import QtQuick
QtObject {
    // Primary
    readonly property color primary: "#561da5"
    readonly property color on_primary: "#ffffff"
    readonly property color primaryContainer: "#ddcdf4"
    readonly property color on_primary_container: "#230849"

    // Secondary
    readonly property color secondary: "#88279b"
    readonly property color on_secondary: "#ffffff"
    readonly property color secondaryContainer: "#ecd0f1"
    readonly property color on_secondary_container: "#3d0a47"

    // Tertiary
    readonly property color tertiary: "#273a9b"
    readonly property color on_tertiary: "#ffffff"
    readonly property color tertiaryContainer: "#d0d5f1"
    readonly property color on_tertiary_container: "#0a1447"

    // Background
    readonly property color background: "#f7f6f8"
    readonly property color on_background: "#1d1726"

    // Surface hierarchy
    readonly property color surface: "#f7f6f8"
    readonly property color surfaceDim: "#dfdae7"
    readonly property color surfaceBright: "#fcfcfd"
    readonly property color surfaceContainerLowest: "#ffffff"
    readonly property color surfaceContainerLow: "#efedf2"
    readonly property color surfaceContainer: "#e7e4ec"
    readonly property color surfaceContainerHigh: "#ddd8e4"
    readonly property color surfaceContainerHighest: "#d2cbdc"

    // Surface content
    readonly property color on_surface: "#1d1726"
    readonly property color on_surface_variant: "#50455e"
    readonly property color inverseSurface: "#2d2735"
    readonly property color inverse_on_surface: "#efedf3"
    readonly property color inversePrimary: "#b78fef"

    // Outline and overlays
    readonly property color outline: "#897b9d"
    readonly property color outlineVariant: "#cac3d5"
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
