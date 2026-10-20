import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../../theme" as Nexa
import "../../theme/components" as NexaUI

Item {
    id: root

    property real cpuUsage: 0
    property real ramUsage: 0
    property real diskUsage: 0

    property int cpuTemp: 0
    property int gpuTemp: 0
    property string gpuPower: "--"
    property int nvmeTemp: 0

    property string ramUsed: "--"
    property string ramTotal: "--"

    property string diskUsed: "--"
    property string diskTotal: "--"
    property string diskFree: "--"

    property string userName: "--"
    property string hostName: "--"
    property string uptime: "--"
    property string kernel: "--"
    property string osName: "--"

    property var topCpuList: []
    property var topMemList: []
    property string processTab: "cpu"

    property double previousCpuTotal: 0
    property double previousCpuIdle: 0

    property var cpuHistory: []
    property var ramHistory: []
    readonly property int historyLength: 36

    function clamp(val, min, max) { return Math.max(min, Math.min(max, val)) }

    function appendHistory(history, val) {
        let res = history ? history.slice() : []
        const cVal = clamp(val, 0, 100)
        if (res.length === 0) {
            for (let i = 0; i < root.historyLength; ++i) res.push(cVal)
        } else {
            res.push(cVal)
            while (res.length > root.historyLength) res.shift()
        }
        return res
    }

    function formatBytes(bytes) {
        const val = Number(bytes)
        if (!isFinite(val)) return "--"
        const gib = val / 1073741824
        return gib >= 100 ? gib.toFixed(0) + " GB" : gib.toFixed(1) + " GB"
    }

    function appIcon(name) {
        const n = String(name || "").toLowerCase()
        if (n.includes("chrome") || n.includes("chromium") || n.includes("brave")) return "󰊯"
        if (n.includes("firefox")) return "󰈹"
        if (n.includes("code") || n.includes("vsc")) return "󰨞"
        if (n.includes("spotify")) return "󰓇"
        if (n.includes("vlc") || n.includes("mpv")) return "󰕼"
        if (n.includes("kitty") || n.includes("alacritty") || n.includes("bash") || n.includes("zsh")) return "󰆍"
        if (n.includes("quickshell")) return "󰘚"
        if (n.includes("hypr") || n.includes("waybar")) return "󰍹"
        if (n.includes("discord") || n.includes("vesktop")) return "󰙯"
        if (n.includes("steam")) return "󰓓"
        return "󰘳"
    }

    function openMonitor() {
        Quickshell.execDetached(["kitty", "--title", "System Monitor", "-e", "sh", "-c", "export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8; exec btop --force-utf"])
    }

    function clearCache() {
        Quickshell.execDetached(["sh", "-c", "sync; (echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true)"])
        trimFeedbackTimer.restart()
        liveStatsProcess.running = true
    }

    function killProcess(pid) {
        if (!pid) return
        Quickshell.execDetached(["kill", "-9", String(pid)])
        root.topCpuList = root.topCpuList.filter(p => String(p.pid) !== String(pid))
        root.topMemList = root.topMemList.filter(p => String(p.pid) !== String(pid))
    }

    Timer { id: trimFeedbackTimer; interval: 1400; repeat: false }

    Timer {
        interval: 1500
        repeat: true
        running: root.visible
        triggeredOnStart: true
        onTriggered: {
            liveStatsProcess.running = true
            topProcessesProcess.running = true
        }
    }

    Component.onCompleted: staticInfoProcess.running = true

    Process {
        id: staticInfoProcess
        command: ["sh", "-c", "echo $(whoami); uname -n; uname -r; (source /etc/os-release 2>/dev/null && echo \"$PRETTY_NAME\") || uname -s"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                const lines = data.trim().split("\n")
                if (lines[0]) root.userName = lines[0].trim()
                if (lines[1]) root.hostName = lines[1].trim()
                if (lines[2]) root.kernel = lines[2].trim()
                if (lines[3]) root.osName = lines[3].trim()
            }
        }
    }

    Process {
        id: liveStatsProcess
        command: ["sh", "-c",
            "awk 'NR==1 {print $2+$3+$4+$5+$6+$7+$8, $5}' /proc/stat; " +
            "awk '/MemTotal:/ {tot=$2} /MemAvailable:/ {avail=$2} END {print tot*1024, (tot-avail)*1024, ((tot-avail)/tot)*100}' /proc/meminfo; " +
            "df -B1 / | awk 'NR==2 {print $2, $3, $4, $5}'; " +
            "uptime -p | sed 's/up //'; " +
            "sensors 2>/dev/null | awk '/(Tctl|Package id 0|CPU Temperature):/ {gsub(/[^0-9.]/,\"\",$2); print int($2); exit}'; " +
            "nvidia-smi --query-gpu=temperature.gpu,power.draw --format=csv,noheader,nounits 2>/dev/null || true; " +
            "sensors 2>/dev/null | awk '/(Composite|nvme-pci):/ {getline; gsub(/[^0-9.]/,\"\",$2); print int($2); exit}'"
        ]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                const lines = data.trim().split("\n")
                if (lines.length >= 4) {
                    const cParts = lines[0].trim().split(" ")
                    if (cParts.length >= 2) {
                        const curTot = Number(cParts[0]) || 0
                        const curIdle = Number(cParts[1]) || 0
                        if (root.previousCpuTotal > 0 && curTot > root.previousCpuTotal) {
                            const dTot = curTot - root.previousCpuTotal
                            const dIdle = curIdle - root.previousCpuIdle
                            const pct = Math.max(0, Math.min(100, Math.round(((dTot - dIdle) / dTot) * 100)))
                            root.cpuUsage = pct
                            root.cpuHistory = root.appendHistory(root.cpuHistory, pct)
                        }
                        root.previousCpuTotal = curTot
                        root.previousCpuIdle = curIdle
                    }
                    const mParts = lines[1].trim().split(" ")
                    if (mParts.length >= 3) {
                        root.ramTotal = root.formatBytes(mParts[0])
                        root.ramUsed = root.formatBytes(mParts[1])
                        const pct = Math.round(Number(mParts[2]) || 0)
                        root.ramUsage = pct
                        root.ramHistory = root.appendHistory(root.ramHistory, pct)
                    }
                    const dParts = lines[2].trim().split(" ")
                    if (dParts.length >= 4) {
                        root.diskTotal = root.formatBytes(dParts[0])
                        root.diskUsed = root.formatBytes(dParts[1])
                        root.diskFree = root.formatBytes(dParts[2])
                        root.diskUsage = parseInt(dParts[3]) || 0
                    }
                    if (lines[3]) root.uptime = lines[3].trim()
                    if (lines[4] && lines[4].trim()) root.cpuTemp = parseInt(lines[4].trim()) || 0
                    if (lines[5] && lines[5].includes(",")) {
                        const gParts = lines[5].split(",")
                        root.gpuTemp = parseInt(gParts[0].trim()) || 0
                        root.gpuPower = Math.round(parseFloat(gParts[1].trim()) || 0) + "W"
                    }
                    if (lines[6] && lines[6].trim()) root.nvmeTemp = parseInt(lines[6].trim()) || 0
                }
            }
        }
    }

    Process {
        id: topProcessesProcess
        command: ["sh", "-c", "ps -eo pid,%cpu,%mem,comm --sort=-%cpu | awk 'NR>1 && NR<=4 {print $1\":\"$2\":\"$3\":\"$4}'; echo '---'; ps -eo pid,%cpu,%mem,comm --sort=-%mem | awk 'NR>1 && NR<=4 {print $1\":\"$2\":\"$3\":\"$4}'"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                const chunks = data.trim().split("---")
                if (chunks.length >= 2) {
                    const parseRows = chunk => chunk.trim().split("\n").filter(l => l.trim().length > 0).map(l => {
                        const p = l.split(":")
                        return { pid: p[0], cpu: p[1] + "%", mem: p[2] + "%", name: p[3] || "proc", value: root.processTab === "cpu" ? p[1] + "%" : p[2] + "%" }
                    })
                    root.topCpuList = parseRows(chunks[0])
                    root.topMemList = parseRows(chunks[1])
                }
            }
        }
    }

    component Sparkline: Canvas {
        id: spark
        property var history: []
        property color lineColor: Nexa.Theme.primary
        antialiasing: true

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            if (!history || history.length < 2) return
            const step = width / (history.length - 1)

            ctx.beginPath()
            ctx.moveTo(0, height * (1.0 - (history[0] / 100.0)))
            for (let i = 0; i < history.length - 1; ++i) {
                const x0 = i * step
                const y0 = height * (1.0 - (history[i] / 100.0))
                const x1 = (i + 1) * step
                const y1 = height * (1.0 - (history[i + 1] / 100.0))
                ctx.quadraticCurveTo(x0, y0, (x0 + x1) / 2, (y0 + y1) / 2)
            }
            const lastX = (history.length - 1) * step
            const lastY = height * (1.0 - (history[history.length - 1] / 100.0))
            ctx.lineTo(lastX, lastY)
            ctx.lineTo(width, height)
            ctx.lineTo(0, height)
            ctx.closePath()

            const fill = ctx.createLinearGradient(0, 0, 0, height)
            fill.addColorStop(0, Qt.rgba(lineColor.r, lineColor.g, lineColor.b, 0.38))
            fill.addColorStop(1, Qt.rgba(lineColor.r, lineColor.g, lineColor.b, 0.02))
            ctx.fillStyle = fill
            ctx.fill()

            ctx.beginPath()
            ctx.moveTo(0, height * (1.0 - (history[0] / 100.0)))
            for (let i = 0; i < history.length - 1; ++i) {
                const x0 = i * step
                const y0 = height * (1.0 - (history[i] / 100.0))
                const x1 = (i + 1) * step
                const y1 = height * (1.0 - (history[i + 1] / 100.0))
                ctx.quadraticCurveTo(x0, y0, (x0 + x1) / 2, (y0 + y1) / 2)
            }
            ctx.lineTo(lastX, lastY)
            ctx.strokeStyle = lineColor
            ctx.lineWidth = 1.8
            ctx.stroke()
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: Nexa.Theme.spacingSm
        spacing: Nexa.Theme.spacingSm

        // Left 2x2 Grid (56% width)
        ColumnLayout {
            Layout.fillWidth: true
            Layout.preferredWidth: 320
            Layout.fillHeight: true
            spacing: Nexa.Theme.spacingSm

            // Top Row: CPU & RAM Cards
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Nexa.Theme.spacingSm

                // CPU Card
                NexaUI.NexaCard {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    interactive: true
                    padding: 10
                    onClicked: root.openMonitor()

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 2

                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: "CPU"; color: Nexa.Theme.text; font.family: Nexa.Theme.fontFamily; font.pixelSize: Nexa.Theme.fontSizeSm; font.weight: Nexa.Theme.fontWeightDemiBold }
                            Item { Layout.fillWidth: true }
                            Rectangle {
                                implicitWidth: cpuTempRow.implicitWidth + 10
                                implicitHeight: 18
                                radius: 9
                                color: root.cpuTemp > 75 ? Qt.rgba(Nexa.Theme.error.r, Nexa.Theme.error.g, Nexa.Theme.error.b, 0.2) : (root.cpuTemp > 58 ? Qt.rgba(Nexa.Theme.warning.r, Nexa.Theme.warning.g, Nexa.Theme.warning.b, 0.2) : Nexa.Theme.surfaceContainerHighest)
                                Row {
                                    id: cpuTempRow
                                    anchors.centerIn: parent
                                    spacing: 3
                                    Text { text: "󰍛"; color: root.cpuTemp > 75 ? Nexa.Theme.error : (root.cpuTemp > 58 ? Nexa.Theme.warning : Nexa.Theme.primary); font.family: Nexa.Theme.iconFontFamily; font.pixelSize: 11 }
                                    Text { text: root.cpuTemp > 0 ? root.cpuTemp + "°C" : "--"; color: Nexa.Theme.text; font.family: Nexa.Theme.monoFontFamily; font.pixelSize: Nexa.Theme.fontSize2Xs; font.weight: Nexa.Theme.fontWeightMedium }
                                }
                            }
                        }

                        Text { text: Math.round(root.cpuUsage) + "%"; color: Nexa.Theme.primary; font.family: Nexa.Theme.monoFontFamily; font.pixelSize: 20; font.weight: Nexa.Theme.fontWeightBold }

                        Sparkline {
                            id: cpuSpark
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            history: root.cpuHistory
                            lineColor: Nexa.Theme.primary
                            Connections { target: root; function onCpuHistoryChanged() { cpuSpark.requestPaint() } }
                        }
                    }
                }

                // RAM Card
                NexaUI.NexaCard {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    interactive: true
                    padding: 10
                    onClicked: root.openMonitor()

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 2

                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: "RAM"; color: Nexa.Theme.text; font.family: Nexa.Theme.fontFamily; font.pixelSize: Nexa.Theme.fontSizeSm; font.weight: Nexa.Theme.fontWeightDemiBold }
                            Item { Layout.fillWidth: true }
                            Rectangle {
                                implicitWidth: ramUsedRow.implicitWidth + 10
                                implicitHeight: 18
                                radius: 9
                                color: Nexa.Theme.surfaceContainerHighest
                                Row {
                                    id: ramUsedRow
                                    anchors.centerIn: parent
                                    spacing: 3
                                    Text { text: "󰘚"; color: Nexa.Theme.secondary; font.family: Nexa.Theme.iconFontFamily; font.pixelSize: 11 }
                                    Text { text: root.ramUsed + " / " + root.ramTotal; color: Nexa.Theme.text; font.family: Nexa.Theme.monoFontFamily; font.pixelSize: Nexa.Theme.fontSize2Xs; font.weight: Nexa.Theme.fontWeightMedium }
                                }
                            }
                        }

                        Text { text: Math.round(root.ramUsage) + "%"; color: Nexa.Theme.secondary; font.family: Nexa.Theme.monoFontFamily; font.pixelSize: 20; font.weight: Nexa.Theme.fontWeightBold }

                        Sparkline {
                            id: ramSpark
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            history: root.ramHistory
                            lineColor: Nexa.Theme.secondary
                            Connections { target: root; function onRamHistoryChanged() { ramSpark.requestPaint() } }
                        }
                    }
                }
            }

            // Bottom Row: GPU & Storage Cards
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Nexa.Theme.spacingSm

                // GPU & Thermals Card
                NexaUI.NexaCard {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    padding: 10

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 0

                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: "GPU & Thermals"; color: Nexa.Theme.text; font.family: Nexa.Theme.fontFamily; font.pixelSize: Nexa.Theme.fontSizeSm; font.weight: Nexa.Theme.fontWeightDemiBold }
                            Item { Layout.fillWidth: true }
                            Text { text: "󰢮"; color: Nexa.Theme.primary; font.family: Nexa.Theme.iconFontFamily; font.pixelSize: Nexa.Theme.iconSm }
                        }

                        Item { Layout.fillHeight: true }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Column {
                                Layout.fillWidth: true; spacing: 2
                                Text { text: "GPU Temp"; color: Nexa.Theme.mutedText; font.family: Nexa.Theme.fontFamily; font.pixelSize: Nexa.Theme.fontSize2Xs }
                                Text { text: root.gpuTemp > 0 ? root.gpuTemp + "°C" : "--"; color: Nexa.Theme.text; font.family: Nexa.Theme.monoFontFamily; font.pixelSize: Nexa.Theme.fontSizeSm; font.weight: Nexa.Theme.fontWeightBold }
                            }
                            Rectangle { width: 1; height: 22; color: Nexa.Theme.divider; Layout.alignment: Qt.AlignVCenter }

                            Column {
                                Layout.fillWidth: true; spacing: 2
                                Text { text: "Power"; color: Nexa.Theme.mutedText; font.family: Nexa.Theme.fontFamily; font.pixelSize: Nexa.Theme.fontSize2Xs }
                                Text { text: root.gpuPower; color: Nexa.Theme.text; font.family: Nexa.Theme.monoFontFamily; font.pixelSize: Nexa.Theme.fontSizeSm; font.weight: Nexa.Theme.fontWeightBold }
                            }
                            Rectangle { width: 1; height: 22; color: Nexa.Theme.divider; Layout.alignment: Qt.AlignVCenter }

                            Column {
                                Layout.fillWidth: true; spacing: 2
                                Text { text: "NVMe"; color: Nexa.Theme.mutedText; font.family: Nexa.Theme.fontFamily; font.pixelSize: Nexa.Theme.fontSize2Xs }
                                Text { text: root.nvmeTemp > 0 ? root.nvmeTemp + "°C" : "--"; color: Nexa.Theme.text; font.family: Nexa.Theme.monoFontFamily; font.pixelSize: Nexa.Theme.fontSizeSm; font.weight: Nexa.Theme.fontWeightBold }
                            }
                        }
                        Item { Layout.fillHeight: true }
                    }
                }

                // NVMe Storage Card
                NexaUI.NexaCard {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    padding: 10

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 5

                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: "Storage"; color: Nexa.Theme.text; font.family: Nexa.Theme.fontFamily; font.pixelSize: Nexa.Theme.fontSizeSm; font.weight: Nexa.Theme.fontWeightDemiBold }
                            Item { Layout.fillWidth: true }
                            Text { text: "󰋊"; color: Nexa.Theme.primary; font.family: Nexa.Theme.iconFontFamily; font.pixelSize: Nexa.Theme.iconSm }
                        }

                        Item { Layout.fillHeight: true }

                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: root.diskUsed + " / " + root.diskTotal; color: Nexa.Theme.text; font.family: Nexa.Theme.monoFontFamily; font.pixelSize: Nexa.Theme.fontSizeSm; font.weight: Nexa.Theme.fontWeightBold }
                            Item { Layout.fillWidth: true }
                            Text { text: root.diskUsage + "%"; color: Nexa.Theme.mutedText; font.family: Nexa.Theme.monoFontFamily; font.pixelSize: Nexa.Theme.fontSizeXs }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 6
                            radius: 3
                            color: Nexa.Theme.surfaceContainerHighest
                            clip: true

                            Rectangle {
                                width: parent.width * Math.min(1.0, root.diskUsage / 100.0)
                                height: parent.height
                                radius: 3
                                color: root.diskUsage > 90 ? Nexa.Theme.error : (root.diskUsage > 75 ? Nexa.Theme.warning : Nexa.Theme.tertiary)
                            }
                        }

                        Text { text: root.diskFree + " available"; color: Nexa.Theme.mutedText; font.family: Nexa.Theme.fontFamily; font.pixelSize: Nexa.Theme.fontSize2Xs }
                        Item { Layout.fillHeight: true }
                    }
                }
            }
        }

        // Right Column: Top Consumers & Actions (44% width)
        ColumnLayout {
            Layout.fillWidth: true
            Layout.preferredWidth: 260
            Layout.fillHeight: true
            spacing: Nexa.Theme.spacingSm

            // Top Consumers Card
            NexaUI.NexaCard {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                padding: 10

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "Top Consumers"; color: Nexa.Theme.text; font.family: Nexa.Theme.fontFamily; font.pixelSize: Nexa.Theme.fontSizeSm; font.weight: Nexa.Theme.fontWeightDemiBold }
                        Item { Layout.fillWidth: true }

                        Rectangle {
                            implicitWidth: 84; implicitHeight: 22; radius: 11
                            color: Nexa.Theme.surfaceContainerHighest
                            Row {
                                anchors.centerIn: parent; spacing: 2
                                Rectangle {
                                    width: 38; height: 18; radius: 9
                                    color: root.processTab === "cpu" ? Nexa.Theme.primary : "transparent"
                                    Text { anchors.centerIn: parent; text: "CPU"; color: root.processTab === "cpu" ? Nexa.Theme.onPrimary : Nexa.Theme.mutedText; font.family: Nexa.Theme.monoFontFamily; font.pixelSize: Nexa.Theme.fontSize2Xs; font.weight: Nexa.Theme.fontWeightBold }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.processTab = "cpu" }
                                }
                                Rectangle {
                                    width: 38; height: 18; radius: 9
                                    color: root.processTab === "mem" ? Nexa.Theme.secondary : "transparent"
                                    Text { anchors.centerIn: parent; text: "RAM"; color: root.processTab === "mem" ? Nexa.Theme.onSecondary : Nexa.Theme.mutedText; font.family: Nexa.Theme.monoFontFamily; font.pixelSize: Nexa.Theme.fontSize2Xs; font.weight: Nexa.Theme.fontWeightBold }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.processTab = "mem" }
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 2

                        Repeater {
                            model: root.processTab === "cpu" ? root.topCpuList : root.topMemList
                            delegate: Rectangle {
                                Layout.fillWidth: true; Layout.preferredHeight: 22; radius: 4
                                color: hoverHandler.hovered ? Nexa.Theme.hover : "transparent"
                                HoverHandler { id: hoverHandler }

                                RowLayout {
                                    anchors.fill: parent; anchors.leftMargin: 4; anchors.rightMargin: 4; spacing: 5
                                    Text { text: root.appIcon(modelData.name); color: Nexa.Theme.primary; font.family: Nexa.Theme.iconFontFamily; font.pixelSize: 12 }
                                    Text { text: modelData.name || "--"; color: Nexa.Theme.text; font.family: Nexa.Theme.fontFamily; font.pixelSize: Nexa.Theme.fontSizeXs; font.weight: Nexa.Theme.fontWeightMedium; Layout.fillWidth: true; elide: Text.ElideRight }
                                    Rectangle {
                                        implicitWidth: usageText.implicitWidth + 6; implicitHeight: 15; radius: 3
                                        color: Nexa.Theme.surfaceContainerHighest
                                        Text { id: usageText; anchors.centerIn: parent; text: modelData.value || "--"; color: root.processTab === "cpu" ? Nexa.Theme.primary : Nexa.Theme.secondary; font.family: Nexa.Theme.monoFontFamily; font.pixelSize: Nexa.Theme.fontSize2Xs; font.weight: Nexa.Theme.fontWeightDemiBold }
                                    }
                                    Rectangle {
                                        implicitWidth: 16; implicitHeight: 16; radius: 8
                                        color: killMouse.containsMouse ? Qt.rgba(Nexa.Theme.error.r, Nexa.Theme.error.g, Nexa.Theme.error.b, 0.35) : "transparent"
                                        visible: hoverHandler.hovered
                                        Text { anchors.centerIn: parent; text: "󰅙"; color: killMouse.containsMouse ? Nexa.Theme.error : Nexa.Theme.mutedText; font.family: Nexa.Theme.iconFontFamily; font.pixelSize: 11 }
                                        MouseArea { id: killMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.killProcess(modelData.pid) }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Quick Utilities & Specs Footer
            NexaUI.NexaCard {
                Layout.fillWidth: true
                Layout.preferredHeight: 82
                clip: true
                padding: 10

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 32
                        spacing: Nexa.Theme.spacingSm

                        Rectangle {
                            Layout.fillWidth: true; Layout.fillHeight: true
                            radius: Nexa.Theme.radiusSm
                            color: monMouse.containsMouse ? Nexa.Theme.primary : Nexa.Theme.surfaceContainerHighest
                            Behavior on color { ColorAnimation { duration: 150 } }
                            Row {
                                anchors.centerIn: parent; spacing: 6
                                Text { anchors.verticalCenter: parent.verticalCenter; text: "󰍹"; color: monMouse.containsMouse ? Nexa.Theme.onPrimary : Nexa.Theme.primary; font.family: Nexa.Theme.iconFontFamily; font.pixelSize: Nexa.Theme.iconSm }
                                Text { anchors.verticalCenter: parent.verticalCenter; text: "btop Monitor"; color: monMouse.containsMouse ? Nexa.Theme.onPrimary : Nexa.Theme.text; font.family: Nexa.Theme.fontFamily; font.pixelSize: Nexa.Theme.fontSizeXs; font.weight: Nexa.Theme.fontWeightMedium }
                            }
                            MouseArea { id: monMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.openMonitor() }
                        }

                        Rectangle {
                            Layout.fillWidth: true; Layout.fillHeight: true
                            radius: Nexa.Theme.radiusSm
                            color: trimMouse.containsMouse ? Nexa.Theme.secondary : (trimFeedbackTimer.running ? Qt.rgba(Nexa.Theme.success.r, Nexa.Theme.success.g, Nexa.Theme.success.b, 0.2) : Nexa.Theme.surfaceContainerHighest)
                            Behavior on color { ColorAnimation { duration: 150 } }
                            Row {
                                anchors.centerIn: parent; spacing: 6
                                Text { anchors.verticalCenter: parent.verticalCenter; text: trimFeedbackTimer.running ? "󰄬" : "󰃢"; color: trimMouse.containsMouse ? Nexa.Theme.onSecondary : (trimFeedbackTimer.running ? Nexa.Theme.success : Nexa.Theme.secondary); font.family: Nexa.Theme.iconFontFamily; font.pixelSize: Nexa.Theme.iconSm }
                                Text { anchors.verticalCenter: parent.verticalCenter; text: trimFeedbackTimer.running ? "Cache Dropped" : "Drop Cache"; color: trimMouse.containsMouse ? Nexa.Theme.onSecondary : Nexa.Theme.text; font.family: Nexa.Theme.fontFamily; font.pixelSize: Nexa.Theme.fontSizeXs; font.weight: Nexa.Theme.fontWeightMedium }
                            }
                            MouseArea { id: trimMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.clearCache() }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Text { text: root.osName + "  •  " + root.kernel; color: Nexa.Theme.mutedText; font.family: Nexa.Theme.fontFamily; font.pixelSize: Nexa.Theme.fontSize2Xs; Layout.fillWidth: true; elide: Text.ElideRight }
                        Text { text: "up " + root.uptime; color: Nexa.Theme.mutedText; font.family: Nexa.Theme.monoFontFamily; font.pixelSize: Nexa.Theme.fontSize2Xs }
                    }
                }
            }
        }
    }
}
