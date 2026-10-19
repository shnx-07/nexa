// pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import Quickshell
import "../../colors"
import "../../theme" as Nexa
import "../lockthemes/components"
import "../lockthemes"
import "../../services" as Services

// Lock Screen Themes panel.
//
// Each card shows a live, scaled-down render of the theme itself.
// Click a card to make it the lock screen; with Shuffle on, clicking adds or
// removes themes from the rotation and every lock picks one of them at
// random. Preview runs a theme full screen (LockPreview.qml, never a real
// lock); Lock now locks straight away.
//
// Keys: Esc closes. Arrows move, Enter/Space choose, P preview, S shuffle, L lock now.
Item {
    id: root

    anchors.fill: parent
    visible: false
    focus: true
    Keys.forwardTo: [keys]
    Keys.onEscapePressed: root.close()

    property int cursor: 0
    property string tab: "lock"
    readonly property int columns: panel.width - 56 > 1000 ? 3 : 2
    function rad(n) { return n; }
    readonly property var themes: Services.LockScreen.themes
    readonly property bool shuffle: Services.LockScreen.shuffle

    function open() {
        visible = true;
        let idx = 0;
        const cur = Services.LockScreen.current;
        for (let i = 0; i < themes.length; i++) {
            if (themes[i].id === cur) {
                idx = i;
                break;
            }
        }
        cursor = idx;
        keys.forceActiveFocus();
        closeAnim.stop();
        openAnim.restart();
    }

    function close() {
        openAnim.stop();
        closeAnim.restart();
    }

    function toggle() {
        if (visible)
            close();
        else
            open();
    }

    readonly property var tabs: ["lock"]

    function openTab(which) {
        tab = "lock";
        if (!visible)
            open();
    }

    // Waits out the close fade, so a capture never includes this panel.
    function launch(command) {
        close();
        Quickshell.execDetached(["sh", "-c", "sleep 0.35; " + command]);
    }

    function preview(id) {
        if (Services.LockScreen.has(id))
            launch("QS_LOCK_THEME=" + id + " exec quickshell -p \"$HOME/.config/nexa/quickshell/modules/lockthemes/LockPreview.qml\"");
    }

    function lockNow() {
        close();
        Quickshell.execDetached(["qs", "-p", Quickshell.env("HOME") + "/.config/nexa/quickshell", "ipc", "call", "lockScreen", "lock"]);
    }

    // ── Scrim ─────────────────────────────────────────────────────────────────

    Rectangle {
        id: scrim
        anchors.fill: parent
        color: Nexa.Theme.scrim
        opacity: 0
        enabled: opacity > 0.01

        MouseArea {
            anchors.fill: parent
            enabled: parent.enabled
            onClicked: root.close()
        }
    }

    ParallelAnimation {
        id: openAnim
        NumberAnimation { target: scrim; property: "opacity"; to: 0.55; duration: 240; easing.type: Easing.OutCubic }
        NumberAnimation { target: panel; property: "opacity"; to: 1; duration: 240; easing.type: Easing.OutCubic }
        NumberAnimation { target: panel; property: "scale"; to: 1; duration: 320; easing.type: Easing.OutBack }
    }

    ParallelAnimation {
        id: closeAnim
        NumberAnimation { target: scrim; property: "opacity"; to: 0; duration: 200; easing.type: Easing.InCubic }
        NumberAnimation { target: panel; property: "opacity"; to: 0; duration: 200; easing.type: Easing.InCubic }
        NumberAnimation { target: panel; property: "scale"; to: 0.94; duration: 200; easing.type: Easing.InCubic }
        onFinished: root.visible = false
    }

    // ── Panel ─────────────────────────────────────────────────────────────────

    Rectangle {
        id: panel

        anchors.centerIn: parent
        width: Math.min(1220, parent.width * 0.86)
        height: Math.min(900, parent.height * 0.9)
        radius: root.rad(Nexa.Theme.radiusLg + 6)
        color: Nexa.Theme.panelBackground
        border.width: Nexa.Theme.borderThin
        border.color: Nexa.Theme.border
        clip: true
        opacity: 0
        scale: 0.94

        // Keyboard handling for the whole panel.
        Item {
            id: keys
            focus: true

            Keys.onPressed: event => {
                const n = root.themes.length;
                const cols = root.columns;
                if (event.key === Qt.Key_Escape) {
                    root.close();
                } else if (event.key === Qt.Key_Right) {
                    root.cursor = (root.cursor + 1) % n;
                } else if (event.key === Qt.Key_Left) {
                    root.cursor = (root.cursor + n - 1) % n;
                } else if (event.key === Qt.Key_Down) {
                    root.cursor = Math.min(n - 1, root.cursor + cols);
                } else if (event.key === Qt.Key_Up) {
                    root.cursor = Math.max(0, root.cursor - cols);
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                    Services.LockScreen.select(root.themes[root.cursor].id);
                    root.close();
                } else if (event.key === Qt.Key_P) {
                    root.preview(root.themes[root.cursor].id);
                } else if (event.key === Qt.Key_S) {
                    Services.LockScreen.setShuffle(!root.shuffle);
                } else if (event.key === Qt.Key_L) {
                    root.lockNow();
                } else {
                    return;
                }
                event.accepted = true;
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(Nexa.Theme.primary.r, Nexa.Theme.primary.g, Nexa.Theme.primary.b, 0.08) }
                GradientStop { position: 0.35; color: "transparent" }
            }
        }

        Column {
            anchors.fill: parent
            anchors.margins: 28
            spacing: 18

            // ── Header ────────────────────────────────────────────────────────
            Item {
                width: parent.width
                height: 52

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 14

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 44
                        height: 44
                        radius: root.rad(14)
                        color: Nexa.Theme.primaryContainer

                        Glyph {
                            anchors.centerIn: parent
                            text: "lock"
                            filled: true
                            font.pixelSize: 22
                            color: Nexa.Theme.onPrimaryContainer
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        StyledText {
                            text: "Lock Screen Themes"
                            font.pixelSize: 21
                            font.weight: Font.Bold
                            color: Nexa.Theme.text
                        }

                        StyledText {
                            text: root.shuffle ? "Shuffle: each lock picks one of the selected themes"
                                : "Pick the design used when you lock"
                            font.pixelSize: 13
                            color: Nexa.Theme.mutedText
                        }
                    }
                }

                // Desktop | Widgets | Lock screen tabs hidden per user request
                Rectangle {
                    anchors.centerIn: parent
                    visible: false
                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10

                    // Shuffle switch
                    ClickableRect {
                        id: shuffleChip
                        anchors.verticalCenter: parent.verticalCenter
                        width: shuffleRow.implicitWidth + 28
                        height: 38
                        radius: root.rad(19)
                        color: root.shuffle ? Nexa.Theme.secondaryContainer
                            : shuffleChip.hovered ? Nexa.Theme.surfaceContainerHigh : Nexa.Theme.surfaceContainer
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Services.LockScreen.setShuffle(!root.shuffle)

                        Row {
                            id: shuffleRow
                            anchors.centerIn: parent
                            spacing: 8

                            Glyph {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "shuffle"
                                font.pixelSize: 17
                                color: root.shuffle ? Nexa.Theme.onSecondaryContainer : Nexa.Theme.mutedText
                            }

                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Shuffle"
                                font.pixelSize: 13
                                font.weight: Font.Medium
                                color: root.shuffle ? Nexa.Theme.onSecondaryContainer : Nexa.Theme.text
                            }

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 30
                                height: 18
                                radius: root.rad(9)
                                color: root.shuffle ? Nexa.Theme.primary : Nexa.Theme.surfaceContainerHighest

                                Rectangle {
                                    width: 12
                                    height: 12
                                    radius: root.rad(6)
                                    y: 3
                                    x: root.shuffle ? 15 : 3
                                    color: root.shuffle ? Nexa.Theme.onPrimary : Nexa.Theme.outline

                                    Behavior on x {
                                        NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                                    }
                                }
                            }
                        }
                    }

                    ClickableRect {
                        id: lockNowChip
                        anchors.verticalCenter: parent.verticalCenter
                        width: lockRow.implicitWidth + 28
                        height: 38
                        radius: root.rad(19)
                        color: lockNowChip.hovered ? Qt.lighter(Nexa.Theme.primary, 1.08) : Nexa.Theme.primary
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.lockNow()

                        Row {
                            id: lockRow
                            anchors.centerIn: parent
                            spacing: 8

                            Glyph {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "lock"
                                filled: true
                                font.pixelSize: 17
                                color: Nexa.Theme.onPrimary
                            }

                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Lock now"
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                color: Nexa.Theme.onPrimary
                            }
                        }
                    }

                    ClickableRect {
                        id: closeChip
                        anchors.verticalCenter: parent.verticalCenter
                        width: 38
                        height: 38
                        radius: root.rad(19)
                        color: closeChip.hovered ? Nexa.Theme.surfaceContainerHigh : "transparent"
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.close()

                        Glyph {
                            anchors.centerIn: parent
                            text: "close"
                            font.pixelSize: 20
                            color: Nexa.Theme.mutedText
                        }
                    }
                }
            }

            // ── Theme cards (live previews, created only while open) ──────────
            Loader {
                id: gridLoader
                width: parent.width
                height: parent.height - 52 - footer.height - 2 * parent.spacing
                active: root.visible
                sourceComponent: gridComponent
            }

            // ── Footer: progression stats ─────────────────────────────────────
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

    Component {
        id: gridComponent

        Item {
            // Demo context for the thumbnails: never talks to PAM; its ambient
            // clock runs only while the panel is open.
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

            Flickable {
                id: themeFlickable
                anchors.fill: parent
                contentHeight: grid.height
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Grid {
                    id: grid
                    width: parent.width
                    columns: root.columns
                    spacing: 18

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
                            height: thumb.height + info.implicitHeight + 34
                            radius: root.rad(Nexa.Theme.radiusLg)
                            z: focused ? 10 : 1
                            scale: focused ? 1.02 : 1.0

                            color: focused
                                ? Qt.rgba(Nexa.Theme.primary.r, Nexa.Theme.primary.g, Nexa.Theme.primary.b, 0.08)
                                : (cardArea.containsMouse ? Nexa.Theme.cardBackgroundElevated : Nexa.Theme.cardBackground)

                            border.width: chosen ? (focused ? 3 : 2) : (focused ? 2 : 1)
                            border.color: (chosen || focused) ? Nexa.Theme.primary : Nexa.Theme.border

                            Behavior on color {
                                ColorAnimation { duration: 140 }
                            }

                            Behavior on scale {
                                NumberAnimation { duration: 120; easing.type: Easing.OutQuad }
                            }

                            // Outer focus halo ring
                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: -4
                                radius: parent.radius + 4
                                color: "transparent"
                                border.width: 2
                                border.color: Qt.rgba(Nexa.Theme.primary.r, Nexa.Theme.primary.g, Nexa.Theme.primary.b, 0.45)
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
                                    root.close();
                                }
                            }

                            // Live thumbnail of the theme itself.
                            Item {
                                id: thumb
                                x: 10
                                y: 10
                                width: parent.width - 20
                                height: Math.round(width * 10 / 16)

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

                                // Preview button, on hover.
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

                                // Active badge.
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
        }
    }
}
