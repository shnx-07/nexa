//! # NEXA Display Engine (`nexad display`)
//!
//! Owns the complete monitor lifecycle for NEXA Shell on Hyprland, for any
//! number of displays (1 … N): discovery, identification, layout policy,
//! atomic application, reconciliation, lid/clamshell handling, lock-screen
//! safety, wallpaper-daemon synchronisation, audio-sink follow-up and a
//! debounced hotplug daemon.
//!
//! ## Pipeline for every layout change
//!
//! ```text
//!  event ──► debounce ──► Snapshot::capture ──► policy ──► plan ──► commit_plan ──► reconcile ──► sync
//!  (socket2 /  (400 ms     (hyprctl + DRM +      (profile   (pure,    (lock, guard,    (focus,        (wallpaper,
//!   lid /       quiet)      lid + lock state)     / mode)    testable) 2-phase batch)   workspaces)    audio, OSD)
//! ```
//!
//! ## Design rules that everything below obeys
//!
//! 1. **Identity is hardware, not ports.** Monitors are keyed by
//!    `make_model_serial` (see [`HyprMonitor::hardware_key`]); the setup
//!    fingerprint is the sorted set of those keys. Identical panels without
//!    serials are disambiguated deterministically (`key#2`, `key#3`).
//! 2. **Never zero screens.** Every transaction is projected before it is
//!    dispatched; enables are verified *live* before anything is disabled.
//! 3. **Never destructive while locked.** `ext-session-lock-v1` requires a
//!    lock surface on every output. While locked we only *add* outputs,
//!    never disable, mirror or rearrange, never touch the wallpaper daemon or
//!    Quickshell, and we leave a `restart-pending` marker for after unlock.
//! 4. **Plans are pure.** Layout planners take a [`Snapshot`] and return a
//!    `Vec<PlannedMonitor>`; only `commit_plan` talks to Hyprland. This is what
//!    makes the logic unit-testable without a compositor.
//! 5. **Idempotent.** A plan that matches the live state is a no-op, so
//!    redundant events (our own transactions echoing back, resume, config
//!    reloads) never cause flicker or wallpaper restarts.
//! 6. **Logical geometry.** Positions are computed in logical pixels
//!    (resolution ÷ scale, rotated by transform), so scaled and rotated
//!    monitors never overlap or leave gaps.
//!
//! ## Files
//!
//! | Path | Purpose |
//! |---|---|
//! | `$XDG_CONFIG_HOME/nexa/config/monitors.json` | policies, per-monitor prefs, profiles |
//! | `$XDG_RUNTIME_DIR/nexa-display.lock` | cross-process transaction lock (PID) |
//! | `$XDG_RUNTIME_DIR/nexa/display-state.json` | live mode / profile / mirror state (QML can watch it) |
//! | `$XDG_RUNTIME_DIR/nexa-display-mode` | legacy one-word mode file (kept for older QML) |
//! | `$XDG_RUNTIME_DIR/nexa/locked`, `/tmp/nexa-locked` | lock-screen flag (written by the lock screen) |
//! | `$XDG_RUNTIME_DIR/nexa/restart-pending`, `/tmp/nexa-restart-pending` | deferred work for after unlock |
//! | `$XDG_RUNTIME_DIR/nexa/workspace-homes.json` | where migrated workspaces should return to |
//! | `$XDG_RUNTIME_DIR/nexa/display-txn.json` | last transaction (daemon ignores its own echoes) |
//! | `$XDG_RUNTIME_DIR/nexa/display-daemon.pid` | single-instance guard for the daemon |
//!
//! ## Integration
//!
//! `main.rs` only needs `std::process::exit(display::run_cli(&args))` for
//! the `display` subcommand (see [`run_cli`] for commands and exit codes:
//! 0 ok, 1 error, 2 usage, 3 deferred while locked). The previous public
//! functions (`apply_projection`, `auto_resolve_setup`, `enable_monitor`,
//! `print_info`, …) keep their signatures for existing callers.
//!
//! The lock screen should call `nexad display unlocked` right after it
//! removes the lock flag; the daemon also replays pending work on its own
//! after a short grace period if nobody does.
//!
//! Set `NEXA_DISPLAY_DEBUG=1` for verbose logs (stderr), and
//! `NEXA_HYPR_BACKEND=lua|legacy` to pin the monitor-rule backend.

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

// ============================================================
// TUNABLES
// ============================================================

/// How long a transaction waits for the cross-process display lock.
const LOCK_TIMEOUT: Duration = Duration::from_secs(5);
/// A lock older than this is considered wedged even if its PID is alive
/// (protects against PID reuse after a crash).
const LOCK_STALE_AGE: Duration = Duration::from_secs(30);
/// Hotplug events are coalesced until the bus has been quiet this long.
const HOTPLUG_QUIET_WINDOW: Duration = Duration::from_millis(400);
/// …but a burst is never held longer than this (a flapping KVM or cable
/// that never goes quiet must still be handled).
const HOTPLUG_MAX_BURST: Duration = Duration::from_secs(3);
/// DRM buses need time to re-train links after resume.
const RESUME_SETTLE: Duration = Duration::from_millis(600);
/// If CLOCK_BOOTTIME advanced this much more than CLOCK_MONOTONIC, we slept.
const RESUME_JUMP_THRESHOLD: f64 = 4.0;
/// Events for outputs we touched ourselves within this window are echoes.
const SELF_EVENT_WINDOW: Duration = Duration::from_millis(2500);
/// Every hyprctl invocation is bounded so a wedged compositor can't hang us.
const HYPRCTL_TIMEOUT: Duration = Duration::from_secs(4);
/// How long phase 1 of a transaction waits for new outputs to come up.
const ENABLE_VERIFY_TIMEOUT: Duration = Duration::from_millis(1800);
/// How long we wait for the post-commit state to converge on the plan.
const CONVERGE_TIMEOUT: Duration = Duration::from_millis(1200);
/// Wallpaper restore retries (with exponential backoff).
const WALLPAPER_RETRIES: u32 = 3;
/// Socket read timeout == daemon tick granularity.
const SOCKET_TICK: Duration = Duration::from_millis(200);
/// Background housekeeping cadences inside the daemon.
const PENDING_CHECK_INTERVAL: Duration = Duration::from_millis(500);
const LID_POLL_INTERVAL: Duration = Duration::from_secs(1);
const RESUME_CHECK_INTERVAL: Duration = Duration::from_secs(1);
const SNAPSHOT_INTERVAL: Duration = Duration::from_secs(2);
/// Wait before looking at audio sinks (ELD / ACP profiles appear late).
const AUDIO_SETTLE: Duration = Duration::from_millis(1500);
/// Workspace-home records older than this are forgotten.
const WORKSPACE_HOME_TTL_MS: u64 = 24 * 60 * 60 * 1000;
/// Tolerance (logical px) when deciding whether two monitors touch/overlap.
const GEOMETRY_TOLERANCE: i32 = 2;
/// Fallback geometry when a monitor reports no usable resolution.
const FALLBACK_RES: (i32, i32) = (1920, 1080);
/// Current on-disk schema version of monitors.json.
const CONFIG_VERSION: u32 = 2;

// ============================================================
// LOGGING
//
// Everything goes to stderr. stdout is reserved for machine-readable output
// (`info`, `profiles`, `--json` results) so QML never has to parse around
// log lines.
// ============================================================

fn debug_enabled() -> bool {
    static DEBUG: OnceLock<bool> = OnceLock::new();
    *DEBUG.get_or_init(|| {
        env::var("NEXA_DISPLAY_DEBUG")
            .map(|v| !v.is_empty() && v != "0")
            .unwrap_or(false)
    })
}

fn log_line(level: &str, msg: &str) {
    let _ = writeln!(std::io::stderr(), "[nexa-display] {level}{msg}");
}
fn log_debug(msg: &str) {
    if debug_enabled() {
        log_line("DEBUG: ", msg);
    }
}
fn log_info(msg: &str) {
    log_line("", msg);
}
fn log_warn(msg: &str) {
    log_line("WARN: ", msg);
}
fn log_error(msg: &str) {
    log_line("ERROR: ", msg);
}

// ============================================================
// TIME HELPERS
// ============================================================

fn now_ms() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_millis() as u64)
        .unwrap_or(0)
}

/// Seconds since boot *including* time spent suspended (CLOCK_BOOTTIME).
fn uptime_secs() -> Option<f64> {
    fs::read_to_string("/proc/uptime")
        .ok()?
        .split_whitespace()
        .next()?
        .parse()
        .ok()
}

/// Wall-clock time of the last boot, from `/proc/stat` `btime`.
fn boot_time_secs() -> Option<u64> {
    fs::read_to_string("/proc/stat")
        .ok()?
        .lines()
        .find_map(|l| l.strip_prefix("btime ").and_then(|v| v.trim().parse().ok()))
}

fn file_mtime_secs(path: &Path) -> Option<u64> {
    fs::metadata(path)
        .ok()?
        .modified()
        .ok()?
        .duration_since(UNIX_EPOCH)
        .ok()
        .map(|d| d.as_secs())
}

// ============================================================
// PATHS
// ============================================================

fn current_uid() -> u32 {
    fs::read_to_string("/proc/self/status")
        .ok()
        .and_then(|s| {
            s.lines()
                .find_map(|l| l.strip_prefix("Uid:"))
                .and_then(|v| v.split_whitespace().next().and_then(|u| u.parse().ok()))
        })
        .unwrap_or(1000)
}

fn runtime_dir() -> PathBuf {
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

fn nexa_runtime_dir() -> PathBuf {
    let dir = runtime_dir().join("nexa");
    let _ = fs::create_dir_all(&dir);
    dir
}

fn home_dir() -> PathBuf {
    PathBuf::from(env::var("HOME").unwrap_or_else(|_| ".".to_string()))
}

fn nexa_config_dir() -> PathBuf {
    let base = env::var("XDG_CONFIG_HOME")
        .ok()
        .filter(|s| !s.is_empty())
        .map(PathBuf::from)
        .unwrap_or_else(|| home_dir().join(".config"));
    base.join("nexa")
}

fn config_path() -> PathBuf {
    nexa_config_dir().join("config").join("monitors.json")
}

fn locked_flag_paths() -> Vec<PathBuf> {
    vec![runtime_dir().join("nexa").join("locked"), PathBuf::from("/tmp/nexa-locked")]
}

fn restart_pending_paths() -> Vec<PathBuf> {
    vec![
        runtime_dir().join("nexa").join("restart-pending"),
        PathBuf::from("/tmp/nexa-restart-pending"),
    ]
}

fn legacy_mode_state_path() -> PathBuf {
    runtime_dir().join("nexa-display-mode")
}
fn runtime_state_path() -> PathBuf {
    nexa_runtime_dir().join("display-state.json")
}
fn workspace_homes_path() -> PathBuf {
    nexa_runtime_dir().join("workspace-homes.json")
}
fn txn_marker_path() -> PathBuf {
    nexa_runtime_dir().join("display-txn.json")
}
fn lid_cache_path() -> PathBuf {
    nexa_runtime_dir().join("lid-state")
}
fn daemon_pid_path() -> PathBuf {
    nexa_runtime_dir().join("display-daemon.pid")
}
fn lock_path() -> PathBuf {
    runtime_dir().join("nexa-display.lock")
}

/// Write via temp file + rename so readers (QML, a second nexad) never see a
/// truncated file, and a crash mid-write never corrupts the previous copy.
/// The temp name is unique per process/time so concurrent writers can't
/// clobber each other's temp file.
fn write_atomic(path: &Path, contents: &[u8]) -> Result<(), String> {
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

fn read_json_file<T: for<'de> Deserialize<'de>>(path: &Path) -> Option<T> {
    fs::read_to_string(path).ok().and_then(|s| serde_json::from_str(&s).ok())
}

fn write_json_file<T: Serialize>(path: &Path, value: &T) -> Result<(), String> {
    let json = serde_json::to_vec_pretty(value).map_err(|e| format!("serialization error: {e}"))?;
    write_atomic(path, &json)
}

// ============================================================
// PROCESS RUNNER
//
// Every external command goes through here: bounded by a timeout (a wedged
// Hyprland must never hang the daemon), stdin detached, output captured
// concurrently so a chatty child can't deadlock on a full pipe.
// ============================================================

#[derive(Debug, Clone, Default)]
struct CmdOutput {
    success: bool,
    stdout: String,
    stderr: String,
}

/// If the daemon discovers that Hyprland restarted under a new instance
/// signature, later hyprctl calls are pointed at it explicitly. We never
/// mutate our own environment (`set_var` is unsound in multithreaded code).
fn hypr_signature_override() -> &'static Mutex<Option<String>> {
    static SIG: OnceLock<Mutex<Option<String>>> = OnceLock::new();
    SIG.get_or_init(|| Mutex::new(None))
}

fn current_hypr_signature() -> Option<String> {
    hypr_signature_override()
        .lock()
        .ok()
        .and_then(|g| g.clone())
        .or_else(|| env::var("HYPRLAND_INSTANCE_SIGNATURE").ok().filter(|s| !s.is_empty()))
}

fn build_command(program: &str, args: &[&str]) -> Command {
    let mut cmd = Command::new(program);
    cmd.args(args).stdin(Stdio::null());
    if program == "hyprctl" {
        if let Some(sig) = hypr_signature_override().lock().ok().and_then(|g| g.clone()) {
            cmd.env("HYPRLAND_INSTANCE_SIGNATURE", sig);
        }
    }
    cmd
}

fn run_cmd_env(program: &str, args: &[&str], envs: &[(&str, &str)], timeout: Duration) -> Result<CmdOutput, String> {
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

fn run_cmd(program: &str, args: &[&str], timeout: Duration) -> Result<CmdOutput, String> {
    run_cmd_env(program, args, &[], timeout)
}

fn hyprctl(args: &[&str]) -> Result<CmdOutput, String> {
    run_cmd("hyprctl", args, HYPRCTL_TIMEOUT)
}

/// hyprctl exits 0 even for many rejected requests; inspect the reply text.
fn hypr_reply_ok(out: &CmdOutput) -> bool {
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

fn command_exists(program: &str) -> bool {
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
fn spawn_detached(program: &str, args: &[&str], envs: &[(&str, &str)]) -> Result<(), String> {
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
fn background_tasks() -> &'static Mutex<Vec<JoinHandle<()>>> {
    static TASKS: OnceLock<Mutex<Vec<JoinHandle<()>>>> = OnceLock::new();
    TASKS.get_or_init(|| Mutex::new(Vec::new()))
}

fn spawn_background<F: FnOnce() + Send + 'static>(f: F) {
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
// HYPRLAND DATA MODEL
// ============================================================

/// Accept strings, numbers, booleans or null for fields whose JSON type has
/// drifted between Hyprland versions (`mirrorOf`, `serial`, …).
fn de_lenient_string<'de, D: serde::Deserializer<'de>>(d: D) -> Result<String, D::Error> {
    let v = Value::deserialize(d)?;
    Ok(match v {
        Value::String(s) => s,
        Value::Null => String::new(),
        Value::Number(n) => n.to_string(),
        Value::Bool(b) => b.to_string(),
        other => other.to_string(),
    })
}

fn default_one() -> f64 {
    1.0
}
fn default_true() -> bool {
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

    fn current_mode_string(&self) -> Option<String> {
        if self.width > 0 && self.height > 0 {
            Some(format_mode(self.width, self.height, Some(self.refresh_rate)))
        } else {
            None
        }
    }
}

/// Some Hyprland builds append " (PORT)" to the description.
fn strip_port_suffix(desc: &str) -> &str {
    let d = desc.trim();
    if d.ends_with(')') {
        if let Some(idx) = d.rfind(" (") {
            return &d[..idx];
        }
    }
    d
}

fn clean_token(s: &str) -> String {
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
fn serial_is_meaningful(raw: &str) -> bool {
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
fn natural_key(name: &str) -> (String, u64) {
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

fn fingerprint_of_keys<'a, I: IntoIterator<Item = &'a String>>(keys: I) -> String {
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
struct HyprWorkspaceInfo {
    #[serde(default)]
    id: i64,
    #[serde(default, deserialize_with = "de_lenient_string")]
    name: String,
    #[serde(default, deserialize_with = "de_lenient_string")]
    monitor: String,
}

impl HyprWorkspaceInfo {
    /// Stable identifier to use with dispatchers ("3", "special:scratch").
    fn dispatch_ref(&self) -> String {
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

fn default_policy_dual() -> String {
    "external-only".to_string()
}
fn default_policy_multi() -> String {
    "extend".to_string()
}
fn default_lid_close_policy() -> String {
    "external-only".to_string()
}
fn default_lid_open_policy() -> String {
    "extend".to_string()
}
fn default_align() -> String {
    "top".to_string()
}
fn default_grid_columns() -> usize {
    2
}
fn default_audio_policy() -> String {
    "notify".to_string()
}
fn default_osd_policy() -> String {
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
    fn pref(&self, key: &str) -> Option<&MonitorPref> {
        self.monitor_prefs.get(key).or_else(|| self.monitor_prefs.get(base_key(key)))
    }
    fn wallpaper_script_path(&self) -> PathBuf {
        match &self.wallpaper_script {
            Some(p) if p.starts_with("~/") => home_dir().join(&p[2..]),
            Some(p) => PathBuf::from(p),
            None => nexa_config_dir().join("scripts").join("restore-wallpaper.sh"),
        }
    }
}

/// `"Dell_U2720Q#2"` → `"Dell_U2720Q"`.
fn base_key(key: &str) -> &str {
    key.split('#').next().unwrap_or(key)
}

/// Load monitors.json. A file that exists but doesn't parse is backed up
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
/// stays "none" on some versions). QML may watch this file.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
struct RuntimeState {
    #[serde(default)]
    mode: Option<String>,
    #[serde(default)]
    active_profile: Option<String>,
    #[serde(default)]
    fingerprint: Option<String>,
    #[serde(default)]
    mirror_source: Option<String>,
    #[serde(default)]
    mirror_targets: Vec<String>,
    #[serde(default)]
    lid_closed: Option<bool>,
    #[serde(default)]
    updated_ms: u64,
}

fn load_runtime_state() -> RuntimeState {
    let mut state: RuntimeState = read_json_file(&runtime_state_path()).unwrap_or_default();
    if state.mode.is_none() {
        state.mode = fs::read_to_string(legacy_mode_state_path())
            .ok()
            .map(|s| s.trim().to_string())
            .filter(|s| !s.is_empty());
    }
    state
}

fn store_runtime_state(state: &mut RuntimeState) {
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
    fn label(self) -> &'static str {
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
    fn manageable(self) -> bool {
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

fn is_internal_with(cfg: &MonitorsConfig, name: &str) -> bool {
    is_internal_display(name)
        || cfg
            .internal_outputs
            .iter()
            .any(|p| !p.is_empty() && name.to_ascii_uppercase().starts_with(&p.to_ascii_uppercase()))
}

fn is_ignored(cfg: &MonitorsConfig, name: &str, key: &str) -> bool {
    cfg.ignore_outputs.iter().any(|pat| {
        let pat = pat.trim();
        !pat.is_empty() && (pat == key || pat == base_key(key) || name.eq_ignore_ascii_case(pat) || name.to_ascii_uppercase().starts_with(&pat.to_ascii_uppercase()))
    })
}

/// Output names are interpolated into Lua / hyprctl commands; refuse anything
/// that could break out of a string literal or a comma-separated rule.
fn valid_output_name(name: &str) -> bool {
    !name.is_empty() && name.len() <= 64 && name.chars().all(|c| c.is_ascii_alphanumeric() || matches!(c, '-' | '_' | '.'))
}

// ============================================================
// SYSTEM PROBES: lock screen, lid, DRM
// ============================================================

/// A lock flag whose mtime predates the current boot is a leftover from a
/// crash/power loss (e.g. a persistent /tmp) and must not wedge the engine
/// into "locked" forever.
fn flag_is_stale(path: &Path) -> bool {
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

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum LidState {
    Open,
    Closed,
    /// No lid switch (desktop) or unknown.
    Absent,
}

impl LidState {
    fn label(self) -> &'static str {
        match self {
            Self::Open => "open",
            Self::Closed => "closed",
            Self::Absent => "absent",
        }
    }
    fn profile_tag(self) -> Option<String> {
        match self {
            Self::Open => Some("open".into()),
            Self::Closed => Some("closed".into()),
            Self::Absent => None,
        }
    }
}

fn read_acpi_lid() -> Option<LidState> {
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

fn cache_lid_state(closed: bool) {
    let _ = write_atomic(&lid_cache_path(), if closed { b"closed" } else { b"open" });
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum DrmStatus {
    Connected,
    Disconnected,
    Unknown,
}

#[derive(Debug, Clone)]
struct DrmConnector {
    status: DrmStatus,
    dpms_on: Option<bool>,
}

/// `/sys/class/drm/card1-HDMI-A-1/status` → `{"HDMI-A-1": Connected}`.
fn read_drm_connectors() -> HashMap<String, DrmConnector> {
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

fn drm_status_in(map: &HashMap<String, DrmConnector>, name: &str) -> DrmStatus {
    map.get(name).map(|c| c.status).unwrap_or(DrmStatus::Unknown)
}

pub fn count_physical_drm_connected() -> usize {
    read_drm_connectors().values().filter(|c| c.status == DrmStatus::Connected).count()
}

pub fn is_monitor_physically_connected(name: &str) -> bool {
    drm_status_in(&read_drm_connectors(), name) == DrmStatus::Connected
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

struct DisplayLock {
    path: PathBuf,
    owner: bool,
}

impl DisplayLock {
    fn acquire(timeout: Duration) -> Result<Self, String> {
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

    fn reclaim_if_stale(path: &Path) -> bool {
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

fn pid_alive(pid: u32) -> bool {
    Path::new(&format!("/proc/{pid}")).exists()
}

// ============================================================
// HYPRLAND QUERIES
// ============================================================

fn run_hyprctl_monitors(args: &[&str]) -> Result<Vec<HyprMonitor>, String> {
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

fn query_workspaces() -> Vec<HyprWorkspaceInfo> {
    hyprctl(&["workspaces", "-j"])
        .ok()
        .filter(|o| o.success)
        .and_then(|o| serde_json::from_str(&o.stdout).ok())
        .unwrap_or_default()
}

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
    active: HashSet<String>,
    keys: HashMap<String, String>,
    internal: HashSet<String>,
    drm: HashMap<String, DrmConnector>,
    /// Mirror relationships Hyprland fails to report (`mirrorOf` stays
    /// "none" on some versions) but that we know we configured.
    mirror_hints: HashMap<String, String>,
    pub lid: LidState,
    pub locked: bool,
    pub fingerprint: String,
}

impl Snapshot {
    fn capture(cfg: &MonitorsConfig) -> Result<Self, String> {
        let all = query_all_monitors()?;
        let active = query_active_monitors().ok();
        let mut snap = Self::from_parts(all, active, read_drm_connectors(), read_lid_state(), is_locked(), cfg);
        snap.apply_mirror_hints(&load_runtime_state());
        Ok(snap)
    }

    fn apply_mirror_hints(&mut self, rt: &RuntimeState) {
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
    fn capture_settled(cfg: &MonitorsConfig, wait: Duration) -> Result<Self, String> {
        let start = Instant::now();
        loop {
            match Self::capture(cfg) {
                Ok(s) if !s.managed.is_empty() || start.elapsed() >= wait => return Ok(s),
                Err(e) if start.elapsed() >= wait => return Err(e),
                _ => thread::sleep(Duration::from_millis(150)),
            }
        }
    }

    fn from_parts(
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

    fn monitor(&self, name: &str) -> Option<&HyprMonitor> {
        self.managed.iter().find(|m| m.name == name)
    }
    fn key(&self, name: &str) -> String {
        self.keys.get(name).cloned().unwrap_or_else(|| {
            self.all.iter().find(|m| m.name == name).map(|m| m.hardware_key()).unwrap_or_else(|| format!("port_{name}"))
        })
    }
    fn by_key(&self, key: &str) -> Option<&HyprMonitor> {
        self.managed.iter().find(|m| self.keys.get(&m.name).map(|k| k == key).unwrap_or(false))
    }
    fn is_active(&self, name: &str) -> bool {
        self.active.contains(name)
    }
    fn is_internal(&self, name: &str) -> bool {
        self.internal.contains(name)
    }
    fn internals(&self) -> Vec<&HyprMonitor> {
        self.managed.iter().filter(|m| self.is_internal(&m.name)).collect()
    }
    fn externals(&self) -> Vec<&HyprMonitor> {
        self.managed.iter().filter(|m| !self.is_internal(&m.name)).collect()
    }
    fn active_managed(&self) -> Vec<&HyprMonitor> {
        self.managed.iter().filter(|m| self.is_active(&m.name)).collect()
    }
    /// Active outputs that are real screens of their own (not mirrors).
    fn active_standalone(&self) -> Vec<&HyprMonitor> {
        self.active_managed().into_iter().filter(|m| self.mirror_of(&m.name).is_none()).collect()
    }
    fn mirror_of(&self, name: &str) -> Option<String> {
        self.all
            .iter()
            .find(|m| m.name == name)
            .and_then(|m| m.mirror_source().map(str::to_string))
            .or_else(|| self.mirror_hints.get(name).cloned())
    }
    fn drm_status(&self, name: &str) -> DrmStatus {
        drm_status_in(&self.drm, name)
    }
    fn lid_closed(&self) -> bool {
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
struct ModeSpec {
    w: i32,
    h: i32,
    hz: Option<f64>,
}

fn parse_mode(s: &str) -> Option<ModeSpec> {
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

fn format_mode(w: i32, h: i32, hz: Option<f64>) -> String {
    match hz {
        Some(r) if r > 0.0 => format!("{w}x{h}@{}", fmt_num(r, 3)),
        _ => format!("{w}x{h}"),
    }
}

/// Format a float with at most `decimals` places and no trailing zeros.
fn fmt_num(v: f64, decimals: usize) -> String {
    let s = format!("{v:.decimals$}");
    if s.contains('.') {
        s.trim_end_matches('0').trim_end_matches('.').to_string()
    } else {
        s
    }
}

fn is_mode_keyword(s: &str) -> bool {
    matches!(s.to_ascii_lowercase().as_str(), "preferred" | "auto" | "highrr" | "highres" | "maxwidth")
}

fn choose_mode(monitor: &HyprMonitor, requested: &str) -> String {
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
fn target_resolution(monitor: &HyprMonitor, mode: &str) -> (i32, i32) {
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
fn sanitize_scale(px: (i32, i32), requested: f64) -> f64 {
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
fn logical_size(px: (i32, i32), scale: f64, transform: i32) -> (i32, i32) {
    let (w, h) = if transform.rem_euclid(2) == 1 { (px.1, px.0) } else { px };
    let s = if scale > 0.0 { scale } else { 1.0 };
    (((w as f64) / s).round() as i32, ((h as f64) / s).round() as i32)
}

fn parse_pos(s: &str) -> Option<(i32, i32)> {
    let (x, y) = s.trim().split_once('x')?;
    Some((x.trim().parse().ok()?, y.trim().parse().ok()?))
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
struct Rect {
    x: i32,
    y: i32,
    w: i32,
    h: i32,
}

impl Rect {
    fn right(&self) -> i32 {
        self.x + self.w
    }
    fn bottom(&self) -> i32 {
        self.y + self.h
    }
    fn overlaps(&self, o: &Rect) -> bool {
        let ox = self.right().min(o.right()) - self.x.max(o.x);
        let oy = self.bottom().min(o.bottom()) - self.y.max(o.y);
        ox > GEOMETRY_TOLERANCE && oy > GEOMETRY_TOLERANCE
    }
    /// Share an edge segment (so the cursor can cross between them).
    fn touches(&self, o: &Rect) -> bool {
        let t = GEOMETRY_TOLERANCE;
        let y_overlap = self.bottom().min(o.bottom()) - self.y.max(o.y) > t;
        let x_overlap = self.right().min(o.right()) - self.x.max(o.x) > t;
        let horiz = ((self.right() - o.x).abs() <= t || (o.right() - self.x).abs() <= t) && y_overlap;
        let vert = ((self.bottom() - o.y).abs() <= t || (o.bottom() - self.y).abs() <= t) && x_overlap;
        horiz || vert
    }
    fn center2(&self) -> (i64, i64) {
        ((self.x as i64) * 2 + self.w as i64, (self.y as i64) * 2 + self.h as i64)
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum Align {
    Start,
    Center,
    End,
}

fn parse_align(s: &str) -> Align {
    match s.trim().to_ascii_lowercase().as_str() {
        "center" | "centre" | "middle" => Align::Center,
        "bottom" | "end" | "right" => Align::End,
        _ => Align::Start,
    }
}

fn align_offset(container: i32, item: i32, align: Align) -> i32 {
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
    pixel_size: (i32, i32),
}

impl PlannedMonitor {
    fn disabled(name: &str) -> Self {
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
    fn logical(&self) -> (i32, i32) {
        logical_size(self.pixel_size, self.scale, self.transform)
    }
    fn pos(&self) -> Option<(i32, i32)> {
        parse_pos(&self.position)
    }
    fn set_pos(&mut self, x: i32, y: i32) {
        self.position = format!("{x}x{y}");
    }
    fn is_standalone(&self) -> bool {
        self.enabled && self.mirror_of.is_none()
    }
    fn rect(&self) -> Option<Rect> {
        let (x, y) = self.pos()?;
        let (w, h) = self.logical();
        Some(Rect { x, y, w: w.max(1), h: h.max(1) })
    }
}

#[derive(Debug, Clone, Default)]
struct Overrides {
    mode: Option<String>,
    scale: Option<f64>,
    transform: Option<i32>,
    position: Option<String>,
    vrr: Option<bool>,
}

/// Build an enabled plan entry for `m`, layering (highest wins):
/// explicit overrides → remembered per-monitor prefs → current live state
/// → preferred/1.0. The mode is validated and the scale sanitised against
/// the resolution that mode will actually produce.
fn plan_for(snap: &Snapshot, cfg: &MonitorsConfig, m: &HyprMonitor, ov: &Overrides) -> PlannedMonitor {
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
struct Block {
    items: Vec<PlannedMonitor>,
    w: i32,
    h: i32,
}

impl Block {
    fn single(mut p: PlannedMonitor) -> Self {
        let (w, h) = p.logical();
        p.set_pos(0, 0);
        Self { items: vec![p], w, h }
    }
    fn translate(&mut self, dx: i32, dy: i32) {
        for p in &mut self.items {
            if let Some((x, y)) = p.pos() {
                p.set_pos(x + dx, y + dy);
            }
        }
    }
    fn is_empty(&self) -> bool {
        self.items.is_empty()
    }
    /// Left → right; each block aligned vertically within the row.
    fn row(blocks: Vec<Block>, align: Align) -> Self {
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
    fn column(blocks: Vec<Block>, align: Align) -> Self {
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

/// Shift the canvas so its top-left is 0,0. Negative coordinates are legal
/// in Hyprland but confuse XWayland apps and our "primary = 0x0" convention.
fn normalize_origin(plan: &mut [PlannedMonitor]) {
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
fn resolve_auto_positions(plan: &mut [PlannedMonitor]) {
    let mut max_right = plan.iter().filter(|p| p.is_standalone()).filter_map(|p| p.rect()).map(|r| r.right()).max().unwrap_or(0);
    for p in plan.iter_mut() {
        if p.is_standalone() && p.pos().is_none() {
            p.set_pos(max_right, 0);
            max_right += p.logical().0;
        }
    }
}

fn layout_is_sound(rects: &[Rect]) -> bool {
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
fn fix_layout(plan: &mut [PlannedMonitor], align: Align) -> bool {
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

    fn is_extend(&self) -> bool {
        matches!(self, Self::ExtendRight | Self::ExtendLeft | Self::ExtendUp | Self::ExtendDown | Self::ExtendGrid(_))
    }
}

/// The monitor the user wants as primary, if configured and present.
fn configured_primary(snap: &Snapshot, cfg: &MonitorsConfig) -> Option<String> {
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
fn order_monitors<'a>(snap: &Snapshot, cfg: &MonitorsConfig, mut mons: Vec<&'a HyprMonitor>) -> Vec<&'a HyprMonitor> {
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
fn build_projection_plan(mode: &ProjectionMode, snap: &Snapshot, cfg: &MonitorsConfig) -> Result<Vec<PlannedMonitor>, String> {
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
fn append_ghost_cleanup(plan: &mut Vec<PlannedMonitor>, snap: &Snapshot) {
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
fn build_profile_plan(profile: &DisplayProfile, snap: &Snapshot, cfg: &MonitorsConfig) -> Result<Vec<PlannedMonitor>, String> {
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
fn lock_safe_plan(plan: Vec<PlannedMonitor>, snap: &Snapshot) -> Vec<PlannedMonitor> {
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
fn projected_state(plan: &[PlannedMonitor], snap: &Snapshot) -> (HashSet<String>, HashSet<String>) {
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
fn validate_plan(plan: Vec<PlannedMonitor>, snap: &Snapshot, allow_unknown: bool) -> Result<Vec<PlannedMonitor>, String> {
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
fn plan_is_noop(plan: &[PlannedMonitor], snap: &Snapshot) -> bool {
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

// ============================================================
// LOW-LEVEL HYPRLAND DISPATCH
//
// Two backends: the Lua `hl.*` API (Lua configs) and legacy `hyprctl
// keyword monitor` rules (hyprland.conf). Whichever works is remembered for
// the rest of the process so we don't pay for a failing Lua eval every time.
// NEXA_HYPR_BACKEND=lua|legacy forces one.
// ============================================================

const BACKEND_UNKNOWN: u8 = 0;
const BACKEND_LUA: u8 = 1;
const BACKEND_LEGACY: u8 = 2;
static BACKEND: AtomicU8 = AtomicU8::new(BACKEND_UNKNOWN);

fn backend() -> u8 {
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

fn lua_str(s: &str) -> String {
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

fn lua_monitor_call(p: &PlannedMonitor) -> String {
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

fn legacy_monitor_rule(p: &PlannedMonitor) -> String {
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

fn eval_lua(code: &str) -> bool {
    hyprctl(&["eval", code]).map(|o| hypr_reply_ok(&o)).unwrap_or(false)
}

fn legacy_keyword_batch(rules: &[String]) -> bool {
    if rules.is_empty() {
        return true;
    }
    let batch = rules.iter().map(|r| format!("keyword monitor {r}")).collect::<Vec<_>>().join(" ; ");
    hyprctl(&["--batch", &batch]).map(|o| hypr_reply_ok(&o)).unwrap_or(false)
}

/// Dispatch monitor entries in the given order: one batched Lua eval →
/// one batched legacy `--batch` → per-output fallback.
fn dispatch_monitors(entries: &[&PlannedMonitor]) -> Result<(), String> {
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
fn hypr_dispatch(lua: Option<String>, legacy: &[&str]) -> bool {
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

fn move_workspace(ws_ref: &str, target: &str) -> bool {
    let lua_ws = ws_ref.parse::<i64>().map(|id| id.to_string()).unwrap_or_else(|_| lua_str(ws_ref));
    let lua = format!("hl.dispatch(hl.dsp.workspace.move({{ workspace = {lua_ws}, monitor = {} }}))", lua_str(target));
    hypr_dispatch(Some(lua), &["moveworkspacetomonitor", ws_ref, target])
}

fn select_workspace(id: i64) {
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
// TRANSACTION MARKER (so the daemon can ignore its own echoes)
// ============================================================

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
struct TxnMarker {
    at_ms: u64,
    pid: u32,
    enabled: Vec<String>,
    disabled: Vec<String>,
}

fn write_txn_marker(enabled: &[String], disabled: &[String]) {
    let marker = TxnMarker { at_ms: now_ms(), pid: std::process::id(), enabled: enabled.to_vec(), disabled: disabled.to_vec() };
    let _ = write_json_file(&txn_marker_path(), &marker);
}

fn read_recent_txn() -> Option<TxnMarker> {
    let m: TxnMarker = read_json_file(&txn_marker_path())?;
    (now_ms().saturating_sub(m.at_ms) <= SELF_EVENT_WINDOW.as_millis() as u64).then_some(m)
}

// ============================================================
// WORKSPACE HOMES
//
// When a monitor is disabled or unplugged, its workspaces are evacuated to
// the primary display and we remember (by hardware key, not port) where they
// came from. When that monitor comes back, they go home.
// ============================================================

#[derive(Debug, Clone, Serialize, Deserialize)]
struct WorkspaceHome {
    home: String,
    from_output: String,
    at_ms: u64,
}

type WorkspaceHomes = BTreeMap<String, WorkspaceHome>;

fn load_workspace_homes() -> WorkspaceHomes {
    let mut homes: WorkspaceHomes = read_json_file(&workspace_homes_path()).unwrap_or_default();
    let now = now_ms();
    homes.retain(|_, h| now.saturating_sub(h.at_ms) < WORKSPACE_HOME_TTL_MS);
    homes
}

fn save_workspace_homes(homes: &WorkspaceHomes) {
    let _ = write_json_file(&workspace_homes_path(), homes);
}

fn record_workspace_homes(entries: &[(String, String, String)]) {
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
fn move_workspaces_from(sources: &[&str], target: &str) {
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

// ============================================================
// ATOMIC COMMIT
// ============================================================

#[derive(Debug, Clone, Default)]
struct CommitOptions {
    /// Dispatch even if the plan matches the live state.
    force: bool,
    /// Allow outputs Hyprland doesn't list (emergency recovery).
    allow_unknown: bool,
    /// Always focus the primary afterwards (projection changes).
    focus_primary: bool,
    reason: String,
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

fn pick_primary(snap: &Snapshot, cfg: &MonitorsConfig) -> Option<String> {
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

fn wait_for_active(names: &[String], timeout: Duration) -> HashSet<String> {
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

fn wait_for_convergence(cfg: &MonitorsConfig, plan: &[PlannedMonitor], timeout: Duration) -> Result<Snapshot, String> {
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
fn commit_plan(plan: Vec<PlannedMonitor>, opts: &CommitOptions) -> Result<CommitReport, String> {
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
fn reconcile(
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
fn restore_workspace_homes(snap: &Snapshot, standalone_on: &HashSet<String>) -> bool {
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
fn emergency_candidate(snap: Option<&Snapshot>, cfg: &MonitorsConfig) -> Option<String> {
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

fn emergency_dispatch(snap: &Snapshot, cfg: &MonitorsConfig) {
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
// RESTART-PENDING (work deferred while the session is locked)
//
// While locked we may only add outputs. Everything else — the real layout,
// wallpaper refresh, a Quickshell refresh — is recorded here and replayed
// once the lock flag is gone. The marker is JSON, but consumers that only
// test for existence (older lock-screen handlers) keep working.
// ============================================================

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

fn read_pending() -> Option<PendingAction> {
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
fn mark_restart_pending(reason: &str, requested_mode: Option<&str>) {
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
fn take_pending() -> Option<PendingAction> {
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

// ============================================================
// MIRROR EXIT RECOVERY
//
// Leaving mirror mode on some Hyprland builds leaves former mirror targets
// in a broken buffer state: listed, but `width=0` or `disabled=true`, so
// layer-shell clients (wallpaper, bar) never get a configure for them.
// Cycling them (off → on) makes Hyprland re-advertise a fresh wl_output.
// ============================================================

fn mirror_targets_of(snap: &Snapshot) -> Vec<String> {
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
fn recover_from_mirror_if_needed(snap: &Snapshot, cfg: &MonitorsConfig) -> bool {
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
fn cycle_outputs(entries: &[PlannedMonitor]) {
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
fn post_mirror_exit_check(plan: &[PlannedMonitor]) {
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
fn detect_mode(snap: &Snapshot, cfg: &MonitorsConfig, rt: &RuntimeState) -> String {
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

fn geometric_mode(snap: &Snapshot, int_on: &[&HyprMonitor], ext_on: &[&HyprMonitor], has_internal_hw: bool) -> String {
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
fn record_runtime_state(mode: Option<String>, profile: Option<String>, plan: Option<&[PlannedMonitor]>, snap: Option<&Snapshot>) {
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
// PROJECTION MODES — public entry point
// ============================================================

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
#[serde(rename_all = "kebab-case")]
pub enum ApplyOutcome {
    Applied,
    NoChange,
    Deferred,
}

fn find_profile_by_name<'a>(cfg: &'a MonitorsConfig, name: &str) -> Option<&'a DisplayProfile> {
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
fn valid_profile_name(name: &str) -> Result<(), String> {
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
fn capture_profile(snap: &Snapshot, cfg: &MonitorsConfig, name: &str, auto: bool) -> Result<DisplayProfile, String> {
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

fn auto_profile_name(snap: &Snapshot) -> String {
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

fn remember_current_layout(_mode: &str) -> Result<(), String> {
    save_current_as_profile(None)
}

fn update_prefs_from_snapshot(cfg: &mut MonitorsConfig, snap: &Snapshot) {
    for m in snap.active_standalone() {
        let key = snap.key(&m.name);
        let pref = cfg.monitor_prefs.entry(key).or_default();
        pref.mode = m.current_mode_string();
        pref.scale = Some(m.scale);
        pref.transform = Some(m.transform);
        pref.vrr = Some(m.vrr);
    }
}

fn update_pref(key: &str, f: impl FnOnce(&mut MonitorPref)) {
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
fn find_profile_for<'a>(cfg: &'a MonitorsConfig, fingerprint: &str, lid: LidState) -> Option<&'a DisplayProfile> {
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

fn touch_profile(name: &str) {
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

fn apply_profile_internal(profile: &DisplayProfile, reason: &str, focus_primary: bool) -> Result<CommitReport, String> {
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

// ============================================================
// AUTO-RESOLVE — the policy engine
// ============================================================

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
    fn label(self) -> &'static str {
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
    fn is_restorative(self) -> bool {
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
fn default_mode_for(snap: &Snapshot, cfg: &MonitorsConfig, trigger: Trigger) -> ProjectionMode {
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
fn resolve_target(snap: &Snapshot, cfg: &MonitorsConfig, query: &str) -> Result<String, String> {
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
fn current_layout_plan(snap: &Snapshot) -> Vec<PlannedMonitor> {
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
fn modify_layout<F>(reason: &str, allow_while_locked: bool, f: F) -> Result<CommitReport, String>
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
fn place_relative(plan: &mut [PlannedMonitor], name: &str, how: &str, anchor: Option<&str>) -> Result<(), String> {
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
fn resolve_position_spec(snap: &Snapshot, cfg: &MonitorsConfig, spec: &str, explicit_anchor: Option<&str>) -> Result<(String, Option<String>), String> {
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

fn apply_position_spec(plan: &mut [PlannedMonitor], name: &str, spec: &str, anchor: Option<&str>) -> Result<(), String> {
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

#[derive(Debug, Clone, Default)]
pub struct EnableOptions {
    pub mode: Option<String>,
    pub position: Option<String>,
    pub scale: Option<f64>,
    pub transform: Option<i32>,
}

/// Turn a display on (or turn a mirror into a screen of its own).
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

/// After removing a screen from a row/column, pull the rest together while
/// keeping their order (fix_layout alone only repairs *disconnected* sets).
fn close_gaps(plan: &mut [PlannedMonitor], align: Align) {
    let rects: Vec<Rect> = plan.iter().filter(|p| p.is_standalone()).filter_map(|p| p.rect()).collect();
    if !layout_is_sound(&rects) {
        fix_layout(plan, align);
    }
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
fn available_projection_modes(snap: &Snapshot, cfg: &MonitorsConfig) -> Vec<(ProjectionMode, bool)> {
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

fn wallpaper_superseded(gen_id: u64) -> bool {
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

fn active_output_names() -> Vec<String> {
    query_active_monitors()
        .unwrap_or_default()
        .into_iter()
        .filter(|m| !m.disabled && m.width > 0 && connector_kind(&m.name).manageable())
        .map(|m| m.name)
        .collect()
}

fn awww_daemon_running() -> bool {
    run_cmd("pgrep", &["-x", "awww-daemon"], Duration::from_secs(2)).map(|o| o.success).unwrap_or(false)
}

fn json_contains_string(v: &Value, needle: &str) -> bool {
    match v {
        Value::String(s) => s == needle || s.split(|c: char| c == ':' || c.is_whitespace() || c == ',').any(|t| t == needle),
        Value::Array(a) => a.iter().any(|x| json_contains_string(x, needle)),
        Value::Object(o) => o.iter().any(|(k, x)| k == needle || json_contains_string(x, needle)),
        _ => false,
    }
}

/// Is the daemon running, answering, and bound to every active output?
fn wallpaper_healthy(outputs: &[String]) -> bool {
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

fn wayland_display() -> Option<String> {
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

fn purge_awww_sockets() {
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

fn wait_until(timeout: Duration, mut cond: impl FnMut() -> bool) -> bool {
    let start = Instant::now();
    while start.elapsed() < timeout {
        if cond() {
            return true;
        }
        thread::sleep(Duration::from_millis(100));
    }
    cond()
}

fn restart_awww_daemon() -> Result<(), String> {
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

fn restore_wallpaper_images() {
    let cfg = load_config();
    let script = cfg.wallpaper_script_path();
    if script.is_file() {
        let s = script.to_string_lossy().to_string();
        match run_cmd("sh", &[&s], Duration::from_secs(15)) {
            Ok(o) if o.success => return,
            Ok(o) => log_warn(&format!("wallpaper script failed: {}", o.stderr.trim())),
            Err(e) => log_warn(&format!("wallpaper script: {e}")),
        }
    }
    let _ = run_cmd("awww", &["restore"], Duration::from_secs(10));
}

fn sync_wallpaper(force: bool, gen_id: u64) {
    let outputs = active_output_names();
    if outputs.is_empty() {
        return;
    }
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
            log_info(&format!("restarting awww-daemon for {} (attempt {attempt})", outputs.join(", ")));
            if let Err(e) = restart_awww_daemon() {
                log_warn(&format!("awww-daemon restart failed: {e}"));
                thread::sleep(delay);
                delay *= 2;
                continue;
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

// ============================================================
// AUDIO SINK FOLLOW-UP (PipeWire / PulseAudio via pactl)
//
// HDMI/DP monitors with speakers expose a sink (ELD) a moment after they
// light up. Policy: "auto" switches the default sink to it; "notify" only
// tells the user; "off" does nothing. When such a monitor disappears while
// it was the default sink, we fall back to the best non-display sink so
// sound doesn't vanish into a dead output.
// ============================================================

#[derive(Debug, Clone)]
struct AudioSink {
    name: String,
    description: String,
    is_display: bool,
    available: bool,
}

fn sink_is_display(text: &str) -> bool {
    let t = text.to_ascii_lowercase();
    t.contains("hdmi") || t.contains("displayport") || t.contains("-dp") || t.contains("dp-") || t.contains("iec958-stereo-hdmi")
}

fn list_audio_sinks() -> Vec<AudioSink> {
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

fn default_sink() -> Option<String> {
    run_cmd("pactl", &["get-default-sink"], Duration::from_secs(2))
        .ok()
        .filter(|o| o.success)
        .map(|o| o.stdout.trim().to_string())
        .filter(|s| !s.is_empty())
}

fn notify_user(summary: &str, body: &str) {
    if command_exists("notify-send") {
        let _ = spawn_detached("notify-send", &["-a", "NEXA Display", "-i", "video-display", summary, body], &[]);
    }
}

/// Called by the daemon after a hotplug has been applied.
fn handle_audio_after_hotplug(added: Vec<String>, removed: Vec<String>, cfg: &MonitorsConfig) {
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

// ============================================================
// HOTPLUG DAEMON
//
// One long-lived process (`nexad display daemon`) that reacts to:
// * Hyprland socket2 events: monitoradded[v2], monitorremoved[v2],
//   configreloaded, switch (lid);
// * polled facts Hyprland doesn't report reliably: ACPI lid state, the
//   lock flag going away (replay deferred work), suspend/resume (boot-time
//   clock jumping ahead of the monotonic clock), and drift between what is
//   connected and what we last resolved (missed events).
//
// Events are coalesced into bursts (400 ms quiet window, 3 s cap), so a
// dock bringing up three monitors one after another is resolved once.
// ============================================================

/// Grace period after unlock for the lock screen's own handler to claim
/// the pending marker before the daemon replays it itself.
const UNLOCK_GRACE: Duration = Duration::from_millis(1500);
/// A monitor that dropped off while asleep (DPMS off) is only considered
/// unplugged if it's still gone this long after the screens woke up.
const DPMS_WAKE_GRACE: Duration = Duration::from_secs(4);

struct DaemonGuard {
    path: PathBuf,
}

impl DaemonGuard {
    fn acquire() -> Result<Self, String> {
        let path = daemon_pid_path();
        if let Some(pid) = fs::read_to_string(&path).ok().and_then(|s| s.trim().parse::<u32>().ok()) {
            if pid != std::process::id() && pid_alive(pid) && Self::looks_like_us(pid) {
                return Err(format!("display daemon already running (pid {pid})"));
            }
        }
        write_atomic(&path, std::process::id().to_string().as_bytes())?;
        Ok(Self { path })
    }
    fn looks_like_us(pid: u32) -> bool {
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

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum HyprEvent {
    MonitorAdded(String),
    MonitorRemoved(String),
    /// `true` = lid closed.
    LidSwitch(bool),
    ConfigReloaded,
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

#[derive(Debug, Default)]
struct HotplugBurst {
    added: Vec<String>,
    removed: Vec<String>,
    lid: Option<bool>,
    config_reloaded: bool,
    first: Option<Instant>,
    last: Option<Instant>,
}

impl HotplugBurst {
    fn touch(&mut self) {
        let now = Instant::now();
        self.first.get_or_insert(now);
        self.last = Some(now);
    }
    fn is_empty(&self) -> bool {
        self.added.is_empty() && self.removed.is_empty() && self.lid.is_none() && !self.config_reloaded
    }
    fn due(&self) -> bool {
        match (self.first, self.last) {
            (Some(f), Some(l)) => l.elapsed() >= HOTPLUG_QUIET_WINDOW || f.elapsed() >= HOTPLUG_MAX_BURST,
            _ => false,
        }
    }
    fn add(&mut self, name: &str) {
        self.removed.retain(|n| n != name);
        if !self.added.iter().any(|n| n == name) {
            self.added.push(name.to_string());
        }
        self.touch();
    }
    fn remove(&mut self, name: &str) {
        // Plugged and unplugged within one burst (flapping cable): net zero,
        // but still resolve — the port may now carry a different monitor.
        self.added.retain(|n| n != name);
        if !self.removed.iter().any(|n| n == name) {
            self.removed.push(name.to_string());
        }
        self.touch();
    }
}

struct DaemonState {
    burst: HotplugBurst,
    known_fingerprint: String,
    last_lid: Option<LidState>,
    was_locked: bool,
    unlocked_at: Option<Instant>,
    mono_ref: Instant,
    uptime_ref: Option<f64>,
    last_pending_check: Instant,
    last_lid_poll: Instant,
    last_resume_check: Instant,
    last_snapshot: Instant,
    /// ws dispatch ref → (connector, hardware key), refreshed periodically so
    /// we know where workspaces lived *before* Hyprland evacuated them.
    ws_locations: HashMap<String, (String, String)>,
    /// Outputs that vanished while their screen was asleep.
    dpms_deferred: HashMap<String, Instant>,
    /// Last known DPMS state per output.
    dpms_state: HashMap<String, bool>,
    screens_woke_at: Option<Instant>,
}

impl DaemonState {
    fn new() -> Self {
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

    fn resolve(&mut self, trigger: Trigger) -> Option<ResolveResult> {
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

    fn on_event(&mut self, ev: HyprEvent) {
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
    fn zero_screen_check(&mut self) {
        let active = query_active_monitors().unwrap_or_default();
        let lit = active.iter().filter(|m| !m.disabled && connector_kind(&m.name).manageable()).count();
        if lit == 0 {
            log_warn("no display left enabled — recovering immediately");
            let _ = emergency_fallback_laptop();
        }
    }

    fn flush_burst(&mut self) {
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
    fn refresh_snapshot(&mut self) {
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

    fn tick(&mut self) {
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

/// Read socket2 until EOF/error, feeding complete lines to the state
/// machine and ticking housekeeping every `SOCKET_TICK`. Partial lines are
/// buffered across reads (events can be split at any byte).
fn run_event_stream(mut stream: UnixStream, state: &mut DaemonState) {
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

// ============================================================
// INFO (`nexad display info`)
//
// Consumed by the Dynamic Island (Super+P). Must never fail: if Hyprland is
// unreachable we still print a well-formed document with an `error` field.
// ============================================================

/// Write one line to stdout, ignoring a closed pipe (the Dynamic Island
/// may stop reading at any time; that must never panic the CLI). Returns
/// `false` when the reader is gone.
fn emit_line(s: &str) -> bool {
    let mut out = std::io::stdout().lock();
    writeln!(out, "{s}").and_then(|_| out.flush()).is_ok()
}

macro_rules! emit {
    ($($arg:tt)*) => {{
        let _ = emit_line(&format!($($arg)*));
    }};
}

fn mode_label(mode: &ProjectionMode, snap: &Snapshot) -> String {
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
fn canvas_of(monitors: &[&HyprMonitor]) -> Option<(i32, i32, i32, i32)> {
    let mut it = monitors.iter().map(|m| {
        let (w, h) = logical_size((m.width, m.height), m.scale, m.transform);
        (m.x, m.y, m.x + w, m.y + h)
    });
    let first = it.next()?;
    let (x0, y0, x1, y1) = it.fold(first, |a, b| (a.0.min(b.0), a.1.min(b.1), a.2.max(b.2), a.3.max(b.3)));
    Some((x0, y0, (x1 - x0).max(1), (y1 - y0).max(1)))
}

fn display_infos(snap: &Snapshot, cfg: &MonitorsConfig) -> (Vec<DisplayInfo>, Value) {
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

/// Build the `info` document (also used by `watch`).
pub fn info_json() -> Value {
    let cfg = load_config();
    let rt = load_runtime_state();
    let locked = is_locked();
    let lid = read_lid_state();
    let pending = read_pending();
    let base = |error: Option<String>| {
        json!({
            "fingerprint": "",
            "current_mode": "unknown",
            "active_profile": Value::Null,
            "is_locked": locked,
            "lid_closed": lid == LidState::Closed,
            "lid_state": lid.label(),
            "restart_pending": pending.is_some(),
            "pending": pending,
            "daemon_running": daemon_running(),
            "connected_count": 0,
            "active_count": 0,
            "internal_count": 0,
            "external_count": 0,
            "primary": Value::Null,
            "projection_modes": [],
            "canvas": Value::Null,
            "displays": [],
            "profiles": [],
            "error": error,
        })
    };

    let snap = match Snapshot::capture(&cfg) {
        Ok(s) => s,
        Err(e) => return base(Some(e)),
    };
    let current_mode = detect_mode(&snap, &cfg, &rt);
    let active_profile = rt
        .active_profile
        .clone()
        .filter(|name| cfg.profiles.iter().any(|p| &p.name == name && p.fingerprint == snap.fingerprint))
        .or_else(|| find_profile_for(&cfg, &snap.fingerprint, snap.lid).map(|p| p.name.clone()));
    let (displays, canvas) = display_infos(&snap, &cfg);
    let modes: Vec<Value> = available_projection_modes(&snap, &cfg)
        .into_iter()
        .map(|(m, ok)| {
            let id = m.as_str();
            json!({
                "mode": id,
                "label": mode_label(&m, &snap),
                "available": ok,
                "current": id == current_mode || (current_mode == "extend-right" && id == "extend"),
            })
        })
        .collect();
    let profiles: Vec<Value> = cfg
        .profiles
        .iter()
        .filter(|p| p.fingerprint == snap.fingerprint)
        .map(|p| json!({"name": p.name, "mode": p.mode, "auto": p.auto, "lid": p.lid, "active": active_profile.as_deref() == Some(p.name.as_str())}))
        .collect();

    let mut doc = base(None);
    if let Value::Object(map) = &mut doc {
        map.insert("fingerprint".into(), json!(snap.fingerprint));
        map.insert("current_mode".into(), json!(current_mode));
        map.insert("active_profile".into(), json!(active_profile));
        map.insert("lid_closed".into(), json!(snap.lid_closed()));
        map.insert("connected_count".into(), json!(snap.managed.len()));
        map.insert("active_count".into(), json!(snap.active_managed().len()));
        map.insert("internal_count".into(), json!(snap.internals().len()));
        map.insert("external_count".into(), json!(snap.externals().len()));
        map.insert("primary".into(), json!(pick_primary(&snap, &cfg)));
        map.insert("mirror_source".into(), json!(rt.mirror_source));
        map.insert("ghosts".into(), json!(snap.ghosts));
        map.insert("unmanaged".into(), json!(snap.unmanaged));
        map.insert("projection_modes".into(), Value::Array(modes));
        map.insert("canvas".into(), canvas);
        map.insert("displays".into(), json!(displays));
        map.insert("profiles".into(), Value::Array(profiles));
        map.remove("error");
    }
    doc
}

/// Print the `info` document as one JSON line. Never fails.
pub fn print_info() {
    emit!("{}", info_json());
}

// ============================================================
// CLI (`nexad display <command> ...`)
//
// Exit codes: 0 ok · 1 error · 2 usage · 3 deferred (session locked; the
// change is recorded in restart-pending and replayed after unlock).
// ============================================================

const EXIT_OK: i32 = 0;
const EXIT_ERR: i32 = 1;
const EXIT_USAGE: i32 = 2;
const EXIT_DEFERRED: i32 = 3;

const CLI_HELP: &str = "\
usage: nexad display <command> [args] [--json]

  info                         JSON state for the Dynamic Island (always succeeds)
  mode <mode|profile>          internal-only | external-only | extend[-left|-up|-down]
                               | extend-grid[-N] | mirror | auto | <profile name>
  auto | resolve               re-evaluate the setup (profile match or defaults)
  cycle                        switch to the next available mode
  daemon                       run the hotplug / lid / resume / unlock daemon
  enable <out> [mode] [pos] [scale]
                               pos: WxH | auto | left-of:<out> | right-of:<out> | above:<out> | below:<out>
  disable <out>                refuses to turn off the last active display
  toggle <out>
  focus <out>
  rotate <out> <normal|90|180|270|flipped[-90|-180|-270]>
  scale <out> <factor|auto>
  resolution <out> <WxH[@Hz]|preferred|highrr|highres>
  vrr <out> <on|off|fullscreen>
  position <out> <spec> [anchor]
  primary <out>                primary display (focus target, mirror source on desktops)
  mirror <out|all> [source]
  unmirror <out|all>
  save [name]                  save current layout (no name = auto profile for this setup)
  profiles                     list saved profiles (JSON)
  delete-profile <name>
  rename-profile <old> <new>
  lid [open|closed]            simulate / re-apply a lid transition
  resume                       run the post-suspend resolution
  unlocked | resolve-pending   replay work deferred while the session was locked
  emergency                    force one display on at 0x0 (black-screen recovery)
  wallpaper [--force]          make sure awww covers every active output
  osd                          open the display panel in the Dynamic Island
  rule <hyprland monitor rule> raw rule, e.g. \"DP-1,2560x1440@144,1920x0,1\"
  fingerprint                  hardware fingerprint of what is connected
  config                       print the config path and contents
  watch                        print `info` again whenever the setup changes
  help

<out> may be a connector (DP-1), a hardware key, \"internal\", \"primary\",
\"focused\", a Hyprland monitor id, or part of the monitor's description.";

struct CliOut {
    json: bool,
}

impl CliOut {
    fn ok(&self, msg: &str, data: Value) -> i32 {
        if self.json {
            let mut v = json!({"ok": true, "message": msg});
            if let (Value::Object(m), Value::Object(extra)) = (&mut v, data) {
                m.extend(extra);
            }
            emit!("{v}");
        } else if !msg.is_empty() {
            emit!("{msg}");
        }
        EXIT_OK
    }
    fn deferred(&self, msg: &str) -> i32 {
        if self.json {
            emit!("{}", json!({"ok": true, "deferred": true, "message": msg}));
        } else {
            emit!("{msg}");
        }
        EXIT_DEFERRED
    }
    fn err(&self, msg: &str) -> i32 {
        if self.json {
            emit!("{}", json!({"ok": false, "error": msg}));
        } else {
            eprintln!("nexad display: {msg}");
        }
        EXIT_ERR
    }
    fn usage(&self, msg: &str) -> i32 {
        if self.json {
            emit!("{}", json!({"ok": false, "error": msg, "usage": true}));
        } else {
            eprintln!("nexad display: {msg}\n\n{CLI_HELP}");
        }
        EXIT_USAGE
    }
    fn report(&self, what: &str, r: Result<CommitReport, String>) -> i32 {
        match r {
            Err(e) => self.err(&e),
            Ok(r) if r.deferred => self.deferred(&format!("{what}: deferred until the session is unlocked")),
            Ok(r) => {
                let mut parts = Vec::new();
                if !r.just_enabled.is_empty() {
                    parts.push(format!("enabled {}", r.just_enabled.join(", ")));
                }
                if !r.just_disabled.is_empty() {
                    parts.push(format!("disabled {}", r.just_disabled.join(", ")));
                }
                let msg = if !r.changed {
                    format!("{what}: nothing to change")
                } else if parts.is_empty() {
                    format!("{what}: done")
                } else {
                    format!("{what}: {}", parts.join("; "))
                };
                self.ok(
                    &msg,
                    json!({
                        "changed": r.changed,
                        "enabled": r.just_enabled,
                        "disabled": r.just_disabled,
                        "primary": r.primary,
                        "active": r.active,
                    }),
                )
            }
        }
    }
    fn outcome(&self, what: &str, r: Result<ApplyOutcome, String>) -> i32 {
        match r {
            Err(e) => self.err(&e),
            Ok(ApplyOutcome::Deferred) => self.deferred(&format!("{what}: session locked; will apply after unlock")),
            Ok(ApplyOutcome::NoChange) => self.ok(&format!("{what}: already active"), json!({"outcome": "no-change"})),
            Ok(ApplyOutcome::Applied) => self.ok(&format!("{what}: applied"), json!({"outcome": "applied"})),
        }
    }
    fn resolved(&self, r: Result<ResolveResult, String>) -> i32 {
        match r {
            Err(e) => self.err(&e),
            Ok(r) => {
                let data = json!({
                    "decision": r.decision,
                    "outcome": r.outcome,
                    "profile": r.matched_profile,
                    "fingerprint": r.fingerprint,
                    "active": r.report.active,
                });
                if r.outcome == ApplyOutcome::Deferred {
                    self.deferred(&format!("{} (deferred until unlock)", r.decision))
                } else {
                    self.ok(&r.decision, data)
                }
            }
        }
    }
}

fn parse_scale_arg(s: &str) -> Result<Option<f64>, String> {
    match s.trim() {
        "" | "auto" | "-" => Ok(None),
        v => v.parse::<f64>().ok().filter(|f| f.is_finite() && *f > 0.0).map(Some).ok_or_else(|| format!("invalid scale '{v}'")),
    }
}

/// Entry point for `nexad display ...`. `args` may start with "display".
/// Returns the process exit code; always waits (bounded) for background
/// work such as the wallpaper sync before returning.
pub fn run_cli(args: &[String]) -> i32 {
    let mut rest: Vec<&str> = args.iter().map(String::as_str).collect();
    if rest.first() == Some(&"display") {
        rest.remove(0);
    }
    let json_flag = rest.iter().any(|a| *a == "--json");
    let force_flag = rest.iter().any(|a| *a == "--force" || *a == "-f");
    let pretty = rest.iter().any(|a| *a == "--pretty");
    rest.retain(|a| !matches!(*a, "--json" | "--force" | "-f" | "--pretty"));
    let out = CliOut { json: json_flag };

    let cmd = rest.first().copied().unwrap_or("info");
    let a = |i: usize| rest.get(i).copied();
    let need = |i: usize, what: &str| -> Result<&str, i32> { a(i).ok_or_else(|| out.usage(&format!("{cmd}: missing {what}"))) };
    macro_rules! need {
        ($i:expr, $what:expr) => {
            match need($i, $what) {
                Ok(v) => v,
                Err(code) => return code,
            }
        };
    }

    let code = match cmd {
        "info" | "status" => {
            let doc = info_json();
            if pretty {
                emit!("{}", serde_json::to_string_pretty(&doc).unwrap_or_else(|_| doc.to_string()));
            } else {
                emit!("{doc}");
            }
            EXIT_OK
        }
        "mode" | "project" | "projection" | "profile" | "apply" => {
            let m = need!(1, "mode or profile name");
            out.outcome(m, apply_projection_ex(m, true))
        }
        "auto" | "resolve" | "auto-resolve" => out.resolved(auto_resolve(Trigger::Manual, None)),
        "cycle" | "next" => match cycle_projection() {
            Ok(m) => out.ok(&format!("switched to {m}"), json!({"mode": m})),
            Err(e) => out.err(&e),
        },
        "daemon" => match start_hotplug_daemon() {
            Ok(()) => EXIT_OK,
            Err(e) => out.err(&e),
        },
        "enable" | "on" => {
            let target = need!(1, "output");
            let scale = match a(4).map(parse_scale_arg).transpose() {
                Ok(v) => v.flatten(),
                Err(e) => return out.usage(&e),
            };
            let transform = match a(5).map(|t| parse_transform(t).ok_or_else(|| format!("invalid rotation '{t}'"))).transpose() {
                Ok(v) => v,
                Err(e) => return out.usage(&e),
            };
            let opts = EnableOptions {
                mode: a(2).filter(|m| !matches!(*m, "" | "-" | "auto")).map(str::to_string),
                position: a(3).filter(|p| !matches!(*p, "" | "-")).map(str::to_string),
                scale,
                transform,
            };
            out.report(&format!("enable {target}"), enable_monitor_ex(target, opts))
        }
        "disable" | "off" => {
            let target = need!(1, "output");
            out.report(&format!("disable {target}"), disable_monitor_ex(target))
        }
        "toggle" => {
            let target = need!(1, "output");
            out.report(&format!("toggle {target}"), toggle_monitor(target))
        }
        "focus" => {
            let target = need!(1, "output");
            match focus_display(target) {
                Ok(n) => out.ok(&format!("focused {n}"), json!({"output": n})),
                Err(e) => out.err(&e),
            }
        }
        "rotate" | "transform" => {
            let target = need!(1, "output");
            let rot = need!(2, "rotation");
            out.report(&format!("rotate {target}"), rotate_monitor(target, rot))
        }
        "scale" => {
            let target = need!(1, "output");
            let s = need!(2, "scale");
            out.report(&format!("scale {target}"), set_monitor_scale(target, s))
        }
        "resolution" | "res" | "set-mode" => {
            let target = need!(1, "output");
            let m = need!(2, "mode");
            out.report(&format!("resolution {target}"), set_monitor_resolution(target, m))
        }
        "vrr" | "adaptive-sync" => {
            let target = need!(1, "output");
            let v = need!(2, "on|off|fullscreen");
            out.report(&format!("vrr {target}"), set_monitor_vrr(target, v))
        }
        "position" | "move" | "pos" => {
            let target = need!(1, "output");
            let spec = need!(2, "position");
            out.report(&format!("position {target}"), set_monitor_position(target, spec, a(3)))
        }
        "primary" | "set-primary" => {
            let target = need!(1, "output");
            match set_primary(target) {
                Ok(name) => out.ok(&format!("primary display: {name}"), json!({"primary": name})),
                Err(e) => out.err(&e),
            }
        }
        "mirror" | "duplicate" => match a(1) {
            None | Some("all") if a(2).is_none() => out.outcome("mirror", apply_projection_ex("mirror", true)),
            Some(target) => out.report(&format!("mirror {target}"), mirror_monitor(target, a(2))),
            None => out.usage("mirror: missing target"),
        },
        "unmirror" | "stop-mirror" => {
            let target = a(1).unwrap_or("all");
            out.report(&format!("unmirror {target}"), unmirror_monitor(target))
        }
        "save" | "save-profile" => {
            let name = a(1);
            match save_current_as_profile(name) {
                Ok(()) => out.ok(&format!("saved {}", name.map(|n| format!("profile '{n}'")).unwrap_or_else(|| "layout for this setup".into())), json!({"profile": name})),
                Err(e) => out.err(&e),
            }
        }
        "profiles" | "list-profiles" => {
            let v = list_profiles_json();
            if pretty {
                emit!("{}", serde_json::to_string_pretty(&v).unwrap_or_default());
            } else {
                emit!("{v}");
            }
            EXIT_OK
        }
        "delete-profile" | "remove-profile" | "rm-profile" => {
            let name = need!(1, "profile name");
            match delete_profile(name) {
                Ok(()) => out.ok(&format!("deleted profile '{name}'"), json!({})),
                Err(e) => out.err(&e),
            }
        }
        "rename-profile" => {
            let old = need!(1, "old name");
            let new = need!(2, "new name");
            match rename_profile(old, new) {
                Ok(()) => out.ok(&format!("renamed '{old}' to '{new}'"), json!({})),
                Err(e) => out.err(&e),
            }
        }
        "lid" => {
            let state = match a(1) {
                Some("closed" | "close" | "on") => LidState::Closed,
                Some("open" | "opened" | "off") => LidState::Open,
                Some(other) => return out.usage(&format!("lid: expected open|closed, got '{other}'")),
                None => read_lid_state(),
            };
            match state {
                LidState::Absent => out.err("this machine has no lid switch"),
                LidState::Closed => {
                    cache_lid_state(true);
                    out.resolved(auto_resolve(Trigger::LidClosed, None))
                }
                LidState::Open => {
                    cache_lid_state(false);
                    out.resolved(auto_resolve(Trigger::LidOpened, None))
                }
            }
        }
        "resume" | "wake" => {
            thread::sleep(RESUME_SETTLE);
            out.resolved(auto_resolve(Trigger::Resume, None))
        }
        "unlocked" | "unlock" | "resolve-pending" | "pending" => match resolve_pending() {
            Ok(Some(p)) => out.ok(&format!("replayed deferred work ({})", p.reasons.join("; ")), json!({"pending": p})),
            Ok(None) => out.ok("nothing was pending", json!({"pending": Value::Null})),
            Err(e) => {
                if is_locked() {
                    out.deferred(&e)
                } else {
                    out.err(&e)
                }
            }
        },
        "emergency" | "rescue" | "fallback" => match emergency_fallback_laptop() {
            Ok(()) => out.ok("emergency fallback applied", json!({})),
            Err(e) => out.err(&e),
        },
        "wallpaper" | "sync-wallpaper" => {
            if is_locked() {
                mark_restart_pending("wallpaper sync requested while locked", None);
                out.deferred("wallpaper: session locked; will sync after unlock")
            } else {
                schedule_wallpaper_sync(force_flag);
                out.ok("wallpaper sync started", json!({"force": force_flag}))
            }
        }
        "osd" | "island" | "panel" => {
            trigger_island_display_osd();
            EXIT_OK
        }
        "rule" | "raw" => {
            if rest.len() < 2 {
                return out.usage("rule: missing monitor rule");
            }
            let rule = rest[1..].join(" ");
            match dispatch_monitor_rule(&rule) {
                Ok(()) => out.ok("rule applied", json!({"rule": rule})),
                Err(e) => out.err(&e),
            }
        }
        "fingerprint" | "fp" => {
            let cfg = load_config();
            match Snapshot::capture(&cfg) {
                Ok(s) => {
                    let keys: Vec<String> = s.managed.iter().map(|m| s.key(&m.name)).collect();
                    out.ok(&s.fingerprint, json!({"fingerprint": s.fingerprint, "keys": keys}))
                }
                Err(e) => out.err(&e),
            }
        }
        "config" => {
            let cfg = load_config();
            let path = config_path();
            if json_flag {
                emit!("{}", json!({"path": path, "config": cfg}));
            } else {
                emit!("# {}", path.display());
                emit!("{}", serde_json::to_string_pretty(&cfg).unwrap_or_default());
            }
            EXIT_OK
        }
        "watch" => {
            // Print `info` whenever something the panel cares about changes.
            let mut last = String::new();
            loop {
                let doc = info_json();
                let sig = json!([
                    doc.get("fingerprint"),
                    doc.get("current_mode"),
                    doc.get("is_locked"),
                    doc.get("lid_closed"),
                    doc.get("restart_pending"),
                    doc.get("displays"),
                ])
                .to_string();
                if sig != last {
                    if !emit_line(&doc.to_string()) {
                        return EXIT_OK; // reader went away (panel closed)
                    }
                    last = sig;
                }
                thread::sleep(Duration::from_secs(1));
            }
        }
        "help" | "-h" | "--help" => {
            emit!("{CLI_HELP}");
            EXIT_OK
        }
        other => out.usage(&format!("unknown command '{other}'")),
    };

    // Background work (wallpaper sync after a transition) must finish before
    // the process exits, or awww is left half-restarted.
    wait_for_background_tasks(Duration::from_secs(10));
    code
}

// ============================================================
// TESTS (pure logic only — nothing here talks to Hyprland)
// ============================================================

#[cfg(test)]
mod tests {
    use super::*;

    fn mon(name: &str, make: &str, model: &str, serial: &str, w: i32, h: i32, modes: &[&str]) -> HyprMonitor {
        HyprMonitor {
            id: 0,
            name: name.into(),
            description: format!("{make} {model} {serial}"),
            make: make.into(),
            model: model.into(),
            serial: serial.into(),
            width: w,
            height: h,
            refresh_rate: 60.0,
            scale: 1.0,
            dpms_status: true,
            mirror_of: "none".into(),
            available_modes: modes.iter().map(|s| s.to_string()).collect(),
            ..Default::default()
        }
    }

    fn laptop() -> HyprMonitor {
        mon("eDP-1", "BOE", "0x0BCA", "", 1920, 1200, &["1920x1200@60.00Hz", "1920x1200@48.00Hz"])
    }
    fn dell(port: &str) -> HyprMonitor {
        mon(port, "Dell Inc.", "U2720Q", "ABC123", 2560, 1440, &["2560x1440@59.95Hz", "2560x1440@143.91Hz", "1920x1080@60.00Hz"])
    }
    fn lg(port: &str) -> HyprMonitor {
        mon(port, "LG Electronics", "27GL850", "0x00000000", 1920, 1080, &["1920x1080@60.00Hz", "1920x1080@144.00Hz"])
    }

    fn snap_with(monitors: Vec<HyprMonitor>, lid: LidState) -> Snapshot {
        snap_full(monitors, lid, false, &[])
    }

    fn snap_full(monitors: Vec<HyprMonitor>, lid: LidState, locked: bool, disconnected: &[&str]) -> Snapshot {
        let mut drm = HashMap::new();
        for m in &monitors {
            let status = if disconnected.contains(&m.name.as_str()) { DrmStatus::Disconnected } else { DrmStatus::Connected };
            drm.insert(m.name.clone(), DrmConnector { status, dpms_on: Some(true) });
        }
        Snapshot::from_parts(monitors, None, drm, lid, locked, &MonitorsConfig::default())
    }

    fn get<'a>(plan: &'a [PlannedMonitor], name: &str) -> &'a PlannedMonitor {
        plan.iter().find(|p| p.name == name).unwrap_or_else(|| panic!("{name} missing from plan {plan:?}"))
    }

    fn plan(mode: &str, snap: &Snapshot) -> Result<Vec<PlannedMonitor>, String> {
        build_projection_plan(&ProjectionMode::parse(mode).expect("mode parses"), snap, &MonitorsConfig::default())
    }

    // ---- modes ----------------------------------------------------------

    #[test]
    fn parse_mode_variants() {
        let m = parse_mode("2560x1440@143.91Hz").unwrap();
        assert_eq!((m.w, m.h), (2560, 1440));
        assert!((m.hz.unwrap() - 143.91).abs() < 1e-9);
        assert!(parse_mode("1920x1080").unwrap().hz.is_none());
        assert!(parse_mode("preferred").is_none());
        assert!(parse_mode("0x1080").is_none());
        assert!(parse_mode("1920x1080@abc").is_none());
        assert_eq!(format_mode(1920, 1080, Some(60.0)), "1920x1080@60");
        assert_eq!(format_mode(2560, 1440, Some(143.912)), "2560x1440@143.912");
    }

    #[test]
    fn choose_mode_fallbacks() {
        let d = dell("DP-1");
        assert_eq!(choose_mode(&d, "2560x1440@143.91"), "2560x1440@143.91", "exact");
        assert_eq!(choose_mode(&d, "2560x1440@144"), "2560x1440@143.91", "near (±1 Hz)");
        assert_eq!(choose_mode(&d, "2560x1440@120"), "2560x1440@143.91", "same res, highest refresh");
        assert_eq!(choose_mode(&d, "2560x1440"), "2560x1440@143.91");
        assert_eq!(choose_mode(&d, "3840x2160@60"), "preferred", "unsupported res");
        assert_eq!(choose_mode(&d, "garbage"), "preferred");
        assert_eq!(choose_mode(&d, ""), "preferred");
        assert_eq!(choose_mode(&d, "highrr"), "highrr");
        let bare = mon("DP-9", "X", "Y", "", 0, 0, &[]);
        assert_eq!(choose_mode(&bare, "1280x720@60"), "1280x720@60", "nothing to validate against");
    }

    #[test]
    fn scale_is_sanitised_to_valid_values() {
        assert_eq!(sanitize_scale((1920, 1080), 1.0), 1.0);
        assert_eq!(sanitize_scale((1920, 1080), 1.25), 1.25);
        assert_eq!(sanitize_scale((2560, 1600), 1.6), 1.6, "fractional scale preserved when valid");
        let s = sanitize_scale((1920, 1080), 1.3);
        let (lw, lh) = (1920.0 / s, 1080.0 / s);
        assert!((lw - lw.round()).abs() < 0.01 && (lh - lh.round()).abs() < 0.01, "{s} is not valid");
        assert!((s - 1.3).abs() < 0.1);
        assert_eq!(sanitize_scale((1920, 1080), f64::NAN), 1.0);
        assert_eq!(sanitize_scale((1920, 1080), -2.0), 1.0);
    }

    #[test]
    fn transforms() {
        assert_eq!(parse_transform("normal"), Some(0));
        assert_eq!(parse_transform("90"), Some(1));
        assert_eq!(parse_transform("portrait"), Some(1));
        assert_eq!(parse_transform("flipped-270"), Some(7));
        assert_eq!(parse_transform("sideways"), None);
        assert_eq!(logical_size((2560, 1440), 1.0, 1), (1440, 2560));
        assert_eq!(logical_size((2560, 1600), 1.6, 0), (1600, 1000));
    }

    // ---- identity ---------------------------------------------------------

    #[test]
    fn hardware_keys_and_serials() {
        assert_eq!(dell("DP-1").hardware_key(), "DellInc_U2720Q_ABC123");
        assert_eq!(lg("HDMI-A-1").hardware_key(), "LGElectronics_27GL850", "placeholder serial dropped");
        assert!(!serial_is_meaningful("0"));
        assert!(!serial_is_meaningful("Unknown"));
        assert!(!serial_is_meaningful("0x00000000"));
        assert!(serial_is_meaningful("0x01A2"));
        let noedid = mon("DP-7", "", "", "", 1920, 1080, &[]);
        assert_eq!(noedid.hardware_key(), "port_DP7");
    }

    #[test]
    fn identical_monitors_get_deterministic_suffixes() {
        let keys = assign_hardware_keys(&[lg("DP-10"), lg("DP-2")]);
        assert_eq!(keys["DP-2"], "LGElectronics_27GL850", "DP-2 sorts before DP-10");
        assert_eq!(keys["DP-10"], "LGElectronics_27GL850#2");
    }

    #[test]
    fn fingerprint_ignores_ports_and_order() {
        let a = snap_with(vec![laptop(), dell("DP-1"), lg("HDMI-A-1")], LidState::Open);
        let b = snap_with(vec![lg("DP-3"), dell("HDMI-A-2"), laptop()], LidState::Open);
        assert_eq!(a.fingerprint, b.fingerprint);
        let c = snap_with(vec![laptop(), dell("DP-1")], LidState::Open);
        assert_ne!(a.fingerprint, c.fingerprint);
    }

    #[test]
    fn fallback_and_headless_outputs_are_unmanaged() {
        let s = snap_with(vec![laptop(), mon("FALLBACK", "", "", "", 1920, 1080, &[]), mon("HEADLESS-2", "", "", "", 1920, 1080, &[])], LidState::Open);
        assert_eq!(s.managed.len(), 1);
        assert_eq!(s.unmanaged.len(), 2);
        assert_eq!(s.fingerprint, snap_with(vec![laptop()], LidState::Open).fingerprint);
    }

    // ---- planners ---------------------------------------------------------

    #[test]
    fn extend_directions() {
        let s = snap_with(vec![laptop(), dell("DP-1")], LidState::Open);

        let p = plan("extend", &s).unwrap();
        assert_eq!(get(&p, "eDP-1").pos(), Some((0, 0)));
        assert_eq!(get(&p, "DP-1").pos(), Some((1920, 0)));

        let p = plan("extend-left", &s).unwrap();
        assert_eq!(get(&p, "DP-1").pos(), Some((0, 0)));
        assert_eq!(get(&p, "eDP-1").pos(), Some((2560, 0)));

        let p = plan("extend-down", &s).unwrap();
        let (_, dy) = get(&p, "DP-1").pos().unwrap();
        let (_, ey) = get(&p, "eDP-1").pos().unwrap();
        assert_eq!(dy - ey, 1200, "external directly below the panel");

        let p = plan("extend-up", &s).unwrap();
        let (_, dy) = get(&p, "DP-1").pos().unwrap();
        let (_, ey) = get(&p, "eDP-1").pos().unwrap();
        assert_eq!(ey - dy, 1440, "panel directly below the external");

        for mode in ["extend", "extend-left", "extend-up", "extend-down"] {
            let p = plan(mode, &s).unwrap();
            let rects: Vec<Rect> = p.iter().filter_map(|m| m.rect()).collect();
            assert!(layout_is_sound(&rects), "{mode} layout unsound: {p:?}");
            assert!(p.iter().all(|m| m.enabled && m.mirror_of.is_none()));
        }
    }

    #[test]
    fn extend_with_three_externals_is_a_chain() {
        let s = snap_with(vec![laptop(), dell("DP-1"), lg("DP-2"), lg("HDMI-A-1")], LidState::Open);
        let p = plan("extend", &s).unwrap();
        let mut xs: Vec<i32> = p.iter().map(|m| m.pos().unwrap().0).collect();
        xs.sort();
        assert_eq!(xs, vec![0, 1920, 1920 + 2560, 1920 + 2560 + 1920]);
    }

    #[test]
    fn grid_layout() {
        let s = snap_with(vec![laptop(), dell("DP-1"), lg("DP-2"), lg("HDMI-A-1")], LidState::Open);
        let p = plan("extend-grid-2", &s).unwrap();
        let rows: HashSet<i32> = p.iter().map(|m| m.pos().unwrap().1).collect();
        assert_eq!(rows.len(), 2, "4 monitors in 2 columns = 2 rows: {p:?}");
        let rects: Vec<Rect> = p.iter().filter_map(|m| m.rect()).collect();
        assert!(layout_is_sound(&rects));
    }

    #[test]
    fn external_only_chains_from_origin() {
        let s = snap_with(vec![laptop(), dell("DP-1"), lg("HDMI-A-1")], LidState::Open);
        let p = plan("external-only", &s).unwrap();
        assert!(!get(&p, "eDP-1").enabled);
        let mut xs: Vec<i32> = p.iter().filter(|m| m.enabled).map(|m| m.pos().unwrap().0).collect();
        xs.sort();
        assert_eq!(xs, vec![0, 2560]);
        assert!(plan("external-only", &snap_with(vec![laptop()], LidState::Open)).is_err());
    }

    #[test]
    fn internal_only_and_desktop_primary_only() {
        let s = snap_with(vec![laptop(), dell("DP-1")], LidState::Open);
        let p = plan("internal-only", &s).unwrap();
        assert!(get(&p, "eDP-1").enabled);
        assert!(!get(&p, "DP-1").enabled);

        // Desktop: "pc-only" = primary display only, never zero screens.
        let d = snap_with(vec![dell("DP-1"), lg("HDMI-A-1")], LidState::Absent);
        let p = plan("pc-only", &d).unwrap();
        assert_eq!(p.iter().filter(|m| m.enabled).count(), 1);
    }

    #[test]
    fn mirror_source_selection() {
        let s = snap_with(vec![laptop(), dell("DP-1"), lg("HDMI-A-1")], LidState::Open);
        let p = plan("mirror", &s).unwrap();
        assert!(get(&p, "eDP-1").mirror_of.is_none(), "built-in panel is the source");
        assert_eq!(get(&p, "DP-1").mirror_of.as_deref(), Some("eDP-1"));
        assert_eq!(get(&p, "HDMI-A-1").mirror_of.as_deref(), Some("eDP-1"));

        // Clamshell: the primary external becomes the source.
        let c = snap_with(vec![laptop(), dell("DP-1"), lg("HDMI-A-1")], LidState::Closed);
        let p = plan("mirror", &c).unwrap();
        assert!(!get(&p, "eDP-1").enabled);
        let sources: Vec<&PlannedMonitor> = p.iter().filter(|m| m.enabled && m.mirror_of.is_none()).collect();
        assert_eq!(sources.len(), 1);
        assert_ne!(sources[0].name, "eDP-1");

        assert!(plan("mirror", &snap_with(vec![laptop()], LidState::Open)).is_err());
        assert!(plan("mirror", &snap_with(vec![laptop(), dell("DP-1")], LidState::Closed)).is_err(), "one usable display");
    }

    #[test]
    fn clamshell_rules() {
        let s = snap_with(vec![laptop(), dell("DP-1")], LidState::Closed);
        assert!(plan("internal-only", &s).is_err(), "can't show on a closed panel");
        let p = plan("extend", &s).unwrap();
        assert!(!get(&p, "eDP-1").enabled, "extend in clamshell uses externals only");
        assert_eq!(get(&p, "DP-1").pos(), Some((0, 0)));

        // Lid closed with nothing else: the panel stays on.
        let alone = snap_with(vec![laptop()], LidState::Closed);
        let p = plan("internal-only", &alone).unwrap();
        assert!(get(&p, "eDP-1").enabled);
    }

    #[test]
    fn ghost_outputs_are_cleaned_up() {
        let s = snap_full(vec![laptop(), dell("DP-1"), lg("DP-2")], LidState::Open, false, &["DP-2"]);
        assert_eq!(s.ghosts, vec!["DP-2".to_string()]);
        assert_eq!(s.managed.len(), 2);
        let p = plan("extend", &s).unwrap();
        assert!(!get(&p, "DP-2").enabled, "ghost disabled as part of the plan");
    }

    #[test]
    fn internal_panel_is_never_a_ghost() {
        let s = snap_full(vec![laptop(), dell("DP-1")], LidState::Closed, false, &["eDP-1"]);
        assert!(s.ghosts.is_empty());
        assert_eq!(s.internals().len(), 1);
    }

    #[test]
    fn mode_aliases_parse() {
        use ProjectionMode as P;
        assert_eq!(P::parse("pc-only"), Some(P::InternalOnly));
        assert_eq!(P::parse("dock-mode"), Some(P::ExternalOnly));
        assert_eq!(P::parse("extend"), Some(P::ExtendRight));
        assert_eq!(P::parse("extend-grid-3"), Some(P::ExtendGrid(3)));
        assert_eq!(P::parse("mirror"), Some(P::Mirror));
        assert_eq!(P::ExtendGrid(3).as_str(), "extend-grid-3");
        for m in [P::InternalOnly, P::ExternalOnly, P::ExtendRight, P::ExtendLeft, P::ExtendUp, P::ExtendDown, P::Mirror] {
            assert_eq!(P::parse(&m.as_str()), Some(m.clone()), "round trip {m:?}");
        }
    }

    // ---- safety -----------------------------------------------------------

    #[test]
    fn lock_safe_plan_only_enables_new_outputs() {
        let mut ext = dell("DP-1");
        ext.disabled = true;
        let s = snap_full(vec![laptop(), ext], LidState::Closed, true, &[]);
        let p = plan("external-only", &s).unwrap();
        let safe = lock_safe_plan(p, &s);
        assert_eq!(safe.len(), 1, "internal disable dropped while locked: {safe:?}");
        assert_eq!(safe[0].name, "DP-1");
        assert!(safe[0].enabled);
        assert_eq!(safe[0].mode, "preferred");
        assert_eq!(safe[0].position, "auto");
    }

    #[test]
    fn projected_state_counts_screens() {
        let s = snap_with(vec![laptop(), dell("DP-1")], LidState::Open);
        let plan = vec![PlannedMonitor::disabled("eDP-1"), PlannedMonitor::disabled("DP-1")];
        let (enabled, standalone) = projected_state(&plan, &s);
        assert!(enabled.is_empty() && standalone.is_empty(), "zero-monitor plan must be detectable");
    }

    #[test]
    fn mirror_chains_are_flattened() {
        let s = snap_with(vec![laptop(), dell("DP-1"), lg("HDMI-A-1")], LidState::Open);
        let pm = |m: &HyprMonitor| plan_for(&s, &MonitorsConfig::default(), m, &Overrides::default());
        let a = pm(&laptop());
        let mut b = pm(&dell("DP-1"));
        b.mirror_of = Some("eDP-1".into());
        let mut c = pm(&lg("HDMI-A-1"));
        c.mirror_of = Some("DP-1".into());
        let out = validate_plan(vec![a, b, c], &s, false).unwrap();
        assert_eq!(get(&out, "HDMI-A-1").mirror_of.as_deref(), Some("eDP-1"));
    }

    #[test]
    fn unsafe_names_rejected() {
        let s = snap_with(vec![laptop()], LidState::Open);
        let mut p = PlannedMonitor::disabled("eDP-1; rm -rf ~");
        p.enabled = true;
        assert!(validate_plan(vec![p], &s, true).is_err());
    }

    #[test]
    fn overlapping_layout_is_repaired() {
        let s = snap_with(vec![laptop(), dell("DP-1")], LidState::Open);
        let mut p = plan("extend", &s).unwrap();
        for m in p.iter_mut() {
            m.set_pos(0, 0);
        }
        assert!(fix_layout(&mut p, Align::Start), "overlap detected");
        let rects: Vec<Rect> = p.iter().filter_map(|m| m.rect()).collect();
        assert!(layout_is_sound(&rects), "{p:?}");
    }

    // ---- profiles ---------------------------------------------------------

    fn profile_from(snap: &Snapshot, p: &[PlannedMonitor], name: &str, lid: Option<&str>) -> DisplayProfile {
        let mut monitors = BTreeMap::new();
        for e in p {
            monitors.insert(
                snap.key(&e.name),
                SavedMonitorState {
                    enabled: e.enabled,
                    mode: e.mode.clone(),
                    position: e.position.clone(),
                    scale: e.scale,
                    transform: e.transform,
                    primary: false,
                    mirror_of: None,
                    vrr: None,
                    last_output: e.name.clone(),
                },
            );
        }
        DisplayProfile {
            name: name.into(),
            fingerprint: snap.fingerprint.clone(),
            mode: "custom".into(),
            monitors,
            auto: false,
            lid: lid.map(str::to_string),
            created_ms: 1,
            last_used_ms: 0,
        }
    }

    #[test]
    fn profile_follows_monitors_across_ports() {
        let before = snap_with(vec![laptop(), dell("DP-1"), lg("HDMI-A-1")], LidState::Open);
        let saved = plan("extend-left", &before).unwrap();
        let prof = profile_from(&before, &saved, "desk", None);

        // Same monitors, swapped ports after re-docking.
        let after = snap_with(vec![laptop(), dell("HDMI-A-1"), lg("DP-1")], LidState::Open);
        assert_eq!(after.fingerprint, prof.fingerprint);
        let p = build_profile_plan(&prof, &after, &MonitorsConfig::default()).unwrap();
        let dell_before = get(&saved, "DP-1").pos();
        assert_eq!(get(&p, "HDMI-A-1").pos(), dell_before, "Dell keeps its place on the new port");
    }

    #[test]
    fn find_profile_respects_lid() {
        let s = snap_with(vec![laptop(), dell("DP-1")], LidState::Open);
        let open = plan("extend", &s).unwrap();
        let mut cfg = MonitorsConfig::default();
        cfg.profiles.push(profile_from(&s, &open, "agnostic", None));
        cfg.profiles.push(profile_from(&s, &open, "docked-closed", Some("closed")));
        cfg.profiles.push(profile_from(&s, &open, "docked-open", Some("open")));

        assert_eq!(find_profile_for(&cfg, &s.fingerprint, LidState::Open).unwrap().name, "docked-open");
        assert_eq!(find_profile_for(&cfg, &s.fingerprint, LidState::Closed).unwrap().name, "docked-closed");
        cfg.profiles.retain(|p| p.name != "docked-open");
        assert_eq!(find_profile_for(&cfg, &s.fingerprint, LidState::Open).unwrap().name, "agnostic", "closed-lid profile never used with lid open");
        assert!(find_profile_for(&cfg, "other+fingerprint", LidState::Open).is_none());
    }

    #[test]
    fn config_is_backward_compatible() {
        let old = r#"{"default_policy_dual":"external-only","default_policy_multi":"extend",
            "profiles":[{"name":"Home","fingerprint":"a+b","mode":"extend",
            "monitors":{"a":{"enabled":true,"mode":"preferred","position":"0x0","scale":1.0,"primary":true,"last_output":"eDP-1"}}}]}"#;
        let cfg: MonitorsConfig = serde_json::from_str(old).expect("old config parses");
        assert_eq!(cfg.profiles.len(), 1);
        assert_eq!(cfg.default_policy_dual, "external-only");
        assert!(cfg.remember_layouts);
    }

    // ---- events -----------------------------------------------------------

    #[test]
    fn socket2_events() {
        assert_eq!(parse_event("monitoradded>>DP-3\n"), Some(HyprEvent::MonitorAdded("DP-3".into())));
        assert_eq!(parse_event("monitoraddedv2>>3,DP-3,Dell Inc. U2720Q, rev A"), Some(HyprEvent::MonitorAdded("DP-3".into())));
        assert_eq!(parse_event("monitorremovedv2>>1,HDMI-A-1,LG, 27GL850"), Some(HyprEvent::MonitorRemoved("HDMI-A-1".into())));
        assert_eq!(parse_event("monitorremoved>>HDMI-A-1"), Some(HyprEvent::MonitorRemoved("HDMI-A-1".into())));
        assert_eq!(parse_event("switch>>lid:on"), Some(HyprEvent::LidSwitch(true)));
        assert_eq!(parse_event("switch>>lid:off"), Some(HyprEvent::LidSwitch(false)));
        assert_eq!(parse_event("configreloaded>>"), Some(HyprEvent::ConfigReloaded));
        assert_eq!(parse_event("switch>>tablet:on"), None);
        assert_eq!(parse_event("monitoradded>>"), None);
        assert_eq!(parse_event("workspace>>2"), None);
        assert_eq!(parse_event("garbage"), None);
    }

    #[test]
    fn natural_ordering() {
        let mut names = vec!["DP-10", "DP-2", "HDMI-A-1", "DP-1"];
        names.sort_by_key(|n| natural_key(n));
        assert_eq!(names, vec!["DP-1", "DP-2", "DP-10", "HDMI-A-1"]);
    }
}
