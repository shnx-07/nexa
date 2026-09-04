pragma Singleton
import QtQuick

QtObject {
    // Primary
    readonly property color primary: "#ffb599"
    readonly property color on_primary: "#5a1c00"
    readonly property color primaryContainer: "#7f2b00"
    readonly property color on_primary_container: "#ffdbce"

    // Secondary
    readonly property color secondary: "#f0bc95"
    readonly property color on_secondary: "#48290d"
    readonly property color secondaryContainer: "#623f21"
    readonly property color on_secondary_container: "#ffdcc3"

    // Tertiary
    readonly property color tertiary: "#f0be79"
    readonly property color on_tertiary: "#452b00"
    readonly property color tertiaryContainer: "#614004"
    readonly property color on_tertiary_container: "#ffddb2"

    // Background
    readonly property color background: "#20181a"
    readonly property color on_background: "#e7dadd"

    // Surface hierarchy
    readonly property color surface: "#20181a"
    readonly property color surfaceDim: "#181012"
    readonly property color surfaceBright: "#493137"

    readonly property color surfaceContainerLowest: "#150e10"
    readonly property color surfaceContainerLow: "#271c1e"
    readonly property color surfaceContainer: "#302225"
    readonly property color surfaceContainerHigh: "#3c2a2e"
    readonly property color surfaceContainerHighest: "#4c343a"

    // Surface content
    readonly property color on_surface: "#e7dadd"
    readonly property color on_surface_variant: "#c2adb2"

    readonly property color inverseSurface: "#e5dcde"
    readonly property color inverse_on_surface: "#25181c"
    readonly property color inversePrimary: "#bd284d"

    // Outline
    readonly property color outline: "#84626a"
    readonly property color outlineVariant: "#422e33"
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
