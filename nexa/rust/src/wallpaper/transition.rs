use std::{
    path::Path,
    process::Command,
    time::{SystemTime, UNIX_EPOCH},
};

/// All 40 GPU transitions supported by skwd-paper.
pub const EFFECTS: &[&str] = &[
    "fade",
    "pixelate",
    "iris",
    "glitch",
    "voronoi-shatter",
    "heat-melt",
    "plasma-flow",
    "ink-splash",
    "smoke",
    "chromatic-bloom",
    "inkwell-drop",
    "pixelfade-wave",
    "soft-warp-fade",
    "zoom-blur-pull",
    "mosaic-tumble",
    "crosswarp",
    "morph",
    "circle-crop",
    "colour-distance",
    "crossfade",
    "directional",
    "directional-scaled",
    "glitch-displace",
    "polka-dots-curtain",
    "puzzle-right",
    "crosshatch",
    "directional-wipe",
    "fadecolor",
    "parametric-glitch",
    "perlin",
    "randomsquares",
    "sand-bloom",
    "sand-maelstrom",
    "sand-murmuration",
    "sand-donut",
    "sand-globe",
    "sand-helix",
    "sand-galaxy",
    "sand-mobius",
    "sand-tornado",
];

/// Represents transition CLI configuration for skwd-paper.
#[derive(Debug, Clone)]
pub struct TransitionEffect {
    pub name: &'static str,
    pub args: Vec<String>,
}

pub struct TransitionEngine;

impl Default for TransitionEngine {
    fn default() -> Self {
        Self::new()
    }
}

impl TransitionEngine {
    pub fn new() -> Self {
        Self
    }

    /// Selects a randomized transition effect from the 40 GPU shaders.
    pub fn random_effect(&self) -> TransitionEffect {
        let nanos = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .map(|d| d.subsec_nanos() as usize)
            .unwrap_or(0);

        let selected = EFFECTS[nanos % EFFECTS.len()];
        self.build_effect(selected, nanos)
    }

    /// Builds command arguments for a specific transition effect.
    pub fn build_effect(&self, name: &str, _seed: usize) -> TransitionEffect {
        let valid_effect = EFFECTS
            .iter()
            .copied()
            .find(|&e| e == name)
            .unwrap_or("fade");

        TransitionEffect {
            name: valid_effect,
            args: vec![
                "--effect".into(),
                valid_effect.to_string(),
                "--duration-ms".into(),
                "950".into(),
            ],
        }
    }
}

/// Orchestrates wallpaper transitions via skwd-paper Vulkan engine.
pub fn apply_with_handshake(
    target_path: &Path,
    target_kind: &str,
    monitor_target: &str,
    _prev_kind: &str,
    _prev_thumb: Option<&Path>,
    _target_thumb: Option<&Path>,
    is_restore: bool,
) -> Result<(), String> {
    let _ = Command::new("pkill").arg("-x").arg("mpvpaper").status();
    let _ = Command::new("pkill").arg("-x").arg("awww-daemon").status();

    let target = if monitor_target == "ALL" || monitor_target == "*" {
        "*"
    } else {
        monitor_target
    };

    let mut cmd = Command::new("skwd-paper-v2");
    cmd.arg("apply");
    cmd.arg(target);
    cmd.arg(target_path);

    match target_kind {
        "image" => {
            cmd.args(["--kind", "static"]);
        }
        "gif" | "video" => {
            cmd.args(["--kind", "video"]);
        }
        "we" => {
            cmd.args(["--kind", "we"]);
        }
        _ => {}
    }

    if is_restore {
        cmd.args(["--fill-mode", "fill", "--mute", "true"]);
    } else {
        let engine = TransitionEngine::new();
        let effect = engine.random_effect();

        cmd.args([
            "--replace-all",
            "--effect",
            effect.name,
            "--duration-ms",
            "950",
            "--fill-mode",
            "fill",
            "--mute",
            "true",
        ]);
    }

    let status = cmd
        .status()
        .map_err(|e| format!("Failed to run skwd-paper-v2: {e}"))?;

    if !status.success() {
        let mut fallback = Command::new("skwd-paper-v2");
        fallback.arg("apply").arg(target).arg(target_path);
        match target_kind {
            "image" => {
                fallback.args(["--kind", "static"]);
            }
            "gif" | "video" => {
                fallback.args(["--kind", "video"]);
            }
            "we" => {
                fallback.args(["--kind", "we"]);
            }
            _ => {}
        }
        fallback.args(["--fill-mode", "fill", "--mute", "true"]);
        let _ = fallback.status();
    }

    Ok(())
}
