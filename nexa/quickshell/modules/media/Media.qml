import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQml.Models
import Qt5Compat.GraphicalEffects

import Quickshell.Services.Mpris
import Quickshell.Io
import Quickshell

import "../../NewNexaUI" as NexaUI
import "../../services" as Services


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

    readonly property string nexadBin: Quickshell.env("HOME") + "/.config/nexa/rust/target/release/nexad"

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

    readonly property var rawPlayerList: {
        const list = Mpris.players.values
        if (!list) return []
        const valid = []
        for (let i = 0; i < list.length; ++i) {
            const p = list[i]
            if (!p) continue
            const id = (p.identity || "").toLowerCase()
            const title = (p.trackTitle || "").trim()
            const artist = (p.trackArtist || "").trim()
            // Ignore playerctld proxy if no player is actually active/controlled
            if (id.includes("playerctld") && title === "" && artist === "") {
                continue
            }
            valid.push(p)
        }
        return valid
    }

    onRawPlayerListChanged: {
        root.evaluateBestPlayer()
    }

    readonly property var player: {
        const list = rawPlayerList
        if (!list || list.length === 0) return null

        // 1. If user manually locked a player that is still alive, retain it
        if (root.manualPlayerIdentity !== "") {
            for (let i = 0; i < list.length; ++i) {
                if (list[i] && list[i].identity === root.manualPlayerIdentity) {
                    return list[i]
                }
            }
        }

        // 2. If activePlayerObj is still alive and present in list, use it
        if (root.activePlayerObj) {
            for (let i = 0; i < list.length; ++i) {
                if (list[i] && list[i] === root.activePlayerObj) {
                    return root.activePlayerObj
                }
            }
        }

        // 3. Otherwise find any player actively Playing
        for (let i = 0; i < list.length; ++i) {
            if (list[i] && list[i].playbackState === MprisPlaybackState.Playing) {
                return list[i]
            }
        }

        // 4. Otherwise find any player that is Paused with track metadata
        for (let i = 0; i < list.length; ++i) {
            if (list[i] && list[i].playbackState === MprisPlaybackState.Paused) {
                const t = (list[i].trackTitle || "").trim()
                const a = (list[i].trackArtist || "").trim()
                if (t !== "" || a !== "") {
                    return list[i]
                }
            }
        }

        // 5. Fallback to first available player
        return list[0]
    }

    function getPlayerList() {
        const list = Mpris.players.values
        if (!list) return []
        const valid = []
        for (let i = 0; i < list.length; ++i) {
            const p = list[i]
            if (!p) continue
            const id = (p.identity || "").toLowerCase()
            const title = (p.trackTitle || "").trim()
            const artist = (p.trackArtist || "").trim()
            if (id.includes("playerctld") && title === "" && artist === "") {
                continue
            }
            valid.push(p)
        }
        return valid
    }

    function evaluateBestPlayer() {
        const list = getPlayerList()
        if (list.length === 0) {
            root.activePlayerObj = null
            return
        }

        if (root.activePlayerObj) {
            let found = false
            for (let i = 0; i < list.length; ++i) {
                if (list[i] && list[i] === root.activePlayerObj) {
                    found = true
                    break
                }
            }
            if (!found) {
                root.activePlayerObj = null
            }
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
    // 1-MINUTE PAUSE / IDLE TIMEOUT (Wall-clock absolute timer)
    // ------------------------------------------------------------

    property real pausedTimestamp: 0
    property bool pauseTimeoutExpired: false

    onPlayingChanged: {
        if (root.playing) {
            root.pauseTimeoutExpired = false
            root.pausedTimestamp = 0
        } else if (root.paused) {
            root.pausedTimestamp = Date.now()
            root.pauseTimeoutExpired = false
        }
    }

    onPausedChanged: {
        if (root.paused && !root.playing) {
            if (root.pausedTimestamp === 0) {
                root.pausedTimestamp = Date.now()
            }
            root.pauseTimeoutExpired = false
        } else if (!root.paused && !root.playing) {
            // Player stopped or closed
            root.pauseTimeoutExpired = true
        }
    }

    onAvailableChanged: {
        if (!root.available) {
            root.pauseTimeoutExpired = false
            root.pausedTimestamp = 0
            root.activePlayerObj = null
        }
    }

    onHasTrackChanged: {
        if (!root.hasTrack) {
            root.pauseTimeoutExpired = false
            root.pausedTimestamp = 0
        }
    }

    Timer {
        id: pauseWatchdogTimer
        interval: 1000
        running: root.available && root.hasTrack && !root.playing && !root.pauseTimeoutExpired
        repeat: true
        onTriggered: {
            if (root.pausedTimestamp > 0 && !root.playing) {
                const elapsed = Date.now() - root.pausedTimestamp
                if (elapsed >= 60000) {
                    root.pauseTimeoutExpired = true
                }
            }
        }
    }

    readonly property bool contextActive:
        available
        && hasTrack
        && (playing || (paused && !pauseTimeoutExpired))

    readonly property bool hasTrack:
        available
        && player
        && player.trackTitle !== null
        && player.trackTitle !== undefined
        && (player.trackTitle.trim() !== "" || (player.trackArtist && player.trackArtist.trim() !== ""))

    // ============================================================
    // METADATA
    // ============================================================

    readonly property string title:
        (available && player && player.trackTitle)
        ? player.trackTitle
        : "Nothing playing"

    readonly property string artist:
        (available && player && player.trackArtist)
        ? player.trackArtist
        : "Unknown artist"

    readonly property string album:
        (available && player && player.trackAlbum)
        ? player.trackAlbum
        : ""

    readonly property string artwork:
        (available && player && player.trackArtUrl)
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
        if (root.paused && !root.playing) {
            root.pausedTimestamp = Date.now()
        }
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
    readonly property bool shuffle: {
        if (root.player && root.player.canShuffle) return root.player.shuffle
        return shuffleActive
    }
    property string loopStatus: "None" // "None", "Track", "Playlist"

    function toggleShuffle() {
        shuffleActive = !shuffleActive
        if (root.player && root.player.canShuffle) {
            root.player.shuffle = !root.player.shuffle
        }
        Quickshell.execDetached(["playerctl", "shuffle", "Toggle"])
    }

    function cycleLoop() {
        const nextLoop = (loopStatus === "None" ? "Track" : (loopStatus === "Track" ? "Playlist" : "None"))
        loopStatus = nextLoop
        if (root.player && root.player.canLoop) {
            if (nextLoop === "None") root.player.loopState = MprisLoopState.None
            else if (nextLoop === "Track") root.player.loopState = MprisLoopState.Track
            else if (nextLoop === "Playlist") root.player.loopState = MprisLoopState.Playlist
        }
        Quickshell.execDetached(["playerctl", "loop", nextLoop])
    }

    Process {
        id: mprisStatusProcess
        command: [
            Quickshell.env("HOME") + "/.config/nexa/rust/target/release/nexad",
            "media",
            "status",
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
    signal requestBack()
    signal requestOpenClock()

    Connections {
        target: Services.AudioVisualizer
        function onFrameTick() {
            if (root.presentation === "full" && root.playing && root.visible) {
                const b = Services.AudioVisualizer.bars;
                for (let i = 0; i < Math.min(b.length, 40); ++i) {
                    root.spectrumBins[i] = b[i];
                }
                root.audioEnergy = Math.max(0.08, Services.AudioVisualizer.energy);
                root.audioBass = Math.max(0.08, Services.AudioVisualizer.bass);
                root.audioPhase += 0.07 + root.audioEnergy * 0.14;
                root.audioTick();
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
        return NexaUI.NexaColors.primary
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
        running: root.available && root.playing && (root.player && root.player.positionSupported) && !root.seeking
        onTriggered: if (root.player) root.player.positionChanged()
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
                    color: NexaUI.NexaColors.surfaceContainerHigh
                    border.width: NexaUI.NexaTokens.borderThin
                    border.color: NexaUI.NexaColors.border

                    Text {
                        anchors.centerIn: parent
                        text: root.playerIcon(root.identity)
                        color: NexaUI.NexaColors.primary
                        font.family: NexaUI.NexaTypography.familyIcon
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
                    color: root.hasTrack ? NexaUI.NexaColors.text : NexaUI.NexaColors.mutedText
                    font.family: NexaUI.NexaTypography.familyBody
                    font.pixelSize: NexaUI.NexaTypography.sizeSm
                    font.weight: NexaUI.NexaTypography.weightMedium
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
            anchors.leftMargin: NexaUI.NexaTokens.spacingMd
            anchors.rightMargin: NexaUI.NexaTokens.spacingMd
            anchors.topMargin: NexaUI.NexaTokens.spacingSm
            anchors.bottomMargin: NexaUI.NexaTokens.spacingSm
            spacing: NexaUI.NexaTokens.spacingMd

            // Artwork Card
            Rectangle {
                Layout.preferredWidth: 44
                Layout.preferredHeight: 44
                radius: NexaUI.NexaTokens.radiusSm
                color: NexaUI.NexaColors.surfaceContainerHigh
                border.width: NexaUI.NexaTokens.borderThin
                border.color: NexaUI.NexaColors.border
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
                    color: NexaUI.NexaColors.mutedText
                    font.family: NexaUI.NexaTypography.familyIcon
                    font.pixelSize: NexaUI.NexaTypography.sizeMd
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
                            color: NexaUI.NexaColors.text
                            font.family: NexaUI.NexaTypography.familyBody
                            font.pixelSize: NexaUI.NexaTypography.sizeSm
                            font.weight: NexaUI.NexaTypography.weightSemiBold
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
                        color: NexaUI.NexaColors.mutedText
                        font.family: NexaUI.NexaTypography.familyMono
                        font.pixelSize: NexaUI.NexaTypography.size2Xs
                        font.features: NexaUI.NexaTypography.fontFeaturesTnum
                        visible: root.duration > 0
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: root.artist
                    color: NexaUI.NexaColors.mutedText
                    font.family: NexaUI.NexaTypography.familyBody
                    font.pixelSize: NexaUI.NexaTypography.sizeXs
                    elide: Text.ElideRight
                }

                // Mini Progress Bar
                NexaUI.NexaProgressBar {
                    Layout.fillWidth: true
                    implicitHeight: 3
                    from: 0.0
                    to: 1.0
                    value: root.progress
                    barColor: NexaUI.NexaColors.primary
                    trackColor: NexaUI.NexaColors.surfaceContainerHighest
                    visible: root.duration > 0
                }
            }

            // Minimal Playback Controls
            RowLayout {
                spacing: NexaUI.NexaTokens.spacingXs

                NexaUI.NexaButton {
                    variant: "icon"
                    icon: "󰒮"
                    implicitWidth: NexaUI.NexaTokens.controlHeightSm
                    implicitHeight: NexaUI.NexaTokens.controlHeightSm
                    interactive: root.available && root.player.canGoPrevious
                    onClicked: root.previous()
                }

                NexaUI.NexaButton {
                    variant: "icon"
                    icon: root.playing ? "󰏤" : "󰐊"
                    checked: true
                    implicitWidth: NexaUI.NexaTokens.controlHeightSm
                    implicitHeight: NexaUI.NexaTokens.controlHeightSm
                    interactive: root.available && root.player.canTogglePlaying
                    onClicked: root.togglePlaying()
                }

                NexaUI.NexaButton {
                    variant: "icon"
                    icon: "󰒭"
                    implicitWidth: NexaUI.NexaTokens.controlHeightSm
                    implicitHeight: NexaUI.NexaTokens.controlHeightSm
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
                radius: NexaUI.NexaTokens.radius2Xl
                visible: false
            }

            Item {
                id: cardContentToMask
                anchors.fill: parent
                visible: false

                // 1. Base card fill
                Rectangle {
                    anchors.fill: parent
                    color: NexaUI.NexaColors.surfaceContainerLow
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
                        GradientStop { position: 0.0; color: NexaUI.NexaColors.alpha(NexaUI.NexaColors.surfaceContainerLow, 0.72) }
                        GradientStop { position: 0.5; color: NexaUI.NexaColors.alpha(NexaUI.NexaColors.surfaceContainerLow, 0.65) }
                        GradientStop { position: 1.0; color: NexaUI.NexaColors.alpha(NexaUI.NexaColors.surfaceContainerLow, 0.80) }
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
                radius: NexaUI.NexaTokens.radius2Xl
                color: "transparent"
                border.width: NexaUI.NexaTokens.borderThin
                border.color: NexaUI.NexaColors.borderStrong
            }

            // Top Chamfer Specular Highlight (Layer 2)
            Rectangle {
                anchors.top: parent.top
                anchors.topMargin: 1
                anchors.horizontalCenter: parent.horizontalCenter
                width: NexaUI.NexaTokens.radius2Xl > 0 ? Math.max(0, parent.width - NexaUI.NexaTokens.radius2Xl * 1.6) : parent.width
                height: 1
                visible: NexaUI.NexaOptics.specularHighlight && NexaUI.NexaOptics.specularIntensity > 0.01
                opacity: Math.min(1.0, NexaUI.NexaOptics.specularIntensity / 0.28)
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.25) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
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
                        color: NexaUI.NexaColors.surfaceContainerHigh
                        border.width: 1
                        border.color: NexaUI.NexaColors.border

                        Text {
                            anchors.centerIn: parent
                            text: "󰎆"
                            color: NexaUI.NexaColors.primary
                            font.family: NexaUI.NexaTypography.familyIcon
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
                        color: NexaUI.NexaColors.surfaceContainerLow
                        border.width: 1
                        border.color: NexaUI.NexaColors.border

                        Row {
                            id: idleStatusRow
                            anchors.centerIn: parent
                            spacing: 6

                            Rectangle {
                                width: 6; height: 6; radius: 3
                                color: NexaUI.NexaColors.primary
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: "READY FOR AUDIO"
                                color: NexaUI.NexaColors.mutedText
                                font.family: NexaUI.NexaTypography.familyBody
                                font.pixelSize: 10
                                font.weight: NexaUI.NexaTypography.weightBold
                                font.letterSpacing: 1.2
                            }
                        }
                    }

                    Text {
                        text: "No Media Playing"
                        color: NexaUI.NexaColors.text
                        font.family: NexaUI.NexaTypography.familyBody
                        font.pixelSize: 22
                        font.weight: NexaUI.NexaTypography.weightBold
                    }

                    Text {
                        text: "Play music or video on Spotify, YouTube, or MPV\nto unlock live controls in the Dynamic Island."
                        color: NexaUI.NexaColors.mutedText
                        font.family: NexaUI.NexaTypography.familyBody
                        font.pixelSize: 13
                        lineHeight: 1.3
                    }
                }
            }
        }

        // --------------------------------------------------------
        // --------------------------------------------------------
        // Active State: Next-Gen Split Studio Media Deck
        // --------------------------------------------------------
        Item {
            anchors.fill: parent
            visible: root.hasTrack && (root.playing || root.paused)

            // Soft Ambient Color Glow on Top-Right Corner (Tied to Matugen primary)
            Rectangle {
                width: 440
                height: 320
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: -40
                radius: 220
                color: NexaUI.NexaColors.alpha(NexaUI.NexaColors.primary, 0.12)
                opacity: root.playing ? 0.95 : 0.35
                Behavior on opacity { NumberAnimation { duration: 400 } }
            }

            // ========================================================
            // TWO-COLUMN SPLIT STUDIO LAYOUT
            // ========================================================
            RowLayout {
                anchors.fill: parent
                spacing: 0

                // ----------------------------------------------------
                // LEFT COLUMN: FULL-BLEED HERO ARTWORK (~40% Width)
                // ----------------------------------------------------
                Item {
                    id: leftCoverCol
                    Layout.preferredWidth: 260
                    Layout.fillHeight: true
                    clip: true

                    // Album Artwork Image (High-Res from pipeline)
                    Image {
                        id: coverImage
                        anchors.fill: parent
                        source: root.highResArtwork !== "" ? root.highResArtwork : (root.artwork !== "" ? root.artwork : "")
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                        mipmap: true
                        smooth: true
                    }

                    // Fallback Gradient if image is loading or empty
                    Rectangle {
                        anchors.fill: parent
                        visible: coverImage.status !== Image.Ready || (root.highResArtwork === "" && root.artwork === "")
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "#23212b" }
                            GradientStop { position: 1.0; color: "#14131a" }
                        }
                        Text {
                            anchors.centerIn: parent
                            text: root.playerIcon(root.cleanIdentity)
                            font.family: NexaUI.NexaTypography.familyIcon
                            font.pixelSize: 68
                            color: Qt.rgba(255, 255, 255, 0.15)
                        }
                    }

                    // Top-Left Glass Pill Badge: // NOW PLAYING / PAUSED
                    Rectangle {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.margins: 18
                        height: 28
                        radius: 14
                        color: Qt.rgba(12 / 255, 12 / 255, 16 / 255, 0.75)
                        border.width: 1
                        border.color: Qt.rgba(255, 255, 255, 0.14)

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 12
                            spacing: 6

                            // Pulsing Matugen Status Beacon
                            Rectangle {
                                width: 7
                                height: 7
                                radius: 3.5
                                color: root.playing ? NexaUI.NexaColors.primary : NexaUI.NexaColors.mutedText

                                SequentialAnimation on opacity {
                                    running: root.playing
                                    loops: Animation.Infinite
                                    NumberAnimation { from: 1.0; to: 0.35; duration: 900; easing.type: Easing.InOutQuad }
                                    NumberAnimation { from: 0.35; to: 1.0; duration: 900; easing.type: Easing.InOutQuad }
                                }
                            }

                            Text {
                                text: root.playing ? "// NOW PLAYING" : "// PAUSED"
                                color: NexaUI.NexaColors.text
                                font.family: NexaUI.NexaTypography.familyMono
                                font.pixelSize: 10
                                font.weight: NexaUI.NexaTypography.weightSemiBold
                                font.letterSpacing: 0.8
                            }
                        }
                    }

                    // Bottom Gradient Scrim & Mini Track Preview
                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 94
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "transparent" }
                            GradientStop { position: 0.35; color: Qt.rgba(10 / 255, 10 / 255, 14 / 255, 0.65) }
                            GradientStop { position: 1.0; color: Qt.rgba(8 / 255, 8 / 255, 12 / 255, 0.95) }
                        }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 16
                            anchors.bottomMargin: 18
                            spacing: 3

                            Text {
                                Layout.fillWidth: true
                                text: root.title
                                color: NexaUI.NexaColors.text
                                font.family: NexaUI.NexaTypography.familyBody
                                font.pixelSize: 13
                                font.weight: NexaUI.NexaTypography.weightSemiBold
                                elide: Text.ElideRight
                            }

                            RowLayout {
                                spacing: 5
                                Text {
                                    text: "◉"
                                    color: NexaUI.NexaColors.primary
                                    font.pixelSize: 9
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: root.artist
                                    color: NexaUI.NexaColors.mutedText
                                    font.family: NexaUI.NexaTypography.familyBody
                                    font.pixelSize: 11
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }

                    // Separator hairline between left and right column
                    Rectangle {
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.right: parent.right
                        width: 1
                        color: Qt.rgba(255, 255, 255, 0.08)
                    }
                }

                // ----------------------------------------------------
                // RIGHT COLUMN: STUDIO CONTROL DECK (~60% Width)
                // ----------------------------------------------------
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.margins: 18
                    Layout.leftMargin: 20
                    Layout.rightMargin: 20
                    spacing: 8

                    // ================================================
                    // 1. HEADER: SOURCE INDICATOR
                    // ================================================
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        RowLayout {
                            spacing: 7
                            Text {
                                text: "— " + root.playerIcon(root.cleanIdentity)
                                color: NexaUI.NexaColors.primary
                                font.family: NexaUI.NexaTypography.familyIcon
                                font.pixelSize: 14
                                font.weight: NexaUI.NexaTypography.weightBold
                            }
                            Text {
                                text: root.cleanIdentity.toUpperCase()
                                color: NexaUI.NexaColors.mutedText
                                font.family: NexaUI.NexaTypography.familyMono
                                font.pixelSize: 11
                                font.weight: NexaUI.NexaTypography.weightSemiBold
                                font.letterSpacing: 1.2
                            }
                        }

                        Item { Layout.fillWidth: true }
                    }

                    Item { height: 2 }

                    // ================================================
                    // 2. HERO TRACK TYPOGRAPHY
                    // ================================================
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Text {
                            Layout.fillWidth: true
                            text: root.title
                            color: NexaUI.NexaColors.text
                            font.family: NexaUI.NexaTypography.familyDisplay
                            font.pixelSize: 18
                            font.weight: NexaUI.NexaTypography.weightBold
                            font.letterSpacing: -0.3
                            elide: Text.ElideRight
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 7

                            Text {
                                text: "◉"
                                color: NexaUI.NexaColors.primary
                                font.pixelSize: 10
                            }

                            Text {
                                Layout.fillWidth: true
                                text: root.artist + (root.album !== "" ? ("  •  " + root.album) : "")
                                color: NexaUI.NexaColors.mutedText
                                font.family: NexaUI.NexaTypography.familyBody
                                font.pixelSize: 12
                                font.weight: NexaUI.NexaTypography.weightMedium
                                elide: Text.ElideRight
                            }
                        }
                    }

                    // Flexible Spacer: Pushes Progress Bar & Controls to Bottom
                    Item { Layout.fillHeight: true }

                    // ================================================
                    // 3. PROGRESS BAR (Lowered right above controls)
                    // ================================================
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            // Elapsed Monospace Timestamp
                            Text {
                                text: root.formatTime(root.displayedPosition)
                                color: NexaUI.NexaColors.mutedText
                                font.family: NexaUI.NexaTypography.familyMono
                                font.pixelSize: 12
                                font.weight: NexaUI.NexaTypography.weightMedium
                                font.features: NexaUI.NexaTypography.fontFeaturesTnum
                            }

                            // Interactive Straight Rail Progress Bar
                            Item {
                                id: scrubberTrack
                                Layout.fillWidth: true
                                Layout.preferredHeight: 20

                                // Background Rail
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: parent.width
                                    height: 4
                                    radius: 2
                                    color: NexaUI.NexaColors.alpha(NexaUI.NexaColors.primary, 0.18)

                                    // Active Elapsed Progress Fill
                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.top: parent.top
                                        anchors.bottom: parent.bottom
                                        width: parent.width * root.displayedProgress
                                        radius: 2
                                        color: NexaUI.NexaColors.primary
                                    }

                                    // Precision Scrubber Thumb Handle
                                    Rectangle {
                                        width: 12
                                        height: 12
                                        radius: 6
                                        x: (parent.width * root.displayedProgress) - (width / 2)
                                        anchors.verticalCenter: parent.verticalCenter
                                        color: NexaUI.NexaColors.primary
                                        border.width: 2
                                        border.color: "#ffffff"
                                        scale: scrubMouse.containsMouse || scrubMouse.pressed ? 1.3 : 1.0
                                        Behavior on scale { NumberAnimation { duration: 150 } }
                                    }
                                }

                                MouseArea {
                                    id: scrubMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onPressed: mouse => {
                                        root.scrubbing = true
                                        const frac = Math.max(0, Math.min(1, mouse.x / width))
                                        root.scrubPosition = frac * root.duration
                                    }
                                    onPositionChanged: mouse => {
                                        if (pressed) {
                                            const frac = Math.max(0, Math.min(1, mouse.x / width))
                                            root.scrubPosition = frac * root.duration
                                        }
                                    }
                                    onReleased: mouse => {
                                        const frac = Math.max(0, Math.min(1, mouse.x / width))
                                        root.seek(frac * root.duration)
                                        root.scrubbing = false
                                    }
                                }
                            }

                            // Total Duration Monospace Timestamp
                            Text {
                                text: root.formatTime(root.duration)
                                color: NexaUI.NexaColors.mutedText
                                font.family: NexaUI.NexaTypography.familyMono
                                font.pixelSize: 12
                                font.weight: NexaUI.NexaTypography.weightMedium
                                font.features: NexaUI.NexaTypography.fontFeaturesTnum
                            }
                        }

                        // Context Row: Album / Next Track Hint
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            opacity: 0.55

                            Text {
                                text: "󰒝"
                                color: NexaUI.NexaColors.mutedText
                                font.family: NexaUI.NexaTypography.familyIcon
                                font.pixelSize: 11
                            }
                            Text {
                                text: root.album !== "" ? ("ALBUM: " + root.album) : "LOSSLESS HIGH-FIDELITY"
                                color: NexaUI.NexaColors.mutedText
                                font.family: NexaUI.NexaTypography.familyBody
                                font.pixelSize: 11
                                font.weight: NexaUI.NexaTypography.weightMedium
                                font.letterSpacing: 0.5
                                elide: Text.ElideRight
                            }
                        }
                    }

                    Item { height: 2 }

                    // ================================================
                    // 4. TACTILE CONTROLS DECK & INLINE VOLUME
                    // ================================================
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 16

                        // Left: Playback Control Cluster
                        RowLayout {
                            spacing: 12

                            // Shuffle Button
                            Rectangle {
                                width: 36
                                height: 36
                                radius: 18
                                color: root.shuffle 
                                    ? NexaUI.NexaColors.alpha(NexaUI.NexaColors.primary, 0.22) 
                                    : (shuffHover.hovered ? NexaUI.NexaColors.surfaceContainerHigh : "transparent")

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰒝"
                                    font.family: NexaUI.NexaTypography.familyIcon
                                    font.pixelSize: 16
                                    color: root.shuffle ? NexaUI.NexaColors.primary : NexaUI.NexaColors.mutedText
                                }

                                MouseArea {
                                    id: shuffHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.toggleShuffle()
                                }
                            }

                            // Previous Track
                            Rectangle {
                                width: 38
                                height: 38
                                radius: 19
                                color: prevHover.hovered ? NexaUI.NexaColors.surfaceContainerHigh : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰒮"
                                    font.family: NexaUI.NexaTypography.familyIcon
                                    font.pixelSize: 20
                                    color: NexaUI.NexaColors.text
                                }

                                MouseArea {
                                    id: prevHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.previous()
                                }
                            }

                            // HERO PLAY / PAUSE PILL BUTTON
                            Rectangle {
                                id: heroPlayPill
                                width: 62
                                height: 40
                                radius: 20
                                color: NexaUI.NexaColors.primary
                                scale: playMouse.pressed ? 0.94 : (playMouse.hovered ? 1.04 : 1.0)
                                Behavior on scale { NumberAnimation { duration: 120 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: root.playing ? "󰏤" : "󰐊"
                                    font.family: NexaUI.NexaTypography.familyIcon
                                    font.pixelSize: 20
                                    color: NexaUI.NexaColors.onPrimary
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
                                width: 38
                                height: 38
                                radius: 19
                                color: nextHover.hovered ? NexaUI.NexaColors.surfaceContainerHigh : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰒭"
                                    font.family: NexaUI.NexaTypography.familyIcon
                                    font.pixelSize: 20
                                    color: NexaUI.NexaColors.text
                                }

                                MouseArea {
                                    id: nextHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.next()
                                }
                            }

                            // Repeat / Loop Button
                            Rectangle {
                                width: 36
                                height: 36
                                radius: 18
                                color: root.loopStatus !== "None" 
                                    ? NexaUI.NexaColors.alpha(NexaUI.NexaColors.primary, 0.22) 
                                    : (repHover.hovered ? NexaUI.NexaColors.surfaceContainerHigh : "transparent")

                                Text {
                                    anchors.centerIn: parent
                                    text: root.loopStatus === "Track" ? "󰑘" : "󰑖"
                                    font.family: NexaUI.NexaTypography.familyIcon
                                    font.pixelSize: 16
                                    color: root.loopStatus !== "None" ? NexaUI.NexaColors.primary : NexaUI.NexaColors.mutedText
                                }

                                MouseArea {
                                    id: repHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.cycleLoop()
                                    }
                                }
                            }
                        }

                        Item { Layout.fillWidth: true }

                        // Right: Inline Volume Scrubber
                        RowLayout {
                            id: volDeck
                            spacing: 8

                            readonly property real masterVol: {
                                if (typeof Services !== "undefined" && Services.SystemState && Services.SystemState.volume >= 0) {
                                    return Services.SystemState.volume / 100.0
                                }
                                if (root.available && root.player && root.player.volumeSupported) return root.player.volume
                                return 0.8
                            }

                            function applyVol(posX, trackW) {
                                const frac = Math.max(0.0, Math.min(1.0, posX / trackW))
                                const pct = Math.round(frac * 100)
                                if (typeof Services !== "undefined" && Services.SystemState) {
                                    Services.SystemState.volume = pct
                                }
                                Quickshell.execDetached([root.nexadBin, "audio", "set", pct.toString()])
                                if (root.available && root.player && root.player.volumeSupported) {
                                    root.player.volume = frac
                                }
                            }

                            Item {
                                width: 20
                                height: 20

                                Text {
                                    anchors.centerIn: parent
                                    text: volDeck.masterVol <= 0.01 ? "󰝟" : (volDeck.masterVol < 0.5 ? "󰕿" : "󰕾")
                                    font.family: NexaUI.NexaTypography.familyIcon
                                    color: volIconMouse.containsMouse ? NexaUI.NexaColors.primary : NexaUI.NexaColors.mutedText
                                    font.pixelSize: 16
                                }

                                MouseArea {
                                    id: volIconMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        Quickshell.execDetached([root.nexadBin, "audio", "toggle-mute"])
                                    }
                                }
                            }

                            Item {
                                id: volTrack
                                width: 78
                                height: 20

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: parent.width
                                    height: 4
                                    radius: 2
                                    color: NexaUI.NexaColors.alpha(NexaUI.NexaColors.primary, 0.18)

                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.top: parent.top
                                        anchors.bottom: parent.bottom
                                        width: parent.width * volDeck.masterVol
                                        radius: 2
                                        color: NexaUI.NexaColors.primary
                                    }

                                    Rectangle {
                                        width: 10
                                        height: 10
                                        radius: 5
                                        x: (parent.width * volDeck.masterVol) - (width / 2)
                                        anchors.verticalCenter: parent.verticalCenter
                                        color: "#ffffff"
                                        scale: volMouse.containsMouse || volMouse.pressed ? 1.25 : 1.0
                                        Behavior on scale { NumberAnimation { duration: 150 } }
                                    }
                                }

                                MouseArea {
                                    id: volMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: mouse => volDeck.applyVol(mouse.x, width)
                                    onPositionChanged: mouse => {
                                        if (pressed) volDeck.applyVol(mouse.x, width)
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
