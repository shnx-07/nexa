import QtQuick
import Quickshell.Io
import Quickshell
import Quickshell.Hyprland

import "../theme" as Nexa


PanelWindow {
    id: root


    readonly property bool notificationActive:
        islandContent.notificationActive
    property bool notificationEventInitialized: false

    // ============================================================
    // RESPONSIBILITY
    //
    // Island.qml owns ONLY:
    //
    // - Wayland window / geometry
    // - Island physical sizes
    // - hover expansion
    // - full expansion
    // - input mask
    // - outside-click close
    // - keyboard focus
    // - Escape close
    //
    // Feature UI DOES NOT belong here.
    // Clock / music / system / theme / notifications etc.
    // belong in IslandContent.qml or reusable modules.
    // ============================================================


    // ============================================================
    // WINDOW / WAYLAND SURFACE
    // ============================================================

    anchors {
        top: true
    }

    // Fixed maximum surface.
    //
    // We DO NOT animate the actual PanelWindow size.
    // Doing that was causing compositor-side lag.
    //
    // The visible Rectangle inside this window is animated instead.
    implicitWidth: 800
    implicitHeight: 660

    margins {
        top: 3

        left: Math.round(
            ((screen ? screen.width : 1920) - implicitWidth) / 2
        )
    }

    color: "transparent"

    exclusionMode: ExclusionMode.Ignore

    aboveWindows: true

    // Keyboard input is only accepted while the full Island is open.
    focusable: root.full || root.specialModeActive


    // ============================================================
    // STATE
    // ============================================================

    property bool hovered: false
    property bool full: false

    // True while the Theme section has a dropdown popup open.
    // Suppresses the outside-click close so the user can browse
    // presets without the Island collapsing.
    readonly property bool themePopupOpen:
        islandContent.themePopupOpen


    // ============================================================
    // SIZE CONSTANTS
    // ============================================================

    readonly property int compactWidth:
        Nexa.Theme.islandCompactWidth

    readonly property int compactHeight:
        Nexa.Theme.islandCompactHeight


    // ============================================================
    // PERSISTENT CONTEXT SIZE
    //
    // Media:
    //     420 x compactHeight
    //     stays visually inside the 36px top bar.
    //
    // Stopwatch:
    //     420 x 44
    //     intentionally uses the taller persistent context.
    //
    // This avoids forcing every contextual module into one height.
    // ============================================================

    readonly property int contextWidth: 420

    readonly property int contextHeight:
        root.compactHeight

    // Confirmed hover dimensions.
    readonly property int hoverWidth: {
        if (islandContent.stopwatchContextActive || islandContent.focusContextActive)
            return 500
        return 420
    }
    readonly property int hoverHeight: 102


    // Confirmed full dimensions.
    readonly property int fullWidth: 720
    readonly property int fullHeight: 400

    // ============================================================
    // APP LAUNCHER DIMENSIONS
    // ============================================================

    readonly property int launcherWidth: 760
    readonly property int launcherHeight: 620

    // ============================================================
    // POWER MODE DIMENSIONS
    //
    // PowerIsland content:
    //   5 × 138px cards = 690
    //   4 × 12px gaps   = 48
    //   content width   = 738
    //
    // 760 gives 11px horizontal padding.
    // 144 gives 12px vertical padding around 120px cards.
    // ============================================================

    readonly property int powerWidth: 760
    readonly property int powerHeight: 144

    // ============================================================
    // OSD DIMENSIONS (UNIQUE SIZES PER NOTIFICATION TYPE)
    // ============================================================

    readonly property int osdVolumeWidth: 320
    readonly property int osdVolumeHeight: 48

    readonly property int osdMuteWidth: 240
    readonly property int osdMuteHeight: 44

    readonly property int osdMicWidth: 240
    readonly property int osdMicHeight: 44

    readonly property int osdBrightnessWidth: 320
    readonly property int osdBrightnessHeight: 48

    readonly property int osdAirplaneWidth: 260
    readonly property int osdAirplaneHeight: 46

    property string osdType: "none"
    property real osdValue: 0.74
    property bool osdMuted: false
    property bool osdMicMuted: false
    property bool osdAirplaneEnabled: false
    property bool osdActive: false

    Timer {
        id: osdDismissTimer
        interval: 1800
        repeat: false
        onTriggered: {
            root.osdActive = false
            root.osdType = "none"
        }
    }

    Timer {
        id: volumeSyncTimer
        interval: 120
        repeat: false
        onTriggered: volumeQueryProcess.running = true
    }

    Timer {
        id: brightnessSyncTimer
        interval: 120
        repeat: false
        onTriggered: brightnessQueryProcess.running = true
    }

    Process {
        id: volumeQueryProcess
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        stdout: StdioCollector {
            onStreamFinished: {
                const text = this.text.trim()
                if (text.startsWith("Volume:")) {
                    const isMuted = text.includes("[MUTED]")
                    const clean = text.replace("Volume:", "").replace("[MUTED]", "").trim()
                    const val = parseFloat(clean)
                    if (!isNaN(val)) {
                        root.osdValue = Math.max(0.0, Math.min(1.0, val))
                        root.osdMuted = isMuted
                    }
                }
            }
        }
    }

    Process {
        id: brightnessQueryProcess
        command: ["brightnessctl", "-m"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = this.text.trim().split(",")
                if (parts.length >= 4 && parts[3].endsWith("%")) {
                    const pct = parseFloat(parts[3].replace("%", ""))
                    if (!isNaN(pct)) {
                        if (root.osdType === "brightness" || !root.osdActive) {
                            root.osdValue = Math.max(0.0, Math.min(1.0, pct / 100.0))
                        }
                    }
                }
            }
        }
    }

    Process {
        id: airplaneToggleProcess
        command: [
            Quickshell.env("HOME") + "/.config/nexa/rust/target/release/nexad",
            "system",
            "airplane",
            "toggle"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(this.text.trim())
                    root.osdAirplaneEnabled = Boolean(data.enabled)
                } catch (e) {}
            }
        }
    }

    Process {
        id: airplaneQueryProcess
        command: [
            Quickshell.env("HOME") + "/.config/nexa/rust/target/release/nexad",
            "system",
            "airplane",
            "info"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(this.text.trim())
                    root.osdAirplaneEnabled = Boolean(data.enabled)
                } catch (e) {}
            }
        }
    }

    function triggerVolumeUp(): void {
        if (root.full || root.specialModeActive) return
        root.osdType = "volume"
        root.osdMuted = false
        root.osdValue = Math.min(1.0, root.osdValue + 0.05)
        root.osdActive = true
        osdDismissTimer.restart()
        Quickshell.execDetached(["wpctl", "set-volume", "-l", "1", "@DEFAULT_AUDIO_SINK@", "5%+"])
        volumeSyncTimer.restart()
    }

    function triggerVolumeDown(): void {
        if (root.full || root.specialModeActive) return
        root.osdType = "volume"
        root.osdValue = Math.max(0.0, root.osdValue - 0.05)
        root.osdActive = true
        osdDismissTimer.restart()
        Quickshell.execDetached(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", "5%-"])
        volumeSyncTimer.restart()
    }

    function triggerToggleMute(): void {
        if (root.full || root.specialModeActive) return
        root.osdType = "mute"
        root.osdMuted = !root.osdMuted
        root.osdActive = true
        osdDismissTimer.restart()
        Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"])
        volumeSyncTimer.restart()
    }

    function triggerBrightnessUp(): void {
        if (root.full || root.specialModeActive) return
        root.osdType = "brightness"
        root.osdValue = Math.min(1.0, root.osdValue + 0.05)
        root.osdActive = true
        osdDismissTimer.restart()
        Quickshell.execDetached(["brightnessctl", "-e4", "-n2", "set", "5%+"])
        brightnessSyncTimer.restart()
    }

    function triggerBrightnessDown(): void {
        if (root.full || root.specialModeActive) return
        root.osdType = "brightness"
        root.osdValue = Math.max(0.01, root.osdValue - 0.05)
        root.osdActive = true
        osdDismissTimer.restart()
        Quickshell.execDetached(["brightnessctl", "-e4", "-n2", "set", "5%-"])
        brightnessSyncTimer.restart()
    }

    Timer {
        id: micSyncTimer
        interval: 120
        repeat: false
        onTriggered: micQueryProcess.running = true
    }

    Process {
        id: micQueryProcess
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SOURCE@"]
        stdout: StdioCollector {
            onStreamFinished: {
                const text = this.text.trim()
                if (text.startsWith("Volume:")) {
                    const isMuted = text.includes("[MUTED]")
                    const clean = text.replace("Volume:", "").replace("[MUTED]", "").trim()
                    const val = parseFloat(clean)
                    if (!isNaN(val)) {
                        if (root.osdType === "mic") {
                            root.osdValue = Math.max(0.0, Math.min(1.0, val))
                        }
                        root.osdMicMuted = isMuted
                    }
                }
            }
        }
    }

    function triggerToggleMicMute(): void {
        if (root.full || root.specialModeActive) return
        root.osdType = "mic"
        root.osdMicMuted = !root.osdMicMuted
        root.osdMuted = root.osdMicMuted
        root.osdActive = true
        osdDismissTimer.restart()
        Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SOURCE@", "toggle"])
        micSyncTimer.restart()
    }

    function triggerToggleAirplane(): void {
        if (root.full || root.specialModeActive) return
        root.osdType = "airplane"
        root.osdAirplaneEnabled = !root.osdAirplaneEnabled
        root.osdActive = true
        osdDismissTimer.restart()
        airplaneToggleProcess.running = true
    }

    property string specialMode: "none"
    // none | search | command | power | appLauncher

    readonly property bool specialModeActive:
        specialMode !== "none"

    IpcHandler {
        target: "nexaIsland"

        function volumeUp(): void {
            root.triggerVolumeUp()
        }

        function volumeDown(): void {
            root.triggerVolumeDown()
        }

        function toggleMute(): void {
            root.triggerToggleMute()
        }

        function toggleMicMute(): void {
            root.triggerToggleMicMute()
        }

        function brightnessUp(): void {
            root.triggerBrightnessUp()
        }

        function brightnessDown(): void {
            root.triggerBrightnessDown()
        }

        function toggleAirplane(): void {
            root.triggerToggleAirplane()
        }

        function openSearch(): void {
            root.specialMode = "search"
            root.full = true
            root.hovered = false

            islandFocus.forceActiveFocus()
        }

        function openCommand(): void {
            root.specialMode = "command"
            root.full = true
            root.hovered = false

            islandFocus.forceActiveFocus()
        }

        function openPower(): void {
            root.specialMode = "power"
            root.full = true
            root.hovered = false

            islandFocus.forceActiveFocus()
        }

        function openAppLauncher(): void {
            root.specialMode = "appLauncher"
            root.full = true
            root.hovered = false

            islandFocus.forceActiveFocus()
        }

        function toggleAppLauncher(): void {
            if (root.specialMode === "appLauncher") {
                root.closeIsland()
            } else {
                root.specialMode = "appLauncher"
                root.full = true
                root.hovered = false

                islandFocus.forceActiveFocus()
            }
        }
    }

    IpcHandler {
        target: "appLauncher"

        function open(): void {
            root.specialMode = "appLauncher"
            root.full = true
            root.hovered = false

            islandFocus.forceActiveFocus()
        }

        function close(): void {
            if (root.specialMode === "appLauncher")
                root.closeIsland()
        }

        function toggle(): void {
            if (root.specialMode === "appLauncher") {
                root.closeIsland()
            } else {
                root.specialMode = "appLauncher"
                root.full = true
                root.hovered = false

                islandFocus.forceActiveFocus()
            }
        }
    }


    // ============================================================
    // CONTENT-DERIVED STATE
    //
    // IslandContent can tell the physical shell that something
    // persistent exists.
    //
    // Currently this is the stopwatch.
    // Later media / recorder / timer can use the same concept.
    // ============================================================

    readonly property bool persistentContext:
        islandContent.persistentContext


    

    // ============================================================
    // TARGET SIZE
    // ============================================================

    readonly property int targetWidth: {
        if (root.specialMode === "appLauncher")
            return root.launcherWidth

        if (root.specialMode === "power")
            return root.powerWidth

        if (root.full || root.specialModeActive)
            return root.fullWidth

        if (root.osdActive) {
            if (root.osdType === "volume")
                return root.osdVolumeWidth
            if (root.osdType === "mute")
                return root.osdMuteWidth
            if (root.osdType === "mic")
                return root.osdMicWidth
            if (root.osdType === "brightness")
                return root.osdBrightnessWidth
            if (root.osdType === "airplane")
                return root.osdAirplaneWidth
            return 320
        }

        if (root.notificationActive)
            return root.hoverWidth

        if (root.hovered)
            return root.hoverWidth

        if (root.persistentContext)
            return root.contextWidth

        return root.compactWidth
    }

    readonly property int targetHeight: {
        if (root.specialMode === "appLauncher")
            return root.launcherHeight

        if (root.specialMode === "power")
            return root.powerHeight

        if (root.full || root.specialModeActive)
            return root.fullHeight

        if (root.osdActive) {
            if (root.osdType === "volume")
                return root.osdVolumeHeight
            if (root.osdType === "mute")
                return root.osdMuteHeight
            if (root.osdType === "mic")
                return root.osdMicHeight
            if (root.osdType === "brightness")
                return root.osdBrightnessHeight
            if (root.osdType === "airplane")
                return root.osdAirplaneHeight
            return 48
        }

        if (root.notificationActive)
            return root.hoverHeight

        if (root.hovered)
            return root.hoverHeight

        if (root.persistentContext)
            return root.contextHeight

        return root.compactHeight
    }


    // ============================================================
    // ACTIONS
    // ============================================================

    function openFull() {
        if (root.full)
            return


        // Ask content which section makes sense for the
        // currently visible context.
        islandContent.section =
            islandContent.preferredFullSection()


        root.full = true
        root.hovered = false

        islandFocus.forceActiveFocus()

        console.log(
            "NEXA full island opened:",
            islandContent.section
        )
    }


    function closeFull() {
        if (!root.full)
            return

        root.full = false
        root.hovered = false

        console.log("NEXA full island closed")
    }

    function closeIsland() {
        if (root.specialModeActive)
            root.specialMode = "none"

        root.full = false
        root.hovered = false
    }

    // ============================================================
    // INPUT MASK
    //
    // The PanelWindow itself is intentionally larger than the
    // visible Island.
    //
    // Only the visible Island rectangle receives pointer input.
    // Transparent space around it remains click-through.
    // ============================================================

    mask: Region {
        item: island
    }


    // ============================================================
    // OUTSIDE CLICK
    //
    // Active only in full mode.
    //
    // Clicking somewhere outside this window clears the Hyprland
    // focus grab and closes the Island.
    // ============================================================

    HyprlandFocusGrab {
        id: focusGrab

        windows: [root]

        active: root.full || root.specialModeActive
        onCleared: {
            // Keep the Island alive while a Theme popup is open.
            // The popup lives in a separate Wayland surface, so
            // Hyprland clears our grab when the user clicks it —
            // but that click is still intentional Island interaction.
            if (root.themePopupOpen)
                return

            root.closeIsland()
        }
    }


    // ============================================================
    // VISIBLE ISLAND SURFACE
    // ============================================================

    Rectangle {
        id: island

        anchors {
            top: parent.top
            horizontalCenter: parent.horizontalCenter
        }

        width: root.targetWidth
        height: root.targetHeight


        // --------------------------------------------------------
        // SHAPE
        // --------------------------------------------------------

        radius:
          root.full
          || root.specialModeActive
          || root.hovered
          || root.notificationActive
          ? Nexa.Theme.radiusLg
          : (root.osdActive ? Math.round(targetHeight / 2) : Nexa.Theme.radiusPill)


        // --------------------------------------------------------
        // SURFACE COLOR
        // --------------------------------------------------------

        color:
          root.full
          || root.specialModeActive
          || root.hovered
          || root.notificationActive
          || root.osdActive
          ? Nexa.Theme.islandBackgroundExpanded
          : Nexa.Theme.islandBackground


        border.width:
            Nexa.Theme.borderThin

        border.color:
          root.full
          || root.hovered
          || root.notificationActive
          || root.osdActive
          ? Nexa.Theme.borderStrong
          : Nexa.Theme.border


        // ========================================================
        // VISUAL ANIMATION
        //
        // Width, height, and corner radius animate together using
        // identical timings and OutQuint easing for maximum fluidity.
        // ========================================================

        Behavior on width {
            NumberAnimation {
                duration: Nexa.Theme.animationNormal
                easing.type: Nexa.Theme.easingDecelerate
            }
        }


        Behavior on height {
            NumberAnimation {
                duration: Nexa.Theme.animationNormal
                easing.type: Nexa.Theme.easingDecelerate
            }
        }


        Behavior on radius {
            NumberAnimation {
                duration: Nexa.Theme.animationNormal
                easing.type: Nexa.Theme.easingDecelerate
            }
        }


        Behavior on color {
            ColorAnimation {
                duration: Nexa.Theme.animationFast
                easing.type: Easing.OutCubic
            }
        }


        Behavior on border.color {
            ColorAnimation {
                duration: Nexa.Theme.animationFast
                easing.type: Easing.OutCubic
            }
        }


        // ========================================================
        // HOVER DETECTION
        //
        // IMPORTANT:
        //
        // HoverHandler observes pointer presence.
        // It does NOT own feature button clicks.
        //
        // This means stopwatch/media controls can be clicked
        // without fighting the Island hover system.
        // ========================================================

        HoverHandler {
            id: islandHover

            enabled:
              !root.full
              && !root.specialModeActive
              && !root.notificationActive
              && !root.osdActive

            onHoveredChanged: {
                root.hovered =
                    islandHover.hovered

                console.log(
                    "[Island] hover:",
                    islandHover.hovered
                )
            }
        }


        // ========================================================
        // BACKGROUND OPEN AREA
        //
        // IMPORTANT:
        //
        // This MouseArea is BELOW IslandContent.
        //
        // Empty/background Island space:
        //     click -> open full
        //
        // Actual controls above it:
        //     Pause / Resume / Next / etc.
        //     consume their own clicks.
        //
        // This prevents hover buttons from opening full mode.
        // ========================================================

        MouseArea {
            id: backgroundOpenArea

            anchors.fill: parent

            z: 0

            enabled:
              !root.full
              && !root.specialModeActive
              && !root.notificationActive
              && !root.osdActive

            cursorShape: Qt.PointingHandCursor

            onClicked: {
                root.openFull()
            }
        }


        // ========================================================
        // CONTENT + KEYBOARD FOCUS
        // ========================================================

        FocusScope {
            id: islandFocus

            anchors.fill: parent

            z: 1

            focus: root.full || root.specialModeActive

            // ----------------------------------------------------
            // ESCAPE
            // ----------------------------------------------------

            Keys.onEscapePressed: event => {
                if (root.full || root.specialModeActive) {
                    root.closeIsland()
                    event.accepted = true
                }
            }


            // ----------------------------------------------------
            // ACTUAL ISLAND CONTENT
            // ----------------------------------------------------

            IslandContent {
              id: islandContent

              anchors.fill:
                  parent

              hovered:
                  root.hovered

              full:
                  root.full

              specialMode:
                  root.specialMode

              osdActive:
                  root.osdActive

              osdType:
                  root.osdType

              osdValue:
                  root.osdValue

              osdMuted:
                  root.osdMuted

              osdAirplaneEnabled:
                  root.osdAirplaneEnabled

              onRequestCloseSpecialMode:
                  root.closeIsland()


              onNotificationPreviewActivated: {
                  Quickshell.execDetached([
                      "qs",
                      "-p",
                      Quickshell.env("HOME")
                          + "/.config/nexa/quickshell",
                      "ipc",
                      "call",
                      "sidePanel",
                      "openNotifications"
                  ])
              }
          }

        }
    }

    Component.onCompleted: {
        volumeQueryProcess.running = true
        micQueryProcess.running = true
        brightnessQueryProcess.running = true
        airplaneQueryProcess.running = true
    }
}
