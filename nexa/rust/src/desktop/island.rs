use std::{env, path::PathBuf, process::Command};

fn quickshell_path() -> Result<PathBuf, String> {
    let home = env::var("HOME").map_err(|error| format!("HOME unavailable: {error}"))?;

    Ok(PathBuf::from(home)
        .join(".config")
        .join("nexa")
        .join("quickshell"))
}

pub fn call_quickshell(function: &str) -> Result<(), String> {
    let config_path = quickshell_path()?;

    let status = Command::new("qs")
        .arg("-p")
        .arg(&config_path)
        .args(["ipc", "call", "nexaIsland", function])
        .status()
        .map_err(|error| format!("failed to launch qs ipc: {error}"))?;

    if !status.success() {
        return Err(format!("qs ipc call failed with status: {status}"));
    }

    Ok(())
}

pub fn call_qs(target: &str, method: &str) -> Result<(), String> {
    let config_path = quickshell_path()?;

    let status = Command::new("qs")
        .arg("-p")
        .arg(&config_path)
        .args(["ipc", "call", target, method])
        .status()
        .map_err(|error| format!("failed to launch qs ipc: {error}"))?;

    if !status.success() {
        return Err(format!("qs ipc call ({target}.{method}) failed with status: {status}"));
    }

    Ok(())
}

pub fn call_action(action: &str) {
    let method = match action {
        "search" => "openSearch",
        "command" => "openCommand",
        "volume-up" | "volumeUp" => "volumeUp",
        "volume-down" | "volumeDown" => "volumeDown",
        "toggle-mute" | "toggleMute" => "toggleMute",
        "toggle-mic-mute" | "toggleMicMute" => "toggleMicMute",
        "brightness-up" | "brightnessUp" => "brightnessUp",
        "brightness-down" | "brightnessDown" => "brightnessDown",
        "control-center" | "toggleControlCenter" => "toggleControlCenter",
        "power" | "togglePower" => "togglePower",
        "airplane" | "toggleAirplane" => "toggleAirplane",
        other => other,
    };

    if let Err(error) = call_quickshell(method) {
        eprintln!("NEXA Island action error ({action}): {error}");
        std::process::exit(2);
    }
}

pub fn open_search() {
    call_action("search");
}

pub fn open_command() {
    call_action("command");
}

