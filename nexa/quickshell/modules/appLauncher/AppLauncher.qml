import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Quickshell
import Quickshell.Io

import "../../theme" as NTheme
import "../../theme/components" as NexaUI


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
    property bool launcherOpen: false
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
    // DIMENSIONS
    // ============================================================

    readonly property int outerPadding: 20
    readonly property int categoryButtonWidth: 46
    readonly property int categorySpacing: 12

    readonly property int categoryNaturalWidth:
        categories.length > 0
        ? categories.length * categoryButtonWidth
          + (categories.length - 1) * categorySpacing
        : 520

    readonly property int launcherWidth:
        Math.max(
            520,
            Math.min(
                700,
                categoryNaturalWidth
                + outerPadding * 2
            )
        )

    readonly property int launcherHeight: 560

    // ============================================================
    // OPEN / CLOSE
    // ============================================================

    function openLauncher() {
        closeTimer.stop()

        if (!windowAlive)
            windowAlive = true

        Qt.callLater(function() {
            launcherOpen = true

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

            searchInput.forceActiveFocus()
        })
    }

    function closeLauncher() {
        if (!windowAlive)
            return

        launcherOpen = false
        closeTimer.restart()
    }

    function toggleLauncher() {
        if (launcherOpen)
            closeLauncher()
        else
            openLauncher()
    }

    // ============================================================
    // IPC
    // ============================================================

    IpcHandler {
        target: "appLauncher"

        function open(): void {
            root.openLauncher()
        }

        function close(): void {
            root.closeLauncher()
        }

        function toggle(): void {
            root.toggleLauncher()
        }
    }

    // ============================================================
    // CATEGORY ICONS
    // ============================================================

    function categoryIcon(id, name) {
        const key =
            (id || name || "")
            .toLowerCase()

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
        if (!app)
            return ""

        if (app.generic_name
                && app.generic_name.length > 0)
            return app.generic_name

        if (app.comment
                && app.comment.length > 0)
            return app.comment

        if (app.category_name)
            return app.category_name

        return ""
    }

    // ============================================================
    // CATEGORY
    // ============================================================

    function selectCategory(category) {
        if (!category)
            return

        searchDebounce.stop()

        searchInput.text = ""

        selectedCategoryId = category.id
        selectedCategoryName = category.name

        visibleApps =
            category.apps || []

        appList.positionViewAtBeginning()
    }

    function restoreSelectedCategory() {
        if (!categories
                || categories.length === 0) {
            visibleApps = []
            return
        }

        for (let i = 0;
             i < categories.length;
             ++i) {

            const category =
                categories[i]

            if (category.id
                    === selectedCategoryId) {

                selectedCategoryName =
                    category.name

                visibleApps =
                    category.apps || []

                appList.positionViewAtBeginning()

                return
            }
        }

        selectedCategoryId = "all"
        selectedCategoryName = "All"

        visibleApps =
            categories[0].apps || []

        appList.positionViewAtBeginning()
    }

    // ============================================================
    // SEARCH
    // ============================================================

    function requestSearch(query) {
        const trimmed =
            query.trim()

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
        if (!app || !app.id)
            return

        launchProcess.exec([
            nexadPath,
            "appLauncher",
            "launch",
            app.id
        ])

        closeLauncher()
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
                        JSON.parse(this.text)

                    root.categories =
                        payload.categories || []

                    root.selectedCategoryId =
                        "all"

                    root.selectedCategoryName =
                        "All"

                    if (root.categories.length > 0) {
                        root.visibleApps =
                            root.categories[0].apps
                            || []
                    } else {
                        root.visibleApps = []
                    }

                } catch (error) {
                    console.error(
                        "[AppLauncher:list]",
                        error
                    )

                    root.categories = []
                    root.visibleApps = []
                }

                root.loading = false
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                const text =
                    this.text.trim()

                if (text.length > 0)
                    console.error(
                        "[AppLauncher:list]",
                        text
                    )
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
                    const payload =
                        JSON.parse(this.text)

                    if (searchInput.text
                            .trim()
                            .length === 0) {

                        root.restoreSelectedCategory()

                    } else {

                        root.visibleApps =
                            payload.results || []

                        appList.positionViewAtBeginning()
                    }

                } catch (error) {
                    console.error(
                        "[AppLauncher:search]",
                        error
                    )

                    root.visibleApps = []
                }

                root.loading = false
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                const text =
                    this.text.trim()

                if (text.length > 0)
                    console.error(
                        "[AppLauncher:search]",
                        text
                    )
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
                const text =
                    this.text.trim()

                if (text.length > 0)
                    console.error(
                        "[AppLauncher:launch]",
                        text
                    )
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

            root.categories = []
            root.visibleApps = []

            root.loading = false

            searchInput.text = ""
        }
    }

    // ============================================================
    // FADE
    // ============================================================

    Item {
        id: fadeLayer

        anchors.fill: parent

        opacity:
            root.launcherOpen
            ? NTheme.Theme.opacityFull
            : NTheme.Theme.opacityHidden

        Behavior on opacity {
            NumberAnimation {
                duration:
                    root.launcherOpen
                    ? NTheme.Theme.animationNormal
                    : NTheme.Theme.animationFast

                easing.type:
                    root.launcherOpen
                    ? NTheme.Theme.easingEnter
                    : NTheme.Theme.easingExit
            }
        }

        // ========================================================
        // CLICK OUTSIDE
        // ========================================================

        MouseArea {
            anchors.fill: parent

            onClicked:
                root.closeLauncher()
        }

        // ========================================================
        // LAUNCHER
        // ========================================================

        Rectangle {
            id: launcher

            anchors.centerIn: parent

            width:
                Math.min(
                    root.launcherWidth,
                    parent.width - 50
                )

            height:
                Math.min(
                    root.launcherHeight,
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

            // prevent outside-click close
            MouseArea {
                anchors.fill: parent
            }

            ColumnLayout {
                anchors.fill: parent

                anchors.margins:
                    root.outerPadding

                spacing:
                    NTheme.Theme.spacingSm

                // =================================================
                // SEARCH
                // =================================================

                Rectangle {
                    Layout.fillWidth: true

                    Layout.preferredHeight: 52

                    radius:
                        NTheme.Theme.radiusMd

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

                    Behavior on border.color {
                        ColorAnimation {
                            duration:
                                NTheme.Theme.animationFast
                        }
                    }

                    Text {
                        id: searchIcon

                        anchors.left:
                            parent.left

                        anchors.leftMargin:
                            NTheme.Theme.spacingLg

                        anchors.verticalCenter:
                            parent.verticalCenter

                        text: "󰍉"

                        color:
                            searchInput.activeFocus
                            ? NTheme.Theme.primary
                            : NTheme.Theme.mutedText

                        font.family:
                            NTheme.Theme.iconFontFamily

                        font.pixelSize:
                            NTheme.Theme.iconSm
                    }

                    Text {
                        anchors.left:
                            searchIcon.right

                        anchors.leftMargin:
                            NTheme.Theme.spacingMd

                        anchors.right:
                            parent.right

                        anchors.rightMargin:
                            NTheme.Theme.spacingLg

                        anchors.verticalCenter:
                            parent.verticalCenter

                        visible:
                            searchInput.text.length === 0

                        text:
                            "Search applications..."

                        color:
                            NTheme.Theme.mutedText

                        font.family:
                            NTheme.Theme.fontFamily

                        font.pixelSize:
                            NTheme.Theme.fontSizeMd
                    }

                    TextInput {
                        id: searchInput

                        anchors.left:
                            searchIcon.right

                        anchors.leftMargin:
                            NTheme.Theme.spacingMd

                        anchors.right:
                            parent.right

                        anchors.rightMargin:
                            NTheme.Theme.spacingLg

                        anchors.verticalCenter:
                            parent.verticalCenter

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

                        Keys.onEscapePressed: event => {
                            event.accepted = true
                            root.closeLauncher()
                        }
                    }

                    MouseArea {
                        anchors.fill: parent

                        z: -1

                        onClicked:
                            searchInput.forceActiveFocus()
                    }
                }

                // =================================================
                // CATEGORY ICONS
                // =================================================

                Item {
                    Layout.fillWidth: true

                    Layout.preferredHeight: 52

                    Flickable {
                        anchors.fill: parent

                        contentWidth:
                            categoryRow.implicitWidth

                        contentHeight:
                            categoryRow.height

                        interactive:
                            contentWidth > width

                        boundsBehavior:
                            Flickable.StopAtBounds

                        clip: false

                        Row {
                            id: categoryRow

                            anchors.centerIn: parent

                            spacing:
                                root.categorySpacing

                            height: 46

                            Repeater {
                                model:
                                    root.categories

                                delegate: Item {
                                    id: categoryDelegate

                                    required property var modelData

                                    width:
                                        root.categoryButtonWidth

                                    height: 46

                                    readonly property bool active:
                                        searchInput.text.length === 0
                                        && root.selectedCategoryId
                                           === modelData.id

                                    NexaUI.NexaIconButton {
                                        id: categoryBtn

                                        anchors.fill: parent

                                        icon: root.categoryIcon(
                                            modelData.id,
                                            modelData.name
                                        )

                                        selected: categoryDelegate.active

                                        onClicked: root.selectCategory(modelData)
                                    }

                                    NTheme.HoverInfo {
                                        anchors.horizontalCenter:
                                            parent.horizontalCenter

                                        anchors.bottom:
                                            parent.bottom

                                        anchors.bottomMargin:
                                            NTheme.Theme.spacingXs

                                        visible:
                                            categoryBtn.hovered

                                        z: 1000

                                        title:
                                            modelData.name

                                        info:
                                            modelData.count
                                            + (
                                                modelData.count === 1
                                                ? " app"
                                                : " apps"
                                            )
                                    }
                                }
                            }
                        }
                    }
                }

                // =================================================
                // APPLICATION LIST
                // =================================================

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    radius:
                        NTheme.Theme.radiusMd

                    color:
                        NTheme.Theme.panelBackground

                    clip: true

                    ListView {
                        id: appList

                        anchors.fill: parent

                        anchors.topMargin:
                            NTheme.Theme.spacingXs

                        anchors.bottomMargin:
                            NTheme.Theme.spacingXs

                        anchors.leftMargin:
                            NTheme.Theme.spacingXs

                        anchors.rightMargin: 12

                        model:
                            root.visibleApps

                        spacing: 2

                        clip: true

                        boundsBehavior:
                            Flickable.StopAtBounds

                        flickDeceleration:
                            NTheme.Theme.flickDeceleration

                        maximumFlickVelocity:
                            NTheme.Theme.flickVelocityMax

                        pixelAligned: true

                        ScrollBar.vertical: ScrollBar {
                            id: appScrollBar
                            policy: ScrollBar.AsNeeded

                            contentItem: Rectangle {
                                implicitWidth: 3
                                radius: width / 2
                                color: Qt.rgba(
                                    NTheme.Theme.text.r,
                                    NTheme.Theme.text.g,
                                    NTheme.Theme.text.b,
                                    appScrollBar.hovered ? 0.5 : 0.18
                                )

                                Behavior on color {
                                    ColorAnimation { duration: NTheme.Theme.animationFast }
                                }
                            }

                            background: null
                        }

                        delegate: Item {
                            id: appDelegate

                            required property var modelData

                            width:
                                appList.width

                            height: 72

                            NexaUI.NexaCard {
                                anchors.fill: parent
                                padding: NTheme.Theme.spacingMd
                                interactive: true
                                onClicked: root.launchApplication(modelData)

                                RowLayout {
                                    anchors.fill:
                                        parent

                                    spacing:
                                        NTheme.Theme.spacingMd

                                    Image {
                                        Layout.preferredWidth: 48
                                        Layout.preferredHeight: 48

                                        source:
                                            modelData.icon
                                            ? Quickshell.iconPath(
                                                  modelData.icon,
                                                  "application-x-executable"
                                              )
                                            : Quickshell.iconPath(
                                                  "application-x-executable"
                                              )

                                        sourceSize.width: 48
                                        sourceSize.height: 48

                                        fillMode:
                                            Image.PreserveAspectFit

                                        asynchronous: true
                                        smooth: true
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true

                                        spacing: 2

                                        Text {
                                            Layout.fillWidth: true

                                            text:
                                                modelData.name

                                            color:
                                                NTheme.Theme.text

                                            font.family:
                                                NTheme.Theme.fontFamily

                                            font.pixelSize:
                                                NTheme.Theme.fontSizeLg

                                            font.weight:
                                                NTheme.Theme.fontWeightDemiBold

                                            elide:
                                                Text.ElideRight

                                            maximumLineCount: 1
                                        }

                                        Text {
                                            Layout.fillWidth: true

                                            text:
                                                root.appDescription(
                                                    modelData
                                                )

                                            visible:
                                                text.length > 0

                                            color:
                                                NTheme.Theme.mutedText

                                            font.family:
                                                NTheme.Theme.fontFamily

                                            font.pixelSize:
                                                NTheme.Theme.fontSizeSm

                                            elide:
                                                Text.ElideRight

                                            maximumLineCount: 1
                                        }
                                    }
                                }
                            }
                        }

                        // =================================================
                        // EMPTY
                        // =================================================

                        Text {
                            anchors.centerIn:
                                parent

                            visible:
                                !root.loading
                                && root.visibleApps.length === 0

                            text:
                                searchInput.text.length > 0
                                ? "No applications found"
                                : "No applications"

                            color:
                                NTheme.Theme.mutedText

                            font.family:
                                NTheme.Theme.fontFamily

                            font.pixelSize:
                                NTheme.Theme.fontSizeSm
                        }

                        // =================================================
                        // LOADING
                        // =================================================

                        Text {
                            anchors.centerIn:
                                parent

                            visible:
                                root.loading
                                && root.visibleApps.length === 0

                            text:
                                "Loading applications..."

                            color:
                                NTheme.Theme.mutedText

                            font.family:
                                NTheme.Theme.fontFamily

                            font.pixelSize:
                                NTheme.Theme.fontSizeSm
                        }
                    }

                    // =====================================================
                    // CUSTOM THIN SCROLLBAR
                    // =====================================================

                    Rectangle {
                        id: scrollTrack

                        anchors.right:
                            parent.right

                        anchors.rightMargin: 4

                        anchors.top:
                            parent.bottom

                        anchors.topMargin: 8

                        anchors.bottom:
                            parent.bottom

                        anchors.bottomMargin: 8

                        width: 4

                        radius: 2

                        color:
                            NTheme.Theme.divider

                        visible:
                            appList.contentHeight
                            > appList.height

                        Rectangle {
                            width:
                                parent.width

                            radius:
                                parent.radius

                            color:
                                NTheme.Theme.borderStrong

                            height:
                                Math.max(
                                    30,
                                    parent.height
                                    * appList.visibleArea.heightRatio
                                )

                            y:
                                (
                                    parent.height
                                    - height
                                )
                                * appList.visibleArea.yPosition
                                / Math.max(
                                    0.0001,
                                    1
                                    - appList.visibleArea.heightRatio
                                )
                        }
                    }
                }
            }
        }
    }
}
