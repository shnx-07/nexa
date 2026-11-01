use serde::{Deserialize, Serialize};
use std::env;
use std::fs;
use std::path::PathBuf;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ConstellationConfig {
    #[serde(default = "default_enabled")]
    pub enabled: bool,
    #[serde(default = "default_style")]
    pub style: String, // "none", "simple_line", "constellation"
    #[serde(default = "default_mode")]
    pub mode: String, // "workspaces", "particles", "audio"
    #[serde(default = "default_direction")]
    pub direction: String, // "left-to-right", "right-to-left"
    #[serde(default = "default_speed")]
    pub speed: f64,
    #[serde(default = "default_glow_intensity")]
    pub glow_intensity: f64,
    #[serde(default = "default_particle_count")]
    pub particle_count: usize,
    #[serde(default = "default_line_opacity")]
    pub line_opacity: f64,
}

fn default_enabled() -> bool {
    true
}

fn default_style() -> String {
    "constellation".to_string()
}

fn default_mode() -> String {
    "workspaces".to_string()
}

fn default_direction() -> String {
    "left-to-right".to_string()
}

fn default_speed() -> f64 {
    1.0
}

fn default_glow_intensity() -> f64 {
    0.85
}

fn default_particle_count() -> usize {
    8
}

fn default_line_opacity() -> f64 {
    0.35
}

impl Default for ConstellationConfig {
    fn default() -> Self {
        Self {
            enabled: default_enabled(),
            style: default_style(),
            mode: default_mode(),
            direction: default_direction(),
            speed: default_speed(),
            glow_intensity: default_glow_intensity(),
            particle_count: default_particle_count(),
            line_opacity: default_line_opacity(),
        }
    }
}

pub fn config_path() -> PathBuf {
    let home = env::var("HOME").unwrap_or_else(|_| ".".to_string());
    PathBuf::from(home)
        .join(".config")
        .join("nexa")
        .join("config")
        .join("decorations")
        .join("constellation_rail.json")
}

pub fn load_config() -> ConstellationConfig {
    let p = config_path();
    if let Ok(bytes) = fs::read(&p) {
        if let Ok(cfg) = serde_json::from_slice::<ConstellationConfig>(&bytes) {
            return cfg;
        }
    }
    ConstellationConfig::default()
}

pub fn save_config(cfg: &ConstellationConfig) -> Result<(), String> {
    let p = config_path();
    if let Some(parent) = p.parent() {
        let _ = fs::create_dir_all(parent);
    }
    let data = serde_json::to_vec_pretty(cfg)
        .map_err(|e| format!("Failed to serialize constellation config: {e}"))?;
    fs::write(&p, data).map_err(|e| format!("Failed to write constellation config: {e}"))?;
    Ok(())
}
