#!/usr/bin/env bash

pkill -f "quickshell.*$HOME/.config/nexa/quickshell" 2>/dev/null || true

echo "NEXA stopped."
