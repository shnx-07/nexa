pragma Singleton
import QtQuick

QtObject {
    // Primary
    readonly property color primary: "#c0000a"
    readonly property color on_primary: "#ffffff"
    readonly property color primaryContainer: "#ffdad5"
    readonly property color on_primary_container: "#410001"

    // Secondary
    readonly property color secondary: "#80543e"
    readonly property color on_secondary: "#ffffff"
    readonly property color secondaryContainer: "#ffdbcc"
    readonly property color on_secondary_container: "#311304"

    // Tertiary
    readonly property color tertiary: "#845324"
    readonly property color on_tertiary: "#ffffff"
    readonly property color tertiaryContainer: "#ffdcc1"
    readonly property color on_tertiary_container: "#2e1500"

    // Background
    readonly property color background: "#fff8f7"
    readonly property color on_background: "#271816"

    // Surface hierarchy
    readonly property color surface: "#fff8f7"
    readonly property color surfaceDim: "#f0d4d0"
    readonly property color surfaceBright: "#fff8f7"

    readonly property color surfaceContainerLowest: "#ffffff"
    readonly property color surfaceContainerLow: "#fff0ee"
    readonly property color surfaceContainer: "#ffe9e6"
    readonly property color surfaceContainerHigh: "#ffe2de"
    readonly property color surfaceContainerHighest: "#f9dcd8"

    // Surface content
    readonly property color on_surface: "#271816"
    readonly property color on_surface_variant: "#554240"

    readonly property color inverseSurface: "#3d2c2a"
    readonly property color inverse_on_surface: "#ffedea"
    readonly property color inversePrimary: "#ffb4aa"

    // Outline
    readonly property color outline: "#89726f"
    readonly property color outlineVariant: "#dcc0bd"
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

    // Keep current NEXA compatibility (map to proper surface container, not text)
    readonly property color surfaceVariant: surfaceContainerHigh
}
