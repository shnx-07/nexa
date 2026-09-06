#!/usr/bin/env bash

set -e

# NEVER kill or restart quickshell if the session is locked!
# Killing quickshell while holding Wayland WlSessionLock crashes the session lock!
if [ -f /tmp/nexa-locked ]; then
    echo "Session is currently locked. Flagging deferred restart for when session is unlocked."
    touch /tmp/nexa-restart-pending
    exit 0
fi

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

