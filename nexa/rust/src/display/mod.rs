#![allow(unused_imports, dead_code)]

pub mod backend;
pub mod config;
pub mod discovery;
pub mod events;
pub mod manager;
pub mod model;
pub mod planner;
pub mod safety;

pub use backend::*;
pub use config::*;
pub use discovery::*;
pub use events::*;
pub use manager::*;
pub use model::*;
pub use planner::*;
pub use safety::*;

use serde_json::{json, Value};
use std::path::PathBuf;
use std::sync::Arc;

/// Entry point for `nexad display <args>`.
pub fn run_cli(args: &[String]) -> i32 {
    let mut rest: Vec<&str> = args.iter().map(String::as_str).collect();
    if rest.first() == Some(&"display") {
        rest.remove(0);
    }

    let json_output = rest.iter().any(|a| *a == "--json");
    let pretty = rest.iter().any(|a| *a == "--pretty");
    rest.retain(|a| !matches!(*a, "--json" | "--pretty"));

    let cmd = rest.first().copied().unwrap_or("info");
    let config_path = DisplayConfigStore::default_config_path();

    match cmd {
        "info" | "status" => {
            match capture_info(&config_path) {
                Ok(doc) => {
                    if pretty {
                        println!("{}", serde_json::to_string_pretty(&doc).unwrap_or_else(|_| doc.to_string()));
                    } else {
                        println!("{doc}");
                    }
                    0
                }
                Err(e) => {
                    if json_output {
                        println!("{}", json!({"error": e.to_string()}));
                    } else {
                        eprintln!("[NexaDisplay] Error querying display info: {e}");
                    }
                    1
                }
            }
        }

        "daemon" => {
            println!("[NexaDisplay] Starting Display Manager Daemon...");
            match DisplayManager::new(&config_path) {
                Ok(mgr) => {
                    mgr.run_background_loop();
                    0
                }
                Err(e) => {
                    eprintln!("[NexaDisplay] Failed to start daemon: {e}");
                    1
                }
            }
        }

        "mode" | "apply" | "set-mode" => {
            let mode_str = match rest.get(1) {
                Some(m) => *m,
                None => {
                    eprintln!("Usage: nexad display mode <extend|mirror|internal-only|external-only> [right|left|above|below]");
                    return 2;
                }
            };

            let mode = match mode_str.to_lowercase().as_str() {
                "extend" => ProjectionMode::Extend,
                "mirror" => ProjectionMode::Mirror,
                "internal-only" | "internal" => ProjectionMode::InternalOnly,
                "external-only" | "external" | "clamshell" => ProjectionMode::ExternalOnly,
                other => {
                    eprintln!("Unknown projection mode: {other}. Options: extend, mirror, internal-only, external-only");
                    return 2;
                }
            };

            let direction = rest.get(2).and_then(|d| match d.to_lowercase().as_str() {
                "left" => Some(ExtendDirection::Left),
                "right" => Some(ExtendDirection::Right),
                "above" => Some(ExtendDirection::Above),
                "below" => Some(ExtendDirection::Below),
                _ => None,
            });

            match DisplayManager::new(&config_path) {
                Ok(mgr) => match mgr.apply_mode(mode, direction) {
                    Ok(()) => {
                        if json_output {
                            println!("{}", json!({"status": "ok", "mode": mode.to_string()}));
                        } else {
                            println!("Successfully applied projection mode: {mode}");
                        }
                        0
                    }
                    Err(e) => {
                        if json_output {
                            println!("{}", json!({"status": "error", "message": e.to_string()}));
                        } else {
                            eprintln!("Failed to apply mode {mode}: {e}");
                        }
                        1
                    }
                },
                Err(e) => {
                    eprintln!("Failed to initialize display manager: {e}");
                    1
                }
            }
        }

        "scale" => {
            let monitor_name = match rest.get(1) {
                Some(m) => *m,
                None => {
                    eprintln!("Usage: nexad display scale <monitor_name> <scale_value (e.g. 1.25)>");
                    return 2;
                }
            };
            let scale_val: f32 = match rest.get(2).and_then(|s| s.parse().ok()) {
                Some(s) if s > 0.0 && s <= 8.0 => s,
                _ => {
                    eprintln!("Invalid scale value (must be between 0.1 and 8.0)");
                    return 2;
                }
            };

            match update_monitor_pref(&config_path, monitor_name, |pref| {
                pref.scale = scale_val;
            }) {
                Ok(()) => {
                    if json_output {
                        println!("{}", json!({"status": "ok", "monitor": monitor_name, "scale": scale_val}));
                    } else {
                        println!("Set scale for {monitor_name} to {scale_val}");
                    }
                    0
                }
                Err(e) => {
                    eprintln!("Failed to set scale: {e}");
                    1
                }
            }
        }

        "rotate" | "transform" => {
            let monitor_name = match rest.get(1) {
                Some(m) => *m,
                None => {
                    eprintln!("Usage: nexad display rotate <monitor_name> <0|90|180|270>");
                    return 2;
                }
            };
            let rot: u8 = match rest.get(2).copied() {
                Some("0") => 0,
                Some("90") | Some("1") => 1,
                Some("180") | Some("2") => 2,
                Some("270") | Some("3") => 3,
                Some("4") => 4,
                Some("5") => 5,
                Some("6") => 6,
                Some("7") => 7,
                _ => {
                    eprintln!("Invalid rotation. Allowed: 0, 90, 180, 270 (or 0-7)");
                    return 2;
                }
            };

            match update_monitor_pref(&config_path, monitor_name, |pref| {
                pref.transform = Transform::from_u8(rot);
            }) {
                Ok(()) => {
                    if json_output {
                        println!("{}", json!({"status": "ok", "monitor": monitor_name, "transform": rot}));
                    } else {
                        println!("Set rotation for {monitor_name} to {rot}");
                    }
                    0
                }
                Err(e) => {
                    eprintln!("Failed to set rotation: {e}");
                    1
                }
            }
        }

        "res" | "resolution" => {
            let monitor_name = match rest.get(1) {
                Some(m) => *m,
                None => {
                    eprintln!("Usage: nexad display res <monitor_name> <mode_spec (e.g. 1920x1080@60.00 or preferred)>");
                    return 2;
                }
            };
            let mode_spec = match rest.get(2) {
                Some(s) => s.to_string(),
                None => {
                    eprintln!("Missing resolution spec (e.g. 1920x1080@60.00)");
                    return 2;
                }
            };

            match update_monitor_pref(&config_path, monitor_name, |pref| {
                pref.preferred_mode_spec = if mode_spec == "preferred" || mode_spec == "auto" {
                    None
                } else {
                    Some(mode_spec.clone())
                };
            }) {
                Ok(()) => {
                    if json_output {
                        println!("{}", json!({"status": "ok", "monitor": monitor_name, "mode": mode_spec}));
                    } else {
                        println!("Set resolution for {monitor_name} to {mode_spec}");
                    }
                    0
                }
                Err(e) => {
                    eprintln!("Failed to set resolution: {e}");
                    1
                }
            }
        }

        "emergency" | "revert" | "fallback" => {
            println!("[NexaDisplay] Triggering emergency fallback...");
            match DisplayManager::new(&config_path) {
                Ok(mgr) => {
                    mgr.execute_emergency_fallback();
                    println!("Emergency fallback completed.");
                    0
                }
                Err(e) => {
                    eprintln!("Emergency fallback failed to init manager: {e}");
                    1
                }
            }
        }

        "help" | "--help" | "-h" => {
            println!("Nexa Display Subsystem CLI");
            println!("Usage: nexad display <command> [options]");
            println!();
            println!("Commands:");
            println!("  info, status [--json] [--pretty]   Show current displays, topologies, and modes");
            println!("  daemon                             Run event listener daemon for hotplug/lid");
            println!("  mode <mode> [direction]            Apply projection mode (extend, mirror, internal-only, external-only)");
            println!("  scale <monitor> <value>            Set display scale factor (e.g. 1.25)");
            println!("  rotate <monitor> <0|90|180|270>    Set display rotation");
            println!("  res <monitor> <mode_spec>          Set display resolution (e.g. 1920x1080@60.00)");
            println!("  emergency, revert                  Restore known-good display configuration");
            0
        }

        unknown => {
            eprintln!("Unknown display command: '{unknown}'. Run 'nexad display help' for usage.");
            2
        }
    }
}

/// Modifies a monitor preference and re-applies the current layout plan.
fn update_monitor_pref<F>(config_path: &std::path::Path, monitor_name: &str, mutate: F) -> Result<(), DisplayError>
where
    F: FnOnce(&mut SavedMonitorPreference),
{
    let mut store = DisplayConfigStore::load_from_path(config_path).unwrap_or_default();
    let snapshot = backend::capture_snapshot(false)?;

    let target_mon = snapshot
        .monitors
        .iter()
        .find(|m| m.name == monitor_name)
        .ok_or_else(|| DisplayError::DiscoveryError(format!("Monitor '{monitor_name}' not found")))?;

    let key = if !target_mon.identity.edid_hash.is_empty() {
        target_mon.identity.edid_hash.clone()
    } else {
        target_mon.name.clone()
    };

    let mut pref = store
        .monitor_preferences
        .get(&key)
        .cloned()
        .unwrap_or_else(|| SavedMonitorPreference::from_monitor(target_mon));

    mutate(&mut pref);
    store.monitor_preferences.insert(key, pref);
    store.save_to_path(config_path)?;

    // Re-apply using current mode
    let mgr = DisplayManager::new(config_path)?;
    let (current_mode, dir) = store.resolve_desired_mode(&snapshot);
    mgr.apply_mode(current_mode, Some(dir))
}

/// Helper that produces the structured info JSON consumed by Quickshell.
fn capture_info(config_path: &std::path::Path) -> Result<Value, DisplayError> {
    let store = DisplayConfigStore::load_from_path(config_path).unwrap_or_default();
    let snapshot = backend::capture_snapshot(false)?;
    let (current_mode, direction) = store.resolve_desired_mode(&snapshot);

    let displays: Vec<Value> = snapshot
        .monitors
        .iter()
        .map(|m| {
            let available_modes: Vec<String> = m.available_modes.iter().map(|mode| mode.to_hyprland_mode()).collect();
            json!({
                "name": m.name,
                "make": m.identity.make,
                "model": m.identity.model,
                "serial": m.identity.serial,
                "edid_hash": m.identity.edid_hash,
                "connector_type": match m.connector_type {
                    ConnectorType::Internal => "internal",
                    ConnectorType::External => "external",
                    ConnectorType::Virtual => "virtual",
                },
                "connected": m.connected_in_drm,
                "enabled": m.enabled_in_compositor,
                "is_ghost": m.is_ghost,
                "current_mode": m.current_mode.as_ref().map(|cm| json!({
                    "width": cm.width,
                    "height": cm.height,
                    "refresh_hz": cm.refresh_hz(),
                    "formatted": cm.to_hyprland_mode(),
                })),
                "preferred_mode": m.preferred_mode.as_ref().map(|pm| pm.to_hyprland_mode()),
                "available_modes": available_modes,
                "position": {
                    "x": m.position.x,
                    "y": m.position.y,
                },
                "scale": m.scale,
                "transform": m.transform as u8,
                "active_workspace_id": m.active_workspace_id,
                "mirror_of": m.mirror_of,
            })
        })
        .collect();

    let externals = snapshot.external_monitors();
    let internals = snapshot.internal_monitor();
    let has_externals = !externals.is_empty();

    let modes = vec![
        json!({
            "mode": "internal-only",
            "label": "Internal Only",
            "available": internals.is_some(),
            "current": current_mode == ProjectionMode::InternalOnly,
        }),
        json!({
            "mode": "external-only",
            "label": "External Only",
            "available": has_externals,
            "current": current_mode == ProjectionMode::ExternalOnly,
        }),
        json!({
            "mode": "extend",
            "label": "Extend Desktop",
            "available": has_externals && internals.is_some(),
            "current": current_mode == ProjectionMode::Extend,
            "direction": match direction {
                ExtendDirection::Right => "right",
                ExtendDirection::Left => "left",
                ExtendDirection::Above => "above",
                ExtendDirection::Below => "below",
            },
        }),
        json!({
            "mode": "mirror",
            "label": "Duplicate / Mirror",
            "available": has_externals && internals.is_some(),
            "current": current_mode == ProjectionMode::Mirror,
        }),
    ];

    let primary_name = snapshot.monitors.iter().find(|m| m.enabled_in_compositor).map(|m| m.name.clone()).unwrap_or_default();

    Ok(json!({
        "current_mode": match current_mode {
            ProjectionMode::InternalOnly => "internal-only",
            ProjectionMode::ExternalOnly => "external-only",
            ProjectionMode::Extend => "extend",
            ProjectionMode::Mirror => "mirror",
        },
        "connected_count": snapshot.monitors.iter().filter(|m| m.connected_in_drm && !m.is_ghost).count(),
        "active_count": snapshot.monitors.iter().filter(|m| m.enabled_in_compositor).count(),
        "internal_count": if internals.is_some() { 1 } else { 0 },
        "external_count": externals.len(),
        "is_locked": snapshot.session_locked,
        "lid_closed": snapshot.lid_state == LidState::Closed,
        "lid_state": match snapshot.lid_state {
            LidState::Open => "open",
            LidState::Closed => "closed",
            LidState::Unknown => "unknown",
        },
        "power_state": match snapshot.power_state {
            PowerState::AcOnline => "ac",
            PowerState::Battery => "battery",
            PowerState::Unknown => "unknown",
        },
        "primary": primary_name,
        "primary_name": primary_name,
        "projection_modes": modes,
        "displays": displays,
        "wallpapers": store.wallpapers,
    }))
}
