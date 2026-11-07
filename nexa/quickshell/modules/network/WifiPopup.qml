import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Quickshell
import Quickshell.Io
import Quickshell.Networking

import "../../NewNexaUI" as NexaUI


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

    implicitWidth: 452
    implicitHeight: Math.min(572, Math.max(332, contentColumn.implicitHeight + NexaUI.NexaTokens.spacingMd * 2 + 32))

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

    // GPU-Accelerated Nexa Drop Shadow for WiFi Popup
    NexaUI.NexaShadow {
        id: panelShadow
        targetItem: panelBackground
        elevation: 1
        spread: 0.08
    }

    Rectangle {
        id: panelBackground
        anchors.fill: parent
        anchors.margins: 16

        radius: NexaUI.NexaTokens.radiusLg
        color: NexaUI.NexaColors.surfaceContainer
        border.width: NexaUI.NexaTokens.borderThin
        border.color: NexaUI.NexaColors.borderStrong

        NexaUI.NexaShaderSubstrate {
            anchors.fill: parent
            radius: parent.radius
        }

        // Apple / Tactile 4-stop Depth Micro-Gradient
        Rectangle {
            anchors.fill: parent
            radius: panelBackground.radius
            antialiasing: panelBackground.radius > 0
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
            width: panelBackground.radius > 0 ? Math.max(0, parent.width - panelBackground.radius * 1.6) : parent.width
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

        opacity: root.visible ? 1.0 : 0.0
        scale: root.visible ? 1.0 : 0.96
        transformOrigin: Item.TopRight

        Behavior on opacity {
            NumberAnimation {
                duration: NexaUI.NexaMotion.durationNormal
                easing.type: NexaUI.NexaMotion.easingStandard
            }
        }

        Behavior on scale {
            enabled: NexaUI.NexaMotion.enabled
            SpringAnimation {
                spring: NexaUI.NexaMotion.useSpring("popups") ? NexaUI.NexaMotion.springStiffness : 8.0
                damping: NexaUI.NexaMotion.useSpring("popups") ? NexaUI.NexaMotion.springDamping : 1.0
                mass: NexaUI.NexaMotion.springMass
                epsilon: 0.002
            }
        }

        ColumnLayout {
            id: contentColumn
            anchors.fill: parent
            anchors.margins: NexaUI.NexaTokens.spacingMd
            spacing: NexaUI.NexaTokens.spacingSm

            // ====================================================
            // HEADER BAR
            // ====================================================
            RowLayout {
                Layout.fillWidth: true
                spacing: NexaUI.NexaTokens.spacingSm

                // Status Icon & Titles
                RowLayout {
                    spacing: NexaUI.NexaTokens.spacingSm

                    Text {
                        text: "󰤨"
                        color: root.wifiEnabled ? NexaUI.NexaColors.primary : NexaUI.NexaColors.mutedText
                        font.family: NexaUI.NexaTypography.familyIcon
                        font.pixelSize: NexaUI.NexaTypography.sizeMd

                        Behavior on color {
                            ColorAnimation {
                                duration: NexaUI.NexaMotion.durationFast
                            }
                        }
                    }

                    ColumnLayout {
                        spacing: 1

                        Text {
                            text: "Wi-Fi"
                            color: NexaUI.NexaColors.text
                            font.family: NexaUI.NexaTypography.familyBody
                            font.pixelSize: NexaUI.NexaTypography.sizeSm
                            font.weight: NexaUI.NexaTypography.weightSemiBold
                        }

                        Text {
                            text: {
                                if (!root.wifiEnabled) return "Disabled"
                                if (root.connectedNetwork) return "Connected to " + root.connectedNetwork.name
                                if (root.isScanning) return "Scanning nearby…"
                                return root.availableList.length + " networks found"
                            }
                            color: NexaUI.NexaColors.mutedText
                            font.family: NexaUI.NexaTypography.familyBody
                            font.pixelSize: NexaUI.NexaTypography.size2Xs
                            elide: Text.ElideRight
                            Layout.maximumWidth: 220
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                // Rescan Button
                NexaUI.NexaButton {
                    variant: "icon"
                    icon: "󰑐"
                    iconSize: NexaUI.NexaTypography.sizeSm
                    implicitWidth: NexaUI.NexaTokens.controlHeightMd
                    implicitHeight: NexaUI.NexaTokens.controlHeightMd
                    interactive: root.wifiEnabled && !networkProcess.running
                    onClicked: root.refreshNetworks()
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
                color: NexaUI.NexaColors.error
                font.family: NexaUI.NexaTypography.familyBody
                font.pixelSize: NexaUI.NexaTypography.size2Xs
                font.weight: NexaUI.NexaTypography.weightMedium
            }

            // ====================================================
            // ACTIVE CONNECTION CARD (Single Unified Card)
            // ====================================================
            NexaUI.NexaCard {
                id: activeNetworkCard
                visible: root.connectedNetwork !== null && root.wifiEnabled
                Layout.fillWidth: true
                padding: NexaUI.NexaTokens.spacingSm
                implicitHeight: Math.max(52, activeRow.implicitHeight + padding * 2)
                selected: true

                RowLayout {
                    id: activeRow
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: activeNetworkCard.padding
                    anchors.rightMargin: activeNetworkCard.padding
                    spacing: NexaUI.NexaTokens.spacingSm

                    // Prominent Signal Glyph
                    Text {
                        text: root.connectedNetwork ? root.signalIcon(root.connectedNetwork) : "󰤭"
                        color: NexaUI.NexaColors.primary
                        font.family: NexaUI.NexaTypography.familyIcon
                        font.pixelSize: NexaUI.NexaTypography.sizeLg
                        Layout.alignment: Qt.AlignVCenter
                    }

                    // SSID & Details
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 2

                        Text {
                            text: root.connectedNetwork ? root.connectedNetwork.name : ""
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
                                text: "Connected · " + root.signalPercent(root.connectedNetwork) + "%"
                                color: NexaUI.NexaColors.mutedText
                                font.family: NexaUI.NexaTypography.familyBody
                                font.pixelSize: NexaUI.NexaTypography.sizeXs
                                Layout.alignment: Qt.AlignVCenter
                            }
                        }
                    }

                    // Forget Active Network Button
                    NexaUI.NexaButton {
                        variant: "icon"
                        icon: "󰆴"
                        iconSize: NexaUI.NexaTypography.sizeSm
                        implicitWidth: NexaUI.NexaTokens.controlHeightSm
                        implicitHeight: NexaUI.NexaTokens.controlHeightSm
                        Layout.alignment: Qt.AlignVCenter
                        onClicked: root.forgetNetwork(root.connectedNetwork)
                    }

                    // Disconnect Active Network Button
                    NexaUI.NexaButton {
                        variant: "tonal"
                        text: "Disconnect"
                        implicitHeight: NexaUI.NexaTokens.controlHeightSm
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
                padding: NexaUI.NexaTokens.spacingMd
                selected: true
                implicitHeight: passwordColumn.implicitHeight + padding * 2

                ColumnLayout {
                    id: passwordColumn
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    spacing: NexaUI.NexaTokens.spacingSm

                    // Title & Security Info
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: NexaUI.NexaTokens.spacingXs

                        Text {
                            text: root.selectedNetwork ? "Connect to " + root.selectedNetwork.name : ""
                            color: NexaUI.NexaColors.text
                            font.family: NexaUI.NexaTypography.familyBody
                            font.pixelSize: NexaUI.NexaTypography.sizeSm
                            font.weight: NexaUI.NexaTypography.weightSemiBold
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Text {
                            text: "󰌾 Secured"
                            color: NexaUI.NexaColors.primary
                            font.family: NexaUI.NexaTypography.familyBody
                            font.pixelSize: NexaUI.NexaTypography.size2Xs
                            font.weight: NexaUI.NexaTypography.weightMedium
                        }
                    }

                    // Password Input Container
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: NexaUI.NexaTokens.controlHeightMd
                        radius: NexaUI.NexaTokens.radiusSm
                        color: NexaUI.NexaColors.surfaceContainerHigh
                        border.width: NexaUI.NexaTokens.borderThin
                        border.color: root.connectError !== "" ? NexaUI.NexaColors.error
                                    : passwordInputField.activeFocus ? NexaUI.NexaColors.primary
                                    : NexaUI.NexaColors.border

                        Behavior on border.color {
                            ColorAnimation { duration: NexaUI.NexaMotion.durationFast }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: NexaUI.NexaTokens.spacingSm
                            anchors.rightMargin: NexaUI.NexaTokens.spacingXs
                            spacing: NexaUI.NexaTokens.spacingXs

                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                TextInput {
                                    id: passwordInputField
                                    anchors.fill: parent
                                    verticalAlignment: TextInput.AlignVCenter
                                    text: root.password
                                    color: NexaUI.NexaColors.text
                                    echoMode: root.showPassword ? TextInput.Normal : TextInput.Password
                                    enabled: !root.connecting
                                    selectByMouse: true
                                    focus: true
                                    font.family: NexaUI.NexaTypography.familyBody
                                    font.pixelSize: NexaUI.NexaTypography.sizeXs

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
                                    color: NexaUI.NexaColors.mutedText
                                    font.family: NexaUI.NexaTypography.familyBody
                                    font.pixelSize: NexaUI.NexaTypography.sizeXs
                                }
                            }

                            // Show / Hide Password Icon
                            NexaUI.NexaButton {
                                variant: "icon"
                                icon: root.showPassword ? "󰛐" : "󰈈"
                                iconSize: NexaUI.NexaTypography.sizeSm
                                implicitWidth: NexaUI.NexaTokens.controlHeightSm
                                implicitHeight: NexaUI.NexaTokens.controlHeightSm
                                Layout.alignment: Qt.AlignVCenter
                                onClicked: root.showPassword = !root.showPassword
                            }
                        }
                    }

                    // Action Buttons Row
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: NexaUI.NexaTokens.spacingSm

                        Item { Layout.fillWidth: true }

                        NexaUI.NexaButton {
                            variant: "tonal"
                            text: "Cancel"
                            implicitHeight: NexaUI.NexaTokens.controlHeightSm
                            interactive: !root.connecting
                            onClicked: root.cancelConnect()
                        }

                        NexaUI.NexaButton {
                            variant: "filled"
                            text: root.connecting ? "Connecting…" : "Connect"
                            implicitHeight: NexaUI.NexaTokens.controlHeightSm
                            interactive: root.password.length > 0 && !root.connecting
                            onClicked: root.connectSelected()
                        }
                    }

                    // Error Message
                    Text {
                        visible: root.connectError !== ""
                        Layout.fillWidth: true
                        text: root.connectError
                        color: NexaUI.NexaColors.error
                        font.family: NexaUI.NexaTypography.familyBody
                        font.pixelSize: NexaUI.NexaTypography.size2Xs
                        font.weight: NexaUI.NexaTypography.weightMedium
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
                implicitHeight: Math.min(320, Math.max(100, listInnerColumn.implicitHeight + NexaUI.NexaTokens.spacingSm * 2))
                radius: NexaUI.NexaTokens.radiusMd
                color: NexaUI.NexaColors.surfaceContainer
                border.width: NexaUI.NexaTokens.borderThin
                border.color: NexaUI.NexaColors.border

                ColumnLayout {
                    id: listInnerColumn
                    anchors.fill: parent
                    anchors.margins: NexaUI.NexaTokens.spacingSm
                    spacing: NexaUI.NexaTokens.spacingSm

                    // Section Title Row
                    RowLayout {
                        visible: root.wifiEnabled && root.availableList.length > 0
                        Layout.fillWidth: true

                        Text {
                            text: "Available Networks"
                            color: NexaUI.NexaColors.mutedText
                            font.family: NexaUI.NexaTypography.familyBody
                            font.pixelSize: NexaUI.NexaTypography.size2Xs
                            font.weight: NexaUI.NexaTypography.weightSemiBold
                        }

                        Item { Layout.fillWidth: true }

                        // Network Count Badge
                        Rectangle {
                            implicitWidth: countText.implicitWidth + NexaUI.NexaTokens.spacingSm
                            implicitHeight: 18
                            radius: NexaUI.NexaTokens.radiusPill
                            color: NexaUI.NexaColors.surfaceContainerHighest

                            Text {
                                id: countText
                                anchors.centerIn: parent
                                text: root.availableList.length.toString()
                                color: NexaUI.NexaColors.mutedText
                                font.family: NexaUI.NexaTypography.familyBody
                                font.pixelSize: NexaUI.NexaTypography.size2Xs
                                font.weight: NexaUI.NexaTypography.weightMedium
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
                        spacing: NexaUI.NexaTokens.spacingXs
                        model: root.availableList

                        flickDeceleration: 1750
                        maximumFlickVelocity: 2500
                        pixelAligned: true
                        boundsBehavior: Flickable.StopAtBounds
                        reuseItems: true

                        NexaUI.NexaSmoothScroll {}

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
                                color: wifiScrollBar.hovered ? NexaUI.NexaColors.primary : NexaUI.NexaColors.mutedText
                                opacity: (wifiScrollBar.active || wifiScrollBar.hovered) ? 0.6 : 0.0

                                Behavior on opacity {
                                    NumberAnimation { duration: NexaUI.NexaMotion.durationNormal }
                                }
                                Behavior on color {
                                    ColorAnimation { duration: NexaUI.NexaMotion.durationFast }
                                }
                            }

                            background: null
                        }

                        delegate: Rectangle {
                            id: networkItem
                            required property var modelData

                            width: networkListView.width - (networkListView.contentHeight > networkListView.height ? (NexaUI.NexaTokens.spacingSm + 4) : 0)
                            height: 48
                            radius: NexaUI.NexaTokens.radiusSm

                            Behavior on width {
                                NumberAnimation { duration: NexaUI.NexaMotion.durationFast }
                            }

                            readonly property bool isConnectingThis:
                                root.connectingNetwork === networkItem.modelData

                            color: itemMouse.pressed ? NexaUI.NexaColors.surfaceContainerHighest
                                 : itemMouse.containsMouse ? NexaUI.NexaColors.surfaceContainerHigh
                                 : NexaUI.NexaColors.surfaceContainerLow

                            border.width: NexaUI.NexaTokens.borderThin
                            border.color: isConnectingThis ? NexaUI.NexaColors.primary
                                        : itemMouse.containsMouse ? NexaUI.NexaColors.borderStrong
                                        : NexaUI.NexaColors.border

                            scale: itemMouse.pressed ? 0.985 : 1.0

                            Behavior on color {
                                ColorAnimation { duration: 120 }
                            }

                            Behavior on border.color {
                                ColorAnimation { duration: 120 }
                            }

                            Behavior on scale {
                                NumberAnimation { duration: 120 }
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
                                anchors.leftMargin: NexaUI.NexaTokens.spacingSm
                                anchors.rightMargin: NexaUI.NexaTokens.spacingSm
                                z: 1
                                spacing: NexaUI.NexaTokens.spacingSm

                                // Signal Strength Icon
                                Text {
                                    text: root.signalIcon(networkItem.modelData)
                                    color: networkItem.isConnectingThis ? NexaUI.NexaColors.primary
                                         : root.signalPercent(networkItem.modelData) >= 50 ? NexaUI.NexaColors.primary
                                         : root.signalPercent(networkItem.modelData) >= 25 ? NexaUI.NexaColors.text
                                         : NexaUI.NexaColors.mutedText
                                    font.family: NexaUI.NexaTypography.familyIcon
                                    font.pixelSize: NexaUI.NexaTypography.sizeMd
                                }

                                // Network SSID
                                Text {
                                    Layout.fillWidth: true
                                    text: networkItem.modelData.name
                                    elide: Text.ElideRight
                                    color: NexaUI.NexaColors.text
                                    font.family: NexaUI.NexaTypography.familyBody
                                    font.pixelSize: NexaUI.NexaTypography.sizeXs
                                    font.weight: NexaUI.NexaTypography.weightMedium
                                }

                                // Connecting Spinner
                                Text {
                                    visible: networkItem.isConnectingThis
                                    text: "󰑐"
                                    color: NexaUI.NexaColors.primary
                                    font.family: NexaUI.NexaTypography.familyIcon
                                    font.pixelSize: NexaUI.NexaTypography.sizeSm

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
                                    radius: NexaUI.NexaTokens.radiusPill
                                    color: NexaUI.NexaColors.surfaceContainerHighest

                                    Text {
                                        id: savedBadgeText
                                        anchors.centerIn: parent
                                        text: "Saved"
                                        color: NexaUI.NexaColors.mutedText
                                        font.family: NexaUI.NexaTypography.familyBody
                                        font.pixelSize: NexaUI.NexaTypography.size2Xs
                                    }
                                }

                                // Security Lock Icon
                                Text {
                                    visible: root.isSecured(networkItem.modelData)
                                    text: "󰌾"
                                    color: NexaUI.NexaColors.mutedText
                                    font.family: NexaUI.NexaTypography.familyIcon
                                    font.pixelSize: NexaUI.NexaTypography.sizeSm
                                }

                                // Signal Percentage
                                Text {
                                    text: root.signalPercent(networkItem.modelData) + "%"
                                    color: NexaUI.NexaColors.mutedText
                                    font.family: NexaUI.NexaTypography.familyBody
                                    font.pixelSize: NexaUI.NexaTypography.sizeXs
                                }

                                // Forget Saved Network Icon Button
                                NexaUI.NexaButton {
                                    variant: "icon"
                                    visible: networkItem.modelData.known
                                    icon: "󰆴"
                                    iconSize: NexaUI.NexaTypography.sizeSm
                                    implicitWidth: NexaUI.NexaTokens.controlHeightSm
                                    implicitHeight: NexaUI.NexaTokens.controlHeightSm
                                    Layout.alignment: Qt.AlignVCenter
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
                        spacing: NexaUI.NexaTokens.spacingMd

                        Item { Layout.fillHeight: true }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "󰤭"
                            color: NexaUI.NexaColors.mutedText
                            font.family: NexaUI.NexaTypography.familyIcon
                            font.pixelSize: 48
                        }

                        ColumnLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 4

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "Wi-Fi is turned off"
                                color: NexaUI.NexaColors.text
                                font.family: NexaUI.NexaTypography.familyBody
                                font.pixelSize: NexaUI.NexaTypography.sizeSm
                                font.weight: NexaUI.NexaTypography.weightSemiBold
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "Turn on Wi-Fi to find and connect to networks"
                                color: NexaUI.NexaColors.mutedText
                                font.family: NexaUI.NexaTypography.familyBody
                                font.pixelSize: NexaUI.NexaTypography.sizeXs
                            }
                        }

                        NexaUI.NexaButton {
                            Layout.alignment: Qt.AlignHCenter
                            text: "Turn On Wi-Fi"
                            icon: "󰤨"
                            variant: "filled"
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
                        spacing: NexaUI.NexaTokens.spacingSm

                        Item { Layout.fillHeight: true }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: root.isScanning ? "󰑐" : "󰤭"
                            color: root.isScanning ? NexaUI.NexaColors.primary : NexaUI.NexaColors.mutedText
                            font.family: NexaUI.NexaTypography.familyIcon
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
                            color: NexaUI.NexaColors.text
                            font.family: NexaUI.NexaTypography.familyBody
                            font.pixelSize: NexaUI.NexaTypography.sizeSm
                            font.weight: NexaUI.NexaTypography.weightMedium
                        }

                        Text {
                            visible: !root.isScanning
                            Layout.alignment: Qt.AlignHCenter
                            text: "Click refresh to scan for nearby Wi-Fi"
                            color: NexaUI.NexaColors.mutedText
                            font.family: NexaUI.NexaTypography.familyBody
                            font.pixelSize: NexaUI.NexaTypography.sizeXs
                        }

                        NexaUI.NexaButton {
                            visible: !root.isScanning
                            Layout.alignment: Qt.AlignHCenter
                            text: "Rescan"
                            icon: "󰑐"
                            variant: "filled"
                            onClicked: root.refreshNetworks()
                        }

                        Item { Layout.fillHeight: true }
                    }
                }
            }
        }
    }
}
