use serde::{Deserialize, Serialize};
use std::{
    collections::{HashMap, HashSet},
    env, fs,
    io::{Read, Seek, SeekFrom},
    path::{Path, PathBuf},
    process::Command,
    sync::{
        mpsc::{channel, Receiver, Sender},
        Arc, Mutex, OnceLock,
    },
    thread,
    time::SystemTime,
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
// SINGLE-WORKER QUEUE (Concurrency = 1, Never Fork Bomb)
// ============================================================

#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub enum WallpaperTask {
    Thumbnail { path: PathBuf, target: PathBuf, is_video: bool },
    Proxy { path: PathBuf, target: PathBuf },
}

struct WorkerQueue {
    sender: Sender<WallpaperTask>,
    enqueued: Arc<Mutex<HashSet<PathBuf>>>,
}

static WORKER: OnceLock<WorkerQueue> = OnceLock::new();

fn get_worker() -> &'static WorkerQueue {
    WORKER.get_or_init(|| {
        let (sender, receiver) = channel::<WallpaperTask>();
        let enqueued = Arc::new(Mutex::new(HashSet::new()));
        let enqueued_clone = Arc::clone(&enqueued);

        let _ = thread::Builder::new()
            .name("nexa-wall-worker".into())
            .spawn(move || {
                worker_loop(receiver, enqueued_clone);
            });

        WorkerQueue { sender, enqueued }
    })
}

fn worker_loop(receiver: Receiver<WallpaperTask>, enqueued: Arc<Mutex<HashSet<PathBuf>>>) {
    while let Ok(task) = receiver.recv() {
        match task {
            WallpaperTask::Proxy { path, target } => {
                if !target.exists() {
                    encode_proxy_single(&path, &target);
                }
                if let Ok(mut set) = enqueued.lock() {
                    set.remove(&target);
                }
            }
            WallpaperTask::Thumbnail { path, target, is_video } => {
                if !target.exists() {
                    encode_thumbnail_single(&path, &target, is_video);
                }
                if let Ok(mut set) = enqueued.lock() {
                    set.remove(&target);
                }
            }
        }
    }
}

fn encode_proxy_single(input_path: &Path, target: &Path) {
    let vaapi_available = Path::new("/dev/dri/renderD128").exists();
    let mut success = false;

    if vaapi_available {
        let status = Command::new("nice")
            .args([
                "-n", "19",
                "ffmpeg",
                "-init_hw_device", "vaapi=gpu:/dev/dri/renderD128",
                "-hwaccel", "vaapi",
                "-hwaccel_device", "gpu",
                "-loglevel", "error",
                "-ss", "0.0",
                "-i",
            ])
            .arg(input_path)
            .args([
                "-vf", "format=nv12,hwupload,scale_vaapi=w=-2:h=480",
                "-c:v", "h264_vaapi",
                "-qp", "24",
                "-an",
                "-t", "15",
                "-y",
            ])
            .arg(target)
            .status();

        if let Ok(s) = status {
            if s.success() {
                success = true;
            }
        }
    }

    if !success {
        let _ = Command::new("nice")
            .args([
                "-n", "19",
                "ffmpeg",
                "-loglevel", "error",
                "-threads", "1",
                "-ss", "0.0",
                "-i",
            ])
            .arg(input_path)
            .args([
                "-vf", "scale=-2:480,fps=30",
                "-c:v", "libx264",
                "-preset", "veryfast",
                "-crf", "24",
                "-pix_fmt", "yuv420p",
                "-an",
                "-t", "15",
                "-y",
            ])
            .arg(target)
            .status();
    }
}

fn encode_thumbnail_single(input_path: &Path, target: &Path, is_video: bool) {
    if is_video {
        let _ = Command::new("nice")
            .args(["-n", "19", "ffmpeg", "-loglevel", "error", "-threads", "1", "-ss", "00:00:01", "-i"])
            .arg(input_path)
            .args(["-frames:v", "1", "-vf", "scale=640:-2", "-q:v", "3", "-y"])
            .arg(target)
            .status();
    } else {
        let _ = Command::new("nice")
            .args(["-n", "19", "ffmpeg", "-loglevel", "error", "-threads", "1", "-i"])
            .arg(input_path)
            .args(["-vf", "scale=640:-2", "-q:v", "3", "-y"])
            .arg(target)
            .status();
    }
}

// ============================================================
// THUMBNAILS & PROXIES (Safe, Non-Blocking, Never Spawns in Loops)
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

    let alt_name = if name_str.contains('_') {
        name_str.replace('_', ".")
    } else {
        name_str.replace('.', "_")
    };
    let alt_thumbnail = cache_dir.join(format!("{}.jpg", alt_name));
    if alt_thumbnail.exists() {
        return alt_thumbnail;
    }

    // For normal wallpapers, static images load directly without needing ffmpeg thumbnails
    let is_slideshow = path.to_string_lossy().contains("/Slideshow");
    if kind == "image" && !is_slideshow {
        return path.to_path_buf();
    }

    let _ = fs::create_dir_all(&cache_dir);

    // Enqueue single background worker task without blocking or fork bombing
    let worker = get_worker();
    if let Ok(mut set) = worker.enqueued.lock() {
        if set.insert(thumbnail.clone()) {
            let _ = worker.sender.send(WallpaperTask::Thumbnail {
                path: path.to_path_buf(),
                target: thumbnail.clone(),
                is_video: kind == "video" || kind == "gif",
            });
        }
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

    let _ = fs::create_dir_all(&cache_dir);

    // Enqueue single background worker task without blocking or fork bombing
    let worker = get_worker();
    if let Ok(mut set) = worker.enqueued.lock() {
        if set.insert(proxy.clone()) {
            let _ = worker.sender.send(WallpaperTask::Proxy {
                path: path.to_path_buf(),
                target: proxy,
            });
        }
    }

    // Return original video path so the UI can preview immediately without waiting
    Some(path.to_path_buf())
}

// ============================================================
// SCANNING (Cached by Directory mtime)
// ============================================================

static SCAN_CACHE: OnceLock<Mutex<HashMap<PathBuf, (SystemTime, Vec<WallpaperEntry>)>>> = OnceLock::new();

fn get_scan_cache() -> &'static Mutex<HashMap<PathBuf, (SystemTime, Vec<WallpaperEntry>)>> {
    SCAN_CACHE.get_or_init(|| Mutex::new(HashMap::new()))
}

pub fn scan_entries(custom_dir: Option<&Path>) -> Vec<WallpaperEntry> {
    let default_dir = wallpaper_dir();
    let directory = custom_dir.unwrap_or(&default_dir);
    let mut wallpapers = Vec::new();

    // Fast-path: Check directory modification timestamp
    let dir_mtime = fs::metadata(directory).and_then(|m| m.modified()).ok();
    if let Some(mtime) = dir_mtime {
        if let Ok(cache) = get_scan_cache().lock() {
            if let Some((cached_mtime, cached_entries)) = cache.get(directory) {
                if *cached_mtime == mtime {
                    return cached_entries.clone();
                }
            }
        }
    }

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

    if let Some(mtime) = dir_mtime {
        if let Ok(mut cache) = get_scan_cache().lock() {
            cache.insert(directory.to_path_buf(), (mtime, wallpapers.clone()));
        }
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
    if let Ok(mut cache) = get_scan_cache().lock() {
        cache.clear();
    }
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

    let worker = get_worker();
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
            // Only videos and gifs need thumbnail frame extraction; images are natively handled by Qt
            if kind == "video" || kind == "gif" {
                if let Ok(mut set) = worker.enqueued.lock() {
                    if set.insert(target.clone()) {
                        let _ = worker.sender.send(WallpaperTask::Thumbnail {
                            path,
                            target,
                            is_video: true,
                        });
                    }
                }
            }
        }
    }
    Ok(())
}
