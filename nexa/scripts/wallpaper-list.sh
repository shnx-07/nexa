#!/usr/bin/env bash

set -u

DIR="${1:-$HOME/Pictures/Wallpapers}"

[[ -d "$DIR" ]] || exit 0

find "$DIR" -maxdepth 1 -type f | sort | while IFS= read -r file; do
  ext="${file##*.}"
  ext="${ext,,}"

  case "$ext" in
  png | jpg | jpeg | webp)
    printf 'image|%s\n' "$file"
    ;;

  gif)
    printf 'gif|%s\n' "$file"
    ;;

  mp4 | mkv | mov | webm)
    printf 'video|%s\n' "$file"
    ;;
  esac
done
