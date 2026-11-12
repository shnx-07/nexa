use serde::{Deserialize, Serialize};
use std::{
    env, fs,
    path::{Path, PathBuf},
    process::Command,
    time::{SystemTime, UNIX_EPOCH},
};

// ============================================================
// CONFIG MODEL
// ============================================================

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SlideshowConfig {
    pub enabled: bool,
    pub paused: bool,
    pub interval: String,     // "1m", "5m", "10m", "15m", "30m", "1h"
    pub type_filter: String,  // "All", "Image", "GIF", "Video"
    pub apply_target: String, // "Background", "Lock Screen", "Both"
    #[serde(default)]
    pub last_wallpaper: String,
    #[serde(default)]
    pub last_changed: u64,
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
            last_changed: 0,
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
    home_dir()
        .join("Pictures")
        .join("Wallpapers")
        .join("Slideshow")
}

fn config_path() -> PathBuf {
    home_dir()
        .join(".config")
        .join("nexa")
        .join("config")
        .join("slideshow.json")
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
    fs::write(&path, json).map_err(|e| format!("Failed to write slideshow config: {e}"))?;
    Ok(())
}

fn random_index(max: usize) -> usize {
    if max <= 1 {
        return 0;
    }
    let nanos = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_nanos();
    let mut z = (nanos as u64).wrapping_add(0x9e3779b97f4a7c15);
    z = (z ^ (z >> 30)).wrapping_mul(0xbf58476d1ce4e5b9);
    z = (z ^ (z >> 27)).wrapping_mul(0x94d049bb133111eb);
    z = z ^ (z >> 31);
    (z as usize) % max
}

fn classify_type(path: &Path) -> Option<&'static str> {
    let ext = path.extension()?.to_str()?.to_lowercase();
    match ext.as_str() {
        "png" | "jpg" | "jpeg" | "webp" => Some("Image"),
        "gif" => Some("GIF"),
        "mp4" | "mkv" | "mov" | "webm" => Some("Video"),
        _ => None,
    }
}

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

    if !dir.exists() {
        let _ = fs::create_dir_all(&dir);
        notify_empty_folder();
        return Err(format!(
            "Created slideshow folder: {}. Please add wallpapers.",
            dir.display()
        ));
    }

    let read_dir = fs::read_dir(&dir)
        .map_err(|e| format!("Failed to read slideshow directory {}: {e}", dir.display()))?;

    let mut candidates: Vec<PathBuf> = Vec::new();

    for entry in read_dir.flatten() {
        let path = entry.path();
        if path.is_file() {
            if let Some(kind) = classify_type(&path) {
                if cfg.type_filter.is_empty()
                    || cfg.type_filter.eq_ignore_ascii_case("all")
                    || cfg.type_filter.eq_ignore_ascii_case(kind)
                {
                    candidates.push(path);
                }
            }
        }
    }

    candidates.sort();

    if candidates.is_empty() {
        notify_empty_folder();
        return Err(
            "No matching wallpapers found in ~/Pictures/Wallpapers/Slideshow".to_string(),
        );
    }

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

    let now = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_secs();
    let mut updated_cfg = cfg.clone();
    updated_cfg.last_wallpaper = selected_str.clone();
    updated_cfg.last_changed = now;
    let _ = save_config(&updated_cfg);

    let target = &cfg.apply_target;
    let t = target.trim().to_ascii_lowercase();

    if t == "background" || t == "both" || t.is_empty() {
        let _ = super::apply::apply_desktop(&selected_str, None, false, false);
    }

    if t == "lock screen" || t == "lock" || t == "lockscreen" || t == "both" {
        let _ = super::apply::set_lock(&selected_str);
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
            "--current" | "--last-wallpaper" | "--wallpaper" => {
                if i + 1 < args.len() {
                    let wall = args[i + 1].clone();
                    set_last_wallpaper(&wall);
                    cfg.last_wallpaper = wall;
                    cfg.last_changed = SystemTime::now()
                        .duration_since(UNIX_EPOCH)
                        .unwrap_or_default()
                        .as_secs();
                    i += 1;
                }
            }
            _ => {}
        }
        i += 1;
    }

    if cfg.last_changed == 0 {
        cfg.last_changed = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap_or_default()
            .as_secs();
    }

    save_config(&cfg)?;
    print_status();
    Ok(())
}

pub fn pause() -> Result<(), String> {
    let mut cfg = load_config();
    cfg.paused = true;
    save_config(&cfg)?;
    print_status();
    Ok(())
}

pub fn resume() -> Result<(), String> {
    let mut cfg = load_config();
    cfg.paused = false;
    save_config(&cfg)?;
    print_status();
    Ok(())
}

pub fn toggle() -> Result<(), String> {
    let mut cfg = load_config();
    if cfg.enabled {
        cfg.paused = !cfg.paused;
    } else {
        cfg.enabled = true;
        cfg.paused = false;
    }
    save_config(&cfg)?;
    print_status();
    Ok(())
}

pub fn set_current(path: &str) -> Result<(), String> {
    let mut cfg = load_config();
    set_last_wallpaper(path);
    cfg.last_wallpaper = path.to_string();
    cfg.last_changed = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_secs();
    save_config(&cfg)?;
    Ok(())
}

pub fn prev() -> Result<String, String> {
    let cfg = load_config();
    if !cfg.last_wallpaper.is_empty() {
        super::apply::apply_target(&cfg.last_wallpaper, &cfg.apply_target, None)?;
        return Ok(cfg.last_wallpaper);
    }
    next()
}

pub fn parse_interval_secs(interval: &str) -> u64 {
    match interval {
        "1m" => 60,
        "5m" => 300,
        "10m" => 600,
        "15m" => 900,
        "30m" => 1800,
        "1h" => 3600,
        _ => 600,
    }
}

pub fn is_screen_locked() -> bool {
    if crate::desktop::lock::lock_flag_path().exists() {
        return true;
    }
    Path::new("/tmp/nexa-locked").exists() || Path::new("/tmp/hyprlock-active").exists()
}

pub fn run_daemon() -> ! {
    eprintln!("[NEXA Slideshow Daemon] Started background scheduler");
    loop {
        std::thread::sleep(std::time::Duration::from_secs(5));

        let cfg = load_config();
        if !cfg.enabled || cfg.paused {
            continue;
        }

        if is_screen_locked() {
            continue;
        }

        let now = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap_or_default()
            .as_secs();

        let interval_secs = parse_interval_secs(&cfg.interval);
        let elapsed = now.saturating_sub(cfg.last_changed);

        if elapsed >= interval_secs {
            eprintln!(
                "[NEXA Slideshow Daemon] Interval elapsed ({}s >= {}s), triggering next wallpaper",
                elapsed, interval_secs
            );
            if let Err(e) = next() {
                eprintln!("[NEXA Slideshow Daemon] Error changing wallpaper: {e}");
            }
        }
    }
}

