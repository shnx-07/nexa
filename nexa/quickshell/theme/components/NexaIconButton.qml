import QtQuick
import ".." as Nexa

Rectangle {
    id: root
    property string icon: ""
    property bool selected: false
    property bool interactive: true
    property int iconSize: Nexa.Theme.iconSm
    signal clicked()

    readonly property bool hovered: interactive && mouse.containsMouse
    readonly property bool pressedState: interactive && mouse.pressed

    implicitWidth: Nexa.Theme.controlHeightMd
    implicitHeight: Nexa.Theme.controlHeightMd
    radius: Nexa.Theme.radiusMd
    opacity: interactive ? Nexa.Theme.opacityFull : Nexa.Theme.opacityDisabled
    color: selected ? Nexa.Theme.selectedSurface
                    : pressedState ? Nexa.Theme.pressed
                    : hovered ? Nexa.Theme.hoverStrong : "transparent"
    border.width: selected ? Nexa.Theme.borderThin : 0
    border.color: Nexa.Theme.selectedBorder
    scale: pressedState ? Nexa.Theme.pressScale
                        : hovered ? Nexa.Theme.hoverScale
                        : Nexa.Theme.normalScale

    Text {
        anchors.centerIn: parent
        text: root.icon
        color: root.selected ? Nexa.Theme.primary : Nexa.Theme.mutedText
        font.family: Nexa.Theme.iconFontFamily
        font.pixelSize: root.iconSize
    }

    Behavior on color { ColorAnimation { duration: Nexa.Theme.motionInteraction } }
    Behavior on scale {
        NumberAnimation {
            duration: Nexa.Theme.motionInteraction
            easing.type: Nexa.Theme.easingStandard
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: root.interactive
        hoverEnabled: true
        cursorShape: root.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.clicked()
    }
}
