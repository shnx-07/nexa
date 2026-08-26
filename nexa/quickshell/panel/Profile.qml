import QtQuick
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
    // PROFILE HEADER
    // ============================================================

    Rectangle {
        id: profileHeader

        anchors {
            top: parent.top
            left: parent.left
            right: parent.right

            topMargin:
                Nexa.Theme.spacingMd

            leftMargin:
                Nexa.Theme.spacingMd

            rightMargin:
                Nexa.Theme.spacingMd
        }

        height: 160

        radius:
            Nexa.Theme.radiusLg

        color:
            Nexa.Theme.panelBackground

        clip: true


        // --------------------------------------------------------
        // WALLPAPER
        // --------------------------------------------------------

        Image {
            id: wallpaperImage

            anchors.fill: parent

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
