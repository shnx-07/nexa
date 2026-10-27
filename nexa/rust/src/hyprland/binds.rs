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
pub struct MonitorRef {
    pub id: i32,
    pub name: String,
    #[serde(rename = "specialWorkspace", default)]
    pub special_workspace: Option<WorkspaceRef>,
}

#[derive(Debug, Serialize, Deserialize, Default)]
struct ScratchpadState {
    last_active_terminal: Option<String>,
    last_active_files: Option<String>,
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

/// Checks whether a specific special workspace (e.g. "special:terminal") is currently on screen.
pub fn is_special_workspace_open(kind: &str) -> bool {
    let target = format!("special:{kind}");

    if let Ok(monitors) = query_json::<Vec<MonitorRef>>("monitors") {
        for m in monitors {
            if let Some(sw) = m.special_workspace {
                if sw.name == target {
                    return true;
                }
            }
        }
    }

    if let Ok(active) = query_json::<ActiveWindowRef>("activewindow") {
        if let Some(ws) = active.workspace {
            if ws.name == target {
                return true;
            }
        }
    }

    false
}

/// Toggles a persistent scratchpad ("terminal" or "files") with automatic focus
/// restoration, state memory, and mutual exclusion.
pub fn toggle_scratchpad(kind: &str) -> Result<(), String> {
    let is_open = is_special_workspace_open(kind);
    let mut state = load_state();

    if is_open {
        // HIDE SCRATCHPAD
        dispatch(&format!(r#"hl.dsp.workspace.toggle_special("{kind}")"#))?;

        // Restore focus to previously active window
        let prev_addr = match kind {
            "terminal" => state.last_active_terminal.take(),
            "files" => state.last_active_files.take(),
            _ => None,
        };

        if let Some(addr) = prev_addr {
            if !addr.is_empty() {
                let _ = dispatch(&format!(r#"hl.dsp.focus({{ window = "address:{addr}" }})"#));
            }
        }

        save_state(&state);
        return Ok(());
    }

    // OPENING SCRATCHPAD:
    // 1. Mutual exclusion: If the other scratchpad is open, close it first
    let other_kind = if kind == "terminal" { "files" } else { "terminal" };
    if is_special_workspace_open(other_kind) {
        let _ = dispatch(&format!(r#"hl.dsp.workspace.toggle_special("{other_kind}")"#));
    }

    // 2. Remember current active window before opening scratchpad
    if let Ok(active) = query_json::<ActiveWindowRef>("activewindow") {
        let ws_name = active.workspace.map(|w| w.name).unwrap_or_default();
        if !ws_name.starts_with("special:") && !active.address.is_empty() {
            match kind {
                "terminal" => state.last_active_terminal = Some(active.address.clone()),
                "files" => state.last_active_files = Some(active.address.clone()),
                _ => {}
            }
            save_state(&state);
        }
    }

    // 3. Find if the scratchpad window already exists in this special workspace
    let target_ws = format!("special:{kind}");
    let clients: Vec<HyprClientRef> = query_json("clients").unwrap_or_default();
    let existing = clients.iter().find(|c| c.workspace.name == target_ws);

    if let Some(client) = existing {
        // Window already mapped — toggle into view & focus immediately
        dispatch(&format!(r#"hl.dsp.workspace.toggle_special("{kind}")"#))?;
        let _ = dispatch(&format!(r#"hl.dsp.focus({{ window = "address:{}" }})"#, client.address));
    } else {
        // Window not launched yet — spawn on special workspace
        let command_to_run = match kind {
            "terminal" => {
                let term = env::var("TERMINAL").unwrap_or_else(|_| "kitty".to_string());
                format!("[workspace special:terminal] {term}")
            }
            "files" => {
                let fm = env::var("FILE_MANAGER").unwrap_or_else(|_| "dolphin".to_string());
                format!("[workspace special:files] {fm}")
            }
            other => format!("[workspace special:{other}] {other}"),
        };

        let _ = dispatch(&format!(r#"hl.dsp.exec_cmd("{command_to_run}")"#));
        dispatch(&format!(r#"hl.dsp.workspace.toggle_special("{kind}")"#))?;

        // Fast poll loop: waits up to 600ms for the new window to map and focuses it instantly
        let kind_clone = kind.to_string();
        thread::spawn(move || {
            let target = format!("special:{kind_clone}");
            for _ in 0..15 {
                thread::sleep(Duration::from_millis(40));
                if let Ok(cls) = query_json::<Vec<HyprClientRef>>("clients") {
                    if let Some(c) = cls.iter().find(|w| w.workspace.name == target) {
                        let _ = dispatch(&format!(r#"hl.dsp.focus({{ window = "address:{}" }})"#, c.address));
                        break;
                    }
                }
            }
        });
    }

    Ok(())
}

