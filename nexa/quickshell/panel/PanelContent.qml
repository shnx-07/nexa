import QtQuick
import QtQuick.Layouts

import Quickshell

import "../theme" as Nexa
import "../modules/notifications" as NotificationModule
import "." as PanelModule
import "../modules/weather" as WeatherModule

Item {
    id: root

    // ============================================================
    // SIDE PANEL CONTENT
    //
    // Page 0 = Notifications
    // Page 1 = Quick Settings
    // Page 2 = Weather
    // Page 3 = Profile
    // ============================================================

    property int currentPage: 0


    // ============================================================
    // MAIN LAYOUT
    // ============================================================

    ColumnLayout {
        anchors.fill: parent
        spacing: 0


        // ========================================================
        // PAGE VIEWPORT
        // ========================================================

        Item {
            id: pageViewport

            Layout.fillWidth: true
            Layout.fillHeight: true

            clip: true


            Row {
                id: pageTrack

                width: pageViewport.width * 4
                height: pageViewport.height

                x:
                    -(
                        root.currentPage
                        * pageViewport.width
                    )


                Behavior on x {
                    NumberAnimation {
                        duration:
                            Nexa.Theme.animationNormal

                        easing.type:
                            Nexa.Theme.easingStandard
                    }
                }


                // ====================================================
                // PAGE 0 — NOTIFICATIONS
                // ====================================================

                Item {
                    width: pageViewport.width
                    height: pageViewport.height


                    NotificationModule.Notifications {
                        anchors.fill: parent
                    }
                }


                // ====================================================
                // PAGE 1 — QUICK SETTINGS
                // ====================================================

                Item {
                    width: pageViewport.width
                    height: pageViewport.height


                    PanelModule.QuickSettings {
                        anchors.fill: parent
                    }
                }


                // ====================================================
                // PAGE 2 — WEATHER
                // ====================================================

                Item {
                    width: pageViewport.width
                    height: pageViewport.height


                    WeatherModule.Weather {
                        anchors.fill: parent
                    }
                }


                // ====================================================
                // PAGE 3 — PROFILE
                // ====================================================

                Item {
                    width: pageViewport.width
                    height: pageViewport.height


                    PanelModule.Profile {
                        anchors.fill: parent
                    }
                }

            }
        }


        // ========================================================
        // DIVIDER
        // ========================================================

        Rectangle {
            Layout.fillWidth: true

            Layout.preferredHeight:
                Nexa.Theme.borderThin

            color:
                Nexa.Theme.divider
        }


        // ========================================================
        // BOTTOM NAVIGATION
        // ========================================================

        Item {
            Layout.fillWidth: true

            Layout.preferredHeight:
                Nexa.Theme.controlHeightLg
                + Nexa.Theme.spacingLg


            RowLayout {
                id: navLayout
                anchors {
                    fill: parent
                    leftMargin: Nexa.Theme.spacingMd
                    rightMargin: Nexa.Theme.spacingMd
                    topMargin: Nexa.Theme.spacingSm
                    bottomMargin: Nexa.Theme.spacingSm
                }
                spacing: Nexa.Theme.spacingSm

                NavButton {
                    id: navBtn0
                    Layout.fillWidth: true
                    icon: "󰂚"
                    active: root.currentPage === 0
                    onClicked: {
                        root.currentPage = 0
                        Quickshell.execDetached([
                            "sh",
                            "-c",
                            "\"$HOME/.config/nexa/rust/target/release/nexad\" notifications read-all"
                        ])
                    }
                }

                NavButton {
                    id: navBtn1
                    Layout.fillWidth: true
                    icon: "󰒓"
                    active: root.currentPage === 1
                    onClicked: root.currentPage = 1
                }

                NavButton {
                    id: navBtn2
                    Layout.fillWidth: true
                    icon: "󰖐"
                    active: root.currentPage === 2
                    onClicked: root.currentPage = 2
                }

                NavButton {
                    id: navBtn3
                    Layout.fillWidth: true
                    icon: ""
                    active: root.currentPage === 3
                    onClicked: root.currentPage = 3
                }
            }

            Nexa.Components.ActiveIndicator {
                y: navLayout.y + navLayout.height - height / 2
                x: {
                    let activeBtn = root.currentPage === 0 ? navBtn0 :
                                    root.currentPage === 1 ? navBtn1 :
                                    root.currentPage === 2 ? navBtn2 : navBtn3;
                    return navLayout.x + activeBtn.x + activeBtn.width / 2 - width / 2;
                }
            }
        }
    }


    // ============================================================
    // NAV BUTTON
    // ============================================================

    component NavButton: Item {
        id: button

        property string icon: ""
        property bool active: false

        signal clicked()

        implicitHeight: Nexa.Theme.controlHeightLg

        scale: mouseArea.pressed ? Nexa.Theme.pressScale : Nexa.Theme.normalScale

        Behavior on scale {
            NumberAnimation {
                duration: Nexa.Theme.animationFast
                easing.type: Nexa.Theme.easingStandard
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: Nexa.Theme.radiusMd
            color: mouseArea.containsMouse && !button.active ? Nexa.Theme.hover : "transparent"
            Behavior on color { ColorAnimation { duration: Nexa.Theme.animationFast } }
        }

        Text {
            anchors.centerIn: parent
            text: button.icon
            color: button.active ? Nexa.Theme.primary : mouseArea.containsMouse ? Nexa.Theme.text : Nexa.Theme.mutedText
            font {
                family: Nexa.Theme.iconFontFamily
                pixelSize: Nexa.Theme.iconLg
            }
            Behavior on color { ColorAnimation { duration: Nexa.Theme.animationFast } }
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.clicked()
        }
    }
}
