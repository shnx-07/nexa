// pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import "../../theme" as Nexa
import "../../services" as Services

Item {
    id: root

    anchors.fill: parent

    signal requestClose()

    function rad(n) {
        if (Nexa.Theme.windowRounding === 0) return 0;
        return Math.max(0, Math.round(n * (Nexa.Theme.windowRounding / 10.0)));
    }

    component StyledSwitch: Switch {
        id: sw
        implicitWidth: 44
        implicitHeight: 24

        indicator: Rectangle {
            implicitWidth: 44
            implicitHeight: 24
            radius: root.rad(12)
            color: sw.checked ? Nexa.Theme.primary : Nexa.Theme.surfaceContainerHighest
            border.width: Nexa.Theme.borderThin
            border.color: sw.checked ? Nexa.Theme.primary : Nexa.Theme.border

            Rectangle {
                x: sw.checked ? parent.width - width - 3 : 3
                anchors.verticalCenter: parent.verticalCenter
                width: 18
                height: 18
                radius: root.rad(9)
                color: sw.checked ? Nexa.Theme.onPrimary : Nexa.Theme.text
                border.width: root.rad(9) === 0 ? Nexa.Theme.borderThin : 0
                border.color: Nexa.Theme.border
                Behavior on x {
                    NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.NoButton
        }
    }

    // Status feedback
    property string toastText: ""
    property bool toastVisible: false

    function showToast(msg) {
        toastText = msg;
        toastVisible = true;
        toastTimer.restart();
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

            // ────────────────────────────────────────────────────────────
            // 1. HEADER
            // ────────────────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Rectangle {
                    width: 44
                    height: 44
                    radius: root.rad(22)
                    color: Nexa.Theme.primaryContainer
                    border.width: Nexa.Theme.borderThin
                    border.color: Nexa.Theme.border

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
                        font.family: Nexa.Theme.fontFamily
                        font.pixelSize: 16
                        font.weight: Font.Bold
                        color: Nexa.Theme.text
                    }

                    Text {
                        text: "Position the bar on any screen edge, toggle intelligent auto-hide and customize widgets"
                        font.family: Nexa.Theme.fontFamily
                        font.pixelSize: 12
                        color: Nexa.Theme.mutedText
                    }
                }

                Rectangle {
                    width: resetTxt.implicitWidth + 20
                    height: 32
                    radius: root.rad(6)
                    color: rHover.containsMouse ? Nexa.Theme.surfaceContainerHighest : Nexa.Theme.surfaceContainerHigh
                    border.width: Nexa.Theme.borderThin
                    border.color: Nexa.Theme.border

                    Text {
                        id: resetTxt
                        anchors.centerIn: parent
                        text: "Reset Defaults"
                        font.family: Nexa.Theme.fontFamily
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        color: Nexa.Theme.text
                    }

                    MouseArea {
                        id: rHover
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Services.BarConfig.resetDefaults();
                            root.showToast("Bar settings reset to default");
                        }
                    }
                }
            }

            // ────────────────────────────────────────────────────────────
            // 2. LIVE BAR VISUALIZER (Faithful to actual Nexa desktop bar)
            // ────────────────────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                height: 120
                radius: root.rad(12)
                color: "#0a0c10"
                border.width: Nexa.Theme.borderThin
                border.color: Nexa.Theme.border
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
                            font.family: Nexa.Theme.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            color: Nexa.Theme.mutedText
                        }

                        Item { Layout.fillWidth: true }

                        Rectangle {
                            width: 8
                            height: 8
                            radius: root.rad(4)
                            color: Services.BarConfig.autohide ? "#ff9800" : "#27c93f"
                        }

                        Text {
                            text: Services.BarConfig.autohide ? "Hidden until edge hover" : "Fixed reserve zone"
                            font.family: Nexa.Theme.fontFamily
                            font.pixelSize: 10
                            color: Nexa.Theme.mutedText
                        }
                    }

                    // Simulated Screen & Bar
                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 52
                        radius: root.rad(8)
                        color: "#12151b"
                        border.width: Nexa.Theme.borderThin
                        border.color: Nexa.Theme.border

                        // The Mock Bar
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 6
                            color: "transparent"

                            RowLayout {
                                anchors.fill: parent
                                spacing: 8

                                // Left: Workspaces Pill & Window Title Pill
                                Row {
                                    visible: Services.BarConfig.showWorkspaces
                                    spacing: 6

                                    // Workspaces Pill
                                    Rectangle {
                                        height: 32
                                        width: wsRow.implicitWidth + 14
                                        radius: root.rad(16)
                                        color: "#282326"
                                        border.width: Nexa.Theme.borderThin
                                        border.color: Nexa.Theme.border

                                        Row {
                                            id: wsRow
                                            anchors.centerIn: parent
                                            spacing: 6

                                            Rectangle { width: 18; height: 10; radius: root.rad(5); color: "#ffb4ab" }
                                            Rectangle { width: 8; height: 8; radius: root.rad(4); color: "#4a454e" }
                                            Rectangle { width: 8; height: 8; radius: root.rad(4); color: "#4a454e" }
                                            Rectangle { width: 8; height: 8; radius: root.rad(4); color: "#4a454e" }
                                        }
                                    }

                                    // Window Title Pill
                                    Rectangle {
                                        visible: Services.BarConfig.showTitle
                                        height: 32
                                        width: titleRow.implicitWidth + 16
                                        radius: root.rad(16)
                                        color: "#282326"
                                        border.width: Nexa.Theme.borderThin
                                        border.color: Nexa.Theme.border

                                        Row {
                                            id: titleRow
                                            anchors.centerIn: parent
                                            spacing: 6

                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: "󰨞"
                                                font.family: Nexa.Theme.iconFontFamily
                                                font.pixelSize: 13
                                                color: "#007acc"
                                            }

                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: "Visual Studio Code · Welcome"
                                                font.family: Nexa.Theme.fontFamily
                                                font.pixelSize: 11
                                                color: "#e2e2e8"
                                            }
                                        }
                                    }
                                }

                                Item { Layout.fillWidth: true }

                                // Center: Dynamic Island Clock
                                Rectangle {
                                    visible: Services.BarConfig.showIsland
                                    height: 32
                                    width: 110
                                    radius: root.rad(16)
                                    color: "#1c181a"
                                    border.width: Nexa.Theme.borderThin
                                    border.color: Nexa.Theme.border

                                    Row {
                                        anchors.centerIn: parent
                                        spacing: 4

                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "02:32 AM"
                                            font.family: Nexa.Theme.fontFamily
                                            font.pixelSize: 11
                                            font.weight: Font.DemiBold
                                            color: "#e2e2e8"
                                        }
                                    }
                                }

                                Item { Layout.fillWidth: true }

                                // Right: Status Pills
                                Row {
                                    spacing: 6

                                    // Battery Pill
                                    Rectangle {
                                        visible: Services.BarConfig.showBattery
                                        height: 32
                                        width: batRow.implicitWidth + 14
                                        radius: root.rad(16)
                                        color: "#282326"
                                        border.width: Nexa.Theme.borderThin
                                        border.color: Nexa.Theme.border

                                        Row {
                                            id: batRow
                                            anchors.centerIn: parent
                                            spacing: 5

                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: "󰁹"
                                                font.family: Nexa.Theme.iconFontFamily
                                                font.pixelSize: 12
                                                color: "#27c93f"
                                            }

                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: "100%"
                                                font.family: Nexa.Theme.fontFamily
                                                font.pixelSize: 11
                                                color: "#e2e2e8"
                                            }
                                        }
                                    }

                                    // Connectivity Pill
                                    Rectangle {
                                        visible: Services.BarConfig.showTray
                                        height: 32
                                        width: netRow.implicitWidth + 16
                                        radius: root.rad(16)
                                        color: "#282326"
                                        border.width: Nexa.Theme.borderThin
                                        border.color: Nexa.Theme.border

                                        Row {
                                            id: netRow
                                            anchors.centerIn: parent
                                            spacing: 8

                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: "󰖩"
                                                font.family: Nexa.Theme.iconFontFamily
                                                font.pixelSize: 12
                                                color: "#e2e2e8"
                                            }

                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: "󰂯"
                                                font.family: Nexa.Theme.iconFontFamily
                                                font.pixelSize: 12
                                                color: "#e2e2e8"
                                            }

                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: "󰐥"
                                                font.family: Nexa.Theme.iconFontFamily
                                                font.pixelSize: 12
                                                color: "#ff5f56"
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ────────────────────────────────────────────────────────────
            // 3. MOVE BAR: POSITION SELECTOR (Top, Bottom, Left, Right)
            // ────────────────────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                height: posCol.implicitHeight + 32
                radius: root.rad(12)
                color: Nexa.Theme.cardBackground
                border.width: Nexa.Theme.borderThin
                border.color: Nexa.Theme.border

                ColumnLayout {
                    id: posCol
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 16
                    spacing: 12

                    Text {
                        text: "Move Bar Placement"
                        font.family: Nexa.Theme.fontFamily
                        font.pixelSize: 14
                        font.weight: Font.Bold
                        color: Nexa.Theme.text
                    }

                    Text {
                        text: "Choose which edge of the screen the status bar attaches to. Windows rearrange automatically."
                        font.family: Nexa.Theme.fontFamily
                        font.pixelSize: 12
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

                            Rectangle {
                                id: posCard
                                required property var modelData
                                readonly property bool isSelected: Services.BarConfig.position === modelData.id

                                Layout.fillWidth: true
                                height: 72
                                radius: root.rad(8)
                                color: isSelected
                                    ? Nexa.Theme.primaryContainer
                                    : (posHover.containsMouse ? Nexa.Theme.surfaceContainerHighest : Nexa.Theme.surfaceContainer)
                                border.width: isSelected ? Math.max(1.5, Nexa.Theme.borderThin * 1.5) : Nexa.Theme.borderThin
                                border.color: isSelected ? Nexa.Theme.primary : Nexa.Theme.border

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 4

                                    Row {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        spacing: 6

                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: posCard.modelData.icon
                                            font.family: Nexa.Theme.iconFontFamily
                                            font.pixelSize: 16
                                            color: posCard.isSelected ? Nexa.Theme.onPrimaryContainer : Nexa.Theme.text
                                        }

                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: posCard.modelData.label
                                            font.family: Nexa.Theme.fontFamily
                                            font.pixelSize: 13
                                            font.weight: posCard.isSelected ? Font.Bold : Font.Medium
                                            color: posCard.isSelected ? Nexa.Theme.onPrimaryContainer : Nexa.Theme.text
                                        }
                                    }

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: posCard.modelData.desc
                                        font.family: Nexa.Theme.fontFamily
                                        font.pixelSize: 10
                                        color: posCard.isSelected ? Nexa.Theme.onPrimaryContainer : Nexa.Theme.mutedText
                                    }
                                }

                                MouseArea {
                                    id: posHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        Services.BarConfig.setPosition(posCard.modelData.id);
                                        root.showToast("Bar moved to " + posCard.modelData.label);
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ────────────────────────────────────────────────────────────
            // 4. AUTOMATIC HIDE SECTION (Hyprland + Quickshell)
            // ────────────────────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                height: hideCol.implicitHeight + 32
                radius: root.rad(12)
                color: Nexa.Theme.cardBackground
                border.width: Nexa.Theme.borderThin
                border.color: Nexa.Theme.border

                ColumnLayout {
                    id: hideCol
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 16
                    spacing: 14

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3

                            Text {
                                text: "Automatic Hide (Intelligent Auto-Hide)"
                                font.family: Nexa.Theme.fontFamily
                                font.pixelSize: 14
                                font.weight: Font.Bold
                                color: Nexa.Theme.text
                            }

                            Text {
                                text: "Hides the bar and unreserves screen space in Hyprland, giving your windows maximum workspace. The bar reveals smoothly when moving your mouse to the screen edge."
                                font.family: Nexa.Theme.fontFamily
                                font.pixelSize: 12
                                color: Nexa.Theme.mutedText
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }
                        }

                        StyledSwitch {
                            checked: Services.BarConfig.autohide
                            onToggled: {
                                Services.BarConfig.setAutohide(checked);
                                root.showToast(checked ? "Auto-hide enabled" : "Auto-hide disabled");
                            }
                        }
                    }
                }
            }

            // ────────────────────────────────────────────────────────────
            // 5. COMPONENT VISIBILITY TOGGLES
            // ────────────────────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                height: compCol.implicitHeight + 32
                radius: root.rad(12)
                color: Nexa.Theme.cardBackground
                border.width: Nexa.Theme.borderThin
                border.color: Nexa.Theme.border

                ColumnLayout {
                    id: compCol
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 16
                    spacing: 12

                    Text {
                        text: "Components & Widgets"
                        font.family: Nexa.Theme.fontFamily
                        font.pixelSize: 14
                        font.weight: Font.Bold
                        color: Nexa.Theme.text
                    }

                    // Workspaces Pager
                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "Workspaces Pill"
                            font.family: Nexa.Theme.fontFamily
                            font.pixelSize: 13
                            color: Nexa.Theme.text
                        }
                        Item { Layout.fillWidth: true }
                        StyledSwitch {
                            checked: Services.BarConfig.showWorkspaces
                            onToggled: Services.BarConfig.toggleComponent("workspaces")
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: Nexa.Theme.border }

                    // Window Title
                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "Active Application Title"
                            font.family: Nexa.Theme.fontFamily
                            font.pixelSize: 13
                            color: Nexa.Theme.text
                        }
                        Item { Layout.fillWidth: true }
                        StyledSwitch {
                            checked: Services.BarConfig.showTitle
                            onToggled: Services.BarConfig.toggleComponent("title")
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: Nexa.Theme.border }

                    // Dynamic Island Center
                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "Dynamic Island Center Trigger"
                            font.family: Nexa.Theme.fontFamily
                            font.pixelSize: 13
                            color: Nexa.Theme.text
                        }
                        Item { Layout.fillWidth: true }
                        StyledSwitch {
                            checked: Services.BarConfig.showIsland
                            onToggled: Services.BarConfig.toggleComponent("island")
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: Nexa.Theme.border }

                    // Battery Indicator
                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "Battery Status Pill"
                            font.family: Nexa.Theme.fontFamily
                            font.pixelSize: 13
                            color: Nexa.Theme.text
                        }
                        Item { Layout.fillWidth: true }
                        StyledSwitch {
                            checked: Services.BarConfig.showBattery
                            onToggled: Services.BarConfig.toggleComponent("battery")
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: Nexa.Theme.border }

                    // Connectivity (WiFi / Bluetooth / Power)
                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "Connectivity & System Controls"
                            font.family: Nexa.Theme.fontFamily
                            font.pixelSize: 13
                            color: Nexa.Theme.text
                        }
                        Item { Layout.fillWidth: true }
                        StyledSwitch {
                            checked: Services.BarConfig.showTray
                            onToggled: Services.BarConfig.toggleComponent("tray")
                        }
                    }
                }
            }
        }
    }

    // ────────────────────────────────────────────────────────────
    // TOAST NOTIFICATION
    // ────────────────────────────────────────────────────────────
    Rectangle {
        id: toast
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 24
        anchors.horizontalCenter: parent.horizontalCenter
        width: toastRow.implicitWidth + 28
        height: 38
        radius: root.rad(19)
        color: Nexa.Theme.surfaceContainerHighest
        border.width: Nexa.Theme.borderThin
        border.color: Nexa.Theme.primary
        visible: root.toastVisible
        opacity: root.toastVisible ? 1.0 : 0.0

        Behavior on opacity {
            NumberAnimation { duration: 200 }
        }

        Row {
            id: toastRow
            anchors.centerIn: parent
            spacing: 8

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "󰄬"
                font.family: Nexa.Theme.iconFontFamily
                font.pixelSize: 14
                color: Nexa.Theme.primary
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.toastText
                font.family: Nexa.Theme.fontFamily
                font.pixelSize: 12
                font.weight: Font.Medium
                color: Nexa.Theme.text
            }
        }
    }
}
