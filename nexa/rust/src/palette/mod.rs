pub mod cache;
pub mod matugen;
pub mod metadata;
pub mod types;

use std::path::Path;
pub use types::WallpaperInfo;

pub fn get_info(path: &Path) -> WallpaperInfo {
    // 1. Check cache first for instant response
    if let Some(cached) = cache::load_cached(path) {
        return cached;
    }

    // 2. Extract metadata
    let meta = metadata::extract_metadata(path);

    // 3. Extract palette via matugen
    let ext = path
        .extension()
        .and_then(|e| e.to_str())
        .unwrap_or("")
        .to_lowercase();
    let is_video = matches!(ext.as_str(), "mp4" | "mkv" | "mov" | "webm");

    let image_path = if is_video {
        crate::media_tools::wallpaper::ensure_thumbnail(path, "video")
    } else {
        path.to_path_buf()
    };

    let palette = matugen::extract_palette(&image_path);

    let info = WallpaperInfo {
        path: path.to_string_lossy().to_string(),
        format: meta.format,
        width: meta.width,
        height: meta.height,
        size: meta.size,
        palette,
    };

    // 4. Save to cache
    cache::save_cached(&info);

    info
}

pub fn print_info(path_str: &str) {
    let path = Path::new(path_str);
    let info = get_info(path);
    if let Ok(json) = serde_json::to_string(&info) {
        println!("{}", json);
    } else {
        eprintln!("{{\"error\":\"Failed to serialize wallpaper info\"}}");
    }
}
