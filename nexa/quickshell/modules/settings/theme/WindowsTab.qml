// pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../../theme" as Nexa

RowLayout {
    id: root

    spacing: 14

    property int windowRounding: Nexa.Theme.windowRounding
    property int windowBorderSize: Nexa.Theme.windowBorderSize
    property bool windowGlow: true
    property real windowDim: 0.0

    signal setRoundingRequested(int r)
    signal setBorderSizeRequested(int b)
    signal setWindowGlowRequested(bool on)
    signal setWindowDimRequested(real dim)

    // ── LEFT: COMPOSITOR STYLING CONTROLS ─────────────────────────────────────
    Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        radius: Nexa.Theme.radiusMd
        color: Nexa.Theme.cardBackground
        border.width: Nexa.Theme.borderThin
        border.color: Nexa.Theme.border
        clip: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 16

            Text {
                text: "Window Aesthetics & Compositor"
                font.family: Nexa.Theme.fontFamily
                font.pixelSize: 16
                font.weight: Nexa.Theme.fontWeightBold
                color: Nexa.Theme.text
            }

            // 1. Corner Rounding Section
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "Corner Rounding Radius"
                        font.family: Nexa.Theme.fontFamily
                        font.pixelSize: 13
                        font.weight: Nexa.Theme.fontWeightDemiBold
                        color: Nexa.Theme.text
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: root.windowRounding + "px"
                        font.family: Nexa.Theme.fontFamily
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
                            { label: "0px Sharp", val: 0 },
                            { label: "8px Subtle", val: 8 },
                            { label: "14px Modern", val: 14 },
                            { label: "22px Round", val: 22 }
                        ]

                        Rectangle {
                            id: roundPill
                            required property var modelData
                            Layout.fillWidth: true
                            height: 36
                            radius: Nexa.Theme.radiusSm
                            readonly property bool isCurrent: root.windowRounding === roundPill.modelData.val
                            color: isCurrent ? Nexa.Theme.primaryContainer : (roundMouse.containsMouse ? Nexa.Theme.hover : Nexa.Theme.surfaceContainer)
                            border.width: isCurrent ? 1 : 0
                            border.color: isCurrent ? Nexa.Theme.primary : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: roundPill.modelData.label
                                font.family: Nexa.Theme.fontFamily
                                font.pixelSize: 12
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
            }

            // 2. Window Border Width Section
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "Window Border Width"
                        font.family: Nexa.Theme.fontFamily
                        font.pixelSize: 13
                        font.weight: Nexa.Theme.fontWeightDemiBold
                        color: Nexa.Theme.text
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: root.windowBorderSize === 0 ? "Borderless" : (root.windowBorderSize + "px")
                        font.family: Nexa.Theme.fontFamily
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
                            { label: "0px None", val: 0 },
                            { label: "1px Hairline", val: 1 },
                            { label: "2px Defined", val: 2 },
                            { label: "3px Bold", val: 3 }
                        ]

                        Rectangle {
                            id: borderPill
                            required property var modelData
                            Layout.fillWidth: true
                            height: 36
                            radius: Nexa.Theme.radiusSm
                            readonly property bool isCurrent: root.windowBorderSize === borderPill.modelData.val
                            color: isCurrent ? Nexa.Theme.primaryContainer : (bMouse.containsMouse ? Nexa.Theme.hover : Nexa.Theme.surfaceContainer)
                            border.width: isCurrent ? 1 : 0
                            border.color: isCurrent ? Nexa.Theme.primary : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: borderPill.modelData.label
                                font.family: Nexa.Theme.fontFamily
                                font.pixelSize: 12
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
            }

            // 3. Drop Shadow & Glow Switch
            Rectangle {
                Layout.fillWidth: true
                height: 70
                radius: Nexa.Theme.radiusSm
                color: Nexa.Theme.surfaceContainer
                border.width: 1
                border.color: Nexa.Theme.border

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 12

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            text: "Drop Shadow & Ambient Glow"
                            font.family: Nexa.Theme.fontFamily
                            font.pixelSize: 13
                            font.weight: Nexa.Theme.fontWeightDemiBold
                            color: Nexa.Theme.text
                        }
                        Text {
                            text: root.windowGlow ? "Soft 30px ambient compositor drop shadow" : "Shadows disabled for a flat, lightweight look"
                            font.family: Nexa.Theme.fontFamily
                            font.pixelSize: 11
                            color: Nexa.Theme.mutedText
                        }
                    }

                    Rectangle {
                        width: 44; height: 24; radius: 12
                        color: root.windowGlow ? Nexa.Theme.primary : Nexa.Theme.surfaceContainerHighest

                        Rectangle {
                            width: 18; height: 18; radius: 9
                            y: 3
                            x: root.windowGlow ? 23 : 3
                            color: root.windowGlow ? Nexa.Theme.onPrimary : Nexa.Theme.mutedText
                            Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.setWindowGlowRequested(!root.windowGlow)
                        }
                    }
                }
            }

            // 4. Inactive Window Dimming
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "Inactive Window Dimming"
                        font.family: Nexa.Theme.fontFamily
                        font.pixelSize: 13
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
                    spacing: 8

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
                            height: 36
                            radius: Nexa.Theme.radiusSm
                            readonly property bool isCurrent: Math.abs(root.windowDim - dimPill.modelData.val) < 0.01
                            color: isCurrent ? Nexa.Theme.primaryContainer : (dMouse.containsMouse ? Nexa.Theme.hover : Nexa.Theme.surfaceContainer)
                            border.width: isCurrent ? 1 : 0
                            border.color: isCurrent ? Nexa.Theme.primary : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: dimPill.modelData.label
                                font.family: Nexa.Theme.fontFamily
                                font.pixelSize: 12
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

            Item { Layout.fillHeight: true }
        }
    }

    // ── RIGHT: LIVE COMPOSITOR MOCKUP WINDOW ──────────────────────────────────
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
                text: "Previewing window geometry, border styling, and focus states."
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

                // Inactive Window (Behind)
                Rectangle {
                    x: 20
                    y: 20
                    width: parent.width - 60
                    height: 140
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
                    y: 70
                    width: parent.width - 60
                    height: 160
                    radius: root.windowRounding
                    color: "#1e1e2e"
                    border.width: root.windowBorderSize > 0 ? root.windowBorderSize : 1
                    border.color: root.windowBorderSize > 0 ? Nexa.Theme.primary : Qt.rgba(1, 1, 1, 0.15)

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
                                spacing: 6

                                Text {
                                    text: "Rounding: " + root.windowRounding + "px"
                                    font.family: Nexa.Theme.fontFamily
                                    font.pixelSize: 11
                                    color: Nexa.Theme.text
                                }

                                Text {
                                    text: "Border: " + (root.windowBorderSize === 0 ? "None" : (root.windowBorderSize + "px"))
                                    font.family: Nexa.Theme.fontFamily
                                    font.pixelSize: 11
                                    color: Nexa.Theme.primary
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

