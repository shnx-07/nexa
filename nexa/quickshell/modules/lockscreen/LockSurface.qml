import QtQuick
import QtQuick.Controls
import QtMultimedia

import Quickshell
import Quickshell.Io

import "../../theme" as Nexa


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

        source:
            root.wallpaperType === "image"
            ? root.fileUrl(
                root.wallpaperPath
            )
            : ""

        fillMode:
            Image.PreserveAspectCrop

        asynchronous: true
        cache: true

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
        // ILLUMINATED AVATAR RING
        // ========================================================

        Rectangle {
            anchors.horizontalCenter:
                parent.horizontalCenter

            width: 90
            height: 90

            radius:
                width / 2

            color:
                Qt.rgba(
                    Nexa.Theme.surfaceContainerLow.r,
                    Nexa.Theme.surfaceContainerLow.g,
                    Nexa.Theme.surfaceContainerLow.b,
                    0.82
                )

            border.width: Nexa.Theme.borderThin
            border.color: passwordInput.activeFocus
                ? Nexa.Theme.primary
                : Nexa.Theme.border

            Behavior on border.color {
                ColorAnimation { duration: Nexa.Theme.animationFast }
            }

            Text {
                anchors.centerIn:
                    parent

                text:
                    root.username.length > 0
                    ? root.username
                        .charAt(0)
                        .toUpperCase()
                    : "N"

                color:
                    Nexa.Theme.text


                font {
                    family:
                        Nexa.Theme.fontFamily

                    pixelSize: 36

                    weight:
                        Nexa.Theme.fontWeightDemiBold
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

            width:
                parent.width

            height: 52

            radius: 14


            color:
                Qt.rgba(
                    Nexa.Theme.surface.r,
                    Nexa.Theme.surface.g,
                    Nexa.Theme.surface.b,
                    passwordInput.activeFocus
                    ? 0.90
                    : 0.70
                )


            border.width: 1


            border.color:
                root.authFailed
                ? Nexa.Theme.error
                : passwordInput.activeFocus
                    ? Nexa.Theme.primary
                    : Nexa.Theme.border


            Behavior on color {
                ColorAnimation {
                    duration: 150
                }
            }


            Behavior on border.color {
                ColorAnimation {
                    duration: 150
                }
            }


            Row {
                anchors {
                    fill: parent

                    leftMargin: 17
                    rightMargin: 9
                }

                spacing: 8


                TextInput {
                    id: passwordInput

                    width:
                        parent.width
                        - unlockButton.width
                        - parent.spacing

                    height:
                        parent.height

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

                Rectangle {
                    id: unlockButton

                    anchors.verticalCenter:
                        parent.verticalCenter

                    width: 36
                    height: 36

                    radius: 10


                    opacity:
                        root.authenticating
                        ? 0.55
                        : 1


                    color:
                        unlockMouse.containsMouse
                        && !root.authenticating
                        ? Nexa.Theme.hover
                        : "transparent"


                    scale:
                        unlockMouse.pressed
                        && !root.authenticating
                        ? 0.92
                        : 1


                    Behavior on scale {
                        NumberAnimation {
                            duration: 100
                        }
                    }


                    Text {
                        anchors.centerIn:
                            parent

                        text:
                            root.authenticating
                            ? "…"
                            : root.authenticated
                                ? "✓"
                                : "→"

                        color:
                            root.authFailed
                            ? Nexa.Theme.error
                            : Nexa.Theme.text


                        font {
                            family:
                                Nexa.Theme.fontFamily

                            pixelSize: 21

                            weight:
                                Nexa.Theme.fontWeightMedium
                        }
                    }


                    MouseArea {
                        id: unlockMouse

                        anchors.fill:
                            parent

                        enabled:
                            !root.authenticating

                        hoverEnabled: true

                        cursorShape:
                            Qt.PointingHandCursor


                        onClicked:
                            root.submitPassword()
                    }
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
        running: true


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
