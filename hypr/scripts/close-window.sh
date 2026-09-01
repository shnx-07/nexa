#!/usr/bin/env bash
# NEXA smart window close & memory release script
# Closes active window and terminates background tray hoarders (Discord, Spotify, Steam, etc.)

win_json=$(hyprctl activewindow -j 2>/dev/null)
pid=$(echo "$win_json" | jq -r '.pid // empty' 2>/dev/null)
class=$(echo "$win_json" | jq -r '.class // empty' 2>/dev/null)

if [ -z "$pid" ] || [ "$pid" -le 0 ]; then
    hyprctl dispatch killactive
    exit 0
fi

case "$class" in
    # Known tray-hoarders that hide to background rather than exiting:
    [Dd]iscord|[Ss]potify|[Ss]team|[Tt]elegram*|[Ss]lack|[Ww]hatsApp*|[Vv]esktop)
        kill -TERM "$pid" 2>/dev/null || hyprctl dispatch killactive
        ;;
    *)
        # Normal window close
        hyprctl dispatch killactive
        ;;
esac
