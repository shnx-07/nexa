import QtQuick
QtObject {
    // Primary
    readonly property color primary: "#1da583"
    readonly property color on_primary: "#ffffff"
    readonly property color primaryContainer: "#cdf4ea"
    readonly property color on_primary_container: "#084939"

    // Secondary
    readonly property color secondary: "#27889b"
    readonly property color on_secondary: "#ffffff"
    readonly property color secondaryContainer: "#d0ecf1"
    readonly property color on_secondary_container: "#0a3d47"

    // Tertiary
    readonly property color tertiary: "#9b6b27"
    readonly property color on_tertiary: "#ffffff"
    readonly property color tertiaryContainer: "#f1e3d0"
    readonly property color on_tertiary_container: "#472e0a"

    // Background
    readonly property color background: "#f6f8f8"
    readonly property color on_background: "#172622"

    // Surface hierarchy
    readonly property color surface: "#f6f8f8"
    readonly property color surfaceDim: "#dae7e3"
    readonly property color surfaceBright: "#fcfdfd"
    readonly property color surfaceContainerLowest: "#ffffff"
    readonly property color surfaceContainerLow: "#edf2f1"
    readonly property color surfaceContainer: "#e4ecea"
    readonly property color surfaceContainerHigh: "#d8e4e1"
    readonly property color surfaceContainerHighest: "#cbdcd8"

    // Surface content
    readonly property color on_surface: "#172622"
    readonly property color on_surface_variant: "#455e58"
    readonly property color inverseSurface: "#273531"
    readonly property color inverse_on_surface: "#edf3f1"
    readonly property color inversePrimary: "#8fefd7"

    // Outline and overlays
    readonly property color outline: "#7b9d95"
    readonly property color outlineVariant: "#c3d5d1"
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
