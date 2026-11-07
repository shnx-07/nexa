// pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../../NewNexaUI" as NexaUI

RowLayout {
    id: root

    spacing: NexaUI.NexaTokens.spacingMd

    property string stagedStyle: "wallpaperFull"
    property string stagedMode: "dark"
    property string selectedStyle: ""
    property string selectedMode: "dark"
    property string wallpaperSource: ""

    property bool applying: false
    property bool isCurrentThemeActive: false
    property bool warmthEnabled: false
    property bool isGlassMode: NexaUI.NexaOptics.glassMode

    property color activePrimary: NexaUI.NexaColors.primary
    property color activeSecondary: NexaUI.NexaColors.secondary
    property color activeTertiary: NexaUI.NexaColors.tertiary

    signal stageStyleRequested(string style)
    signal stageModeRequested(string mode)
    signal setWarmthRequested(bool enabled)
    signal setGlassModeRequested(bool enabled)
    signal shuffleWallpaperRequested()
    signal applyRequested()

    // ── LEFT: WALLPAPER CONTROLS & DETAILS ────────────────────────────────────
    NexaUI.NexaCard {
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: NexaUI.NexaTokens.spacingLg
            spacing: NexaUI.NexaTokens.spacingLg

            Text {
                text: "Dynamic Material You Extraction"
                font.family: NexaUI.NexaTypography.familyBody
                font.pixelSize: NexaUI.NexaTypography.sizeLg
                font.weight: NexaUI.NexaTypography.weightBold
                color: NexaUI.NexaColors.text
            }

            // Style Choices (Full Wallpaper vs Accents)
            RowLayout {
                Layout.fillWidth: true
                spacing: NexaUI.NexaTokens.spacingMd

                // Card 1: Full Wallpaper
                NexaUI.NexaCard {
                    id: fullWallCard
                    Layout.fillWidth: true
                    customHeight: 90
                    customRadius: NexaUI.NexaTokens.radiusMd
                    interactive: true

                    readonly property bool isSelected: root.stagedStyle === "wallpaperFull"

                    customColor: isSelected ? NexaUI.NexaColors.alpha(NexaUI.NexaColors.primary, 0.08) : NexaUI.NexaColors.surfaceContainer
                    border.width: isSelected ? 1.5 : NexaUI.NexaTokens.borderThin
                    border.color: isSelected ? NexaUI.NexaColors.primary : NexaUI.NexaColors.border

                    onClicked: root.stageStyleRequested("wallpaperFull")

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: NexaUI.NexaTokens.spacingMd
                        spacing: NexaUI.NexaTokens.spacingMd

                        Rectangle {
                            width: 40; height: 40; radius: NexaUI.NexaTokens.radiusPill
                            color: fullWallCard.isSelected ? NexaUI.NexaColors.primary : NexaUI.NexaColors.surfaceContainerHighest
                            Text {
                                anchors.centerIn: parent
                                text: "󰸉"
                                font.family: NexaUI.NexaTypography.familyIcon
                                font.pixelSize: 20
                                color: fullWallCard.isSelected ? NexaUI.NexaColors.onPrimary : NexaUI.NexaColors.text
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                text: "Full Wallpaper Spectrum"
                                font.family: NexaUI.NexaTypography.familyBody
                                font.pixelSize: NexaUI.NexaTypography.sizeSm
                                font.weight: NexaUI.NexaTypography.weightSemiBold
                                color: NexaUI.NexaColors.text
                            }
                            Text {
                                text: "Generates primary, secondary, surface and background roles from active wallpaper."
                                font.family: NexaUI.NexaTypography.familyBody
                                font.pixelSize: NexaUI.NexaTypography.sizeXs
                                color: NexaUI.NexaColors.mutedText
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }
                        }
                    }
                }

                // Card 2: Wallpaper Accents
                NexaUI.NexaCard {
                    id: accentWallCard
                    Layout.fillWidth: true
                    customHeight: 90
                    customRadius: NexaUI.NexaTokens.radiusMd
                    interactive: true

                    readonly property bool isSelected: root.stagedStyle === "wallpaperAccents"

                    customColor: isSelected ? NexaUI.NexaColors.alpha(NexaUI.NexaColors.primary, 0.08) : NexaUI.NexaColors.surfaceContainer
                    border.width: isSelected ? 1.5 : NexaUI.NexaTokens.borderThin
                    border.color: isSelected ? NexaUI.NexaColors.primary : NexaUI.NexaColors.border

                    onClicked: root.stageStyleRequested("wallpaperAccents")

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: NexaUI.NexaTokens.spacingMd
                        spacing: NexaUI.NexaTokens.spacingMd

                        Rectangle {
                            width: 40; height: 40; radius: NexaUI.NexaTokens.radiusPill
                            color: accentWallCard.isSelected ? NexaUI.NexaColors.primary : NexaUI.NexaColors.surfaceContainerHighest
                            Text {
                                anchors.centerIn: parent
                                text: "󰸉"
                                font.family: NexaUI.NexaTypography.familyIcon
                                font.pixelSize: 20
                                color: accentWallCard.isSelected ? NexaUI.NexaColors.onPrimary : NexaUI.NexaColors.text
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                text: "Wallpaper Accents"
                                font.family: NexaUI.NexaTypography.familyBody
                                font.pixelSize: NexaUI.NexaTypography.sizeSm
                                font.weight: NexaUI.NexaTypography.weightSemiBold
                                color: NexaUI.NexaColors.text
                            }
                            Text {
                                text: "Keeps neutral dark surfaces while using wallpaper-extracted accent highlights."
                                font.family: NexaUI.NexaTypography.familyBody
                                font.pixelSize: NexaUI.NexaTypography.sizeXs
                                color: NexaUI.NexaColors.mutedText
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }
                        }
                    }
                }
            }

            // Surface & Effects Controls
            RowLayout {
                Layout.fillWidth: true
                spacing: NexaUI.NexaTokens.spacingMd

                // Glass vs Solid Surface
                NexaUI.NexaCard {
                    Layout.fillWidth: true
                    customHeight: 70
                    customRadius: NexaUI.NexaTokens.radiusMd
                    customColor: NexaUI.NexaColors.surfaceContainer

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: NexaUI.NexaTokens.spacingMd
                        spacing: NexaUI.NexaTokens.spacingSm

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                text: "Glass Transparency"
                                font.family: NexaUI.NexaTypography.familyBody
                                font.pixelSize: NexaUI.NexaTypography.sizeSm
                                font.weight: NexaUI.NexaTypography.weightSemiBold
                                color: NexaUI.NexaColors.text
                            }
                            Text {
                                text: root.isGlassMode ? "Translucent acrylic blur enabled" : "Opaque solid background surfaces"
                                font.family: NexaUI.NexaTypography.familyBody
                                font.pixelSize: NexaUI.NexaTypography.sizeXs
                                color: NexaUI.NexaColors.mutedText
                            }
                        }

                        NexaUI.NexaToggle {
                            checked: root.isGlassMode
                            onToggled: function(val) { root.setGlassModeRequested(val); }
                        }
                    }
                }

                // Night Warmth Toggle
                NexaUI.NexaCard {
                    Layout.fillWidth: true
                    customHeight: 70
                    customRadius: NexaUI.NexaTokens.radiusMd
                    customColor: NexaUI.NexaColors.surfaceContainer

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: NexaUI.NexaTokens.spacingMd
                        spacing: NexaUI.NexaTokens.spacingSm

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                text: "Night Warmth"
                                font.family: NexaUI.NexaTypography.familyBody
                                font.pixelSize: NexaUI.NexaTypography.sizeSm
                                font.weight: NexaUI.NexaTypography.weightSemiBold
                                color: NexaUI.NexaColors.text
                            }
                            Text {
                                text: root.warmthEnabled ? "Wallpaper-adaptive warm screen tint" : "Standard neutral white balance"
                                font.family: NexaUI.NexaTypography.familyBody
                                font.pixelSize: NexaUI.NexaTypography.sizeXs
                                color: NexaUI.NexaColors.mutedText
                            }
                        }

                        NexaUI.NexaToggle {
                            checked: root.warmthEnabled
                            onToggled: function(val) { root.setWarmthRequested(val); }
                        }
                    }
                }
            }

            Item { Layout.fillHeight: true }
        }
    }

    // ── RIGHT: LIVE WALLPAPER PALETTE PREVIEW HUB ─────────────────────────────
    NexaUI.NexaCard {
        Layout.preferredWidth: 320
        Layout.fillHeight: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "Extracted Palette"
                    font.family: NexaUI.NexaTypography.familyBody
                    font.pixelSize: NexaUI.NexaTypography.sizeMd
                    font.weight: NexaUI.NexaTypography.weightBold
                    color: NexaUI.NexaColors.text
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: root.stagedStyle === "wallpaperAccents" ? "Accents Only" : "Full Spectrum"
                    font.family: NexaUI.NexaTypography.familyBody
                    font.pixelSize: NexaUI.NexaTypography.sizeXs
                    color: NexaUI.NexaColors.mutedText
                }
            }

            // Mode Selector (Dark / Light) via NexaSegmentedControl
            NexaUI.NexaSegmentedControl {
                Layout.fillWidth: true
                customHeight: NexaUI.NexaTokens.controlHeightSm
                model: [
                    { id: "dark", label: "Dark", icon: "󰖔" },
                    { id: "light", label: "Light", icon: "󰖙" }
                ]
                currentId: root.stagedMode
                onSelected: function(id) { root.stageModeRequested(id); }
            }

            // Swatches List with Hex Labels
            ColumnLayout {
                Layout.fillWidth: true
                spacing: NexaUI.NexaTokens.spacingXs

                Repeater {
                    model: [
                        { name: "Primary Accent", color: root.activePrimary },
                        { name: "Secondary", color: root.activeSecondary },
                        { name: "Tertiary", color: root.activeTertiary }
                    ]

                    Rectangle {
                        id: swatchRow
                        required property var modelData
                        Layout.fillWidth: true
                        height: NexaUI.NexaTokens.controlHeightSm
                        radius: NexaUI.NexaTokens.radiusSm
                        color: NexaUI.NexaColors.surfaceContainer

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: NexaUI.NexaTokens.spacingSm
                            anchors.rightMargin: NexaUI.NexaTokens.spacingSm
                            spacing: NexaUI.NexaTokens.spacingSm

                            Rectangle {
                                width: 16; height: 16; radius: NexaUI.NexaTokens.radiusPill
                                color: swatchRow.modelData.color
                                border.width: NexaUI.NexaTokens.borderThin
                                border.color: NexaUI.NexaColors.border
                            }

                            Text {
                                text: swatchRow.modelData.name
                                font.family: NexaUI.NexaTypography.familyBody
                                font.pixelSize: NexaUI.NexaTypography.sizeSm
                                color: NexaUI.NexaColors.text
                                Layout.fillWidth: true
                            }

                            Text {
                                text: String(swatchRow.modelData.color).toUpperCase()
                                font.family: NexaUI.NexaTypography.familyMono
                                font.pixelSize: NexaUI.NexaTypography.sizeXs
                                font.weight: NexaUI.NexaTypography.weightSemiBold
                                color: NexaUI.NexaColors.mutedText
                            }
                        }
                    }
                }
            }

            Item { Layout.fillHeight: true }

            Text {
                text: root.stagedStyle === "wallpaperAccents" ? "Wallpaper Accents" : "Full Wallpaper Spectrum"
                font.family: NexaUI.NexaTypography.familyBody
                font.pixelSize: NexaUI.NexaTypography.sizeMd
                font.weight: NexaUI.NexaTypography.weightBold
                color: NexaUI.NexaColors.text
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Text {
                text: "Dynamic Material You Colors"
                font.family: NexaUI.NexaTypography.familyBody
                font.pixelSize: NexaUI.NexaTypography.sizeXs
                color: NexaUI.NexaColors.mutedText
            }

            // Apply Button using NexaButton
            NexaUI.NexaButton {
                id: applyWallBtn
                Layout.fillWidth: true
                customHeight: NexaUI.NexaTokens.controlHeightLg
                variant: root.isCurrentThemeActive ? "tonal" : "filled"
                icon: root.isCurrentThemeActive ? "✓" : "󰸉"
                text: root.applying ? "Applying..." : (root.isCurrentThemeActive ? "Active Theme" : "Apply Wallpaper Palette")
                enabled: !root.isCurrentThemeActive && !root.applying
                onClicked: root.applyRequested()
            }
        }
    }
}
