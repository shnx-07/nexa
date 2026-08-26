import QtQuick
QtObject {
    // Primary
    readonly property color primary: "#61a51d"
    readonly property color on_primary: "#ffffff"
    readonly property color primaryContainer: "#e0f4cd"
    readonly property color on_primary_container: "#294908"

    // Secondary
    readonly property color secondary: "#9b7427"
    readonly property color on_secondary: "#ffffff"
    readonly property color secondaryContainer: "#f1e6d0"
    readonly property color on_secondary_container: "#47330a"

    // Tertiary
    readonly property color tertiary: "#27749b"
    readonly property color on_tertiary: "#ffffff"
    readonly property color tertiaryContainer: "#d0e6f1"
    readonly property color on_tertiary_container: "#0a3347"

    // Background
    readonly property color background: "#f7f8f6"
    readonly property color on_background: "#1f2617"

    // Surface hierarchy
    readonly property color surface: "#f7f8f6"
    readonly property color surfaceDim: "#e0e7da"
    readonly property color surfaceBright: "#fcfdfc"
    readonly property color surfaceContainerLowest: "#ffffff"
    readonly property color surfaceContainerLow: "#f0f2ed"
    readonly property color surfaceContainer: "#e8ece4"
    readonly property color surfaceContainerHigh: "#dee4d8"
    readonly property color surfaceContainerHighest: "#d4dccb"

    // Surface content
    readonly property color on_surface: "#1f2617"
    readonly property color on_surface_variant: "#525e45"
    readonly property color inverseSurface: "#2e3527"
    readonly property color inverse_on_surface: "#f0f3ed"
    readonly property color inversePrimary: "#bfef8f"

    // Outline and overlays
    readonly property color outline: "#8c9d7b"
    readonly property color outlineVariant: "#ccd5c3"
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
