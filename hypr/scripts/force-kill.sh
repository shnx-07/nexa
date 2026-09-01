#!/usr/bin/env bash
# NEXA force kill active window process and free RAM immediately

win_json=$(hyprctl activewindow -j 2>/dev/null)
pid=$(echo "$win_json" | jq -r '.pid // empty' 2>/dev/null)

if [ -n "$pid" ] && [ "$pid" -gt 0 ]; then
    kill -9 "$pid" 2>/dev/null
fi
hyprctl dispatch killactive
