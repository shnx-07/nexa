import QtQuick
import Quickshell
import Quickshell.Io

Process {
    id: root

    property var data: null
    property string rawOutput: ""
    property string errorOutput: ""
    property bool loading: false

    signal success(var data)
    signal failure(string message)

    stdout: StdioCollector {
        onStreamFinished: {
            root.rawOutput = text.trim()
            if (root.rawOutput.length === 0) {
                root.loading = false
                return
            }
            try {
                root.data = JSON.parse(root.rawOutput)
                root.errorOutput = ""
                root.success(root.data)
            } catch (e) {
                root.errorOutput = "Failed to parse JSON"
                root.failure(root.errorOutput)
            }
            root.loading = false
        }
    }

    stderr: StdioCollector {
        onStreamFinished: {
            const err = text.trim()
            if (err.length > 0) {
                root.errorOutput = err
                root.failure(err)
            }
        }
    }

    onRunningChanged: {
        if (running) {
            root.loading = true
            root.errorOutput = ""
        }
    }
}
