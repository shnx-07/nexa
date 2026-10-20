// pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import "../../theme" as Nexa
import "../../theme/components" as NexaUI
import "../../services" as Services

Item {
    id: root
    anchors.fill: parent
    signal requestClose()

    property string toastText: ""
    property bool toastVisible: false

    function showToast(msg) {
        toastText = msg
        toastVisible = true
        toastTimer.restart()
    }

    Timer {
        id: toastTimer
        interval: 2200
        repeat: false
        onTriggered: root.toastVisible = false
    }

    Flickable {
        anchors.fill: parent
        anchors.margins: 18
        contentWidth: width
        contentHeight: contentCol.implicitHeight + 24
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        ColumnLayout {
            id: contentCol
            width: parent.width
            spacing: 16

            // 1. HEADER
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Rectangle {
                    width: 44
                    height: 44
                    radius: 22
                    color: Nexa.Theme.primaryContainer
                    Text {
                        anchors.centerIn: parent
                        text: "󰈺"
                        font.family: Nexa.Theme.iconFontFamily
                        font.pixelSize: 22
                        color: Nexa.Theme.onPrimaryContainer
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Text {
                        text: "Status Bar & Panels"
                        font.family: Nexa.Theme.fontFamily; font.pixelSize: 16; font.weight: Font.Bold
                        color: Nexa.Theme.text
                    }
                    Text {
                        text: "Position the bar on any screen edge, toggle intelligent auto-hide and customize widgets"
                        font.family: Nexa.Theme.fontFamily; font.pixelSize: 12
                        color: Nexa.Theme.mutedText
                    }
                }

                NexaUI.NexaButton {
                    text: "Reset Defaults"
                    icon: "󰁯"
                    onClicked: {
                        Services.BarConfig.resetDefaults()
                        root.showToast("Bar settings reset to default")
                    }
                }
            }

            // 2. LIVE BAR VISUALIZER
            NexaUI.NexaCard {
                Layout.fillWidth: true
                implicitHeight: 120
                color: "#0a0c10"
                clip: true

                Item {
                    anchors.fill: parent
                    anchors.margins: 14

                    RowLayout {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right

                        Text {
                            text: "Bar Layout Preview (" + Services.BarConfig.position.toUpperCase() + (Services.BarConfig.autohide ? " · AUTO-HIDE ON" : "") + ")"
                            font.family: Nexa.Theme.fontFamily; font.pixelSize: 11; font.weight: Font.DemiBold
                            color: Nexa.Theme.mutedText
                        }

                        Item { Layout.fillWidth: true }

                        Rectangle {
                            width: 8
                            height: 8
                            radius: 4
                            color: Services.BarConfig.autohide ? "#ff9800" : "#27c93f"
                        }

                        Text {
                            text: Services.BarConfig.autohide ? "Hidden until edge hover" : "Fixed reserve zone"
                            font.family: Nexa.Theme.fontFamily; font.pixelSize: 10
                            color: Nexa.Theme.mutedText
                        }
                    }

                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 52
                        radius: 8
                        color: "#12151b"
                        border.width: 1
                        border.color: "#232832"

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 6
                            color: "transparent"

                            RowLayout {
                                anchors.fill: parent
                                spacing: 8

                                Row {
                                    visible: Services.BarConfig.showWorkspaces
                                    spacing: 6
                                    Rectangle {
                                        height: 32
                                        width: wsRow.implicitWidth + 14
                                        radius: 16
                                        color: "#282326"
                                        border.width: 1
                                        border.color: "#3f373d"
                                        Row {
                                            id: wsRow
                                            anchors.centerIn: parent
                                            spacing: 6
                                            Rectangle { width: 18; height: 10; radius: 5; color: "#ffb4ab" }
                                            Rectangle { width: 8; height: 8; radius: 4; color: "#4a454e" }
                                            Rectangle { width: 8; height: 8; radius: 4; color: "#4a454e" }
                                            Rectangle { width: 8; height: 8; radius: 4; color: "#4a454e" }
                                        }
                                    }
                                }

                                Rectangle {
                                    visible: Services.BarConfig.showTitle
                                    height: 32
                                    width: 130
                                    radius: 16
                                    color: "#282326"
                                    border.width: 1
                                    border.color: "#3f373d"
                                    Row {
                                        anchors.centerIn: parent
                                        spacing: 6
                                        Text { text: "󰣇"; font.family: Nexa.Theme.iconFontFamily; font.pixelSize: 13; color: "#ffb4ab" }
                                        Text { text: "Arch Linux"; font.family: Nexa.Theme.fontFamily; font.pixelSize: 11; font.weight: Font.Medium; color: "#e2e2e8" }
                                    }
                                }

                                Item { Layout.fillWidth: true }

                                Rectangle {
                                    visible: Services.BarConfig.showIsland
                                    height: 32
                                    width: 110
                                    radius: 16
                                    color: "#1d191b"
                                    border.width: 1
                                    border.color: "#3f373d"
                                    Row {
                                        anchors.centerIn: parent
                                        spacing: 6
                                        Rectangle { width: 6; height: 6; radius: 3; color: "#ffb4ab" }
                                        Text { text: "NEXA Island"; font.family: Nexa.Theme.fontFamily; font.pixelSize: 11; font.weight: Font.Bold; color: "#ffb4ab" }
                                    }
                                }

                                Item { Layout.fillWidth: true }

                                RowLayout {
                                    spacing: 6

                                    Rectangle {
                                        visible: Services.BarConfig.showBattery
                                        height: 32
                                        width: 64
                                        radius: 16
                                        color: "#282326"
                                        border.width: 1
                                        border.color: "#3f373d"
                                        Row {
                                            anchors.centerIn: parent
                                            spacing: 4
                                            Text { text: "󱐋"; font.family: Nexa.Theme.iconFontFamily; font.pixelSize: 12; color: "#27c93f" }
                                            Text { text: "100%"; font.family: Nexa.Theme.fontFamily; font.pixelSize: 11; color: "#e2e2e8" }
                                        }
                                    }

                                    Rectangle {
                                        visible: Services.BarConfig.showTray
                                        height: 32
                                        width: netRow.implicitWidth + 16
                                        radius: 16
                                        color: "#282326"
                                        border.width: 1
                                        border.color: "#3f373d"
                                        Row {
                                            id: netRow
                                            anchors.centerIn: parent
                                            spacing: 8
                                            Text { text: "󰖩"; font.family: Nexa.Theme.iconFontFamily; font.pixelSize: 12; color: "#e2e2e8" }
                                            Text { text: "󰂯"; font.family: Nexa.Theme.iconFontFamily; font.pixelSize: 12; color: "#e2e2e8" }
                                            Text { text: "󰐥"; font.family: Nexa.Theme.iconFontFamily; font.pixelSize: 12; color: "#ff5f56" }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // 3. MOVE BAR: POSITION SELECTOR
            NexaUI.NexaCard {
                Layout.fillWidth: true
                padding: 16

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 12

                    Text {
                        text: "Screen Position (Move Bar)"
                        font.family: Nexa.Theme.fontFamily; font.pixelSize: 14; font.weight: Font.Bold
                        color: Nexa.Theme.text
                    }
                    Text {
                        text: "Choose which edge of the screen the status bar attaches to. Windows rearrange automatically."
                        font.family: Nexa.Theme.fontFamily; font.pixelSize: 12
                        color: Nexa.Theme.mutedText
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Repeater {
                            model: [
                                { id: "top", label: "Top", icon: "󰈺", desc: "Default status bar" },
                                { id: "bottom", label: "Bottom", icon: "󰈻", desc: "Dock style layout" },
                                { id: "left", label: "Left", icon: "󰈸", desc: "Vertical left sidebar" },
                                { id: "right", label: "Right", icon: "󰈹", desc: "Vertical right sidebar" }
                            ]

                            NexaUI.NexaCard {
                                required property var modelData
                                Layout.fillWidth: true
                                implicitHeight: 72
                                interactive: true
                                selected: Services.BarConfig.position === modelData.id
                                onClicked: {
                                    Services.BarConfig.setPosition(modelData.id)
                                    root.showToast("Bar moved to " + modelData.label)
                                }

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 4

                                    Row {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        spacing: 6
                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: modelData.icon
                                            font.family: Nexa.Theme.iconFontFamily; font.pixelSize: 16
                                            color: Services.BarConfig.position === modelData.id ? Nexa.Theme.primary : Nexa.Theme.text
                                        }
                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: modelData.label
                                            font.family: Nexa.Theme.fontFamily; font.pixelSize: 13; font.weight: Font.DemiBold
                                            color: Services.BarConfig.position === modelData.id ? Nexa.Theme.primary : Nexa.Theme.text
                                        }
                                    }
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: modelData.desc
                                        font.family: Nexa.Theme.fontFamily; font.pixelSize: 10
                                        color: Nexa.Theme.mutedText
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // 4. AUTOMATIC HIDE SECTION
            NexaUI.NexaCard {
                Layout.fillWidth: true
                padding: 16

                RowLayout {
                    anchors.fill: parent
                    spacing: 12

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 3

                        Text {
                            text: "Automatic Hide (Intelligent Auto-Hide)"
                            font.family: Nexa.Theme.fontFamily; font.pixelSize: 14; font.weight: Font.Bold
                            color: Nexa.Theme.text
                        }
                        Text {
                            text: "Hides the bar and unreserves screen space in Hyprland, giving your windows maximum workspace. The bar reveals smoothly when moving your mouse to the screen edge."
                            font.family: Nexa.Theme.fontFamily; font.pixelSize: 12
                            color: Nexa.Theme.mutedText
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                    }

                    NexaUI.NexaToggle {
                        checked: Services.BarConfig.autohide
                        onToggled: isChecked => {
                            Services.BarConfig.setAutohide(isChecked)
                            root.showToast(isChecked ? "Auto-hide enabled" : "Auto-hide disabled")
                        }
                    }
                }
            }

            // 5. COMPONENT VISIBILITY TOGGLES
            NexaUI.NexaCard {
                Layout.fillWidth: true
                padding: 16

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 12

                    Text {
                        text: "Components & Widgets"
                        font.family: Nexa.Theme.fontFamily; font.pixelSize: 14; font.weight: Font.Bold
                        color: Nexa.Theme.text
                    }

                    Repeater {
                        model: [
                            { label: "Workspaces Pill", id: "workspaces", getVal: () => Services.BarConfig.showWorkspaces },
                            { label: "Active Application Title", id: "title", getVal: () => Services.BarConfig.showTitle },
                            { label: "Dynamic Island Center Trigger", id: "island", getVal: () => Services.BarConfig.showIsland },
                            { label: "Battery Status Pill", id: "battery", getVal: () => Services.BarConfig.showBattery },
                            { label: "Connectivity & System Controls", id: "tray", getVal: () => Services.BarConfig.showTray }
                        ]

                        ColumnLayout {
                            required property var modelData
                            required property int index
                            Layout.fillWidth: true
                            spacing: 8

                            Rectangle { Layout.fillWidth: true; height: 1; color: Nexa.Theme.border; visible: index > 0 }

                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: modelData.label
                                    font.family: Nexa.Theme.fontFamily; font.pixelSize: 13
                                    color: Nexa.Theme.text
                                }
                                Item { Layout.fillWidth: true }
                                NexaUI.NexaToggle {
                                    checked: modelData.getVal()
                                    onToggled: Services.BarConfig.toggleComponent(modelData.id)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // TOAST NOTIFICATION
    Rectangle {
        id: toast
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 24
        anchors.horizontalCenter: parent.horizontalCenter
        width: toastRow.implicitWidth + 28
        height: 38
        radius: 19
        color: Nexa.Theme.surfaceContainerHighest
        border.width: 1
        border.color: Nexa.Theme.primary
        visible: root.toastVisible
        opacity: root.toastVisible ? 1.0 : 0.0

        Behavior on opacity { NumberAnimation { duration: 200 } }

        Row {
            id: toastRow
            anchors.centerIn: parent
            spacing: 8
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "󰄬"
                font.family: Nexa.Theme.iconFontFamily; font.pixelSize: 14
                color: Nexa.Theme.primary
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.toastText
                font.family: Nexa.Theme.fontFamily; font.pixelSize: 12; font.weight: Font.Medium
                color: Nexa.Theme.text
            }
        }
    }
}
