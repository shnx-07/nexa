import QtQuick
import ".." as Nexa

Rectangle {
    id: root
    property string icon: ""
    property bool selected: false
    property bool interactive: true
    property int iconSize: Nexa.Theme.iconSm
    property color iconColor: selected ? Nexa.Theme.primary : (hovered ? Nexa.Theme.text : Nexa.Theme.mutedText)
    signal clicked()

    readonly property bool hovered: interactive && mouse.containsMouse
    readonly property bool pressedState: interactive && mouse.pressed

    implicitWidth: Nexa.Theme.controlHeightMd
    implicitHeight: Nexa.Theme.controlHeightMd
    radius: Nexa.Theme.nexaRounding === 0 ? 0 : Math.min(height / 2, Nexa.Theme.nexaRounding)
    antialiasing: true
    opacity: interactive ? Nexa.Theme.opacityFull : Nexa.Theme.opacityDisabled
    color: selected ? Nexa.Theme.selectedSurface
                    : pressedState ? Nexa.Theme.pressed
                    : hovered ? Nexa.Theme.hoverStrong : "transparent"
    border.width: Nexa.Theme.borderThin
    border.color: selected ? Nexa.Theme.selectedBorder
                           : (hovered ? Nexa.Theme.edgeHighlightStrong : "transparent")
    scale: pressedState ? Nexa.Theme.pressScale
                        : hovered ? Nexa.Theme.hoverScale
                        : Nexa.Theme.normalScale
    transformOrigin: Item.Center

    // Continuous-corner liquid glass highlight (top sheen on hover/selected)
    Rectangle {
        anchors.fill: parent
        anchors.margins: root.border.width
        radius: Math.max(0, root.radius - root.border.width)
        visible: root.selected || root.hovered
        opacity: root.selected ? 1.0 : (root.hovered ? 0.8 : 0.0)
        gradient: Gradient {
            GradientStop {
                position: 0.0
                color: root.selected ? Nexa.Theme.edgeHighlightStrong : Nexa.Theme.edgeHighlight
            }
            GradientStop { position: 0.6; color: "transparent" }
        }

        Behavior on opacity {
            NumberAnimation { duration: Nexa.Theme.animationFast }
        }
    }

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
    Behavior on scale {
        enabled: !Nexa.Theme.reducedMotion
        NexaSpring {
            section: "popups"
            customStiffness: 8.0
            customDamping: 0.28
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
