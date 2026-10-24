// pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import "../../../theme" as Nexa
import "../../../theme/components" as NexaUI
import "../../lockthemes/components"
import "../../../services" as Services

Item {
    id: root

    anchors.fill: parent

    signal requestClose()
    signal openWallpaper()
    signal openLockTab()

    function rad(n) { return n; }

    // ── Profile State ─────────────────────────────────────────────────────────
    property string userName: ""
    property string hostName: ""
    property string osInfo: ""
    property string kernelInfo: ""
    property string shellInfo: ""
    property string cpuInfo: ""
    property string memoryInfo: ""
    property string uptimeText: ""

    property string wallpaperPath: ""
    property string wallpaperType: "image"
    property string lockWallpaperPath: ""
    property string lockWallpaperType: "image"

    property string avatarUrl: ""
    property bool avatarLoaded: false
    property string activeAvatarPreset: ""

    readonly property var avatarPresets: [
        { id: "cyber_neon", label: "Cyber Neon", file: "cyber_neon.svg" },
        { id: "astro_space", label: "Astro Space", file: "astro_space.svg" },
        { id: "mecha_cat", label: "Mecha Cat", file: "mecha_cat.svg" },
        { id: "crystal_prism", label: "Crystal Prism", file: "crystal_prism.svg" },
        { id: "minimal_silhouette", label: "Silhouette", file: "minimal_silhouette.svg" }
    ]

    function cleanPath(raw) {
        if (!raw || raw === "") return "";
        let p = String(raw).trim();
        p = p.replace(/^['"]|['"]$/g, "");
        p = p.replace(/\\(.)/g, "$1");
        if (p.startsWith("file://")) p = p.substring(7);
        return p;
    }

    function getThumbSource(path, type) {
        const cPath = cleanPath(path);
        if (cPath === "") return "";
        const fileName = cPath.substring(cPath.lastIndexOf("/") + 1);
        const thumb = Quickshell.env("HOME") + "/.cache/nexa/wallpapers/thumbs/" + fileName + ".jpg";
        const lower = cPath.toLowerCase();
        if (type === "video" || type === "gif" || lower.endsWith(".mp4") || lower.endsWith(".webm") || lower.endsWith(".mkv") || lower.endsWith(".gif")) {
            return "file://" + thumb;
        }
        return "file://" + cPath;
    }

    function setAvatarPreset(presetId) {
        activeAvatarPreset = presetId;
        const script = Quickshell.env("HOME") + "/.config/nexa/scripts/nexa-avatar.sh";
        Quickshell.execDetached(["bash", script, "set", presetId]);
        reloadTimer.restart();
    }

    function lockNow() {
        root.requestClose();
        Quickshell.execDetached(["qs", "-p", Quickshell.env("HOME") + "/.config/nexa/quickshell", "ipc", "call", "lockScreen", "lock"]);
    }

    // ── System Info Collector ─────────────────────────────────────────────────
    Process {
        id: sysInfoProc
        command: [
            "sh", "-c",
            [
                "printf 'USER %s\\n' \"$(whoami)\"; ",
                "printf 'HOST %s\\n' \"$(hostname)\"; ",
                "printf 'OS %s\\n' \"$(grep -s '^PRETTY_NAME=' /etc/os-release | cut -d= -f2 | tr -d '\"')\"; ",
                "printf 'KERNEL %s\\n' \"$(uname -r -m)\"; ",
                "printf 'SHELL %s\\n' \"${SHELL##*/}\"; ",
                "printf 'UPTIME %s\\n' \"$(uptime -p 2>/dev/null | sed 's/^up //')\"; ",
                "printf 'CPU %s\\n' \"$(lscpu 2>/dev/null | awk -F: '/Model name/ {gsub(/^[ \\t]+/, \"\", $2); print $2; exit}')\"; ",
                "printf 'MEMORY %s\\n' \"$(free -h 2>/dev/null | awk '/^Mem:/ {print $3 \" / \" $2}')\"; ",
                "( . \"$HOME/.config/nexa/config/wallpaper.conf\" 2>/dev/null; printf 'WALLPAPER %s\\n' \"$WALLPAPER\"; printf 'WALLPAPER_TYPE %s\\n' \"${WALLPAPER_TYPE:-image}\"; ); ",
                "( . \"$HOME/.config/nexa/config/lockscreen.conf\" 2>/dev/null; printf 'LOCK_WALLPAPER %s\\n' \"$WALLPAPER\"; printf 'LOCK_WALLPAPER_TYPE %s\\n' \"${WALLPAPER_TYPE:-image}\"; ); "
            ].join("")
        ]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                for (let i = 0; i < lines.length; ++i) {
                    const line = lines[i].trim();
                    const split = line.indexOf(" ");
                    if (split < 0) continue;
                    const key = line.substring(0, split);
                    const value = line.substring(split + 1);

                    switch (key) {
                    case "USER": root.userName = value; break;
                    case "HOST": root.hostName = value; break;
                    case "OS": root.osInfo = value; break;
                    case "KERNEL": root.kernelInfo = value; break;
                    case "SHELL": root.shellInfo = value; break;
                    case "UPTIME": root.uptimeText = value; break;
                    case "CPU": root.cpuInfo = value; break;
                    case "MEMORY": root.memoryInfo = value; break;
                    case "WALLPAPER": root.wallpaperPath = root.cleanPath(value); break;
                    case "WALLPAPER_TYPE": root.wallpaperType = root.cleanPath(value); break;
                    case "LOCK_WALLPAPER": root.lockWallpaperPath = root.cleanPath(value); break;
                    case "LOCK_WALLPAPER_TYPE": root.lockWallpaperType = root.cleanPath(value); break;
                    }
                }
            }
        }
    }

    // ── Avatar Path Finder ────────────────────────────────────────────────────
    Process {
        id: avatarFinder
        command: [
            "sh", "-c",
            "for f in \"$HOME/.face\" \"$HOME/.config/nexa/avatar.png\" \"$HOME/.config/nexa/avatar.jpg\" \"$HOME/.config/nexa/avatar.svg\" \"$HOME/.config/nexa/avatar.webp\" \"$HOME/.config/nexa/config/avatars/cyber_neon.svg\"; do " +
            "  if [ -f \"$f\" ]; then echo \"$f\"; exit 0; fi; " +
            "done; exit 1"
        ]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim();
                if (p.length > 0) {
                    root.avatarUrl = "file://" + p;
                    root.avatarLoaded = true;

                    // Match active preset
                    for (let i = 0; i < root.avatarPresets.length; i++) {
                        if (p.indexOf(root.avatarPresets[i].id) !== -1) {
                            root.activeAvatarPreset = root.avatarPresets[i].id;
                            break;
                        }
                    }
                }
            }
        }
    }

    Timer {
        id: reloadTimer
        interval: 350
        onTriggered: {
            avatarFinder.running = false;
            avatarFinder.running = true;
        }
    }

    // Live uptime ticker
    Timer {
        interval: 60000
        repeat: true
        running: true
        onTriggered: {
            sysInfoProc.running = false;
            sysInfoProc.running = true;
        }
    }

    // ── Main Scrollable View ──────────────────────────────────────────────────
    Flickable {
        id: scrollArea
        anchors.fill: parent
        contentWidth: width
        contentHeight: contentCol.implicitHeight + 36
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        NexaUI.NexaSmoothScroll {}

        Column {
            id: contentCol
            width: parent.width
            spacing: 18

            // ── 1. HERO IDENTITY & AVATAR CARD ────────────────────────────────
            Rectangle {
                width: parent.width
                height: 140
                radius: root.rad(Nexa.Theme.radiusLg)
                color: Nexa.Theme.cardBackground
                border.width: Nexa.Theme.borderThin
                border.color: Nexa.Theme.border

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 20

                    // Left: Avatar with glowing accent ring
                    Rectangle {
                        Layout.preferredWidth: 96
                        Layout.preferredHeight: 96
                        radius: root.rad(48)
                        color: Nexa.Theme.surfaceContainerHighest
                        border.width: 2.5
                        border.color: Nexa.Theme.primary

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 4
                            radius: root.rad(44)
                            clip: true
                            color: Nexa.Theme.surfaceContainer

                            Image {
                                id: avatarImg
                                anchors.fill: parent
                                source: root.avatarUrl
                                fillMode: Image.PreserveAspectCrop
                                visible: root.avatarLoaded && avatarImg.status === Image.Ready
                                cache: false
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: !avatarImg.visible
                                text: ""
                                font.family: Nexa.Theme.iconFontFamily
                                font.pixelSize: 42
                                color: Nexa.Theme.primary
                            }
                        }
                    }

                    // Middle: Username, Host & Environment
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        RowLayout {
                            spacing: 10

                            StyledText {
                                text: root.userName !== "" ? root.userName : "User"
                                font.pixelSize: 22
                                font.weight: Font.Bold
                                color: Nexa.Theme.text
                            }

                            // Host Tag Pill
                            Rectangle {
                                Layout.preferredHeight: 22
                                Layout.preferredWidth: hostLabel.implicitWidth + 14
                                radius: root.rad(11)
                                color: Nexa.Theme.surfaceContainerHigh
                                border.width: 1
                                border.color: Nexa.Theme.border

                                StyledText {
                                    id: hostLabel
                                    anchors.centerIn: parent
                                    text: "@" + (root.hostName !== "" ? root.hostName : "nexa")
                                    font.pixelSize: 11
                                    font.weight: Font.Medium
                                    color: Nexa.Theme.secondary
                                }
                            }

                            // Admin / User Badge
                            Rectangle {
                                Layout.preferredHeight: 22
                                Layout.preferredWidth: badgeLabel.implicitWidth + 14
                                radius: root.rad(11)
                                color: Qt.rgba(Nexa.Theme.primary.r, Nexa.Theme.primary.g, Nexa.Theme.primary.b, 0.16)
                                border.width: 1
                                border.color: Qt.rgba(Nexa.Theme.primary.r, Nexa.Theme.primary.g, Nexa.Theme.primary.b, 0.35)

                                Row {
                                    id: badgeLabel
                                    anchors.centerIn: parent
                                    spacing: 4

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "󰌽"
                                        font.family: Nexa.Theme.iconFontFamily
                                        font.pixelSize: 12
                                        color: Nexa.Theme.primary
                                    }

                                    StyledText {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "Wheel / Sudoer"
                                        font.pixelSize: 11
                                        font.weight: Font.DemiBold
                                        color: Nexa.Theme.primary
                                    }
                                }
                            }
                        }

                        StyledText {
                            text: (root.osInfo !== "" ? root.osInfo : "Nexa Desktop") + " • " + (root.shellInfo !== "" ? ("Shell: " + root.shellInfo) : "Shell: Linux")
                            font.pixelSize: 12
                            color: Nexa.Theme.mutedText
                        }

                        StyledText {
                            text: "Session Uptime ~ " + (root.uptimeText !== "" ? root.uptimeText : "active")
                            font.pixelSize: 11
                            color: Nexa.Theme.mutedText
                        }
                    }

                    // Right: Quick Avatar Presets Selector
                    ColumnLayout {
                        Layout.preferredWidth: 260
                        spacing: 8

                        StyledText {
                            text: "AVATAR PRESETS"
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            font.letterSpacing: 0.8
                            color: Nexa.Theme.mutedText
                        }

                        RowLayout {
                            spacing: 8

                            Repeater {
                                model: root.avatarPresets

                                ClickableRect {
                                    id: presetChip
                                    required property var modelData
                                    Layout.preferredWidth: 42
                                    Layout.preferredHeight: 42
                                    radius: root.rad(21)
                                    color: root.activeAvatarPreset === modelData.id
                                        ? Nexa.Theme.primaryContainer
                                        : (presetChip.hovered ? Nexa.Theme.surfaceContainerHighest : Nexa.Theme.surfaceContainerHigh)
                                    border.width: root.activeAvatarPreset === modelData.id ? 2 : 1
                                    border.color: root.activeAvatarPreset === modelData.id ? Nexa.Theme.primary : Nexa.Theme.border
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.setAvatarPreset(modelData.id)

                                    Image {
                                        anchors.fill: parent
                                        anchors.margins: 5
                                        source: "file://" + Quickshell.env("HOME") + "/.config/nexa/config/avatars/" + presetChip.modelData.file
                                        fillMode: Image.PreserveAspectFit
                                        smooth: true
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ── 2. ARTWORK & WALLPAPERS (1:2 SPLIT) ────────────────────────────
            Column {
                width: parent.width
                spacing: 8

                StyledText {
                    text: "DESKTOP & LOCK SCREEN ARTWORK"
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1.0
                    color: Nexa.Theme.mutedText
                    leftPadding: 4
                }

                RowLayout {
                    width: parent.width
                    height: 160
                    spacing: 14

                    // Left Card: Lock Screen Wallpaper Preview
                    Rectangle {
                        id: lockArtCard
                        Layout.preferredWidth: Math.round(parent.width * 0.35)
                        Layout.fillHeight: true
                        radius: root.rad(Nexa.Theme.radiusLg)
                        color: Nexa.Theme.cardBackground
                        border.width: Nexa.Theme.borderThin
                        border.color: lockArtMouse.containsMouse ? Nexa.Theme.primary : Nexa.Theme.border
                        clip: true

                        scale: lockArtMouse.pressed ? 0.985 : (lockArtMouse.containsMouse ? 1.008 : 1.0)
                        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }
                        Behavior on border.color { ColorAnimation { duration: 140 } }

                        Image {
                            anchors.fill: parent
                            source: root.getThumbSource(root.lockWallpaperPath, root.lockWallpaperType)
                            fillMode: Image.PreserveAspectCrop
                            smooth: true
                            onStatusChanged: {
                                if (status === Image.Error) {
                                    const cPath = root.cleanPath(root.lockWallpaperPath);
                                    const fileName = cPath.substring(cPath.lastIndexOf("/") + 1);
                                    source = "file://" + Quickshell.env("HOME") + "/.cache/nexa/wallpapers/thumbs/" + fileName + ".jpg";
                                }
                            }
                        }

                        // Gradient protection
                        Rectangle {
                            anchors.fill: parent
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.45) }
                                GradientStop { position: 0.5; color: "transparent" }
                                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.65) }
                            }
                        }

                        // Badge Top Left
                        Rectangle {
                            anchors { top: parent.top; left: parent.left; margins: 10 }
                            height: 22
                            width: lockBadgeRow.implicitWidth + 14
                            radius: root.rad(11)
                            color: Qt.rgba(0, 0, 0, 0.65)

                            Row {
                                id: lockBadgeRow
                                anchors.centerIn: parent
                                spacing: 5

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "󰌾"
                                    color: "white"
                                    font.family: Nexa.Theme.iconFontFamily
                                    font.pixelSize: 11
                                }

                                StyledText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Lock Screen"
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                    color: "white"
                                }
                            }
                        }

                        // Bottom Action Cue
                        StyledText {
                            anchors { bottom: parent.bottom; left: parent.left; margins: 10 }
                            text: "Click to Switch Theme ↗"
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            color: lockArtMouse.containsMouse ? Nexa.Theme.primary : "white"
                        }

                        MouseArea {
                            id: lockArtMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.openLockTab()
                        }
                    }

                    // Right Card: Desktop Wallpaper Preview
                    Rectangle {
                        id: wpArtCard
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: root.rad(Nexa.Theme.radiusLg)
                        color: Nexa.Theme.cardBackground
                        border.width: Nexa.Theme.borderThin
                        border.color: wpArtMouse.containsMouse ? Nexa.Theme.primary : Nexa.Theme.border
                        clip: true

                        scale: wpArtMouse.pressed ? 0.985 : (wpArtMouse.containsMouse ? 1.008 : 1.0)
                        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }
                        Behavior on border.color { ColorAnimation { duration: 140 } }

                        Image {
                            anchors.fill: parent
                            source: root.getThumbSource(root.wallpaperPath, root.wallpaperType)
                            fillMode: Image.PreserveAspectCrop
                            smooth: true
                        }

                        // Horizontal Dark Fade Overlay
                        Rectangle {
                            anchors.fill: parent
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0.00; color: Qt.rgba(Nexa.Theme.background.r, Nexa.Theme.background.g, Nexa.Theme.background.b, 0.92) }
                                GradientStop { position: 0.32; color: Qt.rgba(Nexa.Theme.background.r, Nexa.Theme.background.g, Nexa.Theme.background.b, 0.80) }
                                GradientStop { position: 0.58; color: Qt.rgba(Nexa.Theme.background.r, Nexa.Theme.background.g, Nexa.Theme.background.b, 0.35) }
                                GradientStop { position: 1.00; color: "transparent" }
                            }
                        }

                        // Overlay Information
                        ColumnLayout {
                            anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 20 }
                            spacing: 4

                            Rectangle {
                                Layout.preferredHeight: 20
                                Layout.preferredWidth: wpBadgeText.implicitWidth + 12
                                radius: root.rad(10)
                                color: Nexa.Theme.primaryContainer

                                StyledText {
                                    id: wpBadgeText
                                    anchors.centerIn: parent
                                    text: "DESKTOP WALLPAPER"
                                    font.pixelSize: 10
                                    font.weight: Font.Bold
                                    color: Nexa.Theme.onPrimaryContainer
                                }
                            }

                            StyledText {
                                text: {
                                    const p = root.wallpaperPath;
                                    return p !== "" ? p.substring(p.lastIndexOf("/") + 1) : "Default Wallpaper";
                                }
                                font.pixelSize: 17
                                font.weight: Font.Bold
                                color: Nexa.Theme.text
                            }

                            StyledText {
                                text: "Click to open 3D Wallpaper Carousel"
                                font.pixelSize: 12
                                color: wpArtMouse.containsMouse ? Nexa.Theme.primary : Nexa.Theme.mutedText
                            }
                        }

                        MouseArea {
                            id: wpArtMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.openWallpaper()
                        }
                    }
                }
            }

            // ── 3. SYSTEM & HARDWARE SPECIFICATIONS ───────────────────────────
            Column {
                width: parent.width
                spacing: 8

                StyledText {
                    text: "SYSTEM SPECIFICATIONS"
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1.0
                    color: Nexa.Theme.mutedText
                    leftPadding: 4
                }

                GridLayout {
                    width: parent.width
                    columns: 3
                    rowSpacing: 10
                    columnSpacing: 10

                    Repeater {
                        model: [
                            { icon: "󰣇", color: Nexa.Theme.primary, title: "Distribution", value: root.osInfo !== "" ? root.osInfo : "Linux", bold: 13 },
                            { icon: "󰒋", color: Nexa.Theme.secondary, title: "Kernel", value: root.kernelInfo !== "" ? root.kernelInfo : "Linux Kernel", bold: 12 },
                            { icon: "󰍹", color: Nexa.Theme.tertiary, title: "Desktop Compositor", value: "Nexa • Hyprland", bold: 13 },
                            { icon: "󰍛", color: Nexa.Theme.primary, title: "Processor (CPU)", value: root.cpuInfo !== "" ? root.cpuInfo : "Multi-core Processor", bold: 12 },
                            { icon: "󰘚", color: Nexa.Theme.secondary, title: "Memory Usage (RAM)", value: root.memoryInfo !== "" ? root.memoryInfo : "RAM", bold: 13 },
                            { icon: "󰞷", color: Nexa.Theme.tertiary, title: "User Shell", value: root.shellInfo !== "" ? ("/bin/" + root.shellInfo) : "/bin/bash", bold: 13 }
                        ]
                        delegate: Rectangle {
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredHeight: 64
                            radius: root.rad(Nexa.Theme.radiusMd)
                            color: Nexa.Theme.cardBackground
                            border.width: Nexa.Theme.borderThin
                            border.color: Nexa.Theme.border

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 12

                                Text {
                                    text: modelData.icon
                                    font.family: Nexa.Theme.iconFontFamily
                                    font.pixelSize: 24
                                    color: modelData.color
                                }

                                Column {
                                    Layout.fillWidth: true
                                    spacing: 1

                                    StyledText { text: modelData.title; font.pixelSize: 11; color: Nexa.Theme.mutedText }
                                    StyledText {
                                        text: modelData.value
                                        font.pixelSize: modelData.bold
                                        font.weight: Font.Bold
                                        color: Nexa.Theme.text
                                        elide: Text.ElideRight
                                        width: parent.width
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ── 4. NEXA PROGRESSION & ARCADE STATS ────────────────────────────
            Rectangle {
                width: parent.width
                height: 80
                radius: root.rad(Nexa.Theme.radiusLg)
                color: Nexa.Theme.cardBackground
                border.width: Nexa.Theme.borderThin
                border.color: Nexa.Theme.border

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 24

                    // Level & Rank
                    Row {
                        spacing: 12
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 44
                            height: 44
                            radius: root.rad(10)
                            color: Nexa.Theme.primaryContainer

                            Glyph {
                                anchors.centerIn: parent
                                text: "military_tech"
                                font.pixelSize: 22
                                color: Nexa.Theme.onPrimaryContainer
                            }
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2

                            StyledText {
                                text: "Level " + Services.LockStats.level + " • " + Services.LockStats.rank
                                font.pixelSize: 14
                                font.weight: Font.Bold
                                color: Nexa.Theme.text
                            }

                            StyledText {
                                text: Services.LockStats.xp.toLocaleString(Qt.locale(), "f", 0) + " total XP"
                                font.pixelSize: 11
                                color: Nexa.Theme.mutedText
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Streak
                    Row {
                        spacing: 8
                        Glyph {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "local_fire_department"
                            font.pixelSize: 18
                            color: Nexa.Theme.primary
                        }
                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Services.LockStats.liveStreak + "-day streak"
                            font.pixelSize: 12
                            font.weight: Font.Medium
                            color: Nexa.Theme.text
                        }
                    }

                    // Trophies
                    Row {
                        spacing: 8
                        Glyph {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "emoji_events"
                            font.pixelSize: 18
                            color: Nexa.Theme.secondary
                        }
                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Services.LockStats.achievements.length + "/" + Services.LockStats.achievementDefs.length + " trophies"
                            font.pixelSize: 12
                            font.weight: Font.Medium
                            color: Nexa.Theme.text
                        }
                    }
                }
            }

            // ── 5. QUICK ACTIONS FOOTER ───────────────────────────────────────
            RowLayout {
                width: parent.width
                spacing: 12

                ClickableRect {
                    id: lockSessionBtn
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    radius: root.rad(10)
                    color: lockSessionBtn.hovered ? Nexa.Theme.surfaceContainerHighest : Nexa.Theme.surfaceContainer
                    border.width: 1
                    border.color: Nexa.Theme.border
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.lockNow()

                    Row {
                        anchors.centerIn: parent
                        spacing: 8
                        Glyph { text: "lock"; font.pixelSize: 16; color: Nexa.Theme.primary }
                        StyledText { text: "Lock Session"; font.pixelSize: 12; font.weight: Font.Medium; color: Nexa.Theme.text }
                    }
                }

                ClickableRect {
                    id: openWpBtn
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    radius: root.rad(10)
                    color: openWpBtn.hovered ? Nexa.Theme.surfaceContainerHighest : Nexa.Theme.surfaceContainer
                    border.width: 1
                    border.color: Nexa.Theme.border
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.openWallpaper()

                    Row {
                        anchors.centerIn: parent
                        spacing: 8
                        Text { text: "󰸉"; font.family: Nexa.Theme.iconFontFamily; font.pixelSize: 16; color: Nexa.Theme.secondary }
                        StyledText { text: "Wallpaper Carousel"; font.pixelSize: 12; font.weight: Font.Medium; color: Nexa.Theme.text }
                    }
                }

                ClickableRect {
                    id: openLockBtn
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    radius: root.rad(10)
                    color: openLockBtn.hovered ? Nexa.Theme.surfaceContainerHighest : Nexa.Theme.surfaceContainer
                    border.width: 1
                    border.color: Nexa.Theme.border
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.openLockTab()

                    Row {
                        anchors.centerIn: parent
                        spacing: 8
                        Text { text: "󰌾"; font.family: Nexa.Theme.iconFontFamily; font.pixelSize: 16; color: Nexa.Theme.tertiary }
                        StyledText { text: "Lock Screen Themes"; font.pixelSize: 12; font.weight: Font.Medium; color: Nexa.Theme.text }
                    }
                }
            }
        }
    }
}
