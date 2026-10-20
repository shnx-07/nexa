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

    // ============================================================
    // BATTERY SOURCES
    //
    // displayDevice:
    // - percentage
    // - charging state
    // - remaining / charging time
    // - wattage
    //
    // physicalBattery:
    // - battery health
    // ============================================================

    readonly property var battery:
        UPower.displayDevice

    readonly property var physicalBattery: {
        for (let i = 0; i < UPower.devices.values.length; i++) {
            const device = UPower.devices.values[i]

            if (device.isLaptopBattery)
                return device
        }

        return null
    }


    readonly property int percent:
        battery && battery.ready
        ? Math.round(battery.percentage * 100)
        : 0

    readonly property bool charging:
        battery && battery.ready
        && !UPower.onBattery

    readonly property real watts:
        battery && battery.ready
        ? Math.abs(battery.changeRate)
        : 0

    readonly property real health:
        physicalBattery
        && physicalBattery.healthSupported
        ? physicalBattery.healthPercentage
        : 0


    implicitWidth: 380
    implicitHeight: 410

    color: "transparent"
    grabFocus: true

    // ============================================================
    // ANIMATED ARC PERCENT
    //
    // When the popup opens, animatedPercent sweeps from 0 → percent
    // giving a satisfying arc fill animation.
    // ============================================================

    property real animatedPercent: 0

    Behavior on animatedPercent {
        NumberAnimation {
            duration: 800
            easing.type: Easing.OutQuint
        }
    }

    // Short delay before starting the sweep so the popup
    // entrance animation (scale/opacity) completes first.
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
    //
    // Opens below the battery and expands toward the left.
    // ============================================================

    anchor {
        item: root.anchorItem

        rect.x:
            root.anchorItem
            ? root.anchorItem.width
            : 0

        rect.y:
            root.anchorItem
            ? root.anchorItem.height
              + Nexa.Theme.spacingSm
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

        const hours =
            Math.floor(seconds / 3600)

        const minutes =
            Math.floor((seconds % 3600) / 60)

        return hours > 0
            ? hours + "h " + minutes + "m"
            : minutes + "m"
    }


    function setProfile(profile) {
        profileProcess.exec([
            "powerprofilesctl",
            "set",
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

    Rectangle {
        id: panel

        anchors.fill: parent

        radius:
            Nexa.Theme.radiusLg

        color:
            Nexa.Theme.panelBackground

        border {
            width:
                Nexa.Theme.borderThin

            color:
                Nexa.Theme.border
        }


        scale:
            root.visible
            ? Nexa.Theme.normalScale
            : 0.97

        opacity:
            root.visible
            ? Nexa.Theme.opacityFull
            : Nexa.Theme.opacityHidden

        transformOrigin:
            Item.TopRight


        Behavior on scale {
            NumberAnimation {
                duration:
                    Nexa.Theme.animationNormal

                easing.type:
                    Nexa.Theme.easingEnter
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration:
                    Nexa.Theme.animationFast

                easing.type:
                    Nexa.Theme.easingEnter
            }
        }


        ColumnLayout {
            anchors {
                fill: parent
                margins: Nexa.Theme.spacingMd
            }

            spacing:
                Nexa.Theme.spacingSm


            // ====================================================
            // SECTION 1 — BATTERY STATUS
            // ====================================================

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 190

                radius:
                    Nexa.Theme.radiusMd

                color:
                    Nexa.Theme.surfaceContainerHigh

                border {
                    width:
                        Nexa.Theme.borderThin

                    color:
                        Nexa.Theme.border
                }


                ColumnLayout {
                    anchors {
                        fill: parent
                        margins: Nexa.Theme.spacingMd
                    }

                    spacing:
                        Nexa.Theme.spacingXs


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
                                const ctx =
                                    getContext("2d")

                                ctx.clearRect(
                                    0,
                                    0,
                                    width,
                                    height
                                )

                                const x = width / 2
                                const y = height - 5
                                const r = 78


                                // Background arc
                                ctx.beginPath()

                                ctx.arc(
                                    x,
                                    y,
                                    r,
                                    Math.PI,
                                    Math.PI * 2
                                )

                                ctx.lineWidth = 10
                                ctx.lineCap = "round"

                                ctx.strokeStyle =
                                    Nexa.Theme.surfaceContainerHighest

                                ctx.stroke()


                                // Active arc
                                ctx.beginPath()

                                ctx.arc(
                                    x,
                                    y,
                                    r,
                                    Math.PI,
                                    Math.PI
                                    + Math.PI
                                    * root.animatedPercent / 100
                                )

                                ctx.lineWidth = 10
                                ctx.lineCap = "round"

                                ctx.strokeStyle =
                                    root.charging
                                    ? Nexa.Theme.success
                                    : root.percent <= 15
                                        ? Nexa.Theme.error
                                        : root.percent <= 30
                                            ? Nexa.Theme.warning
                                            : Nexa.Theme.primary

                                ctx.stroke()
                            }


                            Connections {
                                target: root

                                function onAnimatedPercentChanged() {
                                    arc.requestPaint()
                                }

                                function onPercentChanged() {
                                    arc.requestPaint()
                                }

                                function onChargingChanged() {
                                    arc.requestPaint()
                                }
                            }
                        }


                        Column {
                            anchors {
                                horizontalCenter:
                                    parent.horizontalCenter

                                top:
                                    parent.top

                                topMargin:
                                    38
                            }

                            spacing: 1


                            Text {
                                anchors.horizontalCenter:
                                    parent.horizontalCenter

                                text:
                                    root.percent + "%"

                                color:
                                    Nexa.Theme.text

                                font {
                                    family:
                                        Nexa.Theme.fontFamily

                                    pixelSize:
                                        28

                                    weight:
                                        Nexa.Theme.fontWeightBold
                                }
                            }


                            Text {
                                anchors.horizontalCenter:
                                    parent.horizontalCenter

                                text:
                                    root.charging
                                    ? "Charging"
                                    : "On battery"

                                color:
                                    root.charging
                                    ? Nexa.Theme.success
                                    : Nexa.Theme.mutedText

                                font {
                                    family:
                                        Nexa.Theme.fontFamily

                                    pixelSize:
                                        Nexa.Theme.fontSizeXs

                                    weight:
                                        Nexa.Theme.fontWeightMedium
                                }
                            }
                        }
                    }


                    // ------------------------------------------------
                    // LIVE INFORMATION
                    // ------------------------------------------------

                    RowLayout {
                        Layout.fillWidth: true

                        spacing:
                            Nexa.Theme.spacingSm


                        // Time
                        Rectangle {
                            Layout.fillWidth: true

                            implicitHeight: 48

                            radius:
                                Nexa.Theme.radiusSm

                            color:
                                Nexa.Theme.surfaceContainerHighest


                            Column {
                                anchors {
                                    left: parent.left
                                    verticalCenter:
                                        parent.verticalCenter

                                    leftMargin:
                                        Nexa.Theme.spacingSm
                                }

                                spacing: 1


                                Text {
                                    text:
                                        root.charging
                                        ? "Until full"
                                        : "Remaining"

                                    color:
                                        Nexa.Theme.mutedText

                                    font {
                                        family:
                                            Nexa.Theme.fontFamily

                                        pixelSize:
                                            Nexa.Theme.fontSize2Xs
                                    }
                                }


                                Text {
                                    text:
                                        root.charging
                                        ? root.formatTime(
                                            root.battery.timeToFull
                                          )
                                        : root.formatTime(
                                            root.battery.timeToEmpty
                                          )

                                    color:
                                        Nexa.Theme.text

                                    font {
                                        family:
                                            Nexa.Theme.fontFamily

                                        pixelSize:
                                            Nexa.Theme.fontSizeSm

                                        weight:
                                            Nexa.Theme.fontWeightDemiBold
                                    }
                                }
                            }
                        }


                        // Wattage
                        Rectangle {
                            Layout.fillWidth: true

                            implicitHeight: 48

                            radius:
                                Nexa.Theme.radiusSm

                            color:
                                Nexa.Theme.surfaceContainerHighest


                            Column {
                                anchors {
                                    left: parent.left
                                    verticalCenter:
                                        parent.verticalCenter

                                    leftMargin:
                                        Nexa.Theme.spacingSm
                                }

                                spacing: 1


                                Text {
                                    text:
                                        root.charging
                                        ? "Charge rate"
                                        : "Power draw"

                                    color:
                                        Nexa.Theme.mutedText

                                    font {
                                        family:
                                            Nexa.Theme.fontFamily

                                        pixelSize:
                                            Nexa.Theme.fontSize2Xs
                                    }
                                }


                                Text {
                                    text:
                                        root.watts > 0
                                        ? root.watts.toFixed(1) + " W"
                                        : "—"

                                    color:
                                        Nexa.Theme.text

                                    font {
                                        family:
                                            Nexa.Theme.fontFamily

                                        pixelSize:
                                            Nexa.Theme.fontSizeSm

                                        weight:
                                            Nexa.Theme.fontWeightDemiBold
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

                radius:
                    Nexa.Theme.radiusMd

                color:
                    Nexa.Theme.surfaceContainerHigh

                border {
                    width:
                        Nexa.Theme.borderThin

                    color:
                        Nexa.Theme.border
                }


                ColumnLayout {
                    anchors {
                        fill: parent
                        margins: Nexa.Theme.spacingMd
                    }

                    spacing:
                        Nexa.Theme.spacingSm


                    Text {
                        text:
                            "Power Profile"

                        color:
                            Nexa.Theme.text

                        font {
                            family:
                                Nexa.Theme.fontFamily

                            pixelSize:
                                Nexa.Theme.fontSizeSm

                            weight:
                                Nexa.Theme.fontWeightDemiBold
                        }
                    }


                    RowLayout {
                        Layout.fillWidth: true

                        spacing:
                            Nexa.Theme.spacingXs


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
                                    root.currentProfile
                                    === modelData[1]

                                Layout.fillWidth: true

                                implicitHeight:
                                    Nexa.Theme.controlHeightMd

                                radius:
                                    Nexa.Theme.radiusSm


                                color:
                                    selected
                                    ? Nexa.Theme.selected
                                    : profileMouse.containsMouse
                                        ? Nexa.Theme.hoverStrong
                                        : Nexa.Theme.surfaceContainerHighest


                                scale:
                                    profileMouse.pressed
                                    ? Nexa.Theme.pressScale
                                    : Nexa.Theme.normalScale


                                Behavior on color {
                                    ColorAnimation {
                                        duration:
                                            Nexa.Theme.animationFast
                                    }
                                }

                                Behavior on scale {
                                    NumberAnimation {
                                        duration:
                                            Nexa.Theme.animationFast

                                        easing.type:
                                            Nexa.Theme.easingStandard
                                    }
                                }


                                Text {
                                    anchors.centerIn:
                                        parent

                                    text:
                                        profileButton.modelData[0]

                                    color:
                                        profileButton.selected
                                        ? Nexa.Theme.selectedText
                                        : Nexa.Theme.text

                                    font {
                                        family:
                                            Nexa.Theme.fontFamily

                                        pixelSize:
                                            Nexa.Theme.fontSizeXs

                                        weight:
                                            Nexa.Theme.fontWeightMedium
                                    }
                                }


                                MouseArea {
                                    id: profileMouse

                                    anchors.fill:
                                        parent

                                    hoverEnabled:
                                        true

                                    cursorShape:
                                        Qt.PointingHandCursor

                                    onClicked:
                                        root.setProfile(
                                            profileButton.modelData[1]
                                        )
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

                radius:
                    Nexa.Theme.radiusMd

                color:
                    Nexa.Theme.surfaceContainerHigh

                border {
                    width:
                        Nexa.Theme.borderThin

                    color:
                        Nexa.Theme.border
                }


                ColumnLayout {
                    anchors {
                        fill: parent
                        margins: Nexa.Theme.spacingMd
                    }

                    spacing:
                        Nexa.Theme.spacingSm


                    RowLayout {
                        Layout.fillWidth: true


                        Text {
                            text:
                                "Battery Health"

                            color:
                                Nexa.Theme.text

                            font {
                                family:
                                    Nexa.Theme.fontFamily

                                pixelSize:
                                    Nexa.Theme.fontSizeSm

                                weight:
                                    Nexa.Theme.fontWeightDemiBold
                            }
                        }


                        Item {
                            Layout.fillWidth: true
                        }


                        Text {
                            text:
                                root.physicalBattery
                                && root.physicalBattery.healthSupported
                                ? Math.round(root.health) + "%"
                                : "Unavailable"

                            color:
                                Nexa.Theme.mutedText

                            font {
                                family:
                                    Nexa.Theme.fontFamily

                                pixelSize:
                                    Nexa.Theme.fontSizeSm

                                weight:
                                    Nexa.Theme.fontWeightDemiBold
                            }
                        }
                    }


                    // ------------------------------------------------
                    // HEALTH BAR
                    // ------------------------------------------------

                    Rectangle {
                        Layout.fillWidth: true

                        implicitHeight: 10

                        radius:
                            Nexa.Theme.radiusPill

                        color:
                            Nexa.Theme.surfaceContainerHighest


                        Rectangle {
                            height:
                                parent.height

                            width:
                                root.physicalBattery
                                && root.physicalBattery.healthSupported
                                ? parent.width
                                  * Math.min(
                                        1,
                                        Math.max(
                                            0,
                                            root.health / 100
                                        )
                                    )
                                : 0

                            radius:
                                parent.radius


                            color:
                                root.health >= 80
                                ? Nexa.Theme.success
                                : root.health >= 60
                                    ? Nexa.Theme.warning
                                    : Nexa.Theme.error


                            Behavior on width {
                                NumberAnimation {
                                    duration:
                                        Nexa.Theme.animationSlow

                                    easing.type:
                                        Nexa.Theme.easingStandard
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
