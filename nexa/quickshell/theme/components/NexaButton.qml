import QtQuick
import QtQuick.Layouts
import ".." as Nexa

Rectangle {
    id: root
    property string text: ""
    property string icon: ""
    property bool selected: false
    property bool interactive: true
    property int iconSize: Nexa.Theme.iconSm
    property int textSize: Nexa.Theme.fontSizeSm
    property int horizontalPadding: Nexa.Theme.spacingMd
    signal clicked()

    readonly property bool hovered: interactive && mouse.containsMouse
    readonly property bool pressedState: interactive && mouse.pressed

    implicitWidth: content.implicitWidth + horizontalPadding * 2
    implicitHeight: Nexa.Theme.controlHeightMd
    radius: Nexa.Theme.radiusMd
    antialiasing: true
    opacity: interactive ? Nexa.Theme.opacityFull : Nexa.Theme.opacityDisabled
    color: selected ? Nexa.Theme.selectedSurface
                    : pressedState ? Nexa.Theme.buttonBackgroundPressed
                    : hovered ? Nexa.Theme.buttonBackgroundHover
                    : Nexa.Theme.buttonBackground
    border.width: Nexa.Theme.borderThin
    border.color: selected ? Nexa.Theme.selectedBorder : Nexa.Theme.border
    scale: pressedState ? Nexa.Theme.pressScale
                        : hovered ? Nexa.Theme.hoverScale
                        : Nexa.Theme.normalScale
    transformOrigin: Item.Center

    // Static glass highlight — a plain gradient fill, no shader,
    // no animation. Gives the button a touch of continuous-corner
    // depth instead of a flat color block.
    Rectangle {
        anchors.fill: parent
        anchors.margins: root.border.width
        radius: Math.max(0, root.radius - root.border.width)
        gradient: Gradient {
            GradientStop { position: 0.0; color: root.selected ? Nexa.Theme.edgeHighlightStrong : Nexa.Theme.edgeHighlight }
            GradientStop { position: 0.6; color: "transparent" }
        }
    }

    RowLayout {
        id: content
        anchors.centerIn: parent
        spacing: Nexa.Theme.spacingSm
        Text {
            visible: root.icon !== ""
            text: root.icon
            color: root.selected ? Nexa.Theme.primary : Nexa.Theme.text
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
        Text {
            visible: root.text !== ""
            text: root.text
            color: root.selected ? Nexa.Theme.primary : Nexa.Theme.text
            font.family: Nexa.Theme.fontFamily
            font.pixelSize: root.textSize
            font.weight: Nexa.Theme.fontWeightMedium
            Behavior on color {
                ColorAnimation {
                    duration: Nexa.Theme.motionInteraction
                    easing.type: Nexa.Theme.easingStandard
                    easing.bezierCurve: Nexa.Theme.easingFluidCurve
                }
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
    // Scale is the one transform-based Behavior here — skip it
    // under reducedMotion since it's the costliest to animate.
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
