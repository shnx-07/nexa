//! Compositor I/O & Execution Backend (`backend.rs`)
//!
//! The sole module permitted to interact with Hyprland IPC, run shell commands,
//! read sysfs/DRM status, and trigger wallpaper/bar refreshes.
//! Implements atomic plan execution order:
//! 1. Enable/position target outputs so geometry exists.
//! 2. Evacuate workspaces from retiring outputs to active outputs.
//! 3. Disable retiring outputs.
//! 4. Ping UI daemons (waybar, hyprpaper/swww).

use crate::display::discovery::{RawDrmConnector, build_snapshot};
use crate::display::model::{
    DisplayError, HardwareSnapshot, LayoutPlan, ProjectionMode, WorkspaceMigration,
};
use std::fs;
use std::io::{Read, Write};
use std::os::unix::net::UnixStream;
use std::path::Path;
use std::process::{Child, Command};
use std::sync::Mutex;
use std::time::Duration;

/// IPC socket read/write timeout to prevent indefinite hangs.
const IPC_TIMEOUT: Duration = Duration::from_secs(5);

/// Global handle for the active systemd-inhibit child process.
/// Storing it here ensures we kill the old one before spawning a new one.
static LID_INHIBIT_CHILD: Mutex<Option<Child>> = Mutex::new(None);

/// Executes a raw command against Hyprland's IPC socket (`$HYPRLAND_INSTANCE_SIGNATURE`).
pub fn hyprctl_command(cmd: &str) -> Result<String, DisplayError> {
    let signature = std::env::var("HYPRLAND_INSTANCE_SIGNATURE").map_err(|_| {
        DisplayError::IpcError(
            "HYPRLAND_INSTANCE_SIGNATURE environment variable not set".to_string(),
        )
    })?;

    let runtime_dir =
        std::env::var("XDG_RUNTIME_DIR").unwrap_or_else(|_| "/run/user/1000".to_string());
    let socket_path = Path::new(&runtime_dir)
        .join("hypr")
        .join(signature)
        .join(".socket.sock");

    let mut stream = UnixStream::connect(&socket_path).map_err(|e| {
        DisplayError::IpcError(format!(
            "Failed to connect to Hyprland socket at {}: {}",
            socket_path.display(),
            e
        ))
    })?;

    // Apply timeouts so a stalled compositor cannot hang the daemon forever.
    let _ = stream.set_read_timeout(Some(IPC_TIMEOUT));
    let _ = stream.set_write_timeout(Some(IPC_TIMEOUT));

    // Hyprland socket command format: j/command (e.g. "j/monitors")
    stream.write_all(cmd.as_bytes()).map_err(|e| {
        DisplayError::IpcError(format!("Failed to write to Hyprland socket: {}", e))
    })?;
    stream.flush().ok();

    let mut response = String::new();
    stream.read_to_string(&mut response).map_err(|e| {
        if e.kind() == std::io::ErrorKind::WouldBlock || e.kind() == std::io::ErrorKind::TimedOut {
            DisplayError::CommandTimeout(format!("IPC read timed out for command: {}", cmd))
        } else {
            DisplayError::IpcError(format!("Failed to read from Hyprland socket: {}", e))
        }
    })?;

    // Hyprland replies "ok" on success. Any other non-JSON response starting with
    // a lower-case letter is an error string (e.g. "error: unknown request").
    // We must check this to surface failures so the emergency fallback can fire.
    let trimmed = response.trim();
    if !trimmed.is_empty()
        && !trimmed.starts_with('[')
        && !trimmed.starts_with('{')
        && !trimmed.eq_ignore_ascii_case("ok")
    {
        return Err(DisplayError::IpcError(format!(
            "Hyprland rejected command '{}': {}",
            cmd, trimmed
        )));
    }

    Ok(response)
}

/// Queries raw monitor JSON from Hyprland (`hyprctl monitors all -j`).
pub fn query_monitors_json() -> Result<String, DisplayError> {
    hyprctl_command("j/monitors all")
}

/// Queries raw workspace JSON from Hyprland (`hyprctl workspaces -j`).
pub fn query_workspaces_json() -> Result<String, DisplayError> {
    hyprctl_command("j/workspaces")
}

/// Scans `/sys/class/drm/` to discover physical connector status and EDID hashes.
pub fn scan_drm_connectors() -> Vec<RawDrmConnector> {
    let mut connectors = Vec::new();
    let drm_dir = Path::new("/sys/class/drm");

    let Ok(entries) = fs::read_dir(drm_dir) else {
        return connectors;
    };

    for entry in entries.flatten() {
        let file_name = entry.file_name();
        let name_str = file_name.to_string_lossy();

        // Looking for entries like "card0-eDP-1", "card0-HDMI-A-1", "card0-DP-2", etc.
        // We split on the first '-' to strip the card prefix.
        // Then we must skip sub-connector components like "card0-eDP-1-edp",
        // "card0-DP-1-dp", "card0-HDMI-A-1-1". These entries have a trailing
        // '-' segment that begins with a known sub-component suffix (edp, dp, 1..9).
        // Strategy: a valid top-level connector name matches one of these patterns:
        //   eDP-N   LVDS-N  DSI-N  DP-N  HDMI-A-N  HDMI-B-N  VGA-N  DVI-*-N
        // Sub-components carry an extra '-<suffix>' beyond the numeric index.
        // We detect them by checking whether, after removing the card prefix and the
        // connector-type prefix (including its '-'), what remains after the last '-'
        // is NOT purely numeric (HDMI-A-1 is fine; HDMI-A-1-1 is a sub-component).
        if let Some((_, connector_name)) = name_str.split_once('-') {
            // Skip if this is a sub-component of a connector.
            // A sub-component always has a trailing '-<non-numeric>' or '-<extra-index>' segment
            // beyond the standard "TYPE-N" or "TYPE-A-N" pattern.
            // We use a simple heuristic: count '-' separators.
            // Valid connectors: eDP-1 (1 dash), DP-1 (1 dash), HDMI-A-1 (2 dashes), VGA-1 (1 dash).
            // Sub-components: eDP-1-edp (2 dashes for eDP), DP-1-dp (2 dashes for DP),
            //                 HDMI-A-1-1 (3 dashes).
            // So the rule is: skip connectors whose last '-' segment is NOT the known numeric index
            // AND the connector is not one of the multi-dash top-level types (HDMI-A, DVI-I, DVI-D, DVI-A).
            if is_drm_subcomponent(connector_name) {
                continue;
            }

            let path = entry.path();
            let status_path = path.join("status");
            let connected = match fs::read_to_string(&status_path) {
                Ok(content) => content.trim().eq_ignore_ascii_case("connected"),
                Err(_) => false,
            };

            let edid_path = path.join("edid");
            let edid_hash = match fs::read(edid_path) {
                Ok(bytes) if !bytes.is_empty() => {
                    // Use FNV-1a (64-bit) — a stable, version-independent hash.
                    // std::collections::hash_map::DefaultHasher is explicitly NOT stable
                    // across Rust compiler versions, which would orphan saved monitor profiles.
                    let hash = fnv1a_64(&bytes);
                    format!("{:016x}", hash)
                }
                _ => String::new(),
            };

            connectors.push(RawDrmConnector {
                name: connector_name.to_string(),
                connected,
                edid_hash,
            });
        }
    }

    connectors
}

/// Reads kernel ACPI lid state from `/proc/acpi/button/lid/*/state`.
pub fn read_lid_state_raw() -> Option<String> {
    let lid_dir = Path::new("/proc/acpi/button/lid");
    let entries = fs::read_dir(lid_dir).ok()?;
    for entry in entries.flatten() {
        let state_file = entry.path().join("state");
        if let Ok(content) = fs::read_to_string(&state_file) {
            return Some(content);
        }
    }
    None
}

/// Reads power supply AC online status from `/sys/class/power_supply/AC*/online`.
pub fn read_ac_online_raw() -> Option<String> {
    let ps_dir = Path::new("/sys/class/power_supply");
    let entries = fs::read_dir(ps_dir).ok()?;
    for entry in entries.flatten() {
        let path = entry.path();
        let name = path.file_name()?.to_string_lossy().to_lowercase();
        if name.starts_with("ac") || name.contains("adapter") || name.contains("mains") {
            let online_file = path.join("online");
            if let Ok(content) = fs::read_to_string(&online_file) {
                return Some(content);
            }
        }
    }
    None
}

/// Captures a full `HardwareSnapshot` by querying Hyprland IPC and kernel sysfs.
pub fn capture_snapshot(session_locked: bool) -> Result<HardwareSnapshot, DisplayError> {
    let monitors_json = query_monitors_json()?;
    let workspaces_json = query_workspaces_json()?;
    let drm_connectors = scan_drm_connectors();
    let lid_raw = read_lid_state_raw();
    let ac_raw = read_ac_online_raw();
    let timestamp_ms = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap_or_default()
        .as_millis() as u64;

    build_snapshot(
        &monitors_json,
        &workspaces_json,
        &drm_connectors,
        lid_raw.as_deref(),
        ac_raw.as_deref(),
        session_locked,
        timestamp_ms,
    )
}

/// Executes an atomic `LayoutPlan` against Hyprland via IPC dispatch.
pub fn apply_layout_plan(plan: &LayoutPlan) -> Result<(), DisplayError> {
    // Phase 1: Enable & position target outputs so target coordinate space exists
    for cfg in &plan.enable_configs {
        // Try modern Hyprland 0.56+ Lua eval first:
        let lua_cmd = cfg.to_hyprland_lua_eval();
        if let Err(e) = hyprctl_command(&lua_cmd) {
            // Fallback to legacy keyword format:
            let rule = cfg.to_hyprland_rule();
            let legacy_cmd = format!("keyword monitor {}", rule);
            let _ = hyprctl_command(&legacy_cmd).map_err(|_| DisplayError::ExecutionFailed {
                step: format!("Enable monitor {}", cfg.name),
                reason: e.to_string(),
            })?;
        }
    }

    // Phase 2: Evacuate workspaces off retiring outputs before disabling them
    for mig in &plan.workspace_migrations {
        let lua_cmd = format!(
            r#"eval hl.dispatch(hl.dsp.workspace.move({{ workspace = {}, monitor = "{}" }}))"#,
            mig.workspace_id, mig.to_monitor
        );
        if hyprctl_command(&lua_cmd).is_err() {
            let legacy_cmd = format!(
                "dispatch moveworkspacetomonitor {} {}",
                mig.workspace_id, mig.to_monitor
            );
            let _ = hyprctl_command(&legacy_cmd);
        }
    }

    // Phase 3: Disable retiring outputs
    for cfg in &plan.disable_configs {
        let lua_cmd = cfg.to_hyprland_lua_eval();
        if let Err(e) = hyprctl_command(&lua_cmd) {
            let rule = cfg.to_hyprland_rule();
            let legacy_cmd = format!("keyword monitor {}", rule);
            let _ = hyprctl_command(&legacy_cmd).map_err(|_| DisplayError::ExecutionFailed {
                step: format!("Disable monitor {}", cfg.name),
                reason: e.to_string(),
            })?;
        }
    }

    // Phase 4: Focus primary monitor
    let lua_focus = format!(
        r#"eval hl.dispatch(hl.dsp.focus({{ monitor = "{}" }}))"#,
        plan.primary_monitor
    );
    if hyprctl_command(&lua_focus).is_err() {
        let legacy_focus = format!("dispatch focusmonitor {}", plan.primary_monitor);
        let _ = hyprctl_command(&legacy_focus);
    }

    // Phase 5: Notify UI daemons (Waybar, wallpaper)
    refresh_ui_daemons();

    Ok(())
}

/// Signals Waybar and wallpaper daemons to re-read monitor geometry.
pub fn refresh_ui_daemons() {
    // Send SIGUSR2 to Waybar to reload layout
    let _ = Command::new("pkill").args(["-SIGUSR2", "waybar"]).status();

    // Signal hyprpaper to reload by sending SIGHUP.
    // Note: "hyprpaper --reload" is NOT a valid flag; SIGHUP is the correct signal.
    let _ = Command::new("pkill").args(["-HUP", "hyprpaper"]).status();
    // swww-daemon: reload wallpaper config by sending SIGUSR1 if running
    let _ = Command::new("pkill")
        .args(["-USR1", "swww-daemon"])
        .status();
}

/// Manages systemd-logind lid sleep inhibition.
///
/// # Inhibitor leak fix
/// Previous implementation spawned a new `systemd-inhibit` process on every call
/// without tracking or killing prior instances, causing an unbounded process leak.
/// This implementation stores the `Child` handle in a global `Mutex` and kills the
/// old process before spawning a new one.
pub fn set_lid_inhibit_active(hold: bool) {
    let mut child_guard = LID_INHIBIT_CHILD.lock().unwrap();

    if hold {
        // Only spawn a new inhibitor if one is not already running.
        if let Some(ref mut child) = *child_guard {
            // Check if the existing inhibitor is still alive.
            match child.try_wait() {
                Ok(None) => return, // still running — nothing to do
                _ => {}             // exited or error — fall through to respawn
            }
        }

        // Kill any stale handle before spawning.
        if let Some(mut old) = child_guard.take() {
            let _ = old.kill();
            let _ = old.wait();
        }

        match Command::new("systemd-inhibit")
            .args([
                "--what=handle-lid-switch",
                "--who=NexaDisplaySubsystem",
                "--why=External display active in Clamshell mode",
                "--mode=block",
                "sleep",
                "infinity",
            ])
            .spawn()
        {
            Ok(child) => {
                *child_guard = Some(child);
            }
            Err(e) => {
                eprintln!("[NexaDisplay] Failed to spawn lid inhibitor: {e}");
            }
        }
    } else {
        // Kill the tracked child if present.
        if let Some(mut child) = child_guard.take() {
            let _ = child.kill();
            let _ = child.wait();
        }
        // Also kill any stray processes that might have escaped tracking.
        let _ = Command::new("pkill")
            .args(["-f", "NexaDisplaySubsystem"])
            .status();
    }
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

/// Returns `true` if `connector_name` (already stripped of the `cardN-` prefix)
/// is a DRM sub-component rather than a top-level connector.
///
/// Top-level connectors:
///   eDP-N, LVDS-N, DSI-N, VGA-N, DP-N, HDMI-A-N, HDMI-B-N, DVI-I-N, DVI-D-N, DVI-A-N
///
/// Sub-components always have an additional segment after the numeric index:
///   eDP-1-edp, DP-1-dp, HDMI-A-1-1, etc.
fn is_drm_subcomponent(name: &str) -> bool {
    // Multi-segment connector types that are NOT sub-components:
    // HDMI-A-N, HDMI-B-N, DVI-I-N, DVI-D-N, DVI-A-N
    // These have exactly 2 dashes. A sub-component would have 3+.
    let dash_count = name.chars().filter(|&c| c == '-').count();

    if name.starts_with("HDMI-A-")
        || name.starts_with("HDMI-B-")
        || name.starts_with("DVI-I-")
        || name.starts_with("DVI-D-")
        || name.starts_with("DVI-A-")
    {
        // Valid top-level multi-dash connectors have exactly 2 dashes.
        // A sub-component of these would have 3+ dashes.
        return dash_count > 2;
    }

    // All other connectors (eDP-N, DP-N, VGA-N, etc.) are top-level with exactly 1 dash.
    // Any extra dash means it's a sub-component.
    dash_count > 1
}

/// FNV-1a 64-bit hash — stable across all Rust compiler versions.
///
/// Unlike `std::collections::hash_map::DefaultHasher`, FNV-1a produces the same
/// output regardless of which Rust version compiled the binary.
fn fnv1a_64(bytes: &[u8]) -> u64 {
    const FNV_OFFSET: u64 = 14695981039346656037;
    const FNV_PRIME: u64 = 1099511628211;

    let mut hash = FNV_OFFSET;
    for &byte in bytes {
        hash ^= byte as u64;
        hash = hash.wrapping_mul(FNV_PRIME);
    }
    hash
}
