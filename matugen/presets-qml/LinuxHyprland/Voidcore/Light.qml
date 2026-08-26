import QtQuick
QtObject {
    // Primary
    readonly property color primary: "#4a1da5"
    readonly property color on_primary: "#ffffff"
    readonly property color primaryContainer: "#dacdf4"
    readonly property color on_primary_container: "#1e0849"

    // Secondary
    readonly property color secondary: "#27749b"
    readonly property color on_secondary: "#ffffff"
    readonly property color secondaryContainer: "#d0e6f1"
    readonly property color on_secondary_container: "#0a3347"

    // Tertiary
    readonly property color tertiary: "#9b2788"
    readonly property color on_tertiary: "#ffffff"
    readonly property color tertiaryContainer: "#f1d0ec"
    readonly property color on_tertiary_container: "#470a3d"

    // Background
    readonly property color background: "#f7f6f8"
    readonly property color on_background: "#1c1726"

    // Surface hierarchy
    readonly property color surface: "#f7f6f8"
    readonly property color surfaceDim: "#dedae7"
    readonly property color surfaceBright: "#fcfcfd"
    readonly property color surfaceContainerLowest: "#ffffff"
    readonly property color surfaceContainerLow: "#efedf2"
    readonly property color surfaceContainer: "#e7e4ec"
    readonly property color surfaceContainerHigh: "#dcd8e4"
    readonly property color surfaceContainerHighest: "#d1cbdc"

    // Surface content
    readonly property color on_surface: "#1c1726"
    readonly property color on_surface_variant: "#4e455e"
    readonly property color inverseSurface: "#2c2735"
    readonly property color inverse_on_surface: "#efedf3"
    readonly property color inversePrimary: "#af8fef"

    // Outline and overlays
    readonly property color outline: "#877b9d"
    readonly property color outlineVariant: "#c9c3d5"
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
