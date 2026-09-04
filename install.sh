#!/usr/bin/env bash
# ==============================================================================
#  NEXA Dotfiles Automated Installer
#  Target OS: Arch Linux / CachyOS
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

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_BASE="$HOME/.config/nexa_backups"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP_DIR="$BACKUP_BASE/backup_$TIMESTAMP"

# ------------------------------------------------------------------------------
# 1. Pre-flight Checks
# ------------------------------------------------------------------------------
log_step "Checking System Compatibility"

if [ ! -f /etc/arch-release ]; then
    log_error "NEXA installer is designed specifically for Arch Linux and CachyOS."
    exit 1
fi
log_success "Arch Linux environment detected."

if [ "$EUID" -eq 0 ]; then
    log_error "Please run this script as a normal user with sudo privileges, NOT as root."
    exit 1
fi

# Request sudo upfront and keep alive
sudo -v
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

# ------------------------------------------------------------------------------
# 2. Bootstrap yay (AUR Helper) if missing
# ------------------------------------------------------------------------------
log_step "Checking for AUR Helper (yay / paru)"

AUR_HELPER=""
if command -v yay >/dev/null 2>&1; then
    AUR_HELPER="yay"
    log_success "Found yay: $(yay --version | head -n 1)"
elif command -v paru >/dev/null 2>&1; then
    AUR_HELPER="paru"
    log_success "Found paru: $(paru --version | head -n 1)"
else
    log_warn "No AUR helper found. Bootstrapping yay from source..."
    sudo pacman -S --needed --noconfirm base-devel git
    
    YAY_TMP="$(mktemp -d)"
    git clone https://aur.archlinux.org/yay.git "$YAY_TMP/yay"
    (
        cd "$YAY_TMP/yay"
        makepkg -si --noconfirm
    )
    rm -rf "$YAY_TMP"
    AUR_HELPER="yay"
    log_success "Successfully installed yay!"
fi

# ------------------------------------------------------------------------------
# 3. Install Official Arch Packages (pacman)
# ------------------------------------------------------------------------------
log_step "Installing Official Packages via pacman"

PACMAN_PACKAGES=(
    # Hyprland Core & Compositor
    hyprland
    hypridle
    hyprpicker
    hyprcursor
    xdg-desktop-portal-hyprland
    xdg-desktop-portal-gtk
    polkit-kde-agent

    # Build & Development
    base-devel
    git
    rust
    cargo
    gcc
    pkgconf
    cmake
    python

    # Audio & Media
    pipewire
    wireplumber
    pipewire-pulse
    pipewire-alsa
    playerctl
    mpv
    cava
    ffmpeg

    # Hardware, Power & Network
    brightnessctl
    bluez
    bluez-utils
    networkmanager
    power-profiles-daemon
    upower
    util-linux

    # Screen Capture & Clipboard
    grim
    slurp
    satty
    wf-recorder
    wl-clipboard
    cliphist

    # Qt Frameworks & Theming
    qt5-wayland
    qt6-wayland
    qt5ct
    qt6ct
    kvantum
    breeze
    breeze-icons
    adwaita-icon-theme
    adw-gtk-theme

    # Terminals & File Managers
    alacritty
    kitty
    wezterm
    nemo
    dolphin
    yazi

    # Shell & System Utilities
    zsh
    starship
    btop
    htop
    jq
    glib2
    socat

    # Fonts
    ttf-jetbrains-mono-nerd
    ttf-jetbrains-mono
    ttf-nerd-fonts-symbols
    noto-fonts
    noto-fonts-cjk
    noto-fonts-emoji
    otf-font-awesome
)

log_info "Synchronizing repositories and installing official packages..."
sudo pacman -S --needed --noconfirm "${PACMAN_PACKAGES[@]}"
log_success "Official packages installed successfully."

# ------------------------------------------------------------------------------
# 4. Install AUR Packages (yay / paru)
# ------------------------------------------------------------------------------
log_step "Installing AUR Packages via $AUR_HELPER"

AUR_PACKAGES=(
    quickshell-git
    matugen-bin
    awww-git
    mpvpaper
    hyprsunset
    otf-apple-sf-pro
    otf-apple-fonts
    nwg-look
    wlogout
    swaync
)

log_info "Installing AUR packages: ${AUR_PACKAGES[*]}"
$AUR_HELPER -S --needed --noconfirm "${AUR_PACKAGES[@]}"
log_success "AUR packages installed successfully."

# ------------------------------------------------------------------------------
# 5. Backup Existing Configurations
# ------------------------------------------------------------------------------
log_step "Backing Up Existing Configurations"

mkdir -p "$BACKUP_DIR"
echo "$BACKUP_DIR" > "$BACKUP_BASE/.latest_backup"

CONFIG_TARGETS=(
    "hypr"
    "nexa"
    "kitty"
    "alacritty"
    "btop"
    "fastfetch"
    "fontconfig"
    "matugen"
    "gtk-3.0"
    "gtk-4.0"
    "qt5ct"
    "qt6ct"
    "mimeapps.list"
    "starship.toml"
)

BACKED_UP_COUNT=0
for item in "${CONFIG_TARGETS[@]}"; do
    if [ -e "$HOME/.config/$item" ]; then
        log_info "Backing up ~/.config/$item -> $BACKUP_DIR/$item"
        cp -a "$HOME/.config/$item" "$BACKUP_DIR/"
        BACKED_UP_COUNT=$((BACKED_UP_COUNT + 1))
    fi
done

if [ -f "$HOME/.zshrc" ]; then
    log_info "Backing up ~/.zshrc -> $BACKUP_DIR/.zshrc"
    cp -a "$HOME/.zshrc" "$BACKUP_DIR/.zshrc"
    BACKED_UP_COUNT=$((BACKED_UP_COUNT + 1))
fi

if [ "$BACKED_UP_COUNT" -gt 0 ]; then
    log_success "Backed up $BACKED_UP_COUNT items to $BACKUP_DIR"
else
    log_info "No existing configurations found to back up."
fi

# ------------------------------------------------------------------------------
# 6. Deploy NEXA Dotfiles
# ------------------------------------------------------------------------------
log_step "Deploying NEXA Dotfiles"

mkdir -p "$HOME/.config"

for item in "${CONFIG_TARGETS[@]}"; do
    if [ -e "$DOTFILES_DIR/$item" ]; then
        log_info "Deploying $item -> ~/.config/$item"
        rm -rf "$HOME/.config/$item"
        cp -a "$DOTFILES_DIR/$item" "$HOME/.config/$item"
    fi
done

if [ -f "$DOTFILES_DIR/.zshrc" ]; then
    log_info "Deploying .zshrc -> ~/.zshrc"
    cp -a "$DOTFILES_DIR/.zshrc" "$HOME/.zshrc"
fi

# Ensure all scripts are executable
chmod +x "$HOME"/.config/nexa/scripts/* 2>/dev/null || true
chmod +x "$HOME"/.config/hypr/scripts/* 2>/dev/null || true
mkdir -p "$HOME/.local/bin"
ln -sf "$HOME/.config/nexa/scripts/nexa-avatar.sh" "$HOME/.local/bin/nexa-avatar" 2>/dev/null || true

# Pre-create required runtime directories
mkdir -p "$HOME/.cache/nexa/theme"
mkdir -p "$HOME/.cache/nexa/wallpapers"
mkdir -p "$HOME/.cache/nexa/wallpapers/video"
mkdir -p "$HOME/Pictures/Wallpapers"

# Ensure BlueZ respects user Bluetooth power state across reboots
if [ -f /etc/bluetooth/main.conf ]; then
    sudo sed -i "s/^#*AutoEnable=true/AutoEnable=false/" /etc/bluetooth/main.conf 2>/dev/null || true
fi

# Refresh font cache so SF Pro Display and other fonts are immediately active
if command -v fc-cache >/dev/null 2>&1; then
    log_info "Updating system font cache (fc-cache -f)..."
    fc-cache -f >/dev/null 2>&1 || true
fi

# Configure GTK interface font and icon theme via gsettings
if command -v gsettings >/dev/null 2>&1; then
    log_info "Applying GNOME/GTK desktop font and icon settings..."
    gsettings set org.gnome.desktop.interface font-name 'SF Pro Display 11' 2>/dev/null || true
    gsettings set org.gnome.desktop.interface document-font-name 'SF Pro Display 11' 2>/dev/null || true
    gsettings set org.gnome.desktop.interface icon-theme 'Adwaita' 2>/dev/null || true
fi

log_success "Dotfiles deployed successfully."

# ------------------------------------------------------------------------------
# 7. Build Rust Backend (`nexad`)
# ------------------------------------------------------------------------------
log_step "Building NEXA Rust Daemon (nexad)"

if [ -d "$HOME/.config/nexa/rust" ]; then
    log_info "Compiling nexad with optimizations (cargo build --release)..."
    (
        cd "$HOME/.config/nexa/rust"
        cargo build --release
    )
    if [ -f "$HOME/.config/nexa/rust/target/release/nexad" ]; then
        log_success "nexad binary compiled successfully at ~/.config/nexa/rust/target/release/nexad"
        log_info "Generating initial NEXA search index..."
        "$HOME/.config/nexa/rust/target/release/nexad" search refresh >/dev/null 2>&1 || true
    else
        log_error "nexad build completed but binary was not found."
        exit 1
    fi
else
    log_warn "Rust backend directory ~/.config/nexa/rust not found. Skipping build."
fi

# ------------------------------------------------------------------------------
# 8. Setup Hyprland Plugins (hyprpm)
# ------------------------------------------------------------------------------
log_step "Configuring Hyprland Plugins via hyprpm"

if command -v hyprpm >/dev/null 2>&1; then
    log_info "Updating hyprpm repository cache..."
    hyprpm update || log_warn "hyprpm update returned non-zero, continuing..."

    # Install HyprGlass
    log_info "Setting up HyprGlass plugin..."
    hyprpm add https://github.com/hyprnux/hyprglass || true
    hyprpm enable hyprglass || true

    # Install dynamic-cursors
    log_info "Setting up dynamic-cursors plugin..."
    hyprpm add https://github.com/VirtCode/dynamic-cursors || true
    hyprpm enable dynamic-cursors || true

    log_success "Hyprland plugins configured."
else
    log_warn "hyprpm not found. Skipping Hyprland plugin configuration."
fi

# ------------------------------------------------------------------------------
# 9. Installation Complete
# ------------------------------------------------------------------------------
echo -e "\n${BOLD}${GREEN}==============================================================================${RESET}"
echo -e "${BOLD}${GREEN}  ✔ NEXA Installation Completed Successfully!${RESET}"
echo -e "${BOLD}${GREEN}==============================================================================${RESET}"
echo -e "
${BOLD}What's next:${RESET}
  1. ${CYAN}Log into Hyprland${RESET} from your display manager (SDDM/GDM) or tty.
  2. To restart or inspect NEXA at any time:
     ${YELLOW}~/.config/nexa/scripts/nexa-restart.sh${RESET}
  3. Keybindings reference:
     - ${BOLD}Super + Space${RESET}       : Dynamic Island Search
     - ${BOLD}Super + Shift + Space${RESET} : Dynamic Island Commands
     - ${BOLD}Super + A${RESET}           : App Launcher
     - ${BOLD}Super + W${RESET}           : Wallpaper Picker
     - ${BOLD}Super + N${RESET}           : Control Center Island
     - ${BOLD}Super + V${RESET}           : Clipboard History
     - ${BOLD}Super + Q${RESET}           : Close Active Window

${BLUE}Backup Info:${RESET} Your previous configs are safely stored in:
  ${CYAN}$BACKUP_DIR${RESET}
  (Run ${YELLOW}./uninstall.sh${RESET} at any time to completely revert).
"
