import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "quickshell"
    WlrLayershell.keyboardFocus: windowAlive ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    aboveWindows: true
    focusable: true
    color: "transparent"

    visible: windowAlive
    property bool windowAlive: false

    function openWindow() {
        windowAlive = true
        panel.open()
        panel.forceActiveFocus()
    }

    function closeWindow() {
        panel.close()
    }

    function toggleWindow() {
        if (!windowAlive || !panel.visible) {
            openWindow()
        } else {
            closeWindow()
        }
    }

    SettingsPanel {
        id: panel
        width: root.width
        height: root.height

        Connections {
            target: panel
            function onVisibleChanged() {
                if (!panel.visible) {
                    root.windowAlive = false
                }
            }
        }
    }
}
