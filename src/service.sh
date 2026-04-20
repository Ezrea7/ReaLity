#!/bin/bash

_init_singbox_config() {
    mkdir -p "$SINGBOX_DIR"

    if [ ! -s "$SINGBOX_CONFIG" ]; then
        cat > "$SINGBOX_CONFIG" <<'JSON'
{
  "log": {
    "disabled": true
  },
  "inbounds": [],
  "outbounds": [
    {
      "type": "direct"
    }
  ]
}
JSON
        _success "Sing-box 配置文件初始化完成。"
    fi
}

_create_xray_systemd_service() {
    cat > /etc/systemd/system/xray.service <<EOF2
[Unit]
Description=Xray Service
After=network.target nss-lookup.target

[Service]
Type=simple
ExecStart=${XRAY_BIN} run -c ${XRAY_CONFIG}
Restart=on-failure
RestartSec=3s
LimitNOFILE=65535
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF2
    systemctl daemon-reload >/dev/null 2>&1 || true
    systemctl enable xray >/dev/null 2>&1 || true
}

_create_xray_openrc_service() {
    cat > /etc/init.d/xray <<EOF2
#!/sbin/openrc-run
description="Xray Service"
command="${XRAY_BIN}"
command_args="run -c ${XRAY_CONFIG}"
supervisor="supervise-daemon"
respawn_delay=3
respawn_max=0
pidfile="${XRAY_PID_FILE}"
output_log="/dev/null"
error_log="/dev/null"

depend() {
    need net
    after firewall
}
EOF2
    chmod +x /etc/init.d/xray
    rc-update add xray default >/dev/null 2>&1 || true
}

_create_xray_service() {
    case "$INIT_SYSTEM" in
        systemd) _create_xray_systemd_service ;;
        openrc) _create_xray_openrc_service ;;
        *) _warn "未检测到 systemd/openrc，请手动管理 Xray 进程。" ;;
    esac
}

_create_singbox_systemd_service() {
    cat > /etc/systemd/system/sing-box.service <<EOF2
[Unit]
Description=sing-box service
Documentation=https://sing-box.sagernet.org
After=network.target nss-lookup.target

[Service]
Type=simple
ExecStart=${SINGBOX_BIN} run -c ${SINGBOX_CONFIG}
Restart=on-failure
RestartSec=3s
LimitNOFILE=65535
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF2
    systemctl daemon-reload >/dev/null 2>&1 || true
    systemctl enable sing-box >/dev/null 2>&1 || true
}

_create_singbox_openrc_service() {
    cat > /etc/init.d/sing-box <<EOF2
#!/sbin/openrc-run
description="sing-box service"
command="${SINGBOX_BIN}"
command_args="run -c ${SINGBOX_CONFIG}"
supervisor="supervise-daemon"
respawn_delay=3
respawn_max=0
pidfile="${SINGBOX_PID_FILE}"
output_log="/dev/null"
error_log="/dev/null"

depend() {
    need net
    after firewall
}
EOF2
    chmod +x /etc/init.d/sing-box
    rc-update add sing-box default >/dev/null 2>&1 || true
}

_create_singbox_service() {
    case "$INIT_SYSTEM" in
        systemd) _create_singbox_systemd_service ;;
        openrc) _create_singbox_openrc_service ;;
        *) _warn "未检测到 systemd/openrc，请手动管理 Sing-box 进程。" ;;
    esac
}

_get_xray_core_version() {
    [ -x "$XRAY_BIN" ] || { echo "未安装"; return 0; }
    local version
    version=$($XRAY_BIN version 2>/dev/null | head -1 | awk '{print $2}')
    [ -n "$version" ] && echo "v${version}" || echo "未知版本"
}

_get_singbox_core_version() {
    [ -x "$SINGBOX_BIN" ] || { echo "未安装"; return 0; }
    local version
    version=$($SINGBOX_BIN version 2>/dev/null | head -n1)
    [ -n "$version" ] && echo "$version" || echo "未知版本"
}

_get_xray_node_count() {
    [ -f "$XRAY_CONFIG" ] || { echo "0"; return 0; }
    jq -r '.inbounds | length' "$XRAY_CONFIG" 2>/dev/null || echo "0"
}

_get_singbox_node_count() {
    [ -f "$SINGBOX_CONFIG" ] || { echo "0"; return 0; }
    jq -r '.inbounds | length' "$SINGBOX_CONFIG" 2>/dev/null || echo "0"
}

_get_xray_service_status() {
    [ -x "$XRAY_BIN" ] || { echo "未安装"; return 0; }

    local active=""
    case "$INIT_SYSTEM" in
        systemd) systemctl is-active --quiet xray >/dev/null 2>&1 && active=1 || active=0 ;;
        openrc) rc-service xray status >/dev/null 2>&1 && active=1 || active=0 ;;
        *) pgrep -f "$XRAY_BIN" >/dev/null 2>&1 && active=1 || active=0 ;;
    esac

    if [ "$active" = "1" ]; then
        echo "● 运行中"
    else
        echo "○ 未运行"
    fi
}

_get_singbox_service_status() {
    [ -x "$SINGBOX_BIN" ] || { echo "未安装"; return 0; }

    local active=""
    case "$INIT_SYSTEM" in
        systemd) systemctl is-active --quiet sing-box >/dev/null 2>&1 && active=1 || active=0 ;;
        openrc) rc-service sing-box status >/dev/null 2>&1 && active=1 || active=0 ;;
        *) pgrep -f "$SINGBOX_BIN" >/dev/null 2>&1 && active=1 || active=0 ;;
    esac

    if [ "$active" = "1" ]; then
        echo "● 运行中"
    else
        echo "○ 未运行"
    fi
}

_show_xray_runtime_summary() {
    local os_info
    os_info=$(_get_os_pretty_name)
    echo -e " 系统: ${CYAN}${os_info}${NC}  |  模式: ${CYAN}${INIT_SYSTEM}${NC}"
    echo -e " Xray ${YELLOW}$(_get_xray_core_version)${NC}: ${GREEN}$(_get_xray_service_status)${NC} ($(_get_xray_node_count)节点)"
    echo -e " Sing-box ${YELLOW}$(_get_singbox_core_version)${NC}: ${GREEN}$(_get_singbox_service_status)${NC} ($(_get_singbox_node_count)节点)"
    echo -e "--------------------------------------------------"
}

_require_xray() {
    [ -x "$XRAY_BIN" ] && return 0
    _warn "当前未安装 Xray 内核。"
    _warn "请先执行 [1] 安装/更新 Xray 内核。"
    return 1
}

_require_singbox() {
    [ -x "$SINGBOX_BIN" ] && return 0
    _warn "当前未安装 Sing-box 内核。"
    _warn "请先执行 [2] 安装/更新 Sing-box 内核。"
    return 1
}

_manage_xray_service() {
    local action="$1" result=1

    [ -x "$XRAY_BIN" ] || { _error "Xray 内核未安装。"; return 1; }
    [ -z "$INIT_SYSTEM" ] && _detect_init_system

    [ "$action" = "status" ] || _info "正在使用 ${INIT_SYSTEM} 执行: ${action}..."

    case "$INIT_SYSTEM" in
        systemd)
            if [ "$action" = "status" ]; then
                systemctl status xray --no-pager -l
                return
            fi
            systemctl "$action" xray >/dev/null 2>&1
            result=$?
            ;;
        openrc)
            if [ "$action" = "status" ]; then
                rc-service xray status
                return
            fi
            rc-service xray "$action" >/dev/null 2>&1
            result=$?
            ;;
        *)
            _warn "未检测到服务管理器，跳过 ${action}。"
            return 0
            ;;
    esac

    [ "$result" -eq 0 ] || { _error "Xray 服务${action}失败。"; return 1; }

    case "$action" in
        start) _success "Xray 服务启动成功。" ;;
        stop) _success "Xray 服务停止成功。" ;;
        restart) _success "Xray 服务重启成功。" ;;
    esac
}

_manage_singbox_service() {
    local action="$1" result=1

    [ -x "$SINGBOX_BIN" ] || { _error "Sing-box 内核未安装。"; return 1; }
    [ -z "$INIT_SYSTEM" ] && _detect_init_system

    [ "$action" = "status" ] || _info "正在使用 ${INIT_SYSTEM} 执行: ${action}..."

    case "$INIT_SYSTEM" in
        systemd)
            if [ "$action" = "status" ]; then
                systemctl status sing-box --no-pager -l
                return
            fi
            systemctl "$action" sing-box >/dev/null 2>&1
            result=$?
            ;;
        openrc)
            if [ "$action" = "status" ]; then
                rc-service sing-box status
                return
            fi
            rc-service sing-box "$action" >/dev/null 2>&1
            result=$?
            ;;
        *)
            _warn "未检测到服务管理器，跳过 ${action}。"
            return 0
            ;;
    esac

    [ "$result" -eq 0 ] || { _error "Sing-box 服务${action}失败。"; return 1; }

    case "$action" in
        start) _success "Sing-box 服务启动成功。" ;;
        stop) _success "Sing-box 服务停止成功。" ;;
        restart) _success "Sing-box 服务重启成功。" ;;
    esac
}

_cleanup_xray_files() {
    _manage_xray_service stop >/dev/null 2>&1 || true

    if [ "$INIT_SYSTEM" = "systemd" ]; then
        systemctl disable xray >/dev/null 2>&1
        rm -f /etc/systemd/system/xray.service
        systemctl daemon-reload >/dev/null 2>&1 || true
    elif [ "$INIT_SYSTEM" = "openrc" ]; then
        rc-update del xray default >/dev/null 2>&1
        rm -f /etc/init.d/xray
    fi

    rm -f "$XRAY_BIN" "$XRAY_PID_FILE" "$XRAY_CONFIG" "$XRAY_DIR/geoip.dat" "$XRAY_DIR/geosite.dat" "$IP_PREF_FILE"

    if [ ! -x "$SINGBOX_BIN" ] && [ ! -f "$SINGBOX_CONFIG" ]; then
        rm -f "$META_FILE"
        rmdir "$META_DIR" 2>/dev/null || true
    fi
}

_cleanup_singbox_files() {
    _manage_singbox_service stop >/dev/null 2>&1 || true

    if [ "$INIT_SYSTEM" = "systemd" ]; then
        systemctl disable sing-box >/dev/null 2>&1
        rm -f /etc/systemd/system/sing-box.service
        systemctl daemon-reload >/dev/null 2>&1 || true
    elif [ "$INIT_SYSTEM" = "openrc" ]; then
        rc-update del sing-box default >/dev/null 2>&1
        rm -f /etc/init.d/sing-box
    fi

    rm -f "$SINGBOX_BIN" "$SINGBOX_PID_FILE"
    rm -rf "$SINGBOX_DIR"

    if [ ! -x "$XRAY_BIN" ] && [ ! -f "$XRAY_CONFIG" ]; then
        rm -f "$META_FILE"
        rmdir "$META_DIR" 2>/dev/null || true
    fi
}

_uninstall_xray() {
    echo ""
    _warn "即将卸载 Xray 内核及相关配置。"
    printf "${YELLOW}确定要继续吗? (y/N): ${NC}"
    read -r confirm
    _confirm_yes "$confirm" || { _info "卸载已取消。"; return; }

    _cleanup_xray_files
    _success "Xray 内核卸载完成。"
}

_uninstall_singbox() {
    echo ""
    _warn "即将卸载 Sing-box 内核及相关配置。"
    printf "${YELLOW}确定要继续吗? (y/N): ${NC}"
    read -r confirm
    _confirm_yes "$confirm" || { _info "卸载已取消。"; return; }

    _cleanup_singbox_files
    _success "Sing-box 内核卸载完成。"
}

_uninstall_script() {
    _warn "！！！警告！！！"
    _warn "本操作将停止并禁用 Xray / Sing-box 服务，"
    _warn "删除所有相关文件（包括二进制、配置文件、快捷命令及脚本本体）。"

    echo ""
    echo "即将删除以下内容："
    echo -e "  ${RED}-${NC} Xray 配置目录: ${XRAY_DIR}"
    echo -e "  ${RED}-${NC} Xray 二进制: ${XRAY_BIN}"
    echo -e "  ${RED}-${NC} Sing-box 配置目录: ${SINGBOX_DIR}"
    echo -e "  ${RED}-${NC} Sing-box 二进制: ${SINGBOX_BIN}"
    echo -e "  ${RED}-${NC} 系统快捷命令: ${SCRIPT_INSTALL_PATH}"
    [ "$SCRIPT_ALIAS_PATH" != "$SCRIPT_INSTALL_PATH" ] && echo -e "  ${RED}-${NC} 系统快捷命令: ${SCRIPT_ALIAS_PATH}"
    echo ""

    printf "${YELLOW}确定要执行卸载吗? (y/N): ${NC}"
    read -r confirm_main
    _confirm_yes "$confirm_main" || { _info "卸载已取消。"; return; }

    _cleanup_xray_files
    _cleanup_singbox_files

    _info "正在清理快捷命令与脚本本体..."
    rm -f "$SCRIPT_INSTALL_PATH" "$SCRIPT_ALIAS_PATH"
    rm -rf "$XRAY_DIR/sh"
    rmdir "$XRAY_DIR" 2>/dev/null || true

    _success "清理完成。脚本已自毁。再见！"
    exit 0
}
