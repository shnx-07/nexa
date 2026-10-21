#!/usr/bin/env bash
# NEXA Lock Screen Trigger Script (Hyprland 0.56+ Lua Dispatch)

hyprctl dispatch 'hl.dsp.global("nexa:lock")' >/dev/null 2>&1 || qs -p "$HOME/.config/nexa/quickshell" ipc call lockScreen lock >/dev/null 2>&1
