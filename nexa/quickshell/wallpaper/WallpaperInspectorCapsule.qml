import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../NewNexaUI" as NexaUI

Rectangle {
    id: root

    property string wallpaperPath: ""
    property string wallpaperTitle: ""
    property string nexad: Quickshell.env("HOME") + "/.config/nexa/rust/target/release/nexad"

    property var currentInfo: null
    property bool hasInfo: currentInfo !== null && currentInfo.palette !== undefined

    property string copiedNotification: ""

    height: 38
    radius: NexaUI.NexaTokens.radiusPill
    color: NexaUI.NexaColors.alpha(NexaUI.NexaColors.surfaceContainer, 0.94)
    border.width: NexaUI.NexaTokens.borderThin
    border.color: NexaUI.NexaColors.outlineVariant
    implicitWidth: capsuleRow.implicitWidth + 24

    // Smooth visibility & hover physics via NexaMotion
    opacity: root.wallpaperPath.length > 0 ? 1.0 : 0.0
    scale: root.wallpaperPath.length > 0 ? 1.0 : 0.95

    Behavior on opacity {
        NumberAnimation { duration: NexaUI.NexaMotion.durationFast; easing.type: NexaUI.NexaMotion.decelerateEasing }
    }
    Behavior on scale {
        NumberAnimation { duration: NexaUI.NexaMotion.durationFast; easing.type: NexaUI.NexaMotion.emphasizedEasing; easing.overshoot: 1.15 }
    }

    // Specular Chamfer Highlight
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        radius: parent.radius
        color: Qt.rgba(1, 1, 1, 0.12 * NexaUI.NexaOptics.specularIntensity)
        visible: NexaUI.NexaOptics.specularHighlight
    }

    // ---------------------------------------------------------
    // Backend Process: nexad wallpaper info <path>
    // ---------------------------------------------------------
    Process {
        id: infoProcess
        command: [root.nexad, "wallpaper", "info", root.wallpaperPath]

        stdout: StdioCollector {
            onStreamFinished: {
                if (!this.text || this.text.trim().length === 0) return
                try {
                    const parsed = JSON.parse(this.text.trim())
                    if (parsed && parsed.palette) {
                        root.currentInfo = parsed
                    }
                } catch (e) {
                    console.log("[WallpaperInspector] JSON parse error:", e)
                }
            }
        }
    }

    Timer {
        id: debounceTimer
        interval: 50
        repeat: false
        onTriggered: {
            if (root.wallpaperPath.length > 0) {
                if (infoProcess.running) {
                    infoProcess.running = false
                }
                infoProcess.running = true
            }
        }
    }

    onWallpaperPathChanged: {
        debounceTimer.restart()
    }

    Timer {
        id: copiedTimer
        interval: 1800
        repeat: false
        onTriggered: {
            root.copiedNotification = ""
        }
    }

    // ---------------------------------------------------------
    // Capsule Content Row
    // ---------------------------------------------------------
    RowLayout {
        id: capsuleRow
        anchors.centerIn: parent
        spacing: 12

        // 1. Wallpaper Title & Format Details
        Row {
            spacing: 8
            Layout.alignment: Qt.AlignVCenter

            Text {
                text: "󰋩"
                color: NexaUI.NexaColors.primary
                font.family: NexaUI.NexaTypography.familyIcon
                font.pixelSize: 15
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: root.wallpaperTitle.length > 0 ? root.wallpaperTitle : "Wallpaper"
                color: NexaUI.NexaColors.text
                font.family: NexaUI.NexaTypography.familyBody
                font.pixelSize: NexaUI.NexaTypography.sizeSm
                font.weight: NexaUI.NexaTypography.weightSemiBold
                anchors.verticalCenter: parent.verticalCenter
            }

            // Metadata Pill: JPG • 2560 × 1440 • 1.4 MB
            Rectangle {
                visible: root.hasInfo && (root.currentInfo.format.length > 0 || root.currentInfo.size.length > 0)
                height: 20
                radius: NexaUI.NexaTokens.radiusPill
                color: NexaUI.NexaColors.surfaceContainerHigh
                implicitWidth: metaText.implicitWidth + 12
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    id: metaText
                    anchors.centerIn: parent
                    text: {
                        if (!root.hasInfo) return ""
                        let parts = []
                        if (root.currentInfo.format) parts.push(root.currentInfo.format)
                        if (root.currentInfo.width > 0 && root.currentInfo.height > 0) {
                            parts.push(root.currentInfo.width + "×" + root.currentInfo.height)
                        }
                        if (root.currentInfo.size) parts.push(root.currentInfo.size.replace(/\s+/g, ""))
                        return parts.join(" • ")
                    }
                    color: NexaUI.NexaColors.mutedText
                    font.family: NexaUI.NexaTypography.familyMono
                    font.pixelSize: 9
                    font.weight: NexaUI.NexaTypography.weightMedium
                }
            }
        }

        // 2. Vertical Divider
        Rectangle {
            width: 1
            height: 16
            color: NexaUI.NexaColors.outlineVariant
            Layout.alignment: Qt.AlignVCenter
        }

        // 3. Matugen Color Palette Breakdown
        Row {
            spacing: 5
            Layout.alignment: Qt.AlignVCenter

            Repeater {
                model: [
                    { label: "PRIMARY", key: "primary" },
                    { label: "SECONDARY", key: "secondary" },
                    { label: "TERTIARY", key: "tertiary" },
                    { label: "CONTAINER", key: "container" },
                    { label: "SURFACE", key: "surface" }
                ]

                delegate: Rectangle {
                    id: swatchPill
                    required property var modelData

                    readonly property string hexVal: {
                        if (root.hasInfo && root.currentInfo.palette[modelData.key]) {
                            return String(root.currentInfo.palette[modelData.key]).toUpperCase()
                        }
                        return "#------"
                    }

                    readonly property color colorVal: hexVal !== "#------" ? hexVal : NexaUI.NexaColors.surfaceContainerHighest

                    readonly property bool isCopied: root.copiedNotification === hexVal

                    height: 24
                    radius: NexaUI.NexaTokens.radiusPill
                    color: isCopied
                        ? NexaUI.NexaColors.primaryContainer
                        : (swatchMouse.containsMouse ? NexaUI.NexaColors.surfaceContainerHighest : NexaUI.NexaColors.surfaceContainerLow)
                    border.width: 1
                    border.color: isCopied
                        ? NexaUI.NexaColors.primary
                        : (swatchMouse.containsMouse ? NexaUI.NexaColors.primary : NexaUI.NexaColors.outlineVariant)
                    implicitWidth: swatchRow.implicitWidth + 10
                    anchors.verticalCenter: parent.verticalCenter

                    scale: swatchMouse.containsMouse ? 1.05 : 1.0
                    Behavior on scale {
                        NumberAnimation { duration: NexaUI.NexaMotion.durationInstant; easing.type: Easing.OutQuad }
                    }
                    Behavior on color {
                        ColorAnimation { duration: NexaUI.NexaMotion.durationInstant }
                    }

                    Row {
                        id: swatchRow
                        anchors.centerIn: parent
                        spacing: 5

                        // Color Swatch Circle
                        Rectangle {
                            width: 10
                            height: 10
                            radius: 5
                            color: swatchPill.colorVal
                            border.width: 1
                            border.color: Qt.rgba(255, 255, 255, 0.22)
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        // Role Label
                        Text {
                            text: swatchPill.isCopied ? "COPIED!" : swatchPill.modelData.label
                            color: swatchPill.isCopied ? NexaUI.NexaColors.primary : NexaUI.NexaColors.mutedText
                            font.family: NexaUI.NexaTypography.familyMono
                            font.pixelSize: 8
                            font.weight: NexaUI.NexaTypography.weightBold
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        // Hex Code
                        Text {
                            text: swatchPill.hexVal
                            color: swatchMouse.containsMouse || swatchPill.isCopied ? NexaUI.NexaColors.primary : NexaUI.NexaColors.text
                            font.family: NexaUI.NexaTypography.familyMono
                            font.pixelSize: 9
                            font.weight: NexaUI.NexaTypography.weightSemiBold
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: swatchMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (swatchPill.hexVal !== "#------") {
                                Quickshell.execDetached(["wl-copy", swatchPill.hexVal])
                                root.copiedNotification = swatchPill.hexVal
                                copiedTimer.restart()
                            }
                        }
                    }
                }
            }
        }
    }
}
