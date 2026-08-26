import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth

import "../../theme" as Nexa


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
        Quickshell.env("HOME")
        + "/.config/nexa/rust/target/release/nexad"


    readonly property var adapter:
        Bluetooth.defaultAdapter


    readonly property bool enabled:
        root.adapter !== null
        && root.adapter.enabled


    readonly property bool scanning:
        root.adapter !== null
        && root.adapter.discovering


    // ============================================================
    // DEVICE GROUPS
    //
    // IMPORTANT:
    //
    // These come from nexad / BlueZ.
    //
    // We deliberately DO NOT use:
    //
    //     Bluetooth.devices
    //     adapter.devices
    //
    // as the full catalogue because those models represent
    // connected Bluetooth devices.
    // ============================================================

    readonly property var connectedDevices:
        root.deviceCatalog.filter(
            device => device.connected
        )


    readonly property var pairedDevices:
        root.deviceCatalog.filter(
            device =>
                device.paired
                && !device.connected
        )


    readonly property var availableDevices:
        root.deviceCatalog.filter(
            device =>
                !device.paired
                && !device.connected
        )


    // ============================================================
    // WINDOW
    // ============================================================

    implicitWidth: 410
    implicitHeight: 580

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
    // HELPERS
    // ============================================================

    function deviceGlyph(type) {

        const value =
            (type || "").toLowerCase()


        if (
            value.includes("headset")
            || value.includes("headphone")
            || value.includes("audio")
        ) {
            return "󰋋"
        }


        if (
            value.includes("mouse")
        ) {
            return "󰍽"
        }


        if (
            value.includes("keyboard")
        ) {
            return "󰌌"
        }


        if (
            value.includes("phone")
            || value.includes("smartphone")
        ) {
            return "󰄜"
        }


        if (
            value.includes("computer")
        ) {
            return "󰍹"
        }


        return "󰂯"
    }


    function deviceName(device) {

        if (!device)
            return "Unknown device"


        if (
            device.name
            && device.name !== ""
        ) {
            return device.name
        }


        return device.address
            || "Unknown device"
    }


    function isPending(device) {

        return (
            device
            && root.pendingAddress
                === device.address
            && root.pendingAction !== ""
        )
    }


    // ============================================================
    // BLUETOOTH INFO PROCESS
    //
    // This is separate from actions so polling never interferes
    // with pair/connect/disconnect/forget.
    // ============================================================

    Process {
        id: infoProcess

        stdout:
            StdioCollector {
                id: infoOutput

                waitForEnd: true


                onStreamFinished: {

                    const raw =
                        infoOutput.text.trim()


                    if (raw === "")
                        return


                    try {

                        const parsed =
                            JSON.parse(raw)


                        if (
                            parsed
                            && Array.isArray(
                                parsed.devices
                            )
                        ) {
                            root.deviceCatalog =
                                parsed.devices
                        }

                    } catch (error) {

                        console.warn(
                            "NEXA Bluetooth JSON error:",
                            error,
                            raw
                        )
                    }
                }
            }


        onExited: function(
            exitCode,
            exitStatus
        ) {

            if (exitCode !== 0) {

                console.warn(
                    "NEXA bluetooth info failed"
                )
            }
        }
    }


    function refreshInfo() {

        if (infoProcess.running)
            return


        infoProcess.exec(
            [
                root.nexad,
                "network",
                "bluetooth",
                "info"
            ]
        )
    }


    // ============================================================
    // ACTION PROCESS
    // ============================================================

    Process {
        id: actionProcess


        onStarted: {

            root.actionError = ""
        }


        onExited: function(
            exitCode,
            exitStatus
        ) {

            if (exitCode !== 0) {

                root.actionError =
                    "Bluetooth action failed"

            } else {

                root.actionError = ""
            }


            /*
             * BlueZ state may take a moment to settle after
             * pair/connect/disconnect/forget.
             *
             * Poll several times so the card smoothly moves
             * between Connected / Paired / Available.
             */
            root.postActionPolls = 5

            postActionTimer.restart()
        }
    }


    function runBluetooth(
        args,
        action,
        address
    ) {

        if (actionProcess.running)
            return


        root.pendingAction =
            action || ""

        root.pendingAddress =
            address || ""

        root.actionError = ""


        actionProcess.exec(
            [
                root.nexad,
                "network",
                "bluetooth"
            ].concat(args)
        )
    }


    // ============================================================
    // ACTIONS
    // ============================================================

    function toggleBluetooth() {

        if (!root.adapter)
            return


        /*
         * Stop discovery first when powering off.
         */
        if (
            root.adapter.enabled
            && root.adapter.discovering
        ) {
            root.adapter.discovering =
                false
        }


        /*
         * Quickshell exposes adapter.enabled as writable.
         */
        root.adapter.enabled =
            !root.adapter.enabled
    }


    function pairDevice(device) {

        if (!device)
            return


        runBluetooth(
            [
                "pair",
                device.address
            ],
            "pair",
            device.address
        )
    }


    function connectDevice(device) {

        if (!device)
            return


        runBluetooth(
            [
                "connect",
                device.address
            ],
            "connect",
            device.address
        )
    }


    function disconnectDevice(device) {

        if (!device)
            return


        runBluetooth(
            [
                "disconnect",
                device.address
            ],
            "disconnect",
            device.address
        )
    }


    function forgetDevice(device) {

        if (!device)
            return


        runBluetooth(
            [
                "forget",
                device.address
            ],
            "forget",
            device.address
        )
    }


    // ============================================================
    // DISCOVERY
    //
    // Quickshell owns the long-lived BlueZ discovery session.
    //
    // Rust only reads the BlueZ device catalogue.
    // ============================================================

    function startDiscovery() {

        if (
            !root.adapter
            || !root.adapter.enabled
        ) {
            return
        }


        if (!root.adapter.discovering) {

            root.adapter.discovering =
                true
        }
    }


    function stopDiscovery() {

        if (!root.adapter)
            return


        if (root.adapter.discovering) {

            root.adapter.discovering =
                false
        }
    }


    function toggleDiscovery() {

        if (!root.enabled)
            return


        if (root.scanning)
            root.stopDiscovery()
        else
            root.startDiscovery()
    }


    // ============================================================
    // POLLING
    //
    // While popup is open:
    //
    // Quickshell maintains discovery
    // Rust reads the resulting BlueZ catalogue
    // ============================================================

    Timer {
        id: catalogueTimer

        interval: 1200
        repeat: true

        running:
            root.visible


        triggeredOnStart:
            true


        onTriggered:
            root.refreshInfo()
    }


    // ============================================================
    // AFTER-ACTION FAST POLLING
    // ============================================================

    Timer {
        id: postActionTimer

        interval: 450
        repeat: true


        onTriggered: {

            root.refreshInfo()


            root.postActionPolls--


            if (
                root.postActionPolls <= 0
            ) {

                stop()


                root.pendingAction = ""
                root.pendingAddress = ""
            }
        }
    }


    // ============================================================
    // DISCOVERY START DELAY
    //
    // Useful after Bluetooth is powered on.
    // ============================================================

    Timer {
        id: discoveryStartDelay

        interval: 300
        repeat: false


        onTriggered: {

            if (
                root.visible
                && root.enabled
            ) {
                root.startDiscovery()
            }
        }
    }


    // ============================================================
    // ADAPTER CHANGES
    // ============================================================

    Connections {
        target:
            root.adapter

        ignoreUnknownSignals: true


        function onEnabledChanged() {

            root.refreshInfo()


            if (
                root.visible
                && root.enabled
            ) {

                discoveryStartDelay.restart()

            } else if (
                root.adapter
                && !root.enabled
            ) {

                root.deviceCatalog = []
            }
        }
    }


    // ============================================================
    // POPUP LIFECYCLE
    // ============================================================

    onVisibleChanged: {

        if (visible) {

            /*
             * Read paired/connected devices immediately.
             */
            root.refreshInfo()


            /*
             * Start OUR discovery session.
             */
            if (root.enabled) {

                discoveryStartDelay.restart()
            }

        } else {

            /*
             * CRITICAL:
             *
             * Closing this popup ONLY stops discovery.
             *
             * It does NOT:
             *
             * - disconnect
             * - forget
             * - cancel pairing
             * - power Bluetooth off
             */
            discoveryStartDelay.stop()

            root.stopDiscovery()
        }
    }


    // ============================================================
    // REUSABLE DEVICE CARD
    // ============================================================

    component DeviceCard: Rectangle {

        id: card


        required property var deviceData


        readonly property bool connected:
            card.deviceData.connected


        readonly property bool paired:
            card.deviceData.paired


        readonly property bool pending:
            root.isPending(
                card.deviceData
            )


        width:
            deviceColumn.width

        height: 62


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
                card.connected
                ? Nexa.Theme.primary

                : card.pending
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


        RowLayout {
            anchors {
                fill: parent

                margins:
                    Nexa.Theme.spacingSm
            }


            spacing:
                Nexa.Theme.spacingSm


            // ====================================================
            // DEVICE ICON
            // ====================================================

            Rectangle {
                Layout.preferredWidth: 38
                Layout.preferredHeight: 38


                radius:
                    Nexa.Theme.radiusPill


                color:
                    card.connected
                    ? Nexa.Theme.primaryContainer

                    : card.paired
                        ? Nexa.Theme.surfaceContainerHigh

                        : Nexa.Theme.surfaceContainerLow


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
                        root.deviceGlyph(
                            card.deviceData
                                .device_type
                        )


                    color:
                        card.connected
                        ? Nexa.Theme.primary

                        : Nexa.Theme.text


                    font {
                        family:
                            Nexa.Theme.iconFontFamily

                        pixelSize:
                            Nexa.Theme.iconMd
                    }


                    scale:
                        cardMouse.containsMouse
                        ? 1.08
                        : 1.0


                    Behavior on scale {

                        NumberAnimation {
                            duration:
                                Nexa.Theme.animationFast

                            easing.type:
                                Nexa.Theme.easingStandard
                        }
                    }
                }
            }


            // ====================================================
            // NAME / STATE
            // ====================================================

            ColumnLayout {
                Layout.fillWidth:
                    true


                spacing: 1


                Text {
                    Layout.fillWidth:
                        true


                    text:
                        root.deviceName(
                            card.deviceData
                        )


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
                    text: {

                        if (card.pending) {

                            if (
                                root.pendingAction
                                    === "pair"
                            ) {
                                return "Pairing…"
                            }


                            if (
                                root.pendingAction
                                    === "connect"
                            ) {
                                return "Connecting…"
                            }


                            if (
                                root.pendingAction
                                    === "disconnect"
                            ) {
                                return "Disconnecting…"
                            }


                            if (
                                root.pendingAction
                                    === "forget"
                            ) {
                                return "Removing…"
                            }
                        }


                        if (card.connected)
                            return "Connected"


                        if (card.paired)
                            return "Paired"


                        return "Available"
                    }


                    color:
                        card.connected
                        || card.pending

                        ? Nexa.Theme.primary
                        : Nexa.Theme.mutedText


                    font {
                        family:
                            Nexa.Theme.fontFamily

                        pixelSize:
                            Nexa.Theme.fontSize2Xs

                        weight:
                            card.connected
                            || card.pending

                            ? Nexa.Theme.fontWeightMedium
                            : Nexa.Theme.fontWeightRegular
                    }


                    Behavior on color {

                        ColorAnimation {
                            duration:
                                Nexa.Theme.animationFast
                        }
                    }
                }
            }


            // ====================================================
            // ACTION SPINNER
            // ====================================================

            Text {
                visible:
                    card.pending


                text:
                    "󰑐"


                color:
                    Nexa.Theme.primary


                font {
                    family:
                        Nexa.Theme.iconFontFamily

                    pixelSize:
                        Nexa.Theme.iconSm
                }


                RotationAnimator on rotation {
                    running:
                        card.pending


                    from: 0
                    to: 360

                    duration: 900

                    loops:
                        Animation.Infinite
                }
            }


            // ====================================================
            // PRIMARY ACTION
            // ====================================================

            Rectangle {
                visible:
                    !card.pending


                implicitWidth:
                    card.connected
                    ? 78

                    : card.paired
                        ? 58
                        : 46


                implicitHeight:
                    Nexa.Theme.controlHeightSm


                radius:
                    Nexa.Theme.radiusSm


                color:
                    actionMouse.pressed
                    ? Nexa.Theme.pressed

                    : actionMouse.containsMouse
                        ? Nexa.Theme.hoverStrong

                        : "transparent"


                scale:
                    actionMouse.pressed
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


                    text:
                        card.connected
                        ? "Disconnect"

                        : card.paired
                            ? "Connect"

                            : "Pair"


                    color:
                        card.connected
                        ? Nexa.Theme.mutedText

                        : Nexa.Theme.primary


                    font {
                        family:
                            Nexa.Theme.fontFamily

                        pixelSize:
                            Nexa.Theme.fontSize2Xs

                        weight:
                            Nexa.Theme.fontWeightMedium
                    }
                }


                MouseArea {
                    id: actionMouse

                    anchors.fill:
                        parent


                    enabled:
                        !actionProcess.running


                    hoverEnabled:
                        true


                    cursorShape:
                        Qt.PointingHandCursor


                    onClicked: {

                        if (card.connected) {

                            root.disconnectDevice(
                                card.deviceData
                            )

                            return
                        }


                        if (card.paired) {

                            root.connectDevice(
                                card.deviceData
                            )

                            return
                        }


                        root.pairDevice(
                            card.deviceData
                        )
                    }
                }
            }


            // ====================================================
            // FORGET
            //
            // Only paired / connected saved devices.
            // ====================================================

            Rectangle {
                visible:
                    card.paired
                    || card.connected


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

                        easing.type:
                            Nexa.Theme.easingStandard
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


                    enabled:
                        !actionProcess.running


                    hoverEnabled:
                        true


                    cursorShape:
                        Qt.PointingHandCursor


                    preventStealing:
                        true


                    onClicked: function(mouse) {

                        mouse.accepted = true


                        root.forgetDevice(
                            card.deviceData
                        )
                    }
                }
            }
        }


        /*
         * Hover-only mouse layer.
         *
         * Qt.NoButton means it never steals clicks from the
         * Connect / Disconnect / Pair / Forget buttons.
         */
        MouseArea {
            id: cardMouse

            anchors.fill:
                parent


            acceptedButtons:
                Qt.NoButton


            hoverEnabled:
                true
        }
    }


    // ============================================================
    // PANEL
    // ============================================================

    Rectangle {
        anchors.fill:
            parent


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
            // BLUETOOTH STATUS
            // ====================================================

            Rectangle {
                Layout.fillWidth:
                    true

                Layout.preferredHeight:
                    82


                radius:
                    Nexa.Theme.radiusMd


                color:
                    Nexa.Theme.surfaceContainerHigh


                border {
                    width:
                        Nexa.Theme.borderThin


                    color:
                        root.connectedDevices.length > 0
                        ? Nexa.Theme.primary
                        : Nexa.Theme.border
                }


                Behavior on border.color {

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
                            root.enabled
                            ? "󰂯"
                            : "󰂲"


                        color:
                            root.connectedDevices.length > 0
                            ? Nexa.Theme.primary

                            : root.enabled
                                ? Nexa.Theme.text

                                : Nexa.Theme.mutedText


                        font {
                            family:
                                Nexa.Theme.iconFontFamily

                            pixelSize:
                                Nexa.Theme.iconLg
                        }
                    }


                    ColumnLayout {
                        Layout.fillWidth:
                            true


                        spacing: 2


                        Text {
                            text:
                                root.enabled
                                ? "Bluetooth"
                                : "Bluetooth disabled"


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
                            text: {

                                if (!root.enabled)
                                    return "Off"


                                if (
                                    root.connectedDevices.length > 0
                                ) {

                                    return root.connectedDevices.length
                                        + (
                                            root.connectedDevices.length
                                                === 1
                                            ? " device connected"
                                            : " devices connected"
                                        )
                                }


                                if (root.scanning)
                                    return "Searching for devices…"


                                return "No connected devices"
                            }


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


                    // --------------------------------------------
                    // POWER TOGGLE
                    // --------------------------------------------

                    Rectangle {
                        implicitWidth: 38
                        implicitHeight: 20


                        radius:
                            Nexa.Theme.radiusPill


                        color:
                            root.enabled
                            ? Nexa.Theme.primary
                            : Nexa.Theme.surfaceContainerHighest


                        scale:
                            powerMouse.pressed
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


                        Rectangle {
                            width: 16
                            height: 16


                            radius:
                                Nexa.Theme.radiusPill


                            anchors.verticalCenter:
                                parent.verticalCenter


                            x:
                                root.enabled
                                ? parent.width
                                  - width
                                  - 2

                                : 2


                            color:
                                root.enabled
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
                            id: powerMouse

                            anchors.fill:
                                parent


                            cursorShape:
                                Qt.PointingHandCursor


                            onClicked:
                                root.toggleBluetooth()
                        }
                    }
                }
            }


            // ====================================================
            // DEVICES
            // ====================================================

            Rectangle {
                Layout.fillWidth:
                    true

                Layout.fillHeight:
                    true


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
                                "Devices"


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


                        Text {
                            visible:
                                root.scanning


                            text:
                                "Scanning"


                            color:
                                Nexa.Theme.primary


                            font {
                                family:
                                    Nexa.Theme.fontFamily

                                pixelSize:
                                    Nexa.Theme.fontSize2Xs

                                weight:
                                    Nexa.Theme.fontWeightMedium
                            }
                        }


                        // ----------------------------------------
                        // SCAN TOGGLE
                        // ----------------------------------------

                        Rectangle {
                            implicitWidth:
                                Nexa.Theme.controlHeightSm

                            implicitHeight:
                                Nexa.Theme.controlHeightSm


                            radius:
                                Nexa.Theme.radiusSm


                            opacity:
                                root.enabled
                                ? Nexa.Theme.opacityFull
                                : Nexa.Theme.opacityDisabled


                            color:
                                scanMouse.pressed
                                ? Nexa.Theme.pressed

                                : scanMouse.containsMouse
                                    ? Nexa.Theme.hover

                                    : "transparent"


                            scale:
                                scanMouse.pressed
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
                                    root.scanning
                                    ? Nexa.Theme.primary
                                    : Nexa.Theme.text


                                font {
                                    family:
                                        Nexa.Theme.iconFontFamily

                                    pixelSize:
                                        Nexa.Theme.iconSm
                                }


                                RotationAnimator on rotation {
                                    running:
                                        root.scanning
                                        && root.visible


                                    from: 0
                                    to: 360

                                    duration: 1200

                                    loops:
                                        Animation.Infinite
                                }
                            }


                            MouseArea {
                                id: scanMouse

                                anchors.fill:
                                    parent


                                enabled:
                                    root.enabled


                                hoverEnabled:
                                    true


                                cursorShape:
                                    Qt.PointingHandCursor


                                onClicked:
                                    root.toggleDiscovery()
                            }
                        }
                    }


                    // ============================================
                    // ERROR
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

                            weight:
                                Nexa.Theme.fontWeightMedium
                        }
                    }


                    // ============================================
                    // DEVICE SCROLLER
                    // ============================================

                    Flickable {
                        id: deviceFlick


                        Layout.fillWidth:
                            true

                        Layout.fillHeight:
                            true


                        clip:
                            true


                        contentWidth:
                            width

                        contentHeight:
                            deviceColumn.height


                        boundsBehavior:
                            Flickable.StopAtBounds

                        flickDeceleration:
                            Nexa.Theme.flickDeceleration

                        maximumFlickVelocity:
                            Nexa.Theme.flickVelocityMax

                        pixelAligned: true

                        ScrollBar.vertical: ScrollBar {
                            id: btScrollBar
                            policy: ScrollBar.AsNeeded

                            contentItem: Rectangle {
                                implicitWidth: 3
                                radius: width / 2
                                color: Qt.rgba(
                                    Nexa.Theme.text.r,
                                    Nexa.Theme.text.g,
                                    Nexa.Theme.text.b,
                                    btScrollBar.hovered ? 0.5 : 0.18
                                )

                                Behavior on color {
                                    ColorAnimation { duration: Nexa.Theme.animationFast }
                                }
                            }

                            background: null
                        }


                        Column {
                            id: deviceColumn


                            width:
                                deviceFlick.width


                            spacing:
                                Nexa.Theme.spacingXs


                            // ====================================
                            // CONNECTED
                            // ====================================

                            Text {
                                visible:
                                    root.connectedDevices.length > 0


                                width:
                                    parent.width

                                height:
                                    visible
                                    ? implicitHeight
                                    : 0


                                text:
                                    "Connected"


                                color:
                                    Nexa.Theme.primary


                                font {
                                    family:
                                        Nexa.Theme.fontFamily

                                    pixelSize:
                                        Nexa.Theme.fontSize2Xs

                                    weight:
                                        Nexa.Theme.fontWeightDemiBold
                                }
                            }


                            Repeater {
                                model:
                                    root.connectedDevices


                                DeviceCard {
                                    required property var modelData

                                    deviceData:
                                        modelData
                                }
                            }


                            // ====================================
                            // PAIRED
                            // ====================================

                            Text {
                                visible:
                                    root.pairedDevices.length > 0


                                width:
                                    parent.width

                                height:
                                    visible
                                    ? implicitHeight
                                    : 0


                                topPadding:
                                    visible
                                    ? Nexa.Theme.spacingXs
                                    : 0


                                text:
                                    "Paired"


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


                            Repeater {
                                model:
                                    root.pairedDevices


                                DeviceCard {
                                    required property var modelData

                                    deviceData:
                                        modelData
                                }
                            }


                            // ====================================
                            // AVAILABLE
                            // ====================================

                            Text {
                                visible:
                                    root.availableDevices.length > 0


                                width:
                                    parent.width

                                height:
                                    visible
                                    ? implicitHeight
                                    : 0


                                topPadding:
                                    visible
                                    ? Nexa.Theme.spacingXs
                                    : 0


                                text:
                                    "Available"


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


                            Repeater {
                                model:
                                    root.availableDevices


                                DeviceCard {
                                    required property var modelData

                                    deviceData:
                                        modelData
                                }
                            }


                            // ====================================
                            // EMPTY
                            // ====================================

                            Item {
                                visible:
                                    root.deviceCatalog.length === 0


                                width:
                                    parent.width

                                height:
                                    visible
                                    ? 180
                                    : 0


                                Column {
                                    anchors.centerIn:
                                        parent


                                    spacing:
                                        Nexa.Theme.spacingSm


                                    Text {
                                        anchors.horizontalCenter:
                                            parent.horizontalCenter


                                        text:
                                            root.enabled
                                            ? "󰂯"
                                            : "󰂲"


                                        color:
                                            root.scanning
                                            ? Nexa.Theme.primary
                                            : Nexa.Theme.mutedText


                                        font {
                                            family:
                                                Nexa.Theme.iconFontFamily

                                            pixelSize:
                                                Nexa.Theme.iconLg
                                        }
                                    }


                                    Text {
                                        anchors.horizontalCenter:
                                            parent.horizontalCenter


                                        text:
                                            !root.enabled
                                            ? "Bluetooth is disabled"

                                            : root.scanning
                                                ? "Searching for nearby devices…"

                                                : "No Bluetooth devices"


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


                    // ============================================
                    // SUMMARY
                    // ============================================

                    RowLayout {
                        visible:
                            root.enabled
                            && root.deviceCatalog.length > 0


                        Layout.fillWidth:
                            true


                        spacing:
                            Nexa.Theme.spacingXs


                        Text {
                            text:
                                root.connectedDevices.length
                                + " connected"


                            color:
                                root.connectedDevices.length > 0
                                ? Nexa.Theme.primary
                                : Nexa.Theme.mutedText


                            font {
                                family:
                                    Nexa.Theme.fontFamily

                                pixelSize:
                                    Nexa.Theme.fontSize2Xs
                            }
                        }


                        Text {
                            text: "•"

                            color:
                                Nexa.Theme.divider
                        }


                        Text {
                            text:
                                root.pairedDevices.length
                                + " paired"


                            color:
                                Nexa.Theme.mutedText


                            font {
                                family:
                                    Nexa.Theme.fontFamily

                                pixelSize:
                                    Nexa.Theme.fontSize2Xs
                            }
                        }


                        Text {
                            text: "•"

                            color:
                                Nexa.Theme.divider
                        }


                        Text {
                            text:
                                root.availableDevices.length
                                + " available"


                            color:
                                Nexa.Theme.mutedText


                            font {
                                family:
                                    Nexa.Theme.fontFamily

                                pixelSize:
                                    Nexa.Theme.fontSize2Xs
                            }
                        }


                        Item {
                            Layout.fillWidth:
                                true
                        }


                        Text {
                            visible:
                                root.scanning


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
                                    root.scanning


                                from: 0
                                to: 360

                                duration: 1200

                                loops:
                                    Animation.Infinite
                            }
                        }
                    }
                }
            }
        }
    }
}
