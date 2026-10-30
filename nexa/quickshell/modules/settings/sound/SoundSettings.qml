// pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../../theme" as Nexa
import "../../lockthemes/components"
import "../../../theme/components" as NexaUI
import "../../../modules/audio" as AudioModule

Item {
    id: root

    anchors.fill: parent

    signal requestClose()

    // ────────────────────────────────────────────────────────────
    // AUDIO SERVICE BRIDGE (PipeWire Output & Mic)
    // ────────────────────────────────────────────────────────────
    AudioModule.Audio {
        id: audio
        visible: root.visible
        micMonitorActive: root.visible
    }

    function rad(n) {
        if (Nexa.Theme.nexaRounding === 0) return 0;
        return Math.max(0, Math.round(n * (Nexa.Theme.nexaRounding / 10.0)));
    }

    // ────────────────────────────────────────────────────────────
    // STATE & CONFIG
    // ────────────────────────────────────────────────────────────
    property bool masterEnabled: true
    property int masterVolume: 80
    property string soundDir: Quickshell.env("HOME") + "/.config/nexa/sounds"
    property var soundList: []
    property bool sinkSelectorOpen: false

    // Toast status notification
    property string toastMessage: ""
    property bool toastVisible: false

    function showToast(msg) {
        toastMessage = msg;
        toastVisible = true;
        toastTimer.restart();
    }

    Timer {
        id: toastTimer
        interval: 2200
        repeat: false
        onTriggered: root.toastVisible = false
    }

    // Sound metadata mapping
    readonly property var soundMeta: ({
        "volumne": { icon: "󰕾", category: "Desktop Audio" },
        "screenshot_sound": { icon: "󰄀", category: "Media Capture" },
        "charging_cable_insert": { icon: "󱐋", category: "Power & Battery" },
        "charging_cable_remove": { icon: "󰚥", category: "Power & Battery" },
        "Full-battery-charge": { icon: "󰂅", category: "Power & Battery" },
        "low_battery": { icon: "󰂃", category: "Power & Battery" },
        "lock": { icon: "󰌾", category: "Security & Session" },
        "unlock": { icon: "󰌿", category: "Security & Session" },
        "notification": { icon: "󰂚", category: "System Alerts" },
        "trash": { icon: "󰩹", category: "System Actions" }
    })

    function getMeta(name) {
        return soundMeta[name] || { icon: "󰎆", category: "Sound Effect" };
    }

    // ────────────────────────────────────────────────────────────
    // PROCESSES
    // ────────────────────────────────────────────────────────────
    function loadSoundStatus() {
        if (!loadProcess.running) {
            loadProcess.running = true;
        }
    }

    Process {
        id: loadProcess
        command: [Nexa.Theme.nexadBin, "sound", "get"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!this.text || this.text.trim() === "") return;
                try {
                    const data = JSON.parse(this.text);
                    root.masterEnabled = Boolean(data.master_enabled);
                    root.masterVolume = Number(data.master_volume ?? 80);
                    if (data.sound_dir) root.soundDir = data.sound_dir;
                    if (data.sounds && Array.isArray(data.sounds)) {
                        root.soundList = data.sounds;
                    }
                } catch (e) {
                    console.warn("[SoundSettings] Failed to parse sound config:", e);
                }
            }
        }
    }

    function setMasterVolume(val) {
        const clamped = Math.max(0, Math.min(100, Math.round(val)));
        root.masterVolume = clamped;
        Quickshell.execDetached([Nexa.Theme.nexadBin, "sound", "set-master-volume", clamped.toString()]);
    }

    function setMasterEnabled(en) {
        root.masterEnabled = en;
        Quickshell.execDetached([Nexa.Theme.nexadBin, "sound", "set-master-enabled", en ? "true" : "false"]);
        showToast(en ? "✓ Master sound effects enabled" : "Master sound effects muted");
    }

    function setSoundVolume(name, val) {
        const clamped = Math.max(0, Math.min(100, Math.round(val)));
        let arr = root.soundList.slice();
        for (let i = 0; i < arr.length; i++) {
            if (arr[i].name === name) {
                arr[i] = Object.assign({}, arr[i], { volume: clamped });
                break;
            }
        }
        root.soundList = arr;
        Quickshell.execDetached([Nexa.Theme.nexadBin, "sound", "set-sound-volume", name, clamped.toString()]);
    }

    function setSoundEnabled(name, en) {
        let arr = root.soundList.slice();
        for (let i = 0; i < arr.length; i++) {
            if (arr[i].name === name) {
                arr[i] = Object.assign({}, arr[i], { enabled: en });
                break;
            }
        }
        root.soundList = arr;
        Quickshell.execDetached([Nexa.Theme.nexadBin, "sound", "set-sound-enabled", name, en ? "true" : "false"]);
    }

    function previewSound(name, vol) {
        Quickshell.execDetached([Nexa.Theme.nexadBin, "sound", "preview", name, vol.toString()]);
    }

    function openSoundFolder() {
        Quickshell.execDetached([Nexa.Theme.nexadBin, "sound", "folder"]);
    }

    Component.onCompleted: {
        loadSoundStatus();
    }

    // ────────────────────────────────────────────────────────────
    // MAIN SCROLLABLE VIEW
    // ────────────────────────────────────────────────────────────
    Flickable {
        id: flickable
        anchors.fill: parent
        anchors.margins: 4
        clip: true
        contentWidth: width
        contentHeight: contentCol.implicitHeight + 64
        boundsBehavior: Flickable.StopAtBounds

        NexaUI.NexaSmoothScroll {}

        Column {
            id: contentCol
            width: parent.width - 24
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 18

            // ════════════════════════════════════════════════════════
            // 1. HARDWARE AUDIO & MICROPHONE HERO CARD
            // ════════════════════════════════════════════════════════
            Rectangle {
                width: parent.width
                implicitHeight: hwCardContent.implicitHeight + 36
                radius: root.rad(16)
                color: Nexa.Theme.cardBackground
                border.width: Nexa.Theme.borderThin
                border.color: Nexa.Theme.border

                // Specular liquid glass highlight
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: parent.border.width
                    radius: Math.max(0, parent.radius - parent.border.width)
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Nexa.Theme.edgeHighlight }
                        GradientStop { position: 0.25; color: "transparent" }
                    }
                }

                Column {
                    id: hwCardContent
                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                        margins: 18
                    }
                    spacing: 16

                    // Header row
                    RowLayout {
                        width: parent.width
                        spacing: 10

                        Rectangle {
                            width: 38
                            height: 38
                            radius: root.rad(10)
                            color: Nexa.Theme.primaryContainer

                            Text {
                                anchors.centerIn: parent
                                text: "󰓃"
                                font.family: Nexa.Theme.iconFontFamily
                                font.pixelSize: 20
                                color: Nexa.Theme.onPrimaryContainer
                            }
                        }

                        Column {
                            Layout.fillWidth: true
                            spacing: 1

                            StyledText {
                                text: "Audio Devices & Hardware"
                                font.pixelSize: 15
                                font.weight: Font.Bold
                                color: Nexa.Theme.text
                            }

                            StyledText {
                                text: "System master output, active sink & microphone input monitoring"
                                font.pixelSize: 11
                                color: Nexa.Theme.mutedText
                            }
                        }

                        // Sink selector button
                        ClickableRect {
                            id: sinkDropdownBtn
                            visible: audio.sinks && audio.sinks.length > 0
                            implicitHeight: 32
                            implicitWidth: sinkBtnRow.implicitWidth + 24
                            radius: root.rad(8)
                            color: root.sinkSelectorOpen ? Nexa.Theme.primaryContainer : (sinkDropdownBtn.hovered ? Nexa.Theme.surfaceContainerHigh : Nexa.Theme.surfaceContainer)
                            border.width: Nexa.Theme.borderThin
                            border.color: root.sinkSelectorOpen ? Nexa.Theme.primary : Nexa.Theme.border
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.sinkSelectorOpen = !root.sinkSelectorOpen;
                                if (root.sinkSelectorOpen) audio.refreshSinks();
                            }

                            Row {
                                id: sinkBtnRow
                                anchors.centerIn: parent
                                spacing: 8

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: {
                                        for (let i = 0; i < audio.sinks.length; i++) {
                                            if (audio.sinks[i].active) return audio.sinks[i].icon || "󰕾";
                                        }
                                        return "󰕾";
                                    }
                                    font.family: Nexa.Theme.iconFontFamily
                                    font.pixelSize: 14
                                    color: root.sinkSelectorOpen ? Nexa.Theme.onPrimaryContainer : Nexa.Theme.primary
                                }

                                StyledText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: {
                                        for (let i = 0; i < audio.sinks.length; i++) {
                                            if (audio.sinks[i].active) {
                                                const d = audio.sinks[i].description || "Output";
                                                return d.length > 22 ? d.substring(0, 20) + "…" : d;
                                            }
                                        }
                                        return "Select Device";
                                    }
                                    font.pixelSize: 12
                                    font.weight: Font.Medium
                                    color: root.sinkSelectorOpen ? Nexa.Theme.onPrimaryContainer : Nexa.Theme.text
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: root.sinkSelectorOpen ? "▴" : "▾"
                                    font.pixelSize: 11
                                    color: root.sinkSelectorOpen ? Nexa.Theme.onPrimaryContainer : Nexa.Theme.mutedText
                                }
                            }
                        }
                    }

                    // Expandable Sink Devices Picker
                    Column {
                        width: parent.width
                        visible: root.sinkSelectorOpen && audio.sinks && audio.sinks.length > 0
                        spacing: 6

                        Rectangle {
                            width: parent.width
                            height: 1
                            color: Nexa.Theme.divider
                        }

                        StyledText {
                            text: "AVAILABLE OUTPUT DEVICES"
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            font.letterSpacing: 0.8
                            color: Nexa.Theme.mutedText
                        }

                        Repeater {
                            model: audio.sinks
                            delegate: ClickableRect {
                                required property var modelData
                                width: parent.width
                                height: 38
                                radius: root.rad(8)
                                color: modelData.active ? Nexa.Theme.primaryContainer : (hovered ? Nexa.Theme.surfaceContainerHigh : Nexa.Theme.cardBackgroundElevated)
                                border.width: Nexa.Theme.borderThin
                                border.color: modelData.active ? Nexa.Theme.primary : Nexa.Theme.border
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    audio.setSink(modelData.id);
                                    root.sinkSelectorOpen = false;
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    spacing: 12

                                    Text {
                                        text: modelData.icon || "󰕾"
                                        font.family: Nexa.Theme.iconFontFamily
                                        font.pixelSize: 16
                                        color: modelData.active ? Nexa.Theme.onPrimaryContainer : Nexa.Theme.primary
                                    }

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: modelData.description || ("Sink " + modelData.id)
                                        elide: Text.ElideRight
                                        font.pixelSize: 12
                                        font.weight: modelData.active ? Font.Bold : Font.Normal
                                        color: modelData.active ? Nexa.Theme.onPrimaryContainer : Nexa.Theme.text
                                    }

                                    Text {
                                        visible: modelData.active
                                        text: "󰄬 Active"
                                        font.family: Nexa.Theme.fontFamily
                                        font.pixelSize: 11
                                        color: Nexa.Theme.primary
                                    }
                                }
                            }
                        }

                        Rectangle {
                            width: parent.width
                            height: 1
                            color: Nexa.Theme.divider
                        }
                    }

                    // Two columns: Left (Master Output) | Right (Microphone & VU meter)
                    Row {
                        width: parent.width
                        spacing: 16

                        // ── Left: Master Output ────────────────────────────────
                        Rectangle {
                            width: (parent.width - parent.spacing) / 2
                            implicitHeight: outputSubCol.implicitHeight + 24
                            radius: root.rad(12)
                            color: Nexa.Theme.surfaceContainerLow
                            border.width: Nexa.Theme.borderThin
                            border.color: Nexa.Theme.border

                            Column {
                                id: outputSubCol
                                anchors {
                                    left: parent.left
                                    right: parent.right
                                    top: parent.top
                                    margins: 12
                                }
                                spacing: 10

                                RowLayout {
                                    width: parent.width

                                    Text {
                                        text: audio.muted ? "󰝟" : (audio.volume > 50 ? "󰕾" : (audio.volume > 0 ? "󰖀" : "󰕿"))
                                        font.family: Nexa.Theme.iconFontFamily
                                        font.pixelSize: 18
                                        color: audio.muted ? Nexa.Theme.error : Nexa.Theme.primary
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: audio.toggleMute()
                                        }
                                    }

                                    StyledText {
                                        text: "Master Output"
                                        font.pixelSize: 13
                                        font.weight: Font.DemiBold
                                        color: Nexa.Theme.text
                                    }

                                    StyledText {
                                        text: audio.muted ? "(Muted)" : ""
                                        font.pixelSize: 11
                                        color: Nexa.Theme.error
                                    }

                                    Item { Layout.fillWidth: true }

                                    StyledText {
                                        text: audio.volume + "%"
                                        font.pixelSize: 13
                                        font.weight: Font.Bold
                                        font.family: Nexa.Theme.monoFontFamily
                                        color: Nexa.Theme.text
                                    }
                                }

                                NexaUI.NexaSlider {
                                    width: parent.width
                                    from: 0
                                    to: 100
                                    value: audio.volume
                                    sliderHeight: 28
                                    accentColor: audio.muted ? Nexa.Theme.mutedText : Nexa.Theme.primary
                                    onMoved: val => audio.setVolume(val)
                                    onReleased: val => audio.setVolumeImmediate(val)
                                }
                            }
                        }

                        // ── Right: Microphone & Live VU Meter ──────────────────
                        Rectangle {
                            width: (parent.width - parent.spacing) / 2
                            implicitHeight: micSubCol.implicitHeight + 24
                            radius: root.rad(12)
                            color: Nexa.Theme.surfaceContainerLow
                            border.width: Nexa.Theme.borderThin
                            border.color: Nexa.Theme.border

                            Column {
                                id: micSubCol
                                anchors {
                                    left: parent.left
                                    right: parent.right
                                    top: parent.top
                                    margins: 12
                                }
                                spacing: 10

                                RowLayout {
                                    width: parent.width

                                    Text {
                                        text: audio.inputMuted ? "󰍭" : "󰍬"
                                        font.family: Nexa.Theme.iconFontFamily
                                        font.pixelSize: 18
                                        color: audio.inputMuted ? Nexa.Theme.error : Nexa.Theme.primary
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: audio.toggleInputMute()
                                        }
                                    }

                                    StyledText {
                                        text: "Microphone Input"
                                        font.pixelSize: 13
                                        font.weight: Font.DemiBold
                                        color: Nexa.Theme.text
                                    }

                                    StyledText {
                                        text: audio.inputMuted ? "(Muted)" : "(Live)"
                                        font.pixelSize: 11
                                        color: audio.inputMuted ? Nexa.Theme.error : Nexa.Theme.primary
                                    }

                                    Item { Layout.fillWidth: true }

                                    StyledText {
                                        text: audio.inputVolume + "%"
                                        font.pixelSize: 13
                                        font.weight: Font.Bold
                                        font.family: Nexa.Theme.monoFontFamily
                                        color: Nexa.Theme.text
                                    }
                                }

                                NexaUI.NexaSlider {
                                    width: parent.width
                                    from: 0
                                    to: 100
                                    value: audio.inputVolume
                                    sliderHeight: 28
                                    livePulse: audio.inputMuted ? 0.0 : audio.micPeak
                                    accentColor: audio.inputMuted ? Nexa.Theme.mutedText : Nexa.Theme.primary
                                    onMoved: val => audio.setInputVolume(val)
                                    onReleased: val => audio.setInputVolumeImmediate(val)
                                }

                                // ── Live Animated Mic VU Meter ──────────────────────
                                Column {
                                    width: parent.width
                                    spacing: 4

                                    RowLayout {
                                        width: parent.width

                                        StyledText {
                                            text: "INPUT LEVEL (VU METER)"
                                            font.pixelSize: 9
                                            font.weight: Font.Bold
                                            font.letterSpacing: 0.5
                                            color: Nexa.Theme.mutedText
                                        }

                                        Item { Layout.fillWidth: true }

                                        StyledText {
                                            text: audio.inputMuted ? "MUTED" : Math.round(audio.micPeak * 100) + "% PEAK"
                                            font.pixelSize: 9
                                            font.weight: Font.Bold
                                            font.family: Nexa.Theme.monoFontFamily
                                            color: audio.inputMuted ? Nexa.Theme.mutedText : (audio.micPeak > 0.85 ? Nexa.Theme.error : Nexa.Theme.primary)
                                        }
                                    }

                                    // VU Segment Meter Track
                                    Rectangle {
                                        width: parent.width
                                        height: 8
                                        radius: 4
                                        color: Nexa.Theme.cardBackgroundElevated
                                        clip: true

                                        // Filled Level Bar
                                        Rectangle {
                                            id: vuFill
                                            anchors.left: parent.left
                                            anchors.top: parent.top
                                            anchors.bottom: parent.bottom
                                            width: parent.width * (audio.inputMuted ? 0 : Math.max(0.02, audio.micPeak))
                                            radius: 4

                                            gradient: Gradient {
                                                orientation: Gradient.Horizontal
                                                GradientStop { position: 0.0; color: "#10b981" } // green
                                                GradientStop { position: 0.7; color: "#f59e0b" } // amber
                                                GradientStop { position: 0.95; color: "#ef4444" } // red
                                            }

                                            Behavior on width {
                                                NumberAnimation { duration: 60; easing.type: Easing.OutQuad }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ════════════════════════════════════════════════════════
            // 2. DESKTOP SOUND EFFECTS MASTER CARD
            // ════════════════════════════════════════════════════════
            Rectangle {
                width: parent.width
                implicitHeight: effectsMasterContent.implicitHeight + 36
                radius: root.rad(16)
                color: Nexa.Theme.cardBackground
                border.width: Nexa.Theme.borderThin
                border.color: Nexa.Theme.border

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: parent.border.width
                    radius: Math.max(0, parent.radius - parent.border.width)
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Nexa.Theme.edgeHighlight }
                        GradientStop { position: 0.25; color: "transparent" }
                    }
                }

                Column {
                    id: effectsMasterContent
                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                        margins: 18
                    }
                    spacing: 16

                    // Master Title & Toggle Row
                    RowLayout {
                        width: parent.width
                        spacing: 12

                        Rectangle {
                            width: 38
                            height: 38
                            radius: root.rad(10)
                            color: root.masterEnabled ? Nexa.Theme.primaryContainer : Nexa.Theme.surfaceContainer

                            Text {
                                anchors.centerIn: parent
                                text: root.masterEnabled ? "󰕾" : "󰝟"
                                font.family: Nexa.Theme.iconFontFamily
                                font.pixelSize: 20
                                color: root.masterEnabled ? Nexa.Theme.onPrimaryContainer : Nexa.Theme.mutedText
                            }
                        }

                        Column {
                            Layout.fillWidth: true
                            spacing: 1

                            StyledText {
                                text: "Desktop Sound Effects"
                                font.pixelSize: 15
                                font.weight: Font.Bold
                                color: Nexa.Theme.text
                            }

                            StyledText {
                                text: "Acoustic feedback for system actions, screenshots, session locks & power changes"
                                font.pixelSize: 11
                                color: Nexa.Theme.mutedText
                            }
                        }

                        // Open Folder Button
                        ClickableRect {
                            id: openFolderBtn
                            implicitHeight: 34
                            implicitWidth: folderBtnRow.implicitWidth + 24
                            radius: root.rad(8)
                            color: openFolderBtn.hovered ? Nexa.Theme.surfaceContainerHigh : Nexa.Theme.surfaceContainer
                            border.width: Nexa.Theme.borderThin
                            border.color: Nexa.Theme.border
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.openSoundFolder()

                            Row {
                                id: folderBtnRow
                                anchors.centerIn: parent
                                spacing: 8

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "󰉋"
                                    font.family: Nexa.Theme.iconFontFamily
                                    font.pixelSize: 16
                                    color: Nexa.Theme.primary
                                }

                                StyledText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Sounds Folder"
                                    font.pixelSize: 12
                                    font.weight: Font.Medium
                                    color: Nexa.Theme.text
                                }
                            }
                        }

                        Item { width: 4 }

                        // Master Sound Effects Toggle
                        NexaUI.NexaToggle {
                            checked: root.masterEnabled
                            onToggled: chk => root.setMasterEnabled(chk)
                        }
                    }

                    // Master Effects Volume Slider
                    Column {
                        width: parent.width
                        spacing: 8
                        opacity: root.masterEnabled ? 1.0 : 0.45
                        enabled: root.masterEnabled

                        RowLayout {
                            width: parent.width

                            StyledText {
                                text: "Effects Master Volume"
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                                color: Nexa.Theme.text
                            }

                            Item { Layout.fillWidth: true }

                            StyledText {
                                text: root.masterVolume + "%"
                                font.pixelSize: 12
                                font.weight: Font.Bold
                                font.family: Nexa.Theme.monoFontFamily
                                color: Nexa.Theme.text
                            }
                        }

                        NexaUI.NexaSlider {
                            width: parent.width
                            from: 0
                            to: 100
                            value: root.masterVolume
                            sliderHeight: 28
                            onMoved: val => root.setMasterVolume(val)
                            onReleased: val => root.setMasterVolume(val)
                        }
                    }

                    // Informational callout
                    Rectangle {
                        width: parent.width
                        implicitHeight: hintRow.implicitHeight + 14
                        radius: root.rad(8)
                        color: Nexa.Theme.surfaceContainerLow
                        border.width: Nexa.Theme.borderThin
                        border.color: Nexa.Theme.border

                        RowLayout {
                            id: hintRow
                            anchors {
                                left: parent.left
                                right: parent.right
                                verticalCenter: parent.verticalCenter
                                margins: 12
                            }
                            spacing: 10

                            Text {
                                text: "󰋼"
                                font.family: Nexa.Theme.iconFontFamily
                                font.pixelSize: 16
                                color: Nexa.Theme.primary
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: "You can customize any sound by dropping a file with matching name into ~/.config/nexa/sounds. Formats supported: .mp3, .wav, .ogg, .flac, .opus, .aac."
                                font.pixelSize: 11
                                color: Nexa.Theme.mutedText
                                wrapMode: Text.WordWrap
                            }
                        }
                    }
                }
            }

            // ════════════════════════════════════════════════════════
            // 3. SYSTEM EVENT SOUNDS (10 INDIVIDUAL SOUND CARDS)
            // ════════════════════════════════════════════════════════
            Item {
                width: parent.width
                height: 24

                StyledText {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "SYSTEM SOUND EVENTS"
                    font.pixelSize: 11
                    font.weight: Font.Bold
                    font.letterSpacing: 1.0
                    color: Nexa.Theme.mutedText
                }
            }

            Repeater {
                model: root.soundList
                delegate: Rectangle {
                    required property var modelData
                    required property int index

                    width: parent.width
                    implicitHeight: cardCol.implicitHeight + 24
                    radius: root.rad(14)
                    color: Nexa.Theme.cardBackground
                    border.width: Nexa.Theme.borderThin
                    border.color: Nexa.Theme.border
                    opacity: root.masterEnabled ? (modelData.enabled ? 1.0 : 0.6) : 0.45

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: parent.border.width
                        radius: Math.max(0, parent.radius - parent.border.width)
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Nexa.Theme.edgeHighlight }
                            GradientStop { position: 0.3; color: "transparent" }
                        }
                    }

                    Column {
                        id: cardCol
                        anchors {
                            left: parent.left
                            right: parent.right
                            top: parent.top
                            margins: 14
                        }
                        spacing: 12

                        // Top Row: Icon, Title & Meta, Format Badge, Toggle
                        RowLayout {
                            width: parent.width
                            spacing: 12

                            // Sound Event Icon
                            Rectangle {
                                width: 36
                                height: 36
                                radius: root.rad(9)
                                color: modelData.enabled ? Nexa.Theme.primaryContainer : Nexa.Theme.surfaceContainer

                                Text {
                                    anchors.centerIn: parent
                                    text: root.getMeta(modelData.name).icon
                                    font.family: Nexa.Theme.iconFontFamily
                                    font.pixelSize: 18
                                    color: modelData.enabled ? Nexa.Theme.onPrimaryContainer : Nexa.Theme.mutedText
                                }
                            }

                            // Sound Title, Category & Description
                            Column {
                                Layout.fillWidth: true
                                spacing: 2

                                Row {
                                    spacing: 8

                                    StyledText {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData.display_name
                                        font.pixelSize: 13
                                        font.weight: Font.Bold
                                        color: Nexa.Theme.text
                                    }

                                    // Category Chip
                                    Rectangle {
                                        anchors.verticalCenter: parent.verticalCenter
                                        height: 18
                                        width: catText.implicitWidth + 12
                                        radius: root.rad(4)
                                        color: Nexa.Theme.surfaceContainerHigh

                                        StyledText {
                                            id: catText
                                            anchors.centerIn: parent
                                            text: root.getMeta(modelData.name).category
                                            font.pixelSize: 9
                                            font.weight: Font.DemiBold
                                            color: Nexa.Theme.mutedText
                                        }
                                    }
                                }

                                StyledText {
                                    text: modelData.description
                                    font.pixelSize: 11
                                    color: Nexa.Theme.mutedText
                                }
                            }

                            // Format Badge
                            Rectangle {
                                height: 22
                                width: formatRow.implicitWidth + 14
                                radius: root.rad(6)
                                color: modelData.file_found ? Nexa.Theme.surfaceContainerLow : Nexa.Theme.errorContainer
                                border.width: Nexa.Theme.borderThin
                                border.color: modelData.file_found ? Nexa.Theme.border : Nexa.Theme.error

                                Row {
                                    id: formatRow
                                    anchors.centerIn: parent
                                    spacing: 5

                                    Rectangle {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 6
                                        height: 6
                                        radius: 3
                                        color: modelData.file_found ? "#10b981" : Nexa.Theme.error
                                    }

                                    StyledText {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData.file_found ? modelData.file_ext.toUpperCase() : "MISSING"
                                        font.pixelSize: 10
                                        font.weight: Font.Bold
                                        font.family: Nexa.Theme.monoFontFamily
                                        color: modelData.file_found ? Nexa.Theme.text : Nexa.Theme.error
                                    }
                                }
                            }

                            Item { width: 4 }

                            // Per-Sound Enable Toggle
                            NexaUI.NexaToggle {
                                checked: modelData.enabled
                                enabled: root.masterEnabled
                                onToggled: chk => root.setSoundEnabled(modelData.name, chk)
                            }
                        }

                        // Divider line
                        Rectangle {
                            width: parent.width
                            height: 1
                            color: Nexa.Theme.divider
                            opacity: 0.5
                        }

                        // Bottom Control Row: Play Preview Button + Volume Slider + Percentage
                        RowLayout {
                            width: parent.width
                            spacing: 12
                            enabled: root.masterEnabled && modelData.enabled

                            // Play Preview Button
                            ClickableRect {
                                id: previewBtn
                                implicitHeight: 30
                                implicitWidth: previewRow.implicitWidth + 20
                                radius: root.rad(8)
                                color: previewBtn.hovered ? Nexa.Theme.primaryContainer : Nexa.Theme.surfaceContainerHigh
                                border.width: Nexa.Theme.borderThin
                                border.color: previewBtn.hovered ? Nexa.Theme.primary : Nexa.Theme.border
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.previewSound(modelData.name, modelData.volume)

                                Row {
                                    id: previewRow
                                    anchors.centerIn: parent
                                    spacing: 6

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "󰐊"
                                        font.family: Nexa.Theme.iconFontFamily
                                        font.pixelSize: 13
                                        color: Nexa.Theme.primary
                                    }

                                    StyledText {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "Preview"
                                        font.pixelSize: 11
                                        font.weight: Font.Medium
                                        color: Nexa.Theme.text
                                    }
                                }
                            }

                            // Individual Sound Volume Slider
                            NexaUI.NexaSlider {
                                Layout.fillWidth: true
                                from: 0
                                to: 100
                                value: modelData.volume
                                sliderHeight: 26
                                onMoved: val => root.setSoundVolume(modelData.name, val)
                                onReleased: val => root.setSoundVolume(modelData.name, val)
                            }

                            // Volume Percentage Text
                            StyledText {
                                text: modelData.volume + "%"
                                font.pixelSize: 12
                                font.weight: Font.Bold
                                font.family: Nexa.Theme.monoFontFamily
                                color: Nexa.Theme.text
                            }
                        }
                    }
                }
            }
        }
    }

    // ────────────────────────────────────────────────────────────
    // TOAST BANNER
    // ────────────────────────────────────────────────────────────
    Rectangle {
        id: toast
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 24
        anchors.horizontalCenter: parent.horizontalCenter
        height: 36
        width: toastText.implicitWidth + 32
        radius: root.rad(18)
        color: Nexa.Theme.panelBackground
        border.width: Nexa.Theme.borderThin
        border.color: Nexa.Theme.border
        opacity: root.toastVisible ? 1.0 : 0.0
        scale: root.toastVisible ? 1.0 : 0.92
        visible: opacity > 0.01

        Behavior on opacity {
            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
        }
        Behavior on scale {
            NumberAnimation { duration: 180; easing.type: Easing.OutBack }
        }

        StyledText {
            id: toastText
            anchors.centerIn: parent
            text: root.toastMessage
            font.pixelSize: 12
            font.weight: Font.Medium
            color: Nexa.Theme.text
        }
    }
}

