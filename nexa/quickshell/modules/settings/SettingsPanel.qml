// pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import Quickshell
import "../../theme/colors"
import "../../theme" as Nexa
import "../lockthemes/components"
import "../lockthemes"
import "../../services" as Services
import "../profile" as ProfileModule
import "../display" as DisplayModule

// SettingsPanel: Unified settings modal with left sidebar navigation.
Item {
    id: root

    anchors.fill: parent
    visible: false
    focus: true
    Keys.forwardTo: [keys]
    Keys.onEscapePressed: root.close()

    property string tab: "lock"
    readonly property var tabs: ["profile", "display", "bars", "lock", "system"]
    function rad(n) {
        if (Nexa.Theme.windowRounding === 0) return 0;
        return Math.max(0, Math.round(n * (Nexa.Theme.windowRounding / 10.0)));
    }

    readonly property bool shuffle: Services.LockScreen.shuffle

    function open() {
        visible = true;
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

    function openTab(which) {
        if (which === "system" || which === "profile" || which === "display" || which === "bars" || which === "lock")
            tab = which;
        else
            tab = "lock";
        if (!visible)
            open();
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
        width: Math.min(1240, (root.width > 0 ? root.width : 1920) * 0.88)
        height: Math.min(900, (root.height > 0 ? root.height : 1080) * 0.9)
        radius: Nexa.Theme.windowRounding === 0 ? 0 : root.rad(Nexa.Theme.radiusLg + 6)
        color: Nexa.Theme.panelBackground
        border.width: Nexa.Theme.borderThin
        border.color: Nexa.Theme.border
        clip: true
        opacity: 0
        scale: 0.94

        // Keyboard navigation
        Item {
            id: keys
            focus: true

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    root.close();
                    event.accepted = true;
                    return;
                }
                if (event.key === Qt.Key_Tab) {
                    const idx = root.tabs.indexOf(root.tab);
                    root.tab = root.tabs[(idx + 1) % root.tabs.length];
                    event.accepted = true;
                    return;
                }

                if (root.tab === "lock") {
                    const currentView = contentLoader.item;
                    if (!currentView) return;

                    const n = currentView.themes ? currentView.themes.length : 0;
                    const cols = currentView.columns ? currentView.columns : 2;

                    if (event.key === Qt.Key_Right) {
                        currentView.cursor = (currentView.cursor + 1) % n;
                    } else if (event.key === Qt.Key_Left) {
                        currentView.cursor = (currentView.cursor + n - 1) % n;
                    } else if (event.key === Qt.Key_Down) {
                        currentView.cursor = Math.min(n - 1, currentView.cursor + cols);
                    } else if (event.key === Qt.Key_Up) {
                        currentView.cursor = Math.max(0, currentView.cursor - cols);
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                        Services.LockScreen.select(currentView.themes[currentView.cursor].id);
                        root.close();
                    } else if (event.key === Qt.Key_P) {
                        currentView.preview(currentView.themes[currentView.cursor].id);
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
        }

        // Background subtle gradient glow
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(Nexa.Theme.primary.r, Nexa.Theme.primary.g, Nexa.Theme.primary.b, 0.08) }
                GradientStop { position: 0.35; color: "transparent" }
            }
        }

        Row {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 24

            // ── Left Sidebar Navigation ───────────────────────────────────────
            Item {
                width: 230
                height: parent.height

                Column {
                    anchors.fill: parent
                    spacing: 8

                    // App Header / Brand
                    Row {
                        spacing: 12
                        height: 44
                        anchors.left: parent.left
                        anchors.leftMargin: 6

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 36
                            height: 36
                            radius: root.rad(10)
                            color: Nexa.Theme.primaryContainer

                            Text {
                                anchors.centerIn: parent
                                text: "󰒓"
                                font.family: Nexa.Theme.iconFontFamily
                                font.pixelSize: 20
                                color: Nexa.Theme.onPrimaryContainer
                            }
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 1

                            StyledText {
                                text: "Settings"
                                font.pixelSize: 18
                                font.weight: Font.Bold
                                color: Nexa.Theme.text
                            }

                            StyledText {
                                text: "Nexa Desktop"
                                font.pixelSize: 11
                                color: Nexa.Theme.mutedText
                            }
                        }
                    }

                    Item { width: 1; height: 16 }

                    StyledText {
                        text: "SYSTEM"
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        font.letterSpacing: 1.0
                        color: Nexa.Theme.mutedText
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                    }

                    Item { width: 1; height: 4 }

                    // Nav Option 1: Profile
                    ClickableRect {
                        id: profileNavBtn
                        anchors.left: parent.left
                        anchors.leftMargin: 6
                        width: parent.width - 26
                        height: 42
                        radius: root.rad(10)
                        color: root.tab === "profile"
                            ? Nexa.Theme.primaryContainer
                            : (profileNavBtn.hovered ? Nexa.Theme.surfaceContainerHigh : "transparent")
                        border.width: root.tab === "profile" ? 1.5 : 1
                        border.color: root.tab === "profile" ? Nexa.Theme.primary : (profileNavBtn.hovered ? Nexa.Theme.border : "transparent")
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.tab = "profile"

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 12

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: ""
                                font.family: Nexa.Theme.iconFontFamily
                                font.pixelSize: 18
                                color: root.tab === "profile" ? Nexa.Theme.onPrimaryContainer : Nexa.Theme.text
                            }

                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Profile"
                                font.pixelSize: 14
                                font.weight: root.tab === "profile" ? Font.Bold : Font.Medium
                                color: root.tab === "profile" ? Nexa.Theme.onPrimaryContainer : Nexa.Theme.text
                            }
                        }
                    }

                    // Nav Option 2: Display
                    ClickableRect {
                        id: displayNavBtn
                        anchors.left: parent.left
                        anchors.leftMargin: 6
                        width: parent.width - 26
                        height: 42
                        radius: root.rad(10)
                        color: root.tab === "display"
                            ? Nexa.Theme.primaryContainer
                            : (displayNavBtn.hovered ? Nexa.Theme.surfaceContainerHigh : "transparent")
                        border.width: root.tab === "display" ? 1.5 : 1
                        border.color: root.tab === "display" ? Nexa.Theme.primary : (displayNavBtn.hovered ? Nexa.Theme.border : "transparent")
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.tab = "display"

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 12

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "󰍹"
                                font.family: Nexa.Theme.iconFontFamily
                                font.pixelSize: 18
                                color: root.tab === "display" ? Nexa.Theme.onPrimaryContainer : Nexa.Theme.text
                            }

                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Display"
                                font.pixelSize: 14
                                font.weight: root.tab === "display" ? Font.Bold : Font.Medium
                                color: root.tab === "display" ? Nexa.Theme.onPrimaryContainer : Nexa.Theme.text
                            }
                        }
                    }

                    // Nav Option 3: Bars
                    ClickableRect {
                        id: barsNavBtn
                        anchors.left: parent.left
                        anchors.leftMargin: 6
                        width: parent.width - 26
                        height: 42
                        radius: root.rad(10)
                        color: root.tab === "bars"
                            ? Nexa.Theme.primaryContainer
                            : (barsNavBtn.hovered ? Nexa.Theme.surfaceContainerHigh : "transparent")
                        border.width: root.tab === "bars" ? 1.5 : 1
                        border.color: root.tab === "bars" ? Nexa.Theme.primary : (barsNavBtn.hovered ? Nexa.Theme.border : "transparent")
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.tab = "bars"

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 12

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "󰈺"
                                font.family: Nexa.Theme.iconFontFamily
                                font.pixelSize: 18
                                color: root.tab === "bars" ? Nexa.Theme.onPrimaryContainer : Nexa.Theme.text
                            }

                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Bars"
                                font.pixelSize: 14
                                font.weight: root.tab === "bars" ? Font.Bold : Font.Medium
                                color: root.tab === "bars" ? Nexa.Theme.onPrimaryContainer : Nexa.Theme.text
                            }
                        }
                    }

                    Item { width: 1; height: 10 }

                    StyledText {
                        text: "CUSTOMIZATION"
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        font.letterSpacing: 1.0
                        color: Nexa.Theme.mutedText
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                    }

                    Item { width: 1; height: 4 }

                    // Nav Option 1: Lock Screen Themes
                    ClickableRect {
                        id: lockNavBtn
                        anchors.left: parent.left
                        anchors.leftMargin: 6
                        width: parent.width - 26
                        height: 42
                        radius: root.rad(10)
                        color: root.tab === "lock"
                            ? Nexa.Theme.primaryContainer
                            : (lockNavBtn.hovered ? Nexa.Theme.surfaceContainerHigh : "transparent")
                        border.width: root.tab === "lock" ? 1.5 : 1
                        border.color: root.tab === "lock" ? Nexa.Theme.primary : (lockNavBtn.hovered ? Nexa.Theme.border : "transparent")
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.tab = "lock"

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 12

                            Glyph {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "lock"
                                filled: root.tab === "lock"
                                font.pixelSize: 19
                                color: root.tab === "lock" ? Nexa.Theme.onPrimaryContainer : Nexa.Theme.text
                            }

                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Lock Screen"
                                font.pixelSize: 14
                                font.weight: root.tab === "lock" ? Font.Bold : Font.Medium
                                color: root.tab === "lock" ? Nexa.Theme.onPrimaryContainer : Nexa.Theme.text
                            }
                        }
                    }

                    // Nav Option 2: System Themes
                    ClickableRect {
                        id: systemNavBtn
                        anchors.left: parent.left
                        anchors.leftMargin: 6
                        width: parent.width - 26
                        height: 42
                        radius: root.rad(10)
                        color: root.tab === "system"
                            ? Nexa.Theme.primaryContainer
                            : (systemNavBtn.hovered ? Nexa.Theme.surfaceContainerHigh : "transparent")
                        border.width: root.tab === "system" ? 1.5 : 1
                        border.color: root.tab === "system" ? Nexa.Theme.primary : (systemNavBtn.hovered ? Nexa.Theme.border : "transparent")
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.tab = "system"

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 12

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "󰏘"
                                font.family: Nexa.Theme.iconFontFamily
                                font.pixelSize: 18
                                color: root.tab === "system" ? Nexa.Theme.onPrimaryContainer : Nexa.Theme.text
                            }

                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "System Themes"
                                font.pixelSize: 14
                                font.weight: root.tab === "system" ? Font.Bold : Font.Medium
                                color: root.tab === "system" ? Nexa.Theme.onPrimaryContainer : Nexa.Theme.text
                            }
                        }
                    }
                }

                // Vertical separator line on the right of the sidebar
                Rectangle {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 1
                    color: Nexa.Theme.border
                    opacity: 0.6
                }
            }

            // ── Right Main Content Area ───────────────────────────────────────
            Column {
                width: parent.width - 230 - parent.spacing
                height: parent.height
                spacing: 16

                // Top Header inside the content view
                Item {
                    width: parent.width
                    height: 48

                    // Title & Description
                    Column {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        StyledText {
                            text: {
                                if (root.tab === "profile") return "Profile";
                                if (root.tab === "display") return "Display Settings";
                                if (root.tab === "bars") return "Bars & Panels";
                                if (root.tab === "system") return "System Themes";
                                return "Lock Screen Themes";
                            }
                            font.pixelSize: 20
                            font.weight: Font.Bold
                            color: Nexa.Theme.text
                        }

                        StyledText {
                            text: {
                                if (root.tab === "profile") return "User account & system identity";
                                if (root.tab === "display") return "Display layout, resolution & scaling";
                                if (root.tab === "bars") return "Status bar layout, components & appearance";
                                if (root.tab === "system") return "Desktop customization and appearance";
                                return (root.shuffle ? "Shuffle: each lock picks one of the selected themes" : "Pick the design used when you lock");
                            }
                            font.pixelSize: 12
                            color: Nexa.Theme.mutedText
                        }
                    }

                    // Action chips on the right
                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 10

                        // Shuffle switch (Lock screen only)
                        ClickableRect {
                            id: shuffleChip
                            visible: root.tab === "lock"
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

                        // Lock now button (Lock screen only)
                        ClickableRect {
                            id: lockNowChip
                            visible: root.tab === "lock"
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

                        // Universal Close Button
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

                // Main Content View
                Item {
                    width: parent.width
                    height: parent.height - 48 - parent.spacing

                    Loader {
                        id: contentLoader
                        anchors.fill: parent
                        sourceComponent: {
                            if (root.tab === "profile") return profileTabComponent;
                            if (root.tab === "display") return displayTabComponent;
                            if (root.tab === "bars") return barsTabComponent;
                            if (root.tab === "system") return systemTabComponent;
                            return lockTabComponent;
                        }
                    }
                }
            }
        }
    }

    Component {
        id: profileTabComponent
        ProfileModule.ProfileSettings {
            onRequestClose: root.close()
            onOpenWallpaper: {
                root.close();
                Quickshell.execDetached(["qs", "-p", Quickshell.env("HOME") + "/.config/nexa/quickshell", "ipc", "call", "wallpaper", "open"]);
            }
            onOpenLockTab: {
                root.tab = "lock";
            }
        }
    }

    Component {
        id: displayTabComponent
        DisplayModule.DisplaySettings {
            onRequestClose: root.close()
        }
    }

    Component {
        id: barsTabComponent
        BarsSettings {
            onRequestClose: root.close()
        }
    }

    Component {
        id: lockTabComponent
        LockScreenSettings {
            onRequestClose: root.close()
        }
    }

    Component {
        id: systemTabComponent
        SystemThemeSettings {
            onRequestClose: root.close()
        }
    }
}
