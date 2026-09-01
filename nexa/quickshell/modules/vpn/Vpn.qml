import QtQuick
import Quickshell
import Quickshell.Io


Item {
    id: root

    property bool enabled: false

    property string activeProfile: ""
    property var configuredProfiles: []
    property string lastProfile: ""

    property bool loading: false

    readonly property bool available:
        configuredProfiles.length > 0

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
        if (!available)
            return

        if (toggleProcess.running)
            return

        toggleProcess.running = true
    }


    Process {
        id: infoProcess

        command: [
            root.nexad,
            "system",
            "vpn",
            "info"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                root.loading = false

                try {
                    const data = JSON.parse(text)

                    root.enabled =
                        Boolean(data.enabled)

                    root.activeProfile =
                        data.active ?? ""

                    root.configuredProfiles =
                        Array.isArray(data.configured)
                        ? data.configured
                        : []

                    root.lastProfile =
                        data.last ?? ""

                } catch (error) {
                    console.warn(
                        "[NEXA VPN] parse failed:",
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
            "vpn",
            "toggle"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text)

                    root.enabled =
                        Boolean(data.enabled)

                    root.activeProfile =
                        data.active ?? ""

                    root.configuredProfiles =
                        Array.isArray(data.configured)
                        ? data.configured
                        : []

                    root.lastProfile =
                        data.last ?? ""

                } catch (error) {
                    console.warn(
                        "[NEXA VPN] toggle parse failed:",
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

        interval: 500
        repeat: false

        onTriggered:
            root.refresh()
    }


    Timer {
        interval: 3500
        repeat: true
        running: root.visible

        onTriggered:
            root.refresh()
    }

    onVisibleChanged: {
        if (root.visible)
            root.refresh()
    }

    Component.onCompleted:
        root.refresh()
}
