pragma Singleton
import QtQuick

QtObject {
    // Primary
    readonly property color primary: "#a6c8ff"
    readonly property color on_primary: "#02315f"
    readonly property color primaryContainer: "#234776"
    readonly property color on_primary_container: "#d5e3ff"

    // Secondary
    readonly property color secondary: "#bdc7dc"
    readonly property color on_secondary: "#273141"
    readonly property color secondaryContainer: "#3d4758"
    readonly property color on_secondary_container: "#d9e3f8"

    // Tertiary
    readonly property color tertiary: "#dabde2"
    readonly property color on_tertiary: "#3d2846"
    readonly property color tertiaryContainer: "#553f5d"
    readonly property color on_tertiary_container: "#f7d8ff"

    // Background
    readonly property color background: "#111318"
    readonly property color on_background: "#e1e2e9"

    // Surface hierarchy
    readonly property color surface: "#111318"
    readonly property color surfaceDim: "#111318"
    readonly property color surfaceBright: "#37393e"

    readonly property color surfaceContainerLowest: "#0c0e13"
    readonly property color surfaceContainerLow: "#191c20"
    readonly property color surfaceContainer: "#1d2024"
    readonly property color surfaceContainerHigh: "#282a2f"
    readonly property color surfaceContainerHighest: "#32353a"

    // Surface content
    readonly property color on_surface: "#e1e2e9"
    readonly property color on_surface_variant: "#c4c6cf"

    readonly property color inverseSurface: "#e1e2e9"
    readonly property color inverse_on_surface: "#2e3035"
    readonly property color inversePrimary: "#3d5f90"

    // Outline
    readonly property color outline: "#8d9199"
    readonly property color outlineVariant: "#43474e"
    readonly property color shadow: "#000000"
    readonly property color scrim: "#000000"

    // Error
    readonly property color error: "#ffb4ab"
    readonly property color on_error: "#690005"
    readonly property color errorContainer: "#93000a"
    readonly property color on_error_container: "#ffdad6"

    // Success
    readonly property color success: "#dabde2"
    readonly property color on_success: "#3d2846"
    readonly property color successContainer: "#553f5d"
    readonly property color on_success_container: "#f7d8ff"

    // Warning
    readonly property color warning: "#bdc7dc"
    readonly property color on_warning: "#273141"
    readonly property color warningContainer: "#3d4758"
    readonly property color on_warning_container: "#d9e3f8"

    // Info
    readonly property color info: "#a6c8ff"
    readonly property color on_info: "#02315f"
    readonly property color infoContainer: "#234776"
    readonly property color on_info_container: "#d5e3ff"

    // Compatibility aliases
    readonly property color text: on_background
    readonly property color mutedText: on_surface_variant

    // Keep current NEXA compatibility
    readonly property color surfaceVariant: on_surface_variant
}
