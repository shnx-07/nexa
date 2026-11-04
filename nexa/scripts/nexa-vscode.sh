#!/usr/bin/env bash
# ==============================================================================
# Nexa VS Code Theme Sync Controller
# ==============================================================================
# Manages live desktop theme synchronization for VS Code / Code-OSS.
# Usage:
#   nexa-vscode.sh enable   - Enable live theme sync with Nexa
#   nexa-vscode.sh disable  - Disable theme sync and restore user's custom theme
#   nexa-vscode.sh status   - Check if theme sync is currently active
# ==============================================================================

set -euo pipefail

MATUGEN_CONF="$HOME/.config/matugen/config.toml"
MATUGEN_TEMPLATE="$HOME/.config/matugen/templates/vscode-settings.json"
CODE_SETTINGS="$HOME/.config/Code/User/settings.json"
OSS_SETTINGS="$HOME/.config/Code - OSS/User/settings.json"
THEME_CONF="$HOME/.config/nexa/config/theme.conf"
NEXAD="$HOME/.config/nexa/rust/target/release/nexad"

is_sync_enabled() {
    if [ -f "$MATUGEN_CONF" ] && grep -q '^\[templates\.vscode\]' "$MATUGEN_CONF"; then
        return 0
    fi
    return 1
}

enable_sync() {
    echo "==> Enabling Nexa VS Code Theme Sync..."

    # Ensure template exists
    if [ ! -f "$MATUGEN_TEMPLATE" ]; then
        echo "Error: Template '$MATUGEN_TEMPLATE' not found." >&2
        exit 1
    fi

    # Ensure Code User directory exists
    mkdir -p "$(dirname "$CODE_SETTINGS")"

    # Add template entry to config.toml if missing
    if ! is_sync_enabled; then
        cat <<'EOF' >> "$MATUGEN_CONF"

[templates.vscode]
input_path = "~/.config/matugen/templates/vscode-settings.json"
output_path = "~/.config/Code/User/settings.json"
EOF
    fi

    # Re-apply active theme to generate fresh settings
    if [ -x "$NEXAD" ] && [ -f "$THEME_CONF" ]; then
        PRESET=$(grep '^PRESET=' "$THEME_CONF" | cut -d'=' -f2 | tr -d '"' | tr -d "'")
        MODE=$(grep '^MODE=' "$THEME_CONF" | cut -d'=' -f2 | tr -d '"' | tr -d "'")
        if [ -n "$PRESET" ] && [ "$PRESET" != '""' ]; then
            "$NEXAD" theme apply-preset "$PRESET" "${MODE:-dark}" >/dev/null 2>&1 || true
        else
            "$NEXAD" theme apply-style preset "${MODE:-dark}" >/dev/null 2>&1 || true
        fi
    fi

    # Link for Code - OSS if installed
    if [ -d "$HOME/.config/Code - OSS" ]; then
        mkdir -p "$(dirname "$OSS_SETTINGS")"
        ln -sf "$CODE_SETTINGS" "$OSS_SETTINGS" 2>/dev/null || true
    fi

    echo "✔ VS Code live theme sync is now ENABLED."
}

disable_sync() {
    echo "==> Disabling Nexa VS Code Theme Sync..."

    # Remove template block from config.toml
    if [ -f "$MATUGEN_CONF" ]; then
        sed -i '/^\[templates\.vscode\]/,/^output_path = .*settings\.json/d' "$MATUGEN_CONF" 2>/dev/null || true
    fi

    # Remove workbench.colorCustomizations from settings.json
    for target in "$CODE_SETTINGS" "$OSS_SETTINGS"; do
        if [ -f "$target" ]; then
            python3 -c '
import json, sys
path = sys.argv[1]
try:
    with open(path, "r") as f:
        data = json.load(f)
    if "workbench.colorCustomizations" in data:
        del data["workbench.colorCustomizations"]
    with open(path, "w") as f:
        json.dump(data, f, indent=4)
        f.write("\n")
except Exception as e:
    pass
' "$target" 2>/dev/null || true
        fi
    done

    echo "✔ VS Code theme sync is now DISABLED. Custom themes will no longer be overridden."
}

show_status() {
    if is_sync_enabled; then
        echo "Nexa VS Code Theme Sync: ENABLED"
    else
        echo "Nexa VS Code Theme Sync: DISABLED"
    fi
}

case "${1:-status}" in
    enable|on|1)
        enable_sync
        ;;
    disable|off|0)
        disable_sync
        ;;
    status)
        show_status
        ;;
    *)
        echo "Usage: $(basename "$0") {enable|disable|status}"
        exit 1
        ;;
esac

