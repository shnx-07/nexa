import QtQuick
import ".." as Nexa

Rectangle {
    id: root

    implicitWidth: 18
    implicitHeight: 3

    radius: Nexa.Theme.radiusPill
    color: Nexa.Theme.primary

    Behavior on color {
        ColorAnimation {
            duration: Nexa.Theme.animationNormal
            easing.type: Nexa.Theme.easingStandard
            easing.bezierCurve: Nexa.Theme.easingFluidCurve
        }
    }
}

