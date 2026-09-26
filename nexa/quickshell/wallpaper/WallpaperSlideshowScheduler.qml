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

    // Wall-clock time ticker: runs constantly every 5 seconds without relying on dynamic running bindings
    Timer {
        id: tickerTimer
        interval: 5000 // 5 seconds
        repeat: true
        running: true
        onTriggered: {
            if (!root.enabled || root.paused || Boolean(root.isLocked)) return

            const now = Date.now()
            const intervalMs = root.intervalToMs(root.intervalStr)
            const elapsed = now - root.lastChangedTime

            if (elapsed >= intervalMs) {
                console.log("[WallpaperSlideshow] Time elapsed (" + Math.round(elapsed / 1000) + "s >= " + Math.round(intervalMs / 1000) + "s), changing wallpaper")
                root.triggerNext()
            }
        }
    }

    // When screen unlocks, immediately check if elapsed time passed during lock
    onIsLockedChanged: {
        if (!isLocked && root.enabled && !root.paused) {
            const now = Date.now()
            const intervalMs = root.intervalToMs(root.intervalStr)
            if (now - root.lastChangedTime >= intervalMs) {
                console.log("[WallpaperSlideshow] Screen unlocked and interval elapsed, changing wallpaper immediately")
                root.triggerNext()
            }
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

        function next(): void {
            root.triggerNext()
        }

        function reload(): void {
            configFile.reload()
        }
    }
}
