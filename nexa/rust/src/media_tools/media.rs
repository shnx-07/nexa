use openssl::hash::{hash, MessageDigest};
use serde::{Deserialize, Serialize};
use std::{
    env, fs,
    io::{BufRead, BufReader, Write},
    path::PathBuf,
    process::{Command, Stdio},
    sync::{
        atomic::{AtomicU64, Ordering},
        Arc,
    },
    thread,
    time::Duration,
};

// ============================================================
// DATA MODELS
// ============================================================

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
#[serde(rename_all = "camelCase")]
pub struct MediaState {
    pub player: String,
    pub identity: String,
    pub icon: String,
    pub color: String,
    pub status: String, // "Playing", "Paused", "Stopped"
    pub playing: bool,
    pub title: String,
    pub artist: String,
    pub album: String,
    pub cover: String,
    pub high_res_cover: String,
    pub length: i64,
    pub position: i64,
}

// ============================================================
// CACHE DIRECTORY
// ============================================================

pub fn get_covers_cache_dir() -> PathBuf {
    let home = env::var("HOME").unwrap_or_else(|_| "/tmp".to_string());
    let path = PathBuf::from(home).join(".cache/nexa/covers");
    let _ = fs::create_dir_all(&path);
    path
}

pub fn get_state_file_path() -> PathBuf {
    let runtime_dir = env::var("XDG_RUNTIME_DIR").unwrap_or_else(|_| "/tmp".to_string());
    let nexa_dir = PathBuf::from(runtime_dir).join("nexa");
    let _ = fs::create_dir_all(&nexa_dir);
    nexa_dir.join("media.json")
}

// ============================================================
// HIGH-RES COVER FETCHER (ITUNES API + DISK CACHE)
// ============================================================

pub fn fetch_high_res_cover(title: &str, artist: &str) -> Option<String> {
    let title_clean = title.trim();
    if title_clean.is_empty() || title_clean == "Nothing playing" {
        return None;
    }

    let artist_clean = artist.trim();
    let cache_dir = get_covers_cache_dir();

    // Generate MD5 cache key identical to hashlib.md5
    let key_str = format!("{}|{}", title_clean.to_lowercase(), artist_clean.to_lowercase());
    let md5_bytes = match hash(MessageDigest::md5(), key_str.as_bytes()) {
        Ok(b) => b,
        Err(_) => return None,
    };
    let key_hex = hex::encode(md5_bytes);
    let cached_path = cache_dir.join(format!("{key_hex}.jpg"));

    if cached_path.exists() {
        if let Ok(meta) = fs::metadata(&cached_path) {
            if meta.len() > 1000 {
                return Some(format!("file://{}", cached_path.to_string_lossy()));
            }
        }
    }

    // Prepare candidate search queries
    let clean_title = title_clean
        .split('(')
        .next()
        .unwrap_or(title_clean)
        .split('-')
        .next()
        .unwrap_or(title_clean)
        .trim();

    let clean_artist = if !artist_clean.is_empty() {
        artist_clean
            .split("feat")
            .next()
            .unwrap_or(artist_clean)
            .split('&')
            .next()
            .unwrap_or(artist_clean)
            .split(',')
            .next()
            .unwrap_or(artist_clean)
            .trim()
    } else {
        ""
    };

    let mut queries = Vec::new();
    if !artist_clean.is_empty() {
        queries.push(format!("{title_clean} {artist_clean}"));
        if clean_title != title_clean || clean_artist != artist_clean {
            queries.push(format!("{clean_title} {clean_artist}"));
        }
    }
    queries.push(title_clean.to_string());
    if clean_title != title_clean {
        queries.push(clean_title.to_string());
    }

    let client = match reqwest::blocking::Client::builder()
        .timeout(Duration::from_millis(2200))
        .user_agent("Mozilla/5.0 (X11; Linux x86_64)")
        .build()
    {
        Ok(c) => c,
        Err(_) => return None,
    };

    for q in queries {
        let url = format!(
            "https://itunes.apple.com/search?term={}&entity=song&limit=1",
            urlencoding(&q)
        );

        if let Ok(resp) = client.get(&url).send() {
            if let Ok(json_val) = resp.json::<serde_json::Value>() {
                if let Some(results) = json_val.get("results").and_then(|r| r.as_array()) {
                    if let Some(first) = results.first() {
                        if let Some(art_url) = first.get("artworkUrl100").and_then(|u| u.as_str()) {
                            let high_res = art_url.replace("100x100bb", "600x600bb");
                            if let Ok(img_resp) = client.get(&high_res).send() {
                                if let Ok(bytes) = img_resp.bytes() {
                                    if bytes.len() > 1000 {
                                        let tmp_path = cache_dir.join(format!("{key_hex}.tmp"));
                                        if fs::write(&tmp_path, &bytes).is_ok() {
                                            let _ = fs::rename(&tmp_path, &cached_path);
                                            return Some(format!("file://{}", cached_path.to_string_lossy()));
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    None
}

fn urlencoding(input: &str) -> String {
    let mut out = String::with_capacity(input.len() * 2);
    for byte in input.bytes() {
        match byte {
            b'a'..=b'z' | b'A'..=b'Z' | b'0'..=b'9' | b'-' | b'_' | b'.' | b'~' => {
                out.push(byte as char);
            }
            b' ' => out.push('+'),
            _ => {
                out.push_str(&format!("%{:02X}", byte));
            }
        }
    }
    out
}

// ============================================================
// BRAND & ICON RESOLVERS
// ============================================================

pub fn resolve_player_branding(identity: &str) -> (&'static str, &'static str, &'static str) {
    let id = identity.to_lowercase();
    if id.contains("spotify") {
        ("Spotify", "󰓇", "#1DB954")
    } else if id.contains("firefox") || id.contains("zen") || id.contains("floorp") || id.contains("waterfox") {
        ("Firefox", "󰈹", "#FF7139")
    } else if id.contains("chrome") || id.contains("chromium") {
        ("Chrome", "󰊯", "#4285F4")
    } else if id.contains("brave") {
        ("Brave", "󰊯", "#FB542B")
    } else if id.contains("edge") {
        ("Edge", "󰇩", "#0078D7")
    } else if id.contains("cider") || id.contains("apple") {
        ("Apple Music", "󰀵", "#FC3C44")
    } else if id.contains("amberol") {
        ("Amberol", "󰎆", "#E05A47")
    } else if id.contains("rhythmbox") {
        ("Rhythmbox", "󰎆", "#2670E8")
    } else if id.contains("vlc") {
        ("VLC", "󰕼", "#FF8800")
    } else if id.contains("mpv") || id.contains("celluloid") {
        ("MPV", "󰐎", "#9C27B0")
    } else if id.contains("tidal") {
        ("Tidal", "󰎆", "#00FFFF")
    } else if id.contains("deezer") {
        ("Deezer", "󰎆", "#A238FF")
    } else {
        ("Media Player", "󰎆", "#00E5FF")
    }
}

// ============================================================
// URL ARTWORK UPSCALER
// ============================================================

pub fn upscale_artwork_url(url: &str) -> String {
    let mut art = url.to_string();
    if art.contains("i.scdn.co/image/ab67616d00001e02") {
        art = art.replace("ab67616d00001e02", "ab67616d0000b273");
    } else if art.contains("i.scdn.co/image/ab67616d00004851") {
        art = art.replace("ab67616d00004851", "ab67616d0000b273");
    } else if art.contains("hqdefault.jpg") {
        art = art.replace("hqdefault.jpg", "maxresdefault.jpg");
    } else if art.contains("default.jpg") && !art.contains("maxresdefault.jpg") && !art.contains("sddefault.jpg") {
        art = art.replace("default.jpg", "hqdefault.jpg");
    }
    art
}

// ============================================================
// ACTIVE MEDIA STATE QUERY
// ============================================================

pub fn get_current_state() -> Option<MediaState> {
    let output = Command::new("playerctl")
        .args([
            "metadata",
            "--format",
            "{{playerName}}@@{{status}}@@{{title}}@@{{artist}}@@{{album}}@@{{mpris:artUrl}}@@{{mpris:length}}@@{{position}}",
        ])
        .output()
        .ok()?;

    if !output.status.success() {
        return None;
    }

    let line = String::from_utf8_lossy(&output.stdout).trim().to_string();
    if line.is_empty() {
        return None;
    }

    parse_playerctl_line(&line)
}

fn parse_playerctl_line(line: &str) -> Option<MediaState> {
    let parts: Vec<&str> = line.split("@@").collect();
    if parts.len() < 6 {
        return None;
    }

    let raw_player = parts[0].trim();
    let status = parts[1].trim();
    let title = parts[2].trim();
    let artist = parts[3].trim();
    let album = parts[4].trim();
    let raw_cover = parts[5].trim();
    let length = parts.get(6).and_then(|s| s.trim().parse::<i64>().ok()).unwrap_or(0);
    let position = parts.get(7).and_then(|s| s.trim().parse::<i64>().ok()).unwrap_or(0);

    let (clean_name, icon, color) = resolve_player_branding(raw_player);
    let upscaled = upscale_artwork_url(raw_cover);

    let high_res = if upscaled.is_empty() || upscaled.contains("/tmp/") || upscaled.contains("firefox-mpris") {
        fetch_high_res_cover(title, artist).unwrap_or_else(|| upscaled.clone())
    } else {
        upscaled.clone()
    };

    Some(MediaState {
        player: raw_player.to_string(),
        identity: clean_name.to_string(),
        icon: icon.to_string(),
        color: color.to_string(),
        status: status.to_string(),
        playing: status == "Playing",
        title: title.to_string(),
        artist: artist.to_string(),
        album: album.to_string(),
        cover: if upscaled.is_empty() { high_res.clone() } else { upscaled },
        high_res_cover: high_res,
        length,
        position,
    })
}

// ============================================================
// REAL-TIME WATCHER DAEMON (CANCELLATION TOKEN + ZERO JANK)
// ============================================================

pub fn watch_daemon() {
    let state_file = get_state_file_path();
    let current_version = Arc::new(AtomicU64::new(0));

    // Spawn playerctl metadata --follow process
    let mut child = match Command::new("playerctl")
        .args([
            "metadata",
            "--follow",
            "--format",
            "{{playerName}}@@{{status}}@@{{title}}@@{{artist}}@@{{album}}@@{{mpris:artUrl}}@@{{mpris:length}}@@{{position}}",
        ])
        .stdout(Stdio::piped())
        .spawn()
    {
        Ok(c) => c,
        Err(err) => {
            eprintln!("Failed to spawn playerctl watcher: {err}");
            return;
        }
    };

    let stdout = match child.stdout.take() {
        Some(s) => s,
        None => return,
    };

    let reader = BufReader::new(stdout);
    for line_res in reader.lines() {
        let line = match line_res {
            Ok(l) => l,
            Err(_) => break,
        };

        if line.trim().is_empty() {
            continue;
        }

        let version = current_version.fetch_add(1, Ordering::SeqCst) + 1;
        let version_check = Arc::clone(&current_version);
        let state_path_clone = state_file.clone();

        // Process line in a lightweight thread with request cancellation
        thread::spawn(move || {
            // Debounce 50ms to allow multi-part D-Bus property changes to coalesce
            thread::sleep(Duration::from_millis(50));
            if version_check.load(Ordering::SeqCst) != version {
                return; // Newer event already arrived, cancel!
            }

            if let Some(state) = parse_playerctl_line(&line) {
                if version_check.load(Ordering::SeqCst) != version {
                    return; // Superseded during cover fetch, abort write
                }

                if let Ok(json_str) = serde_json::to_string(&state) {
                    println!("{json_str}");
                    let _ = std::io::stdout().flush();

                    // Atomic write to state file
                    let tmp_path = state_path_clone.with_extension("tmp");
                    if fs::write(&tmp_path, json_str.as_bytes()).is_ok() {
                        let _ = fs::rename(&tmp_path, &state_path_clone);
                    }
                }
            }
        });
    }
}

// ============================================================
// CLI INTERFACE FOR NEXAD
// ============================================================

pub fn run_fetch(title: &str, artist: &str) {
    if let Some(url) = fetch_high_res_cover(title, artist) {
        println!("{url}");
    }
}

pub fn run_info() {
    if let Some(state) = get_current_state() {
        if let Ok(json_str) = serde_json::to_string_pretty(&state) {
            println!("{json_str}");
        }
    } else {
        println!("{{}}");
    }
}

pub fn run_toggle() {
    let _ = Command::new("playerctl").arg("play-pause").status();
}

pub fn run_next() {
    let _ = Command::new("playerctl").arg("next").status();
}

pub fn run_prev() {
    let _ = Command::new("playerctl").arg("previous").status();
}
