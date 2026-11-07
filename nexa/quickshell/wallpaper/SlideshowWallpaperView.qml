import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import QtMultimedia
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import "../NewNexaUI" as NexaUI

Item {
    id: root

    required property string slideshowFolder
    required property string slideshowType
    required property string slideshowTarget
    property string lastWallpaper: ""
    property string searchQuery: ""

    readonly property string homeDir: Quickshell.env("HOME")
    readonly property string nexad: homeDir + "/.config/nexa/rust/target/release/nexad"
    readonly property string thumbDir: "file://" + homeDir + "/.cache/nexa/wallpapers/slideshow_thumbs/"

    function fileUrl(path) {
        if (!path || path.length === 0) return "";
        if (path.startsWith("file://")) return path;
        return "file://" + encodeURI(path);
    }

    signal applyWallpaper(string filePath)
    signal closeRequested()

    // =========================================================================
    // [EXTENSION POINT]: ADD NEW WALLPAPER VIEW SHAPES & LAYOUTS HERE
    // =========================================================================
    property var gridMetrics: ({ columns: 5, cell_height_ratio: 0.5625, corner_radius: 14 })

    Process {
        id: layoutProcess
        command: [nexad, "wallpaper", "layout", "--width", String(root.width || 1920), "--height", String(root.height || 1080), "--mode", "grid"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                if (!this.text || this.text.trim() === "") return;
                try {
                    const p = JSON.parse(this.text.trim());
                    if (p.grid) root.gridMetrics = p.grid;
                } catch (e) {}
            }
        }
    }

    onWidthChanged: if (root.visible && !layoutProcess.running) layoutProcess.running = true

    // Rust-driven Wallpaper Scanner & In-Memory Model
    property var allSlideshowItems: []

    Process {
        id: slideshowListProcess
        command: [nexad, "wallpaper", "list", root.slideshowFolder, "--json"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                if (!this.text || this.text.trim() === "") return;
                try {
                    const data = JSON.parse(this.text.trim());
                    root.allSlideshowItems = data.wallpapers || [];
                    root.filterAndPopulateModel();
                } catch (e) {
                    console.warn("[SlideshowWallpaperView] Error parsing slideshow JSON:", e);
                }
            }
        }
    }

    function reload() {
        if (!slideshowListProcess.running) slideshowListProcess.running = true;
        if (!layoutProcess.running) layoutProcess.running = true;
    }

    function filterAndPopulateModel() {
        const q = root.searchQuery.trim().toLowerCase();
        const t = root.slideshowType.toLowerCase();
        folderModel.clear();
        for (let i = 0; i < root.allSlideshowItems.length; ++i) {
            const it = root.allSlideshowItems[i];
            const kind = (it.kind || "").toLowerCase();
            if (t !== "all" && kind !== t) continue;
            if (q.length > 0 && !it.name.toLowerCase().includes(q)) continue;
            folderModel.append({
                fileName: it.name, filePath: it.path, fileURL: "file://" + it.path,
                wallType: it.kind, wallThumb: it.thumb, wallProxy: it.proxy, formattedSize: it.formatted_size
            });
        }
        root.syncCurrentSelection();
    }

    onSearchQueryChanged: filterAndPopulateModel()
    onSlideshowTypeChanged: filterAndPopulateModel()
    onLastWallpaperChanged: syncCurrentSelection()

    Component.onCompleted: { root.reload(); grid.forceActiveFocus(); }
    onVisibleChanged: if (visible) { root.reload(); grid.forceActiveFocus(); root.syncCurrentSelection(); }

    function applySelected() {
        if (folderModel.count <= 0 || grid.currentIndex < 0 || grid.currentIndex >= folderModel.count) return;
        const it = folderModel.get(grid.currentIndex);
        if (it && it.filePath) root.applyWallpaper(it.filePath);
    }

    function syncCurrentSelection() {
        if (!root.lastWallpaper || folderModel.count <= 0) return;
        for (let i = 0; i < folderModel.count; ++i) {
            const it = folderModel.get(i);
            if (!it) continue;
            const p = it.filePath;
            if (p === root.lastWallpaper || (p && root.lastWallpaper.endsWith("/" + it.fileName))) {
                grid.currentIndex = i;
                grid.positionViewAtIndex(i, GridView.Contain);
                return;
            }
        }
    }

    Shortcut {
        sequence: "/"
        enabled: root.visible && !searchInput.activeFocus
        onActivated: { searchInput.forceActiveFocus(); searchInput.selectAll(); }
    }

    // Top Header Row (100% Sourced from NewNexaUI Tokens)
    RowLayout {
        id: headerRow
        anchors { top: parent.top; topMargin: 16; left: parent.left; leftMargin: 16; right: parent.right; rightMargin: 16 }
        height: 38

        // Left Capsule: Info & Count
        Rectangle {
            height: 38
            radius: NexaUI.NexaTokens.radiusPill
            color: NexaUI.NexaColors.surfaceContainer
            border.width: NexaUI.NexaTokens.borderThin
            border.color: NexaUI.NexaColors.border
            implicitWidth: headerContent.implicitWidth + 28

            // Apple Tactile 4-stop Depth Micro-Gradient
            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                antialiasing: true
                visible: NexaUI.NexaOptics.surface3DGradient && NexaUI.NexaOptics.gradientIntensity > 0.01
                opacity: NexaUI.NexaOptics.gradientIntensity
                gradient: Gradient {
                    GradientStop { position: 0.00; color: Qt.rgba(1, 1, 1, 0.045) }
                    GradientStop { position: 0.40; color: Qt.rgba(1, 1, 1, 0.010) }
                    GradientStop { position: 0.70; color: Qt.rgba(0, 0, 0, 0.000) }
                    GradientStop { position: 1.00; color: Qt.rgba(0, 0, 0, 0.120) }
                }
            }

            // Top Chamfer Specular Highlight
            Rectangle {
                anchors.top: parent.top
                anchors.topMargin: 1
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.max(0, parent.width - parent.radius * 1.6)
                height: 1
                visible: NexaUI.NexaOptics.specularHighlight && NexaUI.NexaOptics.specularIntensity > 0.01
                opacity: Math.min(1.0, NexaUI.NexaOptics.specularIntensity / 0.28)
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.30) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }

            Row {
                id: headerContent
                anchors.centerIn: parent
                spacing: 10
                Text { text: "󰋩"; color: NexaUI.NexaColors.primary; font.family: NexaUI.NexaTypography.familyIcon; font.pixelSize: 15; anchors.verticalCenter: parent.verticalCenter }
                Text { text: "Slideshow Gallery"; color: NexaUI.NexaColors.text; font.family: NexaUI.NexaTypography.familyBody; font.pixelSize: NexaUI.NexaTypography.sizeSm; font.weight: NexaUI.NexaTypography.weightSemiBold; anchors.verticalCenter: parent.verticalCenter }
                Rectangle { width: 1; height: 14; anchors.verticalCenter: parent.verticalCenter; color: NexaUI.NexaColors.border }
                Text { text: root.searchQuery.length > 0 ? (folderModel.count + " Found") : (folderModel.count + " Wallpapers"); color: root.searchQuery.length > 0 ? NexaUI.NexaColors.primary : NexaUI.NexaColors.mutedText; font.family: NexaUI.NexaTypography.familyBody; font.pixelSize: NexaUI.NexaTypography.sizeXs; anchors.verticalCenter: parent.verticalCenter }
                Rectangle { width: 1; height: 14; anchors.verticalCenter: parent.verticalCenter; color: NexaUI.NexaColors.border; visible: root.searchQuery.length === 0 }
                Text { visible: root.searchQuery.length === 0; text: "Arrows • Enter to apply • / to search"; color: NexaUI.NexaColors.primary; font.family: NexaUI.NexaTypography.familyBody; font.pixelSize: NexaUI.NexaTypography.sizeXs; font.weight: NexaUI.NexaTypography.weightMedium; anchors.verticalCenter: parent.verticalCenter }
            }
        }

        Item { Layout.fillWidth: true }

        // Right Capsule: Search Field
        Rectangle {
            id: searchCapsule
            height: 38
            radius: NexaUI.NexaTokens.radiusPill
            color: searchInput.activeFocus ? NexaUI.NexaColors.surfaceContainerHighest : NexaUI.NexaColors.surfaceContainer
            border.width: searchInput.activeFocus ? NexaUI.NexaTokens.borderMedium : NexaUI.NexaTokens.borderThin
            border.color: searchInput.activeFocus ? NexaUI.NexaColors.primary : (root.searchQuery.length > 0 ? NexaUI.NexaColors.primary : NexaUI.NexaColors.border)
            implicitWidth: searchInput.activeFocus || root.searchQuery.length > 0 ? 280 : 210
            Behavior on implicitWidth { NumberAnimation { duration: NexaUI.NexaMotion.durationFast; easing.type: NexaUI.NexaMotion.decelerateEasing } }

            // Apple Tactile 4-stop Depth Micro-Gradient
            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                antialiasing: true
                visible: NexaUI.NexaOptics.surface3DGradient && NexaUI.NexaOptics.gradientIntensity > 0.01
                opacity: NexaUI.NexaOptics.gradientIntensity
                gradient: Gradient {
                    GradientStop { position: 0.00; color: Qt.rgba(1, 1, 1, 0.045) }
                    GradientStop { position: 0.40; color: Qt.rgba(1, 1, 1, 0.010) }
                    GradientStop { position: 0.70; color: Qt.rgba(0, 0, 0, 0.000) }
                    GradientStop { position: 1.00; color: Qt.rgba(0, 0, 0, 0.120) }
                }
            }

            // Top Chamfer Specular Highlight
            Rectangle {
                anchors.top: parent.top
                anchors.topMargin: 1
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.max(0, parent.width - parent.radius * 1.6)
                height: 1
                visible: NexaUI.NexaOptics.specularHighlight && NexaUI.NexaOptics.specularIntensity > 0.01
                opacity: Math.min(1.0, NexaUI.NexaOptics.specularIntensity / 0.28)
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.30) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }

            RowLayout {
                anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 12; spacing: 8
                Text { text: "󰍉"; color: searchInput.activeFocus || root.searchQuery.length > 0 ? NexaUI.NexaColors.primary : NexaUI.NexaColors.mutedText; font.family: NexaUI.NexaTypography.familyIcon; font.pixelSize: 15; Layout.alignment: Qt.AlignVCenter }
                Item {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    Text { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; visible: searchInput.text.length === 0; text: "Search wallpapers... (/)"; color: NexaUI.NexaColors.mutedText; font.family: NexaUI.NexaTypography.familyBody; font.pixelSize: NexaUI.NexaTypography.sizeXs }
                    TextInput {
                        id: searchInput
                        anchors.fill: parent; verticalAlignment: TextInput.AlignVCenter; color: NexaUI.NexaColors.text
                        selectionColor: NexaUI.NexaColors.primary; font.family: NexaUI.NexaTypography.familyBody; font.pixelSize: NexaUI.NexaTypography.sizeXs; font.weight: NexaUI.NexaTypography.weightMedium; clip: true
                        onTextChanged: root.searchQuery = text
                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Escape) {
                                if (text.length > 0) text = "";
                                else root.closeRequested();
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Down) {
                                grid.forceActiveFocus();
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                if (folderModel.count > 0) root.applySelected();
                                grid.forceActiveFocus();
                                event.accepted = true;
                            }
                        }
                    }
                }
                Text {
                    visible: searchInput.text.length > 0; text: "󰅖"; font.family: NexaUI.NexaTypography.familyIcon; font.pixelSize: 13; color: NexaUI.NexaColors.mutedText; Layout.alignment: Qt.AlignVCenter
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { searchInput.text = ""; searchInput.forceActiveFocus(); } }
                }
            }
        }
    }

    // Top Center Floating Inspector Capsule
    WallpaperInspectorCapsule {
        id: inspectorCapsule
        anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 16 }
        height: 38; z: 60; visible: folderModel.count > 0 && parent.width >= 1150
        wallpaperPath: {
            if (grid.currentIndex >= 0 && grid.currentIndex < folderModel.count) {
                const it = folderModel.get(grid.currentIndex);
                return it && it.filePath ? String(it.filePath) : "";
            }
            return "";
        }
        wallpaperTitle: {
            if (grid.currentIndex >= 0 && grid.currentIndex < folderModel.count) {
                const it = folderModel.get(grid.currentIndex);
                const n = it ? it.fileName : "";
                if (!n) return "";
                let s = String(n);
                const dot = s.lastIndexOf(".");
                return (dot > 0 ? s.substring(0, dot) : s).replace(/[-_]/g, " ").trim();
            }
            return "";
        }
    }

    ListModel { id: folderModel }

    // High-Performance Grid View
    GridView {
        id: grid
        anchors { top: headerRow.bottom; topMargin: 14; left: parent.left; right: parent.right; bottom: parent.bottom; bottomMargin: 6 }
        clip: true; cacheBuffer: 1200; currentIndex: 0; focus: true; boundsBehavior: Flickable.StopAtBounds
        readonly property int cols: root.gridMetrics.columns || 5
        cellWidth: width / cols
        cellHeight: Math.round(cellWidth * (root.gridMetrics.cell_height_ratio || 0.5625)) + 12
        model: folderModel

        NexaUI.NexaScroll {}

        delegate: Item {
            id: delegateRoot
            width: grid.cellWidth; height: grid.cellHeight
            readonly property bool isSelected: grid.currentIndex === index
            readonly property bool isHovered: itemMouse.containsMouse
            readonly property bool isHighlighted: isSelected || isHovered
            z: isHighlighted ? 10 : 1

            readonly property string itemFileName: model.fileName || ""
            readonly property string itemFilePath: model.filePath || ""
            readonly property string fileBaseName: {
                const idx = itemFileName.lastIndexOf(".");
                return idx > 0 ? itemFileName.substring(0, idx) : itemFileName;
            }
            readonly property string cachedThumb: root.thumbDir + fileBaseName + ".jpg"
            readonly property bool isCurrent: root.lastWallpaper.length > 0 && (root.lastWallpaper === itemFilePath || root.lastWallpaper.endsWith("/" + itemFileName))
            readonly property bool isVideoFile: (model.wallType || "").toLowerCase() === "video"
            readonly property bool isGifFile: (model.wallType || "").toLowerCase() === "gif"

            // Ambient Halo Aura
            Item {
                anchors.fill: cardFrame; anchors.margins: -12; z: -1
                opacity: delegateRoot.isHighlighted ? 0.65 : (delegateRoot.isCurrent ? 0.40 : 0.0)
                Behavior on opacity { NumberAnimation { duration: 200 } }
                layer.enabled: true
                layer.effect: OpacityMask {
                    maskSource: Rectangle { width: cardFrame.width + 24; height: cardFrame.height + 24; radius: (root.gridMetrics.corner_radius || NexaUI.NexaTokens.radiusLg) + 6 }
                }
                Image {
                    id: auraImg; anchors.fill: parent; source: delegateRoot.cachedThumb; fillMode: Image.PreserveAspectCrop; asynchronous: true; visible: false
                    onStatusChanged: if (status === Image.Error) source = model.fileURL || ""
                }
                MultiEffect { anchors.fill: parent; source: auraImg; blurEnabled: true; blur: 1.0; blurMax: 32; saturation: 0.75 }
            }

            // Card Frame with Nexa Motion Spring Physics
            Item {
                id: cardFrame
                anchors.fill: parent; anchors.margins: 8
                scale: itemMouse.pressed ? 0.96 : (delegateRoot.isHighlighted ? 1.035 : 1.0)
                Behavior on scale {
                    SpringAnimation {
                        spring: NexaUI.NexaMotion.effectiveSpring
                        damping: NexaUI.NexaMotion.effectiveDamping
                        mass: NexaUI.NexaMotion.effectiveMass
                        epsilon: 0.05
                    }
                }

                Item {
                    id: maskedContent
                    anchors.fill: parent
                    layer.enabled: true
                    layer.effect: OpacityMask {
                        maskSource: Rectangle { width: maskedContent.width; height: maskedContent.height; radius: root.gridMetrics.corner_radius || NexaUI.NexaTokens.radiusLg }
                    }
                    Rectangle { anchors.fill: parent; color: NexaUI.NexaColors.surfaceContainerLow }

                    // Static Thumbnail (Always loaded first by Rust)
                    Image {
                        id: thumb; anchors.fill: parent; source: delegateRoot.cachedThumb; asynchronous: true; cache: true
                        sourceSize.width: 480; sourceSize.height: 270; fillMode: Image.PreserveAspectCrop
                        onStatusChanged: if (status === Image.Error) source = model.fileURL || ""
                    }

                    // GIF playback on hover/selection
                    AnimatedImage {
                        anchors.fill: parent
                        source: (delegateRoot.isGifFile && delegateRoot.isHighlighted) ? (model.fileURL || "") : ""
                        fillMode: Image.PreserveAspectCrop
                        playing: delegateRoot.isGifFile && delegateRoot.isHighlighted
                        visible: delegateRoot.isGifFile && delegateRoot.isHighlighted
                    }

                    // Video playback on hover/selection (plays fast proxy generated by Rust)
                    Loader {
                        id: videoPlayerLoader
                        anchors.fill: parent
                        active: delegateRoot.isVideoFile && delegateRoot.isHighlighted && root.visible
                        visible: active
                        sourceComponent: Component {
                            Item {
                                anchors.fill: parent
                                MediaPlayer {
                                    id: gridPlayer
                                    source: root.fileUrl(model.wallProxy && model.wallProxy.length > 0 ? model.wallProxy : model.filePath)
                                    loops: MediaPlayer.Infinite
                                    audioOutput: AudioOutput { muted: true }
                                    videoOutput: gridVideoOut
                                    autoPlay: true
                                    Component.onCompleted: play()
                                }

                                VideoOutput {
                                    id: gridVideoOut
                                    anchors.fill: parent
                                    fillMode: VideoOutput.PreserveAspectCrop
                                    visible: gridPlayer.playbackState === MediaPlayer.PlayingState
                                }
                            }
                        }
                    }

                    // Bottom Gradient Scrim
                    Rectangle {
                        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                        height: 54
                        gradient: Gradient { GradientStop { position: 0.0; color: "transparent" } GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.85) } }
                    }

                    Text {
                        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 10 }
                        text: delegateRoot.fileBaseName; color: delegateRoot.isHighlighted ? NexaUI.NexaColors.primary : NexaUI.NexaColors.text
                        font.family: NexaUI.NexaTypography.familyBody; font.pixelSize: 12; font.weight: delegateRoot.isCurrent ? NexaUI.NexaTypography.weightSemiBold : NexaUI.NexaTypography.weightMedium; elide: Text.ElideRight
                    }
                }

                // Tag Badge: VIDEO (Red) / GIF (Orange)
                Rectangle {
                    visible: delegateRoot.isVideoFile || delegateRoot.isGifFile
                    anchors { top: parent.top; right: parent.right; margins: 8 }
                    height: 20; radius: 10
                    color: delegateRoot.isVideoFile ? NexaUI.NexaColors.alpha(NexaUI.NexaColors.error, 0.90) : NexaUI.NexaColors.alpha(NexaUI.NexaColors.warning, 0.90)
                    implicitWidth: tagRow.implicitWidth + 10
                    Row {
                        id: tagRow; anchors.centerIn: parent; spacing: 4
                        Text { text: delegateRoot.isVideoFile ? "󰕧" : "󰵸"; color: "#ffffff"; font.family: NexaUI.NexaTypography.familyIcon; font.pixelSize: 10; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: delegateRoot.isVideoFile ? "VIDEO" : "GIF"; color: "#ffffff"; font.family: NexaUI.NexaTypography.familyMono; font.pixelSize: 9; font.weight: NexaUI.NexaTypography.weightBold; anchors.verticalCenter: parent.verticalCenter }
                    }
                }

                // Active Wallpaper Tag (Top Left)
                Rectangle {
                    visible: delegateRoot.isCurrent
                    anchors { top: parent.top; left: parent.left; margins: 8 }
                    height: 20; radius: 10
                    color: NexaUI.NexaColors.alpha(NexaUI.NexaColors.primary, 0.90)
                    implicitWidth: activeRow.implicitWidth + 10
                    Row {
                        id: activeRow; anchors.centerIn: parent; spacing: 4
                        Text { text: "✓"; color: NexaUI.NexaColors.onPrimary; font.family: NexaUI.NexaTypography.familyBody; font.pixelSize: 10; font.weight: NexaUI.NexaTypography.weightBold; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: "ACTIVE"; color: NexaUI.NexaColors.onPrimary; font.family: NexaUI.NexaTypography.familyMono; font.pixelSize: 8; font.weight: NexaUI.NexaTypography.weightBold; anchors.verticalCenter: parent.verticalCenter }
                    }
                }

                Rectangle {
                    anchors.fill: parent; radius: root.gridMetrics.corner_radius || NexaUI.NexaTokens.radiusLg; color: "transparent"
                    border.width: delegateRoot.isCurrent || delegateRoot.isHighlighted ? 2 : 1
                    border.color: delegateRoot.isCurrent || delegateRoot.isHighlighted ? NexaUI.NexaColors.primary : NexaUI.NexaColors.alpha(NexaUI.NexaColors.onSurface, 0.12)
                }

                MouseArea {
                    id: itemMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (grid.currentIndex === index) {
                            root.applySelected();
                        } else {
                            grid.currentIndex = index;
                            grid.forceActiveFocus();
                        }
                    }
                    onDoubleClicked: {
                        grid.currentIndex = index;
                        root.applySelected();
                    }
                }
            }
        }

        Keys.onPressed: event => {
            const cols = grid.cols;
            if (event.key === Qt.Key_Left) { if (grid.currentIndex > 0) grid.currentIndex--; event.accepted = true; }
            else if (event.key === Qt.Key_Right) { if (grid.currentIndex < folderModel.count - 1) grid.currentIndex++; event.accepted = true; }
            else if (event.key === Qt.Key_Up) { if (grid.currentIndex - cols >= 0) grid.currentIndex -= cols; event.accepted = true; }
            else if (event.key === Qt.Key_Down) { if (grid.currentIndex + cols < folderModel.count) grid.currentIndex += cols; event.accepted = true; }
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { root.applySelected(); event.accepted = true; }
            else if (event.key === Qt.Key_Escape) { root.closeRequested(); event.accepted = true; }
        }
    }
}
