import QtQuick
import QtQuick.Layouts

import Quickshell
import Quickshell.Io

import "../NewNexaUI" as NexaUI
import "../modules/settings/quicksettings" as QuickSettingsModule
import "../modules/notifications" as NotificationModule
import "../modules/weather" as WeatherModule
import "../modules/battery" as BatteryModule


Item {
    id: root

    implicitWidth: 760
    implicitHeight: 460
    width: 760
    height: 460

    // ============================================================
    // CONTROL CENTER STATE
    //
    // Page 0 = Quick Settings
    // Page 1 = Notifications
    // Page 2 = Weather
    // Page 3 = Profile
    // ============================================================

    property int currentPage: 0

    signal requestClose()
    signal requestOpenClock()


    // ============================================================
    // HEADER (NAVIGATION + CLOSE)
    // ============================================================

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: NexaUI.NexaTokens.spacingLg
        spacing: NexaUI.NexaTokens.spacingMd


        // --------------------------------------------------------
        // TOP BAR / SEGMENTED SWITCHER
        // --------------------------------------------------------

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 38
            spacing: NexaUI.NexaTokens.spacingMd

            // Left: Back to Clock
            Rectangle {
                Layout.alignment: Qt.AlignVCenter
                width: 32
                height: 32
                radius: 16
                color: clockBtnMouse.containsMouse ? NexaUI.NexaColors.surfaceContainerHigh : NexaUI.NexaColors.surfaceContainer
                border.width: NexaUI.NexaTokens.borderThin
                border.color: clockBtnMouse.containsMouse ? NexaUI.NexaColors.borderStrong : NexaUI.NexaColors.border

                Behavior on color {
                    ColorAnimation { duration: NexaUI.NexaMotion.durationFast }
                }
                Behavior on border.color {
                    ColorAnimation { duration: NexaUI.NexaMotion.durationFast }
                }

                Text {
                    anchors.centerIn: parent
                    text: "󰥔"
                    color: clockBtnMouse.containsMouse ? NexaUI.NexaColors.text : NexaUI.NexaColors.mutedText
                    font.family: NexaUI.NexaTypography.familyIcon
                    font.pixelSize: NexaUI.NexaTypography.sizeMd
                }

                MouseArea {
                    id: clockBtnMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.requestOpenClock()
                }
            }

            // Title / Breadcrumb
            Row {
                Layout.alignment: Qt.AlignVCenter
                spacing: NexaUI.NexaTokens.spacingSm

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: {
                        switch (root.currentPage) {
                        case 0: return "󰒓"
                        case 1: return "󰂚"
                        case 2: return "󰖐"
                        default: return "󰕰"
                        }
                    }
                    color: NexaUI.NexaColors.primary
                    font {
                        family: NexaUI.NexaTypography.familyIcon
                        pixelSize: NexaUI.NexaTypography.sizeLg
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: {
                        switch (root.currentPage) {
                        case 0: return "Quick Settings"
                        case 1: return "Notifications"
                        case 2: return "Weather"
                        default: return "Control Center"
                        }
                    }
                    color: NexaUI.NexaColors.text
                    font {
                        family: NexaUI.NexaTypography.familyDisplay
                        pixelSize: NexaUI.NexaTypography.sizeMd
                        weight: NexaUI.NexaTypography.weightSemiBold
                    }
                }
            }

            Item { Layout.fillWidth: true }

            // Center: Segmented Navigation Pill
            Rectangle {
                Layout.alignment: Qt.AlignVCenter
                implicitHeight: 36
                implicitWidth: 360
                radius: NexaUI.NexaTokens.radiusPill
                color: NexaUI.NexaColors.surfaceContainer
                border.width: NexaUI.NexaTokens.borderThin
                border.color: NexaUI.NexaColors.border

                // Top chamfer specular highlight
                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 1
                    radius: parent.radius
                    color: Qt.rgba(1, 1, 1, 0.12 * NexaUI.NexaOptics.specularIntensity)
                    visible: NexaUI.NexaOptics.specularHighlight
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 3
                    spacing: 4

                    NavTab {
                        pageIndex: 0
                        icon: "󰒓"
                        label: "Controls"
                    }

                    NavTab {
                        pageIndex: 1
                        icon: "󰂚"
                        label: "Alerts"
                    }

                    NavTab {
                        pageIndex: 2
                        icon: "󰖐"
                        label: "Weather"
                    }
                }
            }

            Item { Layout.fillWidth: true }

            // Right: Battery
            BatteryModule.Battery {
                Layout.alignment: Qt.AlignVCenter
            }
        }


        // --------------------------------------------------------
        // DIVIDER
        // --------------------------------------------------------

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: NexaUI.NexaTokens.borderThin
            color: NexaUI.NexaColors.borderSubtle
        }


        // --------------------------------------------------------
        // SLIDING CONTENT VIEWPORT
        // --------------------------------------------------------

        Item {
            id: pageViewport
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            Row {
                id: pageTrack
                width: pageViewport.width * 4
                height: pageViewport.height
                x: -(root.currentPage * pageViewport.width)

                Behavior on x {
                    enabled: NexaUI.NexaMotion.enabled
                    SpringAnimation {
                        spring: NexaUI.NexaMotion.springStiffness
                        damping: NexaUI.NexaMotion.springDamping
                        mass: NexaUI.NexaMotion.springMass
                        epsilon: 0.25
                    }
                }

                // Page 0 — Quick Settings
                Item {
                    width: pageViewport.width
                    height: pageViewport.height

                    QuickSettingsModule.QuickSettings {
                        anchors.fill: parent
                        visible: root.visible && root.currentPage === 0
                    }
                }

                // Page 1 — Notifications
                Item {
                    width: pageViewport.width
                    height: pageViewport.height

                    NotificationModule.Notifications {
                        anchors.fill: parent
                        visible: root.visible && root.currentPage === 1
                    }
                }

                // Page 2 — Weather
                Item {
                    width: pageViewport.width
                    height: pageViewport.height

                    WeatherModule.Weather {
                        anchors.fill: parent
                        visible: root.visible && root.currentPage === 2
                    }
                }
            }
        }
    }


    // ============================================================
    // NAV TAB COMPONENT
    // ============================================================

    component NavTab: Rectangle {
        id: tab

        property int pageIndex: 0
        property string icon: ""
        property string label: ""

        readonly property bool active: root.currentPage === tab.pageIndex

        Layout.fillWidth: true
        Layout.fillHeight: true
        radius: NexaUI.NexaTokens.radiusPill

        color: {
            if (tab.active)
                return NexaUI.NexaColors.primary
            if (tabMouse.containsMouse)
                return NexaUI.NexaColors.alpha(NexaUI.NexaColors.onSurface, 0.08)
            return "transparent"
        }

        Behavior on color {
            ColorAnimation { duration: NexaUI.NexaMotion.durationFast }
        }

        // Top specular line when active
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            radius: parent.radius
            color: Qt.rgba(1, 1, 1, 0.25 * NexaUI.NexaOptics.specularIntensity)
            visible: tab.active && NexaUI.NexaOptics.specularHighlight
        }

        Row {
            anchors.centerIn: parent
            spacing: 6

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: tab.icon
                color: tab.active ? NexaUI.NexaColors.onPrimary : (tabMouse.containsMouse ? NexaUI.NexaColors.text : NexaUI.NexaColors.mutedText)
                font {
                    family: NexaUI.NexaTypography.familyIcon
                    pixelSize: NexaUI.NexaTypography.sizeSm
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: tab.label
                color: tab.active ? NexaUI.NexaColors.onPrimary : (tabMouse.containsMouse ? NexaUI.NexaColors.text : NexaUI.NexaColors.mutedText)
                font {
                    family: NexaUI.NexaTypography.familyBody
                    pixelSize: NexaUI.NexaTypography.sizeXs
                    weight: tab.active ? NexaUI.NexaTypography.weightSemiBold : NexaUI.NexaTypography.weightMedium
                }
            }
        }

        MouseArea {
            id: tabMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                root.currentPage = tab.pageIndex
                if (tab.pageIndex === 1) {
                    // Mark notifications as read
                    Quickshell.execDetached([
                        Quickshell.env("HOME") + "/.config/nexa/rust/target/release/nexad",
                        "notifications",
                        "read-all"
                    ])
                }
            }
        }
    }
}
