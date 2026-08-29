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

    readonly property var player:
        Mpris.players.values.length > 0
        ? Mpris.players.values[0]
        : null

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

            // Animated 3-Bar Equalizer
            Row {
                spacing: 2
                Layout.alignment: Qt.AlignVCenter
                visible: root.hasTrack

                Repeater {
                    model: 3
                    delegate: Rectangle {
                        id: eqBar
                        required property int index
                        width: 3
                        height: root.playing ? 6 : 3
                        radius: 1.5
                        color: Nexa.Theme.primary

                        SequentialAnimation on height {
                            running: root.playing
                            loops: Animation.Infinite
                            NumberAnimation {
                                to: index === 0 ? 12 : (index === 1 ? 16 : 9)
                                duration: index === 0 ? 320 : (index === 1 ? 420 : 360)
                                easing.type: Easing.InOutSine
                            }
                            NumberAnimation {
                                to: index === 0 ? 4 : (index === 1 ? 3 : 5)
                                duration: index === 0 ? 280 : (index === 1 ? 380 : 310)
                                easing.type: Easing.InOutSine
                            }
                        }
                    }
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
    // FULL MUSIC VIEW
    // ============================================================

    Item {
        anchors.fill: parent
        visible: root.presentation === "full"

        // Ambient Album Artwork Backdrop
        Rectangle {
            anchors.fill: parent
            radius: Nexa.Theme.radiusLg
            color: Nexa.Theme.surfaceContainerLow
            clip: true
            z: -1

            Image {
                anchors.fill: parent
                source: root.artwork
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                opacity: root.artwork !== "" ? 0.30 : 0.0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Nexa.Theme.animationNormal
                        easing.type: Easing.OutCubic
                    }
                }
            }

            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(
                    Nexa.Theme.surfaceContainerLow.r,
                    Nexa.Theme.surfaceContainerLow.g,
                    Nexa.Theme.surfaceContainerLow.b,
                    0.88
                )
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: Nexa.Theme.spacingMd
            spacing: Nexa.Theme.spacingXl

            // ====================================================
            // LEFT: LARGE ALBUM ARTWORK CARD
            // ====================================================

            Rectangle {
                Layout.preferredWidth: 200
                Layout.preferredHeight: 200
                Layout.alignment: Qt.AlignVCenter
                radius: 16
                color: Nexa.Theme.surfaceContainerHigh
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.08)
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
                    font.pixelSize: 56
                }
            }

            // ====================================================
            // RIGHT: TRACK INFO, CONTROLS & SLEEK SPECTRUM
            // ====================================================

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 8

                // Top Source Player Badge
                RowLayout {
                    Layout.fillWidth: true

                    Rectangle {
                        implicitWidth: sourceRow.implicitWidth + 16
                        implicitHeight: 24
                        radius: 12
                        color: Nexa.Theme.surfaceContainerHigh
                        border.width: 1
                        border.color: Nexa.Theme.border

                        Row {
                            id: sourceRow
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.playerIcon(root.identity)
                                color: Nexa.Theme.primary
                                font.family: Nexa.Theme.iconFontFamily
                                font.pixelSize: Nexa.Theme.iconSm
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.identity
                                color: Nexa.Theme.mutedText
                                font.family: Nexa.Theme.fontFamily
                                font.pixelSize: Nexa.Theme.fontSize2Xs
                                font.weight: Nexa.Theme.fontWeightMedium
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }
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
                Text {
                    Layout.fillWidth: true
                    text: root.album !== "" ? root.artist + "  •  " + root.album : root.artist
                    elide: Text.ElideRight
                    color: Nexa.Theme.mutedText
                    font.family: Nexa.Theme.fontFamily
                    font.pixelSize: Nexa.Theme.fontSizeMd
                    font.weight: Nexa.Theme.fontWeightMedium
                }

                // Seekbar & Timestamps
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Rectangle {
                        id: seekArea
                        Layout.fillWidth: true
                        Layout.preferredHeight: 18
                        color: "transparent"

                        Rectangle {
                            id: seekTrack
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            height: 4
                            radius: 2
                            color: Nexa.Theme.surfaceContainerHighest

                            Rectangle {
                                width: parent.width * root.displayedProgress
                                height: parent.height
                                radius: parent.radius
                                color: Nexa.Theme.primary
                            }

                            // Scrub thumb
                            Rectangle {
                                width: 12
                                height: 12
                                radius: 6
                                anchors.verticalCenter: parent.verticalCenter
                                x: Math.max(0, Math.min(parent.width - width, (parent.width * root.displayedProgress) - width / 2))
                                color: Nexa.Theme.primary
                                visible: seekMouse.containsMouse || root.seeking
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

                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            text: root.formatTime(root.displayedPosition)
                            color: Nexa.Theme.mutedText
                            font.family: Nexa.Theme.monoFontFamily
                            font.pixelSize: Nexa.Theme.fontSizeXs
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: root.formatTime(root.duration)
                            color: Nexa.Theme.mutedText
                            font.family: Nexa.Theme.monoFontFamily
                            font.pixelSize: Nexa.Theme.fontSizeXs
                        }
                    }
                }

                // Playback Controls Deck
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: Nexa.Theme.spacingLg

                    // Shuffle
                    NexaUI.NexaIconButton {
                        icon: "󰒞"
                        selected: root.available && root.player.shuffle === true
                        interactive: root.available && root.player.canShuffle
                        onClicked: root.toggleShuffle()
                    }

                    // Previous
                    NexaUI.NexaIconButton {
                        icon: "󰒮"
                        interactive: root.available && root.player.canGoPrevious
                        onClicked: root.previous()
                    }

                    // HERO Play / Pause Button
                    Rectangle {
                        implicitWidth: 46
                        implicitHeight: 46
                        radius: 23
                        color: playMouse.pressed ? Nexa.Theme.primaryDark : Nexa.Theme.primary
                        scale: playMouse.containsMouse ? 1.05 : 1.0

                        Behavior on scale {
                            NumberAnimation { duration: Nexa.Theme.animationFast }
                        }
                        Behavior on color {
                            ColorAnimation { duration: Nexa.Theme.animationFast }
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

                    // Next
                    NexaUI.NexaIconButton {
                        icon: "󰒭"
                        interactive: root.available && root.player.canGoNext
                        onClicked: root.next()
                    }

                    // Loop / Repeat
                    NexaUI.NexaIconButton {
                        icon: root.available && root.player.loopStatus === MprisLoopStatus.Track ? "󰑘" : "󰑖"
                        selected: root.available && root.player.loopStatus !== MprisLoopStatus.None
                        interactive: root.available && root.player.canLoop
                        onClicked: root.toggleLoop()
                    }
                }

                // ========================================================
                // SLEEK, MODERN AUDIO EQUALIZER SPECTRUM
                // ========================================================

                Rectangle {
                    id: spectrumArea
                    Layout.fillWidth: true
                    Layout.preferredHeight: 38
                    radius: Nexa.Theme.radiusSm
                    color: "transparent"
                    clip: true

                    Row {
                        id: spectrumBars
                        anchors.fill: parent
                        anchors.leftMargin: 6
                        anchors.rightMargin: 6
                        anchors.bottomMargin: 4
                        spacing: 2

                        Repeater {
                            model: 64
                            delegate: Item {
                                id: barSlot
                                required property int index

                                width: Math.max(1.5, (spectrumBars.width - spectrumBars.spacing * 63) / 64)
                                height: spectrumBars.height

                                readonly property real rawTargetLevel: {
                                    if (!root.spectrumBins || index >= root.spectrumBins.length || !root.playing) return 0.0
                                    return Number(root.spectrumBins[index]) || 0.0
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

                                    // Luminous Gradient Fill across 64 note bands
                                    color: {
                                        const ratio = barSlot.index / 63.0
                                        return Qt.rgba(
                                            Nexa.Theme.primary.r + (Nexa.Theme.tertiary.r - Nexa.Theme.primary.r) * ratio,
                                            Nexa.Theme.primary.g + (Nexa.Theme.tertiary.g - Nexa.Theme.primary.g) * ratio,
                                            Nexa.Theme.primary.b + (Nexa.Theme.tertiary.b - Nexa.Theme.primary.b) * ratio,
                                            0.45 + barSlot.visualLevel * 0.55
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
