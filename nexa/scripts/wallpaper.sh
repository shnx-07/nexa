#!/usr/bin/env bash

set -u

# ------------------------------------------------------------
# Paths
# ------------------------------------------------------------

NEXA_DIR="$HOME/.config/nexa"
CONFIG_DIR="$NEXA_DIR/config"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/nexa"

THEME_CACHE="$CACHE_DIR/theme"
LOG_FILE="$CACHE_DIR/wallpaper.log"

WALLPAPER_CONFIG="$CONFIG_DIR/wallpaper.conf"
THEME_SCRIPT="$NEXA_DIR/scripts/theme.sh"

mkdir -p "$CONFIG_DIR"
mkdir -p "$THEME_CACHE"

# ------------------------------------------------------------
# Logging
# ------------------------------------------------------------

log() {
  printf '[NEXA wallpaper] %s\n' "$*" | tee -a "$LOG_FILE"
}

# ------------------------------------------------------------
# Usage
# ------------------------------------------------------------

usage() {
  cat <<EOF
Usage:

  wallpaper.sh <wallpaper> [monitor]

Examples:

  wallpaper.sh ~/Pictures/Wallpapers/test.png
  wallpaper.sh ~/Pictures/Wallpapers/test.gif
  wallpaper.sh ~/Pictures/Wallpapers/test.mp4

  wallpaper.sh ~/Pictures/Wallpapers/test.png eDP-1

Monitor defaults to all outputs.
EOF
}

# ------------------------------------------------------------
# Arguments
# ------------------------------------------------------------

WALLPAPER="${1:-}"
MONITOR="${2:-*}"

if [[ -z "$WALLPAPER" ]]; then
  usage
  exit 1
fi

# ------------------------------------------------------------
# Resolve wallpaper path
# ------------------------------------------------------------

if [[ "$WALLPAPER" == "~/"* ]]; then
  WALLPAPER="$HOME/${WALLPAPER#~/}"
fi

if command -v realpath >/dev/null 2>&1; then
  WALLPAPER="$(
    realpath "$WALLPAPER" 2>/dev/null ||
      printf '%s' "$WALLPAPER"
  )"
fi

if [[ ! -f "$WALLPAPER" ]]; then
  log "Wallpaper does not exist: $WALLPAPER"
  exit 1
fi

# ------------------------------------------------------------
# Detect type
# ------------------------------------------------------------

filename="${WALLPAPER##*/}"
extension="${filename##*.}"
extension="${extension,,}"

WALLPAPER_TYPE=""

case "$extension" in

png | jpg | jpeg | webp)
  WALLPAPER_TYPE="image"
  ;;

gif)
  WALLPAPER_TYPE="gif"
  ;;

mp4 | mkv | webm | mov)
  WALLPAPER_TYPE="video"
  ;;

*)
  log "Unsupported wallpaper type: .$extension"
  exit 1
  ;;

esac

log "Wallpaper: $WALLPAPER"
log "Type: $WALLPAPER_TYPE"
log "Monitor: $MONITOR"

# ------------------------------------------------------------
# Stop existing video wallpaper
# ------------------------------------------------------------

stop_mpvpaper() {
  if pgrep -x mpvpaper >/dev/null 2>&1; then
    pkill -x mpvpaper 2>/dev/null || true
  fi
}

# ------------------------------------------------------------
# Static wallpaper
# ------------------------------------------------------------

apply_static() {
  if ! command -v awww >/dev/null 2>&1; then
    log "awww is not installed."
    return 1
  fi

  stop_mpvpaper

  if [[ "$MONITOR" == "*" || "$MONITOR" == "ALL" ]]; then

    if ! awww img "$WALLPAPER"; then
      log "awww failed to apply wallpaper."
      return 1
    fi

  else

    if ! awww img -o "$MONITOR" "$WALLPAPER"; then
      log "awww failed to apply wallpaper on $MONITOR."
      return 1
    fi

  fi

  return 0
}

# ------------------------------------------------------------
# Animated wallpaper
# ------------------------------------------------------------

apply_animated() {
  if ! command -v mpvpaper >/dev/null 2>&1; then
    log "mpvpaper is not installed."
    return 1
  fi

  stop_mpvpaper

  local target="$MONITOR"

  if [[ "$target" == "*" ]]; then
    target="ALL"
  fi

  mpvpaper \
    -o "no-audio loop-file=inf" \
    "$target" \
    "$WALLPAPER" \
    >>"$LOG_FILE" 2>&1 &

  disown

  sleep 0.2

  if ! pgrep -x mpvpaper >/dev/null 2>&1; then
    log "mpvpaper failed to start."
    return 1
  fi

  return 0
}

# ------------------------------------------------------------
# Apply wallpaper
# ------------------------------------------------------------

case "$WALLPAPER_TYPE" in

image)
  apply_static || exit 1
  ;;

gif | video)
  apply_animated || exit 1
  ;;

esac

log "Wallpaper applied successfully."

# ------------------------------------------------------------
# Generate theme source
#
# Static image:
#   wallpaper itself
#
# GIF/video:
#   cached representative JPG frame
# ------------------------------------------------------------

THEME_SOURCE="$WALLPAPER"

if [[ "$WALLPAPER_TYPE" == "gif" || "$WALLPAPER_TYPE" == "video" ]]; then

  if command -v ffmpeg >/dev/null 2>&1; then

    hash="$(
      printf '%s' "$WALLPAPER" |
        sha256sum |
        awk '{print $1}'
    )"

    THEME_SOURCE="$THEME_CACHE/wallpaper-${hash}.jpg"

    log "Extracting theme frame..."

    if ! ffmpeg \
      -hide_banner \
      -loglevel error \
      -y \
      -ss 1 \
      -i "$WALLPAPER" \
      -frames:v 1 \
      "$THEME_SOURCE"; then
      log "Theme frame extraction failed."
      THEME_SOURCE=""
    fi

  else

    log "ffmpeg unavailable; animated wallpaper theme extraction skipped."
    THEME_SOURCE=""

  fi
fi

# ------------------------------------------------------------
# Save persistent wallpaper state
# ------------------------------------------------------------

{
  printf 'WALLPAPER=%q\n' "$WALLPAPER"
  printf 'WALLPAPER_TYPE=%q\n' "$WALLPAPER_TYPE"
  printf 'THEME_SOURCE=%q\n' "$THEME_SOURCE"
  printf 'MONITOR=%q\n' "$MONITOR"
} >"$WALLPAPER_CONFIG"

log "Wallpaper state saved."

# ------------------------------------------------------------
# Update wallpaper-based screen temperature
# ------------------------------------------------------------

NEXAD="$HOME/.config/nexa/rust/target/release/nexad"

if [[ -n "${THEME_SOURCE:-}" && -f "$THEME_SOURCE" ]]; then
  if [[ -x "$NEXAD" ]]; then

    log "Updating wallpaper screen temperature..."

    if ! "$NEXAD" screenTemp wallpaper "$THEME_SOURCE" >>"$LOG_FILE" 2>&1; then
      log "Wallpaper temperature analysis failed."
    fi

  else
    log "nexad not found or not executable: $NEXAD"
  fi
else
  log "No usable theme source for screen temperature analysis."
fi

# ------------------------------------------------------------
# Apply selected NEXA theme mode
# ------------------------------------------------------------

if [[ -f "$THEME_SCRIPT" ]]; then

  log "Applying NEXA theme..."
  log "Theme script: $THEME_SCRIPT"

  if bash "$THEME_SCRIPT" apply >>"$LOG_FILE" 2>&1; then
    log "Theme apply completed successfully."
  else
    theme_status=$?

    log "Theme apply failed with exit code: $theme_status"
    log "Wallpaper remains applied."
  fi

else

  log "Theme script not found: $THEME_SCRIPT"

fi

# ------------------------------------------------------------
# Done
# ------------------------------------------------------------

log "Wallpaper pipeline complete."

exit 0
