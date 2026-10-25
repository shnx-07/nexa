//! Core domain models, data structures, and error types for the Nexa Display subsystem.
//! Strictly pure data definitions — zero I/O or execution logic.

use serde::{Deserialize, Serialize};
use std::fmt;

/// Represents the hardware connector classification.
#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum ConnectorType {
    /// Built-in laptop panel (e.g., eDP-1, eDP-2, LVDS-1)
    Internal,
    /// External display (e.g., HDMI-A-1, DP-1, DP-2, USB-C)
    External,
    /// Virtual or headless output
    Virtual,
}

impl ConnectorType {
    /// Classifies a connector name based on standard Linux DRM naming conventions.
    pub fn from_name(name: &str) -> Self {
        let lower = name.to_lowercase();
        if lower.starts_with("edp") || lower.starts_with("lvds") || lower.starts_with("dsi") {
            Self::Internal
        } else if lower.starts_with("headless") || lower.starts_with("virtual") {
            Self::Virtual
        } else {
            Self::External
        }
    }
}

/// Unique hardware fingerprint for a display, resilient against port/connector swapping.
#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize, Default)]
pub struct MonitorIdentity {
    pub make: String,
    pub model: String,
    pub serial: String,
    /// Computed deterministic key (e.g. "make_model_serial" or EDID hash)
    pub edid_hash: String,
}

impl MonitorIdentity {
    pub fn new(make: &str, model: &str, serial: &str, edid_hash: &str) -> Self {
        let computed_hash = if !edid_hash.is_empty() {
            edid_hash.to_string()
        } else {
            format!(
                "{}_{}_{}",
                make.trim().replace(' ', "_"),
                model.trim().replace(' ', "_"),
                serial.trim().replace(' ', "_")
            )
        };

        Self {
            make: make.to_string(),
            model: model.to_string(),
            serial: serial.to_string(),
            edid_hash: computed_hash,
        }
    }
}

/// Resolution and refresh rate tuple.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub struct DisplayMode {
    pub width: u32,
    pub height: u32,
    /// Refresh rate in millihertz (e.g. 60000 = 60.00 Hz) to preserve exact precision
    pub refresh_mhz: u32,
}

impl DisplayMode {
    pub fn new(width: u32, height: u32, refresh_hz: f32) -> Self {
        Self {
            width,
            height,
            refresh_mhz: (refresh_hz * 1000.0).round() as u32,
        }
    }

    pub fn refresh_hz(&self) -> f32 {
        self.refresh_mhz as f32 / 1000.0
    }

    pub fn pixels(&self) -> u64 {
        (self.width as u64) * (self.height as u64)
    }

    /// Formats as Hyprland mode string: "1920x1080@60.00"
    pub fn to_hyprland_mode(&self) -> String {
        format!("{}x{}@{:.2}", self.width, self.height, self.refresh_hz())
    }
}

/// 2D logical coordinate offset in the compositor space.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default, Serialize, Deserialize)]
pub struct Position {
    pub x: i32,
    pub y: i32,
}

impl Position {
    pub const ORIGIN: Self = Self { x: 0, y: 0 };

    pub fn new(x: i32, y: i32) -> Self {
        Self { x, y }
    }

    pub fn to_hyprland_pos(&self) -> String {
        format!("{}x{}", self.x, self.y)
    }
}

/// Hyprland monitor transform / rotation values (0 to 7).
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default, Serialize, Deserialize)]
#[repr(u8)]
pub enum Transform {
    #[default]
    Normal = 0,
    Rotate90 = 1,
    Rotate180 = 2,
    Rotate270 = 3,
    Flipped = 4,
    Flipped90 = 5,
    Flipped180 = 6,
    Flipped270 = 7,
}

impl Transform {
    pub fn from_u8(val: u8) -> Self {
        match val {
            1 => Self::Rotate90,
            2 => Self::Rotate180,
            3 => Self::Rotate270,
            4 => Self::Flipped,
            5 => Self::Flipped90,
            6 => Self::Flipped180,
            7 => Self::Flipped270,
            _ => Self::Normal,
        }
    }

    pub fn is_rotated_90_or_270(&self) -> bool {
        matches!(
            self,
            Self::Rotate90 | Self::Rotate270 | Self::Flipped90 | Self::Flipped270
        )
    }
}

/// Complete observed state of a single physical or logical monitor.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct Monitor {
    /// Connector name in Hyprland/DRM (e.g., "eDP-1", "HDMI-A-1")
    pub name: String,
    pub connector_type: ConnectorType,
    pub identity: MonitorIdentity,
    /// True if physically connected according to kernel DRM
    pub connected_in_drm: bool,
    /// True if currently enabled and rendering in Hyprland
    pub enabled_in_compositor: bool,
    /// True if cached in Hyprland but physically unplugged in DRM
    pub is_ghost: bool,
    pub current_mode: Option<DisplayMode>,
    pub preferred_mode: Option<DisplayMode>,
    pub available_modes: Vec<DisplayMode>,
    pub position: Position,
    pub scale: f32,
    pub transform: Transform,
    pub active_workspace_id: Option<i32>,
    pub mirror_of: Option<String>,
}

impl Monitor {
    /// Calculates the logical width accounting for scale and rotation.
    pub fn logical_width(&self) -> u32 {
        let Some(mode) = self.current_mode.or(self.preferred_mode) else {
            return 1920;
        };
        let raw_w = if self.transform.is_rotated_90_or_270() {
            mode.height
        } else {
            mode.width
        };
        let s = if self.scale <= 0.0 { 1.0 } else { self.scale };
        ((raw_w as f32) / s).round() as u32
    }

    /// Calculates the logical height accounting for scale and rotation.
    pub fn logical_height(&self) -> u32 {
        let Some(mode) = self.current_mode.or(self.preferred_mode) else {
            return 1080;
        };
        let raw_h = if self.transform.is_rotated_90_or_270() {
            mode.width
        } else {
            mode.height
        };
        let s = if self.scale <= 0.0 { 1.0 } else { self.scale };
        ((raw_h as f32) / s).round() as u32
    }
}

/// Active workspace representation in Hyprland.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct WorkspaceInfo {
    pub id: i32,
    pub name: String,
    pub monitor_name: String,
    pub windows: u32,
}

/// Physical laptop lid state.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default, Serialize, Deserialize)]
pub enum LidState {
    #[default]
    Open,
    Closed,
    Unknown,
}

/// Power supply state (AC vs Battery).
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default, Serialize, Deserialize)]
pub enum PowerState {
    #[default]
    AcOnline,
    Battery,
    Unknown,
}

/// Complete point-in-time snapshot of hardware and compositor state.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct HardwareSnapshot {
    pub monitors: Vec<Monitor>,
    pub workspaces: Vec<WorkspaceInfo>,
    pub lid_state: LidState,
    pub power_state: PowerState,
    pub session_locked: bool,
    pub timestamp_ms: u64,
}

impl HardwareSnapshot {
    pub fn internal_monitor(&self) -> Option<&Monitor> {
        self.monitors
            .iter()
            .find(|m| m.connector_type == ConnectorType::Internal && m.connected_in_drm)
    }

    pub fn external_monitors(&self) -> Vec<&Monitor> {
        self.monitors
            .iter()
            .filter(|m| {
                m.connector_type == ConnectorType::External && m.connected_in_drm && !m.is_ghost
            })
            .collect()
    }
}

/// Relative placement direction for multi-monitor Extend mode.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default, Serialize, Deserialize)]
pub enum ExtendDirection {
    #[default]
    Right,
    Left,
    Above,
    Below,
}

/// User-facing Windows/macOS style projection modes.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default, Serialize, Deserialize)]
pub enum ProjectionMode {
    /// Laptop screen only (disables external outputs)
    InternalOnly,
    /// Second screen only / Clamshell mode (evacuates workspaces & disables internal panel)
    ExternalOnly,
    /// Extend desktop across internal and external monitors
    #[default]
    Extend,
    /// Duplicate / Mirror internal display onto external monitors
    Mirror,
}

impl fmt::Display for ProjectionMode {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::InternalOnly => write!(f, "InternalOnly"),
            Self::ExternalOnly => write!(f, "ExternalOnly"),
            Self::Extend => write!(f, "Extend"),
            Self::Mirror => write!(f, "Mirror"),
        }
    }
}

/// Desired target configuration for an individual monitor within a LayoutPlan.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct TargetMonitorConfig {
    pub name: String,
    pub enabled: bool,
    /// Mode specification ("preferred", "highres", or explicit "1920x1080@60.00")
    pub mode_spec: String,
    pub position: Position,
    pub scale: f32,
    pub transform: Transform,
    pub mirror_source: Option<String>,
}

impl TargetMonitorConfig {
    /// Formats into a `hyprctl keyword monitor` argument string.
    pub fn to_hyprland_rule(&self) -> String {
        if !self.enabled {
            return format!("{},disable", self.name);
        }

        let mut rule = format!(
            "{},{},{},{:.2}",
            self.name,
            self.mode_spec,
            self.position.to_hyprland_pos(),
            self.scale
        );

        if self.transform != Transform::Normal {
            rule.push_str(&format!(",transform,{}", self.transform as u8));
        }

        if let Some(ref src) = self.mirror_source {
            rule.push_str(&format!(",mirror,{}", src));
        }

        rule
    }

    /// Formats into a Hyprland 0.56+ Lua  command string.
    pub fn to_hyprland_lua_eval(&self) -> String {
        if !self.enabled {
            return format!(
                r#"eval hl.monitor({{ output = "{}", disabled = true }})"#,
                self.name
            );
        }

        let mode = if self.mode_spec.trim().is_empty() || self.mode_spec == "preferred" {
            "preferred".to_string()
        } else {
            self.mode_spec.clone()
        };

        let mut parts = vec![
            format!(r#"output = "{}""#, self.name),
            "disabled = false".to_string(),
            format!(r#"mode = "{}""#, mode),
            format!(r#"position = "{}""#, self.position.to_hyprland_pos()),
            format!("scale = {:.2}", self.scale),
            format!("transform = {}", self.transform as u8),
        ];

        if let Some(ref src) = self.mirror_source {
            parts.push(format!(r#"mirror = "{}""#, src));
        }

        format!("eval hl.monitor({{ {} }})", parts.join(", "))
    }
}

/// Instruction to evacuate a workspace from a retiring monitor to an active monitor.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct WorkspaceMigration {
    pub workspace_id: i32,
    pub from_monitor: String,
    pub to_monitor: String,
}

/// Atomic execution plan computed by `planner.rs` and validated by `safety.rs`.
#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct LayoutPlan {
    pub mode: ProjectionMode,
    pub primary_monitor: String,
    /// Step 1: Monitors to enable/position first so target coordinates exist
    pub enable_configs: Vec<TargetMonitorConfig>,
    /// Step 2: Workspaces to migrate away from monitors about to be disabled
    pub workspace_migrations: Vec<WorkspaceMigration>,
    /// Step 3: Monitors to disable after workspace evacuation completes
    pub disable_configs: Vec<TargetMonitorConfig>,
    /// Whether systemd-logind lid sleep inhibit should be held active
    pub hold_lid_inhibit: bool,
}

/// Normalized domain events emitted by `events.rs`.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub enum DisplayEvent {
    HotplugChanged {
        connector: Option<String>,
    },
    LidChanged(LidState),
    PowerChanged(PowerState),
    SessionLockChanged(bool),
    UserModeRequested {
        mode: ProjectionMode,
        direction: Option<ExtendDirection>,
    },
    ForceRefresh,
}

/// Unified error type across all display modules.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub enum DisplayError {
    IpcError(String),
    DiscoveryError(String),
    SafetyViolation(String),
    NoActiveMonitorsLeft,
    ExternalMonitorNotFound,
    InternalMonitorNotFound,
    ConfigIoError(String),
    CommandTimeout(String),
    ExecutionFailed { step: String, reason: String },
}

impl fmt::Display for DisplayError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::IpcError(msg) => write!(f, "Hyprland IPC error: {}", msg),
            Self::DiscoveryError(msg) => write!(f, "Hardware discovery error: {}", msg),
            Self::SafetyViolation(msg) => write!(f, "Display safety violation: {}", msg),
            Self::NoActiveMonitorsLeft => {
                write!(f, "Safety abort: Plan would leave zero active displays")
            }
            Self::ExternalMonitorNotFound => {
                write!(
                    f,
                    "Requested external display mode, but no external monitor is connected"
                )
            }
            Self::InternalMonitorNotFound => {
                write!(f, "Internal laptop panel (eDP) not found")
            }
            Self::ConfigIoError(msg) => write!(f, "Configuration I/O error: {}", msg),
            Self::CommandTimeout(msg) => write!(f, "Command timed out: {}", msg),
            Self::ExecutionFailed { step, reason } => {
                write!(f, "Execution failed at step '{}': {}", step, reason)
            }
        }
    }
}

impl std::error::Error for DisplayError {}
