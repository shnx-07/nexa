import QtQuick
import QtQuick.Layouts
import "../NewNexaUI" as NexaUI

Item {
    id: root

    property string osdType: "none" // "volume" | "mute" | "brightness" | "airplane" | "battery" | "bluetooth" | "wifi"
    property real value: 0.0        // 0.0 to 1.0
    property bool muted: false
    property bool airplaneEnabled: false
    property string title: ""
    property string subtitle: ""
    property string icon: ""
    property bool batteryCharging: false
    property bool hasInternet: true
    property bool lockEnabled: false

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
    // 1. GAUGE LAYOUT (VOLUME & BRIGHTNESS)
    // ============================================================

    RowLayout {
        id: gaugeLayout
        anchors.fill: parent
        anchors.leftMargin: NexaUI.NexaTokens.spacingLg
        anchors.rightMargin: NexaUI.NexaTokens.spacingLg
        spacing: NexaUI.NexaTokens.spacingMd
        visible: root.osdType === "volume" || root.osdType === "brightness"

        // Leading Icon
        Text {
            text: root.iconText
            color: root.iconColor
            font.family: NexaUI.NexaTypography.familyIcon
            font.pixelSize: 18
            Layout.alignment: Qt.AlignVCenter
        }

        // Pill Progress Track
        NexaUI.NexaProgressBar {
            Layout.fillWidth: true
            Layout.preferredHeight: 8
            Layout.alignment: Qt.AlignVCenter
            from: 0.0
            to: 1.0
            value: root.value
            barColor: root.iconColor
            trackColor: NexaUI.NexaColors.surfaceContainerHigh
        }

        // Percentage Text
        Text {
            Layout.preferredWidth: 38
            text: Math.round(root.value * 100) + "%"
            color: NexaUI.NexaColors.text
            font.family: NexaUI.NexaTypography.familyBody
            font.pixelSize: NexaUI.NexaTypography.sizeSm
            font.weight: NexaUI.NexaTypography.weightMedium
            font.features: NexaUI.NexaTypography.fontFeaturesTnum
            horizontalAlignment: Text.AlignRight
            Layout.alignment: Qt.AlignVCenter
        }
    }

    // ============================================================
    // 2. MUTE LAYOUT
    // ============================================================

    RowLayout {
        id: muteLayout
        anchors.fill: parent
        anchors.leftMargin: NexaUI.NexaTokens.spacingLg
        anchors.rightMargin: NexaUI.NexaTokens.spacingLg
        spacing: NexaUI.NexaTokens.spacingSm + 2
        visible: root.osdType === "mute" || root.osdType === "mic"

        Rectangle {
            width: 28
            height: 28
            radius: 14
            color: root.muted
                ? NexaUI.NexaColors.alpha(NexaUI.NexaColors.error, 0.18)
                : NexaUI.NexaColors.alpha(NexaUI.NexaColors.primary, 0.18)
            Layout.alignment: Qt.AlignVCenter

            Text {
                anchors.centerIn: parent
                text: root.osdType === "mic"
                    ? (root.muted ? "󰍭" : "󰍬")
                    : (root.muted ? "󰝟" : "󰕾")
                color: root.muted ? NexaUI.NexaColors.error : NexaUI.NexaColors.primary
                font.family: NexaUI.NexaTypography.familyIcon
                font.pixelSize: 16
            }
        }

        Text {
            Layout.fillWidth: true
            text: root.osdType === "mic"
                ? (root.muted ? "Mic Muted" : "Mic Unmuted")
                : (root.muted ? "Audio Muted" : "Audio Unmuted")
            color: NexaUI.NexaColors.text
            font.family: NexaUI.NexaTypography.familyBody
            font.pixelSize: NexaUI.NexaTypography.sizeSm
            font.weight: NexaUI.NexaTypography.weightMedium
            Layout.alignment: Qt.AlignVCenter
        }

        Text {
            text: Math.round(root.value * 100) + "%"
            color: NexaUI.NexaColors.mutedText
            font.family: NexaUI.NexaTypography.familyBody
            font.pixelSize: NexaUI.NexaTypography.sizeXs
            font.features: NexaUI.NexaTypography.fontFeaturesTnum
            Layout.alignment: Qt.AlignVCenter
        }
    }

    // ============================================================
    // 3. AIRPLANE MODE LAYOUT
    // ============================================================

    RowLayout {
        id: airplaneLayout
        anchors.fill: parent
        anchors.leftMargin: NexaUI.NexaTokens.spacingLg
        anchors.rightMargin: 14
        spacing: 10
        visible: root.osdType === "airplane"

        Rectangle {
            width: 28
            height: 28
            radius: 14
            color: root.airplaneEnabled
                ? NexaUI.NexaColors.alpha(NexaUI.NexaColors.info, 0.18)
                : NexaUI.NexaColors.surfaceContainer
            Layout.alignment: Qt.AlignVCenter

            Text {
                anchors.centerIn: parent
                text: root.airplaneEnabled ? "󰀝" : "󰀞"
                color: root.airplaneEnabled ? NexaUI.NexaColors.info : NexaUI.NexaColors.mutedText
                font.family: NexaUI.NexaTypography.familyIcon
                font.pixelSize: 16
            }
        }

        Text {
            Layout.fillWidth: true
            text: "Airplane Mode"
            color: NexaUI.NexaColors.text
            font.family: NexaUI.NexaTypography.familyBody
            font.pixelSize: NexaUI.NexaTypography.sizeSm
            font.weight: NexaUI.NexaTypography.weightMedium
            Layout.alignment: Qt.AlignVCenter
        }

        Rectangle {
            height: 22
            width: 36
            radius: 11
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
        anchors.leftMargin: NexaUI.NexaTokens.spacingLg
        anchors.rightMargin: NexaUI.NexaTokens.spacingLg
        spacing: 12
        visible: root.osdType === "battery"

        // Animated Charging/Battery Icon Badge
        Rectangle {
            width: 28
            height: 28
            radius: 9
            color: root.batteryCharging
                ? NexaUI.NexaColors.alpha(NexaUI.NexaColors.success, 0.20)
                : NexaUI.NexaColors.surfaceContainer
            border.width: NexaUI.NexaTokens.borderThin
            border.color: root.batteryCharging
                ? NexaUI.NexaColors.alpha(NexaUI.NexaColors.success, 0.40)
                : NexaUI.NexaColors.border
            Layout.alignment: Qt.AlignVCenter

            Text {
                anchors.centerIn: parent
                text: root.batteryCharging ? "󰂄" : "󰁹"
                color: root.batteryCharging ? NexaUI.NexaColors.success : NexaUI.NexaColors.text
                font.family: NexaUI.NexaTypography.familyIcon
                font.pixelSize: 16
            }
        }

        // Title + Mini Progress Bar
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

        // Percentage Badge Pill
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
        anchors.leftMargin: NexaUI.NexaTokens.spacingLg
        anchors.rightMargin: NexaUI.NexaTokens.spacingLg
        spacing: 12
        visible: root.osdType === "battery_low"

        // Pulsing Glowing Warning Badge
        Rectangle {
            width: 28
            height: 28
            radius: 9
            color: NexaUI.NexaColors.alpha(NexaUI.NexaColors.error, 0.22)
            border.width: NexaUI.NexaTokens.borderThin
            border.color: NexaUI.NexaColors.alpha(NexaUI.NexaColors.error, 0.60)
            Layout.alignment: Qt.AlignVCenter

            SequentialAnimation on opacity {
                loops: Animation.Infinite
                running: root.visible && root.osdType === "battery_low"
                NumberAnimation { to: 0.45; duration: 700; easing.type: Easing.InOutQuad }
                NumberAnimation { to: 1.0; duration: 700; easing.type: Easing.InOutQuad }
            }

            Text {
                anchors.centerIn: parent
                text: "󰂃"
                color: NexaUI.NexaColors.error
                font.family: NexaUI.NexaTypography.familyIcon
                font.pixelSize: 16
            }
        }

        // Warning Title + Subtitle
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

        // Unique Urgent Flag Pill with Flashing Beacon
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
        anchors.leftMargin: NexaUI.NexaTokens.spacingLg
        anchors.rightMargin: NexaUI.NexaTokens.spacingLg
        spacing: 12
        visible: root.osdType === "bluetooth"

        // Device Icon Badge
        Rectangle {
            width: 28
            height: 28
            radius: 9
            color: NexaUI.NexaColors.alpha(NexaUI.NexaColors.info, 0.18)
            border.width: NexaUI.NexaTokens.borderThin
            border.color: NexaUI.NexaColors.alpha(NexaUI.NexaColors.info, 0.40)
            Layout.alignment: Qt.AlignVCenter

            Text {
                anchors.centerIn: parent
                text: root.icon.length > 0 ? root.icon : "󰂯"
                color: NexaUI.NexaColors.info
                font.family: NexaUI.NexaTypography.familyIcon
                font.pixelSize: 16
            }
        }

        // Device Info
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

        // Status / Battery Pill
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
            anchors.leftMargin: NexaUI.NexaTokens.spacingLg
            anchors.rightMargin: NexaUI.NexaTokens.spacingLg
            spacing: 12

            // Wi-Fi Icon Badge
            Rectangle {
                width: 28
                height: 28
                radius: 9
                color: root.hasInternet
                    ? NexaUI.NexaColors.alpha(NexaUI.NexaColors.info, 0.20)
                    : NexaUI.NexaColors.alpha(NexaUI.NexaColors.warning, 0.22)
                border.width: NexaUI.NexaTokens.borderThin
                border.color: root.hasInternet
                    ? NexaUI.NexaColors.alpha(NexaUI.NexaColors.info, 0.40)
                    : NexaUI.NexaColors.alpha(NexaUI.NexaColors.warning, 0.50)
                Layout.alignment: Qt.AlignVCenter

                Text {
                    anchors.centerIn: parent
                    text: root.hasInternet ? "󰤨" : "󰤭"
                    color: root.hasInternet ? NexaUI.NexaColors.info : NexaUI.NexaColors.warning
                    font.family: NexaUI.NexaTypography.familyIcon
                    font.pixelSize: 16
                }
            }

            // Network Info
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

            // Status / Signal Pill
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
        anchors.rightMargin: 14
        spacing: 10
        visible: root.osdType === "capslock" || root.osdType === "numlock"

        // Leading Key Icon Badge
        Rectangle {
            id: keyBadge
            width: 32
            height: 32
            radius: 9
            color: root.lockEnabled
                ? NexaUI.NexaColors.alpha(NexaUI.NexaColors.success, 0.18)
                : NexaUI.NexaColors.surfaceContainer
            border.width: NexaUI.NexaTokens.borderThin
            border.color: root.lockEnabled
                ? NexaUI.NexaColors.alpha(NexaUI.NexaColors.success, 0.38)
                : NexaUI.NexaColors.border
            Layout.alignment: Qt.AlignVCenter

            Text {
                anchors.centerIn: parent
                text: root.osdType === "capslock" ? "󰬈" : "󰎤"
                color: root.lockEnabled ? NexaUI.NexaColors.success : NexaUI.NexaColors.mutedText
                font.family: NexaUI.NexaTypography.familyIcon
                font.pixelSize: 18
            }
        }

        // Info Text Column
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

        // Trailing Status Pill Badge
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
