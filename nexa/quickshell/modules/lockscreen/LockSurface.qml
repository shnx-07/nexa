import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtMultimedia
import Qt5Compat.GraphicalEffects

import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

import "../../NewNexaUI" as NexaUI
import "../../services" as Services


Item {
    id: root

    anchors.fill: parent
    focus: true

    property bool still: false
    property bool unlocking: false
    // ============================================================
    // SIGNALS
    // ============================================================

    // The preview does not unlock anything yet.
    // Later LockScreen.qml will use this signal to release
    // the real WlSessionLock.
    signal authenticationSucceeded()


    // ============================================================
    // PATHS
    // ============================================================

    readonly property string homeDir:
        Quickshell.env("HOME")

    readonly property string nexad:
        homeDir + "/.config/nexa/rust/target/release/nexad"

    readonly property string username:
        Quickshell.env("USER")


    // ============================================================
    // WALLPAPER STATE
    // ============================================================

    property string wallpaperPath: ""
    property string wallpaperProxy: ""
    property string wallpaperType: ""

    property bool wallpaperLoaded: false


    // ============================================================
    // LOGIN / AUTH STATE
    // ============================================================

    property bool loginVisible: false

    property bool authenticating: false
    property bool authenticated: false

    property string authMessage: ""
    property bool authFailed: false

    // ============================================================
    // PROFILE PICTURE / AVATAR AUTO-DETECTION
    // ============================================================

    property string avatarUrl: ""
    property bool avatarLoaded: false

    Process {
        id: avatarFinder
        command: [Quickshell.env("HOME") + "/.config/nexa/scripts/nexa-avatar.sh", "get"]
        running: true
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: path => {
                const p = path.trim()
                if (p.length > 0) {
                    root.avatarUrl = "file://" + p
                    root.avatarLoaded = true
                }
            }
        }
    }

    // ============================================================
    // MPRIS NOW PLAYING ON LOCKSCREEN
    // ============================================================

    readonly property var lockPlayer: {
        const list = Mpris.players.values
        if (!list || list.length === 0) return null
        for (let i = 0; i < list.length; ++i) {
            if (list[i] && list[i].playbackState === MprisPlaybackState.Playing) return list[i]
        }
        for (let i = 0; i < list.length; ++i) {
            if (list[i] && list[i].playbackState === MprisPlaybackState.Paused && (list[i].trackTitle || list[i].trackArtist)) return list[i]
        }
        return null
    }

    readonly property bool hasLockMedia:
        lockPlayer !== null && (lockPlayer.trackTitle !== "" || lockPlayer.trackArtist !== "")

    // ============================================================
    // SYSTEM TELEMETRY (BATTERY / HOST)
    // ============================================================

    readonly property bool batteryAvailable: true
    readonly property int batteryPct: Services.SystemState.batteryPercentage
    readonly property bool isCharging: Services.SystemState.batteryCharging

    function suspendSystem() {
        Quickshell.execDetached(["systemctl", "suspend"])
    }
    function rebootSystem() {
        Quickshell.execDetached(["systemctl", "reboot"])
    }
    function powerOffSystem() {
        Quickshell.execDetached(["systemctl", "poweroff"])
    }


    // ============================================================
    // HELPERS
    // ============================================================

    function fileUrl(path) {
        return "file://" + encodeURI(path)
    }


    function loadLockWallpaper() {
        wallpaperLoaded = false

        lockInfoProcess.command = [
            nexad,
            "wallpaper",
            "lock-info"
        ]

        lockInfoProcess.running = true
    }


    function parseLockInfo(output) {
        const text =
            String(output).trim()

        const parts =
            text.split("|")

        if (parts.length < 2) {
            console.warn(
                "NEXA lockscreen: invalid wallpaper info:",
                text
            )

            return
        }


        const nextType = parts[0]
        const nextPath = parts[1]
        const nextProxy = parts.length > 2 ? parts[2] : ""

        wallpaperProxy = nextProxy
        wallpaperPath = nextPath
        wallpaperType = nextType
        wallpaperLoaded = true

        console.log(
            "NEXA lockscreen wallpaper:",
            wallpaperType,
            wallpaperPath,
            "proxy:",
            wallpaperProxy
        )
    }


    function showLogin() {
        if (!loginVisible)
            loginVisible = true

        if (!authenticating)
            inactivityTimer.restart()

        Qt.callLater(function() {
            if (!authenticating)
                passwordInput.forceActiveFocus()
        })
    }


    function hideLogin() {
        if (authenticating)
            return

        loginVisible = false

        passwordInput.text = ""

        authMessage = ""
        authFailed = false
        authenticated = false

        root.forceActiveFocus()
    }


    function submitPassword() {
        if (authenticating)
            return

        if (passwordInput.text.length === 0)
            return


        authenticating = true
        authenticated = false
        authFailed = false

        authMessage =
            "Checking password…"

        inactivityTimer.stop()


        // Start PAM process.
        //
        // IMPORTANT:
        // Password is NOT passed in argv.
        // authProcess.onStarted writes it to stdin.
        authProcess.command = [
            nexad,
            "lock",
            "auth"
        ]

        authProcess.running = true
    }


    function handleAuthResult(output) {
        const text =
            String(output).trim()

        authenticating = false


        if (text.length === 0) {
            authenticationFailure(
                "Authentication failed"
            )

            return
        }


        let result

        try {
            result =
                JSON.parse(text)
        } catch (error) {
            console.warn(
                "NEXA lockscreen: invalid auth response:",
                text
            )

            authenticationFailure(
                "Authentication error"
            )

            return
        }


        if (result.success === true) {
            authenticationSuccess()
        } else {
            authenticationFailure(
                "Incorrect password"
            )
        }
    }


    function authenticationSuccess() {
        passwordInput.text = ""

        authenticating = false
        authFailed = false
        authenticated = true

        authMessage = "Authenticated"

        console.log(
            "NEXA lockscreen: authentication successful"
        )

        unlocking = true
        unlockAnimation.start()
    }

    function authenticationFailure(message) {
        passwordInput.text = ""

        authenticating = false
        authenticated = false
        authFailed = true

        authMessage = message


        console.log(
            "NEXA lockscreen: authentication failed"
        )


        failureShake.restart()

        Qt.callLater(function() {
            passwordInput.forceActiveFocus()
        })

        inactivityTimer.restart()
    }


    // ============================================================
    // WALLPAPER INFO PROCESS
    // ============================================================

    Process {
        id: lockInfoProcess

        stdout: StdioCollector {
            onStreamFinished:
                root.parseLockInfo(
                    this.text
                )
        }
    }


    // ============================================================
    // PAM AUTH PROCESS
    // ============================================================

    Process {
        id: authProcess

        stdinEnabled: true


        stdout: StdioCollector {
            onStreamFinished:
                root.handleAuthResult(
                    this.text
                )
        }


        stderr: StdioCollector {
            onStreamFinished: {
                const error =
                    String(this.text).trim()

                if (error.length > 0) {
                    console.warn(
                        "NEXA lockscreen auth backend:",
                        error
                    )
                }
            }
        }


        onStarted: {
            /*
             * Write directly to stdin.
             *
             * The newline is important because the Rust backend
             * now uses read_line().
             *
             * Never console.log() this value.
             */
            write(
                passwordInput.text + "\n"
            )

            /*
             * Clear the QML field immediately after it has been
             * handed to the backend.
             */
            passwordInput.text = ""
        }


        onExited: (exitCode, exitStatus) => {
            /*
             * Normally stdout handles the PAM result.
             *
             * This catches cases where nexad itself failed before
             * producing JSON.
             */
            if (
                root.authenticating
                && exitCode !== 0
            ) {
                root.authenticationFailure(
                    "Authentication backend error"
                )
            }
        }
    }


    // ============================================================
    // WALLPAPER - IMAGE
    // ============================================================

    Image {
        id: staticWallpaper

        anchors.fill: parent

        sourceSize.width: root.still ? 480 : 1920
        sourceSize.height: root.still ? 270 : 1080

        source:
            root.still
            ? Services.LockScreen.wallpaperThumb
            : ((root.visible && root.wallpaperType === "image")
                ? root.fileUrl(root.wallpaperPath)
                : "")

        fillMode:
            Image.PreserveAspectCrop

        asynchronous: true
        cache: false

        visible:
            root.still
            || (root.wallpaperLoaded && root.wallpaperType === "image")
    }


    // ============================================================
    // WALLPAPER - GIF
    // ============================================================

    AnimatedImage {
        id: gifWallpaper

        anchors.fill: parent

        source:
            (!root.still && root.wallpaperType === "gif")
            ? root.fileUrl(
                root.wallpaperPath
            )
            : ""

        fillMode:
            Image.PreserveAspectCrop

        asynchronous: true
        cache: true

        playing:
            !root.still && visible

        visible:
            !root.still
            && root.wallpaperLoaded
            && root.wallpaperType === "gif"
    }


    // ============================================================
    // WALLPAPER - VIDEO
    // ============================================================

    MediaPlayer {
        id: videoPlayer

        source:
            (!root.still && root.wallpaperType === "video")
            ? (root.wallpaperProxy !== "" ? root.fileUrl(root.wallpaperProxy) : root.fileUrl(root.wallpaperPath))
            : ""

        loops:
            MediaPlayer.Infinite


        audioOutput:
            AudioOutput {
                muted: true
            }


        videoOutput:
            videoOutput

        function checkPlay() {
            if (
                root.visible
                && !root.still
                && root.wallpaperLoaded
                && root.wallpaperType === "video"
            ) {
                if (playbackState !== MediaPlayer.PlayingState) {
                    play()
                }
            } else if (!root.visible) {
                stop()
            }
        }

        onSourceChanged: checkPlay()
    }


    VideoOutput {
        id: videoOutput

        anchors.fill: parent

        fillMode:
            VideoOutput.PreserveAspectCrop

        visible:
            !root.still
            && root.wallpaperLoaded
            && root.wallpaperType === "video"
    }


    Connections {
        target: root


        function onVisibleChanged() {
            videoPlayer.checkPlay()
        }


        function onWallpaperLoadedChanged() {
            videoPlayer.checkPlay()
        }


        function onWallpaperTypeChanged() {
            videoPlayer.checkPlay()
        }

        function onStillChanged() {
            videoPlayer.checkPlay()
        }
    }


    // ============================================================
    // BASE OVERLAY
    // ============================================================

    Rectangle {
        anchors.fill: parent

        color:
            Qt.rgba(
                NexaUI.NexaColors.background.r,
                NexaUI.NexaColors.background.g,
                NexaUI.NexaColors.background.b,
                root.loginVisible
                ? 0.42
                : 0.25
            )


        Behavior on color {
            ColorAnimation {
                duration: 220
            }
        }

        NexaUI.NexaShaderSubstrate {
            anchors.fill: parent
            radius: 0
            showSpecularLine: false
        }
    }

    // ============================================================
    // TOP TELEMETRY BAR (CYBER-MINIMALIST)
    // ============================================================

    RowLayout {
        id: topTelemetryBar
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            margins: 32
        }
        height: 38
        z: 25

        // Left Date Pill
        Rectangle {
            implicitWidth: dateRow.implicitWidth + 24
            implicitHeight: 32
            radius: 16
            color: Qt.rgba(NexaUI.NexaColors.surfaceContainer.r, NexaUI.NexaColors.surfaceContainer.g, NexaUI.NexaColors.surfaceContainer.b, 0.65)
            border.width: 1
            border.color: NexaUI.NexaColors.borderSubtle

            Row {
                id: dateRow
                anchors.centerIn: parent
                spacing: 8

                Rectangle {
                    width: 6; height: 6; radius: 3
                    color: NexaUI.NexaColors.primary
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Qt.formatDateTime(new Date(), "dddd, d MMMM")
                    color: NexaUI.NexaColors.text
                    font.family: NexaUI.NexaTypography.familyBody
                    font.pixelSize: 12
                    font.weight: Font.Medium
                }
            }
        }

        Item { Layout.fillWidth: true }

        // Right System Status Pill (Battery + Host)
        Rectangle {
            implicitWidth: telemetryRow.implicitWidth + 24
            implicitHeight: 32
            radius: 16
            color: Qt.rgba(NexaUI.NexaColors.surfaceContainer.r, NexaUI.NexaColors.surfaceContainer.g, NexaUI.NexaColors.surfaceContainer.b, 0.65)
            border.width: 1
            border.color: NexaUI.NexaColors.borderSubtle

            Row {
                id: telemetryRow
                anchors.centerIn: parent
                spacing: 14

                // Battery Badge
                Row {
                    spacing: 6
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.isCharging ? "󰂄" : (root.batteryPct > 20 ? "󰁹" : "󰂃")
                        color: root.isCharging ? NexaUI.NexaColors.success : (root.batteryPct <= 20 ? NexaUI.NexaColors.error : NexaUI.NexaColors.text)
                        font.family: NexaUI.NexaTypography.familyIcon
                        font.pixelSize: 15
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.batteryPct + "%"
                        color: NexaUI.NexaColors.text
                        font.family: NexaUI.NexaTypography.familyMono
                        font.pixelSize: 12
                    }
                }

                Rectangle {
                    width: 1; height: 12
                    color: NexaUI.NexaColors.borderSubtle
                    anchors.verticalCenter: parent.verticalCenter
                }

                // Host OS Badge
                Row {
                    spacing: 6
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "󰣇"
                        color: NexaUI.NexaColors.primary
                        font.family: NexaUI.NexaTypography.familyIcon
                        font.pixelSize: 14
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "cachyos"
                        color: NexaUI.NexaColors.mutedText
                        font.family: NexaUI.NexaTypography.familyBody
                        font.pixelSize: 12
                        font.weight: Font.Medium
                    }
                }
            }
        }
    }

    // ============================================================
    // CLOCK
    // ============================================================

    Column {
        id: clockArea

        anchors {
            horizontalCenter:
                parent.horizontalCenter

            top:
                parent.top

            topMargin:
                root.loginVisible
                ? 70
                : 120
        }

        Behavior on anchors.topMargin {
            NumberAnimation {
                duration: 320
                easing.type: Easing.OutQuint
            }
        }

        spacing: 7


        Text {
            id: clockText

            anchors.horizontalCenter:
                parent.horizontalCenter

            text:
                Qt.formatDateTime(
                    new Date(),
                    "hh:mm"
                )

            color:
                NexaUI.NexaColors.text


            font {
                family:
                    NexaUI.NexaTypography.familyBody

                pixelSize:
                    root.loginVisible
                    ? 58
                    : 78

                weight:
                    Font.DemiBold
            }


            Behavior on font.pixelSize {
                NumberAnimation {
                    duration: 320
                    easing.type: Easing.OutQuint
                }
            }
        }


        Text {
            id: dateText

            anchors.horizontalCenter:
                parent.horizontalCenter

            text:
                Qt.formatDateTime(
                    new Date(),
                    "dddd, d MMMM"
                )

            color:
                NexaUI.NexaColors.mutedText


            font {
                family:
                    NexaUI.NexaTypography.familyBody

                pixelSize:
                    NexaUI.NexaTypography.sizeMd

                weight:
                    Font.Medium
            }
        }
    }


    // ============================================================
    // LOGIN PANEL
    // ============================================================

    Column {
        id: loginPanel

        z: 20

        anchors {
            horizontalCenter:
                parent.horizontalCenter

            verticalCenter:
                parent.verticalCenter

            verticalCenterOffset: 55
        }

        width: 340
        spacing: 16


        visible:
            opacity > 0


        opacity:
            root.loginVisible
            ? 1
            : 0


        scale:
            root.loginVisible
            ? 1
            : 0.94


        transform:
            Translate {
                id: loginShake

                x: 0
            }


        Behavior on opacity {
            NumberAnimation {
                duration: 220
                easing.type: Easing.OutQuint
            }
        }


        Behavior on scale {
            NumberAnimation {
                duration: 280
                easing.type: Easing.OutQuint
            }
        }


        // ========================================================
        // ILLUMINATED AVATAR RING & PROFILE PICTURE
        // ========================================================

        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 104
            height: 104

            // Pulsing Ambient Halo Ring
            Rectangle {
                id: outerHaloRing
                anchors.fill: parent
                radius: width / 2
                color: "transparent"
                border.width: passwordInput.activeFocus ? 2 : 1
                border.color: passwordInput.activeFocus
                    ? NexaUI.NexaColors.primary
                    : NexaUI.NexaColors.borderSubtle

                Behavior on border.color {
                    ColorAnimation { duration: 250 }
                }

                // Breathing glow animation when focused
                SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    running: passwordInput.activeFocus && root.visible
                    NumberAnimation { from: 0.5; to: 1.0; duration: 900; easing.type: Easing.InOutSine }
                    NumberAnimation { from: 1.0; to: 0.5; duration: 900; easing.type: Easing.InOutSine }
                }
            }

            // Inner Profile Picture Container
            Item {
                id: innerAvatarCard
                anchors.centerIn: parent
                width: 92
                height: 92

                layer.enabled: true
                layer.effect: OpacityMask {
                    maskSource: Rectangle {
                        width: innerAvatarCard.width
                        height: innerAvatarCard.height
                        radius: innerAvatarCard.width / 2
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: NexaUI.NexaColors.surfaceContainerLowest
                }

                Image {
                    id: avatarImg
                    anchors.fill: parent
                    source: root.avatarUrl
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    visible: root.avatarLoaded && avatarImg.status === Image.Ready
                }

                // Fallback initial badge if image fails/empty
                Rectangle {
                    anchors.fill: parent
                    visible: !avatarImg.visible
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: NexaUI.NexaColors.primary }
                        GradientStop { position: 1.0; color: NexaUI.NexaColors.tertiary }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: root.username.length > 0 ? root.username.charAt(0).toUpperCase() : "N"
                        color: NexaUI.NexaColors.onPrimary
                        font.family: NexaUI.NexaTypography.familyBody
                        font.pixelSize: 36
                        font.weight: Font.Bold
                    }
                }
            }
        }


        // ========================================================
        // USERNAME
        // ========================================================

        Text {
            anchors.horizontalCenter:
                parent.horizontalCenter

            text:
                root.username

            color:
                NexaUI.NexaColors.text


            font {
                family:
                    NexaUI.NexaTypography.familyBody

                pixelSize: 18

                weight:
                    Font.Medium
            }
        }


        // ========================================================
        // PASSWORD BOX
        // ========================================================

        Rectangle {
            id: passwordBox

            width: parent.width
            height: 50
            radius: 25

            color: Qt.rgba(
                NexaUI.NexaColors.surface.r,
                NexaUI.NexaColors.surface.g,
                NexaUI.NexaColors.surface.b,
                passwordInput.activeFocus ? 0.90 : 0.70
            )

            border.width: 1
            border.color: root.authFailed
                ? NexaUI.NexaColors.error
                : passwordInput.activeFocus
                    ? NexaUI.NexaColors.primary
                    : NexaUI.NexaColors.borderSubtle

            Behavior on color {
                ColorAnimation { duration: 150 }
            }

            Behavior on border.color {
                ColorAnimation { duration: 150 }
            }

            Row {
                anchors {
                    fill: parent
                    leftMargin: 16
                    rightMargin: 8
                }
                spacing: 10

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰌾"
                    color: passwordInput.activeFocus ? NexaUI.NexaColors.primary : NexaUI.NexaColors.mutedText
                    font.family: NexaUI.NexaTypography.familyIcon
                    font.pixelSize: 16

                    Behavior on color {
                        ColorAnimation { duration: 150 }
                    }
                }

                TextInput {
                    id: passwordInput

                    width: parent.width - unlockButton.width - 26 - parent.spacing
                    height: parent.height

                    enabled:
                        !root.authenticating

                    verticalAlignment:
                        TextInput.AlignVCenter

                    color:
                        NexaUI.NexaColors.text

                    selectionColor:
                        NexaUI.NexaColors.primary

                    selectedTextColor:
                        NexaUI.NexaColors.background

                    echoMode:
                        TextInput.Password

                    passwordCharacter:
                        "●"

                    clip: true


                    font {
                        family:
                            NexaUI.NexaTypography.familyBody

                        pixelSize: 16
                    }


                    Text {
                        anchors {
                            left:
                                parent.left

                            verticalCenter:
                                parent.verticalCenter
                        }

                        visible:
                            passwordInput.text.length === 0
                            && !passwordInput.activeFocus

                        text:
                            root.authenticating
                            ? "Checking…"
                            : "Password"

                        color:
                            NexaUI.NexaColors.mutedText


                        font {
                            family:
                                NexaUI.NexaTypography.familyBody

                            pixelSize: 14
                        }
                    }


                    onTextEdited: {
                        root.authFailed = false
                        root.authMessage = ""

                        inactivityTimer.restart()
                    }


                    Keys.onPressed: event => {
                        inactivityTimer.restart()

                        if (
                            event.key === Qt.Key_Return
                            || event.key === Qt.Key_Enter
                        ) {
                            root.submitPassword()

                            event.accepted = true
                        }
                    }
                }


                // =================================================
                // UNLOCK / AUTH BUTTON
                // =================================================

                NexaUI.NexaButton {
                    id: unlockButton
                    anchors.verticalCenter: parent.verticalCenter
                    implicitWidth: 36
                    implicitHeight: 36
                    horizontalPadding: 0
                    text: root.authenticating ? "…" : (root.authenticated ? "✓" : "→")
                    interactive: !root.authenticating
                    onClicked: root.submitPassword()
                }
            }
        }


        // ========================================================
        // AUTH STATUS
        // ========================================================

        Text {
            anchors.horizontalCenter:
                parent.horizontalCenter

            text:
                root.authMessage.length > 0
                ? root.authMessage
                : "Enter password to unlock"

            color:
                root.authFailed
                ? NexaUI.NexaColors.error
                : root.authenticated
                    ? NexaUI.NexaColors.primary
                    : NexaUI.NexaColors.mutedText


            font {
                family:
                    NexaUI.NexaTypography.familyBody

                pixelSize: 12

                weight:
                    root.authFailed
                    || root.authenticated
                    ? Font.Medium
                    : Font.Normal
            }
        }
    }


    // ============================================================
    // FAILURE SHAKE
    // ============================================================

    SequentialAnimation {
        id: failureShake

        NumberAnimation {
            target: loginShake
            property: "x"
            to: -10
            duration: 45
        }

        NumberAnimation {
            target: loginShake
            property: "x"
            to: 10
            duration: 70
        }

        NumberAnimation {
            target: loginShake
            property: "x"
            to: -7
            duration: 60
        }

        NumberAnimation {
            target: loginShake
            property: "x"
            to: 7
            duration: 55
        }

        NumberAnimation {
            target: loginShake
            property: "x"
            to: 0
            duration: 45
        }
    }


    // ============================================================
    // AUTH SUCCESS RESET
    //
    // Preview mode only.
    // Once real session locking is enabled, successful auth will
    // unlock instead of returning to the password state.
    // ============================================================

    


    // ============================================================
    // NOW PLAYING MINI CARD (BOTTOM LEFT)
    // ============================================================

    Rectangle {
        id: lockMediaCard
        anchors {
            left: parent.left
            bottom: parent.bottom
            margins: 32
        }
        width: 270
        height: 52
        radius: 16
        color: Qt.rgba(NexaUI.NexaColors.surfaceContainer.r, NexaUI.NexaColors.surfaceContainer.g, NexaUI.NexaColors.surfaceContainer.b, 0.75)
        border.width: 1
        border.color: NexaUI.NexaColors.borderSubtle
        visible: root.hasLockMedia
        z: 25

        RowLayout {
            anchors.fill: parent
            anchors.margins: 7
            spacing: 10

            // Album art thumbnail
            Rectangle {
                Layout.preferredWidth: 38
                Layout.preferredHeight: 38
                radius: 10
                color: NexaUI.NexaColors.surfaceContainerHighest
                clip: true

                Image {
                    anchors.fill: parent
                    source: root.lockPlayer ? root.lockPlayer.trackArtUrl : ""
                    fillMode: Image.PreserveAspectCrop
                    visible: source !== ""
                }

                Text {
                    anchors.centerIn: parent
                    visible: !root.lockPlayer || root.lockPlayer.trackArtUrl === ""
                    text: "󰎆"
                    color: NexaUI.NexaColors.primary
                    font.family: NexaUI.NexaTypography.familyIcon
                    font.pixelSize: 18
                }
            }

            // Track info
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    Layout.fillWidth: true
                    text: root.lockPlayer ? root.lockPlayer.trackTitle : ""
                    color: NexaUI.NexaColors.text
                    font.family: NexaUI.NexaTypography.familyBody
                    font.pixelSize: 12
                    font.weight: Font.Bold
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    text: root.lockPlayer ? root.lockPlayer.trackArtist : ""
                    color: NexaUI.NexaColors.mutedText
                    font.family: NexaUI.NexaTypography.familyBody
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }
            }

            // Play / Pause Quick Button
            Rectangle {
                Layout.preferredWidth: 34
                Layout.preferredHeight: 34
                radius: 17
                color: mediaBtnMouse.containsMouse ? NexaUI.NexaColors.hoverStrong : NexaUI.NexaColors.hover

                Text {
                    anchors.centerIn: parent
                    text: (root.lockPlayer && root.lockPlayer.playbackState === MprisPlaybackState.Playing) ? "󰏤" : "󰐊"
                    color: NexaUI.NexaColors.text
                    font.family: NexaUI.NexaTypography.familyIcon
                    font.pixelSize: 16
                }

                MouseArea {
                    id: mediaBtnMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.lockPlayer) root.lockPlayer.togglePlaying()
                    }
                }
            }
        }
    }

    // ============================================================
    // POWER ACTIONS DECK (BOTTOM RIGHT)
    // ============================================================

    Row {
        id: powerActionsDeck
        anchors {
            right: parent.right
            bottom: parent.bottom
            margins: 32
        }
        spacing: 12
        z: 25

        // Sleep / Suspend Button
        Rectangle {
            width: 38
            height: 38
            radius: 19
            color: sleepMouse.containsMouse ? NexaUI.NexaColors.hoverStrong : Qt.rgba(NexaUI.NexaColors.surfaceContainer.r, NexaUI.NexaColors.surfaceContainer.g, NexaUI.NexaColors.surfaceContainer.b, 0.65)
            border.width: 1
            border.color: NexaUI.NexaColors.borderSubtle
            scale: sleepMouse.pressed ? 0.92 : 1.0
            Behavior on scale { NumberAnimation { duration: 100 } }

            Text {
                anchors.centerIn: parent
                text: "󰤄"
                color: NexaUI.NexaColors.text
                font.family: NexaUI.NexaTypography.familyIcon
                font.pixelSize: 16
            }

            MouseArea {
                id: sleepMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.suspendSystem()
            }
        }

        // Reboot Button
        Rectangle {
            width: 38
            height: 38
            radius: 19
            color: rebootMouse.containsMouse ? NexaUI.NexaColors.hoverStrong : Qt.rgba(NexaUI.NexaColors.surfaceContainer.r, NexaUI.NexaColors.surfaceContainer.g, NexaUI.NexaColors.surfaceContainer.b, 0.65)
            border.width: 1
            border.color: NexaUI.NexaColors.borderSubtle
            scale: rebootMouse.pressed ? 0.92 : 1.0
            Behavior on scale { NumberAnimation { duration: 100 } }

            Text {
                anchors.centerIn: parent
                text: "󰜉"
                color: NexaUI.NexaColors.text
                font.family: NexaUI.NexaTypography.familyIcon
                font.pixelSize: 16
            }

            MouseArea {
                id: rebootMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.rebootSystem()
            }
        }

        // Power Off Button
        Rectangle {
            width: 38
            height: 38
            radius: 19
            color: powerMouse.containsMouse ? Qt.rgba(NexaUI.NexaColors.error.r, NexaUI.NexaColors.error.g, NexaUI.NexaColors.error.b, 0.25) : Qt.rgba(NexaUI.NexaColors.surfaceContainer.r, NexaUI.NexaColors.surfaceContainer.g, NexaUI.NexaColors.surfaceContainer.b, 0.65)
            border.width: 1
            border.color: powerMouse.containsMouse ? NexaUI.NexaColors.error : NexaUI.NexaColors.borderSubtle
            scale: powerMouse.pressed ? 0.92 : 1.0
            Behavior on scale { NumberAnimation { duration: 100 } }

            Text {
                anchors.centerIn: parent
                text: "󰐥"
                color: powerMouse.containsMouse ? NexaUI.NexaColors.error : NexaUI.NexaColors.text
                font.family: NexaUI.NexaTypography.familyIcon
                font.pixelSize: 16
            }

            MouseArea {
                id: powerMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.powerOffSystem()
            }
        }
    }

    // ============================================================
    // DEVELOPMENT PREVIEW INDICATOR
    // ============================================================

    Rectangle {
        id: bottomPromptPill

        z: 20

        anchors {
            horizontalCenter:
                parent.horizontalCenter

            bottom:
                parent.bottom

            bottomMargin: 32
        }

        width:
            previewText.implicitWidth + 28

        height: 32

        radius: height / 2

        color:
            Qt.rgba(
                NexaUI.NexaColors.surfaceContainerLow.r,
                NexaUI.NexaColors.surfaceContainerLow.g,
                NexaUI.NexaColors.surfaceContainerLow.b,
                0.68
            )

        border.width: NexaUI.NexaTokens.borderThin
        border.color: NexaUI.NexaColors.borderSubtle

        SequentialAnimation on opacity {
            loops: Animation.Infinite
            running: !root.loginVisible && root.visible

            NumberAnimation {
                from: 0.65
                to: 0.95
                duration: 1800
                easing.type: Easing.InOutSine
            }

            NumberAnimation {
                from: 0.95
                to: 0.65
                duration: 1800
                easing.type: Easing.InOutSine
            }
        }

        Text {
            id: previewText

            anchors.centerIn:
                parent

            text:
                root.loginVisible
                ? "NEXA Lock Screen · Secure"
                : "Click or press any key to unlock"

            color:
                NexaUI.NexaColors.mutedText


            font {
                family:
                    NexaUI.NexaTypography.familyBody

                pixelSize: 12
                weight: Font.Medium
            }
        }
    }


    // ============================================================
    // BACKGROUND ACTIVITY DETECTOR
    // ============================================================

    MouseArea {
        id: activityMouse

        z: 10

        anchors.fill:
            parent

        hoverEnabled: true

        acceptedButtons:
            Qt.AllButtons


        onPressed: mouse => {
            root.showLogin()

            mouse.accepted = false
        }


        onPositionChanged: {
            if (!root.authenticating)
                root.showLogin()
        }
    }


    // ============================================================
    // KEYBOARD ACTIVITY
    // ============================================================

    Keys.onPressed: event => {
        if (!root.loginVisible) {
            root.showLogin()

            // First key only wakes the login UI.
            event.accepted = true
        }
    }


    // ============================================================
    // AUTO-HIDE LOGIN
    // ============================================================

    Timer {
        id: inactivityTimer

        interval: 8000

        repeat: false


        onTriggered:
            root.hideLogin()
    }


    // ============================================================
    // CLOCK UPDATE
    // ============================================================

    Timer {
        interval: 1000
        repeat: true
        running: root.visible

        onTriggered: {
            const now =
                new Date()

            clockText.text =
                Qt.formatDateTime(
                    now,
                    "hh:mm"
                )

            dateText.text =
                Qt.formatDateTime(
                    now,
                    "dddd, d MMMM"
                )
        }
    }

    onVisibleChanged: {
        if (root.visible) {
            const now = new Date()
            clockText.text = Qt.formatDateTime(now, "hh:mm")
            dateText.text = Qt.formatDateTime(now, "dddd, d MMMM")
            root.loadLockWallpaper()
        }
    }


    // ============================================================
    // STARTUP
    // ============================================================

    Component.onCompleted: {
        root.y = 0
        unlocking = false

        loadLockWallpaper()
        root.forceActiveFocus()
    }

    Connections {
        target: Services.LockScreen
        function onWallpaperLoadedChanged() {
            if (Services.LockScreen.wallpaperLoaded) {
                root.loadLockWallpaper()
            }
        }
    }


    SequentialAnimation {
        id: unlockAnimation

        NumberAnimation {
            target: root
            property: "y"

            from: 0
            to: -root.height

            duration: 360
            easing.type: Easing.OutQuint
        }

        ScriptAction {
            script: {
                root.authenticationSucceeded()
            }
        }
    }
}
