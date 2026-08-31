use serde::{
    Deserialize,
    Serialize,
};

use std::{
    env,
    ffi::OsStr,
    fs,
    io::Write,
    path::PathBuf,
    process::Command,
    thread::sleep,
    time::Duration,
};


// ============================================================
// PUBLIC DATA
// ============================================================

#[derive(
    Debug,
    Clone,
    Serialize,
)]
pub struct AirplaneInfo {
    pub enabled: bool,

    pub wifi_enabled: bool,
    pub bluetooth_enabled: bool,

    pub restore_wifi: bool,
    pub restore_bluetooth: bool,
}


#[derive(
    Debug,
    Clone,
    Serialize,
)]
pub struct VpnInfo {
    pub enabled: bool,

    pub active: String,
    pub configured: Vec<String>,

    pub last: String,
}


// ============================================================
// PERSISTENT STATE
// ============================================================

#[derive(
    Debug,
    Clone,
    Serialize,
    Deserialize,
)]
struct SystemState {
    #[serde(default)]
    airplane_enabled: bool,

    #[serde(default)]
    wifi_before_airplane: bool,

    #[serde(default)]
    bluetooth_before_airplane: bool,

    #[serde(default)]
    last_vpn: String,
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
    let mut last_caps = read_led_state("capslock");
    let mut last_num = read_led_state("numlock");

    // Small startup sleep to let initial compositor state settle
    sleep(Duration::from_millis(600));
    last_caps = read_led_state("capslock");
    last_num = read_led_state("numlock");

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

pub fn handle(
    args: &[String],
) {
    if args.is_empty() {
        print_usage();
        return;
    }

    if args[0] == "keylock-watch" || args[0] == "lock-watch" {
        keylock_watch();
        return;
    }

    if args.len() < 2 {
        print_usage();
        return;
    }


    let result =
        match args[0].as_str() {

            // ====================================================
            // AIRPLANE
            // ====================================================

            "airplane" => {
                match args[1].as_str() {

                    "info" => {
                        airplane_info()
                            .and_then(print_json)
                    }


                    "on" => {
                        airplane_on()
                            .and_then(print_json)
                    }


                    "off" => {
                        airplane_off()
                            .and_then(print_json)
                    }


                    "toggle" => {
                        airplane_toggle()
                            .and_then(print_json)
                    }


                    _ => {
                        print_usage();
                        return;
                    }
                }
            }


            // ====================================================
            // VPN
            // ====================================================

            "vpn" => {
                match args[1].as_str() {

                    "info" => {
                        vpn_info()
                            .and_then(print_json)
                    }


                    "connect" => {
                        if args.len() < 3 {
                            Err(
                                "Missing VPN profile name"
                                    .to_string()
                            )
                        } else {
                            vpn_connect(
                                &args[2]
                            )
                            .and_then(print_json)
                        }
                    }


                    "disconnect" => {
                        vpn_disconnect()
                            .and_then(print_json)
                    }


                    "toggle" => {
                        vpn_toggle()
                            .and_then(print_json)
                    }


                    _ => {
                        print_usage();
                        return;
                    }
                }
            }


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
// AIRPLANE INFO
// ============================================================

pub fn airplane_info()
    -> Result<AirplaneInfo, String>
{
    let state =
        load_state();


    Ok(
        AirplaneInfo {
            enabled:
                state.airplane_enabled,

            wifi_enabled:
                wifi_enabled()?,

            bluetooth_enabled:
                bluetooth_enabled()?,

            restore_wifi:
                state.wifi_before_airplane,

            restore_bluetooth:
                state.bluetooth_before_airplane,
        }
    )
}


// ============================================================
// AIRPLANE ON
// ============================================================

pub fn airplane_on()
    -> Result<AirplaneInfo, String>
{
    let mut state =
        load_state();


    /*
     * Already active.
     *
     * Do not overwrite the saved restore state.
     */
    if state.airplane_enabled {
        return airplane_info();
    }


    let wifi =
        wifi_enabled()?;


    let bluetooth =
        bluetooth_enabled()?;


    /*
     * Remember exactly what was enabled before
     * entering Airplane Mode.
     */
    state.wifi_before_airplane =
        wifi;

    state.bluetooth_before_airplane =
        bluetooth;


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
        if let Err(error) =
            bluetooth_set_enabled(false)
        {
            /*
             * Bluetooth failed.
             *
             * Restore Wi-Fi so we do not leave the
             * system half-transitioned.
             */
            if wifi {
                let _ =
                    wifi_set_enabled(true);
            }

            return Err(error);
        }
    }


    state.airplane_enabled =
        true;


    save_state(
        &state
    )?;


    airplane_info()
}


// ============================================================
// AIRPLANE OFF
// ============================================================

pub fn airplane_off()
    -> Result<AirplaneInfo, String>
{
    let mut state =
        load_state();


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

    wifi_set_enabled(
        state.wifi_before_airplane
    )?;


    // --------------------------------------------------------
    // BLUETOOTH
    // --------------------------------------------------------

    bluetooth_set_enabled(
        state.bluetooth_before_airplane
    )?;


    state.airplane_enabled =
        false;


    save_state(
        &state
    )?;


    airplane_info()
}


// ============================================================
// AIRPLANE TOGGLE
// ============================================================

pub fn airplane_toggle()
    -> Result<AirplaneInfo, String>
{
    let state =
        load_state();


    if state.airplane_enabled {
        airplane_off()
    } else {
        airplane_on()
    }
}


// ============================================================
// WIFI
// ============================================================

fn wifi_enabled()
    -> Result<bool, String>
{
    Ok(
        run(
            "nmcli",
            [
                "radio",
                "wifi",
            ],
        )?
        .trim()
        == "enabled"
    )
}


fn wifi_set_enabled(
    enabled: bool,
) -> Result<(), String> {
    run(
        "nmcli",
        [
            "radio",
            "wifi",
            if enabled {
                "on"
            } else {
                "off"
            },
        ],
    )?;


    Ok(())
}


// ============================================================
// BLUETOOTH
// ============================================================

fn bluetooth_enabled()
    -> Result<bool, String>
{
    let output =
        run(
            "bluetoothctl",
            [
                "show",
            ],
        )?;


    Ok(
        output
            .lines()
            .any(
                |line|
                    line.trim()
                        == "Powered: yes"
            )
    )
}


fn bluetooth_set_enabled(
    enabled: bool,
) -> Result<(), String> {
    run(
        "bluetoothctl",
        [
            "power",
            if enabled {
                "on"
            } else {
                "off"
            },
        ],
    )?;


    Ok(())
}


// ============================================================
// VPN INFO
// ============================================================

pub fn vpn_info()
    -> Result<VpnInfo, String>
{
    let configured =
        configured_vpns()?;


    let active =
        active_vpns()?;


    let state =
        load_state();


    Ok(
        VpnInfo {
            enabled:
                !active.is_empty(),

            active:
                active
                    .first()
                    .cloned()
                    .unwrap_or_default(),

            configured,

            last:
                state.last_vpn,
        }
    )
}


// ============================================================
// VPN CONNECT
// ============================================================

pub fn vpn_connect(
    name: &str,
) -> Result<VpnInfo, String> {
    let configured =
        configured_vpns()?;


    if !configured.iter()
        .any(
            |profile|
                profile == name
        )
    {
        return Err(
            format!(
                "VPN profile not found: {name}"
            )
        );
    }


    /*
     * Disconnect another active VPN first.
     *
     * Quick Settings v1 is deliberately single-VPN.
     */
    let active =
        active_vpns()?;


    for current in active {
        if current != name {
            let _ =
                run(
                    "nmcli",
                    [
                        "connection",
                        "down",
                        "id",
                        &current,
                    ],
                );
        }
    }


    run(
        "nmcli",
        [
            "connection",
            "up",
            "id",
            name,
        ],
    )?;


    let mut state =
        load_state();


    state.last_vpn =
        name.to_string();


    save_state(
        &state
    )?;


    vpn_info()
}


// ============================================================
// VPN DISCONNECT
// ============================================================

pub fn vpn_disconnect()
    -> Result<VpnInfo, String>
{
    let active =
        active_vpns()?;


    for name in active {
        run(
            "nmcli",
            [
                "connection",
                "down",
                "id",
                &name,
            ],
        )?;
    }


    vpn_info()
}


// ============================================================
// VPN TOGGLE
// ============================================================

pub fn vpn_toggle()
    -> Result<VpnInfo, String>
{
    let info =
        vpn_info()?;


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
        return Err(
            "No VPN profiles configured in NetworkManager"
                .to_string()
        );
    }


    /*
     * Prefer the previously used VPN profile.
     */
    if !info.last.is_empty()
        && info.configured
            .iter()
            .any(
                |name|
                    name == &info.last
            )
    {
        return vpn_connect(
            &info.last
        );
    }


    /*
     * Otherwise use the first configured VPN.
     */
    vpn_connect(
        &info.configured[0]
    )
}


// ============================================================
// CONFIGURED VPN PROFILES
// ============================================================

fn configured_vpns()
    -> Result<Vec<String>, String>
{
    let output =
        run(
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


    let mut result =
        Vec::new();


    for line in output.lines() {
        let Some(
            (name, kind)
        ) = line.rsplit_once(':')
        else {
            continue;
        };


        /*
         * NetworkManager uses "vpn" for OpenVPN,
         * OpenConnect, etc.
         *
         * WireGuard profiles use "wireguard".
         */
        if kind != "vpn"
            && kind != "wireguard"
        {
            continue;
        }


        let name =
            name.trim();


        if name.is_empty() {
            continue;
        }


        if !result.iter()
            .any(
                |existing|
                    existing == name
            )
        {
            result.push(
                name.to_string()
            );
        }
    }


    result.sort();


    Ok(result)
}


// ============================================================
// ACTIVE VPN PROFILES
// ============================================================

fn active_vpns()
    -> Result<Vec<String>, String>
{
    let output =
        run(
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


    let mut result =
        Vec::new();


    for line in output.lines() {
        let Some(
            (name, kind)
        ) = line.rsplit_once(':')
        else {
            continue;
        };


        if kind != "vpn"
            && kind != "wireguard"
        {
            continue;
        }


        let name =
            name.trim();


        if !name.is_empty() {
            result.push(
                name.to_string()
            );
        }
    }


    Ok(result)
}


// ============================================================
// STATE PATH
// ============================================================

fn state_path()
    -> PathBuf
{
    let home =
        env::var("HOME")
            .unwrap_or_else(
                |_| ".".to_string()
            );


    PathBuf::from(home)
        .join(".config")
        .join("nexa")
        .join("config")
        .join("quicksettings.conf")
}


// ============================================================
// LOAD STATE
// ============================================================

fn load_state()
    -> SystemState
{
    let path =
        state_path();


    let Ok(content) =
        fs::read_to_string(path)
    else {
        return SystemState::default();
    };


    serde_json::from_str(
        &content
    )
    .unwrap_or_default()
}


// ============================================================
// SAVE STATE
// ============================================================

fn save_state(
    state: &SystemState,
) -> Result<(), String> {
    let path =
        state_path();


    if let Some(parent) =
        path.parent()
    {
        fs::create_dir_all(parent)
            .map_err(
                |error|
                    format!(
                        "Failed to create config directory: {error}"
                    )
            )?;
    }


    let content =
        serde_json::to_string_pretty(
            state
        )
        .map_err(
            |error|
                format!(
                    "Failed to serialize Quick Settings state: {error}"
                )
        )?;


    fs::write(
        &path,
        content,
    )
    .map_err(
        |error|
            format!(
                "Failed to save {}: {error}",
                path.display()
            )
    )
}


// ============================================================
// JSON
// ============================================================

fn print_json<T>(
    value: T,
) -> Result<(), String>
where
    T: Serialize,
{
    println!(
        "{}",
        serde_json::to_string(
            &value
        )
        .map_err(
            |error|
                error.to_string()
        )?
    );


    Ok(())
}


// ============================================================
// COMMAND
// ============================================================

fn run<I, S>(
    program: &str,
    args: I,
) -> Result<String, String>
where
    I: IntoIterator<Item = S>,
    S: AsRef<OsStr>,
{
    let output =
        Command::new(program)
            .args(args)
            .output()
            .map_err(
                |error|
                    format!(
                        "{program}: {error}"
                    )
            )?;


    if !output.status.success() {
        let stderr =
            String::from_utf8_lossy(
                &output.stderr
            )
            .trim()
            .to_string();


        let stdout =
            String::from_utf8_lossy(
                &output.stdout
            )
            .trim()
            .to_string();


        return Err(
            if !stderr.is_empty() {
                stderr
            } else if !stdout.is_empty() {
                stdout
            } else {
                format!(
                    "{program} exited with {}",
                    output.status
                )
            }
        );
    }


    Ok(
        String::from_utf8_lossy(
            &output.stdout
        )
        .trim()
        .to_string()
    )
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
