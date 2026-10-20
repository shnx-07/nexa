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

pub(crate) fn configured_primary(snap: &Snapshot, cfg: &MonitorsConfig) -> Option<String> {
    let want = cfg.primary.as_deref()?.trim();
    if want.is_empty() {
        return None;
    }
    snap.managed
        .iter()
        .find(|m| {
            let key = snap.key(&m.name);
            m.name == want || key == want || base_key(&key) == want
        })
        .map(|m| m.name.clone())
}

/// Order a group of monitors for chaining: configured primary first, then
/// the current on-screen arrangement (left→right), then the arrangement
/// last remembered in any profile, then natural connector order.
pub(crate) fn order_monitors<'a>(snap: &Snapshot, cfg: &MonitorsConfig, mut mons: Vec<&'a HyprMonitor>) -> Vec<&'a HyprMonitor> {
    let primary = configured_primary(snap, cfg);
    let remembered = |key: &str| -> Option<(i32, i32)> {
        cfg.profiles
            .iter()
            .filter(|p| p.monitors.get(key).map(|s| s.enabled && s.mirror_of.is_none()).unwrap_or(false))
            .max_by_key(|p| p.last_used_ms)
            .and_then(|p| parse_pos(&p.monitors[key].position))
    };
    mons.sort_by_key(|m| {
        let key = snap.key(&m.name);
        let (group, a, b) = if snap.is_active(&m.name) && snap.mirror_of(&m.name).is_none() && m.width > 0 {
            (0, m.x, m.y)
        } else if let Some((x, y)) = remembered(&key) {
            (1, x, y)
        } else {
            (2, 0, 0)
        };
        (primary.as_deref() != Some(m.name.as_str()), group, a, b, natural_key(&m.name))
    });
    mons
}

/// Pure planner for the built-in projection modes.
pub(crate) fn build_projection_plan(mode: &ProjectionMode, snap: &Snapshot, cfg: &MonitorsConfig) -> Result<Vec<PlannedMonitor>, String> {
    let align = parse_align(&cfg.align);
    let internals: Vec<&HyprMonitor> = snap.internals();
    let externals = order_monitors(snap, cfg, snap.externals());
    // Clamshell: lid shut with something else to show on → the built-in
    // panel is unusable. Lid shut with nothing else → keep it on (a
    // headless session is unreachable; suspend belongs to logind/hypridle).
    let clamshell = snap.lid_closed() && !externals.is_empty() && !internals.is_empty();

    let pm = |m: &HyprMonitor| plan_for(snap, cfg, m, &Overrides::default());
    let internal_block = || Block::column(internals.iter().map(|m| Block::single(pm(m))).collect(), Align::Center);
    let ext_blocks = || externals.iter().map(|m| Block::single(pm(m))).collect::<Vec<_>>();
    let disabled = |list: &[&HyprMonitor]| list.iter().map(|m| PlannedMonitor::disabled(&m.name)).collect::<Vec<_>>();

    let mut plan: Vec<PlannedMonitor> = match mode {
        ProjectionMode::InternalOnly => {
            if internals.is_empty() {
                // Desktop: "PC screen only" means the primary display only.
                let first = externals.first().ok_or("no displays connected")?;
                let mut p = vec![Block::single(pm(first)).items.remove(0)];
                p.extend(disabled(&externals[1..]));
                p
            } else {
                if clamshell {
                    return Err("the lid is closed, so the built-in display can't be used — open the lid or choose another mode".into());
                }
                let mut p = internal_block().items;
                p.extend(disabled(&externals));
                p
            }
        }
        ProjectionMode::ExternalOnly => {
            if externals.is_empty() {
                return Err("no external display connected".into());
            }
            let mut p = Block::row(ext_blocks(), align).items;
            p.extend(disabled(&internals));
            p
        }
        m if m.is_extend() => {
            if externals.is_empty() && internals.len() < 2 {
                return Err("no second display to extend onto".into());
            }
            let int_block = if clamshell { Block::default() } else { internal_block() };
            let laid = match m {
                ProjectionMode::ExtendRight => Block::row([vec![int_block], ext_blocks()].concat(), align),
                ProjectionMode::ExtendLeft => Block::row([ext_blocks(), vec![int_block]].concat(), align),
                ProjectionMode::ExtendDown => Block::column(vec![int_block, Block::row(ext_blocks(), align)], Align::Center),
                ProjectionMode::ExtendUp => Block::column(vec![Block::row(ext_blocks(), align), int_block], Align::Center),
                ProjectionMode::ExtendGrid(cols) => {
                    let cols = if *cols == 0 { cfg.grid_columns.max(1) } else { *cols };
                    let mut cells: Vec<Block> = Vec::new();
                    if !clamshell {
                        cells.extend(internals.iter().map(|m| Block::single(pm(m))));
                    }
                    cells.extend(ext_blocks());
                    let mut rows = Vec::new();
                    while !cells.is_empty() {
                        let rest = cells.split_off(cols.min(cells.len()));
                        rows.push(Block::row(std::mem::replace(&mut cells, rest), align));
                    }
                    Block::column(rows, Align::Start)
                }
                _ => unreachable!(),
            };
            let mut p = laid.items;
            if clamshell {
                log_info("lid closed: extending across external displays only");
                p.extend(disabled(&internals));
            }
            p
        }
        ProjectionMode::Mirror => {
            let usable: Vec<&HyprMonitor> = if clamshell {
                externals.clone()
            } else {
                internals.iter().chain(externals.iter()).copied().collect()
            };
            if usable.len() < 2 {
                return Err(if clamshell {
                    "only one usable display (lid closed) — nothing to mirror onto".into()
                } else {
                    "mirroring needs at least two displays".into()
                });
            }
            // Source: built-in panel when usable, otherwise the primary external.
            let source = usable[0];
            let mut p = vec![Block::single(pm(source)).items.remove(0)];
            for m in &usable[1..] {
                let mut t = pm(m);
                t.mirror_of = Some(source.name.clone());
                t.position = "auto".into();
                p.push(t);
            }
            if clamshell {
                p.extend(disabled(&internals));
            }
            p
        }
        ProjectionMode::Custom(name) => return Err(format!("'{name}' is a profile, not a built-in mode")),
        ProjectionMode::Auto => return Err("'auto' must be resolved before planning".into()),
        _ => unreachable!(),
    };
    normalize_origin(&mut plan);
    append_ghost_cleanup(&mut plan, snap);
    Ok(plan)
}

/// Outputs Hyprland still lists as enabled after DRM says they're gone
/// (typical after a dock unplug) keep a phantom region on the canvas that
/// windows and the cursor can wander into. Disable them as part of the plan.
pub(crate) fn append_ghost_cleanup(plan: &mut Vec<PlannedMonitor>, snap: &Snapshot) {
    for g in &snap.ghosts {
        if snap.is_active(g) && !plan.iter().any(|p| &p.name == g) {
            log_info(&format!("cleaning up ghost output {g} (disconnected but still enabled)"));
            plan.push(PlannedMonitor::disabled(g));
        }
    }
}

/// Restore a saved profile literally (matched by hardware key, so ports
/// don't matter). Monitors the profile doesn't know are lit up to the right
/// rather than ignored — not lighting a screen someone just plugged in is
/// worse than an extra display.
pub(crate) fn build_profile_plan(profile: &DisplayProfile, snap: &Snapshot, cfg: &MonitorsConfig) -> Result<Vec<PlannedMonitor>, String> {
    let align = parse_align(&cfg.align);
    let key_to_name: HashMap<String, String> = snap.managed.iter().map(|m| (snap.key(&m.name), m.name.clone())).collect();
    let mut plan = Vec::new();

    for m in &snap.managed {
        let key = snap.key(&m.name);
        let saved = profile.monitors.get(&key).or_else(|| {
            // Profile saved before a twin panel was attached (no "#n" yet).
            if key.contains('#') {
                None
            } else {
                profile.monitors.get(base_key(&key))
            }
        });
        match saved {
            Some(s) if s.enabled => {
                let ov = Overrides {
                    mode: Some(s.mode.clone()),
                    scale: Some(s.scale),
                    transform: Some(s.transform),
                    position: Some(s.position.clone()),
                    vrr: s.vrr,
                };
                let mut p = plan_for(snap, cfg, m, &ov);
                p.mirror_of = s.mirror_of.as_ref().and_then(|k| key_to_name.get(k)).cloned();
                if p.mirror_of.is_some() {
                    p.position = "auto".into();
                }
                plan.push(p);
            }
            Some(_) => plan.push(PlannedMonitor::disabled(&m.name)),
            None => {
                log_info(&format!("{} ({key}) is not in profile '{}', extending it to the right", m.name, profile.name));
                plan.push(plan_for(snap, cfg, m, &Overrides::default()));
            }
        }
    }

    // Clamshell overrides whatever the profile says about the built-in panel.
    let has_external_on = plan.iter().any(|p| p.is_standalone() && !snap.is_internal(&p.name));
    if snap.lid_closed() && has_external_on {
        for p in plan.iter_mut().filter(|p| snap.is_internal(&p.name) && p.enabled) {
            log_info(&format!("lid closed: keeping {} off despite profile", p.name));
            *p = PlannedMonitor::disabled(&p.name);
        }
    }

    // A mirror whose source isn't a standalone enabled screen becomes standalone.
    let standalone: HashSet<String> = plan.iter().filter(|p| p.is_standalone()).map(|p| p.name.clone()).collect();
    for p in plan.iter_mut() {
        if let Some(src) = p.mirror_of.clone() {
            if !standalone.contains(&src) {
                p.mirror_of = None;
                p.position = "auto".into();
            }
        }
    }

    if !plan.iter().any(|p| p.is_standalone()) {
        // Every screen the profile knows is off now — light one up.
        let fallback = snap
            .managed
            .iter()
            .find(|m| !(snap.lid_closed() && snap.is_internal(&m.name)))
            .or_else(|| snap.managed.first())
            .ok_or("no monitors connected")?;
        log_warn(&format!("profile '{}' leaves no display enabled here; enabling {}", profile.name, fallback.name));
        let mut p = plan_for(snap, cfg, fallback, &Overrides::default());
        p.set_pos(0, 0);
        plan.retain(|q| q.name != fallback.name);
        plan.insert(0, p);
    }

    resolve_auto_positions(&mut plan);
    fix_layout(&mut plan, align);
    normalize_origin(&mut plan);
    append_ghost_cleanup(&mut plan, snap);
    Ok(plan)
}

/// While the session is locked, the only safe change is *adding* outputs so
/// the lock screen can attach a surface to them: preferred mode, automatic
/// position, no mirroring, never a disable, never a rearrangement.
pub(crate) fn lock_safe_plan(plan: Vec<PlannedMonitor>, snap: &Snapshot) -> Vec<PlannedMonitor> {
    plan.into_iter()
        .filter(|p| p.enabled && !snap.is_active(&p.name) && snap.monitor(&p.name).is_some())
        .map(|mut p| {
            p.mode = "preferred".into();
            p.position = "auto".into();
            p.mirror_of = None;
            p
        })
        .collect()
}

/// Projected set of enabled outputs and of standalone (non-mirror) outputs
/// after applying `plan` on top of the live state.
pub(crate) fn projected_state(plan: &[PlannedMonitor], snap: &Snapshot) -> (HashSet<String>, HashSet<String>) {
    let mut enabled: HashSet<String> = snap.active.clone();
    let mut standalone: HashSet<String> = snap.active.iter().filter(|n| snap.mirror_of(n).is_none()).cloned().collect();
    for p in plan {
        if p.enabled {
            enabled.insert(p.name.clone());
            if p.mirror_of.is_none() {
                standalone.insert(p.name.clone());
            } else {
                standalone.remove(&p.name);
            }
        } else {
            enabled.remove(&p.name);
            standalone.remove(&p.name);
        }
    }
    (enabled, standalone)
}

/// Validate and normalise a plan: dedupe, reject unsafe names, flatten
/// mirror chains, verify every mirror source will be a real screen.
pub(crate) fn validate_plan(plan: Vec<PlannedMonitor>, snap: &Snapshot, allow_unknown: bool) -> Result<Vec<PlannedMonitor>, String> {
    let mut out: Vec<PlannedMonitor> = Vec::new();
    for p in plan {
        if !valid_output_name(&p.name) {
            return Err(format!("refusing unsafe output name '{}'", p.name));
        }
        if !allow_unknown && !snap.all.iter().any(|m| m.name == p.name) {
            log_warn(&format!("dropping {} from plan: Hyprland doesn't know this output", p.name));
            continue;
        }
        out.retain(|q| q.name != p.name);
        out.push(p);
    }

    // Flatten A→B→C mirror chains to A→C; break self-mirrors and loops.
    let sources: HashMap<String, Option<String>> = out.iter().map(|p| (p.name.clone(), p.mirror_of.clone())).collect();
    for p in out.iter_mut() {
        let mut src = p.mirror_of.clone();
        let mut hops = 0;
        while let Some(s) = src.clone() {
            if s == p.name || hops > 8 {
                src = None;
                break;
            }
            match sources.get(&s).cloned().flatten().or_else(|| if sources.contains_key(&s) { None } else { snap.mirror_of(&s) }) {
                Some(next) => {
                    src = Some(next);
                    hops += 1;
                }
                None => break,
            }
        }
        if p.mirror_of != src {
            log_debug(&format!("{}: mirror source normalised {:?} → {src:?}", p.name, p.mirror_of));
            p.mirror_of = src;
        }
        if let Some(s) = &p.mirror_of {
            if !valid_output_name(s) {
                return Err(format!("refusing unsafe mirror source '{s}'"));
            }
        }
    }

    let (_, standalone) = projected_state(&out, snap);
    for p in &out {
        if let Some(src) = &p.mirror_of {
            if p.enabled && !standalone.contains(src) {
                return Err(format!("{} cannot mirror {src}: it would not be an active standalone display", p.name));
            }
        }
    }
    Ok(out)
}

/// Does the live state already match the plan? Then committing is a no-op.
pub(crate) fn plan_is_noop(plan: &[PlannedMonitor], snap: &Snapshot) -> bool {
    plan.iter().all(|p| {
        let Some(m) = snap.all.iter().find(|m| m.name == p.name) else {
            return !p.enabled;
        };
        if !p.enabled {
            return !snap.is_active(&p.name);
        }
        if !snap.is_active(&p.name) || m.width <= 0 {
            return false;
        }
        if p.mirror_of != snap.mirror_of(&p.name) {
            return false;
        }
        if p.mirror_of.is_some() {
            return true;
        }
        let mode_ok = match parse_mode(&p.mode) {
            Some(spec) => spec.w == m.width && spec.h == m.height && spec.hz.map(|r| (r - m.refresh_rate).abs() < 0.5).unwrap_or(true),
            None => target_resolution(m, &p.mode) == (m.width, m.height),
        };
        let pos_ok = p.position == "auto" || p.pos() == Some((m.x, m.y));
        let vrr_ok = p.vrr.map(|v| v == m.vrr).unwrap_or(true);
        mode_ok && pos_ok && (p.scale - m.scale).abs() < 0.01 && p.transform == m.transform && vrr_ok
    })
}


pub(crate) fn pick_primary(snap: &Snapshot, cfg: &MonitorsConfig) -> Option<String> {
    let standalone = snap.active_standalone();
    if let Some(p) = configured_primary(snap, cfg) {
        if standalone.iter().any(|m| m.name == p) {
            return Some(p);
        }
    }
    standalone
        .iter()
        .find(|m| m.x == 0 && m.y == 0)
        .or_else(|| standalone.iter().min_by_key(|m| (m.y, m.x)))
        .map(|m| m.name.clone())
}

pub(crate) fn wait_for_active(names: &[String], timeout: Duration) -> HashSet<String> {
    let start = Instant::now();
    loop {
        let active: HashSet<String> = query_active_monitors()
            .unwrap_or_default()
            .into_iter()
            .filter(|m| !m.disabled && m.width > 0)
            .map(|m| m.name)
            .collect();
        let up: HashSet<String> = names.iter().filter(|n| active.contains(*n)).cloned().collect();
        if up.len() == names.len() || start.elapsed() >= timeout {
            return up;
        }
        thread::sleep(Duration::from_millis(100));
    }
}

pub(crate) fn wait_for_convergence(cfg: &MonitorsConfig, plan: &[PlannedMonitor], timeout: Duration) -> Result<Snapshot, String> {
    let start = Instant::now();
    loop {
        let all = run_hyprctl_monitors(&["monitors", "all", "-j"])?;
        let active = query_active_monitors().ok();
        let mut snap = Snapshot::from_parts(all, active, read_drm_connectors(), read_lid_state(), is_locked(), cfg);
        snap.apply_mirror_hints(&load_runtime_state());
        let converged = plan.iter().all(|p| p.enabled == snap.is_active(&p.name) || snap.monitor(&p.name).is_none());
        if converged || start.elapsed() >= timeout {
            if !converged {
                log_warn("Hyprland state did not fully converge on the plan; reconciling against actual state");
            }
            return Ok(snap);
        }
        thread::sleep(Duration::from_millis(100));
    }
}

/// Apply a plan atomically:
///
/// 1. take the cross-process lock and capture a fresh snapshot;
/// 2. validate (names, mirror chains) and, if locked, reduce to lock-safe;
/// 3. **zero-monitor guard** on the projected result;
/// 4. skip entirely if the live state already matches;
/// 5. dispatch — enables before disables, standalone before mirrors. If the
///    plan both brings new outputs up *and* takes others down, it runs in
///    two batched phases and the new outputs must be verified live before
///    anything is disabled (the internal panel is never turned off until
///    an external is proven to be showing a picture);
/// 6. wait for Hyprland to converge, then reconcile focus and workspaces
///    against the *actual* state, not our bookkeeping.
pub(crate) fn commit_plan(plan: Vec<PlannedMonitor>, opts: &CommitOptions) -> Result<CommitReport, String> {
    let mut report = CommitReport::default();
    if plan.is_empty() {
        return Ok(report);
    }
    let _lock = DisplayLock::acquire(LOCK_TIMEOUT)?;
    let cfg = load_config();
    let before = Snapshot::capture(&cfg)?;
    let mut plan = validate_plan(plan, &before, opts.allow_unknown)?;

    if before.locked {
        let safe = lock_safe_plan(plan.clone(), &before);
        if safe.len() != plan.iter().filter(|p| p.enabled && !before.is_active(&p.name)).count() || safe.len() != plan.len() {
            report.deferred = true;
            mark_restart_pending(&format!("layout change while locked ({})", opts.reason), None);
            log_info("session is locked: only bringing up new outputs; the rest is deferred until unlock");
        }
        plan = safe;
        if plan.is_empty() {
            report.active = before.active.iter().cloned().collect();
            return Ok(report);
        }
    }

    let (_, standalone) = projected_state(&plan, &before);
    if standalone.is_empty() {
        return Err("refusing a change that would leave zero displays enabled".into());
    }

    if !opts.force && plan_is_noop(&plan, &before) {
        log_debug(&format!("plan already satisfied ({}), nothing to do", opts.reason));
        report.primary = pick_primary(&before, &cfg);
        report.active = before.active.iter().cloned().collect();
        return Ok(report);
    }

    let workspaces_before = query_workspaces();

    let mut enables: Vec<&PlannedMonitor> = plan.iter().filter(|p| p.enabled).collect();
    enables.sort_by_key(|p| p.mirror_of.is_some()); // sources before their mirrors
    let disables: Vec<&PlannedMonitor> = plan.iter().filter(|p| !p.enabled && before.is_active(&p.name)).collect();
    let newly_enabled: Vec<String> = enables.iter().filter(|p| !before.is_active(&p.name)).map(|p| p.name.clone()).collect();
    let disable_names: Vec<String> = disables.iter().map(|p| p.name.clone()).collect();

    log_info(&format!(
        "applying layout ({}): {}",
        if opts.reason.is_empty() { "change" } else { &opts.reason },
        plan.iter()
            .map(|p| if p.enabled {
                match &p.mirror_of {
                    Some(src) => format!("{}⇐{src}", p.name),
                    None => format!("{}@{}", p.name, p.position),
                }
            } else {
                format!("{}:off", p.name)
            })
            .collect::<Vec<_>>()
            .join(", ")
    ));
    write_txn_marker(&enables.iter().map(|p| p.name.clone()).collect::<Vec<_>>(), &disable_names);

    if !disables.is_empty() && !newly_enabled.is_empty() {
        // Phase 1: bring everything up.
        dispatch_monitors(&enables)?;
        let survivors: Vec<&String> = standalone.iter().filter(|n| before.is_active(n) && before.mirror_of(n).is_none()).collect();
        if survivors.is_empty() {
            let new_standalone: Vec<String> = newly_enabled.iter().filter(|n| standalone.contains(*n)).cloned().collect();
            let up = wait_for_active(&new_standalone, ENABLE_VERIFY_TIMEOUT);
            if up.is_empty() {
                return Err(format!(
                    "new display(s) {} did not come up; keeping the current screens on",
                    new_standalone.join(", ")
                ));
            }
            if up.len() < new_standalone.len() {
                log_warn("some new displays did not come up in time; proceeding with the ones that did");
            }
        }
        // The lock screen may have engaged while phase 1 ran.
        if is_locked() {
            log_warn("session locked mid-transaction: skipping disables, deferring the rest");
            report.deferred = true;
            mark_restart_pending("locked mid-transaction", None);
        } else {
            // Phase 2: take the old outputs down.
            dispatch_monitors(&disables)?;
        }
    } else {
        let ordered: Vec<&PlannedMonitor> = enables.iter().chain(disables.iter()).copied().collect();
        dispatch_monitors(&ordered)?;
    }
    write_txn_marker(&enables.iter().map(|p| p.name.clone()).collect::<Vec<_>>(), &disable_names);
    report.changed = true;

    let after = wait_for_convergence(&cfg, &plan, CONVERGE_TIMEOUT)?;
    if after.active_standalone().is_empty() {
        log_error("transaction left zero active displays — running emergency recovery");
        emergency_dispatch(&after, &cfg);
    }
    reconcile(&before, &after, &workspaces_before, &cfg, opts, &mut report);
    Ok(report)
}

/// Post-transition reconciliation against the real state.
pub(crate) fn reconcile(
    before: &Snapshot,
    after: &Snapshot,
    workspaces_before: &[HyprWorkspaceInfo],
    cfg: &MonitorsConfig,
    opts: &CommitOptions,
    report: &mut CommitReport,
) {
    let before_on: HashSet<String> = before.active_standalone().iter().map(|m| m.name.clone()).collect();
    let after_on: HashSet<String> = after.active_standalone().iter().map(|m| m.name.clone()).collect();
    report.just_enabled = after.active.difference(&before.active).cloned().collect();
    report.just_disabled = before.active.difference(&after.active).cloned().collect();
    report.active = after.active.iter().cloned().collect();
    let Some(primary) = pick_primary(after, cfg) else {
        return;
    };
    report.primary = Some(primary.clone());

    if before.locked || after.locked || is_locked() {
        log_info("session is locked: skipping workspace migration and monitor focus");
        return;
    }

    // Screens that stopped showing their own content (disabled or turned
    // into mirrors). Only their workspaces move; nothing that lived on a
    // surviving screen is touched.
    let left: HashSet<&String> = before_on.difference(&after_on).collect();
    let prev_ws_on_primary = after.monitor(&primary).map(|m| m.active_workspace.id).filter(|id| *id > 0);
    let mut moved_any = false;
    let mut homes = Vec::new();

    let now_ws = query_workspaces();
    for ws in &now_ws {
        let origin = workspaces_before
            .iter()
            .find(|w| w.dispatch_ref() == ws.dispatch_ref())
            .map(|w| w.monitor.clone())
            .unwrap_or_else(|| ws.monitor.clone());
        let evacuee = left.contains(&origin);
        let orphan = !ws.monitor.is_empty() && !after_on.contains(&ws.monitor);
        if !(evacuee || orphan) {
            continue;
        }
        if cfg.restore_workspaces && ws.id > 0 && evacuee {
            homes.push((ws.dispatch_ref(), before.key(&origin), origin.clone()));
        }
        if ws.monitor != primary {
            move_workspace(&ws.dispatch_ref(), &primary);
            moved_any = true;
        }
    }
    record_workspace_homes(&homes);

    if cfg.restore_workspaces {
        moved_any |= restore_workspace_homes(after, &after_on);
    }

    let focused_ok = after.managed.iter().any(|m| m.focused && after_on.contains(&m.name));
    if opts.focus_primary || !focused_ok || moved_any {
        focus_monitor(&primary);
        if moved_any {
            if let Some(id) = prev_ws_on_primary {
                if query_workspaces().iter().any(|w| w.id == id && w.monitor == primary) {
                    select_workspace(id);
                }
            }
        }
    }
}

/// Send evacuated workspaces back to their home monitor if it's on again.
pub(crate) fn restore_workspace_homes(snap: &Snapshot, standalone_on: &HashSet<String>) -> bool {
    if snap.locked || is_locked() {
        return false;
    }
    let mut homes = load_workspace_homes();
    if homes.is_empty() {
        return false;
    }
    let workspaces = query_workspaces();
    let mut moved = false;
    let mut dirty = false;
    for (ws_ref, home) in homes.clone() {
        let Some(target) = snap.by_key(&home.home).map(|m| m.name.clone()) else { continue };
        if !standalone_on.contains(&target) {
            continue;
        }
        match workspaces.iter().find(|w| w.dispatch_ref() == ws_ref) {
            None => {
                homes.remove(&ws_ref); // workspace was closed meanwhile
                dirty = true;
            }
            Some(ws) if ws.monitor == target => {
                homes.remove(&ws_ref);
                dirty = true;
            }
            Some(_) => {
                if move_workspace(&ws_ref, &target) {
                    log_info(&format!("workspace {ws_ref} returned home to {target}"));
                    moved = true;
                }
                homes.remove(&ws_ref);
                dirty = true;
            }
        }
    }
    if dirty {
        save_workspace_homes(&homes);
    }
    moved
}


// ============================================================
// EMERGENCY RECOVERY
// ============================================================

/// Best output to force on when nothing is showing: the built-in panel
/// (even with the lid shut — a dark but live session beats a headless one),
/// else any physically connected output, else anything Hyprland lists.
pub(crate) fn emergency_candidate(snap: Option<&Snapshot>, cfg: &MonitorsConfig) -> Option<String> {
    if let Some(s) = snap {
        if let Some(m) = s.internals().first() {
            return Some(m.name.clone());
        }
        if let Some(m) = s.managed.iter().find(|m| s.drm_status(&m.name) == DrmStatus::Connected) {
            return Some(m.name.clone());
        }
        if let Some(m) = s.managed.first() {
            return Some(m.name.clone());
        }
    }
    let drm = read_drm_connectors();
    let mut connected: Vec<&String> = drm.iter().filter(|(n, c)| c.status == DrmStatus::Connected && connector_kind(n).manageable()).map(|(n, _)| n).collect();
    connected.sort_by_key(|n| (!is_internal_with(cfg, n), natural_key(n)));
    connected.first().map(|n| n.to_string()).or_else(|| Some("eDP-1".to_string()))
}

pub(crate) fn emergency_dispatch(snap: &Snapshot, cfg: &MonitorsConfig) {
    if let Some(name) = emergency_candidate(Some(snap), cfg) {
        let mut p = snap.monitor(&name).map(|m| plan_for(snap, cfg, m, &Overrides::default())).unwrap_or_else(|| {
            let mut p = PlannedMonitor::disabled(&name);
            p.enabled = true;
            p.mode = "preferred".into();
            p.scale = 1.0;
            p
        });
        p.set_pos(0, 0);
        p.mirror_of = None;
        let _ = dispatch_monitors(&[&p]);
        // Rescue workspaces stranded on outputs that are now off.
        let stranded: Vec<&str> = snap.all.iter().filter(|m| m.name != name && !snap.is_active(&m.name)).map(|m| m.name.as_str()).collect();
        move_workspaces_from(&stranded, &name);
        focus_monitor(&name);
    }
}

pub fn emergency_fallback_laptop() -> Result<(), String> {
    let cfg = load_config();
    let snap = Snapshot::capture(&cfg).ok();
    let name = emergency_candidate(snap.as_ref(), &cfg).ok_or("no output available for emergency fallback")?;
    log_warn(&format!("emergency fallback: forcing {name} on at 0x0"));
    let mut p = match snap.as_ref().and_then(|s| s.monitor(&name).map(|m| (s, m))) {
        Some((s, m)) => plan_for(s, &cfg, m, &Overrides::default()),
        None => {
            let mut p = PlannedMonitor::disabled(&name);
            p.enabled = true;
            p.mode = "preferred".into();
            p
        }
    };
    p.set_pos(0, 0);
    let locked = is_locked();
    let opts = CommitOptions { force: true, allow_unknown: true, focus_primary: !locked, reason: "emergency".into() };
    if let Err(e) = commit_plan(vec![p.clone()], &opts) {
        // Even the guarded path failed (lock timeout, hyprctl hiccup):
        // dispatch raw — getting a picture back beats every other concern.
        log_error(&format!("guarded emergency commit failed ({e}); dispatching directly"));
        dispatch_monitors(&[&p])?;
    }
    if !locked {
        move_workspaces_to_monitor(&name);
        focus_monitor(&name);
    }
    Ok(())
}


// ============================================================
// MIRROR EXIT RECOVERY
//
// Leaving mirror mode on some Hyprland builds leaves former mirror targets
// in a broken buffer state: listed, but `width=0` or `disabled=true`, so
// layer-shell clients (wallpaper, bar) never get a configure for them.
// Cycling them (off → on) makes Hyprland re-advertise a fresh wl_output.
// ============================================================

pub(crate) fn mirror_targets_of(snap: &Snapshot) -> Vec<String> {
    let rt = load_runtime_state();
    let mut targets: Vec<String> = snap.managed.iter().filter(|m| snap.mirror_of(&m.name).is_some()).map(|m| m.name.clone()).collect();
    if matches!(rt.mode.as_deref(), Some("mirror") | Some("duplicate")) {
        for t in rt.mirror_targets {
            if snap.monitor(&t).is_some() && !targets.contains(&t) {
                targets.push(t);
            }
        }
    }
    targets
}

/// Clear mirrors and cycle any former target left without a buffer.
/// Returns `true` if anything was dispatched (callers re-capture then).
pub(crate) fn recover_from_mirror_if_needed(snap: &Snapshot, cfg: &MonitorsConfig) -> bool {
    if snap.locked {
        return false;
    }
    let targets = mirror_targets_of(snap);
    if targets.is_empty() {
        return false;
    }
    let Ok(_lock) = DisplayLock::acquire(LOCK_TIMEOUT) else {
        return false;
    };
    log_info(&format!("leaving mirror mode: releasing {}", targets.join(", ")));

    // 1. Un-mirror every target as a standalone screen at an automatic spot.
    let entries: Vec<PlannedMonitor> = targets
        .iter()
        .filter_map(|t| snap.monitor(t))
        .filter(|m| !(snap.lid_closed() && snap.is_internal(&m.name) && snap.externals().len() > 0))
        .map(|m| plan_for(snap, cfg, m, &Overrides::default()))
        .collect();
    let refs: Vec<&PlannedMonitor> = entries.iter().collect();
    write_txn_marker(&targets, &[]);
    let _ = dispatch_monitors(&refs);
    thread::sleep(Duration::from_millis(250));

    // 2. Re-advertise whatever is still broken.
    let broken: Vec<PlannedMonitor> = run_hyprctl_monitors(&["monitors", "all", "-j"])
        .unwrap_or_default()
        .into_iter()
        .filter(|m| targets.contains(&m.name) && (m.disabled || m.width <= 0))
        .filter_map(|m| entries.iter().find(|p| p.name == m.name).cloned())
        .collect();
    cycle_outputs(&broken);

    let mut rt = load_runtime_state();
    rt.mirror_source = None;
    rt.mirror_targets.clear();
    store_runtime_state(&mut rt);
    true
}

/// Off → on for each entry, so Hyprland creates a fresh wl_output global.
pub(crate) fn cycle_outputs(entries: &[PlannedMonitor]) {
    if entries.is_empty() {
        return;
    }
    let names: Vec<String> = entries.iter().map(|p| p.name.clone()).collect();
    log_info(&format!("re-advertising output(s) {}", names.join(", ")));
    write_txn_marker(&names, &names);
    let offs: Vec<PlannedMonitor> = entries.iter().map(|p| PlannedMonitor::disabled(&p.name)).collect();
    let _ = dispatch_monitors(&offs.iter().collect::<Vec<_>>());
    thread::sleep(Duration::from_millis(150));
    let _ = dispatch_monitors(&entries.iter().collect::<Vec<_>>());
    thread::sleep(Duration::from_millis(300));
}

/// After a commit that left mirror mode: anything planned "on" but reporting
/// no buffer gets one more re-advertisement cycle before wallpaper sync.
pub(crate) fn post_mirror_exit_check(plan: &[PlannedMonitor]) {
    let Ok(all) = run_hyprctl_monitors(&["monitors", "all", "-j"]) else { return };
    let broken: Vec<PlannedMonitor> = plan
        .iter()
        .filter(|p| p.enabled && p.mirror_of.is_none())
        .filter(|p| all.iter().any(|m| m.name == p.name && (m.disabled || m.width <= 0)))
        .cloned()
        .collect();
    if !broken.is_empty() {
        if let Ok(_lock) = DisplayLock::acquire(LOCK_TIMEOUT) {
            cycle_outputs(&broken);
        }
    }
}


// ============================================================
// CURRENT MODE DETECTION
// ============================================================

/// Name the current arrangement. Order of trust:
/// 1. no screen / mirror in effect (live facts);
/// 2. the mode or profile we recorded, if it still describes reality for
///    this exact hardware set;
/// 3. geometry: which screens are on and where the externals sit
///    relative to the built-in panel.
pub(crate) fn detect_mode(snap: &Snapshot, cfg: &MonitorsConfig, rt: &RuntimeState) -> String {
    let standalone = snap.active_standalone();
    if standalone.is_empty() {
        return "none".into();
    }
    if snap.active_managed().iter().any(|m| snap.mirror_of(&m.name).is_some()) {
        return "mirror".into();
    }
    let int_on: Vec<&HyprMonitor> = standalone.iter().copied().filter(|m| snap.is_internal(&m.name)).collect();
    let ext_on: Vec<&HyprMonitor> = standalone.iter().copied().filter(|m| !snap.is_internal(&m.name)).collect();
    let has_internal_hw = !snap.internals().is_empty();

    let geometric = geometric_mode(snap, &int_on, &ext_on, has_internal_hw);

    let same_setup = rt.fingerprint.as_deref().map(|f| f == snap.fingerprint).unwrap_or(true);
    if same_setup {
        if let Some(profile) = rt.active_profile.as_deref() {
            if cfg.profiles.iter().any(|p| p.name == profile && p.fingerprint == snap.fingerprint && !p.auto) {
                return profile.to_string();
            }
        }
        if let Some(saved) = rt.mode.as_deref() {
            let valid = match ProjectionMode::parse(saved) {
                Some(ProjectionMode::Mirror) => false, // no mirror live → stale
                Some(ProjectionMode::InternalOnly) => geometric == "internal-only",
                Some(ProjectionMode::ExternalOnly) => geometric == "external-only" || (!has_internal_hw && ext_on.len() > 1),
                Some(ProjectionMode::ExtendGrid(_)) => standalone.len() >= 2,
                Some(m) if m.is_extend() => geometric == m.as_str() || (snap.lid_closed() && ext_on.len() >= 2 && int_on.is_empty()),
                Some(ProjectionMode::Custom(name)) => cfg.profiles.iter().any(|p| p.name == name),
                _ => false,
            };
            if valid {
                return ProjectionMode::parse(saved).map(|m| m.as_str()).unwrap_or_else(|| saved.to_string());
            }
        }
    }
    geometric
}

pub(crate) fn geometric_mode(snap: &Snapshot, int_on: &[&HyprMonitor], ext_on: &[&HyprMonitor], has_internal_hw: bool) -> String {
    match (int_on.is_empty(), ext_on.is_empty()) {
        (false, true) => "internal-only".into(),
        (true, false) if has_internal_hw => "external-only".into(),
        (true, false) => {
            // Desktop: one screen of several = "PC screen only".
            if ext_on.len() == 1 {
                if snap.managed.len() > 1 { "internal-only".into() } else { "single".into() }
            } else {
                "extend".into()
            }
        }
        (false, false) => {
            let rect = |m: &HyprMonitor| {
                let (w, h) = logical_size((m.width, m.height), m.scale, m.transform);
                Rect { x: m.x, y: m.y, w, h }
            };
            let int_rects: Vec<Rect> = int_on.iter().map(|m| rect(m)).collect();
            let left = int_rects.iter().map(|r| r.x).min().unwrap_or(0);
            let right = int_rects.iter().map(|r| r.right()).max().unwrap_or(0);
            let top = int_rects.iter().map(|r| r.y).min().unwrap_or(0);
            let bottom = int_rects.iter().map(|r| r.bottom()).max().unwrap_or(0);
            let t = GEOMETRY_TOLERANCE;
            let exts: Vec<Rect> = ext_on.iter().map(|m| rect(m)).collect();
            if exts.iter().all(|r| r.x >= right - t) {
                "extend".into()
            } else if exts.iter().all(|r| r.right() <= left + t) {
                "extend-left".into()
            } else if exts.iter().all(|r| r.y >= bottom - t) {
                "extend-down".into()
            } else if exts.iter().all(|r| r.bottom() <= top + t) {
                "extend-up".into()
            } else {
                "custom".into()
            }
        }
        (true, true) => "none".into(),
    }
}

/// Legacy public API.
pub fn detect_current_mode(all: &[HyprMonitor], active: &[HyprMonitor]) -> String {
    let cfg = load_config();
    let rt = load_runtime_state();
    let mut snap = Snapshot::from_parts(all.to_vec(), Some(active.to_vec()), read_drm_connectors(), read_lid_state(), is_locked(), &cfg);
    snap.apply_mirror_hints(&rt);
    detect_mode(&snap, &cfg, &rt)
}

/// Record what is on screen now so `info`, the Dynamic Island and the next
/// auto-resolve agree on it.

// ============================================================
// PROJECTION MODES — public entry point
// ============================================================


pub(crate) fn find_profile_by_name<'a>(cfg: &'a MonitorsConfig, name: &str) -> Option<&'a DisplayProfile> {
    cfg.profiles
        .iter()
        .find(|p| p.name == name)
        .or_else(|| cfg.profiles.iter().find(|p| p.name.eq_ignore_ascii_case(name)))
}

/// Apply a built-in projection mode or a saved profile by name.
pub fn apply_projection(target_mode: &str) -> Result<(), String> {
    apply_projection_ex(target_mode, true).map(|_| ())
}

/// `user_initiated` controls whether the result is remembered as this
/// hardware set's preferred layout.
pub fn apply_projection_ex(target_mode: &str, user_initiated: bool) -> Result<ApplyOutcome, String> {
    let mode = ProjectionMode::parse(target_mode).ok_or_else(|| format!("'{target_mode}' is not a usable projection mode"))?;
    if mode == ProjectionMode::Auto {
        return auto_resolve(Trigger::Manual, None).map(|r| r.outcome);
    }
    let cfg = load_config();
    let mut snap = Snapshot::capture(&cfg)?;
    if snap.managed.is_empty() {
        let _ = emergency_fallback_laptop();
        return Err("no displays detected".into());
    }
    if cfg.lid_close_policy.eq_ignore_ascii_case("ignore") && snap.lid == LidState::Closed {
        snap.lid = LidState::Open;
    }

    // Resolve profile names up front so typos fail fast and helpfully.
    let profile = match &mode {
        ProjectionMode::Custom(name) => Some(find_profile_by_name(&cfg, name).cloned().ok_or_else(|| {
            let names: Vec<&str> = cfg.profiles.iter().filter(|p| !p.auto).map(|p| p.name.as_str()).collect();
            format!(
                "unknown mode or profile '{name}' (modes: internal-only, external-only, extend, extend-left, extend-up, extend-down, extend-grid, mirror, auto{}{})",
                if names.is_empty() { "" } else { "; profiles: " },
                names.join(", ")
            )
        })?),
        _ => None,
    };
    let label = profile.as_ref().map(|p| p.name.clone()).unwrap_or_else(|| mode.as_str());

    if snap.locked {
        // Remember the request, but only light up new outputs now.
        mark_restart_pending(&format!("mode '{label}' requested while locked"), Some(&label));
        let plan = match &profile {
            Some(p) => build_profile_plan(p, &snap, &cfg),
            None => build_projection_plan(&mode, &snap, &cfg),
        };
        if let Ok(plan) = plan {
            let opts = CommitOptions { reason: format!("lock-safe part of '{label}'"), ..Default::default() };
            let _ = commit_plan(plan, &opts);
        }
        return Ok(ApplyOutcome::Deferred);
    }

    let was_mirroring = !mirror_targets_of(&snap).is_empty();
    let into_mirror = mode == ProjectionMode::Mirror || profile.as_ref().map(|p| p.monitors.values().any(|m| m.mirror_of.is_some())).unwrap_or(false);
    if was_mirroring && !into_mirror && recover_from_mirror_if_needed(&snap, &cfg) {
        snap = Snapshot::capture(&cfg)?;
        if cfg.lid_close_policy.eq_ignore_ascii_case("ignore") && snap.lid == LidState::Closed {
            snap.lid = LidState::Open;
        }
    }

    let plan = match &profile {
        Some(p) => build_profile_plan(p, &snap, &cfg)?,
        None => build_projection_plan(&mode, &snap, &cfg)?,
    };

    // Mirror bookkeeping goes down *before* the commit so convergence and
    // reconciliation already understand the new mirror relationships.
    let prev_rt = load_runtime_state();
    if into_mirror {
        record_runtime_state(Some(label.clone()), profile.as_ref().map(|p| p.name.clone()), Some(&plan), Some(&snap));
    }
    let opts = CommitOptions { focus_primary: true, reason: format!("mode {label}"), ..Default::default() };
    let report = match commit_plan(plan.clone(), &opts) {
        Ok(r) => r,
        Err(e) => {
            if into_mirror {
                let mut restore = prev_rt;
                store_runtime_state(&mut restore);
            }
            return Err(e);
        }
    };
    if report.deferred {
        mark_restart_pending(&format!("mode '{label}' interrupted by lock"), Some(&label));
    }
    if was_mirroring && !into_mirror {
        post_mirror_exit_check(&plan);
    }

    let after = Snapshot::capture(&cfg).ok();
    let mode_label = match &profile {
        Some(p) => p.name.clone(),
        None => mode.as_str(),
    };
    record_runtime_state(Some(mode_label), profile.as_ref().map(|p| p.name.clone()), Some(&plan), after.as_ref());

    if let Some(p) = &profile {
        touch_profile(&p.name);
    } else if user_initiated && cfg.remember_layouts && !report.deferred {
        if let Err(e) = remember_current_layout(&mode.as_str()) {
            log_debug(&format!("could not remember layout: {e}"));
        }
    }

    if report.changed || was_mirroring {
        schedule_wallpaper_sync(was_mirroring && !into_mirror);
    }
    Ok(if report.deferred {
        ApplyOutcome::Deferred
    } else if report.changed {
        ApplyOutcome::Applied
    } else {
        ApplyOutcome::NoChange
    })
}


// ============================================================
// AUTO-RESOLVE — the policy engine
// ============================================================


pub(crate) fn default_mode_for(snap: &Snapshot, cfg: &MonitorsConfig, trigger: Trigger) -> ProjectionMode {
    let n_int = snap.internals().len();
    let n_ext = snap.externals().len();
    let parse = |s: &str, fallback: ProjectionMode| match ProjectionMode::parse(s) {
        Some(ProjectionMode::Auto) | None => fallback,
        Some(ProjectionMode::Custom(name)) if find_profile_by_name(cfg, &name).is_none() => {
            log_warn(&format!("policy '{name}' is neither a mode nor a profile; using extend"));
            ProjectionMode::ExtendRight
        }
        Some(m) => m,
    };
    if n_ext == 0 {
        return if n_int >= 2 { ProjectionMode::ExtendRight } else { ProjectionMode::InternalOnly };
    }
    if n_int == 0 {
        // Desktop: every screen is "external". Only extend-ish policies and
        // mirror make sense; external-only there would mean "all on" anyway.
        if n_ext == 1 {
            return ProjectionMode::InternalOnly;
        }
        return match parse(&cfg.default_policy_multi, ProjectionMode::ExtendRight) {
            ProjectionMode::ExternalOnly | ProjectionMode::InternalOnly => ProjectionMode::ExtendRight,
            m => m,
        };
    }
    if snap.lid_closed() {
        return match parse(&cfg.lid_close_policy, ProjectionMode::ExternalOnly) {
            // Internal is unusable with the lid shut; every other mode is
            // planned in clamshell form automatically.
            ProjectionMode::InternalOnly => ProjectionMode::ExternalOnly,
            m => m,
        };
    }
    if trigger == Trigger::LidOpened {
        return parse(&cfg.lid_open_policy, ProjectionMode::ExtendRight);
    }
    if n_ext == 1 {
        parse(&cfg.default_policy_dual, ProjectionMode::ExternalOnly)
    } else {
        parse(&cfg.default_policy_multi, ProjectionMode::ExtendRight)
    }
}

/// Legacy public API.
pub fn auto_resolve_setup() -> Result<String, String> {
    auto_resolve(Trigger::Manual, None).map(|r| r.decision)
}

/// Decide and apply the right layout for what is connected right now.
///
/// Order: zero-display guard → lock-safe path → explicitly requested mode
/// (e.g. chosen while locked) → remembered profile → the last mode for this
/// same hardware (restorative triggers) → configured defaults → extend →
/// internal-only.
pub fn auto_resolve(trigger: Trigger, requested: Option<String>) -> Result<ResolveResult, String> {
    let cfg = load_config();
    let wait = match trigger {
        Trigger::Startup | Trigger::Resume => Duration::from_secs(3),
        _ => Duration::from_millis(800),
    };
    let mut snap = Snapshot::capture_settled(&cfg, wait)?;
    let fingerprint = snap.fingerprint.clone();
    let mut result = ResolveResult {
        decision: String::new(),
        outcome: ApplyOutcome::NoChange,
        matched_profile: None,
        report: CommitReport::default(),
        fingerprint: fingerprint.clone(),
    };

    if snap.managed.is_empty() {
        if count_physical_drm_connected() > 0 || snap.all.iter().any(|m| m.name.eq_ignore_ascii_case("FALLBACK")) {
            log_error("no usable display is active; attempting emergency recovery");
            emergency_fallback_laptop()?;
            result.decision = "emergency".into();
            result.outcome = ApplyOutcome::Applied;
            return Ok(result);
        }
        result.decision = "no displays".into();
        return Ok(result);
    }

    if cfg.lid_close_policy.eq_ignore_ascii_case("ignore") && snap.lid == LidState::Closed {
        if trigger == Trigger::LidClosed {
            result.decision = "lid close ignored by policy".into();
            return Ok(result);
        }
        snap.lid = LidState::Open;
    }

    // ---- Locked: only add outputs, defer the rest. ------------------------
    if snap.locked {
        let mut plan: Vec<PlannedMonitor> = snap
            .managed
            .iter()
            .filter(|m| !snap.is_active(&m.name))
            .filter(|m| !(snap.lid_closed() && snap.is_internal(&m.name) && !snap.externals().is_empty()))
            .map(|m| plan_for(&snap, &cfg, m, &Overrides::default()))
            .collect();
        if snap.active_standalone().is_empty() && plan.is_empty() {
            // Nothing is lit and nothing new to light: force the best candidate.
            if let Some(m) = emergency_candidate(Some(&snap), &cfg).and_then(|n| snap.monitor(&n).cloned()) {
                plan.push(plan_for(&snap, &cfg, &m, &Overrides::default()));
            }
        }
        mark_restart_pending(&format!("{} while locked", trigger.label()), requested.as_deref());
        if !plan.is_empty() {
            result.report = commit_plan(plan, &CommitOptions { reason: format!("{} (locked)", trigger.label()), ..Default::default() })?;
        }
        result.decision = "deferred until unlock".into();
        result.outcome = ApplyOutcome::Deferred;
        return Ok(result);
    }


    // ---- An explicit request wins. ----------------------------------------
    if let Some(req) = requested.filter(|r| !r.trim().is_empty() && ProjectionMode::parse(r) != Some(ProjectionMode::Auto)) {
        match apply_projection_ex(&req, true) {
            Ok(outcome) => {
                result.decision = format!("requested: {req}");
                result.outcome = outcome;
                return Ok(result);
            }
            Err(e) => log_warn(&format!("requested mode '{req}' is not applicable any more ({e}); resolving automatically")),
        }
    }

    // ---- Remembered profile for this exact hardware. ----------------------
    if cfg.remember_layouts {
        if let Some(profile) = find_profile_for(&cfg, &fingerprint, snap.lid).cloned() {
            let internals_off = snap.internals().iter().all(|m| {
                let key = snap.key(&m.name);
                profile.monitors.get(&key).or_else(|| profile.monitors.get(base_key(&key))).map(|s| !s.enabled).unwrap_or(false)
            });
            // Opening the lid is a request for the built-in panel, unless the
            // user explicitly saved an "open lid, internal off" layout.
            let skip = trigger == Trigger::LidOpened && internals_off && !snap.internals().is_empty() && profile.lid.as_deref() != Some("open");
            if !skip {
                match apply_profile_internal(&profile, &format!("{}: profile {}", trigger.label(), profile.name), !trigger.is_restorative()) {
                    Ok(report) => {
                        result.outcome = if report.deferred { ApplyOutcome::Deferred } else if report.changed { ApplyOutcome::Applied } else { ApplyOutcome::NoChange };
                        result.decision = format!("profile '{}'", profile.name);
                        result.matched_profile = Some(profile.name.clone());
                        result.report = report;
                        return Ok(result);
                    }
                    Err(e) => log_warn(&format!("profile '{}' could not be applied ({e}); using defaults", profile.name)),
                }
            } else {
                log_info("lid opened: the remembered layout keeps the built-in panel off; using the lid-open policy instead");
            }
        }
    }

    // ---- Same hardware as last time: keep the last mode. ------------------
    let rt = load_runtime_state();
    let mut candidates: Vec<ProjectionMode> = Vec::new();
    if trigger.is_restorative() && rt.fingerprint.as_deref() == Some(fingerprint.as_str()) {
        let lid_same = rt.lid_closed.map(|c| c == snap.lid_closed()).unwrap_or(true);
        if lid_same {
            if let Some(m) = rt.mode.as_deref().and_then(ProjectionMode::parse) {
                if !matches!(m, ProjectionMode::Auto) && !matches!(&m, ProjectionMode::Custom(n) if find_profile_by_name(&cfg, n).is_none()) {
                    candidates.push(m);
                }
            }
        }
    }
    candidates.push(default_mode_for(&snap, &cfg, trigger));
    candidates.push(ProjectionMode::ExtendRight);
    candidates.push(ProjectionMode::InternalOnly);
    candidates.dedup();

    let mut last_err = String::new();
    for mode in candidates {
        let plan = match &mode {
            ProjectionMode::Custom(name) => match find_profile_by_name(&cfg, name) {
                Some(p) => build_profile_plan(p, &snap, &cfg),
                None => continue,
            },
            m => build_projection_plan(m, &snap, &cfg),
        };
        let plan = match plan {
            Ok(p) => p,
            Err(e) => {
                log_debug(&format!("{} not applicable: {e}", mode.as_str()));
                last_err = e;
                continue;
            }
        };
        let was_mirroring = !mirror_targets_of(&snap).is_empty();
        if was_mirroring && mode != ProjectionMode::Mirror && recover_from_mirror_if_needed(&snap, &cfg) {
            snap = Snapshot::capture(&cfg)?;
        }
        if mode == ProjectionMode::Mirror {
            record_runtime_state(Some(mode.as_str()), None, Some(&plan), Some(&snap));
        }
        let opts = CommitOptions { focus_primary: !trigger.is_restorative(), reason: format!("{}: {}", trigger.label(), mode.as_str()), ..Default::default() };
        match commit_plan(plan.clone(), &opts) {
            Ok(report) => {
                if was_mirroring && mode != ProjectionMode::Mirror {
                    post_mirror_exit_check(&plan);
                }
                let after = Snapshot::capture(&cfg).ok();
                let label = match &mode {
                    ProjectionMode::Custom(n) => find_profile_by_name(&cfg, n).map(|p| p.name.clone()).unwrap_or_else(|| n.clone()),
                    m => m.as_str(),
                };
                let profile = matches!(mode, ProjectionMode::Custom(_)).then(|| label.clone());
                record_runtime_state(Some(label.clone()), profile, Some(&plan), after.as_ref());
                if report.changed || was_mirroring || trigger == Trigger::Resume {
                    schedule_wallpaper_sync(was_mirroring && mode != ProjectionMode::Mirror);
                }
                result.outcome = if report.deferred { ApplyOutcome::Deferred } else if report.changed { ApplyOutcome::Applied } else { ApplyOutcome::NoChange };
                result.decision = format!("{}: {label}", if trigger.is_restorative() && rt.mode.as_deref() == Some(label.as_str()) { "kept" } else { "default" });
                result.report = report;
                return Ok(result);
            }
            Err(e) => {
                log_warn(&format!("{} failed: {e}", mode.as_str()));
                last_err = e;
            }
        }
    }
    if snap.active_standalone().is_empty() {
        emergency_fallback_laptop()?;
        result.decision = "emergency".into();
        result.outcome = ApplyOutcome::Applied;
        return Ok(result);
    }
    Err(format!("could not resolve a layout: {last_err}"))
}


// ============================================================
// SINGLE-MONITOR OPERATIONS
//
// Each operation starts from the *live* layout expressed as a plan, edits
// it, repairs geometry (no overlaps, no unreachable islands) and commits it
// through the same guarded path as everything else.
// ============================================================

/// Resolve a user-supplied display reference: connector name (any case),
/// `internal`/`external`/`primary`/`focused`, numeric Hyprland id, hardware
/// key, or a unique substring of description / make / model.
pub(crate) fn resolve_target(snap: &Snapshot, cfg: &MonitorsConfig, query: &str) -> Result<String, String> {
    let q = query.trim();
    if q.is_empty() {
        return Err("no display given".into());
    }
    if let Some(m) = snap.managed.iter().find(|m| m.name == q).or_else(|| snap.managed.iter().find(|m| m.name.eq_ignore_ascii_case(q))) {
        return Ok(m.name.clone());
    }
    let lower = q.to_ascii_lowercase();
    let pick = |v: Vec<&HyprMonitor>, what: &str| -> Result<String, String> {
        v.first().map(|m| m.name.clone()).ok_or_else(|| format!("no {what} display connected"))
    };
    match lower.as_str() {
        "internal" | "builtin" | "built-in" | "laptop" => return pick(snap.internals(), "built-in"),
        "external" => return pick(order_monitors(snap, cfg, snap.externals()), "external"),
        "primary" => return pick_primary(snap, cfg).ok_or_else(|| "no primary display".to_string()),
        "focused" | "current" => {
            return snap
                .managed
                .iter()
                .find(|m| m.focused)
                .map(|m| m.name.clone())
                .or_else(|| pick_primary(snap, cfg))
                .ok_or_else(|| "no focused display".to_string())
        }
        _ => {}
    }
    if let Ok(id) = q.parse::<i64>() {
        if let Some(m) = snap.managed.iter().find(|m| m.id == id) {
            return Ok(m.name.clone());
        }
    }
    if let Some(m) = snap.by_key(q) {
        return Ok(m.name.clone());
    }
    let matches: Vec<&HyprMonitor> = snap
        .managed
        .iter()
        .filter(|m| {
            let key = snap.key(&m.name).to_ascii_lowercase();
            key.starts_with(&lower)
                || m.description.to_ascii_lowercase().contains(&lower)
                || format!("{} {}", m.make, m.model).to_ascii_lowercase().contains(&lower)
        })
        .collect();
    match matches.len() {
        1 => Ok(matches[0].name.clone()),
        0 => {
            if snap.unmanaged.iter().any(|n| n.eq_ignore_ascii_case(q)) {
                Err(format!("{q} is not managed by NEXA (ignored, headless or placeholder output)"))
            } else if snap.ghosts.iter().any(|n| n.eq_ignore_ascii_case(q)) {
                Err(format!("{q} is not physically connected"))
            } else {
                Err(format!(
                    "no display matches '{q}' (connected: {})",
                    snap.managed.iter().map(|m| m.name.as_str()).collect::<Vec<_>>().join(", ")
                ))
            }
        }
        _ => Err(format!("'{q}' is ambiguous: {}", matches.iter().map(|m| m.name.as_str()).collect::<Vec<_>>().join(", "))),
    }
}

/// The live layout as a plan (what `commit_plan` would consider a no-op).
pub(crate) fn current_layout_plan(snap: &Snapshot) -> Vec<PlannedMonitor> {
    snap.managed
        .iter()
        .map(|m| {
            if !snap.is_active(&m.name) {
                return PlannedMonitor::disabled(&m.name);
            }
            let mirror = snap.mirror_of(&m.name);
            let px = if m.width > 0 && m.height > 0 { (m.width, m.height) } else { target_resolution(m, "preferred") };
            PlannedMonitor {
                name: m.name.clone(),
                enabled: true,
                mode: m.current_mode_string().unwrap_or_else(|| "preferred".into()),
                position: if mirror.is_some() { "auto".into() } else { format!("{}x{}", m.x, m.y) },
                scale: if m.scale > 0.0 { m.scale } else { 1.0 },
                transform: m.transform,
                mirror_of: mirror,
                vrr: None,
                pixel_size: px,
            }
        })
        .collect()
}

/// Edit the live layout with `f`, repair geometry, commit, and refresh the
/// bookkeeping (mode label, auto profile, wallpaper).
pub(crate) fn modify_layout<F>(reason: &str, allow_while_locked: bool, f: F) -> Result<CommitReport, String>
where
    F: FnOnce(&Snapshot, &MonitorsConfig, &mut Vec<PlannedMonitor>) -> Result<(), String>,
{
    let cfg = load_config();
    let snap = Snapshot::capture(&cfg)?;
    if snap.locked && !allow_while_locked {
        // Not queued: replaying an old manual tweak after unlock would
        // surprise the user more than asking them to repeat it.
        return Err(format!("the session is locked; '{reason}' was not applied (try again after unlocking)"));
    }
    let mut plan = current_layout_plan(&snap);
    let before = plan.clone();
    f(&snap, &cfg, &mut plan)?;

    // Anything that stopped mirroring gets an automatic position.
    for p in plan.iter_mut() {
        if p.enabled && p.mirror_of.is_none() && p.pos().is_none() {
            p.position = "auto".into();
        }
    }
    resolve_auto_positions(&mut plan);
    fix_layout(&mut plan, parse_align(&cfg.align));
    normalize_origin(&mut plan);
    append_ghost_cleanup(&mut plan, &snap);

    // Only send what actually changed (keeps untouched screens from blinking).
    let changed: Vec<PlannedMonitor> = plan.iter().filter(|p| !before.contains(p)).cloned().collect();
    if changed.is_empty() {
        return Ok(CommitReport { active: snap.active.iter().cloned().collect(), ..Default::default() });
    }
    let was_mirroring = !mirror_targets_of(&snap).is_empty();
    let mirroring_after = plan.iter().any(|p| p.enabled && p.mirror_of.is_some());
    if mirroring_after {
        record_runtime_state(None, None, Some(&plan), Some(&snap));
    }
    let report = commit_plan(changed, &CommitOptions { reason: reason.to_string(), ..Default::default() })?;
    if was_mirroring && !mirroring_after {
        post_mirror_exit_check(&plan);
    }
    if let Ok(after) = Snapshot::capture(&cfg) {
        let mut rt = load_runtime_state();
        rt.active_profile = None;
        rt.mode = Some(detect_mode(&after, &cfg, &RuntimeState { mode: None, active_profile: None, fingerprint: None, ..rt.clone() }));
        if !mirroring_after {
            rt.mirror_source = None;
            rt.mirror_targets.clear();
        }
        rt.fingerprint = Some(after.fingerprint.clone());
        store_runtime_state(&mut rt);
        if cfg.remember_layouts && !after.locked && !report.deferred {
            let _ = save_current_as_profile(None);
        }
    }
    if report.changed {
        schedule_wallpaper_sync(was_mirroring && !mirroring_after);
    }
    Ok(report)
}

/// Relative placement keywords for `enable`/`position`.

pub fn enable_monitor_ex(target: &str, opts: EnableOptions) -> Result<CommitReport, String> {
    let target = target.to_string();
    let explicit = opts.mode.is_some() || opts.scale.is_some() || opts.transform.is_some();
    // (hardware key, applied entry) for remembering explicit choices.
    let mut applied: Option<(String, PlannedMonitor)> = None;
    let report = modify_layout(&format!("enable {target}"), true, |snap, cfg, plan| {
        let name = resolve_target(snap, cfg, &target)?;
        if snap.lid_closed() && snap.is_internal(&name) && !snap.externals().is_empty() {
            return Err(format!("{name} is the built-in panel and the lid is closed"));
        }
        let m = snap.monitor(&name).ok_or_else(|| format!("{name} is not connected"))?;
        let already_live = snap.is_active(&name) && snap.mirror_of(&name).is_none();
        let ov = Overrides {
            mode: opts.mode.clone().filter(|s| !s.is_empty()).or_else(|| already_live.then(|| m.current_mode_string()).flatten()),
            scale: opts.scale.filter(|s| *s > 0.0).or_else(|| already_live.then_some(m.scale)),
            transform: opts.transform,
            position: None,
            vrr: None,
        };
        let mut entry = plan_for(snap, cfg, m, &ov);
        let pos = opts.position.clone().unwrap_or_else(|| if already_live { format!("{}x{}", m.x, m.y) } else { "auto".into() });
        entry.position = "auto".into();
        // Anything mirroring this output keeps doing so; mirrors of *other*
        // outputs are left alone.
        plan.retain(|p| p.name != name);
        plan.push(entry);
        let (how, anchor) = resolve_position_spec(snap, cfg, &pos, None)?;
        apply_position_spec(plan, &name, &how, anchor.as_deref())?;
        if snap.locked {
            log_info("session locked: enabling at an automatic position, full layout deferred");
        }
        if let Some(e) = plan.iter().find(|p| p.name == name) {
            applied = Some((snap.key(&name), e.clone()));
        }
        Ok(())
    })?;
    // Explicit mode/scale/rotation given on `enable` are the user's choice
    // for this monitor from now on (every mode and profile respects them).
    if explicit && !report.deferred {
        if let Some((key, e)) = applied {
            update_pref(&key, |pref| {
                if opts.mode.is_some() {
                    pref.mode = Some(e.mode.clone()).filter(|m| m != "preferred");
                }
                if opts.scale.is_some() {
                    pref.scale = Some(e.scale);
                }
                if opts.transform.is_some() {
                    pref.transform = Some(e.transform);
                }
            });
        }
    }
    Ok(report)
}

/// Legacy public API.
pub fn enable_monitor(name: &str, mode: &str, pos: &str, scale: f64) -> Result<(), String> {
    enable_monitor_ex(
        name,
        EnableOptions {
            mode: Some(mode.to_string()).filter(|m| !m.is_empty()),
            position: Some(pos.to_string()).filter(|p| !p.is_empty()),
            scale: (scale > 0.0).then_some(scale),
            transform: None,
        },
    )
    .map(|_| ())
}

/// Turn a display off. Refuses to turn off the last screen; mirrors of it
/// are re-pointed (or promoted to a standalone screen) first; gaps left
/// behind are closed.
pub fn disable_monitor_ex(target: &str) -> Result<CommitReport, String> {
    let target = target.to_string();
    modify_layout(&format!("disable {target}"), false, move |snap, cfg, plan| {
        let name = resolve_target(snap, cfg, &target)?;
        if !snap.is_active(&name) {
            return Ok(()); // already off: idempotent
        }
        let others: Vec<String> = plan.iter().filter(|p| p.is_standalone() && p.name != name).map(|p| p.name.clone()).collect();
        let mirrors: Vec<String> = plan.iter().filter(|p| p.enabled && p.mirror_of.as_deref() == Some(name.as_str())).map(|p| p.name.clone()).collect();
        if others.is_empty() && mirrors.is_empty() {
            return Err(format!("refusing to disable {name}: it is the only active display"));
        }
        match others.first() {
            Some(new_src) => {
                for p in plan.iter_mut().filter(|p| mirrors.contains(&p.name)) {
                    p.mirror_of = Some(new_src.clone());
                }
            }
            None => {
                // Promote the first mirror to a real screen; the rest mirror it.
                let promoted = mirrors[0].clone();
                for p in plan.iter_mut() {
                    if p.name == promoted {
                        p.mirror_of = None;
                        p.set_pos(0, 0);
                    } else if mirrors.contains(&p.name) {
                        p.mirror_of = Some(promoted.clone());
                    }
                }
            }
        }
        if let Some(p) = plan.iter_mut().find(|p| p.name == name) {
            *p = PlannedMonitor::disabled(&name);
        }
        close_gaps(plan, parse_align(&cfg.align));
        Ok(())
    })
}

/// Legacy public API.
pub fn disable_monitor(name: &str) -> Result<(), String> {
    disable_monitor_ex(name).map(|_| ())
}


pub fn toggle_monitor(target: &str) -> Result<CommitReport, String> {
    let cfg = load_config();
    let snap = Snapshot::capture(&cfg)?;
    let name = resolve_target(&snap, &cfg, target)?;
    if snap.is_active(&name) && snap.mirror_of(&name).is_none() {
        disable_monitor_ex(&name)
    } else {
        enable_monitor_ex(&name, EnableOptions::default())
    }
}

pub fn focus_display(target: &str) -> Result<String, String> {
    let cfg = load_config();
    let snap = Snapshot::capture(&cfg)?;
    let name = resolve_target(&snap, &cfg, target)?;
    if !snap.is_active(&name) {
        return Err(format!("{name} is not enabled"));
    }
    let focus_name = snap.mirror_of(&name).unwrap_or_else(|| name.clone());
    focus_monitor(&focus_name);
    Ok(focus_name)
}

pub fn rotate_monitor(target: &str, rotation: &str) -> Result<CommitReport, String> {
    let transform = parse_transform(rotation).ok_or_else(|| format!("unknown rotation '{rotation}' (normal, 90, 180, 270, flipped…)"))?;
    let target = target.to_string();
    let mut key = String::new();
    let report = modify_layout(&format!("rotate {target}"), false, |snap, cfg, plan| {
        let name = resolve_target(snap, cfg, &target)?;
        key = snap.key(&name);
        let p = plan.iter_mut().find(|p| p.name == name && p.enabled).ok_or_else(|| format!("{name} is not enabled"))?;
        if p.mirror_of.is_some() {
            return Err(format!("{name} is mirroring another display; unmirror it first"));
        }
        p.transform = transform;
        p.scale = sanitize_scale(p.pixel_size, p.scale);
        Ok(())
    })?;
    update_pref(&key, |pref| pref.transform = Some(transform));
    Ok(report)
}

pub fn set_monitor_scale(target: &str, scale: &str) -> Result<CommitReport, String> {
    let requested: f64 = scale.trim().trim_end_matches('x').parse().map_err(|_| format!("invalid scale '{scale}'"))?;
    if !(0.25..=10.0).contains(&requested) {
        return Err("scale must be between 0.25 and 10".into());
    }
    let target = target.to_string();
    let mut key = String::new();
    let mut applied = requested;
    let report = modify_layout(&format!("scale {target}"), false, |snap, cfg, plan| {
        let name = resolve_target(snap, cfg, &target)?;
        key = snap.key(&name);
        let p = plan.iter_mut().find(|p| p.name == name && p.enabled).ok_or_else(|| format!("{name} is not enabled"))?;
        p.scale = sanitize_scale(p.pixel_size, requested);
        applied = p.scale;
        Ok(())
    })?;
    update_pref(&key, |pref| pref.scale = Some(applied));
    Ok(report)
}

pub fn set_monitor_resolution(target: &str, mode: &str) -> Result<CommitReport, String> {
    let target = target.to_string();
    let mode_req = mode.trim().to_string();
    let mut key = String::new();
    let mut chosen = String::new();
    let report = modify_layout(&format!("resolution {target}"), false, |snap, cfg, plan| {
        let name = resolve_target(snap, cfg, &target)?;
        key = snap.key(&name);
        let m = snap.monitor(&name).ok_or_else(|| format!("{name} is not connected"))?;
        let req = match mode_req.to_ascii_lowercase().as_str() {
            "max" | "best" | "highest" => "highres".to_string(),
            "fastest" => "highrr".to_string(),
            _ => mode_req.clone(),
        };
        let p = plan.iter_mut().find(|p| p.name == name && p.enabled).ok_or_else(|| format!("{name} is not enabled"))?;
        p.mode = choose_mode(m, &req);
        p.pixel_size = target_resolution(m, &p.mode);
        p.scale = sanitize_scale(p.pixel_size, p.scale);
        chosen = p.mode.clone();
        Ok(())
    })?;
    let stored = if chosen == "preferred" { None } else { Some(chosen) };
    update_pref(&key, |pref| pref.mode = stored);
    Ok(report)
}

pub fn set_monitor_vrr(target: &str, value: &str) -> Result<CommitReport, String> {
    let on = match value.trim().to_ascii_lowercase().as_str() {
        "on" | "1" | "true" | "yes" => true,
        "off" | "0" | "false" | "no" => false,
        other => return Err(format!("invalid VRR value '{other}' (on/off)")),
    };
    let target = target.to_string();
    let mut key = String::new();
    let report = modify_layout(&format!("vrr {target}"), false, |snap, cfg, plan| {
        let name = resolve_target(snap, cfg, &target)?;
        key = snap.key(&name);
        let p = plan.iter_mut().find(|p| p.name == name && p.enabled).ok_or_else(|| format!("{name} is not enabled"))?;
        p.vrr = Some(on);
        Ok(())
    })?;
    update_pref(&key, |pref| pref.vrr = Some(on));
    Ok(report)
}

pub fn set_monitor_position(target: &str, spec: &str, anchor: Option<&str>) -> Result<CommitReport, String> {
    let target = target.to_string();
    let spec = spec.to_string();
    let anchor = anchor.map(str::to_string);
    modify_layout(&format!("position {target}"), false, move |snap, cfg, plan| {
        let name = resolve_target(snap, cfg, &target)?;
        let (how, anchor_name) = resolve_position_spec(snap, cfg, &spec, anchor.as_deref())?;
        let p = plan.iter_mut().find(|p| p.name == name && p.enabled).ok_or_else(|| format!("{name} is not enabled"))?;
        if p.mirror_of.is_some() {
            return Err(format!("{name} is mirroring another display; unmirror it first"));
        }
        apply_position_spec(plan, &name, &how, anchor_name.as_deref())
    })
}

/// Make a display primary: remembered in config, placed first by every
/// built-in mode, focused, and used as the mirror source.
pub fn set_primary(target: &str) -> Result<String, String> {
    let mut cfg = load_config();
    let snap = Snapshot::capture(&cfg)?;
    let name = resolve_target(&snap, &cfg, target)?;
    cfg.primary = Some(snap.key(&name));
    save_config(&cfg)?;
    log_info(&format!("primary display is now {name} ({})", snap.key(&name)));
    if snap.locked {
        mark_restart_pending("primary display changed while locked", None);
        return Ok(name);
    }
    let rt = load_runtime_state();
    let current = detect_mode(&snap, &cfg, &rt);
    match ProjectionMode::parse(&current) {
        Some(m) if m.is_extend() || m == ProjectionMode::Mirror || m == ProjectionMode::ExternalOnly || m == ProjectionMode::InternalOnly => {
            apply_projection_ex(&m.as_str(), true)?;
        }
        _ => {}
    }
    if snap.is_active(&name) {
        focus_monitor(&name);
    }
    Ok(name)
}

/// Mirror `target` (or `all`) from `source` (default: the primary).
pub fn mirror_monitor(target: &str, source: Option<&str>) -> Result<CommitReport, String> {
    let target = target.to_string();
    let source = source.map(str::to_string);
    modify_layout(&format!("mirror {target}"), false, move |snap, cfg, plan| {
        let src = match &source {
            Some(s) => resolve_target(snap, cfg, s)?,
            None => {
                // Primary by default — unless the primary is the one being
                // turned into a mirror; then the first other standalone
                // screen (built-in panel first) is the source.
                let target_name = if target.eq_ignore_ascii_case("all") { None } else { resolve_target(snap, cfg, &target).ok() };
                let primary = pick_primary(snap, cfg);
                match primary {
                    Some(p) if Some(&p) != target_name.as_ref() => p,
                    _ => {
                        let mut candidates: Vec<&HyprMonitor> = snap.active_standalone().into_iter().filter(|m| Some(&m.name) != target_name.as_ref()).collect();
                        candidates.sort_by_key(|m| !snap.is_internal(&m.name));
                        candidates.first().map(|m| m.name.clone()).ok_or("no other display to mirror from")?
                    }
                }
            }
        };
        let targets: Vec<String> = if target.eq_ignore_ascii_case("all") {
            snap.managed
                .iter()
                .filter(|m| m.name != src && !(snap.lid_closed() && snap.is_internal(&m.name)))
                .map(|m| m.name.clone())
                .collect()
        } else {
            vec![resolve_target(snap, cfg, &target)?]
        };
        if targets.is_empty() || targets.contains(&src) {
            return Err("nothing to mirror (a display can't mirror itself)".into());
        }
        // The source must be a standalone screen.
        match plan.iter_mut().find(|p| p.name == src) {
            Some(p) if p.enabled => {
                if p.mirror_of.is_some() {
                    p.mirror_of = None;
                    p.position = "auto".into();
                }
            }
            _ => {
                let m = snap.monitor(&src).ok_or_else(|| format!("{src} is not connected"))?;
                let e = plan_for(snap, cfg, m, &Overrides::default());
                plan.retain(|p| p.name != src);
                plan.push(e);
            }
        }
        for t in &targets {
            let m = snap.monitor(t).ok_or_else(|| format!("{t} is not connected"))?;
            let mut e = plan_for(snap, cfg, m, &Overrides::default());
            e.mirror_of = Some(src.clone());
            e.position = "auto".into();
            plan.retain(|p| &p.name != t);
            plan.push(e);
        }
        // Anything that mirrored a new target now mirrors the source.
        for p in plan.iter_mut() {
            if p.mirror_of.as_ref().map(|s| targets.contains(s)).unwrap_or(false) {
                p.mirror_of = Some(src.clone());
            }
        }
        if !plan.iter().any(|p| p.is_standalone()) {
            return Err("that would leave no standalone display".into());
        }
        Ok(())
    })
}

/// Stop mirroring on `target` (or `all`); former mirrors become screens of
/// their own to the right of the layout.
pub fn unmirror_monitor(target: &str) -> Result<CommitReport, String> {
    let target = target.to_string();
    modify_layout(&format!("unmirror {target}"), false, move |snap, cfg, plan| {
        let targets: Vec<String> = if target.eq_ignore_ascii_case("all") {
            plan.iter().filter(|p| p.enabled && p.mirror_of.is_some()).map(|p| p.name.clone()).collect()
        } else {
            vec![resolve_target(snap, cfg, &target)?]
        };
        for t in &targets {
            if let Some(m) = snap.monitor(t) {
                let e = plan_for(snap, cfg, m, &Overrides::default());
                plan.retain(|p| &p.name != t);
                plan.push(e);
            }
        }
        Ok(())
    })
}

/// Legacy helper for callers that hand us a raw `hyprctl keyword monitor`
/// style rule, e.g. `"HDMI-A-1, 1920x1080@60, 1920x0, 1"`.
pub fn dispatch_monitor_rule(rule: &str) -> Result<(), String> {
    let parts: Vec<&str> = rule.split(',').map(|s| s.trim()).collect();
    if parts.is_empty() || parts[0].is_empty() {
        return Ok(());
    }
    let output = parts[0];
    if parts.len() > 1 && parts[1].eq_ignore_ascii_case("disable") {
        return disable_monitor(output);
    }
    let mode = parts.get(1).copied().unwrap_or("preferred");
    let pos = parts.get(2).copied().unwrap_or("auto");
    let scale = parts.get(3).and_then(|s| s.parse::<f64>().ok()).unwrap_or(1.0);
    let mut i = 4;
    let mut mirror = None;
    let mut transform = None;
    while i + 1 < parts.len() {
        match parts[i] {
            "mirror" => mirror = Some(parts[i + 1]),
            "transform" => transform = parts[i + 1].parse::<i32>().ok(),
            _ => {}
        }
        i += 2;
    }
    if let Some(src) = mirror {
        return mirror_monitor(output, Some(src)).map(|_| ());
    }
    enable_monitor_ex(output, EnableOptions { mode: Some(mode.to_string()), position: Some(pos.to_string()), scale: Some(scale), transform }).map(|_| ())
}

/// Super+P style: step to the next applicable projection mode.
pub fn cycle_projection() -> Result<String, String> {
    let cfg = load_config();
    let snap = Snapshot::capture(&cfg)?;
    let order: Vec<ProjectionMode> = available_projection_modes(&snap, &cfg).into_iter().filter(|(_, ok)| *ok).map(|(m, _)| m).collect();
    if order.len() < 2 {
        return Err("only one display arrangement is possible right now".into());
    }
    let current = ProjectionMode::parse(&detect_mode(&snap, &cfg, &load_runtime_state()));
    let idx = current.and_then(|c| order.iter().position(|m| *m == c || (c.is_extend() && *m == ProjectionMode::ExtendRight)));
    let next = order[idx.map(|i| (i + 1) % order.len()).unwrap_or(0)].clone();
    apply_projection_ex(&next.as_str(), true)?;
    Ok(next.as_str())
}

/// Which built-in modes make sense for the current hardware (for the
/// Dynamic Island's quick-select row).
pub(crate) fn available_projection_modes(snap: &Snapshot, cfg: &MonitorsConfig) -> Vec<(ProjectionMode, bool)> {
    [
        ProjectionMode::InternalOnly,
        ProjectionMode::ExtendRight,
        ProjectionMode::ExternalOnly,
        ProjectionMode::Mirror,
        ProjectionMode::ExtendLeft,
        ProjectionMode::ExtendUp,
        ProjectionMode::ExtendDown,
        ProjectionMode::ExtendGrid(0),
    ]
    .into_iter()
    .map(|m| {
        let ok = match &m {
            // External-only is meaningless on desktops (it equals "all on").
            ProjectionMode::ExternalOnly => !snap.internals().is_empty() && build_projection_plan(&m, snap, cfg).is_ok(),
            ProjectionMode::ExtendGrid(_) => snap.managed.len() >= 3 && build_projection_plan(&m, snap, cfg).is_ok(),
            _ => build_projection_plan(&m, snap, cfg).is_ok(),
        };
        (m, ok)
    })
    .collect()
}


/// Read socket2 until EOF/error, feeding complete lines to the state
/// machine and ticking housekeeping every `SOCKET_TICK`. Partial lines are
/// buffered across reads (events can be split at any byte).
pub(crate) fn run_event_stream(mut stream: UnixStream, state: &mut DaemonState) {
    let _ = stream.set_read_timeout(Some(SOCKET_TICK));
    let mut buf = [0u8; 8192];
    let mut pending: Vec<u8> = Vec::new();
    loop {
        match stream.read(&mut buf) {
            Ok(0) => return,
            Ok(n) => {
                pending.extend_from_slice(&buf[..n]);
                while let Some(pos) = pending.iter().position(|b| *b == b'\n') {
                    let line: Vec<u8> = pending.drain(..=pos).collect();
                    let line = String::from_utf8_lossy(&line);
                    if let Some(ev) = parse_event(&line) {
                        log_debug(&format!("event: {ev:?}"));
                        state.on_event(ev);
                    }
                }
                if pending.len() > 1 << 20 {
                    pending.clear(); // never grow unbounded on garbage
                }
            }
            Err(e) if matches!(e.kind(), std::io::ErrorKind::WouldBlock | std::io::ErrorKind::TimedOut | std::io::ErrorKind::Interrupted) => {}
            Err(e) => {
                log_warn(&format!("socket2 read error: {e}"));
                return;
            }
        }
        state.tick();
    }
}

pub fn start_hotplug_daemon() -> Result<(), String> {
    let _guard = DaemonGuard::acquire()?;
    log_info("display daemon starting");
    let mut state = DaemonState::new();

    // Startup: wait for Hyprland, then resolve once.
    let mut backoff = Duration::from_millis(250);
    while hyprland_socket2_path().is_err() {
        thread::sleep(backoff);
        backoff = (backoff * 2).min(Duration::from_secs(5));
    }
    if is_locked() {
        log_info("started while locked; only lock-safe changes until unlock");
    }
    state.resolve(Trigger::Startup);
    state.refresh_snapshot();

    let mut first = true;
    let mut backoff = Duration::from_millis(250);
    loop {
        let sock = match hyprland_socket2_path() {
            Ok(p) => p,
            Err(e) => {
                log_debug(&format!("{e}; retrying"));
                thread::sleep(backoff);
                backoff = (backoff * 2).min(Duration::from_secs(5));
                state.tick();
                continue;
            }
        };
        match UnixStream::connect(&sock) {
            Ok(stream) => {
                backoff = Duration::from_millis(250);
                log_info(&format!("connected to {}", sock.display()));
                if !first {
                    // Events may have been missed while disconnected (or
                    // Hyprland restarted): resolve if the hardware changed.
                    let cfg = load_config();
                    if let Ok(s) = Snapshot::capture_settled(&cfg, Duration::from_secs(2)) {
                        if s.fingerprint != state.known_fingerprint || s.active_standalone().is_empty() {
                            state.resolve(Trigger::Hotplug);
                        }
                    }
                }
                first = false;
                run_event_stream(stream, &mut state);
                log_warn("Hyprland event stream closed; reconnecting");
                if !state.burst.is_empty() {
                    state.flush_burst();
                }
            }
            Err(e) => {
                log_debug(&format!("connect {} failed: {e}", sock.display()));
                // The instance may be gone for good: forget the override so
                // the next lookup can find a new one.
                if let Ok(mut g) = hypr_signature_override().lock() {
                    *g = None;
                }
                thread::sleep(backoff);
                backoff = (backoff * 2).min(Duration::from_secs(5));
            }
        }
    }
}

/// Open the Dynamic Island's display-projection panel (never while locked:
/// the lock surface must stay on top and Quickshell must not be poked).
pub fn trigger_island_display_osd() {
    if is_locked() {
        return;
    }
    let qs_path = nexa_config_dir().join("quickshell").to_string_lossy().to_string();
    if command_exists("qs") {
        let _ = spawn_detached("qs", &["-p", &qs_path, "ipc", "call", "displayProjection", "open"], &[]);
    }
}


