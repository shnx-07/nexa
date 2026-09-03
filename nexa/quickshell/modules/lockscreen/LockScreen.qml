import QtQuick
import Quickshell.Io
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland


Item {
    id: root

    // ============================================================
    // PUBLIC STATE
    // ============================================================

    readonly property bool locked:
        sessionLock.locked

    readonly property bool secure:
        sessionLock.secure


    property bool previewOpen: false

    // ============================================================
    // LOCK CONTROL
    // ============================================================
    IpcHandler {
        target: "lockScreen"

        function lock(): void {
            root.lock()
        }

        function openPreview(): void {
            root.previewOpen = true
        }

        function closePreview(): void {
            root.previewOpen = false
        }
    }
    function lock() {
        if (sessionLock.locked) {
            console.log(
                "NEXA lockscreen: already locked"
            )

            return
        }

        console.log(
            "NEXA lockscreen: lock requested"
        )

        sessionLock.locked = true
    }


    function unlock() {
        if (!sessionLock.locked)
            return

        console.log(
            "NEXA lockscreen: releasing session"
        )

        sessionLock.locked = false
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

                LockSurface {
                    id: lockSurface

                    anchors.fill:
                        parent

                    onAuthenticationSucceeded: {
                        console.log(
                            "NEXA lockscreen: PAM accepted"
                        )

                        root.unlock()
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
        }


        onSecureChanged: {
            console.log(
                "NEXA lockscreen secure:",
                secure
            )
        }
    }

    // ============================================================
    // PREVIEW WINDOW (SAFE TESTING WITHOUT LOCKOUT)
    // ============================================================

    PanelWindow {
        id: previewWindow
        visible: root.previewOpen
        color: "#000000"
        exclusionMode: ExclusionMode.Ignore
        aboveWindows: true
        focusable: true
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        LockSurface {
            anchors.fill: parent
            onAuthenticationSucceeded: {
                root.previewOpen = false
            }
        }
    }
}
