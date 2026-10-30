import QtQuick
import Quickshell.Io
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../lockthemes" as LockThemesModule
import "../../services" as Services


Item {
    id: root

    // ============================================================
    // PUBLIC STATE
    // ============================================================

    readonly property bool locked:
        sessionLock.locked

    readonly property bool secure:
        sessionLock.secure

    readonly property string runtimeDir: {
        const xdg = Quickshell.env("XDG_RUNTIME_DIR")
        return (xdg && xdg.trim() !== "") ? (xdg + "/nexa") : ("/run/user/" + Quickshell.env("UID") + "/nexa")
    }
    readonly property string lockFlag: runtimeDir + "/locked"
    readonly property string pendingFlag: runtimeDir + "/restart-pending"

    property bool previewOpen: false
    property string activeThemeId: Services.LockScreen.current

    property real lastLockTime: 0

    LockThemesModule.ScreenCapture {
        id: capture
    }

    LockThemesModule.LockContext {
        id: lockCtx
        onReleased: {
            if (root.activeThemeId !== "nexa") {
                root.unlock()
            }
        }
    }

    // ============================================================
    // LOCK CONTROL
    // ============================================================
    IpcHandler {
        target: "lockScreen"

        function lock() {
            root.lock()
        }

        function openPreview() {
            root.previewOpen = true
        }

        function closePreview() {
            root.previewOpen = false
        }
    }
    function lock() {
        const now = Date.now()
        if (now - lastLockTime < 400) {
            console.log("NEXA lockscreen: ignoring rapid duplicate lock request")
            return
        }
        lastLockTime = now

        if (sessionLock.locked) {
            console.log("NEXA lockscreen: already locked")
            return
        }

        console.log("NEXA lockscreen: lock requested")

        activeThemeId = Services.LockScreen.pick()
        Services.LockScreen.remember(activeThemeId)
        if (activeThemeId !== "nexa") {
            lockCtx.configure(Services.LockScreen.theme(activeThemeId))
            lockCtx.begin()
        }

        Quickshell.execDetached(["mkdir", "-p", root.runtimeDir])
        Quickshell.execDetached(["touch", root.lockFlag])
        Quickshell.execDetached([Quickshell.env("HOME") + "/.config/nexa/rust/target/release/nexad", "sound", "play", "lock"])
        sessionLock.locked = true
    }


    function unlock() {
        if (!sessionLock.locked)
            return

        console.log(
            "NEXA lockscreen: releasing session"
        )

        Quickshell.execDetached([Quickshell.env("HOME") + "/.config/nexa/rust/target/release/nexad", "sound", "play", "unlock"])
        Quickshell.execDetached(["rm", "-f", root.lockFlag])
        sessionLock.locked = false

        // Check if monitor configuration changed while session was locked
        Quickshell.execDetached([
            "sh", "-c",
            "if [ -f " + root.pendingFlag + " ]; then "
            + "rm -f " + root.pendingFlag + "; "
            + "sleep 0.2; "
            + "$HOME/.config/nexa/scripts/nexa-restart.sh && $HOME/.config/nexa/rust/target/release/nexad wallpaper restore; "
            + "fi"
        ])
    }



    // ============================================================
    // HYPRLAND GLOBAL SHORTCUT
    //
    // hyprctl dispatch global nexa:lock
    // ============================================================

    GlobalShortcut {
        appid: "nexa"
        name: "lock"

        description:
            "Open NEXA lock screen"

        onPressed: {
            root.lock()
        }
    }


    // ============================================================
    // REAL WAYLAND SESSION LOCK
    // ============================================================

    WlSessionLock {
        id: sessionLock

        /*
         * CRITICAL:
         *
         * Never start as true.
         *
         * Quickshell reload/recompile therefore starts unlocked.
         * Only root.lock() may change this to true.
         */
        locked: false


        // ========================================================
        // ONE SURFACE IS CREATED PER MONITOR
        // ========================================================

        surface: Component {
            WlSessionLockSurface {
                id: lockWindow

                color: "black"

                Loader {
                    id: surfaceLoader
                    anchors.fill: parent
                    sourceComponent: (root.activeThemeId !== "nexa")
                        ? themeHostComponent
                        : nexaSurfaceComponent
                }

                Component {
                    id: themeHostComponent
                    LockThemesModule.ThemeHost {
                        anchors.fill: parent
                        ctx: lockCtx
                        themeId: root.activeThemeId
                        shot: capture.urlFor(lockWindow.screen)
                        shown: lockWindow.visible
                    }
                }

                Component {
                    id: nexaSurfaceComponent
                    LockSurface {
                        id: lockSurface
                        anchors.fill: parent
                        onAuthenticationSucceeded: {
                            root.unlock()
                        }
                    }
                }
            }
        }


        // ========================================================
        // DEBUG
        // ========================================================

        onLockedChanged: {
            console.log(
                "NEXA lockscreen locked:",
                locked
            )
            if (locked) {
                Quickshell.execDetached(["mkdir", "-p", root.runtimeDir])
                Quickshell.execDetached(["touch", root.lockFlag])
            } else {
                Quickshell.execDetached(["rm", "-f", root.lockFlag])
                Quickshell.execDetached([
                    "sh", "-c",
                    "if [ -f " + root.pendingFlag + " ]; then "
                    + "rm -f " + root.pendingFlag + "; "
                    + "sleep 0.2; "
                    + "$HOME/.config/nexa/scripts/nexa-restart.sh && $HOME/.config/nexa/rust/target/release/nexad wallpaper restore; "
                    + "fi"
                ])
            }
        }


        onSecureChanged: {
            console.log(
                "NEXA lockscreen secure:",
                secure
            )
        }

        Component.onDestruction: {
            if (locked) {
                console.log("NEXA lockscreen: releasing session lock during destruction")
                locked = false
            }
        }
    }

    Component.onCompleted: {
        Quickshell.execDetached(["rm", "-f", root.lockFlag, root.pendingFlag])
    }

    Component.onDestruction: {
        Quickshell.execDetached(["rm", "-f", root.lockFlag])
    }

    // ============================================================
    // PREVIEW WINDOW (SAFE TESTING WITHOUT LOCKOUT)
    // ============================================================

    PanelWindow {
        id: previewWindow
        visible: root.previewOpen
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        aboveWindows: true
        focusable: true
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        Loader {
            id: previewLoader
            anchors.fill: parent
            active: root.previewOpen
            source: "LockSurface.qml"
            onLoaded: {
                if (item) {
                    item.authenticationSucceeded.connect(() => {
                        root.previewOpen = false
                    })
                }
            }
        }
    }
}

