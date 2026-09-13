use serde::{Deserialize, Serialize};
use std::{
    env, fs,
    io::Write,
    path::{Path, PathBuf},
    process::{Command, Stdio},
    time::{SystemTime, UNIX_EPOCH},
};

// ============================================================
// DATA MODELS
// ============================================================

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ShelfItem {
    pub id: String,
    pub uri: String,
    pub path: String,
    pub name: String,
    pub mime_type: String,
    pub category: String, // "image", "video", "audio", "document", "archive", "code", "file"
    #[serde(default = "default_icon_name")]
    pub icon_name: String, // e.g. "text-x-python", "folder", "video-x-generic" from gio info
    pub size_bytes: u64,
    pub exists: bool,
    pub thumbnail: Option<String>,
}

#[derive(Debug, Default, Clone, Serialize, Deserialize)]
pub struct ShelfState {
    pub items: Vec<ShelfItem>,
}

fn default_icon_name() -> String {
    "text-x-generic".to_string()
}

// ============================================================
// PATHS & STORAGE
// ============================================================

fn config_dir() -> PathBuf {
    let home = env::var("HOME").unwrap_or_else(|_| ".".to_string());
    PathBuf::from(home).join(".config").join("nexa").join("config")
}

fn shelf_path() -> PathBuf {
    config_dir().join("shelf.json")
}

fn quickshell_dir() -> PathBuf {
    let home = env::var("HOME").unwrap_or_else(|_| ".".to_string());
    PathBuf::from(home).join(".config").join("nexa").join("quickshell")
}

// ============================================================
// LOAD & SAVE
// ============================================================

pub fn load_shelf() -> ShelfState {
    let path = shelf_path();
    if let Ok(content) = fs::read_to_string(&path) {
        if let Ok(state) = serde_json::from_str::<ShelfState>(&content) {
            return state;
        }
    }
    ShelfState::default()
}

pub fn save_shelf(state: &ShelfState) -> Result<(), String> {
    let dir = config_dir();
    if !dir.exists() {
        fs::create_dir_all(&dir).map_err(|e| format!("Failed to create config dir: {e}"))?;
    }

    let json = serde_json::to_string_pretty(state)
        .map_err(|e| format!("Failed to serialize shelf state: {e}"))?;

    fs::write(shelf_path(), json)
        .map_err(|e| format!("Failed to write shelf state: {e}"))
}

// ============================================================
// URI & PATH HELPERS
// ============================================================

fn decode_percent(input: &str) -> String {
    let mut bytes = Vec::new();
    let mut chars = input.bytes();

    while let Some(b) = chars.next() {
        if b == b'%' {
            let h1 = chars.next();
            let h2 = chars.next();
            if let (Some(c1), Some(c2)) = (h1, h2) {
                let hex_str = [c1, c2];
                if let Ok(s) = std::str::from_utf8(&hex_str) {
                    if let Ok(val) = u8::from_str_radix(s, 16) {
                        bytes.push(val);
                        continue;
                    }
                }
                bytes.push(b'%');
                bytes.push(c1);
                bytes.push(c2);
            } else {
                bytes.push(b'%');
            }
        } else {
            bytes.push(b);
        }
    }

    String::from_utf8_lossy(&bytes).to_string()
}

pub fn parse_input_to_path_and_uri(input: &str) -> (String, String) {
    let trimmed = input.trim();
    if trimmed.starts_with("file://") {
        let raw_path = &trimmed["file://".len()..];
        let decoded = decode_percent(raw_path);
        (decoded, trimmed.to_string())
    } else {
        let abs_path = if trimmed.starts_with('~') {
            let home = env::var("HOME").unwrap_or_else(|_| "".to_string());
            trimmed.replacen('~', &home, 1)
        } else if trimmed.starts_with('/') {
            trimmed.to_string()
        } else {
            let current = env::current_dir().unwrap_or_default();
            current.join(trimmed).to_string_lossy().to_string()
        };
        let uri = format!("file://{abs_path}");
        (abs_path, uri)
    }
}

// ============================================================
// MIME & CATEGORY DETECTION
// ============================================================

fn detect_mime_and_category(path: &Path) -> (String, String) {
    let ext = path
        .extension()
        .and_then(|e| e.to_str())
        .unwrap_or("")
        .to_lowercase();

    match ext.as_str() {
        "jpg" | "jpeg" => ("image/jpeg".to_string(), "image".to_string()),
        "png" => ("image/png".to_string(), "image".to_string()),
        "webp" => ("image/webp".to_string(), "image".to_string()),
        "gif" => ("image/gif".to_string(), "image".to_string()),
        "svg" => ("image/svg+xml".to_string(), "image".to_string()),
        "bmp" => ("image/bmp".to_string(), "image".to_string()),
        "ico" => ("image/x-icon".to_string(), "image".to_string()),

        "mp4" => ("video/mp4".to_string(), "video".to_string()),
        "mkv" => ("video/x-matroska".to_string(), "video".to_string()),
        "webm" => ("video/webm".to_string(), "video".to_string()),
        "avi" => ("video/x-msvideo".to_string(), "video".to_string()),
        "mov" => ("video/quicktime".to_string(), "video".to_string()),

        "mp3" => ("audio/mpeg".to_string(), "audio".to_string()),
        "flac" => ("audio/flac".to_string(), "audio".to_string()),
        "wav" => ("audio/wav".to_string(), "audio".to_string()),
        "ogg" => ("audio/ogg".to_string(), "audio".to_string()),
        "m4a" => ("audio/mp4".to_string(), "audio".to_string()),

        "pdf" => ("application/pdf".to_string(), "document".to_string()),
        "doc" | "docx" => ("application/msword".to_string(), "document".to_string()),
        "xls" | "xlsx" => ("application/vnd.ms-excel".to_string(), "document".to_string()),
        "ppt" | "pptx" => ("application/vnd.ms-powerpoint".to_string(), "document".to_string()),
        "txt" => ("text/plain".to_string(), "document".to_string()),
        "md" => ("text/markdown".to_string(), "document".to_string()),

        "zip" => ("application/zip".to_string(), "archive".to_string()),
        "tar" => ("application/x-tar".to_string(), "archive".to_string()),
        "gz" => ("application/gzip".to_string(), "archive".to_string()),
        "7z" => ("application/x-7z-compressed".to_string(), "archive".to_string()),
        "rar" => ("application/vnd.rar".to_string(), "archive".to_string()),
        "bz2" | "xz" => ("application/x-compressed".to_string(), "archive".to_string()),

        "rs" | "py" | "js" | "ts" | "qml" | "c" | "cpp" | "h" | "html" | "css" | "json"
        | "toml" | "yaml" | "sh" => ("text/plain".to_string(), "code".to_string()),

        _ => ("application/octet-stream".to_string(), "file".to_string()),
    }
}

// ============================================================
// ICON RESOLUTION (GIO)
// ============================================================

/// Queries `gio info` for the themed icon name so QML can render
/// the real system icon rather than a hardcoded Nerd-Font glyph.
/// Falls back to a sensible default if gio is unavailable.
fn get_icon_name(path: &str) -> String {
    if let Ok(output) = Command::new("gio")
        .arg("info")
        .arg(path)
        .output()
    {
        let stdout = String::from_utf8_lossy(&output.stdout);
        for line in stdout.lines() {
            // Match the line that contains "standard::icon:" but not "symbolic-icon"
            if line.contains("standard::icon:") && !line.contains("symbolic-icon") {
                // The line looks like: "  standard::icon: text-plain, text-x-generic, ..."
                // Split on "standard::icon:" to get the values after it
                if let Some(after) = line.split("standard::icon:").nth(1) {
                    for icon in after.split(',') {
                        let icon = icon.trim();
                        // Skip: symbolic variants, empty strings, and long MIME-style
                        // names (e.g. "application-vnd.openxmlformats-...") that
                        // don't exist as actual icon files in common themes.
                        if icon.is_empty()
                            || icon.contains("symbolic")
                            || icon.contains('.')   // MIME-type names have dots
                            || icon.len() > 40      // real icon names are short
                        {
                            continue;
                        }
                        return icon.to_string();
                    }
                }
            }
        }
    }
    "text-x-generic".to_string()
}

// ============================================================
// CORE SHELF OPERATIONS
// ============================================================

/// Build a single ShelfItem from a path/URI string — does NOT touch shelf.json.
fn build_shelf_item(input: &str) -> ShelfItem {
    let (path_str, uri_str) = parse_input_to_path_and_uri(input);
    let path = PathBuf::from(&path_str);

    let exists = path.exists();
    let size_bytes = if exists {
        fs::metadata(&path).map(|m| m.len()).unwrap_or(0)
    } else {
        0
    };

    let name = path
        .file_name()
        .map(|n| n.to_string_lossy().to_string())
        .unwrap_or_else(|| path_str.clone());

    let (mime_type, category) = detect_mime_and_category(&path);

    let icon_name = if exists {
        get_icon_name(&path_str)
    } else {
        "text-x-generic".to_string()
    };

    let thumbnail = if category == "image" && exists {
        Some(uri_str.clone())
    } else {
        None
    };

    let id = format!(
        "{:016x}",
        SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap_or_default()
            .as_nanos()
    );

    ShelfItem {
        id,
        uri: uri_str,
        path: path_str,
        name,
        mime_type,
        category,
        icon_name,
        size_bytes,
        exists,
        thumbnail,
    }
}

/// Add ONE OR MORE files atomically — loads shelf.json once, appends all, saves once.
/// This eliminates the concurrent-write race when dropping multiple files at once.
pub fn add_many(inputs: &[&str]) -> Result<Vec<ShelfItem>, String> {
    // Build all items first (gio info calls happen outside the critical section)
    let new_items: Vec<ShelfItem> = inputs.iter().map(|s| build_shelf_item(s)).collect();

    // Load once, apply all changes, save once
    let mut state = load_shelf();
    let mut added: Vec<ShelfItem> = Vec::new();

    for item in new_items {
        // Deduplicate by URI
        state.items.retain(|existing| existing.uri != item.uri);
        state.items.insert(0, item.clone());
        added.push(item);
    }

    save_shelf(&state)?;
    Ok(added)
}

/// Convenience wrapper — add a single file.
#[allow(dead_code)]
pub fn add(input: &str) -> Result<ShelfItem, String> {
    add_many(&[input])
        .map(|mut v| v.remove(0))
}

pub fn remove(id: &str) -> Result<(), String> {
    let mut state = load_shelf();
    let initial_len = state.items.len();
    state.items.retain(|item| item.id != id);

    if state.items.len() != initial_len {
        save_shelf(&state)?;
    }
    Ok(())
}

pub fn clear() -> Result<(), String> {
    let state = ShelfState { items: Vec::new() };
    save_shelf(&state)
}

pub fn list() -> Vec<ShelfItem> {
    let mut state = load_shelf();
    let mut updated = false;

    // Fast validation: update exists flag for items
    for item in &mut state.items {
        let current_exists = Path::new(&item.path).exists();
        if item.exists != current_exists {
            item.exists = current_exists;
            updated = true;
        }
    }

    if updated {
        let _ = save_shelf(&state);
    }

    state.items
}

pub fn copy_all() -> Result<String, String> {
    let state = load_shelf();
    let valid_items: Vec<_> = state.items.iter().filter(|i| i.exists).collect();

    if valid_items.is_empty() {
        return Err("Shelf is empty or items no longer exist".to_string());
    }

    // Standard Wayland file clipboard format: text/uri-list
    let mut uri_list = valid_items
        .iter()
        .map(|i| i.uri.as_str())
        .collect::<Vec<_>>()
        .join("\r\n");
    uri_list.push_str("\r\n");

    // Copy to Wayland clipboard using wl-copy via stdin
    if let Ok(mut child) = Command::new("wl-copy")
        .arg("-t")
        .arg("text/uri-list")
        .stdin(Stdio::piped())
        .spawn()
    {
        if let Some(mut stdin) = child.stdin.take() {
            let _ = stdin.write_all(uri_list.as_bytes());
        }
        let _ = child.wait();
    }

    Ok(format!("Copied {} file(s) to clipboard", valid_items.len()))
}

pub fn copy_item(id: &str) -> Result<String, String> {
    let state = load_shelf();
    let item = state
        .items
        .iter()
        .find(|i| i.id == id)
        .ok_or_else(|| "Item not found".to_string())?;

    if !item.exists {
        return Err("File no longer exists".to_string());
    }

    let uri_data = format!("{}\r\n", item.uri);

    // Copy as file reference (text/uri-list) so file managers paste the actual file
    if let Ok(mut child) = Command::new("wl-copy")
        .arg("-t")
        .arg("text/uri-list")
        .stdin(Stdio::piped())
        .spawn()
    {
        if let Some(mut stdin) = child.stdin.take() {
            let _ = stdin.write_all(uri_data.as_bytes());
        }
        let _ = child.wait();
    }

    Ok(format!("Copied {} to clipboard", item.name))
}

// ============================================================
// QUICKSHELL IPC TRIGGER
// ============================================================

pub fn call_quickshell(action: &str) -> Result<(), String> {
    let config_path = quickshell_dir();

    let status = Command::new("qs")
        .arg("-p")
        .arg(&config_path)
        .args(["ipc", "call", "fileShelf", action])
        .status()
        .map_err(|e| format!("Failed to call qs ipc: {e}"))?;

    if !status.success() {
        return Err(format!("qs ipc call failed with status: {status}"));
    }

    Ok(())
}

