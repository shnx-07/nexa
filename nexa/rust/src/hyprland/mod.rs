pub mod animations;
pub mod binds;
pub mod rules;

use std::env;
use std::io::{BufRead, BufReader, Read, Write};
use std::os::unix::net::UnixStream;
use std::path::PathBuf;
use std::process::Command;

/// Resolves the Hyprland UNIX domain command socket path.
/// `$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket.sock`
pub fn get_socket_path() -> Option<PathBuf> {
    let runtime_dir = env::var("XDG_RUNTIME_DIR").ok()?;
    let his = env::var("HYPRLAND_INSTANCE_SIGNATURE").ok()?;
    let path = PathBuf::from(runtime_dir).join("hypr").join(his).join(".socket.sock");
    if path.exists() {
        Some(path)
    } else {
        None
    }
}

/// Resolves the Hyprland UNIX domain real-time event socket path.
/// `$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock`
pub fn get_event_socket_path() -> Option<PathBuf> {
    let runtime_dir = env::var("XDG_RUNTIME_DIR").ok()?;
    let his = env::var("HYPRLAND_INSTANCE_SIGNATURE").ok()?;
    let path = PathBuf::from(runtime_dir).join("hypr").join(his).join(".socket2.sock");
    if path.exists() {
        Some(path)
    } else {
        None
    }
}

/// Dispatches a command to Hyprland via direct UNIX socket (sub-millisecond)
/// with graceful fallback to `hyprctl`.
pub fn hypr_command(cmd: &str) -> Result<String, String> {
    if let Some(socket_path) = get_socket_path() {
        if let Ok(mut stream) = UnixStream::connect(&socket_path) {
            if stream.write_all(cmd.as_bytes()).is_ok() {
                let mut response = String::new();
                if stream.read_to_string(&mut response).is_ok() {
                    return Ok(response.trim().to_string());
                }
            }
        }
    }

    // Fallback to hyprctl process invocation
    let parts: Vec<&str> = cmd.splitn(2, ' ').collect();
    let mut command = Command::new("hyprctl");
    for part in parts {
        command.arg(part);
    }

    let output = command
        .output()
        .map_err(|e| format!("Failed to execute hyprctl fallback: {e}"))?;

    if !output.status.success() {
        let err = String::from_utf8_lossy(&output.stderr);
        return Err(format!("Hyprland command failed: {err}"));
    }

    Ok(String::from_utf8_lossy(&output.stdout).trim().to_string())
}

/// Dispatches a dispatcher action to Hyprland (e.g. `dispatch focuswindow address:0x...`)
pub fn dispatch(action: &str) -> Result<(), String> {
    let cmd = format!("dispatch {action}");
    let resp = hypr_command(&cmd)?;
    if resp != "ok" && !resp.is_empty() && !resp.contains("ok") {
        // Some dispatches return "ok" or empty string on success
        eprintln!("[NEXA Hypr] dispatch '{action}' response: {resp}");
    }
    Ok(())
}

/// Queries JSON data from Hyprland via direct socket (`j/<cmd>`) or `hyprctl -j <cmd>`.
pub fn query_json<T: for<'de> serde::Deserialize<'de>>(section: &str) -> Result<T, String> {
    if let Some(socket_path) = get_socket_path() {
        if let Ok(mut stream) = UnixStream::connect(&socket_path) {
            let query = format!("j/{section}");
            if stream.write_all(query.as_bytes()).is_ok() {
                let mut response = String::new();
                if stream.read_to_string(&mut response).is_ok() {
                    if let Ok(val) = serde_json::from_str::<T>(&response) {
                        return Ok(val);
                    }
                }
            }
        }
    }

    // Fallback to hyprctl -j
    let output = Command::new("hyprctl")
        .args(["-j", section])
        .output()
        .map_err(|e| format!("Failed to run hyprctl -j {section}: {e}"))?;

    if !output.status.success() {
        return Err(format!("hyprctl -j {section} exited with error"));
    }

    serde_json::from_slice(&output.stdout)
        .map_err(|e| format!("Failed to parse hyprctl JSON for {section}: {e}"))
}

/// Listens to Hyprland's real-time event socket (.socket2.sock) and triggers dynamic rules.
pub fn run_daemon() -> Result<(), String> {
    let socket_path = get_event_socket_path()
        .ok_or_else(|| "Could not locate Hyprland event socket (.socket2.sock)".to_string())?;

    println!("[NEXA Hypr Daemon] Connecting to event socket at {:?}", socket_path);
    let stream = UnixStream::connect(&socket_path)
        .map_err(|e| format!("Failed to connect to .socket2.sock: {e}"))?;

    println!("[NEXA Hypr Daemon] Listening for window & workspace events...");
    let reader = BufReader::new(stream);

    for line in reader.lines() {
        if let Ok(l) = line {
            if l.starts_with("openwindow>>") {
                if let Some(payload) = l.strip_prefix("openwindow>>") {
                    let parts: Vec<&str> = payload.splitn(4, ',').collect();
                    if parts.len() >= 4 {
                        let addr = parts[0];
                        let ws = parts[1];
                        let class = parts[2];
                        let title = parts[3];
                        rules::on_window_open(addr, ws, class, title);
                    }
                }
            } else if l.starts_with("closewindow>>") {
                if let Some(addr) = l.strip_prefix("closewindow>>") {
                    rules::on_window_close(addr);
                }
            }
        }
    }

    Ok(())
}

/// Entry point for `nexad hypr <subcommand>` CLI
pub fn handle_command(args: &[String]) {
    if args.is_empty() {
        eprintln!("Usage: nexad hypr [daemon|scratchpad|rules|animations] ...");
        return;
    }

    match args[0].as_str() {
        "daemon" => {
            if let Err(e) = run_daemon() {
                eprintln!("[NEXA Hypr Daemon Error]: {e}");
            }
        }
        "scratchpad" => {
            if args.len() < 2 {
                eprintln!("Usage: nexad hypr scratchpad <terminal|files>");
                return;
            }
            if let Err(e) = binds::toggle_scratchpad(&args[1]) {
                eprintln!("[NEXA Hypr Error]: {e}");
            }
        }
        "rules" => {
            let target_addr = args.get(1).map(String::as_str);
            if let Err(e) = rules::apply_rules(target_addr) {
                eprintln!("[NEXA Rules Error]: {e}");
            }
        }
        "animations" => {
            if args.len() < 2 {
                eprintln!("Usage: nexad hypr animations <profile <name> | sync>");
                return;
            }
            match args[1].as_str() {
                "list" => {
                    animations::print_profiles();
                }
                "profile" => {
                    let profile_name = args.get(2).map(String::as_str).unwrap_or("fluid");
                    if let Err(e) = animations::set_profile(profile_name) {
                        eprintln!("[NEXA Animations Error]: {e}");
                    }
                }
                "sync" => {
                    if let Err(e) = animations::sync_motion_config() {
                        eprintln!("[NEXA Animations Sync Error]: {e}");
                    }
                }
                other => eprintln!("Unknown animation subcommand: {other}"),
            }
        }
        other => {
            eprintln!("Unknown hypr subcommand: {other}");
        }
    }
}

