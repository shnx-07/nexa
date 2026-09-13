import QtQuick
import ".." as Nexa

Rectangle {
    id: root
    property bool checked: false
    property bool interactive: true
    signal toggled(bool checked)

    implicitWidth: 42
    implicitHeight: 24
    radius: Nexa.Theme.radiusPill
    antialiasing: true
    opacity: interactive ? Nexa.Theme.opacityFull : Nexa.Theme.opacityDisabled
    color: checked ? Nexa.Theme.selectedSurfaceStrong
                   : Nexa.Theme.surfaceContainerHighest
    border.width: Nexa.Theme.borderThin
    border.color: checked ? Nexa.Theme.selectedBorder : Nexa.Theme.border

    // Static glass highlight on the track — cheap, no animation.
    Rectangle {
        anchors.fill: parent
        anchors.margins: root.border.width
        radius: Math.max(0, root.radius - root.border.width)
        gradient: Gradient {
            GradientStop { position: 0.0; color: Nexa.Theme.edgeHighlight }
            GradientStop { position: 0.7; color: "transparent" }
        }
    }

    Rectangle {
        id: thumb
        width: mouse.pressed ? 21 : 18
        height: 18
        radius: height / 2
        antialiasing: true
        anchors.verticalCenter: parent.verticalCenter
        x: root.checked ? root.width - width - 3 : 3
        color: root.checked ? Nexa.Theme.primary : Nexa.Theme.mutedText

        // Width "squish" on press — a fast fluid ease reads as a
        // real physical compression rather than a linear resize.
        Behavior on width {
            enabled: !Nexa.Theme.reducedMotion
            NumberAnimation {
                duration: Nexa.Theme.motionInteraction
                easing.type: Nexa.Theme.easingStandard
                easing.bezierCurve: Nexa.Theme.easingFluidCurve
            }
        }
        // The flick itself is the toggle's signature motion — this
        // is the one Behavior in the whole library that keeps
        // running even under reducedMotion, since a toggle with an
        // instant jump reads as broken rather than economical.
        Behavior on x {
            NumberAnimation {
                duration: Nexa.Theme.motionSelection
                easing.type: Nexa.Theme.easingEmphasized
                easing.bezierCurve: Nexa.Theme.easingSpringCurve
            }
        }
        Behavior on color {
            ColorAnimation {
                duration: Nexa.Theme.motionInteraction
                easing.type: Nexa.Theme.easingStandard
                easing.bezierCurve: Nexa.Theme.easingFluidCurve
            }
        }
    }

    Behavior on color {
        ColorAnimation {
            duration: Nexa.Theme.motionInteraction
            easing.type: Nexa.Theme.easingStandard
            easing.bezierCurve: Nexa.Theme.easingFluidCurve
        }
    }
    Behavior on border.color {
        ColorAnimation {
            duration: Nexa.Theme.motionInteraction
            easing.type: Nexa.Theme.easingStandard
            easing.bezierCurve: Nexa.Theme.easingFluidCurve
        }
    }
    Behavior on opacity {
        NumberAnimation {
            duration: Nexa.Theme.motionInteraction
            easing.type: Nexa.Theme.easingStandard
            easing.bezierCurve: Nexa.Theme.easingFluidCurve
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: root.interactive
        hoverEnabled: true
        cursorShape: root.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: {
            root.checked = !root.checked
            root.toggled(root.checked)
        }
    }
}
