import QtQuick
QtObject {
    // Primary
    readonly property color primary: "#28a51d"
    readonly property color on_primary: "#ffffff"
    readonly property color primaryContainer: "#d0f4cd"
    readonly property color on_primary_container: "#0e4908"

    // Secondary
    readonly property color secondary: "#6b9b27"
    readonly property color on_secondary: "#ffffff"
    readonly property color secondaryContainer: "#e3f1d0"
    readonly property color on_secondary_container: "#2e470a"

    // Tertiary
    readonly property color tertiary: "#9b7e27"
    readonly property color on_tertiary: "#ffffff"
    readonly property color tertiaryContainer: "#f1e9d0"
    readonly property color on_tertiary_container: "#47380a"

    // Background
    readonly property color background: "#f6f8f6"
    readonly property color on_background: "#182617"

    // Surface hierarchy
    readonly property color surface: "#f6f8f6"
    readonly property color surfaceDim: "#dbe7da"
    readonly property color surfaceBright: "#fcfdfc"
    readonly property color surfaceContainerLowest: "#ffffff"
    readonly property color surfaceContainerLow: "#eef2ed"
    readonly property color surfaceContainer: "#e5ece4"
    readonly property color surfaceContainerHigh: "#d9e4d8"
    readonly property color surfaceContainerHighest: "#cddccb"

    // Surface content
    readonly property color on_surface: "#182617"
    readonly property color on_surface_variant: "#475e45"
    readonly property color inverseSurface: "#283527"
    readonly property color inverse_on_surface: "#edf3ed"
    readonly property color inversePrimary: "#97ef8f"

    // Outline and overlays
    readonly property color outline: "#7e9d7b"
    readonly property color outlineVariant: "#c4d5c3"
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
