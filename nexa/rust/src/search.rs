use serde::{Deserialize, Serialize};
use std::{
    collections::HashSet,
    env,
    fs,
    os::unix::process::CommandExt,
    path::{Path, PathBuf},
    process::Command,
    time::Duration,
};

use walkdir::{DirEntry, WalkDir};


// ============================================================
// SEARCH ENTRY
// ============================================================

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SearchEntry {
    pub id: usize,
    pub kind: String,
    pub name: String,
    pub path: String,
    pub exec: String,
    pub icon: String,
    #[serde(default)]
    pub generic_name: String,
    #[serde(default)]
    pub keywords: String,
}


// ============================================================
// SEARCH RESULT
// ============================================================

#[derive(Debug, Serialize)]
struct SearchResult {
    id: usize,
    kind: String,
    name: String,
    path: String,
    exec: String,
    icon: String,
    score: i32,
}


// ============================================================
// PATHS
// ============================================================

fn home_dir() -> PathBuf {
    env::var("HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|_| PathBuf::from("/tmp"))
}


fn cache_dir() -> PathBuf {
    home_dir()
        .join(".cache")
        .join("nexa")
}


fn cache_path() -> PathBuf {
    cache_dir()
        .join("search-index.json")
}


// ============================================================
// DESKTOP APPLICATION DIRECTORIES
// ============================================================

fn application_dirs() -> Vec<PathBuf> {
    vec![
        PathBuf::from("/usr/share/applications"),
        PathBuf::from("/usr/local/share/applications"),
        home_dir()
            .join(".local")
            .join("share")
            .join("applications"),
    ]
}


// ============================================================
// FILE SEARCH DIRECTORIES
//
// Strictly clean user document/media directories.
// Hidden folders (like ~/.config) are intentionally omitted.
// ============================================================

fn file_dirs() -> Vec<PathBuf> {
    let home = home_dir();

    vec![
        home.join("Desktop"),
        home.join("Documents"),
        home.join("Downloads"),
        home.join("Music"),
        home.join("Pictures"),
        home.join("Videos"),
        home.join("Projects"),
        home.join("Apps_img"),
    ]
}


// ============================================================
// DESKTOP FILE PARSING
// ============================================================

fn parse_desktop_file(path: &Path) -> Option<SearchEntry> {
    let content =
        fs::read_to_string(path)
            .ok()?;

    let mut name = String::new();
    let mut generic_name = String::new();
    let mut keywords = String::new();
    let mut exec = String::new();
    let mut icon = String::new();

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

        if let Some(value) = line.strip_prefix("Name=") {
            if name.is_empty() {
                name = value.trim().to_string();
            }
            continue;
        }

        if let Some(value) = line.strip_prefix("GenericName=") {
            if generic_name.is_empty() {
                generic_name = value.trim().to_string();
            }
            continue;
        }

        if let Some(value) = line.strip_prefix("Keywords=") {
            if keywords.is_empty() {
                keywords = value.trim().to_string();
            }
            continue;
        }

        if let Some(value) = line.strip_prefix("Exec=") {
            if exec.is_empty() {
                exec = value.trim().to_string();
            }
            continue;
        }

        if let Some(value) = line.strip_prefix("Icon=") {
            if icon.is_empty() {
                icon = value.trim().to_string();
            }
            continue;
        }

        if let Some(value) = line.strip_prefix("Hidden=") {
            hidden = value.trim().eq_ignore_ascii_case("true");
            continue;
        }

        if let Some(value) = line.strip_prefix("NoDisplay=") {
            no_display = value.trim().eq_ignore_ascii_case("true");
            continue;
        }
    }

    if hidden || no_display || name.is_empty() {
        return None;
    }

    Some(SearchEntry {
        id: 0,
        kind: "app".to_string(),
        name,
        path: path.to_string_lossy().to_string(),
        exec,
        icon,
        generic_name,
        keywords,
    })
}


// ============================================================
// APPLICATION INDEXING
//
// Follows symlinks so distributions that symlink launchers
// (e.g. Arch Linux LibreOffice) are properly indexed.
// ============================================================

fn index_applications(
    entries: &mut Vec<SearchEntry>,
) {
    let mut seen = HashSet::<String>::new();

    for directory in application_dirs() {
        if !directory.exists() {
            continue;
        }

        for item in WalkDir::new(directory)
            .max_depth(4)
            .follow_links(true)
            .into_iter()
            .filter_map(Result::ok)
        {
            let path = item.path();

            if !path.is_file() {
                continue;
            }

            if path.extension().and_then(|value| value.to_str()) != Some("desktop") {
                continue;
            }

            let Some(entry) = parse_desktop_file(path) else {
                continue;
            };

            // Avoid duplicate desktop files by filename.
            let key = path
                .file_name()
                .and_then(|value| value.to_str())
                .unwrap_or("")
                .to_lowercase();

            if key.is_empty() || !seen.insert(key) {
                continue;
            }

            entries.push(entry);
        }
    }
}


// ============================================================
// FILE FILTERING
//
// Automatically skips any hidden directory (starts with '.')
// or heavy build/cache directories.
// ============================================================

fn should_skip_dir(
    entry: &DirEntry,
) -> bool {
    if !entry.file_type().is_dir() {
        return false;
    }

    let name = entry.file_name().to_string_lossy();

    name.starts_with('.')
        || matches!(
            name.as_ref(),
            "node_modules"
                | "target"
                | "dist"
                | "build"
                | "venv"
                | ".venv"
                | "__pycache__"
                | "Trash"
                | ".Trash"
        )
}


// ============================================================
// FILE INDEXING
// ============================================================

fn index_files(
    entries: &mut Vec<SearchEntry>,
) {
    let mut seen = HashSet::<String>::new();

    for directory in file_dirs() {
        if !directory.exists() {
            continue;
        }

        let walker = WalkDir::new(&directory)
            .follow_links(false)
            .max_depth(6)
            .into_iter()
            .filter_entry(|entry| !should_skip_dir(entry));

        for item in walker.filter_map(Result::ok) {
            let path = item.path();

            // Do not index search root itself.
            if path == directory {
                continue;
            }

            if !path.is_file() && !path.is_dir() {
                continue;
            }

            let Some(name) = path.file_name().and_then(|value| value.to_str()) else {
                continue;
            };

            // Strictly skip any dotfiles or hidden entries.
            if name.is_empty() || name.starts_with('.') {
                continue;
            }

            let path_string = path.to_string_lossy().to_string();

            if !seen.insert(path_string.clone()) {
                continue;
            }

            entries.push(SearchEntry {
                id: 0,
                kind: "file".to_string(),
                name: name.to_string(),
                path: path_string,
                exec: String::new(),
                icon: String::new(),
                generic_name: String::new(),
                keywords: String::new(),
            });
        }
    }
}


// ============================================================
// BUILD INDEX
// ============================================================

fn build_index() -> Vec<SearchEntry> {
    let mut entries = Vec::<SearchEntry>::new();

    index_applications(&mut entries);
    index_files(&mut entries);

    // Stable deterministic order before IDs.
    entries.sort_by(|a, b| {
        let kind_order_a = if a.kind == "app" { 0 } else { 1 };
        let kind_order_b = if b.kind == "app" { 0 } else { 1 };

        kind_order_a
            .cmp(&kind_order_b)
            .then_with(|| a.name.to_lowercase().cmp(&b.name.to_lowercase()))
    });

    for (index, entry) in entries.iter_mut().enumerate() {
        entry.id = index;
    }

    entries
}


// ============================================================
// SAVE INDEX
// ============================================================

fn save_index(
    entries: &[SearchEntry],
) -> Result<(), String> {
    fs::create_dir_all(cache_dir())
        .map_err(|error| format!("failed to create cache directory: {error}"))?;

    let json = serde_json::to_string(entries)
        .map_err(|error| format!("failed to serialize search index: {error}"))?;

    fs::write(cache_path(), json)
        .map_err(|error| format!("failed to write search index: {error}"))?;

    Ok(())
}


// ============================================================
// LOAD INDEX
// ============================================================

fn load_index() -> Result<Vec<SearchEntry>, String> {
    let path = cache_path();

    if !path.exists() {
        let entries = build_index();
        save_index(&entries)?;
        return Ok(entries);
    }

    // Refresh after 5 seconds of inactivity if files changed.
    let should_refresh = match fs::metadata(&path).and_then(|m| m.modified()) {
        Ok(modified) => modified
            .elapsed()
            .map(|age| age > Duration::from_secs(5))
            .unwrap_or(true),
        Err(_) => true,
    };

    if should_refresh {
        let entries = build_index();
        save_index(&entries)?;
        return Ok(entries);
    }

    let content = fs::read_to_string(&path)
        .map_err(|error| format!("failed to read search index: {error}"))?;

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
// STRING & WORD UTILITIES
// ============================================================

fn normalize(value: &str) -> String {
    value.trim().to_lowercase()
}


/// Splits a string into words by whitespace, punctuation, and CamelCase transitions.
/// E.g. "Visual Studio Code" -> ["visual", "studio", "code"]
/// E.g. "LibreOffice Writer" -> ["libre", "office", "writer"]
/// E.g. "QuickShell"         -> ["quick", "shell"]
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


/// Computes the initials / acronym of the words.
/// E.g. ["visual", "studio", "code"] -> "vsc"
fn compute_acronym(words: &[String]) -> String {
    words
        .iter()
        .filter_map(|w| w.chars().next())
        .collect()
}


// ============================================================
// ADVANCED MATCHING & SCORING ENGINE
//
// Matches:
// 1. Exact string match             (1000)
// 2. Acronym / initials exact match (950)   e.g. "vsc" -> "Visual Studio Code", "lo" -> "LibreOffice", "gimp" -> "GNU Image Manipulation Program"
// 3. Multi-word prefix match        (920)   e.g. "vs code" -> "Visual Studio Code", "libre calc" -> "LibreOffice Calc"
// 4. Acronym prefix match           (900)   e.g. "vs" -> "Visual Studio Code"
// 5. String prefix match            (880)   e.g. "fire" -> "Firefox"
// 6. Word-boundary prefix match     (840)   e.g. "calc" -> "LibreOffice Calc", "writer" -> "LibreOffice Writer", "studio" -> "Visual Studio Code"
// 7. Substring contains match       (600)
// 8. Fuzzy subsequence match        (350..550)
// ============================================================

fn score_text(target: &str, query: &str) -> Option<i32> {
    let norm_target = normalize(target);
    let norm_query = normalize(query);

    if norm_query.is_empty() || norm_target.is_empty() {
        return None;
    }

    // 1. Exact match
    if norm_target == norm_query {
        return Some(1000);
    }

    let target_words = extract_words(target);
    let query_words = extract_words(query);
    let acronym = compute_acronym(&target_words);

    // 2. Acronym exact match (e.g. "vsc" == "vsc", "lo" == "lo")
    if !acronym.is_empty() && acronym == norm_query {
        return Some(950);
    }

    // 3. Multi-word prefix / acronym query match (e.g. "vs code" on "Visual Studio Code")
    if query_words.len() > 1 && !target_words.is_empty() {
        let mut t_idx = 0;
        let mut all_matched = true;

        for qw in &query_words {
            let mut matched_word = false;

            while t_idx < target_words.len() {
                let tw = &target_words[t_idx];
                t_idx += 1;

                // Word prefix match
                if tw.starts_with(qw) {
                    matched_word = true;
                    break;
                }

                // Check sub-acronym from current word onward
                let sub_acronym = compute_acronym(&target_words[(t_idx - 1)..]);
                if sub_acronym.starts_with(qw) {
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
            return Some(920);
        }
    }

    // 4. Acronym prefix match (e.g. "vs" on "vsc")
    if !acronym.is_empty() && norm_query.len() >= 2 && acronym.starts_with(&norm_query) {
        return Some(900);
    }

    // 5. String prefix match (e.g. "fire" on "firefox")
    if norm_target.starts_with(&norm_query) {
        let length_penalty = (norm_target.len().saturating_sub(norm_query.len()) as i32).min(50);
        return Some(880 - length_penalty);
    }

    // 6. Word-boundary prefix match (e.g. "calc" on "LibreOffice Calc")
    for tw in &target_words {
        if tw.starts_with(&norm_query) {
            let length_penalty = (tw.len().saturating_sub(norm_query.len()) as i32).min(40);
            return Some(840 - length_penalty);
        }
    }

    // 7. Substring contains match
    if norm_target.contains(&norm_query) {
        let length_penalty = (norm_target.len().saturating_sub(norm_query.len()) as i32).min(80);
        return Some(600 - length_penalty);
    }

    // 8. Strict Compact Fuzzy Subsequence
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

    let mut score = 300;
    score += (max_span.saturating_sub(span) as i32) * 12;
    score += best_consecutive * 18;
    score -= (first as i32) * 5;
    score -= (length_gap as i32) * 3;

    if score < 300 {
        return None;
    }

    Some(score)
}


// ============================================================
// ENTRY SCORING
// ============================================================

fn score_entry(
    entry: &SearchEntry,
    query: &str,
) -> Option<i32> {
    let mut best_score: Option<i32> = None;

    let update_best = |current: &mut Option<i32>, new_score: Option<i32>| {
        if let Some(ns) = new_score {
            *current = Some(current.map_or(ns, |c| c.max(ns)));
        }
    };

    // 1. Primary Name Match
    update_best(&mut best_score, score_text(&entry.name, query));

    // 2. Extra metadata scoring for Applications
    if entry.kind == "app" {
        // GenericName match (e.g. "Spreadsheet", "Text Editor", "Word Processor")
        if !entry.generic_name.is_empty() {
            let gen_score = score_text(&entry.generic_name, query).map(|s| s - 20);
            update_best(&mut best_score, gen_score);
        }

        // Keywords match (e.g. "calc;excel;sheets;" or "word;document;")
        if !entry.keywords.is_empty() {
            let kw_score = score_text(&entry.keywords, query).map(|s| s - 40);
            update_best(&mut best_score, kw_score);
        }

        // Exec binary name (e.g. "code", "libreoffice", "gimp")
        let exec_bin = entry
            .exec
            .split_whitespace()
            .next()
            .and_then(|s| Path::new(s).file_name())
            .and_then(|s| s.to_str())
            .unwrap_or("");

        if !exec_bin.is_empty() {
            let exec_score = score_text(exec_bin, query);
            update_best(&mut best_score, exec_score);
        }

        // Desktop path stem (e.g. "libreoffice-writer", "code", "org.kde.kate")
        let path_stem = Path::new(&entry.path)
            .file_stem()
            .and_then(|s| s.to_str())
            .unwrap_or("");

        if !path_stem.is_empty() {
            let stem_score = score_text(path_stem, query);
            update_best(&mut best_score, stem_score);
        }
    }

    let score = best_score?;

    // Applications receive a +200 ranking bonus so they appear before files.
    let bonus = if entry.kind == "app" { 200 } else { 0 };

    Some(score + bonus)
}


// ============================================================
// REFRESH PUBLIC COMMAND
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


// ============================================================
// QUERY PUBLIC COMMAND
// ============================================================

pub fn query(
    query: &str,
) {
    let query = query.trim();

    if query.is_empty() {
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

    let mut results = entries
        .iter()
        .filter_map(|entry| {
            let score = score_entry(entry, query)?;

            Some(SearchResult {
                id: entry.id,
                kind: entry.kind.clone(),
                name: entry.name.clone(),
                path: entry.path.clone(),
                exec: entry.exec.clone(),
                icon: entry.icon.clone(),
                score,
            })
        })
        .collect::<Vec<_>>();

    results.sort_by(|a, b| {
        let app_a = a.kind == "app";
        let app_b = b.kind == "app";

        app_b
            .cmp(&app_a)
            .then_with(|| b.score.cmp(&a.score))
            .then_with(|| a.name.to_lowercase().cmp(&b.name.to_lowercase()))
    });

    results.truncate(20);

    match serde_json::to_string(&results) {
        Ok(json) => println!("{json}"),
        Err(error) => {
            eprintln!("NEXA search serialization error: {error}");
            std::process::exit(2);
        }
    }
}


// ============================================================
// DESKTOP EXEC CLEANUP
// ============================================================

fn clean_desktop_exec(
    exec: &str,
) -> String {
    let mut cleaned = exec.to_string();

    for code in [
        "%f", "%F", "%u", "%U", "%i", "%c", "%k", "%d", "%D", "%n", "%N", "%v", "%m",
    ] {
        cleaned = cleaned.replace(code, "");
    }

    cleaned = cleaned.replace("%%", "%");

    cleaned
        .split_whitespace()
        .collect::<Vec<_>>()
        .join(" ")
}


// ============================================================
// OPEN APPLICATION
// ============================================================

fn open_application(
    entry: &SearchEntry,
) -> Result<(), String> {
    let command = clean_desktop_exec(&entry.exec);

    if !command.is_empty() {
        match Command::new("sh")
            .arg("-c")
            .arg(format!("exec {command}"))
            .process_group(0)
            .spawn()
        {
            Ok(_) => return Ok(()),
            Err(error) => {
                eprintln!(
                    "NEXA search: Exec launch failed for '{}': {error}; falling back to gtk-launch",
                    entry.name
                );
            }
        }
    }

    let desktop_path = Path::new(&entry.path);
    let desktop_id = desktop_path
        .file_stem()
        .and_then(|v| v.to_str())
        .ok_or_else(|| format!("invalid desktop file: {}", entry.path))?;

    Command::new("gtk-launch")
        .arg(desktop_id)
        .process_group(0)
        .spawn()
        .map_err(|error| format!("failed to launch application '{}': {error}", entry.name))?;

    Ok(())
}


// ============================================================
// OPEN FILE
// ============================================================

fn open_file(
    entry: &SearchEntry,
) -> Result<(), String> {
    Command::new("xdg-open")
        .arg(&entry.path)
        .process_group(0)
        .spawn()
        .map_err(|error| format!("failed to open '{}': {error}", entry.path))?;

    Ok(())
}


// ============================================================
// OPEN PUBLIC COMMAND
// ============================================================

pub fn open(
    id: usize,
) {
    let entries = match load_index() {
        Ok(entries) => entries,
        Err(error) => {
            eprintln!("NEXA search open error: {error}");
            std::process::exit(2);
        }
    };

    let Some(entry) = entries.iter().find(|entry| entry.id == id) else {
        eprintln!("NEXA search open error: result id {id} not found");
        std::process::exit(2);
    };

    let result = match entry.kind.as_str() {
        "app" => open_application(entry),
        "file" => open_file(entry),
        other => Err(format!("unsupported search result type: {other}")),
    };

    if let Err(error) = result {
        eprintln!("NEXA search open error: {error}");
        std::process::exit(2);
    }
}
