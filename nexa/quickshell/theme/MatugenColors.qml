pragma Singleton
import QtQuick

QtObject {
    // Primary
    readonly property color primary: "#ffb599"
    readonly property color on_primary: "#5a1c00"
    readonly property color primaryContainer: "#7f2a00"
    readonly property color on_primary_container: "#ffdbce"

    // Secondary
    readonly property color secondary: "#f0bc95"
    readonly property color on_secondary: "#48290d"
    readonly property color secondaryContainer: "#623f21"
    readonly property color on_secondary_container: "#ffdcc3"

    // Tertiary
    readonly property color tertiary: "#f0be79"
    readonly property color on_tertiary: "#452b00"
    readonly property color tertiaryContainer: "#624004"
    readonly property color on_tertiary_container: "#ffddb3"

    // Background
    readonly property color background: "#1e100b"
    readonly property color on_background: "#f9ddd3"

    // Surface hierarchy
    readonly property color surface: "#1e100b"
    readonly property color surfaceDim: "#1e100b"
    readonly property color surfaceBright: "#47352f"

    readonly property color surfaceContainerLowest: "#180b06"
    readonly property color surfaceContainerLow: "#271813"
    readonly property color surfaceContainer: "#2b1c16"
    readonly property color surfaceContainerHigh: "#362620"
    readonly property color surfaceContainerHighest: "#42312b"

    // Surface content
    readonly property color on_surface: "#f9ddd3"
    readonly property color on_surface_variant: "#dcc1b8"

    readonly property color inverseSurface: "#f9ddd3"
    readonly property color inverse_on_surface: "#3d2d26"
    readonly property color inversePrimary: "#a73a00"

    // Outline
    readonly property color outline: "#a38c83"
    readonly property color outlineVariant: "#55433c"
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
