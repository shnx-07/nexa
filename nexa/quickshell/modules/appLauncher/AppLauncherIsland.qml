import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../theme" as Nexa
import "../../theme/components" as NexaUI

Item {
    id: root

    signal requestClose()
    signal requestOpen()

    property bool loading: false
    property var categories: []
    property var visibleApps: []
    property string selectedCategoryId: "all"
    property string selectedCategoryName: "All"

    readonly property string nexadPath: Quickshell.env("HOME") + "/.config/nexa/rust/target/release/nexad"

    function activate() {
        selectedCategoryId = "all"
        selectedCategoryName = "All"
        visibleApps = []
        categories = []
        searchInput.text = ""
        loading = true
        listProcess.exec([nexadPath, "appLauncher", "list"])
        Qt.callLater(() => searchInput.forceActiveFocus())
    }

    onVisibleChanged: { if (visible) activate() }

    function categoryIcon(id, name) {
        const icons = {
            "all": "󰀻", "development": "󰅨", "internet": "󰖩", "media": "󰐊",
            "graphics": "󰏘", "office": "󰈙", "games": "󰊗", "system": "󰒓",
            "utilities": "󰒑", "education": "󰑴", "science": "󰙨"
        }
        return icons[(id || name || "").toLowerCase()] || "󰘔"
    }

    function appDescription(app) {
        if (!app) return ""
        return app.generic_name || app.comment || app.category_name || ""
    }

    function selectCategory(category) {
        if (!category) return
        searchDebounce.stop()
        searchInput.text = ""
        selectedCategoryId = category.id
        selectedCategoryName = category.name
        visibleApps = category.apps || []
        appGrid.currentIndex = 0
        appGrid.positionViewAtBeginning()
    }

    function restoreSelectedCategory() {
        if (!categories || categories.length === 0) { visibleApps = []; return }
        for (let i = 0; i < categories.length; ++i) {
            if (categories[i].id === selectedCategoryId) {
                selectedCategoryName = categories[i].name
                visibleApps = categories[i].apps || []
                appGrid.currentIndex = 0
                appGrid.positionViewAtBeginning()
                return
            }
        }
        selectedCategoryId = "all"
        selectedCategoryName = "All"
        visibleApps = categories[0].apps || []
        appGrid.currentIndex = 0
        appGrid.positionViewAtBeginning()
    }

    function requestSearch(query) {
        const trimmed = query.trim()
        if (trimmed.length === 0) {
            restoreSelectedCategory()
            loading = false
            return
        }
        loading = true
        searchProcess.exec([nexadPath, "appLauncher", "search", trimmed])
    }

    function launchApplication(app) {
        if (!app || !app.id) return
        launchProcess.exec([nexadPath, "appLauncher", "launch", app.id])
        root.requestClose()
    }

    Process {
        id: listProcess
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const payload = JSON.parse(this.text)
                    root.categories = payload.categories || []
                    root.selectedCategoryId = "all"
                    root.selectedCategoryName = "All"
                    root.visibleApps = (root.categories.length > 0) ? (root.categories[0].apps || []) : []
                } catch (e) {
                    console.error("[AppLauncherIsland:list]", e)
                    root.categories = []
                    root.visibleApps = []
                }
                root.loading = false
            }
        }
        stderr: StdioCollector {
            onStreamFinished: { if (this.text.trim()) console.error("[AppLauncherIsland:list]", this.text.trim()) }
        }
    }

    Process {
        id: searchProcess
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const payload = JSON.parse(this.text)
                    if (searchInput.text.trim().length === 0) {
                        root.restoreSelectedCategory()
                    } else {
                        root.visibleApps = payload.results || []
                        appGrid.currentIndex = 0
                        appGrid.positionViewAtBeginning()
                    }
                } catch (e) {
                    console.error("[AppLauncherIsland:search]", e)
                    root.visibleApps = []
                }
                root.loading = false
            }
        }
        stderr: StdioCollector {
            onStreamFinished: { if (this.text.trim()) console.error("[AppLauncherIsland:search]", this.text.trim()) }
        }
    }

    Process {
        id: launchProcess
        stderr: StdioCollector {
            onStreamFinished: { if (this.text.trim()) console.error("[AppLauncherIsland:launch]", this.text.trim()) }
        }
    }

    Timer {
        id: searchDebounce
        interval: 100
        repeat: false
        onTriggered: root.requestSearch(searchInput.text)
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 14

        // 1. TOP HEADER: SEARCH BAR
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 50
            radius: Nexa.Theme.radiusMd
            color: Nexa.Theme.surfaceContainer
            border.width: searchInput.activeFocus ? Nexa.Theme.borderNormal : Nexa.Theme.borderThin
            border.color: searchInput.activeFocus ? Nexa.Theme.primary : Nexa.Theme.border
            Behavior on border.color { ColorAnimation { duration: Nexa.Theme.animationFast } }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 14
                spacing: 12

                Text {
                    text: "󰍉"
                    color: searchInput.activeFocus ? Nexa.Theme.primary : Nexa.Theme.mutedText
                    font.family: Nexa.Theme.iconFontFamily
                    font.pixelSize: Nexa.Theme.iconMd
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Text {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        visible: searchInput.text.length === 0
                        text: root.selectedCategoryId === "all" ? "Search applications..." : "Search in " + root.selectedCategoryName + "..."
                        color: Nexa.Theme.mutedText
                        font.family: Nexa.Theme.fontFamily
                        font.pixelSize: Nexa.Theme.fontSizeMd
                    }

                    TextInput {
                        id: searchInput
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        color: Nexa.Theme.text
                        selectionColor: Nexa.Theme.primary
                        selectedTextColor: Nexa.Theme.onPrimary
                        font.family: Nexa.Theme.fontFamily
                        font.pixelSize: Nexa.Theme.fontSizeMd
                        clip: true
                        onTextChanged: searchDebounce.restart()

                        Keys.onEscapePressed: (event) => {
                            event.accepted = true
                            if (searchInput.text.length > 0) searchInput.text = ""
                            else root.requestClose()
                        }
                        Keys.onLeftPressed: (event) => {
                            if (appGrid.count > 0 && appGrid.currentIndex % 2 === 1) {
                                event.accepted = true; appGrid.currentIndex = Math.max(0, appGrid.currentIndex - 1); return
                            }
                            if (root.categories.length > 0 && searchInput.text.length === 0) {
                                event.accepted = true
                                const cur = root.categories.findIndex(c => c.id === root.selectedCategoryId)
                                const prev = cur <= 0 ? root.categories.length - 1 : cur - 1
                                root.selectCategory(root.categories[prev])
                            }
                        }
                        Keys.onRightPressed: (event) => {
                            if (appGrid.count > 0 && appGrid.currentIndex % 2 === 0 && appGrid.currentIndex + 1 < appGrid.count) {
                                event.accepted = true; appGrid.currentIndex += 1; return
                            }
                            if (root.categories.length > 0 && searchInput.text.length === 0) {
                                event.accepted = true
                                const cur = root.categories.findIndex(c => c.id === root.selectedCategoryId)
                                const next = (cur + 1) % root.categories.length
                                root.selectCategory(root.categories[next])
                            }
                        }
                        Keys.onDownPressed: (event) => {
                            event.accepted = true
                            if (appGrid.count > 0) appGrid.currentIndex = Math.min(appGrid.count - 1, appGrid.currentIndex + 2)
                        }
                        Keys.onUpPressed: (event) => {
                            event.accepted = true
                            if (appGrid.count > 0) appGrid.currentIndex = Math.max(0, appGrid.currentIndex - 2)
                        }
                        Keys.onReturnPressed: (event) => {
                            event.accepted = true
                            if (appGrid.currentIndex >= 0 && appGrid.currentIndex < root.visibleApps.length) {
                                root.launchApplication(root.visibleApps[appGrid.currentIndex])
                            }
                        }
                    }
                }

                Rectangle {
                    width: 26
                    height: 26
                    radius: 13
                    visible: searchInput.text.length > 0
                    color: clearMouse.containsMouse ? Nexa.Theme.hover : "transparent"
                    Text {
                        anchors.centerIn: parent
                        text: "󰅖"
                        color: clearMouse.containsMouse ? Nexa.Theme.text : Nexa.Theme.mutedText
                        font.family: Nexa.Theme.iconFontFamily
                        font.pixelSize: Nexa.Theme.iconSm
                    }
                    MouseArea {
                        id: clearMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { searchInput.text = ""; searchInput.forceActiveFocus() }
                    }
                }
            }
        }

        // 2. CATEGORY PILLS BAR
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 38

            Flickable {
                anchors.fill: parent
                contentWidth: categoryRow.implicitWidth
                contentHeight: parent.height
                interactive: contentWidth > width
                boundsBehavior: Flickable.StopAtBounds
                clip: true

                Row {
                    id: categoryRow
                    spacing: 8
                    height: parent.height

                    Repeater {
                        model: root.categories
                        delegate: Rectangle {
                            id: catChip
                            required property var modelData
                            readonly property bool active: searchInput.text.length === 0 && root.selectedCategoryId === modelData.id
                            implicitWidth: chipRow.implicitWidth + 24
                            implicitHeight: 36
                            radius: height / 2
                            color: active ? Nexa.Theme.primary : (chipMouse.containsMouse ? Nexa.Theme.surfaceContainerHigh : Nexa.Theme.surfaceContainer)
                            border.width: active ? 0 : Nexa.Theme.borderThin
                            border.color: active ? "transparent" : Nexa.Theme.border
                            scale: chipMouse.pressed ? 0.96 : (chipMouse.containsMouse ? 1.02 : 1.0)
                            Behavior on color { ColorAnimation { duration: Nexa.Theme.animationFast } }
                            Behavior on scale { NumberAnimation { duration: Nexa.Theme.animationFast } }

                            Row {
                                id: chipRow
                                anchors.centerIn: parent
                                spacing: 6
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: root.categoryIcon(modelData.id, modelData.name)
                                    color: catChip.active ? Nexa.Theme.onPrimary : Nexa.Theme.text
                                    font.family: Nexa.Theme.iconFontFamily
                                    font.pixelSize: Nexa.Theme.iconSm
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.name
                                    color: catChip.active ? Nexa.Theme.onPrimary : Nexa.Theme.text
                                    font.family: Nexa.Theme.fontFamily
                                    font.pixelSize: Nexa.Theme.fontSizeSm
                                    font.weight: catChip.active ? Nexa.Theme.fontWeightSemiBold : Nexa.Theme.fontWeightMedium
                                }
                            }

                            MouseArea {
                                id: chipMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.selectCategory(modelData)
                            }
                        }
                    }
                }
            }
        }

        // 3. APPLICATION GRID VIEW
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Nexa.Theme.radiusLg
            color: Nexa.Theme.surfaceContainer
            border.width: Nexa.Theme.borderThin
            border.color: Nexa.Theme.border
            clip: true

            GridView {
                id: appGrid
                anchors.fill: parent
                anchors.margins: 10
                anchors.rightMargin: 18
                cellWidth: width / 2
                cellHeight: 70
                model: root.visibleApps
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                flickDeceleration: Nexa.Theme.flickDeceleration
                maximumFlickVelocity: Nexa.Theme.flickVelocityMax

                ScrollBar.vertical: ScrollBar {
                    id: gridScrollBar
                    parent: appGrid.parent
                    anchors { right: parent.right; rightMargin: 5; top: parent.top; topMargin: 12; bottom: parent.bottom; bottomMargin: 12 }
                    policy: ScrollBar.AsNeeded
                    contentItem: Rectangle {
                        implicitWidth: 3
                        radius: 1.5
                        color: Qt.rgba(Nexa.Theme.text.r, Nexa.Theme.text.g, Nexa.Theme.text.b, gridScrollBar.hovered ? 0.6 : 0.25)
                        Behavior on color { ColorAnimation { duration: Nexa.Theme.animationFast } }
                    }
                    background: Rectangle {
                        implicitWidth: 3
                        radius: 1.5
                        color: Qt.rgba(Nexa.Theme.text.r, Nexa.Theme.text.g, Nexa.Theme.text.b, 0.06)
                    }
                }

                delegate: Item {
                    id: appItem
                    required property var modelData
                    required property int index
                    width: appGrid.cellWidth
                    height: appGrid.cellHeight
                    readonly property bool isSelected: appGrid.currentIndex === index

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 4
                        radius: Nexa.Theme.radiusMd
                        color: appItem.isSelected ? Nexa.Theme.primaryContainer : (appMouse.containsMouse ? Nexa.Theme.surfaceContainerHigh : Nexa.Theme.surfaceContainerLow)
                        border.width: appItem.isSelected ? Nexa.Theme.borderNormal : Nexa.Theme.borderThin
                        border.color: appItem.isSelected ? Nexa.Theme.primary : (appMouse.containsMouse ? Nexa.Theme.borderStrong : Nexa.Theme.border)
                        scale: appMouse.pressed ? 0.97 : (appMouse.containsMouse ? 1.01 : 1.0)
                        Behavior on color { ColorAnimation { duration: Nexa.Theme.animationFast } }
                        Behavior on scale { NumberAnimation { duration: Nexa.Theme.animationFast } }
                        Behavior on border.color { ColorAnimation { duration: Nexa.Theme.animationFast } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 12

                            Image {
                                Layout.preferredWidth: 42
                                Layout.preferredHeight: 42
                                source: modelData.icon ? Quickshell.iconPath(modelData.icon, "application-x-executable") : Quickshell.iconPath("application-x-executable")
                                sourceSize.width: 42
                                sourceSize.height: 42
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                                smooth: true
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.name
                                    color: appItem.isSelected ? Nexa.Theme.onPrimaryContainer : Nexa.Theme.text
                                    font.family: Nexa.Theme.fontFamily
                                    font.pixelSize: Nexa.Theme.fontSizeMd
                                    font.weight: Nexa.Theme.fontWeightSemiBold
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: root.appDescription(modelData)
                                    visible: text.length > 0
                                    color: appItem.isSelected ? Nexa.Theme.onPrimaryContainer : Nexa.Theme.mutedText
                                    opacity: appItem.isSelected ? 0.8 : 1.0
                                    font.family: Nexa.Theme.fontFamily
                                    font.pixelSize: Nexa.Theme.fontSizeXs
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                }
                            }
                        }

                        MouseArea {
                            id: appMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                appGrid.currentIndex = appItem.index
                                root.launchApplication(modelData)
                            }
                        }
                    }
                }

                // Empty State
                Column {
                    anchors.centerIn: parent
                    spacing: 8
                    visible: !root.loading && root.visibleApps.length === 0
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "󰀻"
                        color: Nexa.Theme.mutedText
                        font.family: Nexa.Theme.iconFontFamily
                        font.pixelSize: 36
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: searchInput.text.length > 0 ? "No applications found" : "No applications"
                        color: Nexa.Theme.mutedText
                        font.family: Nexa.Theme.fontFamily
                        font.pixelSize: Nexa.Theme.fontSizeMd
                        font.weight: Nexa.Theme.fontWeightMedium
                    }
                }

                // Loading State
                Text {
                    anchors.centerIn: parent
                    visible: root.loading && root.visibleApps.length === 0
                    text: "Loading applications..."
                    color: Nexa.Theme.mutedText
                    font.family: Nexa.Theme.fontFamily
                    font.pixelSize: Nexa.Theme.fontSizeMd
                }
            }
        }

        // 4. BOTTOM STATUS BAR
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 24

            Row {
                spacing: 6
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: searchInput.text.length > 0 ? "󰍉" : "󰀻"
                    color: Nexa.Theme.mutedText
                    font.family: Nexa.Theme.iconFontFamily
                    font.pixelSize: Nexa.Theme.iconXs
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: searchInput.text.length > 0
                        ? root.visibleApps.length + " result" + (root.visibleApps.length === 1 ? "" : "s")
                        : root.visibleApps.length + " apps in " + root.selectedCategoryName
                    color: Nexa.Theme.mutedText
                    font.family: Nexa.Theme.fontFamily
                    font.pixelSize: Nexa.Theme.fontSizeXs
                    font.weight: Nexa.Theme.fontWeightMedium
                }
            }

            Item { Layout.fillWidth: true }

            Row {
                spacing: 12
                LegendItem { key: "↑↓←→"; label: "Navigate" }
                LegendItem { key: "↵"; label: "Launch" }
                LegendItem { key: "ESC"; label: "Close" }
            }
        }
    }

    component LegendItem: Row {
        property string key: ""
        property string label: ""
        spacing: 4
        Text {
            text: parent.key
            color: Nexa.Theme.primary
            font.family: Nexa.Theme.monoFontFamily
            font.pixelSize: Nexa.Theme.fontSizeXs
            font.weight: Nexa.Theme.fontWeightBold
        }
        Text {
            text: parent.label
            color: Nexa.Theme.mutedText
            font.family: Nexa.Theme.fontFamily
            font.pixelSize: Nexa.Theme.fontSizeXs
        }
    }
}
