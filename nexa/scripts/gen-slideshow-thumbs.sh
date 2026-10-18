#!/usr/bin/env bash
# High-performance background thumbnail generator for slideshow wallpapers
set -euo pipefail

WALLPAPER_DIR="${HOME}/Pictures/Wallpapers/Slideshow"
THUMB_DIR="${HOME}/.cache/nexa/wallpapers/slideshow_thumbs"

[ -d "$WALLPAPER_DIR" ] || exit 0
mkdir -p "$THUMB_DIR"

# Generate thumbnails for any new or missing images using vipsthumbnail (SIMD-accelerated)
if command -v fd >/dev/null 2>&1 && command -v vipsthumbnail >/dev/null 2>&1; then
    fd -e png -e jpg -e jpeg -e JPG -e webp . "$WALLPAPER_DIR" -x bash -c '
        target="'"$THUMB_DIR"'/{/.}.jpg"
        if [ ! -f "$target" ]; then
            vipsthumbnail "$1" -s 320x180 -o "$target" 2>/dev/null || true
        fi
    ' _ {}
fi

