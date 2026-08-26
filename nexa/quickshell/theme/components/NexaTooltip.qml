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
    color: Nexa.Theme.popupBackground
    border.width: Nexa.Theme.borderThin
    border.color: Nexa.Theme.border
    z: Nexa.Theme.zOverlay

    Text {
        id: label
        anchors.centerIn: parent
        text: root.text
        color: Nexa.Theme.text
        font.family: Nexa.Theme.fontFamily
        font.pixelSize: Nexa.Theme.fontSizeXs
    }

    Behavior on opacity {
        NumberAnimation {
            duration: root.shown ? Nexa.Theme.popEnterDuration : Nexa.Theme.popExitDuration
        }
    }
    Behavior on scale {
        NumberAnimation {
            duration: root.shown ? Nexa.Theme.popEnterDuration : Nexa.Theme.popExitDuration
            easing.type: root.shown ? Nexa.Theme.easingEnter : Nexa.Theme.easingExit
        }
    }
}
