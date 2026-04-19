#!/bin/bash

args="$@"
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"

# common globals
SCRIPT_VERSION="0.3.18"
SCRIPT_CMD_NAME="xray"
SCRIPT_INSTALL_PATH="/usr/local/bin/${SCRIPT_CMD_NAME}"
SCRIPT_ALIAS_PATH="$SCRIPT_INSTALL_PATH"
SCRIPT_UPDATE_URL="https://raw.githubusercontent.com/Ezrea7/Xray/main/src/core.sh"
SELF_SCRIPT_PATH="$(readlink -f "$0" 2>/dev/null || printf '%s' "$0")"
XRAY_BIN="/usr/local/bin/xray"
XRAY_DIR="/usr/local/etc/xray"
XRAY_CONFIG="${XRAY_DIR}/config.json"
XRAY_PID_FILE="/tmp/xray.pid"
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

# load split modules first
[ -f "$SCRIPT_DIR/src/download.sh" ] && . "$SCRIPT_DIR/src/download.sh"
[ -f "$SCRIPT_DIR/src/service.sh" ] && . "$SCRIPT_DIR/src/service.sh"
[ -f "$SCRIPT_DIR/src/help.sh" ] && . "$SCRIPT_DIR/src/help.sh"

# first-stage repo bootstrap: load current monolithic core
. "$SCRIPT_DIR/src/core.sh"
