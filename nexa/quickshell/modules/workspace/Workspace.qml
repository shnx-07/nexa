import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

import "../../theme" as Nexa

RowLayout {
    id: root

    spacing: Nexa.Theme.spacingXs

    property var hoveredWorkspace: null
    property Item hoveredAnchorItem: null

    readonly property string nexad:
        Quickshell.env("HOME") + "/.config/nexa/rust/target/release/nexad"

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
    // ACTIVE SCRATCHPADS / SPECIAL WORKSPACES
    // ------------------------------------------------------------

    readonly property var activeSpecialWorkspaces: {
        if (typeof Hyprland === "undefined" || !Hyprland.toplevels)
            return []

        const toplevels = Hyprland.toplevels.values
        const map = {}

        for (let i = 0; i < toplevels.length; ++i) {
            const top = toplevels[i]
            if (!top || !top.workspace)
                continue

            let name = ""
            let id = top.workspace.id

            if (top.workspace.name && top.workspace.name.startsWith("special:")) {
                name = top.workspace.name.slice(8)
            } else if (id === -97) {
                name = "terminal"
            } else if (id === -98) {
                name = "files"
            } else if (id === -99) {
                name = "magic"
            } else if (id < 0) {
                name = "scratchpad"
            }

            if (name !== "") {
                if (!map[name]) {
                    let icon = "󰏤"
                    let label = "Scratchpad"
                    if (name === "terminal") {
                        icon = "󰆍"
                        label = "Terminal"
                    } else if (name === "files") {
                        icon = "󰉋"
                        label = "Files"
                    } else if (name === "magic") {
                        icon = "󰏤"
                        label = "Quick Scratchpad"
                    }

                    map[name] = {
                        name: name,
                        id: id,
                        icon: icon,
                        label: label,
                        windowCount: 0
                    }
                }
                map[name].windowCount++
            }
        }

        const order = ["terminal", "files", "magic"]
        const list = Object.values(map)
        list.sort((a, b) => {
            let ia = order.indexOf(a.name)
            let ib = order.indexOf(b.name)
            if (ia === -1) ia = 99
            if (ib === -1) ib = 99
            return ia - ib
        })
        return list
    }

    // ------------------------------------------------------------
    // WORKSPACE ACTION PROCESS & CONTROLS
    // ------------------------------------------------------------

    Process {
        id: workspaceProcess
    }

    function runWorkspaceAction(args) {
        workspaceProcess.command = [root.nexad].concat(args)
        workspaceProcess.running = true
    }

    function toggleSpecialWorkspace(name) {
        if (!name || name === "")
            return
        runWorkspaceAction(["workspace", "special", name])
    }

    function cycleWorkspace(direction) {
        if (!root.workspaceList || root.workspaceList.length === 0)
            return

        const curWs = Hyprland.focusedWorkspace
        const curId = curWs ? curWs.id : 1

        if (root.workspaceList.length > 1) {
            let currentIndex = -1
            for (let i = 0; i < root.workspaceList.length; ++i) {
                if (root.workspaceList[i].id === curId) {
                    currentIndex = i
                    break
                }
            }

            let nextIndex = 0
            if (currentIndex !== -1) {
                nextIndex = (currentIndex + direction + root.workspaceList.length) % root.workspaceList.length
            } else {
                nextIndex = direction > 0 ? 0 : root.workspaceList.length - 1
            }

            const target = root.workspaceList[nextIndex]
            if (target && target.activate) {
                target.activate()
                return
            }
        }

        let nextId = curId + direction
        if (nextId < 1) nextId = 10
        if (nextId > 10) nextId = 1
        runWorkspaceAction(["workspace", "switch", nextId.toString()])
    }

    // ------------------------------------------------------------
    // WORKSPACE GROUP (Pill Container)
    // ------------------------------------------------------------

    Rectangle {
        id: workspaceContainer

        implicitWidth: workspaceRow.implicitWidth + 16
        implicitHeight: Nexa.Theme.controlHeightSm

        Behavior on implicitWidth {
            NumberAnimation {
                duration: 280
                easing.type: Easing.InOutCubic
            }
        }

        radius: height / 2
        color: Nexa.Theme.surfaceContainer

        MouseArea {
            id: containerWheelArea
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            hoverEnabled: false

            onWheel: (wheel) => {
                root.cycleWorkspace(wheel.angleDelta.y > 0 ? -1 : 1)
            }
        }

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

                    // Symmetrical width: active is 28+4=32px, inactive is 10+4=14px
                    width: (active ? 28 : 10) + 4
                    height: Nexa.Theme.controlHeightSm

                    Behavior on width {
                        NumberAnimation {
                            duration: 280
                            easing.type: Easing.InOutCubic
                        }
                    }

                    Rectangle {
                        id: dotIndicator

                        anchors.centerIn: parent

                        // Directly tracks parent width for instant single-curve synchronization
                        width: parent.width - 4
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

                        Behavior on color {
                            ColorAnimation {
                                duration: 250
                                easing.type: Easing.InOutCubic
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

                        onWheel: (wheel) => {
                            root.cycleWorkspace(wheel.angleDelta.y > 0 ? -1 : 1)
                        }
                    }
                }
            }
        }
    }

    // ------------------------------------------------------------
    // SCRATCHPAD TRAY
    // ------------------------------------------------------------

    Rectangle {
        id: scratchpadTray

        visible: root.activeSpecialWorkspaces.length > 0
        implicitHeight: Nexa.Theme.controlHeightSm
        implicitWidth: scratchpadRow.implicitWidth + 12
        radius: height / 2
        color: Nexa.Theme.surfaceContainer

        Behavior on implicitWidth {
            NumberAnimation {
                duration: 280
                easing.type: Easing.InOutCubic
            }
        }

        Row {
            id: scratchpadRow
            anchors.centerIn: parent
            spacing: 4

            Repeater {
                model: root.activeSpecialWorkspaces

                delegate: Rectangle {
                    id: scratchpadBtn

                    required property var modelData

                    readonly property bool isFocused:
                        Hyprland.focusedWorkspace
                        && (Hyprland.focusedWorkspace.name === ("special:" + modelData.name)
                            || Hyprland.focusedWorkspace.id === modelData.id)

                    width: 26
                    height: 22
                    radius: height / 2

                    color: {
                        if (isFocused) {
                            return Qt.rgba(Nexa.Theme.primary.r, Nexa.Theme.primary.g, Nexa.Theme.primary.b, 0.22)
                        } else if (spMouse.containsMouse) {
                            return Qt.rgba(1, 1, 1, 0.12)
                        } else {
                            return "transparent"
                        }
                    }

                    scale: spMouse.pressed ? 0.90 : (spMouse.containsMouse ? 1.08 : 1.0)

                    Behavior on color {
                        ColorAnimation {
                            duration: 200
                            easing.type: Easing.InOutCubic
                        }
                    }

                    Behavior on scale {
                        NumberAnimation {
                            duration: 150
                            easing.type: Easing.OutCubic
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: modelData.icon
                        font.family: Nexa.Theme.iconFontFamily
                        font.pixelSize: 13
                        color: scratchpadBtn.isFocused
                            ? Nexa.Theme.primary
                            : (spMouse.containsMouse
                                ? Nexa.Theme.textPrimary
                                : Qt.rgba(Nexa.Theme.primary.r, Nexa.Theme.primary.g, Nexa.Theme.primary.b, 0.75))
                    }

                    MouseArea {
                        id: spMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        onClicked: {
                            root.toggleSpecialWorkspace(modelData.name)
                        }
                    }
                }
            }
        }
    }

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
