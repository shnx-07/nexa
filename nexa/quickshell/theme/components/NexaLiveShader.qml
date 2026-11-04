import QtQuick
import Quickshell

// =============================================================================
// NEXA Universal Live Shader Template Component
// =============================================================================
// Embeds a GPU-accelerated moving fragment shader into any card, popup, or window.
// Features built-in smart CPU-sleep checks (0% CPU when parent is hidden).
//
// Usage:
//   NexaLiveShader {
//       source: "theme/aurora.frag.qsb"  // Or full URL or just preset name
//       speed: 1.0
//       intensity: 0.85
//   }
// =============================================================================
Item {
    id: root

    anchors.fill: parent
    z: 0
    clip: true

    // Core Shader Configuration
    property string source: ""
    property real speed: 1.0
    property real intensity: 0.85
    property real shaderOpacity: 0.85
    property real veilAlpha: 0.30
    property int radius: parent.radius !== undefined ? parent.radius : 0
    property bool showSpecularLine: root.radius === 0

    // Palette Colors
    property color veilColor: Qt.rgba(0.06, 0.08, 0.11, 0.32)
    property color accentA: Qt.rgba(0.75, 0.0, 0.04, 1.0)
    property color accentB: root.accentA

    // ── SMART CPU-THROTTLING & VISIBILITY CHECK ──────────────────
    // Ensures shaders DO NOT consume CPU cycles when parent popups are hidden
    readonly property bool parentVisible: (root.parent !== null && root.parent.visible !== undefined) ? root.parent.visible : true
    readonly property bool parentOpaque: (root.parent !== null && root.parent.opacity !== undefined) ? root.parent.opacity > 0.01 : true
    readonly property bool shouldRender: root.visible && root.parentVisible && root.parentOpaque && root.opacity > 0.01 && root.resolvedShaderUrl !== ""

    // Path Resolution (Supports short names, relative subpaths, and absolute file URLs)
    readonly property url resolvedShaderUrl: {
        if (!root.source || root.source.trim() === "" || root.source === "off") return "";
        const s = root.source.trim();
        if (s.startsWith("file://") || s.startsWith("qrc:/")) return s;
        if (s.startsWith("/")) return "file://" + s;

        const baseDir = Quickshell.env("HOME") + "/.config/nexa/quickshell/shaders/";
        if (s.endsWith(".qsb")) {
            return "file://" + (s.includes("/") ? baseDir + s : baseDir + "theme/" + s);
        }
        return "file://" + baseDir + "theme/" + s + ".frag.qsb";
    }

    // ── DEDICATED GPU ANIMATION CLOCK (ONLY TICKS WHEN VISIBLE) ──
    property real iTime: 0.0
    property real time: iTime * 0.001

    Timer {
        id: frameClock
        interval: 16 // 60 FPS
        repeat: true
        running: root.shouldRender
        property double lastTime: Date.now()

        onRunningChanged: {
            if (running) lastTime = Date.now();
        }

        onTriggered: {
            const now = Date.now();
            const dt = (now - lastTime) / 1000.0;
            lastTime = now;
            root.iTime += dt * 1000.0 * Math.max(0.1, root.speed);
        }
    }

    // ── 1. ACTIVE GPU SHADER EFFECT ──────────────────────────────
    ShaderEffect {
        id: effect
        anchors.fill: parent
        visible: root.shouldRender
        opacity: root.shaderOpacity

        property real itemWidth: width
        property real itemHeight: height
        property real iTime: root.iTime
        property real time: root.time
        property real speed: root.speed
        property real intensity: root.intensity
        property real veilAlpha: root.veilAlpha
        property real radius: root.radius
        property color veilColor: root.veilColor
        property color accentA: root.accentA
        property color accentB: root.accentB

        fragmentShader: root.resolvedShaderUrl
    }

    // ── 2. MATHEMATICAL CONTRAST VEIL ────────────────────────────
    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: Qt.rgba(0, 0, 0, root.veilAlpha * 0.35)
        visible: root.shouldRender && root.veilAlpha > 0.01
    }

    // ── 3. TOP SPECULAR GLASS HIGHLIGHT ──────────────────────────
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        visible: root.shouldRender && root.showSpecularLine
        color: Qt.rgba(255, 255, 255, 0.15)
    }
}
