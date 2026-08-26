use serde::Serialize;
use std::collections::HashSet;
use std::fs;
use std::io::Write;
use std::path::PathBuf;
use std::process::{Command, Stdio};

// ============================================================
// TYPES
// ============================================================

#[derive(Debug, Serialize)]
pub struct ClipboardEntry {
    pub id: String,
    pub preview: String,
    pub size_bytes: usize,
    pub pinned: bool,

    #[serde(rename = "type")]
    pub entry_type: String,
}

// ============================================================
// COMMAND HELPERS
// ============================================================

fn run_command(
    program: &str,
    args: &[&str],
) -> Result<String, String> {
    let output = Command::new(program)
        .args(args)
        .output()
        .map_err(|e| {
            format!("Failed to run {program}: {e}")
        })?;

    if !output.status.success() {
        return Err(
            String::from_utf8_lossy(
                &output.stderr
            )
            .trim()
            .to_string()
        );
    }

    Ok(
        String::from_utf8_lossy(
            &output.stdout
        )
        .to_string()
    )
}

fn decode_bytes(
    id: &str,
) -> Result<Vec<u8>, String> {
    let output = Command::new("cliphist")
        .args(["decode", id])
        .output()
        .map_err(|e| {
            format!(
                "Failed to decode clipboard entry: {e}"
            )
        })?;

    if !output.status.success() {
        return Err(
            String::from_utf8_lossy(
                &output.stderr
            )
            .trim()
            .to_string()
        );
    }

    Ok(output.stdout)
}

fn decode_text(
    id: &str,
) -> Result<String, String> {
    let bytes = decode_bytes(id)?;

    Ok(
        String::from_utf8_lossy(
            &bytes
        )
        .to_string()
    )
}

// ============================================================
// ENTRY TYPE
// ============================================================

fn is_image_preview(
    preview: &str,
) -> bool {
    let value =
        preview.to_lowercase();

    value.contains("binary data")
        && (
            value.contains("png")
            || value.contains("jpeg")
            || value.contains("jpg")
            || value.contains("webp")
            || value.contains("image")
        )
}

fn entry_type(
    preview: &str,
) -> &'static str {
    if is_image_preview(preview) {
        "image"
    } else {
        "text"
    }
}

// ============================================================
// PIN STORAGE
// ============================================================

fn pins_path() -> PathBuf {
    let home =
        std::env::var("HOME")
            .unwrap_or_else(
                |_| ".".to_string()
            );

    PathBuf::from(home)
        .join(
            ".config/nexa/clipboard-pins.json"
        )
}

fn load_pins() -> HashSet<String> {
    let path = pins_path();

    let Ok(data) =
        fs::read_to_string(path)
    else {
        return HashSet::new();
    };

    serde_json::from_str(&data)
        .unwrap_or_default()
}

fn save_pins(
    pins: &HashSet<String>,
) -> Result<(), String> {
    let path = pins_path();

    if let Some(parent) =
        path.parent()
    {
        fs::create_dir_all(parent)
            .map_err(|e| {
                format!(
                    "Failed to create pin directory: {e}"
                )
            })?;
    }

    let data =
        serde_json::to_string_pretty(
            pins
        )
        .map_err(|e| {
            format!(
                "Failed to serialize pins: {e}"
            )
        })?;

    fs::write(path, data)
        .map_err(|e| {
            format!(
                "Failed to save pins: {e}"
            )
        })
}

// ============================================================
// IMAGE CACHE
// ============================================================

fn image_cache_dir() -> PathBuf {
    let home =
        std::env::var("HOME")
            .unwrap_or_else(
                |_| ".".to_string()
            );

    PathBuf::from(home)
        .join(".cache")
        .join("nexa")
        .join("clipboard")
}

fn image_extension(
    data: &[u8],
) -> &'static str {
    // PNG
    if data.len() >= 8
        && data[0..8]
            == [
                0x89,
                0x50,
                0x4E,
                0x47,
                0x0D,
                0x0A,
                0x1A,
                0x0A,
            ]
    {
        return "png";
    }

    // JPEG
    if data.len() >= 3
        && data[0] == 0xFF
        && data[1] == 0xD8
        && data[2] == 0xFF
    {
        return "jpg";
    }

    // WEBP
    if data.len() >= 12
        && &data[0..4] == b"RIFF"
        && &data[8..12] == b"WEBP"
    {
        return "webp";
    }

    "png"
}

fn cache_image(
    id: &str,
    data: &[u8],
) -> Result<PathBuf, String> {
    let directory =
        image_cache_dir();

    fs::create_dir_all(
        &directory
    )
    .map_err(|e| {
        format!(
            "Failed to create clipboard cache: {e}"
        )
    })?;

    let extension =
        image_extension(data);

    let path =
        directory.join(
            format!(
                "{id}.{extension}"
            )
        );

    fs::write(
        &path,
        data
    )
    .map_err(|e| {
        format!(
            "Failed to cache clipboard image: {e}"
        )
    })?;

    Ok(path)
}

// ============================================================
// BUILD ENTRIES
// ============================================================

fn load_entries() -> Result<
    Vec<ClipboardEntry>,
    String,
> {
    let pins =
        load_pins();

    let raw =
        run_command(
            "cliphist",
            &["list"]
        )?;

    let mut entries =
        Vec::new();

    for line in raw.lines() {
        let mut parts =
            line.splitn(
                2,
                '\t'
            );

        let Some(id) =
            parts.next()
        else {
            continue;
        };

        if id.trim().is_empty() {
            continue;
        }

        let preview =
            parts
                .next()
                .unwrap_or("")
                .to_string();

        let kind =
            entry_type(
                &preview
            );

        let size_bytes =
            decode_bytes(id)
                .map(
                    |bytes| bytes.len()
                )
                .unwrap_or(0);

        entries.push(
            ClipboardEntry {
                id:
                    id.to_string(),

                preview,

                size_bytes,

                pinned:
                    pins.contains(id),

                entry_type:
                    kind.to_string(),
            }
        );
    }

    // --------------------------------------------------------
    // PINNED FIRST
    //
    // Within pinned and normal groups:
    // larger cliphist ID = newer
    // --------------------------------------------------------

    entries.sort_by(
        |a, b| {
            if a.pinned
                != b.pinned
            {
                return b
                    .pinned
                    .cmp(
                        &a.pinned
                    );
            }

            let a_id =
                a.id
                    .parse::<u64>()
                    .unwrap_or(0);

            let b_id =
                b.id
                    .parse::<u64>()
                    .unwrap_or(0);

            b_id.cmp(
                &a_id
            )
        }
    );

    Ok(entries)
}

// ============================================================
// LIST
// ============================================================

pub fn list() {
    match load_entries() {
        Ok(entries) => {
            println!(
                "{}",
                serde_json::to_string(
                    &entries
                )
                .unwrap_or_else(
                    |_| "[]".to_string()
                )
            );
        }

        Err(error) => {
            eprintln!("{error}");
        }
    }
}

// ============================================================
// SEARCH
// ============================================================

pub fn search(
    query: &str,
) {
    let query =
        query.to_lowercase();

    match load_entries() {
        Ok(entries) => {
            let filtered:
                Vec<ClipboardEntry> =
                entries
                    .into_iter()
                    .filter(
                        |entry| {
                            if entry
                                .preview
                                .to_lowercase()
                                .contains(
                                    &query
                                )
                            {
                                return true;
                            }

                            if entry
                                .entry_type
                                == "image"
                            {
                                return query
                                    .contains(
                                        "image"
                                    )
                                    || query
                                        .contains(
                                            "png"
                                        )
                                    || query
                                        .contains(
                                            "screenshot"
                                        );
                            }

                            decode_text(
                                &entry.id
                            )
                            .unwrap_or_default()
                            .to_lowercase()
                            .contains(
                                &query
                            )
                        }
                    )
                    .collect();

            println!(
                "{}",
                serde_json::to_string(
                    &filtered
                )
                .unwrap_or_else(
                    |_| "[]".to_string()
                )
            );
        }

        Err(error) => {
            eprintln!("{error}");
        }
    }
}

// ============================================================
// GET
// ============================================================

pub fn get(
    id: &str,
) {
    let raw =
        match run_command(
            "cliphist",
            &["list"]
        ) {
            Ok(value) =>
                value,

            Err(error) => {
                eprintln!(
                    "{error}"
                );
                return;
            }
        };

    let target =
        raw.lines()
            .find(
                |line| {
                    line
                        .split('\t')
                        .next()
                        .map(
                            |entry_id| {
                                entry_id
                                    == id
                            }
                        )
                        .unwrap_or(
                            false
                        )
                }
            );

    let Some(target) =
        target
    else {
        eprintln!(
            "Clipboard entry not found"
        );
        return;
    };

    let preview =
        target
            .splitn(
                2,
                '\t'
            )
            .nth(1)
            .unwrap_or("");

    let kind =
        entry_type(
            preview
        );

    let bytes =
        match decode_bytes(id) {
            Ok(bytes) =>
                bytes,

            Err(error) => {
                eprintln!(
                    "{error}"
                );
                return;
            }
        };

    if kind == "image" {
        match cache_image(
            id,
            &bytes
        ) {
            Ok(path) => {
                let path_string =
                    path
                        .to_string_lossy()
                        .to_string();

                let source =
                    format!(
                        "file://{}",
                        path_string
                    );

                println!(
                    "{}",
                    serde_json::json!({
                        "id": id,
                        "type": "image",
                        "size_bytes": bytes.len(),
                        "path": path_string,
                        "source": source
                    })
                );
            }

            Err(error) => {
                eprintln!(
                    "{error}"
                );
            }
        }

        return;
    }

    let content =
        String::from_utf8_lossy(
            &bytes
        )
        .to_string();

    println!(
        "{}",
        serde_json::json!({
            "id": id,
            "type": "text",
            "content": content,
            "size_bytes": bytes.len()
        })
    );
}

// ============================================================
// COPY
// ============================================================

pub fn copy(
    id: &str,
) {
    let mut decode =
        match Command::new(
            "cliphist"
        )
        .args([
            "decode",
            id
        ])
        .stdout(
            Stdio::piped()
        )
        .spawn()
        {
            Ok(child) =>
                child,

            Err(error) => {
                eprintln!(
                    "Failed to decode clipboard item: {error}"
                );

                return;
            }
        };

    let Some(stdout) =
        decode.stdout.take()
    else {
        eprintln!(
            "Failed to read clipboard data"
        );

        return;
    };

    let result =
        Command::new(
            "wl-copy"
        )
        .stdin(stdout)
        .status();

    let _ =
        decode.wait();

    match result {
        Ok(status)
            if status.success() =>
        {
            println!(
                "{}",
                serde_json::json!({
                    "success": true,
                    "id": id
                })
            );
        }

        Ok(_) => {
            eprintln!(
                "wl-copy failed"
            );
        }

        Err(error) => {
            eprintln!(
                "Failed to run wl-copy: {error}"
            );
        }
    }
}

// ============================================================
// PIN
// ============================================================

pub fn pin(
    id: &str,
) {
    let mut pins =
        load_pins();

    pins.insert(
        id.to_string()
    );

    match save_pins(
        &pins
    ) {
        Ok(_) => {
            println!(
                "{}",
                serde_json::json!({
                    "success": true,
                    "id": id,
                    "pinned": true
                })
            );
        }

        Err(error) => {
            eprintln!(
                "{error}"
            );
        }
    }
}

// ============================================================
// UNPIN
// ============================================================

pub fn unpin(
    id: &str,
) {
    let mut pins =
        load_pins();

    pins.remove(id);

    match save_pins(
        &pins
    ) {
        Ok(_) => {
            println!(
                "{}",
                serde_json::json!({
                    "success": true,
                    "id": id,
                    "pinned": false
                })
            );
        }

        Err(error) => {
            eprintln!(
                "{error}"
            );
        }
    }
}

// ============================================================
// DELETE
// ============================================================

pub fn delete(
    id: &str,
) {
    let list =
        match run_command(
            "cliphist",
            &["list"]
        ) {
            Ok(value) =>
                value,

            Err(error) => {
                eprintln!(
                    "{error}"
                );

                return;
            }
        };

    let target =
        list.lines()
            .find(
                |line| {
                    line
                        .split('\t')
                        .next()
                        .map(
                            |entry_id| {
                                entry_id
                                    == id
                            }
                        )
                        .unwrap_or(
                            false
                        )
                }
            );

    let Some(target) =
        target
    else {
        eprintln!(
            "Clipboard entry not found"
        );

        return;
    };

    let mut child =
        match Command::new(
            "cliphist"
        )
        .arg(
            "delete"
        )
        .stdin(
            Stdio::piped()
        )
        .spawn()
        {
            Ok(child) =>
                child,

            Err(error) => {
                eprintln!(
                    "Failed to run cliphist delete: {error}"
                );

                return;
            }
        };

    if let Some(
        mut stdin
    ) = child.stdin.take()
    {
        if let Err(error) =
            writeln!(
                stdin,
                "{target}"
            )
        {
            eprintln!(
                "Failed to send clipboard entry: {error}"
            );

            return;
        }
    }

    match child.wait() {
        Ok(status)
            if status.success() =>
        {
            let mut pins =
                load_pins();

            if pins.remove(id) {
                let _ =
                    save_pins(
                        &pins
                    );
            }

            // remove cached preview if present

            let cache =
                image_cache_dir();

            if let Ok(files) =
                fs::read_dir(
                    &cache
                )
            {
                for file in
                    files.flatten()
                {
                    let name =
                        file
                            .file_name()
                            .to_string_lossy()
                            .to_string();

                    if name.starts_with(
                        &format!(
                            "{id}."
                        )
                    ) {
                        let _ =
                            fs::remove_file(
                                file.path()
                            );
                    }
                }
            }

            println!(
                "{}",
                serde_json::json!({
                    "success": true,
                    "id": id
                })
            );
        }

        Ok(_) => {
            eprintln!(
                "Failed to delete clipboard entry"
            );
        }

        Err(error) => {
            eprintln!(
                "Failed to wait for delete: {error}"
            );
        }
    }
}

// ============================================================
// CLEAR
// ============================================================

pub fn clear() {
    match Command::new(
        "cliphist"
    )
    .arg(
        "wipe"
    )
    .status()
    {
        Ok(status)
            if status.success() =>
        {
            let pin_file =
                pins_path();

            if pin_file.exists() {
                let _ =
                    fs::remove_file(
                        pin_file
                    );
            }

            let cache =
                image_cache_dir();

            if cache.exists() {
                let _ =
                    fs::remove_dir_all(
                        cache
                    );
            }

            println!(
                "{}",
                serde_json::json!({
                    "success": true
                })
            );
        }

        Ok(_) => {
            eprintln!(
                "Failed to clear clipboard history"
            );
        }

        Err(error) => {
            eprintln!(
                "Failed to run cliphist wipe: {error}"
            );
        }
    }
}
