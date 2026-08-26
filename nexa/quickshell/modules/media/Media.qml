import QtQuick
import QtQuick.Layouts

import Quickshell.Services.Mpris

import "../../theme" as Nexa
import "../../theme/components" as NexaUI
import Quickshell.Io

Item {
  id: root

    // ============================================================
    // RESPONSIBILITY
    //
    // Reusable NEXA media frontend.
    //
    // presentation:
    //
    // compact
    //     artwork + current track
    //     NO progress bar
    //
    // hover
    //     artwork + title + artist
    //     ONE passive progress bar
    //     previous / play-pause / next
    //
    // full
    //     large artwork
    //     title + artist
    //     ONE seekable progress bar
    //     previous / play-pause / next
    //     waveform area reserved for Rust spectrum data
    //
    // No audio analysis happens here.
    // ============================================================


    property string presentation: "full"


    // ============================================================
    // PLAYER
    // ============================================================

    readonly property var player:
        Mpris.players.values.length > 0
        ? Mpris.players.values[0]
        : null


    readonly property bool available:
        player !== null


    readonly property bool playing:
        available
        && player.playbackState
            === MprisPlaybackState.Playing


    readonly property bool paused:
        available
        && player.playbackState
            === MprisPlaybackState.Paused

    // ------------------------------------------------------------
    // 1-MINUTE PAUSE / IDLE TIMEOUT
    //
    // If music is paused for 1 minute (60,000ms), expire context
    // so Dynamic Island resets back to Timer / Idle Clock.
    // When music is played again, immediately reset & show music.
    // ------------------------------------------------------------

    property bool pauseTimeoutExpired: false

    Timer {
        id: pauseTimeoutTimer

        interval: 60000
        running: root.available && root.hasTrack && root.paused && !root.playing
        repeat: false

        onTriggered: {
            root.pauseTimeoutExpired = true
        }
    }

    onPlayingChanged: {
        if (root.playing) {
            root.pauseTimeoutExpired = false
            pauseTimeoutTimer.stop()
        }
    }

    onHasTrackChanged: {
        if (!root.hasTrack) {
            root.pauseTimeoutExpired = false
            pauseTimeoutTimer.stop()
        }
    }

    readonly property bool contextActive:
        available
        && hasTrack
        && (playing || (paused && !pauseTimeoutExpired))


    readonly property bool hasTrack:
        available
        && (
            player.trackTitle !== ""
            || player.trackArtist !== ""
        )


    // ============================================================
    // METADATA
    // ============================================================

    readonly property string title:
        available && player.trackTitle !== ""
        ? player.trackTitle
        : "Nothing playing"


    readonly property string artist:
        available && player.trackArtist !== ""
        ? player.trackArtist
        : "Unknown artist"


    readonly property string artwork:
        available
        ? player.trackArtUrl
        : ""


    // ============================================================
    // POSITION
    // ============================================================

    readonly property real duration:
        available
        && player.lengthSupported
        ? player.length
        : 0


    readonly property real position:
        available
        && player.positionSupported
        ? player.position
        : 0


    readonly property real progress:
        duration > 0
        ? Math.max(
            0,
            Math.min(
                1,
                position / duration
            )
        )
        : 0


    // ============================================================
    // SEEK STATE
    //
    // Only used by FULL presentation.
    // ============================================================

    property bool seeking: false
    property real seekPosition: 0


    readonly property real displayedPosition:
        seeking
        ? seekPosition
        : position


    readonly property real displayedProgress:
        duration > 0
        ? Math.max(
            0,
            Math.min(
                1,
                displayedPosition / duration
            )
        )
        : 0


   

     // ============================================================
    // CAVA SPECTRUM DATA
    //
    // CAVA provides 32 normalized visualizer bands.
    //
    // QML only renders them.
    // ============================================================

    property var spectrumBins: []

    readonly property bool spectrumAvailable:
        spectrumBins
      && spectrumBins.length > 0

    // ============================================================
    // CAVA AUDIO VISUALIZER
    //
    // Starts ONLY when:
    //     music is playing
    //     AND full Music view is visible
    //
    // This avoids running CAVA continuously in the background.
    // ============================================================

    Process {
        id: cavaProcess

        running:
            root.playing
            && root.presentation === "full"

        command: [
            "cava",
            "-p",
            "/home/shnx/.config/nexa/config/cava.conf"
        ]

        stdout: SplitParser {
            splitMarker: "\n"

            onRead: data => {
                const line = data.trim()

                if (line === "")
                    return

                const parts =
                    line.split(";")

                const values = []

                for (let i = 0; i < parts.length; ++i) {
                    if (parts[i] === "")
                        continue

                    const raw =
                        Number(parts[i])

                    if (isNaN(raw))
                        continue

                    values.push(
                        Math.max(
                            0.0,
                            Math.min(
                                1.0,
                                raw / 1000.0
                            )
                        )
                    )
                }

                if (values.length > 0)
                    root.spectrumBins = values
            }
        }

        onRunningChanged: {
            if (!running)
                root.spectrumBins = []
        }
    }

    // ============================================================
    // POSITION REFRESH
    //
    // MPRIS position does not continuously notify while playing.
    // Refresh at a modest rate for the UI.
    // ============================================================

    Timer {
        interval: 500
        repeat: true

        running:
            root.available
            && root.playing
            && root.player.positionSupported
            && !root.seeking

        onTriggered:
            root.player.positionChanged()
    }


    // ============================================================
    // HELPERS
    // ============================================================

    function formatTime(seconds) {
        if (!isFinite(seconds) || seconds < 0)
            return "0:00"

        const total =
            Math.floor(seconds)

        const minutes =
            Math.floor(total / 60)

        const secs =
            total % 60

        return (
            minutes
            + ":"
            + String(secs).padStart(2, "0")
        )
    }


    // ============================================================
    // PLAYBACK ACTIONS
    // ============================================================

    function previous() {
        if (
            available
            && player.canGoPrevious
        ) {
            player.previous()
        }
    }


    function togglePlaying() {
        if (
            available
            && player.canTogglePlaying
        ) {
            player.togglePlaying()
        }
    }


    function next() {
        if (
            available
            && player.canGoNext
        ) {
            player.next()
        }
    }


    // ============================================================
    // SEEK
    // ============================================================

    function updateSeekFromX(x, width) {
        if (
            !available
            || !player.canSeek
            || !player.positionSupported
            || duration <= 0
            || width <= 0
        ) {
            return
        }

        const ratio =
            Math.max(
                0,
                Math.min(
                    1,
                    x / width
                )
            )

        seekPosition =
            ratio * duration
    }


    function commitSeek() {
        if (
            !available
            || !player.canSeek
            || !player.positionSupported
        ) {
            seeking = false
            return
        }

        player.position =
            seekPosition

        seeking = false

        // Immediately refresh after the seek.
        player.positionChanged()
    }


    // ============================================================
    // COMPACT
    //
    // IMPORTANT:
    //
    // There is deliberately NO progress bar here.
    //
    // This prevents the small progress line appearing underneath
    // the Island / near the top bar when collapsed.
    // ============================================================

    Item {
        anchors.fill: parent

        visible:
            root.presentation === "compact"


        RowLayout {
            anchors {
                fill: parent

                leftMargin:
                    Nexa.Theme.spacingMd

                rightMargin:
                    Nexa.Theme.spacingMd
            }

            spacing:
                Nexa.Theme.spacingSm


            // ----------------------------------------------------
            // SMALL ARTWORK
            // ----------------------------------------------------

            Rectangle {
                Layout.preferredWidth: 24
                Layout.preferredHeight: 24

                radius:
                    Nexa.Theme.radiusXs

                color:
                    Nexa.Theme.surfaceContainerHigh

                clip: true


                Image {
                    anchors.fill: parent

                    source:
                        root.artwork

                    fillMode:
                        Image.PreserveAspectCrop

                    visible:
                        root.artwork !== ""
                }


                Text {
                    anchors.centerIn: parent

                    visible:
                        root.artwork === ""

                    text: "󰎆"

                    color:
                        Nexa.Theme.mutedText

                    font {
                        family:
                            Nexa.Theme.iconFontFamily

                        pixelSize:
                            Nexa.Theme.iconSm
                    }
                }
            }


            // ----------------------------------------------------
            // ONE-LINE TRACK
            // ----------------------------------------------------

            Text {
                Layout.fillWidth: true

                text:
                    root.hasTrack
                    ? root.title + "  —  " + root.artist
                    : "Nothing playing"

                elide:
                    Text.ElideRight

                verticalAlignment:
                    Text.AlignVCenter

                color:
                    root.hasTrack
                    ? Nexa.Theme.text
                    : Nexa.Theme.mutedText

                font {
                    family:
                        Nexa.Theme.fontFamily

                    pixelSize:
                        Nexa.Theme.fontSizeSm

                    weight:
                        Nexa.Theme.fontWeightMedium
                }
            }


            // ----------------------------------------------------
            // PLAYING INDICATOR ONLY
            //
            // Not a progress bar.
            // ----------------------------------------------------

            Text {
                visible:
                    root.hasTrack

                text:
                    root.playing
                    ? "󰏤"
                    : "󰐊"

                color:
                    Nexa.Theme.primary

                font {
                    family:
                        Nexa.Theme.iconFontFamily

                    pixelSize:
                        Nexa.Theme.iconXs
                }
            }
        }
    }


    // ============================================================
    // HOVER
    //
    // Exactly ONE progress bar here.
    // It is intentionally not seekable.
    //
    // Hover is for quick interaction.
    // ============================================================

    Item {
        anchors.fill: parent

        visible:
            root.presentation === "hover"


        RowLayout {
            anchors {
                fill: parent

                leftMargin:
                    Nexa.Theme.spacingMd

                rightMargin:
                    Nexa.Theme.spacingMd

                topMargin:
                    Nexa.Theme.spacingSm

                bottomMargin:
                    Nexa.Theme.spacingSm
            }

            spacing:
                Nexa.Theme.spacingMd


            // ====================================================
            // ARTWORK
            // ====================================================

            Rectangle {
                Layout.preferredWidth: 62
                Layout.preferredHeight: 62

                radius:
                    Nexa.Theme.radiusMd

                color:
                    Nexa.Theme.surfaceContainerHigh

                clip: true


                Image {
                    anchors.fill: parent

                    source:
                        root.artwork

                    fillMode:
                        Image.PreserveAspectCrop

                    visible:
                        root.artwork !== ""
                }


                Text {
                    anchors.centerIn: parent

                    visible:
                        root.artwork === ""

                    text: "󰎆"

                    color:
                        Nexa.Theme.mutedText

                    font {
                        family:
                            Nexa.Theme.iconFontFamily

                        pixelSize:
                            Nexa.Theme.iconLg
                    }
                }
            }


            // ====================================================
            // TRACK INFO + SINGLE PROGRESS BAR
            // ====================================================

            ColumnLayout {
                Layout.fillWidth: true

                spacing:
                    Nexa.Theme.spacing2Xs


                Text {
                    Layout.fillWidth: true

                    text:
                        root.title

                    elide:
                        Text.ElideRight

                    color:
                        Nexa.Theme.text

                    font {
                        family:
                            Nexa.Theme.fontFamily

                        pixelSize:
                            Nexa.Theme.fontSizeMd

                        weight:
                            Nexa.Theme.fontWeightDemiBold
                    }
                }


                Text {
                    Layout.fillWidth: true

                    text:
                        root.artist

                    elide:
                        Text.ElideRight

                    color:
                        Nexa.Theme.mutedText

                    font {
                        family:
                            Nexa.Theme.fontFamily

                        pixelSize:
                            Nexa.Theme.fontSizeSm

                        weight:
                            Nexa.Theme.fontWeightMedium
                    }
                }


                // ------------------------------------------------
                // THE ONLY HOVER PROGRESS BAR
                // ------------------------------------------------

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 4

                    radius:
                        Nexa.Theme.radiusPill

                    color:
                        Nexa.Theme.surfaceContainerHighest


                    Rectangle {
                        width:
                            parent.width
                            * root.progress

                        height:
                            parent.height

                        radius:
                            parent.radius

                        color:
                            Nexa.Theme.primary


                        Behavior on width {
                            NumberAnimation {
                                duration:
                                    Nexa.Theme.animationFast
                            }
                          }

                        Behavior on height {
                            NumberAnimation {
                                duration: 80
                                easing.type: Easing.OutCubic
                            }
                        }
                    }
                }
            }


            // ====================================================
            // QUICK CONTROLS
            // ====================================================

            RowLayout {
                spacing:
                    Nexa.Theme.spacingXs


                // ------------------------------------------------
                // PREVIOUS
                // ------------------------------------------------

                NexaUI.NexaIconButton {
                    id: hoverPrevious
                    icon: "󰒮"
                    interactive: root.available && root.player.canGoPrevious
                    onClicked: root.previous()
                }


                // ------------------------------------------------
                // PLAY / PAUSE
                // ------------------------------------------------

                NexaUI.NexaIconButton {
                    id: hoverToggle
                    icon: root.playing ? "󰏤" : "󰐊"
                    selected: true
                    interactive: root.available && root.player.canTogglePlaying
                    onClicked: root.togglePlaying()
                }


                // ------------------------------------------------
                // NEXT
                // ------------------------------------------------

                NexaUI.NexaIconButton {
                    id: hoverNext
                    icon: "󰒭"
                    interactive: root.available && root.player.canGoNext
                    onClicked: root.next()
                }
            }
        }
    }


    // ============================================================
    // FULL MUSIC VIEW
    //
    // Exactly ONE progress/seek bar exists in this entire view.
    // ============================================================

    Item {
        anchors.fill: parent

        visible:
            root.presentation === "full"

        // ========================================================
        // AMBIENT ALBUM ARTWORK BACKDROP
        // ========================================================

        Rectangle {
            anchors.fill: parent
            radius: Nexa.Theme.radiusLg
            color: Nexa.Theme.surfaceContainerLow
            clip: true
            z: -1

            Image {
                anchors.fill: parent
                source: root.artwork
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                opacity: root.artwork !== "" ? 0.38 : 0.0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Nexa.Theme.animationNormal
                        easing.type: Easing.OutCubic
                    }
                }
            }

            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(
                    Nexa.Theme.surfaceContainerLow.r,
                    Nexa.Theme.surfaceContainerLow.g,
                    Nexa.Theme.surfaceContainerLow.b,
                    0.85
                )
            }
        }

        RowLayout {
            anchors {
                fill: parent
                margins: Nexa.Theme.spacingMd
            }

            spacing:
                Nexa.Theme.spacingXl


            // ====================================================
            // LARGE ARTWORK
            // ====================================================

            Rectangle {
                Layout.preferredWidth: 210
                Layout.preferredHeight: 210

                Layout.alignment:
                    Qt.AlignVCenter

                radius:
                    Nexa.Theme.radiusLg

                color:
                    Nexa.Theme.surfaceContainerHigh

                clip: true


                Image {
                    anchors.fill: parent

                    source:
                        root.artwork

                    fillMode:
                        Image.PreserveAspectCrop

                    visible:
                        root.artwork !== ""
                }


                Text {
                    anchors.centerIn: parent

                    visible:
                        root.artwork === ""

                    text: "󰎆"

                    color:
                        Nexa.Theme.mutedText

                    font {
                        family:
                            Nexa.Theme.iconFontFamily

                        pixelSize: 54
                    }
                }
            }


            // ====================================================
            // MUSIC INFORMATION
            // ====================================================

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true

                spacing:
                    Nexa.Theme.spacingMd


                Item {
                    Layout.fillHeight: true
                }


                // ------------------------------------------------
                // TITLE
                // ------------------------------------------------

                Text {
                    Layout.fillWidth: true

                    text:
                        root.title

                    elide:
                        Text.ElideRight

                    color:
                        Nexa.Theme.text

                    font {
                        family:
                            Nexa.Theme.fontFamily

                        pixelSize:
                            Nexa.Theme.fontSizeXl

                        weight:
                            Nexa.Theme.fontWeightDemiBold
                    }
                }


                // ------------------------------------------------
                // ARTIST
                // ------------------------------------------------

                Text {
                    Layout.fillWidth: true

                    text:
                        root.artist

                    elide:
                        Text.ElideRight

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


                // =================================================
                // THE ONLY FULL PROGRESS BAR
                //
                // Click or drag to seek.
                // =================================================

                ColumnLayout {
                    Layout.fillWidth: true

                    spacing:
                        Nexa.Theme.spacing2Xs


                    Rectangle {
                        id: seekArea

                        Layout.fillWidth: true
                        Layout.preferredHeight: 20

                        color:
                            "transparent"


                        // ----------------------------------------
                        // TRACK
                        // ----------------------------------------

                        Rectangle {
                            id: seekTrack

                            anchors {
                                left: parent.left
                                right: parent.right
                                verticalCenter: parent.verticalCenter
                            }

                            height: 5

                            radius:
                                Nexa.Theme.radiusPill

                            color:
                                Nexa.Theme.surfaceContainerHighest


                            // ------------------------------------
                            // PLAYED SECTION
                            // ------------------------------------

                            Rectangle {
                                width:
                                    parent.width
                                    * root.displayedProgress

                                height:
                                    parent.height

                                radius:
                                    parent.radius

                                color:
                                    Nexa.Theme.primary
                            }


                            // ------------------------------------
                            // SEEK THUMB
                            // ------------------------------------

                            Rectangle {
                                width: 12
                                height: 12

                                radius:
                                    Nexa.Theme.radiusPill

                                anchors.verticalCenter:
                                    parent.verticalCenter


                                x:
                                    Math.max(
                                        0,
                                        Math.min(
                                            parent.width - width,

                                            (
                                                parent.width
                                                * root.displayedProgress
                                            )
                                            - width / 2
                                        )
                                    )


                                color:
                                    Nexa.Theme.primary


                                visible:
                                    seekMouse.containsMouse
                                    || root.seeking
                            }
                        }


                        // ----------------------------------------
                        // CLICK / DRAG SEEK
                        // ----------------------------------------

                        MouseArea {
                            id: seekMouse

                            anchors.fill: parent

                            hoverEnabled: true


                            enabled:
                                root.available
                                && root.player.canSeek
                                && root.player.positionSupported
                                && root.duration > 0


                            cursorShape:
                                enabled
                                ? Qt.PointingHandCursor
                                : Qt.ArrowCursor


                            onPressed: mouse => {
                                root.seeking = true

                                root.updateSeekFromX(
                                    mouse.x,
                                    width
                                )
                            }


                            onPositionChanged: mouse => {
                                if (!pressed)
                                    return

                                root.updateSeekFromX(
                                    mouse.x,
                                    width
                                )
                            }


                            onReleased: mouse => {
                                root.updateSeekFromX(
                                    mouse.x,
                                    width
                                )

                                root.commitSeek()
                            }
                        }
                    }


                    // --------------------------------------------
                    // POSITION / DURATION
                    // --------------------------------------------

                    RowLayout {
                        Layout.fillWidth: true


                        Text {
                            text:
                                root.formatTime(
                                    root.displayedPosition
                                )

                            color:
                                Nexa.Theme.mutedText

                            font {
                                family:
                                    Nexa.Theme.monoFontFamily

                                pixelSize:
                                    Nexa.Theme.fontSizeXs
                            }
                        }


                        Item {
                            Layout.fillWidth: true
                        }


                        Text {
                            text:
                                root.formatTime(
                                    root.duration
                                )

                            color:
                                Nexa.Theme.mutedText

                            font {
                                family:
                                    Nexa.Theme.monoFontFamily

                                pixelSize:
                                    Nexa.Theme.fontSizeXs
                            }
                        }
                    }
                }


                // =================================================
                // PLAYBACK CONTROLS
                // =================================================

                RowLayout {
                    Layout.alignment:
                        Qt.AlignHCenter

                    spacing:
                        Nexa.Theme.spacingMd


                    // --------------------------------------------
                    // PREVIOUS
                    // --------------------------------------------

                    NexaUI.NexaIconButton {
                        id: fullPrevious
                        icon: "󰒮"
                        interactive: root.available && root.player.canGoPrevious
                        onClicked: root.previous()
                    }


                    // --------------------------------------------
                    // PLAY / PAUSE
                    // --------------------------------------------

                    NexaUI.NexaIconButton {
                        id: fullToggle
                        icon: root.playing ? "󰏤" : "󰐊"
                        selected: true
                        interactive: root.available && root.player.canTogglePlaying
                        onClicked: root.togglePlaying()
                    }


                    // --------------------------------------------
                    // NEXT
                    // --------------------------------------------

                    NexaUI.NexaIconButton {
                        id: fullNext
                        icon: "󰒭"
                        interactive: root.available && root.player.canGoNext
                        onClicked: root.next()
                    }
                }


                // ============================================================
                // CAVA AUDIO SPECTRUM
                //
                // IMPORTANT:
                //
                // Bar delegates are PERMANENT.
                //
                // CAVA changes only their level/height.
                // We do NOT rebuild the Repeater every audio frame.
                //
                // This removes the flickering caused by using spectrumBins
                // itself as the Repeater model.
                // ============================================================

                Rectangle {
                    id: spectrumArea

                    Layout.fillWidth: true
                    Layout.preferredHeight: 58

                    radius:
                        Nexa.Theme.radiusMd

                    color:
                        waveMouse.containsMouse
                        ? Nexa.Theme.hoverStrong
                        : Nexa.Theme.surfaceContainerLow

                    border.width: Nexa.Theme.borderThin
                    border.color: waveMouse.containsMouse
                        ? Nexa.Theme.primary
                        : "transparent"

                    clip: true

                    Behavior on color {
                        ColorAnimation { duration: Nexa.Theme.animationFast }
                    }

                    Behavior on border.color {
                        ColorAnimation { duration: Nexa.Theme.animationFast }
                    }

                    MouseArea {
                        id: waveMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                    }

                     Row {
                        id: spectrumBars

                        anchors {
                            left: parent.left
                            right: parent.right
                            verticalCenter: parent.verticalCenter

                            leftMargin: Nexa.Theme.spacingSm
                            rightMargin: Nexa.Theme.spacingSm
                        }

                        height:
                            parent.height
                            - Nexa.Theme.spacingMd

                        spacing: 3

                        Repeater {
                            model: 32

                            delegate: Item {
                                id: barSlot

                                required property int index

                                width:
                                    Math.max(
                                        3,
                                        (
                                            spectrumBars.width
                                            - spectrumBars.spacing * 31
                                        ) / 32
                                    )

                                height:
                                    spectrumBars.height

                                readonly property real rawTargetLevel: {
                                    if (
                                        !root.spectrumBins
                                        || index >= root.spectrumBins.length
                                    ) {
                                        return 0.0
                                    }

                                    return Math.max(
                                        0.0,
                                        Math.min(
                                            1.0,
                                            Number(
                                                root.spectrumBins[index]
                                            )
                                        )
                                    )
                                }

                                readonly property real distToPointer:
                                    waveMouse.containsMouse
                                    ? Math.abs((barSlot.x + barSlot.width / 2) - waveMouse.mouseX)
                                    : 9999

                                readonly property real hoverBoost:
                                    waveMouse.containsMouse
                                    ? Math.max(0.0, 1.0 - (distToPointer / 75.0)) * 0.40
                                    : 0.0

                                property real visualLevel:
                                    Math.min(1.0, rawTargetLevel + hoverBoost)

                                Behavior on visualLevel {
                                    NumberAnimation {
                                        duration: 90
                                        easing.type: Easing.OutCubic
                                    }
                                }

                                Rectangle {
                                    anchors.centerIn: parent

                                    width:
                                        Math.max(
                                            3,
                                            parent.width - 1
                                        )

                                    height:
                                        Math.max(
                                            4,
                                            parent.height
                                            * barSlot.visualLevel
                                        )

                                    radius:
                                        Math.min(
                                            width / 2,
                                            4
                                        )

                                    color: Qt.rgba(
                                        Nexa.Theme.primary.r + (Nexa.Theme.tertiary.r - Nexa.Theme.primary.r) * (barSlot.index / 31.0),
                                        Nexa.Theme.primary.g + (Nexa.Theme.tertiary.g - Nexa.Theme.primary.g) * (barSlot.index / 31.0),
                                        Nexa.Theme.primary.b + (Nexa.Theme.tertiary.b - Nexa.Theme.primary.b) * (barSlot.index / 31.0),
                                        waveMouse.containsMouse ? 1.0 : 0.88
                                    )
                                }
                            }
                        }
                    }


                    // ========================================================
                    // NO AUDIO / PAUSED
                    // ========================================================

                    Rectangle {
                        anchors.centerIn: parent

                        width:
                            parent.width
                            - Nexa.Theme.spacingLg

                        height: 1

                        visible:
                            !root.spectrumAvailable

                        color:
                            Nexa.Theme.divider
                    }
                }


                Item {
                    Layout.fillHeight: true
                }
            }
        }
    }
}
