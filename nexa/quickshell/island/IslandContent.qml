import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../theme" as Nexa
import "../modules/clock"
import "../modules/media"
import "../modules/systeminfo"
import "../modules/search"
import "../modules/command"
import "../modules/recorder"
import "../modules/notifications"
import "../modules/power"
import "../modules/appLauncher"
Item {
    id: root


    // ============================================================
    // RESPONSIBILITY
    //
    // IslandContent.qml owns ONLY CONTENT:
    //
    // - compact presentation
    // - hover presentation
    // - contextual presentation
    // - full Island navigation
    // - full section routing
    //
    // It DOES NOT own:
    //
    // - PanelWindow geometry
    // - Wayland focus
    // - input masks
    // - outside-click behavior
    // - physical Island dimensions
    //
    // Those belong in Island.qml.
    // ============================================================


    // ============================================================
    // STATE RECEIVED FROM Island.qml
    // ============================================================

    property bool hovered: false
    property bool full: false

    // ============================================================
    // TRANSIENT NOTIFICATION
    // ============================================================

    property var notificationData: null
    property var pendingNotificationData: null
    property bool notificationActive: false

    property double lastNotificationSerial: -1

    property bool notificationEventInitialized: false
    signal notificationPreviewActivated()

    function dismissNotification() {
        root.notificationActive = false
        root.pendingNotificationData = null
        notificationTimer.stop()
    }

    function showNotification(data) {
        if (!data || root.full || root.specialModeActive) return
        root.notificationData = data
        root.notificationActive = true
        notificationTimer.interval = Math.max(1, Math.min(data.timeoutMs || 5000, 5000))
        notificationTimer.restart()
    }

    onOsdActiveChanged: {
        if (root.osdActive) {
            if (root.notificationActive) {
                root.pendingNotificationData = root.notificationData
                root.notificationActive = false
                notificationTimer.stop()
            }
        } else {
            if (root.pendingNotificationData !== null) {
                const data = root.pendingNotificationData
                root.pendingNotificationData = null
                if (!root.specialModeActive && !root.full) {
                    root.showNotification(data)
                }
            }
        }
    }

    // ============================================================
    // TRANSIENT OSD (VOLUME / MUTE / BRIGHTNESS / AIRPLANE)
    // ============================================================

    property string osdType: "none"
    property real osdValue: 0.0
    property bool osdMuted: false
    property bool osdAirplaneEnabled: false
    property bool osdActive: false
    property string osdTitle: ""
    property string osdSubtitle: ""
    property string osdIcon: ""
    property bool osdBatteryCharging: false
    property bool osdHasInternet: true
    property bool osdLockEnabled: false

    // ============================================================
    // CONTEXT
    //
    // Future examples:
    //
    // idle
    // media
    // notification
    // volume
    // brightness
    // recording
    // search
    // command
    //
    // For now Clock / Stopwatch is our real implementation.
    // ============================================================

    property string context: "idle"

    // Kept for backward compatibility with Island.qml bindings.
    readonly property bool themePopupOpen: false

    readonly property bool shelfDragInProgress:
        islandShelfLoader.item ? islandShelfLoader.item.dragInProgress : false


    // ============================================================
    // FULL ISLAND SECTION
    // ============================================================

    property string section: "clock"


    // ============================================================
    // COLLAPSED / PERSISTENT CONTEXT STATE
    //
    // Only ONE contextual feature owns the collapsed Island.
    //
    // Priority:
    //     Stopwatch
    //     Media
    //     Idle Clock
    //
    // These properties are also used by Island.qml to select
    // the correct physical height.
    // ============================================================

    readonly property bool recorderContextActive:
        recorderModule.recording
        && !root.notificationActive


    readonly property bool stopwatchContextActive:
        clockModule.stopwatchActive
        && !root.notificationActive
        && !recorderContextActive


    readonly property bool focusContextActive:
        clockModule.focusActive
        && !root.notificationActive
        && !recorderContextActive
        && !clockModule.stopwatchActive


    readonly property bool mediaContextActive:
        mediaModule.contextActive
        && !root.notificationActive
        && !recorderContextActive
        && !clockModule.stopwatchActive
        && !clockModule.focusActive


    readonly property bool persistentContext:
        root.notificationActive
        || recorderContextActive
        || stopwatchContextActive
        || focusContextActive
        || mediaContextActive


    // search n command
    signal requestCloseSpecialMode()
    property string specialMode: "none"

    readonly property bool specialModeActive:
        specialMode !== "none"

    onSpecialModeChanged: {
        if (root.specialMode === "search" && searchIslandLoader.item) {
            Qt.callLater(searchIslandLoader.item.activate)
        }
        if (root.specialMode === "command" && commandIslandLoader.item) {
            Qt.callLater(commandIslandLoader.item.activate)
        }
        if (root.specialMode === "power" && powerIslandLoader.item) {
            Qt.callLater(powerIslandLoader.item.activate)
        }
        if (root.specialMode === "appLauncher" && appLauncherIslandLoader.item) {
            Qt.callLater(appLauncherIslandLoader.item.activate)
        }
        if (root.specialMode === "shelf" && islandShelfLoader.item) {
            Qt.callLater(islandShelfLoader.item.refresh)
        }
    }

    // ============================================================
    // CONTEXT-AWARE FULL OPEN
    //
    // Decides which full section Island.qml should open.
    //
    // Priority follows what the user is currently seeing:
    //     Stopwatch -> Clock (Page 1)
    //     Focus     -> Clock (Page 2)
    //     Media     -> Music
    //     Idle      -> Clock (Page 0)
    // ============================================================

    function preferredFullSection() {

        if (root.stopwatchContextActive) {
            clockModule.page = 1
            return "clock"
        }

        if (root.focusContextActive) {
            clockModule.page = 2
            return "clock"
        }

        if (root.mediaContextActive)
            return "music"

        return "clock"
    }


    // ============================================================
    // MAIN FULL NAVIGATION HEIGHT
    //
    // Clock uses this value as its top margin while full so its
    // content begins BELOW the main four-section navigation.
    // ============================================================

    readonly property int fullNavigationHeight: 34

    // ============================================================
    // FULL CONTENT OFFSET
    //
    // Main Island navigation starts spacingLg below the top.
    // Clock content must begin AFTER:
    //   top margin
    //   navigation
    //   spacing
    //   divider
    //   spacing
    // ============================================================

    readonly property int fullContentTop:
        Nexa.Theme.spacingLg
        + fullNavigationHeight
        + Nexa.Theme.spacingMd
        + 1
        + Nexa.Theme.spacingMd


    // ============================================================
    // TRANSIENT NOTIFICATION PREVIEW
    // ============================================================

    Loader {
        id: notificationIslandLoader
        anchors.fill: parent
        z: 200
        active: root.notificationActive
        visible: active && !root.osdActive && !root.full && !root.specialModeActive
        source: active ? "../modules/notifications/NotificationIsland.qml" : ""
        onLoaded: {
            if (item) {
                item.notification = Qt.binding(() => root.notificationData)
                item.activated.connect(function() {
                    root.notificationActive = false
                    notificationTimer.stop()
                    root.notificationPreviewActivated()
                })
            }
        }
    }    

    // ============================================================
    // TRANSIENT OSD PREVIEW
    // ============================================================

    IslandOsd {
        id: islandOsd
        anchors.fill: parent
        z: 250
        visible: root.osdActive && !root.full && !root.specialModeActive
        osdType: root.osdType
        value: root.osdValue
        muted: root.osdMuted
        airplaneEnabled: root.osdAirplaneEnabled
        title: root.osdTitle
        subtitle: root.osdSubtitle
        icon: root.osdIcon
        batteryCharging: root.osdBatteryCharging
        hasInternet: root.osdHasInternet
        lockEnabled: root.osdLockEnabled
    }

    // ============================================================
    // SINGLE PERSISTENT RECORDER MODULE
    // ============================================================

    Recorder {
        id: recorderModule

        anchors.fill: parent
        z: 10

        visible:
            !root.specialModeActive
            && !root.full
            && !root.osdActive
            && root.recorderContextActive

        presentation: {
            if (root.hovered)
                return "hover"

            return "compact"
        }
    }

    function refreshRecorder() {
        recorderModule.refreshStatus()
    }



    //notifications
    FileView {
        id: notificationEventFile

        path:
            Quickshell.env("HOME")
            + "/.cache/nexa/notification-event.json"

        watchChanges: true

        onFileChanged: {
            reload()
        }

        onLoaded: {
            // First load after Quickshell starts:
            // remember the existing event, but don't replay it.
            if (!root.notificationEventInitialized) {
                try {
                    const text =
                        notificationEventFile.text()

                    if (text && text.length > 0) {
                        const data =
                            JSON.parse(text)

                        if (data.serial) {
                            root.lastNotificationSerial =
                                data.serial
                        }
                    }

                } catch (error) {
                    console.warn(
                        "NEXA notification initial load:",
                        error
                    )
                }

                root.notificationEventInitialized = true
                return
            }

            // Any later load came from a real file change.
            root.loadNotificationEvent()
        }
    }

    Timer {
        id: notificationTimer

        interval:
            5000

        repeat:
            false


        onTriggered: {
            root.notificationActive =
                false
        }
    }


    function loadNotificationEvent() {
        try {
            const text =
                notificationEventFile.text()

            if (!text || text.length === 0)
                return

            const data =
                JSON.parse(text)

            if (!data.serial)
                return

            if (data.serial === root.lastNotificationSerial)
                return

            root.lastNotificationSerial =
                data.serial

            root.notificationData =
                data

            if (
                root.full
                || root.specialModeActive
            ) {
                return
            }

            if (root.osdActive) {
                root.pendingNotificationData = data
                return
            }

            root.showNotification(data)

        } catch (error) {
            console.warn(
                "NEXA notification event:",
                error
            )
        }
    }


    // ============================================================
    // SINGLE PERSISTENT CLOCK MODULE
    //
    // IMPORTANT:
    //
    // There is only ONE Clock instance.
    //
    // This means:
    // - stopwatch survives Island close/open
    // - stopwatch survives Clock -> Music -> Clock navigation
    // - no duplicated stopwatch timers
    // - no state synchronization problem
    //
    // The module simply changes presentation depending on the
    // current physical Island state.
    // ============================================================

    Clock {
        id: clockModule

        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom

            top: parent.top

            // In full Clock mode, leave room for main navigation.
            topMargin:
                root.full && root.section === "clock"
                ? root.fullContentTop
                : 0
        }


        visible: {
            if (root.specialModeActive)
                return false

            if (root.full)
                return root.section === "clock"

            if (root.notificationActive || root.osdActive)
                return false

            if (root.recorderContextActive)
                return false

            if (root.stopwatchContextActive)
                return true

            if (root.focusContextActive)
                return true

            if (root.mediaContextActive)
               return false

            return true
        }


        presentation:
            root.full
            ? "full"
            : root.hovered
                ? "hover"
                : "compact"


        // Keep full-content breathing room.
        anchors.leftMargin:
            root.full
            ? Nexa.Theme.spacingLg
            : 0

        anchors.rightMargin:
            root.full
            ? Nexa.Theme.spacingLg
            : 0

        anchors.bottomMargin:
            root.full
            ? Nexa.Theme.spacingLg
            : 0
    }



    // ============================================================
    // SINGLE PERSISTENT MEDIA MODULE
    //
    // There MUST be only one Media instance.
    //
    // It renders:
    //     compact context
    //     hover context
    //     full Music page
    //
    // This avoids:
    //     duplicate progress bars
    //     duplicate player state
    //     duplicate timers
    // ============================================================

    Media {
        id: mediaModule

        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            top: parent.top


            // Full Music starts below the main Island navigation.
            topMargin:
                root.full
                && root.section === "music"
                ? root.fullContentTop
                : 0


            leftMargin:
                root.full
                ? Nexa.Theme.spacingLg
                  : 0


            rightMargin:
                root.full
                ? Nexa.Theme.spacingLg
                : 0


            bottomMargin:
                root.full
                ? Nexa.Theme.spacingLg
                : 0
        }


        // ========================================================
        // VISIBILITY PRIORITY
        //
        // Full:
        //     only visible inside Music
        //
        // Collapsed/Hover:
        //     Stopwatch wins over Media
        //
        //     Otherwise active/paused Media owns the Island.
        // ========================================================

        visible: {
              if (root.specialModeActive)
                  return false

              if (root.full)
                  return root.section === "music"

              if (root.notificationActive || root.osdActive)
                  return false

              return root.mediaContextActive
          }


        presentation:
            root.full
            ? "full"
            : root.hovered
                ? "hover"
                : "compact"
    }



    // ============================================================
    // FULL ISLAND UI
    //
    // This layer exists only when full == true.
    //
    // Main section navigation lives here.
    //
    // Clock itself remains the persistent module above.
    // Other sections use the section content area below.
    // ============================================================

    Item {
        id: fullLayer

        anchors.fill: parent

        visible:
          root.full
          && !root.specialModeActive

        // Keep above the Clock background if necessary,
        // while individual section content remains below nav.
        z: 2


        // ========================================================
        // MAIN SECTION NAVIGATION
        // ========================================================

        RowLayout {
            id: sectionNavigation

            anchors {
                top: parent.top
                left: parent.left
                right: parent.right

                topMargin: Nexa.Theme.spacingLg
                leftMargin: Nexa.Theme.spacingLg
                rightMargin: Nexa.Theme.spacingLg
            }

            height: root.fullNavigationHeight

            spacing: Nexa.Theme.spacingXs


            Repeater {
                model: [
                    {
                        name: "clock",
                        icon: "󰥔",
                        label: "Clock"
                    },
                    {
                        name: "music",
                        icon: "󰎆",
                        label: "Music"
                    },
                    {
                        name: "system",
                        icon: "󰍛",
                        label: "System"
                    }
                ]


                delegate: Rectangle {
                    id: sectionButton

                    required property var modelData

                    property bool hovered: false
                    property bool pressed: false


                    readonly property bool selected:
                        root.section === modelData.name


                    Layout.fillWidth: true
                    Layout.preferredHeight: 32


                    radius:
                        Nexa.Theme.radiusSm


                    // ------------------------------------------------
                    // Declarative color state.
                    //
                    // Do NOT assign color directly from MouseArea.
                    // That would break this binding.
                    // ------------------------------------------------

                    color: {
                        if (sectionButton.selected)
                            return Nexa.Theme.selected

                        if (sectionButton.pressed)
                            return Nexa.Theme.pressed

                        if (sectionButton.hovered)
                            return Nexa.Theme.hover

                        return "transparent"
                    }


                    Behavior on color {
                        ColorAnimation {
                            duration:
                                Nexa.Theme.animationFast
                        }
                    }


                    Row {
                        anchors.centerIn: parent

                        spacing:
                            Nexa.Theme.spacingXs


                        Text {
                            text:
                                sectionButton.modelData.icon

                            color:
                                sectionButton.selected
                                ? Nexa.Theme.selectedText
                                : Nexa.Theme.mutedText

                            font {
                                family:
                                    Nexa.Theme.iconFontFamily

                                pixelSize:
                                    Nexa.Theme.iconXs
                            }
                        }


                        Text {
                            text:
                                sectionButton.modelData.label

                            color:
                                sectionButton.selected
                                ? Nexa.Theme.selectedText
                                : Nexa.Theme.mutedText

                            font {
                                family:
                                    Nexa.Theme.fontFamily

                                pixelSize:
                                    Nexa.Theme.fontSizeSm

                                weight:
                                    sectionButton.selected
                                    ? Nexa.Theme.fontWeightDemiBold
                                    : Nexa.Theme.fontWeightMedium
                            }
                        }
                    }


                    MouseArea {
                        anchors.fill: parent

                        hoverEnabled: true

                        cursorShape:
                            Qt.PointingHandCursor


                        onEntered:
                            sectionButton.hovered = true


                        onExited: {
                            sectionButton.hovered = false
                            sectionButton.pressed = false
                        }


                        onPressed:
                            sectionButton.pressed = true


                        onReleased:
                            sectionButton.pressed = false


                        onClicked: {
                            root.section =
                                sectionButton.modelData.name
                        }
                    }
                }
            }
        }


        // ========================================================
        // DIVIDER UNDER MAIN NAVIGATION
        // ========================================================

        Rectangle {
            id: navigationDivider

            anchors {
                top: sectionNavigation.bottom
                left: parent.left
                right: parent.right

                topMargin: Nexa.Theme.spacingMd
                leftMargin: Nexa.Theme.spacingLg
                rightMargin: Nexa.Theme.spacingLg
            }

            height: 1

            color:
                Nexa.Theme.divider
        }


        // ========================================================
        // NON-CLOCK SECTION AREA
        //
        // Clock does NOT render here.
        // The persistent clockModule already owns Clock content.
        //
        // Music / System / Theme appear in this area.
        // ========================================================

        Item {
            id: alternateSectionArea

            anchors {
                top: navigationDivider.bottom
                left: parent.left
                right: parent.right
                bottom: parent.bottom

                topMargin: Nexa.Theme.spacingMd
                leftMargin: Nexa.Theme.spacingLg
                rightMargin: Nexa.Theme.spacingLg
                bottomMargin: Nexa.Theme.spacingLg
            }


            visible:
                root.section !== "clock"


            Loader {
                id: sectionLoader

                anchors.fill: parent

                sourceComponent: {
                    switch (root.section) {

                    case "system":
                        return systemInfoComponent

                    default:
                        return null
                    }
                }
            }
        }
    }



    property int pendingControlCenterPage: 0

    Loader {
        id: searchIslandLoader
        anchors.fill: parent
        active: root.specialMode === "search"
        visible: active && root.full
        z: 100
        source: active ? "../modules/search/SearchIsland.qml" : ""
        onLoaded: {
            if (item) {
                item.accepted.connect(root.requestCloseSpecialMode)
                item.requestClose.connect(root.requestCloseSpecialMode)
                Qt.callLater(item.activate)
            }
        }
    }

    Loader {
        id: commandIslandLoader
        anchors.fill: parent
        active: root.specialMode === "command"
        visible: active && root.full
        z: 100
        source: active ? "../modules/command/CommandIsland.qml" : ""
        onLoaded: {
            if (item) {
                item.requestClose.connect(root.requestCloseSpecialMode)
                Qt.callLater(item.activate)
            }
        }
    }

    Loader {
        id: powerIslandLoader
        anchors.fill: parent
        active: root.specialMode === "power"
        visible: active && root.full
        z: 100
        source: active ? "../modules/power/PowerIsland.qml" : ""
        onLoaded: {
            if (item) {
                item.requestClose.connect(root.requestCloseSpecialMode)
                Qt.callLater(item.activate)
            }
        }
    }

    Loader {
        id: appLauncherIslandLoader
        anchors.fill: parent
        active: root.specialMode === "appLauncher"
        visible: active && root.full
        z: 100
        source: active ? "../modules/appLauncher/AppLauncherIsland.qml" : ""
        onLoaded: {
            if (item) {
                item.requestClose.connect(root.requestCloseSpecialMode)
                Qt.callLater(item.activate)
            }
        }
    }

    Loader {
        id: controlCenterIslandLoader
        anchors.fill: parent
        active: root.specialMode === "controlCenter"
        visible: active && root.full
        z: 100
        source: active ? "ControlCenterIsland.qml" : ""
        onLoaded: {
            if (item) {
                item.currentPage = root.pendingControlCenterPage
                item.requestClose.connect(root.requestCloseSpecialMode)
            }
        }
    }

    Loader {
        id: islandShelfLoader
        anchors.fill: parent
        active: root.specialMode === "shelf"
        visible: active && root.full
        z: 100
        source: active ? "IslandShelf.qml" : ""
        onLoaded: {
            if (item) {
                item.requestClose.connect(root.requestCloseSpecialMode)
                Qt.callLater(item.refresh)
            }
        }
    }

    function setControlCenterPage(page) {
        root.pendingControlCenterPage = page
        if (controlCenterIslandLoader.item) {
            controlCenterIslandLoader.item.currentPage = page
        }
    }

    function triggerPowerKey(keyNum) {
        if (powerIslandLoader.item) {
            powerIslandLoader.item.triggerKeyNumber(keyNum)
        }
    }

    // ============================================================
    // TEMPORARY SYSTEM PLACEHOLDER
    //
    // Later replaced by:
    // modules/systeminfo/SystemInfo.qml
    // ============================================================

    Component {
        id: systemInfoComponent

        SystemInfo {
            anchors.fill: parent
        }
    }


}
