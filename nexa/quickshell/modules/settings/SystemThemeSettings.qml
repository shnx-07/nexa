// pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../theme" as Nexa
import "./theme" as ThemeViews

Item {
    id: root

    anchors.fill: parent

    signal requestClose()

    // ============================================================
    // STATE & REPOSITORIES
    // ============================================================
    property string activeSubTab: "presets" // "presets", "wallpaper", "windows"

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
    property int windowRounding: Nexa.Theme.windowRounding
    property int windowBorderSize: Nexa.Theme.windowBorderSize
    property bool windowGlow: true
    property real windowDim: 0.0

    readonly property string themeScript: "$HOME/.config/nexa/scripts/theme.sh"
    readonly property string nexad: "$HOME/.config/nexa/rust/target/release/nexad"

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
        return slot === 0 ? Nexa.Theme.primary : slot === 1 ? Nexa.Theme.secondary : Nexa.Theme.tertiary
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
            "extras", "LinuxHyprland", "CyberTech", "ColdArctic",
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
            applyProcess.command = [root.themeScript, "apply-preset", String(root.stagedPreset), String(root.stagedMode)]
        } else {
            applyProcess.command = [root.themeScript, "apply-style", String(root.stagedStyle), String(root.stagedMode)]
        }
        applyProcess.running = true
    }

    function setWarmth(enabled) {
        if (root.warmthEnabled === enabled || root.applying) return
        root.warmthEnabled = enabled
        const cmd = enabled
            ? root.nexad + " screenTemp mode wallpaper && " + root.nexad + " screenTemp enable"
            : root.nexad + " screenTemp disable"
        warmthProcess.command = ["sh", "-c", cmd]
        warmthProcess.running = true
    }

    function setGlassMode(enabled) {
        Nexa.Theme.glassMode = enabled
        Quickshell.execDetached([
            "sh",
            "-c",
            "mkdir -p \"$HOME/.config/nexa/config\" && printf '%s\\n' \"" + (enabled ? "true" : "false") + "\" > \"$HOME/.config/nexa/config/glass.conf\""
        ])
    }

    function nextWallpaper() {
        Quickshell.execDetached([Quickshell.env("HOME") + "/.config/nexa/scripts/wallpaper.sh", "next"])
        refreshTimer.restart()
    }

    function setRounding(r) {
        const val = parseInt(r) || 0
        root.windowRounding = val
        Nexa.Theme.windowRounding = val
        Quickshell.execDetached(["hyprctl", "eval", "hl.config({ decoration = { rounding = " + val + " } })"])
    }

    function setBorderSize(b) {
        const val = parseInt(b) || 0
        root.windowBorderSize = val
        Nexa.Theme.windowBorderSize = val
        Quickshell.execDetached(["hyprctl", "eval", "hl.config({ general = { border_size = " + val + " } })"])
    }

    function setWindowGlow(on) {
        root.windowGlow = on
        Quickshell.execDetached(["hyprctl", "eval", "hl.config({ decoration = { shadow = { enabled = " + (on ? "true" : "false") + ", range = 30 } } })"])
    }

    function setWindowDim(dim) {
        root.windowDim = dim
        const enabled = dim > 0.001
        Quickshell.execDetached(["hyprctl", "eval", "hl.config({ decoration = { dim_inactive = " + (enabled ? "true" : "false") + ", dim_strength = " + dim + " } })"])
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
        command: ["sh", "-c", root.themeScript + " status"]
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
        command: ["sh", "-c", root.themeScript + " presets-json"]
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
        command: ["sh", "-c", root.nexad + " screenTemp info"]
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

            // Sub-tabs bar: Presets | Wallpaper & Material | Windows & Effects
            Rectangle {
                Layout.preferredHeight: 38
                Layout.preferredWidth: 550
                radius: Nexa.Theme.radiusSm
                color: Nexa.Theme.cardBackground
                border.width: Nexa.Theme.borderThin
                border.color: Nexa.Theme.border

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 3
                    spacing: 3

                    Repeater {
                        model: [
                            { id: "presets", label: "Presets", icon: "󰏘" },
                            { id: "wallpaper", label: "Wallpaper & Material", icon: "󰸉" },
                            { id: "windows", label: "Windows & Effects", icon: "󰍹" },
                            { id: "shapes", label: "Shapes", icon: "󰏤" }
                        ]

                        Rectangle {
                            id: tabPill
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: Nexa.Theme.radiusXs

                            readonly property bool isSelected: root.activeSubTab === modelData.id

                            color: isSelected ? Nexa.Theme.primaryContainer : (tabMouse.containsMouse ? Nexa.Theme.hover : "transparent")
                            border.width: isSelected ? 1 : 0
                            border.color: isSelected ? Nexa.Theme.primary : "transparent"

                            Behavior on color { ColorAnimation { duration: Nexa.Theme.animationFast } }

                            Row {
                                anchors.centerIn: parent
                                spacing: 6

                                Text {
                                    text: tabPill.modelData.icon
                                    font.family: Nexa.Theme.iconFontFamily
                                    font.pixelSize: 14
                                    color: tabPill.isSelected ? Nexa.Theme.onPrimaryContainer : Nexa.Theme.mutedText
                                }

                                Text {
                                    text: tabPill.modelData.label
                                    font.family: Nexa.Theme.fontFamily
                                    font.pixelSize: 12
                                    font.weight: tabPill.isSelected ? Nexa.Theme.fontWeightDemiBold : Nexa.Theme.fontWeightRegular
                                    color: tabPill.isSelected ? Nexa.Theme.onPrimaryContainer : Nexa.Theme.text
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
                radius: Nexa.Theme.radiusSm
                color: Nexa.Theme.cardBackground
                border.width: Nexa.Theme.borderThin
                border.color: Nexa.Theme.border

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 3
                    spacing: 3

                    // Dark Pill
                    Rectangle {
                        id: topDarkPill
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: Nexa.Theme.radiusXs
                        readonly property bool isSelected: root.stagedMode === "dark"
                        color: isSelected ? Nexa.Theme.primaryContainer : (topDarkHov.containsMouse ? Nexa.Theme.hover : "transparent")
                        border.width: isSelected ? 1 : 0
                        border.color: isSelected ? Nexa.Theme.primary : "transparent"

                        Row {
                            anchors.centerIn: parent
                            spacing: 5
                            Text {
                                text: "󰖔"
                                font.family: Nexa.Theme.iconFontFamily
                                font.pixelSize: 13
                                color: topDarkPill.isSelected ? Nexa.Theme.onPrimaryContainer : Nexa.Theme.mutedText
                            }
                            Text {
                                text: "Dark"
                                font.family: Nexa.Theme.fontFamily
                                font.pixelSize: 12
                                font.weight: topDarkPill.isSelected ? Nexa.Theme.fontWeightDemiBold : Nexa.Theme.fontWeightRegular
                                color: topDarkPill.isSelected ? Nexa.Theme.onPrimaryContainer : Nexa.Theme.text
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
                        radius: Nexa.Theme.radiusXs
                        readonly property bool isSelected: root.stagedMode === "light"
                        color: isSelected ? Nexa.Theme.primaryContainer : (topLightHov.containsMouse ? Nexa.Theme.hover : "transparent")
                        border.width: isSelected ? 1 : 0
                        border.color: isSelected ? Nexa.Theme.primary : "transparent"

                        Row {
                            anchors.centerIn: parent
                            spacing: 5
                            Text {
                                text: "󰖙"
                                font.family: Nexa.Theme.iconFontFamily
                                font.pixelSize: 13
                                color: topLightPill.isSelected ? Nexa.Theme.onPrimaryContainer : Nexa.Theme.mutedText
                            }
                            Text {
                                text: "Light"
                                font.family: Nexa.Theme.fontFamily
                                font.pixelSize: 12
                                font.weight: topLightPill.isSelected ? Nexa.Theme.fontWeightDemiBold : Nexa.Theme.fontWeightRegular
                                color: topLightPill.isSelected ? Nexa.Theme.onPrimaryContainer : Nexa.Theme.text
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
                isGlassMode: Nexa.Theme.glassMode

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
                windowBorderSize: root.windowBorderSize
                windowGlow: root.windowGlow
                windowDim: root.windowDim

                onSetRoundingRequested: r => root.setRounding(r)
                onSetBorderSizeRequested: b => root.setBorderSize(b)
                onSetWindowGlowRequested: g => root.setWindowGlow(g)
                onSetWindowDimRequested: d => root.setWindowDim(d)
            }

            // 4. Shapes View
            ThemeViews.ShapesTab {
                anchors.fill: parent
                visible: root.activeSubTab === "shapes"

                windowRounding: root.windowRounding
                windowBorderSize: root.windowBorderSize

                onSetRoundingRequested: r => root.setRounding(r)
                onSetBorderSizeRequested: b => root.setBorderSize(b)
            }
        }
    }
}
