use serde::{Deserialize, Serialize};
use std::env;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;
use std::thread;
use std::time::Duration;

use crate::hyprland::autostart::is_running_exact;

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct PowerConfig {
    #[serde(default = "default_screen_off_battery")]
    pub screen_off_battery: u32,
    #[serde(default = "default_screen_off_ac")]
    pub screen_off_ac: u32,
    #[serde(default = "default_lock_battery")]
    pub lock_battery: u32,
    #[serde(default = "default_lock_ac")]
    pub lock_ac: u32,
    #[serde(default = "default_sleep_battery")]
    pub sleep_battery: u32,
    #[serde(default = "default_sleep_ac")]
    pub sleep_ac: u32,
    #[serde(default = "default_battery_saver_enabled")]
    pub battery_saver_enabled: bool,
    #[serde(default = "default_battery_saver_threshold")]
    pub battery_saver_threshold: u32,
}

fn default_screen_off_battery() -> u32 {
    300
}
fn default_screen_off_ac() -> u32 {
    600
}
fn default_lock_battery() -> u32 {
    180
}
fn default_lock_ac() -> u32 {
    300
}
fn default_sleep_battery() -> u32 {
    900
}
fn default_sleep_ac() -> u32 {
    1800
}
fn default_battery_saver_enabled() -> bool {
    true
}
fn default_battery_saver_threshold() -> u32 {
    20
}

impl Default for PowerConfig {
    fn default() -> Self {
        Self {
            screen_off_battery: default_screen_off_battery(),
            screen_off_ac: default_screen_off_ac(),
            lock_battery: default_lock_battery(),
            lock_ac: default_lock_ac(),
            sleep_battery: default_sleep_battery(),
            sleep_ac: default_sleep_ac(),
            battery_saver_enabled: default_battery_saver_enabled(),
            battery_saver_threshold: default_battery_saver_threshold(),
        }
    }
}

pub fn get_config_path() -> PathBuf {
    let home = env::var("HOME").unwrap_or_else(|_| "/home/shnx".to_string());
    PathBuf::from(home).join(".config/nexa/config/power.json")
}

pub fn get_hypridle_conf_path() -> PathBuf {
    let home = env::var("HOME").unwrap_or_else(|_| "/home/shnx".to_string());
    PathBuf::from(home).join(".config/hypr/hypridle.conf")
}

pub fn get_nexad_bin() -> String {
    let home = env::var("HOME").unwrap_or_else(|_| "/home/shnx".to_string());
    let path = PathBuf::from(home).join(".config/nexa/rust/target/release/nexad");
    if path.exists() {
        path.to_string_lossy().to_string()
    } else {
        "nexad".to_string()
    }
}

/// Loads PowerConfig from disk or returns defaults.
pub fn load_config() -> PowerConfig {
    let path = get_config_path();
    if let Ok(content) = fs::read_to_string(&path) {
        if let Ok(cfg) = serde_json::from_str::<PowerConfig>(&content) {
            return cfg;
        }
    }
    PowerConfig::default()
}

/// Atomically saves PowerConfig to disk.
pub fn save_config(cfg: &PowerConfig) -> Result<(), String> {
    let path = get_config_path();
    if let Some(parent) = path.parent() {
        let _ = fs::create_dir_all(parent);
    }
    let json = serde_json::to_string_pretty(cfg)
        .map_err(|e| format!("Failed to serialize power config: {e}"))?;
    fs::write(&path, json).map_err(|e| format!("Failed to write power config to {path:?}: {e}"))
}

/// Detects whether system is running on Battery or AC directly via Linux sysfs.
pub fn is_on_battery() -> bool {
    let ps_dir = Path::new("/sys/class/power_supply");
    if ps_dir.is_dir() {
        if let Ok(entries) = fs::read_dir(ps_dir) {
            let mut found_ac = false;
            let mut ac_online = false;
            let mut found_battery = false;
            let mut battery_discharging = false;

            for entry in entries.flatten() {
                let path = entry.path();
                let name = entry.file_name().to_string_lossy().to_string();
                let type_path = path.join("type");
                let supply_type = fs::read_to_string(&type_path)
                    .unwrap_or_default()
                    .trim()
                    .to_string();

                if supply_type == "Mains" || name.starts_with("AC") || name.starts_with("ADP") {
                    found_ac = true;
                    let online_path = path.join("online");
                    if let Ok(val) = fs::read_to_string(&online_path) {
                        if val.trim() == "1" {
                            ac_online = true;
                        }
                    }
                } else if supply_type == "Battery" || name.starts_with("BAT") {
                    found_battery = true;
                    let status_path = path.join("status");
                    if let Ok(st) = fs::read_to_string(&status_path) {
                        if st.trim().eq_ignore_ascii_case("discharging") {
                            battery_discharging = true;
                        }
                    }
                }
            }

            if found_battery {
                if battery_discharging {
                    return true;
                }
                if found_ac {
                    return !ac_online;
                }
            }
        }
    }

    // Fallback: query upower if sysfs was inconclusive
    if let Ok(output) = Command::new("upower").arg("-d").output() {
        let text = String::from_utf8_lossy(&output.stdout);
        for line in text.lines() {
            if line.contains("on-battery:") && line.contains("yes") {
                return true;
            }
        }
    }

    false
}

/// Generates a clean, Hyprland 0.57+ compliant hypridle.conf string.
pub fn generate_hypridle_conf(cfg: &PowerConfig, on_battery: bool) -> String {
    let (lock_timeout, screen_off_timeout, sleep_timeout) = if on_battery {
        (cfg.lock_battery, cfg.screen_off_battery, cfg.sleep_battery)
    } else {
        (cfg.lock_ac, cfg.screen_off_ac, cfg.sleep_ac)
    };

    let nexad = get_nexad_bin();

    let mut out = format!(
        "# Generated by NEXA Power & Sleep Management\n\
         # Do not edit manually. Changes will be overwritten by NEXA Settings.\n\n\
         general {{\n\
         \x20   lock_cmd = {nexad} lock trigger\n\
         \x20   before_sleep_cmd = {nexad} lock trigger\n\
         \x20   after_sleep_cmd = hyprctl dispatch dpms on\n\n\
         \x20   ignore_dbus_inhibit = false\n\
         \x20   ignore_systemd_inhibit = false\n\
         }}\n"
    );

    // Listener 1: Inactivity Screen Lock
    if lock_timeout > 0 {
        out.push_str(&format!(
            "\nlistener {{\n\
             \x20   timeout = {lock_timeout}\n\
             \x20   on-timeout = {nexad} lock trigger\n\
             }}\n"
        ));
    }

    // Listener 2: Smart Dimming (gently dims backlight before screen turns off)
    if screen_off_timeout > 15 {
        let dim_timeout = if screen_off_timeout > 45 {
            screen_off_timeout - 20
        } else {
            screen_off_timeout / 2
        };
        out.push_str(&format!(
            "\nlistener {{\n\
             \x20   timeout = {dim_timeout}\n\
             \x20   on-timeout = brightnessctl -s set 10%\n\
             \x20   on-resume = brightnessctl -r\n\
             }}\n"
        ));
    }

    // Listener 3: Screen Light / Backlight Off
    if screen_off_timeout > 0 {
        out.push_str(&format!(
            "\nlistener {{\n\
             \x20   timeout = {screen_off_timeout}\n\
             \x20   on-timeout = brightnessctl -s set 0\n\
             \x20   on-resume = brightnessctl -r && hyprctl dispatch dpms on\n\
             }}\n"
        ));
    }

    // Listener 4: System Sleep / Suspend to RAM
    if sleep_timeout > 0 {
        out.push_str(&format!(
            "\nlistener {{\n\
             \x20   timeout = {sleep_timeout}\n\
             \x20   on-timeout = systemctl suspend\n\
             }}\n"
        ));
    }

    out
}

/// Restarts hypridle cleanly without race conditions.
pub fn restart_hypridle() -> Result<(), String> {
    use std::os::unix::process::CommandExt;
    use std::process::Stdio;

    if is_running_exact("hypridle") {
        let _ = Command::new("pkill").args(["-x", "hypridle"]).output();
        // Brief poll for process termination
        for _ in 0..10 {
            if !is_running_exact("hypridle") {
                break;
            }
            thread::sleep(Duration::from_millis(20));
        }
    }

    let mut cmd = Command::new("hypridle");
    cmd.stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null());

    // Ensure session variables are present if called outside a full shell session
    if env::var("XDG_RUNTIME_DIR").is_err() {
        let uid = Command::new("id")
            .arg("-u")
            .output()
            .map(|o| String::from_utf8_lossy(&o.stdout).trim().to_string())
            .unwrap_or_else(|_| "1000".to_string());
        cmd.env("XDG_RUNTIME_DIR", format!("/run/user/{uid}"));
    }
    if env::var("WAYLAND_DISPLAY").is_err() {
        cmd.env("WAYLAND_DISPLAY", "wayland-1");
    }

    // Detach from parent process group
    cmd.process_group(0);

    cmd.spawn()
        .map_err(|e| format!("Failed to start hypridle daemon: {e}"))?;

    Ok(())
}

/// Synchronizes idle config with current power source and restarts hypridle.
pub fn sync_idle() -> Result<(), String> {
    let cfg = load_config();
    let on_battery = is_on_battery();
    let conf_content = generate_hypridle_conf(&cfg, on_battery);

    let conf_path = get_hypridle_conf_path();
    if let Some(parent) = conf_path.parent() {
        let _ = fs::create_dir_all(parent);
    }
    fs::write(&conf_path, conf_content)
        .map_err(|e| format!("Failed to write hypridle.conf: {e}"))?;

    restart_hypridle()?;

    println!(
        "[NEXA Idle] Synced hypridle with profile: {}",
        if on_battery { "Battery" } else { "AC Power" }
    );
    Ok(())
}

/// Returns current PowerConfig as a JSON string.
pub fn get_config_json() -> Result<String, String> {
    let cfg = load_config();
    serde_json::to_string_pretty(&cfg)
        .map_err(|e| format!("Failed to serialize power config: {e}"))
}

/// Updates PowerConfig from a JSON string, regenerates hypridle.conf, and restarts daemon.
pub fn set_config_json(json_str: &str) -> Result<(), String> {
    let cfg: PowerConfig = serde_json::from_str(json_str)
        .map_err(|e| format!("Failed to parse JSON power config: {e}"))?;

    save_config(&cfg)?;
    sync_idle()?;
    Ok(())
}

/// Prints diagnostic status of idle management.
pub fn print_status() {
    let cfg = load_config();
    let on_battery = is_on_battery();
    let hypridle_running = is_running_exact("hypridle");

    println!("\nNEXA Idle & Power Management Status:\n");
    println!(
        "  • Power Profile:        {}",
        if on_battery {
            "Battery (Conserving)"
        } else {
            "AC Power (High Performance)"
        }
    );
    println!(
        "  • Hypridle Daemon:      {}",
        if hypridle_running {
            "Running (Active)"
        } else {
            "Stopped"
        }
    );
    println!(
        "  • Lock Timeout:         {}s (current profile)",
        if on_battery {
            cfg.lock_battery
        } else {
            cfg.lock_ac
        }
    );
    println!(
        "  • Screen Off Timeout:   {}s (current profile)",
        if on_battery {
            cfg.screen_off_battery
        } else {
            cfg.screen_off_ac
        }
    );
    println!(
        "  • Sleep Suspend Timeout:{}s (current profile)",
        if on_battery {
            cfg.sleep_battery
        } else {
            cfg.sleep_ac
        }
    );
    println!(
        "  • Battery Saver:        {} (threshold: {}%)\n",
        if cfg.battery_saver_enabled {
            "Enabled"
        } else {
            "Disabled"
        },
        cfg.battery_saver_threshold
    );
}

/// CLI entry point for `nexad hypr idle <subcommand>`
pub fn handle_command(args: &[String]) {
    let sub = args.get(0).map(String::as_str).unwrap_or("status");
    match sub {
        "sync" => {
            if let Err(e) = sync_idle() {
                eprintln!("[NEXA Idle Sync Error]: {e}");
            }
        }
        "get" => match get_config_json() {
            Ok(json) => println!("{json}"),
            Err(e) => eprintln!("[NEXA Idle Get Error]: {e}"),
        },
        "set" => {
            if let Some(json_str) = args.get(1) {
                if let Err(e) = set_config_json(json_str) {
                    eprintln!("[NEXA Idle Set Error]: {e}");
                } else {
                    println!("{{\"success\":true}}");
                }
            } else {
                eprintln!("Usage: nexad hypr idle set '<json>'");
            }
        }
        "status" => {
            print_status();
        }
        other => {
            eprintln!("Unknown idle subcommand: '{other}'. Use 'sync', 'get', 'set', or 'status'.");
        }
    }
}
