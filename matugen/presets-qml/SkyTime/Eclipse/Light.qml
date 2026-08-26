import QtQuick
QtObject {
    // Primary
    readonly property color primary: "#a5731d"
    readonly property color on_primary: "#ffffff"
    readonly property color primaryContainer: "#f4e6cd"
    readonly property color on_primary_container: "#493208"

    // Secondary
    readonly property color secondary: "#274e9b"
    readonly property color on_secondary: "#ffffff"
    readonly property color secondaryContainer: "#d0dbf1"
    readonly property color on_secondary_container: "#0a1f47"

    // Tertiary
    readonly property color tertiary: "#74279b"
    readonly property color on_tertiary: "#ffffff"
    readonly property color tertiaryContainer: "#e6d0f1"
    readonly property color on_tertiary_container: "#330a47"

    // Background
    readonly property color background: "#f8f8f6"
    readonly property color on_background: "#262117"

    // Surface hierarchy
    readonly property color surface: "#f8f8f6"
    readonly property color surfaceDim: "#e7e2da"
    readonly property color surfaceBright: "#fdfdfc"
    readonly property color surfaceContainerLowest: "#ffffff"
    readonly property color surfaceContainerLow: "#f2f0ed"
    readonly property color surfaceContainer: "#ece9e4"
    readonly property color surfaceContainerHigh: "#e4dfd8"
    readonly property color surfaceContainerHighest: "#dcd6cb"

    // Surface content
    readonly property color on_surface: "#262117"
    readonly property color on_surface_variant: "#5e5545"
    readonly property color inverseSurface: "#353027"
    readonly property color inverse_on_surface: "#f3f1ed"
    readonly property color inversePrimary: "#efcc8f"

    // Outline and overlays
    readonly property color outline: "#9d917b"
    readonly property color outlineVariant: "#d5cec3"
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
