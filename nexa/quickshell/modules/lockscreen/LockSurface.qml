import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtMultimedia
import Qt5Compat.GraphicalEffects

import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.UPower

import "../../theme" as Nexa
import "../../theme/components" as NexaUI


Item {
    id: root

    anchors.fill: parent
    focus: true

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
        command: [
            "sh", "-c",
            "for f in \"$HOME/.face\" \"$HOME/.face.icon\" \"$HOME/.config/nexa/avatar.png\" \"$HOME/.config/nexa/avatar.jpg\" \"$HOME/.config/nexa/avatar.svg\" \"$HOME/.config/nexa/avatar.webp\" \"$HOME/.config/nexa/avatar.jpeg\" \"$HOME/.config/nexa/avatars/cyber_neon.svg\"; do "
            + "if [ -f \"$f\" ]; then echo \"$f\"; exit 0; fi; done"
        ]
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

    readonly property var batteryDev: UPower.displayDevice
    readonly property bool batteryAvailable: batteryDev && batteryDev.isBattery
    readonly property int batteryPct: batteryDev ? Math.round(batteryDev.percentage * 100) : 100
    readonly property bool isCharging: batteryDev ? (batteryDev.charging || !UPower.onBattery) : false

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

        const separator =
            text.indexOf("|")

        if (separator <= 0) {
            console.warn(
                "NEXA lockscreen: invalid wallpaper info:",
                text
            )

            return
        }


        wallpaperType =
            text.substring(
                0,
                separator
            )

        wallpaperPath =
            text.substring(
                separator + 1
            )

        wallpaperLoaded = true


        console.log(
            "NEXA lockscreen wallpaper:",
            wallpaperType,
            wallpaperPath
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

        sourceSize.width: 1920
        sourceSize.height: 1080

        source:
            (root.visible && root.wallpaperType === "image")
            ? root.fileUrl(
                root.wallpaperPath
            )
            : ""

        fillMode:
            Image.PreserveAspectCrop

        asynchronous: true
        cache: false

        visible:
            root.wallpaperLoaded
            && root.wallpaperType === "image"
    }


    // ============================================================
    // WALLPAPER - GIF
    // ============================================================

    AnimatedImage {
        id: gifWallpaper

        anchors.fill: parent

        source:
            root.wallpaperType === "gif"
            ? root.fileUrl(
                root.wallpaperPath
            )
            : ""

        fillMode:
            Image.PreserveAspectCrop

        asynchronous: true
        cache: true

        playing:
            visible

        visible:
            root.wallpaperLoaded
            && root.wallpaperType === "gif"
    }


    // ============================================================
    // WALLPAPER - VIDEO
    // ============================================================

    MediaPlayer {
        id: videoPlayer

        source:
            root.wallpaperType === "video"
            ? root.fileUrl(
                root.wallpaperPath
            )
            : ""

        loops:
            MediaPlayer.Infinite


        audioOutput:
            AudioOutput {
                muted: true
            }


        videoOutput:
            videoOutput
    }


    VideoOutput {
        id: videoOutput

        anchors.fill: parent

        fillMode:
            VideoOutput.PreserveAspectCrop

        visible:
            root.wallpaperLoaded
            && root.wallpaperType === "video"
    }


    Connections {
        target: root


        function onWallpaperLoadedChanged() {
            if (
                root.wallpaperLoaded
                && root.wallpaperType === "video"
            ) {
                videoPlayer.position = 0
                videoPlayer.play()
            } else {
                videoPlayer.stop()
            }
        }


        function onWallpaperTypeChanged() {
            if (
                root.wallpaperLoaded
                && root.wallpaperType === "video"
            ) {
                videoPlayer.position = 0
                videoPlayer.play()
            } else {
                videoPlayer.stop()
            }
        }
    }


    // ============================================================
    // BASE OVERLAY
    // ============================================================

    Rectangle {
        anchors.fill: parent

        color:
            Qt.rgba(
                Nexa.Theme.background.r,
                Nexa.Theme.background.g,
                Nexa.Theme.background.b,
                root.loginVisible
                ? 0.42
                : 0.25
            )


        Behavior on color {
            ColorAnimation {
                duration: 220
            }
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
            color: Qt.rgba(0.06, 0.08, 0.12, 0.65)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.08)

            Row {
                id: dateRow
                anchors.centerIn: parent
                spacing: 8

                Rectangle {
                    width: 6; height: 6; radius: 3
                    color: Nexa.Theme.primary
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Qt.formatDateTime(new Date(), "dddd, d MMMM")
                    color: Nexa.Theme.text
                    font.family: Nexa.Theme.fontFamily
                    font.pixelSize: 12
                    font.weight: Nexa.Theme.fontWeightMedium
                }
            }
        }

        Item { Layout.fillWidth: true }

        // Right System Status Pill (Battery + Host)
        Rectangle {
            implicitWidth: telemetryRow.implicitWidth + 24
            implicitHeight: 32
            radius: 16
            color: Qt.rgba(0.06, 0.08, 0.12, 0.65)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.08)

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
                        color: root.isCharging ? "#34d399" : (root.batteryPct <= 20 ? "#ef4444" : Nexa.Theme.text)
                        font.family: Nexa.Theme.iconFontFamily
                        font.pixelSize: 15
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.batteryPct + "%"
                        color: Nexa.Theme.text
                        font.family: Nexa.Theme.monoFontFamily
                        font.pixelSize: 12
                    }
                }

                Rectangle {
                    width: 1; height: 12
                    color: Qt.rgba(1, 1, 1, 0.15)
                    anchors.verticalCenter: parent.verticalCenter
                }

                // Host OS Badge
                Row {
                    spacing: 6
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "󰣇"
                        color: Nexa.Theme.primary
                        font.family: Nexa.Theme.iconFontFamily
                        font.pixelSize: 14
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "cachyos"
                        color: Nexa.Theme.mutedText
                        font.family: Nexa.Theme.fontFamily
                        font.pixelSize: 12
                        font.weight: Nexa.Theme.fontWeightMedium
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
                Nexa.Theme.text


            font {
                family:
                    Nexa.Theme.fontFamily

                pixelSize:
                    root.loginVisible
                    ? 58
                    : 78

                weight:
                    Nexa.Theme.fontWeightDemiBold
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
                Nexa.Theme.mutedText


            font {
                family:
                    Nexa.Theme.fontFamily

                pixelSize:
                    Nexa.Theme.fontSizeMd

                weight:
                    Nexa.Theme.fontWeightMedium
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
                    ? Nexa.Theme.primary
                    : Qt.rgba(1, 1, 1, 0.14)

                Behavior on border.color {
                    ColorAnimation { duration: 250 }
                }

                // Breathing glow animation when focused
                SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    running: passwordInput.activeFocus
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
                    color: "#12131c"
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
                        GradientStop { position: 0.0; color: Nexa.Theme.primary }
                        GradientStop { position: 1.0; color: Nexa.Theme.tertiary }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: root.username.length > 0 ? root.username.charAt(0).toUpperCase() : "N"
                        color: "#ffffff"
                        font.family: Nexa.Theme.fontFamily
                        font.pixelSize: 36
                        font.weight: Nexa.Theme.fontWeightBold
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
                Nexa.Theme.text


            font {
                family:
                    Nexa.Theme.fontFamily

                pixelSize: 18

                weight:
                    Nexa.Theme.fontWeightMedium
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
                Nexa.Theme.surface.r,
                Nexa.Theme.surface.g,
                Nexa.Theme.surface.b,
                passwordInput.activeFocus ? 0.90 : 0.70
            )

            border.width: 1
            border.color: root.authFailed
                ? Nexa.Theme.error
                : passwordInput.activeFocus
                    ? Nexa.Theme.primary
                    : Qt.rgba(1, 1, 1, 0.12)

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
                    color: passwordInput.activeFocus ? Nexa.Theme.primary : Nexa.Theme.mutedText
                    font.family: Nexa.Theme.iconFontFamily
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
                        Nexa.Theme.text

                    selectionColor:
                        Nexa.Theme.primary

                    selectedTextColor:
                        Nexa.Theme.background

                    echoMode:
                        TextInput.Password

                    passwordCharacter:
                        "●"

                    clip: true


                    font {
                        family:
                            Nexa.Theme.fontFamily

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
                            Nexa.Theme.mutedText


                        font {
                            family:
                                Nexa.Theme.fontFamily

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
                ? Nexa.Theme.error
                : root.authenticated
                    ? Nexa.Theme.primary
                    : Nexa.Theme.mutedText


            font {
                family:
                    Nexa.Theme.fontFamily

                pixelSize: 12

                weight:
                    root.authFailed
                    || root.authenticated
                    ? Nexa.Theme.fontWeightMedium
                    : Nexa.Theme.fontWeightRegular
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
        color: Qt.rgba(0.06, 0.08, 0.12, 0.75)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.10)
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
                color: "#161824"
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
                    color: Nexa.Theme.primary
                    font.family: Nexa.Theme.iconFontFamily
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
                    color: Nexa.Theme.text
                    font.family: Nexa.Theme.fontFamily
                    font.pixelSize: 12
                    font.weight: Nexa.Theme.fontWeightBold
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    text: root.lockPlayer ? root.lockPlayer.trackArtist : ""
                    color: Nexa.Theme.mutedText
                    font.family: Nexa.Theme.fontFamily
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }
            }

            // Play / Pause Quick Button
            Rectangle {
                Layout.preferredWidth: 34
                Layout.preferredHeight: 34
                radius: 17
                color: mediaBtnMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(255, 255, 255, 0.08)

                Text {
                    anchors.centerIn: parent
                    text: (root.lockPlayer && root.lockPlayer.playbackState === MprisPlaybackState.Playing) ? "󰏤" : "󰐊"
                    color: Nexa.Theme.text
                    font.family: Nexa.Theme.iconFontFamily
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
            color: sleepMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(0.06, 0.08, 0.12, 0.65)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.10)
            scale: sleepMouse.pressed ? 0.92 : 1.0
            Behavior on scale { NumberAnimation { duration: 100 } }

            Text {
                anchors.centerIn: parent
                text: "󰤄"
                color: Nexa.Theme.text
                font.family: Nexa.Theme.iconFontFamily
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
            color: rebootMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(0.06, 0.08, 0.12, 0.65)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.10)
            scale: rebootMouse.pressed ? 0.92 : 1.0
            Behavior on scale { NumberAnimation { duration: 100 } }

            Text {
                anchors.centerIn: parent
                text: "󰜉"
                color: Nexa.Theme.text
                font.family: Nexa.Theme.iconFontFamily
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
            color: powerMouse.containsMouse ? Qt.rgba(239/255, 68/255, 68/255, 0.25) : Qt.rgba(0.06, 0.08, 0.12, 0.65)
            border.width: 1
            border.color: powerMouse.containsMouse ? "#ef4444" : Qt.rgba(1, 1, 1, 0.10)
            scale: powerMouse.pressed ? 0.92 : 1.0
            Behavior on scale { NumberAnimation { duration: 100 } }

            Text {
                anchors.centerIn: parent
                text: "󰐥"
                color: powerMouse.containsMouse ? "#ef4444" : Nexa.Theme.text
                font.family: Nexa.Theme.iconFontFamily
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
                Nexa.Theme.surfaceContainerLow.r,
                Nexa.Theme.surfaceContainerLow.g,
                Nexa.Theme.surfaceContainerLow.b,
                0.68
            )

        border.width: Nexa.Theme.borderThin
        border.color: Qt.rgba(255/255, 255/255, 255/255, 0.10)

        SequentialAnimation on opacity {
            loops: Animation.Infinite
            running: !root.loginVisible

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
                Nexa.Theme.mutedText


            font {
                family:
                    Nexa.Theme.fontFamily

                pixelSize: 12
                weight: Nexa.Theme.fontWeightMedium
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
