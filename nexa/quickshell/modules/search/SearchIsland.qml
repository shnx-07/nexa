import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Quickshell
import Quickshell.Io

import "../../NewNexaUI" as NexaUI
import "../appLauncher" as AppLauncher


Item {
    id: root

    signal accepted()
    signal requestClose()

    property var results: []
    property int selectedIndex: 0

    property string pendingQuery: ""
    property string activeQuery: ""

    property bool queryQueued: false
    property bool searching: false

    // Initial desktop applications cache for zero-query state
    property var initialApps: []

    // ============================================================
    // FLUID DYNAMIC HEIGHT (Based on query and result count)
    // ============================================================

    readonly property real preferredHeight: {
        const queryText = searchInput.text.trim()
        if (queryText.length === 0) {
            // Initial full state: Search Bar (52) + Quick-Launch Row (48) + Apps List
            return 420
        }

        // Active search state
        if (root.results.length === 0) {
            // Compact pill: Search Bar + "No results" message
            return 116
        }

        if (root.results.length === 1) {
            // Snug single-card result (like Postman / Quick action)
            return 140
        }

        if (root.results.length === 2) {
            return 196
        }

        if (root.results.length === 3) {
            return 252
        }

        // 4 or more results: expand up to max 420px
        return Math.min(420, 80 + root.results.length * 56)
    }

    readonly property var currentList: {
        if (searchInput.text.trim().length > 0) {
            return root.results
        }
        return root.initialApps
    }

    // ============================================================
    // RECENT / PINNED APPS FOR QUICK-LAUNCH ROW
    // ============================================================

    readonly property var pinnedApps: [
        { id: "google-chrome", name: "Google Chrome", icon: "google-chrome" },
        { id: "code", name: "VS Code", icon: "/usr/share/pixmaps/vscode.png" },
        { id: "spotify", name: "Spotify", icon: "spotify-client" },
        { id: "discord", name: "Discord", icon: "discord" }
    ]

    // ============================================================
    // ICON RESOLUTION HELPERS
    // ============================================================

    function fileIconName(path) {
        const lower = String(path || "").toLowerCase()
        const lastSlash = lower.lastIndexOf("/")
        const fileName = lastSlash >= 0 ? lower.substring(lastSlash + 1) : lower
        const lastDot = fileName.lastIndexOf(".")
        const ext = lastDot >= 0 ? fileName.substring(lastDot + 1) : ""

        if (ext === "") return "folder"
        if (/^(png|jpe?g|webp|gif|svg|bmp|ico|tiff?|avif|heic)$/.test(ext)) return "image-x-generic"
        if (/^(mp3|flac|wav|ogg|m4a|aac|opus|wma|mid|midi)$/.test(ext)) return "audio-x-generic"
        if (/^(mp4|mkv|webm|mov|avi|flv|wmv|m4v|3gp)$/.test(ext)) return "video-x-generic"
        if (ext === "pdf") return "application-pdf"
        if (/^(docx?|odt|rtf|epub)$/.test(ext)) return "x-office-document"
        if (/^(xlsx?|ods|csv|tsv)$/.test(ext)) return "x-office-spreadsheet"
        if (/^(pptx?|odp)$/.test(ext)) return "x-office-presentation"
        if (/^(zip|tar|gz|bz2|xz|zst|7z|rar|iso|img|dmg)$/.test(ext)) return "package-x-generic"
        if (/^(qml|rs|py|js|mjs|cjs|ts|tsx|jsx|cpp|c|h|hpp|sh|bash|zsh|fish|lua|go|java|kt|php|rb|swift|sql)$/.test(ext)) return "text-x-script"
        if (/^(html?|css|scss|sass|xml)$/.test(ext)) return "text-html"
        if (/^(json|toml|ya?ml|ini|conf|cfg)$/.test(ext)) return "text-x-script"
        if (/^(ttf|otf|woff2?)$/.test(ext)) return "font-ttf"
        return "text-x-generic"
    }

    function fileIconSource(path) {
        const iconName = fileIconName(path)
        if (Quickshell.hasThemeIcon(iconName)) return Quickshell.iconPath(iconName)
        if (Quickshell.hasThemeIcon("text-x-generic")) return Quickshell.iconPath("text-x-generic")
        return "file:///usr/share/icons/breeze/mimetypes/64/text-x-generic.svg"
    }

    function appIconSource(iconName) {
        if (!iconName || iconName.length === 0) {
            return "file:///usr/share/icons/breeze/mimetypes/64/application-x-executable.svg"
        }
        if (iconName.startsWith("/") || iconName.startsWith("file://")) {
            return iconName.startsWith("file://") ? iconName : ("file://" + iconName)
        }
        const appResolved = AppLauncher.AppRegistry.resolveAppIcon(iconName)
        if (appResolved && appResolved.length > 0) {
            return appResolved
        }
        if (Quickshell.hasThemeIcon(iconName)) {
            return Quickshell.iconPath(iconName)
        }
        const lower = iconName.toLowerCase()
        if (Quickshell.hasThemeIcon(lower)) {
            return Quickshell.iconPath(lower)
        }
        return "file:///usr/share/icons/breeze/mimetypes/64/application-x-executable.svg"
    }

    // ============================================================
    // BACKEND PATHS & INVOCATION
    // ============================================================

    readonly property string nexadPath:
        Quickshell.shellDir + "/../rust/target/release/nexad"

    function activate() {
        searchInput.forceActiveFocus()
        searchInput.selectAll()
    }

    function setQuery(text) {
        searchInput.text = text
        searchInput.cursorPosition = text.length
        searchInput.forceActiveFocus()
        queueSearch()
    }

    onVisibleChanged: {
        if (visible) {
            Qt.callLater(activate)
            if (root.initialApps.length === 0) {
                loadInitialApps()
            }
        }
    }

    Component.onCompleted: {
        loadInitialApps()
    }

    function loadInitialApps() {
        initialAppsProcess.command = [root.nexadPath, "search", "query", "a"]
        initialAppsProcess.running = true
    }

    // ============================================================
    // SEARCH EXECUTION & DEBOUNCE
    // ============================================================

    function queueSearch() {
        root.pendingQuery = searchInput.text.trim()
        root.selectedIndex = 0

        if (root.pendingQuery.length === 0) {
            debounce.stop()
            root.results = []
            return
        }

        debounce.restart()
    }

    function runPendingSearch() {
        if (root.pendingQuery.length === 0) {
            root.results = []
            return
        }

        if (queryProcess.running) {
            root.queryQueued = true
            return
        }

        root.queryQueued = false
        root.activeQuery = root.pendingQuery
        root.searching = true

        queryProcess.command = [
            root.nexadPath,
            "search",
            "query",
            root.activeQuery
        ]
        queryProcess.running = true
    }

    function moveSelection(amount) {
        const list = root.currentList
        if (!list || list.length === 0) return

        let next = root.selectedIndex + amount
        if (next < 0) next = list.length - 1
        if (next >= list.length) next = 0

        root.selectedIndex = next
        resultList.positionViewAtIndex(root.selectedIndex, ListView.Contain)
    }

    function openSelected() {
        const list = root.currentList
        if (!list || list.length === 0) return

        const result = list[root.selectedIndex]
        if (!result) return

        launchResult(result)
    }

    function launchResult(result) {
        if (!result) return

        if (result.kind === "command") {
            Quickshell.execDetached([root.nexadPath, "search", "run", result.exec || result.path])
        } else {
            const target = String(result.path && result.path.length > 0 ? result.path : result.id)
            Quickshell.execDetached([root.nexadPath, "search", "open", target])
        }

        root.accepted()
    }

    function launchAppId(appId) {
        Quickshell.execDetached([root.nexadPath, "search", "open", appId])
        root.accepted()
    }

    Timer {
        id: debounce
        interval: 60
        repeat: false
        onTriggered: root.runPendingSearch()
    }

    Process {
        id: queryProcess
        stdout: StdioCollector {
            onStreamFinished: {
                if (root.activeQuery !== root.pendingQuery) return

                try {
                    const parsed = JSON.parse(text)
                    root.results = Array.isArray(parsed) ? parsed : []
                    if (root.selectedIndex >= root.results.length) {
                        root.selectedIndex = 0
                    }
                } catch (error) {
                    root.results = []
                }
            }
        }

        onRunningChanged: {
            if (running) return
            root.searching = false
            if (root.queryQueued || root.pendingQuery !== root.activeQuery) {
                root.runPendingSearch()
            }
        }
    }

    Process {
        id: initialAppsProcess
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parsed = JSON.parse(text)
                    if (Array.isArray(parsed)) {
                        root.initialApps = parsed.filter(item => item.kind === "app" || item.kind === "appimage")
                    }
                } catch (e) {}
            }
        }
    }

    // ============================================================
    // MAIN SPOTLIGHT UI
    // ============================================================

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        // ========================================================
        // 1. SEAMLESS TOP BAR & SCOPE TAGS (Image 2 style)
        // ========================================================

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            spacing: 10

            Text {
                text: searchInput.text.startsWith(">") ? "󰆍" : "󰍉"
                color: searchInput.text.startsWith(">") ? "#e5a93c" : NexaUI.NexaColors.mutedText
                font {
                    family: NexaUI.NexaTypography.familyIcon
                    pixelSize: 20
                }
            }

            TextInput {
                id: searchInput
                focus: true
                Layout.fillWidth: true
                color: NexaUI.NexaColors.text
                selectionColor: NexaUI.NexaColors.primary
                selectedTextColor: NexaUI.NexaColors.onPrimary
                clip: true

                font {
                    family: NexaUI.NexaTypography.familyBody
                    pixelSize: 15
                    weight: Font.Medium
                }

                Text {
                    anchors.fill: parent
                    visible: searchInput.text.length === 0
                    text: "Search applications..."
                    color: NexaUI.NexaColors.mutedText
                    verticalAlignment: Text.AlignVCenter
                    font: searchInput.font
                }

                onTextChanged: root.queueSearch()

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
                        root.openSelected()
                        event.accepted = true
                        return
                    }
                    if (event.key === Qt.Key_Escape) {
                        root.requestClose()
                        event.accepted = true
                        return
                    }
                }
            }

            // Actions scope toggle
            Text {
                text: "<font color='" + NexaUI.NexaColors.primary + "'>&gt;</font> <font color='#8c8f94'>Actions</font>"
                textFormat: Text.RichText
                font.family: NexaUI.NexaTypography.familyBody
                font.pixelSize: 12
                Layout.alignment: Qt.AlignVCenter | Qt.AlignRight

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (searchInput.text.startsWith(">")) {
                            root.setQuery("")
                        } else {
                            root.setQuery("> ")
                        }
                    }
                }
            }
        }

        // ========================================================
        // SEPARATOR LINE BELOW SEARCH BAR
        // ========================================================

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: NexaUI.NexaColors.borderSubtle
            opacity: 0.6
        }

        // ========================================================
        // 2. QUICK-ACCESS PINNED APPS (Image 2 style - borderless circles)
        // ========================================================

        Row {
            id: quickAccessRow
            Layout.fillWidth: true
            Layout.preferredHeight: 38
            spacing: 16
            visible: searchInput.text.trim().length === 0

            Repeater {
                model: root.pinnedApps

                Item {
                    required property var modelData
                    width: 36
                    height: 36

                    Image {
                        anchors.centerIn: parent
                        width: 32
                        height: 32
                        source: root.appIconSource(modelData.icon)
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        sourceSize: Qt.size(64, 64)
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.launchAppId(modelData.id)
                    }
                }
            }
        }

        // ========================================================
        // 3. NO RESULTS STATE
        // ========================================================

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: searchInput.text.trim().length > 0 && root.results.length === 0 && !root.searching

            Text {
                anchors.centerIn: parent
                text: "No results"
                color: NexaUI.NexaColors.mutedText
                font {
                    family: NexaUI.NexaTypography.familyBody
                    pixelSize: NexaUI.NexaTypography.sizeSm
                }
            }
        }

        // ========================================================
        // 4. RESULTS LIST (No scrollbar / sidebar, warm highlight, green star)
        // ========================================================

        ListView {
            id: resultList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 3
            model: root.currentList
            visible: root.currentList.length > 0

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AlwaysOff
            }

            delegate: Rectangle {
                id: resultRow
                required property var modelData
                required property int index

                property bool hovered: false
                readonly property bool selected: index === root.selectedIndex

                width: resultList.width
                height: 52
                radius: 12

                // Wallpaper Matugen primary accent pill (never black)
                color: {
                    if (selected) return NexaUI.NexaColors.alpha(NexaUI.NexaColors.primary, 0.24)
                    if (hovered) return NexaUI.NexaColors.hover
                    return "transparent"
                }

                border.width: selected ? 1 : 0
                border.color: selected ? NexaUI.NexaColors.alpha(NexaUI.NexaColors.primary, 0.40) : "transparent"

                Behavior on color {
                    ColorAnimation { duration: NexaUI.NexaMotion.durationFast }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 14
                    spacing: 12

                    // Direct clean icon (no background box / no border)
                    Item {
                        Layout.preferredWidth: 34
                        Layout.preferredHeight: 34

                        Image {
                            anchors.centerIn: parent
                            width: 32
                            height: 32
                            visible: resultRow.modelData.kind === "app" || resultRow.modelData.kind === "appimage"
                            source: root.appIconSource(resultRow.modelData.icon)
                            sourceSize: Qt.size(64, 64)
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                        }

                        Image {
                            anchors.centerIn: parent
                            width: 30
                            height: 30
                            visible: resultRow.modelData.kind === "file"
                            source: root.fileIconSource(resultRow.modelData.path)
                            sourceSize: Qt.size(64, 64)
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: resultRow.modelData.kind === "command"
                            text: "󰆍"
                            color: NexaUI.NexaColors.primary
                            font.family: NexaUI.NexaTypography.familyIcon
                            font.pixelSize: 20
                        }
                    }

                    // Name and Description / Path
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            Layout.fillWidth: true
                            text: resultRow.modelData.name || ""
                            color: NexaUI.NexaColors.text
                            elide: Text.ElideRight
                            font {
                                family: NexaUI.NexaTypography.familyBody
                                pixelSize: 14
                                weight: resultRow.selected ? Font.Medium : Font.Normal
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: {
                                if (resultRow.modelData.description && resultRow.modelData.description.length > 0)
                                    return resultRow.modelData.description
                                if (resultRow.modelData.kind === "app" || resultRow.modelData.kind === "appimage") return "Application"
                                if (resultRow.modelData.kind === "command") return "Shell Command"
                                return resultRow.modelData.path || ""
                            }
                            color: NexaUI.NexaColors.mutedText
                            elide: Text.ElideRight
                            font {
                                family: NexaUI.NexaTypography.familyBody
                                pixelSize: 12
                            }
                        }
                    }

                    // Enter Key Action for selected item
                    Text {
                        visible: resultRow.selected
                        text: "↵"
                        color: NexaUI.NexaColors.primary
                        font.family: NexaUI.NexaTypography.familyMono
                        font.pixelSize: 15
                        font.weight: Font.Bold
                        Layout.alignment: Qt.AlignVCenter
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor

                    onEntered: {
                        resultRow.hovered = true
                        root.selectedIndex = resultRow.index
                    }
                    onExited: resultRow.hovered = false
                    onClicked: {
                        root.selectedIndex = resultRow.index
                        root.openSelected()
                    }
                }
            }
        }
    }
}
