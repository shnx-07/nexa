import QtQuick
import QtQuick.Layouts

import "../../NewNexaUI" as NexaUI

Item {
    id: root

    // ============================================================
    // RESPONSIBILITY
    //
    // Reusable Clock module styled with NewNexaUI:
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
    onVisibleChanged: if (visible) currentTime = new Date()

    Timer {
        interval: 1000
        running: root.visible
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
            case "morning": return NexaUI.NexaColors.warning
            case "afternoon": return NexaUI.NexaColors.tertiary
            case "evening": return NexaUI.NexaColors.secondary
            default: return NexaUI.NexaColors.primary
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
            color: NexaUI.NexaColors.text
            font.family: NexaUI.NexaTypography.familyBody
            font.pixelSize: NexaUI.NexaTypography.sizeMd
            font.weight: NexaUI.NexaTypography.weightSemiBold
            font.features: NexaUI.NexaTypography.fontFeaturesTnum
        }

        // 2. STOPWATCH COMPACT (Priority 1)
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: NexaUI.NexaTokens.spacingMd
            anchors.rightMargin: NexaUI.NexaTokens.spacingMd
            visible: root.stopwatchActive
            spacing: NexaUI.NexaTokens.spacingMd

            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignLeft
                text: Qt.formatDateTime(root.currentTime, "hh:mm AP")
                color: NexaUI.NexaColors.text
                font.family: NexaUI.NexaTypography.familyBody
                font.pixelSize: NexaUI.NexaTypography.sizeMd
                font.weight: NexaUI.NexaTypography.weightSemiBold
                font.features: NexaUI.NexaTypography.fontFeaturesTnum
            }

            Rectangle {
                Layout.preferredWidth: 1
                Layout.preferredHeight: 18
                color: NexaUI.NexaColors.borderSubtle
            }

            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignRight
                text: root.stopwatchText(root.stopwatchElapsed)
                color: root.stopwatchRunning ? NexaUI.NexaColors.primary : NexaUI.NexaColors.text
                font.family: NexaUI.NexaTypography.familyMono
                font.pixelSize: NexaUI.NexaTypography.sizeMd
                font.weight: NexaUI.NexaTypography.weightSemiBold
                font.features: NexaUI.NexaTypography.fontFeaturesTnum
            }
        }

        // 3. FOCUS COMPACT (Priority 2)
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: NexaUI.NexaTokens.spacingMd
            anchors.rightMargin: NexaUI.NexaTokens.spacingMd
            visible: root.focusActive && !root.stopwatchActive
            spacing: NexaUI.NexaTokens.spacingMd

            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignLeft
                text: Qt.formatDateTime(root.currentTime, "hh:mm AP")
                color: NexaUI.NexaColors.text
                font.family: NexaUI.NexaTypography.familyBody
                font.pixelSize: NexaUI.NexaTypography.sizeMd
                font.weight: NexaUI.NexaTypography.weightSemiBold
                font.features: NexaUI.NexaTypography.fontFeaturesTnum
            }

            Rectangle {
                Layout.preferredWidth: 1
                Layout.preferredHeight: 18
                color: NexaUI.NexaColors.borderSubtle
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignRight
                spacing: 6

                Item {
                    Layout.fillWidth: true
                }

                Text {
                    Layout.alignment: Qt.AlignVCenter
                    text: root.focusMode === "focus" ? "󰪠" : "󰛨"
                    color: root.focusRunning ? NexaUI.NexaColors.primary : NexaUI.NexaColors.mutedText
                    font.family: NexaUI.NexaTypography.familyIcon
                    font.pixelSize: NexaUI.NexaTypography.sizeSm
                }

                Text {
                    Layout.alignment: Qt.AlignVCenter
                    text: root.focusText(root.focusRemaining)
                    color: root.focusRunning ? NexaUI.NexaColors.primary : NexaUI.NexaColors.text
                    font.family: NexaUI.NexaTypography.familyMono
                    font.pixelSize: NexaUI.NexaTypography.sizeMd
                    font.weight: NexaUI.NexaTypography.weightSemiBold
                    font.features: NexaUI.NexaTypography.fontFeaturesTnum
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
            anchors.leftMargin: NexaUI.NexaTokens.spacingLg
            anchors.rightMargin: NexaUI.NexaTokens.spacingLg
            anchors.topMargin: NexaUI.NexaTokens.spacingSm
            anchors.bottomMargin: NexaUI.NexaTokens.spacingSm
            spacing: NexaUI.NexaTokens.spacingLg

            // Left: Clock & Date
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    text: Qt.formatDateTime(root.currentTime, "hh:mm:ss AP")
                    color: NexaUI.NexaColors.text
                    font.family: NexaUI.NexaTypography.familyDisplay
                    font.pixelSize: NexaUI.NexaTypography.sizeLg
                    font.weight: NexaUI.NexaTypography.weightSemiBold
                    font.features: NexaUI.NexaTypography.fontFeaturesTnum
                }

                Text {
                    text: Qt.formatDateTime(root.currentTime, "dddd, MMMM d")
                    color: NexaUI.NexaColors.mutedText
                    font.family: NexaUI.NexaTypography.familyBody
                    font.pixelSize: NexaUI.NexaTypography.sizeXs
                }
            }

            // Divider
            Rectangle {
                Layout.preferredWidth: 1
                Layout.fillHeight: true
                Layout.topMargin: 4
                Layout.bottomMargin: 4
                color: NexaUI.NexaColors.borderSubtle
            }

            // Right Option A: Stopwatch Hover Controls
            RowLayout {
                visible: root.stopwatchActive
                spacing: NexaUI.NexaTokens.spacingMd

                Text {
                    text: root.stopwatchText(root.stopwatchElapsed)
                    color: root.stopwatchRunning ? NexaUI.NexaColors.primary : NexaUI.NexaColors.text
                    font.family: NexaUI.NexaTypography.familyMono
                    font.pixelSize: NexaUI.NexaTypography.sizeLg
                    font.weight: NexaUI.NexaTypography.weightSemiBold
                    font.features: NexaUI.NexaTypography.fontFeaturesTnum
                }

                NexaUI.NexaButton {
                    implicitWidth: 84
                    implicitHeight: 32
                    variant: root.stopwatchRunning ? "filled" : "tonal"
                    icon: root.stopwatchRunning ? "󰏤" : "󰐊"
                    text: root.stopwatchRunning ? "Pause" : "Resume"
                    onClicked: root.toggleStopwatch()
                }

                NexaUI.NexaButton {
                    implicitWidth: 84
                    implicitHeight: 32
                    variant: "tonal"
                    icon: "󰑐"
                    text: "Restart"
                    onClicked: root.restartStopwatch()
                }
            }

            // Right Option B: Focus Hover Controls
            RowLayout {
                visible: root.focusActive && !root.stopwatchActive
                spacing: NexaUI.NexaTokens.spacingMd

                Column {
                    spacing: 2
                    Row {
                        spacing: 6
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.focusMode === "focus" ? "󰪠" : "󰛨"
                            color: NexaUI.NexaColors.primary
                            font.family: NexaUI.NexaTypography.familyIcon
                            font.pixelSize: NexaUI.NexaTypography.sizeSm
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: (root.focusMode === "focus" ? "Focus" : "Break") + " • " + root.focusSessions + " done"
                            color: NexaUI.NexaColors.mutedText
                            font.family: NexaUI.NexaTypography.familyBody
                            font.pixelSize: NexaUI.NexaTypography.size2Xs
                        }
                    }
                    Text {
                        text: root.focusText(root.focusRemaining)
                        color: root.focusRunning ? NexaUI.NexaColors.primary : NexaUI.NexaColors.text
                        font.family: NexaUI.NexaTypography.familyMono
                        font.pixelSize: NexaUI.NexaTypography.sizeLg
                        font.weight: NexaUI.NexaTypography.weightSemiBold
                        font.features: NexaUI.NexaTypography.fontFeaturesTnum
                    }
                }

                NexaUI.NexaButton {
                    implicitWidth: 84
                    implicitHeight: 32
                    variant: root.focusRunning ? "filled" : "tonal"
                    icon: root.focusRunning ? "󰏤" : "󰐊"
                    text: root.focusRunning ? "Pause" : "Resume"
                    onClicked: root.toggleFocus()
                }

                NexaUI.NexaButton {
                    implicitWidth: 80
                    implicitHeight: 32
                    variant: "tonal"
                    icon: "󰜉"
                    text: "Reset"
                    onClicked: root.resetFocus()
                }
            }

            // Right Option C: Day/Night Solar Greeting (Idle State)
            RowLayout {
                visible: !root.stopwatchActive && !root.focusActive
                spacing: NexaUI.NexaTokens.spacingMd

                Rectangle {
                    implicitWidth: 36
                    implicitHeight: 36
                    radius: NexaUI.NexaTokens.radiusSm
                    color: NexaUI.NexaColors.alpha(root.solarColor, 0.15)
                    border.width: NexaUI.NexaTokens.borderThin
                    border.color: NexaUI.NexaColors.alpha(root.solarColor, 0.35)

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
                        color: NexaUI.NexaColors.text
                        font.family: NexaUI.NexaTypography.familyDisplay
                        font.pixelSize: NexaUI.NexaTypography.sizeSm
                        font.weight: NexaUI.NexaTypography.weightSemiBold
                    }

                    Text {
                        text: root.solarSubtitle
                        color: root.solarColor
                        font.family: NexaUI.NexaTypography.familyBody
                        font.pixelSize: NexaUI.NexaTypography.size2Xs
                        font.weight: NexaUI.NexaTypography.weightMedium
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
        spacing: NexaUI.NexaTokens.spacingMd

        // 3-Tab Segmented Navigation
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredHeight: 34
            spacing: NexaUI.NexaTokens.spacingSm

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
                    variant: root.page === modelData.page ? "filled" : "tonal"
                    icon: modelData.icon
                    text: modelData.label
                    checked: root.page === modelData.page
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
                    spacing: NexaUI.NexaTokens.spacingXl

                    // Clock side
                    Item {
                        Layout.preferredWidth: 220
                        Layout.fillHeight: true

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: NexaUI.NexaTokens.spacingXs

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: Qt.formatDateTime(root.currentTime, "hh:mm")
                                color: NexaUI.NexaColors.text
                                font.family: NexaUI.NexaTypography.familyDisplay
                                font.pixelSize: 42
                                font.weight: NexaUI.NexaTypography.weightBold
                                font.features: NexaUI.NexaTypography.fontFeaturesTnum
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: Qt.formatDateTime(root.currentTime, "AP")
                                color: NexaUI.NexaColors.primary
                                font.family: NexaUI.NexaTypography.familyDisplay
                                font.pixelSize: NexaUI.NexaTypography.sizeLg
                                font.weight: NexaUI.NexaTypography.weightSemiBold
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: Qt.formatDateTime(root.currentTime, "dddd")
                                color: NexaUI.NexaColors.text
                                font.family: NexaUI.NexaTypography.familyBody
                                font.pixelSize: NexaUI.NexaTypography.sizeMd
                                font.weight: NexaUI.NexaTypography.weightMedium
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: Qt.formatDateTime(root.currentTime, "d MMMM yyyy")
                                color: NexaUI.NexaColors.mutedText
                                font.family: NexaUI.NexaTypography.familyBody
                                font.pixelSize: NexaUI.NexaTypography.sizeSm
                            }
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 1
                        Layout.fillHeight: true
                        Layout.topMargin: NexaUI.NexaTokens.spacingSm
                        Layout.bottomMargin: NexaUI.NexaTokens.spacingSm
                        color: NexaUI.NexaColors.borderSubtle
                    }

                    // Calendar side
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: NexaUI.NexaTokens.spacingSm

                        RowLayout {
                            Layout.fillWidth: true

                            NexaUI.NexaButton {
                                implicitWidth: 32
                                implicitHeight: 30
                                variant: "tonal"
                                icon: "󰅁"
                                onClicked: root.previousMonth()
                            }

                            Text {
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                                text: Qt.formatDate(root.calendarMonth, "MMMM yyyy")
                                color: NexaUI.NexaColors.text
                                font.family: NexaUI.NexaTypography.familyDisplay
                                font.pixelSize: NexaUI.NexaTypography.sizeMd
                                font.weight: NexaUI.NexaTypography.weightSemiBold
                            }

                            NexaUI.NexaButton {
                                implicitWidth: 76
                                implicitHeight: 30
                                variant: "tonal"
                                text: "Today"
                                onClicked: root.goCurrentMonth()
                            }

                            NexaUI.NexaButton {
                                implicitWidth: 32
                                implicitHeight: 30
                                variant: "tonal"
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
                                    color: NexaUI.NexaColors.mutedText
                                    font.family: NexaUI.NexaTypography.familyBody
                                    font.pixelSize: NexaUI.NexaTypography.sizeXs
                                    font.weight: NexaUI.NexaTypography.weightSemiBold
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
                                    radius: NexaUI.NexaTokens.radiusSm
                                    color: today
                                           ? NexaUI.NexaColors.primary
                                           : (dayMouse.containsMouse && inMonth ? NexaUI.NexaColors.surfaceContainerHigh : "transparent")

                                    Behavior on color {
                                        ColorAnimation { duration: NexaUI.NexaMotion.durationInstant }
                                    }

                                    // Subtle specular line on today cell
                                    Rectangle {
                                        anchors.top: parent.top
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        height: 1
                                        radius: parent.radius
                                        color: Qt.rgba(1, 1, 1, 0.25 * NexaUI.NexaOptics.specularIntensity)
                                        visible: dayCell.today && NexaUI.NexaOptics.specularHighlight
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: dayCell.cellDate.getDate()
                                        color: dayCell.today
                                               ? NexaUI.NexaColors.onPrimary
                                               : (dayCell.inMonth ? NexaUI.NexaColors.text : NexaUI.NexaColors.alpha(NexaUI.NexaColors.onSurface, 0.35))
                                        font.family: NexaUI.NexaTypography.familyBody
                                        font.pixelSize: NexaUI.NexaTypography.sizeSm
                                        font.weight: dayCell.today ? NexaUI.NexaTypography.weightSemiBold : NexaUI.NexaTypography.weightRegular
                                    }

                                    MouseArea {
                                        id: dayMouse
                                        anchors.fill: parent
                                        hoverEnabled: dayCell.inMonth
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
                    spacing: NexaUI.NexaTokens.spacingXl

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: root.stopwatchText(root.stopwatchElapsed)
                        color: root.stopwatchRunning ? NexaUI.NexaColors.primary : NexaUI.NexaColors.text
                        font.family: NexaUI.NexaTypography.familyMono
                        font.pixelSize: 44
                        font.weight: NexaUI.NexaTypography.weightBold
                        font.features: NexaUI.NexaTypography.fontFeaturesTnum
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: NexaUI.NexaTokens.spacingSm

                        NexaUI.NexaButton {
                            implicitWidth: 120
                            implicitHeight: 38
                            variant: root.stopwatchRunning ? "filled" : "tonal"
                            icon: root.stopwatchRunning ? "󰏤" : "󰐊"
                            text: root.stopwatchRunning ? "Pause" : (root.stopwatchElapsed > 0 ? "Resume" : "Start")
                            onClicked: root.toggleStopwatch()
                        }

                        NexaUI.NexaButton {
                            implicitWidth: 110
                            implicitHeight: 38
                            variant: "tonal"
                            icon: "󰑐"
                            text: "Restart"
                            enabled: root.stopwatchActive
                            visible: root.stopwatchActive
                            onClicked: root.restartStopwatch()
                        }

                        NexaUI.NexaButton {
                            implicitWidth: 100
                            implicitHeight: 38
                            variant: "tonal"
                            icon: "󰜉"
                            text: "Reset"
                            enabled: root.stopwatchActive
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
                    spacing: NexaUI.NexaTokens.spacingMd

                    // Presets Row
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: NexaUI.NexaTokens.spacingSm

                        NexaUI.NexaButton {
                            implicitWidth: 96
                            implicitHeight: 30
                            variant: "pill"
                            text: "15m Quick"
                            checked: root.focusTotalSeconds === 900 && root.focusMode === "focus"
                            onClicked: root.setFocusPreset(900, "focus")
                        }

                        NexaUI.NexaButton {
                            implicitWidth: 118
                            implicitHeight: 30
                            variant: "pill"
                            text: "25m Pomodoro"
                            checked: root.focusTotalSeconds === 1500 && root.focusMode === "focus"
                            onClicked: root.setFocusPreset(1500, "focus")
                        }

                        NexaUI.NexaButton {
                            implicitWidth: 120
                            implicitHeight: 30
                            variant: "pill"
                            text: "45m Deep Work"
                            checked: root.focusTotalSeconds === 2700 && root.focusMode === "focus"
                            onClicked: root.setFocusPreset(2700, "focus")
                        }

                        NexaUI.NexaButton {
                            implicitWidth: 88
                            implicitHeight: 30
                            variant: "pill"
                            text: "5m Break"
                            checked: root.focusTotalSeconds === 300 && root.focusMode === "short_break"
                            onClicked: root.setFocusPreset(300, "short_break")
                        }

                        NexaUI.NexaButton {
                            implicitWidth: 96
                            implicitHeight: 30
                            variant: "pill"
                            text: "15m Break"
                            checked: root.focusTotalSeconds === 900 && root.focusMode === "long_break"
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
                            color: root.focusRunning ? NexaUI.NexaColors.primary : NexaUI.NexaColors.text
                            font.family: NexaUI.NexaTypography.familyMono
                            font.pixelSize: 48
                            font.weight: NexaUI.NexaTypography.weightBold
                            font.features: NexaUI.NexaTypography.fontFeaturesTnum
                        }

                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 8

                            Text {
                                text: root.focusMode === "focus" ? "󰪠" : "󰛨"
                                color: NexaUI.NexaColors.primary
                                font.family: NexaUI.NexaTypography.familyIcon
                                font.pixelSize: NexaUI.NexaTypography.sizeSm
                            }

                            Text {
                                text: root.focusMode === "focus"
                                    ? "Focus Session"
                                    : (root.focusMode === "short_break" ? "Short Break" : "Long Break")
                                color: NexaUI.NexaColors.mutedText
                                font.family: NexaUI.NexaTypography.familyBody
                                font.pixelSize: NexaUI.NexaTypography.sizeSm
                                font.weight: NexaUI.NexaTypography.weightMedium
                            }
                        }
                    }

                    // Progress Bar
                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: 320
                        Layout.preferredHeight: 6
                        radius: NexaUI.NexaTokens.radiusPill
                        color: NexaUI.NexaColors.surfaceContainerHighest

                        Rectangle {
                            height: parent.height
                            width: parent.width * (1.0 - root.focusProgress)
                            radius: NexaUI.NexaTokens.radiusPill
                            color: NexaUI.NexaColors.primary

                            Behavior on width {
                                NumberAnimation { duration: NexaUI.NexaMotion.durationNormal }
                            }
                        }
                    }

                    // Session Streak Dots
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 8

                        Text {
                            Layout.alignment: Qt.AlignVCenter
                            text: "Cycles:"
                            color: NexaUI.NexaColors.mutedText
                            font.family: NexaUI.NexaTypography.familyBody
                            font.pixelSize: NexaUI.NexaTypography.sizeXs
                        }

                        Repeater {
                            model: 4
                            delegate: Rectangle {
                                Layout.alignment: Qt.AlignVCenter
                                width: 8
                                height: 8
                                radius: 4
                                color: index < (root.focusSessions % 4) || (root.focusSessions > 0 && root.focusSessions % 4 === 0)
                                    ? NexaUI.NexaColors.primary
                                    : NexaUI.NexaColors.surfaceContainerHighest
                            }
                        }

                        Text {
                            Layout.alignment: Qt.AlignVCenter
                            text: "(" + root.focusSessions + " completed)"
                            color: NexaUI.NexaColors.mutedText
                            font.family: NexaUI.NexaTypography.familyBody
                            font.pixelSize: NexaUI.NexaTypography.sizeXs
                        }
                    }

                    // Focus Action Buttons
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: NexaUI.NexaTokens.spacingSm

                        NexaUI.NexaButton {
                            implicitWidth: 120
                            implicitHeight: 38
                            variant: root.focusRunning ? "filled" : "tonal"
                            icon: root.focusRunning ? "󰏤" : "󰐊"
                            text: root.focusRunning ? "Pause" : (root.focusRemaining < root.focusTotalSeconds ? "Resume" : "Start")
                            onClicked: root.toggleFocus()
                        }

                        NexaUI.NexaButton {
                            implicitWidth: 90
                            implicitHeight: 38
                            variant: "tonal"
                            icon: "󰐕"
                            text: "+5m"
                            onClicked: root.addFocusTime(300)
                        }

                        NexaUI.NexaButton {
                            implicitWidth: 90
                            implicitHeight: 38
                            variant: "tonal"
                            icon: "󰜉"
                            text: "Reset"
                            enabled: root.focusActive
                            visible: root.focusActive
                            onClicked: root.resetFocus()
                        }
                    }
                }
            }
        }
    }
}
