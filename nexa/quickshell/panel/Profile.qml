import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io

import "../theme" as Nexa


Item {
    id: root

    property string wallpaperPath: ""
    property string userName: ""
    property string hostName: ""
    property string uptimeText: ""


    // ============================================================
    // PAGE HEADER
    // ============================================================

    Rectangle {
        id: pageHeader

        anchors {
            top: parent.top
            left: parent.left
            right: parent.right

            topMargin: Nexa.Theme.spacingLg
            leftMargin: Nexa.Theme.spacingLg
            rightMargin: Nexa.Theme.spacingLg
        }

        height: profileHeaderRow.implicitHeight + Nexa.Theme.spacingMd * 2

        color: Nexa.Theme.panelBackgroundElevated
        radius: Nexa.Theme.radiusXl

        // Flatten bottom edge
        Rectangle {
            anchors {
                left: parent.left
                right: parent.right
                bottom: parent.bottom
            }
            height: parent.radius
            color: parent.color
        }

        border {
            width: Nexa.Theme.borderThin
            color: Nexa.Theme.divider
        }

        RowLayout {
            id: profileHeaderRow

            anchors {
                left: parent.left
                right: parent.right
                verticalCenter: parent.verticalCenter
                leftMargin: Nexa.Theme.spacingLg
                rightMargin: Nexa.Theme.spacingMd
            }

            spacing: Nexa.Theme.spacingSm

            Text {
                text: ""
                color: Nexa.Theme.primary
                font {
                    family: Nexa.Theme.iconFontFamily
                    pixelSize: Nexa.Theme.iconMd
                }
            }

            Text {
                text: "Profile"
                color: Nexa.Theme.text
                font {
                    family: Nexa.Theme.fontFamily
                    pixelSize: Nexa.Theme.fontSizeXl
                    weight: Nexa.Theme.fontWeightDemiBold
                }
            }

            Item { Layout.fillWidth: true }
        }
    }


    // ============================================================
    // WALLPAPER / PROFILE INFO
    // ============================================================

    Rectangle {
        id: profileHeader

        anchors {
            top: pageHeader.bottom
            bottom: parent.bottom
            left: parent.left
            right: parent.right

            topMargin:
                Nexa.Theme.spacingMd

            bottomMargin:
                Nexa.Theme.spacingLg

            leftMargin:
                Nexa.Theme.spacingLg

            rightMargin:
                Nexa.Theme.spacingLg
        }

        radius:
            Nexa.Theme.radiusLg

        color:
            Nexa.Theme.panelBackground

        clip: true

        layer.enabled: true
        layer.effect: OpacityMask {
            maskSource: Rectangle {
                width: profileHeader.width
                height: profileHeader.height
                radius: Nexa.Theme.radiusLg
            }
        }


        // --------------------------------------------------------
        // WALLPAPER
        // --------------------------------------------------------

        Image {
            id: wallpaperImage

            anchors.fill: parent

            sourceSize.width: 600
            sourceSize.height: 300

            source:
                root.wallpaperPath !== ""
                ? "file://" + root.wallpaperPath
                : ""

            fillMode:
                Image.PreserveAspectCrop

            horizontalAlignment:
                Image.AlignHCenter

            verticalAlignment:
                Image.AlignVCenter

            asynchronous: true
            cache: false
            smooth: true
        }


        // --------------------------------------------------------
        // DARK OVERLAY
        // --------------------------------------------------------

        Rectangle {
            anchors.fill: parent

            color:
                Nexa.Theme.scrimLight
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            z: 100
            
            onClicked: {
                if (typeof wallpaperView !== "undefined") {
                    wallpaperView.visible = true
                    wallpaperView.forceActiveFocus()
                }

                // Close the side panel automatically
                Quickshell.execDetached([
                    "qs",
                    "-p",
                    Quickshell.env("HOME") + "/.config/nexa/quickshell",
                    "ipc",
                    "call",
                    "sidePanel",
                    "close"
                ])
            }
        }


        // --------------------------------------------------------
        // PROFILE INFO
        // --------------------------------------------------------

        Column {
            anchors {
                left: parent.left
                bottom: parent.bottom

                leftMargin:
                    Nexa.Theme.spacingLg

                bottomMargin:
                    Nexa.Theme.spacingLg
            }

            spacing: 2


            Text {
                text:
                    root.userName

                color:
                    "white"

                font {
                    family:
                        Nexa.Theme.fontFamily

                    pixelSize:
                        Nexa.Theme.fontSizeXl

                    weight:
                        Nexa.Theme.fontWeightDemiBold
                }
            }


            Text {
                text:
                    root.userName !== ""
                    && root.hostName !== ""
                    ? root.userName + "@" + root.hostName
                    : ""

                color:
                    "#DDFFFFFF"

                font {
                    family:
                        Nexa.Theme.fontFamily

                    pixelSize:
                        Nexa.Theme.fontSizeSm
                }
            }


            Text {
                text:
                    root.uptimeText !== ""
                    ? "Uptime · " + root.uptimeText
                    : ""

                color:
                    "#BBFFFFFF"

                font {
                    family:
                        Nexa.Theme.fontFamily

                    pixelSize:
                        Nexa.Theme.fontSizeSm
                }
            }
        }
    }


    // ============================================================
    // PROFILE DATA
    // ============================================================

    Process {
        id: profileInfoProcess

        command: [
            "sh",
            "-c",
            [
                "printf 'USER %s\\n' \"$(whoami)\"; ",

                "printf 'HOST %s\\n' \"$(hostname)\"; ",

                "printf 'UPTIME %s\\n' \"$(",
                    "uptime -p | sed 's/^up //'",
                ")\"; ",

                ". \"$HOME/.config/nexa/config/wallpaper.conf\"; ",

                "printf 'WALLPAPER %s\\n' \"$THEME_SOURCE\""
              ].join("")
        ]

        running: true


        stdout: StdioCollector {
            onStreamFinished: {
                const lines =
                    text.trim().split("\n")


                for (let i = 0; i < lines.length; ++i) {

                    const line =
                        lines[i].trim()

                    const split =
                        line.indexOf(" ")

                    if (split < 0)
                        continue


                    const key =
                        line.substring(
                            0,
                            split
                        )

                    const value =
                        line.substring(
                            split + 1
                        )


                    switch (key) {

                    case "USER":
                        root.userName =
                            value

                        break


                    case "HOST":
                        root.hostName =
                            value

                        break


                    case "UPTIME":
                        root.uptimeText =
                            value

                        break


                    case "WALLPAPER":
                        root.wallpaperPath =
                            value

                        console.log(
                            "Profile wallpaper:",
                            value
                        )

                        break
                    }
                }
            }
        }
    }
}
