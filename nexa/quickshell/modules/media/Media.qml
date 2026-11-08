import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQml.Models
import Qt5Compat.GraphicalEffects
import QtQuick.Effects

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

    property string presentation: "compact"

    readonly property string nexadBin: Quickshell.env("HOME") + "/.config/nexa/rust/target/release/nexad"

    // ============================================================
    // COMPACT CLOCK & AUDIO REACTIVITY
    // ============================================================

    property date currentTime: new Date()

    Timer {
        id: compactClockTimer
        interval: 1000
        running: root.presentation === "compact" && root.visible
        repeat: true
        onTriggered: root.currentTime = new Date()
    }

    // Audio reactivity levels from live CAVA stream (native Rust bass calculation)
    readonly property real bassLevel: root.playing ? Services.AudioVisualizer.bass : 0.0

    // Symmetrical 44-ray bottom spectrum mapping (bass in center, rolling off toward edges)
    function rayLevel(i) {
        if (!root.playing || !Services.AudioVisualizer.bars || Services.AudioVisualizer.bars.length === 0)
            return 0.0;
        const bars = Services.AudioVisualizer.bars;
        const n = bars.length;
        const half = 22;
        const pos = (i < half) ? (half - 1 - i) / half : (i - half) / half;
        const f = pos * (n - 1);
        const a = Math.floor(f);
        const b = Math.min(n - 1, a + 1);
        const frac = f - a;
        const raw = Number(bars[a] || 0) + (Number(bars[b] || 0) - Number(bars[a] || 0)) * frac;
        return Math.max(0.0, Math.min(1.0, raw));
    }

    // Dynamic corner radius following NexaUI tokens and user settings
    readonly property real effectiveRadius: {
        if (NexaUI.NexaTokens.islandRounding === 0) return 0;
        if (root.presentation === "compact") {
            return (NexaUI.NexaTokens.islandRounding >= 999)
                ? Math.round(root.height / 2)
                : Math.min(Math.round(root.height / 2), NexaUI.NexaTokens.islandRounding);
        }
        return (NexaUI.NexaTokens.islandRounding >= 999) ? 26 : NexaUI.NexaTokens.islandRounding;
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
        root._stateTrigger++
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
                root._stateTrigger++
                root.handlePlayerStateChanged(modelData)
            }
            function onTrackTitleChanged() {
                root._stateTrigger++
                root.handlePlayerMetadataChanged(modelData)
            }
            function onTrackArtistChanged() {
                root._stateTrigger++
                root.handlePlayerMetadataChanged(modelData)
            }
            function onTrackArtUrlChanged() {
                root._stateTrigger++
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

    property int _stateTrigger: 0

    readonly property bool available: {
        root._stateTrigger;
        return root.player !== null;
    }

    readonly property bool playing: {
        root._stateTrigger;
        return root.available && root.player && root.player.playbackState === MprisPlaybackState.Playing;
    }

    readonly property bool paused: {
        root._stateTrigger;
        return root.available && root.player && root.player.playbackState === MprisPlaybackState.Paused;
    }

    // ------------------------------------------------------------
    // 1-MINUTE PAUSE / IDLE TIMEOUT
    // If music is paused for 1 minute (60,000 ms), the music
    // section is cleared from the Dynamic Island pill, returning it
    // to the normal clock notch.
    // ------------------------------------------------------------

    property bool pauseTimeoutExpired: false

    Timer {
        id: pauseExpiryTimer
        interval: 60000 // 1 minute
        repeat: false
        running: false
        onTriggered: {
            root.pauseTimeoutExpired = true
        }
    }

    function checkPauseTimeoutState() {
        if (!root.available || !root.hasTrack) {
            pauseExpiryTimer.stop()
            root.pauseTimeoutExpired = false
            return
        }

        if (root.playing) {
            pauseExpiryTimer.stop()
            root.pauseTimeoutExpired = false
        } else if (root.paused) {
            if (!root.pauseTimeoutExpired && !pauseExpiryTimer.running) {
                pauseExpiryTimer.restart()
            }
        } else {
            // Player stopped
            pauseExpiryTimer.stop()
            root.pauseTimeoutExpired = true
        }
    }

    onPlayingChanged: {
        if (root.playing) {
            triggerMatugenExtract()
        }
        checkPauseTimeoutState()
    }

    onPausedChanged: {
        checkPauseTimeoutState()
    }

    onAvailableChanged: {
        if (!root.available) {
            root.activePlayerObj = null
        }
        checkPauseTimeoutState()
    }

    onHasTrackChanged: {
        if (!root.hasTrack) {
            NexaUI.NexaColors.resetMediaColors()
            root.lastExtractedKey = ""
        } else {
            triggerMatugenExtract()
        }
        checkPauseTimeoutState()
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
        root.lastExtractedKey = ""
        triggerCoverFetch()
        triggerMatugenExtract()
    }

    onArtistChanged: {
        root.lastExtractedKey = ""
        triggerCoverFetch()
        triggerMatugenExtract()
    }

    onArtworkChanged: {
        root.lastExtractedKey = ""
        triggerCoverFetch()
        triggerMatugenExtract()
    }

    onFetchedCoverUrlChanged: {
        triggerMatugenExtract()
    }

    onPlayerChanged: {
        checkPauseTimeoutState()
        root.fetchedCoverUrl = ""
        root.lastExtractedKey = ""
        triggerCoverFetch()
        triggerMatugenExtract()
    }

    Component.onCompleted: {
        root.evaluateBestPlayer()
        root.checkPauseTimeoutState()
        if (initialPlayerctlProbe) initialPlayerctlProbe.running = true
        triggerCoverFetch()
        triggerMatugenExtract()
    }

    // ============================================================
    // NON-DESTRUCTIVE LOCAL MATUGEN ALBUM ART THEMING (via Rust nexad)
    // ============================================================

    readonly property bool hasAlbumColors: NexaUI.NexaColors.hasMediaColors
    readonly property color albumAccentColor: NexaUI.NexaColors.hasMediaColors ? NexaUI.NexaColors.mediaPrimary : NexaUI.NexaColors.primary
    readonly property color albumSurfaceColor: NexaUI.NexaColors.hasMediaColors ? NexaUI.NexaColors.mediaSurface : NexaUI.NexaColors.islandBackground
    readonly property color albumBorderColor: NexaUI.NexaColors.hasMediaColors ? NexaUI.NexaColors.mediaBorder : NexaUI.NexaColors.border
    property string lastExtractedKey: ""

    Timer {
        id: matugenDebounceTimer
        interval: 150
        repeat: false
        onTriggered: {
            const artSource = (root.highResArtwork && root.highResArtwork !== "") ? root.highResArtwork : root.artwork
            const trackKey = (root.title || "") + "|" + (root.artist || "") + "|" + artSource
            if (!artSource || artSource === "" || trackKey === root.lastExtractedKey) return
            root.lastExtractedKey = trackKey
            matugenProcess.running = false
            matugenProcess.command = [
                root.nexadBin,
                "media",
                "matugen",
                artSource
            ]
            matugenProcess.running = true
        }
    }

    Process {
        id: matugenProcess
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const res = text.trim()
                    if (res !== "" && res.startsWith("{")) {
                        const data = JSON.parse(res)
                        if (data && data.primary) {
                            NexaUI.NexaColors.setMediaColors(data)
                            return
                        }
                    }
                } catch (e) {
                }
                NexaUI.NexaColors.resetMediaColors()
            }
        }
    }

    function triggerMatugenExtract() {
        matugenDebounceTimer.restart()
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

    signal requestBack()
    signal requestOpenClock()

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
    // 1. COMPACT PRESENTATION (Dynamic Island Notch - Phase 1)
    // ============================================================

    Item {
        anchors.fill: parent
        visible: root.presentation === "compact"

        // --------------------------------------------------------
        // LEFT: Album Art Rounded Square Avatar
        // --------------------------------------------------------
        Item {
            id: compactAvatarBox
            width: 20
            height: 20
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            scale: (root.playing ? 1.0 : 0.94) * (1.0 + 0.05 * root.bassLevel)
            Behavior on scale { NumberAnimation { duration: 70; easing.type: Easing.OutQuad } }

            Rectangle {
                id: compactMask
                anchors.fill: parent
                radius: 5
                visible: false
            }

            Image {
                id: compactImg
                anchors.fill: parent
                source: (root.highResArtwork !== "") ? root.highResArtwork : root.artwork
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
                visible: (root.artwork !== "" || root.highResArtwork !== "")
            }

            // Fallback square badge
            Rectangle {
                anchors.fill: parent
                radius: 5
                visible: (root.artwork === "" && root.highResArtwork === "")
                color: NexaUI.NexaColors.surfaceContainerHigh
                border.width: NexaUI.NexaTokens.borderThin
                border.color: NexaUI.NexaColors.border

                Text {
                    anchors.centerIn: parent
                    text: root.playerIcon(root.identity)
                    color: root.albumAccentColor
                    font.family: NexaUI.NexaTypography.familyIcon
                    font.pixelSize: 10
                }
            }

            // Subtle border ring
            Rectangle {
                anchors.fill: parent
                radius: 5
                color: "transparent"
                border.width: 1
                border.color: Qt.rgba(255, 255, 255, 0.18)
            }
        }

        // --------------------------------------------------------
        // CENTER: Clock Time (hh:mm)
        // --------------------------------------------------------
        Text {
            id: compactClockText
            anchors.centerIn: parent
            text: Qt.formatDateTime(root.currentTime, "hh:mm")
            color: NexaUI.NexaColors.text
            font.family: NexaUI.NexaTypography.familyBody
            font.pixelSize: 13
            font.weight: NexaUI.NexaTypography.weightSemiBold
        }

        // --------------------------------------------------------
        // RIGHT: Real-time Audio Visualizer Waveform Bars (CAVA IslandBars)
        // --------------------------------------------------------
        Row {
            id: compactEq
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2.5
            height: 16

            Repeater {
                model: (root.presentation === "compact" && root.playing) ? 5 : 0

                Rectangle {
                    required property int index
                    width: 3
                    radius: 1.5
                    anchors.verticalCenter: parent.verticalCenter

                    readonly property real t: index / 4.0
                    readonly property int bin: Math.round(1 + 8 * t)
                    readonly property real rawVal: (root.playing && Services.AudioVisualizer.bars && Services.AudioVisualizer.bars.length > bin)
                        ? Number(Services.AudioVisualizer.bars[bin])
                        : 0.0
                    readonly property real shape: 0.65 + 0.35 * Math.sin(Math.PI * (0.15 + 0.7 * t))
                    readonly property real v: Math.min(1.0, rawVal * 1.35 * shape)

                    height: Math.max(3, Math.round(3 + v * 13))

                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.lighter(root.albumAccentColor, 1.25) }
                        GradientStop { position: 1.0; color: Qt.darker(root.albumAccentColor, 1.15) }
                    }

                    Behavior on height {
                        NumberAnimation {
                            duration: 65
                            easing.type: Easing.OutQuad
                        }
                    }
                }
            }
        }
    }

    // ============================================================
    // 2. HOVER PRESENTATION (Dynamic Island Expansion - Phase 2)
    // ============================================================

    Item {
        anchors.fill: parent
        visible: root.presentation === "hover"

        // --------------------------------------------------------
        // ATMOSPHERIC AMBIENT GLOW & FOG BACKDROP
        // --------------------------------------------------------

        // Blurred Artwork Fog Backdrop
        Image {
            id: hoverFogArt
            anchors.fill: parent
            source: root.highResArtwork !== "" ? root.highResArtwork : root.artwork
            fillMode: Image.PreserveAspectCrop
            visible: false
            asynchronous: true
        }

        Rectangle {
            id: hoverFogMask
            anchors.fill: parent
            radius: root.effectiveRadius
            antialiasing: root.effectiveRadius > 0
            visible: false
        }

        MultiEffect {
            anchors.fill: parent
            source: hoverFogArt
            maskEnabled: true
            maskSource: hoverFogMask
            autoPaddingEnabled: false
            visible: (root.artwork !== "" || root.highResArtwork !== "") && root.playing
            opacity: 0.32 + 0.14 * root.bassLevel
            blurEnabled: true
            blurMax: 32
            blur: 1.0
            saturation: 0.55
            layer.enabled: true
            Behavior on opacity { NumberAnimation { duration: 300 } }
        }

        // Dark Horizontal Vignette Gradient
        Rectangle {
            anchors.fill: parent
            radius: root.effectiveRadius
            antialiasing: root.effectiveRadius > 0
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.20) }
                GradientStop { position: 0.45; color: Qt.rgba(0, 0, 0, 0.65) }
                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.88) }
            }
        }

        // Top edge specular accent highlight line
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: Math.max(12, root.effectiveRadius)
            anchors.rightMargin: Math.max(12, root.effectiveRadius)
            height: 1
            opacity: root.hasAlbumColors ? 0.45 : 0.20
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.2; color: Qt.lighter(root.albumAccentColor, 1.3) }
                GradientStop { position: 0.8; color: Qt.rgba(root.albumAccentColor.r, root.albumAccentColor.g, root.albumAccentColor.b, 0.3) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        // --------------------------------------------------------
        // FULL-WIDTH BOTTOM AUDIO SPECTRUM (44-Ray Ambient Floor Wave)
        // --------------------------------------------------------
        Row {
            visible: root.presentation === "hover"
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 0
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 5
            opacity: root.playing ? 0.28 : 0.08
            Behavior on opacity { NumberAnimation { duration: 300 } }
            z: 1

            Repeater {
                model: (root.presentation === "hover" && root.playing) ? 44 : 0

                Rectangle {
                    required property int index
                    readonly property real v: root.rayLevel(index)
                    anchors.bottom: parent.bottom
                    width: 5
                    height: Math.max(3, Math.round(3 + v * 36))
                    radius: 2.5
                    antialiasing: true
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.lighter(root.albumAccentColor, 1.45) }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                    Behavior on height {
                        NumberAnimation { duration: 65; easing.type: Easing.OutQuad }
                    }
                }
            }
        }

        // --------------------------------------------------------
        // TOP ROW: Sculpted Artwork Pedestal + Metadata + Visualizer
        // --------------------------------------------------------

        // Sculpted Artwork Deck Pedestal (Outer Beveled Frame)
        Item {
            id: hoverArtDeck
            anchors.left: parent.left
            anchors.leftMargin: 18
            anchors.top: parent.top
            anchors.topMargin: 12
            width: 72
            height: 72
            z: 2

            // Ambient glow shadow beneath artwork pedestal
            RectangularShadow {
                anchors.centerIn: parent
                width: parent.width
                height: parent.height
                radius: 16
                blur: 20
                color: Qt.rgba(root.albumAccentColor.r, root.albumAccentColor.g, root.albumAccentColor.b, 0.45)
            }

            // Concentric beat pulse ring
            Rectangle {
                anchors.centerIn: parent
                width: parent.width + 8 + root.bassLevel * 8
                height: width
                radius: 20
                color: "transparent"
                border.width: 1.5
                border.color: Qt.lighter(root.albumAccentColor, 1.3)
                opacity: (0.12 + 0.45 * root.bassLevel) * (root.playing ? 1.0 : 0.0)
                Behavior on width { NumberAnimation { duration: 65; easing.type: Easing.OutQuad } }
            }

            // Outer soft ambient glow rim
            Rectangle {
                anchors.fill: parent
                radius: 16
                color: Qt.rgba(root.albumAccentColor.r, root.albumAccentColor.g, root.albumAccentColor.b, 0.18)
                border.width: 1.5
                border.color: Qt.rgba(root.albumAccentColor.r, root.albumAccentColor.g, root.albumAccentColor.b, 0.45)
            }

            // Inner artwork mask
            Rectangle {
                id: hoverArtMask
                anchors.fill: parent
                anchors.margins: 4
                radius: 12
                visible: false
            }

            Image {
                id: hoverArtImg
                anchors.fill: parent
                anchors.margins: 4
                source: root.highResArtwork !== "" ? root.highResArtwork : root.artwork
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                mipmap: true
                sourceSize: Qt.size(160, 160)
                smooth: true
                visible: false
                scale: (root.playing ? 1.0 : 0.94) * (1.0 + 0.035 * root.bassLevel)
                Behavior on scale { NumberAnimation { duration: 70; easing.type: Easing.OutQuad } }
            }

            OpacityMask {
                anchors.fill: parent
                anchors.margins: 4
                source: hoverArtImg
                maskSource: hoverArtMask
                visible: root.artwork !== "" || root.highResArtwork !== ""
            }

            // Fallback badge if no artwork
            Rectangle {
                anchors.fill: parent
                anchors.margins: 4
                radius: 12
                visible: root.artwork === "" && root.highResArtwork === ""
                color: NexaUI.NexaColors.surfaceContainerHigh

                Text {
                    anchors.centerIn: parent
                    text: root.playerIcon(root.identity)
                    color: root.albumAccentColor
                    font.family: NexaUI.NexaTypography.familyIcon
                    font.pixelSize: NexaUI.NexaTypography.sizeXl
                }
            }
        }

        // Top-Right: 6-Bar Symmetrical Audio Visualizer Waveform (IslandBars style)
        Row {
            id: hoverTopEq
            anchors.right: parent.right
            anchors.rightMargin: 18
            anchors.verticalCenter: hoverArtDeck.verticalCenter
            spacing: 3.5
            height: 36
            z: 2

            Repeater {
                model: (root.presentation === "hover" && root.playing) ? 6 : 0

                Item {
                    required property int index
                    width: 4
                    height: parent.height
                    anchors.verticalCenter: parent.verticalCenter

                    readonly property real t: index / 5.0
                    readonly property int bin: Math.round(1 + 14 * t)
                    readonly property real rawVal: (root.playing && Services.AudioVisualizer.bars && Services.AudioVisualizer.bars.length > bin)
                        ? Number(Services.AudioVisualizer.bars[bin])
                        : 0.0
                    readonly property real shape: 0.62 + 0.38 * Math.sin(Math.PI * (0.15 + 0.7 * t))
                    readonly property real v: Math.min(1.0, rawVal * 1.35 * shape)
                    readonly property real barH: Math.max(6, Math.round(6 + v * 26))

                    // Neon glow halo underlay
                    Rectangle {
                        anchors.centerIn: parent
                        width: 6
                        height: parent.barH + 4
                        radius: NexaUI.NexaTokens.radiusPill
                        color: root.albumAccentColor
                        opacity: root.playing ? 0.35 : 0.0

                        Behavior on height {
                            NumberAnimation { duration: 65; easing.type: Easing.OutQuad }
                        }
                    }

                    // Solid 3D gradient bar
                    Rectangle {
                        anchors.centerIn: parent
                        width: 4
                        height: parent.barH
                        radius: NexaUI.NexaTokens.radiusPill
                        antialiasing: true
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Qt.lighter(root.albumAccentColor, 1.25) }
                            GradientStop { position: 1.0; color: Qt.darker(root.albumAccentColor, 1.15) }
                        }

                        Behavior on height {
                            NumberAnimation { duration: 65; easing.type: Easing.OutQuad }
                        }
                    }
                }
            }
        }

        // Center: Metadata Stack (Player Tag, Title, Artist)
        Column {
            anchors.left: hoverArtDeck.right
            anchors.leftMargin: 16
            anchors.right: hoverTopEq.left
            anchors.rightMargin: 16
            anchors.verticalCenter: hoverArtDeck.verticalCenter
            spacing: 3
            z: 2

            // 1. Service / Player Tag (e.g. "SPOTIFY")
            Text {
                text: root.cleanIdentity.toUpperCase()
                color: Qt.rgba(255, 255, 255, 0.45)
                font.family: NexaUI.NexaTypography.familyBody
                font.pixelSize: 10
                font.weight: NexaUI.NexaTypography.weightBold
                font.letterSpacing: 1.6
            }

            // 2. Track Title (with Marquee if overflowing)
            Item {
                id: hoverTitleBox
                width: parent.width
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
                    font.pixelSize: 18
                    font.weight: NexaUI.NexaTypography.weightBold
                }

                SequentialAnimation {
                    id: hoverTitleAnim
                    running: hoverTitleBox.needsScroll && root.presentation === "hover" && root.visible
                    loops: Animation.Infinite

                    PauseAnimation { duration: 2000 }
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

            // 3. Artist Name in album accent color
            Text {
                width: parent.width
                text: root.artist
                color: Qt.lighter(root.albumAccentColor, 1.35)
                font.family: NexaUI.NexaTypography.familyBody
                font.pixelSize: 13
                font.weight: NexaUI.NexaTypography.weightMedium
                elide: Text.ElideRight
            }
        }

        // --------------------------------------------------------
        // MIDDLE ROW: Full-Width Glowing Laser Seekbar
        // --------------------------------------------------------
        RowLayout {
            id: hoverSeekRow
            anchors.left: parent.left
            anchors.leftMargin: 18
            anchors.right: parent.right
            anchors.rightMargin: 18
            anchors.top: hoverArtDeck.bottom
            anchors.topMargin: 8
            spacing: 10
            z: 2

            // Left Elapsed Timestamp
            Text {
                text: root.formatTime(root.displayedPosition)
                color: Qt.rgba(255, 255, 255, 0.5)
                font.family: NexaUI.NexaTypography.familyMono
                font.pixelSize: 10
                font.features: NexaUI.NexaTypography.fontFeaturesTnum
            }

            // Interactive Progress Bar with Neon Laser Bloom
            Item {
                id: hoverProgressBar
                Layout.fillWidth: true
                implicitHeight: 14

                // Rail (unfilled track)
                Rectangle {
                    id: hoverRail
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    height: 3.5
                    radius: NexaUI.NexaTokens.radiusPill
                    color: Qt.rgba(255, 255, 255, 0.15)
                }

                // Laser glow shadow halo
                RectangularShadow {
                    anchors.left: hoverRail.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(hoverRail.height, hoverRail.width * root.displayedProgress)
                    height: hoverRail.height
                    radius: hoverRail.height / 2
                    blur: 10 + 6 * root.bassLevel
                    color: Qt.rgba(root.albumAccentColor.r, root.albumAccentColor.g, root.albumAccentColor.b, 0.65)
                }

                // Solid laser core fill with horizontal gradient
                Rectangle {
                    anchors.left: hoverRail.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(hoverRail.height, hoverRail.width * root.displayedProgress)
                    height: hoverRail.height
                    radius: hoverRail.height / 2
                    antialiasing: true
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: root.albumAccentColor }
                        GradientStop { position: 1.0; color: Qt.lighter(root.albumAccentColor, 1.5) }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onPressed: mouse => { root.seeking = true; root.updateSeekFromX(mouse.x, width) }
                    onPositionChanged: mouse => { if (pressed) root.updateSeekFromX(mouse.x, width) }
                    onReleased: root.commitSeek()
                }
            }

            // Right Remaining Timestamp
            Text {
                text: (root.duration > 0 && root.duration >= root.displayedPosition)
                    ? ("-" + root.formatTime(root.duration - root.displayedPosition))
                    : "--:--"
                color: Qt.rgba(255, 255, 255, 0.5)
                font.family: NexaUI.NexaTypography.familyMono
                font.pixelSize: 10
                font.features: NexaUI.NexaTypography.fontFeaturesTnum
            }
        }

        // --------------------------------------------------------
        // BOTTOM ROW: Floating Transport Controls (Above Floor Wave)
        // --------------------------------------------------------
        Item {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: hoverSeekRow.bottom
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 8
            z: 2

            // Transport Controls: Previous | Circular Play/Pause | Next
            Row {
                anchors.centerIn: parent
                spacing: 42

                // Previous Track
                Item {
                    width: 32
                    height: 32
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        anchors.centerIn: parent
                        text: "󰒮"
                        font.family: NexaUI.NexaTypography.familyIcon
                        font.pixelSize: 20
                        color: NexaUI.NexaColors.text
                        opacity: hoverPrevMouse.pressed ? 0.4 : (hoverPrevMouse.containsMouse ? 1.0 : 0.85)
                        Behavior on opacity { NumberAnimation { duration: 100 } }
                    }

                    MouseArea {
                        id: hoverPrevMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: root.available && root.player.canGoPrevious
                        onClicked: root.previous()
                    }
                }

                // Circular Play / Pause Lens Button
                Item {
                    width: 40
                    height: 40
                    anchors.verticalCenter: parent.verticalCenter

                    // Reactive bass ring around play button
                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width * (0.95 + 0.22 * root.bassLevel)
                        height: width
                        radius: width / 2
                        color: Qt.rgba(root.albumAccentColor.r, root.albumAccentColor.g, root.albumAccentColor.b, 0.08)
                        border.width: 1.5
                        border.color: Qt.rgba(root.albumAccentColor.r, root.albumAccentColor.g, root.albumAccentColor.b, 0.35)
                        antialiasing: true
                    }

                    Rectangle {
                        id: hoverPlayBtnBg
                        anchors.fill: parent
                        radius: width / 2
                        color: Qt.rgba(255, 255, 255, hoverPlayMouse.pressed ? 0.24 : (hoverPlayMouse.containsMouse ? 0.18 : 0.12))
                        border.width: 1.5
                        border.color: Qt.rgba(255, 255, 255, 0.28)
                        scale: hoverPlayMouse.pressed ? 0.93 : (hoverPlayMouse.containsMouse ? 1.05 : 1.0)
                        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Text {
                            anchors.centerIn: parent
                            text: root.playing ? "󰏤" : "󰐊"
                            font.family: NexaUI.NexaTypography.familyIcon
                            font.pixelSize: 18
                            color: NexaUI.NexaColors.text
                        }
                    }

                    MouseArea {
                        id: hoverPlayMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: root.available && root.player.canTogglePlaying
                        onClicked: root.togglePlaying()
                    }
                }

                // Next Track
                Item {
                    width: 32
                    height: 32
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        anchors.centerIn: parent
                        text: "󰒭"
                        font.family: NexaUI.NexaTypography.familyIcon
                        font.pixelSize: 20
                        color: NexaUI.NexaColors.text
                        opacity: hoverNextMouse.pressed ? 0.4 : (hoverNextMouse.containsMouse ? 1.0 : 0.85)
                        Behavior on opacity { NumberAnimation { duration: 100 } }
                    }

                    MouseArea {
                        id: hoverNextMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: root.available && root.player.canGoNext
                        onClicked: root.next()
                    }
                }
            }
        }
    }
}
