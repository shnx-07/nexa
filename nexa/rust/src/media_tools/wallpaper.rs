use std::{
    env, fs,
    path::{Path, PathBuf},
    process::Command,
};

// ============================================================
// WALLPAPER ENTRY
// ============================================================

#[derive(Debug)]
struct Wallpaper {
    kind: &'static str,
    path: PathBuf,
    name: String,
}

// ============================================================
// PATHS
// ============================================================

fn wallpaper_dir() -> PathBuf {
    let home = env::var("HOME").unwrap_or_else(|_| String::from("."));

    PathBuf::from(home).join("Pictures").join("Wallpapers")
}

// ------------------------------------------------------------
// Desktop wallpaper config
// ------------------------------------------------------------

fn desktop_config_path() -> PathBuf {
    let home = env::var("HOME").unwrap_or_else(|_| String::from("."));

    PathBuf::from(home)
        .join(".config")
        .join("nexa")
        .join("config")
        .join("wallpaper.conf")
}

// ------------------------------------------------------------
// Lock-screen wallpaper config
// ------------------------------------------------------------

fn lock_config_path() -> PathBuf {
    let home = env::var("HOME").unwrap_or_else(|_| String::from("."));

    PathBuf::from(home)
        .join(".config")
        .join("nexa")
        .join("config")
        .join("lockscreen.conf")
}

// ============================================================
// WALLPAPER TYPE
// ============================================================

fn classify(path: &Path) -> Option<&'static str> {
    let extension = path.extension()?.to_string_lossy().to_lowercase();

    match extension.as_str() {
        "png" | "jpg" | "jpeg" | "webp" => Some("image"),

        "gif" => Some("gif"),

        "mp4" | "mkv" | "mov" | "webm" => Some("video"),

        _ => None,
    }
}

// ============================================================
// SCAN WALLPAPER DIRECTORY
// ============================================================

fn scan(custom_dir: Option<&Path>) -> Vec<Wallpaper> {
    let default_dir = wallpaper_dir();
    let directory = custom_dir.unwrap_or(&default_dir);

    let mut wallpapers = Vec::new();

    let entries = match fs::read_dir(directory) {
        Ok(entries) => entries,

        Err(error) => {
            eprintln!(
                "Failed to read wallpaper directory {}: {}",
                directory.display(),
                error
            );

            return wallpapers;
        }
    };

    for entry in entries.flatten() {
        let path = entry.path();

        if !path.is_file() {
            continue;
        }

        let Some(kind) = classify(&path) else {
            continue;
        };

        // Ensure fast cached thumbnails for all wallpapers
        ensure_thumbnail(&path, kind);

        let name = path
            .file_name()
            .map(|name| name.to_string_lossy().to_string())
            .unwrap_or_default();

        wallpapers.push(Wallpaper { kind, path, name });
    }

    wallpapers.sort_by(|a, b| a.name.to_lowercase().cmp(&b.name.to_lowercase()));

    wallpapers
}

// ============================================================
// ============================================================
// PRINT WALLPAPER ENTRY
// ============================================================

fn print_wallpaper(wallpaper: &Wallpaper) {
    let thumb = ensure_thumbnail(&wallpaper.path, wallpaper.kind);
    let proxy = ensure_proxy(&wallpaper.path, wallpaper.kind);
    let proxy_str = proxy.map(|p| p.display().to_string()).unwrap_or_default();
    println!(
        "{}|{}|{}|{}",
        wallpaper.kind,
        wallpaper.path.display(),
        thumb.display(),
        proxy_str
    );
}

// ============================================================
// UNIVERSAL FAST THUMBNAILS & PROXIES
// ============================================================

fn proxy_cache_dir() -> PathBuf {
    let home = env::var("HOME").unwrap_or_else(|_| String::from("."));

    PathBuf::from(home)
        .join(".cache")
        .join("nexa")
        .join("wallpapers")
        .join("proxies")
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

    // Spawn non-blocking background generator so scan() never hangs
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

fn thumb_cache_dir() -> PathBuf {
    let home = env::var("HOME").unwrap_or_else(|_| String::from("."));

    PathBuf::from(home)
        .join(".cache")
        .join("nexa")
        .join("wallpapers")
        .join("thumbs")
}

pub fn ensure_thumbnail(path: &Path, kind: &str) -> PathBuf {
    let Some(name) = path.file_name() else {
        return path.to_path_buf();
    };

    let cache_dir = thumb_cache_dir();

    let _ = fs::create_dir_all(&cache_dir);

    let thumbnail = cache_dir.join(format!("{}.jpg", name.to_string_lossy()));

    // Already generated.
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

// ============================================================
// WALLPAPER LIST
// ============================================================

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

    for wallpaper in scan(custom_path.as_deref()) {
        print_wallpaper(&wallpaper);
    }
}

// ============================================================
// WALLPAPER SEARCH
// ============================================================

pub fn print_search(query: &str) {
    let query = query.trim().to_lowercase();

    for wallpaper in scan(None) {
        if query.is_empty() || wallpaper.name.to_lowercase().contains(&query) {
            print_wallpaper(&wallpaper);
        }
    }
}

// ============================================================
// WALLPAPER REFRESH
// ============================================================

pub fn refresh() {
    let wallpapers = scan(None);

    println!("indexed={}", wallpapers.len());
}

// ============================================================
// LOCK SCREEN WALLPAPER
// ============================================================
//
// Lock-screen wallpaper state is deliberately stored separately:
//
// ~/.config/nexa/config/lockscreen.conf
//
// Desktop wallpaper remains:
//
// ~/.config/nexa/config/wallpaper.conf
//
// This guarantees:
//
// Background
//     -> cannot overwrite lock wallpaper
//
// Lock Screen
//     -> cannot overwrite desktop wallpaper
//
// Both
//     -> QML explicitly updates both
//
// ============================================================

// ============================================================
// SET LOCK WALLPAPER
// ============================================================

pub fn set_lock(path: &str) -> Result<(), String> {
    let path = PathBuf::from(path);

    // --------------------------------------------------------
    // Validate file
    // --------------------------------------------------------

    if !path.is_file() {
        return Err(format!("Lock wallpaper does not exist: {}", path.display()));
    }

    // --------------------------------------------------------
    // Detect media type
    // --------------------------------------------------------

    let kind =
        classify(&path).ok_or_else(|| format!("Unsupported lock wallpaper: {}", path.display()))?;

    // --------------------------------------------------------
    // Config destination
    // --------------------------------------------------------

    let config = lock_config_path();

    if let Some(parent) = config.parent() {
        fs::create_dir_all(parent)
            .map_err(|error| format!("Failed to create lockscreen config directory: {}", error))?;
    }

    // --------------------------------------------------------
    // Save lock-screen state
    // --------------------------------------------------------

    // Ensure thumbnail is generated for video/gif so lockscreen preview is available
    if kind == "video" || kind == "gif" {
        let _ = ensure_thumbnail(&path, kind);
        if kind == "video" {
            let _ = ensure_proxy(&path, kind);
        }
    }

    let contents = format!(
        "WALLPAPER={}\nWALLPAPER_TYPE={}\n",
        config_escape(&path.to_string_lossy()),
        kind
    );

    fs::write(&config, contents)
        .map_err(|error| format!("Failed to save lock wallpaper: {}", error))?;

    println!("lock_wallpaper={}|{}", kind, path.display());

    Ok(())
}

fn load_current_wallpaper_state() -> (String, Option<PathBuf>, String) {
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

    // 1. Read previous wallpaper state for seamless transition handshake
    let (prev_kind, prev_thumb, _) = load_current_wallpaper_state();

    // 2. Generate target poster thumbnail if video or gif
    let mut theme_source_path = resolved_path.clone();
    let mut target_thumb = None;

    if kind == "video" || kind == "gif" {
        let thumb_path = ensure_thumbnail(&resolved_path, kind);
        theme_source_path = thumb_path.clone();
        target_thumb = Some(thumb_path);
    }

    // 3. Render display output with seamless double-buffered handshake
    super::transition::apply_with_handshake(
        &resolved_path,
        kind,
        monitor_target,
        &prev_kind,
        prev_thumb.as_deref(),
        target_thumb.as_deref(),
        opt_restore,
    )?;

    // 4. Save persistent desktop wallpaper config
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
    let _ = fs::write(&config, contents);

    println!("desktop_wallpaper={}|{}", kind, resolved_path.display());

    if opt_restore || opt_no_theme {
        return Ok(());
    }

    // 5. Apply Matugen Theme and update ScreenTemp
    let _ = crate::palette::theme::apply();

    let home = env::var("HOME").unwrap_or_else(|_| String::from("."));
    let nexad_bin = PathBuf::from(&home).join(".config/nexa/rust/target/release/nexad");
    if nexad_bin.exists() {
        let _ = Command::new(&nexad_bin)
            .args([
                "screenTemp",
                "wallpaper",
                &theme_source_path.to_string_lossy(),
            ])
            .spawn();
    }

    Ok(())
}

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
        if let Some(v) = line.strip_prefix("WALLPAPER=") {
            path = config_unescape(v);
        } else if let Some(m) = line.strip_prefix("MONITOR=") {
            monitor = config_unescape(m);
        }
    }

    if path.is_empty() {
        return Ok(());
    }

    apply_desktop(&path, Some(&monitor), true, true)
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

// ============================================================
// LOCK WALLPAPER INFO
// ============================================================

pub fn print_lock_info() -> Result<(), String> {
    let lock_config = lock_config_path();

    // ========================================================
    // EXPLICIT LOCK WALLPAPER
    // ========================================================
    //
    // If lockscreen.conf exists and contains a valid wallpaper,
    // it ALWAYS wins.
    //
    // Changing the desktop wallpaper therefore cannot affect
    // this value.
    // ========================================================

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

    // ========================================================
    // FALLBACK TO DESKTOP
    // ========================================================
    //
    // This is used ONLY if the user has never explicitly chosen
    // a lock-screen wallpaper.
    //
    // Once lockscreen.conf contains a wallpaper, background and
    // lock screen are completely independent.
    // ========================================================

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

// ============================================================
// CONFIG PARSER
// ============================================================

fn parse_wallpaper_config(contents: &str) -> (String, String) {
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

// ============================================================
// CONFIG ESCAPING
// ============================================================
//
// lockscreen.conf is deliberately simple.
//
// Paths containing spaces are written using shell-style
// backslash escaping:
//
// /home/shnx/My Wallpapers/a.png
//
// becomes:
//
// /home/shnx/My\ Wallpapers/a.png
//
// ============================================================

fn config_escape(value: &str) -> String {
    let mut escaped = String::new();

    for character in value.chars() {
        match character {
            '\\' | ' ' | '\t' | '\'' | '"' | '$' | '`' => {
                escaped.push('\\');
                escaped.push(character);
            }

            _ => {
                escaped.push(character);
            }
        }
    }

    escaped
}

// ============================================================
// CONFIG UNESCAPING
// ============================================================
//
// Also handles the normal backslash escaping generated by
// Bash's:
//
// printf '%q'
//
// which your desktop wallpaper.sh currently uses.
//
// ============================================================

fn config_unescape(value: &str) -> String {
    let value = value.trim();

    // --------------------------------------------------------
    // Simple quoted value
    // --------------------------------------------------------

    if value.len() >= 2 {
        if (value.starts_with('"') && value.ends_with('"'))
            || (value.starts_with('\'') && value.ends_with('\''))
        {
            return value[1..value.len() - 1].to_string();
        }
    }

    // --------------------------------------------------------
    // Backslash escaped value
    // --------------------------------------------------------

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
