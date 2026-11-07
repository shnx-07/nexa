// pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import Quickshell
import "../../NewNexaUI" as NexaUI
import "../lockthemes/components"
import "../lockthemes"
import "../../services" as Services
import "profile" as ProfileModule
import "display" as DisplayModule
import "power" as PowerModule
import "sound" as SoundModule

// SettingsPanel: Unified settings modal with left sidebar navigation.
Item {
    id: root

    anchors.fill: parent
    visible: false
    focus: true
    Keys.forwardTo: [keys]
    Keys.onEscapePressed: root.close()

    property string tab: "profile"
    readonly property var tabs: ["profile", "performance", "sound", "display", "power", "bars", "decorations", "motion", "lock", "system"]
    function rad(n) {
        if (NexaUI.NexaTokens.nexaRounding === 0) return 0;
        return Math.max(0, Math.round(n * (NexaUI.NexaTokens.nexaRounding / 10.0)));
    }

    readonly property bool shuffle: Services.LockScreen.shuffle

    function open() {
        if (!tab) tab = "profile";
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
        if (!visible)
            open();
        if (which === "performance" || which === "system" || which === "profile" || which === "sound" || which === "display" || which === "bars" || which === "decorations" || which === "motion" || which === "lock" || which === "power")
            tab = which;
        else
            tab = "profile";
    }

    function lockNow() {
        close();
        Quickshell.execDetached(["qs", "-p", Quickshell.env("HOME") + "/.config/nexa/quickshell", "ipc", "call", "lockScreen", "lock"]);
    }

    // ── Scrim ─────────────────────────────────────────────────────────────────
    Rectangle {
        id: scrim
        anchors.fill: parent
        color: NexaUI.NexaOptics.glassMode ? Qt.rgba(0, 0, 0, 0.22) : NexaUI.NexaColors.scrim
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
        NumberAnimation { target: scrim; property: "opacity"; to: NexaUI.NexaOptics.glassMode ? 0.35 : 0.55; duration: NexaUI.NexaMotion.durationNormal; easing.type: NexaUI.NexaMotion.decelerateEasing }
        NumberAnimation { target: panel; property: "opacity"; to: 1; duration: NexaUI.NexaMotion.durationNormal; easing.type: NexaUI.NexaMotion.decelerateEasing }
        NumberAnimation { target: panel; property: "scale"; to: 1; duration: NexaUI.NexaMotion.durationNormal; easing.type: NexaUI.NexaMotion.emphasizedEasing }
    }

    ParallelAnimation {
        id: closeAnim
        NumberAnimation { target: scrim; property: "opacity"; to: 0; duration: NexaUI.NexaMotion.durationFast; easing.type: NexaUI.NexaMotion.accelerationEasing }
        NumberAnimation { target: panel; property: "opacity"; to: 0; duration: NexaUI.NexaMotion.durationFast; easing.type: NexaUI.NexaMotion.accelerationEasing }
        NumberAnimation { target: panel; property: "scale"; to: 0.94; duration: NexaUI.NexaMotion.durationFast; easing.type: NexaUI.NexaMotion.accelerationEasing }
        onFinished: root.visible = false
    }

    // ── Panel Shadow ──────────────────────────────────────────────────────────
    NexaUI.NexaShadow {
        id: panelShadow
        targetItem: panel
        elevation: 2
        spread: 0.12
    }

    // ── Panel ─────────────────────────────────────────────────────────────────
    Rectangle {
        id: panel

        anchors.centerIn: parent
        width: Math.min(1240, (root.width > 0 ? root.width : 1920) * 0.88)
        height: Math.min(900, (root.height > 0 ? root.height : 1080) * 0.9)
        radius: NexaUI.NexaTokens.nexaRounding
        color: NexaUI.NexaColors.surfaceContainerLow
        border.width: NexaUI.NexaTokens.borderThin
        border.color: NexaUI.NexaColors.border
        clip: true
        opacity: 0
        scale: 0.94

        NexaUI.NexaShaderSubstrate {
            anchors.fill: parent
            radius: panel.radius
        }

        // Apple / Tactile 4-stop OLED Depth Micro-Gradient
        Rectangle {
            anchors.fill: parent
            radius: panel.radius
            antialiasing: panel.radius > 0
            visible: NexaUI.NexaOptics.surface3DGradient && NexaUI.NexaOptics.gradientIntensity > 0.01
            opacity: NexaUI.NexaOptics.gradientIntensity
            z: 0
            gradient: Gradient {
                GradientStop { position: 0.00; color: Qt.rgba(1, 1, 1, 0.055) }
                GradientStop { position: 0.40; color: Qt.rgba(1, 1, 1, 0.012) }
                GradientStop { position: 0.75; color: Qt.rgba(0, 0, 0, 0.000) }
                GradientStop { position: 1.00; color: Qt.rgba(0, 0, 0, 0.120) }
            }
        }

        // Apple Top Chamfer Specular Highlight
        Rectangle {
            anchors.top: parent.top
            anchors.topMargin: 1
            anchors.horizontalCenter: parent.horizontalCenter
            width: panel.radius > 0 ? Math.max(0, parent.width - panel.radius * 1.6) : parent.width
            height: 1
            visible: NexaUI.NexaOptics.specularHighlight && NexaUI.NexaOptics.specularIntensity > 0.01
            opacity: Math.min(1.0, NexaUI.NexaOptics.specularIntensity / 0.28)
            z: 1
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.30) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        MouseArea {
            anchors.fill: parent
            // Prevent clicks on empty panel area from propagating to scrim
            onClicked: {}
        }

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

        Row {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 24

            // ── Left Sidebar Navigation ───────────────────────────────────────
            Item {
                width: 230
                height: parent.height

                // Fluid Selection Indicator Pill (Slides across tabs with harmonic spring)
                Rectangle {
                    id: activeNavPill
                    anchors.left: parent.left
                    anchors.leftMargin: 6
                    width: parent.width - 26
                    height: 42
                    radius: root.rad(10)
                    color: NexaUI.NexaColors.primaryContainer
                    border.width: 1.5
                    border.color: NexaUI.NexaColors.primary
                    z: 0

                    readonly property Item activeBtn: {
                        switch (root.tab) {
                            case "profile": return profileNavBtn;
                            case "performance": return perfNavBtn;
                            case "sound": return soundNavBtn;
                            case "display": return displayNavBtn;
                            case "power": return powerNavBtn;
                            case "bars": return barsNavBtn;
                            case "decorations": return decorNavBtn;
                            case "motion": return motionNavBtn;
                            case "lock": return lockNavBtn;
                            case "system": return systemNavBtn;
                            default: return profileNavBtn;
                        }
                    }

                    y: activeBtn ? (navCol.y + activeBtn.y) : 0
                    visible: activeBtn !== null

                    Behavior on y {
                        enabled: NexaUI.NexaMotion.enabled
                        SpringAnimation {
                            spring: NexaUI.NexaMotion.navSpringStiffness * 3.5
                            damping: NexaUI.NexaMotion.navSpringDamping
                            mass: NexaUI.NexaMotion.springMass
                            epsilon: 0.25
                        }
                    }
                }

                Column {
                    id: navCol
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
                            color: NexaUI.NexaColors.primaryContainer

                            Text {
                                anchors.centerIn: parent
                                text: "󰒓"
                                font.family: NexaUI.NexaTypography.familyIcon
                                font.pixelSize: 20
                                color: NexaUI.NexaColors.onPrimaryContainer
                            }
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 1

                            StyledText {
                                text: "Settings"
                                font.pixelSize: 18
                                font.weight: Font.Bold
                                color: NexaUI.NexaColors.text
                            }

                            StyledText {
                                text: "Nexa Desktop"
                                font.pixelSize: 11
                                color: NexaUI.NexaColors.mutedText
                            }
                        }
                    }

                    Item { width: 1; height: 16 }

                    StyledText {
                        text: "SYSTEM"
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        font.letterSpacing: 1.0
                        color: NexaUI.NexaColors.mutedText
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                    }

                    Item { width: 1; height: 4 }

                    // Nav Option 1: Profile
                    NexaUI.NexaButton {
                        id: profileNavBtn
                        anchors.left: parent.left
                        anchors.leftMargin: 6
                        width: parent.width - 26
                        customHeight: 42
                        customRadius: root.rad(10)
                        variant: "ghost"
                        alignment: "left"
                        selected: root.tab === "profile"
                        icon: ""
                        text: "Profile"
                        onClicked: root.tab = "profile"
                        z: 1
                    }

                    // Nav Option 1.2: Performance
                    NexaUI.NexaButton {
                        id: perfNavBtn
                        anchors.left: parent.left
                        anchors.leftMargin: 6
                        width: parent.width - 26
                        customHeight: 42
                        customRadius: root.rad(10)
                        variant: "ghost"
                        alignment: "left"
                        selected: root.tab === "performance"
                        icon: "󰍛"
                        text: "Performance"
                        onClicked: root.tab = "performance"
                        z: 1
                    }

                    // Nav Option 1.5: Sound & Audio
                    NexaUI.NexaButton {
                        id: soundNavBtn
                        anchors.left: parent.left
                        anchors.leftMargin: 6
                        width: parent.width - 26
                        customHeight: 42
                        customRadius: root.rad(10)
                        variant: "ghost"
                        alignment: "left"
                        selected: root.tab === "sound"
                        icon: "󰕾"
                        text: "Sound & Audio"
                        onClicked: root.tab = "sound"
                        z: 1
                    }

                    // Nav Option 2: Display
                    NexaUI.NexaButton {
                        id: displayNavBtn
                        anchors.left: parent.left
                        anchors.leftMargin: 6
                        width: parent.width - 26
                        customHeight: 42
                        customRadius: root.rad(10)
                        variant: "ghost"
                        alignment: "left"
                        selected: root.tab === "display"
                        icon: "󰍹"
                        text: "Display"
                        onClicked: root.tab = "display"
                        z: 1
                    }

                    // Nav Option 2.5: Power & Sleep
                    NexaUI.NexaButton {
                        id: powerNavBtn
                        anchors.left: parent.left
                        anchors.leftMargin: 6
                        width: parent.width - 26
                        customHeight: 42
                        customRadius: root.rad(10)
                        variant: "ghost"
                        alignment: "left"
                        selected: root.tab === "power"
                        icon: "󱐋"
                        text: "Power & Sleep"
                        onClicked: root.tab = "power"
                        z: 1
                    }

                    // Nav Option 3: Bars
                    NexaUI.NexaButton {
                        id: barsNavBtn
                        anchors.left: parent.left
                        anchors.leftMargin: 6
                        width: parent.width - 26
                        customHeight: 42
                        customRadius: root.rad(10)
                        variant: "ghost"
                        alignment: "left"
                        selected: root.tab === "bars"
                        icon: "󰈺"
                        text: "Bars"
                        onClicked: root.tab = "bars"
                        z: 1
                    }

                    Item { width: 1; height: 10 }

                    StyledText {
                        text: "CUSTOMIZATION"
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        font.letterSpacing: 1.0
                        color: NexaUI.NexaColors.mutedText
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                    }

                    Item { width: 1; height: 4 }

                    // Nav Option: Decorations
                    NexaUI.NexaButton {
                        id: decorNavBtn
                        anchors.left: parent.left
                        anchors.leftMargin: 6
                        width: parent.width - 26
                        customHeight: 42
                        customRadius: root.rad(10)
                        variant: "ghost"
                        alignment: "left"
                        selected: root.tab === "decorations"
                        icon: ""
                        text: "Decorations"
                        onClicked: root.tab = "decorations"
                        z: 1
                    }

                    // Nav Option: Motion & Physics
                    NexaUI.NexaButton {
                        id: motionNavBtn
                        anchors.left: parent.left
                        anchors.leftMargin: 6
                        width: parent.width - 26
                        customHeight: 42
                        customRadius: root.rad(10)
                        variant: "ghost"
                        alignment: "left"
                        selected: root.tab === "motion"
                        icon: "󰏢"
                        text: "Motion & Physics"
                        onClicked: root.tab = "motion"
                        z: 1
                    }

                    // Nav Option: Lock Screen Themes
                    NexaUI.NexaButton {
                        id: lockNavBtn
                        anchors.left: parent.left
                        anchors.leftMargin: 6
                        width: parent.width - 26
                        customHeight: 42
                        customRadius: root.rad(10)
                        variant: "ghost"
                        alignment: "left"
                        selected: root.tab === "lock"
                        icon: "󰌾"
                        text: "Lock Screen"
                        onClicked: root.tab = "lock"
                        z: 1
                    }

                    // Nav Option: System Themes
                    NexaUI.NexaButton {
                        id: systemNavBtn
                        anchors.left: parent.left
                        anchors.leftMargin: 6
                        width: parent.width - 26
                        customHeight: 42
                        customRadius: root.rad(10)
                        variant: "ghost"
                        alignment: "left"
                        selected: root.tab === "system"
                        icon: "󰏘"
                        text: "System Themes"
                        onClicked: root.tab = "system"
                        z: 1
                    }
                }

                // Vertical separator line on the right of the sidebar
                Rectangle {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 1
                    color: NexaUI.NexaColors.border
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
                                if (root.tab === "performance") return "System Performance";
                                if (root.tab === "sound") return "Sound & Audio";
                                if (root.tab === "display") return "Display Settings";
                                if (root.tab === "power") return "Power & Sleep Settings";
                                if (root.tab === "bars") return "Bars & Panels";
                                if (root.tab === "decorations") return "Bar Decorations";
                                if (root.tab === "motion") return "Motion & Physics";
                                if (root.tab === "system") return "System Themes";
                                return "Lock Screen Themes";
                            }
                            font.pixelSize: 20
                            font.weight: Font.Bold
                            color: NexaUI.NexaColors.text
                        }

                        StyledText {
                            text: {
                                if (root.tab === "profile") return "User account & system identity";
                                if (root.tab === "performance") return "Live resource metrics, historical telemetry & active process monitor";
                                if (root.tab === "sound") return "Hardware output, microphone monitor & desktop acoustic effects";
                                if (root.tab === "display") return "Display layout, resolution & scaling";
                                if (root.tab === "power") return "Battery, screen backlight timeouts & sleep behaviors";
                                if (root.tab === "bars") return "Status bar layout, components & appearance";
                                if (root.tab === "decorations") return "Ambient horizon rail, constellation beads & music soundwave effects";
                                if (root.tab === "motion") return "Harmonic spring physics, momentum and interactive timings";
                                if (root.tab === "system") return "Desktop customization and appearance";
                                return (root.shuffle ? "Shuffle: each lock picks one of the selected themes" : "Pick the design used when you lock");
                            }
                            font.pixelSize: 12
                            color: NexaUI.NexaColors.mutedText
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
                            color: root.shuffle ? NexaUI.NexaColors.secondaryContainer
                                : shuffleChip.hovered ? NexaUI.NexaColors.surfaceContainerHigh : NexaUI.NexaColors.surfaceContainer
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
                                    color: root.shuffle ? NexaUI.NexaColors.onSecondaryContainer : NexaUI.NexaColors.mutedText
                                }

                                StyledText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Shuffle"
                                    font.pixelSize: 13
                                    font.weight: Font.Medium
                                    color: root.shuffle ? NexaUI.NexaColors.onSecondaryContainer : NexaUI.NexaColors.text
                                }

                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 30
                                    height: 18
                                    radius: root.rad(9)
                                    color: root.shuffle ? NexaUI.NexaColors.primary : NexaUI.NexaColors.surfaceContainerHighest

                                    Rectangle {
                                        width: 12
                                        height: 12
                                        radius: root.rad(6)
                                        y: 3
                                        x: root.shuffle ? 15 : 3
                                        color: root.shuffle ? NexaUI.NexaColors.onPrimary : NexaUI.NexaColors.outline

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
                            color: lockNowChip.hovered ? Qt.lighter(NexaUI.NexaColors.primary, 1.08) : NexaUI.NexaColors.primary
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
                                    color: NexaUI.NexaColors.onPrimary
                                }

                                StyledText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Lock now"
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                    color: NexaUI.NexaColors.onPrimary
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
                            color: closeChip.hovered ? NexaUI.NexaColors.surfaceContainerHigh : "transparent"
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.close()

                            Glyph {
                                anchors.centerIn: parent
                                text: "close"
                                font.pixelSize: 20
                                color: NexaUI.NexaColors.mutedText
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
                        active: root.visible
                        sourceComponent: {
                            if (root.tab === "profile") return profileTabComponent;
                            if (root.tab === "performance") return performanceTabComponent;
                            if (root.tab === "sound") return soundTabComponent;
                            if (root.tab === "display") return displayTabComponent;
                            if (root.tab === "power") return powerTabComponent;
                            if (root.tab === "bars") return barsTabComponent;
                            if (root.tab === "decorations") return decorationsTabComponent;
                            if (root.tab === "motion") return motionTabComponent;
                            if (root.tab === "system") return systemTabComponent;
                            return lockTabComponent;
                        }
                    }
                }
            }
        }
    }

    Component {
        id: decorationsTabComponent
        DecorationsSettings {
            onRequestClose: root.close()
        }
    }

    Component {
        id: soundTabComponent
        SoundModule.SoundSettings {
            onRequestClose: root.close()
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
        id: performanceTabComponent
        PerformanceSettings {
            onRequestClose: root.close()
        }
    }

    Component {
        id: powerTabComponent
        PowerModule.PowerSettings {
            onRequestClose: root.close()
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

    Component {
        id: motionTabComponent
        MotionSettings {
            onRequestClose: root.close()
        }
    }
}