#!/bin/bash

args="$@"
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"

. "$SCRIPT_DIR/src/core.sh"
. "$SCRIPT_DIR/src/download.sh"
. "$SCRIPT_DIR/src/service.sh"
. "$SCRIPT_DIR/src/help.sh"
. "$SCRIPT_DIR/src/config.sh"
. "$SCRIPT_DIR/src/share.sh"
. "$SCRIPT_DIR/src/protocol.sh"
. "$SCRIPT_DIR/src/menu.sh"

_main "$@"
