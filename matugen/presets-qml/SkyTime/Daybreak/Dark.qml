import QtQuick
QtObject {
    // Primary
    readonly property color primary: "#edd282"
    readonly property color on_primary: "#372b06"
    readonly property color primaryContainer: "#54461c"
    readonly property color on_primary_container: "#f6e3ac"

    // Secondary
    readonly property color secondary: "#89c7e6"
    readonly property color on_secondary: "#082636"
    readonly property color secondaryContainer: "#1f4151"
    readonly property color on_secondary_container: "#afddf4"

    // Tertiary
    readonly property color tertiary: "#e6a089"
    readonly property color on_tertiary: "#361308"
    readonly property color tertiaryContainer: "#512b1f"
    readonly property color on_tertiary_container: "#f4c0af"

    // Background
    readonly property color background: "#201e18"
    readonly property color on_background: "#e7e3da"

    // Surface hierarchy
    readonly property color surface: "#201e18"
    readonly property color surfaceDim: "#181610"
    readonly property color surfaceBright: "#494331"
    readonly property color surfaceContainerLowest: "#15140e"
    readonly property color surfaceContainerLow: "#27241c"
    readonly property color surfaceContainer: "#302c22"
    readonly property color surfaceContainerHigh: "#3c382a"
    readonly property color surfaceContainerHighest: "#4c4634"

    // Surface content
    readonly property color on_surface: "#e7e3da"
    readonly property color on_surface_variant: "#c2bdad"
    readonly property color inverseSurface: "#e5e3dc"
    readonly property color inverse_on_surface: "#252218"
    readonly property color inversePrimary: "#bd9828"

    // Outline and overlays
    readonly property color outline: "#847b62"
    readonly property color outlineVariant: "#423d2e"
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
