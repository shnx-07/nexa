import QtQuick
import QtQuick.Layouts
import "../core" as Core

Rectangle {
    id: root

    // ============================================================
    // PROPERTIES & API
    // ============================================================
    property var model: [] // Array of { id: string, label: string, icon?: string }
    property var currentId: ""
    property int customHeight: 34

    signal selected(var id, var itemData)

    implicitHeight: customHeight
    implicitWidth: pillRow.implicitWidth + 8
    Layout.preferredWidth: implicitWidth
    Layout.preferredHeight: implicitHeight
    radius: Core.NexaTokens.radiusPill
    color: Core.NexaColors.surfaceContainerLowest
    border.width: Core.NexaTokens.borderThin
    border.color: Core.NexaColors.border

    // Specular Highlight
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        radius: parent.radius
        color: Qt.rgba(1, 1, 1, 0.08 * Core.NexaOptics.specularIntensity)
        visible: Core.NexaOptics.specularHighlight
    }

    // Sliding Active Thumb
    Rectangle {
        id: activeThumb
        height: parent.height - 6
        radius: Core.NexaTokens.radiusPill
        y: 3
        color: Core.NexaColors.primary
        visible: root.currentId !== "" && root.model.length > 0

        // Calculate thumb geometry based on selected pill
        property Item activePill: null

        x: activePill ? (pillRow.x + activePill.x) : 0
        width: activePill ? activePill.width : 0

        Behavior on x {
            enabled: Core.NexaMotion.enabled
            SpringAnimation {
                spring: Core.NexaMotion.springStiffness
                damping: Core.NexaMotion.springDamping
                mass: Core.NexaMotion.springMass
                epsilon: 0.25
            }
        }
        Behavior on width {
            enabled: Core.NexaMotion.enabled
            SpringAnimation {
                spring: Core.NexaMotion.springStiffness
                damping: Core.NexaMotion.springDamping
                mass: Core.NexaMotion.springMass
                epsilon: 0.25
            }
        }
    }

    RowLayout {
        id: pillRow
        anchors.fill: parent
        anchors.margins: 3
        spacing: 4

        Repeater {
            id: repeater
            model: root.model

            Rectangle {
                id: pillItem
                required property var modelData
                required property int index

                Layout.fillHeight: true
                Layout.fillWidth: true
                implicitWidth: pillContentRow.implicitWidth + 24
                Layout.preferredWidth: implicitWidth
                radius: Core.NexaTokens.radiusPill
                color: "transparent"

                readonly property bool isSelected: root.currentId === modelData.id

                Component.onCompleted: {
                    if (isSelected) activeThumb.activePill = pillItem;
                }
                Connections {
                    target: root
                    function onCurrentIdChanged() {
                        if (pillItem.isSelected) activeThumb.activePill = pillItem;
                    }
                }

                RowLayout {
                    id: pillContentRow
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        visible: pillItem.modelData.icon !== undefined && pillItem.modelData.icon.length > 0
                        text: pillItem.modelData.icon || ""
                        font.family: Core.NexaTypography.familyIcon
                        font.pixelSize: Core.NexaTypography.sizeSm
                        color: pillItem.isSelected ? Core.NexaColors.onPrimary : (pillMouse.containsMouse ? Core.NexaColors.text : Core.NexaColors.mutedText)
                    }

                    Text {
                        text: pillItem.modelData.label || pillItem.modelData.id
                        font.family: Core.NexaTypography.familyBody
                        font.pixelSize: Core.NexaTypography.sizeSm
                        font.weight: pillItem.isSelected ? Core.NexaTypography.weightSemiBold : Core.NexaTypography.weightRegular
                        color: pillItem.isSelected ? Core.NexaColors.onPrimary : (pillMouse.containsMouse ? Core.NexaColors.text : Core.NexaColors.mutedText)
                    }
                }

                MouseArea {
                    id: pillMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.currentId = pillItem.modelData.id;
                        activeThumb.activePill = pillItem;
                        root.selected(pillItem.modelData.id, pillItem.modelData);
                    }
                }
            }
        }
    }
}
