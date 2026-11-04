import QtQuick
import Quickshell
import ".." as Nexa

Item {
    id: root

    anchors.fill: parent
    z: 0
    clip: true

    // ── SMART CPU & VISIBILITY CHECK ─────────────────────────────
    // Shaders only render when active, AND when their parent window/popup
    // is actually visible on screen. This stops hidden popups from
    // dirtying the scene graph and eliminates CPU spikes.
    readonly property bool parentVisible: (root.parent !== null && root.parent.visible !== undefined) ? root.parent.visible : true
    readonly property bool parentOpaque: (root.parent !== null && root.parent.opacity !== undefined) ? root.parent.opacity > 0.01 : true

    visible: Nexa.Theme.activeShader !== "off" && Nexa.Theme.activeShaderFile !== "" && root.parentVisible && root.parentOpaque

    property int radius: parent.radius !== undefined ? parent.radius : 0
    property bool showSpecularLine: root.radius === 0

    // 1. Active GPU Fragment Shader (Outputs premultiplied translucent alpha)
    ShaderEffect {
        id: effect
        anchors.fill: parent
        opacity: Nexa.Theme.shaderOpacity

        property real itemWidth: width
        property real itemHeight: height
        property real iTime: Nexa.Theme.globalShaderTime
        property real speed: Nexa.Theme.shaderSpeed
        property real intensity: Nexa.Theme.shaderIntensity
        property real veilAlpha: Nexa.Theme.shaderContrastVeil
        property real radius: root.radius
        property color veilColor: Nexa.Theme.surfaceContainer || Qt.rgba(0.06, 0.08, 0.11, 0.32)
        property color accentA: Nexa.Theme.primary
        property color accentB: Nexa.Theme.secondary ? Nexa.Theme.secondary : Nexa.Theme.primary

        fragmentShader: Nexa.Theme.activeShaderUrl
    }

    // 2. Mathematical Contrast Veil (Soft translucent darkening tint for text legibility)
    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: Qt.rgba(0, 0, 0, Nexa.Theme.shaderContrastVeil * 0.35)
        visible: Nexa.Theme.shaderContrastVeil > 0.01
    }

    // 3. Top Specular Glass Edge Highlight
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        visible: root.showSpecularLine
        color: Qt.rgba(255, 255, 255, 0.15)
    }
}
