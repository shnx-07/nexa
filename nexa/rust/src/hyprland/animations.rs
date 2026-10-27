use super::hypr_command;
use serde::Deserialize;
use std::env;
use std::fs;
use std::path::PathBuf;

#[allow(dead_code)]
#[derive(Debug, Deserialize, Default)]
struct MotionConfig {
    #[serde(default = "default_true")]
    enabled: bool,
    #[serde(default)]
    preset: String,
    #[serde(rename = "hyprAnimationProfile", default)]
    hypr_animation_profile: Option<String>,
    #[serde(default)]
    stiffness: f64,
    #[serde(default)]
    damping: f64,
}

fn default_true() -> bool {
    true
}

fn motion_config_path() -> PathBuf {
    if let Ok(home) = env::var("HOME") {
        PathBuf::from(home)
            .join(".config")
            .join("nexa")
            .join("config")
            .join("motion.json")
    } else {
        PathBuf::from("/tmp/motion.json")
    }
}

pub struct ProfileInfo {
    pub id: &'static str,
    pub name: &'static str,
    pub description: &'static str,
}

pub const ALL_PROFILES: &[ProfileInfo] = &[
    ProfileInfo {
        id: "fluid",
        name: "Apple Fluid",
        description: "Natural damping with smooth workspace slide and subtle window pop-in",
    },
    ProfileInfo {
        id: "bouncy",
        name: "Elastic Bouncy",
        description: "Playful spring physics with elastic recoil overshoot on workspaces and windows",
    },
    ProfileInfo {
        id: "snappy",
        name: "Crisp Snappy",
        description: "Ultra-fast 120ms transitions designed for maximum productivity",
    },
    ProfileInfo {
        id: "slidefade",
        name: "Modern Slide & Fade",
        description: "Elegant combined slide and opacity crossfade (GNOME 45+ / iOS style)",
    },
    ProfileInfo {
        id: "cinematic",
        name: "Cinematic Gentle",
        description: "Luxurious, velvety smooth 400ms easing curves with wide dynamic range",
    },
    ProfileInfo {
        id: "pop",
        name: "Arcade Pop",
        description: "Punchy, dynamic window expansion from center (popin 50%) with fast slide",
    },
    ProfileInfo {
        id: "minimal",
        name: "Minimal Fade",
        description: "Zero sliding or camera movement; windows and workspaces transition with pure opacity",
    },
    ProfileInfo {
        id: "game",
        name: "Game Mode",
        description: "Instantaneous 0ms cut; all animations disabled for minimum latency and maximum FPS",
    },
];

pub fn print_profiles() {
    println!("\nAvailable NEXA Hyprland Animation Profiles:\n");
    for p in ALL_PROFILES {
        println!("  • {:<12} {:<24} {}", p.id, format!("({})", p.name), p.description);
    }
    println!("\nUsage: nexad hypr animations profile <name>\n");
}

/// Applies a named animation profile to Hyprland on the fly via Lua `eval`.
pub fn set_profile(name: &str) -> Result<(), String> {
    let script = match name {
        // 1. Apple Fluid: Organic harmonic easing
        "fluid" | "apple" => {
            r#"
            hl.config({ animations = { enabled = true } })
            hl.curve("nexa_fluid", { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.05 } } })
            hl.animation({ leaf = "workspaces", enabled = true, speed = 5.0, bezier = "nexa_fluid", style = "slide" })
            hl.animation({ leaf = "workspacesIn", enabled = true, speed = 5.0, bezier = "nexa_fluid", style = "slide" })
            hl.animation({ leaf = "workspacesOut", enabled = true, speed = 5.0, bezier = "nexa_fluid", style = "slide" })
            hl.animation({ leaf = "windows", enabled = true, speed = 4.2, bezier = "nexa_fluid", style = "popin 85%" })
            hl.animation({ leaf = "windowsIn", enabled = true, speed = 4.2, bezier = "nexa_fluid", style = "popin 85%" })
            hl.animation({ leaf = "windowsOut", enabled = true, speed = 3.5, bezier = "nexa_fluid", style = "popin 85%" })
            hl.animation({ leaf = "windowsMove", enabled = true, speed = 4.5, bezier = "nexa_fluid" })
            hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 4.5, bezier = "nexa_fluid", style = "slidevert" })
            hl.animation({ leaf = "fade", enabled = true, speed = 3.5, bezier = "nexa_fluid" })
            "#
        }

        // 2. Elastic Bouncy: Spring recoil with dynamic overshoot
        "bouncy" | "elastic" => {
            r#"
            hl.config({ animations = { enabled = true } })
            hl.curve("nexa_bouncy", { type = "bezier", points = { { 0.68, -0.6 }, { 0.32, 1.6 } } })
            hl.animation({ leaf = "workspaces", enabled = true, speed = 6.5, bezier = "nexa_bouncy", style = "slide" })
            hl.animation({ leaf = "workspacesIn", enabled = true, speed = 6.5, bezier = "nexa_bouncy", style = "slide" })
            hl.animation({ leaf = "workspacesOut", enabled = true, speed = 6.5, bezier = "nexa_bouncy", style = "slide" })
            hl.animation({ leaf = "windows", enabled = true, speed = 5.5, bezier = "nexa_bouncy", style = "popin 72%" })
            hl.animation({ leaf = "windowsIn", enabled = true, speed = 5.5, bezier = "nexa_bouncy", style = "popin 72%" })
            hl.animation({ leaf = "windowsOut", enabled = true, speed = 4.5, bezier = "nexa_bouncy", style = "popin 72%" })
            hl.animation({ leaf = "windowsMove", enabled = true, speed = 5.5, bezier = "nexa_bouncy" })
            hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 5.5, bezier = "nexa_bouncy", style = "slidevert" })
            hl.animation({ leaf = "fade", enabled = true, speed = 4.0, bezier = "nexa_bouncy" })
            "#
        }

        // 3. Crisp Snappy: High productivity, 120ms sharp curves
        "snappy" | "fast" => {
            r#"
            hl.config({ animations = { enabled = true } })
            hl.curve("nexa_snappy", { type = "bezier", points = { { 0.2, 0.9 }, { 0.1, 1.0 } } })
            hl.animation({ leaf = "workspaces", enabled = true, speed = 2.4, bezier = "nexa_snappy", style = "slide" })
            hl.animation({ leaf = "workspacesIn", enabled = true, speed = 2.4, bezier = "nexa_snappy", style = "slide" })
            hl.animation({ leaf = "workspacesOut", enabled = true, speed = 2.4, bezier = "nexa_snappy", style = "slide" })
            hl.animation({ leaf = "windows", enabled = true, speed = 2.2, bezier = "nexa_snappy", style = "popin 90%" })
            hl.animation({ leaf = "windowsIn", enabled = true, speed = 2.2, bezier = "nexa_snappy", style = "popin 90%" })
            hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.8, bezier = "nexa_snappy", style = "popin 90%" })
            hl.animation({ leaf = "windowsMove", enabled = true, speed = 2.5, bezier = "nexa_snappy" })
            hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 2.4, bezier = "nexa_snappy", style = "slidevert" })
            hl.animation({ leaf = "fade", enabled = true, speed = 1.8, bezier = "nexa_snappy" })
            "#
        }

        // 4. Modern Slide & Fade: Combined translation and opacity crossfade
        "slidefade" | "fade-slide" => {
            r#"
            hl.config({ animations = { enabled = true } })
            hl.curve("nexa_slidefade", { type = "bezier", points = { { 0.16, 1.0 }, { 0.3, 1.0 } } })
            hl.animation({ leaf = "workspaces", enabled = true, speed = 4.8, bezier = "nexa_slidefade", style = "slidefade 20%" })
            hl.animation({ leaf = "workspacesIn", enabled = true, speed = 4.8, bezier = "nexa_slidefade", style = "slidefade 20%" })
            hl.animation({ leaf = "workspacesOut", enabled = true, speed = 4.8, bezier = "nexa_slidefade", style = "slidefade 20%" })
            hl.animation({ leaf = "windows", enabled = true, speed = 4.0, bezier = "nexa_slidefade", style = "slidefade 15%" })
            hl.animation({ leaf = "windowsIn", enabled = true, speed = 4.0, bezier = "nexa_slidefade", style = "slidefade 15%" })
            hl.animation({ leaf = "windowsOut", enabled = true, speed = 3.2, bezier = "nexa_slidefade", style = "slidefade 15%" })
            hl.animation({ leaf = "windowsMove", enabled = true, speed = 4.5, bezier = "nexa_slidefade" })
            hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 4.5, bezier = "nexa_slidefade", style = "slidefadevert 25%" })
            hl.animation({ leaf = "fade", enabled = true, speed = 3.0, bezier = "nexa_slidefade" })
            "#
        }

        // 5. Cinematic Gentle: Velvety smooth, slow deceleration
        "cinematic" | "gentle" | "smooth" => {
            r#"
            hl.config({ animations = { enabled = true } })
            hl.curve("nexa_gentle", { type = "bezier", points = { { 0.25, 1.0 }, { 0.5, 1.0 } } })
            hl.animation({ leaf = "workspaces", enabled = true, speed = 7.5, bezier = "nexa_gentle", style = "slide" })
            hl.animation({ leaf = "workspacesIn", enabled = true, speed = 7.5, bezier = "nexa_gentle", style = "slide" })
            hl.animation({ leaf = "workspacesOut", enabled = true, speed = 7.5, bezier = "nexa_gentle", style = "slide" })
            hl.animation({ leaf = "windows", enabled = true, speed = 6.2, bezier = "nexa_gentle", style = "popin 80%" })
            hl.animation({ leaf = "windowsIn", enabled = true, speed = 6.2, bezier = "nexa_gentle", style = "popin 80%" })
            hl.animation({ leaf = "windowsOut", enabled = true, speed = 5.0, bezier = "nexa_gentle", style = "popin 80%" })
            hl.animation({ leaf = "windowsMove", enabled = true, speed = 6.5, bezier = "nexa_gentle" })
            hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 6.5, bezier = "nexa_gentle", style = "slidevert" })
            hl.animation({ leaf = "fade", enabled = true, speed = 5.0, bezier = "nexa_gentle" })
            "#
        }

        // 6. Arcade Pop: Deep scale pop-in from center
        "pop" | "arcade" => {
            r#"
            hl.config({ animations = { enabled = true } })
            hl.curve("nexa_pop", { type = "bezier", points = { { 0.34, 1.56 }, { 0.64, 1.0 } } })
            hl.animation({ leaf = "workspaces", enabled = true, speed = 4.5, bezier = "nexa_pop", style = "slide" })
            hl.animation({ leaf = "workspacesIn", enabled = true, speed = 4.5, bezier = "nexa_pop", style = "slide" })
            hl.animation({ leaf = "workspacesOut", enabled = true, speed = 4.5, bezier = "nexa_pop", style = "slide" })
            hl.animation({ leaf = "windows", enabled = true, speed = 4.2, bezier = "nexa_pop", style = "popin 50%" })
            hl.animation({ leaf = "windowsIn", enabled = true, speed = 4.2, bezier = "nexa_pop", style = "popin 50%" })
            hl.animation({ leaf = "windowsOut", enabled = true, speed = 3.2, bezier = "nexa_pop", style = "popin 50%" })
            hl.animation({ leaf = "windowsMove", enabled = true, speed = 4.5, bezier = "nexa_pop" })
            hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 4.2, bezier = "nexa_pop", style = "slidevert" })
            hl.animation({ leaf = "fade", enabled = true, speed = 3.0, bezier = "nexa_pop" })
            "#
        }

        // 7. Minimal Fade: Zero motion translation, pure opacity
        "minimal" | "fade" => {
            r#"
            hl.config({ animations = { enabled = true } })
            hl.curve("nexa_linear", { type = "bezier", points = { { 0.0, 0.0 }, { 1.0, 1.0 } } })
            hl.animation({ leaf = "workspaces", enabled = true, speed = 3.5, bezier = "nexa_linear", style = "fade" })
            hl.animation({ leaf = "workspacesIn", enabled = true, speed = 3.5, bezier = "nexa_linear", style = "fade" })
            hl.animation({ leaf = "workspacesOut", enabled = true, speed = 3.5, bezier = "nexa_linear", style = "fade" })
            hl.animation({ leaf = "windows", enabled = true, speed = 3.0, bezier = "nexa_linear", style = "fade" })
            hl.animation({ leaf = "windowsIn", enabled = true, speed = 3.0, bezier = "nexa_linear", style = "fade" })
            hl.animation({ leaf = "windowsOut", enabled = true, speed = 2.5, bezier = "nexa_linear", style = "fade" })
            hl.animation({ leaf = "windowsMove", enabled = true, speed = 3.5, bezier = "nexa_linear" })
            hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 3.5, bezier = "nexa_linear", style = "fade" })
            hl.animation({ leaf = "fade", enabled = true, speed = 2.8, bezier = "nexa_linear" })
            "#
        }

        // 8. Game / Off: 0ms instant cut
        "game" | "off" => {
            r#"
            hl.config({ animations = { enabled = false } })
            "#
        }

        other => return Err(format!("Unknown animation profile: '{other}'. Run 'nexad hypr animations list' to view available profiles.")),
    };

    // Compact single-line eval payload for Hyprland IPC
    let clean_script: String = script
        .lines()
        .map(|l| l.trim())
        .filter(|l| !l.is_empty())
        .collect::<Vec<&str>>()
        .join("; ");

    let cmd = format!("eval {clean_script}");
    let resp = hypr_command(&cmd)?;
    if resp != "ok" && !resp.is_empty() {
        eprintln!("[NEXA Animations] eval response: {resp}");
    } else {
        println!("[NEXA Animations] Applied profile: {name}");
    }

    Ok(())
}

/// Reads the user's active Nexa Motion & Physics configuration (`motion.json`)
/// and automatically aligns Hyprland compositor animations with Quickshell.
pub fn sync_motion_config() -> Result<(), String> {
    let p = motion_config_path();
    if !p.exists() {
        return set_profile("fluid");
    }

    let bytes = fs::read(&p).map_err(|e| format!("Failed to read motion.json: {e}"))?;
    let config: MotionConfig = serde_json::from_slice(&bytes)
        .map_err(|e| format!("Failed to parse motion.json: {e}"))?;

    if !config.enabled {
        return set_profile("off");
    }

    if let Some(profile) = config.hypr_animation_profile {
        if !profile.is_empty() {
            return set_profile(&profile);
        }
    }

    match config.preset.as_str() {
        "fluid" => set_profile("fluid"),
        "snappy" => set_profile("snappy"),
        "bouncy" => set_profile("bouncy"),
        "gentle" => set_profile("cinematic"),
        _ => set_profile("fluid"),
    }
}
