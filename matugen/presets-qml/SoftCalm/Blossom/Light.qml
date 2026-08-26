import QtQuick
QtObject {
    // Primary
    readonly property color primary: "#a51d3f"
    readonly property color on_primary: "#ffffff"
    readonly property color primaryContainer: "#f4cdd6"
    readonly property color on_primary_container: "#490818"

    // Secondary
    readonly property color secondary: "#88279b"
    readonly property color on_secondary: "#ffffff"
    readonly property color secondaryContainer: "#ecd0f1"
    readonly property color on_secondary_container: "#3d0a47"

    // Tertiary
    readonly property color tertiary: "#4e9b27"
    readonly property color on_tertiary: "#ffffff"
    readonly property color tertiaryContainer: "#dbf1d0"
    readonly property color on_tertiary_container: "#1f470a"

    // Background
    readonly property color background: "#f8f6f7"
    readonly property color on_background: "#26171b"

    // Surface hierarchy
    readonly property color surface: "#f8f6f7"
    readonly property color surfaceDim: "#e7dadd"
    readonly property color surfaceBright: "#fdfcfc"
    readonly property color surfaceContainerLowest: "#ffffff"
    readonly property color surfaceContainerLow: "#f2edee"
    readonly property color surfaceContainer: "#ece4e6"
    readonly property color surfaceContainerHigh: "#e4d8db"
    readonly property color surfaceContainerHighest: "#dccbd0"

    // Surface content
    readonly property color on_surface: "#26171b"
    readonly property color on_surface_variant: "#5e454b"
    readonly property color inverseSurface: "#35272a"
    readonly property color inverse_on_surface: "#f3edee"
    readonly property color inversePrimary: "#ef8fa7"

    // Outline and overlays
    readonly property color outline: "#9d7b84"
    readonly property color outlineVariant: "#d5c3c7"
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
