import QtQuick
import Quickshell
import Quickshell.Io

import "../../theme" as Nexa

Item {
    id: root

    signal requestClose()

    // ============================================================
    // FOCUS
    // ============================================================

    function activate() {
        forceActiveFocus()
    }

    onVisibleChanged: {
        if (visible) {
            Qt.callLater(function() {
                forceActiveFocus()
            })
        }
    }


    // ============================================================
    // POWER COMMAND
    // ============================================================
    function runLockAction() {
        console.log(
            "NEXA power action: lock"
        )

        lockProcess.command = [
            "hyprctl",
            "dispatch",
            "global",
            "nexa:lock"
        ]

        lockProcess.running = true

        root.requestClose()
    }
    function runPowerAction(action) {
        console.log(
            "NEXA power action:",
            action
        )

        powerProcess.command = [
            "/home/shnx/.config/nexa/rust/target/release/nexad",
            "power",
            action
        ]

        powerProcess.running = true

        root.requestClose()
    }

    Process {
        id: lockProcess
    }

    Process {
        id: powerProcess
    }


    // ============================================================
    // SHORTCUTS
    // ============================================================

    Shortcut {
        sequence: "Escape"

        enabled: root.visible

        onActivated: root.requestClose()
    }

    Shortcut {
        sequence: "1"
        enabled: root.visible
        onActivated: root.runLockAction()
    }

    Shortcut {
        sequence: "2"
        enabled: root.visible
        onActivated: root.runPowerAction("suspend")
    }

    Shortcut {
        sequence: "3"
        enabled: root.visible
        onActivated: root.runPowerAction("logout")
    }

    Shortcut {
        sequence: "4"
        enabled: root.visible
        onActivated: root.runPowerAction("reboot")
    }

    Shortcut {
        sequence: "5"
        enabled: root.visible
        onActivated: root.runPowerAction("shutdown")
    }


    // ============================================================
    // POWER BUTTON ROW
    // ============================================================

    Row {
        id: powerRow

        anchors.centerIn: parent

        spacing: 12


            // ====================================================
            // 1 — LOCK
            // ====================================================

            PowerCard {
                number: "1"
                label: "Lock"
                icon: "⏻"
                cardIndex: 0
                popupVisible: root.visible

                onTriggered:
                    root.runLockAction()
            }


            // ====================================================
            // 2 — SUSPEND
            // ====================================================

            PowerCard {
                number: "2"
                label: "Sleep"
                icon: "◐"
                cardIndex: 1
                popupVisible: root.visible

                onTriggered:
                    root.runPowerAction("suspend")
            }


            // ====================================================
            // 3 — LOGOUT
            // ====================================================

            PowerCard {
                number: "3"
                label: "Logout"
                icon: "⇥"
                cardIndex: 2
                popupVisible: root.visible

                onTriggered:
                    root.runPowerAction("logout")
            }


            // ====================================================
            // 4 — REBOOT
            // ====================================================

            PowerCard {
                number: "4"
                label: "Reboot"
                icon: "⏸"
                cardIndex: 3
                popupVisible: root.visible

                onTriggered:
                    root.runPowerAction("reboot")
            }


            // ====================================================
            // 5 — SHUTDOWN
            // ====================================================

            PowerCard {
                number: "5"
                label: "Shutdown"
                icon: "◒"
                cardIndex: 4
                popupVisible: root.visible

                onTriggered:
                    root.runPowerAction("shutdown")
            }
        }


    // ============================================================
    // POWER CARD
    // ============================================================

    component PowerCard: Rectangle {
        id: card


        required property string number
        required property string label
        required property string icon
        property int cardIndex: 0
        property bool popupVisible: false

        signal triggered()


        // ========================================================
        // SIZE
        // ========================================================

        width: 138
        height: 120

        radius: 10


        // ========================================================
        // STAGGERED SLIDE-UP ENTRANCE
        // ========================================================

        opacity: popupVisible ? 1.0 : 0.0
        y: popupVisible ? 0 : 14

        Behavior on opacity {
            SequentialAnimation {
                PauseAnimation { duration: card.cardIndex * Nexa.Theme.staggerBase }
                NumberAnimation {
                    duration: Nexa.Theme.popEnterDuration
                    easing.type: Nexa.Theme.easingEnter
                }
            }
        }

        Behavior on y {
            SequentialAnimation {
                PauseAnimation { duration: card.cardIndex * Nexa.Theme.staggerBase }
                NumberAnimation {
                    duration: Nexa.Theme.animationNormal
                    easing.type: Nexa.Theme.easingEnter
                }
            }
        }


        // ========================================================
        // GLASS BACKGROUND
        // ========================================================

        color:
            cardMouse.containsMouse
            ? Nexa.Theme.hover
            : "transparent"


        border.width: Nexa.Theme.borderThin
        border.color: Nexa.Theme.border


        // ========================================================
        // SCALE
        // ========================================================

        scale:
            cardMouse.pressed
            ? 0.97
            : cardMouse.containsMouse
                ? 1.02
                : 1.0


        // ========================================================
        // ANIMATIONS
        // ========================================================

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


        // ========================================================
        // CONTENT
        // ========================================================

        Column {
            anchors.centerIn: parent

            spacing: 6


            // ----------------------------------------------------
            // LARGE ICON
            // ----------------------------------------------------

            Text {
                anchors.horizontalCenter:
                    parent.horizontalCenter

                text:
                    card.icon

                color: Nexa.Theme.text

                font {
                    family:
                        Nexa.Theme.fontFamily

                    pixelSize: 31

                    weight:
                        Nexa.Theme.fontWeightMedium
                }
            }


            // ----------------------------------------------------
            // ACTION LABEL
            // ----------------------------------------------------

            Text {
                anchors.horizontalCenter:
                    parent.horizontalCenter

                text:
                    card.label

                color: Nexa.Theme.text

                font {
                    family:
                        Nexa.Theme.fontFamily

                    pixelSize: Nexa.Theme.fontSizeSm

                    weight:
                        Nexa.Theme.fontWeightMedium
                }
            }


            // ----------------------------------------------------
            // SMALL SHORTCUT NUMBER
            // ----------------------------------------------------

            Text {
                anchors.horizontalCenter:
                    parent.horizontalCenter

                text:
                    card.number

                color: Nexa.Theme.mutedText

                font {
                    family:
                        Nexa.Theme.fontFamily

                    pixelSize: 9

                    weight:
                        Nexa.Theme.fontWeightMedium
                }
            }
        }


        // ========================================================
        // BUTTON INPUT
        // ========================================================

        MouseArea {
            id: cardMouse

            anchors.fill: parent

            z: 20

            hoverEnabled: true

            cursorShape:
                Qt.PointingHandCursor


            onClicked: {
                console.log(
                    "NEXA power button clicked:",
                    card.number
                )

                card.triggered()
            }
        }
    }
}
