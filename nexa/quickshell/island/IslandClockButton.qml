import QtQuick
import QtQuick.Layouts
import "../theme" as Nexa
import "../theme/components" as NexaUI

Rectangle {
    id: root

    signal clicked()

    property date currentTime: new Date()

    Timer {
        interval: 1000
        running: root.visible
        repeat: true
        onTriggered: root.currentTime = new Date()
    }

    height: Nexa.Theme.islandCompactHeight
    width: clockText.implicitWidth + 24

    // Copies exact radius change behavior as Island in compact mode
    radius: {
        if (Nexa.Theme.islandRounding === 0) return 0;
        return (Nexa.Theme.islandRounding >= 999) ? Math.round(height / 2) : Nexa.Theme.islandRounding;
    }

    Behavior on radius {
        enabled: !Nexa.Theme.reducedMotion
        NexaUI.NexaSpring { section: "island" }
    }

    color: clockMouse.containsMouse
        ? Nexa.Theme.surfaceContainerHigh
        : Nexa.Theme.islandBackground

    border.width: Nexa.Theme.borderThin
    border.color: clockMouse.containsMouse
        ? Nexa.Theme.borderStrong
        : Nexa.Theme.border

    Text {
        id: clockText
        anchors.centerIn: parent
        text: Qt.formatDateTime(root.currentTime, "hh:mm AP")
        color: clockMouse.containsMouse ? "#ffffff" : Nexa.Theme.text
        font.family: Nexa.Theme.fontFamily
        font.pixelSize: Nexa.Theme.fontSizeSm
        font.weight: Nexa.Theme.fontWeightMedium
    }

    MouseArea {
        id: clockMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            root.clicked()
        }
    }
}
