use std::env;
use std::process::{Command, Stdio};
use std::thread;
use std::time::Duration;

/// Checks if a process is already running by exact binary name.
pub fn is_running_exact(name: &str) -> bool {
    Command::new("pgrep")
        .args(["-x", name])
        .output()
        .map(|o| o.status.success() && !o.stdout.is_empty())
        .unwrap_or(false)
}

/// Checks if a process is already running matching a command-line pattern.
pub fn is_running_pattern(pattern: &str) -> bool {
    Command::new("pgrep")
        .args(["-f", pattern])
        .output()
        .map(|o| o.status.success() && !o.stdout.is_empty())
        .unwrap_or(false)
}

/// Spawns a background detached daemon.
pub fn spawn_detached(binary: &str, args: &[&str], envs: &[(&str, &str)]) -> Result<(), String> {
    let mut cmd = Command::new(binary);
    cmd.args(args);
    for (k, v) in envs {
        cmd.env(k, v);
    }
    cmd.stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null());

    cmd.spawn()
        .map_err(|e| format!("Failed to spawn {binary}: {e}"))?;
    Ok(())
}

/// Runs the complete, staged boot sequence for the Nexa desktop session.
pub fn run_autostart() -> Result<(), String> {
    println!("[NEXA Autostart] Initiating staged desktop boot sequence...");

    let home = env::var("HOME").unwrap_or_else(|_| String::from("/home/shnx"));

    // ── STAGE 1: Polkit Authentication & Hyprland Plugins ────────────────────
    println!("[NEXA Autostart] Stage 1: Initializing polkit & plugins...");
    let _ = spawn_detached("systemctl", &["--user", "start", "plasma-polkit-agent.service"], &[]);

    let _ = Command::new("hyprpm")
        .arg("reload")
        .status();

    // ── STAGE 2: Primary Visual Shell & Wallpaper ─────────────────────────────
    println!("[NEXA Autostart] Stage 2: Spawning QuickShell desktop & restoring wallpaper...");

    let shell_path = format!("{home}/.config/nexa/quickshell/shell.qml");
    if !is_running_pattern("quickshell.*shell.qml") {
        let envs = [
            ("QS_NO_RELOAD_POPUP", "1"),
            ("QT_IMAGEIO_MAXALLOC", "1024"),
            ("QML_DISABLE_DISK_CACHE", "0"),
            ("QSG_RENDER_LOOP", "threaded"),
        ];
        if let Err(e) = spawn_detached("quickshell", &["-p", &shell_path], &envs) {
            eprintln!("[NEXA Autostart] Error spawning QuickShell: {e}");
        }
    } else {
        println!("[NEXA Autostart] QuickShell already running, skipping duplicate spawn.");
    }

    // Wallpaper restore
    let nexad_bin = format!("{home}/.config/nexa/rust/target/release/nexad");
    let _ = Command::new(&nexad_bin)
        .args(["wallpaper", "restore"])
        .status();

    // ── STAGE 3: Background Daemons (Staggered by 300ms) ──────────────────────
    thread::sleep(Duration::from_millis(300));
    println!("[NEXA Autostart] Stage 3: Launching background utilities...");

    // playerctld daemon
    if !is_running_exact("playerctld") {
        let _ = spawn_detached("playerctld", &["daemon"], &[]);
    }

    // Clipboard history daemon (text & image watchers)
    if !is_running_pattern("cliphist store") {
        let _ = Command::new("sh")
            .arg("-c")
            .arg("wl-paste --type text --watch cliphist store & wl-paste --type image --watch cliphist store &")
            .spawn();
    }

    // hypridle (screen idle management)
    if !is_running_exact("hypridle") {
        let _ = spawn_detached("hypridle", &[], &[]);
    }

    println!("[NEXA Autostart] Staged boot sequence completed successfully.");
    Ok(())
}

/// Prints a diagnostic health report of all autostart services.
pub fn print_status() {
    println!("\nNEXA Desktop Autostart & Daemons Status:\n");

    let qs_running = is_running_pattern("quickshell.*shell.qml");
    let polkit_active = Command::new("systemctl")
        .args(["--user", "is-active", "plasma-polkit-agent.service"])
        .output()
        .map(|o| o.status.success() && String::from_utf8_lossy(&o.stdout).trim() == "active")
        .unwrap_or(false);
    let playerctld_running = is_running_exact("playerctld");
    let cliphist_running = is_running_pattern("cliphist store");
    let hypridle_running = is_running_exact("hypridle");
    let wallpaper_running = is_running_exact("skwd-paper");

    println!("  • QuickShell UI:      {}", if qs_running { "Running (Active)" } else { "Stopped" });
    println!("  • Polkit Agent:       {}", if polkit_active { "Active (systemd)" } else { "Inactive" });
    println!("  • Wallpaper Engine:   {}", if wallpaper_running { "Active (skwd-paper)" } else { "Standby / Restored" });
    println!("  • Media (playerctld): {}", if playerctld_running { "Running" } else { "Stopped" });
    println!("  • Clipboard History:  {}", if cliphist_running { "Running (cliphist)" } else { "Stopped" });
    println!("  • Idle / ScreenLock:  {}", if hypridle_running { "Running (hypridle)" } else { "Stopped" });
    println!("\nUsage:");
    println!("  nexad hypr autostart run     (Execute staged boot sequence)");
    println!("  nexad hypr autostart status  (Check daemon health)\n");
}

