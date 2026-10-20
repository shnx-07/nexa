// pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../theme" as Nexa

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
    property var profiles: []

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

    function showToast(msg) {
        toastMessage = msg;
        toastVisible = true;
        toastTimer.restart();
    }

    Timer {
        id: toastTimer
        interval: 2200
        repeat: false
        onTriggered: root.toastVisible = false
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
                    root.primaryName = d.primary || "";
                    root.projectionModes = d.projection_modes || [];
                    root.displays = d.displays || [];
                    root.profiles = d.profiles || [];

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
    function applyProjection(modeId) {
        if (!modeId || root.busy) return;
        if (modeId === root.currentMode) return;
        root.busy = true;
        showToast("Applying projection: " + modeId);
        Quickshell.execDetached([root.nexadBin, "display", "mode", modeId]);
        refreshTimer.restart();
    }

    function toggleDisplay(name) {
        if (!name || root.busy) return;
        const disp = root.selectedDisplay;
        if (disp && !disp.disabled && root.activeCount <= 1) {
            showToast("Cannot disable the only active screen");
            return;
        }
        root.busy = true;
        showToast("Toggling display: " + name);
        Quickshell.execDetached([root.nexadBin, "display", "toggle", name]);
        refreshTimer.restart();
    }

    function setPrimaryDisplay(name) {
        if (!name || root.busy) return;
        if (root.primaryName === name) return;
        root.busy = true;
        showToast("Setting primary: " + name);
        Quickshell.execDetached([root.nexadBin, "display", "primary", name]);
        refreshTimer.restart();
    }

    function setScale(name, scaleVal) {
        if (!name || root.busy) return;
        if (root.selectedDisplay && Math.abs((root.selectedDisplay.scale || 1.0) - scaleVal) < 0.05) return;
        root.busy = true;
        showToast("Setting scale " + Math.round(scaleVal * 100) + "% on " + name);
        Quickshell.execDetached([root.nexadBin, "display", "scale", name, scaleVal.toString()]);
        refreshTimer.restart();
    }

    function setResolution(name, modeStr) {
        if (!name || !modeStr || root.busy) return;
        root.busy = true;
        showToast("Setting resolution " + modeStr + " on " + name);
        Quickshell.execDetached([root.nexadBin, "display", "res", name, modeStr]);
        refreshTimer.restart();
    }

    function setRotation(name, rot) {
        if (!name || root.busy) return;
        if (root.selectedDisplay && (root.selectedDisplay.transform || 0) === rot) return;
        root.busy = true;
        showToast("Rotating " + name + " to " + (rot * 90) + "°");
        Quickshell.execDetached([root.nexadBin, "display", "rotate", name, rot.toString()]);
        refreshTimer.restart();
    }

    function autoDetect() {
        if (root.busy) return;
        root.busy = true;
        showToast("Auto-detecting and arranging displays...");
        Quickshell.execDetached([root.nexadBin, "display", "auto"]);
        refreshTimer.restart();
    }

    function saveProfile() {
        if (root.busy) return;
        showToast("Saved current display configuration");
        Quickshell.execDetached([root.nexadBin, "display", "save"]);
        refreshTimer.restart();
    }

    function toggleVrr(name, currentVrr) {
        if (!name || root.busy) return;
        root.busy = true;
        const next = currentVrr ? "off" : "on";
        showToast("Setting VRR " + next + " on " + name);
        Quickshell.execDetached([root.nexadBin, "display", "vrr", name, next]);
        refreshTimer.restart();
    }

    // Icon helper
    function getMonitorIcon(disp) {
        if (!disp) return "󰍹";
        if (disp.is_internal) return "󰌢";
        const k = (disp.connector_kind || "").toLowerCase();
        if (k === "hdmi") return "󰡁";
        if (k === "dp" || k === "displayport") return "󰾴";
        if (k === "usb-c" || k === "thunderbolt") return "󰒡";
        return "󰍹";
    }

    // ============================================================
    // MAIN CONTENT SCROLL VIEW
    // ============================================================
    Flickable {
        id: scrollContent
        anchors.fill: parent
        anchors.margins: 16
        contentWidth: width
        contentHeight: contentCol.implicitHeight + 24
        clip: true
        boundsBehavior: Flickable.StopAtBounds

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
                            font.family: Nexa.Theme.iconFontFamily
                            font.pixelSize: 18
                            color: Nexa.Theme.primary
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Monitors & Layout"
                            font.family: Nexa.Theme.fontFamily
                            font.pixelSize: 15
                            font.weight: Font.Bold
                            color: Nexa.Theme.text
                        }

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: countLabel.implicitWidth + 12
                            height: 20
                            radius: 10
                            color: Nexa.Theme.surfaceContainerHighest

                            Text {
                                id: countLabel
                                anchors.centerIn: parent
                                text: root.connectedCount + (root.connectedCount === 1 ? " display connected" : " displays connected")
                                font.family: Nexa.Theme.fontFamily
                                font.pixelSize: 11
                                font.weight: Font.Medium
                                color: Nexa.Theme.mutedText
                            }
                        }

                        // Clamshell badge if lid is closed
                        Rectangle {
                            visible: root.lidClosed
                            anchors.verticalCenter: parent.verticalCenter
                            width: clamText.implicitWidth + 12
                            height: 20
                            radius: 10
                            color: Qt.rgba(1, 0.6, 0.1, 0.2)

                            Text {
                                id: clamText
                                anchors.centerIn: parent
                                text: "Lid Closed (Clamshell)"
                                font.family: Nexa.Theme.fontFamily
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                                color: "#ff9800"
                            }
                        }
                    }

                    Text {
                        text: "Arrange screens, customize resolution, scaling and external projection"
                        font.family: Nexa.Theme.fontFamily
                        font.pixelSize: 12
                        color: Nexa.Theme.mutedText
                    }
                }

                // Action buttons
                Row {
                    spacing: 8
                    Layout.alignment: Qt.AlignVCenter

                    // Auto-Detect Button
                    Rectangle {
                        width: autoRow.implicitWidth + 20
                        height: 32
                        radius: 8
                        color: autoHover.containsMouse ? Nexa.Theme.surfaceContainerHighest : Nexa.Theme.surfaceContainerHigh
                        border.width: 1
                        border.color: Nexa.Theme.border

                        Row {
                            id: autoRow
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "󰑐"
                                font.family: Nexa.Theme.iconFontFamily
                                font.pixelSize: 13
                                color: Nexa.Theme.text
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Auto-Detect"
                                font.family: Nexa.Theme.fontFamily
                                font.pixelSize: 12
                                font.weight: Font.Medium
                                color: Nexa.Theme.text
                            }
                        }

                        MouseArea {
                            id: autoHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.autoDetect()
                        }
                    }

                    // Save Profile Button
                    Rectangle {
                        width: saveRow.implicitWidth + 20
                        height: 32
                        radius: 8
                        color: saveHover.containsMouse ? Qt.lighter(Nexa.Theme.primary, 1.08) : Nexa.Theme.primary

                        Row {
                            id: saveRow
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "󰆓"
                                font.family: Nexa.Theme.iconFontFamily
                                font.pixelSize: 13
                                color: Nexa.Theme.onPrimary
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Save Setup"
                                font.family: Nexa.Theme.fontFamily
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                                color: Nexa.Theme.onPrimary
                            }
                        }

                        MouseArea {
                            id: saveHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.saveProfile()
                        }
                    }
                }
            }

            // ────────────────────────────────────────────────────────────
            // 2. INTERACTIVE MONITOR ARRANGEMENT CANVAS
            // ────────────────────────────────────────────────────────────
            Rectangle {
                width: parent.width
                height: 180
                radius: 12
                color: Nexa.Theme.surfaceContainerLowest || Nexa.Theme.cardBackground
                border.width: 1
                border.color: Nexa.Theme.border

                Item {
                    anchors.fill: parent
                    anchors.margins: 12

                    Text {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        text: "Select a monitor to configure:"
                        font.family: Nexa.Theme.fontFamily
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        color: Nexa.Theme.mutedText
                    }

                    // Centered monitors flow
                    Row {
                        anchors.centerIn: parent
                        spacing: 16

                        Repeater {
                            model: root.displays

                            delegate: Rectangle {
                                id: screenBox
                                readonly property var disp: modelData
                                readonly property bool isSelected: root.selectedDisplayName === disp.name
                                readonly property bool isPrimary: disp.is_primary === true
                                readonly property bool isDisabled: disp.disabled === true

                                width: Math.max(130, Math.min(220, (disp.width || 1920) / 14))
                                height: 100
                                radius: 10
                                color: isSelected
                                    ? Nexa.Theme.surfaceContainerHighest
                                    : (screenHover.containsMouse ? Nexa.Theme.surfaceContainerHigh : Nexa.Theme.surfaceContainer)
                                border.width: isSelected ? 2 : 1
                                border.color: isSelected
                                    ? Nexa.Theme.primary
                                    : (isPrimary ? Qt.rgba(Nexa.Theme.primary.r, Nexa.Theme.primary.g, Nexa.Theme.primary.b, 0.4) : Nexa.Theme.border)

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
                                            font.family: Nexa.Theme.iconFontFamily
                                            font.pixelSize: 18
                                            color: isDisabled ? Nexa.Theme.mutedText : Nexa.Theme.primary
                                        }

                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: disp.name
                                            font.family: Nexa.Theme.fontFamily
                                            font.pixelSize: 13
                                            font.weight: Font.Bold
                                            color: isDisabled ? Nexa.Theme.mutedText : Nexa.Theme.text
                                        }

                                        Text {
                                            visible: isPrimary
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "★"
                                            font.pixelSize: 11
                                            color: Nexa.Theme.primary
                                        }
                                    }

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: (disp.width || 0) + "×" + (disp.height || 0) + " (" + (disp.refresh_rate ? disp.refresh_rate.toFixed(0) : "60") + "Hz)"
                                        font.family: Nexa.Theme.fontFamily
                                        font.pixelSize: 11
                                        color: Nexa.Theme.mutedText
                                    }

                                    Rectangle {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        width: statusTxt.implicitWidth + 8
                                        height: 16
                                        radius: 4
                                        color: isDisabled
                                            ? Qt.rgba(0.5, 0.5, 0.5, 0.15)
                                            : (isPrimary ? Qt.rgba(Nexa.Theme.primary.r, Nexa.Theme.primary.g, Nexa.Theme.primary.b, 0.15) : Nexa.Theme.surfaceContainerHighest)

                                        Text {
                                            id: statusTxt
                                            anchors.centerIn: parent
                                            text: isDisabled ? "Off" : (isPrimary ? "Main Screen" : "Active")
                                            font.family: Nexa.Theme.fontFamily
                                            font.pixelSize: 9
                                            font.weight: Font.SemiBold
                                            color: isDisabled ? Nexa.Theme.mutedText : (isPrimary ? Nexa.Theme.primary : Nexa.Theme.text)
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
            // 3. PROJECTION MODES (External Display Quick Switcher)
            // ────────────────────────────────────────────────────────────
            Column {
                width: parent.width
                spacing: 8

                RowLayout {
                    width: parent.width
                    Text {
                        text: "Projection Mode"
                        font.family: Nexa.Theme.fontFamily
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        color: Nexa.Theme.text
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        visible: root.externalCount === 0
                        text: "Connect an external display to mirror or extend"
                        font.family: Nexa.Theme.fontFamily
                        font.pixelSize: 11
                        color: Nexa.Theme.mutedText
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
                            radius: 8
                            opacity: isAvailable ? 1.0 : 0.45
                            color: isCurrent
                                ? Nexa.Theme.primaryContainer
                                : (projHover.containsMouse && isAvailable ? Nexa.Theme.surfaceContainerHigh : Nexa.Theme.cardBackground)
                            border.width: isCurrent ? 1.5 : 1
                            border.color: isCurrent ? Nexa.Theme.primary : Nexa.Theme.border

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 8

                                Text {
                                    text: item.icon
                                    font.family: Nexa.Theme.iconFontFamily
                                    font.pixelSize: 16
                                    color: isCurrent ? Nexa.Theme.onPrimaryContainer : Nexa.Theme.text
                                }

                                Text {
                                    text: item.label
                                    font.family: Nexa.Theme.fontFamily
                                    font.pixelSize: 12
                                    font.weight: isCurrent ? Font.Bold : Font.Medium
                                    color: isCurrent ? Nexa.Theme.onPrimaryContainer : Nexa.Theme.text
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
            }

            // ────────────────────────────────────────────────────────────
            // 4. SELECTED MONITOR DETAILED CONTROLS
            // ────────────────────────────────────────────────────────────
            Rectangle {
                width: parent.width
                height: monitorSettingsCol.implicitHeight + 32
                radius: 12
                color: Nexa.Theme.cardBackground
                border.width: 1
                border.color: Nexa.Theme.border

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
                            font.family: Nexa.Theme.iconFontFamily
                            font.pixelSize: 22
                            color: Nexa.Theme.primary
                        }

                        Column {
                            Layout.fillWidth: true
                            spacing: 2

                            Row {
                                spacing: 8

                                Text {
                                    text: root.selectedDisplay ? (root.selectedDisplay.description || root.selectedDisplay.name) : "Display"
                                    font.family: Nexa.Theme.fontFamily
                                    font.pixelSize: 14
                                    font.weight: Font.Bold
                                    color: Nexa.Theme.text
                                }

                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: connKindText.implicitWidth + 8
                                    height: 18
                                    radius: 4
                                    color: Nexa.Theme.surfaceContainerHighest

                                    Text {
                                        id: connKindText
                                        anchors.centerIn: parent
                                        text: root.selectedDisplay ? (root.selectedDisplay.connector_kind ? root.selectedDisplay.connector_kind.toUpperCase() : "DISPLAY") : ""
                                        font.family: Nexa.Theme.fontFamily
                                        font.pixelSize: 10
                                        font.weight: Font.SemiBold
                                        color: Nexa.Theme.mutedText
                                    }
                                }
                            }

                            Text {
                                text: root.selectedDisplay ? ("Connector: " + root.selectedDisplay.name + (root.selectedDisplay.is_internal ? " (Built-in Display)" : " (External Display)")) : ""
                                font.family: Nexa.Theme.fontFamily
                                font.pixelSize: 11
                                color: Nexa.Theme.mutedText
                            }
                        }

                        // On/Off Switch Button
                        Rectangle {
                            readonly property bool isOn: root.selectedDisplay ? !root.selectedDisplay.disabled : false
                            readonly property bool canToggle: !isOn || (root.activeCount > 1)
                            width: 100
                            height: 32
                            radius: 8
                            opacity: canToggle ? 1.0 : 0.6
                            color: isOn ? Qt.rgba(Nexa.Theme.primary.r, Nexa.Theme.primary.g, Nexa.Theme.primary.b, 0.15) : Nexa.Theme.surfaceContainerHighest
                            border.width: 1
                            border.color: isOn ? Nexa.Theme.primary : Nexa.Theme.border

                            Row {
                                anchors.centerIn: parent
                                spacing: 6

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: isOn ? "󰐥 Enabled" : "󰐥 Disabled"
                                    font.family: Nexa.Theme.fontFamily
                                    font.pixelSize: 12
                                    font.weight: Font.Medium
                                    color: isOn ? Nexa.Theme.primary : Nexa.Theme.mutedText
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: parent.canToggle ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                                onClicked: if (root.selectedDisplay) root.toggleDisplay(root.selectedDisplay.name)
                            }
                        }
                    }

                    Rectangle { width: parent.width; height: 1; color: Nexa.Theme.border }

                    // Make Primary Button
                    RowLayout {
                        width: parent.width
                        spacing: 12

                        Column {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                text: "Make this my primary display"
                                font.family: Nexa.Theme.fontFamily
                                font.pixelSize: 13
                                font.weight: Font.Medium
                                color: Nexa.Theme.text
                            }

                            Text {
                                text: "Primary display holds default workspace and system panels"
                                font.family: Nexa.Theme.fontFamily
                                font.pixelSize: 11
                                color: Nexa.Theme.mutedText
                            }
                        }

                        Rectangle {
                            readonly property bool isPrimary: root.selectedDisplay ? (root.selectedDisplay.is_primary === true) : false
                            width: primaryBtnTxt.implicitWidth + 24
                            height: 32
                            radius: 8
                            color: isPrimary ? Nexa.Theme.primaryContainer : (primaryHover.containsMouse ? Nexa.Theme.surfaceContainerHighest : Nexa.Theme.surfaceContainerHigh)
                            border.width: 1
                            border.color: isPrimary ? Nexa.Theme.primary : Nexa.Theme.border

                            Text {
                                id: primaryBtnTxt
                                anchors.centerIn: parent
                                text: isPrimary ? "✓ Primary Screen" : "Set as Primary"
                                font.family: Nexa.Theme.fontFamily
                                font.pixelSize: 12
                                font.weight: isPrimary ? Font.Bold : Font.Medium
                                color: isPrimary ? Nexa.Theme.onPrimaryContainer : Nexa.Theme.text
                            }

                            MouseArea {
                                id: primaryHover
                                anchors.fill: parent
                                enabled: !parent.isPrimary && !root.busy
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: if (root.selectedDisplay) root.setPrimaryDisplay(root.selectedDisplay.name)
                            }
                        }
                    }

                    Rectangle { width: parent.width; height: 1; color: Nexa.Theme.border }

                    // Display Scaling
                    Column {
                        width: parent.width
                        spacing: 8

                        Text {
                            text: "Display Scale"
                            font.family: Nexa.Theme.fontFamily
                            font.pixelSize: 13
                            font.weight: Font.Medium
                            color: Nexa.Theme.text
                        }

                        Row {
                            spacing: 8

                            Repeater {
                                model: [1.0, 1.25, 1.5, 1.75, 2.0]

                                delegate: Rectangle {
                                    id: scaleChip
                                    readonly property real sVal: modelData
                                    readonly property bool isCurrentScale: root.selectedDisplay && Math.abs((root.selectedDisplay.scale || 1.0) - sVal) < 0.05

                                    width: 80
                                    height: 32
                                    radius: 6
                                    color: isCurrentScale
                                        ? Nexa.Theme.primary
                                        : (sHover.containsMouse ? Nexa.Theme.surfaceContainerHighest : Nexa.Theme.surfaceContainerHigh)
                                    border.width: 1
                                    border.color: isCurrentScale ? Nexa.Theme.primary : Nexa.Theme.border

                                    Text {
                                        anchors.centerIn: parent
                                        text: Math.round(sVal * 100) + "%"
                                        font.family: Nexa.Theme.fontFamily
                                        font.pixelSize: 12
                                        font.weight: isCurrentScale ? Font.Bold : Font.Normal
                                        color: isCurrentScale ? Nexa.Theme.onPrimary : Nexa.Theme.text
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

                    Rectangle { width: parent.width; height: 1; color: Nexa.Theme.border }

                    // Display Orientation / Rotation
                    Column {
                        width: parent.width
                        spacing: 8

                        Text {
                            text: "Orientation"
                            font.family: Nexa.Theme.fontFamily
                            font.pixelSize: 13
                            font.weight: Font.Medium
                            color: Nexa.Theme.text
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
                                    radius: 6
                                    color: isCurrentRot
                                        ? Nexa.Theme.primary
                                        : (rHover.containsMouse ? Nexa.Theme.surfaceContainerHighest : Nexa.Theme.surfaceContainerHigh)
                                    border.width: 1
                                    border.color: isCurrentRot ? Nexa.Theme.primary : Nexa.Theme.border

                                    Row {
                                        id: rotRow
                                        anchors.centerIn: parent
                                        spacing: 6

                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: item.icon
                                            font.family: Nexa.Theme.iconFontFamily
                                            font.pixelSize: 13
                                            color: isCurrentRot ? Nexa.Theme.onPrimary : Nexa.Theme.text
                                        }

                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: item.label
                                            font.family: Nexa.Theme.fontFamily
                                            font.pixelSize: 12
                                            font.weight: isCurrentRot ? Font.Bold : Font.Normal
                                            color: isCurrentRot ? Nexa.Theme.onPrimary : Nexa.Theme.text
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

                    Rectangle { width: parent.width; height: 1; color: Nexa.Theme.border }

                    // Available Resolutions & Refresh Rates
                    Column {
                        width: parent.width
                        spacing: 8

                        RowLayout {
                            width: parent.width
                            Text {
                                text: "Resolution & Refresh Rate"
                                font.family: Nexa.Theme.fontFamily
                                font.pixelSize: 13
                                font.weight: Font.Medium
                                color: Nexa.Theme.text
                            }

                            Item { Layout.fillWidth: true }

                            Text {
                                text: root.selectedDisplay ? (root.selectedDisplay.width + "×" + root.selectedDisplay.height + " @ " + (root.selectedDisplay.refresh_rate ? root.selectedDisplay.refresh_rate.toFixed(1) : "60") + "Hz") : ""
                                font.family: Nexa.Theme.fontFamily
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                                color: Nexa.Theme.primary
                            }
                        }

                        // Flow of common modes
                        Flow {
                            width: parent.width
                            spacing: 8

                            Repeater {
                                model: root.selectedDisplay && root.selectedDisplay.available_modes ? root.selectedDisplay.available_modes.slice(0, 8) : []

                                delegate: Rectangle {
                                    id: resChip
                                    readonly property string mStr: modelData
                                    readonly property bool isCurrentMode: {
                                        if (!root.selectedDisplay) return false;
                                        const cur = root.selectedDisplay.width + "x" + root.selectedDisplay.height;
                                        return mStr.startsWith(cur);
                                    }

                                    width: resTxt.implicitWidth + 16
                                    height: 30
                                    radius: 6
                                    color: isCurrentMode
                                        ? Nexa.Theme.primaryContainer
                                        : (resHover.containsMouse ? Nexa.Theme.surfaceContainerHighest : Nexa.Theme.surfaceContainerHigh)
                                    border.width: 1
                                    border.color: isCurrentMode ? Nexa.Theme.primary : Nexa.Theme.border

                                    Text {
                                        id: resTxt
                                        anchors.centerIn: parent
                                        text: mStr
                                        font.family: Nexa.Theme.fontFamily
                                        font.pixelSize: 11
                                        font.weight: isCurrentMode ? Font.Bold : Font.Normal
                                        color: isCurrentMode ? Nexa.Theme.onPrimaryContainer : Nexa.Theme.text
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

                    Rectangle { width: parent.width; height: 1; color: Nexa.Theme.border }

                    // Variable Refresh Rate (VRR / Adaptive Sync)
                    RowLayout {
                        width: parent.width
                        spacing: 12

                        Column {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                text: "Variable Refresh Rate (VRR / Adaptive-Sync)"
                                font.family: Nexa.Theme.fontFamily
                                font.pixelSize: 13
                                font.weight: Font.Medium
                                color: Nexa.Theme.text
                            }

                            Text {
                                text: "Reduces stuttering and screen tearing in games and high framerate content"
                                font.family: Nexa.Theme.fontFamily
                                font.pixelSize: 11
                                color: Nexa.Theme.mutedText
                            }
                        }

                        Rectangle {
                            readonly property bool vrrActive: root.selectedDisplay ? (root.selectedDisplay.vrr === true) : false
                            width: 72
                            height: 30
                            radius: 15
                            color: vrrActive ? Nexa.Theme.primary : Nexa.Theme.surfaceContainerHighest
                            border.width: 1
                            border.color: vrrActive ? Nexa.Theme.primary : Nexa.Theme.border

                            Rectangle {
                                width: 22
                                height: 22
                                radius: 11
                                anchors.verticalCenter: parent.verticalCenter
                                x: parent.vrrActive ? (parent.width - width - 4) : 4
                                color: parent.vrrActive ? Nexa.Theme.onPrimary : Nexa.Theme.outline

                                Behavior on x {
                                    NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                enabled: !root.busy
                                cursorShape: Qt.PointingHandCursor
                                onClicked: if (root.selectedDisplay) root.toggleVrr(root.selectedDisplay.name, root.selectedDisplay.vrr)
                            }
                        }
                    }
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
        anchors.bottomMargin: 24
        anchors.horizontalCenter: parent.horizontalCenter
        width: toastRow.implicitWidth + 28
        height: 38
        radius: 19
        color: Nexa.Theme.surfaceContainerHighest
        border.width: 1
        border.color: Nexa.Theme.primary
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
                font.family: Nexa.Theme.iconFontFamily
                font.pixelSize: 14
                color: Nexa.Theme.primary
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.toastMessage
                font.family: Nexa.Theme.fontFamily
                font.pixelSize: 12
                font.weight: Font.Medium
                color: Nexa.Theme.text
            }
        }
    }
}
