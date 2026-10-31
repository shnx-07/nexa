use std::process::Command;

// ============================================================
// NEXA POWER BACKEND
// ============================================================
//
// Commands:
//
// nexad power lock
// nexad power suspend
// nexad power logout
// nexad power reboot
// nexad power shutdown
//
// QML should only call nexad.
// Actual system actions stay here.
// ============================================================

fn run_command(program: &str, args: &[&str]) -> Result<(), String> {
    let status = Command::new(program)
        .args(args)
        .status()
        .map_err(|error| format!("Failed to run {}: {}", program, error))?;

    if status.success() {
        Ok(())
    } else {
        Err(format!("{} exited with status {}", program, status))
    }
}

// ============================================================
// LOCK
// ============================================================

fn lock() -> Result<(), String> {
    crate::desktop::lock::trigger_lock()
}

// ============================================================
// SUSPEND
// ============================================================

fn suspend() -> Result<(), String> {
    let _ = crate::state::sync_from_system();
    run_command("systemctl", &["suspend"])
}

// ============================================================
// LOGOUT
// ============================================================

fn logout() -> Result<(), String> {
    let _ = crate::state::sync_from_system();
    run_command("hyprctl", &["dispatch", "exit"])
}

// ============================================================
// REBOOT
// ============================================================

fn reboot() -> Result<(), String> {
    let _ = crate::state::sync_from_system();
    run_command("systemctl", &["reboot"])
}

// ============================================================
// SHUTDOWN
// ============================================================

fn shutdown() -> Result<(), String> {
    let _ = crate::state::sync_from_system();
    run_command("systemctl", &["poweroff"])
}

// ============================================================
// PROFILE
// ============================================================

fn set_profile(profile: &str) -> Result<(), String> {
    if run_command("powerprofilesctl", &["set", profile]).is_ok() {
        return Ok(());
    }

    let gov = match profile {
        "power-saver" | "powersave" | "saver" => "powersave",
        "performance" => "performance",
        _ => "schedutil",
    };

    if run_command("cpupower", &["frequency-set", "-g", gov]).is_ok() {
        return Ok(());
    }

    if let Ok(entries) = std::fs::read_dir("/sys/devices/system/cpu") {
        for entry in entries.flatten() {
            let gov_file = entry.path().join("cpufreq/scaling_governor");
            if gov_file.exists() {
                let _ = std::fs::write(gov_file, gov);
            }
        }
    }

    Ok(())
}

// ============================================================
// COMMAND HANDLER
// ============================================================

pub fn handle(args: &[String]) -> Result<(), String> {
    if args.is_empty() {
        return Err("Missing power action".to_string());
    }

    match args[0].as_str() {
        "status" | "info" => crate::hardware::battery::handle(&["status".to_string()]),

        "watch" | "daemon" => crate::hardware::battery::handle(&["watch".to_string()]),

        "profile" => {
            if args.len() < 2 {
                return Err("Missing profile name".to_string());
            }
            set_profile(&args[1])
        }

        "lock" => lock(),

        "suspend" => suspend(),

        "logout" => logout(),

        "reboot" => reboot(),

        "shutdown" => shutdown(),

        action => Err(format!("Unknown power action: {}", action)),
    }
}
