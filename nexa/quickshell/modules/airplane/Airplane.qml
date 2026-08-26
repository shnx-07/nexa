import QtQuick
import Quickshell
import Quickshell.Io


Item {
    id: root

    property bool enabled: false

    property bool wifiEnabled: false
    property bool bluetoothEnabled: false

    property bool restoreWifi: false
    property bool restoreBluetooth: false

    property bool loading: false

    readonly property string nexad:
        Quickshell.env("HOME")
        + "/.config/nexa/rust/target/release/nexad"


    function refresh() {
        if (infoProcess.running)
            return

        loading = true
        infoProcess.running = true
    }


    function toggle() {
        if (toggleProcess.running)
            return

        toggleProcess.running = true
    }


    Process {
        id: infoProcess

        command: [
            root.nexad,
            "system",
            "airplane",
            "info"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                root.loading = false

                try {
                    const data = JSON.parse(text)

                    root.enabled =
                        Boolean(data.enabled)

                    root.wifiEnabled =
                        Boolean(data.wifi_enabled)

                    root.bluetoothEnabled =
                        Boolean(data.bluetooth_enabled)

                    root.restoreWifi =
                        Boolean(data.restore_wifi)

                    root.restoreBluetooth =
                        Boolean(data.restore_bluetooth)

                } catch (error) {
                    console.warn(
                        "[NEXA Airplane] parse failed:",
                        error,
                        text
                    )
                }
            }
        }
    }


    Process {
        id: toggleProcess

        command: [
            root.nexad,
            "system",
            "airplane",
            "toggle"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text)

                    root.enabled =
                        Boolean(data.enabled)

                    root.wifiEnabled =
                        Boolean(data.wifi_enabled)

                    root.bluetoothEnabled =
                        Boolean(data.bluetooth_enabled)

                    root.restoreWifi =
                        Boolean(data.restore_wifi)

                    root.restoreBluetooth =
                        Boolean(data.restore_bluetooth)

                } catch (error) {
                    console.warn(
                        "[NEXA Airplane] toggle parse failed:",
                        error,
                        text
                    )
                }

                delayedRefresh.restart()
            }
        }
    }


    Timer {
        id: delayedRefresh

        interval: 400
        repeat: false

        onTriggered:
            root.refresh()
    }


    Timer {
        interval: 2000
        repeat: true
        running: true

        onTriggered:
            root.refresh()
    }


    Component.onCompleted:
        root.refresh()
}
