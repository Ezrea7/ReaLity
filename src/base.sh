#!/bin/bash

# ============================================================
#      Xray base module
# ============================================================

SCRIPT_VERSION="$(cat "$SCRIPT_DIR/VERSION" 2>/dev/null || echo 0.3.26)"
SCRIPT_CMD_NAME="xtls"
SCRIPT_CMD_ALIAS="XTLS"
SCRIPT_INSTALL_PATH="/usr/local/bin/${SCRIPT_CMD_NAME}"
SCRIPT_ALIAS_PATH="/usr/local/bin/${SCRIPT_CMD_ALIAS}"
SCRIPT_UPDATE_URL=""
SELF_SCRIPT_PATH="$(readlink -f "$0" 2>/dev/null || printf '%s' "$0")"
XRAY_BIN="/usr/local/bin/xray"
XRAY_DIR="/usr/local/etc/xray"
XRAY_CONFIG="${XRAY_DIR}/config.json"
XRAY_PID_FILE="/tmp/xray.pid"
SINGBOX_BIN="/usr/local/bin/sing-box"
SINGBOX_DIR="/usr/local/etc/sing-box"
SINGBOX_CONFIG="${SINGBOX_DIR}/config.json"
SINGBOX_PID_FILE="/tmp/sing-box.pid"
META_DIR="/usr/local/etc/xtls"
META_FILE="${META_DIR}/metadata.json"
DEFAULT_SNI=""
IP_PREF_FILE="${XRAY_DIR}/ip_preference.conf"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

_info()    { echo -e "${CYAN}[信息] $1${NC}" >&2; }
_success() { echo -e "${GREEN}[成功] $1${NC}" >&2; }
_warn()    { echo -e "${YELLOW}[注意] $1${NC}" >&2; }
_error()   { echo -e "${RED}[错误] $1${NC}" >&2; }

trap 'rm -f "${XRAY_DIR}"/*.tmp.* "${META_DIR}"/*.tmp.* 2>/dev/null || true' EXIT

_check_root() {
    if [ "$EUID" -ne 0 ]; then
        _error "请使用 root 权限运行。"
        exit 1
    fi
}

_detect_init_system() {
    if [ -f /sbin/openrc-run ] || command -v rc-service >/dev/null 2>&1; then
        INIT_SYSTEM="openrc"
    elif command -v systemctl >/dev/null 2>&1; then
        INIT_SYSTEM="systemd"
    else
        INIT_SYSTEM="unknown"
    fi
}

_install_script_shortcut() {
    local src
    src="$SCRIPT_DIR/xray.sh"
    [ -n "$src" ] && [ -f "$src" ] || return 0

    mkdir -p "$(dirname "$SCRIPT_INSTALL_PATH")" 2>/dev/null || true
    ln -sf "$src" "$SCRIPT_INSTALL_PATH" 2>/dev/null || cp -f "$src" "$SCRIPT_INSTALL_PATH" 2>/dev/null || true
    chmod +x "$SCRIPT_INSTALL_PATH" 2>/dev/null || true
    ln -sf "$src" "$SCRIPT_ALIAS_PATH" 2>/dev/null || cp -f "$src" "$SCRIPT_ALIAS_PATH" 2>/dev/null || true
    chmod +x "$SCRIPT_ALIAS_PATH" 2>/dev/null || true
}

_get_ip_preference() {
    local pref=""
    if [ -f "$IP_PREF_FILE" ]; then
        pref=$(tr -d '\n\r' < "$IP_PREF_FILE" 2>/dev/null | tr 'A-Z' 'a-z')
    fi
    case "$pref" in
        ipv4|ipv6) echo "$pref" ;;
        *) echo "ipv4" ;;
    esac
}

_apply_system_ip_preference() {
    local pref="$1"
    local gai_conf="/etc/gai.conf"
    [ -f "$gai_conf" ] || touch "$gai_conf"
    sed -i -e "/^[[:space:]]*precedence[[:space:]]\+::ffff:0:0\/96/ s/^/#/" "$gai_conf"
    if [ "$pref" = "ipv4" ] && ! grep -qE '^[[:space:]]*precedence[[:space:]]+::ffff:0:0/96[[:space:]]+100' "$gai_conf"; then
        echo 'precedence ::ffff:0:0/96 100' >> "$gai_conf"
    fi
}

_set_ip_preference() {
    local pref="$1"
    case "$pref" in
        ipv4|ipv6)
            mkdir -p "$XRAY_DIR" 2>/dev/null || true
            echo "$pref" > "$IP_PREF_FILE" 2>/dev/null || return 1
            _apply_system_ip_preference "$pref"
            unset server_ip
            ;;
        *) return 1 ;;
    esac
}

_fetch_ip_by_proto() {
    local proto="$1" ip=""

    if command -v curl >/dev/null 2>&1; then
        if [ "$proto" = "ipv6" ]; then
            ip=$(curl -s6 --max-time 5 icanhazip.com 2>/dev/null || curl -s6 --max-time 5 ipinfo.io/ip 2>/dev/null || curl -s6 --max-time 5 api6.ipify.org 2>/dev/null || true)
        else
            ip=$(curl -s4 --max-time 5 icanhazip.com 2>/dev/null || curl -s4 --max-time 5 ipinfo.io/ip 2>/dev/null || curl -s4 --max-time 5 api.ipify.org 2>/dev/null || true)
        fi
    fi

    if [ -z "$ip" ] && command -v wget >/dev/null 2>&1; then
        if [ "$proto" = "ipv6" ]; then
            ip=$(wget -qO- -6 --timeout=5 icanhazip.com 2>/dev/null || wget -qO- -6 --timeout=5 ipinfo.io/ip 2>/dev/null || wget -qO- -6 --timeout=5 api6.ipify.org 2>/dev/null || true)
        else
            ip=$(wget -qO- -4 --timeout=5 icanhazip.com 2>/dev/null || wget -qO- -4 --timeout=5 ipinfo.io/ip 2>/dev/null || wget -qO- -4 --timeout=5 api.ipify.org 2>/dev/null || true)
        fi
    fi

    printf '%s' "$ip"
}

_get_public_ip() {
    [ -n "$server_ip" ] && { echo "$server_ip"; return; }

    local pref ip=""
    pref=$(_get_ip_preference)

    if [ "$pref" = "ipv6" ]; then
        ip=$(_fetch_ip_by_proto ipv6)
        [ -z "$ip" ] && ip=$(_fetch_ip_by_proto ipv4)
    else
        ip=$(_fetch_ip_by_proto ipv4)
        [ -z "$ip" ] && ip=$(_fetch_ip_by_proto ipv6)
    fi

    server_ip="$ip"
    echo "$ip"
}

_init_server_ip() {
    server_ip=$(_get_public_ip)
    if [ -z "$server_ip" ] || [ "$server_ip" = "null" ]; then
        _warn "自动获取 IP 失败，请添加节点时手动输入服务器地址。"
        server_ip=""
    fi
}

_get_os_pretty_name() {
    local os_name os_ver
    if [ -r /etc/os-release ]; then
        os_name=$(awk -F= '/^NAME=/{gsub(/"/,"",$2); print $2}' /etc/os-release)
        os_ver=$(awk -F= '/^VERSION_ID=/{gsub(/"/,"",$2); print $2}' /etc/os-release)
        [ -n "$os_name" ] && {
            [ -n "$os_ver" ] && printf '%s v%s\n' "$os_name" "$os_ver" || printf '%s\n' "$os_name"
            return 0
        }
    fi
    uname -s
}
