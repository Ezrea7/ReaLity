#!/bin/bash

args="$@"
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"

# first-stage repo bootstrap: load current monolithic core
. "$SCRIPT_DIR/src/core.sh"
