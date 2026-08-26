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
        color: root.backgroundColor
        border.width: Nexa.Theme.borderThin
        border.color: Nexa.Theme.border
    }

    enter: Transition {
        ParallelAnimation {
            NumberAnimation {
                property: "opacity"
                from: 0
                to: 1
                duration: Nexa.Theme.popEnterDuration
            }
            NumberAnimation {
                property: "scale"
                from: 0.98
                to: 1
                duration: Nexa.Theme.popEnterDuration
                easing.type: Nexa.Theme.easingEnter
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
            }
            NumberAnimation {
                property: "scale"
                from: 1
                to: 0.98
                duration: Nexa.Theme.popExitDuration
                easing.type: Nexa.Theme.easingExit
            }
        }
    }
}
