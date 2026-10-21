#!/usr/bin/env bash

# Terminate running quickshell instance immediately
pkill -TERM -f "quickshell.*$HOME/.config/nexa/quickshell" 2>/dev/null || true

# Give 300ms to exit gracefully, otherwise force kill
for i in {1..6}; do
    if ! pgrep -f "quickshell.*$HOME/.config/nexa/quickshell" >/dev/null 2>&1; then
        break
    fi
    sleep 0.05
done

pkill -KILL -f "quickshell.*$HOME/.config/nexa/quickshell" 2>/dev/null || true
