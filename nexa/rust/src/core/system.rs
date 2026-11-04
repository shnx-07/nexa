use serde::{Deserialize, Serialize};

use std::{
    env, ffi::OsStr, fs, io::Write, path::PathBuf, process::Command, thread::sleep, time::Duration,
};

// ============================================================
// PUBLIC DATA
// ============================================================

#[derive(Debug, Clone, Serialize)]
pub struct AirplaneInfo {
    pub enabled: bool,

    pub wifi_enabled: bool,
    pub bluetooth_enabled: bool,

    pub restore_wifi: bool,
    pub restore_bluetooth: bool,
}

#[derive(Debug, Clone, Serialize)]
pub struct VpnInfo {
    pub enabled: bool,

    pub active: String,
    pub configured: Vec<String>,

    pub last: String,
}

// ============================================================
// TIMESTAMP FORMATTER (ZERO-FORK NATIVE LOCALTIME)
// ============================================================

pub fn format_timestamp(secs: i64) -> String {
    let mut tm: libc::tm = unsafe { std::mem::zeroed() };
    let time_val: libc::time_t = secs as libc::time_t;
    if unsafe { libc::localtime_r(&time_val, &mut tm) }.is_null() {
        return secs.to_string();
    }
    let mut buf = [0u8; 64];
    let len = unsafe {
        libc::strftime(
            buf.as_mut_ptr() as *mut libc::c_char,
            buf.len(),
            b"%Y-%m-%d_%H-%M-%S\0".as_ptr() as *const libc::c_char,
            &tm,
        )
    };
    if len > 0 {
        String::from_utf8_lossy(&buf[..len]).to_string()
    } else {
        secs.to_string()
    }
}

// ============================================================
// PERSISTENT STATE
// ============================================================

#[derive(Debug, Clone, Serialize, Deserialize)]
pub(crate) struct SystemState {
    #[serde(default)]
    pub airplane_enabled: bool,

    #[serde(default)]
    pub wifi_before_airplane: bool,

    #[serde(default)]
    pub bluetooth_before_airplane: bool,

    #[serde(default)]
    pub last_vpn: String,
}

impl Default for SystemState {
    fn default() -> Self {
        Self {
            airplane_enabled: false,

            wifi_before_airplane: false,
            bluetooth_before_airplane: false,

            last_vpn: String::new(),
        }
    }
}

// ============================================================
// KEYBOARD LOCK LED WATCHER
// ============================================================

fn read_led_state(keyword: &str) -> bool {
    let Ok(entries) = fs::read_dir("/sys/class/leds") else {
        return false;
    };

    for entry in entries.flatten() {
        let name = entry.file_name().to_string_lossy().to_string();
        if name.contains(keyword) {
            let brightness_path = entry.path().join("brightness");
            if let Ok(content) = fs::read_to_string(brightness_path) {
                if content.trim() != "0" {
                    return true;
                }
            }
        }
    }
    false
}

pub fn keylock_watch() {
    // Small startup sleep to let initial compositor state settle
    sleep(Duration::from_millis(600));
    let mut last_caps = read_led_state("capslock");
    let mut last_num = read_led_state("numlock");

    let stdout = std::io::stdout();
    let mut handle = stdout.lock();

    loop {
        sleep(Duration::from_millis(50));

        let caps = read_led_state("capslock");
        if caps != last_caps {
            let _ = writeln!(handle, "CAPS:{}", caps);
            let _ = handle.flush();
            last_caps = caps;
        }

        let num = read_led_state("numlock");
        if num != last_num {
            let _ = writeln!(handle, "NUM:{}", num);
            let _ = handle.flush();
            last_num = num;
        }
    }
}

// ============================================================
// CLI
// ============================================================

pub fn handle(args: &[String]) {
    if args.is_empty() {
        print_usage();
        return;
    }

    if args[0] == "keylock-watch" || args[0] == "lock-watch" {
        keylock_watch();
        return;
    }

    if args[0] == "profile" || args[0] == "info" {
        profile_info();
        return;
    }

    if args.len() < 2 {
        print_usage();
        return;
    }

    let result = match args[0].as_str() {
        // ====================================================
        // AIRPLANE
        // ====================================================
        "airplane" => match args[1].as_str() {
            "info" => airplane_info().and_then(print_json),

            "on" => airplane_on().and_then(print_json),

            "off" => airplane_off().and_then(print_json),

            "toggle" => airplane_toggle().and_then(print_json),

            _ => {
                print_usage();
                return;
            }
        },

        // ====================================================
        // VPN
        // ====================================================
        "vpn" => match args[1].as_str() {
            "info" => vpn_info().and_then(print_json),

            "connect" => {
                if args.len() < 3 {
                    Err("Missing VPN profile name".to_string())
                } else {
                    vpn_connect(&args[2]).and_then(print_json)
                }
            }

            "disconnect" => vpn_disconnect().and_then(print_json),

            "toggle" => vpn_toggle().and_then(print_json),

            _ => {
                print_usage();
                return;
            }
        },

        // ====================================================
        // SYSTEM MONITOR & HISTORY
        // ====================================================
        "monitor" => match args[1].as_str() {
            "history" => crate::hardware::system_monitor::get_cached_history().and_then(print_json),
            "current" => {
                let mut sampler = crate::hardware::system_monitor::SystemSampler::new();
                std::thread::sleep(std::time::Duration::from_millis(150));
                let snap = sampler.sample();
                print_json(snap)
            }
            "watch" | "daemon" => crate::hardware::system_monitor::run_watch(),
            _ => {
                print_usage();
                return;
            }
        },

        _ => {
            print_usage();
            return;
        }
    };

    if let Err(error) = result {
        eprintln!("{error}");
    }
}

// ============================================================
// PROFILE & SYSTEM OVERVIEW INFO
// ============================================================

pub fn profile_info() {
    let user = env::var("USER").unwrap_or_else(|_| "user".into());
    let host = fs::read_to_string("/etc/hostname")
        .map(|s| s.trim().to_string())
        .unwrap_or_else(|_| "localhost".into());

    let mut os_name = String::new();
    if let Ok(content) = fs::read_to_string("/etc/os-release") {
        for line in content.lines() {
            if let Some(val) = line.strip_prefix("PRETTY_NAME=") {
                os_name = val.trim_matches('"').trim_matches('\'').to_string();
                break;
            }
        }
    }
    if os_name.is_empty() {
        os_name = "Linux".into();
    }

    let mut uts: libc::utsname = unsafe { std::mem::zeroed() };
    let kernel = if unsafe { libc::uname(&mut uts) } == 0 {
        let rel = unsafe { std::ffi::CStr::from_ptr(uts.release.as_ptr()) }.to_string_lossy();
        let mach = unsafe { std::ffi::CStr::from_ptr(uts.machine.as_ptr()) }.to_string_lossy();
        format!("{rel} {mach}")
    } else {
        "Unknown".into()
    };

    let shell = env::var("SHELL")
        .map(|s| {
            std::path::Path::new(&s)
                .file_name()
                .unwrap_or_default()
                .to_string_lossy()
                .to_string()
        })
        .unwrap_or_else(|_| "bash".into());

    let mut uptime_str = String::new();
    if let Ok(content) = fs::read_to_string("/proc/uptime") {
        if let Some(sec_str) = content.split_whitespace().next() {
            if let Ok(secs_f) = sec_str.parse::<f64>() {
                let total_secs = secs_f as u64;
                let days = total_secs / 86400;
                let hours = (total_secs % 86400) / 3600;
                let mins = (total_secs % 3600) / 60;
                let mut parts = Vec::new();
                if days > 0 {
                    parts.push(format!("{days} day{}", if days > 1 { "s" } else { "" }));
                }
                if hours > 0 {
                    parts.push(format!("{hours} hour{}", if hours > 1 { "s" } else { "" }));
                }
                if mins > 0 || parts.is_empty() {
                    parts.push(format!("{mins} minute{}", if mins != 1 { "s" } else { "" }));
                }
                uptime_str = parts.join(", ");
            }
        }
    }

    let mut cpu = String::new();
    if let Ok(content) = fs::read_to_string("/proc/cpuinfo") {
        for line in content.lines() {
            if line.starts_with("model name") {
                if let Some((_, val)) = line.split_once(':') {
                    cpu = val.trim().to_string();
                    break;
                }
            }
        }
    }

    let mut mem_str = String::new();
    if let Ok(content) = fs::read_to_string("/proc/meminfo") {
        let mut total_kb = 0u64;
        let mut avail_kb = 0u64;
        for line in content.lines() {
            if let Some(val) = line.strip_prefix("MemTotal:") {
                total_kb = val.trim().split_whitespace().next().and_then(|s| s.parse().ok()).unwrap_or(0);
            } else if let Some(val) = line.strip_prefix("MemAvailable:") {
                avail_kb = val.trim().split_whitespace().next().and_then(|s| s.parse().ok()).unwrap_or(0);
            }
        }
        if total_kb > 0 {
            let used_kb = total_kb.saturating_sub(avail_kb);
            let fmt_unit = |kb: u64| -> String {
                if kb >= 1024 * 1024 {
                    format!("{:.1}Gi", kb as f64 / (1024.0 * 1024.0))
                } else {
                    format!("{}Mi", kb / 1024)
                }
            };
            mem_str = format!("{} / {}", fmt_unit(used_kb), fmt_unit(total_kb));
        }
    }

    let (wp_kind, _, wp_path) = crate::wallpaper::apply::load_current_wallpaper_state();
    let (lock_path, lock_kind) = if let Ok(contents) = fs::read_to_string(crate::wallpaper::apply::lock_config_path()) {
        crate::wallpaper::apply::parse_wallpaper_config(&contents)
    } else {
        (String::new(), String::new())
    };

    println!("USER {user}");
    println!("HOST {host}");
    println!("OS {os_name}");
    println!("KERNEL {kernel}");
    println!("SHELL {shell}");
    println!("UPTIME {uptime_str}");
    println!("CPU {cpu}");
    println!("MEMORY {mem_str}");
    println!("WALLPAPER {wp_path}");
    println!("WALLPAPER_TYPE {}", if wp_kind.is_empty() { "image" } else { &wp_kind });
    println!("LOCK_WALLPAPER {lock_path}");
    println!("LOCK_WALLPAPER_TYPE {}", if lock_kind.is_empty() { "image" } else { &lock_kind });
}

// ============================================================
// AIRPLANE INFO
// ============================================================

pub fn airplane_info() -> Result<AirplaneInfo, String> {
    let state = load_state();

    Ok(AirplaneInfo {
        enabled: state.airplane_enabled,

        wifi_enabled: wifi_enabled()?,

        bluetooth_enabled: bluetooth_enabled()?,

        restore_wifi: state.wifi_before_airplane,

        restore_bluetooth: state.bluetooth_before_airplane,
    })
}

// ============================================================
// AIRPLANE ON
// ============================================================

pub fn airplane_on() -> Result<AirplaneInfo, String> {
    let mut state = load_state();

    /*
     * Already active.
     *
     * Do not overwrite the saved restore state.
     */
    if state.airplane_enabled {
        return airplane_info();
    }

    let wifi = wifi_enabled()?;

    let bluetooth = bluetooth_enabled()?;

    /*
     * Remember exactly what was enabled before
     * entering Airplane Mode.
     */
    state.wifi_before_airplane = wifi;

    state.bluetooth_before_airplane = bluetooth;

    // --------------------------------------------------------
    // DISABLE WIFI
    // --------------------------------------------------------

    if wifi {
        wifi_set_enabled(false)?;
    }

    // --------------------------------------------------------
    // DISABLE BLUETOOTH
    // --------------------------------------------------------

    if bluetooth {
        if let Err(error) = bluetooth_set_enabled(false) {
            /*
             * Bluetooth failed.
             *
             * Restore Wi-Fi so we do not leave the
             * system half-transitioned.
             */
            if wifi {
                let _ = wifi_set_enabled(true);
            }

            return Err(error);
        }
    }

    state.airplane_enabled = true;

    save_state(&state)?;

    let _ = crate::state::update_state(|s| {
        s.airplane_enabled = true;
        s.wifi_enabled = false;
        s.bluetooth_enabled = false;
    });

    airplane_info()
}

// ============================================================
// AIRPLANE OFF
// ============================================================

pub fn airplane_off() -> Result<AirplaneInfo, String> {
    let mut state = load_state();

    if !state.airplane_enabled {
        return airplane_info();
    }

    /*
     * Restore only the radios which were enabled
     * before Airplane Mode was entered.
     *
     * Example:
     *
     * Wi-Fi ON
     * Bluetooth OFF
     *
     * Airplane ON:
     *     Wi-Fi OFF
     *     Bluetooth OFF
     *
     * Airplane OFF:
     *     Wi-Fi ON
     *     Bluetooth stays OFF
     */

    // --------------------------------------------------------
    // WIFI
    // --------------------------------------------------------

    wifi_set_enabled(state.wifi_before_airplane)?;

    // --------------------------------------------------------
    // BLUETOOTH
    // --------------------------------------------------------

    bluetooth_set_enabled(state.bluetooth_before_airplane)?;

    state.airplane_enabled = false;

    save_state(&state)?;

    let wifi_restored = state.wifi_before_airplane;
    let bt_restored = state.bluetooth_before_airplane;
    let _ = crate::state::update_state(|s| {
        s.airplane_enabled = false;
        s.wifi_enabled = wifi_restored;
        s.bluetooth_enabled = bt_restored;
    });

    airplane_info()
}

// ============================================================
// AIRPLANE TOGGLE
// ============================================================

pub fn airplane_toggle() -> Result<AirplaneInfo, String> {
    let state = load_state();

    if state.airplane_enabled {
        airplane_off()
    } else {
        airplane_on()
    }
}

// ============================================================
// WIFI
// ============================================================

fn wifi_enabled() -> Result<bool, String> {
    Ok(run("nmcli", ["radio", "wifi"])?.trim() == "enabled")
}

fn wifi_set_enabled(enabled: bool) -> Result<(), String> {
    run(
        "nmcli",
        ["radio", "wifi", if enabled { "on" } else { "off" }],
    )?;

    Ok(())
}

// ============================================================
// BLUETOOTH
// ============================================================

fn bluetooth_enabled() -> Result<bool, String> {
    let output = run("bluetoothctl", ["show"])?;

    Ok(output.lines().any(|line| line.trim() == "Powered: yes"))
}

fn bluetooth_set_enabled(enabled: bool) -> Result<(), String> {
    run(
        "bluetoothctl",
        ["power", if enabled { "on" } else { "off" }],
    )?;

    Ok(())
}

// ============================================================
// VPN INFO
// ============================================================

pub fn vpn_info() -> Result<VpnInfo, String> {
    let configured = configured_vpns()?;

    let active = active_vpns()?;

    let state = load_state();

    Ok(VpnInfo {
        enabled: !active.is_empty(),

        active: active.first().cloned().unwrap_or_default(),

        configured,

        last: state.last_vpn,
    })
}

// ============================================================
// VPN CONNECT
// ============================================================

pub fn vpn_connect(name: &str) -> Result<VpnInfo, String> {
    let configured = configured_vpns()?;

    if !configured.iter().any(|profile| profile == name) {
        return Err(format!("VPN profile not found: {name}"));
    }

    /*
     * Disconnect another active VPN first.
     *
     * Quick Settings v1 is deliberately single-VPN.
     */
    let active = active_vpns()?;

    for current in active {
        if current != name {
            let _ = run("nmcli", ["connection", "down", "id", &current]);
        }
    }

    run("nmcli", ["connection", "up", "id", name])?;

    let mut state = load_state();

    state.last_vpn = name.to_string();

    save_state(&state)?;

    vpn_info()
}

// ============================================================
// VPN DISCONNECT
// ============================================================

pub fn vpn_disconnect() -> Result<VpnInfo, String> {
    let active = active_vpns()?;

    for name in active {
        run("nmcli", ["connection", "down", "id", &name])?;
    }

    vpn_info()
}

// ============================================================
// VPN TOGGLE
// ============================================================

pub fn vpn_toggle() -> Result<VpnInfo, String> {
    let info = vpn_info()?;

    /*
     * Active VPN:
     * disconnect it.
     */
    if info.enabled {
        return vpn_disconnect();
    }

    /*
     * No configured VPN profiles.
     */
    if info.configured.is_empty() {
        return Err("No VPN profiles configured in NetworkManager".to_string());
    }

    /*
     * Prefer the previously used VPN profile.
     */
    if !info.last.is_empty() && info.configured.iter().any(|name| name == &info.last) {
        return vpn_connect(&info.last);
    }

    /*
     * Otherwise use the first configured VPN.
     */
    vpn_connect(&info.configured[0])
}

// ============================================================
// CONFIGURED VPN PROFILES
// ============================================================

fn configured_vpns() -> Result<Vec<String>, String> {
    let output = run(
        "nmcli",
        [
            "-t",
            "--escape",
            "no",
            "-f",
            "NAME,TYPE",
            "connection",
            "show",
        ],
    )?;

    let mut result = Vec::new();

    for line in output.lines() {
        let Some((name, kind)) = line.rsplit_once(':') else {
            continue;
        };

        /*
         * NetworkManager uses "vpn" for OpenVPN,
         * OpenConnect, etc.
         *
         * WireGuard profiles use "wireguard".
         */
        if kind != "vpn" && kind != "wireguard" {
            continue;
        }

        let name = name.trim();

        if name.is_empty() {
            continue;
        }

        if !result.iter().any(|existing| existing == name) {
            result.push(name.to_string());
        }
    }

    result.sort();

    Ok(result)
}

// ============================================================
// ACTIVE VPN PROFILES
// ============================================================

fn active_vpns() -> Result<Vec<String>, String> {
    let output = run(
        "nmcli",
        [
            "-t",
            "--escape",
            "no",
            "-f",
            "NAME,TYPE",
            "connection",
            "show",
            "--active",
        ],
    )?;

    let mut result = Vec::new();

    for line in output.lines() {
        let Some((name, kind)) = line.rsplit_once(':') else {
            continue;
        };

        if kind != "vpn" && kind != "wireguard" {
            continue;
        }

        let name = name.trim();

        if !name.is_empty() {
            result.push(name.to_string());
        }
    }

    Ok(result)
}

// ============================================================
// STATE PATH
// ============================================================

fn state_path() -> PathBuf {
    let home = env::var("HOME").unwrap_or_else(|_| ".".to_string());

    PathBuf::from(home)
        .join(".config")
        .join("nexa")
        .join("config")
        .join("quicksettings.conf")
}

// ============================================================
// LOAD STATE
// ============================================================

pub(crate) fn load_state() -> SystemState {
    let path = state_path();

    let Ok(content) = fs::read_to_string(path) else {
        return SystemState::default();
    };

    serde_json::from_str(&content).unwrap_or_default()
}

// ============================================================
// SAVE STATE
// ============================================================

pub(crate) fn save_state(state: &SystemState) -> Result<(), String> {
    let path = state_path();

    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)
            .map_err(|error| format!("Failed to create config directory: {error}"))?;
    }

    let content = serde_json::to_string_pretty(state)
        .map_err(|error| format!("Failed to serialize Quick Settings state: {error}"))?;

    fs::write(&path, content).map_err(|error| format!("Failed to save {}: {error}", path.display()))
}

// ============================================================
// JSON
// ============================================================

fn print_json<T>(value: T) -> Result<(), String>
where
    T: Serialize,
{
    println!(
        "{}",
        serde_json::to_string(&value).map_err(|error| error.to_string())?
    );

    Ok(())
}

// ============================================================
// COMMAND
// ============================================================

fn run<I, S>(program: &str, args: I) -> Result<String, String>
where
    I: IntoIterator<Item = S>,
    S: AsRef<OsStr>,
{
    let output = Command::new(program)
        .args(args)
        .output()
        .map_err(|error| format!("{program}: {error}"))?;

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr).trim().to_string();

        let stdout = String::from_utf8_lossy(&output.stdout).trim().to_string();

        return Err(if !stderr.is_empty() {
            stderr
        } else if !stdout.is_empty() {
            stdout
        } else {
            format!("{program} exited with {}", output.status)
        });
    }

    Ok(String::from_utf8_lossy(&output.stdout).trim().to_string())
}

// ============================================================
// USAGE
// ============================================================

fn print_usage() {
    eprintln!(
        "Usage:
  nexad system airplane info
  nexad system airplane on
  nexad system airplane off
  nexad system airplane toggle

  nexad system vpn info
  nexad system vpn connect <profile>
  nexad system vpn disconnect
  nexad system vpn toggle

  nexad system keylock-watch"
    );
}
