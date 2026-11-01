use serde::{Deserialize, Serialize};
use std::{
    env, fs,
    path::{Path, PathBuf},
    process::Command,
};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WallpaperEntry {
    pub id: usize,
    pub name: String,
    pub kind: String,
    pub path: String,
    pub thumb: String,
    pub proxy: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WallpaperListPayload {
    pub current_desktop: String,
    pub current_desktop_name: String,
    pub current_lock: String,
    pub current_lock_name: String,
    pub slideshow_enabled: bool,
    pub total: usize,
    pub wallpapers: Vec<WallpaperEntry>,
}

// ============================================================
// DIRECTORIES & CACHING
// ============================================================

pub fn wallpaper_dir() -> PathBuf {
    let home = env::var("HOME").unwrap_or_else(|_| String::from("."));
    PathBuf::from(home).join("Pictures").join("Wallpapers")
}

pub fn thumb_cache_dir() -> PathBuf {
    let home = env::var("HOME").unwrap_or_else(|_| String::from("."));
    PathBuf::from(home)
        .join(".cache")
        .join("nexa")
        .join("wallpapers")
        .join("thumbs")
}

pub fn proxy_cache_dir() -> PathBuf {
    let home = env::var("HOME").unwrap_or_else(|_| String::from("."));
    PathBuf::from(home)
        .join(".cache")
        .join("nexa")
        .join("wallpapers")
        .join("proxies")
}

pub fn classify(path: &Path) -> Option<&'static str> {
    let extension = path.extension()?.to_string_lossy().to_lowercase();
    match extension.as_str() {
        "png" | "jpg" | "jpeg" | "webp" => Some("image"),
        "gif" => Some("gif"),
        "mp4" | "mkv" | "mov" | "webm" => Some("video"),
        _ => None,
    }
}

pub fn ensure_thumbnail(path: &Path, kind: &str) -> PathBuf {
    let Some(name) = path.file_name() else {
        return path.to_path_buf();
    };

    let cache_dir = thumb_cache_dir();
    let _ = fs::create_dir_all(&cache_dir);
    let thumbnail = cache_dir.join(format!("{}.jpg", name.to_string_lossy()));

    if thumbnail.exists() {
        return thumbnail;
    }

    if kind == "video" || kind == "gif" {
        let _ = Command::new("ffmpeg")
            .args(["-loglevel", "error", "-ss", "1", "-i"])
            .arg(path)
            .args(["-frames:v", "1", "-vf", "scale=640:-2", "-q:v", "3", "-y"])
            .arg(&thumbnail)
            .status();
    } else {
        let _ = Command::new("ffmpeg")
            .args(["-loglevel", "error", "-i"])
            .arg(path)
            .args(["-vf", "scale=640:-2", "-q:v", "3", "-y"])
            .arg(&thumbnail)
            .status();
    }

    if thumbnail.exists() {
        thumbnail
    } else {
        path.to_path_buf()
    }
}

pub fn ensure_proxy(path: &Path, kind: &str) -> Option<PathBuf> {
    if kind != "video" {
        return None;
    }

    let name = path.file_name()?;
    let cache_dir = proxy_cache_dir();
    let _ = fs::create_dir_all(&cache_dir);

    let proxy = cache_dir.join(format!("{}.mp4", name.to_string_lossy()));
    if proxy.exists() {
        return Some(proxy);
    }

    let _ = Command::new("ffmpeg")
        .args(["-loglevel", "error", "-ss", "0.0", "-i"])
        .arg(path)
        .args([
            "-vf",
            "scale=-2:480,fps=30",
            "-c:v",
            "libx264",
            "-preset",
            "veryfast",
            "-crf",
            "24",
            "-pix_fmt",
            "yuv420p",
            "-an",
            "-t",
            "15",
            "-y",
        ])
        .arg(&proxy)
        .spawn();

    None
}

// ============================================================
// SCANNING
// ============================================================

pub fn scan_entries(custom_dir: Option<&Path>) -> Vec<WallpaperEntry> {
    let default_dir = wallpaper_dir();
    let directory = custom_dir.unwrap_or(&default_dir);
    let mut wallpapers = Vec::new();

    let entries = match fs::read_dir(directory) {
        Ok(entries) => entries,
        Err(_) => return wallpapers,
    };

    let mut temp = Vec::new();
    for entry in entries.flatten() {
        let path = entry.path();
        if !path.is_file() {
            continue;
        }

        let Some(kind) = classify(&path) else {
            continue;
        };

        let name = path
            .file_name()
            .map(|n| n.to_string_lossy().to_string())
            .unwrap_or_default();

        temp.push((kind, path, name));
    }

    temp.sort_by(|a, b| a.2.to_lowercase().cmp(&b.2.to_lowercase()));

    for (id, (kind, path, name)) in temp.into_iter().enumerate() {
        let thumb = ensure_thumbnail(&path, kind);
        let proxy = ensure_proxy(&path, kind);
        let proxy_str = proxy.map(|p| p.display().to_string()).unwrap_or_default();

        wallpapers.push(WallpaperEntry {
            id,
            name,
            kind: kind.to_string(),
            path: path.display().to_string(),
            thumb: thumb.display().to_string(),
            proxy: proxy_str,
        });
    }

    wallpapers
}

// ============================================================
// PUBLIC CLI & JSON DISPATCHERS
// ============================================================

pub fn print_list_json(filter: Option<&str>, custom_dir: Option<&str>) {
    let custom_path = custom_dir.map(|d| {
        let mut p = PathBuf::from(d);
        if d.starts_with("~/") {
            if let Ok(home) = env::var("HOME") {
                p = PathBuf::from(home).join(&d[2..]);
            }
        }
        p
    });

    let entries = scan_entries(custom_path.as_deref());

    let filtered: Vec<WallpaperEntry> = if let Some(f) = filter {
        let f_lower = f.trim().to_lowercase();
        if f_lower.is_empty() || f_lower == "all" {
            entries
        } else {
            entries.into_iter().filter(|e| e.kind == f_lower).collect()
        }
    } else {
        entries
    };

    let (current_desktop, current_desktop_name) = super::apply::get_current_desktop();
    let (current_lock, current_lock_name) = super::apply::get_current_lock();
    let slideshow_enabled = super::slideshow::load_config().enabled;

    let payload = WallpaperListPayload {
        current_desktop,
        current_desktop_name,
        current_lock,
        current_lock_name,
        slideshow_enabled,
        total: filtered.len(),
        wallpapers: filtered,
    };

    if let Ok(json) = serde_json::to_string(&payload) {
        println!("{json}");
    } else {
        println!("{{\"total\":0,\"wallpapers\":[]}}");
    }
}

pub fn print_list(dir: Option<&str>) {
    let custom_path = dir.map(|d| {
        let mut p = PathBuf::from(d);
        if d.starts_with("~/") {
            if let Ok(home) = env::var("HOME") {
                p = PathBuf::from(home).join(&d[2..]);
            }
        }
        p
    });

    for entry in scan_entries(custom_path.as_deref()) {
        println!("{}|{}|{}|{}", entry.kind, entry.path, entry.thumb, entry.proxy);
    }
}

pub fn print_search(query: &str) {
    let query = query.trim().to_lowercase();
    for entry in scan_entries(None) {
        if query.is_empty() || entry.name.to_lowercase().contains(&query) {
            println!("{}|{}|{}|{}", entry.kind, entry.path, entry.thumb, entry.proxy);
        }
    }
}

pub fn print_search_json(query: &str) {
    let query = query.trim().to_lowercase();
    let entries = scan_entries(None);
    let filtered: Vec<WallpaperEntry> = entries
        .into_iter()
        .filter(|e| query.is_empty() || e.name.to_lowercase().contains(&query))
        .collect();

    let (current_desktop, current_desktop_name) = super::apply::get_current_desktop();
    let (current_lock, current_lock_name) = super::apply::get_current_lock();
    let slideshow_enabled = super::slideshow::load_config().enabled;

    let payload = WallpaperListPayload {
        current_desktop,
        current_desktop_name,
        current_lock,
        current_lock_name,
        slideshow_enabled,
        total: filtered.len(),
        wallpapers: filtered,
    };

    if let Ok(json) = serde_json::to_string(&payload) {
        println!("{json}");
    } else {
        println!("{{\"total\":0,\"wallpapers\":[]}}");
    }
}

pub fn refresh() {
    let wallpapers = scan_entries(None);
    println!("indexed={}", wallpapers.len());
}

pub fn generate_slideshow_thumbs() -> Result<(), String> {
    let home = env::var("HOME").unwrap_or_else(|_| String::from("."));
    let wall_dir = PathBuf::from(&home).join("Pictures/Wallpapers/Slideshow");
    let thumb_dir = PathBuf::from(&home).join(".cache/nexa/wallpapers/slideshow_thumbs");

    if !wall_dir.exists() {
        return Ok(());
    }
    let _ = fs::create_dir_all(&thumb_dir);

    for entry in fs::read_dir(&wall_dir).into_iter().flatten().flatten() {
        let path = entry.path();
        if !path.is_file() {
            continue;
        }
        let stem = match path.file_stem() {
            Some(s) => s.to_string_lossy().to_string(),
            None => continue,
        };
        let target = thumb_dir.join(format!("{stem}.jpg"));
        if target.exists() {
            continue;
        }

        if let Some(kind) = classify(&path) {
            match kind {
                "image" => {
                    let _ = Command::new("ffmpeg")
                        .args(["-loglevel", "error", "-y", "-i"])
                        .arg(&path)
                        .args([
                            "-vf",
                            "scale=320:180:force_original_aspect_ratio=increase,crop=320:180",
                            "-q:v",
                            "3",
                        ])
                        .arg(&target)
                        .status();
                }
                "video" | "gif" => {
                    let _ = Command::new("ffmpeg")
                        .args(["-loglevel", "error", "-ss", "00:00:01", "-y", "-i"])
                        .arg(&path)
                        .args(["-frames:v", "1", "-vf", "scale=480:-2", "-q:v", "3"])
                        .arg(&target)
                        .status();
                }
                _ => {}
            }
        }
    }
    Ok(())
}

