#!/bin/bash

_pause () 
{ 
    [ -t 0 ] || return 0;
    echo "";
    read -p "按回车键继续..." _
}
_menu_item () 
{ 
    printf "  ${GREEN}[%-2s]${NC} %s\n" "$1" "$2"
}
_menu_danger () 
{ 
    printf "  ${RED}[%-2s]${NC} %s\n" "$1" "$2"
}
_menu_exit () 
{ 
    printf "  ${YELLOW}[%-2s]${NC} %s\n" "$1" "$2"
}
_confirm_yes () 
{ 
    local answer="$1";
    [ "$answer" = "y" ] || [ "$answer" = "Y" ]
}
_input_port () 
{ 
    local port="";
    while true; do
        read -p "请输入监听端口: " port;
        [[ -z "$port" ]] && _error "端口不能为空。" && continue;
        if ! [[ "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
            _error "无效端口号。";
            continue;
        fi;
        echo "$port";
        return 0;
    done
}
_input_uuid () 
{ 
    local uuid="";
    while true; do
        read -p "请输入 UUID (回车自动生成): " uuid;
        if [ -z "$uuid" ]; then
            if [ -x "$XRAY_BIN" ]; then
                uuid=$($XRAY_BIN uuid 2> /dev/null | tr 'A-Z' 'a-z');
            else
                if command -v uuidgen > /dev/null 2>&1; then
                    uuid=$(uuidgen | tr 'A-Z' 'a-z');
                else
                    if [ -f /proc/sys/kernel/random/uuid ]; then
                        uuid=$(cat /proc/sys/kernel/random/uuid 2> /dev/null | tr 'A-Z' 'a-z');
                    else
                        uuid=$(openssl rand -hex 16 | sed 's/^\(........\)\(....\)\(....\)\(....\)\(............\)$/\1-\2-\3-\4-\5/');
                    fi;
                fi;
            fi;
            printf '%s\n' "$uuid";
            return 0;
        fi;
        if printf '%s' "$uuid" | grep -qiE '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'; then
            printf '%s\n' "$(printf '%s' "$uuid" | tr 'A-Z' 'a-z')";
            return 0;
        fi;
        _error "UUID 格式无效，请重新输入。";
    done
}
_input_node_ip () 
{ 
    local node_ip custom_ip;
    while true; do
        [ -z "$server_ip" ] && _init_server_ip;
        node_ip="$server_ip";
        if [ -n "$server_ip" ]; then
            read -p "请输入服务器地址 (IP 或域名，回车默认当前检测 IP: ${server_ip}): " custom_ip;
            node_ip=${custom_ip:-$server_ip};
        else
            _warn "未能自动检测到当前公网 IP，请手动输入服务器地址。";
            read -p "请输入服务器地址 (IP 或域名): " node_ip;
        fi;
        if [ -z "$node_ip" ]; then
            _error "服务器地址不能为空。";
            continue;
        fi;
        if printf '%s' "$node_ip" | grep -q '[[:space:]]'; then
            _error "服务器地址不能包含空白字符。";
            continue;
        fi;
        printf '%s\n' "$node_ip";
        return 0;
    done
}
_input_sni () 
{ 
    local default_sni="$1" custom_sni sni;
    [ -n "$default_sni" ] || default_sni="$DEFAULT_SNI";
    while true; do
        if [ -n "$default_sni" ]; then
            read -p "请输入 REALITY 目标域名 / SNI (默认: ${default_sni}): " custom_sni;
            sni="${custom_sni:-$default_sni}";
        else
            read -p "请输入 REALITY 目标域名 / SNI: " custom_sni;
            sni="$custom_sni";
        fi;
        if [ -z "$sni" ]; then
            _error "REALITY 目标域名 / SNI 不能为空。";
            continue;
        fi;
        if printf '%s' "$sni" | grep -q '[[:space:]]'; then
            _error "REALITY 目标域名 / SNI 不能包含空白字符。";
            continue;
        fi;
        printf '%s\n' "$sni";
        return 0;
    done
}
_input_node_name () 
{ 
    local protocol="$1" port="$2" default_name custom_name name tag;
    default_name=$(_protocol_default_name "$protocol" "$port");
    while true; do
        read -p "请输入节点名称 (默认: ${default_name}): " custom_name;
        name=${custom_name:-$default_name};
        [ -n "$name" ] || { 
            _error "节点名称不能为空。";
            continue
        };
        if printf '%s' "$name" | grep -q '["\\]'; then
            _error "节点名称不能包含双引号或反斜杠。";
            continue;
        fi;
        tag="$name";
        if _list_tags | grep -Fxq "$tag"; then
            _error "节点名称已存在，请重新输入。";
            continue;
        fi;
        printf '%s\n' "$name";
        return 0;
    done
}
_protocol_view_all_nodes () 
{ 
    if ! _has_nodes; then
        _warn "当前没有节点。";
        return;
    fi;
    echo "";
    echo -e "${YELLOW}══════════════════ 节点列表 ══════════════════${NC}";
    local count=0 tag port name link display_proto std_link;
    while IFS= read -r tag; do
        count=$((count + 1));
        port=$(_get_inbound_port "$tag");
        name=$(_get_tag_name "$tag");
        link=$(_get_share_link "$tag");
        display_proto=$(_get_inbound_display_protocol "$tag");
        echo "";
        echo -e "  ${GREEN}[${count}]${NC} ${CYAN}${name}${NC}";
        echo -e "      类型: ${YELLOW}$(_protocol_name "$(_protocol_of_tag "$tag")")${NC}";
        echo -e "      协议: ${YELLOW}${display_proto}${NC}  |  端口: ${GREEN}${port}${NC}  |  标签: ${CYAN}${tag}${NC}";
        if [ -n "$link" ]; then
            echo -e "      ${YELLOW}Quantumult X:${NC} ${link}";
        else
            echo -e "      ${RED}Quantumult X: 无法生成链接${NC}";
        fi;
        if [ "$(_protocol_of_tag "$tag")" = "vless_vision_reality" ]; then
            std_link=$(_build_vless_vision_reality_std_link "$tag");
            [ -n "$std_link" ] && echo -e "      ${YELLOW}标准分享链接:${NC} ${std_link}";
        fi;
    done < <(_list_tags)
}
_restart_node_backend () 
{ 
    _manage_xray_service restart
}
_protocol_view_one_node_by_tag () 
{ 
    local target_tag="$1" port name link display_proto std_link;
    [ -n "$target_tag" ] || return 1;
    port=$(_get_inbound_port "$target_tag");
    name=$(_get_tag_name "$target_tag");
    link=$(_get_share_link "$target_tag");
    display_proto=$(_get_inbound_display_protocol "$target_tag");
    echo "";
    echo -e "${YELLOW}══════════════════ 节点详情 ══════════════════${NC}";
    echo -e "  名称: ${CYAN}${name}${NC}";
    echo -e "  类型: ${YELLOW}$(_protocol_name "$(_protocol_of_tag "$target_tag")")${NC}";
    echo -e "  协议: ${YELLOW}${display_proto}${NC}";
    echo -e "  端口: ${GREEN}${port}${NC}";
    echo -e "  标签: ${CYAN}${target_tag}${NC}";
    if [ -n "$link" ]; then
        echo -e "  ${YELLOW}Quantumult X:${NC} ${link}";
    else
        echo -e "  ${RED}Quantumult X: 无法生成链接${NC}";
    fi;
    if [ "$(_protocol_of_tag "$target_tag")" = "vless_vision_reality" ]; then
        std_link=$(_build_vless_vision_reality_std_link "$target_tag");
        [ -n "$std_link" ] && echo -e "  ${YELLOW}标准分享链接:${NC} ${std_link}";
    fi;
    echo ""
}
_protocol_view_nodes () 
{ 
    local choice i=1;
    local -a tags;
    if ! _has_nodes; then
        _warn "当前没有节点。";
        return;
    fi;
    mapfile -t tags < <(_list_tags);
    [ "${#tags[@]}" -gt 0 ] || { 
        _warn "当前没有节点。";
        return
    };
    echo "";
    echo -e "${YELLOW}══════════ 查看节点 ══════════${NC}";
    for tag in "${tags[@]}";
    do
        echo -e "  ${GREEN}[${i}]${NC} $(_get_tag_name "$tag") (端口: $(_get_inbound_port "$tag"))";
        i=$((i + 1));
    done;
    echo -e "  ${GREEN}[a]${NC} 查看全部节点";
    echo -e "  ${RED}[0]${NC} 返回";
    echo "";
    read -p "请选择 [0-${#tags[@]}/a]: " choice;
    case "$choice" in 
        a | A)
            _protocol_view_all_nodes
        ;;
        0)
            return 0
        ;;
        *)
            if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#tags[@]}" ]; then
                _protocol_view_one_node_by_tag "${tags[$((choice-1))]}";
            else
                _error "无效输入。";
                return 1;
            fi
        ;;
    esac
}
_protocol_delete_node () 
{ 
    if ! _has_nodes; then
        _warn "当前没有节点。";
        return;
    fi;
    local target_tag target_name confirm;
    target_tag=$(_select_tag "══════════ 选择要删除的节点 ══════════") || return;
    target_name=$(_get_tag_name "$target_tag");
    read -p "确定删除 [${target_name}]? (y/N): " confirm;
    _confirm_yes "$confirm" || { 
        _info "已取消。";
        return
    };
    _delete_inbound_by_tag "$target_tag" || return 1;
    _atomic_modify_json "$META_FILE" "del(.\"$target_tag\")" > /dev/null 2>&1 || true;
    _restart_node_backend;
    _success "节点删除完成：${target_name}。"
}
_protocol_modify_port () 
{ 
    if ! _has_nodes; then
        _warn "当前没有节点。";
        return;
    fi;
    local target_tag old_port target_name new_port new_tag new_name old_link new_link tmp;
    target_tag=$(_select_tag "══════════ 选择要修改端口的节点 ══════════") || return;
    old_port=$(_get_inbound_port "$target_tag");
    target_name=$(_get_tag_name "$target_tag");
    [ -n "$old_port" ] && [ "$old_port" != "null" ] || { 
        _error "未找到目标节点端口。";
        return 1
    };
    _info "当前端口: ${old_port}";
    new_port=$(_input_port);
    [ "$new_port" = "$old_port" ] && { 
        _info "新端口与当前端口一致，无需修改。";
        return 0
    };
    new_tag=$(printf '%s' "$target_tag" | sed "s/${old_port}/${new_port}/g");
    new_name=$(printf '%s' "$target_name" | sed "s/${old_port}/${new_port}/g");
    [ -n "$new_tag" ] || new_tag="$target_tag";
    [ -n "$new_name" ] || new_name="$target_name";
    if [ "$new_tag" != "$target_tag" ] && _list_tags | grep -Fxq "$new_tag"; then
        _error "修改后的节点标签已存在，请调整节点名称后再试。";
        return 1;
    fi;
    old_link=$(_get_share_link "$target_tag");
    _update_inbound_port_and_tag "$target_tag" "$new_port" "$new_tag" || return 1;
    new_link=$(_replace_port_in_text "$old_link" "$old_port" "$new_port");
    [ -n "$new_link" ] || new_link=$(_build_protocol_share_link "$new_tag" 2> /dev/null);
    tmp="${META_FILE}.tmp.$$";
    jq --arg ot "$target_tag" --arg nt "$new_tag" --arg n "$new_name" --arg l "$new_link" '. + {($nt): ((.[$ot] // {}) + {name: $n, qx_link: $l})} | del(.[$ot])' "$META_FILE" > "$tmp" 2> /dev/null && mv "$tmp" "$META_FILE" || { 
        rm -f "$tmp";
        _error "更新节点元数据失败。";
        return 1
    };
    _restart_node_backend;
    _success "节点端口修改完成：${new_name} -> ${new_port}。"
}
_add_protocol_menu () 
{ 
    local choice;
    echo "";
    echo -e "${YELLOW}══════════ 选择要添加的协议 ══════════${NC}";
    echo -e " ${CYAN}【Xray 内核】${NC}";
    echo -e "  ${GREEN}[1]${NC} VLESS + Vision + Reality";
    echo -e "  ${GREEN}[2]${NC} SS + ReaLity";
    echo -e "  ${GREEN}[3]${NC} Trojan + Reality";
    echo -e "  ${GREEN}[4]${NC} VMess + Reality";
    echo "";
    echo -e " ${CYAN}【Sing-box 内核】${NC}";
    echo -e "  ${GREEN}[5]${NC} AnyTLS + Reality";
    echo -e "  ${RED}[0]${NC} 返回上一级";
    echo "";
    read -p "请选择 [0-5]: " choice;
    case "$choice" in 
        1 | 2 | 3 | 4)
            _require_xray || return 1;
            _init_xray_config;
            case "$choice" in 
                1)
                    _protocol_add_node vless_vision_reality
                ;;
                2)
                    _protocol_add_node ss2022_reality
                ;;
                3)
                    _protocol_add_node trojan_reality
                ;;
                4)
                    _protocol_add_node vmess_reality
                ;;
            esac
        ;;
        5)
            _require_singbox || return 1;
            _init_singbox_config;
            _protocol_add_node anytls_reality
        ;;
        0)
            return 0
        ;;
        *)
            _error "无效输入。";
            return 1
        ;;
    esac
}
_xray_menu () 
{ 
    while true; do
        clear;
        echo "";
        echo -e "==================================================";
        echo -e " Xray Sing-box / Reality 协议管理脚本 v${SCRIPT_VERSION}";
        echo -e " 当前协议组合: Xray + Sing-box / Reality";
        _show_xray_runtime_summary;
        echo -e "==================================================";
        echo -e " ${CYAN}【核心管理】${NC}";
        _menu_item 1 "安装/更新 Xray 内核";
        _menu_item 2 "安装/更新 Sing-box 内核";
        echo "";
        echo -e " ${CYAN}【Xray 服务管理】${NC}";
        _menu_item 3 "启动 Xray 服务";
        _menu_item 4 "停止 Xray 服务";
        _menu_item 5 "重启 Xray 服务";
        echo "";
        echo -e " ${CYAN}【Sing-box 服务管理】${NC}";
        _menu_item 6 "启动 Sing-box 服务";
        _menu_item 7 "停止 Sing-box 服务";
        _menu_item 8 "重启 Sing-box 服务";
        echo "";
        echo -e " ${CYAN}【节点管理】${NC}";
        _menu_item 9 "添加节点（选择协议）";
        _menu_item 10 "查看节点";
        _menu_item 11 "删除节点";
        _menu_item 12 "修改节点端口";
        _menu_item 13 "设置网络优先级 (IPv4/IPv6)";
        echo "";
        echo -e " ${CYAN}【脚本与卸载】${NC}";
        _menu_danger 55 "更新脚本";
        _menu_danger 77 "卸载 Sing-box 内核";
        _menu_danger 88 "卸载 Xray 内核";
        _menu_danger 99 "卸载脚本";
        _menu_exit 0 "退出脚本";
        echo -e "==================================================";
        read -p "请选择 [0-99]: " choice;
        case "$choice" in 
            1)
                _install_or_update_xray; _pause ;;
            2)
                _install_or_update_singbox; _pause ;;
            3)
                [ -f "$XRAY_BIN" ] && _manage_xray_service start; _pause ;;
            4)
                [ -f "$XRAY_BIN" ] && _manage_xray_service stop; _pause ;;
            5)
                [ -f "$XRAY_BIN" ] && _manage_xray_service restart; _pause ;;
            6)
                [ -f "$SINGBOX_BIN" ] && _manage_singbox_service start; _pause ;;
            7)
                [ -f "$SINGBOX_BIN" ] && _manage_singbox_service stop; _pause ;;
            8)
                [ -f "$SINGBOX_BIN" ] && _manage_singbox_service restart; _pause ;;
            9)
                _add_protocol_menu; _pause ;;
            10)
                _protocol_view_nodes; _pause ;;
            11)
                _protocol_delete_node; _pause ;;
            12)
                _protocol_modify_port; _pause ;;
            13)
                _choose_ip_preference ;;
            55)
                _update_script_self; _pause; exit 0 ;;
            77)
                _uninstall_singbox; _pause ;;
            88)
                _uninstall_xray; _pause ;;
            99)
                _uninstall_script ;;
            0)
                exit 0 ;;
            *)
                _error "无效输入。"; _pause ;;
        esac;
    done
}
_main () 
{ 
    _check_root;
    _detect_init_system;
    _ensure_deps;
    _check_core_functions;
    _install_script_shortcut;
    if [ -f "$XRAY_BIN" ]; then
        _init_xray_config;
        _create_xray_service > /dev/null 2>&1 || true;
    fi;
    _xray_menu
}
