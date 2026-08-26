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

                        anchors.margins:
                            Nexa.Theme.spacingMd
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
                anchors {
                    fill: parent

                    leftMargin:
                        Nexa.Theme.spacingMd

                    rightMargin:
                        Nexa.Theme.spacingMd

                    topMargin:
                        Nexa.Theme.spacingSm

                    bottomMargin:
                        Nexa.Theme.spacingSm
                }

                spacing:
                    Nexa.Theme.spacingSm


                // ====================================================
                // NOTIFICATIONS
                // ====================================================

                NavButton {
                    Layout.fillWidth: true

                    icon: "󰂚"

                    active:
                        root.currentPage === 0


                    onClicked: {
                        root.currentPage = 0

                        Quickshell.execDetached([
                            "sh",
                            "-c",
                            "\"$HOME/.config/nexa/rust/target/release/nexad\" notifications read-all"
                        ])
                    }
                }


                // ====================================================
                // QUICK SETTINGS
                // ====================================================

                NavButton {
                    Layout.fillWidth: true

                    icon: "󰒓"

                    active:
                        root.currentPage === 1

                    onClicked:
                        root.currentPage = 1
                }


                // ====================================================
                // WEATHER
                // ====================================================

                NavButton {
                    Layout.fillWidth: true

                    icon: "󰖐"

                    active:
                        root.currentPage === 2

                    onClicked:
                        root.currentPage = 2
                }


                // ====================================================
                // PROFILE
                // ====================================================

                NavButton {
                    Layout.fillWidth: true

                    icon: ""

                    active:
                        root.currentPage === 3

                    onClicked:
                        root.currentPage = 3
                }
            }
        }
    }


    // ============================================================
    // NAV BUTTON
    // ============================================================

    component NavButton: Rectangle {
        id: button

        property string icon: ""
        property bool active: false

        signal clicked()


        implicitHeight:
            Nexa.Theme.controlHeightLg

        radius:
            Nexa.Theme.radiusMd


        color:
            active
            ? Nexa.Theme.selectedOverlay
            : mouseArea.containsMouse
              ? Nexa.Theme.hover
              : "transparent"


        scale:
            mouseArea.pressed
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
            anchors.centerIn: parent

            text:
                button.icon

            color:
                button.active
                ? Nexa.Theme.primary
                : mouseArea.containsMouse
                  ? Nexa.Theme.text
                  : Nexa.Theme.mutedText


            font {
                family:
                    Nexa.Theme.iconFontFamily

                pixelSize:
                    Nexa.Theme.iconMd
            }


            Behavior on color {
                ColorAnimation {
                    duration:
                        Nexa.Theme.animationFast
                }
            }
        }


        MouseArea {
            id: mouseArea

            anchors.fill: parent

            hoverEnabled: true

            cursorShape:
                Qt.PointingHandCursor

            onClicked:
                button.clicked()
        }
    }
}
