import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../theme" as ThemeModule
import "../theme/components" as NexaUI

import "../modules/audio" as AudioModule
import "../modules/brightness" as BrightnessModule
import "../modules/network" as NetworkModule
import "../modules/airplane" as AirplaneModule
import "../modules/vpn" as VpnModule
import "../modules/nightlight" as NightLightModule
import "../modules/screenfilter" as ScreenFilterModule
import "../modules/notifications" as NotificationModule
import "../modules/recorder" as RecorderModule
import "../modules/battery" as BatteryModule

Item {
    id: root

    readonly property var theme:
        ThemeModule.Theme

    property bool appsExpanded: false
    property bool screenFilterDropdownOpen: false
    property bool sinkMenuOpen: false

    // ============================================================
    // ACTION HELPERS
    // ============================================================

    function takeScreenshot() {
        if (screenshotProcess.running)
            return

        screenshotProcess.exec([
            Quickshell.env("HOME")
                + "/.config/nexa/rust/target/release/nexad",
            "screenshot",
            "capture"
        ])
    }


    function openClipboard() {
        if (clipboardOpenProcess.running)
            return

        clipboardOpenProcess.exec([
            "qs",
            "-p",
            Quickshell.env("HOME")
                + "/.config/nexa/quickshell",
            "ipc",
            "call",
            "clipboard",
            "open"
        ])
    }


    AudioModule.Audio {
        id: audio
    }


    BrightnessModule.Brightness {
        id: brightness
    }

    NetworkModule.Wifi {
        id: wifi
        visible: false
    }

    NetworkModule.Bluetooth {
        id: bluetooth
        visible: false
    }

    AirplaneModule.Airplane {
        id: airplane
        visible: false
    }

    VpnModule.Vpn {
        id: vpn
        visible: false
    }


    NightLightModule.NightLight {
        id: nightLight
        visible: false
    }

    ScreenFilterModule.ScreenFilter {
        id: screenFilter
        visible: false
    }

    NotificationModule.Dnd {
        id: dnd
        visible: false
    }


    RecorderModule.RecorderControl {
        id: recorderControl
        visible: false
    }


    // ============================================================
    // SCREENSHOT
    // ============================================================

    Process {
        id: screenshotProcess

        stdout: StdioCollector {
            onStreamFinished: {
                const value =
                    this.text.trim()

                if (value.length > 0)
                    console.log(
                        "[QuickSettings:Screenshot]",
                        value
                    )
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                const value =
                    this.text.trim()

                if (value.length > 0)
                    console.error(
                        "[QuickSettings:Screenshot]",
                        value
                    )
            }
        }
    }


    // ============================================================
    // CLIPBOARD
    // ============================================================

    Process {
        id: clipboardOpenProcess

        stdout: StdioCollector {
            onStreamFinished: {
                const value =
                    this.text.trim()

                if (value.length > 0)
                    console.log(
                        "[QuickSettings:Clipboard]",
                        value
                    )
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                const value =
                    this.text.trim()

                if (value.length > 0)
                    console.error(
                        "[QuickSettings:Clipboard]",
                        value
                    )
            }
        }
    }


    // ============================================================
    // MAIN LAYOUT
    // ============================================================

    ColumnLayout {
        anchors {
            fill: parent
            margins: root.theme.spacingLg
        }
        spacing: root.theme.spacingSm


        // ========================================================
        // HEADER  (fixed – not scrollable)
        // ========================================================

        Rectangle {
            Layout.fillWidth: true

            Layout.preferredHeight:
                qsHeaderContent.implicitHeight
                + root.theme.spacingLg * 2

            radius: root.theme.radiusLg
            color: root.theme.panelBackgroundElevated

            border {
                width: root.theme.borderThin
                color: root.theme.divider
            }


            RowLayout {
                id: qsHeaderContent

                anchors {
                    left: parent.left
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                    leftMargin: root.theme.spacingLg
                    rightMargin: root.theme.spacingLg
                }

                spacing: root.theme.spacingMd

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: root.theme.spacing2Xs

                    Text {
                        text: "Quick Settings"
                        color: root.theme.text
                        font {
                            family: root.theme.fontFamily
                            pixelSize: root.theme.fontSizeXl
                            weight: root.theme.fontWeightDemiBold
                        }
                    }

                    Text {
                        text: "Connectivity & controls"
                        color: root.theme.mutedText
                        font {
                            family: root.theme.fontFamily
                            pixelSize: root.theme.fontSizeSm
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                BatteryModule.Battery {
                    Layout.alignment: Qt.AlignVCenter
                }
            }
        }


        // ========================================================
        // SCROLLABLE CONTENT
        // ========================================================

        Flickable {
            id: qsFlickable
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: width
            contentHeight: contentColumn.height
            boundsBehavior: Flickable.DragAndOvershootBounds
            maximumFlickVelocity: 2200
            flickDeceleration: 1400

            // Modern auto-hiding scrollbar
            Rectangle {
                id: scrollbar
                anchors.right: parent.right
                anchors.rightMargin: 3
                y: qsFlickable.visibleArea.yPosition * qsFlickable.height
                height: Math.max(32, qsFlickable.visibleArea.heightRatio * qsFlickable.height)
                width: 4
                radius: 2
                color: root.theme.primary
                opacity: (qsFlickable.moving || qsFlickable.flicking) ? 0.6 : 0.0
                Behavior on opacity {
                    NumberAnimation { duration: root.theme.animationNormal }
                }
            }


            Column {
                id: contentColumn

                width:
                    parent.width

                spacing:
                    root.theme.spacingLg



            // ============================================================
            // CONNECTIVITY
            // ============================================================

            Text {
                leftPadding: root.theme.spacingLg
                text: "Connectivity"
                color: theme.text
                font {
                    family: theme.fontFamily
                    pixelSize: theme.fontSizeSm
                    weight: theme.fontWeightDemiBold
                }
            }


            Grid {
                id: connectivityGrid

                anchors {
                    left: parent.left
                    right: parent.right
                    leftMargin: root.theme.spacingLg
                    rightMargin: root.theme.spacingLg
                }

                columns: 2
                columnSpacing: theme.spacingSm
                rowSpacing: theme.spacingSm


                // ========================================================
                // WI-FI
                // ========================================================

                NexaUI.NexaCard {
                    width: (parent.width - theme.spacingSm) / 2
                    height: 80
                    clip: true

                    interactive: true
                    selected: wifi.enabled
                    onClicked: wifi.toggle()

                    Column {
                        anchors {
                            left: parent.left
                            right: parent.right
                            verticalCenter: parent.verticalCenter
                        }
                        spacing: 3

                        Text {
                            text: {
                                if (!wifi.enabled) return "󰤭"
                                if (!wifi.connected) return "󰤭"
                                if (wifi.strength >= 75) return "󰤨"
                                if (wifi.strength >= 50) return "󰤥"
                                if (wifi.strength >= 25) return "󰤢"
                                return "󰤟"
                            }
                            color: wifi.enabled ? theme.primaryContainerText : theme.mutedText
                            font.family: theme.iconFontFamily
                            font.pixelSize: theme.iconMd
                        }

                        Text {
                            width: parent.width
                            text: "Wi-Fi"
                            color: wifi.enabled ? theme.primaryContainerText : theme.text
                            elide: Text.ElideRight
                            font.family: theme.fontFamily
                            font.pixelSize: theme.fontSizeSm
                            font.bold: true
                        }

                        Text {
                            width: parent.width
                            text: !wifi.enabled ? "Off" : wifi.connected ? wifi.ssid : "Disconnected"
                            color: wifi.enabled ? theme.primaryContainerText : theme.mutedText
                            opacity: 0.8
                            elide: Text.ElideRight
                            font.family: theme.fontFamily
                            font.pixelSize: theme.fontSizeXs
                        }
                    }
                }


                // ========================================================
                // BLUETOOTH
                // ========================================================

                NexaUI.NexaCard {
                    width: (parent.width - theme.spacingSm) / 2
                    height: 80
                    clip: true

                    interactive: true
                    selected: bluetooth.enabled
                    onClicked: bluetooth.toggle()

                    Column {
                        anchors {
                            left: parent.left
                            right: parent.right
                            verticalCenter: parent.verticalCenter
                        }
                        spacing: 3

                        Text {
                            text: bluetooth.enabled ? "󰂯" : "󰂲"
                            color: bluetooth.enabled ? theme.primaryContainerText : theme.mutedText
                            font.family: theme.iconFontFamily
                            font.pixelSize: theme.iconMd
                        }

                        Text {
                            width: parent.width
                            text: "Bluetooth"
                            color: bluetooth.enabled ? theme.primaryContainerText : theme.text
                            elide: Text.ElideRight
                            font.family: theme.fontFamily
                            font.pixelSize: theme.fontSizeSm
                            font.bold: true
                        }

                        Text {
                            width: parent.width
                            text: !bluetooth.enabled ? "Off" : bluetooth.connected ? bluetooth.connectedDeviceName : "On"
                            color: bluetooth.enabled ? theme.primaryContainerText : theme.mutedText
                            opacity: 0.8
                            elide: Text.ElideRight
                            font.family: theme.fontFamily
                            font.pixelSize: theme.fontSizeXs
                        }
                    }
                }


                // ========================================================
                // AIRPLANE
                // ========================================================

                NexaUI.NexaCard {
                    width: (parent.width - theme.spacingSm) / 2
                    height: 80
                    clip: true

                    interactive: true
                    selected: airplane.enabled
                    onClicked: airplane.toggle()

                    Column {
                        anchors {
                            left: parent.left
                            right: parent.right
                            verticalCenter: parent.verticalCenter
                        }
                        spacing: 3

                        Text {
                            text: airplane.enabled ? "󰀝" : "󰀞"
                            color: airplane.enabled ? theme.primaryContainerText : theme.mutedText
                            font.family: theme.iconFontFamily
                            font.pixelSize: theme.iconMd
                        }

                        Text {
                            width: parent.width
                            text: "Airplane"
                            color: airplane.enabled ? theme.primaryContainerText : theme.text
                            elide: Text.ElideRight
                            font.family: theme.fontFamily
                            font.pixelSize: theme.fontSizeSm
                            font.bold: true
                        }

                        Text {
                            width: parent.width
                            text: airplane.enabled ? "On" : "Off"
                            color: airplane.enabled ? theme.primaryContainerText : theme.mutedText
                            opacity: 0.8
                            font.family: theme.fontFamily
                            font.pixelSize: theme.fontSizeXs
                        }
                    }
                }


                // ========================================================
                // VPN
                // ========================================================

                NexaUI.NexaCard {
                    width: (parent.width - theme.spacingSm) / 2
                    height: 80
                    clip: true
                    opacity: vpn.available ? 1.0 : 0.45

                    interactive: vpn.available
                    selected: vpn.enabled
                    onClicked: vpn.toggle()

                    Column {
                        anchors {
                            left: parent.left
                            right: parent.right
                            verticalCenter: parent.verticalCenter
                        }
                        spacing: 3

                        Text {
                            text: vpn.enabled ? "󰖂" : "󰦝"
                            color: vpn.enabled ? theme.primaryContainerText : theme.mutedText
                            font.family: theme.iconFontFamily
                            font.pixelSize: theme.iconMd
                        }

                        Text {
                            width: parent.width
                            text: "VPN"
                            color: vpn.enabled ? theme.primaryContainerText : theme.text
                            elide: Text.ElideRight
                            font.family: theme.fontFamily
                            font.pixelSize: theme.fontSizeSm
                            font.bold: true
                        }

                        Text {
                            width: parent.width
                            text: !vpn.available ? "No profile" : vpn.enabled ? vpn.activeProfile : "Disconnected"
                            color: vpn.enabled ? theme.primaryContainerText : theme.mutedText
                            opacity: 0.8
                            elide: Text.ElideRight
                            font.family: theme.fontFamily
                            font.pixelSize: theme.fontSizeXs
                        }
                    }
                }
            }


            // ====================================================
            // AUDIO CARD
            // ====================================================

            Rectangle {
                width:
                    parent.width
                    - root.theme.spacingLg * 2

                anchors.horizontalCenter:
                    parent.horizontalCenter

                implicitHeight:
                    audioColumn.implicitHeight
                    + root.theme.spacingLg * 2

                radius:
                    root.theme.radiusLg

                color:
                    root.theme.cardBackground

                border.width:
                    root.theme.borderThin

                border.color:
                    root.theme.border


                Column {
                    id: audioColumn

                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top

                        margins:
                            root.theme.spacingLg
                    }

                    spacing:
                        root.theme.spacingLg


                    // ============================================
                    // AUDIO HEADER & OUTPUT DEVICE SELECTOR
                    // ============================================

                    RowLayout {
                        width: parent.width

                        Text {
                            text: "Audio"
                            color: root.theme.text
                            font.family: root.theme.fontFamily
                            font.pixelSize: root.theme.fontSizeLg
                            font.weight: root.theme.fontWeightDemiBold
                        }

                        Item { Layout.fillWidth: true }

                        // Audio Output Device Chip
                        Rectangle {
                            id: sinkChip
                            implicitHeight: 28
                            implicitWidth: sinkChipContent.implicitWidth + 20
                            radius: 14
                            color: root.sinkMenuOpen
                                ? root.theme.primaryContainer
                                : sinkChipMouse.containsMouse
                                    ? root.theme.hoverStrong
                                    : root.theme.cardBackgroundElevated

                            border.width: root.theme.borderThin
                            border.color: root.sinkMenuOpen ? root.theme.primary : root.theme.border

                            Row {
                                id: sinkChipContent
                                anchors.centerIn: parent
                                spacing: 6

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: {
                                        for (let i = 0; i < audio.sinks.length; ++i) {
                                            if (audio.sinks[i].active) return audio.sinks[i].icon
                                        }
                                        return "󰕾"
                                    }
                                    font.family: root.theme.iconFontFamily
                                    font.pixelSize: root.theme.iconSm
                                    color: root.sinkMenuOpen ? root.theme.primaryContainerText : root.theme.primary
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: {
                                        for (let i = 0; i < audio.sinks.length; ++i) {
                                            if (audio.sinks[i].active) {
                                                const d = audio.sinks[i].description
                                                return d.length > 18 ? d.substring(0, 16) + "…" : d
                                            }
                                        }
                                        return "Output Device"
                                    }
                                    font.family: root.theme.fontFamily
                                    font.pixelSize: root.theme.fontSize2Xs
                                    font.weight: root.theme.fontWeightMedium
                                    color: root.sinkMenuOpen ? root.theme.primaryContainerText : root.theme.text
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: root.sinkMenuOpen ? "▴" : "▾"
                                    font.family: root.theme.fontFamily
                                    font.pixelSize: root.theme.fontSize2Xs
                                    color: root.sinkMenuOpen ? root.theme.primaryContainerText : root.theme.mutedText
                                }
                            }

                            MouseArea {
                                id: sinkChipMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.sinkMenuOpen = !root.sinkMenuOpen
                            }
                        }
                    }

                    // Expandable Audio Sinks Menu
                    Column {
                        visible: root.sinkMenuOpen && audio.sinks.length > 0
                        width: parent.width
                        spacing: root.theme.spacingXs

                        Repeater {
                            model: audio.sinks
                            delegate: Rectangle {
                                width: parent.width
                                height: 36
                                radius: root.theme.radiusMd
                                color: modelData.active
                                    ? root.theme.primaryContainer
                                    : (sinkItemMouse.containsMouse ? root.theme.hover : root.theme.cardBackgroundElevated)

                                border.width: root.theme.borderThin
                                border.color: modelData.active ? root.theme.primary : root.theme.border

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: root.theme.spacingMd
                                    anchors.rightMargin: root.theme.spacingMd
                                    spacing: root.theme.spacingSm

                                    Text {
                                        text: modelData.icon
                                        font.family: root.theme.iconFontFamily
                                        font.pixelSize: root.theme.iconSm
                                        color: modelData.active ? root.theme.primaryContainerText : root.theme.primary
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.description
                                        elide: Text.ElideRight
                                        font.family: root.theme.fontFamily
                                        font.pixelSize: root.theme.fontSizeXs
                                        font.weight: modelData.active ? root.theme.fontWeightDemiBold : root.theme.fontWeightRegular
                                        color: modelData.active ? root.theme.primaryContainerText : root.theme.text
                                    }

                                    Text {
                                        visible: modelData.active
                                        text: "󰄬"
                                        font.family: root.theme.iconFontFamily
                                        font.pixelSize: root.theme.iconSm
                                        color: root.theme.primaryContainerText
                                    }
                                }

                                MouseArea {
                                    id: sinkItemMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        audio.setSink(modelData.name)
                                        root.sinkMenuOpen = false
                                    }
                                }
                            }
                        }
                    }


                    // ============================================
                    // OUTPUT
                    // ============================================

                    Column {
                        width:
                            parent.width

                        spacing:
                            root.theme.spacingSm


                        Row {
                            width:
                                parent.width

                            height:
                                root.theme.controlHeightMd

                            spacing:
                                root.theme.spacingMd


                            NexaUI.NexaIconButton {
                                id: outputMuteButton

                                icon: audio.muted
                                    ? "󰝟"
                                    : (
                                        audio.volume < 35
                                        ? "󰕿"
                                        : audio.volume < 70
                                            ? "󰖀"
                                            : "󰕾"
                                    )

                                selected: !audio.muted
                                onClicked: audio.toggleMute()
                            }


                            Column {
                                width:
                                    parent.width
                                    - outputMuteButton.width
                                    - outputPercent.width
                                    - appsButton.width
                                    - root.theme.spacingMd * 3

                                anchors.verticalCenter:
                                    parent.verticalCenter

                                spacing:
                                    root.theme.spacing2Xs


                                Text {
                                    text:
                                        "Output"

                                    color:
                                        root.theme.text

                                    font.family:
                                        root.theme.fontFamily

                                    font.pixelSize:
                                        root.theme.fontSizeMd

                                    font.weight:
                                        root.theme.fontWeightMedium
                                }


                                Text {
                                    text:
                                        audio.muted
                                        ? "Muted"
                                        : "System volume"

                                    color:
                                        root.theme.mutedText

                                    font.family:
                                        root.theme.fontFamily

                                    font.pixelSize:
                                        root.theme.fontSizeXs
                                }
                            }


                            Text {
                                id: outputPercent

                                anchors.verticalCenter:
                                    parent.verticalCenter

                                text:
                                    audio.volume
                                    + "%"

                                color:
                                    root.theme.text

                                font.family:
                                    root.theme.monoFontFamily

                                font.pixelSize:
                                    root.theme.fontSizeSm
                            }


                            Rectangle {
                                id: appsButton

                                width:
                                    root.theme.controlHeightMd

                                height:
                                    width

                                radius:
                                    root.theme.radiusMd

                                color:
                                    appsMouse.pressed
                                    ? root.theme.pressed
                                    : appsMouse.containsMouse
                                        ? root.theme.hoverStrong
                                        : root.theme.surfaceContainerHighest


                                Text {
                                    anchors.centerIn:
                                        parent

                                    text:
                                        "󰅀"

                                    rotation:
                                        root.appsExpanded
                                        ? 180
                                        : 0

                                    color:
                                        root.theme.text

                                    font.family:
                                        root.theme.iconFontFamily

                                    font.pixelSize:
                                        root.theme.iconSm


                                    Behavior on rotation {
                                        NumberAnimation {
                                            duration:
                                                root.theme.animationFast

                                            easing.type:
                                                root.theme.easingStandard
                                        }
                                    }
                                }


                                MouseArea {
                                    id: appsMouse

                                    anchors.fill:
                                        parent

                                    hoverEnabled:
                                        true

                                    cursorShape:
                                        Qt.PointingHandCursor

                                    onClicked: {
                                        root.appsExpanded =
                                            !root.appsExpanded

                                        if (
                                            root.appsExpanded
                                        ) {
                                            audio.refreshApps()
                                        }
                                    }
                                }
                            }
                        }


                        NexaUI.NexaSlider {
                            width: parent.width
                            sliderHeight: 34
                            sliderRadius: 10
                            from: 0
                            to: 100
                            value: audio.volume
                            icon: audio.muted ? "󰝟" : (audio.volume > 50 ? "󰕾" : (audio.volume > 0 ? "󰖀" : "󰕿"))
                            iconInteractive: true
                            onIconClicked: audio.toggleMute()
                            onMoved: (val) => audio.setVolume(val)
                            onReleased: (val) => audio.setVolumeImmediate(val)
                        }
                    }


                    // ============================================
                    // APP OUTPUTS
                    // ============================================

                    Rectangle {
                        width:
                            parent.width

                        height:
                            root.appsExpanded
                            ? Math.min(
                                220,
                                Math.max(
                                    64,
                                    appList.contentHeight
                                    + root.theme.spacingMd * 2
                                )
                            )
                            : 0

                        visible:
                            height > 0

                        opacity:
                            root.appsExpanded
                            ? 1
                            : 0

                        radius:
                            root.theme.radiusMd

                        color:
                            root.theme.cardBackgroundElevated

                        border.width:
                            root.theme.borderThin

                        border.color:
                            root.theme.border

                        clip:
                            true


                        Behavior on height {
                            NumberAnimation {
                                duration:
                                    root.theme.animationNormal

                                easing.type:
                                    root.theme.easingStandard
                            }
                        }


                        Behavior on opacity {
                            NumberAnimation {
                                duration:
                                    root.theme.animationFast
                            }
                        }


                        Text {
                            anchors.centerIn:
                                parent

                            visible:
                                !audio.appsLoading
                                && audio.apps.length === 0

                            text:
                                "No active audio applications"

                            color:
                                root.theme.mutedText

                            font.family:
                                root.theme.fontFamily

                            font.pixelSize:
                                root.theme.fontSizeSm
                        }


                        Text {
                            anchors.centerIn:
                                parent

                            visible:
                                audio.appsLoading

                            text:
                                "Loading audio streams..."

                            color:
                                root.theme.mutedText

                            font.family:
                                root.theme.fontFamily

                            font.pixelSize:
                                root.theme.fontSizeSm
                        }


                        ListView {
                            id: appList

                            anchors {
                                fill: parent

                                margins:
                                    root.theme.spacingMd
                            }

                            visible:
                                !audio.appsLoading
                                && audio.apps.length > 0

                            clip:
                                true

                            spacing:
                                root.theme.spacingSm

                            model:
                                audio.apps


                            delegate: Column {
                                required property var modelData

                                width:
                                    ListView.view.width

                                height: 64

                                spacing:
                                    root.theme.spacingXs


                                Row {
                                    width:
                                        parent.width

                                    height: 28

                                    spacing:
                                        root.theme.spacingSm


                                    Text {
                                        width:
                                            parent.width
                                            - appPercent.width
                                            - appMute.width
                                            - root.theme.spacingSm * 2

                                        anchors.verticalCenter:
                                            parent.verticalCenter

                                        text:
                                            modelData.name

                                        elide:
                                            Text.ElideRight

                                        color:
                                            root.theme.text

                                        font.family:
                                            root.theme.fontFamily

                                        font.pixelSize:
                                            root.theme.fontSizeSm
                                    }


                                    Text {
                                        id: appPercent

                                        anchors.verticalCenter:
                                            parent.verticalCenter

                                        text:
                                            modelData.volume
                                            + "%"

                                        color:
                                            root.theme.mutedText

                                        font.family:
                                            root.theme.monoFontFamily

                                        font.pixelSize:
                                            root.theme.fontSizeXs
                                    }


                                    Rectangle {
                                        id: appMute

                                        width: 28
                                        height: 28

                                        radius:
                                            root.theme.radiusSm

                                        color:
                                            appMuteMouse.containsMouse
                                            ? root.theme.hoverStrong
                                            : "transparent"


                                        Text {
                                            anchors.centerIn:
                                                parent

                                            text:
                                                modelData.muted
                                                ? "󰝟"
                                                : "󰕾"

                                            color:
                                                modelData.muted
                                                ? root.theme.mutedText
                                                : root.theme.text

                                            font.family:
                                                root.theme.iconFontFamily

                                            font.pixelSize:
                                                root.theme.iconSm
                                        }


                                        MouseArea {
                                            id: appMuteMouse

                                            anchors.fill:
                                                parent

                                            hoverEnabled:
                                                true

                                            cursorShape:
                                                Qt.PointingHandCursor

                                            onClicked:
                                                audio.toggleAppMute(
                                                    modelData.id
                                                )
                                        }
                                    }
                                }


                                NexaUI.NexaSlider {
                                    width: parent.width
                                    sliderHeight: 28
                                    sliderRadius: 8

                                    from: 0
                                    to: 100

                                    value:
                                        modelData.volume


                                    onMoved: (val) => audio.setAppVolume(modelData.id, val)
                                    onReleased: (val) => audio.setAppVolumeImmediate(modelData.id, val)
                                }
                            }
                        }
                    }


                    // ============================================
                    // DIVIDER
                    // ============================================

                    Rectangle {
                        width:
                            parent.width

                        height:
                            root.theme.borderThin

                        color:
                            root.theme.divider
                    }


                    // ============================================
                    // MICROPHONE INPUT
                    // ============================================

                    Column {
                        width:
                            parent.width

                        spacing:
                            root.theme.spacingSm


                        Row {
                            width:
                                parent.width

                            height:
                                root.theme.controlHeightMd

                            spacing:
                                root.theme.spacingMd


                            // ====================================
                            // MIC OFF BUTTON
                            // ====================================

                            Rectangle {
                                id: micButton

                                width:
                                    root.theme.controlHeightMd

                                height:
                                    width

                                radius:
                                    root.theme.radiusMd

                                color:
                                    micMouse.pressed
                                    ? root.theme.pressed
                                    : micMouse.containsMouse
                                        ? root.theme.hoverStrong
                                        : audio.inputMuted
                                            ? root.theme.errorContainer
                                            : root.theme.primaryContainer


                                Text {
                                    anchors.centerIn:
                                        parent

                                    text:
                                        audio.inputMuted
                                        ? "󰍭"
                                        : "󰍬"

                                    color:
                                        audio.inputMuted
                                        ? root.theme.error
                                        : root.theme.primaryContainerText

                                    font.family:
                                        root.theme.iconFontFamily

                                    font.pixelSize:
                                        root.theme.iconMd
                                }


                                MouseArea {
                                    id: micMouse

                                    anchors.fill:
                                        parent

                                    hoverEnabled:
                                        true

                                    cursorShape:
                                        Qt.PointingHandCursor

                                    onClicked:
                                        audio.toggleInputMute()
                                }
                            }


                            Column {
                                width:
                                    parent.width
                                    - micButton.width
                                    - inputPercent.width
                                    - root.theme.spacingMd * 2

                                anchors.verticalCenter:
                                    parent.verticalCenter

                                spacing:
                                    root.theme.spacing2Xs


                                Text {
                                    text:
                                        audio.inputMuted
                                        ? "Mic Off"
                                        : "Microphone"

                                    color:
                                        audio.inputMuted
                                        ? root.theme.error
                                        : root.theme.text

                                    font.family:
                                        root.theme.fontFamily

                                    font.pixelSize:
                                        root.theme.fontSizeMd

                                    font.weight:
                                        root.theme.fontWeightMedium
                                }


                                Text {
                                    text:
                                        audio.inputMuted
                                        ? "Input muted"
                                        : "Input volume"

                                    color:
                                        root.theme.mutedText

                                    font.family:
                                        root.theme.fontFamily

                                    font.pixelSize:
                                        root.theme.fontSizeXs
                                }
                            }


                            Text {
                                id: inputPercent

                                anchors.verticalCenter:
                                    parent.verticalCenter

                                text:
                                    audio.inputVolume
                                    + "%"

                                color:
                                    audio.inputMuted
                                    ? root.theme.mutedText
                                    : root.theme.text

                                font.family:
                                    root.theme.monoFontFamily

                                font.pixelSize:
                                    root.theme.fontSizeSm
                            }
                        }


                        NexaUI.NexaSlider {
                            width: parent.width
                            sliderHeight: 34
                            sliderRadius: 10
                            from: 0
                            to: 100
                            value: audio.inputVolume
                            icon: audio.inputMuted ? "󰍭" : "󰍬"
                            iconInteractive: true
                            livePulse: !audio.inputMuted ? audio.micPeak : 0.0
                            onIconClicked: audio.toggleInputMute()
                            onMoved: (val) => audio.setInputVolume(val)
                            onReleased: (val) => audio.setInputVolumeImmediate(val)
                        }
                    }
                }
            }


            // ============================================================
            // DISPLAY
            // ============================================================

            Text {
                leftPadding: root.theme.spacingLg
                text: "Display"
                color: theme.text
                font {
                    family: theme.fontFamily
                    pixelSize: theme.fontSizeSm
                    weight: theme.fontWeightDemiBold
                }
            }



            // ============================================================
            // ACTIONS
            // ============================================================

            Text {
                leftPadding: root.theme.spacingLg
                text: "Actions"
                color: theme.text
                font {
                    family: theme.fontFamily
                    pixelSize: theme.fontSizeSm
                    weight: theme.fontWeightDemiBold
                }
            }


            Grid {
                anchors {
                    left: parent.left
                    right: parent.right
                    leftMargin: root.theme.spacingLg
                    rightMargin: root.theme.spacingLg
                }

                columns: 2
                columnSpacing: theme.spacingSm
                rowSpacing: theme.spacingSm


                // ========================================================
                // DND
                // ========================================================

                Rectangle {
                    width: (parent.width - theme.spacingSm) / 2
                    height: 80
                    radius: theme.radiusMd
                    clip: true

                    color: dnd.enabled
                        ? theme.primaryContainer
                        : dndMouse.containsMouse
                            ? theme.hoverStrong
                            : theme.cardBackgroundElevated

                    Behavior on color { ColorAnimation { duration: theme.animationFast } }

                    border.width: theme.borderThin
                    border.color: dnd.enabled ? theme.primary : theme.border

                    scale: dndMouse.pressed ? root.theme.pressScale : 1.0
                    Behavior on scale { NumberAnimation { duration: theme.animationFast; easing.type: theme.easingStandard } }


                    Column {
                        anchors {
                            left: parent.left
                            right: parent.right
                            verticalCenter: parent.verticalCenter
                            leftMargin: theme.spacingMd
                            rightMargin: theme.spacingMd
                        }
                        spacing: 3

                        Row {
                            spacing: theme.spacingSm

                            Text {
                                text: "󰂛"
                                color: dnd.enabled ? theme.primaryContainerText : theme.mutedText
                                font.family: theme.iconFontFamily
                                font.pixelSize: theme.iconMd
                            }

                            Text {
                                text: "DND"
                                color: dnd.enabled ? theme.primaryContainerText : theme.text
                                font.family: theme.fontFamily
                                font.pixelSize: theme.fontSizeSm
                                font.bold: true
                            }
                        }

                        Text {
                            text: dnd.enabled ? "On" : "Off"
                            color: dnd.enabled ? theme.primaryContainerText : theme.mutedText
                            opacity: 0.8
                            font.family: theme.fontFamily
                            font.pixelSize: theme.fontSizeXs
                        }
                    }

                    MouseArea {
                        id: dndMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: !dnd.changing
                        cursorShape: Qt.PointingHandCursor
                        onClicked: dnd.toggle()
                    }
                }


                // ========================================================
                // RECORDER
                // ========================================================

                Rectangle {
                    width: (parent.width - theme.spacingSm) / 2
                    height: 80
                    radius: theme.radiusMd
                    clip: true

                    color: recorderControl.recording
                        ? theme.primaryContainer
                        : recorderMouse.containsMouse
                            ? theme.hoverStrong
                            : theme.cardBackgroundElevated

                    Behavior on color { ColorAnimation { duration: theme.animationFast } }

                    border.width: theme.borderThin
                    border.color: recorderControl.recording ? theme.primary : theme.border

                    scale: recorderMouse.pressed ? root.theme.pressScale : 1.0
                    Behavior on scale { NumberAnimation { duration: theme.animationFast; easing.type: theme.easingStandard } }


                    Column {
                        anchors {
                            left: parent.left
                            right: parent.right
                            verticalCenter: parent.verticalCenter
                            leftMargin: theme.spacingMd
                            rightMargin: theme.spacingMd
                        }
                        spacing: 3

                        Row {
                            spacing: theme.spacingSm

                            Text {
                                text: recorderControl.recording ? "󰑊" : "󰻂"
                                color: recorderControl.recording ? theme.primaryContainerText : theme.mutedText
                                font.family: theme.iconFontFamily
                                font.pixelSize: theme.iconMd
                            }

                            Text {
                                text: "Recorder"
                                color: recorderControl.recording ? theme.primaryContainerText : theme.text
                                font.family: theme.fontFamily
                                font.pixelSize: theme.fontSizeSm
                                font.bold: true
                            }
                        }

                        Text {
                            width: parent.width
                            text: recorderControl.statusText
                            color: recorderControl.recording ? theme.primaryContainerText : theme.mutedText
                            opacity: 0.8
                            elide: Text.ElideRight
                            font.family: theme.fontFamily
                            font.pixelSize: theme.fontSizeXs
                        }
                    }

                    MouseArea {
                        id: recorderMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: !recorderControl.changing
                        cursorShape: Qt.PointingHandCursor
                        onClicked: recorderControl.toggleRecording()
                    }
                }


                // ========================================================
                // SCREENSHOT
                // ========================================================

                Rectangle {
                    width: (parent.width - theme.spacingSm) / 2
                    height: 80
                    radius: theme.radiusMd
                    clip: true

                    color: screenshotMouse.containsMouse
                        ? theme.hoverStrong
                        : theme.cardBackgroundElevated

                    Behavior on color { ColorAnimation { duration: theme.animationFast } }

                    border.width: theme.borderThin
                    border.color: theme.border

                    scale: screenshotMouse.pressed ? root.theme.pressScale : 1.0
                    Behavior on scale { NumberAnimation { duration: theme.animationFast; easing.type: theme.easingStandard } }


                    Column {
                        anchors {
                            left: parent.left
                            right: parent.right
                            verticalCenter: parent.verticalCenter
                            leftMargin: theme.spacingMd
                            rightMargin: theme.spacingMd
                        }
                        spacing: 3

                        Row {
                            spacing: theme.spacingSm

                            Text {
                                text: "󰹑"
                                color: theme.mutedText
                                font.family: theme.iconFontFamily
                                font.pixelSize: theme.iconMd
                            }

                            Text {
                                text: "Screenshot"
                                color: theme.text
                                font.family: theme.fontFamily
                                font.pixelSize: theme.fontSizeSm
                                font.bold: true
                            }
                        }

                        Text {
                            text: "Capture"
                            color: theme.mutedText
                            opacity: 0.8
                            font.family: theme.fontFamily
                            font.pixelSize: theme.fontSizeXs
                        }
                    }

                    MouseArea {
                        id: screenshotMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.takeScreenshot()
                    }
                }


                // ========================================================
                // CLIPBOARD
                // ========================================================

                Rectangle {
                    width: (parent.width - theme.spacingSm) / 2
                    height: 80
                    radius: theme.radiusMd
                    clip: true

                    color: clipboardMouse.containsMouse
                        ? theme.hoverStrong
                        : theme.cardBackgroundElevated

                    Behavior on color { ColorAnimation { duration: theme.animationFast } }

                    border.width: theme.borderThin
                    border.color: theme.border

                    scale: clipboardMouse.pressed ? root.theme.pressScale : 1.0
                    Behavior on scale { NumberAnimation { duration: theme.animationFast; easing.type: theme.easingStandard } }


                    Column {
                        anchors {
                            left: parent.left
                            right: parent.right
                            verticalCenter: parent.verticalCenter
                            leftMargin: theme.spacingMd
                            rightMargin: theme.spacingMd
                        }
                        spacing: 3

                        Row {
                            spacing: theme.spacingSm

                            Text {
                                text: "󰅇"
                                color: theme.mutedText
                                font.family: theme.iconFontFamily
                                font.pixelSize: theme.iconMd
                            }

                            Text {
                                text: "Clipboard"
                                color: theme.text
                                font.family: theme.fontFamily
                                font.pixelSize: theme.fontSizeSm
                                font.bold: true
                            }
                        }

                        Text {
                            text: "Open"
                            color: theme.mutedText
                            opacity: 0.8
                            font.family: theme.fontFamily
                            font.pixelSize: theme.fontSizeXs
                        }
                    }

                    MouseArea {
                        id: clipboardMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.openClipboard()
                    }
                }
            }




            // ====================================================
            // BRIGHTNESS CARD
            // ====================================================

            Rectangle {
                width:
                    parent.width
                    - root.theme.spacingLg * 2

                implicitHeight:
                    brightnessCardColumn.implicitHeight
                    + root.theme.spacingLg * 2

                anchors.horizontalCenter:
                    parent.horizontalCenter

                radius:
                    root.theme.radiusLg

                color:
                    root.theme.cardBackground

                border.width:
                    root.theme.borderThin

                border.color:
                    root.theme.border


                Column {
                    id: brightnessCardColumn

                    anchors {
                        fill: parent

                        margins:
                            root.theme.spacingLg
                    }

                    spacing:
                        root.theme.spacingMd


                    Row {
                        width:
                            parent.width

                        height:
                            root.theme.controlHeightMd

                        spacing:
                            root.theme.spacingMd


                        Rectangle {
                            width:
                                root.theme.controlHeightMd

                            height:
                                width

                            radius:
                                root.theme.radiusMd

                            color:
                                root.theme.tertiaryContainer


                            Text {
                                anchors.centerIn:
                                    parent

                                text:
                                    "󰃠"

                                color:
                                    root.theme.tertiaryContainerText

                                font.family:
                                    root.theme.iconFontFamily

                                font.pixelSize:
                                    root.theme.iconMd
                            }
                        }


                        Column {
                            width:
                                parent.width
                                - root.theme.controlHeightMd
                                - brightnessPercent.width
                                - root.theme.spacingMd * 2

                            anchors.verticalCenter:
                                parent.verticalCenter

                            spacing:
                                root.theme.spacing2Xs


                            Text {
                                text:
                                    "Brightness"

                                color:
                                    root.theme.text

                                font.family:
                                    root.theme.fontFamily

                                font.pixelSize:
                                    root.theme.fontSizeMd

                                font.weight:
                                    root.theme.fontWeightMedium
                            }


                            Text {
                                text:
                                    "Display backlight"

                                color:
                                    root.theme.mutedText

                                font.family:
                                    root.theme.fontFamily

                                font.pixelSize:
                                    root.theme.fontSizeXs
                            }
                        }


                        Text {
                            id: brightnessPercent

                            anchors.verticalCenter:
                                parent.verticalCenter

                            text:
                                brightness.brightness
                                + "%"

                            color:
                                root.theme.text

                            font.family:
                                root.theme.monoFontFamily

                            font.pixelSize:
                                root.theme.fontSizeSm
                        }
                    }


                    RowLayout {
                        width: parent.width
                        spacing: 8

                        Rectangle {
                            implicitWidth: 34
                            implicitHeight: 34
                            radius: 10
                            color: nightLight.enabled ? root.theme.primary : root.theme.cardBackgroundElevated
                            border.width: root.theme.borderThin
                            border.color: nightLight.enabled ? root.theme.primary : root.theme.border

                            Text {
                                anchors.centerIn: parent
                                text: "󰃛"
                                font.family: root.theme.iconFontFamily
                                font.pixelSize: 15
                                color: nightLight.enabled ? root.theme.primaryContainerText : root.theme.text
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: nightLight.toggle()
                            }
                        }

                        NexaUI.NexaSlider {
                            Layout.fillWidth: true
                            sliderHeight: 34
                            sliderRadius: 10
                            from: 1
                            to: 100
                            value: brightness.brightness
                            icon: "󰃠"
                            onMoved: (val) => brightness.setBrightness(val)
                            onReleased: (val) => brightness.setBrightnessImmediate(val)
                        }
                    }
                }
            }


            // ============================================================
            // SCREEN TEMPERATURE CARD
            // ============================================================

            Rectangle {
                width:
                    parent.width
                    - root.theme.spacingLg * 2

                anchors.horizontalCenter:
                    parent.horizontalCenter

                implicitHeight:
                    screenTempContent.implicitHeight
                    + (theme.spacingMd * 2)

                radius:
                    theme.radiusMd

                color:
                    theme.cardBackground

                border.width:
                    root.theme.borderThin

                border.color:
                    root.theme.border


                Column {
                    id: screenTempContent

                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top

                        margins:
                            theme.spacingMd
                    }

                    spacing:
                        theme.spacingMd


                    // ====================================================
                    // HEADER
                    // ====================================================

                    Row {
                        width: parent.width

                        spacing:
                            theme.spacingMd


                        Text {
                            anchors.verticalCenter:
                                parent.verticalCenter

                            text:
                                nightLight.enabled
                                ? "󰖨"
                                : "󰖔"

                            color:
                                nightLight.enabled
                                ? theme.primary
                                : theme.mutedText

                            font {
                                family:
                                    theme.iconFontFamily

                                pixelSize:
                                    theme.iconLg
                            }
                        }


                        Column {
                            width:
                                parent.width
                                - temperatureToggle.width
                                - theme.iconLg
                                - (theme.spacingMd * 2)

                            spacing:
                                theme.spacing2Xs


                            Text {
                                width:
                                    parent.width

                                text:
                                    "Screen Temperature"

                                color:
                                    theme.text

                                elide:
                                    Text.ElideRight

                                font {
                                    family:
                                        theme.fontFamily

                                    pixelSize:
                                        theme.fontSizeSm

                                    bold:
                                        true
                                }
                            }


                            Text {
                                width:
                                    parent.width

                                text: {
                                    if (!nightLight.enabled)
                                        return "Disabled"

                                    if (nightLight.mode === "wallpaper")
                                        return "Wallpaper"

                                    if (nightLight.mode === "night")
                                        return "Night"

                                    return "Manual"
                                }

                                color:
                                    theme.mutedText

                                elide:
                                    Text.ElideRight

                                font {
                                    family:
                                        theme.fontFamily

                                    pixelSize:
                                        theme.fontSizeXs
                                }
                            }
                        }


                        // ================================================
                        // ENABLE / DISABLE
                        // ================================================

                        Rectangle {
                            id: temperatureToggle

                            width: 44
                            height: 24

                            anchors.verticalCenter:
                                parent.verticalCenter

                            radius:
                                theme.radiusPill

                            color:
                                nightLight.enabled
                                ? theme.primary
                                : theme.surfaceContainerHighest

                            Behavior on color {
                                ColorAnimation {
                                    duration:
                                        theme.animationFast
                                }
                            }


                            Rectangle {
                                width: 18
                                height: 18

                                anchors.verticalCenter:
                                    parent.verticalCenter

                                x:
                                    nightLight.enabled
                                    ? parent.width - width - 3
                                    : 3

                                radius:
                                    theme.radiusPill

                                color:
                                    nightLight.enabled
                                    ? theme.primaryText
                                    : theme.mutedText


                                Behavior on x {
                                    NumberAnimation {
                                        duration:
                                            theme.animationFast

                                        easing.type:
                                            theme.easingStandard
                                    }
                                }
                            }


                            MouseArea {
                                anchors.fill:
                                    parent

                                enabled:
                                    !nightLight.changing

                                cursorShape:
                                    Qt.PointingHandCursor

                                onClicked:
                                    nightLight.toggle()
                            }
                        }
                    }


                    // ====================================================
                    // TEMPERATURE VALUE
                    // ====================================================

                    Row {
                        width: parent.width


                        Text {
                            text:
                                nightLight.mode === "wallpaper"
                                ? "Wallpaper Temperature"
                                : nightLight.mode === "night"
                                    ? "Night Temperature"
                                    : "Temperature"

                            color:
                                theme.mutedText

                            font {
                                family:
                                    theme.fontFamily

                                pixelSize:
                                    theme.fontSizeXs
                            }
                        }


                        Item {
                            width:
                                parent.width
                                - parent.children[0].implicitWidth
                                - temperatureValue.implicitWidth

                            height: 1
                        }


                        Text {
                            id: temperatureValue

                            text:
                                nightLight.activeTemperature
                                + "K"

                            color:
                                nightLight.enabled
                                ? theme.text
                                : theme.mutedText

                            font {
                                family:
                                    theme.fontFamily

                                pixelSize:
                                    theme.fontSizeSm

                                bold:
                                    true
                            }
                        }
                    }


                    // ====================================================
                    // TEMPERATURE SLIDER
                    // ====================================================

                    NexaUI.NexaSlider {
                        id: temperatureSlider
                        width: parent.width
                        sliderHeight: 34
                        sliderRadius: 10
                        icon: "󰖔"

                        from:
                            nightLight.minimumTemperature

                        to:
                            nightLight.maximumTemperature

                        stepSize:
                            50

                        enabled:
                            nightLight.enabled
                            && !nightLight.wallpaperMode

                        opacity:
                            enabled
                            ? 1.0
                            : 0.5


                        /*
                        * Mode owns which stored temperature
                        * is displayed.
                        */
                        value:
                            nightLight.activeTemperature


                        /*
                        * During drag we update through the
                        * throttled backend path.
                        */
                        onMoved: (val) => nightLight.setTemperature(val)
                    }


                    // ====================================================
                    // RANGE LABELS
                    // ====================================================

                    Row {
                        width: parent.width


                        Text {
                            text:
                                nightLight.minimumTemperature
                                + "K"

                            color:
                                theme.mutedText

                            font {
                                family:
                                    theme.fontFamily

                                pixelSize:
                                    theme.fontSize2Xs
                            }
                        }


                        Item {
                            width:
                                parent.width
                                - parent.children[0].implicitWidth
                                - parent.children[2].implicitWidth

                            height: 1
                        }


                        Text {
                            text:
                                nightLight.maximumTemperature
                                + "K"

                            color:
                                theme.mutedText

                            font {
                                family:
                                    theme.fontFamily

                                pixelSize:
                                    theme.fontSize2Xs
                            }
                        }
                    }


                    // ====================================================
                    // MODE BUTTONS
                    // ====================================================

                    Row {
                        width: parent.width

                        spacing:
                            theme.spacingSm


                        // ================================================
                        // MANUAL
                        // ================================================

                        Rectangle {
                            width:
                                (parent.width - (theme.spacingSm * 2)) / 3

                            height:
                                theme.controlHeightMd

                            radius:
                                theme.radiusSm

                            color:
                                nightLight.mode === "manual"
                                ? theme.primaryContainer
                                : theme.cardBackgroundElevated

                            border.width:
                                theme.borderThin

                            border.color:
                                nightLight.mode === "manual"
                                ? theme.primary
                                : theme.border


                            Text {
                                anchors.centerIn:
                                    parent

                                text:
                                    "Manual"

                                color:
                                    nightLight.mode === "manual"
                                    ? theme.primaryContainerText
                                    : theme.text

                                font {
                                    family:
                                        theme.fontFamily

                                    pixelSize:
                                        theme.fontSizeXs

                                    bold:
                                        nightLight.mode === "manual"
                                }
                            }


                            MouseArea {
                                anchors.fill:
                                    parent

                                enabled:
                                    !nightLight.changing

                                cursorShape:
                                    Qt.PointingHandCursor

                                onClicked:
                                    nightLight.setMode(
                                        "manual"
                                    )
                            }
                        }


                        // ================================================
                        // WALLPAPER
                        // ================================================

                        Rectangle {
                            width:
                                (parent.width - (theme.spacingSm * 2)) / 3

                            height:
                                theme.controlHeightMd

                            radius:
                                theme.radiusSm

                            color:
                                nightLight.mode === "wallpaper"
                                ? theme.primaryContainer
                                : theme.cardBackgroundElevated

                            border.width:
                                theme.borderThin

                            border.color:
                                nightLight.mode === "wallpaper"
                                ? theme.primary
                                : theme.border


                            Text {
                                anchors.centerIn:
                                    parent

                                text:
                                    "Wallpaper"

                                color:
                                    nightLight.mode === "wallpaper"
                                    ? theme.primaryContainerText
                                    : theme.text

                                font {
                                    family:
                                        theme.fontFamily

                                    pixelSize:
                                        theme.fontSizeXs

                                    bold:
                                        nightLight.mode === "wallpaper"
                                }
                            }


                            MouseArea {
                                anchors.fill:
                                    parent

                                enabled:
                                    !nightLight.changing

                                cursorShape:
                                    Qt.PointingHandCursor

                                onClicked:
                                    nightLight.setMode(
                                        "wallpaper"
                                    )
                            }
                        }


                        // ================================================
                        // NIGHT
                        // ================================================

                        Rectangle {
                            width:
                                (parent.width - (theme.spacingSm * 2)) / 3

                            height:
                                theme.controlHeightMd

                            radius:
                                theme.radiusSm

                            color:
                                nightLight.mode === "night"
                                ? theme.primaryContainer
                                : theme.cardBackgroundElevated

                            border.width:
                                theme.borderThin

                            border.color:
                                nightLight.mode === "night"
                                ? theme.primary
                                : theme.border


                            Text {
                                anchors.centerIn:
                                    parent

                                text:
                                    "Night"

                                color:
                                    nightLight.mode === "night"
                                    ? theme.primaryContainerText
                                    : theme.text

                                font {
                                    family:
                                        theme.fontFamily

                                    pixelSize:
                                        theme.fontSizeXs

                                    bold:
                                        nightLight.mode === "night"
                                }
                            }


                            MouseArea {
                                anchors.fill:
                                    parent

                                enabled:
                                    !nightLight.changing

                                cursorShape:
                                    Qt.PointingHandCursor

                                onClicked:
                                    nightLight.setMode(
                                        "night"
                                    )
                            }
                        }
                    }
                }
            }



            // ============================================================
            // SCREEN FILTER
            // ============================================================

            Rectangle {
                width:
                    parent.width
                    - root.theme.spacingLg * 2

                anchors.horizontalCenter:
                    parent.horizontalCenter

                implicitHeight:
                    screenFilterColumn.implicitHeight
                    + (theme.spacingMd * 2)

                radius:
                    theme.radiusMd

                color:
                    theme.cardBackground

                border.width:
                    root.theme.borderThin

                border.color:
                    root.theme.border


                Column {
                    id: screenFilterColumn

                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                        margins: theme.spacingMd
                    }

                    spacing:
                        theme.spacingSm


                    // ====================================================
                    // HEADER / SELECTOR
                    // ====================================================

                    Rectangle {
                        width: parent.width
                        height: theme.controlHeightLg

                        radius:
                            theme.radiusSm

                        color:
                            screenFilterDropdownOpen
                            ? theme.surfaceContainerHigh
                            : theme.cardBackgroundElevated

                        border.width:
                            theme.borderThin

                        border.color:
                            screenFilterDropdownOpen
                            ? theme.focusBorder
                            : theme.border


                        Row {
                            anchors {
                                fill: parent
                                leftMargin: theme.spacingMd
                                rightMargin: theme.spacingMd
                            }

                            spacing:
                                theme.spacingMd


                            Text {
                                anchors.verticalCenter:
                                    parent.verticalCenter

                                text:
                                    "󰹑"

                                color:
                                    screenFilter.enabled
                                    ? theme.primary
                                    : theme.mutedText

                                font {
                                    family:
                                        theme.iconFontFamily

                                    pixelSize:
                                        theme.iconLg
                                }
                            }


                            Column {
                                anchors.verticalCenter:
                                    parent.verticalCenter

                                width:
                                    parent.width
                                    - theme.iconLg
                                    - filterArrow.width
                                    - (theme.spacingMd * 2)


                                Text {
                                    text:
                                        "Screen Filter"

                                    color:
                                        theme.text

                                    font {
                                        family:
                                            theme.fontFamily

                                        pixelSize:
                                            theme.fontSizeSm

                                        bold:
                                            true
                                    }
                                }


                                Text {
                                    text:
                                        screenFilter.label

                                    color:
                                        theme.mutedText

                                    font {
                                        family:
                                            theme.fontFamily

                                        pixelSize:
                                            theme.fontSizeXs
                                    }
                                }
                            }


                            Text {
                                id: filterArrow

                                anchors.verticalCenter:
                                    parent.verticalCenter

                                text:
                                    screenFilterDropdownOpen
                                    ? "󰅀"
                                    : "󰅂"

                                color:
                                    theme.mutedText

                                font {
                                    family:
                                        theme.iconFontFamily

                                    pixelSize:
                                        theme.iconMd
                                }
                            }
                        }


                        MouseArea {
                            anchors.fill:
                                parent

                            enabled:
                                !screenFilter.changing

                            hoverEnabled:
                                true

                            cursorShape:
                                Qt.PointingHandCursor

                            onClicked:
                                screenFilterDropdownOpen =
                                    !screenFilterDropdownOpen
                        }
                    }


                    // ====================================================
                    // DROPDOWN DRAWER
                    // ====================================================

                    Item {
                        width: parent.width
                        implicitHeight: screenFilterDropdownOpen ? filterListColumn.implicitHeight : 0
                        clip: true

                        Behavior on implicitHeight {
                            NumberAnimation {
                                duration: theme.animationNormal
                                easing.type: theme.easingStandard
                            }
                        }

                        Column {
                            id: filterListColumn
                            width: parent.width

                            spacing:
                                theme.spacingXs


                            Repeater {
                                model: [
                                    {
                                        value: "off",
                                        label: "Off"
                                    },
                                    {
                                        value: "chroma",
                                        label: "Chroma"
                                    },
                                    {
                                        value: "grayscale",
                                        label: "Grayscale"
                                    },
                                    {
                                        value: "hdr-boost",
                                        label: "HDR Boost"
                                    },
                                    {
                                        value: "high-contrast",
                                        label: "High Contrast"
                                    },
                                    {
                                        value: "invert",
                                        label: "Invert Colors"
                                    },
                                    {
                                        value: "sepia",
                                        label: "Sepia"
                                    }
                                ]


                                delegate: Rectangle {
                                    required property var modelData

                                    width:
                                        parent.width

                                    height:
                                        theme.controlHeightSm + 6

                                    radius:
                                        theme.radiusSm

                                    color:
                                        screenFilter.filter === modelData.value
                                        ? theme.primaryContainer
                                        : filterMouse.containsMouse
                                            ? theme.hover
                                            : theme.cardBackgroundElevated

                                    border.width:
                                        theme.borderThin

                                    border.color:
                                        screenFilter.filter === modelData.value
                                        ? theme.primary
                                        : theme.border


                                    Row {
                                        anchors {
                                            fill: parent
                                            leftMargin: theme.spacingMd
                                            rightMargin: theme.spacingMd
                                        }


                                        Text {
                                            anchors.verticalCenter:
                                                parent.verticalCenter

                                            text:
                                                modelData.label

                                            color:
                                                screenFilter.filter === modelData.value
                                                ? theme.primaryContainerText
                                                : theme.text

                                            font {
                                                family:
                                                    theme.fontFamily

                                                pixelSize:
                                                    theme.fontSizeXs

                                                bold:
                                                    screenFilter.filter === modelData.value
                                            }
                                        }


                                        Item {
                                            width:
                                                parent.width
                                                - parent.children[0].implicitWidth
                                                - selectedMark.implicitWidth

                                            height: 1
                                        }


                                        Text {
                                            id: selectedMark

                                            anchors.verticalCenter:
                                                parent.verticalCenter

                                            visible:
                                                screenFilter.filter === modelData.value

                                            text:
                                                "󰄬"

                                            color:
                                                theme.primaryContainerText

                                            font {
                                                family:
                                                    theme.iconFontFamily

                                                pixelSize:
                                                    theme.iconMd
                                            }
                                        }
                                    }


                                    MouseArea {
                                        id: filterMouse

                                        anchors.fill:
                                            parent

                                        hoverEnabled:
                                            true

                                        cursorShape:
                                            Qt.PointingHandCursor

                                        enabled:
                                            !screenFilter.changing

                                        onClicked: {
                                            screenFilter.setFilter(
                                                modelData.value
                                            )

                                            screenFilterDropdownOpen =
                                                false
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }



            Item {
                width: 1

                height:
                    root.theme.spacing2Xl
            }
            }
        }
    }
}


