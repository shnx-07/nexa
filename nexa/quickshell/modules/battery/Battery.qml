import QtQuick
import Quickshell.Services.UPower
import Quickshell
import "../../theme" as Nexa


Item {
    id: root

    readonly property var battery: UPower.displayDevice
    readonly property bool ready: battery && battery.ready
    readonly property int percent:
        ready ? Math.round(battery.percentage * 100) : 0

    readonly property bool charging:
        ready && !UPower.onBattery


    implicitWidth: 54
    implicitHeight: Nexa.Theme.controlHeightSm


    Rectangle {
        id: button

        anchors.fill: parent
        radius: Nexa.Theme.radiusSm

        color: mouse.containsMouse
            ? Nexa.Theme.hover
            : "transparent"

        scale: mouse.pressed
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


        Row {
            anchors.centerIn: parent
            spacing: Nexa.Theme.spacingXs


            // ----------------------------------------------------
            // HORIZONTAL BATTERY
            // ----------------------------------------------------

            Item {
                width: 22
                height: 12

                Rectangle {
                    anchors {
                        left: parent.left
                        verticalCenter: parent.verticalCenter
                    }

                    width: 19
                    height: 11
                    radius: 3

                    color: "transparent"

                    border {
                        width: 1
                        color: Nexa.Theme.mutedText
                    }


                    Rectangle {
                        anchors {
                            left: parent.left
                            top: parent.top
                            bottom: parent.bottom
                            margins: 2
                        }

                        width: Math.max(
                            2,
                            (parent.width - 4) * root.percent / 100
                        )

                        radius: 1

                        color:
                            root.charging
                            ? Nexa.Theme.success
                            : root.percent <= 15
                                ? Nexa.Theme.error
                                : root.percent <= 30
                                    ? Nexa.Theme.warning
                                    : Nexa.Theme.primary

                        Behavior on color {
                            ColorAnimation {
                                duration: Nexa.Theme.animationNormal
                                easing.type: Nexa.Theme.easingStandard
                            }
                        }

                        Behavior on width {
                            NumberAnimation {
                                duration: Nexa.Theme.animationNormal
                                easing.type: Nexa.Theme.easingDecelerate
                            }
                        }
                    }


                    // ⚡ overlay — centered inside the battery body
                    Text {
                        anchors.centerIn: parent

                        visible: root.charging

                        text: "⚡"

                        z: 1

                        color: Nexa.Theme.onSurface

                        font {
                            family: Nexa.Theme.fontFamily
                            pixelSize: Nexa.Theme.fontSize2Xs
                        }
                    }
                }


                // Battery tip
                Rectangle {
                    anchors {
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                    }

                    width: 2
                    height: 5
                    radius: 1

                    color: Nexa.Theme.mutedText
                }
            }



            Text {
                anchors.verticalCenter: parent.verticalCenter

                text: root.ready
                    ? root.percent + "%"
                    : "--"

                color:
                    root.percent <= 15
                    ? Nexa.Theme.error
                    : Nexa.Theme.text

                font {
                    family: Nexa.Theme.fontFamily
                    pixelSize: Nexa.Theme.fontSizeXs
                    weight: Nexa.Theme.fontWeightMedium
                }
            }
        }


        MouseArea {
            id: mouse

            anchors.fill: parent

            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            // Popup visible is the ONLY open/close state.
            onClicked:
                popup.visible = !popup.visible
        }
    }


    // ------------------------------------------------------------
    // DETAILS
    // ------------------------------------------------------------

    BatteryPopup {
        id: popup

        anchorItem: button
    }

    // ============================================================
    // HOVER INFO
    // ============================================================

    PopupWindow {
        id: hoverPopup

        visible:
            mouse.containsMouse
            && !popup.visible

        implicitWidth: 150
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

            // Entrance: fade + scale spring
            opacity: hoverPopup.visible ? 1.0 : 0.0
            scale:  hoverPopup.visible ? 1.0 : 0.95

            Behavior on opacity {
                NumberAnimation {
                    duration: Nexa.Theme.animationFast
                    easing.type: Nexa.Theme.easingEnter
                }
            }

            Behavior on scale {
                NumberAnimation {
                    duration: Nexa.Theme.animationFast
                    easing.type: Nexa.Theme.easingEmphasized
                }
            }


            Column {
                anchors {
                    left: parent.left
                    verticalCenter: parent.verticalCenter
                    leftMargin: Nexa.Theme.spacingMd
                }

                spacing: 2


                Text {
                    text: "Battery"

                    color: Nexa.Theme.text

                    font {
                        family: Nexa.Theme.fontFamily
                        pixelSize: Nexa.Theme.fontSizeXs
                        weight: Nexa.Theme.fontWeightDemiBold
                    }
                }


                Text {
                    text:
                        root.ready
                        ? root.percent + "% · "
                          + (root.charging ? "Charging" : "On battery")
                        : "Unavailable"

                    color: Nexa.Theme.mutedText

                    font {
                        family: Nexa.Theme.fontFamily
                        pixelSize: Nexa.Theme.fontSize2Xs
                    }
                }
            }
        }
    }   // ------------------------------------------------------------
    // NOTIFICATIONS
    //
    // Low / critical / full battery hook goes here later.
    // ------------------------------------------------------------
}
