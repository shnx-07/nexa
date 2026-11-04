#!/usr/bin/env bash
# ==============================================================================
# Nexa SDDM Theme Applicator (Polkit Helper)
#
# Called via pkexec to install and activate an SDDM theme from Nexa's registry.
# Usage:
#   pkexec /home/shnx/.config/nexa/scripts/sddm-apply.sh <theme-name> [wallpaper-path]
# ==============================================================================

set -euo pipefail

THEME_NAME="${1:-}"
WALLPAPER_SRC="${2:-}"

if [ -z "$THEME_NAME" ]; then
    echo "Error: No theme name specified." >&2
    exit 1
fi

# Security: strictly sanitize theme name to prevent directory traversal or injection
if [[ ! "$THEME_NAME" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    echo "Error: Invalid theme name characters '$THEME_NAME'. Allowed: [a-zA-Z0-9_-]" >&2
    exit 1
fi

REAL_USER="${SUDO_USER:-${DOAS_USER:-${PKEXEC_UID:-}}}"
if [ -n "$REAL_USER" ] && [ "$REAL_USER" != "root" ]; then
    USER_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)
else
    USER_HOME="/home/shnx"
fi

NEXA_SDDM_DIR="$USER_HOME/.config/nexa/sddm"
THEME_SRC="$NEXA_SDDM_DIR/themes/$THEME_NAME"
SYSTEM_THEMES_DIR="/usr/share/sddm/themes"
SDDM_CONF_DIR="/etc/sddm.conf.d"
SDDM_CONF="$SDDM_CONF_DIR/theme.conf"

if [ ! -d "$THEME_SRC" ]; then
    echo "Error: Theme '$THEME_NAME' not found in '$THEME_SRC'." >&2
    exit 2
fi

echo "[Nexa SDDM] Installing theme '$THEME_NAME'..."

mkdir -p "$SYSTEM_THEMES_DIR"
rm -rf "$SYSTEM_THEMES_DIR/$THEME_NAME"
cp -r "$THEME_SRC" "$SYSTEM_THEMES_DIR/$THEME_NAME"

# Copy QML compatibility imports if present
if [ -d "$NEXA_SDDM_DIR/imports" ]; then
    cp -r "$NEXA_SDDM_DIR/imports/"* "$SYSTEM_THEMES_DIR/$THEME_NAME/" 2>/dev/null || true
fi

# Helper function to validate image or video MIME type
is_valid_media() {
    local target="$1"
    if [ ! -f "$target" ]; then return 1; fi
    local mime
    mime=$(file -b --mime-type "$target" 2>/dev/null || true)
    case "$mime" in
        image/*|video/*) return 0 ;;
        *) return 1 ;;
    esac
}

# Apply wallpaper if specified or available from wallpaper.conf
if [ -n "$WALLPAPER_SRC" ] && is_valid_media "$WALLPAPER_SRC"; then
    echo "[Nexa SDDM] Syncing active wallpaper: $WALLPAPER_SRC"
    cp "$WALLPAPER_SRC" "$SYSTEM_THEMES_DIR/$THEME_NAME/bg.png"
    chmod 644 "$SYSTEM_THEMES_DIR/$THEME_NAME/bg.png"
elif [ -f "$USER_HOME/.config/nexa/config/wallpaper.conf" ]; then
    CONF_WP=$(grep '^WALLPAPER=' "$USER_HOME/.config/nexa/config/wallpaper.conf" | cut -d'=' -f2- | tr -d '"' | tr -d "'")
    if [ -n "$CONF_WP" ] && is_valid_media "$CONF_WP"; then
        echo "[Nexa SDDM] Syncing wallpaper from wallpaper.conf: $CONF_WP"
        cp "$CONF_WP" "$SYSTEM_THEMES_DIR/$THEME_NAME/bg.png" 2>/dev/null || true
        chmod 644 "$SYSTEM_THEMES_DIR/$THEME_NAME/bg.png" 2>/dev/null || true
    fi
fi

# Ensure QtVersion=6 in metadata.desktop so SDDM always uses sddm-greeter-qt6
TARGET_META="$SYSTEM_THEMES_DIR/$THEME_NAME/metadata.desktop"
if [ ! -f "$TARGET_META" ]; then
    cat <<EOF > "$TARGET_META"
[SddmGreeterTheme]
Name=$THEME_NAME
Description=Nexa SDDM Theme
Author=Nexa
Type=sddm-theme
MainScript=Main.qml
ConfigFile=theme.conf
QtVersion=6
EOF
else
    if grep -q "^QtVersion=" "$TARGET_META"; then
        sed -i "s|^QtVersion=.*|QtVersion=6|" "$TARGET_META"
    else
        printf "\nQtVersion=6\n" >> "$TARGET_META"
    fi
fi

# Ensure theme.conf exists
TARGET_CONF="$SYSTEM_THEMES_DIR/$THEME_NAME/theme.conf"
if [ ! -f "$TARGET_CONF" ]; then
    printf "[General]\nbackground=bg.png\n" > "$TARGET_CONF"
fi

# Ensure all files in the installed theme are readable
chmod -R 755 "$SYSTEM_THEMES_DIR/$THEME_NAME"
find "$SYSTEM_THEMES_DIR/$THEME_NAME" -type f -exec chmod 644 {} +
find "$SYSTEM_THEMES_DIR/$THEME_NAME" -type d -exec chmod 755 {} +

# Update SDDM configuration
mkdir -p "$SDDM_CONF_DIR"

if [ ! -f "$SDDM_CONF" ]; then
    printf "[Theme]\nCurrent=%s\n" "$THEME_NAME" > "$SDDM_CONF"
else
    if grep -q "^Current=" "$SDDM_CONF"; then
        sed -i "s|^Current=.*|Current=$THEME_NAME|" "$SDDM_CONF"
    elif grep -q "^\[Theme\]" "$SDDM_CONF"; then
        sed -i "/^\[Theme\]/a Current=$THEME_NAME" "$SDDM_CONF"
    else
        printf "\n[Theme]\nCurrent=%s\n" "$THEME_NAME" >> "$SDDM_CONF"
    fi
fi

chmod 644 "$SDDM_CONF"

# Record the currently active SDDM theme in user config for GUI reflection
mkdir -p "$USER_HOME/.config/nexa/config"
printf "%s\n" "$THEME_NAME" > "$USER_HOME/.config/nexa/config/sddm_theme"
if [ -n "$REAL_USER" ] && [ "$REAL_USER" != "root" ]; then
    chown "$REAL_USER":"$REAL_USER" "$USER_HOME/.config/nexa/config/sddm_theme" 2>/dev/null || true
fi

echo "[Nexa SDDM] Theme '$THEME_NAME' successfully activated!"
exit 0

