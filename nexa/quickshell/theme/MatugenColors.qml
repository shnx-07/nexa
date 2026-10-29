pragma Singleton
import QtQuick

QtObject {
    // Primary
    readonly property color primary: "#b1c5ff"
    readonly property color on_primary: "#002c70"
    readonly property color primaryContainer: "#00419e"
    readonly property color on_primary_container: "#dae2ff"

    // Secondary
    readonly property color secondary: "#c3c3eb"
    readonly property color on_secondary: "#2c2d4d"
    readonly property color secondaryContainer: "#434465"
    readonly property color on_secondary_container: "#e1e0ff"

    // Tertiary
    readonly property color tertiary: "#cfbef7"
    readonly property color on_tertiary: "#352857"
    readonly property color tertiaryContainer: "#4c3f6f"
    readonly property color on_tertiary_container: "#e9ddff"

    // Background
    readonly property color background: "#10131c"
    readonly property color on_background: "#e0e2ef"

    // Surface hierarchy
    readonly property color surface: "#10131c"
    readonly property color surfaceDim: "#10131c"
    readonly property color surfaceBright: "#363943"

    readonly property color surfaceContainerLowest: "#0b0e17"
    readonly property color surfaceContainerLow: "#181b25"
    readonly property color surfaceContainer: "#1c1f29"
    readonly property color surfaceContainerHigh: "#272a34"
    readonly property color surfaceContainerHighest: "#31343f"

    // Surface content
    readonly property color on_surface: "#e0e2ef"
    readonly property color on_surface_variant: "#c4c6d3"

    readonly property color inverseSurface: "#e0e2ef"
    readonly property color inverse_on_surface: "#2d303a"
    readonly property color inversePrimary: "#0057ce"

    // Outline
    readonly property color outline: "#8e909c"
    readonly property color outlineVariant: "#434651"
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
