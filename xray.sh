#!/bin/bash

args="$@"
is_sh_ver="v0.3.19"
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"

if [ -f "$SCRIPT_DIR/src/init.sh" ]; then
    . "$SCRIPT_DIR/src/init.sh"
elif [ -f "/usr/local/etc/xray/sh/src/init.sh" ]; then
    . "/usr/local/etc/xray/sh/src/init.sh"
else
    echo "init.sh not found"
    exit 1
fi
