import QtQuick
import ".." as Nexa

Rectangle {
    id: root
    default property alias content: contentItem.data
    property bool interactive: false
    property bool selected: false
    property int padding: Nexa.Theme.spacingMd
    signal clicked()
    signal rightClicked()

    readonly property bool hovered: interactive && mouse.containsMouse
    readonly property bool pressedState: interactive && mouse.pressed

    implicitWidth: Math.max(100, contentItem.implicitWidth + padding * 2)
    implicitHeight: Math.max(Nexa.Theme.controlHeightLg,
                             contentItem.implicitHeight + padding * 2)
    radius: Nexa.Theme.radiusLg
    color: selected ? Nexa.Theme.selectedSurface
                    : pressedState ? Nexa.Theme.interactiveCardPressed
                    : hovered ? Nexa.Theme.interactiveCardHover
                    : interactive ? Nexa.Theme.interactiveCard
                    : Nexa.Theme.cardBackground
    border.width: Nexa.Theme.borderThin
    border.color: selected ? Nexa.Theme.selectedBorder : Nexa.Theme.border
    scale: pressedState ? Nexa.Theme.cardPressScale
                        : hovered ? Nexa.Theme.cardHoverScale
                        : Nexa.Theme.normalScale

    Item {
        id: contentItem
        anchors.fill: parent
        anchors.margins: root.padding
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
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: root.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: event => {
            if (event.button === Qt.RightButton) root.rightClicked()
            else root.clicked()
        }
    }
}
