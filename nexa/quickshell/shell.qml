//@ pragma IconTheme breeze-dark
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "bar"
import "island"
import "modules/lockscreen" as LockScreenModule
import "modules/nightlight" as NightLightModule
import "wallpaper" as WallpaperModule
import "services" as Services

ShellRoot {
    Component.onCompleted: {
        Services.DesktopTheme.manage = true
        // Ensure Battery service is initialized at startup
        const _ = Services.Battery.percentage
    }

    Connections {
        target: Quickshell
        function onReloadCompleted() {
            Quickshell.inhibitReloadPopup()
        }
    }

    NightLightModule.NightLightScheduler {}
    WallpaperModule.WallpaperSlideshowScheduler {
        isLocked: lockScreen.locked
    }

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

    Process {
        id: desktopAppsIndexer

        command: [
            Quickshell.env("HOME")
            + "/.config/nexa/rust/target/release/nexad",
            "appLauncher",
            "index"
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
        function open() {
            if (!workspaceLoader.active) {
                workspaceLoader.active = true
            } else if (workspaceLoader.item) {
                workspaceLoader.item.openManager()
            }
        }
        function close() {
            if (workspaceLoader.item) {
                workspaceLoader.item.closeManager()
            }
        }
        function toggle() {
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
            } else if (wallpaperLoader.item) {
                wallpaperLoader.item.visible = !wallpaperLoader.item.visible
                if (!wallpaperLoader.item.visible) {
                    wallpaperLoader.active = false
                }
            } else {
                wallpaperLoader.active = false
            }
        }
    }

    IpcHandler {
        target: "wallpaper"
        function toggle() {
            if (!wallpaperLoader.active) {
                wallpaperLoader.active = true
            } else if (wallpaperLoader.item) {
                wallpaperLoader.item.visible = !wallpaperLoader.item.visible
                if (!wallpaperLoader.item.visible) {
                    wallpaperLoader.active = false
                }
            } else {
                wallpaperLoader.active = false
            }
        }
        function open() {
            if (!wallpaperLoader.active) {
                wallpaperLoader.active = true
            } else if (wallpaperLoader.item) {
                wallpaperLoader.item.visible = true
                wallpaperLoader.item.forceActiveFocus()
            }
        }
        function close() {
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

        function open() {
            if (!clipboardLoader.active) {
                clipboardLoader.active = true
            } else if (clipboardLoader.item) {
                clipboardLoader.item.openClipboard()
            }
        }

        function close() {
            if (clipboardLoader.item) {
                clipboardLoader.item.closeClipboard()
            }
        }

        function toggle() {
            if (!clipboardLoader.active) {
                clipboardLoader.active = true
            } else if (clipboardLoader.item) {
                clipboardLoader.item.toggleClipboard()
            }
        }
    }

    Timer {
        id: settingsPreloadTimer
        interval: 1500
        running: true
        repeat: false
        onTriggered: {
            if (!settingsLoader.active) {
                settingsLoader.active = true
            }
        }
    }

    Loader {
        id: settingsLoader
        active: false
        source: "modules/settings/SettingsWindow.qml"
        property var pendingAction: null

        onLoaded: {
            if (item && pendingAction) {
                pendingAction()
                pendingAction = null
            }
        }
    }

    IpcHandler {
        target: "settings"

        function open(tabName: string) {
            settingsPreloadTimer.stop()
            if (settingsLoader.item) {
                settingsLoader.item.openWindow(tabName || "")
            } else {
                settingsLoader.pendingAction = function() {
                    if (settingsLoader.item) settingsLoader.item.openWindow(tabName || "")
                }
                settingsLoader.active = true
            }
        }

        function openTab(tabName: string) {
            open(tabName)
        }

        function close() {
            if (settingsLoader.item) {
                settingsLoader.item.closeWindow()
            }
        }

        function toggle() {
            settingsPreloadTimer.stop()
            if (settingsLoader.item) {
                settingsLoader.item.toggleWindow()
            } else {
                settingsLoader.pendingAction = function() {
                    if (settingsLoader.item) settingsLoader.item.openWindow()
                }
                settingsLoader.active = true
            }
        }
    }

    IpcHandler {
        target: "lockSettings"

        function open(tabName: string) {
            settingsPreloadTimer.stop()
            if (settingsLoader.item) {
                settingsLoader.item.openWindow(tabName || "lock")
            } else {
                settingsLoader.pendingAction = function() {
                    if (settingsLoader.item) settingsLoader.item.openWindow(tabName || "lock")
                }
                settingsLoader.active = true
            }
        }

        function openTab(tabName: string) {
            open(tabName)
        }

        function close() {
            if (settingsLoader.item) {
                settingsLoader.item.closeWindow()
            }
        }

        function toggle() {
            settingsPreloadTimer.stop()
            if (settingsLoader.item) {
                settingsLoader.item.toggleWindow()
            } else {
                settingsLoader.pendingAction = function() {
                    if (settingsLoader.item) settingsLoader.item.openWindow("lock")
                }
                settingsLoader.active = true
            }
        }
    }

    LockScreenModule.LockScreen {
        id: lockScreen
    }
}
