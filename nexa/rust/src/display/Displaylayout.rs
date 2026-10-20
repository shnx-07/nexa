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
// SNAPSHOT — one coherent view of "what is plugged in and what is on"
// ============================================================

/// Everything the planners need, captured once. Planners are pure functions
/// of a `Snapshot` + config, which keeps them testable.
#[derive(Debug, Clone)]
pub struct Snapshot {
    /// Raw Hyprland view, including unmanaged/ghost outputs.
    pub all: Vec<HyprMonitor>,
    /// Real, connected, not-ignored monitors, in natural connector order.
    pub managed: Vec<HyprMonitor>,
    /// Outputs we deliberately leave alone (FALLBACK, HEADLESS-*, ignored).
    pub unmanaged: Vec<String>,
    /// Outputs Hyprland still lists but DRM reports as disconnected.
    pub ghosts: Vec<String>,
    pub(crate) active: HashSet<String>,
    pub(crate) keys: HashMap<String, String>,
    pub(crate) internal: HashSet<String>,
    pub(crate) drm: HashMap<String, DrmConnector>,
    /// Mirror relationships Hyprland fails to report (`mirrorOf` stays
    /// "none" on some versions) but that we know we configured.
    pub(crate) mirror_hints: HashMap<String, String>,
    pub lid: LidState,
    pub locked: bool,
    pub fingerprint: String,
}

impl Snapshot {
    pub(crate) fn capture(cfg: &MonitorsConfig) -> Result<Self, String> {
        let all = query_all_monitors()?;
        let active = query_active_monitors().ok();
        let mut snap = Self::from_parts(all, active, read_drm_connectors(), read_lid_state(), is_locked(), cfg);
        snap.apply_mirror_hints(&load_runtime_state());
        Ok(snap)
    }

    pub(crate) fn apply_mirror_hints(&mut self, rt: &RuntimeState) {
        if !matches!(rt.mode.as_deref(), Some("mirror") | Some("duplicate")) {
            return;
        }
        let Some(src) = rt.mirror_source.clone() else { return };
        if !self.is_active(&src) {
            return;
        }
        for t in &rt.mirror_targets {
            if let Some(m) = self.monitor(t) {
                if m.mirror_source().is_none() && !m.disabled && t != &src {
                    self.mirror_hints.insert(t.clone(), src.clone());
                    self.active.insert(t.clone());
                }
            }
        }
    }

    /// Like `capture`, but waits (bounded) for at least one real monitor to
    /// show up — used at daemon start-up and right after resume, when
    /// Hyprland may briefly report nothing (or only FALLBACK).
    pub(crate) fn capture_settled(cfg: &MonitorsConfig, wait: Duration) -> Result<Self, String> {
        let start = Instant::now();
        loop {
            match Self::capture(cfg) {
                Ok(s) if !s.managed.is_empty() || start.elapsed() >= wait => return Ok(s),
                Err(e) if start.elapsed() >= wait => return Err(e),
                _ => thread::sleep(Duration::from_millis(150)),
            }
        }
    }

    pub(crate) fn from_parts(
        all: Vec<HyprMonitor>,
        active_list: Option<Vec<HyprMonitor>>,
        drm: HashMap<String, DrmConnector>,
        lid: LidState,
        locked: bool,
        cfg: &MonitorsConfig,
    ) -> Self {
        let active_names: Option<HashSet<String>> = active_list.map(|l| l.into_iter().filter(|m| !m.disabled).map(|m| m.name).collect());

        let mut managed = Vec::new();
        let mut unmanaged = Vec::new();
        let mut ghosts = Vec::new();
        let raw_keys = assign_hardware_keys(&all);

        for m in &all {
            let kind = connector_kind(&m.name);
            let key = raw_keys.get(&m.name).cloned().unwrap_or_else(|| m.hardware_key());
            if !kind.manageable() || is_ignored(cfg, &m.name, &key) || !valid_output_name(&m.name) {
                unmanaged.push(m.name.clone());
                continue;
            }
            // Never classify the built-in panel as a ghost: some firmware
            // reports odd connector status for eDP while the lid is shut.
            if drm_status_in(&drm, &m.name) == DrmStatus::Disconnected && !is_internal_with(cfg, &m.name) {
                ghosts.push(m.name.clone());
                continue;
            }
            managed.push(m.clone());
        }
        managed.sort_by_key(|m| natural_key(&m.name));

        // Keys/fingerprint over managed monitors only, so FALLBACK or a
        // streaming HEADLESS output never changes which profile matches.
        let keys = assign_hardware_keys(&managed);
        let fingerprint = fingerprint_of_keys(keys.values());

        let active: HashSet<String> = managed
            .iter()
            .chain(all.iter().filter(|m| ghosts.contains(&m.name)))
            .filter(|m| {
                !m.disabled
                    && match &active_names {
                        Some(set) => set.contains(&m.name) || m.mirror_source().is_some(),
                        None => true,
                    }
            })
            .map(|m| m.name.clone())
            .collect();

        let internal = managed.iter().filter(|m| is_internal_with(cfg, &m.name)).map(|m| m.name.clone()).collect();

        Self { all, managed, unmanaged, ghosts, active, keys, internal, drm, mirror_hints: HashMap::new(), lid, locked, fingerprint }
    }

    pub(crate) fn monitor(&self, name: &str) -> Option<&HyprMonitor> {
        self.managed.iter().find(|m| m.name == name)
    }
    pub(crate) fn key(&self, name: &str) -> String {
        self.keys.get(name).cloned().unwrap_or_else(|| {
            self.all.iter().find(|m| m.name == name).map(|m| m.hardware_key()).unwrap_or_else(|| format!("port_{name}"))
        })
    }
    pub(crate) fn by_key(&self, key: &str) -> Option<&HyprMonitor> {
        self.managed.iter().find(|m| self.keys.get(&m.name).map(|k| k == key).unwrap_or(false))
    }
    pub(crate) fn is_active(&self, name: &str) -> bool {
        self.active.contains(name)
    }
    pub(crate) fn is_internal(&self, name: &str) -> bool {
        self.internal.contains(name)
    }
    pub(crate) fn internals(&self) -> Vec<&HyprMonitor> {
        self.managed.iter().filter(|m| self.is_internal(&m.name)).collect()
    }
    pub(crate) fn externals(&self) -> Vec<&HyprMonitor> {
        self.managed.iter().filter(|m| !self.is_internal(&m.name)).collect()
    }
    pub(crate) fn active_managed(&self) -> Vec<&HyprMonitor> {
        self.managed.iter().filter(|m| self.is_active(&m.name)).collect()
    }
    /// Active outputs that are real screens of their own (not mirrors).
    pub(crate) fn active_standalone(&self) -> Vec<&HyprMonitor> {
        self.active_managed().into_iter().filter(|m| self.mirror_of(&m.name).is_none()).collect()
    }
    pub(crate) fn mirror_of(&self, name: &str) -> Option<String> {
        self.all
            .iter()
            .find(|m| m.name == name)
            .and_then(|m| m.mirror_source().map(str::to_string))
            .or_else(|| self.mirror_hints.get(name).cloned())
    }
    pub(crate) fn drm_status(&self, name: &str) -> DrmStatus {
        drm_status_in(&self.drm, name)
    }
    pub(crate) fn lid_closed(&self) -> bool {
        self.lid == LidState::Closed
    }
}


// ============================================================
// MODE, REFRESH-RATE & SCALE NEGOTIATION
//
// A saved profile or request can name a mode the monitor no longer offers
// (now behind a lower-bandwidth cable, dock or adapter). Blindly sending it
// fails silently or black-screens. Validate against `availableModes` and
// degrade gracefully: exact → same-res nearest rate → same-res highest
// rate → preferred.
// ============================================================

#[derive(Debug, Clone, Copy, PartialEq)]
pub(crate) struct ModeSpec {
    pub(crate) w: i32,
    pub(crate) h: i32,
    pub(crate) hz: Option<f64>,
}

pub(crate) fn parse_mode(s: &str) -> Option<ModeSpec> {
    let s = s.trim();
    let s = s
        .strip_suffix("Hz")
        .or_else(|| s.strip_suffix("hz"))
        .or_else(|| s.strip_suffix("HZ"))
        .unwrap_or(s);
    let (res, hz) = match s.split_once('@') {
        Some((r, h)) => (r, Some(h.trim().parse::<f64>().ok()?)),
        None => (s, None),
    };
    let (w, h) = res.split_once('x')?;
    let spec = ModeSpec { w: w.trim().parse().ok()?, h: h.trim().parse().ok()?, hz };
    if spec.w <= 0 || spec.h <= 0 || spec.hz.map(|r| !r.is_finite() || r <= 0.0).unwrap_or(false) {
        return None;
    }
    Some(spec)
}

pub(crate) fn format_mode(w: i32, h: i32, hz: Option<f64>) -> String {
    match hz {
        Some(r) if r > 0.0 => format!("{w}x{h}@{}", fmt_num(r, 3)),
        _ => format!("{w}x{h}"),
    }
}

/// Format a float with at most `decimals` places and no trailing zeros.
pub(crate) fn fmt_num(v: f64, decimals: usize) -> String {
    let s = format!("{v:.decimals$}");
    if s.contains('.') {
        s.trim_end_matches('0').trim_end_matches('.').to_string()
    } else {
        s
    }
}

pub(crate) fn is_mode_keyword(s: &str) -> bool {
    matches!(s.to_ascii_lowercase().as_str(), "preferred" | "auto" | "highrr" | "highres" | "maxwidth")
}

pub(crate) fn choose_mode(monitor: &HyprMonitor, requested: &str) -> String {
    let requested = requested.trim();
    if requested.is_empty() || requested.eq_ignore_ascii_case("preferred") || requested.eq_ignore_ascii_case("auto") {
        return "preferred".to_string();
    }
    if is_mode_keyword(requested) {
        return requested.to_ascii_lowercase();
    }
    let Some(req) = parse_mode(requested) else {
        log_warn(&format!("{}: unparseable mode '{requested}', using preferred", monitor.name));
        return "preferred".to_string();
    };
    let available: Vec<ModeSpec> = monitor.available_modes.iter().filter_map(|m| parse_mode(m)).collect();
    if available.is_empty() {
        // Nothing to validate against (nested session, old Hyprland): trust it.
        return format_mode(req.w, req.h, req.hz);
    }
    let same_res: Vec<&ModeSpec> = available.iter().filter(|m| m.w == req.w && m.h == req.h).collect();
    if same_res.is_empty() {
        log_warn(&format!(
            "{}: resolution {}x{} not offered (adapter/cable bandwidth?), falling back to preferred",
            monitor.name, req.w, req.h
        ));
        return "preferred".to_string();
    }
    let rate = |m: &ModeSpec| m.hz.unwrap_or(0.0);
    if let Some(want) = req.hz {
        // Exact (within rounding noise, e.g. 144 vs 143.998).
        if let Some(m) = same_res.iter().find(|m| (rate(m) - want).abs() < 0.05) {
            return format_mode(m.w, m.h, m.hz);
        }
        // Near (59.94 vs 60.00 are the "same" rate to a human).
        if let Some(m) = same_res
            .iter()
            .filter(|m| (rate(m) - want).abs() < 1.0)
            .min_by(|a, b| (rate(a) - want).abs().total_cmp(&(rate(b) - want).abs()))
        {
            return format_mode(m.w, m.h, m.hz);
        }
    }
    let best = same_res.iter().max_by(|a, b| rate(a).total_cmp(&rate(b))).expect("non-empty");
    if req.hz.is_some() {
        log_warn(&format!(
            "{}: {requested} unavailable, using {} (highest rate at that resolution)",
            monitor.name,
            format_mode(best.w, best.h, best.hz)
        ));
    }
    format_mode(best.w, best.h, best.hz)
}

/// Best estimate of the pixel resolution a mode string will produce, for
/// layout computation *before* Hyprland has applied it.
pub(crate) fn target_resolution(monitor: &HyprMonitor, mode: &str) -> (i32, i32) {
    if let Some(spec) = parse_mode(mode) {
        return (spec.w, spec.h);
    }
    let available: Vec<ModeSpec> = monitor.available_modes.iter().filter_map(|m| parse_mode(m)).collect();
    let current = (monitor.width > 0 && monitor.height > 0 && !monitor.disabled).then_some((monitor.width, monitor.height));
    match mode.to_ascii_lowercase().as_str() {
        "highres" | "maxwidth" => available
            .iter()
            .max_by_key(|m| (m.w as i64) * (m.h as i64))
            .map(|m| (m.w, m.h))
            .or(current)
            .unwrap_or(FALLBACK_RES),
        "highrr" => available
            .iter()
            .max_by(|a, b| a.hz.unwrap_or(0.0).total_cmp(&b.hz.unwrap_or(0.0)).then((a.w * a.h).cmp(&(b.w * b.h))))
            .map(|m| (m.w, m.h))
            .or(current)
            .unwrap_or(FALLBACK_RES),
        // "preferred": DRM lists the EDID-preferred timing first.
        _ => available.first().map(|m| (m.w, m.h)).or(current).unwrap_or(FALLBACK_RES),
    }
}

/// Hyprland rejects scales whose logical size isn't a whole number of
/// pixels ("invalid scale, will use …") and silently substitutes its own
/// choice, which then breaks our computed layout. Find the closest valid
/// scale in 1/120 steps (the wp-fractional-scale granularity).
pub(crate) fn sanitize_scale(px: (i32, i32), requested: f64) -> f64 {
    let req = if requested.is_finite() && requested > 0.0 { requested.clamp(0.25, 10.0) } else { 1.0 };
    let (w, h) = px;
    if w <= 0 || h <= 0 {
        return req;
    }
    let valid = |s: f64| {
        let lw = w as f64 / s;
        let lh = h as f64 / s;
        (lw - lw.round()).abs() < 0.01 && (lh - lh.round()).abs() < 0.01
    };
    if valid(req) {
        return (req * 1_000_000.0).round() / 1_000_000.0;
    }
    let center = (req * 120.0).round() as i64;
    for d in 0..=60i64 {
        for k in [center - d, center + d] {
            if k >= 30 {
                let s = k as f64 / 120.0;
                if valid(s) {
                    if (s - req).abs() > 0.001 {
                        log_warn(&format!("scale {req} is invalid for {w}x{h}, using {}", fmt_num(s, 6)));
                    }
                    return (s * 1_000_000.0).round() / 1_000_000.0;
                }
            }
        }
    }
    req.round().max(1.0)
}

/// Hyprland transform codes: 0 normal, 1 90°, 2 180°, 3 270°, 4–7 flipped.
pub fn parse_transform(s: &str) -> Option<i32> {
    Some(match s.trim().to_ascii_lowercase().as_str() {
        "0" | "normal" | "none" | "landscape" => 0,
        "1" | "90" | "right" | "portrait" => 1,
        "2" | "180" | "inverted" | "upside-down" => 2,
        "3" | "270" | "left" | "portrait-flipped" => 3,
        "4" | "flipped" => 4,
        "5" | "flipped-90" => 5,
        "6" | "flipped-180" => 6,
        "7" | "flipped-270" => 7,
        _ => return None,
    })
}


// ============================================================
// GEOMETRY
// ============================================================

/// Logical size = pixels rotated by transform, divided by scale.
pub(crate) fn logical_size(px: (i32, i32), scale: f64, transform: i32) -> (i32, i32) {
    let (w, h) = if transform.rem_euclid(2) == 1 { (px.1, px.0) } else { px };
    let s = if scale > 0.0 { scale } else { 1.0 };
    (((w as f64) / s).round() as i32, ((h as f64) / s).round() as i32)
}

pub(crate) fn parse_pos(s: &str) -> Option<(i32, i32)> {
    let (x, y) = s.trim().split_once('x')?;
    Some((x.trim().parse().ok()?, y.trim().parse().ok()?))
}


/// Shift the canvas so its top-left is 0,0. Negative coordinates are legal
/// in Hyprland but confuse XWayland apps and our "primary = 0x0" convention.
pub(crate) fn normalize_origin(plan: &mut [PlannedMonitor]) {
    let positioned: Vec<(i32, i32)> = plan.iter().filter(|p| p.is_standalone()).filter_map(|p| p.pos()).collect();
    let (Some(min_x), Some(min_y)) = (positioned.iter().map(|p| p.0).min(), positioned.iter().map(|p| p.1).min()) else {
        return;
    };
    if min_x == 0 && min_y == 0 {
        return;
    }
    for p in plan.iter_mut().filter(|p| p.is_standalone()) {
        if let Some((x, y)) = p.pos() {
            p.set_pos(x - min_x, y - min_y);
        }
    }
}

/// Place `"auto"` entries to the right of everything explicitly positioned.
pub(crate) fn resolve_auto_positions(plan: &mut [PlannedMonitor]) {
    let mut max_right = plan.iter().filter(|p| p.is_standalone()).filter_map(|p| p.rect()).map(|r| r.right()).max().unwrap_or(0);
    for p in plan.iter_mut() {
        if p.is_standalone() && p.pos().is_none() {
            p.set_pos(max_right, 0);
            max_right += p.logical().0;
        }
    }
}

pub(crate) fn layout_is_sound(rects: &[Rect]) -> bool {
    for i in 0..rects.len() {
        for j in (i + 1)..rects.len() {
            if rects[i].overlaps(&rects[j]) {
                return false;
            }
        }
    }
    if rects.len() <= 1 {
        return true;
    }
    // Connectivity: every monitor reachable by the cursor via shared edges.
    let mut seen = vec![false; rects.len()];
    let mut stack = vec![0usize];
    seen[0] = true;
    while let Some(i) = stack.pop() {
        for j in 0..rects.len() {
            if !seen[j] && rects[i].touches(&rects[j]) {
                seen[j] = true;
                stack.push(j);
            }
        }
    }
    seen.into_iter().all(|s| s)
}

/// A saved/custom layout can become invalid when a mode falls back to a
/// different resolution, a scale is sanitised, or a monitor is rotated:
/// monitors overlap or drift apart so the cursor can't cross. Repair it
/// while preserving the user's arrangement order along the dominant axis.
pub(crate) fn fix_layout(plan: &mut [PlannedMonitor], align: Align) -> bool {
    let idx: Vec<usize> = (0..plan.len()).filter(|&i| plan[i].is_standalone() && plan[i].pos().is_some()).collect();
    let rects: Vec<Rect> = idx.iter().filter_map(|&i| plan[i].rect()).collect();
    if layout_is_sound(&rects) {
        return false;
    }
    let (xs, ys): (Vec<i64>, Vec<i64>) = rects.iter().map(|r| r.center2()).unzip();
    let spread = |v: &[i64]| v.iter().max().unwrap_or(&0) - v.iter().min().unwrap_or(&0);
    let horizontal = spread(&xs) >= spread(&ys);

    let mut order: Vec<(usize, (i64, i64))> = idx.iter().copied().zip(rects.iter().map(|r| r.center2())).collect();
    order.sort_by_key(|(_, (cx, cy))| if horizontal { (*cx, *cy) } else { (*cy, *cx) });

    let blocks: Vec<Block> = order.iter().map(|(i, _)| Block::single(plan[*i].clone())).collect();
    let laid = if horizontal { Block::row(blocks, align) } else { Block::column(blocks, Align::Center) };
    for placed in laid.items {
        if let Some(p) = plan.iter_mut().find(|p| p.name == placed.name) {
            p.position = placed.position;
        }
    }
    log_warn(&format!("layout had overlaps/gaps; re-flowed {} monitor(s) {}", idx.len(), if horizontal { "horizontally" } else { "vertically" }));
    true
}


pub(crate) fn place_relative(plan: &mut [PlannedMonitor], name: &str, how: &str, anchor: Option<&str>) -> Result<(), String> {
    let others: Vec<Rect> = plan
        .iter()
        .filter(|p| p.is_standalone() && p.name != name && anchor.map(|a| p.name == a).unwrap_or(true))
        .filter_map(|p| p.rect())
        .collect();
    let Some(me) = plan.iter().position(|p| p.name == name) else {
        return Err(format!("{name} is not part of the layout"));
    };
    let (w, h) = plan[me].logical();
    if others.is_empty() {
        plan[me].set_pos(0, 0);
        return Ok(());
    }
    let min_x = others.iter().map(|r| r.x).min().unwrap_or(0);
    let max_x = others.iter().map(|r| r.right()).max().unwrap_or(0);
    let min_y = others.iter().map(|r| r.y).min().unwrap_or(0);
    let max_y = others.iter().map(|r| r.bottom()).max().unwrap_or(0);
    let center_x = min_x + (max_x - min_x - w) / 2;
    let center_y = min_y + (max_y - min_y - h) / 2;
    let (x, y) = match how {
        "right" | "right-of" | "auto" => (max_x, min_y),
        "left" | "left-of" => (min_x - w, min_y),
        "above" | "up" | "top" => (center_x, min_y - h),
        "below" | "down" | "bottom" => (center_x, max_y),
        "center-right" => (max_x, center_y),
        "center-left" => (min_x - w, center_y),
        other => return Err(format!("unknown position '{other}' (use XxY, auto, left, right, above, below, optionally with :<display>)")),
    };
    plan[me].set_pos(x, y);
    Ok(())
}

/// Split `right-of:DP-2` style specs and resolve the anchor like any other
/// target ("internal", a hardware key, a description…). An explicit anchor
/// argument wins over one embedded in the spec.
pub(crate) fn resolve_position_spec(snap: &Snapshot, cfg: &MonitorsConfig, spec: &str, explicit_anchor: Option<&str>) -> Result<(String, Option<String>), String> {
    let spec = spec.trim();
    let (how, embedded) = match spec.split_once(':') {
        Some((h, a)) if parse_pos(spec).is_none() => (h.trim().to_string(), Some(a.trim().to_string()).filter(|a| !a.is_empty())),
        _ => (spec.to_string(), None),
    };
    let anchor = match explicit_anchor.map(str::to_string).or(embedded) {
        Some(a) => Some(resolve_target(snap, cfg, &a)?),
        None => None,
    };
    Ok((how, anchor))
}

pub(crate) fn apply_position_spec(plan: &mut [PlannedMonitor], name: &str, spec: &str, anchor: Option<&str>) -> Result<(), String> {
    let spec = spec.trim();
    if anchor == Some(name) {
        return Err("a display can't be positioned relative to itself".into());
    }
    if spec.is_empty() || spec.eq_ignore_ascii_case("auto") {
        return place_relative(plan, name, "right", None);
    }
    if let Some((x, y)) = parse_pos(spec) {
        if let Some(p) = plan.iter_mut().find(|p| p.name == name) {
            p.set_pos(x, y);
        }
        return Ok(());
    }
    place_relative(plan, name, &spec.to_ascii_lowercase(), anchor)
}


/// After removing a screen from a row/column, pull the rest together while
/// keeping their order (fix_layout alone only repairs *disconnected* sets).
pub(crate) fn close_gaps(plan: &mut [PlannedMonitor], align: Align) {
    let rects: Vec<Rect> = plan.iter().filter(|p| p.is_standalone()).filter_map(|p| p.rect()).collect();
    if !layout_is_sound(&rects) {
        fix_layout(plan, align);
    }
}


pub(crate) fn mode_label(mode: &ProjectionMode, snap: &Snapshot) -> String {
    let desktop = snap.internals().is_empty();
    match mode {
        ProjectionMode::InternalOnly if desktop => "Primary only".into(),
        ProjectionMode::InternalOnly => "PC screen only".into(),
        ProjectionMode::ExternalOnly => "Second screen only".into(),
        ProjectionMode::ExtendRight => "Extend".into(),
        ProjectionMode::ExtendLeft => "Extend left".into(),
        ProjectionMode::ExtendUp => "Extend up".into(),
        ProjectionMode::ExtendDown => "Extend down".into(),
        ProjectionMode::ExtendGrid(_) => "Grid".into(),
        ProjectionMode::Mirror => "Duplicate".into(),
        ProjectionMode::Auto => "Automatic".into(),
        ProjectionMode::Custom(n) => n.clone(),
    }
}

/// Bounding box of all standalone active outputs in logical pixels.
pub(crate) fn canvas_of(monitors: &[&HyprMonitor]) -> Option<(i32, i32, i32, i32)> {
    let mut it = monitors.iter().map(|m| {
        let (w, h) = logical_size((m.width, m.height), m.scale, m.transform);
        (m.x, m.y, m.x + w, m.y + h)
    });
    let first = it.next()?;
    let (x0, y0, x1, y1) = it.fold(first, |a, b| (a.0.min(b.0), a.1.min(b.1), a.2.max(b.2), a.3.max(b.3)));
    Some((x0, y0, (x1 - x0).max(1), (y1 - y0).max(1)))
}

pub(crate) fn display_infos(snap: &Snapshot, cfg: &MonitorsConfig) -> (Vec<DisplayInfo>, Value) {
    let standalone = snap.active_standalone();
    let canvas = canvas_of(&standalone);
    let primary = pick_primary(snap, cfg);
    let standalone_names: HashSet<&str> = standalone.iter().map(|m| m.name.as_str()).collect();
    let managed_names: HashSet<&str> = snap.managed.iter().map(|m| m.name.as_str()).collect();

    let infos = snap
        .all
        .iter()
        .map(|m| {
            let active = snap.is_active(&m.name);
            let (lw, lh) = logical_size((m.width, m.height), m.scale, m.transform);
            let topology = match canvas {
                Some((cx, cy, cw, ch)) if standalone_names.contains(m.name.as_str()) => Some(json!({
                    "x": (m.x - cx) as f64 / cw as f64,
                    "y": (m.y - cy) as f64 / ch as f64,
                    "w": lw as f64 / cw as f64,
                    "h": lh as f64 / ch as f64,
                })),
                _ => None,
            };
            DisplayInfo {
                id: m.id,
                name: m.name.clone(),
                description: m.description.clone(),
                hardware_key: snap.key(&m.name),
                make: m.make.clone(),
                model: m.model.clone(),
                serial: m.serial.clone(),
                connector_kind: connector_kind(&m.name).label().to_string(),
                width: m.width,
                height: m.height,
                refresh_rate: m.refresh_rate,
                x: m.x,
                y: m.y,
                scale: m.scale,
                transform: m.transform,
                logical_width: lw,
                logical_height: lh,
                focused: m.focused && active,
                disabled: !active,
                dpms: m.dpms_status,
                vrr: m.vrr,
                is_internal: snap.is_internal(&m.name) || is_internal_with(cfg, &m.name),
                is_primary: primary.as_deref() == Some(m.name.as_str()),
                managed: managed_names.contains(m.name.as_str()),
                physically_connected: match snap.drm_status(&m.name) {
                    DrmStatus::Connected => Some(true),
                    DrmStatus::Disconnected => Some(false),
                    DrmStatus::Unknown => None,
                },
                mirror_of: snap.mirror_of(&m.name).unwrap_or_else(|| "none".into()),
                active_workspace: if active && m.active_workspace.id != 0 { Some(m.active_workspace.id) } else { None },
                available_modes: m.available_modes.clone(),
                topology,
            }
        })
        .collect();

    let canvas_json = match canvas {
        Some((x, y, w, h)) => json!({"x": x, "y": y, "width": w, "height": h}),
        None => Value::Null,
    };
    (infos, canvas_json)
}


