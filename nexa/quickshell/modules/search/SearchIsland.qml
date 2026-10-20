import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../theme" as Nexa

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
        if (!iconName) return "file:///usr/share/icons/breeze/mimetypes/64/application-x-executable.svg"
        if (iconName.startsWith("/") || iconName.startsWith("file://")) return iconName.startsWith("file://") ? iconName : ("file://" + iconName)
        if (Quickshell.hasThemeIcon(iconName)) return Quickshell.iconPath(iconName)
        const lower = iconName.toLowerCase()
        if (Quickshell.hasThemeIcon(lower)) return Quickshell.iconPath(lower)
        const pixmaps = {
            "code": "file:///usr/share/pixmaps/vscode.png",
            "vscode": "file:///usr/share/pixmaps/vscode.png",
            "alacritty": "file:///usr/share/pixmaps/Alacritty.svg",
            "kitty": "file:///usr/share/pixmaps/kitty.png",
            "nvim": "file:///usr/share/pixmaps/nvim.png",
            "neovim": "file:///usr/share/pixmaps/nvim.png"
        }
        if (pixmaps[lower]) return pixmaps[lower]
        if (Quickshell.hasThemeIcon("application-x-executable")) return Quickshell.iconPath("application-x-executable")
        return "file:///usr/share/icons/breeze/mimetypes/64/application-x-executable.svg"
    }

    readonly property string nexadPath: Quickshell.shellDir + "/../rust/target/release/nexad"

    function activate() {
        searchInput.forceActiveFocus()
        searchInput.selectAll()
    }

    onVisibleChanged: {
        if (visible) Qt.callLater(() => searchInput.forceActiveFocus())
    }

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
        if (root.pendingQuery.length === 0) { root.results = []; return }
        if (queryProcess.running) { root.queryQueued = true; return }
        root.queryQueued = false
        root.activeQuery = root.pendingQuery
        root.searching = true
        queryProcess.command = [root.nexadPath, "search", "query", root.activeQuery]
        queryProcess.running = true
    }

    function moveSelection(amount) {
        if (root.results.length === 0) return
        let next = root.selectedIndex + amount
        if (next < 0) next = root.results.length - 1
        if (next >= root.results.length) next = 0
        root.selectedIndex = next
        resultList.positionViewAtIndex(root.selectedIndex, ListView.Contain)
    }

    function openSelected() {
        if (root.results.length === 0) return
        const result = root.results[root.selectedIndex]
        if (!result) return
        openProcess.command = [
            root.nexadPath,
            "search",
            "open",
            String(result.path && result.path.length > 0 ? result.path : result.id)
        ]
        openProcess.running = true
        root.accepted()
    }

    Timer {
        id: debounce
        interval: 90
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
                    if (root.selectedIndex >= root.results.length) root.selectedIndex = 0
                } catch (e) {
                    console.warn("NEXA search JSON error:", e)
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

    Process { id: openProcess }

    // Search Input Bar
    Rectangle {
        id: searchBox
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            topMargin: Nexa.Theme.spacingLg
            leftMargin: Nexa.Theme.spacingLg
            rightMargin: Nexa.Theme.spacingLg
        }
        height: 52
        radius: Nexa.Theme.radiusMd
        color: Nexa.Theme.inputBackgroundFocus
        border.width: Nexa.Theme.borderNormal
        border.color: searchInput.activeFocus ? Nexa.Theme.primary : Nexa.Theme.border
        Behavior on border.color { ColorAnimation { duration: Nexa.Theme.animationFast } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Nexa.Theme.spacingLg
            anchors.rightMargin: Nexa.Theme.spacingLg
            spacing: Nexa.Theme.spacingMd

            Text {
                text: "󰍉"
                color: Nexa.Theme.primary
                font.family: Nexa.Theme.iconFontFamily
                font.pixelSize: Nexa.Theme.iconMd
            }

            TextInput {
                id: searchInput
                focus: true
                Layout.fillWidth: true
                color: Nexa.Theme.text
                selectionColor: Nexa.Theme.primary
                selectedTextColor: Nexa.Theme.primaryText
                clip: true
                font.family: Nexa.Theme.fontFamily
                font.pixelSize: Nexa.Theme.fontSizeLg
                font.weight: Nexa.Theme.fontWeightMedium

                Text {
                    anchors.fill: parent
                    visible: searchInput.text.length === 0
                    text: "Search apps and files..."
                    color: Nexa.Theme.mutedText
                    verticalAlignment: Text.AlignVCenter
                    font: searchInput.font
                }

                onTextChanged: root.queueSearch()

                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_Down) { root.moveSelection(1); event.accepted = true; return }
                    if (event.key === Qt.Key_Up) { root.moveSelection(-1); event.accepted = true; return }
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { root.openSelected(); event.accepted = true; return }
                    if (event.key === Qt.Key_Escape) { root.requestClose(); event.accepted = true }
                }
            }

            Text {
                visible: root.searching
                text: "Searching…"
                color: Nexa.Theme.mutedText
                font.family: Nexa.Theme.fontFamily
                font.pixelSize: Nexa.Theme.fontSizeXs
            }

            Rectangle {
                width: 38
                height: 24
                radius: Nexa.Theme.radiusSm
                color: Nexa.Theme.surfaceContainerHigh
                visible: searchInput.text.length > 0
                Text {
                    anchors.centerIn: parent
                    text: "ESC"
                    color: Nexa.Theme.mutedText
                    font.family: Nexa.Theme.monoFontFamily
                    font.pixelSize: Nexa.Theme.fontSize2Xs
                }
            }
        }
    }

    // Results Area
    Rectangle {
        anchors {
            top: searchBox.bottom
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            topMargin: Nexa.Theme.spacingMd
            leftMargin: Nexa.Theme.spacingLg
            rightMargin: Nexa.Theme.spacingLg
            bottomMargin: Nexa.Theme.spacingLg
        }
        radius: Nexa.Theme.radiusMd
        color: Nexa.Theme.cardBackground
        border.width: Nexa.Theme.borderThin
        border.color: Nexa.Theme.border
        clip: true

        // Empty state
        Column {
            anchors.centerIn: parent
            visible: searchInput.text.length === 0
            spacing: Nexa.Theme.spacingSm
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "󰍉"
                color: Nexa.Theme.mutedText
                font.family: Nexa.Theme.iconFontFamily
                font.pixelSize: Nexa.Theme.icon2Xl
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Search applications and files"
                color: Nexa.Theme.mutedText
                font.family: Nexa.Theme.fontFamily
                font.pixelSize: Nexa.Theme.fontSizeSm
            }
        }

        // No results
        Text {
            anchors.centerIn: parent
            visible: searchInput.text.length > 0 && !root.searching && root.results.length === 0
            text: "No results"
            color: Nexa.Theme.mutedText
            font.family: Nexa.Theme.fontFamily
            font.pixelSize: Nexa.Theme.fontSizeSm
        }

        // Results ListView
        ListView {
            id: resultList
            anchors { fill: parent; margins: Nexa.Theme.spacingSm }
            visible: root.results.length > 0
            model: root.results
            spacing: Nexa.Theme.spacingXs
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            flickDeceleration: Nexa.Theme.flickDeceleration
            maximumFlickVelocity: Nexa.Theme.flickVelocityMax
            pixelAligned: true

            ScrollBar.vertical: ScrollBar {
                id: searchScrollBar
                policy: ScrollBar.AsNeeded
                contentItem: Rectangle {
                    implicitWidth: 3
                    radius: width / 2
                    color: Qt.rgba(Nexa.Theme.text.r, Nexa.Theme.text.g, Nexa.Theme.text.b, searchScrollBar.hovered ? 0.5 : 0.18)
                    Behavior on color { ColorAnimation { duration: Nexa.Theme.animationFast } }
                }
                background: null
            }

            delegate: Rectangle {
                id: resultRow
                required property var modelData
                required property int index
                property bool hovered: false
                readonly property bool selected: index === root.selectedIndex

                width: resultList.width
                height: 52
                radius: Nexa.Theme.radiusSm
                color: selected ? Nexa.Theme.hoverStrong : (hovered ? Nexa.Theme.hover : "transparent")
                border.width: selected ? Nexa.Theme.borderThin : 0
                border.color: Nexa.Theme.primary
                Behavior on color { ColorAnimation { duration: Nexa.Theme.animationFast } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Nexa.Theme.spacingMd
                    anchors.rightMargin: Nexa.Theme.spacingMd
                    spacing: Nexa.Theme.spacingMd

                    Rectangle {
                        Layout.preferredWidth: 36
                        Layout.preferredHeight: 36
                        radius: Nexa.Theme.radiusSm
                        color: resultRow.selected ? Nexa.Theme.primaryContainer : Nexa.Theme.surfaceContainerHigh

                        Image {
                            id: appIconImage
                            anchors.centerIn: parent
                            width: 26
                            height: 26
                            visible: resultRow.modelData.kind === "app" || resultRow.modelData.kind === "appimage"
                            source: root.appIconSource(resultRow.modelData.icon)
                            sourceSize.width: width
                            sourceSize.height: height
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            onStatusChanged: {
                                if (status === Image.Error && source !== "file:///usr/share/icons/breeze/mimetypes/64/application-x-executable.svg") {
                                    source = "file:///usr/share/icons/breeze/mimetypes/64/application-x-executable.svg"
                                }
                            }
                        }

                        Image {
                            anchors.centerIn: parent
                            width: 26
                            height: 26
                            visible: resultRow.modelData.kind === "file"
                            source: root.fileIconSource(resultRow.modelData.path)
                            sourceSize.width: width
                            sourceSize.height: height
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            onStatusChanged: {
                                if (status === Image.Error && source !== "file:///usr/share/icons/breeze/mimetypes/64/text-x-generic.svg") {
                                    source = "file:///usr/share/icons/breeze/mimetypes/64/text-x-generic.svg"
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        Text {
                            Layout.fillWidth: true
                            text: resultRow.modelData.name
                            color: Nexa.Theme.text
                            elide: Text.ElideRight
                            font.family: Nexa.Theme.fontFamily
                            font.pixelSize: Nexa.Theme.fontSizeSm
                            font.weight: resultRow.selected ? Nexa.Theme.fontWeightDemiBold : Nexa.Theme.fontWeightMedium
                        }

                        Text {
                            Layout.fillWidth: true
                            text: (resultRow.modelData.description && resultRow.modelData.description.length > 0)
                                ? resultRow.modelData.description
                                : (resultRow.modelData.kind === "app" ? "Application" :
                                   resultRow.modelData.kind === "appimage" ? "AppImage Executable" :
                                   (resultRow.modelData.path || ""))
                            color: Nexa.Theme.mutedText
                            elide: Text.ElideMiddle
                            font.family: Nexa.Theme.monoFontFamily
                            font.pixelSize: Nexa.Theme.fontSize2Xs
                        }
                    }

                    Text {
                        text: resultRow.modelData.kind === "app" ? "APP" : (resultRow.modelData.kind === "appimage" ? "APPIMAGE" : "FILE")
                        color: resultRow.selected ? Nexa.Theme.primary : Nexa.Theme.mutedText
                        font.family: Nexa.Theme.monoFontFamily
                        font.pixelSize: Nexa.Theme.fontSize2Xs
                        font.weight: Nexa.Theme.fontWeightDemiBold
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
