//! Display Layout & Workspace Evacuation Planner (`planner.rs`)
//!
//! Pure deterministic calculation engine for Windows/macOS style projection modes:
//! - `InternalOnly`: Enables built-in panel at (0,0), evacuates workspaces from externals, disables externals.
//! - `ExternalOnly`: Enables external monitor(s) starting at (0,0), evacuates all internal workspaces to external, disables internal panel.
//! - `Extend`: Arranges internal + external monitors with logical scale/transform offsets.
//! - `Mirror`: Negotiates highest common resolution and mirrors internal onto external(s).
//!
//! Strictly pure Rust — zero shell execution or IPC calls.

use crate::display::config::DisplayConfigStore;
use crate::display::discovery::find_best_common_mirror_mode;
use crate::display::model::{
    DisplayError, ExtendDirection, HardwareSnapshot, LayoutPlan, LidState, Monitor, Position,
    PowerState, ProjectionMode, TargetMonitorConfig, Transform, WorkspaceMigration,
};

/// Generates an atomic `LayoutPlan` given the current hardware snapshot, user config store,
/// and optional explicit mode/direction overrides.
pub fn build_layout_plan(
    snapshot: &HardwareSnapshot,
    config: &DisplayConfigStore,
    requested_mode: Option<ProjectionMode>,
    requested_direction: Option<ExtendDirection>,
) -> Result<LayoutPlan, DisplayError> {
    let internal = snapshot.internal_monitor();
    let externals = snapshot.external_monitors();

    // 1. Determine effective projection mode considering hardware availability and laptop lid policy
    let (saved_mode, saved_dir) = config.resolve_desired_mode(snapshot);
    let direction = requested_direction.unwrap_or(saved_dir);
    let mut effective_mode = requested_mode.unwrap_or(saved_mode);

    // Clamshell override: If laptop lid is closed and at least one external monitor is connected,
    // automatically force ExternalOnly (macOS / Windows clamshell behavior).
    if snapshot.lid_state == LidState::Closed && !externals.is_empty() {
        let allow_clamshell = match snapshot.power_state {
            PowerState::AcOnline | PowerState::Unknown => config.clamshell_on_ac,
            PowerState::Battery => config.clamshell_on_battery,
        };
        if allow_clamshell {
            effective_mode = ProjectionMode::ExternalOnly;
        }
    }

    // Fallback: If no external monitor is connected, we must use InternalOnly
    if externals.is_empty() {
        effective_mode = ProjectionMode::InternalOnly;
    } else if internal.is_none() {
        // Desktop PC or headless internal panel -> always ExternalOnly / multi-external
        effective_mode = ProjectionMode::ExternalOnly;
    }

    let mut plan = match effective_mode {
        ProjectionMode::InternalOnly => plan_internal_only(snapshot, config)?,
        ProjectionMode::ExternalOnly => plan_external_only(snapshot, config, direction)?,
        ProjectionMode::Extend => plan_extend(snapshot, config, direction)?,
        ProjectionMode::Mirror => plan_mirror(snapshot, config)?,
    };

    // Also explicitly disable any lingering "ghost" monitors cached in Hyprland
    for ghost in snapshot
        .monitors
        .iter()
        .filter(|m| m.is_ghost && m.enabled_in_compositor)
    {
        if !plan.disable_configs.iter().any(|d| d.name == ghost.name) {
            // Evacuate workspaces off the ghost monitor to primary
            for ws in snapshot
                .workspaces
                .iter()
                .filter(|w| w.monitor_name == ghost.name)
            {
                plan.workspace_migrations.push(WorkspaceMigration {
                    workspace_id: ws.id,
                    from_monitor: ghost.name.clone(),
                    to_monitor: plan.primary_monitor.clone(),
                });
            }

            plan.disable_configs.push(TargetMonitorConfig {
                name: ghost.name.clone(),
                enabled: false,
                mode_spec: String::new(),
                position: Position::ORIGIN,
                scale: 1.0,
                transform: Transform::Normal,
                mirror_source: None,
            });
        }
    }

    Ok(plan)
}

/// Resolves mode specification, scale, and transform for a monitor using saved preferences or defaults.
fn resolve_monitor_params(
    monitor: &Monitor,
    config: &DisplayConfigStore,
) -> (String, f32, Transform) {
    if let Some(pref) = config.preference_for_monitor(monitor) {
        let mode_spec = pref
            .preferred_mode_spec
            .clone()
            .or_else(|| monitor.preferred_mode.map(|m| m.to_hyprland_mode()))
            .unwrap_or_else(|| "preferred".to_string());
        let scale = if pref.scale <= 0.0 { 1.0 } else { pref.scale };
        return (mode_spec, scale, pref.transform);
    }

    let mode_spec = monitor
        .preferred_mode
        .map(|m| m.to_hyprland_mode())
        .unwrap_or_else(|| "preferred".to_string());
    let scale = if monitor.scale <= 0.0 {
        1.0
    } else {
        monitor.scale
    };
    (mode_spec, scale, monitor.transform)
}

/// Calculates logical dimensions (width, height) of a monitor for a planned scale and transform.
///
/// The `mode_spec` parameter (e.g. `"2560x1440@144.00"`) takes highest priority.
/// If it is provided and parseable we use those dimensions, which avoids gaps or overlaps
/// in Extend mode when a user has saved a non-preferred resolution override.
fn planned_logical_size(monitor: &Monitor, scale: f32, transform: Transform) -> (i32, i32) {
    // Try to parse an explicit WxH[@Hz] string so saved mode specs are honoured.
    fn parse_mode_spec_dimensions(spec: &str) -> Option<(u32, u32)> {
        // Accepts "WxH" or "WxH@Hz"
        let wh = spec.split('@').next()?;
        let mut parts = wh.splitn(2, 'x');
        let w: u32 = parts.next()?.trim().parse().ok()?;
        let h: u32 = parts.next()?.trim().parse().ok()?;
        if w > 0 && h > 0 { Some((w, h)) } else { None }
    }

    let (raw_w, raw_h) = match monitor.preferred_mode.or(monitor.current_mode) {
        Some(m) => (m.width, m.height),
        None => (1920, 1080),
    };

    let (oriented_w, oriented_h) = if transform.is_rotated_90_or_270() {
        (raw_h, raw_w)
    } else {
        (raw_w, raw_h)
    };

    let safe_scale = if scale <= 0.0 { 1.0 } else { scale };
    let logical_w = ((oriented_w as f32) / safe_scale).round() as i32;
    let logical_h = ((oriented_h as f32) / safe_scale).round() as i32;
    (logical_w.max(1), logical_h.max(1))
}

/// Same as `planned_logical_size` but also accepts an optional saved mode spec string
/// (e.g. `"2560x1440@144.00"`) that takes priority over the monitor's preferred/current mode.
///
/// Call this variant from layout builders that have access to the config store to prevent
/// geometry gaps or overlaps when the user has saved a custom resolution.
fn planned_logical_size_with_spec(
    monitor: &Monitor,
    scale: f32,
    transform: Transform,
    mode_spec: Option<&str>,
) -> (i32, i32) {
    fn parse_wh(spec: &str) -> Option<(u32, u32)> {
        let wh = spec.split('@').next()?;
        let mut parts = wh.splitn(2, 'x');
        let w: u32 = parts.next()?.trim().parse().ok()?;
        let h: u32 = parts.next()?.trim().parse().ok()?;
        if w > 0 && h > 0 { Some((w, h)) } else { None }
    }

    // If a non-keyword mode_spec was provided and is parseable, use its dimensions.
    let (raw_w, raw_h) = if let Some(spec) = mode_spec {
        if let Some((w, h)) = parse_wh(spec) {
            (w, h)
        } else {
            // "preferred" / "highres" / unparseable keyword — fall back to monitor struct
            match monitor.preferred_mode.or(monitor.current_mode) {
                Some(m) => (m.width, m.height),
                None => (1920, 1080),
            }
        }
    } else {
        match monitor.preferred_mode.or(monitor.current_mode) {
            Some(m) => (m.width, m.height),
            None => (1920, 1080),
        }
    };

    let (oriented_w, oriented_h) = if transform.is_rotated_90_or_270() {
        (raw_h, raw_w)
    } else {
        (raw_w, raw_h)
    };

    let safe_scale = if scale <= 0.0 { 1.0 } else { scale };
    let logical_w = ((oriented_w as f32) / safe_scale).round() as i32;
    let logical_h = ((oriented_h as f32) / safe_scale).round() as i32;
    (logical_w.max(1), logical_h.max(1))
}

/// 1. INTERNAL ONLY:
/// - Anchor `eDP-1` at `0x0`.
/// - Evacuate all workspaces from external monitors back to `eDP-1`.
/// - Disable all external monitors.
fn plan_internal_only(
    snapshot: &HardwareSnapshot,
    config: &DisplayConfigStore,
) -> Result<LayoutPlan, DisplayError> {
    let internal = snapshot
        .internal_monitor()
        .ok_or(DisplayError::InternalMonitorNotFound)?;

    let (mode_spec, scale, transform) = resolve_monitor_params(internal, config);

    let enable_configs = vec![TargetMonitorConfig {
        name: internal.name.clone(),
        enabled: true,
        mode_spec,
        position: Position::ORIGIN,
        scale,
        transform,
        mirror_source: None,
    }];

    let mut workspace_migrations = Vec::new();
    let mut disable_configs = Vec::new();

    for ext in snapshot.external_monitors() {
        for ws in snapshot
            .workspaces
            .iter()
            .filter(|w| w.monitor_name == ext.name)
        {
            workspace_migrations.push(WorkspaceMigration {
                workspace_id: ws.id,
                from_monitor: ext.name.clone(),
                to_monitor: internal.name.clone(),
            });
        }

        disable_configs.push(TargetMonitorConfig {
            name: ext.name.clone(),
            enabled: false,
            mode_spec: String::new(),
            position: Position::ORIGIN,
            scale: 1.0,
            transform: Transform::Normal,
            mirror_source: None,
        });
    }

    Ok(LayoutPlan {
        mode: ProjectionMode::InternalOnly,
        primary_monitor: internal.name.clone(),
        enable_configs,
        workspace_migrations,
        disable_configs,
        hold_lid_inhibit: false,
    })
}

/// 2. EXTERNAL ONLY (Windows "Second screen only" / macOS Clamshell):
/// - Anchor primary external monitor strictly at `0x0` so it covers the entire desktop space.
/// - Chain any additional external monitors relative to the primary external.
/// - Evacuate EVERY workspace from `eDP-1` to the primary external monitor BEFORE disabling `eDP-1`.
/// - Disable `eDP-1` and hold `systemd-logind` lid sleep inhibit so closing the lid won't suspend.
fn plan_external_only(
    snapshot: &HardwareSnapshot,
    config: &DisplayConfigStore,
    direction: ExtendDirection,
) -> Result<LayoutPlan, DisplayError> {
    let externals = snapshot.external_monitors();
    if externals.is_empty() {
        return Err(DisplayError::ExternalMonitorNotFound);
    }

    let primary_ext = externals[0];
    let mut enable_configs = Vec::new();
    let mut cursor_x = 0i32;
    let mut cursor_y = 0i32;

    for (idx, ext) in externals.iter().enumerate() {
        let (mode_spec, scale, transform) = resolve_monitor_params(ext, config);
        let (w, h) = planned_logical_size_with_spec(ext, scale, transform, Some(&mode_spec));

        let pos = if idx == 0 {
            Position::ORIGIN
        } else {
            match direction {
                // Right: chain rightward → each monitor placed to the right of the previous
                ExtendDirection::Right => {
                    let p = Position::new(cursor_x, 0);
                    cursor_x += w;
                    p
                }
                // Left: chain leftward → each monitor placed to the left (negative X, then normalize)
                ExtendDirection::Left => {
                    cursor_x -= w;
                    Position::new(cursor_x, 0)
                }
                // Below: chain downward → each monitor placed below the previous
                ExtendDirection::Below => {
                    let p = Position::new(0, cursor_y);
                    cursor_y += h;
                    p
                }
                // Above: chain upward → each monitor placed above (negative Y, then normalize)
                ExtendDirection::Above => {
                    cursor_y -= h;
                    Position::new(0, cursor_y)
                }
            }
        };

        // For idx==0, still update cursors so subsequent monitors chain correctly.
        if idx == 0 {
            cursor_x += w;
            cursor_y += h;
        }

        enable_configs.push(TargetMonitorConfig {
            name: ext.name.clone(),
            enabled: true,
            mode_spec,
            position: pos,
            scale,
            transform,
            mirror_source: None,
        });
    }

    let mut workspace_migrations = Vec::new();
    let mut disable_configs = Vec::new();

    if let Some(internal) = snapshot.internal_monitor() {
        // Evacuate all workspaces currently on the internal laptop screen to the primary external monitor
        for ws in snapshot
            .workspaces
            .iter()
            .filter(|w| w.monitor_name == internal.name)
        {
            workspace_migrations.push(WorkspaceMigration {
                workspace_id: ws.id,
                from_monitor: internal.name.clone(),
                to_monitor: primary_ext.name.clone(),
            });
        }

        // If no workspaces were listed on internal, still ensure active_workspace_id is migrated
        if workspace_migrations.is_empty() {
            if let Some(active_id) = internal.active_workspace_id {
                if active_id > 0 {
                    workspace_migrations.push(WorkspaceMigration {
                        workspace_id: active_id,
                        from_monitor: internal.name.clone(),
                        to_monitor: primary_ext.name.clone(),
                    });
                }
            }
        }

        disable_configs.push(TargetMonitorConfig {
            name: internal.name.clone(),
            enabled: false,
            mode_spec: String::new(),
            position: Position::ORIGIN,
            scale: 1.0,
            transform: Transform::Normal,
            mirror_source: None,
        });
    }

    // Normalize any negative coordinates if ExtendDirection::Left or Above was used with multiple externals
    normalize_positions(&mut enable_configs);

    Ok(LayoutPlan {
        mode: ProjectionMode::ExternalOnly,
        primary_monitor: primary_ext.name.clone(),
        enable_configs,
        workspace_migrations,
        disable_configs,
        hold_lid_inhibit: true,
    })
}

/// 3. EXTEND:
/// - Keep internal display enabled and place external display(s) in `direction` (`Right`, `Left`, `Above`, `Below`).
/// - Normalizes coordinates so the top-left-most monitor sits at non-negative coordinates.
fn plan_extend(
    snapshot: &HardwareSnapshot,
    config: &DisplayConfigStore,
    direction: ExtendDirection,
) -> Result<LayoutPlan, DisplayError> {
    let internal = snapshot
        .internal_monitor()
        .ok_or(DisplayError::InternalMonitorNotFound)?;
    let externals = snapshot.external_monitors();
    if externals.is_empty() {
        return plan_internal_only(snapshot, config);
    }

    let (int_mode, int_scale, int_transform) = resolve_monitor_params(internal, config);
    let (int_w, int_h) =
        planned_logical_size_with_spec(internal, int_scale, int_transform, Some(&int_mode));

    let mut enable_configs = Vec::new();
    enable_configs.push(TargetMonitorConfig {
        name: internal.name.clone(),
        enabled: true,
        mode_spec: int_mode,
        position: Position::ORIGIN,
        scale: int_scale,
        transform: int_transform,
        mirror_source: None,
    });

    let mut offset_right = int_w;
    let mut offset_left = 0i32;
    let mut offset_below = int_h;
    let mut offset_above = 0i32;

    for ext in &externals {
        let (ext_mode, ext_scale, ext_transform) = resolve_monitor_params(ext, config);
        let (ext_w, ext_h) =
            planned_logical_size_with_spec(ext, ext_scale, ext_transform, Some(&ext_mode));

        let pos = match direction {
            ExtendDirection::Right => {
                let p = Position::new(offset_right, 0);
                offset_right += ext_w;
                p
            }
            ExtendDirection::Left => {
                offset_left -= ext_w;
                Position::new(offset_left, 0)
            }
            ExtendDirection::Below => {
                let p = Position::new(0, offset_below);
                offset_below += ext_h;
                p
            }
            ExtendDirection::Above => {
                offset_above -= ext_h;
                Position::new(0, offset_above)
            }
        };

        enable_configs.push(TargetMonitorConfig {
            name: ext.name.clone(),
            enabled: true,
            mode_spec: ext_mode,
            position: pos,
            scale: ext_scale,
            transform: ext_transform,
            mirror_source: None,
        });
    }

    // Shift all positions so minimum X and Y are 0 (prevents negative coordinate bugs in Wayland)
    normalize_positions(&mut enable_configs);

    Ok(LayoutPlan {
        mode: ProjectionMode::Extend,
        primary_monitor: externals[0].name.clone(),
        enable_configs,
        workspace_migrations: Vec::new(),
        disable_configs: Vec::new(),
        hold_lid_inhibit: true,
    })
}

/// 4. MIRROR:
/// - Enables internal display at `0x0`.
/// - Configures external display(s) at `0x0` with `mirror, <internal_name>` and matched common resolution.
fn plan_mirror(
    snapshot: &HardwareSnapshot,
    config: &DisplayConfigStore,
) -> Result<LayoutPlan, DisplayError> {
    let internal = snapshot
        .internal_monitor()
        .ok_or(DisplayError::InternalMonitorNotFound)?;
    let externals = snapshot.external_monitors();
    if externals.is_empty() {
        return plan_internal_only(snapshot, config);
    }

    let (int_mode, int_scale, int_transform) = resolve_monitor_params(internal, config);

    let mut enable_configs = Vec::new();
    enable_configs.push(TargetMonitorConfig {
        name: internal.name.clone(),
        enabled: true,
        mode_spec: int_mode,
        position: Position::ORIGIN,
        scale: int_scale,
        transform: int_transform,
        mirror_source: None,
    });

    for ext in &externals {
        let mode_spec = find_best_common_mirror_mode(internal, ext)
            .map(|m| m.to_hyprland_mode())
            .or_else(|| ext.preferred_mode.map(|m| m.to_hyprland_mode()))
            .unwrap_or_else(|| "preferred".to_string());

        enable_configs.push(TargetMonitorConfig {
            name: ext.name.clone(),
            enabled: true,
            mode_spec,
            position: Position::ORIGIN,
            scale: 1.0,
            transform: Transform::Normal,
            mirror_source: Some(internal.name.clone()),
        });
    }

    Ok(LayoutPlan {
        mode: ProjectionMode::Mirror,
        primary_monitor: internal.name.clone(),
        enable_configs,
        workspace_migrations: Vec::new(),
        disable_configs: Vec::new(),
        hold_lid_inhibit: true,
    })
}

/// Shifts all planned monitor coordinates so the bounding box starts at `(0, 0)` with no negative coordinates.
fn normalize_positions(configs: &mut [TargetMonitorConfig]) {
    if configs.is_empty() {
        return;
    }

    let min_x = configs.iter().map(|c| c.position.x).min().unwrap_or(0);
    let min_y = configs.iter().map(|c| c.position.y).min().unwrap_or(0);

    if min_x < 0 || min_y < 0 {
        for cfg in configs.iter_mut() {
            cfg.position.x -= min_x;
            cfg.position.y -= min_y;
        }
    }
}
