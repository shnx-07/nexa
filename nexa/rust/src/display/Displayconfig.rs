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
// PATHS
// ============================================================

pub(crate) fn current_uid() -> u32 {
    fs::read_to_string("/proc/self/status")
        .ok()
        .and_then(|s| {
            s.lines()
                .find_map(|l| l.strip_prefix("Uid:"))
                .and_then(|v| v.split_whitespace().next().and_then(|u| u.parse().ok()))
        })
        .unwrap_or(1000)
}

pub(crate) fn runtime_dir() -> PathBuf {
    if let Ok(r) = env::var("XDG_RUNTIME_DIR") {
        if !r.is_empty() {
            return PathBuf::from(r);
        }
    }
    let candidate = PathBuf::from(format!("/run/user/{}", current_uid()));
    if candidate.is_dir() {
        candidate
    } else {
        env::temp_dir()
    }
}

pub(crate) fn nexa_runtime_dir() -> PathBuf {
    let dir = runtime_dir().join("nexa");
    let _ = fs::create_dir_all(&dir);
    dir
}

pub(crate) fn home_dir() -> PathBuf {
    PathBuf::from(env::var("HOME").unwrap_or_else(|_| ".".to_string()))
}

pub(crate) fn nexa_config_dir() -> PathBuf {
    let base = env::var("XDG_CONFIG_HOME")
        .ok()
        .filter(|s| !s.is_empty())
        .map(PathBuf::from)
        .unwrap_or_else(|| home_dir().join(".config"));
    base.join("nexa")
}

pub(crate) fn config_path() -> PathBuf {
    nexa_config_dir().join("config").join("monitors.json")
}

pub(crate) fn locked_flag_paths() -> Vec<PathBuf> {
    vec![nexa_runtime_dir().join("locked")]
}

pub(crate) fn restart_pending_paths() -> Vec<PathBuf> {
    vec![nexa_runtime_dir().join("restart-pending")]
}

pub(crate) fn legacy_mode_state_path() -> PathBuf {
    runtime_dir().join("nexa-display-mode")
}
pub(crate) fn runtime_state_path() -> PathBuf {
    nexa_runtime_dir().join("display-state.json")
}
pub(crate) fn workspace_homes_path() -> PathBuf {
    nexa_runtime_dir().join("workspace-homes.json")
}
pub(crate) fn txn_marker_path() -> PathBuf {
    nexa_runtime_dir().join("display-txn.json")
}
pub(crate) fn lid_cache_path() -> PathBuf {
    nexa_runtime_dir().join("lid-state")
}
pub(crate) fn daemon_pid_path() -> PathBuf {
    nexa_runtime_dir().join("display-daemon.pid")
}
pub(crate) fn lock_path() -> PathBuf {
    runtime_dir().join("nexa-display.lock")
}

/// Write via temp file + rename so readers (QML, a second nexad) never see a
/// truncated file, and a crash mid-write never corrupts the previous copy.
/// The temp name is unique per process/time so concurrent writers can't
/// clobber each other's temp file.
pub(crate) fn write_atomic(path: &Path, contents: &[u8]) -> Result<(), String> {
    if let Some(parent) = path.parent() {
        let _ = fs::create_dir_all(parent);
    }
    let file_name = path.file_name().map(|n| n.to_string_lossy().to_string()).unwrap_or_default();
    let tmp = path.with_file_name(format!(
        ".{file_name}.tmp.{}.{}",
        std::process::id(),
        SystemTime::now().duration_since(UNIX_EPOCH).map(|d| d.subsec_nanos()).unwrap_or(0)
    ));
    fs::write(&tmp, contents).map_err(|e| format!("failed to write {}: {e}", tmp.display()))?;
    fs::rename(&tmp, path).map_err(|e| {
        let _ = fs::remove_file(&tmp);
        format!("failed to finalize {}: {e}", path.display())
    })
}

pub(crate) fn read_json_file<T: for<'de> Deserialize<'de>>(path: &Path) -> Option<T> {
    fs::read_to_string(path).ok().and_then(|s| serde_json::from_str(&s).ok())
}

pub(crate) fn write_json_file<T: Serialize>(path: &Path, value: &T) -> Result<(), String> {
    let json = serde_json::to_vec_pretty(value).map_err(|e| format!("serialization error: {e}"))?;
    write_atomic(path, &json)
}


/// (once) before defaults are used, so the next save can never silently
/// wipe a user's hand-edited profiles because of a single typo.
pub fn load_config() -> MonitorsConfig {
    let path = config_path();
    let Ok(content) = fs::read_to_string(&path) else {
        return MonitorsConfig::default();
    };
    match serde_json::from_str::<MonitorsConfig>(&content) {
        Ok(mut cfg) => {
            if cfg.version < CONFIG_VERSION {
                cfg.version = CONFIG_VERSION;
            }
            if cfg.grid_columns == 0 {
                cfg.grid_columns = default_grid_columns();
            }
            cfg
        }
        Err(e) => {
            let backup = path.with_extension("json.corrupt");
            if !backup.exists() {
                let _ = fs::copy(&path, &backup);
                log_warn(&format!("{} is invalid ({e}); backed up to {}", path.display(), backup.display()));
            } else {
                log_warn(&format!("{} is invalid ({e}); using defaults", path.display()));
            }
            MonitorsConfig::default()
        }
    }
}

pub fn save_config(cfg: &MonitorsConfig) -> Result<(), String> {
    write_json_file(&config_path(), cfg)
}

/// Live state that Hyprland itself doesn't reliably expose (e.g. `mirrorOf`

pub(crate) fn store_runtime_state(state: &mut RuntimeState) {
    state.updated_ms = now_ms();
    if let Err(e) = write_json_file(&runtime_state_path(), state) {
        log_warn(&format!("could not persist runtime state: {e}"));
    }
    if let Some(mode) = &state.mode {
        let _ = write_atomic(&legacy_mode_state_path(), mode.as_bytes());
    }
}

/// Persist the active projection mode (legacy API, kept for callers).
pub fn save_mode_state(mode: &str) {
    let mut st = load_runtime_state();
    st.mode = Some(mode.to_string());
    store_runtime_state(&mut st);
}

/// Read the last explicitly set projection mode (legacy API).
pub fn load_mode_state() -> Option<String> {
    load_runtime_state().mode
}


// ============================================================
// CROSS-PROCESS LOCK
//
// The daemon, the Dynamic Island and manual CLI calls can all run at once.
// Without serialisation, two batches issued milliseconds apart interleave
// and leave Hyprland half-applied. Advisory PID lock, stale reclamation on
// dead PID *or* excessive age, and re-entrant within one thread so helpers
// that commit (e.g. emergency fallback) can be called from inside a
// transaction without deadlocking on ourselves.
// ============================================================

thread_local! {
    static LOCK_DEPTH: std::cell::Cell<usize> = const { std::cell::Cell::new(0) };
}

pub(crate) struct DisplayLock {
    pub(crate) path: PathBuf,
    pub(crate) owner: bool,
}

impl DisplayLock {
    pub(crate) fn acquire(timeout: Duration) -> Result<Self, String> {
        let path = lock_path();
        if LOCK_DEPTH.with(|d| d.get()) > 0 {
            LOCK_DEPTH.with(|d| d.set(d.get() + 1));
            return Ok(DisplayLock { path, owner: false });
        }
        let start = Instant::now();
        loop {
            match fs::OpenOptions::new().write(true).create_new(true).open(&path) {
                Ok(mut f) => {
                    let _ = write!(f, "{} {}", std::process::id(), now_ms());
                    LOCK_DEPTH.with(|d| d.set(1));
                    return Ok(DisplayLock { path, owner: true });
                }
                Err(_) => {
                    if Self::reclaim_if_stale(&path) {
                        continue;
                    }
                    if start.elapsed() > timeout {
                        return Err("timed out waiting for the display lock (another transaction is running)".to_string());
                    }
                    thread::sleep(Duration::from_millis(50));
                }
            }
        }
    }

    pub(crate) fn reclaim_if_stale(path: &Path) -> bool {
        let Ok(contents) = fs::read_to_string(path) else {
            return false; // vanished between create_new and read: just retry
        };
        let mut parts = contents.split_whitespace();
        let pid = parts.next().and_then(|p| p.parse::<u32>().ok());
        let stamp = parts.next().and_then(|t| t.parse::<u64>().ok());
        let stale = match pid {
            None => true,
            Some(pid) if !pid_alive(pid) => true,
            Some(_) => stamp.map(|t| now_ms().saturating_sub(t) > LOCK_STALE_AGE.as_millis() as u64).unwrap_or(false),
        };
        if stale {
            log_warn(&format!("reclaiming stale display lock ({})", contents.trim()));
            let _ = fs::remove_file(path);
        }
        stale
    }
}

impl Drop for DisplayLock {
    fn drop(&mut self) {
        LOCK_DEPTH.with(|d| d.set(d.get().saturating_sub(1)));
        if self.owner {
            let _ = fs::remove_file(&self.path);
        }
    }
}

pub(crate) fn pid_alive(pid: u32) -> bool {
    Path::new(&format!("/proc/{pid}")).exists()
}


pub(crate) fn write_txn_marker(enabled: &[String], disabled: &[String]) {
    let marker = TxnMarker { at_ms: now_ms(), pid: std::process::id(), enabled: enabled.to_vec(), disabled: disabled.to_vec() };
    let _ = write_json_file(&txn_marker_path(), &marker);
}

pub(crate) fn read_recent_txn() -> Option<TxnMarker> {
    let m: TxnMarker = read_json_file(&txn_marker_path())?;
    (now_ms().saturating_sub(m.at_ms) <= SELF_EVENT_WINDOW.as_millis() as u64).then_some(m)
}


pub(crate) fn load_workspace_homes() -> WorkspaceHomes {
    let mut homes: WorkspaceHomes = read_json_file(&workspace_homes_path()).unwrap_or_default();
    let now = now_ms();
    homes.retain(|_, h| now.saturating_sub(h.at_ms) < WORKSPACE_HOME_TTL_MS);
    homes
}

pub(crate) fn save_workspace_homes(homes: &WorkspaceHomes) {
    let _ = write_json_file(&workspace_homes_path(), homes);
}

pub(crate) fn record_workspace_homes(entries: &[(String, String, String)]) {
    if entries.is_empty() {
        return;
    }
    let mut homes = load_workspace_homes();
    for (ws_ref, key, output) in entries {
        // Keep the *first* home: a workspace evacuated twice (external →
        // laptop → other external) should still return to where it started.
        homes.entry(ws_ref.clone()).or_insert(WorkspaceHome { home: key.clone(), from_output: output.clone(), at_ms: now_ms() });
    }
    save_workspace_homes(&homes);
}

/// Move only the workspaces that currently live on `sources` onto `target`.
pub(crate) fn move_workspaces_from(sources: &[&str], target: &str) {
    for ws in query_workspaces() {
        if sources.contains(&ws.monitor.as_str()) {
            move_workspace(&ws.dispatch_ref(), target);
        }
    }
}

/// Move *every* workspace onto `name`. Emergency use only.
pub fn move_workspaces_to_monitor(name: &str) {
    for ws in query_workspaces() {
        if ws.monitor != name {
            move_workspace(&ws.dispatch_ref(), name);
        }
    }
}


pub(crate) fn read_pending() -> Option<PendingAction> {
    for path in restart_pending_paths() {
        if !path.exists() {
            continue;
        }
        if flag_is_stale(&path) {
            log_debug(&format!("removing stale pending marker {}", path.display()));
            let _ = fs::remove_file(&path);
            continue;
        }
        let content = fs::read_to_string(&path).unwrap_or_default();
        return Some(serde_json::from_str(&content).unwrap_or_else(|_| PendingAction {
            reasons: vec![content.trim().to_string()].into_iter().filter(|s| !s.is_empty()).collect(),
            refresh_wallpaper: true,
            refresh_shell: true,
            ..Default::default()
        }));
    }
    None
}

pub fn pending_exists() -> bool {
    read_pending().is_some()
}

/// Record deferred work in both marker locations (the lock screen may only
/// be able to see one of them, depending on how it was started).
pub(crate) fn mark_restart_pending(reason: &str, requested_mode: Option<&str>) {
    let mut p = read_pending().unwrap_or(PendingAction { refresh_wallpaper: true, refresh_shell: true, ..Default::default() });
    let now = now_ms();
    if p.since_ms == 0 {
        p.since_ms = now;
    }
    p.updated_ms = now;
    p.reasons.retain(|r| r != reason);
    p.reasons.push(reason.to_string());
    if p.reasons.len() > 16 {
        let excess = p.reasons.len() - 16;
        p.reasons.drain(..excess);
    }
    if let Some(m) = requested_mode {
        p.requested_mode = Some(m.to_string());
    }
    p.refresh_wallpaper = true;
    p.refresh_shell = true;
    let Ok(json) = serde_json::to_vec_pretty(&p) else { return };
    for path in restart_pending_paths() {
        if let Err(e) = write_atomic(&path, &json) {
            log_warn(&format!("could not write pending marker: {e}"));
        }
    }
    log_info(&format!("deferred until unlock: {reason}"));
}

/// Claim the pending work exactly once. The first existing marker is
/// renamed away atomically, so if the lock-screen handler and the daemon
/// race for it, only one of them replays it.
pub(crate) fn take_pending() -> Option<PendingAction> {
    let mut claimed: Option<PendingAction> = None;
    for path in restart_pending_paths() {
        if !path.exists() {
            continue;
        }
        let tmp = path.with_file_name(format!(".nexa-pending-claim.{}.{}", std::process::id(), now_ms()));
        if fs::rename(&path, &tmp).is_ok() {
            if claimed.is_none() {
                let content = fs::read_to_string(&tmp).unwrap_or_default();
                claimed = Some(serde_json::from_str(&content).unwrap_or(PendingAction {
                    refresh_wallpaper: true,
                    refresh_shell: true,
                    ..Default::default()
                }));
            }
            let _ = fs::remove_file(&tmp);
        }
    }
    claimed
}

/// Replay deferred work after unlock: a clean auto-resolve (honouring a
/// mode requested while locked), a wallpaper re-sync and — reported back
/// to the caller — whether Quickshell should refresh.
///
/// Returns `Ok(None)` if nothing was pending.
pub fn resolve_pending() -> Result<Option<PendingAction>, String> {
    if is_locked() {
        return Err("the session is still locked; pending work stays deferred".into());
    }
    let Some(pending) = take_pending() else {
        return Ok(None);
    };
    log_info(&format!("session unlocked: replaying deferred work ({})", pending.reasons.join("; ")));
    let result = auto_resolve(Trigger::Unlock, pending.requested_mode.clone());
    if pending.refresh_wallpaper {
        schedule_wallpaper_sync(true);
    }
    match result {
        Ok(_) => Ok(Some(pending)),
        Err(e) => {
            // Don't lose a user's requested mode because of a hiccup.
            if is_locked() {
                mark_restart_pending("replay interrupted by a new lock", pending.requested_mode.as_deref());
            }
            Err(e)
        }
    }
}


pub(crate) fn record_runtime_state(mode: Option<String>, profile: Option<String>, plan: Option<&[PlannedMonitor]>, snap: Option<&Snapshot>) {
    let mut rt = load_runtime_state();
    if let Some(m) = mode {
        rt.mode = Some(m);
    }
    rt.active_profile = profile;
    if let Some(plan) = plan {
        let targets: Vec<String> = plan.iter().filter(|p| p.enabled && p.mirror_of.is_some()).map(|p| p.name.clone()).collect();
        rt.mirror_source = plan.iter().find_map(|p| if p.enabled { p.mirror_of.clone() } else { None });
        rt.mirror_targets = targets;
    }
    if let Some(s) = snap {
        rt.fingerprint = Some(s.fingerprint.clone());
        rt.lid_closed = match s.lid {
            LidState::Absent => None,
            l => Some(l == LidState::Closed),
        };
    }
    store_runtime_state(&mut rt);
}


// ============================================================
// PROFILES
//
// Profiles are keyed by the hardware fingerprint (and optionally the lid
// state). Two kinds:
// * user-named profiles (`save <name>`) — never touched by the engine;
// * auto profiles — one per (fingerprint, lid), refreshed whenever the user
//   picks a layout, so "dock at the office" and "TV at home" each come back
//   the way they were last used.
// ============================================================

/// Built-in mode names can't be used as profile names (`mode extend` must
/// stay unambiguous).
pub(crate) fn valid_profile_name(name: &str) -> Result<(), String> {
    let n = name.trim();
    if n.is_empty() || n.len() > 64 {
        return Err("profile names must be 1–64 characters".into());
    }
    if n.chars().any(|c| c.is_control() || c == '/' || c == '\\') {
        return Err("profile names can't contain control characters or slashes".into());
    }
    if !matches!(ProjectionMode::parse(n), Some(ProjectionMode::Custom(_))) {
        return Err(format!("'{n}' is a built-in mode name; choose another profile name"));
    }
    Ok(())
}

/// Snapshot the live layout as a profile (keyed by hardware key).
pub(crate) fn capture_profile(snap: &Snapshot, cfg: &MonitorsConfig, name: &str, auto: bool) -> Result<DisplayProfile, String> {
    if snap.active_standalone().is_empty() {
        return Err("no active display to save".into());
    }
    let rt = load_runtime_state();
    let primary = pick_primary(snap, cfg);
    let previous = cfg.profiles.iter().find(|p| p.name == name);
    let mut monitors = BTreeMap::new();
    for m in &snap.managed {
        let key = snap.key(&m.name);
        let prev = previous.and_then(|p| p.monitors.get(&key));
        let mirror_src = snap.mirror_of(&m.name);
        let state = if snap.is_active(&m.name) && (m.width > 0 || mirror_src.is_some()) {
            SavedMonitorState {
                enabled: true,
                mode: m.current_mode_string().or_else(|| prev.map(|p| p.mode.clone())).unwrap_or_else(|| "preferred".into()),
                position: if mirror_src.is_some() { "auto".into() } else { format!("{}x{}", m.x, m.y) },
                scale: if m.scale > 0.0 { m.scale } else { 1.0 },
                transform: m.transform,
                primary: primary.as_deref() == Some(m.name.as_str()),
                mirror_of: mirror_src.map(|s| snap.key(&s)),
                vrr: Some(m.vrr),
                last_output: m.name.clone(),
            }
        } else {
            SavedMonitorState {
                enabled: false,
                mode: prev.map(|p| p.mode.clone()).unwrap_or_else(|| "preferred".into()),
                position: "auto".into(),
                scale: prev.map(|p| p.scale).unwrap_or(1.0),
                transform: prev.map(|p| p.transform).unwrap_or(0),
                primary: false,
                mirror_of: None,
                vrr: prev.and_then(|p| p.vrr),
                last_output: m.name.clone(),
            }
        };
        monitors.insert(key, state);
    }
    let now = now_ms();
    Ok(DisplayProfile {
        name: name.to_string(),
        fingerprint: snap.fingerprint.clone(),
        mode: detect_mode(snap, cfg, &rt),
        monitors,
        auto,
        lid: if auto { snap.lid.profile_tag() } else { None },
        created_ms: previous.map(|p| p.created_ms).filter(|t| *t > 0).unwrap_or(now),
        last_used_ms: now,
    })
}

pub(crate) fn auto_profile_name(snap: &Snapshot) -> String {
    let n = snap.managed.len();
    let lid = match snap.lid {
        LidState::Closed => " · lid closed",
        _ => "",
    };
    // Short, stable suffix derived from the fingerprint so names stay unique.
    let mut h: u64 = 0xcbf29ce484222325;
    for b in snap.fingerprint.bytes() {
        h ^= b as u64;
        h = h.wrapping_mul(0x100000001b3);
    }
    format!("auto: {n} display{}{lid} [{:06x}]", if n == 1 { "" } else { "s" }, h & 0xffffff)
}

/// Save the live layout. `None` → the auto profile for this hardware set
/// and lid state; `Some(name)` → a user-named profile (replacing one of the
/// same name). Named saves also update per-monitor preferences, so every
/// built-in mode keeps the chosen resolution/scale/rotation.
pub fn save_current_as_profile(profile_name: Option<&str>) -> Result<(), String> {
    let mut cfg = load_config();
    let snap = Snapshot::capture(&cfg)?;
    if snap.locked {
        return Err("refusing to save while locked: the current layout is a temporary lock-safe one".into());
    }
    match profile_name.map(str::trim).filter(|s| !s.is_empty()) {
        None => {
            let name = auto_profile_name(&snap);
            let tag = snap.lid.profile_tag();
            let profile = capture_profile(&snap, &cfg, &name, true)?;
            cfg.profiles.retain(|p| !(p.auto && p.fingerprint == snap.fingerprint && p.lid == tag) && p.name != name);
            cfg.profiles.push(profile);
            log_info(&format!("remembered layout for this setup ({name})"));
        }
        Some(name) => {
            valid_profile_name(name)?;
            let existing = find_profile_by_name(&cfg, name).map(|p| p.name.clone());
            let final_name = existing.clone().unwrap_or_else(|| name.to_string());
            let profile = capture_profile(&snap, &cfg, &final_name, false)?;
            update_prefs_from_snapshot(&mut cfg, &snap);
            cfg.profiles.retain(|p| p.name != final_name);
            cfg.profiles.push(profile);
            log_info(&format!("{} profile '{final_name}'", if existing.is_some() { "updated" } else { "saved" }));
            let mut rt = load_runtime_state();
            rt.active_profile = Some(final_name);
            store_runtime_state(&mut rt);
        }
    }
    save_config(&cfg)
}

pub(crate) fn remember_current_layout(_mode: &str) -> Result<(), String> {
    save_current_as_profile(None)
}

pub(crate) fn update_prefs_from_snapshot(cfg: &mut MonitorsConfig, snap: &Snapshot) {
    for m in snap.active_standalone() {
        let key = snap.key(&m.name);
        let pref = cfg.monitor_prefs.entry(key).or_default();
        pref.mode = m.current_mode_string();
        pref.scale = Some(m.scale);
        pref.transform = Some(m.transform);
        pref.vrr = Some(m.vrr);
    }
}

pub(crate) fn update_pref(key: &str, f: impl FnOnce(&mut MonitorPref)) {
    let mut cfg = load_config();
    let pref = cfg.monitor_prefs.entry(key.to_string()).or_default();
    f(pref);
    if let Err(e) = save_config(&cfg) {
        log_warn(&format!("could not save monitor preference: {e}"));
    }
}

/// Best profile for this hardware set and lid state: profiles bound to a
/// different lid state are excluded; an exact lid match beats a lid-agnostic
/// one; then the most recently used wins.
pub(crate) fn find_profile_for<'a>(cfg: &'a MonitorsConfig, fingerprint: &str, lid: LidState) -> Option<&'a DisplayProfile> {
    let tag = lid.profile_tag();
    cfg.profiles
        .iter()
        .filter(|p| p.fingerprint == fingerprint)
        .filter(|p| match (&p.lid, &tag) {
            (Some(pl), Some(t)) => pl == t,
            (Some(pl), None) => pl != "closed",
            (None, _) => true,
        })
        .max_by_key(|p| (p.lid.is_some() && p.lid == tag, p.last_used_ms.max(p.created_ms)))
}

pub(crate) fn touch_profile(name: &str) {
    let mut cfg = load_config();
    if let Some(p) = cfg.profiles.iter_mut().find(|p| p.name == name) {
        p.last_used_ms = now_ms();
        let _ = save_config(&cfg);
    }
}

pub fn list_profiles_json() -> Value {
    let cfg = load_config();
    let fp = Snapshot::capture(&cfg).map(|s| s.fingerprint).unwrap_or_default();
    let active = load_runtime_state().active_profile;
    Value::Array(
        cfg.profiles
            .iter()
            .map(|p| {
                json!({
                    "name": p.name,
                    "mode": p.mode,
                    "auto": p.auto,
                    "lid": p.lid,
                    "fingerprint": p.fingerprint,
                    "matches_current": p.fingerprint == fp,
                    "active": active.as_deref() == Some(p.name.as_str()),
                    "monitor_count": p.monitors.len(),
                    "enabled_count": p.monitors.values().filter(|m| m.enabled).count(),
                    "monitors": p.monitors,
                    "created_ms": p.created_ms,
                    "last_used_ms": p.last_used_ms,
                })
            })
            .collect(),
    )
}

pub fn delete_profile(name: &str) -> Result<(), String> {
    let mut cfg = load_config();
    let target = find_profile_by_name(&cfg, name).map(|p| p.name.clone()).ok_or_else(|| format!("no profile named '{name}'"))?;
    cfg.profiles.retain(|p| p.name != target);
    save_config(&cfg)?;
    let mut rt = load_runtime_state();
    if rt.active_profile.as_deref() == Some(target.as_str()) {
        rt.active_profile = None;
        store_runtime_state(&mut rt);
    }
    log_info(&format!("deleted profile '{target}'"));
    Ok(())
}

pub fn rename_profile(old: &str, new: &str) -> Result<(), String> {
    valid_profile_name(new)?;
    let mut cfg = load_config();
    let target = find_profile_by_name(&cfg, old).map(|p| p.name.clone()).ok_or_else(|| format!("no profile named '{old}'"))?;
    if cfg.profiles.iter().any(|p| p.name.eq_ignore_ascii_case(new.trim()) && p.name != target) {
        return Err(format!("a profile named '{}' already exists", new.trim()));
    }
    if let Some(p) = cfg.profiles.iter_mut().find(|p| p.name == target) {
        p.name = new.trim().to_string();
        // Naming an auto profile promotes it to a user profile.
        p.auto = false;
        p.lid = None;
    }
    save_config(&cfg)?;
    let mut rt = load_runtime_state();
    if rt.active_profile.as_deref() == Some(target.as_str()) {
        rt.active_profile = Some(new.trim().to_string());
        store_runtime_state(&mut rt);
    }
    Ok(())
}

pub(crate) fn apply_profile_internal(profile: &DisplayProfile, reason: &str, focus_primary: bool) -> Result<CommitReport, String> {
    let cfg = load_config();
    let mut snap = Snapshot::capture(&cfg)?;
    if cfg.lid_close_policy.eq_ignore_ascii_case("ignore") && snap.lid == LidState::Closed {
        snap.lid = LidState::Open;
    }
    let was_mirroring = !mirror_targets_of(&snap).is_empty();
    let into_mirror = profile.monitors.values().any(|m| m.enabled && m.mirror_of.is_some());
    if was_mirroring && !into_mirror && !snap.locked && recover_from_mirror_if_needed(&snap, &cfg) {
        snap = Snapshot::capture(&cfg)?;
    }
    let plan = build_profile_plan(profile, &snap, &cfg)?;
    if into_mirror && !snap.locked {
        record_runtime_state(Some(profile.name.clone()), Some(profile.name.clone()), Some(&plan), Some(&snap));
    }
    let report = commit_plan(plan.clone(), &CommitOptions { focus_primary, reason: reason.to_string(), ..Default::default() })?;
    if !report.deferred {
        if was_mirroring && !into_mirror {
            post_mirror_exit_check(&plan);
        }
        let after = Snapshot::capture(&cfg).ok();
        let label = if profile.auto { profile.mode.clone() } else { profile.name.clone() };
        record_runtime_state(Some(label), (!profile.auto).then(|| profile.name.clone()), Some(&plan), after.as_ref());
        touch_profile(&profile.name);
        if report.changed || was_mirroring {
            schedule_wallpaper_sync(was_mirroring && !into_mirror);
        }
    }
    Ok(report)
}

/// Legacy public API: restore a saved profile (the monitor list argument is
/// ignored — a fresh snapshot is always taken under the lock).
pub fn apply_saved_profile(profile: &DisplayProfile, _all: &[HyprMonitor]) -> Result<(), String> {
    apply_profile_internal(profile, &format!("profile {}", profile.name), true).map(|_| ())
}


