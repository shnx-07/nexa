import QtQuick

import Quickshell
import Quickshell.Io


Item {
    id: root

    property bool recording: false
    property bool paused: false
    property int elapsed: 0
    property string recordingPath: ""

    property bool changing: false


    readonly property string nexadPath:
        Quickshell.env("HOME")
        + "/.config/nexa/rust/target/release/nexad"


    readonly property string statusText: {
        if (!recording)
            return "Ready"

        if (paused)
            return "Paused · " + formatTime(elapsed)

        return "Recording · " + formatTime(elapsed)
    }


    function formatTime(seconds) {
        const minutes =
            Math.floor(
                seconds / 60
            )

        const secs =
            seconds % 60

        return String(minutes)
            .padStart(2, "0")
            + ":"
            + String(secs)
                .padStart(2, "0")
    }


    function applyData(payload) {
        root.recording =
            payload.recording === true

        root.paused =
            payload.paused === true

        root.elapsed =
            payload.elapsed || 0

        root.recordingPath =
            payload.path || ""
    }


    function refresh() {
        if (statusProcess.running)
            return

        statusProcess.exec([
            root.nexadPath,
            "recorder",
            "status"
        ])
    }


    // Idle -> start
    // Recording -> stop
    function toggleRecording() {
        if (changing)
            return

        root.changing = true

        actionProcess.exec([
            root.nexadPath,
            "recorder",
            root.recording
                ? "stop"
                : "start"
        ])
    }


    function pauseResume() {
        if (!recording || changing)
            return

        root.changing = true

        actionProcess.exec([
            root.nexadPath,
            "recorder",
            root.paused
                ? "resume"
                : "pause"
        ])
    }


    function stop() {
        if (!recording || changing)
            return

        root.changing = true

        actionProcess.exec([
            root.nexadPath,
            "recorder",
            "stop"
        ])
    }


    Process {
        id: statusProcess

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.applyData(
                        JSON.parse(
                            this.text
                        )
                    )
                } catch (error) {
                    console.error(
                        "[RecorderControl:status]",
                        error
                    )
                }
            }
        }
    }


    Process {
        id: actionProcess

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
                        "[RecorderControl:action]",
                        error
                    )
                }

                delayedRefresh.restart()
            }
        }
    }


    Timer {
        id: delayedRefresh

        interval: 250
        repeat: false

        onTriggered:
            root.refresh()
    }


    Timer {
        interval: 1500
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
