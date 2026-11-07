import QtQuick
import QtQuick.Layouts

import Quickshell
import Quickshell.Io

import "../../NewNexaUI" as NexaUI


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
    // POLLING & FILE WATCHER
    //
    // Watches runtime recorder.json for instant start/stop reactions
    // and continuously polls so Dynamic Island is immediately aware
    // when recording starts from Quick Settings, scripts, or hotkeys.
    // ============================================================

    FileView {
        id: recorderStateFile
        path: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/nexa/recorder.json"
        watchChanges: true

        onFileChanged: {
            root.refreshStatus()
        }
    }

    Timer {
        interval: root.recording ? 1000 : 1500
        repeat: true
        running: true

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
                NexaUI.NexaTokens.spacingLg

            anchors.rightMargin:
                NexaUI.NexaTokens.spacingLg

            spacing:
                NexaUI.NexaTokens.spacingSm

            Text {
                text:
                    root.paused
                    ? "Recording paused"
                    : "Recording started"

                color:
                    NexaUI.NexaColors.text

                font {
                    family:
                        NexaUI.NexaTypography.familyBody

                    pixelSize:
                        NexaUI.NexaTypography.sizeSm

                    weight:
                        NexaUI.NexaTypography.weightMedium
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
                    NexaUI.NexaColors.text

                font {
                    family:
                        NexaUI.NexaTypography.familyMono

                    pixelSize:
                        NexaUI.NexaTypography.sizeSm

                    weight:
                        NexaUI.NexaTypography.weightSemiBold
                }
            }

            Rectangle {
                width: 8
                height: 8

                radius: 4

                color:
                    root.paused
                    ? NexaUI.NexaColors.mutedText
                    : NexaUI.NexaColors.error
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
                NexaUI.NexaTokens.spacingLg

            anchors.rightMargin:
                NexaUI.NexaTokens.spacingLg

            anchors.topMargin:
                NexaUI.NexaTokens.spacingMd

            anchors.bottomMargin:
                NexaUI.NexaTokens.spacingMd

            spacing:
                NexaUI.NexaTokens.spacingSm

            RowLayout {
                Layout.fillWidth: true

                Text {
                    text:
                        root.paused
                        ? "Recording paused"
                        : "Screen recording"

                    color:
                        NexaUI.NexaColors.text

                    font {
                        family:
                            NexaUI.NexaTypography.familyBody

                        pixelSize:
                            NexaUI.NexaTypography.sizeSm

                        weight:
                            NexaUI.NexaTypography.weightSemiBold
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
                        ? NexaUI.NexaColors.mutedText
                        : NexaUI.NexaColors.error
                }

                Text {
                    text:
                        root.formatTime(
                            root.elapsed
                        )

                    color:
                        NexaUI.NexaColors.text

                    font {
                        family:
                            NexaUI.NexaTypography.familyMono

                        pixelSize:
                            NexaUI.NexaTypography.sizeSm

                        weight:
                            NexaUI.NexaTypography.weightSemiBold
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true

                spacing:
                    NexaUI.NexaTokens.spacingSm

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
                        NexaUI.NexaTokens.radiusSm

                    color:
                        pauseMouse.pressed
                        ? NexaUI.NexaColors.surfaceContainerHighest
                        : pauseMouse.containsMouse
                          ? NexaUI.NexaColors.hoverStrong
                          : NexaUI.NexaColors.surfaceContainerHigh

                    Row {
                        anchors.centerIn: parent

                        spacing:
                            NexaUI.NexaTokens.spacingXs

                        Text {
                            text:
                                root.paused
                                ? "󰐊"
                                : "󰏤"

                            color:
                                NexaUI.NexaColors.text

                            font {
                                family:
                                    NexaUI.NexaTypography.familyIcon

                                pixelSize:
                                    NexaUI.NexaTokens.iconSm
                            }
                        }

                        Text {
                            text:
                                root.paused
                                ? "Resume"
                                : "Pause"

                            color:
                                NexaUI.NexaColors.text

                            font {
                                family:
                                    NexaUI.NexaTypography.familyBody

                                pixelSize:
                                    NexaUI.NexaTypography.sizeXs

                                weight:
                                    NexaUI.NexaTypography.weightMedium
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
                        NexaUI.NexaTokens.radiusSm

                    color:
                        stopMouse.pressed
                        ? NexaUI.NexaColors.surfaceContainerHighest
                        : stopMouse.containsMouse
                          ? NexaUI.NexaColors.hoverStrong
                          : NexaUI.NexaColors.surfaceContainerHigh

                    Row {
                        anchors.centerIn: parent

                        spacing:
                            NexaUI.NexaTokens.spacingXs

                        Rectangle {
                            width: 9
                            height: 9

                            radius:
                                NexaUI.NexaTokens.radiusXs

                            color:
                                NexaUI.NexaColors.error
                        }

                        Text {
                            text: "Stop"

                            color:
                                NexaUI.NexaColors.text

                            font {
                                family:
                                    NexaUI.NexaTypography.familyBody

                                pixelSize:
                                    NexaUI.NexaTypography.sizeXs

                                weight:
                                    NexaUI.NexaTypography.weightMedium
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
