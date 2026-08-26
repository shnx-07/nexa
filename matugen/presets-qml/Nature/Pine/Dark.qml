import QtQuick
QtObject {
    // Primary
    readonly property color primary: "#82edd2"
    readonly property color on_primary: "#06372b"
    readonly property color primaryContainer: "#1c5446"
    readonly property color on_primary_container: "#acf6e3"

    // Secondary
    readonly property color secondary: "#89d7e6"
    readonly property color on_secondary: "#082e36"
    readonly property color secondaryContainer: "#1f4951"
    readonly property color on_secondary_container: "#afe8f4"

    // Tertiary
    readonly property color tertiary: "#e6bf89"
    readonly property color on_tertiary: "#362208"
    readonly property color tertiaryContainer: "#513c1f"
    readonly property color on_tertiary_container: "#f4d7af"

    // Background
    readonly property color background: "#18201e"
    readonly property color on_background: "#dae7e3"

    // Surface hierarchy
    readonly property color surface: "#18201e"
    readonly property color surfaceDim: "#101816"
    readonly property color surfaceBright: "#314943"
    readonly property color surfaceContainerLowest: "#0e1514"
    readonly property color surfaceContainerLow: "#1c2724"
    readonly property color surfaceContainer: "#22302c"
    readonly property color surfaceContainerHigh: "#2a3c38"
    readonly property color surfaceContainerHighest: "#344c46"

    // Surface content
    readonly property color on_surface: "#dae7e3"
    readonly property color on_surface_variant: "#adc2bd"
    readonly property color inverseSurface: "#dce5e3"
    readonly property color inverse_on_surface: "#182522"
    readonly property color inversePrimary: "#28bd98"

    // Outline and overlays
    readonly property color outline: "#62847b"
    readonly property color outlineVariant: "#2e423d"
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
