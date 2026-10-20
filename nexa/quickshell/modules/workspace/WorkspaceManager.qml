import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import "../../theme" as Nexa
import "../../theme/components" as NexaUI

PanelWindow {
    id: manager

    readonly property string nexad: Quickshell.env("HOME") + "/.config/nexa/rust/target/release/nexad"
    readonly property real outerMargin: 52
    readonly property real specialHeight: 150

    property real overviewScale: 0.18
    property real workspaceGap: Nexa.Theme.spacingMd
    property int workspaceColumns: 5
    property int workspaceRows: 2

    property real workspacePreviewWidth: {
        const monitor = manager.monitors.length > 0 ? manager.monitors[0] : null
        return monitor ? Math.round(Number(monitor.width || 1920) * overviewScale) : 300
    }

    property real workspacePreviewHeight: {
        const monitor = manager.monitors.length > 0 ? manager.monitors[0] : null
        return monitor ? Math.round(Number(monitor.height || 1080) * overviewScale) : 170
    }

    readonly property real regularContentWidth: workspaceColumns * workspacePreviewWidth + (workspaceColumns - 1) * workspaceGap
    readonly property real regularContentHeight: workspaceRows * workspacePreviewHeight + (workspaceRows - 1) * workspaceGap

    property bool managerVisible: false
    property var workspaceState: null
    readonly property var workspaces: (workspaceState && workspaceState.workspaces) ? workspaceState.workspaces : []
    readonly property var specialWorkspaces: (workspaceState && workspaceState.specialWorkspaces) ? workspaceState.specialWorkspaces : []
    readonly property var monitors: (workspaceState && workspaceState.monitors) ? workspaceState.monitors : []

    // Drag State
    property bool dragActive: false
    property string draggingAddress: ""
    property int draggingFromWorkspace: -1
    property string draggingFromSpecialWorkspace: ""
    property int draggingTargetWorkspace: -1
    property string draggingTargetSpecialWorkspace: ""

    visible: managerVisible
    color: "transparent"
    aboveWindows: true
    focusable: true
    anchors { left: true; right: true; top: true; bottom: true }

    function cleanSpecialName(name) {
        let v = String(name || "").trim()
        return v.startsWith("special:") ? v.slice(8) : v
    }

    function clearDragState() {
        dragActive = false
        draggingAddress = ""
        draggingFromWorkspace = -1
        draggingFromSpecialWorkspace = ""
        draggingTargetWorkspace = -1
        draggingTargetSpecialWorkspace = ""
    }

    function openManager() {
        managerVisible = true
        reload()
    }

    function closeManager() {
        clearDragState()
        managerVisible = false
    }

    function toggleManager() {
        if (managerVisible) closeManager()
        else openManager()
    }

    function rustWindowForAddress(address) {
        const wanted = manager.normalizeAddress(address)
        if (!wanted) return null

        for (let i = 0; i < workspaces.length; ++i) {
            const ws = workspaces[i]
            const list = ws.windows || []
            for (let j = 0; j < list.length; ++j) {
                if (manager.normalizeAddress(list[j].address) === wanted) {
                    return { windowData: list[j], workspaceData: ws, workspaceId: Number(ws.id), specialName: "" }
                }
            }
        }

        for (let i = 0; i < specialWorkspaces.length; ++i) {
            const ws = specialWorkspaces[i]
            const list = ws.windows || []
            for (let j = 0; j < list.length; ++j) {
                if (manager.normalizeAddress(list[j].address) === wanted) {
                    return {
                        windowData: list[j],
                        workspaceData: ws,
                        workspaceId: -1,
                        specialName: manager.cleanSpecialName(ws.displayName || ws.name || "")
                    }
                }
            }
        }
        return null
    }

    function addressForToplevel(toplevel) {
        return (toplevel && toplevel.HyprlandToplevel && toplevel.HyprlandToplevel.address) ? String(toplevel.HyprlandToplevel.address) : ""
    }

    function monitorForName(name) {
        const wanted = String(name || "")
        if (wanted !== "") {
            for (let i = 0; i < monitors.length; ++i) {
                if (String(monitors[i].name || "") === wanted) return monitors[i]
            }
        }
        for (let i = 0; i < monitors.length; ++i) {
            if (monitors[i].focused) return monitors[i]
        }
        return monitors.length > 0 ? monitors[0] : null
    }

    function workspaceIndex(id) {
        const num = Number(id)
        return (Number.isFinite(num) && num >= 1 && num <= 10) ? num - 1 : -1
    }

    function workspaceColumn(id) {
        const idx = workspaceIndex(id)
        return idx < 0 ? 0 : idx % workspaceColumns
    }

    function workspaceRow(id) {
        const idx = workspaceIndex(id)
        return idx < 0 ? 0 : Math.floor(idx / workspaceColumns)
    }

    function workspaceX(id) {
        const idx = Number(id) - 1
        return (idx % workspaceColumns) * (workspacePreviewWidth + workspaceGap)
    }

    function workspaceY(id) {
        const idx = Number(id) - 1
        return Math.floor(idx / workspaceColumns) * (workspacePreviewHeight + workspaceGap)
    }

    function specialWorkspaceIndex(name) {
        const wanted = manager.cleanSpecialName(name)
        for (let i = 0; i < specialWorkspaces.length; ++i) {
            if (manager.cleanSpecialName(specialWorkspaces[i].displayName || specialWorkspaces[i].name || "") === wanted) return i
        }
        return -1
    }

    function specialTileWidth() { return manager.workspacePreviewWidth }

    function specialWorkspaceX(name) {
        const idx = manager.specialWorkspaceIndex(name)
        if (idx < 0) return 0
        return specialSection.x + specialRow.x + idx * (manager.workspacePreviewWidth + specialRow.spacing) - regularGrid.x
    }

    function specialWorkspaceY(name) {
        return specialSection.y + specialRow.y - regularGrid.y
    }

    function specialWorkspaceWidth(name) { return manager.workspacePreviewWidth }

    function specialWorkspaceHeight(name) { return manager.workspacePreviewHeight }

    function normalizeAddress(address) {
        let v = String(address || "").trim().toLowerCase()
        return v.startsWith("0x") ? v.slice(2) : v
    }

    function specialExists(name) {
        const wanted = manager.cleanSpecialName(name)
        for (let i = 0; i < manager.specialWorkspaces.length; ++i) {
            if (manager.cleanSpecialName(manager.specialWorkspaces[i].displayName || manager.specialWorkspaces[i].name || "") === wanted) return true
        }
        return false
    }

    function reload() {
        if (!infoProcess.running) infoProcess.running = true
    }

    Timer { id: reloadTimer; interval: 80; repeat: false; onTriggered: manager.reload() }

    Process {
        id: infoProcess
        command: [manager.nexad, "workspace", "info"]
        stdout: StdioCollector {
            onStreamFinished: {
                const val = this.text.trim()
                if (!val) return
                try { manager.workspaceState = JSON.parse(val) }
                catch (e) { console.warn("WorkspaceManager: invalid workspace JSON", e) }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: { if (this.text && this.text.trim()) console.warn("WorkspaceManager backend:", this.text.trim()) }
        }
    }

    Process {
        id: actionProcess
        property var pendingCommand: []
        command: pendingCommand
        stdout: StdioCollector { onStreamFinished: { if (this.text && this.text.trim()) console.log("WorkspaceManager:", this.text.trim()) } }
        stderr: StdioCollector { onStreamFinished: { if (this.text && this.text.trim()) console.warn("WorkspaceManager action:", this.text.trim()) } }
        onExited: reloadTimer.restart()
    }

    function runAction(args) {
        if (actionProcess.running) return false
        actionProcess.pendingCommand = [manager.nexad].concat(args)
        actionProcess.running = true
        return true
    }

    function closeWindow(address) {
        if (address) runAction(["workspace", "close", String(address)])
    }

    function switchWorkspace(id) {
        if (runAction(["workspace", "switch", String(id)])) closeManager()
    }

    function focusWindow(address) {
        if (address && runAction(["workspace", "focus", String(address)])) closeManager()
    }

    function moveToRegular(address, workspaceId) {
        runAction(["workspace", "move", String(address), String(workspaceId)])
    }

    function moveToSpecial(address, specialName) {
        if (specialName) runAction(["workspace", "move-special", String(address), String(specialName)])
    }

    function toggleSpecial(name) {
        if (!name) return
        const clean = cleanSpecialName(name)
        const idx = specialWorkspaceIndex(clean)
        const winCount = (idx >= 0 && specialWorkspaces[idx] && specialWorkspaces[idx].windows) ? specialWorkspaces[idx].windows.length : 0

        if (clean === "terminal" && winCount === 0) {
            runAction(["command", "run", "hyprctl dispatch 'hl.exec_cmd(\"[workspace special:terminal] kitty\")' && hyprctl dispatch 'hl.dsp.workspace.toggle_special(\"terminal\")'"])
            return
        }
        if (clean === "files" && winCount === 0) {
            runAction(["command", "run", "hyprctl dispatch 'hl.exec_cmd(\"[workspace special:files] dolphin\")' && hyprctl dispatch 'hl.dsp.workspace.toggle_special(\"files\")'"])
            return
        }
        runAction(["workspace", "special", String(clean)])
    }

    function finishWindowDrag(windowItem) {
        const address = draggingAddress
        const regularTarget = draggingTargetWorkspace
        const specialTarget = draggingTargetSpecialWorkspace
        const sourceWorkspace = draggingFromWorkspace
        const sourceSpecial = draggingFromSpecialWorkspace

        if (regularTarget > 0 && regularTarget !== sourceWorkspace) {
            if (windowItem) {
                windowItem.workspaceX = manager.workspaceX(regularTarget)
                windowItem.workspaceY = manager.workspaceY(regularTarget)
                windowItem.dragInProgress = false
                windowItem.x = windowItem.initX
                windowItem.y = windowItem.initY
            }
            moveToRegular(address, regularTarget)
            clearDragState()
            return
        }

        if (specialTarget !== "" && specialTarget !== sourceSpecial) {
            if (windowItem) {
                windowItem.workspaceX = manager.specialWorkspaceX(specialTarget)
                windowItem.workspaceY = manager.specialWorkspaceY(specialTarget)
                windowItem.dragInProgress = false
                windowItem.x = windowItem.initX
                windowItem.y = windowItem.initY
            }
            moveToSpecial(address, specialTarget)
            clearDragState()
            return
        }

        clearDragState()
        if (windowItem) {
            windowItem.dragInProgress = false
            windowItem.x = windowItem.initX
            windowItem.y = windowItem.initY
        }
    }

    Component.onCompleted: reload()

    Timer {
        interval: 800
        repeat: true
        running: manager.visible && !manager.dragActive
        onTriggered: manager.reload()
    }

    Shortcut {
        sequence: "Escape"
        enabled: manager.visible
        onActivated: manager.closeManager()
    }

    Repeater {
        model: 10
        Shortcut {
            sequence: (index + 1) % 10 === 0 ? "0" : String(index + 1)
            enabled: manager.visible && !manager.dragActive
            onActivated: manager.switchWorkspace(index + 1)
        }
    }

    // Modal Scrim
    Rectangle {
        anchors.fill: parent
        color: Nexa.Theme.scrimHeavy
        MouseArea {
            anchors.fill: parent
            enabled: !manager.dragActive
            onClicked: manager.closeManager()
        }
    }

    // Main Modal Board
    Rectangle {
        id: board
        width: regularContentWidth + Nexa.Theme.spacingLg * 2
        height: titleArea.height + regularContentHeight + specialSection.height + Nexa.Theme.spacingLg * 4
        anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 90 }
        radius: Nexa.Theme.radiusXl
        color: Nexa.Theme.panelBackground
        border.width: Nexa.Theme.borderThin
        border.color: Nexa.Theme.border
        opacity: manager.managerVisible ? 1 : 0
        scale: manager.managerVisible ? 1 : 0.97

        Behavior on opacity { NumberAnimation { duration: Nexa.Theme.motionPopup } }
        Behavior on scale { NumberAnimation { duration: Nexa.Theme.motionPopup; easing.type: Easing.OutCubic } }

        // Header Title
        Item {
            id: titleArea
            anchors { top: parent.top; left: parent.left; right: parent.right }
            height: 54

            Text {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: Nexa.Theme.spacingLg }
                text: "Workspaces"
                color: Nexa.Theme.text
                font.family: Nexa.Theme.fontFamily
                font.pixelSize: Nexa.Theme.fontSizeXl
                font.bold: true
            }

            Text {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: Nexa.Theme.spacingLg }
                text: manager.dragActive ? "Move window" : "Drag a window to move it"
                color: manager.dragActive ? Nexa.Theme.primary : Nexa.Theme.mutedText
                font.family: Nexa.Theme.fontFamily
                font.pixelSize: Nexa.Theme.fontSizeSm
            }
        }

        // Regular Workspaces Grid
        Item {
            id: regularGrid
            width: manager.regularContentWidth
            height: manager.regularContentHeight
            anchors { top: titleArea.bottom; horizontalCenter: parent.horizontalCenter; topMargin: Nexa.Theme.spacingMd }

            readonly property real workspaceWidth: manager.workspacePreviewWidth
            readonly property real workspaceHeight: manager.workspacePreviewHeight

            Repeater {
                model: manager.workspaces
                delegate: NexaUI.NexaCard {
                    id: workspaceTile
                    required property var modelData
                    required property int index
                    readonly property int workspaceId: Number(modelData.id)

                    x: (index % manager.workspaceColumns) * (manager.workspacePreviewWidth + manager.workspaceGap)
                    y: Math.floor(index / manager.workspaceColumns) * (manager.workspacePreviewHeight + manager.workspaceGap)
                    implicitWidth: manager.workspacePreviewWidth
                    implicitHeight: manager.workspacePreviewHeight
                    padding: 0
                    selected: modelData.active
                    scale: workspaceDrop.containsDrag ? 1.015 : 1.0
                    Behavior on scale { NumberAnimation { duration: Nexa.Theme.motionInteraction } }

                    border.width: (workspaceDrop.containsDrag || modelData.active) ? 2 : 1
                    border.color: (workspaceDrop.containsDrag || modelData.active) ? Nexa.Theme.primary : Nexa.Theme.border

                    Text {
                        anchors { left: parent.left; top: parent.top; margins: Nexa.Theme.spacingSm }
                        text: workspaceTile.workspaceId
                        color: modelData.active ? Nexa.Theme.primary : Nexa.Theme.mutedText
                        font.family: Nexa.Theme.fontFamily
                        font.pixelSize: Nexa.Theme.fontSizeMd
                        font.bold: true
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: !modelData.windows || modelData.windows.length === 0
                        text: workspaceTile.workspaceId
                        color: Nexa.Theme.text
                        opacity: 0.08
                        font.family: Nexa.Theme.fontFamily
                        font.pixelSize: 48
                        font.bold: true
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: !manager.dragActive
                        onClicked: manager.switchWorkspace(workspaceTile.workspaceId)
                    }

                    DropArea {
                        id: workspaceDrop
                        anchors.fill: parent
                        keys: ["nexa-workspace-window"]
                        onEntered: drag => {
                            if (!manager.dragActive) { drag.accepted = false; return }
                            drag.accepted = true
                            manager.draggingTargetWorkspace = workspaceTile.workspaceId
                            manager.draggingTargetSpecialWorkspace = ""
                        }
                        onExited: {
                            if (manager.draggingTargetWorkspace === workspaceTile.workspaceId) manager.draggingTargetWorkspace = -1
                        }
                    }
                }
            }
        }

        // Special Workspaces & Scratchpads
        Rectangle {
            id: specialSection
            anchors {
                top: regularGrid.bottom
                left: parent.left
                right: parent.right
                topMargin: Nexa.Theme.spacingLg
                leftMargin: Nexa.Theme.spacingLg
                rightMargin: Nexa.Theme.spacingLg
            }
            height: specialTitle.implicitHeight + manager.workspacePreviewHeight + Nexa.Theme.spacingSm + Nexa.Theme.spacingMd * 2
            radius: Nexa.Theme.radiusLg
            color: Nexa.Theme.cardBackgroundSubtle
            border.width: Nexa.Theme.borderThin
            border.color: Nexa.Theme.border

            Text {
                id: specialTitle
                anchors { left: parent.left; top: parent.top; margins: Nexa.Theme.spacingMd }
                text: "Scratchpads & Special Workspaces"
                color: Nexa.Theme.mutedText
                font.family: Nexa.Theme.fontFamily
                font.pixelSize: Nexa.Theme.fontSizeSm
                font.bold: true
            }

            Row {
                id: specialRow
                anchors {
                    left: parent.left
                    right: parent.right
                    top: specialTitle.bottom
                    bottom: parent.bottom
                    leftMargin: Nexa.Theme.spacingMd
                    rightMargin: Nexa.Theme.spacingMd
                    topMargin: Nexa.Theme.spacingSm
                    bottomMargin: Nexa.Theme.spacingMd
                }
                spacing: Nexa.Theme.spacingMd

                Repeater {
                    model: manager.specialWorkspaces
                    delegate: NexaUI.NexaCard {
                        id: specialTile
                        required property var modelData
                        required property int index

                        readonly property string specialName: manager.cleanSpecialName(modelData.displayName || modelData.name || "")
                        readonly property string friendlyTitle: {
                            if (specialName === "terminal") return "Terminal"
                            if (specialName === "files") return "Files"
                            if (specialName === "magic") return "Quick Scratchpad"
                            return specialName.charAt(0).toUpperCase() + specialName.slice(1)
                        }
                        readonly property string scratchIcon: {
                            if (specialName === "terminal") return "󰆍"
                            if (specialName === "files") return "󰉋"
                            if (specialName === "magic") return "󰏤"
                            return "󰍹"
                        }
                        readonly property int windowCount: modelData.windows ? modelData.windows.length : 0

                        implicitWidth: manager.workspacePreviewWidth
                        implicitHeight: manager.workspacePreviewHeight
                        padding: 0
                        selected: modelData.active
                        border.width: specialDrop.containsDrag ? Nexa.Theme.borderStrongWidth : modelData.active ? 2 : Nexa.Theme.borderThin
                        border.color: (specialDrop.containsDrag || modelData.active) ? Nexa.Theme.primary : Nexa.Theme.border

                        RowLayout {
                            anchors { left: parent.left; top: parent.top; right: parent.right; margins: Nexa.Theme.spacingSm }
                            spacing: Nexa.Theme.spacingXs

                            Text {
                                text: specialTile.scratchIcon
                                color: modelData.active ? Nexa.Theme.primary : Nexa.Theme.text
                                font.pixelSize: Nexa.Theme.fontSizeSm
                            }

                            Text {
                                text: specialTile.friendlyTitle
                                color: Nexa.Theme.text
                                font.family: Nexa.Theme.fontFamily
                                font.pixelSize: Nexa.Theme.fontSizeSm
                                font.bold: true
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }

                            Rectangle {
                                visible: specialTile.windowCount > 0
                                implicitWidth: countText.implicitWidth + 8
                                implicitHeight: 16
                                radius: 8
                                color: modelData.active ? Nexa.Theme.primary : Qt.rgba(255, 255, 255, 0.12)
                                Text {
                                    id: countText
                                    anchors.centerIn: parent
                                    text: String(specialTile.windowCount)
                                    color: modelData.active ? Nexa.Theme.onPrimary : Nexa.Theme.text
                                    font.pixelSize: 10
                                    font.bold: true
                                }
                            }
                        }

                        Column {
                            anchors.centerIn: parent
                            visible: specialTile.windowCount === 0
                            spacing: 4
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: specialTile.scratchIcon
                                color: Nexa.Theme.mutedText
                                font.pixelSize: 22
                                opacity: 0.35
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "Click to launch"
                                color: Nexa.Theme.mutedText
                                font.family: Nexa.Theme.fontFamily
                                font.pixelSize: Nexa.Theme.fontSizeXs
                                opacity: 0.55
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: !manager.dragActive
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                manager.closeManager()
                                manager.toggleSpecial(specialTile.specialName)
                            }
                        }

                        DropArea {
                            id: specialDrop
                            anchors.fill: parent
                            keys: ["nexa-workspace-window"]
                            onEntered: drag => {
                                if (!manager.dragActive || manager.draggingAddress === "") { drag.accepted = false; return }
                                drag.accepted = true
                                manager.draggingTargetSpecialWorkspace = specialTile.specialName
                                manager.draggingTargetWorkspace = -1
                            }
                            onExited: {
                                if (manager.draggingTargetSpecialWorkspace === specialTile.specialName) manager.draggingTargetSpecialWorkspace = ""
                            }
                        }
                    }
                }
            }
        }

        // Live Windows Space
        Item {
            id: windowSpace
            anchors.fill: regularGrid
            z: 100
            clip: false

            Repeater {
                model: ToplevelManager.toplevels.values
                delegate: WorkspaceWindow {
                    id: overviewWindow
                    required property var modelData
                    required property int index

                    readonly property string compositorAddress: manager.addressForToplevel(modelData)
                    readonly property var lookup: manager.rustWindowForAddress(compositorAddress)
                    readonly property bool isRegular: lookup && lookup.workspaceId > 0
                    readonly property bool isSpecial: lookup && lookup.specialName !== ""

                    visible: lookup !== null && (isRegular || isSpecial)
                    windowData: lookup ? lookup.windowData : null
                    toplevel: modelData
                    livePreview: manager.visible && overviewWindow.visible
                    monitorData: lookup ? manager.monitorForName(lookup.workspaceData.monitor) : null

                    workspaceX: {
                        if (!lookup) return 0
                        if (isRegular) return manager.workspaceX(lookup.workspaceId)
                        if (isSpecial) return manager.specialWorkspaceX(lookup.specialName)
                        return 0
                    }

                    workspaceY: {
                        if (!lookup) return 0
                        if (isRegular) return manager.workspaceY(lookup.workspaceId)
                        if (isSpecial) return manager.specialWorkspaceY(lookup.specialName)
                        return 0
                    }

                    workspaceWidth: {
                        if (isRegular) return regularGrid.workspaceWidth
                        if (isSpecial) return manager.specialWorkspaceWidth(lookup.specialName)
                        return 1
                    }

                    workspaceHeight: {
                        if (isRegular) return regularGrid.workspaceHeight
                        if (isSpecial) return manager.specialWorkspaceHeight(lookup.specialName)
                        return 1
                    }

                    previewScaleX: monitorData ? (workspaceWidth / Math.max(1, Number(monitorData.width))) : 0.1
                    previewScaleY: monitorData ? (workspaceHeight / Math.max(1, Number(monitorData.height))) : 0.1

                    Drag.active: windowMouse.drag.active
                    Drag.source: overviewWindow
                    Drag.keys: ["nexa-workspace-window"]
                    Drag.hotSpot.x: windowMouse.mouseX
                    Drag.hotSpot.y: windowMouse.mouseY

                    MouseArea {
                        id: windowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                        drag.target: parent
                        drag.axis: Drag.XAndYAxis

                        onEntered: overviewWindow.hovered = true
                        onExited: overviewWindow.hovered = false

                        onClicked: mouse => {
                            if (!overviewWindow.lookup) return
                            if (mouse.button === Qt.MiddleButton) manager.closeWindow(overviewWindow.compositorAddress)
                            else if (mouse.button === Qt.LeftButton) manager.focusWindow(overviewWindow.compositorAddress)
                        }

                        onPressed: mouse => {
                            if (!overviewWindow.lookup) { mouse.accepted = false; return }
                            overviewWindow.pressed = true
                            overviewWindow.dragInProgress = true
                            manager.dragActive = true
                            manager.draggingAddress = overviewWindow.compositorAddress
                            if (overviewWindow.isRegular) {
                                manager.draggingFromWorkspace = overviewWindow.lookup.workspaceId
                                manager.draggingFromSpecialWorkspace = ""
                            } else {
                                manager.draggingFromWorkspace = -1
                                manager.draggingFromSpecialWorkspace = overviewWindow.lookup.specialName
                            }
                            manager.draggingTargetWorkspace = -1
                            manager.draggingTargetSpecialWorkspace = ""
                        }

                        onReleased: {
                            overviewWindow.pressed = false
                            overviewWindow.dragInProgress = false
                            if (manager.draggingTargetWorkspace < 1 && manager.draggingTargetSpecialWorkspace === "") {
                                manager.clearDragState()
                                overviewWindow.x = overviewWindow.initX
                                overviewWindow.y = overviewWindow.initY
                                return
                            }
                            manager.finishWindowDrag(overviewWindow)
                        }

                        onCanceled: {
                            overviewWindow.pressed = false
                            overviewWindow.dragInProgress = false
                            manager.clearDragState()
                            overviewWindow.x = overviewWindow.initX
                            overviewWindow.y = overviewWindow.initY
                        }
                    }
                }
            }
        }
    }
}
