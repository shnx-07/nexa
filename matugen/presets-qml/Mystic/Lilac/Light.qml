import QtQuick
QtObject {
    // Primary
    readonly property color primary: "#831da5"
    readonly property color on_primary: "#ffffff"
    readonly property color primaryContainer: "#eacdf4"
    readonly property color on_primary_container: "#390849"

    // Secondary
    readonly property color secondary: "#9b276b"
    readonly property color on_secondary: "#ffffff"
    readonly property color secondaryContainer: "#f1d0e3"
    readonly property color on_secondary_container: "#470a2e"

    // Tertiary
    readonly property color tertiary: "#274e9b"
    readonly property color on_tertiary: "#ffffff"
    readonly property color tertiaryContainer: "#d0dbf1"
    readonly property color on_tertiary_container: "#0a1f47"

    // Background
    readonly property color background: "#f8f6f8"
    readonly property color on_background: "#221726"

    // Surface hierarchy
    readonly property color surface: "#f8f6f8"
    readonly property color surfaceDim: "#e3dae7"
    readonly property color surfaceBright: "#fdfcfd"
    readonly property color surfaceContainerLowest: "#ffffff"
    readonly property color surfaceContainerLow: "#f1edf2"
    readonly property color surfaceContainer: "#eae4ec"
    readonly property color surfaceContainerHigh: "#e1d8e4"
    readonly property color surfaceContainerHighest: "#d8cbdc"

    // Surface content
    readonly property color on_surface: "#221726"
    readonly property color on_surface_variant: "#58455e"
    readonly property color inverseSurface: "#312735"
    readonly property color inverse_on_surface: "#f1edf3"
    readonly property color inversePrimary: "#d78fef"

    // Outline and overlays
    readonly property color outline: "#957b9d"
    readonly property color outlineVariant: "#d1c3d5"
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
