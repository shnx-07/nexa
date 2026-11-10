use serde::{Deserialize, Serialize};
use std::io::{BufRead, BufReader, Read, Write};
use std::os::unix::net::UnixStream;
use std::path::PathBuf;
use std::process::Command;
use std::thread;
use std::time::{Duration, Instant};

// ============================================================
// RAW HYPRLAND TYPES
// ============================================================

#[derive(Debug, Deserialize, Default, Clone)]
struct HyprWorkspaceRef {
    #[serde(default)]
    id: Option<i32>,

    #[serde(default)]
    name: String,
}

#[derive(Debug, Deserialize, Default, Clone)]
struct HyprWorkspace {
    #[serde(default)]
    id: Option<i32>,

    #[serde(default)]
    name: String,

    #[serde(default)]
    monitor: String,
}

#[derive(Debug, Deserialize)]
struct HyprClient {
    address: String,

    #[serde(default)]
    mapped: bool,

    #[serde(default)]
    hidden: bool,

    #[serde(default)]
    at: [i32; 2],

    #[serde(default)]
    size: [i32; 2],

    #[serde(default)]
    workspace: HyprWorkspaceRef,

    #[serde(default)]
    floating: bool,

    #[serde(default)]
    pinned: bool,

    #[serde(default)]
    monitor: i32,

    #[serde(default)]
    class: String,

    #[serde(default)]
    title: String,

    #[serde(rename = "initialClass", default)]
    initial_class: String,

    #[serde(rename = "initialTitle", default)]
    initial_title: String,

    #[serde(default)]
    pid: i32,

    #[serde(default)]
    xwayland: bool,
}

#[derive(Debug, Deserialize, Default)]
struct HyprActiveWorkspace {
    #[serde(default)]
    id: i32,

    #[serde(default)]
    name: String,
}

#[derive(Debug, Deserialize, Default)]
struct HyprActiveWindow {
    #[serde(default)]
    address: String,
}

#[derive(Debug, Deserialize, Default, Clone)]
struct HyprSpecialWorkspaceRef {
    #[serde(default)]
    id: Option<i32>,

    #[serde(default)]
    name: String,
}

#[derive(Debug, Deserialize, Default, Clone)]
struct HyprMonitor {
    #[serde(default)]
    id: i32,

    #[serde(default)]
    name: String,

    #[serde(default)]
    x: i32,

    #[serde(default)]
    y: i32,

    #[serde(default)]
    width: i32,

    #[serde(default)]
    height: i32,

    #[serde(default)]
    scale: f64,

    #[serde(default)]
    focused: bool,

    #[serde(rename = "specialWorkspace", default)]
    special_workspace: Option<HyprSpecialWorkspaceRef>,
}

// ============================================================
// NEXA OUTPUT TYPES
// ============================================================

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct WorkspaceState {
    active_workspace: i32,
    active_window: String,

    workspaces: Vec<WorkspaceInfo>,
    special_workspaces: Vec<SpecialWorkspaceInfo>,
    monitors: Vec<MonitorInfo>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct WorkspaceInfo {
    id: i32,
    name: String,

    exists: bool,
    active: bool,

    monitor: String,

    windows: Vec<WorkspaceWindow>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct SpecialWorkspaceInfo {
    id: i32,

    name: String,
    display_name: String,
    icon: String,
    window_count: usize,

    active: bool,

    monitor: String,

    windows: Vec<WorkspaceWindow>,
}

#[derive(Debug, Serialize, Clone)]
#[serde(rename_all = "camelCase")]
pub struct WorkspaceWindow {
    pub address: String,
    pub norm_address: String,

    pub class: String,
    pub title: String,

    pub initial_class: String,
    pub initial_title: String,

    pub pid: i32,

    pub x: i32,
    pub y: i32,

    pub width: i32,
    pub height: i32,

    pub rel_x: f64,
    pub rel_y: f64,
    pub rel_width: f64,
    pub rel_height: f64,

    pub floating: bool,
    pub pinned: bool,

    pub hidden: bool,
    pub mapped: bool,

    pub xwayland: bool,

    pub monitor_id: i32,

    pub focused: bool,
}

#[derive(Debug, Serialize, Clone)]
#[serde(rename_all = "camelCase")]
pub struct MonitorInfo {
    id: i32,
    name: String,

    x: i32,
    y: i32,

    width: i32,
    height: i32,

    scale: f64,

    focused: bool,
}

// ============================================================
// HYPRLAND SOCKET IPC (Direct Zero-Fork UNIX Domain Socket)
// ============================================================

fn get_hyprland_socket_path(socket_idx: u8) -> Result<PathBuf, String> {
    let sock_name = if socket_idx == 2 {
        ".socket2.sock"
    } else {
        ".socket.sock"
    };

    let sig = std::env::var("HYPRLAND_INSTANCE_SIGNATURE").ok();
    let runtime_dir = std::env::var("XDG_RUNTIME_DIR").unwrap_or_else(|_| {
        let uid = unsafe { libc::getuid() };
        format!("/run/user/{uid}")
    });

    if let Some(ref s) = sig {
        let p1 = PathBuf::from(&runtime_dir).join("hypr").join(s).join(sock_name);
        if p1.exists() {
            return Ok(p1);
        }
        let p2 = PathBuf::from("/tmp/hypr").join(s).join(sock_name);
        if p2.exists() {
            return Ok(p2);
        }
    }

    for base in &[
        PathBuf::from(&runtime_dir).join("hypr"),
        PathBuf::from("/tmp/hypr"),
    ] {
        if let Ok(entries) = std::fs::read_dir(base) {
            let mut candidates: Vec<PathBuf> = entries
                .flatten()
                .map(|e| e.path().join(sock_name))
                .filter(|p| p.exists())
                .collect();
            if let Some(first) = candidates.pop() {
                return Ok(first);
            }
        }
    }

    Err("Hyprland IPC socket not found".to_string())
}

fn hypr_socket_request(query: &str) -> Result<Vec<u8>, String> {
    let path = get_hyprland_socket_path(1)?;
    let mut stream = UnixStream::connect(&path)
        .map_err(|e| format!("Hyprland socket connect error: {e}"))?;
    stream
        .set_read_timeout(Some(Duration::from_millis(600)))
        .ok();
    stream
        .set_write_timeout(Some(Duration::from_millis(600)))
        .ok();

    stream
        .write_all(query.as_bytes())
        .map_err(|e| format!("Hyprland socket write error: {e}"))?;

    let mut buf = Vec::with_capacity(16384);
    stream
        .read_to_end(&mut buf)
        .map_err(|e| format!("Hyprland socket read error: {e}"))?;

    Ok(buf)
}

fn hypr_json<T: for<'de> Deserialize<'de>>(endpoint: &str) -> Result<T, String> {
    match hypr_socket_request(&format!("j/{endpoint}")) {
        Ok(bytes) => {
            serde_json::from_slice(&bytes)
                .map_err(|error| format!("failed to parse hyprland socket {endpoint}: {error}"))
        }
        Err(_) => {
            hyprctl_json(endpoint)
        }
    }
}

fn hyprctl_json<T>(section: &str) -> Result<T, String>
where
    T: for<'de> Deserialize<'de>,
{
    let output = Command::new("hyprctl")
        .args(["-j", section])
        .output()
        .map_err(|error| format!("failed to execute hyprctl: {error}"))?;

    if !output.status.success() {
        let stdout = String::from_utf8_lossy(&output.stdout);
        let stderr = String::from_utf8_lossy(&output.stderr);
        let message = if !stderr.trim().is_empty() {
            stderr.trim()
        } else if !stdout.trim().is_empty() {
            stdout.trim()
        } else {
            "unknown hyprctl error"
        };

        return Err(format!("hyprctl -j {section} failed: {message}"));
    }

    serde_json::from_slice(&output.stdout)
        .map_err(|error| format!("failed to parse hyprctl {section}: {error}"))
}

// ============================================================
// LUA / DISPATCH HELPERS
// ============================================================

fn lua_escape(value: &str) -> String {
    value.replace('\\', "\\\\").replace('"', "\\\"")
}

fn window_selector(address: &str) -> Result<String, String> {
    let address = address.trim();

    if address.is_empty() {
        return Err("window address is empty".to_string());
    }

    if address.starts_with("0x") {
        Ok(format!("address:{}", address))
    } else {
        Ok(format!("address:0x{}", address))
    }
}

fn hypr_dispatch(expression: &str) -> Result<(), String> {
    let req = format!("dispatch {expression}");
    match hypr_socket_request(&req) {
        Ok(bytes) => {
            let res = String::from_utf8_lossy(&bytes);
            if res.starts_with("ok") {
                Ok(())
            } else if res.contains("error:") {
                hyprctl_dispatch(expression)
            } else {
                Ok(())
            }
        }
        Err(_) => {
            hyprctl_dispatch(expression)
        }
    }
}

fn hyprctl_dispatch(expression: &str) -> Result<(), String> {
    let output = Command::new("hyprctl")
        .args(["dispatch", expression])
        .output()
        .map_err(|error| format!("failed to execute hyprctl: {error}"))?;

    if !output.status.success() {
        let stdout = String::from_utf8_lossy(&output.stdout);
        let stderr = String::from_utf8_lossy(&output.stderr);
        let message = if !stderr.trim().is_empty() {
            stderr.trim()
        } else if !stdout.trim().is_empty() {
            stdout.trim()
        } else {
            "unknown Hyprland error"
        };

        return Err(format!("Hyprland dispatch failed: {message}"));
    }

    Ok(())
}

// ============================================================
// WINDOW CONVERSION
// ============================================================

fn make_window(
    client: &HyprClient,
    active_window: &str,
    monitors: &[HyprMonitor],
) -> WorkspaceWindow {
    let norm_addr = client.address.trim_start_matches("0x").to_lowercase();
    let norm_active = active_window.trim_start_matches("0x").to_lowercase();
    let is_focused = !norm_active.is_empty() && norm_addr == norm_active;

    let mon = monitors
        .iter()
        .find(|m| m.id == client.monitor)
        .or_else(|| monitors.first());

    let (mon_x, mon_y, mon_w, mon_h) = if let Some(m) = mon {
        (
            m.x,
            m.y,
            if m.width > 0 { m.width } else { 1920 },
            if m.height > 0 { m.height } else { 1080 },
        )
    } else {
        (0, 0, 1920, 1080)
    };

    let rel_x = ((client.at[0] - mon_x).max(0) as f64 / mon_w as f64).clamp(0.0, 1.0);
    let rel_y = ((client.at[1] - mon_y).max(0) as f64 / mon_h as f64).clamp(0.0, 1.0);
    let rel_w = (client.size[0].max(1) as f64 / mon_w as f64).clamp(0.02, 1.0);
    let rel_h = (client.size[1].max(1) as f64 / mon_h as f64).clamp(0.02, 1.0);

    WorkspaceWindow {
        address: client.address.clone(),
        norm_address: norm_addr,

        class: client.class.clone(),
        title: client.title.clone(),

        initial_class: client.initial_class.clone(),
        initial_title: client.initial_title.clone(),

        pid: client.pid,

        x: client.at[0],
        y: client.at[1],

        width: client.size[0],
        height: client.size[1],

        rel_x,
        rel_y,
        rel_width: rel_w,
        rel_height: rel_h,

        floating: client.floating,
        pinned: client.pinned,

        hidden: client.hidden,
        mapped: client.mapped,

        xwayland: client.xwayland,

        monitor_id: client.monitor,

        focused: is_focused,
    }
}

fn scratchpad_icon(display_name: &str) -> &'static str {
    match display_name.to_lowercase().as_str() {
        "terminal" => "󰆍",
        "files" => "󰉋",
        "magic" | "quick scratchpad" => "󰏤",
        "music" => "󰝚",
        "chat" => "󰭹",
        _ => "󰏤",
    }
}

// ============================================================
// WORKSPACE INFO
// ============================================================

pub fn info() -> Result<WorkspaceState, String> {
    let hypr_workspaces: Vec<HyprWorkspace> = hypr_json("workspaces")?;
    let clients: Vec<HyprClient> = hypr_json("clients")?;
    let active_workspace: HyprActiveWorkspace = hypr_json("activeworkspace")?;
    let active_window: HyprActiveWindow = hypr_json("activewindow").unwrap_or_default();
    let hypr_monitors: Vec<HyprMonitor> = hypr_json("monitors")?;

    // ========================================================
    // REGULAR WORKSPACES 1 - 10
    //
    // Always return all 10 so the grid never shifts.
    // ========================================================

    let mut workspaces = Vec::with_capacity(10);

    for id in 1..=10 {
        let ws_str = id.to_string();
        let workspace = hypr_workspaces
            .iter()
            .find(|ws| ws.id == Some(id) || ws.name == ws_str);

        let mut windows: Vec<WorkspaceWindow> = clients
            .iter()
            .filter(|client| {
                client.workspace.id == Some(id) || client.workspace.name == ws_str
            })
            .map(|client| make_window(client, &active_window.address, &hypr_monitors))
            .collect();

        windows.sort_by_key(|window| (window.y, window.x, window.pid));

        workspaces.push(WorkspaceInfo {
            id,
            name: workspace
                .map(|ws| ws.name.clone())
                .unwrap_or_else(|| ws_str),
            exists: workspace.is_some(),
            active: active_workspace.id == id || active_workspace.name == id.to_string(),
            monitor: workspace
                .map(|ws| ws.monitor.clone())
                .unwrap_or_default(),
            windows,
        });
    }

    // ========================================================
    // SPECIAL WORKSPACES
    // ========================================================

    let mut special_workspaces = Vec::new();

    let active_special_names: Vec<String> = hypr_monitors
        .iter()
        .filter_map(|m| {
            m.special_workspace.as_ref().and_then(|s| {
                let id_val = s.id.unwrap_or(0);
                if id_val != 0 && !s.name.is_empty() {
                    Some(
                        s.name
                            .strip_prefix("special:")
                            .unwrap_or(&s.name)
                            .to_string(),
                    )
                } else {
                    None
                }
            })
        })
        .collect();

    for workspace in hypr_workspaces
        .iter()
        .filter(|ws| ws.name.starts_with("special:") || ws.id.unwrap_or(0) < 0)
    {
        let display_name = workspace
            .name
            .strip_prefix("special:")
            .unwrap_or(&workspace.name)
            .to_string();

        let mut windows: Vec<WorkspaceWindow> = clients
            .iter()
            .filter(|client| {
                client.workspace.name == workspace.name
                    || (workspace.id.is_some() && client.workspace.id == workspace.id)
                    || client.workspace.name.strip_prefix("special:") == Some(&display_name)
            })
            .map(|client| make_window(client, &active_window.address, &hypr_monitors))
            .collect();

        windows.sort_by_key(|window| (window.y, window.x, window.pid));

        let is_act = active_special_names.iter().any(|an| {
            an == &display_name
                || an == &workspace.name
                || format!("special:{}", an) == workspace.name
        });

        let icon = scratchpad_icon(&display_name).to_string();
        let window_count = windows.len();
        let ws_id = workspace.id.unwrap_or(-1);

        special_workspaces.push(SpecialWorkspaceInfo {
            id: ws_id,
            name: workspace.name.clone(),
            display_name,
            icon,
            window_count,
            active: is_act,
            monitor: workspace.monitor.clone(),
            windows,
        });
    }

    let known_scratchpads = [
        ("special:terminal", "terminal", -97),
        ("special:files", "files", -98),
        ("special:music", "music", -96),
        ("special:magic", "magic", -99),
    ];

    for (k_name, k_disp, k_id) in &known_scratchpads {
        if !special_workspaces
            .iter()
            .any(|s: &SpecialWorkspaceInfo| s.name == *k_name || s.display_name == *k_disp)
        {
            let is_act = active_special_names
                .iter()
                .any(|an| an == *k_disp || an == *k_name);
            let icon = scratchpad_icon(k_disp).to_string();

            let mut windows: Vec<WorkspaceWindow> = clients
                .iter()
                .filter(|client| {
                    client.workspace.name == *k_name
                        || client.workspace.name.strip_prefix("special:") == Some(*k_disp)
                        || client.workspace.id == Some(*k_id)
                })
                .map(|client| make_window(client, &active_window.address, &hypr_monitors))
                .collect();

            windows.sort_by_key(|window| (window.y, window.x, window.pid));
            let window_count = windows.len();

            special_workspaces.push(SpecialWorkspaceInfo {
                id: *k_id,
                name: k_name.to_string(),
                display_name: k_disp.to_string(),
                icon,
                window_count,
                active: is_act,
                monitor: hypr_monitors
                    .first()
                    .map(|m| m.name.clone())
                    .unwrap_or_default(),
                windows,
            });
        }
    }

    special_workspaces.sort_by(|a, b| {
        let order = |name: &str| match name {
            "terminal" | "special:terminal" => 0,
            "files" | "special:files" => 1,
            "music" | "special:music" => 2,
            "magic" | "special:magic" => 3,
            _ => 4,
        };
        let oa = order(&a.display_name);
        let ob = order(&b.display_name);
        if oa != ob {
            oa.cmp(&ob)
        } else {
            a.display_name
                .to_lowercase()
                .cmp(&b.display_name.to_lowercase())
        }
    });

    // ========================================================
    // MONITORS
    // ========================================================

    let monitors = hypr_monitors
        .into_iter()
        .map(|monitor| MonitorInfo {
            id: monitor.id,
            name: monitor.name,
            x: monitor.x,
            y: monitor.y,
            width: monitor.width,
            height: monitor.height,
            scale: monitor.scale,
            focused: monitor.focused,
        })
        .collect();

    Ok(WorkspaceState {
        active_workspace: active_workspace.id,
        active_window: active_window.address,
        workspaces,
        special_workspaces,
        monitors,
    })
}

// ============================================================
// SWITCH WORKSPACE
// ============================================================

pub fn switch_workspace(id: i32) -> Result<(), String> {
    if !(1..=10).contains(&id) {
        return Err("workspace must be between 1 and 10".to_string());
    }

    let expression = format!("hl.dsp.focus({{ workspace = {} }})", id);
    hypr_dispatch(&expression)
}

// ============================================================
// FOCUS EXACT WINDOW
// ============================================================

pub fn focus_window(address: &str) -> Result<(), String> {
    let selector = lua_escape(&window_selector(address)?);
    let expression = format!("hl.dsp.focus({{ window = \"{}\" }})", selector);
    hypr_dispatch(&expression)
}

// ============================================================
// MOVE EXACT WINDOW → REGULAR WORKSPACE
// ============================================================

pub fn move_window(address: &str, workspace_id: i32, follow: bool) -> Result<(), String> {
    if !(1..=10).contains(&workspace_id) {
        return Err("workspace must be between 1 and 10".to_string());
    }

    let selector = lua_escape(&window_selector(address)?);
    let expression = format!(
        "hl.dsp.window.move({{ workspace = {}, follow = {}, window = \"{}\" }})",
        workspace_id,
        if follow { "true" } else { "false" },
        selector
    );

    hypr_dispatch(&expression)
}

// ============================================================
// MOVE EXACT WINDOW → SPECIAL WORKSPACE
// ============================================================

pub fn move_window_to_special(address: &str, name: &str, follow: bool) -> Result<(), String> {
    let name = name.trim().strip_prefix("special:").unwrap_or(name.trim());

    if name.is_empty() {
        return Err("special workspace name is empty".to_string());
    }

    let selector = lua_escape(&window_selector(address)?);
    let workspace = lua_escape(&format!("special:{}", name));

    let expression = format!(
        "hl.dsp.window.move({{ workspace = \"{}\", follow = {}, window = \"{}\" }})",
        workspace,
        if follow { "true" } else { "false" },
        selector
    );

    hypr_dispatch(&expression)
}

// ============================================================
// TOGGLE SPECIAL WORKSPACE
// ============================================================

pub fn toggle_special(name: &str) -> Result<(), String> {
    let name = name.trim().strip_prefix("special:").unwrap_or(name.trim());

    if name.is_empty() {
        return Err("special workspace name is empty".to_string());
    }

    let name = lua_escape(name);
    let expression = format!("hl.dsp.workspace.toggle_special(\"{}\")", name);

    hypr_dispatch(&expression)
}

// ============================================================
// CLOSE EXACT WINDOW
// ============================================================

pub fn close_window(address: &str) -> Result<(), String> {
    let selector = lua_escape(&window_selector(address)?);
    let expression = format!("hl.dsp.window.close({{ window = \"{}\" }})", selector);
    hypr_dispatch(&expression)
}

// ============================================================
// REAL-TIME EVENT STREAM (Socket 2 Event-Driven Workspace Sync)
// ============================================================

pub fn run_stream() -> Result<(), String> {
    let mut stdout = std::io::stdout();

    loop {
        let sock_path = match get_hyprland_socket_path(2) {
            Ok(p) => p,
            Err(e) => {
                eprintln!("Hyprland socket2 not found: {e}");
                thread::sleep(Duration::from_millis(1000));
                continue;
            }
        };

        let stream = match UnixStream::connect(&sock_path) {
            Ok(s) => s,
            Err(e) => {
                eprintln!("Failed to connect to Hyprland socket2: {e}");
                thread::sleep(Duration::from_millis(1000));
                continue;
            }
        };

        // Emit initial state
        if let Ok(state) = info() {
            if let Ok(json) = serde_json::to_string(&state) {
                if writeln!(stdout, "{}", json).is_err() || stdout.flush().is_err() {
                    return Ok(());
                }
            }
        }

        let reader = BufReader::new(stream);
        let mut last_emit = Instant::now();

        for line in reader.lines() {
            match line {
                Ok(raw) => {
                    let ev = raw.trim();
                    if ev.is_empty() {
                        continue;
                    }

                    let is_relevant = ev.starts_with("workspace>>")
                        || ev.starts_with("focusedmon>>")
                        || ev.starts_with("activewindow>>")
                        || ev.starts_with("activewindowv2>>")
                        || ev.starts_with("openwindow>>")
                        || ev.starts_with("closewindow>>")
                        || ev.starts_with("movewindow>>")
                        || ev.starts_with("movewindowv2>>")
                        || ev.starts_with("fullscreen>>")
                        || ev.starts_with("changefloatingmode>>")
                        || ev.starts_with("special>>")
                        || ev.starts_with("urgent>>")
                        || ev.starts_with("renameworkspace>>");

                    if !is_relevant {
                        continue;
                    }

                    // Debounce rapid bursts: 25ms
                    if last_emit.elapsed() < Duration::from_millis(25) {
                        thread::sleep(Duration::from_millis(25));
                    }

                    if let Ok(state) = info() {
                        if let Ok(json) = serde_json::to_string(&state) {
                            if writeln!(stdout, "{}", json).is_err() || stdout.flush().is_err() {
                                return Ok(());
                            }
                            last_emit = Instant::now();
                        }
                    }
                }
                Err(_) => {
                    break;
                }
            }
        }

        thread::sleep(Duration::from_millis(500));
    }
}

// ============================================================
// SUCCESS JSON
// ============================================================

fn print_success(action: &str, value: serde_json::Value) {
    println!(
        "{}",
        serde_json::json!({
            "success": true,
            "action": action,
            "value": value
        })
    );
}

// ============================================================
// CLI HANDLER
// ============================================================

pub fn handle(args: &[String]) -> Result<(), String> {
    let Some(command) = args.first() else {
        return Err("usage: nexad workspace \
             <info|stream|switch|focus|move|move-follow|move-special|move-special-follow|special|close>"
            .to_string());
    };

    match command.as_str() {
        "info" => {
            let state = info()?;
            println!(
                "{}",
                serde_json::to_string(&state)
                    .map_err(|error| format!("failed to serialize workspace state: {error}"))?
            );
            Ok(())
        }
        "stream" => {
            run_stream()?;
            Ok(())
        }
        "switch" => {
            let id = args
                .get(1)
                .ok_or_else(|| "missing workspace id".to_string())?
                .parse::<i32>()
                .map_err(|_| "invalid workspace id".to_string())?;

            switch_workspace(id)?;

            print_success(
                "switch",
                serde_json::json!({
                    "workspace": id
                }),
            );
            Ok(())
        }
        "focus" => {
            let address = args
                .get(1)
                .ok_or_else(|| "missing window address".to_string())?;

            focus_window(address)?;

            print_success(
                "focus",
                serde_json::json!({
                    "address": address
                }),
            );
            Ok(())
        }
        "move" | "move-follow" => {
            let address = args
                .get(1)
                .ok_or_else(|| "missing window address".to_string())?;

            let workspace_id = args
                .get(2)
                .ok_or_else(|| "missing target workspace id".to_string())?
                .parse::<i32>()
                .map_err(|_| "invalid target workspace id".to_string())?;

            let follow = command == "move-follow";
            move_window(address, workspace_id, follow)?;

            print_success(
                command,
                serde_json::json!({
                    "address": address,
                    "workspace": workspace_id,
                    "follow": follow
                }),
            );
            Ok(())
        }
        "move-special" | "move-special-follow" => {
            let address = args
                .get(1)
                .ok_or_else(|| "missing window address".to_string())?;

            let name = args
                .get(2)
                .ok_or_else(|| "missing special workspace name".to_string())?;

            let follow = command == "move-special-follow";
            move_window_to_special(address, name, follow)?;

            let clean_name = name.trim().strip_prefix("special:").unwrap_or(name.trim());

            print_success(
                command,
                serde_json::json!({
                    "address": address,
                    "workspace": format!("special:{}", clean_name),
                    "follow": follow
                }),
            );
            Ok(())
        }
        "special" => {
            let name = args
                .get(1)
                .ok_or_else(|| "missing special workspace name".to_string())?;

            toggle_special(name)?;

            print_success(
                "special",
                serde_json::json!({
                    "name": name
                }),
            );
            Ok(())
        }
        "close" => {
            let address = args
                .get(1)
                .ok_or_else(|| "missing window address".to_string())?;

            close_window(address)?;

            print_success(
                "close",
                serde_json::json!({
                    "address": address
                }),
            );
            Ok(())
        }
        unknown => Err(format!("unknown workspace command: {unknown}")),
    }
}
