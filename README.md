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
* **Integrated Control Center:** Sleek widescreen (`760px × 460px`) hub built directly into the Dynamic Island with tabbed navigation:
  * **Controls (Quick Settings):** Dual-column layout featuring Output sink selector chip, per-app audio volume mixer, sound-reactive Microphone input with click-to-mute, Display Brightness & Night Light (with 3-mode switcher), Screen Filters, and unified 2×2 Connectivity & Actions grids.
  * **Alerts:** Notification center with instant dismissal and history.
  * **Weather:** Dual-card 50/50 layout with current conditions, scrollable atmospheric metrics, and Daily/Hourly forecast views.
  * **Profile:** User account overview and system details.
* **On-Screen Display (OSD):** Zero-latency hardware feedback popups directly in the Dynamic Island with tailored dimensions:
  * **Master Volume:** `320px` × `48px` capsule gauge with dynamic speaker icon (`F2` / `F3`)
  * **Audio Output Mute:** `240px` × `44px` status pill with volume readout (`F1`)
  * **Microphone Mute:** `240px` × `44px` status pill with mic input indicator (`F4`)
  * **Display Brightness:** `320px` × `48px` capsule gauge with amber sun indicator (`F5` / `F6`)
  * **Airplane Mode:** `260px` × `46px` quick toggle indicator (`F8`)
* **Status Cluster:** Wi-Fi, Bluetooth, Battery, and Power menu.

### ⚙️ Quick Settings & Audio Control
* **Dual-Column Widescreen Layout:** Left column dedicated to Audio, Display, and Screen Filters; right column features 2×2 Connectivity and Quick Actions grids.
* **Modern Capsule Sliders:** Sleek, proportional volume, mic, brightness, and color temperature sliders with scroll-hijacking protection.
* **PipeWire Audio Sink Switcher:** Real-time dropdown to switch active audio output sinks on the fly.
* **Per-App Volume Mixer:** Expandable stream controller with individual app volume sliders and mute toggles.
* **Microphone Sound Reactivity:** Live microphone audio meter showing real-time input levels with one-click mute/unmute.
* **Night Light & Screen Temperature:** Dual-mode color tuning (`hyprsunset`) with 3-mode switcher (`Manual`, `Wallpaper`, `Night`).
* **Screen Shaders / Filters:** Live toggle and selector for display shader filters.
* **Dual-Column Weather Center:** 50/50 split layout featuring current conditions, detailed scrollable atmospheric metrics, and Daily/Hourly forecasts with rain probability.

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
* Dynamic GTK3/4, Qt5/6, Kitty, Quickshell, and **Starship Prompt** synchronized color palettes.
* **Two-Line Powerline Starship Prompt:** Dynamic user/host filled capsule, seamless directory breadcrumbs, and theme-colored prompt symbols.
* Screen temperature tuning via `hyprsunset`.

### 📋 Clipboard & Utilities
* Clipboard history supporting pinned text and image previews (`cliphist`).
* Snipping tool & full-screen screen recording with Dynamic Island status.
* Static (`awww`) and animated video wallpapers (`mpvpaper`).

---

## ⌨️ Recommended Keybindings (Hyprland)

Add these bindings to your Hyprland configuration (`hyprland.conf` or `binds.lua`):

```ini
# Dynamic Island Control Center & Notifications
bind = SUPER, C, exec, qs -p ~/.config/nexa/quickshell ipc call nexaIsland toggleControlCenter
bind = SUPER, N, exec, qs -p ~/.config/nexa/quickshell ipc call nexaIsland openNotifications

# App Launcher
bind = SUPER, A, exec, qs -p ~/.config/nexa/quickshell ipc call appLauncher toggle

# Workspace Manager Overview
bind = SUPER, TAB, exec, qs -p ~/.config/nexa/quickshell ipc call workspaceManager toggle

# Dynamic Island Search & Commands
bind = SUPER, SPACE, exec, qs -p ~/.config/nexa/quickshell ipc call nexaIsland openSearch

# Lock Screen
bind = SUPER, L, exec, qs -p ~/.config/nexa/quickshell ipc call lockScreen lock

# Clipboard Manager
bind = SUPER SHIFT, V, exec, qs -p ~/.config/nexa/quickshell ipc call clipboard toggle

# Screenshots & Snipping
bind = SUPER, PRINT, exec, ~/.config/nexa/scripts/screenshot.sh full
bind = SUPER SHIFT, PRINT, exec, ~/.config/nexa/scripts/screenshot.sh region

# Dynamic Island OSD Hardware Controls
bind = , F1, exec, qs -p ~/.config/nexa/quickshell ipc call nexaIsland toggleMute
bind = , F2, exec, qs -p ~/.config/nexa/quickshell ipc call nexaIsland volumeDown
bind = , F3, exec, qs -p ~/.config/nexa/quickshell ipc call nexaIsland volumeUp
bind = , F4, exec, qs -p ~/.config/nexa/quickshell ipc call nexaIsland toggleMicMute
bind = , F5, exec, qs -p ~/.config/nexa/quickshell ipc call nexaIsland brightnessDown
bind = , F6, exec, qs -p ~/.config/nexa/quickshell ipc call nexaIsland brightnessUp
bind = , F8, exec, qs -p ~/.config/nexa/quickshell ipc call nexaIsland toggleAirplane
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
