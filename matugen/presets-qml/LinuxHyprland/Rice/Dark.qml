import QtQuick
QtObject {
    // Primary
    readonly property color primary: "#82edc9"
    readonly property color on_primary: "#063727"
    readonly property color primaryContainer: "#1c5441"
    readonly property color on_primary_container: "#acf6dd"

    // Secondary
    readonly property color secondary: "#e6bf89"
    readonly property color on_secondary: "#362208"
    readonly property color secondaryContainer: "#513c1f"
    readonly property color on_secondary_container: "#f4d7af"

    // Tertiary
    readonly property color tertiary: "#c789e6"
    readonly property color on_tertiary: "#260836"
    readonly property color tertiaryContainer: "#411f51"
    readonly property color on_tertiary_container: "#ddaff4"

    // Background
    readonly property color background: "#18201d"
    readonly property color on_background: "#dae7e2"

    // Surface hierarchy
    readonly property color surface: "#18201d"
    readonly property color surfaceDim: "#101816"
    readonly property color surfaceBright: "#314941"
    readonly property color surfaceContainerLowest: "#0e1513"
    readonly property color surfaceContainerLow: "#1c2723"
    readonly property color surfaceContainer: "#22302b"
    readonly property color surfaceContainerHigh: "#2a3c36"
    readonly property color surfaceContainerHighest: "#344c44"

    // Surface content
    readonly property color on_surface: "#dae7e2"
    readonly property color on_surface_variant: "#adc2bb"
    readonly property color inverseSurface: "#dce5e2"
    readonly property color inverse_on_surface: "#182521"
    readonly property color inversePrimary: "#28bd8c"

    // Outline and overlays
    readonly property color outline: "#628478"
    readonly property color outlineVariant: "#2e423b"
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
