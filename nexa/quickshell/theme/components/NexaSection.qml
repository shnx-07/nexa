import QtQuick
import QtQuick.Layouts
import ".." as Nexa

Item {
    id: root
    default property alias content: body.data
    property string title: ""
    property string description: ""
    property string icon: ""
    property color accentColor: Nexa.Theme.primary
    property int contentSpacing: Nexa.Theme.spacingMd
    property bool showDivider: false

    implicitHeight: column.implicitHeight
    implicitWidth: column.implicitWidth

    ColumnLayout {
        id: column
        anchors.fill: parent
        spacing: root.contentSpacing

        RowLayout {
            visible: root.title !== "" || root.description !== "" || root.icon !== ""
            Layout.fillWidth: true
            spacing: Nexa.Theme.spacingSm

            Text {
                visible: root.icon !== ""
                text: root.icon
                color: root.accentColor
                font.family: Nexa.Theme.iconFontFamily
                font.pixelSize: Nexa.Theme.iconSm
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Text {
                    visible: root.title !== ""
                    text: root.title
                    color: Nexa.Theme.text
                    font.family: Nexa.Theme.fontFamily
                    font.pixelSize: Nexa.Theme.fontSizeSm
                    font.weight: Nexa.Theme.fontWeightDemiBold
                }

                Text {
                    visible: root.description !== ""
                    text: root.description
                    color: Nexa.Theme.mutedText
                    font.family: Nexa.Theme.fontFamily
                    font.pixelSize: Nexa.Theme.fontSize2Xs
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
            }
        }

        Item {
            id: body
            Layout.fillWidth: true
            implicitHeight: childrenRect.height
        }

        Rectangle {
            visible: root.showDivider
            Layout.fillWidth: true
            height: 1
            color: Nexa.Theme.divider
        }
    }
}
