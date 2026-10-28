use super::hypr_command;
use serde::{Deserialize, Serialize};
use std::env;
use std::fs;
use std::path::PathBuf;

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct ShapesConfig {
    #[serde(default = "default_rounding")]
    pub rounding: i32,
    #[serde(default = "default_nexa_rounding")]
    pub nexa_rounding: i32,
    #[serde(default)]
    pub border_size: i32,
    #[serde(default = "default_style")]
    pub style: String,
    #[serde(default = "default_true")]
    pub shadow_enabled: bool,
    #[serde(default = "default_shadow_range")]
    pub shadow_range: i32,
    #[serde(default)]
    pub dim_inactive: bool,
    #[serde(default)]
    pub dim_strength: f64,
}

fn default_rounding() -> i32 {
    10
}

fn default_nexa_rounding() -> i32 {
    8
}

fn default_style() -> String {
    "standard".to_string()
}

fn default_true() -> bool {
    true
}

fn default_shadow_range() -> i32 {
    30
}

impl Default for ShapesConfig {
    fn default() -> Self {
        Self {
            rounding: 10,
            nexa_rounding: 8,
            border_size: 0,
            style: "standard".to_string(),
            shadow_enabled: true,
            shadow_range: 30,
            dim_inactive: false,
            dim_strength: 0.0,
        }
    }
}

pub fn config_path() -> PathBuf {
    if let Ok(home) = env::var("HOME") {
        PathBuf::from(home)
            .join(".config")
            .join("nexa")
            .join("config")
            .join("shapes.json")
    } else {
        PathBuf::from("/tmp/shapes.json")
    }
}

pub fn load_config() -> ShapesConfig {
    let p = config_path();
    if let Ok(bytes) = fs::read(&p) {
        serde_json::from_slice(&bytes).unwrap_or_default()
    } else {
        ShapesConfig::default()
    }
}

pub fn save_config(config: &ShapesConfig) -> Result<(), String> {
    let p = config_path();
    if let Some(parent) = p.parent() {
        let _ = fs::create_dir_all(parent);
    }
    let data = serde_json::to_vec_pretty(config)
        .map_err(|e| format!("Failed to serialize shapes.json: {e}"))?;
    fs::write(&p, data).map_err(|e| format!("Failed to write shapes.json: {e}"))?;
    Ok(())
}

/// Dispatches all visual parameters (borders, rounding, shadows, blur, dimming)
/// directly into Hyprland compositor in < 2ms via UNIX domain socket.
pub fn sync_decorations() -> Result<(), String> {
    let config = load_config();

    let rounding = config.rounding;
    let border_size = config.border_size;
    let shadow_enabled = if config.shadow_enabled { "true" } else { "false" };
    let shadow_range = config.shadow_range;
    let dim_inactive = if config.dim_inactive { "true" } else { "false" };
    let dim_strength = config.dim_strength;

    let lua_script = format!(
        r#"
        local home = os.getenv("HOME") or ""
        local cache = home .. "/.cache"
        local config = home .. "/.config/hypr"
        local paths = {{
            config .. "/config/colors.lua",
            cache .. "/hypr/colors.lua",
            cache .. "/wal/colors.lua",
            cache .. "/matugen/colors.lua",
        }}
        local colors = nil
        for _, path in ipairs(paths) do
            local chunk = loadfile(path)
            if chunk then
                local ok, theme_colors = pcall(chunk)
                if ok and type(theme_colors) == "table" and theme_colors.active_border then
                    colors = theme_colors
                    break
                end
            end
        end
        if not colors then
            colors = {{
                active_border = {{ colors = {{ "rgba(ffb4aaee)", "rgba(f4ba9fee)" }}, angle = 45 }},
                inactive_border = "rgba(55424055)"
            }}
        end

        hl.config({{
            general = {{
                gaps_in = 5,
                gaps_out = 10,
                border_size = {border_size},
                col = {{
                    active_border = colors.active_border,
                    inactive_border = colors.inactive_border,
                }},
                resize_on_border = true,
                allow_tearing = false,
                layout = "dwindle"
            }},
            decoration = {{
                rounding = {rounding},
                rounding_power = 2,
                active_opacity = 1.0,
                inactive_opacity = 1.0,
                dim_inactive = {dim_inactive},
                dim_strength = {dim_strength},
                shadow = {{
                    enabled = {shadow_enabled},
                    range = {shadow_range},
                    render_power = 4,
                    color = "rgba(000000aa)",
                    color_inactive = "rgba(00000065)",
                    offset = "0 8",
                    scale = 1.0
                }},
                blur = {{
                    enabled = true,
                    size = 3,
                    passes = 1,
                    vibrancy = 0.1696
                }}
            }},
            dwindle = {{ preserve_split = true }},
            master = {{ new_status = "master" }},
            misc = {{
                force_default_wallpaper = -1,
                disable_hyprland_logo = false,
                animate_manual_resizes = true,
                animate_mouse_windowdragging = true
            }}
        }})
        "#
    );

    let clean_script: String = lua_script
        .lines()
        .map(|l| l.trim())
        .filter(|l| !l.is_empty())
        .collect::<Vec<&str>>()
        .join("\n");

    let cmd = format!("eval {clean_script}");
    let resp = hypr_command(&cmd)?;

    if resp != "ok" && !resp.is_empty() {
        eprintln!("[NEXA Decorations] eval response: {resp}");
    } else {
        println!("[NEXA Decorations] Successfully applied compositor decorations (rounding={rounding}px, border={border_size}px, shadow={shadow_enabled}, dim={dim_strength}).");
    }

    Ok(())
}

/// Updates decoration parameters in `shapes.json` and syncs them live to Hyprland compositor.
pub fn set_decoration(
    rounding: Option<i32>,
    border: Option<i32>,
    nexa_rounding: Option<i32>,
    shadow: Option<bool>,
    shadow_range: Option<i32>,
    dim_inactive: Option<bool>,
    dim_strength: Option<f64>,
) -> Result<(), String> {
    let mut config = load_config();

    if let Some(r) = rounding {
        config.rounding = r;
    }
    if let Some(b) = border {
        config.border_size = b;
    }
    if let Some(nr) = nexa_rounding {
        config.nexa_rounding = nr;
    }
    if let Some(s) = shadow {
        config.shadow_enabled = s;
    }
    if let Some(sr) = shadow_range {
        config.shadow_range = sr;
    }
    if let Some(di) = dim_inactive {
        config.dim_inactive = di;
    }
    if let Some(ds) = dim_strength {
        config.dim_strength = ds;
        config.dim_inactive = ds > 0.001;
    }

    save_config(&config)?;
    sync_decorations()?;

    Ok(())
}

/// Prints a summary of the current decoration settings.
pub fn print_status() {
    let config = load_config();
    println!("\nNEXA Hyprland Decorations & Shapes State:");
    println!("  • Window Corner Radius:  {} px", config.rounding);
    println!("  • Window Border Width:   {} px", config.border_size);
    println!("  • Nexa Shell Curvature:  {} px", config.nexa_rounding);
    println!("  • Drop Shadow:           {} (range: {}px)", if config.shadow_enabled { "Enabled" } else { "Disabled" }, config.shadow_range);
    println!("  • Inactive Window Dim:   {} ({:.0}%)", if config.dim_inactive { "Enabled" } else { "Disabled" }, config.dim_strength * 100.0);
    println!("  • Preset Style:          {}\n", config.style);
    println!("Usage:");
    println!("  nexad hypr decorations sync");
    println!("  nexad hypr decorations set --rounding <px> --border <px> --shadow <true|false> --dim <0.0-1.0>\n");
}
