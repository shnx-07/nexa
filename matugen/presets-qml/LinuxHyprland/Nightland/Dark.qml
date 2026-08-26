import QtQuick
QtObject {
    // Primary
    readonly property color primary: "#8282ed"
    readonly property color on_primary: "#060637"
    readonly property color primaryContainer: "#1c1c54"
    readonly property color on_primary_container: "#acacf6"

    // Secondary
    readonly property color secondary: "#d789e6"
    readonly property color on_secondary: "#2e0836"
    readonly property color secondaryContainer: "#491f51"
    readonly property color on_secondary_container: "#e8aff4"

    // Tertiary
    readonly property color tertiary: "#89e6d7"
    readonly property color on_tertiary: "#08362e"
    readonly property color tertiaryContainer: "#1f5149"
    readonly property color on_tertiary_container: "#aff4e8"

    // Background
    readonly property color background: "#181820"
    readonly property color on_background: "#dadae7"

    // Surface hierarchy
    readonly property color surface: "#181820"
    readonly property color surfaceDim: "#101018"
    readonly property color surfaceBright: "#313149"
    readonly property color surfaceContainerLowest: "#0e0e15"
    readonly property color surfaceContainerLow: "#1c1c27"
    readonly property color surfaceContainer: "#222230"
    readonly property color surfaceContainerHigh: "#2a2a3c"
    readonly property color surfaceContainerHighest: "#34344c"

    // Surface content
    readonly property color on_surface: "#dadae7"
    readonly property color on_surface_variant: "#adadc2"
    readonly property color inverseSurface: "#dcdce5"
    readonly property color inverse_on_surface: "#181825"
    readonly property color inversePrimary: "#2828bd"

    // Outline and overlays
    readonly property color outline: "#626284"
    readonly property color outlineVariant: "#2e2e42"
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
