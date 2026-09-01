import QtQuick

import Quickshell
import Quickshell.Io


Item {
    id: root

    property bool enabled: false
    property bool loading: false
    property bool changing: false

    readonly property string nexadPath:
        Quickshell.env("HOME")
        + "/.config/nexa/rust/target/release/nexad"


    // ============================================================
    // DATA
    // ============================================================

    function applyData(payload) {
        root.enabled =
            payload.enabled === true
    }


    // ============================================================
    // REFRESH
    // ============================================================

    function refresh() {
        if (infoProcess.running)
            return

        root.loading = true

        infoProcess.exec([
            root.nexadPath,
            "notifications",
            "dnd",
            "info"
        ])
    }


    // ============================================================
    // TOGGLE
    // ============================================================

    function toggle() {
        if (changing)
            return

        root.changing = true

        toggleProcess.exec([
            root.nexadPath,
            "notifications",
            "dnd",
            "toggle"
        ])
    }


    // ============================================================
    // INFO
    // ============================================================

    Process {
        id: infoProcess

        stdout: StdioCollector {
            onStreamFinished: {
                root.loading = false

                try {
                    root.applyData(
                        JSON.parse(
                            this.text
                        )
                    )
                } catch (error) {
                    console.error(
                        "[DND:info]",
                        error
                    )
                }
            }
        }
    }


    // ============================================================
    // TOGGLE PROCESS
    // ============================================================

    Process {
        id: toggleProcess

        stdout: StdioCollector {
            onStreamFinished: {
                root.changing = false

                try {
                    root.applyData(
                        JSON.parse(
                            this.text
                        )
                    )
                } catch (error) {
                    console.error(
                        "[DND:toggle]",
                        error
                    )
                }

                delayedRefresh.restart()
            }
        }
    }


    Timer {
        id: delayedRefresh

        interval: 200
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
