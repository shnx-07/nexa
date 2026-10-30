pragma Singleton
import QtQuick

QtObject {
    // Primary
    readonly property color primary: "#d3bbff"
    readonly property color on_primary: "#40008c"
    readonly property color primaryContainer: "#5c00c4"
    readonly property color on_primary_container: "#ebdcff"

    // Secondary
    readonly property color secondary: "#d7bee4"
    readonly property color on_secondary: "#3b2947"
    readonly property color secondaryContainer: "#533f5f"
    readonly property color on_secondary_container: "#f3daff"

    // Tertiary
    readonly property color tertiary: "#e7b7e8"
    readonly property color on_tertiary: "#46234a"
    readonly property color tertiaryContainer: "#5f3962"
    readonly property color on_tertiary_container: "#ffd6fe"

    // Background
    readonly property color background: "#15121c"
    readonly property color on_background: "#e8dfee"

    // Surface hierarchy
    readonly property color surface: "#15121c"
    readonly property color surfaceDim: "#15121c"
    readonly property color surfaceBright: "#3c3742"

    readonly property color surfaceContainerLowest: "#100c16"
    readonly property color surfaceContainerLow: "#1e1a24"
    readonly property color surfaceContainer: "#221e28"
    readonly property color surfaceContainerHigh: "#2c2833"
    readonly property color surfaceContainerHighest: "#37333e"

    // Surface content
    readonly property color on_surface: "#e8dfee"
    readonly property color on_surface_variant: "#cbc4d2"

    readonly property color inverseSurface: "#e8dfee"
    readonly property color inverse_on_surface: "#332e39"
    readonly property color inversePrimary: "#7900fe"

    // Outline
    readonly property color outline: "#958e9c"
    readonly property color outlineVariant: "#4a4550"
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
