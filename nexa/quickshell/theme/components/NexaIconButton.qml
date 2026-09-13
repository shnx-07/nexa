import QtQuick
import ".." as Nexa

Rectangle {
    id: root
    property string icon: ""
    property bool selected: false
    property bool interactive: true
    property int iconSize: Nexa.Theme.iconSm
    property color iconColor: selected ? Nexa.Theme.primary : Nexa.Theme.mutedText
    signal clicked()

    readonly property bool hovered: interactive && mouse.containsMouse
    readonly property bool pressedState: interactive && mouse.pressed

    implicitWidth: Nexa.Theme.controlHeightMd
    implicitHeight: Nexa.Theme.controlHeightMd
    radius: Nexa.Theme.radiusMd
    antialiasing: true
    opacity: interactive ? Nexa.Theme.opacityFull : Nexa.Theme.opacityDisabled
    color: selected ? Nexa.Theme.selectedSurface
                    : pressedState ? Nexa.Theme.pressed
                    : hovered ? Nexa.Theme.hoverStrong : "transparent"
    border.width: selected ? Nexa.Theme.borderThin : 0
    border.color: Nexa.Theme.selectedBorder
    scale: pressedState ? Nexa.Theme.pressScale
                        : hovered ? Nexa.Theme.hoverScale
                        : Nexa.Theme.normalScale
    transformOrigin: Item.Center

    Text {
        anchors.centerIn: parent
        text: root.icon
        color: root.iconColor
        font.family: Nexa.Theme.iconFontFamily
        font.pixelSize: root.iconSize

        Behavior on color {
            ColorAnimation {
                duration: Nexa.Theme.motionInteraction
                easing.type: Nexa.Theme.easingStandard
                easing.bezierCurve: Nexa.Theme.easingFluidCurve
            }
        }
    }

    Behavior on color {
        ColorAnimation {
            duration: Nexa.Theme.motionInteraction
            easing.type: Nexa.Theme.easingStandard
            easing.bezierCurve: Nexa.Theme.easingFluidCurve
        }
    }
    Behavior on border.color {
        ColorAnimation {
            duration: Nexa.Theme.motionInteraction
            easing.type: Nexa.Theme.easingStandard
            easing.bezierCurve: Nexa.Theme.easingFluidCurve
        }
    }
    // Icon buttons sit densely packed in the bar — many of them can
    // be near the cursor at once. Scale is the most expensive of
    // these Behaviors, so it's the one gated by reducedMotion.
    Behavior on scale {
        enabled: !Nexa.Theme.reducedMotion
        NumberAnimation {
            duration: Nexa.Theme.motionInteraction
            easing.type: Nexa.Theme.easingStandard
            easing.bezierCurve: Nexa.Theme.easingFluidCurve
        }
    }
    Behavior on opacity {
        NumberAnimation {
            duration: Nexa.Theme.motionInteraction
            easing.type: Nexa.Theme.easingStandard
            easing.bezierCurve: Nexa.Theme.easingFluidCurve
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
