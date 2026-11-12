use serde::{Deserialize, Serialize};
use std::{
    collections::HashSet,
    env, fs,
    os::unix::{fs::PermissionsExt, process::CommandExt},
    path::{Path, PathBuf},
    process::{Command, Stdio},
};
use walkdir::{DirEntry, WalkDir};

// ============================================================
// SEARCH ENTRY DEFINITIONS
// ============================================================

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SearchEntry {
    pub id: usize,
    pub kind: String, // "app", "appimage", "file", "folder"
    pub name: String,
    pub path: String, // Canonical absolute path
    #[serde(default)]
    pub location: String,
    pub exec: String,
    pub icon: String,
    #[serde(default)]
    pub terminal: bool,
    #[serde(default)]
    pub generic_name: String,
    #[serde(default)]
    pub keywords: String,
    #[serde(default)]
    pub description: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SearchResult {
    pub id: usize,
    pub kind: String,
    pub name: String,
    pub path: String,
    #[serde(default)]
    pub location: String,
    pub exec: String,
    pub icon: String,
    pub score: i32,
    #[serde(default)]
    pub terminal: bool,
    #[serde(default)]
    pub description: String,
}

// ============================================================
// PATHS & DIRECTORIES
// ============================================================

fn home_dir() -> PathBuf {
    env::var("HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|_| PathBuf::from("/tmp"))
}

fn cache_dir() -> PathBuf {
    home_dir().join(".cache").join("nexa")
}

fn cache_path() -> PathBuf {
    cache_dir().join("search-index.json")
}

fn apps_cache_path() -> PathBuf {
    cache_dir().join("search-apps.json")
}

fn files_cache_path() -> PathBuf {
    cache_dir().join("search-files.json")
}

pub fn format_location(path: &Path) -> String {
    let home = home_dir();
    let parent = if path.is_dir() {
        path.parent().unwrap_or(path)
    } else {
        path.parent().unwrap_or(path)
    };
    let s = parent.to_string_lossy();
    let home_s = home.to_string_lossy();
    if s == home_s.as_ref() {
        "~".to_string()
    } else if s.starts_with(home_s.as_ref()) {
        format!("~{}", &s[home_s.len()..])
    } else {
        s.to_string()
    }
}

/// Discovers all Freedesktop application directories including
/// standard XDG paths, Flatpak (system + user), and Snap.
fn application_dirs() -> Vec<PathBuf> {
    let mut dirs = Vec::new();
    let mut seen = HashSet::new();

    let mut add_dir = |p: PathBuf| {
        if p.is_dir() {
            if let Ok(canonical) = p.canonicalize() {
                if seen.insert(canonical.clone()) {
                    dirs.push(canonical);
                }
            } else if seen.insert(p.clone()) {
                dirs.push(p);
            }
        }
    };

    let home = home_dir();

    // 1. User local applications
    add_dir(home.join(".local/share/applications"));

    // 2. User Flatpak exports
    add_dir(home.join(".local/share/flatpak/exports/share/applications"));

    // 3. System Flatpak exports
    add_dir(PathBuf::from("/var/lib/flatpak/exports/share/applications"));

    // 4. XDG_DATA_HOME
    if let Ok(xdg_home) = env::var("XDG_DATA_HOME") {
        add_dir(PathBuf::from(xdg_home).join("applications"));
    }

    // 5. XDG_DATA_DIRS
    if let Ok(xdg_dirs) = env::var("XDG_DATA_DIRS") {
        for d in xdg_dirs.split(':').filter(|s| !s.is_empty()) {
            add_dir(PathBuf::from(d).join("applications"));
        }
    } else {
        add_dir(PathBuf::from("/usr/local/share/applications"));
        add_dir(PathBuf::from("/usr/share/applications"));
    }

    // 6. Snap applications
    add_dir(PathBuf::from("/var/lib/snapd/desktop/applications"));

    dirs
}

/// Discovers directories where portable or folder-based applications (macOS-style app bundles) are placed.
fn folder_app_dirs() -> Vec<PathBuf> {
    let home = home_dir();
    let candidates = [
        home.join("Applications"),
        home.join("Application"),
        home.join("Apps"),
        home.join(".local/share/applications"),
        PathBuf::from("/Applications"),
        PathBuf::from("/opt"),
    ];

    let mut dirs = Vec::new();
    let mut seen = HashSet::new();

    for p in candidates {
        if p.is_dir() {
            if let Ok(can) = p.canonicalize() {
                if seen.insert(can.clone()) {
                    dirs.push(can);
                }
            } else if seen.insert(p.clone()) {
                dirs.push(p);
            }
        }
    }

    dirs
}

/// Discovers directories where AppImages are typically placed.
fn appimage_dirs() -> Vec<PathBuf> {
    let home = home_dir();
    let candidates = [
        home.join("Applications"),
        home.join("Apps"),
        home.join("Apps_img"),
        home.join("Downloads"),
        home.join(".local/bin"),
        home.join("Desktop"),
    ];

    candidates.into_iter().filter(|p| p.is_dir()).collect()
}

/// Discovers user document and media directories.
fn file_dirs() -> Vec<PathBuf> {
    let home = home_dir();
    let mut dirs = Vec::new();

    if let Ok(entries) = fs::read_dir(&home) {
        for entry in entries.flatten() {
            let path = entry.path();
            if path.is_dir() {
                let name = entry.file_name().to_string_lossy().to_string();
                if !name.starts_with('.')
                    && name != "Applications"
                    && name != "Apps"
                    && name != "Apps_img"
                    && name != "target"
                    && name != "node_modules"
                    && name != "venv"
                    && name != "dist"
                    && name != "build"
                {
                    dirs.push(path);
                }
            }
        }
    }

    // Ensure common XDG user directories are covered
    for fallback in &[
        home.join("Desktop"),
        home.join("Documents"),
        home.join("Downloads"),
        home.join("Music"),
        home.join("Pictures"),
        home.join("Videos"),
        home.join("Projects"),
    ] {
        if fallback.is_dir() && !dirs.contains(fallback) {
            dirs.push(fallback.clone());
        }
    }

    dirs
}

// ============================================================
// STRICT DOTFILE & NOISE SHIELD
// ============================================================

/// Strictly filters out any path that contains hidden folders (starting with '.')
/// or development cache/build noise directories.
fn should_skip_entry(entry: &DirEntry) -> bool {
    let file_name = entry.file_name().to_string_lossy();

    if file_name.starts_with('.') {
        return true;
    }

    if entry.file_type().is_dir() {
        matches!(
            file_name.as_ref(),
            "node_modules"
                | "target"
                | "dist"
                | "build"
                | "venv"
                | ".venv"
                | "__pycache__"
                | "Trash"
                | ".Trash"
                | ".git"
                | ".config"
                | ".cache"
                | ".local"
        )
    } else {
        false
    }
}

/// Validates whether a file path is clean of any hidden ancestor directory.
fn is_clean_user_path(path: &Path) -> bool {
    for comp in path.components() {
        let s = comp.as_os_str().to_string_lossy();
        if s.starts_with('.') {
            return false;
        }
        if matches!(
            s.as_ref(),
            "node_modules" | "target" | "dist" | "build" | "venv" | "__pycache__" | "Trash"
        ) {
            return false;
        }
    }
    true
}

// ============================================================
// DESKTOP FILE PARSING
// ============================================================

fn resolve_desktop_icon(raw_icon: &str) -> String {
    let trimmed = raw_icon.trim();
    if trimmed.is_empty() {
        return "application-x-executable".to_string();
    }

    if trimmed.starts_with('/') {
        return trimmed.to_string();
    }

    // Check /usr/share/pixmaps/ for direct image matches
    for ext in &["", ".png", ".svg", ".xpm"] {
        let candidate = PathBuf::from(format!("/usr/share/pixmaps/{trimmed}{ext}"));
        if candidate.is_file() {
            return candidate.to_string_lossy().to_string();
        }
        let lower = trimmed.to_lowercase();
        let candidate_lower = PathBuf::from(format!("/usr/share/pixmaps/{lower}{ext}"));
        if candidate_lower.is_file() {
            return candidate_lower.to_string_lossy().to_string();
        }
    }

    // Return the icon name for Quickshell's icon theme engine
    trimmed.to_string()
}

fn parse_desktop_file(path: &Path) -> Option<SearchEntry> {
    let content = fs::read_to_string(path).ok()?;

    let mut name = String::new();
    let mut generic_name = String::new();
    let mut keywords = String::new();
    let mut exec = String::new();
    let mut icon = String::new();
    let mut terminal = false;
    let mut hidden = false;
    let mut no_display = false;
    let mut in_desktop_entry = false;

    for raw_line in content.lines() {
        let line = raw_line.trim();

        if line.starts_with('[') {
            in_desktop_entry = line == "[Desktop Entry]";
            continue;
        }

        if !in_desktop_entry {
            continue;
        }

        if let Some(val) = line.strip_prefix("Name=") {
            if name.is_empty() {
                name = val.trim().to_string();
            }
            continue;
        }

        if let Some(val) = line.strip_prefix("GenericName=") {
            if generic_name.is_empty() {
                generic_name = val.trim().to_string();
            }
            continue;
        }

        if let Some(val) = line.strip_prefix("Keywords=") {
            if keywords.is_empty() {
                keywords = val.trim().to_string();
            }
            continue;
        }

        if let Some(val) = line.strip_prefix("TryExec=") {
            let try_bin = val.trim();
            if !try_bin.is_empty() {
                if try_bin.starts_with('/') {
                    if !Path::new(try_bin).exists() {
                        return None;
                    }
                } else if !command_exists(try_bin) {
                    return None;
                }
            }
            continue;
        }

        if let Some(val) = line.strip_prefix("Exec=") {
            if exec.is_empty() {
                exec = val.trim().to_string();
            }
            continue;
        }

        if let Some(val) = line.strip_prefix("Terminal=") {
            terminal = val.trim().eq_ignore_ascii_case("true");
            continue;
        }

        if let Some(val) = line.strip_prefix("Icon=") {
            if icon.is_empty() {
                icon = resolve_desktop_icon(val);
            }
            continue;
        }

        if let Some(val) = line.strip_prefix("Hidden=") {
            hidden = val.trim().eq_ignore_ascii_case("true");
            continue;
        }

        if let Some(val) = line.strip_prefix("NoDisplay=") {
            no_display = val.trim().eq_ignore_ascii_case("true");
            continue;
        }
    }

    if hidden || no_display || name.is_empty() {
        return None;
    }

    if let Some(first_word) = exec.split_whitespace().next() {
        let bin_clean = first_word.trim_matches('"').trim_matches('\'');
        if bin_clean.starts_with('/') {
            if !Path::new(bin_clean).exists() {
                return None;
            }
        } else if !command_exists(bin_clean) {
            return None;
        }
    }

    let description = if !generic_name.is_empty() {
        generic_name.clone()
    } else {
        "Application".to_string()
    };

    let location = format_location(path);

    Some(SearchEntry {
        id: 0,
        kind: "app".to_string(),
        name,
        path: path.to_string_lossy().to_string(),
        location,
        exec,
        icon,
        terminal,
        generic_name,
        keywords,
        description,
    })
}

fn is_executable_file(path: &Path) -> bool {
    if !path.is_file() {
        return false;
    }
    if let Ok(metadata) = fs::metadata(path) {
        if metadata.permissions().mode() & 0o111 != 0 {
            return true;
        }
    }
    if let Ok(mut f) = fs::File::open(path) {
        use std::io::Read;
        let mut magic = [0u8; 4];
        if f.read_exact(&mut magic).is_ok() {
            if magic == [0x7f, b'E', b'L', b'F'] {
                return true;
            }
            if &magic[0..2] == b"#!" {
                return true;
            }
        }
    }
    false
}

fn is_helper_binary(name: &str) -> bool {
    let lower = name.to_lowercase();
    lower.contains("sandbox")
        || lower.contains("crashpad")
        || lower.contains("reporter")
        || lower.contains("updater")
        || lower.ends_with(".so")
        || lower.contains(".so.")
        || lower.ends_with(".dll")
        || lower.ends_with(".dylib")
        || lower.starts_with("lib")
        || lower == "ld-linux"
        || lower.starts_with("ld-linux")
}

fn clean_folder_app_name(raw_name: &str) -> String {
    let mut name = raw_name.trim();
    if let Some(stripped) = name.strip_suffix(".app") {
        name = stripped;
    }
    if let Some(stripped) = name.strip_suffix(".App") {
        name = stripped;
    }
    name.replace(['-', '_'], " ").trim().to_string()
}

fn find_folder_app_executable(app_dir: &Path) -> Option<(PathBuf, PathBuf)> {
    let dir_name = app_dir.file_name()?.to_str()?;
    let raw_name = dir_name.strip_suffix(".app").unwrap_or(dir_name);
    let name_lower = raw_name.to_lowercase();

    let subdirs = [
        app_dir.to_path_buf(),
        app_dir.join("app"),
        app_dir.join("bin"),
        app_dir.join("Contents").join("MacOS"),
    ];

    // Priority 1: Exact directory name match
    for sdir in &subdirs {
        if !sdir.is_dir() {
            continue;
        }
        for candidate_name in &[raw_name, &name_lower] {
            let cand_path = sdir.join(candidate_name);
            if cand_path.exists() && is_executable_file(&cand_path) {
                return Some((cand_path, app_dir.to_path_buf()));
            }
        }
        for ext in &[".sh", ".bin"] {
            let cand_path = sdir.join(format!("{raw_name}{ext}"));
            if cand_path.exists() && is_executable_file(&cand_path) {
                return Some((cand_path, app_dir.to_path_buf()));
            }
        }
    }

    // Priority 2: Standard launcher scripts
    for sdir in &subdirs {
        if !sdir.is_dir() {
            continue;
        }
        for script in &[
            "run.sh",
            "start.sh",
            "launch.sh",
            "main.sh",
            "app.sh",
            "main",
        ] {
            let cand_path = sdir.join(script);
            if cand_path.exists() && is_executable_file(&cand_path) {
                return Some((cand_path, app_dir.to_path_buf()));
            }
        }
    }

    // Priority 3: First valid executable in directory or bin
    for sdir in &subdirs {
        if let Ok(entries) = fs::read_dir(sdir) {
            for entry in entries.flatten() {
                let p = entry.path();
                if let Some(fname) = p.file_name().and_then(|f| f.to_str()) {
                    if !is_helper_binary(fname) && is_executable_file(&p) {
                        return Some((p, app_dir.to_path_buf()));
                    }
                }
            }
        }
    }

    None
}

fn find_folder_app_icon(app_dir: &Path) -> String {
    let dir_name = app_dir.file_name().and_then(|f| f.to_str()).unwrap_or("");
    let raw_name = dir_name.strip_suffix(".app").unwrap_or(dir_name);
    let name_lower = raw_name.to_lowercase();

    // 1. Direct files in app_dir
    for base in &[raw_name, &name_lower, "icon", "logo", "app"] {
        for ext in &[".png", ".svg", ".xpm"] {
            let cand = app_dir.join(format!("{base}{ext}"));
            if cand.is_file() {
                return cand.to_string_lossy().to_string();
            }
        }
    }

    // 2. Common Electron / standard asset paths
    let asset_subpaths = [
        "app/resources/app/assets/icon.png",
        "app/resources/app/assets/icon.svg",
        "resources/app/assets/icon.png",
        "resources/app/assets/icon.svg",
        "app/resources/app/icon.png",
        "resources/app/icon.png",
        "assets/icon.png",
        "assets/icon.svg",
        "assets/logo.png",
        "assets/logo.svg",
        "resources/icon.png",
        "resources/icon.svg",
        "res/icon.png",
    ];

    for rel in &asset_subpaths {
        let cand = app_dir.join(rel);
        if cand.is_file() {
            return cand.to_string_lossy().to_string();
        }
    }

    // 3. Deep search for icon/logo up to depth 4
    let walker = WalkDir::new(app_dir)
        .max_depth(4)
        .follow_links(true)
        .into_iter()
        .filter_entry(|e| {
            let n = e.file_name().to_string_lossy();
            !n.starts_with('.') && n != "node_modules" && n != ".git"
        });

    for item in walker.flatten() {
        let p = item.path();
        if !p.is_file() {
            continue;
        }
        let ext = p
            .extension()
            .and_then(|e| e.to_str())
            .unwrap_or("")
            .to_lowercase();
        if ext == "png" || ext == "svg" {
            let fname = p
                .file_stem()
                .and_then(|f| f.to_str())
                .unwrap_or("")
                .to_lowercase();
            if fname.contains("icon") || fname.contains("logo") || fname == name_lower {
                return p.to_string_lossy().to_string();
            }
        }
    }

    // 4. Try system pixmaps
    for ext in &[".png", ".svg"] {
        let cand = PathBuf::from(format!("/usr/share/pixmaps/{name_lower}{ext}"));
        if cand.is_file() {
            return cand.to_string_lossy().to_string();
        }
    }

    "application-x-executable".to_string()
}

fn index_folder_apps(
    entries: &mut Vec<SearchEntry>,
    seen_paths: &mut HashSet<String>,
    seen_desktop_ids: &mut HashSet<String>,
    seen_app_names: &mut HashSet<String>,
) {
    for directory in folder_app_dirs() {
        let read_entries = match fs::read_dir(&directory) {
            Ok(iter) => iter,
            Err(_) => continue,
        };

        for item in read_entries.flatten() {
            let path = item.path();

            let Some(file_name) = path.file_name().and_then(|f| f.to_str()) else {
                continue;
            };

            if file_name.starts_with('.') {
                continue;
            }

            // A. Directory: e.g. ~/Applications/Postman or ~/Applications/Postman.app
            if path.is_dir() {
                // Check if there is an embedded .desktop file
                let mut found_desktop = false;
                let desktop_walker = WalkDir::new(&path)
                    .max_depth(3)
                    .follow_links(true)
                    .into_iter()
                    .filter_entry(|e| !should_skip_entry(e));

                for d_item in desktop_walker.flatten() {
                    let d_path = d_item.path();
                    if d_path.extension().and_then(|ext| ext.to_str()) == Some("desktop") {
                        if let Some(mut d_entry) = parse_desktop_file(d_path) {
                            let p_str = d_path.to_string_lossy().to_string();
                            let d_id = d_path
                                .file_name()
                                .and_then(|f| f.to_str())
                                .unwrap_or("")
                                .to_lowercase();
                            let name_key = d_entry.name.trim().to_lowercase();

                            if seen_desktop_ids.contains(&d_id)
                                || seen_app_names.contains(&name_key)
                                || !seen_paths.insert(p_str)
                            {
                                found_desktop = true;
                                break;
                            }

                            seen_desktop_ids.insert(d_id);
                            seen_app_names.insert(name_key);

                            if !d_entry.exec.starts_with('/') {
                                if let Some((bin_path, _)) = find_folder_app_executable(&path) {
                                    d_entry.exec = bin_path.to_string_lossy().to_string();
                                }
                            }
                            entries.push(d_entry);
                            found_desktop = true;
                            break;
                        }
                    }
                }

                if found_desktop {
                    continue;
                }

                // If no desktop file found, treat as folder application bundle
                if let Some((exec_path, _workdir)) = find_folder_app_executable(&path) {
                    let app_name = clean_folder_app_name(file_name);
                    let name_key = app_name.to_lowercase();

                    if seen_app_names.contains(&name_key) {
                        continue;
                    }
                    seen_app_names.insert(name_key.clone());

                    let path_str = path.to_string_lossy().to_string();
                    seen_paths.insert(path_str.clone());

                    let icon = find_folder_app_icon(&path);
                    let exec_str = exec_path.to_string_lossy().to_string();
                    let location = format_location(&path);

                    entries.push(SearchEntry {
                        id: 0,
                        kind: "app".to_string(),
                        name: app_name,
                        path: path_str,
                        location,
                        exec: exec_str,
                        icon,
                        terminal: false,
                        generic_name: "Application".to_string(),
                        keywords: format!("application;portable;folder;{name_key};"),
                        description: "Application".to_string(),
                    });
                }
            } else if path.is_file() || path.is_symlink() {
                // B. Standalone binary or link directly in Applications
                let lower = file_name.to_lowercase();
                if lower.ends_with(".appimage") || lower.ends_with(".desktop") {
                    continue;
                }

                if is_helper_binary(file_name) || !is_executable_file(&path) {
                    continue;
                }

                let app_name = clean_folder_app_name(file_name);
                let name_key = app_name.to_lowercase();

                if seen_app_names.contains(&name_key) {
                    continue;
                }
                seen_app_names.insert(name_key.clone());

                let path_str = path.to_string_lossy().to_string();
                if !seen_paths.insert(path_str.clone()) {
                    continue;
                }

                let icon = find_folder_app_icon(path.parent().unwrap_or(&path));
                let location = format_location(&path);

                entries.push(SearchEntry {
                    id: 0,
                    kind: "app".to_string(),
                    name: app_name,
                    path: path_str.clone(),
                    location,
                    exec: path_str,
                    icon,
                    terminal: false,
                    generic_name: "Application".to_string(),
                    keywords: format!("application;portable;{name_key};"),
                    description: "Application".to_string(),
                });
            }
        }
    }
}

// ============================================================
// APPIMAGE DISCOVERY
// ============================================================

fn clean_appimage_name(file_name: &str) -> String {
    let mut base = file_name;
    for ext in &[".AppImage", ".appimage"] {
        if let Some(s) = base.strip_suffix(ext) {
            base = s;
            break;
        }
    }

    let cleaned = base.replace(['-', '_'], " ");
    cleaned.trim().to_string()
}

fn index_appimages(
    entries: &mut Vec<SearchEntry>,
    seen_paths: &mut HashSet<String>,
    seen_app_names: &mut HashSet<String>,
) {
    for directory in appimage_dirs() {
        let walker = WalkDir::new(&directory)
            .max_depth(3)
            .follow_links(true)
            .into_iter()
            .filter_entry(|e| !should_skip_entry(e));

        for item in walker.flatten() {
            let path = item.path();
            if !path.is_file() {
                continue;
            }

            let Some(file_name) = path.file_name().and_then(|f| f.to_str()) else {
                continue;
            };

            let lower = file_name.to_lowercase();
            if !lower.ends_with(".appimage") {
                continue;
            }

            // Ensure executable permissions
            if let Ok(metadata) = fs::metadata(path) {
                let mut perms = metadata.permissions();
                let mode = perms.mode();
                if mode & 0o111 == 0 {
                    perms.set_mode(mode | 0o755);
                    let _ = fs::set_permissions(path, perms);
                }
            }

            let path_string = path.to_string_lossy().to_string();
            if !seen_paths.insert(path_string.clone()) {
                continue;
            }

            let name = clean_appimage_name(file_name);
            let name_key = name.trim().to_lowercase();
            if seen_app_names.contains(&name_key) {
                continue;
            }
            seen_app_names.insert(name_key);

            // Look for adjacent icon if present
            let parent = path.parent();
            let mut icon = "application-x-executable".to_string();
            if let Some(p) = parent {
                let stem = path.file_stem().and_then(|s| s.to_str()).unwrap_or("");
                for ext in &[".png", ".svg"] {
                    let img_cand = p.join(format!("{stem}{ext}"));
                    if img_cand.is_file() {
                        icon = img_cand.to_string_lossy().to_string();
                        break;
                    }
                }
            }

            let location = format_location(path);

            entries.push(SearchEntry {
                id: 0,
                kind: "appimage".to_string(),
                name,
                path: path_string,
                location,
                exec: path.to_string_lossy().to_string(),
                icon,
                terminal: false,
                generic_name: "AppImage Executable".to_string(),
                keywords: "appimage;portable;application;".to_string(),
                description: "AppImage".to_string(),
            });
        }
    }
}

// ============================================================
// APPLICATION INDEXING
// ============================================================

fn index_applications(
    entries: &mut Vec<SearchEntry>,
    seen_paths: &mut HashSet<String>,
    seen_desktop_ids: &mut HashSet<String>,
    seen_app_names: &mut HashSet<String>,
) {
    for directory in application_dirs() {
        let walker = WalkDir::new(&directory)
            .max_depth(4)
            .follow_links(true)
            .into_iter()
            .filter_entry(|e| !should_skip_entry(e));

        for item in walker.flatten() {
            let path = item.path();
            if !path.is_file() {
                continue;
            }

            if path.extension().and_then(|ext| ext.to_str()) != Some("desktop") {
                continue;
            }

            let Some(entry) = parse_desktop_file(path) else {
                continue;
            };

            let d_id = path
                .file_name()
                .and_then(|v| v.to_str())
                .unwrap_or("")
                .to_lowercase();

            let name_key = entry.name.trim().to_lowercase();

            if d_id.is_empty()
                || seen_desktop_ids.contains(&d_id)
                || seen_app_names.contains(&name_key)
            {
                continue;
            }

            seen_desktop_ids.insert(d_id);
            seen_app_names.insert(name_key);

            let path_str = path.to_string_lossy().to_string();
            seen_paths.insert(path_str);
            entries.push(entry);
        }
    }
}

// ============================================================
// FILE INDEXING
// ============================================================

fn index_files(entries: &mut Vec<SearchEntry>, seen_paths: &mut HashSet<String>) {
    let home = home_dir();

    // Index non-hidden files directly in user home directory
    if let Ok(read_home) = fs::read_dir(&home) {
        for entry in read_home.flatten() {
            let path = entry.path();
            if path.is_file() {
                let name = entry.file_name().to_string_lossy().to_string();
                if !name.starts_with('.') {
                    let path_string = path.to_string_lossy().to_string();
                    if seen_paths.insert(path_string.clone()) {
                        let ext = path
                            .extension()
                            .and_then(|e| e.to_str())
                            .unwrap_or("")
                            .to_uppercase();
                        let description = if !ext.is_empty() {
                            format!("{ext} Document")
                        } else {
                            "File".to_string()
                        };
                        let location = format_location(&path);
                        entries.push(SearchEntry {
                            id: 0,
                            kind: "file".to_string(),
                            name,
                            path: path_string,
                            location,
                            exec: String::new(),
                            icon: String::new(),
                            terminal: false,
                            generic_name: String::new(),
                            keywords: String::new(),
                            description,
                        });
                    }
                }
            }
        }
    }

    for directory in file_dirs() {
        let walker = WalkDir::new(&directory)
            .follow_links(false)
            .max_depth(5)
            .into_iter()
            .filter_entry(|e| !should_skip_entry(e));

        for item in walker.flatten() {
            let path = item.path();
            if path == directory {
                continue;
            }

            if !path.is_file() && !path.is_dir() {
                continue;
            }

            let Some(name) = path.file_name().and_then(|v| v.to_str()) else {
                continue;
            };

            if name.starts_with('.') {
                continue;
            }

            // Verify the path has no hidden components
            if !is_clean_user_path(path) {
                continue;
            }

            let path_string = path.to_string_lossy().to_string();
            if !seen_paths.insert(path_string.clone()) {
                continue;
            }

            let ext = path
                .extension()
                .and_then(|e| e.to_str())
                .unwrap_or("")
                .to_uppercase();

            let is_dir = path.is_dir();
            let description = if is_dir {
                "Folder".to_string()
            } else if !ext.is_empty() {
                format!("{ext} Document")
            } else {
                "File".to_string()
            };

            let location = format_location(path);
            let kind = if is_dir {
                "folder".to_string()
            } else {
                "file".to_string()
            };

            entries.push(SearchEntry {
                id: 0,
                kind,
                name: name.to_string(),
                path: path_string,
                location,
                exec: String::new(),
                icon: String::new(),
                terminal: false,
                generic_name: String::new(),
                keywords: String::new(),
                description,
            });
        }
    }
}

// ============================================================
// BUILD & CACHE ENGINE (Dual Tier: Microsecond Mtime Invalidation)
// ============================================================

fn get_app_dirs_max_mtime() -> std::time::SystemTime {
    let mut max_time = std::time::SystemTime::UNIX_EPOCH;
    for dir in application_dirs() {
        if let Ok(meta) = fs::metadata(&dir) {
            if let Ok(m) = meta.modified() {
                if m > max_time {
                    max_time = m;
                }
            }
        }
    }
    for dir in folder_app_dirs() {
        if let Ok(meta) = fs::metadata(&dir) {
            if let Ok(m) = meta.modified() {
                if m > max_time {
                    max_time = m;
                }
            }
        }
    }
    for dir in appimage_dirs() {
        if let Ok(meta) = fs::metadata(&dir) {
            if let Ok(m) = meta.modified() {
                if m > max_time {
                    max_time = m;
                }
            }
        }
    }
    max_time
}

fn build_app_index() -> Vec<SearchEntry> {
    let mut entries = Vec::new();
    let mut seen_paths = HashSet::new();
    let mut seen_desktop_ids = HashSet::new();
    let mut seen_app_names = HashSet::new();

    index_applications(
        &mut entries,
        &mut seen_paths,
        &mut seen_desktop_ids,
        &mut seen_app_names,
    );
    index_folder_apps(
        &mut entries,
        &mut seen_paths,
        &mut seen_desktop_ids,
        &mut seen_app_names,
    );
    index_appimages(&mut entries, &mut seen_paths, &mut seen_app_names);

    // Final safety deduplication pass
    let mut deduped = Vec::with_capacity(entries.len());
    let mut final_seen = HashSet::new();
    for entry in entries {
        let key = entry.name.trim().to_lowercase();
        if final_seen.insert(key) {
            deduped.push(entry);
        }
    }

    deduped.sort_by(|a, b| {
        let rank_a = match a.kind.as_str() {
            "app" => 0,
            "appimage" => 1,
            _ => 2,
        };
        let rank_b = match b.kind.as_str() {
            "app" => 0,
            "appimage" => 1,
            _ => 2,
        };

        rank_a
            .cmp(&rank_b)
            .then_with(|| a.name.to_lowercase().cmp(&b.name.to_lowercase()))
    });

    deduped
}

fn load_app_index() -> Vec<SearchEntry> {
    let path = apps_cache_path();
    let max_mtime = get_app_dirs_max_mtime();

    if path.is_file() {
        if let Ok(meta) = fs::metadata(&path) {
            if let Ok(cache_mtime) = meta.modified() {
                // If cache is at least as new as all app directories, it's valid
                if cache_mtime >= max_mtime {
                    if let Ok(content) = fs::read_to_string(&path) {
                        if let Ok(entries) = serde_json::from_str::<Vec<SearchEntry>>(&content) {
                            if !entries.is_empty() {
                                return entries;
                            }
                        }
                    }
                }
            }
        }
    }

    // Cache missing or an app directory was modified (new app installed / removed)
    let entries = build_app_index();
    let _ = fs::create_dir_all(cache_dir());
    if let Ok(json) = serde_json::to_string(&entries) {
        let _ = fs::write(&path, json);
    }
    entries
}

fn build_file_index() -> Vec<SearchEntry> {
    let mut entries = Vec::new();
    let mut seen_paths = HashSet::new();
    index_files(&mut entries, &mut seen_paths);
    entries.sort_by(|a, b| a.name.to_lowercase().cmp(&b.name.to_lowercase()));
    entries
}

fn load_file_index() -> Vec<SearchEntry> {
    let path = files_cache_path();
    if path.is_file() {
        if let Ok(content) = fs::read_to_string(&path) {
            if let Ok(entries) = serde_json::from_str::<Vec<SearchEntry>>(&content) {
                if !entries.is_empty() {
                    return entries;
                }
            }
        }
    }

    let entries = build_file_index();
    let _ = fs::create_dir_all(cache_dir());
    if let Ok(json) = serde_json::to_string(&entries) {
        let _ = fs::write(&path, json);
    }
    entries
}

fn save_index(entries: &[SearchEntry]) -> Result<(), String> {
    fs::create_dir_all(cache_dir()).map_err(|e| format!("failed to create cache dir: {e}"))?;

    let json = serde_json::to_string(entries)
        .map_err(|e| format!("failed to serialize search index: {e}"))?;

    fs::write(cache_path(), json).map_err(|e| format!("failed to write search index: {e}"))?;

    Ok(())
}

fn load_index() -> Result<Vec<SearchEntry>, String> {
    let mut apps = load_app_index();
    let mut files = load_file_index();
    let mut all = Vec::with_capacity(apps.len() + files.len());
    all.append(&mut apps);
    all.append(&mut files);

    for (idx, entry) in all.iter_mut().enumerate() {
        entry.id = idx;
    }

    Ok(all)
}

/// On-demand deep search for exact files and folders using ultra-fast fd
/// Strictly ignores hidden files and dot-folders by default
fn find_exact_files_fd(query: &str) -> Vec<SearchEntry> {
    let clean_query = query.trim();
    if clean_query.len() < 3 || clean_query.starts_with('/') {
        return Vec::new();
    }

    let home = home_dir();
    let output = Command::new("fd")
        .arg("-i")
        .arg("--exclude")
        .arg("node_modules")
        .arg("--exclude")
        .arg("target")
        .arg("--exclude")
        .arg(".git")
        .arg("--exclude")
        .arg(".cache")
        .arg("--max-results")
        .arg("15")
        .arg("-g")
        .arg(format!("*{clean_query}*"))
        .arg(&home)
        .output();

    let mut entries = Vec::new();
    if let Ok(out) = output {
        if out.status.success() {
            let stdout = String::from_utf8_lossy(&out.stdout);
            for line in stdout.lines() {
                let path_str = line.trim();
                if path_str.is_empty() {
                    continue;
                }
                let path = PathBuf::from(path_str);
                if !is_clean_user_path(&path) {
                    continue;
                }
                let is_dir = path.is_dir();
                let name = path
                    .file_name()
                    .and_then(|f| f.to_str())
                    .unwrap_or(path_str)
                    .to_string();

                let location = format_location(&path);
                let ext = path
                    .extension()
                    .and_then(|e| e.to_str())
                    .unwrap_or("")
                    .to_uppercase();

                let description = if is_dir {
                    "Folder".to_string()
                } else if !ext.is_empty() {
                    format!("{ext} Document")
                } else {
                    "File".to_string()
                };

                let kind = if is_dir {
                    "folder".to_string()
                } else {
                    "file".to_string()
                };

                entries.push(SearchEntry {
                    id: 0,
                    kind,
                    name,
                    path: path_str.to_string(),
                    location,
                    exec: String::new(),
                    icon: String::new(),
                    terminal: false,
                    generic_name: String::new(),
                    keywords: String::new(),
                    description,
                });
            }
        }
    }

    entries
}

// ============================================================
// FUZZY SCORING ENGINE
// ============================================================

fn extract_words(text: &str) -> Vec<String> {
    let mut words = Vec::new();
    let mut current = String::new();
    let mut prev_char: Option<char> = None;

    for ch in text.chars() {
        if ch.is_alphanumeric() {
            if let Some(prev) = prev_char {
                if prev.is_lowercase() && ch.is_uppercase() && !current.is_empty() {
                    words.push(current.to_lowercase());
                    current = String::new();
                }
            }
            current.push(ch);
            prev_char = Some(ch);
        } else {
            if !current.is_empty() {
                words.push(current.to_lowercase());
                current = String::new();
            }
            prev_char = None;
        }
    }

    if !current.is_empty() {
        words.push(current.to_lowercase());
    }

    words
}

fn compute_acronym(words: &[String]) -> String {
    words.iter().filter_map(|w| w.chars().next()).collect()
}

fn score_text(target: &str, query: &str) -> Option<i32> {
    let norm_target = target.trim().to_lowercase();
    let norm_query = query.trim().to_lowercase();

    if norm_query.is_empty() || norm_target.is_empty() {
        return None;
    }

    // 1. Exact match
    if norm_target == norm_query {
        return Some(1200);
    }

    let target_words = extract_words(target);
    let query_words = extract_words(query);
    let acronym = compute_acronym(&target_words);

    // 2. Acronym match (e.g. "vsc" or "vs" -> "Visual Studio Code")
    if !acronym.is_empty() {
        if acronym == norm_query {
            return Some(1100);
        }
        if acronym.starts_with(&norm_query) && norm_query.len() >= 2 {
            return Some(1050);
        }
    }

    // Direct alias mappings (e.g. "vs" -> Visual Studio Code)
    if norm_query == "vs" && (norm_target.contains("visual studio") || norm_target.contains("vscode")) {
        return Some(1150);
    }

    // 3. Multi-word prefix match (e.g. "vs code" -> "Visual Studio Code")
    if query_words.len() > 1 && !target_words.is_empty() {
        let mut t_idx = 0;
        let mut all_matched = true;

        for qw in &query_words {
            let mut matched_word = false;
            while t_idx < target_words.len() {
                let tw = &target_words[t_idx];
                t_idx += 1;
                if tw.starts_with(qw) {
                    matched_word = true;
                    break;
                }
            }
            if !matched_word {
                all_matched = false;
                break;
            }
        }

        if all_matched {
            return Some(950);
        }
    }

    // 4. String prefix match (e.g. "fire" -> "Firefox")
    if norm_target.starts_with(&norm_query) {
        let penalty = (norm_target.len().saturating_sub(norm_query.len()) as i32).min(50);
        return Some(900 - penalty);
    }

    // 5. Word-boundary prefix match (e.g. "calc" -> "LibreOffice Calc")
    for tw in &target_words {
        if tw.starts_with(&norm_query) {
            let penalty = (tw.len().saturating_sub(norm_query.len()) as i32).min(40);
            return Some(850 - penalty);
        }
    }

    // 6. Substring match
    if norm_target.contains(&norm_query) {
        let penalty = (norm_target.len().saturating_sub(norm_query.len()) as i32).min(80);
        return Some(650 - penalty);
    }

    // 7. Compact Fuzzy Subsequence
    let target_chars: Vec<char> = norm_target.chars().collect();
    let query_chars: Vec<char> = norm_query.chars().collect();

    if query_chars.len() < 3 {
        return None;
    }

    let length_gap = target_chars.len().saturating_sub(query_chars.len());
    if length_gap > 12 {
        return None;
    }

    let mut q_idx = 0usize;
    let mut first_match = None;
    let mut last_match = None;
    let mut consecutive = 0i32;
    let mut best_consecutive = 0i32;

    for (idx, ch) in target_chars.iter().enumerate() {
        if q_idx >= query_chars.len() {
            break;
        }

        if *ch == query_chars[q_idx] {
            if first_match.is_none() {
                first_match = Some(idx);
            }
            if let Some(prev) = last_match {
                if idx == prev + 1 {
                    consecutive += 1;
                } else {
                    consecutive = 1;
                }
            } else {
                consecutive = 1;
            }
            best_consecutive = best_consecutive.max(consecutive);
            last_match = Some(idx);
            q_idx += 1;
        }
    }

    if q_idx != query_chars.len() {
        return None;
    }

    let first = first_match?;
    let last = last_match?;
    let span = last.saturating_sub(first) + 1;
    let max_span = query_chars.len() + 6;

    if span > max_span || best_consecutive < 2 {
        return None;
    }

    let mut score = 350;
    score += (max_span.saturating_sub(span) as i32) * 12;
    score += best_consecutive * 18;
    score -= (first as i32) * 5;
    score -= (length_gap as i32) * 3;

    if score < 300 {
        return None;
    }

    Some(score)
}

fn score_entry(entry: &SearchEntry, query: &str) -> Option<i32> {
    let mut best_score: Option<i32> = None;

    let mut update_best = |new_score: Option<i32>| {
        if let Some(ns) = new_score {
            best_score = Some(best_score.map_or(ns, |c| c.max(ns)));
        }
    };

    update_best(score_text(&entry.name, query));

    if entry.kind == "app" || entry.kind == "appimage" {
        if !entry.generic_name.is_empty() {
            update_best(score_text(&entry.generic_name, query).map(|s| s - 30));
        }
        if !entry.keywords.is_empty() {
            update_best(score_text(&entry.keywords, query).map(|s| s - 50));
        }

        let exec_bin = entry
            .exec
            .split_whitespace()
            .next()
            .and_then(|s| Path::new(s).file_name())
            .and_then(|s| s.to_str())
            .unwrap_or("");

        if !exec_bin.is_empty() {
            update_best(score_text(exec_bin, query).map(|s| s - 20));
        }

        let path_stem = Path::new(&entry.path)
            .file_stem()
            .and_then(|s| s.to_str())
            .unwrap_or("");

        if !path_stem.is_empty() {
            update_best(score_text(path_stem, query).map(|s| s - 20));
        }
    } else if entry.kind == "file" || entry.kind == "folder" {
        let p = Path::new(&entry.path);
        let q_trimmed = query.trim();
        let fname = p.file_name().and_then(|s| s.to_str()).unwrap_or("");

        // 1. Exact full filename or folder name match
        if fname.eq_ignore_ascii_case(q_trimmed) {
            update_best(Some(2200));
        }

        if let Some(stem) = p.file_stem().and_then(|s| s.to_str()) {
            if stem.eq_ignore_ascii_case(q_trimmed) {
                update_best(Some(1800));
            } else if stem.to_lowercase().starts_with(&q_trimmed.to_lowercase()) {
                update_best(Some(980));
            }
        }

        if let Some(ext) = p.extension().and_then(|e| e.to_str()) {
            let clean_q = q_trimmed.trim_start_matches('.');
            if ext.eq_ignore_ascii_case(clean_q) {
                update_best(Some(850));
            }
        }
    }

    let score = best_score?;
    let bonus = match entry.kind.as_str() {
        "app" => 250,
        "appimage" => 220,
        _ => 0,
    };

    Some(score + bonus)
}

// ============================================================
// COMMAND / PATH BINARY RUNNER (Unified Command Mode)
// ============================================================



pub fn run(command: &str) {
    let home = home_dir();
    let shell = env::var("SHELL").unwrap_or_else(|_| "/bin/sh".to_string());

    let status = Command::new(&shell)
        .arg("-c")
        .arg(command)
        .current_dir(&home)
        .process_group(0)
        .status();

    match status {
        Ok(s) => {
            let code = s.code().unwrap_or(0);
            println!("{{\"exit_code\": {code}}}");
        }
        Err(err) => {
            eprintln!("Failed to execute command '{command}': {err}");
            std::process::exit(2);
        }
    }
}

// ============================================================
// PUBLIC COMMANDS: REFRESH & QUERY
// ============================================================

pub fn refresh() {
    let apps = build_app_index();
    let files = build_file_index();
    let _ = fs::create_dir_all(cache_dir());

    if let Ok(json) = serde_json::to_string(&apps) {
        let _ = fs::write(apps_cache_path(), json);
    }
    if let Ok(json) = serde_json::to_string(&files) {
        let _ = fs::write(files_cache_path(), json);
    }

    let mut all = apps;
    all.extend(files);
    for (idx, entry) in all.iter_mut().enumerate() {
        entry.id = idx;
    }
    let _ = save_index(&all);

    let output = serde_json::json!({
        "indexed": all.len(),
        "cache": cache_path().to_string_lossy().to_string()
    });

    println!("{output}");
}

pub fn query(query_str: &str) {
    let query_str = query_str.trim();
    if query_str.is_empty() {
        println!("[]");
        return;
    }



    let mut results: Vec<SearchResult> = Vec::new();
    let mut seen_paths: HashSet<String> = HashSet::new();

    // Direct path detection: typing /... or ~/... directly resolves existing files/folders
    if query_str.starts_with('/') || query_str.starts_with('~') || query_str.starts_with("./") {
        let expanded = if let Some(stripped) = query_str.strip_prefix('~') {
            home_dir().join(stripped.trim_start_matches('/'))
        } else {
            PathBuf::from(query_str)
        };

        if expanded.exists() {
            let name = expanded
                .file_name()
                .and_then(|f| f.to_str())
                .unwrap_or(query_str)
                .to_string();
            let is_dir = expanded.is_dir();
            let location = format_location(&expanded);
            let description = if is_dir {
                "Folder".to_string()
            } else {
                let ext = expanded
                    .extension()
                    .and_then(|e| e.to_str())
                    .unwrap_or("")
                    .to_uppercase();
                if !ext.is_empty() {
                    format!("{ext} Document")
                } else {
                    "File".to_string()
                }
            };
            let kind = if is_dir {
                "folder".to_string()
            } else {
                "file".to_string()
            };
            let path_str = expanded.to_string_lossy().to_string();
            seen_paths.insert(path_str.clone());

            results.push(SearchResult {
                id: 0,
                kind,
                name,
                path: path_str,
                location,
                exec: String::new(),
                icon: String::new(),
                score: 5000,
                terminal: false,
                description,
            });
        }
    }

    let entries = match load_index() {
        Ok(entries) => entries,
        Err(error) => {
            eprintln!("NEXA search query error: {error}");
            std::process::exit(2);
        }
    };

    for entry in &entries {
        if let Some(score) = score_entry(entry, query_str) {
            seen_paths.insert(entry.path.clone());
            results.push(SearchResult {
                id: entry.id,
                kind: entry.kind.clone(),
                name: entry.name.clone(),
                path: entry.path.clone(),
                location: entry.location.clone(),
                exec: entry.exec.clone(),
                icon: entry.icon.clone(),
                score,
                terminal: entry.terminal,
                description: entry.description.clone(),
            });
        }
    }

    // Deep on-demand exact file search via fd if query is 3+ characters
    if query_str.len() >= 3 {
        let fd_entries = find_exact_files_fd(query_str);
        for entry in fd_entries {
            if seen_paths.insert(entry.path.clone()) {
                if let Some(score) = score_entry(&entry, query_str) {
                    results.push(SearchResult {
                        id: 800000 + results.len(),
                        kind: entry.kind,
                        name: entry.name,
                        path: entry.path,
                        location: entry.location,
                        exec: entry.exec,
                        icon: entry.icon,
                        score,
                        terminal: entry.terminal,
                        description: entry.description,
                    });
                }
            }
        }
    }

    results.sort_by(|a, b| {
        b.score
            .cmp(&a.score)
            .then_with(|| a.name.to_lowercase().cmp(&b.name.to_lowercase()))
    });

    results.truncate(30);

    match serde_json::to_string(&results) {
        Ok(json) => println!("{json}"),
        Err(error) => {
            eprintln!("NEXA search serialization error: {error}");
            std::process::exit(2);
        }
    }
}

// ============================================================
// RELIABLE LAUNCH ENGINE
// ============================================================

fn clean_desktop_exec(exec: &str) -> String {
    let mut cleaned = exec.to_string();
    for code in [
        "%f", "%F", "%u", "%U", "%i", "%c", "%k", "%d", "%D", "%n", "%N", "%v", "%m",
    ] {
        cleaned = cleaned.replace(code, "");
    }
    cleaned = cleaned.replace("%%", "%");
    cleaned.split_whitespace().collect::<Vec<_>>().join(" ")
}

fn command_exists(name: &str) -> bool {
    if let Ok(path_var) = env::var("PATH") {
        for p in path_var.split(':') {
            if Path::new(p).join(name).is_file() {
                return true;
            }
        }
    }
    false
}

fn launch_desktop_file(path_str: &str) -> Result<(), String> {
    let desktop_path = Path::new(path_str);
    if !desktop_path.is_file() {
        return Err(format!("desktop file not found: {path_str}"));
    }

    let content =
        fs::read_to_string(desktop_path).map_err(|e| format!("cannot read desktop file: {e}"))?;

    let mut exec = String::new();
    let mut terminal = false;
    let mut workdir = home_dir();

    for line in content.lines() {
        let l = line.trim();
        if let Some(v) = l.strip_prefix("Exec=") {
            if exec.is_empty() {
                exec = v.trim().to_string();
            }
        } else if let Some(v) = l.strip_prefix("Terminal=") {
            terminal = v.trim().eq_ignore_ascii_case("true");
        } else if let Some(v) = l.strip_prefix("Path=") {
            let wd = PathBuf::from(v.trim());
            if wd.is_dir() {
                workdir = wd;
            }
        }
    }

    // 1. Primary launcher: gio launch (Only for GUI apps; gio launch cannot spawn terminal apps on Wayland)
    if !terminal && command_exists("gio") {
        let status = Command::new("gio")
            .arg("launch")
            .arg(desktop_path)
            .stdin(Stdio::null())
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .process_group(0)
            .status();

        if let Ok(st) = status {
            if st.success() {
                return Ok(());
            }
        }
    }

    // 2. Direct execution (or Terminal execution)
    let cleaned_exec = clean_desktop_exec(&exec);
    let mut tokens: Vec<String> = cleaned_exec
        .split_whitespace()
        .map(|s| s.to_string())
        .collect();
    if tokens.is_empty() {
        return Err(format!("no Exec line found in {path_str}"));
    }

    // Special handling for btop: needs --force-utf so it renders properly in terminal
    if tokens[0].ends_with("btop") && !tokens.iter().any(|arg| arg == "--force-utf") {
        tokens.push("--force-utf".to_string());
    }

    let lang = env::var("LANG").unwrap_or_else(|_| "en_US.UTF-8".to_string());
    let lc_all = env::var("LC_ALL").unwrap_or_else(|_| "en_US.UTF-8".to_string());

    let mut cmd = if terminal {
        let term = env::var("TERMINAL").unwrap_or_else(|_| "kitty".to_string());
        let app_name = if desktop_path
            .file_stem()
            .and_then(|s| s.to_str())
            .unwrap_or("")
            .to_lowercase()
            .starts_with("btop")
            || tokens[0].ends_with("btop")
        {
            "btop".to_string()
        } else if tokens[0].ends_with("yazi") {
            "yazi".to_string()
        } else {
            desktop_path
                .file_stem()
                .and_then(|s| s.to_str())
                .unwrap_or("app")
                .to_lowercase()
        };

        let mut c = Command::new(&term);
        let term_name = Path::new(&term)
            .file_name()
            .and_then(|n| n.to_str())
            .unwrap_or(&term);

        match term_name {
            "kitty" | "alacritty" | "wezterm" => {
                c.arg("--class").arg(&app_name);
            }
            "foot" => {
                c.arg("-a").arg(&app_name);
            }
            "xterm" => {
                c.arg("-class").arg(&app_name);
            }
            _ => {}
        }

        // Terminal execute flag (-e for kitty, foot, alacritty, wezterm, xterm)
        c.arg("-e");
        c.args(&tokens);
        c
    } else {
        let mut c = Command::new(&tokens[0]);
        if tokens.len() > 1 {
            c.args(&tokens[1..]);
        }
        c
    };

    cmd.current_dir(workdir)
        .env("LANG", lang)
        .env("LC_ALL", lc_all)
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .process_group(0)
        .spawn()
        .map(|_| ())
        .map_err(|e| format!("failed to spawn exec command: {e}"))
}

fn launch_folder_app(exec_path: &Path, workdir: &Path) -> Result<(), String> {
    if !exec_path.exists() {
        return Err(format!("executable not found: {}", exec_path.display()));
    }

    if let Ok(metadata) = fs::metadata(exec_path) {
        let mut perms = metadata.permissions();
        let mode = perms.mode();
        if mode & 0o111 == 0 {
            perms.set_mode(mode | 0o755);
            let _ = fs::set_permissions(exec_path, perms);
        }
    }

    let workdir = if workdir.is_dir() {
        workdir
    } else {
        exec_path.parent().unwrap_or_else(|| Path::new("/"))
    };

    Command::new(exec_path)
        .current_dir(workdir)
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .process_group(0)
        .spawn()
        .map(|_| ())
        .map_err(|e| {
            format!(
                "failed to launch application '{}': {e}",
                exec_path.display()
            )
        })
}

fn launch_appimage(path_str: &str) -> Result<(), String> {
    let path = Path::new(path_str);
    if !path.is_file() {
        return Err(format!("AppImage not found: {path_str}"));
    }

    // Ensure executable permissions (chmod +x)
    if let Ok(metadata) = fs::metadata(path) {
        let mut perms = metadata.permissions();
        let mode = perms.mode();
        if mode & 0o111 == 0 {
            perms.set_mode(mode | 0o755);
            let _ = fs::set_permissions(path, perms);
        }
    }

    let parent_dir = path.parent().unwrap_or(&home_dir()).to_path_buf();

    Command::new(path)
        .current_dir(parent_dir)
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .process_group(0)
        .spawn()
        .map(|_| ())
        .map_err(|e| format!("failed to launch AppImage: {e}"))
}

fn launch_file(path_str: &str) -> Result<(), String> {
    let path = Path::new(path_str);
    if !path.exists() {
        return Err(format!("file not found: {path_str}"));
    }

    Command::new("xdg-open")
        .arg(path)
        .current_dir(home_dir())
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .process_group(0)
        .spawn()
        .map(|_| ())
        .map_err(|e| format!("failed to open file via xdg-open: {e}"))
}

pub fn open(target: &str) {
    let target = target.trim();
    if target.is_empty() {
        eprintln!("NEXA search open error: empty target");
        std::process::exit(2);
    }



    // If target is directly an existing path (with optional ~ expansion)
    let target_path = if let Some(stripped) = target.strip_prefix('~') {
        home_dir().join(stripped.trim_start_matches('/'))
    } else {
        PathBuf::from(target)
    };

    if target_path.exists() {
        let path_str = target_path.to_string_lossy().to_string();
        let result = if path_str.ends_with(".desktop") {
            launch_desktop_file(&path_str)
        } else if path_str.to_lowercase().ends_with(".appimage") {
            launch_appimage(&path_str)
        } else if target_path.is_dir() {
            if let Some((exec, workdir)) = find_folder_app_executable(&target_path) {
                launch_folder_app(&exec, &workdir)
            } else {
                launch_file(&path_str)
            }
        } else if is_executable_file(&target_path) {
            let workdir = target_path.parent().unwrap_or_else(|| Path::new("/"));
            launch_folder_app(&target_path, workdir)
        } else {
            launch_file(&path_str)
        };

        if let Err(error) = result {
            eprintln!("NEXA search open error: {error}");
            std::process::exit(2);
        }
        return;
    }

    // Fallback: target is a numeric ID
    if let Ok(id) = target.parse::<usize>() {
        let entries = match load_index() {
            Ok(entries) => entries,
            Err(error) => {
                eprintln!("NEXA search open error: {error}");
                std::process::exit(2);
            }
        };

        let Some(entry) = entries.iter().find(|e| e.id == id) else {
            eprintln!("NEXA search open error: result id {id} not found");
            std::process::exit(2);
        };

        let result = match entry.kind.as_str() {
            "app" => {
                if entry.path.ends_with(".desktop") {
                    launch_desktop_file(&entry.path)
                } else {
                    let exec_path = PathBuf::from(&entry.exec);
                    let entry_path = PathBuf::from(&entry.path);
                    let workdir = if entry_path.is_dir() {
                        entry_path
                    } else {
                        exec_path
                            .parent()
                            .unwrap_or_else(|| Path::new("/"))
                            .to_path_buf()
                    };
                    launch_folder_app(&exec_path, &workdir)
                }
            }
            "appimage" => launch_appimage(&entry.path),
            "file" | "folder" => launch_file(&entry.path),
            other => Err(format!("unsupported search result type: {other}")),
        };

        if let Err(error) = result {
            eprintln!("NEXA search open error: {error}");
            std::process::exit(2);
        }
        return;
    }

    // Fallback: command execution for standalone binary names
    if command_exists(target) {
        let home = home_dir();
        let shell = env::var("SHELL").unwrap_or_else(|_| "/bin/sh".to_string());
        let _ = Command::new(&shell)
            .arg("-c")
            .arg(target)
            .current_dir(&home)
            .process_group(0)
            .spawn();
        return;
    }

    // Fallback: match by desktop app ID, desktop file name, or app name
    if let Ok(entries) = load_index() {
        let clean_target = target.trim_end_matches(".desktop");
        let matched = entries.iter().find(|e| {
            if e.kind != "app" {
                return false;
            }
            let file_stem = Path::new(&e.path)
                .file_stem()
                .and_then(|s| s.to_str())
                .unwrap_or("");
            file_stem == clean_target
                || file_stem == target
                || e.name.eq_ignore_ascii_case(clean_target)
                || e.exec
                    .split_whitespace()
                    .next()
                    .map(|b| b.trim_matches('"').trim_matches('\'').ends_with(clean_target))
                    .unwrap_or(false)
        });

        if let Some(entry) = matched {
            let result = if entry.path.ends_with(".desktop") {
                launch_desktop_file(&entry.path)
            } else {
                let exec_path = PathBuf::from(&entry.exec);
                let entry_path = PathBuf::from(&entry.path);
                let workdir = if entry_path.is_dir() {
                    entry_path
                } else {
                    exec_path
                        .parent()
                        .unwrap_or_else(|| Path::new("/"))
                        .to_path_buf()
                };
                launch_folder_app(&exec_path, &workdir)
            };

            if let Err(error) = result {
                eprintln!("NEXA search open error: {error}");
                std::process::exit(2);
            }
            return;
        }
    }

    eprintln!("NEXA search open error: invalid path or ID '{target}'");
    std::process::exit(2);
}
