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

fn run_command(
    program: &str,
    args: &[&str],
) -> Result<(), String> {
    let status = Command::new(program)
        .args(args)
        .status()
        .map_err(|error| {
            format!(
                "Failed to run {}: {}",
                program,
                error
            )
        })?;

    if status.success() {
        Ok(())
    } else {
        Err(format!(
            "{} exited with status {}",
            program,
            status
        ))
    }
}


// ============================================================
// LOCK
// ============================================================

fn lock() -> Result<(), String> {
    // Temporary backend until the native NEXA lock screen
    // is implemented.
    //
    // We intentionally keep the command registered now so
    // Power.qml will not need changing later.

    Err(
        "NEXA lock screen is not implemented yet".to_string()
    )
}


// ============================================================
// SUSPEND
// ============================================================

fn suspend() -> Result<(), String> {
    let _ = crate::state::sync_from_system();
    run_command(
        "systemctl",
        &["suspend"],
    )
}


// ============================================================
// LOGOUT
// ============================================================

fn logout() -> Result<(), String> {
    let _ = crate::state::sync_from_system();
    run_command(
        "hyprctl",
        &[
            "dispatch",
            "exit",
        ],
    )
}


// ============================================================
// REBOOT
// ============================================================

fn reboot() -> Result<(), String> {
    let _ = crate::state::sync_from_system();
    run_command(
        "systemctl",
        &["reboot"],
    )
}


// ============================================================
// SHUTDOWN
// ============================================================

fn shutdown() -> Result<(), String> {
    let _ = crate::state::sync_from_system();
    run_command(
        "systemctl",
        &["poweroff"],
    )
}


// ============================================================
// COMMAND HANDLER
// ============================================================

pub fn handle(
    args: &[String],
) -> Result<(), String> {
    if args.is_empty() {
        return Err(
            "Missing power action".to_string()
        );
    }

    match args[0].as_str() {
        "lock" => {
            lock()
        }

        "suspend" => {
            suspend()
        }

        "logout" => {
            logout()
        }

        "reboot" => {
            reboot()
        }

        "shutdown" => {
            shutdown()
        }

        action => {
            Err(format!(
                "Unknown power action: {}",
                action
            ))
        }
    }
}
