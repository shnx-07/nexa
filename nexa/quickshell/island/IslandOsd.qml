import QtQuick
import QtQuick.Layouts
import "../theme" as Nexa

Item {
    id: root

    property string osdType: "none" // "volume" | "mute" | "brightness" | "airplane"
    property real value: 0.0        // 0.0 to 1.0
    property bool muted: false
    property bool airplaneEnabled: false

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

                Rectangle {
                    id: fillBar
                    height: parent.height
                    width: Math.max(height, Math.min(parent.width, parent.width * root.value))
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
}
