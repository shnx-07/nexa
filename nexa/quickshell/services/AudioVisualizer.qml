pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "." as Services

Singleton {
    id: root

    readonly property string nexadBin:
        Quickshell.env("HOME") + "/.config/nexa/rust/target/release/nexad"

    // -------------------------------------------------------------
    // Categorized Reactive Properties (Provided by Rust Engine)
    // -------------------------------------------------------------

    // Category 1: Dynamics & Transients (for Island, Glow, Ambient effects)
    property real energy: 0.0
    property real bass: 0.0
    property real mid: 0.0
    property real treble: 0.0
    property bool isBeat: false

    // Category 2: Waveform / Rail (for Top Bar Horizon Rail & Simple Line)
    property real waveAmplitude: 0.0
    property real speedMultiplier: 1.0
    property var waveProfile: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]

    // Category 3: Equalizer / Spectrum Bars (for Media Player, Widgets, Shaders)
    property var bars: [
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0
    ]

    // Signal emitted on every audio frame tick
    signal frameTick()

    // Active state: stream runs continuously with 0% CPU idle management handled in visualizer.rs
    property bool activeRequest: false
    readonly property bool isMediaPlaying: Services.Media.isPlaying || activeRequest

    property bool shouldRun: true

    Process {
        id: streamProcess
        command: [root.nexadBin, "visualizer", "stream"]
        running: true

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                const str = data.trim();
                if (!str) return;
                try {
                    const frame = JSON.parse(str);
                    root.energy = frame.energy !== undefined ? Number(frame.energy) : 0.0;
                    root.bass = frame.bass !== undefined ? Number(frame.bass) : 0.0;
                    root.mid = frame.mid !== undefined ? Number(frame.mid) : 0.0;
                    root.treble = frame.treble !== undefined ? Number(frame.treble) : 0.0;
                    root.isBeat = !!frame.is_beat;
                    root.waveAmplitude = frame.amp !== undefined ? Number(frame.amp) : 0.0;
                    root.speedMultiplier = frame.speed !== undefined ? Number(frame.speed) : 1.0;
                    if (frame.bars && Array.isArray(frame.bars)) {
                        root.bars = frame.bars;
                    }
                    if (frame.wave_profile && Array.isArray(frame.wave_profile)) {
                        root.waveProfile = frame.wave_profile;
                    }
                    root.frameTick();
                } catch (_) {}
            }
        }
    }
}
