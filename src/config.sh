#!/bin/bash

_atomic_modify_json () 
{ 
    local file="$1" filter="$2";
    [ -f "$file" ] || { 
        _error "文件不存在: $file";
        return 1
    };
    local tmp="${file}.tmp.$$";
    if jq "$filter" "$file" > "$tmp" 2> /dev/null; then
        mv "$tmp" "$file";
    else
        rm -f "$tmp";
        _error "JSON 修改失败: $file";
        return 1;
    fi
}
_apply_xray_json_change () 
{ 
    local filter="$1";
    _atomic_modify_json "$XRAY_CONFIG" "$filter"
}
_check_core_functions () 
{ 
    local fn missing="";
    for fn in \
        _atomic_modify_json \
        _apply_xray_json_change \
        _manage_xray_service \
        _manage_singbox_service \
        _init_xray_config \
        _init_singbox_config \
        _install_or_update_xray \
        _install_or_update_singbox \
        _protocol_add_node \
        _build_protocol_share_link \
        _build_anytls_reality_link \
        _show_xray_runtime_summary \
        _choose_ip_preference; 
    do
        if ! command -v "$fn" > /dev/null 2>&1; then
            missing="$missing $fn";
        fi;
    done;
    if [ -n "$missing" ]; then
        _error "脚本关键函数缺失:${missing}";
        _error "当前脚本可能被不完整修改，请重新更新或替换脚本。";
        exit 1;
    fi
}
_check_port_occupied () 
{ 
    local port="$1" proto="${2:-tcp}";
    if command -v ss > /dev/null 2>&1; then
        if [ "$proto" = "tcp" ]; then
            ss -lntup 2> /dev/null | awk -v p=":${port}" '$0 ~ p {found=1} END{exit !found}' && return 0;
        else
            ss -lnup 2> /dev/null | awk -v p=":${port}" '$0 ~ p {found=1} END{exit !found}' && return 0;
        fi;
    else
        if command -v netstat > /dev/null 2>&1; then
            if [ "$proto" = "tcp" ]; then
                netstat -lntup 2> /dev/null | awk -v p=":${port}" '$0 ~ p {found=1} END{exit !found}' && return 0;
            else
                netstat -lnup 2> /dev/null | awk -v p=":${port}" '$0 ~ p {found=1} END{exit !found}' && return 0;
            fi;
        fi;
    fi;
    return 1
}
_check_port_in_configs () 
{ 
    local port="$1";
    if [ -f "$XRAY_CONFIG" ] && jq -e --argjson p "$port" '.inbounds[] | select(.port == $p)' "$XRAY_CONFIG" > /dev/null 2>&1; then
        return 0;
    fi;
    if [ -f "$SINGBOX_CONFIG" ] && jq -e --argjson p "$port" '.inbounds[] | select(.listen_port == $p)' "$SINGBOX_CONFIG" > /dev/null 2>&1; then
        return 0;
    fi;
    return 1
}
_check_port_conflict () 
{ 
    local port="$1" proto="${2:-tcp}";
    if _check_port_in_configs "$port"; then
        _error "端口 ${port} 已存在于当前节点配置中，请更换端口。";
        return 0;
    fi;
    if _check_port_occupied "$port" "$proto"; then
        _error "端口 ${port} 已被系统进程占用，请更换端口。";
        return 0;
    fi;
    return 1
}
_init_xray_config () 
{ 
    mkdir -p "$XRAY_DIR";
    if [ ! -s "$XRAY_CONFIG" ]; then
        cat > "$XRAY_CONFIG" <<'JSON'
{
  "log": {
    "access": "none",
    "error": "none",
    "loglevel": "none"
  },
  "inbounds": [],
  "outbounds": [
    {
      "protocol": "freedom"
    }
  ]
}
JSON

        _success "Xray 配置文件初始化完成。";
    fi
    mkdir -p "$META_DIR";
    [ -s "$META_FILE" ] || echo '{}' > "$META_FILE"
}
_get_inbound_field () 
{ 
    local tag="$1" field="$2" protocol;
    protocol=$(_get_meta_field "$tag" protocol);
    if [ "$protocol" = "anytls_reality" ]; then
        jq --arg tag "$tag" -r ".inbounds[] | select(.tag == \$tag) | ${field} // empty" "$SINGBOX_CONFIG" 2> /dev/null;
    else
        jq --arg tag "$tag" -r ".inbounds[] | select(.tag == \$tag) | ${field} // empty" "$XRAY_CONFIG" 2> /dev/null;
    fi
}
_get_meta_field () 
{ 
    local tag="$1" field="$2";
    jq --arg tag "$tag" --arg field "$field" -r '.[$tag][$field] // empty' "$META_FILE" 2> /dev/null
}
_set_meta_field () 
{ 
    local tag="$1" key="$2" value="$3";
    _atomic_modify_json "$META_FILE" ".\"$tag\".\"$key\" = \"$value\"" > /dev/null 2>&1
}
_save_meta_bundle () 
{ 
    local tag="$1" name="$2" link="$3";
    shift 3;
    mkdir -p "$META_DIR";
    [ -s "$META_FILE" ] || echo '{}' > "$META_FILE";
    _atomic_modify_json "$META_FILE" ". + {\"$tag\": {name: \"$name\", qx_link: \"$link\"}}" || return 1;
    for pair in "$@";
    do
        local key="${pair%%=*}" val="${pair#*=}";
        [ -n "$key" ] && [ -n "$val" ] || continue;
        _set_meta_field "$tag" "$key" "$val" || true;
    done
}
_get_tag_name () 
{ 
    local tag="$1" name;
    name=$(_get_meta_field "$tag" name);
    [ -n "$name" ] && printf '%s\n' "$name" || printf '%s\n' "$tag"
}
_get_inbound_port () 
{ 
    local tag="$1" protocol;
    protocol=$(_get_meta_field "$tag" protocol);
    if [ "$protocol" = "anytls_reality" ]; then
        jq --arg tag "$tag" -r '.inbounds[] | select(.tag == $tag) | .listen_port // empty' "$SINGBOX_CONFIG" 2> /dev/null;
    else
        jq --arg tag "$tag" -r '.inbounds[] | select(.tag == $tag) | .port // empty' "$XRAY_CONFIG" 2> /dev/null;
    fi
}
_get_inbound_display_protocol () 
{ 
    local tag="$1" protocol;
    protocol=$(_get_meta_field "$tag" protocol);
    if [ "$protocol" = "anytls_reality" ]; then
        echo "anytls+reality+tcp";
        return 0;
    fi;
    local proto network security;
    proto=$(_get_inbound_field "$tag" '.protocol');
    network=$(_get_inbound_field "$tag" '.streamSettings.network // "raw"');
    security=$(_get_inbound_field "$tag" '.streamSettings.security // "none"');
    echo "${proto}+${security}+${network}"
}
_list_tags () 
{ 
    { jq -r '.inbounds[].tag' "$XRAY_CONFIG" 2> /dev/null; jq -r '.inbounds[].tag' "$SINGBOX_CONFIG" 2> /dev/null; } | awk 'NF && !seen[$0]++'
}
_has_nodes () 
{ 
    ([ -f "$XRAY_CONFIG" ] && jq -e '.inbounds | length > 0' "$XRAY_CONFIG" >/dev/null 2>&1) || ([ -f "$SINGBOX_CONFIG" ] && jq -e '.inbounds | length > 0' "$SINGBOX_CONFIG" >/dev/null 2>&1)
}
_select_tag () 
{ 
    local prompt="$1" choice i=1;
    local -a tags;
    mapfile -t tags < <(_list_tags);
    [ "${#tags[@]}" -gt 0 ] || return 1;
    echo "" 1>&2;
    echo -e "${YELLOW}${prompt}${NC}" 1>&2;
    for tag in "${tags[@]}";
    do
        echo -e "  ${GREEN}[${i}]${NC} $(_get_tag_name "$tag") (端口: $(_get_inbound_port "$tag"))" 1>&2;
        i=$((i + 1));
    done;
    echo -e "  ${RED}[0]${NC} 返回" 1>&2;
    echo "" 1>&2;
    read -p "请选择 [0-${#tags[@]}]: " choice 1>&2;
    [ "$choice" = "0" ] && return 1;
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "${#tags[@]}" ]; then
        _error "无效选择。";
        return 1;
    fi;
    printf '%s\n' "${tags[$((choice-1))]}"
}
_delete_inbound_by_tag () 
{ 
    local tag="$1" protocol;
    protocol=$(_get_meta_field "$tag" protocol);
    if [ "$protocol" = "anytls_reality" ]; then
        _atomic_modify_json "$SINGBOX_CONFIG" "del(.inbounds[] | select(.tag == \"$tag\"))" || { _error "删除节点配置失败。"; return 1; };
    else
        _apply_xray_json_change "del(.inbounds[] | select(.tag == \"$tag\"))" || { _error "删除节点配置失败。"; return 1; };
    fi
}
_update_inbound_port_and_tag () 
{ 
    local tag="$1" new_port="$2" new_tag="$3" protocol;
    protocol=$(_get_meta_field "$tag" protocol);
    if [ "$protocol" = "anytls_reality" ]; then
        _atomic_modify_json "$SINGBOX_CONFIG" "(.inbounds[] | select(.tag == \"$tag\") | .listen_port) = $new_port | (.inbounds[] | select(.tag == \"$tag\") | .tag) = \"$new_tag\" | (.inbounds[] | select(.tag == \"$new_tag\") | .users[0].name) = \"$new_tag\"" || { _error "更新节点端口失败。"; return 1; };
    else
        _apply_xray_json_change "(.inbounds[] | select(.tag == \"$tag\") | .port) = $new_port | (.inbounds[] | select(.tag == \"$tag\") | .tag) = \"$new_tag\"" || { _error "更新节点端口失败。"; return 1; };
    fi
}
