import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland

import "../../theme" as Nexa

RowLayout {
    id: root

    spacing: Nexa.Theme.spacingXs

    property var hoveredWorkspace: null
    property Item hoveredAnchorItem: null

    // ------------------------------------------------------------
    // LIVE HYPRLAND WORKSPACES
    // ------------------------------------------------------------

    readonly property var workspaceList: {
        const values = Hyprland.workspaces.values
        const result = []

        for (let i = 0; i < values.length; ++i) {
            if (values[i].id > 0)
                result.push(values[i])
        }

        result.sort((a, b) => a.id - b.id)
        return result
    }

    // ------------------------------------------------------------
    // WORKSPACE GROUP (Pill Container)
    // ------------------------------------------------------------

    Rectangle {
        id: workspaceContainer

        implicitWidth: workspaceRow.implicitWidth + 16
        implicitHeight: Nexa.Theme.controlHeightSm

        radius: height / 2
        color: Nexa.Theme.surfaceContainer

        Row {
            id: workspaceRow

            anchors.centerIn: parent
            spacing: 6

            Repeater {
                id: workspaceRepeater
                model: root.workspaceList

                delegate: Item {
                    id: workspaceButton

                    required property int index
                    required property var modelData

                    readonly property var workspace: modelData

                    readonly property bool active:
                        Hyprland.focusedWorkspace
                        && workspace
                        && Hyprland.focusedWorkspace.id === workspace.id

                    readonly property bool hasWindows: {
                        if (typeof Hyprland === "undefined" || !Hyprland.toplevels || !workspace)
                            return false
                        const toplevels = Hyprland.toplevels.values
                        for (let i = 0; i < toplevels.length; ++i) {
                            if (toplevels[i] && toplevels[i].workspace && toplevels[i].workspace.id === workspace.id) {
                                return true
                            }
                        }
                        return false
                    }

                    width: dotIndicator.width + 4
                    height: Nexa.Theme.controlHeightSm

                    Behavior on width {
                        NumberAnimation {
                            duration: 250
                            easing.type: Easing.OutCubic
                        }
                    }

                    Rectangle {
                        id: dotIndicator

                        anchors.centerIn: parent

                        // Inactive: 10px circle. Active: 28px elongated capsule pill.
                        width: workspaceButton.active ? 28 : 10
                        height: 10
                        radius: height / 2

                        color: {
                            if (workspaceButton.active) {
                                return Nexa.Theme.primary
                            } else if (workspaceButton.hasWindows) {
                                return Qt.rgba(Nexa.Theme.primary.r, Nexa.Theme.primary.g, Nexa.Theme.primary.b, 0.70)
                            } else {
                                return Qt.rgba(Nexa.Theme.primary.r, Nexa.Theme.primary.g, Nexa.Theme.primary.b, 0.30)
                            }
                        }

                        scale: mouse.pressed ? 0.88 : (mouse.containsMouse && !workspaceButton.active ? 1.2 : 1.0)

                        Behavior on width {
                            NumberAnimation {
                                duration: 250
                                easing.type: Easing.OutCubic
                            }
                        }

                        Behavior on color {
                            ColorAnimation {
                                duration: Nexa.Theme.animationFast
                            }
                        }

                        Behavior on scale {
                            NumberAnimation {
                                duration: 150
                                easing.type: Easing.OutCubic
                            }
                        }
                    }

                    MouseArea {
                        id: mouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        onClicked: {
                            if (workspaceButton.workspace && !workspaceButton.active) {
                                workspaceButton.workspace.activate()
                            }
                        }
                    }
                }
            }
        }
    }

    // ------------------------------------------------------------
    // HOVER PREVIEW CARD POPUP
    // ------------------------------------------------------------
    
    /*
    WorkspacePreview {
        id: previewCard

        anchorItem: root.hoveredAnchorItem
        workspace: root.hoveredWorkspace
        activeWorkspace: root.hoveredWorkspace && Hyprland.focusedWorkspace && root.hoveredWorkspace.id === Hyprland.focusedWorkspace.id
        previewVisible: root.hoveredWorkspace !== null
    }
    */
    // ------------------------------------------------------------
    // SEPARATOR
    // ------------------------------------------------------------

    Rectangle {
        Layout.leftMargin:
            Nexa.Theme.spacing2Xs

        Layout.rightMargin:
            Nexa.Theme.spacing2Xs

        width:
            Nexa.Theme.borderThin

        height:
            Nexa.Theme.controlHeightSm * 0.55

        radius:
            width / 2

        color:
            Nexa.Theme.divider

        opacity:
            Nexa.Theme.opacitySecondary
    }

    // ------------------------------------------------------------
    // CURRENT APP
    // ------------------------------------------------------------

    WorkspaceCurrentApp {}
}
