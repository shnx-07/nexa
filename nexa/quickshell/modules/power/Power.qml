import QtQuick
import Quickshell
import "../../theme" as Nexa
import "../../theme/components" as NexaUI


Item {
    id: root


    // ============================================================
    // SIZE
    // ============================================================

    implicitWidth: Nexa.Theme.controlHeightSm
    implicitHeight: Nexa.Theme.controlHeightSm


    // ============================================================
    // POWER BUTTON
    // ============================================================

    NexaUI.NexaIconButton {
        id: button
        anchors.fill: parent
        radius: height / 2
        icon: "⏻"
        iconColor: Nexa.Theme.error
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
