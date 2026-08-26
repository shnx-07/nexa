import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Quickshell
import Quickshell.Io

import "../../theme" as Nexa


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
                Nexa.Theme.spacingLg

            leftMargin:
                Nexa.Theme.spacingLg

            rightMargin:
                Nexa.Theme.spacingLg
        }

        height: 28


        Text {
            text: "󰆍"

            color:
                Nexa.Theme.primary

            font {
                family:
                    Nexa.Theme.iconFontFamily

                pixelSize:
                    Nexa.Theme.iconSm
            }
        }


        Text {
            Layout.fillWidth: true

            text:
                "Command"

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


        Text {
            text:
                root.running
                ? "Running…"
                : "ESC"

            color:
                Nexa.Theme.mutedText

            font {
                family:
                    Nexa.Theme.monoFontFamily

                pixelSize:
                    Nexa.Theme.fontSize2Xs
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
                Nexa.Theme.spacingMd

            leftMargin:
                Nexa.Theme.spacingLg

            rightMargin:
                Nexa.Theme.spacingLg
        }

        height: 54

        radius:
            Nexa.Theme.radiusMd

        color:
            Nexa.Theme.inputBackgroundFocus

        border.width:
            Nexa.Theme.borderNormal

        border.color:
            commandInput.activeFocus
            ? Nexa.Theme.primary
            : Nexa.Theme.border


        RowLayout {
            anchors {
                fill: parent

                leftMargin:
                    Nexa.Theme.spacingLg

                rightMargin:
                    Nexa.Theme.spacingLg
            }

            spacing:
                Nexa.Theme.spacingMd


            Text {
                text: "❯"

                color:
                    Nexa.Theme.primary

                font {
                    family:
                        Nexa.Theme.monoFontFamily

                    pixelSize:
                        Nexa.Theme.fontSizeLg

                    weight:
                        Nexa.Theme.fontWeightBold
                }
            }


            TextInput {
                id: commandInput

                focus: true

                Layout.fillWidth: true

                color:
                    Nexa.Theme.text

                selectionColor:
                    Nexa.Theme.primary

                selectedTextColor:
                    Nexa.Theme.primaryText

                clip: true


                font {
                    family:
                        Nexa.Theme.monoFontFamily

                    pixelSize:
                        Nexa.Theme.fontSizeMd
                }


                Text {
                    anchors.fill:
                        parent

                    visible:
                        commandInput.text.length === 0

                    text:
                        "Enter command..."

                    color:
                        Nexa.Theme.mutedText

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
                Nexa.Theme.spacingMd

            leftMargin:
                Nexa.Theme.spacingLg

            rightMargin:
                Nexa.Theme.spacingLg

            bottomMargin:
                Nexa.Theme.spacingLg
        }

        radius:
            Nexa.Theme.radiusMd

        color:
            Nexa.Theme.cardBackground

        border.width:
            Nexa.Theme.borderThin

        border.color:
            Nexa.Theme.border

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
                Nexa.Theme.spacingSm


            Text {
                anchors.horizontalCenter:
                    parent.horizontalCenter

                text: "󰆍"

                color:
                    Nexa.Theme.mutedText

                font {
                    family:
                        Nexa.Theme.iconFontFamily

                    pixelSize:
                        Nexa.Theme.icon2Xl
                }
            }


            Text {
                anchors.horizontalCenter:
                    parent.horizontalCenter

                text:
                    "Run a shell command"

                color:
                    Nexa.Theme.mutedText

                font {
                    family:
                        Nexa.Theme.fontFamily

                    pixelSize:
                        Nexa.Theme.fontSizeSm
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
                Nexa.Theme.mutedText

            font {
                family:
                    Nexa.Theme.monoFontFamily

                pixelSize:
                    Nexa.Theme.fontSizeSm
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
                    Nexa.Theme.spacingMd
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
                Nexa.Theme.flickDeceleration

            maximumFlickVelocity:
                Nexa.Theme.flickVelocityMax

            pixelAligned: true

            ScrollBar.vertical: ScrollBar {
                id: cmdScrollBar
                policy: ScrollBar.AsNeeded

                contentItem: Rectangle {
                    implicitWidth: 3
                    radius: width / 2
                    color: Qt.rgba(
                        Nexa.Theme.text.r,
                        Nexa.Theme.text.g,
                        Nexa.Theme.text.b,
                        cmdScrollBar.hovered ? 0.5 : 0.18
                    )

                    Behavior on color {
                        ColorAnimation { duration: Nexa.Theme.animationFast }
                    }
                }

                background: null
            }


            Column {
                id: outputColumn

                width:
                    outputFlick.width

                spacing:
                    Nexa.Theme.spacingMd


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
                            ? Nexa.Theme.success
                            : Nexa.Theme.error

                        font {
                            family:
                                Nexa.Theme.fontFamily

                            pixelSize:
                                Nexa.Theme.fontSizeXs

                            weight:
                                Nexa.Theme.fontWeightDemiBold
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
                        Nexa.Theme.text

                    wrapMode:
                        Text.WrapAnywhere

                    textFormat:
                        Text.PlainText

                    font {
                        family:
                            Nexa.Theme.monoFontFamily

                        pixelSize:
                            Nexa.Theme.fontSizeXs
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
                        Nexa.Theme.error

                    wrapMode:
                        Text.WrapAnywhere

                    textFormat:
                        Text.PlainText

                    font {
                        family:
                            Nexa.Theme.monoFontFamily

                        pixelSize:
                            Nexa.Theme.fontSizeXs
                    }
                }
            }
        }
    }
}
