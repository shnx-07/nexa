import QtQuick
QtObject {
    // Primary
    readonly property color primary: "#82c9ed"
    readonly property color on_primary: "#062737"
    readonly property color primaryContainer: "#1c4154"
    readonly property color on_primary_container: "#acddf6"

    // Secondary
    readonly property color secondary: "#89b8e6"
    readonly property color on_secondary: "#081f36"
    readonly property color secondaryContainer: "#1f3851"
    readonly property color on_secondary_container: "#afd1f4"

    // Tertiary
    readonly property color tertiary: "#e6bf89"
    readonly property color on_tertiary: "#362208"
    readonly property color tertiaryContainer: "#513c1f"
    readonly property color on_tertiary_container: "#f4d7af"

    // Background
    readonly property color background: "#181d20"
    readonly property color on_background: "#dae2e7"

    // Surface hierarchy
    readonly property color surface: "#181d20"
    readonly property color surfaceDim: "#101618"
    readonly property color surfaceBright: "#314149"
    readonly property color surfaceContainerLowest: "#0e1315"
    readonly property color surfaceContainerLow: "#1c2327"
    readonly property color surfaceContainer: "#222b30"
    readonly property color surfaceContainerHigh: "#2a363c"
    readonly property color surfaceContainerHighest: "#34444c"

    // Surface content
    readonly property color on_surface: "#dae2e7"
    readonly property color on_surface_variant: "#adbbc2"
    readonly property color inverseSurface: "#dce2e5"
    readonly property color inverse_on_surface: "#182125"
    readonly property color inversePrimary: "#288cbd"

    // Outline and overlays
    readonly property color outline: "#627884"
    readonly property color outlineVariant: "#2e3b42"
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
