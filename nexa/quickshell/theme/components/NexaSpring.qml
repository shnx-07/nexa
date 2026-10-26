import QtQuick
import "../" as Nexa

SpringAnimation {
    id: anim
    property string section: ""
    property real customStiffness: 0
    property real customDamping: 0

    readonly property bool isSpring: Nexa.Theme.useSpring(section)

    spring: isSpring ? (customStiffness > 0 ? customStiffness : Nexa.Theme.springStiffness) : 4.5
    damping: isSpring ? (customDamping > 0 ? customDamping : Nexa.Theme.springDamping) : 1.0
    mass: Nexa.Theme.springMass
    epsilon: 0.1
}
