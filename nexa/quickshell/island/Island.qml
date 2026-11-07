import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell.Io
import Quickshell
import Quickshell.Hyprland
import Quickshell.Bluetooth
import Quickshell.Networking

import "../NewNexaUI" as NexaUI
import "../services" as Services


PanelWindow {
    id: root


    readonly property bool notificationActive:
        islandContent.notificationActive
    property bool notificationEventInitialized: false
    property real squashVal: 0

    Behavior on squashVal {
        NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
    }

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
    // Clock / music / notifications / quick settings etc.
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
    implicitWidth: 920
    implicitHeight: 660

    // Synchronize vertical position with the TopBar pills and rail for pixel-perfect symmetry
    readonly property int effectiveBarHeight: (Services.BarConfig.position === "top" && Services.BarConfig.height > 0)
        ? Services.BarConfig.height
        : NexaUI.NexaTokens.barHeight
    readonly property int compactTopMargin: Math.max(4, Math.round((effectiveBarHeight - root.compactHeight) / 2))

    margins {
        top: root.compactTopMargin

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
        NexaUI.NexaTokens.islandCompactWidth

    readonly property int compactHeight:
        NexaUI.NexaTokens.islandCompactHeight


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

    readonly property int launcherWidth: 880
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
    // FILE SHELF / TRAY DIMENSIONS
    // ============================================================

    readonly property int shelfWidth: 580
    readonly property int shelfHeight: 155

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

    // ============================================================
    

    Connections {
        target: Services.SystemState
        function onBrightnessChanged() {
            if (root.osdType === "brightness" || !root.osdActive) {
                root.osdValue = Math.max(0.01, Math.min(1.0, Services.SystemState.brightness / 100.0))
            }
        }
        function onVolumeChanged() {
            if (root.osdType === "volume" || !root.osdActive) {
                root.osdValue = Math.max(0.0, Math.min(1.0, Services.SystemState.volume / 100.0))
            }
        }
        function onMutedChanged() {
            root.osdMuted = Services.SystemState.muted
        }
        function onInputVolumeChanged() {
            if (root.osdType === "mic") {
                root.osdValue = Math.max(0.0, Math.min(1.0, Services.SystemState.inputVolume / 100.0))
            }
        }
        function onInputMutedChanged() {
            root.osdMicMuted = Services.SystemState.inputMuted
        }
        function onAirplaneEnabledChanged() {
            root.osdAirplaneEnabled = Services.SystemState.airplaneEnabled
        }
        function onWifiConnectedChanged() {
            if (!root.wifiWatcherReady) return
            if (Services.SystemState.wifiConnected && !root.wifiWasConnected) {
                root.triggerWifiOsd(Services.SystemState.wifiSsid, Services.SystemState.wifiSignal, Services.SystemState.wifiHasInternet)
            }
            root.wifiWasConnected = Services.SystemState.wifiConnected
        }
    }

    // ============================================================
    

    Timer {
        id: statePersistDebounceTimer
        interval: 600
        repeat: false
        onTriggered: {
            Quickshell.execDetached([
                Quickshell.env("HOME") + "/.config/nexa/rust/target/release/nexad",
                "state",
                "sync"
            ])
        }
    }

    // ============================================================
    


    function triggerVolumeUp() {
        if (root.full || root.specialModeActive) return
        root.osdType = "volume"
        root.osdMuted = false
        const prevValue = root.osdValue
        root.osdValue = Math.min(1.0, root.osdValue + 0.05)
        root.osdActive = true
        osdDismissTimer.restart()
        Quickshell.execDetached([Quickshell.env("HOME") + "/.config/nexa/rust/target/release/nexad", "audio", "up", "5"])
        if (prevValue < 0.999) {
            Quickshell.execDetached([Quickshell.env("HOME") + "/.config/nexa/rust/target/release/nexad", "sound", "play", "volume"])
        }
    }

    function triggerVolumeDown() {
        if (root.full || root.specialModeActive) return
        root.osdType = "volume"
        const prevValue = root.osdValue
        root.osdValue = Math.max(0.0, root.osdValue - 0.05)
        root.osdActive = true
        osdDismissTimer.restart()
        Quickshell.execDetached([Quickshell.env("HOME") + "/.config/nexa/rust/target/release/nexad", "audio", "down", "5"])
        if (prevValue > 0.001) {
            Quickshell.execDetached([Quickshell.env("HOME") + "/.config/nexa/rust/target/release/nexad", "sound", "play", "volume"])
        }
    }

    function triggerToggleMute() {
        if (root.full || root.specialModeActive) return
        root.osdType = "mute"
        root.osdMuted = !root.osdMuted
        root.osdActive = true
        osdDismissTimer.restart()
        Quickshell.execDetached([Quickshell.env("HOME") + "/.config/nexa/rust/target/release/nexad", "audio", "toggle-mute"])
    }

    function triggerBrightnessUp() {
        if (root.full || root.specialModeActive) return
        root.osdType = "brightness"
        root.osdValue = Math.min(1.0, root.osdValue + 0.05)
        root.osdActive = true
        osdDismissTimer.restart()
        Quickshell.execDetached([
            Quickshell.env("HOME") + "/.config/nexa/rust/target/release/nexad",
            "brightness",
            "up",
            "5"
        ])
    }

    function triggerBrightnessDown() {
        if (root.full || root.specialModeActive) return
        root.osdType = "brightness"
        root.osdValue = Math.max(0.01, root.osdValue - 0.05)
        root.osdActive = true
        osdDismissTimer.restart()
        Quickshell.execDetached([
            Quickshell.env("HOME") + "/.config/nexa/rust/target/release/nexad",
            "brightness",
            "down",
            "5"
        ])
    }

    function triggerToggleMicMute() {
        if (root.full || root.specialModeActive) return
        root.osdType = "mic"
        root.osdMicMuted = !root.osdMicMuted
        root.osdMuted = root.osdMicMuted
        root.osdActive = true
        osdDismissTimer.restart()
        Quickshell.execDetached([Quickshell.env("HOME") + "/.config/nexa/rust/target/release/nexad", "audio", "input-toggle-mute"])
    }

    function triggerToggleAirplane() {
        if (root.full || root.specialModeActive) return
        root.osdType = "airplane"
        root.osdAirplaneEnabled = !root.osdAirplaneEnabled
        root.osdActive = true
        osdDismissTimer.restart()
        Quickshell.execDetached([Quickshell.env("HOME") + "/.config/nexa/rust/target/release/nexad", "system", "airplane", "toggle"])
    }

    // ============================================================
    // BATTERY HARDWARE OSD (DRIVEN NATIVELY BY RUST DAEMON)
    // ============================================================

    function triggerBatteryOsd(charging: bool, pct: int) {
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

    function triggerLowBatteryAlert(pct: int) {
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

    // ============================================================
    

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

    // ============================================================
    

    function triggerBluetoothOsd(device) {
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
        else if (device.icon && device.icon.length > 0) iconName = device.icon
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

    // ============================================================
    // WIFI HARDWARE OSD (DRIVEN NATIVELY BY RUST DAEMON)
    // ============================================================

    function triggerWifiOsd(ssid, strength, hasInternet) {
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

    function triggerCapsLockOsd(enabled: bool) {
        if (root.full || root.specialModeActive) return
        root.osdType = "capslock"
        root.osdTitle = "Caps Lock"
        root.osdLockEnabled = enabled
        root.osdActive = true
        osdDismissTimer.restart()
    }

    function triggerNumLockOsd(enabled: bool) {
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

    // ============================================================
    

    property string specialMode: "none"
    // none | search | command | power | appLauncher | controlCenter

    readonly property bool specialModeActive:
        specialMode !== "none"

    function enterSpecialMode(mode: string) {
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

    function openControlCenter(page: int) {
        root.enterSpecialMode("controlCenter")
        if (page !== undefined && page >= 0) {
            islandContent.setControlCenterPage(page)
        }
    }

    // ============================================================
    

    function toggleControlCenter() {
        if (root.specialMode === "controlCenter") {
            root.closeIsland()
        } else {
            root.enterSpecialMode("controlCenter")
        }
    }

    // ============================================================
    

    function openShelf() {
        root.enterSpecialMode("shelf")
    }

    function toggleShelf() {
        if (root.specialMode === "shelf") {
            root.closeIsland()
        } else {
            root.enterSpecialMode("shelf")
        }
    }

    // ============================================================
    

    function openQuickSettings() {
        root.openControlCenter(0)
    }

    function openNotifications() {
        root.openControlCenter(1)
        Quickshell.execDetached([
            Quickshell.env("HOME") + "/.config/nexa/rust/target/release/nexad",
            "notifications",
            "read-all"
        ])
    }

    IpcHandler {
        target: "nexaIsland"

        function triggerCapsLockOsd(enabled: bool) {
            root.triggerCapsLockOsd(enabled)
        }

        function triggerNumLockOsd(enabled: bool) {
            root.triggerNumLockOsd(enabled)
        }

        function triggerBatteryOsd(charging: string, pct: int) {
            root.triggerBatteryOsd(charging === "true" || charging === "1", pct)
        }

        function triggerLowBatteryAlert(pct: int) {
            root.triggerLowBatteryAlert(pct || 22)
        }

        function triggerBluetoothOsd(name: string, icon: string) {
            let batt = Services.SystemState.bluetoothDeviceBattery
            root.triggerBluetoothOsd({
                name: (name && name.length > 0) ? name : (Services.SystemState.bluetoothDeviceName || "Bluetooth Device"),
                icon: (icon && icon.length > 0) ? icon : (Services.SystemState.bluetoothDeviceType || "audio-headset"),
                batteryAvailable: batt > 0,
                batteryPercentage: batt > 0 ? batt : 0
            })
        }

        function triggerWifiOsd(ssid: string, strength: int, hasInternet: string) {
            const hasNet = (hasInternet === "true" || hasInternet === "1")
            root.triggerWifiOsd(
                (ssid && ssid.length > 0) ? ssid : (Services.SystemState.wifiSsid || "Wi-Fi Network"),
                strength > 0 ? strength : (Services.SystemState.wifiSignal || 80),
                hasNet
            )
        }

        function volumeUp() {
            root.triggerVolumeUp()
        }

        function volumeDown() {
            root.triggerVolumeDown()
        }

        function toggleMute() {
            root.triggerToggleMute()
        }

        function toggleMicMute() {
            root.triggerToggleMicMute()
        }

        function brightnessUp() {
            root.triggerBrightnessUp()
        }

        function brightnessDown() {
            root.triggerBrightnessDown()
        }

        function toggleAirplane() {
            root.triggerToggleAirplane()
        }

        function openSearch() {
            root.enterSpecialMode("search")
        }

        function openCommand() {
            root.enterSpecialMode("command")
        }

        function openPower() {
            root.enterSpecialMode("power")
        }

        function togglePower() {
            if (root.specialMode === "power") {
                root.closeIsland()
            } else {
                root.enterSpecialMode("power")
            }
        }

        function openAppLauncher() {
            root.enterSpecialMode("appLauncher")
        }

        function toggleAppLauncher() {
            if (root.specialMode === "appLauncher") {
                root.closeIsland()
            } else {
                root.enterSpecialMode("appLauncher")
            }
        }

        function openControlCenter(page: int) {
            root.enterSpecialMode("controlCenter")
            if (page !== undefined && page >= 0) {
                islandContent.setControlCenterPage(page)
            }
        }

        function toggleControlCenter() {
            if (root.specialMode === "controlCenter") {
                root.closeIsland()
            } else {
                root.enterSpecialMode("controlCenter")
            }
        }

        function openNotifications() {
            root.openControlCenter(1)
            Quickshell.execDetached([
                Quickshell.env("HOME") + "/.config/nexa/rust/target/release/nexad",
                "notifications",
                "read-all"
            ])
        }

        function openQuickSettings() {
            root.openControlCenter(0)
        }

        function openFullSection(name: string) {
            islandContent.section = name || "music"
            root.full = true
            root.hovered = false
            islandFocus.forceActiveFocus()
        }

        function refreshRecorder() {
            islandContent.refreshRecorder()
        }

        function close() {
            root.closeIsland()
        }
    }

    // ============================================================
    

    IpcHandler {
        target: "appLauncher"

        function open() {
            root.specialMode = "appLauncher"
            root.full = true
            root.hovered = false

            islandFocus.forceActiveFocus()
        }

        function close() {
            if (root.specialMode === "appLauncher")
                root.closeIsland()
        }

        function toggle() {
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

    // ============================================================
    

    IpcHandler {
        target: "controlCenter"

        function open() {
            root.openControlCenter(0)
        }

        function close() {
            if (root.specialMode === "controlCenter")
                root.closeIsland()
        }

        function toggle() {
            root.toggleControlCenter()
        }

        function openNotifications() {
            root.openNotifications()
        }

        function openQuickSettings() {
            root.openQuickSettings()
        }
    }

    // ============================================================
    

    IpcHandler {
        target: "sidePanel"

        function toggle() {
            root.toggleControlCenter()
        }

        function open() {
            root.openControlCenter(0)
        }

        function close() {
            if (root.specialMode === "controlCenter")
                root.closeIsland()
        }

        function openNotifications() {
            root.openNotifications()
        }

        function openQuickSettings() {
            root.openQuickSettings()
        }
    }

    // ============================================================
    

    IpcHandler {
        target: "fileShelf"

        function open() {
            root.openShelf()
        }

        function close() {
            if (root.specialMode === "shelf")
                root.closeIsland()
        }

        function toggle() {
            root.toggleShelf()
        }
    }

    // ============================================================
    


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

        if (root.specialMode === "shelf")
            return root.shelfWidth

        if (root.full || root.specialModeActive) {
            return root.fullWidth
        }

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
            if (root.osdType === "bluetooth")
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

        if (root.specialMode === "shelf")
            return root.shelfHeight

        if (root.full || root.specialModeActive) {
            if (islandContent.section === "music")
                return 310
            return root.fullHeight
        }

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
            if (root.osdType === "bluetooth")
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

    function openFullSection(name: string) {
        islandContent.section = name || "music"
        root.full = true
        root.hovered = false
        islandFocus.forceActiveFocus()
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
        Region {
            item: islandClockBtn
        }
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

        active: (root.full || root.specialModeActive) && !islandContent.shelfDragInProgress
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
    


    // ============================================================
    // VISIBLE ISLAND SURFACE
    // ============================================================

    // GPU-Accelerated Nexa Shadow (Elevation 0 when resting on top bar, Elevation 2 when expanded modal)
    NexaUI.NexaShadow {
        targetItem: island
        elevation: (root.full || root.hovered || root.specialModeActive) ? 2 : 0
    }

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
        //
        // The Dynamic Island dimensions and curvature are handled
        // independently from Nexa Shell curvature:
        // - Collapsed pill: signature capsule pill (targetHeight / 2)
        // - OSD notifications: capsule pill (targetHeight / 2)
        // - Expanded views: modern smooth curve (24px)
        // --------------------------------------------------------

        radius: {
            if (NexaUI.NexaTokens.islandRounding === 0) return 0;
            if (root.full || root.specialModeActive || root.hovered || root.notificationActive) {
                return (NexaUI.NexaTokens.islandRounding >= 999) ? 24 : Math.min(24, NexaUI.NexaTokens.islandRounding);
            }
            if (root.osdActive) {
                return Math.round(targetHeight / 2);
            }
            return (NexaUI.NexaTokens.islandRounding >= 999) ? Math.round(targetHeight / 2) : NexaUI.NexaTokens.islandRounding;
        }


        // --------------------------------------------------------
        // SURFACE COLOR
        // --------------------------------------------------------

        color:
          root.full
          || root.specialModeActive
          || root.hovered
          || root.notificationActive
          || root.osdActive
          ? NexaUI.NexaColors.islandBackgroundExpanded
          : NexaUI.NexaColors.islandBackground


        border.width: NexaUI.NexaTokens.borderThin

        border.color: (root.full || root.hovered || root.specialModeActive || root.notificationActive || root.osdActive)
            ? NexaUI.NexaColors.borderStrong
            : NexaUI.NexaColors.border


        // ========================================================
        // VISUAL ANIMATION
        //
        // Width, height, and corner radius animate together using
        // spring physics driven by NexaMotion tokens.
        // ========================================================

        Behavior on width {
            enabled: NexaUI.NexaMotion.enabled
            SpringAnimation {
                spring: NexaUI.NexaMotion.springStiffness
                damping: NexaUI.NexaMotion.springDamping
                mass: NexaUI.NexaMotion.springMass
                epsilon: 0.25
            }
        }

        Behavior on height {
            enabled: NexaUI.NexaMotion.enabled
            SpringAnimation {
                spring: NexaUI.NexaMotion.springStiffness
                damping: NexaUI.NexaMotion.springDamping
                mass: NexaUI.NexaMotion.springMass
                epsilon: 0.25
            }
        }

        Behavior on radius {
            enabled: NexaUI.NexaMotion.enabled
            SpringAnimation {
                spring: NexaUI.NexaMotion.springStiffness
                damping: NexaUI.NexaMotion.springDamping
                mass: NexaUI.NexaMotion.springMass
                epsilon: 0.25
            }
        }


        Behavior on color {
            ColorAnimation {
                duration: NexaUI.NexaMotion.durationFast
                easing.type: NexaUI.NexaMotion.standardEasing
            }
        }


        Behavior on border.color {
            ColorAnimation {
                duration: NexaUI.NexaMotion.durationFast
                easing.type: NexaUI.NexaMotion.standardEasing
            }
        }

        scale: 1 - 0.025 * root.squashVal
        Behavior on scale {
            NumberAnimation {
                duration: 140
                easing.type: Easing.OutCubic
            }
        }

        // Apple / Tactile 4-stop OLED Depth Micro-Gradient (3D Surface Convexity)
        Rectangle {
            anchors.fill: parent
            radius: island.radius
            antialiasing: island.radius > 0
            visible: NexaUI.NexaOptics.surface3DGradient && NexaUI.NexaOptics.gradientIntensity > 0.01
            opacity: NexaUI.NexaOptics.gradientIntensity
            z: 0
            gradient: Gradient {
                GradientStop { position: 0.00; color: Qt.rgba(1, 1, 1, 0.060) }
                GradientStop { position: 0.40; color: Qt.rgba(1, 1, 1, 0.014) }
                GradientStop { position: 0.72; color: Qt.rgba(0, 0, 0, 0.000) }
                GradientStop { position: 1.00; color: Qt.rgba(0, 0, 0, 0.150) }
            }
        }

        // Apple Top Chamfer Specular Highlight (Physical Overhead Light Reflection)
        Rectangle {
            anchors.top: parent.top
            anchors.topMargin: 1
            anchors.horizontalCenter: parent.horizontalCenter
            width: island.radius > 0 ? Math.max(0, parent.width - island.radius * 1.6) : parent.width
            height: 1
            visible: NexaUI.NexaOptics.specularHighlight && NexaUI.NexaOptics.specularIntensity > 0.01
            opacity: Math.min(1.0, NexaUI.NexaOptics.specularIntensity / 0.28)
            z: 1
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.32) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        // Apple Bottom Chamfer Ambient Shadow Line (Crisp Grounding Line)
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 1
            anchors.horizontalCenter: parent.horizontalCenter
            width: island.radius > 0 ? Math.max(0, parent.width - island.radius * 1.6) : parent.width
            height: 1
            visible: NexaUI.NexaOptics.specularHighlight
            opacity: Math.min(1.0, NexaUI.NexaOptics.specularIntensity / 0.28)
            z: 1
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.5; color: Qt.rgba(0, 0, 0, 0.45) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        NexaUI.NexaShaderSubstrate {
            anchors.fill: parent
            radius: island.radius
            showSpecularLine: false
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

            onPressed: root.squashVal = 1.0
            onReleased: root.squashVal = 0.0
            onCanceled: root.squashVal = 0.0

            onClicked: {
                root.openFull()
            }
        }

        // ========================================================
        // DROP AREA FOR FILE SHELF (TRAY)
        // ========================================================

        DropArea {
            id: islandDropArea

            anchors.fill: parent

            z: 0

            onEntered: drag => {
                if (drag.hasUrls) {
                    root.openShelf()
                    drag.acceptProposedAction()
                }
            }

            onDropped: drop => {
                if (drop.hasUrls) {
                    root.openShelf()

                    // Pass ALL dropped URLs in a single nexad call to avoid the
                    // concurrent-write race condition that loses files when each
                    // URL spawned its own process that overwrote shelf.json.
                    const nexad = Quickshell.env("HOME") + "/.config/nexa/rust/target/release/nexad"
                    const cmd = [nexad, "shelf", "add"].concat(Array.from(drop.urls))
                    Quickshell.execDetached(cmd)

                    drop.acceptProposedAction()
                    // Give nexad time to run gio info for each file before we close
                    shelfAutoCloseTimer.restart()
                }
            }
        }

        Timer {
            id: shelfAutoCloseTimer
            interval: 1200
            repeat: false
            onTriggered: {
                if (root.specialMode === "shelf")
                    root.closeIsland()
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

            Keys.onPressed: event => {
                if (root.specialMode === "power") {
                    if (event.key === Qt.Key_1 || event.text === "1") {
                        islandContent.triggerPowerKey(1)
                        event.accepted = true
                    } else if (event.key === Qt.Key_2 || event.text === "2") {
                        islandContent.triggerPowerKey(2)
                        event.accepted = true
                    } else if (event.key === Qt.Key_3 || event.text === "3") {
                        islandContent.triggerPowerKey(3)
                        event.accepted = true
                    } else if (event.key === Qt.Key_4 || event.text === "4") {
                        islandContent.triggerPowerKey(4)
                        event.accepted = true
                    } else if (event.key === Qt.Key_5 || event.text === "5") {
                        islandContent.triggerPowerKey(5)
                        event.accepted = true
                    }
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

              onRequestOpenControlCenter: page => {
                  root.openControlCenter(page)
              }

              onRequestOpenClockSection: {
                  root.full = true
                  root.hovered = false
                  islandFocus.forceActiveFocus()
              }

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

    // ========================================================
    // TOP-LEVEL BORDER RIM OVERLAY
    // ========================================================
    // Guarantees border is ALWAYS drawn cleanly above all content layers
    // and is never clipped by island.clip: true.
    Rectangle {
        id: islandBorderOverlay
        anchors.fill: island
        radius: island.radius
        color: "transparent"
        border.width: island.border.width
        border.color: island.border.color
        enabled: false
        z: 100
    }

    IslandClockButton {
        id: islandClockBtn
        anchors.left: island.right
        anchors.leftMargin: 8
        anchors.verticalCenter: island.verticalCenter
        visible: islandContent.mediaContextActive && !root.full && !root.hovered && !root.specialModeActive && !root.osdActive && !root.notificationActive
        onClicked: {
            root.openFullSection("clock")
        }
    }
    

    Component.onCompleted: {
        if (Services.SystemState.brightness > 0) {
            root.osdValue = Math.max(0.01, Math.min(1.0, Services.SystemState.brightness / 100.0))
        }
        root.osdMuted = Services.SystemState.muted
        root.osdMicMuted = Services.SystemState.inputMuted
        root.osdAirplaneEnabled = Services.SystemState.airplaneEnabled
    }

    // ============================================================
    
}
