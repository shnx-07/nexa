pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    // Central state properties synced from nexad
    property int volume: 80
    property bool muted: false
    property int inputVolume: 100
    property bool inputMuted: false
    property int brightness: 100
    property bool bluetoothEnabled: false
    property bool wifiEnabled: true
    property bool airplaneEnabled: false
    property bool nightlightEnabled: false
    property string nightlightMode: "manual"
    property int nightlightTemperature: 5000
    property string screenFilter: "off"
    property bool dnd: false
    property real timestamp: 0

    readonly property string statePath: Quickshell.env("HOME") + "/.config/nexa/config/settings-state.json"
    readonly property string nexadPath: Quickshell.env("HOME") + "/.config/nexa/rust/target/release/nexad"

    // Watcher for atomic file updates
    FileView {
        id: stateFile
        path: root.statePath
        watchChanges: true

        onLoaded: {
            root.parseState(stateFile.text())
        }
    }

    function parseState(raw) {
        if (!raw || raw.trim().length === 0) return
        try {
            const data = JSON.parse(raw)
            if (data.timestamp !== undefined && data.timestamp !== root.timestamp) {
                root.timestamp = data.timestamp
                root.volume = data.volume ?? root.volume
                root.muted = data.muted ?? root.muted
                root.inputVolume = data.input_volume ?? root.inputVolume
                root.inputMuted = data.input_muted ?? root.inputMuted
                root.brightness = data.brightness ?? root.brightness
                root.bluetoothEnabled = data.bluetooth_enabled ?? root.bluetoothEnabled
                root.wifiEnabled = data.wifi_enabled ?? root.wifiEnabled
                root.airplaneEnabled = data.airplane_enabled ?? root.airplaneEnabled
                root.nightlightEnabled = data.nightlight_enabled ?? root.nightlightEnabled
                root.nightlightMode = data.nightlight_mode ?? root.nightlightMode
                root.nightlightTemperature = data.nightlight_temperature ?? root.nightlightTemperature
                root.screenFilter = data.screen_filter ?? root.screenFilter
                root.dnd = data.dnd ?? root.dnd
            }
        } catch (e) {
            // Ignore partial/in-flight reads safely without throwing errors
        }
    }

    // Process to request a full hardware sync from nexad
    Process {
        id: syncProcess
        command: [root.nexadPath, "state", "sync"]
        running: false

        stdout: SplitParser {
            onRead: data => {
                root.parseState(data)
            }
        }
    }

    function sync() {
        if (!syncProcess.running) {
            syncProcess.running = true
        }
    }

    Component.onCompleted: {
        sync()
    }
}
