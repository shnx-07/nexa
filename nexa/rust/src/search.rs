use serde::{Deserialize, Serialize};
use std::{
    collections::HashSet,
    env, fs,
    os::unix::{fs::PermissionsExt, process::CommandExt},
    path::{Path, PathBuf},
    process::{Command, Stdio},
    time::SystemTime,
};
use walkdir::{DirEntry, WalkDir};

// ============================================================
// SEARCH ENTRY DEFINITIONS
// ============================================================

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SearchEntry {
    pub id: usize,
    pub kind: String, // "app", "appimage", "file"
    pub name: String,
    pub path: String, // Canonical absolute path
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

#[derive(Debug, Serialize)]
pub struct SearchResult {
    pub id: usize,
    pub kind: String,
    pub name: String,
    pub path: String,
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
    let candidates = [
        home.join("Desktop"),
        home.join("Documents"),
        home.join("Downloads"),
        home.join("Music"),
        home.join("Pictures"),
        home.join("Videos"),
        home.join("Projects"),
    ];

    candidates.into_iter().filter(|p| p.is_dir()).collect()
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

    let description = if !generic_name.is_empty() {
        generic_name.clone()
    } else {
        "Application".to_string()
    };

    Some(SearchEntry {
        id: 0,
        kind: "app".to_string(),
        name,
        path: path.to_string_lossy().to_string(),
        exec,
        icon,
        terminal,
        generic_name,
        keywords,
        description,
    })
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

fn index_appimages(entries: &mut Vec<SearchEntry>, seen_paths: &mut HashSet<String>) {
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

            let path_string = path.to_string_lossy().to_string();
            if !seen_paths.insert(path_string.clone()) {
                continue;
            }

            let name = clean_appimage_name(file_name);

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

            entries.push(SearchEntry {
                id: 0,
                kind: "appimage".to_string(),
                name,
                path: path_string,
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

fn index_applications(entries: &mut Vec<SearchEntry>, seen_paths: &mut HashSet<String>) {
    let mut seen_desktop_keys = HashSet::new();

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

            let key = path
                .file_name()
                .and_then(|v| v.to_str())
                .unwrap_or("")
                .to_lowercase();

            if key.is_empty() || !seen_desktop_keys.insert(key) {
                continue;
            }

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

            let description = if path.is_dir() {
                "Folder".to_string()
            } else if !ext.is_empty() {
                format!("{ext} Document")
            } else {
                "File".to_string()
            };

            entries.push(SearchEntry {
                id: 0,
                kind: "file".to_string(),
                name: name.to_string(),
                path: path_string,
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
// BUILD & CACHE ENGINE
// ============================================================

fn build_index() -> Vec<SearchEntry> {
    let mut entries = Vec::new();
    let mut seen_paths = HashSet::new();

    index_applications(&mut entries, &mut seen_paths);
    index_appimages(&mut entries, &mut seen_paths);
    index_files(&mut entries, &mut seen_paths);

    // Deterministic sorting: Apps -> AppImages -> Files
    entries.sort_by(|a, b| {
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

    for (idx, entry) in entries.iter_mut().enumerate() {
        entry.id = idx;
    }

    entries
}

fn save_index(entries: &[SearchEntry]) -> Result<(), String> {
    fs::create_dir_all(cache_dir())
        .map_err(|e| format!("failed to create cache dir: {e}"))?;

    let json = serde_json::to_string(entries)
        .map_err(|e| format!("failed to serialize search index: {e}"))?;

    fs::write(cache_path(), json)
        .map_err(|e| format!("failed to write search index: {e}"))?;

    Ok(())
}

fn check_app_dirs_newer_than(cache_mtime: SystemTime) -> bool {
    for dir in application_dirs() {
        if let Ok(metadata) = fs::metadata(&dir) {
            if let Ok(mtime) = metadata.modified() {
                if mtime > cache_mtime {
                    return true;
                }
            }
        }
    }
    for dir in appimage_dirs() {
        if let Ok(metadata) = fs::metadata(&dir) {
            if let Ok(mtime) = metadata.modified() {
                if mtime > cache_mtime {
                    return true;
                }
            }
        }
    }
    false
}

fn load_index() -> Result<Vec<SearchEntry>, String> {
    let path = cache_path();

    if !path.is_file() {
        let entries = build_index();
        save_index(&entries)?;
        return Ok(entries);
    }

    let cache_mtime = fs::metadata(&path)
        .and_then(|m| m.modified())
        .unwrap_or(SystemTime::UNIX_EPOCH);

    // If an application directory was modified since the cache was built, re-index immediately!
    if check_app_dirs_newer_than(cache_mtime) {
        let entries = build_index();
        save_index(&entries)?;
        return Ok(entries);
    }

    let content = fs::read_to_string(&path)
        .map_err(|e| format!("failed to read search index: {e}"))?;

    match serde_json::from_str::<Vec<SearchEntry>>(&content) {
        Ok(entries) => Ok(entries),
        Err(_) => {
            let entries = build_index();
            save_index(&entries)?;
            Ok(entries)
        }
    }
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

    // 2. Acronym exact match (e.g. "vsc" -> "Visual Studio Code")
    if !acronym.is_empty() && acronym == norm_query {
        return Some(1050);
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
// PUBLIC COMMANDS: REFRESH & QUERY
// ============================================================

pub fn refresh() {
    let entries = build_index();
    if let Err(error) = save_index(&entries) {
        eprintln!("NEXA search refresh error: {error}");
        std::process::exit(2);
    }

    let output = serde_json::json!({
        "indexed": entries.len(),
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

    let entries = match load_index() {
        Ok(entries) => entries,
        Err(error) => {
            eprintln!("NEXA search query error: {error}");
            std::process::exit(2);
        }
    };

    let mut results: Vec<SearchResult> = entries
        .iter()
        .filter_map(|entry| {
            let score = score_entry(entry, query_str)?;
            Some(SearchResult {
                id: entry.id,
                kind: entry.kind.clone(),
                name: entry.name.clone(),
                path: entry.path.clone(),
                exec: entry.exec.clone(),
                icon: entry.icon.clone(),
                score,
                terminal: entry.terminal,
                description: entry.description.clone(),
            })
        })
        .collect();

    results.sort_by(|a, b| {
        let rank_a = if a.kind == "app" || a.kind == "appimage" { 0 } else { 1 };
        let rank_b = if b.kind == "app" || b.kind == "appimage" { 0 } else { 1 };

        rank_a
            .cmp(&rank_b)
            .then_with(|| b.score.cmp(&a.score))
            .then_with(|| a.name.to_lowercase().cmp(&b.name.to_lowercase()))
    });

    results.truncate(25);

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

    // 1. Primary launcher: gio launch
    if command_exists("gio") {
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

    // 2. Fallback: Parse Exec line and run directly
    let content = fs::read_to_string(desktop_path)
        .map_err(|e| format!("cannot read desktop file: {e}"))?;

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

    let cleaned_exec = clean_desktop_exec(&exec);
    if cleaned_exec.is_empty() {
        return Err(format!("no Exec line found in {path_str}"));
    }

    let final_command = if terminal {
        let term = env::var("TERMINAL").unwrap_or_else(|_| "kitty".to_string());
        let app_name = desktop_path
            .file_stem()
            .and_then(|s| s.to_str())
            .unwrap_or("app")
            .to_lowercase();

        if term.contains("alacritty") {
            format!("{term} --class {app_name} -e {cleaned_exec}")
        } else {
            format!("{term} --class {app_name} {cleaned_exec}")
        }
    } else {
        cleaned_exec
    };

    Command::new("sh")
        .arg("-c")
        .arg(format!("exec {final_command}"))
        .current_dir(workdir)
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .process_group(0)
        .spawn()
        .map(|_| ())
        .map_err(|e| format!("failed to spawn exec command: {e}"))
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

    // If target is directly an existing path
    let target_path = Path::new(target);
    if target_path.exists() {
        let result = if target.ends_with(".desktop") {
            launch_desktop_file(target)
        } else if target.to_lowercase().ends_with(".appimage") {
            launch_appimage(target)
        } else {
            launch_file(target)
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
            "app" => launch_desktop_file(&entry.path),
            "appimage" => launch_appimage(&entry.path),
            "file" => launch_file(&entry.path),
            other => Err(format!("unsupported search result type: {other}")),
        };

        if let Err(error) = result {
            eprintln!("NEXA search open error: {error}");
            std::process::exit(2);
        }
        return;
    }

    eprintln!("NEXA search open error: invalid path or ID '{target}'");
    std::process::exit(2);
}
