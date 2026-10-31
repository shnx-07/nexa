pragma Singleton
import Quickshell
import "." as Services

Singleton {
    id: root

    readonly property real percentage: Services.SystemState.batteryPercentage
    readonly property bool charging: Services.SystemState.batteryCharging
    readonly property bool onBattery: Services.SystemState.onBattery
}
