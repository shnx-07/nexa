use std::{
    env,
    fs,
    path::{Path, PathBuf},
    process::Command,
    time::{SystemTime, UNIX_EPOCH},
};
use serde::{Deserialize, Serialize};

// ============================================================
// CONFIG MODEL
// ============================================================

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SlideshowConfig {
    pub enabled: bool,
    pub paused: bool,
    pub interval: String,      // "5m", "10m", "15m", "30m", "1h"
    pub type_filter: String,   // "All", "Image", "GIF", "Video"
    pub apply_target: String,  // "Background", "Lock Screen", "Both"
    #[serde(default)]
    pub last_wallpaper: String,
}

impl Default for SlideshowConfig {
    fn default() -> Self {
        Self {
            enabled: false,
            paused: false,
            interval: "10m".to_string(),
            type_filter: "All".to_string(),
            apply_target: "Background".to_string(),
            last_wallpaper: String::new(),
        }
    }
}

// ============================================================
// PATHS
// ============================================================

fn home_dir() -> PathBuf {
    let home = env::var("HOME").unwrap_or_else(|_| String::from("."));
    PathBuf::from(home)
}

pub fn slideshow_dir() -> PathBuf {
    home_dir().join("Pictures").join("Wallpapers").join("Slideshow")
}

fn config_path() -> PathBuf {
    home_dir().join(".config").join("nexa").join("config").join("slideshow.json")
}

fn apply_script_path() -> PathBuf {
    home_dir().join(".config").join("nexa").join("scripts").join("wallpaper.sh")
}

fn last_wallpaper_cache_path() -> PathBuf {
    PathBuf::from("/tmp/nexa-last-slideshow-wallpaper")
}

fn get_last_wallpaper() -> String {
    fs::read_to_string(last_wallpaper_cache_path())
        .unwrap_or_default()
        .trim()
        .to_string()
}

fn set_last_wallpaper(path: &str) {
    let _ = fs::write(last_wallpaper_cache_path(), path);
}

// ============================================================
// CONFIG PERSISTENCE
// ============================================================

pub fn load_config() -> SlideshowConfig {
    let path = config_path();
    if let Ok(content) = fs::read_to_string(&path) {
        if let Ok(cfg) = serde_json::from_str::<SlideshowConfig>(&content) {
            return cfg;
        }
    }
    SlideshowConfig::default()
}

pub fn save_config(cfg: &SlideshowConfig) -> Result<(), String> {
    let path = config_path();
    if let Some(parent) = path.parent() {
        let _ = fs::create_dir_all(parent);
    }
    let json = serde_json::to_string_pretty(cfg)
        .map_err(|e| format!("Failed to serialize slideshow config: {e}"))?;
    fs::write(&path, json)
        .map_err(|e| format!("Failed to write slideshow config: {e}"))?;
    Ok(())
}

// ============================================================
// RANDOM NUMBER GENERATOR (NO EXTERNAL CRATE)
// ============================================================

fn random_index(max: usize) -> usize {
    if max <= 1 {
        return 0;
    }
    let nanos = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_nanos();
    let mut x = nanos ^ 0x517cc1b727220a95;
    x ^= x << 13;
    x ^= x >> 7;
    x ^= x << 17;
    (x as usize) % max
}

// ============================================================
// FILE CLASSIFICATION
// ============================================================

fn classify_type(path: &Path) -> Option<&'static str> {
    let ext = path.extension()?.to_str()?.to_lowercase();
    match ext.as_str() {
        "png" | "jpg" | "jpeg" | "webp" => Some("Image"),
        "gif" => Some("GIF"),
        "mp4" | "mkv" | "mov" | "webm" => Some("Video"),
        _ => None,
    }
}

// ============================================================
// NOTIFICATION HELPER
// ============================================================

fn notify_empty_folder() {
    let _ = Command::new("notify-send")
        .args([
            "-a", "NEXA Wallpaper Slideshow",
            "-i", "preferences-desktop-wallpaper",
            "NEXA Wallpaper Slideshow",
            "Slideshow folder has fewer than 2 wallpapers. Please add images to ~/Pictures/Wallpapers/Slideshow",
        ])
        .spawn();
}

// ============================================================
// CORE SLIDESHOW LOGIC
// ============================================================

pub fn next() -> Result<String, String> {
    let cfg = load_config();
    let dir = slideshow_dir();

    // 1. Ensure directory exists
    if !dir.exists() {
        let _ = fs::create_dir_all(&dir);
        notify_empty_folder();
        return Err(format!(
            "Created slideshow folder: {}. Please add wallpapers.",
            dir.display()
        ));
    }

    // 2. Scan valid files in directory
    let read_dir = fs::read_dir(&dir)
        .map_err(|e| format!("Failed to read slideshow directory {}: {e}", dir.display()))?;

    let mut candidates: Vec<PathBuf> = Vec::new();

    for entry in read_dir.flatten() {
        let path = entry.path();
        if path.is_file() {
            if let Some(kind) = classify_type(&path) {
                // Filter by configured type
                if cfg.type_filter == "All" || cfg.type_filter.eq_ignore_ascii_case(kind) {
                    candidates.push(path);
                }
            }
        }
    }

    // 3. Graceful fallback if fewer than 2 candidates
    if candidates.len() < 2 {
        notify_empty_folder();
        if candidates.is_empty() {
            return Err("No matching wallpapers found in ~/Pictures/Wallpapers/Slideshow".to_string());
        }
    }

    // 4. Random selection (avoiding immediate repeat if >1 candidate exists)
    let last_wall = get_last_wallpaper();
    let eligible: Vec<&PathBuf> = if candidates.len() > 1 && !last_wall.is_empty() {
        let filtered: Vec<&PathBuf> = candidates
            .iter()
            .filter(|p| p.to_string_lossy() != last_wall)
            .collect();
        if filtered.is_empty() {
            candidates.iter().collect()
        } else {
            filtered
        }
    } else {
        candidates.iter().collect()
    };

    let idx = random_index(eligible.len());
    let selected_path = eligible[idx];
    let selected_str = selected_path.to_string_lossy().to_string();
    set_last_wallpaper(&selected_str);

    // 5. Apply according to apply_target
    let target = cfg.apply_target.as_str();

    if target == "Background" || target == "Both" {
        let script = apply_script_path();
        if script.exists() {
            let _ = Command::new("bash")
                .arg(&script)
                .arg(&selected_str)
                .spawn();
        } else {
            let _ = crate::wallpaper::apply_desktop(&selected_str, None);
        }
    }

    if target == "Lock Screen" || target == "Both" {
        let _ = crate::wallpaper::set_lock(&selected_str);
    }

    println!(
        "{{\"success\":true,\"wallpaper\":\"{}\",\"target\":\"{}\"}}",
        selected_str, target
    );

    Ok(selected_str)
}

// ============================================================
// CLI DISPATCHERS
// ============================================================

pub fn print_status() {
    let cfg = load_config();
    let _ = fs::create_dir_all(slideshow_dir());
    match serde_json::to_string(&cfg) {
        Ok(json) => println!("{json}"),
        Err(e) => eprintln!("Failed to serialize slideshow status: {e}"),
    }
}

pub fn handle_set(args: &[String]) -> Result<(), String> {
    let mut cfg = load_config();
    let mut i = 0;

    while i < args.len() {
        match args[i].as_str() {
            "--enabled" => {
                if i + 1 < args.len() {
                    cfg.enabled = args[i + 1] == "true" || args[i + 1] == "1";
                    i += 1;
                }
            }
            "--paused" => {
                if i + 1 < args.len() {
                    cfg.paused = args[i + 1] == "true" || args[i + 1] == "1";
                    i += 1;
                }
            }
            "--interval" => {
                if i + 1 < args.len() {
                    cfg.interval = args[i + 1].clone();
                    i += 1;
                }
            }
            "--type" => {
                if i + 1 < args.len() {
                    cfg.type_filter = args[i + 1].clone();
                    i += 1;
                }
            }
            "--target" => {
                if i + 1 < args.len() {
                    cfg.apply_target = args[i + 1].clone();
                    i += 1;
                }
            }
            _ => {}
        }
        i += 1;
    }

    save_config(&cfg)?;
    print_status();
    Ok(())
}

