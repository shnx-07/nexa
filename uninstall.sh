#!/usr/bin/env bash
# ==============================================================================
#  NEXA Dotfiles Automated Uninstaller & Rollback Tool
# ==============================================================================

set -e

# Colors for terminal output
BOLD="\033[1m"
GREEN="\033[1;32m"
BLUE="\033[1;34m"
YELLOW="\033[1;33m"
RED="\033[1;31m"
CYAN="\033[1;36m"
RESET="\033[0m"

log_info()    { echo -e "${BLUE}ℹ [INFO]${RESET} $*"; }
log_step()    { echo -e "\n${BOLD}${CYAN}==>${RESET} ${BOLD}$*${RESET}"; }
log_success() { echo -e "${GREEN}✔ [SUCCESS]${RESET} $*"; }
log_warn()    { echo -e "${YELLOW}⚠ [WARNING]${RESET} $*"; }
log_error()   { echo -e "${RED}✖ [ERROR]${RESET} $*"; }

BACKUP_BASE="$HOME/.config/nexa_backups"

echo -e "\n${BOLD}${RED}==============================================================================${RESET}"
echo -e "${BOLD}${RED}  NEXA Dotfiles Uninstaller & Rollback${RESET}"
echo -e "${BOLD}${RED}==============================================================================${RESET}\n"

read -rp "Are you sure you want to uninstall NEXA and revert your configurations? [y/N]: " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    log_info "Uninstallation aborted."
    exit 0
fi

# ------------------------------------------------------------------------------
# 1. Stop Running NEXA Daemons & Processes
# ------------------------------------------------------------------------------
log_step "Stopping Running NEXA & Shell Processes"

killall quickshell 2>/dev/null || true
killall nexad 2>/dev/null || true
killall awww-daemon 2>/dev/null || true
killall mpvpaper 2>/dev/null || true

log_success "Processes stopped."

# ------------------------------------------------------------------------------
# 2. Check for Backup & Restore
# ------------------------------------------------------------------------------
log_step "Checking for Previous Configuration Backups"

CONFIG_TARGETS=(
    "hypr"
    "nexa"
    "kitty"
    "matugen"
    "gtk-3.0"
    "gtk-4.0"
    "qt5ct"
    "qt6ct"
    "mimeapps.list"
    "starship.toml"
)

LATEST_BACKUP=""
if [ -f "$BACKUP_BASE/.latest_backup" ]; then
    LATEST_BACKUP="$(cat "$BACKUP_BASE/.latest_backup")"
fi

if [ -n "$LATEST_BACKUP" ] && [ -d "$LATEST_BACKUP" ]; then
    log_info "Found backup directory: ${CYAN}$LATEST_BACKUP${RESET}"
    read -rp "Do you want to restore this backup? [Y/n]: " restore_confirm
    if [[ "$restore_confirm" =~ ^[Nn]$ ]]; then
        log_warn "Skipping backup restoration. Removing NEXA configurations..."
        for item in "${CONFIG_TARGETS[@]}"; do
            rm -rf "$HOME/.config/$item"
        done
        rm -f "$HOME/.zshrc"
    else
        log_info "Reverting configurations to pre-NEXA state..."
        for item in "${CONFIG_TARGETS[@]}"; do
            rm -rf "$HOME/.config/$item"
            if [ -e "$LATEST_BACKUP/$item" ]; then
                log_info "Restoring ~/.config/$item"
                cp -a "$LATEST_BACKUP/$item" "$HOME/.config/$item"
            fi
        done

        if [ -f "$LATEST_BACKUP/.zshrc" ]; then
            log_info "Restoring ~/.zshrc"
            rm -f "$HOME/.zshrc"
            cp -a "$LATEST_BACKUP/.zshrc" "$HOME/.zshrc"
        fi
        log_success "Original configurations restored successfully!"
    fi
else
    log_warn "No automatic backup manifest found. Removing NEXA dotfiles from ~/.config/..."
    for item in "${CONFIG_TARGETS[@]}"; do
        rm -rf "$HOME/.config/$item"
    done
fi

# ------------------------------------------------------------------------------
# 3. Clean Caches
# ------------------------------------------------------------------------------
log_step "Cleaning Runtime Caches"

rm -rf "$HOME/.cache/nexa"
log_success "Cleared ~/.cache/nexa."

# ------------------------------------------------------------------------------
# 4. Optional: Disable Hyprland Plugins
# ------------------------------------------------------------------------------
if command -v hyprpm >/dev/null 2>&1; then
    log_step "Hyprland Plugins"
    read -rp "Do you want to disable HyprGlass and dynamic-cursors plugins? [y/N]: " plugin_confirm
    if [[ "$plugin_confirm" =~ ^[Yy]$ ]]; then
        hyprpm disable hyprglass 2>/dev/null || true
        hyprpm disable dynamic-cursors 2>/dev/null || true
        log_success "Plugins disabled."
    fi
fi

# ------------------------------------------------------------------------------
# 5. Completion Message
# ------------------------------------------------------------------------------
echo -e "\n${BOLD}${GREEN}==============================================================================${RESET}"
echo -e "${BOLD}${GREEN}  ✔ NEXA Uninstallation and Rollback Complete!${RESET}"
echo -e "${BOLD}${GREEN}==============================================================================${RESET}\n"
