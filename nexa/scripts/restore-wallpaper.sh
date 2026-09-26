#!/usr/bin/env bash

CONFIG="$HOME/.config/nexa/config/wallpaper.conf"
WALLPAPER_SCRIPT="$HOME/.config/nexa/scripts/wallpaper.sh"
SLIDESHOW_CONFIG="$HOME/.config/nexa/config/slideshow.json"
NEXAD="$HOME/.config/nexa/rust/target/release/nexad"



[[ -f "$CONFIG" ]] || exit 0

# shellcheck disable=SC1090
source "$CONFIG"

[[ -n "${WALLPAPER:-}" ]] || exit 0
[[ -f "$WALLPAPER" ]] || exit 0

"$WALLPAPER_SCRIPT" "$WALLPAPER" "${MONITOR:-*}" --restore
