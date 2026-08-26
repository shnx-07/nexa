import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

import "../../theme" as Nexa


PanelWindow {
    id: root


    // ============================================================
    // POWER POPUP
    // ============================================================

    property var anchorItem: null

    visible: false

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"

    aboveWindows: true
    exclusionMode: ExclusionMode.Ignore

    focusable: visible


    // ============================================================
    // HYPRLAND LAYER
    // ============================================================

    WlrLayershell.namespace: "nexa-power"


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

        root.visible = false
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

        root.visible = false
    }

    Process {
        id: lockProcess
    }

    Process {
        id: powerProcess
    }


    // ============================================================
    // ESCAPE
    // ============================================================

    Shortcut {
        sequence: "Escape"

        enabled: root.visible

        onActivated:
            root.visible = false
    }


    // ============================================================
    // FULLSCREEN BACKGROUND
    // ============================================================

    Rectangle {
        id: backdrop

        anchors.fill: parent

        z: 0

        color: Qt.rgba(
            0.02,
            0.02,
            0.02,
            0.58
        )

        opacity: root.visible ? 1.0 : 0.0

        Behavior on opacity {
            NumberAnimation {
                duration: 200
                easing.type: Nexa.Theme.easingEnter
            }
        }


        // Clicking outside the power controls closes the popup.

        MouseArea {
            id: backdropMouse

            anchors.fill: parent

            hoverEnabled: false

            onClicked:
                root.visible = false
        }
    }


    // ============================================================
    // POWER CONTAINER
    // ============================================================

    Rectangle {
        id: powerContainer

        anchors.centerIn: parent

        z: 10

        width:
            powerRow.width + 36

        height:
            powerRow.height + 30

        radius: 16

        color: Qt.rgba(
            0.03,
            0.03,
            0.03,
            0.52
        )

        border.width: 0


        // Spring entrance when popup opens
        scale: root.visible ? 1.0 : 0.90
        opacity: root.visible ? 1.0 : 0.0

        Behavior on scale {
            NumberAnimation {
                duration: Nexa.Theme.animationSpring
                easing.type: Nexa.Theme.easingSpring
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Nexa.Theme.popEnterDuration
                easing.type: Nexa.Theme.easingEnter
            }
        }


        // ========================================================
        // POWER BUTTON ROW
        // ========================================================

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
            ? Qt.rgba(
                0.10,
                0.10,
                0.10,
                0.32
            )
            : Qt.rgba(
                0.05,
                0.05,
                0.05,
                0.72
            )


        border.width: 0


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

                color: Qt.rgba(
                    1,
                    1,
                    1,
                    0.95
                )

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

                color: Qt.rgba(
                    1,
                    1,
                    1,
                    0.80
                )

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

                color: Qt.rgba(
                    1,
                    1,
                    1,
                    0.40
                )

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
