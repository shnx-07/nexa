import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects

import Quickshell.Services.Mpris
import Quickshell.Io
import Quickshell

import "../../theme" as Nexa
import "../../theme/components" as NexaUI


Item {
    id: root

    // ============================================================
    // RESPONSIBILITY
    //
    // Apple-Minimal Dynamic Island Media Deck:
    // - High-DPI crystal-clear album art rendering (mipmap + explicit sourceSize)
    // - Zero lag: No CAVA processes, no heavy FBO re-rasterization during resize
    // - 100% true circular masked thumbnail in compact notch
    // - Spacious Apple Music aesthetic with smooth fade transitions
    // - Zero duplicate waveforms (handled by dedicated TopBar WaveformPill)
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
    // 1. COMPACT PRESENTATION (Dynamic Island Notch)
    // ============================================================

    Item {
        anchors.fill: parent
        visible: root.presentation === "compact"

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 12
            spacing: 8

            // True Circular Cropped Album Art Avatar (Pin-Sharp)
            Item {
                Layout.preferredWidth: 22
                Layout.preferredHeight: 22
                Layout.alignment: Qt.AlignVCenter

                Rectangle {
                    id: compactMask
                    anchors.fill: parent
                    radius: width / 2
                    visible: false
                }

                Image {
                    id: compactImg
                    anchors.fill: parent
                    source: root.artwork
                    fillMode: Image.PreserveAspectCrop
                    visible: false
                    asynchronous: true
                    mipmap: true
                    sourceSize: Qt.size(64, 64)
                    smooth: true
                }

                OpacityMask {
                    anchors.fill: parent
                    source: compactImg
                    maskSource: compactMask
                    visible: root.artwork !== ""
                }

                // Fallback circular badge
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    visible: root.artwork === ""
                    color: Nexa.Theme.surfaceContainerHigh
                    border.width: 1
                    border.color: Nexa.Theme.border

                    Text {
                        anchors.centerIn: parent
                        text: root.playerIcon(root.identity)
                        color: Nexa.Theme.primary
                        font.family: Nexa.Theme.iconFontFamily
                        font.pixelSize: 11
                    }
                }

                // Clean circular border ring
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: "transparent"
                    border.width: 1
                    border.color: Qt.rgba(255, 255, 255, 0.20)
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
                    running: compactMarqueeBox.needsScroll && root.presentation === "compact" && root.visible
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
    // 2. HOVER PRESENTATION (Dynamic Island Expansion)
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
                Layout.preferredWidth: 44
                Layout.preferredHeight: 44
                radius: Nexa.Theme.radiusSm
                color: Nexa.Theme.surfaceContainerHigh
                border.width: 1
                border.color: Nexa.Theme.border
                clip: true

                Image {
                    anchors.fill: parent
                    source: root.artwork
                    fillMode: Image.PreserveAspectCrop
                    mipmap: true
                    sourceSize: Qt.size(128, 128)
                    smooth: true
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
                            running: hoverTitleBox.needsScroll && root.presentation === "hover" && root.visible
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

            // Minimal Playback Controls
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
    // 3. FULL MUSIC VIEW (APPLE-MINIMAL CARD)
    // ============================================================

    Item {
        id: fullMusicContainer
        anchors.fill: parent
        visible: root.presentation === "full"

        // Smooth opacity fade on appearance for butter-smooth opening
        opacity: visible ? 1.0 : 0.0
        Behavior on opacity {
            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
        }

        // --------------------------------------------------------
        // Ambient Backdrop & Specular Rim (Hardware-Optimized)
        // --------------------------------------------------------
        Rectangle {
            anchors.fill: parent
            radius: Nexa.Theme.radiusLg
            color: Nexa.Theme.surfaceContainerLow
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.09)
            clip: true
            z: -1

            // Soft ambient glow using downsampled 120x120 texture (0ms resize overhead)
            Image {
                id: bgAmbientArt
                anchors.fill: parent
                anchors.margins: -20
                source: root.artwork
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                sourceSize: Qt.size(120, 120)
                smooth: true
                opacity: (root.hasTrack && root.artwork !== "") ? 0.25 : 0.0

                Behavior on opacity {
                    NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
                }
            }

            // High-tech frosted glass vignette
            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(
                    Nexa.Theme.surfaceContainerLow.r,
                    Nexa.Theme.surfaceContainerLow.g,
                    Nexa.Theme.surfaceContainerLow.b,
                    0.91
                )
            }

            // Top specular edge highlight
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 1
                color: Qt.rgba(1, 1, 1, 0.16)
            }
        }

        // --------------------------------------------------------
        // Idle State: When No Active Media is Playing
        // --------------------------------------------------------
        Item {
            anchors.fill: parent
            visible: !root.hasTrack || (!root.playing && !root.paused)

            RowLayout {
                anchors.centerIn: parent
                spacing: 36

                Item {
                    width: 140
                    height: 140
                    Layout.alignment: Qt.AlignVCenter

                    Rectangle {
                        anchors.fill: parent
                        radius: 70
                        color: Nexa.Theme.surfaceContainerHigh
                        border.width: 1
                        border.color: Nexa.Theme.border

                        Text {
                            anchors.centerIn: parent
                            text: "󰎆"
                            color: Nexa.Theme.primary
                            font.family: Nexa.Theme.iconFontFamily
                            font.pixelSize: 42
                        }
                    }

                    SequentialAnimation on scale {
                        loops: Animation.Infinite
                        running: fullMusicContainer.visible && (!root.hasTrack || (!root.playing && !root.paused))
                        NumberAnimation { from: 0.98; to: 1.02; duration: 2400; easing.type: Easing.InOutSine }
                        NumberAnimation { from: 1.02; to: 0.98; duration: 2400; easing.type: Easing.InOutSine }
                    }
                }

                ColumnLayout {
                    spacing: 8
                    Layout.alignment: Qt.AlignVCenter

                    Rectangle {
                        implicitWidth: idleStatusRow.implicitWidth + 18
                        implicitHeight: 24
                        radius: 12
                        color: Nexa.Theme.surfaceContainerLow
                        border.width: 1
                        border.color: Nexa.Theme.border

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
                        text: "Play music or video on Spotify, YouTube, or MPV\nto unlock live controls in the Dynamic Island."
                        color: Nexa.Theme.mutedText
                        font.family: Nexa.Theme.fontFamily
                        font.pixelSize: 13
                        lineHeight: 1.3
                    }
                }
            }
        }

        // --------------------------------------------------------
        // Active State: Clean Apple-Minimal Player Deck
        // --------------------------------------------------------
        Item {
            anchors.fill: parent
            visible: root.hasTrack && (root.playing || root.paused)

            RowLayout {
                anchors.fill: parent
                anchors.margins: 24
                spacing: 28

                // ====================================================
                // LEFT: LARGE ULTRA-CRISP APPLE ALBUM ART CARD
                // ====================================================
                Item {
                    Layout.preferredWidth: 175
                    Layout.preferredHeight: 175
                    Layout.alignment: Qt.AlignVCenter

                    // Soft ambient drop-shadow glow behind card
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: -4
                        radius: 22
                        color: Qt.rgba(Nexa.Theme.primary.r, Nexa.Theme.primary.g, Nexa.Theme.primary.b, 0.18)
                        opacity: root.playing ? 0.65 : 0.2
                        Behavior on opacity { NumberAnimation { duration: 400 } }
                    }

                    // Native Rounded Artwork Container (Crystal-Sharp Mipmaps, 0% FBO overhead)
                    Rectangle {
                        id: frontArtworkCard
                        anchors.fill: parent
                        radius: 18
                        color: Nexa.Theme.surfaceContainerHigh
                        border.width: 1
                        border.color: Qt.rgba(255, 255, 255, 0.16)
                        clip: true

                        Image {
                            id: mainArtworkImage
                            anchors.fill: parent
                            source: root.artwork
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                            mipmap: true
                            sourceSize: Qt.size(600, 600)
                            smooth: true
                            visible: root.artwork !== ""
                        }

                        // Fallback when artwork is empty
                        Rectangle {
                            anchors.fill: parent
                            visible: root.artwork === ""
                            color: Nexa.Theme.surfaceContainer

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

                        // Glass specular sheen highlight line
                        Rectangle {
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            height: 1
                            color: Qt.rgba(255, 255, 255, 0.25)
                        }
                    }
                }

                // ====================================================
                // RIGHT: METADATA, SCRUBBER & HERO CONTROLS
                // ====================================================
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 12

                    // 1. Header Badges: Source App & Status
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        // Source App Pill
                        Rectangle {
                            implicitWidth: sourcePillRow.implicitWidth + 18
                            implicitHeight: 26
                            radius: 13
                            color: Qt.rgba(255/255, 255/255, 255/255, 0.07)
                            border.width: 1
                            border.color: Qt.rgba(255/255, 255/255, 255/255, 0.12)

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

                        // Status Pill
                        Rectangle {
                            implicitWidth: statusPillRow.implicitWidth + 16
                            implicitHeight: 24
                            radius: 12
                            color: root.playing
                                ? Qt.rgba(Nexa.Theme.success.r, Nexa.Theme.success.g, Nexa.Theme.success.b, 0.18)
                                : Qt.rgba(Nexa.Theme.warning.r, Nexa.Theme.warning.g, Nexa.Theme.warning.b, 0.18)
                            border.width: 1
                            border.color: root.playing
                                ? Qt.rgba(Nexa.Theme.success.r, Nexa.Theme.success.g, Nexa.Theme.success.b, 0.40)
                                : Qt.rgba(Nexa.Theme.warning.r, Nexa.Theme.warning.g, Nexa.Theme.warning.b, 0.40)

                            Row {
                                id: statusPillRow
                                anchors.centerIn: parent
                                spacing: 5

                                Rectangle {
                                    width: 6; height: 6; radius: 3
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: root.playing ? Nexa.Theme.success : Nexa.Theme.warning

                                    SequentialAnimation on opacity {
                                        loops: Animation.Infinite
                                        running: root.playing && root.presentation === "full" && root.visible
                                        NumberAnimation { from: 0.4; to: 1.0; duration: 800 }
                                        NumberAnimation { from: 1.0; to: 0.4; duration: 800 }
                                    }
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: root.playing ? "PLAYING" : "PAUSED"
                                    color: root.playing ? Nexa.Theme.success : Nexa.Theme.warning
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
                            implicitWidth: 72
                            implicitHeight: 22
                            radius: 11
                            color: Nexa.Theme.surfaceContainerLow
                            border.width: 1
                            border.color: Nexa.Theme.border

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

                    // 2. Track Title Box (Apple Bold)
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
                            running: fullTitleBox.needsScroll && root.presentation === "full" && root.visible
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

                    // 3. Artist & Album Subtitle
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Text {
                            text: root.artist
                            color: Nexa.Theme.primary
                            font.family: Nexa.Theme.fontFamily
                            font.pixelSize: 15
                            font.weight: Nexa.Theme.fontWeightDemiBold
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
                            font.pixelSize: 14
                            elide: Text.ElideRight
                        }
                    }

                    // 4. Apple-Style Progress Scrubber
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 5

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
                                height: seekMouse.containsMouse || root.seeking ? 6 : 4
                                radius: height / 2
                                color: Qt.rgba(255/255, 255/255, 255/255, 0.12)

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
                                        GradientStop { position: 1.0; color: Nexa.Theme.secondary }
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
                                    color: Nexa.Theme.onPrimary
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

                    // 5. Minimal Apple Hero Controls (Prev, Hero Play/Pause, Next)
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 28

                        Item { Layout.fillWidth: true }

                        // Previous Track
                        Rectangle {
                            implicitWidth: 44
                            implicitHeight: 44
                            radius: 22
                            color: prevMouse.containsMouse ? Nexa.Theme.hoverStrong : Nexa.Theme.surfaceContainerHigh
                            border.width: 1
                            border.color: Nexa.Theme.border
                            scale: prevMouse.pressed ? 0.90 : 1.0

                            Behavior on scale { NumberAnimation { duration: 100 } }

                            Text {
                                anchors.centerIn: parent
                                text: "󰒮"
                                color: Nexa.Theme.text
                                font.family: Nexa.Theme.iconFontFamily
                                font.pixelSize: 19
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
                            implicitWidth: 58
                            implicitHeight: 58
                            radius: 29
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: playMouse.pressed ? Qt.darker(Nexa.Theme.primary, 1.25) : Nexa.Theme.primary }
                                GradientStop { position: 1.0; color: Qt.darker(Nexa.Theme.primary, 1.20) }
                            }
                            scale: playMouse.pressed ? 0.90 : playMouse.containsMouse ? 1.06 : 1.0

                            Behavior on scale {
                                NumberAnimation { duration: 150; easing.type: Easing.OutBack }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: root.playing ? "󰏤" : "󰐊"
                                color: Nexa.Theme.onPrimary
                                font.family: Nexa.Theme.iconFontFamily
                                font.pixelSize: 26
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
                            implicitWidth: 44
                            implicitHeight: 44
                            radius: 22
                            color: nextMouse.containsMouse ? Nexa.Theme.hoverStrong : Nexa.Theme.surfaceContainerHigh
                            border.width: 1
                            border.color: Nexa.Theme.border
                            scale: nextMouse.pressed ? 0.90 : 1.0

                            Behavior on scale { NumberAnimation { duration: 100 } }

                            Text {
                                anchors.centerIn: parent
                                text: "󰒭"
                                color: Nexa.Theme.text
                                font.family: Nexa.Theme.iconFontFamily
                                font.pixelSize: 19
                            }

                            MouseArea {
                                id: nextMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.next()
                            }
                        }

                        Item { Layout.fillWidth: true }
                    }
                }
            }
        }
    }
}
