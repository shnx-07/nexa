use pam::Client;
use serde_json::json;
use std::env;
use std::fs;
use std::io;
use std::path::PathBuf;
use std::process::Command;

pub fn runtime_dir() -> PathBuf {
    let base = match env::var("XDG_RUNTIME_DIR") {
        Ok(dir) if !dir.trim().is_empty() => PathBuf::from(dir).join("nexa"),
        _ => {
            let user = env::var("USER").unwrap_or_else(|_| "user".to_string());
            PathBuf::from(format!("/tmp/nexa-{}", user))
        }
    };
    let _ = fs::create_dir_all(&base);
    base
}

pub fn lock_flag_path() -> PathBuf {
    runtime_dir().join("locked")
}

/// Triggers the Nexa Lock Screen via Hyprland global shortcut and Quickshell IPC.
pub fn trigger_lock() -> Result<(), String> {
    let home = env::var("HOME").unwrap_or_else(|_| "/home/shnx".to_string());
    let qs_path = format!("{}/.config/nexa/quickshell", home);

    // Dispatch native Hyprland global shortcut
    let hypr_status = Command::new("hyprctl")
        .args(["dispatch", "global", "nexa:lock"])
        .output();

    let dispatched = hypr_status.map(|o| o.status.success()).unwrap_or(false);

    // Also send Quickshell IPC call if global shortcut wasn't handled
    if !dispatched {
        let _ = Command::new("qs")
            .args(["-p", &qs_path, "ipc", "call", "lockScreen", "lock"])
            .output();
    }

    crate::hardware::sound::play_sound("lock");

    Ok(())
}

pub fn handle(args: &[String]) -> Result<(), String> {
    if args.is_empty() {
        return Err("Usage: nexad lock <auth|status|trigger>".to_string());
    }

    match args[0].as_str() {
        "auth" => authenticate_from_stdin(),
        "status" => {
            let is_locked = lock_flag_path().exists();
            println!("{}", json!({ "locked": is_locked }));
            Ok(())
        }
        "trigger" | "screen" => trigger_lock(),
        action => Err(format!("Unknown lock action: {action}")),
    }
}

fn authenticate_from_stdin() -> Result<(), String> {
    let username = env::var("USER").map_err(|_| "Unable to determine current user".to_string())?;

    // Password comes from stdin instead of argv
    let mut password = String::new();
    io::stdin()
        .read_line(&mut password)
        .map_err(|error| format!("Unable to read password: {error}"))?;

    let trimmed_len = password.trim_end_matches(['\r', '\n']).len();

    let mut client = Client::with_password("system-auth")
        .map_err(|error| format!("Unable to initialize PAM: {error}"))?;

    client
        .conversation_mut()
        .set_credentials(&username, &password[..trimmed_len]);

    let auth_result = client.authenticate();

    // Securely wipe password buffer from memory immediately after authentication
    unsafe {
        std::ptr::write_bytes(password.as_mut_ptr(), 0, password.capacity());
    }

    match auth_result {
        Ok(()) => {
            crate::hardware::sound::play_sound("unlock");
            println!("{}", json!({ "success": true }));
            Ok(())
        }
        Err(_) => {
            println!("{}", json!({ "success": false }));
            Ok(())
        }
    }
}
