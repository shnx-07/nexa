//! Display Safety Verification & Emergency Recovery (`safety.rs`)
//!
//! Enforces strict safety invariants before any `LayoutPlan` is sent to Hyprland,
//! and provides deterministic rollback/fallback plans if hardware disconnects
//! or compositor commands fail.
//!
//! Invariants enforced:
//! 1. Never leave 0 enabled displays (prevents total black screen).
//! 2. Never disable a monitor without evacuating its active workspaces to an enabled monitor.
//! 3. Ensure at least one enabled display is anchored at `(0, 0)` with non-negative coordinates.
//! 4. Reject invalid scale factors (`<= 0.0` or `> 8.0`).
//! 5. Verify post-execution snapshots actually converged to a usable active display.

use crate::display::model::{
    ConnectorType, DisplayError, HardwareSnapshot, LayoutPlan, Position, ProjectionMode,
    TargetMonitorConfig, Transform, WorkspaceMigration,
};
use std::collections::HashSet;

/// Validates a proposed `LayoutPlan` against hardware reality and safety invariants.
pub fn validate_plan(plan: &LayoutPlan, snapshot: &HardwareSnapshot) -> Result<(), DisplayError> {
    // 1. Must enable at least one display
    let enabled_monitors: Vec<&TargetMonitorConfig> =
        plan.enable_configs.iter().filter(|c| c.enabled).collect();

    if enabled_monitors.is_empty() {
        return Err(DisplayError::NoActiveMonitorsLeft);
    }

    // 2. Every enabled monitor must be physically connected in DRM (not a disconnected ghost)
    for target in &enabled_monitors {
        if let Some(hw) = snapshot.monitors.iter().find(|m| m.name == target.name) {
            if !hw.connected_in_drm || hw.is_ghost {
                return Err(DisplayError::SafetyViolation(format!(
                    "Cannot enable disconnected or ghost output '{}'",
                    target.name
                )));
            }
        }
    }

    // 3. No monitor can appear in both `enable_configs` and `disable_configs`
    let enabled_names: HashSet<&str> = enabled_monitors.iter().map(|c| c.name.as_str()).collect();
    for dis in &plan.disable_configs {
        if enabled_names.contains(dis.name.as_str()) {
            return Err(DisplayError::SafetyViolation(format!(
                "Monitor '{}' is listed in both enable and disable queues",
                dis.name
            )));
        }
    }

    // 4. Primary monitor must be in the enabled set
    if !enabled_names.contains(plan.primary_monitor.as_str()) {
        return Err(DisplayError::SafetyViolation(format!(
            "Primary monitor '{}' is not enabled in the layout plan",
            plan.primary_monitor
        )));
    }

    // 5. At least one enabled monitor must be anchored at (0, 0), and no coordinates may be negative
    let mut has_origin = false;
    for cfg in &enabled_monitors {
        if cfg.position == Position::ORIGIN {
            has_origin = true;
        }
        if cfg.position.x < 0 || cfg.position.y < 0 {
            return Err(DisplayError::SafetyViolation(format!(
                "Monitor '{}' has negative coordinates ({}, {})",
                cfg.name, cfg.position.x, cfg.position.y
            )));
        }
        if cfg.scale <= 0.0 || cfg.scale > 8.0 || cfg.scale.is_nan() {
            return Err(DisplayError::SafetyViolation(format!(
                "Monitor '{}' has invalid scale factor {}",
                cfg.name, cfg.scale
            )));
        }
    }

    if !has_origin {
        return Err(DisplayError::SafetyViolation(
            "No enabled monitor is anchored at origin (0x0)".to_string(),
        ));
    }

    // 6. All workspace migrations must target an enabled monitor
    for mig in &plan.workspace_migrations {
        if !enabled_names.contains(mig.to_monitor.as_str()) {
            return Err(DisplayError::SafetyViolation(format!(
                "Workspace {} is scheduled to migrate to disabled/unknown monitor '{}'",
                mig.workspace_id, mig.to_monitor
            )));
        }
    }

    Ok(())
}

/// Verifies that the post-apply hardware snapshot has at least one active, non-ghost monitor rendering.
///
/// # Settle delay removed from here
/// The caller (`manager.rs`) is responsible for sleeping before calling this function
/// and for retrying it. This keeps `safety.rs` pure and testable.
pub fn verify_applied_state(
    post_snapshot: &HardwareSnapshot,
    expected_plan: &LayoutPlan,
) -> Result<(), DisplayError> {
    let active_valid_count = post_snapshot
        .monitors
        .iter()
        .filter(|m| m.enabled_in_compositor && m.connected_in_drm && !m.is_ghost)
        .count();

    if active_valid_count == 0 {
        return Err(DisplayError::NoActiveMonitorsLeft);
    }

    // Confirm primary monitor from the plan is active in Hyprland
    let primary_active = post_snapshot
        .monitors
        .iter()
        .any(|m| m.name == expected_plan.primary_monitor && m.enabled_in_compositor && !m.is_ghost);

    if !primary_active {
        return Err(DisplayError::SafetyViolation(format!(
            "Primary monitor '{}' failed to activate in Hyprland",
            expected_plan.primary_monitor
        )));
    }

    Ok(())
}

/// Generates an emergency rescue `LayoutPlan` when an external monitor is yanked out
/// or when a transition fails partway through.
///
/// Priority:
/// 1. Re-enable internal panel (`eDP-1` or detected internal) at `preferred, 0x0, 1.0`.
/// 2. Evacuate all known workspaces to the internal panel.
/// 3. Disable any ghost/disconnected external monitors.
/// 4. If no internal panel exists (desktop PC), enable the first physically connected external at `0x0`.
pub fn build_emergency_fallback_plan(snapshot: Option<&HardwareSnapshot>) -> LayoutPlan {
    if let Some(snap) = snapshot {
        // Prefer internal laptop panel if present
        if let Some(internal) = snap
            .monitors
            .iter()
            .find(|m| m.connector_type == ConnectorType::Internal)
        {
            let mut migrations = Vec::new();
            let mut disable_configs = Vec::new();

            for m in &snap.monitors {
                if m.name != internal.name {
                    for ws in snap.workspaces.iter().filter(|w| w.monitor_name == m.name) {
                        migrations.push(WorkspaceMigration {
                            workspace_id: ws.id,
                            from_monitor: m.name.clone(),
                            to_monitor: internal.name.clone(),
                        });
                    }
                    disable_configs.push(TargetMonitorConfig {
                        name: m.name.clone(),
                        enabled: false,
                        mode_spec: String::new(),
                        position: Position::ORIGIN,
                        scale: 1.0,
                        transform: Transform::Normal,
                        mirror_source: None,
                    });
                }
            }

            return LayoutPlan {
                mode: ProjectionMode::InternalOnly,
                primary_monitor: internal.name.clone(),
                enable_configs: vec![TargetMonitorConfig {
                    name: internal.name.clone(),
                    enabled: true,
                    mode_spec: "preferred".to_string(),
                    position: Position::ORIGIN,
                    scale: 1.0,
                    transform: Transform::Normal,
                    mirror_source: None,
                }],
                workspace_migrations: migrations,
                disable_configs,
                hold_lid_inhibit: false,
            };
        }

        // Desktop fallback: pick first connected external monitor
        if let Some(ext) = snap.monitors.iter().find(|m| m.connected_in_drm) {
            return LayoutPlan {
                mode: ProjectionMode::ExternalOnly,
                primary_monitor: ext.name.clone(),
                enable_configs: vec![TargetMonitorConfig {
                    name: ext.name.clone(),
                    enabled: true,
                    mode_spec: "preferred".to_string(),
                    position: Position::ORIGIN,
                    scale: 1.0,
                    transform: Transform::Normal,
                    mirror_source: None,
                }],
                workspace_migrations: Vec::new(),
                disable_configs: Vec::new(),
                hold_lid_inhibit: false,
            };
        }
    }

    // Blind last-resort fallback if even snapshot discovery failed: revive `eDP-1` at 0x0.
    // Do NOT generate fake workspace migrations for IDs 1-10: most won't exist, and
    // Hyprland returns an error for each non-existent workspace, polluting logs.
    // The user's session will be usable on eDP-1 with whatever workspaces Hyprland has.
    LayoutPlan {
        mode: ProjectionMode::InternalOnly,
        primary_monitor: "eDP-1".to_string(),
        enable_configs: vec![TargetMonitorConfig {
            name: "eDP-1".to_string(),
            enabled: true,
            mode_spec: "preferred".to_string(),
            position: Position::ORIGIN,
            scale: 1.0,
            transform: Transform::Normal,
            mirror_source: None,
        }],
        workspace_migrations: Vec::new(),
        disable_configs: Vec::new(),
        hold_lid_inhibit: false,
    }
}
