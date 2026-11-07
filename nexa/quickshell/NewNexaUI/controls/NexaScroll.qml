import QtQuick
import "../core" as Core

Flickable {
    id: root

    clip: true
    boundsBehavior: Flickable.StopAtBounds

    // Smooth subtle scroll indicator
    Rectangle {
        id: scrollBar
        anchors.right: parent.right
        anchors.rightMargin: 2
        width: 4
        radius: Core.NexaTokens.radiusPill
        color: Core.NexaColors.alpha(Core.NexaColors.onSurface, 0.25)

        visible: root.contentHeight > root.height
        opacity: (root.moving || root.flicking) ? 1.0 : 0.0

        y: root.visibleArea.yPosition * root.height
        height: Math.max(20, root.visibleArea.heightRatio * root.height)

        Behavior on opacity {
            NumberAnimation { duration: Core.NexaMotion.durationNormal }
        }
    }
}
