// pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../theme" as Nexa
import "../lockthemes/components"
import "../../theme/components" as NexaUI

Item {
    id: root

    anchors.fill: parent

    signal requestClose()

    function rad(n) {
        if (Nexa.Theme.nexaRounding === 0) return 0;
        return Math.max(0, Math.round(n * (Nexa.Theme.nexaRounding / 10.0)));
    }

    // ────────────────────────────────────────────────────────────
    // STATE & METRICS REPOSITORY
    // ────────────────────────────────────────────────────────────
    property real currentCpuPct: 0
    property real currentCpuTemp: 0
    property int currentCpuFreq: 0

    property real currentRamUsedMb: 0
    property real currentRamTotalMb: 1
    property real currentRamPct: 0

    property real currentSwapUsedMb: 0
    property real currentSwapTotalMb: 1
    property real currentSwapPct: 0

    property real currentDiskUsedGb: 0
    property real currentDiskTotalGb: 1
    property real currentDiskPct: 0

    property real currentNetRxKbps: 0
    property real currentNetTxKbps: 0

    property var topProcesses: []

    // 60-second rolling vectors from Rust engine
    property var cpuHistory: []
    property var ramHistory: []
    property var netRxHistory: []
    property var netTxHistory: []

    property bool isTrimSuccess: false

    readonly property string historyPath: Quickshell.env("HOME") + "/.cache/nexa/system-history.json"

    function parseTelemetry(content) {
        if (!content || content.length < 10) return;
        try {
            const data = JSON.parse(content);
            if (data.current) {
                const c = data.current;
                root.currentCpuPct = c.cpu_pct !== undefined ? c.cpu_pct : 0;
                root.currentCpuTemp = c.cpu_temp !== undefined ? c.cpu_temp : 0;
                root.currentCpuFreq = c.cpu_freq_mhz !== undefined ? c.cpu_freq_mhz : 0;

                root.currentRamUsedMb = c.ram_used_mb !== undefined ? c.ram_used_mb : 0;
                root.currentRamTotalMb = c.ram_total_mb !== undefined ? c.ram_total_mb : 1;
                root.currentRamPct = c.ram_pct !== undefined ? c.ram_pct : 0;

                root.currentSwapUsedMb = c.swap_used_mb !== undefined ? c.swap_used_mb : 0;
                root.currentSwapTotalMb = c.swap_total_mb !== undefined ? c.swap_total_mb : 1;
                root.currentSwapPct = c.swap_pct !== undefined ? c.swap_pct : 0;

                root.currentDiskUsedGb = c.disk_used_gb !== undefined ? c.disk_used_gb : 0;
                root.currentDiskTotalGb = c.disk_total_gb !== undefined ? c.disk_total_gb : 1;
                root.currentDiskPct = c.disk_pct !== undefined ? c.disk_pct : 0;

                root.currentNetRxKbps = c.net_rx_kbps !== undefined ? c.net_rx_kbps : 0;
                root.currentNetTxKbps = c.net_tx_kbps !== undefined ? c.net_tx_kbps : 0;

                root.topProcesses = c.top_processes || [];
            }

            if (data.cpu_history && Array.isArray(data.cpu_history)) {
                root.cpuHistory = data.cpu_history;
                cpuChartCanvas.requestPaint();
            }
            if (data.ram_history && Array.isArray(data.ram_history)) {
                root.ramHistory = data.ram_history;
                ramChartCanvas.requestPaint();
            }
            if (data.net_rx_history && Array.isArray(data.net_rx_history)) {
                root.netRxHistory = data.net_rx_history;
            }
            if (data.net_tx_history && Array.isArray(data.net_tx_history)) {
                root.netTxHistory = data.net_tx_history;
            }
        } catch (e) {
            // Wait for next file write
        }
    }

    FileView {
        id: historyFileView
        path: root.historyPath
        watchChanges: true

        onFileChanged: {
            historyFileView.reload();
            root.parseTelemetry(historyFileView.text());
        }

        onLoaded: {
            root.parseTelemetry(historyFileView.text());
        }
    }

    Timer {
        id: refreshTimer
        interval: 1000
        repeat: true
        running: root.visible
        onTriggered: {
            historyFileView.reload();
            root.parseTelemetry(historyFileView.text());
        }
    }

    Component.onCompleted: {
        historyFileView.reload();
        root.parseTelemetry(historyFileView.text());
    }

    function trimMemory() {
        Quickshell.execDetached([
            "sh",
            "-c",
            "sync; (echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true)"
        ]);
        root.isTrimSuccess = true;
        trimTimer.restart();
    }

    Timer {
        id: trimTimer
        interval: 2000
        repeat: false
        onTriggered: root.isTrimSuccess = false
    }

    function appIcon(name) {
        const n = String(name || "").toLowerCase();
        if (n.includes("chrome") || n.includes("chromium") || n.includes("brave")) return "󰊯";
        if (n.includes("firefox")) return "󰈹";
        if (n.includes("code") || n.includes("vsc")) return "󰨞";
        if (n.includes("spotify")) return "󰓇";
        if (n.includes("kitty") || n.includes("alacritty") || n.includes("bash") || n.includes("zsh")) return "󰆍";
        if (n.includes("quickshell")) return "󰘚";
        if (n.includes("hypr") || n.includes("waybar")) return "󰍹";
        if (n.includes("discord") || n.includes("vesktop")) return "󰙯";
        if (n.includes("steam")) return "󰓓";
        return "󰘳";
    }

    function killProcess(pid) {
        if (!pid) return;
        Quickshell.execDetached(["kill", "-9", String(pid)]);
        root.topProcesses = root.topProcesses.filter(p => String(p.pid) !== String(pid));
    }

    function formatNet(kbps) {
        if (kbps >= 1024) {
            return (kbps / 1024.0).toFixed(1) + " MB/s";
        }
        return kbps.toFixed(1) + " KB/s";
    }

    function formatRam(mb) {
        if (mb >= 1024) {
            return (mb / 1024.0).toFixed(1) + " GB";
        }
        return Math.round(mb) + " MB";
    }

    // ────────────────────────────────────────────────────────────
    // MAIN SCROLLABLE VIEW
    // ────────────────────────────────────────────────────────────
    Flickable {
        id: flickable
        anchors.fill: parent
        anchors.margins: 4
        clip: true
        contentWidth: width
        contentHeight: contentCol.implicitHeight + 48
        boundsBehavior: Flickable.StopAtBounds

        NexaUI.NexaSmoothScroll {}

        Column {
            id: contentCol
            width: parent.width - 24
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 16

            // ════════════════════════════════════════════════════════
            // 1. TOP METRICS HERO CARDS (4-Columns)
            // ════════════════════════════════════════════════════════
            RowLayout {
                width: parent.width
                spacing: 12

                // CARD 1: CPU
                Rectangle {
                    Layout.fillWidth: true
                    height: 104
                    radius: root.rad(14)
                    color: Nexa.Theme.cardBackground
                    border.width: Nexa.Theme.borderThin
                    border.color: Nexa.Theme.border

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 2

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Rectangle {
                                width: 28
                                height: 28
                                radius: root.rad(8)
                                color: Qt.rgba(Nexa.Theme.primary.r, Nexa.Theme.primary.g, Nexa.Theme.primary.b, 0.15)

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰍛"
                                    font.family: Nexa.Theme.iconFontFamily
                                    font.pixelSize: 16
                                    color: Nexa.Theme.primary
                                }
                            }

                            StyledText {
                                text: "CPU Load"
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                                color: Nexa.Theme.mutedText
                            }

                            Item { Layout.fillWidth: true }

                            StyledText {
                                text: root.currentCpuTemp > 0 ? (root.currentCpuTemp.toFixed(1) + " °C") : "--"
                                font.pixelSize: 11
                                font.weight: Font.Medium
                                color: root.currentCpuTemp > 75 ? Nexa.Theme.error : Nexa.Theme.mutedText
                            }
                        }

                        Item { Layout.fillHeight: true }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            StyledText {
                                text: root.currentCpuPct.toFixed(1) + "%"
                                font.pixelSize: 22
                                font.weight: Font.Bold
                                color: root.currentCpuPct > 80 ? Nexa.Theme.error : Nexa.Theme.text
                            }

                            Item { Layout.fillWidth: true }

                            StyledText {
                                text: root.currentCpuFreq > 0 ? ((root.currentCpuFreq / 1000.0).toFixed(2) + " GHz") : ""
                                font.pixelSize: 12
                                color: Nexa.Theme.mutedText
                            }
                        }
                    }
                }

                // CARD 2: RAM
                Rectangle {
                    Layout.fillWidth: true
                    height: 104
                    radius: root.rad(14)
                    color: Nexa.Theme.cardBackground
                    border.width: Nexa.Theme.borderThin
                    border.color: Nexa.Theme.border

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 2

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Rectangle {
                                width: 28
                                height: 28
                                radius: root.rad(8)
                                color: Qt.rgba(Nexa.Theme.secondary.r, Nexa.Theme.secondary.g, Nexa.Theme.secondary.b, 0.15)

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰘚"
                                    font.family: Nexa.Theme.iconFontFamily
                                    font.pixelSize: 16
                                    color: Nexa.Theme.secondary
                                }
                            }

                            StyledText {
                                text: "Memory"
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                                color: Nexa.Theme.mutedText
                            }

                            Item { Layout.fillWidth: true }

                            StyledText {
                                text: root.currentRamPct.toFixed(0) + "%"
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                                color: root.currentRamPct > 85 ? Nexa.Theme.error : Nexa.Theme.secondary
                            }
                        }

                        Item { Layout.fillHeight: true }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            StyledText {
                                text: root.formatRam(root.currentRamUsedMb)
                                font.pixelSize: 22
                                font.weight: Font.Bold
                                color: Nexa.Theme.text
                            }

                            StyledText {
                                text: "/ " + root.formatRam(root.currentRamTotalMb)
                                font.pixelSize: 12
                                color: Nexa.Theme.mutedText
                            }
                        }
                    }
                }

                // CARD 3: DISK
                Rectangle {
                    Layout.fillWidth: true
                    height: 104
                    radius: root.rad(14)
                    color: Nexa.Theme.cardBackground
                    border.width: Nexa.Theme.borderThin
                    border.color: Nexa.Theme.border

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 2

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Rectangle {
                                width: 28
                                height: 28
                                radius: root.rad(8)
                                color: Qt.rgba(Nexa.Theme.primary.r, Nexa.Theme.primary.g, Nexa.Theme.primary.b, 0.15)

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰋊"
                                    font.family: Nexa.Theme.iconFontFamily
                                    font.pixelSize: 16
                                    color: Nexa.Theme.primary
                                }
                            }

                            StyledText {
                                text: "System Disk"
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                                color: Nexa.Theme.mutedText
                            }

                            Item { Layout.fillWidth: true }

                            StyledText {
                                text: root.currentDiskPct.toFixed(0) + "%"
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                                color: Nexa.Theme.mutedText
                            }
                        }

                        Item { Layout.fillHeight: true }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            StyledText {
                                text: root.currentDiskUsedGb.toFixed(0) + " GB"
                                font.pixelSize: 22
                                font.weight: Font.Bold
                                color: Nexa.Theme.text
                            }

                            StyledText {
                                text: "/ " + root.currentDiskTotalGb.toFixed(0) + " GB"
                                font.pixelSize: 12
                                color: Nexa.Theme.mutedText
                            }
                        }
                    }
                }

                // CARD 4: NETWORK
                Rectangle {
                    Layout.fillWidth: true
                    height: 104
                    radius: root.rad(14)
                    color: Nexa.Theme.cardBackground
                    border.width: Nexa.Theme.borderThin
                    border.color: Nexa.Theme.border

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 2

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Rectangle {
                                width: 28
                                height: 28
                                radius: root.rad(8)
                                color: Qt.rgba(Nexa.Theme.tertiary ? Nexa.Theme.tertiary.r : Nexa.Theme.primary.r,
                                               Nexa.Theme.tertiary ? Nexa.Theme.tertiary.g : Nexa.Theme.primary.g,
                                               Nexa.Theme.tertiary ? Nexa.Theme.tertiary.b : Nexa.Theme.primary.b, 0.15)

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰖩"
                                    font.family: Nexa.Theme.iconFontFamily
                                    font.pixelSize: 16
                                    color: Nexa.Theme.tertiary || Nexa.Theme.primary
                                }
                            }

                            StyledText {
                                text: "Throughput"
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                                color: Nexa.Theme.mutedText
                            }
                        }

                        Item { Layout.fillHeight: true }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Text {
                                text: "󰕒"
                                font.family: Nexa.Theme.iconFontFamily
                                font.pixelSize: 13
                                color: Nexa.Theme.primary
                            }

                            StyledText {
                                text: root.formatNet(root.currentNetTxKbps)
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                color: Nexa.Theme.text
                            }

                            Item { Layout.fillWidth: true }

                            Text {
                                text: "󰇚"
                                font.family: Nexa.Theme.iconFontFamily
                                font.pixelSize: 13
                                color: Nexa.Theme.secondary
                            }

                            StyledText {
                                text: root.formatNet(root.currentNetRxKbps)
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                color: Nexa.Theme.text
                            }
                        }
                    }
                }
            }

            // ════════════════════════════════════════════════════════
            // 2. 60-SECOND HISTORICAL PERFORMANCE CHARTS
            // ════════════════════════════════════════════════════════
            RowLayout {
                width: parent.width
                spacing: 12

                // CPU HISTORICAL CHART CARD
                Rectangle {
                    Layout.fillWidth: true
                    height: 230
                    radius: root.rad(16)
                    color: Nexa.Theme.cardBackground
                    border.width: Nexa.Theme.borderThin
                    border.color: Nexa.Theme.border
                    clip: true

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 10

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                text: "󰍛"
                                font.family: Nexa.Theme.iconFontFamily
                                font.pixelSize: 17
                                color: Nexa.Theme.primary
                            }

                            StyledText {
                                text: "CPU Utilization History"
                                font.pixelSize: 14
                                font.weight: Font.Bold
                                color: Nexa.Theme.text
                            }

                            Item { Layout.fillWidth: true }

                            StyledText {
                                text: "Past 60 Seconds"
                                font.pixelSize: 11
                                color: Nexa.Theme.mutedText
                            }
                        }

                        // Canvas Timeline Plot
                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            // Gridlines (25%, 50%, 75%)
                            Rectangle { y: parent.height * 0.25; width: parent.width; height: 1; color: Nexa.Theme.divider; opacity: 0.3 }
                            Rectangle { y: parent.height * 0.50; width: parent.width; height: 1; color: Nexa.Theme.divider; opacity: 0.3 }
                            Rectangle { y: parent.height * 0.75; width: parent.width; height: 1; color: Nexa.Theme.divider; opacity: 0.3 }

                            Text { y: parent.height * 0.25 - 12; anchors.right: parent.right; text: "75%"; font.pixelSize: 9; color: Nexa.Theme.mutedText; opacity: 0.6 }
                            Text { y: parent.height * 0.50 - 12; anchors.right: parent.right; text: "50%"; font.pixelSize: 9; color: Nexa.Theme.mutedText; opacity: 0.6 }
                            Text { y: parent.height * 0.75 - 12; anchors.right: parent.right; text: "25%"; font.pixelSize: 9; color: Nexa.Theme.mutedText; opacity: 0.6 }

                            Canvas {
                                id: cpuChartCanvas
                                anchors.fill: parent
                                antialiasing: true

                                onPaint: {
                                    const ctx = getContext("2d");
                                    ctx.reset();
                                    const data = root.cpuHistory;
                                    if (!data || data.length < 2) return;

                                    const w = width;
                                    const h = height;
                                    const step = w / (data.length - 1);

                                    // 1. Fill Path (Gradient Area)
                                    ctx.beginPath();
                                    ctx.moveTo(0, h * (1.0 - Math.min(100, Math.max(0, data[0])) / 100.0));
                                    for (let i = 0; i < data.length - 1; ++i) {
                                        const x0 = i * step;
                                        const y0 = h * (1.0 - Math.min(100, Math.max(0, data[i])) / 100.0);
                                        const x1 = (i + 1) * step;
                                        const y1 = h * (1.0 - Math.min(100, Math.max(0, data[i + 1])) / 100.0);
                                        const midX = (x0 + x1) / 2;
                                        const midY = (y0 + y1) / 2;
                                        ctx.quadraticCurveTo(x0, y0, midX, midY);
                                    }
                                    const lastX = (data.length - 1) * step;
                                    const lastY = h * (1.0 - Math.min(100, Math.max(0, data[data.length - 1])) / 100.0);
                                    ctx.lineTo(lastX, lastY);
                                    ctx.lineTo(w, h);
                                    ctx.lineTo(0, h);
                                    ctx.closePath();

                                    const fillGrad = ctx.createLinearGradient(0, 0, 0, h);
                                    fillGrad.addColorStop(0, Qt.rgba(Nexa.Theme.primary.r, Nexa.Theme.primary.g, Nexa.Theme.primary.b, 0.35));
                                    fillGrad.addColorStop(1, Qt.rgba(Nexa.Theme.primary.r, Nexa.Theme.primary.g, Nexa.Theme.primary.b, 0.02));
                                    ctx.fillStyle = fillGrad;
                                    ctx.fill();

                                    // 2. Stroke Path (Sharp Bezier Line)
                                    ctx.beginPath();
                                    ctx.moveTo(0, h * (1.0 - Math.min(100, Math.max(0, data[0])) / 100.0));
                                    for (let i = 0; i < data.length - 1; ++i) {
                                        const x0 = i * step;
                                        const y0 = h * (1.0 - Math.min(100, Math.max(0, data[i])) / 100.0);
                                        const x1 = (i + 1) * step;
                                        const y1 = h * (1.0 - Math.min(100, Math.max(0, data[i + 1])) / 100.0);
                                        const midX = (x0 + x1) / 2;
                                        const midY = (y0 + y1) / 2;
                                        ctx.quadraticCurveTo(x0, y0, midX, midY);
                                    }
                                    ctx.lineTo(lastX, lastY);
                                    ctx.lineWidth = 2.0;
                                    ctx.strokeStyle = Nexa.Theme.primary;
                                    ctx.stroke();
                                }
                            }
                        }
                    }
                }

                // RAM HISTORICAL CHART CARD
                Rectangle {
                    Layout.fillWidth: true
                    height: 230
                    radius: root.rad(16)
                    color: Nexa.Theme.cardBackground
                    border.width: Nexa.Theme.borderThin
                    border.color: Nexa.Theme.border
                    clip: true

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 10

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                text: "󰘚"
                                font.family: Nexa.Theme.iconFontFamily
                                font.pixelSize: 17
                                color: Nexa.Theme.secondary
                            }

                            StyledText {
                                text: "Memory History"
                                font.pixelSize: 14
                                font.weight: Font.Bold
                                color: Nexa.Theme.text
                            }

                            Item { Layout.fillWidth: true }

                            StyledText {
                                text: "Past 60 Seconds"
                                font.pixelSize: 11
                                color: Nexa.Theme.mutedText
                            }
                        }

                        // Canvas Timeline Plot
                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            // Gridlines (25%, 50%, 75%)
                            Rectangle { y: parent.height * 0.25; width: parent.width; height: 1; color: Nexa.Theme.divider; opacity: 0.3 }
                            Rectangle { y: parent.height * 0.50; width: parent.width; height: 1; color: Nexa.Theme.divider; opacity: 0.3 }
                            Rectangle { y: parent.height * 0.75; width: parent.width; height: 1; color: Nexa.Theme.divider; opacity: 0.3 }

                            Text { y: parent.height * 0.25 - 12; anchors.right: parent.right; text: "75%"; font.pixelSize: 9; color: Nexa.Theme.mutedText; opacity: 0.6 }
                            Text { y: parent.height * 0.50 - 12; anchors.right: parent.right; text: "50%"; font.pixelSize: 9; color: Nexa.Theme.mutedText; opacity: 0.6 }
                            Text { y: parent.height * 0.75 - 12; anchors.right: parent.right; text: "25%"; font.pixelSize: 9; color: Nexa.Theme.mutedText; opacity: 0.6 }

                            Canvas {
                                id: ramChartCanvas
                                anchors.fill: parent
                                antialiasing: true

                                onPaint: {
                                    const ctx = getContext("2d");
                                    ctx.reset();
                                    const data = root.ramHistory;
                                    if (!data || data.length < 2) return;

                                    const w = width;
                                    const h = height;
                                    const step = w / (data.length - 1);

                                    // 1. Fill Path (Gradient Area)
                                    ctx.beginPath();
                                    ctx.moveTo(0, h * (1.0 - Math.min(100, Math.max(0, data[0])) / 100.0));
                                    for (let i = 0; i < data.length - 1; ++i) {
                                        const x0 = i * step;
                                        const y0 = h * (1.0 - Math.min(100, Math.max(0, data[i])) / 100.0);
                                        const x1 = (i + 1) * step;
                                        const y1 = h * (1.0 - Math.min(100, Math.max(0, data[i + 1])) / 100.0);
                                        const midX = (x0 + x1) / 2;
                                        const midY = (y0 + y1) / 2;
                                        ctx.quadraticCurveTo(x0, y0, midX, midY);
                                    }
                                    const lastX = (data.length - 1) * step;
                                    const lastY = h * (1.0 - Math.min(100, Math.max(0, data[data.length - 1])) / 100.0);
                                    ctx.lineTo(lastX, lastY);
                                    ctx.lineTo(w, h);
                                    ctx.lineTo(0, h);
                                    ctx.closePath();

                                    const fillGrad = ctx.createLinearGradient(0, 0, 0, h);
                                    fillGrad.addColorStop(0, Qt.rgba(Nexa.Theme.secondary.r, Nexa.Theme.secondary.g, Nexa.Theme.secondary.b, 0.35));
                                    fillGrad.addColorStop(1, Qt.rgba(Nexa.Theme.secondary.r, Nexa.Theme.secondary.g, Nexa.Theme.secondary.b, 0.02));
                                    ctx.fillStyle = fillGrad;
                                    ctx.fill();

                                    // 2. Stroke Path (Sharp Bezier Line)
                                    ctx.beginPath();
                                    ctx.moveTo(0, h * (1.0 - Math.min(100, Math.max(0, data[0])) / 100.0));
                                    for (let i = 0; i < data.length - 1; ++i) {
                                        const x0 = i * step;
                                        const y0 = h * (1.0 - Math.min(100, Math.max(0, data[i])) / 100.0);
                                        const x1 = (i + 1) * step;
                                        const y1 = h * (1.0 - Math.min(100, Math.max(0, data[i + 1])) / 100.0);
                                        const midX = (x0 + x1) / 2;
                                        const midY = (y0 + y1) / 2;
                                        ctx.quadraticCurveTo(x0, y0, midX, midY);
                                    }
                                    ctx.lineTo(lastX, lastY);
                                    ctx.lineWidth = 2.0;
                                    ctx.strokeStyle = Nexa.Theme.secondary;
                                    ctx.stroke();
                                }
                            }
                        }
                    }
                }
            }

            // ════════════════════════════════════════════════════════
            // 3. TOP PROCESSES & DIAGNOSTICS CARD
            // ════════════════════════════════════════════════════════
            Rectangle {
                width: parent.width
                implicitHeight: procCol.implicitHeight + 32
                radius: root.rad(16)
                color: Nexa.Theme.cardBackground
                border.width: Nexa.Theme.borderThin
                border.color: Nexa.Theme.border

                Column {
                    id: procCol
                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                        margins: 16
                    }
                    spacing: 12

                    // Header & Quick Utilities
                    RowLayout {
                        width: parent.width
                        spacing: 8

                        Text {
                            text: "󰆍"
                            font.family: Nexa.Theme.iconFontFamily
                            font.pixelSize: 18
                            color: Nexa.Theme.primary
                        }

                        StyledText {
                            text: "Active Top Processes"
                            font.pixelSize: 15
                            font.weight: Font.Bold
                            color: Nexa.Theme.text
                        }

                        Item { Layout.fillWidth: true }

                        // Trim RAM Button
                        ClickableRect {
                            width: trimRow.implicitWidth + 24
                            height: 32
                            radius: root.rad(8)
                            color: root.isTrimSuccess ? Nexa.Theme.primaryContainer : Nexa.Theme.surfaceContainerHigh
                            border.width: 1
                            border.color: root.isTrimSuccess ? Nexa.Theme.primary : Nexa.Theme.border
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.trimMemory()

                            Row {
                                id: trimRow
                                anchors.centerIn: parent
                                spacing: 6

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: root.isTrimSuccess ? "󰄬" : "󰃢"
                                    font.family: Nexa.Theme.iconFontFamily
                                    font.pixelSize: 13
                                    color: root.isTrimSuccess ? Nexa.Theme.onPrimaryContainer : Nexa.Theme.text
                                }

                                StyledText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: root.isTrimSuccess ? "Trimmed!" : "Trim Cache"
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                    color: root.isTrimSuccess ? Nexa.Theme.onPrimaryContainer : Nexa.Theme.text
                                }
                            }
                        }
                    }

                    // Process Table Header (Symmetrical Columns)
                    Item {
                        width: parent.width
                        height: 28

                        Row {
                            anchors.fill: parent

                            // Col 1: PID
                            Item {
                                width: 80
                                height: parent.height
                                StyledText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    anchors.leftMargin: 8
                                    text: "PID"
                                    font.pixelSize: 11
                                    font.weight: Font.Bold
                                    color: Nexa.Theme.mutedText
                                }
                            }

                            // Col 2: Process Name
                            Item {
                                width: parent.width - 80 - 100 - 100 - 48
                                height: parent.height
                                StyledText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    anchors.leftMargin: 8
                                    text: "Process Name"
                                    font.pixelSize: 11
                                    font.weight: Font.Bold
                                    color: Nexa.Theme.mutedText
                                }
                            }

                            // Col 3: CPU %
                            Item {
                                width: 100
                                height: parent.height
                                StyledText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.right: parent.right
                                    anchors.rightMargin: 12
                                    text: "CPU %"
                                    font.pixelSize: 11
                                    font.weight: Font.Bold
                                    color: Nexa.Theme.mutedText
                                }
                            }

                            // Col 4: RAM %
                            Item {
                                width: 100
                                height: parent.height
                                StyledText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.right: parent.right
                                    anchors.rightMargin: 12
                                    text: "RAM %"
                                    font.pixelSize: 11
                                    font.weight: Font.Bold
                                    color: Nexa.Theme.mutedText
                                }
                            }

                            // Col 5: Action Spacer
                            Item {
                                width: 48
                                height: parent.height
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Nexa.Theme.divider
                        opacity: 0.5
                    }

                    // Process Repeater (Pixel-perfect Symmetrical Rows)
                    Repeater {
                        model: root.topProcesses

                        delegate: Rectangle {
                            required property var modelData
                            width: parent.width
                            height: 38
                            radius: root.rad(6)
                            color: pMouse.containsMouse ? Nexa.Theme.surfaceContainerHighest : "transparent"

                            Row {
                                anchors.fill: parent

                                // Col 1: PID
                                Item {
                                    width: 80
                                    height: parent.height
                                    StyledText {
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.left: parent.left
                                        anchors.leftMargin: 8
                                        text: String(modelData.pid)
                                        font.family: Nexa.Theme.monoFontFamily
                                        font.pixelSize: 11
                                        color: Nexa.Theme.mutedText
                                    }
                                }

                                // Col 2: Process Name
                                Item {
                                    width: parent.width - 80 - 100 - 100 - 48
                                    height: parent.height

                                    Row {
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.left: parent.left
                                        anchors.leftMargin: 8
                                        anchors.right: parent.right
                                        anchors.rightMargin: 8
                                        spacing: 8

                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: root.appIcon(modelData.name)
                                            font.family: Nexa.Theme.iconFontFamily
                                            font.pixelSize: 15
                                            color: Nexa.Theme.primary
                                        }

                                        StyledText {
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: parent.width - 24
                                            text: String(modelData.name)
                                            font.pixelSize: 12
                                            font.weight: Font.Medium
                                            color: Nexa.Theme.text
                                            elide: Text.ElideRight
                                        }
                                    }
                                }

                                // Col 3: CPU %
                                Item {
                                    width: 100
                                    height: parent.height
                                    StyledText {
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.right: parent.right
                                        anchors.rightMargin: 12
                                        text: Number(modelData.cpu_pct).toFixed(1) + "%"
                                        font.family: Nexa.Theme.monoFontFamily
                                        font.pixelSize: 11
                                        font.weight: Font.DemiBold
                                        color: Number(modelData.cpu_pct) > 20 ? Nexa.Theme.error : Nexa.Theme.text
                                    }
                                }

                                // Col 4: RAM %
                                Item {
                                    width: 100
                                    height: parent.height
                                    StyledText {
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.right: parent.right
                                        anchors.rightMargin: 12
                                        text: Number(modelData.mem_pct).toFixed(1) + "%"
                                        font.family: Nexa.Theme.monoFontFamily
                                        font.pixelSize: 11
                                        color: Nexa.Theme.mutedText
                                    }
                                }

                                // Col 5: Kill Action
                                Item {
                                    width: 48
                                    height: parent.height

                                    ClickableRect {
                                        anchors.centerIn: parent
                                        width: 26
                                        height: 26
                                        radius: root.rad(6)
                                        color: killMouse.hovered ? Qt.rgba(1, 0, 0, 0.18) : "transparent"
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.killProcess(modelData.pid)

                                        Text {
                                            id: killMouse
                                            property bool hovered: false
                                            anchors.centerIn: parent
                                            text: "󰅙"
                                            font.family: Nexa.Theme.iconFontFamily
                                            font.pixelSize: 15
                                            color: killMouse.hovered ? Nexa.Theme.error : Nexa.Theme.mutedText
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onEntered: killMouse.hovered = true
                                            onExited: killMouse.hovered = false
                                            onClicked: root.killProcess(modelData.pid)
                                        }
                                    }
                                }
                            }

                            MouseArea {
                                id: pMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.NoButton
                            }
                        }
                    }
                }
            }
        }
    }
}

