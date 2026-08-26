import QtQuick
QtObject {
    // Primary
    readonly property color primary: "#82eda6"
    readonly property color on_primary: "#063716"
    readonly property color primaryContainer: "#1c542f"
    readonly property color on_primary_container: "#acf6c5"

    // Secondary
    readonly property color secondary: "#e6b889"
    readonly property color on_secondary: "#361f08"
    readonly property color secondaryContainer: "#51381f"
    readonly property color on_secondary_container: "#f4d1af"

    // Tertiary
    readonly property color tertiary: "#c7e689"
    readonly property color on_tertiary: "#263608"
    readonly property color tertiaryContainer: "#41511f"
    readonly property color on_tertiary_container: "#ddf4af"

    // Background
    readonly property color background: "#18201b"
    readonly property color on_background: "#dae7de"

    // Surface hierarchy
    readonly property color surface: "#18201b"
    readonly property color surfaceDim: "#101813"
    readonly property color surfaceBright: "#314939"
    readonly property color surfaceContainerLowest: "#0e1511"
    readonly property color surfaceContainerLow: "#1c271f"
    readonly property color surfaceContainer: "#223026"
    readonly property color surfaceContainerHigh: "#2a3c30"
    readonly property color surfaceContainerHighest: "#344c3c"

    // Surface content
    readonly property color on_surface: "#dae7de"
    readonly property color on_surface_variant: "#adc2b4"
    readonly property color inverseSurface: "#dce5df"
    readonly property color inverse_on_surface: "#18251d"
    readonly property color inversePrimary: "#28bd5a"

    // Outline and overlays
    readonly property color outline: "#62846d"
    readonly property color outlineVariant: "#2e4235"
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
