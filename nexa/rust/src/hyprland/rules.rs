use super::{binds, dispatch, query_json};
use serde::Deserialize;

#[derive(Debug, Deserialize, Default, Clone)]
pub struct MonitorInfo {
    pub id: i32,
    pub name: String,
    pub x: i32,
    pub y: i32,
    pub width: i32,
    pub height: i32,
    #[serde(default = "default_scale")]
    pub scale: f64,
    pub focused: bool,
    #[serde(default)]
    pub reserved: [i32; 4],
}

fn default_scale() -> f64 {
    1.0
}

/// Retrieves the currently focused monitor to calculate pixel-perfect bounds.
pub fn get_focused_monitor() -> Option<MonitorInfo> {
    if let Ok(monitors) = query_json::<Vec<MonitorInfo>>("monitors") {
        if let Some(m) = monitors.iter().find(|m| m.focused).cloned() {
            return Some(m);
        }
        return monitors.first().cloned();
    }
    None
}

/// Checks if a window is Picture-in-Picture.
pub fn is_pip(title: &str) -> bool {
    let t = title.to_lowercase();
    t.contains("picture-in-picture") || t.contains("picture in picture")
}

/// Checks if a window is a modal, dialog, or popup.
pub fn is_modal_or_dialog(class: &str, title: &str) -> bool {
    let c = class.to_lowercase();
    let t = title.to_lowercase();

    if c.contains("dialog")
        || c == "xdg-desktop-portal-gtk"
        || c == "hyprland-share-picker"
        || c.contains("pavucontrol")
        || c.contains("blueman-manager")
        || c.contains("calc")
    {
        return true;
    }

    let modal_titles = [
        "open file",
        "save as",
        "authentication required",
        "choose files",
        "file operation progress",
        "confirm",
        "library",
        "page info",
        "sign in",
        "log in",
        "oauth",
    ];

    for mt in &modal_titles {
        if t.contains(mt) {
            return true;
        }
    }

    false
}

/// Triggered in real time when any window maps on screen.
pub fn on_window_open(addr: &str, workspace: &str, class: &str, title: &str) {
    let formatted_addr = if addr.starts_with("0x") {
        addr.to_string()
    } else {
        format!("0x{addr}")
    };

    println!("[NEXA Rules] Window opened: addr={formatted_addr}, class='{class}', title='{title}', ws='{workspace}'");

    // 1. PICTURE-IN-PICTURE: Snap to bottom-right corner of focused display
    if is_pip(title) {
        println!("[NEXA Rules] Picture-in-Picture detected: snapping to bottom-right corner...");
        let mon = get_focused_monitor().unwrap_or(MonitorInfo {
            width: 1920,
            height: 1080,
            scale: 1.0,
            ..Default::default()
        });

        let eff_w = (mon.width as f64 / mon.scale) as i32;
        let eff_h = (mon.height as f64 / mon.scale) as i32;

        let pip_w = 460;
        let pip_h = (pip_w as f64 * (9.0 / 16.0)) as i32;

        let target_x = mon.x + eff_w - pip_w - 24;
        let target_y = mon.y + eff_h - pip_h - 24;

        let _ = dispatch(&format!(r#"hl.dsp.window.float({{ action = "set", window = "address:{formatted_addr}" }})"#));
        let _ = dispatch(&format!(r#"hl.dsp.window.pin({{ action = "set", window = "address:{formatted_addr}" }})"#));
        let _ = dispatch(&format!(r#"hl.dsp.window.resize({{ window = "address:{formatted_addr}", x = {pip_w}, y = {pip_h} }})"#));
        let _ = dispatch(&format!(r#"hl.dsp.window.move({{ window = "address:{formatted_addr}", x = {target_x}, y = {target_y} }})"#));
        return;
    }

    // 3. MODAL DIALOGS: Auto-float and center
    if is_modal_or_dialog(class, title) {
        println!("[NEXA Rules] Modal dialog detected: auto-floating and centering...");
        let _ = dispatch(&format!(r#"hl.dsp.window.float({{ action = "set", window = "address:{formatted_addr}" }})"#));
        let _ = dispatch(&format!(r#"hl.dsp.window.center({{ window = "address:{formatted_addr}" }})"#));
        return;
    }

    // 4. SCRATCHPAD AUTO-SLIDEAWAY: If external application opened while Files scratchpad is up
    if !workspace.starts_with("special:") && !class.to_lowercase().contains("dolphin") {
        if binds::is_special_workspace_open("files") {
            println!("[NEXA Rules] External app opened, auto-hiding Files scratchpad...");
            let _ = dispatch(r#"hl.dsp.workspace.toggle_special("files")"#);
        }
    }
}

/// Triggered in real time when any window closes.
pub fn on_window_close(_addr: &str) {
    // Window close hook reserved for future rules
}

#[derive(Debug, Deserialize, Clone)]
pub struct HyprClient {
    pub address: String,
    pub class: String,
    pub title: String,
    pub workspace: ClientWorkspace,
}

#[derive(Debug, Deserialize, Clone)]
pub struct ClientWorkspace {
    pub id: i32,
    pub name: String,
}

/// Applies rules manually to currently open windows (e.g. from CLI).
pub fn apply_rules(target_addr: Option<&str>) -> Result<(), String> {
    let clients: Vec<HyprClient> = query_json("clients")?;
    for c in clients {
        if let Some(addr) = target_addr {
            if !c.address.ends_with(addr) && !addr.ends_with(&c.address) {
                continue;
            }
        }
        on_window_open(&c.address, &c.workspace.name, &c.class, &c.title);
    }
    Ok(())
}
