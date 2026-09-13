#!/usr/bin/env bash

CONFIG="$HOME/.config/nexa/config/wallpaper.conf"
WALLPAPER_SCRIPT="$HOME/.config/nexa/scripts/wallpaper.sh"
SLIDESHOW_CONFIG="$HOME/.config/nexa/config/slideshow.json"
NEXAD="$HOME/.config/nexa/rust/target/release/nexad"

# On system restart / login: if slideshow is active, apply a fresh random wallpaper
if [[ -f "$SLIDESHOW_CONFIG" ]] && command -v jq >/dev/null 2>&1; then
    enabled=$(jq -r '.enabled // false' "$SLIDESHOW_CONFIG" 2>/dev/null)
    paused=$(jq -r '.paused // false' "$SLIDESHOW_CONFIG" 2>/dev/null)
    if [[ "$enabled" == "true" && "$paused" != "true" && -x "$NEXAD" ]]; then
        "$NEXAD" wallpaper slideshow next
        exit 0
    fi
fi

[[ -f "$CONFIG" ]] || exit 0

# shellcheck disable=SC1090
source "$CONFIG"

[[ -n "${WALLPAPER:-}" ]] || exit 0
[[ -f "$WALLPAPER" ]] || exit 0

"$WALLPAPER_SCRIPT" "$WALLPAPER" "${MONITOR:-*}" --restore
