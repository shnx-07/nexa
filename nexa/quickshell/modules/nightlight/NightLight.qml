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

    property string scheduleMode: "off"
    property string scheduleStart: "22:00"
    property string scheduleEnd: "06:00"
    property string sunriseTime: "06:00"
    property string sunsetTime: "18:30"

    readonly property string scheduleLabel: {
        if (scheduleMode === "sunset")
            return "Sunset–Sunrise"
        if (scheduleMode === "custom")
            return formatTimeDisplay(scheduleStart) + " – " + formatTimeDisplay(scheduleEnd)
        return "Schedule: Off"
    }

    function formatTimeDisplay(t) {
        if (!t) return ""
        let parts = t.split(":")
        if (parts.length < 2) return t
        let h = parseInt(parts[0], 10)
        let m = parts[1]
        let ampm = h >= 12 ? "PM" : "AM"
        let h12 = h % 12
        if (h12 === 0) h12 = 12
        return h12 + ":" + m + " " + ampm
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

        root.scheduleMode =
            data.scheduleMode ?? "off"

        root.scheduleStart =
            data.scheduleStart ?? "22:00"

        root.scheduleEnd =
            data.scheduleEnd ?? "06:00"

        root.sunriseTime =
            data.sunrise ?? "06:00"

        root.sunsetTime =
            data.sunset ?? "18:30"
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

    // ============================================================
    // SCHEDULE FUNCTIONS & AUTOMATION
    // ============================================================

    function adjustTime(timeStr, deltaH, deltaM) {
        let parts = (timeStr || "00:00").split(":")
        let h = parseInt(parts[0], 10) || 0
        let m = parseInt(parts[1], 10) || 0

        let total = (h * 60 + m + deltaH * 60 + deltaM) % 1440
        if (total < 0) total += 1440

        let newH = Math.floor(total / 60)
        let newM = total % 60

        let padH = newH < 10 ? "0" + newH : "" + newH
        let padM = newM < 10 ? "0" + newM : "" + newM
        return padH + ":" + padM
    }

    function adjustScheduleHour(target, delta) {
        if (target === "start") {
            let newStart = adjustTime(scheduleStart, delta, 0)
            setSchedule("custom", newStart, scheduleEnd)
        } else if (target === "end") {
            let newEnd = adjustTime(scheduleEnd, delta, 0)
            setSchedule("custom", scheduleStart, newEnd)
        }
    }

    function adjustScheduleMinute(target, delta) {
        if (target === "start") {
            let newStart = adjustTime(scheduleStart, 0, delta)
            setSchedule("custom", newStart, scheduleEnd)
        } else if (target === "end") {
            let newEnd = adjustTime(scheduleEnd, 0, delta)
            setSchedule("custom", scheduleStart, newEnd)
        }
    }

    function setSchedule(newMode, newStart, newEnd) {
        if (newMode !== "off" && newMode !== "sunset" && newMode !== "custom") return

        scheduleMode = newMode
        if (newStart !== undefined && newStart !== null && newStart !== "") scheduleStart = newStart
        if (newEnd !== undefined && newEnd !== null && newEnd !== "") scheduleEnd = newEnd

        scheduleProcess.command = [
            nexad,
            "screenTemp",
            "schedule",
            scheduleMode,
            scheduleStart,
            scheduleEnd
        ]
        scheduleProcess.running = true
    }

    function checkSchedule() {
        if (scheduleMode === "off") return
        if (!evalScheduleProcess.running) {
            evalScheduleProcess.running = true
        }
    }

    Timer {
        id: scheduleCheckTimer
        interval: 30000
        repeat: true
        running: root.scheduleMode !== "off"
        onTriggered: root.checkSchedule()
    }

    Process {
        id: scheduleProcess
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.applyData(JSON.parse(text))
                } catch (e) {}
                delayedRefresh.restart()
            }
        }
    }

    Process {
        id: evalScheduleProcess
        command: [root.nexad, "screenTemp", "evaluate-schedule"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.applyData(JSON.parse(text))
                } catch (e) {}
            }
        }
    }

    Component.onCompleted: {
        root.refresh()
        root.checkSchedule()
    }
}
