import QtQuick
import Quickshell
import "../../theme" as Nexa


Item {
    id: root


    // ============================================================
    // SIZE
    // ============================================================

    implicitWidth: Nexa.Theme.controlHeightSm
    implicitHeight: Nexa.Theme.controlHeightSm


    // ============================================================
    // POWER BUTTON
    // ============================================================

    Rectangle {
        id: button

        anchors.fill: parent

        radius: Nexa.Theme.radiusSm

        color:
            mouse.containsMouse
            ? Nexa.Theme.hover
            : "transparent"

        scale:
            mouse.pressed
            ? Nexa.Theme.pressScale
            : Nexa.Theme.normalScale


        Behavior on color {
            ColorAnimation {
                duration: Nexa.Theme.animationFast
            }
        }


        Behavior on scale {
            NumberAnimation {
                duration: Nexa.Theme.animationFast
                easing.type: Nexa.Theme.easingStandard
            }
        }


        // --------------------------------------------------------
        // POWER ICON
        // --------------------------------------------------------

        Text {
            anchors.centerIn: parent

            text: "⏻"

            color: Nexa.Theme.text

            font {
                family: Nexa.Theme.fontFamily
                pixelSize: Nexa.Theme.fontSizeMd
                weight: Nexa.Theme.fontWeightMedium
            }

            Behavior on color {
                ColorAnimation {
                    duration: Nexa.Theme.animationFast
                }
            }
        }


        // --------------------------------------------------------
        // INPUT
        // --------------------------------------------------------

        MouseArea {
            id: mouse

            anchors.fill: parent

            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            onClicked: {
                Quickshell.execDetached([
                    "qs",
                    "-p",
                    Quickshell.env("HOME") + "/.config/nexa/quickshell",
                    "ipc",
                    "call",
                    "nexaIsland",
                    "openPower"
                ])
            }
        }
    }


    // ============================================================
    // HOVER INFO
    // ============================================================

    PopupWindow {
        id: hoverPopup

        visible: mouse.containsMouse

        implicitWidth: 120
        implicitHeight: 52

        color: "transparent"


        anchor {
            item: button

            rect.x: button.width / 2
            rect.y: button.height + Nexa.Theme.spacingXs

            rect.width: 1
            rect.height: 1

            edges: Edges.Top
            gravity: Edges.Bottom
        }


        Rectangle {
            anchors.fill: parent

            radius: Nexa.Theme.radiusSm
            color: Nexa.Theme.popupBackground

            border {
                width: Nexa.Theme.borderThin
                color: Nexa.Theme.border
            }


            Column {
                anchors {
                    left: parent.left
                    verticalCenter: parent.verticalCenter
                    leftMargin: Nexa.Theme.spacingMd
                }

                spacing: 2


                Text {
                    text: "Power"

                    color: Nexa.Theme.text

                    font {
                        family: Nexa.Theme.fontFamily
                        pixelSize: Nexa.Theme.fontSizeXs
                        weight: Nexa.Theme.fontWeightDemiBold
                    }
                }


                Text {
                    text: "Session controls"

                    color: Nexa.Theme.mutedText

                    font {
                        family: Nexa.Theme.fontFamily
                        pixelSize: Nexa.Theme.fontSize2Xs
                    }
                }
            }
        }
    }
}
