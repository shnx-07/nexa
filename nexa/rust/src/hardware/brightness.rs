use serde::Serialize;
use std::fs;
use std::path::{Path, PathBuf};

#[derive(Debug, Serialize)]
pub struct BrightnessInfo {
    pub brightness: u32,
    pub current: u64,
    pub maximum: u64,
}

/// Discovers the active backlight device under /sys/class/backlight
fn find_backlight_device() -> Result<PathBuf, String> {
    let backlight_dir = Path::new("/sys/class/backlight");
    if !backlight_dir.exists() {
        return Err("No /sys/class/backlight directory found on system".to_string());
    }

    let entries = fs::read_dir(backlight_dir)
        .map_err(|e| format!("Failed to read /sys/class/backlight: {e}"))?;

    let mut candidate: Option<PathBuf> = None;

    for entry in entries.flatten() {
        let path = entry.path();
        if path.join("brightness").exists() && path.join("max_brightness").exists() {
            // If we find an amdgpu or intel device, prioritize it over firmware/acpi
            let name = path.file_name().unwrap_or_default().to_string_lossy();
            if name.contains("amdgpu") || name.contains("intel") {
                return Ok(path);
            }
            if candidate.is_none() {
                candidate = Some(path);
            }
        }
    }

    candidate.ok_or_else(|| "No valid backlight device found under /sys/class/backlight".to_string())
}

/// Reads current brightness and maximum brightness directly from sysfs
pub fn info() -> Result<BrightnessInfo, String> {
    let dev = find_backlight_device()?;

    let cur_str = fs::read_to_string(dev.join("brightness"))
        .map_err(|e| format!("Failed to read brightness from sysfs: {e}"))?;
    let max_str = fs::read_to_string(dev.join("max_brightness"))
        .map_err(|e| format!("Failed to read max_brightness from sysfs: {e}"))?;

    let current: u64 = cur_str.trim().parse()
        .map_err(|e| format!("Failed to parse brightness value '{cur_str}': {e}"))?;
    let maximum: u64 = max_str.trim().parse()
        .map_err(|e| format!("Failed to parse max_brightness value '{max_str}': {e}"))?;

    if maximum == 0 {
        return Err("Invalid max_brightness: 0".to_string());
    }

    let percentage = (((current as f64) / (maximum as f64) * 100.0).round() as u32).clamp(1, 100);

    Ok(BrightnessInfo {
        brightness: percentage,
        current,
        maximum,
    })
}

/// Writes target raw brightness. Tries direct sysfs write first; falls back to systemd login1 D-Bus.
fn write_raw_brightness(dev: &Path, raw_value: u64) -> Result<(), String> {
    let brightness_path = dev.join("brightness");

    // 1. Try direct sysfs write (fastest if permissions allow)
    if let Ok(()) = fs::write(&brightness_path, raw_value.to_string()) {
        return Ok(());
    }

    // 2. Fallback: Call org.freedesktop.login1 SetBrightness over system D-Bus via zbus
    let dev_name = dev
        .file_name()
        .and_then(|n| n.to_str())
        .ok_or_else(|| "Invalid device path".to_string())?;

    let connection = zbus::blocking::Connection::system()
        .map_err(|e| format!("Failed to connect to system D-Bus: {e}"))?;

    // Call method: SetBrightness(type: "backlight", device: dev_name, brightness: raw_value as u32)
    let raw_u32 = raw_value.min(u32::MAX as u64) as u32;

    connection
        .call_method(
            Some("org.freedesktop.login1"),
            "/org/freedesktop/login1/session/auto",
            Some("org.freedesktop.login1.Session"),
            "SetBrightness",
            &("backlight", dev_name, raw_u32),
        )
        .map_err(|e| format!("login1 SetBrightness D-Bus call failed: {e}"))?;

    Ok(())
}

/// Sets screen brightness to a specific percentage (1-100)
pub fn set(brightness: u32) -> Result<BrightnessInfo, String> {
    let target_pct = brightness.clamp(1, 100);
    let dev = find_backlight_device()?;

    let max_str = fs::read_to_string(dev.join("max_brightness"))
        .map_err(|e| format!("Failed to read max_brightness from sysfs: {e}"))?;
    let maximum: u64 = max_str.trim().parse()
        .map_err(|e| format!("Failed to parse max_brightness value: {e}"))?;

    let raw_target = ((target_pct as f64 / 100.0) * maximum as f64).round() as u64;
    let raw_target = raw_target.clamp(1, maximum);

    write_raw_brightness(&dev, raw_target)?;

    let res = BrightnessInfo {
        brightness: target_pct,
        current: raw_target,
        maximum,
    };

    let _ = crate::state::update_state(|s| {
        s.brightness = res.brightness;
    });

    Ok(res)
}

/// Increases screen brightness by percentage amount
pub fn up(amount: u32) -> Result<BrightnessInfo, String> {
    let current_info = info()?;
    let new_pct = (current_info.brightness + amount).min(100);
    set(new_pct)
}

/// Decreases screen brightness by percentage amount
pub fn down(amount: u32) -> Result<BrightnessInfo, String> {
    let current_info = info()?;
    let new_pct = current_info.brightness.saturating_sub(amount).max(1);
    set(new_pct)
}

fn print_json(result: Result<BrightnessInfo, String>) -> Result<(), String> {
    let info = result?;
    println!(
        "{}",
        serde_json::to_string(&info).map_err(|error| error.to_string())?
    );
    Ok(())
}

pub fn handle(args: &[String]) -> Result<(), String> {
    if args.is_empty() {
        return Err("usage: nexad brightness <info|set|up|down>".to_string());
    }

    match args[0].as_str() {
        "info" => print_json(info()),

        "set" => {
            let value = args
                .get(1)
                .ok_or_else(|| "missing brightness percentage".to_string())?;

            let brightness = value
                .parse::<u32>()
                .map_err(|_| "invalid brightness percentage".to_string())?;

            print_json(set(brightness))
        }

        "up" => {
            let amount = args
                .get(1)
                .map(String::as_str)
                .unwrap_or("5")
                .parse::<u32>()
                .map_err(|_| "invalid brightness amount".to_string())?;

            print_json(up(amount))
        }

        "down" => {
            let amount = args
                .get(1)
                .map(String::as_str)
                .unwrap_or("5")
                .parse::<u32>()
                .map_err(|_| "invalid brightness amount".to_string())?;

            print_json(down(amount))
        }

        _ => Err("usage: nexad brightness <info|set|up|down>".to_string()),
    }
}
