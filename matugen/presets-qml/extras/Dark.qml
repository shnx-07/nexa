import QtQuick

QtObject {
    // Primary
    readonly property color primary: "#d0bcff"
    readonly property color on_primary: "#381e72"
    readonly property color primaryContainer: "#4f378b"
    readonly property color on_primary_container: "#eaddff"

    // Secondary
    readonly property color secondary: "#ccc2dc"
    readonly property color on_secondary: "#332d41"
    readonly property color secondaryContainer: "#4a4458"
    readonly property color on_secondary_container: "#e8def8"

    // Tertiary
    readonly property color tertiary: "#efb8c8"
    readonly property color on_tertiary: "#492532"
    readonly property color tertiaryContainer: "#633b48"
    readonly property color on_tertiary_container: "#ffd8e4"

    // Background
    readonly property color background: "#141218"
    readonly property color on_background: "#e6e0e9"

    // Surface hierarchy
    readonly property color surface: "#141218"
    readonly property color surfaceDim: "#141218"
    readonly property color surfaceBright: "#3b383e"

    readonly property color surfaceContainerLowest: "#0f0d13"
    readonly property color surfaceContainerLow: "#1d1b20"
    readonly property color surfaceContainer: "#211f26"
    readonly property color surfaceContainerHigh: "#2b2930"
    readonly property color surfaceContainerHighest: "#36343b"

    // Surface content
    readonly property color on_surface: "#e6e0e9"
    readonly property color on_surface_variant: "#cac4d0"

    readonly property color inverseSurface: "#e6e0e9"
    readonly property color inverse_on_surface: "#322f35"
    readonly property color inversePrimary: "#6750a4"

    // Outline and overlays
    readonly property color outline: "#938f99"
    readonly property color outlineVariant: "#49454f"
    readonly property color shadow: "#000000"
    readonly property color scrim: "#000000"

    // Error
    readonly property color error: "#f2b8b5"
    readonly property color on_error: "#601410"
    readonly property color errorContainer: "#8c1d18"
    readonly property color on_error_container: "#f9dedc"

    // Success
    readonly property color success: "#81c995"
    readonly property color on_success: "#0b3d20"
    readonly property color successContainer: "#155d35"
    readonly property color on_success_container: "#a8f0bd"

    // Warning
    readonly property color warning: "#f9c74f"
    readonly property color on_warning: "#3f2e00"
    readonly property color warningContainer: "#5d4300"
    readonly property color on_warning_container: "#ffe08a"

    // Information
    readonly property color info: "#8ab4f8"
    readonly property color on_info: "#002f65"
    readonly property color infoContainer: "#174f8f"
    readonly property color on_info_container: "#d4e3ff"
}
