import QtQuick
import "../core" as Core

Rectangle {
    id: root

    // ============================================================
    // PROPERTIES & API
    // ============================================================
    property bool checked: false
    property alias interactive: root.enabled
    signal toggled(bool newState)

    implicitWidth: 44
    implicitHeight: 24
    radius: Core.NexaTokens.radiusPill

    readonly property bool isHovered: mouseArea.containsMouse && enabled
    readonly property bool isPressed: mouseArea.pressed && enabled

    // Track Background
    color: {
        if (!enabled) return Core.NexaColors.alpha(Core.NexaColors.onSurface, 0.12);
        if (checked) {
            return isPressed ? Core.NexaColors.pressOverlay(Core.NexaColors.primary) : (isHovered ? Core.NexaColors.alpha(Core.NexaColors.primary, 0.9) : Core.NexaColors.primary);
        }
        return isHovered ? Core.NexaColors.surfaceContainerHighest : Core.NexaColors.surfaceContainerHigh;
    }

    border.width: checked ? 0 : Core.NexaTokens.borderThin
    border.color: isHovered ? Core.NexaColors.outline : Core.NexaColors.outlineVariant

    Behavior on color {
        ColorAnimation { duration: Core.NexaMotion.durationFast; easing.type: Easing.OutQuad }
    }

    // Specular Chamfer Highlight
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        radius: parent.radius
        color: Qt.rgba(1, 1, 1, (root.checked ? 0.25 : 0.1) * Core.NexaOptics.specularIntensity)
        visible: Core.NexaOptics.specularHighlight
    }

    // Toggle Knob (Thumb)
    Rectangle {
        id: knob
        width: 18
        height: 18
        radius: Core.NexaTokens.radiusPill
        anchors.verticalCenter: parent.verticalCenter
        x: root.checked ? (root.width - width - 3) : 3

        color: {
            if (!root.enabled) return Core.NexaColors.alpha(Core.NexaColors.onSurface, 0.38);
            return root.checked ? Core.NexaColors.onPrimary : Core.NexaColors.onSurfaceVariant;
        }

        // Slight stretch when pressed (haptic tactile feel)
        scale: root.isPressed ? 0.85 : (mouseArea.containsMouse ? 1.06 : 1.0)

        Behavior on x {
            enabled: Core.NexaMotion.enabled
            SpringAnimation {
                spring: Core.NexaMotion.useSpring("sliders") ? (Core.NexaMotion.springStiffness * 4.5 * Core.NexaMotion.effectiveSpeed) : 18.0
                damping: Core.NexaMotion.useSpring("sliders") ? Core.NexaMotion.springDamping : 1.0
                mass: Core.NexaMotion.springMass
                epsilon: 0.1
            }
        }
        Behavior on scale {
            enabled: Core.NexaMotion.enabled
            SpringAnimation {
                spring: Core.NexaMotion.springStiffness * 4.0
                damping: Core.NexaMotion.springDamping
                mass: Core.NexaMotion.springMass
                epsilon: 0.005
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: {
            root.checked = !root.checked;
            root.toggled(root.checked);
        }
    }
}
