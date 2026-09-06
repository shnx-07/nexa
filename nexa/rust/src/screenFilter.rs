use serde::Serialize;
use std::{
    env,
    fs,
    path::{Path, PathBuf},
    process::Command,
};

// ============================================================
// FILTER CONSTANTS
// ============================================================

pub const FILTER_OFF: &str = "off";
pub const FILTER_CHROMA: &str = "chroma";
pub const FILTER_GRAYSCALE: &str = "grayscale";
pub const FILTER_HDR: &str = "hdr-boost";
pub const FILTER_HIGH_CONTRAST: &str = "high-contrast";
pub const FILTER_INVERT: &str = "invert";
pub const FILTER_SEPIA: &str = "sepia";
pub const FILTER_PAPER: &str = "paper-mode";

pub const FILTERS: &[&str] = &[
    FILTER_OFF,
    FILTER_CHROMA,
    FILTER_GRAYSCALE,
    FILTER_HDR,
    FILTER_HIGH_CONTRAST,
    FILTER_INVERT,
    FILTER_SEPIA,
    FILTER_PAPER,
];

// ============================================================
// STATE STRUCT
// ============================================================

#[derive(Debug, Clone, Serialize)]
pub struct ScreenFilterInfo {
    pub enabled: bool,
    pub filter: String,
    pub available: Vec<String>,
}

// ============================================================
// PATHS
// ============================================================

fn home_dir() -> PathBuf {
    PathBuf::from(env::var("HOME").unwrap_or_else(|_| ".".to_string()))
}

fn config_path() -> PathBuf {
    home_dir()
        .join(".config")
        .join("nexa")
        .join("config")
        .join("screen-filter.conf")
}

fn shader_dir() -> PathBuf {
    home_dir()
        .join(".cache")
        .join("nexa")
        .join("screen-filters")
}

fn shader_path(filter: &str) -> PathBuf {
    shader_dir().join(format!("{filter}.frag"))
}

// ============================================================
// STATE PERSISTENCE
// ============================================================

fn load_filter() -> String {
    let Ok(content) = fs::read_to_string(config_path()) else {
        return FILTER_OFF.to_string();
    };

    for line in content.lines() {
        let line = line.trim();
        if let Some((key, val)) = line.split_once('=') {
            if key.trim() == "filter" {
                let v = val.trim();
                if FILTERS.contains(&v) {
                    return v.to_string();
                }
            }
        }
    }

    FILTER_OFF.to_string()
}

fn save_filter(filter: &str) -> Result<(), String> {
    let path = config_path();
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent).map_err(|e| {
            format!("Failed to create config dir {}: {e}", parent.display())
        })?;
    }

    fs::write(&path, format!("filter={filter}\n")).map_err(|e| {
        format!("Failed to write {}: {e}", path.display())
    })
}

// ============================================================
// HYPRLAND INTERFACING
// ============================================================

fn run_hyprctl(args: &[&str]) -> Result<(), String> {
    let output = Command::new("hyprctl")
        .args(args)
        .output()
        .map_err(|e| format!("Failed to execute hyprctl: {e}"))?;

    if !output.status.success() {
        let err = String::from_utf8_lossy(&output.stderr);
        return Err(format!("hyprctl error: {}", err.trim()));
    }

    Ok(())
}

fn apply_shader(path: &Path) -> Result<(), String> {
    let canonical = path.canonicalize().map_err(|e| {
        format!("Failed to resolve shader path {}: {e}", path.display())
    })?;

    let path_str = canonical
        .to_string_lossy()
        .replace('\\', "\\\\")
        .replace('"', "\\\"");

    let expr = format!(
        r#"hl.config({{ debug = {{ damage_tracking = 1 }}, decoration = {{ screen_shader = "{path_str}" }} }});"#
    );

    run_hyprctl(&["eval", &expr])
}

fn disable_shader() -> Result<(), String> {
    run_hyprctl(&[
        "eval",
        r#"hl.config({ debug = { damage_tracking = 2 }, decoration = { screen_shader = "" } });"#,
    ])
}

// ============================================================
// CORE ACTIONS
// ============================================================

pub fn info() -> Result<ScreenFilterInfo, String> {
    let current = load_filter();
    Ok(ScreenFilterInfo {
        enabled: current != FILTER_OFF,
        filter: current,
        available: FILTERS.iter().map(|s| s.to_string()).collect(),
    })
}

pub fn set(filter: &str) -> Result<ScreenFilterInfo, String> {
    if !FILTERS.contains(&filter) {
        return Err(format!("Unknown screen filter: {filter}"));
    }

    if filter == FILTER_OFF {
        return off();
    }

    ensure_shaders()?;

    let spath = shader_path(filter);
    apply_shader(&spath)?;
    save_filter(filter)?;

    info()
}

pub fn off() -> Result<ScreenFilterInfo, String> {
    disable_shader()?;
    save_filter(FILTER_OFF)?;
    info()
}

pub fn toggle(filter: &str) -> Result<ScreenFilterInfo, String> {
    let current = load_filter();
    if current == filter {
        off()
    } else {
        set(filter)
    }
}

pub fn apply() -> Result<ScreenFilterInfo, String> {
    let current = load_filter();
    if current == FILTER_OFF {
        disable_shader()?;
        return info();
    }

    ensure_shaders()?;
    let spath = shader_path(&current);
    apply_shader(&spath)?;
    info()
}

// ============================================================
// SHADER ASSETS
// ============================================================

fn ensure_shaders() -> Result<(), String> {
    let dir = shader_dir();
    fs::create_dir_all(&dir).map_err(|e| {
        format!("Failed to create shader dir {}: {e}", dir.display())
    })?;

    write_shader_file(FILTER_CHROMA, CHROMA_SHADER)?;
    write_shader_file(FILTER_GRAYSCALE, GRAYSCALE_SHADER)?;
    write_shader_file(FILTER_HDR, HDR_SHADER)?;
    write_shader_file(FILTER_HIGH_CONTRAST, HIGH_CONTRAST_SHADER)?;
    write_shader_file(FILTER_INVERT, INVERT_SHADER)?;
    write_shader_file(FILTER_SEPIA, SEPIA_SHADER)?;
    write_shader_file(FILTER_PAPER, PAPER_SHADER)?;

    Ok(())
}

fn write_shader_file(name: &str, content: &str) -> Result<(), String> {
    let path = shader_path(name);
    fs::write(&path, content).map_err(|e| {
        format!("Failed to write shader file {}: {e}", path.display())
    })
}

// ------------------------------------------------------------
// GLSL Shaders (OpenGL ES 3.0 compatible)
// ------------------------------------------------------------

const CHROMA_SHADER: &str = r#"#version 300 es
precision mediump float;
in vec2 v_texcoord;
layout(location = 0) out vec4 fragColor;
uniform sampler2D tex;

void main() {
    vec4 color = texture(tex, v_texcoord);
    float luminance = dot(color.rgb, vec3(0.2126, 0.7152, 0.0722));
    vec3 boosted = mix(vec3(luminance), color.rgb, 1.35);
    fragColor = vec4(clamp(boosted, 0.0, 1.0), color.a);
}
"#;

const GRAYSCALE_SHADER: &str = r#"#version 300 es
precision mediump float;
in vec2 v_texcoord;
layout(location = 0) out vec4 fragColor;
uniform sampler2D tex;

void main() {
    vec4 color = texture(tex, v_texcoord);
    float luminance = dot(color.rgb, vec3(0.2126, 0.7152, 0.0722));
    fragColor = vec4(vec3(luminance), color.a);
}
"#;

const HDR_SHADER: &str = r#"#version 300 es
precision mediump float;
in vec2 v_texcoord;
layout(location = 0) out vec4 fragColor;
uniform sampler2D tex;

void main() {
    vec4 color = texture(tex, v_texcoord);
    vec3 rgb = (color.rgb - 0.5) * 1.12 + 0.5;
    float luminance = dot(rgb, vec3(0.2126, 0.7152, 0.0722));
    rgb = mix(vec3(luminance), rgb, 1.12);
    rgb = pow(max(rgb, vec3(0.0)), vec3(0.94));
    fragColor = vec4(clamp(rgb, 0.0, 1.0), color.a);
}
"#;

const HIGH_CONTRAST_SHADER: &str = r#"#version 300 es
precision mediump float;
in vec2 v_texcoord;
layout(location = 0) out vec4 fragColor;
uniform sampler2D tex;

void main() {
    vec4 color = texture(tex, v_texcoord);
    vec3 rgb = (color.rgb - 0.5) * 1.35 + 0.5;
    fragColor = vec4(clamp(rgb, 0.0, 1.0), color.a);
}
"#;

const INVERT_SHADER: &str = r#"#version 300 es
precision mediump float;
in vec2 v_texcoord;
layout(location = 0) out vec4 fragColor;
uniform sampler2D tex;

void main() {
    vec4 color = texture(tex, v_texcoord);
    fragColor = vec4(vec3(1.0) - color.rgb, color.a);
}
"#;

const SEPIA_SHADER: &str = r#"#version 300 es
precision mediump float;
in vec2 v_texcoord;
layout(location = 0) out vec4 fragColor;
uniform sampler2D tex;

void main() {
    vec4 color = texture(tex, v_texcoord);
    vec3 rgb;
    rgb.r = dot(color.rgb, vec3(0.393, 0.769, 0.189));
    rgb.g = dot(color.rgb, vec3(0.349, 0.686, 0.168));
    rgb.b = dot(color.rgb, vec3(0.272, 0.534, 0.131));
    fragColor = vec4(clamp(rgb, 0.0, 1.0), color.a);
}
"#;

const PAPER_SHADER: &str = r#"#version 300 es
precision highp float;
in vec2 v_texcoord;
layout(location = 0) out vec4 fragColor;
uniform sampler2D tex;

// Safe normalized pseudorandom hash
float paperRand(vec2 n) {
    return fract(sin(dot(n, vec2(12.9898, 78.233))) * 43758.5453);
}

void main() {
    vec4 color = texture(tex, v_texcoord);
    float lum = dot(color.rgb, vec3(0.2126, 0.7152, 0.0722));

    // 1. Warm paper color matrix (gentle ~4200K amber/ivory shift)
    vec3 warmTint = vec3(1.0, 0.935, 0.825);
    vec3 paperColor = color.rgb * warmTint;

    // 2. Anti-glare white compression:
    // Softens harsh digital white into natural book-page ivory
    vec3 bookPageIvory = vec3(0.965, 0.930, 0.855);
    paperColor = mix(paperColor, paperColor * bookPageIvory, smoothstep(0.4, 1.0, lum) * 0.35);

    // 3. Subtle contrast softening (matte print feel)
    paperColor = clamp(paperColor * 0.985 + vec3(0.008, 0.008, 0.008), 0.0, 1.0);

    // 4. Safe procedural micro paper fiber & tactile grain texture
    float fineGrain = paperRand(v_texcoord * 600.0);
    float fiberNoise = paperRand(floor(v_texcoord * 300.0));
    float combinedGrain = mix(fineGrain, fiberNoise, 0.35);

    float backgroundMask = smoothstep(0.25, 0.95, lum);
    float grainVariation = (combinedGrain - 0.5) * 0.035 * backgroundMask;

    vec3 finalRgb = paperColor + vec3(
        grainVariation * 1.0,
        grainVariation * 0.92,
        grainVariation * 0.80
    );

    fragColor = vec4(clamp(finalRgb, 0.0, 1.0), color.a);
}
"#;

// ============================================================
// CLI ENTRY POINT
// ============================================================

pub fn handle(args: &[String]) -> Result<(), String> {
    let command = args.first().map(String::as_str).unwrap_or("info");

    let result = match command {
        "info" => info()?,
        "set" => {
            let filter = args.get(1).ok_or("Missing screen filter name")?;
            set(filter)?
        }
        "off" => off()?,
        "toggle" => {
            let filter = args.get(1).ok_or("Missing screen filter name")?;
            toggle(filter)?
        }
        "apply" => apply()?,
        _ => {
            return Err(format!("Unknown screen filter command: {command}"));
        }
    };

    let json = serde_json::to_string(&result)
        .map_err(|e| format!("Failed to serialize result: {e}"))?;

    println!("{json}");
    Ok(())
}
