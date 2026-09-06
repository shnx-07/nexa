import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    // ============================================================
    // STATE
    // ============================================================

    property string filter: "off"

    readonly property bool enabled: filter !== "off"

    readonly property var available: [
        "off",
        "chroma",
        "grayscale",
        "hdr-boost",
        "high-contrast",
        "invert",
        "sepia",
        "paper-mode"
    ]

    readonly property string label: {
        switch (filter) {
        case "chroma": return "Chroma"
        case "grayscale": return "Grayscale"
        case "hdr-boost": return "HDR Boost"
        case "high-contrast": return "High Contrast"
        case "invert": return "Invert Colors"
        case "sepia": return "Sepia"
        case "paper-mode": return "Paper Mode"
        default: return "Off"
        }
    }

    readonly property string nexad:
        Quickshell.env("HOME") + "/.config/nexa/rust/target/release/nexad"

    // ============================================================
    // ACTIONS
    // ============================================================

    function setFilter(name) {
        if (!name || name === filter) return
        if (name === "off") {
            off()
            return
        }

        filter = name
        cmdProcess.command = [nexad, "screenFilter", "set", name]
        cmdProcess.running = true
    }

    function off() {
        if (filter === "off") return
        filter = "off"
        cmdProcess.command = [nexad, "screenFilter", "off"]
        cmdProcess.running = true
    }

    function toggle(name) {
        if (filter === name) {
            off()
        } else {
            setFilter(name)
        }
    }

    function refresh() {
        if (infoProcess.running) return
        infoProcess.running = true
    }

    // ============================================================
    // PROCESSES
    // ============================================================

    Process {
        id: cmdProcess
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text)
                    if (data && data.filter !== undefined) {
                        root.filter = data.filter
                    }
                } catch (e) {}
            }
        }
    }

    Process {
        id: infoProcess
        command: [root.nexad, "screenFilter", "info"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text)
                    if (data && data.filter !== undefined) {
                        root.filter = data.filter
                    }
                } catch (e) {}
            }
        }
    }

    onVisibleChanged: {
        if (root.visible) {
            root.refresh()
        }
    }

    Component.onCompleted: {
        root.refresh()
    }
}
