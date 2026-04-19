#!/bin/bash

args="$@"
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"

# load current monolithic core for first-stage repo bootstrap
. "$SCRIPT_DIR/src/core.sh"
