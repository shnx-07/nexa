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
OPT_RESTORE=false

for arg in "$@"; do
  case "$arg" in
    --no-theme|--restore)
      OPT_RESTORE=true
      ;;
  esac
done

if [[ -z "$WALLPAPER" ]]; then
  usage
  exit 1
fi

# ------------------------------------------------------------
# Support 'next', 'shuffle', or 'random'
# ------------------------------------------------------------

if [[ "$WALLPAPER" == "next" || "$WALLPAPER" == "shuffle" || "$WALLPAPER" == "random" ]]; then
  WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
  if [[ ! -d "$WALLPAPER_DIR" ]]; then
    WALLPAPER_DIR="$HOME/.config/nexa/wallpapers"
  fi
  CURRENT_WP=""
  if [[ -f "$WALLPAPER_CONFIG" ]]; then
    CURRENT_WP=$(grep '^WALLPAPER=' "$WALLPAPER_CONFIG" 2>/dev/null | cut -d'=' -f2-)
  fi
  CANDIDATE=$(find "$WALLPAPER_DIR" -maxdepth 2 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" -o -iname "*.gif" -o -iname "*.mp4" \) ! -path "*/.*" ! -path "*/thumbs/*" ! -path "*/slideshow_thumbs/*" 2>/dev/null | grep -F -v -x "$CURRENT_WP" | shuf -n 1)
  if [[ -z "$CANDIDATE" ]]; then
    CANDIDATE=$(find "$WALLPAPER_DIR" -maxdepth 2 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" -o -iname "*.gif" -o -iname "*.mp4" \) ! -path "*/.*" 2>/dev/null | shuf -n 1)
  fi
  if [[ -n "$CANDIDATE" && -f "$CANDIDATE" ]]; then
    WALLPAPER="$CANDIDATE"
    log "Resolved shuffle/next wallpaper to: $WALLPAPER"
  else
    log "No wallpapers found in $WALLPAPER_DIR"
    exit 1
  fi
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
    pkill -CONT -x mpvpaper 2>/dev/null || true
    pkill -x mpvpaper 2>/dev/null || true
    local i=0
    while pgrep -x mpvpaper >/dev/null 2>&1 && (( i < 6 )); do
      sleep 0.05
      ((i++))
    done
    pkill -9 -x mpvpaper 2>/dev/null || true
  fi
}

# ------------------------------------------------------------
# Static wallpaper & GIF
# ------------------------------------------------------------

get_transition_args() {
  local nexad="$HOME/.config/nexa/rust/target/release/nexad"
  if [[ -x "$nexad" ]]; then
    local res
    res="$("$nexad" wallpaper transition-args 2>/dev/null)"
    if [[ -n "$res" ]]; then
      echo "$res"
      return 0
    fi
  fi
  # Fallback if nexad is unavailable
  echo "--transition-type wave --transition-angle 45 --transition-wave 35,18 --transition-duration 1.2 --transition-fps 60 --transition-bezier .42,0,.58,1 -f Bilinear"
}

apply_static() {
  if ! command -v awww >/dev/null 2>&1; then
    log "awww is not installed."
    return 1
  fi

  if [[ "$OPT_RESTORE" == "true" ]]; then
    log "Restoring wallpaper with instant transition (none)"
    stop_mpvpaper
    awww unpause 2>/dev/null || true
    if [[ "$MONITOR" == "*" || "$MONITOR" == "ALL" ]]; then
      awww img "$WALLPAPER" --transition-type none || return 1
    else
      awww img -o "$MONITOR" "$WALLPAPER" --transition-type none || return 1
    fi
    return 0
  fi

  local trans_args
  trans_args="$(get_transition_args)"

  # SEAMLESS VIDEO -> IMAGE HANDSHAKE:
  # If mpvpaper is currently running, synchronize awww with the video's poster thumbnail first
  # while mpvpaper is still rendering on top. Then stop mpvpaper cleanly, and run the transition!
  if pgrep -x mpvpaper >/dev/null 2>&1; then
    local prev_theme=""
    if [[ -f "$WALLPAPER_CONFIG" ]]; then
      prev_theme=$(grep "^THEME_SOURCE=" "$WALLPAPER_CONFIG" | cut -d= -f2- | tr -d '"'"'")
    fi

    awww unpause 2>/dev/null || true

    if [[ -n "$prev_theme" && -f "$prev_theme" ]]; then
      log "Priming awww with video poster frame: $prev_theme"
      if [[ "$MONITOR" == "*" || "$MONITOR" == "ALL" ]]; then
        awww img "$prev_theme" --transition-type none -f Bilinear 2>/dev/null || true
      else
        awww img -o "$MONITOR" "$prev_theme" --transition-type none -f Bilinear 2>/dev/null || true
      fi
      sleep 0.05
    fi

    # Stop mpvpaper now that awww is holding the exact still frame of the video!
    stop_mpvpaper

    log "Applying wallpaper with transition: $trans_args"

    # Start the full, uninterrupted transition from that still frame to the new wallpaper
    if [[ "$MONITOR" == "*" || "$MONITOR" == "ALL" ]]; then
      # shellcheck disable=SC2086
      awww img "$WALLPAPER" $trans_args || return 1
    else
      # shellcheck disable=SC2086
      awww img -o "$MONITOR" "$WALLPAPER" $trans_args || return 1
    fi
  else
    stop_mpvpaper
    awww unpause 2>/dev/null || true

    log "Applying wallpaper with transition: $trans_args"

    if [[ "$MONITOR" == "*" || "$MONITOR" == "ALL" ]]; then
      # shellcheck disable=SC2086
      if ! awww img "$WALLPAPER" $trans_args; then
        log "awww failed to apply wallpaper."
        return 1
      fi
    else
      # shellcheck disable=SC2086
      if ! awww img -o "$MONITOR" "$WALLPAPER" $trans_args; then
        log "awww failed to apply wallpaper on $MONITOR."
        return 1
      fi
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

  local target="$MONITOR"
  if [[ "$target" == "*" ]]; then
    target="ALL"
  fi

  # Generate poster thumbnail (at 0.0s) for seamless entry transition
  local hash
  hash="$(printf '%s' "$WALLPAPER" | sha256sum | awk '{print $1}')"
  local poster="$THEME_CACHE/firstframe-${hash}.jpg"

  if [[ ! -f "$poster" ]] && command -v ffmpeg >/dev/null 2>&1; then
    ffmpeg -loglevel error -ss 0.0 -i "$WALLPAPER" -frames:v 1 -vf "scale=1920:-2" -q:v 3 -y "$poster" 2>/dev/null || true
  fi
  # Fallback to theme frame if firstframe extraction failed
  if [[ ! -f "$poster" ]]; then
    poster="$THEME_CACHE/wallpaper-${hash}.jpg"
  fi

  local trans_args
  trans_args="$(get_transition_args)"

  # SEAMLESS VIDEO -> VIDEO HANDSHAKE:
  # If mpvpaper is ALREADY running (e.g. video to video transition), prime awww with the previous
  # video's frame first, stop old mpvpaper so the previous frame is held visibly on screen,
  # and only then run the transition into the new video's frame!
  if pgrep -x mpvpaper >/dev/null 2>&1; then
    local prev_theme=""
    if [[ -f "$WALLPAPER_CONFIG" ]]; then
      prev_theme=$(grep "^THEME_SOURCE=" "$WALLPAPER_CONFIG" | cut -d= -f2- | tr -d '"'"'")
    fi
    awww unpause 2>/dev/null || true
    if [[ -n "$prev_theme" && -f "$prev_theme" ]]; then
      if [[ "$target" == "ALL" ]]; then
        awww img "$prev_theme" --transition-type none -f Bilinear 2>/dev/null || true
      else
        awww img -o "$target" "$prev_theme" --transition-type none -f Bilinear 2>/dev/null || true
      fi
      sleep 0.05
    fi
    stop_mpvpaper
  fi

  # 1. Transition awww into the new video's first frame and wait for it to complete 100%!
  if [[ -f "$poster" ]] && command -v awww >/dev/null 2>&1; then
    awww unpause 2>/dev/null || true
    log "Transitioning into video poster frame with: $trans_args"
    if [[ "$target" == "ALL" ]]; then
      # shellcheck disable=SC2086
      awww img "$poster" $trans_args 2>/dev/null || true
    else
      # shellcheck disable=SC2086
      awww img -o "$target" "$poster" $trans_args 2>/dev/null || true
    fi

    # Wait for the transition to finish completely so it is NEVER cut off mid-way!
    local dur
    dur=$(echo "$trans_args" | grep -oP '(?<=--transition-duration )\d+(\.\d+)?' | head -n 1)
    dur="${dur:-1.2}"
    # Add 0.15s margin to ensure the bezier curve completes its final settle step
    dur=$(awk -v d="$dur" 'BEGIN { printf "%.2f", d + 0.15 }' 2>/dev/null || echo "$dur")
    sleep "$dur"
  fi

  stop_mpvpaper

  # 2. Start mpvpaper seamlessly over the matching completed first frame
  if ! mpvpaper \
    --fork \
    -p \
    -o "no-audio loop-file=inf hwdec=auto-safe profile=fast opengl-pbo=yes framedrop=vo video-sync=desync demuxer-max-bytes=20M demuxer-max-back-bytes=5M input-terminal=no input-default-bindings=no" \
    "$target" \
    "$WALLPAPER"; then
    log "mpvpaper failed to start."
    return 1
  fi

  (
    sleep 1.0
    awww pause 2>/dev/null || true
  ) &

  return 0
}

# ------------------------------------------------------------
# Apply wallpaper
# ------------------------------------------------------------

case "$WALLPAPER_TYPE" in

image | gif)
  apply_static || exit 1
  ;;

video)
  apply_animated || exit 1
  ;;

esac

log "Wallpaper applied successfully."

if [[ "$OPT_RESTORE" == true ]]; then
  log "Wallpaper restored (theme extraction and application skipped)."
  exit 0
fi

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
# Generate lightweight thumbnail preview
# ------------------------------------------------------------

THUMB_DIR="$CACHE_DIR/wallpapers/thumbs"
mkdir -p "$THUMB_DIR"
THUMB_FILE="$THUMB_DIR/${filename}.jpg"

if [[ ! -f "$THUMB_FILE" ]]; then
  if command -v ffmpeg >/dev/null 2>&1; then
    if [[ "$WALLPAPER_TYPE" == "gif" || "$WALLPAPER_TYPE" == "video" ]]; then
      ffmpeg -hide_banner -loglevel error -y -ss 1 -i "$WALLPAPER" -frames:v 1 -vf "scale=800:-2" -q:v 3 "$THUMB_FILE" 2>/dev/null || true
    else
      ffmpeg -hide_banner -loglevel error -y -i "$WALLPAPER" -vf "scale=1200:-2" -q:v 3 "$THUMB_FILE" 2>/dev/null || true
    fi
  fi
fi

PREVIEW="$WALLPAPER"
if [[ -f "$THUMB_FILE" ]]; then
  PREVIEW="$THUMB_FILE"
elif [[ -n "${THEME_SOURCE:-}" && -f "$THEME_SOURCE" ]]; then
  PREVIEW="$THEME_SOURCE"
fi

# ------------------------------------------------------------
# Save persistent wallpaper state
# ------------------------------------------------------------

{
  printf 'WALLPAPER=%q\n' "$WALLPAPER"
  printf 'WALLPAPER_TYPE=%q\n' "$WALLPAPER_TYPE"
  printf 'THEME_SOURCE=%q\n' "$THEME_SOURCE"
  printf 'PREVIEW=%q\n' "$PREVIEW"
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
# Apply selected NEXA theme mode (skipped during restore)
# ------------------------------------------------------------

if [[ "$OPT_RESTORE" != "true" && -f "$THEME_SCRIPT" ]]; then

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
