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
    implicitWidth: 760
    implicitHeight: 430

    margins {
        top: 3

        left: Math.round(
            (screen.width - implicitWidth) / 2
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
    readonly property int hoverWidth: 420
    readonly property int hoverHeight: 102


    // Confirmed full dimensions.
    readonly property int fullWidth: 720
    readonly property int fullHeight: 400

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

    //search n command 



    property string specialMode: "none"
    // none | search | command

    readonly property bool specialModeActive:
        specialMode !== "none"
  
    
    IpcHandler {
        target: "nexaIsland"

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
        if (root.specialMode === "power")
            return root.powerWidth

        if (root.full || root.specialModeActive)
            return root.fullWidth

        if (root.notificationActive)
            return root.hoverWidth

        if (root.hovered)
            return root.hoverWidth

        if (root.persistentContext)
            return root.contextWidth

        return root.compactWidth
    }

    readonly property int targetHeight: {
        if (root.specialMode === "power")
            return root.powerHeight

        if (root.full || root.specialModeActive)
            return root.fullHeight

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
          : Nexa.Theme.radiusPill


        // --------------------------------------------------------
        // SURFACE COLOR
        // --------------------------------------------------------

        color:
          root.full
          || root.specialModeActive
          || root.hovered
          || root.notificationActive
          ? Nexa.Theme.islandBackgroundExpanded
          : Nexa.Theme.islandBackground


        border.width:
            Nexa.Theme.borderThin

        border.color:
          root.full
          || root.hovered
          || root.notificationActive
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
}
