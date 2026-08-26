import QtQuick
QtObject {
    // Primary
    readonly property color primary: "#82ede4"
    readonly property color on_primary: "#063733"
    readonly property color primaryContainer: "#1c544f"
    readonly property color on_primary_container: "#acf6f0"

    // Secondary
    readonly property color secondary: "#89b0e6"
    readonly property color on_secondary: "#081b36"
    readonly property color secondaryContainer: "#1f3451"
    readonly property color on_secondary_container: "#afcbf4"

    // Tertiary
    readonly property color tertiary: "#e689a8"
    readonly property color on_tertiary: "#360817"
    readonly property color tertiaryContainer: "#511f30"
    readonly property color on_tertiary_container: "#f4afc6"

    // Background
    readonly property color background: "#182020"
    readonly property color on_background: "#dae7e6"

    // Surface hierarchy
    readonly property color surface: "#182020"
    readonly property color surfaceDim: "#101818"
    readonly property color surfaceBright: "#314947"
    readonly property color surfaceContainerLowest: "#0e1515"
    readonly property color surfaceContainerLow: "#1c2726"
    readonly property color surfaceContainer: "#22302f"
    readonly property color surfaceContainerHigh: "#2a3c3b"
    readonly property color surfaceContainerHighest: "#344c4a"

    // Surface content
    readonly property color on_surface: "#dae7e6"
    readonly property color on_surface_variant: "#adc2c1"
    readonly property color inverseSurface: "#dce5e4"
    readonly property color inverse_on_surface: "#182524"
    readonly property color inversePrimary: "#28bdb1"

    // Outline and overlays
    readonly property color outline: "#628481"
    readonly property color outlineVariant: "#2e4241"
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
