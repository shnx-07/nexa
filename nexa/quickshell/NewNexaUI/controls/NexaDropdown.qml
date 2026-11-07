import QtQuick
import QtQuick.Layouts
import "../core" as Core

Item {
    id: root

    // ============================================================
    // PROPERTIES & API
    // ============================================================
    property var model: [] // Array of { id: string, label: string, icon?: string }
    property var currentId: ""
    property string placeholder: "Select an option..."
    property int customHeight: 36
    property bool expanded: false

    signal selected(var id, var itemData)

    implicitHeight: customHeight
    implicitWidth: 200
    z: expanded ? 9999 : 1

    readonly property var currentItem: {
        for (var i = 0; i < model.length; i++) {
            if (model[i].id === currentId) return model[i];
        }
        return null;
    }

    // Trigger Capsule
    Rectangle {
        id: triggerBox
        anchors.fill: parent
        radius: Core.NexaTokens.radiusSm
        color: triggerMouse.containsMouse ? Core.NexaColors.surfaceContainerHighest : Core.NexaColors.surfaceContainerHigh
        border.width: Core.NexaTokens.borderThin
        border.color: root.expanded ? Core.NexaColors.primary : (triggerMouse.containsMouse ? Core.NexaColors.outline : Core.NexaColors.border)

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 8

            Text {
                visible: root.currentItem && root.currentItem.icon !== undefined
                text: root.currentItem ? (root.currentItem.icon || "") : ""
                font.family: Core.NexaTypography.familyIcon
                font.pixelSize: Core.NexaTypography.sizeMd
                color: Core.NexaColors.primary
            }

            Text {
                Layout.fillWidth: true
                text: root.currentItem ? (root.currentItem.label || root.currentItem.id) : root.placeholder
                font.family: Core.NexaTypography.familyBody
                font.pixelSize: Core.NexaTypography.sizeSm
                color: root.currentItem ? Core.NexaColors.text : Core.NexaColors.mutedText
                elide: Text.ElideRight
            }

            Text {
                text: "󰅀"
                font.family: Core.NexaTypography.familyIcon
                font.pixelSize: Core.NexaTypography.sizeSm
                color: Core.NexaColors.mutedText
                rotation: root.expanded ? 180 : 0
                Behavior on rotation {
                    NumberAnimation { duration: Core.NexaMotion.durationInstant; easing.type: Easing.OutQuad }
                }
            }
        }

        MouseArea {
            id: triggerMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.expanded = !root.expanded
        }
    }

    // Popover Menu Container
    Rectangle {
        id: popover
        anchors.top: triggerBox.bottom
        anchors.topMargin: 4
        anchors.left: triggerBox.left
        anchors.right: triggerBox.right
        height: Math.min(220, listColumn.implicitHeight + 8)
        radius: Core.NexaTokens.radiusSm
        color: Core.NexaColors.surfaceContainerHigh
        border.width: Core.NexaTokens.borderThin
        border.color: Core.NexaColors.border
        clip: true

        visible: root.expanded
        opacity: root.expanded ? 1.0 : 0.0
        scale: root.expanded ? 1.0 : 0.95
        transformOrigin: Item.Top

        Behavior on opacity {
            NumberAnimation { duration: Core.NexaMotion.durationFast; easing.type: Core.NexaMotion.decelerateEasing }
        }
        Behavior on scale {
            enabled: Core.NexaMotion.enabled
            SpringAnimation {
                spring: Core.NexaMotion.useSpring("popups") ? Core.NexaMotion.springStiffness : 8.0
                damping: Core.NexaMotion.useSpring("popups") ? Core.NexaMotion.springDamping : 1.0
                mass: Core.NexaMotion.springMass
                epsilon: 0.002
            }
        }

        Flickable {
            anchors.fill: parent
            anchors.margins: 4
            contentHeight: listColumn.implicitHeight
            clip: true

            ColumnLayout {
                id: listColumn
                width: parent.width
                spacing: 2

                Repeater {
                    model: root.model

                    Rectangle {
                        id: itemBox
                        required property var modelData
                        required property int index

                        Layout.fillWidth: true
                        height: 32
                        radius: Core.NexaTokens.radiusXs
                        readonly property bool isCurrent: root.currentId === itemBox.modelData.id
                        color: isCurrent ? Core.NexaColors.primaryContainer : (itemMouse.containsMouse ? Core.NexaColors.surfaceContainerHighest : "transparent")

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 8

                            Text {
                                visible: itemBox.modelData.icon !== undefined
                                text: itemBox.modelData.icon || ""
                                font.family: Core.NexaTypography.familyIcon
                                font.pixelSize: Core.NexaTypography.sizeSm
                                color: itemBox.isCurrent ? Core.NexaColors.onPrimaryContainer : Core.NexaColors.mutedText
                            }

                            Text {
                                Layout.fillWidth: true
                                text: itemBox.modelData.label || itemBox.modelData.id
                                font.family: Core.NexaTypography.familyBody
                                font.pixelSize: Core.NexaTypography.sizeSm
                                font.weight: itemBox.isCurrent ? Core.NexaTypography.weightSemiBold : Core.NexaTypography.weightRegular
                                color: itemBox.isCurrent ? Core.NexaColors.onPrimaryContainer : Core.NexaColors.text
                                elide: Text.ElideRight
                            }
                        }

                        MouseArea {
                            id: itemMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.currentId = itemBox.modelData.id;
                                root.expanded = false;
                                root.selected(itemBox.modelData.id, itemBox.modelData);
                            }
                        }
                    }
                }
            }
        }
    }
}
