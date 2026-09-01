import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io

import "../theme" as Nexa


Item {
    id: root

    property string wallpaperPath: ""
    property string lockWallpaperPath: ""
    property string userName: ""
    property string hostName: ""
    property string uptimeText: ""
    property string osInfo: ""


    // ============================================================
    // MAIN LAYOUT (1:3 Split for Profile / Lockscreen & Wallpaper)
    // ============================================================

    RowLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        // ========================================================
        // LEFT CARD: LOCKSCREEN PICTURE (~1/3 WIDTH, PURE ART)
        // ========================================================

        Rectangle {
            id: lockCard

            Layout.preferredWidth: Math.round((root.width - 24 - 12) * 0.33)
            Layout.fillHeight: true

            radius: Nexa.Theme.radiusLg
            color: Nexa.Theme.cardBackground
            border.width: Nexa.Theme.borderThin
            border.color: lockMouse.containsMouse ? Nexa.Theme.outline : Nexa.Theme.border
            clip: true

            scale: lockMouse.pressed ? 0.985 : (lockMouse.containsMouse ? 1.01 : 1.0)
            Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutQuad } }
            Behavior on border.color { ColorAnimation { duration: 140 } }

            layer.enabled: true
            layer.effect: OpacityMask {
                maskSource: Rectangle {
                    width: lockCard.width
                    height: lockCard.height
                    radius: Nexa.Theme.radiusLg
                }
            }

            Image {
                id: lockImage
                anchors.fill: parent

                sourceSize.width: 500
                sourceSize.height: 600

                source: root.lockWallpaperPath !== ""
                    ? "file://" + root.lockWallpaperPath
                    : ""

                fillMode: Image.PreserveAspectCrop
                horizontalAlignment: Image.AlignHCenter
                verticalAlignment: Image.AlignVCenter

                asynchronous: true
                cache: false
                smooth: true
            }

            // Interactive hover
            MouseArea {
                id: lockMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.ArrowCursor
            }
        }

        // ========================================================
        // RIGHT CARD: WALLPAPER & SYSTEM INFO WITH FADE OVERLAY
        // ========================================================

        Rectangle {
            id: wallpaperCard

            Layout.fillWidth: true
            Layout.fillHeight: true

            radius: Nexa.Theme.radiusLg
            color: Nexa.Theme.cardBackground
            border.width: Nexa.Theme.borderThin
            border.color: wpMouse.containsMouse ? Nexa.Theme.outline : Nexa.Theme.border
            clip: true

            scale: wpMouse.pressed ? 0.99 : 1.0
            Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutQuad } }
            Behavior on border.color { ColorAnimation { duration: 140 } }

            layer.enabled: true
            layer.effect: OpacityMask {
                maskSource: Rectangle {
                    width: wallpaperCard.width
                    height: wallpaperCard.height
                    radius: Nexa.Theme.radiusLg
                }
            }

            // Desktop Wallpaper Image
            Image {
                id: wallpaperImage
                anchors.fill: parent

                sourceSize.width: 900
                sourceSize.height: 500

                source: root.wallpaperPath !== ""
                    ? "file://" + root.wallpaperPath
                    : ""

                fillMode: Image.PreserveAspectCrop
                horizontalAlignment: Image.AlignHCenter
                verticalAlignment: Image.AlignVCenter

                asynchronous: true
                cache: false
                smooth: true
            }

            // Horizontal Dark Fade Overlay (Deep dark on left, transparent on right)
            Rectangle {
                anchors.fill: parent

                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.00; color: Qt.rgba(12/255, 16/255, 14/255, 0.94) }
                    GradientStop { position: 0.26; color: Qt.rgba(12/255, 16/255, 14/255, 0.86) }
                    GradientStop { position: 0.48; color: Qt.rgba(12/255, 16/255, 14/255, 0.40) }
                    GradientStop { position: 0.68; color: "transparent" }
                    GradientStop { position: 1.00; color: "transparent" }
                }
            }

            // System & Profile Information (Left-aligned over the dark fade)
            ColumnLayout {
                anchors {
                    left: parent.left
                    verticalCenter: parent.verticalCenter
                    leftMargin: 26
                }
                spacing: 4
                z: 10

                // Username
                Text {
                    text: root.userName
                    color: "#FFFFFF"
                    font.family: Nexa.Theme.fontFamily
                    font.pixelSize: 22
                    font.weight: Nexa.Theme.fontWeightBold
                }

                // Host string
                Text {
                    text: (root.userName !== "" && root.hostName !== "")
                        ? (root.userName + "@" + root.hostName)
                        : ""
                    color: "#99B0BE"
                    font.family: Nexa.Theme.fontFamily
                    font.pixelSize: 13
                    font.weight: Nexa.Theme.fontWeightMedium
                }

                // Uptime
                Text {
                    text: root.uptimeText !== ""
                        ? ("Uptime ~ " + root.uptimeText)
                        : ""
                    color: "#8EA6B4"
                    font.family: Nexa.Theme.fontFamily
                    font.pixelSize: 12
                }

                // System / Shell info
                Text {
                    text: root.osInfo !== ""
                        ? ("Nexa • " + root.osInfo)
                        : "Nexa Shell"
                    color: "#6E828E"
                    font.family: Nexa.Theme.fontFamily
                    font.pixelSize: 11
                }
            }

            // Click Area to Open Wallpaper Picker
            MouseArea {
                id: wpMouse
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                z: 20

                onClicked: {
                    if (typeof wallpaperView !== "undefined") {
                        wallpaperView.visible = true
                        wallpaperView.forceActiveFocus()
                    }

                    // Close the island control center
                    Quickshell.execDetached([
                        "qs",
                        "-p",
                        Quickshell.env("HOME") + "/.config/nexa/quickshell",
                        "ipc",
                        "call",
                        "nexaIsland",
                        "toggleControlCenter"
                    ])

                    // Also close legacy sidePanel if open
                    Quickshell.execDetached([
                        "qs",
                        "-p",
                        Quickshell.env("HOME") + "/.config/nexa/quickshell",
                        "ipc",
                        "call",
                        "sidePanel",
                        "close"
                    ])
                }
            }
        }
    }


    // ============================================================
    // PROFILE & WALLPAPER DATA LOADER
    // ============================================================

    Process {
        id: profileInfoProcess

        command: [
            "sh",
            "-c",
            [
                "printf 'USER %s\\n' \"$(whoami)\"; ",
                "printf 'HOST %s\\n' \"$(hostname)\"; ",
                "printf 'UPTIME %s\\n' \"$(uptime -p | sed 's/^up //')\"; ",
                ". \"$HOME/.config/nexa/config/wallpaper.conf\" 2>/dev/null || true; ",
                "printf 'WALLPAPER %s\\n' \"$WALLPAPER\"; ",
                ". \"$HOME/.config/nexa/config/lockscreen.conf\" 2>/dev/null || true; ",
                "printf 'LOCK_WALLPAPER %s\\n' \"$WALLPAPER\"; ",
                "printf 'OS %s\\n' \"$(grep -s '^PRETTY_NAME=' /etc/os-release | cut -d= -f2 | tr -d '\"')\""
            ].join("")
        ]

        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n")

                for (let i = 0; i < lines.length; ++i) {
                    const line = lines[i].trim()
                    const split = line.indexOf(" ")
                    if (split < 0) continue

                    const key = line.substring(0, split)
                    const value = line.substring(split + 1)

                    switch (key) {
                    case "USER":
                        root.userName = value
                        break
                    case "HOST":
                        root.hostName = value
                        break
                    case "UPTIME":
                        root.uptimeText = value
                        break
                    case "WALLPAPER":
                        root.wallpaperPath = value
                        break
                    case "LOCK_WALLPAPER":
                        root.lockWallpaperPath = value
                        break
                    case "OS":
                        root.osInfo = value
                        break
                    }
                }
            }
        }
    }
}
