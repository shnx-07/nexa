import QtQuick
QtObject {
    // Primary
    readonly property color primary: "#a51d1d"
    readonly property color on_primary: "#ffffff"
    readonly property color primaryContainer: "#f4cdcd"
    readonly property color on_primary_container: "#490808"

    // Secondary
    readonly property color secondary: "#274e9b"
    readonly property color on_secondary: "#ffffff"
    readonly property color secondaryContainer: "#d0dbf1"
    readonly property color on_secondary_container: "#0a1f47"

    // Tertiary
    readonly property color tertiary: "#279b27"
    readonly property color on_tertiary: "#ffffff"
    readonly property color tertiaryContainer: "#d0f1d0"
    readonly property color on_tertiary_container: "#0a470a"

    // Background
    readonly property color background: "#f8f6f6"
    readonly property color on_background: "#261717"

    // Surface hierarchy
    readonly property color surface: "#f8f6f6"
    readonly property color surfaceDim: "#e7dada"
    readonly property color surfaceBright: "#fdfcfc"
    readonly property color surfaceContainerLowest: "#ffffff"
    readonly property color surfaceContainerLow: "#f2eded"
    readonly property color surfaceContainer: "#ece4e4"
    readonly property color surfaceContainerHigh: "#e4d8d8"
    readonly property color surfaceContainerHighest: "#dccbcb"

    // Surface content
    readonly property color on_surface: "#261717"
    readonly property color on_surface_variant: "#5e4545"
    readonly property color inverseSurface: "#352727"
    readonly property color inverse_on_surface: "#f3eded"
    readonly property color inversePrimary: "#ef8f8f"

    // Outline and overlays
    readonly property color outline: "#9d7b7b"
    readonly property color outlineVariant: "#d5c3c3"
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
