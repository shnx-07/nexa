import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import "../NewNexaUI" as NexaUI

Item {
    id: root

    property string osdType: "none" // "volume" | "mute" | "brightness" | "airplane" | "battery" | "bluetooth" | "wifi" | "capslock" | "numlock"
    property real value: 0.0        // 0.0 to 1.0
    property bool muted: false
    property bool airplaneEnabled: false
    property string title: ""
    property string subtitle: ""
    property string icon: ""
    property bool batteryCharging: false
    property bool hasInternet: true
    property bool lockEnabled: false

    readonly property real effectiveRadius: {
        if (NexaUI.NexaTokens.islandRounding === 0) return 0;
        return (NexaUI.NexaTokens.islandRounding >= 999)
            ? Math.round(root.height / 2)
            : Math.min(Math.round(root.height / 2), NexaUI.NexaTokens.islandRounding);
    }

    readonly property string iconText: {
        switch (root.osdType) {
        case "volume":
            if (root.muted || root.value <= 0.001) return "󰝟"
            if (root.value > 0.6) return "󰕾"
            if (root.value > 0.2) return "󰖀"
            return "󰕿"
        case "mute":
            return root.muted ? "󰝟" : "󰕾"
        case "mic":
            return root.muted ? "󰍭" : "󰍬"
        case "brightness":
            if (root.value > 0.66) return "󰃠"
            if (root.value > 0.33) return "󰃟"
            return "󰃞"
        case "airplane":
            return root.airplaneEnabled ? "󰀝" : "󰀞"
        case "capslock":
            return "󰬈"
        case "numlock":
            return "󰎤"
        default:
            return ""
        }
    }

    readonly property color iconColor: {
        switch (root.osdType) {
        case "volume":
        case "mute":
        case "mic":
            return root.muted ? NexaUI.NexaColors.error : NexaUI.NexaColors.primary
        case "brightness":
            return NexaUI.NexaColors.warning
        case "airplane":
            return root.airplaneEnabled ? NexaUI.NexaColors.info : NexaUI.NexaColors.mutedText
        case "bluetooth":
            return (root.subtitle === "Turned Off" || root.subtitle === "Disconnected") ? NexaUI.NexaColors.mutedText : NexaUI.NexaColors.info
        case "wifi":
            return root.hasInternet ? NexaUI.NexaColors.info : NexaUI.NexaColors.warning
        case "capslock":
        case "numlock":
            return root.lockEnabled ? NexaUI.NexaColors.success : NexaUI.NexaColors.mutedText
        default:
            return NexaUI.NexaColors.primary
        }
    }

    // ============================================================
    // 1. LIQUID PHYSICS WAVE OSD (VOLUME & BRIGHTNESS)
    // ============================================================

    Item {
        id: liquidOsdContainer
        anchors.fill: parent
        visible: root.osdType === "volume" || root.osdType === "brightness"

        // Smoothed front spring level
        QtObject {
            id: front
            property real target: root.value * liquidOsdContainer.width
            property real value: 0
            property real prevVal: 0

            onTargetChanged: value = target

            Behavior on value {
                SpringAnimation {
                    spring: 3.8
                    damping: 0.34
                    epsilon: 0.2
                }
            }
        }

        // Slosh dynamics
        property real slosh: 0
        property real phase: 0

        NumberAnimation on phase {
            running: liquidOsdContainer.visible
            loops: Animation.Infinite
            from: 0; to: Math.PI * 2
            duration: 2800
        }

        FrameAnimation {
            running: liquidOsdContainer.visible
            onTriggered: {
                const delta = Math.abs(front.value - front.prevVal);
                front.prevVal = front.value;
                const targetSlosh = Math.min(5.5, delta * 0.45);
                liquidOsdContainer.slosh += (targetSlosh - liquidOsdContainer.slosh) * (1.0 - Math.exp(-frameTime * 4.0));
            }
        }

        // GPU Fragment Shader Liquid Wave masked to dynamic island curvature
        ClippingRectangle {
            id: waterClipper
            anchors.fill: parent
            radius: root.effectiveRadius
            color: "transparent"
            z: 0

            Water {
                id: waterWave
                anchors.fill: parent
                axis: 1
                level: Math.max(0, front.value)
                phase1: liquidOsdContainer.phase
                amp1: 1.2 + liquidOsdContainer.slosh
                waves1: 1.15
                phase2: liquidOsdContainer.phase * 1.8
                amp2: liquidOsdContainer.slosh * 0.6
                waves2: 2.1
                nearColor: root.iconColor
                nearAlpha: 0.38
                farColor: root.iconColor
                farAlpha: 0.14
                crestColor: Qt.lighter(root.iconColor, 1.45)
                crestAlpha: 0.88
                crestWidth: 2.0
            }

            // Traveling soft wave-front bloom
            RectangularShadow {
                x: Math.max(-20, front.value - 24)
                y: 0
                width: 48
                height: parent.height
                radius: 24
                blur: 24
                color: Qt.rgba(root.iconColor.r, root.iconColor.g, root.iconColor.b, 0.35)
            }
        }

        // Foreground UI Elements (Above Liquid Surface)
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 16
            spacing: 12
            z: 2

            // Glassmorphic Icon Badge with Sonar Pulse
            IslandTile {
                id: liquidTile
                size: 42
                glyph: root.iconText
                tint: root.iconColor
                sonar: true
                Layout.alignment: Qt.AlignVCenter
            }

            // Category & Source Labels
            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 1

                Text {
                    text: root.osdType === "brightness" ? "Brightness" : "Volume"
                    color: Qt.rgba(255, 255, 255, 0.60)
                    font.family: NexaUI.NexaTypography.familyBody
                    font.pixelSize: 11
                    font.weight: NexaUI.NexaTypography.weightSemiBold
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }

                Text {
                    text: root.osdType === "brightness" ? "Display Backlight" : (root.muted ? "Muted" : "Master Output")
                    color: NexaUI.NexaColors.text
                    font.family: NexaUI.NexaTypography.familyBody
                    font.pixelSize: 13
                    font.weight: NexaUI.NexaTypography.weightBold
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }
            }

            // Odometer Flip Digits
            RollText {
                id: liquidRoll
                text: Math.round(root.value * 100) + "%"
                color: NexaUI.NexaColors.text
                pixelSize: 22
                weight: NexaUI.NexaTypography.weightBold
                rollDuration: 220
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }

    // ============================================================
    // 2. MUTE & MIC LAYOUT
    // ============================================================

    RowLayout {
        id: muteLayout
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 16
        spacing: 12
        visible: root.osdType === "mute" || root.osdType === "mic"

        IslandTile {
            size: 42
            glyph: root.osdType === "mic"
                ? (root.muted ? "󰍭" : "󰍬")
                : (root.muted ? "󰝟" : "󰕾")
            tint: root.muted ? NexaUI.NexaColors.error : NexaUI.NexaColors.primary
            sonar: root.muted
            Layout.alignment: Qt.AlignVCenter
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 1

            Text {
                text: root.osdType === "mic" ? "Microphone" : "Audio Output"
                color: Qt.rgba(255, 255, 255, 0.60)
                font.family: NexaUI.NexaTypography.familyBody
                font.pixelSize: 11
                font.weight: NexaUI.NexaTypography.weightSemiBold
            }

            Text {
                text: root.osdType === "mic"
                    ? (root.muted ? "Microphone Muted" : "Microphone Active")
                    : (root.muted ? "Sound Muted" : "Sound Unmuted")
                color: NexaUI.NexaColors.text
                font.family: NexaUI.NexaTypography.familyBody
                font.pixelSize: 13
                font.weight: NexaUI.NexaTypography.weightBold
            }
        }

        Rectangle {
            height: 24
            implicitWidth: muteBadgeText.implicitWidth + 16
            radius: 12
            color: root.muted
                ? NexaUI.NexaColors.alpha(NexaUI.NexaColors.error, 0.20)
                : NexaUI.NexaColors.alpha(NexaUI.NexaColors.primary, 0.20)
            border.width: NexaUI.NexaTokens.borderThin
            border.color: root.muted ? NexaUI.NexaColors.error : NexaUI.NexaColors.primary
            Layout.alignment: Qt.AlignVCenter

            Text {
                id: muteBadgeText
                anchors.centerIn: parent
                text: root.muted ? "MUTED" : (Math.round(root.value * 100) + "%")
                color: root.muted ? NexaUI.NexaColors.error : NexaUI.NexaColors.primary
                font.family: NexaUI.NexaTypography.familyBody
                font.pixelSize: 10
                font.weight: NexaUI.NexaTypography.weightBold
            }
        }
    }

    // ============================================================
    // 3. AIRPLANE MODE LAYOUT
    // ============================================================

    RowLayout {
        id: airplaneLayout
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 16
        spacing: 12
        visible: root.osdType === "airplane"

        IslandTile {
            size: 42
            glyph: root.airplaneEnabled ? "󰀝" : "󰀞"
            tint: root.airplaneEnabled ? NexaUI.NexaColors.info : NexaUI.NexaColors.mutedText
            sonar: root.airplaneEnabled
            Layout.alignment: Qt.AlignVCenter
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 1

            Text {
                text: "Wireless Radios"
                color: Qt.rgba(255, 255, 255, 0.60)
                font.family: NexaUI.NexaTypography.familyBody
                font.pixelSize: 11
                font.weight: NexaUI.NexaTypography.weightSemiBold
            }

            Text {
                text: "Airplane Mode"
                color: NexaUI.NexaColors.text
                font.family: NexaUI.NexaTypography.familyBody
                font.pixelSize: 13
                font.weight: NexaUI.NexaTypography.weightBold
            }
        }

        Rectangle {
            height: 24
            width: 44
            radius: 12
            color: root.airplaneEnabled ? NexaUI.NexaColors.info : NexaUI.NexaColors.surfaceContainer
            Layout.alignment: Qt.AlignVCenter

            Text {
                anchors.centerIn: parent
                text: root.airplaneEnabled ? "ON" : "OFF"
                color: root.airplaneEnabled ? NexaUI.NexaColors.surface : NexaUI.NexaColors.mutedText
                font.family: NexaUI.NexaTypography.familyBody
                font.pixelSize: 10
                font.bold: true
            }
        }
    }

    // ============================================================
    // 4. BATTERY CHARGER STATUS LAYOUT (APPLE MAGSAFE STYLE)
    // ============================================================

    RowLayout {
        id: batteryChargerLayout
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 16
        spacing: 12
        visible: root.osdType === "battery"

        IslandTile {
            size: 42
            glyph: root.batteryCharging ? "󰂄" : "󰁹"
            tint: root.batteryCharging ? NexaUI.NexaColors.success : NexaUI.NexaColors.primary
            sonar: root.batteryCharging
            Layout.alignment: Qt.AlignVCenter
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 3

            Text {
                text: root.batteryCharging ? "Charging" : "On Battery"
                color: NexaUI.NexaColors.text
                font.family: NexaUI.NexaTypography.familyBody
                font.pixelSize: 13
                font.weight: NexaUI.NexaTypography.weightBold
            }

            NexaUI.NexaProgressBar {
                Layout.fillWidth: true
                implicitHeight: 4
                from: 0.0
                to: 1.0
                value: root.value
                barColor: root.batteryCharging ? NexaUI.NexaColors.success : NexaUI.NexaColors.primary
                trackColor: NexaUI.NexaColors.surfaceContainer
            }
        }

        Rectangle {
            height: 24
            implicitWidth: pctText.implicitWidth + 14
            radius: 12
            color: root.batteryCharging
                ? NexaUI.NexaColors.alpha(NexaUI.NexaColors.success, 0.22)
                : NexaUI.NexaColors.surfaceContainer
            border.width: NexaUI.NexaTokens.borderThin
            border.color: root.batteryCharging
                ? NexaUI.NexaColors.alpha(NexaUI.NexaColors.success, 0.45)
                : NexaUI.NexaColors.border
            Layout.alignment: Qt.AlignVCenter

            Text {
                id: pctText
                anchors.centerIn: parent
                text: Math.round(root.value * 100) + "%"
                color: root.batteryCharging ? NexaUI.NexaColors.success : NexaUI.NexaColors.text
                font.family: NexaUI.NexaTypography.familyBody
                font.pixelSize: 12
                font.weight: NexaUI.NexaTypography.weightBold
                font.features: NexaUI.NexaTypography.fontFeaturesTnum
            }
        }
    }

    // ============================================================
    // 4b. UNIQUE LOW BATTERY ALERT FLAG (< 25%)
    // ============================================================

    RowLayout {
        id: batteryLowLayout
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 16
        spacing: 12
        visible: root.osdType === "battery_low"

        IslandTile {
            size: 42
            glyph: "󰂃"
            tint: NexaUI.NexaColors.error
            sonar: true
            Layout.alignment: Qt.AlignVCenter
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 2

            Text {
                text: "Low Battery"
                color: NexaUI.NexaColors.error
                font.family: NexaUI.NexaTypography.familyBody
                font.pixelSize: 13
                font.weight: NexaUI.NexaTypography.weightBold
                Layout.fillWidth: true
                elide: Text.ElideRight
            }

            Text {
                text: "Connect charger now"
                color: NexaUI.NexaColors.mutedText
                font.family: NexaUI.NexaTypography.familyBody
                font.pixelSize: 11
                Layout.fillWidth: true
                elide: Text.ElideRight
            }
        }

        Rectangle {
            height: 24
            implicitWidth: lowFlagRow.implicitWidth + 16
            radius: 12
            color: NexaUI.NexaColors.alpha(NexaUI.NexaColors.error, 0.22)
            border.width: NexaUI.NexaTokens.borderThin
            border.color: NexaUI.NexaColors.alpha(NexaUI.NexaColors.error, 0.50)
            Layout.alignment: Qt.AlignVCenter

            RowLayout {
                id: lowFlagRow
                anchors.centerIn: parent
                spacing: 5

                Rectangle {
                    width: 6
                    height: 6
                    radius: 3
                    color: NexaUI.NexaColors.error
                    Layout.alignment: Qt.AlignVCenter

                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        running: root.visible && root.osdType === "battery_low"
                        NumberAnimation { to: 0.2; duration: 500 }
                        NumberAnimation { to: 1.0; duration: 500 }
                    }
                }

                Text {
                    text: Math.round(root.value * 100) + "%"
                    color: NexaUI.NexaColors.error
                    font.family: NexaUI.NexaTypography.familyBody
                    font.pixelSize: 12
                    font.weight: NexaUI.NexaTypography.weightBold
                    font.features: NexaUI.NexaTypography.fontFeaturesTnum
                    Layout.alignment: Qt.AlignVCenter
                }
            }
        }
    }

    // ============================================================
    // 5. BLUETOOTH DEVICE CONNECTED LAYOUT
    // ============================================================

    RowLayout {
        id: bluetoothLayout
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 16
        spacing: 12
        visible: root.osdType === "bluetooth"

        IslandTile {
            size: 42
            glyph: root.icon.length > 0 ? root.icon : "󰂯"
            tint: NexaUI.NexaColors.info
            sonar: true
            Layout.alignment: Qt.AlignVCenter
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 2

            Text {
                Layout.fillWidth: true
                text: root.title.length > 0 ? root.title : "Bluetooth Device"
                color: NexaUI.NexaColors.text
                font.family: NexaUI.NexaTypography.familyBody
                font.pixelSize: 13
                font.weight: NexaUI.NexaTypography.weightBold
                elide: Text.ElideRight
            }

            Text {
                text: root.subtitle.length > 0 ? root.subtitle : "Connected"
                color: NexaUI.NexaColors.mutedText
                font.family: NexaUI.NexaTypography.familyBody
                font.pixelSize: 11
                elide: Text.ElideRight
            }
        }

        Rectangle {
            height: 24
            implicitWidth: btSubText.implicitWidth + 14
            radius: 12
            color: NexaUI.NexaColors.alpha(NexaUI.NexaColors.info, 0.18)
            border.width: NexaUI.NexaTokens.borderThin
            border.color: NexaUI.NexaColors.alpha(NexaUI.NexaColors.info, 0.35)
            Layout.alignment: Qt.AlignVCenter

            Text {
                id: btSubText
                anchors.centerIn: parent
                text: root.value > 0 ? (Math.round(root.value * 100) + "%") : "Connected"
                color: NexaUI.NexaColors.info
                font.family: NexaUI.NexaTypography.familyBody
                font.pixelSize: 11
                font.weight: NexaUI.NexaTypography.weightBold
                font.features: NexaUI.NexaTypography.fontFeaturesTnum
            }
        }
    }

    // ============================================================
    // 6. WI-FI CONNECTED / STATUS LAYOUT
    // ============================================================

    Item {
        id: wifiContainer
        anchors.fill: parent
        visible: root.osdType === "wifi"

        RowLayout {
            id: wifiLayout
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 16
            spacing: 12

            IslandTile {
                size: 42
                glyph: root.hasInternet ? "󰤨" : "󰤭"
                tint: root.hasInternet ? NexaUI.NexaColors.info : NexaUI.NexaColors.warning
                sonar: true
                Layout.alignment: Qt.AlignVCenter
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 2

                Text {
                    Layout.fillWidth: true
                    text: root.title.length > 0 ? root.title : "Wi-Fi"
                    color: NexaUI.NexaColors.text
                    font.family: NexaUI.NexaTypography.familyBody
                    font.pixelSize: 13
                    font.weight: NexaUI.NexaTypography.weightBold
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    text: root.hasInternet ? "Connected" : "No Internet"
                    color: root.hasInternet ? NexaUI.NexaColors.mutedText : NexaUI.NexaColors.warning
                    font.family: NexaUI.NexaTypography.familyBody
                    font.pixelSize: 11
                    font.weight: root.hasInternet ? NexaUI.NexaTypography.weightRegular : NexaUI.NexaTypography.weightBold
                    elide: Text.ElideRight
                }
            }

            Rectangle {
                height: 24
                implicitWidth: wifiSignalText.implicitWidth + 14
                radius: 12
                color: root.hasInternet
                    ? NexaUI.NexaColors.alpha(NexaUI.NexaColors.info, 0.18)
                    : NexaUI.NexaColors.alpha(NexaUI.NexaColors.warning, 0.20)
                border.width: NexaUI.NexaTokens.borderThin
                border.color: root.hasInternet
                    ? NexaUI.NexaColors.alpha(NexaUI.NexaColors.info, 0.35)
                    : NexaUI.NexaColors.alpha(NexaUI.NexaColors.warning, 0.45)
                Layout.alignment: Qt.AlignVCenter

                Text {
                    id: wifiSignalText
                    anchors.centerIn: parent
                    text: root.hasInternet
                        ? (root.value > 0 ? (Math.round(root.value * 100) + "%") : "Connected")
                        : "No Internet"
                    color: root.hasInternet ? NexaUI.NexaColors.info : NexaUI.NexaColors.warning
                    font.family: NexaUI.NexaTypography.familyBody
                    font.pixelSize: 11
                    font.weight: NexaUI.NexaTypography.weightBold
                    font.features: NexaUI.NexaTypography.fontFeaturesTnum
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: !root.hasInternet ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: {
                if (!root.hasInternet) {
                    Quickshell.execDetached([
                        "qs",
                        "-p",
                        Quickshell.env("HOME") + "/.config/nexa/quickshell",
                        "call",
                        "sidePanel",
                        "openQuickSettings"
                    ])
                }
            }
        }
    }

    // ============================================================
    // 7. KEYBOARD LOCK LAYOUT (CAPS LOCK / NUM LOCK)
    // ============================================================

    RowLayout {
        id: keyLockLayout
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 16
        spacing: 12
        visible: root.osdType === "capslock" || root.osdType === "numlock"

        IslandTile {
            size: 42
            glyph: root.osdType === "capslock" ? "󰬈" : "󰎤"
            tint: root.lockEnabled ? NexaUI.NexaColors.success : NexaUI.NexaColors.mutedText
            sonar: root.lockEnabled
            Layout.alignment: Qt.AlignVCenter
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 1

            Text {
                text: root.title !== "" ? root.title : (root.osdType === "capslock" ? "Caps Lock" : "Num Lock")
                color: NexaUI.NexaColors.text
                font.family: NexaUI.NexaTypography.familyBody
                font.pixelSize: 13
                font.weight: NexaUI.NexaTypography.weightSemiBold
                Layout.fillWidth: true
                elide: Text.ElideRight
            }

            RowLayout {
                spacing: 5
                Layout.fillWidth: true

                Rectangle {
                    width: 6
                    height: 6
                    radius: 3
                    color: root.lockEnabled ? NexaUI.NexaColors.success : NexaUI.NexaColors.mutedText
                    Layout.alignment: Qt.AlignVCenter
                }

                Text {
                    text: root.lockEnabled ? "On" : "Off"
                    color: root.lockEnabled ? NexaUI.NexaColors.success : NexaUI.NexaColors.mutedText
                    font.family: NexaUI.NexaTypography.familyBody
                    font.pixelSize: 11
                    font.weight: NexaUI.NexaTypography.weightMedium
                    Layout.alignment: Qt.AlignVCenter
                }
            }
        }

        Rectangle {
            width: 44
            height: 24
            radius: 12
            color: root.lockEnabled
                ? NexaUI.NexaColors.alpha(NexaUI.NexaColors.success, 0.18)
                : NexaUI.NexaColors.surfaceContainer
            border.width: NexaUI.NexaTokens.borderThin
            border.color: root.lockEnabled
                ? NexaUI.NexaColors.alpha(NexaUI.NexaColors.success, 0.35)
                : NexaUI.NexaColors.border
            Layout.alignment: Qt.AlignVCenter

            Text {
                anchors.centerIn: parent
                text: root.lockEnabled ? "ON" : "OFF"
                color: root.lockEnabled ? NexaUI.NexaColors.success : NexaUI.NexaColors.mutedText
                font.family: NexaUI.NexaTypography.familyBody
                font.pixelSize: 11
                font.weight: NexaUI.NexaTypography.weightBold
            }
        }
    }
}
