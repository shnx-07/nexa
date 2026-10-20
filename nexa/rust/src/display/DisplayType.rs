#![allow(unused_imports, dead_code, non_snake_case, unused_variables)]
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use std::{
    collections::{BTreeMap, HashMap, HashSet},
    env, fs,
    io::{Read, Write},
    os::unix::{net::UnixStream, process::CommandExt},
    path::{Path, PathBuf},
    process::{Command, Stdio},
    sync::{
        atomic::{AtomicU64, AtomicU8, Ordering},
        Mutex, OnceLock,
    },
    thread::{self, JoinHandle},
    time::{Duration, Instant, SystemTime, UNIX_EPOCH},
};

use super::*;

// ============================================================
// TUNABLES
// ============================================================

/// How long a transaction waits for the cross-process display lock.
pub(crate) const LOCK_TIMEOUT: Duration = Duration::from_secs(5);
/// A lock older than this is considered wedged even if its PID is alive
/// (protects against PID reuse after a crash).
pub(crate) const LOCK_STALE_AGE: Duration = Duration::from_secs(30);
/// Hotplug events are coalesced until the bus has been quiet this long.
pub(crate) const HOTPLUG_QUIET_WINDOW: Duration = Duration::from_millis(400);
/// …but a burst is never held longer than this (a flapping KVM or cable
/// that never goes quiet must still be handled).
pub(crate) const HOTPLUG_MAX_BURST: Duration = Duration::from_secs(3);
/// DRM buses need time to re-train links after resume.
pub(crate) const RESUME_SETTLE: Duration = Duration::from_millis(600);
/// If CLOCK_BOOTTIME advanced this much more than CLOCK_MONOTONIC, we slept.
pub(crate) const RESUME_JUMP_THRESHOLD: f64 = 4.0;
/// Events for outputs we touched ourselves within this window are echoes.
pub(crate) const SELF_EVENT_WINDOW: Duration = Duration::from_millis(2500);
/// Every hyprctl invocation is bounded so a wedged compositor can't hang us.
pub(crate) const HYPRCTL_TIMEOUT: Duration = Duration::from_secs(4);
/// How long phase 1 of a transaction waits for new outputs to come up.
pub(crate) const ENABLE_VERIFY_TIMEOUT: Duration = Duration::from_millis(1800);
/// How long we wait for the post-commit state to converge on the plan.
pub(crate) const CONVERGE_TIMEOUT: Duration = Duration::from_millis(1200);
/// Wallpaper restore retries (with exponential backoff).
pub(crate) const WALLPAPER_RETRIES: u32 = 3;
/// Socket read timeout == daemon tick granularity.
pub(crate) const SOCKET_TICK: Duration = Duration::from_millis(200);
/// Background housekeeping cadences inside the daemon.
pub(crate) const PENDING_CHECK_INTERVAL: Duration = Duration::from_millis(500);
pub(crate) const LID_POLL_INTERVAL: Duration = Duration::from_secs(1);
pub(crate) const RESUME_CHECK_INTERVAL: Duration = Duration::from_secs(1);
pub(crate) const SNAPSHOT_INTERVAL: Duration = Duration::from_secs(2);
/// Wait before looking at audio sinks (ELD / ACP profiles appear late).
pub(crate) const AUDIO_SETTLE: Duration = Duration::from_millis(1500);
/// Workspace-home records older than this are forgotten.
pub(crate) const WORKSPACE_HOME_TTL_MS: u64 = 24 * 60 * 60 * 1000;
/// Tolerance (logical px) when deciding whether two monitors touch/overlap.
pub(crate) const GEOMETRY_TOLERANCE: i32 = 2;
/// Fallback geometry when a monitor reports no usable resolution.
pub(crate) const FALLBACK_RES: (i32, i32) = (1920, 1080);
/// Current on-disk schema version of monitors.json.
pub(crate) const CONFIG_VERSION: u32 = 2;


// ============================================================
// HYPRLAND DATA MODEL
// ============================================================

/// Accept strings, numbers, booleans or null for fields whose JSON type has
/// drifted between Hyprland versions (`mirrorOf`, `serial`, …).
pub(crate) fn de_lenient_string<'de, D: serde::Deserializer<'de>>(d: D) -> Result<String, D::Error> {
    let v = Value::deserialize(d)?;
    Ok(match v {
        Value::String(s) => s,
        Value::Null => String::new(),
        Value::Number(n) => n.to_string(),
        Value::Bool(b) => b.to_string(),
        other => other.to_string(),
    })
}

pub(crate) fn default_one() -> f64 {
    1.0
}
pub(crate) fn default_true() -> bool {
    true
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct WorkspaceRef {
    #[serde(default)]
    pub id: i64,
    #[serde(default, deserialize_with = "de_lenient_string")]
    pub name: String,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct HyprMonitor {
    #[serde(default)]
    pub id: i64,
    pub name: String,
    #[serde(default, deserialize_with = "de_lenient_string")]
    pub description: String,
    #[serde(default, deserialize_with = "de_lenient_string")]
    pub make: String,
    #[serde(default, deserialize_with = "de_lenient_string")]
    pub model: String,
    #[serde(default, deserialize_with = "de_lenient_string")]
    pub serial: String,
    #[serde(default)]
    pub width: i32,
    #[serde(default)]
    pub height: i32,
    #[serde(default, rename = "refreshRate")]
    pub refresh_rate: f64,
    #[serde(default)]
    pub x: i32,
    #[serde(default)]
    pub y: i32,
    #[serde(default = "default_one")]
    pub scale: f64,
    #[serde(default)]
    pub transform: i32,
    #[serde(default)]
    pub focused: bool,
    #[serde(default)]
    pub disabled: bool,
    #[serde(default = "default_true", rename = "dpmsStatus")]
    pub dpms_status: bool,
    #[serde(default)]
    pub vrr: bool,
    #[serde(default, rename = "mirrorOf", deserialize_with = "de_lenient_string")]
    pub mirror_of: String,
    #[serde(default, rename = "availableModes")]
    pub available_modes: Vec<String>,
    #[serde(default, rename = "activeWorkspace")]
    pub active_workspace: WorkspaceRef,
}

impl HyprMonitor {
    /// A stable identity for this physical panel, independent of which
    /// connector it happens to be plugged into right now.
    ///
    /// * `make_model_serial` when the EDID carries a meaningful serial;
    /// * `make_model` when the serial is absent / zero / "Unknown";
    /// * `desc_<description>` if make and model are both missing;
    /// * `port_<connector>` only as a last resort (e.g. no EDID at all).
    ///
    /// Two identical panels without serials yield the same base key; see
    /// [`assign_hardware_keys`] for the deterministic disambiguation.
    pub fn hardware_key(&self) -> String {
        let make = clean_token(&self.make);
        let model = clean_token(&self.model);
        if make == "Unknown" && model == "Unknown" {
            let desc = clean_token(strip_port_suffix(&self.description));
            if desc != "Unknown" {
                return format!("desc_{}", desc.chars().take(48).collect::<String>());
            }
            return format!("port_{}", clean_token(&self.name));
        }
        if serial_is_meaningful(&self.serial) {
            format!("{make}_{model}_{}", clean_token(&self.serial))
        } else {
            format!("{make}_{model}")
        }
    }

    /// The output this monitor mirrors, if any (Hyprland reports "none").
    pub fn mirror_source(&self) -> Option<&str> {
        let m = self.mirror_of.trim();
        if m.is_empty() || m.eq_ignore_ascii_case("none") || m == "-1" {
            None
        } else {
            Some(m)
        }
    }

    pub(crate) fn current_mode_string(&self) -> Option<String> {
        if self.width > 0 && self.height > 0 {
            Some(format_mode(self.width, self.height, Some(self.refresh_rate)))
        } else {
            None
        }
    }
}

/// Some Hyprland builds append " (PORT)" to the description.
pub(crate) fn strip_port_suffix(desc: &str) -> &str {
    let d = desc.trim();
    if d.ends_with(')') {
        if let Some(idx) = d.rfind(" (") {
            return &d[..idx];
        }
    }
    d
}

pub(crate) fn clean_token(s: &str) -> String {
    let cleaned: String = s.chars().filter(|c| c.is_alphanumeric()).collect();
    if cleaned.is_empty() {
        "Unknown".to_string()
    } else {
        cleaned
    }
}

/// EDIDs frequently carry placeholder serials ("0", "0x00000000",
/// "Unknown"). Those must not be part of the identity, or two boots of the
/// same panel could disagree.
pub(crate) fn serial_is_meaningful(raw: &str) -> bool {
    let c: String = raw
        .chars()
        .filter(|c| c.is_ascii_alphanumeric())
        .collect::<String>()
        .to_ascii_lowercase();
    if c.is_empty() || matches!(c.as_str(), "unknown" | "none" | "null" | "na") {
        return false;
    }
    let digits = c.strip_prefix("0x").unwrap_or(&c);
    !digits.is_empty() && !digits.chars().all(|ch| ch == '0')
}

/// `("DP-", 10)` style key so DP-2 sorts before DP-10.
pub(crate) fn natural_key(name: &str) -> (String, u64) {
    let digits: String = name.chars().rev().take_while(|c| c.is_ascii_digit()).collect::<Vec<_>>().into_iter().rev().collect();
    let prefix = name[..name.len() - digits.len()].to_string();
    (prefix, digits.parse().unwrap_or(0))
}

/// Map connector name → hardware key for a set of monitors. Identical
/// panels (same base key) get `#2`, `#3`… in natural connector order — the
/// only deterministic tiebreaker available when EDIDs are indistinguishable.
pub fn assign_hardware_keys(monitors: &[HyprMonitor]) -> HashMap<String, String> {
    let mut sorted: Vec<&HyprMonitor> = monitors.iter().collect();
    sorted.sort_by_key(|m| natural_key(&m.name));
    let mut seen: HashMap<String, usize> = HashMap::new();
    let mut out = HashMap::new();
    for m in sorted {
        let base = m.hardware_key();
        let n = seen.entry(base.clone()).or_insert(0);
        *n += 1;
        let key = if *n == 1 { base } else { format!("{base}#{n}") };
        out.insert(m.name.clone(), key);
    }
    out
}

pub(crate) fn fingerprint_of_keys<'a, I: IntoIterator<Item = &'a String>>(keys: I) -> String {
    let mut parts: Vec<&String> = keys.into_iter().collect();
    parts.sort();
    parts.into_iter().cloned().collect::<Vec<_>>().join("+")
}

/// Fingerprint of the *whole set* of monitors: sorted hardware keys joined
/// by `+`. The same physical setup gives the same fingerprint no matter
/// which ports or dock slots the monitors are plugged into.
pub fn generate_fingerprint(monitors: &[HyprMonitor]) -> String {
    let keys = assign_hardware_keys(monitors);
    fingerprint_of_keys(keys.values())
}

#[derive(Debug, Clone, Default, Deserialize)]
pub(crate) struct HyprWorkspaceInfo {
    #[serde(default)]
    pub(crate) id: i64,
    #[serde(default, deserialize_with = "de_lenient_string")]
    pub(crate) name: String,
    #[serde(default, deserialize_with = "de_lenient_string")]
    pub(crate) monitor: String,
}

impl HyprWorkspaceInfo {
    /// Stable identifier to use with dispatchers ("3", "special:scratch").
    pub(crate) fn dispatch_ref(&self) -> String {
        if self.id < 0 && !self.name.is_empty() {
            if self.name.starts_with("special") {
                self.name.clone()
            } else {
                format!("special:{}", self.name)
            }
        } else if self.id > 0 {
            self.id.to_string()
        } else {
            format!("name:{}", self.name)
        }
    }
}


// ============================================================
// NEXA DATA MODEL (config, profiles, runtime state)
// ============================================================

/// Per-display output of `nexad display info`.
#[derive(Debug, Clone, Serialize)]
pub struct DisplayInfo {
    pub id: i64,
    pub name: String,
    pub description: String,
    pub hardware_key: String,
    pub make: String,
    pub model: String,
    pub serial: String,
    pub connector_kind: String,
    pub width: i32,
    pub height: i32,
    pub refresh_rate: f64,
    pub x: i32,
    pub y: i32,
    pub scale: f64,
    pub transform: i32,
    pub logical_width: i32,
    pub logical_height: i32,
    pub focused: bool,
    pub disabled: bool,
    pub dpms: bool,
    pub vrr: bool,
    pub is_internal: bool,
    pub is_primary: bool,
    pub managed: bool,
    pub physically_connected: Option<bool>,
    pub mirror_of: String,
    pub active_workspace: Option<i64>,
    pub available_modes: Vec<String>,
    /// Normalised rectangle (0..1) of this display within the canvas, for
    /// the Dynamic Island topology strip. `None` for disabled/mirrored.
    pub topology: Option<Value>,
}

/// A single monitor's remembered state within a [`DisplayProfile`], keyed
/// by hardware key rather than port name.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct SavedMonitorState {
    pub enabled: bool,
    /// e.g. "2560x1440@144.00" or "preferred"
    pub mode: String,
    /// e.g. "0x0" or "auto"
    pub position: String,
    #[serde(default = "default_one")]
    pub scale: f64,
    #[serde(default)]
    pub transform: i32,
    #[serde(default)]
    pub primary: bool,
    /// Hardware key of the monitor this one mirrors.
    #[serde(default)]
    pub mirror_of: Option<String>,
    #[serde(default)]
    pub vrr: Option<bool>,
    /// Informational only — the connector this monitor was last seen on.
    #[serde(default)]
    pub last_output: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DisplayProfile {
    pub name: String,
    /// Sorted hardware keys joined by `+`.
    pub fingerprint: String,
    /// Descriptive label ("extend", "mirror", "custom", …). The layout is
    /// always restored from `monitors`, never re-derived from this label.
    pub mode: String,
    /// Keyed by hardware key.
    pub monitors: BTreeMap<String, SavedMonitorState>,
    /// `true` for profiles the engine remembers on its own; `false` for
    /// profiles the user named explicitly. Auto-save never overwrites a
    /// user-named profile.
    #[serde(default)]
    pub auto: bool,
    /// "open" / "closed" when the profile only applies to one lid state.
    #[serde(default)]
    pub lid: Option<String>,
    #[serde(default)]
    pub created_ms: u64,
    #[serde(default)]
    pub last_used_ms: u64,
}

/// Per-monitor preferences, remembered across profiles and modes: once you
/// set a panel to 1.5× or 144 Hz, every built-in mode (extend, external-only,
/// …) keeps using it instead of falling back to preferred/1.0.
#[derive(Debug, Clone, Default, Serialize, Deserialize, PartialEq)]
pub struct MonitorPref {
    #[serde(default)]
    pub mode: Option<String>,
    #[serde(default)]
    pub scale: Option<f64>,
    #[serde(default)]
    pub transform: Option<i32>,
    #[serde(default)]
    pub vrr: Option<bool>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MonitorsConfig {
    #[serde(default)]
    pub version: u32,
    /// Policy when exactly one external display is connected (lid open).
    #[serde(default = "default_policy_dual")]
    pub default_policy_dual: String,
    /// Policy when two or more external displays are connected (lid open).
    #[serde(default = "default_policy_multi")]
    pub default_policy_multi: String,
    /// What to do when the lid closes with externals attached:
    /// "external-only" (clamshell) or "ignore".
    #[serde(default = "default_lid_close_policy")]
    pub lid_close_policy: String,
    /// Layout used when the lid opens and nothing better is remembered.
    #[serde(default = "default_lid_open_policy")]
    pub lid_open_policy: String,
    /// Vertical alignment of monitors in a row: "top" | "center" | "bottom".
    #[serde(default = "default_align")]
    pub align: String,
    /// Columns for `extend-grid`.
    #[serde(default = "default_grid_columns")]
    pub grid_columns: usize,
    /// Preferred primary display (hardware key or connector name).
    #[serde(default)]
    pub primary: Option<String>,
    /// Remember user-chosen layouts per hardware set and restore them.
    #[serde(default = "default_true")]
    pub remember_layouts: bool,
    /// Move workspaces back to the monitor they were evacuated from.
    #[serde(default = "default_true")]
    pub restore_workspaces: bool,
    /// "auto" (switch default sink), "notify", or "off".
    #[serde(default = "default_audio_policy")]
    pub audio_policy: String,
    /// "new-setup" (only for unknown hardware), "always", or "never".
    #[serde(default = "default_osd_policy")]
    pub osd_on_hotplug: String,
    /// Extra connector prefixes to treat as built-in panels.
    #[serde(default)]
    pub internal_outputs: Vec<String>,
    /// Connector names/prefixes or hardware keys never managed by NEXA.
    #[serde(default)]
    pub ignore_outputs: Vec<String>,
    /// Wallpaper restore script (default: ~/.config/nexa/scripts/restore-wallpaper.sh).
    #[serde(default)]
    pub wallpaper_script: Option<String>,
    #[serde(default)]
    pub monitor_prefs: BTreeMap<String, MonitorPref>,
    #[serde(default)]
    pub profiles: Vec<DisplayProfile>,
}

pub(crate) fn default_policy_dual() -> String {
    "external-only".to_string()
}
pub(crate) fn default_policy_multi() -> String {
    "extend".to_string()
}
pub(crate) fn default_lid_close_policy() -> String {
    "external-only".to_string()
}
pub(crate) fn default_lid_open_policy() -> String {
    "extend".to_string()
}
pub(crate) fn default_align() -> String {
    "top".to_string()
}
pub(crate) fn default_grid_columns() -> usize {
    2
}
pub(crate) fn default_audio_policy() -> String {
    "notify".to_string()
}
pub(crate) fn default_osd_policy() -> String {
    "new-setup".to_string()
}

impl Default for MonitorsConfig {
    fn default() -> Self {
        Self {
            version: CONFIG_VERSION,
            default_policy_dual: default_policy_dual(),
            default_policy_multi: default_policy_multi(),
            lid_close_policy: default_lid_close_policy(),
            lid_open_policy: default_lid_open_policy(),
            align: default_align(),
            grid_columns: default_grid_columns(),
            primary: None,
            remember_layouts: true,
            restore_workspaces: true,
            audio_policy: default_audio_policy(),
            osd_on_hotplug: default_osd_policy(),
            internal_outputs: Vec::new(),
            ignore_outputs: Vec::new(),
            wallpaper_script: None,
            monitor_prefs: BTreeMap::new(),
            profiles: Vec::new(),
        }
    }
}

impl MonitorsConfig {
    pub(crate) fn pref(&self, key: &str) -> Option<&MonitorPref> {
        self.monitor_prefs.get(key).or_else(|| self.monitor_prefs.get(base_key(key)))
    }
    pub(crate) fn wallpaper_script_path(&self) -> PathBuf {
        match &self.wallpaper_script {
            Some(p) if p.starts_with("~/") => home_dir().join(&p[2..]),
            Some(p) => PathBuf::from(p),
            None => nexa_config_dir().join("scripts").join("restore-wallpaper.sh"),
        }
    }
}

/// `"Dell_U2720Q#2"` → `"Dell_U2720Q"`.
pub(crate) fn base_key(key: &str) -> &str {
    key.split('#').next().unwrap_or(key)
}

/// Load monitors.json. A file that exists but doesn't parse is backed up

/// stays "none" on some versions). QML may watch this file.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub(crate) struct RuntimeState {
    #[serde(default)]
    pub(crate) mode: Option<String>,
    #[serde(default)]
    pub(crate) active_profile: Option<String>,
    #[serde(default)]
    pub(crate) fingerprint: Option<String>,
    #[serde(default)]
    pub(crate) mirror_source: Option<String>,
    #[serde(default)]
    pub(crate) mirror_targets: Vec<String>,
    #[serde(default)]
    pub(crate) lid_closed: Option<bool>,
    #[serde(default)]
    pub(crate) updated_ms: u64,
}

pub(crate) fn load_runtime_state() -> RuntimeState {
    let mut state: RuntimeState = read_json_file(&runtime_state_path()).unwrap_or_default();
    if state.mode.is_none() {
        state.mode = fs::read_to_string(legacy_mode_state_path())
            .ok()
            .map(|s| s.trim().to_string())
            .filter(|s| !s.is_empty());
    }
    state
}


// ============================================================
// CONNECTOR CLASSIFICATION
// ============================================================

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ConnectorKind {
    /// eDP / LVDS / DSI built-in panel.
    Internal,
    Hdmi,
    /// DisplayPort, including USB-C / Thunderbolt alt-mode and MST.
    DisplayPort,
    Dvi,
    Vga,
    /// A DRM "Virtual-N" connector (VMs). Managed like an external.
    Virtual,
    /// Nested session outputs (WL-1, X11-1). Managed like an external.
    Nested,
    /// HEADLESS-N (streaming / remote desktop). Never managed.
    Headless,
    /// Hyprland's zero-monitor placeholder. Never managed.
    Fallback,
    Writeback,
    Other,
}

impl ConnectorKind {
    pub(crate) fn label(self) -> &'static str {
        match self {
            Self::Internal => "internal",
            Self::Hdmi => "hdmi",
            Self::DisplayPort => "displayport",
            Self::Dvi => "dvi",
            Self::Vga => "vga",
            Self::Virtual => "virtual",
            Self::Nested => "nested",
            Self::Headless => "headless",
            Self::Fallback => "fallback",
            Self::Writeback => "writeback",
            Self::Other => "other",
        }
    }
    /// Can this kind of output ever be part of a NEXA-managed layout?
    pub(crate) fn manageable(self) -> bool {
        !matches!(self, Self::Headless | Self::Fallback | Self::Writeback)
    }
}

pub fn connector_kind(name: &str) -> ConnectorKind {
    let n = name.to_ascii_uppercase();
    if n == "FALLBACK" {
        ConnectorKind::Fallback
    } else if n.starts_with("EDP") || n.starts_with("LVDS") || n.starts_with("DSI") {
        ConnectorKind::Internal
    } else if n.starts_with("HDMI") {
        ConnectorKind::Hdmi
    } else if n.starts_with("DP") || n.starts_with("USB-C") || n.starts_with("TYPE-C") {
        ConnectorKind::DisplayPort
    } else if n.starts_with("DVI") {
        ConnectorKind::Dvi
    } else if n.starts_with("VGA") {
        ConnectorKind::Vga
    } else if n.starts_with("VIRTUAL") {
        ConnectorKind::Virtual
    } else if n.starts_with("WL-") || n.starts_with("X11-") {
        ConnectorKind::Nested
    } else if n.starts_with("HEADLESS") {
        ConnectorKind::Headless
    } else if n.starts_with("WRITEBACK") {
        ConnectorKind::Writeback
    } else {
        ConnectorKind::Other
    }
}

pub fn is_internal_display(name: &str) -> bool {
    connector_kind(name) == ConnectorKind::Internal
}

pub(crate) fn is_internal_with(cfg: &MonitorsConfig, name: &str) -> bool {
    is_internal_display(name)
        || cfg
            .internal_outputs
            .iter()
            .any(|p| !p.is_empty() && name.to_ascii_uppercase().starts_with(&p.to_ascii_uppercase()))
}

pub(crate) fn is_ignored(cfg: &MonitorsConfig, name: &str, key: &str) -> bool {
    cfg.ignore_outputs.iter().any(|pat| {
        let pat = pat.trim();
        !pat.is_empty() && (pat == key || pat == base_key(key) || name.eq_ignore_ascii_case(pat) || name.to_ascii_uppercase().starts_with(&pat.to_ascii_uppercase()))
    })
}

/// Output names are interpolated into Lua / hyprctl commands; refuse anything
/// that could break out of a string literal or a comma-separated rule.
pub(crate) fn valid_output_name(name: &str) -> bool {
    !name.is_empty() && name.len() <= 64 && name.chars().all(|c| c.is_ascii_alphanumeric() || matches!(c, '-' | '_' | '.'))
}


#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum LidState {
    Open,
    Closed,
    /// No lid switch (desktop) or unknown.
    Absent,
}

impl LidState {
    pub(crate) fn label(self) -> &'static str {
        match self {
            Self::Open => "open",
            Self::Closed => "closed",
            Self::Absent => "absent",
        }
    }
    pub(crate) fn profile_tag(self) -> Option<String> {
        match self {
            Self::Open => Some("open".into()),
            Self::Closed => Some("closed".into()),
            Self::Absent => None,
        }
    }
}


#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum DrmStatus {
    Connected,
    Disconnected,
    Unknown,
}

#[derive(Debug, Clone)]
pub(crate) struct DrmConnector {
    pub(crate) status: DrmStatus,
    pub(crate) dpms_on: Option<bool>,
}

/// `/sys/class/drm/card1-HDMI-A-1/status` → `{"HDMI-A-1": Connected}`.

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) struct Rect {
    pub(crate) x: i32,
    pub(crate) y: i32,
    pub(crate) w: i32,
    pub(crate) h: i32,
}

impl Rect {
    pub(crate) fn right(&self) -> i32 {
        self.x + self.w
    }
    pub(crate) fn bottom(&self) -> i32 {
        self.y + self.h
    }
    pub(crate) fn overlaps(&self, o: &Rect) -> bool {
        let ox = self.right().min(o.right()) - self.x.max(o.x);
        let oy = self.bottom().min(o.bottom()) - self.y.max(o.y);
        ox > GEOMETRY_TOLERANCE && oy > GEOMETRY_TOLERANCE
    }
    /// Share an edge segment (so the cursor can cross between them).
    pub(crate) fn touches(&self, o: &Rect) -> bool {
        let t = GEOMETRY_TOLERANCE;
        let y_overlap = self.bottom().min(o.bottom()) - self.y.max(o.y) > t;
        let x_overlap = self.right().min(o.right()) - self.x.max(o.x) > t;
        let horiz = ((self.right() - o.x).abs() <= t || (o.right() - self.x).abs() <= t) && y_overlap;
        let vert = ((self.bottom() - o.y).abs() <= t || (o.bottom() - self.y).abs() <= t) && x_overlap;
        horiz || vert
    }
    pub(crate) fn center2(&self) -> (i64, i64) {
        ((self.x as i64) * 2 + self.w as i64, (self.y as i64) * 2 + self.h as i64)
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) enum Align {
    Start,
    Center,
    End,
}

pub(crate) fn parse_align(s: &str) -> Align {
    match s.trim().to_ascii_lowercase().as_str() {
        "center" | "centre" | "middle" => Align::Center,
        "bottom" | "end" | "right" => Align::End,
        _ => Align::Start,
    }
}

pub(crate) fn align_offset(container: i32, item: i32, align: Align) -> i32 {
    match align {
        Align::Start => 0,
        Align::Center => (container - item) / 2,
        Align::End => container - item,
    }
}


// ============================================================
// PLANNED LAYOUTS
//
// Every code path that changes the layout — a projection mode, a restored
// profile, a single enable/disable/rotate — builds a `Vec<PlannedMonitor>`
// and hands it to `commit_plan`, the single place that talks to Hyprland.
// ============================================================

#[derive(Debug, Clone, PartialEq)]
pub struct PlannedMonitor {
    pub name: String,
    pub enabled: bool,
    pub mode: String,
    /// "XxY" in logical pixels, or "auto".
    pub position: String,
    pub scale: f64,
    pub transform: i32,
    /// Connector name of the mirror source.
    pub mirror_of: Option<String>,
    pub vrr: Option<bool>,
    /// Estimated pixel resolution after the mode is applied (layout only).
    pub(crate) pixel_size: (i32, i32),
}

impl PlannedMonitor {
    pub(crate) fn disabled(name: &str) -> Self {
        Self {
            name: name.to_string(),
            enabled: false,
            mode: String::new(),
            position: String::new(),
            scale: 1.0,
            transform: 0,
            mirror_of: None,
            vrr: None,
            pixel_size: (0, 0),
        }
    }
    pub(crate) fn logical(&self) -> (i32, i32) {
        logical_size(self.pixel_size, self.scale, self.transform)
    }
    pub(crate) fn pos(&self) -> Option<(i32, i32)> {
        parse_pos(&self.position)
    }
    pub(crate) fn set_pos(&mut self, x: i32, y: i32) {
        self.position = format!("{x}x{y}");
    }
    pub(crate) fn is_standalone(&self) -> bool {
        self.enabled && self.mirror_of.is_none()
    }
    pub(crate) fn rect(&self) -> Option<Rect> {
        let (x, y) = self.pos()?;
        let (w, h) = self.logical();
        Some(Rect { x, y, w: w.max(1), h: h.max(1) })
    }
}

#[derive(Debug, Clone, Default)]
pub(crate) struct Overrides {
    pub(crate) mode: Option<String>,
    pub(crate) scale: Option<f64>,
    pub(crate) transform: Option<i32>,
    pub(crate) position: Option<String>,
    pub(crate) vrr: Option<bool>,
}

/// Build an enabled plan entry for `m`, layering (highest wins):
/// explicit overrides → remembered per-monitor prefs → current live state
/// → preferred/1.0. The mode is validated and the scale sanitised against
/// the resolution that mode will actually produce.
pub(crate) fn plan_for(snap: &Snapshot, cfg: &MonitorsConfig, m: &HyprMonitor, ov: &Overrides) -> PlannedMonitor {
    let key = snap.key(&m.name);
    let pref = cfg.pref(&key).cloned().unwrap_or_default();
    let live = snap.is_active(&m.name) && m.width > 0 && snap.mirror_of(&m.name).is_none();

    let requested = ov.mode.clone().or(pref.mode.clone()).unwrap_or_else(|| "preferred".to_string());
    let mode = choose_mode(m, &requested);
    let px = target_resolution(m, &mode);
    let raw_scale = ov
        .scale
        .or(pref.scale)
        .or_else(|| (live && m.scale > 0.0).then_some(m.scale))
        .unwrap_or(1.0);
    let transform = ov.transform.or(pref.transform).unwrap_or(m.transform).rem_euclid(8);

    PlannedMonitor {
        name: m.name.clone(),
        enabled: true,
        mode,
        position: ov.position.clone().unwrap_or_else(|| "auto".to_string()),
        scale: sanitize_scale(px, raw_scale),
        transform,
        mirror_of: None,
        vrr: ov.vrr.or(pref.vrr),
        pixel_size: px,
    }
}

/// A laid-out group of monitors with its own origin at 0,0.
#[derive(Debug, Clone, Default)]
pub(crate) struct Block {
    pub(crate) items: Vec<PlannedMonitor>,
    pub(crate) w: i32,
    pub(crate) h: i32,
}

impl Block {
    pub(crate) fn single(mut p: PlannedMonitor) -> Self {
        let (w, h) = p.logical();
        p.set_pos(0, 0);
        Self { items: vec![p], w, h }
    }
    pub(crate) fn translate(&mut self, dx: i32, dy: i32) {
        for p in &mut self.items {
            if let Some((x, y)) = p.pos() {
                p.set_pos(x + dx, y + dy);
            }
        }
    }
    pub(crate) fn is_empty(&self) -> bool {
        self.items.is_empty()
    }
    /// Left → right; each block aligned vertically within the row.
    pub(crate) fn row(blocks: Vec<Block>, align: Align) -> Self {
        let blocks: Vec<Block> = blocks.into_iter().filter(|b| !b.is_empty()).collect();
        let h = blocks.iter().map(|b| b.h).max().unwrap_or(0);
        let mut out = Block { items: Vec::new(), w: 0, h };
        for mut b in blocks {
            b.translate(out.w, align_offset(h, b.h, align));
            out.w += b.w;
            out.items.extend(b.items);
        }
        out
    }
    /// Top → bottom; each block aligned horizontally within the column.
    pub(crate) fn column(blocks: Vec<Block>, align: Align) -> Self {
        let blocks: Vec<Block> = blocks.into_iter().filter(|b| !b.is_empty()).collect();
        let w = blocks.iter().map(|b| b.w).max().unwrap_or(0);
        let mut out = Block { items: Vec::new(), w, h: 0 };
        for mut b in blocks {
            b.translate(align_offset(w, b.w, align), out.h);
            out.h += b.h;
            out.items.extend(b.items);
        }
        out
    }
}


// ============================================================
// PROJECTION MODES
// ============================================================

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ProjectionMode {
    InternalOnly,
    ExternalOnly,
    ExtendRight,
    ExtendLeft,
    ExtendUp,
    ExtendDown,
    /// Row-major grid with N columns.
    ExtendGrid(usize),
    Mirror,
    /// Let the engine decide (saved profile or default policy).
    Auto,
    /// Name of a saved [`DisplayProfile`] to restore literally.
    Custom(String),
}

impl ProjectionMode {
    pub fn parse(s: &str) -> Option<Self> {
        let t = s.trim();
        let lower = t.to_ascii_lowercase();
        Some(match lower.as_str() {
            "" | "none" => return None,
            "internal-only" | "laptop-only" | "pc-only" | "pc" | "internal" => Self::InternalOnly,
            "external-only" | "second-only" | "dock-mode" | "dock" | "clamshell" | "external" => Self::ExternalOnly,
            "extend" | "extend-right" | "extend-all" => Self::ExtendRight,
            "extend-left" => Self::ExtendLeft,
            "extend-up" | "extend-top" | "extend-above" => Self::ExtendUp,
            "extend-down" | "extend-bottom" | "extend-below" => Self::ExtendDown,
            "extend-grid" | "grid" => Self::ExtendGrid(0),
            "mirror" | "duplicate" | "clone" => Self::Mirror,
            "auto" | "resolve" | "default" => Self::Auto,
            other => {
                if let Some(n) = other.strip_prefix("extend-grid-").or_else(|| other.strip_prefix("grid-")) {
                    if let Ok(cols) = n.parse::<usize>() {
                        return Some(Self::ExtendGrid(cols.max(1)));
                    }
                }
                Self::Custom(t.to_string())
            }
        })
    }

    pub fn as_str(&self) -> String {
        match self {
            Self::InternalOnly => "internal-only".into(),
            Self::ExternalOnly => "external-only".into(),
            Self::ExtendRight => "extend".into(),
            Self::ExtendLeft => "extend-left".into(),
            Self::ExtendUp => "extend-up".into(),
            Self::ExtendDown => "extend-down".into(),
            Self::ExtendGrid(0) => "extend-grid".into(),
            Self::ExtendGrid(n) => format!("extend-grid-{n}"),
            Self::Mirror => "mirror".into(),
            Self::Auto => "auto".into(),
            Self::Custom(name) => name.clone(),
        }
    }

    pub(crate) fn is_extend(&self) -> bool {
        matches!(self, Self::ExtendRight | Self::ExtendLeft | Self::ExtendUp | Self::ExtendDown | Self::ExtendGrid(_))
    }
}

/// The monitor the user wants as primary, if configured and present.

// ============================================================
// TRANSACTION MARKER (so the daemon can ignore its own echoes)
// ============================================================

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub(crate) struct TxnMarker {
    pub(crate) at_ms: u64,
    pub(crate) pid: u32,
    pub(crate) enabled: Vec<String>,
    pub(crate) disabled: Vec<String>,
}


// ============================================================
// WORKSPACE HOMES
//
// When a monitor is disabled or unplugged, its workspaces are evacuated to
// the primary display and we remember (by hardware key, not port) where they
// came from. When that monitor comes back, they go home.
// ============================================================

#[derive(Debug, Clone, Serialize, Deserialize)]
pub(crate) struct WorkspaceHome {
    pub(crate) home: String,
    pub(crate) from_output: String,
    pub(crate) at_ms: u64,
}

pub(crate) type WorkspaceHomes = BTreeMap<String, WorkspaceHome>;


#[derive(Debug, Clone, Default)]
pub(crate) struct CommitOptions {
    /// Dispatch even if the plan matches the live state.
    pub(crate) force: bool,
    /// Allow outputs Hyprland doesn't list (emergency recovery).
    pub(crate) allow_unknown: bool,
    /// Always focus the primary afterwards (projection changes).
    pub(crate) focus_primary: bool,
    pub(crate) reason: String,
}

#[derive(Debug, Clone, Default)]
pub struct CommitReport {
    pub changed: bool,
    pub deferred: bool,
    pub just_enabled: Vec<String>,
    pub just_disabled: Vec<String>,
    pub primary: Option<String>,
    pub active: Vec<String>,
}



#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct PendingAction {
    /// Why work was deferred (deduplicated, most recent last).
    #[serde(default)]
    pub reasons: Vec<String>,
    /// A projection mode the user asked for while locked (latest wins).
    #[serde(default)]
    pub requested_mode: Option<String>,
    #[serde(default)]
    pub since_ms: u64,
    #[serde(default)]
    pub updated_ms: u64,
    /// The wallpaper daemon must be re-synced after unlock.
    #[serde(default = "default_true")]
    pub refresh_wallpaper: bool,
    /// Quickshell should refresh its per-output windows after unlock
    /// (never done by us while locked — that would kill the lock client).
    #[serde(default = "default_true")]
    pub refresh_shell: bool,
}


#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
#[serde(rename_all = "kebab-case")]
pub enum ApplyOutcome {
    Applied,
    NoChange,
    Deferred,
}


#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Trigger {
    Startup,
    Hotplug,
    LidOpened,
    LidClosed,
    Resume,
    Unlock,
    Manual,
    ConfigReload,
}

impl Trigger {
    pub(crate) fn label(self) -> &'static str {
        match self {
            Self::Startup => "startup",
            Self::Hotplug => "hotplug",
            Self::LidOpened => "lid opened",
            Self::LidClosed => "lid closed",
            Self::Resume => "resume",
            Self::Unlock => "unlock",
            Self::Manual => "manual",
            Self::ConfigReload => "config reload",
        }
    }
    /// Triggers that "restore what was there" rather than react to a change.
    pub(crate) fn is_restorative(self) -> bool {
        matches!(self, Self::Startup | Self::Resume | Self::Unlock | Self::ConfigReload)
    }
}

#[derive(Debug, Clone)]
pub struct ResolveResult {
    /// Human-readable decision ("profile 'Desk'", "default: external-only", …).
    pub decision: String,
    pub outcome: ApplyOutcome,
    pub matched_profile: Option<String>,
    pub report: CommitReport,
    pub fingerprint: String,
}

/// Default policy when nothing is remembered for this hardware set.

#[derive(Debug, Clone, Default)]
pub struct EnableOptions {
    pub mode: Option<String>,
    pub position: Option<String>,
    pub scale: Option<f64>,
    pub transform: Option<i32>,
}

/// Turn a display on (or turn a mirror into a screen of its own).

#[derive(Debug, Clone)]
pub(crate) struct AudioSink {
    pub(crate) name: String,
    pub(crate) description: String,
    pub(crate) is_display: bool,
    pub(crate) available: bool,
}


/// Grace period after unlock for the lock screen's own handler to claim
/// the pending marker before the daemon replays it itself.
pub(crate) const UNLOCK_GRACE: Duration = Duration::from_millis(1500);
/// A monitor that dropped off while asleep (DPMS off) is only considered
/// unplugged if it's still gone this long after the screens woke up.
pub(crate) const DPMS_WAKE_GRACE: Duration = Duration::from_secs(4);


pub(crate) struct DaemonGuard {
    pub(crate) path: PathBuf,
}

impl DaemonGuard {
    pub(crate) fn acquire() -> Result<Self, String> {
        let path = daemon_pid_path();
        if let Some(pid) = fs::read_to_string(&path).ok().and_then(|s| s.trim().parse::<u32>().ok()) {
            if pid != std::process::id() && pid_alive(pid) && Self::looks_like_us(pid) {
                return Err(format!("display daemon already running (pid {pid})"));
            }
        }
        write_atomic(&path, std::process::id().to_string().as_bytes())?;
        Ok(Self { path })
    }
    pub(crate) fn looks_like_us(pid: u32) -> bool {
        let cmdline = fs::read(format!("/proc/{pid}/cmdline")).unwrap_or_default();
        let text = String::from_utf8_lossy(&cmdline).replace('\0', " ");
        let me = env::current_exe().ok().and_then(|p| p.file_name().map(|n| n.to_string_lossy().to_string())).unwrap_or_else(|| "nexad".into());
        text.contains("nexad") || text.contains(&me)
    }
}

impl Drop for DaemonGuard {
    fn drop(&mut self) {
        if fs::read_to_string(&self.path).ok().and_then(|s| s.trim().parse::<u32>().ok()) == Some(std::process::id()) {
            let _ = fs::remove_file(&self.path);
        }
    }
}


#[derive(Debug, Clone, PartialEq, Eq)]
pub enum HyprEvent {
    MonitorAdded(String),
    MonitorRemoved(String),
    /// `true` = lid closed.
    LidSwitch(bool),
    ConfigReloaded,
}


#[derive(Debug, Default)]
pub(crate) struct HotplugBurst {
    pub(crate) added: Vec<String>,
    pub(crate) removed: Vec<String>,
    pub(crate) lid: Option<bool>,
    pub(crate) config_reloaded: bool,
    pub(crate) first: Option<Instant>,
    pub(crate) last: Option<Instant>,
}

impl HotplugBurst {
    pub(crate) fn touch(&mut self) {
        let now = Instant::now();
        self.first.get_or_insert(now);
        self.last = Some(now);
    }
    pub(crate) fn is_empty(&self) -> bool {
        self.added.is_empty() && self.removed.is_empty() && self.lid.is_none() && !self.config_reloaded
    }
    pub(crate) fn due(&self) -> bool {
        match (self.first, self.last) {
            (Some(f), Some(l)) => l.elapsed() >= HOTPLUG_QUIET_WINDOW || f.elapsed() >= HOTPLUG_MAX_BURST,
            _ => false,
        }
    }
    pub(crate) fn add(&mut self, name: &str) {
        self.removed.retain(|n| n != name);
        if !self.added.iter().any(|n| n == name) {
            self.added.push(name.to_string());
        }
        self.touch();
    }
    pub(crate) fn remove(&mut self, name: &str) {
        // Plugged and unplugged within one burst (flapping cable): net zero,
        // but still resolve — the port may now carry a different monitor.
        self.added.retain(|n| n != name);
        if !self.removed.iter().any(|n| n == name) {
            self.removed.push(name.to_string());
        }
        self.touch();
    }
}


pub(crate) struct DaemonState {
    pub(crate) burst: HotplugBurst,
    pub(crate) known_fingerprint: String,
    pub(crate) last_lid: Option<LidState>,
    pub(crate) was_locked: bool,
    pub(crate) unlocked_at: Option<Instant>,
    pub(crate) mono_ref: Instant,
    pub(crate) uptime_ref: Option<f64>,
    pub(crate) last_pending_check: Instant,
    pub(crate) last_lid_poll: Instant,
    pub(crate) last_resume_check: Instant,
    pub(crate) last_snapshot: Instant,
    /// ws dispatch ref → (connector, hardware key), refreshed periodically so
    /// we know where workspaces lived *before* Hyprland evacuated them.
    pub(crate) ws_locations: HashMap<String, (String, String)>,
    /// Outputs that vanished while their screen was asleep.
    pub(crate) dpms_deferred: HashMap<String, Instant>,
    /// Last known DPMS state per output.
    pub(crate) dpms_state: HashMap<String, bool>,
    pub(crate) screens_woke_at: Option<Instant>,
}

impl DaemonState {
    pub(crate) fn new() -> Self {
        let now = Instant::now();
        Self {
            burst: HotplugBurst::default(),
            known_fingerprint: String::new(),
            last_lid: read_acpi_lid(),
            was_locked: is_locked(),
            unlocked_at: None,
            mono_ref: now,
            uptime_ref: uptime_secs(),
            last_pending_check: now,
            last_lid_poll: now,
            last_resume_check: now,
            last_snapshot: now - SNAPSHOT_INTERVAL,
            ws_locations: HashMap::new(),
            dpms_deferred: HashMap::new(),
            dpms_state: HashMap::new(),
            screens_woke_at: None,
        }
    }

    pub(crate) fn resolve(&mut self, trigger: Trigger) -> Option<ResolveResult> {
        match auto_resolve(trigger, None) {
            Ok(r) => {
                log_info(&format!("{}: {} ({:?})", trigger.label(), r.decision, r.outcome));
                self.known_fingerprint = r.fingerprint.clone();
                Some(r)
            }
            Err(e) => {
                log_error(&format!("{} resolve failed: {e}", trigger.label()));
                let cfg = load_config();
                if let Ok(s) = Snapshot::capture(&cfg) {
                    self.known_fingerprint = s.fingerprint.clone();
                    if s.active_standalone().is_empty() {
                        let _ = emergency_fallback_laptop();
                    }
                }
                None
            }
        }
    }

    pub(crate) fn on_event(&mut self, ev: HyprEvent) {
        let cfg = load_config();
        let txn = read_recent_txn();
        match ev {
            HyprEvent::MonitorAdded(name) => {
                if !connector_kind(&name).manageable() {
                    if name.eq_ignore_ascii_case("FALLBACK") {
                        // Hyprland only creates FALLBACK when nothing else is left.
                        log_warn("Hyprland fell back to its placeholder output — no real display is active");
                        self.burst.remove(&name);
                    }
                    return;
                }
                if txn.as_ref().map(|t| t.enabled.contains(&name)).unwrap_or(false) {
                    log_debug(&format!("ignoring echo: {name} added by our own transaction"));
                    return;
                }
                if self.dpms_deferred.remove(&name).is_some() {
                    log_info(&format!("{name} is back after sleeping; no reorganisation needed"));
                    // Still resolve (idempotent) so workspaces return home.
                }
                log_info(&format!("monitor added: {name}"));
                self.burst.add(&name);
            }
            HyprEvent::MonitorRemoved(name) => {
                if !connector_kind(&name).manageable() {
                    return;
                }
                if txn.as_ref().map(|t| t.disabled.contains(&name)).unwrap_or(false) {
                    log_debug(&format!("ignoring echo: {name} removed by our own transaction"));
                    return;
                }
                let drm = read_drm_connectors();
                let status = drm_status_in(&drm, &name);
                // Remember where its workspaces lived before Hyprland moved them.
                if cfg.restore_workspaces {
                    let homes: Vec<(String, String, String)> = self
                        .ws_locations
                        .iter()
                        .filter(|(_, (out, _))| out == &name)
                        .filter(|(ws, _)| !ws.starts_with("special") && ws.parse::<i64>().map(|id| id > 0).unwrap_or(true))
                        .map(|(ws, (out, key))| (ws.clone(), key.clone(), out.clone()))
                        .collect();
                    record_workspace_homes(&homes);
                }
                if status == DrmStatus::Connected && !is_locked() {
                    // Still physically attached: software disable (hyprctl,
                    // another tool) or a transient link retrain — not an unplug.
                    log_info(&format!("{name} was turned off but is still connected; checking layout"));
                } else if self.dpms_state.get(&name) == Some(&false) {
                    // Deep-sleep HPD drop (common on DisplayPort): wait until
                    // screens wake before treating it as a real unplug.
                    log_info(&format!("{name} dropped off while asleep (DPMS off); deferring until wake"));
                    self.dpms_deferred.insert(name.clone(), Instant::now());
                    self.zero_screen_check();
                    return;
                }
                log_info(&format!("monitor removed: {name}"));
                self.burst.remove(&name);
                self.zero_screen_check();
            }
            HyprEvent::LidSwitch(closed) => {
                cache_lid_state(closed);
                // ACPI, when present, is authoritative (debounces bouncy switches).
                let actual = read_acpi_lid().map(|l| l == LidState::Closed).unwrap_or(closed);
                if self.last_lid.map(|l| (l == LidState::Closed) != actual).unwrap_or(true) {
                    log_info(&format!("lid {}", if actual { "closed" } else { "opened" }));
                    self.last_lid = Some(if actual { LidState::Closed } else { LidState::Open });
                    self.burst.lid = Some(actual);
                    self.burst.touch();
                }
            }
            HyprEvent::ConfigReloaded => {
                if txn.is_some() {
                    log_debug("ignoring configreloaded during our own transaction window");
                    return;
                }
                // A reload re-applies hyprland.conf monitor rules, wiping the
                // layout we set. Re-apply ours.
                log_info("Hyprland config reloaded; re-applying display layout");
                self.burst.config_reloaded = true;
                self.burst.touch();
            }
        }
    }

    /// Unplugging the last lit screen must never wait for the debounce.
    pub(crate) fn zero_screen_check(&mut self) {
        let active = query_active_monitors().unwrap_or_default();
        let lit = active.iter().filter(|m| !m.disabled && connector_kind(&m.name).manageable()).count();
        if lit == 0 {
            log_warn("no display left enabled — recovering immediately");
            let _ = emergency_fallback_laptop();
        }
    }

    pub(crate) fn flush_burst(&mut self) {
        let burst = std::mem::take(&mut self.burst);
        if burst.is_empty() {
            return;
        }
        let trigger = match burst.lid {
            Some(true) => Trigger::LidClosed,
            Some(false) => Trigger::LidOpened,
            None if burst.added.is_empty() && burst.removed.is_empty() && burst.config_reloaded => Trigger::ConfigReload,
            None => Trigger::Hotplug,
        };
        let old_fp = self.known_fingerprint.clone();
        let Some(result) = self.resolve(trigger) else { return };
        let cfg = load_config();

        let setup_changed = result.fingerprint != old_fp;
        if setup_changed && !is_locked() {
            handle_audio_after_hotplug(burst.added.clone(), burst.removed.clone(), &cfg);
            let osd = match cfg.osd_on_hotplug.to_ascii_lowercase().as_str() {
                "always" => !burst.added.is_empty(),
                "never" => false,
                _ => !burst.added.is_empty() && result.matched_profile.is_none(),
            };
            if osd {
                trigger_island_display_osd();
            }
        }
        self.refresh_snapshot();
    }

    /// Periodic cheap view of workspaces + DPMS, plus drift detection.
    pub(crate) fn refresh_snapshot(&mut self) {
        self.last_snapshot = Instant::now();
        let Ok(all) = run_hyprctl_monitors(&["monitors", "all", "-j"]) else { return };
        let keys = assign_hardware_keys(&all);
        self.ws_locations = query_workspaces()
            .into_iter()
            .filter(|w| !w.monitor.is_empty())
            .map(|w| {
                let key = keys.get(&w.monitor).cloned().unwrap_or_else(|| format!("port_{}", w.monitor));
                (w.dispatch_ref(), (w.monitor.clone(), key))
            })
            .collect();

        let mut any_woke = false;
        for m in all.iter().filter(|m| !m.disabled) {
            let prev = self.dpms_state.insert(m.name.clone(), m.dpms_status);
            if prev == Some(false) && m.dpms_status {
                any_woke = true;
            }
        }
        if any_woke {
            self.screens_woke_at = Some(Instant::now());
        }
        // Deferred sleepers that are still missing after the screens woke
        // were really unplugged.
        if let Some(woke) = self.screens_woke_at {
            if woke.elapsed() >= DPMS_WAKE_GRACE && !self.dpms_deferred.is_empty() {
                let gone: Vec<String> = self.dpms_deferred.keys().filter(|n| !all.iter().any(|m| &m.name == *n && !m.disabled)).cloned().collect();
                self.dpms_deferred.clear();
                for n in gone {
                    log_info(&format!("{n} did not come back after wake; treating as unplugged"));
                    self.burst.remove(&n);
                }
            }
        }

        // Drift: the connected set changed without us seeing an event
        // (missed while reconnecting, or a KVM that doesn't emit HPD cleanly).
        if self.burst.is_empty() && self.dpms_deferred.is_empty() && !self.known_fingerprint.is_empty() {
            let cfg = load_config();
            let snap = Snapshot::from_parts(all, None, read_drm_connectors(), read_lid_state(), is_locked(), &cfg);
            if snap.fingerprint != self.known_fingerprint && !snap.managed.is_empty() {
                log_info("connected displays changed without an event; resolving");
                self.burst.touch();
                self.burst.config_reloaded = false;
                self.burst.added.push(String::from("(drift)"));
            }
            if !snap.locked && snap.active_standalone().is_empty() && snap.managed.iter().any(|m| snap.drm_status(&m.name) == DrmStatus::Connected) {
                log_warn("watchdog: displays are connected but none is enabled");
                let _ = emergency_fallback_laptop();
            }
        }
    }

    pub(crate) fn tick(&mut self) {
        if !self.burst.is_empty() && self.burst.due() {
            self.flush_burst();
        }

        if self.last_pending_check.elapsed() >= PENDING_CHECK_INTERVAL {
            self.last_pending_check = Instant::now();
            let locked = is_locked();
            if self.was_locked && !locked {
                log_info("session unlocked");
                self.unlocked_at = Some(Instant::now());
            }
            if !self.was_locked && locked {
                log_debug("session locked");
                self.unlocked_at = None;
            }
            self.was_locked = locked;
            if !locked {
                if let Some(t) = self.unlocked_at {
                    if t.elapsed() >= UNLOCK_GRACE {
                        self.unlocked_at = None;
                        match resolve_pending() {
                            Ok(Some(_)) => {
                                if let Ok(s) = Snapshot::capture(&load_config()) {
                                    self.known_fingerprint = s.fingerprint;
                                }
                            }
                            Ok(None) => {}
                            Err(e) => log_warn(&format!("replaying deferred work failed: {e}")),
                        }
                    }
                } else if pending_exists() && self.burst.is_empty() {
                    // Pending work left from before we started (or the lock
                    // screen never ran its handler): replay it now.
                    self.unlocked_at = Some(Instant::now());
                }
            }
        }

        if self.last_lid_poll.elapsed() >= LID_POLL_INTERVAL {
            self.last_lid_poll = Instant::now();
            // Hyprland doesn't forward lid events on every build; poll ACPI.
            if let Some(now) = read_acpi_lid() {
                if self.last_lid != Some(now) {
                    self.on_event(HyprEvent::LidSwitch(now == LidState::Closed));
                }
            }
        }

        if self.last_resume_check.elapsed() >= RESUME_CHECK_INTERVAL {
            self.last_resume_check = Instant::now();
            if let (Some(up_now), Some(up_ref)) = (uptime_secs(), self.uptime_ref) {
                let slept = (up_now - up_ref) - self.mono_ref.elapsed().as_secs_f64();
                if slept > RESUME_JUMP_THRESHOLD {
                    log_info(&format!("resumed from suspend (~{slept:.0}s asleep); letting DRM settle"));
                    thread::sleep(RESUME_SETTLE);
                    self.burst = HotplugBurst::default();
                    self.dpms_deferred.clear();
                    self.last_lid = read_acpi_lid().or(self.last_lid);
                    self.resolve(Trigger::Resume);
                    self.refresh_snapshot();
                }
            }
            self.uptime_ref = uptime_secs();
            self.mono_ref = Instant::now();
        }

        if self.last_snapshot.elapsed() >= SNAPSHOT_INTERVAL {
            self.refresh_snapshot();
        }
    }
}


