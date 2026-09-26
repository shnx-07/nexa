import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

import "../theme" as Nexa

// ================================================================
// DISPLAY PROJECTION ISLAND  –  driven by `nexad display info`
//
// JSON fields actually used:
//   current_mode          string   "internal-only" | "extend" | …
//   connected_count       int      how many managed monitors are known
//   active_count          int      how many are currently on
//   internal_count        int
//   external_count        int
//   is_locked             bool
//   lid_closed            bool
//   lid_state             string   "open" | "closed"
//   daemon_running        bool
//   restart_pending       bool
//   primary               string   connector name of primary
//   projection_modes[]
//     .mode               string   id passed to `nexad display mode`
//     .label              string   human label from mode_label()
//     .available          bool     engine decided this mode makes sense
//     .current            bool     this mode is active right now
//   displays[]            – full DisplayInfo struct:
//     .name               string   connector name  "eDP-1", "HDMI-A-1"
//     .description        string   e.g. "Lenovo Group Limited 0x9051"
//     .make / .model      string
//     .connector_kind     string   "internal" | "hdmi" | "dp" | …
//     .width / .height    int      native pixels
//     .logical_width / .logical_height int
//     .refresh_rate       float    Hz
//     .x / .y             int      position on canvas
//     .scale              float
//     .is_internal        bool
//     .is_primary         bool
//     .disabled           bool     true = monitor is currently off
//     .dpms               bool     power state
//     .vrr                bool
//     .focused            bool
//     .managed            bool
//     .mirror_of          string   "none" or connector name
//     .active_workspace   int|null
//     .topology           {x,y,w,h} normalised 0..1 canvas position
//
// Projection mode ids in order from available_projection_modes():
//   "internal-only", "extend", "external-only", "mirror",
//   "extend-left", "extend-up", "extend-down", "extend-grid"
//
// CLI calls dispatched:
//   nexad display mode  <mode>    – switch projection
//   nexad display toggle <name>   – enable / disable one monitor
// ================================================================

Item {
    id: root

    signal requestClose()

    // ── state parsed from JSON ──────────────────────────────────
    property string currentMode:     "internal-only"
    property int    connectedCount:  1
    property int    activeCount:     1
    property int    internalCount:   1
    property int    externalCount:   0
    property bool   isLocked:        false
    property bool   lidClosed:       false
    property string lidState:        "open"
    property bool   daemonRunning:   false
    property bool   restartPending:  false
    property string primaryName:     ""
    property var    projectionModes: []   // array of {mode, label, available, current}
    property var    displays:        []   // array of DisplayInfo objects

    // keyboard-selected card index (within projectionModes that are available)
    property int selectedIndex: 0

    // ── keyboard helpers ─────────────────────────────────────────
    function moveLeft() {
        const avail = root.projectionModes.filter(m => m.available)
        if (avail.length === 0) return
        root.selectedIndex = (root.selectedIndex - 1 + avail.length) % avail.length
    }
    function moveRight() {
        const avail = root.projectionModes.filter(m => m.available)
        if (avail.length === 0) return
        root.selectedIndex = (root.selectedIndex + 1) % avail.length
    }
    function cycleNext() { moveRight() }

    // ── apply mode ───────────────────────────────────────────────
    function applySelected() {
        const avail = root.projectionModes.filter(m => m.available)
        if (avail.length === 0 || root.selectedIndex >= avail.length) return
        applyMode(avail[root.selectedIndex].mode)
    }
    function applyMode(modeId) {
        if (!modeId) return
        Quickshell.execDetached([
            Quickshell.env("HOME") + "/.config/nexa/rust/target/release/nexad",
            "display", "mode", modeId
        ])
        root.requestClose()
    }

    // ── toggle single monitor ────────────────────────────────────
    function toggleMonitor(name) {
        if (!name) return
        Quickshell.execDetached([
            Quickshell.env("HOME") + "/.config/nexa/rust/target/release/nexad",
            "display", "toggle", name
        ])
        refreshTimer.restart()
    }

    // ── refresh ──────────────────────────────────────────────────
    function refreshInfo() {
        infoProcess.running = false
        infoProcess.running = true
    }

    // post-toggle refresh (single shot, not repeating)
    Timer {
        id: refreshTimer
        interval: 500
        repeat: false
        onTriggered: root.refreshInfo()
    }

    // ── data source ──────────────────────────────────────────────
    Process {
        id: infoProcess
        command: [
            Quickshell.env("HOME") + "/.config/nexa/rust/target/release/nexad",
            "display", "info"
        ]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text)
                    if (!d) return

                    // Atomically set every state property
                    root.currentMode     = d.current_mode     || "internal-only"
                    root.connectedCount  = d.connected_count  || 1
                    root.activeCount     = d.active_count     || 1
                    root.internalCount   = d.internal_count   || 0
                    root.externalCount   = d.external_count   || 0
                    root.isLocked        = d.is_locked        || false
                    root.lidClosed       = d.lid_closed       || false
                    root.lidState        = d.lid_state        || "open"
                    root.daemonRunning   = d.daemon_running   || false
                    root.restartPending  = d.restart_pending  || false
                    root.primaryName     = d.primary          || ""
                    root.projectionModes = d.projection_modes || []
                    root.displays        = d.displays         || []

                    // Sync selectedIndex to the currently active mode
                    const avail = root.projectionModes.filter(m => m.available)
                    for (let i = 0; i < avail.length; i++) {
                        if (avail[i].current) { root.selectedIndex = i; break }
                    }
                } catch (_) {}
            }
        }
    }

    onVisibleChanged: {
        if (visible) {
            refreshInfo()
            focusScope.forceActiveFocus()
        }
    }

    // ── icon helpers ─────────────────────────────────────────────
    function monitorIcon(disp) {
        if (disp.is_internal) return "󰌢"
        const k = (disp.connector_kind || "").toLowerCase()
        if (k === "hdmi")                        return "󰡁"
        if (k === "dp" || k === "displayport")   return "󰾴"
        if (k === "usb-c" || k === "thunderbolt") return "󰒡"
        return "󰍹"
    }

    function modeIcon(modeId) {
        switch (modeId) {
        case "internal-only":  return "󰌢"
        case "extend":         return "󰯫"
        case "extend-left":    return "󰯬"
        case "extend-up":      return "󰯭"
        case "extend-down":    return "󰯮"
        case "external-only":  return "󰍹"
        case "mirror":         return "󰍺"
        case "extend-grid":    return "󰠘"
        default:               return "󰍹"
        }
    }

    // ================================================================
    // LAYOUT
    // ================================================================
    FocusScope {
        id: focusScope
        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: root.requestClose()
        Keys.onReturnPressed: root.applySelected()
        Keys.onEnterPressed:  root.applySelected()
        Keys.onLeftPressed:   root.moveLeft()
        Keys.onRightPressed:  root.moveRight()

        ColumnLayout {
            anchors {
                fill: parent
                margins: Nexa.Theme.spacingLg
            }
            spacing: Nexa.Theme.spacingMd

            // ────────────────────────────────────────────────────
            // HEADER ROW
            // ────────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: Nexa.Theme.spacingSm

                Text {
                    text: "󰍹"
                    color: Nexa.Theme.primary
                    font { family: Nexa.Theme.iconFontFamily; pixelSize: Nexa.Theme.fontSizeLg }
                }
                Text {
                    text: "Display"
                    color: Nexa.Theme.text
                    font {
                        family: Nexa.Theme.fontFamily
                        pixelSize: Nexa.Theme.fontSizeMd
                        weight: Nexa.Theme.fontWeightDemiBold
                    }
                }

                Item { Layout.fillWidth: true }

                // Daemon not running warning
                Rectangle {
                    visible: !root.daemonRunning
                    width: daemonLabel.implicitWidth + 12
                    height: 20
                    radius: Nexa.Theme.radiusPill
                    color: Qt.rgba(1, 0.4, 0.2, 0.15)
                    border.width: 1
                    border.color: Qt.rgba(1, 0.4, 0.2, 0.4)
                    Text {
                        id: daemonLabel
                        anchors.centerIn: parent
                        text: "daemon off"
                        color: "#ff7043"
                        font { family: Nexa.Theme.fontFamily; pixelSize: Nexa.Theme.fontSize2Xs }
                    }
                }

                // Lid / lock badge
                Rectangle {
                    visible: root.lidClosed || root.isLocked
                    width: statusLabel.implicitWidth + 12
                    height: 20
                    radius: Nexa.Theme.radiusPill
                    color: Nexa.Theme.surfaceContainerHigh
                    border.width: 1
                    border.color: Nexa.Theme.border
                    Text {
                        id: statusLabel
                        anchors.centerIn: parent
                        text: root.isLocked ? "󰌾 Locked" : "󰌶 Lid closed"
                        color: Nexa.Theme.mutedText
                        font { family: Nexa.Theme.fontFamily; pixelSize: Nexa.Theme.fontSize2Xs }
                    }
                }

                // Screen count pill
                Rectangle {
                    width: screenCount.implicitWidth + 14
                    height: 22
                    radius: Nexa.Theme.radiusPill
                    color: Nexa.Theme.surfaceContainerHigh
                    border.width: Nexa.Theme.borderThin
                    border.color: Nexa.Theme.border
                    Text {
                        id: screenCount
                        anchors.centerIn: parent
                        text: root.connectedCount + " screen" + (root.connectedCount !== 1 ? "s" : "")
                        color: Nexa.Theme.mutedText
                        font { family: Nexa.Theme.fontFamily; pixelSize: Nexa.Theme.fontSizeXs }
                    }
                }

                // Close
                Rectangle {
                    width: 26; height: 26; radius: 13
                    color: closeHover.containsMouse ? Nexa.Theme.surfaceContainerHigh : "transparent"
                    Behavior on color { ColorAnimation { duration: 100 } }
                    Text {
                        anchors.centerIn: parent
                        text: "󰅖"
                        color: Nexa.Theme.mutedText
                        font { family: Nexa.Theme.iconFontFamily; pixelSize: 13 }
                    }
                    MouseArea {
                        id: closeHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.requestClose()
                    }
                }
            }

            // ────────────────────────────────────────────────────
            // PROJECTION CARDS
            // Source: projection_modes[].{mode, label, available, current}
            // Show primary 4 in a row; label comes directly from display.rs
            // ────────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 100
                spacing: Nexa.Theme.spacingSm

                Repeater {
                    model: {
                        const order = ["internal-only", "extend", "external-only", "mirror"]
                        const src   = root.projectionModes
                        return order.map(id => src.find(m => m.mode === id)).filter(x => x !== undefined)
                    }

                    delegate: Rectangle {
                        id: card
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        readonly property bool isAvailable: modelData.available
                        readonly property bool isActive:    modelData.current
                        readonly property int  keyIdx: {
                            const avail = root.projectionModes.filter(m => m.available)
                            for (let i = 0; i < avail.length; i++) {
                                if (avail[i].mode === modelData.mode) return i
                            }
                            return -1
                        }
                        readonly property bool isKeyFocus: isAvailable && (keyIdx === root.selectedIndex)

                        radius:  Nexa.Theme.radiusMd
                        opacity: isAvailable ? 1.0 : 0.35

                        color: {
                            if (isKeyFocus)       return Qt.rgba(Nexa.Theme.primary.r, Nexa.Theme.primary.g, Nexa.Theme.primary.b, 0.12)
                            if (cArea.containsMouse && isAvailable) return Nexa.Theme.interactiveCardHover
                            return Nexa.Theme.cardBackground
                        }
                        border.width: isActive ? Nexa.Theme.borderNormal : Nexa.Theme.borderThin
                        border.color: {
                            if (isActive)   return Nexa.Theme.primary
                            if (isKeyFocus) return Qt.rgba(Nexa.Theme.primary.r, Nexa.Theme.primary.g, Nexa.Theme.primary.b, 0.5)
                            return Nexa.Theme.border
                        }
                        scale: cArea.pressed && isAvailable ? 0.93 : 1.0

                        Behavior on scale { NumberAnimation { duration: 80; easing.type: Easing.OutQuad } }
                        Behavior on color { ColorAnimation { duration: 110 } }
                        Behavior on border.color { ColorAnimation { duration: 110 } }

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 5

                            Rectangle {
                                Layout.alignment: Qt.AlignHCenter
                                width: 38; height: 38; radius: 19
                                color: card.isActive
                                    ? Nexa.Theme.primary
                                    : (card.isKeyFocus
                                        ? Qt.rgba(Nexa.Theme.primary.r, Nexa.Theme.primary.g, Nexa.Theme.primary.b, 0.18)
                                        : Nexa.Theme.surfaceContainerHigh)
                                Behavior on color { ColorAnimation { duration: 110 } }
                                Text {
                                    anchors.centerIn: parent
                                    text: root.modeIcon(modelData.mode)
                                    color: card.isActive ? Nexa.Theme.onPrimary : Nexa.Theme.text
                                    font { family: Nexa.Theme.iconFontFamily; pixelSize: 18 }
                                }
                            }

                            // Label straight from display.rs mode_label()
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                Layout.maximumWidth: card.width - 8
                                text: modelData.label
                                color: card.isActive ? Nexa.Theme.primary : Nexa.Theme.text
                                font {
                                    family: Nexa.Theme.fontFamily
                                    pixelSize: Nexa.Theme.fontSizeSm
                                    weight: card.isActive ? Nexa.Theme.fontWeightDemiBold : Nexa.Theme.fontWeightMedium
                                }
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.WordWrap
                            }

                            // Active underline
                            Rectangle {
                                Layout.alignment: Qt.AlignHCenter
                                visible: card.isActive
                                width: 24; height: 3; radius: 2
                                color: Nexa.Theme.primary
                            }
                        }

                        MouseArea {
                            id: cArea
                            anchors.fill: parent
                            hoverEnabled: card.isAvailable
                            cursorShape: card.isAvailable ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: { if (card.isAvailable) root.applyMode(modelData.mode) }
                            onEntered: { if (card.isAvailable && card.keyIdx >= 0) root.selectedIndex = card.keyIdx }
                        }
                    }
                }
            }

            // ────────────────────────────────────────────────────
            // EXTEND DIRECTION ROW
            // Only visible when external display is connected — shows
            // the direction variants as small chips
            // ────────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 30
                spacing: Nexa.Theme.spacingSm
                visible: root.externalCount > 0

                Text {
                    text: "Extend:"
                    color: Nexa.Theme.mutedText
                    font { family: Nexa.Theme.fontFamily; pixelSize: Nexa.Theme.fontSizeXs }
                    Layout.alignment: Qt.AlignVCenter
                }

                Repeater {
                    model: {
                        const ext = ["extend", "extend-left", "extend-up", "extend-down", "extend-grid"]
                        return root.projectionModes.filter(m => ext.indexOf(m.mode) !== -1)
                    }

                    delegate: Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 26
                        radius: Nexa.Theme.radiusSm
                        color: modelData.current
                            ? Nexa.Theme.primary
                            : (dHover.containsMouse && modelData.available
                                ? Nexa.Theme.interactiveCardHover
                                : Nexa.Theme.cardBackground)
                        border.width: Nexa.Theme.borderThin
                        border.color: modelData.current ? Nexa.Theme.primary : Nexa.Theme.border
                        opacity: modelData.available ? 1.0 : 0.4
                        Behavior on color { ColorAnimation { duration: 90 } }

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 3
                            Text {
                                text: root.modeIcon(modelData.mode)
                                color: modelData.current ? Nexa.Theme.onPrimary : Nexa.Theme.text
                                font { family: Nexa.Theme.iconFontFamily; pixelSize: 11 }
                            }
                            Text {
                                text: {
                                    switch (modelData.mode) {
                                    case "extend":      return "Right"
                                    case "extend-left": return "Left"
                                    case "extend-up":   return "Up"
                                    case "extend-down": return "Down"
                                    case "extend-grid": return "Grid"
                                    default:            return modelData.label
                                    }
                                }
                                color: modelData.current ? Nexa.Theme.onPrimary : Nexa.Theme.text
                                font { family: Nexa.Theme.fontFamily; pixelSize: Nexa.Theme.fontSizeXs }
                            }
                        }

                        MouseArea {
                            id: dHover
                            anchors.fill: parent
                            hoverEnabled: modelData.available
                            cursorShape: modelData.available ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: { if (modelData.available) root.applyMode(modelData.mode) }
                        }
                    }
                }
            }

            // ────────────────────────────────────────────────────
            // MONITOR HARDWARE STRIP
            // Each pill = one entry from displays[]
            // Uses: name, connector_kind, is_internal, is_primary,
            //       width, height, refresh_rate, scale,
            //       disabled, dpms, mirror_of, active_workspace
            // Click = nexad display toggle <name>
            // ────────────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: visible ? 56 : 0
                visible: root.displays.length > 0
                radius: Nexa.Theme.radiusMd
                color: Nexa.Theme.surfaceContainerLow
                border.width: Nexa.Theme.borderThin
                border.color: Nexa.Theme.border

                RowLayout {
                    anchors {
                        fill: parent
                        leftMargin: Nexa.Theme.spacingSm
                        rightMargin: Nexa.Theme.spacingSm
                    }
                    spacing: Nexa.Theme.spacingSm

                    Repeater {
                        model: root.displays

                        delegate: Rectangle {
                            id: pill

                            Layout.fillWidth: true
                            Layout.preferredHeight: 40
                            Layout.alignment: Qt.AlignVCenter

                            readonly property bool monOn:      !modelData.disabled
                            readonly property bool monPrimary: modelData.is_primary === true
                            readonly property bool monInternal:modelData.is_internal === true
                            readonly property bool isMirrored: (modelData.mirror_of || "none") !== "none"
                            readonly property string monName:  modelData.name || "?"
                            readonly property string monRes: {
                                const w = modelData.width  || 0
                                const h = modelData.height || 0
                                const r = (modelData.refresh_rate || 0).toFixed(0)
                                const s = modelData.scale || 1.0
                                let str = (w && h) ? w + "×" + h + " " + r + "Hz" : ""
                                if (s !== 1.0) str += " " + s + "×"
                                return str
                            }

                            radius: Nexa.Theme.radiusSm
                            color: pHover.containsMouse
                                ? Nexa.Theme.interactiveCardHover
                                : (monOn ? Nexa.Theme.cardBackground : Nexa.Theme.surfaceContainer)
                            border.width: monPrimary ? Nexa.Theme.borderNormal : Nexa.Theme.borderThin
                            border.color: monPrimary ? Nexa.Theme.primary
                                        : (monOn ? Nexa.Theme.border : Nexa.Theme.borderSubtle)
                            Behavior on color { ColorAnimation { duration: 90 } }

                            RowLayout {
                                anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                                spacing: 5

                                Text {
                                    text: root.monitorIcon(modelData)
                                    color: pill.monOn ? Nexa.Theme.primary : Nexa.Theme.mutedText
                                    font { family: Nexa.Theme.iconFontFamily; pixelSize: 13 }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1

                                    RowLayout {
                                        spacing: 4
                                        Text {
                                            text: pill.monName
                                            color: pill.monOn ? Nexa.Theme.text : Nexa.Theme.mutedText
                                            font {
                                                family: Nexa.Theme.fontFamily
                                                pixelSize: Nexa.Theme.fontSizeSm
                                                weight: Nexa.Theme.fontWeightDemiBold
                                            }
                                        }
                                        Text {
                                            visible: pill.monPrimary
                                            text: "★"
                                            color: Nexa.Theme.primary
                                            font.pixelSize: 8
                                        }
                                        Rectangle {
                                            visible: pill.isMirrored
                                            width: mlbl.implicitWidth + 6; height: 12; radius: 3
                                            color: Qt.rgba(Nexa.Theme.primary.r, Nexa.Theme.primary.g, Nexa.Theme.primary.b, 0.15)
                                            Text { id: mlbl; anchors.centerIn: parent; text: "mirror"; color: Nexa.Theme.primary; font.pixelSize: 8 }
                                        }
                                        Rectangle {
                                            visible: !pill.monOn
                                            width: olbl.implicitWidth + 6; height: 12; radius: 3
                                            color: Qt.rgba(0.5, 0.5, 0.5, 0.12)
                                            Text { id: olbl; anchors.centerIn: parent; text: "off"; color: Nexa.Theme.mutedText; font.pixelSize: 8 }
                                        }
                                    }
                                    Text {
                                        visible: pill.monRes !== ""
                                        text: pill.monRes
                                        color: Nexa.Theme.mutedText
                                        font { family: Nexa.Theme.fontFamily; pixelSize: Nexa.Theme.fontSize2Xs }
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                }

                                // Workspace badge
                                Rectangle {
                                    visible: !modelData.disabled
                                        && modelData.active_workspace !== undefined
                                        && modelData.active_workspace !== null
                                    width: 18; height: 18; radius: 9
                                    color: Nexa.Theme.surfaceContainerHigh
                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.active_workspace || ""
                                        color: Nexa.Theme.mutedText
                                        font { family: Nexa.Theme.fontFamily; pixelSize: 9 }
                                    }
                                }

                                // Status dot: green=on+dpms, orange=on+dpms-off, grey=disabled
                                Rectangle {
                                    width: 7; height: 7; radius: 4
                                    color: pill.monOn
                                        ? (modelData.dpms ? Nexa.Theme.secondary : "#ff9800")
                                        : Nexa.Theme.borderSubtle
                                    Behavior on color { ColorAnimation { duration: 120 } }
                                }
                            }

                            MouseArea {
                                id: pHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.toggleMonitor(pill.monName)
                            }
                        }
                    }
                }
            }

            // ────────────────────────────────────────────────────
            // FOOTER HINT
            // ────────────────────────────────────────────────────
            Text {
                Layout.fillWidth: true
                text: "← → select  ·  ↵ apply  ·  click monitor to toggle"
                color: Nexa.Theme.mutedText
                font { family: Nexa.Theme.fontFamily; pixelSize: Nexa.Theme.fontSize2Xs }
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
            }
        }
    }
}
