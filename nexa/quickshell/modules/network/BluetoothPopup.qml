import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Quickshell
import Quickshell.Io

import "../../services" as Services
import "../../NewNexaUI" as NexaUI

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
        Services.SystemState.nexadPath

    readonly property bool enabled:
        Services.SystemState.bluetoothEnabled

    property bool optimisticEnabled: root.enabled

    onEnabledChanged: {
        root.optimisticEnabled = root.enabled
    }

    property bool scanning: false

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

    implicitWidth: 412
    implicitHeight: Math.min(572, Math.max(372, mainLayout.implicitHeight + NexaUI.NexaTokens.spacingMd * 2 + 32))

    color: "transparent"
    grabFocus: true

    anchor {
        item: root.anchorItem

        rect.x:
            root.anchorItem
            ? root.anchorItem.width + 16
            : 0

        rect.y:
            root.anchorItem
            ? root.anchorItem.height + NexaUI.NexaTokens.spacingSm - 16
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
        if (root.scanning) {
            root.scanning = false
        }
        runBluetooth([nextState ? "on" : "off"], "toggle")
    }

    function toggleDiscovery() {
        if (!root.enabled) return
        const nextScan = !root.scanning
        root.scanning = nextScan
        runBluetooth(["scan", nextScan ? "on" : "off"], "scan")
        if (nextScan) {
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

    // GPU-Accelerated Nexa Drop Shadow for Bluetooth Popup
    NexaUI.NexaShadow {
        id: panelShadow
        targetItem: mainSurface
        elevation: 1
        spread: 0.08
    }

    Rectangle {
        id: mainSurface
        anchors.fill: parent
        anchors.margins: 16
        radius: NexaUI.NexaTokens.nexaRounding === 0 ? 0 : Math.min(mainSurface.height / 2, NexaUI.NexaTokens.nexaRounding)
        color: NexaUI.NexaColors.surfaceContainer
        border.width: NexaUI.NexaTokens.borderThin
        border.color: NexaUI.NexaColors.border

        NexaUI.NexaShaderSubstrate {
            anchors.fill: parent
            radius: parent.radius
        }

        // Apple / Tactile 4-stop Depth Micro-Gradient
        Rectangle {
            anchors.fill: parent
            radius: mainSurface.radius
            antialiasing: mainSurface.radius > 0
            visible: NexaUI.NexaOptics.surface3DGradient && NexaUI.NexaOptics.gradientIntensity > 0.01
            opacity: NexaUI.NexaOptics.gradientIntensity
            gradient: Gradient {
                GradientStop { position: 0.00; color: Qt.rgba(1, 1, 1, 0.055) }
                GradientStop { position: 0.40; color: Qt.rgba(1, 1, 1, 0.012) }
                GradientStop { position: 0.70; color: Qt.rgba(0, 0, 0, 0.000) }
                GradientStop { position: 1.00; color: Qt.rgba(0, 0, 0, 0.140) }
            }
        }

        // Top Chamfer Specular Highlight
        Rectangle {
            anchors.top: parent.top
            anchors.topMargin: 1
            anchors.horizontalCenter: parent.horizontalCenter
            width: mainSurface.radius > 0 ? Math.max(0, parent.width - mainSurface.radius * 1.6) : parent.width
            height: 1
            visible: NexaUI.NexaOptics.specularHighlight && NexaUI.NexaOptics.specularIntensity > 0.01
            opacity: Math.min(1.0, NexaUI.NexaOptics.specularIntensity / 0.28)
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.32) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        scale: root.visible ? 1.0 : 0.97
        opacity: root.visible ? 1.0 : 0.0
        transformOrigin: Item.TopRight

        Behavior on scale {
            enabled: NexaUI.NexaMotion.enabled
            SpringAnimation {
                spring: NexaUI.NexaMotion.useSpring("popups") ? NexaUI.NexaMotion.springStiffness : 8.0
                damping: NexaUI.NexaMotion.useSpring("popups") ? NexaUI.NexaMotion.springDamping : 1.0
                mass: NexaUI.NexaMotion.springMass
                epsilon: 0.002
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: NexaUI.NexaMotion.durationFast
                easing.type: NexaUI.NexaMotion.decelerateEasing
            }
        }

        ColumnLayout {
            id: mainLayout
            anchors.fill: parent
            anchors.margins: NexaUI.NexaTokens.spacingMd
            spacing: NexaUI.NexaTokens.spacingMd

            // ====================================================
            // TOP HEADER ROW
            // ====================================================
            RowLayout {
                Layout.fillWidth: true
                spacing: NexaUI.NexaTokens.spacingSm

                // Status Icon
                Text {
                    text: root.connectedDevices.length > 0 ? "󰂱" : root.optimisticEnabled ? "󰂯" : "󰂲"
                    color: root.connectedDevices.length > 0 ? NexaUI.NexaColors.primary : root.optimisticEnabled ? NexaUI.NexaColors.text : NexaUI.NexaColors.mutedText
                    font.family: NexaUI.NexaTypography.familyIcon
                    font.pixelSize: NexaUI.NexaTypography.sizeLg
                    Layout.alignment: Qt.AlignVCenter
                }

                // Title & Subtitle
                ColumnLayout {
                    spacing: 1
                    Layout.alignment: Qt.AlignVCenter

                    RowLayout {
                        spacing: NexaUI.NexaTokens.spacingXs
                        Layout.alignment: Qt.AlignVCenter

                        Text {
                            text: "Bluetooth"
                            color: NexaUI.NexaColors.text
                            font.family: NexaUI.NexaTypography.familyDisplay
                            font.pixelSize: NexaUI.NexaTypography.sizeMd
                            font.weight: NexaUI.NexaTypography.weightSemiBold
                            Layout.alignment: Qt.AlignVCenter
                        }

                        // Badge count
                        Rectangle {
                            visible: root.optimisticEnabled && root.deviceCatalog.length > 0
                            implicitWidth: badgeText.implicitWidth + 10
                            implicitHeight: 18
                            radius: 9
                            color: NexaUI.NexaColors.surfaceContainerHighest
                            Layout.alignment: Qt.AlignVCenter

                            Text {
                                id: badgeText
                                anchors.centerIn: parent
                                text: root.connectedDevices.length > 0
                                      ? root.connectedDevices.length + " connected"
                                      : root.deviceCatalog.length.toString()
                                color: root.connectedDevices.length > 0 ? NexaUI.NexaColors.primary : NexaUI.NexaColors.mutedText
                                font.family: NexaUI.NexaTypography.familyBody
                                font.pixelSize: NexaUI.NexaTypography.size2Xs
                                font.weight: NexaUI.NexaTypography.weightMedium
                            }
                        }
                    }

                    Text {
                        text: !root.optimisticEnabled ? "Disabled"
                            : root.connectedDevices.length > 0 ? root.connectedDevices.length + (root.connectedDevices.length === 1 ? " device active" : " devices active")
                            : root.scanning ? "Searching for devices…"
                            : "Ready to connect"
                        color: NexaUI.NexaColors.mutedText
                        font.family: NexaUI.NexaTypography.familyBody
                        font.pixelSize: NexaUI.NexaTypography.size2Xs
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
                        radius: NexaUI.NexaTokens.radiusPill
                        color: scanArea.containsMouse ? NexaUI.NexaColors.hoverOverlay : "transparent"
                        border.color: scanArea.containsMouse ? NexaUI.NexaColors.borderSubtle : "transparent"
                        border.width: 1

                        Behavior on color { ColorAnimation { duration: 150 } }
                    }

                    Text {
                        id: scanIcon
                        anchors.centerIn: parent
                        text: "󰑐"
                        font.family: NexaUI.NexaTypography.familyIcon
                        font.pixelSize: 16
                        color: root.scanning ? NexaUI.NexaColors.primary : NexaUI.NexaColors.onSurface

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
                color: NexaUI.NexaColors.error
                font.family: NexaUI.NexaTypography.familyBody
                font.pixelSize: NexaUI.NexaTypography.size2Xs
                font.weight: NexaUI.NexaTypography.weightMedium
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
                    padding: NexaUI.NexaTokens.spacingSm
                    implicitHeight: Math.max(52, connectedRow.implicitHeight + padding * 2)
                    selected: true

                    RowLayout {
                        id: connectedRow
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: connectedCard.padding
                        anchors.rightMargin: connectedCard.padding
                        spacing: NexaUI.NexaTokens.spacingSm

                        // Capsule Device Glyph
                        Rectangle {
                            implicitWidth: 32
                            implicitHeight: 32
                            radius: NexaUI.NexaTokens.radiusPill
                            color: NexaUI.NexaColors.surfaceContainerHigh
                            Layout.alignment: Qt.AlignVCenter

                            Text {
                                anchors.centerIn: parent
                                text: root.deviceGlyph(connectedCard.modelData.device_type)
                                color: NexaUI.NexaColors.primary
                                font.family: NexaUI.NexaTypography.familyIcon
                                font.pixelSize: NexaUI.NexaTypography.sizeMd
                            }
                        }

                        // Name & Status Details
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 2

                            Text {
                                text: root.deviceName(connectedCard.modelData)
                                color: NexaUI.NexaColors.text
                                font.family: NexaUI.NexaTypography.familyBody
                                font.pixelSize: NexaUI.NexaTypography.sizeSm
                                font.weight: NexaUI.NexaTypography.weightSemiBold
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            RowLayout {
                                spacing: NexaUI.NexaTokens.spacingXs
                                Layout.alignment: Qt.AlignVCenter

                                Rectangle {
                                    implicitWidth: NexaUI.NexaTokens.indicatorWidth
                                    implicitHeight: NexaUI.NexaTokens.indicatorHeight
                                    radius: NexaUI.NexaTokens.radiusPill
                                    color: NexaUI.NexaColors.primary
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
                                    color: NexaUI.NexaColors.mutedText
                                    font.family: NexaUI.NexaTypography.familyBody
                                    font.pixelSize: NexaUI.NexaTypography.sizeXs
                                    Layout.alignment: Qt.AlignVCenter
                                }
                            }
                        }

                        // Forget Button
                        NexaUI.NexaButton {
                            variant: "icon"
                            icon: "󰆴"
                            iconSize: NexaUI.NexaTypography.sizeSm
                            implicitWidth: NexaUI.NexaTokens.controlHeightSm
                            implicitHeight: NexaUI.NexaTokens.controlHeightSm
                            Layout.alignment: Qt.AlignVCenter
                            interactive: !actionProcess.running
                            onClicked: root.forgetDevice(connectedCard.modelData)
                        }

                        // Disconnect Button
                        NexaUI.NexaButton {
                            variant: "tonal"
                            text: root.isPending(connectedCard.modelData) ? "Disconnecting…" : "Disconnect"
                            implicitHeight: NexaUI.NexaTokens.controlHeightSm
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
                implicitHeight: Math.min(320, Math.max(220, listInnerColumn.implicitHeight + NexaUI.NexaTokens.spacingSm * 2))
                radius: NexaUI.NexaTokens.radiusMd
                color: NexaUI.NexaColors.surfaceContainer
                border.width: NexaUI.NexaTokens.borderThin
                border.color: NexaUI.NexaColors.border

                ColumnLayout {
                    id: listInnerColumn
                    anchors.fill: parent
                    anchors.margins: NexaUI.NexaTokens.spacingSm
                    spacing: NexaUI.NexaTokens.spacingSm

                    // ============================================
                    // EMPTY / DISABLED STATES
                    // ============================================

                    // State 1: Bluetooth Disabled
                    ColumnLayout {
                        visible: !root.optimisticEnabled
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.alignment: Qt.AlignCenter
                        spacing: NexaUI.NexaTokens.spacingMd

                        Item { Layout.fillHeight: true }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "󰂲"
                            color: NexaUI.NexaColors.mutedText
                            font.family: NexaUI.NexaTypography.familyIcon
                            font.pixelSize: 48
                        }

                        ColumnLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 4

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "Bluetooth is turned off"
                                color: NexaUI.NexaColors.text
                                font.family: NexaUI.NexaTypography.familyBody
                                font.pixelSize: NexaUI.NexaTypography.sizeSm
                                font.weight: NexaUI.NexaTypography.weightSemiBold
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "Turn on Bluetooth to find and connect to devices"
                                color: NexaUI.NexaColors.mutedText
                                font.family: NexaUI.NexaTypography.familyBody
                                font.pixelSize: NexaUI.NexaTypography.sizeXs
                            }
                        }

                        NexaUI.NexaButton {
                            Layout.alignment: Qt.AlignHCenter
                            text: "Turn On Bluetooth"
                            icon: "󰂯"
                            variant: "filled"
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
                        spacing: NexaUI.NexaTokens.spacingSm

                        Item { Layout.fillHeight: true }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: root.scanning ? "󰑐" : "󰂲"
                            color: root.scanning ? NexaUI.NexaColors.primary : NexaUI.NexaColors.mutedText
                            font.family: NexaUI.NexaTypography.familyIcon
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
                                color: NexaUI.NexaColors.text
                                font.family: NexaUI.NexaTypography.familyBody
                                font.pixelSize: NexaUI.NexaTypography.sizeSm
                                font.weight: NexaUI.NexaTypography.weightSemiBold
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "Make sure devices are in pairing mode"
                                color: NexaUI.NexaColors.mutedText
                                font.family: NexaUI.NexaTypography.familyBody
                                font.pixelSize: NexaUI.NexaTypography.sizeXs
                            }
                        }

                        NexaUI.NexaButton {
                            Layout.alignment: Qt.AlignHCenter
                            text: "Scan for Devices"
                            icon: "󰑐"
                            variant: "filled"
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
                        flickDeceleration: 1750
                        maximumFlickVelocity: 2500
                        pixelAligned: true

                        NexaUI.NexaSmoothScroll {}

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
                                radius: NexaUI.NexaTokens.radiusPill
                                color: btScrollBar.hovered ? NexaUI.NexaColors.primary : NexaUI.NexaColors.mutedText
                                opacity: (btScrollBar.active || btScrollBar.hovered) ? 0.6 : 0.0

                                Behavior on opacity { NumberAnimation { duration: NexaUI.NexaMotion.durationNormal } }
                                Behavior on color { ColorAnimation { duration: NexaUI.NexaMotion.durationFast } }
                            }
                            background: null
                        }

                        Column {
                            id: deviceColumn
                            width: deviceFlick.width - (deviceFlick.contentHeight > deviceFlick.height ? (NexaUI.NexaTokens.spacingSm + 4) : 0)
                            spacing: NexaUI.NexaTokens.spacingSm

                            Behavior on width {
                                NumberAnimation { duration: NexaUI.NexaMotion.durationFast }
                            }

                            // ----------------------------------------
                            // PAIRED DEVICES SECTION
                            // ----------------------------------------
                            Column {
                                width: parent.width
                                spacing: NexaUI.NexaTokens.spacingXs
                                visible: root.pairedDevices.length > 0

                                RowLayout {
                                    width: parent.width
                                    Text {
                                        text: "Paired Devices"
                                        color: NexaUI.NexaColors.mutedText
                                        font.family: NexaUI.NexaTypography.familyBody
                                        font.pixelSize: NexaUI.NexaTypography.size2Xs
                                        font.weight: NexaUI.NexaTypography.weightSemiBold
                                    }
                                    Item { Layout.fillWidth: true }
                                    Text {
                                        text: root.pairedDevices.length.toString()
                                        color: NexaUI.NexaColors.mutedText
                                        font.family: NexaUI.NexaTypography.familyBody
                                        font.pixelSize: NexaUI.NexaTypography.size2Xs
                                    }
                                }

                                Repeater {
                                    model: root.pairedDevices

                                    delegate: Rectangle {
                                        id: pairedItem
                                        required property var modelData
                                        width: deviceColumn.width
                                        height: 48
                                        radius: NexaUI.NexaTokens.radiusSm
                                        color: pairedMouse.pressed ? NexaUI.NexaColors.surfaceContainerHighest
                                             : pairedMouse.containsMouse ? NexaUI.NexaColors.surfaceContainerHigh
                                             : NexaUI.NexaColors.surfaceContainerLow
                                        border.width: NexaUI.NexaTokens.borderThin
                                        border.color: pairedMouse.containsMouse ? NexaUI.NexaColors.borderStrong : NexaUI.NexaColors.border
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
                                            anchors.leftMargin: NexaUI.NexaTokens.spacingSm
                                            anchors.rightMargin: NexaUI.NexaTokens.spacingSm
                                            spacing: NexaUI.NexaTokens.spacingSm

                                            Text {
                                                text: root.deviceGlyph(pairedItem.modelData.device_type)
                                                color: NexaUI.NexaColors.text
                                                font.family: NexaUI.NexaTypography.familyIcon
                                                font.pixelSize: NexaUI.NexaTypography.sizeMd
                                                Layout.alignment: Qt.AlignVCenter
                                            }

                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                Layout.alignment: Qt.AlignVCenter
                                                spacing: 1

                                                Text {
                                                    text: root.deviceName(pairedItem.modelData)
                                                    color: NexaUI.NexaColors.text
                                                    font.family: NexaUI.NexaTypography.familyBody
                                                    font.pixelSize: NexaUI.NexaTypography.sizeXs
                                                    font.weight: NexaUI.NexaTypography.weightMedium
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true
                                                }

                                                Text {
                                                    text: root.isPending(pairedItem.modelData) ? "Connecting…" : "Paired"
                                                    color: root.isPending(pairedItem.modelData) ? NexaUI.NexaColors.primary : NexaUI.NexaColors.mutedText
                                                    font.family: NexaUI.NexaTypography.familyBody
                                                    font.pixelSize: NexaUI.NexaTypography.size2Xs
                                                }
                                            }

                                            // Action Spinner
                                            Text {
                                                visible: root.isPending(pairedItem.modelData)
                                                text: "󰑐"
                                                color: NexaUI.NexaColors.primary
                                                font.family: NexaUI.NexaTypography.familyIcon
                                                font.pixelSize: NexaUI.NexaTypography.sizeSm
                                                Layout.alignment: Qt.AlignVCenter

                                                RotationAnimator on rotation {
                                                    from: 0; to: 360; duration: 900
                                                    loops: Animation.Infinite
                                                    running: root.isPending(pairedItem.modelData) && root.visible
                                                }
                                            }

                                            // Forget Button
                                            NexaUI.NexaButton {
                                                variant: "icon"
                                                icon: "󰆴"
                                                iconSize: NexaUI.NexaTypography.sizeSm
                                                implicitWidth: NexaUI.NexaTokens.controlHeightSm
                                                implicitHeight: NexaUI.NexaTokens.controlHeightSm
                                                Layout.alignment: Qt.AlignVCenter
                                                interactive: !actionProcess.running
                                                onClicked: root.forgetDevice(pairedItem.modelData)
                                            }

                                            // Connect Button
                                            NexaUI.NexaButton {
                                                variant: "tonal"
                                                text: "Connect"
                                                implicitHeight: NexaUI.NexaTokens.controlHeightSm
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
                                spacing: NexaUI.NexaTokens.spacingXs
                                visible: root.availableDevices.length > 0

                                RowLayout {
                                    width: parent.width
                                    Text {
                                        text: "Available Devices"
                                        color: NexaUI.NexaColors.mutedText
                                        font.family: NexaUI.NexaTypography.familyBody
                                        font.pixelSize: NexaUI.NexaTypography.size2Xs
                                        font.weight: NexaUI.NexaTypography.weightSemiBold
                                    }
                                    Item { Layout.fillWidth: true }
                                    Text {
                                        text: root.availableDevices.length.toString()
                                        color: NexaUI.NexaColors.mutedText
                                        font.family: NexaUI.NexaTypography.familyBody
                                        font.pixelSize: NexaUI.NexaTypography.size2Xs
                                    }
                                }

                                Repeater {
                                    model: root.availableDevices

                                    delegate: Rectangle {
                                        id: availItem
                                        required property var modelData
                                        width: deviceColumn.width
                                        height: 44
                                        radius: NexaUI.NexaTokens.radiusSm
                                        color: availMouse.pressed ? NexaUI.NexaColors.surfaceContainerHighest
                                             : availMouse.containsMouse ? NexaUI.NexaColors.surfaceContainerHigh
                                             : NexaUI.NexaColors.surfaceContainerLow
                                        border.width: NexaUI.NexaTokens.borderThin
                                        border.color: availMouse.containsMouse ? NexaUI.NexaColors.borderStrong : NexaUI.NexaColors.border
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
                                            anchors.leftMargin: NexaUI.NexaTokens.spacingSm
                                            anchors.rightMargin: NexaUI.NexaTokens.spacingSm
                                            spacing: NexaUI.NexaTokens.spacingSm

                                            Text {
                                                text: root.deviceGlyph(availItem.modelData.device_type)
                                                color: NexaUI.NexaColors.mutedText
                                                font.family: NexaUI.NexaTypography.familyIcon
                                                font.pixelSize: NexaUI.NexaTypography.sizeMd
                                                Layout.alignment: Qt.AlignVCenter
                                            }

                                            Text {
                                                Layout.fillWidth: true
                                                text: root.deviceName(availItem.modelData)
                                                color: NexaUI.NexaColors.text
                                                font.family: NexaUI.NexaTypography.familyBody
                                                font.pixelSize: NexaUI.NexaTypography.sizeXs
                                                font.weight: NexaUI.NexaTypography.weightMedium
                                                elide: Text.ElideRight
                                                Layout.alignment: Qt.AlignVCenter
                                            }

                                            // Action Spinner
                                            Text {
                                                visible: root.isPending(availItem.modelData)
                                                text: "󰑐"
                                                color: NexaUI.NexaColors.primary
                                                font.family: NexaUI.NexaTypography.familyIcon
                                                font.pixelSize: NexaUI.NexaTypography.sizeSm
                                                Layout.alignment: Qt.AlignVCenter

                                                RotationAnimator on rotation {
                                                    from: 0; to: 360; duration: 900
                                                    loops: Animation.Infinite
                                                    running: root.isPending(availItem.modelData) && root.visible
                                                }
                                            }

                                            // Pair Button
                                            NexaUI.NexaButton {
                                                variant: "filled"
                                                text: root.isPending(availItem.modelData) ? "Pairing…" : "Pair"
                                                implicitHeight: NexaUI.NexaTokens.controlHeightSm
                                                Layout.alignment: Qt.AlignVCenter
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
