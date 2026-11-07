// pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../../NewNexaUI" as NexaUI
import "../../services" as Services

Item {
    id: root

    anchors.fill: parent

    signal requestClose()

    function rad(n) {
        if (NexaUI.NexaTokens.nexaRounding === 0) return 0;
        return Math.max(0, Math.round(n * (NexaUI.NexaTokens.nexaRounding / 10.0)));
    }

    readonly property string configPath:
        Quickshell.env("HOME") + "/.config/nexa/config/decorations/constellation_rail.json"
    readonly property string nexadBin:
        Quickshell.env("HOME") + "/.config/nexa/rust/target/release/nexad"

    // Configuration properties
    property bool railEnabled: true
    property string railStyle: "constellation" // "none", "simple_line", "constellation"
    property string railDirection: "left-to-right" // "left-to-right", "right-to-left"
    property real railSpeed: 1.0
    property real glowIntensity: 0.85
    property real lineOpacity: 0.35
    property int particleCount: 8

    // Preview interactive state
    property bool previewSimulateWave: false
    readonly property bool isActuallyPlaying: Services.Media.isPlaying
    readonly property bool previewWaving: previewSimulateWave || isActuallyPlaying

    // Feedback toast
    property string toastText: ""
    property bool toastVisible: false

    function showToast(msg) {
        toastText = msg;
        toastVisible = true;
        toastTimer.restart();
    }

    Timer {
        id: toastTimer
        interval: 2200
        repeat: false
        onTriggered: root.toastVisible = false
    }

    // Load & watch config
    function parseConfig(raw) {
        if (!raw || raw.trim() === "") return;
        try {
            const data = JSON.parse(raw);
            root.railEnabled = data.enabled !== undefined ? !!data.enabled : true;
            root.railStyle = data.style || "constellation";
            root.railDirection = data.direction || "left-to-right";
            root.railSpeed = data.speed !== undefined ? Number(data.speed) : 1.0;
            root.glowIntensity = data.glow_intensity !== undefined ? Number(data.glow_intensity) : 0.85;
            root.lineOpacity = data.line_opacity !== undefined ? Number(data.line_opacity) : 0.35;
            root.particleCount = data.particle_count !== undefined ? Number(data.particle_count) : 8;
        } catch (e) {
            console.warn("[DecorationsSettings] parse error:", e);
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

    // Save Process
    Process {
        id: saveProcess
        running: false
    }

    function saveSettings() {
        const cmd = [
            root.nexadBin,
            "decoration",
            "constellation",
            "set",
            "--enabled", root.railEnabled ? "true" : "false",
            "--style", root.railStyle,
            "--direction", root.railDirection,
            "--speed", root.railSpeed.toFixed(2),
            "--glow", root.glowIntensity.toFixed(2),
            "--opacity", root.lineOpacity.toFixed(2),
            "--count", String(root.particleCount)
        ];
        saveProcess.command = cmd;
        saveProcess.running = true;
    }

    // Debounced save for sliders
    Timer {
        id: debounceSaveTimer
        interval: 180
        repeat: false
        onTriggered: root.saveSettings()
    }

    function queueSave() {
        debounceSaveTimer.restart();
    }

    // Scrollable content
    Flickable {
        anchors.fill: parent
        anchors.margins: 18
        contentWidth: width
        contentHeight: contentCol.implicitHeight + 36
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        NexaUI.NexaSmoothScroll {}

        ColumnLayout {
            id: contentCol
            width: parent.width
            spacing: 20

            // ────────────────────────────────────────────────────────────
            // 1. HEADER
            // ────────────────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 14

                Rectangle {
                    width: 44
                    height: 44
                    radius: root.rad(22)
                    color: NexaUI.NexaColors.primaryContainer
                    border.width: NexaUI.NexaTokens.borderThin
                    border.color: NexaUI.NexaColors.border

                    Text {
                        anchors.centerIn: parent
                        text: ""
                        font.family: NexaUI.NexaTypography.familyIcon
                        font.pixelSize: 20
                        color: NexaUI.NexaColors.onPrimaryContainer
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        text: "Top Bar Visual Decorations"
                        font.family: NexaUI.NexaTypography.familyBody
                        font.pixelSize: 16
                        font.weight: Font.Bold
                        color: NexaUI.NexaColors.text
                    }

                    Text {
                        text: "Configure ambient horizon rails, star beads, parallax drift & audio wave undulation"
                        font.family: NexaUI.NexaTypography.familyBody
                        font.pixelSize: 12
                        color: NexaUI.NexaColors.mutedText
                    }
                }

                // Reset button
                Rectangle {
                    width: resetTxt.implicitWidth + 24
                    height: 34
                    radius: root.rad(8)
                    color: resetHover.containsMouse ? NexaUI.NexaColors.surfaceContainerHighest : NexaUI.NexaColors.surfaceContainerHigh
                    border.width: NexaUI.NexaTokens.borderThin
                    border.color: NexaUI.NexaColors.border

                    Text {
                        id: resetTxt
                        anchors.centerIn: parent
                        text: "Reset Defaults"
                        font.family: NexaUI.NexaTypography.familyBody
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        color: NexaUI.NexaColors.text
                    }

                    MouseArea {
                        id: resetHover
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: {
                            root.railEnabled = true;
                            root.railStyle = "constellation";
                            root.railDirection = "left-to-right";
                            root.railSpeed = 1.0;
                            root.glowIntensity = 0.85;
                            root.lineOpacity = 0.35;
                            root.particleCount = 8;
                            root.saveSettings();
                            root.showToast("Decoration settings reset to defaults");
                        }
                    }
                }
            }

            // ────────────────────────────────────────────────────────────
            // 2. LIVE INTERACTIVE PREVIEW CARD
            // ────────────────────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                height: 140
                radius: root.rad(14)
                color: NexaUI.NexaColors.surfaceContainer
                border.width: NexaUI.NexaTokens.borderThin
                border.color: NexaUI.NexaColors.border
                clip: true

                // Specular top highlight
                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: 1
                    color: NexaUI.NexaColors.borderStrong
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 10

                    // Preview Card Header
                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            text: "Live Bar Preview · " + (
                                root.railStyle === "none" ? "CLEAN BAR (NO DECORATION)" :
                                root.railStyle === "simple_line" ? "SIMPLE WAVE LINE" : "CONSTELLATION RAIL"
                            )
                            font.family: NexaUI.NexaTypography.familyBody
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            color: NexaUI.NexaColors.mutedText
                        }

                        Item { Layout.fillWidth: true }

                        // Music wave simulation button
                        Rectangle {
                            visible: root.railStyle !== "none"
                            width: waveSimTxt.implicitWidth + 20
                            height: 26
                            radius: root.rad(13)
                            color: root.previewWaving ? NexaUI.NexaColors.secondaryContainer : NexaUI.NexaColors.surfaceContainerHigh
                            border.width: NexaUI.NexaTokens.borderThin
                            border.color: root.previewWaving ? NexaUI.NexaColors.primary : NexaUI.NexaColors.border

                            Row {
                                anchors.centerIn: parent
                                spacing: 6

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: root.previewWaving ? "󰎈" : "󰐊"
                                    font.family: NexaUI.NexaTypography.familyIcon
                                    font.pixelSize: 11
                                    color: root.previewWaving ? NexaUI.NexaColors.onSecondaryContainer : NexaUI.NexaColors.text
                                }

                                Text {
                                    id: waveSimTxt
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: root.isActuallyPlaying ? "Live Music Active" : (root.previewSimulateWave ? "Simulating Music" : "Simulate Music Wave")
                                    font.family: NexaUI.NexaTypography.familyBody
                                    font.pixelSize: 10
                                    font.weight: Font.Medium
                                    color: root.previewWaving ? NexaUI.NexaColors.onSecondaryContainer : NexaUI.NexaColors.text
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (!root.isActuallyPlaying) {
                                        root.previewSimulateWave = !root.previewSimulateWave;
                                    }
                                }
                            }
                        }
                    }

                    // Mock Screen Bar Stage
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: root.rad(8)
                        color: "#0c0d12"
                        border.width: NexaUI.NexaTokens.borderThin
                        border.color: NexaUI.NexaColors.border
                        clip: true

                        // Island Mock Pill
                        Rectangle {
                            id: previewIsland
                            anchors.centerIn: parent
                            width: root.previewWaving ? 220 : 120
                            height: 28
                            radius: root.rad(14)
                            color: "#181920"
                            border.width: 1
                            border.color: NexaUI.NexaColors.border
                            z: 10

                            Behavior on width {
                                NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
                            }

                            Row {
                                anchors.centerIn: parent
                                spacing: 6

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: root.previewWaving ? "󰎈" : "󱑂"
                                    font.family: NexaUI.NexaTypography.familyIcon
                                    font.pixelSize: 12
                                    color: NexaUI.NexaColors.primary
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: root.previewWaving ? "Playing Audio..." : "11:00 PM"
                                    font.family: NexaUI.NexaTypography.familyBody
                                    font.pixelSize: 11
                                    font.weight: Font.Medium
                                    color: NexaUI.NexaColors.text
                                }
                            }
                        }

                        // Preview Rail Left & Right
                        Item {
                            anchors.fill: parent
                            visible: root.railEnabled && root.railStyle !== "none"

                            property real waveAmp: root.previewWaving ? 4.5 : 0.0
                            Behavior on waveAmp { NumberAnimation { duration: 350 } }

                            property real prevPhaseFast: 0.0
                            NumberAnimation on prevPhaseFast {
                                from: 0.0; to: 1.0
                                duration: Math.max(1500, 7000 / Math.max(0.1, root.railSpeed))
                                loops: Animation.Infinite
                                running: root.railStyle === "constellation"
                            }

                            property real prevPhaseSlow: 0.0
                            NumberAnimation on prevPhaseSlow {
                                from: 0.0; to: 1.0
                                duration: Math.max(3000, 14000 / Math.max(0.1, root.railSpeed))
                                loops: Animation.Infinite
                                running: root.railStyle === "constellation"
                            }

                            property real waveRipple: 0.0
                            NumberAnimation on waveRipple {
                                from: 0.0; to: 6.2831853
                                duration: 1800
                                loops: Animation.Infinite
                                running: root.previewWaving
                            }

                            // Wave Canvas
                            Canvas {
                                id: prevCanvas
                                anchors.fill: parent
                                property real amp: parent.waveAmp
                                property real phase: parent.waveRipple
                                property real op: root.lineOpacity
                                property color col: NexaUI.NexaColors.primary
                                property real gapHalf: (previewIsland.width / 2) + 12

                                onAmpChanged: requestPaint()
                                onPhaseChanged: if (amp > 0.01) requestPaint()
                                onOpChanged: requestPaint()
                                onColChanged: requestPaint()
                                onGapHalfChanged: requestPaint()

                                onPaint: {
                                    const ctx = getContext("2d");
                                    ctx.clearRect(0, 0, width, height);

                                    ctx.strokeStyle = Qt.rgba(col.r, col.g, col.b, op);
                                    ctx.lineWidth = 1.5;
                                    ctx.lineCap = "round";

                                    const midY = height / 2;
                                    const midX = width / 2;
                                    const leftEnd = midX - gapHalf;
                                    const rightStart = midX + gapHalf;

                                    // Left wing
                                    ctx.beginPath();
                                    ctx.moveTo(30, midY);
                                    if (amp <= 0.05) {
                                        ctx.lineTo(leftEnd, midY);
                                    } else {
                                        const steps = 30;
                                        const dx = (leftEnd - 30) / steps;
                                        for (let i = 0; i <= steps; i++) {
                                            const px = 30 + i * dx;
                                            const py = midY + Math.sin(px * 0.04 + phase) * amp;
                                            ctx.lineTo(px, py);
                                        }
                                    }
                                    ctx.stroke();

                                    // Right wing
                                    ctx.beginPath();
                                    ctx.moveTo(rightStart, midY);
                                    if (amp <= 0.05) {
                                        ctx.lineTo(width - 30, midY);
                                    } else {
                                        const steps = 30;
                                        const dx = (width - 30 - rightStart) / steps;
                                        for (let i = 0; i <= steps; i++) {
                                            const px = rightStart + i * dx;
                                            const py = midY + Math.sin(px * 0.04 + phase + 1.5) * amp;
                                            ctx.lineTo(px, py);
                                        }
                                    }
                                    ctx.stroke();
                                }
                            }

                            // Constellation Beads in Preview (Left wing beads)
                            Repeater {
                                model: root.railStyle === "constellation" ? 2 : 0
                                Item {
                                    width: 16; height: 16
                                    readonly property real p: {
                                        const b = index * 0.5;
                                        return root.railDirection === "right-to-left"
                                            ? (1.0 - parent.prevPhaseFast + b) % 1.0
                                            : (parent.prevPhaseFast + b) % 1.0;
                                    }
                                    x: 35 + p * Math.max(1, (parent.width / 2 - previewIsland.width / 2 - 50))
                                    y: (parent.height / 2 - 8) + (parent.waveAmp > 0.01 ? Math.sin(x * 0.04 + parent.waveRipple) * parent.waveAmp : 0)

                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 12; height: 12; radius: 6
                                        color: Qt.rgba(NexaUI.NexaColors.primary.r, NexaUI.NexaColors.primary.g, NexaUI.NexaColors.primary.b, 0.25 * root.glowIntensity)
                                    }
                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 3.5; height: 3.5; radius: 1.75
                                        color: NexaUI.NexaColors.text
                                    }
                                }
                            }

                            // Slow beads in preview (Right wing beads)
                            Repeater {
                                model: root.railStyle === "constellation" ? 2 : 0
                                Item {
                                    width: 20; height: 20
                                    readonly property real p: {
                                        const b = index * 0.5 + 0.25;
                                        return root.railDirection === "right-to-left"
                                            ? (1.0 - parent.prevPhaseSlow + b) % 1.0
                                            : (parent.prevPhaseSlow + b) % 1.0;
                                    }
                                    x: (parent.width / 2 + previewIsland.width / 2 + 15) + p * Math.max(1, (parent.width / 2 - previewIsland.width / 2 - 50))
                                    y: (parent.height / 2 - 10) + (parent.waveAmp > 0.01 ? Math.sin(x * 0.04 + parent.waveRipple + 1.5) * parent.waveAmp : 0)

                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 16; height: 16; radius: 8
                                        color: Qt.rgba(NexaUI.NexaColors.primary.r, NexaUI.NexaColors.primary.g, NexaUI.NexaColors.primary.b, 0.45 * root.glowIntensity)
                                    }
                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 4.5; height: 4.5; radius: 2.25
                                        color: NexaUI.NexaColors.text
                                    }
                                }
                            }
                        }

                        // Label when none
                        Text {
                            visible: !root.railEnabled || root.railStyle === "none"
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 8
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "No decoration active · Clean stock top bar"
                            font.family: NexaUI.NexaTypography.familyBody
                            font.pixelSize: 11
                            color: NexaUI.NexaColors.mutedText
                        }
                    }
                }
            }

            // ────────────────────────────────────────────────────────────
            // 3. STYLE SELECTION: 3 PRESETS
            // ────────────────────────────────────────────────────────────
            Text {
                text: "DECORATION STYLE"
                font.family: NexaUI.NexaTypography.familyBody
                font.pixelSize: 11
                font.weight: Font.DemiBold
                font.letterSpacing: 1.0
                color: NexaUI.NexaColors.mutedText
                Layout.topMargin: 4
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 14

                // Option 1: None / Clean
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    height: 100
                    radius: root.rad(12)
                    color: root.railStyle === "none"
                        ? NexaUI.NexaColors.primaryContainer
                        : (noneCardMouse.containsMouse ? NexaUI.NexaColors.surfaceContainerHigh : NexaUI.NexaColors.surfaceContainer)
                    border.width: root.railStyle === "none" ? 1.5 : NexaUI.NexaTokens.borderThin
                    border.color: root.railStyle === "none" ? NexaUI.NexaColors.primary : NexaUI.NexaColors.border

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 6

                        RowLayout {
                            spacing: 10
                            Text {
                                text: "󰅖"
                                font.family: NexaUI.NexaTypography.familyIcon
                                font.pixelSize: 18
                                color: root.railStyle === "none" ? NexaUI.NexaColors.primary : NexaUI.NexaColors.text
                            }
                            Text {
                                text: "None (Clean)"
                                font.family: NexaUI.NexaTypography.familyBody
                                font.pixelSize: 14
                                font.weight: Font.Bold
                                color: root.railStyle === "none" ? NexaUI.NexaColors.primary : NexaUI.NexaColors.text
                            }
                            Item { Layout.fillWidth: true }
                            Rectangle {
                                width: 14; height: 14; radius: 7
                                color: root.railStyle === "none" ? NexaUI.NexaColors.primary : "transparent"
                                border.width: 1.5
                                border.color: root.railStyle === "none" ? NexaUI.NexaColors.primary : NexaUI.NexaColors.outline
                            }
                        }

                        Text {
                            text: "Clean stock top bar without extra lines or particles. Pure minimalism."
                            font.family: NexaUI.NexaTypography.familyBody
                            font.pixelSize: 11
                            color: NexaUI.NexaColors.mutedText
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                    }

                    MouseArea {
                        id: noneCardMouse
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: {
                            root.railStyle = "none";
                            root.saveSettings();
                            root.showToast("Top bar decoration disabled");
                        }
                    }
                }

                // Option 2: Simple Line
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    height: 100
                    radius: root.rad(12)
                    color: root.railStyle === "simple_line"
                        ? NexaUI.NexaColors.primaryContainer
                        : (simpleCardMouse.containsMouse ? NexaUI.NexaColors.surfaceContainerHigh : NexaUI.NexaColors.surfaceContainer)
                    border.width: root.railStyle === "simple_line" ? 1.5 : NexaUI.NexaTokens.borderThin
                    border.color: root.railStyle === "simple_line" ? NexaUI.NexaColors.primary : NexaUI.NexaColors.border

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 6

                        RowLayout {
                            spacing: 10
                            Text {
                                text: "󰈺"
                                font.family: NexaUI.NexaTypography.familyIcon
                                font.pixelSize: 20
                                color: root.railStyle === "simple_line" ? NexaUI.NexaColors.primary : NexaUI.NexaColors.text
                            }
                            Text {
                                text: "Simple Wave Line"
                                font.family: NexaUI.NexaTypography.familyBody
                                font.pixelSize: 14
                                font.weight: Font.Bold
                                color: root.railStyle === "simple_line" ? NexaUI.NexaColors.primary : NexaUI.NexaColors.text
                            }
                            Item { Layout.fillWidth: true }
                            Rectangle {
                                width: 14; height: 14; radius: 7
                                color: root.railStyle === "simple_line" ? NexaUI.NexaColors.primary : "transparent"
                                border.width: 1.5
                                border.color: root.railStyle === "simple_line" ? NexaUI.NexaColors.primary : NexaUI.NexaColors.outline
                            }
                        }

                        Text {
                            text: "Sleek continuous rail without beads. Dynamically undulates into soundwaves on music playback."
                            font.family: NexaUI.NexaTypography.familyBody
                            font.pixelSize: 11
                            color: NexaUI.NexaColors.mutedText
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                    }

                    MouseArea {
                        id: simpleCardMouse
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: {
                            root.railStyle = "simple_line";
                            root.saveSettings();
                            root.showToast("Simple Wave Line enabled");
                        }
                    }
                }

                // Option 3: Constellation Rail
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    height: 100
                    radius: root.rad(12)
                    color: root.railStyle === "constellation"
                        ? NexaUI.NexaColors.primaryContainer
                        : (constellCardMouse.containsMouse ? NexaUI.NexaColors.surfaceContainerHigh : NexaUI.NexaColors.surfaceContainer)
                    border.width: root.railStyle === "constellation" ? 1.5 : NexaUI.NexaTokens.borderThin
                    border.color: root.railStyle === "constellation" ? NexaUI.NexaColors.primary : NexaUI.NexaColors.border

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 6

                        RowLayout {
                            spacing: 10
                            Text {
                                text: ""
                                font.family: NexaUI.NexaTypography.familyIcon
                                font.pixelSize: 18
                                color: root.railStyle === "constellation" ? NexaUI.NexaColors.primary : NexaUI.NexaColors.text
                            }
                            Text {
                                text: "Constellation Rail"
                                font.family: NexaUI.NexaTypography.familyBody
                                font.pixelSize: 14
                                font.weight: Font.Bold
                                color: root.railStyle === "constellation" ? NexaUI.NexaColors.primary : NexaUI.NexaColors.text
                            }
                            Item { Layout.fillWidth: true }
                            Rectangle {
                                width: 14; height: 14; radius: 7
                                color: root.railStyle === "constellation" ? NexaUI.NexaColors.primary : "transparent"
                                border.width: 1.5
                                border.color: root.railStyle === "constellation" ? NexaUI.NexaColors.primary : NexaUI.NexaColors.outline
                            }
                        }

                        Text {
                            text: "Dual-speed drifting beads with luminous flares riding dynamic audio waves along the rail."
                            font.family: NexaUI.NexaTypography.familyBody
                            font.pixelSize: 11
                            color: NexaUI.NexaColors.mutedText
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                    }

                    MouseArea {
                        id: constellCardMouse
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: {
                            root.railStyle = "constellation";
                            root.saveSettings();
                            root.showToast("Constellation Rail enabled");
                        }
                    }
                }
            }

            // ────────────────────────────────────────────────────────────
            // 4. CUSTOMIZATION PARAMETERS (Shown when line/constellation active)
            // ────────────────────────────────────────────────────────────
            Text {
                text: "ANIMATION & GEOMETRY TUNING"
                font.family: NexaUI.NexaTypography.familyBody
                font.pixelSize: 11
                font.weight: Font.DemiBold
                font.letterSpacing: 1.0
                color: NexaUI.NexaColors.mutedText
                Layout.topMargin: 8
            }

            Rectangle {
                Layout.fillWidth: true
                radius: root.rad(14)
                color: NexaUI.NexaColors.surfaceContainer
                border.width: NexaUI.NexaTokens.borderThin
                border.color: NexaUI.NexaColors.border
                implicitHeight: paramsCol.implicitHeight + 32

                ColumnLayout {
                    id: paramsCol
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 16

                    // Direction Row (Only for constellation beads)
                    RowLayout {
                        Layout.fillWidth: true
                        visible: root.railStyle === "constellation"

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                text: "Bead Drift Direction"
                                font.family: NexaUI.NexaTypography.familyBody
                                font.pixelSize: 13
                                font.weight: Font.Medium
                                color: NexaUI.NexaColors.text
                            }
                            Text {
                                text: "Horizontal direction of drifting constellation particles along the rail"
                                font.family: NexaUI.NexaTypography.familyBody
                                font.pixelSize: 11
                                color: NexaUI.NexaColors.mutedText
                            }
                        }

                        // Segmented control for direction
                        Rectangle {
                            width: 220; height: 34
                            radius: root.rad(17)
                            color: NexaUI.NexaColors.surfaceContainerHigh
                            border.width: NexaUI.NexaTokens.borderThin
                            border.color: NexaUI.NexaColors.border

                            Row {
                                anchors.fill: parent
                                anchors.margins: 3
                                spacing: 4

                                // Left to right pill
                                Rectangle {
                                    width: (parent.width - 4) / 2
                                    height: parent.height
                                    radius: root.rad(14)
                                    color: root.railDirection === "left-to-right" ? NexaUI.NexaColors.primary : "transparent"

                                    Row {
                                        anchors.centerIn: parent
                                        spacing: 6
                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "→"
                                            font.pixelSize: 13
                                            font.weight: Font.Bold
                                            color: root.railDirection === "left-to-right" ? NexaUI.NexaColors.onPrimary : NexaUI.NexaColors.text
                                        }
                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "Left to Right"
                                            font.family: NexaUI.NexaTypography.familyBody
                                            font.pixelSize: 11
                                            font.weight: Font.Medium
                                            color: root.railDirection === "left-to-right" ? NexaUI.NexaColors.onPrimary : NexaUI.NexaColors.text
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.railDirection = "left-to-right";
                                            root.saveSettings();
                                        }
                                    }
                                }

                                // Right to left pill
                                Rectangle {
                                    width: (parent.width - 4) / 2
                                    height: parent.height
                                    radius: root.rad(14)
                                    color: root.railDirection === "right-to-left" ? NexaUI.NexaColors.primary : "transparent"

                                    Row {
                                        anchors.centerIn: parent
                                        spacing: 6
                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "←"
                                            font.pixelSize: 13
                                            font.weight: Font.Bold
                                            color: root.railDirection === "right-to-left" ? NexaUI.NexaColors.onPrimary : NexaUI.NexaColors.text
                                        }
                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "Right to Left"
                                            font.family: NexaUI.NexaTypography.familyBody
                                            font.pixelSize: 11
                                            font.weight: Font.Medium
                                            color: root.railDirection === "right-to-left" ? NexaUI.NexaColors.onPrimary : NexaUI.NexaColors.text
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.railDirection = "right-to-left";
                                            root.saveSettings();
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Divider
                    Rectangle {
                        Layout.fillWidth: true; height: 1
                        color: NexaUI.NexaColors.border; opacity: 0.5
                        visible: root.railStyle === "constellation"
                    }

                    // Drift Speed Slider (Constellation)
                    RowLayout {
                        Layout.fillWidth: true
                        visible: root.railStyle === "constellation"

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                text: "Animation Drift Speed"
                                font.family: NexaUI.NexaTypography.familyBody
                                font.pixelSize: 13
                                font.weight: Font.Medium
                                color: NexaUI.NexaColors.text
                            }
                            Text {
                                text: "Controls baseline velocity of slow and fast particle layers (" + root.railSpeed.toFixed(1) + "x)"
                                font.family: NexaUI.NexaTypography.familyBody
                                font.pixelSize: 11
                                color: NexaUI.NexaColors.mutedText
                            }
                        }

                        NexaUI.NexaSlider {
                            Layout.preferredWidth: 220
                            from: 0.5
                            to: 2.5
                            stepSize: 0.1
                            value: root.railSpeed
                            showValue: true
                            valueSuffix: "x"
                            valueDecimals: 1
                            onMoved: v => {
                                root.railSpeed = v;
                                root.queueSave();
                            }
                        }
                    }

                    // Divider
                    Rectangle {
                        Layout.fillWidth: true; height: 1
                        color: NexaUI.NexaColors.border; opacity: 0.5
                        visible: root.railStyle === "constellation"
                    }

                    // Glow Intensity Slider (Constellation)
                    RowLayout {
                        Layout.fillWidth: true
                        visible: root.railStyle === "constellation"

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                text: "Bead Glow Intensity"
                                font.family: NexaUI.NexaTypography.familyBody
                                font.pixelSize: 13
                                font.weight: Font.Medium
                                color: NexaUI.NexaColors.text
                            }
                            Text {
                                text: "Opacity and radius of luminous halos surrounding beads (" + Math.round(root.glowIntensity * 100) + "%)"
                                font.family: NexaUI.NexaTypography.familyBody
                                font.pixelSize: 11
                                color: NexaUI.NexaColors.mutedText
                            }
                        }

                        NexaUI.NexaSlider {
                            Layout.preferredWidth: 220
                            from: 20
                            to: 150
                            stepSize: 5
                            value: Math.round(root.glowIntensity * 100)
                            showValue: true
                            valueSuffix: "%"
                            valueDecimals: 0
                            onMoved: v => {
                                root.glowIntensity = v / 100.0;
                                root.queueSave();
                            }
                        }
                    }

                    // Divider
                    Rectangle {
                        Layout.fillWidth: true; height: 1
                        color: NexaUI.NexaColors.border; opacity: 0.5
                        visible: root.railStyle === "constellation"
                    }

                    // Particle Count Slider (Constellation)
                    RowLayout {
                        Layout.fillWidth: true
                        visible: root.railStyle === "constellation"

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                text: "Star Bead Density"
                                font.family: NexaUI.NexaTypography.familyBody
                                font.pixelSize: 13
                                font.weight: Font.Medium
                                color: NexaUI.NexaColors.text
                            }
                            Text {
                                text: "Total number of constellation particles orbiting the rail (" + root.particleCount + " beads)"
                                font.family: NexaUI.NexaTypography.familyBody
                                font.pixelSize: 11
                                color: NexaUI.NexaColors.mutedText
                            }
                        }

                        NexaUI.NexaSlider {
                            Layout.preferredWidth: 220
                            from: 4
                            to: 16
                            stepSize: 2
                            value: root.particleCount
                            showValue: true
                            valueSuffix: " beads"
                            valueDecimals: 0
                            onMoved: v => {
                                root.particleCount = Math.round(v);
                                root.queueSave();
                            }
                        }
                    }

                    // Divider
                    Rectangle {
                        Layout.fillWidth: true; height: 1
                        color: NexaUI.NexaColors.border; opacity: 0.5
                        visible: root.railStyle !== "none"
                    }

                    // Rail Line Opacity Slider
                    RowLayout {
                        Layout.fillWidth: true
                        visible: root.railStyle !== "none"

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                text: "Horizon Rail Line Opacity"
                                font.family: NexaUI.NexaTypography.familyBody
                                font.pixelSize: 13
                                font.weight: Font.Medium
                                color: NexaUI.NexaColors.text
                            }
                            Text {
                                text: "Subtlety of the horizontal track line (" + Math.round(root.lineOpacity * 100) + "%)"
                                font.family: NexaUI.NexaTypography.familyBody
                                font.pixelSize: 11
                                color: NexaUI.NexaColors.mutedText
                            }
                        }

                        NexaUI.NexaSlider {
                            Layout.preferredWidth: 220
                            from: 10
                            to: 80
                            stepSize: 5
                            value: Math.round(root.lineOpacity * 100)
                            showValue: true
                            valueSuffix: "%"
                            valueDecimals: 0
                            onMoved: v => {
                                root.lineOpacity = v / 100.0;
                                root.queueSave();
                            }
                        }
                    }
                }
            }
        }
    }

    // Feedback Toast Popup
    Rectangle {
        id: toast
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 24
        anchors.horizontalCenter: parent.horizontalCenter
        width: toastTextItem.implicitWidth + 36
        height: 38
        radius: root.rad(19)
        color: NexaUI.NexaColors.surfaceContainerHighest
        border.width: NexaUI.NexaTokens.borderThin
        border.color: NexaUI.NexaColors.border
        opacity: root.toastVisible ? 1.0 : 0.0
        visible: opacity > 0.01

        Behavior on opacity {
            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
        }

        Row {
            anchors.centerIn: parent
            spacing: 8

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "󰄬"
                font.family: NexaUI.NexaTypography.familyIcon
                font.pixelSize: 14
                color: NexaUI.NexaColors.primary
            }

            Text {
                id: toastTextItem
                anchors.verticalCenter: parent.verticalCenter
                text: root.toastText
                font.family: NexaUI.NexaTypography.familyBody
                font.pixelSize: 12
                font.weight: Font.Medium
                color: NexaUI.NexaColors.text
            }
        }
    }
}
