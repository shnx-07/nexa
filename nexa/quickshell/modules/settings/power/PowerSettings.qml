// pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../../theme" as Nexa
import "../../lockthemes/components"
import "../../../services" as Services
import "../../../theme/components" as NexaUI

Item {
    id: root

    anchors.fill: parent

    signal requestClose()

    readonly property string configPath: Quickshell.env("HOME") + "/.config/nexa/config/power.json"
    readonly property string syncScript: Quickshell.env("HOME") + "/.config/nexa/scripts/power-sync.sh"

    // Configuration state
    property int screenOffBattery: 300
    property int screenOffAc: 600
    property int lockBattery: 180
    property int lockAc: 300
    property int sleepBattery: 900
    property int sleepAc: 1800
    property bool batterySaverEnabled: true
    property int batterySaverThreshold: 20

    // Toast status
    property string toastMessage: ""
    property bool toastVisible: false

    function showToast(msg) {
        toastMessage = msg;
        toastVisible = true;
        toastTimer.restart();
    }

    Timer {
        id: toastTimer
        interval: 2200
        repeat: false
        onTriggered: root.toastVisible = false
    }

    // Live battery / power readings
    readonly property bool isCharging: Services.Battery ? Services.Battery.charging : false
    readonly property int batteryPercent: Services.Battery ? Services.Battery.percentage : 100

    function rad(n) {
        if (Nexa.Theme.nexaRounding === 0) return 0;
        return Math.max(0, Math.round(n * (Nexa.Theme.nexaRounding / 10.0)));
    }

    function loadConfig() {
        loadProcess.running = true;
    }

    function saveConfig() {
        var cfg = {
            "screen_off_battery": root.screenOffBattery,
            "screen_off_ac": root.screenOffAc,
            "lock_battery": root.lockBattery,
            "lock_ac": root.lockAc,
            "sleep_battery": root.sleepBattery,
            "sleep_ac": root.sleepAc,
            "battery_saver_enabled": root.batterySaverEnabled,
            "battery_saver_threshold": root.batterySaverThreshold
        };
        var jsonStr = JSON.stringify(cfg, null, 2);
        saveProcess.command = ["bash", "-c", "cat << 'EOF' > " + root.configPath + "\n" + jsonStr + "\nEOF\n" + root.syncScript];
        saveProcess.running = true;
        showToast("✓ Power settings applied & synced");
    }

    Process {
        id: loadProcess
        command: ["cat", root.configPath]
        stdout: StdioCollector {
            onStreamFinished: {
                if (this.text && this.text.trim() !== "") {
                    try {
                        var c = JSON.parse(this.text);
                        root.screenOffBattery = c.screen_off_battery !== undefined ? c.screen_off_battery : 300;
                        root.screenOffAc = c.screen_off_ac !== undefined ? c.screen_off_ac : 600;
                        root.lockBattery = c.lock_battery !== undefined ? c.lock_battery : 180;
                        root.lockAc = c.lock_ac !== undefined ? c.lock_ac : 300;
                        root.sleepBattery = c.sleep_battery !== undefined ? c.sleep_battery : 900;
                        root.sleepAc = c.sleep_ac !== undefined ? c.sleep_ac : 1800;
                        root.batterySaverEnabled = c.battery_saver_enabled !== undefined ? c.battery_saver_enabled : true;
                        root.batterySaverThreshold = c.battery_saver_threshold !== undefined ? c.battery_saver_threshold : 20;
                    } catch (e) {
                        console.warn("PowerSettings: failed to parse JSON", e);
                    }
                }
            }
        }
    }

    Process {
        id: saveProcess
        command: ["true"]
    }

    Component.onCompleted: {
        loadConfig();
    }

    // ────────────────────────────────────────────────────────────
    // MAIN SCROLLABLE CONTENT
    // ────────────────────────────────────────────────────────────
    Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: contentCol.height + 48
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: contentCol
            width: parent.width - 24
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 16

            // ────────────────────────────────────────────────────────
            // 1. LIVE POWER & BATTERY HERO CARD
            // ────────────────────────────────────────────────────────
            Rectangle {
                width: parent.width
                height: 94
                radius: root.rad(14)
                color: Nexa.Theme.surfaceContainer
                border.width: Nexa.Theme.borderThin
                border.color: Nexa.Theme.border

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 18

                    Rectangle {
                        width: 56
                        height: 56
                        radius: root.rad(12)
                        color: root.isCharging ? Nexa.Theme.primaryContainer : Nexa.Theme.surfaceContainerHigh
                        border.width: Nexa.Theme.borderThin
                        border.color: root.isCharging ? Nexa.Theme.primary : Nexa.Theme.border

                        Text {
                            anchors.centerIn: parent
                            text: root.isCharging ? "󱐋" : (root.batteryPercent > 20 ? "󰁹" : "󰂃")
                            font.family: Nexa.Theme.iconFontFamily
                            font.pixelSize: 26
                            color: root.isCharging ? Nexa.Theme.primary : (root.batteryPercent <= 20 ? Nexa.Theme.error : Nexa.Theme.text)
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Row {
                            spacing: 10
                            StyledText {
                                text: root.isCharging ? "Plugged In & Charging (" + root.batteryPercent + "%)" : "Running on Battery (" + root.batteryPercent + "%)"
                                font.pixelSize: 17
                                font.weight: Font.Bold
                                color: Nexa.Theme.text
                            }

                            Rectangle {
                                visible: root.batterySaverEnabled && !root.isCharging && root.batteryPercent <= root.batterySaverThreshold
                                height: 22
                                width: bSaverTxt.implicitWidth + 14
                                radius: root.rad(6)
                                color: Nexa.Theme.errorContainer
                                border.width: Nexa.Theme.borderThin
                                border.color: Nexa.Theme.error
                                anchors.verticalCenter: parent.verticalCenter

                                StyledText {
                                    id: bSaverTxt
                                    anchors.centerIn: parent
                                    text: "󰂃 Safe Mode Active"
                                    font.pixelSize: 11
                                    font.weight: Font.Bold
                                    color: Nexa.Theme.onErrorContainer
                                }
                            }
                        }

                        StyledText {
                            text: root.isCharging ? "Active Profile: AC High Performance & Extended Sleep Timeouts" : "Active Profile: Dynamic Battery Conservation & Smart Dimming"
                            font.pixelSize: 12
                            color: Nexa.Theme.mutedText
                        }
                    }

                    // Quick Power Action Pill
                    ClickableRect {
                        width: 120
                        height: 38
                        radius: root.rad(10)
                        color: Nexa.Theme.surfaceContainerHigh
                        border.width: Nexa.Theme.borderThin
                        border.color: Nexa.Theme.border
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.saveConfig()

                        Row {
                            anchors.centerIn: parent
                            spacing: 8
                            Text {
                                text: "󰑐"
                                font.family: Nexa.Theme.iconFontFamily
                                font.pixelSize: 14
                                color: Nexa.Theme.primary
                            }
                            StyledText {
                                text: "Sync Daemon"
                                font.pixelSize: 12
                                font.weight: Font.Medium
                                color: Nexa.Theme.text
                            }
                        }
                    }
                }
            }

            // ────────────────────────────────────────────────────────
            // 2. SCREEN LIGHT & DISPLAY TIMEOUT
            // ────────────────────────────────────────────────────────
            Rectangle {
                width: parent.width
                implicitHeight: lightCol.implicitHeight + 36
                radius: root.rad(14)
                color: Nexa.Theme.surfaceContainer
                border.width: Nexa.Theme.borderThin
                border.color: Nexa.Theme.border

                Column {
                    id: lightCol
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 16

                    RowLayout {
                        width: parent.width
                        spacing: 10
                        Text {
                            text: "󰌵"
                            font.family: Nexa.Theme.iconFontFamily
                            font.pixelSize: 20
                            color: Nexa.Theme.primary
                        }
                        ColumnLayout {
                            spacing: 2
                            StyledText {
                                text: "Screen Light & Backlight Timeout"
                                font.pixelSize: 15
                                font.weight: Font.Bold
                                color: Nexa.Theme.text
                            }
                            StyledText {
                                text: "Turns off display backlight when idle to preserve power and panel life."
                                font.pixelSize: 12
                                color: Nexa.Theme.mutedText
                            }
                        }
                    }

                    // On Battery Chips
                    Column {
                        width: parent.width
                        spacing: 8

                        Row {
                            spacing: 6
                            Text { text: "󰁹"; font.family: Nexa.Theme.iconFontFamily; font.pixelSize: 13; color: Nexa.Theme.mutedText }
                            StyledText { text: "When running on battery:"; font.pixelSize: 12; font.weight: Font.Medium; color: Nexa.Theme.mutedText }
                        }

                        Flow {
                            width: parent.width
                            spacing: 8
                            Repeater {
                                model: [
                                    { label: "1 min", secs: 60 },
                                    { label: "2 min", secs: 120 },
                                    { label: "3 min", secs: 180 },
                                    { label: "5 min", secs: 300 },
                                    { label: "10 min", secs: 600 },
                                    { label: "15 min", secs: 900 },
                                    { label: "Never", secs: 0 }
                                ]
                                delegate: ClickableRect {
                                    readonly property bool isSelected: root.screenOffBattery === modelData.secs
                                    width: bText.implicitWidth + 24
                                    height: 32
                                    radius: root.rad(8)
                                    color: isSelected ? Nexa.Theme.primary : (hovered ? Nexa.Theme.surfaceContainerHighest : Nexa.Theme.surfaceContainerHigh)
                                    border.width: Nexa.Theme.borderThin
                                    border.color: isSelected ? Nexa.Theme.primary : Nexa.Theme.border
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.screenOffBattery = modelData.secs;
                                        root.saveConfig();
                                    }

                                    StyledText {
                                        id: bText
                                        anchors.centerIn: parent
                                        text: modelData.label
                                        font.pixelSize: 12
                                        font.weight: isSelected ? Font.Bold : Font.Normal
                                        color: isSelected ? Nexa.Theme.onPrimary : Nexa.Theme.text
                                    }
                                }
                            }
                        }
                    }

                    // When Plugged In Chips
                    Column {
                        width: parent.width
                        spacing: 8

                        Row {
                            spacing: 6
                            Text { text: "󱐋"; font.family: Nexa.Theme.iconFontFamily; font.pixelSize: 13; color: Nexa.Theme.primary }
                            StyledText { text: "When plugged into power (AC):"; font.pixelSize: 12; font.weight: Font.Medium; color: Nexa.Theme.mutedText }
                        }

                        Flow {
                            width: parent.width
                            spacing: 8
                            Repeater {
                                model: [
                                    { label: "3 min", secs: 180 },
                                    { label: "5 min", secs: 300 },
                                    { label: "10 min", secs: 600 },
                                    { label: "15 min", secs: 900 },
                                    { label: "30 min", secs: 1800 },
                                    { label: "Never", secs: 0 }
                                ]
                                delegate: ClickableRect {
                                    readonly property bool isSelected: root.screenOffAc === modelData.secs
                                    width: acText.implicitWidth + 24
                                    height: 32
                                    radius: root.rad(8)
                                    color: isSelected ? Nexa.Theme.primary : (hovered ? Nexa.Theme.surfaceContainerHighest : Nexa.Theme.surfaceContainerHigh)
                                    border.width: Nexa.Theme.borderThin
                                    border.color: isSelected ? Nexa.Theme.primary : Nexa.Theme.border
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.screenOffAc = modelData.secs;
                                        root.saveConfig();
                                    }

                                    StyledText {
                                        id: acText
                                        anchors.centerIn: parent
                                        text: modelData.label
                                        font.pixelSize: 12
                                        font.weight: isSelected ? Font.Bold : Font.Normal
                                        color: isSelected ? Nexa.Theme.onPrimary : Nexa.Theme.text
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ────────────────────────────────────────────────────────
            // 3. SLEEP & SYSTEM SUSPEND
            // ────────────────────────────────────────────────────────
            Rectangle {
                width: parent.width
                implicitHeight: sleepCol.implicitHeight + 36
                radius: root.rad(14)
                color: Nexa.Theme.surfaceContainer
                border.width: Nexa.Theme.borderThin
                border.color: Nexa.Theme.border

                Column {
                    id: sleepCol
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 16

                    RowLayout {
                        width: parent.width
                        spacing: 10
                        Text {
                            text: "󰤄"
                            font.family: Nexa.Theme.iconFontFamily
                            font.pixelSize: 20
                            color: Nexa.Theme.primary
                        }
                        ColumnLayout {
                            spacing: 2
                            StyledText {
                                text: "Sleep & Suspend Device"
                                font.pixelSize: 15
                                font.weight: Font.Bold
                                color: Nexa.Theme.text
                            }
                            StyledText {
                                text: "Places device into low-power RAM suspend state after inactivity."
                                font.pixelSize: 12
                                color: Nexa.Theme.mutedText
                            }
                        }
                    }

                    // On Battery Sleep Chips
                    Column {
                        width: parent.width
                        spacing: 8

                        Row {
                            spacing: 6
                            Text { text: "󰁹"; font.family: Nexa.Theme.iconFontFamily; font.pixelSize: 13; color: Nexa.Theme.mutedText }
                            StyledText { text: "On battery, suspend after:"; font.pixelSize: 12; font.weight: Font.Medium; color: Nexa.Theme.mutedText }
                        }

                        Flow {
                            width: parent.width
                            spacing: 8
                            Repeater {
                                model: [
                                    { label: "5 min", secs: 300 },
                                    { label: "10 min", secs: 600 },
                                    { label: "15 min", secs: 900 },
                                    { label: "30 min", secs: 1800 },
                                    { label: "1 hour", secs: 3600 },
                                    { label: "Never", secs: 0 }
                                ]
                                delegate: ClickableRect {
                                    readonly property bool isSelected: root.sleepBattery === modelData.secs
                                    width: sbText.implicitWidth + 24
                                    height: 32
                                    radius: root.rad(8)
                                    color: isSelected ? Nexa.Theme.primary : (hovered ? Nexa.Theme.surfaceContainerHighest : Nexa.Theme.surfaceContainerHigh)
                                    border.width: Nexa.Theme.borderThin
                                    border.color: isSelected ? Nexa.Theme.primary : Nexa.Theme.border
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.sleepBattery = modelData.secs;
                                        root.saveConfig();
                                    }

                                    StyledText {
                                        id: sbText
                                        anchors.centerIn: parent
                                        text: modelData.label
                                        font.pixelSize: 12
                                        font.weight: isSelected ? Font.Bold : Font.Normal
                                        color: isSelected ? Nexa.Theme.onPrimary : Nexa.Theme.text
                                    }
                                }
                            }
                        }
                    }

                    // When Plugged In Sleep Chips
                    Column {
                        width: parent.width
                        spacing: 8

                        Row {
                            spacing: 6
                            Text { text: "󱐋"; font.family: Nexa.Theme.iconFontFamily; font.pixelSize: 13; color: Nexa.Theme.primary }
                            StyledText { text: "When plugged in, suspend after:"; font.pixelSize: 12; font.weight: Font.Medium; color: Nexa.Theme.mutedText }
                        }

                        Flow {
                            width: parent.width
                            spacing: 8
                            Repeater {
                                model: [
                                    { label: "15 min", secs: 900 },
                                    { label: "30 min", secs: 1800 },
                                    { label: "1 hour", secs: 3600 },
                                    { label: "2 hours", secs: 7200 },
                                    { label: "Never", secs: 0 }
                                ]
                                delegate: ClickableRect {
                                    readonly property bool isSelected: root.sleepAc === modelData.secs
                                    width: saText.implicitWidth + 24
                                    height: 32
                                    radius: root.rad(8)
                                    color: isSelected ? Nexa.Theme.primary : (hovered ? Nexa.Theme.surfaceContainerHighest : Nexa.Theme.surfaceContainerHigh)
                                    border.width: Nexa.Theme.borderThin
                                    border.color: isSelected ? Nexa.Theme.primary : Nexa.Theme.border
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.sleepAc = modelData.secs;
                                        root.saveConfig();
                                    }

                                    StyledText {
                                        id: saText
                                        anchors.centerIn: parent
                                        text: modelData.label
                                        font.pixelSize: 12
                                        font.weight: isSelected ? Font.Bold : Font.Normal
                                        color: isSelected ? Nexa.Theme.onPrimary : Nexa.Theme.text
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ────────────────────────────────────────────────────────
            // 4. SAFE MODE & BATTERY SAVER
            // ────────────────────────────────────────────────────────
            Rectangle {
                width: parent.width
                implicitHeight: safeCol.implicitHeight + 36
                radius: root.rad(14)
                color: Nexa.Theme.surfaceContainer
                border.width: Nexa.Theme.borderThin
                border.color: Nexa.Theme.border

                Column {
                    id: safeCol
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 16

                    RowLayout {
                        width: parent.width
                        spacing: 10

                        Text {
                            text: "󰂎"
                            font.family: Nexa.Theme.iconFontFamily
                            font.pixelSize: 20
                            color: Nexa.Theme.primary
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            StyledText {
                                text: "Safe Mode (Battery Saver)"
                                font.pixelSize: 15
                                font.weight: Font.Bold
                                color: Nexa.Theme.text
                            }
                            StyledText {
                                text: "Extends battery longevity by engaging conservative power policies under threshold."
                                font.pixelSize: 12
                                color: Nexa.Theme.mutedText
                            }
                        }

                        // Standardized NexaToggle
                        NexaUI.NexaToggle {
                            checked: root.batterySaverEnabled
                            onToggled: {
                                root.batterySaverEnabled = !root.batterySaverEnabled
                                root.saveConfig()
                            }
                        }
                    }

                    // Threshold selector chips
                    Column {
                        width: parent.width
                        spacing: 8
                        opacity: root.batterySaverEnabled ? 1.0 : 0.4
                        enabled: root.batterySaverEnabled

                        StyledText {
                            text: "Engage Safe Mode automatically when battery drops below:"
                            font.pixelSize: 12
                            font.weight: Font.Medium
                            color: Nexa.Theme.mutedText
                        }

                        Flow {
                            width: parent.width
                            spacing: 8
                            Repeater {
                                model: [
                                    { label: "10% Battery", pct: 10 },
                                    { label: "15% Battery", pct: 15 },
                                    { label: "20% Battery", pct: 20 },
                                    { label: "25% Battery", pct: 25 },
                                    { label: "30% Battery", pct: 30 }
                                ]
                                delegate: ClickableRect {
                                    readonly property bool isSelected: root.batterySaverThreshold === modelData.pct
                                    width: pctText.implicitWidth + 24
                                    height: 32
                                    radius: root.rad(8)
                                    color: isSelected ? Nexa.Theme.primary : (hovered ? Nexa.Theme.surfaceContainerHighest : Nexa.Theme.surfaceContainerHigh)
                                    border.width: Nexa.Theme.borderThin
                                    border.color: isSelected ? Nexa.Theme.primary : Nexa.Theme.border
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.batterySaverThreshold = modelData.pct;
                                        root.saveConfig();
                                    }

                                    StyledText {
                                        id: pctText
                                        anchors.centerIn: parent
                                        text: modelData.label
                                        font.pixelSize: 12
                                        font.weight: isSelected ? Font.Bold : Font.Normal
                                        color: isSelected ? Nexa.Theme.onPrimary : Nexa.Theme.text
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ────────────────────────────────────────────────────────
            // 5. INACTIVITY SCREEN LOCK
            // ────────────────────────────────────────────────────────
            Rectangle {
                width: parent.width
                implicitHeight: lockCol.implicitHeight + 36
                radius: root.rad(14)
                color: Nexa.Theme.surfaceContainer
                border.width: Nexa.Theme.borderThin
                border.color: Nexa.Theme.border

                Column {
                    id: lockCol
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 16

                    RowLayout {
                        width: parent.width
                        spacing: 10
                        Text {
                            text: "󰌾"
                            font.family: Nexa.Theme.iconFontFamily
                            font.pixelSize: 20
                            color: Nexa.Theme.primary
                        }
                        ColumnLayout {
                            spacing: 2
                            StyledText {
                                text: "Inactivity Screen Lock"
                                font.pixelSize: 15
                                font.weight: Font.Bold
                                color: Nexa.Theme.text
                            }
                            StyledText {
                                text: "Locks session and protects privacy after a period of idle inactivity."
                                font.pixelSize: 12
                                color: Nexa.Theme.mutedText
                            }
                        }
                    }

                    // Lock Battery Chips
                    Column {
                        width: parent.width
                        spacing: 8

                        Row {
                            spacing: 6
                            Text { text: "󰁹"; font.family: Nexa.Theme.iconFontFamily; font.pixelSize: 13; color: Nexa.Theme.mutedText }
                            StyledText { text: "On battery, lock after:"; font.pixelSize: 12; font.weight: Font.Medium; color: Nexa.Theme.mutedText }
                        }

                        Flow {
                            width: parent.width
                            spacing: 8
                            Repeater {
                                model: [
                                    { label: "1 min", secs: 60 },
                                    { label: "2 min", secs: 120 },
                                    { label: "3 min", secs: 180 },
                                    { label: "5 min", secs: 300 },
                                    { label: "10 min", secs: 600 },
                                    { label: "Never", secs: 0 }
                                ]
                                delegate: ClickableRect {
                                    readonly property bool isSelected: root.lockBattery === modelData.secs
                                    width: lbText.implicitWidth + 24
                                    height: 32
                                    radius: root.rad(8)
                                    color: isSelected ? Nexa.Theme.primary : (hovered ? Nexa.Theme.surfaceContainerHighest : Nexa.Theme.surfaceContainerHigh)
                                    border.width: Nexa.Theme.borderThin
                                    border.color: isSelected ? Nexa.Theme.primary : Nexa.Theme.border
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.lockBattery = modelData.secs;
                                        root.saveConfig();
                                    }

                                    StyledText {
                                        id: lbText
                                        anchors.centerIn: parent
                                        text: modelData.label
                                        font.pixelSize: 12
                                        font.weight: isSelected ? Font.Bold : Font.Normal
                                        color: isSelected ? Nexa.Theme.onPrimary : Nexa.Theme.text
                                    }
                                }
                            }
                        }
                    }

                    // Lock AC Chips
                    Column {
                        width: parent.width
                        spacing: 8

                        Row {
                            spacing: 6
                            Text { text: "󱐋"; font.family: Nexa.Theme.iconFontFamily; font.pixelSize: 13; color: Nexa.Theme.primary }
                            StyledText { text: "When plugged in, lock after:"; font.pixelSize: 12; font.weight: Font.Medium; color: Nexa.Theme.mutedText }
                        }

                        Flow {
                            width: parent.width
                            spacing: 8
                            Repeater {
                                model: [
                                    { label: "2 min", secs: 120 },
                                    { label: "5 min", secs: 300 },
                                    { label: "10 min", secs: 600 },
                                    { label: "15 min", secs: 900 },
                                    { label: "30 min", secs: 1800 },
                                    { label: "Never", secs: 0 }
                                ]
                                delegate: ClickableRect {
                                    readonly property bool isSelected: root.lockAc === modelData.secs
                                    width: laText.implicitWidth + 24
                                    height: 32
                                    radius: root.rad(8)
                                    color: isSelected ? Nexa.Theme.primary : (hovered ? Nexa.Theme.surfaceContainerHighest : Nexa.Theme.surfaceContainerHigh)
                                    border.width: Nexa.Theme.borderThin
                                    border.color: isSelected ? Nexa.Theme.primary : Nexa.Theme.border
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.lockAc = modelData.secs;
                                        root.saveConfig();
                                    }

                                    StyledText {
                                        id: laText
                                        anchors.centerIn: parent
                                        text: modelData.label
                                        font.pixelSize: 12
                                        font.weight: isSelected ? Font.Bold : Font.Normal
                                        color: isSelected ? Nexa.Theme.onPrimary : Nexa.Theme.text
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ────────────────────────────────────────────────────────────
    // FLOATING TOAST CONFIRMATION
    // ────────────────────────────────────────────────────────────
    Rectangle {
        id: toast
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 24
        anchors.horizontalCenter: parent.horizontalCenter
        width: toastTxt.implicitWidth + 32
        height: 36
        radius: root.rad(18)
        color: Nexa.Theme.surfaceContainerHighest
        border.width: Nexa.Theme.borderThin
        border.color: Nexa.Theme.primary
        opacity: root.toastVisible ? 1.0 : 0.0
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation { duration: 200 }
        }

        StyledText {
            id: toastTxt
            anchors.centerIn: parent
            text: root.toastMessage
            font.pixelSize: 12
            font.weight: Font.Medium
            color: Nexa.Theme.text
        }
    }
}
