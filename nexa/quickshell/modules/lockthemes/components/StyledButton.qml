import QtQuick
import QtQuick.Controls
import "../../../NewNexaUI" as NexaUI

// Button with the shell's background/label styling, replacing the hand-written
// `background: Rectangle` + `contentItem: Text` pair.
Button {
    id: root

    property real radius: 14
    property int borderWidth: 1
    property color backgroundColor: "transparent"
    property color hoverColor: NexaUI.NexaColors.surfaceContainerHigh
    property color borderColor: NexaUI.NexaColors.outlineVariant
    property color textColor: NexaUI.NexaColors.text
    property int fontPixelSize: 14
    property int fontWeight: Font.Medium

    background: Rectangle {
        radius: root.radius
        color: root.hovered ? root.hoverColor : root.backgroundColor
        border.width: root.borderWidth
        border.color: root.borderColor
    }

    contentItem: StyledText {
        text: root.text
        color: root.textColor
        font.pixelSize: root.fontPixelSize
        font.weight: root.fontWeight
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
}
