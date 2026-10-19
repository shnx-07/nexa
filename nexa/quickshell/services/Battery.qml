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
}

