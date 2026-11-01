import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import QtMultimedia
import Qt.labs.folderlistmodel

import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "../theme" as Nexa
import "../theme/components" as NexaUI

PanelWindow {
    id: root

    visible: false
    focusable: true
    color: "transparent"

    // GlobalShortcut moved to shell.qml to allow on-demand lazy loading

    exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // ---------------------------------------------------------
    // Paths
    // ---------------------------------------------------------

    readonly property string homeDir:
        Quickshell.env("HOME")

    readonly property string wallpaperDir:
        homeDir + "/Pictures/Wallpapers"

    readonly property string nexad:
    homeDir + "/.config/nexa/rust/target/release/nexad"

    readonly property string applyScript:
        homeDir + "/.config/nexa/scripts/wallpaper.sh"

    // ---------------------------------------------------------
    // State
    // ---------------------------------------------------------

    property bool loaded: false
    property bool applying: false

    property string statusText: ""

    property string currentFilter: "All"

    // Wallpaper destination
    property string applyTarget: "Background"
    property bool applyMenuOpen: false

    // Current desktop wallpaper state
    readonly property string wallpaperConfigFile:
        homeDir + "/.config/nexa/config/wallpaper.conf"
    property string currentWallpaperPath: ""

    function parseWallpaperConfig(raw) {
        if (!raw || String(raw).trim() === "")
            return
        const lines = String(raw).split("\n")
        for (let i = 0; i < lines.length; ++i) {
            const line = lines[i].trim()
            if (line.startsWith("WALLPAPER=")) {
                let val = line.substring("WALLPAPER=".length).trim()
                if ((val.startsWith('"') && val.endsWith('"')) || (val.startsWith("'") && val.endsWith("'"))) {
                    val = val.substring(1, val.length - 1)
                }
                val = val.replace(/\\(.)/g, "$1")
                root.currentWallpaperPath = val
                break
            }
        }
    }

    // Slideshow state
    readonly property string slideshowConfigFile:
        homeDir + "/.config/nexa/config/slideshow.json"

    property bool slideshowEnabled: false
    property bool slideshowPaused: false
    property string slideshowInterval: "10m"
    property string slideshowType: "All"
    property string slideshowTarget: "Background"
    property string slideshowLastWallpaper: ""
    readonly property string slideshowFolder:
        wallpaperDir + "/Slideshow"

    property bool slideshowTimerMenuOpen: false
    property bool slideshowTypeMenuOpen: false
    property bool slideshowTargetMenuOpen: false

    // ---------------------------------------------------------
    // Carousel geometry
    // ---------------------------------------------------------

    readonly property real cardWidth: 400
    readonly property real cardHeight: 420

    readonly property real selectedWidth:
        cardWidth * 1.5

    readonly property real sideWidth:
        cardWidth * 0.5

    readonly property real selectedHeight:
        cardHeight + 30

    readonly property real itemSpacing: 10
    readonly property real skewFactor: -0.35

    // ---------------------------------------------------------
    // Fluid Spring & Jiggle Physics Engine
    // ---------------------------------------------------------

    property real jiggleOffset: 0.0
    property real jiggleVelocity: 0.0

    readonly property real jiggleStiffness: 140.0
    readonly property real jiggleDamping: 8.5

    property real lastContentX: 0.0

    function triggerJiggle(direction) {
        jiggleVelocity += direction * 9.0
        jigglePhysics.running = true
    }

    FrameAnimation {
        id: jigglePhysics
        running: false

        onTriggered: {
            const dt = Math.min(frameTime, 0.04)
            if (dt <= 0.0001)
                return

            const currentX = view.contentX
            const contentDx = currentX - root.lastContentX
            root.lastContentX = currentX

            if (view.moving && Math.abs(contentDx) > 0.3) {
                root.jiggleVelocity += (-contentDx / dt) * 0.0006
            }

            const springForce = (-root.jiggleStiffness * root.jiggleOffset) - (root.jiggleDamping * root.jiggleVelocity)
            root.jiggleVelocity += springForce * dt
            root.jiggleOffset += root.jiggleVelocity * dt

            if (Math.abs(root.jiggleOffset) < 0.0005 && Math.abs(root.jiggleVelocity) < 0.003 && !view.moving) {
                root.jiggleOffset = 0.0
                root.jiggleVelocity = 0.0
                running = false
            }
        }
    }

    // ---------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------

    function fileName(path) {
        const pieces = String(path).split("/")

        return pieces.length > 0
            ? pieces[pieces.length - 1]
            : path
    }

    function fileUrl(path) {
        return "file://" + encodeURI(path)
    }

    function closeWallpaper() {
        root.applying = false
        root.visible = false
    }



    function videoThumbnail(path) {
        return root.homeDir
            + "/.cache/nexa/wallpapers/video/"
            + root.fileName(path)
            + ".jpg"
    }

    function reload() {
        if (listProcess.running)
            return

        listProcess.command = [
            nexad,
            "wallpaper",
            "list",
            "--json"
        ]

        listProcess.running = true
    }

    function parseWallpaperList(output) {
        if (!output || output.trim() === "") return;
        try {
            const trimmed = output.trim();
            if (trimmed.startsWith("{")) {
                const data = JSON.parse(trimmed);
                if (data.current_desktop && data.current_desktop.length > 0) {
                    root.currentWallpaperPath = data.current_desktop;
                }
                const items = data.wallpapers || [];
                let hasChanges = items.length !== wallpaperModel.count;
                if (!hasChanges) {
                    for (let i = 0; i < items.length; ++i) {
                        const cur = wallpaperModel.get(i);
                        if (!cur || cur.wallPath !== items[i].path) {
                            hasChanges = true;
                            break;
                        }
                    }
                }
                if (hasChanges || !loaded) {
                    wallpaperModel.clear();
                    for (let i = 0; i < items.length; ++i) {
                        const it = items[i];
                        wallpaperModel.append({
                            wallType: it.kind,
                            wallPath: it.path,
                            wallThumb: it.thumb,
                            wallProxy: it.proxy,
                            wallName: it.name
                        });
                    }
                }
                updateVisibleSelection();
                loaded = true;
                statusText = items.length === 0 ? "No wallpapers found" : "";
                return;
            }
        } catch (e) {
            console.warn("[WallpaperView] JSON parse error, falling back to legacy line parser:", e);
        }

        const lines = String(output)
            .split("\n")
            .filter(line => line.trim() !== "")

        const newItems = []
        for (let i = 0; i < lines.length; ++i) {
            const parts = lines[i].split("|")
            if (parts.length < 2)
                continue

            const type = parts[0]
            const path = parts[1]
            const thumb = parts.length >= 3 && parts[2] ? parts[2] : path
            const proxy = parts.length >= 4 && parts[3] ? parts[3] : ""

            newItems.push({
                wallType: type,
                wallPath: path,
                wallThumb: thumb,
                wallProxy: proxy,
                wallName: fileName(path)
            })
        }

        let hasLineChanges = newItems.length !== wallpaperModel.count;
        if (!hasLineChanges) {
            for (let i = 0; i < newItems.length; ++i) {
                const cur = wallpaperModel.get(i);
                if (!cur || cur.wallPath !== newItems[i].wallPath) {
                    hasLineChanges = true;
                    break;
                }
            }
        }
        if (hasLineChanges || !loaded) {
            wallpaperModel.clear()
            for (let i = 0; i < newItems.length; ++i) {
                wallpaperModel.append(newItems[i])
            }
        }
        updateVisibleSelection()
        loaded = true
        statusText = wallpaperModel.count === 0 ? "No wallpapers found" : ""
    }

    function matchesFilter(type, name) {
        if (currentFilter === "All") return true;
        if (currentFilter === "Image") return type === "image";
        if (currentFilter === "GIF") return type === "gif";
        if (currentFilter === "Video") return type === "video";
        return true;
    }

    function findNextValid(start, direction) {
        if (wallpaperModel.count <= 0) return -1;
        let index = start;
        for (let i = 0; i < wallpaperModel.count; ++i) {
            index = (index + direction + wallpaperModel.count) % wallpaperModel.count;
            const item = wallpaperModel.get(index);
            if (item && matchesFilter(item.wallType, item.wallName)) {
                return index;
            }
        }
        return -1;
    }

    function firstValidIndex() {
        for (let i = 0; i < wallpaperModel.count; ++i) {
            const item = wallpaperModel.get(i);
            if (item && matchesFilter(item.wallType, item.wallName)) {
                return i;
            }
        }
        return -1;
    }

    function visibleCount() {
        let count = 0;
        for (let i = 0; i < wallpaperModel.count; ++i) {
            const item = wallpaperModel.get(i);
            if (item && matchesFilter(item.wallType, item.wallName)) {
                ++count;
            }
        }
        return count;
    }

    function findCurrentWallpaperIndex() {
        if (!root.currentWallpaperPath || wallpaperModel.count <= 0) return -1;
        const cur = root.currentWallpaperPath;
        const curName = root.fileName(cur);
        for (let i = 0; i < wallpaperModel.count; ++i) {
            const item = wallpaperModel.get(i);
            if (!item) continue;
            const p = item.wallPath;
            const name = item.wallName;
            if (p === cur || (p && cur.endsWith("/" + name)) || (name && name === curName)) {
                if (matchesFilter(item.wallType, item.wallName)) {
                    return i;
                }
            }
        }
        return -1;
    }

    function updateVisibleSelection() {
        let target = findCurrentWallpaperIndex()
        if (target < 0) target = firstValidIndex()

        if (target >= 0) {
            view.highlightMoveDuration = 0
            view.currentIndex = target
            Qt.callLater(() => {
                view.currentIndex = target
                view.highlightMoveDuration = 340
                view.forceActiveFocus()
            })
        }
    }

    function move(direction) {
        if (wallpaperModel.count <= 0) return
        const next = findNextValid(view.currentIndex, direction)
        if (next >= 0) {
            triggerJiggle(direction)
            view.currentIndex = next
        }
    }

    function applyCurrent() {
      if (applying)
          return

      if (slideshowEnabled && !slideshowPaused) {
          statusText = "Slideshow is active. Pause slideshow to apply static wallpaper."
          statusClearTimer.restart()
          return
      }

      if (
          view.currentIndex < 0 ||
          view.currentIndex >= wallpaperModel.count
      ) {
          return
      }

      const entry =
          wallpaperModel.get(
              view.currentIndex
          )


      // =========================================================
      // UNIFIED NATIVE APPLY (Background, Lock Screen, Both)
      // =========================================================
      applying = true;
      if (applyTarget === "Background" || applyTarget === "Both") {
          root.currentWallpaperPath = entry.wallPath;
      }

      statusText = "Applying " + entry.wallName + "...";

      Quickshell.execDetached([
          nexad,
          "wallpaper",
          "apply",
          entry.wallPath,
          "--target",
          applyTarget
      ]);

      closeTimer.restart();
  }


    function activateFilter(name) {
        if (currentFilter === name)
            return

        currentFilter = name
        updateVisibleSelection()

        Qt.callLater(
            () => view.forceActiveFocus()
        )
    }

    function activateApplyTarget(name) {
        applyTarget = name
        applyMenuOpen = false

        Qt.callLater(
            () => view.forceActiveFocus()
        )
    }

    function closeAllSlideshowMenus() {
        slideshowTimerMenuOpen = false
        slideshowTypeMenuOpen = false
        slideshowTargetMenuOpen = false
    }

    function parseSlideshowConfig(raw) {
        if (!raw || raw.trim() === "")
            return
        try {
            const data = JSON.parse(raw)
            root.slideshowEnabled = !!data.enabled
            root.slideshowPaused = !!data.paused
            if (data.interval) root.slideshowInterval = data.interval
            if (data.type_filter) root.slideshowType = data.type_filter
            if (data.apply_target) root.slideshowTarget = data.apply_target
            if (data.last_wallpaper) root.slideshowLastWallpaper = data.last_wallpaper
        } catch (e) {
            console.log("[WallpaperView] Error parsing slideshow config:", e)
        }
    }

    function applySlideshowWallpaper(filePath) {
        if (applying || !filePath)
            return

        applying = true
        const wName = fileName(filePath)
        statusText = "Applying " + wName + " (" + slideshowTarget + ")..."

        Quickshell.execDetached([
            nexad,
            "wallpaper",
            "apply",
            filePath,
            "--target",
            slideshowTarget
        ])

        slideshowLastWallpaper = filePath

        Quickshell.execDetached([
            nexad,
            "wallpaper",
            "slideshow",
            "set",
            "--current",
            filePath
        ])

        Quickshell.execDetached([
            "quickshell",
            "ipc",
            "-p",
            Quickshell.env("HOME") + "/.config/nexa/quickshell",
            "call",
            "wallpaperSlideshow",
            "reload"
        ])

        closeTimer.restart()
    }

    function saveSlideshowState(enabled, paused, interval, typeFilter, target) {
        root.slideshowEnabled = enabled
        root.slideshowPaused = paused
        root.slideshowInterval = interval
        root.slideshowType = typeFilter
        root.slideshowTarget = target

        Quickshell.execDetached([
            nexad,
            "wallpaper",
            "slideshow",
            "set",
            "--enabled", enabled ? "true" : "false",
            "--paused", paused ? "true" : "false",
            "--interval", interval,
            "--type", typeFilter,
            "--target", target
        ])

        Quickshell.execDetached([
            "quickshell",
            "ipc",
            "-p",
            Quickshell.env("HOME") + "/.config/nexa/quickshell",
            "call",
            "wallpaperSlideshow",
            "reload"
        ])
    }

    function toggleSlideshowEnabled() {
        root.closeAllSlideshowMenus()
        const newEnabled = !root.slideshowEnabled
        const newPaused = newEnabled ? false : root.slideshowPaused
        root.saveSlideshowState(newEnabled, newPaused, root.slideshowInterval, root.slideshowType, root.slideshowTarget)
        if (newEnabled) {
            root.triggerSlideshowNext()
        }
    }

    function toggleSlideshowPaused() {
        root.closeAllSlideshowMenus()
        if (!root.slideshowEnabled)
            return
        root.saveSlideshowState(root.slideshowEnabled, !root.slideshowPaused, root.slideshowInterval, root.slideshowType, root.slideshowTarget)
    }

    function triggerSlideshowNext() {
        root.closeAllSlideshowMenus()
        root.statusText = "Switching slideshow wallpaper..."
        statusClearTimer.restart()
        Quickshell.execDetached([
            nexad,
            "wallpaper",
            "slideshow",
            "next"
        ])
    }

    function handleEscape() {
        if (slideshowTimerMenuOpen || slideshowTypeMenuOpen || slideshowTargetMenuOpen) {
            closeAllSlideshowMenus()
            return
        }

        if (applyMenuOpen) {
            applyMenuOpen = false
            return
        }

        closeWallpaper()
    }
    // ---------------------------------------------------------
    // Model
    // ---------------------------------------------------------

    ListModel {
        id: wallpaperModel
    }

    Process {
        id: listProcess

        stdout: StdioCollector {
            onStreamFinished:
                root.parseWallpaperList(this.text)
        }

        onRunningChanged: {
            if (!running && !root.loaded)
                root.loaded = true
        }
    }

    Timer {
        id: closeTimer

        interval: 180
        repeat: false

        onTriggered: {
            root.applying = false
            root.closeWallpaper()
        }
    }

    Timer {
        id: statusClearTimer
        interval: 3500
        repeat: false
        onTriggered: {
            root.statusText = ""
        }
    }

    FileView {
        id: slideshowConfigFileView
        path: root.slideshowConfigFile
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            root.parseSlideshowConfig(text())
        }
    }

    FileView {
        id: wallpaperConfigFileView
        path: root.wallpaperConfigFile
        onLoaded: {
            root.parseWallpaperConfig(text())
            root.updateVisibleSelection()
        }
    }

    // ---------------------------------------------------------
    // Keyboard
    // ---------------------------------------------------------

    Shortcut {
        sequence: "Left"
        context: Qt.ApplicationShortcut

        enabled:
            root.visible &&
            !root.applying &&
            !root.slideshowEnabled

        onActivated:
            root.move(-1)
    }

    Shortcut {
        sequence: "Right"
        context: Qt.ApplicationShortcut

        enabled:
            root.visible &&
            !root.applying &&
            !root.slideshowEnabled

        onActivated:
            root.move(1)
    }

    Shortcut {
        sequence: "Return"
        context: Qt.ApplicationShortcut

        enabled:
            root.visible &&
            !root.applying &&
            !root.slideshowEnabled

        onActivated:
            root.applyCurrent()
    }

    Shortcut {
        sequence: "Escape"
        context: Qt.ApplicationShortcut

        enabled:
            root.visible &&
            !root.applying

        onActivated:
            root.handleEscape()
    }

    // ---------------------------------------------------------
    // Overlay
    // ---------------------------------------------------------

    Rectangle {
        anchors.fill: parent
        z: -100

        color: Nexa.Theme.scrim

        MouseArea {
            anchors.fill: parent

            acceptedButtons:
                Qt.LeftButton
        }
    }

    // ---------------------------------------------------------
    // Carousel
    // ---------------------------------------------------------

    ListView {
        id: view
        focus: true

        anchors.fill: parent

        orientation:
            ListView.Horizontal

        spacing: 0

        model:
            wallpaperModel

        visible:
            !root.slideshowEnabled

        opacity:
            root.slideshowEnabled ? 0.0 : 1.0

        Behavior on opacity {
            NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
        }

        interactive:
            !root.slideshowEnabled &&
            !root.applying &&
            wallpaperModel.count > 0

        cacheBuffer: 800

        highlightRangeMode:
            ListView.StrictlyEnforceRange

        preferredHighlightBegin:
            (width / 2)
            -
            (
                (
                    root.selectedWidth
                    + root.itemSpacing
                )
                / 2
            )

        preferredHighlightEnd:
            (width / 2)
            +
            (
                (
                    root.selectedWidth
                    + root.itemSpacing
                )
                / 2
            )

        highlightMoveDuration: 340
        highlightMoveVelocity: -1

        Connections {
            target: view
            function onMovingChanged() {
                if (view.moving) {
                    root.lastContentX = view.contentX
                    jigglePhysics.running = true
                }
            }
            function onContentXChanged() {
                if (view.moving && !jigglePhysics.running) {
                    jigglePhysics.running = true
                }
            }
        }

        WheelHandler {
            id: carouselWheel
            orientation: Qt.Vertical
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            property real accumulatedDelta: 0

            onWheel: (event) => {
                let dy = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x
                accumulatedDelta += dy
                if (Math.abs(accumulatedDelta) >= 80) {
                    let dir = accumulatedDelta < 0 ? 1 : -1
                    accumulatedDelta = 0
                    root.move(dir)
                }
                wheelResetTimer.restart()
            }
        }

        Timer {
            id: wheelResetTimer
            interval: 160
            repeat: false
            onTriggered: {
                carouselWheel.accumulatedDelta = 0
            }
        }

        header: Item {
            width:
                Math.max(
                    0,
                    (view.width / 2)
                    -
                    (root.selectedWidth / 2)
                )
        }

        footer: Item {
            width:
                Math.max(
                    0,
                    (view.width / 2)
                    -
                    (root.selectedWidth / 2)
                )
        }

        delegate: Item {
            id: cardRoot

            required property int index
            required property string wallType
            required property string wallPath
            required property string wallThumb
            required property string wallProxy
            required property string wallName

            readonly property bool matches:
                root.matchesFilter(
                    wallType,
                    wallName
                )

            readonly property bool selected:
                ListView.isCurrentItem &&
                matches

            readonly property int distFromSelected:
                Math.abs(cardRoot.index - view.currentIndex)

            // Dynamic wave propagation: center card has punchiest jiggle, neighbors ripple with soft decay
            readonly property real cardJiggle:
                root.jiggleOffset / (1.0 + (cardRoot.distFromSelected * 0.4))

            readonly property bool isImage:
                wallType === "image"

            readonly property bool isGif:
                wallType === "gif"

            readonly property bool isVideo:
                wallType === "video"

            readonly property bool isCurrentWallpaper:
                root.currentWallpaperPath.length > 0 &&
                (wallPath === root.currentWallpaperPath || (wallPath && root.currentWallpaperPath.endsWith("/" + wallName)) || (wallName && wallName === root.fileName(root.currentWallpaperPath)))

            property real clickScale: 1.0

            width:
                matches
                ? (
                    selected
                    ? root.selectedWidth
                    : root.sideWidth
                )
                + root.itemSpacing
                : 0

            height:
                matches
                ? (
                    selected
                    ? root.selectedHeight
                    : root.cardHeight
                )
                : 0

            anchors.verticalCenter:
                parent
                ? parent.verticalCenter
                : undefined

            opacity:
                matches
                ? (selected ? 1.0 : (cardMouse.containsMouse ? 0.88 : 0.56))
                : 0.0

            visible:
                width > 0.1

            z:
                selected ? 10 : 1

            Behavior on width {
                NexaUI.NexaSpring { section: "wallpaper" }
            }

            Behavior on height {
                NexaUI.NexaSpring { section: "wallpaper" }
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: 300
                    easing.type: Easing.OutCubic
                }
            }

            Item {
                id: skewContainer

                anchors.centerIn: parent

                width:
                    parent.width > 0
                    ? parent.width
                      *
                      (
                          (
                              cardRoot.selected
                              ? root.selectedWidth
                              : root.sideWidth
                          )
                          /
                          (
                              (
                                  cardRoot.selected
                                  ? root.selectedWidth
                                  : root.sideWidth
                              )
                              + root.itemSpacing
                          )
                      )
                    : 0

                height:
                    parent.height

                scale:
                    cardMouse.pressed
                    ? 0.96
                    : (cardMouse.containsMouse ? 1.02 : cardRoot.clickScale)

                transform:
                    Matrix4x4 {
                        property real skew:
                            root.skewFactor + (cardRoot.cardJiggle * 0.04)

                        matrix:
                            Qt.matrix4x4(
                                1, skew, 0, 0,
                                0, 1, 0, 0,
                                0, 0, 1, 0,
                                0, 0, 0, 1
                            )
                    }

                Behavior on scale {
                    NumberAnimation {
                        duration: 260
                        easing.type: Easing.OutBack
                        easing.overshoot: 1.35
                    }
                }

                // -------------------------------------------------
                // Smooth Ambient Light Aura (Pre-loaded texture)
                // -------------------------------------------------
                Item {
                    id: auraLayer
                    anchors.fill: parent
                    anchors.margins: -14
                    z: -1
                    opacity: cardRoot.selected ? 0.65 : (cardMouse.containsMouse ? 0.28 : 0.0)
                    scale: cardRoot.selected ? 1.03 : 0.98

                    Behavior on opacity {
                        NumberAnimation { duration: 420; easing.type: Easing.OutCubic }
                    }
                    Behavior on scale {
                        NumberAnimation { duration: 420; easing.type: Easing.OutCubic }
                    }

                    Image {
                        id: auraSourceImg
                        anchors.fill: parent
                        source: root.fileUrl(cardRoot.wallThumb && cardRoot.wallThumb.length > 0 ? cardRoot.wallThumb : cardRoot.wallPath)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                        sourceSize.width: 48
                        sourceSize.height: 36
                        visible: false
                    }

                    MultiEffect {
                        anchors.fill: parent
                        source: auraSourceImg
                        blurEnabled: true
                        blur: 1.0
                        blurMax: 32
                        saturation: 0.65
                        brightness: 0.12
                    }
                }

                Rectangle {
                    anchors.fill: parent

                    color:
                        Nexa.Theme.surface

                    radius: 0

                    border.width:
                        cardRoot.selected ? 2 : 1

                    border.color:
                        cardRoot.selected
                        ? Nexa.Theme.primary
                        : (cardMouse.containsMouse ? Nexa.Theme.borderStrong : Nexa.Theme.outlineVariant)

                    clip: true

                    Rectangle {
                        anchors.fill: parent
                        color: Nexa.Theme.surfaceContainerLowest
                    }

                    // -------------------------------------------------
                    // Shared slanted-media geometry
                    //
                    // The card itself is skewed. Every media surface is
                    // counter-skewed and deliberately oversized so the
                    // clipped slanted edges never expose an empty strip.
                    // -------------------------------------------------

                    // -------------------------------------------------
                    // Static image
                    // -------------------------------------------------

                    Image {
                        anchors.centerIn: parent

                        anchors.horizontalCenterOffset:
                            skewContainer.height
                            * root.skewFactor
                            * 0.32

                        width:
                            skewContainer.width
                            +
                            (
                                skewContainer.height
                                * Math.abs(root.skewFactor)
                            )
                            + 100

                        height:
                            skewContainer.height + 20

                        sourceSize.width: 640
                        sourceSize.height: 480

                        source:
                            cardRoot.isImage
                            ? root.fileUrl(cardRoot.wallThumb && cardRoot.wallThumb.length > 0 ? cardRoot.wallThumb : cardRoot.wallPath)
                            : ""

                        fillMode:
                            Image.PreserveAspectCrop

                        asynchronous: true
                        cache: true

                        visible:
                            cardRoot.isImage

                        transform: Matrix4x4 {
                            property real skew:
                                -root.skewFactor

                            matrix:
                                Qt.matrix4x4(
                                    1, skew, 0, 0,
                                    0, 1, 0, 0,
                                    0, 0, 1, 0,
                                    0, 0, 0, 1
                                )
                        }
                    }

                    // -------------------------------------------------
                    // GIF
                    //
                    // Side cards keep a still preview. Only the selected
                    // card runs AnimatedImage, which keeps scrolling light.
                    // -------------------------------------------------

                    Image {
                        anchors.centerIn: parent

                        anchors.horizontalCenterOffset:
                            skewContainer.height
                            * root.skewFactor
                            * 0.32

                        width:
                            skewContainer.width
                            +
                            (
                                skewContainer.height
                                * Math.abs(root.skewFactor)
                            )
                            + 100

                        height:
                            skewContainer.height + 20

                        sourceSize.width: 800
                        sourceSize.height: 600

                        source:
                            cardRoot.isGif
                            ? root.fileUrl(cardRoot.wallPath)
                            : ""

                        fillMode:
                            Image.PreserveAspectCrop

                        asynchronous: true
                        cache: true

                        visible:
                            cardRoot.isGif

                        transform: Matrix4x4 {
                            property real skew:
                                -root.skewFactor

                            matrix:
                                Qt.matrix4x4(
                                    1, skew, 0, 0,
                                    0, 1, 0, 0,
                                    0, 0, 1, 0,
                                    0, 0, 0, 1
                                )
                        }
                    }

                    AnimatedImage {
                        anchors.centerIn: parent

                        anchors.horizontalCenterOffset:
                            skewContainer.height
                            * root.skewFactor
                            * 0.32

                        width:
                            skewContainer.width
                            +
                            (
                                skewContainer.height
                                * Math.abs(root.skewFactor)
                            )
                            + 100

                        height:
                            skewContainer.height + 20

                        source:
                            cardRoot.isGif
                            ? root.fileUrl(cardRoot.wallPath)
                            : ""

                        fillMode:
                            Image.PreserveAspectCrop

                        asynchronous: true
                        cache: true

                        playing:
                            cardRoot.isGif &&
                            cardRoot.selected

                        visible:
                            cardRoot.isGif &&
                            cardRoot.selected

                        transform: Matrix4x4 {
                            property real skew:
                                -root.skewFactor

                            matrix:
                                Qt.matrix4x4(
                                    1, skew, 0, 0,
                                    0, 1, 0, 0,
                                    0, 0, 1, 0,
                                    0, 0, 0, 1
                                )
                        }
                    }

                    // -------------------------------------------------
                    // Video
                    //
                    // Thumbnail is permanently underneath the live video.
                    // Therefore a video card never turns blank when it moves
                    // from current -> side.
                    // -------------------------------------------------

                    Image {
                        id: videoThumbnailImage

                        anchors.centerIn: parent

                        anchors.horizontalCenterOffset:
                            skewContainer.height
                            * root.skewFactor
                            * 0.32

                        width:
                            skewContainer.width
                            +
                            (
                                skewContainer.height
                                * Math.abs(root.skewFactor)
                            )
                            + 100

                        height:
                            skewContainer.height + 20

                        sourceSize.width: 640
                        sourceSize.height: 480

                        source:
                            cardRoot.isVideo
                            ? root.fileUrl(
                                  cardRoot.wallThumb && cardRoot.wallThumb.length > 0
                                  ? cardRoot.wallThumb
                                  : root.videoThumbnail(cardRoot.wallPath)
                              )
                            : ""

                        fillMode:
                            Image.PreserveAspectCrop

                        asynchronous: true
                        cache: true

                        visible:
                            cardRoot.isVideo

                        transform: Matrix4x4 {
                            property real skew:
                                -root.skewFactor

                            matrix:
                                Qt.matrix4x4(
                                    1, skew, 0, 0,
                                    0, 1, 0, 0,
                                    0, 0, 1, 0,
                                    0, 0, 0, 1
                                )
                        }
                    }

                    MediaPlayer {
                        id: previewPlayer

                        source:
                            (cardRoot.isVideo && !cardRoot.isCurrentWallpaper)
                            ? root.fileUrl(cardRoot.wallProxy && cardRoot.wallProxy.length > 0 ? cardRoot.wallProxy : cardRoot.wallPath)
                            : ""

                        loops:
                            MediaPlayer.Infinite

                        audioOutput:
                            AudioOutput {
                                muted: true
                            }

                        videoOutput:
                            previewOutput

                        autoPlay: false
                    }

                    VideoOutput {
                        id: previewOutput
                        focus: false

                        anchors.centerIn: parent

                        anchors.horizontalCenterOffset:
                            skewContainer.height
                            * root.skewFactor
                            * 0.32

                        width:
                            skewContainer.width
                            +
                            (
                                skewContainer.height
                                * Math.abs(root.skewFactor)
                            )
                            + 100

                        height:
                            skewContainer.height + 20

                        fillMode:
                            VideoOutput.PreserveAspectCrop

                        visible:
                            cardRoot.isVideo &&
                            cardRoot.selected &&
                            previewPlayer.playbackState
                            === MediaPlayer.PlayingState

                        transform: Matrix4x4 {
                            property real skew:
                                -root.skewFactor

                            matrix:
                                Qt.matrix4x4(
                                    1, skew, 0, 0,
                                    0, 1, 0, 0,
                                    0, 0, 1, 0,
                                    0, 0, 0, 1
                                )
                        }
                    }

                    Timer {
                        id: videoPlayTimer
                        interval: 180
                        repeat: false
                        onTriggered: {
                            if (cardRoot.isVideo && cardRoot.selected && !cardRoot.isCurrentWallpaper && root.visible) {
                                previewPlayer.position = 0
                                previewPlayer.play()
                            }
                        }
                    }

                    Connections {
                        target: cardRoot

                        function onSelectedChanged() {
                            if (!cardRoot.isVideo || cardRoot.isCurrentWallpaper) {
                                videoPlayTimer.stop()
                                previewPlayer.stop()
                                return
                            }

                            if (cardRoot.selected && root.visible) {
                                videoPlayTimer.restart()
                            } else {
                                videoPlayTimer.stop()
                                previewPlayer.stop()
                            }
                        }
                    }

                    // -------------------------------------------------
                    // Specular glass sheen highlight
                    // -------------------------------------------------
                    Rectangle {
                        anchors.fill: parent
                        radius: 0
                        gradient: Gradient {
                            orientation: Gradient.Vertical
                            GradientStop { position: 0.35; color: "transparent" }
                            GradientStop { position: 0.7; color: "transparent" }
                            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, cardRoot.selected ? 0.35 : 0.2) }
                        }
                    }

                    // -------------------------------------------------
                    // Wallpaper Name Chip (Bottom-Left)
                    // -------------------------------------------------
                    Rectangle {
                        visible: cardRoot.selected
                        anchors {
                            left: parent.left
                            bottom: parent.bottom
                            margins: 18
                        }
                        height: 32
                        width: Math.min(nameRow.implicitWidth + 24, parent.width - 120)
                        radius: Nexa.Theme.radiusFull
                        color: Qt.rgba(Nexa.Theme.background.r, Nexa.Theme.background.g, Nexa.Theme.background.b, 0.82)
                        border.width: 1
                        border.color: Qt.rgba(255, 255, 255, 0.15)

                        RowLayout {
                            id: nameRow
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 6

                            Text {
                                text: "󰋩"
                                color: Nexa.Theme.primary
                                font.family: Nexa.Theme.iconFontFamily
                                font.pixelSize: 13
                            }

                            Text {
                                text: cardRoot.wallName ? cardRoot.wallName.replace(/\.[^/.]+$/, "").replace(/[-_]/g, " ") : ""
                                color: Nexa.Theme.text
                                font.family: Nexa.Theme.fontFamily
                                font.pixelSize: Nexa.Theme.fontSizeXs
                                font.weight: Font.DemiBold
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                        }
                    }

                    // -------------------------------------------------
                    // Type badge (Bottom-Right)
                    // -------------------------------------------------
                    Rectangle {
                        visible: cardRoot.selected
                        anchors {
                            right: parent.right
                            bottom: parent.bottom
                            margins: 18
                        }

                        height: 32
                        width: typeBadgeRow.implicitWidth + 20
                        radius: Nexa.Theme.radiusFull
                        color: Qt.rgba(Nexa.Theme.background.r, Nexa.Theme.background.g, Nexa.Theme.background.b, 0.82)
                        border.width: 1
                        border.color: Qt.rgba(255, 255, 255, 0.15)

                        RowLayout {
                            id: typeBadgeRow
                            anchors.centerIn: parent
                            spacing: 5

                            Rectangle {
                                implicitWidth: 6
                                implicitHeight: 6
                                radius: 3
                                color: cardRoot.isVideo ? Nexa.Theme.error : (cardRoot.isGif ? Nexa.Theme.warning : Nexa.Theme.primary)
                            }

                            Text {
                                text: cardRoot.isVideo ? "VIDEO" : (cardRoot.isGif ? "GIF" : "IMAGE")
                                color: Nexa.Theme.text
                                font.family: Nexa.Theme.monoFont
                                font.pixelSize: Nexa.Theme.fontSize2Xs
                                font.weight: Font.Bold
                            }
                        }
                    }
                    // -------------------------------------------------
                    // Active Wallpaper Pill (Top-Left)
                    // -------------------------------------------------
                    Rectangle {
                        visible: cardRoot.isCurrentWallpaper
                        anchors {
                            left: parent.left
                            top: parent.top
                            margins: 18
                        }
                        height: 28
                        width: activePillRow.implicitWidth + 20
                        radius: Nexa.Theme.radiusFull
                        color: Nexa.Theme.primary
                        border.width: 1
                        border.color: Qt.rgba(255, 255, 255, 0.25)
                        z: 20

                        RowLayout {
                            id: activePillRow
                            anchors.centerIn: parent
                            spacing: 5

                            Text {
                                text: "󰄬"
                                color: Nexa.Theme.onPrimary
                                font.family: Nexa.Theme.iconFontFamily
                                font.pixelSize: 12
                            }

                            Text {
                                text: "CURRENT"
                                color: Nexa.Theme.onPrimary
                                font.family: Nexa.Theme.monoFont
                                font.pixelSize: Nexa.Theme.fontSize2Xs
                                font.weight: Font.Bold
                            }
                        }
                    }
                }

                MouseArea {
                    id: cardMouse
                    anchors.fill: parent

                    enabled:
                        !root.applying &&
                        cardRoot.matches

                    hoverEnabled: true

                    cursorShape:
                        Qt.PointingHandCursor

                    onClicked: {
                        const dir = cardRoot.index > view.currentIndex ? 1 : (cardRoot.index < view.currentIndex ? -1 : 0)
                        if (dir !== 0)
                            root.triggerJiggle(dir)
                        view.currentIndex = cardRoot.index
                        cardRoot.clickScale = 0.95
                        pressReset.restart()
                        root.applyCurrent()
                    }
                }

                Timer {
                    id: pressReset
                    interval: 110

                    onTriggered:
                        cardRoot.clickScale = 1.0
                }

                // -------------------------------------------------
                // Matugen Color Palette & Wallpaper Info Baseplate
                // (Directly below selected card, matching 3D skew in lockstep)
                // -------------------------------------------------
                Item {
                    id: infoPlate
                    visible: cardRoot.selected
                    opacity: cardRoot.selected ? 1.0 : 0.0
                    scale: cardRoot.selected ? 1.0 : 0.96

                    Behavior on opacity {
                        NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
                    }
                    Behavior on scale {
                        NumberAnimation { duration: 240; easing.type: Easing.OutBack; easing.overshoot: 1.15 }
                    }

                    anchors {
                        top: parent.bottom
                        topMargin: 12
                        left: parent.left
                        right: parent.right
                    }

                    height: 44
                    z: 20

                    // Slanted Glass Plate (inherits parent skewContainer Matrix4x4)
                    Rectangle {
                        anchors.fill: parent
                        radius: 8
                        color: Qt.rgba(Nexa.Theme.surfaceContainer.r, Nexa.Theme.surfaceContainer.g, Nexa.Theme.surfaceContainer.b, 0.92)
                        border.width: 1
                        border.color: Nexa.Theme.outlineVariant
                    }

                    // Counter-skewed upright container: ensures all text, icons, and swatches are perfectly upright and crisp
                    Item {
                        id: unskewContent
                        anchors {
                            fill: parent
                            leftMargin: 16
                            rightMargin: 24
                        }

                        transform: Matrix4x4 {
                            property real skew: -(root.skewFactor + (cardRoot.cardJiggle * 0.04))
                            matrix: Qt.matrix4x4(
                                1, skew, 0, 0,
                                0, 1, 0, 0,
                                0, 0, 1, 0,
                                0, 0, 0, 1
                            )
                        }

                        RowLayout {
                            anchors.fill: parent
                            spacing: 8

                            // Format & Resolution Badge
                            Row {
                                spacing: 5
                                Layout.alignment: Qt.AlignVCenter

                                Text {
                                    text: cardRoot.isVideo ? "󰕧" : (cardRoot.isGif ? "󰵸" : "󰋩")
                                    color: Nexa.Theme.primary
                                    font.family: Nexa.Theme.iconFontFamily
                                    font.pixelSize: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Rectangle {
                                    height: 20
                                    radius: Nexa.Theme.radiusFull
                                    color: Nexa.Theme.surfaceContainerHigh
                                    implicitWidth: metaText.implicitWidth + 10
                                    anchors.verticalCenter: parent.verticalCenter

                                    Text {
                                        id: metaText
                                        anchors.centerIn: parent
                                        text: {
                                            if (!root.currentSelectedInfo) return cardRoot.wallType.toUpperCase()
                                            let parts = []
                                            if (root.currentSelectedInfo.format) parts.push(root.currentSelectedInfo.format)
                                            if (root.currentSelectedInfo.width > 0 && root.currentSelectedInfo.height > 0) {
                                                parts.push(root.currentSelectedInfo.width + "×" + root.currentSelectedInfo.height)
                                            }
                                            if (root.currentSelectedInfo.size) parts.push(root.currentSelectedInfo.size.replace(/\s+/g, ""))
                                            return parts.length > 0 ? parts.join(" • ") : cardRoot.wallType.toUpperCase()
                                        }
                                        color: Nexa.Theme.mutedText
                                        font.family: Nexa.Theme.monoFont
                                        font.pixelSize: 8
                                        font.weight: Font.Medium
                                    }
                                }
                            }

                            // Divider
                            Rectangle {
                                width: 1
                                height: 14
                                color: Nexa.Theme.outlineVariant
                                Layout.alignment: Qt.AlignVCenter
                            }

                            // 5 Matugen Swatches
                            Row {
                                spacing: 4
                                Layout.alignment: Qt.AlignVCenter

                                Repeater {
                                    model: [
                                        { label: "PRI", key: "primary" },
                                        { label: "SEC", key: "secondary" },
                                        { label: "TER", key: "tertiary" },
                                        { label: "CON", key: "container" },
                                        { label: "SUR", key: "surface" }
                                    ]

                                    delegate: Rectangle {
                                        id: swatchPill
                                        required property var modelData

                                        readonly property string hexVal: {
                                            if (root.currentSelectedInfo && root.currentSelectedInfo.palette && root.currentSelectedInfo.palette[modelData.key]) {
                                                return String(root.currentSelectedInfo.palette[modelData.key]).toUpperCase()
                                            }
                                            return "#------"
                                        }

                                        readonly property color colorVal: hexVal !== "#------" ? hexVal : Nexa.Theme.surfaceContainerHighest
                                        readonly property bool isCopied: root.copiedColorHex === hexVal

                                        height: 22
                                        radius: Nexa.Theme.radiusFull
                                        color: isCopied
                                            ? Nexa.Theme.primaryContainer
                                            : (swatchMouse.containsMouse ? Nexa.Theme.surfaceContainerHighest : Nexa.Theme.surfaceContainerLow)
                                        border.width: 1
                                        border.color: isCopied
                                            ? Nexa.Theme.primary
                                            : (swatchMouse.containsMouse ? Nexa.Theme.primary : Nexa.Theme.outlineVariant)
                                        implicitWidth: swatchRow.implicitWidth + 8
                                        anchors.verticalCenter: parent.verticalCenter

                                        scale: swatchMouse.containsMouse ? 1.04 : 1.0
                                        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }

                                        Row {
                                            id: swatchRow
                                            anchors.centerIn: parent
                                            spacing: 4

                                            Rectangle {
                                                width: 8
                                                height: 8
                                                radius: 4
                                                color: swatchPill.colorVal
                                                border.width: 1
                                                border.color: Qt.rgba(255, 255, 255, 0.25)
                                                anchors.verticalCenter: parent.verticalCenter
                                            }

                                            Text {
                                                text: swatchPill.isCopied ? "COPIED" : swatchPill.modelData.label
                                                color: swatchPill.isCopied ? Nexa.Theme.primary : Nexa.Theme.mutedText
                                                font.family: Nexa.Theme.monoFont
                                                font.pixelSize: 8
                                                font.weight: Font.Bold
                                                anchors.verticalCenter: parent.verticalCenter
                                            }

                                            Text {
                                                text: swatchPill.hexVal
                                                color: swatchMouse.containsMouse || swatchPill.isCopied ? Nexa.Theme.primary : Nexa.Theme.text
                                                font.family: Nexa.Theme.monoFont
                                                font.pixelSize: 8
                                                font.weight: Font.DemiBold
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                        }

                                        MouseArea {
                                            id: swatchMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (swatchPill.hexVal !== "#------") {
                                                    Quickshell.execDetached(["wl-copy", swatchPill.hexVal])
                                                    root.copiedColorHex = swatchPill.hexVal
                                                    copiedResetTimer.restart()
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            Item {
                                Layout.fillWidth: true
                            }
                        }
                    }
                }
            }
        }
    }

    // ---------------------------------------------------------
    // Slideshow Wallpaper Gallery (Loaded on-demand for 0% CPU & RAM when off)
    // ---------------------------------------------------------

    Loader {
        id: slideshowLoader
        anchors {
            top: parent.top
            topMargin: 48
            left: parent.left
            leftMargin: 56
            right: parent.right
            rightMargin: 56
            bottom: bottomControlsRow.top
            bottomMargin: 18
        }
        z: 400
        active: root.slideshowEnabled
        visible: root.slideshowEnabled
        opacity: root.slideshowEnabled ? 1.0 : 0.0

        Behavior on opacity {
            NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
        }

        sourceComponent: Component {
            SlideshowWallpaperView {
                anchors.fill: parent
                slideshowFolder: root.slideshowFolder
                slideshowType: root.slideshowType
                slideshowTarget: root.slideshowTarget
                lastWallpaper: root.slideshowLastWallpaper

                onApplyWallpaper: (filePath) => {
                    root.applySlideshowWallpaper(filePath)
                }
            }
        }
    }

    // ---------------------------------------------------------
    // Dismiss Menu Backdrop MouseArea
    // ---------------------------------------------------------

    MouseArea {
        anchors.fill: parent
        z: 450
        enabled: root.applyMenuOpen || root.slideshowTimerMenuOpen || root.slideshowTypeMenuOpen || root.slideshowTargetMenuOpen
        onClicked: {
            root.applyMenuOpen = false
            root.closeAllSlideshowMenus()
        }
    }

    // ---------------------------------------------------------
    // Matugen Palette & Wallpaper Metadata Fetcher
    // ---------------------------------------------------------

    property var currentSelectedInfo: null
    property string copiedColorHex: ""

    Timer {
        id: copiedResetTimer
        interval: 1600
        repeat: false
        onTriggered: {
            root.copiedColorHex = ""
        }
    }

    readonly property string currentSelectedWallpaperPath: {
        if (view.currentIndex >= 0 && view.currentIndex < wallpaperModel.count) {
            const item = wallpaperModel.get(view.currentIndex)
            return item ? item.wallPath : ""
        }
        return ""
    }

    Process {
        id: selectedWallpaperInfoProcess
        command: [root.nexad, "wallpaper", "info", root.currentSelectedWallpaperPath]

        stdout: StdioCollector {
            onStreamFinished: {
                if (!this.text || this.text.trim().length === 0) return
                try {
                    const parsed = JSON.parse(this.text.trim())
                    if (parsed && parsed.palette) {
                        root.currentSelectedInfo = parsed
                    }
                } catch (e) {
                    console.log("[WallpaperView] Info parse error:", e)
                }
            }
        }
    }

    Timer {
        id: selectedInfoDebounce
        interval: 350
        repeat: false
        onTriggered: {
            if (view.moving) {
                selectedInfoDebounce.restart()
                return
            }
            if (root.currentSelectedWallpaperPath.length > 0 && !root.slideshowEnabled) {
                if (selectedWallpaperInfoProcess.running) {
                    selectedWallpaperInfoProcess.running = false
                }
                selectedWallpaperInfoProcess.running = true
            }
        }
    }

    onCurrentSelectedWallpaperPathChanged: {
        selectedInfoDebounce.restart()
    }

    // ---------------------------------------------------------
    // Reusable Drop-up Selector Component
    // ---------------------------------------------------------

    component DropUpSelector: Item {
        id: selector
        property string label: ""
        property string currentValue: ""
        property var options: []
        property bool menuOpen: false
        property int menuWidth: 140
        property int itemHeight: 34
        property bool alignLeft: false
        signal selected(string value)
        signal toggled()

        width: selectorContentRow.implicitWidth + 24
        height: 40

        // Popup Drop-up Menu
        Rectangle {
            id: popupMenu
            anchors {
                horizontalCenter: parent.horizontalCenter
                bottom: parent.top
                bottomMargin: 8
            }
            z: 600
            width: selector.menuWidth
            height: selector.options.length * selector.itemHeight + 12
            visible: selector.menuOpen
            radius: Nexa.Theme.radiusMd
            color: Qt.rgba(Nexa.Theme.surface.r, Nexa.Theme.surface.g, Nexa.Theme.surface.b, 0.96)
            border.width: 1
            border.color: Qt.rgba(Nexa.Theme.outline.r, Nexa.Theme.outline.g, Nexa.Theme.outline.b, 0.55)

            Column {
                anchors { fill: parent; margins: 6 }
                spacing: 2

                Repeater {
                    model: selector.options
                    delegate: Rectangle {
                        required property string modelData
                        readonly property bool active: selector.currentValue === modelData

                        width: parent.width
                        height: selector.itemHeight
                        radius: Nexa.Theme.radiusSm
                        color: itemMouse.containsMouse ? Nexa.Theme.hover : (active ? Nexa.Theme.selectedOverlay : "transparent")

                        Behavior on color {
                            ColorAnimation { duration: Nexa.Theme.animationFast }
                        }

                        Text {
                            anchors {
                                left: selector.alignLeft ? parent.left : undefined
                                leftMargin: selector.alignLeft ? 12 : 0
                                centerIn: selector.alignLeft ? undefined : parent
                                verticalCenter: selector.alignLeft ? parent.verticalCenter : undefined
                            }
                            text: modelData
                            color: parent.active ? Nexa.Theme.primary : Nexa.Theme.text
                            font.family: Nexa.Theme.uiFont
                            font.pixelSize: Nexa.Theme.fontSizeSm
                            font.weight: parent.active ? Font.DemiBold : Font.Normal
                        }

                        MouseArea {
                            id: itemMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: selector.selected(modelData)
                        }
                    }
                }
            }
        }

        // Trigger Button
        Rectangle {
            anchors.fill: parent
            radius: Nexa.Theme.radiusSm
            color: btnMouse.containsMouse || selector.menuOpen ? Nexa.Theme.hover : "transparent"

            Behavior on color {
                ColorAnimation { duration: Nexa.Theme.animationFast }
            }

            Row {
                id: selectorContentRow
                anchors.centerIn: parent
                spacing: 6

                Text {
                    text: selector.label
                    color: Nexa.Theme.mutedText
                    font.family: Nexa.Theme.uiFont
                    font.pixelSize: Nexa.Theme.fontSizeSm
                }

                Text {
                    text: selector.currentValue
                    color: selector.menuOpen ? Nexa.Theme.primary : Nexa.Theme.text
                    font.family: Nexa.Theme.uiFont
                    font.pixelSize: Nexa.Theme.fontSizeSm
                    font.weight: Font.DemiBold
                }

                Text {
                    text: selector.menuOpen ? "▾" : "▴"
                    color: selector.menuOpen ? Nexa.Theme.primary : Nexa.Theme.mutedText
                    font.family: Nexa.Theme.uiFont
                    font.pixelSize: Nexa.Theme.fontSizeXs
                }
            }

            MouseArea {
                id: btnMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: selector.toggled()
            }
        }
    }

    // ---------------------------------------------------------
    // Bottom floating controls row
    // ---------------------------------------------------------

    Row {
        id: bottomControlsRow
        anchors {
            horizontalCenter: parent.horizontalCenter
            bottom: parent.bottom
            bottomMargin: 18
        }
        spacing: 14
        z: 500

        // ---------------------------------------------------------
        // Bottom floating filter bar
        // ---------------------------------------------------------

        Rectangle {
            id: filterBar
            visible: !root.slideshowEnabled
            height: 56
            width: filterRow.implicitWidth + 24
            radius: Nexa.Theme.radiusLg
            color: Qt.rgba(Nexa.Theme.surface.r, Nexa.Theme.surface.g, Nexa.Theme.surface.b, 0.92)
            border.width: 1
            border.color: Qt.rgba(Nexa.Theme.outline.r, Nexa.Theme.outline.g, Nexa.Theme.outline.b, 0.55)

            Row {
                id: filterRow
                anchors.centerIn: parent
                spacing: 8

                Repeater {
                    model: ["All", "Image", "GIF", "Video"]
                    delegate: Rectangle {
                        required property string modelData
                        readonly property bool active: root.currentFilter === modelData

                        height: 40
                        width: filterText.implicitWidth + 24
                        radius: Nexa.Theme.radiusSm
                        color: active ? Nexa.Theme.selectedOverlay : (tabMouse.containsMouse ? Nexa.Theme.hover : "transparent")
                        border.width: active ? 1 : 0
                        border.color: Nexa.Theme.primary
                        scale: tabMouse.pressed ? 0.95 : (tabMouse.containsMouse ? 1.03 : 1.0)

                        Behavior on color {
                            ColorAnimation { duration: Nexa.Theme.animationFast }
                        }
                        Behavior on scale {
                            NumberAnimation { duration: Nexa.Theme.animationFast; easing.type: Nexa.Theme.easingEmphasized }
                        }

                        Text {
                            id: filterText
                            anchors.centerIn: parent
                            text: modelData
                            color: parent.active ? Nexa.Theme.primary : Nexa.Theme.mutedText
                            font.family: Nexa.Theme.uiFont
                            font.pixelSize: Nexa.Theme.fontSizeSm
                            font.weight: parent.active ? Font.DemiBold : Font.Normal
                        }

                        MouseArea {
                            id: tabMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.applyMenuOpen = false
                                root.activateFilter(modelData)
                            }
                        }
                    }
                }

                // DIVIDER
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 1
                    height: 24
                    color: Qt.rgba(Nexa.Theme.outline.r, Nexa.Theme.outline.g, Nexa.Theme.outline.b, 0.35)
                }

                // APPLY TARGET
                DropUpSelector {
                    id: applyTargetControl
                    label: "Apply to:"
                    currentValue: root.applyTarget
                    options: ["Background", "Lock Screen", "Both"]
                    menuOpen: root.applyMenuOpen
                    menuWidth: 168
                    itemHeight: 38
                    alignLeft: true
                    onSelected: (val) => root.activateApplyTarget(val)
                    onToggled: {
                        root.closeAllSlideshowMenus()
                        root.applyMenuOpen = !root.applyMenuOpen
                    }
                }
            }
        }

        // ---------------------------------------------------------
        // Bottom floating slideshow bar
        // ---------------------------------------------------------

        Rectangle {
            id: slideshowBar
            height: 56
            width: slideshowRow.implicitWidth + 24
            radius: Nexa.Theme.radiusLg
            color: Qt.rgba(Nexa.Theme.surface.r, Nexa.Theme.surface.g, Nexa.Theme.surface.b, 0.92)
            border.width: 1
            border.color: Qt.rgba(Nexa.Theme.outline.r, Nexa.Theme.outline.g, Nexa.Theme.outline.b, 0.55)

            Behavior on width {
                NumberAnimation { duration: Nexa.Theme.animationFast; easing.type: Nexa.Theme.easingEmphasized }
            }

            Row {
                id: slideshowRow
                anchors.centerIn: parent
                spacing: 8

                // 1. ON/OFF (APPLY) TOGGLE BUTTON
                Rectangle {
                    id: slideshowToggleBtn
                    height: 40
                    width: toggleContentRow.implicitWidth + 22
                    radius: Nexa.Theme.radiusSm
                    color: root.slideshowEnabled ? Nexa.Theme.selectedOverlay : (toggleMouse.containsMouse ? Nexa.Theme.hover : "transparent")
                    border.width: root.slideshowEnabled ? 1 : 0
                    border.color: Nexa.Theme.primary
                    scale: toggleMouse.pressed ? 0.95 : (toggleMouse.containsMouse ? 1.03 : 1.0)

                    Behavior on color {
                        ColorAnimation { duration: Nexa.Theme.animationFast }
                    }
                    Behavior on scale {
                        NumberAnimation { duration: Nexa.Theme.animationFast; easing.type: Nexa.Theme.easingEmphasized }
                    }

                    Row {
                        id: toggleContentRow
                        anchors.centerIn: parent
                        spacing: 8

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 8
                            height: 8
                            radius: 4
                            color: root.slideshowEnabled
                                ? (root.slideshowPaused ? Nexa.Theme.warning : Nexa.Theme.success)
                                : Nexa.Theme.mutedText
                        }

                        Text {
                            text: "Slideshow: " + (root.slideshowEnabled ? "ON" : "OFF")
                            color: root.slideshowEnabled ? Nexa.Theme.primary : Nexa.Theme.mutedText
                            font.family: Nexa.Theme.uiFont
                            font.pixelSize: Nexa.Theme.fontSizeSm
                            font.weight: root.slideshowEnabled ? Font.DemiBold : Font.Normal
                        }
                    }

                    MouseArea {
                        id: toggleMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggleSlideshowEnabled()
                    }
                }

                // DIVIDER
                Rectangle {
                    visible: root.slideshowEnabled
                    anchors.verticalCenter: parent.verticalCenter
                    width: 1
                    height: 24
                    color: Qt.rgba(Nexa.Theme.outline.r, Nexa.Theme.outline.g, Nexa.Theme.outline.b, 0.35)
                }

                // 2. TIMER DROPDOWN
                DropUpSelector {
                    id: slideshowTimerControl
                    visible: root.slideshowEnabled
                    label: "Timer:"
                    currentValue: root.slideshowInterval
                    options: ["5m", "10m", "15m", "30m", "1h"]
                    menuOpen: root.slideshowTimerMenuOpen
                    menuWidth: 108
                    itemHeight: 32
                    alignLeft: false
                    onSelected: (val) => {
                        root.saveSlideshowState(root.slideshowEnabled, root.slideshowPaused, val, root.slideshowType, root.slideshowTarget)
                        root.slideshowTimerMenuOpen = false
                    }
                    onToggled: {
                        root.applyMenuOpen = false
                        root.slideshowTypeMenuOpen = false
                        root.slideshowTargetMenuOpen = false
                        root.slideshowTimerMenuOpen = !root.slideshowTimerMenuOpen
                    }
                }

                // DIVIDER
                Rectangle {
                    visible: root.slideshowEnabled
                    anchors.verticalCenter: parent.verticalCenter
                    width: 1
                    height: 24
                    color: Qt.rgba(Nexa.Theme.outline.r, Nexa.Theme.outline.g, Nexa.Theme.outline.b, 0.35)
                }

                // 3. START/PAUSE & NEXT PLAYBACK CONTROLS
                Row {
                    visible: root.slideshowEnabled
                    spacing: 4
                    opacity: root.slideshowEnabled ? 1.0 : 0.45

                    // PLAY / PAUSE BUTTON
                    Rectangle {
                        id: playPauseBtn
                        height: 40
                        width: playPauseRow.implicitWidth + 18
                        radius: Nexa.Theme.radiusSm
                        color: root.slideshowPaused
                            ? (playPauseMouse.containsMouse ? Nexa.Theme.hover : Qt.rgba(1, 0.8, 0, 0.15))
                            : (playPauseMouse.containsMouse ? Nexa.Theme.hover : "transparent")

                        Row {
                            id: playPauseRow
                            anchors.centerIn: parent
                            spacing: 5

                            Text {
                                text: root.slideshowPaused ? "▶" : "⏸"
                                color: root.slideshowPaused ? Nexa.Theme.warning : Nexa.Theme.primary
                                font.family: Nexa.Theme.uiFont
                                font.pixelSize: Nexa.Theme.fontSizeSm
                            }

                            Text {
                                text: root.slideshowPaused ? "Start" : "Pause"
                                color: root.slideshowPaused ? Nexa.Theme.warning : Nexa.Theme.text
                                font.family: Nexa.Theme.uiFont
                                font.pixelSize: Nexa.Theme.fontSizeSm
                                font.weight: Font.DemiBold
                            }
                        }

                        MouseArea {
                            id: playPauseMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: root.slideshowEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: {
                                if (root.slideshowEnabled) {
                                    root.toggleSlideshowPaused()
                                }
                            }
                        }
                    }

                    // NEXT BUTTON
                    Rectangle {
                        id: nextBtn
                        height: 40
                        width: nextRow.implicitWidth + 18
                        radius: Nexa.Theme.radiusSm
                        color: nextMouse.containsMouse ? Nexa.Theme.hover : "transparent"
                        scale: nextMouse.pressed ? 0.95 : 1.0

                        Behavior on scale {
                            NumberAnimation { duration: Nexa.Theme.animationFast; easing.type: Nexa.Theme.easingEmphasized }
                        }

                        Row {
                            id: nextRow
                            anchors.centerIn: parent
                            spacing: 5

                            Text {
                                text: "⏭"
                                color: Nexa.Theme.primary
                                font.family: Nexa.Theme.uiFont
                                font.pixelSize: Nexa.Theme.fontSizeSm
                            }

                            Text {
                                text: "Next"
                                color: Nexa.Theme.text
                                font.family: Nexa.Theme.uiFont
                                font.pixelSize: Nexa.Theme.fontSizeSm
                                font.weight: Font.DemiBold
                            }
                        }

                        MouseArea {
                            id: nextMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: root.slideshowEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: {
                                if (root.slideshowEnabled) {
                                    root.triggerSlideshowNext()
                                }
                            }
                        }
                    }
                }

                // DIVIDER
                Rectangle {
                    visible: root.slideshowEnabled
                    anchors.verticalCenter: parent.verticalCenter
                    width: 1
                    height: 24
                    color: Qt.rgba(Nexa.Theme.outline.r, Nexa.Theme.outline.g, Nexa.Theme.outline.b, 0.35)
                }

                // 4. TYPE FILTER DROPDOWN
                DropUpSelector {
                    id: slideshowTypeControl
                    visible: root.slideshowEnabled
                    label: "Type:"
                    currentValue: root.slideshowType
                    options: ["All", "Image", "GIF", "Video"]
                    menuOpen: root.slideshowTypeMenuOpen
                    menuWidth: 120
                    itemHeight: 32
                    alignLeft: false
                    onSelected: (val) => {
                        root.saveSlideshowState(root.slideshowEnabled, root.slideshowPaused, root.slideshowInterval, val, root.slideshowTarget)
                        root.slideshowTypeMenuOpen = false
                    }
                    onToggled: {
                        root.applyMenuOpen = false
                        root.slideshowTimerMenuOpen = false
                        root.slideshowTargetMenuOpen = false
                        root.slideshowTypeMenuOpen = !root.slideshowTypeMenuOpen
                    }
                }

                // DIVIDER
                Rectangle {
                    visible: root.slideshowEnabled
                    anchors.verticalCenter: parent.verticalCenter
                    width: 1
                    height: 24
                    color: Qt.rgba(Nexa.Theme.outline.r, Nexa.Theme.outline.g, Nexa.Theme.outline.b, 0.35)
                }

                // 5. APPLY TO DROPDOWN
                DropUpSelector {
                    id: slideshowTargetControl
                    visible: root.slideshowEnabled
                    label: "Apply to:"
                    currentValue: root.slideshowTarget
                    options: ["Background", "Lock Screen", "Both"]
                    menuOpen: root.slideshowTargetMenuOpen
                    menuWidth: 154
                    itemHeight: 36
                    alignLeft: true
                    onSelected: (val) => {
                        root.saveSlideshowState(root.slideshowEnabled, root.slideshowPaused, root.slideshowInterval, root.slideshowType, val)
                        root.slideshowTargetMenuOpen = false
                    }
                    onToggled: {
                        root.applyMenuOpen = false
                        root.slideshowTimerMenuOpen = false
                        root.slideshowTypeMenuOpen = false
                        root.slideshowTargetMenuOpen = !root.slideshowTargetMenuOpen
                    }
                }
            }
        }
    }

    // ---------------------------------------------------------
    // Status / count pill
    // ---------------------------------------------------------

    Rectangle {
        anchors {
            horizontalCenter: parent.horizontalCenter
            bottom: bottomControlsRow.top
            bottomMargin: 10
        }
        visible: root.statusText !== ""
        height: 30
        width: statusLabel.implicitWidth + 22
        radius: Nexa.Theme.radiusFull
        color: Qt.rgba(Nexa.Theme.surface.r, Nexa.Theme.surface.g, Nexa.Theme.surface.b, 0.82)

        Text {
            id: statusLabel
            anchors.centerIn: parent
            text: root.statusText !== "" ? root.statusText : (root.visibleCount() + " wallpapers")
            color: Nexa.Theme.mutedText
            font.family: Nexa.Theme.monoFont
            font.pixelSize: Nexa.Theme.fontSizeXs
        }
    }

    // ---------------------------------------------------------
    // Startup
    // ---------------------------------------------------------

    Component.onCompleted: {
        if (wallpaperConfigFileView.text()) {
            root.parseWallpaperConfig(wallpaperConfigFileView.text())
        }
        if (slideshowConfigFileView.text()) {
            root.parseSlideshowConfig(slideshowConfigFileView.text())
        }
        Qt.callLater(
            () => view.forceActiveFocus()
        )
    }

    onVisibleChanged: {
        root.applying = false
        if (!visible) {
            root.applyMenuOpen = false
            root.closeAllSlideshowMenus()
            return
        }

        wallpaperConfigFileView.reload()
        if (wallpaperConfigFileView.text()) {
            root.parseWallpaperConfig(wallpaperConfigFileView.text())
        }

        slideshowConfigFileView.reload()
        if (slideshowConfigFileView.text()) {
            root.parseSlideshowConfig(slideshowConfigFileView.text())
        }

        reload()
        updateVisibleSelection()

        Qt.callLater(
            () => view.forceActiveFocus()
        )
    }
}
