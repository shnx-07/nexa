import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

import "../theme" as Nexa

Rectangle {
    id: root

    // ============================================================
    // PLAYING STATE
    // ============================================================

    readonly property bool isPlaying: {
        const players = Mpris.players.values
        for (let i = 0; i < players.length; ++i) {
            if (players[i] && players[i].playbackState === MprisPlaybackState.Playing)
                return true
        }
        return false
    }

    // ============================================================
    // CAVA AUDIO REACTIVITY (64 BINS) - OPTIMIZED
    // ============================================================

    property var spectrumBins: []
    property real energy: 0.15
    property real bassEnergy: 0.15
    property real midEnergy: 0.15
    property real trebleEnergy: 0.15

    Process {
        id: cavaProcess
        running: root.isPlaying && root.visible
        command: [
            "cava",
            "-p",
            Quickshell.env("HOME") + "/.config/nexa/config/cava.conf"
        ]

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                const line = data.trim()
                if (line === "") return
                const parts = line.split(";")
                const values = []
                let sum = 0
                let bassSum = 0
                let midSum = 0
                let trebleSum = 0

                const len = parts.length
                for (let i = 0; i < len; ++i) {
                    const pStr = parts[i]
                    if (pStr === "") continue
                    const raw = Number(pStr)
                    if (isNaN(raw)) continue
                    const val = Math.max(0.0, Math.min(1.0, (raw / 1000.0) * 1.25))
                    values.push(val)
                    sum += val

                    if (i < 16) bassSum += val
                    else if (i <= 40) midSum += val
                    else trebleSum += val
                }

                if (values.length > 0) {
                    root.spectrumBins = values
                    root.energy = Math.max(0.12, sum / values.length)
                    root.bassEnergy = Math.max(0.12, bassSum / Math.min(16, values.length))
                    root.midEnergy = Math.max(0.12, midSum / Math.max(1, Math.min(25, values.length - 16)))
                    root.trebleEnergy = Math.max(0.12, trebleSum / Math.max(1, values.length - 41))
                }
            }
        }

        onRunningChanged: {
            if (!running) {
                root.spectrumBins = []
                root.energy = 0.15
                root.bassEnergy = 0.15
                root.midEnergy = 0.15
                root.trebleEnergy = 0.15
            }
        }
    }

    // ============================================================
    // CAPSULE GEOMETRY & MATUGEN GLASS STYLING (BIGGER & BOLDER)
    // ============================================================

    implicitHeight: 30
    implicitWidth: isPlaying ? 280 : 0
    opacity: isPlaying ? 1.0 : 0.0
    visible: opacity > 0.01
    clip: true

    radius: height / 2
    color: Nexa.Theme.surfaceContainer

    // Multi-color audio-reactive border that pulses with the bass beat
    border {
        width: Nexa.Theme.borderThin
        color: Qt.rgba(
            Nexa.Theme.primary.r,
            Nexa.Theme.primary.g,
            Nexa.Theme.primary.b,
            0.22 + Math.min(0.55, root.bassEnergy * 0.70)
        )
    }

    Behavior on implicitWidth {
        NumberAnimation {
            duration: Nexa.Theme.animationNormal
            easing.type: Nexa.Theme.easingDecelerate
        }
    }

    Behavior on opacity {
        NumberAnimation {
            duration: Nexa.Theme.animationNormal
            easing.type: Nexa.Theme.easingDecelerate
        }
    }

    // Top subtle specular rim highlight
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: root.height / 2
        anchors.rightMargin: root.height / 2
        height: 1
        color: Qt.rgba(1, 1, 1, 0.16)
    }

    // ============================================================
    // CONTENT LAYOUT: [ 4-Bar Matugen Equalizer ] [ Spectrum Wave ]
    // ============================================================

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 9
        anchors.rightMargin: 14
        spacing: 9

        // Vibrant 4-Bar Matugen Equalizer Badge (0% CPU Animation)
        Rectangle {
            id: anchorBadge
            Layout.preferredWidth: 24
            Layout.preferredHeight: 24
            Layout.alignment: Qt.AlignVCenter
            radius: 12
            color: Qt.rgba(Nexa.Theme.primary.r, Nexa.Theme.primary.g, Nexa.Theme.primary.b, 0.14)
            border.width: 1
            border.color: Qt.rgba(Nexa.Theme.primary.r, Nexa.Theme.primary.g, Nexa.Theme.primary.b, 0.40)

            scale: 1.0 + Math.min(0.18, root.bassEnergy * 0.25)

            // 4-Bar Animated Equalizer
            Row {
                anchors.centerIn: parent
                spacing: 2.2

                // Bar 1: Bass
                Rectangle {
                    width: 2.2
                    height: Math.max(4, Math.min(14, 5 + root.bassEnergy * 11))
                    radius: 1.1
                    color: Nexa.Theme.error
                    anchors.verticalCenter: parent.verticalCenter
                }

                // Bar 2: Low-Mid
                Rectangle {
                    width: 2.2
                    height: Math.max(4, Math.min(16, 6 + root.energy * 12))
                    radius: 1.1
                    color: Nexa.Theme.warning
                    anchors.verticalCenter: parent.verticalCenter
                }

                // Bar 3: Core Mids
                Rectangle {
                    width: 2.2
                    height: Math.max(4, Math.min(15, 6 + root.midEnergy * 11))
                    radius: 1.1
                    color: Nexa.Theme.primary
                    anchors.verticalCenter: parent.verticalCenter
                }

                // Bar 4: Treble
                Rectangle {
                    width: 2.2
                    height: Math.max(4, Math.min(13, 4 + root.trebleEnergy * 10))
                    radius: 1.1
                    color: Nexa.Theme.success
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        // High-Precision Hardware-Optimized Colorful Audio Wave Canvas
        Canvas {
            id: waveCanvas
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.alignment: Qt.AlignVCenter

            property real phase: 0.0

            Timer {
                id: renderTimer
                interval: 28 // ~36 FPS (Extremely smooth, minimal CPU footprint)
                running: root.isPlaying && root.visible
                repeat: true
                onTriggered: {
                    waveCanvas.phase += 0.055 + (root.energy * 0.08)
                    waveCanvas.requestPaint()
                }
            }

            onPaint: {
                const ctx = getContext("2d")
                const w = width
                const h = height
                const cy = h / 2

                ctx.clearRect(0, 0, w, h)

                if (!root.isPlaying || w <= 0 || h <= 0)
                    return

                const p = phase
                const bins = root.spectrumBins
                const binCount = bins.length
                const musicEnergy = root.energy

                // Extract all vibrant Matugen theme colors
                const cPink = Nexa.Theme.error
                const cAmber = Nexa.Theme.warning
                const cPrimary = Nexa.Theme.primary
                const cTertiary = Nexa.Theme.tertiary
                const cMint = Nexa.Theme.success

                // ----------------------------------------------------
                // 1. Horizontal Matugen Spectrum Gradients
                // ----------------------------------------------------
                const matugenGrad = ctx.createLinearGradient(0, 0, w, 0)
                matugenGrad.addColorStop(0.00, "transparent")
                matugenGrad.addColorStop(0.06, cPink)     // Bass: Rose / Coral
                matugenGrad.addColorStop(0.26, cAmber)    // Low Mids: Amber
                matugenGrad.addColorStop(0.50, cPrimary)  // Vocal Mids: Primary Cyan / Blue
                matugenGrad.addColorStop(0.76, cTertiary) // Highs: Periwinkle / Purple
                matugenGrad.addColorStop(0.94, cMint)     // Treble Sparkle: Mint Green
                matugenGrad.addColorStop(1.00, "transparent")

                // Complementary gradient for lower wave
                const lowerGrad = ctx.createLinearGradient(0, 0, w, 0)
                lowerGrad.addColorStop(0.00, "transparent")
                lowerGrad.addColorStop(0.06, cAmber)
                lowerGrad.addColorStop(0.28, cPink)
                lowerGrad.addColorStop(0.55, cTertiary)
                lowerGrad.addColorStop(0.80, cPrimary)
                lowerGrad.addColorStop(0.94, cMint)
                lowerGrad.addColorStop(1.00, "transparent")

                // Secondary internal wave gradients
                const pinkGrad = ctx.createLinearGradient(0, 0, w, 0)
                pinkGrad.addColorStop(0.00, "transparent")
                pinkGrad.addColorStop(0.08, cPink)
                pinkGrad.addColorStop(0.92, cPink)
                pinkGrad.addColorStop(1.00, "transparent")

                const mintGrad = ctx.createLinearGradient(0, 0, w, 0)
                mintGrad.addColorStop(0.00, "transparent")
                mintGrad.addColorStop(0.08, cMint)
                mintGrad.addColorStop(0.92, cMint)
                mintGrad.addColorStop(1.00, "transparent")

                // Maximum vertical wave excursion
                const maxAmp = (h * 0.48)

                // Fast cosine interpolation
                function getBinEnergy(normX) {
                    if (binCount === 0) return musicEnergy
                    const u = normX * (binCount - 1)
                    const idx = Math.floor(u)
                    const nextIdx = Math.min(binCount - 1, idx + 1)
                    const frac = u - idx
                    const smoothFrac = (1.0 - Math.cos(frac * Math.PI)) * 0.5
                    const b1 = bins[idx] || 0.0
                    const b2 = bins[nextIdx] || 0.0
                    return (b1 * (1.0 - smoothFrac)) + (b2 * smoothFrac)
                }

                // Envelope function: sin(pi * t)^1.28
                function envelope(normX) {
                    return Math.pow(Math.sin(Math.PI * normX), 1.28)
                }

                // ----------------------------------------------------
                // 2. Pre-calculate Multi-Layer Wave Curves (step 4 = fast hardware path)
                // ----------------------------------------------------
                const step = 4
                const upperPoints = []
                const lowerPoints = []
                const harmonicPoints = []
                const treblePoints = []
                const peakSparkles = []

                for (let x = 0; x <= w; x += step) {
                    const normX = x / w
                    const env = envelope(normX)
                    const freqE = getBinEnergy(normX)

                    const dynamicEnergy = freqE * 1.40 + musicEnergy * 0.35
                    const clampedEnergy = Math.min(1.35, Math.max(0.14, dynamicEnergy))

                    // Upper boundary
                    const oscUp = Math.sin(normX * 8.5 + p) * 0.28 + Math.cos(normX * 13.5 - p * 0.7) * 0.20
                    const deltaUp = env * maxAmp * (clampedEnergy * 0.90 + oscUp * 0.32)
                    const yUp = cy - deltaUp
                    upperPoints.push({ x: x, y: yUp })

                    // Lower boundary
                    const oscDn = Math.cos(normX * 7.5 - p * 0.9) * 0.28 + Math.sin(normX * 12.0 + p * 0.6) * 0.20
                    const deltaDn = env * maxAmp * (clampedEnergy * 0.90 + oscDn * 0.32)
                    const yDn = cy + deltaDn
                    lowerPoints.push({ x: x, y: yDn })

                    // Harmonic wave
                    const oscHarm = Math.sin(normX * 10.5 - p * 1.3) * 0.35
                    const deltaHarm = env * maxAmp * (clampedEnergy * 0.68 + oscHarm * 0.30)
                    harmonicPoints.push({ x: x, y: cy - deltaHarm * 0.80 })

                    // Treble wave
                    const oscTreb = Math.cos(normX * 14.0 + p * 1.7) * 0.30
                    const deltaTreb = env * (maxAmp * 0.45) * clampedEnergy * oscTreb
                    treblePoints.push({ x: x, y: cy + deltaTreb })

                    // Peak sparkles
                    if (freqE > 0.60 && env > 0.35 && (x % 15 === 0)) {
                        peakSparkles.push({ x: x, y: yUp - 1 })
                    }
                }

                // ----------------------------------------------------
                // 3. Volumetric Translucent Fluid Fill
                // ----------------------------------------------------
                ctx.save()
                ctx.beginPath()
                ctx.moveTo(upperPoints[0].x, upperPoints[0].y)
                for (let i = 1; i < upperPoints.length; ++i) {
                    ctx.lineTo(upperPoints[i].x, upperPoints[i].y)
                }
                for (let j = lowerPoints.length - 1; j >= 0; --j) {
                    ctx.lineTo(lowerPoints[j].x, lowerPoints[j].y)
                }
                ctx.closePath()

                ctx.fillStyle = matugenGrad
                ctx.globalAlpha = 0.26 + Math.min(0.28, musicEnergy * 0.35)
                ctx.fill()
                ctx.restore()

                // ----------------------------------------------------
                // 4. Amber/Rose Harmonic Wave (Layer 1) - Hardware Stroke
                // ----------------------------------------------------
                ctx.save()
                ctx.beginPath()
                ctx.strokeStyle = pinkGrad
                ctx.lineWidth = 1.4
                ctx.lineCap = "round"
                ctx.lineJoin = "round"
                ctx.globalAlpha = 0.75 + Math.min(0.20, root.bassEnergy * 0.25)

                ctx.moveTo(harmonicPoints[0].x, harmonicPoints[0].y)
                for (let hIdx = 1; hIdx < harmonicPoints.length; ++hIdx) {
                    ctx.lineTo(harmonicPoints[hIdx].x, harmonicPoints[hIdx].y)
                }
                ctx.stroke()
                ctx.restore()

                // ----------------------------------------------------
                // 5. Mint/Treble Core Wave (Layer 2) - Hardware Stroke
                // ----------------------------------------------------
                ctx.save()
                ctx.beginPath()
                ctx.strokeStyle = mintGrad
                ctx.lineWidth = 1.2
                ctx.lineCap = "round"
                ctx.lineJoin = "round"
                ctx.globalAlpha = 0.75 + Math.min(0.20, root.trebleEnergy * 0.25)

                ctx.moveTo(treblePoints[0].x, treblePoints[0].y)
                for (let tIdx = 1; tIdx < treblePoints.length; ++tIdx) {
                    ctx.lineTo(treblePoints[tIdx].x, treblePoints[tIdx].y)
                }
                ctx.stroke()
                ctx.restore()

                // ----------------------------------------------------
                // 6. Glowing Upper Ridge Line (Hardware Dual-Pass Glow, 0% CPU Blur)
                // ----------------------------------------------------
                // Pass A: Soft glow understroke
                ctx.save()
                ctx.beginPath()
                ctx.strokeStyle = matugenGrad
                ctx.lineWidth = 4.2
                ctx.lineCap = "round"
                ctx.lineJoin = "round"
                ctx.globalAlpha = 0.25 + Math.min(0.25, root.bassEnergy * 0.30)
                ctx.moveTo(upperPoints[0].x, upperPoints[0].y)
                for (let i = 1; i < upperPoints.length; ++i) {
                    ctx.lineTo(upperPoints[i].x, upperPoints[i].y)
                }
                ctx.stroke()

                // Pass B: Crisp core ridge line
                ctx.lineWidth = 2.0
                ctx.globalAlpha = 0.98
                ctx.stroke()
                ctx.restore()

                // ----------------------------------------------------
                // 7. Glowing Lower Ridge Line (Hardware Dual-Pass Glow, 0% CPU Blur)
                // ----------------------------------------------------
                ctx.save()
                ctx.beginPath()
                ctx.strokeStyle = lowerGrad
                ctx.lineWidth = 3.6
                ctx.lineCap = "round"
                ctx.lineJoin = "round"
                ctx.globalAlpha = 0.22 + Math.min(0.22, root.midEnergy * 0.25)
                ctx.moveTo(lowerPoints[0].x, lowerPoints[0].y)
                for (let j = 1; j < lowerPoints.length; ++j) {
                    ctx.lineTo(lowerPoints[j].x, lowerPoints[j].y)
                }
                ctx.stroke()

                // Pass B: Crisp core ridge line
                ctx.lineWidth = 1.7
                ctx.globalAlpha = 0.92
                ctx.stroke()
                ctx.restore()

                // ----------------------------------------------------
                // 8. Peak Sparkle Micro-Beacons
                // ----------------------------------------------------
                if (peakSparkles.length > 0) {
                    ctx.save()
                    ctx.fillStyle = "#FFFFFF"
                    ctx.globalAlpha = 0.92
                    for (let s = 0; s < peakSparkles.length; ++s) {
                        ctx.beginPath()
                        ctx.arc(peakSparkles[s].x, peakSparkles[s].y, 1.5, 0, Math.PI * 2)
                        ctx.fill()
                    }
                    ctx.restore()
                }
            }
        }
    }

    // ============================================================
    // INTERACTION: CLICK TO OPEN ISLAND, SCROLL FOR SINK VOLUME
    // ============================================================

    MouseArea {
        id: pillMouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onClicked: {
            Quickshell.execDetached([
                "quickshell",
                "-p",
                Quickshell.env("HOME") + "/.config/nexa/quickshell",
                "ipc",
                "call",
                "nexaIsland",
                "openFullSection",
                "music"
            ])
        }

        onWheel: wheel => {
            if (wheel.angleDelta.y > 0) {
                Quickshell.execDetached(["wpctl", "set-volume", "-l", "1.0", "@DEFAULT_AUDIO_SINK@", "2%+"])
            } else if (wheel.angleDelta.y < 0) {
                Quickshell.execDetached(["wpctl", "set-volume", "-l", "1.0", "@DEFAULT_AUDIO_SINK@", "2%-"])
            }
        }
    }
}
