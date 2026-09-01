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

    readonly property var theme: ThemeModule.Theme

    property bool appsExpanded: false
    property bool screenFilterDropdownOpen: false
    property bool sinkMenuOpen: false

    function takeScreenshot() {
        if (screenshotProcess.running) return
        screenshotProcess.exec([
            Quickshell.env("HOME") + "/.config/nexa/rust/target/release/nexad",
            "screenshot",
            "capture"
        ])
    }

    function openClipboard() {
        if (clipboardOpenProcess.running) return
        clipboardOpenProcess.exec([
            "qs", "-p", Quickshell.env("HOME") + "/.config/nexa/quickshell",
            "ipc", "call", "clipboard", "open"
        ])
    }

    function getFilterLabel(f) {
        switch (f) {
        case "chroma": return "Chroma"
        case "grayscale": return "Grayscale"
        case "hdr-boost": return "HDR Boost"
        case "high-contrast": return "High Contrast"
        case "invert": return "Invert Colors"
        case "sepia": return "Sepia"
        default: return "Off"
        }
    }

    AudioModule.Audio { id: audio; visible: root.visible }
    BrightnessModule.Brightness { id: brightness; visible: root.visible }
    NetworkModule.Wifi { id: wifi; visible: root.visible }
    NetworkModule.Bluetooth { id: bluetooth; visible: root.visible }
    AirplaneModule.Airplane { id: airplane; visible: root.visible }
    VpnModule.Vpn { id: vpn; visible: root.visible }
    NightLightModule.NightLight { id: nightLight; visible: root.visible }
    ScreenFilterModule.ScreenFilter { id: screenFilter; visible: root.visible }
    NotificationModule.Dnd { id: dnd; visible: root.visible }
    RecorderModule.RecorderControl { id: recorderControl; visible: root.visible }

    Process {
        id: screenshotProcess
        stdout: StdioCollector {}
        stderr: StdioCollector {}
    }

    Process {
        id: clipboardOpenProcess
        stdout: StdioCollector {}
        stderr: StdioCollector {}
    }

    Flickable {
        id: qsFlickable
        anchors.fill: parent
        anchors.margins: 12
        clip: true
        contentWidth: width
        contentHeight: Math.max(height, columnsRow.implicitHeight + 12)
        boundsBehavior: Flickable.StopAtBounds

        Row {
            id: columnsRow
            width: parent.width
            spacing: root.theme.spacingLg

            // ========================================================
            // LEFT COLUMN (Audio, Display, Night Light, Screen Filter)
            // ========================================================
            Column {
                width: (parent.width - root.theme.spacingLg) / 2
                spacing: 10

                // ----------------------------------------------------
                // 1. AUDIO CARD (Output, Apps, Mic)
                // ----------------------------------------------------
                Rectangle {
                    width: parent.width
                    implicitHeight: audioCardContent.implicitHeight + 16
                    radius: root.theme.radiusMd
                    color: root.theme.cardBackground
                    border.width: root.theme.borderThin
                    border.color: root.theme.border

                    Column {
                        id: audioCardContent
                        anchors {
                            left: parent.left
                            right: parent.right
                            top: parent.top
                            margins: 8
                        }
                        spacing: 7

                        // Header row: Icon, "Output", spacer, Apps toggle, Volume %
                        RowLayout {
                            width: parent.width
                            spacing: root.theme.spacingSm

                            Text {
                                text: audio.muted ? "󰝟" : (audio.volume > 50 ? "󰕾" : (audio.volume > 0 ? "󰖀" : "󰕿"))
                                font.family: root.theme.iconFontFamily
                                font.pixelSize: root.theme.iconSm
                                color: audio.muted ? root.theme.error : root.theme.primary
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: audio.toggleMute()
                                }
                            }

                            Text {
                                text: "Output"
                                font.family: root.theme.fontFamily
                                font.pixelSize: root.theme.fontSizeXs
                                font.weight: root.theme.fontWeightDemiBold
                                color: root.theme.text
                            }

                            // Audio Output Device Chip
                            Rectangle {
                                id: sinkChip
                                implicitHeight: 22
                                implicitWidth: Math.min(120, sinkChipRow.implicitWidth + 16)
                                radius: 11
                                color: root.sinkMenuOpen
                                    ? root.theme.primaryContainer
                                    : (sinkChipMouse.containsMouse ? root.theme.hoverStrong : root.theme.cardBackgroundElevated)
                                border.width: root.theme.borderThin
                                border.color: root.sinkMenuOpen ? root.theme.primary : root.theme.border

                                Row {
                                    id: sinkChipRow
                                    anchors.centerIn: parent
                                    spacing: 4

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: {
                                            for (let i = 0; i < audio.sinks.length; ++i)
                                                if (audio.sinks[i].active) return audio.sinks[i].icon
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
                                                    return d.length > 14 ? d.substring(0, 12) + "…" : d
                                                }
                                            }
                                            return "Output"
                                        }
                                        font.family: root.theme.fontFamily
                                        font.pixelSize: root.theme.fontSize2Xs
                                        font.weight: root.theme.fontWeightMedium
                                        color: root.sinkMenuOpen ? root.theme.primaryContainerText : root.theme.text
                                    }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: root.sinkMenuOpen ? "▴" : "▾"
                                        font.pixelSize: root.theme.fontSize2Xs
                                        color: root.sinkMenuOpen ? root.theme.primaryContainerText : root.theme.mutedText
                                    }
                                }

                                MouseArea {
                                    id: sinkChipMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.sinkMenuOpen = !root.sinkMenuOpen
                                        if (root.sinkMenuOpen) audio.refreshSinks()
                                    }
                                }
                            }

                            Item { Layout.fillWidth: true }

                            // Apps mixer toggle button
                            Rectangle {
                                implicitWidth: 20
                                implicitHeight: 20
                                radius: 10
                                color: root.appsExpanded ? root.theme.primaryContainer : (appsMouse.containsMouse ? root.theme.hover : "transparent")

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰅀"
                                    rotation: root.appsExpanded ? 180 : 0
                                    font.family: root.theme.iconFontFamily
                                    font.pixelSize: root.theme.iconSm
                                    color: root.appsExpanded ? root.theme.primaryContainerText : root.theme.mutedText
                                    Behavior on rotation { NumberAnimation { duration: root.theme.animationFast } }
                                }

                                MouseArea {
                                    id: appsMouse
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.appsExpanded = !root.appsExpanded
                                        if (root.appsExpanded) audio.refreshApps()
                                    }
                                }
                            }

                            Text {
                                text: audio.volume + "%"
                                font.family: root.theme.monoFontFamily
                                font.pixelSize: root.theme.fontSizeXs
                                color: root.theme.text
                            }
                        }

                        // Expandable Audio Sinks List
                        Column {
                            width: parent.width
                            visible: root.sinkMenuOpen && audio.sinks.length > 0
                            spacing: root.theme.spacingXs

                            Repeater {
                                model: audio.sinks
                                delegate: Rectangle {
                                    width: parent.width
                                    height: 32
                                    radius: root.theme.radiusMd
                                    color: modelData.active
                                        ? root.theme.primaryContainer
                                        : (sinkItemMouse.containsMouse ? root.theme.hover : root.theme.cardBackgroundElevated)
                                    border.width: root.theme.borderThin
                                    border.color: modelData.active ? root.theme.primary : root.theme.border

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: root.theme.spacingSm
                                        anchors.rightMargin: root.theme.spacingSm
                                        spacing: root.theme.spacingSm

                                        Text {
                                            text: modelData.icon || "󰕾"
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
                                            font.weight: modelData.active ? root.theme.fontWeightDemiBold : root.theme.fontWeightNormal
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

                        // Dedicated Master Volume Slider Bar (Zero Overlap)
                        NexaUI.NexaSlider {
                            width: parent.width
                            sliderHeight: 18
                            sliderRadius: 6
                            from: 0
                            to: 100
                            value: audio.volume
                            icon: ""
                            onMoved: (val) => audio.setVolume(val)
                            onReleased: (val) => audio.setVolumeImmediate(val)
                        }

                        // Expandable Per-App Volume Mixers (animated container)
                        Rectangle {
                            width: parent.width
                            height: root.appsExpanded
                                ? Math.min(180, Math.max(48, appListView.contentHeight + 16))
                                : 0
                            visible: height > 0
                            opacity: root.appsExpanded ? 1.0 : 0.0
                            radius: root.theme.radiusMd
                            color: root.theme.cardBackgroundElevated
                            border.width: root.theme.borderThin
                            border.color: root.theme.border
                            clip: true

                            Behavior on height { NumberAnimation { duration: root.theme.animationNormal; easing.type: root.theme.easingStandard } }
                            Behavior on opacity { NumberAnimation { duration: root.theme.animationFast } }

                            Text {
                                anchors.centerIn: parent
                                visible: !audio.appsLoading && audio.apps.length === 0
                                text: "No active audio applications"
                                color: root.theme.mutedText
                                font.family: root.theme.fontFamily
                                font.pixelSize: root.theme.fontSizeXs
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: audio.appsLoading
                                text: "Loading…"
                                color: root.theme.mutedText
                                font.family: root.theme.fontFamily
                                font.pixelSize: root.theme.fontSizeXs
                            }

                            ListView {
                                id: appListView
                                anchors { fill: parent; margins: 8 }
                                visible: !audio.appsLoading && audio.apps.length > 0
                                clip: true
                                spacing: root.theme.spacingSm
                                model: audio.apps

                                delegate: Column {
                                    required property var modelData
                                    width: ListView.view.width
                                    spacing: root.theme.spacing2Xs

                                    RowLayout {
                                        width: parent.width
                                        spacing: root.theme.spacingSm

                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.name
                                            elide: Text.ElideRight
                                            color: root.theme.text
                                            font.family: root.theme.fontFamily
                                            font.pixelSize: root.theme.fontSizeXs
                                        }

                                        Text {
                                            text: modelData.volume + "%"
                                            color: root.theme.mutedText
                                            font.family: root.theme.monoFontFamily
                                            font.pixelSize: root.theme.fontSizeXs
                                        }

                                        Rectangle {
                                            width: 24
                                            height: 24
                                            radius: root.theme.radiusSm
                                            color: appMuteMouse.containsMouse ? root.theme.hoverStrong : "transparent"

                                            Text {
                                                anchors.centerIn: parent
                                                text: modelData.muted ? "󰝟" : "󰕾"
                                                color: modelData.muted ? root.theme.mutedText : root.theme.text
                                                font.family: root.theme.iconFontFamily
                                                font.pixelSize: root.theme.iconSm
                                            }

                                            MouseArea {
                                                id: appMuteMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: audio.toggleAppMute(modelData.id)
                                            }
                                        }
                                    }

                                    NexaUI.NexaSlider {
                                        width: parent.width
                                        sliderHeight: 18
                                        sliderRadius: 6
                                        from: 0
                                        to: 100
                                        value: modelData.volume
                                        icon: ""
                                        onMoved: (val) => audio.setAppVolume(modelData.id, val)
                                        onReleased: (val) => audio.setAppVolumeImmediate(modelData.id, val)
                                    }
                                }
                            }
                        }

                        // Divider between Output and Microphone
                        Rectangle {
                            width: parent.width
                            height: root.theme.borderThin
                            color: root.theme.divider
                        }

                        // Microphone Header: Title, Mute, Volume %
                        RowLayout {
                            width: parent.width
                            spacing: root.theme.spacingSm

                            Text {
                                text: audio.inputMuted ? "󰍭" : "󰍬"
                                font.family: root.theme.iconFontFamily
                                font.pixelSize: root.theme.iconSm
                                color: audio.inputMuted ? root.theme.error : root.theme.primary

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: audio.toggleInputMute()
                                }
                            }

                            Text {
                                text: "Microphone"
                                font.family: root.theme.fontFamily
                                font.pixelSize: root.theme.fontSizeXs
                                font.weight: root.theme.fontWeightDemiBold
                                color: root.theme.text

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: audio.toggleInputMute()
                                }
                            }

                            Text {
                                text: audio.inputMuted ? "Muted" : "Active"
                                font.family: root.theme.fontFamily
                                font.pixelSize: root.theme.fontSize2Xs
                                color: root.theme.mutedText
                                opacity: 0.8
                            }

                            Item { Layout.fillWidth: true }

                            // Dedicated mute toggle button
                            Rectangle {
                                implicitWidth: 20
                                implicitHeight: 20
                                radius: 10
                                color: audio.inputMuted
                                    ? root.theme.errorContainer
                                    : (micMuteHover.containsMouse ? root.theme.hoverStrong : root.theme.primaryContainer)

                                Text {
                                    anchors.centerIn: parent
                                    text: audio.inputMuted ? "󰍭" : "󰍬"
                                    font.family: root.theme.iconFontFamily
                                    font.pixelSize: 11
                                    color: audio.inputMuted ? root.theme.error : root.theme.primaryContainerText
                                }

                                MouseArea {
                                    id: micMuteHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: audio.toggleInputMute()
                                }
                            }

                            Text {
                                text: audio.inputVolume + "%"
                                font.family: root.theme.monoFontFamily
                                font.pixelSize: root.theme.fontSizeXs
                                color: root.theme.text
                            }
                        }

                        // Dedicated Microphone Slider Bar with Live Reactive Pulse
                        NexaUI.NexaSlider {
                            width: parent.width
                            sliderHeight: 18
                            sliderRadius: 6
                            from: 0
                            to: 100
                            value: audio.inputVolume
                            icon: ""
                            livePulse: !audio.inputMuted ? audio.micPeak : 0.0
                            onMoved: (val) => audio.setInputVolume(val)
                            onReleased: (val) => audio.setInputVolumeImmediate(val)
                        }
                    }
                }

                // ----------------------------------------------------
                // 2. DISPLAY & NIGHT LIGHT CARD
                // ----------------------------------------------------
                Rectangle {
                    width: parent.width
                    implicitHeight: displayCardContent.implicitHeight + 16
                    radius: root.theme.radiusMd
                    color: root.theme.cardBackground
                    border.width: root.theme.borderThin
                    border.color: root.theme.border

                    Column {
                        id: displayCardContent
                        anchors {
                            left: parent.left
                            right: parent.right
                            top: parent.top
                            margins: 8
                        }
                        spacing: 7

                        // Brightness Header: Title, Backlight, %
                        RowLayout {
                            width: parent.width
                            spacing: root.theme.spacingSm

                            Text {
                                text: "󰃠"
                                font.family: root.theme.iconFontFamily
                                font.pixelSize: root.theme.iconSm
                                color: root.theme.primary
                            }

                            Text {
                                text: "Brightness"
                                font.family: root.theme.fontFamily
                                font.pixelSize: root.theme.fontSizeXs
                                font.weight: root.theme.fontWeightDemiBold
                                color: root.theme.text
                            }

                            Text {
                                text: "Backlight"
                                font.family: root.theme.fontFamily
                                font.pixelSize: root.theme.fontSize2Xs
                                color: root.theme.mutedText
                                opacity: 0.8
                            }

                            Item { Layout.fillWidth: true }

                            Text {
                                text: brightness.brightness + "%"
                                font.family: root.theme.monoFontFamily
                                font.pixelSize: root.theme.fontSizeXs
                                color: root.theme.text
                            }
                        }

                        // Dedicated Brightness Slider Bar (Zero Overlap)
                        NexaUI.NexaSlider {
                            width: parent.width
                            sliderHeight: 18
                            sliderRadius: 6
                            from: 1
                            to: 100
                            value: brightness.brightness
                            icon: ""
                            onMoved: (val) => brightness.setBrightness(val)
                            onReleased: (val) => brightness.setBrightnessImmediate(val)
                        }

                        // Divider
                        Rectangle {
                            width: parent.width
                            height: root.theme.borderThin
                            color: root.theme.divider
                        }

                        // Night Light Header: Title, Temperature, Toggle Switch
                        RowLayout {
                            width: parent.width
                            spacing: root.theme.spacingSm

                            Text {
                                text: "󰖔"
                                font.family: root.theme.iconFontFamily
                                font.pixelSize: root.theme.iconSm
                                color: nightLight.enabled ? root.theme.primary : root.theme.mutedText
                            }

                            Text {
                                text: "Night Light"
                                font.family: root.theme.fontFamily
                                font.pixelSize: root.theme.fontSizeXs
                                font.weight: root.theme.fontWeightDemiBold
                                color: root.theme.text
                            }

                            Text {
                                text: nightLight.enabled ? (nightLight.activeTemperature + "K") : "Off"
                                font.family: root.theme.fontFamily
                                font.pixelSize: root.theme.fontSize2Xs
                                color: root.theme.mutedText
                                opacity: 0.8
                            }

                            Item { Layout.fillWidth: true }

                            Rectangle {
                                implicitWidth: 32
                                implicitHeight: 18
                                radius: 9
                                color: nightLight.enabled ? root.theme.primary : root.theme.surfaceContainerHighest

                                Rectangle {
                                    width: 14
                                    height: 14
                                    radius: 7
                                    anchors.verticalCenter: parent.verticalCenter
                                    x: nightLight.enabled ? parent.width - width - 2 : 2
                                    color: "#ffffff"
                                    Behavior on x { NumberAnimation { duration: root.theme.animationFast } }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: nightLight.toggle()
                                }
                            }
                        }

                        // Dedicated Night Light Temperature Slider (Zero Overlap)
                        NexaUI.NexaSlider {
                            width: parent.width
                            sliderHeight: 18
                            sliderRadius: 6
                            from: nightLight.minimumTemperature
                            to: nightLight.maximumTemperature
                            stepSize: 50
                            value: nightLight.activeTemperature
                            enabled: nightLight.enabled && !nightLight.wallpaperMode
                            opacity: enabled ? 1.0 : 0.4
                            icon: ""
                            onMoved: (val) => {
                                if (nightLight.enabled) nightLight.setManualTemperature(val)
                            }
                        }

                        // 3-Mode Switcher: Manual | Wallpaper | Night
                        Row {
                            width: parent.width
                            spacing: 4

                            Repeater {
                                model: [
                                    { mode: "manual", label: "Manual" },
                                    { mode: "wallpaper", label: "Wallpaper" },
                                    { mode: "night", label: "Night" }
                                ]
                                delegate: Rectangle {
                                    width: (parent.width - 8) / 3
                                    height: 22
                                    radius: root.theme.radiusSm
                                    color: nightLight.mode === modelData.mode ? root.theme.primaryContainer : (mMouse.containsMouse ? root.theme.hover : root.theme.cardBackgroundElevated)
                                    border.width: root.theme.borderThin
                                    border.color: nightLight.mode === modelData.mode ? root.theme.primary : root.theme.border

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.label
                                        font.family: root.theme.fontFamily
                                        font.pixelSize: root.theme.fontSize2Xs
                                        font.weight: nightLight.mode === modelData.mode ? root.theme.fontWeightDemiBold : root.theme.fontWeightNormal
                                        color: nightLight.mode === modelData.mode ? root.theme.primaryContainerText : root.theme.text
                                    }

                                    MouseArea {
                                        id: mMouse
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: nightLight.setMode(modelData.mode)
                                    }
                                }
                            }
                        }
                    }
                }

                // ----------------------------------------------------
                // 3. SCREEN FILTER CARD (Left Column)
                // ----------------------------------------------------
                Rectangle {
                    width: parent.width
                    implicitHeight: filterCardContent.implicitHeight + 16
                    radius: root.theme.radiusMd
                    color: root.theme.cardBackground
                    border.width: root.theme.borderThin
                    border.color: root.theme.border

                    Column {
                        id: filterCardContent
                        anchors {
                            left: parent.left
                            right: parent.right
                            top: parent.top
                            margins: 8
                        }
                        spacing: 6

                        Item {
                            width: parent.width
                            height: 26

                            RowLayout {
                                anchors.fill: parent
                                spacing: root.theme.spacingSm

                                Text {
                                    text: "󰹑"
                                    font.family: root.theme.iconFontFamily
                                    font.pixelSize: root.theme.iconSm
                                    color: screenFilter.filter !== "off" ? root.theme.primary : root.theme.mutedText
                                }

                                Column {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    Text {
                                        text: "Screen Filter"
                                        font.family: root.theme.fontFamily
                                        font.pixelSize: root.theme.fontSizeXs
                                        font.weight: root.theme.fontWeightDemiBold
                                        color: root.theme.text
                                    }

                                    Text {
                                        text: screenFilter.label || "Off"
                                        font.family: root.theme.fontFamily
                                        font.pixelSize: root.theme.fontSize2Xs
                                        color: root.theme.mutedText
                                    }
                                }

                                Text {
                                    text: root.screenFilterDropdownOpen ? "󰅃" : "󰅂"
                                    font.family: root.theme.iconFontFamily
                                    font.pixelSize: root.theme.iconSm
                                    color: root.theme.mutedText
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.screenFilterDropdownOpen = !root.screenFilterDropdownOpen
                            }
                        }

                        // Dropdown Shader Selector (Live & Populated)
                        Column {
                            width: parent.width
                            visible: root.screenFilterDropdownOpen
                            spacing: 4

                            Repeater {
                                model: screenFilter.available
                                delegate: Rectangle {
                                    width: parent.width
                                    height: 26
                                    radius: root.theme.radiusSm
                                    color: modelData === screenFilter.filter ? root.theme.primaryContainer : (fItemMouse.containsMouse ? root.theme.hover : root.theme.cardBackgroundElevated)

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 5

                                        Text {
                                            Layout.fillWidth: true
                                            text: root.getFilterLabel(modelData)
                                            font.family: root.theme.fontFamily
                                            font.pixelSize: root.theme.fontSizeXs
                                            color: modelData === screenFilter.filter ? root.theme.primaryContainerText : root.theme.text
                                        }

                                        Text {
                                            visible: modelData === screenFilter.filter
                                            text: "󰄬"
                                            font.family: root.theme.iconFontFamily
                                            font.pixelSize: root.theme.iconSm
                                            color: root.theme.primaryContainerText
                                        }
                                    }

                                    MouseArea {
                                        id: fItemMouse
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            screenFilter.setFilter(modelData)
                                            root.screenFilterDropdownOpen = false
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ========================================================
            // RIGHT COLUMN (Tiles: Connectivity & Actions)
            // ========================================================
            Column {
                width: (parent.width - root.theme.spacingLg) / 2
                spacing: 8

                // --- CONNECTIVITY HEADER ---
                Text {
                    text: "Connectivity"
                    color: root.theme.text
                    font.family: root.theme.fontFamily
                    font.pixelSize: root.theme.fontSizeXs
                    font.weight: root.theme.fontWeightDemiBold
                    opacity: 0.9
                }

                // 2x2 CONNECTIVITY GRID (Unified Pixel-Perfect Alignment)
                Grid {
                    width: parent.width
                    columns: 2
                    columnSpacing: root.theme.spacingSm
                    rowSpacing: root.theme.spacingSm

                    // 1. Wi-Fi
                    Rectangle {
                        width: (parent.width - root.theme.spacingSm) / 2
                        height: 58
                        radius: root.theme.radiusMd
                        clip: true
                        color: wifi.enabled ? root.theme.primaryContainer : (wifiMouse.containsMouse ? root.theme.hoverStrong : root.theme.cardBackgroundElevated)
                        border.width: root.theme.borderThin
                        border.color: wifi.enabled ? root.theme.primary : root.theme.border

                        Column {
                            anchors {
                                left: parent.left
                                right: parent.right
                                verticalCenter: parent.verticalCenter
                                leftMargin: 12
                                rightMargin: 12
                            }
                            spacing: 2

                            Item {
                                width: 18
                                height: 18
                                Text {
                                    anchors.centerIn: parent
                                    text: !wifi.enabled ? "󰤭" : (!wifi.connected ? "󰤭" : (wifi.strength >= 75 ? "󰤨" : (wifi.strength >= 50 ? "󰤥" : "󰤢")))
                                    color: wifi.enabled ? root.theme.primaryContainerText : root.theme.mutedText
                                    font.family: root.theme.iconFontFamily
                                    font.pixelSize: root.theme.iconSm
                                }
                            }

                            Text {
                                width: parent.width
                                text: "Wi-Fi"
                                color: wifi.enabled ? root.theme.primaryContainerText : root.theme.text
                                elide: Text.ElideRight
                                font.family: root.theme.fontFamily
                                font.pixelSize: root.theme.fontSizeXs
                                font.weight: root.theme.fontWeightDemiBold
                            }

                            Text {
                                width: parent.width
                                text: !wifi.enabled ? "Off" : (wifi.connected ? wifi.ssid : "Disconnected")
                                color: wifi.enabled ? root.theme.primaryContainerText : root.theme.mutedText
                                opacity: 0.8
                                elide: Text.ElideRight
                                font.family: root.theme.fontFamily
                                font.pixelSize: root.theme.fontSize2Xs
                            }
                        }

                        MouseArea {
                            id: wifiMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: wifi.toggle()
                        }
                    }

                    // 2. Bluetooth
                    Rectangle {
                        width: (parent.width - root.theme.spacingSm) / 2
                        height: 58
                        radius: root.theme.radiusMd
                        clip: true
                        color: bluetooth.enabled ? root.theme.primaryContainer : (btMouse.containsMouse ? root.theme.hoverStrong : root.theme.cardBackgroundElevated)
                        border.width: root.theme.borderThin
                        border.color: bluetooth.enabled ? root.theme.primary : root.theme.border

                        Column {
                            anchors {
                                left: parent.left
                                right: parent.right
                                verticalCenter: parent.verticalCenter
                                leftMargin: 12
                                rightMargin: 12
                            }
                            spacing: 2

                            Item {
                                width: 18
                                height: 18
                                Text {
                                    anchors.centerIn: parent
                                    text: bluetooth.enabled ? (bluetooth.connected ? "󰂱" : "󰂯") : "󰂲"
                                    color: bluetooth.enabled ? root.theme.primaryContainerText : root.theme.mutedText
                                    font.family: root.theme.iconFontFamily
                                    font.pixelSize: root.theme.iconSm
                                }
                            }

                            Text {
                                width: parent.width
                                text: "Bluetooth"
                                color: bluetooth.enabled ? root.theme.primaryContainerText : root.theme.text
                                elide: Text.ElideRight
                                font.family: root.theme.fontFamily
                                font.pixelSize: root.theme.fontSizeXs
                                font.weight: root.theme.fontWeightDemiBold
                            }

                            Text {
                                width: parent.width
                                text: !bluetooth.enabled ? "Off" : (bluetooth.connected ? bluetooth.connectedDeviceName : "On")
                                color: bluetooth.enabled ? root.theme.primaryContainerText : root.theme.mutedText
                                opacity: 0.8
                                elide: Text.ElideRight
                                font.family: root.theme.fontFamily
                                font.pixelSize: root.theme.fontSize2Xs
                            }
                        }

                        MouseArea {
                            id: btMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: bluetooth.toggle()
                        }
                    }

                    // 3. Airplane
                    Rectangle {
                        width: (parent.width - root.theme.spacingSm) / 2
                        height: 58
                        radius: root.theme.radiusMd
                        clip: true
                        color: airplane.enabled ? root.theme.primaryContainer : (airMouse.containsMouse ? root.theme.hoverStrong : root.theme.cardBackgroundElevated)
                        border.width: root.theme.borderThin
                        border.color: airplane.enabled ? root.theme.primary : root.theme.border

                        Column {
                            anchors {
                                left: parent.left
                                right: parent.right
                                verticalCenter: parent.verticalCenter
                                leftMargin: 12
                                rightMargin: 12
                            }
                            spacing: 2

                            Item {
                                width: 18
                                height: 18
                                Text {
                                    anchors.centerIn: parent
                                    text: "󰀝"
                                    color: airplane.enabled ? root.theme.primaryContainerText : root.theme.mutedText
                                    font.family: root.theme.iconFontFamily
                                    font.pixelSize: root.theme.iconSm
                                }
                            }

                            Text {
                                width: parent.width
                                text: "Airplane"
                                color: airplane.enabled ? root.theme.primaryContainerText : root.theme.text
                                elide: Text.ElideRight
                                font.family: root.theme.fontFamily
                                font.pixelSize: root.theme.fontSizeXs
                                font.weight: root.theme.fontWeightDemiBold
                            }

                            Text {
                                width: parent.width
                                text: airplane.enabled ? "On" : "Off"
                                color: airplane.enabled ? root.theme.primaryContainerText : root.theme.mutedText
                                opacity: 0.8
                                elide: Text.ElideRight
                                font.family: root.theme.fontFamily
                                font.pixelSize: root.theme.fontSize2Xs
                            }
                        }

                        MouseArea {
                            id: airMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: airplane.toggle()
                        }
                    }

                    // 4. VPN
                    Rectangle {
                        width: (parent.width - root.theme.spacingSm) / 2
                        height: 58
                        radius: root.theme.radiusMd
                        clip: true
                        color: vpn.enabled ? root.theme.primaryContainer : (vpnMouse.containsMouse ? root.theme.hoverStrong : root.theme.cardBackgroundElevated)
                        border.width: root.theme.borderThin
                        border.color: vpn.enabled ? root.theme.primary : root.theme.border

                        Column {
                            anchors {
                                left: parent.left
                                right: parent.right
                                verticalCenter: parent.verticalCenter
                                leftMargin: 12
                                rightMargin: 12
                            }
                            spacing: 2

                            Item {
                                width: 18
                                height: 18
                                Text {
                                    anchors.centerIn: parent
                                    text: vpn.enabled ? "󰦝" : "󰦞"
                                    color: vpn.enabled ? root.theme.primaryContainerText : root.theme.mutedText
                                    font.family: root.theme.iconFontFamily
                                    font.pixelSize: root.theme.iconSm
                                }
                            }

                            Text {
                                width: parent.width
                                text: "VPN"
                                color: vpn.enabled ? root.theme.primaryContainerText : root.theme.text
                                elide: Text.ElideRight
                                font.family: root.theme.fontFamily
                                font.pixelSize: root.theme.fontSizeXs
                                font.weight: root.theme.fontWeightDemiBold
                            }

                            Text {
                                width: parent.width
                                text: !vpn.available ? "No profile" : (vpn.enabled ? vpn.activeProfile : "Disconnected")
                                color: vpn.enabled ? root.theme.primaryContainerText : root.theme.mutedText
                                opacity: 0.8
                                elide: Text.ElideRight
                                font.family: root.theme.fontFamily
                                font.pixelSize: root.theme.fontSize2Xs
                            }
                        }

                        MouseArea {
                            id: vpnMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: vpn.toggle()
                        }
                    }
                }

                Item {
                    width: parent.width
                    height: 6
                }

                // --- ACTIONS HEADER ---
                Text {
                    text: "Actions"
                    color: root.theme.text
                    font.family: root.theme.fontFamily
                    font.pixelSize: root.theme.fontSizeXs
                    font.weight: root.theme.fontWeightDemiBold
                    opacity: 0.9
                }

                // 2x2 ACTIONS GRID (Unified Pixel-Perfect Alignment)
                Grid {
                    width: parent.width
                    columns: 2
                    columnSpacing: root.theme.spacingSm
                    rowSpacing: root.theme.spacingSm

                    // 1. DND
                    Rectangle {
                        width: (parent.width - root.theme.spacingSm) / 2
                        height: 58
                        radius: root.theme.radiusMd
                        clip: true
                        color: dnd.enabled ? root.theme.primaryContainer : (dndMouse.containsMouse ? root.theme.hoverStrong : root.theme.cardBackgroundElevated)
                        border.width: root.theme.borderThin
                        border.color: dnd.enabled ? root.theme.primary : root.theme.border

                        Column {
                            anchors {
                                left: parent.left
                                right: parent.right
                                verticalCenter: parent.verticalCenter
                                leftMargin: 12
                                rightMargin: 12
                            }
                            spacing: 2

                            Item {
                                width: 18
                                height: 18
                                Text {
                                    anchors.centerIn: parent
                                    text: "󰂛"
                                    color: dnd.enabled ? root.theme.primaryContainerText : root.theme.mutedText
                                    font.family: root.theme.iconFontFamily
                                    font.pixelSize: root.theme.iconSm
                                }
                            }

                            Text {
                                width: parent.width
                                text: "DND"
                                color: dnd.enabled ? root.theme.primaryContainerText : root.theme.text
                                elide: Text.ElideRight
                                font.family: root.theme.fontFamily
                                font.pixelSize: root.theme.fontSizeXs
                                font.weight: root.theme.fontWeightDemiBold
                            }

                            Text {
                                width: parent.width
                                text: dnd.enabled ? "On" : "Off"
                                color: dnd.enabled ? root.theme.primaryContainerText : root.theme.mutedText
                                opacity: 0.8
                                font.family: root.theme.fontFamily
                                font.pixelSize: root.theme.fontSize2Xs
                            }
                        }

                        MouseArea {
                            id: dndMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: dnd.toggle()
                        }
                    }

                    // 2. Recorder
                    Rectangle {
                        width: (parent.width - root.theme.spacingSm) / 2
                        height: 58
                        radius: root.theme.radiusMd
                        clip: true
                        color: recorderControl.recording ? root.theme.primaryContainer : (recMouse.containsMouse ? root.theme.hoverStrong : root.theme.cardBackgroundElevated)
                        border.width: root.theme.borderThin
                        border.color: recorderControl.recording ? root.theme.primary : root.theme.border

                        Column {
                            anchors {
                                left: parent.left
                                right: parent.right
                                verticalCenter: parent.verticalCenter
                                leftMargin: 12
                                rightMargin: 12
                            }
                            spacing: 2

                            Item {
                                width: 18
                                height: 18
                                Text {
                                    anchors.centerIn: parent
                                    text: recorderControl.recording ? "󰑊" : "󰻂"
                                    color: recorderControl.recording ? root.theme.primaryContainerText : root.theme.mutedText
                                    font.family: root.theme.iconFontFamily
                                    font.pixelSize: root.theme.iconSm
                                }
                            }

                            Text {
                                width: parent.width
                                text: "Recorder"
                                color: recorderControl.recording ? root.theme.primaryContainerText : root.theme.text
                                font.family: root.theme.fontFamily
                                font.pixelSize: root.theme.fontSizeXs
                                font.weight: root.theme.fontWeightDemiBold
                            }

                            Text {
                                width: parent.width
                                text: recorderControl.statusText
                                color: recorderControl.recording ? root.theme.primaryContainerText : root.theme.mutedText
                                opacity: 0.8
                                elide: Text.ElideRight
                                font.family: root.theme.fontFamily
                                font.pixelSize: root.theme.fontSize2Xs
                            }
                        }

                        MouseArea {
                            id: recMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: recorderControl.toggleRecording()
                        }
                    }

                    // 3. Screenshot
                    Rectangle {
                        width: (parent.width - root.theme.spacingSm) / 2
                        height: 58
                        radius: root.theme.radiusMd
                        clip: true
                        color: shotMouse.containsMouse ? root.theme.hoverStrong : root.theme.cardBackgroundElevated
                        border.width: root.theme.borderThin
                        border.color: root.theme.border

                        Column {
                            anchors {
                                left: parent.left
                                right: parent.right
                                verticalCenter: parent.verticalCenter
                                leftMargin: 12
                                rightMargin: 12
                            }
                            spacing: 2

                            Item {
                                width: 18
                                height: 18
                                Text {
                                    anchors.centerIn: parent
                                    text: "󰹑"
                                    color: root.theme.mutedText
                                    font.family: root.theme.iconFontFamily
                                    font.pixelSize: root.theme.iconSm
                                }
                            }

                            Text {
                                width: parent.width
                                text: "Screenshot"
                                color: root.theme.text
                                font.family: root.theme.fontFamily
                                font.pixelSize: root.theme.fontSizeXs
                                font.weight: root.theme.fontWeightDemiBold
                            }

                            Text {
                                width: parent.width
                                text: "Capture"
                                color: root.theme.mutedText
                                opacity: 0.8
                                font.family: root.theme.fontFamily
                                font.pixelSize: root.theme.fontSize2Xs
                            }
                        }

                        MouseArea {
                            id: shotMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.takeScreenshot()
                        }
                    }

                    // 4. Clipboard
                    Rectangle {
                        width: (parent.width - root.theme.spacingSm) / 2
                        height: 58
                        radius: root.theme.radiusMd
                        clip: true
                        color: clipMouse.containsMouse ? root.theme.hoverStrong : root.theme.cardBackgroundElevated
                        border.width: root.theme.borderThin
                        border.color: root.theme.border

                        Column {
                            anchors {
                                left: parent.left
                                right: parent.right
                                verticalCenter: parent.verticalCenter
                                leftMargin: 12
                                rightMargin: 12
                            }
                            spacing: 2

                            Item {
                                width: 18
                                height: 18
                                Text {
                                    anchors.centerIn: parent
                                    text: "󰅇"
                                    color: root.theme.mutedText
                                    font.family: root.theme.iconFontFamily
                                    font.pixelSize: root.theme.iconSm
                                }
                            }

                            Text {
                                width: parent.width
                                text: "Clipboard"
                                color: root.theme.text
                                font.family: root.theme.fontFamily
                                font.pixelSize: root.theme.fontSizeXs
                                font.weight: root.theme.fontWeightDemiBold
                            }

                            Text {
                                width: parent.width
                                text: "Open"
                                color: root.theme.mutedText
                                opacity: 0.8
                                font.family: root.theme.fontFamily
                                font.pixelSize: root.theme.fontSize2Xs
                            }
                        }

                        MouseArea {
                            id: clipMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.openClipboard()
                        }
                    }
                }
            }
        }
    }
}
