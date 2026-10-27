import QtQuick

import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth

import "../../theme" as Nexa
import "../../theme/components" as NexaUI
import "../status" as Status


Item {
    id: root


    // ============================================================
    // PUBLIC STATE
    // ============================================================

    readonly property var adapter:
        Bluetooth.defaultAdapter


    readonly property bool enabled:
        adapter !== null
        && adapter.enabled


    readonly property var connectedDevice: {
        for (
            let device
            of Bluetooth.devices.values
        ) {
            if (device.connected)
                return device
        }

        return null
    }


    readonly property bool connected:
        connectedDevice !== null


    readonly property string connectedDeviceName:
        connected
        ? connectedDevice.name
        : ""


    readonly property string connectedDeviceType:
        connected
        ? connectedDevice.icon
        : ""


    readonly property bool popupVisible:
        popupLoader.item ? popupLoader.item.visible : false


    readonly property string nexad:
        Quickshell.env("HOME")
        + "/.config/nexa/rust/target/release/nexad"


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
                function toggle(): void { root.togglePopup() }
                function open(): void { root.openPopup() }
                function close(): void { root.closePopup() }
            }
        }
    }


    // ============================================================
    // SIZE & INLINE HOVER EXPANSION
    // ============================================================

    readonly property real compactWidth: Nexa.Theme.controlHeightSm
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
        ? (compactWidth + Nexa.Theme.spacingXs + contentLabelWidth + Nexa.Theme.spacingXs)
        : compactWidth

    implicitWidth: targetWidth

    implicitHeight:
        Nexa.Theme.controlHeightSm

    Behavior on implicitWidth {
        enabled: !Nexa.Theme.reducedMotion
        NexaUI.NexaSpring { section: "popups"; customStiffness: 5.5; customDamping: 0.26 }
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
            Nexa.Theme.radiusSm

        color:
            (mouse.containsMouse || root.popupVisible)
            ? Nexa.Theme.hover
            : "transparent"

        scale:
            mouse.pressed
            ? Nexa.Theme.pressScale
            : Nexa.Theme.normalScale


        Behavior on color {
            ColorAnimation {
                duration:
                    Nexa.Theme.animationFast
            }
        }


        Behavior on scale {
            NumberAnimation {
                duration:
                    Nexa.Theme.animationFast

                easing.type:
                    Nexa.Theme.easingStandard
            }
        }


        Row {
            anchors.centerIn: parent
            spacing: (root.width > root.compactWidth + 2) ? Nexa.Theme.spacingXs : 0

            Text {
                id: iconText
                anchors.verticalCenter: parent.verticalCenter

                text:
                    root.enabled
                    ? "󰂯"
                    : "󰂲"

                color:
                    root.connected
                    ? Nexa.Theme.primary
                    : root.enabled
                        ? Nexa.Theme.text
                        : Nexa.Theme.mutedText

                font {
                    family:
                        Nexa.Theme.iconFontFamily

                    pixelSize:
                        Nexa.Theme.iconSm
                }

                Behavior on color {
                    ColorAnimation {
                        duration:
                            Nexa.Theme.animationNormal
                    }
                }
            }

            Item {
                id: labelClip
                anchors.verticalCenter: parent.verticalCenter
                clip: true
                visible: width > 0.5
                width: Math.max(0, Math.min(root.contentLabelWidth, root.width - root.compactWidth - Nexa.Theme.spacingXs))
                height: labelText.implicitHeight
                opacity: Math.max(0.0, Math.min(1.0, (root.width - root.compactWidth) / 16.0))

                Behavior on opacity {
                    NumberAnimation { duration: Nexa.Theme.animationFast }
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
                    color: Nexa.Theme.text
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
