pragma Singleton
import QtQuick

QtObject {
    // Primary
    readonly property color primary: "#a0c9ff"
    readonly property color on_primary: "#003259"
    readonly property color primaryContainer: "#00497f"
    readonly property color on_primary_container: "#d2e4ff"

    // Secondary
    readonly property color secondary: "#bac6ea"
    readonly property color on_secondary: "#24304d"
    readonly property color secondaryContainer: "#3b4664"
    readonly property color on_secondary_container: "#dae2ff"

    // Tertiary
    readonly property color tertiary: "#c2c2f9"
    readonly property color on_tertiary: "#2a2b59"
    readonly property color tertiaryContainer: "#414271"
    readonly property color on_tertiary_container: "#e1dfff"

    // Background
    readonly property color background: "#0e141c"
    readonly property color on_background: "#dde3ee"

    // Surface hierarchy
    readonly property color surface: "#0e141c"
    readonly property color surfaceDim: "#0e141c"
    readonly property color surfaceBright: "#343a43"

    readonly property color surfaceContainerLowest: "#080f16"
    readonly property color surfaceContainerLow: "#161c24"
    readonly property color surfaceContainer: "#1a2028"
    readonly property color surfaceContainerHigh: "#242a33"
    readonly property color surfaceContainerHighest: "#2f353e"

    // Surface content
    readonly property color on_surface: "#dde3ee"
    readonly property color on_surface_variant: "#c1c7d2"

    readonly property color inverseSurface: "#dde3ee"
    readonly property color inverse_on_surface: "#2b313a"
    readonly property color inversePrimary: "#0061a6"

    // Outline
    readonly property color outline: "#8b919c"
    readonly property color outlineVariant: "#414750"
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
