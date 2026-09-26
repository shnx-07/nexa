pragma Singleton
import QtQuick

QtObject {
    // Primary
    readonly property color primary: "#f2c000"
    readonly property color on_primary: "#3d2f00"
    readonly property color primaryContainer: "#584400"
    readonly property color on_primary_container: "#ffe08e"

    // Secondary
    readonly property color secondary: "#d3c78e"
    readonly property color on_secondary: "#373006"
    readonly property color secondaryContainer: "#4f471b"
    readonly property color on_secondary_container: "#f0e3a8"

    // Tertiary
    readonly property color tertiary: "#cbca80"
    readonly property color on_tertiary: "#323200"
    readonly property color tertiaryContainer: "#49490b"
    readonly property color on_tertiary_container: "#e8e799"

    // Background
    readonly property color background: "#181306"
    readonly property color on_background: "#ede1ca"

    // Surface hierarchy
    readonly property color surface: "#181306"
    readonly property color surfaceDim: "#181306"
    readonly property color surfaceBright: "#3f3928"

    readonly property color surfaceContainerLowest: "#120e03"
    readonly property color surfaceContainerLow: "#201b0d"
    readonly property color surfaceContainer: "#251f11"
    readonly property color surfaceContainerHigh: "#2f291a"
    readonly property color surfaceContainerHighest: "#3b3424"

    // Surface content
    readonly property color on_surface: "#ede1ca"
    readonly property color on_surface_variant: "#d0c5af"

    readonly property color inverseSurface: "#ede1ca"
    readonly property color inverse_on_surface: "#363020"
    readonly property color inversePrimary: "#755b00"

    // Outline
    readonly property color outline: "#99907b"
    readonly property color outlineVariant: "#4d4635"
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

    // Info
    readonly property color info: "#79cfec"
    readonly property color on_info: "#062b37"
    readonly property color infoContainer: "#1c3e4a"
    readonly property color on_info_container: "#a3e0f5"

    // Compatibility aliases
    readonly property color text: on_background
    readonly property color mutedText: on_surface_variant

    // Keep current NEXA compatibility
    readonly property color surfaceVariant: on_surface_variant
}
