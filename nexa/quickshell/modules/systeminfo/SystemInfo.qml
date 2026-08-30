import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import Quickshell
import Quickshell.Io

import "../../theme" as Nexa
import "../../theme/components" as NexaUI


Item {
    id: root

    // ============================================================
    // RESPONSIBILITY
    //
    // Polished NEXA System Performance & Hardware Diagnostics Hub:
    // - Smooth Bezier sparklines with gradient fills (CPU & RAM)
    // - CPU, GPU & NVMe SSD Thermals & Power
    // - Mini Task Manager (Top 3 CPU & RAM consumers with working kill action & app icons)
    // - Quick System Utilities (Monitor launcher, working memory trim, uptime specs)
    // ============================================================

    // ============================================================
    // DATA PROPERTIES
    // ============================================================

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

    property string userName: "--"
    property string hostName: "--"
    property string uptime: "--"
    property string kernel: "--"
    property string osName: "--"

    // Top processes
    property var topCpuList: []
    property var topMemList: []
    property string processTab: "cpu" // "cpu" or "mem"

    // CPU delta calculation
    property double previousCpuTotal: 0
    property double previousCpuIdle: 0

    // History graphs (36 samples)
    property var cpuHistory: []
    property var ramHistory: []
    readonly property int historyLength: 36

    // ============================================================
    // HELPERS
    // ============================================================

    function clamp(val, min, max) {
        return Math.max(min, Math.min(max, val))
    }

    function appendHistory(history, val) {
        let res = history ? history.slice() : []
        const clampedVal = clamp(val, 0, 100)
        if (res.length === 0) {
            for (let i = 0; i < root.historyLength; ++i)
                res.push(clampedVal)
        } else {
            res.push(clampedVal)
            while (res.length > root.historyLength)
                res.shift()
        }
        return res
    }

    function formatBytes(bytes) {
        const val = Number(bytes)
        if (!isFinite(val)) return "--"
        const gib = val / 1073741824
        if (gib >= 100) return gib.toFixed(0) + " GB"
        return gib.toFixed(1) + " GB"
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
        Quickshell.execDetached([
            "kitty",
            "--title",
            "System Monitor",
            "-e",
            "sh",
            "-c",
            "export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8; exec btop --force-utf"
        ])
    }

    function clearCache() {
        Quickshell.execDetached([
            "sh",
            "-c",
            "sync; (echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true)"
        ])
        trimFeedbackTimer.restart()
        liveStatsProcess.running = true
    }

    function killProcess(pid) {
        if (!pid) return
        Quickshell.execDetached([
            "kill",
            "-9",
            String(pid)
        ])
        root.topCpuList = root.topCpuList.filter(p => String(p.pid) !== String(pid))
        root.topMemList = root.topMemList.filter(p => String(p.pid) !== String(pid))
        liveStatsProcess.running = true
    }

    Timer {
        id: trimFeedbackTimer
        interval: 2000
        repeat: false
    }

    // ============================================================
    // LIVE METRICS & SENSORS PROCESS (Runs every 1.5 seconds)
    // ============================================================

    Process {
        id: liveStatsProcess
        command: [
            "sh",
            "-c",
            [
                "# CPU /proc/stat\n",
                "awk '/^cpu / { total=0; for(i=2;i<=NF;i++) total+=$i; idle=$5+$6; printf \"CPU %.0f %.0f\\n\", total, idle }' /proc/stat;\n",
                "# RAM /proc/meminfo\n",
                "awk '/^MemTotal:/ { total=$2 } /^MemAvailable:/ { avail=$2 } END { used=total-avail; printf \"RAM %.0f %.0f %.0f\\n\", used, total, (used/total)*100 }' /proc/meminfo;\n",
                "# Sensors (CPU, GPU, NVMe)\n",
                "sensors 2>/dev/null | awk '/Tctl:/ { gsub(\"[+°C]\", \"\", $2); printf \"CPUTEMP %s\\n\", int($2) } /edge:/ { gsub(\"[+°C]\", \"\", $2); printf \"GPUTEMP %s\\n\", int($2) } /PPT:/ { printf \"GPUPOWER %s\\n\", $2 } /Composite:/ { gsub(\"[+°C]\", \"\", $2); printf \"NVMETEMP %s\\n\", int($2) }';\n",
                "# Top 3 CPU\n",
                "printf \"TOP_CPU_START\\n\";\n",
                "ps -eo pid,comm,%cpu --sort=-%cpu --no-headers | head -n 3 | while read -r pid comm cpu; do printf \"TOP_CPU %s %s %s\\n\" \"$pid\" \"$comm\" \"$cpu\"; done;\n",
                "# Top 3 RAM\n",
                "printf \"TOP_MEM_START\\n\";\n",
                "ps -eo pid,comm,rss --sort=-rss --no-headers | head -n 3 | while read -r pid comm rss; do mb=$(( rss / 1024 )); printf \"TOP_MEM %s %s %s\\n\" \"$pid\" \"$comm\" \"$mb\"; done\n"
            ].join("")
        ]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n")
                const newTopCpu = []
                const newTopMem = []

                for (let i = 0; i < lines.length; ++i) {
                    const fields = lines[i].trim().split(/\s+/)
                    if (fields.length === 0 || fields[0] === "") continue

                    // CPU Usage
                    if (fields[0] === "CPU" && fields.length >= 3) {
                        const total = Number(fields[1])
                        const idle = Number(fields[2])
                        if (root.previousCpuTotal > 0) {
                            const totalDelta = total - root.previousCpuTotal
                            const idleDelta = idle - root.previousCpuIdle
                            if (totalDelta > 0) {
                                root.cpuUsage = root.clamp((1.0 - idleDelta / totalDelta) * 100, 0, 100)
                                root.cpuHistory = root.appendHistory(root.cpuHistory, root.cpuUsage)
                                cpuGraph.requestPaint()
                            }
                        } else {
                            root.cpuHistory = root.appendHistory(root.cpuHistory, 5)
                            cpuGraph.requestPaint()
                        }
                        root.previousCpuTotal = total
                        root.previousCpuIdle = idle
                    }

                    // RAM Usage
                    else if (fields[0] === "RAM" && fields.length >= 4) {
                        const usedKb = Number(fields[1])
                        const totalKb = Number(fields[2])
                        const percent = Number(fields[3])
                        root.ramUsage = root.clamp(percent, 0, 100)
                        root.ramUsed = root.formatBytes(usedKb * 1024)
                        root.ramTotal = root.formatBytes(totalKb * 1024)
                        root.ramHistory = root.appendHistory(root.ramHistory, root.ramUsage)
                        ramGraph.requestPaint()
                    }

                    // Thermals
                    else if (fields[0] === "CPUTEMP" && fields.length >= 2) {
                        root.cpuTemp = Number(fields[1]) || 0
                    }
                    else if (fields[0] === "GPUTEMP" && fields.length >= 2) {
                        root.gpuTemp = Number(fields[1]) || 0
                    }
                    else if (fields[0] === "GPUPOWER" && fields.length >= 2) {
                        const w = Math.round(Number(fields[1])) || 0
                        root.gpuPower = w > 0 ? w + "W" : fields[1]
                    }
                    else if (fields[0] === "NVMETEMP" && fields.length >= 2) {
                        root.nvmeTemp = Number(fields[1]) || 0
                    }

                    // Top CPU List
                    else if (fields[0] === "TOP_CPU" && fields.length >= 4) {
                        newTopCpu.push({
                            pid: fields[1],
                            name: fields[2],
                            value: fields[3] + "%"
                        })
                    }

                    // Top RAM List
                    else if (fields[0] === "TOP_MEM" && fields.length >= 4) {
                        newTopMem.push({
                            pid: fields[1],
                            name: fields[2],
                            value: fields[3] + " MB"
                        })
                    }
                }

                if (newTopCpu.length > 0) root.topCpuList = newTopCpu
                if (newTopMem.length > 0) root.topMemList = newTopMem
            }
        }
    }

    Timer {
        interval: 1500
        running: root.visible
        repeat: true
        onTriggered: {
            if (!liveStatsProcess.running) liveStatsProcess.running = true
        }
    }

    // ============================================================
    // SLOW STATS PROCESS (Disk, Uptime, Identity - every 20s)
    // ============================================================

    Process {
        id: slowStatsProcess
        command: [
            "sh",
            "-c",
            [
                "df -B1 / | awk 'NR==2 { gsub(\"%\", \"\", $5); printf \"DISK %s %s %s\\n\", $3, $2, $5 }'; ",
                "printf 'USER %s\\n' \"$(whoami)\"; ",
                "printf 'HOST %s\\n' \"$(hostname)\"; ",
                "printf 'UPTIME %s\\n' \"$(uptime -p | sed 's/^up //')\"; ",
                "printf 'KERNEL %s\\n' \"$(uname -r)\"; ",
                "printf 'OS %s\\n' \"$(. /etc/os-release 2>/dev/null; printf '%s' \"${PRETTY_NAME:-Arch Linux}\")\""
            ].join("")
        ]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n")
                for (let i = 0; i < lines.length; ++i) {
                    const line = lines[i].trim()
                    const split = line.indexOf(" ")
                    if (split < 0) continue
                    const key = line.substring(0, split)
                    const value = line.substring(split + 1)

                    switch (key) {
                    case "DISK": {
                        const disk = value.split(/\s+/)
                        if (disk.length >= 3) {
                            root.diskUsed = root.formatBytes(Number(disk[0]))
                            root.diskTotal = root.formatBytes(Number(disk[1]))
                            root.diskUsage = root.clamp(Number(disk[2]), 0, 100)
                        }
                        break
                    }
                    case "USER": root.userName = value; break
                    case "HOST": root.hostName = value; break
                    case "UPTIME": root.uptime = value; break
                    case "KERNEL": root.kernel = value; break
                    case "OS": root.osName = value; break
                    }
                }
            }
        }
    }

    Timer {
        interval: 20000
        running: root.visible
        repeat: true
        onTriggered: {
            if (!slowStatsProcess.running) slowStatsProcess.running = true
        }
    }

    // ============================================================
    // MAIN LAYOUT
    // ============================================================

    RowLayout {
        anchors.fill: parent
        anchors.margins: Nexa.Theme.spacingMd
        spacing: Nexa.Theme.spacingMd

        // ========================================================
        // LEFT: 2x2 HARDWARE & PERFORMANCE GRID (56% width)
        // ========================================================

        ColumnLayout {
            Layout.fillWidth: true
            Layout.preferredWidth: 310
            Layout.fillHeight: true
            spacing: Nexa.Theme.spacingSm

            // Top Row: CPU Card & RAM Card
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Nexa.Theme.spacingSm

                // ------------------------------------------------
                // CPU CARD WITH SMOOTH BEZIER SPARKLINE
                // ------------------------------------------------
                NexaUI.NexaCard {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    interactive: true
                    onClicked: root.openMonitor()

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Nexa.Theme.spacingSm
                        spacing: 2

                        // Header: Title & Temp Pill
                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                text: "CPU"
                                color: Nexa.Theme.text
                                font.family: Nexa.Theme.fontFamily
                                font.pixelSize: Nexa.Theme.fontSizeSm
                                font.weight: Nexa.Theme.fontWeightDemiBold
                            }

                            Item { Layout.fillWidth: true }

                            // Thermals Badge
                            Rectangle {
                                implicitWidth: cpuTempRow.implicitWidth + 10
                                implicitHeight: 18
                                radius: 9
                                color: root.cpuTemp > 75 ? Qt.rgba(0.9, 0.2, 0.2, 0.2) : (root.cpuTemp > 58 ? Qt.rgba(0.9, 0.6, 0.1, 0.2) : Nexa.Theme.surfaceContainerHighest)

                                Row {
                                    id: cpuTempRow
                                    anchors.centerIn: parent
                                    spacing: 3
                                    Text {
                                        text: "󰍛"
                                        color: root.cpuTemp > 75 ? "#EF4444" : (root.cpuTemp > 58 ? "#F59E0B" : Nexa.Theme.primary)
                                        font.family: Nexa.Theme.iconFontFamily
                                        font.pixelSize: 11
                                    }
                                    Text {
                                        text: root.cpuTemp > 0 ? root.cpuTemp + "°C" : "--"
                                        color: Nexa.Theme.text
                                        font.family: Nexa.Theme.monoFontFamily
                                        font.pixelSize: Nexa.Theme.fontSize2Xs
                                        font.weight: Nexa.Theme.fontWeightMedium
                                    }
                                }
                            }
                        }

                        // Usage Percentage
                        Text {
                            text: Math.round(root.cpuUsage) + "%"
                            color: Nexa.Theme.primary
                            font.family: Nexa.Theme.monoFontFamily
                            font.pixelSize: 20
                            font.weight: Nexa.Theme.fontWeightBold
                        }

                        // Sparkline Canvas with Bezier Curve smoothing
                        Canvas {
                            id: cpuGraph
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            antialiasing: true

                            onPaint: {
                                const ctx = getContext("2d")
                                ctx.reset()
                                if (!root.cpuHistory || root.cpuHistory.length < 2) return

                                const data = root.cpuHistory
                                const step = width / (data.length - 1)

                                // Gradient Area Fill
                                ctx.beginPath()
                                ctx.moveTo(0, height * (1.0 - (data[0] / 100.0)))
                                for (let i = 0; i < data.length - 1; ++i) {
                                    const x0 = i * step
                                    const y0 = height * (1.0 - (data[i] / 100.0))
                                    const x1 = (i + 1) * step
                                    const y1 = height * (1.0 - (data[i + 1] / 100.0))
                                    const midX = (x0 + x1) / 2
                                    const midY = (y0 + y1) / 2
                                    ctx.quadraticCurveTo(x0, y0, midX, midY)
                                }
                                const lastX = (data.length - 1) * step
                                const lastY = height * (1.0 - (data[data.length - 1] / 100.0))
                                ctx.lineTo(lastX, lastY)
                                ctx.lineTo(width, height)
                                ctx.lineTo(0, height)
                                ctx.closePath()

                                const fill = ctx.createLinearGradient(0, 0, 0, height)
                                fill.addColorStop(0, Qt.rgba(Nexa.Theme.primary.r, Nexa.Theme.primary.g, Nexa.Theme.primary.b, 0.38))
                                fill.addColorStop(1, Qt.rgba(Nexa.Theme.primary.r, Nexa.Theme.primary.g, Nexa.Theme.primary.b, 0.02))
                                ctx.fillStyle = fill
                                ctx.fill()

                                // Line Stroke
                                ctx.beginPath()
                                ctx.moveTo(0, height * (1.0 - (data[0] / 100.0)))
                                for (let i = 0; i < data.length - 1; ++i) {
                                    const x0 = i * step
                                    const y0 = height * (1.0 - (data[i] / 100.0))
                                    const x1 = (i + 1) * step
                                    const y1 = height * (1.0 - (data[i + 1] / 100.0))
                                    const midX = (x0 + x1) / 2
                                    const midY = (y0 + y1) / 2
                                    ctx.quadraticCurveTo(x0, y0, midX, midY)
                                }
                                ctx.lineTo(lastX, lastY)
                                ctx.strokeStyle = Nexa.Theme.primary
                                ctx.lineWidth = 1.8
                                ctx.stroke()
                            }
                        }
                    }
                }

                // ------------------------------------------------
                // RAM CARD WITH LIVE BEZIER HISTORY
                // ------------------------------------------------
                NexaUI.NexaCard {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    interactive: true
                    onClicked: root.openMonitor()

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Nexa.Theme.spacingSm
                        spacing: 2

                        // Header: Title & Used Text
                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                text: "RAM"
                                color: Nexa.Theme.text
                                font.family: Nexa.Theme.fontFamily
                                font.pixelSize: Nexa.Theme.fontSizeSm
                                font.weight: Nexa.Theme.fontWeightDemiBold
                            }

                            Item { Layout.fillWidth: true }

                            Text {
                                text: root.ramUsed
                                color: Nexa.Theme.mutedText
                                font.family: Nexa.Theme.monoFontFamily
                                font.pixelSize: Nexa.Theme.fontSize2Xs
                            }
                        }

                        // Usage Percentage
                        Text {
                            text: Math.round(root.ramUsage) + "%"
                            color: Nexa.Theme.secondary
                            font.family: Nexa.Theme.monoFontFamily
                            font.pixelSize: 20
                            font.weight: Nexa.Theme.fontWeightBold
                        }

                        // Sparkline Canvas with Bezier Curve smoothing
                        Canvas {
                            id: ramGraph
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            antialiasing: true

                            onPaint: {
                                const ctx = getContext("2d")
                                ctx.reset()
                                if (!root.ramHistory || root.ramHistory.length < 2) return

                                const data = root.ramHistory
                                const step = width / (data.length - 1)

                                // Gradient Area Fill
                                ctx.beginPath()
                                ctx.moveTo(0, height * (1.0 - (data[0] / 100.0)))
                                for (let i = 0; i < data.length - 1; ++i) {
                                    const x0 = i * step
                                    const y0 = height * (1.0 - (data[i] / 100.0))
                                    const x1 = (i + 1) * step
                                    const y1 = height * (1.0 - (data[i + 1] / 100.0))
                                    const midX = (x0 + x1) / 2
                                    const midY = (y0 + y1) / 2
                                    ctx.quadraticCurveTo(x0, y0, midX, midY)
                                }
                                const lastX = (data.length - 1) * step
                                const lastY = height * (1.0 - (data[data.length - 1] / 100.0))
                                ctx.lineTo(lastX, lastY)
                                ctx.lineTo(width, height)
                                ctx.lineTo(0, height)
                                ctx.closePath()

                                const fill = ctx.createLinearGradient(0, 0, 0, height)
                                fill.addColorStop(0, Qt.rgba(Nexa.Theme.secondary.r, Nexa.Theme.secondary.g, Nexa.Theme.secondary.b, 0.38))
                                fill.addColorStop(1, Qt.rgba(Nexa.Theme.secondary.r, Nexa.Theme.secondary.g, Nexa.Theme.secondary.b, 0.02))
                                ctx.fillStyle = fill
                                ctx.fill()

                                // Line Stroke
                                ctx.beginPath()
                                ctx.moveTo(0, height * (1.0 - (data[0] / 100.0)))
                                for (let i = 0; i < data.length - 1; ++i) {
                                    const x0 = i * step
                                    const y0 = height * (1.0 - (data[i] / 100.0))
                                    const x1 = (i + 1) * step
                                    const y1 = height * (1.0 - (data[i + 1] / 100.0))
                                    const midX = (x0 + x1) / 2
                                    const midY = (y0 + y1) / 2
                                    ctx.quadraticCurveTo(x0, y0, midX, midY)
                                }
                                ctx.lineTo(lastX, lastY)
                                ctx.strokeStyle = Nexa.Theme.secondary
                                ctx.lineWidth = 1.8
                                ctx.stroke()
                            }
                        }
                    }
                }
            }

            // Bottom Row: GPU & Thermals Card + NVMe Storage Card
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Nexa.Theme.spacingSm

                // ------------------------------------------------
                // GPU & THERMALS CARD
                // ------------------------------------------------
                NexaUI.NexaCard {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Nexa.Theme.spacingSm
                        spacing: 4

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "GPU & Thermals"
                                color: Nexa.Theme.text
                                font.family: Nexa.Theme.fontFamily
                                font.pixelSize: Nexa.Theme.fontSizeSm
                                font.weight: Nexa.Theme.fontWeightDemiBold
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: "󰢮"
                                color: Nexa.Theme.primary
                                font.family: Nexa.Theme.iconFontFamily
                                font.pixelSize: Nexa.Theme.iconSm
                            }
                        }

                        // GPU Temp & Wattage Row
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Column {
                                spacing: 1
                                Text {
                                    text: "GPU Temp"
                                    color: Nexa.Theme.mutedText
                                    font.family: Nexa.Theme.fontFamily
                                    font.pixelSize: Nexa.Theme.fontSize2Xs
                                }
                                Text {
                                    text: root.gpuTemp > 0 ? root.gpuTemp + "°C" : "--"
                                    color: Nexa.Theme.text
                                    font.family: Nexa.Theme.monoFontFamily
                                    font.pixelSize: Nexa.Theme.fontSizeSm
                                    font.weight: Nexa.Theme.fontWeightBold
                                }
                            }

                            Rectangle {
                                width: 1
                                height: 20
                                color: Nexa.Theme.divider
                            }

                            Column {
                                spacing: 1
                                Text {
                                    text: "Power"
                                    color: Nexa.Theme.mutedText
                                    font.family: Nexa.Theme.fontFamily
                                    font.pixelSize: Nexa.Theme.fontSize2Xs
                                }
                                Text {
                                    text: root.gpuPower
                                    color: Nexa.Theme.text
                                    font.family: Nexa.Theme.monoFontFamily
                                    font.pixelSize: Nexa.Theme.fontSizeSm
                                    font.weight: Nexa.Theme.fontWeightBold
                                }
                            }

                            Rectangle {
                                width: 1
                                height: 20
                                color: Nexa.Theme.divider
                            }

                            Column {
                                spacing: 1
                                Text {
                                    text: "NVMe"
                                    color: Nexa.Theme.mutedText
                                    font.family: Nexa.Theme.fontFamily
                                    font.pixelSize: Nexa.Theme.fontSize2Xs
                                }
                                Text {
                                    text: root.nvmeTemp > 0 ? root.nvmeTemp + "°C" : "--"
                                    color: Nexa.Theme.text
                                    font.family: Nexa.Theme.monoFontFamily
                                    font.pixelSize: Nexa.Theme.fontSizeSm
                                    font.weight: Nexa.Theme.fontWeightBold
                                }
                            }
                        }
                    }
                }

                // ------------------------------------------------
                // NVME STORAGE CARD
                // ------------------------------------------------
                NexaUI.NexaCard {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Nexa.Theme.spacingSm
                        spacing: 4

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "Storage"
                                color: Nexa.Theme.text
                                font.family: Nexa.Theme.fontFamily
                                font.pixelSize: Nexa.Theme.fontSizeSm
                                font.weight: Nexa.Theme.fontWeightDemiBold
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: Math.round(root.diskUsage) + "%"
                                color: Nexa.Theme.primary
                                font.family: Nexa.Theme.monoFontFamily
                                font.pixelSize: Nexa.Theme.fontSizeXs
                                font.weight: Nexa.Theme.fontWeightBold
                            }
                        }

                        Text {
                            text: root.diskUsed + " / " + root.diskTotal
                            color: Nexa.Theme.mutedText
                            font.family: Nexa.Theme.monoFontFamily
                            font.pixelSize: Nexa.Theme.fontSize2Xs
                        }

                        // Storage Progress Bar
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 6
                            radius: 3
                            color: Nexa.Theme.surfaceContainerHighest

                            Rectangle {
                                height: parent.height
                                width: Math.max(6, parent.width * (root.diskUsage / 100.0))
                                radius: parent.radius
                                color: Nexa.Theme.primary
                            }
                        }
                    }
                }
            }
        }

        // ========================================================
        // RIGHT: MINI TASK MANAGER & SYSTEM UTILITIES (44% width)
        // ========================================================

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Nexa.Theme.spacingSm

            // ----------------------------------------------------
            // MINI TASK MANAGER CARD (Top Resource Consumers)
            // ----------------------------------------------------
            NexaUI.NexaCard {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Nexa.Theme.spacingSm
                    spacing: 4

                    // Tab Segmented Switcher (CPU vs RAM)
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Text {
                            text: "Processes"
                            color: Nexa.Theme.text
                            font.family: Nexa.Theme.fontFamily
                            font.pixelSize: Nexa.Theme.fontSizeSm
                            font.weight: Nexa.Theme.fontWeightDemiBold
                        }

                        Item { Layout.fillWidth: true }

                        Rectangle {
                            implicitWidth: 84
                            implicitHeight: 20
                            radius: 10
                            color: Nexa.Theme.surfaceContainerHighest

                            Row {
                                anchors.centerIn: parent
                                spacing: 2

                                // CPU Tab
                                Rectangle {
                                    width: 38
                                    height: 16
                                    radius: 8
                                    color: root.processTab === "cpu" ? Nexa.Theme.primary : "transparent"

                                    Text {
                                        anchors.centerIn: parent
                                        text: "CPU"
                                        color: root.processTab === "cpu" ? Nexa.Theme.onPrimary : Nexa.Theme.mutedText
                                        font.family: Nexa.Theme.fontFamily
                                        font.pixelSize: Nexa.Theme.fontSize2Xs
                                        font.weight: Nexa.Theme.fontWeightBold
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.processTab = "cpu"
                                    }
                                }

                                // RAM Tab
                                Rectangle {
                                    width: 38
                                    height: 16
                                    radius: 8
                                    color: root.processTab === "mem" ? Nexa.Theme.primary : "transparent"

                                    Text {
                                        anchors.centerIn: parent
                                        text: "RAM"
                                        color: root.processTab === "mem" ? Nexa.Theme.onPrimary : Nexa.Theme.mutedText
                                        font.family: Nexa.Theme.fontFamily
                                        font.pixelSize: Nexa.Theme.fontSize2Xs
                                        font.weight: Nexa.Theme.fontWeightBold
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.processTab = "mem"
                                    }
                                }
                            }
                        }
                    }

                    // Process Rows (Top 3)
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 2

                        Repeater {
                            model: root.processTab === "cpu" ? root.topCpuList : root.topMemList
                            delegate: Rectangle {
                                id: procRow
                                Layout.fillWidth: true
                                Layout.preferredHeight: 22
                                radius: 4
                                color: hoverHandler.hovered ? Nexa.Theme.hover : "transparent"

                                HoverHandler {
                                    id: hoverHandler
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 4
                                    anchors.rightMargin: 4
                                    spacing: 5

                                    // App Icon
                                    Text {
                                        text: root.appIcon(modelData.name)
                                        color: Nexa.Theme.primary
                                        font.family: Nexa.Theme.iconFontFamily
                                        font.pixelSize: 12
                                    }

                                    // Process Name
                                    Text {
                                        text: modelData.name || "--"
                                        color: Nexa.Theme.text
                                        font.family: Nexa.Theme.fontFamily
                                        font.pixelSize: Nexa.Theme.fontSizeXs
                                        font.weight: Nexa.Theme.fontWeightMedium
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                    }

                                    // Resource Usage Badge
                                    Rectangle {
                                        implicitWidth: usageText.implicitWidth + 6
                                        implicitHeight: 15
                                        radius: 3
                                        color: Nexa.Theme.surfaceContainerHighest

                                        Text {
                                            id: usageText
                                            anchors.centerIn: parent
                                            text: modelData.value || "--"
                                            color: root.processTab === "cpu" ? Nexa.Theme.primary : Nexa.Theme.secondary
                                            font.family: Nexa.Theme.monoFontFamily
                                            font.pixelSize: Nexa.Theme.fontSize2Xs
                                            font.weight: Nexa.Theme.fontWeightDemiBold
                                        }
                                    }

                                    // Kill Action Button
                                    Rectangle {
                                        id: killBtn
                                        implicitWidth: 16
                                        implicitHeight: 16
                                        radius: 8
                                        color: killMouse.containsMouse ? Qt.rgba(0.9, 0.2, 0.2, 0.35) : "transparent"
                                        visible: hoverHandler.hovered

                                        Text {
                                            anchors.centerIn: parent
                                            text: "󰅙"
                                            color: killMouse.containsMouse ? "#EF4444" : Nexa.Theme.mutedText
                                            font.family: Nexa.Theme.iconFontFamily
                                            font.pixelSize: 11
                                        }

                                        MouseArea {
                                            id: killMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                root.killProcess(modelData.pid)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ----------------------------------------------------
            // QUICK UTILITIES & SPECS FOOTER
            // ----------------------------------------------------
            NexaUI.NexaCard {
                Layout.fillWidth: true
                Layout.preferredHeight: 52
                clip: true

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Nexa.Theme.spacingSm
                    spacing: Nexa.Theme.spacingSm

                    // Monitor Launcher Button
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: Nexa.Theme.radiusSm
                        color: monMouse.containsMouse ? Nexa.Theme.primary : Nexa.Theme.surfaceContainerHighest

                        Row {
                            anchors.centerIn: parent
                            spacing: 5
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "󰌌"
                                color: monMouse.containsMouse ? Nexa.Theme.onPrimary : Nexa.Theme.primary
                                font.family: Nexa.Theme.iconFontFamily
                                font.pixelSize: Nexa.Theme.iconSm
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Monitor"
                                color: monMouse.containsMouse ? Nexa.Theme.onPrimary : Nexa.Theme.text
                                font.family: Nexa.Theme.fontFamily
                                font.pixelSize: Nexa.Theme.fontSizeXs
                                font.weight: Nexa.Theme.fontWeightMedium
                            }
                        }

                        MouseArea {
                            id: monMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.openMonitor()
                        }
                    }

                    // Trim Memory / Cache Button
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: Nexa.Theme.radiusSm
                        color: trimFeedbackTimer.running ? Qt.rgba(0.2, 0.8, 0.4, 0.25) : (trimMouse.containsMouse ? Nexa.Theme.primary : Nexa.Theme.surfaceContainerHighest)

                        Row {
                            anchors.centerIn: parent
                            spacing: 5
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: trimFeedbackTimer.running ? "󰄬" : "󰃮"
                                color: trimFeedbackTimer.running ? "#10B981" : (trimMouse.containsMouse ? Nexa.Theme.onPrimary : Nexa.Theme.secondary)
                                font.family: Nexa.Theme.iconFontFamily
                                font.pixelSize: Nexa.Theme.iconSm
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: trimFeedbackTimer.running ? "Trimmed!" : "Trim RAM"
                                color: trimFeedbackTimer.running ? "#10B981" : (trimMouse.containsMouse ? Nexa.Theme.onPrimary : Nexa.Theme.text)
                                font.family: Nexa.Theme.fontFamily
                                font.pixelSize: Nexa.Theme.fontSizeXs
                                font.weight: Nexa.Theme.fontWeightMedium
                            }
                        }

                        MouseArea {
                            id: trimMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.clearCache()
                        }
                    }
                }
            }

            // Host & Uptime Meta Bar
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Text {
                    text: "󰌢 " + root.hostName
                    color: Nexa.Theme.mutedText
                    font.family: Nexa.Theme.fontFamily
                    font.pixelSize: Nexa.Theme.fontSize2Xs
                }

                Text {
                    text: "•"
                    color: Nexa.Theme.divider
                    font.pixelSize: Nexa.Theme.fontSize2Xs
                }

                Text {
                    text: "up " + root.uptime
                    color: Nexa.Theme.mutedText
                    font.family: Nexa.Theme.fontFamily
                    font.pixelSize: Nexa.Theme.fontSize2Xs
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }
            }
        }
    }
}
