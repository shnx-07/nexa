#!/usr/bin/env bash
# NEXA Lock Screen Trigger Script

hyprctl dispatch global nexa:lock 2>/dev/null || qs -p "$HOME/.config/nexa/quickshell" ipc call lockScreen lock
