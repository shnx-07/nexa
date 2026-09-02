use serde::Serialize;
use std::{
    collections::HashSet,
    ffi::OsStr,
    fs,
    process::Command,
    sync::Mutex,
    thread,
    time::{
        Duration,
        Instant,
    },
};


// ============================================================
// PUBLIC DATA
// ============================================================

#[derive(Debug, Clone, Serialize)]
pub struct WifiInfo {
    pub enabled: bool,
    pub connected: bool,

    pub interface: String,
    pub ssid: String,
    pub signal: u8,
    pub security: String,

    pub frequency_mhz: u32,
    pub band: String,

    pub ipv4: String,

    pub download_bps: u64,
    pub upload_bps: u64,
}


#[derive(Debug, Clone, Serialize)]
pub struct WifiNetwork {
    pub ssid: String,
    pub signal: u8,
    pub security: String,

    pub frequency_mhz: u32,
    pub band: String,

    pub known: bool,
    pub connected: bool,
}


#[derive(Debug, Clone, Serialize)]
pub struct BluetoothInfo {
    pub enabled: bool,
    pub devices: Vec<BluetoothDevice>,
}


#[derive(Debug, Clone, Serialize)]
pub struct BluetoothDevice {
    pub address: String,
    pub name: String,
    pub device_type: String,

    pub paired: bool,
    pub connected: bool,
    pub trusted: bool,
}


// ============================================================
// INTERNAL TRAFFIC STATE
// ============================================================

struct TrafficSample {
    interface: String,
    rx: u64,
    tx: u64,
    at: Instant,
}


pub struct NetworkService {
    traffic: Mutex<Option<TrafficSample>>,
}


impl NetworkService {

    pub fn new() -> Self {
        Self {
            traffic: Mutex::new(None),
        }
    }


    // ========================================================
    // WIFI STATUS
    // ========================================================

    pub fn wifi_info(&self) -> Result<WifiInfo, String> {

        let enabled =
            run("nmcli", ["radio", "wifi"])?
            == "enabled";

        let interface =
            wifi_interface().unwrap_or_default();

        let networks =
            self.wifi_scan(false)?;

        let current =
            networks.iter().find(|n| n.connected);

        let ipv4 =
            if interface.is_empty() {
                String::new()
            } else {
                wifi_ipv4(&interface)
            };

        let (download_bps, upload_bps) =
            if interface.is_empty() {
                (0, 0)
            } else {
                self.traffic_rate(&interface)
            };


        Ok(WifiInfo {
            enabled,

            connected:
                current.is_some(),

            interface,

            ssid:
                current
                    .map(|n| n.ssid.clone())
                    .unwrap_or_default(),

            signal:
                current
                    .map(|n| n.signal)
                    .unwrap_or(0),

            security:
                current
                    .map(|n| n.security.clone())
                    .unwrap_or_default(),

            frequency_mhz:
                current
                    .map(|n| n.frequency_mhz)
                    .unwrap_or(0),

            band:
                current
                    .map(|n| n.band.clone())
                    .unwrap_or_default(),

            ipv4,

            download_bps,
            upload_bps,
        })
    }


    // ========================================================
    // WIFI SCAN
    // ========================================================

    pub fn wifi_scan(
        &self,
        force: bool,
    ) -> Result<Vec<WifiNetwork>, String> {

        let rescan =
            if force { "yes" } else { "no" };

        let output = run(
            "nmcli",
            [
                "-t",
                "--escape",
                "no",
                "-f",
                "IN-USE,SSID,SIGNAL,SECURITY,FREQ",
                "device",
                "wifi",
                "list",
                "--rescan",
                rescan,
            ],
        )?;

        let saved = saved_wifi_ssids();

        let mut networks = Vec::new();


        for line in output.lines() {

            let parts: Vec<&str> = line.split(':').collect();

            if parts.len() < 5 {
                continue;
            }

            let ssid = parts[1].trim();

            if ssid.is_empty() {
                continue;
            }

            let signal =
                parts[2]
                    .parse::<u8>()
                    .unwrap_or(0);

            let frequency =
                parts[4]
                    .parse::<u32>()
                    .unwrap_or(0);


            let network = WifiNetwork {
                ssid: ssid.to_string(),

                signal,

                security:
                    parts[3].trim().to_string(),

                frequency_mhz:
                    frequency,

                band:
                    band_from_frequency(frequency),

                known:
                    saved.contains(ssid),

                connected:
                    parts[0].trim() == "*",
            };


            // Same SSID may appear from multiple APs.
            // Keep only strongest one.
            if let Some(existing) =
                networks
                    .iter_mut()
                    .find(|n: &&mut WifiNetwork| n.ssid == network.ssid)
            {
                if network.signal > existing.signal {
                    *existing = network;
                }
            } else {
                networks.push(network);
            }
        }


        networks.sort_by(
            |a, b| b.signal.cmp(&a.signal)
        );

        Ok(networks)
    }


    // ========================================================
    // WIFI ACTIONS
    // ========================================================

    pub fn wifi_set_enabled(
        &self,
        enabled: bool,
    ) -> Result<(), String> {

        run(
            "nmcli",
            [
                "radio",
                "wifi",
                if enabled { "on" } else { "off" },
            ],
        )?;

        Ok(())
    }


    pub fn wifi_connect(
        &self,
        ssid: &str,
        password: Option<&str>,
    ) -> Result<(), String> {

        let mut args = vec![
            "device",
            "wifi",
            "connect",
            ssid,
        ];

        if let Some(password) = password {
            if !password.is_empty() {
                args.push("password");
                args.push(password);
            }
        }

        run("nmcli", args)?;

        Ok(())
    }


    pub fn wifi_disconnect(
        &self,
    ) -> Result<(), String> {

        let interface =
            wifi_interface()
                .ok_or("No Wi-Fi interface found")?;

        run(
            "nmcli",
            [
                "device",
                "disconnect",
                &interface,
            ],
        )?;

        Ok(())
    }


    pub fn wifi_forget(
        &self,
        ssid: &str,
    ) -> Result<(), String> {

        let uuid =
            wifi_profile_uuid(ssid)
                .ok_or("Saved Wi-Fi profile not found")?;

        run(
            "nmcli",
            [
                "connection",
                "delete",
                "uuid",
                &uuid,
            ],
        )?;

        Ok(())
    }


    pub fn wifi_refresh(
        &self,
    ) -> Result<Vec<WifiNetwork>, String> {

        self.wifi_scan(true)
    }


    // ========================================================
    // BLUETOOTH STATUS
    // ========================================================

    pub fn bluetooth_info(
    &self,
    ) -> Result<BluetoothInfo, String> {

        // --------------------------------------------------------
        // ADAPTER POWER STATE
        // --------------------------------------------------------

        let show =
            run(
                "bluetoothctl",
                ["show"],
            )?;

        let enabled =
            show.lines().any(
                |line|
                    line.trim()
                        == "Powered: yes"
            );


        // --------------------------------------------------------
        // ALL DEVICES KNOWN TO BLUEZ
        //
        // IMPORTANT:
        //
        // Do NOT use:
        //
        //     bluetoothctl devices Connected
        //
        // because that only returns currently connected devices.
        //
        // `bluetoothctl devices` gives us:
        //
        // - connected devices
        // - paired devices
        // - discovered / available devices
        //
        // Then `bluetoothctl info` tells us the state of each.
        // --------------------------------------------------------

        let output =
            run(
                "bluetoothctl",
                ["devices"],
            )
            .unwrap_or_default();


        let mut devices =
            Vec::new();


        let mut seen_addresses =
            HashSet::new();


        for line in output.lines() {

            // Expected format:
            //
            // Device AA:BB:CC:DD:EE:FF Device Name

            let mut parts =
                line.splitn(3, ' ');


            if parts.next()
                != Some("Device")
            {
                continue;
            }


            let Some(address) =
                parts.next()
            else {
                continue;
            };


            if address.is_empty() {
                continue;
            }


            /*
            * Avoid duplicate entries in case BlueZ produces
            * duplicate device lines.
            */
            if !seen_addresses.insert(
                address.to_string()
            ) {
                continue;
            }


            let fallback_name =
                parts.next()
                    .unwrap_or("Unknown")
                    .trim()
                    .to_string();


            // ----------------------------------------------------
            // DEVICE DETAILS
            // ----------------------------------------------------

            let info =
                run(
                    "bluetoothctl",
                    [
                        "info",
                        address,
                    ],
                )
                .unwrap_or_default();


            // ----------------------------------------------------
            // NAME
            //
            // Prefer Name: from bluetoothctl info because the
            // device listing can sometimes contain aliases.
            // ----------------------------------------------------

            let name =
                info.lines()
                    .find_map(
                        |line| {
                            line.trim()
                                .strip_prefix(
                                    "Name: "
                                )
                        },
                    )
                    .map(
                        |value|
                            value.trim()
                                .to_string(),
                    )
                    .filter(
                        |value|
                            !value.is_empty(),
                    )
                    .unwrap_or(
                        fallback_name
                    );


            // ----------------------------------------------------
            // DEVICE ICON / TYPE
            // ----------------------------------------------------

            let device_type =
                info.lines()
                    .find_map(
                        |line| {
                            line.trim()
                                .strip_prefix(
                                    "Icon: "
                                )
                        },
                    )
                    .unwrap_or(
                        "device"
                    )
                    .trim()
                    .to_string();


            // ----------------------------------------------------
            // PAIRED
            // ----------------------------------------------------

            let paired =
                info.lines().any(
                    |line| {
                        line.trim()
                            == "Paired: yes"
                    },
                );


            // ----------------------------------------------------
            // CONNECTED
            // ----------------------------------------------------

            let connected =
                info.lines().any(
                    |line| {
                        line.trim()
                            == "Connected: yes"
                    },
                );


            // ----------------------------------------------------
            // TRUSTED
            // ----------------------------------------------------

            let trusted =
                info.lines().any(
                    |line| {
                        line.trim()
                            == "Trusted: yes"
                    },
                );


            devices.push(
                BluetoothDevice {
                    address:
                        address.to_string(),

                    name,

                    device_type,

                    paired,

                    connected,

                    trusted,
                },
            );
        }


        // --------------------------------------------------------
        // SORT
        //
        // Connected first
        // Paired second
        // Newly discovered / available last
        // --------------------------------------------------------

        devices.sort_by(
            |a, b| {

                let rank_a =
                    bluetooth_device_rank(a);

                let rank_b =
                    bluetooth_device_rank(b);


                rank_a
                    .cmp(&rank_b)
                    .then_with(
                        || {
                            a.name
                                .to_lowercase()
                                .cmp(
                                    &b.name
                                        .to_lowercase()
                                )
                        },
                    )
            },
        );


        Ok(
            BluetoothInfo {
                enabled,
                devices,
            },
        )
    }


    // ========================================================
    // BLUETOOTH ACTIONS
    // ========================================================

    pub fn bluetooth_set_enabled(
        &self,
        enabled: bool,
    ) -> Result<(), String> {
        if enabled {
            let _ = Command::new("rfkill").args(["unblock", "bluetooth"]).status();
            let _ = run(
                "bluetoothctl",
                [
                    "power",
                    "on",
                ],
            );
        } else {
            let _ = Command::new("rfkill").args(["block", "bluetooth"]).status();
            let _ = run(
                "bluetoothctl",
                [
                    "power",
                    "off",
                ],
            );
        }

        let _ = crate::state::update_state(|s| {
            s.bluetooth_enabled = enabled;
        });

        Ok(())
    }


    pub fn bluetooth_scan(
        &self,
        enabled: bool,
    ) -> Result<(), String> {

        run(
            "bluetoothctl",
            [
                "scan",
                if enabled { "on" } else { "off" },
            ],
        )?;

        Ok(())
    }


    pub fn bluetooth_pair(
        &self,
        address: &str,
    ) -> Result<(), String> {

        run(
            "bluetoothctl",
            [
                "pair",
                address,
            ],
        )?;


        /*
        * Make the saved device trusted so BlueZ can reconnect
        * normally later.
        */
        run(
            "bluetoothctl",
            [
                "trust",
                address,
            ],
        )?;


        /*
        * Pairing may establish a generic connection, but explicitly
        * request the A2DP playback profile as well.
        */
        match run(
            "bluetoothctl",
            [
                "connect",
                address,
                "a2dp-sink",
            ],
        ) {
            Ok(_) => {}

            Err(error) => {

                let lower =
                    error.to_lowercase();

                if !lower.contains("already") {
                    return Err(
                        format!(
                            "Paired, but A2DP audio failed: {error}"
                        )
                    );
                }
            }
        }


        Ok(())
    }


    pub fn bluetooth_connect(
        &self,
        address: &str,
    ) -> Result<(), String> {

        // --------------------------------------------------------
        // 1. Establish the normal Bluetooth connection.
        //
        // BlueZ Connect() may report success when only one usable
        // profile connects, so this alone is not enough for audio.
        // --------------------------------------------------------

        match run(
            "bluetoothctl",
            [
                "connect",
                address,
            ],
        ) {
            Ok(_) => {}

            Err(error) => {

                /*
                * If the low-level device is already connected,
                * continue and explicitly request A2DP below.
                */
                let lower =
                    error.to_lowercase();

                if !lower.contains("already") {
                    return Err(error);
                }
            }
        }


        // --------------------------------------------------------
        // 2. Explicitly connect the A2DP playback profile.
        //
        // THIS is the important fix.
        // --------------------------------------------------------

        match run(
            "bluetoothctl",
            [
                "connect",
                address,
                "a2dp-sink",
            ],
        ) {
            Ok(_) => {}

            Err(error) => {

                let lower =
                    error.to_lowercase();

                /*
                * Already connected is fine.
                *
                * Any real A2DP failure should be surfaced instead
                * of pretending Bluetooth is audio-ready.
                */
                if !lower.contains("already") {
                    return Err(
                        format!(
                            "Bluetooth connected, but A2DP audio failed: {error}"
                        )
                    );
                }
            }
        }


        // --------------------------------------------------------
        // 3. Wait for WirePlumber/PipeWire to create bluez_output.
        //
        // Bluetooth profile negotiation is asynchronous, so the
        // PipeWire sink may appear shortly after bluetoothctl exits.
        // --------------------------------------------------------

        let sink =
            wait_for_bluetooth_sink(
                address,
                Duration::from_secs(6),
            )
            .ok_or_else(
                || {
                    format!(
                        "Bluetooth connected but no PipeWire A2DP sink appeared for {address}"
                    )
                },
            )?;


        // --------------------------------------------------------
        // 4. Make the Bluetooth headset the default output.
        // --------------------------------------------------------

        run(
            "wpctl",
            [
                "set-default",
                &sink.id,
            ],
        )
        .map_err(
            |error| {
                format!(
                    "Bluetooth audio connected, but failed to set default sink: {error}"
                )
            },
        )?;


        // --------------------------------------------------------
        // 5. Move currently playing Pulse/PipeWire streams.
        //
        // wpctl set-default primarily determines the target for new
        // automatically connected streams, so move existing streams
        // too. Failure here is non-fatal.
        // --------------------------------------------------------

        move_existing_audio_streams(
            &sink.name
        );


        Ok(())
    }


    pub fn bluetooth_disconnect(
        &self,
        address: &str,
    ) -> Result<(), String> {

        run(
            "bluetoothctl",
            ["disconnect", address],
        )?;

        Ok(())
    }


    pub fn bluetooth_forget(
        &self,
        address: &str,
    ) -> Result<(), String> {

        run(
            "bluetoothctl",
            ["remove", address],
        )?;

        Ok(())
    }


    // ========================================================
    // TRAFFIC RATE
    // ========================================================

    fn traffic_rate(
        &self,
        interface: &str,
    ) -> (u64, u64) {

        let rx =
            read_counter(
                interface,
                "rx_bytes",
            );

        let tx =
            read_counter(
                interface,
                "tx_bytes",
            );

        let now = Instant::now();

        let mut previous =
            self.traffic.lock().unwrap();


        let result =
            if let Some(old) = previous.as_ref() {

                if old.interface == interface {

                    let seconds =
                        now.duration_since(old.at)
                            .as_secs_f64();

                    if seconds > 0.0 {
                        (
                            (
                                rx.saturating_sub(old.rx)
                                as f64
                                / seconds
                            ) as u64,

                            (
                                tx.saturating_sub(old.tx)
                                as f64
                                / seconds
                            ) as u64,
                        )
                    } else {
                        (0, 0)
                    }

                } else {
                    (0, 0)
                }

            } else {
                (0, 0)
            };


        *previous =
            Some(
                TrafficSample {
                    interface:
                        interface.to_string(),

                    rx,
                    tx,
                    at: now,
                }
            );


        result
    }
}


// ============================================================
// NETWORKMANAGER HELPERS
// ============================================================

fn wifi_interface() -> Option<String> {

    let output = run(
        "nmcli",
        [
            "-t",
            "--escape",
            "no",
            "-f",
            "DEVICE,TYPE",
            "device",
            "status",
        ],
    )
    .ok()?;


    output.lines().find_map(|line| {

        let mut parts = line.split(':');
        let device = parts.next()?;
        let kind = parts.next()?;


        if kind == "wifi" {
            Some(device.to_string())
        } else {
            None
        }
    })
}


fn wifi_ipv4(
    interface: &str,
) -> String {

    let output =
        run(
            "nmcli",
            [
                "-g",
                "IP4.ADDRESS",
                "device",
                "show",
                interface,
            ],
        )
        .unwrap_or_default();


    output
        .lines()
        .next()
        .unwrap_or("")
        .split('/')
        .next()
        .unwrap_or("")
        .to_string()
}


fn saved_wifi_ssids() -> HashSet<String> {

    let output =
        run(
            "nmcli",
            [
                "-t",
                "--escape",
                "no",
                "-f",
                "UUID,TYPE",
                "connection",
                "show",
            ],
        )
        .unwrap_or_default();


    let mut saved =
        HashSet::new();


    for line in output.lines() {

        let mut parts =
            line.split(':');

        let Some(uuid) = parts.next() else {
            continue;
        };

        let Some(kind) = parts.next() else {
            continue;
        };


        if kind != "802-11-wireless"
            && kind != "wifi"
        {
            continue;
        }


        let ssid =
            run(
                "nmcli",
                [
                    "-g",
                    "802-11-wireless.ssid",
                    "connection",
                    "show",
                    "uuid",
                    uuid,
                ],
            )
            .unwrap_or_default();


        if !ssid.is_empty() {
            saved.insert(ssid);
        }
    }


    saved
}


fn wifi_profile_uuid(
    ssid: &str,
) -> Option<String> {

    let output =
        run(
            "nmcli",
            [
                "-t",
                "--escape",
                "no",
                "-f",
                "UUID,TYPE",
                "connection",
                "show",
            ],
        )
        .ok()?;


    for line in output.lines() {

        let mut parts =
            line.split(':');

        let uuid = parts.next()?;
        let kind = parts.next()?;


        if kind != "802-11-wireless"
            && kind != "wifi"
        {
            continue;
        }


        let profile_ssid =
            run(
                "nmcli",
                [
                    "-g",
                    "802-11-wireless.ssid",
                    "connection",
                    "show",
                    "uuid",
                    uuid,
                ],
            )
            .unwrap_or_default();


        if profile_ssid == ssid {
            return Some(uuid.to_string());
        }
    }


    None
}

fn bluetooth_device_rank(
    device: &BluetoothDevice,
) -> u8 {

    if device.connected {
        return 0;
    }

    if device.paired {
        return 1;
    }

    2
}

struct BluetoothAudioSink {
    id: String,
    name: String,
}


fn wait_for_bluetooth_sink(
    address: &str,
    timeout: Duration,
) -> Option<BluetoothAudioSink> {

    let started =
        Instant::now();


    while started.elapsed() < timeout {

        if let Some(sink) =
            bluetooth_sink(address)
        {
            return Some(sink);
        }


        thread::sleep(
            Duration::from_millis(250)
        );
    }


    None
}


fn bluetooth_sink(
    address: &str,
) -> Option<BluetoothAudioSink> {

    /*
     * PipeWire Bluetooth node names use underscores instead
     * of ':' in the MAC:
     *
     * 3C:B0:ED:39:99:C1
     *
     * becomes:
     *
     * bluez_output.3C_B0_ED_39_99_C1...
     */

    let mac =
        address.replace(':', "_");


    let needle =
        format!(
            "bluez_output.{mac}"
        );


    let output =
        run(
            "wpctl",
            [
                "status",
                "-n",
            ],
        )
        .ok()?;


    for line in output.lines() {

        if !line.contains(&needle) {
            continue;
        }


        let trimmed =
            line.trim();


        /*
         * Possible forms:
         *
         * 67. bluez_output....
         *
         * * 67. bluez_output....
         */

        let cleaned =
            trimmed
                .trim_start_matches('*')
                .trim();


        let mut parts =
            cleaned.split_whitespace();


        let id =
            parts.next()?
                .trim_end_matches('.')
                .to_string();


        let name =
            parts.next()?
                .to_string();


        if id.is_empty()
            || name.is_empty()
        {
            continue;
        }


        return Some(
            BluetoothAudioSink {
                id,
                name,
            }
        );
    }


    None
}


fn move_existing_audio_streams(
    sink_name: &str,
) {

    let output =
        match run(
            "pactl",
            [
                "list",
                "short",
                "sink-inputs",
            ],
        ) {
            Ok(output) => output,
            Err(_) => return,
        };


    for line in output.lines() {

        let Some(id) =
            line.split_whitespace()
                .next()
        else {
            continue;
        };


        let _ =
            run(
                "pactl",
                [
                    "move-sink-input",
                    id,
                    sink_name,
                ],
            );
    }
}

// ============================================================
// BAND
// ============================================================

fn band_from_frequency(
    frequency: u32,
) -> String {

    match frequency {
        5925.. => "6 GHz",
        4900..=5924 => "5 GHz",
        2300..=2499 => "2.4 GHz",
        _ => "Unknown",
    }
    .to_string()
}


// ============================================================
// KERNEL TRAFFIC COUNTERS
// ============================================================

fn read_counter(
    interface: &str,
    counter: &str,
) -> u64 {

    fs::read_to_string(
        format!(
            "/sys/class/net/{interface}/statistics/{counter}"
        )
    )
    .ok()
    .and_then(
        |value|
            value.trim().parse().ok()
    )
    .unwrap_or(0)
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
