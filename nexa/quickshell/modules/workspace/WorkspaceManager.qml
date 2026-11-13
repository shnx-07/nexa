import QtQuick
import QtQuick.Layouts

import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland

import "../../NewNexaUI" as NexaUI
import "../../services" as Services


PanelWindow {
    id: manager


    // ============================================================
    // NEXA WORKSPACE MANAGER
    //
    // Architecture:
    //
    //  workspace cards
    //       ↓
    //  shared windowSpace
    //       ↓
    //  WorkspaceWindow
    //       ↓
    //  MouseArea.drag.target = WorkspaceWindow
    //
    // Windows DO NOT belong to workspace cards.
    // ============================================================


    // ============================================================
    // CONFIG
    // ============================================================

    readonly property string nexad:
        Quickshell.env("HOME") + "/.config/nexa/rust/target/release/nexad"

    function getWorkspaceLabel(wsId) {
        const style = Services.BarConfig.workspaceStyle || "dots";
        switch (style) {
            case "devanagari":
                const dev = ["०", "१", "२", "३", "४", "५", "६", "७", "८", "९"];
                return String(wsId).split("").map(c => dev[parseInt(c)] || c).join("");
            case "roman":
                const rom = ["", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"];
                return rom[wsId] || String(wsId);
            case "kanji":
                const cjk = ["", "一", "二", "三", "四", "五", "六", "七", "八", "九", "十"];
                return cjk[wsId] || String(wsId);
            case "numbers":
            case "dots":
            default:
                return String(wsId);
        }
    }

    

    readonly property real outerMargin: 52

    readonly property real specialHeight: 150


    // ============================================================
    // OVERVIEW SIZE
    // ============================================================

    property real overviewScale: 0.18

    property real workspaceGap:
        NexaUI.NexaTokens.spacingMd

    property int workspaceColumns: 5
    property int workspaceRows: 2

    property real workspacePreviewWidth: {

        const monitor =
            manager.monitors.length > 0
            ? manager.monitors[0]
            : null

        if (!monitor)
            return 300

        return Math.round(
            Number(monitor.width || 1920)
            * overviewScale
        )
    }


    property real workspacePreviewHeight: {

        const monitor =
            manager.monitors.length > 0
            ? manager.monitors[0]
            : null

        if (!monitor)
            return 170

        return Math.round(
            Number(monitor.height || 1080)
            * overviewScale
        )
    }


    readonly property real regularContentWidth:
        workspaceColumns
        * workspacePreviewWidth
        + (workspaceColumns - 1)
        * workspaceGap


    readonly property real regularContentHeight:
        workspaceRows
        * workspacePreviewHeight
        + (workspaceRows - 1)
        * workspaceGap



    // ============================================================
    // STATE
    // ============================================================

    property bool managerVisible: false

    property var workspaceState: null


    function defaultWorkspaces() {
        const list = []
        const focusedId = (typeof Hyprland !== "undefined" && Hyprland.focusedWorkspace) ? Hyprland.focusedWorkspace.id : 1
        for (let i = 1; i <= 10; ++i) {
            list.push({
                id: i,
                name: i.toString(),
                active: (i === focusedId),
                monitor: "",
                windowCount: 0,
                hasWindows: false
            })
        }
        return list
    }

    readonly property var workspaces: {
        if (workspaceState && workspaceState.workspaces && workspaceState.workspaces.length > 0)
            return workspaceState.workspaces
        return defaultWorkspaces()
    }

    readonly property var specialWorkspaces:
        workspaceState
        && workspaceState.specialWorkspaces
        ? workspaceState.specialWorkspaces
        : []

    readonly property var monitors: {
        if (workspaceState && workspaceState.monitors && workspaceState.monitors.length > 0)
            return workspaceState.monitors
        return [{ id: 0, name: "default", width: 1920, height: 1080 }]
    }


    // ============================================================
    // DRAG STATE
    // ============================================================

    property bool dragActive: false

    property string draggingAddress: ""

    property int draggingFromWorkspace: -1

    property string draggingFromSpecialWorkspace: ""

    property int draggingTargetWorkspace: -1

    property string draggingTargetSpecialWorkspace: ""


    // ============================================================
    // WINDOW
    // ============================================================

    visible:
        managerVisible

    color:
        "transparent"

    aboveWindows:
        true

    focusable:
        true


    anchors {
        left: true
        right: true
        top: true
        bottom: true
    }


    // ============================================================
    // HELPERS
    // ============================================================

    function cleanSpecialName(name) {

        let value =
            String(name || "").trim()

        if (value.startsWith("special:"))
            value = value.slice(8)

        return value
    }


    function clearDragState() {

        dragActive =
            false

        draggingAddress =
            ""

        draggingFromWorkspace =
            -1

        draggingFromSpecialWorkspace =
            ""

        draggingTargetWorkspace =
            -1

        draggingTargetSpecialWorkspace =
            ""
    }


    function openManager() {

        managerVisible =
            true

        reload()
    }


    function closeManager() {

        clearDragState()

        managerVisible =
            false
    }


    function toggleManager() {

        if (managerVisible)
            closeManager()
        else
            openManager()
    }


    // ============================================================
    // IPC
    // ============================================================

    // IpcHandler moved to shell.qml to allow on-demand lazy loading


    // ============================================================
    // RUST WINDOW LOOKUP
    // ============================================================

    function rustWindowForAddress(address) {

        const wanted =
        manager.normalizeAddress(
            address
        )


        if (wanted === "")
            return null


        // --------------------------------------------------------
        // Regular
        // --------------------------------------------------------

        for (
            let i = 0;
            i < workspaces.length;
            ++i
        ) {

            const ws =
                workspaces[i]

            const list =
                ws.windows || []


            for (
                let j = 0;
                j < list.length;
                ++j
            ) {

                const win =
                    list[j]


                if (
                    (win.normAddress && win.normAddress === wanted)
                    || manager.normalizeAddress(win.address) === wanted
                ) {

                    return {
                        windowData:
                            win,

                        workspaceData:
                            ws,

                        workspaceId:
                            Number(ws.id),

                        specialName:
                            ""
                    }
                }
            }
        }


        // --------------------------------------------------------
        // Special
        // --------------------------------------------------------

        for (
            let i = 0;
            i < specialWorkspaces.length;
            ++i
        ) {

            const ws =
                specialWorkspaces[i]

            const list =
                ws.windows || []


            for (
                let j = 0;
                j < list.length;
                ++j
            ) {

                const win =
                    list[j]


                if (
                    (win.normAddress && win.normAddress === wanted)
                    || manager.normalizeAddress(win.address) === wanted
                ) {

                    return {
                        windowData:
                            win,

                        workspaceData:
                            ws,

                        workspaceId:
                            -1,

                        specialName:
                            manager.cleanSpecialName(
                                ws.displayName
                                || ws.name
                                || ""
                            )
                    }
                }
            }
        }


        return null
    }




    // ============================================================
    // TOPLEVEL ADDRESS
    // ============================================================

    function addressForToplevel(toplevel) {

        if (!toplevel)
            return ""

        const address =
            toplevel.HyprlandToplevel.address

        if (!address)
            return ""

        return String(address)
    }


    // ============================================================
    // MONITOR LOOKUP
    // ============================================================

    function monitorForName(name) {

        const wanted =
            String(name || "")


        if (wanted !== "") {

            for (
                let i = 0;
                i < monitors.length;
                ++i
            ) {

                if (
                    String(
                        monitors[i].name || ""
                    )
                    === wanted
                ) {
                    return monitors[i]
                }
            }
        }


        // Focused monitor fallback.

        for (
            let i = 0;
            i < monitors.length;
            ++i
        ) {

            if (monitors[i].focused)
                return monitors[i]
        }


        return monitors.length > 0
            ? monitors[0]
            : null
    }


    // ============================================================
    // WORKSPACE INDEX / GEOMETRY
    // ============================================================

    function workspaceIndex(workspaceId) {

        const id =
            Number(workspaceId)


        if (
            !Number.isFinite(id)
            || id < 1
            || id > 10
        ) {
            return -1
        }


        return id - 1
    }


    function workspaceColumn(workspaceId) {

        const index =
            workspaceIndex(
                workspaceId
            )

        if (index < 0)
            return 0


        return index
            % workspaceColumns
    }


    function workspaceRow(workspaceId) {

        const index =
            workspaceIndex(
                workspaceId
            )

        if (index < 0)
            return 0


        return Math.floor(
            index
            / workspaceColumns
        )
    }


    function workspaceX(workspaceId) {

        const index =
            Number(workspaceId) - 1

        return (
            index % workspaceColumns
        )
        * (
            workspacePreviewWidth
            + workspaceGap
        )
    }


    function workspaceY(workspaceId) {

        const index =
            Number(workspaceId) - 1

        return Math.floor(
            index / workspaceColumns
        )
        * (
            workspacePreviewHeight
            + workspaceGap
        )
    }


    function specialWorkspaceIndex(name) {

        const wanted =
            manager.cleanSpecialName(name)

        for (
            let i = 0;
            i < specialWorkspaces.length;
            ++i
        ) {

            const current =
                manager.cleanSpecialName(
                    specialWorkspaces[i].displayName
                    || specialWorkspaces[i].name
                    || ""
                )

            if (current === wanted)
                return i
        }

        return -1
    }


    function specialTileWidth() {

        return manager.workspacePreviewWidth
    }



    function specialWorkspaceX(name) {

        const index =
            manager.specialWorkspaceIndex(name)

        if (index < 0)
            return 0

        return (
            specialSection.x
            + NexaUI.NexaTokens.spacingMd
            + index
              * (
                  manager.specialTileWidth()
                  + NexaUI.NexaTokens.spacingMd
              )
            - regularGrid.x
        )
    }


    function specialWorkspaceY(name) {

        return (
            specialSection.y
            + specialTitle.y
            + specialTitle.height
            + NexaUI.NexaTokens.spacingSm
            - regularGrid.y
        )
    }


    function specialWorkspaceWidth(name) {

        return manager.specialTileWidth()
    }


    function specialWorkspaceHeight(name) {

        return Math.max(
            1,
            specialSection.height
            - specialTitle.height
            - NexaUI.NexaTokens.spacingMd
            - NexaUI.NexaTokens.spacingSm * 2
        )
    }


    function normalizeAddress(address) {

        let value =
            String(address || "")
            .trim()
            .toLowerCase()

        if (
            value.startsWith("0x")
        ) {
            value =
                value.slice(2)
        }

        return value
    }

  function specialExists(name) {

      const wanted =
          manager.cleanSpecialName(name)

      for (
          let i = 0;
          i < manager.specialWorkspaces.length;
          ++i
      ) {

          const current =
              manager.cleanSpecialName(
                  manager.specialWorkspaces[i].displayName
                  || manager.specialWorkspaces[i].name
                  || ""
              )

          if (current === wanted)
              return true
      }

      return false
  }


    // ============================================================
    // BACKEND
    // ============================================================

    function reload() {

        if (!infoProcess.running)
            infoProcess.running = true
    }


    Timer {
        id: reloadTimer

        interval: 80

        repeat: false

        onTriggered:
            manager.reload()
    }


    Process {
        id: streamProcess

        running: manager.visible && !manager.dragActive

        command: [
            manager.nexad,
            "workspace",
            "stream"
        ]

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                const value = data.trim()
                if (value === "")
                    return
                try {
                    manager.workspaceState = JSON.parse(value)
                } catch (error) {
                    // Ignore partial reads
                }
            }
        }
    }


    Process {
        id: infoProcess

        command: [
            manager.nexad,
            "workspace",
            "info"
        ]


        stdout:
            StdioCollector {

                onStreamFinished: {

                    const value =
                        this.text.trim()


                    if (value === "")
                        return


                    try {

                        manager.workspaceState =
                            JSON.parse(value)

                    } catch (error) {

                        console.warn(
                            "WorkspaceManager:",
                            "invalid workspace JSON",
                            error
                        )
                    }
                }
            }


        stderr:
            StdioCollector {

                onStreamFinished: {

                    if (
                        this.text
                        && this.text.trim() !== ""
                    ) {

                        console.warn(
                            "WorkspaceManager backend:",
                            this.text.trim()
                        )
                    }
                }
            }
    }


    Process {
        id: actionProcess

        property var pendingCommand: []


        command:
            pendingCommand


        stdout:
            StdioCollector {

                onStreamFinished: {

                    if (
                        this.text
                        && this.text.trim() !== ""
                    ) {

                        console.log(
                            "WorkspaceManager:",
                            this.text.trim()
                        )
                    }
                }
            }


        stderr:
            StdioCollector {

                onStreamFinished: {

                    if (
                        this.text
                        && this.text.trim() !== ""
                    ) {

                        console.warn(
                            "WorkspaceManager action:",
                            this.text.trim()
                        )
                    }
                }
            }


        onExited: {

            reloadTimer.restart()
        }
    }


    // ============================================================
    // RUN ACTION
    // ============================================================

    function runAction(args) {

        if (actionProcess.running)
            return false


        actionProcess.pendingCommand =
            [ manager.nexad ].concat(args)


        actionProcess.running =
            true


        return true
    }


    // ============================================================
    // WORKSPACE ACTIONS
    // ============================================================

    function closeWindow(address) {

        if (
            !address
            || address === ""
        ) {
            return
        }

        runAction([
            "workspace",
            "close",
            String(address)
        ])
    }


    function switchWorkspace(id) {

        if (
            runAction([
                "workspace",
                "switch",
                String(id)
            ])
        ) {
            closeManager()
        }
    }


    function focusWindow(address) {

        if (
            !address
            || address === ""
        ) {
            return
        }


        if (
            runAction([
                "workspace",
                "focus",
                String(address)
            ])
        ) {
            closeManager()
        }
    }


    function moveToRegular(
        address,
        workspaceId
    ) {

        runAction([
            "workspace",
            "move",
            String(address),
            String(workspaceId)
        ])
    }


    function moveToSpecial(
        address,
        specialName
    ) {

        if (
            !specialName
            || specialName === ""
        ) {
            return
        }


        runAction([
            "workspace",
            "move-special",
            String(address),
            String(specialName)
        ])
    }


    function toggleSpecial(name) {
        if (!name || name === "") {
            return
        }

        const clean = cleanSpecialName(name)

        if (clean === "terminal" || clean === "files" || clean === "music") {
            runAction([
                "hypr",
                "scratchpad",
                String(clean)
            ])
            return
        }

        runAction([
            "workspace",
            "special",
            String(clean)
        ])
    }


    // ============================================================
    // DROP DECISION
    //
    // Like the working repo:
    //
    // DropArea ONLY tells us which target is under the cursor.
    //
    // Mouse release decides what command to execute.
    // ============================================================

    function finishWindowDrag(
        windowItem
    ) {

        const address =
            draggingAddress


        const regularTarget =
            draggingTargetWorkspace


        const specialTarget =
            draggingTargetSpecialWorkspace


        const sourceWorkspace =
            draggingFromWorkspace


        const sourceSpecial =
            draggingFromSpecialWorkspace


        // --------------------------------------------------------
        // Regular target
        // --------------------------------------------------------

        if (
            regularTarget > 0
            && regularTarget !== sourceWorkspace
        ) {

            if (windowItem) {
                windowItem.workspaceX = manager.workspaceX(regularTarget)
                windowItem.workspaceY = manager.workspaceY(regularTarget)
                windowItem.dragInProgress = false
                windowItem.x = windowItem.initX
                windowItem.y = windowItem.initY
            }

            moveToRegular(
                address,
                regularTarget
            )

            clearDragState()

            return
        }


        // --------------------------------------------------------
        // Special target
        // --------------------------------------------------------

        if (
            specialTarget !== ""
            && specialTarget !== sourceSpecial
        ) {

            if (windowItem) {
                windowItem.workspaceX = manager.specialWorkspaceX(specialTarget)
                windowItem.workspaceY = manager.specialWorkspaceY(specialTarget)
                windowItem.dragInProgress = false
                windowItem.x = windowItem.initX
                windowItem.y = windowItem.initY
            }

            moveToSpecial(
                address,
                specialTarget
            )

            clearDragState()

            return
        }


        // --------------------------------------------------------
        // No valid target.
        //
        // Put preview back at calculated workspace position.
        // --------------------------------------------------------

        clearDragState()


        if (windowItem) {

            windowItem.dragInProgress =
                false

            windowItem.x =
                windowItem.initX

            windowItem.y =
                windowItem.initY
        }
    }


    // ============================================================
    // INITIAL / POLLING
    // ============================================================

    Component.onCompleted:
        reload()


    Timer {
        interval:
            4000

        repeat:
            true

        running:
            manager.visible
            && !manager.dragActive


        onTriggered:
            manager.reload()
    }


    Shortcut {
        sequence:
            "Escape"

        enabled:
            manager.visible


        onActivated:
            manager.closeManager()
    }

    Repeater {
        model: 10
        Item {
            Shortcut {
                sequence: (index + 1) % 10 === 0 ? "0" : String(index + 1)
                enabled: manager.visible && !manager.dragActive
                onActivated: {
                    manager.switchWorkspace(index + 1)
                }
            }
        }
    }


    // ============================================================
    // SCRIM
    // ============================================================

    Rectangle {
        anchors.fill:
            parent

        color:
            NexaUI.NexaColors.scrim


        MouseArea {
            anchors.fill:
                parent

            enabled:
                !manager.dragActive


            onClicked:
                manager.closeManager()
        }
    }


    // ============================================================
    // MAIN BOARD
    // ============================================================

    Rectangle {
        id: board

        width:
            regularContentWidth
            + NexaUI.NexaTokens.spacingLg * 2

        height:
          titleArea.height
          + regularContentHeight
          + specialSection.height
          + NexaUI.NexaTokens.spacingLg * 4

        anchors {
            horizontalCenter:
                parent.horizontalCenter

            top:
                parent.top

            topMargin:
                90
        }


        radius:
            NexaUI.NexaTokens.radiusXl

        color:
            NexaUI.NexaColors.surface

        border.width:
            NexaUI.NexaTokens.borderThin

        border.color:
            NexaUI.NexaColors.border

        opacity:
            manager.managerVisible
            ? 1
            : 0

        scale:
            manager.managerVisible
            ? 1
            : 0.97


        Behavior on opacity {
            NumberAnimation {
                duration:
                    NexaUI.NexaMotion.durationNormal
            }
        }


        Behavior on scale {
            enabled: NexaUI.NexaMotion.enabled
            SpringAnimation {
                spring: NexaUI.NexaMotion.springStiffness
                damping: NexaUI.NexaMotion.springDamping
                epsilon: 0.002
            }
        }

        NexaUI.NexaShaderSubstrate {
            anchors.fill: parent
            radius: board.radius
        }

        // ========================================================
        // TITLE
        // ========================================================

        Item {
            id: titleArea

            anchors {
                top:
                    parent.top

                left:
                    parent.left

                right:
                    parent.right
            }

            height:
                54


            Text {
                anchors {
                    left:
                        parent.left

                    verticalCenter:
                        parent.verticalCenter

                    leftMargin:
                        NexaUI.NexaTokens.spacingLg
                }

                text:
                    "Workspaces"

                color:
                    NexaUI.NexaColors.text

                font {
                    family:
                        NexaUI.NexaTypography.familyBody

                    pixelSize:
                        NexaUI.NexaTypography.sizeXl

                    bold:
                        true
                }
            }

            Text {
                anchors {
                    right:
                        parent.right

                    verticalCenter:
                        parent.verticalCenter

                    rightMargin:
                        NexaUI.NexaTokens.spacingLg
                }

                text:
                    manager.dragActive
                    ? "Move window"
                    : "Drag a window to move it"

                color:
                    manager.dragActive
                    ? NexaUI.NexaColors.primary
                    : NexaUI.NexaColors.mutedText

                font {
                    family:
                        NexaUI.NexaTypography.familyBody

                    pixelSize:
                        NexaUI.NexaTypography.sizeSm
                }
            }
        }


        // ========================================================
        // REGULAR WORKSPACE GRID
        //
        // These are BACKGROUND/DROP TARGETS only.
        // They do NOT contain live windows.
        // ========================================================

        Item {
          id: regularGrid

          width:
              manager.regularContentWidth

          height:
              manager.regularContentHeight

          anchors {
              top:
                  titleArea.bottom

              horizontalCenter:
                  parent.horizontalCenter

              topMargin:
                  NexaUI.NexaTokens.spacingMd
          }


          readonly property real workspaceWidth:
              manager.workspacePreviewWidth

          readonly property real workspaceHeight:
              manager.workspacePreviewHeight


          Repeater {
              model:
                  manager.workspaces


              delegate:
                  NexaUI.NexaCard {
                      id: workspaceTile

                      required property var modelData
                      required property int index

                      readonly property int workspaceId:
                          Number(modelData.id)


                      x:
                          (
                              index
                              % manager.workspaceColumns
                          )
                          * (
                              manager.workspacePreviewWidth
                              + manager.workspaceGap
                          )


                      y:
                          Math.floor(
                              index
                              / manager.workspaceColumns
                          )
                          * (
                              manager.workspacePreviewHeight
                              + manager.workspaceGap
                          )


                      implicitWidth: manager.workspacePreviewWidth
                      implicitHeight: manager.workspacePreviewHeight
                      padding: 0
                      selected: modelData.active

                      scale:
                          workspaceDrop.containsDrag
                          ? 1.015
                          : 1.0


                      Behavior on scale {
                          NumberAnimation {
                              duration:
                                  NexaUI.NexaMotion.durationFast
                          }
                      }


                      border.width:
                          workspaceDrop.containsDrag
                          ? 2
                          : modelData.active
                            ? 2
                            : 1


                      border.color:
                          workspaceDrop.containsDrag
                          ? NexaUI.NexaColors.primary
                          : modelData.active
                            ? NexaUI.NexaColors.primary
                            : NexaUI.NexaColors.border


                      Text {
                          anchors {
                              left:
                                  parent.left

                              top:
                                  parent.top

                              margins:
                                  NexaUI.NexaTokens.spacingSm
                          }

                          text:
                              manager.getWorkspaceLabel(workspaceTile.workspaceId)

                          color:
                              modelData.active
                              ? NexaUI.NexaColors.primary
                              : NexaUI.NexaColors.mutedText

                          font {
                              family:
                                  NexaUI.NexaTypography.familyBody

                              pixelSize:
                                  NexaUI.NexaTypography.sizeMd

                              bold:
                                  true
                          }
                      }


                      Text {
                          anchors.centerIn:
                              parent

                          visible:
                              !modelData.windows
                              || modelData.windows.length === 0

                          text:
                              manager.getWorkspaceLabel(workspaceTile.workspaceId)

                          color:
                              NexaUI.NexaColors.text

                          opacity:
                              0.08

                          font {
                              family:
                                  NexaUI.NexaTypography.familyBody

                              pixelSize:
                                  48

                              bold:
                                  true
                          }
                      }


                      MouseArea {
                          anchors.fill:
                              parent

                          enabled:
                              !manager.dragActive

                          onClicked:
                              manager.switchWorkspace(
                                  workspaceTile.workspaceId
                              )
                      }


                      DropArea {
                          id: workspaceDrop

                          anchors.fill:
                              parent

                          keys: [
                              "nexa-workspace-window"
                          ]


                          onEntered: drag => {

                              if (!manager.dragActive) {
                                  drag.accepted = false
                                  return
                              }

                              drag.accepted = true

                              manager.draggingTargetWorkspace =
                                  workspaceTile.workspaceId

                              manager.draggingTargetSpecialWorkspace =
                                  ""
                          }


                          onExited: {

                              if (
                                  manager.draggingTargetWorkspace
                                  === workspaceTile.workspaceId
                              ) {
                                  manager.draggingTargetWorkspace =
                                      -1
                              }
                          }
                      }
                  }
          }
      }


        // ========================================================
        // SPECIAL WORKSPACES
        // ========================================================

        Rectangle {
            id: specialSection


            anchors {
                top: regularGrid.bottom
                left: parent.left
                right: parent.right

                topMargin: NexaUI.NexaTokens.spacingLg
                leftMargin: NexaUI.NexaTokens.spacingLg
                rightMargin: NexaUI.NexaTokens.spacingLg
            }


            height:
              specialTitle.implicitHeight
              + manager.workspacePreviewHeight
              + NexaUI.NexaTokens.spacingSm
              + NexaUI.NexaTokens.spacingMd * 2

            visible:
                true

            radius:
                NexaUI.NexaTokens.radiusLg


            color:
                NexaUI.NexaColors.surfaceContainerLow


            border.width:
                NexaUI.NexaTokens.borderThin

            border.color:
                NexaUI.NexaColors.border


            Text {
                id: specialTitle


                anchors {
                    left:
                        parent.left

                    top:
                        parent.top

                    margins:
                        NexaUI.NexaTokens.spacingMd
                }


                text:
                    "Scratchpads & Special Workspaces"


                color:
                    NexaUI.NexaColors.mutedText


                font {
                    family:
                        NexaUI.NexaTypography.familyBody

                    pixelSize:
                        NexaUI.NexaTypography.sizeSm

                    bold:
                        true
                }
            }


            Row {
                anchors {
                    left:
                        parent.left

                    right:
                        parent.right

                    top:
                        specialTitle.bottom

                    bottom:
                        parent.bottom

                    leftMargin:
                        NexaUI.NexaTokens.spacingMd

                    rightMargin:
                        NexaUI.NexaTokens.spacingMd

                    topMargin:
                        NexaUI.NexaTokens.spacingSm

                    bottomMargin:
                        NexaUI.NexaTokens.spacingMd
                }


                spacing:
                    NexaUI.NexaTokens.spacingMd

                Repeater {
                    model:
                        manager.specialWorkspaces


                    delegate:
                        NexaUI.NexaCard {
                            id: specialTile


                            required property var modelData
                            required property int index


                            readonly property string specialName:
                                manager.cleanSpecialName(
                                    modelData.displayName
                                    || modelData.name
                                    || ""
                                )

                            readonly property string friendlyTitle: {
                                if (specialName === "terminal") return "Terminal"
                                if (specialName === "files") return "Files"
                                if (specialName === "magic") return "Quick Scratchpad"
                                return specialName.charAt(0).toUpperCase() + specialName.slice(1)
                            }

                            readonly property string scratchIcon: {
                                if (specialName === "terminal") return "󰆍"
                                if (specialName === "files") return "󰉋"
                                if (specialName === "music") return "󰝚"
                                if (specialName === "magic") return "󰏤"
                                return "󰍹"
                            }

                            readonly property int windowCount:
                                modelData.windows ? modelData.windows.length : 0


                            implicitWidth: manager.workspacePreviewWidth
                            implicitHeight: manager.workspacePreviewHeight
                            padding: 0
                            selected: modelData.active

                            border.width:
                                specialDrop.containsDrag
                                ? NexaUI.NexaTokens.borderThick
                                : modelData.active
                                  ? 2
                                  : NexaUI.NexaTokens.borderThin


                            border.color:
                                specialDrop.containsDrag
                                ? NexaUI.NexaColors.primary
                                : modelData.active
                                  ? NexaUI.NexaColors.primary
                                  : NexaUI.NexaColors.border


                            // Header with Icon, Title, and Window Count Badge
                            RowLayout {
                                anchors {
                                    left: parent.left
                                    top: parent.top
                                    right: parent.right
                                    margins: NexaUI.NexaTokens.spacingSm
                                }
                                spacing: NexaUI.NexaTokens.spacingXs

                                Text {
                                    text: specialTile.scratchIcon
                                    color: modelData.active ? NexaUI.NexaColors.primary : NexaUI.NexaColors.text
                                    font.pixelSize: NexaUI.NexaTypography.sizeSm
                                }

                                Text {
                                    text: specialTile.friendlyTitle
                                    color: NexaUI.NexaColors.text
                                    font {
                                        family: NexaUI.NexaTypography.familyBody
                                        pixelSize: NexaUI.NexaTypography.sizeSm
                                        bold: true
                                    }
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }

                                Rectangle {
                                    visible: specialTile.windowCount > 0
                                    implicitWidth: countText.implicitWidth + 8
                                    implicitHeight: 16
                                    radius: 8
                                    color: modelData.active ? NexaUI.NexaColors.primary : Qt.rgba(255, 255, 255, 0.12)

                                    Text {
                                        id: countText
                                        anchors.centerIn: parent
                                        text: String(specialTile.windowCount)
                                        color: modelData.active ? NexaUI.NexaColors.onPrimary : NexaUI.NexaColors.text
                                        font {
                                            pixelSize: 10
                                            bold: true
                                        }
                                    }
                                }
                            }


                            // Empty State Graphic
                            Column {
                                anchors.centerIn: parent
                                visible: specialTile.windowCount === 0
                                spacing: 4

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: specialTile.scratchIcon
                                    color: NexaUI.NexaColors.mutedText
                                    font.pixelSize: 22
                                    opacity: 0.35
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "Click to launch"
                                    color: NexaUI.NexaColors.mutedText
                                    font {
                                        family: NexaUI.NexaTypography.familyBody
                                        pixelSize: NexaUI.NexaTypography.sizeXs
                                    }
                                    opacity: 0.55
                                }
                            }


                            MouseArea {
                                anchors.fill:
                                    parent

                                enabled:
                                    !manager.dragActive

                                cursorShape:
                                    Qt.PointingHandCursor

                                onClicked: {
                                    manager.closeManager()
                                    manager.toggleSpecial(
                                        specialTile.specialName
                                    )
                                }
                            }


                            DropArea {
                                id: specialDrop

                                anchors.fill:
                                    parent

                                keys: [
                                    "nexa-workspace-window"
                                ]

                                onEntered: drag => {
                                    if (
                                        !manager.dragActive
                                        || manager.draggingAddress === ""
                                    ) {
                                        drag.accepted =
                                            false
                                        return
                                    }

                                    drag.accepted =
                                        true

                                    manager.draggingTargetSpecialWorkspace =
                                        specialTile.specialName

                                    manager.draggingTargetWorkspace =
                                        -1
                                }

                                onExited: {
                                    if (
                                        manager.draggingTargetSpecialWorkspace
                                        === specialTile.specialName
                                    ) {
                                        manager.draggingTargetSpecialWorkspace =
                                            ""
                                    }
                                }
                            }
                        }
                }
            }
        }


        // ========================================================
        // SHARED LIVE WINDOW SPACE
        //
        // THIS IS THE IMPORTANT PART.
        //
        // One Repeater for ALL compositor toplevels.
        //
        // WorkspaceWindow items are siblings here.
        // They are NOT children of workspace cards.
        // ========================================================

        Item {
            id: windowSpace


            anchors {
                fill:
                    regularGrid
            }


            z:
                100


            clip:
                false


            Repeater {
                model:
                    ToplevelManager.toplevels.values


                delegate:
                    WorkspaceWindow {
                        id: overviewWindow


                        required property var modelData
                        required property int index


                        // ========================================
                        // LOOKUP
                        // ========================================

                        readonly property string compositorAddress:
                            manager.addressForToplevel(
                                modelData
                            )


                        readonly property var lookup:
                            manager.rustWindowForAddress(
                                compositorAddress
                            )


                        readonly property bool isRegular:
                            lookup
                            && lookup.workspaceId > 0


                        readonly property bool isSpecial:
                            lookup
                            && lookup.specialName !== ""


                        visible:
                            lookup !== null
                            && (
                                isRegular
                                || isSpecial
                            )


                        // ========================================
                        // DATA
                        // ========================================

                        windowData:
                            lookup
                            ? lookup.windowData
                            : null


                        toplevel:
                            modelData

                        livePreview:
                            manager.visible && overviewWindow.visible


                        monitorData:
                            lookup
                            ? manager.monitorForName(
                                lookup.workspaceData.monitor
                            )
                            : null


                        // ========================================
                        // REGULAR POSITION
                        //
                        // Special windows are temporarily placed
                        // over their special card further below.
                        // ========================================

                        workspaceX: {

                            if (!lookup)
                                return 0

                            if (isRegular)
                                return manager.workspaceX(
                                    lookup.workspaceId
                                )

                            if (isSpecial)
                                return manager.specialWorkspaceX(
                                    lookup.specialName
                                )

                            return 0
                        }


                        workspaceY: {

                            if (!lookup)
                                return 0

                            if (isRegular)
                                return manager.workspaceY(
                                    lookup.workspaceId
                                )

                            if (isSpecial)
                                return manager.specialWorkspaceY(
                                    lookup.specialName
                                )

                            return 0
                        }


                        workspaceWidth: {

                            if (isRegular)
                                return regularGrid.workspaceWidth

                            if (isSpecial)
                                return manager.specialWorkspaceWidth(
                                    lookup.specialName
                                )

                            return 1
                        }


                        workspaceHeight: {

                            if (isRegular)
                                return regularGrid.workspaceHeight

                            if (isSpecial)
                                return manager.specialWorkspaceHeight(
                                    lookup.specialName
                                )

                            return 1
                        }


                        // ========================================
                        // SCALE
                        // ========================================

                        previewScaleX: {

                            if (!monitorData)
                                return 0.1

                            return workspaceWidth
                                / Math.max(
                                    1,
                                    Number(
                                        monitorData.width
                                    )
                                )
                        }


                        previewScaleY: {

                            if (!monitorData)
                                return 0.1

                            return workspaceHeight
                                / Math.max(
                                    1,
                                    Number(
                                        monitorData.height
                                    )
                                )
                        }


                        // ========================================
                        // QT DRAG SOURCE
                        // ========================================

                        Drag.active:
                            windowMouse.drag.active


                        Drag.source:
                            overviewWindow


                        Drag.keys: [
                            "nexa-workspace-window"
                        ]


                        Drag.hotSpot.x:
                            windowMouse.mouseX


                        Drag.hotSpot.y:
                            windowMouse.mouseY


                        // ========================================
                        // MOUSE / DRAG
                        // ========================================

                        MouseArea {
                            id: windowMouse


                            anchors.fill:
                                parent


                            hoverEnabled:
                                true


                            acceptedButtons:
                                Qt.LeftButton | Qt.MiddleButton


                            cursorShape:
                                pressed
                                ? Qt.ClosedHandCursor
                                : Qt.OpenHandCursor


                            drag.target:
                                parent


                            drag.axis:
                                Drag.XAndYAxis


                            onEntered:
                                overviewWindow.hovered =
                                    true


                            onExited:
                                overviewWindow.hovered =
                                    false


                            onClicked: mouse => {

                                if (!overviewWindow.lookup)
                                    return

                                if (mouse.button === Qt.MiddleButton) {

                                    manager.closeWindow(
                                        overviewWindow.compositorAddress
                                    )

                                    return
                                }


                                if (mouse.button === Qt.LeftButton) {

                                    manager.focusWindow(
                                        overviewWindow.compositorAddress
                                    )
                                }
                            }


                            onPressed: mouse => {

                                if (!overviewWindow.lookup) {

                                    mouse.accepted =
                                        false

                                    return
                                }


                                overviewWindow.pressed =
                                    true


                                overviewWindow.dragInProgress =
                                    true


                                manager.dragActive =
                                    true


                                manager.draggingAddress =
                                    overviewWindow.compositorAddress


                                if (
                                    overviewWindow.isRegular
                                ) {

                                    manager.draggingFromWorkspace =
                                        overviewWindow.lookup.workspaceId


                                    manager.draggingFromSpecialWorkspace =
                                        ""

                                } else {

                                    manager.draggingFromWorkspace =
                                        -1


                                    manager.draggingFromSpecialWorkspace =
                                        overviewWindow.lookup.specialName
                                }


                                manager.draggingTargetWorkspace =
                                    -1


                                manager.draggingTargetSpecialWorkspace =
                                    ""
                            }


                            onReleased: {

                                overviewWindow.pressed =
                                    false


                                overviewWindow.dragInProgress =
                                    false


                                if (
                                    manager.draggingTargetWorkspace < 1
                                    && manager.draggingTargetSpecialWorkspace === ""
                                ) {

                                    manager.clearDragState()

                                    overviewWindow.x =
                                        overviewWindow.initX

                                    overviewWindow.y =
                                        overviewWindow.initY

                                    return
                                }


                                manager.finishWindowDrag(
                                    overviewWindow
                                )
                            }


                            onCanceled: {

                                overviewWindow.pressed =
                                    false

                                overviewWindow.dragInProgress =
                                    false


                                manager.clearDragState()


                                overviewWindow.x =
                                    overviewWindow.initX

                                overviewWindow.y =
                                    overviewWindow.initY
                            }
                        }


                        


                    }
            }
        }
    }
}

