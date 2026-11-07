// pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import "../../../NewNexaUI" as NexaUI

RowLayout {
    id: root

    spacing: 14

    // ── LEFT: SHADER SELECTION & FINE-TUNING CONTROLS ─────────────────────────
    Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        radius: NexaUI.NexaTokens.radiusMd
        color: NexaUI.NexaColors.surfaceContainer
        border.width: NexaUI.NexaTokens.borderThin
        border.color: NexaUI.NexaColors.border
        clip: true

        Flickable {
            id: leftFlick
            anchors.fill: parent
            contentWidth: width
            contentHeight: leftCol.implicitHeight + 36
            boundsBehavior: Flickable.StopAtBounds
            flickDeceleration: 1500
            maximumFlickVelocity: 2500
            pixelAligned: false
            clip: true

            NexaUI.NexaSmoothScroll {}

            ScrollBar.vertical: ScrollBar {
                id: vScroll
                policy: ScrollBar.AsNeeded
                contentItem: Rectangle {
                    implicitWidth: 3
                    radius: width / 2
                    color: Qt.rgba(NexaUI.NexaColors.text.r, NexaUI.NexaColors.text.g, NexaUI.NexaColors.text.b, vScroll.hovered ? 0.45 : 0.18)
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
                    font.family: NexaUI.NexaTypography.familyBody
                    font.pixelSize: 16
                    font.weight: NexaUI.NexaTypography.weightBold
                    color: NexaUI.NexaColors.text
                }

                // ════════════════════════════════════════════════════════════
                // SECTION 1: SHADER PRESETS
                // ════════════════════════════════════════════════════════════
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: presetCol.implicitHeight + 24
                    radius: NexaUI.NexaTokens.radiusSm
                    color: NexaUI.NexaColors.surfaceContainerLow
                    border.width: NexaUI.NexaTokens.borderThin
                    border.color: NexaUI.NexaColors.border

                    ColumnLayout {
                        id: presetCol
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 10

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "Active Substrate Shader"
                                font.family: NexaUI.NexaTypography.familyBody
                                font.pixelSize: 13
                                font.weight: NexaUI.NexaTypography.weightSemiBold
                                color: NexaUI.NexaColors.text
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: NexaUI.NexaOptics.activeShader === "off" ? "Default (Off)" : "Active: " + NexaUI.NexaOptics.activeShader
                                font.family: NexaUI.NexaTypography.familyBody
                                font.pixelSize: 11
                                font.weight: NexaUI.NexaTypography.weightBold
                                color: NexaUI.NexaOptics.activeShader === "off" ? NexaUI.NexaColors.mutedText : NexaUI.NexaColors.primary
                            }
                        }

                        // Dynamic Auto-Discovered Presets Grid
                        GridLayout {
                            Layout.fillWidth: true
                            columns: 3
                            rowSpacing: 8
                            columnSpacing: 8

                            Repeater {
                                model: NexaUI.NexaOptics.shaderList

                                Rectangle {
                                    id: shaderCard
                                    required property var modelData
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 52
                                    radius: NexaUI.NexaTokens.radiusSm

                                    readonly property bool isCurrent: NexaUI.NexaOptics.activeShader === modelData.id
                                    color: isCurrent ? NexaUI.NexaColors.primaryContainer : (cardMouse.containsMouse ? NexaUI.NexaColors.surfaceContainerHigh : NexaUI.NexaColors.surfaceContainerHigh)
                                    border.width: isCurrent ? 1.5 : 1
                                    border.color: isCurrent ? NexaUI.NexaColors.primary : NexaUI.NexaColors.border

                                    RowLayout {
                                        anchors.centerIn: parent
                                        anchors.leftMargin: 10
                                        anchors.rightMargin: 10
                                        spacing: 8

                                        Text {
                                            text: shaderCard.modelData.icon || "󰄛"
                                            font.family: NexaUI.NexaTypography.familyIcon
                                            font.pixelSize: 16
                                            color: shaderCard.isCurrent ? NexaUI.NexaColors.onPrimaryContainer : NexaUI.NexaColors.primary
                                        }

                                        ColumnLayout {
                                            spacing: 1
                                            Text {
                                                text: shaderCard.modelData.name
                                                font.family: NexaUI.NexaTypography.familyBody
                                                font.pixelSize: 12
                                                font.weight: shaderCard.isCurrent ? NexaUI.NexaTypography.weightBold : NexaUI.NexaTypography.weightMedium
                                                color: shaderCard.isCurrent ? NexaUI.NexaColors.onPrimaryContainer : NexaUI.NexaColors.text
                                                elide: Text.ElideRight
                                            }
                                            Text {
                                                text: shaderCard.modelData.subtitle
                                                font.family: NexaUI.NexaTypography.familyBody
                                                font.pixelSize: 9
                                                color: shaderCard.isCurrent ? NexaUI.NexaColors.onPrimaryContainer : NexaUI.NexaColors.mutedText
                                                elide: Text.ElideRight
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: cardMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: NexaUI.NexaOptics.setShader(shaderCard.modelData.id)
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
                    radius: NexaUI.NexaTokens.radiusSm
                    color: NexaUI.NexaColors.surfaceContainerLow
                    border.width: NexaUI.NexaTokens.borderThin
                    border.color: NexaUI.NexaColors.border
                    opacity: NexaUI.NexaOptics.activeShader !== "off" ? 1.0 : 0.45

                    ColumnLayout {
                        id: slidersCol
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 14

                        Text {
                            text: "Shader Optics & Tuning"
                            font.family: NexaUI.NexaTypography.familyBody
                            font.pixelSize: 13
                            font.weight: NexaUI.NexaTypography.weightSemiBold
                            color: NexaUI.NexaColors.text
                        }

                        // 1. Opacity Slider
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: "Surface Opacity"
                                    font.family: NexaUI.NexaTypography.familyBody
                                    font.pixelSize: 11
                                    font.weight: NexaUI.NexaTypography.weightSemiBold
                                    color: NexaUI.NexaColors.text
                                }
                                Item { Layout.fillWidth: true }
                                Text {
                                    text: Math.round(NexaUI.NexaOptics.shaderOpacity * 100) + "%"
                                    font.family: NexaUI.NexaTypography.familyMono
                                    font.pixelSize: 11
                                    color: NexaUI.NexaColors.primary
                                }
                            }

                            NexaUI.NexaSlider {
                                Layout.fillWidth: true
                                sliderHeight: 26
                                from: 0.1
                                to: 1.0
                                stepSize: 0.05
                                value: NexaUI.NexaOptics.shaderOpacity
                                icon: "󰂵"
                                iconPosition: "left"
                                onMoved: val => {
                                    NexaUI.NexaOptics.shaderOpacity = val;
                                    NexaUI.NexaOptics.saveShaderConfig();
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
                                    font.family: NexaUI.NexaTypography.familyBody
                                    font.pixelSize: 11
                                    font.weight: NexaUI.NexaTypography.weightSemiBold
                                    color: NexaUI.NexaColors.text
                                }
                                Item { Layout.fillWidth: true }
                                Text {
                                    text: NexaUI.NexaOptics.shaderSpeed.toFixed(1) + "x"
                                    font.family: NexaUI.NexaTypography.familyMono
                                    font.pixelSize: 11
                                    color: NexaUI.NexaColors.primary
                                }
                            }

                            NexaUI.NexaSlider {
                                Layout.fillWidth: true
                                sliderHeight: 26
                                from: 0.1
                                to: 3.0
                                stepSize: 0.1
                                value: NexaUI.NexaOptics.shaderSpeed
                                icon: "󱐋"
                                iconPosition: "left"
                                onMoved: val => {
                                    NexaUI.NexaOptics.shaderSpeed = val;
                                    NexaUI.NexaOptics.saveShaderConfig();
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
                                    font.family: NexaUI.NexaTypography.familyBody
                                    font.pixelSize: 11
                                    font.weight: NexaUI.NexaTypography.weightSemiBold
                                    color: NexaUI.NexaColors.text
                                }
                                Item { Layout.fillWidth: true }
                                Text {
                                    text: Math.round(NexaUI.NexaOptics.shaderIntensity * 100) + "%"
                                    font.family: NexaUI.NexaTypography.familyMono
                                    font.pixelSize: 11
                                    color: NexaUI.NexaColors.primary
                                }
                            }

                            NexaUI.NexaSlider {
                                Layout.fillWidth: true
                                sliderHeight: 26
                                from: 0.1
                                to: 1.0
                                stepSize: 0.05
                                value: NexaUI.NexaOptics.shaderIntensity
                                icon: "󰅒"
                                iconPosition: "left"
                                onMoved: val => {
                                    NexaUI.NexaOptics.shaderIntensity = val;
                                    NexaUI.NexaOptics.saveShaderConfig();
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
                                    font.family: NexaUI.NexaTypography.familyBody
                                    font.pixelSize: 11
                                    font.weight: NexaUI.NexaTypography.weightSemiBold
                                    color: NexaUI.NexaColors.text
                                }
                                Item { Layout.fillWidth: true }
                                Text {
                                    text: Math.round(NexaUI.NexaOptics.shaderContrastVeil * 100) + "%"
                                    font.family: NexaUI.NexaTypography.familyMono
                                    font.pixelSize: 11
                                    color: NexaUI.NexaColors.primary
                                }
                            }

                            NexaUI.NexaSlider {
                                Layout.fillWidth: true
                                sliderHeight: 26
                                from: 0.0
                                to: 0.8
                                stepSize: 0.05
                                value: NexaUI.NexaOptics.shaderContrastVeil
                                icon: "󰌵"
                                iconPosition: "left"
                                onMoved: val => {
                                    NexaUI.NexaOptics.shaderContrastVeil = val;
                                    NexaUI.NexaOptics.saveShaderConfig();
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
                    radius: NexaUI.NexaTokens.radiusSm
                    color: NexaUI.NexaColors.surfaceContainerLow
                    border.width: NexaUI.NexaTokens.borderThin
                    border.color: NexaUI.NexaColors.border

                    RowLayout {
                        id: effRow
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 12

                        Text {
                            text: "󰾆"
                            font.family: NexaUI.NexaTypography.familyIcon
                            font.pixelSize: 18
                            color: NexaUI.NexaColors.primary
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            Text {
                                text: "Pause GPU Animation When Window is Hidden"
                                font.family: NexaUI.NexaTypography.familyBody
                                font.pixelSize: 12
                                font.weight: NexaUI.NexaTypography.weightSemiBold
                                color: NexaUI.NexaColors.text
                            }

                            Text {
                                text: "Drops GPU consumption to strictly 0% when windows are minimized or closed"
                                font.family: NexaUI.NexaTypography.familyBody
                                font.pixelSize: 10
                                color: NexaUI.NexaColors.mutedText
                            }
                        }

                        NexaUI.NexaToggle {
                            checked: NexaUI.NexaOptics.shaderPauseWhenHidden
                            onToggled: {
                                NexaUI.NexaOptics.shaderPauseWhenHidden = checked;
                                NexaUI.NexaOptics.saveShaderConfig();
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
        radius: NexaUI.NexaTokens.radiusMd
        color: NexaUI.NexaColors.surfaceContainer
        border.width: NexaUI.NexaTokens.borderThin
        border.color: NexaUI.NexaColors.border
        clip: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 14

            Text {
                text: "Live Material Preview"
                font.family: NexaUI.NexaTypography.familyBody
                font.pixelSize: 14
                font.weight: NexaUI.NexaTypography.weightBold
                color: NexaUI.NexaColors.text
            }

            // Real Interactive Shader Substrate Preview Box
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: NexaUI.NexaTokens.radiusSm
                color: NexaUI.NexaColors.surfaceContainerLow
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
                            font.family: NexaUI.NexaTypography.familyBody
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
                                Text { text: "󰄛"; font.family: NexaUI.NexaTypography.familyIcon; font.pixelSize: 14; color: NexaUI.NexaColors.primary }
                                Text {
                                    text: NexaUI.NexaOptics.shaderName(NexaUI.NexaOptics.activeShader)
                                    font.family: NexaUI.NexaTypography.familyBody
                                    font.pixelSize: 12
                                    font.weight: Font.Bold
                                    color: "#ffffff"
                                }
                            }

                            Text {
                                text: "Text contrast is mathematically preserved over the live GPU caustics."
                                font.family: NexaUI.NexaTypography.familyBody
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
                        color: NexaUI.NexaOptics.activeShader === "off" ? Qt.rgba(255, 255, 255, 0.05) : Qt.rgba(239, 68, 68, 0.2)
                        border.width: 1
                        border.color: NexaUI.NexaOptics.activeShader === "off" ? Qt.rgba(255, 255, 255, 0.1) : "#ef4444"

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                text: "󰛐"
                                font.family: NexaUI.NexaTypography.familyIcon
                                font.pixelSize: 12
                                color: NexaUI.NexaOptics.activeShader === "off" ? Qt.rgba(255, 255, 255, 0.5) : "#ef4444"
                            }
                            Text {
                                text: NexaUI.NexaOptics.activeShader === "off" ? "Running Default" : "Revert to Default (Off)"
                                font.family: NexaUI.NexaTypography.familyBody
                                font.pixelSize: 11
                                font.weight: Font.Medium
                                color: NexaUI.NexaOptics.activeShader === "off" ? Qt.rgba(255, 255, 255, 0.6) : "#ffffff"
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: NexaUI.NexaOptics.activeShader !== "off"
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: NexaUI.NexaOptics.setShader("off")
                        }
                    }
                }
            }
        }
    }
}

