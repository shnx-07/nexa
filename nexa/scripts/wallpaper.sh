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

log() {
  printf '[NEXA wallpaper] %s
' "$*" | tee -a "$LOG_FILE"
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
  echo "Usage: wallpaper.sh <path> [monitor] [--restore] [--no-theme]"
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
  WALLPAPER="$(realpath "$WALLPAPER" 2>/dev/null || printf '%s' "$WALLPAPER")"
fi

if [[ ! -f "$WALLPAPER" && ! -d "$WALLPAPER" ]]; then
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

if [[ -d "$WALLPAPER" && -f "$WALLPAPER/project.json" ]]; then
  WALLPAPER_TYPE="we"
else
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
fi

log "Wallpaper: $WALLPAPER"
log "Type: $WALLPAPER_TYPE"
log "Monitor: $MONITOR"

# Stop legacy daemons if running
pkill -x mpvpaper 2>/dev/null || true
pkill -x awww-daemon 2>/dev/null || true

# ------------------------------------------------------------
# Apply via skwd-paper (Unified Vulkan Engine)
# ------------------------------------------------------------

apply_skwd() {
  local target="$MONITOR"
  if [[ "$target" == "ALL" ]]; then
    target="*"
  fi

  local kind_arg=()
  case "$WALLPAPER_TYPE" in
    image) kind_arg=("--kind" "static") ;;
    gif)   kind_arg=("--kind" "video") ;;
    video) kind_arg=("--kind" "video") ;;
    we)    kind_arg=("--kind" "we") ;;
  esac

  if [[ "$OPT_RESTORE" == "true" ]]; then
    log "Restoring wallpaper with instant display via skwd-paper..."
    skwd-paper-v2 apply "$target" "$WALLPAPER" "${kind_arg[@]}" --fill-mode fill --mute true >/dev/null 2>&1
    return $?
  fi

  # Complete pool of all 40 skwd-paper GPU shader transitions:
  local SHADER_POOL=(
    "fade"
    "pixelate"
    "iris"
    "glitch"
    "voronoi-shatter"
    "heat-melt"
    "plasma-flow"
    "ink-splash"
    "smoke"
    "chromatic-bloom"
    "inkwell-drop"
    "pixelfade-wave"
    "soft-warp-fade"
    "zoom-blur-pull"
    "mosaic-tumble"
    "crosswarp"
    "morph"
    "circle-crop"
    "colour-distance"
    "crossfade"
    "directional"
    "directional-scaled"
    "glitch-displace"
    "polka-dots-curtain"
    "puzzle-right"
    "crosshatch"
    "directional-wipe"
    "fadecolor"
    "parametric-glitch"
    "perlin"
    "randomsquares"
    "sand-bloom"
    "sand-maelstrom"
    "sand-murmuration"
    "sand-donut"
    "sand-globe"
    "sand-helix"
    "sand-galaxy"
    "sand-mobius"
    "sand-tornado"
  )
  local random_idx=$(( RANDOM % ${#SHADER_POOL[@]} ))
  local effect="${WALLPAPER_EFFECT:-${SHADER_POOL[$random_idx]}}"
  local duration="${WALLPAPER_DURATION:-950}"

  log "Applying wallpaper with dynamic GPU transition: effect=$effect, duration=${duration}ms"
  if ! skwd-paper-v2 apply "$target" "$WALLPAPER" "${kind_arg[@]}" --replace-all --effect "$effect" --duration-ms "$duration" --fill-mode fill --mute true >/dev/null 2>&1; then
    log "Transition apply failed, attempting direct apply..."
    skwd-paper-v2 apply "$target" "$WALLPAPER" "${kind_arg[@]}" --replace-all --fill-mode fill --mute true >/dev/null 2>&1 || return 1
  fi

  return 0
}

apply_skwd || {
  log "Failed to apply wallpaper via skwd-paper."
  exit 1
}

log "Wallpaper applied successfully via skwd-paper."

if [[ "$OPT_RESTORE" == true ]]; then
  log "Wallpaper restored (theme extraction skipped)."
  exit 0
fi

# ------------------------------------------------------------
# Generate theme source (for Matugen color palette)
# ------------------------------------------------------------

THEME_SOURCE="$WALLPAPER"

if [[ "$WALLPAPER_TYPE" == "gif" || "$WALLPAPER_TYPE" == "video" ]]; then
  if command -v ffmpeg >/dev/null 2>&1; then
    hash="$(printf '%s' "$WALLPAPER" | sha256sum | awk '{print $1}')"
    THEME_SOURCE="$THEME_CACHE/wallpaper-${hash}.jpg"

    if [[ ! -f "$THEME_SOURCE" ]]; then
      log "Extracting theme frame..."
      if ! ffmpeg -hide_banner -loglevel error -y -ss 1 -i "$WALLPAPER" -frames:v 1 "$THEME_SOURCE" 2>/dev/null; then
        log "Theme frame extraction failed."
        THEME_SOURCE=""
      fi
    fi
  fi
elif [[ "$WALLPAPER_TYPE" == "we" ]]; then
  if [[ -f "$WALLPAPER/preview.jpg" ]]; then
    THEME_SOURCE="$WALLPAPER/preview.jpg"
  elif [[ -f "$WALLPAPER/preview.png" ]]; then
    THEME_SOURCE="$WALLPAPER/preview.png"
  fi
fi

# ------------------------------------------------------------
# Generate lightweight thumbnail preview for picker
# ------------------------------------------------------------

THUMB_DIR="$CACHE_DIR/wallpapers/thumbs"
mkdir -p "$THUMB_DIR"
THUMB_FILE="$THUMB_DIR/${filename}.jpg"

if [[ ! -f "$THUMB_FILE" ]]; then
  if command -v ffmpeg >/dev/null 2>&1; then
    if [[ "$WALLPAPER_TYPE" == "gif" || "$WALLPAPER_TYPE" == "video" ]]; then
      ffmpeg -hide_banner -loglevel error -y -ss 1 -i "$WALLPAPER" -frames:v 1 -vf "scale=800:-2" -q:v 3 "$THUMB_FILE" 2>/dev/null || true
    elif [[ "$WALLPAPER_TYPE" == "image" ]]; then
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
  printf 'WALLPAPER=%q
' "$WALLPAPER"
  printf 'WALLPAPER_TYPE=%q
' "$WALLPAPER_TYPE"
  printf 'THEME_SOURCE=%q
' "$THEME_SOURCE"
  printf 'PREVIEW=%q
' "$PREVIEW"
  printf 'MONITOR=%q
' "$MONITOR"
} >"$WALLPAPER_CONFIG"

log "Wallpaper state saved."

# ------------------------------------------------------------
# Update wallpaper-based screen temperature
# ------------------------------------------------------------

NEXAD="$HOME/.config/nexa/rust/target/release/nexad"

if [[ -n "${THEME_SOURCE:-}" && -f "$THEME_SOURCE" ]]; then
  if [[ -x "$NEXAD" ]]; then
    log "Updating wallpaper screen temperature..."
    "$NEXAD" screenTemp wallpaper "$THEME_SOURCE" >>"$LOG_FILE" 2>&1 || true
  fi
fi

# ------------------------------------------------------------
# Apply selected NEXA theme mode (matugen colors)
# ------------------------------------------------------------

if [[ "$OPT_RESTORE" != "true" && -f "$THEME_SCRIPT" ]]; then
  log "Applying NEXA theme..."
  bash "$THEME_SCRIPT" apply >>"$LOG_FILE" 2>&1 || true
fi

log "Wallpaper pipeline complete."
exit 0
