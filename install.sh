#!/bin/bash
set -e

YELLOW='\033[0;33m'
NC='\033[0m'

TARGET_DIR="/usr/local/etc/xray/sh"
BIN_LINK="/usr/local/bin/xtls"
ALIAS_LINK="/usr/local/bin/XTLS"
SELF_DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
ARCHIVE_URL="https://github.com/Ezrea7/Xray/archive/refs/heads/main.zip"
TMPDIR=""

install_pkg() {
  if command -v apk >/dev/null 2>&1; then
    apk add --no-cache "$@" >/dev/null 2>&1
  elif command -v apt-get >/dev/null 2>&1; then
    apt-get update -qq >/dev/null 2>&1 || true
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "$@" >/dev/null 2>&1
  elif command -v yum >/dev/null 2>&1; then
    yum install -y "$@" >/dev/null 2>&1
  fi
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || install_pkg "$2"
}

download_to() {
  local url="$1" out="$2"
  if command -v curl >/dev/null 2>&1; then
    curl -LfsS "$url" -o "$out"
  else
    wget -q "$url" -O "$out"
  fi
}

cleanup() {
  [ -n "$TMPDIR" ] && rm -rf "$TMPDIR" >/dev/null 2>&1 || true
}
trap cleanup EXIT

if [ "$(id -u)" != "0" ]; then
  echo "请使用 root 运行 install.sh"
  exit 1
fi

need_cmd curl curl
need_cmd unzip unzip
need_cmd bash bash

if [ -f "$SELF_DIR/src/core.sh" ] && [ -f "$SELF_DIR/xray.sh" ]; then
  SOURCE_DIR="$SELF_DIR"
else
  TMPDIR=$(mktemp -d)
  ZIPFILE="$TMPDIR/xray.zip"
  download_to "$ARCHIVE_URL" "$ZIPFILE"
  unzip -qo "$ZIPFILE" -d "$TMPDIR"
  SOURCE_DIR="$(find "$TMPDIR" -maxdepth 1 -type d -name 'Xray-*' | head -n1)"
  [ -n "$SOURCE_DIR" ] || { echo "下载仓库骨架失败"; exit 1; }
fi

mkdir -p "$TARGET_DIR"
cp -rf "$SOURCE_DIR"/* "$TARGET_DIR/"
chmod +x "$TARGET_DIR/xray.sh" "$TARGET_DIR/install.sh" "$TARGET_DIR/src/"*.sh 2>/dev/null || true
ln -sf "$TARGET_DIR/xray.sh" "$BIN_LINK"
ln -sf "$TARGET_DIR/xray.sh" "$ALIAS_LINK"

echo "安装完成"
echo "脚本目录: $TARGET_DIR"
echo "快捷命令: $BIN_LINK"
echo "快捷命令: $ALIAS_LINK"
echo -e "运行方式: ${YELLOW}xtls${NC}"
echo "当前版本: $(grep -E '^[[:space:]]*is_sh_ver=' "$TARGET_DIR/xray.sh" | head -n1 | cut -d'=' -f2 | tr -d '"')"
