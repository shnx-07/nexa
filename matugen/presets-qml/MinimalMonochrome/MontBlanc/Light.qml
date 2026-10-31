import QtQuick
QtObject {
    // Primary
    readonly property color primary: "#121212"
    readonly property color on_primary: "#ffffff"
    readonly property color primaryContainer: "#e8e8e8"
    readonly property color on_primary_container: "#000000"

    // Secondary
    readonly property color secondary: "#444444"
    readonly property color on_secondary: "#ffffff"
    readonly property color secondaryContainer: "#dedede"
    readonly property color on_secondary_container: "#111111"

    // Tertiary
    readonly property color tertiary: "#6e6e6e"
    readonly property color on_tertiary: "#ffffff"
    readonly property color tertiaryContainer: "#e4e4e4"
    readonly property color on_tertiary_container: "#222222"

    // Background
    readonly property color background: "#f8f9fa"
    readonly property color on_background: "#121212"

    // Surface hierarchy
    readonly property color surface: "#ffffff"
    readonly property color surfaceDim: "#eaeaea"
    readonly property color surfaceBright: "#ffffff"
    readonly property color surfaceContainerLowest: "#ffffff"
    readonly property color surfaceContainerLow: "#f4f4f4"
    readonly property color surfaceContainer: "#eeeeee"
    readonly property color surfaceContainerHigh: "#e6e6e6"
    readonly property color surfaceContainerHighest: "#dedede"

    // Surface content
    readonly property color on_surface: "#121212"
    readonly property color on_surface_variant: "#555555"
    readonly property color inverseSurface: "#121212"
    readonly property color inverse_on_surface: "#ffffff"
    readonly property color inversePrimary: "#cccccc"

    // Outline and overlays
    readonly property color outline: "#888888"
    readonly property color outlineVariant: "#cccccc"
    readonly property color shadow: "#000000"
    readonly property color scrim: "#000000"

    // Error
    readonly property color error: "#d32f2f"
    readonly property color on_error: "#ffffff"
    readonly property color errorContainer: "#ffcdd2"
    readonly property color on_error_container: "#49080e"

    // Success
    readonly property color success: "#2e7d32"
    readonly property color on_success: "#ffffff"
    readonly property color successContainer: "#c8e6c9"
    readonly property color on_success_container: "#093e1b"

    // Warning
    readonly property color warning: "#ed6c02"
    readonly property color on_warning: "#ffffff"
    readonly property color warningContainer: "#ffe0b2"
    readonly property color on_warning_container: "#422905"

    // Info
    readonly property color info: "#0288d1"
    readonly property color on_info: "#ffffff"
    readonly property color infoContainer: "#b3e5fc"
    readonly property color on_info_container: "#073240"

    // Compatibility aliases
    readonly property color text: on_background
}

