use serde::Serialize;
use std::{
    collections::{HashMap, HashSet},
    ffi::OsStr,
    fs,
    process::Command,
    sync::Mutex,
    thread,
    time::{Duration, Instant},
};
use zbus::blocking::Connection;
use zbus::zvariant::{OwnedObjectPath, OwnedValue, Value};

type ManagedObjects = HashMap<OwnedObjectPath, HashMap<String, HashMap<String, OwnedValue>>>;

fn val_to_str<'a>(val: &'a OwnedValue) -> Option<&'a str> {
    match &**val {
        Value::Str(s) => Some(s.as_str()),
        _ => None,
    }
}

fn val_to_string(val: &OwnedValue) -> Option<String> {
    val_to_str(val).map(|s| s.to_string())
}

fn val_to_path(val: &OwnedValue) -> Option<OwnedObjectPath> {
    match &**val {
        Value::ObjectPath(p) => OwnedObjectPath::try_from(p.as_str()).ok(),
        Value::Str(s) => OwnedObjectPath::try_from(s.as_str()).ok(),
        _ => None,
    }
}

fn val_to_bool(val: &OwnedValue) -> Option<bool> {
    match &**val {
        Value::Bool(b) => Some(*b),
        _ => None,
    }
}

fn val_to_u32(val: &OwnedValue) -> Option<u32> {
    match &**val {
        Value::U32(v) => Some(*v),
        Value::U16(v) => Some(*v as u32),
        Value::U8(v) => Some(*v as u32),
        Value::I32(v) => Some(*v as u32),
        _ => None,
    }
}

fn val_to_u8(val: &OwnedValue) -> Option<u8> {
    match &**val {
        Value::U8(v) => Some(*v),
        Value::U32(v) => Some(*v as u8),
        _ => None,
    }
}

fn val_to_ssid(val: &OwnedValue) -> Option<String> {
    match &**val {
        Value::Array(arr) => {
            let bytes: Vec<u8> = arr
                .iter()
                .filter_map(|v| match v {
                    Value::U8(b) => Some(*b),
                    _ => None,
                })
                .collect();
            if bytes.is_empty() {
                None
            } else {
                Some(String::from_utf8_lossy(&bytes).trim().to_string())
            }
        }
        Value::Str(s) => {
            let trimmed = s.as_str().trim();
            if trimmed.is_empty() {
                None
            } else {
                Some(trimmed.to_string())
            }
        }
        _ => None,
    }
}

fn val_to_ipv4(val: &OwnedValue) -> Option<String> {
    match &**val {
        Value::Array(arr) => {
            for item in arr.iter() {
                if let Value::Dict(dict) = item {
                    for (k, v) in dict.iter() {
                        if let Value::Str(key) = k {
                            if key.as_str() == "address" {
                                let unwrapped = match v {
                                    Value::Value(inner) => inner.as_ref(),
                                    other => other,
                                };
                                if let Value::Str(addr) = unwrapped {
                                    return Some(addr.as_str().to_string());
                                }
                            }
                        }
                    }
                }
            }
            None
        }
        _ => None,
    }
}

// ============================================================
// PUBLIC DATA
// ============================================================

#[derive(Debug, Clone, Serialize)]
pub struct WifiInfo {
    pub enabled: bool,
    pub connected: bool,
    pub has_internet: bool,

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
    pub battery_percentage: Option<u8>,
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
        if let Ok(info) = self.wifi_info_dbus() {
            return Ok(info);
        }
        self.wifi_info_legacy()
    }

    fn wifi_info_dbus(&self) -> Result<WifiInfo, String> {
        let conn = Connection::system()
            .map_err(|e| format!("Failed to connect to system bus: {e}"))?;

        let managed = get_nm_managed_objects(&conn)?;

        let mut enabled = true;
        let mut has_internet = false;
        let root_path = OwnedObjectPath::try_from("/org/freedesktop/NetworkManager").unwrap();
        if let Some(nm_root) = managed.get(&root_path) {
            if let Some(nm_iface) = nm_root.get("org.freedesktop.NetworkManager") {
                if let Some(val) = nm_iface.get("WirelessEnabled") {
                    if let Some(b) = val_to_bool(val) {
                        enabled = b;
                    }
                }
                if let Some(val) = nm_iface.get("Connectivity") {
                    if let Some(c) = val_to_u32(val) {
                        has_internet = c == 4; // NM_CONNECTIVITY_FULL
                    }
                }
            }
        }

        // Find wireless device (DeviceType == 2)
        let mut interface = String::new();
        let mut active_ap_path: Option<OwnedObjectPath> = None;
        let mut ip4_config_path: Option<OwnedObjectPath> = None;

        for (_path, ifaces) in &managed {
            if let Some(dev) = ifaces.get("org.freedesktop.NetworkManager.Device") {
                let dev_type = dev.get("DeviceType").and_then(val_to_u32).unwrap_or(0);
                if dev_type == 2 {
                    if let Some(iface_val) = dev.get("Interface") {
                        if let Some(s) = val_to_string(iface_val) {
                            interface = s;
                        }
                    }
                    if let Some(ip4_val) = dev.get("Ip4Config") {
                        if let Some(p) = val_to_path(ip4_val) {
                            if p.as_str() != "/" {
                                ip4_config_path = Some(p);
                            }
                        }
                    }
                    if let Some(wireless) = ifaces.get("org.freedesktop.NetworkManager.Device.Wireless") {
                        if let Some(ap_val) = wireless.get("ActiveAccessPoint") {
                            if let Some(p) = val_to_path(ap_val) {
                                if p.as_str() != "/" {
                                    active_ap_path = Some(p);
                                }
                            }
                        }
                    }
                    break;
                }
            }
        }

        let mut connected = false;
        let mut ssid = String::new();
        let mut signal = 0u8;
        let mut security = String::new();
        let mut frequency_mhz = 0u32;
        let mut band = String::new();

        if let Some(ap_p) = active_ap_path {
            if let Some(ap_ifaces) = managed.get(&ap_p) {
                if let Some(ap) = ap_ifaces.get("org.freedesktop.NetworkManager.AccessPoint") {
                    connected = true;
                    ssid = ap.get("Ssid").and_then(val_to_ssid).unwrap_or_default();
                    signal = ap.get("Strength").and_then(val_to_u8).unwrap_or(0);
                    if let Some(f) = ap.get("Frequency").and_then(val_to_u32) {
                        frequency_mhz = f;
                        band = band_from_frequency(f);
                    }
                    let rsn = ap.get("RsnFlags").and_then(val_to_u32).unwrap_or(0);
                    let wpa = ap.get("WpaFlags").and_then(val_to_u32).unwrap_or(0);
                    let flags = ap.get("Flags").and_then(val_to_u32).unwrap_or(0);
                    security = security_from_flags(rsn, wpa, flags);
                }
            }
        }

        // IPv4 from IP4Config
        let mut ipv4 = String::new();
        if let Some(ip_p) = ip4_config_path {
            if let Some(ip_ifaces) = managed.get(&ip_p) {
                if let Some(ip4) = ip_ifaces.get("org.freedesktop.NetworkManager.IP4Config") {
                    if let Some(addr_data_val) = ip4.get("AddressData") {
                        if let Some(addr) = val_to_ipv4(addr_data_val) {
                            ipv4 = addr;
                        }
                    }
                }
            }
        }

        let (download_bps, upload_bps) = if interface.is_empty() {
            (0, 0)
        } else {
            self.traffic_rate(&interface)
        };

        Ok(WifiInfo {
            enabled,
            connected,
            has_internet: connected && has_internet,
            interface,
            ssid,
            signal,
            security,
            frequency_mhz,
            band,
            ipv4,
            download_bps,
            upload_bps,
        })
    }

    fn wifi_info_legacy(&self) -> Result<WifiInfo, String> {
        let enabled = run("nmcli", ["radio", "wifi"])? == "enabled";

        let interface = wifi_interface().unwrap_or_default();

        let networks = self.wifi_scan(false)?;

        let current = networks.iter().find(|n| n.connected);

        let ipv4 = if interface.is_empty() {
            String::new()
        } else {
            wifi_ipv4(&interface)
        };

        let (download_bps, upload_bps) = if interface.is_empty() {
            (0, 0)
        } else {
            self.traffic_rate(&interface)
        };

        let has_internet = current.is_some()
            && run("nmcli", ["networking", "connectivity"])
                .map(|s| s.trim() == "full")
                .unwrap_or(false);

        Ok(WifiInfo {
            enabled,

            connected: current.is_some(),
            has_internet,

            interface,

            ssid: current.map(|n| n.ssid.clone()).unwrap_or_default(),

            signal: current.map(|n| n.signal).unwrap_or(0),

            security: current.map(|n| n.security.clone()).unwrap_or_default(),

            frequency_mhz: current.map(|n| n.frequency_mhz).unwrap_or(0),

            band: current.map(|n| n.band.clone()).unwrap_or_default(),

            ipv4,

            download_bps,
            upload_bps,
        })
    }

    // ========================================================
    // WIFI SCAN
    // ========================================================

    pub fn wifi_scan(&self, force: bool) -> Result<Vec<WifiNetwork>, String> {
        if let Ok(networks) = self.wifi_scan_dbus(force) {
            return Ok(networks);
        }
        self.wifi_scan_legacy(force)
    }

    fn wifi_scan_dbus(&self, force: bool) -> Result<Vec<WifiNetwork>, String> {
        let conn = Connection::system()
            .map_err(|e| format!("Failed to connect to system bus: {e}"))?;

        let managed = get_nm_managed_objects(&conn)?;

        // Find wireless device path and active AP path
        let mut wifi_dev_path: Option<OwnedObjectPath> = None;
        let mut active_ap_path: Option<OwnedObjectPath> = None;

        for (path, ifaces) in &managed {
            if let Some(dev) = ifaces.get("org.freedesktop.NetworkManager.Device") {
                let dev_type = dev.get("DeviceType").and_then(val_to_u32).unwrap_or(0);
                if dev_type == 2 {
                    wifi_dev_path = Some(path.clone());
                    if let Some(wireless) = ifaces.get("org.freedesktop.NetworkManager.Device.Wireless") {
                        if let Some(ap_val) = wireless.get("ActiveAccessPoint") {
                            if let Some(p) = val_to_path(ap_val) {
                                if p.as_str() != "/" {
                                    active_ap_path = Some(p);
                                }
                            }
                        }
                    }
                    break;
                }
            }
        }

        if force {
            if let Some(ref dev_p) = wifi_dev_path {
                let empty_options: HashMap<&str, OwnedValue> = HashMap::new();
                let _ = conn.call_method(
                    Some("org.freedesktop.NetworkManager"),
                    dev_p,
                    Some("org.freedesktop.NetworkManager.Device.Wireless"),
                    "RequestScan",
                    &(empty_options),
                );
            }
        }

        let saved = saved_wifi_ssids_dbus(&conn, &managed);

        let mut networks = Vec::new();

        for (path, ifaces) in &managed {
            if let Some(ap) = ifaces.get("org.freedesktop.NetworkManager.AccessPoint") {
                let ssid = ap.get("Ssid").and_then(val_to_ssid).unwrap_or_default();

                if ssid.is_empty() {
                    continue;
                }

                let signal = ap.get("Strength").and_then(val_to_u8).unwrap_or(0);
                let frequency = ap.get("Frequency").and_then(val_to_u32).unwrap_or(0);

                let rsn = ap.get("RsnFlags").and_then(val_to_u32).unwrap_or(0);
                let wpa = ap.get("WpaFlags").and_then(val_to_u32).unwrap_or(0);
                let flags = ap.get("Flags").and_then(val_to_u32).unwrap_or(0);

                let security = security_from_flags(rsn, wpa, flags);
                let band = band_from_frequency(frequency);
                let known = saved.contains(&ssid);
                let connected = active_ap_path.as_ref().map(|p| p == path).unwrap_or(false);

                let network = WifiNetwork {
                    ssid: ssid.clone(),
                    signal,
                    security,
                    frequency_mhz: frequency,
                    band,
                    known,
                    connected,
                };

                if let Some(existing) = networks.iter_mut().find(|n: &&mut WifiNetwork| n.ssid == network.ssid) {
                    if network.connected || (!existing.connected && network.signal > existing.signal) {
                        *existing = network;
                    }
                } else {
                    networks.push(network);
                }
            }
        }

        networks.sort_by(|a, b| {
            if a.connected != b.connected {
                return b.connected.cmp(&a.connected);
            }
            b.signal.cmp(&a.signal)
        });

        Ok(networks)
    }

    fn wifi_scan_legacy(&self, force: bool) -> Result<Vec<WifiNetwork>, String> {
        let rescan = if force { "yes" } else { "no" };

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

            let signal = parts[2].parse::<u8>().unwrap_or(0);

            let frequency = parts[4].parse::<u32>().unwrap_or(0);

            let network = WifiNetwork {
                ssid: ssid.to_string(),

                signal,

                security: parts[3].trim().to_string(),

                frequency_mhz: frequency,

                band: band_from_frequency(frequency),

                known: saved.contains(ssid),

                connected: parts[0].trim() == "*",
            };

            // Same SSID may appear from multiple APs.
            // Keep only strongest one.
            if let Some(existing) = networks
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

        networks.sort_by(|a, b| b.signal.cmp(&a.signal));

        Ok(networks)
    }

    // ========================================================
    // WIFI ACTIONS
    // ========================================================

    pub fn wifi_set_enabled(&self, enabled: bool) -> Result<(), String> {
        let set_dbus = || -> Result<(), String> {
            let conn = Connection::system()
                .map_err(|e| format!("Failed to connect to system bus: {e}"))?;
            let prop_val = zbus::zvariant::Value::from(enabled);
            conn.call_method(
                Some("org.freedesktop.NetworkManager"),
                "/org/freedesktop/NetworkManager",
                Some("org.freedesktop.DBus.Properties"),
                "Set",
                &("org.freedesktop.NetworkManager", "WirelessEnabled", prop_val),
            )
            .map_err(|e| format!("Failed to set WirelessEnabled: {e}"))?;
            Ok(())
        };

        if let Err(_) = set_dbus() {
            run(
                "nmcli",
                ["radio", "wifi", if enabled { "on" } else { "off" }],
            )?;
        }

        let _ = crate::state::update_state(|s| {
            s.wifi_enabled = enabled;
            if enabled {
                s.airplane_enabled = false;
            }
        });

        Ok(())
    }

    pub fn wifi_connect(&self, ssid: &str, password: Option<&str>) -> Result<(), String> {
        let mut args = vec!["device", "wifi", "connect", ssid];

        if let Some(password) = password {
            if !password.is_empty() {
                args.push("password");
                args.push(password);
            }
        }

        run("nmcli", args)?;

        Ok(())
    }

    pub fn wifi_disconnect(&self) -> Result<(), String> {
        let interface = wifi_interface().ok_or("No Wi-Fi interface found")?;

        run("nmcli", ["device", "disconnect", &interface])?;

        Ok(())
    }

    pub fn wifi_forget(&self, ssid: &str) -> Result<(), String> {
        let uuid = wifi_profile_uuid(ssid).ok_or("Saved Wi-Fi profile not found")?;

        run("nmcli", ["connection", "delete", "uuid", &uuid])?;

        Ok(())
    }

    pub fn wifi_refresh(&self) -> Result<Vec<WifiNetwork>, String> {
        self.wifi_scan(true)
    }

    // ========================================================
    // BLUETOOTH STATUS
    // ========================================================

    pub fn bluetooth_info(&self) -> Result<BluetoothInfo, String> {
        if let Ok(info) = get_bluetooth_info_dbus() {
            return Ok(info);
        }
        self.bluetooth_info_legacy()
    }

    fn bluetooth_info_legacy(&self) -> Result<BluetoothInfo, String> {
        // --------------------------------------------------------
        // ADAPTER POWER STATE
        // --------------------------------------------------------

        let show = run("bluetoothctl", ["show"])?;

        let enabled = show.lines().any(|line| line.trim() == "Powered: yes");

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

        let output = run("bluetoothctl", ["devices"]).unwrap_or_default();

        let mut devices = Vec::new();

        let mut seen_addresses = HashSet::new();

        for line in output.lines() {
            // Expected format:
            //
            // Device AA:BB:CC:DD:EE:FF Device Name

            let mut parts = line.splitn(3, ' ');

            if parts.next() != Some("Device") {
                continue;
            }

            let Some(address) = parts.next() else {
                continue;
            };

            if address.is_empty() {
                continue;
            }

            /*
             * Avoid duplicate entries in case BlueZ produces
             * duplicate device lines.
             */
            if !seen_addresses.insert(address.to_string()) {
                continue;
            }

            let fallback_name = parts.next().unwrap_or("Unknown").trim().to_string();

            // ----------------------------------------------------
            // DEVICE DETAILS
            // ----------------------------------------------------

            let info = run("bluetoothctl", ["info", address]).unwrap_or_default();

            // ----------------------------------------------------
            // NAME
            //
            // Prefer Name: from bluetoothctl info because the
            // device listing can sometimes contain aliases.
            // ----------------------------------------------------

            let name = info
                .lines()
                .find_map(|line| line.trim().strip_prefix("Name: "))
                .map(|value| value.trim().to_string())
                .filter(|value| !value.is_empty())
                .unwrap_or(fallback_name);

            // ----------------------------------------------------
            // DEVICE ICON / TYPE
            // ----------------------------------------------------

            let device_type = info
                .lines()
                .find_map(|line| line.trim().strip_prefix("Icon: "))
                .unwrap_or("device")
                .trim()
                .to_string();

            // ----------------------------------------------------
            // PAIRED
            // ----------------------------------------------------

            let paired = info.lines().any(|line| line.trim() == "Paired: yes");

            // ----------------------------------------------------
            // CONNECTED
            // ----------------------------------------------------

            let connected = info.lines().any(|line| line.trim() == "Connected: yes");

            // ----------------------------------------------------
            // TRUSTED
            // ----------------------------------------------------

            let trusted = info.lines().any(|line| line.trim() == "Trusted: yes");

            let battery_percentage = info.lines().find_map(|line| {
                let l = line.trim();
                if l.starts_with("Battery Percentage:") {
                    l.split('(').nth(1)?.strip_suffix(')')?.parse::<u8>().ok()
                } else {
                    None
                }
            });

            devices.push(BluetoothDevice {
                address: address.to_string(),

                name,

                device_type,

                paired,

                connected,

                trusted,
                battery_percentage,
            });
        }

        // --------------------------------------------------------
        // SORT
        //
        // Connected first
        // Paired second
        // Newly discovered / available last
        // --------------------------------------------------------

        devices.sort_by(|a, b| {
            let rank_a = bluetooth_device_rank(a);

            let rank_b = bluetooth_device_rank(b);

            rank_a
                .cmp(&rank_b)
                .then_with(|| a.name.to_lowercase().cmp(&b.name.to_lowercase()))
        });

        Ok(BluetoothInfo { enabled, devices })
    }

    // ========================================================
    // BLUETOOTH ACTIONS
    // ========================================================

    pub fn bluetooth_set_enabled(&self, enabled: bool) -> Result<(), String> {
        if enabled {
            let _ = Command::new("rfkill")
                .args(["unblock", "bluetooth"])
                .status();
            let _ = run("bluetoothctl", ["power", "on"]);
        } else {
            let _ = Command::new("rfkill").args(["block", "bluetooth"]).status();
            let _ = run("bluetoothctl", ["power", "off"]);
        }

        let _ = crate::state::update_state(|s| {
            s.bluetooth_enabled = enabled;
        });

        Ok(())
    }

    pub fn bluetooth_scan(&self, enabled: bool) -> Result<(), String> {
        run("bluetoothctl", ["scan", if enabled { "on" } else { "off" }])?;

        Ok(())
    }

    pub fn bluetooth_pair(&self, address: &str) -> Result<(), String> {
        run("bluetoothctl", ["pair", address])?;

        /*
         * Make the saved device trusted so BlueZ can reconnect
         * normally later.
         */
        run("bluetoothctl", ["trust", address])?;

        /*
         * Pairing may establish a generic connection, but explicitly
         * request the A2DP playback profile as well.
         */
        match run("bluetoothctl", ["connect", address, "a2dp-sink"]) {
            Ok(_) => {}

            Err(error) => {
                let lower = error.to_lowercase();

                if !lower.contains("already") {
                    return Err(format!("Paired, but A2DP audio failed: {error}"));
                }
            }
        }

        Ok(())
    }

    pub fn bluetooth_connect(&self, address: &str) -> Result<(), String> {
        // --------------------------------------------------------
        // 1. Establish the normal Bluetooth connection.
        //
        // BlueZ Connect() may report success when only one usable
        // profile connects, so this alone is not enough for audio.
        // --------------------------------------------------------

        match run("bluetoothctl", ["connect", address]) {
            Ok(_) => {}

            Err(error) => {
                /*
                 * If the low-level device is already connected,
                 * continue and explicitly request A2DP below.
                 */
                let lower = error.to_lowercase();

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

        match run("bluetoothctl", ["connect", address, "a2dp-sink"]) {
            Ok(_) => {}

            Err(error) => {
                let lower = error.to_lowercase();

                /*
                 * Already connected is fine.
                 *
                 * Any real A2DP failure should be surfaced instead
                 * of pretending Bluetooth is audio-ready.
                 */
                if !lower.contains("already") {
                    return Err(format!(
                        "Bluetooth connected, but A2DP audio failed: {error}"
                    ));
                }
            }
        }

        // --------------------------------------------------------
        // 3. Wait for WirePlumber/PipeWire to create bluez_output.
        //
        // Bluetooth profile negotiation is asynchronous, so the
        // PipeWire sink may appear shortly after bluetoothctl exits.
        // --------------------------------------------------------

        let sink = wait_for_bluetooth_sink(address, Duration::from_secs(6)).ok_or_else(|| {
            format!("Bluetooth connected but no PipeWire A2DP sink appeared for {address}")
        })?;

        // --------------------------------------------------------
        // 4. Make the Bluetooth headset the default output.
        // --------------------------------------------------------

        run("wpctl", ["set-default", &sink.id]).map_err(|error| {
            format!("Bluetooth audio connected, but failed to set default sink: {error}")
        })?;

        // --------------------------------------------------------
        // 5. Move currently playing Pulse/PipeWire streams.
        //
        // wpctl set-default primarily determines the target for new
        // automatically connected streams, so move existing streams
        // too. Failure here is non-fatal.
        // --------------------------------------------------------

        move_existing_audio_streams(&sink.name);

        Ok(())
    }

    pub fn bluetooth_disconnect(&self, address: &str) -> Result<(), String> {
        run("bluetoothctl", ["disconnect", address])?;

        Ok(())
    }

    pub fn bluetooth_forget(&self, address: &str) -> Result<(), String> {
        run("bluetoothctl", ["remove", address])?;

        Ok(())
    }

    // ========================================================
    // TRAFFIC RATE
    // ========================================================

    fn traffic_rate(&self, interface: &str) -> (u64, u64) {
        let rx = read_counter(interface, "rx_bytes");

        let tx = read_counter(interface, "tx_bytes");

        let now = Instant::now();

        let mut previous = self.traffic.lock().unwrap();

        let result = if let Some(old) = previous.as_ref() {
            if old.interface == interface {
                let seconds = now.duration_since(old.at).as_secs_f64();

                if seconds > 0.0 {
                    (
                        (rx.saturating_sub(old.rx) as f64 / seconds) as u64,
                        (tx.saturating_sub(old.tx) as f64 / seconds) as u64,
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

        *previous = Some(TrafficSample {
            interface: interface.to_string(),

            rx,
            tx,
            at: now,
        });

        result
    }
}

pub fn run_watch() -> Result<(), String> {
    let service = NetworkService::new();
    let mut prev_wifi_enabled = true;
    let mut prev_wifi_connected = false;
    let mut prev_bt_enabled = false;
    let mut prev_bt_connected_addrs: HashSet<String> = HashSet::new();

    if let Ok(wifi) = service.wifi_info() {
        prev_wifi_enabled = wifi.enabled;
        prev_wifi_connected = wifi.connected;
    }
    if let Ok(bt) = service.bluetooth_info() {
        prev_bt_enabled = bt.enabled;
        prev_bt_connected_addrs = bt
            .devices
            .iter()
            .filter(|d| d.connected)
            .map(|d| d.address.clone())
            .collect();
    }

    loop {
        thread::sleep(Duration::from_millis(1500));
        let wifi = service.wifi_info().ok();
        let bt = service.bluetooth_info().ok();

        // 1. Wi-Fi changes
        if let Some(ref w) = wifi {
            if w.enabled != prev_wifi_enabled {
                if !w.enabled {
                    let _ = crate::desktop::island::trigger_wifi_osd("Wi-Fi", 0, false);
                } else if !w.connected {
                    let _ = crate::desktop::island::trigger_wifi_osd("Wi-Fi", 0, true);
                }
                prev_wifi_enabled = w.enabled;
            }

            if w.connected != prev_wifi_connected {
                if w.connected && !w.ssid.is_empty() {
                    let _ = crate::desktop::island::trigger_wifi_osd(
                        &w.ssid,
                        w.signal as u32,
                        w.has_internet,
                    );
                }
                prev_wifi_connected = w.connected;
            }
        }

        // 2. Bluetooth changes
        if let Some(ref b) = bt {
            for dev in &b.devices {
                if dev.connected && !prev_bt_connected_addrs.contains(&dev.address) {
                    let _ = crate::desktop::island::trigger_bluetooth_osd(&dev.name, &dev.device_type);
                }
            }

            let curr_connected: HashSet<String> = b
                .devices
                .iter()
                .filter(|d| d.connected)
                .map(|d| d.address.clone())
                .collect();

            prev_bt_connected_addrs = curr_connected;
        }

        // Update settings-state.json atomically
        let _ = crate::state::update_state(|s| {
            if let Some(ref w) = wifi {
                s.wifi_enabled = w.enabled;
                s.wifi_connected = w.connected;
                s.wifi_ssid = w.ssid.clone();
                s.wifi_signal = w.signal;
                s.wifi_has_internet = w.has_internet;
            }
            if let Some(ref b) = bt {
                s.bluetooth_enabled = b.enabled;
                let connected_dev = b.devices.iter().find(|d| d.connected);
                s.bluetooth_connected = connected_dev.is_some();
                s.bluetooth_device_name = connected_dev
                    .map(|d| d.name.clone())
                    .unwrap_or_default();
                s.bluetooth_device_type = connected_dev
                    .map(|d| d.device_type.clone())
                    .unwrap_or_default();
                s.bluetooth_device_battery = connected_dev
                    .and_then(|d| d.battery_percentage)
                    .map(|b| b as i32)
                    .unwrap_or(-1);
            }
        });
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

fn wifi_ipv4(interface: &str) -> String {
    let output =
        run("nmcli", ["-g", "IP4.ADDRESS", "device", "show", interface]).unwrap_or_default();

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
    let output = run(
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

    let mut saved = HashSet::new();

    for line in output.lines() {
        let mut parts = line.split(':');

        let Some(uuid) = parts.next() else {
            continue;
        };

        let Some(kind) = parts.next() else {
            continue;
        };

        if kind != "802-11-wireless" && kind != "wifi" {
            continue;
        }

        let ssid = run(
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

fn wifi_profile_uuid(ssid: &str) -> Option<String> {
    let output = run(
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
        let mut parts = line.split(':');

        let uuid = parts.next()?;
        let kind = parts.next()?;

        if kind != "802-11-wireless" && kind != "wifi" {
            continue;
        }

        let profile_ssid = run(
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

fn security_from_flags(rsn_flags: u32, wpa_flags: u32, flags: u32) -> String {
    if rsn_flags != 0 && wpa_flags != 0 {
        "WPA1 WPA2".to_string()
    } else if rsn_flags != 0 {
        "WPA2".to_string()
    } else if wpa_flags != 0 {
        "WPA1".to_string()
    } else if (flags & 0x1) != 0 {
        "WEP".to_string()
    } else {
        "--".to_string()
    }
}

fn get_nm_managed_objects(conn: &Connection) -> Result<ManagedObjects, String> {
    let reply = conn
        .call_method(
            Some("org.freedesktop.NetworkManager"),
            "/org/freedesktop",
            Some("org.freedesktop.DBus.ObjectManager"),
            "GetManagedObjects",
            &(),
        )
        .map_err(|e| format!("NM GetManagedObjects failed: {e}"))?;

    reply
        .body()
        .deserialize()
        .map_err(|e| format!("Failed to parse NM managed objects: {e}"))
}

fn saved_wifi_ssids_dbus(conn: &Connection, managed: &ManagedObjects) -> HashSet<String> {
    let mut saved = HashSet::new();

    for (path, ifaces) in managed {
        if ifaces.contains_key("org.freedesktop.NetworkManager.Settings.Connection") {
            if let Ok(reply) = conn.call_method(
                Some("org.freedesktop.NetworkManager"),
                path,
                Some("org.freedesktop.NetworkManager.Settings.Connection"),
                "GetSettings",
                &(),
            ) {
                type ConnSettings = HashMap<String, HashMap<String, OwnedValue>>;
                if let Ok(settings) = reply.body().deserialize::<ConnSettings>() {
                    if let Some(wireless) = settings.get("802-11-wireless") {
                        if let Some(ssid) = wireless.get("ssid").and_then(val_to_ssid) {
                            if !ssid.is_empty() {
                                saved.insert(ssid);
                            }
                        }
                    }
                }
            }
        }
    }

    if saved.is_empty() {
        return saved_wifi_ssids();
    }

    saved
}

fn get_bluetooth_info_dbus() -> Result<BluetoothInfo, String> {
    let connection = Connection::system()
        .map_err(|e| format!("Failed to connect to system bus: {e}"))?;

    let reply = connection
        .call_method(
            Some("org.bluez"),
            "/",
            Some("org.freedesktop.DBus.ObjectManager"),
            "GetManagedObjects",
            &(),
        )
        .map_err(|e| format!("GetManagedObjects failed: {e}"))?;

    type ManagedObjects = HashMap<OwnedObjectPath, HashMap<String, HashMap<String, OwnedValue>>>;
    let managed: ManagedObjects = reply
        .body()
        .deserialize()
        .map_err(|e| format!("Failed to parse BlueZ objects: {e}"))?;

    let mut enabled = false;
    let mut devices = Vec::new();

    for (_path, interfaces) in managed {
        if let Some(adapter) = interfaces.get("org.bluez.Adapter1") {
            if let Some(powered_val) = adapter.get("Powered") {
                if let Ok(powered) = <bool>::try_from(powered_val) {
                    if powered {
                        enabled = true;
                    }
                }
            }
        }

        if let Some(device) = interfaces.get("org.bluez.Device1") {
            let address = device
                .get("Address")
                .and_then(|v| <&str>::try_from(v).ok())
                .unwrap_or_default()
                .to_string();

            if address.is_empty() {
                continue;
            }

            let name = device
                .get("Name")
                .or_else(|| device.get("Alias"))
                .and_then(|v| <&str>::try_from(v).ok())
                .unwrap_or("Unknown")
                .to_string();

            let device_type = device
                .get("Icon")
                .and_then(|v| <&str>::try_from(v).ok())
                .unwrap_or("device")
                .to_string();

            let paired = device
                .get("Paired")
                .and_then(|v| <bool>::try_from(v).ok())
                .unwrap_or(false);

            let connected = device
                .get("Connected")
                .and_then(|v| <bool>::try_from(v).ok())
                .unwrap_or(false);

            let trusted = device
                .get("Trusted")
                .and_then(|v| <bool>::try_from(v).ok())
                .unwrap_or(false);

            let battery_percentage = interfaces
                .get("org.bluez.Battery1")
                .and_then(|b| b.get("Percentage"))
                .and_then(|v| <u8>::try_from(v).ok());

            devices.push(BluetoothDevice {
                address,
                name,
                device_type,
                paired,
                connected,
                trusted,
                battery_percentage,
            });
        }
    }

    devices.sort_by(|a, b| {
        let rank_a = bluetooth_device_rank(a);
        let rank_b = bluetooth_device_rank(b);
        rank_a
            .cmp(&rank_b)
            .then_with(|| a.name.to_lowercase().cmp(&b.name.to_lowercase()))
    });

    Ok(BluetoothInfo { enabled, devices })
}

fn bluetooth_device_rank(device: &BluetoothDevice) -> u8 {
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

fn wait_for_bluetooth_sink(address: &str, timeout: Duration) -> Option<BluetoothAudioSink> {
    let started = Instant::now();

    while started.elapsed() < timeout {
        if let Some(sink) = bluetooth_sink(address) {
            return Some(sink);
        }

        thread::sleep(Duration::from_millis(250));
    }

    None
}

fn bluetooth_sink(address: &str) -> Option<BluetoothAudioSink> {
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

    let mac = address.replace(':', "_");

    let needle = format!("bluez_output.{mac}");

    let output = run("wpctl", ["status", "-n"]).ok()?;

    for line in output.lines() {
        if !line.contains(&needle) {
            continue;
        }

        let trimmed = line.trim();

        /*
         * Possible forms:
         *
         * 67. bluez_output....
         *
         * * 67. bluez_output....
         */

        let cleaned = trimmed.trim_start_matches('*').trim();

        let mut parts = cleaned.split_whitespace();

        let id = parts.next()?.trim_end_matches('.').to_string();

        let name = parts.next()?.to_string();

        if id.is_empty() || name.is_empty() {
            continue;
        }

        return Some(BluetoothAudioSink { id, name });
    }

    None
}

fn move_existing_audio_streams(sink_name: &str) {
    let output = match run("pactl", ["list", "short", "sink-inputs"]) {
        Ok(output) => output,
        Err(_) => return,
    };

    for line in output.lines() {
        let Some(id) = line.split_whitespace().next() else {
            continue;
        };

        let _ = run("pactl", ["move-sink-input", id, sink_name]);
    }
}

// ============================================================
// BAND
// ============================================================

fn band_from_frequency(frequency: u32) -> String {
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

fn read_counter(interface: &str, counter: &str) -> u64 {
    fs::read_to_string(format!("/sys/class/net/{interface}/statistics/{counter}"))
        .ok()
        .and_then(|value| value.trim().parse().ok())
        .unwrap_or(0)
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
