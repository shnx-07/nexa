import QtQuick
QtObject {
    // Primary
    readonly property color primary: "#1da578"
    readonly property color on_primary: "#ffffff"
    readonly property color primaryContainer: "#cdf4e7"
    readonly property color on_primary_container: "#084934"

    // Secondary
    readonly property color secondary: "#9b6b27"
    readonly property color on_secondary: "#ffffff"
    readonly property color secondaryContainer: "#f1e3d0"
    readonly property color on_secondary_container: "#472e0a"

    // Tertiary
    readonly property color tertiary: "#74279b"
    readonly property color on_tertiary: "#ffffff"
    readonly property color tertiaryContainer: "#e6d0f1"
    readonly property color on_tertiary_container: "#330a47"

    // Background
    readonly property color background: "#f6f8f8"
    readonly property color on_background: "#172621"

    // Surface hierarchy
    readonly property color surface: "#f6f8f8"
    readonly property color surfaceDim: "#dae7e2"
    readonly property color surfaceBright: "#fcfdfd"
    readonly property color surfaceContainerLowest: "#ffffff"
    readonly property color surfaceContainerLow: "#edf2f1"
    readonly property color surfaceContainer: "#e4ece9"
    readonly property color surfaceContainerHigh: "#d8e4e0"
    readonly property color surfaceContainerHighest: "#cbdcd6"

    // Surface content
    readonly property color on_surface: "#172621"
    readonly property color on_surface_variant: "#455e56"
    readonly property color inverseSurface: "#273530"
    readonly property color inverse_on_surface: "#edf3f1"
    readonly property color inversePrimary: "#8fefcf"

    // Outline and overlays
    readonly property color outline: "#7b9d92"
    readonly property color outlineVariant: "#c3d5cf"
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
