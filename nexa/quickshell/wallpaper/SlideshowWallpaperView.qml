import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import QtMultimedia
import Qt5Compat.GraphicalEffects
import Qt.labs.folderlistmodel
import Quickshell
import "../theme" as Nexa

Item {
    id: root

    required property string slideshowFolder
    required property string slideshowType
    required property string slideshowTarget
    property string lastWallpaper: ""
    property string searchQuery: ""

    readonly property string homeDir:
        Quickshell.env("HOME")

    readonly property string thumbDir:
        "file://" + homeDir + "/.cache/nexa/wallpapers/slideshow_thumbs/"

    Component.onCompleted: {
        Quickshell.execDetached([homeDir + "/.config/nexa/rust/target/release/nexad", "wallpaper", "slideshow-thumbs"])
        grid.forceActiveFocus()
    }

    onVisibleChanged: {
        if (visible) {
            grid.forceActiveFocus()
            root.syncCurrentSelection()
        }
    }

    signal applyWallpaper(string filePath)

    // ---------------------------------------------------------
    // Selection Synchronization & Apply Action
    // ---------------------------------------------------------
    function applySelected() {
        if (folderModel.count <= 0 || grid.currentIndex < 0 || grid.currentIndex >= folderModel.count)
            return
        const path = folderModel.get(grid.currentIndex, "filePath")
        if (path) {
            root.applyWallpaper(path)
        }
    }

    function syncCurrentSelection() {
        if (!root.lastWallpaper || folderModel.count <= 0) return
        for (let i = 0; i < folderModel.count; ++i) {
            const p = folderModel.get(i, "filePath")
            if (p === root.lastWallpaper || (p && root.lastWallpaper.endsWith("/" + folderModel.get(i, "fileName")))) {
                grid.currentIndex = i
                root.smoothScrollToCurrent()
                return
            }
        }
    }

    Connections {
        target: folderModel
        function onCountChanged() {
            root.syncCurrentSelection()
        }
    }

    onLastWallpaperChanged: {
        root.syncCurrentSelection()
    }

    // ---------------------------------------------------------
    // 60fps Smooth Animated Scrolling & Navigation Engine
    // ---------------------------------------------------------
    property real targetContentY: 0

    NumberAnimation {
        id: scrollAnim
        target: grid
        property: "contentY"
        duration: 220
        easing.type: Easing.OutCubic
    }

    Connections {
        target: grid
        function onMovingChanged() {
            if (grid.moving && scrollAnim.running) {
                scrollAnim.stop()
                root.targetContentY = grid.contentY
            }
        }
    }

    function smoothScrollToCurrent() {
        if (grid.height <= 0 || grid.cellHeight <= 0 || grid.cols <= 0 || folderModel.count <= 0)
            return

        const c = grid.cols
        const row = Math.floor(grid.currentIndex / c)
        const rowTop = row * grid.cellHeight
        const rowBottom = rowTop + grid.cellHeight

        const totalRows = Math.ceil(folderModel.count / c)
        const totalHeight = totalRows * grid.cellHeight
        const maxContentY = Math.max(0, totalHeight - grid.height)

        let currY = scrollAnim.running ? targetContentY : grid.contentY
        currY = Math.max(0, Math.min(maxContentY, currY))

        const pad = 24
        let newTarget = currY

        if (rowTop < currY + pad) {
            newTarget = Math.max(0, rowTop - pad)
        } else if (rowBottom > currY + grid.height - pad) {
            newTarget = Math.min(maxContentY, rowBottom - grid.height + pad)
        }

        targetContentY = newTarget

        if (Math.abs(newTarget - grid.contentY) > 2) {
            scrollAnim.stop()
            scrollAnim.from = grid.contentY
            scrollAnim.to = newTarget
            scrollAnim.restart()
        }
    }

    function selectPrev() {
        if (folderModel.count <= 0) return
        if (grid.currentIndex < 0) {
            grid.currentIndex = 0
        } else if (grid.currentIndex > 0) {
            grid.currentIndex -= 1
        }
        root.smoothScrollToCurrent()
    }

    function selectNext() {
        if (folderModel.count <= 0) return
        if (grid.currentIndex < 0) {
            grid.currentIndex = 0
        } else if (grid.currentIndex < folderModel.count - 1) {
            grid.currentIndex += 1
        }
        root.smoothScrollToCurrent()
    }

    function selectUp() {
        if (folderModel.count <= 0) return
        if (grid.currentIndex < 0) {
            grid.currentIndex = 0
            root.smoothScrollToCurrent()
            return
        }
        const c = grid.cols
        if (grid.currentIndex - c >= 0) {
            grid.currentIndex -= c
            root.smoothScrollToCurrent()
        }
    }

    function selectDown() {
        if (folderModel.count <= 0) return
        if (grid.currentIndex < 0) {
            grid.currentIndex = 0
            root.smoothScrollToCurrent()
            return
        }
        const c = grid.cols
        const total = folderModel.count
        const currentRow = Math.floor(grid.currentIndex / c)
        const totalRows = Math.ceil(total / c)

        if (currentRow >= totalRows - 1) return

        if (grid.currentIndex + c < total) {
            grid.currentIndex += c
        } else {
            grid.currentIndex = total - 1
        }
        root.smoothScrollToCurrent()
    }

    function selectHome() {
        if (folderModel.count <= 0) return
        grid.currentIndex = 0
        root.targetContentY = 0
        scrollAnim.stop()
        scrollAnim.from = grid.contentY
        scrollAnim.to = 0
        scrollAnim.restart()
    }

    function selectEnd() {
        if (folderModel.count <= 0) return
        grid.currentIndex = folderModel.count - 1
        const totalRows = Math.ceil(folderModel.count / grid.cols)
        const totalHeight = totalRows * grid.cellHeight
        const maxContentY = Math.max(0, totalHeight - grid.height)
        root.targetContentY = maxContentY
        scrollAnim.stop()
        scrollAnim.from = grid.contentY
        scrollAnim.to = maxContentY
        scrollAnim.restart()
    }

    function selectPageUp() {
        if (folderModel.count <= 0) return
        const step = grid.cols * 2
        grid.currentIndex = Math.max(0, grid.currentIndex - step)
        root.smoothScrollToCurrent()
    }

    function selectPageDown() {
        if (folderModel.count <= 0) return
        const step = grid.cols * 2
        grid.currentIndex = Math.min(folderModel.count - 1, grid.currentIndex + step)
        root.smoothScrollToCurrent()
    }

    // ---------------------------------------------------------
    // Keyboard Shortcuts (Arrow control & Apply)
    // ---------------------------------------------------------
    Shortcut {
        sequence: "Left"
        enabled: root.visible && folderModel.count > 0
        onActivated: root.selectPrev()
    }

    Shortcut {
        sequence: "Right"
        enabled: root.visible && folderModel.count > 0
        onActivated: root.selectNext()
    }

    Shortcut {
        sequence: "Up"
        enabled: root.visible && folderModel.count > 0
        onActivated: root.selectUp()
    }

    Shortcut {
        sequence: "Down"
        enabled: root.visible && folderModel.count > 0
        onActivated: root.selectDown()
    }

    Shortcut {
        sequence: "Home"
        enabled: root.visible && folderModel.count > 0
        onActivated: root.selectHome()
    }

    Shortcut {
        sequence: "End"
        enabled: root.visible && folderModel.count > 0
        onActivated: root.selectEnd()
    }

    Shortcut {
        sequence: "PageUp"
        enabled: root.visible && folderModel.count > 0
        onActivated: root.selectPageUp()
    }

    Shortcut {
        sequence: "PageDown"
        enabled: root.visible && folderModel.count > 0
        onActivated: root.selectPageDown()
    }

    // Apply Shortcuts
    Shortcut {
        sequence: "Return"
        enabled: root.visible && folderModel.count > 0 && !searchInput.activeFocus
        onActivated: root.applySelected()
    }

    Shortcut {
        sequence: "Enter"
        enabled: root.visible && folderModel.count > 0 && !searchInput.activeFocus
        onActivated: root.applySelected()
    }

    Shortcut {
        sequence: "Space"
        enabled: root.visible && folderModel.count > 0 && !searchInput.activeFocus
        onActivated: root.applySelected()
    }

    Shortcut {
        sequence: "/"
        enabled: root.visible && !searchInput.activeFocus
        onActivated: {
            searchInput.forceActiveFocus()
            searchInput.selectAll()
        }
    }

    Shortcut {
        sequence: "Ctrl+F"
        enabled: root.visible
        onActivated: {
            searchInput.forceActiveFocus()
            searchInput.selectAll()
        }
    }

    // ---------------------------------------------------------
    // Top Info Header
    // ---------------------------------------------------------
    RowLayout {
        id: headerRow
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }
        height: 38

        Rectangle {
            height: 38
            radius: Nexa.Theme.radiusFull
            color: Qt.rgba(Nexa.Theme.surfaceContainer.r, Nexa.Theme.surfaceContainer.g, Nexa.Theme.surfaceContainer.b, 0.88)
            border.width: 1
            border.color: Nexa.Theme.outlineVariant
            implicitWidth: headerContent.implicitWidth + 24

            Row {
                id: headerContent
                anchors.centerIn: parent
                spacing: 10

                Text {
                    text: "󰋩"
                    color: Nexa.Theme.primary
                    font.family: Nexa.Theme.iconFontFamily
                    font.pixelSize: 15
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text: "Slideshow Gallery"
                    color: Nexa.Theme.text
                    font.family: Nexa.Theme.fontFamily
                    font.pixelSize: Nexa.Theme.fontSizeSm
                    font.weight: Font.DemiBold
                    anchors.verticalCenter: parent.verticalCenter
                }

                Rectangle {
                    width: 1
                    height: 14
                    anchors.verticalCenter: parent.verticalCenter
                    color: Nexa.Theme.outlineVariant
                }

                Text {
                    text: root.searchQuery.length > 0 ? (folderModel.count + " Found") : (folderModel.count + " Wallpapers")
                    color: root.searchQuery.length > 0 ? Nexa.Theme.primary : Nexa.Theme.mutedText
                    font.family: Nexa.Theme.fontFamily
                    font.pixelSize: Nexa.Theme.fontSizeXs
                    anchors.verticalCenter: parent.verticalCenter
                }

                Rectangle {
                    width: 1
                    height: 14
                    anchors.verticalCenter: parent.verticalCenter
                    color: Nexa.Theme.outlineVariant
                    visible: root.searchQuery.length === 0
                }

                Text {
                    visible: root.searchQuery.length === 0
                    text: "Arrows • Enter to apply • / to search"
                    color: Nexa.Theme.primary
                    font.family: Nexa.Theme.fontFamily
                    font.pixelSize: Nexa.Theme.fontSizeXs
                    font.weight: Font.Medium
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        Item { Layout.fillWidth: true }

        // Top Search Capsule
        Rectangle {
            id: searchCapsule
            height: 38
            radius: Nexa.Theme.radiusFull
            color: searchInput.activeFocus
                ? Qt.rgba(Nexa.Theme.surfaceContainerHighest.r, Nexa.Theme.surfaceContainerHighest.g, Nexa.Theme.surfaceContainerHighest.b, 0.96)
                : Qt.rgba(Nexa.Theme.surfaceContainer.r, Nexa.Theme.surfaceContainer.g, Nexa.Theme.surfaceContainer.b, 0.88)
            border.width: searchInput.activeFocus ? 2 : 1
            border.color: searchInput.activeFocus ? Nexa.Theme.primary : (root.searchQuery.length > 0 ? Nexa.Theme.primary : Nexa.Theme.outlineVariant)
            implicitWidth: searchInput.activeFocus || root.searchQuery.length > 0 ? 280 : 210

            Behavior on implicitWidth {
                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
            }
            Behavior on border.color {
                ColorAnimation { duration: 150 }
            }
            Behavior on color {
                ColorAnimation { duration: 150 }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 10
                spacing: 8

                Text {
                    text: "󰍉"
                    color: searchInput.activeFocus || root.searchQuery.length > 0 ? Nexa.Theme.primary : Nexa.Theme.mutedText
                    font.family: Nexa.Theme.iconFontFamily
                    font.pixelSize: 15
                    Layout.alignment: Qt.AlignVCenter
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        visible: searchInput.text.length === 0
                        text: "Search wallpapers... (/)"
                        color: Nexa.Theme.mutedText
                        font.family: Nexa.Theme.fontFamily
                        font.pixelSize: Nexa.Theme.fontSizeXs
                        font.weight: Font.Normal
                    }

                    TextInput {
                        id: searchInput
                        anchors.fill: parent
                        verticalAlignment: TextInput.AlignVCenter
                        color: Nexa.Theme.text
                        selectionColor: Nexa.Theme.primary
                        selectedTextColor: Nexa.Theme.onPrimary
                        font.family: Nexa.Theme.fontFamily
                        font.pixelSize: Nexa.Theme.fontSizeXs
                        font.weight: Font.Medium
                        clip: true

                        onTextChanged: {
                            root.searchQuery = text
                        }

                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Escape) {
                                if (text.length > 0) {
                                    text = ""
                                } else {
                                    grid.forceActiveFocus()
                                }
                                event.accepted = true
                                return
                            }
                            if (event.key === Qt.Key_Down) {
                                grid.forceActiveFocus()
                                event.accepted = true
                                return
                            }
                            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                if (folderModel.count > 0) {
                                    root.applySelected()
                                }
                                grid.forceActiveFocus()
                                event.accepted = true
                                return
                            }
                        }
                    }
                }

                // Clear button
                Rectangle {
                    visible: searchInput.text.length > 0
                    width: 18
                    height: 18
                    radius: 9
                    color: clearMouse.containsMouse ? Nexa.Theme.surfaceContainerHighest : "transparent"
                    Layout.alignment: Qt.AlignVCenter

                    Text {
                        anchors.centerIn: parent
                        text: "󰅖"
                        font.family: Nexa.Theme.iconFontFamily
                        font.pixelSize: 12
                        color: clearMouse.containsMouse ? Nexa.Theme.text : Nexa.Theme.mutedText
                    }

                    MouseArea {
                        id: clearMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            searchInput.text = ""
                            searchInput.forceActiveFocus()
                        }
                    }
                }
            }
        }
    }

    // ---------------------------------------------------------
    // Top Floating Glass Inspector Capsule (Matugen Palette & Metadata)
    // ---------------------------------------------------------
    WallpaperInspectorCapsule {
        id: inspectorCapsule
        anchors {
            horizontalCenter: parent.horizontalCenter
            top: parent.top
        }
        height: 38
        z: 60
        visible: folderModel.count > 0 && parent.width >= 1150

        wallpaperPath: {
            if (grid.currentIndex >= 0 && grid.currentIndex < folderModel.count) {
                const p = folderModel.get(grid.currentIndex, "filePath")
                return p ? String(p) : ""
            }
            return ""
        }

        wallpaperTitle: {
            if (grid.currentIndex >= 0 && grid.currentIndex < folderModel.count) {
                const n = folderModel.get(grid.currentIndex, "fileName")
                if (!n) return ""
                let s = String(n)
                const dot = s.lastIndexOf(".")
                if (dot > 0) s = s.substring(0, dot)
                s = s.replace(/[-_][a-z0-9]{8,}$/i, "")
                s = s.replace(/[-_]/g, " ").trim()
                return s.length > 0 ? s.charAt(0).toUpperCase() + s.slice(1) : String(n)
            }
            return ""
        }
    }

    // ---------------------------------------------------------
    // Folder Model (Background Thread C++ Scanner)
    // ---------------------------------------------------------
    FolderListModel {
        id: folderModel
        folder: "file://" + root.slideshowFolder
        nameFilters: {
            const q = root.searchQuery.trim().replace(/\s+/g, "*")
            const wildcard = q.length > 0 ? ("*" + q + "*") : "*"
            const t = root.slideshowType.toLowerCase()
            if (t === "image")
                return [wildcard + ".jpg", wildcard + ".jpeg", wildcard + ".png", wildcard + ".webp"]
            if (t === "gif")
                return [wildcard + ".gif"]
            if (t === "video")
                return [wildcard + ".mp4", wildcard + ".mkv", wildcard + ".webm"]
            return [
                wildcard + ".jpg", wildcard + ".jpeg", wildcard + ".png", wildcard + ".webp",
                wildcard + ".gif", wildcard + ".mp4", wildcard + ".mkv", wildcard + ".webm"
            ]
        }
        caseSensitive: false
        showDirs: false
        showFiles: true
        sortField: FolderListModel.Name
    }

    // ---------------------------------------------------------
    // High-Performance Gallery Grid View (Native 60fps C++ Navigation)
    // ---------------------------------------------------------
    GridView {
        id: grid
        anchors {
            top: headerRow.bottom
            topMargin: 14
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            bottomMargin: 6
        }

        clip: true
        cacheBuffer: 1200
        currentIndex: 0
        focus: true
        keyNavigationEnabled: false
        highlightFollowsCurrentItem: false
        highlightRangeMode: GridView.NoHighlightRange
        boundsBehavior: Flickable.StopAtBounds

        readonly property int cols: Math.max(3, Math.min(5, Math.floor(Math.max(width, 700) / 320)))
        cellWidth: width / cols
        cellHeight: Math.round(cellWidth * 9 / 16) + 12

        model: folderModel

        delegate: Item {
            id: delegateRoot
            width: grid.cellWidth
            height: grid.cellHeight

            readonly property bool isSelected: grid.currentIndex === index
            readonly property bool isHovered: itemMouse.containsMouse
            readonly property bool isHighlighted: isSelected || isHovered

            z: (isHighlighted || delegateRoot.isCurrent) ? 10 : 1

            readonly property string itemFileName: (model.fileName !== undefined && model.fileName !== null) ? String(model.fileName) : ""
            readonly property string itemFilePath: (model.filePath !== undefined && model.filePath !== null) ? String(model.filePath) : ""
            readonly property var itemFileURL: (model.fileURL !== undefined && model.fileURL !== null) ? model.fileURL : ((model.fileUrl !== undefined && model.fileUrl !== null) ? model.fileUrl : ("file://" + itemFilePath))

            readonly property string fileBaseName: {
                const idx = itemFileName.lastIndexOf(".")
                return idx > 0 ? itemFileName.substring(0, idx) : itemFileName
            }

            readonly property string fileSuffix: {
                const idx = itemFileName.lastIndexOf(".")
                return idx > 0 ? itemFileName.substring(idx + 1) : ""
            }

            readonly property string cleanedTitle: {
                let s = fileBaseName
                s = s.replace(/[-_][a-z0-9]{8,}$/i, "")
                s = s.replace(/[-_]/g, " ").trim()
                if (s.length === 0) s = fileBaseName
                return s.charAt(0).toUpperCase() + s.slice(1)
            }

            readonly property string cachedThumb:
                root.thumbDir + fileBaseName + ".jpg"

            readonly property bool isCurrent:
                root.lastWallpaper.length > 0 &&
                (root.lastWallpaper === itemFilePath || root.lastWallpaper.endsWith("/" + itemFileName))

            readonly property bool isVideoFile: {
                const s = fileSuffix.toLowerCase()
                return s === "mp4" || s === "mkv" || s === "webm"
            }

            readonly property bool isGifFile:
                fileSuffix.toLowerCase() === "gif"

            // -------------------------------------------------
            // Ambient Wallpaper Color Aura (Rounded contour halo)
            // -------------------------------------------------
            Item {
                id: auraLayer
                anchors.fill: cardFrame
                anchors.margins: -14
                z: -1
                opacity: delegateRoot.isHighlighted ? 0.60 : (delegateRoot.isCurrent ? 0.40 : 0.0)
                scale: delegateRoot.isHighlighted ? 1.03 : 0.98

                Behavior on opacity {
                    NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
                }
                Behavior on scale {
                    NumberAnimation { duration: 250; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
                }

                layer.enabled: true
                layer.effect: OpacityMask {
                    maskSource: Rectangle {
                        width: auraLayer.width
                        height: auraLayer.height
                        radius: 22
                    }
                }

                Image {
                    id: auraSourceImg
                    anchors.fill: parent
                    source: delegateRoot.cachedThumb
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    sourceSize.width: 48
                    sourceSize.height: 36
                    visible: false

                    onStatusChanged: {
                        if (status === Image.Error && !delegateRoot.isVideoFile && String(source) !== String(delegateRoot.itemFileURL)) {
                            source = delegateRoot.itemFileURL
                        }
                    }
                }

                MultiEffect {
                    anchors.fill: parent
                    source: auraSourceImg
                    blurEnabled: true
                    blur: 1.0
                    blurMax: 32
                    saturation: 0.70
                    brightness: 0.08
                }
            }

            // -------------------------------------------------
            // Interactive Card Frame (Pop spring physics)
            // -------------------------------------------------
            Item {
                id: cardFrame
                anchors {
                    fill: parent
                    margins: 8
                }

                scale: itemMouse.pressed ? 0.96 : (delegateRoot.isHighlighted ? 1.045 : 1.0)

                Behavior on scale {
                    NumberAnimation {
                        duration: 220
                        easing.type: Easing.OutBack
                        easing.overshoot: 1.35
                    }
                }

                // -------------------------------------------------
                // Masked Content (Clipped with 14px rounded corners)
                // -------------------------------------------------
                Item {
                    id: maskedContent
                    anchors.fill: parent

                    layer.enabled: true
                    layer.effect: OpacityMask {
                        maskSource: Rectangle {
                            width: maskedContent.width
                            height: maskedContent.height
                            radius: 14
                        }
                    }

                    // Background placeholder
                    Rectangle {
                        anchors.fill: parent
                        color: Qt.rgba(Nexa.Theme.surfaceContainerLow.r, Nexa.Theme.surfaceContainerLow.g, Nexa.Theme.surfaceContainerLow.b, 0.92)

                        Text {
                            anchors.centerIn: parent
                            visible: thumb.status !== Image.Ready
                            text: delegateRoot.isVideoFile ? "󰕧" : (delegateRoot.isGifFile ? "󰵸" : "󰋩")
                            font.family: Nexa.Theme.iconFontFamily
                            font.pixelSize: 36
                            color: Qt.rgba(1, 1, 1, 0.25)
                        }
                    }

                    // Thumbnail Image (Full-bleed 16:9 wallpaper)
                    Image {
                        id: thumb
                        anchors.fill: parent
                        source: delegateRoot.cachedThumb
                        asynchronous: true
                        cache: true
                        sourceSize.width: 480
                        sourceSize.height: 270
                        fillMode: Image.PreserveAspectCrop

                        onStatusChanged: {
                            if (status === Image.Error) {
                                if (!delegateRoot.isVideoFile && String(source) !== String(delegateRoot.itemFileURL)) {
                                    source = delegateRoot.itemFileURL
                                } else if (delegateRoot.isVideoFile) {
                                    const alt = root.homeDir + "/.cache/nexa/wallpapers/video/" + delegateRoot.fileBaseName + ".jpg"
                                    if (String(source) !== "file://" + alt) {
                                        source = "file://" + alt
                                    }
                                }
                            }
                        }
                    }

                    // Animated GIF Live Preview (Plays when highlighted/selected)
                    AnimatedImage {
                        id: gifPlayer
                        anchors.fill: parent
                        source: delegateRoot.isGifFile ? delegateRoot.itemFileURL : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                        playing: delegateRoot.isGifFile && delegateRoot.isHighlighted
                        visible: delegateRoot.isGifFile && delegateRoot.isHighlighted && status === AnimatedImage.Ready
                    }

                    // Live Video Preview (On-demand MediaPlayer when highlighted/selected)
                    Loader {
                        id: videoPlayerLoader
                        anchors.fill: parent
                        active: delegateRoot.isVideoFile && delegateRoot.isHighlighted
                        visible: active
                        sourceComponent: Component {
                            Item {
                                anchors.fill: parent

                                MediaPlayer {
                                    id: previewPlayer
                                    source: delegateRoot.itemFileURL
                                    loops: MediaPlayer.Infinite
                                    audioOutput: AudioOutput { muted: true }
                                    videoOutput: previewOutput
                                    autoPlay: true
                                }

                                VideoOutput {
                                    id: previewOutput
                                    anchors.fill: parent
                                    fillMode: VideoOutput.PreserveAspectCrop
                                    visible: previewPlayer.playbackState === MediaPlayer.PlayingState
                                }
                            }
                        }
                    }

                    // Cinematic Dark Scrim Gradient
                    Rectangle {
                        anchors {
                            left: parent.left
                            right: parent.right
                            bottom: parent.bottom
                        }
                        height: 58
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "transparent" }
                            GradientStop { position: 0.45; color: Qt.rgba(0, 0, 0, 0.45) }
                            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.88) }
                        }
                    }

                    // Bottom Metadata & Hover Action Row
                    RowLayout {
                        anchors {
                            left: parent.left
                            right: parent.right
                            bottom: parent.bottom
                            leftMargin: 12
                            rightMargin: 12
                            bottomMargin: 9
                        }
                        spacing: 8

                        Text {
                            text: delegateRoot.cleanedTitle
                            color: delegateRoot.isHighlighted ? Nexa.Theme.primary : "#ffffff"
                            font.family: Nexa.Theme.fontFamily
                            font.pixelSize: 12
                            font.weight: delegateRoot.isCurrent ? Font.DemiBold : Font.Medium
                            elide: Text.ElideRight
                            Layout.fillWidth: true

                            Behavior on color {
                                ColorAnimation { duration: 150 }
                            }
                        }

                        // Floating Apply Pill on Hover / Selection
                        Rectangle {
                            visible: delegateRoot.isHighlighted && !delegateRoot.isCurrent
                            height: 22
                            radius: Nexa.Theme.radiusFull
                            color: Qt.rgba(Nexa.Theme.primary.r, Nexa.Theme.primary.g, Nexa.Theme.primary.b, 0.90)
                            implicitWidth: actionLabel.implicitWidth + 14

                            Row {
                                id: actionLabel
                                anchors.centerIn: parent
                                spacing: 4

                                Text {
                                    text: "󰄲"
                                    color: Nexa.Theme.onPrimary
                                    font.family: Nexa.Theme.iconFontFamily
                                    font.pixelSize: 11
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    text: "Apply"
                                    color: Nexa.Theme.onPrimary
                                    font.family: Nexa.Theme.fontFamily
                                    font.pixelSize: 10
                                    font.weight: Font.Bold
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }
                    }
                }

                // -------------------------------------------------
                // Crisp Rounded Border Stroke
                // -------------------------------------------------
                Rectangle {
                    anchors.fill: parent
                    radius: 14
                    color: "transparent"
                    border.width: delegateRoot.isCurrent ? 2 : (delegateRoot.isHighlighted ? 2 : 1)
                    border.color: delegateRoot.isCurrent
                        ? Nexa.Theme.primary
                        : (delegateRoot.isHighlighted ? Nexa.Theme.primary : Qt.rgba(255, 255, 255, 0.12))

                    Behavior on border.color {
                        ColorAnimation { duration: 160 }
                    }
                }

                // Video / GIF Badge (Top Right)
                Rectangle {
                    visible: delegateRoot.isVideoFile || delegateRoot.isGifFile
                    anchors {
                        top: parent.top
                        right: parent.right
                        margins: 10
                    }
                    height: 22
                    radius: Nexa.Theme.radiusFull
                    color: delegateRoot.isVideoFile
                        ? Qt.rgba(0.85, 0.15, 0.15, 0.88)
                        : Qt.rgba(0.95, 0.55, 0.10, 0.88)
                    border.width: 1
                    border.color: Qt.rgba(255, 255, 255, 0.25)
                    implicitWidth: typeContent.implicitWidth + 12

                    Row {
                        id: typeContent
                        anchors.centerIn: parent
                        spacing: 4

                        Text {
                            text: delegateRoot.isVideoFile ? "󰕧" : "󰵸"
                            color: "#ffffff"
                            font.family: Nexa.Theme.iconFontFamily
                            font.pixelSize: 11
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: delegateRoot.isVideoFile ? "VIDEO" : "GIF"
                            color: "#ffffff"
                            font.family: Nexa.Theme.monoFont
                            font.pixelSize: 9
                            font.weight: Font.Bold
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                // Active Wallpaper Pill (Top Left)
                Rectangle {
                    visible: delegateRoot.isCurrent
                    anchors {
                        top: parent.top
                        left: parent.left
                        margins: 10
                    }
                    height: 24
                    radius: Nexa.Theme.radiusFull
                    color: Nexa.Theme.primary
                    implicitWidth: activeContent.implicitWidth + 16

                    Row {
                        id: activeContent
                        anchors.centerIn: parent
                        spacing: 5

                        Text {
                            text: "󰄬"
                            color: Nexa.Theme.onPrimary
                            font.family: Nexa.Theme.iconFontFamily
                            font.pixelSize: 12
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: "ACTIVE"
                            color: Nexa.Theme.onPrimary
                            font.family: Nexa.Theme.fontFamily
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                // Interactive Mouse Area
                MouseArea {
                    id: itemMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor

                    onClicked: {
                        grid.currentIndex = index
                        root.smoothScrollToCurrent()
                    }

                    onDoubleClicked: {
                        root.applyWallpaper(delegateRoot.itemFilePath)
                    }
                }
            }
        }
    }

    // ---------------------------------------------------------
    // Subtle Scroll Indicator
    // ---------------------------------------------------------
    Rectangle {
        anchors {
            right: parent.right
            rightMargin: -10
            top: grid.top
            bottom: grid.bottom
        }
        width: 4
        radius: 2
        color: Nexa.Theme.outlineVariant
        opacity: grid.moving ? 0.75 : 0.2
        visible: folderModel.count > 0

        Behavior on opacity {
            NumberAnimation { duration: 200 }
        }

        Rectangle {
            id: scrollThumb
            width: parent.width
            radius: 2
            color: Nexa.Theme.primary
            height: Math.max(30, grid.visibleArea.heightRatio * parent.height)
            y: grid.visibleArea.yPosition * parent.height
        }
    }

    // ---------------------------------------------------------
    // Empty State
    // ---------------------------------------------------------
    Column {
        anchors.centerIn: parent
        visible: folderModel.count === 0
        spacing: 12

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.searchQuery.length > 0 ? "󰍉" : "󰋩"
            font.family: Nexa.Theme.iconFontFamily
            font.pixelSize: 48
            color: Nexa.Theme.mutedText
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.searchQuery.length > 0
                ? ("No wallpapers match \"" + root.searchQuery + "\"")
                : ("No wallpapers found matching \"" + root.slideshowType + "\" in ~/Pictures/Wallpapers/Slideshow")
            font.family: Nexa.Theme.fontFamily
            font.pixelSize: Nexa.Theme.fontSizeMd
            color: Nexa.Theme.mutedText
        }

        Rectangle {
            visible: root.searchQuery.length > 0
            anchors.horizontalCenter: parent.horizontalCenter
            height: 32
            radius: Nexa.Theme.radiusFull
            color: clearEmptyMouse.containsMouse ? Nexa.Theme.surfaceContainerHighest : Nexa.Theme.surfaceContainer
            border.width: 1
            border.color: Nexa.Theme.outlineVariant
            implicitWidth: clearEmptyRow.implicitWidth + 24

            Row {
                id: clearEmptyRow
                anchors.centerIn: parent
                spacing: 6

                Text {
                    text: "󰅖"
                    font.family: Nexa.Theme.iconFontFamily
                    font.pixelSize: 13
                    color: Nexa.Theme.primary
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text: "Clear search"
                    font.family: Nexa.Theme.fontFamily
                    font.pixelSize: Nexa.Theme.fontSizeSm
                    font.weight: Font.Medium
                    color: Nexa.Theme.primary
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            MouseArea {
                id: clearEmptyMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.searchQuery = ""
                    searchInput.text = ""
                    grid.forceActiveFocus()
                }
            }
        }
    }
}
