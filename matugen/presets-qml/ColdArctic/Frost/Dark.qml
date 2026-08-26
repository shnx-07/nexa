import QtQuick
QtObject {
    // Primary
    readonly property color primary: "#82d2ed"
    readonly property color on_primary: "#062b37"
    readonly property color primaryContainer: "#1c4654"
    readonly property color on_primary_container: "#ace3f6"

    // Secondary
    readonly property color secondary: "#89b0e6"
    readonly property color on_secondary: "#081b36"
    readonly property color secondaryContainer: "#1f3451"
    readonly property color on_secondary_container: "#afcbf4"

    // Tertiary
    readonly property color tertiary: "#8989e6"
    readonly property color on_tertiary: "#080836"
    readonly property color tertiaryContainer: "#1f1f51"
    readonly property color on_tertiary_container: "#afaff4"

    // Background
    readonly property color background: "#181e20"
    readonly property color on_background: "#dae3e7"

    // Surface hierarchy
    readonly property color surface: "#181e20"
    readonly property color surfaceDim: "#101618"
    readonly property color surfaceBright: "#314349"
    readonly property color surfaceContainerLowest: "#0e1415"
    readonly property color surfaceContainerLow: "#1c2427"
    readonly property color surfaceContainer: "#222c30"
    readonly property color surfaceContainerHigh: "#2a383c"
    readonly property color surfaceContainerHighest: "#34464c"

    // Surface content
    readonly property color on_surface: "#dae3e7"
    readonly property color on_surface_variant: "#adbdc2"
    readonly property color inverseSurface: "#dce3e5"
    readonly property color inverse_on_surface: "#182225"
    readonly property color inversePrimary: "#2898bd"

    // Outline and overlays
    readonly property color outline: "#627b84"
    readonly property color outlineVariant: "#2e3d42"
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
