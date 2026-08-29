use std::{
    env,
    fs,
    path::{Path, PathBuf},
    process::Command,
    time::{SystemTime, UNIX_EPOCH},
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


        // Ensure fast cached thumbnails for all wallpapers
        ensure_thumbnail(
            &path,
            kind
        );


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
// ============================================================
// PRINT WALLPAPER ENTRY
// ============================================================

fn print_wallpaper(
    wallpaper: &Wallpaper,
) {
    let thumb = ensure_thumbnail(&wallpaper.path, wallpaper.kind);
    println!(
        "{}|{}|{}",
        wallpaper.kind,
        wallpaper.path.display(),
        thumb.display()
    );
}


// ============================================================
// UNIVERSAL FAST THUMBNAILS
// ============================================================

fn thumb_cache_dir() -> PathBuf {
    let home =
        env::var("HOME")
            .unwrap_or_else(|_| String::from("."));

    PathBuf::from(home)
        .join(".cache")
        .join("nexa")
        .join("wallpapers")
        .join("thumbs")
}


fn ensure_thumbnail(
    path: &Path,
    kind: &str,
) -> PathBuf {
    let Some(name) =
        path.file_name()
    else {
        return path.to_path_buf();
    };


    let cache_dir =
        thumb_cache_dir();


    let _ = fs::create_dir_all(
        &cache_dir
    );


    let thumbnail =
        cache_dir.join(
            format!(
                "{}.jpg",
                name.to_string_lossy()
            )
        );


    // Already generated.
    if thumbnail.exists() {
        return thumbnail;
    }


    if kind == "video" || kind == "gif" {
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
                    "scale=640:-2",
                    "-q:v",
                    "3",
                    "-y",
                ])
                .arg(&thumbnail)
                .status();
    } else {
        let _ =
            Command::new("ffmpeg")
                .args([
                    "-loglevel",
                    "error",
                    "-i",
                ])
                .arg(path)
                .args([
                    "-vf",
                    "scale=640:-2",
                    "-q:v",
                    "3",
                    "-y",
                ])
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
// APPLY DESKTOP WALLPAPER
// ============================================================

pub fn apply_desktop(
    path: &str,
    monitor: Option<&str>,
) -> Result<(), String> {
    let mut resolved_path = PathBuf::from(path);
    if path.starts_with("~/") {
        if let Ok(home) = env::var("HOME") {
            resolved_path = PathBuf::from(home).join(&path[2..]);
        }
    }

    if let Ok(canonical) = resolved_path.canonicalize() {
        resolved_path = canonical;
    }

    if !resolved_path.is_file() {
        return Err(format!(
            "Wallpaper does not exist: {}",
            resolved_path.display()
        ));
    }

    let kind = classify(&resolved_path).ok_or_else(|| {
        format!(
            "Unsupported wallpaper format: {}",
            resolved_path.display()
        )
    })?;

    let monitor_target = monitor.unwrap_or("*");

    // 1. Stop existing video wallpaper if any
    let _ = Command::new("pkill").arg("-x").arg("mpvpaper").status();

    // 2. Render on display output
    if kind == "image" {
        let transitions = [
            "wipe", "wave", "grow", "center", "any", "outer", "fade", "left", "right", "top", "bottom"
        ];
        let angles = ["0", "45", "90", "135", "180", "225", "270", "315"];

        let nanos = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .map(|d| d.subsec_nanos() as usize)
            .unwrap_or(0);

        let selected_trans = transitions[nanos % transitions.len()];
        let selected_angle = angles[(nanos / 7) % angles.len()];

        let mut cmd = Command::new("awww");
        cmd.arg("img");

        if monitor_target != "*" && monitor_target != "ALL" {
            cmd.args(["-o", monitor_target]);
        }

        cmd.arg(&resolved_path)
            .args([
                "--transition-type", selected_trans,
                "--transition-angle", selected_angle,
                "--transition-duration", "1.2",
                "--transition-fps", "144",
                "--transition-bezier", ".42,0,.58,1",
            ]);

        let status = cmd.status().map_err(|e| format!("Failed to run awww: {e}"))?;
        if !status.success() {
            return Err("awww failed to display wallpaper".to_string());
        }
    } else {
        let target = if monitor_target == "*" { "ALL" } else { monitor_target };
        let _ = Command::new("mpvpaper")
            .args(["-o", "no-audio loop-file=inf", target])
            .arg(&resolved_path)
            .spawn();
    }

    // 3. Determine theme source frame (Matugen requires an image)
    let home = env::var("HOME").unwrap_or_else(|_| String::from("."));
    let mut theme_source_path = resolved_path.clone();

    if kind == "video" || kind == "gif" {
        let thumb_path = ensure_thumbnail(&resolved_path, kind);
        theme_source_path = thumb_path;
    }

    // 4. Save persistent desktop wallpaper config
    let config = desktop_config_path();
    if let Some(parent) = config.parent() {
        let _ = fs::create_dir_all(parent);
    }

    let contents = format!(
        "WALLPAPER={}\nWALLPAPER_TYPE={}\nTHEME_SOURCE={}\nMONITOR={}\n",
        config_escape(&resolved_path.to_string_lossy()),
        kind,
        config_escape(&theme_source_path.to_string_lossy()),
        config_escape(monitor_target)
    );
    let _ = fs::write(&config, contents);

    println!("desktop_wallpaper={}|{}", kind, resolved_path.display());

    // 5. Update ScreenTemp and Apply Matugen Theme (Detached asynchronous child processes)
    let theme_script = PathBuf::from(&home).join(".config/nexa/scripts/theme.sh");
    if theme_script.exists() {
        let _ = Command::new("bash")
            .arg(&theme_script)
            .arg("apply")
            .spawn();
    }

    let nexad_bin = PathBuf::from(&home).join(".config/nexa/rust/target/release/nexad");
    if nexad_bin.exists() {
        let _ = Command::new(&nexad_bin)
            .args(["screenTemp", "wallpaper", &theme_source_path.to_string_lossy()])
            .spawn();
    }

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
