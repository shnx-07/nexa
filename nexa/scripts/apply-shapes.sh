#!/usr/bin/env bash
set -u

ROUNDING="${1:-10}"
BORDER_SIZE="${2:-0}"
STYLE="${3:-standard}"

# SEC-01: Validate numeric inputs to prevent code/Lua injection into Hyprland
if ! [[ "$ROUNDING" =~ ^[0-9]+$ ]]; then
  echo "Error: ROUNDING must be an unsigned integer." >&2
  exit 1
fi

if ! [[ "$BORDER_SIZE" =~ ^[0-9]+$ ]]; then
  echo "Error: BORDER_SIZE must be an unsigned integer." >&2
  exit 1
fi

# Sanitize STYLE to safe identifier characters only
STYLE=$(echo "$STYLE" | tr -cd "a-zA-Z0-9_-")
if [[ -z "$STYLE" ]]; then
  STYLE="standard"
fi

CONFIG_DIR="$HOME/.config/nexa/config"
mkdir -p "$CONFIG_DIR"
SHAPES_JSON="$CONFIG_DIR/shapes.json"

# 1. Update shapes.json
cat > "$SHAPES_JSON" <<JSON
{
  "rounding": $ROUNDING,
  "border_size": $BORDER_SIZE,
  "style": "$STYLE"
}
JSON

# 2. Apply live to Hyprland via hyprctl eval
if command -v hyprctl >/dev/null 2>&1; then
  hyprctl eval "hl.config({ general = { border_size = $BORDER_SIZE }, decoration = { rounding = $ROUNDING } })" >/dev/null 2>&1 || true
fi

# 3. Update hyprland decorations.lua for persistence across reboots
DECORATIONS_LUA="$HOME/.config/hypr/config/decorations.lua"
if [[ -f "$DECORATIONS_LUA" ]]; then
  sed -i -E "s/border_size = [0-9]+/border_size = $BORDER_SIZE/g" "$DECORATIONS_LUA"
  sed -i -E "s/rounding = [0-9]+/rounding = $ROUNDING/g" "$DECORATIONS_LUA"
fi
