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
        id: thumb
        width: mouse.pressed ? 21 : 18
        height: 18
        radius: height / 2
        anchors.verticalCenter: parent.verticalCenter
        x: root.checked ? root.width - width - 3 : 3
        color: root.checked ? Nexa.Theme.primary : Nexa.Theme.mutedText

        Behavior on width {
            NumberAnimation {
                duration: Nexa.Theme.motionInteraction
                easing.type: Easing.OutCubic
            }
        }
        Behavior on x {
            NumberAnimation {
                duration: Nexa.Theme.motionSelection
                easing.type: Easing.InOutCubic
            }
        }
        Behavior on color {
            ColorAnimation {
                duration: Nexa.Theme.motionInteraction
                easing.type: Easing.OutCubic
            }
        }
    }

    Behavior on color {
        ColorAnimation {
            duration: Nexa.Theme.motionInteraction
            easing.type: Easing.OutCubic
        }
    }
    Behavior on border.color {
        ColorAnimation {
            duration: Nexa.Theme.motionInteraction
            easing.type: Easing.OutCubic
        }
    }
    Behavior on opacity {
        NumberAnimation {
            duration: Nexa.Theme.motionInteraction
            easing.type: Easing.OutCubic
        }
    }

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
