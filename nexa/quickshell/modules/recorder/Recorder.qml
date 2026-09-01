import QtQuick
import QtQuick.Layouts

import Quickshell
import Quickshell.Io

import "../../theme" as Nexa


Item {
    id: root

    // ============================================================
    // PRESENTATION FROM ISLAND
    // ============================================================

    property string presentation: "compact"

    // ============================================================
    // PUBLIC RECORDER STATE
    // ============================================================

    property bool recording: false
    property bool paused: false

    property int elapsed: 0

    property string recordingPath: ""

    readonly property bool active:
        recording

    // ============================================================
    // BACKEND
    // ============================================================

    readonly property string nexadPath:
        Quickshell.env("HOME")
        + "/.config/nexa/rust/target/release/nexad"

    // ============================================================
    // TIME FORMAT
    // ============================================================

    function formatTime(seconds) {
        const hours =
            Math.floor(seconds / 3600)

        const minutes =
            Math.floor(
                (seconds % 3600) / 60
            )

        const secs =
            seconds % 60

        if (hours > 0) {
            return String(hours)
                .padStart(2, "0")
                + ":"
                + String(minutes)
                    .padStart(2, "0")
                + ":"
                + String(secs)
                    .padStart(2, "0")
        }

        return String(minutes)
            .padStart(2, "0")
            + ":"
            + String(secs)
                .padStart(2, "0")
    }

    // ============================================================
    // STATUS
    // ============================================================

    function refreshStatus() {
        if (statusProcess.running)
            return

        statusProcess.exec([
            nexadPath,
            "recorder",
            "status"
        ])
    }

    function applyStatus(payload) {
        root.recording =
            payload.recording === true

        root.paused =
            payload.paused === true

        root.elapsed =
            payload.elapsed || 0

        root.recordingPath =
            payload.path || ""
    }

    // ============================================================
    // ACTIONS
    // ============================================================

    function pauseRecording() {
        if (!recording || paused)
            return

        pauseProcess.exec([
            nexadPath,
            "recorder",
            "pause"
        ])
    }

    function resumeRecording() {
        if (!recording || !paused)
            return

        resumeProcess.exec([
            nexadPath,
            "recorder",
            "resume"
        ])
    }

    function stopRecording() {
        if (!recording)
            return

        stopProcess.exec([
            nexadPath,
            "recorder",
            "stop"
        ])
    }

    // ============================================================
    // INITIAL CHECK
    // ============================================================

    Component.onCompleted:
        refreshStatus()

    // ============================================================
    // POLLING
    //
    // Rust remains source of truth.
    // ============================================================

    Timer {
        interval: 1000
        repeat: true
        running: root.visible || root.recording

        onTriggered:
            root.refreshStatus()
    }

    onVisibleChanged: {
        if (root.visible)
            root.refreshStatus()
    }

    // ============================================================
    // STATUS PROCESS
    // ============================================================

    Process {
        id: statusProcess

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.applyStatus(
                        JSON.parse(
                            this.text
                        )
                    )
                } catch (error) {
                    console.error(
                        "[Recorder:status]",
                        error
                    )
                }
            }
        }
    }

    // ============================================================
    // PAUSE
    // ============================================================

    Process {
        id: pauseProcess

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.applyStatus(
                        JSON.parse(
                            this.text
                        )
                    )
                } catch (error) {
                    console.error(
                        "[Recorder:pause]",
                        error
                    )
                }
            }
        }
    }

    // ============================================================
    // RESUME
    // ============================================================

    Process {
        id: resumeProcess

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.applyStatus(
                        JSON.parse(
                            this.text
                        )
                    )
                } catch (error) {
                    console.error(
                        "[Recorder:resume]",
                        error
                    )
                }
            }
        }
    }

    // ============================================================
    // STOP
    // ============================================================

    Process {
        id: stopProcess

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.applyStatus(
                        JSON.parse(
                            this.text
                        )
                    )
                } catch (error) {
                    console.error(
                        "[Recorder:stop]",
                        error
                    )
                }
            }
        }
    }

    // ============================================================
    // COMPACT
    //
    // Recording started                 00:18 ●
    // ============================================================

    Item {
        anchors.fill: parent

        visible:
            root.presentation === "compact"

        RowLayout {
            anchors.fill: parent

            anchors.leftMargin:
                Nexa.Theme.spacingLg

            anchors.rightMargin:
                Nexa.Theme.spacingLg

            spacing:
                Nexa.Theme.spacingSm

            Text {
                text:
                    root.paused
                    ? "Recording paused"
                    : "Recording started"

                color:
                    Nexa.Theme.text

                font {
                    family:
                        Nexa.Theme.fontFamily

                    pixelSize:
                        Nexa.Theme.fontSizeSm

                    weight:
                        Nexa.Theme.fontWeightMedium
                }
            }

            Item {
                Layout.fillWidth: true
            }

            Text {
                text:
                    root.formatTime(
                        root.elapsed
                    )

                color:
                    Nexa.Theme.text

                font {
                    family:
                        Nexa.Theme.monoFontFamily

                    pixelSize:
                        Nexa.Theme.fontSizeSm

                    weight:
                        Nexa.Theme.fontWeightDemiBold
                }
            }

            Rectangle {
                width: 8
                height: 8

                radius: 4

                color:
                    root.paused
                    ? Nexa.Theme.mutedText
                    : Nexa.Theme.error
            }
        }
    }

    // ============================================================
    // HOVER
    //
    // Recording             ● 00:18
    //
    //             pause/resume    stop
    // ============================================================

    Item {
        anchors.fill: parent

        visible:
            root.presentation === "hover"

        ColumnLayout {
            anchors.fill: parent

            anchors.leftMargin:
                Nexa.Theme.spacingLg

            anchors.rightMargin:
                Nexa.Theme.spacingLg

            anchors.topMargin:
                Nexa.Theme.spacingMd

            anchors.bottomMargin:
                Nexa.Theme.spacingMd

            spacing:
                Nexa.Theme.spacingSm

            RowLayout {
                Layout.fillWidth: true

                Text {
                    text:
                        root.paused
                        ? "Recording paused"
                        : "Screen recording"

                    color:
                        Nexa.Theme.text

                    font {
                        family:
                            Nexa.Theme.fontFamily

                        pixelSize:
                            Nexa.Theme.fontSizeSm

                        weight:
                            Nexa.Theme.fontWeightDemiBold
                    }
                }

                Item {
                    Layout.fillWidth: true
                }

                Rectangle {
                    width: 8
                    height: 8
                    radius: 4

                    color:
                        root.paused
                        ? Nexa.Theme.mutedText
                        : Nexa.Theme.error
                }

                Text {
                    text:
                        root.formatTime(
                            root.elapsed
                        )

                    color:
                        Nexa.Theme.text

                    font {
                        family:
                            Nexa.Theme.monoFontFamily

                        pixelSize:
                            Nexa.Theme.fontSizeSm

                        weight:
                            Nexa.Theme.fontWeightDemiBold
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true

                spacing:
                    Nexa.Theme.spacingSm

                Item {
                    Layout.fillWidth: true
                }

                // =================================================
                // PAUSE / RESUME
                // =================================================

                Rectangle {
                    id: pauseButton

                    width: 84
                    height: 32

                    radius:
                        Nexa.Theme.radiusSm

                    color:
                        pauseMouse.pressed
                        ? Nexa.Theme.pressed
                        : pauseMouse.containsMouse
                          ? Nexa.Theme.hoverStrong
                          : Nexa.Theme.buttonBackground

                    Row {
                        anchors.centerIn: parent

                        spacing:
                            Nexa.Theme.spacingXs

                        Text {
                            text:
                                root.paused
                                ? "󰐊"
                                : "󰏤"

                            color:
                                Nexa.Theme.text

                            font {
                                family:
                                    Nexa.Theme.iconFontFamily

                                pixelSize:
                                    Nexa.Theme.iconSm
                            }
                        }

                        Text {
                            text:
                                root.paused
                                ? "Resume"
                                : "Pause"

                            color:
                                Nexa.Theme.text

                            font {
                                family:
                                    Nexa.Theme.fontFamily

                                pixelSize:
                                    Nexa.Theme.fontSizeXs

                                weight:
                                    Nexa.Theme.fontWeightMedium
                            }
                        }
                    }

                    MouseArea {
                        id: pauseMouse

                        anchors.fill: parent

                        hoverEnabled: true

                        cursorShape:
                            Qt.PointingHandCursor

                        onClicked: {
                            if (root.paused)
                                root.resumeRecording()
                            else
                                root.pauseRecording()
                        }
                    }
                }

                // =================================================
                // STOP
                // =================================================

                Rectangle {
                    id: stopButton

                    width: 72
                    height: 32

                    radius:
                        Nexa.Theme.radiusSm

                    color:
                        stopMouse.pressed
                        ? Nexa.Theme.pressed
                        : stopMouse.containsMouse
                          ? Nexa.Theme.hoverStrong
                          : Nexa.Theme.buttonBackground

                    Row {
                        anchors.centerIn: parent

                        spacing:
                            Nexa.Theme.spacingXs

                        Rectangle {
                            width: 9
                            height: 9

                            radius:
                                Nexa.Theme.radiusXs

                            color:
                                Nexa.Theme.error
                        }

                        Text {
                            text: "Stop"

                            color:
                                Nexa.Theme.text

                            font {
                                family:
                                    Nexa.Theme.fontFamily

                                pixelSize:
                                    Nexa.Theme.fontSizeXs

                                weight:
                                    Nexa.Theme.fontWeightMedium
                            }
                        }
                    }

                    MouseArea {
                        id: stopMouse

                        anchors.fill: parent

                        hoverEnabled: true

                        cursorShape:
                            Qt.PointingHandCursor

                        onClicked:
                            root.stopRecording()
                    }
                }
            }
        }
     }

     onPresentationChanged: {
        console.log(
            "[Recorder] presentation:",
            presentation
        )
    }

}
