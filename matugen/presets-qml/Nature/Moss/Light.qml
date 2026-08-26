import QtQuick
QtObject {
    // Primary
    readonly property color primary: "#56a51d"
    readonly property color on_primary: "#ffffff"
    readonly property color primaryContainer: "#ddf4cd"
    readonly property color on_primary_container: "#234908"

    // Secondary
    readonly property color secondary: "#279b3a"
    readonly property color on_secondary: "#ffffff"
    readonly property color secondaryContainer: "#d0f1d5"
    readonly property color on_secondary_container: "#0a4714"

    // Tertiary
    readonly property color tertiary: "#889b27"
    readonly property color on_tertiary: "#ffffff"
    readonly property color tertiaryContainer: "#ecf1d0"
    readonly property color on_tertiary_container: "#3d470a"

    // Background
    readonly property color background: "#f7f8f6"
    readonly property color on_background: "#1d2617"

    // Surface hierarchy
    readonly property color surface: "#f7f8f6"
    readonly property color surfaceDim: "#dfe7da"
    readonly property color surfaceBright: "#fcfdfc"
    readonly property color surfaceContainerLowest: "#ffffff"
    readonly property color surfaceContainerLow: "#eff2ed"
    readonly property color surfaceContainer: "#e7ece4"
    readonly property color surfaceContainerHigh: "#dde4d8"
    readonly property color surfaceContainerHighest: "#d2dccb"

    // Surface content
    readonly property color on_surface: "#1d2617"
    readonly property color on_surface_variant: "#505e45"
    readonly property color inverseSurface: "#2d3527"
    readonly property color inverse_on_surface: "#eff3ed"
    readonly property color inversePrimary: "#b7ef8f"

    // Outline and overlays
    readonly property color outline: "#899d7b"
    readonly property color outlineVariant: "#cad5c3"
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
