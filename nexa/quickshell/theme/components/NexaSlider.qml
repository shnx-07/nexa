import QtQuick
import ".." as Nexa

Item {
    id: root
    property real from: 0
    property real to: 100
    property real value: 0
    property real stepSize: 1
    property bool interactive: true
    signal moved(real value)
    signal released(real value)

    implicitWidth: 180
    implicitHeight: Nexa.Theme.controlHeightMd

    readonly property real normalizedValue:
        to <= from ? 0 : Math.max(0, Math.min(1, (value - from) / (to - from)))

    function valueFromPosition(x) {
        const n = Math.max(0, Math.min(1, x / Math.max(1, track.width)))
        let v = from + n * (to - from)
        if (stepSize > 0)
            v = Math.round((v - from) / stepSize) * stepSize + from
        return Math.max(from, Math.min(to, v))
    }

    Rectangle {
        id: track
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: 6
        radius: Nexa.Theme.radiusPill
        color: Nexa.Theme.surfaceContainerHighest

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: parent.width * root.normalizedValue
            radius: parent.radius
            color: Nexa.Theme.primary
        }

        Rectangle {
            width: 16
            height: 16
            radius: width / 2
            anchors.verticalCenter: parent.verticalCenter
            x: Math.max(-width / 2, Math.min(track.width - width / 2,
                                             track.width * root.normalizedValue - width / 2))
            color: Nexa.Theme.primary
            border.width: Nexa.Theme.borderThin
            border.color: Nexa.Theme.selectedBorder
            scale: mouse.pressed ? 1.12 : mouse.containsMouse ? 1.06 : 1.0
            Behavior on scale {
                NumberAnimation {
                    duration: Nexa.Theme.motionInteraction
                    easing.type: Nexa.Theme.easingStandard
                }
            }
        }

        MouseArea {
            id: mouse
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: Nexa.Theme.controlHeightMd
            enabled: root.interactive
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            preventStealing: true

            onPressed: event => {
                root.value = root.valueFromPosition(event.x)
                root.moved(root.value)
            }
            onPositionChanged: event => {
                if (!pressed) return
                root.value = root.valueFromPosition(event.x)
                root.moved(root.value)
            }
            onReleased: root.released(root.value)
        }
    }
}
