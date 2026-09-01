import QtQuick
import Quickshell
import Quickshell.Io


Item {
    id: root


    // ============================================================
    // PUBLIC STATE
    // ============================================================

    property bool enabled: false

    property string mode: "manual"

    property int temperature: 6500

    property int manualTemperature: 4500
    property int wallpaperTemperature: 5000
    property int nightTemperature: 3500

    property int minimumTemperature: 2500
    property int maximumTemperature: 6500

    property bool loading: false
    property bool changing: false


    readonly property bool manualMode:
        mode === "manual"

    readonly property bool wallpaperMode:
        mode === "wallpaper"

    readonly property bool nightMode:
        mode === "night"


    readonly property int activeTemperature: {
        if (mode === "wallpaper")
            return wallpaperTemperature

        if (mode === "night")
            return nightTemperature

        return manualTemperature
    }


    readonly property string nexad:
        Quickshell.env("HOME")
        + "/.config/nexa/rust/target/release/nexad"


    // ============================================================
    // INTERNAL
    // ============================================================

    property int pendingTemperature: manualTemperature
    property string pendingMode: ""


    // ============================================================
    // STATE PARSER
    // ============================================================

    function applyData(data) {
        root.enabled =
            Boolean(data.enabled)

        root.mode =
            data.mode ?? "manual"

        root.temperature =
            Number(
                data.temperature ?? 6500
            )

        root.manualTemperature =
            Number(
                data.manualTemperature ?? 4500
            )

        root.wallpaperTemperature =
            Number(
                data.wallpaperTemperature ?? 5000
            )

        root.nightTemperature =
            Number(
                data.nightTemperature ?? 3500
            )

        root.minimumTemperature =
            Number(
                data.minTemperature ?? 2500
            )

        root.maximumTemperature =
            Number(
                data.maxTemperature ?? 6500
            )
    }


    // ============================================================
    // REFRESH
    // ============================================================

    function refresh() {
        if (infoProcess.running)
            return

        loading = true
        infoProcess.running = true
    }


    // ============================================================
    // ENABLE / DISABLE
    // ============================================================

    function toggle() {
        if (toggleProcess.running)
            return

        changing = true
        toggleProcess.running = true
    }


    function enable() {
        if (enableProcess.running)
            return

        changing = true
        enableProcess.running = true
    }


    function disable() {
        if (disableProcess.running)
            return

        changing = true
        disableProcess.running = true
    }


    // ============================================================
    // MODE
    // ============================================================

    function setMode(newMode) {
        if (
            newMode !== "manual"
            && newMode !== "wallpaper"
            && newMode !== "night"
        ) {
            return
        }

        if (modeProcess.running)
            return

        pendingMode = newMode

        changing = true

        modeProcess.command = [
            nexad,
            "screenTemp",
            "mode",
            newMode
        ]

        modeProcess.running = true
    }


    // ============================================================
    // TEMPERATURE
    // ============================================================

    function setTemperature(value) {
        let target =
            Math.round(value)

        target =
            Math.max(
                minimumTemperature,
                Math.min(
                    maximumTemperature,
                    target
                )
            )


        // Wallpaper mode is generated from the wallpaper.
        if (wallpaperMode)
            return


        pendingTemperature =
            target


        /*
         * Optimistic UI update.
         */
        if (nightMode)
            nightTemperature = target
        else
            manualTemperature = target


        temperatureThrottle.restart()
    }


    function setTemperatureImmediate(value) {
        let target =
            Math.round(value)

        target =
            Math.max(
                minimumTemperature,
                Math.min(
                    maximumTemperature,
                    target
                )
            )


        if (wallpaperMode)
            return


        pendingTemperature =
            target

        temperatureThrottle.stop()

        runTemperatureChange()
    }


    function runTemperatureChange() {
        if (temperatureProcess.running)
            return


        changing = true


        if (nightMode) {
            temperatureProcess.command = [
                nexad,
                "screenTemp",
                "night-set",
                pendingTemperature.toString()
            ]
        } else {
            temperatureProcess.command = [
                nexad,
                "screenTemp",
                "set",
                pendingTemperature.toString()
            ]
        }


        temperatureProcess.running = true
    }


    // ============================================================
    // INFO PROCESS
    // ============================================================

    Process {
        id: infoProcess

        command: [
            root.nexad,
            "screenTemp",
            "info"
        ]


        stdout: StdioCollector {
            onStreamFinished: {
                root.loading = false

                try {
                    root.applyData(
                        JSON.parse(text)
                    )
                } catch (error) {
                    console.warn(
                        "[NEXA NightLight] info parse failed:",
                        error,
                        text
                    )
                }
            }
        }
    }


    // ============================================================
    // TOGGLE
    // ============================================================

    Process {
        id: toggleProcess

        command: [
            root.nexad,
            "screenTemp",
            "toggle"
        ]


        stdout: StdioCollector {
            onStreamFinished: {
                root.changing = false

                try {
                    root.applyData(
                        JSON.parse(text)
                    )
                } catch (error) {
                    console.warn(
                        "[NEXA NightLight] toggle parse failed:",
                        error,
                        text
                    )
                }

                delayedRefresh.restart()
            }
        }
    }


    // ============================================================
    // ENABLE
    // ============================================================

    Process {
        id: enableProcess

        command: [
            root.nexad,
            "screenTemp",
            "enable"
        ]


        stdout: StdioCollector {
            onStreamFinished: {
                root.changing = false

                try {
                    root.applyData(
                        JSON.parse(text)
                    )
                } catch (error) {
                    console.warn(
                        "[NEXA NightLight] enable parse failed:",
                        error,
                        text
                    )
                }

                delayedRefresh.restart()
            }
        }
    }


    // ============================================================
    // DISABLE
    // ============================================================

    Process {
        id: disableProcess

        command: [
            root.nexad,
            "screenTemp",
            "disable"
        ]


        stdout: StdioCollector {
            onStreamFinished: {
                root.changing = false

                try {
                    root.applyData(
                        JSON.parse(text)
                    )
                } catch (error) {
                    console.warn(
                        "[NEXA NightLight] disable parse failed:",
                        error,
                        text
                    )
                }

                delayedRefresh.restart()
            }
        }
    }


    // ============================================================
    // MODE PROCESS
    // ============================================================

    Process {
        id: modeProcess


        stdout: StdioCollector {
            onStreamFinished: {
                root.changing = false

                try {
                    root.applyData(
                        JSON.parse(text)
                    )
                } catch (error) {
                    console.warn(
                        "[NEXA NightLight] mode parse failed:",
                        error,
                        text
                    )
                }

                root.pendingMode = ""

                delayedRefresh.restart()
            }
        }
    }


    // ============================================================
    // TEMPERATURE PROCESS
    // ============================================================

    Process {
        id: temperatureProcess


        stdout: StdioCollector {
            onStreamFinished: {
                root.changing = false

                try {
                    root.applyData(
                        JSON.parse(text)
                    )
                } catch (error) {
                    console.warn(
                        "[NEXA NightLight] temperature parse failed:",
                        error,
                        text
                    )
                }

                delayedRefresh.restart()
            }
        }
    }


    // ============================================================
    // SLIDER THROTTLE
    // ============================================================

    Timer {
        id: temperatureThrottle

        interval: 80
        repeat: false

        onTriggered:
            root.runTemperatureChange()
    }


    // ============================================================
    // DELAYED REFRESH
    // ============================================================

    Timer {
        id: delayedRefresh

        interval: 250
        repeat: false

        onTriggered:
            root.refresh()
    }


    // ============================================================
    // EXTERNAL STATE SYNC
    // ============================================================

    Timer {
        interval: 3000
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
