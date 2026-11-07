import QtQuick
import QtQuick.Effects

import "../core" as Core

Item {
    id: root

    // ============================================================
    // NEXA DIRECTIONAL CONTACT SHADOW
    // ============================================================

    property Item targetItem: parent

    // 0 = small / subtle (cards, top bar pills)
    // 1 = medium (popups / dropdowns)
    // 2 = large (island / modal overlays)
    property int elevation: 0
    property real spread: 0.08

    property int cornerRadius:
        targetItem && targetItem.radius !== undefined
        ? targetItem.radius
        : Core.NexaTokens.radiusMd

    readonly property real corner: Math.max(0, root.cornerRadius)

    anchors.fill: targetItem ? targetItem : undefined

    opacity: targetItem ? targetItem.opacity : 1.0
    scale: targetItem ? targetItem.scale : 1.0
    transformOrigin: targetItem ? targetItem.transformOrigin : Item.Center

    z: -1
    visible: targetItem !== null && targetItem.visible && (targetItem.opacity === undefined || targetItem.opacity > 0.01) && Core.NexaOptics.contactShadow

    // 1. Crisp Physical Contact Shadow Line (Thin 1px grounded line directly below bottom edge)
    Rectangle {
        id: contactLine
        anchors.bottom: parent.bottom
        anchors.bottomMargin: -1
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.corner > 0 ? Math.max(0, parent.width - root.corner * 1.5) : parent.width
        height: 1
        visible: root.elevation > 0 && Core.NexaOptics.contactShadow
        color: Qt.rgba(0, 0, 0, root.elevation === 1 ? 0.35 : 0.50)
    }

    // 2. Focused Under-Drop Penumbra
    Rectangle {
        id: penumbra
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.elevation === 2 ? -6 : (root.elevation === 1 ? -4 : -2)
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.corner > 0 ? Math.max(0, parent.width - root.corner * 0.8) : parent.width
        height: root.elevation === 2 ? 14 : (root.elevation === 1 ? 8 : 4)
        radius: height / 2
        opacity: root.elevation === 2 ? 0.45 : (root.elevation === 1 ? 0.30 : 0.15)
        color: Qt.rgba(0, 0, 0, 0.85)

        layer.enabled: true
        layer.effect: MultiEffect {
            blur: (root.elevation === 2 ? 0.8 : (root.elevation === 1 ? 0.5 : 0.3)) * Core.NexaOptics.shadowBlurFactor
            blurMax: 32
        }
    }
}

