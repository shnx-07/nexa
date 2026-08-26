import QtQuick
QtObject {
    // Primary
    readonly property color primary: "#82b8ed"
    readonly property color on_primary: "#061f37"
    readonly property color primaryContainer: "#1c3854"
    readonly property color on_primary_container: "#acd1f6"

    // Secondary
    readonly property color secondary: "#89e6e6"
    readonly property color on_secondary: "#083636"
    readonly property color secondaryContainer: "#1f5151"
    readonly property color on_secondary_container: "#aff4f4"

    // Tertiary
    readonly property color tertiary: "#9989e6"
    readonly property color on_tertiary: "#0f0836"
    readonly property color tertiaryContainer: "#271f51"
    readonly property color on_tertiary_container: "#baaff4"

    // Background
    readonly property color background: "#181c20"
    readonly property color on_background: "#dae0e7"

    // Surface hierarchy
    readonly property color surface: "#181c20"
    readonly property color surfaceDim: "#101418"
    readonly property color surfaceBright: "#313d49"
    readonly property color surfaceContainerLowest: "#0e1215"
    readonly property color surfaceContainerLow: "#1c2127"
    readonly property color surfaceContainer: "#222930"
    readonly property color surfaceContainerHigh: "#2a333c"
    readonly property color surfaceContainerHighest: "#34404c"

    // Surface content
    readonly property color on_surface: "#dae0e7"
    readonly property color on_surface_variant: "#adb8c2"
    readonly property color inverseSurface: "#dce0e5"
    readonly property color inverse_on_surface: "#181f25"
    readonly property color inversePrimary: "#2873bd"

    // Outline and overlays
    readonly property color outline: "#627384"
    readonly property color outlineVariant: "#2e3842"
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
