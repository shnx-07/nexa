//@ pragma IconTheme breeze-dark
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "wallpaper" as Wallpaper
import "bar"
import "island"
import "modules/clipboard" as Clipboard
import "modules/lockscreen" as LockScreenModule
import "modules/workspace" as WorkspaceModule
import "modules/nightlight" as NightLightModule

ShellRoot {
    NightLightModule.NightLightScheduler {}

    Process {
        id: notificationDaemonStartup

        command: [
            "sh",
            "-c",
            "busctl --user status org.freedesktop.Notifications >/dev/null 2>&1 "
            + "|| exec \"$HOME/.config/nexa/rust/target/release/nexad\" notifications daemon"
        ]

        running: true
    }

    Process {
        id: settingsStateRestore

        command: [
            Quickshell.env("HOME")
            + "/.config/nexa/rust/target/release/nexad",
            "state",
            "restore"
        ]

        running: true
    }
   
    Loader {
        id: workspaceLoader
        active: false
        source: "modules/workspace/WorkspaceManager.qml"
        onLoaded: {
            if (item) {
                item.openManager()
            }
        }
    }

    IpcHandler {
        target: "workspaceManager"
        function open(): void {
            if (!workspaceLoader.active) {
                workspaceLoader.active = true
            } else if (workspaceLoader.item) {
                workspaceLoader.item.openManager()
            }
        }
        function close(): void {
            if (workspaceLoader.item) {
                workspaceLoader.item.closeManager()
            }
        }
        function toggle(): void {
            if (!workspaceLoader.active) {
                workspaceLoader.active = true
            } else if (workspaceLoader.item) {
                workspaceLoader.item.toggleManager()
            }
        }
    }
    

    TopBar {}

    Island {}

    Loader {
        id: wallpaperLoader
        active: false
        source: "wallpaper/WallpaperView.qml"
        onLoaded: {
            if (item) {
                item.visible = true
            }
        }
    }

    GlobalShortcut {
        appid: "nexa"
        name: "wallpaper"
        description: "Toggle NEXA wallpaper picker"

        onPressed: {
            if (!wallpaperLoader.active) {
                wallpaperLoader.active = true
            } else {
                if (wallpaperLoader.item) {
                    wallpaperLoader.item.visible = false
                }
                wallpaperLoader.active = false
            }
        }
    }

    IpcHandler {
        target: "wallpaper"
        function toggle(): void {
            if (!wallpaperLoader.active) {
                wallpaperLoader.active = true
            } else {
                if (wallpaperLoader.item) {
                    wallpaperLoader.item.visible = false
                }
                wallpaperLoader.active = false
            }
        }
        function open(): void {
            wallpaperLoader.active = true
        }
        function close(): void {
            if (wallpaperLoader.item) {
                wallpaperLoader.item.visible = false
            }
            wallpaperLoader.active = false
        }
    }

    Item {
        id: wallpaperView
        visible: false
        onVisibleChanged: {
            if (visible) {
                wallpaperLoader.active = true
            }
        }
        function forceActiveFocus() {
            if (wallpaperLoader.item) {
                wallpaperLoader.item.forceActiveFocus()
            }
        }
    }

    Connections {
        target: wallpaperLoader.item
        ignoreUnknownSignals: true
        function onVisibleChanged() {
            if (wallpaperLoader.item && !wallpaperLoader.item.visible) {
                wallpaperLoader.active = false
                wallpaperView.visible = false
            }
        }
    }

    Loader {
        id: clipboardLoader
        active: false
        source: "modules/clipboard/Clipboard.qml"
        onLoaded: {
            if (item) {
                item.openClipboard()
            }
        }
    }

    Connections {
        target: clipboardLoader.item
        ignoreUnknownSignals: true
        function onWindowAliveChanged() {
            if (clipboardLoader.item && !clipboardLoader.item.windowAlive) {
                clipboardLoader.active = false
            }
        }
    }

    IpcHandler {
        target: "clipboard"

        function open(): void {
            if (!clipboardLoader.active) {
                clipboardLoader.active = true
            } else if (clipboardLoader.item) {
                clipboardLoader.item.openClipboard()
            }
        }

        function close(): void {
            if (clipboardLoader.item) {
                clipboardLoader.item.closeClipboard()
            }
        }

        function toggle(): void {
            if (!clipboardLoader.active) {
                clipboardLoader.active = true
            } else if (clipboardLoader.item) {
                clipboardLoader.item.toggleClipboard()
            }
        }
    }

    LockScreenModule.LockScreen {}
}
