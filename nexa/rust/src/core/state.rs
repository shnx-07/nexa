use serde::{Deserialize, Serialize};
use std::{env, fs, path::PathBuf, process::Command};

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
    pub airplane_enabled: bool,

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

    #[serde(default)]
    pub battery_percentage: u32,

    #[serde(default)]
    pub battery_charging: bool,

    #[serde(default)]
    pub on_battery: bool,

    #[serde(default)]
    pub wifi_connected: bool,

    #[serde(default)]
    pub wifi_ssid: String,

    #[serde(default)]
    pub wifi_signal: u8,

    #[serde(default = "default_true")]
    pub wifi_has_internet: bool,

    #[serde(default)]
    pub bluetooth_connected: bool,

    #[serde(default)]
    pub bluetooth_device_name: String,

    #[serde(default)]
    pub bluetooth_device_type: String,

    #[serde(default = "default_minus_one")]
    pub bluetooth_device_battery: i32,

    #[serde(default = "current_timestamp")]
    pub timestamp: u64,
}

fn current_timestamp() -> u64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0)
}

fn default_volume() -> u32 {
    60
}
fn default_input_volume() -> u32 {
    80
}
fn default_brightness() -> u32 {
    70
}
fn default_true() -> bool {
    true
}
fn default_nightlight_mode() -> String {
    "manual".to_string()
}
fn default_nightlight_temp() -> u32 {
    5000
}
fn default_filter() -> String {
    "off".to_string()
}
fn default_minus_one() -> i32 {
    -1
}

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
            airplane_enabled: false,
            nightlight_enabled: false,
            nightlight_mode: default_nightlight_mode(),
            nightlight_temperature: default_nightlight_temp(),
            screen_filter: default_filter(),
            dnd: false,
            battery_percentage: 100,
            battery_charging: false,
            on_battery: false,
            wifi_connected: false,
            wifi_ssid: String::new(),
            wifi_signal: 0,
            wifi_has_internet: true,
            bluetooth_connected: false,
            bluetooth_device_name: String::new(),
            bluetooth_device_type: String::new(),
            bluetooth_device_battery: -1,
            timestamp: current_timestamp(),
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
    let json = serde_json::to_string_pretty(state)
        .map_err(|e| format!("Failed to serialize settings state: {e}"))?;
    crate::core::fs_utils::atomic_write(&path, json)
}

pub fn update_state<F>(update: F) -> Result<SettingsState, String>
where
    F: FnOnce(&mut SettingsState),
{
    let mut state = load_state();
    update(&mut state);
    state.timestamp = current_timestamp();
    save_state(&state)?;
    Ok(state)
}

// ============================================================
// SYNC FROM LIVE HARDWARE
// ============================================================

pub fn sync_from_system() -> SettingsState {
    let mut state = load_state();

    // 1. Audio Output Volume & Mute
    if let Ok(info) = crate::audio::info() {
        state.volume = info.volume;
        state.muted = info.muted;
    }

    // 2. Audio Input (Microphone) Volume & Mute
    if let Ok(info) = crate::audio::input_info() {
        state.input_volume = info.volume;
        state.input_muted = info.muted;
    }

    // 3. Screen Brightness
    if let Ok(info) = crate::brightness::info() {
        state.brightness = info.brightness;
    }

    // Battery & Power State
    if let Ok(bat) = crate::hardware::battery::status() {
        state.battery_percentage = bat.percentage;
        state.battery_charging = bat.charging;
        state.on_battery = bat.on_battery;
    }

    // 4. Bluetooth State
    let net_svc = crate::network::NetworkService::new();
    if let Ok(info) = net_svc.bluetooth_info() {
        state.bluetooth_enabled = info.enabled;
        let connected_dev = info.devices.iter().find(|d| d.connected);
        state.bluetooth_connected = connected_dev.is_some();
        state.bluetooth_device_name = connected_dev.map(|d| d.name.clone()).unwrap_or_default();
        state.bluetooth_device_type = connected_dev.map(|d| d.device_type.clone()).unwrap_or_default();
    }

    // 5. WiFi State
    if let Ok(wifi) = net_svc.wifi_info() {
        state.wifi_enabled = wifi.enabled;
        state.wifi_connected = wifi.connected;
        state.wifi_ssid = wifi.ssid;
        state.wifi_signal = wifi.signal;
    }

    // 6. Airplane Mode
    let airplane_state = crate::system::load_state();
    state.airplane_enabled = airplane_state.airplane_enabled;

    // 7. Night Light
    let st = crate::screenTemp::load_state();
    state.nightlight_enabled = st.enabled;
    state.nightlight_mode = st.mode;
    state.nightlight_temperature = st.temperature;

    // 8. Screen Filter
    if let Ok(info) = crate::screenFilter::info() {
        state.screen_filter = info.filter;
    }

    // 9. Do Not Disturb
    state.dnd = crate::notifications::load_dnd();

    // 10. Stamp and Save
    state.timestamp = current_timestamp();
    let _ = save_state(&state);
    state
}

// ============================================================
// RESTORE TO SYSTEM
// ============================================================

pub fn restore_all(force: bool) -> Result<(), String> {
    let flag_path = crate::lock::runtime_dir().join("state-restored");
    if !force && (flag_path.exists() || std::path::Path::new("/tmp/nexa-state-restored").exists()) {
        println!("settings_state=already_restored_this_boot");
        return Ok(());
    }

    let mut state = load_state();

    // 1. Airplane Mode & Radios (WiFi, Bluetooth)
    if state.airplane_enabled {
        let _ = crate::system::airplane_on();
    } else {
        let _ = crate::system::airplane_off();

        // Restore WiFi
        if state.wifi_enabled {
            let _ = Command::new("rfkill").args(["unblock", "wifi"]).status();
            let _ = Command::new("nmcli").args(["radio", "wifi", "on"]).status();
        } else {
            let _ = Command::new("nmcli")
                .args(["radio", "wifi", "off"])
                .status();
            let _ = Command::new("rfkill").args(["block", "wifi"]).status();
        }

        // Restore Bluetooth
        if state.bluetooth_enabled {
            let _ = Command::new("rfkill")
                .args(["unblock", "bluetooth"])
                .status();
            let _ = Command::new("bluetoothctl").args(["power", "on"]).status();
        } else {
            let _ = Command::new("rfkill").args(["block", "bluetooth"]).status();
            let _ = Command::new("bluetoothctl").args(["power", "off"]).status();
        }
    }

    // 2. Audio Output Volume & Mute
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

    // 3. Audio Input / Microphone Volume & Mute
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

    // 4. Screen Brightness
    let _ = crate::brightness::set(state.brightness);

    // 5. Screen Temperature / Night Light
    let mut st = crate::screenTemp::load_state();
    if st.schedule_mode != "off" {
        let _ = crate::screenTemp::evaluate_schedule(&mut st, true);
    } else {
        let _ = crate::screenTemp::apply_state(&mut st);
        let _ = crate::screenTemp::save_state(&st);
    }
    state.nightlight_enabled = st.enabled;
    state.nightlight_mode = st.mode.clone();
    state.nightlight_temperature = st.temperature;

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
            let force = args.iter().any(|a| a == "--force" || a == "-f");
            restore_all(force)?;
            println!(
                "{}",
                serde_json::to_string(&load_state()).map_err(|e| e.to_string())?
            );
            Ok(())
        }

        "save" | "sync" => {
            let state = sync_from_system();
            println!(
                "{}",
                serde_json::to_string(&state).map_err(|e| e.to_string())?
            );
            Ok(())
        }

        "info" => {
            let state = load_state();
            println!(
                "{}",
                serde_json::to_string(&state).map_err(|e| e.to_string())?
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
                "airplane" => {
                    s.airplane_enabled = val == "true" || val == "1" || val == "on";
                }
                "nightlight" => {
                    s.nightlight_enabled = val == "true" || val == "1" || val == "on";
                }
                "dnd" => {
                    s.dnd = val == "true" || val == "1" || val == "on";
                }
                _ => {}
            })?;

            println!(
                "{}",
                serde_json::to_string(&updated).map_err(|e| e.to_string())?
            );
            Ok(())
        }

        _ => {
            Err("usage: nexad state <restore [--force]|save|sync|info|set <key> <val>>".to_string())
        }
    }
}
