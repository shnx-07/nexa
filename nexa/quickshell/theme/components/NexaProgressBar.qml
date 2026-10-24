import QtQuick
import ".." as Nexa

Rectangle {
    id: root

    // ============================================================
    // PROPERTIES & API
    // ============================================================
    property real from: 0.0
    property real to: 1.0
    property real value: 0.0

    // Visual options
    property color barColor: Nexa.Theme.primary
    property color trackColor: Nexa.Theme.surfaceContainerHighest
    property bool animated: true

    // Computed fraction [0.0 - 1.0]
    readonly property real progress: {
        const range = root.to - root.from
        if (range <= 0) return 0.0
        return Math.max(0.0, Math.min(1.0, (root.value - root.from) / range))
    }

    implicitWidth: 200
    implicitHeight: 6
    radius: Nexa.Theme.radiusPill
    antialiasing: true
    color: trackColor
    clip: true

    // The Active Fill Bar
    Rectangle {
        id: fillBar
        height: parent.height
        width: Math.max(0, parent.width * root.progress)
        radius: parent.radius
        color: root.barColor
        antialiasing: true

        Behavior on width {
            enabled: root.animated && !Nexa.Theme.reducedMotion
            NumberAnimation {
                duration: Nexa.Theme ? Nexa.Theme.animationFast : 130
                easing.type: Nexa.Theme.easingStandard
                easing.bezierCurve: Nexa.Theme.easingFluidCurve
            }
        }

        Behavior on color {
            ColorAnimation {
                duration: Nexa.Theme ? Nexa.Theme.animationFast : 130
                easing.type: Nexa.Theme.easingStandard
            }
        }
    }
}
