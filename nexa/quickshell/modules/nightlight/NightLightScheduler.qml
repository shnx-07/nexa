import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    readonly property string nexad:
        Quickshell.env("HOME") + "/.config/nexa/rust/target/release/nexad"

    Process {
        id: evalProcess
        command: [root.nexad, "screenTemp", "evaluate-schedule"]
        stdout: StdioCollector {}
    }

    Timer {
        id: scheduleTimer
        interval: 30000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            if (!evalProcess.running) {
                evalProcess.running = true
            }
        }
    }
}
