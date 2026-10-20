// pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import Quickshell
import "../../colors"
import "../../theme" as Nexa
import "../lockthemes/components"
import "../lockthemes"
import "../../services" as Services

Item {
    id: root

    anchors.fill: parent

    signal requestClose()
    signal requestLock()

    property int cursor: 0
    readonly property int columns: width > 760 ? 3 : 2
    function rad(n) { return n; }

    readonly property var themes: Services.LockScreen.themes
    readonly property bool shuffle: Services.LockScreen.shuffle

    function preview(id) {
        if (Services.LockScreen.has(id)) {
            root.requestClose();
            Quickshell.execDetached(["sh", "-c", "sleep 0.35; QS_LOCK_THEME=" + id + " exec quickshell -p \"$HOME/.config/nexa/quickshell/modules/lockthemes/LockPreview.qml\""]);
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

    Column {
        anchors.fill: parent
        spacing: 16

        // ── Theme Cards Grid ──────────────────────────────────────────────────
        Flickable {
            id: themeFlickable
            width: parent.width
            height: parent.height - footer.height - parent.spacing
            contentHeight: grid.height + 20
            clip: true
            boundsBehavior: Flickable.StopAtBounds

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
                        radius: root.rad(Nexa.Theme.radiusLg)
                        z: focused ? 10 : 1

                        color: focused
                            ? Qt.rgba(Nexa.Theme.primary.r, Nexa.Theme.primary.g, Nexa.Theme.primary.b, 0.08)
                            : (cardArea.containsMouse ? Nexa.Theme.cardBackgroundElevated : Nexa.Theme.cardBackground)

                        border.width: chosen ? (focused ? 2.5 : 2) : (focused ? 2 : 1)
                        border.color: (chosen || focused) ? Nexa.Theme.primary : Nexa.Theme.border

                        Behavior on color {
                            ColorAnimation { duration: 140 }
                        }

                        // Outer focus halo ring with safe margins
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: -3
                            radius: parent.radius + 3
                            color: "transparent"
                            border.width: 1.5
                            border.color: Qt.rgba(Nexa.Theme.primary.r, Nexa.Theme.primary.g, Nexa.Theme.primary.b, 0.4)
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
                                color: previewChip.hovered ? Nexa.Theme.primary : Qt.rgba(0, 0, 0, 0.7)
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
                                        color: previewChip.hovered ? Nexa.Theme.onPrimary : "white"
                                    }

                                    StyledText {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "Preview"
                                        font.pixelSize: 13
                                        font.weight: Font.DemiBold
                                        color: previewChip.hovered ? Nexa.Theme.onPrimary : "white"
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
                                color: Nexa.Theme.primary

                                Row {
                                    id: badgeRow
                                    anchors.centerIn: parent
                                    spacing: 4

                                    Glyph {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: root.shuffle ? "shuffle" : "check"
                                        font.pixelSize: 14
                                        color: Nexa.Theme.onPrimary
                                    }

                                    StyledText {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: root.shuffle ? "In rotation" : "Active"
                                        font.pixelSize: 12
                                        font.weight: Font.DemiBold
                                        color: Nexa.Theme.onPrimary
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
                                    color: Nexa.Theme.text
                                }

                                StyledText {
                                    anchors.baseline: nameLabel.baseline
                                    text: card.modelData.tagline
                                    font.pixelSize: 12
                                    color: Nexa.Theme.primary
                                }
                            }

                            StyledText {
                                width: parent.width
                                text: card.modelData.description
                                font.pixelSize: 12
                                color: Nexa.Theme.mutedText
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
                radius: root.rad(16)
                color: Nexa.Theme.surfaceContainer

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
                                color: Nexa.Theme.primary
                            }

                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: stat.modelData.text
                                font.pixelSize: 13
                                font.weight: Font.Medium
                                color: Nexa.Theme.text
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
                    color: Nexa.Theme.mutedText
                }
            }
        }
    }
}

