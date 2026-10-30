pragma Singleton
import Quickshell
import Quickshell.Services.UPower

Singleton {
    id: root
    readonly property real percentage: {
        const dev = UPower.displayDevice;
        return (dev && dev.ready) ? Math.round(dev.percentage * 100) : 50;
    }
    readonly property bool charging: UPower.displayDevice ? !UPower.onBattery : false
    readonly property string nexad: Quickshell.env("HOME") + "/.config/nexa/rust/target/release/nexad"

    property bool _initialized: false
    property bool _fullAlerted: false
    property bool _lowAlerted: false

    onChargingChanged: {
        Quickshell.execDetached([root.nexad, "hypr", "idle", "sync"])
        if (!root._initialized) {
            root._initialized = true
            return
        }
        if (root.charging) {
            root._lowAlerted = false
            Quickshell.execDetached([root.nexad, "sound", "play", "charging_cable_insert"])
        } else {
            root._fullAlerted = false
            Quickshell.execDetached([root.nexad, "sound", "play", "charging_cable_remove"])
        }
    }

    onPercentageChanged: {
        if (!root._initialized) return
        if (root.percentage >= 100 && root.charging && !root._fullAlerted) {
            root._fullAlerted = true
            Quickshell.execDetached([root.nexad, "sound", "play", "Full-battery-charge"])
        } else if (root.percentage <= 20 && !root.charging && !root._lowAlerted) {
            root._lowAlerted = true
            Quickshell.execDetached([root.nexad, "sound", "play", "low_battery"])
        }
    }
}