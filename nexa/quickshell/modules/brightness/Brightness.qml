import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    // ============================================================
    // STATE
    // ============================================================

    property int brightness: 1

    property int current: 0
    property int maximum: 0

    property bool loading: false

    property int pendingBrightness: 1

    readonly property string nexad:
        Quickshell.env("HOME")
        + "/.config/nexa/rust/target/release/nexad"


    // ============================================================
    // REFRESH
    // ============================================================

    function refresh() {
        if (brightnessInfo.running)
            return

        loading = true
        brightnessInfo.running = true
    }


    // ============================================================
    // SET BRIGHTNESS
    // ============================================================

    function setBrightness(value) {
        const clamped =
            Math.max(
                1,
                Math.min(
                    100,
                    Math.round(value)
                )
            )

        brightness = clamped
        pendingBrightness = clamped

        brightnessTimer.restart()
    }


    function setBrightnessImmediate(value) {
        const clamped =
            Math.max(
                1,
                Math.min(
                    100,
                    Math.round(value)
                )
            )

        brightness = clamped
        pendingBrightness = clamped

        brightnessTimer.stop()

        Quickshell.execDetached([
            nexad,
            "brightness",
            "set",
            clamped.toString()
        ])
    }


    // ============================================================
    // INFO PROCESS
    // ============================================================

    Process {
        id: brightnessInfo

        command: [
            root.nexad,
            "brightness",
            "info"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                root.loading = false

                try {
                    const data =
                        JSON.parse(text)

                    root.brightness =
                        Number(
                            data.brightness ?? 1
                        )

                    root.current =
                        Number(
                            data.current ?? 0
                        )

                    root.maximum =
                        Number(
                            data.maximum ?? 0
                        )

                } catch (error) {
                    console.warn(
                        "[NEXA Brightness] Failed to parse brightness:",
                        error,
                        text
                    )
                }
            }
        }
    }


    // ============================================================
    // SLIDER THROTTLE
    // ============================================================

    Timer {
        id: brightnessTimer

        interval: 70
        repeat: false

        onTriggered: {
            Quickshell.execDetached([
                root.nexad,
                "brightness",
                "set",
                root.pendingBrightness.toString()
            ])
        }
    }


    // ============================================================
    // LIVE STATE
    // ============================================================

    Timer {
        interval: 2500
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
