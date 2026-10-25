use std::{
    os::unix::process::CommandExt,
    path::Path,
    process::{Command, Stdio},
    thread,
    time::{Duration, SystemTime, UNIX_EPOCH},
};

/// Represents an awww transition configuration with arguments.
#[derive(Debug, Clone)]
pub struct TransitionEffect {
    pub name: &'static str,
    pub args: Vec<String>,
}

/// Every effect id accepted by `build_effect`.
/// The first 6 are the originals; the rest are new variations.
const EFFECTS: &[&str] = &[
    // --- original ---
    "wave_dynamic",
    "circular_iris",
    "outer_iris",
    "curtain_slide",
    "cubic_wipe",
    "smooth_fade",
    "random_grow",
    // --- new ---
    "diagonal_wipe",
    "slow_wave",
    "fast_wave",
    "ripple_wave",
    "backwash_wave",
    "corner_grow",
    "scatter_grow",
    "bouncy_grow",
    "corner_outer",
    "snappy_fade",
    "slow_fade",
    "bouncy_slide",
    "fast_slide",
    "expo_wipe",
    "pixel_step",
];

const ANGLES: [&str; 8] = ["0", "45", "90", "135", "180", "225", "270", "315"];
const DIAGONALS: [&str; 4] = ["45", "135", "225", "315"];
const POSITIONS: [&str; 5] = [
    "center",
    "top-left",
    "top-right",
    "bottom-left",
    "bottom-right",
];
const CORNERS: [&str; 4] = ["top-left", "top-right", "bottom-left", "bottom-right"];
// Float coords (x,y in 0..1) for off-center grows.
const SCATTER: [&str; 6] = [
    "0.25,0.25",
    "0.75,0.25",
    "0.25,0.75",
    "0.75,0.75",
    "0.5,0.2",
    "0.5,0.8",
];
const DIRECTIONS: [&str; 4] = ["left", "right", "top", "bottom"];

// Common bezier curves
const EASE_IN_OUT: &str = ".42,0,.58,1";
const EASE_OUT_EXPO: &str = ".16,1,.3,1";
const EASE_OUT_QUAD: &str = ".25,1,.5,1";
const SNAPPY: &str = ".4,0,.2,1";
const EXPO_IN_OUT: &str = ".87,0,.13,1";
const OVERSHOOT: &str = ".34,1.56,.64,1";
const SOFT_IN_OUT: &str = ".65,0,.35,1";

/// Dynamic transition engine detecting hardware display refresh rates
/// and building smooth bezier curves for wallpaper animations.
pub struct TransitionEngine {
    pub fps: u32,
}

impl Default for TransitionEngine {
    fn default() -> Self {
        Self::new()
    }
}

impl TransitionEngine {
    pub fn new() -> Self {
        Self {
            fps: detect_refresh_rate(),
        }
    }

    /// Selects a randomized, aesthetically rich transition effect.
    pub fn random_effect(&self) -> TransitionEffect {
        let nanos = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .map(|d| d.subsec_nanos() as usize)
            .unwrap_or(0);

        // Light mixing so the low bits aren't correlated with the derived picks below.
        let mixed = nanos ^ (nanos >> 7) ^ (nanos >> 13);
        let selected = EFFECTS[mixed % EFFECTS.len()];
        self.build_effect(selected, nanos)
    }

    /// Shared argument builder: type, duration, bezier, plus any extra flag/value pairs.
    fn args(&self, ty: &str, duration: &str, bezier: &str, extra: &[(&str, &str)]) -> Vec<String> {
        let mut v: Vec<String> = vec![
            "--transition-type".into(),
            ty.into(),
            "--transition-duration".into(),
            duration.into(),
            "--transition-fps".into(),
            self.fps.to_string(),
            "--transition-bezier".into(),
            bezier.into(),
            "-f".into(),
            "Bilinear".into(),
        ];
        for (flag, val) in extra {
            v.push((*flag).into());
            v.push((*val).into());
        }
        v
    }

    /// Builds the specific command arguments for a transition effect.
    pub fn build_effect(&self, name: &str, seed: usize) -> TransitionEffect {
        let angle = ANGLES[(seed / 3) % ANGLES.len()];
        let diag = DIAGONALS[(seed / 3) % DIAGONALS.len()];
        let pos = POSITIONS[(seed / 5) % POSITIONS.len()];
        let corner = CORNERS[(seed / 5) % CORNERS.len()];
        let scatter = SCATTER[(seed / 5) % SCATTER.len()];
        let dir = DIRECTIONS[(seed / 7) % DIRECTIONS.len()];

        match name {
            // ---------------- original effects ----------------
            "wave_dynamic" => TransitionEffect {
                name: "wave",
                args: self.args(
                    "wave",
                    "1.2",
                    EASE_IN_OUT,
                    &[
                        ("--transition-angle", angle),
                        ("--transition-wave", "35,18"),
                    ],
                ),
            },
            "circular_iris" => TransitionEffect {
                name: "grow",
                args: self.args("grow", "1.2", EASE_OUT_EXPO, &[("--transition-pos", pos)]),
            },
            "outer_iris" => TransitionEffect {
                name: "outer",
                args: self.args(
                    "outer",
                    "1.2",
                    EASE_OUT_EXPO,
                    &[("--transition-pos", "center")],
                ),
            },
            "curtain_slide" => TransitionEffect {
                name: dir,
                args: self.args(dir, "1.1", EASE_OUT_EXPO, &[]),
            },
            "smooth_fade" => TransitionEffect {
                name: "fade",
                args: self.args("fade", "1.0", EASE_OUT_QUAD, &[]),
            },
            "random_grow" => TransitionEffect {
                name: "any",
                args: self.args("any", "1.2", EASE_OUT_EXPO, &[]),
            },

            // ---------------- new effects ----------------
            // Diagonal wipe, only at 45° multiples
            "diagonal_wipe" => TransitionEffect {
                name: "diagonal_wipe",
                args: self.args("wipe", "1.3", SOFT_IN_OUT, &[("--transition-angle", diag)]),
            },
            // Long, lazy, wide waves
            "slow_wave" => TransitionEffect {
                name: "slow_wave",
                args: self.args(
                    "wave",
                    "1.8",
                    EASE_IN_OUT,
                    &[
                        ("--transition-angle", angle),
                        ("--transition-wave", "60,30"),
                    ],
                ),
            },
            // Quick, tight waves
            "fast_wave" => TransitionEffect {
                name: "fast_wave",
                args: self.args(
                    "wave",
                    "0.8",
                    SNAPPY,
                    &[
                        ("--transition-angle", angle),
                        ("--transition-wave", "20,10"),
                    ],
                ),
            },
            // Very tight, high-frequency ripple
            "ripple_wave" => TransitionEffect {
                name: "ripple_wave",
                args: self.args(
                    "wave",
                    "1.4",
                    EASE_OUT_QUAD,
                    &[
                        ("--transition-angle", angle),
                        ("--transition-wave", "12,45"),
                    ],
                ),
            },
            // Wave sweeping the opposite way (angle + 180°)
            "backwash_wave" => {
                let a: usize = angle.parse().unwrap_or(0);
                let rev = ((a + 180) % 360).to_string();
                TransitionEffect {
                    name: "backwash_wave",
                    args: self.args(
                        "wave",
                        "1.5",
                        SOFT_IN_OUT,
                        &[("--transition-angle", &rev), ("--transition-wave", "40,22")],
                    ),
                }
            }
            // Grow from a screen corner only
            "corner_grow" => TransitionEffect {
                name: "corner_grow",
                args: self.args(
                    "grow",
                    "1.3",
                    EASE_OUT_EXPO,
                    &[("--transition-pos", corner)],
                ),
            },
            // Grow from an off-center point
            "scatter_grow" => TransitionEffect {
                name: "scatter_grow",
                args: self.args(
                    "grow",
                    "1.2",
                    EASE_OUT_EXPO,
                    &[("--transition-pos", scatter)],
                ),
            },
            // Grow with a springy overshoot
            "bouncy_grow" => TransitionEffect {
                name: "bouncy_grow",
                args: self.args("grow", "1.4", OVERSHOOT, &[("--transition-pos", pos)]),
            },
            // Outer (closing iris) from a corner
            "corner_outer" => TransitionEffect {
                name: "corner_outer",
                args: self.args(
                    "outer",
                    "1.3",
                    EASE_OUT_EXPO,
                    &[("--transition-pos", corner)],
                ),
            },
            // Quick crossfade
            "snappy_fade" => TransitionEffect {
                name: "snappy_fade",
                args: self.args("fade", "0.5", SNAPPY, &[]),
            },
            // Slow, dreamy crossfade
            "slow_fade" => TransitionEffect {
                name: "slow_fade",
                args: self.args("fade", "2.0", EASE_IN_OUT, &[]),
            },
            // Directional slide with overshoot
            "bouncy_slide" => TransitionEffect {
                name: "bouncy_slide",
                args: self.args(dir, "1.2", OVERSHOOT, &[]),
            },
            // Very fast directional slide
            "fast_slide" => TransitionEffect {
                name: "fast_slide",
                args: self.args(dir, "0.6", SNAPPY, &[]),
            },
            // Aggressive ease-in-out-expo wipe at any angle
            "expo_wipe" => TransitionEffect {
                name: "expo_wipe",
                args: self.args("wipe", "0.9", EXPO_IN_OUT, &[("--transition-angle", angle)]),
            },
            // Retro stepped "simple" blend (step-based, not duration-based)
            "pixel_step" => TransitionEffect {
                name: "simple",
                args: self.args("simple", "1.0", EASE_IN_OUT, &[("--transition-step", "20")]),
            },

            // Fallback: plain wipe
            _ => TransitionEffect {
                name: "wipe",
                args: self.args("wipe", "1.2", EASE_IN_OUT, &[("--transition-angle", angle)]),
            },
        }
    }
}

/// Detects the active monitor refresh rate via hyprctl (defaulting to 60).
pub fn detect_refresh_rate() -> u32 {
    if let Ok(output) = Command::new("hyprctl").arg("monitors").output() {
        if let Ok(text) = String::from_utf8(output.stdout) {
            for line in text.lines() {
                if let Some(pos) = line.find('@') {
                    let rest = &line[pos + 1..];
                    let rate_str: String =
                        rest.chars().take_while(|c| c.is_ascii_digit()).collect();
                    if let Ok(hz) = rate_str.parse::<u32>() {
                        if (30..=360).contains(&hz) {
                            return hz;
                        }
                    }
                }
            }
        }
    }
    60
}

/// Orchestrates double-buffered wallpaper transitions between images, GIFs, and MP4 videos.
pub fn apply_with_handshake(
    target_path: &Path,
    target_kind: &str,
    monitor_target: &str,
    prev_kind: &str,
    prev_thumb: Option<&Path>,
    target_thumb: Option<&Path>,
) -> Result<(), String> {
    let engine = TransitionEngine::new();
    let effect = engine.random_effect();

    let target = if monitor_target == "*" {
        "ALL"
    } else {
        monitor_target
    };

    if target_kind == "image" || target_kind == "gif" {
        // 1. If transitioning away from video, prime awww with the video's poster frame
        //    so awww's buffer does NOT expose the previous old image behind mpvpaper.
        if prev_kind == "video" {
            if let Some(thumb) = prev_thumb {
                if thumb.is_file() {
                    let _ = Command::new("awww").arg("unpause").status();
                    let mut prime = Command::new("awww");
                    prime.arg("img");
                    if monitor_target != "*" && monitor_target != "ALL" {
                        prime.args(["-o", monitor_target]);
                    }
                    prime
                        .arg(thumb)
                        .args(["--transition-type", "none", "-f", "Bilinear"]);
                    let _ = prime.status();
                }
            }
        } else {
            let _ = Command::new("awww").arg("unpause").status();
        }

        // 2. Trigger the fluid transition to the new target
        let mut cmd = Command::new("awww");
        cmd.arg("img");
        if monitor_target != "*" && monitor_target != "ALL" {
            cmd.args(["-o", monitor_target]);
        }
        cmd.arg(target_path);
        cmd.args(&effect.args);

        let status = cmd
            .status()
            .map_err(|e| format!("Failed to run awww: {e}"))?;
        if !status.success() {
            return Err("awww failed to display wallpaper".to_string());
        }

        // 3. Gracefully stop mpvpaper after awww's transition has begun
        if prev_kind == "video" {
            thread::sleep(Duration::from_millis(60));
            let _ = Command::new("pkill").arg("-x").arg("mpvpaper").status();
        }
    } else if target_kind == "video" {
        // Target is video (MP4)
        // 1. Transition awww into the video's poster thumbnail first!
        if let Some(thumb) = target_thumb {
            if thumb.is_file() {
                let _ = Command::new("awww").arg("unpause").status();
                let mut cmd = Command::new("awww");
                cmd.arg("img");
                if monitor_target != "*" && monitor_target != "ALL" {
                    cmd.args(["-o", monitor_target]);
                }
                cmd.arg(thumb);
                cmd.args(&effect.args);
                let _ = cmd.status();
            }
        }

        // 2. Stop any existing video wallpaper instance
        let _ = Command::new("pkill").arg("-x").arg("mpvpaper").status();

        // 3. Seamlessly spawn mpvpaper over the matching poster frame
        let _ = Command::new("mpvpaper")
        .process_group(0)
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .arg("-p")
        .args([
            "-o",
            "no-audio loop-file=inf hwdec=auto-safe profile=fast opengl-pbo=yes framedrop=vo video-sync=desync demuxer-max-bytes=20M demuxer-max-back-bytes=5M input-terminal=no input-default-bindings=no",
            target,
        ])
        .arg(target_path)
        .spawn();

        // 4. Pause awww after mpvpaper takes over to conserve system resources
        thread::spawn(|| {
            thread::sleep(Duration::from_millis(1500));
            let _ = Command::new("awww").arg("pause").status();
        });
    }

    Ok(())
}
