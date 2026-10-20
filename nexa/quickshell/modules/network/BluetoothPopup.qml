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
    property var deviceCatalog: []
    property string pendingAction: ""
    property string pendingAddress: ""
    property string actionError: ""
    property int postActionPolls: 0

    readonly property string nexad: Quickshell.env("HOME") + "/.config/nexa/rust/target/release/nexad"
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool enabled: root.adapter !== null && root.adapter.enabled
    property bool optimisticEnabled: root.enabled
    onEnabledChanged: root.optimisticEnabled = root.enabled

    readonly property bool scanning: root.adapter !== null && root.adapter.discovering
    readonly property var connectedDevices: root.deviceCatalog.filter(device => device.connected)
    readonly property var pairedDevices: root.deviceCatalog.filter(device => device.paired && !device.connected)
    readonly property var availableDevices: root.deviceCatalog.filter(device => !device.paired && !device.connected)

    implicitWidth: 380
    implicitHeight: Math.min(540, Math.max(340, mainLayout.implicitHeight + Nexa.Theme.spacingMd * 2))
    color: "transparent"
    grabFocus: true

    anchor {
        item: root.anchorItem
        rect.x: root.anchorItem ? root.anchorItem.width : 0
        rect.y: root.anchorItem ? root.anchorItem.height + Nexa.Theme.spacingSm : 0
        rect.width: 1
        rect.height: 1
        edges: Edges.Top | Edges.Left
        gravity: Edges.Bottom | Edges.Left
    }

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
        return (device.name && device.name.trim() !== "") ? device.name : (device.address || "Unknown device")
    }

    function isPending(device) {
        return device && root.pendingAddress === device.address && root.pendingAction !== ""
    }

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
                    if (parsed && Array.isArray(parsed.devices)) root.deviceCatalog = parsed.devices
                } catch (err) {
                    console.warn("NEXA Bluetooth JSON error:", err)
                }
            }
        }
    }

    function refreshInfo() {
        if (!infoProcess.running) infoProcess.exec([root.nexad, "network", "bluetooth", "info"])
    }

    Process {
        id: actionProcess
        onStarted: root.actionError = ""
        onExited: function(exitCode, exitStatus) {
            root.actionError = exitCode !== 0 ? "Bluetooth action failed" : ""
            if (exitCode !== 0) root.optimisticEnabled = root.enabled
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

    function toggleBluetooth() {
        if (actionProcess.running) return
        const nextState = !root.optimisticEnabled
        root.optimisticEnabled = nextState
        if (root.adapter && root.adapter.enabled && root.adapter.discovering) root.adapter.discovering = false
        runBluetooth([nextState ? "on" : "off"], "toggle")
    }

    function toggleDiscovery() {
        if (!root.adapter || !root.adapter.enabled) return
        root.adapter.discovering = !root.adapter.discovering
        if (root.adapter.discovering) root.refreshInfo()
    }

    function pairDevice(device) { if (device) runBluetooth(["pair", device.address], "pair", device.address) }
    function connectDevice(device) { if (device) runBluetooth(["connect", device.address], "connect", device.address) }
    function disconnectDevice(device) { if (device) runBluetooth(["disconnect", device.address], "disconnect", device.address) }
    function forgetDevice(device) { if (device) runBluetooth(["forget", device.address], "forget", device.address) }

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
            if (root.enabled && !root.scanning) root.toggleDiscovery()
        } else {
            root.pendingAction = ""
            root.pendingAddress = ""
            root.postActionPolls = 0
            if (root.scanning) root.toggleDiscovery()
        }
    }


    Component {
        id: connectedRowDelegate
        NexaUI.NexaCard {
            id: cCard
            required property var modelData
            Layout.fillWidth: true
            padding: Nexa.Theme.spacingSm
            selected: true

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: cCard.padding
                anchors.rightMargin: cCard.padding
                spacing: Nexa.Theme.spacingSm

                Rectangle {
                    implicitWidth: 32; implicitHeight: 32; radius: Nexa.Theme.radiusPill
                    color: Nexa.Theme.primaryContainer
                    Layout.alignment: Qt.AlignVCenter
                    Text {
                        anchors.centerIn: parent
                        text: root.deviceGlyph(cCard.modelData.device_type)
                        color: Nexa.Theme.primary
                        font.family: Nexa.Theme.iconFontFamily
                        font.pixelSize: 16
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 2
                    Text {
                        text: root.deviceName(cCard.modelData)
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
                        NexaUI.NexaActiveIndicator { Layout.alignment: Qt.AlignVCenter }
                        Text {
                            text: {
                                let str = "Connected"
                                if (cCard.modelData.battery !== undefined && cCard.modelData.battery !== null) {
                                    str += " · " + cCard.modelData.battery + "%"
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

                NexaUI.NexaIconButton {
                    icon: "󰆴"
                    iconSize: Nexa.Theme.iconSm
                    implicitWidth: Nexa.Theme.controlHeightSm
                    implicitHeight: Nexa.Theme.controlHeightSm
                    iconColor: hovered ? Nexa.Theme.error : Nexa.Theme.mutedText
                    Layout.alignment: Qt.AlignVCenter
                    enabled: !actionProcess.running
                    onClicked: root.forgetDevice(cCard.modelData)
                }

                NexaUI.NexaButton {
                    text: root.isPending(cCard.modelData) ? "Disconnecting…" : "Disconnect"
                    textSize: Nexa.Theme.fontSizeXs
                    implicitHeight: Nexa.Theme.controlHeightSm
                    horizontalPadding: Nexa.Theme.spacingSm
                    Layout.alignment: Qt.AlignVCenter
                    interactive: !actionProcess.running
                    onClicked: root.disconnectDevice(cCard.modelData)
                }
            }
        }
    }

    Component {
        id: pairedRowDelegate
        Rectangle {
            id: pRow
            required property var modelData
            Layout.fillWidth: true
            implicitHeight: 44
            radius: Nexa.Theme.radiusSm
            color: pMouse.pressed ? Nexa.Theme.pressed : (pMouse.containsMouse ? Nexa.Theme.surfaceContainerHighest : Nexa.Theme.surfaceContainerHigh)
            border.width: Nexa.Theme.borderThin
            border.color: pMouse.containsMouse ? Nexa.Theme.borderStrong : Nexa.Theme.border
            scale: pMouse.pressed ? 0.985 : 1.0

            Behavior on color { ColorAnimation { duration: Nexa.Theme.animationFast } }
            Behavior on border.color { ColorAnimation { duration: Nexa.Theme.animationFast } }
            Behavior on scale { NumberAnimation { duration: Nexa.Theme.animationFast; easing.type: Nexa.Theme.easingStandard } }

            MouseArea {
                id: pMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                enabled: !actionProcess.running
                onClicked: root.connectDevice(pRow.modelData)
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Nexa.Theme.spacingSm
                anchors.rightMargin: Nexa.Theme.spacingSm
                spacing: Nexa.Theme.spacingSm

                Text {
                    text: root.deviceGlyph(pRow.modelData.device_type)
                    color: Nexa.Theme.mutedText
                    font.family: Nexa.Theme.iconFontFamily
                    font.pixelSize: Nexa.Theme.iconMd
                    Layout.alignment: Qt.AlignVCenter
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 1

                    Text {
                        text: root.deviceName(pRow.modelData)
                        color: Nexa.Theme.text
                        font.family: Nexa.Theme.fontFamily
                        font.pixelSize: Nexa.Theme.fontSizeXs
                        font.weight: Nexa.Theme.fontWeightMedium
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Text {
                        text: root.isPending(pRow.modelData) ? "Connecting…" : "Paired"
                        color: Nexa.Theme.mutedText
                        font.family: Nexa.Theme.fontFamily
                        font.pixelSize: Nexa.Theme.fontSize2Xs
                    }
                }

                Text {
                    visible: root.isPending(pRow.modelData)
                    text: "󰑐"
                    color: Nexa.Theme.primary
                    font.family: Nexa.Theme.iconFontFamily
                    font.pixelSize: Nexa.Theme.iconSm
                    Layout.alignment: Qt.AlignVCenter
                    RotationAnimator on rotation {
                        from: 0; to: 360; duration: 900; loops: Animation.Infinite
                        running: root.isPending(pRow.modelData) && root.visible
                    }
                }

                NexaUI.NexaIconButton {
                    icon: "󰆴"
                    iconSize: Nexa.Theme.iconSm
                    implicitWidth: Nexa.Theme.controlHeightSm
                    implicitHeight: Nexa.Theme.controlHeightSm
                    iconColor: hovered ? Nexa.Theme.error : Nexa.Theme.mutedText
                    Layout.alignment: Qt.AlignVCenter
                    enabled: !actionProcess.running
                    onClicked: root.forgetDevice(pRow.modelData)
                }

                NexaUI.NexaButton {
                    text: root.isPending(pRow.modelData) ? "Connecting…" : "Connect"
                    textSize: Nexa.Theme.fontSizeXs
                    implicitHeight: Nexa.Theme.controlHeightSm
                    horizontalPadding: Nexa.Theme.spacingSm
                    Layout.alignment: Qt.AlignVCenter
                    interactive: !actionProcess.running
                    onClicked: root.connectDevice(pRow.modelData)
                }
            }
        }
    }

    Component {
        id: availableRowDelegate
        Rectangle {
            id: aRow
            required property var modelData
            Layout.fillWidth: true
            implicitHeight: 44
            radius: Nexa.Theme.radiusSm
            color: aMouse.pressed ? Nexa.Theme.pressed : (aMouse.containsMouse ? Nexa.Theme.surfaceContainerHighest : Nexa.Theme.surfaceContainerHigh)
            border.width: Nexa.Theme.borderThin
            border.color: aMouse.containsMouse ? Nexa.Theme.borderStrong : Nexa.Theme.border
            scale: aMouse.pressed ? 0.985 : 1.0

            Behavior on color { ColorAnimation { duration: Nexa.Theme.animationFast } }
            Behavior on border.color { ColorAnimation { duration: Nexa.Theme.animationFast } }
            Behavior on scale { NumberAnimation { duration: Nexa.Theme.animationFast; easing.type: Nexa.Theme.easingStandard } }

            MouseArea {
                id: aMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                enabled: !actionProcess.running
                onClicked: root.pairDevice(aRow.modelData)
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Nexa.Theme.spacingSm
                anchors.rightMargin: Nexa.Theme.spacingSm
                spacing: Nexa.Theme.spacingSm

                Text {
                    text: root.deviceGlyph(aRow.modelData.device_type)
                    color: Nexa.Theme.mutedText
                    font.family: Nexa.Theme.iconFontFamily
                    font.pixelSize: Nexa.Theme.iconMd
                    Layout.alignment: Qt.AlignVCenter
                }

                Text {
                    Layout.fillWidth: true
                    text: root.deviceName(aRow.modelData)
                    color: Nexa.Theme.text
                    font.family: Nexa.Theme.fontFamily
                    font.pixelSize: Nexa.Theme.fontSizeXs
                    font.weight: Nexa.Theme.fontWeightMedium
                    elide: Text.ElideRight
                    Layout.alignment: Qt.AlignVCenter
                }

                Text {
                    visible: root.isPending(aRow.modelData)
                    text: "󰑐"
                    color: Nexa.Theme.primary
                    font.family: Nexa.Theme.iconFontFamily
                    font.pixelSize: Nexa.Theme.iconSm
                    Layout.alignment: Qt.AlignVCenter
                    RotationAnimator on rotation {
                        from: 0; to: 360; duration: 900; loops: Animation.Infinite
                        running: root.isPending(aRow.modelData) && root.visible
                    }
                }

                NexaUI.NexaButton {
                    text: root.isPending(aRow.modelData) ? "Pairing…" : "Pair"
                    textSize: Nexa.Theme.fontSizeXs
                    implicitHeight: Nexa.Theme.controlHeightSm
                    horizontalPadding: Nexa.Theme.spacingSm
                    Layout.alignment: Qt.AlignVCenter
                    selected: true
                    interactive: !actionProcess.running
                    onClicked: root.pairDevice(aRow.modelData)
                }
            }
        }
    }
    Rectangle {
        id: mainSurface
        anchors.fill: parent
        radius: Nexa.Theme.radiusLg
        color: Nexa.Theme.panelBackground
        border.width: Nexa.Theme.borderThin
        border.color: Nexa.Theme.border

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

            // Header Row
            RowLayout {
                Layout.fillWidth: true
                spacing: Nexa.Theme.spacingSm

                Text {
                    text: root.connectedDevices.length > 0 ? "󰂱" : root.optimisticEnabled ? "󰂯" : "󰂲"
                    color: root.connectedDevices.length > 0 ? Nexa.Theme.primary : root.optimisticEnabled ? Nexa.Theme.text : Nexa.Theme.mutedText
                    font.family: Nexa.Theme.iconFontFamily
                    font.pixelSize: Nexa.Theme.iconLg
                    Layout.alignment: Qt.AlignVCenter
                }

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
                        }

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
                                text: root.connectedDevices.length > 0 ? root.connectedDevices.length + " connected" : root.deviceCatalog.length.toString()
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
                            : root.scanning ? "Searching for devices…" : "Ready to connect"
                        color: Nexa.Theme.mutedText
                        font.family: Nexa.Theme.fontFamily
                        font.pixelSize: Nexa.Theme.fontSize2Xs
                    }
                }

                Item { Layout.fillWidth: true }

                Item {
                    id: scanButton
                    implicitWidth: 32
                    implicitHeight: 32
                    visible: root.optimisticEnabled
                    Layout.alignment: Qt.AlignVCenter

                    Rectangle {
                        anchors.fill: parent
                        radius: Nexa.Theme.radiusSm
                        color: scanMouse.pressed ? Nexa.Theme.pressed : (scanMouse.containsMouse ? Nexa.Theme.hoverStrong : "transparent")
                        scale: scanMouse.pressed ? 0.92 : 1.0
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Behavior on scale { NumberAnimation { duration: 120; easing.type: Nexa.Theme.easingStandard } }

                        Text {
                            anchors.centerIn: parent
                            text: "󰑐"
                            color: root.scanning ? Nexa.Theme.primary : (scanMouse.containsMouse ? Nexa.Theme.text : Nexa.Theme.mutedText)
                            font.family: Nexa.Theme.iconFontFamily
                            font.pixelSize: Nexa.Theme.iconSm
                            RotationAnimator on rotation {
                                running: root.scanning && root.visible
                                from: 0; to: 360; duration: 1200; loops: Animation.Infinite
                            }
                        }

                        MouseArea {
                            id: scanMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            enabled: root.optimisticEnabled && !actionProcess.running
                            onClicked: root.toggleDiscovery()
                        }
                    }
                }

                NexaUI.NexaToggle {
                    checked: root.optimisticEnabled
                    interactive: !actionProcess.running
                    Layout.alignment: Qt.AlignVCenter
                    onToggled: root.toggleBluetooth()
                }
            }

            // Connected Devices Hero Cards
            Repeater { model: root.optimisticEnabled ? root.connectedDevices : []; delegate: connectedRowDelegate }

            // Device List Viewport
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

                    // Empty / Disabled State: Disabled
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

                    // Empty State: Scanning or 0 Devices Found
                    ColumnLayout {
                        visible: root.optimisticEnabled && root.deviceCatalog.length === 0 && root.connectedDevices.length === 0
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
                                from: 0; to: 360; duration: 1200; loops: Animation.Infinite
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
                                font.weight: Nexa.Theme.fontWeightMedium
                            }
                            Text {
                                visible: !root.scanning
                                Layout.alignment: Qt.AlignHCenter
                                text: "Make sure devices are in pairing mode"
                                color: Nexa.Theme.mutedText
                                font.family: Nexa.Theme.fontFamily
                                font.pixelSize: Nexa.Theme.fontSizeXs
                            }
                        }
                        NexaUI.NexaButton {
                            visible: !root.scanning
                            Layout.alignment: Qt.AlignHCenter
                            text: "Rescan"
                            icon: "󰑐"
                            interactive: !actionProcess.running
                            onClicked: root.toggleDiscovery()
                        }
                        Item { Layout.fillHeight: true }
                    }

                    // Active Device Lists
                    ScrollView {
                        visible: root.optimisticEnabled && (root.pairedDevices.length > 0 || root.availableDevices.length > 0)
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        ScrollBar.vertical.policy: ScrollBar.AsNeeded
                        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                        ColumnLayout {
                            width: parent.width
                            spacing: Nexa.Theme.spacingSm

                            // Paired Section
                            ColumnLayout {
                                visible: root.pairedDevices.length > 0
                                Layout.fillWidth: true
                                spacing: Nexa.Theme.spacingXs

                                RowLayout {
                                    Layout.fillWidth: true
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

                                Repeater { model: root.pairedDevices; delegate: pairedRowDelegate }
                            }

                            // Available Section
                            ColumnLayout {
                                visible: root.availableDevices.length > 0
                                Layout.fillWidth: true
                                spacing: Nexa.Theme.spacingXs

                                RowLayout {
                                    Layout.fillWidth: true
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

                                Repeater { model: root.availableDevices; delegate: availableRowDelegate }
                            }
                        }
                    }
                }
            }
        }
    }
}
