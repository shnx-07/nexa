pub mod animations;
pub mod autostart;
pub mod binds;
pub mod decorations;
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

/// Listens to Hyprland's real-time event socket (.socket2.sock).
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
            // Reserved for future lightweight telemetry
            let _ = l;
        }
    }

    Ok(())
}

/// Entry point for `nexad hypr <subcommand>` CLI
pub fn handle_command(args: &[String]) {
    if args.is_empty() {
        eprintln!("Usage: nexad hypr [daemon|scratchpad|rules|animations|decorations|autostart] ...");
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
            let sub = args.get(1).map(String::as_str).unwrap_or("sync");
            match sub {
                "sync" => {
                    if let Err(e) = rules::sync_rules() {
                        eprintln!("[NEXA Rules Sync Error]: {e}");
                    }
                }
                "list" => {
                    rules::print_rules_summary();
                }
                other => {
                    eprintln!("Unknown rules subcommand: '{other}'. Use 'sync' or 'list'.");
                }
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
        "decorations" => {
            let sub = args.get(1).map(String::as_str).unwrap_or("sync");
            match sub {
                "sync" => {
                    if let Err(e) = decorations::sync_decorations() {
                        eprintln!("[NEXA Decorations Sync Error]: {e}");
                    }
                }
                "status" | "list" => {
                    decorations::print_status();
                }
                "set" => {
                    let mut rounding = None;
                    let mut border = None;
                    let mut nexa_rounding = None;
                    let mut shadow = None;
                    let mut shadow_range = None;
                    let mut dim_inactive = None;
                    let mut dim_strength = None;

                    let mut i = 2;
                    while i < args.len() {
                        match args[i].as_str() {
                            "--rounding" => {
                                if let Some(val) = args.get(i + 1) {
                                    rounding = val.parse::<i32>().ok();
                                    i += 1;
                                }
                            }
                            "--border" => {
                                if let Some(val) = args.get(i + 1) {
                                    border = val.parse::<i32>().ok();
                                    i += 1;
                                }
                            }
                            "--nexa-rounding" => {
                                if let Some(val) = args.get(i + 1) {
                                    nexa_rounding = val.parse::<i32>().ok();
                                    i += 1;
                                }
                            }
                            "--shadow" => {
                                if let Some(val) = args.get(i + 1) {
                                    shadow = match val.to_lowercase().as_str() {
                                        "true" | "1" | "on" => Some(true),
                                        "false" | "0" | "off" => Some(false),
                                        _ => None,
                                    };
                                    i += 1;
                                }
                            }
                            "--shadow-range" => {
                                if let Some(val) = args.get(i + 1) {
                                    shadow_range = val.parse::<i32>().ok();
                                    i += 1;
                                }
                            }
                            "--dim" => {
                                if let Some(val) = args.get(i + 1) {
                                    dim_strength = val.parse::<f64>().ok();
                                    i += 1;
                                }
                            }
                            "--dim-inactive" => {
                                if let Some(val) = args.get(i + 1) {
                                    dim_inactive = match val.to_lowercase().as_str() {
                                        "true" | "1" | "on" => Some(true),
                                        "false" | "0" | "off" => Some(false),
                                        _ => None,
                                    };
                                    i += 1;
                                }
                            }
                            _ => {}
                        }
                        i += 1;
                    }

                    if let Err(e) = decorations::set_decoration(
                        rounding,
                        border,
                        nexa_rounding,
                        shadow,
                        shadow_range,
                        dim_inactive,
                        dim_strength,
                    ) {
                        eprintln!("[NEXA Decorations Set Error]: {e}");
                    }
                }
                other => {
                    eprintln!("Unknown decorations subcommand: '{other}'. Use 'sync', 'set', or 'status'.");
                }
            }
        }
        "autostart" => {
            let sub = args.get(1).map(String::as_str).unwrap_or("status");
            match sub {
                "run" | "start" => {
                    if let Err(e) = autostart::run_autostart() {
                        eprintln!("[NEXA Autostart Error]: {e}");
                    }
                }
                "status" | "list" => {
                    autostart::print_status();
                }
                other => {
                    eprintln!("Unknown autostart subcommand: '{other}'. Use 'run' or 'status'.");
                }
            }
        }
        other => {
            eprintln!("Unknown hypr subcommand: {other}");
        }
    }
}

