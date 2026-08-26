import QtQuick
QtObject {
    // Primary
    readonly property color primary: "#82e4ed"
    readonly property color on_primary: "#063337"
    readonly property color primaryContainer: "#1c4f54"
    readonly property color on_primary_container: "#acf0f6"

    // Secondary
    readonly property color secondary: "#89c7e6"
    readonly property color on_secondary: "#082636"
    readonly property color secondaryContainer: "#1f4151"
    readonly property color on_secondary_container: "#afddf4"

    // Tertiary
    readonly property color tertiary: "#89e6d7"
    readonly property color on_tertiary: "#08362e"
    readonly property color tertiaryContainer: "#1f5149"
    readonly property color on_tertiary_container: "#aff4e8"

    // Background
    readonly property color background: "#182020"
    readonly property color on_background: "#dae6e7"

    // Surface hierarchy
    readonly property color surface: "#182020"
    readonly property color surfaceDim: "#101818"
    readonly property color surfaceBright: "#314749"
    readonly property color surfaceContainerLowest: "#0e1515"
    readonly property color surfaceContainerLow: "#1c2627"
    readonly property color surfaceContainer: "#222f30"
    readonly property color surfaceContainerHigh: "#2a3b3c"
    readonly property color surfaceContainerHighest: "#344a4c"

    // Surface content
    readonly property color on_surface: "#dae6e7"
    readonly property color on_surface_variant: "#adc1c2"
    readonly property color inverseSurface: "#dce4e5"
    readonly property color inverse_on_surface: "#182425"
    readonly property color inversePrimary: "#28b1bd"

    // Outline and overlays
    readonly property color outline: "#628184"
    readonly property color outlineVariant: "#2e4142"
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
