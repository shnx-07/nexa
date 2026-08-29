# NEXA

NEXA is a modern, high-performance Wayland desktop shell built around **Quickshell**, **Hyprland**, and a dedicated **Rust backend** (`nexad`).

> **Philosophy:** Keep the UI reactive in QML, keep system logic fast and safe in Rust, and maintain strict desktop modularity.

---

## 📦 Required Dependencies & Installation

### 1. Required Fonts

NEXA is designed around Apple's **SF Pro** typography and **Nerd Font** icons:

* **SF Pro Display & Text (Primary Font):**
  ```bash
  # Arch / AUR
  yay -S otf-apple-fonts
  # or
  yay -S apple-fonts
  ```
* **Nerd Font Icons (Icons & Glyphs):**
  ```bash
  sudo pacman -S ttf-jetbrains-mono-nerd ttf-nerd-fonts-symbols
  ```
* **Monospace / Code Font:**
  ```bash
  sudo pacman -S ttf-jetbrains-mono
  ```

---

### 2. Core System Packages (Pacman)

Install standard desktop tools, audio pipelines, and utilities:

```bash
sudo pacman -S \
    hyprland \
    hypridle \
    hyprpicker \
    xdg-desktop-portal-hyprland \
    rust cargo \
    pipewire wireplumber pipewire-pulse pipewire-alsa \
    playerctl \
    brightnessctl \
    bluez bluez-utils \
    networkmanager \
    grim slurp \
    wl-clipboard cliphist \
    wf-recorder \
    ffmpeg \
    mpv \
    cava \
    btop htop \
    qt5-wayland qt6-wayland \
    qt5ct qt6ct \
    sddm
```

---

### 3. AUR Dependencies (Yay / Paru)

Install Wayland shell components, color generation tools, and wallpaper engines:

```bash
yay -S \
    quickshell-git \
    matugen-bin \
    hyprsunset \
    mpvpaper \
    awww-git \
    nwg-look
```

---

## 🛠️ Build & Installation

### 1. Build the Rust Backend (`nexad`)

The Rust backend handles application indexing, window geometry, screen temperature, audio, battery, and workspace events:

```bash
cd ~/.config/nexa/rust
cargo build --release
```

The compiled binary will be placed at:
```text
~/.config/nexa/rust/target/release/nexad
```

### 2. Launching NEXA Shell

To start or reload the Quickshell environment:

```bash
# Start Quickshell
quickshell -p ~/.config/nexa/quickshell/shell.qml

# Or restart via NEXA script
bash ~/.config/nexa/scripts/nexa-restart.sh
```

---

## ✨ Features

### 🌟 Top Bar & Dynamic Island
* **Live Workspaces:** Dynamic pill indicator with smooth sliding animation and active window tracking.
* **Dynamic Island:** Interactive notch supporting Clock, Calendar, Stopwatch, Media player, Theme switcher, System Monitor, Audio visualizer, and Notification banners.
* **Status Cluster:** Wi-Fi, Bluetooth, Battery, Side Panel toggle, and Power menu.

### 📱 Modern App Launcher
* High-density 2-column grid layout with fluid spring entrance motion.
* Segmented category chips (`All`, `Development`, `Office`, `Internet`, `Media`, `Graphics`, `System`, `Utilities`).
* Dedicated non-overlapping scrollbar gutter.
* Instant keyboard navigation (`↑↓←→` to navigate, `↵` to launch, `ESC` to close).

### 🖥️ Workspace Manager (Overview)
* Proportional fullscreen overview with live Wayland window previews (`Screencopy`).
* Interactive window dragging between Workspaces 1–10 and Special scratchpads.
* Luminous candidate drop target glowing feedback with smooth optimistic positioning.
* Subtle architectural workspace watermarks for empty workspaces.

### 🎨 Material You Theme System (Matugen)
* Automatic color scheme generation from any wallpaper or manual color presets.
* Dynamic GTK3/4, Qt5/6, Kitty, and Quickshell synchronized color palettes.
* Screen temperature tuning via `hyprsunset`.

### 📋 Clipboard & Utilities
* Clipboard history supporting pinned text and image previews (`cliphist`).
* Snipping tool & full-screen screen recording with Dynamic Island status.
* Static (`awww`) and animated video wallpapers (`mpvpaper`).

---

## ⌨️ Recommended Keybindings (Hyprland)

Add these bindings to your Hyprland configuration (`hyprland.conf` or `keybinds.lua`):

```ini
# App Launcher
bind = SUPER, A, exec, qs -p ~/.config/nexa/quickshell ipc call appLauncher toggle

# Workspace Manager Overview
bind = SUPER, TAB, exec, qs -p ~/.config/nexa/quickshell ipc call workspaceManager toggle

# Dynamic Island Search
bind = SUPER, SPACE, exec, qs -p ~/.config/nexa/quickshell ipc call island openSearch

# Lock Screen
bind = SUPER, L, exec, qs -p ~/.config/nexa/quickshell ipc call lockScreen lock

# Clipboard Manager
bind = SUPER SHIFT, V, exec, qs -p ~/.config/nexa/quickshell ipc call clipboard toggle

# Screenshots & Snipping
bind = SUPER, PRINT, exec, ~/.config/nexa/scripts/screenshot.sh full
bind = SUPER SHIFT, PRINT, exec, ~/.config/nexa/scripts/screenshot.sh region
```

---

## 📂 Project Directory Structure

```text
~/.config/nexa/
├── config/              # User settings, wallpaper.conf, theme.conf
├── quickshell/          # QML User Interface
│   ├── bar/             # Top bar components
│   ├── island/          # Dynamic Island modules
│   ├── modules/         # AppLauncher, Workspace, LockScreen, SidePanel, etc.
│   ├── panel/           # QuickSettings & Notifications
│   └── theme/           # Material color tokens and reusable UI components
├── rust/                # Rust backend (nexad)
│   └── src/             # search.rs, workspace.rs, audio.rs, events.rs, etc.
└── scripts/             # Helper scripts (nexa-restart.sh, open-monitor.sh)
```

---

## 🔒 SDDM Login Theme

NEXA includes a matching login screen theme for SDDM:

```text
/usr/share/sddm/themes/nexa/
```

Enable it in `/etc/sddm.conf.d/nexa.conf`:
```ini
[Theme]
Current=nexa
```

---

## 📜 License

Personal configuration and dotfiles. Distributed under the MIT License.
