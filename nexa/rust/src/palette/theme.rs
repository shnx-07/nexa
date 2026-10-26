use serde::{Deserialize, Serialize};
use std::{
    env, fs,
    path::{Path, PathBuf},
    process::Command,
};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ThemeConfig {
    pub style: String,
    pub preset: String,
    pub mode: String,
    pub scheme_type: String,
}

impl Default for ThemeConfig {
    fn default() -> Self {
        Self {
            style: "wallpaperFull".into(),
            preset: "extras/CatppuccinMacchiato".into(),
            mode: "dark".into(),
            scheme_type: "scheme-vibrant".into(),
        }
    }
}

pub fn nexa_config_dir() -> PathBuf {
    let home = env::var("HOME").unwrap_or_else(|_| String::from("."));
    PathBuf::from(home).join(".config/nexa/config")
}

pub fn cache_dir() -> PathBuf {
    let home = env::var("HOME").unwrap_or_else(|_| String::from("."));
    PathBuf::from(home).join(".cache/nexa")
}

pub fn theme_config_path() -> PathBuf {
    nexa_config_dir().join("theme.conf")
}

pub fn load_config() -> ThemeConfig {
    let path = theme_config_path();
    let mut cfg = ThemeConfig::default();

    if let Ok(content) = fs::read_to_string(path) {
        for line in content.lines() {
            let line = line.trim();
            if let Some(val) = line.strip_prefix("STYLE=") {
                cfg.style = val.trim_matches('"').trim_matches('\'').to_string();
            } else if let Some(val) = line.strip_prefix("PRESET=") {
                cfg.preset = val.trim_matches('"').trim_matches('\'').to_string();
            } else if let Some(val) = line.strip_prefix("MODE=") {
                cfg.mode = val.trim_matches('"').trim_matches('\'').to_string();
            } else if let Some(val) = line.strip_prefix("SCHEME_TYPE=") {
                cfg.scheme_type = val.trim_matches('"').trim_matches('\'').to_string();
            }
        }
    }

    cfg
}

pub fn save_config(cfg: &ThemeConfig) -> Result<(), String> {
    let path = theme_config_path();
    if let Some(p) = path.parent() {
        let _ = fs::create_dir_all(p);
    }
    let content = format!(
        "STYLE=\"{}\"\nPRESET=\"{}\"\nMODE=\"{}\"\nSCHEME_TYPE=\"{}\"\n",
        cfg.style, cfg.preset, cfg.mode, cfg.scheme_type
    );
    fs::write(path, content).map_err(|e| format!("Failed to save theme config: {e}"))
}

pub fn print_status() {
    let cfg = load_config();
    let wall_conf = nexa_config_dir().join("wallpaper.conf");
    let mut wallpaper = String::new();
    if let Ok(content) = fs::read_to_string(wall_conf) {
        for line in content.lines() {
            let line = line.trim();
            if let Some(val) = line.strip_prefix("WALLPAPER=") {
                wallpaper = val.trim_matches('"').trim_matches('\'').to_string();
            }
        }
    }

    println!("NEXA Theme");
    println!("----------");
    println!("Style  : {}", cfg.style);
    println!("Preset : {}", cfg.preset);
    println!("Mode   : {}", cfg.mode);
    println!("Scheme : {}", cfg.scheme_type);
    println!("Wallpaper: {}", wallpaper);
}

fn hex_to_rgb(hex_color: &str) -> String {
    let clean = hex_color.trim_start_matches('#');
    if clean.len() < 6 {
        return "0,0,0".into();
    }
    let r = u8::from_str_radix(&clean[0..2], 16).unwrap_or(0);
    let g = u8::from_str_radix(&clean[2..4], 16).unwrap_or(0);
    let b = u8::from_str_radix(&clean[4..6], 16).unwrap_or(0);
    format!("{r},{g},{b}")
}

fn get_role(
    colors: &serde_json::Map<String, serde_json::Value>,
    role: &str,
    fallbacks: &[&str],
) -> Option<String> {
    for key in std::iter::once(&role).chain(fallbacks.iter()) {
        if let Some(entry) = colors.get(*key) {
            if let Some(obj) = entry.as_object() {
                let pref = obj
                    .get("default")
                    .or_else(|| obj.get("dark"))
                    .or_else(|| obj.get("light"));
                if let Some(c) = pref
                    .and_then(|p| p.get("color"))
                    .and_then(|v| v.as_str())
                {
                    return Some(c.to_lowercase());
                }
            }
            if let Some(s) = entry.as_str() {
                return Some(s.to_lowercase());
            }
        }
    }
    None
}

pub fn matugen_to_canonical(
    data: &serde_json::Value,
    mode: &str,
) -> Result<serde_json::Value, String> {
    let colors_obj = data
        .get("colors")
        .and_then(|c| c.as_object())
        .ok_or_else(|| "Missing colors in matugen json".to_string())?;

    let is_light = mode.eq_ignore_ascii_case("light");

    let req = |role: &str, fallbacks: &[&str]| -> String {
        get_role(colors_obj, role, fallbacks).unwrap_or_else(|| "#808080".into())
    };

    let mut colors = serde_json::Map::new();

    colors.insert("primary".into(), req("primary", &[]).into());
    colors.insert("on_primary".into(), req("on_primary", &[]).into());
    colors.insert("primary_container".into(), req("primary_container", &[]).into());
    colors.insert("on_primary_container".into(), req("on_primary_container", &[]).into());

    colors.insert("secondary".into(), req("secondary", &[]).into());
    colors.insert("on_secondary".into(), req("on_secondary", &[]).into());
    colors.insert("secondary_container".into(), req("secondary_container", &[]).into());
    colors.insert("on_secondary_container".into(), req("on_secondary_container", &[]).into());

    colors.insert("tertiary".into(), req("tertiary", &[]).into());
    colors.insert("on_tertiary".into(), req("on_tertiary", &[]).into());
    colors.insert("tertiary_container".into(), req("tertiary_container", &[]).into());
    colors.insert("on_tertiary_container".into(), req("on_tertiary_container", &[]).into());

    colors.insert("background".into(), req("background", &[]).into());
    colors.insert("on_background".into(), req("on_background", &[]).into());

    colors.insert("surface".into(), req("surface", &[]).into());
    colors.insert("surface_dim".into(), req("surface_dim", &["surface"]).into());
    colors.insert("surface_bright".into(), req("surface_bright", &["surface_container_highest"]).into());
    colors.insert("surface_variant".into(), req("surface_variant", &["surface_container_high"]).into());
    colors.insert("surface_container_lowest".into(), req("surface_container_lowest", &["surface_dim", "surface"]).into());
    colors.insert("surface_container_low".into(), req("surface_container_low", &["surface"]).into());
    colors.insert("surface_container".into(), req("surface_container", &[]).into());
    colors.insert("surface_container_high".into(), req("surface_container_high", &["surface_container"]).into());
    colors.insert("surface_container_highest".into(), req("surface_container_highest", &["surface_container_high"]).into());

    colors.insert("on_surface".into(), req("on_surface", &[]).into());
    colors.insert("on_surface_variant".into(), req("on_surface_variant", &[]).into());

    colors.insert("inverse_surface".into(), req("inverse_surface", &[]).into());
    colors.insert("inverse_on_surface".into(), req("inverse_on_surface", &[]).into());
    colors.insert("inverse_primary".into(), req("inverse_primary", &[]).into());

    colors.insert("outline".into(), req("outline", &[]).into());
    colors.insert("outline_variant".into(), req("outline_variant", &[]).into());
    colors.insert("shadow".into(), req("shadow", &[]).into());
    colors.insert("scrim".into(), req("scrim", &["shadow"]).into());

    // Standard semantics
    colors.insert("error".into(), (if is_light { "#bb1b28" } else { "#f0757f" }).into());
    colors.insert("on_error".into(), (if is_light { "#ffffff" } else { "#37060a" }).into());
    colors.insert("error_container".into(), (if is_light { "#f7d4d7" } else { "#541c21" }).into());
    colors.insert("on_error_container".into(), (if is_light { "#49080e" } else { "#f8aab1" }).into());

    colors.insert("success".into(), (if is_light { "#1e8f44" } else { "#78e29c" }).into());
    colors.insert("on_success".into(), (if is_light { "#ffffff" } else { "#083617" }).into());
    colors.insert("success_container".into(), (if is_light { "#d0f1db" } else { "#1c4a2b" }).into());
    colors.insert("on_success_container".into(), (if is_light { "#093e1b" } else { "#a6f2bf" }).into());

    colors.insert("warning".into(), (if is_light { "#aa690e" } else { "#efc36c" }).into());
    colors.insert("on_warning".into(), (if is_light { "#ffffff" } else { "#372706" }).into());
    colors.insert("warning_container".into(), (if is_light { "#f7e4c9" } else { "#4d3c19" }).into());
    colors.insert("on_warning_container".into(), (if is_light { "#422905" } else { "#f7daa1" }).into());

    colors.insert("info".into(), (if is_light { "#1885aa" } else { "#79cfec" }).into());
    colors.insert("on_info".into(), (if is_light { "#ffffff" } else { "#062b37" }).into());
    colors.insert("info_container".into(), (if is_light { "#cdeaf4" } else { "#1c3e4a" }).into());
    colors.insert("on_info_container".into(), (if is_light { "#073240" } else { "#a3e0f5" }).into());

    let mut rgb = serde_json::Map::new();
    for (k, v) in &colors {
        if let Some(s) = v.as_str() {
            rgb.insert(k.clone(), hex_to_rgb(s).into());
        }
    }

    let meta = serde_json::json!({
        "id": format!("wallpaper/generated/{mode}"),
        "category": "wallpaper",
        "name": "generated",
        "variant": mode
    });

    Ok(serde_json::json!({
        "meta": meta,
        "colors": colors,
        "rgb": rgb
    }))
}

pub fn set_gtk_color_preference(mode: &str) {
    let is_light = mode.eq_ignore_ascii_case("light");
    let prefer_dark = if is_light { 0 } else { 1 };
    let color_scheme = if is_light { "prefer-light" } else { "prefer-dark" };
    let gtk_theme = if is_light { "adw-gtk3" } else { "adw-gtk3-dark" };

    let _ = Command::new("gsettings")
        .args(["set", "org.gnome.desktop.interface", "color-scheme", color_scheme])
        .status();
    let _ = Command::new("gsettings")
        .args(["set", "org.gnome.desktop.interface", "gtk-theme", gtk_theme])
        .status();

    let _ = Command::new("dconf")
        .args(["write", "/org/gnome/desktop/interface/color-scheme", &format!("'{color_scheme}'")])
        .status();
    let _ = Command::new("dconf")
        .args(["write", "/org/gnome/desktop/interface/gtk-theme", &format!("'{gtk_theme}'")])
        .status();

    let home = env::var("HOME").unwrap_or_else(|_| String::from("."));
    for dir in &["gtk-3.0", "gtk-4.0"] {
        let settings_path = PathBuf::from(&home).join(".config").join(dir).join("settings.ini");
        if settings_path.exists() {
            if let Ok(mut text) = fs::read_to_string(&settings_path) {
                if text.contains("gtk-application-prefer-dark-theme=") {
                    text = text.lines().map(|line| {
                        if line.starts_with("gtk-application-prefer-dark-theme=") {
                            format!("gtk-application-prefer-dark-theme={prefer_dark}")
                        } else if line.starts_with("gtk-theme-name=") {
                            format!("gtk-theme-name={gtk_theme}")
                        } else {
                            line.to_string()
                        }
                    }).collect::<Vec<_>>().join("\n");
                } else {
                    text.push_str(&format!("\ngtk-application-prefer-dark-theme={prefer_dark}\ngtk-theme-name={gtk_theme}\n"));
                }
                let _ = fs::write(&settings_path, text);
            }
        }
    }
}

pub fn sync_chrome_theme(palette_file: &Path, mode: &str) {
    let primary_hex = if palette_file.exists() {
        if let Ok(text) = fs::read_to_string(palette_file) {
            text.lines()
                .find(|l| l.starts_with("PRIMARY="))
                .map(|l| l.split('=').nth(1).unwrap_or("").trim_matches('"').trim_matches('\'').to_string())
        } else {
            None
        }
    } else {
        None
    };

    let Some(hex_str) = primary_hex else {
        return;
    };
    let clean = hex_str.trim_start_matches('#');
    let argb = match u32::from_str_radix(&format!("FF{clean}"), 16) {
        Ok(v) => v,
        Err(_) => return,
    };
    let sk_color: i32 = argb as i32;
    let color_scheme = if mode.eq_ignore_ascii_case("dark") { 2 } else { 1 };

    let home = env::var("HOME").unwrap_or_else(|_| String::from("."));
    let browser_dirs = [
        format!("{home}/.config/google-chrome"),
        format!("{home}/.config/chromium"),
        format!("{home}/.config/BraveSoftware/Brave-Browser"),
    ];

    for base in &browser_dirs {
        let path = PathBuf::from(base);
        if !path.exists() {
            continue;
        }
        for entry in walkdir::WalkDir::new(path).max_depth(3).into_iter().flatten() {
            if entry.file_name() == "Preferences" {
                let pref_path = entry.path();
                if let Ok(text) = fs::read_to_string(pref_path) {
                    if let Ok(mut json) = serde_json::from_str::<serde_json::Value>(&text) {
                        if !json.is_object() {
                            json = serde_json::json!({});
                        }
                        json["browser"]["theme"]["user_color2"] = serde_json::json!(sk_color);
                        json["browser"]["theme"]["color_scheme2"] = serde_json::json!(color_scheme);
                        json["browser"]["theme"]["color_variant2"] = serde_json::json!(1);
                        json["browser"]["theme"]["saved_local_theme"] = serde_json::json!("CAAQAEgB");
                        if let Ok(out) = serde_json::to_string(&json) {
                            let _ = fs::write(pref_path, out);
                        }
                    }
                }
            }
        }
    }
}

pub fn render_canonical(canonical_path: &Path, mode: &str) -> Result<(), String> {
    let home = env::var("HOME").unwrap_or_else(|_| String::from("."));
    let matugen_config = PathBuf::from(&home).join(".config/matugen/config.toml");

    let status = Command::new("matugen")
        .args(["-c", &matugen_config.to_string_lossy(), "json", &canonical_path.to_string_lossy()])
        .status()
        .map_err(|e| format!("Failed to run matugen: {e}"))?;

    if !status.success() {
        return Err("Matugen canonical rendering failed".into());
    }

    let palette_file = cache_dir().join("theme/palette");
    sync_chrome_theme(&palette_file, mode);
    set_gtk_color_preference(mode);

    let gtk4_css = PathBuf::from(&home).join(".config/gtk-4.0/gtk.css");
    if gtk4_css.exists() {
        let _ = Command::new("touch").arg(&gtk4_css).status();
    }

    // Live reload GTK3 & GTK4 apps via dummy flick
    let _ = Command::new("bash").arg("-c").arg(
        "curr_theme=$(gsettings get org.gnome.desktop.interface gtk-theme 2>/dev/null | tr -d \"'\"); \
         if [[ -n \"$curr_theme\" ]]; then \
           dummy=\"Adwaita\"; [[ \"$curr_theme\" == \"Adwaita\" ]] && dummy=\"HighContrast\"; \
           gsettings set org.gnome.desktop.interface gtk-theme \"$dummy\" 2>/dev/null; \
           sleep 0.05; \
           gsettings set org.gnome.desktop.interface gtk-theme \"$curr_theme\" 2>/dev/null; \
         fi &"
    ).spawn();

    // Live reload Kitty
    let _ = Command::new("pkill").args(["-SIGUSR1", "kitty"]).status();

    // Live reload Hyprland window borders
    let _ = Command::new("hyprctl").arg("reload").status();

    Ok(())
}

pub fn generate_wallpaper_canonical(source: &Path, mode: &str) -> Result<PathBuf, String> {
    let home = env::var("HOME").unwrap_or_else(|_| String::from("."));
    let export_cfg = PathBuf::from(&home).join(".config/matugen/config-export.toml");
    let scheme_type = load_config().scheme_type;

    let output = Command::new("matugen")
        .args([
            "-c",
            &export_cfg.to_string_lossy(),
            "image",
            &source.to_string_lossy(),
            "-t",
            &scheme_type,
            "--mode",
            mode,
            "--source-color-index",
            "0",
            "--dry-run",
            "--json",
            "hex",
        ])
        .output()
        .map_err(|e| format!("Failed to run matugen image export: {e}"))?;

    if !output.status.success() {
        return Err("Matugen export returned error".into());
    }

    let raw_json: serde_json::Value = serde_json::from_slice(&output.stdout)
        .map_err(|e| format!("Failed to parse matugen export JSON: {e}"))?;

    let canonical = matugen_to_canonical(&raw_json, mode)?;

    let target_dir = cache_dir().join("theme");
    let _ = fs::create_dir_all(&target_dir);
    let target_file = target_dir.join("wallpaper-canonical.json");

    let text = serde_json::to_string_pretty(&canonical)
        .map_err(|e| format!("Failed to serialize canonical JSON: {e}"))?;
    fs::write(&target_file, text).map_err(|e| format!("Failed to write canonical file: {e}"))?;

    Ok(target_file)
}

pub fn apply_preset(preset_id: &str, mode: Option<&str>) -> Result<(), String> {
    let mut cfg = load_config();
    if let Some(m) = mode {
        cfg.mode = m.to_string();
    }
    cfg.style = "preset".into();

    let preset_path = super::presets::resolve_preset(preset_id, &cfg.mode)?;
    cfg.preset = preset_id.to_string();
    save_config(&cfg)?;

    render_canonical(&preset_path, &cfg.mode)
}

pub fn apply_mode(mode: &str) -> Result<(), String> {
    let mut cfg = load_config();
    cfg.mode = mode.to_string();
    save_config(&cfg)?;

    apply()
}

pub fn apply_style(style: &str, mode: Option<&str>) -> Result<(), String> {
    let mut cfg = load_config();
    cfg.style = style.to_string();
    if let Some(m) = mode {
        cfg.mode = m.to_string();
    }
    save_config(&cfg)?;

    apply()
}

pub fn apply() -> Result<(), String> {
    let cfg = load_config();

    match cfg.style.as_str() {
        "preset" => {
            let preset_path = super::presets::resolve_preset(&cfg.preset, &cfg.mode)?;
            render_canonical(&preset_path, &cfg.mode)
        }
        "wallpaperFull" | "wallpaperAccents" => {
            let wall_conf = nexa_config_dir().join("wallpaper.conf");
            let mut theme_source = String::new();
            if let Ok(content) = fs::read_to_string(&wall_conf) {
                for line in content.lines() {
                    let line = line.trim();
                    if let Some(val) = line.strip_prefix("THEME_SOURCE=") {
                        theme_source = val.trim_matches('"').trim_matches('\'').to_string();
                    }
                }
            }
            if theme_source.is_empty() {
                return Err("No THEME_SOURCE configured in wallpaper.conf".into());
            }
            let canonical = generate_wallpaper_canonical(Path::new(&theme_source), &cfg.mode)?;
            render_canonical(&canonical, &cfg.mode)
        }
        _ => Err(format!("Unknown style: {}", cfg.style)),
    }
}
