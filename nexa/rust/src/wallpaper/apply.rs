use super::list::{classify, ensure_proxy, ensure_thumbnail, wallpaper_dir};
use std::{
    env, fs,
    path::{Path, PathBuf},
    process::Command,
};

// ============================================================
// CONFIG PATHS
// ============================================================

pub fn desktop_config_path() -> PathBuf {
    let home = env::var("HOME").unwrap_or_else(|_| String::from("."));
    PathBuf::from(home)
        .join(".config")
        .join("nexa")
        .join("config")
        .join("wallpaper.conf")
}

pub fn lock_config_path() -> PathBuf {
    let home = env::var("HOME").unwrap_or_else(|_| String::from("."));
    PathBuf::from(home)
        .join(".config")
        .join("nexa")
        .join("config")
        .join("lockscreen.conf")
}

// ============================================================
// CONFIG PARSING & STATE
// ============================================================

pub fn config_escape(value: &str) -> String {
    let mut escaped = String::new();
    for character in value.chars() {
        match character {
            '\\' | ' ' | '\t' | '\'' | '"' | '$' | '`' => {
                escaped.push('\\');
                escaped.push(character);
            }
            _ => escaped.push(character),
        }
    }
    escaped
}

pub fn config_unescape(value: &str) -> String {
    let value = value.trim();
    if value.len() >= 2 {
        if (value.starts_with('"') && value.ends_with('"'))
            || (value.starts_with('\'') && value.ends_with('\''))
        {
            return value[1..value.len() - 1].to_string();
        }
    }

    let mut result = String::new();
    let mut characters = value.chars();
    while let Some(character) = characters.next() {
        if character == '\\' {
            if let Some(next) = characters.next() {
                result.push(next);
            }
        } else {
            result.push(character);
        }
    }
    result
}

pub fn parse_wallpaper_config(contents: &str) -> (String, String) {
    let mut path = String::new();
    let mut kind = String::new();

    for line in contents.lines() {
        if let Some(value) = line.strip_prefix("WALLPAPER=") {
            path = config_unescape(value);
        }
        if let Some(value) = line.strip_prefix("WALLPAPER_TYPE=") {
            kind = config_unescape(value);
        }
    }
    (path, kind)
}

pub fn load_current_wallpaper_state() -> (String, Option<PathBuf>, String) {
    let config = desktop_config_path();
    let mut prev_type = String::new();
    let mut prev_theme_source = None;
    let mut prev_wallpaper = String::new();

    if let Ok(content) = fs::read_to_string(&config) {
        for line in content.lines() {
            let line = line.trim();
            if let Some(val) = line.strip_prefix("WALLPAPER=") {
                prev_wallpaper = config_unescape(val);
            } else if let Some(val) = line.strip_prefix("WALLPAPER_TYPE=") {
                prev_type = config_unescape(val);
            } else if let Some(val) = line.strip_prefix("THEME_SOURCE=") {
                let s = config_unescape(val);
                if !s.is_empty() {
                    prev_theme_source = Some(PathBuf::from(s));
                }
            }
        }
    }
    (prev_type, prev_theme_source, prev_wallpaper)
}

pub fn get_current_desktop() -> (String, String) {
    let (_, _, path) = load_current_wallpaper_state();
    let name = Path::new(&path)
        .file_name()
        .map(|n| n.to_string_lossy().to_string())
        .unwrap_or_default();
    (path, name)
}

pub fn get_current_lock() -> (String, String) {
    let config = lock_config_path();
    if let Ok(contents) = fs::read_to_string(&config) {
        let (path, _) = parse_wallpaper_config(&contents);
        let name = Path::new(&path)
            .file_name()
            .map(|n| n.to_string_lossy().to_string())
            .unwrap_or_default();
        return (path, name);
    }
    (String::new(), String::new())
}

// ============================================================
// SHUFFLE RESOLUTION
// ============================================================

pub fn resolve_shuffle(dir: Option<&Path>) -> Option<PathBuf> {
    let default_dir = wallpaper_dir();
    let base_dir = dir.unwrap_or(&default_dir);
    if !base_dir.exists() {
        return None;
    }

    let (_, _, current_wp) = load_current_wallpaper_state();

    let mut candidates = Vec::new();
    for entry in walkdir::WalkDir::new(base_dir).max_depth(2).into_iter().flatten() {
        let path = entry.path();
        if !path.is_file() {
            continue;
        }
        let s = path.to_string_lossy();
        if s.contains("/.") || s.contains("/thumbs/") || s.contains("/slideshow_thumbs/") {
            continue;
        }
        if classify(path).is_some() {
            candidates.push(path.to_path_buf());
        }
    }

    if candidates.is_empty() {
        return None;
    }

    let eligible: Vec<&PathBuf> = if candidates.len() > 1 && !current_wp.is_empty() {
        let filtered: Vec<&PathBuf> = candidates
            .iter()
            .filter(|p| p.to_string_lossy() != current_wp)
            .collect();
        if filtered.is_empty() {
            candidates.iter().collect()
        } else {
            filtered
        }
    } else {
        candidates.iter().collect()
    };

    let nanos = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.subsec_nanos() as usize)
        .unwrap_or(0);
    let idx = nanos % eligible.len();
    Some(eligible[idx].clone())
}

// ============================================================
// GIF TO HARDWARE-ACCELERATED MP4 CONVERSION
// ============================================================

pub fn gif_mp4_cache_dir() -> PathBuf {
    let home = env::var("HOME").unwrap_or_else(|_| String::from("."));
    PathBuf::from(home)
        .join(".cache")
        .join("nexa")
        .join("wallpapers")
        .join("gif_mp4")
}

pub fn ensure_gif_mp4(gif_path: &Path) -> Result<PathBuf, String> {
    let name = gif_path
        .file_name()
        .ok_or_else(|| "Invalid file name".to_string())?
        .to_string_lossy();
    let cache_dir = gif_mp4_cache_dir();
    fs::create_dir_all(&cache_dir)
        .map_err(|e| format!("Failed to create gif_mp4 cache dir: {e}"))?;

    let target = cache_dir.join(format!("{}.mp4", name));

    if target.exists() {
        if let (Ok(target_meta), Ok(gif_meta)) = (target.metadata(), gif_path.metadata()) {
            if target_meta.len() > 0 {
                if let (Ok(target_mtime), Ok(gif_mtime)) = (target_meta.modified(), gif_meta.modified()) {
                    if target_mtime >= gif_mtime {
                        return Ok(target);
                    }
                } else {
                    return Ok(target);
                }
            }
        }
    }

    let temp_target = cache_dir.join(format!(".{}.{}.tmp.mp4", name, std::process::id()));

    let status = Command::new("nice")
        .args([
            "-n", "19",
            "ffmpeg",
            "-loglevel", "error",
            "-threads", "2",
            "-i",
        ])
        .arg(gif_path)
        .args([
            "-vf", "scale=trunc(iw/2)*2:trunc(ih/2)*2",
            "-c:v", "libx264",
            "-pix_fmt", "yuv420p",
            "-f", "mp4",
            "-movflags", "+faststart",
            "-y",
        ])
        .arg(&temp_target)
        .status()
        .map_err(|e| format!("Failed to run ffmpeg: {e}"))?;

    if status.success() && temp_target.exists() {
        fs::rename(&temp_target, &target)
            .map_err(|e| format!("Failed to commit converted mp4: {e}"))?;
        Ok(target)
    } else {
        let _ = fs::remove_file(&temp_target);
        Err("ffmpeg conversion failed".to_string())
    }
}

// ============================================================
// APPLY DESKTOP WALLPAPER
// ============================================================

pub fn apply_desktop(
    path: &str,
    monitor: Option<&str>,
    opt_restore: bool,
    opt_no_theme: bool,
) -> Result<(), String> {
    let resolved_path = if path == "next" || path == "shuffle" || path == "random" {
        resolve_shuffle(None).ok_or_else(|| "No wallpapers found for shuffle/next".to_string())?
    } else {
        let mut p = PathBuf::from(path);
        if path.starts_with("~/") {
            if let Ok(home) = env::var("HOME") {
                p = PathBuf::from(home).join(&path[2..]);
            }
        }
        if let Ok(c) = p.canonicalize() {
            p = c;
        }
        p
    };

    if !resolved_path.is_file() {
        return Err(format!(
            "Wallpaper does not exist: {}",
            resolved_path.display()
        ));
    }

    let kind = classify(&resolved_path)
        .ok_or_else(|| format!("Unsupported wallpaper format: {}", resolved_path.display()))?;

    let monitor_target = monitor.unwrap_or("*");

    let (prev_kind, prev_thumb, current_wp) = load_current_wallpaper_state();

    if !opt_restore && !current_wp.is_empty() && resolved_path.to_string_lossy() == current_wp {
        println!("desktop_wallpaper_unchanged={}", current_wp);
        return Ok(());
    }

    let mut theme_source_path = resolved_path.clone();
    let mut target_thumb = None;

    if kind == "video" || kind == "gif" {
        let thumb_path = ensure_thumbnail(&resolved_path, kind);
        theme_source_path = thumb_path.clone();
        target_thumb = Some(thumb_path);
    }

    let engine_path = if kind == "gif" {
        ensure_gif_mp4(&resolved_path).unwrap_or_else(|e| {
            eprintln!("Warning: failed to convert GIF to hardware-accelerated MP4: {e}");
            resolved_path.clone()
        })
    } else {
        resolved_path.clone()
    };
    let engine_kind = if kind == "gif" && engine_path.extension().map_or(false, |e| e == "mp4") {
        "video"
    } else {
        kind
    };

    super::transition::apply_with_handshake(
        &engine_path,
        engine_kind,
        monitor_target,
        &prev_kind,
        prev_thumb.as_deref(),
        target_thumb.as_deref(),
        opt_restore,
    )?;

    let config = desktop_config_path();
    if let Some(parent) = config.parent() {
        let _ = fs::create_dir_all(parent);
    }

    let preview_path = if let Some(ref t) = target_thumb {
        t.clone()
    } else {
        ensure_thumbnail(&resolved_path, kind)
    };

    let contents = format!(
        "WALLPAPER={}\nWALLPAPER_TYPE={}\nTHEME_SOURCE={}\nPREVIEW={}\nMONITOR={}\n",
        config_escape(&resolved_path.to_string_lossy()),
        kind,
        config_escape(&theme_source_path.to_string_lossy()),
        config_escape(&preview_path.to_string_lossy()),
        config_escape(monitor_target)
    );
    let _ = crate::core::fs_utils::atomic_write(&config, contents);

    println!("desktop_wallpaper={}|{}", kind, resolved_path.display());

    if opt_restore || opt_no_theme {
        return Ok(());
    }

    let _ = crate::palette::theme::apply();
    let _ = crate::hardware::screenTemp::handle(&[
        "wallpaper".to_string(),
        theme_source_path.to_string_lossy().to_string(),
    ]);

    Ok(())
}

// ============================================================
// SET LOCK WALLPAPER
// ============================================================

pub fn set_lock(path: &str) -> Result<(), String> {
    let mut path_buf = PathBuf::from(path);
    if path.starts_with("~/") {
        if let Ok(home) = env::var("HOME") {
            path_buf = PathBuf::from(home).join(&path[2..]);
        }
    }
    if let Ok(c) = path_buf.canonicalize() {
        path_buf = c;
    }

    if !path_buf.is_file() {
        return Err(format!("Lock wallpaper does not exist: {}", path_buf.display()));
    }

    let kind = classify(&path_buf)
        .ok_or_else(|| format!("Unsupported lock wallpaper: {}", path_buf.display()))?;

    let (current_lock, _) = get_current_lock();
    if !current_lock.is_empty() && path_buf.to_string_lossy() == current_lock {
        println!("lock_wallpaper_unchanged={}", current_lock);
        return Ok(());
    }

    let config = lock_config_path();
    if let Some(parent) = config.parent() {
        fs::create_dir_all(parent)
            .map_err(|error| format!("Failed to create lockscreen config directory: {}", error))?;
    }

    let _ = ensure_thumbnail(&path_buf, kind);
    if kind == "video" {
        let _ = ensure_proxy(&path_buf, kind);
    }

    let contents = format!(
        "WALLPAPER={}\nWALLPAPER_TYPE={}\n",
        config_escape(&path_buf.to_string_lossy()),
        kind
    );

    crate::core::fs_utils::atomic_write(&config, contents)?;

    if let Ok(home) = env::var("HOME") {
        let cache_wp = PathBuf::from(home).join(".cache/current_wallpaper");
        let _ = fs::copy(&path_buf, &cache_wp);
    }

    println!("lock_wallpaper={}|{}", kind, path_buf.display());
    Ok(())
}

// ============================================================
// UNIFIED APPLY TARGET (Background, Lock Screen, Both)
// ============================================================

pub fn apply_target(path: &str, target: &str, monitor: Option<&str>) -> Result<(), String> {
    let t = target.trim().to_ascii_lowercase();
    match t.as_str() {
        "lock screen" | "lock" | "lockscreen" => set_lock(path),
        "both" => {
            let _ = set_lock(path);
            apply_desktop(path, monitor, false, false)
        }
        _ => apply_desktop(path, monitor, false, false),
    }
}

// ============================================================
// RESTORE DESKTOP
// ============================================================

pub fn restore_desktop() -> Result<(), String> {
    let home = env::var("HOME").unwrap_or_else(|_| String::from("."));
    let slideshow_cfg = PathBuf::from(&home).join(".config/nexa/config/slideshow.json");
    if slideshow_cfg.exists() {
        if let Ok(content) = fs::read_to_string(&slideshow_cfg) {
            if let Ok(v) = serde_json::from_str::<serde_json::Value>(&content) {
                let enabled = v.get("enabled").and_then(|e| e.as_bool()).unwrap_or(false);
                let paused = v.get("paused").and_then(|p| p.as_bool()).unwrap_or(false);
                if enabled && !paused {
                    let _ = super::slideshow::next();
                    return Ok(());
                }
            }
        }
    }

    let config = desktop_config_path();
    if !config.exists() {
        return Ok(());
    }

    let contents = fs::read_to_string(&config)
        .map_err(|e| format!("Failed to read wallpaper config: {e}"))?;

    let mut path = String::new();
    let mut monitor = String::from("*");

    for line in contents.lines() {
        let line = line.trim();
        if let Some(val) = line.strip_prefix("WALLPAPER=") {
            path = config_unescape(val);
        } else if let Some(val) = line.strip_prefix("MONITOR=") {
            monitor = config_unescape(val);
        }
    }

    if path.is_empty() {
        return Ok(());
    }

    apply_desktop(&path, Some(&monitor), true, true)
}

// ============================================================
// PRINT LOCK INFO
// ============================================================

pub fn print_lock_info() -> Result<(), String> {
    let lock_config = lock_config_path();

    if lock_config.exists() {
        let contents = fs::read_to_string(&lock_config)
            .map_err(|error| format!("Failed to read lockscreen config: {}", error))?;

        let (lock_path, lock_type) = parse_wallpaper_config(&contents);

        if !lock_path.is_empty() {
            let proxy = ensure_proxy(Path::new(&lock_path), &lock_type);
            let proxy_str = proxy.map(|p| p.display().to_string()).unwrap_or_default();
            println!("{}|{}|{}", lock_type, lock_path, proxy_str);
            return Ok(());
        }
    }

    let desktop_config = desktop_config_path();
    let contents = fs::read_to_string(&desktop_config)
        .map_err(|error| format!("Failed to read desktop wallpaper config: {}", error))?;

    let (desktop_path, desktop_type) = parse_wallpaper_config(&contents);

    if desktop_path.is_empty() {
        return Err("Desktop wallpaper is not configured".to_string());
    }

    let proxy = ensure_proxy(Path::new(&desktop_path), &desktop_type);
    let proxy_str = proxy.map(|p| p.display().to_string()).unwrap_or_default();
    println!("{}|{}|{}", desktop_type, desktop_path, proxy_str);

    Ok(())
}

