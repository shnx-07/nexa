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
    // CAVA AUDIO REACTIVITY
    // ============================================================

    property var spectrumBins: []
    property real energy: 0.15
    property real bassEnergy: 0.15
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
                let trebleSum = 0
                for (let i = 0; i < parts.length; ++i) {
                    if (parts[i] === "") continue
                    const raw = Number(parts[i])
                    if (isNaN(raw)) continue
                    const val = Math.max(0.0, Math.min(1.0, (raw / 1000.0) * 1.15))
                    values.push(val)
                    sum += val
                    if (i < 16) bassSum += val
                    else if (i > 36) trebleSum += val
                }
                if (values.length > 0) {
                    root.spectrumBins = values
                    root.energy = Math.max(0.12, sum / values.length)
                    root.bassEnergy = Math.max(0.12, bassSum / Math.min(16, values.length))
                    root.trebleEnergy = Math.max(0.12, trebleSum / Math.max(1, values.length - 37))
                }
            }
        }

        onRunningChanged: {
            if (!running) {
                root.spectrumBins = []
                root.energy = 0.15
                root.bassEnergy = 0.15
                root.trebleEnergy = 0.15
            }
        }
    }

    // ============================================================
    // DIMENSIONS & STYLING (180PX LENGTH)
    // ============================================================

    implicitHeight: Nexa.Theme.controlHeightSm
    implicitWidth: isPlaying ? 180 : 0
    opacity: isPlaying ? 1.0 : 0.0
    visible: opacity > 0.01
    clip: true

    radius: height / 2
    color: Nexa.Theme.surfaceContainer

    border {
        width: Nexa.Theme.borderThin
        color: Qt.rgba(
            Nexa.Theme.primary.r,
            Nexa.Theme.primary.g,
            Nexa.Theme.primary.b,
            0.15 + Math.min(0.55, root.bassEnergy * 0.65)
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

    // ============================================================
    // CONTENT
    // ============================================================

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Nexa.Theme.spacingMd
        anchors.rightMargin: Nexa.Theme.spacingMd
        spacing: 10

        // Leading music note icon that subtly pulses to the bass beat
        Text {
            text: "󰎆"
            color: Nexa.Theme.primary
            font.family: Nexa.Theme.iconFontFamily
            font.pixelSize: 13
            scale: 1.0 + Math.min(0.25, root.bassEnergy * 0.32)
            Layout.alignment: Qt.AlignVCenter

            Behavior on scale {
                NumberAnimation { duration: 60 }
            }
        }

        // Live Audio-Reactive Waveform Canvas
        Canvas {
            id: waveCanvas

            Layout.fillWidth: true
            Layout.preferredHeight: 24
            Layout.alignment: Qt.AlignVCenter

            property real phase: 0.0

            Timer {
                id: animTimer
                interval: 16 // ~60fps
                running: root.isPlaying && root.visible
                repeat: true
                onTriggered: {
                    // Speed dynamically reacts to music energy
                    waveCanvas.phase += 0.05 + (root.energy * 0.08)
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
                const primaryColor = Nexa.Theme.primary
                const secondaryColor = Nexa.Theme.secondary
                const tertiaryColor = Nexa.Theme.tertiary
                const bins = root.spectrumBins
                const binCount = bins.length
                const musicEnergy = root.energy

                // 0. Audio-Reactive Ambient Aura Spotlight
                ctx.save()
                const auraRadius = (w * 0.45) * (0.8 + musicEnergy * 0.7)
                const auraGrad = ctx.createRadialGradient(w / 2, cy, 2, w / 2, cy, auraRadius)
                auraGrad.addColorStop(0, primaryColor)
                auraGrad.addColorStop(0.5, secondaryColor)
                auraGrad.addColorStop(1, "transparent")
                ctx.fillStyle = auraGrad
                ctx.globalAlpha = 0.08 + Math.min(0.24, musicEnergy * 0.35)
                ctx.fillRect(0, 0, w, h)
                ctx.restore()

                // 1. Subtle Center Horizon Line
                ctx.save()
                ctx.beginPath()
                ctx.strokeStyle = Nexa.Theme.outline
                ctx.lineWidth = 1
                ctx.globalAlpha = 0.15
                ctx.moveTo(0, cy)
                ctx.lineTo(w, cy)
                ctx.stroke()
                ctx.restore()

                // Helper to compute wave Y coordinate
                function getWaveY(x, amplitude, frequency, phaseOffset, energyMultiplier) {
                    const t = x / w
                    const envelope = Math.sin(Math.PI * t)

                    let binVal = 0.0
                    if (binCount > 0) {
                        const idx = Math.min(binCount - 1, Math.floor(t * binCount))
                        binVal = bins[idx] || 0.0
                    }

                    const dynamicAmp = amplitude * (0.35 + binVal * 1.5 * energyMultiplier + musicEnergy * 0.4)
                    return cy + envelope * dynamicAmp * Math.sin(x * frequency + p + phaseOffset)
                }

                // 2. Translucent Ambient Volume Fill under Primary Wave
                ctx.save()
                ctx.beginPath()
                ctx.moveTo(0, cy)
                const step = 2
                for (let x = 0; x <= w; x += step) {
                    const y = getWaveY(x, 7.5, 0.07, 0.0, 1.35)
                    ctx.lineTo(x, y)
                }
                ctx.lineTo(w, cy)
                ctx.closePath()

                const grad = ctx.createLinearGradient(0, cy - 8, 0, cy + 8)
                grad.addColorStop(0, primaryColor)
                grad.addColorStop(0.5, secondaryColor)
                grad.addColorStop(1, primaryColor)
                ctx.fillStyle = grad
                ctx.globalAlpha = 0.12 + Math.min(0.24, musicEnergy * 0.32)
                ctx.fill()
                ctx.restore()

                // 3. Draw Wave Lines
                function drawWave(color, lineWidth, amplitude, frequency, phaseOffset, alpha, energyMultiplier, withGlow) {
                    ctx.save()
                    ctx.beginPath()
                    ctx.strokeStyle = color
                    ctx.lineWidth = lineWidth
                    ctx.globalAlpha = alpha
                    ctx.lineCap = "round"
                    ctx.lineJoin = "round"

                    if (withGlow) {
                        ctx.shadowColor = color
                        ctx.shadowBlur = 4 + Math.min(10, root.bassEnergy * 12)
                    }

                    let first = true
                    for (let x = 0; x <= w; x += step) {
                        const y = getWaveY(x, amplitude, frequency, phaseOffset, energyMultiplier)
                        if (first) {
                            ctx.moveTo(x, y)
                            first = false
                        } else {
                            ctx.lineTo(x, y)
                        }
                    }

                    ctx.stroke()
                    ctx.restore()
                }

                // Wave 1: Background harmonic tertiary wave (soft cyan / amber)
                drawWave(tertiaryColor, 1.2, 5.0, 0.055, Math.PI * 0.8, 0.5, 0.9, false)

                // Wave 2: Mid secondary wave (flowing lavender / teal)
                drawWave(secondaryColor, 1.4, 6.2, 0.065, Math.PI * 0.35, 0.65, 1.1, false)

                // Wave 3: Dominant Primary wave with soft luminous aura
                drawWave(primaryColor, 2.0, 7.8, 0.07, 0.0, 0.95, 1.35, true)
            }
        }
    }
}
