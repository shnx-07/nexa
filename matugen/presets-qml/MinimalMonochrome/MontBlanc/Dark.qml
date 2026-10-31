import QtQuick
QtObject {
    // Primary
    readonly property color primary: "#ffffff"
    readonly property color on_primary: "#000000"
    readonly property color primaryContainer: "#242424"
    readonly property color on_primary_container: "#ffffff"

    // Secondary
    readonly property color secondary: "#d6d6d6"
    readonly property color on_secondary: "#111111"
    readonly property color secondaryContainer: "#1f1f1f"
    readonly property color on_secondary_container: "#e0e0e0"

    // Tertiary
    readonly property color tertiary: "#8a8a8a"
    readonly property color on_tertiary: "#000000"
    readonly property color tertiaryContainer: "#181818"
    readonly property color on_tertiary_container: "#cccccc"

    // Background
    readonly property color background: "#0a0a0a"
    readonly property color on_background: "#f0f0f0"

    // Surface hierarchy
    readonly property color surface: "#0a0a0a"
    readonly property color surfaceDim: "#050505"
    readonly property color surfaceBright: "#222222"
    readonly property color surfaceContainerLowest: "#000000"
    readonly property color surfaceContainerLow: "#0d0d0d"
    readonly property color surfaceContainer: "#141414"
    readonly property color surfaceContainerHigh: "#1c1c1c"
    readonly property color surfaceContainerHighest: "#282828"

    // Surface content
    readonly property color on_surface: "#f0f0f0"
    readonly property color on_surface_variant: "#a6a6a6"
    readonly property color inverseSurface: "#f0f0f0"
    readonly property color inverse_on_surface: "#0a0a0a"
    readonly property color inversePrimary: "#555555"

    // Outline and overlays
    readonly property color outline: "#484848"
    readonly property color outlineVariant: "#222222"
    readonly property color shadow: "#000000"
    readonly property color scrim: "#000000"

    // Error
    readonly property color error: "#ff5555"
    readonly property color on_error: "#220000"
    readonly property color errorContainer: "#441111"
    readonly property color on_error_container: "#ff9999"

    // Success
    readonly property color success: "#55ff99"
    readonly property color on_success: "#002211"
    readonly property color successContainer: "#114422"
    readonly property color on_success_container: "#99ffbb"

    // Warning
    readonly property color warning: "#ffbb33"
    readonly property color on_warning: "#332200"
    readonly property color warningContainer: "#443311"
    readonly property color on_warning_container: "#ffdd88"

    // Info
    readonly property color info: "#77bbff"
    readonly property color on_info: "#002244"
    readonly property color infoContainer: "#113355"
    readonly property color on_info_container: "#aaddff"

    // Compatibility aliases
    readonly property color text: on_background
}

