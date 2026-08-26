import QtQuick
QtObject {
    // Primary
    readonly property color primary: "#991da5"
    readonly property color on_primary: "#ffffff"
    readonly property color primaryContainer: "#f1cdf4"
    readonly property color on_primary_container: "#440849"

    // Secondary
    readonly property color secondary: "#274e9b"
    readonly property color on_secondary: "#ffffff"
    readonly property color secondaryContainer: "#d0dbf1"
    readonly property color on_secondary_container: "#0a1f47"

    // Tertiary
    readonly property color tertiary: "#9b274e"
    readonly property color on_tertiary: "#ffffff"
    readonly property color tertiaryContainer: "#f1d0db"
    readonly property color on_tertiary_container: "#470a1f"

    // Background
    readonly property color background: "#f8f6f8"
    readonly property color on_background: "#251726"

    // Surface hierarchy
    readonly property color surface: "#f8f6f8"
    readonly property color surfaceDim: "#e6dae7"
    readonly property color surfaceBright: "#fdfcfd"
    readonly property color surfaceContainerLowest: "#ffffff"
    readonly property color surfaceContainerLow: "#f2edf2"
    readonly property color surfaceContainer: "#ebe4ec"
    readonly property color surfaceContainerHigh: "#e3d8e4"
    readonly property color surfaceContainerHighest: "#dbcbdc"

    // Surface content
    readonly property color on_surface: "#251726"
    readonly property color on_surface_variant: "#5c455e"
    readonly property color inverseSurface: "#342735"
    readonly property color inverse_on_surface: "#f2edf3"
    readonly property color inversePrimary: "#e78fef"

    // Outline and overlays
    readonly property color outline: "#9b7b9d"
    readonly property color outlineVariant: "#d4c3d5"
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
