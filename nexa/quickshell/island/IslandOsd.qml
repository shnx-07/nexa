import QtQuick
import QtQuick.Layouts
import "../theme" as Nexa

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
            return root.muted ? Nexa.Theme.error : Nexa.Theme.primary
        case "brightness":
            return Nexa.Theme.warning
        case "airplane":
            return root.airplaneEnabled ? Nexa.Theme.info : Nexa.Theme.mutedText
        case "capslock":
        case "numlock":
            return root.lockEnabled ? Nexa.Theme.success : Nexa.Theme.mutedText
        default:
            return Nexa.Theme.primary
        }
    }

    // ============================================================
    // 1. GAUGE LAYOUT (VOLUME & BRIGHTNESS)
    // ============================================================

    RowLayout {
        id: gaugeLayout
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        spacing: 12
        visible: root.osdType === "volume" || root.osdType === "brightness"

        // Leading Icon
        Text {
            text: root.iconText
            color: root.iconColor
            font.family: Nexa.Theme.iconFontFamily
            font.pixelSize: 18
            Layout.alignment: Qt.AlignVCenter
        }

        // Pill Progress Track
        Item {
            id: trackContainer
            Layout.fillWidth: true
            Layout.preferredHeight: 8
            Layout.alignment: Qt.AlignVCenter

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: Nexa.Theme.surface
                border.width: Nexa.Theme.borderThin
                border.color: Nexa.Theme.border
                clip: true

                Rectangle {
                    id: fillBar
                    height: parent.height
                    width: Math.max(0, Math.min(parent.width, parent.width * Math.min(1.0, Math.max(0.0, root.value))))
                    radius: height / 2
                    color: root.iconColor

                    Behavior on width {
                        NumberAnimation {
                            duration: Nexa.Theme.animationFast
                            easing.type: Easing.OutQuad
                        }
                    }

                    Behavior on color {
                        ColorAnimation {
                            duration: Nexa.Theme.animationFast
                        }
                    }
                }
            }
        }

        // Percentage Text
        Text {
            Layout.preferredWidth: 38
            text: Math.round(root.value * 100) + "%"
            color: Nexa.Theme.text
            font.family: Nexa.Theme.fontFamily
            font.pixelSize: Nexa.Theme.fontSizeSm
            font.weight: Nexa.Theme.fontWeightMedium
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
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        spacing: 10
        visible: root.osdType === "mute" || root.osdType === "mic"

        Rectangle {
            width: 28
            height: 28
            radius: 14
            color: root.muted
                ? Qt.rgba(Nexa.Theme.error.r, Nexa.Theme.error.g, Nexa.Theme.error.b, 0.18)
                : Qt.rgba(Nexa.Theme.primary.r, Nexa.Theme.primary.g, Nexa.Theme.primary.b, 0.18)
            Layout.alignment: Qt.AlignVCenter

            Text {
                anchors.centerIn: parent
                text: root.osdType === "mic"
                    ? (root.muted ? "󰍭" : "󰍬")
                    : (root.muted ? "󰝟" : "󰕾")
                color: root.muted ? Nexa.Theme.error : Nexa.Theme.primary
                font.family: Nexa.Theme.iconFontFamily
                font.pixelSize: 16
            }
        }

        Text {
            Layout.fillWidth: true
            text: root.osdType === "mic"
                ? (root.muted ? "Mic Muted" : "Mic Unmuted")
                : (root.muted ? "Audio Muted" : "Audio Unmuted")
            color: Nexa.Theme.text
            font.family: Nexa.Theme.fontFamily
            font.pixelSize: Nexa.Theme.fontSizeSm
            font.weight: Nexa.Theme.fontWeightMedium
            Layout.alignment: Qt.AlignVCenter
        }

        Text {
            text: Math.round(root.value * 100) + "%"
            color: Nexa.Theme.mutedText
            font.family: Nexa.Theme.fontFamily
            font.pixelSize: Nexa.Theme.fontSizeXs
            Layout.alignment: Qt.AlignVCenter
        }
    }

    // ============================================================
    // 3. AIRPLANE MODE LAYOUT
    // ============================================================

    RowLayout {
        id: airplaneLayout
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 14
        spacing: 10
        visible: root.osdType === "airplane"

        Rectangle {
            width: 28
            height: 28
            radius: 14
            color: root.airplaneEnabled
                ? Qt.rgba(Nexa.Theme.info.r, Nexa.Theme.info.g, Nexa.Theme.info.b, 0.18)
                : Nexa.Theme.surfaceContainer
            Layout.alignment: Qt.AlignVCenter

            Text {
                anchors.centerIn: parent
                text: root.airplaneEnabled ? "󰀝" : "󰀞"
                color: root.airplaneEnabled ? Nexa.Theme.info : Nexa.Theme.mutedText
                font.family: Nexa.Theme.iconFontFamily
                font.pixelSize: 16
            }
        }

        Text {
            Layout.fillWidth: true
            text: "Airplane Mode"
            color: Nexa.Theme.text
            font.family: Nexa.Theme.fontFamily
            font.pixelSize: Nexa.Theme.fontSizeSm
            font.weight: Nexa.Theme.fontWeightMedium
            Layout.alignment: Qt.AlignVCenter
        }

        Rectangle {
            height: 22
            width: 36
            radius: 11
            color: root.airplaneEnabled ? Nexa.Theme.info : Nexa.Theme.surfaceContainer
            Layout.alignment: Qt.AlignVCenter

            Text {
                anchors.centerIn: parent
                text: root.airplaneEnabled ? "ON" : "OFF"
                color: root.airplaneEnabled ? Nexa.Theme.surface : Nexa.Theme.mutedText
                font.family: Nexa.Theme.fontFamily
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
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        spacing: 12
        visible: root.osdType === "battery"

        // Animated Charging/Battery Icon Badge
        Rectangle {
            width: 28
            height: 28
            radius: 9
            color: root.batteryCharging
                ? Qt.rgba(Nexa.Theme.success.r, Nexa.Theme.success.g, Nexa.Theme.success.b, 0.20)
                : Nexa.Theme.surfaceContainer
            border.width: Nexa.Theme.borderThin
            border.color: root.batteryCharging
                ? Qt.rgba(Nexa.Theme.success.r, Nexa.Theme.success.g, Nexa.Theme.success.b, 0.40)
                : Nexa.Theme.border
            Layout.alignment: Qt.AlignVCenter

            Text {
                anchors.centerIn: parent
                text: root.batteryCharging ? "󰂄" : "󰁹"
                color: root.batteryCharging ? Nexa.Theme.success : Nexa.Theme.text
                font.family: Nexa.Theme.iconFontFamily
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
                color: Nexa.Theme.text
                font.family: Nexa.Theme.fontFamily
                font.pixelSize: 13
                font.weight: Nexa.Theme.fontWeightBold
            }

            Rectangle {
                Layout.fillWidth: true
                height: 4
                radius: 2
                color: Nexa.Theme.surfaceContainer
                clip: true

                Rectangle {
                    height: parent.height
                    width: Math.max(0, Math.min(parent.width, parent.width * Math.min(1.0, Math.max(0.0, root.value))))
                    radius: 2
                    color: root.batteryCharging ? Nexa.Theme.success : Nexa.Theme.primary
                }
            }
        }

        // Percentage Badge Pill
        Rectangle {
            height: 24
            implicitWidth: pctText.implicitWidth + 14
            radius: 12
            color: root.batteryCharging
                ? Qt.rgba(Nexa.Theme.success.r, Nexa.Theme.success.g, Nexa.Theme.success.b, 0.22)
                : Nexa.Theme.surfaceContainer
            border.width: Nexa.Theme.borderThin
            border.color: root.batteryCharging
                ? Qt.rgba(Nexa.Theme.success.r, Nexa.Theme.success.g, Nexa.Theme.success.b, 0.45)
                : Nexa.Theme.border
            Layout.alignment: Qt.AlignVCenter

            Text {
                id: pctText
                anchors.centerIn: parent
                text: Math.round(root.value * 100) + "%"
                color: root.batteryCharging ? Nexa.Theme.success : Nexa.Theme.text
                font.family: Nexa.Theme.fontFamily
                font.pixelSize: 12
                font.weight: Nexa.Theme.fontWeightBold
            }
        }
    }

    // ============================================================
    // 4b. UNIQUE LOW BATTERY ALERT FLAG (< 25%)
    // ============================================================

    RowLayout {
        id: batteryLowLayout
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        spacing: 12
        visible: root.osdType === "battery_low"

        // Pulsing Glowing Warning Badge
        Rectangle {
            width: 28
            height: 28
            radius: 9
            color: Qt.rgba(Nexa.Theme.error.r, Nexa.Theme.error.g, Nexa.Theme.error.b, 0.22)
            border.width: Nexa.Theme.borderThin
            border.color: Qt.rgba(Nexa.Theme.error.r, Nexa.Theme.error.g, Nexa.Theme.error.b, 0.60)
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
                color: Nexa.Theme.error
                font.family: Nexa.Theme.iconFontFamily
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
                color: Nexa.Theme.error
                font.family: Nexa.Theme.fontFamily
                font.pixelSize: 13
                font.weight: Nexa.Theme.fontWeightBold
                Layout.fillWidth: true
                elide: Text.ElideRight
            }

            Text {
                text: "Connect charger now"
                color: Nexa.Theme.mutedText
                font.family: Nexa.Theme.fontFamily
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
            color: Qt.rgba(Nexa.Theme.error.r, Nexa.Theme.error.g, Nexa.Theme.error.b, 0.22)
            border.width: Nexa.Theme.borderThin
            border.color: Qt.rgba(Nexa.Theme.error.r, Nexa.Theme.error.g, Nexa.Theme.error.b, 0.50)
            Layout.alignment: Qt.AlignVCenter

            RowLayout {
                id: lowFlagRow
                anchors.centerIn: parent
                spacing: 5

                Rectangle {
                    width: 6
                    height: 6
                    radius: 3
                    color: Nexa.Theme.error
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
                    color: Nexa.Theme.error
                    font.family: Nexa.Theme.fontFamily
                    font.pixelSize: 12
                    font.weight: Nexa.Theme.fontWeightBold
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
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        spacing: 12
        visible: root.osdType === "bluetooth"

        // Device Icon Badge
        Rectangle {
            width: 28
            height: 28
            radius: 9
            color: Qt.rgba(Nexa.Theme.info.r, Nexa.Theme.info.g, Nexa.Theme.info.b, 0.18)
            border.width: Nexa.Theme.borderThin
            border.color: Qt.rgba(Nexa.Theme.info.r, Nexa.Theme.info.g, Nexa.Theme.info.b, 0.40)
            Layout.alignment: Qt.AlignVCenter

            Text {
                anchors.centerIn: parent
                text: root.icon.length > 0 ? root.icon : "󰂯"
                color: Nexa.Theme.info
                font.family: Nexa.Theme.iconFontFamily
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
                color: Nexa.Theme.text
                font.family: Nexa.Theme.fontFamily
                font.pixelSize: 13
                font.weight: Nexa.Theme.fontWeightBold
                elide: Text.ElideRight
            }

            Text {
                text: root.subtitle.length > 0 ? root.subtitle : "Connected"
                color: Nexa.Theme.mutedText
                font.family: Nexa.Theme.fontFamily
                font.pixelSize: 11
                elide: Text.ElideRight
            }
        }

        // Status / Battery Pill
        Rectangle {
            height: 24
            implicitWidth: btSubText.implicitWidth + 14
            radius: 12
            color: Qt.rgba(Nexa.Theme.info.r, Nexa.Theme.info.g, Nexa.Theme.info.b, 0.18)
            border.width: Nexa.Theme.borderThin
            border.color: Qt.rgba(Nexa.Theme.info.r, Nexa.Theme.info.g, Nexa.Theme.info.b, 0.35)
            Layout.alignment: Qt.AlignVCenter

            Text {
                id: btSubText
                anchors.centerIn: parent
                text: root.value > 0 ? (Math.round(root.value * 100) + "%") : "Connected"
                color: Nexa.Theme.info
                font.family: Nexa.Theme.fontFamily
                font.pixelSize: 11
                font.weight: Nexa.Theme.fontWeightBold
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
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            spacing: 12

            // Wi-Fi Icon Badge
            Rectangle {
                width: 28
                height: 28
                radius: 9
                color: root.hasInternet
                    ? Qt.rgba(Nexa.Theme.info.r, Nexa.Theme.info.g, Nexa.Theme.info.b, 0.20)
                    : Qt.rgba(Nexa.Theme.warning.r, Nexa.Theme.warning.g, Nexa.Theme.warning.b, 0.22)
                border.width: Nexa.Theme.borderThin
                border.color: root.hasInternet
                    ? Qt.rgba(Nexa.Theme.info.r, Nexa.Theme.info.g, Nexa.Theme.info.b, 0.40)
                    : Qt.rgba(Nexa.Theme.warning.r, Nexa.Theme.warning.g, Nexa.Theme.warning.b, 0.50)
                Layout.alignment: Qt.AlignVCenter

                Text {
                    anchors.centerIn: parent
                    text: root.hasInternet ? "󰤨" : "󰤭"
                    color: root.hasInternet ? Nexa.Theme.info : Nexa.Theme.warning
                    font.family: Nexa.Theme.iconFontFamily
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
                    color: Nexa.Theme.text
                    font.family: Nexa.Theme.fontFamily
                    font.pixelSize: 13
                    font.weight: Font.Bold
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    text: root.hasInternet ? "Connected" : "No Internet"
                    color: root.hasInternet ? Nexa.Theme.mutedText : Nexa.Theme.warning
                    font.family: Nexa.Theme.fontFamily
                    font.pixelSize: 11
                    font.weight: root.hasInternet ? Font.Normal : Font.Bold
                    elide: Text.ElideRight
                }
            }

            // Status / Signal Pill
            Rectangle {
                height: 24
                implicitWidth: wifiSignalText.implicitWidth + 14
                radius: 12
                color: root.hasInternet
                    ? Qt.rgba(Nexa.Theme.info.r, Nexa.Theme.info.g, Nexa.Theme.info.b, 0.18)
                    : Qt.rgba(Nexa.Theme.warning.r, Nexa.Theme.warning.g, Nexa.Theme.warning.b, 0.20)
                border.width: Nexa.Theme.borderThin
                border.color: root.hasInternet
                    ? Qt.rgba(Nexa.Theme.info.r, Nexa.Theme.info.g, Nexa.Theme.info.b, 0.35)
                    : Qt.rgba(Nexa.Theme.warning.r, Nexa.Theme.warning.g, Nexa.Theme.warning.b, 0.45)
                Layout.alignment: Qt.AlignVCenter

                Text {
                    id: wifiSignalText
                    anchors.centerIn: parent
                    text: root.hasInternet
                        ? (root.value > 0 ? (Math.round(root.value * 100) + "%") : "Connected")
                        : "No Internet"
                    color: root.hasInternet ? Nexa.Theme.info : Nexa.Theme.warning
                    font.family: Nexa.Theme.fontFamily
                    font.pixelSize: 11
                    font.weight: Font.Bold
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
                ? Qt.rgba(Nexa.Theme.success.r, Nexa.Theme.success.g, Nexa.Theme.success.b, 0.18)
                : Nexa.Theme.surfaceContainer
            border.width: Nexa.Theme.borderThin
            border.color: root.lockEnabled
                ? Qt.rgba(Nexa.Theme.success.r, Nexa.Theme.success.g, Nexa.Theme.success.b, 0.38)
                : Nexa.Theme.border
            Layout.alignment: Qt.AlignVCenter

            Text {
                anchors.centerIn: parent
                text: root.osdType === "capslock" ? "󰬈" : "󰎤"
                color: root.lockEnabled ? Nexa.Theme.success : Nexa.Theme.mutedText
                font.family: Nexa.Theme.iconFontFamily
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
                color: Nexa.Theme.text
                font.family: Nexa.Theme.fontFamily
                font.pixelSize: 13
                font.weight: Font.DemiBold
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
                    color: root.lockEnabled ? Nexa.Theme.success : Nexa.Theme.mutedText
                    Layout.alignment: Qt.AlignVCenter
                }

                Text {
                    text: root.lockEnabled ? "On" : "Off"
                    color: root.lockEnabled ? Nexa.Theme.success : Nexa.Theme.mutedText
                    font.family: Nexa.Theme.fontFamily
                    font.pixelSize: 11
                    font.weight: Font.Medium
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
                ? Qt.rgba(Nexa.Theme.success.r, Nexa.Theme.success.g, Nexa.Theme.success.b, 0.18)
                : Nexa.Theme.surfaceContainer
            border.width: Nexa.Theme.borderThin
            border.color: root.lockEnabled
                ? Qt.rgba(Nexa.Theme.success.r, Nexa.Theme.success.g, Nexa.Theme.success.b, 0.35)
                : Nexa.Theme.border
            Layout.alignment: Qt.AlignVCenter

            Text {
                anchors.centerIn: parent
                text: root.lockEnabled ? "ON" : "OFF"
                color: root.lockEnabled ? Nexa.Theme.success : Nexa.Theme.mutedText
                font.family: Nexa.Theme.fontFamily
                font.pixelSize: 11
                font.weight: Font.Bold
            }
        }
    }
}
