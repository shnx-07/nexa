use std::{
    path::{Path, PathBuf},
    process::Command,
};
use super::list::{classify, thumb_cache_dir};

// =============================================================================
// SKWD-PAPER PREVIEW & FAST FRAME ENGINE
// =============================================================================
// Uses skwd-wall-still and skwd-paper-v2 to offload wallpaper previewing,
// frame capture, and GPU visual streaming from QML to compiled native binaries.
// =============================================================================

pub struct PreviewEngine;

impl PreviewEngine {
    /// Generates or resolves the cached thumbnail for a wallpaper
    pub fn get_or_render_thumbnail(path: &Path) -> PathBuf {
        let Some(name) = path.file_name() else {
            return path.to_path_buf();
        };

        let cache_dir = thumb_cache_dir();
        let target = cache_dir.join(format!("{}.jpg", name.to_string_lossy()));

        if target.exists() {
            return target;
        }

        let kind = classify(path).unwrap_or("image");

        // Prefer ffmpeg for standard thumbnail scaling, skwd-wall-still for instant frame capture
        if kind == "video" || kind == "gif" {
            let _ = Command::new("nice")
                .args(["-n", "19", "ffmpeg", "-loglevel", "error", "-threads", "1", "-ss", "1", "-i"])
                .arg(path)
                .args(["-frames:v", "1", "-vf", "scale=640:-2", "-q:v", "3", "-y"])
                .arg(&target)
                .status();
        } else {
            let _ = Command::new("nice")
                .args(["-n", "19", "ffmpeg", "-loglevel", "error", "-threads", "1", "-i"])
                .arg(path)
                .args(["-vf", "scale=640:-2", "-q:v", "3", "-y"])
                .arg(&target)
                .status();
        }

        if target.exists() {
            target
        } else {
            path.to_path_buf()
        }
    }

    /// Invokes skwd-wall-still to preview a wallpaper on an explicit Wayland output
    pub fn preview_output(output: &str, file: &Path) -> Result<(), String> {
        let status = Command::new("skwd-wall-still")
            .arg(output)
            .arg(file)
            .status()
            .map_err(|e| format!("Failed to spawn skwd-wall-still: {e}"))?;

        if status.success() {
            Ok(())
        } else {
            Err(format!("skwd-wall-still exited with status: {status}"))
        }
    }
}

