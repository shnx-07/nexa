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

        // NEXA / user application locations.
        //
        // Keep these explicit instead of recursively indexing all of $HOME,
        // which would make refreshes much heavier and fill Search with noise.
        home.join("Apps_img"),
        home.join(".config"),
    ]
}


// ============================================================
// DESKTOP FILE PARSING
// ============================================================

fn parse_desktop_file(path: &Path) -> Option<SearchEntry> {
    let content =
        fs::read_to_string(path)
            .ok()?;


    let mut name =
        String::new();

    let mut exec =
        String::new();

    let mut icon =
        String::new();

    let mut hidden = false;
    let mut no_display = false;

    let mut in_desktop_entry = false;


    for raw_line in content.lines() {
        let line =
            raw_line.trim();


        if line.starts_with('[') {
            in_desktop_entry =
                line == "[Desktop Entry]";

            continue;
        }


        if !in_desktop_entry {
            continue;
        }


        if let Some(value) =
            line.strip_prefix("Name=")
        {
            if name.is_empty() {
                name =
                    value.trim().to_string();
            }

            continue;
        }


        if let Some(value) =
            line.strip_prefix("Exec=")
        {
            if exec.is_empty() {
                exec =
                    value.trim().to_string();
            }

            continue;
        }


        if let Some(value) =
            line.strip_prefix("Icon=")
        {
            if icon.is_empty() {
                icon =
                    value.trim().to_string();
            }

            continue;
        }


        if let Some(value) =
            line.strip_prefix("Hidden=")
        {
            hidden =
                value.trim()
                    .eq_ignore_ascii_case("true");

            continue;
        }


        if let Some(value) =
            line.strip_prefix("NoDisplay=")
        {
            no_display =
                value.trim()
                    .eq_ignore_ascii_case("true");

            continue;
        }
    }


    if hidden || no_display {
        return None;
    }


    if name.is_empty() {
        return None;
    }


    Some(
        SearchEntry {
            id: 0,

            kind:
                "app".to_string(),

            name,

            path:
                path.to_string_lossy()
                    .to_string(),

            exec,

            icon,
        }
    )
}


// ============================================================
// APPLICATION INDEXING
// ============================================================

fn index_applications(
    entries: &mut Vec<SearchEntry>,
) {
    let mut seen =
        HashSet::<String>::new();


    for directory in application_dirs() {
        if !directory.exists() {
            continue;
        }


        for item in WalkDir::new(directory)
            .max_depth(3)
            .follow_links(false)
            .into_iter()
            .filter_map(Result::ok)
        {
            let path =
                item.path();


            if !item.file_type().is_file() {
                continue;
            }


            if path.extension()
                .and_then(|value| value.to_str())
                != Some("desktop")
            {
                continue;
            }


            let Some(entry) =
                parse_desktop_file(path)
            else {
                continue;
            };


            // Avoid duplicate desktop files.
            let key =
                path.file_name()
                    .and_then(|value| value.to_str())
                    .unwrap_or("")
                    .to_lowercase();


            if key.is_empty()
                || !seen.insert(key)
            {
                continue;
            }


            entries.push(entry);
        }
    }
}


// ============================================================
// FILE FILTERING
// ============================================================

fn should_skip_dir(
    entry: &DirEntry,
) -> bool {
    if !entry.file_type().is_dir() {
        return false;
    }


    let name =
        entry.file_name()
            .to_string_lossy();


    matches!(
        name.as_ref(),
        ".cache"
            | ".git"
            | ".Trash"
            | "Trash"
            | "node_modules"
            | "target"
    )
}


// ============================================================
// FILE INDEXING
// ============================================================

fn index_files(
    entries: &mut Vec<SearchEntry>,
) {
    let mut seen =
        HashSet::<String>::new();


    for directory in file_dirs() {
        if !directory.exists() {
            continue;
        }


        let walker =
            WalkDir::new(&directory)
                .follow_links(false)
                .max_depth(8)
                .into_iter()
                .filter_entry(
                    |entry| !should_skip_dir(entry)
                );


        for item in walker.filter_map(Result::ok) {
            let path =
                item.path();

            // Do not index the search root itself. Index its contents.
            if path == directory {
                continue;
            }

            // Search supports normal files and directories. Directories are
            // intentionally stored as kind "file" because open_file() already
            // uses xdg-open, which correctly opens both files and folders.
            if !item.file_type().is_file()
                && !item.file_type().is_dir()
            {
                continue;
            }


            let Some(name) =
                path.file_name()
                    .and_then(|value| value.to_str())
            else {
                continue;
            };


            if name.is_empty()
                || name.starts_with('.')
            {
                continue;
            }


            let path_string =
                path.to_string_lossy()
                    .to_string();


            if !seen.insert(
                path_string.clone()
            ) {
                continue;
            }


            entries.push(
                SearchEntry {
                    id: 0,

                    kind:
                        "file".to_string(),

                    name:
                        name.to_string(),

                    path:
                        path_string,

                    exec:
                        String::new(),

                    icon:
                        String::new(),
                }
            );
        }
    }
}


// ============================================================
// BUILD INDEX
// ============================================================

fn build_index() -> Vec<SearchEntry> {
    let mut entries =
        Vec::<SearchEntry>::new();


    index_applications(
        &mut entries,
    );

    index_files(
        &mut entries,
    );


    // Stable deterministic order before IDs.
    entries.sort_by(
        |a, b| {
            let kind_order_a =
                if a.kind == "app" {
                    0
                } else {
                    1
                };

            let kind_order_b =
                if b.kind == "app" {
                    0
                } else {
                    1
                };


            kind_order_a
                .cmp(&kind_order_b)
                .then_with(
                    || {
                        a.name
                            .to_lowercase()
                            .cmp(
                                &b.name
                                    .to_lowercase()
                            )
                    }
                )
        }
    );


    for (
        index,
        entry,
    ) in entries.iter_mut().enumerate()
    {
        entry.id =
            index;
    }


    entries
}


// ============================================================
// SAVE INDEX
// ============================================================

fn save_index(
    entries: &[SearchEntry],
) -> Result<(), String> {
    fs::create_dir_all(
        cache_dir()
    )
    .map_err(
        |error| {
            format!(
                "failed to create cache directory: {error}"
            )
        }
    )?;


    let json =
        serde_json::to_string(entries)
            .map_err(
                |error| {
                    format!(
                        "failed to serialize search index: {error}"
                    )
                }
            )?;


    fs::write(
        cache_path(),
        json,
    )
    .map_err(
        |error| {
            format!(
                "failed to write search index: {error}"
            )
        }
    )?;


    Ok(())
}


// ============================================================
// LOAD INDEX
// ============================================================

fn load_index() -> Result<Vec<SearchEntry>, String> {
    let path =
        cache_path();


    // --------------------------------------------------------
    // Rebuild when index does not exist.
    // --------------------------------------------------------

    if !path.exists() {
        let entries =
            build_index();


        save_index(
            &entries,
        )?;


        return Ok(entries);
    }


    // --------------------------------------------------------
    // Automatic refresh.
    //
    // nexad is invoked repeatedly by Search, so we don't want
    // to rebuild on every keystroke.
    //
    // A short cache lifetime gives newly installed apps/files
    // time to appear while keeping normal searches fast.
    // --------------------------------------------------------

    let should_refresh =
        match fs::metadata(&path)
            .and_then(
                |metadata| metadata.modified()
            )
        {
            Ok(modified) => {
                modified
                    .elapsed()
                    .map(
                        |age| {
                            age >
                            Duration::from_secs(5)
                        }
                    )
                    .unwrap_or(true)
            }

            Err(_) => true,
        };


    if should_refresh {
        let entries =
            build_index();


        save_index(
            &entries,
        )?;


        return Ok(entries);
    }


    // --------------------------------------------------------
    // Normal cached read.
    // --------------------------------------------------------

    let content =
        fs::read_to_string(
            &path,
        )
        .map_err(
            |error| {
                format!(
                    "failed to read search index: {error}"
                )
            }
        )?;


    // --------------------------------------------------------
    // If cache somehow becomes malformed, rebuild instead of
    // killing Search completely.
    // --------------------------------------------------------

    match serde_json::from_str::<Vec<SearchEntry>>(
        &content,
    ) {
        Ok(entries) =>
            Ok(entries),

        Err(_) => {
            let entries =
                build_index();


            save_index(
                &entries,
            )?;


            Ok(entries)
        }
    }
}

// ============================================================
// NORMALIZE
// ============================================================

fn normalize(
    value: &str,
) -> String {
    value
        .trim()
        .to_lowercase()
}


// ============================================================
// FUZZY MATCH
//
// Rules:
//
// exact       = 1000
// prefix      = 800
// substring   = 600
// fuzzy       = lower
//
// Fuzzy matching is deliberately strict.
// We do NOT want random long filenames appearing just because
// letters happen to occur somewhere in the same order.
// ============================================================

fn score_match(
    name: &str,
    query: &str,
) -> Option<i32> {
    let name =
        normalize(name);

    let query =
        normalize(query);


    if query.is_empty() {
        return None;
    }


    if name == query {
        return Some(1000);
    }


    if name.starts_with(&query) {
        return Some(800);
    }


    if name.contains(&query) {
        return Some(600);
    }


    // --------------------------------------------------------
    // FUZZY SUBSEQUENCE MATCH
    // --------------------------------------------------------

    let name_chars:
        Vec<char> =
        name.chars().collect();

    let query_chars:
        Vec<char> =
        query.chars().collect();


    if query_chars.len() < 3 {
        return None;
    }


    // Long unrelated names should not become fuzzy matches.
    let length_gap =
        name_chars.len()
            .saturating_sub(
                query_chars.len()
            );


    if length_gap > 12 {
        return None;
    }


    let mut query_index =
        0usize;

    let mut first_match:
        Option<usize> =
        None;

    let mut last_match:
        Option<usize> =
        None;

    let mut consecutive =
        0i32;

    let mut best_consecutive =
        0i32;


    for (
        index,
        ch,
    ) in name_chars.iter().enumerate()
    {
        if query_index
            >= query_chars.len()
        {
            break;
        }


        if *ch
            == query_chars[query_index]
        {
            if first_match.is_none() {
                first_match =
                    Some(index);
            }


            if let Some(previous) =
                last_match
            {
                if index
                    == previous + 1
                {
                    consecutive += 1;
                } else {
                    consecutive = 1;
                }
            } else {
                consecutive = 1;
            }


            best_consecutive =
                best_consecutive.max(
                    consecutive
                );


            last_match =
                Some(index);


            query_index +=
                1;
        }
    }


    // Query wasn't fully matched.
    if query_index
        != query_chars.len()
    {
        return None;
    }


    let Some(first) =
        first_match
    else {
        return None;
    };


    let Some(last) =
        last_match
    else {
        return None;
    };


    let span =
        last
            .saturating_sub(first)
            + 1;


    // A fuzzy match should remain reasonably compact.
    //
    // Example:
    //
    // firefox
    // f i r e
    //
    // is useful.
    //
    // some-filename-with-f...i...r...e
    //
    // should usually disappear.
    let max_span =
        query_chars.len() + 6;


    if span > max_span {
        return None;
    }


    // Require at least some adjacent letters.
    if best_consecutive < 2 {
        return None;
    }


    // Base fuzzy score.
    let mut score =
        300;


    // Reward compact matches.
    score +=
        (
            max_span
                .saturating_sub(span)
            as i32
        ) * 12;


    // Reward consecutive letters.
    score +=
        best_consecutive * 18;


    // Reward matches near the beginning.
    score -=
        (first as i32) * 5;


    // Penalize long names.
    score -=
        (length_gap as i32) * 3;


    if score < 300 {
        return None;
    }


    Some(score)
}


// ============================================================
// ENTRY SCORE
// ============================================================

fn score_entry(
    entry: &SearchEntry,
    query: &str,
) -> Option<i32> {
    // Score against the human-readable name.
    let name_score = score_match(&entry.name, query);

    // For apps, also score against the exec binary name and the
    // desktop file stem (e.g. "google-chrome-stable", "google-chrome")
    // so that typing a binary-style keyword like "chrome" still finds
    // the application even when its display name starts differently.
    let extra_score: Option<i32> = if entry.kind == "app" {
        let exec_bin = entry
            .exec
            .split_whitespace()
            .next()
            .and_then(|s| std::path::Path::new(s).file_name())
            .and_then(|s| s.to_str())
            .unwrap_or("");

        let path_stem = std::path::Path::new(&entry.path)
            .file_stem()
            .and_then(|s| s.to_str())
            .unwrap_or("");

        [exec_bin, path_stem]
            .iter()
            .filter(|s| !s.is_empty())
            .filter_map(|s| score_match(s, query))
            .max()
    } else {
        None
    };

    let base = match (name_score, extra_score) {
        (Some(n), Some(e)) => n.max(e),
        (Some(n), None)    => n,
        (None,    Some(e)) => e,
        (None,    None)    => return None,
    };

    // Apps get a large bonus so they are not buried under file-tree
    // noise from indexed directories like ~/.config/google-chrome/.
    let bonus = if entry.kind == "app" { 150 } else { 0 };

    Some(base + bonus)
}


// ============================================================
// REFRESH PUBLIC COMMAND
// ============================================================

pub fn refresh() {
    let entries =
        build_index();


    if let Err(error) =
        save_index(
            &entries,
        )
    {
        eprintln!(
            "NEXA search refresh error: {error}"
        );

        std::process::exit(2);
    }


    let output =
        serde_json::json!({
            "indexed": entries.len(),
            "cache": cache_path()
                .to_string_lossy()
                .to_string()
        });


    println!("{output}");
}


// ============================================================
// QUERY PUBLIC COMMAND
// ============================================================

pub fn query(
    query: &str,
) {
    let query =
        query.trim();


    if query.is_empty() {
        println!("[]");
        return;
    }


    let entries =
        match load_index() {
            Ok(entries) =>
                entries,

            Err(error) => {
                eprintln!(
                    "NEXA search query error: {error}"
                );

                std::process::exit(2);
            }
        };


    let mut results =
        entries
            .iter()
            .filter_map(
                |entry| {
                    let score =
                        score_entry(
                            entry,
                            query,
                        )?;


                    Some(
                        SearchResult {
                            id:
                                entry.id,

                            kind:
                                entry.kind.clone(),

                            name:
                                entry.name.clone(),

                            path:
                                entry.path.clone(),

                            exec:
                                entry.exec.clone(),

                            icon:
                                entry.icon.clone(),

                            score,
                        }
                    )
                }
            )
            .collect::<Vec<_>>();


    results.sort_by(
        |a, b| {
            // Apps always appear before files.
            // Within each group, sort by score descending then name.
            let app_a = a.kind == "app";
            let app_b = b.kind == "app";

            app_b
                .cmp(&app_a)
                .then_with(|| b.score.cmp(&a.score))
                .then_with(|| {
                    a.name
                        .to_lowercase()
                        .cmp(&b.name.to_lowercase())
                })
        }
    );


    results.truncate(20);


    match serde_json::to_string(
        &results,
    ) {
        Ok(json) =>
            println!("{json}"),

        Err(error) => {
            eprintln!(
                "NEXA search serialization error: {error}"
            );

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
    let mut cleaned =
        exec.to_string();


    // Desktop Entry field codes.
    //
    // Search launches applications without supplying files,
    // URLs, icons, translated names, etc., so remove them.
    //
    // Common values:
    // %f %F -> file/files
    // %u %U -> URL/URLs
    // %i    -> icon
    // %c    -> application name
    // %k    -> desktop file path

    for code in [
        "%f",
        "%F",
        "%u",
        "%U",
        "%i",
        "%c",
        "%k",
        "%d",
        "%D",
        "%n",
        "%N",
        "%v",
        "%m",
    ] {
        cleaned =
            cleaned.replace(
                code,
                "",
            );
    }


    // %% represents a literal percent sign.
    cleaned =
        cleaned.replace(
            "%%",
            "%",
        );


    // Collapse whitespace left behind by removed field codes.
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

    // --------------------------------------------------------
    // Prefer the actual Exec= command from the desktop entry.
    //
    // This matches normal application launchers more closely
    // than relying solely on gtk-launch.
    // --------------------------------------------------------

    let command =
        clean_desktop_exec(
            &entry.exec,
        );


    if !command.is_empty() {

        match Command::new(
            "sh",
        )
        .arg("-c")
        .arg(
            format!(
                "exec {command}"
            )
        )
        // Detach from Quickshell's process group so the launched
        // app survives a Quickshell restart.
        .process_group(0)
        .spawn()
        {
            Ok(_) => {
                return Ok(());
            }

            Err(error) => {
                eprintln!(
                    "NEXA search: Exec launch failed for '{}': {error}; falling back to gtk-launch",
                    entry.name
                );
            }
        }
    }


    // --------------------------------------------------------
    // Fallback: gtk-launch
    // --------------------------------------------------------

    let desktop_path =
        Path::new(
            &entry.path,
        );


    let desktop_id =
        desktop_path
            .file_stem()
            .and_then(
                |value| value.to_str()
            )
            .ok_or_else(
                || {
                    format!(
                        "invalid desktop file: {}",
                        entry.path
                    )
                }
            )?;


    Command::new(
        "gtk-launch",
    )
    .arg(
        desktop_id,
    )
    // Detach from Quickshell's process group.
    .process_group(0)
    .spawn()
    .map_err(
        |error| {
            format!(
                "failed to launch application '{}': {error}",
                entry.name
            )
        }
    )?;


    Ok(())
}


// ============================================================
// OPEN FILE
// ============================================================

fn open_file(
    entry: &SearchEntry,
) -> Result<(), String> {
    Command::new(
        "xdg-open",
    )
    .arg(
        &entry.path,
    )
    // Detach from Quickshell's process group.
    .process_group(0)
    .spawn()
    .map_err(
        |error| {
            format!(
                "failed to open '{}': {error}",
                entry.path
            )
        }
    )?;


    Ok(())
}


// ============================================================
// OPEN PUBLIC COMMAND
// ============================================================

pub fn open(
    id: usize,
) {
    let entries =
        match load_index() {
            Ok(entries) =>
                entries,

            Err(error) => {
                eprintln!(
                    "NEXA search open error: {error}"
                );

                std::process::exit(2);
            }
        };


    let Some(entry) =
        entries
            .iter()
            .find(
                |entry| entry.id == id
            )
    else {
        eprintln!(
            "NEXA search open error: result id {id} not found"
        );

        std::process::exit(2);
    };


    let result =
        match entry.kind.as_str() {
            "app" =>
                open_application(
                    entry,
                ),

            "file" =>
                open_file(
                    entry,
                ),

            other =>
                Err(
                    format!(
                        "unsupported search result type: {other}"
                    )
                ),
        };


    if let Err(error) =
        result
    {
        eprintln!(
            "NEXA search open error: {error}"
        );

        std::process::exit(2);
    }
}

