import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import "../core" as Core

Rectangle {
    id: root

    // ============================================================
    // PROPERTIES & API
    // ============================================================
    property int customRadius: -1
    property int customHeight: 0
    property color customColor: "transparent"
    property int elevation: Core.NexaTokens.elevation1
    property bool interactive: false
    property bool selected: false
    property int padding: 0
    property alias hovered: mouseArea.containsMouse
    property alias pressed: mouseArea.pressed

    signal clicked()

    radius: customRadius >= 0 ? customRadius : Core.NexaTokens.radiusLg
    implicitHeight: customHeight > 0 ? customHeight : 0
    Layout.preferredWidth: implicitWidth > 0 ? implicitWidth : -1
    Layout.preferredHeight: implicitHeight > 0 ? implicitHeight : -1

    // Dynamic 3D depth background
    color: {
        if (customColor !== "transparent") return customColor;
        if (interactive && mouseArea.pressed) return Core.NexaColors.surfaceContainerHighest;
        if (interactive && mouseArea.containsMouse) return Core.NexaColors.surfaceContainerHigh;
        if (elevation === Core.NexaTokens.elevation0) return "transparent";
        if (elevation === Core.NexaTokens.elevation1) return Core.NexaColors.surfaceContainer;
        if (elevation === Core.NexaTokens.elevation2) return Core.NexaColors.surfaceContainerHigh;
        return Core.NexaColors.surfaceContainerHighest;
    }

    border.width: Core.NexaTokens.borderThin
    border.color: {
        if (selected) return Core.NexaColors.alpha(Core.NexaColors.primary, 0.5);
        if (interactive && mouseArea.containsMouse) return Core.NexaColors.alpha(Core.NexaColors.primary, 0.4);
        return Core.NexaColors.border;
    }

    Behavior on color {
        ColorAnimation { duration: Core.NexaMotion.durationFast; easing.type: Easing.OutQuad }
    }
    Behavior on border.color {
        ColorAnimation { duration: Core.NexaMotion.durationFast; easing.type: Easing.OutQuad }
    }

    scale: (root.interactive && mouseArea.pressed) ? Core.NexaMotion.scalePress : ((root.interactive && mouseArea.containsMouse) ? Core.NexaMotion.scaleHover : 1.0)
    Behavior on scale {
        enabled: Core.NexaMotion.enabled && root.interactive
        SpringAnimation {
            spring: Core.NexaMotion.springStiffness
            damping: Core.NexaMotion.springDamping
            mass: Core.NexaMotion.springMass
            epsilon: 0.002
        }
    }

    // Tactile 3D Micro-Gradient (Layer 2 depth on elevated/selected cards)
    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        antialiasing: parent.radius > 0
        visible: Core.NexaOptics.surface3DGradient && Core.NexaOptics.gradientIntensity > 0.01 && (root.elevation >= Core.NexaTokens.elevation2 || root.selected)
        opacity: Core.NexaOptics.gradientIntensity
        gradient: Gradient {
            GradientStop { position: 0.00; color: Qt.rgba(1, 1, 1, 0.045) }
            GradientStop { position: 0.40; color: Qt.rgba(1, 1, 1, 0.010) }
            GradientStop { position: 0.75; color: Qt.rgba(0, 0, 0, 0.000) }
            GradientStop { position: 1.00; color: Qt.rgba(0, 0, 0, 0.090) }
        }
    }

    // Top Chamfer Specular Highlight (Layer 2 specular reflection)
    Rectangle {
        id: chamfer
        anchors.top: parent.top
        anchors.topMargin: 1
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.radius > 0 ? Math.max(0, parent.width - root.radius * 1.5) : parent.width
        height: 1
        visible: Core.NexaOptics.specularHighlight && (root.elevation > Core.NexaTokens.elevation0 || root.selected)
        opacity: Math.min(1.0, Core.NexaOptics.specularIntensity / 0.28)
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop {
                position: 0.5
                color: Qt.rgba(1, 1, 1, root.selected ? 0.35 : (root.interactive && mouseArea.containsMouse ? 0.25 : 0.14))
            }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        enabled: root.interactive
        hoverEnabled: root.interactive
        cursorShape: root.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.clicked()
    }
}
