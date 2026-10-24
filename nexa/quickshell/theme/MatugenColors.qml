pragma Singleton
import QtQuick

QtObject {
    // Primary
    readonly property color primary: "#b30086"
    readonly property color on_primary: "#ffffff"
    readonly property color primaryContainer: "#ffd8ea"
    readonly property color on_primary_container: "#3c002b"

    // Secondary
    readonly property color secondary: "#7e5260"
    readonly property color on_secondary: "#ffffff"
    readonly property color secondaryContainer: "#ffd9e3"
    readonly property color on_secondary_container: "#31101d"

    // Tertiary
    readonly property color tertiary: "#8a4c53"
    readonly property color on_tertiary: "#ffffff"
    readonly property color tertiaryContainer: "#ffdadc"
    readonly property color on_tertiary_container: "#380b13"

    // Background
    readonly property color background: "#fff8f8"
    readonly property color on_background: "#24181e"

    // Surface hierarchy
    readonly property color surface: "#fff8f8"
    readonly property color surfaceDim: "#ead4dd"
    readonly property color surfaceBright: "#fff8f8"

    readonly property color surfaceContainerLowest: "#ffffff"
    readonly property color surfaceContainerLow: "#fff0f5"
    readonly property color surfaceContainer: "#ffe8f1"
    readonly property color surfaceContainerHigh: "#f9e2eb"
    readonly property color surfaceContainerHighest: "#f3dde6"

    // Surface content
    readonly property color on_surface: "#24181e"
    readonly property color on_surface_variant: "#52434a"

    readonly property color inverseSurface: "#3a2d33"
    readonly property color inverse_on_surface: "#ffecf3"
    readonly property color inversePrimary: "#ffaeda"

    // Outline
    readonly property color outline: "#84727a"
    readonly property color outlineVariant: "#d6c1ca"
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

    // Info
    readonly property color info: "#1885aa"
    readonly property color on_info: "#ffffff"
    readonly property color infoContainer: "#cdeaf4"
    readonly property color on_info_container: "#073240"

    // Compatibility aliases
    readonly property color text: on_background
    readonly property color mutedText: on_surface_variant

    // Keep current NEXA compatibility
    readonly property color surfaceVariant: on_surface_variant
}
