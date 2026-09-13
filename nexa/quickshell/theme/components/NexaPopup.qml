import QtQuick
import QtQuick.Controls
import ".." as Nexa

Popup {
    id: root
    property int popupPadding: Nexa.Theme.spacingMd
    property color backgroundColor: Nexa.Theme.popupBackground
    property int cornerRadius: Nexa.Theme.radiusLg

    padding: popupPadding
    modal: false
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    background: Rectangle {
        radius: root.cornerRadius
        antialiasing: true
        color: root.backgroundColor
        border.width: Nexa.Theme.borderThin
        border.color: Nexa.Theme.borderStrong

        NexaShadow {
            elevation: 1
            cornerRadius: root.cornerRadius
        }

        // Static glass highlight for depth on the popup surface.
        Rectangle {
            anchors.fill: parent
            anchors.margins: parent.border.width
            radius: Math.max(0, parent.radius - parent.border.width)
            gradient: Gradient {
                GradientStop { position: 0.0; color: Nexa.Theme.edgeHighlight }
                GradientStop { position: 0.35; color: "transparent" }
            }
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
    }

    enter: Transition {
        ParallelAnimation {
            NumberAnimation {
                property: "opacity"
                from: 0
                to: 1
                duration: Nexa.Theme.popEnterDuration
                easing.type: Nexa.Theme.easingStandard
                easing.bezierCurve: Nexa.Theme.easingFluidCurve
            }
            NumberAnimation {
                property: "scale"
                from: 0.94
                to: 1
                duration: Nexa.Theme.popEnterDuration
                easing.type: Nexa.Theme.easingEnter
                easing.bezierCurve: Nexa.Theme.easingSpringCurve
            }
        }
    }

    exit: Transition {
        ParallelAnimation {
            NumberAnimation {
                property: "opacity"
                from: 1
                to: 0
                duration: Nexa.Theme.popExitDuration
                easing.type: Easing.InCubic
            }
            NumberAnimation {
                property: "scale"
                from: 1
                to: 0.94
                duration: Nexa.Theme.popExitDuration
                easing.type: Nexa.Theme.easingExit
            }
        }
    }
}
