import QtQuick
import QtQuick.Layouts
import ".." as Nexa

RowLayout {
    id: root

    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property string badgeText: ""
    property bool showClose: true
    signal closeClicked()

    height: 28
    spacing: Nexa.Theme.spacingSm

    Text {
        visible: root.icon.length > 0
        text: root.icon
        color: Nexa.Theme.primary
        font {
            family: Nexa.Theme.iconFontFamily
            pixelSize: Nexa.Theme.iconSm
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 1

        Text {
            text: root.title
            color: Nexa.Theme.text
            font {
                family: Nexa.Theme.fontFamily
                pixelSize: Nexa.Theme.fontSizeSm
                weight: Nexa.Theme.fontWeightDemiBold
            }
            elide: Text.ElideRight
        }

        Text {
            visible: root.subtitle.length > 0
            text: root.subtitle
            color: Nexa.Theme.mutedText
            font {
                family: Nexa.Theme.fontFamily
                pixelSize: Nexa.Theme.fontSize2Xs
            }
            elide: Text.ElideRight
        }
    }

    Text {
        visible: root.badgeText.length > 0
        text: root.badgeText
        color: Nexa.Theme.mutedText
        font {
            family: Nexa.Theme.monoFontFamily
            pixelSize: Nexa.Theme.fontSize2Xs
        }
    }

    Rectangle {
        visible: root.showClose
        width: 24
        height: 24
        radius: width / 2
        color: closeMa.containsMouse ? Nexa.Theme.hover : "transparent"

        Text {
            anchors.centerIn: parent
            text: "󰅖"
            color: closeMa.containsMouse ? Nexa.Theme.error : Nexa.Theme.mutedText
            font {
                family: Nexa.Theme.iconFontFamily
                pixelSize: Nexa.Theme.iconSm
            }
        }

        MouseArea {
            id: closeMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.closeClicked()
        }
    }
}
