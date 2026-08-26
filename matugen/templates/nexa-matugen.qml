pragma Singleton
import QtQuick

QtObject {
    readonly property color background: "{{colors.background.default.hex}}"
    readonly property color onBackground: "{{colors.on_background.default.hex}}"

    readonly property color surface: "{{colors.surface.default.hex}}"
    readonly property color surfaceDim: "{{colors.surface_dim.default.hex}}"
    readonly property color surfaceBright: "{{colors.surface_bright.default.hex}}"
    readonly property color surfaceVariant: "{{colors.surface_variant.default.hex}}"

    readonly property color surfaceContainer: "{{colors.surface_container.default.hex}}"
    readonly property color surfaceContainerLow: "{{colors.surface_container_low.default.hex}}"
    readonly property color surfaceContainerHigh: "{{colors.surface_container_high.default.hex}}"
    readonly property color surfaceContainerHighest: "{{colors.surface_container_highest.default.hex}}"

    readonly property color primary: "{{colors.primary.default.hex}}"
    readonly property color onPrimary: "{{colors.on_primary.default.hex}}"
    readonly property color primaryContainer: "{{colors.primary_container.default.hex}}"
    readonly property color onPrimaryContainer: "{{colors.on_primary_container.default.hex}}"

    readonly property color secondary: "{{colors.secondary.default.hex}}"
    readonly property color onSecondary: "{{colors.on_secondary.default.hex}}"
    readonly property color secondaryContainer: "{{colors.secondary_container.default.hex}}"
    readonly property color onSecondaryContainer: "{{colors.on_secondary_container.default.hex}}"

    readonly property color tertiary: "{{colors.tertiary.default.hex}}"
    readonly property color onTertiary: "{{colors.on_tertiary.default.hex}}"
    readonly property color tertiaryContainer: "{{colors.tertiary_container.default.hex}}"
    readonly property color onTertiaryContainer: "{{colors.on_tertiary_container.default.hex}}"

    readonly property color text: "{{colors.on_background.default.hex}}"
    readonly property color mutedText: "{{colors.on_surface_variant.default.hex}}"

    readonly property color error: "{{colors.error.default.hex}}"
    readonly property color onError: "{{colors.on_error.default.hex}}"
    readonly property color errorContainer: "{{colors.error_container.default.hex}}"

    readonly property color outline: "{{colors.outline.default.hex}}"
    readonly property color outlineVariant: "{{colors.outline_variant.default.hex}}"
    readonly property color shadow: "{{colors.shadow.default.hex}}"

    // NEXA semantic additions
    readonly property color warning: "#F5A623"
    readonly property color success: "#4CAF50"
    readonly property color info: primary
}
