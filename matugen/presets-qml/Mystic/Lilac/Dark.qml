import QtQuick
QtObject {
    // Primary
    readonly property color primary: "#d282ed"
    readonly property color on_primary: "#2b0637"
    readonly property color primaryContainer: "#461c54"
    readonly property color on_primary_container: "#e3acf6"

    // Secondary
    readonly property color secondary: "#e689bf"
    readonly property color on_secondary: "#360822"
    readonly property color secondaryContainer: "#511f3c"
    readonly property color on_secondary_container: "#f4afd7"

    // Tertiary
    readonly property color tertiary: "#89a8e6"
    readonly property color on_tertiary: "#081736"
    readonly property color tertiaryContainer: "#1f3051"
    readonly property color on_tertiary_container: "#afc6f4"

    // Background
    readonly property color background: "#1e1820"
    readonly property color on_background: "#e3dae7"

    // Surface hierarchy
    readonly property color surface: "#1e1820"
    readonly property color surfaceDim: "#161018"
    readonly property color surfaceBright: "#433149"
    readonly property color surfaceContainerLowest: "#140e15"
    readonly property color surfaceContainerLow: "#241c27"
    readonly property color surfaceContainer: "#2c2230"
    readonly property color surfaceContainerHigh: "#382a3c"
    readonly property color surfaceContainerHighest: "#46344c"

    // Surface content
    readonly property color on_surface: "#e3dae7"
    readonly property color on_surface_variant: "#bdadc2"
    readonly property color inverseSurface: "#e3dce5"
    readonly property color inverse_on_surface: "#221825"
    readonly property color inversePrimary: "#9828bd"

    // Outline and overlays
    readonly property color outline: "#7b6284"
    readonly property color outlineVariant: "#3d2e42"
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
