pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    // ============================================================
    // SYSTEM BINARIES & PATHS
    // ============================================================
    readonly property string nexadBin: Quickshell.env("HOME") + "/.config/nexa/rust/target/release/nexad"

    // ============================================================
    // CORNER RADII (Dynamically watched from shapes.json & island.json)
    // ============================================================
    property int windowRounding: 10
    property int nexaRounding: 14
    property int islandRounding: 14
    property int windowBorderSize: 0
    property bool windowGlow: true
    property real windowDim: 0.0

    readonly property int radiusXs: root.nexaRounding === 0 ? 0 : 4
    readonly property int radiusSm: root.nexaRounding === 0 ? 0 : Math.max(4, Math.round(root.nexaRounding * 0.55))
    readonly property int radiusMd: root.nexaRounding === 0 ? 0 : Math.max(6, Math.round(root.nexaRounding * 0.85))
    readonly property int radiusLg: root.nexaRounding
    readonly property int radiusXl: root.nexaRounding === 0 ? 0 : Math.max(16, Math.round(root.nexaRounding * 1.5))
    readonly property int radius2Xl: root.nexaRounding === 0 ? 0 : Math.max(20, Math.round(root.nexaRounding * 2.0))
    readonly property int radiusPill: root.nexaRounding === 0 ? 0 : 9999

    function setIslandRounding(val) {
        root.islandRounding = val
        const cfg = { "rounding": val }
        const json = JSON.stringify(cfg, null, 2)
        Quickshell.execDetached([
            "sh", "-c",
            'mkdir -p "$HOME/.config/nexa/config" && printf "%s" "$1" > "$HOME/.config/nexa/config/island.json"',
            "_", json
        ])
    }

    function saveDecorations(winRound, nexaRound, border, glow, dim) {
        if (winRound !== undefined) root.windowRounding = winRound
        if (nexaRound !== undefined) root.nexaRounding = nexaRound
        if (border !== undefined) root.windowBorderSize = border
        if (glow !== undefined) root.windowGlow = glow
        if (dim !== undefined) root.windowDim = dim

        let existing = {}
        try {
            existing = JSON.parse(root._shapesWatcher.text() || "{}")
        } catch (e) {}

        existing.rounding = root.windowRounding
        existing.nexa_rounding = root.nexaRounding
        existing.border_size = root.windowBorderSize
        existing.shadow_enabled = root.windowGlow
        existing.dim_strength = root.windowDim

        const json = JSON.stringify(existing, null, 2)
        Quickshell.execDetached([
            "sh", "-c",
            'mkdir -p "$HOME/.config/nexa/config" && printf "%s" "$1" > "$HOME/.config/nexa/config/shapes.json" && "$2" hypr decorations set --rounding "$3" --border "$4" --nexa-rounding "$5"',
            "sh", json,
            Quickshell.env("HOME") + "/.config/nexa/rust/target/release/nexad",
            root.windowRounding.toString(),
            root.windowBorderSize.toString(),
            root.nexaRounding.toString()
        ])
    }

    property FileView _shapesWatcher: FileView {
        path: Quickshell.env("HOME") + "/.config/nexa/config/shapes.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const data = JSON.parse(text())
                if (data) {
                    if (data.rounding !== undefined) root.windowRounding = data.rounding
                    if (data.nexa_rounding !== undefined) root.nexaRounding = data.nexa_rounding
                    else if (data.rounding !== undefined) root.nexaRounding = data.rounding
                    if (data.border_size !== undefined) root.windowBorderSize = data.border_size
                    if (data.shadow_enabled !== undefined) root.windowGlow = data.shadow_enabled
                    if (data.dim_strength !== undefined) root.windowDim = data.dim_strength
                }
            } catch (e) {}
        }
    }

    property FileView _islandWatcher: FileView {
        path: Quickshell.env("HOME") + "/.config/nexa/config/island.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const data = JSON.parse(text())
                if (data && data.rounding !== undefined) root.islandRounding = data.rounding
            } catch (e) {}
        }
    }

    // ============================================================
    // SPACING SCALE (8pt Grid System)
    // ============================================================
    readonly property int spacing2Xs: 2
    readonly property int spacingXs: 4
    readonly property int spacingSm: 8
    readonly property int spacingMd: 12
    readonly property int spacingLg: 16
    readonly property int spacingXl: 24
    readonly property int spacing2Xl: 32

    // ============================================================
    // CONTROL SIZES
    // ============================================================
    readonly property int controlHeightXs: 24
    readonly property int controlHeightSm: 28
    readonly property int controlHeightMd: 36
    readonly property int controlHeightLg: 44
    readonly property int indicatorWidth: 18
    readonly property int indicatorHeight: 3
    readonly property int iconXs: 12
    readonly property int iconSm: 14
    readonly property int iconMd: 16
    readonly property int iconLg: 20
    readonly property real opacityFull: 1.0
    readonly property real opacityDisabled: 0.38

    // ============================================================
    // BORDER WIDTHS
    // ============================================================
    readonly property int borderThin: 1
    readonly property int borderMedium: 2
    readonly property int borderThick: 3

    // ============================================================
    // ISLAND GEOMETRY SCALE
    // ============================================================
    readonly property int barHeight: 44
    readonly property int islandCompactHeight: 28
    readonly property int islandCompactWidth: 170
    readonly property int islandExpandedWidth: 420
    readonly property int islandExpandedMinHeight: 120

    // ============================================================
    // ELEVATION LEVELS
    // ============================================================
    readonly property int elevation0: 0
    readonly property int elevation1: 1
    readonly property int elevation2: 2
    readonly property int elevation3: 3
    readonly property int elevation4: 4
}
