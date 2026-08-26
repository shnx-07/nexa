import QtQuick
QtObject {
    // Primary
    readonly property color primary: "#82c1ed"
    readonly property color on_primary: "#062337"
    readonly property color primaryContainer: "#1c3d54"
    readonly property color on_primary_container: "#acd7f6"

    // Secondary
    readonly property color secondary: "#89a0e6"
    readonly property color on_secondary: "#081336"
    readonly property color secondaryContainer: "#1f2b51"
    readonly property color on_secondary_container: "#afc0f4"

    // Tertiary
    readonly property color tertiary: "#89d7e6"
    readonly property color on_tertiary: "#082e36"
    readonly property color tertiaryContainer: "#1f4951"
    readonly property color on_tertiary_container: "#afe8f4"

    // Background
    readonly property color background: "#181d20"
    readonly property color on_background: "#dae1e7"

    // Surface hierarchy
    readonly property color surface: "#181d20"
    readonly property color surfaceDim: "#101518"
    readonly property color surfaceBright: "#313f49"
    readonly property color surfaceContainerLowest: "#0e1215"
    readonly property color surfaceContainerLow: "#1c2227"
    readonly property color surfaceContainer: "#222a30"
    readonly property color surfaceContainerHigh: "#2a353c"
    readonly property color surfaceContainerHighest: "#34424c"

    // Surface content
    readonly property color on_surface: "#dae1e7"
    readonly property color on_surface_variant: "#adb9c2"
    readonly property color inverseSurface: "#dce1e5"
    readonly property color inverse_on_surface: "#182025"
    readonly property color inversePrimary: "#287fbd"

    // Outline and overlays
    readonly property color outline: "#627684"
    readonly property color outlineVariant: "#2e3a42"
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
