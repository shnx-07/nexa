import QtQuick
QtObject {
    // Primary
    readonly property color primary: "#a54a1d"
    readonly property color on_primary: "#ffffff"
    readonly property color primaryContainer: "#f4dacd"
    readonly property color on_primary_container: "#491e08"

    // Secondary
    readonly property color secondary: "#9b2744"
    readonly property color on_secondary: "#ffffff"
    readonly property color secondaryContainer: "#f1d0d8"
    readonly property color on_secondary_container: "#470a19"

    // Tertiary
    readonly property color tertiary: "#9b9127"
    readonly property color on_tertiary: "#ffffff"
    readonly property color tertiaryContainer: "#f1eed0"
    readonly property color on_tertiary_container: "#47420a"

    // Background
    readonly property color background: "#f8f7f6"
    readonly property color on_background: "#261c17"

    // Surface hierarchy
    readonly property color surface: "#f8f7f6"
    readonly property color surfaceDim: "#e7deda"
    readonly property color surfaceBright: "#fdfcfc"
    readonly property color surfaceContainerLowest: "#ffffff"
    readonly property color surfaceContainerLow: "#f2efed"
    readonly property color surfaceContainer: "#ece7e4"
    readonly property color surfaceContainerHigh: "#e4dcd8"
    readonly property color surfaceContainerHighest: "#dcd1cb"

    // Surface content
    readonly property color on_surface: "#261c17"
    readonly property color on_surface_variant: "#5e4e45"
    readonly property color inverseSurface: "#352c27"
    readonly property color inverse_on_surface: "#f3efed"
    readonly property color inversePrimary: "#efaf8f"

    // Outline and overlays
    readonly property color outline: "#9d877b"
    readonly property color outlineVariant: "#d5c9c3"
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
