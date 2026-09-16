use serde::Serialize;
use std::{
    collections::HashSet,
    env, fs,
    os::unix::{fs::PermissionsExt, process::CommandExt},
    path::PathBuf,
    process::Command,
};

#[derive(Debug, Clone, Serialize)]
pub struct CommandItem {
    pub name: String,
    pub path: String,
    pub score: i32,
}

#[derive(Debug, Serialize)]
pub struct CommandExecResult {
    pub exit_code: i32,
    pub stdout: String,
    pub stderr: String,
}

fn path_dirs() -> Vec<PathBuf> {
    let mut dirs = Vec::new();
    if let Ok(path_var) = env::var("PATH") {
        for p in path_var.split(':') {
            if !p.is_empty() {
                dirs.push(PathBuf::from(p));
            }
        }
    }
    // Ensure common local bin directories are included
    if let Ok(home) = env::var("HOME") {
        let home_bin = PathBuf::from(&home).join(".local").join("bin");
        if !dirs.contains(&home_bin) {
            dirs.push(home_bin);
        }
        let user_bin = PathBuf::from(&home).join("bin");
        if !dirs.contains(&user_bin) {
            dirs.push(user_bin);
        }
    }
    dirs
}

fn is_executable(path: &PathBuf) -> bool {
    if let Ok(metadata) = fs::metadata(path) {
        if metadata.is_file() {
            let permissions = metadata.permissions();
            return permissions.mode() & 0o111 != 0;
        }
    }
    false
}

fn collect_binaries() -> Vec<CommandItem> {
    let mut seen = HashSet::new();
    let mut items = Vec::new();

    for dir in path_dirs() {
        if !dir.is_dir() {
            continue;
        }
        if let Ok(entries) = fs::read_dir(&dir) {
            for entry in entries.flatten() {
                let path = entry.path();
                if let Some(file_name) = path.file_name().and_then(|f| f.to_str()) {
                    if file_name.starts_with('.') {
                        continue;
                    }
                    if seen.insert(file_name.to_string()) && is_executable(&path) {
                        items.push(CommandItem {
                            name: file_name.to_string(),
                            path: path.to_string_lossy().to_string(),
                            score: 0,
                        });
                    }
                }
            }
        }
    }

    items.sort_by(|a, b| a.name.cmp(&b.name));
    items
}

fn score_command(name: &str, query: &str) -> Option<i32> {
    let norm_name = name.to_lowercase();
    let norm_query = query.trim().to_lowercase();

    if norm_query.is_empty() {
        return None;
    }

    // Exact match
    if norm_name == norm_query {
        return Some(1000);
    }

    // Starts with query
    if norm_name.starts_with(&norm_query) {
        let penalty = (norm_name.len().saturating_sub(norm_query.len()) as i32).min(100);
        return Some(900 - penalty);
    }

    // Contains query
    if norm_name.contains(&norm_query) {
        let penalty = (norm_name.len().saturating_sub(norm_query.len()) as i32).min(200);
        return Some(700 - penalty);
    }

    // Fuzzy subsequence match
    let mut q_chars = norm_query.chars();
    let mut current_q = q_chars.next()?;

    for c in norm_name.chars() {
        if c == current_q {
            if let Some(next_c) = q_chars.next() {
                current_q = next_c;
            } else {
                let score = 400 - (norm_name.len().saturating_sub(norm_query.len()) as i32 * 5);
                return if score > 100 { Some(score) } else { None };
            }
        }
    }

    None
}

pub fn query(query_str: &str) {
    let query_str = query_str.trim();
    if query_str.is_empty() {
        println!("[]");
        return;
    }

    let binaries = collect_binaries();
    let mut results = Vec::new();

    for mut item in binaries {
        if let Some(score) = score_command(&item.name, query_str) {
            item.score = score;
            results.push(item);
        }
    }

    results.sort_by(|a, b| b.score.cmp(&a.score).then_with(|| a.name.cmp(&b.name)));
    results.truncate(30);

    match serde_json::to_string(&results) {
        Ok(json) => println!("{json}"),
        Err(err) => {
            eprintln!("Failed to serialize command search results: {err}");
            std::process::exit(2);
        }
    }
}

pub fn run(command: &str) {
    let home = env::var("HOME").unwrap_or_else(|_| "/tmp".to_string());
    let shell = env::var("SHELL").unwrap_or_else(|_| "/bin/sh".to_string());

    let result = Command::new(&shell)
        .arg("-c")
        .arg(command)
        .current_dir(&home)
        .process_group(0)
        .output();

    match result {
        Ok(output) => {
            let response = CommandExecResult {
                exit_code: output.status.code().unwrap_or(-1),
                stdout: String::from_utf8_lossy(&output.stdout).to_string(),
                stderr: String::from_utf8_lossy(&output.stderr).to_string(),
            };

            match serde_json::to_string(&response) {
                Ok(json) => println!("{json}"),
                Err(error) => {
                    eprintln!("Failed to encode command result: {error}");
                    std::process::exit(2);
                }
            }
        }
        Err(error) => {
            eprintln!("Failed to execute command: {error}");
            std::process::exit(2);
        }
    }
}
