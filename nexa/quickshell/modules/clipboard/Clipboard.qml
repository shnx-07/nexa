import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Quickshell
import Quickshell.Io

import "../../NewNexaUI" as NexaUI


PanelWindow {
    id: root

    // ============================================================
    // WINDOW CONFIGURATION
    // ============================================================

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    exclusionMode: ExclusionMode.Ignore
    aboveWindows: true
    focusable: true
    color: "transparent"

    visible: windowAlive

    property bool windowAlive: false
    property bool clipboardOpen: false
    property bool loading: false

    property bool confirmClear: false
    property bool confirmDelete: false

    // ============================================================
    // DATA & FILTER STATE
    // ============================================================

    property var entries: []
    property var selectedEntry: null

    property string selectedContent: ""
    property int selectedSize: 0
    property string selectedType: ""
    property string selectedImageSource: ""

    // Category filter: "all" | "text" | "image" | "link" | "code" | "pinned"
    property string activeFilter: "all"

    // Toast notification state
    property string toastText: ""
    property bool toastVisible: false

    // ============================================================
    // BACKEND PATH
    // ============================================================

    readonly property string nexadPath:
        Quickshell.env("HOME")
        + "/.config/nexa/rust/target/release/nexad"

    // ============================================================
    // DIMENSIONS
    // ============================================================

    readonly property int panelWidth: 920
    readonly property int panelHeight: 640
    readonly property int leftWidth: 350
    readonly property int outerPadding: 16

    // ============================================================
    // CONTENT CLASSIFICATION & FORMATTING HELPERS
    // ============================================================

    function formatBytes(bytes) {
        if (!bytes || bytes <= 0) return "0 B"
        if (bytes < 1024) return bytes + " B"
        if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + " KB"
        return (bytes / (1024 * 1024)).toFixed(1) + " MB"
    }

    function isLink(text) {
        if (!text) return false
        const t = String(text).trim()
        return t.startsWith("http://") || t.startsWith("https://") || t.startsWith("file://")
    }

    function isCode(text) {
        if (!text) return false
        const t = String(text).trim()
        if (isLink(t)) return false
        return t.startsWith("#!/") || t.startsWith("git ") || t.startsWith("cargo ") ||
               t.startsWith("sudo ") || t.startsWith("pacman ") || t.startsWith("npm ") ||
               t.startsWith("const ") || t.startsWith("let ") || t.startsWith("var ") ||
               t.startsWith("function ") || t.startsWith("fn ") || t.startsWith("def ") ||
               t.startsWith("class ") || t.startsWith("import ") || t.startsWith("#include") ||
               t.startsWith("<?php") || t.startsWith("<!DOCTYPE") ||
               t.startsWith("{") || t.startsWith("[") ||
               t.includes(";\n") || t.includes("{\n") || t.includes("}\n")
    }

    function getItemCategory(entry) {
        if (!entry) return "text"
        if (entry.type === "image") return "image"
        const preview = entry.preview || ""
        if (isLink(preview)) return "link"
        if (isCode(preview)) return "code"
        return "text"
    }

    function getCategoryIcon(category) {
        switch (category) {
            case "image": return "󰋩"
            case "link":  return "󰌹"
            case "code":  return "󰘳"
            default:      return "󰅇"
        }
    }

    function getCategoryColor(category) {
        switch (category) {
            case "image": return NexaUI.NexaColors.tertiary
            case "link":  return NexaUI.NexaColors.secondary
            case "code":  return NexaUI.NexaColors.success
            default:      return NexaUI.NexaColors.primary
        }
    }

    function getCategoryLabel(category) {
        switch (category) {
            case "image": return "IMAGE"
            case "link":  return "LINK"
            case "code":  return "CODE"
            default:      return "TEXT"
        }
    }

    // Filtered entries according to active tab
    readonly property var currentList: {
        if (!entries || entries.length === 0) return []
        if (activeFilter === "all") return entries
        if (activeFilter === "pinned") return entries.filter(e => e.pinned === true)
        if (activeFilter === "image") return entries.filter(e => e.type === "image")
        if (activeFilter === "link") return entries.filter(e => getItemCategory(e) === "link")
        if (activeFilter === "code") return entries.filter(e => getItemCategory(e) === "code")
        if (activeFilter === "text") return entries.filter(e => getItemCategory(e) === "text")
        return entries
    }

    // Category counts for filter tabs
    readonly property int countAll: entries ? entries.length : 0
    readonly property int countPinned: entries ? entries.filter(e => e.pinned === true).length : 0
    readonly property int countImages: entries ? entries.filter(e => e.type === "image").length : 0
    readonly property int countLinks: entries ? entries.filter(e => getItemCategory(e) === "link").length : 0

    // Text stats for preview
    readonly property int textCharCount: selectedContent ? selectedContent.length : 0
    readonly property int textLineCount: selectedContent ? selectedContent.split("\n").length : 0
    readonly property int textWordCount: {
        if (!selectedContent || selectedContent.trim().length === 0) return 0
        return selectedContent.trim().split(/\s+/).length
    }

    // ============================================================
    // TOAST FEEDBACK
    // ============================================================

    function triggerToast(message) {
        toastText = message
        toastVisible = true
        toastTimer.restart()
    }

    Timer {
        id: toastTimer
        interval: 1300
        repeat: false
        onTriggered: root.toastVisible = false
    }

    Timer {
        id: autoCloseTimer
        interval: 140
        repeat: false
        onTriggered: root.closeClipboard()
    }

    // ============================================================
    // SELECTION & ACTIONS
    // ============================================================

    function selectEntry(entry) {
        if (!entry || !entry.id) return

        selectedEntry = entry
        selectedContent = ""
        selectedImageSource = ""
        selectedType = entry.type || "text"
        selectedSize = entry.size_bytes || 0

        getProcess.exec([
            nexadPath,
            "clipboard",
            "get",
            entry.id
        ])
    }

    function refresh() {
        requestSearch(searchInput.text)
    }

    function requestSearch(query) {
        const trimmed = query.trim()
        loading = true

        if (trimmed.length === 0) {
            listProcess.exec([
                nexadPath,
                "clipboard",
                "list"
            ])
            return
        }

        searchProcess.exec([
            nexadPath,
            "clipboard",
            "search",
            trimmed
        ])
    }

    function copySelected(autoClose = false) {
        if (!selectedEntry) return

        copyProcess.exec([
            nexadPath,
            "clipboard",
            "copy",
            selectedEntry.id
        ])

        triggerToast("Copied to clipboard!")

        if (autoClose) {
            autoCloseTimer.restart()
        }
    }

    function moveSelection(delta) {
        const list = currentList
        if (!list || list.length === 0) return

        let currentIndex = -1
        if (selectedEntry && selectedEntry.id) {
            for (let i = 0; i < list.length; i++) {
                if (list[i].id === selectedEntry.id) {
                    currentIndex = i
                    break
                }
            }
        }

        let nextIndex = currentIndex + delta
        if (nextIndex < 0) nextIndex = 0
        if (nextIndex >= list.length) nextIndex = list.length - 1

        if (nextIndex !== currentIndex && list[nextIndex]) {
            selectEntry(list[nextIndex])
            historyList.positionViewAtIndex(nextIndex, ListView.Beginning)
        }
    }

    function togglePinSelected(target = null) {
        const item = target || selectedEntry
        if (!item || !item.id) return

        const willPin = !item.pinned
        const command = willPin ? "pin" : "unpin"

        // Optimistically update in entries
        for (let i = 0; i < entries.length; i++) {
            if (entries[i].id === item.id) {
                entries[i].pinned = willPin
                break
            }
        }
        item.pinned = willPin
        if (selectedEntry && selectedEntry.id === item.id) {
            selectedEntry.pinned = willPin
            selectedEntryChanged()
        }

        triggerToast(willPin ? "Pinned clip" : "Unpinned clip")

        pinProcess.exec([
            nexadPath,
            "clipboard",
            command,
            String(item.id)
        ])
    }

    function deleteSelected() {
        if (!selectedEntry) return

        deleteProcess.exec([
            nexadPath,
            "clipboard",
            "delete",
            selectedEntry.id
        ])
    }

    function clearHistory() {
        clearProcess.exec([
            nexadPath,
            "clipboard",
            "clear"
        ])
    }

    function openSelectedUrl() {
        if (!selectedContent) return
        const url = selectedContent.trim()
        if (url.startsWith("http://") || url.startsWith("https://") || url.startsWith("file://")) {
            Qt.openUrlExternally(url)
            root.closeClipboard()
        }
    }

    // ============================================================
    // OPEN / CLOSE LIFECYCLE
    // ============================================================

    function openClipboard() {
        closeTimer.stop()
        autoCloseTimer.stop()

        if (!windowAlive)
            windowAlive = true

        Qt.callLater(function() {
            clipboardOpen = true
            confirmClear = false
            confirmDelete = false
            toastVisible = false
            activeFilter = "all"

            selectedEntry = null
            selectedContent = ""
            selectedImageSource = ""
            selectedType = ""
            selectedSize = 0

            searchInput.text = ""
            requestSearch("")
            searchInput.forceActiveFocus()
        })
    }

    function closeClipboard() {
        if (!windowAlive) return

        clipboardOpen = false
        confirmClear = false
        confirmDelete = false
        toastVisible = false

        closeTimer.restart()
    }

    function toggleClipboard() {
        if (clipboardOpen)
            closeClipboard()
        else
            openClipboard()
    }

    // ============================================================
    // PROCESSES
    // ============================================================

    Process {
        id: listProcess
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const payload = JSON.parse(this.text)
                    const targetId = root.selectedEntry ? root.selectedEntry.id : null
                    root.entries = payload || []

                    let reselected = null
                    if (targetId) {
                        for (let i = 0; i < root.currentList.length; i++) {
                            if (root.currentList[i].id === targetId) {
                                reselected = root.currentList[i]
                                break
                            }
                        }
                    }

                    if (reselected) {
                        root.selectEntry(reselected)
                    } else if (root.currentList.length > 0) {
                        historyList.positionViewAtBeginning()
                        root.selectEntry(root.currentList[0])
                    } else {
                        root.selectedEntry = null
                        root.selectedContent = ""
                        root.selectedImageSource = ""
                        root.selectedType = ""
                        root.selectedSize = 0
                    }
                } catch (error) {
                    console.error("[Clipboard:list]", error)
                    root.entries = []
                }
                root.loading = false
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                const value = this.text.trim()
                if (value.length > 0) console.error("[Clipboard:list]", value)
            }
        }
    }

    Process {
        id: searchProcess
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const payload = JSON.parse(this.text)
                    const targetId = root.selectedEntry ? root.selectedEntry.id : null
                    root.entries = payload || []

                    let reselected = null
                    if (targetId) {
                        for (let i = 0; i < root.currentList.length; i++) {
                            if (root.currentList[i].id === targetId) {
                                reselected = root.currentList[i]
                                break
                            }
                        }
                    }

                    if (reselected) {
                        root.selectEntry(reselected)
                    } else if (root.currentList.length > 0) {
                        historyList.positionViewAtBeginning()
                        root.selectEntry(root.currentList[0])
                    } else {
                        root.selectedEntry = null
                        root.selectedContent = ""
                        root.selectedImageSource = ""
                        root.selectedType = ""
                        root.selectedSize = 0
                    }
                } catch (error) {
                    console.error("[Clipboard:search]", error)
                    root.entries = []
                }
                root.loading = false
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                const value = this.text.trim()
                if (value.length > 0) console.error("[Clipboard:search]", value)
            }
        }
    }

    Process {
        id: getProcess
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const payload = JSON.parse(this.text)
                    root.selectedType = payload.type || "text"
                    root.selectedSize = payload.size_bytes || 0

                    if (root.selectedType === "image") {
                        root.selectedContent = ""
                        root.selectedImageSource = payload.source || ""
                    } else {
                        root.selectedImageSource = ""
                        root.selectedContent = payload.content || ""
                    }
                } catch (error) {
                    console.error("[Clipboard:get]", error)
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                const value = this.text.trim()
                if (value.length > 0) console.error("[Clipboard:get]", value)
            }
        }
    }

    Process {
        id: copyProcess
        stderr: StdioCollector {
            onStreamFinished: {
                const value = this.text.trim()
                if (value.length > 0) console.error("[Clipboard:copy]", value)
            }
        }
    }

    Process {
        id: pinProcess
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    JSON.parse(this.text)
                    root.refresh()
                } catch (error) {
                    console.error("[Clipboard:pin]", error)
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                const value = this.text.trim()
                if (value.length > 0) console.error("[Clipboard:pin]", value)
            }
        }
    }

    Process {
        id: deleteProcess
        stdout: StdioCollector {
            onStreamFinished: {
                root.confirmDelete = false
                root.selectedEntry = null
                root.selectedContent = ""
                root.selectedImageSource = ""
                root.selectedType = ""
                root.selectedSize = 0
                root.refresh()
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                const value = this.text.trim()
                if (value.length > 0) console.error("[Clipboard:delete]", value)
            }
        }
    }

    Process {
        id: clearProcess
        stdout: StdioCollector {
            onStreamFinished: {
                root.confirmClear = false
                root.entries = []
                root.selectedEntry = null
                root.selectedContent = ""
                root.selectedImageSource = ""
                root.selectedType = ""
                root.selectedSize = 0
                searchInput.text = ""
                triggerToast("Clipboard cleared")
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                const value = this.text.trim()
                if (value.length > 0) console.error("[Clipboard:clear]", value)
            }
        }
    }

    // ============================================================
    // TIMERS
    // ============================================================

    Timer {
        id: searchDebounce
        interval: 100
        repeat: false
        onTriggered: root.requestSearch(searchInput.text)
    }

    Timer {
        id: closeTimer
        interval: NexaUI.NexaMotion.durationFast
        repeat: false
        onTriggered: {
            root.windowAlive = false
            root.entries = []
            root.selectedEntry = null
            root.selectedContent = ""
            root.selectedImageSource = ""
            root.selectedType = ""
            root.selectedSize = 0
            root.loading = false
            searchInput.text = ""
        }
    }

    // ============================================================
    // ROOT OVERLAY & ENTRANCE ANIMATION
    // ============================================================

    Item {
        anchors.fill: parent

        opacity: root.clipboardOpen ? 1.0 : 0.0
        scale: root.clipboardOpen ? 1.0 : 0.97

        Behavior on opacity {
            NumberAnimation {
                duration: root.clipboardOpen ? NexaUI.NexaMotion.durationNormal : NexaUI.NexaMotion.durationFast
                easing.type: root.clipboardOpen ? NexaUI.NexaMotion.standardEasing : NexaUI.NexaMotion.exitEasing
            }
        }

        Behavior on scale {
            enabled: NexaUI.NexaMotion.enabled
            SpringAnimation {
                spring: NexaUI.NexaMotion.useSpring("clipboard") ? NexaUI.NexaMotion.springStiffness : 8.0
                damping: NexaUI.NexaMotion.useSpring("clipboard") ? NexaUI.NexaMotion.springDamping : 1.0
                mass: NexaUI.NexaMotion.springMass
                epsilon: 0.002
            }
        }

        // Click outside closes clipboard
        MouseArea {
            anchors.fill: parent
            onClicked: root.closeClipboard()
        }

        // ========================================================
        // MAIN DIALOG PANEL
        // ========================================================

        // Nexa Drop Shadow for floating depth
        NexaUI.NexaShadow {
            id: panelShadow
            targetItem: panel
            elevation: 2
            spread: 0.10
        }

        Rectangle {
            id: panel

            anchors.centerIn: parent
            width: Math.min(root.panelWidth, parent.width - 40)
            height: Math.min(root.panelHeight, parent.height - 60)

            radius: NexaUI.NexaTokens.nexaRounding
            color: NexaUI.NexaColors.surfaceContainer
            border.width: NexaUI.NexaTokens.borderThin
            border.color: NexaUI.NexaColors.border

            clip: true

            NexaUI.NexaShaderSubstrate {
                anchors.fill: parent
                radius: parent.radius
            }

            // Stop click propagating to backdrop
            MouseArea {
                anchors.fill: parent
            }

            // Tactile 4-stop OLED Depth Micro-Gradient
            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                antialiasing: parent.radius > 0
                visible: NexaUI.NexaOptics.surface3DGradient && NexaUI.NexaOptics.gradientIntensity > 0.01
                opacity: NexaUI.NexaOptics.gradientIntensity
                gradient: Gradient {
                    GradientStop { position: 0.00; color: Qt.rgba(1, 1, 1, 0.055) }
                    GradientStop { position: 0.40; color: Qt.rgba(1, 1, 1, 0.012) }
                    GradientStop { position: 0.75; color: Qt.rgba(0, 0, 0, 0.000) }
                    GradientStop { position: 1.00; color: Qt.rgba(0, 0, 0, 0.120) }
                }
            }

            // Top Chamfer Specular Highlight
            Rectangle {
                anchors.top: parent.top
                anchors.topMargin: 1
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.radius > 0 ? Math.max(0, parent.width - parent.radius * 1.6) : parent.width
                height: 1
                visible: NexaUI.NexaOptics.specularHighlight && NexaUI.NexaOptics.specularIntensity > 0.01
                opacity: Math.min(1.0, NexaUI.NexaOptics.specularIntensity / 0.28)
                z: 10
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.30) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                // =================================================
                // MAIN BODY (LEFT COLUMN + PREVIEW)
                // =================================================

                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.topMargin: root.outerPadding
                    Layout.leftMargin: root.outerPadding
                    Layout.rightMargin: root.outerPadding
                    Layout.bottomMargin: NexaUI.NexaTokens.spacingSm
                    spacing: NexaUI.NexaTokens.spacingLg

                    // =============================================
                    // LEFT COLUMN (HEADER, SEARCH, TABS, LIST)
                    // =============================================

                    ColumnLayout {
                        Layout.preferredWidth: root.leftWidth
                        Layout.minimumWidth: root.leftWidth
                        Layout.maximumWidth: root.leftWidth
                        Layout.fillWidth: false
                        Layout.fillHeight: true
                        spacing: NexaUI.NexaTokens.spacingMd

                        // -----------------------------------------
                        // LEFT HEADER
                        // -----------------------------------------
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: NexaUI.NexaTokens.spacingSm

                            Text {
                                text: "Clipboard"
                                color: NexaUI.NexaColors.text
                                font.family: NexaUI.NexaTypography.familyDisplay
                                font.pixelSize: NexaUI.NexaTypography.sizeXl
                                font.weight: NexaUI.NexaTypography.weightBold
                            }

                            // Clips count badge
                            Rectangle {
                                implicitWidth: countText.implicitWidth + 12
                                implicitHeight: 20
                                radius: NexaUI.NexaTokens.radiusPill
                                color: NexaUI.NexaColors.surfaceContainerHigh
                                border.width: NexaUI.NexaTokens.borderThin
                                border.color: NexaUI.NexaColors.borderSubtle

                                Text {
                                    id: countText
                                    anchors.centerIn: parent
                                    text: root.entries.length + " clips"
                                    color: NexaUI.NexaColors.mutedText
                                    font.family: NexaUI.NexaTypography.familyBody
                                    font.pixelSize: NexaUI.NexaTypography.sizeXs
                                    font.weight: NexaUI.NexaTypography.weightMedium
                                }
                            }

                            Item { Layout.fillWidth: true }

                            // Refresh button
                            Rectangle {
                                width: 32
                                height: 32
                                radius: NexaUI.NexaTokens.radiusSm
                                color: refreshMouse.containsMouse ? NexaUI.NexaColors.hoverOverlay : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰑐"
                                    color: NexaUI.NexaColors.mutedText
                                    font.family: NexaUI.NexaTypography.familyIcon
                                    font.pixelSize: NexaUI.NexaTypography.sizeSm
                                }

                                MouseArea {
                                    id: refreshMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.refresh()
                                }
                            }

                            // Clear history button
                            Rectangle {
                                width: 32
                                height: 32
                                radius: NexaUI.NexaTokens.radiusSm
                                color: clearMouse.containsMouse ? NexaUI.NexaColors.hoverOverlay : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰆴"
                                    color: clearMouse.containsMouse ? NexaUI.NexaColors.error : NexaUI.NexaColors.mutedText
                                    font.family: NexaUI.NexaTypography.familyIcon
                                    font.pixelSize: NexaUI.NexaTypography.sizeSm

                                    Behavior on color {
                                        ColorAnimation { duration: NexaUI.NexaMotion.durationFast }
                                    }
                                }

                                MouseArea {
                                    id: clearMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.confirmDelete = false
                                        root.confirmClear = true
                                    }
                                }
                            }
                        }

                        // -----------------------------------------
                        // SEARCH BOX
                        // -----------------------------------------
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 40
                            radius: NexaUI.NexaTokens.radiusMd
                            color: searchInput.activeFocus ? NexaUI.NexaColors.surfaceContainerHighest : NexaUI.NexaColors.surfaceContainerHigh
                            border.width: searchInput.activeFocus ? NexaUI.NexaTokens.borderMedium : NexaUI.NexaTokens.borderThin
                            border.color: searchInput.activeFocus ? NexaUI.NexaColors.primary : NexaUI.NexaColors.borderSubtle

                            Behavior on border.color {
                                ColorAnimation { duration: NexaUI.NexaMotion.durationFast }
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 10
                                spacing: 8

                                Text {
                                    text: "󰍉"
                                    color: searchInput.activeFocus ? NexaUI.NexaColors.primary : NexaUI.NexaColors.mutedText
                                    font.family: NexaUI.NexaTypography.familyIcon
                                    font.pixelSize: NexaUI.NexaTypography.sizeSm

                                    Behavior on color {
                                        ColorAnimation { duration: NexaUI.NexaMotion.durationFast }
                                    }
                                }

                                Item {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true

                                    Text {
                                        anchors.left: parent.left
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: searchInput.text.length === 0
                                        text: "Filter clipboard history..."
                                        color: NexaUI.NexaColors.mutedText
                                        font.family: NexaUI.NexaTypography.familyBody
                                        font.pixelSize: NexaUI.NexaTypography.sizeSm
                                    }

                                    TextInput {
                                        id: searchInput
                                        anchors.fill: parent
                                        verticalAlignment: TextInput.AlignVCenter
                                        color: NexaUI.NexaColors.text
                                        selectionColor: NexaUI.NexaColors.primary
                                        selectedTextColor: NexaUI.NexaColors.onPrimary
                                        font.family: NexaUI.NexaTypography.familyBody
                                        font.pixelSize: NexaUI.NexaTypography.sizeSm
                                        clip: true

                                        onTextChanged: searchDebounce.restart()

                                        Keys.onPressed: event => {
                                            if (event.key === Qt.Key_Down) {
                                                root.moveSelection(1)
                                                event.accepted = true
                                                return
                                            }

                                            if (event.key === Qt.Key_Up) {
                                                root.moveSelection(-1)
                                                event.accepted = true
                                                return
                                            }

                                            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                                if (root.confirmClear) {
                                                    root.clearHistory()
                                                } else if (root.confirmDelete) {
                                                    root.deleteSelected()
                                                } else {
                                                    root.copySelected(true)
                                                }
                                                event.accepted = true
                                                return
                                            }

                                            if (event.key === Qt.Key_P && (event.modifiers & Qt.ControlModifier || event.modifiers & Qt.AltModifier)) {
                                                root.togglePinSelected()
                                                event.accepted = true
                                                return
                                            }

                                            if (event.key === Qt.Key_Delete) {
                                                if (root.selectedEntry) {
                                                    root.confirmClear = false
                                                    root.confirmDelete = true
                                                    event.accepted = true
                                                    return
                                                }
                                            }

                                            if (event.key === Qt.Key_Escape) {
                                                if (root.confirmClear || root.confirmDelete) {
                                                    root.confirmClear = false
                                                    root.confirmDelete = false
                                                    event.accepted = true
                                                    return
                                                }
                                                if (searchInput.text.length > 0) {
                                                    searchInput.text = ""
                                                    event.accepted = true
                                                    return
                                                }
                                                event.accepted = true
                                                root.closeClipboard()
                                            }
                                        }
                                    }
                                }

                                // Clear search button
                                Rectangle {
                                    visible: searchInput.text.length > 0
                                    width: 20
                                    height: 20
                                    radius: 10
                                    color: clearSearchMouse.containsMouse ? NexaUI.NexaColors.hoverOverlay : NexaUI.NexaColors.surfaceContainerHigh

                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰅖"
                                        color: NexaUI.NexaColors.mutedText
                                        font.family: NexaUI.NexaTypography.familyIcon
                                        font.pixelSize: NexaUI.NexaTypography.size2Xs
                                    }

                                    MouseArea {
                                        id: clearSearchMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            searchInput.text = ""
                                            searchInput.forceActiveFocus()
                                        }
                                    }
                                }
                            }
                        }

                        // -----------------------------------------
                        // FILTER TABS PILLS
                        // -----------------------------------------
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Repeater {
                                model: [
                                    { id: "all", label: "All", count: root.countAll },
                                    { id: "text", label: "Text", count: -1 },
                                    { id: "image", label: "Images", count: root.countImages },
                                    { id: "link", label: "Links", count: root.countLinks },
                                    { id: "pinned", label: "Pinned", count: root.countPinned }
                                ]

                                Rectangle {
                                    id: filterPill
                                    readonly property bool active: root.activeFilter === modelData.id
                                    readonly property bool hovered: filterMouse.containsMouse

                                    implicitHeight: 28
                                    implicitWidth: pillRow.implicitWidth + 16
                                    radius: NexaUI.NexaTokens.radiusPill

                                    color: active ? NexaUI.NexaColors.alpha(NexaUI.NexaColors.primary, 0.18)
                                                  : hovered ? NexaUI.NexaColors.surfaceContainerHigh
                                                            : NexaUI.NexaColors.surfaceContainerLow

                                    border.width: NexaUI.NexaTokens.borderThin
                                    border.color: active ? NexaUI.NexaColors.primary : NexaUI.NexaColors.borderSubtle

                                    Behavior on color {
                                        ColorAnimation { duration: NexaUI.NexaMotion.durationFast }
                                    }

                                    Behavior on border.color {
                                        ColorAnimation { duration: NexaUI.NexaMotion.durationFast }
                                    }

                                    Row {
                                        id: pillRow
                                        anchors.centerIn: parent
                                        spacing: 4

                                        Text {
                                            text: modelData.label
                                            color: filterPill.active ? NexaUI.NexaColors.primary : (filterPill.hovered ? NexaUI.NexaColors.text : NexaUI.NexaColors.mutedText)
                                            font.family: NexaUI.NexaTypography.familyBody
                                            font.pixelSize: NexaUI.NexaTypography.sizeXs
                                            font.weight: filterPill.active ? NexaUI.NexaTypography.weightSemiBold : NexaUI.NexaTypography.weightRegular
                                        }

                                        Text {
                                            visible: modelData.count >= 0
                                            text: modelData.count
                                            color: filterPill.active ? NexaUI.NexaColors.primary : NexaUI.NexaColors.mutedText
                                            opacity: filterPill.active ? 0.9 : 0.6
                                            font.family: NexaUI.NexaTypography.familyMono
                                            font.pixelSize: NexaUI.NexaTypography.size2Xs
                                        }
                                    }

                                    MouseArea {
                                        id: filterMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.activeFilter = modelData.id
                                            if (root.currentList.length > 0) {
                                                root.selectEntry(root.currentList[0])
                                            } else {
                                                root.selectedEntry = null
                                                root.selectedContent = ""
                                                root.selectedImageSource = ""
                                            }
                                        }
                                    }
                                }
                            }

                            Item { Layout.fillWidth: true }
                        }

                        // -----------------------------------------
                        // HISTORY LIST
                        // -----------------------------------------
                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            ListView {
                                id: historyList
                                anchors.fill: parent
                                anchors.rightMargin: 6
                                model: root.currentList
                                spacing: 6
                                clip: true
                                boundsBehavior: Flickable.StopAtBounds
                                flickDeceleration: 1500
                                maximumFlickVelocity: 3000
                                pixelAligned: false

                                NexaUI.NexaSmoothScroll {}

                                delegate: Item {
                                    id: entryDelegate
                                    required property var modelData
                                    required property int index

                                    width: historyList.width
                                    height: 64

                                    readonly property bool selected:
                                        root.selectedEntry && root.selectedEntry.id === modelData.id
                                    readonly property string category: root.getItemCategory(modelData)
                                    readonly property color categoryColor: root.getCategoryColor(category)
                                    readonly property string categoryIcon: root.getCategoryIcon(category)
                                    readonly property string categoryLabel: root.getCategoryLabel(category)

                                    // Card background container
                                    Rectangle {
                                        anchors.fill: parent
                                        radius: NexaUI.NexaTokens.radiusSm

                                        color: entryDelegate.selected
                                            ? NexaUI.NexaColors.alpha(NexaUI.NexaColors.primary, 0.16)
                                            : (entryMouse.containsMouse ? NexaUI.NexaColors.surfaceContainerHigh : NexaUI.NexaColors.surfaceContainer)

                                        border.width: NexaUI.NexaTokens.borderThin
                                        border.color: entryDelegate.selected
                                            ? NexaUI.NexaColors.primary
                                            : (modelData.pinned ? NexaUI.NexaColors.primary : NexaUI.NexaColors.borderSubtle)

                                        Behavior on color {
                                            ColorAnimation { duration: NexaUI.NexaMotion.durationFast }
                                        }
                                        Behavior on border.color {
                                            ColorAnimation { duration: NexaUI.NexaMotion.durationFast }
                                        }

                                        // Left vertical accent indicator bar
                                        Rectangle {
                                            anchors.left: parent.left
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: 3.5
                                            height: entryDelegate.selected ? 26 : 0
                                            radius: 2
                                            color: NexaUI.NexaColors.primary
                                            visible: entryDelegate.selected

                                            Behavior on height {
                                                NumberAnimation { duration: NexaUI.NexaMotion.durationFast }
                                            }
                                        }
                                    }

                                    // Background mouse area for whole card
                                    MouseArea {
                                        id: entryMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.selectEntry(modelData)
                                        onDoubleClicked: {
                                            root.selectEntry(modelData)
                                            root.copySelected(true)
                                        }
                                    }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 12
                                        anchors.rightMargin: 10
                                        spacing: 10

                                        // Type Avatar Icon Box
                                        Rectangle {
                                            Layout.preferredWidth: 38
                                            Layout.preferredHeight: 38
                                            radius: NexaUI.NexaTokens.radiusSm
                                            color: entryDelegate.selected
                                                ? Qt.rgba(entryDelegate.categoryColor.r, entryDelegate.categoryColor.g, entryDelegate.categoryColor.b, 0.18)
                                                : NexaUI.NexaColors.surfaceContainerHigh

                                            Text {
                                                anchors.centerIn: parent
                                                text: entryDelegate.categoryIcon
                                                color: entryDelegate.categoryColor
                                                font.family: NexaUI.NexaTypography.familyIcon
                                                font.pixelSize: NexaUI.NexaTypography.sizeMd
                                            }
                                        }

                                        // Text Information
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 3

                                            // Title / Preview
                                            Text {
                                                Layout.fillWidth: true
                                                text: modelData.type === "image" ? "Image clip" : (modelData.preview || "")
                                                color: entryDelegate.selected ? NexaUI.NexaColors.primary : NexaUI.NexaColors.text
                                                font.family: NexaUI.NexaTypography.familyBody
                                                font.pixelSize: NexaUI.NexaTypography.sizeSm
                                                font.weight: NexaUI.NexaTypography.weightSemiBold
                                                elide: Text.ElideRight
                                                maximumLineCount: 1

                                                Behavior on color {
                                                    ColorAnimation { duration: NexaUI.NexaMotion.durationFast }
                                                }
                                            }

                                            // Subtitle Row (Category Tag + Details)
                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: 6

                                                // Small Tag Chip
                                                Rectangle {
                                                    implicitWidth: tagLabel.implicitWidth + 8
                                                    implicitHeight: 16
                                                    radius: 4
                                                    color: Qt.rgba(entryDelegate.categoryColor.r, entryDelegate.categoryColor.g, entryDelegate.categoryColor.b, 0.15)

                                                    Text {
                                                        id: tagLabel
                                                        anchors.centerIn: parent
                                                        text: entryDelegate.categoryLabel
                                                        color: entryDelegate.categoryColor
                                                        font.family: NexaUI.NexaTypography.familyBody
                                                        font.pixelSize: NexaUI.NexaTypography.size2Xs
                                                        font.weight: NexaUI.NexaTypography.weightSemiBold
                                                    }
                                                }

                                                // Details text
                                                Text {
                                                    Layout.fillWidth: true
                                                    text: modelData.type === "image"
                                                        ? root.formatBytes(modelData.size_bytes || 0)
                                                        : (modelData.preview ? (modelData.preview.length + " chars") : root.formatBytes(modelData.size_bytes || 0))
                                                    color: NexaUI.NexaColors.mutedText
                                                    font.family: NexaUI.NexaTypography.familyBody
                                                    font.pixelSize: NexaUI.NexaTypography.sizeXs
                                                    elide: Text.ElideRight
                                                }
                                            }
                                        }

                                        // Pin indicator or action icon
                                        Rectangle {
                                            z: 10
                                            visible: modelData.pinned === true || entryMouse.containsMouse
                                            width: 26
                                            height: 26
                                            radius: 6
                                            color: quickPinMouse.containsMouse ? NexaUI.NexaColors.hoverOverlay : "transparent"

                                            Text {
                                                anchors.centerIn: parent
                                                text: "󰐃"
                                                color: modelData.pinned ? NexaUI.NexaColors.primary : NexaUI.NexaColors.mutedText
                                                font.family: NexaUI.NexaTypography.familyIcon
                                                font.pixelSize: NexaUI.NexaTypography.sizeSm
                                            }

                                            MouseArea {
                                                id: quickPinMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    root.togglePinSelected(modelData)
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // Empty state
                            Column {
                                anchors.centerIn: parent
                                visible: !root.loading && root.currentList.length === 0
                                spacing: 8

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "󰅇"
                                    color: NexaUI.NexaColors.mutedText
                                    opacity: 0.5
                                    font.family: NexaUI.NexaTypography.familyIcon
                                    font.pixelSize: 36
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: searchInput.text.length > 0 ? "No matches found" : "No clips in this filter"
                                    color: NexaUI.NexaColors.mutedText
                                    font.family: NexaUI.NexaTypography.familyBody
                                    font.pixelSize: NexaUI.NexaTypography.sizeSm
                                }
                            }
                        }
                    }

                    // =============================================
                    // DIVIDER
                    // =============================================

                    Rectangle {
                        Layout.fillHeight: true
                        Layout.preferredWidth: 1
                        Layout.minimumWidth: 1
                        Layout.maximumWidth: 1
                        Layout.fillWidth: false
                        color: NexaUI.NexaColors.borderSubtle
                    }

                    // =============================================
                    // RIGHT COLUMN (PREVIEW & ACTION PANE)
                    // =============================================

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        Layout.fillHeight: true
                        spacing: NexaUI.NexaTokens.spacingMd

                        // -----------------------------------------
                        // PREVIEW HEADER
                        // -----------------------------------------
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: NexaUI.NexaTokens.spacingMd

                            // Type icon badge
                            Rectangle {
                                width: 40
                                height: 40
                                radius: NexaUI.NexaTokens.radiusSm
                                color: root.selectedEntry
                                    ? Qt.rgba(root.getCategoryColor(root.getItemCategory(root.selectedEntry)).r,
                                              root.getCategoryColor(root.getItemCategory(root.selectedEntry)).g,
                                              root.getCategoryColor(root.getItemCategory(root.selectedEntry)).b, 0.16)
                                    : NexaUI.NexaColors.surfaceContainerHigh

                                Text {
                                    anchors.centerIn: parent
                                    text: root.selectedEntry ? root.getCategoryIcon(root.getItemCategory(root.selectedEntry)) : "󰅇"
                                    color: root.selectedEntry ? root.getCategoryColor(root.getItemCategory(root.selectedEntry)) : NexaUI.NexaColors.mutedText
                                    font.family: NexaUI.NexaTypography.familyIcon
                                    font.pixelSize: NexaUI.NexaTypography.sizeMd
                                }
                            }

                            // Dynamic Title & Stats
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                Text {
                                    text: {
                                        if (!root.selectedEntry) return "Preview"
                                        const cat = root.getItemCategory(root.selectedEntry)
                                        if (cat === "image") return "Image Clip"
                                        if (cat === "link")  return "Web Link"
                                        if (cat === "code")  return "Code Snippet"
                                        return "Text Clip"
                                    }
                                    color: NexaUI.NexaColors.text
                                    font.family: NexaUI.NexaTypography.familyDisplay
                                    font.pixelSize: NexaUI.NexaTypography.sizeLg
                                    font.weight: NexaUI.NexaTypography.weightSemiBold
                                }

                                RowLayout {
                                    spacing: 8
                                    visible: root.selectedEntry !== null

                                    Text {
                                        text: root.formatBytes(root.selectedSize)
                                        color: NexaUI.NexaColors.mutedText
                                        font.family: NexaUI.NexaTypography.familyBody
                                        font.pixelSize: NexaUI.NexaTypography.sizeXs
                                    }

                                    Text {
                                        visible: root.selectedType === "text" && root.textCharCount > 0
                                        text: "•  " + root.textCharCount + " chars"
                                        color: NexaUI.NexaColors.mutedText
                                        font.family: NexaUI.NexaTypography.familyBody
                                        font.pixelSize: NexaUI.NexaTypography.sizeXs
                                    }

                                    Text {
                                        visible: root.selectedType === "text" && root.textLineCount > 1
                                        text: "•  " + root.textLineCount + " lines"
                                        color: NexaUI.NexaColors.mutedText
                                        font.family: NexaUI.NexaTypography.familyBody
                                        font.pixelSize: NexaUI.NexaTypography.sizeXs
                                    }

                                    Text {
                                        visible: root.selectedType === "image" && previewImage.sourceSize.width > 0
                                        text: "•  " + previewImage.sourceSize.width + " × " + previewImage.sourceSize.height + " px"
                                        color: NexaUI.NexaColors.mutedText
                                        font.family: NexaUI.NexaTypography.familyBody
                                        font.pixelSize: NexaUI.NexaTypography.sizeXs
                                    }
                                }
                            }

                            // Spacer pushing buttons to the far right
                            Item {
                                Layout.fillWidth: true
                            }

                            // Pin Button
                            Rectangle {
                                Layout.preferredWidth: 34
                                Layout.preferredHeight: 34
                                radius: NexaUI.NexaTokens.radiusSm
                                color: root.selectedEntry && root.selectedEntry.pinned
                                    ? NexaUI.NexaColors.alpha(NexaUI.NexaColors.primary, 0.2)
                                    : (pinMouse.containsMouse ? NexaUI.NexaColors.hoverOverlay : NexaUI.NexaColors.surfaceContainerHigh)
                                opacity: root.selectedEntry ? 1 : 0.4

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰐃"
                                    color: root.selectedEntry && root.selectedEntry.pinned ? NexaUI.NexaColors.primary : NexaUI.NexaColors.text
                                    font.family: NexaUI.NexaTypography.familyIcon
                                    font.pixelSize: NexaUI.NexaTypography.sizeSm
                                }

                                MouseArea {
                                    id: pinMouse
                                    anchors.fill: parent
                                    enabled: root.selectedEntry !== null
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.togglePinSelected()
                                }
                            }

                            // Delete Button
                            Rectangle {
                                Layout.preferredWidth: 34
                                Layout.preferredHeight: 34
                                radius: NexaUI.NexaTokens.radiusSm
                                color: deleteMouse.containsMouse ? NexaUI.NexaColors.hoverOverlay : NexaUI.NexaColors.surfaceContainerHigh
                                opacity: root.selectedEntry ? 1 : 0.4

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰆴"
                                    color: deleteMouse.containsMouse ? NexaUI.NexaColors.error : NexaUI.NexaColors.mutedText
                                    font.family: NexaUI.NexaTypography.familyIcon
                                    font.pixelSize: NexaUI.NexaTypography.sizeSm
                                }

                                MouseArea {
                                    id: deleteMouse
                                    anchors.fill: parent
                                    enabled: root.selectedEntry !== null
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.confirmClear = false
                                        root.confirmDelete = true
                                    }
                                }
                            }

                            // Close Button
                            Rectangle {
                                Layout.preferredWidth: 34
                                Layout.preferredHeight: 34
                                radius: NexaUI.NexaTokens.radiusSm
                                color: closeMouse.containsMouse ? NexaUI.NexaColors.hoverOverlay : NexaUI.NexaColors.surfaceContainerHigh

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰅖"
                                    color: NexaUI.NexaColors.text
                                    font.family: NexaUI.NexaTypography.familyIcon
                                    font.pixelSize: NexaUI.NexaTypography.sizeSm
                                }

                                MouseArea {
                                    id: closeMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.closeClipboard()
                                }
                            }
                        }

                        // -----------------------------------------
                        // PREVIEW CANVAS AREA
                        // -----------------------------------------
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: NexaUI.NexaTokens.radiusMd
                            color: NexaUI.NexaColors.surfaceContainerLow
                            border.width: NexaUI.NexaTokens.borderThin
                            border.color: NexaUI.NexaColors.borderSubtle
                            clip: true

                            // Empty state
                            Column {
                                anchors.centerIn: parent
                                visible: root.selectedEntry === null
                                spacing: 10

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "󰅈"
                                    color: NexaUI.NexaColors.mutedText
                                    opacity: 0.4
                                    font.family: NexaUI.NexaTypography.familyIcon
                                    font.pixelSize: 48
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "Select a clip to view details"
                                    color: NexaUI.NexaColors.mutedText
                                    font.family: NexaUI.NexaTypography.familyBody
                                    font.pixelSize: NexaUI.NexaTypography.sizeMd
                                }
                            }

                            // Text / Code preview
                            Flickable {
                                id: textPreview
                                anchors.fill: parent
                                anchors.margins: 14
                                visible: root.selectedEntry !== null && root.selectedType === "text"
                                contentWidth: width
                                contentHeight: clipboardText.implicitHeight
                                clip: true
                                boundsBehavior: Flickable.StopAtBounds
                                flickDeceleration: 1500
                                maximumFlickVelocity: 3000
                                pixelAligned: false

                                NexaUI.NexaSmoothScroll {}

                                ScrollBar.vertical: ScrollBar {
                                    id: cbScrollBar
                                    policy: ScrollBar.AsNeeded
                                    contentItem: Rectangle {
                                        implicitWidth: 4
                                        radius: 2
                                        color: NexaUI.NexaColors.alpha(NexaUI.NexaColors.text, cbScrollBar.hovered ? 0.5 : 0.2)
                                    }
                                }

                                Text {
                                    id: clipboardText
                                    width: textPreview.width
                                    text: root.selectedContent
                                    color: NexaUI.NexaColors.text
                                    font.family: root.isCode(root.selectedContent) ? NexaUI.NexaTypography.familyMono : NexaUI.NexaTypography.familyBody
                                    font.pixelSize: NexaUI.NexaTypography.sizeMd
                                    lineHeight: 1.3
                                    wrapMode: Text.WrapAnywhere
                                    textFormat: Text.PlainText
                                }
                            }

                            // Image preview
                            Item {
                                anchors.fill: parent
                                anchors.margins: 14
                                visible: root.selectedEntry !== null && root.selectedType === "image"

                                Rectangle {
                                    anchors.fill: parent
                                    radius: NexaUI.NexaTokens.radiusSm
                                    color: NexaUI.NexaColors.surfaceContainer
                                    border.width: NexaUI.NexaTokens.borderThin
                                    border.color: NexaUI.NexaColors.borderSubtle
                                    clip: true

                                    Image {
                                        id: previewImage
                                        anchors.fill: parent
                                        anchors.margins: 12
                                        source: root.selectedImageSource
                                        fillMode: Image.PreserveAspectFit
                                        asynchronous: true
                                        cache: false
                                        smooth: true
                                    }
                                }
                            }
                        }

                        // -----------------------------------------
                        // ACTION FOOTER (PREVIEW SPECIFIC)
                        // -----------------------------------------
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            visible: root.selectedEntry !== null

                            // Contextual: Open URL if it's a link
                            Rectangle {
                                visible: root.selectedType === "text" && root.isLink(root.selectedContent)
                                implicitHeight: 36
                                implicitWidth: openUrlContent.implicitWidth + 24
                                radius: NexaUI.NexaTokens.radiusSm
                                color: openUrlMouse.containsMouse ? NexaUI.NexaColors.hoverOverlay : NexaUI.NexaColors.surfaceContainerHigh
                                border.width: NexaUI.NexaTokens.borderThin
                                border.color: NexaUI.NexaColors.secondary

                                RowLayout {
                                    id: openUrlContent
                                    anchors.centerIn: parent
                                    spacing: 6

                                    Text {
                                        text: "󰌹"
                                        color: NexaUI.NexaColors.secondary
                                        font.family: NexaUI.NexaTypography.familyIcon
                                        font.pixelSize: NexaUI.NexaTypography.sizeSm
                                    }
                                    Text {
                                        text: "Open in Browser"
                                        color: NexaUI.NexaColors.text
                                        font.family: NexaUI.NexaTypography.familyBody
                                        font.pixelSize: NexaUI.NexaTypography.sizeSm
                                        font.weight: NexaUI.NexaTypography.weightMedium
                                    }
                                }

                                MouseArea {
                                    id: openUrlMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.openSelectedUrl()
                                }
                            }

                            // Contextual: Open Image in external viewer
                            Rectangle {
                                visible: root.selectedType === "image" && root.selectedImageSource.length > 0
                                implicitHeight: 36
                                implicitWidth: openImgContent.implicitWidth + 24
                                radius: NexaUI.NexaTokens.radiusSm
                                color: openImgMouse.containsMouse ? NexaUI.NexaColors.hoverOverlay : NexaUI.NexaColors.surfaceContainerHigh
                                border.width: NexaUI.NexaTokens.borderThin
                                border.color: NexaUI.NexaColors.tertiary

                                RowLayout {
                                    id: openImgContent
                                    anchors.centerIn: parent
                                    spacing: 6

                                    Text {
                                        text: "󰋩"
                                        color: NexaUI.NexaColors.tertiary
                                        font.family: NexaUI.NexaTypography.familyIcon
                                        font.pixelSize: NexaUI.NexaTypography.sizeSm
                                    }
                                    Text {
                                        text: "Open in Viewer"
                                        color: NexaUI.NexaColors.text
                                        font.family: NexaUI.NexaTypography.familyBody
                                        font.pixelSize: NexaUI.NexaTypography.sizeSm
                                        font.weight: NexaUI.NexaTypography.weightMedium
                                    }
                                }

                                MouseArea {
                                    id: openImgMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        Qt.openUrlExternally(root.selectedImageSource)
                                        root.closeClipboard()
                                    }
                                }
                            }

                            Item { Layout.fillWidth: true }

                            // Hero Action: Copy Button
                            Rectangle {
                                implicitHeight: 36
                                implicitWidth: copyContent.implicitWidth + 24
                                radius: NexaUI.NexaTokens.radiusSm
                                color: copyBtnMouse.pressed
                                    ? NexaUI.NexaColors.pressOverlay(NexaUI.NexaColors.primary)
                                    : (copyBtnMouse.containsMouse ? NexaUI.NexaColors.primary : NexaUI.NexaColors.primaryContainer)

                                Behavior on color {
                                    ColorAnimation { duration: NexaUI.NexaMotion.durationFast }
                                }

                                RowLayout {
                                    id: copyContent
                                    anchors.centerIn: parent
                                    spacing: 8

                                    Text {
                                        text: "󰆏"
                                        color: copyBtnMouse.containsMouse ? NexaUI.NexaColors.onPrimary : NexaUI.NexaColors.primary
                                        font.family: NexaUI.NexaTypography.familyIcon
                                        font.pixelSize: NexaUI.NexaTypography.sizeSm
                                    }
                                    Text {
                                        text: "Copy to Clipboard"
                                        color: copyBtnMouse.containsMouse ? NexaUI.NexaColors.onPrimary : NexaUI.NexaColors.primary
                                        font.family: NexaUI.NexaTypography.familyBody
                                        font.pixelSize: NexaUI.NexaTypography.sizeSm
                                        font.weight: NexaUI.NexaTypography.weightSemiBold
                                    }
                                    Text {
                                        text: "↵"
                                        color: copyBtnMouse.containsMouse ? NexaUI.NexaColors.onPrimary : NexaUI.NexaColors.mutedText
                                        font.family: NexaUI.NexaTypography.familyMono
                                        font.pixelSize: NexaUI.NexaTypography.sizeXs
                                    }
                                }

                                MouseArea {
                                    id: copyBtnMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.copySelected(true)
                                }
                            }
                        }
                    }
                }

                // =================================================
                // BOTTOM KEYBOARD SHORTCUTS BAR
                // =================================================
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    color: "transparent"

                    // Top divider line only (no outer side borders to clash with panel corners)
                    Rectangle {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 1
                        color: NexaUI.NexaColors.borderSubtle
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: root.outerPadding
                        anchors.rightMargin: root.outerPadding
                        spacing: 16

                        Row {
                            spacing: 5
                            Rectangle {
                                width: 20
                                height: 16
                                radius: 3
                                color: NexaUI.NexaColors.surfaceContainerHigh
                                anchors.verticalCenter: parent.verticalCenter
                                Text {
                                    anchors.centerIn: parent
                                    text: "↑↓"
                                    color: NexaUI.NexaColors.mutedText
                                    font.family: NexaUI.NexaTypography.familyMono
                                    font.pixelSize: 10
                                }
                            }
                            Text {
                                text: "Navigate"
                                color: NexaUI.NexaColors.mutedText
                                font.family: NexaUI.NexaTypography.familyBody
                                font.pixelSize: NexaUI.NexaTypography.sizeXs
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        Row {
                            spacing: 5
                            Rectangle {
                                width: 22
                                height: 16
                                radius: 3
                                color: NexaUI.NexaColors.surfaceContainerHigh
                                anchors.verticalCenter: parent.verticalCenter
                                Text {
                                    anchors.centerIn: parent
                                    text: "↵"
                                    color: NexaUI.NexaColors.primary
                                    font.family: NexaUI.NexaTypography.familyMono
                                    font.pixelSize: 11
                                    font.weight: Font.Bold
                                }
                            }
                            Text {
                                text: "Copy & Close"
                                color: NexaUI.NexaColors.mutedText
                                font.family: NexaUI.NexaTypography.familyBody
                                font.pixelSize: NexaUI.NexaTypography.sizeXs
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        Row {
                            spacing: 5
                            Rectangle {
                                width: 18
                                height: 16
                                radius: 3
                                color: NexaUI.NexaColors.surfaceContainerHigh
                                anchors.verticalCenter: parent.verticalCenter
                                Text {
                                    anchors.centerIn: parent
                                    text: "P"
                                    color: NexaUI.NexaColors.mutedText
                                    font.family: NexaUI.NexaTypography.familyMono
                                    font.pixelSize: 10
                                }
                            }
                            Text {
                                text: "Pin / Unpin"
                                color: NexaUI.NexaColors.mutedText
                                font.family: NexaUI.NexaTypography.familyBody
                                font.pixelSize: NexaUI.NexaTypography.sizeXs
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        Row {
                            spacing: 5
                            Rectangle {
                                width: 24
                                height: 16
                                radius: 3
                                color: NexaUI.NexaColors.surfaceContainerHigh
                                anchors.verticalCenter: parent.verticalCenter
                                Text {
                                    anchors.centerIn: parent
                                    text: "Del"
                                    color: NexaUI.NexaColors.mutedText
                                    font.family: NexaUI.NexaTypography.familyMono
                                    font.pixelSize: 10
                                }
                            }
                            Text {
                                text: "Delete"
                                color: NexaUI.NexaColors.mutedText
                                font.family: NexaUI.NexaTypography.familyBody
                                font.pixelSize: NexaUI.NexaTypography.sizeXs
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        Item { Layout.fillWidth: true }

                        Row {
                            spacing: 5
                            Rectangle {
                                width: 26
                                height: 16
                                radius: 3
                                color: NexaUI.NexaColors.surfaceContainerHigh
                                anchors.verticalCenter: parent.verticalCenter
                                Text {
                                    anchors.centerIn: parent
                                    text: "ESC"
                                    color: NexaUI.NexaColors.mutedText
                                    font.family: NexaUI.NexaTypography.familyMono
                                    font.pixelSize: 9
                                }
                            }
                            Text {
                                text: "Close"
                                color: NexaUI.NexaColors.mutedText
                                font.family: NexaUI.NexaTypography.familyBody
                                font.pixelSize: NexaUI.NexaTypography.sizeXs
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }
                }
            }

            // =====================================================
            // FLOATING TOAST NOTIFICATION
            // =====================================================
            Rectangle {
                id: toastPill
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 46

                implicitWidth: toastRow.implicitWidth + 24
                implicitHeight: 34
                radius: NexaUI.NexaTokens.radiusPill

                color: NexaUI.NexaColors.surfaceContainerHighest
                border.width: NexaUI.NexaTokens.borderThin
                border.color: NexaUI.NexaColors.primary

                opacity: root.toastVisible ? 1 : 0
                scale: root.toastVisible ? 1 : 0.85
                z: 800

                Behavior on opacity {
                    NumberAnimation { duration: NexaUI.NexaMotion.durationFast }
                }
                Behavior on scale {
                    NumberAnimation { duration: NexaUI.NexaMotion.durationFast; easing.type: Easing.OutBack }
                }

                Row {
                    id: toastRow
                    anchors.centerIn: parent
                    spacing: 8

                    Text {
                        text: "󰄬"
                        color: NexaUI.NexaColors.primary
                        font.family: NexaUI.NexaTypography.familyIcon
                        font.pixelSize: NexaUI.NexaTypography.sizeSm
                    }
                    Text {
                        text: root.toastText
                        color: NexaUI.NexaColors.text
                        font.family: NexaUI.NexaTypography.familyBody
                        font.pixelSize: NexaUI.NexaTypography.sizeSm
                        font.weight: NexaUI.NexaTypography.weightSemiBold
                    }
                }
            }

            // =====================================================
            // CENTERED CONFIRMATION MODAL (CLEAR / DELETE)
            // =====================================================
            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0, 0, 0, 0.6)
                visible: root.confirmClear || root.confirmDelete
                z: 900

                // Dialog Card
                Rectangle {
                    anchors.centerIn: parent
                    width: 380
                    implicitHeight: modalColumn.implicitHeight + 40
                    radius: NexaUI.NexaTokens.radiusMd
                    color: NexaUI.NexaColors.surfaceContainerHighest
                    border.width: NexaUI.NexaTokens.borderThin
                    border.color: NexaUI.NexaColors.borderStrong

                    ColumnLayout {
                        id: modalColumn
                        anchors.fill: parent
                        anchors.margins: 20
                        spacing: 14

                        // Warning Icon Circle
                        Rectangle {
                            Layout.alignment: Qt.AlignHCenter
                            width: 44
                            height: 44
                            radius: 22
                            color: NexaUI.NexaColors.errorContainer

                            Text {
                                anchors.centerIn: parent
                                text: "󰆴"
                                color: NexaUI.NexaColors.error
                                font.family: NexaUI.NexaTypography.familyIcon
                                font.pixelSize: 22
                            }
                        }

                        // Title
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: root.confirmClear ? "Clear Entire Clipboard?" : "Delete Clipboard Item?"
                            color: NexaUI.NexaColors.text
                            font.family: NexaUI.NexaTypography.familyDisplay
                            font.pixelSize: NexaUI.NexaTypography.sizeLg
                            font.weight: NexaUI.NexaTypography.weightBold
                        }

                        // Subtitle
                        Text {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: root.confirmClear
                                ? "All saved history items will be permanently removed."
                                : "This item will be removed from your clipboard history."
                            color: NexaUI.NexaColors.mutedText
                            font.family: NexaUI.NexaTypography.familyBody
                            font.pixelSize: NexaUI.NexaTypography.sizeSm
                            wrapMode: Text.Wrap
                        }

                        Item { Layout.preferredHeight: 6 }

                        // Buttons Row
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            // Cancel
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 36
                                radius: NexaUI.NexaTokens.radiusSm
                                color: modalCancelMouse.containsMouse ? NexaUI.NexaColors.hoverOverlay : NexaUI.NexaColors.surfaceContainerHigh
                                border.width: NexaUI.NexaTokens.borderThin
                                border.color: NexaUI.NexaColors.borderSubtle

                                Text {
                                    anchors.centerIn: parent
                                    text: "Cancel"
                                    color: NexaUI.NexaColors.text
                                    font.family: NexaUI.NexaTypography.familyBody
                                    font.pixelSize: NexaUI.NexaTypography.sizeSm
                                    font.weight: NexaUI.NexaTypography.weightMedium
                                }

                                MouseArea {
                                    id: modalCancelMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.confirmClear = false
                                        root.confirmDelete = false
                                    }
                                }
                            }

                            // Confirm
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 36
                                radius: NexaUI.NexaTokens.radiusSm
                                color: modalConfirmMouse.containsMouse ? NexaUI.NexaColors.error : NexaUI.NexaColors.errorContainer

                                Text {
                                    anchors.centerIn: parent
                                    text: root.confirmClear ? "Clear All" : "Delete"
                                    color: modalConfirmMouse.containsMouse ? NexaUI.NexaColors.onError : NexaUI.NexaColors.error
                                    font.family: NexaUI.NexaTypography.familyBody
                                    font.pixelSize: NexaUI.NexaTypography.sizeSm
                                    font.weight: NexaUI.NexaTypography.weightSemiBold
                                }

                                MouseArea {
                                    id: modalConfirmMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (root.confirmClear) {
                                            root.clearHistory()
                                        } else {
                                            root.deleteSelected()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
