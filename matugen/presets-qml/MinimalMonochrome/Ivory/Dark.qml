import QtQuick
QtObject {
    // Primary
    readonly property color primary: "#edc982"
    readonly property color on_primary: "#372706"
    readonly property color primaryContainer: "#54411c"
    readonly property color on_primary_container: "#f6ddac"

    // Secondary
    readonly property color secondary: "#e6b889"
    readonly property color on_secondary: "#361f08"
    readonly property color secondaryContainer: "#51381f"
    readonly property color on_secondary_container: "#f4d1af"

    // Tertiary
    readonly property color tertiary: "#89c7e6"
    readonly property color on_tertiary: "#082636"
    readonly property color tertiaryContainer: "#1f4151"
    readonly property color on_tertiary_container: "#afddf4"

    // Background
    readonly property color background: "#201d18"
    readonly property color on_background: "#e7e2da"

    // Surface hierarchy
    readonly property color surface: "#201d18"
    readonly property color surfaceDim: "#181610"
    readonly property color surfaceBright: "#494131"
    readonly property color surfaceContainerLowest: "#15130e"
    readonly property color surfaceContainerLow: "#27231c"
    readonly property color surfaceContainer: "#302b22"
    readonly property color surfaceContainerHigh: "#3c362a"
    readonly property color surfaceContainerHighest: "#4c4434"

    // Surface content
    readonly property color on_surface: "#e7e2da"
    readonly property color on_surface_variant: "#c2bbad"
    readonly property color inverseSurface: "#e5e2dc"
    readonly property color inverse_on_surface: "#252118"
    readonly property color inversePrimary: "#bd8c28"

    // Outline and overlays
    readonly property color outline: "#847862"
    readonly property color outlineVariant: "#423b2e"
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
