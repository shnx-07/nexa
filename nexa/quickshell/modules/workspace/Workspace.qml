import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

import "../../NewNexaUI" as NexaUI

RowLayout {
    id: root

    spacing: NexaUI.NexaTokens.spacingSm

    readonly property string nexad:
        Quickshell.env("HOME") + "/.config/nexa/rust/target/release/nexad"

    // ------------------------------------------------------------
    // LIVE HYPRLAND WORKSPACE TRACKING (Zero-latency in-memory)
    // ------------------------------------------------------------

    readonly property int focusedWorkspaceId: {
        if (typeof Hyprland !== "undefined" && Hyprland.focusedWorkspace) {
            return Hyprland.focusedWorkspace.id
        }
        return 1
    }

    readonly property int maxWorkspace: {
        let maxId = 5
        if (typeof Hyprland !== "undefined" && Hyprland.workspaces) {
            const values = Hyprland.workspaces.values
            for (let i = 0; i < values.length; ++i) {
                if (values[i].id > maxId && values[i].id <= 10) {
                    maxId = values[i].id
                }
            }
        }
        return maxId
    }

    readonly property var workspaceSlots: {
        const slots = []
        for (let i = 1; i <= root.maxWorkspace; ++i) {
            slots.push(i)
        }
        return slots
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

    function toggleSpecialWorkspace(name) {
        if (!name || name === "") return
        if (name === "terminal" || name === "files") {
            Quickshell.execDetached([root.nexad, "hypr", "scratchpad", name])
            return
        }
        Quickshell.execDetached([root.nexad, "workspace", "special", name])
    }

    function hasWindows(wsId) {
        if (typeof Hyprland === "undefined" || !Hyprland.toplevels)
            return false
        const toplevels = Hyprland.toplevels.values
        for (let i = 0; i < toplevels.length; ++i) {
            if (toplevels[i] && toplevels[i].workspace && toplevels[i].workspace.id === wsId) {
                return true
            }
        }
        return false
    }

    function switchWorkspace(wsId) {
        if (!wsId) return
        Quickshell.execDetached([
            "sh", "-c",
            "hyprctl dispatch workspace \"$1\" 2>/dev/null || \"$2\" workspace switch \"$1\" 2>/dev/null",
            "sh", String(wsId), root.nexad
        ])
    }

    function cycleWorkspace(direction) {
        let cur = root.focusedWorkspaceId
        if (cur < 1 || cur > 10) cur = 1
        let next = cur + direction
        if (next < 1) next = root.maxWorkspace
        if (next > root.maxWorkspace) next = 1
        root.switchWorkspace(next)
    }

    function toggleOverview() {
        Quickshell.execDetached([
            "qs",
            "-p",
            Quickshell.env("HOME") + "/.config/nexa/quickshell",
            "ipc",
            "call",
            "workspaceManager",
            "toggle"
        ])
    }

    // ------------------------------------------------------------
    // 1. WORKSPACE GROUP (Pill Container)
    // ------------------------------------------------------------

    Rectangle {
        id: workspaceContainer

        implicitWidth: workspaceRow.implicitWidth + 16
        implicitHeight: NexaUI.NexaTokens.controlHeightSm

        NexaUI.NexaShadow {
            id: wsShadow
            targetItem: workspaceContainer
            elevation: 0
        }

        radius: NexaUI.NexaTokens.radiusLg === 0 ? 0 : Math.min(height / 2, NexaUI.NexaTokens.radiusLg)
        color: NexaUI.NexaColors.surfaceContainer
        border.width: NexaUI.NexaTokens.borderThin
        border.color: NexaUI.NexaColors.border

        // Apple Tactile 4-stop Depth Micro-Gradient
        Rectangle {
            anchors.fill: parent
            radius: workspaceContainer.radius
            antialiasing: true
            visible: NexaUI.NexaOptics.surface3DGradient && NexaUI.NexaOptics.gradientIntensity > 0.01
            opacity: NexaUI.NexaOptics.gradientIntensity
            gradient: Gradient {
                GradientStop { position: 0.00; color: Qt.rgba(1, 1, 1, 0.045) }
                GradientStop { position: 0.40; color: Qt.rgba(1, 1, 1, 0.010) }
                GradientStop { position: 0.70; color: Qt.rgba(0, 0, 0, 0.000) }
                GradientStop { position: 1.00; color: Qt.rgba(0, 0, 0, 0.120) }
            }
        }

        // Apple Top Chamfer Specular Highlight
        Rectangle {
            anchors.top: parent.top
            anchors.topMargin: 1
            anchors.horizontalCenter: parent.horizontalCenter
            width: workspaceContainer.radius > 0 ? Math.max(0, parent.width - workspaceContainer.radius * 1.6) : parent.width
            height: 1
            visible: NexaUI.NexaOptics.specularHighlight && NexaUI.NexaOptics.specularIntensity > 0.01
            opacity: Math.min(1.0, NexaUI.NexaOptics.specularIntensity / 0.28)
            z: 1
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.30) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        // Apple Bottom Chamfer Ambient Shadow Line
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 1
            anchors.horizontalCenter: parent.horizontalCenter
            width: workspaceContainer.radius > 0 ? Math.max(0, parent.width - workspaceContainer.radius * 1.6) : parent.width
            height: 1
            visible: NexaUI.NexaOptics.contactShadow && NexaUI.NexaOptics.shadowBlurFactor > 0.01
            opacity: Math.min(1.0, NexaUI.NexaOptics.shadowBlurFactor)
            z: 1
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.5; color: Qt.rgba(0, 0, 0, 0.45) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        MouseArea {
            id: containerWheelArea
            anchors.fill: parent
            acceptedButtons: Qt.RightButton
            hoverEnabled: false

            onWheel: (wheel) => {
                root.cycleWorkspace(wheel.angleDelta.y > 0 ? -1 : 1)
            }

            onClicked: (mouse) => {
                if (mouse.button === Qt.RightButton) {
                    root.toggleOverview()
                }
            }

            onDoubleClicked: {
                root.toggleOverview()
            }
        }

        Row {
            id: workspaceRow

            anchors.centerIn: parent
            spacing: 6

            Repeater {
                id: workspaceRepeater
                model: root.workspaceSlots

                delegate: Item {
                    id: workspaceButton

                    required property int index
                    required property int modelData

                    readonly property int wsId: modelData
                    readonly property bool active: root.focusedWorkspaceId === wsId
                    readonly property bool occupied: root.hasWindows(wsId)

                    width: (active ? 28 : 10) + 4
                    height: NexaUI.NexaTokens.controlHeightSm

                    Behavior on width {
                        enabled: NexaUI.NexaMotion.enabled
                        SpringAnimation {
                            spring: NexaUI.NexaMotion.springStiffness
                            damping: NexaUI.NexaMotion.springDamping
                            epsilon: 0.002
                        }
                    }

                    Rectangle {
                        id: dotIndicator

                        anchors.centerIn: parent
                        width: parent.width - 4
                        height: 10
                        radius: NexaUI.NexaTokens.radiusLg === 0 ? 0 : Math.min(height / 2, NexaUI.NexaTokens.radiusLg)

                        color: {
                            if (workspaceButton.active) {
                                return NexaUI.NexaColors.primary
                            } else if (workspaceButton.occupied) {
                                return Qt.rgba(NexaUI.NexaColors.primary.r, NexaUI.NexaColors.primary.g, NexaUI.NexaColors.primary.b, 0.70)
                            } else {
                                return Qt.rgba(NexaUI.NexaColors.primary.r, NexaUI.NexaColors.primary.g, NexaUI.NexaColors.primary.b, 0.30)
                            }
                        }

                        scale: mouse.pressed ? 0.88 : (mouse.containsMouse && !workspaceButton.active ? 1.2 : 1.0)

                        Behavior on color {
                            ColorAnimation {
                                duration: NexaUI.NexaMotion.durationNormal
                                easing.type: Easing.InOutCubic
                            }
                        }

                        Behavior on scale {
                            NumberAnimation {
                                duration: NexaUI.NexaMotion.durationFast
                                easing.type: Easing.OutCubic
                            }
                        }
                    }

                    MouseArea {
                        id: mouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton

                        onClicked: (mouseEv) => {
                            if (mouseEv.button === Qt.RightButton) {
                                root.toggleOverview()
                            } else {
                                root.switchWorkspace(workspaceButton.wsId)
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
    // 2. SCRATCHPAD TRAY (Dedicated pill appearing when scratchpad open)
    // ------------------------------------------------------------

    Rectangle {
        id: scratchpadTray

        visible: root.activeSpecialWorkspaces.length > 0
        implicitHeight: NexaUI.NexaTokens.controlHeightSm
        implicitWidth: scratchpadRow.implicitWidth + 12

        NexaUI.NexaShadow {
            id: spShadow
            targetItem: scratchpadTray
            elevation: 0
        }

        radius: NexaUI.NexaTokens.radiusLg === 0 ? 0 : Math.min(height / 2, NexaUI.NexaTokens.radiusLg)
        color: NexaUI.NexaColors.surfaceContainer
        border.width: NexaUI.NexaTokens.borderThin
        border.color: NexaUI.NexaColors.border

        // Apple Tactile 4-stop Depth Micro-Gradient
        Rectangle {
            anchors.fill: parent
            radius: scratchpadTray.radius
            antialiasing: true
            visible: NexaUI.NexaOptics.surface3DGradient && NexaUI.NexaOptics.gradientIntensity > 0.01
            opacity: NexaUI.NexaOptics.gradientIntensity
            gradient: Gradient {
                GradientStop { position: 0.00; color: Qt.rgba(1, 1, 1, 0.045) }
                GradientStop { position: 0.40; color: Qt.rgba(1, 1, 1, 0.010) }
                GradientStop { position: 0.70; color: Qt.rgba(0, 0, 0, 0.000) }
                GradientStop { position: 1.00; color: Qt.rgba(0, 0, 0, 0.120) }
            }
        }

        // Apple Top Chamfer Specular Highlight
        Rectangle {
            anchors.top: parent.top
            anchors.topMargin: 1
            anchors.horizontalCenter: parent.horizontalCenter
            width: scratchpadTray.radius > 0 ? Math.max(0, parent.width - scratchpadTray.radius * 1.6) : parent.width
            height: 1
            visible: NexaUI.NexaOptics.specularHighlight && NexaUI.NexaOptics.specularIntensity > 0.01
            opacity: Math.min(1.0, NexaUI.NexaOptics.specularIntensity / 0.28)
            z: 1
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.30) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        // Apple Bottom Chamfer Ambient Shadow Line
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 1
            anchors.horizontalCenter: parent.horizontalCenter
            width: scratchpadTray.radius > 0 ? Math.max(0, parent.width - scratchpadTray.radius * 1.6) : parent.width
            height: 1
            visible: NexaUI.NexaOptics.contactShadow && NexaUI.NexaOptics.shadowBlurFactor > 0.01
            opacity: Math.min(1.0, NexaUI.NexaOptics.shadowBlurFactor)
            z: 1
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.5; color: Qt.rgba(0, 0, 0, 0.45) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        Behavior on implicitWidth {
            NumberAnimation {
                duration: NexaUI.NexaMotion.durationNormal
                easing.type: Easing.OutCubic
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
                    radius: NexaUI.NexaTokens.radiusLg === 0 ? 0 : Math.min(height / 2, NexaUI.NexaTokens.radiusLg)
                    border.width: isFocused ? NexaUI.NexaTokens.borderThin : 0
                    border.color: NexaUI.NexaColors.primary

                    color: {
                        if (isFocused) {
                            return Qt.rgba(NexaUI.NexaColors.primary.r, NexaUI.NexaColors.primary.g, NexaUI.NexaColors.primary.b, 0.22)
                        } else if (spMouse.containsMouse) {
                            return Qt.rgba(1, 1, 1, 0.12)
                        } else {
                            return "transparent"
                        }
                    }

                    scale: spMouse.pressed ? 0.90 : (spMouse.containsMouse ? 1.08 : 1.0)

                    Text {
                        anchors.centerIn: parent
                        text: modelData.icon
                        font.family: NexaUI.NexaTypography.familyIcon
                        font.pixelSize: 13
                        color: scratchpadBtn.isFocused
                            ? NexaUI.NexaColors.primary
                            : (spMouse.containsMouse
                                ? NexaUI.NexaColors.text
                                : Qt.rgba(NexaUI.NexaColors.primary.r, NexaUI.NexaColors.primary.g, NexaUI.NexaColors.primary.b, 0.75))
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
    // 3. CURRENT ACTIVE APPLICATION
    // ------------------------------------------------------------

    WorkspaceCurrentApp {
        id: currentApp
    }
}
