import QtQuick

import Quickshell
import Quickshell.Networking

import "../../theme" as Nexa
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


    // ============================================================
    // SIZE
    // ============================================================

    implicitWidth:
        Nexa.Theme.controlHeightSm

    implicitHeight:
        Nexa.Theme.controlHeightSm


    // ============================================================
    // TOP BAR BUTTON
    // ============================================================

    Rectangle {
        id: button

        anchors.fill:
            parent

        radius:
            Nexa.Theme.radiusSm

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


        Text {
            anchors.centerIn:
                parent

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


        MouseArea {
            id: mouse

            anchors.fill:
                parent

            hoverEnabled:
                true

            cursorShape:
                Qt.PointingHandCursor


            /*
             * IMPORTANT:
             *
             * Top Bar behavior stays exactly the same.
             *
             * Clicking the Top Bar icon opens/closes
             * WifiPopup.
             *
             * Quick Settings will call:
             *
             *     wifi.toggle()
             *
             * separately.
             */
            onClicked:
                root.togglePopup()
        }
    }


    // ============================================================
    // HOVER
    // ============================================================

    Status.StatusHover {
        anchorItem:
            button

        visible:
            mouse.containsMouse
            && !popup.visible

        title:
            "Wi-Fi"

        rows: [
            [
                "Network",
                root.connected
                    ? root.ssid
                    : root.enabled
                        ? "Disconnected"
                        : "Disabled"
            ],
            [
                "Signal",
                root.connected
                    ? root.strength + "%"
                    : "—"
            ]
        ]
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
