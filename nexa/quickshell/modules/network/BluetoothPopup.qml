import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth

import "../../theme" as Nexa
import "../../theme/components" as NexaUI

PopupWindow {
    id: root

    property Item anchorItem

    // ============================================================
    // STATE
    // ============================================================

    property var deviceCatalog: []
    property string pendingAction: ""
    property string pendingAddress: ""
    property string actionError: ""
    property int postActionPolls: 0

    readonly property string nexad:
        Quickshell.env("HOME") + "/.config/nexa/rust/target/release/nexad"

    readonly property var adapter:
        Bluetooth.defaultAdapter

    readonly property bool enabled:
        root.adapter !== null && root.adapter.enabled

    property bool optimisticEnabled: root.enabled

    onEnabledChanged: {
        root.optimisticEnabled = root.enabled
    }

    readonly property bool scanning:
        root.adapter !== null && root.adapter.discovering

    // Device Groups from BlueZ / nexad
    readonly property var connectedDevices:
        root.deviceCatalog.filter(device => device.connected)

    readonly property var pairedDevices:
        root.deviceCatalog.filter(device => device.paired && !device.connected)

    readonly property var availableDevices:
        root.deviceCatalog.filter(device => !device.paired && !device.connected)

    // ============================================================
    // WINDOW GEOMETRY & ANCHORING
    // ============================================================

    implicitWidth: 380
    implicitHeight: Math.min(540, Math.max(340, mainLayout.implicitHeight + Nexa.Theme.spacingMd * 2))

    color: "transparent"
    grabFocus: true

    anchor {
        item: root.anchorItem

        rect.x:
            root.anchorItem
            ? root.anchorItem.width
            : 0

        rect.y:
            root.anchorItem
            ? root.anchorItem.height + Nexa.Theme.spacingSm
            : 0

        rect.width: 1
        rect.height: 1

        edges:
            Edges.Top | Edges.Left

        gravity:
            Edges.Bottom | Edges.Left
    }

    // ============================================================
    // HELPERS
    // ============================================================

    function deviceGlyph(type) {
        const val = (type || "").toLowerCase()
        if (val.includes("headset") || val.includes("headphone") || val.includes("audio")) return "󰋋"
        if (val.includes("mouse")) return "󰍽"
        if (val.includes("keyboard")) return "󰌌"
        if (val.includes("phone") || val.includes("smartphone")) return "󰄜"
        if (val.includes("computer")) return "󰍹"
        return "󰂯"
    }

    function deviceName(device) {
        if (!device) return "Unknown device"
        if (device.name && device.name.trim() !== "") return device.name
        return device.address || "Unknown device"
    }

    function isPending(device) {
        return device && root.pendingAddress === device.address && root.pendingAction !== ""
    }

    // ============================================================
    // PROCESSES
    // ============================================================

    Process {
        id: infoProcess
        stdout: StdioCollector {
            id: infoOutput
            waitForEnd: true
            onStreamFinished: {
                const raw = infoOutput.text.trim()
                if (raw === "") return
                try {
                    const parsed = JSON.parse(raw)
                    if (parsed && Array.isArray(parsed.devices)) {
                        root.deviceCatalog = parsed.devices
                    }
                } catch (err) {
                    console.warn("NEXA Bluetooth JSON error:", err)
                }
            }
        }
    }

    function refreshInfo() {
        if (infoProcess.running) return
        infoProcess.exec([root.nexad, "network", "bluetooth", "info"])
    }

    Process {
        id: actionProcess
        onStarted: {
            root.actionError = ""
        }
        onExited: function(exitCode, exitStatus) {
            if (exitCode !== 0) {
                root.actionError = "Bluetooth action failed"
                root.optimisticEnabled = root.enabled
            } else {
                root.actionError = ""
            }
            root.postActionPolls = 5
            postActionTimer.restart()
        }
    }

    function runBluetooth(args, action, address) {
        if (actionProcess.running) return
        root.pendingAction = action || ""
        root.pendingAddress = address || ""
        root.actionError = ""
        actionProcess.exec([root.nexad, "network", "bluetooth"].concat(args))
    }

    // ============================================================
    // ACTIONS
    // ============================================================

    function toggleBluetooth() {
        if (actionProcess.running) return
        const nextState = !root.optimisticEnabled
        root.optimisticEnabled = nextState
        if (root.adapter && root.adapter.enabled && root.adapter.discovering) {
            root.adapter.discovering = false
        }
        runBluetooth([nextState ? "on" : "off"], "toggle")
    }

    function toggleDiscovery() {
        if (!root.adapter || !root.adapter.enabled) return
        root.adapter.discovering = !root.adapter.discovering
        if (root.adapter.discovering) {
            root.refreshInfo()
        }
    }

    function pairDevice(device) {
        if (!device) return
        runBluetooth(["pair", device.address], "pair", device.address)
    }

    function connectDevice(device) {
        if (!device) return
        runBluetooth(["connect", device.address], "connect", device.address)
    }

    function disconnectDevice(device) {
        if (!device) return
        runBluetooth(["disconnect", device.address], "disconnect", device.address)
    }

    function forgetDevice(device) {
        if (!device) return
        runBluetooth(["forget", device.address], "forget", device.address)
    }

    // ============================================================
    // TIMERS & LIFECYCLE
    // ============================================================

    Timer {
        id: pollTimer
        interval: 3000
        repeat: true
        running: root.visible && root.enabled
        onTriggered: root.refreshInfo()
    }

    Timer {
        id: postActionTimer
        interval: 600
        repeat: true
        running: root.visible && root.postActionPolls > 0
        onTriggered: {
            root.refreshInfo()
            root.postActionPolls--
            if (root.postActionPolls <= 0) {
                root.pendingAction = ""
                root.pendingAddress = ""
                root.optimisticEnabled = root.enabled
            }
        }
    }

    Timer {
        id: discoveryPollTimer
        interval: 2000
        repeat: true
        running: root.visible && root.scanning
        onTriggered: root.refreshInfo()
    }

    onVisibleChanged: {
        if (visible) {
            root.actionError = ""
            root.optimisticEnabled = root.enabled
            root.refreshInfo()
            if (root.enabled && !root.scanning) {
                root.toggleDiscovery()
            }
        } else {
            root.pendingAction = ""
            root.pendingAddress = ""
            root.postActionPolls = 0
            if (root.scanning) {
                root.toggleDiscovery()
            }
        }
    }

    // ============================================================
    // MAIN POPUP CONTAINER
    // ============================================================

    Rectangle {
        id: mainSurface
        anchors.fill: parent
        radius: Nexa.Theme.radiusLg
        color: Nexa.Theme.panelBackground
        border.width: Nexa.Theme.borderThin
        border.color: Nexa.Theme.border

        // Static continuous-corner glass gradient highlight
        Rectangle {
            anchors.fill: parent
            anchors.margins: mainSurface.border.width
            radius: Math.max(0, mainSurface.radius - mainSurface.border.width)
            gradient: Gradient {
                GradientStop { position: 0.0; color: Nexa.Theme.edgeHighlightStrong }
                GradientStop { position: 0.45; color: "transparent" }
            }
        }

        ColumnLayout {
            id: mainLayout
            anchors.fill: parent
            anchors.margins: Nexa.Theme.spacingMd
            spacing: Nexa.Theme.spacingMd

            // ====================================================
            // TOP HEADER ROW
            // ====================================================
            RowLayout {
                Layout.fillWidth: true
                spacing: Nexa.Theme.spacingSm

                // Status Icon
                Text {
                    text: root.connectedDevices.length > 0 ? "󰂱" : root.optimisticEnabled ? "󰂯" : "󰂲"
                    color: root.connectedDevices.length > 0 ? Nexa.Theme.primary : root.optimisticEnabled ? Nexa.Theme.text : Nexa.Theme.mutedText
                    font.family: Nexa.Theme.iconFontFamily
                    font.pixelSize: Nexa.Theme.iconLg
                    Layout.alignment: Qt.AlignVCenter
                }

                // Title & Subtitle
                ColumnLayout {
                    spacing: 1
                    Layout.alignment: Qt.AlignVCenter

                    RowLayout {
                        spacing: Nexa.Theme.spacingXs
                        Layout.alignment: Qt.AlignVCenter

                        Text {
                            text: "Bluetooth"
                            color: Nexa.Theme.text
                            font.family: Nexa.Theme.fontFamily
                            font.pixelSize: Nexa.Theme.fontSizeMd
                            font.weight: Nexa.Theme.fontWeightDemiBold
                            Layout.alignment: Qt.AlignVCenter
                        }

                        // Badge count
                        Rectangle {
                            visible: root.optimisticEnabled && root.deviceCatalog.length > 0
                            implicitWidth: badgeText.implicitWidth + 10
                            implicitHeight: 18
                            radius: 9
                            color: Nexa.Theme.surfaceContainerHighest
                            Layout.alignment: Qt.AlignVCenter

                            Text {
                                id: badgeText
                                anchors.centerIn: parent
                                text: root.connectedDevices.length > 0
                                      ? root.connectedDevices.length + " connected"
                                      : root.deviceCatalog.length.toString()
                                color: root.connectedDevices.length > 0 ? Nexa.Theme.primary : Nexa.Theme.mutedText
                                font.family: Nexa.Theme.fontFamily
                                font.pixelSize: Nexa.Theme.fontSize2Xs
                                font.weight: Nexa.Theme.fontWeightMedium
                            }
                        }
                    }

                    Text {
                        text: !root.optimisticEnabled ? "Disabled"
                            : root.connectedDevices.length > 0 ? root.connectedDevices.length + (root.connectedDevices.length === 1 ? " device active" : " devices active")
                            : root.scanning ? "Searching for devices…"
                            : "Ready to connect"
                        color: Nexa.Theme.mutedText
                        font.family: Nexa.Theme.fontFamily
                        font.pixelSize: Nexa.Theme.fontSize2Xs
                    }
                }

                Item { Layout.fillWidth: true }

                // Scan / Rescan Button (Hover background stays stable, only icon rotates)
                Item {
                    id: scanButton
                    implicitWidth: 32
                    implicitHeight: 32
                    visible: root.optimisticEnabled
                    Layout.alignment: Qt.AlignVCenter

                    Rectangle {
                        id: scanHoverBg
                        anchors.fill: parent
                        radius: Nexa.Theme.radiusPill
                        color: scanArea.containsMouse ? Nexa.Theme.hover : "transparent"
                        border.color: scanArea.containsMouse ? Nexa.Theme.borderSubtle : "transparent"
                        border.width: 1

                        Behavior on color { ColorAnimation { duration: 150 } }
                    }

                    Text {
                        id: scanIcon
                        anchors.centerIn: parent
                        text: "󰑐"
                        font.family: Nexa.Theme.iconFontFamily
                        font.pixelSize: 16
                        color: root.scanning ? Nexa.Theme.primary : Nexa.Theme.onSurface

                        RotationAnimator on rotation {
                            from: 0
                            to: 360
                            duration: 1000
                            loops: Animation.Infinite
                            running: root.scanning && root.visible
                        }
                    }

                    MouseArea {
                        id: scanArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggleDiscovery()
                    }
                }

                // Master Bluetooth Toggle
                NexaUI.NexaToggle {
                    id: headerToggle
                    checked: root.optimisticEnabled
                    interactive: !actionProcess.running
                    Layout.alignment: Qt.AlignVCenter
                    onToggled: function(val) {
                        if (val !== root.optimisticEnabled) {
                            root.toggleBluetooth()
                        }
                    }
                    Connections {
                        target: root
                        function onOptimisticEnabledChanged() {
                            headerToggle.checked = root.optimisticEnabled
                        }
                    }
                }
            }

            // Backend Action Error
            Text {
                visible: root.actionError !== ""
                Layout.fillWidth: true
                text: root.actionError
                color: Nexa.Theme.error
                font.family: Nexa.Theme.fontFamily
                font.pixelSize: Nexa.Theme.fontSize2Xs
                font.weight: Nexa.Theme.fontWeightMedium
            }

            // ====================================================
            // CONNECTED HERO SECTION (Unified Cards)
            // ====================================================
            Repeater {
                model: root.optimisticEnabled ? root.connectedDevices : []

                delegate: NexaUI.NexaCard {
                    id: connectedCard
                    required property var modelData
                    Layout.fillWidth: true
                    padding: Nexa.Theme.spacingSm
                    implicitHeight: Math.max(52, connectedRow.implicitHeight + padding * 2)
                    selected: true

                    RowLayout {
                        id: connectedRow
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: connectedCard.padding
                        anchors.rightMargin: connectedCard.padding
                        spacing: Nexa.Theme.spacingSm

                        // Capsule Device Glyph
                        Rectangle {
                            implicitWidth: 32
                            implicitHeight: 32
                            radius: Nexa.Theme.radiusPill
                            color: Nexa.Theme.primaryContainer
                            Layout.alignment: Qt.AlignVCenter

                            Text {
                                anchors.centerIn: parent
                                text: root.deviceGlyph(connectedCard.modelData.device_type)
                                color: Nexa.Theme.primary
                                font.family: Nexa.Theme.iconFontFamily
                                font.pixelSize: 16
                            }
                        }

                        // Name & Status Details
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 2

                            Text {
                                text: root.deviceName(connectedCard.modelData)
                                color: Nexa.Theme.text
                                font.family: Nexa.Theme.fontFamily
                                font.pixelSize: Nexa.Theme.fontSizeSm
                                font.weight: Nexa.Theme.fontWeightDemiBold
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            RowLayout {
                                spacing: Nexa.Theme.spacingXs
                                Layout.alignment: Qt.AlignVCenter

                                NexaUI.NexaActiveIndicator {
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                Text {
                                    text: {
                                        let str = "Connected"
                                        if (connectedCard.modelData.battery !== undefined && connectedCard.modelData.battery !== null) {
                                            str += " · " + connectedCard.modelData.battery + "%"
                                        }
                                        return str
                                    }
                                    color: Nexa.Theme.mutedText
                                    font.family: Nexa.Theme.fontFamily
                                    font.pixelSize: Nexa.Theme.fontSizeXs
                                    Layout.alignment: Qt.AlignVCenter
                                }
                            }
                        }

                        // Forget Button
                        NexaUI.NexaIconButton {
                            icon: "󰆴"
                            iconSize: Nexa.Theme.iconSm
                            implicitWidth: Nexa.Theme.controlHeightSm
                            implicitHeight: Nexa.Theme.controlHeightSm
                            iconColor: hovered ? Nexa.Theme.error : Nexa.Theme.mutedText
                            Layout.alignment: Qt.AlignVCenter
                            enabled: !actionProcess.running
                            onClicked: root.forgetDevice(connectedCard.modelData)
                        }

                        // Disconnect Button
                        NexaUI.NexaButton {
                            text: root.isPending(connectedCard.modelData) ? "Disconnecting…" : "Disconnect"
                            textSize: Nexa.Theme.fontSizeXs
                            implicitHeight: Nexa.Theme.controlHeightSm
                            horizontalPadding: Nexa.Theme.spacingSm
                            Layout.alignment: Qt.AlignVCenter
                            interactive: !actionProcess.running
                            onClicked: root.disconnectDevice(connectedCard.modelData)
                        }
                    }
                }
            }

            // ====================================================
            // DEVICE LIST VIEWPORT
            // ====================================================
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                implicitHeight: Math.min(320, Math.max(220, listInnerColumn.implicitHeight + Nexa.Theme.spacingSm * 2))
                radius: Nexa.Theme.radiusMd
                color: Nexa.Theme.surfaceContainer
                border.width: Nexa.Theme.borderThin
                border.color: Nexa.Theme.border

                ColumnLayout {
                    id: listInnerColumn
                    anchors.fill: parent
                    anchors.margins: Nexa.Theme.spacingSm
                    spacing: Nexa.Theme.spacingSm

                    // ============================================
                    // EMPTY / DISABLED STATES
                    // ============================================

                    // State 1: Bluetooth Disabled
                    ColumnLayout {
                        visible: !root.optimisticEnabled
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.alignment: Qt.AlignCenter
                        spacing: Nexa.Theme.spacingMd

                        Item { Layout.fillHeight: true }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "󰂲"
                            color: Nexa.Theme.mutedText
                            font.family: Nexa.Theme.iconFontFamily
                            font.pixelSize: 48
                        }

                        ColumnLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 4

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "Bluetooth is turned off"
                                color: Nexa.Theme.text
                                font.family: Nexa.Theme.fontFamily
                                font.pixelSize: Nexa.Theme.fontSizeSm
                                font.weight: Nexa.Theme.fontWeightDemiBold
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "Turn on Bluetooth to find and connect to devices"
                                color: Nexa.Theme.mutedText
                                font.family: Nexa.Theme.fontFamily
                                font.pixelSize: Nexa.Theme.fontSizeXs
                            }
                        }

                        NexaUI.NexaButton {
                            Layout.alignment: Qt.AlignHCenter
                            text: "Turn On Bluetooth"
                            icon: "󰂯"
                            selected: true
                            interactive: !actionProcess.running
                            onClicked: root.toggleBluetooth()
                        }

                        Item { Layout.fillHeight: true }
                    }

                    // State 2: Bluetooth Enabled, Scanning or 0 Devices Found
                    ColumnLayout {
                        visible: root.optimisticEnabled && (root.deviceCatalog.length === 0 && root.connectedDevices.length === 0)
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.alignment: Qt.AlignCenter
                        spacing: Nexa.Theme.spacingSm

                        Item { Layout.fillHeight: true }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: root.scanning ? "󰑐" : "󰂲"
                            color: root.scanning ? Nexa.Theme.primary : Nexa.Theme.mutedText
                            font.family: Nexa.Theme.iconFontFamily
                            font.pixelSize: 32

                            RotationAnimator on rotation {
                                running: root.scanning && root.visible
                                from: 0
                                to: 360
                                duration: 1200
                                loops: Animation.Infinite
                            }
                        }

                        ColumnLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 4

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: root.scanning ? "Searching for nearby devices…" : "No Bluetooth devices found"
                                color: Nexa.Theme.text
                                font.family: Nexa.Theme.fontFamily
                                font.pixelSize: Nexa.Theme.fontSizeSm
                                font.weight: Nexa.Theme.fontWeightDemiBold
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "Make sure devices are in pairing mode"
                                color: Nexa.Theme.mutedText
                                font.family: Nexa.Theme.fontFamily
                                font.pixelSize: Nexa.Theme.fontSizeXs
                            }
                        }

                        NexaUI.NexaButton {
                            Layout.alignment: Qt.AlignHCenter
                            text: "Scan for Devices"
                            icon: "󰑐"
                            selected: true
                            interactive: !actionProcess.running
                            onClicked: root.toggleDiscovery()
                        }

                        Item { Layout.fillHeight: true }
                    }

                    // Scrollable List of Devices
                    Flickable {
                        id: deviceFlick
                        visible: root.optimisticEnabled && (root.pairedDevices.length > 0 || root.availableDevices.length > 0)
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        implicitHeight: Math.min(260, Math.max(120, deviceColumn.implicitHeight))
                        clip: true
                        contentHeight: deviceColumn.implicitHeight
                        contentWidth: width
                        boundsBehavior: Flickable.StopAtBounds
                        flickDeceleration: Nexa.Theme.flickDeceleration
                        maximumFlickVelocity: Nexa.Theme.flickVelocityMax
                        pixelAligned: true

                        // Sleek discreet floating scrollbar
                        ScrollBar.vertical: ScrollBar {
                            id: btScrollBar
                            policy: ScrollBar.AsNeeded
                            width: 4
                            anchors.right: parent.right
                            anchors.rightMargin: 1
                            visible: size < 1.0

                            contentItem: Rectangle {
                                implicitWidth: 3
                                radius: Nexa.Theme.radiusPill
                                color: btScrollBar.hovered ? Nexa.Theme.primary : Nexa.Theme.mutedText
                                opacity: (btScrollBar.active || btScrollBar.hovered) ? 0.6 : 0.0

                                Behavior on opacity { NumberAnimation { duration: Nexa.Theme.animationNormal } }
                                Behavior on color { ColorAnimation { duration: Nexa.Theme.animationFast } }
                            }
                            background: null
                        }

                        Column {
                            id: deviceColumn
                            width: deviceFlick.width - (deviceFlick.contentHeight > deviceFlick.height ? (Nexa.Theme.spacingSm + 4) : 0)
                            spacing: Nexa.Theme.spacingSm

                            Behavior on width {
                                NumberAnimation { duration: Nexa.Theme.animationFast }
                            }

                            // ----------------------------------------
                            // PAIRED DEVICES SECTION
                            // ----------------------------------------
                            Column {
                                width: parent.width
                                spacing: Nexa.Theme.spacingXs
                                visible: root.pairedDevices.length > 0

                                RowLayout {
                                    width: parent.width
                                    Text {
                                        text: "Paired Devices"
                                        color: Nexa.Theme.mutedText
                                        font.family: Nexa.Theme.fontFamily
                                        font.pixelSize: Nexa.Theme.fontSize2Xs
                                        font.weight: Nexa.Theme.fontWeightDemiBold
                                    }
                                    Item { Layout.fillWidth: true }
                                    Text {
                                        text: root.pairedDevices.length.toString()
                                        color: Nexa.Theme.mutedText
                                        font.family: Nexa.Theme.fontFamily
                                        font.pixelSize: Nexa.Theme.fontSize2Xs
                                    }
                                }

                                Repeater {
                                    model: root.pairedDevices

                                    delegate: Rectangle {
                                        id: pairedItem
                                        required property var modelData
                                        width: deviceColumn.width
                                        height: 48
                                        radius: Nexa.Theme.radiusSm
                                        color: pairedMouse.pressed ? Nexa.Theme.pressed
                                             : pairedMouse.containsMouse ? Nexa.Theme.hover
                                             : Nexa.Theme.surfaceContainerHigh
                                        border.width: Nexa.Theme.borderThin
                                        border.color: pairedMouse.containsMouse ? Nexa.Theme.borderStrong : Nexa.Theme.border
                                        scale: pairedMouse.pressed ? 0.985 : 1.0

                                        Behavior on color { ColorAnimation { duration: 120 } }
                                        Behavior on border.color { ColorAnimation { duration: 120 } }
                                        Behavior on scale { NumberAnimation { duration: 120 } }

                                        MouseArea {
                                            id: pairedMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            enabled: !actionProcess.running
                                            onClicked: root.connectDevice(pairedItem.modelData)
                                        }

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: Nexa.Theme.spacingSm
                                            anchors.rightMargin: Nexa.Theme.spacingSm
                                            spacing: Nexa.Theme.spacingSm

                                            Text {
                                                text: root.deviceGlyph(pairedItem.modelData.device_type)
                                                color: Nexa.Theme.text
                                                font.family: Nexa.Theme.iconFontFamily
                                                font.pixelSize: Nexa.Theme.iconMd
                                                Layout.alignment: Qt.AlignVCenter
                                            }

                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                Layout.alignment: Qt.AlignVCenter
                                                spacing: 1

                                                Text {
                                                    text: root.deviceName(pairedItem.modelData)
                                                    color: Nexa.Theme.text
                                                    font.family: Nexa.Theme.fontFamily
                                                    font.pixelSize: Nexa.Theme.fontSizeXs
                                                    font.weight: Nexa.Theme.fontWeightMedium
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true
                                                }

                                                Text {
                                                    text: root.isPending(pairedItem.modelData) ? "Connecting…" : "Paired"
                                                    color: root.isPending(pairedItem.modelData) ? Nexa.Theme.primary : Nexa.Theme.mutedText
                                                    font.family: Nexa.Theme.fontFamily
                                                    font.pixelSize: Nexa.Theme.fontSize2Xs
                                                }
                                            }

                                            // Action Spinner
                                            Text {
                                                visible: root.isPending(pairedItem.modelData)
                                                text: "󰑐"
                                                color: Nexa.Theme.primary
                                                font.family: Nexa.Theme.iconFontFamily
                                                font.pixelSize: Nexa.Theme.iconSm
                                                Layout.alignment: Qt.AlignVCenter

                                                RotationAnimator on rotation {
                                                    from: 0; to: 360; duration: 900
                                                    loops: Animation.Infinite
                                                    running: root.isPending(pairedItem.modelData) && root.visible
                                                }
                                            }

                                            // Forget Button
                                            NexaUI.NexaIconButton {
                                                icon: "󰆴"
                                                iconSize: Nexa.Theme.iconSm
                                                implicitWidth: Nexa.Theme.controlHeightSm
                                                implicitHeight: Nexa.Theme.controlHeightSm
                                                iconColor: hovered ? Nexa.Theme.error : Nexa.Theme.mutedText
                                                Layout.alignment: Qt.AlignVCenter
                                                enabled: !actionProcess.running
                                                onClicked: root.forgetDevice(pairedItem.modelData)
                                            }

                                            // Connect Button
                                            NexaUI.NexaButton {
                                                text: "Connect"
                                                textSize: Nexa.Theme.fontSizeXs
                                                implicitHeight: Nexa.Theme.controlHeightSm
                                                horizontalPadding: Nexa.Theme.spacingSm
                                                Layout.alignment: Qt.AlignVCenter
                                                interactive: !actionProcess.running
                                                onClicked: root.connectDevice(pairedItem.modelData)
                                            }
                                        }
                                    }
                                }
                            }

                            // ----------------------------------------
                            // AVAILABLE DEVICES SECTION
                            // ----------------------------------------
                            Column {
                                width: parent.width
                                spacing: Nexa.Theme.spacingXs
                                visible: root.availableDevices.length > 0

                                RowLayout {
                                    width: parent.width
                                    Text {
                                        text: "Available Devices"
                                        color: Nexa.Theme.mutedText
                                        font.family: Nexa.Theme.fontFamily
                                        font.pixelSize: Nexa.Theme.fontSize2Xs
                                        font.weight: Nexa.Theme.fontWeightDemiBold
                                    }
                                    Item { Layout.fillWidth: true }
                                    Text {
                                        text: root.availableDevices.length.toString()
                                        color: Nexa.Theme.mutedText
                                        font.family: Nexa.Theme.fontFamily
                                        font.pixelSize: Nexa.Theme.fontSize2Xs
                                    }
                                }

                                Repeater {
                                    model: root.availableDevices

                                    delegate: Rectangle {
                                        id: availItem
                                        required property var modelData
                                        width: deviceColumn.width
                                        height: 44
                                        radius: Nexa.Theme.radiusSm
                                        color: availMouse.pressed ? Nexa.Theme.pressed
                                             : availMouse.containsMouse ? Nexa.Theme.hover
                                             : Nexa.Theme.surfaceContainerHigh
                                        border.width: Nexa.Theme.borderThin
                                        border.color: availMouse.containsMouse ? Nexa.Theme.borderStrong : Nexa.Theme.border
                                        scale: availMouse.pressed ? 0.985 : 1.0

                                        Behavior on color { ColorAnimation { duration: 120 } }
                                        Behavior on border.color { ColorAnimation { duration: 120 } }
                                        Behavior on scale { NumberAnimation { duration: 120 } }

                                        MouseArea {
                                            id: availMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            enabled: !actionProcess.running
                                            onClicked: root.pairDevice(availItem.modelData)
                                        }

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: Nexa.Theme.spacingSm
                                            anchors.rightMargin: Nexa.Theme.spacingSm
                                            spacing: Nexa.Theme.spacingSm

                                            Text {
                                                text: root.deviceGlyph(availItem.modelData.device_type)
                                                color: Nexa.Theme.mutedText
                                                font.family: Nexa.Theme.iconFontFamily
                                                font.pixelSize: Nexa.Theme.iconMd
                                                Layout.alignment: Qt.AlignVCenter
                                            }

                                            Text {
                                                Layout.fillWidth: true
                                                text: root.deviceName(availItem.modelData)
                                                color: Nexa.Theme.text
                                                font.family: Nexa.Theme.fontFamily
                                                font.pixelSize: Nexa.Theme.fontSizeXs
                                                font.weight: Nexa.Theme.fontWeightMedium
                                                elide: Text.ElideRight
                                                Layout.alignment: Qt.AlignVCenter
                                            }

                                            // Action Spinner
                                            Text {
                                                visible: root.isPending(availItem.modelData)
                                                text: "󰑐"
                                                color: Nexa.Theme.primary
                                                font.family: Nexa.Theme.iconFontFamily
                                                font.pixelSize: Nexa.Theme.iconSm
                                                Layout.alignment: Qt.AlignVCenter

                                                RotationAnimator on rotation {
                                                    from: 0; to: 360; duration: 900
                                                    loops: Animation.Infinite
                                                    running: root.isPending(availItem.modelData) && root.visible
                                                }
                                            }

                                            // Pair Button
                                            NexaUI.NexaButton {
                                                text: root.isPending(availItem.modelData) ? "Pairing…" : "Pair"
                                                textSize: Nexa.Theme.fontSizeXs
                                                implicitHeight: Nexa.Theme.controlHeightSm
                                                horizontalPadding: Nexa.Theme.spacingSm
                                                Layout.alignment: Qt.AlignVCenter
                                                selected: true
                                                interactive: !actionProcess.running
                                                onClicked: root.pairDevice(availItem.modelData)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
