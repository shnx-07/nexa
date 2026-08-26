import QtQuick
QtObject {
    // Primary
    readonly property color primary: "#828bed"
    readonly property color on_primary: "#060a37"
    readonly property color primaryContainer: "#1c2154"
    readonly property color on_primary_container: "#acb2f6"

    // Secondary
    readonly property color secondary: "#a889e6"
    readonly property color on_secondary: "#170836"
    readonly property color secondaryContainer: "#301f51"
    readonly property color on_secondary_container: "#c6aff4"

    // Tertiary
    readonly property color tertiary: "#89d7e6"
    readonly property color on_tertiary: "#082e36"
    readonly property color tertiaryContainer: "#1f4951"
    readonly property color on_tertiary_container: "#afe8f4"

    // Background
    readonly property color background: "#181920"
    readonly property color on_background: "#dadbe7"

    // Surface hierarchy
    readonly property color surface: "#181920"
    readonly property color surfaceDim: "#101118"
    readonly property color surfaceBright: "#313349"
    readonly property color surfaceContainerLowest: "#0e0f15"
    readonly property color surfaceContainerLow: "#1c1c27"
    readonly property color surfaceContainer: "#222330"
    readonly property color surfaceContainerHigh: "#2a2b3c"
    readonly property color surfaceContainerHighest: "#34364c"

    // Surface content
    readonly property color on_surface: "#dadbe7"
    readonly property color on_surface_variant: "#adafc2"
    readonly property color inverseSurface: "#dcdde5"
    readonly property color inverse_on_surface: "#181925"
    readonly property color inversePrimary: "#2835bd"

    // Outline and overlays
    readonly property color outline: "#626484"
    readonly property color outlineVariant: "#2e3042"
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

    // Information
    readonly property color info: "#79cfec"
    readonly property color on_info: "#062b37"
    readonly property color infoContainer: "#1c3e4a"
    readonly property color on_info_container: "#a3e0f5"
}
