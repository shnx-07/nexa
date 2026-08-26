import QtQuick
QtObject {
    // Primary
    readonly property color primary: "#a51d78"
    readonly property color on_primary: "#ffffff"
    readonly property color primaryContainer: "#f4cde7"
    readonly property color on_primary_container: "#490834"

    // Secondary
    readonly property color secondary: "#277e9b"
    readonly property color on_secondary: "#ffffff"
    readonly property color secondaryContainer: "#d0e9f1"
    readonly property color on_secondary_container: "#0a3847"

    // Tertiary
    readonly property color tertiary: "#9b7e27"
    readonly property color on_tertiary: "#ffffff"
    readonly property color tertiaryContainer: "#f1e9d0"
    readonly property color on_tertiary_container: "#47380a"

    // Background
    readonly property color background: "#f8f6f8"
    readonly property color on_background: "#261721"

    // Surface hierarchy
    readonly property color surface: "#f8f6f8"
    readonly property color surfaceDim: "#e7dae2"
    readonly property color surfaceBright: "#fdfcfd"
    readonly property color surfaceContainerLowest: "#ffffff"
    readonly property color surfaceContainerLow: "#f2edf1"
    readonly property color surfaceContainer: "#ece4e9"
    readonly property color surfaceContainerHigh: "#e4d8e0"
    readonly property color surfaceContainerHighest: "#dccbd6"

    // Surface content
    readonly property color on_surface: "#261721"
    readonly property color on_surface_variant: "#5e4556"
    readonly property color inverseSurface: "#352730"
    readonly property color inverse_on_surface: "#f3edf1"
    readonly property color inversePrimary: "#ef8fcf"

    // Outline and overlays
    readonly property color outline: "#9d7b92"
    readonly property color outlineVariant: "#d5c3cf"
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
