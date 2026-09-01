import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import QtMultimedia

import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "../theme" as NTheme

PanelWindow {
    id: root

    visible: false
    focusable: true
    color: "transparent"

    GlobalShortcut {
        appid: "nexa"
        name: "wallpaper"
        description: "Toggle NEXA wallpaper picker"

        onPressed: {
            root.visible = !root.visible

            if (root.visible)
                root.forceActiveFocus()
        }
    }

    exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    WlrLayershell.layer: WlrLayer.Overlay

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
            "list"
        ]

        listProcess.running = true
    }

    function parseWallpaperList(output) {
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

            newItems.push({
                wallType: type,
                wallPath: path,
                wallThumb: thumb,
                wallName: fileName(path)
            })
        }

        // Reconcile: check if items actually changed
        let hasChanges = false
        if (newItems.length !== wallpaperModel.count) {
            hasChanges = true
        } else {
            for (let i = 0; i < newItems.length; ++i) {
                const current = wallpaperModel.get(i)
                if (!current || current.wallPath !== newItems[i].wallPath) {
                    hasChanges = true
                    break
                }
            }
        }

        if (hasChanges || !loaded) {
            wallpaperModel.clear()
            for (let i = 0; i < newItems.length; ++i) {
                wallpaperModel.append(newItems[i])
            }
            updateVisibleSelection()
        }

        loaded = true

        if (wallpaperModel.count === 0)
            statusText = "No wallpapers found"
        else
            statusText = ""
    }

    function matchesFilter(type, name) {
        if (currentFilter === "All")
            return true

        if (currentFilter === "Image")
            return type === "image"

        if (currentFilter === "GIF")
            return type === "gif"

        if (currentFilter === "Video")
            return type === "video"

        return true
    }

    function findNextValid(start, direction) {
        if (wallpaperModel.count <= 0)
            return -1

        let index = start

        for (let i = 0; i < wallpaperModel.count; ++i) {
            index =
                (
                    index
                    + direction
                    + wallpaperModel.count
                )
                % wallpaperModel.count

            const item =
                wallpaperModel.get(index)

            if (
                matchesFilter(
                    item.wallType,
                    item.wallName
                )
            ) {
                return index
            }
        }

        return -1
    }

    function firstValidIndex() {
        for (
            let i = 0;
            i < wallpaperModel.count;
            ++i
        ) {
            const item =
                wallpaperModel.get(i)

            if (
                matchesFilter(
                    item.wallType,
                    item.wallName
                )
            ) {
                return i
            }
        }

        return -1
    }

    function visibleCount() {
        let count = 0

        for (
            let i = 0;
            i < wallpaperModel.count;
            ++i
        ) {
            const item =
                wallpaperModel.get(i)

            if (
                matchesFilter(
                    item.wallType,
                    item.wallName
                )
            ) {
                ++count
            }
        }

        return count
    }

    function updateVisibleSelection() {
        const first = firstValidIndex()

        view.currentIndex = first

        if (first >= 0) {
            Qt.callLater(() => {
                view.positionViewAtIndex(
                    first,
                    ListView.Center
                )

                view.forceActiveFocus()
            })
        }
    }

    function move(direction) {
        if (wallpaperModel.count <= 0)
            return

        const next =
            findNextValid(
                view.currentIndex,
                direction
            )

        if (next >= 0)
            view.currentIndex = next
    }

    function applyCurrent() {
      if (applying)
          return

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
      // BACKGROUND
      // =========================================================

      if (applyTarget === "Background") {
          applying = true

          statusText =
              "Applying "
              + entry.wallName
              + " to background..."

          Quickshell.execDetached([
              applyScript,
              entry.wallPath
          ])

          closeTimer.restart()
          return
      }


      // =========================================================
      // LOCK SCREEN
      // =========================================================

      if (applyTarget === "Lock Screen") {
          applying = true

          statusText =
              "Applying "
              + entry.wallName
              + " to lock screen..."

          Quickshell.execDetached([
              nexad,
              "wallpaper",
              "lock-set",
              entry.wallPath
          ])

          closeTimer.restart()
          return
      }


      // =========================================================
      // BOTH
      // =========================================================

      if (applyTarget === "Both") {
          applying = true

          statusText =
              "Applying "
              + entry.wallName
              + " to both..."

          Quickshell.execDetached([
              applyScript,
              entry.wallPath
          ])

          Quickshell.execDetached([
              nexad,
              "wallpaper",
              "lock-set",
              entry.wallPath
          ])

          closeTimer.restart()
      }
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

    function handleEscape() {
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

    // ---------------------------------------------------------
    // Keyboard
    // ---------------------------------------------------------

    Shortcut {
        sequence: "Left"

        enabled:
            root.visible &&
            !root.applying

        onActivated:
            root.move(-1)
    }

    Shortcut {
        sequence: "Right"

        enabled:
            root.visible &&
            !root.applying

        onActivated:
            root.move(1)
    }

    Shortcut {
        sequence: "Return"

        enabled:
            root.visible &&
            !root.applying

        onActivated:
            root.applyCurrent()
    }

    Shortcut {
        sequence: "Escape"

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

        color: "#59000000"

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

        anchors.fill: parent

        orientation:
            ListView.Horizontal

        spacing: 0

        model:
            wallpaperModel

        focus: true
        clip: false

        interactive:
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

        highlightMoveDuration: 420
        highlightMoveVelocity: -1

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
            required property string wallName

            readonly property bool matches:
                root.matchesFilter(
                    wallType,
                    wallName
                )

            readonly property bool selected:
                ListView.isCurrentItem &&
                matches

            readonly property bool isImage:
                wallType === "image"

            readonly property bool isGif:
                wallType === "gif"

            readonly property bool isVideo:
                wallType === "video"

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
                NumberAnimation {
                    duration: 360
                    easing.type: Easing.OutQuint
                }
            }

            Behavior on height {
                NumberAnimation {
                    duration: 360
                    easing.type: Easing.OutQuint
                }
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
                            root.skewFactor

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
                        duration:
                            NTheme.Theme.animationFast

                        easing.type:
                            NTheme.Theme.easingEmphasized
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
                        NTheme.Theme.surface

                    radius: 0

                    border.width:
                        cardRoot.selected ? 2 : 1

                    border.color:
                        cardRoot.selected
                        ? NTheme.Theme.primary
                        : (cardMouse.containsMouse ? NTheme.Theme.borderStrong : NTheme.Theme.outlineVariant)

                    clip: true

                    Rectangle {
                        anchors.fill: parent
                        color: "#000000"
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
                            cardRoot.isVideo
                            ? root.fileUrl(cardRoot.wallPath)
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

                    Connections {
                        target: cardRoot

                        function onSelectedChanged() {
                            if (!cardRoot.isVideo)
                                return

                            if (cardRoot.selected) {
                                previewPlayer.position = 0
                                previewPlayer.play()
                            } else {
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
                        radius: NTheme.Theme.radiusFull
                        color: Qt.rgba(NTheme.Theme.background.r, NTheme.Theme.background.g, NTheme.Theme.background.b, 0.82)
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
                                color: NTheme.Theme.primary
                                font.family: NTheme.Theme.iconFont
                                font.pixelSize: 13
                            }

                            Text {
                                text: cardRoot.wallName.replace(/\.[^/.]+$/, "").replace(/[-_]/g, " ")
                                color: NTheme.Theme.text
                                font.family: NTheme.Theme.fontFamily
                                font.pixelSize: NTheme.Theme.fontSizeXs
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
                        radius: NTheme.Theme.radiusFull
                        color: Qt.rgba(NTheme.Theme.background.r, NTheme.Theme.background.g, NTheme.Theme.background.b, 0.82)
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
                                color: cardRoot.isVideo ? "#EF4444" : (cardRoot.isGif ? "#F59E0B" : NTheme.Theme.primary)
                            }

                            Text {
                                text: cardRoot.isVideo ? "VIDEO" : (cardRoot.isGif ? "GIF" : "IMAGE")
                                color: NTheme.Theme.text
                                font.family: NTheme.Theme.monoFont
                                font.pixelSize: NTheme.Theme.fontSize2Xs
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
            }
        }
    }

    // ---------------------------------------------------------
    // Bottom floating filter bar
    // ---------------------------------------------------------

    Rectangle {
        id: filterBar

        anchors {
            horizontalCenter:
                parent.horizontalCenter

            bottom:
                parent.bottom

            bottomMargin:
                18
        }

        z: 100

        height: 56

        width:
            filterRow.implicitWidth + 24

        radius:
            NTheme.Theme.radiusLg

        color:
            Qt.rgba(
                NTheme.Theme.surface.r,
                NTheme.Theme.surface.g,
                NTheme.Theme.surface.b,
                0.92
            )

        border.width: 1

        border.color:
            Qt.rgba(
                NTheme.Theme.outline.r,
                NTheme.Theme.outline.g,
                NTheme.Theme.outline.b,
                0.55
            )


        Row {
            id: filterRow

            anchors.centerIn: parent

            spacing: 8


            // =====================================================
            // WALLPAPER TYPE FILTERS
            // =====================================================

            Repeater {
                model: [
                    "All",
                    "Image",
                    "GIF",
                    "Video"
                ]


                delegate: Rectangle {
                    required property string modelData

                    readonly property bool active:
                        root.currentFilter
                        === modelData


                    height: 40

                    width:
                        filterText.implicitWidth
                        + 24

                    radius:
                        NTheme.Theme.radiusSm


                    color:
                        active
                        ? NTheme.Theme.selectedOverlay
                        : (tabMouse.containsMouse ? NTheme.Theme.hover : "transparent")


                    border.width:
                        active ? 1 : 0

                    border.color:
                        NTheme.Theme.primary

                    scale:
                        tabMouse.pressed
                        ? 0.95
                        : (tabMouse.containsMouse ? 1.03 : 1.0)


                    Behavior on color {
                        ColorAnimation {
                            duration:
                                NTheme.Theme.animationFast
                        }
                    }

                    Behavior on scale {
                        NumberAnimation {
                            duration: NTheme.Theme.animationFast
                            easing.type: NTheme.Theme.easingEmphasized
                        }
                    }


                    Text {
                        id: filterText

                        anchors.centerIn:
                            parent

                        text:
                            modelData

                        color:
                            parent.active
                            ? NTheme.Theme.primary
                            : NTheme.Theme.mutedText

                        font.family:
                            NTheme.Theme.uiFont

                        font.pixelSize:
                            NTheme.Theme.fontSizeSm

                        font.weight:
                            parent.active
                            ? Font.DemiBold
                            : Font.Normal
                    }


                    MouseArea {
                        id: tabMouse
                        anchors.fill:
                            parent

                        hoverEnabled:
                            true

                        cursorShape:
                            Qt.PointingHandCursor

                        onClicked: {
                            root.applyMenuOpen = false

                            root.activateFilter(
                                modelData
                            )
                        }
                    }
                }
            }


            // =====================================================
            // DIVIDER
            // =====================================================

            Rectangle {
                anchors.verticalCenter:
                    parent.verticalCenter

                width: 1
                height: 24

                color:
                    Qt.rgba(
                        NTheme.Theme.outline.r,
                        NTheme.Theme.outline.g,
                        NTheme.Theme.outline.b,
                        0.35
                    )
            }


            // =====================================================
            // APPLY TARGET
            // =====================================================

            Item {
                id: applyTargetControl

                width: 168
                height: 40


                // -------------------------------------------------
                // DROP-UP MENU
                // -------------------------------------------------

                Rectangle {
                    id: applyMenu

                    anchors {
                        horizontalCenter:
                            applyButton.horizontalCenter

                        bottom:
                            applyButton.top

                        bottomMargin:
                            8
                    }

                    z: 500

                    width: 168
                    height: 132

                    visible:
                        root.applyMenuOpen

                    radius:
                        NTheme.Theme.radiusMd

                    color:
                        Qt.rgba(
                            NTheme.Theme.surface.r,
                            NTheme.Theme.surface.g,
                            NTheme.Theme.surface.b,
                            0.96
                        )

                    border.width: 1

                    border.color:
                        Qt.rgba(
                            NTheme.Theme.outline.r,
                            NTheme.Theme.outline.g,
                            NTheme.Theme.outline.b,
                            0.55
                        )


                    Column {
                        anchors {
                            fill: parent
                            margins: 6
                        }

                        spacing: 2


                        Repeater {
                            model: [
                                "Background",
                                "Lock Screen",
                                "Both"
                            ]


                            delegate: Rectangle {
                                required property string modelData

                                readonly property bool active:
                                    root.applyTarget
                                    === modelData


                                width:
                                    parent.width

                                height: 38

                                radius:
                                    NTheme.Theme.radiusSm


                                color:
                                    targetMouse.containsMouse
                                    ? NTheme.Theme.hover
                                    : active
                                        ? NTheme.Theme.selectedOverlay
                                        : "transparent"


                                Behavior on color {
                                    ColorAnimation {
                                        duration:
                                            NTheme.Theme.animationFast
                                    }
                                }


                                Text {
                                    anchors {
                                        left:
                                            parent.left

                                        verticalCenter:
                                            parent.verticalCenter

                                        leftMargin:
                                            12
                                    }

                                    text:
                                        modelData

                                    color:
                                        parent.active
                                        ? NTheme.Theme.primary
                                        : NTheme.Theme.text

                                    font.family:
                                        NTheme.Theme.uiFont

                                    font.pixelSize:
                                        NTheme.Theme.fontSizeSm

                                    font.weight:
                                        parent.active
                                        ? Font.DemiBold
                                        : Font.Normal
                                }


                                MouseArea {
                                    id: targetMouse

                                    anchors.fill:
                                        parent

                                    hoverEnabled:
                                        true

                                    cursorShape:
                                        Qt.PointingHandCursor


                                    onClicked:
                                        root.activateApplyTarget(
                                            modelData
                                        )
                                }
                            }
                        }
                    }
                }


                // -------------------------------------------------
                // APPLY-TO BUTTON
                // -------------------------------------------------

                Rectangle {
                    id: applyButton

                    anchors.fill:
                        parent

                    radius:
                        NTheme.Theme.radiusSm


                    color:
                        applyMouse.containsMouse
                        || root.applyMenuOpen
                        ? NTheme.Theme.hover
                        : "transparent"


                    Behavior on color {
                        ColorAnimation {
                            duration:
                                NTheme.Theme.animationFast
                        }
                    }


                    Row {
                        anchors.centerIn:
                            parent

                        spacing: 7


                        Text {
                            text:
                                "Apply to:"

                            color:
                                NTheme.Theme.mutedText

                            font.family:
                                NTheme.Theme.uiFont

                            font.pixelSize:
                                NTheme.Theme.fontSizeSm
                        }


                        Text {
                            text:
                                root.applyTarget

                            color:
                                root.applyMenuOpen
                                ? NTheme.Theme.primary
                                : NTheme.Theme.text

                            font.family:
                                NTheme.Theme.uiFont

                            font.pixelSize:
                                NTheme.Theme.fontSizeSm

                            font.weight:
                                Font.DemiBold
                        }


                        Text {
                            text:
                                root.applyMenuOpen
                                ? "▾"
                                : "▴"

                            color:
                                root.applyMenuOpen
                                ? NTheme.Theme.primary
                                : NTheme.Theme.mutedText

                            font.family:
                                NTheme.Theme.uiFont

                            font.pixelSize:
                                NTheme.Theme.fontSizeXs
                        }
                    }


                    MouseArea {
                        id: applyMouse

                        anchors.fill:
                            parent

                        hoverEnabled:
                            true

                        cursorShape:
                            Qt.PointingHandCursor


                        onClicked:
                            root.applyMenuOpen =
                                !root.applyMenuOpen
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
            horizontalCenter:
                parent.horizontalCenter

            bottom:
                filterBar.top

            bottomMargin:
                10
        }

        visible:
            root.statusText !== ""

        height: 30

        width:
            statusLabel.implicitWidth + 22

        radius:
            NTheme.Theme.radiusFull

        color:
            Qt.rgba(
                NTheme.Theme.surface.r,
                NTheme.Theme.surface.g,
                NTheme.Theme.surface.b,
                0.82
            )

        Text {
            id: statusLabel

            anchors.centerIn:
                parent

            text: {
                if (root.statusText !== "")
                    return root.statusText

                return root.visibleCount()
                    + " wallpapers"
            }

            color:
                NTheme.Theme.mutedText

            font.family:
                NTheme.Theme.monoFont

            font.pixelSize:
                NTheme.Theme.fontSizeXs
        }
    }

    // ---------------------------------------------------------
    // Startup
    // ---------------------------------------------------------

    Component.onCompleted: {
        Qt.callLater(
            () => view.forceActiveFocus()
        )
    }

    onVisibleChanged: {
        if (!visible)
            return

        reload()

        Qt.callLater(
            () => view.forceActiveFocus()
        )
    }
}
