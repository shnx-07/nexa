import QtQuick
QtObject {
    // Primary
    readonly property color primary: "#ed82db"
    readonly property color on_primary: "#37062f"
    readonly property color primaryContainer: "#541c4b"
    readonly property color on_primary_container: "#f6acea"

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
    readonly property color background: "#20181f"
    readonly property color on_background: "#e7dae4"

    // Surface hierarchy
    readonly property color surface: "#20181f"
    readonly property color surfaceDim: "#181017"
    readonly property color surfaceBright: "#493145"
    readonly property color surfaceContainerLowest: "#150e14"
    readonly property color surfaceContainerLow: "#271c25"
    readonly property color surfaceContainer: "#30222d"
    readonly property color surfaceContainerHigh: "#3c2a39"
    readonly property color surfaceContainerHighest: "#4c3448"

    // Surface content
    readonly property color on_surface: "#e7dae4"
    readonly property color on_surface_variant: "#c2adbf"
    readonly property color inverseSurface: "#e5dce3"
    readonly property color inverse_on_surface: "#251823"
    readonly property color inversePrimary: "#bd28a4"

    // Outline and overlays
    readonly property color outline: "#84627e"
    readonly property color outlineVariant: "#422e3f"
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
