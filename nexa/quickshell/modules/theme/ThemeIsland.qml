import QtQuick
import QtQuick.Layouts

import Quickshell
import Quickshell.Io

import "../../theme" as Nexa
import "../../theme/components" as NexaUI


Item {
    id: root

    // ============================================================
    // STATE
    // ============================================================

    property string selectedStyle: ""
    property string selectedPreset: ""
    property string selectedMode: "dark"
    property string wallpaperSource: ""

    // Local preview / staging (0ms lag, zero auto-apply until Apply is clicked)
    property string stagedStyle: ""
    property string stagedPreset: ""
    property string stagedMode: "dark"

    property bool warmthEnabled: false
    property bool applying: false
    property bool presetsLoaded: false

    property var presets: []
    property var categories: ["All"]
    property string selectedCategory: "All"
    property string searchQuery: ""

    // Refresh status whenever Theme island becomes visible
    onVisibleChanged: {
        if (visible) {
            statusProcess.running = true
        }
    }

    // Backward compatibility for IslandContent.qml
    readonly property bool themePopupOpen: false

    readonly property string themeScript:
        "$HOME/.config/nexa/scripts/theme.sh"

    readonly property string nexad:
        "$HOME/.config/nexa/rust/target/release/nexad"

    // ============================================================
    // DYNAMIC DERIVED STAGED COLORS
    // ============================================================

    readonly property color stagedPrimary: {
        if (root.stagedStyle === "preset")
            return root.colorForPreset(root.stagedPreset, 0, root.stagedMode)
        return Nexa.Theme.primary
    }

    readonly property color stagedSecondary: {
        if (root.stagedStyle === "preset")
            return root.colorForPreset(root.stagedPreset, 1, root.stagedMode)
        return Nexa.Theme.secondary
    }

    readonly property color stagedTertiary: {
        if (root.stagedStyle === "preset")
            return root.colorForPreset(root.stagedPreset, 2, root.stagedMode)
        return Nexa.Theme.tertiary
    }

    readonly property string stagedPresetName: {
        if (root.stagedStyle === "wallpaperFull")
            return "Full Wallpaper"
        if (root.stagedStyle === "wallpaperAccents")
            return "Wallpaper Accents"
        const p = root.presetById(root.stagedPreset)
        return p ? p.name : (root.stagedPreset || "Select Preset")
    }

    readonly property string stagedPresetCategory: {
        const p = root.presetById(root.stagedPreset)
        return p ? p.category : ""
    }

    readonly property bool isCurrentThemeActive: {
        if (!root.selectedStyle)
            return true
        if (root.stagedStyle !== root.selectedStyle)
            return false
        if (root.stagedMode !== root.selectedMode)
            return false
        if (root.stagedStyle === "preset") {
            return root.stagedPreset.length > 0
                && root.stagedPreset === root.selectedPreset
        }
        return true
    }

    // Filtered presets based on search query and selected category
    readonly property var filteredPresets: {
        if (!root.presets || root.presets.length === 0)
            return []

        const q = root.searchQuery.trim().toLowerCase()
        const cat = root.selectedCategory

        const result = []
        for (let i = 0; i < root.presets.length; ++i) {
            const p = root.presets[i]
            if (cat !== "All" && p.category !== cat)
                continue

            if (q.length > 0) {
                const matchName = p.name && p.name.toLowerCase().indexOf(q) >= 0
                const matchCat = p.category && p.category.toLowerCase().indexOf(q) >= 0
                const matchId = p.id && p.id.toLowerCase().indexOf(q) >= 0
                if (!matchName && !matchCat && !matchId)
                    continue
            }

            result.push(p)
        }
        return result
    }

    // ============================================================
    // HELPERS
    // ============================================================

    function presetById(id) {
        if (!id)
            return null
        for (let i = 0; i < root.presets.length; ++i) {
            if (root.presets[i].id === id)
                return root.presets[i]
        }
        return null
    }

    function colorForPreset(id, slot, mode) {
        const preset = root.presetById(id)
        const targetMode = mode || root.selectedMode

        if (preset && preset.previews) {
            let colors = preset.previews[targetMode]

            if (!colors || colors.length < 3)
                colors = preset.previews["default"]

            if (!colors || colors.length < 3) {
                const keys = Object.keys(preset.previews)
                if (keys.length > 0)
                    colors = preset.previews[keys[0]]
            }

            if (colors && colors.length > slot)
                return colors[slot]
        }

        return slot === 0
            ? Nexa.Theme.primary
            : slot === 1
                ? Nexa.Theme.secondary
                : Nexa.Theme.tertiary
    }

    function hexForPreset(id, slot, mode) {
        const col = root.colorForPreset(id, slot, mode)
        return String(col).toUpperCase()
    }

    function hexForStaged(slot) {
        if (root.stagedStyle === "preset")
            return root.hexForPreset(root.stagedPreset, slot, root.stagedMode)
        const col = slot === 0 ? Nexa.Theme.primary : slot === 1 ? Nexa.Theme.secondary : Nexa.Theme.tertiary
        return String(col).toUpperCase()
    }

    function syncStagedToActive() {
        root.stagedStyle = root.selectedStyle || "preset"
        root.stagedPreset = root.selectedPreset || (root.presets.length > 0 ? root.presets[0].id : "")
        root.stagedMode = root.selectedMode || "dark"
    }

    function rebuildCategories() {
        const seen = {}
        const list = ["All"]
        for (let i = 0; i < root.presets.length; ++i) {
            const cat = root.presets[i].category
            if (cat && !seen[cat]) {
                seen[cat] = true
                list.push(cat)
            }
        }
        root.categories = list
    }

    // ============================================================
    // USER ACTIONS
    // ============================================================

    // Instant local preview stage (Zero lag, no process spawned)
    function stagePreset(presetId) {
        if (!presetId)
            return
        root.stagedPreset = presetId
    }

    function stageStyle(style) {
        if (!style)
            return
        root.stagedStyle = style
    }

    function stageMode(mode) {
        if (!mode)
            return
        root.stagedMode = mode
    }

    // Apply staged configuration when user clicks the Apply button
    function applyCurrentConfiguration() {
        if (root.applying || root.isCurrentThemeActive)
            return

        root.applying = true

        let cmd = ""
        if (root.stagedStyle === "preset") {
            cmd = root.themeScript + " apply-preset '" + root.stagedPreset + "' " + root.stagedMode
        } else {
            cmd = root.themeScript + " mode " + root.stagedMode + " && " + root.themeScript + " apply-style " + root.stagedStyle
        }

        applyProcess.command = [
            "sh",
            "-c",
            cmd
        ]
        applyProcess.running = true
    }

    // Toggle screen temperature
    function setWarmth(enabled) {
        if (root.warmthEnabled === enabled || root.applying)
            return

        root.warmthEnabled = enabled

        if (enabled) {
            warmthProcess.command = [
                "sh",
                "-c",
                root.nexad + " screenTemp mode wallpaper && " + root.nexad + " screenTemp enable"
            ]
        } else {
            warmthProcess.command = [
                "sh",
                "-c",
                root.nexad + " screenTemp disable"
            ]
        }
        warmthProcess.running = true
    }

    // ============================================================
    // PROCESSES
    // ============================================================

    Process {
        id: statusProcess

        command: [
            "sh",
            "-c",
            root.themeScript + " status"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n")
                let loadedStyle = ""
                let loadedPreset = ""
                let loadedMode = ""
                let loadedWallpaper = ""

                for (let i = 0; i < lines.length; ++i) {
                    const line = lines[i].trim()
                    if (line.startsWith("Style")) {
                        const sep = line.indexOf(":")
                        if (sep >= 0)
                            loadedStyle = line.substring(sep + 1).trim()
                    }
                    if (line.startsWith("Preset")) {
                        const sep = line.indexOf(":")
                        if (sep >= 0)
                            loadedPreset = line.substring(sep + 1).trim()
                    }
                    if (line.startsWith("Mode")) {
                        const sep = line.indexOf(":")
                        if (sep >= 0)
                            loadedMode = line.substring(sep + 1).trim()
                    }
                    if (line.startsWith("Wallpaper")) {
                        const sep = line.indexOf(":")
                        if (sep >= 0)
                            loadedWallpaper = line.substring(sep + 1).trim()
                    }
                }

                if (loadedStyle) root.selectedStyle = loadedStyle
                if (loadedPreset) root.selectedPreset = loadedPreset
                if (loadedMode) root.selectedMode = loadedMode
                if (loadedWallpaper) root.wallpaperSource = loadedWallpaper

                root.syncStagedToActive()
            }
        }
    }

    Process {
        id: presetCatalogProcess

        command: [
            "sh",
            "-c",
            root.themeScript + " presets-json"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                const output = text.trim()
                if (output.length === 0) {
                    root.presets = []
                    root.presetsLoaded = true
                    statusProcess.running = true
                    return
                }

                try {
                    const catalog = JSON.parse(output)
                    root.presets = Array.isArray(catalog) ? catalog : []
                    root.rebuildCategories()
                    root.presetsLoaded = true
                } catch (e) {
                    console.warn("ThemeIsland: failed to parse presets catalog:", e)
                    root.presets = []
                    root.presetsLoaded = true
                }

                statusProcess.running = true
            }
        }
    }

    Process {
        id: warmthStatusProcess

        command: [
            "sh",
            "-c",
            root.nexad + " screenTemp info"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                const output = text.trim()
                if (output.length === 0)
                    return
                try {
                    const state = JSON.parse(output)
                    root.warmthEnabled = state.enabled === true && state.mode === "wallpaper"
                } catch (e) {}
            }
        }
    }

    Process {
        id: applyProcess

        property bool wasRunning: false

        onRunningChanged: {
            if (running) {
                root.applying = true
                wasRunning = true
                return
            }

            if (wasRunning) {
                root.applying = false
                wasRunning = false
                statusProcess.running = true
            }
        }
    }

    Process {
        id: warmthProcess

        property bool wasRunning: false

        onRunningChanged: {
            if (running) {
                root.applying = true
                wasRunning = true
                return
            }

            if (wasRunning) {
                root.applying = false
                wasRunning = false
                warmthStatusProcess.running = true
            }
        }
    }

    Component.onCompleted: {
        presetCatalogProcess.running = true
        warmthStatusProcess.running = true
    }

    // ============================================================
    // UI LAYOUT
    // ============================================================

    ColumnLayout {
        anchors.fill: parent
        spacing: Nexa.Theme.spacingSm

        // --------------------------------------------------------
        // TOP CONTROL HEADER (Style, Warmth, Mode)
        // --------------------------------------------------------
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            spacing: Nexa.Theme.spacingSm

            // Style Segmented Switch (Presets / Wallpaper Accents / Full)
            Rectangle {
                Layout.preferredHeight: 32
                Layout.preferredWidth: 310
                radius: Nexa.Theme.radiusSm
                color: Nexa.Theme.cardBackground
                border.width: Nexa.Theme.borderThin
                border.color: Nexa.Theme.border

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 2
                    spacing: 2

                    Repeater {
                        model: [
                            { id: "preset", label: "Presets", icon: "󰏘" },
                            { id: "wallpaperAccents", label: "Accents", icon: "󰸉" },
                            { id: "wallpaperFull", label: "Full Wall", icon: "󰸉" }
                        ]

                        Rectangle {
                            id: stylePill
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: Nexa.Theme.radiusXs

                            readonly property bool isSelected:
                                root.stagedStyle === modelData.id

                            color: isSelected
                                ? Nexa.Theme.primary
                                : styleMouse.containsMouse
                                    ? Nexa.Theme.hover
                                    : "transparent"

                            Behavior on color {
                                ColorAnimation { duration: Nexa.Theme.animationFast }
                            }

                            Row {
                                anchors.centerIn: parent
                                spacing: 4

                                Text {
                                    text: stylePill.modelData.icon
                                    font.family: Nexa.Theme.iconFontFamily
                                    font.pixelSize: Nexa.Theme.iconSm
                                    color: stylePill.isSelected ? Nexa.Theme.onPrimary : Nexa.Theme.mutedText
                                }

                                Text {
                                    text: stylePill.modelData.label
                                    font.family: Nexa.Theme.fontFamily
                                    font.pixelSize: Nexa.Theme.fontSizeXs
                                    font.weight: stylePill.isSelected ? Nexa.Theme.fontWeightDemiBold : Nexa.Theme.fontWeightRegular
                                    color: stylePill.isSelected ? Nexa.Theme.onPrimary : Nexa.Theme.text
                                }
                            }

                            MouseArea {
                                id: styleMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.stageStyle(stylePill.modelData.id)
                            }
                        }
                    }
                }
            }

            Item {
                Layout.fillWidth: true
            }

            // Night Warmth Toggle Chip
            Rectangle {
                Layout.preferredHeight: 32
                Layout.preferredWidth: 92
                radius: Nexa.Theme.radiusSm
                color: root.warmthEnabled
                    ? Nexa.Theme.hoverStrong
                    : warmthMouse.containsMouse
                        ? Nexa.Theme.hover
                        : Nexa.Theme.cardBackground
                border.width: Nexa.Theme.borderThin
                border.color: root.warmthEnabled ? Nexa.Theme.primary : Nexa.Theme.border

                Behavior on color { ColorAnimation { duration: Nexa.Theme.animationFast } }
                Behavior on border.color { ColorAnimation { duration: Nexa.Theme.animationFast } }

                Row {
                    anchors.centerIn: parent
                    spacing: 4

                    Text {
                        text: "󰖨"
                        font.family: Nexa.Theme.iconFontFamily
                        font.pixelSize: Nexa.Theme.iconSm
                        color: root.warmthEnabled ? Nexa.Theme.primary : Nexa.Theme.mutedText
                    }

                    Text {
                        text: root.warmthEnabled ? "Warm" : "Cool"
                        font.family: Nexa.Theme.fontFamily
                        font.pixelSize: Nexa.Theme.fontSizeXs
                        font.weight: Nexa.Theme.fontWeightMedium
                        color: root.warmthEnabled ? Nexa.Theme.primary : Nexa.Theme.text
                    }
                }

                MouseArea {
                    id: warmthMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.setWarmth(!root.warmthEnabled)
                }
            }

            // Appearance Mode Switch (Dark / Light)
            Rectangle {
                Layout.preferredHeight: 32
                Layout.preferredWidth: 140
                radius: Nexa.Theme.radiusSm
                color: Nexa.Theme.cardBackground
                border.width: Nexa.Theme.borderThin
                border.color: Nexa.Theme.border

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 2
                    spacing: 2

                    Repeater {
                        model: [
                            { id: "dark", label: "Dark", icon: "󰔎" },
                            { id: "light", label: "Light", icon: "󰖨" }
                        ]

                        Rectangle {
                            id: modePill
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: Nexa.Theme.radiusXs

                            readonly property bool isSelected:
                                root.stagedMode === modelData.id

                            color: isSelected
                                ? Nexa.Theme.primary
                                : modeMouse.containsMouse
                                    ? Nexa.Theme.hover
                                    : "transparent"

                            Behavior on color {
                                ColorAnimation { duration: Nexa.Theme.animationFast }
                            }

                            Row {
                                anchors.centerIn: parent
                                spacing: 4

                                Text {
                                    text: modePill.modelData.icon
                                    font.family: Nexa.Theme.iconFontFamily
                                    font.pixelSize: Nexa.Theme.iconSm
                                    color: modePill.isSelected ? Nexa.Theme.onPrimary : Nexa.Theme.mutedText
                                }

                                Text {
                                    text: modePill.modelData.label
                                    font.family: Nexa.Theme.fontFamily
                                    font.pixelSize: Nexa.Theme.fontSizeXs
                                    font.weight: modePill.isSelected ? Nexa.Theme.fontWeightDemiBold : Nexa.Theme.fontWeightRegular
                                    color: modePill.isSelected ? Nexa.Theme.onPrimary : Nexa.Theme.text
                                }
                            }

                            MouseArea {
                                id: modeMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.stageMode(modePill.modelData.id)
                            }
                        }
                    }
                }
            }
        }

        // --------------------------------------------------------
        // MAIN CONTENT AREA (Left: Explorer / Cards, Right: Preview Hub)
        // --------------------------------------------------------
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Nexa.Theme.spacingSm

            // ====================================================
            // LEFT COLUMN: PRESET EXPLORER / CARDS (or Wallpaper Info)
            // ====================================================
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Nexa.Theme.radiusMd
                color: Nexa.Theme.cardBackground
                border.width: Nexa.Theme.borderThin
                border.color: Nexa.Theme.border
                clip: true

                // Preset Explorer View
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 8
                    visible: root.stagedStyle === "preset"

                    // Search Input & Count Badge
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 30
                        Layout.maximumHeight: 30
                        Layout.minimumHeight: 30
                        Layout.fillHeight: false
                        spacing: 6

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: Nexa.Theme.radiusSm
                            color: Nexa.Theme.surfaceContainer
                            border.width: Nexa.Theme.borderThin
                            border.color: searchInput.activeFocus ? Nexa.Theme.primary : Nexa.Theme.border

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 6

                                Text {
                                    text: "󰍉"
                                    font.family: Nexa.Theme.iconFontFamily
                                    font.pixelSize: Nexa.Theme.iconSm
                                    color: Nexa.Theme.mutedText
                                }

                                TextInput {
                                    id: searchInput
                                    Layout.fillWidth: true
                                    font.family: Nexa.Theme.fontFamily
                                    font.pixelSize: Nexa.Theme.fontSizeXs
                                    color: Nexa.Theme.text
                                    clip: true
                                    text: root.searchQuery
                                    onTextChanged: root.searchQuery = text

                                    Text {
                                        anchors.fill: parent
                                        visible: !searchInput.text && !searchInput.activeFocus
                                        text: "Search " + root.presets.length + " presets..."
                                        font.family: Nexa.Theme.fontFamily
                                        font.pixelSize: Nexa.Theme.fontSizeXs
                                        color: Nexa.Theme.mutedText
                                    }
                                }

                                Text {
                                    visible: searchInput.text.length > 0
                                    text: "󰅖"
                                    font.family: Nexa.Theme.iconFontFamily
                                    font.pixelSize: Nexa.Theme.iconSm
                                    color: Nexa.Theme.mutedText

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            searchInput.text = ""
                                            root.searchQuery = ""
                                        }
                                    }
                                }
                            }
                        }

                        // Presets Count Badge
                        Rectangle {
                            Layout.preferredWidth: 64
                            Layout.fillHeight: true
                            radius: Nexa.Theme.radiusSm
                            color: Nexa.Theme.surfaceContainer
                            border.width: Nexa.Theme.borderThin
                            border.color: Nexa.Theme.border

                            Text {
                                anchors.centerIn: parent
                                text: root.filteredPresets.length + " / " + root.presets.length
                                font.family: Nexa.Theme.fontFamily
                                font.pixelSize: Nexa.Theme.fontSize2Xs
                                color: Nexa.Theme.mutedText
                            }
                        }
                    }

                    // Category Filter Pills (Horizontal Scroll)
                    Flickable {
                        id: categoryFlickable
                        Layout.fillWidth: true
                        Layout.preferredHeight: 28
                        Layout.maximumHeight: 28
                        Layout.minimumHeight: 28
                        Layout.fillHeight: false
                        contentWidth: categoryRow.width
                        contentHeight: 28
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        WheelHandler {
                            onWheel: event => {
                                categoryFlickable.contentX = Math.max(
                                    0,
                                    Math.min(
                                        categoryFlickable.contentWidth - categoryFlickable.width,
                                        categoryFlickable.contentX - event.angleDelta.y
                                    )
                                )
                            }
                        }

                        Row {
                            id: categoryRow
                            spacing: 4
                            height: 28

                            Repeater {
                                model: root.categories

                                Rectangle {
                                    id: catChip
                                    required property var modelData
                                    height: 24
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: catText.width + 16
                                    radius: Nexa.Theme.radiusPill

                                    readonly property bool isSelected:
                                        root.selectedCategory === modelData

                                    color: isSelected
                                        ? Nexa.Theme.primary
                                        : catMouse.containsMouse
                                            ? Nexa.Theme.hover
                                            : Nexa.Theme.surfaceContainer

                                    border.width: Nexa.Theme.borderThin
                                    border.color: isSelected ? Nexa.Theme.primary : Nexa.Theme.border

                                    Behavior on color { ColorAnimation { duration: Nexa.Theme.animationFast } }

                                    Text {
                                        id: catText
                                        anchors.centerIn: parent
                                        text: catChip.modelData
                                        font.family: Nexa.Theme.fontFamily
                                        font.pixelSize: Nexa.Theme.fontSize2Xs
                                        font.weight: catChip.isSelected ? Nexa.Theme.fontWeightDemiBold : Nexa.Theme.fontWeightRegular
                                        color: catChip.isSelected ? Nexa.Theme.onPrimary : Nexa.Theme.text
                                    }

                                    MouseArea {
                                        id: catMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.selectedCategory = catChip.modelData
                                    }
                                }
                            }
                        }
                    }

                    // Presets Grid Area (2-column layout with instant local preview and scroll thumb)
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true

                        GridView {
                            id: presetGrid
                            anchors.fill: parent
                            clip: true
                            cellWidth: Math.floor(width / 2)
                            cellHeight: 56
                            model: root.filteredPresets
                            boundsBehavior: Flickable.StopAtBounds

                        delegate: Item {
                            id: delegateRoot
                            required property var modelData

                            width: presetGrid.cellWidth
                            height: presetGrid.cellHeight

                            readonly property bool isStaged:
                                root.stagedPreset === modelData.id

                            readonly property bool isActive:
                                root.selectedPreset === modelData.id

                            Rectangle {
                                id: presetCard
                                anchors.fill: parent
                                anchors.margins: 3
                                radius: Nexa.Theme.radiusSm

                                color: delegateRoot.isStaged
                                    ? Nexa.Theme.surfaceContainerHigh
                                    : cardMouse.containsMouse
                                        ? Nexa.Theme.hover
                                        : Nexa.Theme.surfaceContainer

                                border.width: delegateRoot.isStaged ? 1.5 : Nexa.Theme.borderThin
                                border.color: delegateRoot.isStaged
                                    ? Nexa.Theme.primary
                                    : delegateRoot.isActive
                                        ? Nexa.Theme.success
                                        : cardMouse.containsMouse
                                            ? Nexa.Theme.borderStrong
                                            : Nexa.Theme.border

                                Behavior on color { ColorAnimation { duration: Nexa.Theme.animationFast } }
                                Behavior on border.color { ColorAnimation { duration: Nexa.Theme.animationFast } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8
                                    spacing: 6

                                    // Theme Name & Category Label
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1

                                        Row {
                                            spacing: 4
                                            Layout.fillWidth: true

                                            Text {
                                                text: delegateRoot.modelData.name
                                                font.family: Nexa.Theme.fontFamily
                                                font.pixelSize: Nexa.Theme.fontSizeXs
                                                font.weight: delegateRoot.isStaged ? Nexa.Theme.fontWeightDemiBold : Nexa.Theme.fontWeightMedium
                                                color: delegateRoot.isStaged ? Nexa.Theme.primary : Nexa.Theme.text
                                                elide: Text.ElideRight
                                                width: Math.min(implicitWidth, presetCard.width - 80)
                                            }

                                            // Small green dot for currently active system preset
                                            Rectangle {
                                                visible: delegateRoot.isActive
                                                width: 6
                                                height: 6
                                                radius: 3
                                                color: Nexa.Theme.success
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                        }

                                        Text {
                                            text: delegateRoot.modelData.category
                                            font.family: Nexa.Theme.fontFamily
                                            font.pixelSize: Nexa.Theme.fontSize2Xs
                                            color: Nexa.Theme.mutedText
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                    }

                                    // 3 Swatch Dots for this preset in the current mode
                                    Row {
                                        spacing: 3
                                        Layout.alignment: Qt.AlignVCenter

                                        Repeater {
                                            model: 3

                                            Rectangle {
                                                required property int index
                                                width: 12
                                                height: 12
                                                radius: 6
                                                color: root.colorForPreset(delegateRoot.modelData.id, index, root.selectedMode)
                                                border.width: Nexa.Theme.borderThin
                                                border.color: Nexa.Theme.border
                                            }
                                        }
                                    }
                                }

                                MouseArea {
                                    id: cardMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.stagePreset(delegateRoot.modelData.id)
                                }
                            }
                        }
                    }

                    // Vertical Scroll Indicator
                    Rectangle {
                        id: scrollTrack
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.margins: 2
                        width: 4
                        radius: 2
                        color: "transparent"
                        visible: presetGrid.contentHeight > presetGrid.height

                        Rectangle {
                            id: scrollThumb
                            width: parent.width
                            radius: parent.radius
                            color: Nexa.Theme.primary
                            opacity: 0.5
                            height: Math.max(16, presetGrid.height * (presetGrid.height / Math.max(1, presetGrid.contentHeight)))
                            y: (presetGrid.contentHeight > presetGrid.height)
                                ? (presetGrid.contentY / (presetGrid.contentHeight - presetGrid.height)) * (presetGrid.height - height)
                                : 0
                        }
                    }
                }
            }

                // Wallpaper Full / Accents View
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 12
                    visible: root.stagedStyle !== "preset"

                    RowLayout {
                        spacing: 10

                        Rectangle {
                            Layout.preferredWidth: 42
                            Layout.preferredHeight: 42
                            radius: Nexa.Theme.radiusSm
                            color: Nexa.Theme.surfaceContainer
                            border.width: Nexa.Theme.borderThin
                            border.color: Nexa.Theme.border

                            Text {
                                anchors.centerIn: parent
                                text: "󰸉"
                                font.family: Nexa.Theme.iconFontFamily
                                font.pixelSize: Nexa.Theme.iconMd
                                color: Nexa.Theme.primary
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                text: root.stagedStyle === "wallpaperFull"
                                    ? "Full Wallpaper Palette"
                                    : "Wallpaper Accents"
                                font.family: Nexa.Theme.fontFamily
                                font.pixelSize: Nexa.Theme.fontSizeMd
                                font.weight: Nexa.Theme.fontWeightDemiBold
                                color: Nexa.Theme.text
                            }

                            Text {
                                text: root.stagedStyle === "wallpaperFull"
                                    ? "Extracts dynamic Material You palette from your active wallpaper."
                                    : "Extracts accents from wallpaper while preserving preset surface tones."
                                font.family: Nexa.Theme.fontFamily
                                font.pixelSize: Nexa.Theme.fontSizeXs
                                color: Nexa.Theme.mutedText
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 64
                        radius: Nexa.Theme.radiusSm
                        color: Nexa.Theme.surfaceContainer
                        border.width: Nexa.Theme.borderThin
                        border.color: Nexa.Theme.border

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 10

                            Text {
                                text: "󰋩"
                                font.family: Nexa.Theme.iconFontFamily
                                font.pixelSize: Nexa.Theme.iconSm
                                color: Nexa.Theme.mutedText
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                Text {
                                    text: "Current Wallpaper Source"
                                    font.family: Nexa.Theme.fontFamily
                                    font.pixelSize: Nexa.Theme.fontSize2Xs
                                    color: Nexa.Theme.mutedText
                                }

                                Text {
                                    text: root.wallpaperSource.length > 0
                                        ? root.wallpaperSource.split("/").pop()
                                        : "No active wallpaper"
                                    font.family: Nexa.Theme.fontFamily
                                    font.pixelSize: Nexa.Theme.fontSizeXs
                                    font.weight: Nexa.Theme.fontWeightMedium
                                    color: Nexa.Theme.text
                                    elide: Text.ElideMiddle
                                    Layout.fillWidth: true
                                }
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }
                }
            }

            // ====================================================
            // RIGHT COLUMN: LIVE INTERACTIVE PREVIEW & ACTION HUB
            // ====================================================
            Rectangle {
                Layout.preferredWidth: 260
                Layout.fillHeight: true
                radius: Nexa.Theme.radiusMd
                color: Nexa.Theme.cardBackground
                border.width: Nexa.Theme.borderThin
                border.color: Nexa.Theme.border
                clip: true

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 8

                    // Header row: Title & Mode Badge
                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            text: "Live Preview"
                            font.family: Nexa.Theme.fontFamily
                            font.pixelSize: Nexa.Theme.fontSizeSm
                            font.weight: Nexa.Theme.fontWeightDemiBold
                            color: Nexa.Theme.text
                        }

                        Item { Layout.fillWidth: true }

                        Rectangle {
                            height: 18
                            width: modeBadgeText.width + 10
                            radius: Nexa.Theme.radiusPill
                            color: Nexa.Theme.surfaceContainer
                            border.width: Nexa.Theme.borderThin
                            border.color: Nexa.Theme.border

                            Text {
                                id: modeBadgeText
                                anchors.centerIn: parent
                                text: root.stagedMode.toUpperCase()
                                font.family: Nexa.Theme.fontFamily
                                font.pixelSize: 8
                                font.weight: Nexa.Theme.fontWeightBold
                                color: Nexa.Theme.mutedText
                            }
                        }
                    }

                    // Mini UI Mockup Card themed with staged colors
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 96
                        radius: Nexa.Theme.radiusSm
                        color: Nexa.Theme.surfaceContainer
                        border.width: Nexa.Theme.borderThin
                        border.color: Nexa.Theme.border
                        clip: true

                        // Window Mockup Header
                        Rectangle {
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 22
                            color: Nexa.Theme.surfaceContainerHigh

                            Row {
                                anchors.left: parent.left
                                anchors.leftMargin: 6
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 4

                                Rectangle { width: 6; height: 6; radius: 3; color: Nexa.Theme.error }
                                Rectangle { width: 6; height: 6; radius: 3; color: Nexa.Theme.warning }
                                Rectangle { width: 6; height: 6; radius: 3; color: Nexa.Theme.success }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: root.stagedPresetName
                                font.family: Nexa.Theme.fontFamily
                                font.pixelSize: Nexa.Theme.fontSize2Xs
                                font.weight: Nexa.Theme.fontWeightMedium
                                color: Nexa.Theme.mutedText
                                elide: Text.ElideRight
                                width: parent.width - 50
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }

                        // Window Mockup Body
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.topMargin: 26
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            anchors.bottomMargin: 6
                            spacing: 5

                            // Accent bar in staged primary
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 4
                                radius: Nexa.Theme.radiusPill
                                color: root.stagedPrimary

                                Behavior on color { ColorAnimation { duration: Nexa.Theme.animationFast } }
                            }

                            // Sample Mini Controls Row
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                // Mini Action Pill
                                Rectangle {
                                    Layout.preferredHeight: 18
                                    Layout.preferredWidth: 62
                                    radius: 4
                                    color: root.stagedPrimary

                                    Behavior on color { ColorAnimation { duration: Nexa.Theme.animationFast } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "Button"
                                        font.family: Nexa.Theme.fontFamily
                                        font.pixelSize: 9
                                        font.weight: Nexa.Theme.fontWeightBold
                                        color: Nexa.Theme.onPrimary
                                    }
                                }

                                // Mini Secondary Pill
                                Rectangle {
                                    Layout.preferredHeight: 18
                                    Layout.preferredWidth: 52
                                    radius: 4
                                    color: root.stagedSecondary

                                    Behavior on color { ColorAnimation { duration: Nexa.Theme.animationFast } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "Chip"
                                        font.family: Nexa.Theme.fontFamily
                                        font.pixelSize: 9
                                        color: Nexa.Theme.onPrimary
                                    }
                                }

                                // Mini Tertiary Tag
                                Rectangle {
                                    Layout.preferredHeight: 18
                                    Layout.fillWidth: true
                                    radius: 4
                                    color: root.stagedTertiary

                                    Behavior on color { ColorAnimation { duration: Nexa.Theme.animationFast } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "Tag"
                                        font.family: Nexa.Theme.fontFamily
                                        font.pixelSize: 9
                                        color: Nexa.Theme.onPrimary
                                    }
                                }
                            }

                            // Secondary accent line
                            Rectangle {
                                Layout.preferredWidth: parent.width * 0.65
                                Layout.preferredHeight: 3
                                radius: Nexa.Theme.radiusPill
                                color: root.stagedSecondary

                                Behavior on color { ColorAnimation { duration: Nexa.Theme.animationFast } }
                            }
                        }
                    }

                    // Hex Swatches Row
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        // Primary Swatch
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 44
                            radius: Nexa.Theme.radiusSm
                            color: Nexa.Theme.surfaceContainer
                            border.width: Nexa.Theme.borderThin
                            border.color: Nexa.Theme.border

                            Column {
                                anchors.centerIn: parent
                                spacing: 2

                                Rectangle {
                                    width: 14
                                    height: 14
                                    radius: 7
                                    color: root.stagedPrimary
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    border.width: Nexa.Theme.borderThin
                                    border.color: Nexa.Theme.border
                                    Behavior on color { ColorAnimation { duration: Nexa.Theme.animationFast } }
                                }

                                Text {
                                    text: root.hexForStaged(0)
                                    font.family: Nexa.Theme.fontFamily
                                    font.pixelSize: 8
                                    font.weight: Nexa.Theme.fontWeightMedium
                                    color: Nexa.Theme.mutedText
                                }
                            }
                        }

                        // Secondary Swatch
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 44
                            radius: Nexa.Theme.radiusSm
                            color: Nexa.Theme.surfaceContainer
                            border.width: Nexa.Theme.borderThin
                            border.color: Nexa.Theme.border

                            Column {
                                anchors.centerIn: parent
                                spacing: 2

                                Rectangle {
                                    width: 14
                                    height: 14
                                    radius: 7
                                    color: root.stagedSecondary
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    border.width: Nexa.Theme.borderThin
                                    border.color: Nexa.Theme.border
                                    Behavior on color { ColorAnimation { duration: Nexa.Theme.animationFast } }
                                }

                                Text {
                                    text: root.hexForStaged(1)
                                    font.family: Nexa.Theme.fontFamily
                                    font.pixelSize: 8
                                    font.weight: Nexa.Theme.fontWeightMedium
                                    color: Nexa.Theme.mutedText
                                }
                            }
                        }

                        // Tertiary Swatch
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 44
                            radius: Nexa.Theme.radiusSm
                            color: Nexa.Theme.surfaceContainer
                            border.width: Nexa.Theme.borderThin
                            border.color: Nexa.Theme.border

                            Column {
                                anchors.centerIn: parent
                                spacing: 2

                                Rectangle {
                                    width: 14
                                    height: 14
                                    radius: 7
                                    color: root.stagedTertiary
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    border.width: Nexa.Theme.borderThin
                                    border.color: Nexa.Theme.border
                                    Behavior on color { ColorAnimation { duration: Nexa.Theme.animationFast } }
                                }

                                Text {
                                    text: root.hexForStaged(2)
                                    font.family: Nexa.Theme.fontFamily
                                    font.pixelSize: 8
                                    font.weight: Nexa.Theme.fontWeightMedium
                                    color: Nexa.Theme.mutedText
                                }
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }

                    // Selected Preset Info Label
                    Text {
                        text: root.stagedStyle === "preset"
                            ? (root.stagedPresetCategory.length > 0 ? (root.stagedPresetCategory + " · " + root.stagedPresetName) : root.stagedPresetName)
                            : (root.stagedStyle === "wallpaperFull" ? "Full Wallpaper Theme" : "Wallpaper Accents Theme")
                        font.family: Nexa.Theme.fontFamily
                        font.pixelSize: Nexa.Theme.fontSizeXs
                        color: Nexa.Theme.mutedText
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                    }

                    // HERO ACTION BUTTON: Apply Theme
                    Rectangle {
                        id: applyButton
                        Layout.fillWidth: true
                        Layout.preferredHeight: 36
                        radius: Nexa.Theme.radiusSm

                        readonly property bool canApply:
                            !root.applying && !root.isCurrentThemeActive

                        color: {
                            if (root.applying)
                                return Nexa.Theme.hoverStrong
                            if (root.isCurrentThemeActive)
                                return Nexa.Theme.surfaceContainerHigh
                            if (applyMouse.pressed)
                                return Nexa.Theme.pressed
                            if (applyMouse.containsMouse)
                                return Nexa.Theme.hoverStrong
                            return Nexa.Theme.primary
                        }

                        border.width: Nexa.Theme.borderThin
                        border.color: root.isCurrentThemeActive
                            ? Nexa.Theme.success
                            : Nexa.Theme.primary

                        Behavior on color { ColorAnimation { duration: Nexa.Theme.animationFast } }

                        Row {
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                text: {
                                    if (root.applying)
                                        return "󰑐"
                                    if (root.isCurrentThemeActive)
                                        return "󰄬"
                                    return "󰄬"
                                }
                                font.family: Nexa.Theme.iconFontFamily
                                font.pixelSize: Nexa.Theme.iconSm
                                color: root.isCurrentThemeActive ? Nexa.Theme.success : Nexa.Theme.onPrimary
                            }

                            Text {
                                text: {
                                    if (root.applying)
                                        return "Applying..."
                                    if (root.isCurrentThemeActive)
                                        return "Active Theme"
                                    if (root.stagedStyle === "preset")
                                        return "Apply Preset"
                                    if (root.stagedStyle === "wallpaperAccents")
                                        return "Apply Accents"
                                    return "Apply Wallpaper"
                                }
                                font.family: Nexa.Theme.fontFamily
                                font.pixelSize: Nexa.Theme.fontSizeSm
                                font.weight: Nexa.Theme.fontWeightDemiBold
                                color: root.isCurrentThemeActive ? Nexa.Theme.success : Nexa.Theme.onPrimary
                            }
                        }

                        MouseArea {
                            id: applyMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: applyButton.canApply ? Qt.PointingHandCursor : Qt.ArrowCursor
                            enabled: applyButton.canApply
                            onClicked: root.applyCurrentConfiguration()
                        }
                    }
                }
            }
        }
    }
}
