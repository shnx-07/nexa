#!/usr/bin/env bash

# Nexa Smart Show-Desktop / Minimize-All (Win+D)
# ------------------------------------------------------------
# Logic:
# - Press on W1: hides W1 windows to special:desktop
# - Press again on W1: restores W1 windows
# - If W1 is already hidden and user presses on W2:
#   1. Restores W1 windows back to W1 in the background
#   2. Hides W2 windows to special:desktop

STATE_FILE="${XDG_RUNTIME_DIR:-/tmp}/nexa_minimized_desktop.json"

ACTIVE_WS=$(hyprctl activeworkspace -j 2>/dev/null | jq -r '.id')
[[ -z "$ACTIVE_WS" || "$ACTIVE_WS" == "null" ]] && exit 0

restore_workspace() {
  local ws="$1"
  local addrs="$2"
  local last_addr=""

  for addr in $addrs; do
    [[ -z "$addr" ]] && continue
    hyprctl dispatch "hl.dsp.window.move({ workspace = \"${ws}\", window = \"address:${addr}\", silent = true })" >/dev/null 2>&1
    last_addr="$addr"
  done

  # If restoring the currently active workspace, restore focus
  if [[ "$ws" == "$ACTIVE_WS" && -n "$last_addr" ]]; then
    hyprctl dispatch "hl.dsp.focus({ window = \"address:${last_addr}\" })" >/dev/null 2>&1
  fi
}

hide_workspace() {
  local ws="$1"
  local addrs="$2"

  for addr in $addrs; do
    [[ -z "$addr" ]] && continue
    hyprctl dispatch "hl.dsp.window.move({ workspace = \"special:desktop\", window = \"address:${addr}\", silent = true })" >/dev/null 2>&1
  done
}

if [[ -f "$STATE_FILE" ]]; then
  SAVED_WS=$(jq -r '.ws' "$STATE_FILE" 2>/dev/null)
  SAVED_ADDRS=$(jq -r '.addrs[]' "$STATE_FILE" 2>/dev/null)

  if [[ "$SAVED_WS" == "$ACTIVE_WS" ]]; then
    # CASE 1: Toggle restore on the SAME workspace
    restore_workspace "$SAVED_WS" "$SAVED_ADDRS"
    rm -f "$STATE_FILE"
    exit 0
  else
    # CASE 2: Switching workspaces (e.g., W1 was hidden, now on W2)
    # First: restore W1 in the background
    restore_workspace "$SAVED_WS" "$SAVED_ADDRS"
    rm -f "$STATE_FILE"
    # Fall through to hide W2 below
  fi
fi

# CASE 3: Hide active workspace windows
CURRENT_ADDRS=$(hyprctl clients -j 2>/dev/null | jq -r --argjson ws "$ACTIVE_WS" '.[] | select(.workspace.id == $ws) | .address')

if [[ -n "$CURRENT_ADDRS" ]]; then
  # Save state
  jq -n --arg ws "$ACTIVE_WS" --argjson addrs "$(printf '%s\n' "$CURRENT_ADDRS" | jq -R . | jq -s .)" \
    '{ws: $ws, addrs: $addrs}' > "$STATE_FILE"

  hide_workspace "$ACTIVE_WS" "$CURRENT_ADDRS"
fi
