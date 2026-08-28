import QtQuick
import Quickshell
import "../../theme" as Nexa
import "../../theme/components" as NexaUI


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

    NexaUI.NexaIconButton {
        id: button
        anchors.fill: parent
        radius: height / 2
        icon: "⏻"
        iconColor: Nexa.Theme.error
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


    // ============================================================
    // HOVER INFO
    // ============================================================

    PopupWindow {
        id: hoverPopup

        visible: button.hovered

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
