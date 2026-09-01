import QtQuick
import Quickshell
import Quickshell.Io


Item {
    id: root


    // ============================================================
    // PUBLIC STATE
    // ============================================================

    property bool enabled: false

    property string filter: "off"

    property var available: [
        "off",
        "chroma",
        "grayscale",
        "hdr-boost",
        "high-contrast",
        "invert",
        "sepia"
    ]

    property bool loading: false
    property bool changing: false


    readonly property string nexad:
        Quickshell.env("HOME")
        + "/.config/nexa/rust/target/release/nexad"


    // ============================================================
    // DISPLAY LABEL
    // ============================================================

    readonly property string label: {
        switch (filter) {
        case "chroma":
            return "Chroma"

        case "grayscale":
            return "Grayscale"

        case "hdr-boost":
            return "HDR Boost"

        case "high-contrast":
            return "High Contrast"

        case "invert":
            return "Invert Colors"

        case "sepia":
            return "Sepia"

        default:
            return "Off"
        }
    }


    // ============================================================
    // APPLY JSON
    // ============================================================

    function applyData(data) {
        root.enabled =
            Boolean(data.enabled)

        root.filter =
            data.filter ?? "off"

        root.available =
            Array.isArray(data.available)
            ? data.available
            : root.available
    }


    // ============================================================
    // REFRESH
    // ============================================================

    function refresh() {
        if (infoProcess.running)
            return

        loading = true
        infoProcess.running = true
    }


    // ============================================================
    // SET FILTER
    // ============================================================

    function setFilter(value) {
        if (changing)
            return

        if (value === "off") {
            off()
            return
        }

        changing = true

        setProcess.command = [
            nexad,
            "screenFilter",
            "set",
            value
        ]

        setProcess.running = true
    }


    // ============================================================
    // OFF
    // ============================================================

    function off() {
        if (changing)
            return

        changing = true
        offProcess.running = true
    }


    // ============================================================
    // INFO
    // ============================================================

    Process {
        id: infoProcess

        command: [
            root.nexad,
            "screenFilter",
            "info"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                root.loading = false

                try {
                    root.applyData(
                        JSON.parse(text)
                    )
                } catch (error) {
                    console.warn(
                        "[NEXA ScreenFilter] info parse failed:",
                        error,
                        text
                    )
                }
            }
        }
    }


    // ============================================================
    // SET PROCESS
    // ============================================================

    Process {
        id: setProcess

        stdout: StdioCollector {
            onStreamFinished: {
                root.changing = false

                try {
                    root.applyData(
                        JSON.parse(text)
                    )
                } catch (error) {
                    console.warn(
                        "[NEXA ScreenFilter] set parse failed:",
                        error,
                        text
                    )
                }

                delayedRefresh.restart()
            }
        }
    }


    // ============================================================
    // OFF PROCESS
    // ============================================================

    Process {
        id: offProcess

        command: [
            root.nexad,
            "screenFilter",
            "off"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                root.changing = false

                try {
                    root.applyData(
                        JSON.parse(text)
                    )
                } catch (error) {
                    console.warn(
                        "[NEXA ScreenFilter] off parse failed:",
                        error,
                        text
                    )
                }

                delayedRefresh.restart()
            }
        }
    }


    // ============================================================
    // DELAYED SYNC
    // ============================================================

    Timer {
        id: delayedRefresh

        interval: 250
        repeat: false

        onTriggered:
            root.refresh()
    }


    // ============================================================
    // EXTERNAL STATE SYNC
    // ============================================================

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
