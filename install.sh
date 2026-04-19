#!/bin/bash
set -e

TARGET_DIR="/usr/local/etc/xray/sh"
BIN_LINK="/usr/local/bin/xray"
SELF_DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"

if [ "$(id -u)" != "0" ]; then
  echo "请使用 root 运行 install.sh"
  exit 1
fi

mkdir -p "$TARGET_DIR"
cp -rf "$SELF_DIR"/* "$TARGET_DIR/"
chmod +x "$TARGET_DIR/xray.sh" "$TARGET_DIR/install.sh" 2>/dev/null || true
ln -sf "$TARGET_DIR/xray.sh" "$BIN_LINK"

echo "安装完成"
echo "脚本目录: $TARGET_DIR"
echo "快捷命令: $BIN_LINK"
echo "运行方式: xray"
