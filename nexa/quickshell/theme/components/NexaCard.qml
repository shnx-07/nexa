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
    antialiasing: true
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
    transformOrigin: Item.Center

    // Static glass highlight for depth. Cheap: a plain gradient
    // fill, computed once by the GPU, no per-frame cost.
    Rectangle {
        anchors.fill: parent
        anchors.margins: root.border.width
        radius: Math.max(0, root.radius - root.border.width)
        gradient: Gradient {
            GradientStop { position: 0.0; color: Nexa.Theme.edgeHighlight }
            GradientStop { position: 0.5; color: "transparent" }
        }
    }

    Item {
        id: contentItem
        anchors.fill: parent
        anchors.margins: root.padding
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
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: root.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: event => {
            if (event.button === Qt.RightButton) root.rightClicked()
            else root.clicked()
        }
    }
}
