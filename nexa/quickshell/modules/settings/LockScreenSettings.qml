// pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import "../../NewNexaUI" as NexaUI
import "../lockthemes/components"
import "../lockthemes"
import "../../services" as Services

Item {
    id: root

    anchors.fill: parent

    signal requestClose()
    signal requestLock()

    property string activeTab: (Services.LockScreen.currentLockSubTab && Services.LockScreen.currentLockSubTab !== "") ? Services.LockScreen.currentLockSubTab : "native"
    property int cursor: 0
    readonly property int columns: width > 760 ? 3 : 2
    function rad(n) { return n; }

    readonly property var themes: Services.LockScreen.themes
    readonly property bool shuffle: Services.LockScreen.shuffle

    function preview(id) {
        if (Services.LockScreen.has(id)) {
            root.requestClose();
            Quickshell.execDetached([
                "env",
                "QS_LOCK_THEME=" + id,
                "quickshell",
                "-p",
                Quickshell.env("HOME") + "/.config/nexa/quickshell/modules/lockthemes/LockPreview.qml"
            ]);
        }
    }

    function lockNow() {
        root.requestClose();
        Quickshell.execDetached(["qs", "-p", Quickshell.env("HOME") + "/.config/nexa/quickshell", "ipc", "call", "lockScreen", "lock"]);
    }

    function syncCursorToCurrent() {
        const cur = Services.LockScreen.current;
        for (let i = 0; i < themes.length; i++) {
            if (themes[i].id === cur) {
                cursor = i;
                return;
            }
        }
        cursor = 0;
    }

    Component.onCompleted: {
        syncCursorToCurrent();
    }

    // Demo context for the thumbnails: never talks to PAM; its ambient
    // clock runs only while the view is active.
    LockContext {
        id: previewCtx
        preview: true
        ambient: root.visible
        phase: "ready"
    }

    Connections {
        target: root
        function onCursorChanged() {
            const row = Math.floor(root.cursor / root.columns);
            const rowHeight = 270;
            const targetTop = row * rowHeight;
            const targetBottom = targetTop + rowHeight;
            if (targetTop < themeFlickable.contentY) {
                themeFlickable.contentY = targetTop;
            } else if (targetBottom > themeFlickable.contentY + themeFlickable.height) {
                themeFlickable.contentY = targetBottom - themeFlickable.height;
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 14

        // ── SUB-TABS SWITCHER: [ Nexa Native ] | [ SDDM Themes ] ─────────────
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 44
            radius: NexaUI.NexaTokens.radiusSm
            color: NexaUI.NexaColors.surfaceContainer
            border.width: NexaUI.NexaTokens.borderThin
            border.color: NexaUI.NexaColors.border

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 6
                anchors.rightMargin: 6
                spacing: 6

                // Tab 1: Nexa Native
                Rectangle {
                    id: nativeTabBtn
                    Layout.fillHeight: true
                    Layout.fillWidth: true
                    radius: NexaUI.NexaTokens.radiusXs
                    readonly property bool isSelected: root.activeTab === "native"
                    color: isSelected ? NexaUI.NexaColors.primaryContainer : (nativeMouse.containsMouse ? NexaUI.NexaColors.surfaceContainerHighest : "transparent")
                    border.width: isSelected ? 1 : 0
                    border.color: isSelected ? NexaUI.NexaColors.primary : "transparent"

                    Behavior on color { ColorAnimation { duration: NexaUI.NexaMotion.durationInstant } }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 8

                        Text {
                            text: "󰌾"
                            font.family: NexaUI.NexaTypography.familyIcon
                            font.pixelSize: 17
                            color: nativeTabBtn.isSelected ? NexaUI.NexaColors.primary : NexaUI.NexaColors.mutedText
                        }

                        StyledText {
                            text: "Nexa Native"
                            font.pixelSize: 13
                            font.weight: nativeTabBtn.isSelected ? Font.Bold : Font.Medium
                            color: nativeTabBtn.isSelected ? NexaUI.NexaColors.onPrimaryContainer : NexaUI.NexaColors.text
                        }
                    }

                    MouseArea {
                        id: nativeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.activeTab = "native"
                            Services.LockScreen.currentLockSubTab = "native"
                        }
                    }
                }

                // Tab 2: SDDM Themes
                Rectangle {
                    id: sddmTabBtn
                    Layout.fillHeight: true
                    Layout.fillWidth: true
                    radius: NexaUI.NexaTokens.radiusXs
                    readonly property bool isSelected: root.activeTab === "sddm"
                    color: isSelected ? NexaUI.NexaColors.primaryContainer : (sddmMouse.containsMouse ? NexaUI.NexaColors.surfaceContainerHighest : "transparent")
                    border.width: isSelected ? 1 : 0
                    border.color: isSelected ? NexaUI.NexaColors.primary : "transparent"

                    Behavior on color { ColorAnimation { duration: NexaUI.NexaMotion.durationInstant } }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 8

                        Text {
                            text: "󱓞"
                            font.family: NexaUI.NexaTypography.familyIcon
                            font.pixelSize: 17
                            color: sddmTabBtn.isSelected ? NexaUI.NexaColors.primary : NexaUI.NexaColors.mutedText
                        }

                        StyledText {
                            text: "SDDM Themes"
                            font.pixelSize: 13
                            font.weight: sddmTabBtn.isSelected ? Font.Bold : Font.Medium
                            color: sddmTabBtn.isSelected ? NexaUI.NexaColors.onPrimaryContainer : NexaUI.NexaColors.text
                        }
                    }

                    MouseArea {
                        id: sddmMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.activeTab = "sddm"
                            Services.LockScreen.currentLockSubTab = "sddm"
                        }
                    }
                }
            }
        }

        // ── TAB CONTENT AREA ─────────────────────────────────────────────────
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // 1. Nexa Native Lock Themes View
            Item {
                id: nativeView
                anchors.fill: parent
                visible: root.activeTab === "native"

                Column {
                    anchors.fill: parent
                    spacing: 16

                    // ── Theme Cards Grid ──────────────────────────────────────────
                    Flickable {
                        id: themeFlickable
                        width: parent.width
                        height: parent.height - footer.height - parent.spacing
                        contentHeight: grid.height + 20
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        NexaUI.NexaSmoothScroll {}

                        Grid {
                            id: grid
                            x: 8
                            y: 8
                            width: parent.width - 16
                            columns: root.columns
                            spacing: 16

                            readonly property real cardW: (width - (columns - 1) * spacing) / columns

                            Repeater {
                                model: root.themes

                                Rectangle {
                                    id: card

                                    required property var modelData
                                    required property int index
                                    readonly property bool chosen: root.shuffle
                                        ? Services.LockScreen.activeIds.includes(modelData.id)
                                        : Services.LockScreen.current === modelData.id
                                    readonly property bool focused: root.cursor === index

                                    width: grid.cardW
                                    height: thumb.height + info.implicitHeight + 28
                                    radius: root.rad(NexaUI.NexaTokens.radiusLg)
                                    z: focused ? 10 : 1

                                    color: focused
                                        ? Qt.rgba(NexaUI.NexaColors.primary.r, NexaUI.NexaColors.primary.g, NexaUI.NexaColors.primary.b, 0.08)
                                        : (cardArea.containsMouse ? NexaUI.NexaColors.surfaceContainerHigh : NexaUI.NexaColors.surfaceContainer)

                                    border.width: chosen ? (focused ? 2.5 : 2) : (focused ? 2 : 1)
                                    border.color: (chosen || focused) ? NexaUI.NexaColors.primary : NexaUI.NexaColors.border

                                    scale: cardArea.pressed ? NexaUI.NexaMotion.scalePress : (focused ? 1.025 : (cardArea.containsMouse ? NexaUI.NexaMotion.scaleHover : 1.0))
                                    Behavior on scale {
                                        enabled: NexaUI.NexaMotion.enabled
                                        SpringAnimation {
                                            spring: NexaUI.NexaMotion.springStiffness
                                            damping: NexaUI.NexaMotion.springDamping
                                            mass: NexaUI.NexaMotion.springMass
                                            epsilon: 0.002
                                        }
                                    }

                                    Behavior on color {
                                        ColorAnimation { duration: NexaUI.NexaMotion.durationInstant }
                                    }

                                    // Top Specular Highlight (Layer 2 specular beam)
                                    Rectangle {
                                        anchors.top: parent.top
                                        anchors.topMargin: 1
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        width: Math.max(0, parent.width - parent.radius * 1.6)
                                        height: 1
                                        visible: NexaUI.NexaOptics.specularHighlight && NexaUI.NexaOptics.specularIntensity > 0.01
                                        opacity: Math.min(1.0, NexaUI.NexaOptics.specularIntensity / 0.28)
                                        z: 2
                                        gradient: Gradient {
                                            orientation: Gradient.Horizontal
                                            GradientStop { position: 0.0; color: "transparent" }
                                            GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.35) }
                                            GradientStop { position: 1.0; color: "transparent" }
                                        }
                                    }

                                    // Outer focus halo ring with safe margins
                                    Rectangle {
                                        anchors.fill: parent
                                        anchors.margins: -3
                                        radius: parent.radius + 3
                                        color: "transparent"
                                        border.width: 1.5
                                        border.color: Qt.rgba(NexaUI.NexaColors.primary.r, NexaUI.NexaColors.primary.g, NexaUI.NexaColors.primary.b, 0.4)
                                        visible: card.focused
                                    }

                                    MouseArea {
                                        id: cardArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onEntered: root.cursor = card.index
                                        onClicked: {
                                            Services.LockScreen.select(card.modelData.id);
                                            Services.Sddm.clearDesktopLockTheme();
                                            root.requestClose();
                                        }
                                    }

                                    // Live thumbnail of the theme itself.
                                    Item {
                                        id: thumb
                                        x: 10
                                        y: 10
                                        width: parent.width - 20
                                        height: Math.round(width * 9 / 16)

                                        Rectangle {
                                            id: thumbMask
                                            anchors.fill: parent
                                            radius: root.rad(14)
                                            visible: false
                                            layer.enabled: true
                                        }

                                        Item {
                                            anchors.fill: parent
                                            layer.enabled: true
                                            layer.effect: MultiEffect {
                                                maskEnabled: true
                                                maskSource: thumbMask
                                                maskThresholdMin: 0.5
                                                maskSpreadAtMin: 1.0
                                            }

                                            ThemeHost {
                                                anchors.fill: parent
                                                ctx: previewCtx
                                                themeId: card.modelData.id
                                                still: true
                                                minScale: 0
                                            }
                                        }

                                        // Preview button on hover
                                        ClickableRect {
                                            id: previewChip
                                            anchors.centerIn: parent
                                            width: previewRow.implicitWidth + 26
                                            height: 36
                                            radius: root.rad(18)
                                            visible: cardArea.containsMouse || previewChip.hovered
                                            color: previewChip.hovered ? NexaUI.NexaColors.primary : Qt.rgba(0, 0, 0, 0.7)
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.preview(card.modelData.id)

                                            Row {
                                                id: previewRow
                                                anchors.centerIn: parent
                                                spacing: 6

                                                Glyph {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: "play_arrow"
                                                    filled: true
                                                    font.pixelSize: 18
                                                    color: previewChip.hovered ? NexaUI.NexaColors.onPrimary : "white"
                                                }

                                                StyledText {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: "Preview"
                                                    font.pixelSize: 13
                                                    font.weight: Font.DemiBold
                                                    color: previewChip.hovered ? NexaUI.NexaColors.onPrimary : "white"
                                                }
                                            }
                                        }

                                        // Active badge
                                        Rectangle {
                                            anchors.top: parent.top
                                            anchors.right: parent.right
                                            anchors.margins: 10
                                            visible: card.chosen
                                            width: badgeRow.implicitWidth + 18
                                            height: 26
                                            radius: root.rad(13)
                                            color: NexaUI.NexaColors.primary

                                            Row {
                                                id: badgeRow
                                                anchors.centerIn: parent
                                                spacing: 4

                                                Glyph {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: root.shuffle ? "shuffle" : "check"
                                                    font.pixelSize: 14
                                                    color: NexaUI.NexaColors.onPrimary
                                                }

                                                StyledText {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: root.shuffle ? "In rotation" : "Active"
                                                    font.pixelSize: 12
                                                    font.weight: Font.DemiBold
                                                    color: NexaUI.NexaColors.onPrimary
                                                }
                                            }
                                        }
                                    }

                                    Column {
                                        id: info
                                        anchors.top: thumb.bottom
                                        anchors.topMargin: 12
                                        x: 16
                                        width: parent.width - 32
                                        spacing: 3

                                        Row {
                                            spacing: 8

                                            StyledText {
                                                id: nameLabel
                                                text: card.modelData.name
                                                font.pixelSize: 16
                                                font.weight: Font.Bold
                                                color: NexaUI.NexaColors.text
                                            }

                                            StyledText {
                                                anchors.baseline: nameLabel.baseline
                                                text: card.modelData.tagline
                                                font.pixelSize: 12
                                                color: NexaUI.NexaColors.primary
                                            }
                                        }

                                        StyledText {
                                            width: parent.width
                                            text: card.modelData.description
                                            font.pixelSize: 12
                                            color: NexaUI.NexaColors.mutedText
                                            wrapMode: Text.WordWrap
                                            maximumLineCount: 2
                                            elide: Text.ElideRight
                                            lineHeight: 1.15
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ── Footer: progression stats ─────────────────────────────────────────
                    Item {
                        id: footer
                        width: parent.width
                        height: 44

                        Rectangle {
                            anchors.fill: parent
                            radius: root.rad(NexaUI.NexaTokens.radiusSm)
                            color: NexaUI.NexaColors.surfaceContainer

                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                x: 16
                                spacing: 20

                                Repeater {
                                    model: [
                                        { icon: "military_tech", text: "Level " + Services.LockStats.level + " · " + Services.LockStats.rank },
                                        { icon: "bolt", text: Services.LockStats.xp.toLocaleString(Qt.locale(), "f", 0) + " XP" },
                                        { icon: "local_fire_department", text: Services.LockStats.liveStreak + "-day streak" },
                                        { icon: "emoji_events", text: Services.LockStats.achievements.length + "/" + Services.LockStats.achievementDefs.length + " trophies" }
                                    ]

                                    Row {
                                        id: stat
                                        required property var modelData
                                        spacing: 6

                                        Glyph {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: stat.modelData.icon
                                            filled: true
                                            font.pixelSize: 16
                                            color: NexaUI.NexaColors.primary
                                        }

                                        StyledText {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: stat.modelData.text
                                            font.pixelSize: 13
                                            font.weight: Font.Medium
                                            color: NexaUI.NexaColors.text
                                        }
                                    }
                                }
                            }

                            StyledText {
                                anchors.right: parent.right
                                anchors.rightMargin: 16
                                anchors.verticalCenter: parent.verticalCenter
                                text: "←→ choose · Enter select · P preview · S shuffle · L lock · Esc close"
                                font.pixelSize: 12
                                color: NexaUI.NexaColors.mutedText
                            }
                        }
                    }
                }
            }

            // 2. Dedicated SDDM Themes View
            SddmThemesTab {
                anchors.fill: parent
                visible: root.activeTab === "sddm"
            }
        }
    }
}
