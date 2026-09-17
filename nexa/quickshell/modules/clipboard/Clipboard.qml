import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Quickshell
import Quickshell.Io

import "../../theme" as NTheme


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
            case "image": return NTheme.Theme.tertiary
            case "link":  return NTheme.Theme.secondary
            case "code":  return NTheme.Theme.success
            default:      return NTheme.Theme.primary
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
        interval: NTheme.Theme.animationFast
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

        opacity: root.clipboardOpen ? NTheme.Theme.opacityFull : NTheme.Theme.opacityHidden
        scale: root.clipboardOpen ? 1.0 : 0.97

        Behavior on opacity {
            NumberAnimation {
                duration: root.clipboardOpen ? NTheme.Theme.animationNormal : NTheme.Theme.animationFast
                easing.type: root.clipboardOpen ? NTheme.Theme.easingEnter : NTheme.Theme.easingExit
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: root.clipboardOpen ? NTheme.Theme.animationNormal : NTheme.Theme.animationFast
                easing.type: root.clipboardOpen ? NTheme.Theme.easingEnter : NTheme.Theme.easingExit
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

        Rectangle {
            id: panel

            anchors.centerIn: parent
            width: Math.min(root.panelWidth, parent.width - 40)
            height: Math.min(root.panelHeight, parent.height - 60)

            radius: NTheme.Theme.radiusLg
            color: NTheme.Theme.panelBackground
            border.width: NTheme.Theme.borderThin
            border.color: NTheme.Theme.border

            clip: true

            // Stop click propagating to backdrop
            MouseArea {
                anchors.fill: parent
            }

            // Top glass edge highlight gradient
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: 1
                color: NTheme.Theme.edgeHighlightStrong
                z: 10
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
                    Layout.bottomMargin: NTheme.Theme.spacingSm
                    spacing: NTheme.Theme.spacingLg

                    // =============================================
                    // LEFT COLUMN (HEADER, SEARCH, TABS, LIST)
                    // =============================================

                    ColumnLayout {
                        Layout.preferredWidth: root.leftWidth
                        Layout.minimumWidth: root.leftWidth
                        Layout.maximumWidth: root.leftWidth
                        Layout.fillWidth: false
                        Layout.fillHeight: true
                        spacing: NTheme.Theme.spacingMd

                        // -----------------------------------------
                        // LEFT HEADER
                        // -----------------------------------------
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: NTheme.Theme.spacingSm

                            Text {
                                text: "Clipboard"
                                color: NTheme.Theme.text
                                font.family: NTheme.Theme.fontFamily
                                font.pixelSize: NTheme.Theme.fontSizeXl
                                font.weight: NTheme.Theme.fontWeightBold
                            }

                            // Clips count badge
                            Rectangle {
                                implicitWidth: countText.implicitWidth + 12
                                implicitHeight: 20
                                radius: NTheme.Theme.radiusPill
                                color: NTheme.Theme.surfaceContainerHigh
                                border.width: NTheme.Theme.borderThin
                                border.color: NTheme.Theme.borderSubtle

                                Text {
                                    id: countText
                                    anchors.centerIn: parent
                                    text: root.entries.length + " clips"
                                    color: NTheme.Theme.mutedText
                                    font.family: NTheme.Theme.fontFamily
                                    font.pixelSize: NTheme.Theme.fontSizeXs
                                    font.weight: NTheme.Theme.fontWeightMedium
                                }
                            }

                            Item { Layout.fillWidth: true }

                            // Refresh button
                            Rectangle {
                                width: 32
                                height: 32
                                radius: NTheme.Theme.radiusSm
                                color: refreshMouse.containsMouse ? NTheme.Theme.hoverStrong : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰑐"
                                    color: NTheme.Theme.mutedText
                                    font.family: NTheme.Theme.iconFontFamily
                                    font.pixelSize: NTheme.Theme.iconSm
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
                                radius: NTheme.Theme.radiusSm
                                color: clearMouse.containsMouse ? NTheme.Theme.hoverStrong : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰆴"
                                    color: clearMouse.containsMouse ? NTheme.Theme.error : NTheme.Theme.mutedText
                                    font.family: NTheme.Theme.iconFontFamily
                                    font.pixelSize: NTheme.Theme.iconSm

                                    Behavior on color {
                                        ColorAnimation { duration: NTheme.Theme.animationFast }
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
                            radius: NTheme.Theme.radiusMd
                            color: searchInput.activeFocus ? NTheme.Theme.inputBackgroundFocus : NTheme.Theme.inputBackground
                            border.width: searchInput.activeFocus ? NTheme.Theme.borderNormal : NTheme.Theme.borderThin
                            border.color: searchInput.activeFocus ? NTheme.Theme.focusBorder : NTheme.Theme.borderSubtle

                            Behavior on border.color {
                                ColorAnimation { duration: NTheme.Theme.animationFast }
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 10
                                spacing: 8

                                Text {
                                    text: "󰍉"
                                    color: searchInput.activeFocus ? NTheme.Theme.primary : NTheme.Theme.mutedText
                                    font.family: NTheme.Theme.iconFontFamily
                                    font.pixelSize: NTheme.Theme.iconSm

                                    Behavior on color {
                                        ColorAnimation { duration: NTheme.Theme.animationFast }
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
                                        color: NTheme.Theme.mutedText
                                        font.family: NTheme.Theme.fontFamily
                                        font.pixelSize: NTheme.Theme.fontSizeSm
                                    }

                                    TextInput {
                                        id: searchInput
                                        anchors.fill: parent
                                        verticalAlignment: TextInput.AlignVCenter
                                        color: NTheme.Theme.text
                                        selectionColor: NTheme.Theme.primary
                                        selectedTextColor: NTheme.Theme.primaryText
                                        font.family: NTheme.Theme.fontFamily
                                        font.pixelSize: NTheme.Theme.fontSizeSm
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
                                    color: clearSearchMouse.containsMouse ? NTheme.Theme.hoverStrong : NTheme.Theme.surfaceContainerHigh

                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰅖"
                                        color: NTheme.Theme.mutedText
                                        font.family: NTheme.Theme.iconFontFamily
                                        font.pixelSize: NTheme.Theme.icon2Xs
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
                                    radius: NTheme.Theme.radiusPill

                                    color: active ? NTheme.Theme.primarySurfaceStrong
                                                  : hovered ? NTheme.Theme.hoverStrong
                                                            : NTheme.Theme.surfaceContainerLow

                                    border.width: NTheme.Theme.borderThin
                                    border.color: active ? NTheme.Theme.primary : NTheme.Theme.borderSubtle

                                    Behavior on color {
                                        ColorAnimation { duration: NTheme.Theme.animationFast }
                                    }

                                    Behavior on border.color {
                                        ColorAnimation { duration: NTheme.Theme.animationFast }
                                    }

                                    Row {
                                        id: pillRow
                                        anchors.centerIn: parent
                                        spacing: 4

                                        Text {
                                            text: modelData.label
                                            color: filterPill.active ? NTheme.Theme.primary : (filterPill.hovered ? NTheme.Theme.text : NTheme.Theme.mutedText)
                                            font.family: NTheme.Theme.fontFamily
                                            font.pixelSize: NTheme.Theme.fontSizeXs
                                            font.weight: filterPill.active ? NTheme.Theme.fontWeightDemiBold : NTheme.Theme.fontWeightNormal
                                        }

                                        Text {
                                            visible: modelData.count >= 0
                                            text: modelData.count
                                            color: filterPill.active ? NTheme.Theme.primary : NTheme.Theme.mutedText
                                            opacity: filterPill.active ? 0.9 : 0.6
                                            font.family: NTheme.Theme.monoFontFamily
                                            font.pixelSize: NTheme.Theme.fontSize2Xs
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
                                flickDeceleration: NTheme.Theme.flickDeceleration
                                maximumFlickVelocity: NTheme.Theme.flickVelocityMax
                                pixelAligned: true

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
                                        radius: NTheme.Theme.radiusSm

                                        color: entryDelegate.selected
                                            ? NTheme.Theme.selectedSurface
                                            : (entryMouse.containsMouse ? NTheme.Theme.hoverStrong : NTheme.Theme.cardBackground)

                                        border.width: NTheme.Theme.borderThin
                                        border.color: entryDelegate.selected
                                            ? NTheme.Theme.selectedBorder
                                            : (modelData.pinned ? NTheme.Theme.primary : NTheme.Theme.borderSubtle)

                                        Behavior on color {
                                            ColorAnimation { duration: NTheme.Theme.animationFast }
                                        }
                                        Behavior on border.color {
                                            ColorAnimation { duration: NTheme.Theme.animationFast }
                                        }

                                        // Left vertical accent indicator bar
                                        Rectangle {
                                            anchors.left: parent.left
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: 3.5
                                            height: entryDelegate.selected ? 26 : 0
                                            radius: 2
                                            color: NTheme.Theme.primary
                                            visible: entryDelegate.selected

                                            Behavior on height {
                                                NumberAnimation { duration: NTheme.Theme.animationFast }
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
                                            radius: NTheme.Theme.radiusSm
                                            color: entryDelegate.selected
                                                ? Qt.rgba(entryDelegate.categoryColor.r, entryDelegate.categoryColor.g, entryDelegate.categoryColor.b, 0.18)
                                                : NTheme.Theme.surfaceContainerHigh

                                            Text {
                                                anchors.centerIn: parent
                                                text: entryDelegate.categoryIcon
                                                color: entryDelegate.categoryColor
                                                font.family: NTheme.Theme.iconFontFamily
                                                font.pixelSize: NTheme.Theme.iconMd
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
                                                color: entryDelegate.selected ? NTheme.Theme.primary : NTheme.Theme.text
                                                font.family: NTheme.Theme.fontFamily
                                                font.pixelSize: NTheme.Theme.fontSizeSm
                                                font.weight: NTheme.Theme.fontWeightDemiBold
                                                elide: Text.ElideRight
                                                maximumLineCount: 1

                                                Behavior on color {
                                                    ColorAnimation { duration: NTheme.Theme.animationFast }
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
                                                        font.family: NTheme.Theme.fontFamily
                                                        font.pixelSize: NTheme.Theme.fontSize2Xs
                                                        font.weight: NTheme.Theme.fontWeightDemiBold
                                                    }
                                                }

                                                // Details text
                                                Text {
                                                    Layout.fillWidth: true
                                                    text: modelData.type === "image"
                                                        ? root.formatBytes(modelData.size_bytes || 0)
                                                        : (modelData.preview ? (modelData.preview.length + " chars") : root.formatBytes(modelData.size_bytes || 0))
                                                    color: NTheme.Theme.mutedText
                                                    font.family: NTheme.Theme.fontFamily
                                                    font.pixelSize: NTheme.Theme.fontSizeXs
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
                                            color: quickPinMouse.containsMouse ? NTheme.Theme.hoverStrong : "transparent"

                                            Text {
                                                anchors.centerIn: parent
                                                text: "󰐃"
                                                color: modelData.pinned ? NTheme.Theme.primary : NTheme.Theme.mutedText
                                                font.family: NTheme.Theme.iconFontFamily
                                                font.pixelSize: NTheme.Theme.iconSm
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
                                    color: NTheme.Theme.mutedText
                                    opacity: 0.5
                                    font.family: NTheme.Theme.iconFontFamily
                                    font.pixelSize: 36
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: searchInput.text.length > 0 ? "No matches found" : "No clips in this filter"
                                    color: NTheme.Theme.mutedText
                                    font.family: NTheme.Theme.fontFamily
                                    font.pixelSize: NTheme.Theme.fontSizeSm
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
                        color: NTheme.Theme.divider
                    }

                    // =============================================
                    // RIGHT COLUMN (PREVIEW & ACTION PANE)
                    // =============================================

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        Layout.fillHeight: true
                        spacing: NTheme.Theme.spacingMd

                        // -----------------------------------------
                        // PREVIEW HEADER
                        // -----------------------------------------
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: NTheme.Theme.spacingMd

                            // Type icon badge
                            Rectangle {
                                width: 40
                                height: 40
                                radius: NTheme.Theme.radiusSm
                                color: root.selectedEntry
                                    ? Qt.rgba(root.getCategoryColor(root.getItemCategory(root.selectedEntry)).r,
                                              root.getCategoryColor(root.getItemCategory(root.selectedEntry)).g,
                                              root.getCategoryColor(root.getItemCategory(root.selectedEntry)).b, 0.16)
                                    : NTheme.Theme.surfaceContainerHigh

                                Text {
                                    anchors.centerIn: parent
                                    text: root.selectedEntry ? root.getCategoryIcon(root.getItemCategory(root.selectedEntry)) : "󰅇"
                                    color: root.selectedEntry ? root.getCategoryColor(root.getItemCategory(root.selectedEntry)) : NTheme.Theme.mutedText
                                    font.family: NTheme.Theme.iconFontFamily
                                    font.pixelSize: NTheme.Theme.iconMd
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
                                    color: NTheme.Theme.text
                                    font.family: NTheme.Theme.fontFamily
                                    font.pixelSize: NTheme.Theme.fontSizeLg
                                    font.weight: NTheme.Theme.fontWeightDemiBold
                                }

                                RowLayout {
                                    spacing: 8
                                    visible: root.selectedEntry !== null

                                    Text {
                                        text: root.formatBytes(root.selectedSize)
                                        color: NTheme.Theme.mutedText
                                        font.family: NTheme.Theme.fontFamily
                                        font.pixelSize: NTheme.Theme.fontSizeXs
                                    }

                                    Text {
                                        visible: root.selectedType === "text" && root.textCharCount > 0
                                        text: "•  " + root.textCharCount + " chars"
                                        color: NTheme.Theme.mutedText
                                        font.family: NTheme.Theme.fontFamily
                                        font.pixelSize: NTheme.Theme.fontSizeXs
                                    }

                                    Text {
                                        visible: root.selectedType === "text" && root.textLineCount > 1
                                        text: "•  " + root.textLineCount + " lines"
                                        color: NTheme.Theme.mutedText
                                        font.family: NTheme.Theme.fontFamily
                                        font.pixelSize: NTheme.Theme.fontSizeXs
                                    }

                                    Text {
                                        visible: root.selectedType === "image" && previewImage.sourceSize.width > 0
                                        text: "•  " + previewImage.sourceSize.width + " × " + previewImage.sourceSize.height + " px"
                                        color: NTheme.Theme.mutedText
                                        font.family: NTheme.Theme.fontFamily
                                        font.pixelSize: NTheme.Theme.fontSizeXs
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
                                radius: NTheme.Theme.radiusSm
                                color: root.selectedEntry && root.selectedEntry.pinned
                                    ? NTheme.Theme.primarySurfaceStrong
                                    : (pinMouse.containsMouse ? NTheme.Theme.hoverStrong : NTheme.Theme.surfaceContainerHigh)
                                opacity: root.selectedEntry ? 1 : NTheme.Theme.opacityDisabled

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰐃"
                                    color: root.selectedEntry && root.selectedEntry.pinned ? NTheme.Theme.primary : NTheme.Theme.text
                                    font.family: NTheme.Theme.iconFontFamily
                                    font.pixelSize: NTheme.Theme.iconSm
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
                                radius: NTheme.Theme.radiusSm
                                color: deleteMouse.containsMouse ? NTheme.Theme.hoverStrong : NTheme.Theme.surfaceContainerHigh
                                opacity: root.selectedEntry ? 1 : NTheme.Theme.opacityDisabled

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰆴"
                                    color: deleteMouse.containsMouse ? NTheme.Theme.error : NTheme.Theme.mutedText
                                    font.family: NTheme.Theme.iconFontFamily
                                    font.pixelSize: NTheme.Theme.iconSm
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
                                radius: NTheme.Theme.radiusSm
                                color: closeMouse.containsMouse ? NTheme.Theme.hoverStrong : NTheme.Theme.surfaceContainerHigh

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰅖"
                                    color: NTheme.Theme.text
                                    font.family: NTheme.Theme.iconFontFamily
                                    font.pixelSize: NTheme.Theme.iconSm
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
                            radius: NTheme.Theme.radiusMd
                            color: NTheme.Theme.surfaceContainerLow
                            border.width: NTheme.Theme.borderThin
                            border.color: NTheme.Theme.borderSubtle
                            clip: true

                            // Empty state
                            Column {
                                anchors.centerIn: parent
                                visible: root.selectedEntry === null
                                spacing: 10

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "󰅈"
                                    color: NTheme.Theme.mutedText
                                    opacity: 0.4
                                    font.family: NTheme.Theme.iconFontFamily
                                    font.pixelSize: 48
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "Select a clip to view details"
                                    color: NTheme.Theme.mutedText
                                    font.family: NTheme.Theme.fontFamily
                                    font.pixelSize: NTheme.Theme.fontSizeMd
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
                                flickDeceleration: NTheme.Theme.flickDeceleration
                                maximumFlickVelocity: NTheme.Theme.flickVelocityMax
                                pixelAligned: true

                                ScrollBar.vertical: ScrollBar {
                                    id: cbScrollBar
                                    policy: ScrollBar.AsNeeded
                                    contentItem: Rectangle {
                                        implicitWidth: 4
                                        radius: 2
                                        color: Qt.rgba(NTheme.Theme.text.r, NTheme.Theme.text.g, NTheme.Theme.text.b, cbScrollBar.hovered ? 0.5 : 0.2)
                                    }
                                }

                                Text {
                                    id: clipboardText
                                    width: textPreview.width
                                    text: root.selectedContent
                                    color: NTheme.Theme.text
                                    font.family: root.isCode(root.selectedContent) ? NTheme.Theme.monoFontFamily : NTheme.Theme.fontFamily
                                    font.pixelSize: NTheme.Theme.fontSizeMd
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
                                    radius: NTheme.Theme.radiusSm
                                    color: NTheme.Theme.surfaceContainer
                                    border.width: NTheme.Theme.borderThin
                                    border.color: NTheme.Theme.borderSubtle
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
                                radius: NTheme.Theme.radiusSm
                                color: openUrlMouse.containsMouse ? NTheme.Theme.hoverStrong : NTheme.Theme.surfaceContainerHigh
                                border.width: NTheme.Theme.borderThin
                                border.color: NTheme.Theme.secondary

                                RowLayout {
                                    id: openUrlContent
                                    anchors.centerIn: parent
                                    spacing: 6

                                    Text {
                                        text: "󰌹"
                                        color: NTheme.Theme.secondary
                                        font.family: NTheme.Theme.iconFontFamily
                                        font.pixelSize: NTheme.Theme.iconSm
                                    }
                                    Text {
                                        text: "Open in Browser"
                                        color: NTheme.Theme.text
                                        font.family: NTheme.Theme.fontFamily
                                        font.pixelSize: NTheme.Theme.fontSizeSm
                                        font.weight: NTheme.Theme.fontWeightMedium
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
                                radius: NTheme.Theme.radiusSm
                                color: openImgMouse.containsMouse ? NTheme.Theme.hoverStrong : NTheme.Theme.surfaceContainerHigh
                                border.width: NTheme.Theme.borderThin
                                border.color: NTheme.Theme.tertiary

                                RowLayout {
                                    id: openImgContent
                                    anchors.centerIn: parent
                                    spacing: 6

                                    Text {
                                        text: "󰋩"
                                        color: NTheme.Theme.tertiary
                                        font.family: NTheme.Theme.iconFontFamily
                                        font.pixelSize: NTheme.Theme.iconSm
                                    }
                                    Text {
                                        text: "Open in Viewer"
                                        color: NTheme.Theme.text
                                        font.family: NTheme.Theme.fontFamily
                                        font.pixelSize: NTheme.Theme.fontSizeSm
                                        font.weight: NTheme.Theme.fontWeightMedium
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
                                radius: NTheme.Theme.radiusSm
                                color: copyBtnMouse.pressed
                                    ? NTheme.Theme.primarySurfaceStrong
                                    : (copyBtnMouse.containsMouse ? NTheme.Theme.primary : NTheme.Theme.primaryContainer)

                                Behavior on color {
                                    ColorAnimation { duration: NTheme.Theme.animationFast }
                                }

                                RowLayout {
                                    id: copyContent
                                    anchors.centerIn: parent
                                    spacing: 8

                                    Text {
                                        text: "󰆏"
                                        color: copyBtnMouse.containsMouse ? NTheme.Theme.primaryText : NTheme.Theme.primaryContainerText
                                        font.family: NTheme.Theme.iconFontFamily
                                        font.pixelSize: NTheme.Theme.iconSm
                                    }
                                    Text {
                                        text: "Copy to Clipboard"
                                        color: copyBtnMouse.containsMouse ? NTheme.Theme.primaryText : NTheme.Theme.primaryContainerText
                                        font.family: NTheme.Theme.fontFamily
                                        font.pixelSize: NTheme.Theme.fontSizeSm
                                        font.weight: NTheme.Theme.fontWeightDemiBold
                                    }
                                    Text {
                                        text: "↵"
                                        color: copyBtnMouse.containsMouse ? NTheme.Theme.primaryText : NTheme.Theme.mutedText
                                        font.family: NTheme.Theme.monoFontFamily
                                        font.pixelSize: NTheme.Theme.fontSizeXs
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
                    color: NTheme.Theme.surfaceContainerLow
                    border.width: NTheme.Theme.borderThin
                    border.color: NTheme.Theme.borderSubtle

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
                                color: NTheme.Theme.surfaceContainerHigh
                                anchors.verticalCenter: parent.verticalCenter
                                Text {
                                    anchors.centerIn: parent
                                    text: "↑↓"
                                    color: NTheme.Theme.mutedText
                                    font.family: NTheme.Theme.monoFontFamily
                                    font.pixelSize: 10
                                }
                            }
                            Text {
                                text: "Navigate"
                                color: NTheme.Theme.mutedText
                                font.family: NTheme.Theme.fontFamily
                                font.pixelSize: NTheme.Theme.fontSizeXs
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        Row {
                            spacing: 5
                            Rectangle {
                                width: 22
                                height: 16
                                radius: 3
                                color: NTheme.Theme.surfaceContainerHigh
                                anchors.verticalCenter: parent.verticalCenter
                                Text {
                                    anchors.centerIn: parent
                                    text: "↵"
                                    color: NTheme.Theme.primary
                                    font.family: NTheme.Theme.monoFontFamily
                                    font.pixelSize: 11
                                    font.weight: Font.Bold
                                }
                            }
                            Text {
                                text: "Copy & Close"
                                color: NTheme.Theme.mutedText
                                font.family: NTheme.Theme.fontFamily
                                font.pixelSize: NTheme.Theme.fontSizeXs
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        Row {
                            spacing: 5
                            Rectangle {
                                width: 18
                                height: 16
                                radius: 3
                                color: NTheme.Theme.surfaceContainerHigh
                                anchors.verticalCenter: parent.verticalCenter
                                Text {
                                    anchors.centerIn: parent
                                    text: "P"
                                    color: NTheme.Theme.mutedText
                                    font.family: NTheme.Theme.monoFontFamily
                                    font.pixelSize: 10
                                }
                            }
                            Text {
                                text: "Pin / Unpin"
                                color: NTheme.Theme.mutedText
                                font.family: NTheme.Theme.fontFamily
                                font.pixelSize: NTheme.Theme.fontSizeXs
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        Row {
                            spacing: 5
                            Rectangle {
                                width: 24
                                height: 16
                                radius: 3
                                color: NTheme.Theme.surfaceContainerHigh
                                anchors.verticalCenter: parent.verticalCenter
                                Text {
                                    anchors.centerIn: parent
                                    text: "Del"
                                    color: NTheme.Theme.mutedText
                                    font.family: NTheme.Theme.monoFontFamily
                                    font.pixelSize: 10
                                }
                            }
                            Text {
                                text: "Delete"
                                color: NTheme.Theme.mutedText
                                font.family: NTheme.Theme.fontFamily
                                font.pixelSize: NTheme.Theme.fontSizeXs
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
                                color: NTheme.Theme.surfaceContainerHigh
                                anchors.verticalCenter: parent.verticalCenter
                                Text {
                                    anchors.centerIn: parent
                                    text: "ESC"
                                    color: NTheme.Theme.mutedText
                                    font.family: NTheme.Theme.monoFontFamily
                                    font.pixelSize: 9
                                }
                            }
                            Text {
                                text: "Close"
                                color: NTheme.Theme.mutedText
                                font.family: NTheme.Theme.fontFamily
                                font.pixelSize: NTheme.Theme.fontSizeXs
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
                radius: NTheme.Theme.radiusPill

                color: NTheme.Theme.surfaceContainerHighest
                border.width: NTheme.Theme.borderThin
                border.color: NTheme.Theme.primary

                opacity: root.toastVisible ? 1 : 0
                scale: root.toastVisible ? 1 : 0.85
                z: 800

                Behavior on opacity {
                    NumberAnimation { duration: 160 }
                }
                Behavior on scale {
                    NumberAnimation { duration: 160; easing.type: Easing.OutBack }
                }

                Row {
                    id: toastRow
                    anchors.centerIn: parent
                    spacing: 8

                    Text {
                        text: "󰄬"
                        color: NTheme.Theme.primary
                        font.family: NTheme.Theme.iconFontFamily
                        font.pixelSize: NTheme.Theme.iconSm
                    }
                    Text {
                        text: root.toastText
                        color: NTheme.Theme.text
                        font.family: NTheme.Theme.fontFamily
                        font.pixelSize: NTheme.Theme.fontSizeSm
                        font.weight: NTheme.Theme.fontWeightDemiBold
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
                    radius: NTheme.Theme.radiusMd
                    color: NTheme.Theme.panelBackgroundElevated
                    border.width: NTheme.Theme.borderThin
                    border.color: NTheme.Theme.borderStrong

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
                            color: NTheme.Theme.errorContainer

                            Text {
                                anchors.centerIn: parent
                                text: "󰆴"
                                color: NTheme.Theme.error
                                font.family: NTheme.Theme.iconFontFamily
                                font.pixelSize: 22
                            }
                        }

                        // Title
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: root.confirmClear ? "Clear Entire Clipboard?" : "Delete Clipboard Item?"
                            color: NTheme.Theme.text
                            font.family: NTheme.Theme.fontFamily
                            font.pixelSize: NTheme.Theme.fontSizeLg
                            font.weight: NTheme.Theme.fontWeightBold
                        }

                        // Subtitle
                        Text {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: root.confirmClear
                                ? "All saved history items will be permanently removed."
                                : "This item will be removed from your clipboard history."
                            color: NTheme.Theme.mutedText
                            font.family: NTheme.Theme.fontFamily
                            font.pixelSize: NTheme.Theme.fontSizeSm
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
                                radius: NTheme.Theme.radiusSm
                                color: modalCancelMouse.containsMouse ? NTheme.Theme.hoverStrong : NTheme.Theme.surfaceContainerHigh
                                border.width: NTheme.Theme.borderThin
                                border.color: NTheme.Theme.borderSubtle

                                Text {
                                    anchors.centerIn: parent
                                    text: "Cancel"
                                    color: NTheme.Theme.text
                                    font.family: NTheme.Theme.fontFamily
                                    font.pixelSize: NTheme.Theme.fontSizeSm
                                    font.weight: NTheme.Theme.fontWeightMedium
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
                                radius: NTheme.Theme.radiusSm
                                color: modalConfirmMouse.containsMouse ? NTheme.Theme.error : NTheme.Theme.errorContainer

                                Text {
                                    anchors.centerIn: parent
                                    text: root.confirmClear ? "Clear All" : "Delete"
                                    color: modalConfirmMouse.containsMouse ? NTheme.Theme.onError : NTheme.Theme.error
                                    font.family: NTheme.Theme.fontFamily
                                    font.pixelSize: NTheme.Theme.fontSizeSm
                                    font.weight: NTheme.Theme.fontWeightDemiBold
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
