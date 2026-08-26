import QtQuick
QtObject {
    // Primary
    readonly property color primary: "#781da5"
    readonly property color on_primary: "#ffffff"
    readonly property color primaryContainer: "#e7cdf4"
    readonly property color on_primary_container: "#340849"

    // Secondary
    readonly property color secondary: "#27749b"
    readonly property color on_secondary: "#ffffff"
    readonly property color secondaryContainer: "#d0e6f1"
    readonly property color on_secondary_container: "#0a3347"

    // Tertiary
    readonly property color tertiary: "#9b2774"
    readonly property color on_tertiary: "#ffffff"
    readonly property color tertiaryContainer: "#f1d0e6"
    readonly property color on_tertiary_container: "#470a33"

    // Background
    readonly property color background: "#f8f6f8"
    readonly property color on_background: "#211726"

    // Surface hierarchy
    readonly property color surface: "#f8f6f8"
    readonly property color surfaceDim: "#e2dae7"
    readonly property color surfaceBright: "#fdfcfd"
    readonly property color surfaceContainerLowest: "#ffffff"
    readonly property color surfaceContainerLow: "#f1edf2"
    readonly property color surfaceContainer: "#e9e4ec"
    readonly property color surfaceContainerHigh: "#e0d8e4"
    readonly property color surfaceContainerHighest: "#d6cbdc"

    // Surface content
    readonly property color on_surface: "#211726"
    readonly property color on_surface_variant: "#56455e"
    readonly property color inverseSurface: "#302735"
    readonly property color inverse_on_surface: "#f1edf3"
    readonly property color inversePrimary: "#cf8fef"

    // Outline and overlays
    readonly property color outline: "#927b9d"
    readonly property color outlineVariant: "#cfc3d5"
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
