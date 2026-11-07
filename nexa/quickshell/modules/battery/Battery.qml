import QtQuick
import Quickshell
import "../../services" as Services
import "../../NewNexaUI" as NexaUI

Item {
    id: root

    readonly property bool ready: true
    readonly property int percent: Services.SystemState.batteryPercentage
    readonly property bool charging: Services.SystemState.batteryCharging
    readonly property bool onBattery: Services.SystemState.onBattery

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
        ? (compactWidth + contentLabelWidth + NexaUI.NexaTokens.spacingXs)
        : compactWidth

    implicitWidth: targetWidth
    implicitHeight: NexaUI.NexaTokens.controlHeightSm

    Behavior on implicitWidth {
        enabled: !NexaUI.NexaMotion.reducedMotion
        SpringAnimation {
            spring: NexaUI.NexaMotion.springStiffness
            damping: NexaUI.NexaMotion.springDamping
            mass: NexaUI.NexaMotion.springMass
        }
    }

    Rectangle {
        id: button

        anchors.fill: parent
        radius: NexaUI.NexaTokens.radiusSm

        color: (mouse.containsMouse || popup.visible)
            ? NexaUI.NexaColors.surfaceContainerHigh
            : "transparent"

        scale: mouse.pressed
            ? NexaUI.NexaMotion.scalePress
            : 1.0

        Behavior on color {
            ColorAnimation {
                duration: NexaUI.NexaMotion.durationFast
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: NexaUI.NexaMotion.durationFast
                easing.type: NexaUI.NexaMotion.easingStandard
            }
        }

        Row {
            anchors.centerIn: parent
            spacing: NexaUI.NexaTokens.spacingXs

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
                        width: NexaUI.NexaTokens.borderThin
                        color: NexaUI.NexaColors.mutedText
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
                            ? NexaUI.NexaColors.success
                            : root.percent <= 15
                                ? NexaUI.NexaColors.error
                                : root.percent <= 30
                                    ? NexaUI.NexaColors.warning
                                    : NexaUI.NexaColors.primary

                        Behavior on color {
                            ColorAnimation {
                                duration: NexaUI.NexaMotion.durationNormal
                                easing.type: NexaUI.NexaMotion.easingStandard
                            }
                        }

                        Behavior on width {
                            NumberAnimation {
                                duration: NexaUI.NexaMotion.durationNormal
                                easing.type: NexaUI.NexaMotion.easingDecelerate
                            }
                        }
                    }

                    // ⚡ overlay — centered inside the battery body
                    Text {
                        anchors.centerIn: parent
                        visible: root.charging
                        text: "⚡"
                        z: 1
                        color: NexaUI.NexaColors.onSurface
                        font {
                            family: NexaUI.NexaTypography.familyBody
                            pixelSize: NexaUI.NexaTypography.size2Xs
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
                    color: NexaUI.NexaColors.mutedText
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.ready
                    ? root.percent + "%"
                    : "--"

                color:
                    root.percent <= 15
                    ? NexaUI.NexaColors.error
                    : NexaUI.NexaColors.text

                font {
                    family: NexaUI.NexaTypography.familyBody
                    pixelSize: NexaUI.NexaTypography.sizeXs
                    weight: NexaUI.NexaTypography.weightMedium
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
                    NumberAnimation { duration: NexaUI.NexaMotion.durationFast }
                }

                Text {
                    id: statusTextItem
                    anchors {
                        left: parent.left
                        verticalCenter: parent.verticalCenter
                    }
                    text: "· " + root.statusText
                    color: NexaUI.NexaColors.mutedText
                    font {
                        family: NexaUI.NexaTypography.familyBody
                        pixelSize: NexaUI.NexaTypography.sizeXs
                        weight: NexaUI.NexaTypography.weightMedium
                    }
                }
            }
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
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
}
