import QtQuick
QtObject {
    // Primary
    readonly property color primary: "#82edb8"
    readonly property color on_primary: "#06371f"
    readonly property color primaryContainer: "#1c5438"
    readonly property color on_primary_container: "#acf6d1"

    // Secondary
    readonly property color secondary: "#89e6d7"
    readonly property color on_secondary: "#08362e"
    readonly property color secondaryContainer: "#1f5149"
    readonly property color on_secondary_container: "#aff4e8"

    // Tertiary
    readonly property color tertiary: "#e6e689"
    readonly property color on_tertiary: "#363608"
    readonly property color tertiaryContainer: "#51511f"
    readonly property color on_tertiary_container: "#f4f4af"

    // Background
    readonly property color background: "#18201c"
    readonly property color on_background: "#dae7e0"

    // Surface hierarchy
    readonly property color surface: "#18201c"
    readonly property color surfaceDim: "#101814"
    readonly property color surfaceBright: "#31493d"
    readonly property color surfaceContainerLowest: "#0e1512"
    readonly property color surfaceContainerLow: "#1c2721"
    readonly property color surfaceContainer: "#223029"
    readonly property color surfaceContainerHigh: "#2a3c33"
    readonly property color surfaceContainerHighest: "#344c40"

    // Surface content
    readonly property color on_surface: "#dae7e0"
    readonly property color on_surface_variant: "#adc2b8"
    readonly property color inverseSurface: "#dce5e0"
    readonly property color inverse_on_surface: "#18251f"
    readonly property color inversePrimary: "#28bd73"

    // Outline and overlays
    readonly property color outline: "#628473"
    readonly property color outlineVariant: "#2e4238"
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
