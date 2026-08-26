import QtQuick
QtObject {
    // Primary
    readonly property color primary: "#1d6ca5"
    readonly property color on_primary: "#ffffff"
    readonly property color primaryContainer: "#cde4f4"
    readonly property color on_primary_container: "#082e49"

    // Secondary
    readonly property color secondary: "#27449b"
    readonly property color on_secondary: "#ffffff"
    readonly property color secondaryContainer: "#d0d8f1"
    readonly property color on_secondary_container: "#0a1947"

    // Tertiary
    readonly property color tertiary: "#27889b"
    readonly property color on_tertiary: "#ffffff"
    readonly property color tertiaryContainer: "#d0ecf1"
    readonly property color on_tertiary_container: "#0a3d47"

    // Background
    readonly property color background: "#f6f8f8"
    readonly property color on_background: "#172026"

    // Surface hierarchy
    readonly property color surface: "#f6f8f8"
    readonly property color surfaceDim: "#dae1e7"
    readonly property color surfaceBright: "#fcfcfd"
    readonly property color surfaceContainerLowest: "#ffffff"
    readonly property color surfaceContainerLow: "#edf0f2"
    readonly property color surfaceContainer: "#e4e9ec"
    readonly property color surfaceContainerHigh: "#d8dfe4"
    readonly property color surfaceContainerHighest: "#cbd5dc"

    // Surface content
    readonly property color on_surface: "#172026"
    readonly property color on_surface_variant: "#45545e"
    readonly property color inverseSurface: "#272f35"
    readonly property color inverse_on_surface: "#edf0f3"
    readonly property color inversePrimary: "#8fc7ef"

    // Outline and overlays
    readonly property color outline: "#7b8f9d"
    readonly property color outlineVariant: "#c3ced5"
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
