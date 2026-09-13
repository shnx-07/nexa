import QtQuick
import Qt5Compat.GraphicalEffects

import ".." as Nexa

Item {
    id: root

    // ============================================================
    // NEXA SHADOW
    //
    // High-performance, GPU-accelerated shadow component for:
    //   - Dynamic Island
    //   - Side panels & Launcher overlays
    //   - Floating cards & Popups
    // ============================================================

    property Item targetItem: parent

    // 0 = small / subtle (cards)
    // 1 = medium (popups / menus)
    // 2 = large (island / main overlays)
    property int elevation: 1

    property color shadowColor:
        Nexa.Theme.shadow

    property real shadowOpacity:
        elevation <= 0
        ? Nexa.Theme.shadowOpacitySm
        : elevation === 1
            ? Nexa.Theme.shadowOpacityMd
            : Nexa.Theme.shadowOpacityLg

    property int glowRadius:
        elevation <= 0
        ? Nexa.Theme.shadowBlurSm
        : elevation === 1
            ? Nexa.Theme.shadowBlurMd
            : Nexa.Theme.shadowBlurLg

    property int verticalOffset:
        elevation <= 0
        ? Nexa.Theme.shadowOffsetSm
        : elevation === 1
            ? Nexa.Theme.shadowOffsetMd
            : Nexa.Theme.shadowOffsetLg

    property int horizontalOffset: 0
    property real spread: 0.08

    property int cornerRadius:
        targetItem && targetItem.radius !== undefined
        ? targetItem.radius
        : Nexa.Theme.radiusMd

    anchors.fill: targetItem ? targetItem : undefined
    anchors.topMargin: verticalOffset
    anchors.bottomMargin: -verticalOffset
    anchors.leftMargin: horizontalOffset
    anchors.rightMargin: -horizontalOffset

    z: -1
    visible: targetItem !== null

    RectangularGlow {
        anchors.fill: parent
        glowRadius: root.glowRadius
        spread: root.spread
        color: Qt.rgba(
            root.shadowColor.r,
            root.shadowColor.g,
            root.shadowColor.b,
            root.shadowOpacity
        )
        cornerRadius: root.cornerRadius + root.glowRadius

        // The glow is a procedural shader, not a texture sample, so
        // by default it re-runs on the GPU every frame it's marked
        // dirty — including every frame of a parent's opacity/scale
        // fade (popup/tooltip open-close), even though the shadow's
        // own shape never actually changes during that fade.
        // `cached: true` rasterizes it once and only re-renders when
        // its own inputs (size/color/elevation) change, so it just
        // rides along as a cheap composited layer during motion.
        cached: true
    }
}

