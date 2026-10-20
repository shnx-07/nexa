// pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../theme" as Nexa

RowLayout {
    id: root

    spacing: 14

    property string stagedStyle: "wallpaperFull"
    property string stagedMode: "dark"
    property string selectedStyle: ""
    property string selectedMode: "dark"
    property string wallpaperSource: ""

    property bool applying: false
    property bool isCurrentThemeActive: false
    property bool warmthEnabled: false
    property bool isGlassMode: Nexa.Theme.glassMode

    property color activePrimary: Nexa.Theme.primary
    property color activeSecondary: Nexa.Theme.secondary
    property color activeTertiary: Nexa.Theme.tertiary

    signal stageStyleRequested(string style)
    signal stageModeRequested(string mode)
    signal setWarmthRequested(bool enabled)
    signal setGlassModeRequested(bool enabled)
    signal shuffleWallpaperRequested()
    signal applyRequested()

    // ── LEFT: WALLPAPER CONTROLS & DETAILS ────────────────────────────────────
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
                text: "Dynamic Material You Extraction"
                font.family: Nexa.Theme.fontFamily
                font.pixelSize: 16
                font.weight: Nexa.Theme.fontWeightBold
                color: Nexa.Theme.text
            }

            // Style Choices (Full Wallpaper vs Accents)
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                // Card 1: Full Wallpaper
                Rectangle {
                    id: fullWallCard
                    Layout.fillWidth: true
                    height: 90
                    radius: Nexa.Theme.radiusSm

                    readonly property bool isSelected: root.stagedStyle === "wallpaperFull"

                    color: isSelected ? Qt.rgba(Nexa.Theme.primary.r, Nexa.Theme.primary.g, Nexa.Theme.primary.b, 0.08) : Nexa.Theme.surfaceContainer
                    border.width: isSelected ? 1.5 : 1
                    border.color: isSelected ? Nexa.Theme.primary : Nexa.Theme.border

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 14

                        Rectangle {
                            width: 40; height: 40; radius: 20
                            color: fullWallCard.isSelected ? Nexa.Theme.primary : Nexa.Theme.surfaceContainerHighest
                            Text {
                                anchors.centerIn: parent
                                text: "󰸉"
                                font.family: Nexa.Theme.iconFontFamily
                                font.pixelSize: 20
                                color: fullWallCard.isSelected ? Nexa.Theme.onPrimary : Nexa.Theme.text
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                text: "Full Wallpaper Spectrum"
                                font.family: Nexa.Theme.fontFamily
                                font.pixelSize: 13
                                font.weight: Nexa.Theme.fontWeightDemiBold
                                color: Nexa.Theme.text
                            }
                            Text {
                                text: "Generates primary, secondary, surface and background roles from active wallpaper."
                                font.family: Nexa.Theme.fontFamily
                                font.pixelSize: 11
                                color: Nexa.Theme.mutedText
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.stageStyleRequested("wallpaperFull")
                    }
                }

                // Card 2: Wallpaper Accents
                Rectangle {
                    id: accentWallCard
                    Layout.fillWidth: true
                    height: 90
                    radius: Nexa.Theme.radiusSm

                    readonly property bool isSelected: root.stagedStyle === "wallpaperAccents"

                    color: isSelected ? Qt.rgba(Nexa.Theme.primary.r, Nexa.Theme.primary.g, Nexa.Theme.primary.b, 0.08) : Nexa.Theme.surfaceContainer
                    border.width: isSelected ? 1.5 : 1
                    border.color: isSelected ? Nexa.Theme.primary : Nexa.Theme.border

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 14

                        Rectangle {
                            width: 40; height: 40; radius: 20
                            color: accentWallCard.isSelected ? Nexa.Theme.primary : Nexa.Theme.surfaceContainerHighest
                            Text {
                                anchors.centerIn: parent
                                text: "󰸉"
                                font.family: Nexa.Theme.iconFontFamily
                                font.pixelSize: 20
                                color: accentWallCard.isSelected ? Nexa.Theme.onPrimary : Nexa.Theme.text
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                text: "Wallpaper Accents"
                                font.family: Nexa.Theme.fontFamily
                                font.pixelSize: 13
                                font.weight: Nexa.Theme.fontWeightDemiBold
                                color: Nexa.Theme.text
                            }
                            Text {
                                text: "Keeps neutral dark surfaces while using wallpaper-extracted accent highlights."
                                font.family: Nexa.Theme.fontFamily
                                font.pixelSize: 11
                                color: Nexa.Theme.mutedText
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.stageStyleRequested("wallpaperAccents")
                    }
                }
            }

            // Current Wallpaper Card with Shuffle Button
            Rectangle {
                Layout.fillWidth: true
                height: 160
                radius: Nexa.Theme.radiusSm
                color: Nexa.Theme.surfaceContainer
                border.width: 1
                border.color: Nexa.Theme.border
                clip: true

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 16

                    // Wallpaper Preview Thumbnail
                    Rectangle {
                        Layout.preferredWidth: 200
                        Layout.fillHeight: true
                        radius: Nexa.Theme.radiusXs
                        color: Nexa.Theme.surfaceContainerHighest
                        clip: true

                        Image {
                            anchors.fill: parent
                            source: root.wallpaperSource ? ("file://" + root.wallpaperSource) : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: false
                        }

                        Rectangle {
                            anchors.fill: parent
                            color: "transparent"
                            border.width: 1
                            border.color: Qt.rgba(1, 1, 1, 0.1)
                            radius: parent.radius
                        }
                    }

                    // Wallpaper Info & Shuffle
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: "Active Desktop Background"
                            font.family: Nexa.Theme.fontFamily
                            font.pixelSize: 14
                            font.weight: Nexa.Theme.fontWeightBold
                            color: Nexa.Theme.text
                        }

                        Text {
                            text: root.wallpaperSource ? root.wallpaperSource.split("/").pop() : "Current Wallpaper"
                            font.family: Nexa.Theme.fontFamily
                            font.pixelSize: 12
                            color: Nexa.Theme.mutedText
                            elide: Text.ElideMiddle
                            Layout.fillWidth: true
                        }

                        Item { Layout.fillHeight: true }

                        // Shuffle Button
                        Rectangle {
                            height: 36
                            width: shuffleRow.implicitWidth + 24
                            radius: Nexa.Theme.radiusSm
                            color: shuffleMouse.containsMouse ? Nexa.Theme.hover : Nexa.Theme.surfaceContainerHighest
                            border.width: 1
                            border.color: Nexa.Theme.border

                            Row {
                                id: shuffleRow
                                anchors.centerIn: parent
                                spacing: 8
                                Text {
                                    text: "󰒝"
                                    font.family: Nexa.Theme.iconFontFamily
                                    font.pixelSize: 14
                                    color: Nexa.Theme.primary
                                }
                                Text {
                                    text: "Shuffle Next Wallpaper"
                                    font.family: Nexa.Theme.fontFamily
                                    font.pixelSize: 12
                                    font.weight: Nexa.Theme.fontWeightDemiBold
                                    color: Nexa.Theme.text
                                }
                            }

                            MouseArea {
                                id: shuffleMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.shuffleWallpaperRequested()
                            }
                        }
                    }
                }
            }

            // Surface & Effects Controls
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                // Glass vs Solid Surface
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
                                text: "Glass Transparency"
                                font.family: Nexa.Theme.fontFamily
                                font.pixelSize: 13
                                font.weight: Nexa.Theme.fontWeightDemiBold
                                color: Nexa.Theme.text
                            }
                            Text {
                                text: root.isGlassMode ? "Translucent acrylic blur enabled" : "Opaque solid background surfaces"
                                font.family: Nexa.Theme.fontFamily
                                font.pixelSize: 11
                                color: Nexa.Theme.mutedText
                            }
                        }

                        Rectangle {
                            width: 44; height: 24; radius: 12
                            color: root.isGlassMode ? Nexa.Theme.primary : Nexa.Theme.surfaceContainerHighest

                            Rectangle {
                                width: 18; height: 18; radius: 9
                                y: 3
                                x: root.isGlassMode ? 23 : 3
                                color: root.isGlassMode ? Nexa.Theme.onPrimary : Nexa.Theme.mutedText
                                Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.setGlassModeRequested(!root.isGlassMode)
                            }
                        }
                    }
                }

                // Night Warmth Toggle
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
                                text: "Night Warmth"
                                font.family: Nexa.Theme.fontFamily
                                font.pixelSize: 13
                                font.weight: Nexa.Theme.fontWeightDemiBold
                                color: Nexa.Theme.text
                            }
                            Text {
                                text: root.warmthEnabled ? "Wallpaper-adaptive warm screen tint" : "Standard neutral white balance"
                                font.family: Nexa.Theme.fontFamily
                                font.pixelSize: 11
                                color: Nexa.Theme.mutedText
                            }
                        }

                        Rectangle {
                            width: 44; height: 24; radius: 12
                            color: root.warmthEnabled ? Nexa.Theme.primary : Nexa.Theme.surfaceContainerHighest

                            Rectangle {
                                width: 18; height: 18; radius: 9
                                y: 3
                                x: root.warmthEnabled ? 23 : 3
                                color: root.warmthEnabled ? Nexa.Theme.onPrimary : Nexa.Theme.mutedText
                                Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.setWarmthRequested(!root.warmthEnabled)
                            }
                        }
                    }
                }
            }

            Item { Layout.fillHeight: true }
        }
    }

    // ── RIGHT: LIVE WALLPAPER PALETTE PREVIEW HUB ─────────────────────────────
    Rectangle {
        Layout.preferredWidth: 320
        Layout.fillHeight: true
        radius: Nexa.Theme.radiusMd
        color: Nexa.Theme.cardBackground
        border.width: Nexa.Theme.borderThin
        border.color: Nexa.Theme.border

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "Extracted Palette"
                    font.family: Nexa.Theme.fontFamily
                    font.pixelSize: 15
                    font.weight: Nexa.Theme.fontWeightBold
                    color: Nexa.Theme.text
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: root.stagedStyle === "wallpaperAccents" ? "Accents Only" : "Full Spectrum"
                    font.family: Nexa.Theme.fontFamily
                    font.pixelSize: 11
                    color: Nexa.Theme.mutedText
                }
            }

            // Mode Selector (Dark / Light)
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Rectangle {
                    id: darkPill
                    Layout.fillWidth: true
                    height: 32
                    radius: Nexa.Theme.radiusSm
                    readonly property bool isDark: root.stagedMode === "dark"
                    color: isDark ? Nexa.Theme.primaryContainer : (darkMouse.containsMouse ? Nexa.Theme.hover : Nexa.Theme.surfaceContainer)
                    border.width: isDark ? 1 : 0
                    border.color: isDark ? Nexa.Theme.primary : "transparent"

                    Row {
                        anchors.centerIn: parent
                        spacing: 6
                        Text {
                            text: "󰖔"
                            font.family: Nexa.Theme.iconFontFamily
                            font.pixelSize: 13
                            color: darkPill.isDark ? Nexa.Theme.onPrimaryContainer : Nexa.Theme.mutedText
                        }
                        Text {
                            text: "Dark"
                            font.family: Nexa.Theme.fontFamily
                            font.pixelSize: 12
                            font.weight: darkPill.isDark ? Nexa.Theme.fontWeightDemiBold : Nexa.Theme.fontWeightRegular
                            color: darkPill.isDark ? Nexa.Theme.onPrimaryContainer : Nexa.Theme.text
                        }
                    }

                    MouseArea {
                        id: darkMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.stageModeRequested("dark")
                    }
                }

                Rectangle {
                    id: lightPill
                    Layout.fillWidth: true
                    height: 32
                    radius: Nexa.Theme.radiusSm
                    readonly property bool isLight: root.stagedMode === "light"
                    color: isLight ? Nexa.Theme.primaryContainer : (lightMouse.containsMouse ? Nexa.Theme.hover : Nexa.Theme.surfaceContainer)
                    border.width: isLight ? 1 : 0
                    border.color: isLight ? Nexa.Theme.primary : "transparent"

                    Row {
                        anchors.centerIn: parent
                        spacing: 6
                        Text {
                            text: "󰖙"
                            font.family: Nexa.Theme.iconFontFamily
                            font.pixelSize: 13
                            color: lightPill.isLight ? Nexa.Theme.onPrimaryContainer : Nexa.Theme.mutedText
                        }
                        Text {
                            text: "Light"
                            font.family: Nexa.Theme.fontFamily
                            font.pixelSize: 12
                            font.weight: lightPill.isLight ? Nexa.Theme.fontWeightDemiBold : Nexa.Theme.fontWeightRegular
                            color: lightPill.isLight ? Nexa.Theme.onPrimaryContainer : Nexa.Theme.text
                        }
                    }

                    MouseArea {
                        id: lightMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.stageModeRequested("light")
                    }
                }
            }

            // Swatches List with Hex Labels
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6

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
                        height: 34
                        radius: Nexa.Theme.radiusSm
                        color: Nexa.Theme.surfaceContainer

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 8

                            Rectangle {
                                width: 16; height: 16; radius: 8
                                color: swatchRow.modelData.color
                                border.width: 1
                                border.color: Nexa.Theme.border
                            }

                            Text {
                                text: swatchRow.modelData.name
                                font.family: Nexa.Theme.fontFamily
                                font.pixelSize: 12
                                color: Nexa.Theme.text
                                Layout.fillWidth: true
                            }

                            Text {
                                text: String(swatchRow.modelData.color).toUpperCase()
                                font.family: Nexa.Theme.fontFamily
                                font.pixelSize: 11
                                font.weight: Nexa.Theme.fontWeightDemiBold
                                color: Nexa.Theme.mutedText
                            }
                        }
                    }
                }
            }

            Item { Layout.fillHeight: true }

            Text {
                text: root.stagedStyle === "wallpaperAccents" ? "Wallpaper Accents" : "Full Wallpaper Spectrum"
                font.family: Nexa.Theme.fontFamily
                font.pixelSize: 14
                font.weight: Nexa.Theme.fontWeightBold
                color: Nexa.Theme.text
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Text {
                text: "Dynamic Material You Colors"
                font.family: Nexa.Theme.fontFamily
                font.pixelSize: 11
                color: Nexa.Theme.mutedText
            }

            // Apply Button
            Rectangle {
                id: applyWallBtn
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                radius: Nexa.Theme.radiusSm

                readonly property bool isCurrent: root.isCurrentThemeActive

                color: isCurrent
                    ? Qt.rgba(Nexa.Theme.primary.r, Nexa.Theme.primary.g, Nexa.Theme.primary.b, 0.1)
                    : (wallApplyMouse.containsMouse ? Qt.lighter(Nexa.Theme.primary, 1.08) : Nexa.Theme.primary)
                border.width: isCurrent ? 1 : 0
                border.color: isCurrent ? Nexa.Theme.primary : "transparent"

                Row {
                    anchors.centerIn: parent
                    spacing: 8

                    Text {
                        text: applyWallBtn.isCurrent ? "✓" : "󰸉"
                        font.family: applyWallBtn.isCurrent ? Nexa.Theme.fontFamily : Nexa.Theme.iconFontFamily
                        font.pixelSize: 14
                        color: applyWallBtn.isCurrent ? Nexa.Theme.primary : Nexa.Theme.onPrimary
                    }

                    Text {
                        text: root.applying ? "Applying..." : (applyWallBtn.isCurrent ? "Active Theme" : "Apply Wallpaper Palette")
                        font.family: Nexa.Theme.fontFamily
                        font.pixelSize: 13
                        font.weight: Nexa.Theme.fontWeightDemiBold
                        color: applyWallBtn.isCurrent ? Nexa.Theme.primary : Nexa.Theme.onPrimary
                    }
                }

                MouseArea {
                    id: wallApplyMouse
                    anchors.fill: parent
                    enabled: !root.isCurrentThemeActive && !root.applying
                    hoverEnabled: true
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: root.applyRequested()
                }
            }
        }
    }
}

