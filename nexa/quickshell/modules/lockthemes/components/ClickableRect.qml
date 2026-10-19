import QtQuick
import "../../../services" as Services

// A Rectangle that knows whether the pointer is over it.
Rectangle {
    id: root

    property alias hovered: mouse.containsMouse
    property alias pressed: mouse.containsPress
    property alias cursorShape: mouse.cursorShape
    property alias acceptedButtons: mouse.acceptedButtons
    property alias mouseArea: mouse

    signal clicked(var mouse)
    signal entered()
    signal exited()

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => root.clicked(mouse)
        onEntered: root.entered()
        onExited: root.exited()
    }
}
