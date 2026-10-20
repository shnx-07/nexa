pragma Singleton
import QtQuick
import Quickshell
import ".." as ThemeParts

Singleton {
    id: root

    // Core Material 3 color roles dynamically mapped from Nexa's active palette:
    property color background:                 ThemeParts.MatugenColors.background
    property color error:                      ThemeParts.MatugenColors.error
    property color error_container:            ThemeParts.MatugenColors.errorContainer
    property color inverse_on_surface:         ThemeParts.MatugenColors.inverse_on_surface
    property color inverse_primary:            ThemeParts.MatugenColors.inversePrimary
    property color inverse_surface:            ThemeParts.MatugenColors.inverseSurface
    property color on_background:              ThemeParts.MatugenColors.on_background
    property color on_error:                   ThemeParts.MatugenColors.on_error
    property color on_error_container:         ThemeParts.MatugenColors.on_error_container
    property color on_primary:                 ThemeParts.MatugenColors.on_primary
    property color on_primary_container:       ThemeParts.MatugenColors.on_primary_container
    property color on_primary_fixed:           ThemeParts.MatugenColors.primaryContainer
    property color on_primary_fixed_variant:   ThemeParts.MatugenColors.on_primary_container
    property color on_secondary:               ThemeParts.MatugenColors.on_secondary
    property color on_secondary_container:     ThemeParts.MatugenColors.on_secondary_container
    property color on_secondary_fixed:         ThemeParts.MatugenColors.secondaryContainer
    property color on_secondary_fixed_variant: ThemeParts.MatugenColors.on_secondary_container
    property color on_surface:                 ThemeParts.MatugenColors.on_surface
    property color on_surface_variant:         ThemeParts.MatugenColors.on_surface_variant
    property color on_tertiary:                ThemeParts.MatugenColors.on_tertiary
    property color on_tertiary_container:      ThemeParts.MatugenColors.on_tertiary_container
    property color on_tertiary_fixed:          ThemeParts.MatugenColors.tertiaryContainer
    property color on_tertiary_fixed_variant:  ThemeParts.MatugenColors.on_tertiary_container
    property color outline:                    ThemeParts.MatugenColors.outline
    property color outline_variant:            ThemeParts.MatugenColors.outlineVariant
    property color primary:                    ThemeParts.MatugenColors.primary
    property color primary_container:          ThemeParts.MatugenColors.primaryContainer
    property color primary_fixed:              ThemeParts.MatugenColors.primaryContainer
    property color primary_fixed_dim:          ThemeParts.MatugenColors.primary
    property color scrim:                      ThemeParts.MatugenColors.scrim
    property color secondary:                  ThemeParts.MatugenColors.secondary
    property color secondary_container:        ThemeParts.MatugenColors.secondaryContainer
    property color secondary_fixed:            ThemeParts.MatugenColors.secondaryContainer
    property color secondary_fixed_dim:        ThemeParts.MatugenColors.secondary
    property color shadow:                     ThemeParts.MatugenColors.shadow
    property color source_color:               ThemeParts.MatugenColors.primary
    property color surface:                    ThemeParts.MatugenColors.surface
    property color surface_bright:             ThemeParts.MatugenColors.surfaceBright
    property color surface_container:          ThemeParts.MatugenColors.surfaceContainer
    property color surface_container_high:     ThemeParts.MatugenColors.surfaceContainerHigh
    property color surface_container_highest:  ThemeParts.MatugenColors.surfaceContainerHighest
    property color surface_container_low:      ThemeParts.MatugenColors.surfaceContainerLow
    property color surface_container_lowest:   ThemeParts.MatugenColors.surfaceContainerLowest
    property color surface_dim:                ThemeParts.MatugenColors.surfaceDim
    property color surface_tint:               ThemeParts.MatugenColors.primary
    property color surface_variant:            ThemeParts.MatugenColors.surfaceContainerHigh
    property color tertiary:                   ThemeParts.MatugenColors.tertiary
    property color tertiary_container:         ThemeParts.MatugenColors.tertiaryContainer
    property color tertiary_fixed:             ThemeParts.MatugenColors.tertiaryContainer
    property color tertiary_fixed_dim:         ThemeParts.MatugenColors.tertiary

    readonly property color accent:      primary
    readonly property color onAccent:    on_primary
    readonly property color surfaceHigh: surface_container_high
    readonly property color text:        on_surface
    readonly property color bg:          background

    function withAlpha(base, a) {
        const c = Qt.color(base)
        return Qt.rgba(c.r, c.g, c.b, c.a * a)
    }
}
