import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQml.Models
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
    // COMPACT CLOCK
    // ============================================================

    property date currentTime: new Date()

    Timer {
        id: compactClockTimer
        interval: 1000
        running: root.presentation === "compact" && root.visible
        repeat: true
        onTriggered: root.currentTime = new Date()
    }

    // ============================================================
    // MPRIS PLAYER - UNIVERSAL MULTI-APP TRACKER & DISPATCHER
    // ============================================================

    property string manualPlayerIdentity: ""
    property var playerLastActive: ({})
    property var activePlayerObj: null

    readonly property var player: activePlayerObj || (Mpris.players.values.length > 0 ? Mpris.players.values[0] : null)

    function getPlayerList() {
        const list = Mpris.players.values
        if (!list) return []
        const valid = []
        for (let i = 0; i < list.length; ++i) {
            if (list[i]) valid.push(list[i])
        }
        return valid
    }

    function evaluateBestPlayer() {
        const list = getPlayerList()
        if (list.length === 0) {
            root.activePlayerObj = null
            return
        }

        // 1. If user manually locked a player that is still alive, retain it
        if (root.manualPlayerIdentity !== "") {
            for (let i = 0; i < list.length; ++i) {
                if (list[i].identity === root.manualPlayerIdentity) {
                    root.activePlayerObj = list[i]
                    return
                }
            }
            root.manualPlayerIdentity = ""
        }

        // 2. Prioritize any player actively Playing (auto-switches on audio playback)
        const playingList = []
        for (let i = 0; i < list.length; ++i) {
            if (list[i].playbackState === MprisPlaybackState.Playing) {
                playingList.push(list[i])
            }
        }
        if (playingList.length === 1) {
            root.activePlayerObj = playingList[0]
            return
        }
        if (playingList.length > 1) {
            playingList.sort((a, b) => (root.playerLastActive[b.identity] || 0) - (root.playerLastActive[a.identity] || 0))
            root.activePlayerObj = playingList[0]
            return
        }

        // 3. Score all paused / idle players intelligently
        let bestPlayer = null
        let highestScore = -999999

        for (let i = 0; i < list.length; ++i) {
            const p = list[i]
            let score = 0

            const title = p.trackTitle || ""
            const artist = p.trackArtist || ""
            const hasMetadata = (title.trim() !== "" || artist.trim() !== "")
            const isPaused = (p.playbackState === MprisPlaybackState.Paused)

            // Paused with real track metadata has highest baseline priority
            if (isPaused && hasMetadata) score += 5000
            else if (hasMetadata) score += 2000

            // Album artwork bonus
            if (p.trackArtUrl && p.trackArtUrl.trim() !== "") score += 500

            // Dedicated Music Players preference over generic browser video tabs
            const id = (p.identity || "").toLowerCase()
            const isDedicatedMusic = (
                id.includes("spotify") || id.includes("cider") || id.includes("apple") ||
                id.includes("amberol") || id.includes("rhythmbox") || id.includes("clementine") ||
                id.includes("audacious") || id.includes("strawberry") || id.includes("tidal") ||
                id.includes("deezer") || id.includes("mpv") || id.includes("celluloid") ||
                id.includes("vlc") || id.includes("elisa")
            )
            if (isDedicatedMusic) score += 3000

            // Recency timestamp bonus (MRU tracking)
            const recency = root.playerLastActive[p.identity] || 0
            if (recency > 0) {
                const ageMs = Date.now() - recency
                if (ageMs < 600000) {
                    score += Math.max(0, 4000 - Math.floor(ageMs / 100))
                }
            }

            if (score > highestScore) {
                highestScore = score
                bestPlayer = p
            }
        }

        root.activePlayerObj = bestPlayer || list[0]
    }

    function handlePlayerStateChanged(p) {
        if (!p) return
        if (p.playbackState === MprisPlaybackState.Playing) {
            root.manualPlayerIdentity = ""
            root.playerLastActive[p.identity] = Date.now()
        }
        root.evaluateBestPlayer()
    }

    function handlePlayerMetadataChanged(p) {
        if (!p) return
        root.playerLastActive[p.identity] = Date.now()
        root.evaluateBestPlayer()
    }

    // Reactive listener attached to every MPRIS player instance on the desktop
    Instantiator {
        model: Mpris.players.values
        delegate: Connections {
            target: modelData
            function onPlaybackStateChanged() {
                root.handlePlayerStateChanged(modelData)
            }
            function onTrackTitleChanged() {
                root.handlePlayerMetadataChanged(modelData)
            }
            function onTrackArtistChanged() {
                root.handlePlayerMetadataChanged(modelData)
            }
            function onTrackArtUrlChanged() {
                root.handlePlayerMetadataChanged(modelData)
            }
        }
    }

    Connections {
        target: Mpris.players
        function onValuesChanged() {
            root.evaluateBestPlayer()
        }
    }

    // Probe playerctl for the active player on startup
    Process {
        id: initialPlayerctlProbe
        command: ["playerctl", "metadata", "-f", "{{playerName}}"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const activeName = text.trim().toLowerCase()
                if (activeName !== "") {
                    const list = root.getPlayerList()
                    for (let i = 0; i < list.length; ++i) {
                        const id = (list[i].identity || "").toLowerCase()
                        if (id.includes(activeName) || activeName.includes(id)) {
                            root.playerLastActive[list[i].identity] = Date.now()
                            break
                        }
                    }
                    root.evaluateBestPlayer()
                }
            }
        }
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

    property string fetchedCoverUrl: ""
    property bool showVinylMode: false
    property string requestedFetchTitle: ""
    property string requestedFetchArtist: ""

    Timer {
        id: coverFetchDebounceTimer
        interval: 100
        repeat: false
        onTriggered: {
            if (!root.hasTrack || root.title === "Nothing playing") return
            root.requestedFetchTitle = root.title
            root.requestedFetchArtist = root.artist
            coverFetchProcess.running = false
            coverFetchProcess.running = true
        }
    }

    Process {
        id: coverFetchProcess
        command: [
            Quickshell.env("HOME") + "/.config/nexa/rust/target/release/nexad",
            "media",
            "fetch",
            root.requestedFetchTitle,
            root.requestedFetchArtist
        ]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const res = text.trim()
                if (res !== "" && res.startsWith("file://") && root.title === root.requestedFetchTitle) {
                    root.fetchedCoverUrl = res
                }
            }
        }
    }

    function triggerCoverFetch() {
        if (!root.hasTrack || root.title === "Nothing playing") return
        coverFetchDebounceTimer.restart()
    }

    onTitleChanged: {
        root.fetchedCoverUrl = ""
        triggerCoverFetch()
    }

    onArtistChanged: {
        triggerCoverFetch()
    }

    onArtworkChanged: {
        triggerCoverFetch()
    }

    onPlayerChanged: {
        root.fetchedCoverUrl = ""
        triggerCoverFetch()
    }

    Component.onCompleted: {
        root.evaluateBestPlayer()
        if (initialPlayerctlProbe) initialPlayerctlProbe.running = true
        triggerCoverFetch()
    }

    // High-Resolution Artwork URL Pipeline
    readonly property string highResArtwork: {
        if (root.fetchedCoverUrl !== "") return root.fetchedCoverUrl

        if (!artwork) return ""
        let art = artwork
        // Spotify: replace 300x300 (1e02) or 64x64 (4851) with 640x640 (b273)
        if (art.includes("i.scdn.co/image/ab67616d00001e02")) {
            art = art.replace("ab67616d00001e02", "ab67616d0000b273")
        } else if (art.includes("i.scdn.co/image/ab67616d00004851")) {
            art = art.replace("ab67616d00004851", "ab67616d0000b273")
        }
        // YouTube / YouTube Music: upgrade low res to maxresdefault
        if (art.includes("hqdefault.jpg")) {
            art = art.replace("hqdefault.jpg", "maxresdefault.jpg")
        } else if (art.includes("default.jpg") && !art.includes("maxresdefault.jpg") && !art.includes("sddefault.jpg")) {
            art = art.replace("default.jpg", "hqdefault.jpg")
        }
        return art
    }

    readonly property string cleanIdentity: {
        if (!available || !player || !player.identity) return "Media Player"
        const raw = player.identity.trim()
        const lower = raw.toLowerCase()
        if (lower.includes("firefox")) return "Firefox"
        if (lower.includes("chromium")) return "Chromium"
        if (lower.includes("chrome")) return "Chrome"
        if (lower.includes("brave")) return "Brave"
        if (lower.includes("zen")) return "Zen"
        if (lower.includes("floorp")) return "Floorp"
        if (lower.includes("waterfox")) return "Waterfox"
        if (lower.includes("spotify")) return "Spotify"
        if (lower.includes("cider")) return "Cider"
        if (lower.includes("apple")) return "Apple Music"
        if (lower.includes("amberol")) return "Amberol"
        if (lower.includes("rhythmbox")) return "Rhythmbox"
        if (lower.includes("vlc")) return "VLC"
        if (lower.includes("mpv")) return "MPV"
        if (lower.includes("celluloid")) return "Celluloid"
        if (lower.includes("deezer")) return "Deezer"
        if (lower.includes("tidal")) return "Tidal"
        return raw
    }

    readonly property string identity: cleanIdentity

    function cyclePlayer() {
        const list = getPlayerList()
        if (list.length <= 1) return
        let curIdx = -1
        for (let i = 0; i < list.length; ++i) {
            if (list[i] === root.player) {
                curIdx = i
                break
            }
        }
        const nextIdx = (curIdx + 1) % list.length
        if (list[nextIdx]) {
            root.manualPlayerIdentity = list[nextIdx].identity || ""
            root.activePlayerObj = list[nextIdx]
            root.playerLastActive[root.activePlayerObj.identity] = Date.now()
            root.refreshPlayerStatus()
        }
    }

    // ============================================================
    // SHUFFLE & LOOP STATUS (MPRIS / PLAYERCTL INTEGRATION)
    // ============================================================

    property bool shuffleActive: false
    property string loopStatus: "None" // "None", "Track", "Playlist"

    function toggleShuffle() {
        const pName = root.cleanIdentity ? root.cleanIdentity.toLowerCase() : ""
        if (pName !== "") {
            Quickshell.execDetached(["playerctl", "-p", pName, "shuffle", "Toggle"])
        } else {
            Quickshell.execDetached(["playerctl", "shuffle", "Toggle"])
        }
        shuffleActive = !shuffleActive
    }

    function cycleLoop() {
        const pName = root.cleanIdentity ? root.cleanIdentity.toLowerCase() : ""
        const nextLoop = (loopStatus === "None" ? "Track" : (loopStatus === "Track" ? "Playlist" : "None"))
        loopStatus = nextLoop
        if (pName !== "") {
            Quickshell.execDetached(["playerctl", "-p", pName, "loop", nextLoop])
        } else {
            Quickshell.execDetached(["playerctl", "loop", nextLoop])
        }
    }

    Process {
        id: mprisStatusProcess
        command: [
            "sh", "-c",
            "p=\"$1\"; if [ -n \"$p\" ]; then printf '%s|%s' \"$(playerctl -p \"$p\" shuffle 2>/dev/null || echo Off)\" \"$(playerctl -p \"$p\" loop 2>/dev/null || echo None)\"; else printf '%s|%s' \"$(playerctl shuffle 2>/dev/null || echo Off)\" \"$(playerctl loop 2>/dev/null || echo None)\"; fi",
            "_",
            root.cleanIdentity ? root.cleanIdentity.toLowerCase() : ""
        ]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split("|")
                if (parts.length >= 2) {
                    root.shuffleActive = (parts[0].toLowerCase() === "on")
                    root.loopStatus = parts[1]
                }
            }
        }
    }

    // ============================================================
    // LIVE CAVA AUDIO SPECTRUM (SYNCED TO MUSIC)
    // Only runs when full island is open, visible, and playing
    // ============================================================
    property var spectrumBins: {
        const arr = []
        for (let i = 0; i < 40; ++i) arr.push(0)
        return arr
    }
    property real audioEnergy: 0.12
    property real audioBass: 0.12
    property real audioPhase: 0.0

    signal audioTick()

    Process {
        id: cavaProcess
        running: root.presentation === "full" && root.playing && root.visible
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
                let start = 0
                let idx = 0
                let sum = 0
                let bassSum = 0
                const len = line.length

                for (let i = 0; i < len; ++i) {
                    if (line.charCodeAt(i) === 59 /* ';' */) {
                        if (i > start && idx < 40) {
                            const raw = Number(line.substring(start, i))
                            if (!isNaN(raw)) {
                                const val = raw >= 1000 ? 1.0 : (raw * 0.00135)
                                root.spectrumBins[idx] = val > 1.0 ? 1.0 : val
                                sum += val
                                if (idx < 12) bassSum += val
                                idx++
                            }
                        }
                        start = i + 1
                    }
                }

                if (idx > 0) {
                    root.audioEnergy = Math.max(0.08, sum / idx)
                    root.audioBass = Math.max(0.08, bassSum / Math.min(12, idx))
                    root.audioPhase += 0.07 + root.audioEnergy * 0.14
                    root.audioTick()
                }
            }
        }

        onRunningChanged: {
            if (!running) {
                for (let i = 0; i < 40; ++i) root.spectrumBins[i] = 0
                root.audioEnergy = 0.12
                root.audioBass = 0.12
                root.audioTick()
            }
        }
    }

    function refreshPlayerStatus() {
        if (!mprisStatusProcess.running) {
            mprisStatusProcess.running = true
        }
    }

    function playerIcon(idName) {
        const id = String(idName || "").toLowerCase()
        if (id.includes("spotify")) return "󰓇"
        if (id.includes("firefox") || id.includes("zen") || id.includes("floorp") || id.includes("waterfox") || id.includes("librewolf")) return "󰈹"
        if (id.includes("chrome") || id.includes("chromium")) return "󰊯"
        if (id.includes("brave")) return "󰊯"
        if (id.includes("edge")) return "󰇩"
        if (id.includes("cider") || id.includes("apple")) return "󰀵"
        if (id.includes("amberol")) return "󰎆"
        if (id.includes("rhythmbox") || id.includes("clementine") || id.includes("strawberry") || id.includes("elisa") || id.includes("lollypop")) return "󰎆"
        if (id.includes("vlc")) return "󰕼"
        if (id.includes("mpv") || id.includes("celluloid") || id.includes("haruna")) return "󰐎"
        if (id.includes("tidal") || id.includes("deezer") || id.includes("ytm") || id.includes("youtube")) return "󰎆"
        return "󰎆"
    }

    function playerBrandColor(idName) {
        const id = String(idName || "").toLowerCase()
        if (id.includes("spotify")) return "#1DB954"
        if (id.includes("firefox") || id.includes("zen") || id.includes("floorp")) return "#FF7139"
        if (id.includes("waterfox")) return "#00B0F0"
        if (id.includes("chrome") || id.includes("chromium")) return "#4285F4"
        if (id.includes("brave")) return "#FB542B"
        if (id.includes("edge")) return "#0078D7"
        if (id.includes("cider") || id.includes("apple")) return "#FC3C44"
        if (id.includes("amberol")) return "#E05A47"
        if (id.includes("rhythmbox")) return "#2670E8"
        if (id.includes("vlc")) return "#FF8800"
        if (id.includes("mpv") || id.includes("celluloid")) return "#9C27B0"
        if (id.includes("tidal")) return "#00FFFF"
        if (id.includes("deezer")) return "#A238FF"
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

            // Subtle Vertical Divider
            Rectangle {
                Layout.preferredWidth: 1
                Layout.preferredHeight: 14
                Layout.alignment: Qt.AlignVCenter
                color: Nexa.Theme.divider
                opacity: 0.6
            }

            // Compact Clock
            Text {
                id: compactClockText
                Layout.alignment: Qt.AlignVCenter
                text: Qt.formatDateTime(root.currentTime, "hh:mm AP")
                color: Nexa.Theme.text
                font.family: Nexa.Theme.fontFamily
                font.pixelSize: Nexa.Theme.fontSizeSm
                font.weight: Nexa.Theme.fontWeightMedium
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
                NexaUI.NexaProgressBar {
                    Layout.fillWidth: true
                    implicitHeight: 3
                    from: 0.0
                    to: 1.0
                    value: root.progress
                    barColor: Nexa.Theme.primary
                    trackColor: Nexa.Theme.surfaceContainerHighest
                    visible: root.duration > 0
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

        // Smooth opacity fade on appearance
        opacity: visible ? 1.0 : 0.0
        Behavior on opacity {
            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
        }

        onVisibleChanged: {
            if (visible) root.refreshPlayerStatus()
        }

        // --------------------------------------------------------
        // Ambient Backdrop & Specular Rim (Hardware-Optimized)
        // --------------------------------------------------------
        Item {
            id: cardBackdropContainer
            anchors.fill: parent
            z: -1

            Rectangle {
                id: cardShapeMask
                anchors.fill: parent
                radius: Nexa.Theme.radius2Xl
                visible: false
            }

            Item {
                id: cardContentToMask
                anchors.fill: parent
                visible: false

                // 1. Base card fill
                Rectangle {
                    anchors.fill: parent
                    color: Nexa.Theme.surfaceContainerLow
                }

                // 2. Ambient Artwork Backdrop (Vibrant & Clearly Visible)
                Image {
                    id: bgAmbientArt
                    anchors.fill: parent
                    anchors.margins: -10
                    source: root.highResArtwork !== "" ? root.highResArtwork : root.artwork
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    sourceSize: Qt.size(360, 360)
                    smooth: true
                    opacity: (root.hasTrack && (root.artwork !== "" || root.highResArtwork !== "")) ? 0.45 : 0.0

                    Behavior on opacity {
                        NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
                    }
                }

                // 3. Frosted Glass Tint
                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.rgba(Nexa.Theme.surfaceContainerLow.r, Nexa.Theme.surfaceContainerLow.g, Nexa.Theme.surfaceContainerLow.b, 0.72) }
                        GradientStop { position: 0.5; color: Qt.rgba(Nexa.Theme.surfaceContainerLow.r, Nexa.Theme.surfaceContainerLow.g, Nexa.Theme.surfaceContainerLow.b, 0.65) }
                        GradientStop { position: 1.0; color: Qt.rgba(Nexa.Theme.surfaceContainerLow.r, Nexa.Theme.surfaceContainerLow.g, Nexa.Theme.surfaceContainerLow.b, 0.80) }
                    }
                }
            }

            // True rounded corner mask - zero bleed into square edges
            OpacityMask {
                anchors.fill: parent
                source: cardContentToMask
                maskSource: cardShapeMask
            }

            // Crisp rounded border matching environment
            Rectangle {
                anchors.fill: parent
                radius: Nexa.Theme.radius2Xl
                color: "transparent"
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.12)
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
        // Active State: Modern Cyber / Android Media Deck
        // --------------------------------------------------------
        Item {
            anchors.fill: parent
            visible: root.hasTrack && (root.playing || root.paused)

            RowLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 24

                // ====================================================
                // LEFT: CIRCULAR ALBUM ART DISC + AUDIO-SYNCED VISUALIZER
                // ====================================================
                Item {
                    Layout.preferredWidth: 220
                    Layout.preferredHeight: 220
                    Layout.alignment: Qt.AlignVCenter

                    // 1. Soft Ambient Glow behind the circular artwork
                    Rectangle {
                        anchors.centerIn: parent
                        width: 140
                        height: 140
                        radius: 70
                        color: Qt.rgba(Nexa.Theme.primary.r, Nexa.Theme.primary.g, Nexa.Theme.primary.b, 0.28)
                        opacity: root.playing ? 0.85 : 0.25
                        scale: root.playing ? (1.02 + root.audioBass * 0.12) : 0.96
                        Behavior on opacity { NumberAnimation { duration: 300 } }
                        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
                    }

                    // 2. Reactive Circular Spectrum Visualizer Ring (Synced to Music)
                    Canvas {
                        id: radialCanvas
                        anchors.fill: parent
                        renderTarget: Canvas.FramebufferObject
                        renderStrategy: Canvas.Threaded

                        Connections {
                            target: root
                            function onAudioTick() { radialCanvas.requestPaint() }
                            function onPlayingChanged() { radialCanvas.requestPaint() }
                            function onPresentationChanged() { if (root.presentation === "full") radialCanvas.requestPaint() }
                        }

                        // Precomputed static trig table for 80 bars (zero Math.cos/sin overhead during animation)
                        readonly property var trigTable: {
                            const count = 80
                            const table = []
                            for (let i = 0; i < count; i++) {
                                const a = (i / count) * Math.PI * 2
                                table.push({ cos: Math.cos(a), sin: Math.sin(a), angle: a })
                            }
                            return table
                        }

                        onPaint: {
                            const ctx = getContext("2d")
                            ctx.reset()
                            const cx = width / 2
                            const cy = height / 2
                            const barCount = 80
                            const baseR = 76
                            const isPlaying = root.playing && root.presentation === "full" && root.visible
                            const hasBins = root.spectrumBins && root.spectrumBins.length > 0
                            const table = trigTable

                            ctx.lineWidth = 2.0
                            ctx.lineCap = "round"
                            ctx.strokeStyle = Nexa.Theme.primary

                            ctx.beginPath()
                            for (let i = 0; i < barCount; i++) {
                                const entry = table[i]
                                const cosA = entry.cos
                                const sinA = entry.sin

                                // Map 80 bars to 20 spectrum bins with smooth interpolation
                                const half = 40
                                const norm = (i < half ? i : (79 - i)) / (half - 1)
                                const floatIdx = norm * 19.0
                                const i0 = Math.floor(floatIdx)
                                const i1 = Math.min(19, i0 + 1)
                                const frac = floatIdx - i0
                                const b0 = hasBins ? (root.spectrumBins[i0] || 0) : 0
                                const b1 = hasBins ? (root.spectrumBins[i1] || 0) : 0
                                const binVal = b0 + (b1 - b0) * frac

                                let h = 3.5
                                if (isPlaying) {
                                    if (hasBins && binVal > 0.01) {
                                        h = 3.5 + binVal * 22.0
                                    } else {
                                        const wave = Math.sin(entry.angle * 4 + root.audioPhase) * 6.0
                                        h = Math.max(3.5, 7.5 + wave)
                                    }
                                }

                                const x1 = cx + cosA * baseR
                                const y1 = cy + sinA * baseR
                                const x2 = cx + cosA * (baseR + h)
                                const y2 = cy + sinA * (baseR + h)

                                ctx.moveTo(x1, y1)
                                ctx.lineTo(x2, y2)
                            }
                            ctx.stroke()
                        }
                    }

                    // 3. High-Res Circular Album Art Disc + Cyber Vinyl Deck
                    Item {
                        id: frontArtworkCard
                        width: 140
                        height: 140
                        anchors.centerIn: parent

                        // Click to toggle between Album Art and Cyber Vinyl Deck
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.showVinylMode = !root.showVinylMode
                        }

                        // --- VIEW 1: High-Res Album Art ---
                        Item {
                            anchors.fill: parent
                            visible: !root.showVinylMode && (root.highResArtwork !== "" || root.artwork !== "")

                            Rectangle {
                                id: artCircleMask
                                anchors.fill: parent
                                radius: width / 2
                                visible: false
                            }

                            Image {
                                id: mainArtworkImage
                                anchors.fill: parent
                                source: root.highResArtwork !== "" ? root.highResArtwork : root.artwork
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: true
                                mipmap: true
                                sourceSize: Qt.size(280, 280)
                                smooth: true
                                visible: false
                            }

                            OpacityMask {
                                anchors.fill: parent
                                source: mainArtworkImage
                                maskSource: artCircleMask
                            }

                            // Specular rim
                            Rectangle {
                                anchors.fill: parent
                                radius: width / 2
                                color: "transparent"
                                border.width: 1.2
                                border.color: Qt.rgba(255, 255, 255, 0.16)
                            }
                        }

                        // --- VIEW 2: Cyber Vinyl Deck ("Something Else") ---
                        Item {
                            id: vinylDeck
                            anchors.fill: parent
                            visible: root.showVinylMode || (root.highResArtwork === "" && root.artwork === "")

                            // Rotating vinyl record container
                            Item {
                                anchors.fill: parent
                                rotation: 0

                                RotationAnimation on rotation {
                                    from: 0
                                    to: 360
                                    duration: 8000
                                    loops: Animation.Infinite
                                    running: root.playing && root.presentation === "full" && root.visible && vinylDeck.visible
                                }

                                // Dark vinyl disc body
                                Rectangle {
                                    anchors.fill: parent
                                    radius: width / 2
                                    color: "#121316"
                                    border.width: 1
                                    border.color: Qt.rgba(255, 255, 255, 0.14)
                                }

                                // Concentric microgrooves
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 116; height: 116; radius: 58
                                    color: "transparent"
                                    border.width: 1
                                    border.color: Qt.rgba(255, 255, 255, 0.06)
                                }
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 96; height: 96; radius: 48
                                    color: "transparent"
                                    border.width: 1
                                    border.color: Qt.rgba(255, 255, 255, 0.07)
                                }
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 76; height: 76; radius: 38
                                    color: "transparent"
                                    border.width: 1
                                    border.color: Qt.rgba(255, 255, 255, 0.08)
                                }

                                // Center Label with Brand Color
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 52; height: 52; radius: 26
                                    color: root.playerBrandColor(root.identity)

                                    Rectangle {
                                        anchors.fill: parent
                                        anchors.margins: 3
                                        radius: width / 2
                                        color: "transparent"
                                        border.width: 1
                                        border.color: Qt.rgba(0, 0, 0, 0.25)
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: root.playerIcon(root.identity)
                                        color: "#ffffff"
                                        font.family: Nexa.Theme.iconFontFamily
                                        font.pixelSize: 22
                                    }

                                    // Spindle hole
                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 10; height: 10; radius: 5
                                        color: "#0a0b0d"
                                        border.width: 1
                                        border.color: Qt.rgba(255, 255, 255, 0.4)
                                    }
                                }
                            }
                        }
                    }
                }

                // ====================================================
                // RIGHT: METADATA, SQUIGGLY SCRUBBER & CAPSULE CONTROLS
                // ====================================================
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 10

                    // 1. Top Bar: Status Indicator + Active Player Switcher Pill
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        // Clean Status Badge
                        Row {
                            spacing: 6
                            Layout.alignment: Qt.AlignVCenter

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

                        Item { Layout.fillWidth: true }

                        // Active Player Switcher Pill: [ 󰓇 Spotify 󰅂 ]
                        Rectangle {
                            id: playerPillRect
                            Layout.preferredWidth: playerPillContent.width + 24
                            Layout.preferredHeight: 26
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                            radius: 13
                            color: playerPillMouse.containsMouse
                                ? Nexa.Theme.hoverStrong
                                : Nexa.Theme.surfaceContainerHigh
                            border.width: 1
                            border.color: Nexa.Theme.border
                            scale: playerPillMouse.pressed ? 0.94 : 1.0
                            Behavior on scale { NumberAnimation { duration: 100 } }

                            Row {
                                id: playerPillContent
                                anchors.centerIn: parent
                                spacing: 6

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: root.playerIcon(root.identity)
                                    color: root.playerBrandColor(root.identity)
                                    font.family: Nexa.Theme.iconFontFamily
                                    font.pixelSize: 13
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: root.identity
                                    color: Nexa.Theme.text
                                    font.family: Nexa.Theme.fontFamily
                                    font.pixelSize: 11
                                    font.weight: Nexa.Theme.fontWeightBold
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "󰅂"
                                    color: Nexa.Theme.mutedText
                                    font.family: Nexa.Theme.iconFontFamily
                                    font.pixelSize: 10
                                }
                            }

                            MouseArea {
                                id: playerPillMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.cyclePlayer()
                            }
                        }
                    }

                    // 2. Track Title Box (Bold, Smooth Marquee on Overflow)
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
                            font.pixelSize: 24
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
                            Layout.fillWidth: true
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
                            font.pixelSize: 13
                            elide: Text.ElideRight
                        }
                    }

                    // 4. Android 13/14 "Squiggly" Waveform Progress Scrubber
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        // Elapsed Time
                        Text {
                            text: root.formatTime(root.displayedPosition)
                            color: Nexa.Theme.mutedText
                            font.family: Nexa.Theme.monoFontFamily
                            font.pixelSize: 12
                            font.weight: Nexa.Theme.fontWeightMedium
                        }

                        // Squiggly Canvas Waveform Scrubber
                        Item {
                            id: squigglyContainer
                            Layout.fillWidth: true
                            Layout.preferredHeight: 28

                            Canvas {
                                id: squigglyCanvas
                                anchors.fill: parent
                                renderTarget: Canvas.FramebufferObject
                                renderStrategy: Canvas.Threaded

                                property real wavePhase: 0.0

                                NumberAnimation on wavePhase {
                                    from: 0
                                    to: Math.PI * 2
                                    duration: 1800
                                    loops: Animation.Infinite
                                    running: root.playing && root.presentation === "full" && root.visible
                                }

                                onWavePhaseChanged: squigglyCanvas.requestPaint()

                                Connections {
                                    target: root
                                    function onDisplayedProgressChanged() { squigglyCanvas.requestPaint() }
                                    function onDurationChanged() { squigglyCanvas.requestPaint() }
                                    function onPlayingChanged() { squigglyCanvas.requestPaint() }
                                }

                                onPaint: {
                                    const ctx = getContext("2d")
                                    ctx.reset()

                                    const w = width
                                    const h = height
                                    const centerY = h / 2
                                    const progress = Math.max(0, Math.min(1, root.displayedProgress))
                                    const progressX = w * progress
                                    const isPlaying = root.playing && root.presentation === "full" && root.visible

                                    // 1. Remaining unplayed track (flat rail with subtle opacity & terminal dot)
                                    if (progressX < w - 4) {
                                        ctx.strokeStyle = Qt.rgba(Nexa.Theme.primary.r, Nexa.Theme.primary.g, Nexa.Theme.primary.b, 0.25)
                                        ctx.lineWidth = 3.5
                                        ctx.lineCap = "round"
                                        ctx.beginPath()
                                        ctx.moveTo(progressX + 3, centerY)
                                        ctx.lineTo(w - 4, centerY)
                                        ctx.stroke()

                                        // Subtle terminal dot at end of rail
                                        ctx.fillStyle = Qt.rgba(Nexa.Theme.primary.r, Nexa.Theme.primary.g, Nexa.Theme.primary.b, 0.45)
                                        ctx.beginPath()
                                        ctx.arc(w - 2, centerY, 2.5, 0, Math.PI * 2)
                                        ctx.fill()
                                    }

                                    // 2. Elapsed played track (original smooth elegant sine wave from preview)
                                    if (progressX > 2) {
                                        ctx.strokeStyle = Nexa.Theme.primary
                                        ctx.lineWidth = 3.5
                                        ctx.lineCap = "round"
                                        ctx.beginPath()
                                        ctx.moveTo(0, centerY)

                                        const step = 2.0
                                        const maxAmp = 4.0
                                        for (let x = 0; x <= progressX; x += step) {
                                            const wave = isPlaying
                                                ? Math.sin(x * 0.16 + wavePhase) * maxAmp
                                                : Math.sin(x * 0.16) * maxAmp
                                            ctx.lineTo(x, centerY + wave)
                                        }
                                        ctx.stroke()
                                    }

                                    // 3. Vertical Scrubber Handle Pill (High-Contrast, Crisp)
                                    if (root.duration > 0) {
                                        ctx.fillStyle = Nexa.Theme.primary
                                        const thumbW = 4.5
                                        const thumbH = 18
                                        const thumbX = Math.max(0, Math.min(w - thumbW, progressX - thumbW / 2))
                                        const r = 2.25
                                        const ty = centerY - thumbH / 2

                                        ctx.beginPath()
                                        ctx.moveTo(thumbX + r, ty)
                                        ctx.lineTo(thumbX + thumbW - r, ty)
                                        ctx.arcTo(thumbX + thumbW, ty, thumbX + thumbW, ty + r, r)
                                        ctx.lineTo(thumbX + thumbW, ty + thumbH - r)
                                        ctx.arcTo(thumbX + thumbW, ty + thumbH, thumbX + thumbW - r, ty + thumbH, r)
                                        ctx.lineTo(thumbX + r, ty + thumbH)
                                        ctx.arcTo(thumbX, ty + thumbH, thumbX, ty + thumbH - r, r)
                                        ctx.lineTo(thumbX, ty + r)
                                        ctx.arcTo(thumbX, ty, thumbX + r, ty, r)
                                        ctx.closePath()
                                        ctx.fill()
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

                        // Total Duration
                        Text {
                            text: root.formatTime(root.duration)
                            color: Nexa.Theme.mutedText
                            font.family: Nexa.Theme.monoFontFamily
                            font.pixelSize: 12
                        }
                    }

                    // 5. Working Media Controls Row with Capsule Containers (Shuffle, Prev, Hero Pill, Next, Loop)
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 4
                        spacing: 20

                        Item { Layout.fillWidth: true }

                        // 1. Shuffle Capsule Button
                        Rectangle {
                            implicitWidth: 40
                            implicitHeight: 40
                            radius: 20
                            color: root.shuffleActive
                                ? Qt.rgba(Nexa.Theme.primary.r, Nexa.Theme.primary.g, Nexa.Theme.primary.b, 0.22)
                                : (shuffleMouse.containsMouse ? Nexa.Theme.hoverStrong : Nexa.Theme.surfaceContainerHigh)
                            border.width: 1
                            border.color: root.shuffleActive ? Nexa.Theme.primary : Nexa.Theme.border
                            scale: shuffleMouse.pressed ? 0.90 : 1.0
                            Behavior on scale { NumberAnimation { duration: 100 } }

                            Text {
                                anchors.centerIn: parent
                                text: "󰒝"
                                color: root.shuffleActive ? Nexa.Theme.primary : Nexa.Theme.text
                                font.family: Nexa.Theme.iconFontFamily
                                font.pixelSize: 18
                            }

                            MouseArea {
                                id: shuffleMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.toggleShuffle()
                            }
                        }

                        // 2. Previous Track Capsule Button
                        Rectangle {
                            implicitWidth: 44
                            implicitHeight: 44
                            radius: 22
                            color: prevMouse.containsMouse
                                ? Nexa.Theme.hoverStrong
                                : Nexa.Theme.surfaceContainerHigh
                            border.width: 1
                            border.color: Nexa.Theme.border
                            scale: prevMouse.pressed ? 0.90 : 1.0
                            Behavior on scale { NumberAnimation { duration: 100 } }

                            Text {
                                anchors.centerIn: parent
                                text: "󰒮"
                                color: Nexa.Theme.text
                                font.family: Nexa.Theme.iconFontFamily
                                font.pixelSize: 22
                            }

                            MouseArea {
                                id: prevMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.previous()
                            }
                        }

                        // 3. HERO Play / Pause Pill Button (Wide Accent Pill with Dark High-Contrast Icon)
                        Rectangle {
                            id: heroPlayBtn
                            implicitWidth: 80
                            implicitHeight: 46
                            radius: 23
                            color: playMouse.pressed
                                ? Qt.darker(Nexa.Theme.primary, 1.25)
                                : Nexa.Theme.primary
                            scale: playMouse.pressed ? 0.92 : playMouse.containsMouse ? 1.04 : 1.0

                            Behavior on scale {
                                NumberAnimation { duration: 150; easing.type: Easing.OutBack }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: root.playing ? "󰏤" : "󰐊"
                                color: "#141414"
                                font.family: Nexa.Theme.iconFontFamily
                                font.pixelSize: 24
                            }

                            MouseArea {
                                id: playMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.togglePlaying()
                            }
                        }

                        // 4. Next Track Capsule Button
                        Rectangle {
                            implicitWidth: 44
                            implicitHeight: 44
                            radius: 22
                            color: nextMouse.containsMouse
                                ? Nexa.Theme.hoverStrong
                                : Nexa.Theme.surfaceContainerHigh
                            border.width: 1
                            border.color: Nexa.Theme.border
                            scale: nextMouse.pressed ? 0.90 : 1.0
                            Behavior on scale { NumberAnimation { duration: 100 } }

                            Text {
                                anchors.centerIn: parent
                                text: "󰒭"
                                color: Nexa.Theme.text
                                font.family: Nexa.Theme.iconFontFamily
                                font.pixelSize: 22
                            }

                            MouseArea {
                                id: nextMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.next()
                            }
                        }

                        // 5. Repeat / Loop Capsule Button
                        Rectangle {
                            implicitWidth: 40
                            implicitHeight: 40
                            radius: 20
                            color: root.loopStatus !== "None"
                                ? Qt.rgba(Nexa.Theme.primary.r, Nexa.Theme.primary.g, Nexa.Theme.primary.b, 0.22)
                                : (loopMouse.containsMouse ? Nexa.Theme.hoverStrong : Nexa.Theme.surfaceContainerHigh)
                            border.width: 1
                            border.color: root.loopStatus !== "None" ? Nexa.Theme.primary : Nexa.Theme.border
                            scale: loopMouse.pressed ? 0.90 : 1.0
                            Behavior on scale { NumberAnimation { duration: 100 } }

                            Text {
                                anchors.centerIn: parent
                                text: root.loopStatus === "Track" ? "󰑘" : "󰑖"
                                color: root.loopStatus !== "None" ? Nexa.Theme.primary : Nexa.Theme.text
                                font.family: Nexa.Theme.iconFontFamily
                                font.pixelSize: 18
                            }

                            MouseArea {
                                id: loopMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.cycleLoop()
                            }
                        }

                        Item { Layout.fillWidth: true }
                    }
                }
            }
        }
    }
}
