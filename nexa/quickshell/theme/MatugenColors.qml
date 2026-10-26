pragma Singleton
import QtQuick

QtObject {
    // Primary
    readonly property color primary: "#9bcbff"
    readonly property color on_primary: "#003256"
    readonly property color primaryContainer: "#004a7a"
    readonly property color on_primary_container: "#d0e4ff"

    // Secondary
    readonly property color secondary: "#b8c6ea"
    readonly property color on_secondary: "#22304c"
    readonly property color secondaryContainer: "#394764"
    readonly property color on_secondary_container: "#d8e2ff"

    // Tertiary
    readonly property color tertiary: "#bec2fa"
    readonly property color on_tertiary: "#272c5a"
    readonly property color tertiaryContainer: "#3e4372"
    readonly property color on_tertiary_container: "#e0e0ff"

    // Background
    readonly property color background: "#0d141b"
    readonly property color on_background: "#dce3ee"

    // Surface hierarchy
    readonly property color surface: "#0d141b"
    readonly property color surfaceDim: "#0d141b"
    readonly property color surfaceBright: "#333a42"

    readonly property color surfaceContainerLowest: "#080f16"
    readonly property color surfaceContainerLow: "#151c24"
    readonly property color surfaceContainer: "#192028"
    readonly property color surfaceContainerHigh: "#242b33"
    readonly property color surfaceContainerHighest: "#2f353e"

    // Surface content
    readonly property color on_surface: "#dce3ee"
    readonly property color on_surface_variant: "#c0c7d2"

    readonly property color inverseSurface: "#dce3ee"
    readonly property color inverse_on_surface: "#2a3139"
    readonly property color inversePrimary: "#0062a0"

    // Outline
    readonly property color outline: "#8a919b"
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

    // Keep current NEXA compatibility (map to proper surface container, not text)
    readonly property color surfaceVariant: surfaceContainerHigh
}
