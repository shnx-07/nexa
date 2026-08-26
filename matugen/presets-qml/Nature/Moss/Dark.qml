import QtQuick
QtObject {
    // Primary
    readonly property color primary: "#afed82"
    readonly property color on_primary: "#1b3706"
    readonly property color primaryContainer: "#33541c"
    readonly property color on_primary_container: "#cbf6ac"

    // Secondary
    readonly property color secondary: "#89e699"
    readonly property color on_secondary: "#08360f"
    readonly property color secondaryContainer: "#1f5127"
    readonly property color on_secondary_container: "#aff4ba"

    // Tertiary
    readonly property color tertiary: "#d7e689"
    readonly property color on_tertiary: "#2e3608"
    readonly property color tertiaryContainer: "#49511f"
    readonly property color on_tertiary_container: "#e8f4af"

    // Background
    readonly property color background: "#1b2018"
    readonly property color on_background: "#dfe7da"

    // Surface hierarchy
    readonly property color surface: "#1b2018"
    readonly property color surfaceDim: "#141810"
    readonly property color surfaceBright: "#3b4931"
    readonly property color surfaceContainerLowest: "#11150e"
    readonly property color surfaceContainerLow: "#20271c"
    readonly property color surfaceContainer: "#283022"
    readonly property color surfaceContainerHigh: "#313c2a"
    readonly property color surfaceContainerHighest: "#3e4c34"

    // Surface content
    readonly property color on_surface: "#dfe7da"
    readonly property color on_surface_variant: "#b6c2ad"
    readonly property color inverseSurface: "#e0e5dc"
    readonly property color inverse_on_surface: "#1e2518"
    readonly property color inversePrimary: "#66bd28"

    // Outline and overlays
    readonly property color outline: "#708462"
    readonly property color outlineVariant: "#36422e"
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
