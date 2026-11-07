import QtQuick

import Quickshell
import Quickshell.Io

import "../../services" as Services
import "../../NewNexaUI" as NexaUI


Item {
    id: root


    // ============================================================
    // PUBLIC STATE (From Rust SystemState)
    // ============================================================

    readonly property bool enabled:
        Services.SystemState.wifiEnabled

    readonly property bool connected:
        Services.SystemState.wifiConnected

    readonly property string ssid:
        Services.SystemState.wifiSsid

    readonly property int strength:
        Services.SystemState.wifiSignal

    readonly property bool popupVisible:
        popup.visible

    readonly property string nexad:
        Services.SystemState.nexadPath


    // ============================================================
    // PUBLIC ACTIONS
    // ============================================================

    function toggle() {
        Quickshell.execDetached([
            nexad,
            "network",
            "wifi",
            enabled ? "off" : "on"
        ])
    }


    function openPopup() {
        popup.visible = true
    }


    function closePopup() {
        popup.visible = false
    }


    function togglePopup() {
        popup.visible = !popup.visible
    }

    property bool enablePopup: true

    Loader {
        active: root.enablePopup
        sourceComponent: Component {
            IpcHandler {
                target: "wifi"
                function toggle() { root.togglePopup() }
                function open() { root.openPopup() }
                function close() { root.closePopup() }
            }
        }
    }


    // ============================================================
    // SIZE & INLINE HOVER EXPANSION
    // ============================================================

    readonly property real compactWidth: NexaUI.NexaTokens.controlHeightSm
    readonly property real maxTextWidth: 160

    readonly property string infoText: {
        if (!root.enabled)
            return "Off"
        if (!root.connected)
            return "Disconnected"
        return root.ssid ? (root.ssid + " · " + root.strength + "%") : (root.strength + "%")
    }

    readonly property bool isExpanded: mouse.containsMouse || popup.visible
    readonly property real contentLabelWidth: Math.min(maxTextWidth, labelText.implicitWidth)
    readonly property real targetWidth: isExpanded
        ? (compactWidth + NexaUI.NexaTokens.spacingXs + contentLabelWidth + NexaUI.NexaTokens.spacingXs)
        : compactWidth

    implicitWidth: targetWidth

    implicitHeight:
        NexaUI.NexaTokens.controlHeightSm

    Behavior on implicitWidth {
        enabled: NexaUI.NexaMotion.enabled
        SpringAnimation {
            spring: 5.5
            damping: 0.26
            mass: NexaUI.NexaMotion.springMass
            epsilon: 0.005
        }
    }


    // ============================================================
    // TOP BAR BUTTON
    // ============================================================

    Rectangle {
        id: button

        anchors.fill:
            parent

        visible:
            root.visible

        radius:
            NexaUI.NexaTokens.radiusSm

        color:
            (mouse.containsMouse || popup.visible)
            ? NexaUI.NexaColors.hoverOverlay
            : "transparent"

        scale:
            mouse.pressed
            ? NexaUI.NexaMotion.scalePress
            : 1.0


        Behavior on color {
            ColorAnimation {
                duration:
                    NexaUI.NexaMotion.durationFast
            }
        }


        Behavior on scale {
            NumberAnimation {
                duration:
                    NexaUI.NexaMotion.durationFast

                easing.type:
                    NexaUI.NexaMotion.standardEasing
            }
        }


        Row {
            anchors.centerIn: parent
            spacing: (root.width > root.compactWidth + 2) ? NexaUI.NexaTokens.spacingXs : 0

            Text {
                id: iconText
                anchors.verticalCenter: parent.verticalCenter

                text: {
                    if (!root.enabled)
                        return "󰤭"

                    if (!root.connected)
                        return "󰤭"

                    if (root.strength >= 75)
                        return "󰤨"

                    if (root.strength >= 50)
                        return "󰤥"

                    if (root.strength >= 25)
                        return "󰤢"

                    return "󰤟"
                }

                color:
                    root.connected
                    ? NexaUI.NexaColors.text
                    : NexaUI.NexaColors.mutedText

                font {
                    family:
                        NexaUI.NexaTypography.familyIcon

                    pixelSize:
                        NexaUI.NexaTypography.sizeSm
                }

                Behavior on color {
                    ColorAnimation {
                        duration:
                            NexaUI.NexaMotion.durationNormal
                    }
                }
            }

            Item {
                id: labelClip
                anchors.verticalCenter: parent.verticalCenter
                clip: true
                visible: width > 0.5
                width: Math.max(0, Math.min(root.contentLabelWidth, root.width - root.compactWidth - NexaUI.NexaTokens.spacingXs))
                height: labelText.implicitHeight
                opacity: Math.max(0.0, Math.min(1.0, (root.width - root.compactWidth) / 16.0))

                Behavior on opacity {
                    NumberAnimation { duration: NexaUI.NexaMotion.durationFast }
                }

                Text {
                    id: labelText
                    anchors {
                        left: parent.left
                        verticalCenter: parent.verticalCenter
                    }
                    width: Math.min(root.maxTextWidth, implicitWidth)
                    elide: Text.ElideRight
                    text: root.infoText
                    color: NexaUI.NexaColors.text
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

            anchors.fill:
                parent

            hoverEnabled:
                true

            cursorShape:
                Qt.PointingHandCursor

            onClicked:
                root.togglePopup()
        }
    }


    // ============================================================
    // EXISTING POPUP
    // ============================================================

    WifiPopup {
        id: popup

        anchorItem:
            button
    }
}
