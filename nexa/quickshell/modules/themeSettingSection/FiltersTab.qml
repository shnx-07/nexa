// pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import "../../theme" as Nexa
import "../../theme/components" as NexaUI
import "../screenfilter" as ScreenFilterModule

RowLayout {
    id: root

    spacing: 14

    ScreenFilterModule.ScreenFilter {
        id: screenFilter
        visible: root.visible
    }

    readonly property var filterMeta: ({
        "off": {
            name: "Standard (Off)",
            desc: "Native uncalibrated display output with standard color profile",
            icon: "󰹑",
            tag: "Default"
        },
        "chroma": {
            name: "Chroma Boost",
            desc: "Enhanced color saturation and dynamic gamut vibrance",
            icon: "󰏘",
            tag: "Vibrant"
        },
        "grayscale": {
            name: "Monochrome",
            desc: "Complete desaturation for zero distraction and focused work",
            icon: "󰄲",
            tag: "Focus"
        },
        "hdr-boost": {
            name: "HDR Boost",
            desc: "Expanded dynamic range with punchy contrast and deeper blacks",
            icon: "󰖔",
            tag: "Contrast"
        },
        "high-contrast": {
            name: "High Contrast",
            desc: "Amplified text outlines and edge contrast for accessibility",
            icon: "󰍹",
            tag: "Clarity"
        },
        "invert": {
            name: "Invert Colors",
            desc: "Luminance inversion for ultra-dark high-contrast reading",
            icon: "󰔎",
            tag: "Accessibility"
        },
        "sepia": {
            name: "Warm Sepia",
            desc: "Gentle warm golden paper tone reducing blue light strain",
            icon: "󰖙",
            tag: "Comfort"
        },
        "paper-mode": {
            name: "Paper Mode",
            desc: "Warm textured e-paper simulation for long reading sessions",
            icon: "󰈙",
            tag: "Reading"
        }
    })

    function getMeta(f) {
        return filterMeta[f] || {
            name: f,
            desc: "Screen post-processing filter",
            icon: "󰹑",
            tag: "Filter"
        }
    }

    property bool dropdownOpen: false

    // ── LEFT: FILTER SELECTION & CONTROLS ─────────────────────────────────────
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

                // Section Title
                ColumnLayout {
                    spacing: 2
                    Text {
                        text: "Display Filters & Accessibility"
                        font.family: Nexa.Theme.fontFamily
                        font.pixelSize: 16
                        font.weight: Nexa.Theme.fontWeightBold
                        color: Nexa.Theme.text
                    }
                    Text {
                        text: "Hardware compositor color matrices for reading comfort, focus, and contrast"
                        font.family: Nexa.Theme.fontFamily
                        font.pixelSize: 11
                        color: Nexa.Theme.mutedText
                    }
                }

                // ════════════════════════════════════════════════════════════
                // SECTION 1: ACTIVE STATUS & QUICK DROPDOWN SELECTOR
                // ════════════════════════════════════════════════════════════
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: dropCardCol.implicitHeight + 20
                    radius: Nexa.Theme.radiusSm
                    color: Nexa.Theme.cardBackgroundSubtle
                    border.width: Nexa.Theme.borderThin
                    border.color: Nexa.Theme.border

                    ColumnLayout {
                        id: dropCardCol
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 10

                        // Header / Trigger row
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            Rectangle {
                                width: 32
                                height: 32
                                radius: Nexa.Theme.radiusSm
                                color: screenFilter.enabled ? Nexa.Theme.primaryContainer : Nexa.Theme.surfaceContainer

                                Text {
                                    anchors.centerIn: parent
                                    text: root.getMeta(screenFilter.filter).icon
                                    font.family: Nexa.Theme.iconFontFamily
                                    font.pixelSize: 16
                                    color: screenFilter.enabled ? Nexa.Theme.onPrimaryContainer : Nexa.Theme.mutedText
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1

                                Text {
                                    text: "Screen Filter"
                                    font.family: Nexa.Theme.fontFamily
                                    font.pixelSize: 13
                                    font.weight: Nexa.Theme.fontWeightDemiBold
                                    color: Nexa.Theme.text
                                }

                                Text {
                                    text: root.getMeta(screenFilter.filter).name + " — " + (screenFilter.enabled ? "Active" : "Standard output")
                                    font.family: Nexa.Theme.fontFamily
                                    font.pixelSize: 11
                                    color: screenFilter.enabled ? Nexa.Theme.primary : Nexa.Theme.mutedText
                                }
                            }

                            // Quick reset / Off button if active
                            Rectangle {
                                visible: screenFilter.enabled
                                Layout.preferredHeight: 28
                                Layout.preferredWidth: 64
                                radius: Nexa.Theme.radiusXs
                                color: resetMouse.containsMouse ? Nexa.Theme.hover : Nexa.Theme.cardBackgroundElevated
                                border.width: Nexa.Theme.borderThin
                                border.color: Nexa.Theme.border

                                Text {
                                    anchors.centerIn: parent
                                    text: "Turn Off"
                                    font.family: Nexa.Theme.fontFamily
                                    font.pixelSize: 11
                                    font.weight: Nexa.Theme.fontWeightMedium
                                    color: Nexa.Theme.error
                                }

                                MouseArea {
                                    id: resetMouse
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: screenFilter.off()
                                }
                            }

                            // Dropdown toggle pill
                            Rectangle {
                                Layout.preferredHeight: 28
                                Layout.preferredWidth: 32
                                radius: Nexa.Theme.radiusXs
                                color: dropToggleMouse.containsMouse ? Nexa.Theme.primaryContainer : Nexa.Theme.cardBackgroundElevated
                                border.width: Nexa.Theme.borderThin
                                border.color: Nexa.Theme.border

                                Text {
                                    anchors.centerIn: parent
                                    text: root.dropdownOpen ? "󰅃" : "󰅀"
                                    font.family: Nexa.Theme.iconFontFamily
                                    font.pixelSize: 14
                                    color: dropToggleMouse.containsMouse ? Nexa.Theme.onPrimaryContainer : Nexa.Theme.text
                                }

                                MouseArea {
                                    id: dropToggleMouse
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.dropdownOpen = !root.dropdownOpen
                                }
                            }
                        }

                        // Collapsible Dropdown List
                        ColumnLayout {
                            Layout.fillWidth: true
                            visible: root.dropdownOpen
                            spacing: 4

                            Rectangle {
                                Layout.fillWidth: true
                                height: 1
                                color: Nexa.Theme.divider
                                opacity: 0.5
                            }

                            Repeater {
                                model: screenFilter.available
                                delegate: Rectangle {
                                    id: dropItemRect
                                    required property var modelData
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 32
                                    radius: Nexa.Theme.radiusSm
                                    color: modelData === screenFilter.filter
                                        ? Nexa.Theme.primaryContainer
                                        : (dropItemMouse.containsMouse ? Nexa.Theme.hover : "transparent")

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 10
                                        anchors.rightMargin: 10
                                        spacing: 8

                                        Text {
                                            text: root.getMeta(modelData).icon
                                            font.family: Nexa.Theme.iconFontFamily
                                            font.pixelSize: 13
                                            color: modelData === screenFilter.filter ? Nexa.Theme.onPrimaryContainer : Nexa.Theme.mutedText
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: root.getMeta(modelData).name
                                            font.family: Nexa.Theme.fontFamily
                                            font.pixelSize: 12
                                            font.weight: modelData === screenFilter.filter ? Nexa.Theme.fontWeightDemiBold : Nexa.Theme.fontWeightRegular
                                            color: modelData === screenFilter.filter ? Nexa.Theme.onPrimaryContainer : Nexa.Theme.text
                                        }

                                        Text {
                                            visible: modelData === screenFilter.filter
                                            text: "󰄬"
                                            font.family: Nexa.Theme.iconFontFamily
                                            font.pixelSize: 13
                                            color: Nexa.Theme.onPrimaryContainer
                                        }
                                    }

                                    MouseArea {
                                        id: dropItemMouse
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            screenFilter.setFilter(modelData)
                                            root.dropdownOpen = false
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ════════════════════════════════════════════════════════════
                // SECTION 2: VISUAL FILTER CARDS GRID
                // ════════════════════════════════════════════════════════════
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Text {
                        text: "Filter Presets"
                        font.family: Nexa.Theme.fontFamily
                        font.pixelSize: 13
                        font.weight: Nexa.Theme.fontWeightDemiBold
                        color: Nexa.Theme.text
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2
                        columnSpacing: 10
                        rowSpacing: 10

                        Repeater {
                            model: screenFilter.available
                            delegate: Rectangle {
                                id: cardDelegate
                                required property var modelData

                                readonly property bool isActive: modelData === screenFilter.filter
                                readonly property var meta: root.getMeta(modelData)

                                Layout.fillWidth: true
                                implicitHeight: 74
                                radius: Nexa.Theme.radiusSm
                                color: isActive ? Nexa.Theme.primaryContainer : (cardMouse.containsMouse ? Nexa.Theme.surfaceContainerHigh : Nexa.Theme.cardBackgroundSubtle)
                                border.width: Nexa.Theme.borderThin
                                border.color: isActive ? Nexa.Theme.primary : Nexa.Theme.border

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 10

                                    Rectangle {
                                        Layout.preferredWidth: 36
                                        Layout.preferredHeight: 36
                                        radius: Nexa.Theme.radiusXs
                                        color: isActive ? Nexa.Theme.primary : Nexa.Theme.cardBackgroundElevated

                                        Text {
                                            anchors.centerIn: parent
                                            text: cardDelegate.meta.icon
                                            font.family: Nexa.Theme.iconFontFamily
                                            font.pixelSize: 18
                                            color: isActive ? Nexa.Theme.onPrimary : Nexa.Theme.text
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 6

                                            Text {
                                                text: cardDelegate.meta.name
                                                font.family: Nexa.Theme.fontFamily
                                                font.pixelSize: 12
                                                font.weight: Nexa.Theme.fontWeightDemiBold
                                                color: cardDelegate.isActive ? Nexa.Theme.onPrimaryContainer : Nexa.Theme.text
                                            }

                                            Rectangle {
                                                Layout.preferredHeight: 16
                                                Layout.preferredWidth: tagText.implicitWidth + 8
                                                radius: 3
                                                color: cardDelegate.isActive ? Qt.rgba(255, 255, 255, 0.2) : Nexa.Theme.surfaceContainer

                                                Text {
                                                    id: tagText
                                                    anchors.centerIn: parent
                                                    text: cardDelegate.meta.tag
                                                    font.family: Nexa.Theme.fontFamily
                                                    font.pixelSize: 9
                                                    font.weight: Font.Medium
                                                    color: cardDelegate.isActive ? Nexa.Theme.onPrimaryContainer : Nexa.Theme.mutedText
                                                }
                                            }

                                            Item { Layout.fillWidth: true }

                                            Text {
                                                visible: cardDelegate.isActive
                                                text: "󰄬"
                                                font.family: Nexa.Theme.iconFontFamily
                                                font.pixelSize: 14
                                                color: Nexa.Theme.onPrimaryContainer
                                            }
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: cardDelegate.meta.desc
                                            font.family: Nexa.Theme.fontFamily
                                            font.pixelSize: 10
                                            color: cardDelegate.isActive ? Nexa.Theme.onPrimaryContainer : Nexa.Theme.mutedText
                                            elide: Text.ElideRight
                                            maximumLineCount: 2
                                            wrapMode: Text.WordWrap
                                            opacity: cardDelegate.isActive ? 0.85 : 0.75
                                        }
                                    }
                                }

                                MouseArea {
                                    id: cardMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (cardDelegate.isActive && modelData !== "off") {
                                            screenFilter.off()
                                        } else {
                                            screenFilter.setFilter(modelData)
                                        }
                                    }
                                }
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
                text: "Live Filter Preview"
                font.family: Nexa.Theme.fontFamily
                font.pixelSize: 14
                font.weight: Nexa.Theme.fontWeightBold
                color: Nexa.Theme.text
            }

            // Preview Box showing sample colors, text, and window mock
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Nexa.Theme.radiusSm
                color: Nexa.Theme.cardBackgroundElevated
                border.width: 1
                border.color: Nexa.Theme.border
                clip: true

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 14

                    // Mini window header
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Rectangle { width: 8; height: 8; radius: 4; color: "#ff5f57" }
                        Rectangle { width: 8; height: 8; radius: 4; color: "#febc2e" }
                        Rectangle { width: 8; height: 8; radius: 4; color: "#28c840" }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: "NEXA Display Filter"
                            font.family: Nexa.Theme.fontFamily
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            color: Nexa.Theme.mutedText
                        }
                    }

                    // Active mode badge
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 46
                        radius: Nexa.Theme.radiusSm
                        color: screenFilter.enabled ? Nexa.Theme.primaryContainer : Nexa.Theme.surfaceContainerLow
                        border.width: Nexa.Theme.borderThin
                        border.color: screenFilter.enabled ? Nexa.Theme.primary : Nexa.Theme.border

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 8

                            Text {
                                text: root.getMeta(screenFilter.filter).icon
                                font.family: Nexa.Theme.iconFontFamily
                                font.pixelSize: 18
                                color: screenFilter.enabled ? Nexa.Theme.onPrimaryContainer : Nexa.Theme.primary
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1
                                Text {
                                    text: root.getMeta(screenFilter.filter).name
                                    font.family: Nexa.Theme.fontFamily
                                    font.pixelSize: 12
                                    font.weight: Nexa.Theme.fontWeightBold
                                    color: screenFilter.enabled ? Nexa.Theme.onPrimaryContainer : Nexa.Theme.text
                                }
                                Text {
                                    text: screenFilter.enabled ? "Hardware matrix active" : "No filter applied"
                                    font.family: Nexa.Theme.fontFamily
                                    font.pixelSize: 10
                                    color: screenFilter.enabled ? Nexa.Theme.onPrimaryContainer : Nexa.Theme.mutedText
                                    opacity: 0.8
                                }
                            }
                        }
                    }

                    // Color Spectrum Palette Test Chips
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Text {
                            text: "Color Matrix Test"
                            font.family: Nexa.Theme.fontFamily
                            font.pixelSize: 10
                            font.weight: Nexa.Theme.fontWeightDemiBold
                            color: Nexa.Theme.mutedText
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Rectangle { Layout.fillWidth: true; height: 28; radius: 4; color: "#ef4444" }
                            Rectangle { Layout.fillWidth: true; height: 28; radius: 4; color: "#f59e0b" }
                            Rectangle { Layout.fillWidth: true; height: 28; radius: 4; color: "#10b981" }
                            Rectangle { Layout.fillWidth: true; height: 28; radius: 4; color: "#06b6d4" }
                            Rectangle { Layout.fillWidth: true; height: 28; radius: 4; color: "#6366f1" }
                            Rectangle { Layout.fillWidth: true; height: 28; radius: 4; color: "#d946ef" }
                        }
                    }

                    // Reading / Typography Mock
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: Nexa.Theme.radiusSm
                        color: Nexa.Theme.surfaceContainerLow
                        border.width: Nexa.Theme.borderThin
                        border.color: Nexa.Theme.border

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 6

                            Text {
                                text: "Typography & Contrast Sample"
                                font.family: Nexa.Theme.fontFamily
                                font.pixelSize: 12
                                font.weight: Nexa.Theme.fontWeightBold
                                color: Nexa.Theme.text
                            }

                            Text {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                text: "Post-processing shaders modify output pixels across the entire display at hardware level. Paper Mode simulates reflective e-ink warmth, while Chroma and High Contrast enhance vibrancy and text legibility."
                                font.family: Nexa.Theme.fontFamily
                                font.pixelSize: 10
                                color: Nexa.Theme.mutedText
                                wrapMode: Text.WordWrap
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }
        }
    }
}

