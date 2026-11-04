#!/usr/bin/env bash
# ==============================================================================
# NEXA Desktop Manager (Unified Control Script)
# ==============================================================================
# Single entry-point to control, build, and restart the NEXA desktop environment.
# Usage:
#   Interactive:  ./nexa.sh
#   Direct CLI:   ./nexa.sh [1|2|3|4|5|6|7|restart|start|stop|build|fresh-build|status|theme-sync]
# ==============================================================================

set -e

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/nexa"
RUST_DIR="$CONFIG_DIR/rust"
SHELL_PATH="$CONFIG_DIR/quickshell"
RUNTIME_NEXA="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/nexa"

# Colors for terminal output
BOLD="\033[1m"
CYAN="\033[0;36m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RED="\033[0;31m"
DIM="\033[0;2m"
RESET="\033[0m"

# ------------------------------------------------------------------------------
# Action Functions
# ------------------------------------------------------------------------------

do_stop() {
    echo -e "${YELLOW}==> Stopping NEXA QuickShell...${RESET}"
    pkill -TERM -x "quickshell" 2>/dev/null || true
    pkill -TERM -f "quickshell.*$SHELL_PATH" 2>/dev/null || true

    for i in {1..6}; do
        if ! pgrep -x "quickshell" >/dev/null 2>&1; then
            break
        fi
        sleep 0.05
    done

    pkill -KILL -x "quickshell" 2>/dev/null || true
    pkill -KILL -f "quickshell.*$SHELL_PATH" 2>/dev/null || true
    echo -e "${GREEN}[✔] NEXA stopped.${RESET}"
}

do_start() {
    echo -e "${CYAN}==> Starting NEXA QuickShell...${RESET}"
    if pgrep -x "quickshell" >/dev/null 2>&1 || pgrep -f "quickshell.*$SHELL_PATH" >/dev/null 2>&1; then
        echo -e "${YELLOW}[!] NEXA is already running.${RESET}"
        return 0
    fi

    cd "$HOME"
    export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-1}"
    export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
    export QS_ICON_THEME="breeze-dark"
    export QS_NO_RELOAD_POPUP=1
    setsid quickshell -p "$SHELL_PATH" >/tmp/nexa-quickshell.log 2>&1 &
    disown

    echo -e "${GREEN}[✔] NEXA started successfully.${RESET}"
}

do_restart() {
    echo -e "${CYAN}==> Restarting NEXA QuickShell...${RESET}"
    if [ -f "$RUNTIME_NEXA/locked" ]; then
        mkdir -p "$RUNTIME_NEXA"
        touch "$RUNTIME_NEXA/restart-pending"
        echo -e "${YELLOW}[!] Session locked: restart deferred until unlock.${RESET}"
        return 0
    fi

    do_stop
    sleep 0.2
    do_start
}

do_build() {
    echo -e "${CYAN}==> Building NEXA Rust Engine (incremental release)...${RESET}"
    cd "$RUST_DIR"
    cargo build --release
    echo -e "${GREEN}[✔] Incremental build complete: $RUST_DIR/target/release/nexad${RESET}"
}

do_fresh_build() {
    echo -e "${YELLOW}==> Cleaning NEXA build cache (cargo clean)...${RESET}"
    cd "$RUST_DIR"
    cargo clean
    echo -e "${CYAN}==> Performing fresh release build from scratch...${RESET}"
    cargo build --release
    echo -e "${GREEN}[✔] Fresh build complete: $RUST_DIR/target/release/nexad${RESET}"
}

do_status() {
    echo -e "${BOLD}${CYAN}==> NEXA Environment Status${RESET}"
    echo ""
    NEXAD_BIN="$RUST_DIR/target/release/nexad"
    if [ -x "$NEXAD_BIN" ]; then
        "$NEXAD_BIN" hypr autostart status || true
    else
        echo -e "${YELLOW}[!] nexad binary not found at $NEXAD_BIN. Run build first.${RESET}"
    fi

    echo -e "${BOLD}Running Processes:${RESET}"
    pgrep -a -x "quickshell" || echo -e "${DIM}  • QuickShell: stopped${RESET}"
    pgrep -a -f "nexad.*watch" || echo -e "${DIM}  • NEXA Watchers: none${RESET}"
    echo ""
}

do_theme_sync() {
    echo -e "${CYAN}==> Synchronizing NEXA Theme across Qt, GTK, Chrome & Terminals...${RESET}"

    # 1. Strip legacy overrides from GTK 3 & 4
    for gtk_css in "$HOME/.config/gtk-3.0/gtk.css" "$HOME/.config/gtk-4.0/gtk.css"; do
        if [ -f "$gtk_css" ]; then
            sed -i '/noctalia\.css/d' "$gtk_css"
            echo -e "  ${GREEN}✔${RESET} Cleaned legacy imports from $(basename "$(dirname "$gtk_css")")/gtk.css"
        fi
    done

    # 2. Clean Alacritty themes
    ALACRITTY_CONF="$HOME/.config/alacritty/alacritty.toml"
    if [ -f "$ALACRITTY_CONF" ]; then
        sed -i '/noctalia\.toml/d' "$ALACRITTY_CONF"
        echo -e "  ${GREEN}✔${RESET} Sanitized Alacritty configuration"
    fi

    # 3. Clean btop theme
    BTOP_CONF="$HOME/.config/btop/btop.conf"
    if [ -f "$BTOP_CONF" ]; then
        sed -i 's/color_theme = "noctalia"/color_theme = "nexa"/' "$BTOP_CONF"
        echo -e "  ${GREEN}✔${RESET} Set btop theme to 'nexa'"
    fi

    # 4. Sync KDE/Qt kdeglobals
    KDE_COLORS="$HOME/.local/share/color-schemes/Nexa.colors"
    KDE_GLOBALS="$HOME/.config/kdeglobals"
    if [ -f "$KDE_COLORS" ]; then
        python3 -c "
with open('$KDE_COLORS') as f:
    nexa = f.read()

content = '''[General]
Name=Nexa
ColorScheme=Nexa
TerminalApplication=kitty

[KDE]
contrast=4
widgetStyle=kvantum

''' + '\n'.join([l for l in nexa.splitlines() if not l.startswith('Name=') and not l.startswith('ColorScheme=') and not l.startswith('[General]')])

with open('$KDE_GLOBALS', 'w') as f:
    f.write(content)
" 2>/dev/null || true
        echo -e "  ${GREEN}✔${RESET} Synchronized kdeglobals (KDE & Qt color scheme)"
    fi

    # 5. Sync Chrome and Chromium browser theme preferences
    python3 -c "
import json, glob, os

palette_path = os.path.expanduser('~/.cache/nexa/theme/palette')
primary_hex = '4e34ff'
if os.path.exists(palette_path):
    with open(palette_path) as f:
        for line in f:
            if line.startswith('PRIMARY='):
                primary_hex = line.split('=')[1].strip().strip('\"\'#')

val = int('FF' + primary_hex, 16)
if val > 0x7FFFFFFF:
    val -= 0x100000000

for pat in ['~/.config/google-chrome/*/Preferences', '~/.config/chromium/*/Preferences']:
    for p in glob.glob(os.path.expanduser(pat)):
        try:
            with open(p, 'r') as f:
                d = json.load(f)
            if 'browser' not in d: d['browser'] = {}
            if 'theme' not in d['browser']: d['browser']['theme'] = {}
            d['browser']['theme']['user_color2'] = val
            d['browser']['theme']['color_scheme2'] = 1
            d['browser']['theme']['color_variant2'] = 1
            d['browser']['theme']['saved_local_theme'] = 'CAAQAEgB'
            with open(p, 'w') as f:
                json.dump(d, f)
        except Exception:
            pass
" 2>/dev/null || true
    echo -e "  ${GREEN}✔${RESET} Injected NEXA palette into Chrome & Chromium preferences"

    # 6. Apply theme via nexad if compiled
    NEXAD_BIN="$RUST_DIR/target/release/nexad"
    if [ -x "$NEXAD_BIN" ]; then
        "$NEXAD_BIN" theme apply || true
        echo -e "  ${GREEN}✔${RESET} Executed nexad theme apply"
    fi

    # 7. Live reload GTK3/4 themes across open apps
    touch "$HOME/.config/gtk-4.0/gtk.css" 2>/dev/null || true
    curr_theme=$(gsettings get org.gnome.desktop.interface gtk-theme 2>/dev/null | tr -d "'")
    if [ -n "$curr_theme" ]; then
        gsettings set org.gnome.desktop.interface gtk-theme "adw-gtk3-dark" 2>/dev/null || true
        gsettings set org.gnome.desktop.interface gtk-theme "$curr_theme" 2>/dev/null || true
    fi

    echo -e "${GREEN}[✔] NEXA theme synchronization complete across all desktop apps!${RESET}"
}

# ------------------------------------------------------------------------------
# Dispatcher
# ------------------------------------------------------------------------------

dispatch_action() {
    case "$1" in
        1|restart)
            do_restart
            ;;
        2|start)
            do_start
            ;;
        3|stop)
            do_stop
            ;;
        4|build)
            do_build
            ;;
        5|fresh|fresh-build)
            do_fresh_build
            ;;
        6|status)
            do_status
            ;;
        7|theme|theme-sync|sync-theme)
            do_theme_sync
            ;;
        0|exit|q|quit)
            echo "Exiting."
            exit 0
            ;;
        *)
            echo -e "${RED}[ERROR] Invalid option: '$1'${RESET}"
            return 1
            ;;
    esac
}

# If an argument was provided on CLI, execute directly without prompt
if [ -n "$1" ]; then
    dispatch_action "$1"
    exit 0
fi

# ------------------------------------------------------------------------------
# Interactive Menu
# ------------------------------------------------------------------------------

clear 2>/dev/null || true
echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}${CYAN}║              NEXA Desktop Environment                ║${RESET}"
echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════╝${RESET}"
echo ""
echo -e "  ${BOLD}1)${RESET} ${GREEN}Restart${RESET}       ${DIM}— Gracefully stop and relaunch QuickShell${RESET}"
echo -e "  ${BOLD}2)${RESET} ${CYAN}Start${RESET}         ${DIM}— Launch QuickShell background daemon${RESET}"
echo -e "  ${BOLD}3)${RESET} ${RED}Stop${RESET}          ${DIM}— Terminate all QuickShell instances${RESET}"
echo -e "  ${BOLD}4)${RESET} ${YELLOW}Build${RESET}         ${DIM}— Fast incremental cargo release build${RESET}"
echo -e "  ${BOLD}5)${RESET} ${YELLOW}Fresh Build${RESET}   ${DIM}— Clean target cache and rebuild from scratch${RESET}"
echo -e "  ${BOLD}6)${RESET} ${CYAN}Status${RESET}        ${DIM}— Inspect autostart daemons & shell health${RESET}"
echo -e "  ${BOLD}7)${RESET} ${CYAN}Theme Sync${RESET}    ${DIM}— Sync Nexa theme to Qt, GTK, Chrome & strip overrides${RESET}"
echo -e "  ${BOLD}0)${RESET} ${DIM}Exit${RESET}"
echo ""
read -rp "Select an option [1-7, 0]: " choice
echo ""

dispatch_action "$choice"

