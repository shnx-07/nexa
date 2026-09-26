import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io

import "../theme" as Nexa


Item {
    id: root

    property string wallpaperPath: ""
    property string wallpaperType: "image"
    property string themeSource: ""
    property string previewPath: ""
    property string lockWallpaperPath: ""
    property string lockWallpaperType: "image"
    property string userName: ""
    property string hostName: ""
    property string uptimeText: ""
    property string osInfo: ""

    function cleanPath(raw) {
        if (!raw || raw === "") return ""
        let p = String(raw).trim()
        p = p.replace(/^['"]|['"]$/g, "")
        p = p.replace(/\\(.)/g, "$1")
        if (p.startsWith("file://")) {
            p = p.substring(7)
        }
        return p
    }

    function getPreviewSource(path, type, themeSource, preview) {
        const cPreview = cleanPath(preview)
        if (cPreview !== "") {
            return "file://" + cPreview
        }

        const cPath = cleanPath(path)
        if (cPath === "") return ""

        const fileName = cPath.substring(cPath.lastIndexOf("/") + 1)
        const thumbPath = Quickshell.env("HOME") + "/.cache/nexa/wallpapers/thumbs/" + fileName + ".jpg"

        if (type === "video" || type === "gif") {
            return "file://" + thumbPath
        }

        const cTheme = cleanPath(themeSource)
        if (cTheme !== "" && (cTheme.endsWith(".jpg") || cTheme.endsWith(".jpeg"))) {
            return "file://" + cTheme
        }

        return "file://" + cPath
    }

    // Live FileView watcher for dynamic wallpaper changes
    FileView {
        id: wallpaperConfigFile
        path: Quickshell.env("HOME") + "/.config/nexa/config/wallpaper.conf"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                root.themeSource = ""
                root.previewPath = ""
                const text = wallpaperConfigFile.text()
                if (text && text.length > 0) {
                    const lines = text.split("\n")
                    for (let i = 0; i < lines.length; i++) {
                        const line = lines[i].trim()
                        if (line.startsWith("WALLPAPER=")) {
                            root.wallpaperPath = root.cleanPath(line.substring(10))
                        } else if (line.startsWith("WALLPAPER_TYPE=")) {
                            root.wallpaperType = root.cleanPath(line.substring(15))
                        } else if (line.startsWith("THEME_SOURCE=")) {
                            root.themeSource = root.cleanPath(line.substring(13))
                        } else if (line.startsWith("PREVIEW=")) {
                            root.previewPath = root.cleanPath(line.substring(8))
                        }
                    }
                }
            } catch (e) {}
        }
    }

    // Live FileView watcher for dynamic lockscreen wallpaper changes
    FileView {
        id: lockscreenConfigFile
        path: Quickshell.env("HOME") + "/.config/nexa/config/lockscreen.conf"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const text = lockscreenConfigFile.text()
                if (text && text.length > 0) {
                    const lines = text.split("\n")
                    for (let i = 0; i < lines.length; i++) {
                        const line = lines[i].trim()
                        if (line.startsWith("WALLPAPER=")) {
                            root.lockWallpaperPath = root.cleanPath(line.substring(10))
                        } else if (line.startsWith("WALLPAPER_TYPE=")) {
                            root.lockWallpaperType = root.cleanPath(line.substring(15))
                        }
                    }
                }
            } catch (e) {}
        }
    }


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

            // Lockscreen Static Wallpaper Preview (0% CPU - purely static picture for image, gif, and video)
            Image {
                id: lockImage
                anchors.fill: parent

                sourceSize.width: 500
                sourceSize.height: 600

                source: root.getPreviewSource(root.lockWallpaperPath, root.lockWallpaperType, "", "")

                fillMode: Image.PreserveAspectCrop
                horizontalAlignment: Image.AlignHCenter
                verticalAlignment: Image.AlignVCenter

                asynchronous: true
                cache: true
                smooth: true

                onStatusChanged: {
                    if (status === Image.Error) {
                        const cPath = root.cleanPath(root.lockWallpaperPath)
                        const fileName = cPath.substring(cPath.lastIndexOf("/") + 1)
                        const thumb = "file://" + Quickshell.env("HOME") + "/.cache/nexa/wallpapers/thumbs/" + fileName + ".jpg"
                        if (source !== thumb) {
                            source = thumb
                        }
                    }
                }
            }

            // Lock Screen Indicator Tag
            Rectangle {
                anchors {
                    top: parent.top
                    left: parent.left
                    margins: 10
                }
                height: 22
                width: lockTagRow.implicitWidth + 14
                radius: 11
                color: Qt.rgba(0, 0, 0, 0.45)
                z: 15

                Row {
                    id: lockTagRow
                    anchors.centerIn: parent
                    spacing: 5

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "󰌾"
                        color: Nexa.Theme.text
                        font {
                            family: Nexa.Theme.iconFontFamily
                            pixelSize: 11
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Lock Screen"
                        color: Nexa.Theme.text
                        font {
                            family: Nexa.Theme.fontFamily
                            pixelSize: 10
                            weight: Nexa.Theme.fontWeightMedium
                        }
                    }
                }
            }

            // Interactive hover (unclickable)
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

            // Desktop Wallpaper Static Preview (0% CPU - purely static picture for image, gif, and video)
            Image {
                id: wallpaperImage
                anchors.fill: parent

                sourceSize.width: 900
                sourceSize.height: 500

                source: root.getPreviewSource(root.wallpaperPath, root.wallpaperType, root.themeSource, root.previewPath)

                fillMode: Image.PreserveAspectCrop
                horizontalAlignment: Image.AlignHCenter
                verticalAlignment: Image.AlignVCenter

                asynchronous: true
                cache: true
                smooth: true

                onStatusChanged: {
                    if (status === Image.Error) {
                        const cPath = root.cleanPath(root.wallpaperPath)
                        const fileName = cPath.substring(cPath.lastIndexOf("/") + 1)
                        const thumb = "file://" + Quickshell.env("HOME") + "/.cache/nexa/wallpapers/thumbs/" + fileName + ".jpg"
                        if (source !== thumb) {
                            source = thumb
                        }
                    }
                }
            }

            // Horizontal Dark Fade Overlay (Deep dark on left, transparent on right)
            Rectangle {
                anchors.fill: parent

                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.00; color: Qt.rgba(Nexa.Theme.background.r, Nexa.Theme.background.g, Nexa.Theme.background.b, 0.94) }
                    GradientStop { position: 0.26; color: Qt.rgba(Nexa.Theme.background.r, Nexa.Theme.background.g, Nexa.Theme.background.b, 0.86) }
                    GradientStop { position: 0.48; color: Qt.rgba(Nexa.Theme.background.r, Nexa.Theme.background.g, Nexa.Theme.background.b, 0.40) }
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
                    color: Nexa.Theme.text
                    font.family: Nexa.Theme.fontFamily
                    font.pixelSize: 22
                    font.weight: Nexa.Theme.fontWeightBold
                }

                // Host string
                Text {
                    text: (root.userName !== "" && root.hostName !== "")
                        ? (root.userName + "@" + root.hostName)
                        : ""
                    color: Nexa.Theme.secondary
                    font.family: Nexa.Theme.fontFamily
                    font.pixelSize: 13
                    font.weight: Nexa.Theme.fontWeightMedium
                }

                // Uptime
                Text {
                    text: root.uptimeText !== ""
                        ? ("Uptime ~ " + root.uptimeText)
                        : ""
                    color: Nexa.Theme.mutedText
                    font.family: Nexa.Theme.fontFamily
                    font.pixelSize: 12
                }

                // System / Shell info
                Text {
                    text: root.osInfo !== ""
                        ? ("Nexa • " + root.osInfo)
                        : "Nexa Shell"
                    color: Nexa.Theme.mutedText
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
                    // Open the wallpaper picker
                    Quickshell.execDetached([
                        "qs",
                        "-p",
                        Quickshell.env("HOME") + "/.config/nexa/quickshell",
                        "ipc",
                        "call",
                        "wallpaper",
                        "open"
                    ])

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

                "( . \"$HOME/.config/nexa/config/wallpaper.conf\" 2>/dev/null; printf 'WALLPAPER %s\\n' \"$WALLPAPER\"; printf 'WALLPAPER_TYPE %s\\n' \"${WALLPAPER_TYPE:-image}\"; printf 'THEME_SOURCE %s\\n' \"${THEME_SOURCE:-}\"; printf 'PREVIEW %s\\n' \"${PREVIEW:-}\"; ); ",
                "( . \"$HOME/.config/nexa/config/lockscreen.conf\" 2>/dev/null; printf 'LOCK_WALLPAPER %s\\n' \"$WALLPAPER\"; printf 'LOCK_WALLPAPER_TYPE %s\\n' \"${WALLPAPER_TYPE:-image}\"; ); ",
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
                        root.wallpaperPath = root.cleanPath(value)
                        break
                    case "WALLPAPER_TYPE":
                        root.wallpaperType = root.cleanPath(value)
                        break
                    case "THEME_SOURCE":
                        root.themeSource = root.cleanPath(value)
                        break
                    case "PREVIEW":
                        root.previewPath = root.cleanPath(value)
                        break
                    case "LOCK_WALLPAPER":
                        root.lockWallpaperPath = root.cleanPath(value)
                        break
                    case "LOCK_WALLPAPER_TYPE":
                        root.lockWallpaperType = root.cleanPath(value)
                        break
                    case "OS":
                        root.osInfo = value
                        break
                    }
                }
            }
        }
    }

    // ============================================================
    // UPTIME REFRESHER — updates every 60 seconds
    // ============================================================

    Process {
        id: uptimeProcess
        command: ["sh", "-c", "uptime -p | sed 's/^up //'"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const val = text.trim()
                if (val !== "") root.uptimeText = val
            }
        }
    }

    Timer {
        interval: 60000
        repeat: true
        running: true
        onTriggered: {
            uptimeProcess.running = false
            uptimeProcess.running = true
        }
    }
}
