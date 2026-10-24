// pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import "../../theme" as Nexa
import "../../theme/components" as NexaUI

RowLayout {
    id: root

    spacing: 14

    property int windowRounding: Nexa.Theme.windowRounding
    property int nexaRounding: Nexa.Theme.nexaRounding
    property int windowBorderSize: Nexa.Theme.windowBorderSize
    property bool windowGlow: true
    property real windowDim: 0.0

    signal setRoundingRequested(int r)
    signal setNexaRoundingRequested(int nr)
    signal setBorderSizeRequested(int b)
    signal setWindowGlowRequested(bool on)
    signal setWindowDimRequested(real dim)

    // ── LEFT: COMPOSITOR & SHELL STYLING CONTROLS ─────────────────────────────
    Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        radius: Nexa.Theme.radiusMd
        color: Nexa.Theme.cardBackground
        border.width: Nexa.Theme.borderThin
        border.color: Nexa.Theme.border
        clip: true

        Flickable {
            id: leftFlick
            anchors.fill: parent
            contentWidth: width
            contentHeight: leftCol.implicitHeight + 36
            boundsBehavior: Flickable.StopAtBounds
            flickDeceleration: Nexa.Theme.flickDeceleration
            maximumFlickVelocity: Nexa.Theme.flickVelocityMax
            pixelAligned: false
            clip: true

            NexaUI.NexaSmoothScroll {}

            ScrollBar.vertical: ScrollBar {
                id: vScroll
                policy: ScrollBar.AsNeeded
                contentItem: Rectangle {
                    implicitWidth: 3
                    radius: width / 2
                    color: Qt.rgba(Nexa.Theme.text.r, Nexa.Theme.text.g, Nexa.Theme.text.b, vScroll.hovered ? 0.45 : 0.18)
                }
                background: null
            }

            ColumnLayout {
                id: leftCol
                width: leftFlick.width - 36
                x: 18
                y: 18
                spacing: 16

                Text {
                    text: "Window Aesthetics & Nexa Shell"
                    font.family: Nexa.Theme.fontFamily
                    font.pixelSize: 16
                    font.weight: Nexa.Theme.fontWeightBold
                    color: Nexa.Theme.text
                }

                // ════════════════════════════════════════════════════════════
                // SECTION 1: APPLICATION WINDOWS (HYPRLAND)
                // ════════════════════════════════════════════════════════════
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: winSecCol.implicitHeight + 24
                    radius: Nexa.Theme.radiusSm
                    color: Nexa.Theme.surfaceContainer
                    border.width: Nexa.Theme.borderThin
                    border.color: Nexa.Theme.border

                    ColumnLayout {
                        id: winSecCol
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 12

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Text {
                                text: "🪟"
                                font.pixelSize: 14
                            }
                            ColumnLayout {
                                spacing: 1
                                Text {
                                    text: "Application Windows"
                                    font.family: Nexa.Theme.fontFamily
                                    font.pixelSize: 13
                                    font.weight: Nexa.Theme.fontWeightBold
                                    color: Nexa.Theme.text
                                }
                                Text {
                                    text: "Curvature & borders for external apps (VS Code, terminal, browser, etc.)"
                                    font.family: Nexa.Theme.fontFamily
                                    font.pixelSize: 10
                                    color: Nexa.Theme.mutedText
                                }
                            }
                        }

                        // 1.1 App Window Corner Radius
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: "Window Corner Radius"
                                    font.family: Nexa.Theme.fontFamily
                                    font.pixelSize: 12
                                    font.weight: Nexa.Theme.fontWeightDemiBold
                                    color: Nexa.Theme.text
                                }
                                Item { Layout.fillWidth: true }
                                Text {
                                    text: root.windowRounding + " px"
                                    font.family: Nexa.Theme.fontFamily
                                    font.pixelSize: 12
                                    font.weight: Nexa.Theme.fontWeightBold
                                    color: Nexa.Theme.primary
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                Repeater {
                                    model: [
                                        { label: "0px Sharp", val: 0 },
                                        { label: "6px Subtle", val: 6 },
                                        { label: "10px Standard", val: 10 },
                                        { label: "16px Modern", val: 16 },
                                        { label: "24px Round", val: 24 }
                                    ]

                                    Rectangle {
                                        id: roundPill
                                        required property var modelData
                                        Layout.fillWidth: true
                                        height: 32
                                        radius: Nexa.Theme.radiusSm
                                        readonly property bool isCurrent: root.windowRounding === roundPill.modelData.val || (root.windowRounding > 0 && Math.abs(root.windowRounding - roundPill.modelData.val) <= 1)
                                        color: isCurrent ? Nexa.Theme.primaryContainer : (roundMouse.containsMouse ? Nexa.Theme.hover : Nexa.Theme.surfaceContainerHigh)
                                        border.width: isCurrent ? 1 : 0
                                        border.color: isCurrent ? Nexa.Theme.primary : "transparent"

                                        Text {
                                            anchors.centerIn: parent
                                            text: roundPill.modelData.label
                                            font.family: Nexa.Theme.fontFamily
                                            font.pixelSize: 11
                                            font.weight: roundPill.isCurrent ? Nexa.Theme.fontWeightDemiBold : Nexa.Theme.fontWeightRegular
                                            color: roundPill.isCurrent ? Nexa.Theme.onPrimaryContainer : Nexa.Theme.text
                                        }

                                        MouseArea {
                                            id: roundMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.setRoundingRequested(roundPill.modelData.val)
                                        }
                                    }
                                }
                            }

                            Slider {
                                id: radiusSlider
                                Layout.fillWidth: true
                                from: 0
                                to: 32
                                stepSize: 1
                                value: root.windowRounding
                                onMoved: root.setRoundingRequested(Math.round(value))
                            }
                        }

                        // Divider
                        Rectangle { Layout.fillWidth: true; height: 1; color: Nexa.Theme.borderSubtle }

                        // 1.2 App Window Border Width
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: "Window Border Width"
                                    font.family: Nexa.Theme.fontFamily
                                    font.pixelSize: 12
                                    font.weight: Nexa.Theme.fontWeightDemiBold
                                    color: Nexa.Theme.text
                                }
                                Item { Layout.fillWidth: true }
                                Text {
                                    text: root.windowBorderSize === 0 ? "Borderless" : (root.windowBorderSize + " px")
                                    font.family: Nexa.Theme.fontFamily
                                    font.pixelSize: 12
                                    font.weight: Nexa.Theme.fontWeightBold
                                    color: Nexa.Theme.primary
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                Repeater {
                                    model: [
                                        { label: "0px None", val: 0 },
                                        { label: "1px Hairline", val: 1 },
                                        { label: "2px Defined", val: 2 },
                                        { label: "3px Bold", val: 3 }
                                    ]

                                    Rectangle {
                                        id: borderPill
                                        required property var modelData
                                        Layout.fillWidth: true
                                        height: 32
                                        radius: Nexa.Theme.radiusSm
                                        readonly property bool isCurrent: root.windowBorderSize === borderPill.modelData.val
                                        color: isCurrent ? Nexa.Theme.primaryContainer : (bMouse.containsMouse ? Nexa.Theme.hover : Nexa.Theme.surfaceContainerHigh)
                                        border.width: isCurrent ? 1 : 0
                                        border.color: isCurrent ? Nexa.Theme.primary : "transparent"

                                        Text {
                                            anchors.centerIn: parent
                                            text: borderPill.modelData.label
                                            font.family: Nexa.Theme.fontFamily
                                            font.pixelSize: 11
                                            font.weight: borderPill.isCurrent ? Nexa.Theme.fontWeightDemiBold : Nexa.Theme.fontWeightRegular
                                            color: borderPill.isCurrent ? Nexa.Theme.onPrimaryContainer : Nexa.Theme.text
                                        }

                                        MouseArea {
                                            id: bMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.setBorderSizeRequested(borderPill.modelData.val)
                                        }
                                    }
                                }
                            }

                            Slider {
                                id: borderSlider
                                Layout.fillWidth: true
                                from: 0
                                to: 8
                                stepSize: 1
                                value: root.windowBorderSize
                                onMoved: root.setBorderSizeRequested(Math.round(value))
                            }
                        }

                        // Divider
                        Rectangle { Layout.fillWidth: true; height: 1; color: Nexa.Theme.borderSubtle }

                        // 1.3 Glow & Shadow
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1
                                Text {
                                    text: "Drop Shadow & Ambient Glow"
                                    font.family: Nexa.Theme.fontFamily
                                    font.pixelSize: 12
                                    font.weight: Nexa.Theme.fontWeightDemiBold
                                    color: Nexa.Theme.text
                                }
                                Text {
                                    text: root.windowGlow ? "Soft 30px ambient compositor drop shadow" : "Shadows disabled for a flat, lightweight look"
                                    font.family: Nexa.Theme.fontFamily
                                    font.pixelSize: 10
                                    color: Nexa.Theme.mutedText
                                }
                            }

                            NexaUI.NexaToggle {
                                checked: root.windowGlow
                                onToggled: root.setWindowGlowRequested(!root.windowGlow)
                            }
                        }

                        // Divider
                        Rectangle { Layout.fillWidth: true; height: 1; color: Nexa.Theme.borderSubtle }

                        // 1.4 Inactive Window Dimming
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: "Inactive Window Dimming"
                                    font.family: Nexa.Theme.fontFamily
                                    font.pixelSize: 12
                                    font.weight: Nexa.Theme.fontWeightDemiBold
                                    color: Nexa.Theme.text
                                }
                                Item { Layout.fillWidth: true }
                                Text {
                                    text: Math.round(root.windowDim * 100) + "%"
                                    font.family: Nexa.Theme.fontFamily
                                    font.pixelSize: 12
                                    font.weight: Nexa.Theme.fontWeightBold
                                    color: Nexa.Theme.primary
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                Repeater {
                                    model: [
                                        { label: "0% Focused", val: 0.0 },
                                        { label: "6% Subtle", val: 0.06 },
                                        { label: "12% Defined", val: 0.12 },
                                        { label: "20% Deep", val: 0.20 }
                                    ]

                                    Rectangle {
                                        id: dimPill
                                        required property var modelData
                                        Layout.fillWidth: true
                                        height: 32
                                        radius: Nexa.Theme.radiusSm
                                        readonly property bool isCurrent: Math.abs(root.windowDim - dimPill.modelData.val) < 0.01
                                        color: isCurrent ? Nexa.Theme.primaryContainer : (dMouse.containsMouse ? Nexa.Theme.hover : Nexa.Theme.surfaceContainerHigh)
                                        border.width: isCurrent ? 1 : 0
                                        border.color: isCurrent ? Nexa.Theme.primary : "transparent"

                                        Text {
                                            anchors.centerIn: parent
                                            text: dimPill.modelData.label
                                            font.family: Nexa.Theme.fontFamily
                                            font.pixelSize: 11
                                            font.weight: dimPill.isCurrent ? Nexa.Theme.fontWeightDemiBold : Nexa.Theme.fontWeightRegular
                                            color: dimPill.isCurrent ? Nexa.Theme.onPrimaryContainer : Nexa.Theme.text
                                        }

                                        MouseArea {
                                            id: dMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.setWindowDimRequested(dimPill.modelData.val)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ════════════════════════════════════════════════════════════
                // SECTION 2: NEXA SHELL & UI COMPONENTS
                // ════════════════════════════════════════════════════════════
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: nexaSecCol.implicitHeight + 24
                    radius: Nexa.Theme.radiusSm
                    color: Nexa.Theme.surfaceContainer
                    border.width: Nexa.Theme.borderThin
                    border.color: Nexa.Theme.border

                    ColumnLayout {
                        id: nexaSecCol
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 12

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Text {
                                text: "✨"
                                font.pixelSize: 14
                            }
                            ColumnLayout {
                                spacing: 1
                                Text {
                                    text: "Nexa Shell & Bars"
                                    font.family: Nexa.Theme.fontFamily
                                    font.pixelSize: 13
                                    font.weight: Nexa.Theme.fontWeightBold
                                    color: Nexa.Theme.text
                                }
                                Text {
                                    text: "Curvature for Nexa top bar, dynamic island, clipboard, and system panels"
                                    font.family: Nexa.Theme.fontFamily
                                    font.pixelSize: 10
                                    color: Nexa.Theme.mutedText
                                }
                            }
                        }

                        // 2.1 Nexa Corner Radius
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: "Nexa Corner Curvature"
                                    font.family: Nexa.Theme.fontFamily
                                    font.pixelSize: 12
                                    font.weight: Nexa.Theme.fontWeightDemiBold
                                    color: Nexa.Theme.text
                                }
                                Item { Layout.fillWidth: true }
                                Text {
                                    text: root.nexaRounding + " px"
                                    font.family: Nexa.Theme.fontFamily
                                    font.pixelSize: 12
                                    font.weight: Nexa.Theme.fontWeightBold
                                    color: Nexa.Theme.primary
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                Repeater {
                                    model: [
                                        { label: "0px Square", val: 0 },
                                        { label: "8px Subtle", val: 8 },
                                        { label: "14px Standard", val: 14 },
                                        { label: "20px Curved", val: 20 },
                                        { label: "28px Pill", val: 28 }
                                    ]

                                    Rectangle {
                                        id: nPill
                                        required property var modelData
                                        Layout.fillWidth: true
                                        height: 32
                                        radius: Nexa.Theme.radiusSm
                                        readonly property bool isCurrent: root.nexaRounding === nPill.modelData.val || (root.nexaRounding > 0 && Math.abs(root.nexaRounding - nPill.modelData.val) <= 1)
                                        color: isCurrent ? Nexa.Theme.primaryContainer : (nMouse.containsMouse ? Nexa.Theme.hover : Nexa.Theme.surfaceContainerHigh)
                                        border.width: isCurrent ? 1 : 0
                                        border.color: isCurrent ? Nexa.Theme.primary : "transparent"

                                        Text {
                                            anchors.centerIn: parent
                                            text: nPill.modelData.label
                                            font.family: Nexa.Theme.fontFamily
                                            font.pixelSize: 11
                                            font.weight: nPill.isCurrent ? Nexa.Theme.fontWeightDemiBold : Nexa.Theme.fontWeightRegular
                                            color: nPill.isCurrent ? Nexa.Theme.onPrimaryContainer : Nexa.Theme.text
                                        }

                                        MouseArea {
                                            id: nMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.setNexaRoundingRequested(nPill.modelData.val)
                                        }
                                    }
                                }
                            }

                            Slider {
                                id: nexaSlider
                                Layout.fillWidth: true
                                from: 0
                                to: 32
                                stepSize: 1
                                value: root.nexaRounding
                                onMoved: root.setNexaRoundingRequested(Math.round(value))
                            }
                        }
                    }
                }
            }
        }
    }

    // ── RIGHT: LIVE COMPOSITOR & SHELL MOCKUP WINDOW ──────────────────────────
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
                text: "Live Compositor Preview"
                font.family: Nexa.Theme.fontFamily
                font.pixelSize: 15
                font.weight: Nexa.Theme.fontWeightBold
                color: Nexa.Theme.text
            }

            Text {
                text: "Previewing Nexa shell curvature and application window geometry simultaneously."
                font.family: Nexa.Theme.fontFamily
                font.pixelSize: 11
                color: Nexa.Theme.mutedText
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            // Desktop Canvas Mockup
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Nexa.Theme.radiusSm
                color: "#11111b"
                clip: true

                // Mini Nexa Top Bar Mockup
                Rectangle {
                    x: 10
                    y: 10
                    width: parent.width - 20
                    height: 24
                    radius: Math.min(12, root.nexaRounding)
                    color: Nexa.Theme.surfaceContainer
                    border.width: 1
                    border.color: Nexa.Theme.borderSubtle

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 6

                        // Workspaces mock pill
                        Rectangle {
                            width: 38
                            height: 14
                            radius: Math.min(7, root.nexaRounding)
                            color: Nexa.Theme.primaryContainer
                            Rectangle {
                                anchors.centerIn: parent
                                width: 8; height: 4; radius: 2; color: Nexa.Theme.primary
                            }
                        }

                        Item { Layout.fillWidth: true }

                        // Island mock pill
                        Rectangle {
                            width: 60
                            height: 16
                            radius: Math.min(8, root.nexaRounding)
                            color: Nexa.Theme.surfaceContainerHighest
                            border.width: 1
                            border.color: Nexa.Theme.border
                            Text {
                                anchors.centerIn: parent
                                text: "Nexa Shell"
                                font.pixelSize: 8
                                color: Nexa.Theme.text
                            }
                        }

                        Item { Layout.fillWidth: true }

                        // Clock mock
                        Rectangle {
                            width: 28
                            height: 14
                            radius: Math.min(7, root.nexaRounding)
                            color: Nexa.Theme.surfaceContainerHigh
                            Text {
                                anchors.centerIn: parent
                                text: root.nexaRounding + "px"
                                font.pixelSize: 8
                                font.weight: Font.Bold
                                color: Nexa.Theme.primary
                            }
                        }
                    }
                }

                // Inactive Window (Behind)
                Rectangle {
                    x: 20
                    y: 46
                    width: parent.width - 60
                    height: 120
                    radius: root.windowRounding
                    color: Qt.rgba(0.12, 0.12, 0.18, 1.0 - root.windowDim)
                    border.width: root.windowBorderSize
                    border.color: Qt.rgba(1, 1, 1, 0.15)

                    RowLayout {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: 8
                        spacing: 4

                        Rectangle { width: 6; height: 6; radius: 3; color: "#555" }
                        Rectangle { width: 6; height: 6; radius: 3; color: "#555" }
                        Rectangle { width: 6; height: 6; radius: 3; color: "#555" }

                        Item { Layout.fillWidth: true }
                        Text {
                            text: "Inactive Window"
                            font.family: Nexa.Theme.fontFamily
                            font.pixelSize: 9
                            color: "#888"
                        }
                    }
                }

                // Active Focused Window (Foreground)
                Rectangle {
                    x: 40
                    y: 90
                    width: parent.width - 60
                    height: 150
                    radius: root.windowRounding
                    color: "#1e1e2e"
                    border.width: root.windowBorderSize > 0 ? root.windowBorderSize : (root.windowRounding === 0 ? 1 : 0)
                    border.color: (root.windowBorderSize > 0 || root.windowRounding === 0) ? Nexa.Theme.primary : Qt.rgba(1, 1, 1, 0.15)

                    // Ambient glow / shadow simulator
                    Rectangle {
                        visible: root.windowGlow
                        anchors.fill: parent
                        anchors.margins: -4
                        radius: parent.radius + 4
                        z: -1
                        color: Qt.rgba(Nexa.Theme.primary.r, Nexa.Theme.primary.g, Nexa.Theme.primary.b, 0.25)
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 8

                        // Titlebar
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 5

                            Rectangle { width: 7; height: 7; radius: 3.5; color: "#ff5555" }
                            Rectangle { width: 7; height: 7; radius: 3.5; color: "#ffb86c" }
                            Rectangle { width: 7; height: 7; radius: 3.5; color: "#50fa7b" }

                            Item { Layout.fillWidth: true }

                            Text {
                                text: "Active Window"
                                font.family: Nexa.Theme.fontFamily
                                font.pixelSize: 10
                                font.weight: Nexa.Theme.fontWeightDemiBold
                                color: "#cdd6f4"
                            }
                        }

                        // Mockup Content Body
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: Math.max(0, root.windowRounding - 4)
                            color: "#181825"

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 4

                                Text {
                                    text: "App Window: " + root.windowRounding + "px"
                                    font.family: Nexa.Theme.fontFamily
                                    font.pixelSize: 11
                                    color: Nexa.Theme.text
                                }

                                Text {
                                    text: "Nexa Shell: " + root.nexaRounding + "px"
                                    font.family: Nexa.Theme.fontFamily
                                    font.pixelSize: 11
                                    font.weight: Font.Bold
                                    color: Nexa.Theme.primary
                                }

                                Text {
                                    text: "Border: " + (root.windowBorderSize === 0 ? "None" : (root.windowBorderSize + "px"))
                                    font.family: Nexa.Theme.fontFamily
                                    font.pixelSize: 10
                                    color: Nexa.Theme.mutedText
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
