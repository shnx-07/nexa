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

    // ── LEFT: SHADER SELECTION & FINE-TUNING CONTROLS ─────────────────────────
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
                    text: "Window Shaders & Surface Materials"
                    font.family: Nexa.Theme.fontFamily
                    font.pixelSize: 16
                    font.weight: Nexa.Theme.fontWeightBold
                    color: Nexa.Theme.text
                }

                // ════════════════════════════════════════════════════════════
                // SECTION 1: SHADER PRESETS
                // ════════════════════════════════════════════════════════════
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: presetCol.implicitHeight + 24
                    radius: Nexa.Theme.radiusSm
                    color: Nexa.Theme.cardBackgroundSubtle
                    border.width: Nexa.Theme.borderThin
                    border.color: Nexa.Theme.border

                    ColumnLayout {
                        id: presetCol
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 10

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "Active Substrate Shader"
                                font.family: Nexa.Theme.fontFamily
                                font.pixelSize: 13
                                font.weight: Nexa.Theme.fontWeightDemiBold
                                color: Nexa.Theme.text
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: Nexa.Theme.activeShader === "off" ? "Default (Off)" : "Active: " + Nexa.Theme.activeShader
                                font.family: Nexa.Theme.fontFamily
                                font.pixelSize: 11
                                font.weight: Nexa.Theme.fontWeightBold
                                color: Nexa.Theme.activeShader === "off" ? Nexa.Theme.mutedText : Nexa.Theme.primary
                            }
                        }

                        // Dynamic Auto-Discovered Presets Grid
                        GridLayout {
                            Layout.fillWidth: true
                            columns: 3
                            rowSpacing: 8
                            columnSpacing: 8

                            Repeater {
                                model: Nexa.Theme.shaderList

                                Rectangle {
                                    id: shaderCard
                                    required property var modelData
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 52
                                    radius: Nexa.Theme.radiusSm

                                    readonly property bool isCurrent: Nexa.Theme.activeShader === modelData.id
                                    color: isCurrent ? Nexa.Theme.primaryContainer : (cardMouse.containsMouse ? Nexa.Theme.hover : Nexa.Theme.surfaceContainerHigh)
                                    border.width: isCurrent ? 1.5 : 1
                                    border.color: isCurrent ? Nexa.Theme.primary : Nexa.Theme.border

                                    RowLayout {
                                        anchors.centerIn: parent
                                        anchors.leftMargin: 10
                                        anchors.rightMargin: 10
                                        spacing: 8

                                        Text {
                                            text: shaderCard.modelData.icon || "󰄛"
                                            font.family: Nexa.Theme.iconFontFamily
                                            font.pixelSize: 16
                                            color: shaderCard.isCurrent ? Nexa.Theme.onPrimaryContainer : Nexa.Theme.primary
                                        }

                                        ColumnLayout {
                                            spacing: 1
                                            Text {
                                                text: shaderCard.modelData.name
                                                font.family: Nexa.Theme.fontFamily
                                                font.pixelSize: 12
                                                font.weight: shaderCard.isCurrent ? Nexa.Theme.fontWeightBold : Nexa.Theme.fontWeightMedium
                                                color: shaderCard.isCurrent ? Nexa.Theme.onPrimaryContainer : Nexa.Theme.text
                                                elide: Text.ElideRight
                                            }
                                            Text {
                                                text: shaderCard.modelData.subtitle
                                                font.family: Nexa.Theme.fontFamily
                                                font.pixelSize: 9
                                                color: shaderCard.isCurrent ? Nexa.Theme.onPrimaryContainer : Nexa.Theme.mutedText
                                                elide: Text.ElideRight
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: cardMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: Nexa.Theme.setShader(shaderCard.modelData.id)
                                    }
                                }
                            }
                        }
                    }
                }

                // ════════════════════════════════════════════════════════════
                // SECTION 2: FINE-TUNING SLIDERS
                // ════════════════════════════════════════════════════════════
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: slidersCol.implicitHeight + 24
                    radius: Nexa.Theme.radiusSm
                    color: Nexa.Theme.cardBackgroundSubtle
                    border.width: Nexa.Theme.borderThin
                    border.color: Nexa.Theme.border
                    opacity: Nexa.Theme.activeShader !== "off" ? 1.0 : 0.45

                    ColumnLayout {
                        id: slidersCol
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 14

                        Text {
                            text: "Shader Optics & Tuning"
                            font.family: Nexa.Theme.fontFamily
                            font.pixelSize: 13
                            font.weight: Nexa.Theme.fontWeightDemiBold
                            color: Nexa.Theme.text
                        }

                        // 1. Opacity Slider
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: "Surface Opacity"
                                    font.family: Nexa.Theme.fontFamily
                                    font.pixelSize: 11
                                    font.weight: Nexa.Theme.fontWeightDemiBold
                                    color: Nexa.Theme.text
                                }
                                Item { Layout.fillWidth: true }
                                Text {
                                    text: Math.round(Nexa.Theme.shaderOpacity * 100) + "%"
                                    font.family: Nexa.Theme.monoFontFamily
                                    font.pixelSize: 11
                                    color: Nexa.Theme.primary
                                }
                            }

                            NexaUI.NexaSlider {
                                Layout.fillWidth: true
                                sliderHeight: 26
                                from: 0.1
                                to: 1.0
                                stepSize: 0.05
                                value: Nexa.Theme.shaderOpacity
                                icon: "󰂵"
                                iconPosition: "left"
                                onMoved: val => {
                                    Nexa.Theme.shaderOpacity = val;
                                    Nexa.Theme.saveShaderConfig();
                                }
                            }
                        }

                        // 2. Animation Speed Slider
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: "Flow Speed"
                                    font.family: Nexa.Theme.fontFamily
                                    font.pixelSize: 11
                                    font.weight: Nexa.Theme.fontWeightDemiBold
                                    color: Nexa.Theme.text
                                }
                                Item { Layout.fillWidth: true }
                                Text {
                                    text: Nexa.Theme.shaderSpeed.toFixed(1) + "x"
                                    font.family: Nexa.Theme.monoFontFamily
                                    font.pixelSize: 11
                                    color: Nexa.Theme.primary
                                }
                            }

                            NexaUI.NexaSlider {
                                Layout.fillWidth: true
                                sliderHeight: 26
                                from: 0.1
                                to: 3.0
                                stepSize: 0.1
                                value: Nexa.Theme.shaderSpeed
                                icon: "󱐋"
                                iconPosition: "left"
                                onMoved: val => {
                                    Nexa.Theme.shaderSpeed = val;
                                    Nexa.Theme.saveShaderConfig();
                                }
                            }
                        }

                        // 3. Caustic Intensity Slider
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: "Caustic Refraction Intensity"
                                    font.family: Nexa.Theme.fontFamily
                                    font.pixelSize: 11
                                    font.weight: Nexa.Theme.fontWeightDemiBold
                                    color: Nexa.Theme.text
                                }
                                Item { Layout.fillWidth: true }
                                Text {
                                    text: Math.round(Nexa.Theme.shaderIntensity * 100) + "%"
                                    font.family: Nexa.Theme.monoFontFamily
                                    font.pixelSize: 11
                                    color: Nexa.Theme.primary
                                }
                            }

                            NexaUI.NexaSlider {
                                Layout.fillWidth: true
                                sliderHeight: 26
                                from: 0.1
                                to: 1.0
                                stepSize: 0.05
                                value: Nexa.Theme.shaderIntensity
                                icon: "󰅒"
                                iconPosition: "left"
                                onMoved: val => {
                                    Nexa.Theme.shaderIntensity = val;
                                    Nexa.Theme.saveShaderConfig();
                                }
                            }
                        }

                        // 4. Contrast Veil Darkening
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: "Text Contrast Veil (Background Darkening)"
                                    font.family: Nexa.Theme.fontFamily
                                    font.pixelSize: 11
                                    font.weight: Nexa.Theme.fontWeightDemiBold
                                    color: Nexa.Theme.text
                                }
                                Item { Layout.fillWidth: true }
                                Text {
                                    text: Math.round(Nexa.Theme.shaderContrastVeil * 100) + "%"
                                    font.family: Nexa.Theme.monoFontFamily
                                    font.pixelSize: 11
                                    color: Nexa.Theme.primary
                                }
                            }

                            NexaUI.NexaSlider {
                                Layout.fillWidth: true
                                sliderHeight: 26
                                from: 0.0
                                to: 0.8
                                stepSize: 0.05
                                value: Nexa.Theme.shaderContrastVeil
                                icon: "󰌵"
                                iconPosition: "left"
                                onMoved: val => {
                                    Nexa.Theme.shaderContrastVeil = val;
                                    Nexa.Theme.saveShaderConfig();
                                }
                            }
                        }
                    }
                }

                // ════════════════════════════════════════════════════════════
                // SECTION 3: EFFICIENCY & POWER MANAGEMENT
                // ════════════════════════════════════════════════════════════
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: effRow.implicitHeight + 20
                    radius: Nexa.Theme.radiusSm
                    color: Nexa.Theme.cardBackgroundSubtle
                    border.width: Nexa.Theme.borderThin
                    border.color: Nexa.Theme.border

                    RowLayout {
                        id: effRow
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 12

                        Text {
                            text: "󰾆"
                            font.family: Nexa.Theme.iconFontFamily
                            font.pixelSize: 18
                            color: Nexa.Theme.primary
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            Text {
                                text: "Pause GPU Animation When Window is Hidden"
                                font.family: Nexa.Theme.fontFamily
                                font.pixelSize: 12
                                font.weight: Nexa.Theme.fontWeightDemiBold
                                color: Nexa.Theme.text
                            }

                            Text {
                                text: "Drops GPU consumption to strictly 0% when windows are minimized or closed"
                                font.family: Nexa.Theme.fontFamily
                                font.pixelSize: 10
                                color: Nexa.Theme.mutedText
                            }
                        }

                        NexaUI.NexaToggle {
                            checked: Nexa.Theme.shaderPauseWhenHidden
                            onToggled: {
                                Nexa.Theme.shaderPauseWhenHidden = checked;
                                Nexa.Theme.saveShaderConfig();
                            }
                        }
                    }
                }
            }
        }
    }

    // ── RIGHT: LIVE INTERACTIVE PREVIEW CARD ──────────────────────────────────
    Rectangle {
        Layout.preferredWidth: 340
        Layout.fillHeight: true
        radius: Nexa.Theme.radiusMd
        color: Nexa.Theme.cardBackground
        border.width: Nexa.Theme.borderThin
        border.color: Nexa.Theme.border
        clip: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 14

            Text {
                text: "Live Material Preview"
                font.family: Nexa.Theme.fontFamily
                font.pixelSize: 14
                font.weight: Nexa.Theme.fontWeightBold
                color: Nexa.Theme.text
            }

            // Real Interactive Shader Substrate Preview Box
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Nexa.Theme.radiusSm
                color: Nexa.Theme.glassSurfaceDark || "#10141d"
                border.width: 1
                border.color: Qt.rgba(255, 255, 255, 0.12)
                clip: true

                // Active Substrate Layer (z: 0)
                NexaUI.NexaShaderSubstrate {
                    anchors.fill: parent
                    radius: parent.radius
                }

                // Foreground Content (z: 1)
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12
                    z: 1

                    // Mini window header
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Rectangle { width: 8; height: 8; radius: 4; color: "#ff5f57" }
                        Rectangle { width: 8; height: 8; radius: 4; color: "#febc2e" }
                        Rectangle { width: 8; height: 8; radius: 4; color: "#28c840" }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: "NEXA Glass"
                            font.family: Nexa.Theme.fontFamily
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            color: Qt.rgba(255, 255, 255, 0.6)
                        }
                    }

                    Item { Layout.fillHeight: true }

                    // Sample Foreground Card
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: cardInner.implicitHeight + 20
                        radius: 8
                        color: Qt.rgba(15 / 255, 19 / 255, 28 / 255, 0.75)
                        border.width: 1
                        border.color: Qt.rgba(255, 255, 255, 0.1)

                        ColumnLayout {
                            id: cardInner
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 4

                            RowLayout {
                                Text { text: "󰄛"; font.family: Nexa.Theme.iconFontFamily; font.pixelSize: 14; color: Nexa.Theme.primary }
                                Text {
                                    text: Nexa.Theme.shaderName(Nexa.Theme.activeShader)
                                    font.family: Nexa.Theme.fontFamily
                                    font.pixelSize: 12
                                    font.weight: Font.Bold
                                    color: "#ffffff"
                                }
                            }

                            Text {
                                text: "Text contrast is mathematically preserved over the live GPU caustics."
                                font.family: Nexa.Theme.fontFamily
                                font.pixelSize: 10
                                color: Qt.rgba(255, 255, 255, 0.7)
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }

                    // Revert Button
                    Rectangle {
                        Layout.fillWidth: true
                        height: 34
                        radius: 7
                        color: Nexa.Theme.activeShader === "off" ? Qt.rgba(255, 255, 255, 0.05) : Qt.rgba(239, 68, 68, 0.2)
                        border.width: 1
                        border.color: Nexa.Theme.activeShader === "off" ? Qt.rgba(255, 255, 255, 0.1) : "#ef4444"

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                text: "󰛐"
                                font.family: Nexa.Theme.iconFontFamily
                                font.pixelSize: 12
                                color: Nexa.Theme.activeShader === "off" ? Qt.rgba(255, 255, 255, 0.5) : "#ef4444"
                            }
                            Text {
                                text: Nexa.Theme.activeShader === "off" ? "Running Default" : "Revert to Default (Off)"
                                font.family: Nexa.Theme.fontFamily
                                font.pixelSize: 11
                                font.weight: Font.Medium
                                color: Nexa.Theme.activeShader === "off" ? Qt.rgba(255, 255, 255, 0.6) : "#ffffff"
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: Nexa.Theme.activeShader !== "off"
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: Nexa.Theme.setShader("off")
                        }
                    }
                }
            }
        }
    }
}

