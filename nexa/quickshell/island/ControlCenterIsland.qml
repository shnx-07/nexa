import QtQuick
import QtQuick.Layouts

import Quickshell
import Quickshell.Io

import "../theme" as Nexa
import "../panel" as PanelModule
import "../modules/notifications" as NotificationModule
import "../modules/weather" as WeatherModule
import "../modules/battery" as BatteryModule


Item {
    id: root

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


    // ============================================================
    // HEADER (NAVIGATION + CLOSE)
    // ============================================================

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Nexa.Theme.spacingLg
        spacing: Nexa.Theme.spacingMd


        // --------------------------------------------------------
        // TOP BAR / SEGMENTED SWITCHER
        // --------------------------------------------------------

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 38
            spacing: Nexa.Theme.spacingMd

            // Left: Title / Breadcrumb
            Row {
                Layout.alignment: Qt.AlignVCenter
                spacing: Nexa.Theme.spacingSm

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: {
                        switch (root.currentPage) {
                        case 0: return "󰒓"
                        case 1: return "󰂚"
                        case 2: return "󰖐"
                        case 3: return ""
                        default: return "󰕰"
                        }
                    }
                    color: Nexa.Theme.primary
                    font {
                        family: Nexa.Theme.iconFontFamily
                        pixelSize: Nexa.Theme.iconMd
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: {
                        switch (root.currentPage) {
                        case 0: return "Quick Settings"
                        case 1: return "Notifications"
                        case 2: return "Weather"
                        case 3: return "Profile"
                        default: return "Control Center"
                        }
                    }
                    color: Nexa.Theme.text
                    font {
                        family: Nexa.Theme.fontFamily
                        pixelSize: Nexa.Theme.fontSizeMd
                        weight: Nexa.Theme.fontWeightDemiBold
                    }
                }
            }

            Item { Layout.fillWidth: true }

            // Center: Segmented Navigation Pill
            Rectangle {
                Layout.alignment: Qt.AlignVCenter
                implicitHeight: 36
                implicitWidth: 360
                radius: 18
                color: Nexa.Theme.surfaceContainer
                border.width: Nexa.Theme.borderThin
                border.color: Nexa.Theme.border

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

                    NavTab {
                        pageIndex: 3
                        icon: ""
                        label: "Profile"
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
            Layout.preferredHeight: Nexa.Theme.borderThin
            color: Nexa.Theme.divider
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
                    NumberAnimation {
                        duration: Nexa.Theme.animationNormal
                        easing.type: Nexa.Theme.easingStandard
                    }
                }

                // Page 0 — Quick Settings
                Item {
                    width: pageViewport.width
                    height: pageViewport.height

                    PanelModule.QuickSettings {
                        anchors.fill: parent
                    }
                }

                // Page 1 — Notifications
                Item {
                    width: pageViewport.width
                    height: pageViewport.height

                    NotificationModule.Notifications {
                        anchors.fill: parent
                    }
                }

                // Page 2 — Weather
                Item {
                    width: pageViewport.width
                    height: pageViewport.height

                    WeatherModule.Weather {
                        anchors.fill: parent
                    }
                }

                // Page 3 — Profile
                Item {
                    width: pageViewport.width
                    height: pageViewport.height

                    PanelModule.Profile {
                        anchors.fill: parent
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
        radius: 15

        color: {
            if (tab.active)
                return Nexa.Theme.selected
            if (tabMouse.containsMouse)
                return Nexa.Theme.hover
            return "transparent"
        }

        Behavior on color {
            ColorAnimation { duration: Nexa.Theme.animationFast }
        }

        Row {
            anchors.centerIn: parent
            spacing: 5

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: tab.icon
                color: tab.active ? Nexa.Theme.selectedText : Nexa.Theme.mutedText
                font {
                    family: Nexa.Theme.iconFontFamily
                    pixelSize: Nexa.Theme.iconSm
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: tab.label
                color: tab.active ? Nexa.Theme.selectedText : Nexa.Theme.mutedText
                font {
                    family: Nexa.Theme.fontFamily
                    pixelSize: Nexa.Theme.fontSizeXs
                    weight: tab.active ? Nexa.Theme.fontWeightDemiBold : Nexa.Theme.fontWeightMedium
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

