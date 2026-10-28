use super::{dispatch, query_json};
use serde::{Deserialize, Serialize};
use std::env;
use std::fs;
use std::path::PathBuf;
use std::thread;
use std::time::Duration;

#[derive(Debug, Deserialize, Clone)]
pub struct HyprClientRef {
    pub address: String,
    pub class: String,
    pub title: String,
    pub workspace: WorkspaceRef,
    #[serde(default)]
    pub floating: bool,
}

#[derive(Debug, Deserialize, Clone)]
pub struct WorkspaceRef {
    pub id: i32,
    pub name: String,
}

#[derive(Debug, Deserialize, Default)]
pub struct ActiveWindowRef {
    pub address: String,
    #[serde(default)]
    pub workspace: Option<WorkspaceRef>,
}

#[derive(Debug, Deserialize, Default)]
pub struct CursorPosRef {
    #[serde(default)]
    pub x: i32,
    #[serde(default)]
    pub y: i32,
}

#[derive(Debug, Deserialize, Default, Clone)]
pub struct MonitorRef {
    pub id: i32,
    pub name: String,
    #[serde(default)]
    pub x: i32,
    #[serde(default)]
    pub y: i32,
    #[serde(default)]
    pub width: i32,
    #[serde(default)]
    pub height: i32,
    #[serde(default)]
    pub focused: bool,
    #[serde(rename = "specialWorkspace", default)]
    pub special_workspace: Option<WorkspaceRef>,
}

#[derive(Debug, Serialize, Deserialize, Default)]
struct ScratchpadState {
    last_active_terminal: Option<String>,
    last_active_files: Option<String>,
    last_cursor_terminal: Option<(i32, i32)>,
    last_cursor_files: Option<(i32, i32)>,
}

fn state_path() -> PathBuf {
    if let Ok(runtime) = env::var("XDG_RUNTIME_DIR") {
        PathBuf::from(runtime).join("nexa_scratchpad.json")
    } else {
        PathBuf::from("/tmp/nexa_scratchpad.json")
    }
}

fn load_state() -> ScratchpadState {
    let p = state_path();
    if let Ok(bytes) = fs::read(&p) {
        serde_json::from_slice(&bytes).unwrap_or_default()
    } else {
        ScratchpadState::default()
    }
}

fn save_state(state: &ScratchpadState) {
    let p = state_path();
    if let Ok(data) = serde_json::to_vec_pretty(state) {
        let _ = fs::write(p, data);
    }
}

fn debug(msg: &str) {
    if env::var_os("NEXA_DEBUG").is_some() {
        eprintln!("[nexa scratchpad] {msg}");
    }
}

fn get_target_dimensions(kind: &str) -> (i32, i32) {
    let (mon_w, mon_h) = query_json::<Vec<MonitorRef>>("monitors")
        .ok()
        .and_then(|ms| {
            ms.iter()
                .find(|m| m.focused)
                .cloned()
                .or_else(|| ms.first().cloned())
        })
        .map(|m| (m.width, m.height))
        .filter(|&(w, h)| w > 0 && h > 0)
        .unwrap_or((1920, 1080));

    match kind {
        "terminal" => (
            (mon_w as f64 * 0.55).round() as i32,
            (mon_h as f64 * 0.52).round() as i32,
        ),
        _ => (
            (mon_w as f64 * 0.55).round() as i32,
            (mon_h as f64 * 0.55).round() as i32,
        ),
    }
}

fn get_monitor_center() -> (i32, i32) {
    query_json::<Vec<MonitorRef>>("monitors")
        .ok()
        .and_then(|ms| {
            ms.iter()
                .find(|m| m.focused)
                .cloned()
                .or_else(|| ms.first().cloned())
        })
        .map(|m| (m.x + m.width / 2, m.y + m.height / 2))
        .filter(|&(x, y)| x > 0 && y > 0)
        .unwrap_or((960, 540))
}

/// True only if the special workspace is currently shown on a monitor.
/// Deliberately does NOT consult `activewindow`: it can lag or stay stale
/// after a special workspace is hidden.
pub fn is_special_workspace_open(kind: &str) -> bool {
    let target = format!("special:{kind}");
    match query_json::<Vec<MonitorRef>>("monitors") {
        Ok(monitors) => monitors.iter().any(|m| {
            m.special_workspace
                .as_ref()
                .map_or(false, |sw| sw.name == target)
        }),
        Err(_) => false,
    }
}

/// Polls until a client exists in the given workspace, or the timeout passes.
fn wait_for_client(target_ws: &str, timeout_ms: u64) -> bool {
    let steps = timeout_ms / 25;
    for _ in 0..steps {
        if let Ok(clients) = query_json::<Vec<HyprClientRef>>("clients") {
            if clients.iter().any(|c| c.workspace.name == target_ws) {
                return true;
            }
        }
        thread::sleep(Duration::from_millis(25));
    }
    false
}

fn lua_escape(s: &str) -> String {
    s.replace('\\', "\\\\").replace('"', "\\\"")
}

pub fn toggle_scratchpad(kind: &str) -> Result<(), String> {
    let is_open = is_special_workspace_open(kind);
    let mut state = load_state();
    debug(&format!("kind={kind} is_open={is_open}"));

    if is_open {
        // HIDE
        dispatch(&format!(r#"hl.dsp.workspace.toggle_special("{kind}")"#))?;

        let prev_addr = match kind {
            "terminal" => state.last_active_terminal.take(),
            "files" => state.last_active_files.take(),
            _ => None,
        };
        let prev_cursor = match kind {
            "terminal" => state.last_cursor_terminal.take(),
            "files" => state.last_cursor_files.take(),
            _ => None,
        };

        // Restore cursor position if remembered
        if let Some((cx, cy)) = prev_cursor {
            let _ = dispatch(&format!(r#"hl.dsp.cursor.move({{ x = {cx}, y = {cy} }})"#));
        }

        // Only restore focus to a window that still exists and is not special.
        if let Some(addr) = prev_addr.filter(|a| !a.is_empty()) {
            let still_valid = query_json::<Vec<HyprClientRef>>("clients")
                .map(|cs| {
                    cs.iter()
                        .any(|c| c.address == addr && !c.workspace.name.starts_with("special:"))
                })
                .unwrap_or(false);
            if still_valid {
                let _ = dispatch(&format!(r#"hl.dsp.focus({{ window = "address:{addr}" }})"#));
            }
        }

        save_state(&state);
        return Ok(());
    }

    // OPEN
    let other_kind = if kind == "terminal" { "files" } else { "terminal" };
    if is_special_workspace_open(other_kind) {
        let _ = dispatch(&format!(r#"hl.dsp.workspace.toggle_special("{other_kind}")"#));
    }

    if let Ok(active) = query_json::<ActiveWindowRef>("activewindow") {
        let ws_name = active.workspace.map(|w| w.name).unwrap_or_default();
        if !ws_name.starts_with("special:") && !active.address.is_empty() {
            match kind {
                "terminal" => state.last_active_terminal = Some(active.address.clone()),
                "files" => state.last_active_files = Some(active.address.clone()),
                _ => {}
            }
        }
    }
    if let Ok(cur) = query_json::<CursorPosRef>("cursorpos") {
        match kind {
            "terminal" => state.last_cursor_terminal = Some((cur.x, cur.y)),
            "files" => state.last_cursor_files = Some((cur.x, cur.y)),
            _ => {}
        }
    }
    save_state(&state);

    let target_ws = format!("special:{kind}");
    let clients: Vec<HyprClientRef> = query_json("clients").unwrap_or_default();
    let existing = clients.iter().find(|c| c.workspace.name == target_ws);
    debug(&format!("existing_client={}", existing.is_some()));

    if let Some(client) = existing {
        // Ensure floating geometry if previously spawned or reset as tiled
        if !client.floating {
            let (w, h) = get_target_dimensions(kind);
            let addr = &client.address;
            let _ = dispatch(&format!(r#"hl.dsp.window.float({{ window = "address:{addr}" }})"#));
            let _ = dispatch(&format!(
                r#"hl.dsp.window.resize({{ x = {w}, y = {h}, relative = false, window = "address:{addr}" }})"#
            ));
            let _ = dispatch(&format!(r#"hl.dsp.window.center({{ window = "address:{addr}" }})"#));
        }

        // Toggle special workspace into view
        dispatch(&format!(r#"hl.dsp.workspace.toggle_special("{kind}")"#))?;

        // Focus floating scratchpad by positioning cursor at scratchpad center
        let (cx, cy) = get_monitor_center();
        let _ = dispatch(&format!(r#"hl.dsp.cursor.move({{ x = {cx}, y = {cy} }})"#));
        return Ok(());
    }

    // COLD LAUNCH: start silently in the special workspace with explicit floating geometry, wait until it maps, toggle once.
    let (w, h) = get_target_dimensions(kind);
    let command_to_run = match kind {
        "terminal" => {
            let term = env::var("TERMINAL").unwrap_or_else(|_| "kitty".to_string());
            format!("[workspace special:terminal silent; float; size {w} {h}; center] {term}")
        }
        "files" => {
            let fm = env::var("FILE_MANAGER").unwrap_or_else(|_| "dolphin".to_string());
            format!("[workspace special:files silent; float; size {w} {h}; center] {fm}")
        }
        other => format!("[workspace special:{other} silent; float; size {w} {h}; center] {other}"),
    };

    let _ = super::hypr_command(&format!(
        r#"eval hl.exec_cmd("{}")"#,
        lua_escape(&command_to_run)
    ))?;

    if wait_for_client(&target_ws, 5000) {
        debug("client mapped, toggling");
        dispatch(&format!(r#"hl.dsp.workspace.toggle_special("{kind}")"#))?;
        let (cx, cy) = get_monitor_center();
        let _ = dispatch(&format!(r#"hl.dsp.cursor.move({{ x = {cx}, y = {cy} }})"#));
        Ok(())
    } else {
        Err(format!("timed out waiting for a window in {target_ws}"))
    }
}
