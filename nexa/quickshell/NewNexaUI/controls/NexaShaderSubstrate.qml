import QtQuick
import Quickshell
import "../core" as Core

Item {
    id: root

    anchors.fill: parent
    z: 0
    clip: true

    readonly property bool parentVisible: (root.parent !== null && root.parent.visible !== undefined) ? root.parent.visible : true
    readonly property bool parentOpaque: (root.parent !== null && root.parent.opacity !== undefined) ? root.parent.opacity > 0.01 : true

    visible: Core.NexaOptics.activeShader !== "off" && Core.NexaOptics.activeShader !== "none" && Core.NexaOptics.activeShaderFile !== "" && root.parentVisible && root.parentOpaque

    property int radius: parent.radius !== undefined ? parent.radius : 0
    property bool showSpecularLine: root.radius === 0

    // 1. Active GPU Fragment Shader (Outputs premultiplied translucent alpha)
    ShaderEffect {
        id: effect
        anchors.fill: parent
        opacity: Core.NexaOptics.shaderOpacity

        property real itemWidth: width
        property real itemHeight: height
        property real iTime: Core.NexaOptics.globalShaderTime
        property real speed: Core.NexaOptics.shaderSpeed
        property real intensity: Core.NexaOptics.shaderIntensity
        property real veilAlpha: Core.NexaOptics.shaderContrastVeil
        property real radius: root.radius
        property color veilColor: Core.NexaColors.surfaceContainer
        property color accentA: Core.NexaColors.primary
        property color accentB: Core.NexaColors.secondary

        fragmentShader: Core.NexaOptics.activeShaderUrl
    }

    // 2. Mathematical Contrast Veil (Soft translucent darkening tint for text legibility)
    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: Qt.rgba(0, 0, 0, Core.NexaOptics.shaderContrastVeil * 0.35)
        visible: Core.NexaOptics.shaderContrastVeil > 0.01
    }

    // 3. Top Specular Glass Edge Highlight
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        visible: root.showSpecularLine && Core.NexaOptics.specularHighlight
        color: Qt.rgba(1, 1, 1, 0.15 * Core.NexaOptics.specularIntensity)
    }
}

