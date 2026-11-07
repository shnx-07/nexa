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
        Services.SystemState.bluetoothEnabled

    readonly property bool connected:
        Services.SystemState.bluetoothConnected

    readonly property string connectedDeviceName:
        Services.SystemState.bluetoothDeviceName

    readonly property string connectedDeviceType:
        Services.SystemState.bluetoothDeviceType

    readonly property bool popupVisible:
        popupLoader.item ? popupLoader.item.visible : false

    readonly property string nexad:
        Services.SystemState.nexadPath


    // ============================================================
    // PUBLIC ACTIONS
    // ============================================================

    function toggle() {
        const nextState = !root.enabled
        Quickshell.execDetached([
            nexad,
            "network",
            "bluetooth",
            nextState ? "on" : "off"
        ])
    }


    function openPopup() {
        if (popupLoader.item)
            popupLoader.item.visible = true
    }


    function closePopup() {
        if (popupLoader.item)
            popupLoader.item.visible = false
    }


    function togglePopup() {
        if (popupLoader.item)
            popupLoader.item.visible = !popupLoader.item.visible
    }


    property bool enablePopup: true

    Loader {
        active: root.enablePopup
        sourceComponent: Component {
            IpcHandler {
                target: "bluetooth"
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
    readonly property real maxTextWidth: 150

    readonly property string infoText: {
        if (!root.enabled)
            return "Off"
        if (!root.connected)
            return "No Device"
        return root.connectedDeviceName || "Connected"
    }

    readonly property bool isExpanded: mouse.containsMouse || root.popupVisible
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
            (mouse.containsMouse || root.popupVisible)
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

                text:
                    root.enabled
                    ? "󰂯"
                    : "󰂲"

                color:
                    root.connected
                    ? NexaUI.NexaColors.primary
                    : root.enabled
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
    // POPUP LOADER
    // ============================================================

    Loader {
        id: popupLoader
        active: root.enablePopup
        sourceComponent: Component {
            BluetoothPopup {
                id: popup
                anchorItem: button
            }
        }
    }
}
