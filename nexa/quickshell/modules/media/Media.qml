import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import Quickshell.Services.Mpris
import Quickshell.Io

import "../../theme" as Nexa
import "../../theme/components" as NexaUI


Item {
    id: root

    // ============================================================
    // RESPONSIBILITY
    //
    // Modern NEXA Media Player frontend:
    // - Reliable horizontal sliding marquee ticker for overflowing titles
    // - Slender, highly-reactive bottom-anchored audio spectrum (CAVA)
    // - Glass album art, hero controls, shuffle/loop & volume
    // ============================================================

    property string presentation: "full"

    // ============================================================
    // MPRIS PLAYER
    // ============================================================

    readonly property var player: {
        const list = Mpris.players.values
        if (!list || list.length === 0) return null

        // 1. Prioritize any player actively playing
        for (let i = 0; i < list.length; ++i) {
            if (list[i] && list[i].playbackState === MprisPlaybackState.Playing)
                return list[i]
        }

        // 2. Prioritize paused player with track metadata
        for (let i = 0; i < list.length; ++i) {
            if (list[i] && list[i].playbackState === MprisPlaybackState.Paused && (list[i].trackTitle || list[i].trackArtist))
                return list[i]
        }

        // 3. Fallback to any player with track metadata
        for (let i = 0; i < list.length; ++i) {
            if (list[i] && (list[i].trackTitle || list[i].trackArtist))
                return list[i]
        }

        // 4. Default to first available player
        return list[0]
    }

    readonly property bool available:
        player !== null

    readonly property bool playing:
        available
        && player.playbackState === MprisPlaybackState.Playing

    readonly property bool paused:
        available
        && player.playbackState === MprisPlaybackState.Paused

    // ------------------------------------------------------------
    // 1-MINUTE PAUSE / IDLE TIMEOUT
    // ------------------------------------------------------------

    property bool pauseTimeoutExpired: false

    Timer {
        id: pauseTimeoutTimer
        interval: 60000
        running: root.available && root.hasTrack && root.paused && !root.playing
        repeat: false
        onTriggered: {
            root.pauseTimeoutExpired = true
        }
    }

    onPlayingChanged: {
        if (root.playing) {
            root.pauseTimeoutExpired = false
            pauseTimeoutTimer.stop()
        }
    }

    onHasTrackChanged: {
        if (!root.hasTrack) {
            root.pauseTimeoutExpired = false
            pauseTimeoutTimer.stop()
        }
    }

    readonly property bool contextActive:
        available
        && hasTrack
        && (playing || (paused && !pauseTimeoutExpired))

    readonly property bool hasTrack:
        available
        && (player.trackTitle !== "" || player.trackArtist !== "")

    // ============================================================
    // METADATA
    // ============================================================

    readonly property string title:
        available && player.trackTitle !== ""
        ? player.trackTitle
        : "Nothing playing"

    readonly property string artist:
        available && player.trackArtist !== ""
        ? player.trackArtist
        : "Unknown artist"

    readonly property string album:
        available && player.trackAlbum !== ""
        ? player.trackAlbum
        : ""

    readonly property string artwork:
        available
        ? player.trackArtUrl
        : ""

    readonly property string identity:
        available && player.identity !== ""
        ? player.identity
        : "Media Player"

    function playerIcon(idName) {
        const id = String(idName || "").toLowerCase()
        if (id.includes("spotify")) return "󰓇"
        if (id.includes("firefox")) return "󰈹"
        if (id.includes("chrome") || id.includes("chromium") || id.includes("brave")) return "󰊯"
        if (id.includes("vlc")) return "󰕼"
        if (id.includes("mpv")) return "󰐎"
        return "󰎆"
    }

    // ============================================================
    // POSITION & DURATION
    // ============================================================

    readonly property real duration:
        available && player.lengthSupported
        ? player.length
        : 0

    readonly property real position:
        available && player.positionSupported
        ? player.position
        : 0

    readonly property real progress:
        duration > 0
        ? Math.max(0, Math.min(1, position / duration))
        : 0

    property bool seeking: false
    property real seekPosition: 0

    readonly property real displayedPosition:
        seeking ? seekPosition : position

    readonly property real displayedProgress:
        duration > 0
        ? Math.max(0, Math.min(1, displayedPosition / duration))
        : 0

    // ============================================================
    // CAVA SPECTRUM DATA
    // ============================================================

    property var spectrumBins: []

    readonly property bool spectrumAvailable:
        spectrumBins && spectrumBins.length > 0

    Process {
        id: cavaProcess
        running: root.playing && root.presentation === "full"
        command: [
            "cava",
            "-p",
            "/home/shnx/.config/nexa/config/cava.conf"
        ]

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                const line = data.trim()
                if (line === "") return
                const parts = line.split(";")
                const values = []
                for (let i = 0; i < parts.length; ++i) {
                    if (parts[i] === "") continue
                    const raw = Number(parts[i])
                    if (isNaN(raw)) continue
                    // Natural audio dynamics (0.0 to 1.0) with slight mid-range compensation
                    const val = Math.max(0.0, Math.min(1.0, (raw / 1000.0) * 1.15))
                    values.push(val)
                }
                if (values.length > 0)
                    root.spectrumBins = values
            }
        }

        onRunningChanged: {
            if (!running)
                root.spectrumBins = []
        }
    }

    // Position refresh timer
    Timer {
        interval: 500
        repeat: true
        running: root.available && root.playing && root.player.positionSupported && !root.seeking
        onTriggered: root.player.positionChanged()
    }

    // Helpers
    function formatTime(seconds) {
        if (!isFinite(seconds) || seconds < 0)
            return "0:00"
        const total = Math.floor(seconds)
        const minutes = Math.floor(total / 60)
        const secs = total % 60
        return minutes + ":" + String(secs).padStart(2, "0")
    }

    function playerBrandColor(idName) {
        const id = String(idName || "").toLowerCase()
        if (id.includes("spotify")) return "#1DB954"
        if (id.includes("firefox")) return "#FF7139"
        if (id.includes("chrome") || id.includes("chromium")) return "#4285F4"
        if (id.includes("brave")) return "#FB542B"
        if (id.includes("vlc")) return "#FF8800"
        if (id.includes("mpv")) return "#9C27B0"
        return Nexa.Theme.primary
    }

    // ============================================================
    // SINK VOLUME TRACKING & CONTROLS
    // ============================================================

    property real sinkVolume: 0.65
    property bool sinkMuted: false

    Process {
        id: sinkVolumeReader
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => {
                const parts = line.trim().split(" ")
                if (parts.length >= 2 && parts[0] === "Volume:") {
                    const val = parseFloat(parts[1])
                    if (!isNaN(val)) root.sinkVolume = Math.max(0.0, Math.min(1.0, val))
                    root.sinkMuted = line.includes("[MUTED]")
                }
            }
        }
    }

    Timer {
        interval: 1200
        repeat: true
        running: root.presentation === "full"
        onTriggered: {
            if (!sinkVolumeReader.running) sinkVolumeReader.running = true
        }
    }

    function setSinkVolume(val) {
        root.sinkVolume = Math.max(0.0, Math.min(1.0, val))
        const pct = Math.round(root.sinkVolume * 100)
        Quickshell.execDetached(["wpctl", "set-volume", "-l", "1.0", "@DEFAULT_AUDIO_SINK@", pct + "%"])
    }

    function toggleSinkMute() {
        Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"])
        sinkVolumeReader.running = true
    }

    // ============================================================
    // PLAYBACK ACTIONS
    // ============================================================

    function previous() {
        if (available && player.canGoPrevious) player.previous()
    }

    function togglePlaying() {
        if (available && player.canTogglePlaying) player.togglePlaying()
    }

    function next() {
        if (available && player.canGoNext) player.next()
    }

    function toggleShuffle() {
        if (!available || !player.canShuffle) return
        player.shuffle = !player.shuffle
    }

    function toggleLoop() {
        if (!available || !player.canLoop) return
        if (player.loopStatus === MprisLoopStatus.None) {
            player.loopStatus = MprisLoopStatus.Playlist
        } else if (player.loopStatus === MprisLoopStatus.Playlist) {
            player.loopStatus = MprisLoopStatus.Track
        } else {
            player.loopStatus = MprisLoopStatus.None
        }
    }

    function updateSeekFromX(x, width) {
        if (!available || !player.canSeek || !player.positionSupported || duration <= 0 || width <= 0)
            return
        const ratio = Math.max(0, Math.min(1, x / width))
        seekPosition = ratio * duration
    }

    function commitSeek() {
        if (!available || !player.canSeek || !player.positionSupported) {
            seeking = false
            return
        }
        player.position = seekPosition
        seeking = false
        player.positionChanged()
    }

    // ============================================================
    // COMPACT PRESENTATION (Dynamic Island Notch)
    // ============================================================

    Item {
        anchors.fill: parent
        visible: root.presentation === "compact"

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Nexa.Theme.spacingMd
            anchors.rightMargin: Nexa.Theme.spacingMd
            spacing: Nexa.Theme.spacingSm

            // Small Artwork Thumbnail
            Rectangle {
                Layout.preferredWidth: 24
                Layout.preferredHeight: 24
                radius: 6
                color: Nexa.Theme.surfaceContainerHigh
                clip: true

                Image {
                    anchors.fill: parent
                    source: root.artwork
                    fillMode: Image.PreserveAspectCrop
                    visible: root.artwork !== ""
                }

                Text {
                    anchors.centerIn: parent
                    visible: root.artwork === ""
                    text: root.playerIcon(root.identity)
                    color: Nexa.Theme.mutedText
                    font.family: Nexa.Theme.iconFontFamily
                    font.pixelSize: Nexa.Theme.iconSm
                }
            }

            // Marquee Track & Artist Ticker
            Item {
                id: compactMarqueeBox
                Layout.fillWidth: true
                implicitHeight: 20
                clip: true

                readonly property string labelText: root.hasTrack
                    ? root.title + "  •  " + root.artist
                    : "Nothing playing"

                readonly property real overflowDist: Math.max(0, compactTickerText.implicitWidth - width)
                readonly property bool needsScroll: overflowDist > 4

                Text {
                    id: compactTickerText
                    x: 0
                    anchors.verticalCenter: parent.verticalCenter
                    text: compactMarqueeBox.labelText
                    color: root.hasTrack ? Nexa.Theme.text : Nexa.Theme.mutedText
                    font.family: Nexa.Theme.fontFamily
                    font.pixelSize: Nexa.Theme.fontSizeSm
                    font.weight: Nexa.Theme.fontWeightMedium
                }

                SequentialAnimation {
                    id: compactTickerAnim
                    running: compactMarqueeBox.needsScroll
                    loops: Animation.Infinite

                    PauseAnimation { duration: 1800 }
                    NumberAnimation {
                        target: compactTickerText
                        property: "x"
                        from: 0
                        to: -compactMarqueeBox.overflowDist - 16
                        duration: Math.max(1400, (compactMarqueeBox.overflowDist + 16) * 35)
                        easing.type: Easing.InOutQuad
                    }
                    PauseAnimation { duration: 1500 }
                    NumberAnimation {
                        target: compactTickerText
                        property: "x"
                        to: 0
                        duration: Math.max(1000, (compactMarqueeBox.overflowDist + 16) * 25)
                        easing.type: Easing.InOutQuad
                    }
                }

                onWidthChanged: {
                    compactTickerText.x = 0
                    if (needsScroll) compactTickerAnim.restart()
                    else compactTickerAnim.stop()
                }

                onLabelTextChanged: {
                    compactTickerText.x = 0
                    if (needsScroll) compactTickerAnim.restart()
                    else compactTickerAnim.stop()
                }
            }
        }
    }

    // ============================================================
    // HOVER PRESENTATION (Dynamic Island Expansion)
    // ============================================================

    Item {
        anchors.fill: parent
        visible: root.presentation === "hover"

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Nexa.Theme.spacingMd
            anchors.rightMargin: Nexa.Theme.spacingMd
            anchors.topMargin: Nexa.Theme.spacingSm
            anchors.bottomMargin: Nexa.Theme.spacingSm
            spacing: Nexa.Theme.spacingMd

            // Artwork Card
            Rectangle {
                Layout.preferredWidth: 42
                Layout.preferredHeight: 42
                radius: Nexa.Theme.radiusSm
                color: Nexa.Theme.surfaceContainerHigh
                clip: true

                Image {
                    anchors.fill: parent
                    source: root.artwork
                    fillMode: Image.PreserveAspectCrop
                    visible: root.artwork !== ""
                }

                Text {
                    anchors.centerIn: parent
                    visible: root.artwork === ""
                    text: root.playerIcon(root.identity)
                    color: Nexa.Theme.mutedText
                    font.family: Nexa.Theme.iconFontFamily
                    font.pixelSize: Nexa.Theme.iconMd
                }
            }

            // Info, Sliding Marquee & Progress
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    // Title Marquee Box
                    Item {
                        id: hoverTitleBox
                        Layout.fillWidth: true
                        implicitHeight: hoverTitleText.implicitHeight
                        clip: true

                        readonly property real overflowDist: Math.max(0, hoverTitleText.implicitWidth - width)
                        readonly property bool needsScroll: overflowDist > 4

                        Text {
                            id: hoverTitleText
                            x: 0
                            text: root.title
                            color: Nexa.Theme.text
                            font.family: Nexa.Theme.fontFamily
                            font.pixelSize: Nexa.Theme.fontSizeSm
                            font.weight: Nexa.Theme.fontWeightDemiBold
                        }

                        SequentialAnimation {
                            id: hoverTitleAnim
                            running: hoverTitleBox.needsScroll
                            loops: Animation.Infinite

                            PauseAnimation { duration: 1800 }
                            NumberAnimation {
                                target: hoverTitleText
                                property: "x"
                                from: 0
                                to: -hoverTitleBox.overflowDist - 16
                                duration: Math.max(1400, (hoverTitleBox.overflowDist + 16) * 35)
                                easing.type: Easing.InOutQuad
                            }
                            PauseAnimation { duration: 1500 }
                            NumberAnimation {
                                target: hoverTitleText
                                property: "x"
                                to: 0
                                duration: Math.max(1000, (hoverTitleBox.overflowDist + 16) * 25)
                                easing.type: Easing.InOutQuad
                            }
                        }

                        onWidthChanged: {
                            hoverTitleText.x = 0
                            if (needsScroll) hoverTitleAnim.restart()
                            else hoverTitleAnim.stop()
                        }

                        Connections {
                            target: root
                            function onTitleChanged() {
                                hoverTitleText.x = 0
                                if (hoverTitleBox.needsScroll) hoverTitleAnim.restart()
                                else hoverTitleAnim.stop()
                            }
                        }
                    }

                    Text {
                        text: root.formatTime(root.position) + " / " + root.formatTime(root.duration)
                        color: Nexa.Theme.mutedText
                        font.family: Nexa.Theme.monoFontFamily
                        font.pixelSize: Nexa.Theme.fontSize2Xs
                        visible: root.duration > 0
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: root.artist
                    color: Nexa.Theme.mutedText
                    font.family: Nexa.Theme.fontFamily
                    font.pixelSize: Nexa.Theme.fontSizeXs
                    elide: Text.ElideRight
                }

                // Mini Progress Bar
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 3
                    radius: 1.5
                    color: Nexa.Theme.surfaceContainerHighest
                    visible: root.duration > 0

                    Rectangle {
                        height: parent.height
                        width: parent.width * root.progress
                        radius: parent.radius
                        color: Nexa.Theme.primary
                    }
                }
            }

            // Quick Playback Controls
            RowLayout {
                spacing: Nexa.Theme.spacingXs

                NexaUI.NexaIconButton {
                    icon: "󰒮"
                    interactive: root.available && root.player.canGoPrevious
                    onClicked: root.previous()
                }

                NexaUI.NexaIconButton {
                    icon: root.playing ? "󰏤" : "󰐊"
                    selected: true
                    interactive: root.available && root.player.canTogglePlaying
                    onClicked: root.togglePlaying()
                }

                NexaUI.NexaIconButton {
                    icon: "󰒭"
                    interactive: root.available && root.player.canGoNext
                    onClicked: root.next()
                }
            }
        }
    }

    // ============================================================
    // FULL MUSIC VIEW (CYBER-LUMINOUS GLASS DECK)
    // ============================================================

    Item {
        id: fullMusicContainer
        anchors.fill: parent
        visible: root.presentation === "full"

        // --------------------------------------------------------
        // 1. AMBIENT BACKDROP & SPECULAR RIM
        // --------------------------------------------------------
        Rectangle {
            anchors.fill: parent
            radius: Nexa.Theme.radiusLg
            color: Nexa.Theme.surfaceContainerLow
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.08)
            clip: true
            z: -1

            // Dynamic blurred ambient artwork glow
            Image {
                id: bgAmbientArt
                anchors.fill: parent
                anchors.margins: -40
                source: root.artwork
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                opacity: (root.hasTrack && root.artwork !== "") ? 0.35 : 0.0

                Behavior on opacity {
                    NumberAnimation {
                        duration: 600
                        easing.type: Easing.OutCubic
                    }
                }
            }

            // High-tech frosted glass vignette
            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(
                    Nexa.Theme.surfaceContainerLow.r,
                    Nexa.Theme.surfaceContainerLow.g,
                    Nexa.Theme.surfaceContainerLow.b,
                    0.88
                )
            }

            // Top specular edge highlight
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 1
                color: Qt.rgba(1, 1, 1, 0.14)
            }
        }

        // --------------------------------------------------------
        // 2. IDLE STATE: WHEN NO ACTIVE TRACK IS PLAYING
        // --------------------------------------------------------
        Item {
            anchors.fill: parent
            visible: !root.hasTrack || (!root.playing && !root.paused)

            RowLayout {
                anchors.centerIn: parent
                spacing: 36

                // Frosted Vinyl Disc
                Item {
                    width: 150
                    height: 150
                    Layout.alignment: Qt.AlignVCenter

                    Rectangle {
                        anchors.fill: parent
                        radius: 75
                        color: "#14151f"
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.10)

                        // Grooves
                        Repeater {
                            model: [130, 110, 90, 70]
                            delegate: Rectangle {
                                anchors.centerIn: parent
                                width: modelData
                                height: modelData
                                radius: modelData / 2
                                color: "transparent"
                                border.width: 1
                                border.color: Qt.rgba(255/255, 255/255, 255/255, 0.04)
                            }
                        }

                        // Center Label
                        Rectangle {
                            anchors.centerIn: parent
                            width: 50
                            height: 50
                            radius: 25
                            color: Qt.rgba(Nexa.Theme.primary.r, Nexa.Theme.primary.g, Nexa.Theme.primary.b, 0.20)
                            border.width: 1
                            border.color: Nexa.Theme.primary

                            Text {
                                anchors.centerIn: parent
                                text: "󰎆"
                                color: Nexa.Theme.primary
                                font.family: Nexa.Theme.iconFontFamily
                                font.pixelSize: 22
                            }
                        }
                    }

                    // Gentle breathing pulse
                    SequentialAnimation on scale {
                        loops: Animation.Infinite
                        running: fullMusicContainer.visible && (!root.hasTrack || (!root.playing && !root.paused))
                        NumberAnimation { from: 0.98; to: 1.02; duration: 2400; easing.type: Easing.InOutSine }
                        NumberAnimation { from: 1.02; to: 0.98; duration: 2400; easing.type: Easing.InOutSine }
                    }
                }

                // Clean Description & Prompt
                ColumnLayout {
                    spacing: 8
                    Layout.alignment: Qt.AlignVCenter

                    Rectangle {
                        implicitWidth: idleStatusRow.implicitWidth + 18
                        implicitHeight: 24
                        radius: 12
                        color: Qt.rgba(255/255, 255/255, 255/255, 0.06)
                        border.width: 1
                        border.color: Qt.rgba(255/255, 255/255, 255/255, 0.08)

                        Row {
                            id: idleStatusRow
                            anchors.centerIn: parent
                            spacing: 6

                            Rectangle {
                                width: 6; height: 6; radius: 3
                                color: Nexa.Theme.primary
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: "READY FOR AUDIO"
                                color: Nexa.Theme.mutedText
                                font.family: Nexa.Theme.fontFamily
                                font.pixelSize: 10
                                font.weight: Nexa.Theme.fontWeightBold
                                font.letterSpacing: 1.2
                            }
                        }
                    }

                    Text {
                        text: "No Media Playing"
                        color: Nexa.Theme.text
                        font.family: Nexa.Theme.fontFamily
                        font.pixelSize: 22
                        font.weight: Nexa.Theme.fontWeightBold
                    }

                    Text {
                        text: "Play music or video on Spotify, YouTube, or MPV\nto unlock live controls, audio visualizer, and lyrics."
                        color: Nexa.Theme.mutedText
                        font.family: Nexa.Theme.fontFamily
                        font.pixelSize: 13
                        lineHeight: 1.3
                    }
                }
            }
        }

        // --------------------------------------------------------
        // 3. ACTIVE STATE: MODERN HERO PLAYER DECK
        // --------------------------------------------------------
        Item {
            anchors.fill: parent
            visible: root.hasTrack && (root.playing || root.paused)

            RowLayout {
                anchors.fill: parent
                anchors.margins: Nexa.Theme.spacingLg
                spacing: Nexa.Theme.spacingXl

                // ====================================================
                // LEFT: FLOATING VINYL + ALBUM ART CARD
                // ====================================================
                Item {
                    Layout.preferredWidth: 210
                    Layout.preferredHeight: 210
                    Layout.alignment: Qt.AlignVCenter

                    // The Spinning Vinyl Record (Slides out when playing)
                    Item {
                        id: vinylDisc
                        width: 190
                        height: 190
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: root.playing ? 34 : 4
                        z: 1

                        Behavior on anchors.leftMargin {
                            NumberAnimation { duration: 600; easing.type: Easing.OutBack }
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            color: "#0f1015"
                            border.width: 1
                            border.color: "#282a36"

                            // Vinyl grooves
                            Repeater {
                                model: [170, 150, 130, 110, 90]
                                delegate: Rectangle {
                                    anchors.centerIn: parent
                                    width: modelData
                                    height: modelData
                                    radius: modelData / 2
                                    color: "transparent"
                                    border.width: 1
                                    border.color: Qt.rgba(1, 1, 1, 0.04)
                                }
                            }

                            // Center Label
                            Rectangle {
                                anchors.centerIn: parent
                                width: 66
                                height: 66
                                radius: 33
                                color: Nexa.Theme.surfaceContainerHigh
                                border.width: 1
                                border.color: root.playerBrandColor(root.identity)
                                clip: true

                                Image {
                                    anchors.fill: parent
                                    source: root.artwork
                                    fillMode: Image.PreserveAspectCrop
                                    visible: root.artwork !== ""
                                }

                                Text {
                                    anchors.centerIn: parent
                                    visible: root.artwork === ""
                                    text: "󰎆"
                                    color: Nexa.Theme.primary
                                    font.family: Nexa.Theme.iconFontFamily
                                    font.pixelSize: 22
                                }

                                // Spindle Hole
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 10; height: 10; radius: 5
                                    color: "#090a0f"
                                    border.width: 1; border.color: "#3a3b4a"
                                }
                            }

                            RotationAnimation on rotation {
                                loops: Animation.Infinite
                                from: 0
                                to: 360
                                duration: 9000
                                running: root.playing && root.presentation === "full"
                            }
                        }
                    }

                    // Front Floating Album Artwork Card
                    Rectangle {
                        id: frontArtworkCard
                        width: 190
                        height: 190
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        radius: 18
                        color: Nexa.Theme.surfaceContainerHigh
                        border.width: 1
                        border.color: Qt.rgba(255, 255, 255, 0.12)
                        clip: true
                        z: 2
                        scale: root.playing ? 1.015 : 1.0

                        Behavior on scale {
                            NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
                        }

                        Image {
                            anchors.fill: parent
                            source: root.artwork
                            fillMode: Image.PreserveAspectCrop
                            visible: root.artwork !== ""
                        }

                        // Fallback when artwork is empty
                        Rectangle {
                            anchors.fill: parent
                            visible: root.artwork === ""
                            color: "#14161f"

                            Column {
                                anchors.centerIn: parent
                                spacing: 8

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: root.playerIcon(root.identity)
                                    color: root.playerBrandColor(root.identity)
                                    font.family: Nexa.Theme.iconFontFamily
                                    font.pixelSize: 48
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: root.identity
                                    color: Nexa.Theme.mutedText
                                    font.family: Nexa.Theme.fontFamily
                                    font.pixelSize: 12
                                    font.weight: Nexa.Theme.fontWeightMedium
                                }
                            }
                        }

                        // Glass sheen line
                        Rectangle {
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 1
                            color: Qt.rgba(255, 255, 255, 0.20)
                        }
                    }
                }

                // ====================================================
                // RIGHT: METADATA, SCRUBBER, HERO CONTROLS & SPECTRUM
                // ====================================================
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 8

                    // Header Status & Source Row
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        // Source App Pill
                        Rectangle {
                            implicitWidth: sourcePillRow.implicitWidth + 18
                            implicitHeight: 26
                            radius: 13
                            color: Qt.rgba(255/255, 255/255, 255/255, 0.06)
                            border.width: 1
                            border.color: Qt.rgba(255/255, 255/255, 255/255, 0.10)

                            Row {
                                id: sourcePillRow
                                anchors.centerIn: parent
                                spacing: 6

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: root.playerIcon(root.identity)
                                    color: root.playerBrandColor(root.identity)
                                    font.family: Nexa.Theme.iconFontFamily
                                    font.pixelSize: 14
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: root.identity
                                    color: Nexa.Theme.text
                                    font.family: Nexa.Theme.fontFamily
                                    font.pixelSize: 11
                                    font.weight: Nexa.Theme.fontWeightBold
                                }
                            }
                        }

                        // Live Status Pill (Playing / Paused)
                        Rectangle {
                            implicitWidth: statusPillRow.implicitWidth + 16
                            implicitHeight: 24
                            radius: 12
                            color: root.playing
                                ? Qt.rgba(16/255, 185/255, 129/255, 0.15)
                                : Qt.rgba(245/255, 158/255, 11/255, 0.15)
                            border.width: 1
                            border.color: root.playing
                                ? Qt.rgba(16/255, 185/255, 129/255, 0.35)
                                : Qt.rgba(245/255, 158/255, 11/255, 0.35)

                            Row {
                                id: statusPillRow
                                anchors.centerIn: parent
                                spacing: 5

                                Rectangle {
                                    width: 6; height: 6; radius: 3
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: root.playing ? "#10b981" : "#f59e0b"

                                    SequentialAnimation on opacity {
                                        loops: Animation.Infinite
                                        running: root.playing
                                        NumberAnimation { from: 0.4; to: 1.0; duration: 800 }
                                        NumberAnimation { from: 1.0; to: 0.4; duration: 800 }
                                    }
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: root.playing ? "PLAYING" : "PAUSED"
                                    color: root.playing ? "#34d399" : "#fbbf24"
                                    font.family: Nexa.Theme.fontFamily
                                    font.pixelSize: 10
                                    font.weight: Nexa.Theme.fontWeightBold
                                    font.letterSpacing: 0.8
                                }
                            }
                        }

                        Item { Layout.fillWidth: true }

                        // Quality Badge
                        Rectangle {
                            implicitWidth: 70
                            implicitHeight: 22
                            radius: 11
                            color: Qt.rgba(255/255, 255/255, 255/255, 0.04)
                            border.width: 1
                            border.color: Qt.rgba(255/255, 255/255, 255/255, 0.07)

                            Text {
                                anchors.centerIn: parent
                                text: "Hi-Fi Stereo"
                                color: Nexa.Theme.mutedText
                                font.family: Nexa.Theme.fontFamily
                                font.pixelSize: 10
                                font.weight: Nexa.Theme.fontWeightMedium
                            }
                        }
                    }

                    // Sliding Marquee Track Title Box
                    Item {
                        id: fullTitleBox
                        Layout.fillWidth: true
                        implicitHeight: fullTitleText.implicitHeight
                        clip: true

                        readonly property real overflowDist: Math.max(0, fullTitleText.implicitWidth - width)
                        readonly property bool needsScroll: overflowDist > 6

                        Text {
                            id: fullTitleText
                            x: 0
                            text: root.title
                            color: Nexa.Theme.text
                            font.family: Nexa.Theme.fontFamily
                            font.pixelSize: 22
                            font.weight: Nexa.Theme.fontWeightBold
                        }

                        SequentialAnimation {
                            id: fullTitleAnim
                            running: fullTitleBox.needsScroll
                            loops: Animation.Infinite

                            PauseAnimation { duration: 2200 }
                            NumberAnimation {
                                target: fullTitleText
                                property: "x"
                                from: 0
                                to: -fullTitleBox.overflowDist - 20
                                duration: Math.max(1600, (fullTitleBox.overflowDist + 20) * 32)
                                easing.type: Easing.InOutQuad
                            }
                            PauseAnimation { duration: 1800 }
                            NumberAnimation {
                                target: fullTitleText
                                property: "x"
                                to: 0
                                duration: Math.max(1200, (fullTitleBox.overflowDist + 20) * 22)
                                easing.type: Easing.InOutQuad
                            }
                        }

                        onWidthChanged: {
                            fullTitleText.x = 0
                            if (needsScroll) fullTitleAnim.restart()
                            else fullTitleAnim.stop()
                        }

                        Connections {
                            target: root
                            function onTitleChanged() {
                                fullTitleText.x = 0
                                if (fullTitleBox.needsScroll) fullTitleAnim.restart()
                                else fullTitleAnim.stop()
                            }
                        }
                    }

                    // Artist & Album
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Text {
                            text: root.artist
                            color: Nexa.Theme.primary
                            font.family: Nexa.Theme.fontFamily
                            font.pixelSize: 14
                            font.weight: Nexa.Theme.fontWeightSemiBold
                            elide: Text.ElideRight
                        }

                        Text {
                            visible: root.album !== ""
                            text: "•"
                            color: Qt.rgba(255/255, 255/255, 255/255, 0.25)
                            font.pixelSize: 14
                        }

                        Text {
                            visible: root.album !== ""
                            Layout.fillWidth: true
                            text: root.album
                            color: Nexa.Theme.mutedText
                            font.family: Nexa.Theme.fontFamily
                            font.pixelSize: 13
                            elide: Text.ElideRight
                        }
                    }

                    // ----------------------------------------------------
                    // Modern Progress Capsule Scrubber
                    // ----------------------------------------------------
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Rectangle {
                            id: seekArea
                            Layout.fillWidth: true
                            Layout.preferredHeight: 16
                            color: "transparent"

                            Rectangle {
                                id: seekTrack
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                height: seekMouse.containsMouse || root.seeking ? 6 : 4
                                radius: height / 2
                                color: Qt.rgba(255/255, 255/255, 255/255, 0.10)

                                Behavior on height {
                                    NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
                                }

                                // Gradient progress fill
                                Rectangle {
                                    width: parent.width * root.displayedProgress
                                    height: parent.height
                                    radius: parent.radius
                                    gradient: Gradient {
                                        orientation: Gradient.Horizontal
                                        GradientStop { position: 0.0; color: Nexa.Theme.primary }
                                        GradientStop { position: 1.0; color: Nexa.Theme.tertiary }
                                    }
                                }

                                // Glowing playhead thumb
                                Rectangle {
                                    id: scrubThumb
                                    width: seekMouse.containsMouse || root.seeking ? 14 : 10
                                    height: width
                                    radius: width / 2
                                    anchors.verticalCenter: parent.verticalCenter
                                    x: Math.max(0, Math.min(parent.width - width, (parent.width * root.displayedProgress) - width / 2))
                                    color: "#ffffff"
                                    border.width: 2
                                    border.color: Nexa.Theme.primary

                                    Behavior on width {
                                        NumberAnimation { duration: 150; easing.type: Easing.OutBack }
                                    }
                                }
                            }

                            MouseArea {
                                id: seekMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: root.available && root.player.canSeek && root.player.positionSupported && root.duration > 0
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor

                                onPressed: mouse => {
                                    root.seeking = true
                                    root.updateSeekFromX(mouse.x, width)
                                }
                                onPositionChanged: mouse => {
                                    if (pressed) root.updateSeekFromX(mouse.x, width)
                                }
                                onReleased: mouse => {
                                    root.updateSeekFromX(mouse.x, width)
                                    root.commitSeek()
                                }
                            }
                        }

                        // Monospace Timestamps
                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                text: root.formatTime(root.displayedPosition)
                                color: Nexa.Theme.mutedText
                                font.family: Nexa.Theme.monoFontFamily
                                font.pixelSize: 11
                            }

                            Item { Layout.fillWidth: true }

                            Text {
                                text: root.formatTime(root.duration)
                                color: Nexa.Theme.mutedText
                                font.family: Nexa.Theme.monoFontFamily
                                font.pixelSize: 11
                            }
                        }
                    }

                    // ----------------------------------------------------
                    // Playback Controls Deck & Volume Bar
                    // ----------------------------------------------------
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        // Shuffle Button
                        Rectangle {
                            implicitWidth: 36
                            implicitHeight: 36
                            radius: 18
                            color: shufMouse.containsMouse ? Qt.rgba(255/255, 255/255, 255/255, 0.10) : Qt.rgba(255/255, 255/255, 255/255, 0.04)
                            border.width: 1
                            border.color: (root.available && root.player.shuffle === true) ? Nexa.Theme.primary : Qt.rgba(255/255, 255/255, 255/255, 0.08)

                            Text {
                                anchors.centerIn: parent
                                text: "󰒞"
                                color: (root.available && root.player.shuffle === true) ? Nexa.Theme.primary : Nexa.Theme.mutedText
                                font.family: Nexa.Theme.iconFontFamily
                                font.pixelSize: 16
                            }

                            MouseArea {
                                id: shufMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.toggleShuffle()
                            }
                        }

                        // Previous Track
                        Rectangle {
                            implicitWidth: 36
                            implicitHeight: 36
                            radius: 18
                            color: prevMouse.containsMouse ? Qt.rgba(255/255, 255/255, 255/255, 0.10) : Qt.rgba(255/255, 255/255, 255/255, 0.04)
                            border.width: 1
                            border.color: Qt.rgba(255/255, 255/255, 255/255, 0.08)
                            scale: prevMouse.pressed ? 0.92 : 1.0

                            Behavior on scale { NumberAnimation { duration: 100 } }

                            Text {
                                anchors.centerIn: parent
                                text: "󰒮"
                                color: Nexa.Theme.text
                                font.family: Nexa.Theme.iconFontFamily
                                font.pixelSize: 16
                            }

                            MouseArea {
                                id: prevMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.previous()
                            }
                        }

                        // HERO Play / Pause Button
                        Rectangle {
                            id: heroPlayBtn
                            implicitWidth: 48
                            implicitHeight: 48
                            radius: 24
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: playMouse.pressed ? Nexa.Theme.primaryDark : Nexa.Theme.primary }
                                GradientStop { position: 1.0; color: Nexa.Theme.primaryDark }
                            }
                            scale: playMouse.pressed ? 0.92 : playMouse.containsMouse ? 1.06 : 1.0

                            Behavior on scale {
                                NumberAnimation { duration: 150; easing.type: Easing.OutBack }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: root.playing ? "󰏤" : "󰐊"
                                color: Nexa.Theme.onPrimary
                                font.family: Nexa.Theme.iconFontFamily
                                font.pixelSize: 22
                            }

                            MouseArea {
                                id: playMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.togglePlaying()
                            }
                        }

                        // Next Track
                        Rectangle {
                            implicitWidth: 36
                            implicitHeight: 36
                            radius: 18
                            color: nextMouse.containsMouse ? Qt.rgba(255/255, 255/255, 255/255, 0.10) : Qt.rgba(255/255, 255/255, 255/255, 0.04)
                            border.width: 1
                            border.color: Qt.rgba(255/255, 255/255, 255/255, 0.08)
                            scale: nextMouse.pressed ? 0.92 : 1.0

                            Behavior on scale { NumberAnimation { duration: 100 } }

                            Text {
                                anchors.centerIn: parent
                                text: "󰒭"
                                color: Nexa.Theme.text
                                font.family: Nexa.Theme.iconFontFamily
                                font.pixelSize: 16
                            }

                            MouseArea {
                                id: nextMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.next()
                            }
                        }

                        // Loop Button
                        Rectangle {
                            implicitWidth: 36
                            implicitHeight: 36
                            radius: 18
                            color: loopMouse.containsMouse ? Qt.rgba(255/255, 255/255, 255/255, 0.10) : Qt.rgba(255/255, 255/255, 255/255, 0.04)
                            border.width: 1
                            border.color: (root.available && root.player.loopStatus !== MprisLoopStatus.None) ? Nexa.Theme.primary : Qt.rgba(255/255, 255/255, 255/255, 0.08)

                            Text {
                                anchors.centerIn: parent
                                text: root.available && root.player.loopStatus === MprisLoopStatus.Track ? "󰑘" : "󰑖"
                                color: (root.available && root.player.loopStatus !== MprisLoopStatus.None) ? Nexa.Theme.primary : Nexa.Theme.mutedText
                                font.family: Nexa.Theme.iconFontFamily
                                font.pixelSize: 16
                            }

                            MouseArea {
                                id: loopMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.toggleLoop()
                            }
                        }

                        Item { Layout.fillWidth: true }

                        // ------------------------------------------------
                        // INLINE VOLUME CONTROL DECK
                        // ------------------------------------------------
                        RowLayout {
                            spacing: 8

                            // Mute/Unmute Icon
                            Rectangle {
                                implicitWidth: 28
                                implicitHeight: 28
                                radius: 14
                                color: "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: root.sinkMuted || root.sinkVolume === 0
                                        ? "󰝟"
                                        : root.sinkVolume > 0.5 ? "󰕾" : "󰖀"
                                    color: root.sinkMuted ? "#ef4444" : Nexa.Theme.mutedText
                                    font.family: Nexa.Theme.iconFontFamily
                                    font.pixelSize: 15
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.toggleSinkMute()
                                }
                            }

                            // Volume Drag Capsule
                            Rectangle {
                                id: volBarTrack
                                Layout.preferredWidth: 70
                                Layout.preferredHeight: 5
                                radius: 2.5
                                color: Qt.rgba(255/255, 255/255, 255/255, 0.12)

                                Rectangle {
                                    width: parent.width * (root.sinkMuted ? 0 : root.sinkVolume)
                                    height: parent.height
                                    radius: parent.radius
                                    color: root.sinkMuted ? "#ef4444" : Nexa.Theme.primary
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -4
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor

                                    onPressed: mouse => {
                                        const ratio = Math.max(0, Math.min(1, mouse.x / width))
                                        root.setSinkVolume(ratio)
                                    }
                                    onPositionChanged: mouse => {
                                        if (pressed) {
                                            const ratio = Math.max(0, Math.min(1, mouse.x / width))
                                            root.setSinkVolume(ratio)
                                        }
                                    }
                                }
                            }

                            Text {
                                text: Math.round((root.sinkMuted ? 0 : root.sinkVolume) * 100) + "%"
                                color: Nexa.Theme.mutedText
                                font.family: Nexa.Theme.monoFontFamily
                                font.pixelSize: 11
                            }
                        }
                    }

                    // ----------------------------------------------------
                    // 64-Band Equalizer Spectrum Visualizer
                    // ----------------------------------------------------
                    Rectangle {
                        id: spectrumArea
                        Layout.fillWidth: true
                        Layout.preferredHeight: 28
                        radius: Nexa.Theme.radiusSm
                        color: "transparent"
                        clip: true

                        Row {
                            id: spectrumBars
                            anchors.fill: parent
                            anchors.leftMargin: 2
                            anchors.rightMargin: 2
                            anchors.bottomMargin: 2
                            spacing: 2

                            Repeater {
                                model: 48
                                delegate: Item {
                                    id: barSlot
                                    required property int index

                                    width: Math.max(1.5, (spectrumBars.width - spectrumBars.spacing * 47) / 48)
                                    height: spectrumBars.height

                                    readonly property real rawTargetLevel: {
                                        if (!root.playing) return 0.0
                                        if (root.spectrumBins && index < root.spectrumBins.length) {
                                            return Number(root.spectrumBins[index]) || 0.0
                                        }
                                        return 0.0
                                    }

                                    property real visualLevel: rawTargetLevel

                                    Behavior on visualLevel {
                                        NumberAnimation { duration: 40; easing.type: Easing.OutQuad }
                                    }

                                    Rectangle {
                                        anchors.bottom: parent.bottom
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        width: parent.width
                                        height: Math.max(2, parent.height * barSlot.visualLevel)
                                        radius: 1

                                        color: {
                                            const ratio = barSlot.index / 47.0
                                            return Qt.rgba(
                                                Nexa.Theme.primary.r + (Nexa.Theme.tertiary.r - Nexa.Theme.primary.r) * ratio,
                                                Nexa.Theme.primary.g + (Nexa.Theme.tertiary.g - Nexa.Theme.primary.g) * ratio,
                                                Nexa.Theme.primary.b + (Nexa.Theme.tertiary.b - Nexa.Theme.primary.b) * ratio,
                                                0.35 + barSlot.visualLevel * 0.65
                                            )
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
