// pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../NewNexaUI" as NexaUI
import "themeSettingSection" as ThemeViews

Item {
    id: root

    anchors.fill: parent

    signal requestClose()

    // ============================================================
    // STATE & REPOSITORIES
    // ============================================================
    property string activeSubTab: "presets"

    onActiveSubTabChanged: {
        if (activeSubTab === "presets") {
            root.stagedStyle = "preset"
        } else if (activeSubTab === "wallpaper") {
            if (root.stagedStyle !== "wallpaperFull" && root.stagedStyle !== "wallpaperAccents") {
                root.stagedStyle = (root.selectedStyle === "wallpaperAccents" || root.selectedStyle === "wallpaperFull") ? root.selectedStyle : "wallpaperFull"
            }
        }
    }

    property string selectedStyle: ""
    property string selectedPreset: ""
    property string selectedMode: "dark"
    property string wallpaperSource: ""

    // Staging state
    property string stagedStyle: "preset"
    property string stagedPreset: ""
    property string stagedMode: "dark"

    property bool warmthEnabled: false
    property bool applying: false
    property bool presetsLoaded: false

    property var presets: []
    property var categories: ["All"]
    property string selectedCategory: "All"
    property string searchQuery: ""

    // Compositor state (Hyprland window styling)
    property int windowRounding: NexaUI.NexaTokens.windowRounding
    property int nexaRounding: NexaUI.NexaTokens.nexaRounding
    property int windowBorderSize: NexaUI.NexaTokens.windowBorderSize
    property bool windowGlow: NexaUI.NexaTokens.windowGlow
    property real windowDim: NexaUI.NexaTokens.windowDim

    readonly property string nexad: Quickshell.env("HOME") + "/.config/nexa/rust/target/release/nexad"

    onVisibleChanged: {
        if (visible) {
            statusProcess.running = true
            warmthStatusProcess.running = true
        }
    }

    // Dynamic Derived Staged Colors
    readonly property color stagedPrimary: {
        if (root.stagedStyle === "preset")
            return root.colorForPreset(root.stagedPreset, 0, root.stagedMode)
        return NexaUI.NexaColors.primary
    }

    readonly property color stagedSecondary: {
        if (root.stagedStyle === "preset")
            return root.colorForPreset(root.stagedPreset, 1, root.stagedMode)
        return NexaUI.NexaColors.secondary
    }

    readonly property color stagedTertiary: {
        if (root.stagedStyle === "preset")
            return root.colorForPreset(root.stagedPreset, 2, root.stagedMode)
        return NexaUI.NexaColors.tertiary
    }

    readonly property string stagedPresetName: {
        if (root.stagedStyle === "wallpaperFull")
            return "Full Wallpaper"
        if (root.stagedStyle === "wallpaperAccents")
            return "Wallpaper Accents"
        const p = root.presetById(root.stagedPreset)
        if (!p) return root.stagedPreset || "Select Preset"
        if (p.id === "extras/Dark" || (p.name === "extras" && p.id && p.id.indexOf("Dark") >= 0)) {
            return "Material 3 Dark"
        }
        if (p.id === "extras/Light" || (p.name === "extras" && p.id && p.id.indexOf("Light") >= 0)) {
            return "Material 3 Light"
        }
        return p.name ? p.name.replace(/([a-z])([A-Z])/g, '$1 $2') : p.id
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

    // ============================================================
    // HELPERS
    // ============================================================
    function presetById(id) {
        if (!id) return null
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
        return slot === 0 ? NexaUI.NexaColors.primary : slot === 1 ? NexaUI.NexaColors.secondary : NexaUI.NexaColors.tertiary
    }

    function syncStagedToActive() {
        root.stagedStyle = root.selectedStyle || "preset"
        root.stagedPreset = root.selectedPreset || (root.presets.length > 0 ? root.presets[0].id : "")
        root.stagedMode = root.selectedMode || "dark"
    }

    function rebuildCategories() {
        const seen = {}
        const list = ["All"]
        const order = [
            "CuratedVault", "extras", "LinuxHyprland", "CyberTech", "ColdArctic",
            "Nature", "WarmCozy", "Cosmic", "SkyTime",
            "MinimalMonochrome", "SoftCalm", "Mystic"
        ]
        for (let o = 0; o < order.length; ++o) {
            seen[order[o]] = true
            list.push(order[o])
        }
        for (let i = 0; i < root.presets.length; ++i) {
            const cat = root.presets[i].category
            if (cat && !seen[cat]) {
                seen[cat] = true
                list.push(cat)
            }
        }
        root.categories = list
    }

    function stagePreset(presetId, mode) {
        if (presetId) {
            root.stagedStyle = "preset"
            root.stagedPreset = presetId
            if (mode) root.stagedMode = mode
        }
    }

    function stageStyle(style) {
        if (style) root.stagedStyle = style
    }

    function stageMode(mode) {
        if (mode) root.stagedMode = mode
    }

    function applyCurrentConfiguration() {
        if (root.applying || root.isCurrentThemeActive)
            return

        root.applying = true
        if (root.stagedStyle === "preset") {
            applyProcess.command = [root.nexad, "theme", "apply-preset", String(root.stagedPreset), String(root.stagedMode)]
        } else {
            applyProcess.command = [root.nexad, "theme", "apply-style", String(root.stagedStyle), String(root.stagedMode)]
        }
        applyProcess.running = true
    }

    function setWarmth(enabled) {
        if (root.warmthEnabled === enabled || root.applying) return
        root.warmthEnabled = enabled
        if (enabled) {
            warmthProcess.command = ["sh", "-c", "\"$1\" screenTemp mode wallpaper && \"$1\" screenTemp enable", "sh", root.nexad]
        } else {
            warmthProcess.command = [root.nexad, "screenTemp", "disable"]
        }
        warmthProcess.running = true
    }

    function setGlassMode(enabled) {
        NexaUI.NexaOptics.setGlassMode(enabled)
    }

    function nextWallpaper() {
        Quickshell.execDetached([root.nexad, "wallpaper", "apply", "next"])
        refreshTimer.restart()
    }

    function setRounding(r) {
        const val = parseInt(r) || 0
        root.windowRounding = val
        NexaUI.NexaTokens.saveDecorations(val, root.nexaRounding, root.windowBorderSize, root.windowGlow, root.windowDim)
    }

    function setNexaRounding(nr) {
        const val = parseInt(nr) || 0
        root.nexaRounding = val
        NexaUI.NexaTokens.saveDecorations(root.windowRounding, val, root.windowBorderSize, root.windowGlow, root.windowDim)
    }

    function setBorderSize(b) {
        const val = parseInt(b) || 0
        root.windowBorderSize = val
        NexaUI.NexaTokens.saveDecorations(root.windowRounding, root.nexaRounding, val, root.windowGlow, root.windowDim)
    }

    function setWindowGlow(on) {
        root.windowGlow = on
        NexaUI.NexaTokens.saveDecorations(root.windowRounding, root.nexaRounding, root.windowBorderSize, on, root.windowDim)
    }

    function setWindowDim(dim) {
        root.windowDim = dim
        NexaUI.NexaTokens.saveDecorations(root.windowRounding, root.nexaRounding, root.windowBorderSize, root.windowGlow, dim)
    }

    Timer {
        id: refreshTimer
        interval: 1200
        repeat: false
        onTriggered: {
            statusProcess.running = true
            warmthStatusProcess.running = true
        }
    }

    // ============================================================
    // BACKEND PROCESSES
    // ============================================================
    Process {
        id: statusProcess
        command: [root.nexad, "theme", "status"]
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
                        if (sep >= 0) loadedStyle = line.substring(sep + 1).trim()
                    }
                    if (line.startsWith("Preset")) {
                        const sep = line.indexOf(":")
                        if (sep >= 0) loadedPreset = line.substring(sep + 1).trim()
                    }
                    if (line.startsWith("Mode")) {
                        const sep = line.indexOf(":")
                        if (sep >= 0) loadedMode = line.substring(sep + 1).trim()
                    }
                    if (line.startsWith("Wallpaper")) {
                        const sep = line.indexOf(":")
                        if (sep >= 0) loadedWallpaper = line.substring(sep + 1).trim()
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
        command: [root.nexad, "theme", "presets-json"]
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
                    root.presetsLoaded = true
                    root.rebuildCategories()
                    if (!root.stagedPreset || root.stagedPreset.length === 0)
                        root.syncStagedToActive()
                } catch (e) {
                    root.presets = []
                    root.presetsLoaded = true
                }

                statusProcess.running = true
            }
        }
    }

    Process {
        id: warmthStatusProcess
        command: [root.nexad, "screenTemp", "info"]
        stdout: StdioCollector {
            onStreamFinished: {
                const output = text.trim()
                if (output.length === 0) return
                try {
                    const state = JSON.parse(output)
                    root.warmthEnabled = state.enabled === true && state.mode === "wallpaper"
                } catch (e) {}
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

    Component.onCompleted: {
        presetCatalogProcess.running = true
        statusProcess.running = true
        warmthStatusProcess.running = true
    }

    // ============================================================
    // MAIN UI LAYOUT
    // ============================================================
    ColumnLayout {
        anchors.fill: parent
        spacing: 14

        // ── TOP NAVIGATION SUB-TABS ──────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 38
            spacing: 12

            // Sub-tabs bar: Presets | Wallpaper & Material | Windows & Effects | Shaders & Glass
            Rectangle {
                Layout.preferredHeight: 38
                Layout.preferredWidth: subTabsRow.implicitWidth + 8
                radius: NexaUI.NexaTokens.radiusSm
                color: NexaUI.NexaColors.surfaceContainer
                border.width: NexaUI.NexaTokens.borderThin
                border.color: NexaUI.NexaColors.border

                RowLayout {
                    id: subTabsRow
                    anchors.fill: parent
                    anchors.margins: 3
                    spacing: 4

                    Repeater {
                        model: [
                            { id: "presets", label: "Presets", icon: "󰏘" },
                            { id: "wallpaper", label: "Wallpaper & Material", icon: "󰸉" },
                            { id: "windows", label: "Windows & Effects", icon: "󰍹" },
                            { id: "filters", label: "Filters", icon: "󰹑" },
                            { id: "shaders", label: "Shaders & Glass", icon: "󰄛" }
                        ]

                        Rectangle {
                            id: tabPill
                            required property var modelData
                            Layout.fillHeight: true
                            Layout.preferredWidth: pillContent.implicitWidth + 24
                            radius: NexaUI.NexaTokens.radiusXs

                            readonly property bool isSelected: root.activeSubTab === modelData.id

                            color: isSelected ? NexaUI.NexaColors.primaryContainer : (tabMouse.containsMouse ? NexaUI.NexaColors.surfaceContainerHigh : "transparent")
                            border.width: isSelected ? 1 : 0
                            border.color: isSelected ? NexaUI.NexaColors.primary : "transparent"

                            Behavior on color { ColorAnimation { duration: NexaUI.NexaMotion.durationFast } }

                            Row {
                                id: pillContent
                                anchors.centerIn: parent
                                spacing: 8

                                Text {
                                    text: tabPill.modelData.icon
                                    font.family: NexaUI.NexaTypography.familyIcon
                                    font.pixelSize: 14
                                    color: tabPill.isSelected ? NexaUI.NexaColors.onPrimaryContainer : NexaUI.NexaColors.mutedText
                                }

                                Text {
                                    text: tabPill.modelData.label
                                    font.family: NexaUI.NexaTypography.familyBody
                                    font.pixelSize: 12
                                    font.weight: tabPill.isSelected ? NexaUI.NexaTypography.weightSemiBold : NexaUI.NexaTypography.weightRegular
                                    color: tabPill.isSelected ? NexaUI.NexaColors.onPrimaryContainer : NexaUI.NexaColors.text
                                }
                            }

                            MouseArea {
                                id: tabMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.activeSubTab = tabPill.modelData.id
                            }
                        }
                    }
                }
            }

            Item { Layout.fillWidth: true }

            // Global Dark / Light Appearance Switch
            Rectangle {
                Layout.preferredHeight: 38
                Layout.preferredWidth: 160
                radius: NexaUI.NexaTokens.radiusSm
                color: NexaUI.NexaColors.surfaceContainer
                border.width: NexaUI.NexaTokens.borderThin
                border.color: NexaUI.NexaColors.border

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 3
                    spacing: 3

                    // Dark Pill
                    Rectangle {
                        id: topDarkPill
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: NexaUI.NexaTokens.radiusXs
                        readonly property bool isSelected: root.stagedMode === "dark"
                        color: isSelected ? NexaUI.NexaColors.primaryContainer : (topDarkHov.containsMouse ? NexaUI.NexaColors.surfaceContainerHigh : "transparent")
                        border.width: isSelected ? 1 : 0
                        border.color: isSelected ? NexaUI.NexaColors.primary : "transparent"

                        Row {
                            anchors.centerIn: parent
                            spacing: 5
                            Text {
                                text: "󰖔"
                                font.family: NexaUI.NexaTypography.familyIcon
                                font.pixelSize: 13
                                color: topDarkPill.isSelected ? NexaUI.NexaColors.onPrimaryContainer : NexaUI.NexaColors.mutedText
                            }
                            Text {
                                text: "Dark"
                                font.family: NexaUI.NexaTypography.familyBody
                                font.pixelSize: 12
                                font.weight: topDarkPill.isSelected ? NexaUI.NexaTypography.weightSemiBold : NexaUI.NexaTypography.weightRegular
                                color: topDarkPill.isSelected ? NexaUI.NexaColors.onPrimaryContainer : NexaUI.NexaColors.text
                            }
                        }

                        MouseArea {
                            id: topDarkHov
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.stageMode("dark")
                        }
                    }

                    // Light Pill
                    Rectangle {
                        id: topLightPill
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: NexaUI.NexaTokens.radiusXs
                        readonly property bool isSelected: root.stagedMode === "light"
                        color: isSelected ? NexaUI.NexaColors.primaryContainer : (topLightHov.containsMouse ? NexaUI.NexaColors.surfaceContainerHigh : "transparent")
                        border.width: isSelected ? 1 : 0
                        border.color: isSelected ? NexaUI.NexaColors.primary : "transparent"

                        Row {
                            anchors.centerIn: parent
                            spacing: 5
                            Text {
                                text: "󰖙"
                                font.family: NexaUI.NexaTypography.familyIcon
                                font.pixelSize: 13
                                color: topLightPill.isSelected ? NexaUI.NexaColors.onPrimaryContainer : NexaUI.NexaColors.mutedText
                            }
                            Text {
                                text: "Light"
                                font.family: NexaUI.NexaTypography.familyBody
                                font.pixelSize: 12
                                font.weight: topLightPill.isSelected ? NexaUI.NexaTypography.weightSemiBold : NexaUI.NexaTypography.weightRegular
                                color: topLightPill.isSelected ? NexaUI.NexaColors.onPrimaryContainer : NexaUI.NexaColors.text
                            }
                        }

                        MouseArea {
                            id: topLightHov
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.stageMode("light")
                        }
                    }
                }
            }
        }

        // ── TAB CONTENT VIEWS ────────────────────────────────────────────────
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // 1. Presets View
            ThemeViews.PresetsTab {
                anchors.fill: parent
                visible: root.activeSubTab === "presets"

                presets: root.presets
                categories: root.categories
                selectedCategory: root.selectedCategory
                searchQuery: root.searchQuery

                stagedPreset: root.stagedPreset
                stagedStyle: root.stagedStyle
                stagedMode: root.stagedMode
                selectedPreset: root.selectedPreset
                selectedStyle: root.selectedStyle
                selectedMode: root.selectedMode

                applying: root.applying
                isCurrentThemeActive: root.isCurrentThemeActive

                stagedPrimary: root.stagedPrimary
                stagedSecondary: root.stagedSecondary
                stagedTertiary: root.stagedTertiary
                stagedPresetName: root.stagedPresetName
                stagedPresetCategory: root.stagedPresetCategory

                onStagePresetRequested: (id, mode) => root.stagePreset(id, mode)
                onStageModeRequested: m => root.stageMode(m)
                onApplyRequested: () => root.applyCurrentConfiguration()
            }

            // 2. Wallpaper View
            ThemeViews.WallpaperTab {
                anchors.fill: parent
                visible: root.activeSubTab === "wallpaper"

                stagedStyle: root.stagedStyle
                stagedMode: root.stagedMode
                selectedStyle: root.selectedStyle
                selectedMode: root.selectedMode
                wallpaperSource: root.wallpaperSource

                applying: root.applying
                isCurrentThemeActive: root.isCurrentThemeActive
                warmthEnabled: root.warmthEnabled
                isGlassMode: NexaUI.NexaOptics.glassMode

                activePrimary: root.stagedPrimary
                activeSecondary: root.stagedSecondary
                activeTertiary: root.stagedTertiary

                onStageStyleRequested: s => root.stageStyle(s)
                onStageModeRequested: m => root.stageMode(m)
                onSetWarmthRequested: w => root.setWarmth(w)
                onSetGlassModeRequested: g => root.setGlassMode(g)
                onShuffleWallpaperRequested: () => root.nextWallpaper()
                onApplyRequested: () => root.applyCurrentConfiguration()
            }

            // 3. Windows & Effects View
            ThemeViews.WindowsTab {
                anchors.fill: parent
                visible: root.activeSubTab === "windows"

                windowRounding: root.windowRounding
                nexaRounding: root.nexaRounding
                islandRounding: NexaUI.NexaTokens.islandRounding
                windowBorderSize: root.windowBorderSize
                windowGlow: root.windowGlow
                windowDim: root.windowDim

                onSetRoundingRequested: r => root.setRounding(r)
                onSetNexaRoundingRequested: nr => root.setNexaRounding(nr)
                onSetIslandRoundingRequested: ir => NexaUI.NexaTokens.setIslandRounding(ir)
                onSetBorderSizeRequested: b => root.setBorderSize(b)
                onSetWindowGlowRequested: g => root.setWindowGlow(g)
                onSetWindowDimRequested: d => root.setWindowDim(d)
            }

            // 4. Screen Filters View
            ThemeViews.FiltersTab {
                anchors.fill: parent
                visible: root.activeSubTab === "filters"
            }

            // 5. Shaders & Surface Materials View
            ThemeViews.ShadersTab {
                anchors.fill: parent
                visible: root.activeSubTab === "shaders"
            }
        }
    }
}
