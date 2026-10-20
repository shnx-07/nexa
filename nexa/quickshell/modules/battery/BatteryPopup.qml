import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import "../../theme" as Nexa

PopupWindow {
    id: root
    property Item anchorItem
    property string currentProfile: "balanced"

    readonly property var battery: UPower.displayDevice
    readonly property var physicalBattery: {
        for (let i = 0; i < UPower.devices.values.length; i++) {
            if (UPower.devices.values[i].isLaptopBattery) return UPower.devices.values[i]
        }
        return null
    }

    readonly property int percent: (battery && battery.ready) ? Math.round(battery.percentage * 100) : 0
    readonly property bool charging: battery && battery.ready && !UPower.onBattery
    readonly property real watts: battery && battery.ready ? Math.abs(battery.changeRate) : 0
    readonly property real health: (physicalBattery && physicalBattery.healthSupported) ? physicalBattery.capacity : 100

    property real animatedPercent: 0
    Behavior on animatedPercent {
        NumberAnimation { duration: Nexa.Theme.animationSlow; easing.type: Nexa.Theme.easingStandard }
    }

    onPercentChanged: animatedPercent = percent
    Component.onCompleted: animatedPercent = percent

    function formatTime(seconds) {
        if (!seconds || seconds <= 0) return "—"
        const h = Math.floor(seconds / 3600)
        const m = Math.floor((seconds % 3600) / 60)
        return h > 0 ? (h + "h " + m + "m") : (m + "m")
    }

    function setProfile(profile) {
        currentProfile = profile
        powerProfileProcess.command = ["powerprofilesctl", "set", profile]
        powerProfileProcess.running = true
    }

    function fetchProfile() {
        getProfileProcess.command = ["powerprofilesctl", "get"]
        getProfileProcess.running = true
    }

    Process {
        id: powerProfileProcess
        onExited: root.fetchProfile()
    }

    Process {
        id: getProfileProcess
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                const p = data.trim()
                if (p) root.currentProfile = p
            }
        }
    }

    onVisibleChanged: {
        if (visible) fetchProfile()
    }

    anchor.item: anchorItem
    anchor.window: anchorItem ? anchorItem.QsWindow.window : null
    anchor.edges: Edges.Bottom | Edges.Right
    anchor.gravity: Edges.Bottom | Edges.Right

    implicitWidth: 340
    implicitHeight: 420
    color: "transparent"

    Rectangle {
        id: panel
        anchors.fill: parent
        radius: Nexa.Theme.radiusLg
        color: Nexa.Theme.panelBackground
        border.width: Nexa.Theme.borderThin
        border.color: Nexa.Theme.border
        scale: root.visible ? Nexa.Theme.normalScale : 0.97
        opacity: root.visible ? Nexa.Theme.opacityFull : Nexa.Theme.opacityHidden
        transformOrigin: Item.TopRight

        Behavior on scale { NumberAnimation { duration: Nexa.Theme.animationNormal; easing.type: Nexa.Theme.easingEnter } }
        Behavior on opacity { NumberAnimation { duration: Nexa.Theme.animationFast; easing.type: Nexa.Theme.easingEnter } }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Nexa.Theme.spacingMd
            spacing: Nexa.Theme.spacingSm

            // Section 1: Battery Status & Half Arc
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 190
                radius: Nexa.Theme.radiusMd
                color: Nexa.Theme.surfaceContainerHigh
                border.width: Nexa.Theme.borderThin
                border.color: Nexa.Theme.border

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Nexa.Theme.spacingMd
                    spacing: Nexa.Theme.spacingXs

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 112

                        Canvas {
                            id: arc
                            anchors.centerIn: parent
                            width: 210
                            height: 105

                            onPaint: {
                                const ctx = getContext("2d")
                                ctx.clearRect(0, 0, width, height)
                                const x = width / 2
                                const y = height - 5
                                const r = 78

                                ctx.beginPath()
                                ctx.arc(x, y, r, Math.PI, Math.PI * 2)
                                ctx.lineWidth = 10
                                ctx.lineCap = "round"
                                ctx.strokeStyle = Nexa.Theme.surfaceContainerHighest
                                ctx.stroke()

                                ctx.beginPath()
                                ctx.arc(x, y, r, Math.PI, Math.PI + Math.PI * root.animatedPercent / 100)
                                ctx.lineWidth = 10
                                ctx.lineCap = "round"
                                ctx.strokeStyle = root.charging ? Nexa.Theme.success : (root.percent <= 15 ? Nexa.Theme.error : (root.percent <= 30 ? Nexa.Theme.warning : Nexa.Theme.primary))
                                ctx.stroke()
                            }

                            Connections {
                                target: root
                                function onAnimatedPercentChanged() { arc.requestPaint() }
                                function onPercentChanged() { arc.requestPaint() }
                                function onChargingChanged() { arc.requestPaint() }
                            }
                        }

                        Column {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: parent.top
                            anchors.topMargin: 38
                            spacing: 1

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: root.percent + "%"
                                color: Nexa.Theme.text
                                font.family: Nexa.Theme.fontFamily
                                font.pixelSize: 28
                                font.weight: Nexa.Theme.fontWeightBold
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: root.charging ? "Charging" : "On battery"
                                color: root.charging ? Nexa.Theme.success : Nexa.Theme.mutedText
                                font.family: Nexa.Theme.fontFamily
                                font.pixelSize: Nexa.Theme.fontSizeXs
                                font.weight: Nexa.Theme.fontWeightMedium
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Nexa.Theme.spacingSm

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 48
                            radius: Nexa.Theme.radiusSm
                            color: Nexa.Theme.surfaceContainerHighest

                            Column {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: Nexa.Theme.spacingSm
                                spacing: 1

                                Text { text: root.charging ? "Until full" : "Remaining"; color: Nexa.Theme.mutedText; font.family: Nexa.Theme.fontFamily; font.pixelSize: Nexa.Theme.fontSize2Xs }
                                Text { text: root.charging ? root.formatTime(root.battery ? root.battery.timeToFull : 0) : root.formatTime(root.battery ? root.battery.timeToEmpty : 0); color: Nexa.Theme.text; font.family: Nexa.Theme.fontFamily; font.pixelSize: Nexa.Theme.fontSizeSm; font.weight: Nexa.Theme.fontWeightDemiBold }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 48
                            radius: Nexa.Theme.radiusSm
                            color: Nexa.Theme.surfaceContainerHighest

                            Column {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: Nexa.Theme.spacingSm
                                spacing: 1

                                Text { text: root.charging ? "Charge rate" : "Power draw"; color: Nexa.Theme.mutedText; font.family: Nexa.Theme.fontFamily; font.pixelSize: Nexa.Theme.fontSize2Xs }
                                Text { text: root.watts > 0 ? (root.watts.toFixed(1) + " W") : "—"; color: Nexa.Theme.text; font.family: Nexa.Theme.fontFamily; font.pixelSize: Nexa.Theme.fontSizeSm; font.weight: Nexa.Theme.fontWeightDemiBold }
                            }
                        }
                    }
                }
            }

            // Section 2: Power Profile
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 94
                radius: Nexa.Theme.radiusMd
                color: Nexa.Theme.surfaceContainerHigh
                border.width: Nexa.Theme.borderThin
                border.color: Nexa.Theme.border

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Nexa.Theme.spacingMd
                    spacing: Nexa.Theme.spacingSm

                    Text { text: "Power Profile"; color: Nexa.Theme.text; font.family: Nexa.Theme.fontFamily; font.pixelSize: Nexa.Theme.fontSizeSm; font.weight: Nexa.Theme.fontWeightDemiBold }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Nexa.Theme.spacingXs

                        Repeater {
                            model: [["Saver", "power-saver"], ["Balanced", "balanced"], ["Performance", "performance"]]
                            delegate: Rectangle {
                                id: profileButton
                                required property var modelData
                                readonly property bool selected: root.currentProfile === modelData[1]

                                Layout.fillWidth: true
                                implicitHeight: Nexa.Theme.controlHeightMd
                                radius: Nexa.Theme.radiusSm
                                color: selected ? Nexa.Theme.selected : (profileMouse.containsMouse ? Nexa.Theme.hoverStrong : Nexa.Theme.surfaceContainerHighest)
                                scale: profileMouse.pressed ? Nexa.Theme.pressScale : Nexa.Theme.normalScale

                                Behavior on color { ColorAnimation { duration: Nexa.Theme.animationFast } }
                                Behavior on scale { NumberAnimation { duration: Nexa.Theme.animationFast; easing.type: Nexa.Theme.easingStandard } }

                                Text {
                                    anchors.centerIn: parent
                                    text: profileButton.modelData[0]
                                    color: profileButton.selected ? Nexa.Theme.selectedText : Nexa.Theme.text
                                    font.family: Nexa.Theme.fontFamily
                                    font.pixelSize: Nexa.Theme.fontSizeXs
                                    font.weight: Nexa.Theme.fontWeightMedium
                                }

                                MouseArea {
                                    id: profileMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.setProfile(profileButton.modelData[1])
                                }
                            }
                        }
                    }
                }
            }

            // Section 3: Battery Health
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Nexa.Theme.radiusMd
                color: Nexa.Theme.surfaceContainerHigh
                border.width: Nexa.Theme.borderThin
                border.color: Nexa.Theme.border

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Nexa.Theme.spacingMd
                    spacing: Nexa.Theme.spacingSm

                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "Battery Health"; color: Nexa.Theme.text; font.family: Nexa.Theme.fontFamily; font.pixelSize: Nexa.Theme.fontSizeSm; font.weight: Nexa.Theme.fontWeightDemiBold }
                        Item { Layout.fillWidth: true }
                        Text { text: (root.physicalBattery && root.physicalBattery.healthSupported) ? (Math.round(root.health) + "%") : "Unavailable"; color: Nexa.Theme.mutedText; font.family: Nexa.Theme.fontFamily; font.pixelSize: Nexa.Theme.fontSizeSm; font.weight: Nexa.Theme.fontWeightDemiBold }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 10
                        radius: Nexa.Theme.radiusPill
                        color: Nexa.Theme.surfaceContainerHighest

                        Rectangle {
                            height: parent.height
                            width: (root.physicalBattery && root.physicalBattery.healthSupported) ? (parent.width * Math.min(1, Math.max(0, root.health / 100))) : 0
                            radius: parent.radius
                            color: root.health >= 80 ? Nexa.Theme.success : (root.health >= 60 ? Nexa.Theme.warning : Nexa.Theme.error)
                            Behavior on width { NumberAnimation { duration: Nexa.Theme.animationSlow; easing.type: Nexa.Theme.easingStandard } }
                        }
                    }
                }
            }
        }
    }
}
