// pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import QtMultimedia
import Quickshell
import "../../NewNexaUI" as NexaUI
import "../lockthemes/components"
import "../../services" as Services

Item {
    id: root

    property string selectedThemeId: Services.Sddm.activeSddmTheme || "material-you-dark"
    readonly property int columns: width > 760 ? 3 : 2

    readonly property var allThemes: Services.Sddm.themes
    readonly property var filteredThemes: allThemes || []

    ColumnLayout {
        anchors.fill: parent
        spacing: 14

        // ── TOP CONTROL & ACTION TOOLBAR ─────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 52
            radius: NexaUI.NexaTokens.radiusMd
            color: NexaUI.NexaColors.surfaceContainer
            border.width: NexaUI.NexaTokens.borderThin
            border.color: NexaUI.NexaColors.border

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                spacing: 12

                // Left: Theme Library Header & Count Badge
                RowLayout {
                    spacing: 8

                    Text {
                        text: "󱓞"
                        font.family: NexaUI.NexaTypography.familyIcon
                        font.pixelSize: 18
                        color: NexaUI.NexaColors.primary
                    }

                    StyledText {
                        text: "SDDM Theme Library"
                        font.pixelSize: 14
                        font.weight: Font.Bold
                        color: NexaUI.NexaColors.text
                    }

                    Rectangle {
                        height: 22
                        width: countText.implicitWidth + 14
                        radius: 11
                        color: NexaUI.NexaColors.surfaceContainerHigh

                        StyledText {
                            id: countText
                            anchors.centerIn: parent
                            text: (root.allThemes ? root.allThemes.length : 39) + " Themes"
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            color: NexaUI.NexaColors.mutedText
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                // Test / Preview Lock Button
                ClickableRect {
                    Layout.preferredHeight: 36
                    Layout.preferredWidth: testRow.implicitWidth + 20
                    radius: NexaUI.NexaTokens.radiusXs
                    color: testBtnArea.containsMouse ? NexaUI.NexaColors.surfaceContainerHigh : NexaUI.NexaColors.surfaceContainer
                    border.width: 1
                    border.color: NexaUI.NexaColors.border

                    MouseArea {
                        id: testBtnArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Services.Sddm.previewTheme(root.selectedThemeId)
                    }

                    RowLayout {
                        id: testRow
                        anchors.centerIn: parent
                        spacing: 6

                        Text {
                            text: "󰐊"
                            font.family: NexaUI.NexaTypography.familyIcon
                            font.pixelSize: 15
                            color: NexaUI.NexaColors.text
                        }

                        StyledText {
                            text: "Test"
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            color: NexaUI.NexaColors.text
                        }
                    }
                }

                // Apply for Nexa Button (Desktop Lock)
                ClickableRect {
                    id: applyNexaBtn
                    readonly property bool isCurrentNexaLock: Services.Sddm.activeDesktopSddmTheme === root.selectedThemeId
                    Layout.preferredHeight: 36
                    Layout.preferredWidth: applyNexaRow.implicitWidth + 24
                    radius: NexaUI.NexaTokens.radiusXs
                    color: isCurrentNexaLock
                        ? Qt.rgba(30/255, 64/255, 175/255, 0.3)
                        : (applyNexaMouse.containsMouse ? NexaUI.NexaColors.surfaceContainerHigh : NexaUI.NexaColors.surfaceContainer)
                    border.width: 1
                    border.color: isCurrentNexaLock ? "#60a5fa" : NexaUI.NexaColors.border

                    MouseArea {
                        id: applyNexaMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Services.Sddm.toggleDesktopLockTheme(root.selectedThemeId)
                    }

                    RowLayout {
                        id: applyNexaRow
                        anchors.centerIn: parent
                        spacing: 6

                        Text {
                            text: applyNexaBtn.isCurrentNexaLock ? "󰄬" : "󰌾"
                            font.family: NexaUI.NexaTypography.familyIcon
                            font.pixelSize: 15
                            color: applyNexaBtn.isCurrentNexaLock ? "#60a5fa" : NexaUI.NexaColors.text
                        }

                        StyledText {
                            text: applyNexaBtn.isCurrentNexaLock ? "Active on Nexa" : "Apply for Nexa"
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            color: applyNexaBtn.isCurrentNexaLock ? "#60a5fa" : NexaUI.NexaColors.text
                        }
                    }
                }

                // Apply for SDDM Button (Polkit)
                ClickableRect {
                    id: applySddmBtn
                    readonly property bool isCurrentSddm: Services.Sddm.activeSddmTheme === root.selectedThemeId
                    Layout.preferredHeight: 36
                    Layout.preferredWidth: applySddmRow.implicitWidth + 24
                    radius: NexaUI.NexaTokens.radiusXs
                    color: Services.Sddm.applying 
                        ? NexaUI.NexaColors.mutedText 
                        : (applySddmMouse.containsMouse ? Qt.lighter(NexaUI.NexaColors.primary, 1.1) : NexaUI.NexaColors.primary)
                    enabled: !Services.Sddm.applying

                    MouseArea {
                        id: applySddmMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Services.Sddm.applyToSddm(root.selectedThemeId)
                    }

                    RowLayout {
                        id: applySddmRow
                        anchors.centerIn: parent
                        spacing: 6

                        Text {
                            text: "󰞌"
                            font.family: NexaUI.NexaTypography.familyIcon
                            font.pixelSize: 15
                            color: NexaUI.NexaColors.onPrimary
                        }

                        StyledText {
                            text: Services.Sddm.applying ? "Applying..." : "Apply for SDDM"
                            font.pixelSize: 12
                            font.weight: Font.Bold
                            color: NexaUI.NexaColors.onPrimary
                        }
                    }
                }
            }
        }

        // ── THEME CARDS GRID ──────────────────────────────────────────────────
        Flickable {
            id: sddmFlickable
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: sddmGrid.height + 24
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            NexaUI.NexaSmoothScroll {}

            Grid {
                id: sddmGrid
                x: 8
                y: 8
                width: parent.width - 16
                columns: root.columns
                spacing: 16

                readonly property real cardW: (width - (columns - 1) * spacing) / columns

                Repeater {
                    model: root.filteredThemes

                    Rectangle {
                        id: sddmCard
                        required property var modelData
                        required property int index

                        readonly property bool isSelected: root.selectedThemeId === modelData.id
                        readonly property bool isActiveInSddm: Services.Sddm.activeSddmTheme === modelData.id

                        width: sddmGrid.cardW
                        height: thumbItem.height + infoCol.implicitHeight + 28
                        radius: NexaUI.NexaTokens.radiusLg
                        z: isSelected ? 5 : 1

                        color: isSelected
                            ? Qt.rgba(NexaUI.NexaColors.primary.r, NexaUI.NexaColors.primary.g, NexaUI.NexaColors.primary.b, 0.08)
                            : (cardHover.containsMouse ? NexaUI.NexaColors.surfaceContainerHigh : NexaUI.NexaColors.surfaceContainer)

                        border.width: isSelected ? 2 : (isActiveInSddm ? 1.5 : 1)
                        border.color: isSelected ? NexaUI.NexaColors.primary : (isActiveInSddm ? "#4ade80" : NexaUI.NexaColors.border)

                        Behavior on color { ColorAnimation { duration: NexaUI.NexaMotion.durationInstant } }

                        // Top Specular Highlight (Layer 2 specular beam)
                        Rectangle {
                            anchors.top: parent.top
                            anchors.topMargin: 1
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: Math.max(0, parent.width - parent.radius * 1.6)
                            height: 1
                            visible: NexaUI.NexaOptics.specularHighlight && NexaUI.NexaOptics.specularIntensity > 0.01
                            opacity: Math.min(1.0, NexaUI.NexaOptics.specularIntensity / 0.28)
                            z: 2
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0.0; color: "transparent" }
                                GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.35) }
                                GradientStop { position: 1.0; color: "transparent" }
                            }
                        }

                        MouseArea {
                            id: cardHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.selectedThemeId = sddmCard.modelData.id
                        }

                        // Thumbnail
                        Rectangle {
                            id: thumbItem
                            x: 10
                            y: 10
                            width: parent.width - 20
                            height: Math.round(width * 9 / 16)
                            radius: 14
                            clip: true
                            color: NexaUI.NexaColors.surfaceContainerLowest

                            Image {
                                anchors.fill: parent
                                source: sddmCard.modelData.preview || ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                mipmap: true
                                cache: true
                            }

                            // Live Animated Video Preview (Plays on hover)
                            Loader {
                                id: videoPlayerLoader
                                anchors.fill: parent
                                active: (sddmCard.modelData.hasVideo === true) && cardHover.containsMouse
                                visible: active
                                sourceComponent: Component {
                                    Item {
                                        anchors.fill: parent

                                        MediaPlayer {
                                            id: previewPlayer
                                            source: sddmCard.modelData.video || ""
                                            loops: MediaPlayer.Infinite
                                            audioOutput: AudioOutput { muted: true }
                                            videoOutput: previewOutput
                                            autoPlay: true
                                        }

                                        VideoOutput {
                                            id: previewOutput
                                            anchors.fill: parent
                                            fillMode: VideoOutput.PreserveAspectCrop
                                            visible: previewPlayer.playbackState === MediaPlayer.PlayingState
                                        }
                                    }
                                }
                            }

                            // Dark bottom gradient for contrast
                            Rectangle {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                height: 50
                                gradient: Gradient {
                                    GradientStop { position: 0.0; color: "transparent" }
                                    GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.75) }
                                }
                            }

                            // Video Theme Indicator Badge (Top Left)
                            Rectangle {
                                visible: sddmCard.modelData.hasVideo === true
                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.margins: 8
                                height: 22
                                width: videoBadgeRow.implicitWidth + 14
                                radius: 11
                                color: Qt.rgba(0, 0, 0, 0.65)
                                border.width: 1
                                border.color: Qt.rgba(255, 255, 255, 0.2)
                                z: 6

                                RowLayout {
                                    id: videoBadgeRow
                                    anchors.centerIn: parent
                                    spacing: 4

                                    Text {
                                        text: "󰕧"
                                        font.family: NexaUI.NexaTypography.familyIcon
                                        font.pixelSize: 12
                                        color: "#38bdf8"
                                    }

                                    StyledText {
                                        text: "Video"
                                        font.pixelSize: 10
                                        font.weight: Font.DemiBold
                                        color: "#e2e8f0"
                                    }
                                }
                            }

                            // Active SDDM Badge
                            Rectangle {
                                visible: sddmCard.isActiveInSddm
                                anchors.top: parent.top
                                anchors.right: parent.right
                                anchors.margins: 8
                                height: 26
                                width: badgeRow.implicitWidth + 16
                                radius: 13
                                color: Qt.rgba(22 / 255, 101 / 255, 52 / 255, 0.9)
                                border.width: 1
                                border.color: "#4ade80"
                                z: 8

                                RowLayout {
                                    id: badgeRow
                                    anchors.centerIn: parent
                                    spacing: 4

                                    Text {
                                        text: "󰄬"
                                        font.family: NexaUI.NexaTypography.familyIcon
                                        font.pixelSize: 13
                                        color: "#4ade80"
                                    }

                                    StyledText {
                                        text: "Active SDDM"
                                        font.pixelSize: 11
                                        font.weight: Font.Bold
                                        color: "#ffffff"
                                    }
                                }
                            }

                            // Active Desktop Lock Badge
                            Rectangle {
                                visible: Services.Sddm.activeDesktopSddmTheme === sddmCard.modelData.id
                                anchors.top: parent.top
                                anchors.right: sddmCard.isActiveInSddm ? badgeRow.left : parent.right
                                anchors.margins: 8
                                height: 26
                                width: deskBadgeRow.implicitWidth + 16
                                radius: 13
                                color: Qt.rgba(30 / 255, 64 / 255, 175 / 255, 0.9)
                                border.width: 1
                                border.color: "#60a5fa"
                                z: 8

                                RowLayout {
                                    id: deskBadgeRow
                                    anchors.centerIn: parent
                                    spacing: 4

                                    Text {
                                        text: "󰌾"
                                        font.family: NexaUI.NexaTypography.familyIcon
                                        font.pixelSize: 13
                                        color: "#93c5fd"
                                    }

                                    StyledText {
                                        text: "Desktop Lock"
                                        font.pixelSize: 11
                                        font.weight: Font.Bold
                                        color: "#ffffff"
                                    }
                                }
                            }

                            // Selected Badge
                            Rectangle {
                                visible: sddmCard.isSelected && !sddmCard.isActiveInSddm
                                anchors.top: parent.top
                                anchors.right: parent.right
                                anchors.margins: 8
                                height: 26
                                width: selRow.implicitWidth + 16
                                radius: 13
                                color: NexaUI.NexaColors.primary
                                border.width: 1
                                border.color: NexaUI.NexaColors.primary

                                RowLayout {
                                    id: selRow
                                    anchors.centerIn: parent
                                    spacing: 4

                                    Text {
                                        text: "󰄬"
                                        font.family: NexaUI.NexaTypography.familyIcon
                                        font.pixelSize: 13
                                        color: NexaUI.NexaColors.onPrimary
                                    }

                                    StyledText {
                                        text: "Selected"
                                        font.pixelSize: 11
                                        font.weight: Font.Bold
                                        color: NexaUI.NexaColors.onPrimary
                                    }
                                }
                            }

                            // Hover Action Button: Preview / Test Lock
                            ClickableRect {
                                id: cardPreviewBtn
                                anchors.centerIn: parent
                                width: prevRow.implicitWidth + 24
                                height: 34
                                radius: 17
                                z: 15
                                visible: cardHover.containsMouse || cardPreviewBtn.hovered
                                color: cardPreviewBtn.hovered ? NexaUI.NexaColors.primary : Qt.rgba(0, 0, 0, 0.78)
                                border.width: 1
                                border.color: Qt.rgba(255, 255, 255, 0.22)
                                onClicked: Services.Sddm.previewTheme(sddmCard.modelData.id)

                                RowLayout {
                                    id: prevRow
                                    anchors.centerIn: parent
                                    spacing: 6

                                    Text {
                                        text: "󰐊"
                                        font.family: NexaUI.NexaTypography.familyIcon
                                        font.pixelSize: 15
                                        color: cardPreviewBtn.hovered ? NexaUI.NexaColors.onPrimary : "white"
                                    }

                                    StyledText {
                                        text: "Preview"
                                        font.pixelSize: 12
                                        font.weight: Font.DemiBold
                                        color: cardPreviewBtn.hovered ? NexaUI.NexaColors.onPrimary : "white"
                                    }
                                }
                            }
                        }

                        // Info Column
                        Column {
                            id: infoCol
                            anchors.top: thumbItem.bottom
                            anchors.topMargin: 12
                            x: 16
                            width: parent.width - 32
                            spacing: 4

                            RowLayout {
                                width: parent.width
                                spacing: 8

                                StyledText {
                                    text: sddmCard.modelData.name
                                    font.pixelSize: 15
                                    font.weight: Font.Bold
                                    color: NexaUI.NexaColors.text
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                StyledText {
                                    text: "SDDM"
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                    color: NexaUI.NexaColors.primary
                                }
                            }

                            StyledText {
                                width: parent.width
                                text: sddmCard.modelData.description || ""
                                font.pixelSize: 12
                                color: NexaUI.NexaColors.mutedText
                                wrapMode: Text.WordWrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                                lineHeight: 1.15
                            }
                        }
                    }
                }
            }
        }

        // ── BOTTOM STATUS BAR ─────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 38
            radius: NexaUI.NexaTokens.radiusSm
            color: NexaUI.NexaColors.surfaceContainer
            border.width: NexaUI.NexaTokens.borderThin
            border.color: NexaUI.NexaColors.border

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16

                RowLayout {
                    spacing: 8
                    Text {
                        text: Services.Sddm.applying ? "󰞌" : (Services.Sddm.lastAppliedStatus.includes("Success") ? "󰄬" : (Services.Sddm.lastAppliedStatus.includes("Fail") || Services.Sddm.lastAppliedStatus.includes("cancel") ? "󰅖" : "󱓞"))
                        font.family: NexaUI.NexaTypography.familyIcon
                        font.pixelSize: 15
                        color: Services.Sddm.applying ? NexaUI.NexaColors.primary : (Services.Sddm.lastAppliedStatus.includes("Success") ? "#4ade80" : (Services.Sddm.lastAppliedStatus.includes("Fail") || Services.Sddm.lastAppliedStatus.includes("cancel") ? "#f87171" : NexaUI.NexaColors.mutedText))
                    }

                    StyledText {
                        text: Services.Sddm.lastAppliedStatus.length > 0 ? Services.Sddm.lastAppliedStatus : "39 SDDM themes installed • Ready"
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        color: Services.Sddm.lastAppliedStatus.includes("Success") ? "#4ade80" : (Services.Sddm.lastAppliedStatus.includes("Fail") || Services.Sddm.lastAppliedStatus.includes("cancel") ? "#f87171" : (Services.Sddm.applying ? NexaUI.NexaColors.primary : NexaUI.NexaColors.mutedText))
                    }
                }

                Item { Layout.fillWidth: true }

                StyledText {
                    text: "Select a theme and click Apply for Nexa or Apply for SDDM"
                    font.pixelSize: 12
                    color: NexaUI.NexaColors.mutedText
                }
            }
        }
    }
}
