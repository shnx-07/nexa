#!/usr/bin/env bash
# NEXA Avatar Manager
# Allows quick switching and previewing of lockscreen profile pictures.

AVATARS_DIR="$HOME/.config/nexa/avatars"
CONFIG_DIR="$HOME/.config/nexa"

case "$1" in
    list)
        echo "=== NEXA Curated Avatars ==="
        if [ -d "$AVATARS_DIR" ]; then
            for f in "$AVATARS_DIR"/*; do
                b=$(basename "$f" | sed 's/\.[^.]*$//')
                echo "  • $b ($f)"
            done
        fi
        echo ""
        echo "Custom avatar files can also be placed at ~/.face or ~/.config/nexa/avatar.png"
        ;;
    set)
        CHOSEN="$2"
        if [ -z "$CHOSEN" ]; then
            echo "Usage: nexa-avatar set <name-or-filepath>"
            exit 1
        fi

        # Remove previous active avatars
        rm -f "$CONFIG_DIR"/avatar.* "$HOME/.face"

        # Check if direct file
        if [ -f "$CHOSEN" ]; then
            ext="${CHOSEN##*.}"
            target_ext=$(echo "$ext" | tr '[:upper:]' '[:lower:]')
            dest="$CONFIG_DIR/avatar.$target_ext"
            cp -f "$CHOSEN" "$dest"
            cp -f "$CHOSEN" "$HOME/.face"
            echo "✓ Avatar updated from: $CHOSEN -> $dest"
        # Check in curated directory
        elif [ -f "$AVATARS_DIR/${CHOSEN}.svg" ]; then
            dest="$CONFIG_DIR/avatar.svg"
            cp -f "$AVATARS_DIR/${CHOSEN}.svg" "$dest"
            cp -f "$AVATARS_DIR/${CHOSEN}.svg" "$HOME/.face"
            echo "✓ Active avatar set to preset: $CHOSEN"
        elif [ -f "$AVATARS_DIR/${CHOSEN}.png" ]; then
            dest="$CONFIG_DIR/avatar.png"
            cp -f "$AVATARS_DIR/${CHOSEN}.png" "$dest"
            cp -f "$AVATARS_DIR/${CHOSEN}.png" "$HOME/.face"
            echo "✓ Active avatar set to preset: $CHOSEN"
        else
            echo "Error: Avatar '$CHOSEN' not found in $AVATARS_DIR or as a file."
            exit 1
        fi

        # Quick restart of NEXA to load the new avatar
        if [ -f "$CONFIG_DIR/scripts/nexa-restart.sh" ]; then
            bash "$CONFIG_DIR/scripts/nexa-restart.sh" >/dev/null 2>&1
        fi
        ;;
    *)
        echo "NEXA Avatar Tool"
        echo "  nexa-avatar list           List available avatar presets"
        echo "  nexa-avatar set <name>     Set avatar (e.g. cyber_neon, astro_space, mecha_cat)"
        echo "  nexa-avatar set <path>     Set custom image from disk"
        ;;
esac
