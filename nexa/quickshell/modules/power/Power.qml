import QtQuick
import Quickshell
import "../../NewNexaUI" as NexaUI

Item {
    id: root

    // ============================================================
    // SIZE
    // ============================================================
    implicitWidth: NexaUI.NexaTokens.controlHeightSm
    implicitHeight: NexaUI.NexaTokens.controlHeightSm

    // ============================================================
    // POWER BUTTON
    // ============================================================
    NexaUI.NexaButton {
        id: button
        anchors.fill: parent
        variant: "icon"
        radius: height / 2
        icon: "⏻"
        iconColor: NexaUI.NexaColors.error
        onClicked: {
            Quickshell.execDetached([
                "qs",
                "-p",
                Quickshell.env("HOME") + "/.config/nexa/quickshell",
                "ipc",
                "call",
                "nexaIsland",
                "openPower"
            ])
        }
    }
}
