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
// LOGGING
//
// Everything goes to stderr. stdout is reserved for machine-readable output
// (`info`, `profiles`, `--json` results) so QML never has to parse around
// log lines.
// ============================================================

pub(crate) fn debug_enabled() -> bool {
    static DEBUG: OnceLock<bool> = OnceLock::new();
    *DEBUG.get_or_init(|| {
        env::var("NEXA_DISPLAY_DEBUG")
            .map(|v| !v.is_empty() && v != "0")
            .unwrap_or(false)
    })
}

pub(crate) fn log_line(level: &str, msg: &str) {
    let _ = writeln!(std::io::stderr(), "[nexa-display] {level}{msg}");
}
pub(crate) fn log_debug(msg: &str) {
    if debug_enabled() {
        log_line("DEBUG: ", msg);
    }
}
pub(crate) fn log_info(msg: &str) {
    log_line("", msg);
}
pub(crate) fn log_warn(msg: &str) {
    log_line("WARN: ", msg);
}
pub(crate) fn log_error(msg: &str) {
    log_line("ERROR: ", msg);
}


// ============================================================
// TIME HELPERS
// ============================================================

pub(crate) fn now_ms() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_millis() as u64)
        .unwrap_or(0)
}

/// Seconds since boot *including* time spent suspended (CLOCK_BOOTTIME).
pub(crate) fn uptime_secs() -> Option<f64> {
    fs::read_to_string("/proc/uptime")
        .ok()?
        .split_whitespace()
        .next()?
        .parse()
        .ok()
}

/// Wall-clock time of the last boot, from `/proc/stat` `btime`.
pub(crate) fn boot_time_secs() -> Option<u64> {
    fs::read_to_string("/proc/stat")
        .ok()?
        .lines()
        .find_map(|l| l.strip_prefix("btime ").and_then(|v| v.trim().parse().ok()))
}

pub(crate) fn file_mtime_secs(path: &Path) -> Option<u64> {
    fs::metadata(path)
        .ok()?
        .modified()
        .ok()?
        .duration_since(UNIX_EPOCH)
        .ok()
        .map(|d| d.as_secs())
}


// ============================================================
// PROCESS RUNNER
//
// Every external command goes through here: bounded by a timeout (a wedged
// Hyprland must never hang the daemon), stdin detached, output captured
// concurrently so a chatty child can't deadlock on a full pipe.
// ============================================================

#[derive(Debug, Clone, Default)]
pub(crate) struct CmdOutput {
    pub(crate) success: bool,
    pub(crate) stdout: String,
    pub(crate) stderr: String,
}

/// If the daemon discovers that Hyprland restarted under a new instance
/// signature, later hyprctl calls are pointed at it explicitly. We never
/// mutate our own environment (`set_var` is unsound in multithreaded code).
pub(crate) fn hypr_signature_override() -> &'static Mutex<Option<String>> {
    static SIG: OnceLock<Mutex<Option<String>>> = OnceLock::new();
    SIG.get_or_init(|| Mutex::new(None))
}

pub(crate) fn current_hypr_signature() -> Option<String> {
    hypr_signature_override()
        .lock()
        .ok()
        .and_then(|g| g.clone())
        .or_else(|| env::var("HYPRLAND_INSTANCE_SIGNATURE").ok().filter(|s| !s.is_empty()))
}

pub(crate) fn build_command(program: &str, args: &[&str]) -> Command {
    let mut cmd = Command::new(program);
    cmd.args(args).stdin(Stdio::null());
    if program == "hyprctl" {
        if let Some(sig) = hypr_signature_override().lock().ok().and_then(|g| g.clone()) {
            cmd.env("HYPRLAND_INSTANCE_SIGNATURE", sig);
        }
    }
    cmd
}

pub(crate) fn run_cmd_env(program: &str, args: &[&str], envs: &[(&str, &str)], timeout: Duration) -> Result<CmdOutput, String> {
    let mut cmd = build_command(program, args);
    for (k, v) in envs {
        cmd.env(k, v);
    }
    cmd.stdout(Stdio::piped()).stderr(Stdio::piped());
    let mut child = cmd.spawn().map_err(|e| format!("failed to spawn {program}: {e}"))?;

    let out_reader = child.stdout.take().map(|mut s| {
        thread::spawn(move || {
            let mut b = Vec::new();
            let _ = s.read_to_end(&mut b);
            b
        })
    });
    let err_reader = child.stderr.take().map(|mut s| {
        thread::spawn(move || {
            let mut b = Vec::new();
            let _ = s.read_to_end(&mut b);
            b
        })
    });

    let start = Instant::now();
    let status = loop {
        match child.try_wait() {
            Ok(Some(status)) => break status,
            Ok(None) => {
                if start.elapsed() > timeout {
                    let _ = child.kill();
                    let _ = child.wait();
                    return Err(format!("{program} {} timed out after {}ms", args.join(" "), timeout.as_millis()));
                }
                thread::sleep(Duration::from_millis(4));
            }
            Err(e) => return Err(format!("failed waiting for {program}: {e}")),
        }
    };

    let stdout = out_reader.and_then(|h| h.join().ok()).unwrap_or_default();
    let stderr = err_reader.and_then(|h| h.join().ok()).unwrap_or_default();
    Ok(CmdOutput {
        success: status.success(),
        stdout: String::from_utf8_lossy(&stdout).into_owned(),
        stderr: String::from_utf8_lossy(&stderr).into_owned(),
    })
}

pub(crate) fn run_cmd(program: &str, args: &[&str], timeout: Duration) -> Result<CmdOutput, String> {
    run_cmd_env(program, args, &[], timeout)
}

pub(crate) fn hyprctl(args: &[&str]) -> Result<CmdOutput, String> {
    run_cmd("hyprctl", args, HYPRCTL_TIMEOUT)
}

/// hyprctl exits 0 even for many rejected requests; inspect the reply text.
pub(crate) fn hypr_reply_ok(out: &CmdOutput) -> bool {
    if !out.success {
        return false;
    }
    let text = format!("{}\n{}", out.stdout, out.stderr).to_ascii_lowercase();
    !(text.contains("error")
        || text.contains("invalid")
        || text.contains("unknown request")
        || text.contains("failed")
        || text.contains("couldn't")
        || text.contains("not found"))
}

pub(crate) fn command_exists(program: &str) -> bool {
    if program.contains('/') {
        return Path::new(program).exists();
    }
    env::var_os("PATH")
        .map(|paths| env::split_paths(&paths).any(|dir| dir.join(program).is_file()))
        .unwrap_or(false)
}

/// Spawn a long-lived child in its own process group (so a terminal hangup
/// or Ctrl-C aimed at a CLI invocation doesn't take it down), and reap it
/// from a detached thread so it never lingers as a zombie in the daemon.
pub(crate) fn spawn_detached(program: &str, args: &[&str], envs: &[(&str, &str)]) -> Result<(), String> {
    let mut cmd = Command::new(program);
    cmd.args(args)
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .process_group(0);
    for (k, v) in envs {
        cmd.env(k, v);
    }
    let mut child = cmd.spawn().map_err(|e| format!("failed to spawn {program}: {e}"))?;
    thread::spawn(move || {
        let _ = child.wait();
    });
    Ok(())
}

/// Background work (wallpaper sync, audio follow-up) is tracked here so a
/// one-shot CLI invocation can wait for it before exiting — otherwise the
/// process would exit and silently kill the thread halfway through.
pub(crate) fn background_tasks() -> &'static Mutex<Vec<JoinHandle<()>>> {
    static TASKS: OnceLock<Mutex<Vec<JoinHandle<()>>>> = OnceLock::new();
    TASKS.get_or_init(|| Mutex::new(Vec::new()))
}

pub(crate) fn spawn_background<F: FnOnce() + Send + 'static>(f: F) {
    let handle = thread::spawn(f);
    if let Ok(mut tasks) = background_tasks().lock() {
        tasks.retain(|h| !h.is_finished());
        tasks.push(handle);
    }
}

/// Block (bounded) until outstanding background work has finished.
pub fn wait_for_background_tasks(timeout: Duration) {
    let start = Instant::now();
    loop {
        let pending = background_tasks()
            .lock()
            .map(|mut t| {
                t.retain(|h| !h.is_finished());
                t.len()
            })
            .unwrap_or(0);
        if pending == 0 || start.elapsed() > timeout {
            if pending > 0 {
                log_warn(&format!("{pending} background task(s) still running at exit"));
            }
            return;
        }
        thread::sleep(Duration::from_millis(50));
    }
}


// ============================================================
// SYSTEM PROBES: lock screen, lid, DRM
// ============================================================

/// A lock flag whose mtime predates the current boot is a leftover from a
/// crash/power loss (e.g. a persistent /tmp) and must not wedge the engine
/// into "locked" forever.
pub(crate) fn flag_is_stale(path: &Path) -> bool {
    match (file_mtime_secs(path), boot_time_secs()) {
        (Some(mtime), Some(boot)) => mtime + 2 < boot,
        _ => false,
    }
}

pub fn is_locked() -> bool {
    locked_flag_paths().iter().any(|p| {
        if !p.exists() {
            return false;
        }
        if flag_is_stale(p) {
            log_debug(&format!("ignoring stale lock flag {}", p.display()));
            return false;
        }
        true
    })
}


pub(crate) fn read_acpi_lid() -> Option<LidState> {
    let entries = fs::read_dir("/proc/acpi/button/lid").ok()?;
    let mut any_open = false;
    let mut any_closed = false;
    for entry in entries.flatten() {
        if let Ok(s) = fs::read_to_string(entry.path().join("state")) {
            let s = s.to_ascii_lowercase();
            if s.contains("closed") {
                any_closed = true;
            } else if s.contains("open") {
                any_open = true;
            }
        }
    }
    match (any_open, any_closed) {
        // Multiple lid devices disagreeing → be conservative: "open" keeps
        // the internal panel on.
        (true, _) => Some(LidState::Open),
        (false, true) => Some(LidState::Closed),
        _ => None,
    }
}

/// ACPI is authoritative; the cache (fed by Hyprland `switch` events) covers
/// machines without `/proc/acpi/button/lid` (ARM, some newer firmware).
pub fn read_lid_state() -> LidState {
    if let Some(state) = read_acpi_lid() {
        return state;
    }
    match fs::read_to_string(lid_cache_path()).map(|s| s.trim().to_string()) {
        Ok(s) if s == "closed" => LidState::Closed,
        Ok(s) if s == "open" => LidState::Open,
        _ => LidState::Absent,
    }
}

pub(crate) fn cache_lid_state(closed: bool) {
    let _ = write_atomic(&lid_cache_path(), if closed { b"closed" } else { b"open" });
}


pub(crate) fn read_drm_connectors() -> HashMap<String, DrmConnector> {
    let mut map = HashMap::new();
    let Ok(entries) = fs::read_dir("/sys/class/drm") else {
        return map;
    };
    for entry in entries.flatten() {
        let fname = entry.file_name().to_string_lossy().to_string();
        // Only connector nodes: "cardN-<connector>".
        let Some(rest) = fname.strip_prefix("card") else { continue };
        let Some((_, connector)) = rest.split_once('-') else { continue };
        if connector_kind(connector) == ConnectorKind::Writeback {
            continue;
        }
        let path = entry.path();
        let status = match fs::read_to_string(path.join("status")).map(|s| s.trim().to_string()) {
            Ok(s) if s == "connected" => DrmStatus::Connected,
            Ok(s) if s == "disconnected" => DrmStatus::Disconnected,
            _ => DrmStatus::Unknown,
        };
        let dpms_on = fs::read_to_string(path.join("dpms")).ok().map(|s| s.trim() == "On");
        // Multi-GPU: if any card reports the connector connected, it is.
        let e = map.entry(connector.to_string()).or_insert(DrmConnector { status, dpms_on });
        if status == DrmStatus::Connected {
            e.status = status;
            e.dpms_on = dpms_on;
        }
    }
    map
}

pub(crate) fn drm_status_in(map: &HashMap<String, DrmConnector>, name: &str) -> DrmStatus {
    map.get(name).map(|c| c.status).unwrap_or(DrmStatus::Unknown)
}

pub fn count_physical_drm_connected() -> usize {
    read_drm_connectors().values().filter(|c| c.status == DrmStatus::Connected).count()
}

pub fn is_monitor_physically_connected(name: &str) -> bool {
    drm_status_in(&read_drm_connectors(), name) == DrmStatus::Connected
}


// ============================================================
// HYPRLAND QUERIES
// ============================================================

pub(crate) fn run_hyprctl_monitors(args: &[&str]) -> Result<Vec<HyprMonitor>, String> {
    let out = hyprctl(args)?;
    if !out.success {
        return Err(format!("hyprctl {} failed: {}", args.join(" "), out.stderr.trim()));
    }
    serde_json::from_str(&out.stdout).map_err(|e| format!("failed to parse hyprctl output: {e}"))
}

/// Every monitor Hyprland knows about (including disabled ones), retrying
/// with backoff while Hyprland reports fewer real outputs than the kernel
/// says are physically connected — right after a hotplug the EDID handshake
/// takes a few hundred milliseconds to settle.
pub fn query_all_monitors() -> Result<Vec<HyprMonitor>, String> {
    let physical = count_physical_drm_connected();
    let mut last: Result<Vec<HyprMonitor>, String> = Err("no attempt made".into());
    for attempt in 0..5u64 {
        last = run_hyprctl_monitors(&["monitors", "all", "-j"]);
        if let Ok(monitors) = &last {
            let real = monitors.iter().filter(|m| connector_kind(&m.name).manageable()).count();
            if real >= physical || physical == 0 {
                return last;
            }
            log_debug(&format!(
                "hyprctl reports {real} output(s) but DRM has {physical} connected — retrying ({}/5)",
                attempt + 1
            ));
        }
        thread::sleep(Duration::from_millis(80 + attempt * 40));
    }
    last
}

pub fn query_active_monitors() -> Result<Vec<HyprMonitor>, String> {
    run_hyprctl_monitors(&["monitors", "-j"])
}

pub(crate) fn query_workspaces() -> Vec<HyprWorkspaceInfo> {
    hyprctl(&["workspaces", "-j"])
        .ok()
        .filter(|o| o.success)
        .and_then(|o| serde_json::from_str(&o.stdout).ok())
        .unwrap_or_default()
}


// ============================================================
// LOW-LEVEL HYPRLAND DISPATCH
//
// Two backends: the Lua `hl.*` API (Lua configs) and legacy `hyprctl
// keyword monitor` rules (hyprland.conf). Whichever works is remembered for
// the rest of the process so we don't pay for a failing Lua eval every time.
// NEXA_HYPR_BACKEND=lua|legacy forces one.
// ============================================================

pub(crate) const BACKEND_UNKNOWN: u8 = 0;
pub(crate) const BACKEND_LUA: u8 = 1;
pub(crate) const BACKEND_LEGACY: u8 = 2;
static BACKEND: AtomicU8 = AtomicU8::new(BACKEND_UNKNOWN);

pub(crate) fn backend() -> u8 {
    let b = BACKEND.load(Ordering::Relaxed);
    if b != BACKEND_UNKNOWN {
        return b;
    }
    match env::var("NEXA_HYPR_BACKEND").map(|v| v.to_ascii_lowercase()) {
        Ok(v) if v == "legacy" => BACKEND_LEGACY,
        Ok(v) if v == "lua" => BACKEND_LUA,
        _ => BACKEND_UNKNOWN,
    }
}

pub(crate) fn lua_str(s: &str) -> String {
    let mut out = String::with_capacity(s.len() + 2);
    out.push('"');
    for c in s.chars() {
        match c {
            '\\' => out.push_str("\\\\"),
            '"' => out.push_str("\\\""),
            '\n' | '\r' => out.push(' '),
            c => out.push(c),
        }
    }
    out.push('"');
    out
}

pub(crate) fn lua_monitor_call(p: &PlannedMonitor) -> String {
    if !p.enabled {
        return format!("hl.monitor({{ output = {}, disabled = true }})", lua_str(&p.name));
    }
    let mode = if p.mode.is_empty() { "preferred" } else { &p.mode };
    let pos = if p.position.is_empty() { "auto" } else { &p.position };
    let mut s = format!(
        "hl.monitor({{ output = {}, mode = {}, position = {}, scale = {}, disabled = false, mirror = {}",
        lua_str(&p.name),
        lua_str(mode),
        lua_str(pos),
        fmt_num(p.scale, 6),
        lua_str(p.mirror_of.as_deref().unwrap_or(""))
    );
    if p.transform != 0 {
        s.push_str(&format!(", transform = {}", p.transform));
    }
    if let Some(v) = p.vrr {
        s.push_str(&format!(", vrr = {}", u8::from(v)));
    }
    s.push_str(" })");
    s
}

pub(crate) fn legacy_monitor_rule(p: &PlannedMonitor) -> String {
    if !p.enabled {
        return format!("{},disable", p.name);
    }
    let mode = if p.mode.is_empty() { "preferred" } else { &p.mode };
    let pos = if p.position.is_empty() { "auto" } else { &p.position };
    let mut rule = format!("{},{mode},{pos},{}", p.name, fmt_num(p.scale, 6));
    if let Some(src) = &p.mirror_of {
        rule.push_str(&format!(",mirror,{src}"));
    }
    if p.transform != 0 {
        rule.push_str(&format!(",transform,{}", p.transform));
    }
    if let Some(v) = p.vrr {
        rule.push_str(&format!(",vrr,{}", u8::from(v)));
    }
    rule
}

pub(crate) fn eval_lua(code: &str) -> bool {
    hyprctl(&["eval", code]).map(|o| hypr_reply_ok(&o)).unwrap_or(false)
}

pub(crate) fn legacy_keyword_batch(rules: &[String]) -> bool {
    if rules.is_empty() {
        return true;
    }
    let batch = rules.iter().map(|r| format!("keyword monitor {r}")).collect::<Vec<_>>().join(" ; ");
    hyprctl(&["--batch", &batch]).map(|o| hypr_reply_ok(&o)).unwrap_or(false)
}

/// Dispatch monitor entries in the given order: one batched Lua eval →
/// one batched legacy `--batch` → per-output fallback.
pub(crate) fn dispatch_monitors(entries: &[&PlannedMonitor]) -> Result<(), String> {
    if entries.is_empty() {
        return Ok(());
    }
    log_debug(&format!("dispatch: {}", entries.iter().map(|p| legacy_monitor_rule(p)).collect::<Vec<_>>().join(" | ")));
    let b = backend();
    if b != BACKEND_LEGACY {
        let lua = entries.iter().map(|p| lua_monitor_call(p)).collect::<Vec<_>>().join("; ");
        if eval_lua(&lua) {
            BACKEND.store(BACKEND_LUA, Ordering::Relaxed);
            return Ok(());
        }
        log_debug("batched Lua monitor transaction failed; trying legacy batch");
    }
    let rules: Vec<String> = entries.iter().map(|p| legacy_monitor_rule(p)).collect();
    if legacy_keyword_batch(&rules) {
        if b == BACKEND_UNKNOWN {
            BACKEND.store(BACKEND_LEGACY, Ordering::Relaxed);
        }
        return Ok(());
    }
    log_warn("batched monitor transaction failed; falling back to per-output dispatch");
    let mut failures = Vec::new();
    for p in entries {
        let ok = (b != BACKEND_LEGACY && eval_lua(&lua_monitor_call(p))) || legacy_keyword_batch(&[legacy_monitor_rule(p)]);
        if !ok {
            log_error(&format!("failed to apply {}", legacy_monitor_rule(p)));
            failures.push(p.name.clone());
        }
    }
    if failures.len() == entries.len() {
        Err(format!("Hyprland rejected every monitor rule ({})", failures.join(", ")))
    } else {
        Ok(())
    }
}

/// Run a dispatcher via Lua when available, otherwise `hyprctl dispatch`.
pub(crate) fn hypr_dispatch(lua: Option<String>, legacy: &[&str]) -> bool {
    if backend() != BACKEND_LEGACY {
        if let Some(code) = lua {
            if eval_lua(&code) {
                return true;
            }
        }
    }
    let mut args = vec!["dispatch"];
    args.extend_from_slice(legacy);
    hyprctl(&args).map(|o| hypr_reply_ok(&o)).unwrap_or(false)
}

pub fn focus_monitor(name: &str) {
    if !valid_output_name(name) {
        return;
    }
    let lua = format!("hl.dispatch(hl.dsp.focus({{ monitor = {} }}))", lua_str(name));
    if !hypr_dispatch(Some(lua), &["focusmonitor", name]) {
        log_debug(&format!("could not focus {name}"));
    }
}

pub(crate) fn move_workspace(ws_ref: &str, target: &str) -> bool {
    let lua_ws = ws_ref.parse::<i64>().map(|id| id.to_string()).unwrap_or_else(|_| lua_str(ws_ref));
    let lua = format!("hl.dispatch(hl.dsp.workspace.move({{ workspace = {lua_ws}, monitor = {} }}))", lua_str(target));
    hypr_dispatch(Some(lua), &["moveworkspacetomonitor", ws_ref, target])
}

pub(crate) fn select_workspace(id: i64) {
    let id = id.to_string();
    let _ = hypr_dispatch(None, &["workspace", &id]);
}

/// Legacy public API: apply one output directly (no lock, no guard).
pub fn apply_monitor_config(output: &str, mode: &str, pos: &str, scale: f64, disabled: bool, mirror: Option<&str>) -> Result<(), String> {
    if !valid_output_name(output) {
        return Err(format!("invalid output name '{output}'"));
    }
    let p = if disabled {
        PlannedMonitor::disabled(output)
    } else {
        PlannedMonitor {
            name: output.to_string(),
            enabled: true,
            mode: mode.to_string(),
            position: pos.to_string(),
            scale: if scale > 0.0 { scale } else { 1.0 },
            transform: 0,
            mirror_of: mirror.filter(|m| !m.is_empty()).map(str::to_string),
            vrr: None,
            pixel_size: (0, 0),
        }
    };
    dispatch_monitors(&[&p])
}


// ============================================================
// WALLPAPER DAEMON (awww) SYNCHRONISATION
//
// awww-daemon binds to the outputs that exist when it starts; outputs that
// appear later (or come back from a broken mirror buffer) stay black. Rules:
// * never touch it while locked (the lock surface owns every output; the
//   pending marker replays this after unlock);
// * only restart it when it is actually unhealthy (not running, not
//   answering, or not covering every active output) or when forced;
// * spawn it *directly* with WAYLAND_DISPLAY / XDG_RUNTIME_DIR, never
//   through a shell script that may lack the session environment;
// * purge stale sockets only once no daemon is running;
// * coalesce bursts: a newer request supersedes an older one.
// ============================================================

static WALLPAPER_GENERATION: AtomicU64 = AtomicU64::new(0);

pub(crate) fn wallpaper_superseded(gen_id: u64) -> bool {
    WALLPAPER_GENERATION.load(Ordering::SeqCst) != gen_id
}

/// Queue a wallpaper sync in the background (tracked, so CLI invocations
/// wait for it before exiting).
pub fn schedule_wallpaper_sync(force: bool) {
    if is_locked() {
        log_debug("wallpaper sync skipped while locked (deferred)");
        mark_restart_pending("wallpaper sync while locked", None);
        return;
    }
    if !command_exists("awww-daemon") && !command_exists("awww") {
        log_debug("awww not installed; skipping wallpaper sync");
        return;
    }
    let gen_id = WALLPAPER_GENERATION.fetch_add(1, Ordering::SeqCst) + 1;
    spawn_background(move || {
        // Let the compositor finish configuring outputs (and let a burst of
        // requests collapse into the last one).
        thread::sleep(Duration::from_millis(300));
        if wallpaper_superseded(gen_id) {
            return;
        }
        sync_wallpaper(force, gen_id);
    });
}

/// Legacy-friendly name used after any layout transition.
pub fn sync_post_transition() {
    schedule_wallpaper_sync(false);
}

pub(crate) fn active_output_names() -> Vec<String> {
    query_active_monitors()
        .unwrap_or_default()
        .into_iter()
        .filter(|m| !m.disabled && m.width > 0 && connector_kind(&m.name).manageable())
        .map(|m| m.name)
        .collect()
}

pub(crate) fn awww_daemon_running() -> bool {
    run_cmd("pgrep", &["-x", "awww-daemon"], Duration::from_secs(2)).map(|o| o.success).unwrap_or(false)
}

pub(crate) fn json_contains_string(v: &Value, needle: &str) -> bool {
    match v {
        Value::String(s) => s == needle || s.split(|c: char| c == ':' || c.is_whitespace() || c == ',').any(|t| t == needle),
        Value::Array(a) => a.iter().any(|x| json_contains_string(x, needle)),
        Value::Object(o) => o.iter().any(|(k, x)| k == needle || json_contains_string(x, needle)),
        _ => false,
    }
}

pub(crate) fn is_video_wallpaper() -> bool {
    let conf_path = nexa_config_dir().join("config").join("wallpaper.conf");
    if let Ok(content) = fs::read_to_string(&conf_path) {
        for line in content.lines() {
            let line = line.trim();
            if let Some(rest) = line.strip_prefix("WALLPAPER_TYPE=") {
                let val = rest.trim_matches('"').trim_matches('\'').to_lowercase();
                return val == "video";
            }
        }
    }
    false
}

pub(crate) fn mpvpaper_running() -> bool {
    run_cmd("pgrep", &["-x", "mpvpaper"], Duration::from_secs(2)).map(|o| o.success).unwrap_or(false)
}

/// Is the daemon running, answering, and bound to every active output?
pub(crate) fn wallpaper_healthy(outputs: &[String]) -> bool {
    if is_video_wallpaper() {
        return mpvpaper_running();
    }
    if !awww_daemon_running() {
        return false;
    }
    if let Ok(o) = run_cmd("awww", &["query", "-j"], Duration::from_secs(3)) {
        if o.success {
            if let Ok(v) = serde_json::from_str::<Value>(&o.stdout) {
                return outputs.iter().all(|n| json_contains_string(&v, n));
            }
        }
    }
    // Older awww without -j: plain text, one output per line ("DP-1: …").
    match run_cmd("awww", &["query"], Duration::from_secs(3)) {
        Ok(o) if o.success => outputs.iter().all(|n| o.stdout.lines().any(|l| l.trim_start().starts_with(n.as_str()) || l.contains(&format!(" {n}:")))),
        _ => false,
    }
}

pub(crate) fn wayland_display() -> Option<String> {
    if let Ok(w) = env::var("WAYLAND_DISPLAY") {
        if !w.is_empty() {
            return Some(w);
        }
    }
    let mut sockets: Vec<String> = fs::read_dir(runtime_dir())
        .ok()?
        .flatten()
        .map(|e| e.file_name().to_string_lossy().to_string())
        .filter(|n| n.starts_with("wayland-") && !n.ends_with(".lock"))
        .collect();
    sockets.sort();
    sockets.into_iter().next()
}

pub(crate) fn purge_awww_sockets() {
    let dir = runtime_dir();
    let Ok(entries) = fs::read_dir(&dir) else { return };
    for e in entries.flatten() {
        let n = e.file_name().to_string_lossy().to_string();
        if n.contains("awww") && n.ends_with(".sock") {
            log_debug(&format!("removing stale socket {n}"));
            let _ = fs::remove_file(e.path());
        }
    }
}

pub(crate) fn wait_until(timeout: Duration, mut cond: impl FnMut() -> bool) -> bool {
    let start = Instant::now();
    while start.elapsed() < timeout {
        if cond() {
            return true;
        }
        thread::sleep(Duration::from_millis(100));
    }
    cond()
}

pub(crate) fn restart_awww_daemon() -> Result<(), String> {
    if is_locked() {
        return Err("locked".into());
    }
    if awww_daemon_running() {
        let _ = run_cmd("awww", &["kill"], Duration::from_secs(2));
        if !wait_until(Duration::from_millis(1000), || !awww_daemon_running()) {
            let _ = run_cmd("pkill", &["-x", "awww-daemon"], Duration::from_secs(2));
            if !wait_until(Duration::from_millis(800), || !awww_daemon_running()) {
                let _ = run_cmd("pkill", &["-9", "-x", "awww-daemon"], Duration::from_secs(2));
                wait_until(Duration::from_millis(500), || !awww_daemon_running());
            }
        }
    }
    if awww_daemon_running() {
        return Err("could not stop the old awww-daemon".into());
    }
    purge_awww_sockets();
    let runtime = runtime_dir().to_string_lossy().to_string();
    let mut envs: Vec<(&str, String)> = vec![("XDG_RUNTIME_DIR", runtime)];
    if let Some(w) = wayland_display() {
        envs.push(("WAYLAND_DISPLAY", w));
    }
    let env_refs: Vec<(&str, &str)> = envs.iter().map(|(k, v)| (*k, v.as_str())).collect();
    spawn_detached("awww-daemon", &[], &env_refs)?;
    // Ready once it answers queries.
    if !wait_until(Duration::from_secs(3), || run_cmd("awww", &["query"], Duration::from_secs(1)).map(|o| o.success).unwrap_or(false)) {
        return Err("awww-daemon did not come up".into());
    }
    Ok(())
}

pub(crate) fn restore_wallpaper_images() {
    let cfg = load_config();
    let script = cfg.wallpaper_script_path();
    if script.is_file() {
        let s = script.to_string_lossy().to_string();
        match run_cmd("bash", &[&s], Duration::from_secs(15)) {
            Ok(o) if o.success => return,
            Ok(o) => log_warn(&format!("wallpaper script failed: {}", o.stderr.trim())),
            Err(e) => log_warn(&format!("wallpaper script: {e}")),
        }
    }
    let _ = run_cmd("awww", &["restore"], Duration::from_secs(10));
}

pub(crate) fn sync_wallpaper(force: bool, gen_id: u64) {
    let outputs = active_output_names();
    if outputs.is_empty() {
        return;
    }
    let is_video = is_video_wallpaper();
    let mut need_restart = force || !wallpaper_healthy(&outputs);
    let mut delay = Duration::from_millis(300);
    for attempt in 1..=WALLPAPER_RETRIES {
        if is_locked() {
            mark_restart_pending("wallpaper sync interrupted by lock", None);
            return;
        }
        if wallpaper_superseded(gen_id) {
            return;
        }
        if need_restart {
            if is_video {
                log_info(&format!("syncing video wallpaper for {} (attempt {attempt})", outputs.join(", ")));
            } else {
                log_info(&format!("restarting awww-daemon for {} (attempt {attempt})", outputs.join(", ")));
                if let Err(e) = restart_awww_daemon() {
                    log_warn(&format!("awww-daemon restart failed: {e}"));
                    thread::sleep(delay);
                    delay *= 2;
                    continue;
                }
            }
        }
        restore_wallpaper_images();
        let outputs = active_output_names();
        if wallpaper_healthy(&outputs) {
            log_debug("wallpaper in sync");
            return;
        }
        need_restart = true;
        thread::sleep(delay);
        delay *= 2;
    }
    log_warn("wallpaper daemon still unhealthy after retries");
}


pub(crate) fn sink_is_display(text: &str) -> bool {
    let t = text.to_ascii_lowercase();
    t.contains("hdmi") || t.contains("displayport") || t.contains("-dp") || t.contains("dp-") || t.contains("iec958-stereo-hdmi")
}

pub(crate) fn list_audio_sinks() -> Vec<AudioSink> {
    if let Ok(o) = run_cmd("pactl", &["-f", "json", "list", "sinks"], Duration::from_secs(3)) {
        if o.success {
            if let Ok(Value::Array(sinks)) = serde_json::from_str::<Value>(&o.stdout) {
                return sinks
                    .iter()
                    .map(|s| {
                        let name = s.get("name").and_then(Value::as_str).unwrap_or("").to_string();
                        let description = s.get("description").and_then(Value::as_str).unwrap_or("").to_string();
                        let active_port = s.get("active_port").and_then(Value::as_str).unwrap_or("");
                        let ports = s.get("ports").and_then(Value::as_array).cloned().unwrap_or_default();
                        let port = ports.iter().find(|p| p.get("name").and_then(Value::as_str) == Some(active_port));
                        let available = port
                            .and_then(|p| p.get("availability").and_then(Value::as_str))
                            .map(|a| !a.contains("not available"))
                            .unwrap_or(true);
                        let is_display = sink_is_display(&name) || sink_is_display(&description) || sink_is_display(active_port);
                        AudioSink { name, description, is_display, available }
                    })
                    .filter(|s| !s.name.is_empty())
                    .collect();
            }
        }
    }
    run_cmd("pactl", &["list", "short", "sinks"], Duration::from_secs(3))
        .ok()
        .filter(|o| o.success)
        .map(|o| {
            o.stdout
                .lines()
                .filter_map(|l| l.split('\t').nth(1).map(str::to_string))
                .map(|name| AudioSink { is_display: sink_is_display(&name), description: name.clone(), name, available: true })
                .collect()
        })
        .unwrap_or_default()
}

pub(crate) fn default_sink() -> Option<String> {
    run_cmd("pactl", &["get-default-sink"], Duration::from_secs(2))
        .ok()
        .filter(|o| o.success)
        .map(|o| o.stdout.trim().to_string())
        .filter(|s| !s.is_empty())
}

pub(crate) fn notify_user(summary: &str, body: &str) {
    if command_exists("notify-send") {
        let _ = spawn_detached("notify-send", &["-a", "NEXA Display", "-i", "video-display", summary, body], &[]);
    }
}

/// Called by the daemon after a hotplug has been applied.
pub(crate) fn handle_audio_after_hotplug(added: Vec<String>, removed: Vec<String>, cfg: &MonitorsConfig) {
    let policy = cfg.audio_policy.to_ascii_lowercase();
    if policy == "off" || (added.is_empty() && removed.is_empty()) || !command_exists("pactl") {
        return;
    }
    spawn_background(move || {
        thread::sleep(AUDIO_SETTLE);
        if is_locked() {
            return;
        }
        let sinks = list_audio_sinks();
        let current = default_sink();
        let current_sink = current.as_ref().and_then(|c| sinks.iter().find(|s| &s.name == c));

        // The default vanished or became unavailable (monitor unplugged).
        let default_gone = match (&current, current_sink) {
            (None, _) => true,
            (Some(_), None) => true,
            (Some(_), Some(s)) => s.is_display && !s.available,
        };
        if !removed.is_empty() && default_gone {
            if let Some(fallback) = sinks.iter().find(|s| !s.is_display && s.available).or_else(|| sinks.iter().find(|s| s.available)) {
                if run_cmd("pactl", &["set-default-sink", &fallback.name], Duration::from_secs(2)).map(|o| o.success).unwrap_or(false) {
                    log_info(&format!("audio: display sink gone, switched to {}", fallback.description));
                    notify_user("Audio output changed", &format!("Now playing through {}", fallback.description));
                }
            }
            return;
        }

        if !added.is_empty() {
            let candidate = sinks.iter().find(|s| s.is_display && s.available && Some(&s.name) != current.as_ref());
            if let Some(sink) = candidate {
                if policy == "auto" {
                    if run_cmd("pactl", &["set-default-sink", &sink.name], Duration::from_secs(2)).map(|o| o.success).unwrap_or(false) {
                        log_info(&format!("audio: switched default sink to {}", sink.description));
                        notify_user("Audio output changed", &format!("Now playing through {}", sink.description));
                    }
                } else {
                    notify_user("Display audio available", &format!("{} can play sound. Switch outputs in Sound settings.", sink.description));
                }
            }
        }
    });
}


pub fn daemon_running() -> bool {
    fs::read_to_string(daemon_pid_path())
        .ok()
        .and_then(|s| s.trim().parse::<u32>().ok())
        .map(|pid| pid_alive(pid) && DaemonGuard::looks_like_us(pid))
        .unwrap_or(false)
}

/// Locate socket2. Prefers `$HYPRLAND_INSTANCE_SIGNATURE`; if that socket is
/// gone (Hyprland restarted, or the daemon was started from a stale
/// environment), falls back to the newest live instance and points all
/// later hyprctl calls at it.
pub fn hyprland_socket2_path() -> Result<PathBuf, String> {
    let base = runtime_dir().join("hypr");
    if let Some(sig) = current_hypr_signature() {
        let sock = base.join(&sig).join(".socket2.sock");
        if sock.exists() {
            return Ok(sock);
        }
    }
    let mut candidates: Vec<(u64, String, PathBuf)> = fs::read_dir(&base)
        .map_err(|e| format!("cannot read {}: {e}", base.display()))?
        .flatten()
        .filter_map(|e| {
            let sock = e.path().join(".socket2.sock");
            if !sock.exists() {
                return None;
            }
            let mtime = file_mtime_secs(&e.path()).unwrap_or(0);
            Some((mtime, e.file_name().to_string_lossy().to_string(), sock))
        })
        .collect();
    candidates.sort_by(|a, b| b.0.cmp(&a.0));
    let (_, sig, sock) = candidates.into_iter().next().ok_or_else(|| format!("no Hyprland socket2 under {}", base.display()))?;
    if current_hypr_signature().as_deref() != Some(sig.as_str()) {
        log_info(&format!("using Hyprland instance {sig}"));
        if let Ok(mut g) = hypr_signature_override().lock() {
            *g = Some(sig);
        }
    }
    Ok(sock)
}

/// Parse one socket2 line. v2 events carry `ID,NAME,DESCRIPTION`; the
/// description may itself contain commas, so only the second field is used.
pub fn parse_event(line: &str) -> Option<HyprEvent> {
    let (ev, data) = line.trim_end_matches(['\r', '\n']).split_once(">>")?;
    let second_field = |d: &str| -> String {
        let mut it = d.splitn(3, ',');
        let first = it.next().unwrap_or("").trim().to_string();
        match it.next() {
            Some(name) if !name.trim().is_empty() => name.trim().to_string(),
            _ => first,
        }
    };
    match ev {
        "monitoradded" => Some(HyprEvent::MonitorAdded(data.trim().to_string())).filter(|e| !matches!(e, HyprEvent::MonitorAdded(n) if n.is_empty())),
        "monitoraddedv2" => Some(HyprEvent::MonitorAdded(second_field(data))),
        "monitorremoved" => Some(HyprEvent::MonitorRemoved(data.trim().to_string())).filter(|e| !matches!(e, HyprEvent::MonitorRemoved(n) if n.is_empty())),
        "monitorremovedv2" => Some(HyprEvent::MonitorRemoved(second_field(data))),
        "configreloaded" => Some(HyprEvent::ConfigReloaded),
        "switch" | "lidswitch" | "lid" => {
            let d = data.to_ascii_lowercase();
            if !(d.contains("lid") || ev != "switch") {
                return None;
            }
            let state = d.rsplit([',', ':', ' ']).next().unwrap_or("").trim().to_string();
            match state.as_str() {
                "on" | "1" | "closed" | "close" | "true" => Some(HyprEvent::LidSwitch(true)),
                "off" | "0" | "open" | "opened" | "false" => Some(HyprEvent::LidSwitch(false)),
                _ => None,
            }
        }
        _ => None,
    }
}


