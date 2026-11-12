import QtQuick
import QtQuick.Effects
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../../services" as Services
import "../../NewNexaUI" as NexaUI

Item {
    id: root

    implicitHeight: 32

    // ---------------------------------------------------------
    // Config Persistence
    // ---------------------------------------------------------
    readonly property string configPath:
        Quickshell.env("HOME") + "/.config/nexa/config/decorations/constellation_rail.json"

    readonly property string nexadBin:
        Quickshell.env("HOME") + "/.config/nexa/rust/target/release/nexad"

    property bool railEnabled: true
    property string railStyle: "constellation" // "none", "simple_line", "constellation"
    property string railMode: "workspaces"
    property string railDirection: "left-to-right" // "left-to-right" or "right-to-left"
    property real railSpeed: 1.0
    property real glowIntensity: 0.85
    property int particleCount: 8
    property real lineOpacity: 0.35

    // Native Nexa Media Service connection
    readonly property bool isMusicPlaying: Services.Media.isPlaying

    // Rail Color: Strictly tied to NexaUI theme (never modified by music album art)
    readonly property color railColor: NexaUI.NexaColors.primary

    // ---------------------------------------------------------
    // Live Hyprland Workspaces (Zero-Latency In-Memory Tracking)
    // ---------------------------------------------------------
    readonly property int activeWorkspaceId: (typeof Hyprland !== "undefined" && Hyprland.focusedWorkspace)
        ? Hyprland.focusedWorkspace.id
        : 1
    readonly property var occupiedWorkspaces: (typeof Hyprland !== "undefined" && Hyprland.workspaces)
        ? Hyprland.workspaces.values.map(w => w.id)
        : [1]

    // Visible only if enabled and style is not "none"
    visible: railEnabled && railStyle !== "none"

    function parseConfig(raw) {
        if (!raw || raw.trim() === "") return;
        try {
            const data = JSON.parse(raw);
            root.railEnabled = data.enabled !== undefined ? !!data.enabled : true;
            root.railStyle = data.style || "constellation";
            root.railMode = data.mode || "workspaces";
            root.railDirection = data.direction || "left-to-right";
            root.railSpeed = data.speed !== undefined ? Math.max(0.1, Number(data.speed)) : 1.0;
            root.glowIntensity = data.glow_intensity !== undefined ? Number(data.glow_intensity) : 0.85;
            root.particleCount = data.particle_count !== undefined ? Number(data.particle_count) : 8;
            root.lineOpacity = data.line_opacity !== undefined ? Number(data.line_opacity) : 0.35;
        } catch (e) {
            console.warn("[ConstellationRail] Error parsing config:", e);
        }
    }

    FileView {
        id: configFile
        path: root.configPath
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            if (configFile.text()) {
                root.parseConfig(configFile.text());
            }
        }
    }

    // ---------------------------------------------------------
    // Dynamic Center Gap: hugs the Island precisely in all modes
    // (Compact resting, compact media playing, OSD, or expanded card)
    // ---------------------------------------------------------
    readonly property real effectiveIslandWidth: {
        if (NexaUI.NexaTokens.islandTargetWidth && NexaUI.NexaTokens.islandTargetWidth > 0)
            return NexaUI.NexaTokens.islandTargetWidth;
        return root.isMusicPlaying ? 175 : 170;
    }
    property real centerGapHalfWidth: Math.round(root.effectiveIslandWidth / 2) + 12
    Behavior on centerGapHalfWidth {
        NumberAnimation { duration: 350; easing.type: Easing.OutCubic }
    }

    property real leftMargin: 160
    property real rightMargin: 160

    Behavior on leftMargin {
        NumberAnimation {
            duration: NexaUI.NexaMotion.durationNormal
            easing.type: NexaUI.NexaMotion.standardEasing
        }
    }

    readonly property real leftWingStartX: root.leftMargin
    readonly property real leftWingWidth: Math.max(0, (root.width / 2) - centerGapHalfWidth - leftWingStartX)

    readonly property real rightWingStartX: (root.width / 2) + centerGapHalfWidth
    readonly property real rightWingWidth: Math.max(0, (root.width - root.rightMargin) - rightWingStartX)

    // ---------------------------------------------------------
    // Wave Amplitude (Dynamic real audio reactivity from unified Rust visualizer)
    // ---------------------------------------------------------
    readonly property bool isAudioActive: root.isMusicPlaying
    readonly property real liveWaveAmp: root.isMusicPlaying ? (3.0 + Services.AudioVisualizer.energy * 2.0) : 0.0
    property real targetAmplitude: root.isAudioActive ? liveWaveAmp : 0.0
    property real waveAmplitude: 0.0
    Behavior on waveAmplitude {
        NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
    }
    onTargetAmplitudeChanged: waveAmplitude = targetAmplitude
    onIsMusicPlayingChanged: {
        if (!root.isMusicPlaying) {
            waveAmplitude = 0.0;
        }
    }

    // ---------------------------------------------------------
    // 60fps Phase Animators: Dual Speed (Fast + 50% Slower)
    // Dynamic tempo acceleration driven by Rust audio energy
    // ---------------------------------------------------------
    readonly property real audioSpeedMult: Services.AudioVisualizer.speedMultiplier

    // Set 1: Fast beads drift phase
    property real driftPhaseFast: 0.0
    NumberAnimation {
        target: root
        property: "driftPhaseFast"
        from: 0.0
        to: 1.0
        duration: Math.max(1600, 7500 / Math.max(0.1, root.railSpeed * (root.isAudioActive ? (1.3 * root.audioSpeedMult) : 1.0)))
        loops: Animation.Infinite
        running: root.visible && root.railStyle === "constellation"
    }

    // Set 2: Slower beads drift phase (50% slower = 2x duration)
    property real driftPhaseSlow: 0.0
    NumberAnimation {
        target: root
        property: "driftPhaseSlow"
        from: 0.0
        to: 1.0
        duration: Math.max(3200, 15000 / Math.max(0.1, root.railSpeed * (root.isAudioActive ? (1.3 * root.audioSpeedMult) : 1.0)))
        loops: Animation.Infinite
        running: root.visible && root.railStyle === "constellation"
    }

    // Wave oscillation phase (ripples the wave when music plays)
    property real wavePhase: 0.0
    NumberAnimation {
        target: root
        property: "wavePhase"
        from: 0.0
        to: 6.2831853 // 2 * PI
        duration: Math.max(800, 1600 / Math.max(0.4, root.audioSpeedMult))
        loops: Animation.Infinite
        running: root.visible && (root.waveAmplitude > 0.01)
    }

    // Centralized pulsating scale drivers (replaces 10+ independent bead animations)
    property real fastBeadPulseScale: 1.0
    property real slowBeadPulseScale: 1.0

    SequentialAnimation on fastBeadPulseScale {
        running: root.visible && (root.isMusicPlaying || root.particleCount > 0) && root.railStyle === "constellation"
        loops: Animation.Infinite
        NumberAnimation { from: 0.90; to: 1.15; duration: 750; easing.type: Easing.InOutSine }
        NumberAnimation { from: 1.15; to: 0.90; duration: 750; easing.type: Easing.InOutSine }
    }

    SequentialAnimation on slowBeadPulseScale {
        running: root.visible && (root.isMusicPlaying || root.particleCount > 0) && root.railStyle === "constellation"
        loops: Animation.Infinite
        NumberAnimation { from: 0.92; to: 1.20; duration: 950; easing.type: Easing.InOutSine }
        NumberAnimation { from: 1.20; to: 0.92; duration: 950; easing.type: Easing.InOutSine }
    }

    // =========================================================
    // WING RAIL COMPONENT
    // =========================================================
    component RailWing: Item {
        id: wingRoot
        property bool isRightSide: false
        property int fastBeadsCount: Math.max(1, Math.round(root.particleCount * 0.35))
        property int slowBeadsCount: Math.max(1, Math.round(root.particleCount * 0.20))

        function requestRepaint() {
            waveCanvas.requestPaint();
        }

        clip: false

        // Laser glow shadow halo (Just like progress bar of music section)
        RectangularShadow {
            id: railLaserGlow
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: 4
            radius: 2
            blur: root.isMusicPlaying ? (12 + 8 * Math.min(1.0, Services.AudioVisualizer.bass * 2.0)) : 12
            color: Qt.rgba(root.railColor.r, root.railColor.g, root.railColor.b, 0.75)
            opacity: root.isMusicPlaying ? 1.0 : 0.0
            visible: opacity > 0.001

            Behavior on opacity {
                NumberAnimation { duration: 350; easing.type: Easing.OutCubic }
            }
        }

        // Continuous line / wave renderer
        Canvas {
            id: waveCanvas
            anchors.fill: parent
            renderTarget: Canvas.FramebufferObject

            property real currentAmp: root.waveAmplitude
            property real currentWPhase: root.wavePhase
            property var currentBars: Services.AudioVisualizer.bars
            property color lineColor: root.railColor
            property real lineAlpha: root.isMusicPlaying ? Math.min(0.85, root.lineOpacity * 1.5) : root.lineOpacity

            // Immediate repaint when theme color or opacity changes (e.g. wallpaper change or track change)
            onLineColorChanged: waveCanvas.requestPaint()
            onLineAlphaChanged: waveCanvas.requestPaint()

            // Single unified paint trigger: active when music is playing or wave is animating
            Connections {
                target: Services.AudioVisualizer
                enabled: root.visible && (root.isMusicPlaying || waveCanvas.currentAmp > 0.01)
                function onFrameTick() {
                    waveCanvas.requestPaint();
                }
            }

            // Repaint when transitioning between active wave and straight rail line
            onCurrentAmpChanged: waveCanvas.requestPaint()

            Connections {
                target: root
                function onIsMusicPlayingChanged() {
                    waveCanvas.requestPaint();
                }
            }

            onPaint: {
                const ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);

                ctx.strokeStyle = Qt.rgba(lineColor.r, lineColor.g, lineColor.b, lineAlpha);
                ctx.lineWidth = root.isMusicPlaying ? 2.0 : 1.6;
                ctx.lineCap = "round";
                ctx.beginPath();

                const midY = height / 2;
                if (currentAmp <= 0.05) {
                    // Normal state: perfectly straight rail line
                    ctx.moveTo(0, midY);
                    ctx.lineTo(width, midY);
                } else {
                    ctx.moveTo(0, midY);
                    // Optimized step resolution: 18-32 steps is visually identical to 200 steps on a 5px wave
                    const steps = Math.min(32, Math.max(18, Math.floor(width / 22)));
                    const dx = width / steps;
                    const sidePhase = wingRoot.isRightSide ? 1.5 : 0.0;
                    const phase1 = currentWPhase + sidePhase;
                    const phase2 = currentWPhase * 1.6;
                    const amp = currentAmp;
                    const maxSafePeak = 5.0; // Strictly capped at 5px height
                    const pi = Math.PI;

                    const bars = currentBars || [];
                    const barsLen = bars.length;

                    for (let i = 0; i <= steps; i++) {
                        const px = i * dx;
                        const progress = i / steps;

                        // Taper ends to anchor smoothly at endpoints
                        const envelope = Math.sin(progress * pi);

                        // Frequency spectrum sampling along the wing
                        let barVal = 0.0;
                        if (barsLen > 0) {
                            const barIdx = Math.min(barsLen - 1, Math.floor(progress * barsLen));
                            barVal = bars[barIdx] || 0.0;
                        }

                        // Harmonic musical soundwave with safety peak clamp
                        const w1 = Math.sin((px * 0.028) + phase1);
                        const w2 = Math.sin((px * 0.065) + phase2);
                        const rawOffset = (w1 * 0.65 + w2 * 0.35) * (0.35 + barVal * 0.85) * amp * envelope;
                        const acousticOffset = Math.max(-maxSafePeak, Math.min(maxSafePeak, rawOffset));

                        ctx.lineTo(px, midY + acousticOffset);
                    }
                }
                ctx.stroke();
            }
        }

        // =====================================================
        // SET 1: FAST BEADS (Only visible in "constellation" mode)
        // =====================================================
        Repeater {
            model: root.railStyle === "constellation" ? wingRoot.fastBeadsCount : 0

            Item {
                id: fastBead
                width: 24
                height: 24

                readonly property int wsId: wingRoot.isRightSide
                    ? (index + 5)
                    : (index + 1)

                readonly property bool isActiveWs: root.activeWorkspaceId === wsId
                readonly property bool isOccupiedWs: root.occupiedWorkspaces.indexOf(wsId) !== -1

                // Drift progress (Fast)
                readonly property real progress: {
                    const base = (index / wingRoot.fastBeadsCount);
                    if (root.railDirection === "right-to-left") {
                        return (1.0 - root.driftPhaseFast + base) % 1.0;
                    } else {
                        return (root.driftPhaseFast + base) % 1.0;
                    }
                }

                x: Math.round(progress * Math.max(1, wingRoot.width - width))
                readonly property real beadProgress: Math.max(0, Math.min(1, x / Math.max(1, wingRoot.width)))
                readonly property real envelope: Math.sin(beadProgress * Math.PI)
                readonly property real sidePhase: wingRoot.isRightSide ? 1.5 : 0.0
                readonly property real w1: Math.sin((x * 0.028) + root.wavePhase + sidePhase)
                readonly property real w2: Math.sin((x * 0.068) + (root.wavePhase * 1.7))
                readonly property real barVal: (Services.AudioVisualizer.bars && Services.AudioVisualizer.bars.length > 0)
                    ? (Services.AudioVisualizer.bars[Math.min(Services.AudioVisualizer.bars.length - 1, Math.floor(beadProgress * Services.AudioVisualizer.bars.length))] || 0)
                    : 0
                readonly property real rawOffset: (w1 * 0.65 + w2 * 0.35) * (0.35 + barVal * 0.85) * root.waveAmplitude * envelope
                readonly property real acousticOffset: Math.max(-5.0, Math.min(5.0, rawOffset))
                readonly property real waveY: (wingRoot.height / 2) + (root.waveAmplitude > 0.05 ? acousticOffset : 0)
                y: Math.round(waveY - (height / 2))

                // Standard subtle halo (pulses dynamically on bass kicks)
                Rectangle {
                    anchors.centerIn: parent
                    width: isActiveWs ? 20 : (isOccupiedWs ? 15 : (root.isMusicPlaying ? (11 + Math.round(Services.AudioVisualizer.bass * 8)) : 11))
                    height: width
                    radius: width / 2
                    color: Qt.rgba(
                        root.railColor.r,
                        root.railColor.g,
                        root.railColor.b,
                        isActiveWs ? (0.35 * root.glowIntensity) : ((0.28 + Services.AudioVisualizer.bass * 0.25) * root.glowIntensity)
                    )

                    Behavior on width { NumberAnimation { duration: 200 } }
                    scale: (isActiveWs || root.isMusicPlaying) ? root.fastBeadPulseScale : 1.0
                }

                // Standard core dot
                Rectangle {
                    anchors.centerIn: parent
                    width: isActiveWs ? 5.0 : (isOccupiedWs ? 4.0 : 3.2)
                    height: width
                    radius: width / 2
                    color: {
                        if (isActiveWs) return NexaUI.NexaColors.text;
                        if (isOccupiedWs) return root.railColor;
                        return Qt.rgba(NexaUI.NexaColors.text.r, NexaUI.NexaColors.text.g, NexaUI.NexaColors.text.b, 0.70);
                    }
                }
            }
        }

        // =====================================================
        // SET 2: SLOW BEADS (50% slower + brighter glowing aura)
        // =====================================================
        Repeater {
            model: root.railStyle === "constellation" ? wingRoot.slowBeadsCount : 0

            Item {
                id: slowBead
                width: 28
                height: 28

                readonly property int wsId: wingRoot.isRightSide
                    ? (index + 8)
                    : (index + 3)

                readonly property bool isActiveWs: root.activeWorkspaceId === wsId
                readonly property bool isOccupiedWs: root.occupiedWorkspaces.indexOf(wsId) !== -1

                // Drift progress (Slow: 50% speed)
                readonly property real progress: {
                    const base = (index / wingRoot.slowBeadsCount) + 0.38;
                    if (root.railDirection === "right-to-left") {
                        return (1.0 - root.driftPhaseSlow + base) % 1.0;
                    } else {
                        return (root.driftPhaseSlow + base) % 1.0;
                    }
                }

                x: Math.round(progress * Math.max(1, wingRoot.width - width))
                readonly property real beadProgress: Math.max(0, Math.min(1, x / Math.max(1, wingRoot.width)))
                readonly property real envelope: Math.sin(beadProgress * Math.PI)
                readonly property real sidePhase: wingRoot.isRightSide ? 1.5 : 0.0
                readonly property real w1: Math.sin((x * 0.028) + root.wavePhase + sidePhase)
                readonly property real w2: Math.sin((x * 0.068) + (root.wavePhase * 1.7))
                readonly property real barVal: (Services.AudioVisualizer.bars && Services.AudioVisualizer.bars.length > 0)
                    ? (Services.AudioVisualizer.bars[Math.min(Services.AudioVisualizer.bars.length - 1, Math.floor(beadProgress * Services.AudioVisualizer.bars.length))] || 0)
                    : 0
                readonly property real rawOffset: (w1 * 0.65 + w2 * 0.35) * (0.35 + barVal * 0.85) * root.waveAmplitude * envelope
                readonly property real acousticOffset: Math.max(-5.0, Math.min(5.0, rawOffset))
                readonly property real waveY: (wingRoot.height / 2) + (root.waveAmplitude > 0.05 ? acousticOffset : 0)
                y: Math.round(waveY - (height / 2))

                // Brighter luminous flare / halo (reacts to overall audio energy)
                Rectangle {
                    anchors.centerIn: parent
                    width: isActiveWs ? 26 : (isOccupiedWs ? 22 : (root.isMusicPlaying ? (17 + Math.round(Services.AudioVisualizer.energy * 10)) : 17))
                    height: width
                    radius: width / 2
                    color: Qt.rgba(
                        root.railColor.r,
                        root.railColor.g,
                        root.railColor.b,
                        isActiveWs ? (0.55 * root.glowIntensity) : ((0.42 + Services.AudioVisualizer.energy * 0.30) * root.glowIntensity)
                    )

                    Behavior on width { NumberAnimation { duration: 220 } }
                    scale: (isActiveWs || root.isMusicPlaying) ? root.slowBeadPulseScale : 1.0
                }

                // Brighter, slightly larger core bead
                Rectangle {
                    anchors.centerIn: parent
                    width: isActiveWs ? 6.0 : (isOccupiedWs ? 5.0 : 4.2)
                    height: width
                    radius: width / 2
                    color: NexaUI.NexaColors.text

                    Behavior on width { NumberAnimation { duration: 180 } }
                }
            }
        }
    }

    // ---------------------------------------------------------
    // Left Wing Rail (Left of Island)
    // ---------------------------------------------------------
    RailWing {
        id: leftWing
        x: root.leftWingStartX
        y: 0
        width: root.leftWingWidth
        height: parent.height
        isRightSide: false
        visible: width > 30
    }

    // ---------------------------------------------------------
    // Right Wing Rail (Right of Island)
    // ---------------------------------------------------------
    RailWing {
        id: rightWing
        x: root.rightWingStartX
        y: 0
        width: root.rightWingWidth
        height: parent.height
        isRightSide: true
        visible: width > 30
    }
}
