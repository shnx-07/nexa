import QtQuick
import Quickshell
import Quickshell.Io
import "../../NewNexaUI" as NexaUI

Item {
    id: root

    signal requestClose()

    // ============================================================
    // FOCUS & KEYBOARD TRIGGER
    // ============================================================

    focus: true

    function activate() {
        forceActiveFocus()
    }

    function triggerKeyNumber(num) {
        if (num === 1) {
            runLockAction()
        } else if (num === 2) {
            runPowerAction("suspend")
        } else if (num === 3) {
            runPowerAction("logout")
        } else if (num === 4) {
            runPowerAction("reboot")
        } else if (num === 5) {
            runPowerAction("shutdown")
        }
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_1 || event.text === "1") {
            root.runLockAction()
            event.accepted = true
        } else if (event.key === Qt.Key_2 || event.text === "2") {
            root.runPowerAction("suspend")
            event.accepted = true
        } else if (event.key === Qt.Key_3 || event.text === "3") {
            root.runPowerAction("logout")
            event.accepted = true
        } else if (event.key === Qt.Key_4 || event.text === "4") {
            root.runPowerAction("reboot")
            event.accepted = true
        } else if (event.key === Qt.Key_5 || event.text === "5") {
            root.runPowerAction("shutdown")
            event.accepted = true
        } else if (event.key === Qt.Key_Escape) {
            root.requestClose()
            event.accepted = true
        }
    }

    onVisibleChanged: {
        if (visible) {
            Qt.callLater(function() {
                forceActiveFocus()
            })
        }
    }

    readonly property string nexadBin:
        Quickshell.env("HOME") + "/.config/nexa/rust/target/release/nexad"

    // ============================================================
    // POWER COMMAND
    // ============================================================
    function runLockAction() {
        console.log("NEXA power action: lock")
        Quickshell.execDetached([root.nexadBin, "power", "lock"])
        root.requestClose()
    }

    function runPowerAction(action) {
        console.log("NEXA power action:", action)
        Quickshell.execDetached([root.nexadBin, "power", action])
        root.requestClose()
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

        // 1 — LOCK
        PowerCard {
            number: "1"
            label: "Lock"
            icon: "⏻"
            cardIndex: 0
            popupVisible: root.visible
            onTriggered: root.runLockAction()
        }

        // 2 — SUSPEND
        PowerCard {
            number: "2"
            label: "Sleep"
            icon: "◐"
            cardIndex: 1
            popupVisible: root.visible
            onTriggered: root.runPowerAction("suspend")
        }

        // 3 — LOGOUT
        PowerCard {
            number: "3"
            label: "Logout"
            icon: "⇥"
            cardIndex: 2
            popupVisible: root.visible
            onTriggered: root.runPowerAction("logout")
        }

        // 4 — REBOOT
        PowerCard {
            number: "4"
            label: "Reboot"
            icon: "⏸"
            cardIndex: 3
            popupVisible: root.visible
            onTriggered: root.runPowerAction("reboot")
        }

        // 5 — SHUTDOWN
        PowerCard {
            number: "5"
            label: "Shutdown"
            icon: "◒"
            cardIndex: 4
            popupVisible: root.visible
            contentColor: NexaUI.NexaColors.error
            onTriggered: root.runPowerAction("shutdown")
        }
    }

    // ============================================================
    // POWER CARD (Layer 2 card - Option A)
    // ============================================================

    component PowerCard: NexaUI.NexaCard {
        id: card

        required property string number
        required property string label
        required property string icon
        property int cardIndex: 0
        property bool popupVisible: false
        property color contentColor: NexaUI.NexaColors.text

        signal triggered()

        width: 138
        height: 120

        opacity: popupVisible ? 1.0 : 0.0
        y: popupVisible ? 0 : 14

        Behavior on opacity {
            SequentialAnimation {
                PauseAnimation { duration: card.cardIndex * 35 }
                NumberAnimation {
                    duration: NexaUI.NexaMotion.durationFast
                    easing.type: Easing.OutCubic
                }
            }
        }

        Behavior on y {
            SequentialAnimation {
                PauseAnimation { duration: card.cardIndex * 35 }
                NumberAnimation {
                    duration: NexaUI.NexaMotion.durationNormal
                    easing.type: Easing.OutCubic
                }
            }
        }

        interactive: true
        padding: 0
        onClicked: {
            console.log("NEXA power button clicked:", card.number)
            card.triggered()
        }

        Column {
            anchors.centerIn: parent
            spacing: 6

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: card.icon
                color: card.contentColor
                font.family: NexaUI.NexaTypography.familyIcon
                font.pixelSize: 31
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: card.label
                color: card.contentColor
                font.family: NexaUI.NexaTypography.familyBody
                font.pixelSize: NexaUI.NexaTypography.sizeSm
                font.weight: Font.Medium
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: card.number
                color: NexaUI.NexaColors.mutedText
                font.family: NexaUI.NexaTypography.familyMono
                font.pixelSize: 9
                font.weight: Font.Medium
            }
        }
    }
}
