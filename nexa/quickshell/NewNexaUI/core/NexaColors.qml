pragma Singleton
import QtQuick
import "." as Core

QtObject {
    id: root

    // ============================================================
    // MATERIAL 3 COLOR ROLES
    // 100% Dynamic - sourced exclusively from MatugenColors
    // ============================================================

    // Primary
    readonly property color primary: Core.MatugenColors.primary
    readonly property color onPrimary: Core.MatugenColors.on_primary
    readonly property color primaryContainer: Core.MatugenColors.primaryContainer
    readonly property color onPrimaryContainer: Core.MatugenColors.on_primary_container

    // Secondary
    readonly property color secondary: Core.MatugenColors.secondary
    readonly property color onSecondary: Core.MatugenColors.on_secondary
    readonly property color secondaryContainer: Core.MatugenColors.secondaryContainer
    readonly property color onSecondaryContainer: Core.MatugenColors.on_secondary_container

    // Tertiary
    readonly property color tertiary: Core.MatugenColors.tertiary
    readonly property color onTertiary: Core.MatugenColors.on_tertiary
    readonly property color tertiaryContainer: Core.MatugenColors.tertiaryContainer
    readonly property color onTertiaryContainer: Core.MatugenColors.on_tertiary_container

    // Surfaces & Containers (Dynamically translucent when Glass Transparency / hyprglass is active)
    readonly property color surface: Core.NexaOptics.glassMode
        ? Qt.rgba(Core.MatugenColors.surface.r, Core.MatugenColors.surface.g, Core.MatugenColors.surface.b, 0.35)
        : Core.MatugenColors.surface

    readonly property color surfaceDim: Core.NexaOptics.glassMode
        ? Qt.rgba(Core.MatugenColors.surfaceDim.r, Core.MatugenColors.surfaceDim.g, Core.MatugenColors.surfaceDim.b, 0.28)
        : Core.MatugenColors.surfaceDim

    readonly property color surfaceBright: Core.NexaOptics.glassMode
        ? Qt.rgba(Core.MatugenColors.surfaceBright.r, Core.MatugenColors.surfaceBright.g, Core.MatugenColors.surfaceBright.b, 0.45)
        : Core.MatugenColors.surfaceBright

    readonly property color surfaceContainerLowest: Core.NexaOptics.glassMode
        ? Qt.rgba(Core.MatugenColors.surfaceContainerLowest.r, Core.MatugenColors.surfaceContainerLowest.g, Core.MatugenColors.surfaceContainerLowest.b, 0.20)
        : Core.MatugenColors.surfaceContainerLowest

    readonly property color surfaceContainerLow: Core.NexaOptics.glassMode
        ? Qt.rgba(Core.MatugenColors.surfaceContainerLow.r, Core.MatugenColors.surfaceContainerLow.g, Core.MatugenColors.surfaceContainerLow.b, 0.25)
        : Core.MatugenColors.surfaceContainerLow

    readonly property color surfaceContainer: Core.NexaOptics.glassMode
        ? Qt.rgba(Core.MatugenColors.surfaceContainer.r, Core.MatugenColors.surfaceContainer.g, Core.MatugenColors.surfaceContainer.b, 0.32)
        : Core.MatugenColors.surfaceContainer

    readonly property color surfaceContainerHigh: Core.NexaOptics.glassMode
        ? Qt.rgba(Core.MatugenColors.surfaceContainerHigh.r, Core.MatugenColors.surfaceContainerHigh.g, Core.MatugenColors.surfaceContainerHigh.b, 0.42)
        : Core.MatugenColors.surfaceContainerHigh

    readonly property color surfaceContainerHighest: Core.NexaOptics.glassMode
        ? Qt.rgba(Core.MatugenColors.surfaceContainerHighest.r, Core.MatugenColors.surfaceContainerHighest.g, Core.MatugenColors.surfaceContainerHighest.b, 0.50)
        : Core.MatugenColors.surfaceContainerHighest

    readonly property color surfaceVariant: Core.NexaOptics.glassMode
        ? Qt.rgba(Core.MatugenColors.surfaceVariant.r, Core.MatugenColors.surfaceVariant.g, Core.MatugenColors.surfaceVariant.b, 0.38)
        : Core.MatugenColors.surfaceVariant

    // Background & Canvas
    readonly property color background: Core.MatugenColors.background
    readonly property color onBackground: Core.MatugenColors.on_background
    readonly property color onSurface: Core.MatugenColors.on_surface
    readonly property color onSurfaceVariant: Core.MatugenColors.on_surface_variant

    // Inverse Roles
    readonly property color inverseSurface: Core.MatugenColors.inverseSurface
    readonly property color inverseOnSurface: Core.MatugenColors.inverse_on_surface
    readonly property color inversePrimary: Core.MatugenColors.inversePrimary

    // Compatibility aliases for lock theme & legacy roles
    readonly property color on_surface: onSurface
    readonly property color on_surface_variant: onSurfaceVariant
    readonly property color inverse_surface: inverseSurface
    readonly property color inverse_on_surface: inverseOnSurface
    readonly property color primary_fixed_dim: primary
    readonly property color tertiary_fixed_dim: tertiary
    readonly property color on_primary: onPrimary
    readonly property color on_tertiary: onTertiary
    readonly property color surface_container: surfaceContainer
    readonly property color surface_container_lowest: surfaceContainerLowest
    readonly property color surface_container_high: surfaceContainerHigh

    // Outlines & Dividers (Derived dynamically from Matugen & Tokens)
    readonly property color outline: Core.MatugenColors.outline
    readonly property color outlineVariant: Core.MatugenColors.outlineVariant
    readonly property color borderStrong: Core.NexaOptics.glassMode
        ? ((Core.NexaTokens.nexaRounding === 0 || Core.NexaTokens.windowBorderSize > 0) ? primary : Qt.rgba(1, 1, 1, 0.38))
        : ((Core.NexaTokens.nexaRounding === 0 || Core.NexaTokens.windowBorderSize > 0)
            ? primary
            : Qt.rgba(outline.r, outline.g, outline.b, 0.55))

    readonly property color focusBorder: primary

    readonly property color borderSubtle: Core.NexaOptics.glassMode
        ? ((Core.NexaTokens.nexaRounding === 0 || Core.NexaTokens.windowBorderSize > 0) ? Qt.rgba(primary.r, primary.g, primary.b, 0.40) : Qt.rgba(1, 1, 1, 0.15))
        : ((Core.NexaTokens.nexaRounding === 0 || Core.NexaTokens.windowBorderSize > 0)
            ? Qt.rgba(primary.r, primary.g, primary.b, 0.45)
            : Qt.rgba(outline.r, outline.g, outline.b, 0.18))

    readonly property color border: Core.NexaOptics.glassMode
        ? ((Core.NexaTokens.nexaRounding === 0 || Core.NexaTokens.windowBorderSize > 0) ? Qt.rgba(primary.r, primary.g, primary.b, 0.70) : Qt.rgba(1, 1, 1, 0.22))
        : ((Core.NexaTokens.nexaRounding === 0 || Core.NexaTokens.windowBorderSize > 0)
            ? Qt.rgba(primary.r, primary.g, primary.b, 0.85)
            : Qt.rgba(outline.r, outline.g, outline.b, 0.32))

    readonly property color hover: alpha(Core.MatugenColors.on_surface, 0.08)
    readonly property color hoverStrong: alpha(Core.MatugenColors.on_surface, 0.14)
    readonly property color active: alpha(Core.MatugenColors.primary, 0.16)

    // Shadows & Scrim
    readonly property color shadow: Core.MatugenColors.shadow
    readonly property color scrim: Core.MatugenColors.scrim

    // Feedback & Semantic Status (Dynamic from MatugenColors)
    readonly property color error: Core.MatugenColors.error
    readonly property color onError: Core.MatugenColors.on_error
    readonly property color errorContainer: Core.MatugenColors.errorContainer
    readonly property color onErrorContainer: Core.MatugenColors.on_error_container

    readonly property color success: Core.MatugenColors.success
    readonly property color successOn: Core.MatugenColors.on_success
    readonly property color successContainer: Core.MatugenColors.successContainer
    readonly property color successContainerOn: Core.MatugenColors.on_success_container

    readonly property color warning: Core.MatugenColors.warning
    readonly property color warningOn: Core.MatugenColors.on_warning
    readonly property color warningContainer: Core.MatugenColors.warningContainer
    readonly property color warningContainerOn: Core.MatugenColors.on_warning_container

    readonly property color info: Core.MatugenColors.info
    readonly property color infoOn: Core.MatugenColors.on_info
    readonly property color infoContainer: Core.MatugenColors.infoContainer
    readonly property color infoContainerOn: Core.MatugenColors.on_info_container

    // Common Text Aliases
    readonly property color text: Core.MatugenColors.text
    readonly property color mutedText: Core.MatugenColors.mutedText

    // Card, Island & Glass Roles (Dynamic glass transparency)
    readonly property color cardBackground: surfaceContainer
    readonly property color cardBorder: Core.NexaOptics.glassMode
        ? Qt.rgba(1, 1, 1, 0.15)
        : alpha(Core.MatugenColors.outlineVariant, 0.35)
    readonly property color islandBackground: surfaceContainer
    readonly property color islandBackgroundExpanded: surfaceContainerHigh
    readonly property color glassBackground: Core.NexaOptics.glassMode
        ? Qt.rgba(surfaceContainer.r, surfaceContainer.g, surfaceContainer.b, 0.28)
        : alpha(Core.MatugenColors.surface, 0.88)
    readonly property color glassBorder: Core.NexaOptics.glassMode
        ? Qt.rgba(outline.r, outline.g, outline.b, 0.40)
        : alpha(Core.MatugenColors.outlineVariant, 0.30)

    // ============================================================
    // DYNAMIC COLOR TRANSFORMERS
    // ============================================================

    function alpha(c, a) {
        if (!c) return Qt.rgba(0, 0, 0, a);
        return Qt.rgba(c.r, c.g, c.b, Math.max(0.0, Math.min(1.0, a)))
    }

    function withAlpha(c, a) {
        return alpha(c, a);
    }

    function hoverOverlay(baseColor) {
        return alpha(root.onSurface, 0.08)
    }

    function pressOverlay(baseColor) {
        return alpha(root.onSurface, 0.14)
    }

    function activeOverlay(baseColor) {
        return alpha(root.primary, 0.16)
    }
}
