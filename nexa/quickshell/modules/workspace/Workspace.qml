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

        return result
    }

    // ------------------------------------------------------------
    // WORKSPACE GROUP
    // ------------------------------------------------------------

    Rectangle {
        id: workspaceContainer

        implicitWidth:
            workspaceRow.implicitWidth
            + (Nexa.Theme.spacingXs * 2)

        implicitHeight:
            Nexa.Theme.controlHeightSm

        radius: height / 2

        color: Nexa.Theme.surfaceContainer


        // --------------------------------------------------------
        // SLIDING ACTIVE INDICATOR
        //
        // This Rectangle slides under the active workspace number.
        // Its x position is computed from the active delegate's
        // position within workspaceRow, offset by the row's x
        // position relative to workspaceContainer.
        // --------------------------------------------------------

        Rectangle {
            id: slideIndicator

            z: 0

            width: {
                for (let i = 0; i < workspaceRepeater.count; i++) {
                    const item = workspaceRepeater.itemAt(i)
                    if (item && item.active) {
                        return item.width - 6
                    }
                }
                return Nexa.Theme.controlHeightSm + 4
            }
            height: Nexa.Theme.controlHeightSm - 6

            anchors.verticalCenter: parent.verticalCenter

            radius: height / 2

            color: Nexa.Theme.primaryContainer

            border {
                width: Nexa.Theme.borderThin
                color: Nexa.Theme.primary
            }

            x: {
                // Find the active delegate and read its x position
                for (let i = 0; i < workspaceRepeater.count; i++) {
                    const item = workspaceRepeater.itemAt(i)
                    if (item && item.active) {
                        return workspaceRow.x + item.x + 3
                    }
                }
                return workspaceRow.x + 3
            }

            Behavior on x {
                NumberAnimation {
                    duration: Nexa.Theme.motionSelection
                    easing.type: Nexa.Theme.easingStandard
                }
            }

            Behavior on width {
                NumberAnimation {
                    duration: Nexa.Theme.motionSelection
                    easing.type: Nexa.Theme.easingStandard
                }
            }

            Behavior on color {
                ColorAnimation { duration: Nexa.Theme.animationFast }
            }
        }


        Row {
            id: workspaceRow

            anchors.centerIn: parent

            spacing: Nexa.Theme.spacing2Xs

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

                    // ------------------------------------------------
                    // ACTIVE WORKSPACE HAS CYLINDRICAL CAPSULE WIDTH
                    // ------------------------------------------------

                    width: active ? (Nexa.Theme.controlHeightSm + 10) : Nexa.Theme.controlHeightSm
                    height: Nexa.Theme.controlHeightSm

                    Behavior on width {
                        NumberAnimation {
                            duration:
                                Nexa.Theme.motionSelection

                            easing.type:
                                Nexa.Theme.easingStandard
                        }
                    }

                    // ------------------------------------------------
                    // WORKSPACE HOVER HIGHLIGHT
                    // (Active highlight is handled by slideIndicator)
                    // ------------------------------------------------

                    Rectangle{
                        id: pill

                        width: parent.width - 6
                        height: parent.height - 6

                        anchors.centerIn: parent

                        radius: height / 2

                        // Active state is handled by slideIndicator —
                        // pill only shows hover color now.
                        color: mouse.containsMouse && !workspaceButton.active
                            ? Nexa.Theme.hoverStrong
                            : "transparent"

                        border.width: 0

                        scale: mouse.pressed
                            ? Nexa.Theme.pressScale
                            : 1.0

                        Behavior on color {
                            ColorAnimation {
                                duration: Nexa.Theme.animationFast
                            }
                        }

                        Behavior on scale {
                            NumberAnimation {
                                duration: Nexa.Theme.motionInteraction
                                easing.type: Nexa.Theme.easingStandard
                            }
                        }
                    }

                    // ------------------------------------------------
                    // WORKSPACE NUMBER
                    // ------------------------------------------------

                    Text {
                        anchors.centerIn: parent

                        z: 1

                        text:
                            workspaceButton.workspace
                            ? workspaceButton.workspace.id
                            : ""

                        color:
                            workspaceButton.active
                            ? Nexa.Theme.primaryContainerText
                            : mouse.containsMouse
                                ? Nexa.Theme.text
                                : Nexa.Theme.mutedText

                        font {
                            family:
                                Nexa.Theme.fontFamily

                            pixelSize:
                                workspaceButton.active
                                ? Nexa.Theme.fontSizeSm
                                : Nexa.Theme.fontSizeXs

                            weight:
                                workspaceButton.active
                                ? Nexa.Theme.fontWeightDemiBold
                                : Nexa.Theme.fontWeightMedium
                        }

                        scale:
                            workspaceButton.active
                            ? 1.05
                            : 1.0

                        Behavior on color {
                            ColorAnimation {
                                duration:
                                    Nexa.Theme.animationFast
                            }
                        }

                        Behavior on scale {
                            NumberAnimation {
                                duration:
                                    Nexa.Theme.motionSelection

                                easing.type:
                                    Nexa.Theme.easingEmphasized
                            }
                        }
                    }

                    // ------------------------------------------------
                    // INTERACTION & HOVER PREVIEW
                    // ------------------------------------------------

                    Timer {
                        id: hoverTimer
                        interval: 180
                        repeat: false
                        onTriggered: {
                            if (mouse.containsMouse && workspaceButton.workspace && !workspaceButton.active) {
                                root.hoveredWorkspace = workspaceButton.workspace
                                root.hoveredAnchorItem = workspaceButton
                            }
                        }
                    }

                    MouseArea {
                        id: mouse

                        anchors.fill: parent

                        hoverEnabled: true

                        cursorShape:
                            Qt.PointingHandCursor

                        onEntered: hoverTimer.start()

                        onExited: {
                            hoverTimer.stop()
                            if (root.hoveredWorkspace && workspaceButton.workspace && root.hoveredWorkspace.id === workspaceButton.workspace.id) {
                                root.hoveredWorkspace = null
                                root.hoveredAnchorItem = null
                            }
                        }

                        onClicked: {
                            if (
                                workspaceButton.workspace
                                && !workspaceButton.active
                            ) {
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
