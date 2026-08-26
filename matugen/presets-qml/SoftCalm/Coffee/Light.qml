import QtQuick
QtObject {
    // Primary
    readonly property color primary: "#a55c1d"
    readonly property color on_primary: "#ffffff"
    readonly property color primaryContainer: "#f4dfcd"
    readonly property color on_primary_container: "#492708"

    // Secondary
    readonly property color secondary: "#9b4a27"
    readonly property color on_secondary: "#ffffff"
    readonly property color secondaryContainer: "#f1dad0"
    readonly property color on_secondary_container: "#471d0a"

    // Tertiary
    readonly property color tertiary: "#9b8427"
    readonly property color on_tertiary: "#ffffff"
    readonly property color tertiaryContainer: "#f1ead0"
    readonly property color on_tertiary_container: "#473b0a"

    // Background
    readonly property color background: "#f8f7f6"
    readonly property color on_background: "#261e17"

    // Surface hierarchy
    readonly property color surface: "#f8f7f6"
    readonly property color surfaceDim: "#e7e0da"
    readonly property color surfaceBright: "#fdfcfc"
    readonly property color surfaceContainerLowest: "#ffffff"
    readonly property color surfaceContainerLow: "#f2f0ed"
    readonly property color surfaceContainer: "#ece8e4"
    readonly property color surfaceContainerHigh: "#e4ddd8"
    readonly property color surfaceContainerHighest: "#dcd3cb"

    // Surface content
    readonly property color on_surface: "#261e17"
    readonly property color on_surface_variant: "#5e5145"
    readonly property color inverseSurface: "#352d27"
    readonly property color inverse_on_surface: "#f3efed"
    readonly property color inversePrimary: "#efbc8f"

    // Outline and overlays
    readonly property color outline: "#9d8b7b"
    readonly property color outlineVariant: "#d5cbc3"
    readonly property color shadow: "#000000"
    readonly property color scrim: "#000000"

    // Error
    readonly property color error: "#bb1b28"
    readonly property color on_error: "#ffffff"
    readonly property color errorContainer: "#f7d4d7"
    readonly property color on_error_container: "#49080e"

    // Success
    readonly property color success: "#1e8f44"
    readonly property color on_success: "#ffffff"
    readonly property color successContainer: "#d0f1db"
    readonly property color on_success_container: "#093e1b"

    // Warning
    readonly property color warning: "#aa690e"
    readonly property color on_warning: "#ffffff"
    readonly property color warningContainer: "#f7e4c9"
    readonly property color on_warning_container: "#422905"

    // Information
    readonly property color info: "#1885aa"
    readonly property color on_info: "#ffffff"
    readonly property color infoContainer: "#cdeaf4"
    readonly property color on_info_container: "#073240"
}
