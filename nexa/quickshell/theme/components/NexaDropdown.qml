import QtQuick
import QtQuick.Controls
import ".." as Nexa

ComboBox {
    id: root
    implicitWidth: 170
    implicitHeight: Nexa.Theme.controlHeightMd

    leftPadding: Nexa.Theme.spacingMd
    rightPadding: Nexa.Theme.spacingLg + Nexa.Theme.iconSm

    contentItem: Text {
        text: root.displayText
        color: Nexa.Theme.text
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        font.family: Nexa.Theme.fontFamily
        font.pixelSize: Nexa.Theme.fontSizeSm
    }

    indicator: Text {
        anchors.right: parent.right
        anchors.rightMargin: Nexa.Theme.spacingMd
        anchors.verticalCenter: parent.verticalCenter
        text: "󰅀"
        color: root.popup.visible ? Nexa.Theme.primary : Nexa.Theme.mutedText
        font.family: Nexa.Theme.iconFontFamily
        font.pixelSize: Nexa.Theme.iconSm
        rotation: root.popup.visible ? 180 : 0
        Behavior on rotation {
            NumberAnimation {
                duration: Nexa.Theme.motionSelection
                easing.type: Nexa.Theme.easingStandard
            }
        }
    }

    background: Rectangle {
        radius: Nexa.Theme.radiusMd
        color: root.down ? Nexa.Theme.buttonBackgroundPressed
                         : root.hovered ? Nexa.Theme.buttonBackgroundHover
                         : Nexa.Theme.buttonBackground
        border.width: Nexa.Theme.borderThin
        border.color: root.popup.visible ? Nexa.Theme.selectedBorder : Nexa.Theme.border
    }

    delegate: ItemDelegate {
        width: ListView.view ? ListView.view.width : root.width
        height: Nexa.Theme.controlHeightMd
        highlighted: root.highlightedIndex === index

        contentItem: Text {
            text: root.textRole !== "" && model ? model[root.textRole] : modelData
            color: root.currentIndex === index ? Nexa.Theme.primary : Nexa.Theme.text
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
            font.family: Nexa.Theme.fontFamily
            font.pixelSize: Nexa.Theme.fontSizeSm
        }

        background: Rectangle {
            radius: Nexa.Theme.radiusSm
            color: root.currentIndex === index ? Nexa.Theme.selectedSurface
                                               : highlighted ? Nexa.Theme.hoverStrong
                                               : "transparent"
        }
    }

    popup: Popup {
        y: root.height + Nexa.Theme.spacingXs
        width: root.width
        padding: Nexa.Theme.spacingXs

        contentItem: ListView {
            clip: true
            implicitHeight: Math.min(contentHeight, 250)
            model: root.popup.visible ? root.delegateModel : null
            currentIndex: root.highlightedIndex
            ScrollIndicator.vertical: ScrollIndicator {}
        }

        background: Rectangle {
            radius: Nexa.Theme.radiusMd
            color: Nexa.Theme.popupBackground
            border.width: Nexa.Theme.borderThin
            border.color: Nexa.Theme.border
        }
    }
}
