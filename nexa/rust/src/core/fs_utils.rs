use std::fs;
use std::io::Write;
use std::path::Path;

/// Atomically writes content to a file by writing to a temporary file in the same
/// directory and then renaming it. This prevents partial reads and file corruption
/// when multiple processes (e.g., Quickshell and nexad) access the file concurrently.
pub fn atomic_write<P: AsRef<Path>, C: AsRef<[u8]>>(path: P, content: C) -> Result<(), String> {
    let path = path.as_ref();
    let parent = path.parent().unwrap_or_else(|| Path::new("."));
    fs::create_dir_all(parent)
        .map_err(|e| format!("Failed to create directory {}: {}", parent.display(), e))?;

    // Create a temporary file in the same directory to guarantee atomic rename across the same filesystem
    let file_stem = path.file_name().and_then(|s| s.to_str()).unwrap_or("tmp");
    let tmp_path = parent.join(format!(".{}.tmp.{}", file_stem, std::process::id()));

    {
        let mut file = fs::File::create(&tmp_path).map_err(|e| {
            format!(
                "Failed to create temporary file {}: {}",
                tmp_path.display(),
                e
            )
        })?;
        file.write_all(content.as_ref())
            .map_err(|e| format!("Failed to write data to {}: {}", tmp_path.display(), e))?;
        file.flush()
            .map_err(|e| format!("Failed to flush {}: {}", tmp_path.display(), e))?;
    }

    fs::rename(&tmp_path, path).map_err(|e| {
        let _ = fs::remove_file(&tmp_path);
        format!(
            "Failed to atomically rename {} to {}: {}",
            tmp_path.display(),
            path.display(),
            e
        )
    })
}
