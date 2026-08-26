import QtQuick
import QtQuick.Layouts

import "../../theme" as Nexa
import "../../theme/components" as NexaUI


Item {
    id: root


    // ============================================================
    // RESPONSIBILITY
    //
    // Reusable Clock module.
    //
    // presentation:
    //
    // compact
    //     Normal Island:
    //         centered current time
    //
    //     Stopwatch active:
    //         clock | stopwatch
    //
    // hover
    //     Current clock/date on left
    //     Stopwatch + controls on right when active
    //
    // full
    //     Clock/Calendar page
    //     Stopwatch page
    //
    // Stopwatch state intentionally lives HERE.
    //
    // IslandContent keeps this same Clock instance alive, so
    // closing/reopening the Island does not reset the stopwatch.
    // ============================================================


    property string presentation: "full"

    // Full Clock module page:
    // 0 = Clock / Calendar
    // 1 = Stopwatch
    property int page: 0


    // ============================================================
    // CURRENT TIME
    // ============================================================

    property date currentTime: new Date()


    Timer {
        interval: 1000
        running: true
        repeat: true

        onTriggered:
            root.currentTime = new Date()
    }


    // ============================================================
    // STOPWATCH STATE
    // ============================================================

    property bool stopwatchRunning: false

    property double stopwatchElapsed: 0
    property double stopwatchStartedAt: 0


    readonly property bool stopwatchActive:
        stopwatchRunning
        || stopwatchElapsed > 0


    Timer {
        id: stopwatchTimer

        interval: 50
        repeat: true

        running:
            root.stopwatchRunning


        onTriggered: {
            root.stopwatchElapsed =
                Date.now()
                - root.stopwatchStartedAt
        }
    }


    // ============================================================
    // STOPWATCH ACTIONS
    // ============================================================

    function toggleStopwatch() {

        // PAUSE
        if (stopwatchRunning) {
            stopwatchRunning = false
            return
        }

        // START / RESUME
        stopwatchStartedAt =
            Date.now() - stopwatchElapsed

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

        const totalTenths =
            Math.floor(ms / 100)

        const tenths =
            totalTenths % 10


        const totalSeconds =
            Math.floor(totalTenths / 10)

        const seconds =
            totalSeconds % 60


        const totalMinutes =
            Math.floor(totalSeconds / 60)

        const minutes =
            totalMinutes % 60


        const hours =
            Math.floor(totalMinutes / 60)


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
    // CALENDAR STATE
    // ============================================================

    property date calendarMonth:
        new Date(
            currentTime.getFullYear(),
            currentTime.getMonth(),
            1
        )


    readonly property var weekDays: [
        "Mon",
        "Tue",
        "Wed",
        "Thu",
        "Fri",
        "Sat",
        "Sun"
    ]


    function previousMonth() {

        calendarMonth =
            new Date(
                calendarMonth.getFullYear(),
                calendarMonth.getMonth() - 1,
                1
            )
    }


    function nextMonth() {

        calendarMonth =
            new Date(
                calendarMonth.getFullYear(),
                calendarMonth.getMonth() + 1,
                1
            )
    }


    function goCurrentMonth() {

        const now = new Date()

        calendarMonth =
            new Date(
                now.getFullYear(),
                now.getMonth(),
                1
            )
    }


    function calendarDate(index) {

        const year =
            calendarMonth.getFullYear()

        const month =
            calendarMonth.getMonth()


        // JavaScript:
        // Sunday = 0
        //
        // NEXA:
        // Monday = 0
        const firstDay =
            (
                new Date(
                    year,
                    month,
                    1
                ).getDay()
                + 6
            ) % 7


        return new Date(
            year,
            month,
            index - firstDay + 1
        )
    }


    function sameDay(a, b) {

        return (
            a.getFullYear()
                === b.getFullYear()

            && a.getMonth()
                === b.getMonth()

            && a.getDate()
                === b.getDate()
        )
    }


    // ============================================================
    // COMPACT PRESENTATION
    // ============================================================

    Item {
        anchors.fill: parent

        visible:
            root.presentation === "compact"


        // --------------------------------------------------------
        // NORMAL COMPACT
        //
        // IMPORTANT:
        // Truly centered in the Dynamic Island.
        // --------------------------------------------------------

        Text {
            anchors.centerIn: parent

            visible:
                !root.stopwatchActive

            text:
                Qt.formatDateTime(
                    root.currentTime,
                    "hh:mm AP"
                )

            color:
                Nexa.Theme.text

            font {
                family:
                    Nexa.Theme.fontFamily

                pixelSize:
                    Nexa.Theme.fontSizeMd

                weight:
                    Nexa.Theme.fontWeightDemiBold
            }
        }


        // --------------------------------------------------------
        // STOPWATCH PERSISTENT COMPACT
        //
        // Clock on one side.
        // Stopwatch on the other.
        // --------------------------------------------------------

        RowLayout {
            anchors {
                fill: parent

                leftMargin:
                    Nexa.Theme.spacingMd

                rightMargin:
                    Nexa.Theme.spacingMd
            }


            visible:
                root.stopwatchActive


            spacing:
                Nexa.Theme.spacingMd


            Text {
                Layout.fillWidth: true

                horizontalAlignment:
                    Text.AlignLeft

                text:
                    Qt.formatDateTime(
                        root.currentTime,
                        "hh:mm AP"
                    )

                color:
                    Nexa.Theme.text

                font {
                    family:
                        Nexa.Theme.fontFamily

                    pixelSize:
                        Nexa.Theme.fontSizeMd

                    weight:
                        Nexa.Theme.fontWeightDemiBold
                }
            }


            Rectangle {
                Layout.preferredWidth: 1
                Layout.preferredHeight: 18

                color:
                    Nexa.Theme.divider
            }


            Text {
                Layout.fillWidth: true

                horizontalAlignment:
                    Text.AlignRight

                text:
                    root.stopwatchText(
                        root.stopwatchElapsed
                    )

                color:
                    root.stopwatchRunning
                    ? Nexa.Theme.primary
                    : Nexa.Theme.text

                font {
                    family:
                        Nexa.Theme.monoFontFamily

                    pixelSize:
                        Nexa.Theme.fontSizeMd

                    weight:
                        Nexa.Theme.fontWeightDemiBold
                }
            }
        }
    }


    // ============================================================
    // HOVER PRESENTATION
    // ============================================================

    Item {
        anchors.fill: parent

        visible:
            root.presentation === "hover"


        RowLayout {
            anchors {
                fill: parent

                leftMargin:
                    Nexa.Theme.spacingLg

                rightMargin:
                    Nexa.Theme.spacingLg

                topMargin:
                    Nexa.Theme.spacingSm

                bottomMargin:
                    Nexa.Theme.spacingSm
            }


            spacing:
                Nexa.Theme.spacingLg


            // ====================================================
            // CLOCK SIDE
            // ====================================================

            ColumnLayout {
                Layout.fillWidth: true

                spacing:
                    Nexa.Theme.spacing2Xs


                Text {
                    text:
                        Qt.formatDateTime(
                            root.currentTime,
                            "hh:mm AP"
                        )

                    color:
                        Nexa.Theme.text

                    font {
                        family:
                            Nexa.Theme.fontFamily

                        pixelSize:
                            Nexa.Theme.fontSizeLg

                        weight:
                            Nexa.Theme.fontWeightDemiBold
                    }
                }


                Text {
                    text:
                        Qt.formatDateTime(
                            root.currentTime,
                            "dddd, d MMMM"
                        )

                    color:
                        Nexa.Theme.mutedText

                    font {
                        family:
                            Nexa.Theme.fontFamily

                        pixelSize:
                            Nexa.Theme.fontSizeSm

                        weight:
                            Nexa.Theme.fontWeightMedium
                    }
                }
            }


            // ====================================================
            // STOPWATCH SIDE
            // ====================================================

            Rectangle {
                visible:
                    root.stopwatchActive

                Layout.preferredWidth: 1
                Layout.fillHeight: true

                Layout.topMargin: 12
                Layout.bottomMargin: 12

                color:
                    Nexa.Theme.divider
            }


            ColumnLayout {
                visible:
                    root.stopwatchActive

                spacing:
                    Nexa.Theme.spacingSm


                Text {
                    Layout.alignment:
                        Qt.AlignHCenter

                    text:
                        root.stopwatchText(
                            root.stopwatchElapsed
                        )

                    color:
                        root.stopwatchRunning
                        ? Nexa.Theme.primary
                        : Nexa.Theme.text

                    font {
                        family:
                            Nexa.Theme.monoFontFamily

                        pixelSize:
                            Nexa.Theme.fontSizeLg

                        weight:
                            Nexa.Theme.fontWeightDemiBold
                    }
                }


                RowLayout {
                    spacing:
                        Nexa.Theme.spacingXs


                    // ============================================
                    // PAUSE / RESUME
                    // ============================================

                    NexaUI.NexaButton {
                        id: hoverToggleButton
                        implicitWidth: 92
                        implicitHeight: 32
                        icon: root.stopwatchRunning ? "󰏤" : "󰐊"
                        text: root.stopwatchRunning ? "Pause" : "Resume"
                        onClicked: root.toggleStopwatch()
                    }


                    // ============================================
                    // RESTART
                    // ============================================

                    NexaUI.NexaButton {
                        id: hoverRestartButton
                        implicitWidth: 96
                        implicitHeight: 32
                        icon: "󰑐"
                        text: "Restart"
                        onClicked: root.restartStopwatch()
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

        visible:
            root.presentation === "full"

        spacing:
            Nexa.Theme.spacingMd


        // ========================================================
        // INTERNAL CLOCK NAVIGATION
        //
        // This is BELOW the main Island navigation because
        // IslandContent.qml supplies the correct top margin.
        // ========================================================

        RowLayout {
            Layout.alignment:
                Qt.AlignHCenter

            Layout.preferredHeight: 34

            spacing:
                Nexa.Theme.spacingXs


            Repeater {
                model: [
                    {
                        label: "Clock",
                        page: 0
                    },
                    {
                        label: "Stopwatch",
                        page: 1
                    }
                ]


                delegate: NexaUI.NexaButton {
                    id: pageButton
                    required property var modelData
                    implicitWidth: 118
                    implicitHeight: 32
                    text: modelData.label
                    selected: root.page === modelData.page
                    onClicked: root.page = modelData.page
                }
            }
        }


        // ========================================================
        // FULL PAGE AREA
        // ========================================================

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true


            // ====================================================
            // CLOCK / CALENDAR PAGE
            // ====================================================

            Item {
                anchors.fill: parent

                visible:
                    root.page === 0


                RowLayout {
                    anchors.fill: parent

                    spacing:
                        Nexa.Theme.spacingXl


                    // ============================================
                    // CLOCK
                    // ============================================

                    Item {
                        Layout.preferredWidth: 220
                        Layout.fillHeight: true


                        ColumnLayout {
                            anchors.centerIn: parent

                            spacing:
                                Nexa.Theme.spacingXs


                            Text {
                                Layout.alignment:
                                    Qt.AlignHCenter

                                text:
                                    Qt.formatDateTime(
                                        root.currentTime,
                                        "hh:mm"
                                    )

                                color:
                                    Nexa.Theme.text

                                font {
                                    family:
                                        Nexa.Theme.fontFamily

                                    pixelSize: 38

                                    weight:
                                        Nexa.Theme.fontWeightDemiBold
                                }
                            }


                            Text {
                                Layout.alignment:
                                    Qt.AlignHCenter

                                text:
                                    Qt.formatDateTime(
                                        root.currentTime,
                                        "AP"
                                    )

                                color:
                                    Nexa.Theme.primary

                                font {
                                    family:
                                        Nexa.Theme.fontFamily

                                    pixelSize:
                                        Nexa.Theme.fontSizeLg

                                    weight:
                                        Nexa.Theme.fontWeightDemiBold
                                }
                            }


                            Text {
                                Layout.alignment:
                                    Qt.AlignHCenter

                                text:
                                    Qt.formatDateTime(
                                        root.currentTime,
                                        "dddd"
                                    )

                                color:
                                    Nexa.Theme.text

                                font {
                                    family:
                                        Nexa.Theme.fontFamily

                                    pixelSize:
                                        Nexa.Theme.fontSizeMd

                                    weight:
                                        Nexa.Theme.fontWeightMedium
                                }
                            }


                            Text {
                                Layout.alignment:
                                    Qt.AlignHCenter

                                text:
                                    Qt.formatDateTime(
                                        root.currentTime,
                                        "d MMMM yyyy"
                                    )

                                color:
                                    Nexa.Theme.mutedText

                                font {
                                    family:
                                        Nexa.Theme.fontFamily

                                    pixelSize:
                                        Nexa.Theme.fontSizeSm
                                }
                            }
                        }
                    }


                    Rectangle {
                        Layout.preferredWidth: 1
                        Layout.fillHeight: true

                        Layout.topMargin:
                            Nexa.Theme.spacingSm

                        Layout.bottomMargin:
                            Nexa.Theme.spacingSm

                        color:
                            Nexa.Theme.divider
                    }


                    // ============================================
                    // MONTH CALENDAR
                    // ============================================

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        spacing:
                            Nexa.Theme.spacingSm


                        // ----------------------------------------
                        // MONTH HEADER
                        // ----------------------------------------

                        RowLayout {
                            Layout.fillWidth: true


                            // Previous
                            NexaUI.NexaButton {
                                implicitWidth: 32
                                implicitHeight: 30
                                icon: "󰅁"
                                onClicked: root.previousMonth()
                            }


                            // Month title
                            Text {
                                Layout.fillWidth: true

                                horizontalAlignment:
                                    Text.AlignHCenter

                                text:
                                    Qt.formatDate(
                                        root.calendarMonth,
                                        "MMMM yyyy"
                                    )

                                color:
                                    Nexa.Theme.text

                                font {
                                    family:
                                        Nexa.Theme.fontFamily

                                    pixelSize:
                                        Nexa.Theme.fontSizeMd

                                    weight:
                                        Nexa.Theme.fontWeightDemiBold
                                }
                            }


                            // Current
                            NexaUI.NexaButton {
                                implicitWidth: 80
                                implicitHeight: 30
                                text: "Current"
                                onClicked: root.goCurrentMonth()
                            }


                            // Next
                            NexaUI.NexaButton {
                                implicitWidth: 32
                                implicitHeight: 30
                                icon: "󰅂"
                                onClicked: root.nextMonth()
                            }
                        }


                        // ----------------------------------------
                        // WEEKDAYS
                        // ----------------------------------------

                        GridLayout {
                            Layout.fillWidth: true

                            columns: 7

                            columnSpacing: 4


                            Repeater {
                                model:
                                    root.weekDays


                                delegate: Text {
                                    required property string modelData

                                    Layout.fillWidth: true

                                    horizontalAlignment:
                                        Text.AlignHCenter

                                    text:
                                        modelData

                                    color:
                                        Nexa.Theme.mutedText

                                    font {
                                        family:
                                            Nexa.Theme.fontFamily

                                        pixelSize:
                                            Nexa.Theme.fontSizeXs

                                        weight:
                                            Nexa.Theme.fontWeightDemiBold
                                    }
                                }
                            }
                        }


                        // ----------------------------------------
                        // 6-WEEK MONTH GRID
                        // ----------------------------------------

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


                                    readonly property date cellDate:
                                        root.calendarDate(index)


                                    readonly property bool inMonth:
                                        cellDate.getMonth()
                                        === root.calendarMonth.getMonth()


                                    readonly property bool today:
                                        root.sameDay(
                                            cellDate,
                                            root.currentTime
                                        )


                                    Layout.fillWidth: true
                                    Layout.fillHeight: true


                                    radius:
                                        Nexa.Theme.radiusSm


                                    color:
                                        today
                                        ? Nexa.Theme.selected
                                        : "transparent"


                                    Text {
                                        anchors.centerIn: parent


                                        text:
                                            dayCell.cellDate.getDate()


                                        color:
                                            dayCell.today
                                            ? Nexa.Theme.selectedText
                                            : dayCell.inMonth
                                                ? Nexa.Theme.text
                                                : Nexa.Theme.mutedText


                                        opacity:
                                            dayCell.inMonth
                                            || dayCell.today
                                            ? 1.0
                                            : Nexa.Theme.opacityDisabled


                                        font {
                                            family:
                                                Nexa.Theme.fontFamily

                                            pixelSize:
                                                Nexa.Theme.fontSizeSm

                                            weight:
                                                dayCell.today
                                                ? Nexa.Theme.fontWeightDemiBold
                                                : Nexa.Theme.fontWeightMedium
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }


            // ====================================================
            // STOPWATCH FULL PAGE
            // ====================================================

            Item {
                anchors.fill: parent

                visible:
                    root.page === 1


                ColumnLayout {
                    anchors.centerIn: parent

                    spacing:
                        Nexa.Theme.spacingXl


                    // ============================================
                    // TIMER
                    // ============================================

                    Text {
                        Layout.alignment:
                            Qt.AlignHCenter


                        text:
                            root.stopwatchText(
                                root.stopwatchElapsed
                            )


                        color:
                            Nexa.Theme.text


                        font {
                            family:
                                Nexa.Theme.monoFontFamily

                            pixelSize: 40

                            weight:
                                Nexa.Theme.fontWeightDemiBold
                        }
                    }


                    // ============================================
                    // FULL STOPWATCH CONTROLS
                    // ============================================

                    RowLayout {
                        Layout.alignment:
                            Qt.AlignHCenter

                        spacing:
                            Nexa.Theme.spacingSm


                        // ----------------------------------------
                        // START / PAUSE / RESUME
                        // ----------------------------------------

                        NexaUI.NexaButton {
                            id: fullToggleButton
                            implicitWidth: 120
                            implicitHeight: 38
                            icon: root.stopwatchRunning ? "󰏤" : "󰐊"
                            text: root.stopwatchRunning ? "Pause" : (root.stopwatchElapsed > 0 ? "Resume" : "Start")
                            onClicked: root.toggleStopwatch()
                        }


                        // ----------------------------------------
                        // RESTART
                        // ----------------------------------------

                        NexaUI.NexaButton {
                            id: fullRestartButton
                            implicitWidth: 110
                            implicitHeight: 38
                            icon: "󰑐"
                            text: "Restart"
                            interactive: root.stopwatchActive
                            visible: root.stopwatchActive
                            onClicked: root.restartStopwatch()
                        }


                        // ----------------------------------------
                        // RESET
                        // ----------------------------------------

                        NexaUI.NexaButton {
                            id: fullResetButton
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
        }
    }
}
