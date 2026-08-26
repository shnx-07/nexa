import QtQuick

import "." as Nexa


Rectangle {
    id: root

    property string title: ""
    property string info: ""

    // Global tooltip offset
    property int hoverOffset: 16

    implicitWidth:
        content.implicitWidth
        + Nexa.Theme.spacingMd * 2

    implicitHeight: 42

    radius:
        Nexa.Theme.radiusSm

    color:
        Nexa.Theme.popupBackground

    border {
        width:
            Nexa.Theme.borderThin

        color:
            Nexa.Theme.border
    }

    Column {
        id: content

        anchors.centerIn:
            parent

        spacing: 1

        Text {
            text:
                root.title

            color:
                Nexa.Theme.text

            font {
                family:
                    Nexa.Theme.fontFamily

                pixelSize:
                    Nexa.Theme.fontSizeXs

                weight:
                    Nexa.Theme.fontWeightDemiBold
            }
        }

        Text {
            text:
                root.info

            color:
                Nexa.Theme.mutedText

            font {
                family:
                    Nexa.Theme.fontFamily

                pixelSize:
                    Nexa.Theme.fontSize2Xs
            }
        }
    }
}
