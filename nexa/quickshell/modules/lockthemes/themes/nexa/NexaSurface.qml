import QtQuick
import "../../../lockscreen" as NativeLock

Item {
    id: root

    required property var ctx
    property url shot
    property bool shown: true
    property bool still: false
    property real minScale: 0.7

    Item {
        id: scaler
        width: 1920
        height: 1080
        scale: Math.min(root.width / 1920, root.height / 1080)
        transformOrigin: Item.TopLeft
        x: Math.max(0, (root.width - 1920 * scale) / 2)
        y: Math.max(0, (root.height - 1080 * scale) / 2)

        NativeLock.LockSurface {
            anchors.fill: parent
            enabled: !root.still
            still: root.still
            onAuthenticationSucceeded: {
                if (root.ctx && typeof root.ctx.unlock === "function")
                    root.ctx.unlock();
            }
        }
    }
}

