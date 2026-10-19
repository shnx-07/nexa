use std::{
    fs,
    path::Path,
    process::Command,
};

pub struct FileMeta {
    pub format: String,
    pub width: u32,
    pub height: u32,
    pub size: String,
}

pub fn extract_metadata(path: &Path) -> FileMeta {
    let format = path
        .extension()
        .and_then(|ext| ext.to_str())
        .unwrap_or("")
        .to_uppercase();

    let bytes = fs::metadata(path).map(|m| m.len()).unwrap_or(0);
    let size = format_size(bytes);

    let (width, height) = extract_dimensions(path);

    FileMeta {
        format,
        width,
        height,
        size,
    }
}

fn format_size(bytes: u64) -> String {
    if bytes >= 1024 * 1024 {
        format!("{:.1} MB", (bytes as f64) / (1024.0 * 1024.0))
    } else if bytes >= 1024 {
        format!("{:.0} KB", (bytes as f64) / 1024.0)
    } else {
        format!("{} B", bytes)
    }
}

fn extract_dimensions(path: &Path) -> (u32, u32) {
    let output = Command::new("file")
        .arg("-b")
        .arg(path)
        .output();

    let Ok(output) = output else {
        return (0, 0);
    };

    let Ok(text) = std::str::from_utf8(&output.stdout) else {
        return (0, 0);
    };

    // Look for pattern like "2560x1440" or "2560 x 1440"
    for part in text.split(&[',', ';', ' '][..]) {
        let trimmed = part.trim();
        if let Some((w_str, h_str)) = trimmed.split_once('x') {
            if let (Ok(w), Ok(h)) = (w_str.parse::<u32>(), h_str.parse::<u32>()) {
                if w >= 100 && h >= 100 && w <= 32000 && h <= 32000 {
                    return (w, h);
                }
            }
        }
    }

    (0, 0)
}
