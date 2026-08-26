import QtQuick
import ".." as Nexa

Rectangle {
    id: root
    property bool checked: false
    property bool interactive: true
    signal toggled(bool checked)

    implicitWidth: 42
    implicitHeight: 24
    radius: Nexa.Theme.radiusPill
    opacity: interactive ? Nexa.Theme.opacityFull : Nexa.Theme.opacityDisabled
    color: checked ? Nexa.Theme.selectedSurfaceStrong
                   : Nexa.Theme.surfaceContainerHighest
    border.width: Nexa.Theme.borderThin
    border.color: checked ? Nexa.Theme.selectedBorder : Nexa.Theme.border

    Rectangle {
        width: 18
        height: 18
        radius: width / 2
        anchors.verticalCenter: parent.verticalCenter
        x: root.checked ? root.width - width - 3 : 3
        color: root.checked ? Nexa.Theme.primary : Nexa.Theme.mutedText
        scale: mouse.pressed ? 0.90 : 1.0

        Behavior on x {
            NumberAnimation {
                duration: Nexa.Theme.motionSelection
                easing.type: Nexa.Theme.easingEnter
            }
        }
        Behavior on color { ColorAnimation { duration: Nexa.Theme.motionInteraction } }
        Behavior on scale { NumberAnimation { duration: Nexa.Theme.motionInteraction } }
    }

    Behavior on color { ColorAnimation { duration: Nexa.Theme.motionInteraction } }
    Behavior on border.color { ColorAnimation { duration: Nexa.Theme.motionInteraction } }

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: root.interactive
        hoverEnabled: true
        cursorShape: root.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: {
            root.checked = !root.checked
            root.toggled(root.checked)
        }
    }
}
