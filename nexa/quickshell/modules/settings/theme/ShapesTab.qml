// pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import "../../../theme" as Nexa

RowLayout {
    id: root

    spacing: 14

    // Initial values bound to system theme
    property int windowRounding: Nexa.Theme.windowRounding
    property int windowBorderSize: Nexa.Theme.windowBorderSize

    // Staged editing values
    property int stagedRounding: Nexa.Theme.windowRounding
    property int stagedBorderSize: Nexa.Theme.windowBorderSize

    Connections {
        target: Nexa.Theme
        function onWindowRoundingChanged() {
            if (!root.hasChanges) root.stagedRounding = Nexa.Theme.windowRounding;
        }
        function onWindowBorderSizeChanged() {
            if (!root.hasChanges) root.stagedBorderSize = Nexa.Theme.windowBorderSize;
        }
    }
    property string stagedStyle: {
        if (stagedRounding === 0) return "sharp";
        if (stagedRounding <= 6) return "subtle";
        if (stagedRounding <= 12) return "standard";
        if (stagedRounding <= 18) return "smooth";
        return "pill";
    }

    readonly property bool hasChanges: (stagedRounding !== Nexa.Theme.windowRounding) || (stagedBorderSize !== Nexa.Theme.windowBorderSize)

    signal setRoundingRequested(int rounding)
    signal setBorderSizeRequested(int borderSize)

    // Toast feedback
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

    function applyShapes() {
        Nexa.Theme.windowRounding = root.stagedRounding;
        Nexa.Theme.windowBorderSize = root.stagedBorderSize;
        setRoundingRequested(root.stagedRounding);
        setBorderSizeRequested(root.stagedBorderSize);
        const script = Quickshell.env("HOME") + "/.config/nexa/scripts/apply-shapes.sh";
        Quickshell.execDetached([script, root.stagedRounding.toString(), root.stagedBorderSize.toString(), root.stagedStyle]);
        root.showToast("Shapes & Curvature applied system-wide ✓");
    }

    // ── LEFT: SHAPE & GEOMETRY CONTROLS ─────────────────────────────────────
    Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        radius: Nexa.Theme.radiusMd
        color: Nexa.Theme.cardBackground
        border.width: Nexa.Theme.borderThin
        border.color: Nexa.Theme.border
        clip: true

        Flickable {
            anchors.fill: parent
            anchors.margins: 18
            contentWidth: width
            contentHeight: controlsCol.implicitHeight + 16
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: controlsCol
                width: parent.width
                spacing: 18

                // Header with Title & Apply Button
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            text: "Shapes & Curvature"
                            font.family: Nexa.Theme.fontFamily
                            font.pixelSize: 16
                            font.weight: Nexa.Theme.fontWeightBold
                            color: Nexa.Theme.text
                        }
                        Text {
                            text: "System-wide UI corner radius, window curvature and border outlines"
                            font.family: Nexa.Theme.fontFamily
                            font.pixelSize: 12
                            color: Nexa.Theme.mutedText
                        }
                    }

                    // Apply Button
                    Rectangle {
                        id: applyBtn
                        width: applyRow.implicitWidth + 24
                        height: 36
                        radius: 8
                        color: root.hasChanges ? (btnHover.containsMouse ? Qt.lighter(Nexa.Theme.primary, 1.08) : Nexa.Theme.primary) : Nexa.Theme.surfaceContainerHigh
                        border.width: 1
                        border.color: root.hasChanges ? Nexa.Theme.primary : Nexa.Theme.border

                        Row {
                            id: applyRow
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "󰄬"
                                font.family: Nexa.Theme.iconFontFamily
                                font.pixelSize: 14
                                color: root.hasChanges ? Nexa.Theme.onPrimary : Nexa.Theme.mutedText
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.hasChanges ? "Apply Shapes" : "Applied"
                                font.family: Nexa.Theme.fontFamily
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                                color: root.hasChanges ? Nexa.Theme.onPrimary : Nexa.Theme.mutedText
                            }
                        }

                        MouseArea {
                            id: btnHover
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.applyShapes()
                        }
                    }
                }

                // 1. Curvature Presets
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: "Curvature Style"
                        font.family: Nexa.Theme.fontFamily
                        font.pixelSize: 13
                        font.weight: Nexa.Theme.fontWeightDemiBold
                        color: Nexa.Theme.text
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Repeater {
                            model: [
                                { label: "Sharp", r: 0, icon: "󰄲" },
                                { label: "Subtle", r: 6, icon: "󰄱" },
                                { label: "Standard", r: 10, icon: "󰝤" },
                                { label: "Smooth", r: 16, icon: "󰝥" },
                                { label: "Pill", r: 24, icon: "󰝦" }
                            ]

                            Rectangle {
                                id: presetChip
                                required property var modelData
                                Layout.fillWidth: true
                                height: 50
                                radius: Math.min(modelData.r, 12)
                                color: (root.stagedRounding === modelData.r)
                                    ? Nexa.Theme.primaryContainer
                                    : (chipHover.containsMouse ? Nexa.Theme.hover : Nexa.Theme.surfaceContainer)
                                border.width: 1
                                border.color: (root.stagedRounding === modelData.r) ? Nexa.Theme.primary : Nexa.Theme.border

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 3

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: presetChip.modelData.label
                                        font.family: Nexa.Theme.fontFamily
                                        font.pixelSize: 12
                                        font.weight: (root.stagedRounding === presetChip.modelData.r) ? Nexa.Theme.fontWeightBold : Nexa.Theme.fontWeightMedium
                                        color: (root.stagedRounding === presetChip.modelData.r) ? Nexa.Theme.onPrimaryContainer : Nexa.Theme.text
                                    }

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: presetChip.modelData.r + "px"
                                        font.family: Nexa.Theme.fontFamily
                                        font.pixelSize: 10
                                        color: (root.stagedRounding === presetChip.modelData.r) ? Nexa.Theme.onPrimaryContainer : Nexa.Theme.mutedText
                                    }
                                }

                                MouseArea {
                                    id: chipHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.stagedRounding = presetChip.modelData.r
                                }
                            }
                        }
                    }
                }

                // 2. Corner Radius Slider
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "Corner Radius Size"
                            font.family: Nexa.Theme.fontFamily
                            font.pixelSize: 13
                            font.weight: Nexa.Theme.fontWeightDemiBold
                            color: Nexa.Theme.text
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: root.stagedRounding + " px"
                            font.family: Nexa.Theme.monoFontFamily || Nexa.Theme.fontFamily
                            font.pixelSize: 12
                            font.weight: Nexa.Theme.fontWeightBold
                            color: Nexa.Theme.primary
                        }
                    }

                    Slider {
                        Layout.fillWidth: true
                        from: 0
                        to: 32
                        stepSize: 1
                        value: root.stagedRounding
                        onMoved: root.stagedRounding = Math.round(value)
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Nexa.Theme.border
                }

                // 3. Border Stroke Width
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "Outline Stroke Width"
                            font.family: Nexa.Theme.fontFamily
                            font.pixelSize: 13
                            font.weight: Nexa.Theme.fontWeightDemiBold
                            color: Nexa.Theme.text
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: root.stagedBorderSize === 0 ? "Borderless" : (root.stagedBorderSize + " px")
                            font.family: Nexa.Theme.monoFontFamily || Nexa.Theme.fontFamily
                            font.pixelSize: 12
                            font.weight: Nexa.Theme.fontWeightBold
                            color: Nexa.Theme.primary
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Repeater {
                            model: [
                                { label: "Off", b: 0 },
                                { label: "1px Hairline", b: 1 },
                                { label: "2px Medium", b: 2 },
                                { label: "3px Bold", b: 3 }
                            ]

                            Rectangle {
                                id: borderChip
                                required property var modelData
                                Layout.fillWidth: true
                                height: 36
                                radius: 6
                                color: (root.stagedBorderSize === modelData.b)
                                    ? Nexa.Theme.primaryContainer
                                    : (bHover.containsMouse ? Nexa.Theme.hover : Nexa.Theme.surfaceContainer)
                                border.width: 1
                                border.color: (root.stagedBorderSize === modelData.b) ? Nexa.Theme.primary : Nexa.Theme.border

                                Text {
                                    anchors.centerIn: parent
                                    text: borderChip.modelData.label
                                    font.family: Nexa.Theme.fontFamily
                                    font.pixelSize: 11
                                    font.weight: (root.stagedBorderSize === borderChip.modelData.b) ? Nexa.Theme.fontWeightBold : Nexa.Theme.fontWeightMedium
                                    color: (root.stagedBorderSize === borderChip.modelData.b) ? Nexa.Theme.onPrimaryContainer : Nexa.Theme.text
                                }

                                MouseArea {
                                    id: bHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.stagedBorderSize = borderChip.modelData.b
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ── RIGHT: LIVE INTERACTIVE SHAPES PREVIEW ──────────────────────────────
    Rectangle {
        Layout.preferredWidth: 320
        Layout.fillHeight: true
        radius: Nexa.Theme.radiusMd
        color: Nexa.Theme.cardBackground
        border.width: Nexa.Theme.borderThin
        border.color: Nexa.Theme.border
        clip: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            Text {
                text: "Live Shape Preview"
                font.family: Nexa.Theme.fontFamily
                font.pixelSize: 14
                font.weight: Nexa.Theme.fontWeightBold
                color: Nexa.Theme.text
            }

            // Mock Desktop Window Preview
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: root.stagedRounding
                color: Nexa.Theme.surfaceContainerLowest || "#101318"
                border.width: Math.max(1, root.stagedBorderSize)
                border.color: root.stagedBorderSize > 0 ? Nexa.Theme.primary : Nexa.Theme.border
                clip: true

                Behavior on radius {
                    NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 10

                    // Window Titlebar
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Rectangle { width: 10; height: 10; radius: 5; color: "#ff5f56" }
                        Rectangle { width: 10; height: 10; radius: 5; color: "#ffbd2e" }
                        Rectangle { width: 10; height: 10; radius: 5; color: "#27c93f" }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: "Nexa Window"
                            font.family: Nexa.Theme.fontFamily
                            font.pixelSize: 11
                            color: Nexa.Theme.mutedText
                        }

                        Item { Layout.fillWidth: true }
                    }

                    // Content Box 1
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 60
                        radius: root.stagedRounding === 0 ? 0 : Math.max(2, root.stagedRounding - 2)
                        color: Nexa.Theme.surfaceContainerHigh
                        border.width: 1
                        border.color: Nexa.Theme.border

                        Behavior on radius {
                            NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 8

                            Rectangle {
                                width: 36
                                height: 36
                                radius: root.stagedRounding === 0 ? 0 : Math.max(2, root.stagedRounding - 4)
                                color: Nexa.Theme.primaryContainer

                                Behavior on radius {
                                    NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰏤"
                                    font.family: Nexa.Theme.iconFontFamily
                                    font.pixelSize: 16
                                    color: Nexa.Theme.onPrimaryContainer
                                }
                            }

                            Column {
                                Layout.fillWidth: true
                                spacing: 2
                                Text {
                                    text: "Corner Radius: " + root.stagedRounding + "px"
                                    font.family: Nexa.Theme.fontFamily
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                    color: Nexa.Theme.text
                                }
                                Text {
                                    text: "Adaptive curvature scaling"
                                    font.family: Nexa.Theme.fontFamily
                                    font.pixelSize: 10
                                    color: Nexa.Theme.mutedText
                                }
                            }
                        }
                    }

                    // Content Box 2 - Interactive Controls
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: root.stagedRounding === 0 ? 0 : Math.max(2, root.stagedRounding - 2)
                        color: Nexa.Theme.surfaceContainer
                        border.width: 1
                        border.color: Nexa.Theme.border

                        Behavior on radius {
                            NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                        }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 8

                            Text {
                                text: "Controls & Badges"
                                font.family: Nexa.Theme.fontFamily
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                                color: Nexa.Theme.text
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 28
                                    radius: root.stagedRounding === 0 ? 0 : Math.max(2, root.stagedRounding - 4)
                                    color: Nexa.Theme.primary

                                    Behavior on radius {
                                        NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "Button"
                                        font.family: Nexa.Theme.fontFamily
                                        font.pixelSize: 11
                                        font.weight: Font.Medium
                                        color: Nexa.Theme.onPrimary
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 28
                                    radius: root.stagedRounding === 0 ? 0 : Math.max(2, root.stagedRounding - 4)
                                    color: "transparent"
                                    border.width: 1
                                    border.color: Nexa.Theme.primary

                                    Behavior on radius {
                                        NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "Outlined"
                                        font.family: Nexa.Theme.fontFamily
                                        font.pixelSize: 11
                                        font.weight: Font.Medium
                                        color: Nexa.Theme.primary
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                Rectangle {
                                    width: 50
                                    height: 20
                                    radius: root.stagedRounding === 0 ? 0 : 10
                                    color: Nexa.Theme.primaryContainer

                                    Text {
                                        anchors.centerIn: parent
                                        text: "Pill Tag"
                                        font.family: Nexa.Theme.fontFamily
                                        font.pixelSize: 9
                                        color: Nexa.Theme.onPrimaryContainer
                                    }
                                }

                                Rectangle {
                                    width: 65
                                    height: 20
                                    radius: root.stagedRounding === 0 ? 0 : Math.min(root.stagedRounding, 6)
                                    color: Nexa.Theme.surfaceContainerHighest

                                    Behavior on radius {
                                        NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "Rounded Tag"
                                        font.family: Nexa.Theme.fontFamily
                                        font.pixelSize: 9
                                        color: Nexa.Theme.text
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
    // TOAST NOTIFICATION
    // ────────────────────────────────────────────────────────────
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
