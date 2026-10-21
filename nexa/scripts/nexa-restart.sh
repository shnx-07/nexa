#!/usr/bin/env bash

set -e

RUNTIME_NEXA="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/nexa"
if [ -f "$RUNTIME_NEXA/locked" ]; then
    mkdir -p "$RUNTIME_NEXA"
    touch "$RUNTIME_NEXA/restart-pending"
    exit 0
fi

SCRIPT_DIR="$HOME/.config/nexa/scripts"

"$SCRIPT_DIR/nexa-stop.sh"
"$SCRIPT_DIR/nexa-start.sh"
