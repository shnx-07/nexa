import QtQuick
QtObject {
    // Primary
    readonly property color primary: "#7e9cd8"
    readonly property color on_primary: "#1f1f28"
    readonly property color primaryContainer: "#2a2a37"
    readonly property color on_primary_container: "#7e9cd8"
    // Secondary
    readonly property color secondary: "#957fb8"
    readonly property color on_secondary: "#1f1f28"
    readonly property color secondaryContainer: "#363646"
    readonly property color on_secondary_container: "#957fb8"
    // Tertiary
    readonly property color tertiary: "#d27e99"
    readonly property color on_tertiary: "#1f1f28"
    readonly property color tertiaryContainer: "#54546d"
    readonly property color on_tertiary_container: "#d27e99"
    // Background
    readonly property color background: "#1f1f28"
    readonly property color on_background: "#dcd7ba"
    // Surface hierarchy
    readonly property color surface: "#1f1f28"
    readonly property color surfaceDim: "#181820"
    readonly property color surfaceBright: "#54546d"
    readonly property color surfaceContainerLowest: "#181820"
    readonly property color surfaceContainerLow: "#1f1f28"
    readonly property color surfaceContainer: "#2a2a37"
    readonly property color surfaceContainerHigh: "#363646"
    readonly property color surfaceContainerHighest: "#54546d"
    // Surface content
    readonly property color on_surface: "#dcd7ba"
    readonly property color on_surface_variant: "#c8c093"
    readonly property color inverseSurface: "#dcd7ba"
    readonly property color inverse_on_surface: "#1f1f28"
    readonly property color inversePrimary: "#658594"
    // Outline and overlays
    readonly property color outline: "#727169"
    readonly property color outlineVariant: "#363646"
    readonly property color shadow: "#000000"
    readonly property color scrim: "#000000"
    // Error
    readonly property color error: "#c34043"
    readonly property color on_error: "#1f1f28"
    readonly property color errorContainer: "#363646"
    readonly property color on_error_container: "#e82424"
    // Success
    readonly property color success: "#98bb6c"
    readonly property color on_success: "#1f1f28"
    readonly property color successContainer: "#363646"
    readonly property color on_success_container: "#98bb6c"
    // Warning
    readonly property color warning: "#e6c384"
    readonly property color on_warning: "#1f1f28"
    readonly property color warningContainer: "#363646"
    readonly property color on_warning_container: "#ff9e3b"
    // Information
    readonly property color info: "#7aa89f"
    readonly property color on_info: "#1f1f28"
    readonly property color infoContainer: "#363646"
    readonly property color on_info_container: "#7aa89f"
}
