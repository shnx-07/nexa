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

/// may stop reading at any time; that must never panic the CLI). Returns
/// `false` when the reader is gone.
pub(crate) fn emit_line(s: &str) -> bool {
    let mut out = std::io::stdout().lock();
    writeln!(out, "{s}").and_then(|_| out.flush()).is_ok()
}

macro_rules! emit {
    ($($arg:tt)*) => {{
        let _ = emit_line(&format!($($arg)*));
    }};
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

pub(crate) const EXIT_OK: i32 = 0;
pub(crate) const EXIT_ERR: i32 = 1;
pub(crate) const EXIT_USAGE: i32 = 2;
pub(crate) const EXIT_DEFERRED: i32 = 3;

pub(crate) const CLI_HELP: &str = "\
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

pub(crate) struct CliOut {
    pub(crate) json: bool,
}

impl CliOut {
    pub(crate) fn ok(&self, msg: &str, data: Value) -> i32 {
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
    pub(crate) fn deferred(&self, msg: &str) -> i32 {
        if self.json {
            emit!("{}", json!({"ok": true, "deferred": true, "message": msg}));
        } else {
            emit!("{msg}");
        }
        EXIT_DEFERRED
    }
    pub(crate) fn err(&self, msg: &str) -> i32 {
        if self.json {
            emit!("{}", json!({"ok": false, "error": msg}));
        } else {
            eprintln!("nexad display: {msg}");
        }
        EXIT_ERR
    }
    pub(crate) fn usage(&self, msg: &str) -> i32 {
        if self.json {
            emit!("{}", json!({"ok": false, "error": msg, "usage": true}));
        } else {
            eprintln!("nexad display: {msg}\n\n{CLI_HELP}");
        }
        EXIT_USAGE
    }
    pub(crate) fn report(&self, what: &str, r: Result<CommitReport, String>) -> i32 {
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
    pub(crate) fn outcome(&self, what: &str, r: Result<ApplyOutcome, String>) -> i32 {
        match r {
            Err(e) => self.err(&e),
            Ok(ApplyOutcome::Deferred) => self.deferred(&format!("{what}: session locked; will apply after unlock")),
            Ok(ApplyOutcome::NoChange) => self.ok(&format!("{what}: already active"), json!({"outcome": "no-change"})),
            Ok(ApplyOutcome::Applied) => self.ok(&format!("{what}: applied"), json!({"outcome": "applied"})),
        }
    }
    pub(crate) fn resolved(&self, r: Result<ResolveResult, String>) -> i32 {
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

pub(crate) fn parse_scale_arg(s: &str) -> Result<Option<f64>, String> {
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

