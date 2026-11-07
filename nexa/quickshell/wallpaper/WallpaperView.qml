import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Controls
import QtMultimedia
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "../NewNexaUI" as NexaUI

PanelWindow {
    id: root

    visible: false
    focusable: true
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    anchors { top: true; bottom: true; left: true; right: true }
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    readonly property string homeDir: Quickshell.env("HOME")
    readonly property string nexad: homeDir + "/.config/nexa/rust/target/release/nexad"

    function fileUrl(path) {
        if (!path || path.length === 0) return "";
        if (path.startsWith("file://")) return path;
        return "file://" + encodeURI(path);
    }

    property bool loaded: false
    property string currentFilter: "All"
    property string applyTarget: "Background"
    property int currentIndex: 0
    property string currentWallpaperPath: ""
    property string currentLockWallpaperPath: ""

    // Slideshow state
    property bool slideshowEnabled: false
    property bool slideshowPaused: false
    property string slideshowInterval: "30m"
    property string slideshowType: "All"
    property string slideshowTarget: "Background"
    property string slideshowLastWallpaper: ""
    readonly property string slideshowFolder: homeDir + "/Pictures/Wallpapers/Slideshow"

    function closeWallpaper() {
        root.visible = false;
    }

    Shortcut {
        sequence: "Escape"
        context: Qt.ApplicationShortcut
        enabled: root.visible
        onActivated: root.closeWallpaper()
    }

    Shortcut {
        sequence: "Left"
        context: Qt.ApplicationShortcut
        enabled: root.visible && !root.slideshowEnabled
        onActivated: root.stepIndex(-1)
    }

    Shortcut {
        sequence: "Right"
        context: Qt.ApplicationShortcut
        enabled: root.visible && !root.slideshowEnabled
        onActivated: root.stepIndex(1)
    }

    function handleApplyRequest() {
        if (root.slideshowEnabled) {
            if (slideshowLoader.item && typeof slideshowLoader.item.applySelected === "function") {
                slideshowLoader.item.applySelected();
            }
        } else {
            root.applySelected();
        }
    }

    Shortcut {
        sequence: "Return"
        context: Qt.ApplicationShortcut
        enabled: root.visible
        onActivated: root.handleApplyRequest()
    }

    Shortcut {
        sequence: "Enter"
        context: Qt.ApplicationShortcut
        enabled: root.visible
        onActivated: root.handleApplyRequest()
    }

    // =========================================================================
    // [EXTENSION POINT]: ADD NEW WALLPAPER VIEW SHAPES & LAYOUTS HERE
    // =========================================================================
    property var layoutMetrics: ({
        card_width: 400, card_height: 420, selected_width: 600, selected_height: 450,
        side_width: 200, item_spacing: 10, skew_factor: -0.35, media_center_offset: 0.32
    })
    readonly property real selectedWidth: layoutMetrics.selected_width || 600
    readonly property real selectedHeight: layoutMetrics.selected_height || 450
    readonly property real sideWidth: layoutMetrics.side_width || 200
    readonly property real cardHeight: layoutMetrics.card_height || 420
    readonly property real itemSpacing: layoutMetrics.item_spacing || 10
    readonly property real skewFactor: layoutMetrics.skew_factor || -0.35

    Process {
        id: layoutProcess
        command: [nexad, "wallpaper", "layout", "--width", String(root.width || 1920), "--height", String(root.height || 1080), "--mode", "carousel"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                if (!this.text || this.text.trim() === "") return;
                try {
                    const parsed = JSON.parse(this.text.trim());
                    if (parsed.carousel) root.layoutMetrics = parsed.carousel;
                } catch (e) {}
            }
        }
    }

    // Config file sync with Nexa Settings
    FileView {
        id: slideshowFileView
        path: homeDir + "/.config/nexa/config/slideshow.json"
        watchChanges: true
        onFileChanged: slideshowFileView.reload()
        onLoaded: {
            try {
                const st = JSON.parse(text());
                root.slideshowEnabled = st.enabled === true;
                root.slideshowPaused = st.paused === true;
                root.slideshowInterval = st.interval || "30m";
                root.slideshowType = st.type_filter || "All";
                root.slideshowTarget = st.apply_target || "Background";
                root.applyTarget = st.apply_target || "Background";
                root.slideshowLastWallpaper = st.last_wallpaper || "";
            } catch (e) {}
        }
    }

    FileView {
        id: wallpaperConfView
        path: homeDir + "/.config/nexa/config/wallpaper.conf"
        watchChanges: true
        onFileChanged: wallpaperConfView.reload()
        onLoaded: {
            const m = text().match(/WALLPAPER=(.+)/);
            if (m && m[1]) root.currentWallpaperPath = m[1].replace(/^["']|["']$/g, "").trim();
        }
    }

    FileView {
        id: lockscreenConfView
        path: homeDir + "/.config/nexa/config/lockscreen.conf"
        watchChanges: true
        onFileChanged: lockscreenConfView.reload()
        onLoaded: {
            const m = text().match(/WALLPAPER=(.+)/);
            if (m && m[1]) root.currentLockWallpaperPath = m[1].replace(/^["']|["']$/g, "").trim();
        }
    }

    // Rust Wallpaper List Scanner
    property var rawWallpapers: []
    Process {
        id: listProcess
        command: [nexad, "wallpaper", "list", "--json"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                if (!this.text || this.text.trim() === "") return;
                try {
                    const data = JSON.parse(this.text.trim());
                    if (data.current_desktop) root.currentWallpaperPath = data.current_desktop;
                    if (data.current_lock) root.currentLockWallpaperPath = data.current_lock;
                    root.rawWallpapers = data.wallpapers || [];
                    root.populateModel();
                    root.loaded = true;
                } catch (e) {
                    console.warn("[WallpaperView] List JSON parse error:", e);
                }
            }
        }
    }

    // Idempotency: Avoid redundant wallpaper re-application if already active on target
    function isCurrentlyApplied(path, target) {
        if (!path || path.trim() === "") return false;
        const norm = p => {
            if (!p) return "";
            let s = p.trim().replace(/^file:\/\//, "");
            try { return decodeURI(s); } catch (e) { return s; }
        };
        const pNorm = norm(path);
        const deskNorm = norm(root.currentWallpaperPath);
        const lockNorm = norm(root.currentLockWallpaperPath);
        const t = (target || root.applyTarget || "Background").toLowerCase();

        if (t === "background") {
            return pNorm !== "" && pNorm === deskNorm;
        } else if (t === "lock screen" || t === "lock" || t === "lockscreen") {
            return pNorm !== "" && pNorm === lockNorm;
        } else if (t === "both") {
            return pNorm !== "" && pNorm === deskNorm && pNorm === lockNorm;
        }
        return false;
    }

    // Rust Wallpaper Apply Engine (apply.rs)
    function applySelected(pathOverride) {
        let p = pathOverride;
        if (!p && filteredModel.count > 0 && carouselList.currentIndex >= 0 && carouselList.currentIndex < filteredModel.count) {
            p = filteredModel.get(carouselList.currentIndex).wallPath;
        }
        if (!p) return;
        const target = root.applyTarget || "Background";

        if (root.isCurrentlyApplied(p, target)) {
            console.log("[WallpaperView] Wallpaper is already applied to target (" + target + "):", p);
            root.closeWallpaper();
            return;
        }

        Quickshell.execDetached([nexad, "wallpaper", "apply", p, "--target", target]);
        if (root.slideshowEnabled) {
            Quickshell.execDetached([nexad, "wallpaper", "slideshow", "set", "--current", p]);
        }
        const t = target.toLowerCase();
        if (t === "background" || t === "both") {
            root.currentWallpaperPath = p;
        }
        if (t === "lock screen" || t === "lock" || t === "both") {
            root.currentLockWallpaperPath = p;
        }
        root.closeWallpaper();
    }

    function toggleSlideshow() {
        const nextState = !root.slideshowEnabled;
        root.slideshowEnabled = nextState;
        dispatchSlideshowCmd(["set", "--enabled", nextState ? "true" : "false"]);
        if (!nextState) {
            carouselList.forceActiveFocus();
        }
    }

    function dispatchSlideshowCmd(args) {
        Quickshell.execDetached([nexad, "wallpaper", "slideshow"].concat(args));
    }

    Process {
        id: nextProcess
        command: [nexad, "wallpaper", "slideshow", "next"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                if (!this.text || this.text.trim() === "") return;
                try {
                    const res = JSON.parse(this.text.trim());
                    if (res && res.wallpaper) {
                        root.slideshowLastWallpaper = res.wallpaper;
                        if (root.applyTarget === "Background" || root.applyTarget === "Both") {
                            root.currentWallpaperPath = res.wallpaper;
                        }
                        if (root.applyTarget === "Lock Screen" || root.applyTarget === "Both") {
                            root.currentLockWallpaperPath = res.wallpaper;
                        }
                    }
                } catch (e) {}
            }
        }
    }

    // Matugen Info & Palette Process
    property var currentSelectedInfo: null
    Process {
        id: infoProcess
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                if (!this.text || this.text.trim() === "") return;
                try { root.currentSelectedInfo = JSON.parse(this.text.trim()); } catch (e) {}
            }
        }
    }

    Timer {
        id: infoDebounce; interval: 80; repeat: false
        onTriggered: {
            if (filteredModel.count > 0 && carouselList.currentIndex >= 0 && carouselList.currentIndex < filteredModel.count) {
                const cur = filteredModel.get(carouselList.currentIndex);
                if (cur && cur.wallPath) { infoProcess.command = [nexad, "wallpaper", "info", cur.wallPath]; infoProcess.running = true; }
            }
        }
    }

    // Fluid Spring & Jiggle Physics Engine (Mapped to Nexa Theme Motion Settings)
    property real jiggleOffset: 0.0
    property real jiggleVelocity: 0.0
    readonly property real jiggleStiffness: NexaUI.NexaMotion.useSpring("wallpaper") ? (NexaUI.NexaMotion.springStiffness * 18.0) : 140.0
    readonly property real jiggleDamping: NexaUI.NexaMotion.useSpring("wallpaper") ? (NexaUI.NexaMotion.springDamping * 28.0) : 8.5
    property real lastContentX: 0.0

    function triggerJiggle(direction) {
        if (!NexaUI.NexaMotion.useSpring("wallpaper")) return;
        jiggleVelocity += direction * 9.0;
        jigglePhysics.running = true;
    }

    FrameAnimation {
        id: jigglePhysics
        running: false

        onTriggered: {
            const dt = Math.min(frameTime, 0.04);
            if (dt <= 0.0001) return;

            const currentX = carouselList.contentX;
            const contentDx = currentX - root.lastContentX;
            root.lastContentX = currentX;

            if (carouselList.moving && Math.abs(contentDx) > 0.3) {
                root.jiggleVelocity += (-contentDx / dt) * 0.0006;
            }

            const springForce = (-root.jiggleStiffness * root.jiggleOffset) - (root.jiggleDamping * root.jiggleVelocity);
            root.jiggleVelocity += springForce * dt;
            root.jiggleOffset += root.jiggleVelocity * dt;

            if (Math.abs(root.jiggleOffset) < 0.0005 && Math.abs(root.jiggleVelocity) < 0.003 && !carouselList.moving) {
                root.jiggleOffset = 0.0;
                root.jiggleVelocity = 0.0;
                running = false;
            }
        }
    }

    // High-Speed Filtered Model
    ListModel { id: filteredModel }

    function stepIndex(direction) {
        if (filteredModel.count <= 0) return;
        const count = filteredModel.count;
        let next = (carouselList.currentIndex + direction) % count;
        if (next < 0) next += count;
        triggerJiggle(direction);
        carouselList.currentIndex = next;
    }

    function populateModel() {
        const f = root.currentFilter.toLowerCase();
        filteredModel.clear();
        let targetIdx = 0;
        for (let i = 0; i < root.rawWallpapers.length; ++i) {
            const it = root.rawWallpapers[i];
            const kind = (it.kind || "").toLowerCase();
            if (f !== "all" && kind !== f) continue;
            if (it.path === root.currentWallpaperPath) targetIdx = filteredModel.count;
            filteredModel.append({
                wallType: it.kind, wallPath: it.path, wallThumb: it.thumb,
                wallProxy: it.proxy, wallName: it.name, formattedSize: it.formatted_size
            });
        }
        carouselList.currentIndex = Math.min(targetIdx, Math.max(0, filteredModel.count - 1));
        infoDebounce.restart();
    }
    onCurrentFilterChanged: {
        populateModel();
        if (root.slideshowEnabled && root.slideshowType !== root.currentFilter) {
            root.slideshowType = root.currentFilter;
            root.dispatchSlideshowCmd(["set", "--type", root.currentFilter.toLowerCase()]);
        }
    }
    onSlideshowTypeChanged: {
        if (root.slideshowEnabled && root.currentFilter !== root.slideshowType) {
            root.currentFilter = root.slideshowType;
        }
    }

    function reload() {
        if (!listProcess.running) listProcess.running = true;
        if (!layoutProcess.running) layoutProcess.running = true;
    }

    Component.onCompleted: reload()
    onVisibleChanged: if (visible) { reload(); if (!root.slideshowEnabled) carouselList.forceActiveFocus(); }

    // ---------------------------------------------------------
    // Reusable Drop-Up Selector Component (Nexa UI Settings Style with QtQuick.Controls Popup)
    // ---------------------------------------------------------
    component DropUpSelector: Item {
        id: selector
        property string label: ""
        property string currentValue: ""
        property var options: []
        property int menuWidth: 168
        property bool alignLeft: false
        signal selected(string value)

        implicitWidth: selRow.implicitWidth + 24
        height: 40

        // True Qt Quick Controls Popup (Pops upward on Overlay.overlay without clipping!)
        Popup {
            id: dropPopup
            y: -implicitHeight - 8
            x: (selector.width - width) / 2
            width: selector.menuWidth
            padding: 6
            closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent

            background: Rectangle {
                radius: NexaUI.NexaTokens.radiusSm
                color: NexaUI.NexaColors.surfaceContainer
                border.width: NexaUI.NexaTokens.borderThin
                border.color: NexaUI.NexaColors.border
            }

            contentItem: Column {
                spacing: 2
                Repeater {
                    model: selector.options
                    delegate: Rectangle {
                        readonly property bool active: selector.currentValue === modelData
                        width: parent.width; height: 34; radius: NexaUI.NexaTokens.radiusSm
                        color: active ? NexaUI.NexaColors.alpha(NexaUI.NexaColors.primary, 0.18) : (itemM.containsMouse ? NexaUI.NexaColors.surfaceContainerHigh : "transparent")
                        border.width: active ? 1 : 0
                        border.color: NexaUI.NexaColors.primary

                        Text {
                            anchors {
                                left: selector.alignLeft ? parent.left : undefined
                                leftMargin: selector.alignLeft ? 12 : 0
                                centerIn: selector.alignLeft ? undefined : parent
                                verticalCenter: selector.alignLeft ? parent.verticalCenter : undefined
                            }
                            text: modelData
                            color: active ? NexaUI.NexaColors.primary : NexaUI.NexaColors.text
                            font.family: NexaUI.NexaTypography.familyBody; font.pixelSize: NexaUI.NexaTypography.sizeSm; font.weight: active ? NexaUI.NexaTypography.weightSemiBold : NexaUI.NexaTypography.weightNormal
                        }
                        MouseArea {
                            id: itemM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                selector.selected(modelData);
                                dropPopup.close();
                            }
                        }
                    }
                }
            }
        }

        // Trigger Button
        Rectangle {
            anchors.fill: parent; radius: NexaUI.NexaTokens.radiusSm
            color: dropPopup.visible ? NexaUI.NexaColors.alpha(NexaUI.NexaColors.primary, 0.18) : (btnM.containsMouse ? NexaUI.NexaColors.surfaceContainerHigh : "transparent")
            Row {
                id: selRow; anchors.centerIn: parent; spacing: 6
                Text { text: selector.label; color: NexaUI.NexaColors.mutedText; font.family: NexaUI.NexaTypography.familyBody; font.pixelSize: NexaUI.NexaTypography.sizeSm }
                Text { text: selector.currentValue; color: dropPopup.visible ? NexaUI.NexaColors.primary : NexaUI.NexaColors.text; font.family: NexaUI.NexaTypography.familyBody; font.pixelSize: NexaUI.NexaTypography.sizeSm; font.weight: NexaUI.NexaTypography.weightSemiBold }
                Text { text: dropPopup.visible ? "▾" : "▴"; color: NexaUI.NexaColors.mutedText; font.family: NexaUI.NexaTypography.familyBody; font.pixelSize: NexaUI.NexaTypography.sizeXs; anchors.verticalCenter: parent.verticalCenter }
            }
            MouseArea {
                id: btnM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (dropPopup.visible) dropPopup.close();
                    else dropPopup.open();
                }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.45)

        MouseArea { anchors.fill: parent; onClicked: root.closeWallpaper() }

        // VIEW 1: Slideshow Gallery Grid (Screenshot 2)
        Loader {
            id: slideshowLoader
            anchors { fill: parent; margins: 36; bottomMargin: 90 }
            active: root.slideshowEnabled; visible: root.slideshowEnabled
            sourceComponent: Component {
                SlideshowWallpaperView {
                    slideshowFolder: root.slideshowFolder
                    slideshowType: root.currentFilter || root.slideshowType
                    slideshowTarget: root.slideshowTarget
                    lastWallpaper: root.slideshowLastWallpaper || root.currentWallpaperPath
                    onApplyWallpaper: path => root.applySelected(path)
                    onCloseRequested: () => root.closeWallpaper()
                }
            }
        }

        // VIEW 2: 3D Slanted Coverflow Carousel (Screenshot 1 & 2)
        ListView {
            id: carouselList
            anchors.fill: parent
            visible: !root.slideshowEnabled
            focus: true
            orientation: ListView.Horizontal
            spacing: 0
            model: filteredModel
            cacheBuffer: 500
            keyNavigationWraps: true
            highlightRangeMode: ListView.StrictlyEnforceRange
            preferredHighlightBegin: (width / 2) - ((root.selectedWidth + root.itemSpacing) / 2)
            preferredHighlightEnd: (width / 2) + ((root.selectedWidth + root.itemSpacing) / 2)
            highlightMoveVelocity: -1
            highlightMoveDuration: 320
            flickDeceleration: 1800
            maximumFlickVelocity: 2500

            header: Item { width: Math.max(0, (carouselList.width / 2) - (root.selectedWidth / 2)) }
            footer: Item { width: Math.max(0, (carouselList.width / 2) - (root.selectedWidth / 2)) }

            onCurrentIndexChanged: infoDebounce.restart()

            delegate: Item {
                id: cardRoot
                readonly property bool selected: ListView.isCurrentItem
                readonly property bool isImage: (model.wallType || "").toLowerCase() === "image"
                readonly property bool isVideo: (model.wallType || "").toLowerCase() === "video"
                readonly property bool isGif: (model.wallType || "").toLowerCase() === "gif"
                readonly property int distFromSelected: Math.abs(index - carouselList.currentIndex)
                readonly property real cardJiggle: root.jiggleOffset / (1.0 + (distFromSelected * 0.4))

                width: (selected ? root.selectedWidth : root.sideWidth) + root.itemSpacing
                height: carouselList.height
                z: selected ? 50 : (20 - Math.min(15, Math.abs(carouselList.currentIndex - index)))
                opacity: selected ? 1.0 : (cardMouse.containsMouse ? 0.90 : 0.72)

                // Motion & Physics Integration with NexaMotion
                Behavior on width {
                    SpringAnimation {
                        spring: NexaUI.NexaMotion.effectiveSpring
                        damping: NexaUI.NexaMotion.effectiveDamping
                        mass: NexaUI.NexaMotion.effectiveMass
                        epsilon: 0.25
                    }
                }
                Behavior on opacity { NumberAnimation { duration: NexaUI.NexaMotion.durationFast; easing.type: NexaUI.NexaMotion.decelerateEasing } }

                Item {
                    id: skewContainer
                    anchors.centerIn: parent
                    width: Math.max(0, parent.width - root.itemSpacing)
                    height: cardRoot.selected ? root.selectedHeight : root.cardHeight

                    scale: cardMouse.pressed ? 0.96 : (cardMouse.containsMouse ? 1.02 : 1.0)
                    Behavior on scale { NumberAnimation { duration: NexaUI.NexaMotion.durationFast; easing.type: NexaUI.NexaMotion.emphasizedEasing; easing.overshoot: 1.25 } }
                    Behavior on height {
                        SpringAnimation {
                            spring: NexaUI.NexaMotion.effectiveSpring
                            damping: NexaUI.NexaMotion.effectiveDamping
                            mass: NexaUI.NexaMotion.effectiveMass
                            epsilon: 0.25
                        }
                    }

                    transform: Matrix4x4 {
                        property real skew: root.skewFactor + (cardRoot.cardJiggle * 0.04)
                        matrix: Qt.matrix4x4(1, skew, 0, 0,  0, 1, 0, 0,  0, 0, 1, 0,  0, 0, 0, 1)
                    }

                    // Ambient Light Halo Aura (Pre-scaled 48x36 texture for silky smooth ambient glow)
                    Item {
                        id: auraLayer
                        anchors.centerIn: parent
                        width: parent.width + 100
                        height: parent.height + 100
                        z: -1
                        opacity: cardRoot.selected ? 0.70 : (cardMouse.containsMouse ? 0.28 : 0.0)
                        visible: opacity > 0.01
                        scale: cardRoot.selected ? 1.03 : 0.98

                        Behavior on opacity { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
                        Behavior on scale { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }

                        Item {
                            id: auraSourceContainer
                            anchors.fill: parent
                            visible: false

                            Image {
                                id: auraImg
                                anchors.centerIn: parent
                                width: skewContainer.width
                                height: skewContainer.height
                                source: root.fileUrl(model.wallThumb && model.wallThumb.length > 0 ? model.wallThumb : model.wallPath)
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: true
                                sourceSize.width: 48
                                sourceSize.height: 36
                            }
                        }

                        MultiEffect {
                            anchors.fill: parent
                            source: auraSourceContainer
                            blurEnabled: auraLayer.visible
                            blur: 1.0
                            blurMax: 36
                            saturation: 0.65
                            brightness: 0.12
                        }
                    }

                    // Sharp Parallelogram Card Frame
                    Rectangle {
                        anchors.fill: parent
                        radius: 0
                        color: NexaUI.NexaColors.surfaceContainerLow
                        clip: true
                        border.width: cardRoot.selected ? 2 : 1
                        border.color: cardRoot.selected ? NexaUI.NexaColors.primary : NexaUI.NexaColors.alpha(NexaUI.NexaColors.onSurface, 0.16)

                        // 1. Static Image / Thumbnail (Always present behind video so NO white screen!)
                        Image {
                            anchors.centerIn: parent
                            anchors.horizontalCenterOffset: skewContainer.height * root.skewFactor * (root.layoutMetrics.media_center_offset || 0.32)
                            width: skewContainer.width + (skewContainer.height * Math.abs(root.skewFactor)) + 100
                            height: skewContainer.height + 20
                            fillMode: Image.PreserveAspectCrop; asynchronous: true; cache: true
                            sourceSize.width: 1280
                            sourceSize.height: 720
                            source: root.fileUrl(model.wallThumb && model.wallThumb.length > 0 ? model.wallThumb : model.wallPath)
                            visible: !cardRoot.isGif || !cardRoot.selected
                            transform: Matrix4x4 {
                                property real skew: -root.skewFactor
                                matrix: Qt.matrix4x4(1, skew, 0, 0,  0, 1, 0, 0,  0, 0, 1, 0,  0, 0, 0, 1)
                            }
                        }

                        // 2. Animated GIF (Plays on selected center card)
                        AnimatedImage {
                            anchors.centerIn: parent
                            anchors.horizontalCenterOffset: skewContainer.height * root.skewFactor * (root.layoutMetrics.media_center_offset || 0.32)
                            width: skewContainer.width + (skewContainer.height * Math.abs(root.skewFactor)) + 100
                            height: skewContainer.height + 20
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true; cache: true
                            source: (cardRoot.isGif && cardRoot.selected) ? root.fileUrl(model.wallPath) : ""
                            playing: cardRoot.selected && cardRoot.isGif
                            visible: cardRoot.isGif && cardRoot.selected
                            transform: Matrix4x4 {
                                property real skew: -root.skewFactor
                                matrix: Qt.matrix4x4(1, skew, 0, 0,  0, 1, 0, 0,  0, 0, 1, 0,  0, 0, 0, 1)
                            }
                        }

                        // 3. Video Player (On-demand Loader when selected)
                        Loader {
                            id: videoPlayerLoader
                            anchors.centerIn: parent
                            anchors.horizontalCenterOffset: skewContainer.height * root.skewFactor * (root.layoutMetrics.media_center_offset || 0.32)
                            width: skewContainer.width + (skewContainer.height * Math.abs(root.skewFactor)) + 100
                            height: skewContainer.height + 20
                            active: cardRoot.isVideo && cardRoot.selected && root.visible
                            visible: active
                            transform: Matrix4x4 {
                                property real skew: -root.skewFactor
                                matrix: Qt.matrix4x4(1, skew, 0, 0,  0, 1, 0, 0,  0, 0, 1, 0,  0, 0, 0, 1)
                            }
                            sourceComponent: Component {
                                Item {
                                    anchors.fill: parent

                                    MediaPlayer {
                                        id: previewPlayer
                                        source: root.fileUrl(model.wallProxy && model.wallProxy.length > 0 ? model.wallProxy : model.wallPath)
                                        loops: MediaPlayer.Infinite
                                        audioOutput: AudioOutput { muted: true }
                                        videoOutput: previewOutput
                                        autoPlay: true
                                        Component.onCompleted: play()
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

                        // Bottom-Left ID / Title Chip
                        Rectangle {
                            visible: cardRoot.selected; anchors { left: parent.left; bottom: parent.bottom; margins: NexaUI.NexaTokens.spacingMd }
                            height: 26; radius: NexaUI.NexaTokens.radiusSm; color: Qt.rgba(0, 0, 0, 0.75); implicitWidth: nameRow.implicitWidth + 14
                            Row {
                                id: nameRow; anchors.centerIn: parent; spacing: NexaUI.NexaTokens.spacingXs
                                Text { text: "󰋩"; color: NexaUI.NexaColors.primary; font.family: NexaUI.NexaTypography.familyIcon; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
                                Text { text: model.wallName || ""; color: "#ffffff"; font.family: NexaUI.NexaTypography.familyBody; font.pixelSize: 11; font.weight: NexaUI.NexaTypography.weightSemiBold; elide: Text.ElideRight; anchors.verticalCenter: parent.verticalCenter }
                            }
                        }

                        // Bottom-Right Kind Badge (GIF / VIDEO)
                        Rectangle {
                            visible: cardRoot.selected && model.wallType !== "image"; anchors { right: parent.right; bottom: parent.bottom; margins: NexaUI.NexaTokens.spacingMd }
                            height: 26; radius: NexaUI.NexaTokens.radiusSm; color: Qt.rgba(0, 0, 0, 0.75); implicitWidth: typeTxt.implicitWidth + 14
                            Text { id: typeTxt; anchors.centerIn: parent; text: (model.wallType || "").toUpperCase(); color: NexaUI.NexaColors.primary; font.family: NexaUI.NexaTypography.familyMono; font.pixelSize: 10; font.weight: NexaUI.NexaTypography.weightBold }
                        }

                        MouseArea {
                            id: cardMouse; anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                const dir = index > carouselList.currentIndex ? 1 : (index < carouselList.currentIndex ? -1 : 0);
                                if (dir !== 0) root.triggerJiggle(dir);
                                carouselList.currentIndex = index;
                                root.applySelected();
                            }
                            onDoubleClicked: { carouselList.currentIndex = index; root.applySelected(); }
                        }
                    }

                    // Slanted Info Plate directly below selected card
                    Item {
                        id: infoPlate
                        anchors { top: parent.bottom; topMargin: 12; left: parent.left; right: parent.right }
                        height: 44; z: 20
                        opacity: cardRoot.selected ? 1.0 : 0.0
                        visible: opacity > 0.01

                        Behavior on opacity { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

                        Rectangle {
                            anchors.fill: parent; radius: NexaUI.NexaTokens.radiusSm
                            color: NexaUI.NexaColors.surfaceContainer
                            border.width: NexaUI.NexaTokens.borderThin; border.color: NexaUI.NexaColors.border
                        }

                        // Counter-skewed upright content
                        RowLayout {
                            anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16
                            transform: Matrix4x4 {
                                property real skew: -(root.skewFactor + (cardRoot.cardJiggle * 0.04))
                                matrix: Qt.matrix4x4(1, skew, 0, 0,  0, 1, 0, 0,  0, 0, 1, 0,  0, 0, 0, 1)
                            }

                            Text {
                                text: {
                                    if (root.currentSelectedInfo && root.currentSelectedInfo.format) return root.currentSelectedInfo.format + " • " + (root.currentSelectedInfo.size || model.formattedSize || "");
                                    return (model.wallType || "").toUpperCase() + (model.formattedSize ? " • " + model.formattedSize : "");
                                }
                                color: NexaUI.NexaColors.mutedText; font.family: NexaUI.NexaTypography.familyMono; font.pixelSize: 11; font.weight: NexaUI.NexaTypography.weightMedium
                            }

                            Item { Layout.fillWidth: true }

                            Row {
                                spacing: 5
                                Repeater {
                                    model: [{ label: "PRI", key: "primary" }, { label: "SEC", key: "secondary" }, { label: "TER", key: "tertiary" }, { label: "CON", key: "container" }, { label: "SUR", key: "surface" }]
                                    delegate: Rectangle {
                                        readonly property string hex: (root.currentSelectedInfo && root.currentSelectedInfo.palette) ? (root.currentSelectedInfo.palette[modelData.key] || "#------") : "#------"
                                        height: 22; radius: NexaUI.NexaTokens.radiusPill; implicitWidth: swatchRow.implicitWidth + 10; color: NexaUI.NexaColors.surfaceContainerLow; border.width: NexaUI.NexaTokens.borderThin; border.color: NexaUI.NexaColors.outlineVariant
                                        Row {
                                            id: swatchRow; anchors.centerIn: parent; spacing: 4
                                            Rectangle { width: 8; height: 8; radius: NexaUI.NexaTokens.radiusPill; color: hex !== "#------" ? hex : NexaUI.NexaColors.surfaceContainerHighest; anchors.verticalCenter: parent.verticalCenter }
                                            Text { text: modelData.label + " " + hex; color: NexaUI.NexaColors.text; font.family: NexaUI.NexaTypography.familyMono; font.pixelSize: 9; anchors.verticalCenter: parent.verticalCenter }
                                        }
                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (hex !== "#------") Quickshell.execDetached(["wl-copy", hex]) }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Left) { root.stepIndex(-1); event.accepted = true; }
                else if (event.key === Qt.Key_Right) { root.stepIndex(1); event.accepted = true; }
                else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { root.applySelected(); event.accepted = true; }
                else if (event.key === Qt.Key_Escape) { root.closeWallpaper(); event.accepted = true; }
            }

            WheelHandler {
                orientation: Qt.Vertical; acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                property real acc: 0
                onWheel: event => {
                    let dy = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x;
                    acc += dy;
                    if (Math.abs(acc) >= 45) {
                        if (acc < 0) root.stepIndex(1);
                        else root.stepIndex(-1);
                        acc = 0;
                    }
                }
            }
        }

        // FLOATING BOTTOM CONTROLS ROW (Mapped 100% to Nexa UI Theme & Settings)
        Row {
            id: bottomControlsRow
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 18 }
            spacing: 14
            z: 500

            // 1. LEFT CAPSULE: FILTER BAR & COVERFLOW APPLY TARGET
            Rectangle {
                id: filterBar
                height: 48
                radius: NexaUI.NexaTokens.radiusPill
                color: NexaUI.NexaColors.surfaceContainer
                border.width: NexaUI.NexaTokens.borderThin
                border.color: NexaUI.NexaColors.border
                implicitWidth: filterRow.implicitWidth + 24

                // Apple Tactile 4-stop Depth Micro-Gradient
                Rectangle {
                    anchors.fill: parent
                    radius: filterBar.radius
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

                // Apple Top Chamfer Specular Highlight
                Rectangle {
                    anchors.top: parent.top
                    anchors.topMargin: 1
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.max(0, parent.width - filterBar.radius * 1.6)
                    height: 1
                    visible: NexaUI.NexaOptics.specularHighlight && NexaUI.NexaOptics.specularIntensity > 0.01
                    opacity: Math.min(1.0, NexaUI.NexaOptics.specularIntensity / 0.28)
                    z: 1
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.30) }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                }

                // Apple Bottom Chamfer Ambient Shadow Line
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 1
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.max(0, parent.width - filterBar.radius * 1.6)
                    height: 1
                    visible: NexaUI.NexaOptics.contactShadow && NexaUI.NexaOptics.shadowBlurFactor > 0.01
                    opacity: Math.min(1.0, NexaUI.NexaOptics.shadowBlurFactor)
                    z: 1
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 0.5; color: Qt.rgba(0, 0, 0, 0.45) }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                }

                Row {
                    id: filterRow
                    anchors.centerIn: parent; spacing: 8

                    Repeater {
                        model: ["All", "Image", "GIF", "Video"]
                        delegate: NexaUI.NexaButton {
                            required property string modelData
                            readonly property bool active: root.currentFilter === modelData
                            variant: "pill"
                            checkable: true
                            checked: active
                            customHeight: 34
                            text: modelData
                            onClicked: {
                                root.currentFilter = modelData
                            }
                        }
                    }

                    // DIVIDER (Visible in Coverflow mode)
                    Rectangle {
                        visible: !root.slideshowEnabled
                        width: 1; height: 20
                        color: NexaUI.NexaColors.border
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    // APPLY TARGET SELECTOR (Visible in Coverflow mode)
                    DropUpSelector {
                        visible: !root.slideshowEnabled
                        label: "Apply to:"
                        currentValue: root.applyTarget
                        options: ["Background", "Lock Screen", "Both"]
                        menuWidth: 168
                        alignLeft: true
                        onSelected: v => {
                            root.applyTarget = v
                            root.slideshowTarget = v
                            root.dispatchSlideshowCmd(["set", "--target", v])
                        }
                    }
                }
            }

            // 2. RIGHT CAPSULE: SLIDESHOW CONTROLS & STATUS
            Rectangle {
                id: slideshowBar
                height: 48
                radius: NexaUI.NexaTokens.radiusPill
                color: NexaUI.NexaColors.surfaceContainer
                border.width: NexaUI.NexaTokens.borderThin
                border.color: NexaUI.NexaColors.border
                implicitWidth: slideshowRow.implicitWidth + 24

                // Apple Tactile 4-stop Depth Micro-Gradient
                Rectangle {
                    anchors.fill: parent
                    radius: slideshowBar.radius
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

                // Apple Top Chamfer Specular Highlight
                Rectangle {
                    anchors.top: parent.top
                    anchors.topMargin: 1
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.max(0, parent.width - slideshowBar.radius * 1.6)
                    height: 1
                    visible: NexaUI.NexaOptics.specularHighlight && NexaUI.NexaOptics.specularIntensity > 0.01
                    opacity: Math.min(1.0, NexaUI.NexaOptics.specularIntensity / 0.28)
                    z: 1
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.30) }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                }

                // Apple Bottom Chamfer Ambient Shadow Line
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 1
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.max(0, parent.width - slideshowBar.radius * 1.6)
                    height: 1
                    visible: NexaUI.NexaOptics.contactShadow && NexaUI.NexaOptics.shadowBlurFactor > 0.01
                    opacity: Math.min(1.0, NexaUI.NexaOptics.shadowBlurFactor)
                    z: 1
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 0.5; color: Qt.rgba(0, 0, 0, 0.45) }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                }

                Behavior on implicitWidth {
                    NumberAnimation { duration: NexaUI.NexaMotion.durationFast; easing.type: NexaUI.NexaMotion.emphasizedEasing }
                }

                Row {
                    id: slideshowRow
                    anchors.centerIn: parent; spacing: 8

                    // When Slideshow is OFF (Subtle status pill)
                    Rectangle {
                        visible: !root.slideshowEnabled
                        height: 34
                        radius: NexaUI.NexaTokens.radiusPill
                        implicitWidth: slideOffRow.implicitWidth + 20
                        color: slideOffMouse.containsMouse ? NexaUI.NexaColors.alpha(NexaUI.NexaColors.onSurface, 0.08) : "transparent"

                        Row {
                            id: slideOffRow
                            anchors.centerIn: parent
                            spacing: NexaUI.NexaTokens.spacingSm

                            Rectangle {
                                width: 8; height: 8; radius: NexaUI.NexaTokens.radiusPill
                                color: NexaUI.NexaColors.mutedText
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: "Slideshow: OFF"
                                color: NexaUI.NexaColors.mutedText
                                font.family: NexaUI.NexaTypography.familyBody
                                font.pixelSize: NexaUI.NexaTypography.sizeSm
                                font.weight: NexaUI.NexaTypography.weightNormal
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: slideOffMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.toggleSlideshow()
                        }
                    }

                    // When Slideshow is ON (Screenshot 2: Timer, Pause/Resume, Next, Type, Apply, Slideshow: ON)
                    DropUpSelector {
                        visible: root.slideshowEnabled
                        label: "Timer:"
                        currentValue: root.slideshowInterval
                        options: ["1m", "5m", "10m", "15m", "30m", "1h"]
                        menuWidth: 108
                        onSelected: v => {
                            root.slideshowInterval = v
                            root.dispatchSlideshowCmd(["set", "--interval", v])
                        }
                    }

                    // Pause / Resume Button
                    NexaUI.NexaButton {
                        visible: root.slideshowEnabled
                        implicitWidth: 104
                        implicitHeight: 40
                        variant: root.slideshowPaused ? "filled" : "ghost"
                        icon: root.slideshowPaused ? "▶" : "⏸"
                        text: root.slideshowPaused ? "Resume" : "Pause"
                        onClicked: {
                            root.slideshowPaused = !root.slideshowPaused
                            root.dispatchSlideshowCmd([root.slideshowPaused ? "pause" : "resume"])
                        }
                    }

                    // Next Button
                    NexaUI.NexaButton {
                        visible: root.slideshowEnabled
                        implicitWidth: 88
                        implicitHeight: 40
                        variant: "ghost"
                        icon: "⏭"
                        text: "Next"
                        onClicked: {
                            if (!nextProcess.running) nextProcess.running = true;
                        }
                    }

                    // Type Selector
                    DropUpSelector {
                        visible: root.slideshowEnabled
                        label: "Type:"
                        currentValue: root.slideshowType
                        options: ["All", "Image", "GIF", "Video"]
                        menuWidth: 120
                        onSelected: v => {
                            root.slideshowType = v
                            root.dispatchSlideshowCmd(["set", "--type", v.toLowerCase()])
                        }
                    }

                    // Divider in Slideshow
                    Rectangle {
                        visible: root.slideshowEnabled
                        width: 1; height: 24; color: NexaUI.NexaColors.border
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    // Apply Target Selector (In Slideshow mode)
                    DropUpSelector {
                        visible: root.slideshowEnabled
                        label: "Apply to:"
                        currentValue: root.applyTarget
                        options: ["Background", "Lock Screen", "Both"]
                        menuWidth: 168
                        alignLeft: true
                        onSelected: v => {
                            root.applyTarget = v
                            root.slideshowTarget = v
                            root.dispatchSlideshowCmd(["set", "--target", v])
                        }
                    }

                    // Divider in Slideshow
                    Rectangle {
                        visible: root.slideshowEnabled
                        width: 1; height: 24; color: NexaUI.NexaColors.border
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    // Slideshow: ON Pill with live status dot
                    Rectangle {
                        visible: root.slideshowEnabled
                        height: 40
                        radius: NexaUI.NexaTokens.radiusSm
                        implicitWidth: slideOnRow.implicitWidth + 24
                        color: NexaUI.NexaColors.alpha(NexaUI.NexaColors.primary, 0.15)
                        border.width: NexaUI.NexaTokens.borderThin
                        border.color: NexaUI.NexaColors.primary

                        Row {
                            id: slideOnRow
                            anchors.centerIn: parent
                            spacing: NexaUI.NexaTokens.spacingSm

                            Rectangle {
                                width: 8; height: 8; radius: NexaUI.NexaTokens.radiusPill
                                color: root.slideshowPaused ? NexaUI.NexaColors.warning : NexaUI.NexaColors.success
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: "Slideshow: ON"
                                color: NexaUI.NexaColors.primary
                                font.family: NexaUI.NexaTypography.familyBody
                                font.pixelSize: NexaUI.NexaTypography.sizeSm
                                font.weight: NexaUI.NexaTypography.weightSemiBold
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.toggleSlideshow()
                        }
                    }
                }
            }
        }
    }
}
