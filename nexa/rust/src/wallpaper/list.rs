use serde::{Deserialize, Serialize};
use std::{
    env, fs,
    io::{Read, Seek, SeekFrom},
    path::{Path, PathBuf},
    process::Command,
};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WallpaperEntry {
    pub id: usize,
    pub name: String,
    pub kind: String,        // "image", "gif", "video"
    pub path: String,
    pub thumb: String,
    pub proxy: String,
    pub width: u32,
    pub height: u32,
    pub aspect_ratio: f32,
    pub size_bytes: u64,
    pub formatted_size: String,
    pub extension: String,
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

pub fn slideshow_dir() -> PathBuf {
    wallpaper_dir().join("Slideshow")
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
        "png" | "jpg" | "jpeg" | "webp" | "bmp" => Some("image"),
        "gif" => Some("gif"),
        "mp4" | "mkv" | "mov" | "webm" => Some("video"),
        _ => None,
    }
}

// ============================================================
// FAST METADATA EXTRACTION (Pure Rust Header Parsing)
// ============================================================

pub fn format_size(bytes: u64) -> String {
    if bytes < 1024 {
        format!("{bytes} B")
    } else if bytes < 1024 * 1024 {
        format!("{:.1} KB", bytes as f64 / 1024.0)
    } else {
        format!("{:.1} MB", bytes as f64 / (1024.0 * 1024.0))
    }
}

pub fn probe_image_dimensions(path: &Path) -> (u32, u32) {
    let mut file = match fs::File::open(path) {
        Ok(f) => f,
        Err(_) => return (0, 0),
    };

    let mut header = [0u8; 32];
    let bytes_read = match file.read(&mut header) {
        Ok(n) => n,
        Err(_) => return (0, 0),
    };

    if bytes_read >= 24 && &header[0..8] == b"\x89PNG\r\n\x1a\n" && &header[12..16] == b"IHDR" {
        let width = u32::from_be_bytes([header[16], header[17], header[18], header[19]]);
        let height = u32::from_be_bytes([header[20], header[21], header[22], header[23]]);
        return (width, height);
    }

    if bytes_read >= 10 && (&header[0..6] == b"GIF87a" || &header[0..6] == b"GIF89a") {
        let width = u16::from_le_bytes([header[6], header[7]]) as u32;
        let height = u16::from_le_bytes([header[8], header[9]]) as u32;
        return (width, height);
    }

    if bytes_read >= 12 && &header[0..4] == b"RIFF" && &header[8..12] == b"WEBP" {
        if bytes_read >= 30 && &header[12..16] == b"VP8X" {
            let width = (header[24] as u32 | ((header[25] as u32) << 8) | ((header[26] as u32) << 16)) + 1;
            let height = (header[27] as u32 | ((header[28] as u32) << 8) | ((header[29] as u32) << 16)) + 1;
            return (width, height);
        }
        if bytes_read >= 30 && &header[12..16] == b"VP8L" && header[20] == 0x2f {
            let b0 = header[21] as u32;
            let b1 = header[22] as u32;
            let b2 = header[23] as u32;
            let b3 = header[24] as u32;
            let width = 1 + (b0 | ((b1 & 0x3f) << 8));
            let height = 1 + (((b1 & 0xc0) >> 6) | (b2 << 2) | ((b3 & 0x0f) << 10));
            return (width, height);
        }
    }

    if bytes_read >= 2 && header[0] == 0xFF && header[1] == 0xD8 {
        if let Ok(_) = file.seek(SeekFrom::Start(2)) {
            let mut marker_buf = [0u8; 4];
            while file.read_exact(&mut marker_buf[0..2]).is_ok() {
                if marker_buf[0] != 0xFF {
                    break;
                }
                let marker = marker_buf[1];
                if marker == 0xD9 || marker == 0xDA {
                    break;
                }
                if file.read_exact(&mut marker_buf[2..4]).is_ok() {
                    let length = u16::from_be_bytes([marker_buf[2], marker_buf[3]]) as usize;
                    if length < 2 {
                        break;
                    }
                    if marker == 0xC0 || marker == 0xC2 {
                        let mut sof = [0u8; 5];
                        if file.read_exact(&mut sof).is_ok() {
                            let height = u16::from_be_bytes([sof[1], sof[2]]) as u32;
                            let width = u16::from_be_bytes([sof[3], sof[4]]) as u32;
                            return (width, height);
                        }
                        break;
                    }
                    let _ = file.seek(SeekFrom::Current((length - 2) as i64));
                } else {
                    break;
                }
            }
        }
    }

    (0, 0)
}

// ============================================================
// THUMBNAILS & PROXIES
// ============================================================

pub fn ensure_thumbnail(path: &Path, kind: &str) -> PathBuf {
    let Some(name) = path.file_name() else {
        return path.to_path_buf();
    };

    let cache_dir = thumb_cache_dir();
    let name_str = name.to_string_lossy();
    let thumbnail = cache_dir.join(format!("{}.jpg", name_str));

    if thumbnail.exists() {
        return thumbnail;
    }

    // Check alternate name (e.g. dot vs underscore: a-galaxy-within.3840x2160 vs a-galaxy-within_3840x2160)
    let alt_name = if name_str.contains('_') {
        name_str.replace('_', ".")
    } else {
        name_str.replace('.', "_")
    };
    let alt_thumbnail = cache_dir.join(format!("{}.jpg", alt_name));
    if alt_thumbnail.exists() {
        return alt_thumbnail;
    }

    let _ = fs::create_dir_all(&cache_dir);

    // Non-blocking asynchronous thumbnail extraction so scanning is instantaneous
    let p = path.to_path_buf();
    let t = thumbnail.clone();
    if kind == "video" || kind == "gif" {
        let _ = Command::new("ffmpeg")
            .args(["-loglevel", "error", "-ss", "1", "-i"])
            .arg(&p)
            .args(["-frames:v", "1", "-vf", "scale=640:-2", "-q:v", "3", "-y"])
            .arg(&t)
            .spawn();
    } else {
        let _ = Command::new("ffmpeg")
            .args(["-loglevel", "error", "-i"])
            .arg(&p)
            .args(["-vf", "scale=640:-2", "-q:v", "3", "-y"])
            .arg(&t)
            .spawn();
    }

    thumbnail
}

pub fn ensure_proxy(path: &Path, kind: &str) -> Option<PathBuf> {
    if kind != "video" {
        return None;
    }

    let name = path.file_name()?;
    let cache_dir = proxy_cache_dir();
    let _ = fs::create_dir_all(&cache_dir);

    let name_str = name.to_string_lossy();
    let proxy = cache_dir.join(format!("{}.mp4", name_str));
    if proxy.exists() {
        return Some(proxy);
    }

    let alt_name = if name_str.contains('_') {
        name_str.replace('_', ".")
    } else {
        name_str.replace('.', "_")
    };
    let alt_proxy = cache_dir.join(format!("{}.mp4", alt_name));
    if alt_proxy.exists() {
        return Some(alt_proxy);
    }

    let p = proxy.clone();
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
        .arg(&p)
        .spawn();

    Some(path.to_path_buf())
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

        let ext = path
            .extension()
            .map(|e| e.to_string_lossy().to_string())
            .unwrap_or_default();

        let metadata = fs::metadata(&path).ok();
        let size_bytes = metadata.as_ref().map(|m| m.len()).unwrap_or(0);
        let formatted_size = format_size(size_bytes);

        let (mut width, mut height) = if kind == "image" || kind == "gif" {
            probe_image_dimensions(&path)
        } else {
            (0, 0)
        };

        if width == 0 || height == 0 {
            let name_lower = name.to_lowercase();
            if name_lower.contains("3840x2160") || name_lower.contains("4k") {
                width = 3840;
                height = 2160;
            } else if name_lower.contains("2560x1440") || name_lower.contains("2k") {
                width = 2560;
                height = 1440;
            } else if name_lower.contains("1920x1080") || name_lower.contains("1080p") {
                width = 1920;
                height = 1080;
            } else {
                width = 1920;
                height = 1080;
            }
        }

        let aspect_ratio = if height > 0 {
            (width as f32) / (height as f32)
        } else {
            1.777
        };

        temp.push((kind, path, name, ext, size_bytes, formatted_size, width, height, aspect_ratio));
    }

    temp.sort_by(|a, b| a.2.to_lowercase().cmp(&b.2.to_lowercase()));

    for (id, (kind, path, name, ext, size_bytes, formatted_size, width, height, aspect_ratio)) in
        temp.into_iter().enumerate()
    {
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
            width,
            height,
            aspect_ratio,
            size_bytes,
            formatted_size,
            extension: ext,
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
