use super::types::PaletteColors;
use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::{
    path::{Path, PathBuf},
    process::Command,
    time::Duration,
};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MediaPalette {
    pub primary: String,
    pub surface: String,
    pub border: String,
    pub container: String,
    pub secondary: String,
    pub tertiary: String,
    pub on_primary: String,
    pub on_surface: String,
}

impl Default for MediaPalette {
    fn default() -> Self {
        Self {
            primary: String::from("#81D3DE"),
            surface: String::from("#0E1415"),
            border: String::from("#434751"),
            container: String::from("#1C2029"),
            secondary: String::from("#B1CBCF"),
            tertiary: String::from("#B8C6EA"),
            on_primary: String::from("#002E69"),
            on_surface: String::from("#DFE2EF"),
        }
    }
}

pub fn extract_palette(path: &Path) -> PaletteColors {
    let mut colors = PaletteColors::default();
    let scheme = get_scheme_type();

    let output = Command::new("matugen")
        .arg("image")
        .arg(path)
        .arg("-t")
        .arg(&scheme)
        .arg("--source-color-index")
        .arg("0")
        .arg("--dry-run")
        .arg("--json")
        .arg("hex")
        .output();

    let Ok(output) = output else {
        return colors;
    };

    if !output.status.success() {
        return colors;
    }

    let Ok(text) = std::str::from_utf8(&output.stdout) else {
        return colors;
    };

    let Ok(json): Result<Value, _> = serde_json::from_str(text) else {
        return colors;
    };

    let Some(c) = json.get("colors") else {
        return colors;
    };

    if let Some(val) = extract_color_str(c, "primary") {
        colors.primary = val;
    }
    if let Some(val) = extract_color_str(c, "secondary") {
        colors.secondary = val;
    }
    if let Some(val) = extract_color_str(c, "tertiary") {
        colors.tertiary = val;
    }
    if let Some(val) = extract_color_str(c, "surface_container") {
        colors.container = val;
    }
    if let Some(val) = extract_color_str(c, "surface") {
        colors.surface = val;
    }

    colors
}

fn extract_color_str(colors: &Value, name: &str) -> Option<String> {
    let role = colors.get(name)?;

    // Check role.default.color
    if let Some(c) = role
        .get("default")
        .and_then(|d| d.get("color"))
        .and_then(|v| v.as_str())
    {
        return Some(c.to_uppercase());
    }

    // Check role.dark.color
    if let Some(c) = role
        .get("dark")
        .and_then(|d| d.get("color"))
        .and_then(|v| v.as_str())
    {
        return Some(c.to_uppercase());
    }

    // Direct string
    if let Some(c) = role.as_str() {
        return Some(c.to_uppercase());
    }

    None
}

fn extract_role_color(colors: &Value, name: &str, is_dark: bool) -> Option<String> {
    let role = colors.get(name)?;

    let target_mode = if is_dark { "dark" } else { "light" };
    if let Some(c) = role
        .get(target_mode)
        .and_then(|d| d.get("color"))
        .and_then(|v| v.as_str())
    {
        return Some(c.to_uppercase());
    }

    if let Some(c) = role
        .get("default")
        .and_then(|d| d.get("color"))
        .and_then(|v| v.as_str())
    {
        return Some(c.to_uppercase());
    }

    if let Some(c) = role
        .get(if is_dark { "light" } else { "dark" })
        .and_then(|d| d.get("color"))
        .and_then(|v| v.as_str())
    {
        return Some(c.to_uppercase());
    }

    if let Some(c) = role.as_str() {
        return Some(c.to_uppercase());
    }

    None
}

fn get_scheme_type() -> String {
    if let Ok(home) = std::env::var("HOME") {
        let conf_path = Path::new(&home).join(".config/nexa/config/theme.conf");
        if let Ok(content) = std::fs::read_to_string(conf_path) {
            for line in content.lines() {
                let trimmed = line.trim();
                if let Some(val) = trimmed.strip_prefix("SCHEME_TYPE=") {
                    let cleaned = val.trim().trim_matches('"').trim_matches('\'');
                    if !cleaned.is_empty() {
                        return cleaned.to_string();
                    }
                }
            }
        }
    }
    "scheme-vibrant".to_string()
}

fn get_theme_mode() -> String {
    if let Ok(home) = std::env::var("HOME") {
        let conf_path = Path::new(&home).join(".config/nexa/config/theme.conf");
        if let Ok(content) = std::fs::read_to_string(conf_path) {
            for line in content.lines() {
                let trimmed = line.trim();
                if let Some(val) = trimmed.strip_prefix("MODE=") {
                    let cleaned = val.trim().trim_matches('"').trim_matches('\'');
                    if !cleaned.is_empty() {
                        return cleaned.to_lowercase();
                    }
                }
            }
        }
    }
    "dark".to_string()
}

// ============================================================
// DYNAMIC MEDIA MATUGEN EXTRACTION
// ============================================================

pub fn resolve_media_image(input: &str) -> Option<PathBuf> {
    let clean = input.trim();
    if clean.is_empty() {
        return None;
    }

    let local = if let Some(stripped) = clean.strip_prefix("file://") {
        stripped
    } else {
        clean
    };

    if local.starts_with("http://") || local.starts_with("https://") {
        let md5_str = match openssl::hash::hash(openssl::hash::MessageDigest::md5(), local.as_bytes()) {
            Ok(b) => hex::encode(b),
            Err(_) => {
                let mut sum: u64 = 0;
                for b in local.bytes() {
                    sum = sum.wrapping_mul(31).wrapping_add(b as u64);
                }
                format!("{sum:x}")
            }
        };

        let cache_dir = if let Ok(home) = std::env::var("HOME") {
            PathBuf::from(home).join(".cache/nexa/covers")
        } else {
            PathBuf::from("/tmp")
        };
        let _ = std::fs::create_dir_all(&cache_dir);
        let target = cache_dir.join(format!("matugen_{md5_str}.jpg"));

        if target.exists() {
            if let Ok(meta) = std::fs::metadata(&target) {
                if meta.len() > 500 {
                    return Some(target);
                }
            }
        }

        // Download via reqwest with timeout, with curl fallback
        let client = reqwest::blocking::Client::builder()
            .timeout(Duration::from_millis(3000))
            .user_agent("Mozilla/5.0")
            .build();

        let mut downloaded = false;
        if let Ok(c) = client {
            if let Ok(resp) = c.get(local).send() {
                if resp.status().is_success() {
                    if let Ok(bytes) = resp.bytes() {
                        if bytes.len() > 500 {
                            if std::fs::write(&target, &bytes).is_ok() {
                                downloaded = true;
                            }
                        }
                    }
                }
            }
        }

        if !downloaded {
            let status = Command::new("curl")
                .args(["-s", "-L", "--max-time", "3", local, "-o", &target.to_string_lossy()])
                .status();
            if let Ok(s) = status {
                if s.success() && target.exists() {
                    if let Ok(meta) = std::fs::metadata(&target) {
                        if meta.len() > 500 {
                            downloaded = true;
                        }
                    }
                }
            }
        }

        if downloaded {
            return Some(target);
        } else {
            return None;
        }
    }

    let p = PathBuf::from(local);
    if p.exists() {
        Some(p)
    } else {
        None
    }
}

pub fn extract_media_palette(input: &str) -> Result<MediaPalette, String> {
    let clean = input.trim();
    if clean.is_empty() {
        return Err("Empty media input".to_string());
    }

    let image_path = resolve_media_image(clean)
        .ok_or_else(|| format!("Could not resolve image from input: {clean}"))?;

    // Create a robust cache key incorporating file modification time and size
    // to handle browsers (like Chrome/Firefox) that reuse the exact same temp file name
    let hash_source = if let Ok(meta) = std::fs::metadata(&image_path) {
        let mtime = meta
            .modified()
            .ok()
            .and_then(|t| t.duration_since(std::time::UNIX_EPOCH).ok())
            .map(|d| d.as_secs())
            .unwrap_or(0);
        format!("{}_{}_{}", image_path.to_string_lossy(), meta.len(), mtime)
    } else {
        clean.to_string()
    };

    let hash_key = match openssl::hash::hash(openssl::hash::MessageDigest::md5(), hash_source.as_bytes()) {
        Ok(b) => hex::encode(b),
        Err(_) => format!("{:x}", hash_source.len()),
    };

    let cache_dir = if let Ok(home) = std::env::var("HOME") {
        PathBuf::from(home).join(".cache/nexa/covers")
    } else {
        PathBuf::from("/tmp")
    };
    let pal_cache_file = cache_dir.join(format!("palette_{hash_key}.json"));

    if pal_cache_file.exists() {
        if let Ok(cached_json) = std::fs::read_to_string(&pal_cache_file) {
            if let Ok(cached_pal) = serde_json::from_str::<MediaPalette>(&cached_json) {
                return Ok(cached_pal);
            }
        }
    }

    let is_dark = get_theme_mode() == "dark";
    let scheme = get_scheme_type();

    let output = Command::new("matugen")
        .arg("image")
        .arg(&image_path)
        .arg("-t")
        .arg(&scheme)
        .arg("--source-color-index")
        .arg("0")
        .arg("--dry-run")
        .arg("--json")
        .arg("hex")
        .output()
        .map_err(|e| format!("Failed to run matugen: {e}"))?;

    if !output.status.success() {
        return Err("Matugen process failed".to_string());
    }

    let text = std::str::from_utf8(&output.stdout)
        .map_err(|e| format!("Invalid UTF-8 from matugen: {e}"))?;

    let json: Value = serde_json::from_str(text)
        .map_err(|e| format!("Failed to parse matugen json: {e}"))?;

    let colors = json
        .get("colors")
        .ok_or_else(|| "Missing 'colors' key in matugen output".to_string())?;

    let def = MediaPalette::default();
    let pal = MediaPalette {
        primary: extract_role_color(colors, "primary", is_dark).unwrap_or(def.primary),
        surface: extract_role_color(colors, "surface", is_dark).unwrap_or(def.surface),
        border: extract_role_color(colors, "outline_variant", is_dark)
            .or_else(|| extract_role_color(colors, "outline", is_dark))
            .unwrap_or(def.border),
        container: extract_role_color(colors, "surface_container", is_dark)
            .or_else(|| extract_role_color(colors, "surface_container_high", is_dark))
            .unwrap_or(def.container),
        secondary: extract_role_color(colors, "secondary", is_dark).unwrap_or(def.secondary),
        tertiary: extract_role_color(colors, "tertiary", is_dark).unwrap_or(def.tertiary),
        on_primary: extract_role_color(colors, "on_primary", is_dark).unwrap_or(def.on_primary),
        on_surface: extract_role_color(colors, "on_surface", is_dark).unwrap_or(def.on_surface),
    };

    // Save to palette cache file
    if let Ok(pal_json) = serde_json::to_string(&pal) {
        let _ = std::fs::create_dir_all(&cache_dir);
        let _ = std::fs::write(&pal_cache_file, pal_json);
    }

    Ok(pal)
}

pub fn run_media_matugen(input: &str) {
    match extract_media_palette(input) {
        Ok(pal) => {
            if let Ok(json) = serde_json::to_string(&pal) {
                // Also write to active theme cache for reactive watchers
                if let Ok(home) = std::env::var("HOME") {
                    let theme_dir = PathBuf::from(home).join(".cache/nexa/theme");
                    let _ = std::fs::create_dir_all(&theme_dir);
                    let _ = std::fs::write(theme_dir.join("media_palette.json"), &json);
                }
                println!("{json}");
            } else {
                println!("{{}}");
            }
        }
        Err(_) => {
            println!("{{}}");
        }
    }
}
