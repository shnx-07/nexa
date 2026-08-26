pragma Singleton
import QtQuick

QtObject {
    // Primary
    readonly property color primary: "#feb0d3"
    readonly property color on_primary: "#521d3a"
    readonly property color primaryContainer: "#6d3351"
    readonly property color on_primary_container: "#ffd8e7"

    // Secondary
    readonly property color secondary: "#e0bdcb"
    readonly property color on_secondary: "#412a34"
    readonly property color secondaryContainer: "#59404b"
    readonly property color on_secondary_container: "#fdd9e7"

    // Tertiary
    readonly property color tertiary: "#f2bb99"
    readonly property color on_tertiary: "#4a2810"
    readonly property color tertiaryContainer: "#643e24"
    readonly property color on_tertiary_container: "#ffdbc7"

    // Background
    readonly property color background: "#191114"
    readonly property color on_background: "#eedfe3"

    // Surface hierarchy
    readonly property color surface: "#191114"
    readonly property color surfaceDim: "#191114"
    readonly property color surfaceBright: "#40373a"

    readonly property color surfaceContainerLowest: "#130c0f"
    readonly property color surfaceContainerLow: "#21191c"
    readonly property color surfaceContainer: "#251d21"
    readonly property color surfaceContainerHigh: "#30282b"
    readonly property color surfaceContainerHighest: "#3b3236"

    // Surface content
    readonly property color on_surface: "#eedfe3"
    readonly property color on_surface_variant: "#d4c2c8"

    readonly property color inverseSurface: "#eedfe3"
    readonly property color inverse_on_surface: "#372e31"
    readonly property color inversePrimary: "#894a69"

    // Outline
    readonly property color outline: "#9d8d92"
    readonly property color outlineVariant: "#504348"
    readonly property color shadow: "#000000"
    readonly property color scrim: "#000000"

    // Error
    readonly property color error: "#ffb4ab"
    readonly property color on_error: "#690005"
    readonly property color errorContainer: "#93000a"
    readonly property color on_error_container: "#ffdad6"

    // Success
    readonly property color success: "#f2bb99"
    readonly property color on_success: "#4a2810"
    readonly property color successContainer: "#643e24"
    readonly property color on_success_container: "#ffdbc7"

    // Warning
    readonly property color warning: "#e0bdcb"
    readonly property color on_warning: "#412a34"
    readonly property color warningContainer: "#59404b"
    readonly property color on_warning_container: "#fdd9e7"

    // Info
    readonly property color info: "#feb0d3"
    readonly property color on_info: "#521d3a"
    readonly property color infoContainer: "#6d3351"
    readonly property color on_info_container: "#ffd8e7"

    // Compatibility aliases
    readonly property color text: on_background
    readonly property color mutedText: on_surface_variant

    // Keep current NEXA compatibility
    readonly property color surfaceVariant: on_surface_variant
}
