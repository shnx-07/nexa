import QtQuick
import QtQuick.Layouts

import "../../theme" as Nexa
import "../../theme/components" as NexaUI


Item {
    id: root

    // ============================================================
    // RESPONSIBILITY
    //
    // Reusable Clock module:
    // - Page 0: Clock / Calendar
    // - Page 1: Stopwatch
    // - Page 2: Focus (Pomodoro / Deep Work)
    // ============================================================

    property string presentation: "full"

    // Full Clock module page:
    // 0 = Clock / Calendar
    // 1 = Stopwatch
    // 2 = Focus
    property int page: 0

    // ============================================================
    // CURRENT TIME
    // ============================================================

    property date currentTime: new Date()

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.currentTime = new Date()
    }

    // ============================================================
    // STOPWATCH STATE
    // ============================================================

    property bool stopwatchRunning: false
    property double stopwatchElapsed: 0
    property double stopwatchStartedAt: 0

    readonly property bool stopwatchActive:
        stopwatchRunning || stopwatchElapsed > 0

    Timer {
        id: stopwatchTimer
        interval: 50
        repeat: true
        running: root.stopwatchRunning
        onTriggered: {
            root.stopwatchElapsed = Date.now() - root.stopwatchStartedAt
        }
    }

    // ============================================================
    // STOPWATCH ACTIONS
    // ============================================================

    function toggleStopwatch() {
        if (stopwatchRunning) {
            stopwatchRunning = false
            return
        }
        stopwatchStartedAt = Date.now() - stopwatchElapsed
        stopwatchRunning = true
    }

    function restartStopwatch() {
        stopwatchElapsed = 0
        stopwatchStartedAt = Date.now()
        stopwatchRunning = true
    }

    function resetStopwatch() {
        stopwatchRunning = false
        stopwatchElapsed = 0
        stopwatchStartedAt = 0
    }

    function stopwatchText(ms) {
        const totalTenths = Math.floor(ms / 100)
        const tenths = totalTenths % 10
        const totalSeconds = Math.floor(totalTenths / 10)
        const seconds = totalSeconds % 60
        const totalMinutes = Math.floor(totalSeconds / 60)
        const minutes = totalMinutes % 60
        const hours = Math.floor(totalMinutes / 60)

        return (
            String(hours).padStart(2, "0")
            + ":"
            + String(minutes).padStart(2, "0")
            + ":"
            + String(seconds).padStart(2, "0")
            + "."
            + tenths
        )
    }

    // ============================================================
    // FOCUS / POMODORO STATE
    // ============================================================

    property bool focusRunning: false
    property int focusTotalSeconds: 1500 // 25 min default
    property int focusRemaining: 1500
    property string focusMode: "focus" // "focus", "short_break", "long_break"
    property int focusSessions: 0

    readonly property bool focusActive:
        focusRunning || (focusRemaining < focusTotalSeconds && focusRemaining > 0)

    readonly property real focusProgress:
        focusTotalSeconds > 0
        ? Math.max(0.0, Math.min(1.0, 1.0 - (focusRemaining / focusTotalSeconds)))
        : 0.0

    Timer {
        id: focusTimer
        interval: 1000
        repeat: true
        running: root.focusRunning

        onTriggered: {
            if (root.focusRemaining > 1) {
                root.focusRemaining -= 1
            } else {
                root.focusRemaining = 0
                root.focusRunning = false
                if (root.focusMode === "focus") {
                    root.focusSessions += 1
                }
                root.onFocusCompleted()
            }
        }
    }

    function toggleFocus() {
        if (focusRunning) {
            focusRunning = false
            return
        }
        if (focusRemaining <= 0) {
            focusRemaining = focusTotalSeconds
        }
        focusRunning = true
    }

    function resetFocus() {
        focusRunning = false
        focusRemaining = focusTotalSeconds
    }

    function setFocusPreset(seconds, mode) {
        focusRunning = false
        focusTotalSeconds = seconds
        focusRemaining = seconds
        focusMode = mode || "focus"
    }

    function addFocusTime(seconds) {
        focusRemaining += seconds
        focusTotalSeconds += seconds
    }

    function onFocusCompleted() {
        if (root.focusMode === "focus") {
            if (root.focusSessions % 4 === 0) {
                root.setFocusPreset(900, "long_break") // 15m
            } else {
                root.setFocusPreset(300, "short_break") // 5m
            }
        } else {
            root.setFocusPreset(1500, "focus") // 25m
        }
    }

    function focusText(sec) {
        const totalSec = Math.max(0, Math.floor(sec))
        const mins = Math.floor(totalSec / 60)
        const s = totalSec % 60
        return String(mins).padStart(2, "0") + ":" + String(s).padStart(2, "0")
    }

    // ============================================================
    // CALENDAR STATE
    // ============================================================

    property date calendarMonth:
        new Date(
            currentTime.getFullYear(),
            currentTime.getMonth(),
            1
        )

    readonly property var weekDays: [
        "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"
    ]

    function previousMonth() {
        calendarMonth = new Date(
            calendarMonth.getFullYear(),
            calendarMonth.getMonth() - 1,
            1
        )
    }

    function nextMonth() {
        calendarMonth = new Date(
            calendarMonth.getFullYear(),
            calendarMonth.getMonth() + 1,
            1
        )
    }

    function goCurrentMonth() {
        calendarMonth = new Date(
            currentTime.getFullYear(),
            currentTime.getMonth(),
            1
        )
    }

    function calendarDate(index) {
        const year = calendarMonth.getFullYear()
        const month = calendarMonth.getMonth()
        const firstDay = (new Date(year, month, 1).getDay() + 6) % 7
        return new Date(year, month, index - firstDay + 1)
    }

    function sameDay(a, b) {
        return (
            a.getFullYear() === b.getFullYear()
            && a.getMonth() === b.getMonth()
            && a.getDate() === b.getDate()
        )
    }

    // ============================================================
    // SOLAR / TIME-OF-DAY HELPERS
    // ============================================================

    readonly property int currentHour: currentTime.getHours()

    readonly property string solarPhase: {
        if (currentHour >= 5 && currentHour < 9) return "morning"
        if (currentHour >= 9 && currentHour < 17) return "afternoon"
        if (currentHour >= 17 && currentHour < 20) return "evening"
        return "night"
    }

    readonly property string solarGreeting: {
        switch (solarPhase) {
            case "morning": return "Good Morning"
            case "afternoon": return "Good Afternoon"
            case "evening": return "Good Evening"
            default: return "Good Night"
        }
    }

    readonly property string solarEmoji: {
        switch (solarPhase) {
            case "morning": return "🌅"
            case "afternoon": return "☀️"
            case "evening": return "🌆"
            default: return "🌙"
        }
    }

    readonly property string solarSubtitle: {
        switch (solarPhase) {
            case "morning": return "Sunrise"
            case "afternoon": return "Daytime"
            case "evening": return "Golden Hour"
            default: return "Nighttime"
        }
    }

    readonly property color solarColor: {
        switch (solarPhase) {
            case "morning": return "#F59E0B"
            case "afternoon": return "#EAB308"
            case "evening": return "#F97316"
            default: return "#818CF8"
        }
    }

    // ============================================================
    // COMPACT PRESENTATION
    // ============================================================

    Item {
        anchors.fill: parent
        visible: root.presentation === "compact"

        // 1. NORMAL CLOCK (when neither stopwatch nor focus is active)
        Text {
            anchors.centerIn: parent
            visible: !root.stopwatchActive && !root.focusActive
            text: Qt.formatDateTime(root.currentTime, "hh:mm AP")
            color: Nexa.Theme.text
            font.family: Nexa.Theme.fontFamily
            font.pixelSize: Nexa.Theme.fontSizeMd
            font.weight: Nexa.Theme.fontWeightDemiBold
        }

        // 2. STOPWATCH COMPACT (Priority 1)
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Nexa.Theme.spacingMd
            anchors.rightMargin: Nexa.Theme.spacingMd
            visible: root.stopwatchActive
            spacing: Nexa.Theme.spacingMd

            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignLeft
                text: Qt.formatDateTime(root.currentTime, "hh:mm AP")
                color: Nexa.Theme.text
                font.family: Nexa.Theme.fontFamily
                font.pixelSize: Nexa.Theme.fontSizeMd
                font.weight: Nexa.Theme.fontWeightDemiBold
            }

            Rectangle {
                Layout.preferredWidth: 1
                Layout.preferredHeight: 18
                color: Nexa.Theme.divider
            }

            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignRight
                text: root.stopwatchText(root.stopwatchElapsed)
                color: root.stopwatchRunning ? Nexa.Theme.primary : Nexa.Theme.text
                font.family: Nexa.Theme.monoFontFamily
                font.pixelSize: Nexa.Theme.fontSizeMd
                font.weight: Nexa.Theme.fontWeightDemiBold
            }
        }

        // 3. FOCUS COMPACT (Priority 2)
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Nexa.Theme.spacingMd
            anchors.rightMargin: Nexa.Theme.spacingMd
            visible: root.focusActive && !root.stopwatchActive
            spacing: Nexa.Theme.spacingMd

            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignLeft
                text: Qt.formatDateTime(root.currentTime, "hh:mm AP")
                color: Nexa.Theme.text
                font.family: Nexa.Theme.fontFamily
                font.pixelSize: Nexa.Theme.fontSizeMd
                font.weight: Nexa.Theme.fontWeightDemiBold
            }

            Rectangle {
                Layout.preferredWidth: 1
                Layout.preferredHeight: 18
                color: Nexa.Theme.divider
            }

            Row {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignRight
                spacing: 6

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.focusMode === "focus" ? "󰪠" : "󰛨"
                    color: root.focusRunning ? Nexa.Theme.primary : Nexa.Theme.mutedText
                    font.family: Nexa.Theme.iconFontFamily
                    font.pixelSize: Nexa.Theme.iconSm
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.focusText(root.focusRemaining)
                    color: root.focusRunning ? Nexa.Theme.primary : Nexa.Theme.text
                    font.family: Nexa.Theme.monoFontFamily
                    font.pixelSize: Nexa.Theme.fontSizeMd
                    font.weight: Nexa.Theme.fontWeightDemiBold
                }
            }
        }
    }

    // ============================================================
    // HOVER PRESENTATION
    // ============================================================

    Item {
        anchors.fill: parent
        visible: root.presentation === "hover"

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Nexa.Theme.spacingLg
            anchors.rightMargin: Nexa.Theme.spacingLg
            anchors.topMargin: Nexa.Theme.spacingSm
            anchors.bottomMargin: Nexa.Theme.spacingSm
            spacing: Nexa.Theme.spacingLg

            // Left: Clock & Date
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    text: Qt.formatDateTime(root.currentTime, "hh:mm:ss AP")
                    color: Nexa.Theme.text
                    font.family: Nexa.Theme.fontFamily
                    font.pixelSize: Nexa.Theme.fontSizeLg
                    font.weight: Nexa.Theme.fontWeightDemiBold
                }

                Text {
                    text: Qt.formatDateTime(root.currentTime, "dddd, MMMM d")
                    color: Nexa.Theme.mutedText
                    font.family: Nexa.Theme.fontFamily
                    font.pixelSize: Nexa.Theme.fontSizeXs
                }
            }

            // Divider
            Rectangle {
                Layout.preferredWidth: 1
                Layout.fillHeight: true
                Layout.topMargin: 4
                Layout.bottomMargin: 4
                color: Nexa.Theme.divider
            }

            // Right Option A: Stopwatch Hover Controls
            RowLayout {
                visible: root.stopwatchActive
                spacing: Nexa.Theme.spacingMd

                Text {
                    text: root.stopwatchText(root.stopwatchElapsed)
                    color: root.stopwatchRunning ? Nexa.Theme.primary : Nexa.Theme.text
                    font.family: Nexa.Theme.monoFontFamily
                    font.pixelSize: Nexa.Theme.fontSizeLg
                    font.weight: Nexa.Theme.fontWeightDemiBold
                }

                NexaUI.NexaButton {
                    implicitWidth: 88
                    implicitHeight: 32
                    icon: root.stopwatchRunning ? "󰏤" : "󰐊"
                    text: root.stopwatchRunning ? "Pause" : "Resume"
                    onClicked: root.toggleStopwatch()
                }

                NexaUI.NexaButton {
                    implicitWidth: 88
                    implicitHeight: 32
                    icon: "󰑐"
                    text: "Restart"
                    onClicked: root.restartStopwatch()
                }
            }

            // Right Option B: Focus Hover Controls
            RowLayout {
                visible: root.focusActive && !root.stopwatchActive
                spacing: Nexa.Theme.spacingMd

                Column {
                    spacing: 2
                    Row {
                        spacing: 4
                        Text {
                            text: root.focusMode === "focus" ? "󰪠 Focus" : "󰛨 Break"
                            color: Nexa.Theme.mutedText
                            font.family: Nexa.Theme.fontFamily
                            font.pixelSize: Nexa.Theme.fontSize2Xs
                        }
                        Text {
                            text: "• " + root.focusSessions + " done"
                            color: Nexa.Theme.mutedText
                            font.family: Nexa.Theme.fontFamily
                            font.pixelSize: Nexa.Theme.fontSize2Xs
                        }
                    }
                    Text {
                        text: root.focusText(root.focusRemaining)
                        color: root.focusRunning ? Nexa.Theme.primary : Nexa.Theme.text
                        font.family: Nexa.Theme.monoFontFamily
                        font.pixelSize: Nexa.Theme.fontSizeLg
                        font.weight: Nexa.Theme.fontWeightDemiBold
                    }
                }

                NexaUI.NexaButton {
                    implicitWidth: 88
                    implicitHeight: 32
                    icon: root.focusRunning ? "󰏤" : "󰐊"
                    text: root.focusRunning ? "Pause" : "Resume"
                    onClicked: root.toggleFocus()
                }

                NexaUI.NexaButton {
                    implicitWidth: 78
                    implicitHeight: 32
                    icon: "󰜉"
                    text: "Reset"
                    onClicked: root.resetFocus()
                }
            }

            // Right Option C: Day/Night Solar Greeting (Idle State)
            RowLayout {
                visible: !root.stopwatchActive && !root.focusActive
                spacing: Nexa.Theme.spacingMd

                Rectangle {
                    implicitWidth: 34
                    implicitHeight: 34
                    radius: 17
                    color: Qt.rgba(root.solarColor.r, root.solarColor.g, root.solarColor.b, 0.15)
                    border.width: 1
                    border.color: Qt.rgba(root.solarColor.r, root.solarColor.g, root.solarColor.b, 0.3)

                    Text {
                        anchors.centerIn: parent
                        text: root.solarEmoji
                        font.pixelSize: 18
                    }
                }

                ColumnLayout {
                    spacing: 1

                    Text {
                        text: root.solarGreeting
                        color: Nexa.Theme.text
                        font.family: Nexa.Theme.fontFamily
                        font.pixelSize: Nexa.Theme.fontSizeSm
                        font.weight: Nexa.Theme.fontWeightDemiBold
                    }

                    Text {
                        text: root.solarSubtitle
                        color: root.solarColor
                        font.family: Nexa.Theme.fontFamily
                        font.pixelSize: Nexa.Theme.fontSize2Xs
                        font.weight: Nexa.Theme.fontWeightMedium
                    }
                }
            }
        }
    }

    // ============================================================
    // FULL PRESENTATION
    // ============================================================

    ColumnLayout {
        anchors.fill: parent
        visible: root.presentation === "full"
        spacing: Nexa.Theme.spacingMd

        // 3-Tab Segmented Navigation
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredHeight: 34
            spacing: Nexa.Theme.spacingXs

            Repeater {
                model: [
                    { label: "Calendar", icon: "󰃰", page: 0 },
                    { label: "Stopwatch", icon: "󰄉", page: 1 },
                    { label: "Focus", icon: "󰪠", page: 2 }
                ]

                delegate: NexaUI.NexaButton {
                    id: pageButton
                    required property var modelData
                    implicitWidth: 120
                    implicitHeight: 32
                    icon: modelData.icon
                    text: modelData.label
                    selected: root.page === modelData.page
                    onClicked: root.page = modelData.page
                }
            }
        }

        // Full Page Content Area
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // ====================================================
            // PAGE 0: CLOCK / CALENDAR
            // ====================================================
            Item {
                anchors.fill: parent
                visible: root.page === 0

                RowLayout {
                    anchors.fill: parent
                    spacing: Nexa.Theme.spacingXl

                    // Clock side
                    Item {
                        Layout.preferredWidth: 220
                        Layout.fillHeight: true

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: Nexa.Theme.spacingXs

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: Qt.formatDateTime(root.currentTime, "hh:mm")
                                color: Nexa.Theme.text
                                font.family: Nexa.Theme.fontFamily
                                font.pixelSize: 38
                                font.weight: Nexa.Theme.fontWeightDemiBold
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: Qt.formatDateTime(root.currentTime, "AP")
                                color: Nexa.Theme.primary
                                font.family: Nexa.Theme.fontFamily
                                font.pixelSize: Nexa.Theme.fontSizeLg
                                font.weight: Nexa.Theme.fontWeightDemiBold
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: Qt.formatDateTime(root.currentTime, "dddd")
                                color: Nexa.Theme.text
                                font.family: Nexa.Theme.fontFamily
                                font.pixelSize: Nexa.Theme.fontSizeMd
                                font.weight: Nexa.Theme.fontWeightMedium
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: Qt.formatDateTime(root.currentTime, "d MMMM yyyy")
                                color: Nexa.Theme.mutedText
                                font.family: Nexa.Theme.fontFamily
                                font.pixelSize: Nexa.Theme.fontSizeSm
                            }
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 1
                        Layout.fillHeight: true
                        Layout.topMargin: Nexa.Theme.spacingSm
                        Layout.bottomMargin: Nexa.Theme.spacingSm
                        color: Nexa.Theme.divider
                    }

                    // Calendar side
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: Nexa.Theme.spacingSm

                        RowLayout {
                            Layout.fillWidth: true

                            NexaUI.NexaButton {
                                implicitWidth: 32
                                implicitHeight: 30
                                icon: "󰅁"
                                onClicked: root.previousMonth()
                            }

                            Text {
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                                text: Qt.formatDate(root.calendarMonth, "MMMM yyyy")
                                color: Nexa.Theme.text
                                font.family: Nexa.Theme.fontFamily
                                font.pixelSize: Nexa.Theme.fontSizeMd
                                font.weight: Nexa.Theme.fontWeightDemiBold
                            }

                            NexaUI.NexaButton {
                                implicitWidth: 76
                                implicitHeight: 30
                                text: "Today"
                                onClicked: root.goCurrentMonth()
                            }

                            NexaUI.NexaButton {
                                implicitWidth: 32
                                implicitHeight: 30
                                icon: "󰅂"
                                onClicked: root.nextMonth()
                            }
                        }

                        GridLayout {
                            Layout.fillWidth: true
                            columns: 7
                            columnSpacing: 4

                            Repeater {
                                model: root.weekDays
                                delegate: Text {
                                    required property string modelData
                                    Layout.fillWidth: true
                                    horizontalAlignment: Text.AlignHCenter
                                    text: modelData
                                    color: Nexa.Theme.mutedText
                                    font.family: Nexa.Theme.fontFamily
                                    font.pixelSize: Nexa.Theme.fontSizeXs
                                    font.weight: Nexa.Theme.fontWeightDemiBold
                                }
                            }
                        }

                        GridLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            columns: 7
                            columnSpacing: 4
                            rowSpacing: 4

                            Repeater {
                                model: 42
                                delegate: Rectangle {
                                    id: dayCell
                                    required property int index
                                    readonly property date cellDate: root.calendarDate(index)
                                    readonly property bool inMonth: cellDate.getMonth() === root.calendarMonth.getMonth()
                                    readonly property bool today: root.sameDay(cellDate, root.currentTime)

                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    radius: Nexa.Theme.radiusSm
                                    color: today ? Nexa.Theme.selected : "transparent"

                                    Text {
                                        anchors.centerIn: parent
                                        text: dayCell.cellDate.getDate()
                                        color: dayCell.today ? Nexa.Theme.selectedText : (dayCell.inMonth ? Nexa.Theme.text : Nexa.Theme.mutedText)
                                        opacity: dayCell.inMonth || dayCell.today ? 1.0 : Nexa.Theme.opacityDisabled
                                        font.family: Nexa.Theme.fontFamily
                                        font.pixelSize: Nexa.Theme.fontSizeSm
                                        font.weight: dayCell.today ? Nexa.Theme.fontWeightDemiBold : Nexa.Theme.fontWeightMedium
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ====================================================
            // PAGE 1: STOPWATCH
            // ====================================================
            Item {
                anchors.fill: parent
                visible: root.page === 1

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: Nexa.Theme.spacingXl

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: root.stopwatchText(root.stopwatchElapsed)
                        color: Nexa.Theme.text
                        font.family: Nexa.Theme.monoFontFamily
                        font.pixelSize: 40
                        font.weight: Nexa.Theme.fontWeightDemiBold
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: Nexa.Theme.spacingSm

                        NexaUI.NexaButton {
                            implicitWidth: 120
                            implicitHeight: 38
                            icon: root.stopwatchRunning ? "󰏤" : "󰐊"
                            text: root.stopwatchRunning ? "Pause" : (root.stopwatchElapsed > 0 ? "Resume" : "Start")
                            onClicked: root.toggleStopwatch()
                        }

                        NexaUI.NexaButton {
                            implicitWidth: 110
                            implicitHeight: 38
                            icon: "󰑐"
                            text: "Restart"
                            interactive: root.stopwatchActive
                            visible: root.stopwatchActive
                            onClicked: root.restartStopwatch()
                        }

                        NexaUI.NexaButton {
                            implicitWidth: 100
                            implicitHeight: 38
                            icon: "󰜉"
                            text: "Reset"
                            interactive: root.stopwatchActive
                            visible: root.stopwatchActive
                            onClicked: root.resetStopwatch()
                        }
                    }
                }
            }

            // ====================================================
            // PAGE 2: FOCUS MODE (POMODORO)
            // ====================================================
            Item {
                anchors.fill: parent
                visible: root.page === 2

                ColumnLayout {
                    anchors.fill: parent
                    spacing: Nexa.Theme.spacingMd

                    // Presets Row
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 8

                        NexaUI.NexaButton {
                            implicitWidth: 90
                            implicitHeight: 30
                            text: "15m Quick"
                            selected: root.focusTotalSeconds === 900 && root.focusMode === "focus"
                            onClicked: root.setFocusPreset(900, "focus")
                        }

                        NexaUI.NexaButton {
                            implicitWidth: 110
                            implicitHeight: 30
                            text: "25m Pomodoro"
                            selected: root.focusTotalSeconds === 1500 && root.focusMode === "focus"
                            onClicked: root.setFocusPreset(1500, "focus")
                        }

                        NexaUI.NexaButton {
                            implicitWidth: 110
                            implicitHeight: 30
                            text: "45m Deep Work"
                            selected: root.focusTotalSeconds === 2700 && root.focusMode === "focus"
                            onClicked: root.setFocusPreset(2700, "focus")
                        }

                        NexaUI.NexaButton {
                            implicitWidth: 80
                            implicitHeight: 30
                            text: "5m Break"
                            selected: root.focusTotalSeconds === 300 && root.focusMode === "short_break"
                            onClicked: root.setFocusPreset(300, "short_break")
                        }

                        NexaUI.NexaButton {
                            implicitWidth: 90
                            implicitHeight: 30
                            text: "15m Break"
                            selected: root.focusTotalSeconds === 900 && root.focusMode === "long_break"
                            onClicked: root.setFocusPreset(900, "long_break")
                        }
                    }

                    // Main Timer Display
                    ColumnLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 4

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: root.focusText(root.focusRemaining)
                            color: root.focusRunning ? Nexa.Theme.primary : Nexa.Theme.text
                            font.family: Nexa.Theme.monoFontFamily
                            font.pixelSize: 48
                            font.weight: Nexa.Theme.fontWeightBold
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: root.focusMode === "focus"
                                ? "󰪠 Focus Session"
                                : (root.focusMode === "short_break" ? "󰛨 Short Break" : "󰛨 Long Break")
                            color: Nexa.Theme.mutedText
                            font.family: Nexa.Theme.fontFamily
                            font.pixelSize: Nexa.Theme.fontSizeSm
                            font.weight: Nexa.Theme.fontWeightMedium
                        }
                    }

                    // Progress Bar
                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: 320
                        Layout.preferredHeight: 6
                        radius: 3
                        color: Nexa.Theme.surfaceContainerHighest

                        Rectangle {
                            height: parent.height
                            width: parent.width * (1.0 - root.focusProgress)
                            radius: 3
                            color: Nexa.Theme.primary

                            Behavior on width {
                                NumberAnimation { duration: 300 }
                            }
                        }
                    }

                    // Session Streak Dots
                    Row {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 8

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Cycles:"
                            color: Nexa.Theme.mutedText
                            font.family: Nexa.Theme.fontFamily
                            font.pixelSize: Nexa.Theme.fontSizeXs
                        }

                        Repeater {
                            model: 4
                            delegate: Rectangle {
                                width: 8
                                height: 8
                                radius: 4
                                color: index < (root.focusSessions % 4) || (root.focusSessions > 0 && root.focusSessions % 4 === 0)
                                    ? Nexa.Theme.primary
                                    : Nexa.Theme.surfaceContainerHighest
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "(" + root.focusSessions + " completed)"
                            color: Nexa.Theme.mutedText
                            font.family: Nexa.Theme.fontFamily
                            font.pixelSize: Nexa.Theme.fontSizeXs
                        }
                    }

                    // Focus Action Buttons
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: Nexa.Theme.spacingSm

                        NexaUI.NexaButton {
                            implicitWidth: 120
                            implicitHeight: 38
                            icon: root.focusRunning ? "󰏤" : "󰐊"
                            text: root.focusRunning ? "Pause" : (root.focusRemaining < root.focusTotalSeconds ? "Resume" : "Start")
                            onClicked: root.toggleFocus()
                        }

                        NexaUI.NexaButton {
                            implicitWidth: 90
                            implicitHeight: 38
                            icon: "󰐕"
                            text: "+5m"
                            interactive: true
                            onClicked: root.addFocusTime(300)
                        }

                        NexaUI.NexaButton {
                            implicitWidth: 90
                            implicitHeight: 38
                            icon: "󰜉"
                            text: "Reset"
                            interactive: root.focusActive
                            visible: root.focusActive
                            onClicked: root.resetFocus()
                        }
                    }
                }
            }
        }
    }
}
