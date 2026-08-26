import QtQuick
QtObject {
    // Primary
    readonly property color primary: "#ed9d82"
    readonly property color on_primary: "#371206"
    readonly property color primaryContainer: "#542a1c"
    readonly property color on_primary_container: "#f6bfac"

    // Secondary
    readonly property color secondary: "#e6bf89"
    readonly property color on_secondary: "#362208"
    readonly property color secondaryContainer: "#513c1f"
    readonly property color on_secondary_container: "#f4d7af"

    // Tertiary
    readonly property color tertiary: "#e68991"
    readonly property color on_tertiary: "#36080b"
    readonly property color tertiaryContainer: "#511f23"
    readonly property color on_tertiary_container: "#f4afb4"

    // Background
    readonly property color background: "#201a18"
    readonly property color on_background: "#e7ddda"

    // Surface hierarchy
    readonly property color surface: "#201a18"
    readonly property color surfaceDim: "#181210"
    readonly property color surfaceBright: "#493731"
    readonly property color surfaceContainerLowest: "#15100e"
    readonly property color surfaceContainerLow: "#271e1c"
    readonly property color surfaceContainer: "#302522"
    readonly property color surfaceContainerHigh: "#3c2e2a"
    readonly property color surfaceContainerHighest: "#4c3a34"

    // Surface content
    readonly property color on_surface: "#e7ddda"
    readonly property color on_surface_variant: "#c2b2ad"
    readonly property color inverseSurface: "#e5dedc"
    readonly property color inverse_on_surface: "#251c18"
    readonly property color inversePrimary: "#bd4d28"

    // Outline and overlays
    readonly property color outline: "#846a62"
    readonly property color outlineVariant: "#42332e"
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
