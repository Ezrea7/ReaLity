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

_get_singbox_core_version() {
    [ -x "$SINGBOX_BIN" ] || { echo "未安装"; return 0; }
    local version
    version=$($SINGBOX_BIN version 2>/dev/null | head -n1)
    [ -n "$version" ] && echo "$version" || echo "未知版本"
}

_get_singbox_node_count() {
    [ -f "$SINGBOX_CONFIG" ] || { echo "0"; return 0; }
    jq -r '.inbounds | length' "$SINGBOX_CONFIG" 2>/dev/null || echo "0"
}

_get_singbox_service_status() {
    [ -x "$SINGBOX_BIN" ] || { echo "未安装"; return 0; }

    local active=""
    case "$INIT_SYSTEM" in
        systemd)
            systemctl is-active --quiet sing-box >/dev/null 2>&1 && active=1 || active=0 ;;
        openrc)
            rc-service sing-box status >/dev/null 2>&1 && active=1 || active=0 ;;
        *)
            pgrep -f "$SINGBOX_BIN" >/dev/null 2>&1 && active=1 || active=0 ;;
    esac

    if [ "$active" = "1" ]; then
        echo "● 运行中"
    else
        echo "○ 未运行"
    fi
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
