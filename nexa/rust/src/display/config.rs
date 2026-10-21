//! Persistent Display Configuration & Profile Storage (`config.rs`)
//!
//! Manages saving and loading display profiles keyed by deterministic EDID hashes
//! rather than volatile connector names (such as `DP-1` vs `DP-2` on USB-C docks).
//! Uses atomic temp-file writes to prevent corrupted JSON state.
//! Prohibited from storing temporary hardware glitches as permanent truth.

use crate::display::model::{
    DisplayError, ExtendDirection, HardwareSnapshot, Monitor, ProjectionMode, Transform,
};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::fs;
use std::io::Write;
use std::path::{Path, PathBuf};

/// User-saved preferences for a specific physical monitor (matched via EDID hash).
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SavedMonitorPreference {
    pub edid_hash: String,
    pub make: String,
    pub model: String,
    /// Optional explicit mode override (e.g., "2560x1440@144.00"), or None for "preferred"
    pub preferred_mode_spec: Option<String>,
    pub scale: f32,
    pub transform: Transform,
}

impl SavedMonitorPreference {
    pub fn from_monitor(m: &Monitor) -> Self {
        Self {
            edid_hash: m.identity.edid_hash.clone(),
            make: m.identity.make.clone(),
            model: m.identity.model.clone(),
            preferred_mode_spec: m.current_mode.map(|mode| mode.to_hyprland_mode()),
            scale: if m.scale <= 0.0 { 1.0 } else { m.scale },
            transform: m.transform,
        }
    }
}

/// A saved multi-monitor topology profile keyed by the sorted combination of connected EDIDs.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TopologyProfile {
    /// Deterministic topology key (e.g., sorted EDID hashes joined by '+')
    pub topology_key: String,
    /// The Windows/macOS projection mode chosen by the user when this combination was active
    pub mode: ProjectionMode,
    /// Direction used when in `Extend` mode
    pub extend_direction: ExtendDirection,
    /// Preferred primary external monitor EDID hash (when multiple externals exist)
    pub preferred_external_edid: Option<String>,
}

/// Root persistent configuration structure stored on disk (`~/.config/nexa/display.json`).
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DisplayConfigStore {
    pub version: u32,
    /// Default projection mode when a brand-new, unseen external display is plugged in.
    /// Defaults to `ExternalOnly` if you want external displays to immediately take over,
    /// or `Extend` for standard dual-screen behavior.
    pub default_hotplug_mode: ProjectionMode,
    pub default_extend_direction: ExtendDirection,
    /// Whether closing the laptop lid on AC power should automatically switch to `ExternalOnly`
    pub clamshell_on_ac: bool,
    /// Whether closing the laptop lid on battery should also switch to `ExternalOnly`
    pub clamshell_on_battery: bool,
    /// Per-monitor saved scale/resolution/rotation indexed by `edid_hash`
    pub monitor_preferences: HashMap<String, SavedMonitorPreference>,
    /// Per-topology saved projection mode indexed by `topology_key`
    pub topology_profiles: HashMap<String, TopologyProfile>,
    /// Optional per-monitor wallpaper paths indexed by connector name or EDID hash
    pub wallpapers: HashMap<String, String>,
}

impl Default for DisplayConfigStore {
    fn default() -> Self {
        Self {
            version: 1,
            // Default to ExternalOnly so connecting an external monitor covers everything by default
            default_hotplug_mode: ProjectionMode::ExternalOnly,
            default_extend_direction: ExtendDirection::Right,
            clamshell_on_ac: true,
            clamshell_on_battery: true,
            monitor_preferences: HashMap::new(),
            topology_profiles: HashMap::new(),
            wallpapers: HashMap::new(),
        }
    }
}

impl DisplayConfigStore {
    /// Returns the default configuration file path (`~/.config/nexa/display.json`).
    pub fn default_config_path() -> PathBuf {
        if let Ok(xdg) = std::env::var("XDG_CONFIG_HOME") {
            if !xdg.trim().is_empty() {
                return PathBuf::from(xdg).join("nexa").join("display.json");
            }
        }
        if let Ok(home) = std::env::var("HOME") {
            return PathBuf::from(home)
                .join(".config")
                .join("nexa")
                .join("display.json");
        }
        PathBuf::from("/tmp/nexa_display.json")
    }

    /// Returns the volatile runtime recovery path (`/run/user/<uid>/nexa_display_last_good.json`).
    pub fn runtime_recovery_path() -> PathBuf {
        if let Ok(runtime_dir) = std::env::var("XDG_RUNTIME_DIR") {
            if !runtime_dir.trim().is_empty() {
                return PathBuf::from(runtime_dir).join("nexa_display_last_good.json");
            }
        }
        PathBuf::from("/tmp/nexa_display_last_good.json")
    }

    /// Loads the configuration from disk, returning `Default` if the file does not exist yet.
    ///
    /// If the file exists but contains malformed JSON, it is renamed to `<path>.bak` for
    /// diagnostics and `Default` is returned. This prevents a corrupted config file from
    /// crashing daemon startup.
    pub fn load_from_path(path: &Path) -> Result<Self, DisplayError> {
        if !path.exists() {
            return Ok(Self::default());
        }

        let raw = fs::read_to_string(path).map_err(|e| {
            DisplayError::ConfigIoError(format!("Failed to read {}: {}", path.display(), e))
        })?;

        match serde_json::from_str::<Self>(&raw) {
            Ok(config) => Ok(config),
            Err(parse_err) => {
                // Rename the malformed file so the user can inspect it later.
                let bak_path = path.with_extension("json.bak");
                if let Err(rename_err) = fs::rename(path, &bak_path) {
                    eprintln!(
                        "[NexaDisplay] Malformed config at {} and failed to rename to {}: {} (parse: {})",
                        path.display(),
                        bak_path.display(),
                        rename_err,
                        parse_err,
                    );
                } else {
                    eprintln!(
                        "[NexaDisplay] Malformed config at {} ({}). Backed up to {}. Starting with defaults.",
                        path.display(),
                        parse_err,
                        bak_path.display(),
                    );
                }
                // Fall back to defaults so the daemon can start cleanly.
                Ok(Self::default())
            }
        }
    }

    /// Saves the configuration to disk using an atomic write-then-rename pattern
    /// so a power loss or crash never leaves a half-written config file.
    pub fn save_to_path(&self, path: &Path) -> Result<(), DisplayError> {
        if let Some(parent) = path.parent() {
            fs::create_dir_all(parent).map_err(|e| {
                DisplayError::ConfigIoError(format!(
                    "Failed to create config directory {}: {}",
                    parent.display(),
                    e
                ))
            })?;
        }

        let serialized = serde_json::to_string_pretty(self).map_err(|e| {
            DisplayError::ConfigIoError(format!("Failed to serialize config: {}", e))
        })?;

        let tmp_path = path.with_extension("json.tmp");
        {
            let mut file = fs::File::create(&tmp_path).map_err(|e| {
                DisplayError::ConfigIoError(format!(
                    "Failed to create temp file {}: {}",
                    tmp_path.display(),
                    e
                ))
            })?;
            file.write_all(serialized.as_bytes()).map_err(|e| {
                DisplayError::ConfigIoError(format!("Failed to write temp config: {}", e))
            })?;
            file.sync_all().map_err(|e| {
                DisplayError::ConfigIoError(format!("Failed to fsync temp config: {}", e))
            })?;
        }

        fs::rename(&tmp_path, path).map_err(|e| {
            DisplayError::ConfigIoError(format!(
                "Failed to atomically rename {} to {}: {}",
                tmp_path.display(),
                path.display(),
                e
            ))
        })?;

        Ok(())
    }

    /// Computes a deterministic topology key from all physically connected non-ghost monitors.
    pub fn compute_topology_key(snapshot: &HardwareSnapshot) -> String {
        let mut hashes: Vec<String> = snapshot
            .monitors
            .iter()
            .filter(|m| m.connected_in_drm && !m.is_ghost)
            .map(|m| {
                if m.identity.edid_hash.is_empty() {
                    m.name.clone()
                } else {
                    m.identity.edid_hash.clone()
                }
            })
            .collect();

        hashes.sort();
        hashes.dedup();
        hashes.join("+")
    }

    /// Resolves the desired `ProjectionMode` and `ExtendDirection` for the current hardware snapshot.
    pub fn resolve_desired_mode(
        &self,
        snapshot: &HardwareSnapshot,
    ) -> (ProjectionMode, ExtendDirection) {
        let externals = snapshot.external_monitors();
        if externals.is_empty() {
            return (ProjectionMode::InternalOnly, self.default_extend_direction);
        }

        let key = Self::compute_topology_key(snapshot);
        if let Some(profile) = self.topology_profiles.get(&key) {
            return (profile.mode, profile.extend_direction);
        }

        (self.default_hotplug_mode, self.default_extend_direction)
    }

    /// Records a verified, successfully applied user mode choice into the persistent store.
    ///
    /// # Mirror mode protection
    /// In Mirror mode, Hyprland negotiates the highest *common* resolution between internal
    /// and external monitors, which is typically lower than the external monitor's native
    /// preferred resolution. Saving that negotiated mode as the external monitor's permanent
    /// preference would permanently cap it at the wrong resolution in all future non-Mirror modes.
    /// Therefore monitor preferences are **not** updated when `mode == ProjectionMode::Mirror`.
    pub fn record_successful_topology(
        &mut self,
        snapshot: &HardwareSnapshot,
        mode: ProjectionMode,
        direction: ExtendDirection,
    ) {
        // Never persist a broken or empty hardware state
        let connected_count = snapshot
            .monitors
            .iter()
            .filter(|m| m.connected_in_drm && !m.is_ghost)
            .count();
        if connected_count == 0 {
            return;
        }

        // Do NOT save per-monitor preferences in Mirror mode: the current_mode on each
        // monitor reflects the negotiated common resolution, not the monitor's native
        // preferred resolution. Persisting it would corrupt future non-Mirror layouts.
        if mode != ProjectionMode::Mirror {
            for monitor in &snapshot.monitors {
                if monitor.connected_in_drm
                    && !monitor.is_ghost
                    && !monitor.identity.edid_hash.is_empty()
                {
                    self.monitor_preferences.insert(
                        monitor.identity.edid_hash.clone(),
                        SavedMonitorPreference::from_monitor(monitor),
                    );
                }
            }
        }

        let key = Self::compute_topology_key(snapshot);
        let preferred_external_edid = snapshot
            .external_monitors()
            .first()
            .map(|m| m.identity.edid_hash.clone());

        self.topology_profiles.insert(
            key.clone(),
            TopologyProfile {
                topology_key: key,
                mode,
                extend_direction: direction,
                preferred_external_edid,
            },
        );
    }

    /// Looks up saved scale, transform, and mode spec for a given monitor.
    pub fn preference_for_monitor(&self, monitor: &Monitor) -> Option<&SavedMonitorPreference> {
        if !monitor.identity.edid_hash.is_empty() {
            if let Some(pref) = self.monitor_preferences.get(&monitor.identity.edid_hash) {
                return Some(pref);
            }
        }
        None
    }
}
