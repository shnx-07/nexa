import QtQuick
QtObject {
    // Primary
    readonly property color primary: "#82edaf"
    readonly property color on_primary: "#06371b"
    readonly property color primaryContainer: "#1c5433"
    readonly property color on_primary_container: "#acf6cb"

    // Secondary
    readonly property color secondary: "#89b8e6"
    readonly property color on_secondary: "#081f36"
    readonly property color secondaryContainer: "#1f3851"
    readonly property color on_secondary_container: "#afd1f4"

    // Tertiary
    readonly property color tertiary: "#e6c789"
    readonly property color on_tertiary: "#362608"
    readonly property color tertiaryContainer: "#51411f"
    readonly property color on_tertiary_container: "#f4ddaf"

    // Background
    readonly property color background: "#18201b"
    readonly property color on_background: "#dae7df"

    // Surface hierarchy
    readonly property color surface: "#18201b"
    readonly property color surfaceDim: "#101814"
    readonly property color surfaceBright: "#31493b"
    readonly property color surfaceContainerLowest: "#0e1511"
    readonly property color surfaceContainerLow: "#1c2720"
    readonly property color surfaceContainer: "#223028"
    readonly property color surfaceContainerHigh: "#2a3c31"
    readonly property color surfaceContainerHighest: "#344c3e"

    // Surface content
    readonly property color on_surface: "#dae7df"
    readonly property color on_surface_variant: "#adc2b6"
    readonly property color inverseSurface: "#dce5e0"
    readonly property color inverse_on_surface: "#18251e"
    readonly property color inversePrimary: "#28bd66"

    // Outline and overlays
    readonly property color outline: "#628470"
    readonly property color outlineVariant: "#2e4236"
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
