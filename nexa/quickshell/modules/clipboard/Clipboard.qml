import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Quickshell
import Quickshell.Io

import "../../theme" as NTheme


PanelWindow {
    id: root

    // ============================================================
    // WINDOW
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
    // DATA
    // ============================================================

    property var entries: []
    property var selectedEntry: null

    property string selectedContent: ""
    property int selectedSize: 0
    property string selectedType: ""
    property string selectedImageSource: ""

    // ============================================================
    // BACKEND
    // ============================================================

    readonly property string nexadPath:
        Quickshell.env("HOME")
        + "/.config/nexa/rust/target/release/nexad"

    // ============================================================
    // DIMENSIONS
    // ============================================================

    readonly property int panelWidth: 900
    readonly property int panelHeight: 620
    readonly property int leftWidth: 330
    readonly property int outerPadding: 20

    // ============================================================
    // HELPERS
    // ============================================================

    function formatBytes(bytes) {
        if (bytes < 1024)
            return bytes + " B"

        if (bytes < 1024 * 1024)
            return (bytes / 1024).toFixed(1) + " KB"

        return (bytes / (1024 * 1024)).toFixed(1) + " MB"
    }

    function entryTitle(entry) {
        if (!entry)
            return ""

        if (entry.type === "image")
            return "Image"

        return entry.preview || ""
    }

    function selectEntry(entry) {
        if (!entry || !entry.id)
            return

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
        requestSearch(
            searchInput.text
        )
    }

    function requestSearch(query) {
        const trimmed =
            query.trim()

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

    function copySelected() {
        if (!selectedEntry)
            return

        copyProcess.exec([
            nexadPath,
            "clipboard",
            "copy",
            selectedEntry.id
        ])
    }

    function moveSelection(delta) {
        if (!entries || entries.length === 0)
            return

        let currentIndex = -1
        if (selectedEntry && selectedEntry.id) {
            for (let i = 0; i < entries.length; i++) {
                if (entries[i].id === selectedEntry.id) {
                    currentIndex = i
                    break
                }
            }
        }

        let nextIndex = currentIndex + delta
        if (nextIndex < 0) nextIndex = 0
        if (nextIndex >= entries.length) nextIndex = entries.length - 1

        if (nextIndex !== currentIndex && entries[nextIndex]) {
            selectEntry(entries[nextIndex])
            historyList.positionViewAtIndex(nextIndex, ListView.Beginning)
        }
    }

    function togglePinSelected() {
        if (!selectedEntry)
            return

        const command =
            selectedEntry.pinned
            ? "unpin"
            : "pin"

        pinProcess.exec([
            nexadPath,
            "clipboard",
            command,
            selectedEntry.id
        ])
    }

    function deleteSelected() {
        if (!selectedEntry)
            return

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

    // ============================================================
    // OPEN / CLOSE
    // ============================================================

    function openClipboard() {
        closeTimer.stop()

        if (!windowAlive)
            windowAlive = true

        Qt.callLater(function() {
            clipboardOpen = true

            confirmClear = false
            confirmDelete = false

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
        if (!windowAlive)
            return

        clipboardOpen = false

        confirmClear = false
        confirmDelete = false

        closeTimer.restart()
    }

    function toggleClipboard() {
        if (clipboardOpen)
            closeClipboard()
        else
            openClipboard()
    }

    // ============================================================
    // IPC
    // ============================================================

    IpcHandler {
        target: "clipboard"

        function open(): void {
            root.openClipboard()
        }

        function close(): void {
            root.closeClipboard()
        }

        function toggle(): void {
            root.toggleClipboard()
        }
    }

    // ============================================================
    // LIST
    // ============================================================

    Process {
        id: listProcess

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const payload =
                        JSON.parse(
                            this.text
                        )

                    root.entries =
                        payload || []

                    historyList.positionViewAtBeginning()

                    if (root.entries.length > 0) {
                        root.selectEntry(
                            root.entries[0]
                        )
                    } else {
                        root.selectedEntry = null
                        root.selectedContent = ""
                        root.selectedImageSource = ""
                        root.selectedType = ""
                        root.selectedSize = 0
                    }
                } catch (error) {
                    console.error(
                        "[Clipboard:list]",
                        error
                    )

                    root.entries = []
                }

                root.loading = false
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                const value =
                    this.text.trim()

                if (value.length > 0)
                    console.error(
                        "[Clipboard:list]",
                        value
                    )
            }
        }
    }

    // ============================================================
    // SEARCH
    // ============================================================

    Process {
        id: searchProcess

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const payload =
                        JSON.parse(
                            this.text
                        )

                    root.entries =
                        payload || []

                    historyList.positionViewAtBeginning()

                    if (root.entries.length > 0) {
                        root.selectEntry(
                            root.entries[0]
                        )
                    } else {
                        root.selectedEntry = null
                        root.selectedContent = ""
                        root.selectedImageSource = ""
                        root.selectedType = ""
                        root.selectedSize = 0
                    }
                } catch (error) {
                    console.error(
                        "[Clipboard:search]",
                        error
                    )

                    root.entries = []
                }

                root.loading = false
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                const value =
                    this.text.trim()

                if (value.length > 0)
                    console.error(
                        "[Clipboard:search]",
                        value
                    )
            }
        }
    }

    // ============================================================
    // GET
    // ============================================================

    Process {
        id: getProcess

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const payload =
                        JSON.parse(
                            this.text
                        )

                    root.selectedType =
                        payload.type || "text"

                    root.selectedSize =
                        payload.size_bytes || 0

                    if (root.selectedType === "image") {
                        root.selectedContent = ""

                        root.selectedImageSource =
                            payload.source || ""
                    } else {
                        root.selectedImageSource = ""

                        root.selectedContent =
                            payload.content || ""
                    }

                } catch (error) {
                    console.error(
                        "[Clipboard:get]",
                        error
                    )
                }
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                const value =
                    this.text.trim()

                if (value.length > 0)
                    console.error(
                        "[Clipboard:get]",
                        value
                    )
            }
        }
    }

    // ============================================================
    // COPY
    // ============================================================

    Process {
        id: copyProcess

        stderr: StdioCollector {
            onStreamFinished: {
                const value =
                    this.text.trim()

                if (value.length > 0)
                    console.error(
                        "[Clipboard:copy]",
                        value
                    )
            }
        }
    }

    // ============================================================
    // PIN
    // ============================================================

    Process {
        id: pinProcess

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    JSON.parse(
                        this.text
                    )

                    root.refresh()

                } catch (error) {
                    console.error(
                        "[Clipboard:pin]",
                        error
                    )
                }
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                const value =
                    this.text.trim()

                if (value.length > 0)
                    console.error(
                        "[Clipboard:pin]",
                        value
                    )
            }
        }
    }

    // ============================================================
    // DELETE
    // ============================================================

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
                const value =
                    this.text.trim()

                if (value.length > 0)
                    console.error(
                        "[Clipboard:delete]",
                        value
                    )
            }
        }
    }

    // ============================================================
    // CLEAR
    // ============================================================

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
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                const value =
                    this.text.trim()

                if (value.length > 0)
                    console.error(
                        "[Clipboard:clear]",
                        value
                    )
            }
        }
    }

    // ============================================================
    // TIMERS
    // ============================================================

    Timer {
        id: searchDebounce

        interval: 120
        repeat: false

        onTriggered:
            root.requestSearch(
                searchInput.text
            )
    }

    Timer {
        id: closeTimer

        interval:
            NTheme.Theme.animationFast

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
    // ROOT FADE
    // ============================================================

    Item {
        anchors.fill: parent

        opacity:
            root.clipboardOpen
            ? NTheme.Theme.opacityFull
            : NTheme.Theme.opacityHidden

        Behavior on opacity {
            NumberAnimation {
                duration:
                    root.clipboardOpen
                    ? NTheme.Theme.animationNormal
                    : NTheme.Theme.animationFast

                easing.type:
                    root.clipboardOpen
                    ? NTheme.Theme.easingEnter
                    : NTheme.Theme.easingExit
            }
        }

        MouseArea {
            anchors.fill: parent

            onClicked:
                root.closeClipboard()
        }

        // ========================================================
        // MAIN WINDOW
        // ========================================================

        Rectangle {
            id: panel

            anchors.centerIn:
                parent

            width:
                Math.min(
                    root.panelWidth,
                    parent.width - 50
                )

            height:
                Math.min(
                    root.panelHeight,
                    parent.height - 70
                )

            radius:
                NTheme.Theme.radiusLg

            color:
                NTheme.Theme.popupBackground

            border.width:
                NTheme.Theme.borderThin

            border.color:
                NTheme.Theme.border

            clip: true

            // stop outside click

            MouseArea {
                anchors.fill: parent
            }

            ColumnLayout {
                anchors.fill: parent

                spacing: 0

                // =================================================
                // CONFIRM DELETE / CLEAR
                // =================================================

                Rectangle {
                    Layout.fillWidth: true

                    Layout.preferredHeight:
                        root.confirmClear
                        || root.confirmDelete
                        ? 96
                        : 0

                    visible:
                        Layout.preferredHeight > 0

                    color:
                        NTheme.Theme.panelBackgroundElevated

                    border.width:
                        NTheme.Theme.borderThin

                    border.color:
                        NTheme.Theme.border

                    RowLayout {
                        anchors.fill: parent

                        anchors.margins:
                            NTheme.Theme.spacingLg

                        spacing:
                            NTheme.Theme.spacingLg

                        ColumnLayout {
                            Layout.fillWidth: true

                            spacing:
                                NTheme.Theme.spacingXs

                            Text {
                                text:
                                    root.confirmClear
                                    ? "Clear clipboard history?"
                                    : "Delete clipboard item?"

                                color:
                                    NTheme.Theme.text

                                font.family:
                                    NTheme.Theme.fontFamily

                                font.pixelSize:
                                    NTheme.Theme.fontSizeLg

                                font.weight:
                                    NTheme.Theme.fontWeightDemiBold
                            }

                            Text {
                                text:
                                    root.confirmClear
                                    ? "Every clipboard entry will be removed."
                                    : "The selected clipboard entry will be removed."

                                color:
                                    NTheme.Theme.mutedText

                                font.family:
                                    NTheme.Theme.fontFamily

                                font.pixelSize:
                                    NTheme.Theme.fontSizeSm
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: 82
                            Layout.preferredHeight: 38

                            radius:
                                NTheme.Theme.radiusSm

                            color:
                                cancelMouse.containsMouse
                                ? NTheme.Theme.hoverStrong
                                : NTheme.Theme.buttonBackground

                            Text {
                                anchors.centerIn: parent

                                text: "Cancel"

                                color:
                                    NTheme.Theme.text

                                font.family:
                                    NTheme.Theme.fontFamily

                                font.pixelSize:
                                    NTheme.Theme.fontSizeSm
                            }

                            MouseArea {
                                id: cancelMouse

                                anchors.fill: parent

                                hoverEnabled: true

                                cursorShape:
                                    Qt.PointingHandCursor

                                onClicked: {
                                    root.confirmClear = false
                                    root.confirmDelete = false
                                }
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth:
                                root.confirmClear
                                ? 150
                                : 120

                            Layout.preferredHeight: 38

                            radius:
                                NTheme.Theme.radiusSm

                            color:
                                confirmMouse.containsMouse
                                ? NTheme.Theme.hoverStrong
                                : NTheme.Theme.errorContainer

                            Row {
                                anchors.centerIn:
                                    parent

                                spacing:
                                    NTheme.Theme.spacingSm

                                Text {
                                    text: "󰆴"

                                    color:
                                        NTheme.Theme.error

                                    font.family:
                                        NTheme.Theme.iconFontFamily

                                    font.pixelSize:
                                        NTheme.Theme.iconSm
                                }

                                Text {
                                    text:
                                        root.confirmClear
                                        ? "Clear everything"
                                        : "Delete"

                                    color:
                                        NTheme.Theme.text

                                    font.family:
                                        NTheme.Theme.fontFamily

                                    font.pixelSize:
                                        NTheme.Theme.fontSizeSm
                                }
                            }

                            MouseArea {
                                id: confirmMouse

                                anchors.fill: parent
                                hoverEnabled: true

                                cursorShape:
                                    Qt.PointingHandCursor

                                onClicked: {
                                    if (root.confirmClear)
                                        root.clearHistory()
                                    else
                                        root.deleteSelected()
                                }
                            }
                        }
                    }
                }

                // =================================================
                // BODY
                // =================================================

                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Layout.margins:
                        root.outerPadding

                    spacing:
                        NTheme.Theme.spacingLg

                    // =============================================
                    // LEFT
                    // =============================================

                    ColumnLayout {
                        Layout.preferredWidth:
                            root.leftWidth

                        Layout.fillHeight: true

                        spacing:
                            NTheme.Theme.spacingMd

                        // HEADER

                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                Layout.fillWidth: true

                                text: "Clipboard"

                                color:
                                    NTheme.Theme.text

                                font.family:
                                    NTheme.Theme.fontFamily

                                font.pixelSize:
                                    NTheme.Theme.fontSizeXl

                                font.weight:
                                    NTheme.Theme.fontWeightDemiBold
                            }

                            Rectangle {
                                width: 36
                                height: 36

                                radius:
                                    NTheme.Theme.radiusSm

                                color:
                                    clearMouse.containsMouse
                                    ? NTheme.Theme.hoverStrong
                                    : "transparent"

                                Text {
                                    anchors.centerIn:
                                        parent

                                    text: "󰆴"

                                    color:
                                        NTheme.Theme.error

                                    font.family:
                                        NTheme.Theme.iconFontFamily

                                    font.pixelSize:
                                        NTheme.Theme.iconSm
                                }

                                MouseArea {
                                    id: clearMouse

                                    anchors.fill: parent

                                    hoverEnabled: true

                                    cursorShape:
                                        Qt.PointingHandCursor

                                    onClicked: {
                                        root.confirmDelete = false
                                        root.confirmClear = true
                                    }
                                }

                                NTheme.HoverInfo {
                                    anchors.horizontalCenter:
                                        parent.horizontalCenter

                                    anchors.top:
                                        parent.bottom

                                    anchors.topMargin:
                                        NTheme.Theme.spacingXs

                                    visible:
                                        clearMouse.containsMouse

                                    z: 1000

                                    title: "Clear history"
                                    info: "Remove all items"
                                }
                            }
                        }

                        // SEARCH

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 46

                            radius:
                                NTheme.Theme.radiusSm

                            color:
                                NTheme.Theme.inputBackground

                            border.width:
                                searchInput.activeFocus
                                ? NTheme.Theme.borderNormal
                                : NTheme.Theme.borderThin

                            border.color:
                                searchInput.activeFocus
                                ? NTheme.Theme.focusBorder
                                : NTheme.Theme.border

                            Text {
                                anchors.left:
                                    parent.left

                                anchors.leftMargin:
                                    NTheme.Theme.spacingMd

                                anchors.verticalCenter:
                                    parent.verticalCenter

                                visible:
                                    searchInput.text.length === 0

                                text:
                                    "Filter clipboard..."

                                color:
                                    NTheme.Theme.mutedText

                                font.family:
                                    NTheme.Theme.fontFamily

                                font.pixelSize:
                                    NTheme.Theme.fontSizeMd
                            }

                            TextInput {
                                id: searchInput

                                anchors.fill: parent

                                anchors.leftMargin:
                                    NTheme.Theme.spacingMd

                                anchors.rightMargin:
                                    NTheme.Theme.spacingMd

                                verticalAlignment:
                                    TextInput.AlignVCenter

                                color:
                                    NTheme.Theme.text

                                selectionColor:
                                    NTheme.Theme.primary

                                selectedTextColor:
                                    NTheme.Theme.primaryText

                                font.family:
                                    NTheme.Theme.fontFamily

                                font.pixelSize:
                                    NTheme.Theme.fontSizeMd

                                clip: true

                                onTextChanged:
                                    searchDebounce.restart()

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
                                        root.copySelected()
                                        event.accepted = true
                                        return
                                    }

                                    if (event.key === Qt.Key_Escape) {
                                        event.accepted = true
                                        root.closeClipboard()
                                    }
                                }
                            }
                        }

                        // HISTORY LIST

                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            ListView {
                                id: historyList

                                anchors.fill: parent

                                anchors.rightMargin: 9

                                model:
                                    root.entries

                                spacing:
                                    NTheme.Theme.spacingSm

                                clip: true

                                boundsBehavior:
                                    Flickable.StopAtBounds

                                flickDeceleration:
                                    NTheme.Theme.flickDeceleration

                                maximumFlickVelocity:
                                    NTheme.Theme.flickVelocityMax

                                pixelAligned: true

                                delegate: Item {
                                    id: entryDelegate

                                    required property var modelData

                                    width:
                                        historyList.width

                                    height: 72

                                    readonly property bool selected:
                                        root.selectedEntry
                                        && root.selectedEntry.id
                                           === modelData.id

                                    // -----------------------------------------
                                    // INDIVIDUAL CARD
                                    // -----------------------------------------

                                    Rectangle {
                                        anchors.fill: parent

                                        radius:
                                            NTheme.Theme.radiusSm

                                        color:
                                            entryDelegate.selected
                                            ? NTheme.Theme.selected
                                            : entryMouse.pressed
                                              ? NTheme.Theme.pressed
                                              : entryMouse.containsMouse
                                                ? NTheme.Theme.hoverStrong
                                                : NTheme.Theme.cardBackground

                                        border.width:
                                            NTheme.Theme.borderThin

                                        border.color:
                                            entryDelegate.selected
                                            ? NTheme.Theme.primary
                                            : modelData.pinned
                                              ? NTheme.Theme.primary
                                              : NTheme.Theme.border

                                        Behavior on color {
                                            ColorAnimation {
                                                duration:
                                                    NTheme.Theme.animationFast
                                            }
                                        }

                                        Behavior on border.color {
                                            ColorAnimation {
                                                duration:
                                                    NTheme.Theme.animationFast
                                            }
                                        }
                                    }

                                    RowLayout {
                                        anchors.fill: parent

                                        anchors.leftMargin:
                                            NTheme.Theme.spacingMd

                                        anchors.rightMargin:
                                            NTheme.Theme.spacingMd

                                        spacing:
                                            NTheme.Theme.spacingMd

                                        Rectangle {
                                            Layout.preferredWidth: 40
                                            Layout.preferredHeight: 40

                                            radius:
                                                NTheme.Theme.radiusSm

                                            color:
                                                entryDelegate.selected
                                                ? Qt.rgba(
                                                      1,
                                                      1,
                                                      1,
                                                      0.10
                                                  )
                                                : NTheme.Theme.panelBackgroundElevated

                                            Text {
                                                anchors.centerIn:
                                                    parent

                                                text:
                                                    modelData.type === "image"
                                                    ? "󰋩"
                                                    : "󰅇"

                                                color:
                                                    entryDelegate.selected
                                                    ? NTheme.Theme.selectedText
                                                    : modelData.type === "image"
                                                      ? NTheme.Theme.primary
                                                      : NTheme.Theme.text

                                                font.family:
                                                    NTheme.Theme.iconFontFamily

                                                font.pixelSize:
                                                    NTheme.Theme.iconMd
                                            }
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true

                                            spacing: 3

                                            Text {
                                                Layout.fillWidth: true

                                                text:
                                                    modelData.type === "image"
                                                    ? "Image"
                                                    : modelData.preview || ""

                                                color:
                                                    entryDelegate.selected
                                                    ? NTheme.Theme.selectedText
                                                    : NTheme.Theme.text

                                                font.family:
                                                    NTheme.Theme.fontFamily

                                                font.pixelSize:
                                                    NTheme.Theme.fontSizeSm

                                                font.weight:
                                                    NTheme.Theme.fontWeightDemiBold

                                                elide:
                                                    Text.ElideRight

                                                maximumLineCount: 1
                                            }

                                            Text {
                                                Layout.fillWidth: true

                                                text:
                                                    modelData.type === "image"
                                                    ? (modelData.preview || root.formatBytes(modelData.size_bytes || 0))
                                                    : root.formatBytes(modelData.size_bytes || 0)

                                                color:
                                                    entryDelegate.selected
                                                    ? NTheme.Theme.selectedText
                                                    : NTheme.Theme.mutedText

                                                opacity:
                                                    entryDelegate.selected
                                                    ? 0.78
                                                    : 1

                                                font.family:
                                                    NTheme.Theme.fontFamily

                                                font.pixelSize:
                                                    NTheme.Theme.fontSizeXs

                                                elide:
                                                    Text.ElideRight
                                            }
                                        }

                                        Text {
                                            visible:
                                                modelData.pinned === true

                                            text: "󰐃"

                                            color:
                                                entryDelegate.selected
                                                ? NTheme.Theme.selectedText
                                                : NTheme.Theme.primary

                                            font.family:
                                                NTheme.Theme.iconFontFamily

                                            font.pixelSize:
                                                NTheme.Theme.iconSm
                                        }
                                    }

                                    MouseArea {
                                        id: entryMouse

                                        anchors.fill: parent

                                        hoverEnabled: true

                                        cursorShape:
                                            Qt.PointingHandCursor

                                        onClicked:
                                            root.selectEntry(
                                                modelData
                                            )
                                    }
                                }
                            }

                            // SCROLL BAR

                            Rectangle {
                                anchors.right:
                                    parent.right

                                anchors.top:
                                    parent.top

                                anchors.bottom:
                                    parent.bottom

                                anchors.topMargin: 8
                                anchors.bottomMargin: 8

                                width: 4
                                radius: 2

                                color:
                                    NTheme.Theme.divider

                                visible:
                                    historyList.contentHeight
                                    > historyList.height

                                Rectangle {
                                    width:
                                        parent.width

                                    radius:
                                        parent.radius

                                    color:
                                        NTheme.Theme.borderStrong

                                    height:
                                        Math.max(
                                            28,
                                            parent.height
                                            * historyList.visibleArea.heightRatio
                                        )

                                    y:
                                        (
                                            parent.height
                                            - height
                                        )
                                        * historyList.visibleArea.yPosition
                                        / Math.max(
                                            0.0001,
                                            1
                                            - historyList.visibleArea.heightRatio
                                        )
                                }
                            }

                            Text {
                                anchors.centerIn:
                                    parent

                                visible:
                                    !root.loading
                                    && root.entries.length === 0

                                text:
                                    searchInput.text.length > 0
                                    ? "No clipboard items found"
                                    : "Clipboard is empty"

                                color:
                                    NTheme.Theme.mutedText

                                font.family:
                                    NTheme.Theme.fontFamily

                                font.pixelSize:
                                    NTheme.Theme.fontSizeSm
                            }
                        }
                    }

                    // DIVIDER

                    Rectangle {
                        Layout.fillHeight: true

                        Layout.preferredWidth:
                            NTheme.Theme.borderThin

                        color:
                            NTheme.Theme.divider
                    }

                    // =============================================
                    // RIGHT SIDE
                    // =============================================

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        spacing:
                            NTheme.Theme.spacingMd

                        // HEADER

                        RowLayout {
                            Layout.fillWidth: true

                            spacing:
                                NTheme.Theme.spacingMd

                            Rectangle {
                                width: 40
                                height: 40

                                radius:
                                    NTheme.Theme.radiusSm

                                color:
                                    NTheme.Theme.primaryContainer

                                Text {
                                    anchors.centerIn:
                                        parent

                                    text:
                                        root.selectedType === "image"
                                        ? "󰋩"
                                        : "󰅇"

                                    color:
                                        NTheme.Theme.primaryContainerText

                                    font.family:
                                        NTheme.Theme.iconFontFamily

                                    font.pixelSize:
                                        NTheme.Theme.iconMd
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true

                                spacing: 2

                                Text {
                                    text:
                                        root.selectedType === "image"
                                        ? "Image Clipboard Entry"
                                        : root.selectedEntry
                                          ? "Text Clipboard Entry"
                                          : "Clipboard Entry"

                                    color:
                                        NTheme.Theme.text

                                    font.family:
                                        NTheme.Theme.fontFamily

                                    font.pixelSize:
                                        NTheme.Theme.fontSizeXl

                                    font.weight:
                                        NTheme.Theme.fontWeightDemiBold
                                }

                                Text {
                                    visible:
                                        root.selectedEntry !== null

                                    text:
                                        root.formatBytes(
                                            root.selectedSize
                                        )

                                    color:
                                        NTheme.Theme.mutedText

                                    font.family:
                                        NTheme.Theme.fontFamily

                                    font.pixelSize:
                                        NTheme.Theme.fontSizeSm
                                }
                            }

                            // COPY

                            Rectangle {
                                width: 38
                                height: 38

                                radius:
                                    NTheme.Theme.radiusSm

                                color:
                                    copyMouse.containsMouse
                                    ? NTheme.Theme.hoverStrong
                                    : NTheme.Theme.buttonBackground

                                opacity:
                                    root.selectedEntry
                                    ? 1
                                    : NTheme.Theme.opacityDisabled

                                Text {
                                    anchors.centerIn:
                                        parent

                                    text: "󰆏"

                                    color:
                                        NTheme.Theme.text

                                    font.family:
                                        NTheme.Theme.iconFontFamily

                                    font.pixelSize:
                                        NTheme.Theme.iconSm
                                }

                                MouseArea {
                                    id: copyMouse

                                    anchors.fill: parent

                                    enabled:
                                        root.selectedEntry !== null

                                    hoverEnabled: true

                                    cursorShape:
                                        Qt.PointingHandCursor

                                    onClicked:
                                        root.copySelected()
                                }

                                NTheme.HoverInfo {
                                    anchors.horizontalCenter:
                                        parent.horizontalCenter

                                    anchors.top:
                                        parent.bottom

                                    anchors.topMargin:
                                        NTheme.Theme.spacingXs

                                    visible:
                                        copyMouse.containsMouse

                                    z: 1000

                                    title: "Copy"
                                    info: "Copy item"
                                }
                            }

                            // PIN

                            Rectangle {
                                width: 38
                                height: 38

                                radius:
                                    NTheme.Theme.radiusSm

                                color:
                                    root.selectedEntry
                                    && root.selectedEntry.pinned
                                    ? NTheme.Theme.primaryContainer
                                    : pinMouse.containsMouse
                                      ? NTheme.Theme.hoverStrong
                                      : NTheme.Theme.buttonBackground

                                opacity:
                                    root.selectedEntry
                                    ? 1
                                    : NTheme.Theme.opacityDisabled

                                Text {
                                    anchors.centerIn:
                                        parent

                                    text: "󰐃"

                                    color:
                                        root.selectedEntry
                                        && root.selectedEntry.pinned
                                        ? NTheme.Theme.primary
                                        : NTheme.Theme.text

                                    font.family:
                                        NTheme.Theme.iconFontFamily

                                    font.pixelSize:
                                        NTheme.Theme.iconSm
                                }

                                MouseArea {
                                    id: pinMouse

                                    anchors.fill: parent

                                    enabled:
                                        root.selectedEntry !== null

                                    hoverEnabled: true

                                    cursorShape:
                                        Qt.PointingHandCursor

                                    onClicked:
                                        root.togglePinSelected()
                                }

                                NTheme.HoverInfo {
                                    anchors.horizontalCenter:
                                        parent.horizontalCenter

                                    anchors.top:
                                        parent.bottom

                                    anchors.topMargin:
                                        NTheme.Theme.spacingXs

                                    visible:
                                        pinMouse.containsMouse

                                    z: 1000

                                    title:
                                        root.selectedEntry
                                        && root.selectedEntry.pinned
                                        ? "Unpin"
                                        : "Pin"

                                    info:
                                        root.selectedEntry
                                        && root.selectedEntry.pinned
                                        ? "Remove from pinned"
                                        : "Keep on top"
                                }
                            }

                            // DELETE

                            Rectangle {
                                width: 38
                                height: 38

                                radius:
                                    NTheme.Theme.radiusSm

                                color:
                                    deleteMouse.containsMouse
                                    ? NTheme.Theme.hoverStrong
                                    : NTheme.Theme.buttonBackground

                                opacity:
                                    root.selectedEntry
                                    ? 1
                                    : NTheme.Theme.opacityDisabled

                                Text {
                                    anchors.centerIn:
                                        parent

                                    text: "󰆴"

                                    color:
                                        NTheme.Theme.error

                                    font.family:
                                        NTheme.Theme.iconFontFamily

                                    font.pixelSize:
                                        NTheme.Theme.iconSm
                                }

                                MouseArea {
                                    id: deleteMouse

                                    anchors.fill: parent

                                    enabled:
                                        root.selectedEntry !== null

                                    hoverEnabled: true

                                    cursorShape:
                                        Qt.PointingHandCursor

                                    onClicked: {
                                        root.confirmClear = false
                                        root.confirmDelete = true
                                    }
                                }

                                NTheme.HoverInfo {
                                    anchors.horizontalCenter:
                                        parent.horizontalCenter

                                    anchors.top:
                                        parent.bottom

                                    anchors.topMargin:
                                        NTheme.Theme.spacingXs

                                    visible:
                                        deleteMouse.containsMouse

                                    z: 1000

                                    title: "Delete"
                                    info: "Remove item"
                                }
                            }

                            // CLOSE

                            Rectangle {
                                width: 38
                                height: 38

                                radius:
                                    NTheme.Theme.radiusSm

                                color:
                                    closeMouse.containsMouse
                                    ? NTheme.Theme.hoverStrong
                                    : NTheme.Theme.buttonBackground

                                Text {
                                    anchors.centerIn:
                                        parent

                                    text: "󰅖"

                                    color:
                                        NTheme.Theme.text

                                    font.family:
                                        NTheme.Theme.iconFontFamily

                                    font.pixelSize:
                                        NTheme.Theme.iconSm
                                }

                                MouseArea {
                                    id: closeMouse

                                    anchors.fill: parent

                                    hoverEnabled: true

                                    cursorShape:
                                        Qt.PointingHandCursor

                                    onClicked:
                                        root.closeClipboard()
                                }
                            }
                        }

                        // =========================================
                        // PREVIEW
                        // =========================================

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            radius:
                                NTheme.Theme.radiusMd

                            color:
                                NTheme.Theme.panelBackground

                            border.width:
                                NTheme.Theme.borderThin

                            border.color:
                                NTheme.Theme.border

                            clip: true

                            // -------------------------------------
                            // NO SELECTION
                            // -------------------------------------

                            Text {
                                anchors.centerIn:
                                    parent

                                visible:
                                    root.selectedEntry === null

                                text:
                                    "Select a clipboard item"

                                color:
                                    NTheme.Theme.mutedText

                                font.family:
                                    NTheme.Theme.fontFamily

                                font.pixelSize:
                                    NTheme.Theme.fontSizeSm
                            }

                            // -------------------------------------
                            // TEXT PREVIEW
                            // -------------------------------------

                            Flickable {
                                id: textPreview

                                anchors.fill: parent

                                anchors.margins:
                                    NTheme.Theme.spacingLg

                                visible:
                                    root.selectedEntry !== null
                                    && root.selectedType === "text"

                                contentWidth:
                                    width

                                contentHeight:
                                    clipboardText.implicitHeight

                                clip: true

                                boundsBehavior:
                                    Flickable.StopAtBounds

                                flickDeceleration:
                                    NTheme.Theme.flickDeceleration

                                maximumFlickVelocity:
                                    NTheme.Theme.flickVelocityMax

                                pixelAligned: true

                                ScrollBar.vertical: ScrollBar {
                                    id: cbScrollBar
                                    policy: ScrollBar.AsNeeded

                                    contentItem: Rectangle {
                                        implicitWidth: 3
                                        radius: width / 2
                                        color: Qt.rgba(
                                            NTheme.Theme.text.r,
                                            NTheme.Theme.text.g,
                                            NTheme.Theme.text.b,
                                            cbScrollBar.hovered ? 0.5 : 0.18
                                        )

                                        Behavior on color {
                                            ColorAnimation { duration: NTheme.Theme.animationFast }
                                        }
                                    }

                                    background: null
                                }

                                Text {
                                    id: clipboardText

                                    width:
                                        textPreview.width

                                    text:
                                        root.selectedContent

                                    color:
                                        NTheme.Theme.text

                                    font.family:
                                        NTheme.Theme.monoFontFamily

                                    font.pixelSize:
                                        NTheme.Theme.fontSizeMd

                                    wrapMode:
                                        Text.WrapAnywhere

                                    textFormat:
                                        Text.PlainText
                                }
                            }

                            // -------------------------------------
                            // IMAGE PREVIEW
                            // -------------------------------------

                            Item {
                                anchors.fill: parent

                                anchors.margins:
                                    NTheme.Theme.spacingLg

                                visible:
                                    root.selectedEntry !== null
                                    && root.selectedType === "image"

                                Rectangle {
                                    anchors.fill: parent

                                    radius:
                                        NTheme.Theme.radiusSm

                                    color:
                                        NTheme.Theme.surfaceContainerLow

                                    clip: true

                                    Image {
                                        anchors.fill: parent

                                        anchors.margins:
                                            NTheme.Theme.spacingMd

                                        source:
                                            root.selectedImageSource

                                        fillMode:
                                            Image.PreserveAspectFit

                                        asynchronous: true

                                        cache: false

                                        smooth: true
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
