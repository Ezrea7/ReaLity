#!/bin/bash
set -e

REPO_DIR="/usr/local/etc/xray/sh"
BIN_LINK="/usr/local/bin/xray"

mkdir -p "$REPO_DIR"
cp -rf ./* "$REPO_DIR/"
chmod +x "$REPO_DIR/xray.sh" 2>/dev/null || true
ln -sf "$REPO_DIR/xray.sh" "$BIN_LINK"

echo "Installed to $REPO_DIR"
echo "Command: $BIN_LINK"
