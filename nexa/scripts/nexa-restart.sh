#!/usr/bin/env bash

set -e

SCRIPT_DIR="$HOME/.config/nexa/scripts"

"$SCRIPT_DIR/nexa-stop.sh"

sleep 0.5

"$SCRIPT_DIR/nexa-start.sh"

echo "NEXA restarted."
