import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Quickshell
import Quickshell.Io
import Quickshell.Networking

import "../../theme" as Nexa


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
    // QUICKShell NETWORK STATE
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


    // ============================================================
    // WINDOW
    // ============================================================

    implicitWidth: 430
    implicitHeight: 610

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
            ? root.anchorItem.height
              + Nexa.Theme.spacingSm
            : 0

        rect.width: 1
        rect.height: 1

        edges:
            Edges.Top
            | Edges.Left

        gravity:
            Edges.Bottom
            | Edges.Left
    }


    // ============================================================
    // RUST PROCESS
    //
    // Rust remains responsible for:
    // - toggle
    // - refresh
    // - disconnect
    //
    // Password connection is handled by Quickshell so failures
    // can be detected correctly.
    // ============================================================

    Process {
        id: networkProcess

        onStarted: {
            root.actionError = ""
        }

        onExited: function(exitCode, exitStatus) {

            if (exitCode !== 0) {

                root.actionError =
                    "Network action failed"

                root.pendingAction = ""

                return
            }

            root.actionError = ""
            root.pendingAction = ""

            refreshDelay.restart()
        }
    }


    // ============================================================
    // REFRESH
    // ============================================================

    Timer {
        id: refreshDelay

        interval: 400
        repeat: false

        onTriggered: {

            if (!root.device)
                return

            root.device.scannerEnabled = false
            scannerRestart.restart()
        }
    }


    Timer {
        id: scannerRestart

        interval: 120
        repeat: false

        onTriggered: {

            if (root.device && root.visible)
                root.device.scannerEnabled = true
        }
    }


    Timer {
        id: passwordFocusTimer

        interval: 100
        repeat: false

        onTriggered: {

            if (
                root.selectedNetwork
                && passwordInput
            ) {
                passwordInput.forceActiveFocus()
            }
        }
    }


    // ============================================================
    // RUST COMMAND
    // ============================================================

    function runNetwork(args, action) {

        if (networkProcess.running)
            return

        root.pendingAction =
            action || ""

        networkProcess.exec(
            [root.nexad, "network"].concat(args)
        )
    }


    // ============================================================
    // HELPERS
    // ============================================================

    function signalPercent(network) {

        return network
            ? Math.round(
                network.signalStrength * 100
            )
            : 0
    }


    function signalIcon(network) {

        const strength =
            signalPercent(network)

        if (strength >= 75)
            return "󰤨"

        if (strength >= 50)
            return "󰤥"

        if (strength >= 25)
            return "󰤢"

        return "󰤟"
    }


    function isOpen(network) {

        return network
            && (
                network.security
                    === WifiSecurityType.Open

                || network.security
                    === WifiSecurityType.Owe
            )
    }


    function secured(network) {

        return network
            && !isOpen(network)
    }


    function connectionErrorText(reason) {

        if (
            reason
            === ConnectionFailReason.NoSecrets
        ) {
            return "Password required"
        }


        if (
            reason
            === ConnectionFailReason.WifiAuthTimeout
        ) {
            return "Incorrect password or authentication timed out"
        }


        if (
            reason
            === ConnectionFailReason.WifiClientFailed
        ) {
            return "Incorrect password or authentication failed"
        }


        if (
            reason
            === ConnectionFailReason.WifiNetworkLost
        ) {
            return "Network is no longer available"
        }


        if (
            reason
            === ConnectionFailReason.WifiClientDisconnected
        ) {
            return "Connection rejected or disconnected"
        }


        return "Unable to connect to network"
    }


    function isAuthenticationFailure(reason) {

        return (
            reason
                === ConnectionFailReason.NoSecrets

            || reason
                === ConnectionFailReason.WifiAuthTimeout

            || reason
                === ConnectionFailReason.WifiClientFailed

            || reason
                === ConnectionFailReason.WifiClientDisconnected
        )
    }


    // ============================================================
    // CONNECTION ACTIONS
    // ============================================================

    function chooseNetwork(network) {

        if (!network)
            return


        if (root.connecting)
            return


        root.connectError = ""


        // --------------------------------------------------------
        // ALREADY CONNECTED
        // --------------------------------------------------------

        if (network.connected)
            return


        // --------------------------------------------------------
        // KNOWN NETWORK
        //
        // First try NetworkManager's stored configuration.
        // If it fails because authentication is invalid, the
        // connectionFailed signal below will reopen the password UI.
        // --------------------------------------------------------

        if (network.known) {

            root.connecting = true
            root.connectingNetwork = network

            network.connect()

            return
        }


        // --------------------------------------------------------
        // OPEN NETWORK
        // --------------------------------------------------------

        if (root.isOpen(network)) {

            root.connecting = true
            root.connectingNetwork = network

            network.connect()

            return
        }


        // --------------------------------------------------------
        // NEW SECURED NETWORK
        // --------------------------------------------------------

        root.selectedNetwork = network
        root.password = ""
        root.showPassword = false

        passwordFocusTimer.restart()
    }


    function connectSelected() {

        if (!root.selectedNetwork)
            return


        if (root.password.length === 0)
            return


        if (root.connecting)
            return


        root.connectError = ""

        root.connectingNetwork =
            root.selectedNetwork

        root.connecting = true


        root.selectedNetwork.connectWithPsk(
            root.password
        )
    }


    function connectionSucceeded() {

        root.connecting = false

        root.connectingNetwork = null
        root.selectedNetwork = null

        root.password = ""
        root.connectError = ""
        root.showPassword = false

        refreshDelay.restart()
    }


    function connectionFailed(
        network,
        reason
    ) {

        if (!network)
            return


        root.connecting = false

        root.connectError =
            root.connectionErrorText(reason)


        /*
         * Authentication failure:
         *
         * NetworkManager may now consider the profile "known",
         * even though its credentials are unusable.
         *
         * Forget those settings immediately so clicking the
         * network again never silently retries the bad password.
         */
        if (
            root.isAuthenticationFailure(reason)
            && network.known
        ) {
            network.forget()
        }


        /*
         * For secured networks keep the password editor open.
         */
        if (root.secured(network)) {

            root.selectedNetwork = network

            /*
             * Clear the rejected password.
             * User can immediately type the corrected password.
             */
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

        if (!root.connectedNetwork)
            return

        root.connectedNetwork.disconnect()
    }


    function forgetNetwork(network) {

        if (!network)
            return


        if (network.connected)
            network.disconnect()


        network.forget()


        if (
            root.selectedNetwork
            && root.selectedNetwork.name
                === network.name
        ) {
            root.cancelConnect()
        }


        refreshDelay.restart()
    }


    function refreshNetworks() {

        runNetwork(
            [
                "wifi",
                "refresh"
            ],
            "refresh"
        )
    }


    function toggleWifi() {

        runNetwork(
            [
                "wifi",
                Networking.wifiEnabled
                    ? "off"
                    : "on"
            ],
            "toggle"
        )
    }


    // ============================================================
    // WATCH CURRENT CONNECTION ATTEMPT
    // ============================================================

    Connections {
        target:
            root.connectingNetwork

        ignoreUnknownSignals: true


        function onConnectionFailed(reason) {

            const failed =
                root.connectingNetwork

            root.connectionFailed(
                failed,
                reason
            )
        }


        function onConnectedChanged() {

            if (
                root.connectingNetwork
                && root.connectingNetwork.connected
            ) {
                root.connectionSucceeded()
            }
        }
    }


    // ============================================================
    // AVAILABLE NETWORKS
    // ============================================================

    ScriptModel {
        id: availableNetworks


        values:
            root.device
            ? [...root.device.networks.values]
                .filter(
                    network =>
                        !network.connected
                        && network.name !== ""
                )
                .sort(
                    (a, b) =>
                        b.signalStrength
                        - a.signalStrength
                )
            : []
    }


    // ============================================================
    // POPUP STATE
    // ============================================================

    onVisibleChanged: {

        if (root.device)
            root.device.scannerEnabled = visible


        if (!visible)
            root.cancelConnect()
    }


    onDeviceChanged: {

        if (
            root.device
            && root.visible
        ) {
            root.device.scannerEnabled = true
        }
    }


    // ============================================================
    // MAIN PANEL
    // ============================================================

    Rectangle {
        anchors.fill: parent

        radius:
            Nexa.Theme.radiusLg

        color:
            Nexa.Theme.panelBackground


        border {
            width:
                Nexa.Theme.borderThin

            color:
                Nexa.Theme.border
        }


        opacity:
            root.visible
            ? Nexa.Theme.opacityFull
            : Nexa.Theme.opacityHidden


        scale:
            root.visible
            ? Nexa.Theme.normalScale
            : 0.97


        transformOrigin:
            Item.TopRight


        Behavior on opacity {

            NumberAnimation {
                duration:
                    Nexa.Theme.animationFast

                easing.type:
                    Nexa.Theme.easingEnter
            }
        }


        Behavior on scale {

            NumberAnimation {
                duration:
                    Nexa.Theme.animationNormal

                easing.type:
                    Nexa.Theme.easingEnter
            }
        }


        ColumnLayout {
            anchors {
                fill: parent
                margins:
                    Nexa.Theme.spacingMd
            }

            spacing:
                Nexa.Theme.spacingSm


            // ====================================================
            // CONNECTED WIFI
            // ====================================================

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 82

                radius:
                    Nexa.Theme.radiusMd

                color:
                    Nexa.Theme.surfaceContainerHigh


                border {
                    width:
                        Nexa.Theme.borderThin

                    color:
                        root.connectedNetwork
                        ? Nexa.Theme.primary
                        : Nexa.Theme.border
                }


                Behavior on color {

                    ColorAnimation {
                        duration:
                            Nexa.Theme.animationFast
                    }
                }


                RowLayout {
                    anchors {
                        fill: parent
                        margins:
                            Nexa.Theme.spacingMd
                    }

                    spacing:
                        Nexa.Theme.spacingSm


                    Text {
                        text:
                            root.connectedNetwork
                            ? root.signalIcon(
                                root.connectedNetwork
                            )
                            : "󰤭"


                        color:
                            root.connectedNetwork
                            ? Nexa.Theme.primary
                            : Nexa.Theme.mutedText


                        font {
                            family:
                                Nexa.Theme.iconFontFamily

                            pixelSize:
                                Nexa.Theme.iconLg
                        }


                        scale:
                            root.connectedNetwork
                            ? 1.0
                            : 0.92


                        Behavior on scale {

                            NumberAnimation {
                                duration:
                                    Nexa.Theme.animationNormal

                                easing.type:
                                    Nexa.Theme.easingStandard
                            }
                        }
                    }


                    ColumnLayout {
                        Layout.fillWidth: true

                        spacing: 2


                        Text {
                            text:
                                root.connectedNetwork
                                ? root.connectedNetwork.name
                                : "No Wi-Fi connection"


                            color:
                                Nexa.Theme.text


                            font {
                                family:
                                    Nexa.Theme.fontFamily

                                pixelSize:
                                    Nexa.Theme.fontSizeSm

                                weight:
                                    Nexa.Theme.fontWeightDemiBold
                            }
                        }


                        Text {
                            text:
                                root.connectedNetwork
                                ? "Connected · "
                                  + root.signalPercent(
                                      root.connectedNetwork
                                  )
                                  + "%"

                                : root.wifiEnabled
                                    ? "Disconnected"
                                    : "Wi-Fi disabled"


                            color:
                                Nexa.Theme.mutedText


                            font {
                                family:
                                    Nexa.Theme.fontFamily

                                pixelSize:
                                    Nexa.Theme.fontSizeXs
                            }
                        }
                    }


                    Rectangle {
                        visible:
                            root.connectedNetwork !== null

                        implicitWidth:
                            Nexa.Theme.controlHeightSm

                        implicitHeight:
                            Nexa.Theme.controlHeightSm

                        radius:
                            Nexa.Theme.radiusSm


                        color:
                            disconnectMouse.pressed
                            ? Nexa.Theme.pressed

                            : disconnectMouse.containsMouse
                                ? Nexa.Theme.hoverStrong

                                : Nexa.Theme.surfaceContainerHighest


                        scale:
                            disconnectMouse.pressed
                            ? Nexa.Theme.pressScale
                            : Nexa.Theme.normalScale


                        Behavior on color {

                            ColorAnimation {
                                duration:
                                    Nexa.Theme.animationFast
                            }
                        }


                        Behavior on scale {

                            NumberAnimation {
                                duration:
                                    Nexa.Theme.animationFast

                                easing.type:
                                    Nexa.Theme.easingStandard
                            }
                        }


                        Text {
                            anchors.centerIn:
                                parent

                            text: "󰅖"

                            color:
                                Nexa.Theme.error


                            font {
                                family:
                                    Nexa.Theme.iconFontFamily

                                pixelSize:
                                    Nexa.Theme.iconMd
                            }
                        }


                        MouseArea {
                            id: disconnectMouse

                            anchors.fill:
                                parent

                            hoverEnabled:
                                true

                            cursorShape:
                                Qt.PointingHandCursor


                            onClicked:
                                root.disconnectCurrent()
                        }
                    }
                }
            }


            // ====================================================
            // PASSWORD PANEL
            // ====================================================

            Rectangle {
                id: passwordCard

                visible:
                    root.selectedNetwork !== null


                Layout.fillWidth: true

                Layout.preferredHeight:
                    root.connectError !== ""
                    ? 116
                    : 92


                radius:
                    Nexa.Theme.radiusMd


                color:
                    Nexa.Theme.surfaceContainerHigh


                border {
                    width:
                        Nexa.Theme.borderThin

                    color:
                        root.connectError !== ""
                        ? Nexa.Theme.error
                        : Nexa.Theme.border
                }


                opacity:
                    root.selectedNetwork
                    ? 1.0
                    : 0.0


                scale:
                    root.selectedNetwork
                    ? 1.0
                    : 0.97


                Behavior on opacity {

                    NumberAnimation {
                        duration:
                            Nexa.Theme.animationFast
                    }
                }


                Behavior on scale {

                    NumberAnimation {
                        duration:
                            Nexa.Theme.animationNormal

                        easing.type:
                            Nexa.Theme.easingStandard
                    }
                }


                ColumnLayout {
                    anchors {
                        fill: parent
                        margins:
                            Nexa.Theme.spacingMd
                    }

                    spacing:
                        Nexa.Theme.spacingXs


                    Text {
                        text:
                            root.selectedNetwork
                            ? "Connect to  "
                              + root.selectedNetwork.name

                            : ""


                        color:
                            Nexa.Theme.text


                        font {
                            family:
                                Nexa.Theme.fontFamily

                            pixelSize:
                                Nexa.Theme.fontSizeSm

                            weight:
                                Nexa.Theme.fontWeightDemiBold
                        }
                    }


                    RowLayout {
                        Layout.fillWidth:
                            true

                        spacing:
                            Nexa.Theme.spacingXs


                        // ----------------------------------------
                        // PASSWORD INPUT
                        // ----------------------------------------

                        Rectangle {
                            Layout.fillWidth:
                                true

                            implicitHeight:
                                Nexa.Theme.controlHeightMd

                            radius:
                                Nexa.Theme.radiusSm


                            color:
                                Nexa.Theme.inputBackground


                            border {
                                width:
                                    Nexa.Theme.borderThin

                                color:
                                    root.connectError !== ""
                                    ? Nexa.Theme.error

                                    : passwordInput.activeFocus
                                        ? Nexa.Theme.focusBorder

                                        : Nexa.Theme.border
                            }


                            Behavior on border.color {

                                ColorAnimation {
                                    duration:
                                        Nexa.Theme.animationFast
                                }
                            }


                            TextInput {
                                id: passwordInput

                                anchors {
                                    fill: parent

                                    leftMargin:
                                        Nexa.Theme.spacingSm

                                    rightMargin:
                                        Nexa.Theme.spacingSm
                                }


                                verticalAlignment:
                                    TextInput.AlignVCenter


                                text:
                                    root.password


                                color:
                                    Nexa.Theme.text


                                echoMode:
                                    root.showPassword
                                    ? TextInput.Normal
                                    : TextInput.Password


                                enabled:
                                    !root.connecting


                                selectByMouse:
                                    true


                                font {
                                    family:
                                        Nexa.Theme.fontFamily

                                    pixelSize:
                                        Nexa.Theme.fontSizeXs
                                }


                                onTextChanged: {

                                    root.password = text

                                    if (
                                        text.length > 0
                                        && root.connectError !== ""
                                    ) {
                                        root.connectError = ""
                                    }
                                }


                                Keys.onReturnPressed: {

                                    if (
                                        root.password.length > 0
                                        && !root.connecting
                                    ) {
                                        root.connectSelected()
                                    }
                                }
                            }


                            Text {
                                visible:
                                    passwordInput.text.length === 0
                                    && !passwordInput.activeFocus


                                anchors {
                                    left:
                                        parent.left

                                    verticalCenter:
                                        parent.verticalCenter

                                    leftMargin:
                                        Nexa.Theme.spacingSm
                                }


                                text:
                                    "Password"


                                color:
                                    Nexa.Theme.mutedText


                                font {
                                    family:
                                        Nexa.Theme.fontFamily

                                    pixelSize:
                                        Nexa.Theme.fontSizeXs
                                }
                            }
                        }


                        // ----------------------------------------
                        // SHOW PASSWORD
                        // ----------------------------------------

                        Rectangle {
                            implicitWidth:
                                Nexa.Theme.controlHeightMd

                            implicitHeight:
                                Nexa.Theme.controlHeightMd

                            radius:
                                Nexa.Theme.radiusSm


                            color:
                                eyeMouse.pressed
                                ? Nexa.Theme.pressed

                                : eyeMouse.containsMouse
                                    ? Nexa.Theme.hover

                                    : Nexa.Theme.surfaceContainerHighest


                            Behavior on color {

                                ColorAnimation {
                                    duration:
                                        Nexa.Theme.animationFast
                                }
                            }


                            Text {
                                anchors.centerIn:
                                    parent


                                text:
                                    root.showPassword
                                    ? "󰛐"
                                    : "󰈈"


                                color:
                                    Nexa.Theme.mutedText


                                font {
                                    family:
                                        Nexa.Theme.iconFontFamily

                                    pixelSize:
                                        Nexa.Theme.iconSm
                                }
                            }


                            MouseArea {
                                id: eyeMouse

                                anchors.fill:
                                    parent

                                hoverEnabled:
                                    true

                                cursorShape:
                                    Qt.PointingHandCursor


                                onClicked: {

                                    root.showPassword =
                                        !root.showPassword
                                }
                            }
                        }


                        // ----------------------------------------
                        // CANCEL
                        // ----------------------------------------

                        Rectangle {
                            implicitWidth: 64

                            implicitHeight:
                                Nexa.Theme.controlHeightMd

                            radius:
                                Nexa.Theme.radiusSm


                            color:
                                cancelMouse.pressed
                                ? Nexa.Theme.pressed

                                : cancelMouse.containsMouse
                                    ? Nexa.Theme.hover

                                    : Nexa.Theme.surfaceContainerHighest


                            scale:
                                cancelMouse.pressed
                                ? Nexa.Theme.pressScale
                                : Nexa.Theme.normalScale


                            Behavior on color {

                                ColorAnimation {
                                    duration:
                                        Nexa.Theme.animationFast
                                }
                            }


                            Behavior on scale {

                                NumberAnimation {
                                    duration:
                                        Nexa.Theme.animationFast
                                }
                            }


                            Text {
                                anchors.centerIn:
                                    parent

                                text:
                                    "Cancel"

                                color:
                                    Nexa.Theme.text


                                font {
                                    family:
                                        Nexa.Theme.fontFamily

                                    pixelSize:
                                        Nexa.Theme.fontSizeXs

                                    weight:
                                        Nexa.Theme.fontWeightMedium
                                }
                            }


                            MouseArea {
                                id: cancelMouse

                                anchors.fill:
                                    parent

                                hoverEnabled:
                                    true

                                cursorShape:
                                    Qt.PointingHandCursor


                                onClicked:
                                    root.cancelConnect()
                            }
                        }


                        // ----------------------------------------
                        // CONNECT
                        // ----------------------------------------

                        Rectangle {
                            implicitWidth: 72

                            implicitHeight:
                                Nexa.Theme.controlHeightMd

                            radius:
                                Nexa.Theme.radiusSm


                            opacity:
                                root.password.length > 0
                                && !root.connecting

                                ? Nexa.Theme.opacityFull
                                : Nexa.Theme.opacityDisabled


                            color:
                                connectMouse.pressed
                                ? Nexa.Theme.primaryContainer

                                : connectMouse.containsMouse
                                    ? Nexa.Theme.primaryContainer

                                    : Nexa.Theme.primary


                            scale:
                                connectMouse.pressed
                                ? Nexa.Theme.pressScale
                                : Nexa.Theme.normalScale


                            Behavior on color {

                                ColorAnimation {
                                    duration:
                                        Nexa.Theme.animationFast
                                }
                            }


                            Behavior on scale {

                                NumberAnimation {
                                    duration:
                                        Nexa.Theme.animationFast
                                }
                            }


                            Text {
                                anchors.centerIn:
                                    parent


                                text:
                                    root.connecting
                                    ? "..."
                                    : "Connect"


                                color:
                                    Nexa.Theme.primaryText


                                font {
                                    family:
                                        Nexa.Theme.fontFamily

                                    pixelSize:
                                        Nexa.Theme.fontSizeXs

                                    weight:
                                        Nexa.Theme.fontWeightDemiBold
                                }
                            }


                            MouseArea {
                                id: connectMouse

                                anchors.fill:
                                    parent


                                enabled:
                                    root.password.length > 0
                                    && !root.connecting


                                hoverEnabled:
                                    true

                                cursorShape:
                                    Qt.PointingHandCursor


                                onClicked:
                                    root.connectSelected()
                            }
                        }
                    }


                    // --------------------------------------------
                    // CONNECTION ERROR
                    // --------------------------------------------

                    Text {
                        visible:
                            root.connectError !== ""


                        Layout.fillWidth:
                            true


                        text:
                            root.connectError


                        color:
                            Nexa.Theme.error


                        font {
                            family:
                                Nexa.Theme.fontFamily

                            pixelSize:
                                Nexa.Theme.fontSize2Xs

                            weight:
                                Nexa.Theme.fontWeightMedium
                        }
                    }
                }
            }


            // ====================================================
            // NETWORK LIST
            // ====================================================

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true


                radius:
                    Nexa.Theme.radiusMd


                color:
                    Nexa.Theme.surfaceContainerHigh


                border {
                    width:
                        Nexa.Theme.borderThin

                    color:
                        Nexa.Theme.border
                }


                ColumnLayout {
                    anchors {
                        fill: parent

                        margins:
                            Nexa.Theme.spacingMd
                    }

                    spacing:
                        Nexa.Theme.spacingSm


                    // ============================================
                    // HEADER
                    // ============================================

                    RowLayout {
                        Layout.fillWidth:
                            true


                        Text {
                            text:
                                "Wi-Fi"

                            color:
                                Nexa.Theme.text


                            font {
                                family:
                                    Nexa.Theme.fontFamily

                                pixelSize:
                                    Nexa.Theme.fontSizeSm

                                weight:
                                    Nexa.Theme.fontWeightDemiBold
                            }
                        }


                        Item {
                            Layout.fillWidth:
                                true
                        }


                        // ----------------------------------------
                        // SCANNER INDICATOR
                        // ----------------------------------------

                        Text {
                            id: scanningIcon

                            text:
                                "󰑐"


                            color:
                                root.device
                                && root.device.scannerEnabled

                                ? Nexa.Theme.primary
                                : Nexa.Theme.mutedText


                            font {
                                family:
                                    Nexa.Theme.iconFontFamily

                                pixelSize:
                                    Nexa.Theme.iconSm
                            }


                            RotationAnimator on rotation {
                                running:
                                    root.device
                                    && root.device.scannerEnabled
                                    && root.visible


                                from: 0
                                to: 360

                                duration: 1400

                                loops:
                                    Animation.Infinite
                            }
                        }


                        // ----------------------------------------
                        // REFRESH
                        // ----------------------------------------

                        Rectangle {
                            implicitWidth:
                                Nexa.Theme.controlHeightSm

                            implicitHeight:
                                Nexa.Theme.controlHeightSm

                            radius:
                                Nexa.Theme.radiusSm


                            color:
                                refreshMouse.pressed
                                ? Nexa.Theme.pressed

                                : refreshMouse.containsMouse
                                    ? Nexa.Theme.hover

                                    : "transparent"


                            scale:
                                refreshMouse.pressed
                                ? Nexa.Theme.pressScale
                                : Nexa.Theme.normalScale


                            Behavior on color {

                                ColorAnimation {
                                    duration:
                                        Nexa.Theme.animationFast
                                }
                            }


                            Behavior on scale {

                                NumberAnimation {
                                    duration:
                                        Nexa.Theme.animationFast
                                }
                            }


                            Text {
                                anchors.centerIn:
                                    parent

                                text:
                                    "󰑐"

                                color:
                                    Nexa.Theme.text


                                font {
                                    family:
                                        Nexa.Theme.iconFontFamily

                                    pixelSize:
                                        Nexa.Theme.iconSm
                                }
                            }


                            MouseArea {
                                id: refreshMouse

                                anchors.fill:
                                    parent


                                enabled:
                                    !networkProcess.running


                                hoverEnabled:
                                    true

                                cursorShape:
                                    Qt.PointingHandCursor


                                onClicked:
                                    root.refreshNetworks()
                            }
                        }


                        // ----------------------------------------
                        // WIFI TOGGLE
                        // ----------------------------------------

                        Rectangle {
                            implicitWidth: 38
                            implicitHeight: 20


                            radius:
                                Nexa.Theme.radiusPill


                            color:
                                Networking.wifiEnabled
                                ? Nexa.Theme.primary
                                : Nexa.Theme.surfaceContainerHighest


                            Behavior on color {

                                ColorAnimation {
                                    duration:
                                        Nexa.Theme.animationFast
                                }
                            }


                            Rectangle {
                                width: 16
                                height: 16

                                radius:
                                    Nexa.Theme.radiusPill


                                anchors.verticalCenter:
                                    parent.verticalCenter


                                x:
                                    Networking.wifiEnabled
                                    ? parent.width
                                      - width
                                      - 2

                                    : 2


                                color:
                                    Networking.wifiEnabled
                                    ? Nexa.Theme.primaryText
                                    : Nexa.Theme.mutedText


                                Behavior on x {

                                    NumberAnimation {
                                        duration:
                                            Nexa.Theme.animationNormal

                                        easing.type:
                                            Nexa.Theme.easingStandard
                                    }
                                }


                                Behavior on color {

                                    ColorAnimation {
                                        duration:
                                            Nexa.Theme.animationFast
                                    }
                                }
                            }


                            MouseArea {
                                anchors.fill:
                                    parent


                                enabled:
                                    !networkProcess.running


                                cursorShape:
                                    Qt.PointingHandCursor


                                onClicked:
                                    root.toggleWifi()
                            }
                        }
                    }


                    // ============================================
                    // BACKEND ERROR
                    // ============================================

                    Text {
                        visible:
                            root.actionError !== ""


                        Layout.fillWidth:
                            true


                        text:
                            root.actionError


                        color:
                            Nexa.Theme.error


                        font {
                            family:
                                Nexa.Theme.fontFamily

                            pixelSize:
                                Nexa.Theme.fontSize2Xs
                        }
                    }


                    // ============================================
                    // CONNECTED NETWORK
                    // ============================================

                    ColumnLayout {
                        visible:
                            root.connectedNetwork !== null


                        Layout.fillWidth:
                            true

                        spacing:
                            Nexa.Theme.spacingXs


                        Text {
                            text:
                                "Connected"

                            color:
                                Nexa.Theme.mutedText


                            font {
                                family:
                                    Nexa.Theme.fontFamily

                                pixelSize:
                                    Nexa.Theme.fontSize2Xs

                                weight:
                                    Nexa.Theme.fontWeightDemiBold
                            }
                        }


                        Rectangle {
                            Layout.fillWidth:
                                true

                            implicitHeight: 48


                            radius:
                                Nexa.Theme.radiusSm


                            color:
                                Nexa.Theme.surfaceContainerHighest


                            border {
                                width:
                                    Nexa.Theme.borderThin

                                color:
                                    Nexa.Theme.primary
                            }


                            RowLayout {
                                anchors {
                                    fill: parent

                                    margins:
                                        Nexa.Theme.spacingSm
                                }

                                spacing:
                                    Nexa.Theme.spacingSm


                                Text {
                                    text:
                                        root.signalIcon(
                                            root.connectedNetwork
                                        )


                                    color:
                                        Nexa.Theme.primary


                                    font {
                                        family:
                                            Nexa.Theme.iconFontFamily

                                        pixelSize:
                                            Nexa.Theme.iconMd
                                    }
                                }


                                Text {
                                    Layout.fillWidth:
                                        true


                                    text:
                                        root.connectedNetwork
                                        ? root.connectedNetwork.name
                                        : ""


                                    elide:
                                        Text.ElideRight


                                    color:
                                        Nexa.Theme.text


                                    font {
                                        family:
                                            Nexa.Theme.fontFamily

                                        pixelSize:
                                            Nexa.Theme.fontSizeXs

                                        weight:
                                            Nexa.Theme.fontWeightMedium
                                    }
                                }


                                Text {
                                    text:
                                        root.signalPercent(
                                            root.connectedNetwork
                                        )
                                        + "%"


                                    color:
                                        Nexa.Theme.mutedText


                                    font {
                                        family:
                                            Nexa.Theme.fontFamily

                                        pixelSize:
                                            Nexa.Theme.fontSizeXs
                                    }
                                }


                                // --------------------------------
                                // FORGET CONNECTED NETWORK
                                // --------------------------------

                                Rectangle {
                                    implicitWidth:
                                        Nexa.Theme.controlHeightSm

                                    implicitHeight:
                                        Nexa.Theme.controlHeightSm


                                    radius:
                                        Nexa.Theme.radiusSm


                                    color:
                                        pinnedForgetMouse.pressed
                                        ? Nexa.Theme.pressed

                                        : pinnedForgetMouse.containsMouse
                                            ? Nexa.Theme.hoverStrong

                                            : "transparent"


                                    scale:
                                        pinnedForgetMouse.pressed
                                        ? Nexa.Theme.pressScale
                                        : Nexa.Theme.normalScale


                                    Behavior on color {

                                        ColorAnimation {
                                            duration:
                                                Nexa.Theme.animationFast
                                        }
                                    }


                                    Behavior on scale {

                                        NumberAnimation {
                                            duration:
                                                Nexa.Theme.animationFast
                                        }
                                    }


                                    Text {
                                        anchors.centerIn:
                                            parent

                                        text:
                                            "󰆴"

                                        color:
                                            Nexa.Theme.error


                                        font {
                                            family:
                                                Nexa.Theme.iconFontFamily

                                            pixelSize:
                                                Nexa.Theme.iconSm
                                        }
                                    }


                                    MouseArea {
                                        id: pinnedForgetMouse

                                        anchors.fill:
                                            parent

                                        hoverEnabled:
                                            true

                                        cursorShape:
                                            Qt.PointingHandCursor


                                        onClicked: {

                                            root.forgetNetwork(
                                                root.connectedNetwork
                                            )
                                        }
                                    }
                                }
                            }
                        }
                    }


                    // ============================================
                    // AVAILABLE HEADER
                    // ============================================

                    Text {
                        visible:
                            availableNetworks.values.length > 0


                        text:
                            "Available Networks"


                        color:
                            Nexa.Theme.mutedText


                        font {
                            family:
                                Nexa.Theme.fontFamily

                            pixelSize:
                                Nexa.Theme.fontSize2Xs

                            weight:
                                Nexa.Theme.fontWeightDemiBold
                        }
                    }


                    // ============================================
                    // AVAILABLE NETWORK LIST
                    // ============================================

                    ListView {
                        id: networkList

                        Layout.fillWidth:
                            true

                        Layout.fillHeight:
                            true


                        clip:
                            true


                        spacing:
                            Nexa.Theme.spacingXs


                        model:
                            availableNetworks

                        flickDeceleration:
                            Nexa.Theme.flickDeceleration

                        maximumFlickVelocity:
                            Nexa.Theme.flickVelocityMax

                        pixelAligned: true

                        ScrollBar.vertical: ScrollBar {
                            id: wifiScrollBar
                            policy: ScrollBar.AsNeeded

                            contentItem: Rectangle {
                                implicitWidth: 3
                                radius: width / 2
                                color: Qt.rgba(
                                    Nexa.Theme.text.r,
                                    Nexa.Theme.text.g,
                                    Nexa.Theme.text.b,
                                    wifiScrollBar.hovered ? 0.5 : 0.18
                                )

                                Behavior on color {
                                    ColorAnimation { duration: Nexa.Theme.animationFast }
                                }
                            }

                            background: null
                        }


                        boundsBehavior: Flickable.StopAtBounds
                        reuseItems: true


                        delegate: Rectangle {
                            id: networkCard


                            required property var modelData


                            width:
                                networkList.width - 8

                            height: 48


                            radius:
                                Nexa.Theme.radiusSm


                            color:
                                cardMouse.pressed
                                ? Nexa.Theme.pressed

                                : cardMouse.containsMouse
                                    ? Nexa.Theme.hover

                                    : Nexa.Theme.surfaceContainerHighest


                            border {
                                width:
                                    Nexa.Theme.borderThin

                                color:
                                    root.connectingNetwork
                                    === networkCard.modelData

                                    ? Nexa.Theme.primary

                                    : Nexa.Theme.border
                            }


                            scale:
                                cardMouse.pressed
                                ? 0.985
                                : 1.0


                            Behavior on color {

                                ColorAnimation {
                                    duration:
                                        Nexa.Theme.animationFast
                                }
                            }


                            Behavior on border.color {

                                ColorAnimation {
                                    duration:
                                        Nexa.Theme.animationFast
                                }
                            }


                            Behavior on scale {

                                NumberAnimation {
                                    duration:
                                        Nexa.Theme.animationFast

                                    easing.type:
                                        Nexa.Theme.easingStandard
                                }
                            }


                            /*
                             * IMPORTANT:
                             *
                             * The card MouseArea stays behind the content.
                             * The delete button is therefore clickable.
                             */
                            MouseArea {
                                id: cardMouse

                                anchors.fill:
                                    parent


                                z: 0


                                enabled:
                                    !root.connecting


                                hoverEnabled:
                                    true


                                cursorShape:
                                    Qt.PointingHandCursor


                                onClicked: {

                                    root.chooseNetwork(
                                        networkCard.modelData
                                    )
                                }
                            }


                            RowLayout {
                                anchors {
                                    fill: parent

                                    margins:
                                        Nexa.Theme.spacingSm
                                }


                                z: 1


                                spacing:
                                    Nexa.Theme.spacingSm


                                Text {
                                    text:
                                        root.signalIcon(
                                            networkCard.modelData
                                        )


                                    color:
                                        root.connectingNetwork
                                            === networkCard.modelData

                                        ? Nexa.Theme.primary
                                        : Nexa.Theme.text


                                    font {
                                        family:
                                            Nexa.Theme.iconFontFamily

                                        pixelSize:
                                            Nexa.Theme.iconMd
                                    }
                                }


                                Text {
                                    Layout.fillWidth:
                                        true


                                    text:
                                        networkCard.modelData.name


                                    elide:
                                        Text.ElideRight


                                    color:
                                        Nexa.Theme.text


                                    font {
                                        family:
                                            Nexa.Theme.fontFamily

                                        pixelSize:
                                            Nexa.Theme.fontSizeXs

                                        weight:
                                            Nexa.Theme.fontWeightMedium
                                    }
                                }


                                // --------------------------------
                                // CONNECTING INDICATOR
                                // --------------------------------

                                Text {
                                    visible:
                                        root.connectingNetwork
                                        === networkCard.modelData


                                    text:
                                        "󰑐"


                                    color:
                                        Nexa.Theme.primary


                                    font {
                                        family:
                                            Nexa.Theme.iconFontFamily

                                        pixelSize:
                                            Nexa.Theme.iconXs
                                    }


                                    RotationAnimator on rotation {
                                        running:
                                            root.connectingNetwork
                                            === networkCard.modelData


                                        from: 0
                                        to: 360

                                        duration: 900

                                        loops:
                                            Animation.Infinite
                                    }
                                }


                                // --------------------------------
                                // SECURITY
                                // --------------------------------

                                Text {
                                    visible:
                                        root.secured(
                                            networkCard.modelData
                                        )


                                    text:
                                        "󰌾"


                                    color:
                                        Nexa.Theme.mutedText


                                    font {
                                        family:
                                            Nexa.Theme.iconFontFamily

                                        pixelSize:
                                            Nexa.Theme.iconXs
                                    }
                                }


                                Text {
                                    text:
                                        root.signalPercent(
                                            networkCard.modelData
                                        )
                                        + "%"


                                    color:
                                        Nexa.Theme.mutedText


                                    font {
                                        family:
                                            Nexa.Theme.fontFamily

                                        pixelSize:
                                            Nexa.Theme.fontSizeXs
                                    }
                                }


                                // --------------------------------
                                // FORGET SAVED NETWORK
                                //
                                // This now sits ABOVE cardMouse.
                                // --------------------------------

                                Rectangle {
                                    visible:
                                        networkCard.modelData.known


                                    implicitWidth:
                                        Nexa.Theme.controlHeightSm

                                    implicitHeight:
                                        Nexa.Theme.controlHeightSm


                                    radius:
                                        Nexa.Theme.radiusSm


                                    color:
                                        forgetMouse.pressed
                                        ? Nexa.Theme.pressed

                                        : forgetMouse.containsMouse
                                            ? Nexa.Theme.hoverStrong

                                            : "transparent"


                                    scale:
                                        forgetMouse.pressed
                                        ? Nexa.Theme.pressScale
                                        : Nexa.Theme.normalScale


                                    Behavior on color {

                                        ColorAnimation {
                                            duration:
                                                Nexa.Theme.animationFast
                                        }
                                    }


                                    Behavior on scale {

                                        NumberAnimation {
                                            duration:
                                                Nexa.Theme.animationFast
                                        }
                                    }


                                    Text {
                                        anchors.centerIn:
                                            parent

                                        text:
                                            "󰆴"

                                        color:
                                            Nexa.Theme.error


                                        font {
                                            family:
                                                Nexa.Theme.iconFontFamily

                                            pixelSize:
                                                Nexa.Theme.iconSm
                                        }
                                    }


                                    MouseArea {
                                        id: forgetMouse

                                        anchors.fill:
                                            parent


                                        hoverEnabled:
                                            true

                                        preventStealing:
                                            true


                                        cursorShape:
                                            Qt.PointingHandCursor


                                        onClicked: function(mouse) {

                                            mouse.accepted = true

                                            root.forgetNetwork(
                                                networkCard.modelData
                                            )
                                        }
                                    }
                                }
                            }
                        }
                    }


                    // ============================================
                    // EMPTY STATE
                    // ============================================

                    Text {
                        visible:
                            root.wifiEnabled
                            && availableNetworks.values.length === 0
                            && root.connectedNetwork === null


                        Layout.alignment:
                            Qt.AlignHCenter


                        text:
                            root.device
                            && root.device.scannerEnabled

                            ? "Searching for networks…"
                            : "No networks found"


                        color:
                            Nexa.Theme.mutedText


                        font {
                            family:
                                Nexa.Theme.fontFamily

                            pixelSize:
                                Nexa.Theme.fontSizeXs
                        }
                    }
                }
            }
        }
    }
}
