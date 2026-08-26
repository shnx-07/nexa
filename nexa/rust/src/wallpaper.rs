use std::{
    env,
    fs,
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
    let home =
        env::var("HOME")
            .unwrap_or_else(|_| String::from("."));

    PathBuf::from(home)
        .join("Pictures")
        .join("Wallpapers")
}


fn video_thumb_dir() -> PathBuf {
    let home =
        env::var("HOME")
            .unwrap_or_else(|_| String::from("."));

    PathBuf::from(home)
        .join(".cache")
        .join("nexa")
        .join("wallpapers")
        .join("video")
}


// ------------------------------------------------------------
// Desktop wallpaper config
// ------------------------------------------------------------

fn desktop_config_path() -> PathBuf {
    let home =
        env::var("HOME")
            .unwrap_or_else(|_| String::from("."));

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
    let home =
        env::var("HOME")
            .unwrap_or_else(|_| String::from("."));

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
    let extension =
        path
            .extension()?
            .to_string_lossy()
            .to_lowercase();

    match extension.as_str() {
        "png"
        | "jpg"
        | "jpeg"
        | "webp" => {
            Some("image")
        }

        "gif" => {
            Some("gif")
        }

        "mp4"
        | "mkv"
        | "mov"
        | "webm" => {
            Some("video")
        }

        _ => None,
    }
}


// ============================================================
// SCAN WALLPAPER DIRECTORY
// ============================================================

fn scan() -> Vec<Wallpaper> {
    let directory =
        wallpaper_dir();

    let mut wallpapers =
        Vec::new();


    let entries =
        match fs::read_dir(&directory) {
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
        let path =
            entry.path();


        if !path.is_file() {
            continue;
        }


        let Some(kind) =
            classify(&path)
        else {
            continue;
        };


        // Video cards use cached thumbnails.
        if kind == "video" {
            ensure_video_thumbnail(
                &path
            );
        }


        let name =
            path
                .file_name()
                .map(|name| {
                    name
                        .to_string_lossy()
                        .to_string()
                })
                .unwrap_or_default();


        wallpapers.push(
            Wallpaper {
                kind,
                path,
                name,
            }
        );
    }


    wallpapers.sort_by(
        |a, b| {
            a.name
                .to_lowercase()
                .cmp(
                    &b.name.to_lowercase()
                )
        }
    );


    wallpapers
}


// ============================================================
// PRINT WALLPAPER ENTRY
// ============================================================

fn print_wallpaper(
    wallpaper: &Wallpaper,
) {
    println!(
        "{}|{}",
        wallpaper.kind,
        wallpaper.path.display()
    );
}


// ============================================================
// VIDEO THUMBNAILS
// ============================================================

fn ensure_video_thumbnail(
    path: &Path,
) {
    let Some(name) =
        path.file_name()
    else {
        return;
    };


    let cache_dir =
        video_thumb_dir();


    if fs::create_dir_all(
        &cache_dir
    )
    .is_err()
    {
        return;
    }


    let thumbnail =
        cache_dir.join(
            format!(
                "{}.jpg",
                name.to_string_lossy()
            )
        );


    // Already generated.
    if thumbnail.exists() {
        return;
    }


    let _ =
        Command::new("ffmpeg")
            .args([
                "-loglevel",
                "error",
                "-ss",
                "1",
                "-i",
            ])
            .arg(path)
            .args([
                "-frames:v",
                "1",
                "-vf",
                "scale=960:-2",
                "-q:v",
                "3",
                "-y",
            ])
            .arg(&thumbnail)
            .status();
}


// ============================================================
// WALLPAPER LIST
// ============================================================

pub fn print_list() {
    for wallpaper in scan() {
        print_wallpaper(
            &wallpaper
        );
    }
}


// ============================================================
// WALLPAPER SEARCH
// ============================================================

pub fn print_search(
    query: &str,
) {
    let query =
        query
            .trim()
            .to_lowercase();


    for wallpaper in scan() {
        if query.is_empty()
            || wallpaper
                .name
                .to_lowercase()
                .contains(&query)
        {
            print_wallpaper(
                &wallpaper
            );
        }
    }
}


// ============================================================
// WALLPAPER REFRESH
// ============================================================

pub fn refresh() {
    let wallpapers =
        scan();

    println!(
        "indexed={}",
        wallpapers.len()
    );
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

pub fn set_lock(
    path: &str,
) -> Result<(), String> {
    let path =
        PathBuf::from(path);


    // --------------------------------------------------------
    // Validate file
    // --------------------------------------------------------

    if !path.is_file() {
        return Err(
            format!(
                "Lock wallpaper does not exist: {}",
                path.display()
            )
        );
    }


    // --------------------------------------------------------
    // Detect media type
    // --------------------------------------------------------

    let kind =
        classify(&path)
            .ok_or_else(|| {
                format!(
                    "Unsupported lock wallpaper: {}",
                    path.display()
                )
            })?;


    // --------------------------------------------------------
    // Config destination
    // --------------------------------------------------------

    let config =
        lock_config_path();


    if let Some(parent) =
        config.parent()
    {
        fs::create_dir_all(
            parent
        )
        .map_err(
            |error| {
                format!(
                    "Failed to create lockscreen config directory: {}",
                    error
                )
            }
        )?;
    }


    // --------------------------------------------------------
    // Save lock-screen state
    // --------------------------------------------------------

    let contents =
        format!(
            "WALLPAPER={}\nWALLPAPER_TYPE={}\n",
            config_escape(
                &path.to_string_lossy()
            ),
            kind
        );


    fs::write(
        &config,
        contents
    )
    .map_err(
        |error| {
            format!(
                "Failed to save lock wallpaper: {}",
                error
            )
        }
    )?;


    println!(
        "lock_wallpaper={}|{}",
        kind,
        path.display()
    );


    Ok(())
}


// ============================================================
// LOCK WALLPAPER INFO
// ============================================================

pub fn print_lock_info()
    -> Result<(), String>
{
    let lock_config =
        lock_config_path();


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
        let contents =
            fs::read_to_string(
                &lock_config
            )
            .map_err(
                |error| {
                    format!(
                        "Failed to read lockscreen config: {}",
                        error
                    )
                }
            )?;


        let (
            lock_path,
            lock_type,
        ) =
            parse_wallpaper_config(
                &contents
            );


        if !lock_path.is_empty() {
            println!(
                "{}|{}",
                lock_type,
                lock_path
            );

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

    let desktop_config =
        desktop_config_path();


    let contents =
        fs::read_to_string(
            &desktop_config
        )
        .map_err(
            |error| {
                format!(
                    "Failed to read desktop wallpaper config: {}",
                    error
                )
            }
        )?;


    let (
        desktop_path,
        desktop_type,
    ) =
        parse_wallpaper_config(
            &contents
        );


    if desktop_path.is_empty() {
        return Err(
            "Desktop wallpaper is not configured"
                .to_string()
        );
    }


    println!(
        "{}|{}",
        desktop_type,
        desktop_path
    );


    Ok(())
}


// ============================================================
// CONFIG PARSER
// ============================================================

fn parse_wallpaper_config(
    contents: &str,
) -> (String, String) {
    let mut path =
        String::new();

    let mut kind =
        String::new();


    for line in contents.lines() {
        if let Some(value) =
            line.strip_prefix(
                "WALLPAPER="
            )
        {
            path =
                config_unescape(
                    value
                );
        }


        if let Some(value) =
            line.strip_prefix(
                "WALLPAPER_TYPE="
            )
        {
            kind =
                config_unescape(
                    value
                );
        }
    }


    (
        path,
        kind,
    )
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

fn config_escape(
    value: &str,
) -> String {
    let mut escaped =
        String::new();


    for character in value.chars() {
        match character {
            '\\'
            | ' '
            | '\t'
            | '\''
            | '"'
            | '$'
            | '`' => {
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

fn config_unescape(
    value: &str,
) -> String {
    let value =
        value.trim();


    // --------------------------------------------------------
    // Simple quoted value
    // --------------------------------------------------------

    if value.len() >= 2 {
        if (
            value.starts_with('"')
            && value.ends_with('"')
        )
            || (
                value.starts_with('\'')
                && value.ends_with('\'')
            )
        {
            return value[
                1..value.len() - 1
            ]
            .to_string();
        }
    }


    // --------------------------------------------------------
    // Backslash escaped value
    // --------------------------------------------------------

    let mut result =
        String::new();

    let mut characters =
        value.chars();


    while let Some(character) =
        characters.next()
    {
        if character == '\\' {
            if let Some(next) =
                characters.next()
            {
                result.push(next);
            }
        } else {
            result.push(character);
        }
    }


    result
}
