//! Hardware & Compositor State Discovery (`discovery.rs`)
//!
//! Pure parsing and state synthesis logic.
//! Cross-references Hyprland's monitor/workspace JSON with Linux DRM sysfs states
//! to detect connected displays, identify ghost outputs, and parse available modes.
//! Prohibited from mutating state or executing shell commands directly.

use crate::display::model::{
    ConnectorType, DisplayError, DisplayMode, HardwareSnapshot, LidState, Monitor,
    MonitorIdentity, Position, PowerState, Transform, WorkspaceInfo,
};
use serde::Deserialize;
use std::collections::HashMap;

/// Raw DRM connector record supplied by the backend I/O reader.
#[derive(Debug, Clone, Default)]
pub struct RawDrmConnector {
    /// Connector name stripped of card prefix (e.g., "eDP-1", "HDMI-A-1", "DP-1")
    pub name: String,
    /// True if `/sys/class/drm/card*-<name>/status` == "connected"
    pub connected: bool,
    /// Optional hex-encoded hash of `/sys/class/drm/card*-<name>/edid`
    pub edid_hash: String,
}

/// Raw JSON schema returned by `hyprctl monitors all -j`.
#[derive(Debug, Clone, Deserialize)]
struct HyprMonitorRaw {
    pub name: String,
    #[serde(default)]
    pub make: String,
    #[serde(default)]
    pub model: String,
    #[serde(default)]
    pub serial: String,
    #[serde(default)]
    pub width: u32,
    #[serde(default)]
    pub height: u32,
    #[serde(rename = "refreshRate", default)]
    pub refresh_rate: f32,
    #[serde(default)]
    pub x: i32,
    #[serde(default)]
    pub y: i32,
    #[serde(default = "default_scale")]
    pub scale: f32,
    #[serde(default)]
    pub transform: u8,
    #[serde(default)]
    pub disabled: bool,
    #[serde(rename = "activeWorkspace")]
    pub active_workspace: Option<HyprWorkspaceRef>,
    #[serde(rename = "availableModes", default)]
    pub available_modes: Vec<String>,
    #[serde(rename = "mirrorOf", default)]
    pub mirror_of: String,
}

fn default_scale() -> f32 {
    1.0
}

#[derive(Debug, Clone, Deserialize)]
struct HyprWorkspaceRef {
    pub id: i32,
}

/// Raw JSON schema returned by `hyprctl workspaces -j`.
#[derive(Debug, Clone, Deserialize)]
struct HyprWorkspaceRaw {
    pub id: i32,
    pub name: String,
    #[serde(default)]
    pub monitor: String,
    #[serde(default)]
    pub windows: u32,
}

/// Builds a complete, verified `HardwareSnapshot` from raw compositor JSON and DRM state.
pub fn build_snapshot(
    hypr_monitors_json: &str,
    hypr_workspaces_json: &str,
    drm_connectors: &[RawDrmConnector],
    raw_lid_state: Option<&str>,
    raw_ac_online: Option<&str>,
    session_locked: bool,
    timestamp_ms: u64,
) -> Result<HardwareSnapshot, DisplayError> {
    let raw_monitors: Vec<HyprMonitorRaw> = serde_json::from_str(hypr_monitors_json)
        .map_err(|e| DisplayError::DiscoveryError(format!("Invalid monitors JSON: {}", e)))?;

    let raw_workspaces: Vec<HyprWorkspaceRaw> = serde_json::from_str(hypr_workspaces_json)
        .map_err(|e| DisplayError::DiscoveryError(format!("Invalid workspaces JSON: {}", e)))?;

    // Index DRM connectors by normalized name (e.g., "HDMI-A-1")
    let mut drm_map: HashMap<String, &RawDrmConnector> = HashMap::new();
    for conn in drm_connectors {
        drm_map.insert(conn.name.clone(), conn);
    }

    let mut monitors = Vec::new();
    let mut seen_names = HashMap::new();

    for raw in raw_monitors {
        seen_names.insert(raw.name.clone(), true);
        let connector_type = ConnectorType::from_name(&raw.name);

        // Cross-reference with kernel DRM status if present
        let (connected_in_drm, edid_hash) = match drm_map.get(&raw.name) {
            Some(drm) => (drm.connected, drm.edid_hash.clone()),
            // If DRM entries aren't exposed (e.g., virtual/nested session), trust compositor
            None => (true, String::new()),
        };

        // A monitor is a "ghost" if Hyprland still reports it, but DRM says it is unplugged
        let is_ghost = !connected_in_drm && connector_type == ConnectorType::External;

        let available_modes = parse_mode_list(&raw.available_modes);
        let current_mode = if raw.width > 0 && raw.height > 0 {
            Some(DisplayMode::new(raw.width, raw.height, raw.refresh_rate))
        } else {
            None
        };

        // Preferred mode is the first entry in Hyprland's availableModes (EDID preferred)
        // or the highest resolution mode available.
        let preferred_mode = available_modes.first().copied().or(current_mode);

        let mirror_of = if raw.mirror_of.is_empty() || raw.mirror_of == "none" {
            None
        } else {
            Some(raw.mirror_of.clone())
        };

        let identity = MonitorIdentity::new(&raw.make, &raw.model, &raw.serial, &edid_hash);

        monitors.push(Monitor {
            name: raw.name,
            connector_type,
            identity,
            connected_in_drm,
            enabled_in_compositor: !raw.disabled,
            is_ghost,
            current_mode,
            preferred_mode,
            available_modes,
            position: Position::new(raw.x, raw.y),
            scale: if raw.scale <= 0.0 { 1.0 } else { raw.scale },
            transform: Transform::from_u8(raw.transform),
            active_workspace_id: raw.active_workspace.map(|w| w.id),
            mirror_of,
        });
    }

    // Check if DRM reports a physically connected display that Hyprland hasn't initialized yet
    for drm in drm_connectors {
        if drm.connected && !seen_names.contains_key(&drm.name) {
            let connector_type = ConnectorType::from_name(&drm.name);
            monitors.push(Monitor {
                name: drm.name.clone(),
                connector_type,
                identity: MonitorIdentity::new("Unknown", "Display", "", &drm.edid_hash),
                connected_in_drm: true,
                enabled_in_compositor: false,
                is_ghost: false,
                current_mode: None,
                preferred_mode: None,
                available_modes: Vec::new(),
                position: Position::ORIGIN,
                scale: 1.0,
                transform: Transform::Normal,
                active_workspace_id: None,
                mirror_of: None,
            });
        }
    }

    // Sort monitors deterministically: Internal first, then External alphabetically
    monitors.sort_by(|a, b| match (&a.connector_type, &b.connector_type) {
        (ConnectorType::Internal, ConnectorType::External) => std::cmp::Ordering::Less,
        (ConnectorType::External, ConnectorType::Internal) => std::cmp::Ordering::Greater,
        _ => a.name.cmp(&b.name),
    });

    let workspaces = raw_workspaces
        .into_iter()
        .filter(|w| w.id > 0) // Filter out special/scratchpad negative IDs
        .map(|w| WorkspaceInfo {
            id: w.id,
            name: w.name,
            monitor_name: w.monitor,
            windows: w.windows,
        })
        .collect();

    Ok(HardwareSnapshot {
        monitors,
        workspaces,
        lid_state: parse_lid_state(raw_lid_state),
        power_state: parse_power_state(raw_ac_online),
        session_locked,
        timestamp_ms,
    })
}

/// Parses a list of Hyprland mode strings (e.g., `["1920x1080@60.00Hz", "2560x1440@144.00Hz"]`).
pub fn parse_mode_list(raw_modes: &[String]) -> Vec<DisplayMode> {
    let mut modes = Vec::new();
    for raw in raw_modes {
        if let Some(mode) = parse_single_mode(raw) {
            if !modes.contains(&mode) {
                modes.push(mode);
            }
        }
    }
    modes
}

/// Parses a single mode string such as `"1920x1080@60.00Hz"` or `"3840x2160@120.00"`.
pub fn parse_single_mode(s: &str) -> Option<DisplayMode> {
    let clean = s.trim().trim_end_matches("Hz").trim_end_matches("hz");
    let (res_part, hz_part) = clean.split_once('@')?;
    let (w_str, h_str) = res_part.split_once('x')?;

    let width: u32 = w_str.trim().parse().ok()?;
    let height: u32 = h_str.trim().parse().ok()?;
    let refresh_hz: f32 = hz_part.trim().parse().ok()?;

    if width == 0 || height == 0 || refresh_hz <= 0.0 {
        return None;
    }

    Some(DisplayMode::new(width, height, refresh_hz))
}

/// Parses `/proc/acpi/button/lid/*/state` content (e.g. `"state:      open"`).
pub fn parse_lid_state(raw: Option<&str>) -> LidState {
    let Some(text) = raw else {
        return LidState::Unknown;
    };
    let lower = text.to_lowercase();
    if lower.contains("closed") {
        LidState::Closed
    } else if lower.contains("open") {
        LidState::Open
    } else {
        LidState::Unknown
    }
}

/// Parses `/sys/class/power_supply/AC*/online` content (`"1"` or `"0"`).
pub fn parse_power_state(raw: Option<&str>) -> PowerState {
    let Some(text) = raw else {
        return PowerState::Unknown;
    };
    match text.trim() {
        "1" => PowerState::AcOnline,
        "0" => PowerState::Battery,
        _ => PowerState::Unknown,
    }
}

/// Finds the highest common resolution supported by both the internal and external monitor
/// for distortion-free Mirror mode. Falls back to `"preferred"` if no exact match exists.
pub fn find_best_common_mirror_mode(primary: &Monitor, replica: &Monitor) -> Option<DisplayMode> {
    if primary.available_modes.is_empty() || replica.available_modes.is_empty() {
        return None;
    }

    let mut common: Vec<DisplayMode> = Vec::new();

    for p_mode in &primary.available_modes {
        for r_mode in &replica.available_modes {
            if p_mode.width == r_mode.width && p_mode.height == r_mode.height {
                // Pick the safer (lower) refresh rate of the two for stability
                let min_mhz = p_mode.refresh_mhz.min(r_mode.refresh_mhz);
                common.push(DisplayMode {
                    width: p_mode.width,
                    height: p_mode.height,
                    refresh_mhz: min_mhz,
                });
            }
        }
    }

    // Sort by highest pixel count first, then highest refresh rate
    common.sort_by(|a, b| {
        b.pixels()
            .cmp(&a.pixels())
            .then_with(|| b.refresh_mhz.cmp(&a.refresh_mhz))
    });

    common.first().copied()
}
