import QtQuick
import QtQuick.Effects
import QtMultimedia
import Quickshell
import "../.."
import "../../../../services" as Services

// The world behind the HUD: the current wallpaper, heavily blurred, under a
// static shader that darkens it and adds a vignette, dot grid and scanlines.
Item {
    id: backdrop

    property real sc: 1
    property bool still: false
    property bool shown: true

    Rectangle {
        anchors.fill: parent
        color: LockTheme.base
    }

    Item {
        id: wallpaperItem
        anchors.fill: parent
        visible: true

        AnimatedImage {
            id: staticOrGif
            anchors.fill: parent
            source: backdrop.still
                ? Services.LockScreen.wallpaperThumb
                : (Services.LockScreen.wallpaperType === "gif"
                    ? Services.LockScreen.wallpaperSource
                    : Services.LockScreen.wallpaperPreview)
            sourceSize: backdrop.still
                ? Qt.size(480, 270)
                : Qt.size(Math.max(1, backdrop.width), Math.max(1, backdrop.height))
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            playing: !backdrop.still && backdrop.shown && (Services.LockScreen.wallpaperType === "gif")
            visible: backdrop.still || (Services.LockScreen.wallpaperType !== "video")
        }

        MediaPlayer {
            id: videoPlayer
            source: (!backdrop.still && Services.LockScreen.wallpaperType === "video")
                ? Services.LockScreen.wallpaperSource
                : ""
            loops: MediaPlayer.Infinite
            audioOutput: AudioOutput { muted: true }
            videoOutput: videoOutput

            function checkPlay() {
                if (!backdrop.still && backdrop.shown && Services.LockScreen.wallpaperType === "video" && source != "") {
                    if (playbackState !== MediaPlayer.PlayingState) {
                        play();
                    }
                } else {
                    stop();
                }
            }

            onSourceChanged: checkPlay()
            Component.onCompleted: checkPlay()
        }

        VideoOutput {
            id: videoOutput
            anchors.fill: parent
            fillMode: VideoOutput.PreserveAspectCrop
            visible: !backdrop.still && (Services.LockScreen.wallpaperType === "video")
        }
    }

    Connections {
        target: backdrop
        function onShownChanged() {
            videoPlayer.checkPlay();
        }
    }

    ShaderEffectSource {
        id: wallSource
        sourceItem: wallpaperItem
        live: !backdrop.still && backdrop.shown && (Services.LockScreen.wallpaperType === "video" || Services.LockScreen.wallpaperType === "gif")
        hideSource: true
        visible: false
    }

    MultiEffect {
        anchors.fill: parent
        source: wallSource
        visible: staticOrGif.status === Image.Ready || videoOutput.visible
        autoPaddingEnabled: false
        blurEnabled: true
        // Blur radius is in pixels: scale it so thumbnails look like the real thing.
        blurMax: Math.max(8, Math.round(64 * backdrop.sc))
        blur: 1.0
        saturation: -0.15
    }

    ShaderEffect {
        anchors.fill: parent

        property real itemWidth: width
        property real itemHeight: height
        property real gridSize: Math.round(30 * backdrop.sc)
        property real dotAlpha: 0.13
        property real scanAlpha: 0.12
        property real tintAlpha: 0.52
        property real vignette: 0.8
        property color tintColor: LockTheme.base
        property color dotColor: LockTheme.ink

        fragmentShader: Qt.resolvedUrl("../../../../shaders/lock_backdrop.frag.qsb")
    }
}
