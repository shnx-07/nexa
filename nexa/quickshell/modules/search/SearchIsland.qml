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

    // iconS
    


  function fileIconName(path) {
        const lower =
            String(path || "").toLowerCase()

        if (
            lower.endsWith(".png")
            || lower.endsWith(".jpg")
            || lower.endsWith(".jpeg")
            || lower.endsWith(".webp")
            || lower.endsWith(".gif")
            || lower.endsWith(".svg")
        )
            return "image-x-generic"

        if (
            lower.endsWith(".mp3")
            || lower.endsWith(".flac")
            || lower.endsWith(".wav")
            || lower.endsWith(".ogg")
            || lower.endsWith(".m4a")
        )
            return "audio-x-generic"

        if (
            lower.endsWith(".mp4")
            || lower.endsWith(".mkv")
            || lower.endsWith(".webm")
            || lower.endsWith(".mov")
            || lower.endsWith(".avi")
        )
            return "video-x-generic"

        if (lower.endsWith(".pdf"))
            return "application-pdf"

        if (
            lower.endsWith(".zip")
            || lower.endsWith(".tar")
            || lower.endsWith(".gz")
            || lower.endsWith(".7z")
            || lower.endsWith(".rar")
        )
            return "package-x-generic"

        if (
            lower.endsWith(".txt")
            || lower.endsWith(".md")
            || lower.endsWith(".log")
        )
            return "text-x-generic"

        if (
            lower.endsWith(".qml")
            || lower.endsWith(".rs")
            || lower.endsWith(".py")
            || lower.endsWith(".js")
            || lower.endsWith(".ts")
            || lower.endsWith(".cpp")
            || lower.endsWith(".c")
            || lower.endsWith(".h")
            || lower.endsWith(".json")
            || lower.endsWith(".toml")
            || lower.endsWith(".yaml")
            || lower.endsWith(".yml")
        )
            return "text-x-script"

        return "text-x-generic"
  }




    // shellDir is:
    // ~/.config/nexa/quickshell
    //
    // so nexad lives one level above it.
    readonly property string nexadPath:
        Quickshell.shellDir
        + "/../rust/target/release/nexad"


    // ============================================================
    // PUBLIC FOCUS ENTRY
    // ============================================================

    function activate() {
        searchInput.forceActiveFocus()
        searchInput.selectAll()
    }

    onVisibleChanged: {
        if (visible) {
            Qt.callLater(function() {
                searchInput.forceActiveFocus()
            })
        }
    }

    // ============================================================
    // SEARCH
    // ============================================================

    function queueSearch() {
        root.pendingQuery =
            searchInput.text.trim()

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


        // Don't kill an in-flight query.
        // Queue the newest text instead.
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
        if (root.results.length === 0)
            return


        let next =
            root.selectedIndex + amount


        if (next < 0)
            next = root.results.length - 1

        if (next >= root.results.length)
            next = 0


        root.selectedIndex = next

        resultList.positionViewAtIndex(
            root.selectedIndex,
            ListView.Contain
        )
    }


    function openSelected() {
        if (root.results.length === 0)
            return


        const result =
            root.results[root.selectedIndex]

        if (!result)
            return


        openProcess.command = [
            root.nexadPath,
            "search",
            "open",
            String(result.id)
        ]

        openProcess.running = true

        // Opening app/file is fire-and-forget.
        // Island returns to its previous normal context.
        root.accepted()
    }


    // ============================================================
    // DEBOUNCE
    // ============================================================

    Timer {
        id: debounce

        interval: 90
        repeat: false

        onTriggered:
            root.runPendingSearch()
    }


    // ============================================================
    // QUERY PROCESS
    // ============================================================

    Process {
        id: queryProcess


        stdout: StdioCollector {
            onStreamFinished: {
                // Ignore stale results if newer text
                // was typed while this query ran.
                if (root.activeQuery !== root.pendingQuery)
                    return


                try {
                    const parsed =
                        JSON.parse(text)


                    root.results =
                        Array.isArray(parsed)
                        ? parsed
                        : []


                    if (
                        root.selectedIndex
                        >= root.results.length
                    ) {
                        root.selectedIndex = 0
                    }
                }
                catch (error) {
                    console.warn(
                        "NEXA search JSON error:",
                        error
                    )

                    root.results = []
                }
            }
        }


        onRunningChanged: {
            if (running)
                return


            root.searching = false


            // User typed again while old query
            // was still running.
            if (
                root.queryQueued
                || root.pendingQuery
                   !== root.activeQuery
            ) {
                root.runPendingSearch()
            }
        }
    }


    // ============================================================
    // OPEN RESULT
    // ============================================================

    Process {
        id: openProcess
    }


    // ============================================================
    // SEARCH BOX
    // ============================================================

    Rectangle {
        id: searchBox

        anchors {
            top: parent.top
            left: parent.left
            right: parent.right

            topMargin:
                Nexa.Theme.spacingLg

            leftMargin:
                Nexa.Theme.spacingLg

            rightMargin:
                Nexa.Theme.spacingLg
        }

        height: 52

        radius:
            Nexa.Theme.radiusMd

        color:
            Nexa.Theme.inputBackgroundFocus

        border.width:
            Nexa.Theme.borderNormal

        border.color:
            searchInput.activeFocus
            ? Nexa.Theme.primary
            : Nexa.Theme.border


        Behavior on border.color {
            ColorAnimation {
                duration:
                    Nexa.Theme.animationFast
            }
        }


        RowLayout {
            anchors {
                fill: parent

                leftMargin:
                    Nexa.Theme.spacingLg

                rightMargin:
                    Nexa.Theme.spacingLg
            }

            spacing:
                Nexa.Theme.spacingMd


            Text {
                text: "󰍉"

                color:
                    Nexa.Theme.primary

                font {
                    family:
                        Nexa.Theme.iconFontFamily

                    pixelSize:
                        Nexa.Theme.iconMd
                }
            }


            TextInput {
                id: searchInput

                focus: true

                Layout.fillWidth: true

                color:
                    Nexa.Theme.text

                selectionColor:
                    Nexa.Theme.primary

                selectedTextColor:
                    Nexa.Theme.primaryText

                clip: true


                font {
                    family:
                        Nexa.Theme.fontFamily

                    pixelSize:
                        Nexa.Theme.fontSizeLg

                    weight:
                        Nexa.Theme.fontWeightMedium
                }


                Text {
                    anchors {
                        fill: parent
                    }

                    visible:
                        searchInput.text.length === 0

                    text:
                        "Search apps and files..."

                    color:
                        Nexa.Theme.mutedText

                    verticalAlignment:
                        Text.AlignVCenter

                    font:
                        searchInput.font
                }


                onTextChanged:
                    root.queueSearch()


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


                    if (
                        event.key === Qt.Key_Return
                        || event.key === Qt.Key_Enter
                    ) {
                        root.openSelected()
                        event.accepted = true
                        return
                    }


                    if (event.key === Qt.Key_Escape) {
                        root.requestClose()
                        event.accepted = true
                    }
                }
            }


            Text {
                visible:
                    root.searching

                text:
                    "Searching…"

                color:
                    Nexa.Theme.mutedText

                font {
                    family:
                        Nexa.Theme.fontFamily

                    pixelSize:
                        Nexa.Theme.fontSizeXs
                }
            }


            Rectangle {
                width: 38
                height: 24

                radius:
                    Nexa.Theme.radiusSm

                color:
                    Nexa.Theme.surfaceContainerHigh

                visible:
                    searchInput.text.length > 0


                Text {
                    anchors.centerIn:
                        parent

                    text:
                        "ESC"

                    color:
                        Nexa.Theme.mutedText

                    font {
                        family:
                            Nexa.Theme.monoFontFamily

                        pixelSize:
                            Nexa.Theme.fontSize2Xs
                    }
                }
            }
        }
    }


    // ============================================================
    // RESULTS AREA
    // ============================================================

    Rectangle {
        anchors {
            top:
                searchBox.bottom

            left:
                parent.left

            right:
                parent.right

            bottom:
                parent.bottom


            topMargin:
                Nexa.Theme.spacingMd

            leftMargin:
                Nexa.Theme.spacingLg

            rightMargin:
                Nexa.Theme.spacingLg

            bottomMargin:
                Nexa.Theme.spacingLg
        }

        radius:
            Nexa.Theme.radiusMd

        color:
            Nexa.Theme.cardBackground

        border.width:
            Nexa.Theme.borderThin

        border.color:
            Nexa.Theme.border

        clip: true


        // ========================================================
        // EMPTY STATE
        // ========================================================

        Column {
            anchors.centerIn:
                parent

            visible:
                searchInput.text.length === 0

            spacing:
                Nexa.Theme.spacingSm


            Text {
                anchors.horizontalCenter:
                    parent.horizontalCenter

                text:
                    "󰍉"

                color:
                    Nexa.Theme.mutedText

                font {
                    family:
                        Nexa.Theme.iconFontFamily

                    pixelSize:
                        Nexa.Theme.icon2Xl
                }
            }


            Text {
                anchors.horizontalCenter:
                    parent.horizontalCenter

                text:
                    "Search applications and files"

                color:
                    Nexa.Theme.mutedText

                font {
                    family:
                        Nexa.Theme.fontFamily

                    pixelSize:
                        Nexa.Theme.fontSizeSm
                }
            }
        }


        // ========================================================
        // NO RESULTS
        // ========================================================

        Text {
            anchors.centerIn:
                parent

            visible:
                searchInput.text.length > 0
                && !root.searching
                && root.results.length === 0

            text:
                "No results"

            color:
                Nexa.Theme.mutedText

            font {
                family:
                    Nexa.Theme.fontFamily

                pixelSize:
                    Nexa.Theme.fontSizeSm
            }
        }


        // ========================================================
        // RESULT LIST
        // ========================================================

        ListView {
            id: resultList

            anchors {
                fill: parent
                margins:
                    Nexa.Theme.spacingSm
            }

            visible:
                root.results.length > 0

            model:
                root.results

            spacing:
                Nexa.Theme.spacingXs

            clip: true

            boundsBehavior:
                Flickable.StopAtBounds

            flickDeceleration:
                Nexa.Theme.flickDeceleration

            maximumFlickVelocity:
                Nexa.Theme.flickVelocityMax

            pixelAligned: true

            ScrollBar.vertical: ScrollBar {
                id: searchScrollBar
                policy: ScrollBar.AsNeeded

                contentItem: Rectangle {
                    implicitWidth: 3
                    radius: width / 2
                    color: Qt.rgba(
                        Nexa.Theme.text.r,
                        Nexa.Theme.text.g,
                        Nexa.Theme.text.b,
                        searchScrollBar.hovered ? 0.5 : 0.18
                    )

                    Behavior on color {
                        ColorAnimation { duration: Nexa.Theme.animationFast }
                    }
                }

                background: null
            }


            delegate: Rectangle {
                id: resultRow

                required property var modelData
                required property int index

                property bool hovered: false


                readonly property bool selected:
                    index === root.selectedIndex


                width:
                    resultList.width

                height: 52

                radius:
                    Nexa.Theme.radiusSm


                color: {
                    if (selected)
                        return Nexa.Theme.hoverStrong

                    if (hovered)
                        return Nexa.Theme.hover

                    return "transparent"
                }


                border.width:
                    selected
                    ? Nexa.Theme.borderThin
                    : 0

                border.color:
                    Nexa.Theme.primary


                Behavior on color {
                    ColorAnimation {
                        duration:
                            Nexa.Theme.animationFast
                    }
                }


                RowLayout {
                    anchors {
                        fill: parent

                        leftMargin:
                            Nexa.Theme.spacingMd

                        rightMargin:
                            Nexa.Theme.spacingMd
                    }

                    spacing:
                        Nexa.Theme.spacingMd


                    Rectangle {
                        Layout.preferredWidth: 36
                        Layout.preferredHeight: 36

                        radius:
                            Nexa.Theme.radiusSm

                        color:
                            resultRow.selected
                            ? Nexa.Theme.primaryContainer
                            : Nexa.Theme.surfaceContainerHigh


                        // ============================================================
                        // REAL APPLICATION ICON
                        // ============================================================

                        Image {
                            anchors.centerIn:
                                parent

                            width: 26
                            height: 26

                            visible:
                                resultRow.modelData.kind === "app"
                                && resultRow.modelData.icon
                                && resultRow.modelData.icon.length > 0

                            source:
                                Quickshell.iconPath(
                                    resultRow.modelData.icon || "",
                                    "application-x-executable"
                                )

                            sourceSize.width:
                                width

                            sourceSize.height:
                                height

                            fillMode:
                                Image.PreserveAspectFit

                            smooth:
                                true
                        }


                        // ============================================================
                        // FILE FALLBACK ICON
                        // ============================================================

                        Image {
                            anchors.centerIn: parent

                            width: 26
                            height: 26

                            visible:
                                resultRow.modelData.kind === "file"

                            source:
                                Quickshell.iconPath(
                                    root.fileIconName(
                                        resultRow.modelData.path
                                    ),
                                    "text-x-generic"
                                )

                            sourceSize.width: width
                            sourceSize.height: height

                            fillMode:
                                Image.PreserveAspectFit

                            smooth: true
                        }
                    }


                    ColumnLayout {
                        Layout.fillWidth: true

                        spacing: 1


                        Text {
                            Layout.fillWidth: true

                            text:
                                resultRow.modelData.name

                            color:
                                Nexa.Theme.text

                            elide:
                                Text.ElideRight

                            font {
                                family:
                                    Nexa.Theme.fontFamily

                                pixelSize:
                                    Nexa.Theme.fontSizeSm

                                weight:
                                    resultRow.selected
                                    ? Nexa.Theme.fontWeightDemiBold
                                    : Nexa.Theme.fontWeightMedium
                            }
                        }


                        Text {
                            Layout.fillWidth: true

                            text:
                                resultRow.modelData.kind
                                === "app"
                                ? "Application"
                                : (
                                    resultRow.modelData.path
                                    || ""
                                )

                            color:
                                Nexa.Theme.mutedText

                            elide:
                                Text.ElideMiddle

                            font {
                                family:
                                    Nexa.Theme.monoFontFamily

                                pixelSize:
                                    Nexa.Theme.fontSize2Xs
                            }
                        }
                    }


                    Text {
                        text:
                            resultRow.modelData.kind
                            === "app"
                            ? "APP"
                            : "FILE"

                        color:
                            resultRow.selected
                            ? Nexa.Theme.primary
                            : Nexa.Theme.mutedText

                        font {
                            family:
                                Nexa.Theme.monoFontFamily

                            pixelSize:
                                Nexa.Theme.fontSize2Xs

                            weight:
                                Nexa.Theme.fontWeightDemiBold
                        }
                    }
                }


                MouseArea {
                    anchors.fill:
                        parent

                    hoverEnabled:
                        true

                    cursorShape:
                        Qt.PointingHandCursor


                    onEntered: {
                        resultRow.hovered = true
                        root.selectedIndex =
                            resultRow.index
                    }


                    onExited:
                        resultRow.hovered = false


                    onClicked: {
                        root.selectedIndex =
                            resultRow.index

                        root.openSelected()
                    }
                }
            }
        }
    }
}
