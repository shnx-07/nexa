import QtQuick
import QtQuick.Layouts

import "../../NewNexaUI" as NexaUI


Row {
    id: root

    // ------------------------------------------------------------
    // NETWORK SECTION
    //
    // Top Bar sees only this component.
    // Wi-Fi and Bluetooth own their own state/UI.
    // ------------------------------------------------------------

    spacing: 0

    Wifi {}
    Bluetooth {}
}
