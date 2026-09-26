use pam::Client;
use serde_json::json;
use std::env;
use std::fs;
use std::io;
use std::path::PathBuf;

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

pub fn handle(args: &[String]) -> Result<(), String> {
    if args.is_empty() {
        return Err("Usage: nexad lock <auth|status>".to_string());
    }

    match args[0].as_str() {
        "auth" => authenticate_from_stdin(),
        "status" => {
            let is_locked = lock_flag_path().exists() || std::path::Path::new("/tmp/nexa-locked").exists();
            println!("{}", json!({ "locked": is_locked }));
            Ok(())
        }
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
            println!("{}", json!({ "success": true }));
            Ok(())
        }
        Err(_) => {
            println!("{}", json!({ "success": false }));
            Ok(())
        }
    }
}
