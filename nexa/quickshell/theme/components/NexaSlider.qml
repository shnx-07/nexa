import QtQuick
import QtQuick.Layouts
import ".." as Nexa

Item {
    id: root

    property real from: 0
    property real to: 100
    property real value: 0
    property real stepSize: 1
    property bool interactive: true

    // Dimensions: default to sleek continuous pill (height 28, radius 14)
    property int sliderHeight: 28
    property int sliderRadius: -1
    property alias pillHeight: root.sliderHeight
    property alias pillRadius: root.sliderRadius
    property color trackColor: Nexa.Theme.cardBackgroundElevated
    property color accentColor: Nexa.Theme.primary

    // Embedded icon
    property string icon: ""
    property string iconPosition: "left"
    property int iconSize: 13
    property bool iconInteractive: false

    // Value readout inside slider (e.g. 70%, 3.8, 0.28)
    property bool showValue: false
    property string valuePrefix: ""
    property string valueSuffix: ""
    property int valueDecimals: 0

    // Live audio pulse reactivity (for mic slider)
    property real livePulse: 0.0

    signal moved(real value)
    signal released(real value)
    signal iconClicked()

    implicitWidth: 220
    implicitHeight: sliderHeight

    readonly property real normalizedValue:
        to <= from ? 0 : Math.max(0, Math.min(1, (value - from) / (to - from)))

    readonly property int effectiveRadius:
        root.sliderRadius > 0 ? root.sliderRadius : Math.round(root.sliderHeight / 2)

    function valueFromPosition(x) {
        const n = Math.max(0, Math.min(1, x / Math.max(1, track.width)))
        let v = from + n * (to - from)
        if (stepSize > 0)
            v = Math.round((v - from) / stepSize) * stepSize + from
        return Math.max(from, Math.min(to, v))
    }

    Item {
        id: container
        anchors.fill: parent

        // Main Track (Apple / Mist liquid glass capsule)
        Rectangle {
            id: track
            anchors.fill: parent
            radius: root.effectiveRadius
            color: root.trackColor
            clip: true

            border.width: Nexa.Theme.borderThin
            border.color: mouse.containsMouse ? Nexa.Theme.edgeHighlightStrong : Nexa.Theme.border

            Behavior on color {
                ColorAnimation {
                    duration: Nexa.Theme.animationNormal
                    easing.type: Nexa.Theme.easingStandard
                    easing.bezierCurve: Nexa.Theme.easingFluidCurve
                }
            }

            Behavior on border.color {
                ColorAnimation {
                    duration: Nexa.Theme.animationFast
                    easing.type: Nexa.Theme.easingStandard
                    easing.bezierCurve: Nexa.Theme.easingFluidCurve
                }
            }

            // Glass reflection highlight on track
            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: Math.max(0, track.radius - 1)
                gradient: Gradient {
                    GradientStop {
                        position: 0.0
                        color: mouse.containsMouse ? Nexa.Theme.edgeHighlightStrong : Nexa.Theme.edgeHighlight
                    }
                    GradientStop { position: 0.55; color: "transparent" }
                }
            }

            // 1. Progress Fill (continuous rounded capsule)
            Rectangle {
                id: progressFill
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: Math.max(0, Math.min(parent.width, parent.width * root.normalizedValue))
                radius: track.radius
                color: root.accentColor

                Behavior on color {
                    ColorAnimation {
                        duration: Nexa.Theme.animationNormal
                        easing.type: Nexa.Theme.easingStandard
                        easing.bezierCurve: Nexa.Theme.easingFluidCurve
                    }
                }

                Behavior on width {
                    enabled: !mouse.pressed && !Nexa.Theme.reducedMotion
                    NexaSpring { section: "sliders" }
                }

                // Inner glass sheen on progress fill
                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.22) }
                        GradientStop { position: 0.55; color: "transparent" }
                    }
                }
            }

            // Live mic dynamic audio reactivity glow
            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                visible: root.livePulse > 0.02
                width: Math.min(progressFill.width, progressFill.width * (0.85 + root.livePulse * 0.25))
                radius: track.radius
                color: Qt.lighter(root.accentColor, 1.25)
                opacity: root.livePulse * 0.7

                Behavior on color {
                    ColorAnimation {
                        duration: Nexa.Theme.animationNormal
                        easing.type: Nexa.Theme.easingStandard
                        easing.bezierCurve: Nexa.Theme.easingFluidCurve
                    }
                }
            }

            // 2. Embedded Leading Icon (Left - Mist Control Center Style)
            Item {
                id: leadingIconArea
                width: 32
                height: parent.height
                anchors.left: parent.left
                anchors.leftMargin: 10
                visible: root.icon !== "" && root.iconPosition === "left"
                z: 3

                Text {
                    anchors.centerIn: parent
                    text: root.icon
                    font.family: Nexa.Theme.iconFontFamily
                    font.pixelSize: root.iconSize
                    color: (progressFill.width > 28) ? Nexa.Theme.onPrimary : Nexa.Theme.text
                    opacity: 0.95

                    Behavior on color {
                        ColorAnimation {
                            duration: Nexa.Theme.animationFast
                            easing.type: Nexa.Theme.easingStandard
                            easing.bezierCurve: Nexa.Theme.easingFluidCurve
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: root.iconInteractive
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: root.iconClicked()
                }
            }

            // 3. Embedded Trailing Icon (Right - for backward compatibility)
            Item {
                id: trailingIconArea
                width: 32
                height: parent.height
                anchors.right: parent.right
                anchors.rightMargin: 10
                visible: root.icon !== "" && root.iconPosition === "right"
                z: 3

                Text {
                    anchors.centerIn: parent
                    text: root.icon
                    font.family: Nexa.Theme.iconFontFamily
                    font.pixelSize: root.iconSize
                    color: root.normalizedValue > 0.88 ? Nexa.Theme.onPrimary : Nexa.Theme.text
                    opacity: 0.95

                    Behavior on color {
                        ColorAnimation {
                            duration: Nexa.Theme.animationFast
                            easing.type: Nexa.Theme.easingStandard
                            easing.bezierCurve: Nexa.Theme.easingFluidCurve
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: root.iconInteractive
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: root.iconClicked()
                }
            }

            // 4. Value Readout (Right aligned inside track)
            Text {
                id: valueText
                anchors.right: parent.right
                anchors.rightMargin: (root.icon !== "" && root.iconPosition === "right") ? 42 : 14
                anchors.verticalCenter: parent.verticalCenter
                visible: root.showValue
                z: 3

                text: root.valuePrefix + (root.valueDecimals > 0 ? root.value.toFixed(root.valueDecimals) : Math.round(root.value)) + root.valueSuffix
                color: (progressFill.width > (parent.width - 60)) ? Nexa.Theme.onPrimary : Nexa.Theme.text
                font {
                    family: Nexa.Theme.fontFamily
                    pixelSize: Nexa.Theme.fontSizeXs
                    weight: Nexa.Theme.fontWeightDemiBold
                    features: Nexa.Theme.fontFeaturesTnum
                }

                Behavior on color {
                    ColorAnimation {
                        duration: Nexa.Theme.animationFast
                        easing.type: Nexa.Theme.easingStandard
                        easing.bezierCurve: Nexa.Theme.easingFluidCurve
                    }
                }
            }
        }

        // 5. Interaction Mouse Area (Prevents scroll stealing)
        MouseArea {
            id: mouse
            anchors.fill: parent
            anchors.leftMargin: (root.iconInteractive && root.iconPosition === "left") ? 40 : 0
            anchors.rightMargin: (root.iconInteractive && root.iconPosition === "right") ? 40 : 0
            enabled: root.interactive
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            preventStealing: true

            onPressed: event => {
                root.value = root.valueFromPosition(event.x + anchors.leftMargin)
                root.moved(root.value)
            }

            onPositionChanged: event => {
                if (!pressed) return
                root.value = root.valueFromPosition(event.x + anchors.leftMargin)
                root.moved(root.value)
            }

            onReleased: root.released(root.value)
        }
    }
}
