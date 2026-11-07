// pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../../NewNexaUI" as NexaUI

Item {
    id: root

    anchors.fill: parent

    signal requestClose()

    // ============================================================
    // STATE FROM RUST ENGINE (nexad display info)
    // ============================================================
    property string currentMode: "internal-only"
    property int connectedCount: 1
    property int activeCount: 1
    property int internalCount: 1
    property int externalCount: 0
    property bool isLocked: false
    property bool lidClosed: false
    property string lidState: "open"
    property bool daemonRunning: false
    property bool restartPending: false
    property string primaryName: ""
    property var projectionModes: []
    property var displays: []
    property var wallpapers: ({})
    property string extendDirection: "right"

    // Busy debounce guard to prevent overlapping dispatches
    property bool busy: false

    // Selected display for configuration
    property string selectedDisplayName: ""
    property var selectedDisplay: {
        for (let i = 0; i < root.displays.length; i++) {
            if (root.displays[i].name === root.selectedDisplayName) {
                return root.displays[i];
            }
        }
        return root.displays.length > 0 ? root.displays[0] : null;
    }

    readonly property string nexadBin: Quickshell.env("HOME") + "/.config/nexa/rust/target/release/nexad"

    // Toast status message
    property string toastMessage: ""
    property bool toastVisible: false

    // 15-Second Safe Confirmation Modal
    property bool showConfirmationModal: false
    property int revertCountdown: 15
    property string pendingActionDescription: "Display settings changed"

    function rad(n) {
        if (NexaUI.NexaTokens.nexaRounding === 0) return 0;
        return Math.max(0, Math.round(n * (NexaUI.NexaTokens.nexaRounding / 10.0)));
    }

    function showToast(msg) {
        toastMessage = msg;
        toastVisible = true;
        toastTimer.restart();
    }

    Timer {
        id: toastTimer
        interval: 2400
        repeat: false
        onTriggered: root.toastVisible = false
    }

    // Safety Countdown Timer
    Timer {
        id: revertTimer
        interval: 1000
        repeat: true
        running: root.showConfirmationModal
        onTriggered: {
            if (root.revertCountdown > 1) {
                root.revertCountdown -= 1;
            } else {
                root.revertCountdown = 0;
                root.showConfirmationModal = false;
                root.revertNow();
            }
        }
    }

    function startSafetyCountdown(desc) {
        root.pendingActionDescription = desc || "Display settings changed";
        root.revertCountdown = 15;
        root.showConfirmationModal = true;
    }

    function keepChanges() {
        root.showConfirmationModal = false;
        showToast("✓ Display settings kept");
    }

    function revertNow() {
        root.showConfirmationModal = false;
        showToast("Reverting to safe display settings...");
        Quickshell.execDetached([root.nexadBin, "display", "emergency"]);
        refreshTimer.restart();
    }

    // ============================================================
    // DISPLAY DATA HELPERS
    // ============================================================
    function getDispWidth(d) {
        if (!d) return 1920;
        if (d.current_mode && d.current_mode.width) return d.current_mode.width;
        return d.width || 1920;
    }

    function getDispHeight(d) {
        if (!d) return 1080;
        if (d.current_mode && d.current_mode.height) return d.current_mode.height;
        return d.height || 1080;
    }

    function getDispRefresh(d) {
        if (!d) return 60;
        if (d.current_mode && d.current_mode.refresh_hz) return Math.round(d.current_mode.refresh_hz);
        return Math.round(d.refresh_rate || 60);
    }

    function getDispFormattedMode(d) {
        if (!d) return "1920x1080@60.00";
        if (d.current_mode && d.current_mode.formatted) return d.current_mode.formatted;
        return getDispWidth(d) + "x" + getDispHeight(d) + "@" + getDispRefresh(d) + ".00";
    }

    function isDispInternal(d) {
        if (!d) return false;
        return d.connector_type === "internal" || d.is_internal === true;
    }

    function getDispTitle(d) {
        if (!d) return "Display";
        if (d.make && d.model) return d.make + " " + d.model;
        if (d.description) return d.description;
        return d.name;
    }

    function getMonitorIcon(disp) {
        if (!disp) return "󰍹";
        if (isDispInternal(disp)) return "󰌢";
        const n = (disp.name || "").toLowerCase();
        if (n.startsWith("hdmi")) return "󰡁";
        if (n.startsWith("dp")) return "󰾴";
        return "󰍹";
    }

    // ============================================================
    // REFRESH & IPC LOGIC
    // ============================================================
    function refreshInfo() {
        infoProcess.running = false;
        infoProcess.running = true;
    }

    Timer {
        id: refreshTimer
        interval: 400
        repeat: false
        onTriggered: {
            root.refreshInfo();
            root.busy = false;
        }
    }

    Process {
        id: infoProcess
        command: [root.nexadBin, "display", "info", "--json"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text);
                    if (!d) return;

                    root.currentMode = d.current_mode || "internal-only";
                    root.connectedCount = d.connected_count || 1;
                    root.activeCount = d.active_count || 1;
                    root.internalCount = d.internal_count || 0;
                    root.externalCount = d.external_count || 0;
                    root.isLocked = d.is_locked || false;
                    root.lidClosed = d.lid_closed || false;
                    root.lidState = d.lid_state || "open";
                    root.daemonRunning = d.daemon_running || false;
                    root.restartPending = d.restart_pending || false;
                    root.primaryName = d.primary || d.primary_name || "";
                    root.projectionModes = d.projection_modes || [];
                    root.displays = d.displays || [];
                    root.wallpapers = d.wallpapers || ({});

                    // Update extendDirection from projectionModes if present
                    if (d.projection_modes) {
                        for (let i = 0; i < d.projection_modes.length; i++) {
                            if (d.projection_modes[i].mode === "extend" && d.projection_modes[i].direction) {
                                root.extendDirection = d.projection_modes[i].direction;
                            }
                        }
                    }

                    // Ensure selectedDisplayName points to a valid display
                    if (!root.selectedDisplayName && root.displays.length > 0) {
                        root.selectedDisplayName = root.primaryName || root.displays[0].name;
                    } else if (root.selectedDisplayName) {
                        let exists = false;
                        for (let i = 0; i < root.displays.length; i++) {
                            if (root.displays[i].name === root.selectedDisplayName) {
                                exists = true;
                                break;
                            }
                        }
                        if (!exists && root.displays.length > 0) {
                            root.selectedDisplayName = root.primaryName || root.displays[0].name;
                        }
                    }
                } catch (_) {}
            }
        }
    }

    onVisibleChanged: {
        if (visible) {
            refreshInfo();
        }
    }

    // ============================================================
    // SAFE COMMAND DISPATCHERS
    // ============================================================
    function applyProjection(modeId, direction) {
        if (!modeId || root.busy) return;
        const dir = direction || root.extendDirection || "right";
        root.busy = true;
        showToast("Applying " + modeId + " mode...");
        if (modeId === "extend") {
            Quickshell.execDetached([root.nexadBin, "display", "mode", "extend", dir]);
        } else {
            Quickshell.execDetached([root.nexadBin, "display", "mode", modeId]);
        }
        startSafetyCountdown("Applied " + modeId + " mode");
        refreshTimer.restart();
    }

    function setScale(name, scaleVal) {
        if (!name || root.busy) return;
        if (root.selectedDisplay && Math.abs((root.selectedDisplay.scale || 1.0) - scaleVal) < 0.05) return;
        root.busy = true;
        showToast("Setting scale " + Math.round(scaleVal * 100) + "% on " + name);
        Quickshell.execDetached([root.nexadBin, "display", "scale", name, scaleVal.toString()]);
        startSafetyCountdown("Display scale changed to " + Math.round(scaleVal * 100) + "%");
        refreshTimer.restart();
    }

    function setResolution(name, modeStr) {
        if (!name || !modeStr || root.busy) return;
        root.busy = true;
        showToast("Setting resolution " + modeStr + " on " + name);
        Quickshell.execDetached([root.nexadBin, "display", "res", name, modeStr]);
        startSafetyCountdown("Resolution set to " + modeStr);
        refreshTimer.restart();
    }

    function setRotation(name, rot) {
        if (!name || root.busy) return;
        if (root.selectedDisplay && (root.selectedDisplay.transform || 0) === rot) return;
        root.busy = true;
        const deg = rot === 1 ? 90 : rot === 2 ? 180 : rot === 3 ? 270 : 0;
        showToast("Rotating " + name + " to " + deg + "°");
        Quickshell.execDetached([root.nexadBin, "display", "rotate", name, deg.toString()]);
        startSafetyCountdown("Display rotation set to " + deg + "°");
        refreshTimer.restart();
    }

    function emergencyReset() {
        if (root.busy) return;
        root.busy = true;
        showToast("Triggering Emergency Fallback (Internal screen @ 1080p)...");
        Quickshell.execDetached([root.nexadBin, "display", "emergency"]);
        refreshTimer.restart();
    }

    // ============================================================
    // MAIN CONTENT SCROLL VIEW
    // ============================================================
    Flickable {
        id: scrollContent
        anchors.fill: parent
        anchors.margins: 16
        contentWidth: width
        contentHeight: contentCol.implicitHeight + 40
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        NexaUI.NexaSmoothScroll {}

        Column {
            id: contentCol
            width: parent.width
            spacing: 18

            // ────────────────────────────────────────────────────────────
            // 1. TOP HEADER & GLOBAL ACTIONS
            // ────────────────────────────────────────────────────────────
            RowLayout {
                width: parent.width
                spacing: 12

                Column {
                    Layout.fillWidth: true
                    spacing: 3

                    Row {
                        spacing: 8
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "󰍹"
                            font.family: NexaUI.NexaTypography.familyIcon
                            font.pixelSize: 18
                            color: NexaUI.NexaColors.primary
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Displays"
                            font.family: NexaUI.NexaTypography.familyBody
                            font.pixelSize: 16
                            font.weight: Font.Bold
                            color: NexaUI.NexaColors.text
                        }

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: countLabel.implicitWidth + 14
                            height: 22
                            radius: root.rad(11)
                            color: NexaUI.NexaColors.surfaceContainerHighest
                            border.width: NexaUI.NexaTokens.borderThin
                            border.color: NexaUI.NexaColors.borderSubtle

                            Text {
                                id: countLabel
                                anchors.centerIn: parent
                                text: root.connectedCount + (root.connectedCount === 1 ? " display connected" : " displays connected")
                                font.family: NexaUI.NexaTypography.familyBody
                                font.pixelSize: 11
                                font.weight: Font.Medium
                                color: NexaUI.NexaColors.mutedText
                            }
                        }

                        // Clamshell badge if lid is closed
                        Rectangle {
                            visible: root.lidClosed
                            anchors.verticalCenter: parent.verticalCenter
                            width: clamText.implicitWidth + 12
                            height: 22
                            radius: root.rad(11)
                            color: Qt.rgba(1, 0.6, 0.1, 0.18)
                            border.width: NexaUI.NexaTokens.borderThin
                            border.color: Qt.rgba(1, 0.6, 0.1, 0.4)

                            Text {
                                id: clamText
                                anchors.centerIn: parent
                                text: "󰌢 Lid Closed (Clamshell)"
                                font.family: NexaUI.NexaTypography.familyBody
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                                color: "#ff9800"
                            }
                        }
                    }

                    Text {
                        text: "Manage arrangement, projection mode, resolution, orientation, and scaling"
                        font.family: NexaUI.NexaTypography.familyBody
                        font.pixelSize: 12
                        color: NexaUI.NexaColors.mutedText
                    }
                }

                // Header actions
                Row {
                    spacing: 8
                    Layout.alignment: Qt.AlignVCenter

                    // Refresh Button
                    Rectangle {
                        width: refRow.implicitWidth + 16
                        height: 32
                        radius: root.rad(8)
                        color: refHover.containsMouse ? NexaUI.NexaColors.surfaceContainerHighest : NexaUI.NexaColors.surfaceContainerHigh
                        border.width: NexaUI.NexaTokens.borderThin
                        border.color: NexaUI.NexaColors.border

                        Row {
                            id: refRow
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "󰑐"
                                font.family: NexaUI.NexaTypography.familyIcon
                                font.pixelSize: 13
                                color: NexaUI.NexaColors.text
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Refresh"
                                font.family: NexaUI.NexaTypography.familyBody
                                font.pixelSize: 12
                                font.weight: Font.Medium
                                color: NexaUI.NexaColors.text
                            }
                        }

                        MouseArea {
                            id: refHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.refreshInfo()
                        }
                    }

                    // Emergency Fallback Reset Button
                    Rectangle {
                        width: emRow.implicitWidth + 16
                        height: 32
                        radius: root.rad(8)
                        color: emHover.containsMouse ? Qt.rgba(0.9, 0.2, 0.2, 0.25) : Qt.rgba(0.9, 0.2, 0.2, 0.12)
                        border.width: NexaUI.NexaTokens.borderThin
                        border.color: Qt.rgba(0.9, 0.2, 0.2, 0.35)

                        Row {
                            id: emRow
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "󰀦"
                                font.family: NexaUI.NexaTypography.familyIcon
                                font.pixelSize: 13
                                color: "#ff5252"
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Emergency Reset"
                                font.family: NexaUI.NexaTypography.familyBody
                                font.pixelSize: 12
                                font.weight: Font.Medium
                                color: "#ff5252"
                            }
                        }

                        MouseArea {
                            id: emHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.emergencyReset()
                        }
                    }
                }
            }

            // ────────────────────────────────────────────────────────────
            // 2. VISUAL MONITOR ARRANGEMENT CANVAS (macOS / Win 11 style)
            // ────────────────────────────────────────────────────────────
            Rectangle {
                width: parent.width
                height: 175
                radius: root.rad(12)
                color: NexaUI.NexaColors.surfaceContainerLowest || NexaUI.NexaColors.surfaceContainer
                border.width: NexaUI.NexaTokens.borderThin
                border.color: NexaUI.NexaColors.border

                Item {
                    anchors.fill: parent
                    anchors.margins: 14

                    RowLayout {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right

                        Text {
                            text: "Display Arrangement"
                            font.family: NexaUI.NexaTypography.familyBody
                            font.pixelSize: 12
                            font.weight: Font.SemiBold
                            color: NexaUI.NexaColors.text
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: "Click a screen below to configure"
                            font.family: NexaUI.NexaTypography.familyBody
                            font.pixelSize: 11
                            color: NexaUI.NexaColors.mutedText
                        }
                    }

                    // Centered monitors flow
                    Row {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: 8
                        spacing: 16

                        Repeater {
                            model: root.displays

                            delegate: Rectangle {
                                id: screenBox
                                readonly property var disp: modelData
                                readonly property bool isSelected: root.selectedDisplayName === disp.name
                                readonly property bool isPrimary: root.primaryName === disp.name
                                readonly property bool isEnabled: disp.enabled !== false
                                readonly property int dispW: root.getDispWidth(disp)
                                readonly property int dispH: root.getDispHeight(disp)

                                width: Math.max(130, Math.min(210, dispW / 14))
                                height: 96
                                radius: root.rad(10)
                                color: isSelected
                                    ? NexaUI.NexaColors.surfaceContainerHighest
                                    : (screenHover.containsMouse ? NexaUI.NexaColors.surfaceContainerHigh : NexaUI.NexaColors.surfaceContainer)
                                border.width: isSelected ? Math.max(2, NexaUI.NexaTokens.borderThin) : NexaUI.NexaTokens.borderThin
                                border.color: isSelected
                                    ? NexaUI.NexaColors.primary
                                    : (isPrimary ? Qt.rgba(NexaUI.NexaColors.primary.r, NexaUI.NexaColors.primary.g, NexaUI.NexaColors.primary.b, 0.45) : NexaUI.NexaColors.border)

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 4
                                    width: parent.width - 16

                                    Row {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        spacing: 6

                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: root.getMonitorIcon(disp)
                                            font.family: NexaUI.NexaTypography.familyIcon
                                            font.pixelSize: 16
                                            color: isEnabled ? NexaUI.NexaColors.primary : NexaUI.NexaColors.mutedText
                                        }

                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: disp.name
                                            font.family: NexaUI.NexaTypography.familyBody
                                            font.pixelSize: 12
                                            font.weight: Font.Bold
                                            color: isEnabled ? NexaUI.NexaColors.text : NexaUI.NexaColors.mutedText
                                        }

                                        Text {
                                            visible: isPrimary
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "★"
                                            font.pixelSize: 10
                                            color: NexaUI.NexaColors.primary
                                        }
                                    }

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: dispW + "×" + dispH + " (" + root.getDispRefresh(disp) + "Hz)"
                                        font.family: NexaUI.NexaTypography.familyBody
                                        font.pixelSize: 10
                                        color: NexaUI.NexaColors.mutedText
                                    }

                                    Rectangle {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        width: statusTxt.implicitWidth + 8
                                        height: 16
                                        radius: root.rad(4)
                                        border.width: NexaUI.NexaTokens.borderThin
                                        border.color: NexaUI.NexaColors.borderSubtle
                                        color: !isEnabled
                                            ? Qt.rgba(0.5, 0.5, 0.5, 0.15)
                                            : (isPrimary ? Qt.rgba(NexaUI.NexaColors.primary.r, NexaUI.NexaColors.primary.g, NexaUI.NexaColors.primary.b, 0.15) : NexaUI.NexaColors.surfaceContainerHighest)

                                        Text {
                                            id: statusTxt
                                            anchors.centerIn: parent
                                            text: !isEnabled ? "Disabled" : (isPrimary ? "Main Screen" : "Active")
                                            font.family: NexaUI.NexaTypography.familyBody
                                            font.pixelSize: 9
                                            font.weight: Font.SemiBold
                                            color: !isEnabled ? NexaUI.NexaColors.mutedText : (isPrimary ? NexaUI.NexaColors.primary : NexaUI.NexaColors.text)
                                        }
                                    }
                                }

                                MouseArea {
                                    id: screenHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.selectedDisplayName = disp.name
                                }
                            }
                        }
                    }
                }
            }

            // ────────────────────────────────────────────────────────────
            // 3. PROJECTION MODES & EXTEND DIRECTION
            // ────────────────────────────────────────────────────────────
            Column {
                width: parent.width
                spacing: 8

                RowLayout {
                    width: parent.width
                    Text {
                        text: "Projection Mode"
                        font.family: NexaUI.NexaTypography.familyBody
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        color: NexaUI.NexaColors.text
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        visible: root.externalCount === 0
                        text: "Connect an external display to mirror or extend"
                        font.family: NexaUI.NexaTypography.familyBody
                        font.pixelSize: 11
                        color: NexaUI.NexaColors.mutedText
                    }
                }

                RowLayout {
                    width: parent.width
                    spacing: 10

                    Repeater {
                        model: [
                            { id: "internal-only", label: "PC screen only", icon: "󰌢" },
                            { id: "mirror", label: "Duplicate", icon: "󰍺" },
                            { id: "extend", label: "Extend", icon: "󰯫" },
                            { id: "external-only", label: "Second screen only", icon: "󰍹" }
                        ]

                        delegate: Rectangle {
                            id: projCard
                            readonly property var item: modelData
                            readonly property bool isCurrent: root.currentMode === item.id
                            readonly property bool isAvailable: {
                                if (item.id === "internal-only") return true;
                                return root.externalCount > 0;
                            }

                            Layout.fillWidth: true
                            height: 48
                            radius: root.rad(8)
                            opacity: isAvailable ? 1.0 : 0.45
                            color: isCurrent
                                ? NexaUI.NexaColors.primaryContainer
                                : (projHover.containsMouse && isAvailable ? NexaUI.NexaColors.surfaceContainerHigh : NexaUI.NexaColors.surfaceContainer)
                            border.width: isCurrent ? Math.max(1.5, NexaUI.NexaTokens.borderThin) : NexaUI.NexaTokens.borderThin
                            border.color: isCurrent ? NexaUI.NexaColors.primary : NexaUI.NexaColors.border

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 8

                                Text {
                                    text: item.icon
                                    font.family: NexaUI.NexaTypography.familyIcon
                                    font.pixelSize: 16
                                    color: isCurrent ? NexaUI.NexaColors.onPrimaryContainer : NexaUI.NexaColors.text
                                }

                                Text {
                                    text: item.label
                                    font.family: NexaUI.NexaTypography.familyBody
                                    font.pixelSize: 12
                                    font.weight: isCurrent ? Font.Bold : Font.Medium
                                    color: isCurrent ? NexaUI.NexaColors.onPrimaryContainer : NexaUI.NexaColors.text
                                }
                            }

                            MouseArea {
                                id: projHover
                                anchors.fill: parent
                                enabled: projCard.isAvailable && !root.busy
                                hoverEnabled: enabled
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: root.applyProjection(item.id)
                            }
                        }
                    }
                }

                // Extend Direction Pills (Shown when in Extend Mode)
                RowLayout {
                    visible: root.currentMode === "extend" && root.externalCount > 0
                    width: parent.width
                    spacing: 8

                    Text {
                        text: "Extend placement:"
                        font.family: NexaUI.NexaTypography.familyBody
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        color: NexaUI.NexaColors.mutedText
                    }

                    Repeater {
                        model: [
                            { id: "right", label: "Right 󰄼" },
                            { id: "left", label: "󰄼 Left" },
                            { id: "above", label: "Above 󰄿" },
                            { id: "below", label: "Below 󰄽" }
                        ]

                        delegate: Rectangle {
                            id: dirChip
                            readonly property var item: modelData
                            readonly property bool isSelected: root.extendDirection === item.id

                            width: dirTxt.implicitWidth + 16
                            height: 26
                            radius: root.rad(6)
                            color: isSelected ? NexaUI.NexaColors.primary : (dirHover.containsMouse ? NexaUI.NexaColors.surfaceContainerHighest : NexaUI.NexaColors.surfaceContainerHigh)
                            border.width: NexaUI.NexaTokens.borderThin
                            border.color: isSelected ? NexaUI.NexaColors.primary : NexaUI.NexaColors.border

                            Text {
                                id: dirTxt
                                anchors.centerIn: parent
                                text: item.label
                                font.family: NexaUI.NexaTypography.familyBody
                                font.pixelSize: 11
                                font.weight: isSelected ? Font.Bold : Font.Normal
                                color: isSelected ? NexaUI.NexaColors.onPrimary : NexaUI.NexaColors.text
                            }

                            MouseArea {
                                id: dirHover
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.extendDirection = item.id;
                                    root.applyProjection("extend", item.id);
                                }
                            }
                        }
                    }
                }
            }

            // ────────────────────────────────────────────────────────────
            // 4. SELECTED MONITOR DETAILED CONTROLS
            // ────────────────────────────────────────────────────────────
            Rectangle {
                width: parent.width
                height: monitorSettingsCol.implicitHeight + 32
                radius: root.rad(12)
                color: NexaUI.NexaColors.surfaceContainer
                border.width: NexaUI.NexaTokens.borderThin
                border.color: NexaUI.NexaColors.border

                Column {
                    id: monitorSettingsCol
                    anchors {
                        top: parent.top
                        left: parent.left
                        right: parent.right
                        margins: 16
                    }
                    spacing: 16

                    // Header row for selected monitor
                    RowLayout {
                        width: parent.width
                        spacing: 10

                        Text {
                            text: root.getMonitorIcon(root.selectedDisplay)
                            font.family: NexaUI.NexaTypography.familyIcon
                            font.pixelSize: 22
                            color: NexaUI.NexaColors.primary
                        }

                        Column {
                            Layout.fillWidth: true
                            spacing: 2

                            Row {
                                spacing: 8

                                Text {
                                    text: root.getDispTitle(root.selectedDisplay)
                                    font.family: NexaUI.NexaTypography.familyBody
                                    font.pixelSize: 14
                                    font.weight: Font.Bold
                                    color: NexaUI.NexaColors.text
                                }

                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: connKindText.implicitWidth + 8
                                    height: 18
                                    radius: root.rad(4)
                                    color: NexaUI.NexaColors.surfaceContainerHighest
                                    border.width: NexaUI.NexaTokens.borderThin
                                    border.color: NexaUI.NexaColors.borderSubtle

                                    Text {
                                        id: connKindText
                                        anchors.centerIn: parent
                                        text: root.selectedDisplay ? (root.isDispInternal(root.selectedDisplay) ? "INTERNAL" : "EXTERNAL") : ""
                                        font.family: NexaUI.NexaTypography.familyBody
                                        font.pixelSize: 10
                                        font.weight: Font.SemiBold
                                        color: NexaUI.NexaColors.mutedText
                                    }
                                }
                            }

                            Text {
                                text: root.selectedDisplay ? ("Port: " + root.selectedDisplay.name + (root.isDispInternal(root.selectedDisplay) ? " (Built-in Display)" : " (External Display)")) : ""
                                font.family: NexaUI.NexaTypography.familyBody
                                font.pixelSize: 11
                                color: NexaUI.NexaColors.mutedText
                            }
                        }
                    }

                    Rectangle { width: parent.width; height: 1; color: NexaUI.NexaColors.border }

                    // Display Scaling
                    Column {
                        width: parent.width
                        spacing: 8

                        RowLayout {
                            width: parent.width
                            Text {
                                text: "Display Scale"
                                font.family: NexaUI.NexaTypography.familyBody
                                font.pixelSize: 13
                                font.weight: Font.Medium
                                color: NexaUI.NexaColors.text
                            }

                            Item { Layout.fillWidth: true }

                            Text {
                                text: root.selectedDisplay ? Math.round((root.selectedDisplay.scale || 1.0) * 100) + "%" : "100%"
                                font.family: NexaUI.NexaTypography.familyBody
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                                color: NexaUI.NexaColors.primary
                            }
                        }

                        Row {
                            spacing: 8

                            Repeater {
                                model: [1.0, 1.25, 1.5, 1.75, 2.0]

                                delegate: Rectangle {
                                    id: scaleChip
                                    readonly property real sVal: modelData
                                    readonly property bool isCurrentScale: root.selectedDisplay && Math.abs((root.selectedDisplay.scale || 1.0) - sVal) < 0.05

                                    width: 76
                                    height: 32
                                    radius: root.rad(6)
                                    color: isCurrentScale
                                        ? NexaUI.NexaColors.primary
                                        : (sHover.containsMouse ? NexaUI.NexaColors.surfaceContainerHighest : NexaUI.NexaColors.surfaceContainerHigh)
                                    border.width: NexaUI.NexaTokens.borderThin
                                    border.color: isCurrentScale ? NexaUI.NexaColors.primary : NexaUI.NexaColors.border

                                    Text {
                                        anchors.centerIn: parent
                                        text: Math.round(sVal * 100) + "%"
                                        font.family: NexaUI.NexaTypography.familyBody
                                        font.pixelSize: 12
                                        font.weight: isCurrentScale ? Font.Bold : Font.Normal
                                        color: isCurrentScale ? NexaUI.NexaColors.onPrimary : NexaUI.NexaColors.text
                                    }

                                    MouseArea {
                                        id: sHover
                                        anchors.fill: parent
                                        enabled: !root.busy
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: if (root.selectedDisplay) root.setScale(root.selectedDisplay.name, sVal)
                                    }
                                }
                            }
                        }
                    }

                    Rectangle { width: parent.width; height: 1; color: NexaUI.NexaColors.border }

                    // Display Orientation / Rotation
                    Column {
                        width: parent.width
                        spacing: 8

                        Text {
                            text: "Orientation"
                            font.family: NexaUI.NexaTypography.familyBody
                            font.pixelSize: 13
                            font.weight: Font.Medium
                            color: NexaUI.NexaColors.text
                        }

                        Row {
                            spacing: 8

                            Repeater {
                                model: [
                                    { rot: 0, label: "Landscape (0°)", icon: "󰹑" },
                                    { rot: 1, label: "Portrait (90°)", icon: "󰹒" },
                                    { rot: 2, label: "Flipped (180°)", icon: "󰹑" },
                                    { rot: 3, label: "Portrait Flipped (270°)", icon: "󰹒" }
                                ]

                                delegate: Rectangle {
                                    id: rotChip
                                    readonly property var item: modelData
                                    readonly property bool isCurrentRot: root.selectedDisplay && (root.selectedDisplay.transform || 0) === item.rot

                                    width: rotRow.implicitWidth + 20
                                    height: 32
                                    radius: root.rad(6)
                                    color: isCurrentRot
                                        ? NexaUI.NexaColors.primary
                                        : (rHover.containsMouse ? NexaUI.NexaColors.surfaceContainerHighest : NexaUI.NexaColors.surfaceContainerHigh)
                                    border.width: NexaUI.NexaTokens.borderThin
                                    border.color: isCurrentRot ? NexaUI.NexaColors.primary : NexaUI.NexaColors.border

                                    Row {
                                        id: rotRow
                                        anchors.centerIn: parent
                                        spacing: 6

                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: item.icon
                                            font.family: NexaUI.NexaTypography.familyIcon
                                            font.pixelSize: 13
                                            color: isCurrentRot ? NexaUI.NexaColors.onPrimary : NexaUI.NexaColors.text
                                        }

                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: item.label
                                            font.family: NexaUI.NexaTypography.familyBody
                                            font.pixelSize: 12
                                            font.weight: isCurrentRot ? Font.Bold : Font.Normal
                                            color: isCurrentRot ? NexaUI.NexaColors.onPrimary : NexaUI.NexaColors.text
                                        }
                                    }

                                    MouseArea {
                                        id: rHover
                                        anchors.fill: parent
                                        enabled: !root.busy
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: if (root.selectedDisplay) root.setRotation(root.selectedDisplay.name, item.rot)
                                    }
                                }
                            }
                        }
                    }

                    Rectangle { width: parent.width; height: 1; color: NexaUI.NexaColors.border }

                    // Available Resolutions & Refresh Rates
                    Column {
                        width: parent.width
                        spacing: 8

                        RowLayout {
                            width: parent.width
                            Text {
                                text: "Resolution & Refresh Rate"
                                font.family: NexaUI.NexaTypography.familyBody
                                font.pixelSize: 13
                                font.weight: Font.Medium
                                color: NexaUI.NexaColors.text
                            }

                            Item { Layout.fillWidth: true }

                            Text {
                                text: root.selectedDisplay ? (root.getDispWidth(root.selectedDisplay) + "×" + root.getDispHeight(root.selectedDisplay) + " @ " + root.getDispRefresh(root.selectedDisplay) + "Hz") : ""
                                font.family: NexaUI.NexaTypography.familyBody
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                                color: NexaUI.NexaColors.primary
                            }
                        }

                        // Flow of available modes
                        Flow {
                            width: parent.width
                            spacing: 8

                            Repeater {
                                model: root.selectedDisplay && root.selectedDisplay.available_modes ? root.selectedDisplay.available_modes.slice(0, 10) : []

                                delegate: Rectangle {
                                    id: resChip
                                    readonly property string mStr: modelData
                                    readonly property bool isCurrentMode: {
                                        if (!root.selectedDisplay) return false;
                                        const curFormatted = root.getDispFormattedMode(root.selectedDisplay);
                                        return mStr === curFormatted || mStr.startsWith(root.getDispWidth(root.selectedDisplay) + "x" + root.getDispHeight(root.selectedDisplay));
                                    }

                                    width: resTxt.implicitWidth + 16
                                    height: 30
                                    radius: root.rad(6)
                                    color: isCurrentMode
                                        ? NexaUI.NexaColors.primaryContainer
                                        : (resHover.containsMouse ? NexaUI.NexaColors.surfaceContainerHighest : NexaUI.NexaColors.surfaceContainerHigh)
                                    border.width: NexaUI.NexaTokens.borderThin
                                    border.color: isCurrentMode ? NexaUI.NexaColors.primary : NexaUI.NexaColors.border

                                    Text {
                                        id: resTxt
                                        anchors.centerIn: parent
                                        text: mStr
                                        font.family: NexaUI.NexaTypography.familyBody
                                        font.pixelSize: 11
                                        font.weight: isCurrentMode ? Font.Bold : Font.Normal
                                        color: isCurrentMode ? NexaUI.NexaColors.onPrimaryContainer : NexaUI.NexaColors.text
                                    }

                                    MouseArea {
                                        id: resHover
                                        anchors.fill: parent
                                        enabled: !root.busy
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: if (root.selectedDisplay) root.setResolution(root.selectedDisplay.name, mStr)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ────────────────────────────────────────────────────────────
    // 5. 15-SECOND SAFE "KEEP CHANGES" CONFIRMATION MODAL
    // ────────────────────────────────────────────────────────────
    Rectangle {
        id: confirmationModal
        visible: root.showConfirmationModal
        opacity: root.showConfirmationModal ? 1.0 : 0.0
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 24
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(parent.width - 32, 460)
        height: 72
        radius: root.rad(14)
        color: NexaUI.NexaColors.surfaceContainerHighest || NexaUI.NexaColors.surfaceContainer
        border.width: NexaUI.NexaTokens.borderThin
        border.color: NexaUI.NexaColors.primary
        z: 100

        Behavior on opacity {
            NumberAnimation { duration: 180 }
        }

        // Live countdown progress bar
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 3
            radius: root.rad(2)
            color: Qt.rgba(NexaUI.NexaColors.primary.r, NexaUI.NexaColors.primary.g, NexaUI.NexaColors.primary.b, 0.2)

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: parent.width * (root.revertCountdown / 15.0)
                color: NexaUI.NexaColors.primary

                Behavior on width {
                    NumberAnimation { duration: 950; easing.type: Easing.Linear }
                }
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 12

            Text {
                text: "󰀦"
                font.family: NexaUI.NexaTypography.familyIcon
                font.pixelSize: 22
                color: NexaUI.NexaColors.primary
            }

            Column {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    text: "Keep these display settings?"
                    font.family: NexaUI.NexaTypography.familyBody
                    font.pixelSize: 13
                    font.weight: Font.Bold
                    color: NexaUI.NexaColors.text
                }

                Text {
                    text: "Reverting automatically in " + root.revertCountdown + "s..."
                    font.family: NexaUI.NexaTypography.familyBody
                    font.pixelSize: 11
                    color: NexaUI.NexaColors.mutedText
                }
            }

            // Keep Changes Button
            Rectangle {
                width: keepTxt.implicitWidth + 20
                height: 34
                radius: root.rad(8)
                color: NexaUI.NexaColors.primary
                border.width: NexaUI.NexaTokens.borderThin
                border.color: NexaUI.NexaColors.primary

                Text {
                    id: keepTxt
                    anchors.centerIn: parent
                    text: "Keep (" + root.revertCountdown + "s)"
                    font.family: NexaUI.NexaTypography.familyBody
                    font.pixelSize: 12
                    font.weight: Font.Bold
                    color: NexaUI.NexaColors.onPrimary
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.keepChanges()
                }
            }

            // Revert Now Button
            Rectangle {
                width: revTxt.implicitWidth + 20
                height: 34
                radius: root.rad(8)
                color: NexaUI.NexaColors.surfaceContainerHigh
                border.width: NexaUI.NexaTokens.borderThin
                border.color: NexaUI.NexaColors.border

                Text {
                    id: revTxt
                    anchors.centerIn: parent
                    text: "Revert"
                    font.family: NexaUI.NexaTypography.familyBody
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    color: NexaUI.NexaColors.text
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.revertNow()
                }
            }
        }
    }

    // ────────────────────────────────────────────────────────────
    // TOAST BANNER
    // ────────────────────────────────────────────────────────────
    Rectangle {
        id: toast
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.showConfirmationModal ? 104 : 24
        anchors.horizontalCenter: parent.horizontalCenter
        width: toastRow.implicitWidth + 28
        height: 38
        radius: root.rad(19)
        color: NexaUI.NexaColors.surfaceContainerHighest
        border.width: NexaUI.NexaTokens.borderThin
        border.color: NexaUI.NexaColors.primary
        visible: root.toastVisible
        opacity: root.toastVisible ? 1.0 : 0.0

        Behavior on opacity {
            NumberAnimation { duration: 200 }
        }

        Row {
            id: toastRow
            anchors.centerIn: parent
            spacing: 8

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "󰄬"
                font.family: NexaUI.NexaTypography.familyIcon
                font.pixelSize: 14
                color: NexaUI.NexaColors.primary
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.toastMessage
                font.family: NexaUI.NexaTypography.familyBody
                font.pixelSize: 12
                font.weight: Font.Medium
                color: NexaUI.NexaColors.text
            }
        }
    }
}
