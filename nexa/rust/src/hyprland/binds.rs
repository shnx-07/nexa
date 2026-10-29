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
#[serde(default)]
struct ScratchpadState {
    last_active_terminal: Option<String>,
    last_active_files: Option<String>,
    last_cursor_terminal: Option<(i32, i32)>,
    last_cursor_files: Option<(i32, i32)>,
    /// Which scratchpad we opened and have not yet restored focus for.
    active_kind: Option<String>,
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

/// Mutable access to the (previous window, previous cursor) slots for one scratchpad kind.
fn slots<'a>(
    s: &'a mut ScratchpadState,
    kind: &str,
) -> Option<(&'a mut Option<String>, &'a mut Option<(i32, i32)>)> {
    match kind {
        "terminal" => Some((&mut s.last_active_terminal, &mut s.last_cursor_terminal)),
        "files" => Some((&mut s.last_active_files, &mut s.last_cursor_files)),
        _ => None,
    }
}

fn focused_monitor() -> Option<MonitorRef> {
    query_json::<Vec<MonitorRef>>("monitors").ok().and_then(|ms| {
        ms.iter()
            .find(|m| m.focused)
            .cloned()
            .or_else(|| ms.first().cloned())
    })
}

fn get_target_dimensions(kind: &str) -> (i32, i32) {
    let (mon_w, mon_h) = focused_monitor()
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
    focused_monitor()
        .filter(|m| m.width > 0 && m.height > 0)
        .map(|m| (m.x + m.width / 2, m.y + m.height / 2))
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

/// True if any special workspace is currently shown on any monitor.
fn any_special_open() -> bool {
    match query_json::<Vec<MonitorRef>>("monitors") {
        Ok(monitors) => monitors.iter().any(|m| {
            m.special_workspace
                .as_ref()
                .map_or(false, |sw| !sw.name.is_empty())
        }),
        Err(_) => false,
    }
}

/// True if either the terminal scratchpad (SUPER + SHIFT + RETURN)
/// or the files scratchpad (SUPER + E) is currently active on screen.
pub fn is_scratchpad_active() -> bool {
    is_special_workspace_open("terminal") || is_special_workspace_open("files")
}

/// Handles standard terminal launch (SUPER + Return).
/// If any scratchpad is active on screen, this does nothing to prevent opening an extra terminal.
pub fn handle_normal_terminal() -> Result<(), String> {
    if is_scratchpad_active() {
        debug("Scratchpad active on screen; suppressing normal terminal launch (SUPER + Return)");
        return Ok(());
    }

    let term = env::var("TERMINAL").unwrap_or_else(|_| "kitty".to_string());
    debug(&format!("Launching normal terminal: {term}"));
    let _ = dispatch(&format!(r#"hl.dsp.exec_cmd("{term}")"#));
    Ok(())
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

/// Polls until the special workspace `kind` is (or is not) shown on a monitor.
fn wait_for_special(kind: &str, want_open: bool, timeout_ms: u64) -> bool {
    let steps = timeout_ms / 20;
    for _ in 0..steps {
        if is_special_workspace_open(kind) == want_open {
            return true;
        }
        thread::sleep(Duration::from_millis(20));
    }
    false
}

fn find_client_address(target_ws: &str) -> Option<String> {
    query_json::<Vec<HyprClientRef>>("clients")
        .ok()
        .and_then(|cs| {
            cs.into_iter()
                .find(|c| c.workspace.name == target_ws)
                .map(|c| c.address)
        })
}

fn active_address() -> Option<String> {
    query_json::<ActiveWindowRef>("activewindow")
        .ok()
        .map(|a| a.address)
}

/// Focuses a window and verifies that Hyprland actually applied it.
/// Only call this once the window's workspace is already on screen,
/// otherwise the focus dispatch itself can flip the special workspace.
fn focus_window(addr: &str) -> bool {
    for attempt in 0..4 {
        let _ = dispatch(&format!(r#"hl.dsp.focus({{ window = "address:{addr}" }})"#));
        thread::sleep(Duration::from_millis(40));
        if active_address().as_deref() == Some(addr) {
            debug(&format!("focus ok on attempt {attempt}"));
            return true;
        }
    }
    debug("focus did not stick");
    false
}

/// Moves focus to the scratchpad window once it is on screen.
fn focus_scratchpad(target_ws: &str) {
    // Park the cursor over the (centered) scratchpad so follow_mouse
    // does not hand focus back to the window underneath.
    let (cx, cy) = get_monitor_center();
    let _ = dispatch(&format!(r#"hl.dsp.cursor.move({{ x = {cx}, y = {cy} }})"#));

    if let Some(addr) = find_client_address(target_ws) {
        focus_window(&addr);
    } else {
        debug("no client found to focus");
    }
}

fn lua_escape(s: &str) -> String {
    s.replace('\\', "\\\\").replace('"', "\\\"")
}

/// Restores focus (and cursor) to the window that was active before the scratchpad
/// opened. Safe to call repeatedly: it consumes the saved state, so a second call is a no-op.
/// `force_kind` is used by the explicit hide path; the daemon passes None.
fn restore_previous(force_kind: Option<&str>) {
    let mut state = load_state();

    let kind = match (force_kind, state.active_kind.clone()) {
        (Some(k), _) => k.to_string(),
        (None, Some(k)) => k,
        (None, None) => return,
    };

    // If some scratchpad is on screen again (e.g. switching between them), do nothing.
    if force_kind.is_none() && any_special_open() {
        return;
    }

    let (prev_addr, prev_cursor) = match slots(&mut state, &kind) {
        Some((a, c)) => (a.take(), c.take()),
        None => (None, None),
    };
    state.active_kind = None;
    save_state(&state);

    if let Some((cx, cy)) = prev_cursor {
        let _ = dispatch(&format!(r#"hl.dsp.cursor.move({{ x = {cx}, y = {cy} }})"#));
    }

    if let Some(addr) = prev_addr.filter(|a| !a.is_empty()) {
        let still_valid = query_json::<Vec<HyprClientRef>>("clients")
            .map(|cs| {
                cs.iter()
                    .any(|c| c.address == addr && !c.workspace.name.starts_with("special:"))
            })
            .unwrap_or(false);
        if still_valid {
            focus_window(&addr);
        } else {
            debug("previous window is gone; leaving focus to Hyprland");
        }
    }
}

/// Called by the event daemon when a special workspace has just closed
/// (`activespecial>>,MONITOR`). This covers closing the scratchpad window,
/// which empties and auto-hides the special workspace without going through
/// `toggle_scratchpad`.
pub fn restore_focus_after_scratchpad_closed() {
    thread::sleep(Duration::from_millis(50));
    restore_previous(None);
}

pub fn toggle_scratchpad(kind: &str) -> Result<(), String> {
    let is_open = is_special_workspace_open(kind);
    debug(&format!("kind={kind} is_open={is_open}"));

    if is_open {
        // HIDE
        dispatch(&format!(r#"hl.dsp.workspace.toggle_special("{kind}")"#))?;
        wait_for_special(kind, false, 800);
        restore_previous(Some(kind));
        return Ok(());
    }

    // OPEN
    let mut state = load_state();
    let other_kind = if kind == "terminal" { "files" } else { "terminal" };
    let other_open = is_special_workspace_open(other_kind);

    // Work out which window/cursor to return to later.
    // If the other scratchpad is open, the active window is inside it, so inherit its saved target.
    let (prev_addr, prev_cursor) = if other_open {
        match slots(&mut state, other_kind) {
            Some((a, c)) => (a.take(), c.take()),
            None => (None, None),
        }
    } else {
        let addr = query_json::<ActiveWindowRef>("activewindow")
            .ok()
            .and_then(|a| {
                let ws = a.workspace.map(|w| w.name).unwrap_or_default();
                if !ws.starts_with("special:") && !a.address.is_empty() {
                    Some(a.address)
                } else {
                    None
                }
            });
        let cur = query_json::<CursorPosRef>("cursorpos")
            .ok()
            .map(|c| (c.x, c.y));
        (addr, cur)
    };

    if let Some((a, c)) = slots(&mut state, kind) {
        *a = prev_addr;
        *c = prev_cursor;
    }
    // Clear active_kind so the daemon ignores the close event of the other scratchpad.
    state.active_kind = None;
    save_state(&state);

    if other_open {
        let _ = dispatch(&format!(r#"hl.dsp.workspace.toggle_special("{other_kind}")"#));
        wait_for_special(other_kind, false, 800);
    }

    let target_ws = format!("special:{kind}");
    let clients: Vec<HyprClientRef> = query_json("clients").unwrap_or_default();
    let existing = clients.iter().find(|c| c.workspace.name == target_ws).cloned();
    debug(&format!("existing_client={}", existing.is_some()));

    if let Some(client) = existing {
        // Ensure floating geometry if the window got reset to tiled.
        if !client.floating {
            let (w, h) = get_target_dimensions(kind);
            let addr = &client.address;
            let _ = dispatch(&format!(r#"hl.dsp.window.float({{ window = "address:{addr}" }})"#));
            let _ = dispatch(&format!(
                r#"hl.dsp.window.resize({{ x = {w}, y = {h}, relative = false, window = "address:{addr}" }})"#
            ));
            let _ = dispatch(&format!(r#"hl.dsp.window.center({{ window = "address:{addr}" }})"#));
        }
    } else {
        // COLD LAUNCH: start silently in the special workspace with floating geometry,
        // then wait until the window has mapped.
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

        if !wait_for_client(&target_ws, 5000) {
            return Err(format!("timed out waiting for a window in {target_ws}"));
        }
        // Let the window finish its first configure and apply its rules.
        thread::sleep(Duration::from_millis(60));
        debug("client mapped");
    }

    // Mark this scratchpad as the one to restore focus from, then show it.
    state.active_kind = Some(kind.to_string());
    save_state(&state);

    dispatch(&format!(r#"hl.dsp.workspace.toggle_special("{kind}")"#))?;

    // Only focus after Hyprland reports the special workspace on screen.
    // Focusing earlier is what made the workspace flip back.
    if !wait_for_special(kind, true, 1500) {
        state.active_kind = None;
        save_state(&state);
        return Err(format!("{target_ws} did not become visible"));
    }

    focus_scratchpad(&target_ws);
    Ok(())
}
