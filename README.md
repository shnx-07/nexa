# NEXA

NEXA is a modern, high-performance Wayland desktop environment built around **Quickshell**, **Hyprland**, and a dedicated **Rust backend** (`nexad`).

> **Philosophy:** Keep the UI reactive in QML, keep system logic fast and safe in Rust, and maintain strict desktop modularity.

---

## ⚡ Quick Start: Automated Installation

NEXA includes a fully automated, production-grade installer and uninstaller for **Arch Linux** and **CachyOS**.

### 🚀 1. Install NEXA (Automated A-to-Z)

Clone the repository and run the installer:

```bash
git clone https://github.com/shnx-07/nexa.git dotfiles
cd dotfiles
chmod +x install.sh uninstall.sh
./install.sh
```

#### What the installer does automatically:
1. **System & Sudo Check:** Validates Arch/CachyOS environment and ensures non-root execution with sudo privileges.
2. **AUR Helper Bootstrapping:** Checks for `yay` or `paru`. If missing, automatically clones and builds `yay` from source.
3. **Full Dependency Installation:** Installs all required official (`pacman`) and AUR (`yay`) packages.
4. **Safe Automated Backups:** Automatically creates a timestamped backup of your existing configs in `~/.config/nexa_backups/backup_<timestamp>/`.
5. **Configuration Deployment:** Deploys Hyprland, Quickshell, Kitty, WezTerm, Matugen, GTK, Qt, and Starship configurations.
6. **Rust Backend Compilation:** Runs `cargo build --release` inside `~/.config/nexa/rust` to compile `nexad`.
7. **Hyprland Plugins:** Automatically updates `hyprpm`, then installs and enables `hyprglass` and `dynamic-cursors`.
8. **Runtime Initialization:** Sets up wallpaper cache and runtime directories.

---

### 🔄 2. Revert / Uninstall NEXA

To completely revert NEXA and restore your original configuration files:

```bash
cd dotfiles
./uninstall.sh
```

#### What the uninstaller does:
- Gracefully terminates running `quickshell`, `nexad`, and wallpaper daemons.
- Cleans up deployed NEXA configurations.
- **Automatically restores your previous configuration backup** from `~/.config/nexa_backups/`.
- Clears temporary runtime caches.
- Optionally disables Hyprland plugins.

---

## 📦 Complete Package & Dependency Inventory

If you prefer installing dependencies manually or want a complete breakdown:

### 1. Core Desktop & Window Management
* `hyprland` — Wayland compositor
* `hypridle` — Idle management daemon
* `hyprpicker` — Wayland color picker
* `hyprcursor` — Cursor theme format support
* `xdg-desktop-portal-hyprland` & `xdg-desktop-portal-gtk` — Wayland desktop portals
* `polkit-kde-agent` — Privilege escalation auth agent

### 2. Theming & Shell (Quickshell & Matugen)
* `quickshell-git` *(AUR)* — The reactive Wayland QML shell engine (provides `qs` and `quickshell`)
* `matugen-bin` *(AUR)* — Material You dynamic color palette extractor
* `awww-git` *(AUR)* — High-performance Wayland wallpaper daemon
* `mpvpaper` *(AUR)* — Video wallpaper engine
* `hyprsunset` *(AUR)* — Color temperature / night light daemon
* `qt5ct` & `qt6ct` — Qt appearance configuration tools
* `kvantum` — SVG-based Qt theme engine
* `nwg-look` *(AUR)* — GTK theme and icon switcher

### 3. Terminals, Shell & Utilities
* `kitty` & `wezterm` — Terminal emulators
* `nemo`, `dolphin` & `yazi` — Graphical and terminal file managers
* `zsh` & `starship` — Shell and dynamic Powerline prompt
* `btop` & `htop` — System monitors
* `jq`, `glib2`, `socat` — Data formatting and IPC utilities

### 4. Audio, Media & Capture
* `pipewire`, `wireplumber`, `pipewire-pulse`, `pipewire-alsa` — Audio server stack
* `playerctl` — Media player controller
* `mpv`, `cava`, `ffmpeg` — Media players and audio visualizer
* `grim`, `slurp`, `satty` — Wayland screenshot and snipping tools
* `wf-recorder` — Screen recorder
* `wl-clipboard`, `cliphist` — Wayland clipboard managers

### 5. Build & Development Chain
* `base-devel`, `git`, `rust`, `cargo`, `gcc`, `pkgconf`, `cmake`, `python`

### 6. Typography & Icons
* `otf-apple-fonts` *(AUR)* — Apple SF Pro Display & Text
* `ttf-jetbrains-mono-nerd` & `ttf-nerd-fonts-symbols` — Nerd Font icons & glyphs
* `noto-fonts`, `noto-fonts-cjk`, `noto-fonts-emoji` — Universal fallback & emoji support
* `otf-font-awesome` — Icon glyphs

---

## ✨ Features

### 🌟 Top Bar & Dynamic Island
* **Live Workspaces:** Dynamic pill indicator with smooth sliding animation and active window tracking.
* **Dynamic Island:** Interactive notch supporting Clock, Calendar, Stopwatch, Media player, Theme switcher, System Monitor, Audio visualizer, and Notification banners.
* **Integrated Control Center:** Sleek widescreen (`760px × 440px`) hub built directly into the Dynamic Island with tabbed navigation:
  * **Controls (Quick Settings):** Dual-column layout featuring Output sink selector chip, per-app audio volume mixer, sound-reactive Microphone input with click-to-mute, Display Brightness & Night Light (with 3-mode switcher), Screen Filters, and unified 2×2 Connectivity & Actions grids.
  * **Alerts:** 2-column notification grid with instant dismissal and history.
  * **Weather:** Dual-card 50/50 layout with current conditions, scrollable atmospheric metrics, and Daily/Hourly forecast views.
  * **Profile:** User account overview with 1:3 profile picture split and cinematic wallpaper backdrop.
* **On-Screen Display (OSD):** Zero-latency hardware feedback popups directly in the Dynamic Island with tailored dimensions:
  * **Master Volume:** `320px` × `48px` capsule gauge with dynamic speaker icon (`F2` / `F3`)
  * **Audio Output Mute:** `240px` × `44px` status pill with volume readout (`F1`)
  * **Microphone Mute:** `240px` × `44px` status pill with mic input indicator (`F4`)
  * **Display Brightness:** `320px` × `48px` capsule gauge with amber sun indicator (`F5` / `F6`)
  * **Airplane Mode:** `260px` × `46px` quick toggle indicator (`F8`)

### ⚡ Battery & Performance Optimized
* **Dynamic Compositor Throttling:** Automatically switches to `power-saver` and disables expensive multi-pass blur and shadows on battery (slashing battery discharge by nearly 80%).
* **0% Idle Polling:** System monitors only query hardware when open, eliminating background CPU spikes.
* **Smart Process Termination:** `Super + Q` terminates background tray hoarders (Discord, Spotify, etc.) directly with `SIGTERM` so closed apps never linger in RAM.

### 🔒 Cyber-Minimalist Glass Lock Screen & Avatar Customization
* **Profile Picture & Illuminated Avatar Halo:** Features hardware-accelerated circular `OpacityMask` cropping and an animated glowing halo ring that pulses with theme accents when typing passwords.
* **Intelligent Auto-Detection:** Automatically checks and loads your profile picture from `~/.face`, `~/.face.icon`, `~/.config/nexa/avatar.png` (or `.jpg`/`.svg`/`.webp`), falling back to a gradient initial badge.
* **Built-in Curated Presets:** Comes bundled with handcrafted high-res SVG presets (`cyber_neon`, `astro_space`, `mecha_cat`, `crystal_prism`, `minimal_silhouette`).
* **Instant Avatar Management (`nexa-avatar`):**
  ```bash
  # List all available avatar presets
  nexa-avatar list

  # Set avatar to a curated preset
  nexa-avatar set astro_space
  nexa-avatar set mecha_cat
  nexa-avatar set cyber_neon

  # Set any custom picture or wallpaper from disk as your lock screen avatar
  nexa-avatar set ~/Pictures/avatar.png
  ```
* **Live System Telemetry & Power Actions:**
  * Top bar displays live Battery percentage / charging beacon and OS host badge (`cachyos`).
  * Bottom-right quick actions for **Sleep** (`󰤄`), **Reboot** (`󰜉`), and **Power Off** (`󰐥`).
  * Bottom-left floating glass **Now Playing Card** with direct Play/Pause controls.

### 🎵 Cyber-Luminous Glass Deck (Music Experience)
* **Spinning Vinyl Disc:** A realistic vinyl record with micro-grooves physically slides out from behind the album artwork and spins continuously during playback.
* **Ambient Artwork Bloom:** Dynamic blurred album art sampling creates an atmospheric underglow behind the player.
* **Integrated Controls & Scrubber:** High-precision seekbar with monospace timestamps, hero play/pause button, shuffle/loop toggles, and an **inline system/music volume slider** right on the deck.
* **48-Band CAVA Spectrum:** Audio-reactive visualizer spectrum across the base.

### 📱 Modern App Launcher & Workspace Manager
* **App Launcher:** High-density 2-column grid layout with fluid spring entrance motion and category chips (`Super + A`).
* **Workspace Manager:** Fullscreen overview with live Wayland window previews and candidate drop targets (`Super + Tab` / `Super + Shift + W`).
* **Window Rules:** Automatic Picture-in-Picture sticky pinning, centered lower floating file managers (Dolphin, Nemo, Yazi), and automatic floating of file dialogs/modals.

---

## ⌨️ Hyprland Keybindings Reference

| Shortcut | Action |
| :--- | :--- |
| `Super + Space` | Dynamic Island Search |
| `Super + Shift + Space` | Dynamic Island Command Palette |
| `Super + A` | NEXA App Launcher |
| `Super + W` | NEXA Wallpaper Picker |
| `Super + N` | Toggle Control Center Island |
| `Super + V` | Clipboard History (`cliphist`) |
| `Super + Return` | Open Terminal (`kitty`) |
| `Super + E` | Open File Manager (`nemo`) |
| `Super + Q` | Close Active Window (with process termination) |
| `Super + Shift + Q` | Force-Kill Active Window (`kill -9`) |
| `Super + F` | Toggle Fullscreen |
| `Super + T` | Toggle Floating |
| `Super + L` | Lock Screen |
| `Super + Shift + S` | Snipping Tool |
| `Super + X` | Instant Screenshot |
| `F1` / `F2` / `F3` | Mute / Volume Down / Volume Up |
| `F4` | Microphone Mute Toggle |
| `F5` / `F6` | Brightness Down / Brightness Up |
| `F8` | Airplane Mode Toggle |

---

## 📂 Project Directory Structure

```text
~/.config/nexa/
├── config/              # User settings, wallpaper.conf, theme.conf
├── quickshell/          # QML User Interface
│   ├── bar/             # Top bar components
│   ├── island/          # Dynamic Island modules
│   ├── modules/         # AppLauncher, Workspace, LockScreen, SidePanel, etc.
│   ├── panel/           # QuickSettings, Alerts, Weather, Profile
│   └── theme/           # Material color tokens and reusable UI components
├── rust/                # Rust backend (nexad)
│   └── src/             # search.rs, workspace.rs, audio.rs, events.rs, etc.
└── scripts/             # Helper scripts (nexa-restart.sh, theme.sh, wallpaper.sh)
```

---

## 📜 License

Personal configuration and dotfiles. Distributed under the MIT License.
