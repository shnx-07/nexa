import QtQuick

import Quickshell
import Quickshell.Bluetooth

import "../../theme" as Nexa
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
            "bluetooth",
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
                    Nexa.Theme.iconLg
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
             * Top Bar behavior remains unchanged.
             *
             * Quick Settings will call:
             *
             *     bluetooth.toggle()
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
            "Bluetooth"

        rows: [
            [
                "Device",
                root.connected
                    ? root.connectedDeviceName
                    : root.enabled
                        ? "No device"
                        : "Disabled"
            ],
            [
                "Type",
                root.connected
                    ? root.connectedDeviceType
                    : "—"
            ]
        ]
    }


    // ============================================================
    // EXISTING POPUP
    // ============================================================

    BluetoothPopup {
        id: popup

        anchorItem:
            button
    }
}
