pragma Singleton
import QtQuick

QtObject {
    // Primary
    readonly property color primary: "#ffb4aa"
    readonly property color on_primary: "#690003"
    readonly property color primaryContainer: "#930005"
    readonly property color on_primary_container: "#ffdad5"

    // Secondary
    readonly property color secondary: "#f4ba9f"
    readonly property color on_secondary: "#4b2715"
    readonly property color secondaryContainer: "#653d29"
    readonly property color on_secondary_container: "#ffdbcc"

    // Tertiary
    readonly property color tertiary: "#fab981"
    readonly property color on_tertiary: "#4c2700"
    readonly property color tertiaryContainer: "#683c0e"
    readonly property color on_tertiary_container: "#ffdcc1"

    // Background
    readonly property color background: "#1e100e"
    readonly property color on_background: "#f9dcd8"

    // Surface hierarchy
    readonly property color surface: "#1e100e"
    readonly property color surfaceDim: "#1e100e"
    readonly property color surfaceBright: "#473532"

    readonly property color surfaceContainerLowest: "#180b09"
    readonly property color surfaceContainerLow: "#271816"
    readonly property color surfaceContainer: "#2b1c1a"
    readonly property color surfaceContainerHigh: "#372624"
    readonly property color surfaceContainerHighest: "#42302e"

    // Surface content
    readonly property color on_surface: "#f9dcd8"
    readonly property color on_surface_variant: "#dcc0bd"

    readonly property color inverseSurface: "#f9dcd8"
    readonly property color inverse_on_surface: "#3d2c2a"
    readonly property color inversePrimary: "#c0000a"

    // Outline
    readonly property color outline: "#a38b88"
    readonly property color outlineVariant: "#554240"
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
