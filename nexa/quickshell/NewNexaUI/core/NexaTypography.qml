pragma Singleton
import QtQuick

QtObject {
    id: root

    // ============================================================
    // FONT FAMILIES
    // ============================================================
    readonly property string familyBody: "Inter, sans-serif"
    readonly property string familyDisplay: "Outfit, Inter, sans-serif"
    readonly property string familyRounded: "Comfortaa, sans-serif"
    readonly property string familyMono: "JetBrains Mono, monospace"
    readonly property string familyIcon: "Symbols Nerd Font Mono"

    // Tabular numbers font feature map for clock/timer alignment
    readonly property var fontFeaturesTnum: ({ "tnum": 1 })

    // ============================================================
    // FLUID FONT SCALE
    // ============================================================
    property real fontScale: 1.0

    // Fluid Scaled Pixel Sizes
    readonly property int size2Xs: Math.round(9 * fontScale)
    readonly property int sizeXs: Math.round(10 * fontScale)
    readonly property int sizeSm: Math.round(12 * fontScale)
    readonly property int sizeMd: Math.round(14 * fontScale)
    readonly property int sizeLg: Math.round(16 * fontScale)
    readonly property int sizeXl: Math.round(18 * fontScale)
    readonly property int size2Xl: Math.round(20 * fontScale)
    readonly property int sizeTitle: Math.round(24 * fontScale)
    readonly property int sizeDisplay: Math.round(32 * fontScale)

    // ============================================================
    // FONT WEIGHTS
    // ============================================================
    readonly property int weightLight: Font.Light
    readonly property int weightNormal: Font.Normal
    readonly property int weightRegular: Font.Normal
    readonly property int weightMedium: Font.Medium
    readonly property int weightSemiBold: Font.DemiBold
    readonly property int weightBold: Font.Bold

    function setFontScale(newScale) {
        root.fontScale = Math.max(0.7, Math.min(1.6, newScale));
    }
}
