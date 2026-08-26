import QtQuick
QtObject {
    // Primary
    readonly property color primary: "#1d8ea5"
    readonly property color on_primary: "#ffffff"
    readonly property color primaryContainer: "#cdeef4"
    readonly property color on_primary_container: "#083f49"

    // Secondary
    readonly property color secondary: "#6b279b"
    readonly property color on_secondary: "#ffffff"
    readonly property color secondaryContainer: "#e3d0f1"
    readonly property color on_secondary_container: "#2e0a47"

    // Tertiary
    readonly property color tertiary: "#9b2761"
    readonly property color on_tertiary: "#ffffff"
    readonly property color tertiaryContainer: "#f1d0e0"
    readonly property color on_tertiary_container: "#470a29"

    // Background
    readonly property color background: "#f6f8f8"
    readonly property color on_background: "#172426"

    // Surface hierarchy
    readonly property color surface: "#f6f8f8"
    readonly property color surfaceDim: "#dae4e7"
    readonly property color surfaceBright: "#fcfdfd"
    readonly property color surfaceContainerLowest: "#ffffff"
    readonly property color surfaceContainerLow: "#edf1f2"
    readonly property color surfaceContainer: "#e4ebec"
    readonly property color surfaceContainerHigh: "#d8e2e4"
    readonly property color surfaceContainerHighest: "#cbd9dc"

    // Surface content
    readonly property color on_surface: "#172426"
    readonly property color on_surface_variant: "#455a5e"
    readonly property color inverseSurface: "#273235"
    readonly property color inverse_on_surface: "#edf2f3"
    readonly property color inversePrimary: "#8fdfef"

    // Outline and overlays
    readonly property color outline: "#7b989d"
    readonly property color outlineVariant: "#c3d2d5"
    readonly property color shadow: "#000000"
    readonly property color scrim: "#000000"

    // Error
    readonly property color error: "#bb1b28"
    readonly property color on_error: "#ffffff"
    readonly property color errorContainer: "#f7d4d7"
    readonly property color on_error_container: "#49080e"

    // Success
    readonly property color success: "#1e8f44"
    readonly property color on_success: "#ffffff"
    readonly property color successContainer: "#d0f1db"
    readonly property color on_success_container: "#093e1b"

    // Warning
    readonly property color warning: "#aa690e"
    readonly property color on_warning: "#ffffff"
    readonly property color warningContainer: "#f7e4c9"
    readonly property color on_warning_container: "#422905"

    // Information
    readonly property color info: "#1885aa"
    readonly property color on_info: "#ffffff"
    readonly property color infoContainer: "#cdeaf4"
    readonly property color on_info_container: "#073240"
}
