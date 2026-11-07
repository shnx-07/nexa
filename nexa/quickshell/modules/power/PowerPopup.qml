import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../../NewNexaUI" as NexaUI

PanelWindow {
    id: root

    property var anchorItem: null
    visible: false

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"
    aboveWindows: true
    exclusionMode: ExclusionMode.Ignore
    focusable: visible

    WlrLayershell.namespace: "nexa-power"

    readonly property string nexadBin:
        Quickshell.env("HOME") + "/.config/nexa/rust/target/release/nexad"

    function runLockAction() {
        console.log("NEXA power action: lock")
        Quickshell.execDetached([root.nexadBin, "power", "lock"])
        root.visible = false
    }

    function runPowerAction(action) {
        console.log("NEXA power action:", action)
        Quickshell.execDetached([root.nexadBin, "power", action])
        root.visible = false
    }

    Shortcut {
        sequence: "Escape"
        enabled: root.visible
        onActivated: root.visible = false
    }

    // Fullscreen backdrop
    Rectangle {
        id: backdrop
        anchors.fill: parent
        z: 0
        color: Qt.rgba(0.02, 0.02, 0.02, 0.58)
        opacity: root.visible ? 1.0 : 0.0

        Behavior on opacity {
            NumberAnimation {
                duration: NexaUI.NexaMotion.durationFast
                easing.type: NexaUI.NexaMotion.decelerateEasing
            }
        }

        MouseArea {
            id: backdropMouse
            anchors.fill: parent
            hoverEnabled: false
            onClicked: root.visible = false
        }
    }

    // GPU-Accelerated Nexa Shadow for Power Dialog (Layer 1)
    NexaUI.NexaShadow {
        id: powerShadow
        targetItem: powerContainer
        elevation: 2
        spread: 0.10
    }

    Rectangle {
        id: powerContainer
        anchors.centerIn: parent
        z: 10
        width: powerRow.width + 36
        height: powerRow.height + 30
        radius: NexaUI.NexaTokens.radiusLg
        color: NexaUI.NexaColors.surfaceContainer
        border.width: NexaUI.NexaTokens.borderThin
        border.color: NexaUI.NexaColors.border
        clip: true

        NexaUI.NexaShaderSubstrate {
            anchors.fill: parent
            radius: parent.radius
        }

        // Layer 1 4-stop micro-gradient
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            visible: NexaUI.NexaOptics.surface3DGradient && NexaUI.NexaOptics.gradientIntensity > 0.01
            opacity: NexaUI.NexaOptics.gradientIntensity * 0.75
            gradient: Gradient {
                GradientStop { position: 0.00; color: Qt.rgba(1, 1, 1, 0.06) }
                GradientStop { position: 0.40; color: Qt.rgba(1, 1, 1, 0.02) }
                GradientStop { position: 0.70; color: Qt.rgba(0, 0, 0, 0.00) }
                GradientStop { position: 1.00; color: Qt.rgba(0, 0, 0, 0.12) }
            }
        }

        // Layer 1 Top Specular Chamfer Highlight
        Rectangle {
            anchors.top: parent.top
            anchors.topMargin: 1
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.max(0, parent.width - parent.radius * 1.6)
            height: 1
            visible: NexaUI.NexaOptics.specularHighlight && NexaUI.NexaOptics.specularIntensity > 0.01
            opacity: Math.min(1.0, NexaUI.NexaOptics.specularIntensity / 0.28)
            z: 2
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.35) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        scale: root.visible ? 1.0 : 0.92
        opacity: root.visible ? 1.0 : 0.0

        Behavior on scale {
            enabled: NexaUI.NexaMotion.enabled
            SpringAnimation {
                spring: NexaUI.NexaMotion.useSpring("popups") ? NexaUI.NexaMotion.springStiffness : 8.0
                damping: NexaUI.NexaMotion.useSpring("popups") ? NexaUI.NexaMotion.springDamping : 1.0
                mass: NexaUI.NexaMotion.springMass
                epsilon: 0.002
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: NexaUI.NexaMotion.durationFast
                easing.type: NexaUI.NexaMotion.decelerateEasing
            }
        }

        Row {
            id: powerRow
            anchors.centerIn: parent
            spacing: 12

            PowerCard {
                number: "1"
                label: "Lock"
                icon: "⏻"
                cardIndex: 0
                popupVisible: root.visible
                onTriggered: root.runLockAction()
            }

            PowerCard {
                number: "2"
                label: "Sleep"
                icon: "◐"
                cardIndex: 1
                popupVisible: root.visible
                onTriggered: root.runPowerAction("suspend")
            }

            PowerCard {
                number: "3"
                label: "Logout"
                icon: "⇥"
                cardIndex: 2
                popupVisible: root.visible
                onTriggered: root.runPowerAction("logout")
            }

            PowerCard {
                number: "4"
                label: "Reboot"
                icon: "⏸"
                cardIndex: 3
                popupVisible: root.visible
                onTriggered: root.runPowerAction("reboot")
            }

            PowerCard {
                number: "5"
                label: "Shutdown"
                icon: "◒"
                cardIndex: 4
                popupVisible: root.visible
                contentColor: NexaUI.NexaColors.error
                onTriggered: root.runPowerAction("shutdown")
            }
        }
    }

    // Layer 2 Power Card (Option A)
    component PowerCard: NexaUI.NexaCard {
        id: card

        required property string number
        required property string label
        required property string icon
        property int cardIndex: 0
        property bool popupVisible: false
        property color contentColor: NexaUI.NexaColors.text

        signal triggered()

        width: 138
        height: 120
        interactive: true
        padding: 0

        opacity: popupVisible ? 1.0 : 0.0
        y: popupVisible ? 0 : 14

        Behavior on opacity {
            SequentialAnimation {
                PauseAnimation { duration: card.cardIndex * 35 }
                NumberAnimation {
                    duration: NexaUI.NexaMotion.durationFast
                    easing.type: Easing.OutCubic
                }
            }
        }

        Behavior on y {
            SequentialAnimation {
                PauseAnimation { duration: card.cardIndex * 35 }
                NumberAnimation {
                    duration: NexaUI.NexaMotion.durationNormal
                    easing.type: Easing.OutCubic
                }
            }
        }

        onClicked: {
            console.log("NEXA power button clicked:", card.number)
            card.triggered()
        }

        Column {
            anchors.centerIn: parent
            spacing: 6

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: card.icon
                color: card.contentColor
                font.family: NexaUI.NexaTypography.familyIcon
                font.pixelSize: 31
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: card.label
                color: card.contentColor
                font.family: NexaUI.NexaTypography.familyBody
                font.pixelSize: NexaUI.NexaTypography.sizeSm
                font.weight: Font.Medium
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: card.number
                color: NexaUI.NexaColors.mutedText
                font.family: NexaUI.NexaTypography.familyMono
                font.pixelSize: 9
                font.weight: Font.Medium
            }
        }
    }
}
