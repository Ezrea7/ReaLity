#!/bin/bash

args="$@"
is_sh_ver="v$(cat "$(CDPATH= cd -- "$(dirname "$0")" && pwd)/VERSION" 2>/dev/null || echo 0.3.23)"

if [ -n "$SCRIPT_DIR" ] && [ -d "$SCRIPT_DIR" ]; then
    :
elif [ -f "$0" ]; then
    SCRIPT_DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
else
    SCRIPT_DIR="/usr/local/etc/xray/sh"
fi

if [ -f "$SCRIPT_DIR/src/init.sh" ]; then
    . "$SCRIPT_DIR/src/init.sh"
elif [ -f "/usr/local/etc/xray/sh/src/init.sh" ]; then
    SCRIPT_DIR="/usr/local/etc/xray/sh"
    . "/usr/local/etc/xray/sh/src/init.sh"
else
    echo "init.sh not found"
    exit 1
fi
