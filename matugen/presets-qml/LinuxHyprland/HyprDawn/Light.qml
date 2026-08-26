import QtQuick
QtObject {
    // Primary
    readonly property color primary: "#1da599"
    readonly property color on_primary: "#ffffff"
    readonly property color primaryContainer: "#cdf4f1"
    readonly property color on_primary_container: "#084944"

    // Secondary
    readonly property color secondary: "#27579b"
    readonly property color on_secondary: "#ffffff"
    readonly property color secondaryContainer: "#d0def1"
    readonly property color on_secondary_container: "#0a2447"

    // Tertiary
    readonly property color tertiary: "#9b274e"
    readonly property color on_tertiary: "#ffffff"
    readonly property color tertiaryContainer: "#f1d0db"
    readonly property color on_tertiary_container: "#470a1f"

    // Background
    readonly property color background: "#f6f8f8"
    readonly property color on_background: "#172625"

    // Surface hierarchy
    readonly property color surface: "#f6f8f8"
    readonly property color surfaceDim: "#dae7e6"
    readonly property color surfaceBright: "#fcfdfd"
    readonly property color surfaceContainerLowest: "#ffffff"
    readonly property color surfaceContainerLow: "#edf2f2"
    readonly property color surfaceContainer: "#e4eceb"
    readonly property color surfaceContainerHigh: "#d8e4e3"
    readonly property color surfaceContainerHighest: "#cbdcdb"

    // Surface content
    readonly property color on_surface: "#172625"
    readonly property color on_surface_variant: "#455e5c"
    readonly property color inverseSurface: "#273534"
    readonly property color inverse_on_surface: "#edf3f2"
    readonly property color inversePrimary: "#8fefe7"

    // Outline and overlays
    readonly property color outline: "#7b9d9b"
    readonly property color outlineVariant: "#c3d5d4"
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
