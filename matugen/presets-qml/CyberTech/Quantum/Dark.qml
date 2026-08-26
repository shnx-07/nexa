import QtQuick
QtObject {
    // Primary
    readonly property color primary: "#82dbed"
    readonly property color on_primary: "#062f37"
    readonly property color primaryContainer: "#1c4b54"
    readonly property color on_primary_container: "#aceaf6"

    // Secondary
    readonly property color secondary: "#bf89e6"
    readonly property color on_secondary: "#220836"
    readonly property color secondaryContainer: "#3c1f51"
    readonly property color on_secondary_container: "#d7aff4"

    // Tertiary
    readonly property color tertiary: "#e689b8"
    readonly property color on_tertiary: "#36081f"
    readonly property color tertiaryContainer: "#511f38"
    readonly property color on_tertiary_container: "#f4afd1"

    // Background
    readonly property color background: "#181f20"
    readonly property color on_background: "#dae4e7"

    // Surface hierarchy
    readonly property color surface: "#181f20"
    readonly property color surfaceDim: "#101718"
    readonly property color surfaceBright: "#314549"
    readonly property color surfaceContainerLowest: "#0e1415"
    readonly property color surfaceContainerLow: "#1c2527"
    readonly property color surfaceContainer: "#222d30"
    readonly property color surfaceContainerHigh: "#2a393c"
    readonly property color surfaceContainerHighest: "#34484c"

    // Surface content
    readonly property color on_surface: "#dae4e7"
    readonly property color on_surface_variant: "#adbfc2"
    readonly property color inverseSurface: "#dce3e5"
    readonly property color inverse_on_surface: "#182325"
    readonly property color inversePrimary: "#28a4bd"

    // Outline and overlays
    readonly property color outline: "#627e84"
    readonly property color outlineVariant: "#2e3f42"
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
