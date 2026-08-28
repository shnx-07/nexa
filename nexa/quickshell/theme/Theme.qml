pragma Singleton

import QtQuick
import "." as ThemeParts


QtObject {
    id: root


    // ============================================================
    // CORE PALETTE
    // ============================================================

    readonly property color background:
        ThemeParts.MatugenColors.background

    readonly property color backgroundText:
        ThemeParts.MatugenColors.backgroundText


    // ============================================================
    // SURFACES
    // ============================================================

    readonly property color surface:
        ThemeParts.MatugenColors.surface

    readonly property color surfaceDim:
        ThemeParts.MatugenColors.surfaceDim

    readonly property color surfaceBright:
        ThemeParts.MatugenColors.surfaceBright

    readonly property color surfaceVariant:
        ThemeParts.MatugenColors.surfaceVariant

    readonly property color surfaceContainer:
        ThemeParts.MatugenColors.surfaceContainer

    readonly property color surfaceContainerLow:
        ThemeParts.MatugenColors.surfaceContainerLow

    readonly property color surfaceContainerHigh:
        ThemeParts.MatugenColors.surfaceContainerHigh

    readonly property color surfaceContainerHighest:
        ThemeParts.MatugenColors.surfaceContainerHighest


    // ============================================================
    // TEXT
    // ============================================================

    readonly property color text:
        ThemeParts.MatugenColors.text

    readonly property color mutedText:
        ThemeParts.MatugenColors.mutedText


    // ============================================================
    // PRIMARY
    // ============================================================

    readonly property color primary:
        ThemeParts.MatugenColors.primary

    readonly property color primaryText:
        ThemeParts.MatugenColors.primaryText

    readonly property color primaryContainer:
        ThemeParts.MatugenColors.primaryContainer

    readonly property color primaryContainerText:
        ThemeParts.MatugenColors.primaryContainerText


    // ============================================================
    // SECONDARY
    // ============================================================

    readonly property color secondary:
        ThemeParts.MatugenColors.secondary

    readonly property color secondaryText:
        ThemeParts.MatugenColors.secondaryText

    readonly property color secondaryContainer:
        ThemeParts.MatugenColors.secondaryContainer

    readonly property color secondaryContainerText:
        ThemeParts.MatugenColors.secondaryContainerText


    // ============================================================
    // TERTIARY
    // ============================================================

    readonly property color tertiary:
        ThemeParts.MatugenColors.tertiary

    readonly property color tertiaryText:
        ThemeParts.MatugenColors.tertiaryText

    readonly property color tertiaryContainer:
        ThemeParts.MatugenColors.tertiaryContainer

    readonly property color tertiaryContainerText:
        ThemeParts.MatugenColors.tertiaryContainerText


    // ============================================================
    // STATUS COLORS
    // ============================================================

    readonly property color error:
        ThemeParts.MatugenColors.error

    readonly property color errorText:
        ThemeParts.MatugenColors.errorText

    readonly property color errorContainer:
        ThemeParts.MatugenColors.errorContainer

    readonly property color warning:
        ThemeParts.MatugenColors.warning

    readonly property color success:
        ThemeParts.MatugenColors.success

    readonly property color info:
        ThemeParts.MatugenColors.info


    // ============================================================
    // OUTLINES / SHADOW
    // ============================================================

    readonly property color outline:
        ThemeParts.MatugenColors.outline

    readonly property color outlineVariant:
        ThemeParts.MatugenColors.outlineVariant

    readonly property color shadow:
        ThemeParts.MatugenColors.shadowColor


    // ============================================================
    // SEMANTIC OVERLAYS / ACCENT SURFACES
    //
    // All accent colors come from the active Matugen palette.
    // These tokens give NEXA more depth and color without letting
    // individual modules invent their own colors.
    //
    // Use neutral surfaces for normal structure and these accent
    // surfaces only for active, selected or important UI.
    // ============================================================

    readonly property color scrim:
        Qt.rgba(0, 0, 0, 0.55)

    readonly property color scrimLight:
        Qt.rgba(0, 0, 0, 0.30)

    readonly property color scrimHeavy:
        Qt.rgba(0, 0, 0, 0.72)


    // ------------------------------------------------------------
    // INTERACTION OVERLAYS
    // ------------------------------------------------------------

    // Normal pointer hover.
    readonly property color hover:
        Qt.rgba(primary.r, primary.g, primary.b, 0.12)

    // Stronger hover for buttons and interactive cards.
    readonly property color hoverStrong:
        Qt.rgba(primary.r, primary.g, primary.b, 0.18)

    // Pressed/clicked state.
    readonly property color pressed:
        Qt.rgba(primary.r, primary.g, primary.b, 0.25)

    // Keyboard/input focus state.
    readonly property color focus:
        Qt.rgba(primary.r, primary.g, primary.b, 0.32)


    // ------------------------------------------------------------
    // ACCENT-TINTED SURFACES
    //
    // Do not use these on every card. They are intended to create
    // hierarchy and allow the wallpaper/Matugen palette to become
    // visible in important areas of the shell.
    // ------------------------------------------------------------

    readonly property color primarySurface:
        Qt.rgba(primary.r, primary.g, primary.b, 0.18)

    readonly property color primarySurfaceStrong:
        Qt.rgba(primary.r, primary.g, primary.b, 0.26)

    readonly property color secondarySurface:
        Qt.rgba(secondary.r, secondary.g, secondary.b, 0.16)

    readonly property color secondarySurfaceStrong:
        Qt.rgba(secondary.r, secondary.g, secondary.b, 0.24)

    readonly property color tertiarySurface:
        Qt.rgba(tertiary.r, tertiary.g, tertiary.b, 0.16)

    readonly property color tertiarySurfaceStrong:
        Qt.rgba(tertiary.r, tertiary.g, tertiary.b, 0.24)


    // ------------------------------------------------------------
    // SELECTED / ACTIVE STATES
    // ------------------------------------------------------------

    // Solid selected state when a full primary fill is appropriate.
    readonly property color selected:
        primary

    readonly property color selectedText:
        primaryText

    // Preferred selected background for toggles, tabs and buttons.
    readonly property color selectedSurface:
        Qt.rgba(primary.r, primary.g, primary.b, 0.26)

    // Strong selected state for emphasized controls.
    readonly property color selectedSurfaceStrong:
        Qt.rgba(primary.r, primary.g, primary.b, 0.36)

    // Border for active/selected controls.
    readonly property color selectedBorder:
        Qt.rgba(primary.r, primary.g, primary.b, 0.65)


    // ------------------------------------------------------------
    // ACCENT GLOW COLORS
    //
    // These are color tokens only. Components decide how to render
    // the glow. Use sparingly for active workspaces, playing media,
    // important Island events and other high-value active states.
    // ------------------------------------------------------------

    readonly property color accentGlow:
        Qt.rgba(primary.r, primary.g, primary.b, 0.30)

    readonly property color accentGlowStrong:
        Qt.rgba(primary.r, primary.g, primary.b, 0.45)


    // ============================================================
    // DIVIDERS / BORDERS
    //
    // Surface contrast should provide most visual separation.
    // Borders stay subtle so NEXA feels layered rather than like a
    // collection of strongly outlined boxes.
    // ============================================================

    readonly property color divider:
        Qt.rgba(
            outline.r,
            outline.g,
            outline.b,
            0.22
        )

    readonly property color border:
        Qt.rgba(
            outline.r,
            outline.g,
            outline.b,
            0.32
        )

    readonly property color borderStrong:
        Qt.rgba(
            outline.r,
            outline.g,
            outline.b,
            0.55
        )

    readonly property color focusBorder:
        primary


    // ============================================================
    // COMMON COMPONENT SURFACES
    //
    // Default neutral hierarchy:
    //   panelBackground
    //       -> cardBackground
    //       -> cardBackgroundElevated
    //
    // Accent-tinted UI should use primarySurface, secondarySurface,
    // tertiarySurface or selectedSurface instead of inventing color.
    // ============================================================

    readonly property color panelBackground:
        surfaceContainer

    readonly property color panelBackgroundElevated:
        surfaceContainerHigh

    // Normal information card / section.
    readonly property color cardBackground:
        surfaceContainerHigh

    // Floating, nested or visually important neutral card.
    readonly property color cardBackgroundElevated:
        surfaceContainerHighest

    // Calm secondary card/background.
    readonly property color cardBackgroundSubtle:
        surfaceContainerLow

    // Popup/dropdown surface.
    readonly property color popupBackground:
        surfaceContainerHighest

    // Dynamic Island surfaces.
    readonly property color islandBackground:
        surfaceContainer

    readonly property color islandBackgroundExpanded:
        surfaceContainerHigh

    // Standard button surfaces.
    readonly property color buttonBackground:
        surfaceContainerHigh

    readonly property color buttonBackgroundHover:
        hoverStrong

    readonly property color buttonBackgroundPressed:
        pressed

    // Inputs/search fields.
    readonly property color inputBackground:
        surfaceContainerLow

    readonly property color inputBackgroundFocus:
        surfaceContainer


    // ------------------------------------------------------------
    // INTERACTIVE CARD SURFACES
    //
    // Use when the entire card is clickable/interactive.
    // Static information cards should stay on cardBackground.
    // ------------------------------------------------------------

    readonly property color interactiveCard:
        cardBackground

    readonly property color interactiveCardHover:
        Qt.rgba(primary.r, primary.g, primary.b, 0.12)

    readonly property color interactiveCardPressed:
        Qt.rgba(primary.r, primary.g, primary.b, 0.20)


    // ============================================================
    // GLASS / TRANSLUCENT SURFACES
    // ============================================================

    readonly property color glassBackground:
        Qt.rgba(
            surfaceContainer.r,
            surfaceContainer.g,
            surfaceContainer.b,
            0.88
        )

    readonly property color glassBackgroundLight:
        Qt.rgba(
            surfaceContainer.r,
            surfaceContainer.g,
            surfaceContainer.b,
            0.72
        )

    readonly property color glassBorder:
        Qt.rgba(
            outline.r,
            outline.g,
            outline.b,
            0.40
        )


    // ============================================================
    // TYPOGRAPHY — FONT FAMILIES
    // ============================================================

    readonly property string fontFamily:
        "JetBrainsMono Nerd Font"

    readonly property string monoFontFamily:
        "JetBrainsMono Nerd Font"

    readonly property string uiFont:
        fontFamily

    readonly property string monoFont:
        monoFontFamily

    readonly property string iconFontFamily:
        "Symbols Nerd Font Mono"

    // ============================================================
    // LEGACY / COMPATIBILITY ALIASES
    //
    // Keep old names working while modules migrate to the newer
    // semantic tokens above.
    // ============================================================

    readonly property color selectedOverlay:
        selectedSurface

    readonly property int radiusFull:
        radiusPill


    // ============================================================
    // TYPOGRAPHY — FONT SIZES
    // ============================================================

    readonly property int fontSize2Xs: 9
    readonly property int fontSizeXs: 10
    readonly property int fontSizeSm: 12
    readonly property int fontSizeMd: 14
    readonly property int fontSizeLg: 16
    readonly property int fontSizeXl: 18
    readonly property int fontSize2Xl: 20
    readonly property int fontSizeTitle: 24
    readonly property int fontSizeDisplay: 32


    // ============================================================
    // TYPOGRAPHY — FONT WEIGHTS
    // ============================================================

    readonly property int fontWeightLight:
        Font.Light

    readonly property int fontWeightNormal:
        Font.Normal

    readonly property int fontWeightMedium:
        Font.Medium

    readonly property int fontWeightDemiBold:
        Font.DemiBold

    readonly property int fontWeightBold:
        Font.Bold


    // ============================================================
    // SPACING
    // ============================================================

    readonly property int spacing2Xs: 2
    readonly property int spacingXs: 4
    readonly property int spacingSm: 8
    readonly property int spacingMd: 12
    readonly property int spacingLg: 16
    readonly property int spacingXl: 24
    readonly property int spacing2Xl: 32
    readonly property int spacing3Xl: 48


    // ============================================================
    // RADII
    // ============================================================

    readonly property int radiusXs: 4
    readonly property int radiusSm: 8
    readonly property int radiusMd: 12
    readonly property int radiusLg: 16
    readonly property int radiusXl: 22
    readonly property int radius2Xl: 28

    readonly property int radiusPill: 999


    // ============================================================
    // BORDER WIDTHS
    // ============================================================

    readonly property real borderThin: 1
    readonly property real borderNormal: 1.5
    readonly property real borderStrongWidth: 2


    // ============================================================
    // ICON SIZES
    // ============================================================

    readonly property int icon2Xs: 12
    readonly property int iconXs: 14
    readonly property int iconSm: 16
    readonly property int iconMd: 20
    readonly property int iconLg: 24
    readonly property int iconXl: 28
    readonly property int icon2Xl: 32


    // ============================================================
    // CONTROL HEIGHTS
    // ============================================================

    readonly property int controlHeightXs: 24
    readonly property int controlHeightSm: 28
    readonly property int controlHeightMd: 36
    readonly property int controlHeightLg: 44
    readonly property int controlHeightXl: 52


    // ============================================================
    // SHELL DIMENSIONS
    // ============================================================

    readonly property int barHeight: 36

    readonly property int islandCompactHeight: 30
    readonly property int islandCompactWidth: 170

    readonly property int islandExpandedWidth: 420
    readonly property int islandExpandedMinHeight: 120

    readonly property int panelWidthSm: 340
    readonly property int panelWidthMd: 420
    readonly property int panelWidthLg: 460

    readonly property int popupWidthSm: 280
    readonly property int popupWidthMd: 360
    readonly property int popupWidthLg: 440


    // ============================================================
    // MOTION — DURATIONS
    //
    // Global animation timing.
    // Use these instead of hardcoded durations in modules.
    // ============================================================

    readonly property int animationInstant: 80
    readonly property int animationFast: 140
    readonly property int animationNormal: 220
    readonly property int animationSlow: 320
    readonly property int animationVerySlow: 450


    // ------------------------------------------------------------
    // SEMANTIC MOTION DURATIONS
    //
    // Prefer these in modules when the animation has a clear role.
    // This keeps motion consistent even if raw timings change later.
    // ------------------------------------------------------------

    // Hover and press feedback.
    readonly property int motionInteraction:
        animationFast

    // Toggle, tab and active-indicator movement.
    readonly property int motionSelection:
        180

    // Page/content transition.
    readonly property int motionPage:
        animationNormal

    // Popup/dropdown entrance and exit movement.
    readonly property int motionPopup:
        animationNormal

    // Larger panel/Island geometry changes.
    readonly property int motionLayout:
        animationSlow


    // ============================================================
    // MOTION — EASING
    // ============================================================

    // General UI movement.
    readonly property int easingStandard:
        Easing.OutCubic

    // Opening / appearing.
    readonly property int easingEnter:
        Easing.OutQuart

    // Closing / disappearing.
    readonly property int easingExit:
        Easing.InCubic

    // Stronger expressive movement.
    readonly property int easingEmphasized:
        Easing.OutBack

    // Smooth deceleration.
    readonly property int easingDecelerate:
        Easing.OutQuint

    // Fast departure.
    readonly property int easingAccelerate:
        Easing.InCubic

    readonly property int easingLinear:
        Easing.Linear


    // ============================================================
    // MOTION — INTERACTION SCALE
    //
    // Keep scaling subtle. Small controls may use hoverScale and
    // pressScale. Larger cards should use the gentler card values.
    // Never scale major panel/window containers on hover.
    // ============================================================

    readonly property real normalScale: 1.0

    // Buttons, icons and compact interactive controls.
    readonly property real hoverScale: 1.02
    readonly property real pressScale: 0.97

    // Larger interactive cards.
    readonly property real cardHoverScale: 1.008
    readonly property real cardPressScale: 0.992


    // ============================================================
    // MOTION — SLIDE DISTANCE
    //
    // Useful for popup/panel enter and exit animations.
    // ============================================================

    readonly property int slideSmall: 6
    readonly property int slideMedium: 12
    readonly property int slideLarge: 20


    // ============================================================
    // OPACITY
    // ============================================================

    readonly property real opacityHidden: 0.0

    readonly property real opacityDisabled: 0.38
    readonly property real opacitySecondary: 0.65
    readonly property real opacityMedium: 0.78
    readonly property real opacityStrong: 0.90

    readonly property real opacityFull: 1.0

    // Decorative accent opacity levels.
    readonly property real opacityAccentSoft: 0.55
    readonly property real opacityAccent: 0.75
    readonly property real opacityAccentStrong: 0.92


    // ============================================================
    // ELEVATION / SHADOW
    //
    // Surface contrast remains the main source of depth in NEXA.
    // Shadows are reserved for floating/elevated UI.
    //
    // Suggested use:
    //   Sm -> hover cards / small floating controls
    //   Md -> menus / popups
    //   Lg -> major floating panels / overlays
    // ============================================================

    readonly property real shadowOpacitySm: 0.14
    readonly property real shadowOpacityMd: 0.22
    readonly property real shadowOpacityLg: 0.30

    readonly property int shadowBlurSm: 8
    readonly property int shadowBlurMd: 16
    readonly property int shadowBlurLg: 28

    readonly property int shadowOffsetSm: 2
    readonly property int shadowOffsetMd: 4
    readonly property int shadowOffsetLg: 8


    // ============================================================
    // SCROLL PHYSICS
    //
    // Apply to every Flickable and ListView for consistent,
    // smooth, high-inertia scrolling across the entire shell.
    //
    // Qt defaults (1500 / 2500) are too snappy — items stop
    // almost immediately, making scrolling feel "stuck".
    // These values give a natural momentum feel.
    // ============================================================

    readonly property real flickDeceleration: 700
    readonly property real flickVelocityMax: 4500

    // ============================================================
    // SPRING ANIMATION
    //
    // Use for popup entrances, active indicator slides, and
    // any motion that benefits from slight overshoot.
    // ============================================================

    readonly property int animationSpring: 300
    readonly property int easingSpring: Easing.OutBack

    // PopEnter / PopExit durations (popup open/close)
    readonly property int popEnterDuration: 220
    readonly property int popExitDuration: 140

    // Stagger base delay per item (ms) for sequential card animations
    readonly property int staggerBase: 35


    // ============================================================
    // Z-LAYERS
    // ============================================================

    readonly property int zBackground: -100
    readonly property int zContent: 0
    readonly property int zFloating: 100
    readonly property int zPopup: 500
    readonly property int zOverlay: 1000
    readonly property int zCritical: 2000
}
