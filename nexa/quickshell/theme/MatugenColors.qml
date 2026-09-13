pragma Singleton
import QtQuick

QtObject {
    // Primary
    readonly property color primary: "#ffb4a4"
    readonly property color on_primary: "#630e00"
    readonly property color primaryContainer: "#8c1800"
    readonly property color on_primary_container: "#ffdad3"

    // Secondary
    readonly property color secondary: "#f3ba9b"
    readonly property color on_secondary: "#4a2812"
    readonly property color secondaryContainer: "#643d26"
    readonly property color on_secondary_container: "#ffdbc9"

    // Tertiary
    readonly property color tertiary: "#f6bb7d"
    readonly property color on_tertiary: "#492900"
    readonly property color tertiaryContainer: "#663e0a"
    readonly property color on_tertiary_container: "#ffdcbc"

    // Background
    readonly property color background: "#1a1b26"
    readonly property color on_background: "#c0caf5"

    // Surface hierarchy
    readonly property color surface: "#1a1b26"
    readonly property color surfaceDim: "#16161e"
    readonly property color surfaceBright: "#414868"

    readonly property color surfaceContainerLowest: "#16161e"
    readonly property color surfaceContainerLow: "#1a1b26"
    readonly property color surfaceContainer: "#1f2335"
    readonly property color surfaceContainerHigh: "#292e42"
    readonly property color surfaceContainerHighest: "#414868"

    // Surface content
    readonly property color on_surface: "#c0caf5"
    readonly property color on_surface_variant: "#a9b1d6"

    readonly property color inverseSurface: "#c0caf5"
    readonly property color inverse_on_surface: "#1a1b26"
    readonly property color inversePrimary: "#3d59a1"

    // Outline
    readonly property color outline: "#565f89"
    readonly property color outlineVariant: "#292e42"
    readonly property color shadow: "#000000"
    readonly property color scrim: "#000000"

    // Error
    readonly property color error: "#f7768e"
    readonly property color on_error: "#1a1b26"
    readonly property color errorContainer: "#292e42"
    readonly property color on_error_container: "#f7768e"

    // Success
    readonly property color success: "#9ece6a"
    readonly property color on_success: "#1a1b26"
    readonly property color successContainer: "#292e42"
    readonly property color on_success_container: "#9ece6a"

    // Warning
    readonly property color warning: "#e0af68"
    readonly property color on_warning: "#1a1b26"
    readonly property color warningContainer: "#292e42"
    readonly property color on_warning_container: "#e0af68"

    // Info
    readonly property color info: "#7dcfff"
    readonly property color on_info: "#1a1b26"
    readonly property color infoContainer: "#292e42"
    readonly property color on_info_container: "#7dcfff"

    // Compatibility aliases
    readonly property color text: on_background
    readonly property color mutedText: on_surface_variant

    // Keep current NEXA compatibility
    readonly property color surfaceVariant: on_surface_variant
}
