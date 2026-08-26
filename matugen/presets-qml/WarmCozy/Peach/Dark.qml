import QtQuick
QtObject {
    // Primary
    readonly property color primary: "#eda682"
    readonly property color on_primary: "#371606"
    readonly property color primaryContainer: "#542f1c"
    readonly property color on_primary_container: "#f6c5ac"

    // Secondary
    readonly property color secondary: "#e689a0"
    readonly property color on_secondary: "#360813"
    readonly property color secondaryContainer: "#511f2b"
    readonly property color on_secondary_container: "#f4afc0"

    // Tertiary
    readonly property color tertiary: "#e6de89"
    readonly property color on_tertiary: "#363208"
    readonly property color tertiaryContainer: "#514d1f"
    readonly property color on_tertiary_container: "#f4eeaf"

    // Background
    readonly property color background: "#201b18"
    readonly property color on_background: "#e7deda"

    // Surface hierarchy
    readonly property color surface: "#201b18"
    readonly property color surfaceDim: "#181310"
    readonly property color surfaceBright: "#493931"
    readonly property color surfaceContainerLowest: "#15110e"
    readonly property color surfaceContainerLow: "#271f1c"
    readonly property color surfaceContainer: "#302622"
    readonly property color surfaceContainerHigh: "#3c302a"
    readonly property color surfaceContainerHighest: "#4c3c34"

    // Surface content
    readonly property color on_surface: "#e7deda"
    readonly property color on_surface_variant: "#c2b4ad"
    readonly property color inverseSurface: "#e5dfdc"
    readonly property color inverse_on_surface: "#251d18"
    readonly property color inversePrimary: "#bd5a28"

    // Outline and overlays
    readonly property color outline: "#846d62"
    readonly property color outlineVariant: "#42352e"
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
