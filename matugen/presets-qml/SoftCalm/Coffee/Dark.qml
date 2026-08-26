import QtQuick
QtObject {
    // Primary
    readonly property color primary: "#edb482"
    readonly property color on_primary: "#371d06"
    readonly property color primaryContainer: "#54361c"
    readonly property color on_primary_container: "#f6cfac"

    // Secondary
    readonly property color secondary: "#e6a589"
    readonly property color on_secondary: "#361508"
    readonly property color secondaryContainer: "#512e1f"
    readonly property color on_secondary_container: "#f4c3af"

    // Tertiary
    readonly property color tertiary: "#e6d389"
    readonly property color on_tertiary: "#362c08"
    readonly property color tertiaryContainer: "#51471f"
    readonly property color on_tertiary_container: "#f4e6af"

    // Background
    readonly property color background: "#201c18"
    readonly property color on_background: "#e7e0da"

    // Surface hierarchy
    readonly property color surface: "#201c18"
    readonly property color surfaceDim: "#181410"
    readonly property color surfaceBright: "#493c31"
    readonly property color surfaceContainerLowest: "#15120e"
    readonly property color surfaceContainerLow: "#27211c"
    readonly property color surfaceContainer: "#302822"
    readonly property color surfaceContainerHigh: "#3c322a"
    readonly property color surfaceContainerHighest: "#4c3f34"

    // Surface content
    readonly property color on_surface: "#e7e0da"
    readonly property color on_surface_variant: "#c2b7ad"
    readonly property color inverseSurface: "#e5e0dc"
    readonly property color inverse_on_surface: "#251e18"
    readonly property color inversePrimary: "#bd6e28"

    // Outline and overlays
    readonly property color outline: "#847262"
    readonly property color outlineVariant: "#42372e"
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
