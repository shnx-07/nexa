import QtQuick
QtObject {
    // Primary
    readonly property color primary: "#edaf82"
    readonly property color on_primary: "#371b06"
    readonly property color primaryContainer: "#54331c"
    readonly property color on_primary_container: "#f6cbac"

    // Secondary
    readonly property color secondary: "#e689a8"
    readonly property color on_secondary: "#360817"
    readonly property color secondaryContainer: "#511f30"
    readonly property color on_secondary_container: "#f4afc6"

    // Tertiary
    readonly property color tertiary: "#89b8e6"
    readonly property color on_tertiary: "#081f36"
    readonly property color tertiaryContainer: "#1f3851"
    readonly property color on_tertiary_container: "#afd1f4"

    // Background
    readonly property color background: "#201b18"
    readonly property color on_background: "#e7dfda"

    // Surface hierarchy
    readonly property color surface: "#201b18"
    readonly property color surfaceDim: "#181410"
    readonly property color surfaceBright: "#493b31"
    readonly property color surfaceContainerLowest: "#15110e"
    readonly property color surfaceContainerLow: "#27201c"
    readonly property color surfaceContainer: "#302822"
    readonly property color surfaceContainerHigh: "#3c312a"
    readonly property color surfaceContainerHighest: "#4c3e34"

    // Surface content
    readonly property color on_surface: "#e7dfda"
    readonly property color on_surface_variant: "#c2b6ad"
    readonly property color inverseSurface: "#e5e0dc"
    readonly property color inverse_on_surface: "#251e18"
    readonly property color inversePrimary: "#bd6628"

    // Outline and overlays
    readonly property color outline: "#847062"
    readonly property color outlineVariant: "#42362e"
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
