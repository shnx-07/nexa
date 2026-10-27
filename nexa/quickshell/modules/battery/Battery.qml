import QtQuick
import Quickshell.Services.UPower
import Quickshell
import "../../theme" as Nexa
import "../../theme/components" as NexaUI


Item {
    id: root

    readonly property var battery: UPower.displayDevice
    readonly property bool ready: battery && battery.ready
    readonly property int percent:
        ready ? Math.round(battery.percentage * 100) : 0

    readonly property bool charging:
        ready && !UPower.onBattery


    readonly property real compactWidth: 54

    readonly property string statusText: {
        if (!root.ready) return "Unavailable"
        if (root.percent >= 100 && root.charging) return "Fully Charged"
        if (root.charging) return "Charging"
        return "On Battery"
    }

    readonly property bool isExpanded: mouse.containsMouse || popup.visible
    readonly property real contentLabelWidth: statusTextItem.implicitWidth
    readonly property real targetWidth: isExpanded
        ? (compactWidth + contentLabelWidth + Nexa.Theme.spacingXs)
        : compactWidth

    implicitWidth: targetWidth
    implicitHeight: Nexa.Theme.controlHeightSm

    Behavior on implicitWidth {
        enabled: !Nexa.Theme.reducedMotion
        NexaUI.NexaSpring { section: "popups"; customStiffness: 5.5; customDamping: 0.26 }
    }


    Rectangle {
        id: button

        anchors.fill: parent
        radius: Nexa.Theme.nexaRounding === 0 ? 0 : Nexa.Theme.radiusSm

        color: (mouse.containsMouse || popup.visible)
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
                    radius: 2.5

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

            Item {
                id: statusClip
                anchors.verticalCenter: parent.verticalCenter
                clip: true
                visible: width > 0.5
                width: Math.max(0, Math.min(root.contentLabelWidth, root.width - root.compactWidth))
                height: statusTextItem.implicitHeight
                opacity: Math.max(0.0, Math.min(1.0, (root.width - root.compactWidth) / 16.0))

                Behavior on opacity {
                    NumberAnimation { duration: Nexa.Theme.animationFast }
                }

                Text {
                    id: statusTextItem
                    anchors {
                        left: parent.left
                        verticalCenter: parent.verticalCenter
                    }
                    text: "· " + root.statusText
                    color: Nexa.Theme.mutedText
                    font {
                        family: Nexa.Theme.fontFamily
                        pixelSize: Nexa.Theme.fontSizeXs
                        weight: Nexa.Theme.fontWeightMedium
                    }
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
    }   // ------------------------------------------------------------
    // NOTIFICATIONS
    //
    // Low / critical / full battery hook goes here later.
    // ------------------------------------------------------------
}
