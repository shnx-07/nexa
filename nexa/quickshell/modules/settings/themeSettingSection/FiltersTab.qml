// pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import "../../../NewNexaUI" as NexaUI
import "../../../NewNexaUI" as NexaUI
import "../../screenfilter" as ScreenFilterModule

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

                // Section Title
                ColumnLayout {
                    spacing: 2
                    Text {
                        text: "Display Filters & Accessibility"
                        font.family: NexaUI.NexaTypography.familyBody
                        font.pixelSize: 16
                        font.weight: NexaUI.NexaTypography.weightBold
                        color: NexaUI.NexaColors.text
                    }
                    Text {
                        text: "Hardware compositor color matrices for reading comfort, focus, and contrast"
                        font.family: NexaUI.NexaTypography.familyBody
                        font.pixelSize: 11
                        color: NexaUI.NexaColors.mutedText
                    }
                }

                // ════════════════════════════════════════════════════════════
                // SECTION 1: ACTIVE STATUS & QUICK DROPDOWN SELECTOR
                // ════════════════════════════════════════════════════════════
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: dropCardCol.implicitHeight + 20
                    radius: NexaUI.NexaTokens.radiusSm
                    color: NexaUI.NexaColors.surfaceContainerLow
                    border.width: NexaUI.NexaTokens.borderThin
                    border.color: NexaUI.NexaColors.border

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
                                radius: NexaUI.NexaTokens.radiusSm
                                color: screenFilter.enabled ? NexaUI.NexaColors.primaryContainer : NexaUI.NexaColors.surfaceContainer

                                Text {
                                    anchors.centerIn: parent
                                    text: root.getMeta(screenFilter.filter).icon
                                    font.family: NexaUI.NexaTypography.familyIcon
                                    font.pixelSize: 16
                                    color: screenFilter.enabled ? NexaUI.NexaColors.onPrimaryContainer : NexaUI.NexaColors.mutedText
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1

                                Text {
                                    text: "Screen Filter"
                                    font.family: NexaUI.NexaTypography.familyBody
                                    font.pixelSize: 13
                                    font.weight: NexaUI.NexaTypography.weightSemiBold
                                    color: NexaUI.NexaColors.text
                                }

                                Text {
                                    text: root.getMeta(screenFilter.filter).name + " — " + (screenFilter.enabled ? "Active" : "Standard output")
                                    font.family: NexaUI.NexaTypography.familyBody
                                    font.pixelSize: 11
                                    color: screenFilter.enabled ? NexaUI.NexaColors.primary : NexaUI.NexaColors.mutedText
                                }
                            }

                            // Quick reset / Off button if active
                            Rectangle {
                                visible: screenFilter.enabled
                                Layout.preferredHeight: 28
                                Layout.preferredWidth: 64
                                radius: NexaUI.NexaTokens.radiusXs
                                color: resetMouse.containsMouse ? NexaUI.NexaColors.surfaceContainerHigh : NexaUI.NexaColors.surfaceContainerHigh
                                border.width: NexaUI.NexaTokens.borderThin
                                border.color: NexaUI.NexaColors.border

                                Text {
                                    anchors.centerIn: parent
                                    text: "Turn Off"
                                    font.family: NexaUI.NexaTypography.familyBody
                                    font.pixelSize: 11
                                    font.weight: NexaUI.NexaTypography.weightMedium
                                    color: NexaUI.NexaColors.error
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
                                radius: NexaUI.NexaTokens.radiusXs
                                color: dropToggleMouse.containsMouse ? NexaUI.NexaColors.primaryContainer : NexaUI.NexaColors.surfaceContainerHigh
                                border.width: NexaUI.NexaTokens.borderThin
                                border.color: NexaUI.NexaColors.border

                                Text {
                                    anchors.centerIn: parent
                                    text: root.dropdownOpen ? "󰅃" : "󰅀"
                                    font.family: NexaUI.NexaTypography.familyIcon
                                    font.pixelSize: 14
                                    color: dropToggleMouse.containsMouse ? NexaUI.NexaColors.onPrimaryContainer : NexaUI.NexaColors.text
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
                                color: NexaUI.NexaColors.borderSubtle
                                opacity: 0.5
                            }

                            Repeater {
                                model: screenFilter.available
                                delegate: Rectangle {
                                    id: dropItemRect
                                    required property var modelData
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 32
                                    radius: NexaUI.NexaTokens.radiusSm
                                    color: modelData === screenFilter.filter
                                        ? NexaUI.NexaColors.primaryContainer
                                        : (dropItemMouse.containsMouse ? NexaUI.NexaColors.surfaceContainerHigh : "transparent")

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 10
                                        anchors.rightMargin: 10
                                        spacing: 8

                                        Text {
                                            text: root.getMeta(modelData).icon
                                            font.family: NexaUI.NexaTypography.familyIcon
                                            font.pixelSize: 13
                                            color: modelData === screenFilter.filter ? NexaUI.NexaColors.onPrimaryContainer : NexaUI.NexaColors.mutedText
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: root.getMeta(modelData).name
                                            font.family: NexaUI.NexaTypography.familyBody
                                            font.pixelSize: 12
                                            font.weight: modelData === screenFilter.filter ? NexaUI.NexaTypography.weightSemiBold : NexaUI.NexaTypography.weightRegular
                                            color: modelData === screenFilter.filter ? NexaUI.NexaColors.onPrimaryContainer : NexaUI.NexaColors.text
                                        }

                                        Text {
                                            visible: modelData === screenFilter.filter
                                            text: "󰄬"
                                            font.family: NexaUI.NexaTypography.familyIcon
                                            font.pixelSize: 13
                                            color: NexaUI.NexaColors.onPrimaryContainer
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
                        font.family: NexaUI.NexaTypography.familyBody
                        font.pixelSize: 13
                        font.weight: NexaUI.NexaTypography.weightSemiBold
                        color: NexaUI.NexaColors.text
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
                                radius: NexaUI.NexaTokens.radiusSm
                                color: isActive ? NexaUI.NexaColors.primaryContainer : (cardMouse.containsMouse ? NexaUI.NexaColors.surfaceContainerHigh : NexaUI.NexaColors.surfaceContainerLow)
                                border.width: NexaUI.NexaTokens.borderThin
                                border.color: isActive ? NexaUI.NexaColors.primary : NexaUI.NexaColors.border

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 10

                                    Rectangle {
                                        Layout.preferredWidth: 36
                                        Layout.preferredHeight: 36
                                        radius: NexaUI.NexaTokens.radiusXs
                                        color: isActive ? NexaUI.NexaColors.primary : NexaUI.NexaColors.surfaceContainerHigh

                                        Text {
                                            anchors.centerIn: parent
                                            text: cardDelegate.meta.icon
                                            font.family: NexaUI.NexaTypography.familyIcon
                                            font.pixelSize: 18
                                            color: isActive ? NexaUI.NexaColors.onPrimary : NexaUI.NexaColors.text
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
                                                font.family: NexaUI.NexaTypography.familyBody
                                                font.pixelSize: 12
                                                font.weight: NexaUI.NexaTypography.weightSemiBold
                                                color: cardDelegate.isActive ? NexaUI.NexaColors.onPrimaryContainer : NexaUI.NexaColors.text
                                            }

                                            Rectangle {
                                                Layout.preferredHeight: 16
                                                Layout.preferredWidth: tagText.implicitWidth + 8
                                                radius: 3
                                                color: cardDelegate.isActive ? Qt.rgba(255, 255, 255, 0.2) : NexaUI.NexaColors.surfaceContainer

                                                Text {
                                                    id: tagText
                                                    anchors.centerIn: parent
                                                    text: cardDelegate.meta.tag
                                                    font.family: NexaUI.NexaTypography.familyBody
                                                    font.pixelSize: 9
                                                    font.weight: Font.Medium
                                                    color: cardDelegate.isActive ? NexaUI.NexaColors.onPrimaryContainer : NexaUI.NexaColors.mutedText
                                                }
                                            }

                                            Item { Layout.fillWidth: true }

                                            Text {
                                                visible: cardDelegate.isActive
                                                text: "󰄬"
                                                font.family: NexaUI.NexaTypography.familyIcon
                                                font.pixelSize: 14
                                                color: NexaUI.NexaColors.onPrimaryContainer
                                            }
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: cardDelegate.meta.desc
                                            font.family: NexaUI.NexaTypography.familyBody
                                            font.pixelSize: 10
                                            color: cardDelegate.isActive ? NexaUI.NexaColors.onPrimaryContainer : NexaUI.NexaColors.mutedText
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
                text: "Live Filter Preview"
                font.family: NexaUI.NexaTypography.familyBody
                font.pixelSize: 14
                font.weight: NexaUI.NexaTypography.weightBold
                color: NexaUI.NexaColors.text
            }

            // Preview Box showing sample colors, text, and window mock
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: NexaUI.NexaTokens.radiusSm
                color: NexaUI.NexaColors.surfaceContainerHigh
                border.width: 1
                border.color: NexaUI.NexaColors.border
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
                            font.family: NexaUI.NexaTypography.familyBody
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            color: NexaUI.NexaColors.mutedText
                        }
                    }

                    // Active mode badge
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 46
                        radius: NexaUI.NexaTokens.radiusSm
                        color: screenFilter.enabled ? NexaUI.NexaColors.primaryContainer : NexaUI.NexaColors.surfaceContainerLow
                        border.width: NexaUI.NexaTokens.borderThin
                        border.color: screenFilter.enabled ? NexaUI.NexaColors.primary : NexaUI.NexaColors.border

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 8

                            Text {
                                text: root.getMeta(screenFilter.filter).icon
                                font.family: NexaUI.NexaTypography.familyIcon
                                font.pixelSize: 18
                                color: screenFilter.enabled ? NexaUI.NexaColors.onPrimaryContainer : NexaUI.NexaColors.primary
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1
                                Text {
                                    text: root.getMeta(screenFilter.filter).name
                                    font.family: NexaUI.NexaTypography.familyBody
                                    font.pixelSize: 12
                                    font.weight: NexaUI.NexaTypography.weightBold
                                    color: screenFilter.enabled ? NexaUI.NexaColors.onPrimaryContainer : NexaUI.NexaColors.text
                                }
                                Text {
                                    text: screenFilter.enabled ? "Hardware matrix active" : "No filter applied"
                                    font.family: NexaUI.NexaTypography.familyBody
                                    font.pixelSize: 10
                                    color: screenFilter.enabled ? NexaUI.NexaColors.onPrimaryContainer : NexaUI.NexaColors.mutedText
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
                            font.family: NexaUI.NexaTypography.familyBody
                            font.pixelSize: 10
                            font.weight: NexaUI.NexaTypography.weightSemiBold
                            color: NexaUI.NexaColors.mutedText
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
                        radius: NexaUI.NexaTokens.radiusSm
                        color: NexaUI.NexaColors.surfaceContainerLow
                        border.width: NexaUI.NexaTokens.borderThin
                        border.color: NexaUI.NexaColors.border

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 6

                            Text {
                                text: "Typography & Contrast Sample"
                                font.family: NexaUI.NexaTypography.familyBody
                                font.pixelSize: 12
                                font.weight: NexaUI.NexaTypography.weightBold
                                color: NexaUI.NexaColors.text
                            }

                            Text {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                text: "Post-processing shaders modify output pixels across the entire display at hardware level. Paper Mode simulates reflective e-ink warmth, while Chroma and High Contrast enhance vibrancy and text legibility."
                                font.family: NexaUI.NexaTypography.familyBody
                                font.pixelSize: 10
                                color: NexaUI.NexaColors.mutedText
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

