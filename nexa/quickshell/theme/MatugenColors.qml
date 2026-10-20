pragma Singleton
import QtQuick

QtObject {
    // Primary
    readonly property color primary: "#ffafd6"
    readonly property color on_primary: "#620043"
    readonly property color primaryContainer: "#8a0060"
    readonly property color on_primary_container: "#ffd8e8"

    // Secondary
    readonly property color secondary: "#f0b7c5"
    readonly property color on_secondary: "#4a2530"
    readonly property color secondaryContainer: "#643b46"
    readonly property color on_secondary_container: "#ffd9e1"

    // Tertiary
    readonly property color tertiary: "#ffb3b6"
    readonly property color on_tertiary: "#532025"
    readonly property color tertiaryContainer: "#6e353a"
    readonly property color on_tertiary_container: "#ffdada"

    // Background
    readonly property color background: "#1c1016"
    readonly property color on_background: "#f4dde5"

    // Surface hierarchy
    readonly property color surface: "#1c1016"
    readonly property color surfaceDim: "#1c1016"
    readonly property color surfaceBright: "#44353c"

    readonly property color surfaceContainerLowest: "#160b10"
    readonly property color surfaceContainerLow: "#24181e"
    readonly property color surfaceContainer: "#291c22"
    readonly property color surfaceContainerHigh: "#34262c"
    readonly property color surfaceContainerHighest: "#3f3137"

    // Surface content
    readonly property color on_surface: "#f4dde5"
    readonly property color on_surface_variant: "#d7c1c9"

    readonly property color inverseSurface: "#f4dde5"
    readonly property color inverse_on_surface: "#3b2c33"
    readonly property color inversePrimary: "#b4007f"

    // Outline
    readonly property color outline: "#9f8c93"
    readonly property color outlineVariant: "#524249"
    readonly property color shadow: "#000000"
    readonly property color scrim: "#000000"

    // Error
    readonly property color error: "#f0757f"
    readonly property color on_error: "#37060a"
    readonly property color errorContainer: "#541c21"
    readonly property color on_error_container: "#f8aab1"

    // Success
    readonly property color success: "#78e29c"
    readonly property color on_success: "#083617"
    readonly property color successContainer: "#1c4a2b"
    readonly property color on_success_container: "#a6f2bf"

    // Warning
    readonly property color warning: "#efc36c"
    readonly property color on_warning: "#372706"
    readonly property color warningContainer: "#4d3c19"
    readonly property color on_warning_container: "#f7daa1"

    // Info
    readonly property color info: "#79cfec"
    readonly property color on_info: "#062b37"
    readonly property color infoContainer: "#1c3e4a"
    readonly property color on_info_container: "#a3e0f5"

    // Compatibility aliases
    readonly property color text: on_background
    readonly property color mutedText: on_surface_variant

    // Keep current NEXA compatibility
    readonly property color surfaceVariant: on_surface_variant
}
