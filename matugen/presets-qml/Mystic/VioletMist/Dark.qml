import QtQuick
QtObject {
    // Primary
    readonly property color primary: "#a682ed"
    readonly property color on_primary: "#160637"
    readonly property color primaryContainer: "#2f1c54"
    readonly property color on_primary_container: "#c5acf6"

    // Secondary
    readonly property color secondary: "#c789e6"
    readonly property color on_secondary: "#260836"
    readonly property color secondaryContainer: "#411f51"
    readonly property color on_secondary_container: "#ddaff4"

    // Tertiary
    readonly property color tertiary: "#89b8e6"
    readonly property color on_tertiary: "#081f36"
    readonly property color tertiaryContainer: "#1f3851"
    readonly property color on_tertiary_container: "#afd1f4"

    // Background
    readonly property color background: "#1b1820"
    readonly property color on_background: "#dedae7"

    // Surface hierarchy
    readonly property color surface: "#1b1820"
    readonly property color surfaceDim: "#131018"
    readonly property color surfaceBright: "#393149"
    readonly property color surfaceContainerLowest: "#110e15"
    readonly property color surfaceContainerLow: "#1f1c27"
    readonly property color surfaceContainer: "#262230"
    readonly property color surfaceContainerHigh: "#302a3c"
    readonly property color surfaceContainerHighest: "#3c344c"

    // Surface content
    readonly property color on_surface: "#dedae7"
    readonly property color on_surface_variant: "#b4adc2"
    readonly property color inverseSurface: "#dfdce5"
    readonly property color inverse_on_surface: "#1d1825"
    readonly property color inversePrimary: "#5a28bd"

    // Outline and overlays
    readonly property color outline: "#6d6284"
    readonly property color outlineVariant: "#352e42"
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
