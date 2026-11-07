import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Quickshell
import Quickshell.Io

import "../../NewNexaUI" as NexaUI


Item {
    id: root

    signal requestClose()

    property bool running: false

    property string output: ""
    property string errorOutput: ""

    property int exitCode: 0


    readonly property string nexadPath:
        Quickshell.shellDir
        + "/../rust/target/release/nexad"


    // ============================================================
    // FOCUS
    // ============================================================

    function activate() {
        commandInput.forceActiveFocus()
    }


    onVisibleChanged: {
        if (visible) {
            Qt.callLater(function() {
                commandInput.forceActiveFocus()
            })
        }
    }


    // ============================================================
    // RUN COMMAND
    // ============================================================

    function runCommand() {
        const command =
            commandInput.text.trim()


        if (command.length === 0)
            return


        if (commandProcess.running)
            return


        root.output = ""
        root.errorOutput = ""
        root.exitCode = 0
        root.running = true


        commandProcess.command = [
            root.nexadPath,
            "command",
            "run",
            command
        ]

        commandProcess.running = true
    }


    // ============================================================
    // PROCESS
    // ============================================================

    Process {
        id: commandProcess


        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const result =
                        JSON.parse(text)


                    root.exitCode =
                        result.exit_code ?? 0


                    root.output =
                        result.stdout || ""


                    root.errorOutput =
                        result.stderr || ""
                }
                catch (error) {
                    console.warn(
                        "NEXA command JSON error:",
                        error
                    )

                    root.exitCode = -1
                    root.errorOutput =
                        "Failed to parse command response."
                }
            }
        }


        onRunningChanged: {
            if (!running)
                root.running = false
        }
    }


    // ============================================================
    // HEADER
    // ============================================================

    RowLayout {
        id: header

        anchors {
            top: parent.top
            left: parent.left
            right: parent.right

            topMargin:
                NexaUI.NexaTokens.spacingLg

            leftMargin:
                NexaUI.NexaTokens.spacingLg

            rightMargin:
                NexaUI.NexaTokens.spacingLg
        }

        height: 28


        Text {
            text: "󰆍"

            color:
                NexaUI.NexaColors.primary

            font {
                family:
                    NexaUI.NexaTypography.familyIcon

                pixelSize:
                    NexaUI.NexaTokens.iconSm
            }
        }


        Text {
            Layout.fillWidth: true

            text:
                "Command"

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


        Text {
            text:
                root.running
                ? "Running…"
                : "ESC"

            color:
                NexaUI.NexaColors.mutedText

            font {
                family:
                    NexaUI.NexaTypography.familyMono

                pixelSize:
                    NexaUI.NexaTypography.size2Xs
            }
        }
    }


    // ============================================================
    // COMMAND INPUT
    // ============================================================

    Rectangle {
        id: commandBox

        anchors {
            top:
                header.bottom

            left:
                parent.left

            right:
                parent.right


            topMargin:
                NexaUI.NexaTokens.spacingMd

            leftMargin:
                NexaUI.NexaTokens.spacingLg

            rightMargin:
                NexaUI.NexaTokens.spacingLg
        }

        height: 54

        radius:
            NexaUI.NexaTokens.radiusMd

        color:
            NexaUI.NexaColors.surfaceContainer

        border.width:
            NexaUI.NexaTokens.borderMedium

        border.color:
            commandInput.activeFocus
            ? NexaUI.NexaColors.primary
            : NexaUI.NexaColors.border


        RowLayout {
            anchors {
                fill: parent

                leftMargin:
                    NexaUI.NexaTokens.spacingLg

                rightMargin:
                    NexaUI.NexaTokens.spacingLg
            }

            spacing:
                NexaUI.NexaTokens.spacingMd


            Text {
                text: "❯"

                color:
                    NexaUI.NexaColors.primary

                font {
                    family:
                        NexaUI.NexaTypography.familyMono

                    pixelSize:
                        NexaUI.NexaTypography.sizeLg

                    weight:
                        NexaUI.NexaTypography.weightBold
                }
            }


            TextInput {
                id: commandInput

                focus: true

                Layout.fillWidth: true

                color:
                    NexaUI.NexaColors.text

                selectionColor:
                    NexaUI.NexaColors.primary

                selectedTextColor:
                    NexaUI.NexaColors.onPrimary

                clip: true


                font {
                    family:
                        NexaUI.NexaTypography.familyMono

                    pixelSize:
                        NexaUI.NexaTypography.sizeMd
                }


                Text {
                    anchors.fill:
                        parent

                    visible:
                        commandInput.text.length === 0

                    text:
                        "Enter command..."

                    color:
                        NexaUI.NexaColors.mutedText

                    verticalAlignment:
                        Text.AlignVCenter

                    font:
                        commandInput.font
                }


                Keys.onPressed: event => {

                    if (
                        event.key === Qt.Key_Return
                        || event.key === Qt.Key_Enter
                    ) {
                        root.runCommand()

                        event.accepted = true
                        return
                    }


                    if (event.key === Qt.Key_Escape) {
                        root.requestClose()

                        event.accepted = true
                    }
                }
            }
        }
    }


    // ============================================================
    // OUTPUT
    // ============================================================

    Rectangle {
        anchors {
            top:
                commandBox.bottom

            left:
                parent.left

            right:
                parent.right

            bottom:
                parent.bottom


            topMargin:
                NexaUI.NexaTokens.spacingMd

            leftMargin:
                NexaUI.NexaTokens.spacingLg

            rightMargin:
                NexaUI.NexaTokens.spacingLg

            bottomMargin:
                NexaUI.NexaTokens.spacingLg
        }

        radius:
            NexaUI.NexaTokens.radiusMd

        color:
            NexaUI.NexaColors.surfaceContainer

        border.width:
            NexaUI.NexaTokens.borderThin

        border.color:
            NexaUI.NexaColors.border

        clip: true


        // ========================================================
        // EMPTY STATE
        // ========================================================

        Column {
            anchors.centerIn:
                parent

            visible:
                root.output.length === 0
                && root.errorOutput.length === 0
                && !root.running

            spacing:
                NexaUI.NexaTokens.spacingSm


            Text {
                anchors.horizontalCenter:
                    parent.horizontalCenter

                text: "󰆍"

                color:
                    NexaUI.NexaColors.mutedText

                font {
                    family:
                        NexaUI.NexaTypography.familyIcon

                    pixelSize:
                        32
                }
            }


            Text {
                anchors.horizontalCenter:
                    parent.horizontalCenter

                text:
                    "Run a shell command"

                color:
                    NexaUI.NexaColors.mutedText

                font {
                    family:
                        NexaUI.NexaTypography.familyBody

                    pixelSize:
                        NexaUI.NexaTypography.sizeSm
                }
            }
        }


        // ========================================================
        // RUNNING STATE
        // ========================================================

        Text {
            anchors.centerIn:
                parent

            visible:
                root.running

            text:
                "Running command…"

            color:
                NexaUI.NexaColors.mutedText

            font {
                family:
                    NexaUI.NexaTypography.familyMono

                pixelSize:
                    NexaUI.NexaTypography.sizeSm
            }
        }


        // ========================================================
        // OUTPUT VIEW
        // ========================================================

        Flickable {
            id: outputFlick

            anchors {
                fill: parent

                margins:
                    NexaUI.NexaTokens.spacingMd
            }

            visible:
                !root.running
                && (
                    root.output.length > 0
                    || root.errorOutput.length > 0
                )

            clip: true

            contentWidth:
                width

            contentHeight:
                outputColumn.implicitHeight

            boundsBehavior:
                Flickable.StopAtBounds

            flickDeceleration:
                1500

            maximumFlickVelocity:
                2500

            NexaUI.NexaSmoothScroll {}

            pixelAligned: false

            ScrollBar.vertical: ScrollBar {
                id: cmdScrollBar
                policy: ScrollBar.AsNeeded

                contentItem: Rectangle {
                    implicitWidth: 3
                    radius: width / 2
                    color: Qt.rgba(
                        NexaUI.NexaColors.text.r,
                        NexaUI.NexaColors.text.g,
                        NexaUI.NexaColors.text.b,
                        cmdScrollBar.hovered ? 0.5 : 0.18
                    )

                    Behavior on color {
                        ColorAnimation { duration: NexaUI.NexaMotion.durationFast }
                    }
                }

                background: null
            }


            Column {
                id: outputColumn

                width:
                    outputFlick.width

                spacing:
                    NexaUI.NexaTokens.spacingMd


                RowLayout {
                    width:
                        parent.width


                    Text {
                        Layout.fillWidth: true

                        text:
                            root.exitCode === 0
                            ? "Completed"
                            : "Exited with code "
                              + root.exitCode

                        color:
                            root.exitCode === 0
                            ? NexaUI.NexaColors.success
                            : NexaUI.NexaColors.error

                        font {
                            family:
                                NexaUI.NexaTypography.familyBody

                            pixelSize:
                                NexaUI.NexaTypography.sizeXs

                            weight:
                                NexaUI.NexaTypography.weightSemiBold
                        }
                    }
                }


                Text {
                    width:
                        parent.width

                    visible:
                        root.output.length > 0

                    text:
                        root.output

                    color:
                        NexaUI.NexaColors.text

                    wrapMode:
                        Text.WrapAnywhere

                    textFormat:
                        Text.PlainText

                    font {
                        family:
                            NexaUI.NexaTypography.familyMono

                        pixelSize:
                            NexaUI.NexaTypography.sizeXs
                    }
                }


                Text {
                    width:
                        parent.width

                    visible:
                        root.errorOutput.length > 0

                    text:
                        root.errorOutput

                    color:
                        NexaUI.NexaColors.error

                    wrapMode:
                        Text.WrapAnywhere

                    textFormat:
                        Text.PlainText

                    font {
                        family:
                            NexaUI.NexaTypography.familyMono

                        pixelSize:
                            NexaUI.NexaTypography.sizeXs
                    }
                }
            }
        }
    }
}
