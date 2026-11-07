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
    property double lastChangedTime: 0

    property bool isLocked: false

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
        if (Boolean(root.isLocked)) {
            console.log("[WallpaperSlideshow] Screen is locked, postponing wallpaper change")
            return
        }

        console.log("[WallpaperSlideshow] Triggering next wallpaper via nexad")
        root.lastChangedTime = Date.now()
        Quickshell.execDetached([root.nexad, "wallpaper", "slideshow", "next"])
    }

    function parseConfig(raw) {
        if (!raw || raw.trim() === "") return
        try {
            const data = JSON.parse(raw)
            root.enabled = !!data.enabled
            root.paused = !!data.paused
            root.intervalStr = data.interval || "10m"
            root.typeFilter = data.type_filter || "All"
            root.applyTarget = data.apply_target || "Background"

            if (data.last_changed && Number(data.last_changed) > 0) {
                root.lastChangedTime = Number(data.last_changed) * 1000
            } else if (root.lastChangedTime === 0) {
                root.lastChangedTime = Date.now()
            }

            console.log("[WallpaperSlideshow] Config loaded: enabled=" + root.enabled +
                        " paused=" + root.paused + " interval=" + root.intervalStr +
                        " lastChanged=" + new Date(root.lastChangedTime).toLocaleTimeString())
        } catch (e) {
            console.warn("[WallpaperSlideshow] Error parsing config:", e)
        }
    }

    FileView {
        id: configFile
        path: root.configPath
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            if (configFile.text()) {
                root.parseConfig(configFile.text())
            }
        }
    }

    // Wall-clock time ticker: retired in favor of native Rust daemon (nexad wallpaper slideshow daemon)
    Timer {
        id: tickerTimer
        interval: 5000
        repeat: true
        running: false
    }

    // Sync screen lock state to /tmp/nexa-locked for Rust slideshow daemon
    onIsLockedChanged: {
        if (isLocked) {
            Quickshell.execDetached(["touch", "/tmp/nexa-locked"])
        } else {
            Quickshell.execDetached(["rm", "-f", "/tmp/nexa-locked"])
        }
    }

    Component.onCompleted: {
        configFile.reload()
        Qt.callLater(function() {
            if (configFile.text()) {
                root.parseConfig(configFile.text())
            }
        })
    }

    IpcHandler {
        target: "wallpaperSlideshow"

        function next() {
            root.triggerNext()
        }

        function reload() {
            configFile.reload()
        }
    }
}
