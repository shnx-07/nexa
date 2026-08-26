import QtQuick
import QtQuick.Layouts

import Quickshell
import Quickshell.Io

import "../../theme" as Nexa


Item {
    id: root

    // ============================================================
    // SYSTEM INFO
    //
    // Layout:
    //
    //   Disk     RAM      | User/System identity
    //   CPU wide          |
    //
    // One compact module.
    // No separate service/controller/model.
    // ============================================================


    // ============================================================
    // DATA
    // ============================================================

    property real cpuUsage: 0
    property real ramUsage: 0
    property real diskUsage: 0

    property string ramUsed: "--"
    property string ramTotal: "--"

    property string diskUsed: "--"
    property string diskTotal: "--"

    property string userName: "--"
    property string hostName: "--"
    property string uptime: "--"
    property string kernel: "--"
    property string osName: "--"


    // CPU needs two /proc/stat samples to calculate usage.
    property double previousCpuTotal: 0
    property double previousCpuIdle: 0


    // Graph history.
    property var cpuHistory: []
    property var ramHistory: []

    readonly property int historyLength: 42


    // ============================================================
    // LAYOUT
    // ============================================================

    readonly property int gap:
        Nexa.Theme.spacingMd

    readonly property int infoWidth:
        Math.round(width * 0.27)

    readonly property int dividerWidth: 1

    readonly property int graphAreaWidth:
        width
        - infoWidth
        - dividerWidth
        - gap * 2

    readonly property int topCardHeight:
        Math.floor((height - gap) * 0.46)

    readonly property int cpuCardHeight:
        height
        - topCardHeight
        - gap


    // ============================================================
    // HELPERS
    // ============================================================

    function clamp(value, minimum, maximum) {
        return Math.max(minimum, Math.min(maximum, value))
    }


    function appendHistory(history, value) {
        let result = history.slice()

        result.push(
            clamp(value, 0, 100)
        )

        while (result.length > root.historyLength)
            result.shift()

        return result
    }


    function formatBytes(bytes) {
        const value = Number(bytes)

        if (!isFinite(value))
            return "--"

        const gib = value / 1073741824

        if (gib >= 100)
            return gib.toFixed(0) + " GB"

        return gib.toFixed(1) + " GB"
    }


    function openMonitor() {
        Quickshell.execDetached([
            "kitty",
            "-e",
            "btop"
        ])
    }


    // ============================================================
    // LIVE CPU / RAM PROCESS
    //
    // Reads:
    //   /proc/stat
    //   /proc/meminfo
    //
    // One lightweight refresh per second.
    // ============================================================

    Process {
        id: liveStatsProcess

        command: [
            "sh",
            "-c",
            [
                "awk '",
                "/^cpu / {",
                    "total=0;",
                    "for(i=2;i<=NF;i++) total+=$i;",
                    "idle=$5+$6;",
                    "printf \"CPU %.0f %.0f\\n\", total, idle",
                "}",
                "' /proc/stat; ",

                "awk '",
                "/^MemTotal:/ { total=$2 }",
                "/^MemAvailable:/ { avail=$2 }",
                "END {",
                    "used=total-avail;",
                    "printf \"RAM %.0f %.0f %.0f\\n\",",
                    "used, total, (used/total)*100",
                "}",
                "' /proc/meminfo"
            ].join("")
        ]

        running: true


        stdout: StdioCollector {
            onStreamFinished: {
                const lines =
                    text.trim().split("\n")

                for (let i = 0; i < lines.length; ++i) {
                    const fields =
                        lines[i].trim().split(/\s+/)

                    if (fields.length === 0)
                        continue


                    // --------------------------------------------
                    // CPU
                    // --------------------------------------------

                    if (fields[0] === "CPU"
                            && fields.length >= 3) {

                        const total =
                            Number(fields[1])

                        const idle =
                            Number(fields[2])


                        if (root.previousCpuTotal > 0) {

                            const totalDelta =
                                total
                                - root.previousCpuTotal

                            const idleDelta =
                                idle
                                - root.previousCpuIdle


                            if (totalDelta > 0) {
                                root.cpuUsage =
                                    root.clamp(
                                        (
                                            1
                                            - idleDelta
                                            / totalDelta
                                        ) * 100,
                                        0,
                                        100
                                    )

                                root.cpuHistory =
                                    root.appendHistory(
                                        root.cpuHistory,
                                        root.cpuUsage
                                    )

                                cpuGraph.requestPaint()
                            }
                        }


                        root.previousCpuTotal =
                            total

                        root.previousCpuIdle =
                            idle
                    }


                    // --------------------------------------------
                    // RAM
                    // --------------------------------------------

                    if (fields[0] === "RAM"
                            && fields.length >= 4) {

                        const usedKb =
                            Number(fields[1])

                        const totalKb =
                            Number(fields[2])

                        const percent =
                            Number(fields[3])


                        root.ramUsage =
                            root.clamp(
                                percent,
                                0,
                                100
                            )


                        root.ramUsed =
                            root.formatBytes(
                                usedKb * 1024
                            )

                        root.ramTotal =
                            root.formatBytes(
                                totalKb * 1024
                            )


                        root.ramHistory =
                            root.appendHistory(
                                root.ramHistory,
                                root.ramUsage
                            )


                        ramGraph.requestPaint()
                    }
                }
            }
        }
    }


    Timer {
        interval: 1000
        running: root.visible
        repeat: true

        onTriggered: {
            if (!liveStatsProcess.running)
                liveStatsProcess.running = true
        }
    }


    // ============================================================
    // SLOW DATA
    //
    // Disk + identity/system information.
    //
    // No reason to update this every second.
    // ============================================================

    Process {
        id: slowStatsProcess

        command: [
            "sh",
            "-c",
            [
                "df -B1 / | awk 'NR==2 {",
                    "gsub(\"%\", \"\", $5);",
                    "printf \"DISK %s %s %s\\n\",",
                    "$3, $2, $5",
                "}'; ",

                "printf 'USER %s\\n' \"$(whoami)\"; ",
                "printf 'HOST %s\\n' \"$(hostname)\"; ",

                "printf 'UPTIME %s\\n' \"$(",
                    "uptime -p | sed 's/^up //'",
                ")\"; ",

                "printf 'KERNEL %s\\n' \"$(",
                    "uname -r",
                ")\"; ",

                "printf 'OS %s\\n' \"$(",
                    ". /etc/os-release 2>/dev/null; ",
                    "printf '%s' \"${PRETTY_NAME:-Linux}\"",
                ")\""
            ].join("")
        ]

        running: true


        stdout: StdioCollector {
            onStreamFinished: {
                const lines =
                    text.trim().split("\n")

                for (let i = 0; i < lines.length; ++i) {

                    const line =
                        lines[i].trim()

                    const split =
                        line.indexOf(" ")

                    if (split < 0)
                        continue


                    const key =
                        line.substring(0, split)

                    const value =
                        line.substring(split + 1)


                    switch (key) {

                    case "DISK": {
                        const disk =
                            value.split(/\s+/)

                        if (disk.length >= 3) {
                            root.diskUsed =
                                root.formatBytes(
                                    Number(disk[0])
                                )

                            root.diskTotal =
                                root.formatBytes(
                                    Number(disk[1])
                                )

                            root.diskUsage =
                                root.clamp(
                                    Number(disk[2]),
                                    0,
                                    100
                                )

                            diskGraph.requestPaint()
                        }

                        break
                    }


                    case "USER":
                        root.userName =
                            value
                        break


                    case "HOST":
                        root.hostName =
                            value
                        break


                    case "UPTIME":
                        root.uptime =
                            value
                        break


                    case "KERNEL":
                        root.kernel =
                            value
                        break


                    case "OS":
                        root.osName =
                            value
                        break
                    }
                }
            }
        }
    }


    Timer {
        interval: 30000
        running: root.visible
        repeat: true

        onTriggered: {
            if (!slowStatsProcess.running)
                slowStatsProcess.running = true
        }
    }


    // ============================================================
    // LEFT GRAPH AREA
    // ============================================================

    Item {
        id: graphArea

        anchors {
            top: parent.top
            bottom: parent.bottom
            left: parent.left
        }

        width:
            root.graphAreaWidth


        // ========================================================
        // DISK
        // ========================================================

        Rectangle {
            id: diskCard

            property bool hovered: false
            property bool pressed: false

            anchors {
                top: parent.top
                left: parent.left
            }

            width:
                Math.floor(
                    (parent.width - root.gap) / 2
                )

            height:
                root.topCardHeight

            radius:
                Nexa.Theme.radiusMd

            color: {
                if (pressed)
                    return Nexa.Theme.pressed

                if (hovered)
                    return Nexa.Theme.cardBackgroundElevated

                return Nexa.Theme.cardBackground
            }

            border.width:
                Nexa.Theme.borderThin

            border.color:
                hovered
                ? Nexa.Theme.borderStrong
                : Nexa.Theme.border

            clip: true


            Behavior on color {
                ColorAnimation {
                    duration:
                        Nexa.Theme.animationFast
                }
            }


            Behavior on border.color {
                ColorAnimation {
                    duration:
                        Nexa.Theme.animationFast
                }
            }


            Text {
                id: diskTitle

                anchors {
                    top: parent.top
                    left: parent.left

                    topMargin:
                        Nexa.Theme.spacingMd

                    leftMargin:
                        Nexa.Theme.spacingMd
                }

                text:
                    "Disk"

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


            Text {
                anchors {
                    top: parent.top
                    right: parent.right

                    topMargin:
                        Nexa.Theme.spacingMd

                    rightMargin:
                        Nexa.Theme.spacingMd
                }

                text:
                    Math.round(root.diskUsage)
                    + "%"

                color:
                    Nexa.Theme.primary

                font {
                    family:
                        Nexa.Theme.monoFontFamily

                    pixelSize:
                        Nexa.Theme.fontSizeSm

                    weight:
                        Nexa.Theme.fontWeightDemiBold
                }
            }


            Text {
                anchors {
                    top: diskTitle.bottom
                    left: parent.left

                    topMargin:
                        Nexa.Theme.spacing2Xs

                    leftMargin:
                        Nexa.Theme.spacingMd
                }

                text:
                    root.diskUsed
                    + " / "
                    + root.diskTotal

                color:
                    Nexa.Theme.mutedText

                font {
                    family:
                        Nexa.Theme.monoFontFamily

                    pixelSize:
                        Nexa.Theme.fontSizeXs
                }
            }


            Canvas {
                id: diskGraph

                anchors {
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom

                    leftMargin:
                        Nexa.Theme.spacingMd

                    rightMargin:
                        Nexa.Theme.spacingMd

                    bottomMargin:
                        Nexa.Theme.spacingMd
                }

                height:
                    Math.max(
                        24,
                        parent.height * 0.34
                    )

                antialiasing: true


                onPaint: {
                    const ctx =
                        getContext("2d")

                    ctx.reset()


                    const percentage =
                        root.diskUsage / 100

                    const y =
                        height * (1 - percentage)


                    ctx.beginPath()

                    ctx.moveTo(
                        0,
                        height
                    )

                    ctx.lineTo(
                        0,
                        y
                    )

                    ctx.lineTo(
                        width,
                        y
                    )

                    ctx.lineTo(
                        width,
                        height
                    )

                    ctx.closePath()


                    const fill =
                        ctx.createLinearGradient(
                            0,
                            0,
                            0,
                            height
                        )

                    fill.addColorStop(
                        0,
                        Qt.rgba(
                            Nexa.Theme.primary.r,
                            Nexa.Theme.primary.g,
                            Nexa.Theme.primary.b,
                            0.30
                        )
                    )

                    fill.addColorStop(
                        1,
                        Qt.rgba(
                            Nexa.Theme.primary.r,
                            Nexa.Theme.primary.g,
                            Nexa.Theme.primary.b,
                            0.03
                        )
                    )


                    ctx.fillStyle =
                        fill

                    ctx.fill()


                    ctx.beginPath()

                    ctx.moveTo(
                        0,
                        y
                    )

                    ctx.lineTo(
                        width,
                        y
                    )

                    ctx.strokeStyle =
                        Nexa.Theme.primary

                    ctx.lineWidth =
                        1.5

                    ctx.stroke()
                }


                Connections {
                    target:
                        Nexa.Theme

                    function onPrimaryChanged() {
                        diskGraph.requestPaint()
                    }
                }
            }


            MouseArea {
                anchors.fill:
                    parent

                hoverEnabled:
                    true

                cursorShape:
                    Qt.PointingHandCursor


                onEntered:
                    diskCard.hovered = true


                onExited: {
                    diskCard.hovered = false
                    diskCard.pressed = false
                }


                onPressed:
                    diskCard.pressed = true


                onReleased:
                    diskCard.pressed = false


                onClicked:
                    root.openMonitor()
            }
        }


        // ========================================================
        // RAM
        // ========================================================

        Rectangle {
            id: ramCard

            property bool hovered: false
            property bool pressed: false

            anchors {
                top: parent.top
                right: parent.right
            }

            width:
                Math.ceil(
                    (parent.width - root.gap) / 2
                )

            height:
                root.topCardHeight

            radius:
                Nexa.Theme.radiusMd

            color: {
                if (pressed)
                    return Nexa.Theme.pressed

                if (hovered)
                    return Nexa.Theme.cardBackgroundElevated

                return Nexa.Theme.cardBackground
            }

            border.width:
                Nexa.Theme.borderThin

            border.color:
                hovered
                ? Nexa.Theme.borderStrong
                : Nexa.Theme.border

            clip: true


            Behavior on color {
                ColorAnimation {
                    duration:
                        Nexa.Theme.animationFast
                }
            }


            Text {
                id: ramTitle

                anchors {
                    top: parent.top
                    left: parent.left

                    topMargin:
                        Nexa.Theme.spacingMd

                    leftMargin:
                        Nexa.Theme.spacingMd
                }

                text:
                    "RAM"

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


            Text {
                anchors {
                    top: parent.top
                    right: parent.right

                    topMargin:
                        Nexa.Theme.spacingMd

                    rightMargin:
                        Nexa.Theme.spacingMd
                }

                text:
                    Math.round(root.ramUsage)
                    + "%"

                color:
                    Nexa.Theme.secondary

                font {
                    family:
                        Nexa.Theme.monoFontFamily

                    pixelSize:
                        Nexa.Theme.fontSizeSm

                    weight:
                        Nexa.Theme.fontWeightDemiBold
                }
            }


            Text {
                anchors {
                    top: ramTitle.bottom
                    left: parent.left

                    topMargin:
                        Nexa.Theme.spacing2Xs

                    leftMargin:
                        Nexa.Theme.spacingMd
                }

                text:
                    root.ramUsed
                    + " / "
                    + root.ramTotal

                color:
                    Nexa.Theme.mutedText

                font {
                    family:
                        Nexa.Theme.monoFontFamily

                    pixelSize:
                        Nexa.Theme.fontSizeXs
                }
            }


            Canvas {
                id: ramGraph

                anchors {
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom

                    leftMargin:
                        Nexa.Theme.spacingMd

                    rightMargin:
                        Nexa.Theme.spacingMd

                    bottomMargin:
                        Nexa.Theme.spacingMd
                }

                height:
                    Math.max(
                        28,
                        parent.height * 0.38
                    )

                antialiasing:
                    true


                onPaint: {
                    const ctx =
                        getContext("2d")

                    ctx.reset()


                    if (root.ramHistory.length < 2)
                        return


                    const step =
                        width
                        / Math.max(
                            1,
                            root.historyLength - 1
                        )


                    ctx.beginPath()


                    for (
                        let i = 0;
                        i < root.ramHistory.length;
                        ++i
                    ) {

                        const x =
                            width
                            - (
                                root.ramHistory.length
                                - 1
                                - i
                            ) * step

                        const y =
                            height
                            - (
                                root.ramHistory[i]
                                / 100
                            ) * height


                        if (i === 0)
                            ctx.moveTo(x, y)
                        else
                            ctx.lineTo(x, y)
                    }


                    ctx.strokeStyle =
                        Nexa.Theme.secondary

                    ctx.lineWidth =
                        1.6

                    ctx.stroke()
                }


                Connections {
                    target:
                        Nexa.Theme

                    function onSecondaryChanged() {
                        ramGraph.requestPaint()
                    }
                }
            }


            MouseArea {
                anchors.fill:
                    parent

                hoverEnabled:
                    true

                cursorShape:
                    Qt.PointingHandCursor


                onEntered:
                    ramCard.hovered = true


                onExited: {
                    ramCard.hovered = false
                    ramCard.pressed = false
                }


                onPressed:
                    ramCard.pressed = true


                onReleased:
                    ramCard.pressed = false


                onClicked:
                    root.openMonitor()
            }
        }


        // ========================================================
        // CPU
        // ========================================================

        Rectangle {
            id: cpuCard

            property bool hovered: false
            property bool pressed: false

            anchors {
                left: parent.left
                right: parent.right
                bottom: parent.bottom
            }

            height:
                root.cpuCardHeight

            radius:
                Nexa.Theme.radiusMd

            color: {
                if (pressed)
                    return Nexa.Theme.pressed

                if (hovered)
                    return Nexa.Theme.cardBackgroundElevated

                return Nexa.Theme.cardBackground
            }

            border.width:
                Nexa.Theme.borderThin

            border.color:
                hovered
                ? Nexa.Theme.borderStrong
                : Nexa.Theme.border

            clip:
                true


            Behavior on color {
                ColorAnimation {
                    duration:
                        Nexa.Theme.animationFast
                }
            }


            Text {
                anchors {
                    top: parent.top
                    left: parent.left

                    topMargin:
                        Nexa.Theme.spacingMd

                    leftMargin:
                        Nexa.Theme.spacingMd
                }

                text:
                    "CPU"

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


            Text {
                anchors {
                    top: parent.top
                    right: parent.right

                    topMargin:
                        Nexa.Theme.spacingMd

                    rightMargin:
                        Nexa.Theme.spacingMd
                }

                text:
                    Math.round(root.cpuUsage)
                    + "%"

                color:
                    Nexa.Theme.tertiary

                font {
                    family:
                        Nexa.Theme.monoFontFamily

                    pixelSize:
                        Nexa.Theme.fontSizeMd

                    weight:
                        Nexa.Theme.fontWeightDemiBold
                }
            }


            Canvas {
                id: cpuGraph

                anchors {
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom

                    leftMargin:
                        Nexa.Theme.spacingMd

                    rightMargin:
                        Nexa.Theme.spacingMd

                    bottomMargin:
                        Nexa.Theme.spacingMd
                }

                height:
                    Math.max(
                        46,
                        parent.height * 0.55
                    )

                antialiasing:
                    true


                onPaint: {
                    const ctx =
                        getContext("2d")

                    ctx.reset()


                    if (root.cpuHistory.length < 2)
                        return


                    const step =
                        width
                        / Math.max(
                            1,
                            root.historyLength - 1
                        )


                    // --------------------------------------------
                    // Filled graph
                    // --------------------------------------------

                    ctx.beginPath()


                    for (
                        let i = 0;
                        i < root.cpuHistory.length;
                        ++i
                    ) {

                        const x =
                            width
                            - (
                                root.cpuHistory.length
                                - 1
                                - i
                            ) * step

                        const y =
                            height
                            - (
                                root.cpuHistory[i]
                                / 100
                            ) * height


                        if (i === 0)
                            ctx.moveTo(x, y)
                        else
                            ctx.lineTo(x, y)
                    }


                    const lastX =
                        width

                    ctx.lineTo(
                        lastX,
                        height
                    )

                    ctx.lineTo(
                        Math.max(
                            0,
                            width
                            - (
                                root.cpuHistory.length
                                - 1
                            ) * step
                        ),
                        height
                    )

                    ctx.closePath()


                    const fill =
                        ctx.createLinearGradient(
                            0,
                            0,
                            0,
                            height
                        )

                    fill.addColorStop(
                        0,
                        Qt.rgba(
                            Nexa.Theme.tertiary.r,
                            Nexa.Theme.tertiary.g,
                            Nexa.Theme.tertiary.b,
                            0.30
                        )
                    )

                    fill.addColorStop(
                        1,
                        Qt.rgba(
                            Nexa.Theme.tertiary.r,
                            Nexa.Theme.tertiary.g,
                            Nexa.Theme.tertiary.b,
                            0.02
                        )
                    )


                    ctx.fillStyle =
                        fill

                    ctx.fill()


                    // --------------------------------------------
                    // Graph line
                    // --------------------------------------------

                    ctx.beginPath()


                    for (
                        let j = 0;
                        j < root.cpuHistory.length;
                        ++j
                    ) {

                        const x =
                            width
                            - (
                                root.cpuHistory.length
                                - 1
                                - j
                            ) * step

                        const y =
                            height
                            - (
                                root.cpuHistory[j]
                                / 100
                            ) * height


                        if (j === 0)
                            ctx.moveTo(x, y)
                        else
                            ctx.lineTo(x, y)
                    }


                    ctx.strokeStyle =
                        Nexa.Theme.tertiary

                    ctx.lineWidth =
                        1.8

                    ctx.stroke()
                }


                Connections {
                    target:
                        Nexa.Theme

                    function onTertiaryChanged() {
                        cpuGraph.requestPaint()
                    }
                }
            }


            MouseArea {
                anchors.fill:
                    parent

                hoverEnabled:
                    true

                cursorShape:
                    Qt.PointingHandCursor


                onEntered:
                    cpuCard.hovered = true


                onExited: {
                    cpuCard.hovered = false
                    cpuCard.pressed = false
                }


                onPressed:
                    cpuCard.pressed = true


                onReleased:
                    cpuCard.pressed = false


                onClicked:
                    root.openMonitor()
            }
        }
    }


    // ============================================================
    // VERTICAL DIVIDER
    // ============================================================

    Rectangle {
        id: verticalDivider

        anchors {
            top: parent.top
            bottom: parent.bottom
            left: graphArea.right

            leftMargin:
                root.gap
        }

        width:
            root.dividerWidth

        color:
            Nexa.Theme.divider
    }


    // ============================================================
    // RIGHT SYSTEM INFORMATION
    // ============================================================

    Item {
        id: infoArea

        anchors {
            top: parent.top
            right: parent.right
            bottom: parent.bottom
            left: verticalDivider.right

            leftMargin:
                root.gap
        }


        Column {
            anchors {
                fill: parent
            }

            spacing:
                Nexa.Theme.spacingSm


            // ----------------------------------------------------
            // USER
            // ----------------------------------------------------

            Column {
                width:
                    parent.width

                spacing:
                    Nexa.Theme.spacing2Xs


                Text {
                    width:
                        parent.width

                    text:
                        "USER"

                    color:
                        Nexa.Theme.mutedText

                    font {
                        family:
                            Nexa.Theme.fontFamily

                        pixelSize:
                            Nexa.Theme.fontSize2Xs

                        weight:
                            Nexa.Theme.fontWeightDemiBold
                    }
                }


                Text {
                    width:
                        parent.width

                    text:
                        root.userName

                    color:
                        Nexa.Theme.text

                    elide:
                        Text.ElideRight

                    font {
                        family:
                            Nexa.Theme.fontFamily

                        pixelSize:
                            Nexa.Theme.fontSizeMd

                        weight:
                            Nexa.Theme.fontWeightDemiBold
                    }
                }
            }


            // ----------------------------------------------------
            // HOST
            // ----------------------------------------------------

            Column {
                width:
                    parent.width

                spacing:
                    Nexa.Theme.spacing2Xs


                Text {
                    text:
                        "HOST"

                    color:
                        Nexa.Theme.mutedText

                    font {
                        family:
                            Nexa.Theme.fontFamily

                        pixelSize:
                            Nexa.Theme.fontSize2Xs

                        weight:
                            Nexa.Theme.fontWeightDemiBold
                    }
                }


                Text {
                    width:
                        parent.width

                    text:
                        root.hostName

                    color:
                        Nexa.Theme.text

                    elide:
                        Text.ElideRight

                    font {
                        family:
                            Nexa.Theme.monoFontFamily

                        pixelSize:
                            Nexa.Theme.fontSizeSm

                        weight:
                            Nexa.Theme.fontWeightMedium
                    }
                }
            }


            // ----------------------------------------------------
            // UPTIME
            // ----------------------------------------------------

            Column {
                width:
                    parent.width

                spacing:
                    Nexa.Theme.spacing2Xs


                Text {
                    text:
                        "UPTIME"

                    color:
                        Nexa.Theme.mutedText

                    font {
                        family:
                            Nexa.Theme.fontFamily

                        pixelSize:
                            Nexa.Theme.fontSize2Xs

                        weight:
                            Nexa.Theme.fontWeightDemiBold
                    }
                }


                Text {
                    width:
                        parent.width

                    text:
                        root.uptime

                    color:
                        Nexa.Theme.text

                    elide:
                        Text.ElideRight

                    font {
                        family:
                            Nexa.Theme.monoFontFamily

                        pixelSize:
                            Nexa.Theme.fontSizeXs
                    }
                }
            }


            // ----------------------------------------------------
            // KERNEL
            // ----------------------------------------------------

            Column {
                width:
                    parent.width

                spacing:
                    Nexa.Theme.spacing2Xs


                Text {
                    text:
                        "KERNEL"

                    color:
                        Nexa.Theme.mutedText

                    font {
                        family:
                            Nexa.Theme.fontFamily

                        pixelSize:
                            Nexa.Theme.fontSize2Xs

                        weight:
                            Nexa.Theme.fontWeightDemiBold
                    }
                }


                Text {
                    width:
                        parent.width

                    text:
                        root.kernel

                    color:
                        Nexa.Theme.text

                    elide:
                        Text.ElideRight

                    font {
                        family:
                            Nexa.Theme.monoFontFamily

                        pixelSize:
                            Nexa.Theme.fontSizeXs
                    }
                }
            }


            // ----------------------------------------------------
            // OS
            // ----------------------------------------------------

            Column {
                width:
                    parent.width

                spacing:
                    Nexa.Theme.spacing2Xs


                Text {
                    text:
                        "OS"

                    color:
                        Nexa.Theme.mutedText

                    font {
                        family:
                            Nexa.Theme.fontFamily

                        pixelSize:
                            Nexa.Theme.fontSize2Xs

                        weight:
                            Nexa.Theme.fontWeightDemiBold
                    }
                }


                Text {
                    width:
                        parent.width

                    text:
                        root.osName

                    color:
                        Nexa.Theme.text

                    elide:
                        Text.ElideRight

                    maximumLineCount:
                        2

                    wrapMode:
                        Text.Wrap

                    font {
                        family:
                            Nexa.Theme.fontFamily

                        pixelSize:
                            Nexa.Theme.fontSizeXs
                    }
                }
            }
        }
    }
}
