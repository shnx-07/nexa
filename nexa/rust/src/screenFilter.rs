use serde::Serialize;

use std::{
    env,
    fs,
    path::{
        Path,
        PathBuf,
    },
    process::Command,
};


// ============================================================
// FILTER NAMES
// ============================================================

const FILTER_OFF: &str = "off";
const FILTER_CHROMA: &str = "chroma";
const FILTER_GRAYSCALE: &str = "grayscale";
const FILTER_HDR: &str = "hdr-boost";
const FILTER_HIGH_CONTRAST: &str = "high-contrast";
const FILTER_INVERT: &str = "invert";
const FILTER_SEPIA: &str = "sepia";


const FILTERS: &[&str] = &[
    FILTER_OFF,
    FILTER_CHROMA,
    FILTER_GRAYSCALE,
    FILTER_HDR,
    FILTER_HIGH_CONTRAST,
    FILTER_INVERT,
    FILTER_SEPIA,
];


// ============================================================
// PUBLIC STATE
// ============================================================

#[derive(
    Debug,
    Clone,
    Serialize,
)]
pub struct ScreenFilterInfo {
    pub enabled: bool,
    pub filter: String,
    pub available: Vec<String>,
}


// ============================================================
// PATHS
// ============================================================

fn home() -> PathBuf {
    PathBuf::from(
        env::var("HOME")
            .unwrap_or_else(
                |_| ".".to_string()
            )
    )
}


fn config_path() -> PathBuf {
    home()
        .join(".config")
        .join("nexa")
        .join("config")
        .join("screen-filter.conf")
}


fn shader_dir() -> PathBuf {
    home()
        .join(".cache")
        .join("nexa")
        .join("screen-filters")
}


fn shader_path(
    filter: &str,
) -> PathBuf {
    shader_dir()
        .join(
            format!("{filter}.frag")
        )
}


// ============================================================
// INFO
// ============================================================

pub fn info()
    -> Result<ScreenFilterInfo, String>
{
    let filter =
        load_filter();


    Ok(
        ScreenFilterInfo {
            enabled:
                filter != FILTER_OFF,

            filter,

            available:
                FILTERS
                    .iter()
                    .map(
                        |value|
                            value.to_string()
                    )
                    .collect(),
        }
    )
}


// ============================================================
// SET FILTER
// ============================================================

pub fn set(
    filter: &str,
) -> Result<ScreenFilterInfo, String>
{
    validate_filter(
        filter
    )?;


    if filter == FILTER_OFF {
        disable_shader()?;

        save_filter(
            FILTER_OFF
        )?;

        return info();
    }


    ensure_shaders()?;


    let path =
        shader_path(
            filter
        );


    apply_shader(
        &path
    )?;


    save_filter(
        filter
    )?;


    info()
}


// ============================================================
// OFF
// ============================================================

pub fn off()
    -> Result<ScreenFilterInfo, String>
{
    set(
        FILTER_OFF
    )
}


// ============================================================
// APPLY SAVED STATE
// ============================================================

pub fn apply()
    -> Result<ScreenFilterInfo, String>
{
    let filter =
        load_filter();


    if filter == FILTER_OFF {
        disable_shader()?;
        return info();
    }


    ensure_shaders()?;


    apply_shader(
        &shader_path(
            &filter
        )
    )?;


    info()
}


// ============================================================
// VALIDATION
// ============================================================

fn validate_filter(
    filter: &str,
) -> Result<(), String>
{
    if FILTERS.contains(
        &filter
    ) {
        return Ok(());
    }


    Err(
        format!(
            "Unknown screen filter: {filter}"
        )
    )
}


// ============================================================
// SAVE STATE
// ============================================================

fn save_filter(
    filter: &str,
) -> Result<(), String>
{
    let path =
        config_path();


    if let Some(parent) =
        path.parent()
    {
        fs::create_dir_all(
            parent
        )
        .map_err(
            |error|
                format!(
                    "Failed to create config directory: {error}"
                )
        )?;
    }


    fs::write(
        &path,
        format!(
            "filter={filter}\n"
        ),
    )
    .map_err(
        |error|
            format!(
                "Failed to save {}: {error}",
                path.display()
            )
    )
}


// ============================================================
// LOAD STATE
// ============================================================

fn load_filter()
    -> String
{
    let Ok(content) =
        fs::read_to_string(
            config_path()
        )
    else {
        return FILTER_OFF
            .to_string();
    };


    for line in content.lines() {
        let Some(
            (key, value)
        ) = line.split_once('=')
        else {
            continue;
        };


        if key.trim()
            != "filter"
        {
            continue;
        }


        let value =
            value.trim();


        if FILTERS.contains(
            &value
        ) {
            return value
                .to_string();
        }
    }


    FILTER_OFF
        .to_string()
}


// ============================================================
// APPLY HYPRLAND SHADER
// ============================================================

fn apply_shader(
    path: &Path,
) -> Result<(), String>
{
    let path =
        path
            .canonicalize()
            .map_err(
                |error|
                    format!(
                        "Failed to resolve shader path: {error}"
                    )
            )?;

    let path =
        path
            .to_string_lossy()
            .replace('\\', "\\\\")
            .replace('"', "\\\"");

    let expression =
        format!(
            r#"hl.config({{ decoration = {{ screen_shader = "{path}" }} }})"#
        );

    run_hyprctl(
        &[
            "eval",
            &expression,
        ]
    )
}

// ============================================================
// DISABLE HYPRLAND SHADER
// ============================================================

fn disable_shader()
    -> Result<(), String>
{
    run_hyprctl(
        &[
            "eval",
            r#"hl.config({ decoration = { screen_shader = "" } })"#,
        ]
    )
}


// ============================================================
// HYPRCTL
// ============================================================

fn run_hyprctl(
    args: &[&str],
) -> Result<(), String>
{
    let output =
        Command::new(
            "hyprctl"
        )
        .args(
            args
        )
        .output()
        .map_err(
            |error|
                format!(
                    "Failed to run hyprctl: {error}"
                )
        )?;


    if !output.status.success() {
        let stderr =
            String::from_utf8_lossy(
                &output.stderr
            )
            .trim()
            .to_string();


        let stdout =
            String::from_utf8_lossy(
                &output.stdout
            )
            .trim()
            .to_string();


        return Err(
            if !stderr.is_empty() {
                stderr
            } else if !stdout.is_empty() {
                stdout
            } else {
                format!(
                    "hyprctl exited with {}",
                    output.status
                )
            }
        );
    }


    Ok(())
}


// ============================================================
// CREATE SHADERS
// ============================================================

fn ensure_shaders()
    -> Result<(), String>
{
    let dir =
        shader_dir();


    fs::create_dir_all(
        &dir
    )
    .map_err(
        |error|
            format!(
                "Failed to create shader directory: {error}"
            )
    )?;


    write_shader(
        FILTER_CHROMA,
        CHROMA_SHADER,
    )?;


    write_shader(
        FILTER_GRAYSCALE,
        GRAYSCALE_SHADER,
    )?;


    write_shader(
        FILTER_HDR,
        HDR_SHADER,
    )?;


    write_shader(
        FILTER_HIGH_CONTRAST,
        HIGH_CONTRAST_SHADER,
    )?;


    write_shader(
        FILTER_INVERT,
        INVERT_SHADER,
    )?;


    write_shader(
        FILTER_SEPIA,
        SEPIA_SHADER,
    )?;


    Ok(())
}


// ============================================================
// WRITE SHADER
// ============================================================

fn write_shader(
    name: &str,
    content: &str,
) -> Result<(), String>
{
    fs::write(
        shader_path(
            name
        ),
        content,
    )
    .map_err(
        |error|
            format!(
                "Failed to write {name} shader: {error}"
            )
    )
}


// ============================================================
// SHADER — CHROMA
// ============================================================

const CHROMA_SHADER: &str = r#"
#version 300 es

precision mediump float;

in vec2 v_texcoord;

layout(location = 0)
out vec4 fragColor;

uniform sampler2D tex;


void main() {
    vec4 color =
        texture(
            tex,
            v_texcoord
        );

    float luminance =
        dot(
            color.rgb,
            vec3(
                0.2126,
                0.7152,
                0.0722
            )
        );

    vec3 gray =
        vec3(
            luminance
        );

    /*
     * Mild saturation boost.
     */
    vec3 boosted =
        mix(
            gray,
            color.rgb,
            1.35
        );

    fragColor =
        vec4(
            clamp(
                boosted,
                0.0,
                1.0
            ),
            color.a
        );
}
"#;


// ============================================================
// SHADER — GRAYSCALE
// ============================================================

const GRAYSCALE_SHADER: &str = r#"
#version 300 es

precision mediump float;

in vec2 v_texcoord;

layout(location = 0)
out vec4 fragColor;

uniform sampler2D tex;


void main() {
    vec4 color =
        texture(
            tex,
            v_texcoord
        );

    float luminance =
        dot(
            color.rgb,
            vec3(
                0.2126,
                0.7152,
                0.0722
            )
        );

    fragColor =
        vec4(
            vec3(
                luminance
            ),
            color.a
        );
}
"#;


// ============================================================
// SHADER — HDR BOOST
//
// This is a visual enhancement only.
// It is NOT real HDR output.
// ============================================================

const HDR_SHADER: &str = r#"
#version 300 es

precision mediump float;

in vec2 v_texcoord;

layout(location = 0)
out vec4 fragColor;

uniform sampler2D tex;


void main() {
    vec4 color =
        texture(
            tex,
            v_texcoord
        );

    vec3 rgb =
        color.rgb;


    /*
     * Mild contrast expansion.
     */
    rgb =
        (rgb - 0.5)
        * 1.12
        + 0.5;


    /*
     * Mild saturation increase.
     */
    float luminance =
        dot(
            rgb,
            vec3(
                0.2126,
                0.7152,
                0.0722
            )
        );


    rgb =
        mix(
            vec3(
                luminance
            ),
            rgb,
            1.12
        );


    /*
     * Small perceptual brightness lift.
     */
    rgb =
        pow(
            max(
                rgb,
                vec3(0.0)
            ),
            vec3(
                0.94
            )
        );


    fragColor =
        vec4(
            clamp(
                rgb,
                0.0,
                1.0
            ),
            color.a
        );
}
"#;


// ============================================================
// SHADER — HIGH CONTRAST
// ============================================================

const HIGH_CONTRAST_SHADER: &str = r#"
#version 300 es

precision mediump float;

in vec2 v_texcoord;

layout(location = 0)
out vec4 fragColor;

uniform sampler2D tex;


void main() {
    vec4 color =
        texture(
            tex,
            v_texcoord
        );

    vec3 rgb =
        (color.rgb - 0.5)
        * 1.35
        + 0.5;

    fragColor =
        vec4(
            clamp(
                rgb,
                0.0,
                1.0
            ),
            color.a
        );
}
"#;


// ============================================================
// SHADER — INVERT
// ============================================================

const INVERT_SHADER: &str = r#"
#version 300 es

precision mediump float;

in vec2 v_texcoord;

layout(location = 0)
out vec4 fragColor;

uniform sampler2D tex;


void main() {
    vec4 color =
        texture(
            tex,
            v_texcoord
        );

    fragColor =
        vec4(
            vec3(1.0)
            - color.rgb,
            color.a
        );
}
"#;


// ============================================================
// SHADER — SEPIA
// ============================================================

const SEPIA_SHADER: &str = r#"
#version 300 es

precision mediump float;

in vec2 v_texcoord;

layout(location = 0)
out vec4 fragColor;

uniform sampler2D tex;


void main() {
    vec4 color =
        texture(
            tex,
            v_texcoord
        );


    vec3 rgb;


    rgb.r =
        dot(
            color.rgb,
            vec3(
                0.393,
                0.769,
                0.189
            )
        );


    rgb.g =
        dot(
            color.rgb,
            vec3(
                0.349,
                0.686,
                0.168
            )
        );


    rgb.b =
        dot(
            color.rgb,
            vec3(
                0.272,
                0.534,
                0.131
            )
        );


    fragColor =
        vec4(
            clamp(
                rgb,
                0.0,
                1.0
            ),
            color.a
        );
}
"#;


// ============================================================
// CLI
// ============================================================

pub fn handle(
    args: &[String],
) -> Result<(), String>
{
    let command =
        args
            .first()
            .map(
                String::as_str
            )
            .unwrap_or(
                "info"
            );


    let result =
        match command {

            "info" => {
                info()?
            }


            "set" => {
                let filter =
                    args
                        .get(1)
                        .ok_or(
                            "Missing screen filter"
                        )?;


                set(
                    filter
                )?
            }


            "off" => {
                off()?
            }


            "apply" => {
                apply()?
            }


            _ => {
                return Err(
                    format!(
                        "Unknown screen filter command: {command}"
                    )
                );
            }
        };


    println!(
        "{}",
        serde_json::to_string(
            &result
        )
        .map_err(
            |error|
                error.to_string()
        )?
    );


    Ok(())
}
