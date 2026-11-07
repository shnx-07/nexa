import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Quickshell
import Quickshell.Io

import "../../NewNexaUI" as NexaUI


Item {
    id: root

    // ============================================================
    // RESPONSIBILITY
    //
    // Dynamic Island-Native NEXA Application Launcher:
    // - Full 760x620 workspace dimensions
    // - Instant search & categorized filtering
    // - IPC target for 'appLauncher' and keyboard shortcuts
    // ============================================================

    signal requestClose()
    signal requestOpen()

    property bool loading: false

    // ============================================================
    // DATA
    // ============================================================

    property var categories: []
    property var visibleApps: []

    property string selectedCategoryId: "all"
    property string selectedCategoryName: "All"

    // ============================================================
    // BACKEND
    // ============================================================

    readonly property string nexadPath:
        Quickshell.env("HOME")
        + "/.config/nexa/rust/target/release/nexad"

    // ============================================================
    // PUBLIC ACTIVATION & FOCUS
    // ============================================================

    function activate() {
        selectedCategoryId = "all"
        selectedCategoryName = "All"
        visibleApps = []
        categories = []
        searchInput.text = ""
        loading = true

        listProcess.exec([
            nexadPath,
            "appLauncher",
            "list"
        ])

        Qt.callLater(function() {
            searchInput.forceActiveFocus()
        })
    }

    onVisibleChanged: {
        if (visible) {
            activate()
        }
    }

    // ============================================================
    // CATEGORY ICONS
    // ============================================================

    function categoryIcon(id, name) {
        const key = (id || name || "").toLowerCase()

        switch (key) {
        case "all":
            return "󰀻"
        case "development":
            return "󰅨"
        case "internet":
            return "󰖩"
        case "media":
            return "󰐊"
        case "graphics":
            return "󰏘"
        case "office":
            return "󰈙"
        case "games":
            return "󰊗"
        case "system":
            return "󰒓"
        case "utilities":
            return "󰒑"
        case "education":
            return "󰑴"
        case "science":
            return "󰙨"
        default:
            return "󰘔"
        }
    }

    // ============================================================
    // APP DESCRIPTION
    // ============================================================

    function appDescription(app) {
        if (!app) return ""
        if (app.generic_name && app.generic_name.length > 0) return app.generic_name
        if (app.comment && app.comment.length > 0) return app.comment
        if (app.category_name) return app.category_name
        return ""
    }

    // ============================================================
    // CATEGORY SELECTION
    // ============================================================

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
        if (!categories || categories.length === 0) {
            visibleApps = []
            return
        }

        for (let i = 0; i < categories.length; ++i) {
            const category = categories[i]
            if (category.id === selectedCategoryId) {
                selectedCategoryName = category.name
                visibleApps = category.apps || []
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

    // ============================================================
    // SEARCH
    // ============================================================

    function requestSearch(query) {
        const trimmed = query.trim()
        if (trimmed.length === 0) {
            restoreSelectedCategory()
            loading = false
            return
        }

        loading = true
        searchProcess.exec([
            nexadPath,
            "appLauncher",
            "search",
            trimmed
        ])
    }

    // ============================================================
    // LAUNCH
    // ============================================================

    function launchApplication(app) {
        if (!app || !app.id) return
        Quickshell.execDetached([nexadPath, "appLauncher", "launch", String(app.id)])
        root.requestClose()
    }

    // ============================================================
    // LIST PROCESS
    // ============================================================

    Process {
        id: listProcess

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const payload = JSON.parse(this.text)
                    root.categories = payload.categories || []
                    root.selectedCategoryId = "all"
                    root.selectedCategoryName = "All"

                    if (root.categories.length > 0) {
                        root.visibleApps = root.categories[0].apps || []
                    } else {
                        root.visibleApps = []
                    }
                } catch (error) {
                    console.error("[AppLauncherIsland:list]", error)
                    root.categories = []
                    root.visibleApps = []
                }
                root.loading = false
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                const text = this.text.trim()
                if (text.length > 0)
                    console.error("[AppLauncherIsland:list]", text)
            }
        }
    }

    // ============================================================
    // SEARCH PROCESS
    // ============================================================

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
                } catch (error) {
                    console.error("[AppLauncherIsland:search]", error)
                    root.visibleApps = []
                }
                root.loading = false
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                const text = this.text.trim()
                if (text.length > 0)
                    console.error("[AppLauncherIsland:search]", text)
            }
        }
    }

    // ============================================================
    // LAUNCH PROCESS
    // ============================================================

    Process {
        id: launchProcess

        stderr: StdioCollector {
            onStreamFinished: {
                const text = this.text.trim()
                if (text.length > 0)
                    console.error("[AppLauncherIsland:launch]", text)
            }
        }
    }

    Timer {
        id: searchDebounce
        interval: 100
        repeat: false
        onTriggered: root.requestSearch(searchInput.text)
    }

    // ============================================================
    // MAIN LAUNCHER CONTENT
    // ============================================================

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 14

        // =========================================================
        // 1. TOP HEADER: SEARCH BAR
        // =========================================================

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 50

            radius: NexaUI.NexaTokens.radiusMd
            color: NexaUI.NexaColors.surfaceContainer
            border.width: searchInput.activeFocus ? NexaUI.NexaTokens.borderMedium : NexaUI.NexaTokens.borderThin
            border.color: searchInput.activeFocus ? NexaUI.NexaColors.primary : NexaUI.NexaColors.border

            Behavior on border.color {
                ColorAnimation { duration: NexaUI.NexaMotion.durationFast }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 14
                spacing: 12

                Text {
                    text: "󰍉"
                    color: searchInput.activeFocus ? NexaUI.NexaColors.primary : NexaUI.NexaColors.mutedText
                    font.family: NexaUI.NexaTypography.familyIcon
                    font.pixelSize: NexaUI.NexaTokens.iconMd
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Text {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        visible: searchInput.text.length === 0
                        text: root.selectedCategoryId === "all"
                            ? "Search applications..."
                            : "Search in " + root.selectedCategoryName + "..."
                        color: NexaUI.NexaColors.mutedText
                        font.family: NexaUI.NexaTypography.familyBody
                        font.pixelSize: NexaUI.NexaTypography.sizeMd
                    }

                    TextInput {
                        id: searchInput
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        color: NexaUI.NexaColors.text
                        selectionColor: NexaUI.NexaColors.primary
                        selectedTextColor: NexaUI.NexaColors.onPrimary
                        font.family: NexaUI.NexaTypography.familyBody
                        font.pixelSize: NexaUI.NexaTypography.sizeMd
                        clip: true

                        onTextChanged: searchDebounce.restart()

                        Keys.onEscapePressed: event => {
                            event.accepted = true
                            if (searchInput.text.length > 0) {
                                searchInput.text = ""
                            } else {
                                root.requestClose()
                            }
                        }

                        Keys.onLeftPressed: event => {
                            if (appGrid.count > 0 && appGrid.currentIndex % 2 === 1) {
                                event.accepted = true
                                appGrid.currentIndex = Math.max(0, appGrid.currentIndex - 1)
                                return
                            }
                            if (root.categories.length > 0 && searchInput.text.length === 0) {
                                event.accepted = true
                                const currentIdx = root.categories.findIndex(c => c.id === root.selectedCategoryId)
                                const prevIdx = currentIdx <= 0 ? root.categories.length - 1 : currentIdx - 1
                                root.selectCategory(root.categories[prevIdx])
                            }
                        }

                        Keys.onRightPressed: event => {
                            if (appGrid.count > 0 && appGrid.currentIndex % 2 === 0 && appGrid.currentIndex + 1 < appGrid.count) {
                                event.accepted = true
                                appGrid.currentIndex = appGrid.currentIndex + 1
                                return
                            }
                            if (root.categories.length > 0 && searchInput.text.length === 0) {
                                event.accepted = true
                                const currentIdx = root.categories.findIndex(c => c.id === root.selectedCategoryId)
                                const nextIdx = (currentIdx + 1) % root.categories.length
                                root.selectCategory(root.categories[nextIdx])
                            }
                        }

                        Keys.onDownPressed: event => {
                            event.accepted = true
                            if (appGrid.count > 0) {
                                appGrid.currentIndex = Math.min(appGrid.count - 1, appGrid.currentIndex + 2)
                            }
                        }

                        Keys.onUpPressed: event => {
                            event.accepted = true
                            if (appGrid.count > 0) {
                                appGrid.currentIndex = Math.max(0, appGrid.currentIndex - 2)
                            }
                        }

                        Keys.onReturnPressed: event => {
                            event.accepted = true
                            if (appGrid.currentIndex >= 0 && appGrid.currentIndex < root.visibleApps.length) {
                                root.launchApplication(root.visibleApps[appGrid.currentIndex])
                            }
                        }
                    }
                }

                // Clear button (✕)
                Rectangle {
                    width: 26
                    height: 26
                    radius: NexaUI.NexaTokens.nexaRounding === 0 ? 0 : 13
                    visible: searchInput.text.length > 0
                    color: clearMouse.containsMouse ? NexaUI.NexaColors.hover : "transparent"
                    border.width: (NexaUI.NexaTokens.nexaRounding === 0 || NexaUI.NexaTokens.windowBorderSize > 0) ? NexaUI.NexaTokens.borderThin : 0
                    border.color: NexaUI.NexaColors.borderSubtle

                    Text {
                        anchors.centerIn: parent
                        text: "󰅖"
                        color: clearMouse.containsMouse ? NexaUI.NexaColors.text : NexaUI.NexaColors.mutedText
                        font.family: NexaUI.NexaTypography.familyIcon
                        font.pixelSize: NexaUI.NexaTokens.iconSm
                    }

                    MouseArea {
                        id: clearMouse
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

        // =========================================================
        // 2. CATEGORY PILLS BAR
        // =========================================================

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

                NexaUI.NexaSmoothScroll { horizontal: true }

                Row {
                    id: categoryRow
                    spacing: 6
                    height: parent.height

                    Repeater {
                        model: root.categories

                        delegate: Rectangle {
                            id: catChip
                            required property var modelData

                            readonly property bool active:
                                searchInput.text.length === 0
                                && root.selectedCategoryId === modelData.id

                            implicitWidth: chipRow.implicitWidth + 20
                            implicitHeight: 36
                            radius: NexaUI.NexaTokens.nexaRounding === 0 ? 0 : height / 2

                            color: active
                                ? NexaUI.NexaColors.primary
                                : chipMouse.containsMouse
                                    ? NexaUI.NexaColors.surfaceContainerHigh
                                    : NexaUI.NexaColors.surfaceContainer

                            border.width: NexaUI.NexaTokens.borderThin
                            border.color: active ? NexaUI.NexaColors.primary : NexaUI.NexaColors.border

                            scale: chipMouse.pressed ? 0.96 : (chipMouse.containsMouse ? 1.02 : 1.0)

                            Behavior on color { ColorAnimation { duration: NexaUI.NexaMotion.durationFast } }
                            Behavior on scale { NumberAnimation { duration: NexaUI.NexaMotion.durationFast } }

                            Row {
                                id: chipRow
                                anchors.centerIn: parent
                                spacing: 6

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: root.categoryIcon(modelData.id, modelData.name)
                                    color: catChip.active ? NexaUI.NexaColors.onPrimary : NexaUI.NexaColors.text
                                    font.family: NexaUI.NexaTypography.familyIcon
                                    font.pixelSize: NexaUI.NexaTokens.iconSm
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.name
                                    color: catChip.active ? NexaUI.NexaColors.onPrimary : NexaUI.NexaColors.text
                                    font.family: NexaUI.NexaTypography.familyBody
                                    font.pixelSize: NexaUI.NexaTypography.sizeSm
                                    font.weight: catChip.active ? NexaUI.NexaTypography.weightSemiBold : NexaUI.NexaTypography.weightMedium
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

        // =========================================================
        // 3. APPLICATION 2-COLUMN GRID VIEW
        // =========================================================

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true

            radius: NexaUI.NexaTokens.radiusLg
            color: NexaUI.NexaColors.surfaceContainer
            border.width: NexaUI.NexaTokens.borderThin
            border.color: NexaUI.NexaColors.border
            clip: true

            GridView {
                id: appGrid
                anchors.fill: parent
                anchors.topMargin: 10
                anchors.bottomMargin: 10
                anchors.leftMargin: 10
                anchors.rightMargin: 18

                cellWidth: width / 2
                cellHeight: 70

                model: root.visibleApps
                clip: true

                boundsBehavior: Flickable.StopAtBounds
                flickDeceleration: 1500
                maximumFlickVelocity: 2500

                NexaUI.NexaSmoothScroll {}

                ScrollBar.vertical: ScrollBar {
                    id: gridScrollBar
                    parent: appGrid.parent
                    anchors.right: parent.right
                    anchors.rightMargin: 5
                    anchors.top: parent.top
                    anchors.topMargin: 12
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 12
                    policy: ScrollBar.AsNeeded

                    contentItem: Rectangle {
                        implicitWidth: 3
                        radius: 1.5
                        color: Qt.rgba(
                            NexaUI.NexaColors.text.r,
                            NexaUI.NexaColors.text.g,
                            NexaUI.NexaColors.text.b,
                            gridScrollBar.hovered ? 0.6 : 0.25
                        )
                        Behavior on color { ColorAnimation { duration: NexaUI.NexaMotion.durationFast } }
                    }
                    background: Rectangle {
                        implicitWidth: 3
                        radius: 1.5
                        color: Qt.rgba(
                            NexaUI.NexaColors.text.r,
                            NexaUI.NexaColors.text.g,
                            NexaUI.NexaColors.text.b,
                            0.06
                        )
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
                        id: cardBackground
                        anchors.fill: parent
                        anchors.margins: 4

                        radius: NexaUI.NexaTokens.radiusMd

                        color: appItem.isSelected
                            ? NexaUI.NexaColors.primaryContainer
                            : appMouse.containsMouse
                                ? NexaUI.NexaColors.surfaceContainerHigh
                                : NexaUI.NexaColors.surfaceContainerLow

                        border.width: appItem.isSelected ? NexaUI.NexaTokens.borderMedium : NexaUI.NexaTokens.borderThin
                        border.color: appItem.isSelected
                            ? NexaUI.NexaColors.primary
                            : (appMouse.containsMouse ? NexaUI.NexaColors.borderStrong : NexaUI.NexaColors.border)

                        scale: appMouse.pressed ? 0.97 : (appMouse.containsMouse ? 1.01 : 1.0)

                        Behavior on color { ColorAnimation { duration: NexaUI.NexaMotion.durationFast } }
                        Behavior on scale { NumberAnimation { duration: NexaUI.NexaMotion.durationFast } }
                        Behavior on border.color { ColorAnimation { duration: NexaUI.NexaMotion.durationFast } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 12

                            // App Icon
                            Image {
                                Layout.preferredWidth: 42
                                Layout.preferredHeight: 42

                                source: modelData.icon
                                    ? Quickshell.iconPath(modelData.icon, "application-x-executable")
                                    : Quickshell.iconPath("application-x-executable")

                                sourceSize.width: 42
                                sourceSize.height: 42
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                                smooth: true
                            }

                            // App Title & Subtitle
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.name
                                    color: appItem.isSelected ? NexaUI.NexaColors.onPrimaryContainer : NexaUI.NexaColors.text
                                    font.family: NexaUI.NexaTypography.familyBody
                                    font.pixelSize: NexaUI.NexaTypography.sizeMd
                                    font.weight: NexaUI.NexaTypography.weightSemiBold
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: root.appDescription(modelData)
                                    visible: text.length > 0
                                    color: appItem.isSelected ? NexaUI.NexaColors.onPrimaryContainer : NexaUI.NexaColors.mutedText
                                    opacity: appItem.isSelected ? 0.8 : 1.0
                                    font.family: NexaUI.NexaTypography.familyBody
                                    font.pixelSize: NexaUI.NexaTypography.sizeXs
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
                        color: NexaUI.NexaColors.mutedText
                        font.family: NexaUI.NexaTypography.familyIcon
                        font.pixelSize: 36
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: searchInput.text.length > 0 ? "No applications found" : "No applications"
                        color: NexaUI.NexaColors.mutedText
                        font.family: NexaUI.NexaTypography.familyBody
                        font.pixelSize: NexaUI.NexaTypography.sizeMd
                        font.weight: NexaUI.NexaTypography.weightMedium
                    }
                }

                // Loading State
                Text {
                    anchors.centerIn: parent
                    visible: root.loading && root.visibleApps.length === 0
                    text: "Loading applications..."
                    color: NexaUI.NexaColors.mutedText
                    font.family: NexaUI.NexaTypography.familyBody
                    font.pixelSize: NexaUI.NexaTypography.sizeMd
                }
            }
        }

        // =========================================================
        // 4. BOTTOM STATUS BAR & NAVIGATION HINTS
        // =========================================================

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 24

            // App count info
            Row {
                spacing: 6

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: searchInput.text.length > 0 ? "󰍉" : "󰀻"
                    color: NexaUI.NexaColors.mutedText
                    font.family: NexaUI.NexaTypography.familyIcon
                    font.pixelSize: NexaUI.NexaTokens.iconXs
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: searchInput.text.length > 0
                        ? root.visibleApps.length + " result" + (root.visibleApps.length === 1 ? "" : "s")
                        : root.visibleApps.length + " apps in " + root.selectedCategoryName
                    color: NexaUI.NexaColors.mutedText
                    font.family: NexaUI.NexaTypography.familyBody
                    font.pixelSize: NexaUI.NexaTypography.sizeXs
                    font.weight: NexaUI.NexaTypography.weightMedium
                }
            }

            Item { Layout.fillWidth: true }

            // Keyboard legend
            Row {
                spacing: 12

                Row {
                    spacing: 4
                    Text {
                        text: "↑↓←→"
                        color: NexaUI.NexaColors.primary
                        font.family: NexaUI.NexaTypography.familyMono
                        font.pixelSize: NexaUI.NexaTypography.sizeXs
                        font.weight: NexaUI.NexaTypography.weightBold
                    }
                    Text {
                        text: "Navigate"
                        color: NexaUI.NexaColors.mutedText
                        font.family: NexaUI.NexaTypography.familyBody
                        font.pixelSize: NexaUI.NexaTypography.sizeXs
                    }
                }

                Row {
                    spacing: 4
                    Text {
                        text: "↵"
                        color: NexaUI.NexaColors.primary
                        font.family: NexaUI.NexaTypography.familyMono
                        font.pixelSize: NexaUI.NexaTypography.sizeXs
                        font.weight: NexaUI.NexaTypography.weightBold
                    }
                    Text {
                        text: "Launch"
                        color: NexaUI.NexaColors.mutedText
                        font.family: NexaUI.NexaTypography.familyBody
                        font.pixelSize: NexaUI.NexaTypography.sizeXs
                    }
                }

                Row {
                    spacing: 4
                    Text {
                        text: "ESC"
                        color: NexaUI.NexaColors.primary
                        font.family: NexaUI.NexaTypography.familyMono
                        font.pixelSize: NexaUI.NexaTypography.sizeXs
                        font.weight: NexaUI.NexaTypography.weightBold
                    }
                    Text {
                        text: "Close"
                        color: NexaUI.NexaColors.mutedText
                        font.family: NexaUI.NexaTypography.familyBody
                        font.pixelSize: NexaUI.NexaTypography.sizeXs
                    }
                }
            }
        }
    }
}
