#!/usr/bin/env bash

set -e

SHELL_PATH="$HOME/.config/nexa/quickshell"

if pgrep -f "quickshell.*$SHELL_PATH" >/dev/null 2>&1; then
    echo "NEXA is already running."
    exit 0
fi

# Always run quickshell with working directory at $HOME so child processes default to $HOME
cd "$HOME"
export QS_ICON_THEME="breeze-dark"
quickshell -d -p "$SHELL_PATH" >/tmp/nexa-quickshell.log 2>&1

echo "NEXA started."
