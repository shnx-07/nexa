use serde::{Deserialize, Serialize};
use std::fs;
use std::path::{Path, PathBuf};
use std::thread;
use std::time::Duration;

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct BatteryStatus {
    pub percentage: u32,
    pub charging: bool,
    pub on_battery: bool,
    pub status: String,
    pub energy_now: u64,
    pub energy_full: u64,
    pub power_watts: f64,
    pub health_percentage: u32,
    pub time_to_full: u64,
    pub time_to_empty: u64,
}

fn read_file_string(path: &Path) -> Option<String> {
    fs::read_to_string(path).ok().map(|s| s.trim().to_string())
}

fn read_file_u64(path: &Path) -> Option<u64> {
    read_file_string(path).and_then(|s| s.parse::<u64>().ok())
}

/// Discovers the active battery directory under /sys/class/power_supply
fn find_battery_dir() -> Option<PathBuf> {
    let ps_dir = Path::new("/sys/class/power_supply");
    if !ps_dir.exists() {
        return None;
    }

    let entries = fs::read_dir(ps_dir).ok()?;
    let mut candidate = None;

    for entry in entries.flatten() {
        let name = entry.file_name().to_string_lossy().to_string();
        if name.starts_with("BAT") {
            let path = entry.path();
            if path.join("capacity").exists() || path.join("energy_now").exists() || path.join("charge_now").exists() {
                return Some(path);
            }
            if candidate.is_none() {
                candidate = Some(path);
            }
        }
    }

    candidate
}

/// Checks if an AC / mains adapter is plugged in under /sys/class/power_supply
fn is_ac_online() -> Option<bool> {
    let ps_dir = Path::new("/sys/class/power_supply");
    if !ps_dir.exists() {
        return None;
    }

    let entries = fs::read_dir(ps_dir).ok()?;

    for entry in entries.flatten() {
        let name = entry.file_name().to_string_lossy().to_string();
        if name.starts_with("AC") || name.starts_with("ADP") || name.starts_with("Mains") {
            let online_path = entry.path().join("online");
            if let Some(val) = read_file_string(&online_path) {
                return Some(val == "1");
            }
        }
    }

    None
}

/// Reads current live battery and AC power status directly from sysfs
pub fn status() -> Result<BatteryStatus, String> {
    let bat_dir = match find_battery_dir() {
        Some(dir) => dir,
        None => {
            // Desktop or system without a battery
            return Ok(BatteryStatus {
                percentage: 100,
                charging: false,
                on_battery: false,
                status: "AC Connected (No Battery)".to_string(),
                energy_now: 0,
                energy_full: 0,
                power_watts: 0.0,
                health_percentage: 100,
                time_to_full: 0,
                time_to_empty: 0,
            });
        }
    };

    let status_str = read_file_string(&bat_dir.join("status")).unwrap_or_else(|| "Unknown".to_string());
    let ac_online = is_ac_online();

    // Capacity percentage
    let capacity = read_file_u64(&bat_dir.join("capacity"));

    // Energy / Charge readings
    let energy_now = read_file_u64(&bat_dir.join("energy_now"))
        .or_else(|| read_file_u64(&bat_dir.join("charge_now")))
        .unwrap_or(0);

    let energy_full = read_file_u64(&bat_dir.join("energy_full"))
        .or_else(|| read_file_u64(&bat_dir.join("charge_full")))
        .unwrap_or(0);

    let energy_full_design = read_file_u64(&bat_dir.join("energy_full_design"))
        .or_else(|| read_file_u64(&bat_dir.join("charge_full_design")))
        .unwrap_or(energy_full);

    let percentage = if let Some(cap) = capacity {
        (cap as u32).min(100)
    } else if energy_full > 0 {
        ((energy_now as f64 / energy_full as f64) * 100.0).round() as u32
    } else {
        100
    };

    // Power consumption in watts
    let power_now = read_file_u64(&bat_dir.join("power_now"));
    let power_watts = if let Some(p) = power_now {
        p as f64 / 1_000_000.0
    } else {
        let voltage_now = read_file_u64(&bat_dir.join("voltage_now")).unwrap_or(0);
        let current_now = read_file_u64(&bat_dir.join("current_now")).unwrap_or(0);
        (voltage_now as f64 * current_now as f64) / 1_000_000_000_000.0
    };

    // Health percentage
    let health_percentage = if energy_full_design > 0 && energy_full > 0 {
        ((energy_full as f64 / energy_full_design as f64) * 100.0).round().min(100.0) as u32
    } else {
        100
    };

    // Determine on_battery and charging states accurately
    let on_battery = if status_str == "Discharging" {
        true
    } else if let Some(online) = ac_online {
        !online
    } else {
        status_str != "Charging" && status_str != "Full"
    };

    let charging = !on_battery;

    let (time_to_full, time_to_empty) = if power_watts > 0.05 {
        let p_raw = power_now.unwrap_or((power_watts * 1_000_000.0) as u64);
        if charging && energy_full > energy_now && p_raw > 0 {
            let secs = ((energy_full - energy_now) as f64 / p_raw as f64 * 3600.0) as u64;
            (secs, 0)
        } else if on_battery && energy_now > 0 && p_raw > 0 {
            let secs = (energy_now as f64 / p_raw as f64 * 3600.0) as u64;
            (0, secs)
        } else {
            (0, 0)
        }
    } else {
        (0, 0)
    };

    Ok(BatteryStatus {
        percentage,
        charging,
        on_battery,
        status: status_str,
        energy_now,
        energy_full,
        power_watts: (power_watts * 100.0).round() / 100.0,
        health_percentage,
        time_to_full,
        time_to_empty,
    })
}

/// Background daemon watching power supply changes with zero-latency responses
pub fn run_watch() -> Result<(), String> {
    println!("[NEXA Battery Watcher] Starting native power & battery daemon...");

    let mut last_on_battery: Option<bool> = None;
    let mut last_charging: Option<bool> = None;
    let mut last_percentage: Option<u32> = None;
    let mut low_battery_warned = false;
    let mut full_battery_warned = false;

    // Small startup delay to allow desktop compositor to settle
    thread::sleep(Duration::from_millis(500));

    loop {
        if let Ok(st) = status() {
            // Update central settings state if on_battery, charging, or percentage changed
            let state_changed = last_on_battery != Some(st.on_battery)
                || last_charging != Some(st.charging)
                || last_percentage != Some(st.percentage);

            if state_changed {
                let _ = crate::state::update_state(|s| {
                    s.battery_percentage = st.percentage;
                    s.battery_charging = st.charging;
                    s.on_battery = st.on_battery;
                });
            }

            if let (Some(prev_on_battery), Some(prev_charging)) = (last_on_battery, last_charging) {
                // Power source transition detected (Plugged in or Unplugged)
                if st.on_battery != prev_on_battery || st.charging != prev_charging {
                    if st.charging || !st.on_battery {
                        println!("[NEXA Battery Watcher] AC Charger connected ({}%)", st.percentage);
                        low_battery_warned = false;
                        crate::hardware::sound::play_sound("charging_cable_insert");
                        let _ = crate::hyprland::idle::sync_idle();
                        let _ = crate::desktop::island::trigger_battery_osd(true, st.percentage);
                    } else {
                        println!("[NEXA Battery Watcher] AC Charger disconnected ({}%)", st.percentage);
                        full_battery_warned = false;
                        crate::hardware::sound::play_sound("charging_cable_remove");
                        let _ = crate::hyprland::idle::sync_idle();
                        let _ = crate::desktop::island::trigger_battery_osd(false, st.percentage);
                    }
                }
            } else {
                // Initial baseline sync on daemon startup
                println!("[NEXA Battery Watcher] Initial state: on_battery={}, charging={}, pct={}%",
                    st.on_battery, st.charging, st.percentage);
                let _ = crate::hyprland::idle::sync_idle();
                if st.percentage <= 25 && st.on_battery {
                    low_battery_warned = true;
                } else if st.percentage >= 100 && st.charging {
                    full_battery_warned = true;
                }
            }

            // Low battery alert threshold (<= 25% and actively discharging)
            if st.on_battery && st.percentage <= 25 {
                if !low_battery_warned {
                    println!("[NEXA Battery Watcher] Low battery alert triggered ({}%)", st.percentage);
                    low_battery_warned = true;
                    crate::hardware::sound::play_sound("low_battery");
                    let _ = crate::desktop::island::trigger_low_battery_alert(st.percentage);
                }
            } else if st.percentage > 30 {
                low_battery_warned = false;
            }

            // Battery fully charged alert (100% while connected to AC)
            if st.charging && st.percentage >= 100 {
                if !full_battery_warned {
                    println!("[NEXA Battery Watcher] Full battery alert triggered");
                    full_battery_warned = true;
                    crate::hardware::sound::play_sound("Full-battery-charge");
                }
            } else if st.percentage < 99 {
                full_battery_warned = false;
            }

            last_on_battery = Some(st.on_battery);
            last_charging = Some(st.charging);
            last_percentage = Some(st.percentage);
        }

        thread::sleep(Duration::from_millis(800));
    }
}

pub fn handle(args: &[String]) -> Result<(), String> {
    if args.is_empty() || args[0] == "status" || args[0] == "info" || args[0] == "get" {
        let st = status()?;
        println!("{}", serde_json::to_string(&st).map_err(|e| e.to_string())?);
        return Ok(());
    }

    match args[0].as_str() {
        "watch" | "daemon" => run_watch(),
        action => Err(format!("Unknown battery action: {action}. Available: status, watch")),
    }
}

