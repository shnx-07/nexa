use serde::{Deserialize, Serialize};
use std::{
    env,
    fs,
    path::PathBuf,
    process::Command,
};

// ============================================================
// SETTINGS STATE MODEL
// ============================================================

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SettingsState {
    #[serde(default = "default_volume")]
    pub volume: u32,

    #[serde(default)]
    pub muted: bool,

    #[serde(default = "default_input_volume")]
    pub input_volume: u32,

    #[serde(default)]
    pub input_muted: bool,

    #[serde(default = "default_brightness")]
    pub brightness: u32,

    #[serde(default = "default_true")]
    pub bluetooth_enabled: bool,

    #[serde(default = "default_true")]
    pub wifi_enabled: bool,

    #[serde(default)]
    pub nightlight_enabled: bool,

    #[serde(default = "default_nightlight_mode")]
    pub nightlight_mode: String,

    #[serde(default = "default_nightlight_temp")]
    pub nightlight_temperature: u32,

    #[serde(default = "default_filter")]
    pub screen_filter: String,

    #[serde(default)]
    pub dnd: bool,
}

fn default_volume() -> u32 { 60 }
fn default_input_volume() -> u32 { 80 }
fn default_brightness() -> u32 { 70 }
fn default_true() -> bool { true }
fn default_nightlight_mode() -> String { "manual".to_string() }
fn default_nightlight_temp() -> u32 { 5000 }
fn default_filter() -> String { "off".to_string() }

impl Default for SettingsState {
    fn default() -> Self {
        Self {
            volume: default_volume(),
            muted: false,
            input_volume: default_input_volume(),
            input_muted: false,
            brightness: default_brightness(),
            bluetooth_enabled: true,
            wifi_enabled: true,
            nightlight_enabled: false,
            nightlight_mode: default_nightlight_mode(),
            nightlight_temperature: default_nightlight_temp(),
            screen_filter: default_filter(),
            dnd: false,
        }
    }
}

// ============================================================
// STORAGE PATH
// ============================================================

fn state_path() -> PathBuf {
    let home = env::var("HOME").unwrap_or_else(|_| ".".to_string());
    PathBuf::from(home)
        .join(".config")
        .join("nexa")
        .join("config")
        .join("settings-state.json")
}

// ============================================================
// LOAD & SAVE
// ============================================================

pub fn load_state() -> SettingsState {
    let path = state_path();
    if let Ok(content) = fs::read_to_string(&path) {
        if let Ok(state) = serde_json::from_str::<SettingsState>(&content) {
            return state;
        }
    }
    SettingsState::default()
}

pub fn save_state(state: &SettingsState) -> Result<(), String> {
    let path = state_path();
    if let Some(parent) = path.parent() {
        let _ = fs::create_dir_all(parent);
    }
    let json = serde_json::to_string_pretty(state)
        .map_err(|e| format!("Failed to serialize settings state: {e}"))?;
    fs::write(&path, json)
        .map_err(|e| format!("Failed to write settings state to {}: {e}", path.display()))
}

pub fn update_state<F>(update: F) -> Result<SettingsState, String>
where
    F: FnOnce(&mut SettingsState),
{
    let mut state = load_state();
    update(&mut state);
    save_state(&state)?;
    Ok(state)
}

// ============================================================
// SYNC FROM LIVE HARDWARE
// ============================================================

pub fn sync_from_system() -> SettingsState {
    let mut state = load_state();

    // 1. Audio Output
    if let Ok(info) = crate::audio::info() {
        state.volume = info.volume;
        state.muted = info.muted;
    }

    // 2. Audio Input
    if let Ok(info) = crate::audio::input_info() {
        state.input_volume = info.volume;
        state.input_muted = info.muted;
    }

    // 3. Brightness
    if let Ok(info) = crate::brightness::info() {
        state.brightness = info.brightness;
    }

    // 4. Bluetooth
    let service = crate::network::NetworkService::new();
    if let Ok(info) = service.bluetooth_info() {
        state.bluetooth_enabled = info.enabled;
    }

    // 5. Screen Filter
    if let Ok(info) = crate::screenFilter::info() {
        state.screen_filter = info.filter;
    }

    // 6. Save and return
    let _ = save_state(&state);
    state
}

// ============================================================
// RESTORE TO SYSTEM
// ============================================================

pub fn restore_all() -> Result<(), String> {
    let flag_path = PathBuf::from("/tmp/nexa-state-restored");
    if flag_path.exists() {
        println!("settings_state=already_restored_this_boot");
        return Ok(());
    }

    let state = load_state();

    // 1. Audio Output Volume & Mute
    let _ = Command::new("wpctl")
        .args([
            "set-volume",
            "@DEFAULT_AUDIO_SINK@",
            &format!("{}%", state.volume.clamp(0, 100)),
        ])
        .status();

    let _ = Command::new("wpctl")
        .args([
            "set-mute",
            "@DEFAULT_AUDIO_SINK@",
            if state.muted { "1" } else { "0" },
        ])
        .status();

    // 2. Audio Input / Microphone Volume & Mute
    let _ = Command::new("wpctl")
        .args([
            "set-volume",
            "@DEFAULT_AUDIO_SOURCE@",
            &format!("{}%", state.input_volume.clamp(0, 100)),
        ])
        .status();

    let _ = Command::new("wpctl")
        .args([
            "set-mute",
            "@DEFAULT_AUDIO_SOURCE@",
            if state.input_muted { "1" } else { "0" },
        ])
        .status();

    // 3. Screen Brightness
    let _ = Command::new("brightnessctl")
        .args([
            "set",
            &format!("{}%", state.brightness.clamp(1, 100)),
        ])
        .status();

    // 4. Bluetooth State
    if state.bluetooth_enabled {
        let _ = Command::new("rfkill").args(["unblock", "bluetooth"]).status();
        let _ = Command::new("bluetoothctl").args(["power", "on"]).status();
    } else {
        let _ = Command::new("bluetoothctl").args(["power", "off"]).status();
    }

    // 5. Screen Temperature / Night Light
    let _ = crate::screenTemp::handle(&["apply".to_string()]);

    // 6. Screen Filter Shader
    let _ = crate::screenFilter::apply();

    // 7. Do Not Disturb
    if state.dnd {
        crate::notifications::dnd_on();
    } else {
        crate::notifications::dnd_off();
    }

    let _ = fs::write(&flag_path, "1");
    println!("settings_state=restored");
    Ok(())
}

// ============================================================
// CLI HANDLER
// ============================================================

pub fn handle(args: &[String]) -> Result<(), String> {
    let command = args.first().map(String::as_str).unwrap_or("info");

    match command {
        "restore" => {
            restore_all()?;
            println!(
                "{}",
                serde_json::to_string(&load_state())
                    .map_err(|e| e.to_string())?
            );
            Ok(())
        }

        "save" | "sync" => {
            let state = sync_from_system();
            println!(
                "{}",
                serde_json::to_string(&state)
                    .map_err(|e| e.to_string())?
            );
            Ok(())
        }

        "info" => {
            let state = load_state();
            println!(
                "{}",
                serde_json::to_string(&state)
                    .map_err(|e| e.to_string())?
            );
            Ok(())
        }

        "set" => {
            let key = args.get(1).ok_or("missing key")?;
            let val = args.get(2).ok_or("missing value")?;

            let updated = update_state(|s| match key.as_str() {
                "volume" => {
                    if let Ok(v) = val.parse::<u32>() {
                        s.volume = v.clamp(0, 100);
                    }
                }
                "muted" => {
                    s.muted = val == "true" || val == "1";
                }
                "input_volume" => {
                    if let Ok(v) = val.parse::<u32>() {
                        s.input_volume = v.clamp(0, 100);
                    }
                }
                "input_muted" => {
                    s.input_muted = val == "true" || val == "1";
                }
                "brightness" => {
                    if let Ok(v) = val.parse::<u32>() {
                        s.brightness = v.clamp(1, 100);
                    }
                }
                "bluetooth" => {
                    s.bluetooth_enabled = val == "true" || val == "1" || val == "on";
                }
                "wifi" => {
                    s.wifi_enabled = val == "true" || val == "1" || val == "on";
                }
                "dnd" => {
                    s.dnd = val == "true" || val == "1" || val == "on";
                }
                _ => {}
            })?;

            println!(
                "{}",
                serde_json::to_string(&updated)
                    .map_err(|e| e.to_string())?
            );
            Ok(())
        }

        _ => Err("usage: nexad state <restore|save|sync|info|set <key> <val>>".to_string()),
    }
}