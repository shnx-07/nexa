import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../../../NewNexaUI" as NexaUI

import "../../audio" as AudioModule
import "../../brightness" as BrightnessModule
import "../../network" as NetworkModule
import "../../airplane" as AirplaneModule
import "../../vpn" as VpnModule
import "../../nightlight" as NightLightModule
import "../../screenfilter" as ScreenFilterModule
import "../../notifications" as NotificationModule
import "../../recorder" as RecorderModule
import "../../battery" as BatteryModule

Item {
    id: root


    property bool appsExpanded: false
    property bool screenFilterDropdownOpen: false
    property bool sinkMenuOpen: false
    property bool scheduleMenuOpen: false

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
        case "paper-mode": return "Paper Mode"
        default: return "Off"
        }
    }

    AudioModule.Audio { id: audio; visible: root.visible }
    BrightnessModule.Brightness { id: brightness; visible: root.visible }
    NetworkModule.Wifi { id: wifi; visible: false; width: 0; height: 0; enablePopup: false }
    NetworkModule.Bluetooth { id: bluetooth; visible: false; width: 0; height: 0; enablePopup: false }
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

        NexaUI.NexaSmoothScroll {}

        Row {
            id: columnsRow
            width: parent.width
            spacing: NexaUI.NexaTokens.spacingLg

            // ========================================================
            // LEFT COLUMN (Audio, Display, Night Light, Screen Filter)
            // ========================================================
            Column {
                width: (parent.width - NexaUI.NexaTokens.spacingLg) / 2
                spacing: 10

                // ----------------------------------------------------
                // 1. AUDIO CARD (Output, Apps, Mic)
                // ----------------------------------------------------
                Rectangle {
                    width: parent.width
                    implicitHeight: audioCardContent.implicitHeight + 16
                    radius: NexaUI.NexaTokens.radiusMd
                    color: NexaUI.NexaColors.surfaceContainer
                    border.width: NexaUI.NexaTokens.borderThin
                    border.color: NexaUI.NexaColors.border

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
                            spacing: NexaUI.NexaTokens.spacingSm

                            Text {
                                text: audio.muted ? "󰝟" : (audio.volume > 50 ? "󰕾" : (audio.volume > 0 ? "󰖀" : "󰕿"))
                                font.family: NexaUI.NexaTypography.familyIcon
                                font.pixelSize: NexaUI.NexaTokens.iconSm
                                color: audio.muted ? NexaUI.NexaColors.error : NexaUI.NexaColors.primary
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: audio.toggleMute()
                                }
                            }

                            Text {
                                text: "Output"
                                font.family: NexaUI.NexaTypography.familyBody
                                font.pixelSize: NexaUI.NexaTypography.sizeXs
                                font.weight: Font.DemiBold
                                color: NexaUI.NexaColors.text
                            }

                            // Audio Output Device Chip
                            Rectangle {
                                id: sinkChip
                                implicitHeight: 22
                                implicitWidth: Math.min(120, sinkChipRow.implicitWidth + 16)
                                radius: 11
                                color: root.sinkMenuOpen
                                    ? NexaUI.NexaColors.primaryContainer
                                    : (sinkChipMouse.containsMouse ? NexaUI.NexaColors.surfaceContainerHighest : NexaUI.NexaColors.surfaceContainerHigh)
                                border.width: NexaUI.NexaTokens.borderThin
                                border.color: root.sinkMenuOpen ? NexaUI.NexaColors.primary : NexaUI.NexaColors.border

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
                                        font.family: NexaUI.NexaTypography.familyIcon
                                        font.pixelSize: NexaUI.NexaTokens.iconSm
                                        color: root.sinkMenuOpen ? NexaUI.NexaColors.onPrimaryContainer : NexaUI.NexaColors.primary
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
                                        font.family: NexaUI.NexaTypography.familyBody
                                        font.pixelSize: 10
                                        font.weight: Font.Medium
                                        color: root.sinkMenuOpen ? NexaUI.NexaColors.onPrimaryContainer : NexaUI.NexaColors.text
                                    }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: root.sinkMenuOpen ? "▴" : "▾"
                                        font.pixelSize: 10
                                        color: root.sinkMenuOpen ? NexaUI.NexaColors.onPrimaryContainer : NexaUI.NexaColors.mutedText
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
                                color: root.appsExpanded ? NexaUI.NexaColors.primaryContainer : (appsMouse.containsMouse ? NexaUI.NexaColors.surfaceContainerHigh : "transparent")

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰅀"
                                    rotation: root.appsExpanded ? 180 : 0
                                    font.family: NexaUI.NexaTypography.familyIcon
                                    font.pixelSize: NexaUI.NexaTokens.iconSm
                                    color: root.appsExpanded ? NexaUI.NexaColors.onPrimaryContainer : NexaUI.NexaColors.mutedText
                                    Behavior on rotation { NumberAnimation { duration: NexaUI.NexaMotion.durationInstant } }
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
                                font.family: NexaUI.NexaTypography.familyMono
                                font.pixelSize: NexaUI.NexaTypography.sizeXs
                                color: NexaUI.NexaColors.text
                            }
                        }

                        // Expandable Audio Sinks List
                        Column {
                            width: parent.width
                            visible: root.sinkMenuOpen && audio.sinks.length > 0
                            spacing: NexaUI.NexaTokens.spacingXs

                            Repeater {
                                model: audio.sinks
                                delegate: Rectangle {
                                    width: parent.width
                                    height: 32
                                    radius: NexaUI.NexaTokens.radiusMd
                                    color: modelData.active
                                        ? NexaUI.NexaColors.primaryContainer
                                        : (sinkItemMouse.containsMouse ? NexaUI.NexaColors.surfaceContainerHigh : NexaUI.NexaColors.surfaceContainerHigh)
                                    border.width: NexaUI.NexaTokens.borderThin
                                    border.color: modelData.active ? NexaUI.NexaColors.primary : NexaUI.NexaColors.border

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: NexaUI.NexaTokens.spacingSm
                                        anchors.rightMargin: NexaUI.NexaTokens.spacingSm
                                        spacing: NexaUI.NexaTokens.spacingSm

                                        Text {
                                            text: modelData.icon || "󰕾"
                                            font.family: NexaUI.NexaTypography.familyIcon
                                            font.pixelSize: NexaUI.NexaTokens.iconSm
                                            color: modelData.active ? NexaUI.NexaColors.onPrimaryContainer : NexaUI.NexaColors.primary
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.description
                                            elide: Text.ElideRight
                                            font.family: NexaUI.NexaTypography.familyBody
                                            font.pixelSize: NexaUI.NexaTypography.sizeXs
                                            font.weight: modelData.active ? Font.DemiBold : Font.Normal
                                            color: modelData.active ? NexaUI.NexaColors.onPrimaryContainer : NexaUI.NexaColors.text
                                        }

                                        Text {
                                            visible: modelData.active
                                            text: "󰄬"
                                            font.family: NexaUI.NexaTypography.familyIcon
                                            font.pixelSize: NexaUI.NexaTokens.iconSm
                                            color: NexaUI.NexaColors.onPrimaryContainer
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

                        // Dedicated Master Volume Slider Bar (Mist / Control Center Pill)
                        NexaUI.NexaSlider {
                            width: parent.width
                            sliderHeight: 28
                            from: 0
                            to: 100
                            value: audio.volume
                            icon: audio.muted ? "󰝟" : (audio.volume > 50 ? "󰕾" : (audio.volume > 0 ? "󰖀" : "󰕿"))
                            iconPosition: "left"
                            showValue: false
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
                            radius: NexaUI.NexaTokens.radiusMd
                            color: NexaUI.NexaColors.surfaceContainerHigh
                            border.width: NexaUI.NexaTokens.borderThin
                            border.color: NexaUI.NexaColors.border
                            clip: true

                            Behavior on height { NumberAnimation { duration: NexaUI.NexaMotion.durationNormal; easing.type: Easing.InOutQuad } }
                            Behavior on opacity { NumberAnimation { duration: NexaUI.NexaMotion.durationInstant } }

                            Text {
                                anchors.centerIn: parent
                                visible: !audio.appsLoading && audio.apps.length === 0
                                text: "No active audio applications"
                                color: NexaUI.NexaColors.mutedText
                                font.family: NexaUI.NexaTypography.familyBody
                                font.pixelSize: NexaUI.NexaTypography.sizeXs
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: audio.appsLoading
                                text: "Loading…"
                                color: NexaUI.NexaColors.mutedText
                                font.family: NexaUI.NexaTypography.familyBody
                                font.pixelSize: NexaUI.NexaTypography.sizeXs
                            }

                            ListView {
                                id: appListView
                                anchors { fill: parent; margins: 8 }
                                visible: !audio.appsLoading && audio.apps.length > 0
                                clip: true
                                spacing: NexaUI.NexaTokens.spacingSm
                                model: audio.apps

                                delegate: Column {
                                    required property var modelData
                                    width: ListView.view.width
                                    spacing: NexaUI.NexaTokens.spacing2Xs

                                    RowLayout {
                                        width: parent.width
                                        spacing: NexaUI.NexaTokens.spacingSm

                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.name
                                            elide: Text.ElideRight
                                            color: NexaUI.NexaColors.text
                                            font.family: NexaUI.NexaTypography.familyBody
                                            font.pixelSize: NexaUI.NexaTypography.sizeXs
                                        }

                                        Text {
                                            text: modelData.volume + "%"
                                            color: NexaUI.NexaColors.mutedText
                                            font.family: NexaUI.NexaTypography.familyMono
                                            font.pixelSize: NexaUI.NexaTypography.sizeXs
                                        }

                                        Rectangle {
                                            width: 24
                                            height: 24
                                            radius: NexaUI.NexaTokens.radiusSm
                                            color: appMuteMouse.containsMouse ? NexaUI.NexaColors.surfaceContainerHighest : "transparent"

                                             Text {
                                                anchors.centerIn: parent
                                                text: modelData.muted ? "󰝟" : "󰕾"
                                                color: modelData.muted ? NexaUI.NexaColors.mutedText : NexaUI.NexaColors.text
                                                font.family: NexaUI.NexaTypography.familyIcon
                                                font.pixelSize: NexaUI.NexaTokens.iconSm
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
                            height: NexaUI.NexaTokens.borderThin
                            color: NexaUI.NexaColors.borderSubtle
                        }

                        // Microphone Header: Title, Mute, Volume %
                        RowLayout {
                            width: parent.width
                            spacing: NexaUI.NexaTokens.spacingSm

                            Text {
                                text: audio.inputMuted ? "󰍭" : "󰍬"
                                font.family: NexaUI.NexaTypography.familyIcon
                                font.pixelSize: NexaUI.NexaTokens.iconSm
                                color: audio.inputMuted ? NexaUI.NexaColors.error : NexaUI.NexaColors.primary

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: audio.toggleInputMute()
                                }
                            }

                            Text {
                                text: "Microphone"
                                font.family: NexaUI.NexaTypography.familyBody
                                font.pixelSize: NexaUI.NexaTypography.sizeXs
                                font.weight: Font.DemiBold
                                color: NexaUI.NexaColors.text

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: audio.toggleInputMute()
                                }
                            }

                            Text {
                                text: audio.inputMuted ? "Muted" : "Active"
                                font.family: NexaUI.NexaTypography.familyBody
                                font.pixelSize: 10
                                color: NexaUI.NexaColors.mutedText
                                opacity: 0.8
                            }

                            Item { Layout.fillWidth: true }

                            // Dedicated mute toggle button
                            Rectangle {
                                implicitWidth: 20
                                implicitHeight: 20
                                radius: 10
                                color: audio.inputMuted
                                    ? NexaUI.NexaColors.errorContainer
                                    : (micMuteHover.containsMouse ? NexaUI.NexaColors.surfaceContainerHighest : NexaUI.NexaColors.primaryContainer)

                                Text {
                                    anchors.centerIn: parent
                                    text: audio.inputMuted ? "󰍭" : "󰍬"
                                    font.family: NexaUI.NexaTypography.familyIcon
                                    font.pixelSize: 11
                                    color: audio.inputMuted ? NexaUI.NexaColors.error : NexaUI.NexaColors.onPrimaryContainer
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
                                font.family: NexaUI.NexaTypography.familyMono
                                font.pixelSize: NexaUI.NexaTypography.sizeXs
                                color: NexaUI.NexaColors.text
                            }
                        }

                        // Dedicated Microphone Slider Bar with Live Reactive Pulse (Pill)
                        NexaUI.NexaSlider {
                            width: parent.width
                            sliderHeight: 28
                            from: 0
                            to: 100
                            value: audio.inputVolume
                            icon: audio.inputMuted ? "󰍭" : "󰍬"
                            iconPosition: "left"
                            showValue: false
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
                    radius: NexaUI.NexaTokens.radiusMd
                    color: NexaUI.NexaColors.surfaceContainer
                    border.width: NexaUI.NexaTokens.borderThin
                    border.color: NexaUI.NexaColors.border

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
                            spacing: NexaUI.NexaTokens.spacingSm

                            Text {
                                text: "󰃠"
                                font.family: NexaUI.NexaTypography.familyIcon
                                font.pixelSize: NexaUI.NexaTokens.iconSm
                                color: NexaUI.NexaColors.primary
                            }

                            Text {
                                text: "Brightness"
                                font.family: NexaUI.NexaTypography.familyBody
                                font.pixelSize: NexaUI.NexaTypography.sizeXs
                                font.weight: Font.DemiBold
                                color: NexaUI.NexaColors.text
                            }

                            Text {
                                text: "Backlight"
                                font.family: NexaUI.NexaTypography.familyBody
                                font.pixelSize: 10
                                color: NexaUI.NexaColors.mutedText
                                opacity: 0.8
                            }

                            Item { Layout.fillWidth: true }

                            Text {
                                text: brightness.brightness + "%"
                                font.family: NexaUI.NexaTypography.familyMono
                                font.pixelSize: NexaUI.NexaTypography.sizeXs
                                color: NexaUI.NexaColors.text
                            }
                        }

                        // Dedicated Brightness Slider Bar (Mist / Control Center Pill)
                        NexaUI.NexaSlider {
                            width: parent.width
                            sliderHeight: 28
                            from: 1
                            to: 100
                            value: brightness.brightness
                            icon: "󰃠"
                            iconPosition: "left"
                            showValue: false
                            onMoved: (val) => brightness.setBrightness(val)
                            onReleased: (val) => brightness.setBrightnessImmediate(val)
                        }

                        // Divider
                        Rectangle {
                            width: parent.width
                            height: NexaUI.NexaTokens.borderThin
                            color: NexaUI.NexaColors.borderSubtle
                        }

                        // Night Light Header: Title, Temperature, Toggle Switch
                        RowLayout {
                            width: parent.width
                            spacing: NexaUI.NexaTokens.spacingSm

                            Text {
                                text: "󰖔"
                                font.family: NexaUI.NexaTypography.familyIcon
                                font.pixelSize: NexaUI.NexaTokens.iconMd
                                color: nightLight.enabled ? NexaUI.NexaColors.primary : NexaUI.NexaColors.mutedText
                            }

                            Text {
                                text: "Night Light"
                                font.family: NexaUI.NexaTypography.familyBody
                                font.pixelSize: NexaUI.NexaTypography.sizeXs
                                font.weight: Font.DemiBold
                                color: NexaUI.NexaColors.text
                            }

                            Text {
                                text: nightLight.enabled ? (nightLight.activeTemperature + "K") : "Off"
                                font.family: NexaUI.NexaTypography.familyBody
                                font.pixelSize: 10
                                color: NexaUI.NexaColors.mutedText
                                opacity: 0.8
                            }

                            Item { Layout.fillWidth: true }

                            // Schedule Dropdown Chip
                            Rectangle {
                                id: scheduleChip
                                implicitHeight: 26
                                implicitWidth: Math.min(140, scheduleChipRow.implicitWidth + 18)
                                radius: 13
                                color: root.scheduleMenuOpen
                                    ? NexaUI.NexaColors.primaryContainer
                                    : (scheduleChipMouse.containsMouse ? NexaUI.NexaColors.surfaceContainerHighest : NexaUI.NexaColors.surfaceContainerHigh)
                                border.width: NexaUI.NexaTokens.borderThin
                                border.color: root.scheduleMenuOpen ? NexaUI.NexaColors.primary : (nightLight.scheduleMode !== "off" ? NexaUI.NexaColors.primary : NexaUI.NexaColors.border)

                                Row {
                                    id: scheduleChipRow
                                    anchors.centerIn: parent
                                    spacing: 4

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: {
                                            if (nightLight.scheduleMode === "sunset") return "󰖔"
                                            if (nightLight.scheduleMode === "custom") return "󰥔"
                                            return "󰔛"
                                        }
                                        font.family: NexaUI.NexaTypography.familyIcon
                                        font.pixelSize: NexaUI.NexaTokens.iconSm
                                        color: root.scheduleMenuOpen ? NexaUI.NexaColors.onPrimaryContainer : (nightLight.scheduleMode !== "off" ? NexaUI.NexaColors.primary : NexaUI.NexaColors.mutedText)
                                    }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: nightLight.scheduleMode === "off" ? "Schedule" : (nightLight.scheduleMode === "sunset" ? "Sunset" : "Custom")
                                        font.family: NexaUI.NexaTypography.familyBody
                                        font.pixelSize: 10
                                        font.weight: Font.Medium
                                        color: root.scheduleMenuOpen ? NexaUI.NexaColors.onPrimaryContainer : (nightLight.scheduleMode !== "off" ? NexaUI.NexaColors.primary : NexaUI.NexaColors.text)
                                    }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: root.scheduleMenuOpen ? "▴" : "▾"
                                        font.pixelSize: 10
                                        color: root.scheduleMenuOpen ? NexaUI.NexaColors.onPrimaryContainer : NexaUI.NexaColors.mutedText
                                    }
                                }

                                MouseArea {
                                    id: scheduleChipMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.scheduleMenuOpen = !root.scheduleMenuOpen
                                    }
                                }
                            }

                            Rectangle {
                                implicitWidth: 40
                                implicitHeight: 22
                                radius: 11
                                color: nightLight.enabled ? NexaUI.NexaColors.primary : NexaUI.NexaColors.surfaceContainerHighest

                                Rectangle {
                                    width: 17
                                    height: 17
                                    radius: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    x: nightLight.enabled ? parent.width - width - 2 : 2
                                    color: nightLight.enabled ? NexaUI.NexaColors.onPrimary : NexaUI.NexaColors.text
                                    Behavior on x { NumberAnimation { duration: NexaUI.NexaMotion.durationInstant } }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: nightLight.toggle()
                                }
                            }
                        }

                        // Expandable Schedule Menu
                        Column {
                            width: parent.width
                            visible: root.scheduleMenuOpen
                            spacing: NexaUI.NexaTokens.spacingXs

                            // Option 1: Off (Manual Only)
                            Rectangle {
                                width: parent.width
                                height: 32
                                radius: NexaUI.NexaTokens.radiusSm
                                color: nightLight.scheduleMode === "off" ? NexaUI.NexaColors.primaryContainer : (offMouse.containsMouse ? NexaUI.NexaColors.surfaceContainerHigh : NexaUI.NexaColors.surfaceContainerHigh)
                                border.width: NexaUI.NexaTokens.borderThin
                                border.color: nightLight.scheduleMode === "off" ? NexaUI.NexaColors.primary : NexaUI.NexaColors.border

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    spacing: 8

                                    Text {
                                        text: "󰔛"
                                        font.family: NexaUI.NexaTypography.familyIcon
                                        font.pixelSize: NexaUI.NexaTokens.iconSm
                                        color: nightLight.scheduleMode === "off" ? NexaUI.NexaColors.onPrimaryContainer : NexaUI.NexaColors.mutedText
                                    }

                                    Column {
                                        Layout.fillWidth: true
                                        spacing: 1

                                        Text {
                                            text: "Manual Only (Off)"
                                            font.family: NexaUI.NexaTypography.familyBody
                                            font.pixelSize: NexaUI.NexaTypography.sizeXs
                                            font.weight: Font.DemiBold
                                            color: nightLight.scheduleMode === "off" ? NexaUI.NexaColors.onPrimaryContainer : NexaUI.NexaColors.text
                                        }
                                    }

                                    Text {
                                        visible: nightLight.scheduleMode === "off"
                                        text: "󰄬"
                                        font.family: NexaUI.NexaTypography.familyIcon
                                        font.pixelSize: NexaUI.NexaTokens.iconSm
                                        color: NexaUI.NexaColors.onPrimaryContainer
                                    }
                                }

                                MouseArea {
                                    id: offMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        nightLight.setSchedule("off")
                                        root.scheduleMenuOpen = false
                                    }
                                }
                            }

                            // Option 2: Sunset to Sunrise
                            Rectangle {
                                width: parent.width
                                height: 38
                                radius: NexaUI.NexaTokens.radiusSm
                                color: nightLight.scheduleMode === "sunset" ? NexaUI.NexaColors.primaryContainer : (sunsetMouse.containsMouse ? NexaUI.NexaColors.surfaceContainerHigh : NexaUI.NexaColors.surfaceContainerHigh)
                                border.width: NexaUI.NexaTokens.borderThin
                                border.color: nightLight.scheduleMode === "sunset" ? NexaUI.NexaColors.primary : NexaUI.NexaColors.border

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    spacing: 8

                                    Text {
                                        text: "󰖔"
                                        font.family: NexaUI.NexaTypography.familyIcon
                                        font.pixelSize: NexaUI.NexaTokens.iconSm
                                        color: nightLight.scheduleMode === "sunset" ? NexaUI.NexaColors.onPrimaryContainer : NexaUI.NexaColors.mutedText
                                    }

                                    Column {
                                        Layout.fillWidth: true
                                        spacing: 1

                                        Text {
                                            text: "Sunset to Sunrise"
                                            font.family: NexaUI.NexaTypography.familyBody
                                            font.pixelSize: NexaUI.NexaTypography.sizeXs
                                            font.weight: Font.DemiBold
                                            color: nightLight.scheduleMode === "sunset" ? NexaUI.NexaColors.onPrimaryContainer : NexaUI.NexaColors.text
                                        }

                                        Text {
                                            text: (nightLight.sunsetTime || "18:30") + " → " + (nightLight.sunriseTime || "06:00")
                                            font.family: NexaUI.NexaTypography.familyMono
                                            font.pixelSize: 10
                                            color: nightLight.scheduleMode === "sunset" ? NexaUI.NexaColors.onPrimaryContainer : NexaUI.NexaColors.mutedText
                                            opacity: 0.85
                                        }
                                    }

                                    Text {
                                        visible: nightLight.scheduleMode === "sunset"
                                        text: "󰄬"
                                        font.family: NexaUI.NexaTypography.familyIcon
                                        font.pixelSize: NexaUI.NexaTokens.iconSm
                                        color: NexaUI.NexaColors.onPrimaryContainer
                                    }
                                }

                                MouseArea {
                                    id: sunsetMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        nightLight.setSchedule("sunset")
                                    }
                                }
                            }

                            // Option 3: Custom Schedule
                            Rectangle {
                                width: parent.width
                                height: nightLight.scheduleMode === "custom" ? 138 : 38
                                radius: NexaUI.NexaTokens.radiusSm
                                color: nightLight.scheduleMode === "custom" ? NexaUI.NexaColors.primaryContainer : (customMouse.containsMouse ? NexaUI.NexaColors.surfaceContainerHigh : NexaUI.NexaColors.surfaceContainerHigh)
                                border.width: NexaUI.NexaTokens.borderThin
                                border.color: nightLight.scheduleMode === "custom" ? NexaUI.NexaColors.primary : NexaUI.NexaColors.border
                                clip: true

                                Column {
                                    anchors.fill: parent
                                    anchors.margins: 6
                                    spacing: 4

                                    RowLayout {
                                        width: parent.width
                                        spacing: 8

                                        Text {
                                            text: "󰥔"
                                            font.family: NexaUI.NexaTypography.familyIcon
                                            font.pixelSize: NexaUI.NexaTokens.iconSm
                                            color: nightLight.scheduleMode === "custom" ? NexaUI.NexaColors.onPrimaryContainer : NexaUI.NexaColors.mutedText
                                        }

                                        Column {
                                            Layout.fillWidth: true
                                            spacing: 1

                                            Text {
                                                text: "Custom Schedule"
                                                font.family: NexaUI.NexaTypography.familyBody
                                                font.pixelSize: NexaUI.NexaTypography.sizeXs
                                                font.weight: Font.DemiBold
                                                color: nightLight.scheduleMode === "custom" ? NexaUI.NexaColors.onPrimaryContainer : NexaUI.NexaColors.text
                                            }

                                            Text {
                                                text: nightLight.formatTimeDisplay(nightLight.scheduleStart) + " → " + nightLight.formatTimeDisplay(nightLight.scheduleEnd)
                                                font.family: NexaUI.NexaTypography.familyMono
                                                font.pixelSize: 10
                                                color: nightLight.scheduleMode === "custom" ? NexaUI.NexaColors.onPrimaryContainer : NexaUI.NexaColors.mutedText
                                                opacity: 0.85
                                            }
                                        }

                                        Text {
                                            visible: nightLight.scheduleMode === "custom"
                                            text: "󰄬"
                                            font.family: NexaUI.NexaTypography.familyIcon
                                            font.pixelSize: NexaUI.NexaTokens.iconSm
                                            color: NexaUI.NexaColors.onPrimaryContainer
                                        }
                                    }

                                    // Time Adjustment Steppers — 12h AM/PM format
                                    RowLayout {
                                        width: parent.width
                                        visible: nightLight.scheduleMode === "custom"
                                        spacing: 6

                                        // Turn On Time Stepper
                                        Rectangle {
                                            Layout.fillWidth: true
                                            height: 84
                                            radius: NexaUI.NexaTokens.radiusSm
                                            color: NexaUI.NexaColors.surfaceContainer
                                            border.width: NexaUI.NexaTokens.borderThin
                                            border.color: NexaUI.NexaColors.border

                                            Column {
                                                anchors.fill: parent
                                                anchors.margins: 6
                                                spacing: 5

                                                Text {
                                                    text: "Turn On"
                                                    font.family: NexaUI.NexaTypography.familyBody
                                                    font.pixelSize: 10
                                                    font.weight: Font.Bold
                                                    color: NexaUI.NexaColors.mutedText
                                                }

                                                RowLayout {
                                                    width: parent.width
                                                    spacing: 3

                                                    // Hour −
                                                    Rectangle {
                                                        width: 16; height: 22; radius: 3
                                                        color: subStartH2.containsMouse ? NexaUI.NexaColors.surfaceContainerHigh : NexaUI.NexaColors.surfaceContainerHigh
                                                        border.width: NexaUI.NexaTokens.borderThin; border.color: NexaUI.NexaColors.border
                                                        Text { anchors.centerIn: parent; text: "−"; font.pixelSize: 11; color: NexaUI.NexaColors.text }
                                                        MouseArea { id: subStartH2; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: nightLight.adjustScheduleHour("start", -1) }
                                                    }

                                                    // Hour display (12h)
                                                    Text {
                                                        Layout.preferredWidth: 20
                                                        horizontalAlignment: Text.AlignHCenter
                                                        text: {
                                                             let h = parseInt((nightLight.scheduleStart || "22:00").split(":")[0], 10) || 0
                                                            let h12 = h % 12; if (h12 === 0) h12 = 12
                                                            return h12 < 10 ? "0" + h12 : "" + h12
                                                        }
                                                        font.family: NexaUI.NexaTypography.familyMono
                                                        font.pixelSize: NexaUI.NexaTypography.sizeXs
                                                        font.weight: Font.DemiBold
                                                        color: NexaUI.NexaColors.text
                                                        MouseArea { anchors.fill: parent; onWheel: (w) => { if (w.angleDelta.y > 0) nightLight.adjustScheduleHour("start", 1); else nightLight.adjustScheduleHour("start", -1) } }
                                                    }

                                                    // Hour +
                                                    Rectangle {
                                                        width: 16; height: 22; radius: 3
                                                        color: addStartH2.containsMouse ? NexaUI.NexaColors.surfaceContainerHigh : NexaUI.NexaColors.surfaceContainerHigh
                                                        border.width: NexaUI.NexaTokens.borderThin; border.color: NexaUI.NexaColors.border
                                                        Text { anchors.centerIn: parent; text: "+"; font.pixelSize: 11; color: NexaUI.NexaColors.text }
                                                        MouseArea { id: addStartH2; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: nightLight.adjustScheduleHour("start", 1) }
                                                    }

                                                    Text { text: ":"; font.family: NexaUI.NexaTypography.familyMono; font.pixelSize: NexaUI.NexaTypography.sizeXs; font.bold: true; color: NexaUI.NexaColors.mutedText }

                                                    // Minute −
                                                    Rectangle {
                                                        width: 16; height: 22; radius: 3
                                                        color: subStartM2.containsMouse ? NexaUI.NexaColors.surfaceContainerHigh : NexaUI.NexaColors.surfaceContainerHigh
                                                        border.width: NexaUI.NexaTokens.borderThin; border.color: NexaUI.NexaColors.border
                                                        Text { anchors.centerIn: parent; text: "−"; font.pixelSize: 11; color: NexaUI.NexaColors.text }
                                                        MouseArea { id: subStartM2; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: nightLight.adjustScheduleMinute("start", -5) }
                                                    }

                                                    // Minute display
                                                    Text {
                                                        Layout.preferredWidth: 20
                                                        horizontalAlignment: Text.AlignHCenter
                                                        text: (nightLight.scheduleStart || "22:00").split(":")[1] || "00"
                                                        font.family: NexaUI.NexaTypography.familyMono
                                                        font.pixelSize: NexaUI.NexaTypography.sizeXs
                                                        font.weight: Font.DemiBold
                                                        color: NexaUI.NexaColors.text
                                                        MouseArea { anchors.fill: parent; onWheel: (w) => { if (w.angleDelta.y > 0) nightLight.adjustScheduleMinute("start", 1); else nightLight.adjustScheduleMinute("start", -1) } }
                                                    }

                                                    // Minute +
                                                    Rectangle {
                                                        width: 16; height: 22; radius: 3
                                                        color: addStartM2.containsMouse ? NexaUI.NexaColors.surfaceContainerHigh : NexaUI.NexaColors.surfaceContainerHigh
                                                        border.width: NexaUI.NexaTokens.borderThin; border.color: NexaUI.NexaColors.border
                                                        Text { anchors.centerIn: parent; text: "+"; font.pixelSize: 11; color: NexaUI.NexaColors.text }
                                                        MouseArea { id: addStartM2; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: nightLight.adjustScheduleMinute("start", 5) }
                                                    }
                                                }

                                                // Extra vertical gap between time row and AM/PM
                                                Item {
                                                    width: 1
                                                    height: 3
                                                }

                                                // AM / PM pills below
                                                Row {
                                                    spacing: 4
                                                    Rectangle {
                                                        width: 28; height: 16; radius: 3
                                                        color: parseInt((nightLight.scheduleStart||"22:00").split(":")[0],10) < 12 ? NexaUI.NexaColors.primary : NexaUI.NexaColors.surfaceContainerHigh
                                                        border.width: NexaUI.NexaTokens.borderThin; border.color: NexaUI.NexaColors.primary
                                                        Text { anchors.centerIn: parent; text: "AM"; font.pixelSize: 9; font.weight: Font.Bold
                                                            color: parseInt((nightLight.scheduleStart||"22:00").split(":")[0],10) < 12 ? NexaUI.NexaColors.onPrimary : NexaUI.NexaColors.primary }
                                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                            onClicked: { let h=parseInt((nightLight.scheduleStart||"22:00").split(":")[0],10)||0; if(h>=12) nightLight.adjustScheduleHour("start",-12) } }
                                                    }
                                                    Rectangle {
                                                        width: 28; height: 16; radius: 3
                                                        color: parseInt((nightLight.scheduleStart||"22:00").split(":")[0],10) >= 12 ? NexaUI.NexaColors.primary : NexaUI.NexaColors.surfaceContainerHigh
                                                        border.width: NexaUI.NexaTokens.borderThin; border.color: NexaUI.NexaColors.primary
                                                        Text { anchors.centerIn: parent; text: "PM"; font.pixelSize: 9; font.weight: Font.Bold
                                                            color: parseInt((nightLight.scheduleStart||"22:00").split(":")[0],10) >= 12 ? NexaUI.NexaColors.onPrimary : NexaUI.NexaColors.primary }
                                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                            onClicked: { let h=parseInt((nightLight.scheduleStart||"22:00").split(":")[0],10)||0; if(h<12) nightLight.adjustScheduleHour("start",12) } }
                                                    }
                                                }
                                            }
                                        }

                                        // Turn Off Time Stepper
                                        Rectangle {
                                            Layout.fillWidth: true
                                            height: 84
                                            radius: NexaUI.NexaTokens.radiusSm
                                            color: NexaUI.NexaColors.surfaceContainer
                                            border.width: NexaUI.NexaTokens.borderThin
                                            border.color: NexaUI.NexaColors.border

                                            Column {
                                                anchors.fill: parent
                                                anchors.margins: 6
                                                spacing: 5

                                                Text {
                                                    text: "Turn Off"
                                                    font.family: NexaUI.NexaTypography.familyBody
                                                    font.pixelSize: 10
                                                    font.weight: Font.Bold
                                                    color: NexaUI.NexaColors.mutedText
                                                }

                                                RowLayout {
                                                    width: parent.width
                                                    spacing: 3

                                                    // Hour −
                                                    Rectangle {
                                                        width: 16; height: 22; radius: 3
                                                        color: subEndH2.containsMouse ? NexaUI.NexaColors.surfaceContainerHigh : NexaUI.NexaColors.surfaceContainerHigh
                                                        border.width: NexaUI.NexaTokens.borderThin; border.color: NexaUI.NexaColors.border
                                                        Text { anchors.centerIn: parent; text: "−"; font.pixelSize: 11; color: NexaUI.NexaColors.text }
                                                        MouseArea { id: subEndH2; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: nightLight.adjustScheduleHour("end", -1) }
                                                    }

                                                    // Hour display (12h)
                                                    Text {
                                                        Layout.preferredWidth: 18
                                                        horizontalAlignment: Text.AlignHCenter
                                                        text: {
                                                            let h = parseInt((nightLight.scheduleEnd || "06:00").split(":")[0], 10) || 0
                                                            let h12 = h % 12; if (h12 === 0) h12 = 12
                                                            return h12 < 10 ? "0" + h12 : "" + h12
                                                        }
                                                        font.family: NexaUI.NexaTypography.familyMono
                                                        font.pixelSize: NexaUI.NexaTypography.sizeXs
                                                        font.weight: Font.DemiBold
                                                        color: NexaUI.NexaColors.text
                                                        MouseArea { anchors.fill: parent; onWheel: (w) => { if (w.angleDelta.y > 0) nightLight.adjustScheduleHour("end", 1); else nightLight.adjustScheduleHour("end", -1) } }
                                                    }

                                                    // Hour +
                                                    Rectangle {
                                                        width: 16; height: 22; radius: 3
                                                        color: addEndH2.containsMouse ? NexaUI.NexaColors.surfaceContainerHigh : NexaUI.NexaColors.surfaceContainerHigh
                                                        border.width: NexaUI.NexaTokens.borderThin; border.color: NexaUI.NexaColors.border
                                                        Text { anchors.centerIn: parent; text: "+"; font.pixelSize: 11; color: NexaUI.NexaColors.text }
                                                        MouseArea { id: addEndH2; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: nightLight.adjustScheduleHour("end", 1) }
                                                    }

                                                    Text { text: ":"; font.family: NexaUI.NexaTypography.familyMono; font.pixelSize: NexaUI.NexaTypography.sizeXs; font.bold: true; color: NexaUI.NexaColors.mutedText }

                                                    // Minute −
                                                    Rectangle {
                                                        width: 16; height: 22; radius: 3
                                                        color: subEndM2.containsMouse ? NexaUI.NexaColors.surfaceContainerHigh : NexaUI.NexaColors.surfaceContainerHigh
                                                        border.width: NexaUI.NexaTokens.borderThin; border.color: NexaUI.NexaColors.border
                                                        Text { anchors.centerIn: parent; text: "−"; font.pixelSize: 11; color: NexaUI.NexaColors.text }
                                                        MouseArea { id: subEndM2; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: nightLight.adjustScheduleMinute("end", -5) }
                                                    }

                                                    // Minute display
                                                    Text {
                                                        Layout.preferredWidth: 18
                                                        horizontalAlignment: Text.AlignHCenter
                                                        text: (nightLight.scheduleEnd || "06:00").split(":")[1] || "00"
                                                        font.family: NexaUI.NexaTypography.familyMono
                                                        font.pixelSize: NexaUI.NexaTypography.sizeXs
                                                        font.weight: Font.DemiBold
                                                        color: NexaUI.NexaColors.text
                                                        MouseArea { anchors.fill: parent; onWheel: (w) => { if (w.angleDelta.y > 0) nightLight.adjustScheduleMinute("end", 1); else nightLight.adjustScheduleMinute("end", -1) } }
                                                    }

                                                    // Minute +
                                                    Rectangle {
                                                        width: 16; height: 22; radius: 3
                                                        color: addEndM2.containsMouse ? NexaUI.NexaColors.surfaceContainerHigh : NexaUI.NexaColors.surfaceContainerHigh
                                                        border.width: NexaUI.NexaTokens.borderThin; border.color: NexaUI.NexaColors.border
                                                        Text { anchors.centerIn: parent; text: "+"; font.pixelSize: 11; color: NexaUI.NexaColors.text }
                                                        MouseArea { id: addEndM2; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: nightLight.adjustScheduleMinute("end", 5) }
                                                    }
                                                }

                                                // Extra vertical gap between time row and AM/PM
                                                Item {
                                                    width: 1
                                                    height: 3
                                                }

                                                // AM / PM pills below
                                                Row {
                                                    spacing: 4
                                                    Rectangle {
                                                        width: 28; height: 16; radius: 3
                                                        color: parseInt((nightLight.scheduleEnd||"06:00").split(":")[0],10) < 12 ? NexaUI.NexaColors.primary : NexaUI.NexaColors.surfaceContainerHigh
                                                        border.width: NexaUI.NexaTokens.borderThin; border.color: NexaUI.NexaColors.primary
                                                        Text { anchors.centerIn: parent; text: "AM"; font.pixelSize: 9; font.weight: Font.Bold
                                                            color: parseInt((nightLight.scheduleEnd||"06:00").split(":")[0],10) < 12 ? NexaUI.NexaColors.onPrimary : NexaUI.NexaColors.primary }
                                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                            onClicked: { let h=parseInt((nightLight.scheduleEnd||"06:00").split(":")[0],10)||0; if(h>=12) nightLight.adjustScheduleHour("end",-12) } }
                                                    }
                                                    Rectangle {
                                                        width: 28; height: 16; radius: 3
                                                        color: parseInt((nightLight.scheduleEnd||"06:00").split(":")[0],10) >= 12 ? NexaUI.NexaColors.primary : NexaUI.NexaColors.surfaceContainerHigh
                                                        border.width: NexaUI.NexaTokens.borderThin; border.color: NexaUI.NexaColors.primary
                                                        Text { anchors.centerIn: parent; text: "PM"; font.pixelSize: 9; font.weight: Font.Bold
                                                            color: parseInt((nightLight.scheduleEnd||"06:00").split(":")[0],10) >= 12 ? NexaUI.NexaColors.onPrimary : NexaUI.NexaColors.primary }
                                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                            onClicked: { let h=parseInt((nightLight.scheduleEnd||"06:00").split(":")[0],10)||0; if(h<12) nightLight.adjustScheduleHour("end",12) } }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                MouseArea {
                                    id: customMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    z: -1
                                    onClicked: {
                                        nightLight.setSchedule("custom")
                                    }
                                }
                            }
                        }

                        // Dedicated Night Light Temperature Slider (Mist Pill)
                        NexaUI.NexaSlider {
                            width: parent.width
                            sliderHeight: 28
                            from: nightLight.minimumTemperature
                            to: nightLight.maximumTemperature
                            stepSize: 50
                            value: nightLight.activeTemperature
                            enabled: nightLight.enabled && !nightLight.wallpaperMode
                            opacity: enabled ? 1.0 : 0.4
                            icon: "󰌵"
                            iconPosition: "left"
                            showValue: false
                            onMoved: (val) => {
                                if (nightLight.enabled) nightLight.setTemperature(val)
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
                                    height: 28
                                    radius: NexaUI.NexaTokens.radiusSm
                                    color: nightLight.mode === modelData.mode ? NexaUI.NexaColors.primaryContainer : (mMouse.containsMouse ? NexaUI.NexaColors.surfaceContainerHigh : NexaUI.NexaColors.surfaceContainerHigh)
                                    border.width: NexaUI.NexaTokens.borderThin
                                    border.color: nightLight.mode === modelData.mode ? NexaUI.NexaColors.primary : NexaUI.NexaColors.border

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.label
                                        font.family: NexaUI.NexaTypography.familyBody
                                        font.pixelSize: 10
                                        font.weight: nightLight.mode === modelData.mode ? Font.DemiBold : Font.Normal
                                        color: nightLight.mode === modelData.mode ? NexaUI.NexaColors.onPrimaryContainer : NexaUI.NexaColors.text
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
            }

            // ========================================================
            // RIGHT COLUMN (Tiles: Connectivity & Actions)
            // ========================================================
            Column {
                width: (parent.width - NexaUI.NexaTokens.spacingLg) / 2
                spacing: 8

                // --- CONNECTIVITY HEADER ---
                Text {
                    text: "Connectivity"
                    color: NexaUI.NexaColors.text
                    font.family: NexaUI.NexaTypography.familyBody
                    font.pixelSize: NexaUI.NexaTypography.sizeXs
                    font.weight: Font.DemiBold
                    opacity: 0.9
                }

                // 2x2 CONNECTIVITY GRID (Unified Pixel-Perfect Alignment)
                Grid {
                    width: parent.width
                    columns: 2
                    columnSpacing: NexaUI.NexaTokens.spacingSm
                    rowSpacing: NexaUI.NexaTokens.spacingSm

                    // 1. Wi-Fi
                    Rectangle {
                        width: (parent.width - NexaUI.NexaTokens.spacingSm) / 2
                        height: 58
                        radius: NexaUI.NexaTokens.radiusMd
                        clip: true
                        color: wifi.enabled ? NexaUI.NexaColors.primaryContainer : (wifiMouse.containsMouse ? NexaUI.NexaColors.surfaceContainerHighest : NexaUI.NexaColors.surfaceContainerHigh)
                        border.width: NexaUI.NexaTokens.borderThin
                        border.color: wifi.enabled ? NexaUI.NexaColors.primary : NexaUI.NexaColors.border

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
                                    color: wifi.enabled ? NexaUI.NexaColors.onPrimaryContainer : NexaUI.NexaColors.mutedText
                                    font.family: NexaUI.NexaTypography.familyIcon
                                    font.pixelSize: NexaUI.NexaTokens.iconSm
                                }
                            }

                            Text {
                                width: parent.width
                                text: "Wi-Fi"
                                color: wifi.enabled ? NexaUI.NexaColors.onPrimaryContainer : NexaUI.NexaColors.text
                                elide: Text.ElideRight
                                font.family: NexaUI.NexaTypography.familyBody
                                font.pixelSize: NexaUI.NexaTypography.sizeXs
                                font.weight: Font.DemiBold
                            }

                            Text {
                                width: parent.width
                                text: !wifi.enabled ? "Off" : (wifi.connected ? wifi.ssid : "Disconnected")
                                color: wifi.enabled ? NexaUI.NexaColors.onPrimaryContainer : NexaUI.NexaColors.mutedText
                                opacity: 0.8
                                elide: Text.ElideRight
                                font.family: NexaUI.NexaTypography.familyBody
                                font.pixelSize: 10
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
                        width: (parent.width - NexaUI.NexaTokens.spacingSm) / 2
                        height: 58
                        radius: NexaUI.NexaTokens.radiusMd
                        clip: true
                        color: bluetooth.enabled ? NexaUI.NexaColors.primaryContainer : (btMouse.containsMouse ? NexaUI.NexaColors.surfaceContainerHighest : NexaUI.NexaColors.surfaceContainerHigh)
                        border.width: NexaUI.NexaTokens.borderThin
                        border.color: bluetooth.enabled ? NexaUI.NexaColors.primary : NexaUI.NexaColors.border

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
                                    color: bluetooth.enabled ? NexaUI.NexaColors.onPrimaryContainer : NexaUI.NexaColors.mutedText
                                    font.family: NexaUI.NexaTypography.familyIcon
                                    font.pixelSize: NexaUI.NexaTokens.iconSm
                                }
                            }

                            Text {
                                width: parent.width
                                text: "Bluetooth"
                                color: bluetooth.enabled ? NexaUI.NexaColors.onPrimaryContainer : NexaUI.NexaColors.text
                                elide: Text.ElideRight
                                font.family: NexaUI.NexaTypography.familyBody
                                font.pixelSize: NexaUI.NexaTypography.sizeXs
                                font.weight: Font.DemiBold
                            }

                            Text {
                                width: parent.width
                                text: !bluetooth.enabled ? "Off" : (bluetooth.connected ? bluetooth.connectedDeviceName : "On")
                                color: bluetooth.enabled ? NexaUI.NexaColors.onPrimaryContainer : NexaUI.NexaColors.mutedText
                                opacity: 0.8
                                elide: Text.ElideRight
                                font.family: NexaUI.NexaTypography.familyBody
                                font.pixelSize: 10
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
                        width: (parent.width - NexaUI.NexaTokens.spacingSm) / 2
                        height: 58
                        radius: NexaUI.NexaTokens.radiusMd
                        clip: true
                        color: airplane.enabled ? NexaUI.NexaColors.primaryContainer : (airMouse.containsMouse ? NexaUI.NexaColors.surfaceContainerHighest : NexaUI.NexaColors.surfaceContainerHigh)
                        border.width: NexaUI.NexaTokens.borderThin
                        border.color: airplane.enabled ? NexaUI.NexaColors.primary : NexaUI.NexaColors.border

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
                                    color: airplane.enabled ? NexaUI.NexaColors.onPrimaryContainer : NexaUI.NexaColors.mutedText
                                    font.family: NexaUI.NexaTypography.familyIcon
                                    font.pixelSize: NexaUI.NexaTokens.iconSm
                                }
                            }

                            Text {
                                width: parent.width
                                text: "Airplane"
                                color: airplane.enabled ? NexaUI.NexaColors.onPrimaryContainer : NexaUI.NexaColors.text
                                elide: Text.ElideRight
                                font.family: NexaUI.NexaTypography.familyBody
                                font.pixelSize: NexaUI.NexaTypography.sizeXs
                                font.weight: Font.DemiBold
                            }

                            Text {
                                width: parent.width
                                text: airplane.enabled ? "On" : "Off"
                                color: airplane.enabled ? NexaUI.NexaColors.onPrimaryContainer : NexaUI.NexaColors.mutedText
                                opacity: 0.8
                                elide: Text.ElideRight
                                font.family: NexaUI.NexaTypography.familyBody
                                font.pixelSize: 10
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
                        width: (parent.width - NexaUI.NexaTokens.spacingSm) / 2
                        height: 58
                        radius: NexaUI.NexaTokens.radiusMd
                        clip: true
                        color: vpn.enabled ? NexaUI.NexaColors.primaryContainer : (vpnMouse.containsMouse ? NexaUI.NexaColors.surfaceContainerHighest : NexaUI.NexaColors.surfaceContainerHigh)
                        border.width: NexaUI.NexaTokens.borderThin
                        border.color: vpn.enabled ? NexaUI.NexaColors.primary : NexaUI.NexaColors.border

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
                                    color: vpn.enabled ? NexaUI.NexaColors.onPrimaryContainer : NexaUI.NexaColors.mutedText
                                    font.family: NexaUI.NexaTypography.familyIcon
                                    font.pixelSize: NexaUI.NexaTokens.iconSm
                                }
                            }

                            Text {
                                width: parent.width
                                text: "VPN"
                                color: vpn.enabled ? NexaUI.NexaColors.onPrimaryContainer : NexaUI.NexaColors.text
                                elide: Text.ElideRight
                                font.family: NexaUI.NexaTypography.familyBody
                                font.pixelSize: NexaUI.NexaTypography.sizeXs
                                font.weight: Font.DemiBold
                            }

                            Text {
                                width: parent.width
                                text: !vpn.available ? "No profile" : (vpn.enabled ? vpn.activeProfile : "Disconnected")
                                color: vpn.enabled ? NexaUI.NexaColors.onPrimaryContainer : NexaUI.NexaColors.mutedText
                                opacity: 0.8
                                elide: Text.ElideRight
                                font.family: NexaUI.NexaTypography.familyBody
                                font.pixelSize: 10
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
                    color: NexaUI.NexaColors.text
                    font.family: NexaUI.NexaTypography.familyBody
                    font.pixelSize: NexaUI.NexaTypography.sizeXs
                    font.weight: Font.DemiBold
                    opacity: 0.9
                }

                // 2x2 ACTIONS GRID (Unified Pixel-Perfect Alignment)
                Grid {
                    width: parent.width
                    columns: 2
                    columnSpacing: NexaUI.NexaTokens.spacingSm
                    rowSpacing: NexaUI.NexaTokens.spacingSm

                    // 1. DND
                    Rectangle {
                        width: (parent.width - NexaUI.NexaTokens.spacingSm) / 2
                        height: 58
                        radius: NexaUI.NexaTokens.radiusMd
                        clip: true
                        color: dnd.enabled ? NexaUI.NexaColors.primaryContainer : (dndMouse.containsMouse ? NexaUI.NexaColors.surfaceContainerHighest : NexaUI.NexaColors.surfaceContainerHigh)
                        border.width: NexaUI.NexaTokens.borderThin
                        border.color: dnd.enabled ? NexaUI.NexaColors.primary : NexaUI.NexaColors.border

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
                                    color: dnd.enabled ? NexaUI.NexaColors.onPrimaryContainer : NexaUI.NexaColors.mutedText
                                    font.family: NexaUI.NexaTypography.familyIcon
                                    font.pixelSize: NexaUI.NexaTokens.iconSm
                                }
                            }

                            Text {
                                width: parent.width
                                text: "DND"
                                color: dnd.enabled ? NexaUI.NexaColors.onPrimaryContainer : NexaUI.NexaColors.text
                                elide: Text.ElideRight
                                font.family: NexaUI.NexaTypography.familyBody
                                font.pixelSize: NexaUI.NexaTypography.sizeXs
                                font.weight: Font.DemiBold
                            }

                            Text {
                                width: parent.width
                                text: dnd.enabled ? "On" : "Off"
                                color: dnd.enabled ? NexaUI.NexaColors.onPrimaryContainer : NexaUI.NexaColors.mutedText
                                opacity: 0.8
                                font.family: NexaUI.NexaTypography.familyBody
                                font.pixelSize: 10
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
                        width: (parent.width - NexaUI.NexaTokens.spacingSm) / 2
                        height: 58
                        radius: NexaUI.NexaTokens.radiusMd
                        clip: true
                        color: recorderControl.recording ? NexaUI.NexaColors.primaryContainer : (recMouse.containsMouse ? NexaUI.NexaColors.surfaceContainerHighest : NexaUI.NexaColors.surfaceContainerHigh)
                        border.width: NexaUI.NexaTokens.borderThin
                        border.color: recorderControl.recording ? NexaUI.NexaColors.primary : NexaUI.NexaColors.border

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
                                    color: recorderControl.recording ? NexaUI.NexaColors.onPrimaryContainer : NexaUI.NexaColors.mutedText
                                    font.family: NexaUI.NexaTypography.familyIcon
                                    font.pixelSize: NexaUI.NexaTokens.iconSm
                                }
                            }

                            Text {
                                width: parent.width
                                text: "Recorder"
                                color: recorderControl.recording ? NexaUI.NexaColors.onPrimaryContainer : NexaUI.NexaColors.text
                                font.family: NexaUI.NexaTypography.familyBody
                                font.pixelSize: NexaUI.NexaTypography.sizeXs
                                font.weight: Font.DemiBold
                            }

                            Text {
                                width: parent.width
                                text: recorderControl.statusText
                                color: recorderControl.recording ? NexaUI.NexaColors.onPrimaryContainer : NexaUI.NexaColors.mutedText
                                opacity: 0.8
                                elide: Text.ElideRight
                                font.family: NexaUI.NexaTypography.familyBody
                                font.pixelSize: 10
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
                        width: (parent.width - NexaUI.NexaTokens.spacingSm) / 2
                        height: 58
                        radius: NexaUI.NexaTokens.radiusMd
                        clip: true
                        color: shotMouse.containsMouse ? NexaUI.NexaColors.surfaceContainerHighest : NexaUI.NexaColors.surfaceContainerHigh
                        border.width: NexaUI.NexaTokens.borderThin
                        border.color: NexaUI.NexaColors.border

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
                                    color: NexaUI.NexaColors.mutedText
                                    font.family: NexaUI.NexaTypography.familyIcon
                                    font.pixelSize: NexaUI.NexaTokens.iconSm
                                }
                            }

                            Text {
                                width: parent.width
                                text: "Screenshot"
                                color: NexaUI.NexaColors.text
                                font.family: NexaUI.NexaTypography.familyBody
                                font.pixelSize: NexaUI.NexaTypography.sizeXs
                                font.weight: Font.DemiBold
                            }

                            Text {
                                width: parent.width
                                text: "Capture"
                                color: NexaUI.NexaColors.mutedText
                                opacity: 0.8
                                font.family: NexaUI.NexaTypography.familyBody
                                font.pixelSize: 10
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
                        width: (parent.width - NexaUI.NexaTokens.spacingSm) / 2
                        height: 58
                        radius: NexaUI.NexaTokens.radiusMd
                        clip: true
                        color: clipMouse.containsMouse ? NexaUI.NexaColors.surfaceContainerHighest : NexaUI.NexaColors.surfaceContainerHigh
                        border.width: NexaUI.NexaTokens.borderThin
                        border.color: NexaUI.NexaColors.border

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
                                    color: NexaUI.NexaColors.mutedText
                                    font.family: NexaUI.NexaTypography.familyIcon
                                    font.pixelSize: NexaUI.NexaTokens.iconSm
                                }
                            }

                            Text {
                                width: parent.width
                                text: "Clipboard"
                                color: NexaUI.NexaColors.text
                                font.family: NexaUI.NexaTypography.familyBody
                                font.pixelSize: NexaUI.NexaTypography.sizeXs
                                font.weight: Font.DemiBold
                            }

                            Text {
                                width: parent.width
                                text: "Open"
                                color: NexaUI.NexaColors.mutedText
                                opacity: 0.8
                                font.family: NexaUI.NexaTypography.familyBody
                                font.pixelSize: 10
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

                    // 5. Reading Mode (Study Mode / Paper Texture)
                    Rectangle {
                        width: (parent.width - NexaUI.NexaTokens.spacingSm) / 2
                        height: 58
                        radius: NexaUI.NexaTokens.radiusMd
                        clip: true
                        color: screenFilter.filter === "paper-mode" ? NexaUI.NexaColors.primaryContainer : (readingMouse.containsMouse ? NexaUI.NexaColors.surfaceContainerHighest : NexaUI.NexaColors.surfaceContainerHigh)
                        border.width: NexaUI.NexaTokens.borderThin
                        border.color: screenFilter.filter === "paper-mode" ? NexaUI.NexaColors.primary : NexaUI.NexaColors.border

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
                                    text: "󰈙"
                                    color: screenFilter.filter === "paper-mode" ? NexaUI.NexaColors.onPrimaryContainer : NexaUI.NexaColors.mutedText
                                    font.family: NexaUI.NexaTypography.familyIcon
                                    font.pixelSize: NexaUI.NexaTokens.iconSm
                                }
                            }

                            Text {
                                width: parent.width
                                text: "Reading Mode"
                                color: screenFilter.filter === "paper-mode" ? NexaUI.NexaColors.onPrimaryContainer : NexaUI.NexaColors.text
                                font.family: NexaUI.NexaTypography.familyBody
                                font.pixelSize: NexaUI.NexaTypography.sizeXs
                                font.weight: Font.DemiBold
                            }

                            Text {
                                width: parent.width
                                text: screenFilter.filter === "paper-mode" ? "Paper Texture" : "Off"
                                color: screenFilter.filter === "paper-mode" ? NexaUI.NexaColors.onPrimaryContainer : NexaUI.NexaColors.mutedText
                                opacity: 0.8
                                elide: Text.ElideRight
                                font.family: NexaUI.NexaTypography.familyBody
                                font.pixelSize: 10
                            }
                        }

                        MouseArea {
                            id: readingMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (screenFilter.filter === "paper-mode") {
                                    screenFilter.off()
                                } else {
                                    screenFilter.setFilter("paper-mode")
                                }
                            }
                        }
                    }

                    // 6. Monochrome (Focus Mode / Grayscale)
                    Rectangle {
                        width: (parent.width - NexaUI.NexaTokens.spacingSm) / 2
                        height: 58
                        radius: NexaUI.NexaTokens.radiusMd
                        clip: true
                        color: screenFilter.filter === "grayscale" ? NexaUI.NexaColors.primaryContainer : (focusMouse.containsMouse ? NexaUI.NexaColors.surfaceContainerHighest : NexaUI.NexaColors.surfaceContainerHigh)
                        border.width: NexaUI.NexaTokens.borderThin
                        border.color: screenFilter.filter === "grayscale" ? NexaUI.NexaColors.primary : NexaUI.NexaColors.border

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
                                    text: "󰄲"
                                    color: screenFilter.filter === "grayscale" ? NexaUI.NexaColors.onPrimaryContainer : NexaUI.NexaColors.mutedText
                                    font.family: NexaUI.NexaTypography.familyIcon
                                    font.pixelSize: NexaUI.NexaTokens.iconSm
                                }
                            }

                            Text {
                                width: parent.width
                                text: "Monochrome"
                                color: screenFilter.filter === "grayscale" ? NexaUI.NexaColors.onPrimaryContainer : NexaUI.NexaColors.text
                                font.family: NexaUI.NexaTypography.familyBody
                                font.pixelSize: NexaUI.NexaTypography.sizeXs
                                font.weight: Font.DemiBold
                            }

                            Text {
                                width: parent.width
                                text: screenFilter.filter === "grayscale" ? "Grayscale" : "Off"
                                color: screenFilter.filter === "grayscale" ? NexaUI.NexaColors.onPrimaryContainer : NexaUI.NexaColors.mutedText
                                opacity: 0.8
                                elide: Text.ElideRight
                                font.family: NexaUI.NexaTypography.familyBody
                                font.pixelSize: 10
                            }
                        }

                        MouseArea {
                            id: focusMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (screenFilter.filter === "grayscale") {
                                    screenFilter.off()
                                } else {
                                    screenFilter.setFilter("grayscale")
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
