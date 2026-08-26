import QtQuick
QtObject {
    // Primary
    readonly property color primary: "#a56c1d"
    readonly property color on_primary: "#ffffff"
    readonly property color primaryContainer: "#f4e4cd"
    readonly property color on_primary_container: "#492e08"

    // Secondary
    readonly property color secondary: "#9b5727"
    readonly property color on_secondary: "#ffffff"
    readonly property color secondaryContainer: "#f1ded0"
    readonly property color on_secondary_container: "#47240a"

    // Tertiary
    readonly property color tertiary: "#279b9b"
    readonly property color on_tertiary: "#ffffff"
    readonly property color tertiaryContainer: "#d0f1f1"
    readonly property color on_tertiary_container: "#0a4747"

    // Background
    readonly property color background: "#f8f8f6"
    readonly property color on_background: "#262017"

    // Surface hierarchy
    readonly property color surface: "#f8f8f6"
    readonly property color surfaceDim: "#e7e1da"
    readonly property color surfaceBright: "#fdfcfc"
    readonly property color surfaceContainerLowest: "#ffffff"
    readonly property color surfaceContainerLow: "#f2f0ed"
    readonly property color surfaceContainer: "#ece9e4"
    readonly property color surfaceContainerHigh: "#e4dfd8"
    readonly property color surfaceContainerHighest: "#dcd5cb"

    // Surface content
    readonly property color on_surface: "#262017"
    readonly property color on_surface_variant: "#5e5445"
    readonly property color inverseSurface: "#352f27"
    readonly property color inverse_on_surface: "#f3f0ed"
    readonly property color inversePrimary: "#efc78f"

    // Outline and overlays
    readonly property color outline: "#9d8f7b"
    readonly property color outlineVariant: "#d5cec3"
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
