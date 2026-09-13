import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    readonly property string nexad:
        Quickshell.env("HOME") + "/.config/nexa/rust/target/release/nexad"

    readonly property string configPath:
        Quickshell.env("HOME") + "/.config/nexa/config/slideshow.json"

    property bool enabled: false
    property bool paused: false
    property string intervalStr: "10m"
    property string typeFilter: "All"
    property string applyTarget: "Background"

    function intervalToMs(str) {
        switch (str) {
            case "5m":  return 5 * 60 * 1000
            case "10m": return 10 * 60 * 1000
            case "15m": return 15 * 60 * 1000
            case "30m": return 30 * 60 * 1000
            case "1h":  return 60 * 60 * 1000
            default:    return 10 * 60 * 1000
        }
    }

    function triggerNext() {
        if (!nextProcess.running) {
            nextProcess.running = true
        }
        cycleTimer.restart()
    }

    function parseConfig(raw) {
        try {
            const data = JSON.parse(raw)
            root.enabled = !!data.enabled
            root.paused = !!data.paused
            root.intervalStr = data.interval || "10m"
            root.typeFilter = data.type_filter || "All"
            root.applyTarget = data.apply_target || "Background"

            const targetMs = root.intervalToMs(root.intervalStr)
            if (cycleTimer.interval !== targetMs) {
                cycleTimer.interval = targetMs
            }

            if (root.enabled && !root.paused) {
                if (!cycleTimer.running) {
                    cycleTimer.start()
                }
            } else {
                cycleTimer.stop()
            }
        } catch (e) {
            console.log("[WallpaperSlideshow] Error parsing config:", e)
        }
    }

    FileView {
        id: configFile
        path: root.configPath
        watchChanges: true
        onFileChanged: {
            if (configFile.text()) {
                root.parseConfig(configFile.text())
            }
        }
        onLoaded: {
            if (configFile.text()) {
                root.parseConfig(configFile.text())
            }
        }
    }

    Process {
        id: nextProcess
        command: [root.nexad, "wallpaper", "slideshow", "next"]
        stdout: StdioCollector {}
    }

    Timer {
        id: cycleTimer
        interval: root.intervalToMs(root.intervalStr)
        repeat: true
        running: false
        onTriggered: {
            if (root.enabled && !root.paused) {
                root.triggerNext()
            }
        }
    }

    Component.onCompleted: {
        Qt.callLater(function() {
            if (configFile.text()) {
                root.parseConfig(configFile.text())
            }
        })
    }

    IpcHandler {
        target: "wallpaperSlideshow"

        function next(): void {
            root.triggerNext()
        }

        function reload(): void {
            if (configFile.text()) {
                root.parseConfig(configFile.text())
            }
        }
    }
}

