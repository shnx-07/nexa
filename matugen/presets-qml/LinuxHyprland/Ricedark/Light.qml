import QtQuick
QtObject {
    // Primary
    readonly property color primary: "#6c1da5"
    readonly property color on_primary: "#ffffff"
    readonly property color primaryContainer: "#e4cdf4"
    readonly property color on_primary_container: "#2e0849"

    // Secondary
    readonly property color secondary: "#279b74"
    readonly property color on_secondary: "#ffffff"
    readonly property color secondaryContainer: "#d0f1e6"
    readonly property color on_secondary_container: "#0a4733"

    // Tertiary
    readonly property color tertiary: "#9b7427"
    readonly property color on_tertiary: "#ffffff"
    readonly property color tertiaryContainer: "#f1e6d0"
    readonly property color on_tertiary_container: "#47330a"

    // Background
    readonly property color background: "#f8f6f8"
    readonly property color on_background: "#201726"

    // Surface hierarchy
    readonly property color surface: "#f8f6f8"
    readonly property color surfaceDim: "#e1dae7"
    readonly property color surfaceBright: "#fcfcfd"
    readonly property color surfaceContainerLowest: "#ffffff"
    readonly property color surfaceContainerLow: "#f0edf2"
    readonly property color surfaceContainer: "#e9e4ec"
    readonly property color surfaceContainerHigh: "#dfd8e4"
    readonly property color surfaceContainerHighest: "#d5cbdc"

    // Surface content
    readonly property color on_surface: "#201726"
    readonly property color on_surface_variant: "#54455e"
    readonly property color inverseSurface: "#2f2735"
    readonly property color inverse_on_surface: "#f0edf3"
    readonly property color inversePrimary: "#c78fef"

    // Outline and overlays
    readonly property color outline: "#8f7b9d"
    readonly property color outlineVariant: "#cec3d5"
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
