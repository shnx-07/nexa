import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../theme" as Nexa

Item {
    id: root

    signal requestClose()

    readonly property string nexadPath:
        Quickshell.env("HOME") + "/.config/nexa/rust/target/release/nexad"

    property var shelfItems: []
    property bool loading: false
    property string toastMessage: ""
    property bool toastActive: false
    property bool dragInProgress: false

    onVisibleChanged: {
        if (visible) {
            root.dragInProgress = false
            root.refresh()
        }
    }

    Component.onCompleted: {
        refresh()
    }

    Timer {
        id: toastTimer
        interval: 1800
        repeat: false
        onTriggered: root.toastActive = false
    }

    function showToast(msg) {
        root.toastMessage = msg
        root.toastActive = true
        toastTimer.restart()
    }

    function refresh() {
        root.loading = true
        listProcess.exec([root.nexadPath, "shelf", "list"])
    }

    // Add one or more files in a single nexad invocation (no race condition)
    function addFiles(urls) {
        if (!urls || urls.length === 0) return
        const cmd = [root.nexadPath, "shelf", "add"].concat(Array.from(urls))
        addProcess.exec(cmd)
    }

    function removeFile(id) {
        removeProcess.exec([root.nexadPath, "shelf", "remove", id])
    }

    function copySingleItem(item) {
        if (!item) return
        Quickshell.execDetached([root.nexadPath, "shelf", "copy-item", item.id])
        root.showToast("✓ Copied to clipboard")
    }

    function copyAll() {
        if (!root.shelfItems || root.shelfItems.length === 0) return
        Quickshell.execDetached([root.nexadPath, "shelf", "copy-all"])
        root.showToast("✓ Copied " + root.shelfItems.length + " file(s)")
        // Close shelf after a brief moment so the user sees the toast
        closeAfterCopyTimer.restart()
    }

    Timer {
        id: closeAfterCopyTimer
        interval: 900
        repeat: false
        onTriggered: root.requestClose()
    }

    function clearShelf() {
        Quickshell.execDetached([root.nexadPath, "shelf", "clear"])
        root.shelfItems = []
        root.showToast("Cleared")
        root.requestClose()
    }

    // ============================================================
    // PROCESSES
    // ============================================================

    Process {
        id: listProcess
        stdout: StdioCollector {
            onStreamFinished: {
                root.loading = false
                try {
                    const text = this.text.trim()
                    if (text.length > 0) {
                        root.shelfItems = JSON.parse(text)
                    } else {
                        root.shelfItems = []
                    }
                } catch (e) {
                    root.shelfItems = []
                }
            }
        }
    }

    Process {
        id: addProcess
        stdout: StdioCollector {
            onStreamFinished: root.refresh()
        }
    }

    Process {
        id: removeProcess
        stdout: StdioCollector {
            onStreamFinished: root.refresh()
        }
    }

    // ============================================================
    // TOP HEADER (SLEEK MINIMALIST APPLE TRAY)
    // ============================================================

    Item {
        id: headerRow
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: 10
        anchors.leftMargin: 18
        anchors.rightMargin: 18
        height: 24

        // Left: NotchNook-style Glass Tab Chip
        Rectangle {
            id: tabChip
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            height: 22
            width: tabContent.implicitWidth + 16
            radius: 11
            color: Nexa.Theme.primarySurface
            border.color: Nexa.Theme.border
            border.width: 1

            RowLayout {
                id: tabContent
                anchors.centerIn: parent
                spacing: 5

                Text {
                    text: "󰉋"
                    font.family: Nexa.Theme.iconFontFamily
                    font.pixelSize: 12
                    color: Nexa.Theme.primary
                    verticalAlignment: Text.AlignVCenter
                }

                Text {
                    text: "Tray"
                    font.family: Nexa.Theme.fontFamily
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    color: Nexa.Theme.text
                    verticalAlignment: Text.AlignVCenter
                }

                Text {
                    text: (root.shelfItems ? root.shelfItems.length : 0) + ""
                    font.family: Nexa.Theme.fontFamily
                    font.pixelSize: 10
                    font.weight: Font.Bold
                    color: Nexa.Theme.mutedText
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }

        // Center: Toast Notification
        Rectangle {
            id: toastPill
            anchors.centerIn: parent
            height: 24
            width: toastText.implicitWidth + 24
            radius: 12
            color: Nexa.Theme.surfaceContainerHighest
            border.color: Nexa.Theme.border
            border.width: 1
            visible: opacity > 0
            opacity: root.toastActive ? 1.0 : 0.0

            Behavior on opacity {
                NumberAnimation { duration: 150 }
            }

            Text {
                id: toastText
                anchors.centerIn: parent
                text: root.toastMessage
                font.family: Nexa.Theme.fontFamily
                font.pixelSize: 11
                font.weight: Font.Medium
                color: Nexa.Theme.text
            }
        }

        // Right Action Buttons
        RowLayout {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            // Copy All Button
            Rectangle {
                id: copyAllBtn
                height: 22
                width: copyLayout.implicitWidth + 14
                radius: 11
                color: copyHover.containsMouse ? Nexa.Theme.hoverStrong : Nexa.Theme.surfaceContainerHigh
                border.color: copyHover.containsMouse ? Nexa.Theme.primary : Nexa.Theme.border
                border.width: 1
                opacity: (root.shelfItems && root.shelfItems.length > 0) ? 1.0 : 0.4
                enabled: root.shelfItems && root.shelfItems.length > 0

                Behavior on color { ColorAnimation { duration: 120 } }
                Behavior on border.color { ColorAnimation { duration: 120 } }

                RowLayout {
                    id: copyLayout
                    anchors.centerIn: parent
                    spacing: 4

                    Text {
                        text: "󰆏"
                        font.family: Nexa.Theme.iconFontFamily
                        font.pixelSize: 11
                        color: Nexa.Theme.primary
                    }

                    Text {
                        text: "Copy All"
                        font.family: Nexa.Theme.fontFamily
                        font.pixelSize: 10
                        font.weight: Font.Medium
                        color: Nexa.Theme.text
                    }
                }

                MouseArea {
                    id: copyHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.copyAll()
                }
            }

            // Clear Button
            Rectangle {
                id: clearBtn
                height: 22
                width: clearLayout.implicitWidth + 14
                radius: 11
                color: clearHover.containsMouse ? Qt.rgba(Nexa.Theme.error.r, Nexa.Theme.error.g, Nexa.Theme.error.b, 0.22) : Nexa.Theme.surfaceContainerHigh
                border.color: clearHover.containsMouse ? Nexa.Theme.error : Nexa.Theme.border
                border.width: 1
                opacity: (root.shelfItems && root.shelfItems.length > 0) ? 1.0 : 0.4
                enabled: root.shelfItems && root.shelfItems.length > 0

                Behavior on color { ColorAnimation { duration: 120 } }
                Behavior on border.color { ColorAnimation { duration: 120 } }

                RowLayout {
                    id: clearLayout
                    anchors.centerIn: parent
                    spacing: 4

                    Text {
                        text: "󰆴"
                        font.family: Nexa.Theme.iconFontFamily
                        font.pixelSize: 11
                        color: clearHover.containsMouse ? Nexa.Theme.error : Nexa.Theme.mutedText
                    }

                    Text {
                        text: "Clear"
                        font.family: Nexa.Theme.fontFamily
                        font.pixelSize: 10
                        font.weight: Font.Medium
                        color: clearHover.containsMouse ? Nexa.Theme.error : Nexa.Theme.mutedText
                    }
                }

                MouseArea {
                    id: clearHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.clearShelf()
                }
            }

            // Close Button
            Rectangle {
                id: closeBtn
                height: 22
                width: 22
                radius: 11
                color: closeHover.containsMouse ? Nexa.Theme.hoverStrong : Nexa.Theme.surfaceContainerHigh
                border.color: closeHover.containsMouse ? Nexa.Theme.borderStrong : Nexa.Theme.border
                border.width: 1

                Behavior on color { ColorAnimation { duration: 120 } }
                Behavior on border.color { ColorAnimation { duration: 120 } }

                Text {
                    anchors.centerIn: parent
                    text: "✕"
                    font.family: Nexa.Theme.fontFamily
                    font.pixelSize: 10
                    font.weight: Font.Bold
                    color: closeHover.containsMouse ? Nexa.Theme.text : Nexa.Theme.mutedText
                }

                MouseArea {
                    id: closeHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.requestClose()
                }
            }
        }
    }

    // ============================================================
    // BODY / CARDS AREA
    // ============================================================

    Item {
        id: bodyArea
        anchors.top: headerRow.bottom
        anchors.topMargin: 8
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 8
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 18
        anchors.rightMargin: 18

        // DropArea for incoming files onto the tray (handled at Island level too)
        DropArea {
            anchors.fill: parent
            onEntered: drag => drag.acceptProposedAction()
            onDropped: drop => {
                if (drop.hasUrls) {
                    // Pass all URLs in one nexad call — no concurrent write race
                    root.addFiles(drop.urls)
                    drop.acceptProposedAction()
                    shelfBodyAutoCloseTimer.restart()
                }
            }
        }

        Timer {
            id: shelfBodyAutoCloseTimer
            interval: 1200
            repeat: false
            onTriggered: root.requestClose()
        }

        // Empty Placeholder
        Item {
            anchors.fill: parent
            visible: !root.shelfItems || root.shelfItems.length === 0

            Rectangle {
                anchors.fill: parent
                radius: 12
                color: Nexa.Theme.surfaceContainerLow
                border.color: Nexa.Theme.borderSubtle
                border.width: 1

                Row {
                    anchors.centerIn: parent
                    spacing: 12

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "󰇚"
                        font.family: Nexa.Theme.iconFontFamily
                        font.pixelSize: 22
                        color: Nexa.Theme.mutedText
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Drag & drop files here to stash"
                        font.family: Nexa.Theme.fontFamily
                        font.pixelSize: 12
                        color: Nexa.Theme.mutedText
                    }
                }
            }
        }

        // Active Files Horizontal List
        ListView {
            id: cardsList
            anchors.fill: parent
            visible: root.shelfItems && root.shelfItems.length > 0
            orientation: ListView.Horizontal
            spacing: 18
            clip: true
            model: root.shelfItems

            delegate: Item {
                id: cardItem
                width: 88
                height: bodyArea.height

                // --------------------------------------------------------
                // WAYLAND DRAG-OUT CONFIGURATION
                //
                // dragType: Drag.Automatic means Qt drives the OS-level
                // Wayland DnD session when Drag.start() is called.
                //
                // We do NOT set drag.target on the MouseArea — that only
                // moves an item inside the QML scene.  Instead we call
                // cardItem.Drag.start(Qt.CopyAction) manually once the
                // pointer has moved far enough.
                // --------------------------------------------------------

                Drag.dragType: Drag.Automatic
                Drag.supportedActions: Qt.CopyAction | Qt.MoveAction
                Drag.proposedAction: Qt.CopyAction
                Drag.mimeData: {
                    "text/uri-list": modelData.uri + "\r\n",
                    "text/plain": modelData.path
                }
                Drag.hotSpot.x: 32
                Drag.hotSpot.y: 32

                // When the drag session begins with the compositor, close the shelf
                // so the user can see and drop onto windows underneath.
                Drag.onDragStarted: {
                    root.requestClose()
                }

                // When the system drag finishes (drop or cancel), reset state
                Drag.onDragFinished: dropAction => {
                    root.dragInProgress = false
                    cardMouse.dragStarted = false
                }

                // --------------------------------------------------------
                // POLAROID CARD
                // --------------------------------------------------------

                Rectangle {
                    id: polaroidFrame
                    anchors.top: parent.top
                    anchors.topMargin: 4
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 64
                    height: 64
                    radius: 8
                    color: Nexa.Theme.surfaceContainerHigh
                    border.color: cardMouse.containsMouse ? Nexa.Theme.primary : Nexa.Theme.border
                    border.width: cardMouse.containsMouse ? 2 : 1.5

                    // Drop shadow
                    Rectangle {
                        anchors.fill: parent
                        anchors.topMargin: 2
                        anchors.leftMargin: 1
                        z: -1
                        radius: 8
                        color: Nexa.Theme.shadow
                    }

                    // Inner content
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 2
                        radius: 6
                        color: Nexa.Theme.surfaceContainer
                        clip: true

                        // Image thumbnail — ONLY loaded for actual image files.
                        // Never set source for non-image URIs: Qt tries to decode
                        // them even when visible:false and throws errors that break
                        // the entire delegate.
                        Image {
                            anchors.fill: parent
                            visible: modelData.category === "image" && modelData.exists
                            source: (modelData.category === "image" && modelData.exists)
                                ? (modelData.uri || "")
                                : ""
                            fillMode: Image.PreserveAspectCrop
                            sourceSize: Qt.size(128, 128)
                            asynchronous: true
                            smooth: true
                            mipmap: true
                        }

                        // System theme icon for non-image files.
                        // Use a safe category-level icon name (never the full MIME
                        // type string which may not exist in the current theme).
                        Image {
                            anchors.fill: parent
                            anchors.margins: 8
                            visible: modelData.category !== "image" || !modelData.exists
                            source: {
                                if (!modelData.exists) return ""
                                // Map category → reliable theme icon name
                                const catIcons = {
                                    "video":    "video-x-generic",
                                    "audio":    "audio-x-generic",
                                    "document": "x-office-document",
                                    "archive":  "package-x-generic",
                                    "code":     "text-x-script",
                                    "image":    "image-x-generic",
                                }
                                const catIcon = catIcons[modelData.category] || "text-x-generic"
                                // Prefer the specific icon_name if it's short (likely valid);
                                // fall back to category icon for long MIME-style names.
                                const specific = modelData.icon_name || ""
                                const iconName = (specific.length > 0 && specific.length < 40 && !specific.includes("."))
                                    ? specific
                                    : catIcon
                                return Quickshell.iconPath(iconName, catIcon)
                            }
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            smooth: true
                            mipmap: true
                        }

                        // Ghost overlay for missing files
                        Text {
                            anchors.centerIn: parent
                            visible: !modelData.exists
                            text: "󰀪"
                            font.family: Nexa.Theme.iconFontFamily
                            font.pixelSize: 28
                            color: Nexa.Theme.error
                        }
                    }

                    // Remove chip (×) on hover
                    Rectangle {
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.topMargin: -6
                        anchors.rightMargin: -6
                        width: 18
                        height: 18
                        radius: 9
                        color: Nexa.Theme.surfaceContainerHighest
                        border.color: Nexa.Theme.border
                        border.width: 1
                        visible: cardMouse.containsMouse && !root.dragInProgress
                        z: 20

                        Text {
                            anchors.centerIn: parent
                            text: "×"
                            font.family: Nexa.Theme.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.Bold
                            color: Nexa.Theme.text
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.removeFile(modelData.id)
                        }
                    }
                }

                // Filename underneath
                Text {
                    id: nameLabel
                    anchors.top: polaroidFrame.bottom
                    anchors.topMargin: 6
                    anchors.left: parent.left
                    anchors.right: parent.right
                    text: modelData.name || "file"
                    font.family: Nexa.Theme.fontFamily
                    font.pixelSize: 11
                    font.weight: Font.Medium
                    color: cardMouse.containsMouse ? Nexa.Theme.text : Nexa.Theme.mutedText
                    elide: Text.ElideMiddle
                    horizontalAlignment: Text.AlignHCenter
                    maximumLineCount: 1
                }

                // --------------------------------------------------------
                // MOUSE INTERACTION
                //
                // Click    → copy file to clipboard
                // Drag     → start OS Wayland DnD (closes tray when done)
                // DblClick → open file with xdg-open
                // --------------------------------------------------------
                MouseArea {
                    id: cardMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: root.dragInProgress ? Qt.ClosedHandCursor : Qt.OpenHandCursor

                    // No drag.target — we start the drag manually via Drag.start()
                    property real pressX: 0
                    property real pressY: 0
                    property bool dragStarted: false

                    onPressed: mouse => {
                        pressX = mouse.x
                        pressY = mouse.y
                        dragStarted = false
                    }

                    onPositionChanged: mouse => {
                        // CRITICAL: Must check cardMouse.pressed AND LeftButton!
                        // Otherwise hover events trigger onPositionChanged and cause
                        // dragInProgress to be permanently true!
                        if (!cardMouse.pressed || !(mouse.buttons & Qt.LeftButton) || dragStarted)
                            return

                        const dx = mouse.x - pressX
                        const dy = mouse.y - pressY
                        const dist = Math.sqrt(dx * dx + dy * dy)
                        if (dist > 10) {
                            dragStarted = true
                            root.dragInProgress = true
                            // Start the real OS-level Wayland drag session
                            cardItem.Drag.start(Qt.CopyAction)
                        }
                    }

                    onReleased: {
                        dragStarted = false
                        root.dragInProgress = false
                    }

                    onCanceled: {
                        dragStarted = false
                        root.dragInProgress = false
                    }

                    onClicked: mouse => {
                        if (!dragStarted && !root.dragInProgress) {
                            root.copySingleItem(modelData)
                        }
                    }

                    onDoubleClicked: {
                        Quickshell.execDetached(["xdg-open", modelData.path])
                    }
                }
            }
        }
    }
}
