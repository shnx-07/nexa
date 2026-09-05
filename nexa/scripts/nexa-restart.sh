#!/usr/bin/env bash

set -e

SCRIPT_DIR="$HOME/.config/nexa/scripts"

"$SCRIPT_DIR/nexa-stop.sh"

# Wait up to 3 seconds for previous quickshell to fully terminate
for i in {1..30}; do
    if ! pgrep -f "quickshell" >/dev/null 2>&1; then
        break
    fi
    sleep 0.1
done

"$SCRIPT_DIR/nexa-start.sh"

echo "NEXA restarted."

