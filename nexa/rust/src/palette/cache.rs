use std::{
    env,
    fs,
    path::{Path, PathBuf},
};
use openssl::hash::{hash, MessageDigest};
use super::types::WallpaperInfo;

fn cache_dir() -> PathBuf {
    let home = env::var("HOME").unwrap_or_else(|_| String::from("."));
    PathBuf::from(home)
        .join(".cache")
        .join("nexa")
        .join("wallpapers")
        .join("info")
}

fn cache_path_for(path: &Path) -> Option<PathBuf> {
    let path_str = path.to_str()?;
    let digest = hash(MessageDigest::md5(), path_str.as_bytes()).ok()?;
    let hex_hash = hex::encode(digest);
    Some(cache_dir().join(format!("{}.json", hex_hash)))
}

pub fn load_cached(path: &Path) -> Option<WallpaperInfo> {
    let cache_file = cache_path_for(path)?;
    if !cache_file.exists() {
        return None;
    }

    let img_meta = fs::metadata(path).ok()?;
    let cache_meta = fs::metadata(&cache_file).ok()?;

    let img_mtime = img_meta.modified().ok()?;
    let cache_mtime = cache_meta.modified().ok()?;

    if cache_mtime < img_mtime {
        return None;
    }

    let content = fs::read_to_string(&cache_file).ok()?;
    serde_json::from_str(&content).ok()
}

pub fn save_cached(info: &WallpaperInfo) {
    let path = Path::new(&info.path);
    let Some(cache_file) = cache_path_for(path) else {
        return;
    };

    if let Some(parent) = cache_file.parent() {
        let _ = fs::create_dir_all(parent);
    }

    if let Ok(json) = serde_json::to_string(info) {
        let _ = fs::write(&cache_file, json);
    }
}
