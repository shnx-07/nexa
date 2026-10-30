use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::env;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};

pub const SOUND_EVENTS: &[(&str, &str, &str)] = &[
    ("volumne", "Volume Feedback", "Subtle acoustic click on volume change"),
    ("screenshot_sound", "Screenshot Shutter", "Shutter click when screen is captured"),
    ("charging_cable_insert", "Charger Connected", "Positive chime when AC power is connected"),
    ("charging_cable_remove", "Charger Disconnected", "Alert chime when AC power is unplugged"),
    ("Full-battery-charge", "Battery Full (100%)", "Chime when battery reaches 100% capacity"),
    ("low_battery", "Low Battery Warning", "Warning chime when battery drops below threshold"),
    ("lock", "Session Locked", "Soft mechanical click on screen lock"),
    ("unlock", "Session Unlocked", "Desktop entry chime when unlocked"),
    ("notification", "Notification Alert", "Audible chime for incoming notifications"),
    ("trash", "Trash & Clear", "Tactile sweep sound when clearing items or trash"),
];

const SUPPORTED_EXTENSIONS: &[&str] = &[
    "mp3", "wav", "ogg", "oga", "flac", "m4a", "opus", "aac", "wma",
];

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct SoundItemConfig {
    #[serde(default = "default_true")]
    pub enabled: bool,
    #[serde(default = "default_80")]
    pub volume: u32,
}

fn default_true() -> bool {
    true
}
fn default_80() -> u32 {
    80
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct SoundConfig {
    #[serde(default = "default_true")]
    pub master_enabled: bool,
    #[serde(default = "default_80")]
    pub master_volume: u32,
    #[serde(default)]
    pub sounds: HashMap<String, SoundItemConfig>,
}

impl Default for SoundConfig {
    fn default() -> Self {
        let mut sounds = HashMap::new();
        for (name, _, _) in SOUND_EVENTS {
            let vol = match *name {
                "volumne" => 40,
                "screenshot_sound" => 80,
                "charging_cable_insert" | "charging_cable_remove" => 75,
                "Full-battery-charge" => 80,
                "low_battery" => 90,
                "lock" | "unlock" => 55,
                "notification" => 70,
                "trash" => 60,
                _ => 70,
            };
            sounds.insert(
                name.to_string(),
                SoundItemConfig {
                    enabled: true,
                    volume: vol,
                },
            );
        }

        Self {
            master_enabled: true,
            master_volume: 80,
            sounds,
        }
    }
}

pub fn get_sound_dir() -> PathBuf {
    let home = env::var("HOME").unwrap_or_else(|_| "/home/shnx".to_string());
    PathBuf::from(home).join(".config/nexa/sounds")
}

pub fn get_config_path() -> PathBuf {
    let home = env::var("HOME").unwrap_or_else(|_| "/home/shnx".to_string());
    PathBuf::from(home).join(".config/nexa/config/sound.json")
}

pub fn load_config() -> SoundConfig {
    let path = get_config_path();
    if let Ok(content) = fs::read_to_string(&path) {
        if let Ok(cfg) = serde_json::from_str::<SoundConfig>(&content) {
            return cfg;
        }
    }
    SoundConfig::default()
}

pub fn save_config(cfg: &SoundConfig) -> Result<(), String> {
    let path = get_config_path();
    if let Some(parent) = path.parent() {
        let _ = fs::create_dir_all(parent);
    }
    let json = serde_json::to_string_pretty(cfg)
        .map_err(|e| format!("Failed to serialize sound config: {e}"))?;
    fs::write(&path, json).map_err(|e| format!("Failed to write sound config: {e}"))
}

/// Resolves standard alias names (e.g. "volume" -> "volumne", "screenshot" -> "screenshot_sound").
pub fn canonical_name(event: &str) -> &str {
    match event {
        "volume" | "volumne" => "volumne",
        "screenshot" | "screenshot_sound" | "snip" | "shutter" => "screenshot_sound",
        "charging" | "charger_insert" | "plug" | "charging_cable_insert" => "charging_cable_insert",
        "unplug" | "charger_remove" | "discharging" | "charging_cable_remove" => "charging_cable_remove",
        "full_battery" | "battery_full" | "Full-battery-charge" => "Full-battery-charge",
        "low_battery" | "battery_low" => "low_battery",
        "lock" => "lock",
        "unlock" => "unlock",
        "notification" | "alert" => "notification",
        "trash" | "empty_trash" | "clear" => "trash",
        other => other,
    }
}

/// Extension-agnostic file resolver. Looks for `<name>.<ext>` in `~/.config/nexa/sounds/`.
/// Accepts any supported extension (.mp3, .wav, .ogg, .oga, .flac, etc.).
pub fn resolve_sound_file(event: &str) -> Option<PathBuf> {
    let cname = canonical_name(event);
    let sound_dir = get_sound_dir();
    if !sound_dir.is_dir() {
        return None;
    }

    // 1. Direct match with supported extensions
    for ext in SUPPORTED_EXTENSIONS {
        let candidate = sound_dir.join(format!("{cname}.{ext}"));
        if candidate.is_file() {
            return Some(candidate);
        }
    }

    // 2. Case-insensitive search inside ~/.config/nexa/sounds/
    if let Ok(entries) = fs::read_dir(&sound_dir) {
        let target_lower = cname.to_lowercase();
        for entry in entries.flatten() {
            let p = entry.path();
            if p.is_file() {
                if let Some(stem) = p.file_stem() {
                    if stem.to_string_lossy().to_lowercase() == target_lower {
                        return Some(p);
                    }
                }
            }
        }
    }

    // 3. Fallback to freedesktop sounds for standard events if custom file missing
    let freedesktop = match cname {
        "screenshot_sound" => Some("/usr/share/sounds/freedesktop/stereo/camera-shutter.oga"),
        "charging_cable_insert" => Some("/usr/share/sounds/freedesktop/stereo/device-added.oga"),
        "charging_cable_remove" => Some("/usr/share/sounds/freedesktop/stereo/device-removed.oga"),
        "notification" => Some("/usr/share/sounds/freedesktop/stereo/message.oga"),
        "trash" => Some("/usr/share/sounds/freedesktop/stereo/trash-empty.oga"),
        "volumne" => Some("/usr/share/sounds/freedesktop/stereo/audio-volume-change.oga"),
        _ => None,
    };

    if let Some(fd_path) = freedesktop {
        let p = PathBuf::from(fd_path);
        if p.is_file() {
            return Some(p);
        }
    }

    None
}

/// Plays a sound event.
/// - If `is_preview` is true, plays regardless of enabled state.
/// - `custom_volume` allows overriding volume (e.g. for preview testing).
pub fn play_event(
    event: &str,
    is_preview: bool,
    custom_volume: Option<u32>,
) -> Result<(), String> {
    let cname = canonical_name(event);
    let cfg = load_config();

    if !is_preview && !cfg.master_enabled {
        return Ok(());
    }

    let item_cfg = cfg.sounds.get(cname).cloned().unwrap_or(SoundItemConfig {
        enabled: true,
        volume: 75,
    });

    if !is_preview && !item_cfg.enabled {
        return Ok(());
    }

    let file_path = resolve_sound_file(cname).ok_or_else(|| {
        format!("No audio file found for sound event '{cname}' in {:?}", get_sound_dir())
    })?;

    let effective_item_vol = custom_volume.unwrap_or(item_cfg.volume);
    let linear_vol = (cfg.master_volume as f64 / 100.0) * (effective_item_vol as f64 / 100.0);
    let clamped_vol = linear_vol.clamp(0.01, 1.0);

    // Spawn detached playback via PipeWire (pw-play)
    spawn_playback(&file_path, clamped_vol)
}

/// Spawns detached player process with volume scaling.
fn spawn_playback(path: &Path, volume: f64) -> Result<(), String> {
    // Try pw-play (native PipeWire, lowest latency)
    let mut cmd = Command::new("pw-play");
    cmd.arg(format!("--volume={:.2}", volume));
    cmd.arg(path);
    cmd.stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null());

    if let Ok(_child) = cmd.spawn() {
        return Ok(());
    }

    // Fallback: paplay (PulseAudio / PipeWire compat)
    let pa_vol = (volume * 65536.0).round() as u32;
    let mut pa_cmd = Command::new("paplay");
    pa_cmd.arg(format!("--volume={pa_vol}"));
    pa_cmd.arg(path);
    pa_cmd.stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null());

    if let Ok(_child) = pa_cmd.spawn() {
        return Ok(());
    }

    // Fallback: mpv (supports all formats including exotic)
    let mpv_vol = (volume * 100.0).round() as u32;
    let mut mpv_cmd = Command::new("mpv");
    mpv_cmd.args([
        "--no-video",
        "--really-quiet",
        &format!("--volume={mpv_vol}"),
    ]);
    mpv_cmd.arg(path);
    mpv_cmd.stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null());

    mpv_cmd.spawn()
        .map_err(|e| format!("Failed to spawn audio player for {:?}: {e}", path))?;

    Ok(())
}

/// Non-failing helper for internal modules (screenshot, lock, battery, etc.).
pub fn play_sound(event: &str) {
    let _ = play_event(event, false, None);
}

#[derive(Serialize)]
struct SoundStatusItem {
    name: String,
    display_name: String,
    description: String,
    enabled: bool,
    volume: u32,
    file_found: bool,
    file_path: Option<String>,
    file_ext: Option<String>,
}

#[derive(Serialize)]
struct SoundStatusResponse {
    master_enabled: bool,
    master_volume: u32,
    sound_dir: String,
    sounds: Vec<SoundStatusItem>,
}

/// Returns full JSON status of all 10 sounds, active file paths, and current preferences.
pub fn get_status_json() -> Result<String, String> {
    let cfg = load_config();
    let s_dir = get_sound_dir();

    let mut sound_items = Vec::new();

    for (name, display, desc) in SOUND_EVENTS {
        let item_cfg = cfg.sounds.get(*name).cloned().unwrap_or(SoundItemConfig {
            enabled: true,
            volume: 75,
        });

        let found_path = resolve_sound_file(name);
        let (file_found, file_path_str, file_ext) = match found_path {
            Some(p) => {
                let ext = p.extension().map(|e| e.to_string_lossy().to_string());
                (true, Some(p.to_string_lossy().to_string()), ext)
            }
            None => (false, None, None),
        };

        sound_items.push(SoundStatusItem {
            name: name.to_string(),
            display_name: display.to_string(),
            description: desc.to_string(),
            enabled: item_cfg.enabled,
            volume: item_cfg.volume,
            file_found,
            file_path: file_path_str,
            file_ext,
        });
    }

    let resp = SoundStatusResponse {
        master_enabled: cfg.master_enabled,
        master_volume: cfg.master_volume,
        sound_dir: s_dir.to_string_lossy().to_string(),
        sounds: sound_items,
    };

    serde_json::to_string_pretty(&resp)
        .map_err(|e| format!("Failed to serialize sound status: {e}"))
}

/// Updates sound preferences from JSON and saves to disk.
pub fn set_config_from_json(json_str: &str) -> Result<(), String> {
    let incoming: SoundConfig = serde_json::from_str(json_str)
        .map_err(|e| format!("Failed to parse sound config JSON: {e}"))?;

    save_config(&incoming)
}

/// Helper to set master volume
pub fn set_master_volume(volume: u32) -> Result<(), String> {
    let mut cfg = load_config();
    cfg.master_volume = volume.clamp(0, 100);
    save_config(&cfg)
}

/// Helper to set master enabled state
pub fn set_master_enabled(enabled: bool) -> Result<(), String> {
    let mut cfg = load_config();
    cfg.master_enabled = enabled;
    save_config(&cfg)
}

/// Helper to set individual sound volume
pub fn set_sound_volume(name: &str, volume: u32) -> Result<(), String> {
    let mut cfg = load_config();
    let entry = cfg.sounds.entry(name.to_string()).or_insert_with(|| SoundItemConfig {
        enabled: true,
        volume: 75,
    });
    entry.volume = volume.clamp(0, 100);
    save_config(&cfg)
}

/// Helper to set individual sound enabled state
pub fn set_sound_enabled(name: &str, enabled: bool) -> Result<(), String> {
    let mut cfg = load_config();
    let entry = cfg.sounds.entry(name.to_string()).or_insert_with(|| SoundItemConfig {
        enabled: true,
        volume: 75,
    });
    entry.enabled = enabled;
    save_config(&cfg)
}

/// CLI entry point for `nexad sound <subcommand>`
pub fn handle(args: &[String]) -> Result<(), String> {
    if args.is_empty() {
        return Err("Usage: nexad sound <play|preview|get|set|set-master-volume|set-master-enabled|set-sound-volume|set-sound-enabled|folder> [args...]".to_string());
    }

    match args[0].as_str() {
        "play" => {
            let event = args.get(1).ok_or_else(|| "Missing sound event name".to_string())?;
            play_event(event, false, None)
        }
        "preview" => {
            let event = args.get(1).ok_or_else(|| "Missing sound event name".to_string())?;
            let custom_vol = args.get(2).and_then(|v| v.parse::<u32>().ok());
            play_event(event, true, custom_vol)
        }
        "get" | "status" | "list" => {
            let json = get_status_json()?;
            println!("{json}");
            Ok(())
        }
        "set" => {
            let json_str = args.get(1).ok_or_else(|| "Missing sound config JSON".to_string())?;
            set_config_from_json(json_str)?;
            println!("{{\"success\":true}}");
            Ok(())
        }
        "set-master-volume" => {
            let vol = args.get(1).ok_or_else(|| "Missing volume".to_string())?
                .parse::<u32>().map_err(|e| format!("Invalid volume: {e}"))?;
            set_master_volume(vol)?;
            println!("{{\"success\":true,\"master_volume\":{vol}}}");
            Ok(())
        }
        "set-master-enabled" => {
            let en = args.get(1).ok_or_else(|| "Missing enabled (true/false)".to_string())?
                .parse::<bool>().map_err(|e| format!("Invalid boolean: {e}"))?;
            set_master_enabled(en)?;
            println!("{{\"success\":true,\"master_enabled\":{en}}}");
            Ok(())
        }
        "set-sound-volume" => {
            let name = args.get(1).ok_or_else(|| "Missing sound name".to_string())?;
            let vol = args.get(2).ok_or_else(|| "Missing volume".to_string())?
                .parse::<u32>().map_err(|e| format!("Invalid volume: {e}"))?;
            set_sound_volume(name, vol)?;
            println!("{{\"success\":true,\"name\":\"{name}\",\"volume\":{vol}}}");
            Ok(())
        }
        "set-sound-enabled" => {
            let name = args.get(1).ok_or_else(|| "Missing sound name".to_string())?;
            let en = args.get(2).ok_or_else(|| "Missing enabled (true/false)".to_string())?
                .parse::<bool>().map_err(|e| format!("Invalid boolean: {e}"))?;
            set_sound_enabled(name, en)?;
            println!("{{\"success\":true,\"name\":\"{name}\",\"enabled\":{en}}}");
            Ok(())
        }
        "folder" | "open-folder" => {
            let dir = get_sound_dir();
            let _ = Command::new("xdg-open").arg(&dir).spawn();
            Ok(())
        }
        other => Err(format!("Unknown sound subcommand: {other}")),
    }
}

