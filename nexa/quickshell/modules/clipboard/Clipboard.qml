import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../theme" as Nexa
import "../../theme/components" as NexaUI

PanelWindow {
    id: root

    anchors { top: true; bottom: true; left: true; right: true }
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

    property var entries: []
    property var selectedEntry: null
    property string selectedContent: ""
    property int selectedSize: 0
    property string selectedType: ""
    property string selectedImageSource: ""
    property string activeFilter: "all"

    property string toastText: ""
    property bool toastVisible: false

    readonly property string nexadPath: Quickshell.env("HOME") + "/.config/nexa/rust/target/release/nexad"
    readonly property int panelWidth: 920
    readonly property int panelHeight: 640
    readonly property int leftWidth: 350
    readonly property int outerPadding: 16

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

    function getCategoryIcon(cat) {
        switch (cat) {
            case "image": return "󰋩"
            case "link": return "󰌹"
            case "code": return "󰘳"
            default: return "󰅇"
        }
    }

    function getCategoryColor(cat) {
        switch (cat) {
            case "image": return Nexa.Theme.tertiary
            case "link": return Nexa.Theme.secondary
            case "code": return Nexa.Theme.success
            default: return Nexa.Theme.primary
        }
    }

    function getCategoryLabel(cat) {
        switch (cat) {
            case "image": return "IMAGE"
            case "link": return "LINK"
            case "code": return "CODE"
            default: return "TEXT"
        }
    }

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

    readonly property int countAll: entries ? entries.length : 0
    readonly property int countPinned: entries ? entries.filter(e => e.pinned === true).length : 0
    readonly property int countImages: entries ? entries.filter(e => e.type === "image").length : 0
    readonly property int countLinks: entries ? entries.filter(e => getItemCategory(e) === "link").length : 0

    readonly property int textCharCount: selectedContent ? selectedContent.length : 0
    readonly property int textLineCount: selectedContent ? selectedContent.split("\n").length : 0
    readonly property int textWordCount: (!selectedContent || selectedContent.trim().length === 0) ? 0 : selectedContent.trim().split(/\s+/).length

    function triggerToast(msg) {
        toastText = msg
        toastVisible = true
        toastTimer.restart()
    }

    Timer { id: toastTimer; interval: 1300; repeat: false; onTriggered: root.toastVisible = false }
    Timer { id: autoCloseTimer; interval: 140; repeat: false; onTriggered: root.closeClipboard() }

    function selectEntry(entry) {
        if (!entry || !entry.id) return
        selectedEntry = entry
        selectedContent = ""
        selectedImageSource = ""
        selectedType = entry.type || "text"
        selectedSize = entry.size_bytes || 0
        getProcess.exec([nexadPath, "clipboard", "get", entry.id])
    }

    function refresh() { requestSearch(searchInput.text) }

    function requestSearch(query) {
        const trimmed = query.trim()
        loading = true
        if (trimmed.length === 0) {
            listProcess.exec([nexadPath, "clipboard", "list"])
        } else {
            searchProcess.exec([nexadPath, "clipboard", "search", trimmed])
        }
    }

    function copySelected(autoClose = false) {
        if (!selectedEntry) return
        copyProcess.exec([nexadPath, "clipboard", "copy", selectedEntry.id])
        triggerToast("Copied to clipboard!")
        if (autoClose) autoCloseTimer.restart()
    }

    function moveSelection(delta) {
        const list = currentList
        if (!list || list.length === 0) return
        let cur = -1
        if (selectedEntry && selectedEntry.id) {
            for (let i = 0; i < list.length; i++) {
                if (list[i].id === selectedEntry.id) { cur = i; break }
            }
        }
        let next = cur + delta
        if (next < 0) next = 0
        if (next >= list.length) next = list.length - 1
        if (next !== cur && list[next]) {
            selectEntry(list[next])
            historyList.positionViewAtIndex(next, ListView.Beginning)
        }
    }

    function togglePinSelected(target = null) {
        const item = target || selectedEntry
        if (!item || !item.id) return
        const willPin = !item.pinned
        for (let i = 0; i < entries.length; i++) {
            if (entries[i].id === item.id) { entries[i].pinned = willPin; break }
        }
        item.pinned = willPin
        if (selectedEntry && selectedEntry.id === item.id) {
            selectedEntry.pinned = willPin
            selectedEntryChanged()
        }
        triggerToast(willPin ? "Pinned clip" : "Unpinned clip")
        pinProcess.exec([nexadPath, "clipboard", willPin ? "pin" : "unpin", String(item.id)])
    }

    function deleteSelected() {
        if (!selectedEntry) return
        deleteProcess.exec([nexadPath, "clipboard", "delete", selectedEntry.id])
    }

    function clearHistory() {
        clearProcess.exec([nexadPath, "clipboard", "clear"])
    }

    function openSelectedUrl() {
        if (!selectedContent) return
        const url = selectedContent.trim()
        if (url.startsWith("http://") || url.startsWith("https://") || url.startsWith("file://")) {
            Qt.openUrlExternally(url)
            root.closeClipboard()
        }
    }

    function openClipboard() {
        closeTimer.stop()
        autoCloseTimer.stop()
        if (!windowAlive) windowAlive = true
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
        if (clipboardOpen) closeClipboard()
        else openClipboard()
    }

    function handleEntriesPayload(rawText) {
        try {
            const payload = JSON.parse(rawText)
            const targetId = root.selectedEntry ? root.selectedEntry.id : null
            root.entries = payload || []
            let reselected = null
            if (targetId) {
                for (let i = 0; i < root.currentList.length; i++) {
                    if (root.currentList[i].id === targetId) { reselected = root.currentList[i]; break }
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
        } catch (e) {
            console.error("[Clipboard]", e)
            root.entries = []
        }
        root.loading = false
    }

    Process {
        id: listProcess
        stdout: StdioCollector { onStreamFinished: root.handleEntriesPayload(this.text) }
        stderr: StdioCollector { onStreamFinished: { if (this.text.trim()) console.error("[Clipboard:list]", this.text.trim()) } }
    }

    Process {
        id: searchProcess
        stdout: StdioCollector { onStreamFinished: root.handleEntriesPayload(this.text) }
        stderr: StdioCollector { onStreamFinished: { if (this.text.trim()) console.error("[Clipboard:search]", this.text.trim()) } }
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
                } catch (e) { console.error("[Clipboard:get]", e) }
            }
        }
        stderr: StdioCollector { onStreamFinished: { if (this.text.trim()) console.error("[Clipboard:get]", this.text.trim()) } }
    }

    Process {
        id: copyProcess
        stderr: StdioCollector { onStreamFinished: { if (this.text.trim()) console.error("[Clipboard:copy]", this.text.trim()) } }
    }

    Process {
        id: pinProcess
        stdout: StdioCollector { onStreamFinished: { try { JSON.parse(this.text); root.refresh() } catch (e) { console.error("[Clipboard:pin]", e) } } }
        stderr: StdioCollector { onStreamFinished: { if (this.text.trim()) console.error("[Clipboard:pin]", this.text.trim()) } }
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
        stderr: StdioCollector { onStreamFinished: { if (this.text.trim()) console.error("[Clipboard:delete]", this.text.trim()) } }
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
        stderr: StdioCollector { onStreamFinished: { if (this.text.trim()) console.error("[Clipboard:clear]", this.text.trim()) } }
    }

    Timer {
        id: searchDebounce
        interval: 100
        repeat: false
        onTriggered: root.requestSearch(searchInput.text)
    }

    Timer {
        id: closeTimer
        interval: Nexa.Theme.animationFast
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

    // Main Modal Overlay
    Item {
        anchors.fill: parent
        opacity: root.clipboardOpen ? Nexa.Theme.opacityFull : Nexa.Theme.opacityHidden
        scale: root.clipboardOpen ? 1.0 : 0.97

        Behavior on opacity { NumberAnimation { duration: Nexa.Theme.animationFast; easing.type: Nexa.Theme.easingStandard } }
        Behavior on scale { NumberAnimation { duration: Nexa.Theme.animationFast; easing.type: Nexa.Theme.easingStandard } }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: false
            Rectangle { anchors.fill: parent; color: Qt.rgba(0, 0, 0, 0.45) }
            onClicked: root.closeClipboard()
        }

        // Dialog Panel
        Rectangle {
            id: panel
            anchors.centerIn: parent
            width: Math.min(root.panelWidth, parent.width - 40)
            height: Math.min(root.panelHeight, parent.height - 60)
            radius: Nexa.Theme.radiusLg
            color: Nexa.Theme.panelBackground
            border.width: Nexa.Theme.borderThin
            border.color: Nexa.Theme.border
            clip: true

            MouseArea { anchors.fill: parent }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: 1
                color: Nexa.Theme.edgeHighlightStrong
                z: 10
            }

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                // Main body
                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.topMargin: root.outerPadding
                    Layout.leftMargin: root.outerPadding
                    Layout.rightMargin: root.outerPadding
                    Layout.bottomMargin: Nexa.Theme.spacingSm
                    spacing: Nexa.Theme.spacingLg

                    // LEFT COLUMN
                    ColumnLayout {
                        Layout.preferredWidth: root.leftWidth
                        Layout.minimumWidth: root.leftWidth
                        Layout.maximumWidth: root.leftWidth
                        Layout.fillHeight: true
                        spacing: Nexa.Theme.spacingMd

                        // Header
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Nexa.Theme.spacingSm

                            Text {
                                text: "Clipboard"
                                color: Nexa.Theme.text
                                font.family: Nexa.Theme.fontFamily
                                font.pixelSize: Nexa.Theme.fontSizeXl
                                font.weight: Nexa.Theme.fontWeightBold
                            }

                            Rectangle {
                                implicitWidth: countText.implicitWidth + 12
                                implicitHeight: 20
                                radius: Nexa.Theme.radiusPill
                                color: Nexa.Theme.surfaceContainerHigh
                                border.width: Nexa.Theme.borderThin
                                border.color: Nexa.Theme.borderSubtle
                                Text {
                                    id: countText
                                    anchors.centerIn: parent
                                    text: root.entries.length + " clips"
                                    color: Nexa.Theme.mutedText
                                    font.family: Nexa.Theme.fontFamily
                                    font.pixelSize: Nexa.Theme.fontSizeXs
                                    font.weight: Nexa.Theme.fontWeightMedium
                                }
                            }

                            Item { Layout.fillWidth: true }

                            HeaderBtn {
                                icon: "󰑐"
                                onClicked: root.refresh()
                            }
                            HeaderBtn {
                                icon: "󰆴"
                                iconColor: hovered ? Nexa.Theme.error : Nexa.Theme.mutedText
                                onClicked: { root.confirmDelete = false; root.confirmClear = true }
                            }
                        }

                        // Search box
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 40
                            radius: Nexa.Theme.radiusMd
                            color: searchInput.activeFocus ? Nexa.Theme.inputBackgroundFocus : Nexa.Theme.inputBackground
                            border.width: searchInput.activeFocus ? Nexa.Theme.borderNormal : Nexa.Theme.borderThin
                            border.color: searchInput.activeFocus ? Nexa.Theme.focusBorder : Nexa.Theme.borderSubtle
                            Behavior on border.color { ColorAnimation { duration: Nexa.Theme.animationFast } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 10
                                spacing: 8

                                Text {
                                    text: "󰍉"
                                    color: searchInput.activeFocus ? Nexa.Theme.primary : Nexa.Theme.mutedText
                                    font.family: Nexa.Theme.iconFontFamily
                                    font.pixelSize: Nexa.Theme.iconSm
                                    Behavior on color { ColorAnimation { duration: Nexa.Theme.animationFast } }
                                }

                                Item {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true

                                    Text {
                                        anchors.left: parent.left
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: searchInput.text.length === 0
                                        text: "Filter clipboard history..."
                                        color: Nexa.Theme.mutedText
                                        font.family: Nexa.Theme.fontFamily
                                        font.pixelSize: Nexa.Theme.fontSizeSm
                                    }

                                    TextInput {
                                        id: searchInput
                                        anchors.fill: parent
                                        verticalAlignment: TextInput.AlignVCenter
                                        color: Nexa.Theme.text
                                        selectionColor: Nexa.Theme.primary
                                        selectedTextColor: Nexa.Theme.primaryText
                                        font.family: Nexa.Theme.fontFamily
                                        font.pixelSize: Nexa.Theme.fontSizeSm
                                        clip: true
                                        onTextChanged: searchDebounce.restart()

                                        Keys.onPressed: (event) => {
                                            if (event.key === Qt.Key_Down) { root.moveSelection(1); event.accepted = true; return }
                                            if (event.key === Qt.Key_Up) { root.moveSelection(-1); event.accepted = true; return }
                                            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                                if (root.confirmClear) root.clearHistory()
                                                else if (root.confirmDelete) root.deleteSelected()
                                                else root.copySelected(true)
                                                event.accepted = true
                                                return
                                            }
                                            if (event.key === Qt.Key_P && (event.modifiers & Qt.ControlModifier || event.modifiers & Qt.AltModifier)) {
                                                root.togglePinSelected()
                                                event.accepted = true
                                                return
                                            }
                                            if (event.key === Qt.Key_Delete && root.selectedEntry) {
                                                root.confirmClear = false
                                                root.confirmDelete = true
                                                event.accepted = true
                                                return
                                            }
                                            if (event.key === Qt.Key_Escape) {
                                                if (root.confirmClear || root.confirmDelete) {
                                                    root.confirmClear = false; root.confirmDelete = false
                                                    event.accepted = true; return
                                                }
                                                if (searchInput.text.length > 0) {
                                                    searchInput.text = ""
                                                    event.accepted = true; return
                                                }
                                                event.accepted = true
                                                root.closeClipboard()
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    visible: searchInput.text.length > 0
                                    width: 20
                                    height: 20
                                    radius: 10
                                    color: clearSearchMouse.containsMouse ? Nexa.Theme.hoverStrong : Nexa.Theme.surfaceContainerHigh
                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰅖"
                                        color: Nexa.Theme.mutedText
                                        font.family: Nexa.Theme.iconFontFamily
                                        font.pixelSize: Nexa.Theme.icon2Xs
                                    }
                                    MouseArea {
                                        id: clearSearchMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: { searchInput.text = ""; searchInput.forceActiveFocus() }
                                    }
                                }
                            }
                        }

                        // Filter pills
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            FilterPill {
                                label: "All"; count: root.countAll; active: root.activeFilter === "all"
                                onClicked: root.applyFilter("all")
                            }
                            FilterPill {
                                label: "Text"; count: -1; active: root.activeFilter === "text"
                                onClicked: root.applyFilter("text")
                            }
                            FilterPill {
                                label: "Images"; count: root.countImages; active: root.activeFilter === "image"
                                onClicked: root.applyFilter("image")
                            }
                            FilterPill {
                                label: "Links"; count: root.countLinks; active: root.activeFilter === "link"
                                onClicked: root.applyFilter("link")
                            }
                            FilterPill {
                                label: "Pinned"; count: root.countPinned; active: root.activeFilter === "pinned"
                                onClicked: root.applyFilter("pinned")
                            }

                            Item { Layout.fillWidth: true }
                        }

                        // Clips List
                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            ListView {
                                id: historyList
                                anchors.fill: parent
                                clip: true
                                spacing: 6
                                model: root.currentList
                                boundsBehavior: Flickable.StopAtBounds

                                ScrollBar.vertical: ScrollBar {
                                    id: hlScrollBar
                                    policy: ScrollBar.AsNeeded
                                    contentItem: Rectangle {
                                        implicitWidth: 4
                                        radius: 2
                                        color: Qt.rgba(Nexa.Theme.text.r, Nexa.Theme.text.g, Nexa.Theme.text.b, hlScrollBar.hovered ? 0.5 : 0.2)
                                    }
                                }

                                delegate: Item {
                                    id: entryDelegate
                                    required property var modelData
                                    required property int index

                                    width: historyList.width
                                    height: 64

                                    readonly property bool selected: root.selectedEntry && root.selectedEntry.id === modelData.id
                                    readonly property string category: root.getItemCategory(modelData)
                                    readonly property color categoryColor: root.getCategoryColor(category)
                                    readonly property string categoryIcon: root.getCategoryIcon(category)
                                    readonly property string categoryLabel: root.getCategoryLabel(category)

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: Nexa.Theme.radiusSm
                                        color: entryDelegate.selected ? Nexa.Theme.selectedSurface
                                            : (entryMouse.containsMouse ? Nexa.Theme.hoverStrong : Nexa.Theme.cardBackground)
                                        border.width: Nexa.Theme.borderThin
                                        border.color: entryDelegate.selected ? Nexa.Theme.selectedBorder
                                            : (modelData.pinned ? Nexa.Theme.primary : Nexa.Theme.borderSubtle)
                                        Behavior on color { ColorAnimation { duration: Nexa.Theme.animationFast } }
                                        Behavior on border.color { ColorAnimation { duration: Nexa.Theme.animationFast } }

                                        Rectangle {
                                            anchors.left: parent.left
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: 3.5
                                            height: entryDelegate.selected ? 26 : 0
                                            radius: 2
                                            color: Nexa.Theme.primary
                                            visible: entryDelegate.selected
                                            Behavior on height { NumberAnimation { duration: Nexa.Theme.animationFast } }
                                        }
                                    }

                                    MouseArea {
                                        id: entryMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.selectEntry(modelData)
                                        onDoubleClicked: { root.selectEntry(modelData); root.copySelected(true) }
                                    }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 12
                                        anchors.rightMargin: 10
                                        spacing: 10

                                        Rectangle {
                                            Layout.preferredWidth: 38
                                            Layout.preferredHeight: 38
                                            radius: Nexa.Theme.radiusSm
                                            color: entryDelegate.selected
                                                ? Qt.rgba(entryDelegate.categoryColor.r, entryDelegate.categoryColor.g, entryDelegate.categoryColor.b, 0.18)
                                                : Nexa.Theme.surfaceContainerHigh

                                            Text {
                                                anchors.centerIn: parent
                                                text: entryDelegate.categoryIcon
                                                color: entryDelegate.categoryColor
                                                font.family: Nexa.Theme.iconFontFamily
                                                font.pixelSize: Nexa.Theme.iconMd
                                            }
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 3

                                            Text {
                                                Layout.fillWidth: true
                                                text: modelData.type === "image" ? "Image clip" : (modelData.preview || "")
                                                color: entryDelegate.selected ? Nexa.Theme.primary : Nexa.Theme.text
                                                font.family: Nexa.Theme.fontFamily
                                                font.pixelSize: Nexa.Theme.fontSizeSm
                                                font.weight: Nexa.Theme.fontWeightDemiBold
                                                elide: Text.ElideRight
                                                maximumLineCount: 1
                                                Behavior on color { ColorAnimation { duration: Nexa.Theme.animationFast } }
                                            }

                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: 6

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
                                                        font.family: Nexa.Theme.fontFamily
                                                        font.pixelSize: Nexa.Theme.fontSize2Xs
                                                        font.weight: Nexa.Theme.fontWeightDemiBold
                                                    }
                                                }

                                                Text {
                                                    Layout.fillWidth: true
                                                    text: modelData.type === "image"
                                                        ? root.formatBytes(modelData.size_bytes || 0)
                                                        : (modelData.preview ? (modelData.preview.length + " chars") : root.formatBytes(modelData.size_bytes || 0))
                                                    color: Nexa.Theme.mutedText
                                                    font.family: Nexa.Theme.fontFamily
                                                    font.pixelSize: Nexa.Theme.fontSizeXs
                                                    elide: Text.ElideRight
                                                }
                                            }
                                        }

                                        Rectangle {
                                            z: 10
                                            visible: modelData.pinned === true || entryMouse.containsMouse
                                            width: 26
                                            height: 26
                                            radius: 6
                                            color: quickPinMouse.containsMouse ? Nexa.Theme.hoverStrong : "transparent"

                                            Text {
                                                anchors.centerIn: parent
                                                text: "󰐃"
                                                color: modelData.pinned ? Nexa.Theme.primary : Nexa.Theme.mutedText
                                                font.family: Nexa.Theme.iconFontFamily
                                                font.pixelSize: Nexa.Theme.iconSm
                                            }

                                            MouseArea {
                                                id: quickPinMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.togglePinSelected(modelData)
                                            }
                                        }
                                    }
                                }
                            }

                            Column {
                                anchors.centerIn: parent
                                visible: !root.loading && root.currentList.length === 0
                                spacing: 8

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "󰅇"
                                    color: Nexa.Theme.mutedText
                                    opacity: 0.5
                                    font.family: Nexa.Theme.iconFontFamily
                                    font.pixelSize: 36
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: searchInput.text.length > 0 ? "No matches found" : "No clips in this filter"
                                    color: Nexa.Theme.mutedText
                                    font.family: Nexa.Theme.fontFamily
                                    font.pixelSize: Nexa.Theme.fontSizeSm
                                }
                            }
                        }
                    }

                    // DIVIDER
                    Rectangle {
                        Layout.fillHeight: true
                        Layout.preferredWidth: 1
                        Layout.minimumWidth: 1
                        color: Nexa.Theme.borderSubtle
                    }

                    // RIGHT COLUMN (PREVIEW)
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        Layout.fillHeight: true
                        spacing: Nexa.Theme.spacingMd

                        // Preview Header
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Nexa.Theme.spacingMd

                            Rectangle {
                                width: 40
                                height: 40
                                radius: Nexa.Theme.radiusSm
                                color: root.selectedEntry
                                    ? Qt.rgba(root.getCategoryColor(root.getItemCategory(root.selectedEntry)).r,
                                              root.getCategoryColor(root.getItemCategory(root.selectedEntry)).g,
                                              root.getCategoryColor(root.getItemCategory(root.selectedEntry)).b, 0.16)
                                    : Nexa.Theme.surfaceContainerHigh

                                Text {
                                    anchors.centerIn: parent
                                    text: root.selectedEntry ? root.getCategoryIcon(root.getItemCategory(root.selectedEntry)) : "󰅇"
                                    color: root.selectedEntry ? root.getCategoryColor(root.getItemCategory(root.selectedEntry)) : Nexa.Theme.mutedText
                                    font.family: Nexa.Theme.iconFontFamily
                                    font.pixelSize: Nexa.Theme.iconMd
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                Text {
                                    text: {
                                        if (!root.selectedEntry) return "Preview"
                                        const cat = root.getItemCategory(root.selectedEntry)
                                        if (cat === "image") return "Image Clip"
                                        if (cat === "link") return "Web Link"
                                        if (cat === "code") return "Code Snippet"
                                        return "Text Clip"
                                    }
                                    color: Nexa.Theme.text
                                    font.family: Nexa.Theme.fontFamily
                                    font.pixelSize: Nexa.Theme.fontSizeLg
                                    font.weight: Nexa.Theme.fontWeightDemiBold
                                }

                                RowLayout {
                                    spacing: 8
                                    visible: root.selectedEntry !== null

                                    Text {
                                        text: root.formatBytes(root.selectedSize)
                                        color: Nexa.Theme.mutedText
                                        font.family: Nexa.Theme.fontFamily
                                        font.pixelSize: Nexa.Theme.fontSizeXs
                                    }
                                    Text {
                                        visible: root.selectedType === "text" && root.textCharCount > 0
                                        text: "•  " + root.textCharCount + " chars"
                                        color: Nexa.Theme.mutedText
                                        font.family: Nexa.Theme.fontFamily
                                        font.pixelSize: Nexa.Theme.fontSizeXs
                                    }
                                    Text {
                                        visible: root.selectedType === "text" && root.textLineCount > 1
                                        text: "•  " + root.textLineCount + " lines"
                                        color: Nexa.Theme.mutedText
                                        font.family: Nexa.Theme.fontFamily
                                        font.pixelSize: Nexa.Theme.fontSizeXs
                                    }
                                    Text {
                                        visible: root.selectedType === "image" && previewImage.sourceSize.width > 0
                                        text: "•  " + previewImage.sourceSize.width + " × " + previewImage.sourceSize.height + " px"
                                        color: Nexa.Theme.mutedText
                                        font.family: Nexa.Theme.fontFamily
                                        font.pixelSize: Nexa.Theme.fontSizeXs
                                    }
                                }
                            }

                            Item { Layout.fillWidth: true }

                            HeaderBtn {
                                btnSize: 34
                                icon: "󰐃"
                                iconColor: (root.selectedEntry && root.selectedEntry.pinned) ? Nexa.Theme.primary : Nexa.Theme.text
                                enabled: root.selectedEntry !== null
                                opacity: root.selectedEntry ? 1 : Nexa.Theme.opacityDisabled
                                color: (root.selectedEntry && root.selectedEntry.pinned)
                                    ? Nexa.Theme.primarySurfaceStrong
                                    : (hovered ? Nexa.Theme.hoverStrong : Nexa.Theme.surfaceContainerHigh)
                                onClicked: root.togglePinSelected()
                            }

                            HeaderBtn {
                                btnSize: 34
                                icon: "󰆴"
                                iconColor: hovered ? Nexa.Theme.error : Nexa.Theme.mutedText
                                enabled: root.selectedEntry !== null
                                opacity: root.selectedEntry ? 1 : Nexa.Theme.opacityDisabled
                                color: hovered ? Nexa.Theme.hoverStrong : Nexa.Theme.surfaceContainerHigh
                                onClicked: { root.confirmClear = false; root.confirmDelete = true }
                            }

                            HeaderBtn {
                                btnSize: 34
                                icon: "󰅖"
                                iconColor: Nexa.Theme.text
                                color: hovered ? Nexa.Theme.hoverStrong : Nexa.Theme.surfaceContainerHigh
                                onClicked: root.closeClipboard()
                            }
                        }

                        // Preview Canvas
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: Nexa.Theme.radiusMd
                            color: Nexa.Theme.surfaceContainerLow
                            border.width: Nexa.Theme.borderThin
                            border.color: Nexa.Theme.borderSubtle
                            clip: true

                            Column {
                                anchors.centerIn: parent
                                visible: root.selectedEntry === null
                                spacing: 10
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "󰅈"
                                    color: Nexa.Theme.mutedText
                                    opacity: 0.4
                                    font.family: Nexa.Theme.iconFontFamily
                                    font.pixelSize: 48
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "Select a clip to view details"
                                    color: Nexa.Theme.mutedText
                                    font.family: Nexa.Theme.fontFamily
                                    font.pixelSize: Nexa.Theme.fontSizeMd
                                }
                            }

                            Flickable {
                                id: textPreview
                                anchors.fill: parent
                                anchors.margins: 14
                                visible: root.selectedEntry !== null && root.selectedType === "text"
                                contentWidth: width
                                contentHeight: clipboardText.implicitHeight
                                clip: true
                                boundsBehavior: Flickable.StopAtBounds
                                flickDeceleration: Nexa.Theme.flickDeceleration
                                maximumFlickVelocity: Nexa.Theme.flickVelocityMax
                                pixelAligned: true

                                ScrollBar.vertical: ScrollBar {
                                    id: cbScrollBar
                                    policy: ScrollBar.AsNeeded
                                    contentItem: Rectangle {
                                        implicitWidth: 4
                                        radius: 2
                                        color: Qt.rgba(Nexa.Theme.text.r, Nexa.Theme.text.g, Nexa.Theme.text.b, cbScrollBar.hovered ? 0.5 : 0.2)
                                    }
                                }

                                Text {
                                    id: clipboardText
                                    width: textPreview.width
                                    text: root.selectedContent
                                    color: Nexa.Theme.text
                                    font.family: root.isCode(root.selectedContent) ? Nexa.Theme.monoFontFamily : Nexa.Theme.fontFamily
                                    font.pixelSize: Nexa.Theme.fontSizeMd
                                    lineHeight: 1.3
                                    wrapMode: Text.WrapAnywhere
                                    textFormat: Text.PlainText
                                }
                            }

                            Item {
                                anchors.fill: parent
                                anchors.margins: 14
                                visible: root.selectedEntry !== null && root.selectedType === "image"

                                Rectangle {
                                    anchors.fill: parent
                                    radius: Nexa.Theme.radiusSm
                                    color: Nexa.Theme.surfaceContainer
                                    border.width: Nexa.Theme.borderThin
                                    border.color: Nexa.Theme.borderSubtle
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

                        // Preview Action Footer
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            visible: root.selectedEntry !== null

                            Rectangle {
                                visible: root.selectedType === "text" && root.isLink(root.selectedContent)
                                implicitHeight: 36
                                implicitWidth: openUrlContent.implicitWidth + 24
                                radius: Nexa.Theme.radiusSm
                                color: openUrlMouse.containsMouse ? Nexa.Theme.hoverStrong : Nexa.Theme.surfaceContainerHigh
                                border.width: Nexa.Theme.borderThin
                                border.color: Nexa.Theme.secondary

                                RowLayout {
                                    id: openUrlContent
                                    anchors.centerIn: parent
                                    spacing: 6
                                    Text { text: "󰌹"; color: Nexa.Theme.secondary; font.family: Nexa.Theme.iconFontFamily; font.pixelSize: Nexa.Theme.iconSm }
                                    Text { text: "Open in Browser"; color: Nexa.Theme.text; font.family: Nexa.Theme.fontFamily; font.pixelSize: Nexa.Theme.fontSizeSm; font.weight: Nexa.Theme.fontWeightMedium }
                                }
                                MouseArea {
                                    id: openUrlMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: root.openSelectedUrl()
                                }
                            }

                            Rectangle {
                                visible: root.selectedType === "image" && root.selectedImageSource.length > 0
                                implicitHeight: 36
                                implicitWidth: openImgContent.implicitWidth + 24
                                radius: Nexa.Theme.radiusSm
                                color: openImgMouse.containsMouse ? Nexa.Theme.hoverStrong : Nexa.Theme.surfaceContainerHigh
                                border.width: Nexa.Theme.borderThin
                                border.color: Nexa.Theme.tertiary

                                RowLayout {
                                    id: openImgContent
                                    anchors.centerIn: parent
                                    spacing: 6
                                    Text { text: "󰋩"; color: Nexa.Theme.tertiary; font.family: Nexa.Theme.iconFontFamily; font.pixelSize: Nexa.Theme.iconSm }
                                    Text { text: "Open in Viewer"; color: Nexa.Theme.text; font.family: Nexa.Theme.fontFamily; font.pixelSize: Nexa.Theme.fontSizeSm; font.weight: Nexa.Theme.fontWeightMedium }
                                }
                                MouseArea {
                                    id: openImgMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: { Qt.openUrlExternally(root.selectedImageSource); root.closeClipboard() }
                                }
                            }

                            Item { Layout.fillWidth: true }

                            Rectangle {
                                implicitHeight: 36
                                implicitWidth: copyContent.implicitWidth + 24
                                radius: Nexa.Theme.radiusSm
                                color: copyBtnMouse.pressed ? Nexa.Theme.primarySurfaceStrong
                                    : (copyBtnMouse.containsMouse ? Nexa.Theme.primary : Nexa.Theme.primaryContainer)
                                Behavior on color { ColorAnimation { duration: Nexa.Theme.animationFast } }

                                RowLayout {
                                    id: copyContent
                                    anchors.centerIn: parent
                                    spacing: 8
                                    Text { text: "󰆏"; color: copyBtnMouse.containsMouse ? Nexa.Theme.primaryText : Nexa.Theme.primaryContainerText; font.family: Nexa.Theme.iconFontFamily; font.pixelSize: Nexa.Theme.iconSm }
                                    Text { text: "Copy to Clipboard"; color: copyBtnMouse.containsMouse ? Nexa.Theme.primaryText : Nexa.Theme.primaryContainerText; font.family: Nexa.Theme.fontFamily; font.pixelSize: Nexa.Theme.fontSizeSm; font.weight: Nexa.Theme.fontWeightDemiBold }
                                    Text { text: "↵"; color: copyBtnMouse.containsMouse ? Nexa.Theme.primaryText : Nexa.Theme.mutedText; font.family: Nexa.Theme.monoFontFamily; font.pixelSize: Nexa.Theme.fontSizeXs }
                                }
                                MouseArea {
                                    id: copyBtnMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: root.copySelected(true)
                                }
                            }
                        }
                    }
                }

                // Keyboard Shortcuts Bar
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    color: Nexa.Theme.surfaceContainerLow
                    border.width: Nexa.Theme.borderThin
                    border.color: Nexa.Theme.borderSubtle

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: root.outerPadding
                        anchors.rightMargin: root.outerPadding
                        spacing: 16

                        KeyPill { keyText: "↑↓"; label: "Navigate" }
                        KeyPill { keyText: "↵"; label: "Copy & Close"; keyColor: Nexa.Theme.primary }
                        KeyPill { keyText: "P"; label: "Pin / Unpin" }
                        KeyPill { keyText: "Del"; label: "Delete" }
                        Item { Layout.fillWidth: true }
                        KeyPill { keyText: "ESC"; label: "Close" }
                    }
                }
            }

            // Floating Toast
            Rectangle {
                id: toastPill
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 46
                implicitWidth: toastRow.implicitWidth + 24
                implicitHeight: 34
                radius: Nexa.Theme.radiusPill
                color: Nexa.Theme.surfaceContainerHighest
                border.width: Nexa.Theme.borderThin
                border.color: Nexa.Theme.primary
                opacity: root.toastVisible ? 1 : 0
                scale: root.toastVisible ? 1 : 0.85
                z: 800

                Behavior on opacity { NumberAnimation { duration: 160 } }
                Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }

                Row {
                    id: toastRow
                    anchors.centerIn: parent
                    spacing: 8
                    Text { text: "󰄬"; color: Nexa.Theme.primary; font.family: Nexa.Theme.iconFontFamily; font.pixelSize: Nexa.Theme.iconSm }
                    Text { text: root.toastText; color: Nexa.Theme.text; font.family: Nexa.Theme.fontFamily; font.pixelSize: Nexa.Theme.fontSizeSm; font.weight: Nexa.Theme.fontWeightDemiBold }
                }
            }

            // Centered Confirmation Modal
            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0, 0, 0, 0.6)
                visible: root.confirmClear || root.confirmDelete
                z: 900

                Rectangle {
                    anchors.centerIn: parent
                    width: 380
                    implicitHeight: modalColumn.implicitHeight + 40
                    radius: Nexa.Theme.radiusMd
                    color: Nexa.Theme.panelBackgroundElevated
                    border.width: Nexa.Theme.borderThin
                    border.color: Nexa.Theme.borderStrong

                    ColumnLayout {
                        id: modalColumn
                        anchors.fill: parent
                        anchors.margins: 20
                        spacing: 14

                        Rectangle {
                            Layout.alignment: Qt.AlignHCenter
                            width: 44
                            height: 44
                            radius: 22
                            color: Nexa.Theme.errorContainer
                            Text {
                                anchors.centerIn: parent
                                text: "󰆴"
                                color: Nexa.Theme.error
                                font.family: Nexa.Theme.iconFontFamily
                                font.pixelSize: 22
                            }
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: root.confirmClear ? "Clear Entire Clipboard?" : "Delete Clipboard Item?"
                            color: Nexa.Theme.text
                            font.family: Nexa.Theme.fontFamily
                            font.pixelSize: Nexa.Theme.fontSizeLg
                            font.weight: Nexa.Theme.fontWeightBold
                        }

                        Text {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: root.confirmClear
                                ? "All saved history items will be permanently removed."
                                : "This item will be removed from your clipboard history."
                            color: Nexa.Theme.mutedText
                            font.family: Nexa.Theme.fontFamily
                            font.pixelSize: Nexa.Theme.fontSizeSm
                            wrapMode: Text.Wrap
                        }

                        Item { Layout.preferredHeight: 6 }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            NexaUI.NexaButton {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 36
                                text: "Cancel"
                                onClicked: { root.confirmClear = false; root.confirmDelete = false }
                            }

                            NexaUI.NexaButton {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 36
                                text: root.confirmClear ? "Clear All" : "Delete"
                                onClicked: {
                                    if (root.confirmClear) root.clearHistory()
                                    else root.deleteSelected()
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    function applyFilter(f) {
        root.activeFilter = f
        if (root.currentList.length > 0) {
            root.selectEntry(root.currentList[0])
        } else {
            root.selectedEntry = null
            root.selectedContent = ""
            root.selectedImageSource = ""
        }
    }

    // Subcomponents
    component HeaderBtn: Rectangle {
        id: hBtn
        property string icon: ""
        property color iconColor: Nexa.Theme.mutedText
        property color hoverColor: Nexa.Theme.hoverStrong
        property int btnSize: 32
        readonly property bool hovered: hMouse.containsMouse
        signal clicked()

        width: btnSize
        height: btnSize
        radius: Nexa.Theme.radiusSm
        color: hovered ? hoverColor : "transparent"

        Text {
            anchors.centerIn: parent
            text: hBtn.icon
            color: hBtn.iconColor
            font.family: Nexa.Theme.iconFontFamily
            font.pixelSize: Nexa.Theme.iconSm
        }

        MouseArea {
            id: hMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: hBtn.clicked()
        }
    }

    component FilterPill: Rectangle {
        id: pillRoot
        property string label: ""
        property int count: -1
        property bool active: false
        signal clicked()

        implicitHeight: 28
        implicitWidth: pillRow.implicitWidth + 16
        radius: Nexa.Theme.radiusPill
        color: active ? Nexa.Theme.primarySurfaceStrong
                      : pillMouse.containsMouse ? Nexa.Theme.hoverStrong : Nexa.Theme.surfaceContainerLow
        border.width: Nexa.Theme.borderThin
        border.color: active ? Nexa.Theme.primary : Nexa.Theme.borderSubtle
        Behavior on color { ColorAnimation { duration: Nexa.Theme.animationFast } }
        Behavior on border.color { ColorAnimation { duration: Nexa.Theme.animationFast } }

        Row {
            id: pillRow
            anchors.centerIn: parent
            spacing: 4
            Text {
                text: pillRoot.label
                color: pillRoot.active ? Nexa.Theme.primary : (pillMouse.containsMouse ? Nexa.Theme.text : Nexa.Theme.mutedText)
                font.family: Nexa.Theme.fontFamily
                font.pixelSize: Nexa.Theme.fontSizeXs
                font.weight: pillRoot.active ? Nexa.Theme.fontWeightDemiBold : Nexa.Theme.fontWeightNormal
            }
            Text {
                visible: pillRoot.count >= 0
                text: pillRoot.count
                color: pillRoot.active ? Nexa.Theme.primary : Nexa.Theme.mutedText
                opacity: pillRoot.active ? 0.9 : 0.6
                font.family: Nexa.Theme.monoFontFamily
                font.pixelSize: Nexa.Theme.fontSize2Xs
            }
        }

        MouseArea {
            id: pillMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: pillRoot.clicked()
        }
    }

    component KeyPill: Row {
        id: kpRoot
        property string keyText: ""
        property string label: ""
        property color keyColor: Nexa.Theme.mutedText
        spacing: 5

        Rectangle {
            width: Math.max(18, keyLabel.implicitWidth + 8)
            height: 16
            radius: 3
            color: Nexa.Theme.surfaceContainerHigh
            anchors.verticalCenter: parent.verticalCenter
            Text {
                id: keyLabel
                anchors.centerIn: parent
                text: kpRoot.keyText
                color: kpRoot.keyColor
                font.family: Nexa.Theme.monoFontFamily
                font.pixelSize: 10
                font.weight: kpRoot.keyColor === Nexa.Theme.primary ? Font.Bold : Font.Normal
            }
        }
        Text {
            text: kpRoot.label
            color: Nexa.Theme.mutedText
            font.family: Nexa.Theme.fontFamily
            font.pixelSize: Nexa.Theme.fontSizeXs
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
