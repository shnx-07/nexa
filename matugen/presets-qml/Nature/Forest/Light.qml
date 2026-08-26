import QtQuick
QtObject {
    // Primary
    readonly property color primary: "#1da54a"
    readonly property color on_primary: "#ffffff"
    readonly property color primaryContainer: "#cdf4da"
    readonly property color on_primary_container: "#08491e"

    // Secondary
    readonly property color secondary: "#9b6127"
    readonly property color on_secondary: "#ffffff"
    readonly property color secondaryContainer: "#f1e0d0"
    readonly property color on_secondary_container: "#47290a"

    // Tertiary
    readonly property color tertiary: "#749b27"
    readonly property color on_tertiary: "#ffffff"
    readonly property color tertiaryContainer: "#e6f1d0"
    readonly property color on_tertiary_container: "#33470a"

    // Background
    readonly property color background: "#f6f8f7"
    readonly property color on_background: "#17261c"

    // Surface hierarchy
    readonly property color surface: "#f6f8f7"
    readonly property color surfaceDim: "#dae7de"
    readonly property color surfaceBright: "#fcfdfc"
    readonly property color surfaceContainerLowest: "#ffffff"
    readonly property color surfaceContainerLow: "#edf2ef"
    readonly property color surfaceContainer: "#e4ece7"
    readonly property color surfaceContainerHigh: "#d8e4dc"
    readonly property color surfaceContainerHighest: "#cbdcd1"

    // Surface content
    readonly property color on_surface: "#17261c"
    readonly property color on_surface_variant: "#455e4e"
    readonly property color inverseSurface: "#27352c"
    readonly property color inverse_on_surface: "#edf3ef"
    readonly property color inversePrimary: "#8fefaf"

    // Outline and overlays
    readonly property color outline: "#7b9d87"
    readonly property color outlineVariant: "#c3d5c9"
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
