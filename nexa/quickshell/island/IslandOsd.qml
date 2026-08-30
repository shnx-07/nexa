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
        default:
            return ""
        }
    }

    readonly property color iconColor: {
        switch (root.osdType) {
        case "volume":
            return root.muted ? Nexa.Theme.error : Nexa.Theme.primary
        case "mute":
            return root.muted ? Nexa.Theme.error : Nexa.Theme.primary
        case "mic":
            return root.muted ? Nexa.Theme.error : Nexa.Theme.primary
        case "brightness":
            return "#f59e0b" // warm amber sun
        case "airplane":
            return root.airplaneEnabled ? "#38bdf8" : Nexa.Theme.mutedText
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
                ? Qt.rgba(239/255, 68/255, 68/255, 0.15)
                : Qt.rgba(59/255, 130/255, 246/255, 0.15)
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
                ? Qt.rgba(56/255, 189/255, 248/255, 0.18)
                : Nexa.Theme.surface
            Layout.alignment: Qt.AlignVCenter

            Text {
                anchors.centerIn: parent
                text: root.airplaneEnabled ? "󰀝" : "󰀞"
                color: root.airplaneEnabled ? "#38bdf8" : Nexa.Theme.mutedText
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
            color: root.airplaneEnabled ? "#38bdf8" : Nexa.Theme.surface
            Layout.alignment: Qt.AlignVCenter

            Text {
                anchors.centerIn: parent
                text: root.airplaneEnabled ? "ON" : "OFF"
                color: root.airplaneEnabled ? "#0f172a" : Nexa.Theme.mutedText
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
        id: batteryLayout
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        spacing: 12
        visible: root.osdType === "battery"

        // Glowing Apple-style Battery/Bolt Badge
        Rectangle {
            width: 28
            height: 28
            radius: 9
            color: root.batteryCharging
                ? Qt.rgba(34/255, 197/255, 94/255, 0.20)
                : Qt.rgba(255/255, 255/255, 255/255, 0.10)
            border.width: Nexa.Theme.borderThin
            border.color: root.batteryCharging
                ? Qt.rgba(34/255, 197/255, 94/255, 0.40)
                : Nexa.Theme.border
            Layout.alignment: Qt.AlignVCenter

            Text {
                anchors.centerIn: parent
                text: root.batteryCharging ? "󰂄" : "󰁹"
                color: root.batteryCharging ? "#22c55e" : Nexa.Theme.text
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
                color: Nexa.Theme.surface
                clip: true

                Rectangle {
                    height: parent.height
                    width: Math.max(0, Math.min(parent.width, parent.width * Math.min(1.0, Math.max(0.0, root.value))))
                    radius: 2
                    color: root.batteryCharging ? "#22c55e" : Nexa.Theme.primary
                }
            }
        }

        // Percentage Badge Pill
        Rectangle {
            height: 24
            implicitWidth: pctText.implicitWidth + 14
            radius: 12
            color: root.batteryCharging
                ? Qt.rgba(34/255, 197/255, 94/255, 0.22)
                : Nexa.Theme.surface
            border.width: Nexa.Theme.borderThin
            border.color: root.batteryCharging
                ? Qt.rgba(34/255, 197/255, 94/255, 0.45)
                : Nexa.Theme.border
            Layout.alignment: Qt.AlignVCenter

            Text {
                id: pctText
                anchors.centerIn: parent
                text: Math.round(root.value * 100) + "%"
                color: root.batteryCharging ? "#22c55e" : Nexa.Theme.text
                font.family: Nexa.Theme.fontFamily
                font.pixelSize: 12
                font.weight: Nexa.Theme.fontWeightBold
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
            color: Qt.rgba(59/255, 130/255, 246/255, 0.20)
            border.width: Nexa.Theme.borderThin
            border.color: Qt.rgba(59/255, 130/255, 246/255, 0.40)
            Layout.alignment: Qt.AlignVCenter

            Text {
                anchors.centerIn: parent
                text: root.icon.length > 0 ? root.icon : "󰂯"
                color: "#3b82f6"
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
            color: Qt.rgba(59/255, 130/255, 246/255, 0.18)
            border.width: Nexa.Theme.borderThin
            border.color: Qt.rgba(59/255, 130/255, 246/255, 0.35)
            Layout.alignment: Qt.AlignVCenter

            Text {
                id: btSubText
                anchors.centerIn: parent
                text: root.value > 0 ? (Math.round(root.value * 100) + "%") : "Connected"
                color: "#3b82f6"
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

            // Wi-Fi Icon Badge (Cyan for OK, Amber/Warning for No Internet)
            Rectangle {
                width: 28
                height: 28
                radius: 9
                color: root.hasInternet
                    ? Qt.rgba(56/255, 189/255, 248/255, 0.20)
                    : Qt.rgba(245/255, 158/255, 11/255, 0.22)
                border.width: Nexa.Theme.borderThin
                border.color: root.hasInternet
                    ? Qt.rgba(56/255, 189/255, 248/255, 0.40)
                    : Qt.rgba(245/255, 158/255, 11/255, 0.50)
                Layout.alignment: Qt.AlignVCenter

                Text {
                    anchors.centerIn: parent
                    text: root.hasInternet ? "󰤨" : "󰤭"
                    color: root.hasInternet ? "#38bdf8" : "#f59e0b"
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
                    color: root.hasInternet ? Nexa.Theme.mutedText : "#f59e0b"
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
                    ? Qt.rgba(56/255, 189/255, 248/255, 0.18)
                    : Qt.rgba(245/255, 158/255, 11/255, 0.20)
                border.width: Nexa.Theme.borderThin
                border.color: root.hasInternet
                    ? Qt.rgba(56/255, 189/255, 248/255, 0.35)
                    : Qt.rgba(245/255, 158/255, 11/255, 0.45)
                Layout.alignment: Qt.AlignVCenter

                Text {
                    id: wifiSignalText
                    anchors.centerIn: parent
                    text: root.hasInternet
                        ? (root.value > 0 ? (Math.round(root.value * 100) + "%") : "Connected")
                        : "No Internet"
                    color: root.hasInternet ? "#38bdf8" : "#f59e0b"
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
}
