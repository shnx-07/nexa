import QtQuick
QtObject {
    // Primary
    readonly property color primary: "#a51d8e"
    readonly property color on_primary: "#ffffff"
    readonly property color primaryContainer: "#f4cdee"
    readonly property color on_primary_container: "#49083f"

    // Secondary
    readonly property color secondary: "#4e279b"
    readonly property color on_secondary: "#ffffff"
    readonly property color secondaryContainer: "#dbd0f1"
    readonly property color on_secondary_container: "#1f0a47"

    // Tertiary
    readonly property color tertiary: "#27889b"
    readonly property color on_tertiary: "#ffffff"
    readonly property color tertiaryContainer: "#d0ecf1"
    readonly property color on_tertiary_container: "#0a3d47"

    // Background
    readonly property color background: "#f8f6f8"
    readonly property color on_background: "#261724"

    // Surface hierarchy
    readonly property color surface: "#f8f6f8"
    readonly property color surfaceDim: "#e7dae4"
    readonly property color surfaceBright: "#fdfcfd"
    readonly property color surfaceContainerLowest: "#ffffff"
    readonly property color surfaceContainerLow: "#f2edf1"
    readonly property color surfaceContainer: "#ece4eb"
    readonly property color surfaceContainerHigh: "#e4d8e2"
    readonly property color surfaceContainerHighest: "#dccbd9"

    // Surface content
    readonly property color on_surface: "#261724"
    readonly property color on_surface_variant: "#5e455a"
    readonly property color inverseSurface: "#352732"
    readonly property color inverse_on_surface: "#f3edf2"
    readonly property color inversePrimary: "#ef8fdf"

    // Outline and overlays
    readonly property color outline: "#9d7b98"
    readonly property color outlineVariant: "#d5c3d2"
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
