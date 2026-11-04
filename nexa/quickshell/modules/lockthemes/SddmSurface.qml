import QtQuick
import Quickshell
import "../../services" as Services
import "../sddm/shim"

Item {
    id: root

    anchors.fill: parent
    focus: true

    property string themeId: Services.Sddm.activeDesktopSddmTheme || "material-you-dark"
    readonly property string themePath: Quickshell.env("HOME") + "/.config/nexa/sddm/themes/" + root.themeId

    // SDDM environment properties injected into theme scope
    readonly property var sddm: sddmShim.sddm
    readonly property var config: sddmShim.config
    readonly property var userModel: sddmShim.userModel
    readonly property var sessionModel: sddmShim.sessionModel

    signal authenticationSucceeded()

    SddmShim {
        id: sddmShim
        themePath: root.themePath
    }

    Connections {
        target: sddmShim.sddm
        function onLoginSucceeded() {
            root.authenticationSucceeded();
        }
    }

    // Background input absorber & cursor normalizer
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.ArrowCursor
        z: -1
    }

    Loader {
        id: themeLoader
        anchors.fill: parent
        source: "file://" + root.themePath + "/Main.qml"

        onLoaded: {
            if (item) {
                item.forceActiveFocus();
            }
        }

        onStatusChanged: {
            if (status === Loader.Error) {
                console.error("[SddmSurface] Failed to load SDDM theme:", source);
            }
        }
    }

    Component.onDestruction: {
        themeLoader.source = "";
    }
}
