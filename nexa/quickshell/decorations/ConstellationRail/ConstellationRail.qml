import QtQuick
import Quickshell
import Quickshell.Io
import "../../theme" as Nexa
import "../../services" as Services

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

    property int activeWorkspaceId: 1
    property var occupiedWorkspaces: [1]

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
    // Rust State Sync (Workspaces & backend state)
    // ---------------------------------------------------------
    Process {
        id: stateProcess
        command: [root.nexadBin, "decoration", "constellation", "state"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                if (!data || data.trim() === "") return;
                try {
                    const st = JSON.parse(data);
                    if (st.nodes && Array.isArray(st.nodes)) {
                        const occupied = [];
                        for (let i = 0; i < st.nodes.length; ++i) {
                            if (st.nodes[i].active) root.activeWorkspaceId = st.nodes[i].id;
                            if (st.nodes[i].occupied) occupied.push(st.nodes[i].id);
                        }
                        root.occupiedWorkspaces = occupied;
                    }
                } catch (_) {}
            }
        }
    }

    Timer {
        id: syncTimer
        interval: 800
        repeat: true
        running: root.visible
        triggeredOnStart: true
        onTriggered: {
            if (!stateProcess.running) {
                stateProcess.running = true;
            }
        }
    }

    // ---------------------------------------------------------
    // Dynamic Center Gap: expands smoothly when Island has song info!
    // ---------------------------------------------------------
    property real centerGapHalfWidth: root.isMusicPlaying ? 220 : 95
    Behavior on centerGapHalfWidth {
        NumberAnimation { duration: 350; easing.type: Easing.OutCubic }
    }

    property real leftMargin: 160
    property real rightMargin: 160

    readonly property real leftWingStartX: root.leftMargin
    readonly property real leftWingWidth: Math.max(0, (root.width / 2) - centerGapHalfWidth - leftWingStartX)

    readonly property real rightWingStartX: (root.width / 2) + centerGapHalfWidth
    readonly property real rightWingWidth: Math.max(0, (root.width - root.rightMargin) - rightWingStartX)

    // ---------------------------------------------------------
    // Wave Amplitude (Dynamic real audio reactivity from unified Rust visualizer)
    // ---------------------------------------------------------
    readonly property bool isAudioActive: (Services.AudioVisualizer.energy > 0.015) || root.isMusicPlaying
    readonly property real liveWaveAmp: (3.0 + Services.AudioVisualizer.energy * 2.0)
    property real targetAmplitude: root.isAudioActive ? liveWaveAmp : 0.0
    property real waveAmplitude: 0.0
    Behavior on waveAmplitude {
        NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
    }
    onTargetAmplitudeChanged: waveAmplitude = targetAmplitude

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

        // Continuous line / wave renderer
        Canvas {
            id: waveCanvas
            anchors.fill: parent

            property real currentAmp: root.waveAmplitude
            property real currentWPhase: root.wavePhase
            property var currentBars: Services.AudioVisualizer.bars
            property color lineColor: Nexa.Theme.primary
            property real lineAlpha: root.lineOpacity

            // Immediate repaint when theme color or opacity changes (e.g. wallpaper change)
            onLineColorChanged: waveCanvas.requestPaint()
            onLineAlphaChanged: waveCanvas.requestPaint()

            // Single unified paint trigger: exactly matches audio frames (30fps)
            Connections {
                target: Services.AudioVisualizer
                function onFrameTick() {
                    if (waveCanvas.currentAmp > 0.05) {
                        waveCanvas.requestPaint();
                    }
                }
            }

            // Single repaint when transitioning between straight rail line and active wave
            onCurrentAmpChanged: {
                if (currentAmp <= 0.05 || Math.abs(currentAmp - 0.05) < 0.1) {
                    waveCanvas.requestPaint();
                }
            }

            onPaint: {
                const ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);

                ctx.strokeStyle = Qt.rgba(lineColor.r, lineColor.g, lineColor.b, lineAlpha);
                ctx.lineWidth = 1.6;
                ctx.lineCap = "round";
                ctx.beginPath();

                const midY = height / 2;
                if (currentAmp <= 0.05) {
                    // Normal state: perfectly straight rail line
                    ctx.moveTo(0, midY);
                    ctx.lineTo(width, midY);
                } else {
                    ctx.moveTo(0, midY);
                    // Optimized step resolution: 35-48 steps is visually identical to 200 steps on a 5px wave
                    const steps = Math.min(48, Math.max(28, Math.floor(width / 14)));
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
                        Nexa.Theme.primary.r,
                        Nexa.Theme.primary.g,
                        Nexa.Theme.primary.b,
                        isActiveWs ? (0.35 * root.glowIntensity) : ((0.18 + Services.AudioVisualizer.bass * 0.15) * root.glowIntensity)
                    )

                    Behavior on width { NumberAnimation { duration: 200 } }

                    SequentialAnimation on scale {
                        running: isActiveWs || root.isMusicPlaying
                        loops: Animation.Infinite
                        NumberAnimation { from: 0.90; to: 1.15; duration: 750; easing.type: Easing.InOutSine }
                        NumberAnimation { from: 1.15; to: 0.90; duration: 750; easing.type: Easing.InOutSine }
                    }
                }

                // Standard core dot
                Rectangle {
                    anchors.centerIn: parent
                    width: isActiveWs ? 5.0 : (isOccupiedWs ? 4.0 : 3.2)
                    height: width
                    radius: width / 2
                    color: {
                        if (isActiveWs) return Nexa.Theme.text;
                        if (isOccupiedWs) return Nexa.Theme.primary;
                        return Qt.rgba(Nexa.Theme.text.r, Nexa.Theme.text.g, Nexa.Theme.text.b, 0.70);
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
                        Nexa.Theme.primary.r,
                        Nexa.Theme.primary.g,
                        Nexa.Theme.primary.b,
                        isActiveWs ? (0.55 * root.glowIntensity) : ((0.32 + Services.AudioVisualizer.energy * 0.20) * root.glowIntensity)
                    )

                    Behavior on width { NumberAnimation { duration: 220 } }

                    SequentialAnimation on scale {
                        running: (isActiveWs || root.isMusicPlaying) && root.visible
                        loops: Animation.Infinite
                        NumberAnimation { from: 0.92; to: 1.20; duration: 950; easing.type: Easing.InOutSine }
                        NumberAnimation { from: 1.20; to: 0.92; duration: 950; easing.type: Easing.InOutSine }
                    }
                }

                // Brighter, slightly larger core bead
                Rectangle {
                    anchors.centerIn: parent
                    width: isActiveWs ? 6.0 : (isOccupiedWs ? 5.0 : 4.2)
                    height: width
                    radius: width / 2
                    color: Nexa.Theme.text

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
