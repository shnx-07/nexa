import QtQuick
import QtQuick.Layouts

import "../../theme" as Nexa


RowLayout {
    id: root

    // ------------------------------------------------------------
    // NETWORK SECTION
    //
    // Top Bar sees only this component.
    // Wi-Fi and Bluetooth own their own state/UI.
    // ------------------------------------------------------------

    spacing: Nexa.Theme.spacing2Xs

    Wifi {}
    Bluetooth {}
}
