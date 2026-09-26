import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Quickshell
import Quickshell.Io
import Quickshell.Networking

import "../../theme" as Nexa
import "../../theme/components" as NexaUI


PopupWindow {
    id: root

    property Item anchorItem

    // ============================================================
    // CONNECTION STATE
    // ============================================================

    property var selectedNetwork: null
    property var connectingNetwork: null

    property string password: ""
    property string connectError: ""
    property string actionError: ""
    property string pendingAction: ""

    property bool showPassword: false
    property bool connecting: false

    readonly property string nexad:
        Quickshell.env("HOME")
        + "/.config/nexa/rust/target/release/nexad"

    // ============================================================
    // QUICKSHELL NETWORK STATE
    // ============================================================

    readonly property var device: {
        for (let d of Networking.devices.values) {
            if (d.type === DeviceType.Wifi)
                return d
        }
        return null
    }

    readonly property var connectedNetwork: {
        if (!root.device)
            return null

        for (let n of root.device.networks.values) {
            if (n.connected)
                return n
        }
        return null
    }

    readonly property bool wifiEnabled:
        Networking.wifiEnabled
        && Networking.wifiHardwareEnabled

    readonly property bool isScanning:
        (root.device && root.device.scannerEnabled)
        || networkProcess.running

    // ============================================================
    // DEDUPLICATED AVAILABLE NETWORKS
    // ============================================================

    readonly property var availableList: {
        if (!root.device || !root.wifiEnabled)
            return []

        const connectedName = root.connectedNetwork ? root.connectedNetwork.name : ""
        const map = new Map()

        for (let net of root.device.networks.values) {
            if (!net.name || net.name === "" || net.connected || net.name === connectedName)
                continue

            const existing = map.get(net.name)
            if (!existing || net.signalStrength > existing.signalStrength) {
                map.set(net.name, net)
            }
        }

        return Array.from(map.values()).sort(
            (a, b) => b.signalStrength - a.signalStrength
        )
    }

    // ============================================================
    // WINDOW CONFIGURATION
    // ============================================================

    implicitWidth: 420
    implicitHeight: Math.min(540, Math.max(300, contentColumn.implicitHeight + Nexa.Theme.spacingMd * 2))

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
    // RUST PROCESS (Toggle & Refresh)
    // ============================================================

    Process {
        id: networkProcess

        onStarted: {
            root.actionError = ""
        }

        onExited: function(exitCode, exitStatus) {
            if (exitCode !== 0) {
                root.actionError = "Network action failed"
            } else {
                root.actionError = ""
            }
            root.pendingAction = ""
        }
    }

    Timer {
        id: passwordFocusTimer
        interval: 100
        repeat: false
        onTriggered: {
            if (root.selectedNetwork && passwordInputField) {
                passwordInputField.forceActiveFocus()
            }
        }
    }

    function runNetwork(args, action) {
        if (networkProcess.running)
            return

        root.pendingAction = action || ""
        networkProcess.exec([root.nexad, "network"].concat(args))
    }

    // ============================================================
    // HELPERS
    // ============================================================

    function signalPercent(network) {
        return network ? Math.round(network.signalStrength * 100) : 0
    }

    function signalIcon(network) {
        const strength = signalPercent(network)
        if (strength >= 75) return "󰤨"
        if (strength >= 50) return "󰤥"
        if (strength >= 25) return "󰤢"
        return "󰤟"
    }

    function isOpen(network) {
        return network && (
            network.security === WifiSecurityType.Open
            || network.security === WifiSecurityType.Owe
        )
    }

    function isSecured(network) {
        return network && !isOpen(network)
    }

    function connectionErrorText(reason) {
        if (reason === ConnectionFailReason.NoSecrets)
            return "Password required"
        if (reason === ConnectionFailReason.WifiAuthTimeout)
            return "Incorrect password or authentication timed out"
        if (reason === ConnectionFailReason.WifiClientFailed)
            return "Incorrect password or authentication failed"
        if (reason === ConnectionFailReason.WifiNetworkLost)
            return "Network is no longer available"
        if (reason === ConnectionFailReason.WifiClientDisconnected)
            return "Connection rejected or disconnected"

        return "Unable to connect to network"
    }

    function isAuthenticationFailure(reason) {
        return (
            reason === ConnectionFailReason.NoSecrets
            || reason === ConnectionFailReason.WifiAuthTimeout
            || reason === ConnectionFailReason.WifiClientFailed
            || reason === ConnectionFailReason.WifiClientDisconnected
        )
    }

    // ============================================================
    // CONNECTION ACTIONS
    // ============================================================

    function chooseNetwork(network) {
        if (!network || root.connecting)
            return

        root.connectError = ""

        if (network.connected)
            return

        if (network.known || root.isOpen(network)) {
            root.connecting = true
            root.connectingNetwork = network
            network.connect()
            return
        }

        root.selectedNetwork = network
        root.password = ""
        root.showPassword = false
        passwordFocusTimer.restart()
    }

    function connectSelected() {
        if (!root.selectedNetwork || root.password.length === 0 || root.connecting)
            return

        root.connectError = ""
        root.connectingNetwork = root.selectedNetwork
        root.connecting = true

        root.selectedNetwork.connectWithPsk(root.password)
    }

    function connectionSucceeded() {
        root.connecting = false
        root.connectingNetwork = null
        root.selectedNetwork = null
        root.password = ""
        root.connectError = ""
        root.showPassword = false
    }

    function connectionFailed(network, reason) {
        if (!network)
            return

        root.connecting = false
        root.connectError = root.connectionErrorText(reason)

        if (root.isAuthenticationFailure(reason) && network.known) {
            network.forget()
        }

        if (root.isSecured(network)) {
            root.selectedNetwork = network
            root.password = ""
            root.showPassword = false
            passwordFocusTimer.restart()
        } else {
            root.selectedNetwork = null
        }

        root.connectingNetwork = null
    }

    function cancelConnect() {
        root.selectedNetwork = null
        root.connectingNetwork = null
        root.password = ""
        root.connectError = ""
        root.showPassword = false
        root.connecting = false
    }

    function disconnectCurrent() {
        if (root.connectedNetwork)
            root.connectedNetwork.disconnect()
    }

    function forgetNetwork(network) {
        if (!network)
            return

        if (network.connected)
            network.disconnect()

        network.forget()

        if (root.selectedNetwork && root.selectedNetwork.name === network.name)
            root.cancelConnect()
    }

    function refreshNetworks() {
        runNetwork(["wifi", "refresh"], "refresh")
    }

    function toggleWifi() {
        runNetwork(["wifi", Networking.wifiEnabled ? "off" : "on"], "toggle")
    }

    // ============================================================
    // WATCH CURRENT CONNECTION ATTEMPT
    // ============================================================

    Connections {
        target: root.connectingNetwork
        ignoreUnknownSignals: true

        function onConnectionFailed(reason) {
            root.connectionFailed(root.connectingNetwork, reason)
        }

        function onConnectedChanged() {
            if (root.connectingNetwork && root.connectingNetwork.connected) {
                root.connectionSucceeded()
            }
        }
    }

    // ============================================================
    // POPUP LIFECYCLE
    // ============================================================

    onVisibleChanged: {
        if (root.device)
            root.device.scannerEnabled = visible

        if (!visible)
            root.cancelConnect()
    }

    onDeviceChanged: {
        if (root.device && root.visible)
            root.device.scannerEnabled = true
    }

    // ============================================================
    // POPUP MAIN PANEL
    // ============================================================

    Rectangle {
        id: panelBackground
        anchors.fill: parent

        radius: Nexa.Theme.radiusLg
        color: Nexa.Theme.panelBackground
        border.width: Nexa.Theme.borderThin
        border.color: Nexa.Theme.borderStrong

        // Continuous-corner top glass highlight
        Rectangle {
            anchors.fill: parent
            anchors.margins: parent.border.width
            radius: Math.max(0, parent.radius - parent.border.width)
            gradient: Gradient {
                GradientStop { position: 0.0; color: Nexa.Theme.edgeHighlight }
                GradientStop { position: 0.35; color: "transparent" }
            }
        }

        opacity: root.visible ? Nexa.Theme.opacityFull : Nexa.Theme.opacityHidden
        scale: root.visible ? Nexa.Theme.normalScale : 0.96
        transformOrigin: Item.TopRight

        Behavior on opacity {
            NumberAnimation {
                duration: Nexa.Theme.popEnterDuration
                easing.type: Nexa.Theme.easingStandard
                easing.bezierCurve: Nexa.Theme.easingFluidCurve
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: Nexa.Theme.popEnterDuration
                easing.type: Nexa.Theme.easingEnter
                easing.bezierCurve: Nexa.Theme.easingSpringCurve
            }
        }

        ColumnLayout {
            id: contentColumn
            anchors.fill: parent
            anchors.margins: Nexa.Theme.spacingMd
            spacing: Nexa.Theme.spacingSm

            // ====================================================
            // HEADER BAR
            // ====================================================
            RowLayout {
                Layout.fillWidth: true
                spacing: Nexa.Theme.spacingSm

                // Status Icon & Titles
                RowLayout {
                    spacing: Nexa.Theme.spacingSm

                    Text {
                        text: "󰤨"
                        color: root.wifiEnabled ? Nexa.Theme.primary : Nexa.Theme.mutedText
                        font.family: Nexa.Theme.iconFontFamily
                        font.pixelSize: Nexa.Theme.iconMd

                        Behavior on color {
                            ColorAnimation {
                                duration: Nexa.Theme.motionInteraction
                                easing.bezierCurve: Nexa.Theme.easingFluidCurve
                            }
                        }
                    }

                    ColumnLayout {
                        spacing: 1

                        Text {
                            text: "Wi-Fi"
                            color: Nexa.Theme.text
                            font.family: Nexa.Theme.fontFamily
                            font.pixelSize: Nexa.Theme.fontSizeSm
                            font.weight: Nexa.Theme.fontWeightDemiBold
                        }

                        Text {
                            text: {
                                if (!root.wifiEnabled) return "Disabled"
                                if (root.connectedNetwork) return "Connected to " + root.connectedNetwork.name
                                if (root.isScanning) return "Scanning nearby…"
                                return root.availableList.length + " networks found"
                            }
                            color: Nexa.Theme.mutedText
                            font.family: Nexa.Theme.fontFamily
                            font.pixelSize: Nexa.Theme.fontSize2Xs
                            elide: Text.ElideRight
                            Layout.maximumWidth: 220
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                // Rescan Button (Stable hover background, only icon rotates)
                Rectangle {
                    implicitWidth: Nexa.Theme.controlHeightMd
                    implicitHeight: Nexa.Theme.controlHeightMd
                    radius: Nexa.Theme.radiusMd
                    antialiasing: true
                    color: refreshMouse.pressed ? Nexa.Theme.pressed
                         : refreshMouse.containsMouse ? Nexa.Theme.hoverStrong
                         : "transparent"
                    scale: refreshMouse.pressed ? Nexa.Theme.pressScale
                         : refreshMouse.containsMouse ? Nexa.Theme.hoverScale
                         : Nexa.Theme.normalScale

                    Behavior on color {
                        ColorAnimation {
                            duration: Nexa.Theme.motionInteraction
                            easing.bezierCurve: Nexa.Theme.easingFluidCurve
                        }
                    }

                    Behavior on scale {
                        NumberAnimation {
                            duration: Nexa.Theme.motionInteraction
                            easing.bezierCurve: Nexa.Theme.easingFluidCurve
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "󰑐"
                        color: root.isScanning ? Nexa.Theme.primary : (refreshMouse.containsMouse ? Nexa.Theme.text : Nexa.Theme.mutedText)
                        font.family: Nexa.Theme.iconFontFamily
                        font.pixelSize: Nexa.Theme.iconSm

                        RotationAnimator on rotation {
                            running: root.isScanning && root.visible
                            from: 0
                            to: 360
                            duration: 1200
                            loops: Animation.Infinite
                        }
                    }

                    MouseArea {
                        id: refreshMouse
                        anchors.fill: parent
                        enabled: root.wifiEnabled && !networkProcess.running
                        hoverEnabled: true
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: root.refreshNetworks()
                    }
                }

                // Wi-Fi Master Toggle
                NexaUI.NexaToggle {
                    checked: Networking.wifiEnabled
                    interactive: !networkProcess.running
                    onToggled: root.toggleWifi()
                }
            }

            // Backend Action Error (if any)
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
            // ACTIVE CONNECTION CARD (Single Unified Card)
            // ====================================================
            NexaUI.NexaCard {
                id: activeNetworkCard
                visible: root.connectedNetwork !== null && root.wifiEnabled
                Layout.fillWidth: true
                padding: Nexa.Theme.spacingSm
                implicitHeight: Math.max(52, activeRow.implicitHeight + padding * 2)
                selected: true

                RowLayout {
                    id: activeRow
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: activeNetworkCard.padding
                    anchors.rightMargin: activeNetworkCard.padding
                    spacing: Nexa.Theme.spacingSm

                    // Prominent Signal Glyph
                    Text {
                        text: root.connectedNetwork ? root.signalIcon(root.connectedNetwork) : "󰤭"
                        color: Nexa.Theme.primary
                        font.family: Nexa.Theme.iconFontFamily
                        font.pixelSize: Nexa.Theme.iconLg
                        Layout.alignment: Qt.AlignVCenter
                    }

                    // SSID & Details
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 2

                        Text {
                            text: root.connectedNetwork ? root.connectedNetwork.name : ""
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
                                text: "Connected · " + root.signalPercent(root.connectedNetwork) + "%"
                                color: Nexa.Theme.mutedText
                                font.family: Nexa.Theme.fontFamily
                                font.pixelSize: Nexa.Theme.fontSizeXs
                                Layout.alignment: Qt.AlignVCenter
                            }
                        }
                    }

                    // Forget Active Network Button
                    NexaUI.NexaIconButton {
                        icon: "󰆴"
                        iconSize: Nexa.Theme.iconSm
                        implicitWidth: Nexa.Theme.controlHeightSm
                        implicitHeight: Nexa.Theme.controlHeightSm
                        iconColor: hovered ? Nexa.Theme.error : Nexa.Theme.mutedText
                        Layout.alignment: Qt.AlignVCenter
                        onClicked: root.forgetNetwork(root.connectedNetwork)
                    }

                    // Disconnect Active Network Button
                    NexaUI.NexaButton {
                        text: "Disconnect"
                        textSize: Nexa.Theme.fontSizeXs
                        implicitHeight: Nexa.Theme.controlHeightSm
                        horizontalPadding: Nexa.Theme.spacingSm
                        Layout.alignment: Qt.AlignVCenter
                        onClicked: root.disconnectCurrent()
                    }
                }
            }

            // ====================================================
            // INLINE PASSWORD EXPANDER CARD
            // ====================================================
            NexaUI.NexaCard {
                id: passwordCard
                visible: root.selectedNetwork !== null && root.wifiEnabled
                Layout.fillWidth: true
                padding: Nexa.Theme.spacingMd
                selected: true
                implicitHeight: passwordColumn.implicitHeight + padding * 2

                ColumnLayout {
                    id: passwordColumn
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    spacing: Nexa.Theme.spacingSm

                    // Title & Security Info
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Nexa.Theme.spacingXs

                        Text {
                            text: root.selectedNetwork ? "Connect to " + root.selectedNetwork.name : ""
                            color: Nexa.Theme.text
                            font.family: Nexa.Theme.fontFamily
                            font.pixelSize: Nexa.Theme.fontSizeSm
                            font.weight: Nexa.Theme.fontWeightDemiBold
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Text {
                            text: "󰌾 Secured"
                            color: Nexa.Theme.primary
                            font.family: Nexa.Theme.fontFamily
                            font.pixelSize: Nexa.Theme.fontSize2Xs
                            font.weight: Nexa.Theme.fontWeightMedium
                        }
                    }

                    // Password Input Container
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: Nexa.Theme.controlHeightMd
                        radius: Nexa.Theme.radiusSm
                        color: Nexa.Theme.inputBackground
                        border.width: Nexa.Theme.borderThin
                        border.color: root.connectError !== "" ? Nexa.Theme.error
                                    : passwordInputField.activeFocus ? Nexa.Theme.focusBorder
                                    : Nexa.Theme.border

                        Behavior on border.color {
                            ColorAnimation { duration: Nexa.Theme.animationFast }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Nexa.Theme.spacingSm
                            anchors.rightMargin: Nexa.Theme.spacingXs
                            spacing: Nexa.Theme.spacingXs

                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                TextInput {
                                    id: passwordInputField
                                    anchors.fill: parent
                                    verticalAlignment: TextInput.AlignVCenter
                                    text: root.password
                                    color: Nexa.Theme.text
                                    echoMode: root.showPassword ? TextInput.Normal : TextInput.Password
                                    enabled: !root.connecting
                                    selectByMouse: true
                                    focus: true
                                    font.family: Nexa.Theme.fontFamily
                                    font.pixelSize: Nexa.Theme.fontSizeXs

                                    onTextChanged: {
                                        root.password = text
                                        if (text.length > 0 && root.connectError !== "")
                                            root.connectError = ""
                                    }

                                    Keys.onReturnPressed: {
                                        if (root.password.length > 0 && !root.connecting)
                                            root.connectSelected()
                                    }

                                    Keys.onEscapePressed: {
                                        root.cancelConnect()
                                    }
                                }

                                Text {
                                    visible: passwordInputField.text.length === 0 && !passwordInputField.activeFocus
                                    anchors.verticalCenter: parent.verticalCenter
                                    enabled: false
                                    text: "Enter password"
                                    color: Nexa.Theme.mutedText
                                    font.family: Nexa.Theme.fontFamily
                                    font.pixelSize: Nexa.Theme.fontSizeXs
                                }
                            }

                            // Show / Hide Password Icon
                            NexaUI.NexaIconButton {
                                icon: root.showPassword ? "󰛐" : "󰈈"
                                iconSize: Nexa.Theme.iconSm
                                implicitWidth: Nexa.Theme.controlHeightSm
                                implicitHeight: Nexa.Theme.controlHeightSm
                                onClicked: root.showPassword = !root.showPassword
                            }
                        }
                    }

                    // Action Buttons Row
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Nexa.Theme.spacingSm

                        Item { Layout.fillWidth: true }

                        NexaUI.NexaButton {
                            text: "Cancel"
                            textSize: Nexa.Theme.fontSizeXs
                            interactive: !root.connecting
                            onClicked: root.cancelConnect()
                        }

                        NexaUI.NexaButton {
                            text: root.connecting ? "Connecting…" : "Connect"
                            textSize: Nexa.Theme.fontSizeXs
                            selected: true
                            interactive: root.password.length > 0 && !root.connecting
                            onClicked: root.connectSelected()
                        }
                    }

                    // Error Message
                    Text {
                        visible: root.connectError !== ""
                        Layout.fillWidth: true
                        text: root.connectError
                        color: Nexa.Theme.error
                        font.family: Nexa.Theme.fontFamily
                        font.pixelSize: Nexa.Theme.fontSize2Xs
                        font.weight: Nexa.Theme.fontWeightMedium
                        wrapMode: Text.WordWrap
                    }
                }
            }

            // ====================================================
            // AVAILABLE NETWORKS LIST SECTION
            // ====================================================
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                implicitHeight: Math.min(320, Math.max(100, listInnerColumn.implicitHeight + Nexa.Theme.spacingSm * 2))
                radius: Nexa.Theme.radiusMd
                color: Nexa.Theme.surfaceContainer
                border.width: Nexa.Theme.borderThin
                border.color: Nexa.Theme.border

                ColumnLayout {
                    id: listInnerColumn
                    anchors.fill: parent
                    anchors.margins: Nexa.Theme.spacingSm
                    spacing: Nexa.Theme.spacingSm

                    // Section Title Row
                    RowLayout {
                        visible: root.wifiEnabled && root.availableList.length > 0
                        Layout.fillWidth: true

                        Text {
                            text: "Available Networks"
                            color: Nexa.Theme.mutedText
                            font.family: Nexa.Theme.fontFamily
                            font.pixelSize: Nexa.Theme.fontSize2Xs
                            font.weight: Nexa.Theme.fontWeightDemiBold
                        }

                        Item { Layout.fillWidth: true }

                        // Network Count Badge
                        Rectangle {
                            implicitWidth: countText.implicitWidth + Nexa.Theme.spacingSm
                            implicitHeight: 18
                            radius: 9
                            color: Nexa.Theme.surfaceContainerHighest

                            Text {
                                id: countText
                                anchors.centerIn: parent
                                text: root.availableList.length.toString()
                                color: Nexa.Theme.mutedText
                                font.family: Nexa.Theme.fontFamily
                                font.pixelSize: Nexa.Theme.fontSize2Xs
                                font.weight: Nexa.Theme.fontWeightMedium
                            }
                        }
                    }

                    // Scrollable List
                    ListView {
                        id: networkListView
                        visible: root.wifiEnabled && root.availableList.length > 0
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        implicitHeight: Math.min(260, Math.max(50, contentHeight))
                        clip: true
                        spacing: Nexa.Theme.spacingXs
                        model: root.availableList

                        flickDeceleration: Nexa.Theme.flickDeceleration
                        maximumFlickVelocity: Nexa.Theme.flickVelocityMax
                        pixelAligned: true
                        boundsBehavior: Flickable.StopAtBounds
                        reuseItems: true

                        // Sleek discreet floating scrollbar
                        ScrollBar.vertical: ScrollBar {
                            id: wifiScrollBar
                            policy: ScrollBar.AsNeeded
                            width: 4
                            anchors.right: parent.right
                            anchors.rightMargin: 1
                            visible: size < 1.0

                            contentItem: Rectangle {
                                implicitWidth: 3
                                radius: 1.5
                                color: wifiScrollBar.hovered ? Nexa.Theme.primary : Nexa.Theme.mutedText
                                opacity: (wifiScrollBar.active || wifiScrollBar.hovered) ? 0.6 : 0.0

                                Behavior on opacity {
                                    NumberAnimation { duration: Nexa.Theme.animationNormal }
                                }
                                Behavior on color {
                                    ColorAnimation { duration: Nexa.Theme.animationFast }
                                }
                            }

                            background: null
                        }

                        delegate: Rectangle {
                            id: networkItem
                            required property var modelData

                            width: networkListView.width - (networkListView.contentHeight > networkListView.height ? (Nexa.Theme.spacingSm + 4) : 0)
                            height: 48
                            radius: Nexa.Theme.radiusSm

                            Behavior on width {
                                NumberAnimation { duration: Nexa.Theme.animationFast }
                            }

                            readonly property bool isConnectingThis:
                                root.connectingNetwork === networkItem.modelData

                            color: itemMouse.pressed ? Nexa.Theme.pressed
                                 : itemMouse.containsMouse ? Nexa.Theme.hover
                                 : Nexa.Theme.surfaceContainerHigh

                            border.width: Nexa.Theme.borderThin
                            border.color: isConnectingThis ? Nexa.Theme.primary
                                        : itemMouse.containsMouse ? Nexa.Theme.borderStrong
                                        : Nexa.Theme.border

                            scale: itemMouse.pressed ? 0.985 : 1.0

                            Behavior on color {
                                ColorAnimation {
                                    duration: Nexa.Theme.motionInteraction
                                    easing.bezierCurve: Nexa.Theme.easingFluidCurve
                                }
                            }

                            Behavior on border.color {
                                ColorAnimation {
                                    duration: Nexa.Theme.motionInteraction
                                    easing.bezierCurve: Nexa.Theme.easingFluidCurve
                                }
                            }

                            Behavior on scale {
                                NumberAnimation {
                                    duration: Nexa.Theme.motionInteraction
                                    easing.type: Nexa.Theme.easingStandard
                                    easing.bezierCurve: Nexa.Theme.easingFluidCurve
                                }
                            }

                            // Card Click Handler
                            MouseArea {
                                id: itemMouse
                                anchors.fill: parent
                                z: 0
                                enabled: !root.connecting
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.chooseNetwork(networkItem.modelData)
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: Nexa.Theme.spacingSm
                                anchors.rightMargin: Nexa.Theme.spacingSm
                                z: 1
                                spacing: Nexa.Theme.spacingSm

                                // Signal Strength Icon
                                Text {
                                    text: root.signalIcon(networkItem.modelData)
                                    color: networkItem.isConnectingThis ? Nexa.Theme.primary
                                         : root.signalPercent(networkItem.modelData) >= 50 ? Nexa.Theme.primary
                                         : root.signalPercent(networkItem.modelData) >= 25 ? Nexa.Theme.text
                                         : Nexa.Theme.mutedText
                                    font.family: Nexa.Theme.iconFontFamily
                                    font.pixelSize: Nexa.Theme.iconMd
                                }

                                // Network SSID
                                Text {
                                    Layout.fillWidth: true
                                    text: networkItem.modelData.name
                                    elide: Text.ElideRight
                                    color: Nexa.Theme.text
                                    font.family: Nexa.Theme.fontFamily
                                    font.pixelSize: Nexa.Theme.fontSizeXs
                                    font.weight: Nexa.Theme.fontWeightMedium
                                }

                                // Connecting Spinner
                                Text {
                                    visible: networkItem.isConnectingThis
                                    text: "󰑐"
                                    color: Nexa.Theme.primary
                                    font.family: Nexa.Theme.iconFontFamily
                                    font.pixelSize: Nexa.Theme.iconSm

                                    RotationAnimator on rotation {
                                        running: root.visible && networkItem.isConnectingThis
                                        from: 0
                                        to: 360
                                        duration: 900
                                        loops: Animation.Infinite
                                    }
                                }

                                // "Saved" Known Badge
                                Rectangle {
                                    visible: networkItem.modelData.known && !networkItem.isConnectingThis
                                    implicitWidth: savedBadgeText.implicitWidth + 8
                                    implicitHeight: 18
                                    radius: 9
                                    color: Nexa.Theme.surfaceContainerHighest

                                    Text {
                                        id: savedBadgeText
                                        anchors.centerIn: parent
                                        text: "Saved"
                                        color: Nexa.Theme.mutedText
                                        font.family: Nexa.Theme.fontFamily
                                        font.pixelSize: Nexa.Theme.fontSize2Xs
                                    }
                                }

                                // Security Lock Icon
                                Text {
                                    visible: root.isSecured(networkItem.modelData)
                                    text: "󰌾"
                                    color: Nexa.Theme.mutedText
                                    font.family: Nexa.Theme.iconFontFamily
                                    font.pixelSize: Nexa.Theme.iconXs
                                }

                                // Signal Percentage
                                Text {
                                    text: root.signalPercent(networkItem.modelData) + "%"
                                    color: Nexa.Theme.mutedText
                                    font.family: Nexa.Theme.fontFamily
                                    font.pixelSize: Nexa.Theme.fontSizeXs
                                }

                                // Forget Saved Network Icon Button
                                NexaUI.NexaIconButton {
                                    visible: networkItem.modelData.known
                                    icon: "󰆴"
                                    iconSize: Nexa.Theme.iconSm
                                    implicitWidth: Nexa.Theme.controlHeightSm
                                    implicitHeight: Nexa.Theme.controlHeightSm
                                    iconColor: hovered ? Nexa.Theme.error : Nexa.Theme.mutedText
                                    onClicked: root.forgetNetwork(networkItem.modelData)
                                }
                            }
                        }
                    }

                    // ============================================
                    // EMPTY / DISABLED STATES
                    // ============================================

                    // State 1: Wi-Fi Disabled
                    ColumnLayout {
                        visible: !root.wifiEnabled
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.alignment: Qt.AlignCenter
                        spacing: Nexa.Theme.spacingMd

                        Item { Layout.fillHeight: true }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "󰤭"
                            color: Nexa.Theme.mutedText
                            font.family: Nexa.Theme.iconFontFamily
                            font.pixelSize: 48
                        }

                        ColumnLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 4

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "Wi-Fi is turned off"
                                color: Nexa.Theme.text
                                font.family: Nexa.Theme.fontFamily
                                font.pixelSize: Nexa.Theme.fontSizeSm
                                font.weight: Nexa.Theme.fontWeightDemiBold
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "Turn on Wi-Fi to find and connect to networks"
                                color: Nexa.Theme.mutedText
                                font.family: Nexa.Theme.fontFamily
                                font.pixelSize: Nexa.Theme.fontSizeXs
                            }
                        }

                        NexaUI.NexaButton {
                            Layout.alignment: Qt.AlignHCenter
                            text: "Turn On Wi-Fi"
                            icon: "󰤨"
                            selected: true
                            onClicked: root.toggleWifi()
                        }

                        Item { Layout.fillHeight: true }
                    }

                    // State 2: Wi-Fi Enabled, Scanning or 0 Networks Found
                    ColumnLayout {
                        visible: root.wifiEnabled && root.availableList.length === 0
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.alignment: Qt.AlignCenter
                        spacing: Nexa.Theme.spacingSm

                        Item { Layout.fillHeight: true }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: root.isScanning ? "󰑐" : "󰤭"
                            color: root.isScanning ? Nexa.Theme.primary : Nexa.Theme.mutedText
                            font.family: Nexa.Theme.iconFontFamily
                            font.pixelSize: 32

                            RotationAnimator on rotation {
                                running: root.isScanning && root.visible
                                from: 0
                                to: 360
                                duration: 1200
                                loops: Animation.Infinite
                            }
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: root.isScanning ? "Searching for networks…"
                                : (root.connectedNetwork ? "No other networks found" : "No networks found")
                            color: Nexa.Theme.text
                            font.family: Nexa.Theme.fontFamily
                            font.pixelSize: Nexa.Theme.fontSizeSm
                            font.weight: Nexa.Theme.fontWeightMedium
                        }

                        Text {
                            visible: !root.isScanning
                            Layout.alignment: Qt.AlignHCenter
                            text: "Click refresh to scan for nearby Wi-Fi"
                            color: Nexa.Theme.mutedText
                            font.family: Nexa.Theme.fontFamily
                            font.pixelSize: Nexa.Theme.fontSizeXs
                        }

                        NexaUI.NexaButton {
                            visible: !root.isScanning
                            Layout.alignment: Qt.AlignHCenter
                            text: "Rescan"
                            icon: "󰑐"
                            onClicked: root.refreshNetworks()
                        }

                        Item { Layout.fillHeight: true }
                    }
                }
            }
        }
    }
}
