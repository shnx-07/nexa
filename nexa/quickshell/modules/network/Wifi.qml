import QtQuick

import Quickshell
import Quickshell.Io
import Quickshell.Networking

import "../../theme" as Nexa
import "../../theme/components" as NexaUI
import "../status" as Status


Item {
    id: root


    // ============================================================
    // PUBLIC STATE
    // ============================================================

    readonly property var device: {
        for (let d of Networking.devices.values) {
            if (d.type === DeviceType.Wifi)
                return d
        }

        return null
    }


    readonly property var network: {
        if (!device)
            return null

        for (let n of device.networks.values) {
            if (n.connected)
                return n
        }

        return null
    }


    readonly property bool enabled:
        Networking.wifiEnabled
        && Networking.wifiHardwareEnabled


    readonly property bool connected:
        device !== null
        && device.connected
        && network !== null


    readonly property string ssid:
        connected && network
        ? network.name
        : ""


    readonly property int strength:
        connected
        ? Math.round(network.signalStrength * 100)
        : 0


    readonly property bool popupVisible:
        popup.visible


    readonly property string nexad:
        Quickshell.env("HOME")
        + "/.config/nexa/rust/target/release/nexad"


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
            (mouse.containsMouse || popup.visible)
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
    // EXISTING POPUP
    // ============================================================

    WifiPopup {
        id: popup

        anchorItem:
            button
    }
}
