pragma Singleton
import QtQuick

QtObject {
    // Primary
    readonly property color primary: "{{colors.primary}}"
    readonly property color on_primary: "{{colors.on_primary}}"
    readonly property color primaryContainer: "{{colors.primary_container}}"
    readonly property color on_primary_container: "{{colors.on_primary_container}}"

    // Secondary
    readonly property color secondary: "{{colors.secondary}}"
    readonly property color on_secondary: "{{colors.on_secondary}}"
    readonly property color secondaryContainer: "{{colors.secondary_container}}"
    readonly property color on_secondary_container: "{{colors.on_secondary_container}}"

    // Tertiary
    readonly property color tertiary: "{{colors.tertiary}}"
    readonly property color on_tertiary: "{{colors.on_tertiary}}"
    readonly property color tertiaryContainer: "{{colors.tertiary_container}}"
    readonly property color on_tertiary_container: "{{colors.on_tertiary_container}}"

    // Background
    readonly property color background: "{{colors.background}}"
    readonly property color on_background: "{{colors.on_background}}"

    // Surface hierarchy
    readonly property color surface: "{{colors.surface}}"
    readonly property color surfaceDim: "{{colors.surface_dim}}"
    readonly property color surfaceBright: "{{colors.surface_bright}}"

    readonly property color surfaceContainerLowest: "{{colors.surface_container_lowest}}"
    readonly property color surfaceContainerLow: "{{colors.surface_container_low}}"
    readonly property color surfaceContainer: "{{colors.surface_container}}"
    readonly property color surfaceContainerHigh: "{{colors.surface_container_high}}"
    readonly property color surfaceContainerHighest: "{{colors.surface_container_highest}}"

    // Surface content
    readonly property color on_surface: "{{colors.on_surface}}"
    readonly property color on_surface_variant: "{{colors.on_surface_variant}}"

    readonly property color inverseSurface: "{{colors.inverse_surface}}"
    readonly property color inverse_on_surface: "{{colors.inverse_on_surface}}"
    readonly property color inversePrimary: "{{colors.inverse_primary}}"

    // Outline
    readonly property color outline: "{{colors.outline}}"
    readonly property color outlineVariant: "{{colors.outline_variant}}"
    readonly property color shadow: "{{colors.shadow}}"
    readonly property color scrim: "{{colors.scrim}}"

    // Error
    readonly property color error: "{{colors.error}}"
    readonly property color on_error: "{{colors.on_error}}"
    readonly property color errorContainer: "{{colors.error_container}}"
    readonly property color on_error_container: "{{colors.on_error_container}}"

    // Success
    readonly property color success: "{{colors.success}}"
    readonly property color on_success: "{{colors.on_success}}"
    readonly property color successContainer: "{{colors.success_container}}"
    readonly property color on_success_container: "{{colors.on_success_container}}"

    // Warning
    readonly property color warning: "{{colors.warning}}"
    readonly property color on_warning: "{{colors.on_warning}}"
    readonly property color warningContainer: "{{colors.warning_container}}"
    readonly property color on_warning_container: "{{colors.on_warning_container}}"

    // Info
    readonly property color info: "{{colors.info}}"
    readonly property color on_info: "{{colors.on_info}}"
    readonly property color infoContainer: "{{colors.info_container}}"
    readonly property color on_info_container: "{{colors.on_info_container}}"

    // Compatibility aliases
    readonly property color text: on_background
    readonly property color mutedText: on_surface_variant

    // Keep current NEXA compatibility
    readonly property color surfaceVariant: on_surface_variant
}
