#!/usr/bin/env bash

set -e

SHELL_PATH="$HOME/.config/nexa/quickshell"

if pgrep -f "quickshell.*$SHELL_PATH" >/dev/null 2>&1; then
    echo "NEXA is already running."
    exit 0
fi

quickshell -p "$SHELL_PATH" >/tmp/nexa-quickshell.log 2>&1 &

disown

echo "NEXA started."
