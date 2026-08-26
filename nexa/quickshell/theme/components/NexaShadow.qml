import QtQuick
import Qt5Compat.GraphicalEffects

import ".." as Nexa


Item {
    id: root

    // ============================================================
    // NEXA SHADOW
    //
    // Reusable shadow layer for floating/elevated UI.
    //
    // Intended for:
    //   - popups
    //   - floating cards
    //   - menus
    //   - larger overlays
    //
    // Keep shadows subtle. Surface contrast remains the primary
    // source of depth in NEXA.
    // ============================================================


    property Item sourceItem: null

    // 0 = small
    // 1 = medium
    // 2 = large
    property int elevation: 1

    property color shadowColor:
        Nexa.Theme.shadow

    property real shadowOpacity:
        elevation <= 0
        ? Nexa.Theme.shadowOpacitySm
        : elevation === 1
            ? Nexa.Theme.shadowOpacityMd
            : Nexa.Theme.shadowOpacityLg

    property int blurRadius:
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

    property bool cached: true


    visible:
        sourceItem !== null

    anchors.fill:
        sourceItem


    DropShadow {
        anchors.fill:
            parent

        source:
            root.sourceItem

        horizontalOffset:
            root.horizontalOffset

        verticalOffset:
            root.verticalOffset

        radius:
            root.blurRadius

        samples:
            Math.max(
                17,
                root.blurRadius * 2 + 1
            )

        color:
            Qt.rgba(
                root.shadowColor.r,
                root.shadowColor.g,
                root.shadowColor.b,
                root.shadowOpacity
            )

        transparentBorder:
            true

        cached:
            root.cached
    }
}
