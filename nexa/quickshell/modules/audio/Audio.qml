import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root


    // ============================================================
    // OUTPUT STATE
    // ============================================================

    property int volume: 0
    property bool muted: false


    // ============================================================
    // INPUT STATE
    // ============================================================

    property int inputVolume: 0
    property bool inputMuted: false


    // ============================================================
    // APPLICATION STATE
    // ============================================================

    property var apps: []
    property var sinks: []
    property real micPeak: 0.0
    property bool micMonitorActive: true


    // ============================================================
    // LOADING
    // ============================================================

    property bool loading: false
    property bool inputLoading: false
    property bool appsLoading: false


    readonly property string nexad:
        Quickshell.env("HOME")
        + "/.config/nexa/rust/target/release/nexad"


    // ============================================================
    // OUTPUT
    // ============================================================

    function refresh() {
        if (masterInfo.running)
            return

        loading = true
        masterInfo.running = true
    }


    function setVolume(value) {
        const clamped =
            Math.max(
                0,
                Math.min(
                    100,
                    Math.round(value)
                )
            )

        volume = clamped
        pendingVolume = clamped

        volumeTimer.restart()
    }


    function setVolumeImmediate(value) {
        const clamped =
            Math.max(
                0,
                Math.min(
                    100,
                    Math.round(value)
                )
            )

        volume = clamped
        pendingVolume = clamped

        volumeTimer.stop()

        Quickshell.execDetached([
            nexad,
            "audio",
            "set",
            clamped.toString()
        ])
    }


    function toggleMute() {
        muted = !muted

        Quickshell.execDetached([
            nexad,
            "audio",
            "toggle-mute"
        ])

        masterRefreshDelay.restart()
    }


    function refreshSinks() {
        if (!sinksProcess.running)
            sinksProcess.running = true
    }


    function setSink(id) {
        Quickshell.execDetached([
            nexad,
            "audio",
            "set-sink",
            id.toString()
        ])

        sinksRefreshDelay.restart()
        masterRefreshDelay.restart()
    }


    // ============================================================
    // INPUT / MICROPHONE
    // ============================================================

    function refreshInput() {
        if (inputInfo.running)
            return

        inputLoading = true
        inputInfo.running = true
    }


    function setInputVolume(value) {
        const clamped =
            Math.max(
                0,
                Math.min(
                    100,
                    Math.round(value)
                )
            )

        inputVolume = clamped
        pendingInputVolume = clamped

        inputVolumeTimer.restart()
    }


    function setInputVolumeImmediate(value) {
        const clamped =
            Math.max(
                0,
                Math.min(
                    100,
                    Math.round(value)
                )
            )

        inputVolume = clamped
        pendingInputVolume = clamped

        inputVolumeTimer.stop()

        Quickshell.execDetached([
            nexad,
            "audio",
            "input-set",
            clamped.toString()
        ])
    }


    function toggleInputMute() {
        inputMuted = !inputMuted

        Quickshell.execDetached([
            nexad,
            "audio",
            "input-toggle-mute"
        ])

        inputRefreshDelay.restart()
    }


    // ============================================================
    // APPLICATION AUDIO
    // ============================================================

    function refreshApps() {
        if (appInfo.running)
            return

        appsLoading = true
        appInfo.running = true
    }


    function setAppVolume(id, value) {
        const clamped =
            Math.max(
                0,
                Math.min(
                    100,
                    Math.round(value)
                )
            )

        pendingAppId = id
        pendingAppVolume = clamped

        appVolumeTimer.restart()
    }


    function setAppVolumeImmediate(id, value) {
        const clamped =
            Math.max(
                0,
                Math.min(
                    100,
                    Math.round(value)
                )
            )

        pendingAppId = id
        pendingAppVolume = clamped

        appVolumeTimer.stop()

        Quickshell.execDetached([
            nexad,
            "audio",
            "app-set",
            id.toString(),
            clamped.toString()
        ])

        appsRefreshDelay.restart()
    }


    function toggleAppMute(id) {
        Quickshell.execDetached([
            nexad,
            "audio",
            "app-toggle-mute",
            id.toString()
        ])

        appsRefreshDelay.restart()
    }


    // ============================================================
    // PENDING VALUES
    // ============================================================

    property int pendingVolume: 0
    property int pendingInputVolume: 0

    property int pendingAppId: -1
    property int pendingAppVolume: 0


    // ============================================================
    // OUTPUT INFO
    // ============================================================

    Process {
        id: masterInfo

        command: [
            root.nexad,
            "audio",
            "info"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                root.loading = false

                try {
                    const data =
                        JSON.parse(text)

                    root.volume =
                        Number(
                            data.volume ?? 0
                        )

                    root.muted =
                        Boolean(
                            data.muted
                        )

                } catch (error) {
                    console.warn(
                        "[NEXA Audio] Output parse failed:",
                        error,
                        text
                    )
                }
            }
        }
    }


    // ============================================================
    // INPUT INFO
    // ============================================================

    Process {
        id: inputInfo

        command: [
            root.nexad,
            "audio",
            "input-info"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                root.inputLoading = false

                try {
                    const data =
                        JSON.parse(text)

                    root.inputVolume =
                        Number(
                            data.volume ?? 0
                        )

                    root.inputMuted =
                        Boolean(
                            data.muted
                        )

                } catch (error) {
                    console.warn(
                        "[NEXA Audio] Input parse failed:",
                        error,
                        text
                    )
                }
            }
        }
    }


    // ============================================================
    // APPLICATION INFO
    // ============================================================

    Process {
        id: appInfo

        command: [
            root.nexad,
            "audio",
            "apps"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                root.appsLoading = false

                try {
                    const data =
                        JSON.parse(text)

                    root.apps =
                        Array.isArray(data)
                        ? data
                        : []

                } catch (error) {
                    root.apps = []

                    console.warn(
                        "[NEXA Audio] Apps parse failed:",
                        error,
                        text
                    )
                }
            }
        }
    }


    // ============================================================
    // OUTPUT THROTTLE
    // ============================================================

    Timer {
        id: volumeTimer

        interval: 70
        repeat: false

        onTriggered: {
            Quickshell.execDetached([
                root.nexad,
                "audio",
                "set",
                root.pendingVolume.toString()
            ])
        }
    }


    // ============================================================
    // INPUT THROTTLE
    // ============================================================

    Timer {
        id: inputVolumeTimer

        interval: 70
        repeat: false

        onTriggered: {
            Quickshell.execDetached([
                root.nexad,
                "audio",
                "input-set",
                root.pendingInputVolume.toString()
            ])
        }
    }


    // ============================================================
    // APP THROTTLE
    // ============================================================

    Timer {
        id: appVolumeTimer

        interval: 70
        repeat: false

        onTriggered: {
            if (root.pendingAppId < 0)
                return

            Quickshell.execDetached([
                root.nexad,
                "audio",
                "app-set",
                root.pendingAppId.toString(),
                root.pendingAppVolume.toString()
            ])
        }
    }


    // ============================================================
    // DELAYED REFRESH
    // ============================================================

    Timer {
        id: masterRefreshDelay

        interval: 120
        repeat: false

        onTriggered:
            root.refresh()
    }


    Timer {
        id: inputRefreshDelay

        interval: 120
        repeat: false

        onTriggered:
            root.refreshInput()
    }


    Timer {
        id: appsRefreshDelay

        interval: 120
        repeat: false

        onTriggered:
            root.refreshApps()
    }


    Process {
        id: sinksProcess
        running: false
        command: [
            root.nexad,
            "audio",
            "sinks"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const text = this.text.trim()
                    if (text.length > 0)
                        root.sinks = JSON.parse(text)
                } catch (e) {
                    console.error("[Audio:Sinks]", e)
                }
            }
        }
    }

    Timer {
        id: sinksRefreshDelay
        interval: 250
        repeat: false
        onTriggered: root.refreshSinks()
    }

    Process {
        id: micMonitorProcess
        running: !root.inputMuted && root.micMonitorActive
        command: [
            root.nexad,
            "audio",
            "mic-monitor"
        ]

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                const val = parseFloat(data.trim())
                if (!isNaN(val)) {
                    root.micPeak = Math.max(0.0, Math.min(1.0, val))
                }
            }
        }

        onRunningChanged: {
            if (!running) root.micPeak = 0.0
        }
    }

    // ============================================================
    // LIVE STATE
    // ============================================================

    Timer {
        interval: 1000
        repeat: true
        running: true

        onTriggered: {
            root.refresh()
            root.refreshInput()
            root.refreshSinks()
        }
    }

    Component.onCompleted: {
        root.refresh()
        root.refreshInput()
        root.refreshSinks()
    }
}
