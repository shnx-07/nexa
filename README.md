# NEXA

NEXA is a custom Wayland desktop shell built around **Quickshell**, **Hyprland**, and a small **Rust backend**.

The project follows a simple architecture:

> Keep the UI in QML, keep system logic in Rust, and keep the desktop modular.

NEXA is not a full desktop environment. It is a personal shell layer built on top of Hyprland with custom panels, widgets, system controls, workspace management, notifications, theming, wallpapers, lock screen, and related utilities.

---

## Features

### Top Bar

- Workspace indicators
- Current application icon
- Dynamic Island
- Battery
- Wi-Fi / Bluetooth status
- Side panel button
- Power button

### Dynamic Island

- Clock
- Calendar
- Stopwatch
- Music controls
- System information
- Theme controls
- Search
- Command mode
- Recorder controls
- Notification events
- Power controls

The Island supports compact, expanded, hover, and full-panel states.

### Side Panel

Pages:

- Notifications
- Quick Settings
- Weather
- Profile

Quick Settings includes:

- Brightness
- Output volume
- Per-application volume
- Microphone input volume
- Microphone mute
- Wi-Fi
- Bluetooth
- Airplane mode
- VPN
- Night Light / screen temperature
- Screen filters
- Do Not Disturb

### Workspace Manager

NEXA includes a fullscreen workspace overview with live window previews.

Features:

- Workspaces 1–10
- Special workspace support
- Live previews using Quickshell screencopy
- Focus exact window
- Move windows between workspaces
- Move windows to/from special workspace
- Optional follow-after-move behavior
- Keyboard shortcut access

### App Launcher

The launcher discovers installed desktop applications and categorizes them.

Example categories:

- All
- Development
- Internet
- Media
- Graphics
- System
- Utilities

### Clipboard Manager

Clipboard support uses `cliphist`, `wl-copy`, and `wl-paste`.

Features:

- Clipboard history
- Text entries
- Image entries
- Pinning
- Delete
- Clear
- Copy selected entry
- Cached image previews

### Screenshots and Recording

- Full screenshot capture
- Region/snipping capture
- Screen recording
- Pause/resume recording
- Stop recording
- Dynamic Island recording indicator and timer

### Wallpaper System

Supported wallpaper types:

- PNG
- JPG / JPEG
- WebP
- GIF
- MP4
- MKV
- MOV
- WebM

Static wallpapers use `awww`.

Animated/video wallpapers use `mpvpaper`.

Wallpaper state is stored in:

```text
~/.config/nexa/config/wallpaper.conf
```

Wallpaper changes can also:

- Regenerate the active Matugen theme
- Update screen temperature
- Generate representative frames for animated wallpapers

### Theme System

NEXA uses Matugen for color generation.

Supported approaches include:

- Preset themes
- Wallpaper accents
- Full wallpaper-generated themes
- Light / dark modes
- Wallpaper-driven screen warmth

### Screen Temperature

Screen temperature is handled through the Rust backend and `hyprsunset`.

Modes include:

- Manual
- Wallpaper-based

### Screen Filters

Available filters include:

- Off
- Chroma
- Grayscale
- HDR
- High Contrast
- Invert Colors
- Sepia

### Lock Screen

NEXA includes its own Quickshell lock screen.

It can be triggered with:

```bash
qs -p ~/.config/nexa/quickshell ipc call lockScreen lock
```

Hypridle can use the same IPC command for automatic idle locking.

### SDDM Theme

The boot login screen uses a custom NEXA SDDM theme.

Typical installed location:

```text
/usr/share/sddm/themes/nexa/
```

The theme contains:

- Wallpaper background
- Clock
- Date
- Username
- Password field
- Session selector
- Reboot
- Shutdown

---

## Project Structure

```text
~/.config/nexa
├── assets
├── config
├── noctalia
├── quickshell
│   ├── bar
│   ├── island
│   ├── modules
│   ├── panel
│   ├── theme
│   └── wallpaper
├── rust
│   └── src
├── scripts
└── README.md
```

---

## Quickshell Modules

```text
quickshell/modules/
├── airplane
├── appLauncher
├── audio
├── battery
├── brightness
├── clipboard
├── clock
├── command
├── lockscreen
├── media
├── microphone
├── network
├── nightlight
├── notifications
├── power
├── recorder
├── screenfilter
├── screenshot
├── search
├── session
├── snippets
├── status
├── systeminfo
├── theme
├── vpn
├── wallpaper
├── weather
└── workspace
```

---

## Rust Backend

The Rust backend binary is:

```text
nexad
```

Source modules include:

```text
rust/src/
├── appLauncher.rs
├── audio.rs
├── brightness.rs
├── clipboard.rs
├── command.rs
├── events.rs
├── ipc.rs
├── island.rs
├── lock.rs
├── main.rs
├── network.rs
├── notifications.rs
├── power.rs
├── recorder.rs
├── screenFilter.rs
├── screenshot.rs
├── screenTemp.rs
├── search.rs
├── snipping.rs
├── state.rs
├── system.rs
├── wallpaper.rs
├── weather.rs
└── workspace.rs
```

Build with:

```bash
cd ~/.config/nexa/rust
cargo build --release
```

The resulting binary is:

```text
~/.config/nexa/rust/target/release/nexad
```

---

## Running NEXA

Example Quickshell launch:

```bash
quickshell -p ~/.config/nexa/quickshell/shell.qml
```

---

## Example Keybinds

### Lock Screen

```lua
hl.bind("SUPER + L", hl.dsp.global("nexa:lock"))
```

### App Launcher

```text
SUPER + A
```

### Island Search

```text
SUPER + SPACE
```

### Island Command

```text
SUPER + SHIFT + SPACE
```

### Screenshot

```text
SUPER + PRINT
```

### Snipping Tool

```text
SUPER + SHIFT + PRINT
```

### Clipboard

```text
SUPER + SHIFT + V
```

---

## Hypridle

Example NEXA lock integration:

```ini
general {
    lock_cmd = qs -p ~/.config/nexa/quickshell ipc call lockScreen lock
    before_sleep_cmd = qs -p ~/.config/nexa/quickshell ipc call lockScreen lock
    after_sleep_cmd = hyprctl dispatch dpms on
}

listener {
    timeout = 300
    on-timeout = qs -p ~/.config/nexa/quickshell ipc call lockScreen lock
}

listener {
    timeout = 600
    on-timeout = hyprctl dispatch dpms off
    on-resume = hyprctl dispatch dpms on
}
```

Adjust the timeout values to your preference.

---

## SDDM Setup

Example SDDM configuration:

```ini
[Theme]
Current=nexa
```

Save it as:

```text
/etc/sddm.conf.d/nexa.conf
```

A typical theme layout:

```text
/usr/share/sddm/themes/nexa/
├── Main.qml
├── metadata.desktop
├── theme.conf
└── background.png
```

### SDDM Wallpaper Helper

Example helper:

```bash
#!/usr/bin/env bash

set -e

if [[ -z "$1" ]]; then
    echo "Usage: nexa-sddm-wallpaper /path/to/image"
    exit 1
fi

SOURCE="$1"
DEST="/usr/share/sddm/themes/nexa/background.png"

if [[ ! -f "$SOURCE" ]]; then
    echo "File not found: $SOURCE"
    exit 1
fi

sudo cp "$SOURCE" "$DEST"

echo "SDDM wallpaper updated:"
echo "$DEST"
```

---

## Recommended Dependencies

NEXA uses several external tools depending on which modules are enabled.

Common dependencies include:

```text
Hyprland
Quickshell
Rust / Cargo
awww
mpvpaper
Matugen
hyprsunset
hypridle
cliphist
wl-clipboard
wf-recorder
playerctl
PipeWire
WirePlumber
ffmpeg
SDDM
```

Individual modules may require additional tools.

---

## Configuration

Main configuration files live under:

```text
~/.config/nexa/config/
```

including:

```text
cava.conf
lockscreen.conf
nexa.toml
notifications.conf
quicksettings.conf
screen-filter.conf
screen-temp.conf
shortcuts.toml
theme.conf
wallpaper.conf
weather.conf
```

---

## Git Backup

Generated build files should normally stay out of Git.

Recommended `.gitignore`:

```gitignore
rust/target/

*.log
*.tmp

.cache/
```

Before publishing the repository, check that no passwords, API keys, tokens, private certificates, or other secrets are present.

---

## Philosophy

NEXA is intentionally modular.

```text
Rust
  └── system logic, state, commands

Quickshell / QML
  └── interface and presentation

Hyprland
  └── compositor, input, workspace and window management

Matugen
  └── color generation and application theming
```

The goal is not to duplicate everything a desktop environment can do.

Each feature should exist because it is useful, remain small where possible, and avoid unnecessary complexity.

---

## Status

NEXA is currently intended to be used as a daily desktop environment.

Major shell components are implemented and usable, while the project remains open to small future improvements when genuinely needed.

---

## License

Choose a license before publishing the repository publicly.

For a private backup repository, this section can be removed until a license is selected.
