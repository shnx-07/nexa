import QtQuick
import QtQuick.Layouts

import "../NewNexaUI" as NexaUI

Rectangle {
    id: root

    signal clicked()

    property date currentTime: new Date()

    Timer {
        interval: 1000
        running: root.visible
        repeat: true
        onTriggered: root.currentTime = new Date()
    }

    height: NexaUI.NexaTokens.islandCompactHeight
    width: clockText.implicitWidth + 24

    // Copies exact radius change behavior as Island in compact mode
    radius: {
        if (NexaUI.NexaTokens.islandRounding === 0) return 0;
        return (NexaUI.NexaTokens.islandRounding >= 999) ? Math.round(height / 2) : NexaUI.NexaTokens.islandRounding;
    }

    Behavior on radius {
        enabled: NexaUI.NexaMotion.enabled
        NumberAnimation {
            duration: NexaUI.NexaMotion.durationFast
            easing.type: NexaUI.NexaMotion.standardEasing
        }
    }

    color: clockMouse.containsMouse
        ? NexaUI.NexaColors.surfaceContainerHigh
        : NexaUI.NexaColors.islandBackground

    border.width: NexaUI.NexaTokens.borderThin
    border.color: clockMouse.containsMouse
        ? NexaUI.NexaColors.borderStrong
        : NexaUI.NexaColors.border

    Behavior on color {
        ColorAnimation { duration: NexaUI.NexaMotion.durationFast }
    }
    Behavior on border.color {
        ColorAnimation { duration: NexaUI.NexaMotion.durationFast }
    }

    // Apple / Tactile 4-stop OLED Depth Micro-Gradient (Harmonized with Island)
    Rectangle {
        anchors.fill: parent
        radius: root.radius
        antialiasing: root.radius > 0
        visible: NexaUI.NexaOptics.surface3DGradient && NexaUI.NexaOptics.gradientIntensity > 0.01
        opacity: NexaUI.NexaOptics.gradientIntensity
        gradient: Gradient {
            GradientStop { position: 0.00; color: Qt.rgba(1, 1, 1, 0.060) }
            GradientStop { position: 0.40; color: Qt.rgba(1, 1, 1, 0.014) }
            GradientStop { position: 0.72; color: Qt.rgba(0, 0, 0, 0.000) }
            GradientStop { position: 1.00; color: Qt.rgba(0, 0, 0, 0.150) }
        }
    }

    // Top Chamfer Specular Highlight (Harmonized horizontal beam)
    Rectangle {
        anchors.top: parent.top
        anchors.topMargin: 1
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.radius > 0 ? Math.max(0, parent.width - root.radius * 1.6) : parent.width
        height: 1
        visible: NexaUI.NexaOptics.specularHighlight && NexaUI.NexaOptics.specularIntensity > 0.01
        opacity: Math.min(1.0, NexaUI.NexaOptics.specularIntensity / 0.28)
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, clockMouse.containsMouse ? 0.38 : 0.24) }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    Text {
        id: clockText
        anchors.centerIn: parent
        text: Qt.formatDateTime(root.currentTime, "hh:mm AP")
        color: clockMouse.containsMouse ? NexaUI.NexaColors.onSurface : NexaUI.NexaColors.text
        font.family: NexaUI.NexaTypography.familyBody
        font.pixelSize: NexaUI.NexaTypography.sizeSm
        font.weight: NexaUI.NexaTypography.weightMedium
        font.features: NexaUI.NexaTypography.fontFeaturesTnum
    }

    MouseArea {
        id: clockMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            root.clicked()
        }
    }
}
