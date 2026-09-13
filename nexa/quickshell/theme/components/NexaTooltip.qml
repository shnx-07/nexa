import QtQuick
import ".." as Nexa

Rectangle {
    id: root
    property string text: ""
    property bool shown: false
    property int horizontalPadding: Nexa.Theme.spacingSm
    property int verticalPadding: Nexa.Theme.spacingXs

    visible: opacity > 0
    opacity: shown ? Nexa.Theme.opacityFull : Nexa.Theme.opacityHidden
    scale: shown ? Nexa.Theme.normalScale : 0.96
    implicitWidth: label.implicitWidth + horizontalPadding * 2
    implicitHeight: label.implicitHeight + verticalPadding * 2
    radius: Nexa.Theme.radiusSm
    antialiasing: true
    color: Nexa.Theme.popupBackground
    border.width: Nexa.Theme.borderThin
    border.color: Nexa.Theme.border
    z: Nexa.Theme.zOverlay

    NexaShadow {
        elevation: 0
        cornerRadius: Nexa.Theme.radiusSm
    }

    Text {
        id: label
        anchors.centerIn: parent
        text: root.text
        color: Nexa.Theme.text
        font.family: Nexa.Theme.fontFamily
        font.pixelSize: Nexa.Theme.fontSizeXs
    }

    Behavior on color {
        ColorAnimation {
            duration: Nexa.Theme.animationFast
            easing.type: Nexa.Theme.easingStandard
            easing.bezierCurve: Nexa.Theme.easingFluidCurve
        }
    }
    Behavior on border.color {
        ColorAnimation {
            duration: Nexa.Theme.animationFast
            easing.type: Nexa.Theme.easingStandard
            easing.bezierCurve: Nexa.Theme.easingFluidCurve
        }
    }
    Behavior on opacity {
        NumberAnimation {
            duration: root.shown ? Nexa.Theme.popEnterDuration : Nexa.Theme.popExitDuration
            easing.type: root.shown ? Nexa.Theme.easingStandard : Easing.InCubic
            easing.bezierCurve: Nexa.Theme.easingFluidCurve
        }
    }
    // Tooltips pop in constantly across the shell on hover — a
    // small spring makes them feel alive without costing anything
    // extra (still gated so reducedMotion just snaps in via opacity).
    Behavior on scale {
        enabled: !Nexa.Theme.reducedMotion
        NumberAnimation {
            duration: root.shown ? Nexa.Theme.popEnterDuration : Nexa.Theme.popExitDuration
            easing.type: root.shown ? Nexa.Theme.easingEnter : Nexa.Theme.easingExit
            easing.bezierCurve: Nexa.Theme.easingSpringCurve
        }
    }
}
