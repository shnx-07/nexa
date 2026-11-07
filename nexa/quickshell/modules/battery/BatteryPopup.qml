import QtQuick
import QtQuick.Layouts

import Quickshell
import Quickshell.Io
import "../../services" as Services
import "../../NewNexaUI" as NexaUI

PopupWindow {
    id: root

    property Item anchorItem
    property string currentProfile: "balanced"

    // ============================================================
    // BATTERY STATE (RUST NEXAD BACKEND)
    // ============================================================

    readonly property int percent: Services.SystemState.batteryPercentage
    readonly property bool charging: Services.SystemState.batteryCharging
    readonly property real watts: Services.SystemState.batteryWatts
    readonly property real health: Services.SystemState.batteryHealth
    readonly property int timeToFull: Services.SystemState.batteryTimeToFull
    readonly property int timeToEmpty: Services.SystemState.batteryTimeToEmpty

    implicitWidth: 412
    implicitHeight: 442

    color: "transparent"
    grabFocus: true

    // ============================================================
    // ANIMATED ARC PERCENT
    // ============================================================

    property real animatedPercent: 0

    Behavior on animatedPercent {
        NumberAnimation {
            duration: 800
            easing.type: Easing.OutQuint
        }
    }

    Timer {
        id: arcSweepTimer
        interval: 80
        repeat: false
        onTriggered: root.animatedPercent = root.percent
    }

    onVisibleChanged: {
        if (visible) {
            root.animatedPercent = 0
            arcSweepTimer.start()
        }
    }

    onPercentChanged: {
        if (visible)
            root.animatedPercent = root.percent
    }

    // ============================================================
    // POSITION
    // ============================================================

    anchor {
        item: root.anchorItem

        rect.x:
            root.anchorItem
            ? root.anchorItem.width + 16
            : 0

        rect.y:
            root.anchorItem
            ? root.anchorItem.height
              + NexaUI.NexaTokens.spacingSm - 16
            : 0

        rect.width: 1
        rect.height: 1

        edges:
            Edges.Top | Edges.Left

        gravity:
            Edges.Bottom | Edges.Left
    }

    // ============================================================
    // HELPERS
    // ============================================================

    function formatTime(seconds) {
        if (!seconds || seconds <= 0)
            return "Calculating…"

        const hours = Math.floor(seconds / 3600)
        const minutes = Math.floor((seconds % 3600) / 60)

        return hours > 0
            ? hours + "h " + minutes + "m"
            : minutes + "m"
    }

    function setProfile(profile) {
        profileProcess.exec([
            Quickshell.env("HOME") + "/.config/nexa/rust/target/release/nexad",
            "power",
            "profile",
            profile
        ])

        currentProfile = profile
    }

    Process {
        id: profileProcess
    }

    // ============================================================
    // MAIN PANEL
    // ============================================================

    NexaUI.NexaShadow {
        id: panelShadow
        targetItem: panel
        elevation: 1
        spread: 0.08
    }

    Rectangle {
        id: panel

        anchors.fill: parent
        anchors.margins: 16

        radius: NexaUI.NexaTokens.radiusLg
        color: NexaUI.NexaColors.surfaceContainer

        border {
            width: NexaUI.NexaTokens.borderThin
            color: NexaUI.NexaColors.borderStrong
        }

        NexaUI.NexaShaderSubstrate {
            anchors.fill: parent
            radius: panel.radius
        }

        // Apple / Tactile 4-stop Depth Micro-Gradient
        Rectangle {
            anchors.fill: parent
            radius: panel.radius
            antialiasing: panel.radius > 0
            visible: NexaUI.NexaOptics.surface3DGradient && NexaUI.NexaOptics.gradientIntensity > 0.01
            opacity: NexaUI.NexaOptics.gradientIntensity
            gradient: Gradient {
                GradientStop { position: 0.00; color: Qt.rgba(1, 1, 1, 0.055) }
                GradientStop { position: 0.40; color: Qt.rgba(1, 1, 1, 0.012) }
                GradientStop { position: 0.70; color: Qt.rgba(0, 0, 0, 0.000) }
                GradientStop { position: 1.00; color: Qt.rgba(0, 0, 0, 0.140) }
            }
        }

        // Top Chamfer Specular Highlight
        Rectangle {
            anchors.top: parent.top
            anchors.topMargin: 1
            anchors.horizontalCenter: parent.horizontalCenter
            width: panel.radius > 0 ? Math.max(0, parent.width - panel.radius * 1.6) : parent.width
            height: 1
            visible: NexaUI.NexaOptics.specularHighlight && NexaUI.NexaOptics.specularIntensity > 0.01
            opacity: Math.min(1.0, NexaUI.NexaOptics.specularIntensity / 0.28)
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.32) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        scale: root.visible ? 1.0 : 0.97
        opacity: root.visible ? 1.0 : 0.0
        transformOrigin: Item.TopRight

        Behavior on scale {
            enabled: NexaUI.NexaMotion.enabled
            SpringAnimation {
                spring: NexaUI.NexaMotion.useSpring("popups") ? NexaUI.NexaMotion.springStiffness : 8.0
                damping: NexaUI.NexaMotion.useSpring("popups") ? NexaUI.NexaMotion.springDamping : 1.0
                mass: NexaUI.NexaMotion.springMass
                epsilon: 0.002
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: NexaUI.NexaMotion.durationFast
                easing.type: NexaUI.NexaMotion.easingStandard
            }
        }

        ColumnLayout {
            anchors {
                fill: parent
                margins: NexaUI.NexaTokens.spacingMd
            }

            spacing: NexaUI.NexaTokens.spacingSm

            // ====================================================
            // SECTION 1 — BATTERY STATUS
            // ====================================================

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 190
                radius: NexaUI.NexaTokens.radiusMd
                color: NexaUI.NexaColors.surfaceContainerHigh

                border {
                    width: NexaUI.NexaTokens.borderThin
                    color: NexaUI.NexaColors.border
                }

                ColumnLayout {
                    anchors {
                        fill: parent
                        margins: NexaUI.NexaTokens.spacingMd
                    }

                    spacing: NexaUI.NexaTokens.spacingXs

                    // ------------------------------------------------
                    // HALF ARC
                    // ------------------------------------------------
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

                                // Background arc
                                ctx.beginPath()
                                ctx.arc(x, y, r, Math.PI, Math.PI * 2)
                                ctx.lineWidth = 10
                                ctx.lineCap = "round"
                                ctx.strokeStyle = NexaUI.NexaColors.surfaceContainerHighest
                                ctx.stroke()

                                // Active arc
                                ctx.beginPath()
                                ctx.arc(
                                    x,
                                    y,
                                    r,
                                    Math.PI,
                                    Math.PI + Math.PI * root.animatedPercent / 100
                                )
                                ctx.lineWidth = 10
                                ctx.lineCap = "round"
                                ctx.strokeStyle =
                                    root.charging
                                    ? NexaUI.NexaColors.success
                                    : root.percent <= 15
                                        ? NexaUI.NexaColors.error
                                        : root.percent <= 30
                                            ? NexaUI.NexaColors.warning
                                            : NexaUI.NexaColors.primary
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
                            anchors {
                                horizontalCenter: parent.horizontalCenter
                                top: parent.top
                                topMargin: 38
                            }

                            spacing: 1

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: root.percent + "%"
                                color: NexaUI.NexaColors.text
                                font {
                                    family: NexaUI.NexaTypography.familyDisplay
                                    pixelSize: 28
                                    weight: NexaUI.NexaTypography.weightBold
                                }
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: root.charging
                                    ? (root.percent >= 100 ? "Fully Charged" : "Charging")
                                    : "On battery"
                                color: root.charging
                                    ? NexaUI.NexaColors.success
                                    : NexaUI.NexaColors.mutedText
                                font {
                                    family: NexaUI.NexaTypography.familyBody
                                    pixelSize: NexaUI.NexaTypography.sizeXs
                                    weight: NexaUI.NexaTypography.weightMedium
                                }
                            }
                        }
                    }

                    // ------------------------------------------------
                    // LIVE INFORMATION
                    // ------------------------------------------------
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: NexaUI.NexaTokens.spacingSm

                        // Time
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 48
                            radius: NexaUI.NexaTokens.radiusSm
                            color: NexaUI.NexaColors.surfaceContainerHighest
                            border.width: NexaUI.NexaTokens.borderThin
                            border.color: NexaUI.NexaColors.border

                            Column {
                                anchors {
                                    left: parent.left
                                    verticalCenter: parent.verticalCenter
                                    leftMargin: NexaUI.NexaTokens.spacingSm
                                }

                                spacing: 1

                                Text {
                                    text: root.charging ? "Until full" : "Remaining"
                                    color: NexaUI.NexaColors.mutedText
                                    font {
                                        family: NexaUI.NexaTypography.familyBody
                                        pixelSize: NexaUI.NexaTypography.size2Xs
                                    }
                                }

                                Text {
                                    text: root.charging
                                        ? root.formatTime(root.timeToFull)
                                        : root.formatTime(root.timeToEmpty)
                                    color: NexaUI.NexaColors.text
                                    font {
                                        family: NexaUI.NexaTypography.familyBody
                                        pixelSize: NexaUI.NexaTypography.sizeSm
                                        weight: NexaUI.NexaTypography.weightSemiBold
                                    }
                                }
                            }
                        }

                        // Wattage
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 48
                            radius: NexaUI.NexaTokens.radiusSm
                            color: NexaUI.NexaColors.surfaceContainerHighest
                            border.width: NexaUI.NexaTokens.borderThin
                            border.color: NexaUI.NexaColors.border

                            Column {
                                anchors {
                                    left: parent.left
                                    verticalCenter: parent.verticalCenter
                                    leftMargin: NexaUI.NexaTokens.spacingSm
                                }

                                spacing: 1

                                Text {
                                    text: root.charging ? "Charge rate" : "Power draw"
                                    color: NexaUI.NexaColors.mutedText
                                    font {
                                        family: NexaUI.NexaTypography.familyBody
                                        pixelSize: NexaUI.NexaTypography.size2Xs
                                    }
                                }

                                Text {
                                    text: root.watts > 0
                                        ? root.watts.toFixed(1) + " W"
                                        : "—"
                                    color: NexaUI.NexaColors.text
                                    font {
                                        family: NexaUI.NexaTypography.familyBody
                                        pixelSize: NexaUI.NexaTypography.sizeSm
                                        weight: NexaUI.NexaTypography.weightSemiBold
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ====================================================
            // SECTION 2 — POWER PROFILE
            // ====================================================
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 94
                radius: NexaUI.NexaTokens.radiusMd
                color: NexaUI.NexaColors.surfaceContainerHigh

                border {
                    width: NexaUI.NexaTokens.borderThin
                    color: NexaUI.NexaColors.border
                }

                ColumnLayout {
                    anchors {
                        fill: parent
                        margins: NexaUI.NexaTokens.spacingMd
                    }

                    spacing: NexaUI.NexaTokens.spacingSm

                    Text {
                        text: "Power Profile"
                        color: NexaUI.NexaColors.text
                        font {
                            family: NexaUI.NexaTypography.familyBody
                            pixelSize: NexaUI.NexaTypography.sizeSm
                            weight: NexaUI.NexaTypography.weightSemiBold
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: NexaUI.NexaTokens.spacingXs

                        Repeater {
                            model: [
                                ["Saver", "power-saver"],
                                ["Balanced", "balanced"],
                                ["Performance", "performance"]
                            ]

                            delegate: Rectangle {
                                id: profileButton
                                required property var modelData

                                readonly property bool selected:
                                    root.currentProfile === modelData[1]

                                Layout.fillWidth: true
                                implicitHeight: NexaUI.NexaTokens.controlHeightMd
                                radius: NexaUI.NexaTokens.radiusSm

                                color: selected
                                    ? NexaUI.NexaColors.primary
                                    : profileMouse.containsMouse
                                        ? NexaUI.NexaColors.surfaceContainerHigh
                                        : NexaUI.NexaColors.surfaceContainerHighest

                                border.width: NexaUI.NexaTokens.borderThin
                                border.color: selected
                                    ? NexaUI.NexaColors.primary
                                    : NexaUI.NexaColors.border

                                scale: profileMouse.pressed
                                    ? NexaUI.NexaMotion.scalePress
                                    : 1.0

                                Behavior on color {
                                    ColorAnimation {
                                        duration: NexaUI.NexaMotion.durationFast
                                    }
                                }

                                Behavior on scale {
                                    NumberAnimation {
                                        duration: NexaUI.NexaMotion.durationFast
                                        easing.type: NexaUI.NexaMotion.easingStandard
                                    }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: profileButton.modelData[0]
                                    color: profileButton.selected
                                        ? NexaUI.NexaColors.onPrimary
                                        : NexaUI.NexaColors.text
                                    font {
                                        family: NexaUI.NexaTypography.familyBody
                                        pixelSize: NexaUI.NexaTypography.sizeXs
                                        weight: NexaUI.NexaTypography.weightMedium
                                    }
                                }

                                MouseArea {
                                    id: profileMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked:
                                        root.setProfile(profileButton.modelData[1])
                                }
                            }
                        }
                    }
                }
            }

            // ====================================================
            // SECTION 3 — BATTERY HEALTH
            // ====================================================
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: NexaUI.NexaTokens.radiusMd
                color: NexaUI.NexaColors.surfaceContainerHigh

                border {
                    width: NexaUI.NexaTokens.borderThin
                    color: NexaUI.NexaColors.border
                }

                ColumnLayout {
                    anchors {
                        fill: parent
                        margins: NexaUI.NexaTokens.spacingMd
                    }

                    spacing: NexaUI.NexaTokens.spacingSm

                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            text: "Battery Health"
                            color: NexaUI.NexaColors.text
                            font {
                                family: NexaUI.NexaTypography.familyBody
                                pixelSize: NexaUI.NexaTypography.sizeSm
                                weight: NexaUI.NexaTypography.weightSemiBold
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        Text {
                            text: root.health > 0
                                ? Math.round(root.health) + "%"
                                : "Unavailable"
                            color: NexaUI.NexaColors.mutedText
                            font {
                                family: NexaUI.NexaTypography.familyBody
                                pixelSize: NexaUI.NexaTypography.sizeSm
                                weight: NexaUI.NexaTypography.weightSemiBold
                            }
                        }
                    }

                    // ------------------------------------------------
                    // HEALTH BAR
                    // ------------------------------------------------
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 10
                        radius: NexaUI.NexaTokens.radiusPill
                        color: NexaUI.NexaColors.surfaceContainerHighest

                        Rectangle {
                            height: parent.height
                            width: root.health > 0
                                ? parent.width * Math.min(1, Math.max(0, root.health / 100))
                                : 0
                            radius: parent.radius
                            color: root.health >= 80
                                ? NexaUI.NexaColors.success
                                : root.health >= 60
                                    ? NexaUI.NexaColors.warning
                                    : NexaUI.NexaColors.error

                            Behavior on width {
                                NumberAnimation {
                                    duration: NexaUI.NexaMotion.durationSlow
                                    easing.type: NexaUI.NexaMotion.easingStandard
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
