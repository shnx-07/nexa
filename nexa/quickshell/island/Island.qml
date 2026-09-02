import QtQuick
import Quickshell.Io
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.UPower
import Quickshell.Bluetooth
import Quickshell.Networking

import "../theme" as Nexa


PanelWindow {
    id: root


    readonly property bool notificationActive:
        islandContent.notificationActive
    property bool notificationEventInitialized: false

    // ============================================================
    // RESPONSIBILITY
    //
    // Island.qml owns ONLY:
    //
    // - Wayland window / geometry
    // - Island physical sizes
    // - hover expansion
    // - full expansion
    // - input mask
    // - outside-click close
    // - keyboard focus
    // - Escape close
    //
    // Feature UI DOES NOT belong here.
    // Clock / music / system / theme / notifications etc.
    // belong in IslandContent.qml or reusable modules.
    // ============================================================


    // ============================================================
    // WINDOW / WAYLAND SURFACE
    // ============================================================

    anchors {
        top: true
    }

    // Fixed maximum surface.
    //
    // We DO NOT animate the actual PanelWindow size.
    // Doing that was causing compositor-side lag.
    //
    // The visible Rectangle inside this window is animated instead.
    implicitWidth: 800
    implicitHeight: 660

    margins {
        top: 3

        left: Math.round(
            ((screen ? screen.width : 1920) - implicitWidth) / 2
        )
    }

    color: "transparent"

    exclusionMode: ExclusionMode.Ignore

    aboveWindows: true

    // Keyboard input is only accepted while the full Island is open.
    focusable: root.full || root.specialModeActive


    // ============================================================
    // STATE
    // ============================================================

    property bool hovered: false
    property bool full: false

    // True while the Theme section has a dropdown popup open.
    // Suppresses the outside-click close so the user can browse
    // presets without the Island collapsing.
    readonly property bool themePopupOpen:
        islandContent.themePopupOpen


    // ============================================================
    // SIZE CONSTANTS
    // ============================================================

    readonly property int compactWidth:
        Nexa.Theme.islandCompactWidth

    readonly property int compactHeight:
        Nexa.Theme.islandCompactHeight


    // ============================================================
    // PERSISTENT CONTEXT SIZE
    //
    // Media:
    //     420 x compactHeight
    //     stays visually inside the 36px top bar.
    //
    // Stopwatch:
    //     420 x 44
    //     intentionally uses the taller persistent context.
    //
    // This avoids forcing every contextual module into one height.
    // ============================================================

    readonly property int contextWidth: 420

    readonly property int contextHeight:
        root.compactHeight

    // Confirmed hover dimensions.
    readonly property int hoverWidth: {
        if (islandContent.stopwatchContextActive || islandContent.focusContextActive)
            return 500
        return 420
    }
    readonly property int hoverHeight: 102


    // Confirmed full dimensions.
    readonly property int fullWidth: 720
    readonly property int fullHeight: 400

    // ============================================================
    // APP LAUNCHER DIMENSIONS
    // ============================================================

    readonly property int launcherWidth: 760
    readonly property int launcherHeight: 620

    // ============================================================
    // POWER MODE DIMENSIONS
    //
    // PowerIsland content:
    //   5 × 138px cards = 690
    //   4 × 12px gaps   = 48
    //   content width   = 738
    //
    // 760 gives 11px horizontal padding.
    // 144 gives 12px vertical padding around 120px cards.
    // ============================================================

    readonly property int powerWidth: 760
    readonly property int powerHeight: 144

    // ============================================================
    // CONTROL CENTER DIMENSIONS
    // ============================================================

    readonly property int controlCenterWidth: 760
    readonly property int controlCenterHeight: 460

    // ============================================================
    // OSD DIMENSIONS (UNIQUE SIZES PER NOTIFICATION TYPE)
    // ============================================================

    readonly property int osdVolumeWidth: 320
    readonly property int osdVolumeHeight: 48

    readonly property int osdMuteWidth: 240
    readonly property int osdMuteHeight: 44

    readonly property int osdMicWidth: 240
    readonly property int osdMicHeight: 44

    readonly property int osdBrightnessWidth: 320
    readonly property int osdBrightnessHeight: 48

    readonly property int osdAirplaneWidth: 260
    readonly property int osdAirplaneHeight: 46

    readonly property int osdBatteryWidth: 280
    readonly property int osdBatteryHeight: 46

    readonly property int osdBluetoothWidth: 320
    readonly property int osdBluetoothHeight: 46

    readonly property int osdWifiWidth: 320
    readonly property int osdWifiHeight: 46

    readonly property int osdKeyLockWidth: 240
    readonly property int osdKeyLockHeight: 46

    property string osdType: "none"
    property real osdValue: 0.74
    property bool osdMuted: false
    property bool osdMicMuted: false
    property bool osdAirplaneEnabled: false
    property bool osdActive: false
    property string osdTitle: ""
    property string osdSubtitle: ""
    property string osdIcon: ""
    property bool osdBatteryCharging: false
    property bool osdHasInternet: true
    property bool osdLockEnabled: false

    Timer {
        id: osdDismissTimer
        interval: 2600
        repeat: false
        onTriggered: {
            root.osdActive = false
            root.osdType = "none"
        }
    }

    Timer {
        id: volumeSyncTimer
        interval: 120
        repeat: false
        onTriggered: volumeQueryProcess.running = true
    }

    Timer {
        id: brightnessSyncTimer
        interval: 120
        repeat: false
        onTriggered: brightnessQueryProcess.running = true
    }

    Process {
        id: volumeQueryProcess
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        stdout: StdioCollector {
            onStreamFinished: {
                const text = this.text.trim()
                if (text.startsWith("Volume:")) {
                    const isMuted = text.includes("[MUTED]")
                    const clean = text.replace("Volume:", "").replace("[MUTED]", "").trim()
                    const val = parseFloat(clean)
                    if (!isNaN(val)) {
                        root.osdValue = Math.max(0.0, Math.min(1.0, val))
                        root.osdMuted = isMuted
                    }
                }
            }
        }
    }

    Process {
        id: brightnessQueryProcess
        command: ["brightnessctl", "-m"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = this.text.trim().split(",")
                if (parts.length >= 4 && parts[3].endsWith("%")) {
                    const pct = parseFloat(parts[3].replace("%", ""))
                    if (!isNaN(pct)) {
                        if (root.osdType === "brightness" || !root.osdActive) {
                            root.osdValue = Math.max(0.0, Math.min(1.0, pct / 100.0))
                        }
                    }
                }
            }
        }
    }

    Process {
        id: airplaneToggleProcess
        command: [
            Quickshell.env("HOME") + "/.config/nexa/rust/target/release/nexad",
            "system",
            "airplane",
            "toggle"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(this.text.trim())
                    root.osdAirplaneEnabled = Boolean(data.enabled)
                } catch (e) {}
            }
        }
    }

    Process {
        id: airplaneQueryProcess
        command: [
            Quickshell.env("HOME") + "/.config/nexa/rust/target/release/nexad",
            "system",
            "airplane",
            "info"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(this.text.trim())
                    root.osdAirplaneEnabled = Boolean(data.enabled)
                } catch (e) {}
            }
        }
    }

    function triggerVolumeUp(): void {
        if (root.full || root.specialModeActive) return
        root.osdType = "volume"
        root.osdMuted = false
        root.osdValue = Math.min(1.0, root.osdValue + 0.05)
        root.osdActive = true
        osdDismissTimer.restart()
        Quickshell.execDetached(["wpctl", "set-volume", "-l", "1", "@DEFAULT_AUDIO_SINK@", "5%+"])
        volumeSyncTimer.restart()
    }

    function triggerVolumeDown(): void {
        if (root.full || root.specialModeActive) return
        root.osdType = "volume"
        root.osdValue = Math.max(0.0, root.osdValue - 0.05)
        root.osdActive = true
        osdDismissTimer.restart()
        Quickshell.execDetached(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", "5%-"])
        volumeSyncTimer.restart()
    }

    function triggerToggleMute(): void {
        if (root.full || root.specialModeActive) return
        root.osdType = "mute"
        root.osdMuted = !root.osdMuted
        root.osdActive = true
        osdDismissTimer.restart()
        Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"])
        volumeSyncTimer.restart()
    }

    function triggerBrightnessUp(): void {
        if (root.full || root.specialModeActive) return
        root.osdType = "brightness"
        root.osdValue = Math.min(1.0, root.osdValue + 0.05)
        root.osdActive = true
        osdDismissTimer.restart()
        Quickshell.execDetached(["brightnessctl", "-e4", "-n2", "set", "5%+"])
        brightnessSyncTimer.restart()
    }

    function triggerBrightnessDown(): void {
        if (root.full || root.specialModeActive) return
        root.osdType = "brightness"
        root.osdValue = Math.max(0.01, root.osdValue - 0.05)
        root.osdActive = true
        osdDismissTimer.restart()
        Quickshell.execDetached(["brightnessctl", "-e4", "-n2", "set", "5%-"])
        brightnessSyncTimer.restart()
    }

    Timer {
        id: micSyncTimer
        interval: 120
        repeat: false
        onTriggered: micQueryProcess.running = true
    }

    Process {
        id: micQueryProcess
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SOURCE@"]
        stdout: StdioCollector {
            onStreamFinished: {
                const text = this.text.trim()
                if (text.startsWith("Volume:")) {
                    const isMuted = text.includes("[MUTED]")
                    const clean = text.replace("Volume:", "").replace("[MUTED]", "").trim()
                    const val = parseFloat(clean)
                    if (!isNaN(val)) {
                        if (root.osdType === "mic") {
                            root.osdValue = Math.max(0.0, Math.min(1.0, val))
                        }
                        root.osdMicMuted = isMuted
                    }
                }
            }
        }
    }

    function triggerToggleMicMute(): void {
        if (root.full || root.specialModeActive) return
        root.osdType = "mic"
        root.osdMicMuted = !root.osdMicMuted
        root.osdMuted = root.osdMicMuted
        root.osdActive = true
        osdDismissTimer.restart()
        Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SOURCE@", "toggle"])
        micSyncTimer.restart()
    }

    function triggerToggleAirplane(): void {
        if (root.full || root.specialModeActive) return
        root.osdType = "airplane"
        root.osdAirplaneEnabled = !root.osdAirplaneEnabled
        root.osdActive = true
        osdDismissTimer.restart()
        airplaneToggleProcess.running = true
    }

    // ============================================================
    // BATTERY HARDWARE WATCHER (APPLE MAGSAFE STYLE)
    // ============================================================

    readonly property var batteryDevice: UPower.displayDevice
    readonly property bool batteryReady: batteryDevice && batteryDevice.ready
    readonly property bool onBattery: UPower.onBattery
    property bool batteryInitialized: false
    property bool lowBatteryWarned: false

    function triggerBatteryOsd(charging: bool, pct: int): void {
        if (root.full || root.specialModeActive) return
        root.osdType = "battery"
        root.osdBatteryCharging = charging
        root.osdValue = Math.max(0.0, Math.min(1.0, pct / 100.0))
        root.osdTitle = charging ? "Charging" : "On Battery"
        root.osdSubtitle = pct + "%"
        root.osdActive = true
        osdDismissTimer.interval = 2600
        osdDismissTimer.restart()
    }

    function triggerLowBatteryAlert(pct: int): void {
        if (root.full || root.specialModeActive) return
        root.osdType = "battery_low"
        root.osdBatteryCharging = false
        root.osdValue = Math.max(0.0, Math.min(1.0, pct / 100.0))
        root.osdTitle = "Low Battery"
        root.osdSubtitle = pct + "% Remaining"
        root.osdActive = true
        osdDismissTimer.interval = 5000
        osdDismissTimer.restart()
    }

    function checkBatteryLevel(): void {
        if (!root.batteryInitialized || !root.batteryReady) return
        const pct = Math.round(batteryDevice.percentage * 100)

        if (root.onBattery && pct <= 25) {
            if (!root.lowBatteryWarned) {
                root.lowBatteryWarned = true
                root.triggerLowBatteryAlert(pct)
            }
        } else if (!root.onBattery || pct > 30) {
            root.lowBatteryWarned = false
        }
    }

    function applyPowerState(onBat: bool): void {
        if (onBat) {
            Quickshell.execDetached(["powerprofilesctl", "set", "power-saver"])
            Quickshell.execDetached(["hyprctl", "eval", "hl.config({ decoration = { blur = { enabled = false }, shadow = { enabled = false } } })"])
        } else {
            Quickshell.execDetached(["powerprofilesctl", "set", "balanced"])
            Quickshell.execDetached(["hyprctl", "eval", "hl.config({ decoration = { blur = { enabled = true }, shadow = { enabled = true } } })"])
        }
    }

    Timer {
        id: batteryInitTimer
        interval: 2000
        running: true
        repeat: false
        onTriggered: {
            root.batteryInitialized = true
            root.applyPowerState(root.onBattery)
            root.checkBatteryLevel()
        }
    }

    Connections {
        target: root.batteryReady ? root.batteryDevice : null

        function onPercentageChanged() {
            root.checkBatteryLevel()
        }
    }

    onOnBatteryChanged: {
        if (!root.batteryInitialized || !root.batteryReady) return
        const pct = Math.round(batteryDevice.percentage * 100)
        root.applyPowerState(root.onBattery)

        if (root.onBattery && pct <= 25) {
            if (!root.lowBatteryWarned) {
                root.lowBatteryWarned = true
                root.triggerLowBatteryAlert(pct)
            }
        } else {
            if (!root.onBattery) {
                root.lowBatteryWarned = false
            }
            root.triggerBatteryOsd(!root.onBattery, pct)
        }
    }


    // ============================================================
    // BLUETOOTH DEVICE CONNECTION WATCHER
    // ============================================================

    property var knownConnectedDevices: ({})
    property bool bluetoothWatcherReady: false

    Timer {
        id: bluetoothInitTimer
        interval: 3000
        running: true
        repeat: false
        onTriggered: {
            root.bluetoothWatcherReady = true
            const current = {}
            for (let dev of Bluetooth.devices.values) {
                if (dev.connected) {
                    current[dev.address] = true
                }
            }
            root.knownConnectedDevices = current
        }
    }

    Connections {
        target: Bluetooth.devices
        function onValuesChanged() {
            if (!root.bluetoothWatcherReady) return

            const current = {}
            for (let dev of Bluetooth.devices.values) {
                if (dev.connected) {
                    current[dev.address] = true
                    if (!root.knownConnectedDevices[dev.address]) {
                        root.triggerBluetoothOsd(dev)
                    }
                }
            }
            root.knownConnectedDevices = current
        }
    }

    function triggerBluetoothOsd(device: var): void {
        if (!device || root.full || root.specialModeActive) return
        root.osdType = "bluetooth"
        root.osdTitle = (device.name && device.name.length > 0) ? device.name : "Bluetooth Device"

        let iconName = "󰂯"
        const devIcon = (device.icon || "").toLowerCase()
        if (devIcon.includes("head") || devIcon.includes("audio")) iconName = "󰋋"
        else if (devIcon.includes("mouse")) iconName = "󰍽"
        else if (devIcon.includes("keyboard")) iconName = "󰌌"
        else if (devIcon.includes("phone")) iconName = "󰏲"
        else if (devIcon.includes("gamepad") || devIcon.includes("controller")) iconName = "󰊖"
        root.osdIcon = iconName

        let batt = 0
        if (device.batteryAvailable && device.batteryPercentage > 0) {
            batt = device.batteryPercentage
            root.osdSubtitle = "Battery " + batt + "%"
            root.osdValue = batt / 100.0
        } else {
            root.osdSubtitle = "Connected"
            root.osdValue = 0
        }

        root.osdActive = true
        osdDismissTimer.restart()
    }

    // ============================================================
    // WI-FI CONNECTION WATCHER (WITH SSID & INTERNET CONNECTIVITY CHECK)
    // ============================================================

    readonly property var wifiDevice: {
        for (let d of Networking.devices.values) {
            if (d.type === DeviceType.Wifi) return d
        }
        return null
    }

    readonly property bool wifiConnected:
        wifiDevice !== null && wifiDevice.connected

    property bool wifiWasConnected: false
    property bool wifiWatcherReady: false

    Timer {
        id: wifiInitTimer
        interval: 3500
        running: true
        repeat: false
        onTriggered: {
            root.wifiWatcherReady = true
            root.wifiWasConnected = root.wifiConnected
        }
    }

    Timer {
        id: wifiQueryDelayTimer
        interval: 650
        repeat: false
        onTriggered: {
            wifiStatusQueryProcess.running = true
        }
    }

    Process {
        id: wifiStatusQueryProcess
        command: ["bash", "-c", "nmcli -t -f ACTIVE,SSID,SIGNAL dev wifi | grep '^yes:'; nmcli -t -f CONNECTIVITY g"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.trim().split("\n")
                let ssid = ""
                let strength = 0
                let connectivity = "full"

                for (let line of lines) {
                    const l = line.trim()
                    if (l.startsWith("yes:")) {
                        const parts = l.split(":")
                        if (parts.length >= 2) ssid = parts[1]
                        if (parts.length >= 3) strength = parseInt(parts[2]) || 0
                    } else if (l === "full" || l === "limited" || l === "none" || l === "portal") {
                        connectivity = l
                    }
                }

                // If nmcli line is empty, fallback to device network name
                if (ssid.length === 0 && wifiDevice) {
                    for (let n of wifiDevice.networks.values) {
                        if (n.connected) {
                            ssid = n.name
                            strength = Math.round(n.signalStrength * 100)
                            break
                        }
                    }
                }

                const hasInternet = (connectivity === "full")
                root.triggerWifiOsd(ssid, strength, hasInternet)
            }
        }
    }

    onWifiConnectedChanged: {
        if (!root.wifiWatcherReady) return

        if (wifiConnected && !wifiWasConnected) {
            // Delay 650ms to allow IP address assignment and connectivity verification
            wifiQueryDelayTimer.restart()
        }
        root.wifiWasConnected = wifiConnected
    }

    function triggerWifiOsd(ssid: string, strength: int, hasInternet: bool): void {
        if (root.full || root.specialModeActive) return
        root.osdType = "wifi"
        root.osdTitle = (ssid && ssid.length > 0) ? ssid : "Wi-Fi Network"
        root.osdHasInternet = (hasInternet !== undefined) ? hasInternet : true
        root.osdSubtitle = root.osdHasInternet ? "Connected" : "No Internet"
        root.osdValue = strength > 0 ? (strength / 100.0) : 0.8
        root.osdActive = true
        osdDismissTimer.restart()
    }

    // ============================================================
    // KEYBOARD LOCK (CAPS LOCK / NUM LOCK) WATCHER
    // ============================================================

    function triggerCapsLockOsd(enabled: bool): void {
        if (root.full || root.specialModeActive) return
        root.osdType = "capslock"
        root.osdTitle = "Caps Lock"
        root.osdLockEnabled = enabled
        root.osdActive = true
        osdDismissTimer.restart()
    }

    function triggerNumLockOsd(enabled: bool): void {
        if (root.full || root.specialModeActive) return
        root.osdType = "numlock"
        root.osdTitle = "Num Lock"
        root.osdLockEnabled = enabled
        root.osdActive = true
        osdDismissTimer.restart()
    }

    Process {
        id: keylockWatcherProcess
        command: [
            Quickshell.env("HOME") + "/.config/nexa/rust/target/release/nexad",
            "system",
            "keylock-watch"
        ]
        running: true
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                const line = data.trim()
                if (line.startsWith("CAPS:")) {
                    const active = line.endsWith("true")
                    root.triggerCapsLockOsd(active)
                } else if (line.startsWith("NUM:")) {
                    const active = line.endsWith("true")
                    root.triggerNumLockOsd(active)
                }
            }
        }
    }

    property string specialMode: "none"
    // none | search | command | power | appLauncher | controlCenter

    readonly property bool specialModeActive:
        specialMode !== "none"

    function enterSpecialMode(mode: string): void {
        root.osdActive = false
        root.osdType = "none"
        osdDismissTimer.stop()
        if (islandContent) {
            islandContent.dismissNotification()
        }
        root.specialMode = mode
        root.full = true
        root.hovered = false
        islandFocus.forceActiveFocus()
    }

    IpcHandler {
        target: "nexaIsland"

        function triggerCapsLockOsd(enabled: bool): void {
            root.triggerCapsLockOsd(enabled)
        }

        function triggerNumLockOsd(enabled: bool): void {
            root.triggerNumLockOsd(enabled)
        }

        function triggerBatteryOsd(charging: bool, pct: int): void {
            root.triggerBatteryOsd(charging, pct)
        }

        function triggerLowBatteryAlert(pct: int): void {
            root.triggerLowBatteryAlert(pct || 22)
        }

        function triggerBluetoothOsd(name: string, icon: string): void {
            root.triggerBluetoothOsd({
                name: name || "AirPods Pro",
                icon: icon || "audio-headset",
                batteryAvailable: true,
                batteryPercentage: 94
            })
        }

        function triggerWifiOsd(ssid: string, strength: int, hasInternet: bool): void {
            root.triggerWifiOsd(ssid || "Home_5G", strength || 92, hasInternet !== false)
        }

        function volumeUp(): void {
            root.triggerVolumeUp()
        }

        function volumeDown(): void {
            root.triggerVolumeDown()
        }

        function toggleMute(): void {
            root.triggerToggleMute()
        }

        function toggleMicMute(): void {
            root.triggerToggleMicMute()
        }

        function brightnessUp(): void {
            root.triggerBrightnessUp()
        }

        function brightnessDown(): void {
            root.triggerBrightnessDown()
        }

        function toggleAirplane(): void {
            root.triggerToggleAirplane()
        }

        function openSearch(): void {
            root.enterSpecialMode("search")
        }

        function openCommand(): void {
            root.enterSpecialMode("command")
        }

        function openPower(): void {
            root.enterSpecialMode("power")
        }

        function openAppLauncher(): void {
            root.enterSpecialMode("appLauncher")
        }

        function toggleAppLauncher(): void {
            if (root.specialMode === "appLauncher") {
                root.closeIsland()
            } else {
                root.enterSpecialMode("appLauncher")
            }
        }

        function openControlCenter(page: int): void {
            root.enterSpecialMode("controlCenter")
            if (page !== undefined && page >= 0) {
                islandContent.setControlCenterPage(page)
            }
        }

        function toggleControlCenter(): void {
            if (root.specialMode === "controlCenter") {
                root.closeIsland()
            } else {
                root.enterSpecialMode("controlCenter")
            }
        }

        function openNotifications(): void {
            root.openControlCenter(1)
            Quickshell.execDetached([
                Quickshell.env("HOME") + "/.config/nexa/rust/target/release/nexad",
                "notifications",
                "read-all"
            ])
        }

        function openQuickSettings(): void {
            root.openControlCenter(0)
        }

        function openFullSection(name: string): void {
            islandContent.section = name || "music"
            root.full = true
            root.hovered = false
            islandFocus.forceActiveFocus()
        }

        function close(): void {
            root.closeIsland()
        }
    }

    IpcHandler {
        target: "appLauncher"

        function open(): void {
            root.specialMode = "appLauncher"
            root.full = true
            root.hovered = false

            islandFocus.forceActiveFocus()
        }

        function close(): void {
            if (root.specialMode === "appLauncher")
                root.closeIsland()
        }

        function toggle(): void {
            if (root.specialMode === "appLauncher") {
                root.closeIsland()
            } else {
                root.specialMode = "appLauncher"
                root.full = true
                root.hovered = false

                islandFocus.forceActiveFocus()
            }
        }
    }

    IpcHandler {
        target: "controlCenter"

        function open(): void {
            root.openControlCenter(0)
        }

        function close(): void {
            if (root.specialMode === "controlCenter")
                root.closeIsland()
        }

        function toggle(): void {
            root.toggleControlCenter()
        }

        function openNotifications(): void {
            root.openNotifications()
        }

        function openQuickSettings(): void {
            root.openQuickSettings()
        }
    }

    IpcHandler {
        target: "sidePanel"

        function toggle(): void {
            root.toggleControlCenter()
        }

        function open(): void {
            root.openControlCenter(0)
        }

        function close(): void {
            if (root.specialMode === "controlCenter")
                root.closeIsland()
        }

        function openNotifications(): void {
            root.openNotifications()
        }

        function openQuickSettings(): void {
            root.openQuickSettings()
        }
    }


    // ============================================================
    // CONTENT-DERIVED STATE
    //
    // IslandContent can tell the physical shell that something
    // persistent exists.
    //
    // Currently this is the stopwatch.
    // Later media / recorder / timer can use the same concept.
    // ============================================================

    readonly property bool persistentContext:
        islandContent.persistentContext


    

    // ============================================================
    // TARGET SIZE
    // ============================================================

    readonly property int targetWidth: {
        if (root.specialMode === "appLauncher")
            return root.launcherWidth

        if (root.specialMode === "power")
            return root.powerWidth

        if (root.specialMode === "controlCenter")
            return root.controlCenterWidth

        if (root.full || root.specialModeActive)
            return root.fullWidth

        if (root.osdActive) {
            if (root.osdType === "volume")
                return root.osdVolumeWidth
            if (root.osdType === "mute")
                return root.osdMuteWidth
            if (root.osdType === "mic")
                return root.osdMicWidth
            if (root.osdType === "brightness")
                return root.osdBrightnessWidth
            if (root.osdType === "airplane")
                return root.osdAirplaneWidth
            if (root.osdType === "battery")
                return root.osdBatteryWidth
            if (root.osdType === "battery_low")
                return root.osdBluetoothWidth
            if (root.osdType === "wifi")
                return root.osdWifiWidth
            if (root.osdType === "capslock" || root.osdType === "numlock")
                return root.osdKeyLockWidth
            return 320
        }

        if (root.notificationActive)
            return root.hoverWidth

        if (root.hovered)
            return root.hoverWidth

        if (root.persistentContext)
            return root.contextWidth

        return root.compactWidth
    }

    readonly property int targetHeight: {
        if (root.specialMode === "appLauncher")
            return root.launcherHeight

        if (root.specialMode === "power")
            return root.powerHeight

        if (root.specialMode === "controlCenter")
            return root.controlCenterHeight

        if (root.full || root.specialModeActive)
            return root.fullHeight

        if (root.osdActive) {
            if (root.osdType === "volume")
                return root.osdVolumeHeight
            if (root.osdType === "mute")
                return root.osdMuteHeight
            if (root.osdType === "mic")
                return root.osdMicHeight
            if (root.osdType === "brightness")
                return root.osdBrightnessHeight
            if (root.osdType === "airplane")
                return root.osdAirplaneHeight
            if (root.osdType === "battery")
                return root.osdBatteryHeight
            if (root.osdType === "battery_low")
                return root.osdBluetoothHeight
            if (root.osdType === "wifi")
                return root.osdWifiHeight
            if (root.osdType === "capslock" || root.osdType === "numlock")
                return root.osdKeyLockHeight
            return 48
        }

        if (root.notificationActive)
            return root.hoverHeight

        if (root.hovered)
            return root.hoverHeight

        if (root.persistentContext)
            return root.contextHeight

        return root.compactHeight
    }


    // ============================================================
    // ACTIONS
    // ============================================================

    function openFull() {
        if (root.full)
            return


        // Ask content which section makes sense for the
        // currently visible context.
        islandContent.section =
            islandContent.preferredFullSection()


        root.full = true
        root.hovered = false

        islandFocus.forceActiveFocus()

        console.log(
            "NEXA full island opened:",
            islandContent.section
        )
    }


    function closeFull() {
        if (!root.full)
            return

        root.full = false
        root.hovered = false

        console.log("NEXA full island closed")
    }

    function closeIsland() {
        if (root.specialModeActive)
            root.specialMode = "none"

        root.full = false
        root.hovered = false
    }

    // ============================================================
    // INPUT MASK
    //
    // The PanelWindow itself is intentionally larger than the
    // visible Island.
    //
    // Only the visible Island rectangle receives pointer input.
    // Transparent space around it remains click-through.
    // ============================================================

    mask: Region {
        item: island
    }


    // ============================================================
    // OUTSIDE CLICK
    //
    // Active only in full mode.
    //
    // Clicking somewhere outside this window clears the Hyprland
    // focus grab and closes the Island.
    // ============================================================

    HyprlandFocusGrab {
        id: focusGrab

        windows: [root]

        active: root.full || root.specialModeActive
        onCleared: {
            // Keep the Island alive while a Theme popup is open.
            // The popup lives in a separate Wayland surface, so
            // Hyprland clears our grab when the user clicks it —
            // but that click is still intentional Island interaction.
            if (root.themePopupOpen)
                return

            root.closeIsland()
        }
    }


    // ============================================================
    // VISIBLE ISLAND SURFACE
    // ============================================================

    Rectangle {
        id: island

        anchors {
            top: parent.top
            horizontalCenter: parent.horizontalCenter
        }

        width: root.targetWidth
        height: root.targetHeight
        clip: true


        // --------------------------------------------------------
        // SHAPE
        // --------------------------------------------------------

        radius:
          root.full
          || root.specialModeActive
          || root.hovered
          || root.notificationActive
          ? Nexa.Theme.radiusLg
          : (root.osdActive ? Math.round(targetHeight / 2) : Nexa.Theme.radiusPill)


        // --------------------------------------------------------
        // SURFACE COLOR
        // --------------------------------------------------------

        color:
          root.full
          || root.specialModeActive
          || root.hovered
          || root.notificationActive
          || root.osdActive
          ? Nexa.Theme.islandBackgroundExpanded
          : Nexa.Theme.islandBackground


        border.width:
            Nexa.Theme.borderThin

        border.color:
          root.full
          || root.hovered
          || root.notificationActive
          || root.osdActive
          ? Nexa.Theme.borderStrong
          : Nexa.Theme.border


        // ========================================================
        // VISUAL ANIMATION
        //
        // Width, height, and corner radius animate together using
        // identical timings and OutQuint easing for maximum fluidity.
        // ========================================================

        Behavior on width {
            NumberAnimation {
                duration: Nexa.Theme.animationNormal
                easing.type: Nexa.Theme.easingDecelerate
            }
        }


        Behavior on height {
            NumberAnimation {
                duration: Nexa.Theme.animationNormal
                easing.type: Nexa.Theme.easingDecelerate
            }
        }


        Behavior on radius {
            NumberAnimation {
                duration: Nexa.Theme.animationNormal
                easing.type: Nexa.Theme.easingDecelerate
            }
        }


        Behavior on color {
            ColorAnimation {
                duration: Nexa.Theme.animationFast
                easing.type: Easing.OutCubic
            }
        }


        Behavior on border.color {
            ColorAnimation {
                duration: Nexa.Theme.animationFast
                easing.type: Easing.OutCubic
            }
        }


        // ========================================================
        // HOVER DETECTION
        //
        // IMPORTANT:
        //
        // HoverHandler observes pointer presence.
        // It does NOT own feature button clicks.
        //
        // This means stopwatch/media controls can be clicked
        // without fighting the Island hover system.
        // ========================================================

        HoverHandler {
            id: islandHover

            enabled:
              !root.full
              && !root.specialModeActive
              && !root.notificationActive
              && !root.osdActive

            onHoveredChanged: {
                root.hovered =
                    islandHover.hovered

                console.log(
                    "[Island] hover:",
                    islandHover.hovered
                )
            }
        }


        // ========================================================
        // BACKGROUND OPEN AREA
        //
        // IMPORTANT:
        //
        // This MouseArea is BELOW IslandContent.
        //
        // Empty/background Island space:
        //     click -> open full
        //
        // Actual controls above it:
        //     Pause / Resume / Next / etc.
        //     consume their own clicks.
        //
        // This prevents hover buttons from opening full mode.
        // ========================================================

        MouseArea {
            id: backgroundOpenArea

            anchors.fill: parent

            z: 0

            enabled:
              !root.full
              && !root.specialModeActive
              && !root.notificationActive
              && !root.osdActive

            cursorShape: Qt.PointingHandCursor

            onClicked: {
                root.openFull()
            }
        }


        // ========================================================
        // CONTENT + KEYBOARD FOCUS
        // ========================================================

        FocusScope {
            id: islandFocus

            anchors.fill: parent

            z: 1

            focus: root.full || root.specialModeActive

            // ----------------------------------------------------
            // ESCAPE
            // ----------------------------------------------------

            Keys.onEscapePressed: event => {
                if (root.full || root.specialModeActive) {
                    root.closeIsland()
                    event.accepted = true
                }
            }


            // ----------------------------------------------------
            // ACTUAL ISLAND CONTENT
            // ----------------------------------------------------

            IslandContent {
              id: islandContent

              anchors.fill:
                  parent

              hovered:
                  root.hovered

              full:
                  root.full

              specialMode:
                  root.specialMode

              osdActive:
                  root.osdActive

              osdType:
                  root.osdType

              osdValue:
                  root.osdValue

              osdMuted:
                  root.osdMuted

              osdAirplaneEnabled:
                  root.osdAirplaneEnabled

              osdTitle:
                  root.osdTitle

              osdSubtitle:
                  root.osdSubtitle

              osdIcon:
                  root.osdIcon

              osdBatteryCharging:
                  root.osdBatteryCharging

              osdHasInternet:
                  root.osdHasInternet

              osdLockEnabled:
                  root.osdLockEnabled

              onRequestCloseSpecialMode:
                  root.closeIsland()


              onNotificationPreviewActivated: {
                  Quickshell.execDetached([
                      "qs",
                      "-p",
                      Quickshell.env("HOME")
                          + "/.config/nexa/quickshell",
                      "ipc",
                      "call",
                      "sidePanel",
                      "openNotifications"
                  ])
              }
          }

        }
    }

    Component.onCompleted: {
        volumeQueryProcess.running = true
        micQueryProcess.running = true
        brightnessQueryProcess.running = true
        airplaneQueryProcess.running = true
    }
}
