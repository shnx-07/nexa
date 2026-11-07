import QtQuick
import QtQuick.Layouts
import "../core" as Core

Item {
    id: root

    // ============================================================
    // PROPERTIES & API
    // ============================================================
    property real from: 0.0
    property real to: 1.0
    property real stepSize: 0.01
    property real value: 0.0
    property bool interactive: true

    // Dimensions: default to sleek continuous pill or compact track
    property int sliderHeight: (label.length > 0) ? 46 : 28
    property int sliderRadius: -1
    property alias pillHeight: root.sliderHeight
    property alias pillRadius: root.sliderRadius
    property color trackColor: Core.NexaColors.surfaceContainerHighest
    property color accentColor: Core.NexaColors.primary

    // Embedded icon
    property string icon: ""
    property string iconPosition: "left"
    property int iconSize: 13
    property bool iconInteractive: false

    // Value readout inside slider / or in header
    property bool showValue: false
    property string valuePrefix: ""
    property string valueSuffix: ""
    property int valueDecimals: 0

    // Header label mode (for settings sliders)
    property string label: ""
    property string suffix: ""
    property string prefix: ""
    property bool showValueLabel: label.length > 0
    property int decimals: 2

    // Live audio pulse reactivity (for mic slider)
    property real livePulse: 0.0

    signal moved(real value)
    signal released(real value)
    signal iconClicked()

    implicitWidth: 200
    implicitHeight: sliderHeight

    readonly property real normalizedValue:
        to <= from ? 0.0 : Math.max(0.0, Math.min(1.0, (value - from) / (to - from)))

    readonly property int effectiveRadius:
        root.sliderRadius > 0 ? root.sliderRadius : Math.round((root.label.length > 0 ? 6 : root.sliderHeight) / 2)

    function valueFromPosition(x, trackWidth) {
        const n = Math.max(0.0, Math.min(1.0, x / Math.max(1.0, trackWidth)))
        let v = from + n * (to - from)
        if (stepSize > 0)
            v = Math.round((v - from) / stepSize) * stepSize + from
        return Math.max(from, Math.min(to, v))
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 4

        // 1. Header Label & Value Display (when label is set)
        RowLayout {
            Layout.fillWidth: true
            visible: root.label.length > 0 || root.showValueLabel

            Text {
                visible: root.label.length > 0
                text: root.label
                font.family: Core.NexaTypography.familyBody
                font.pixelSize: Core.NexaTypography.sizeSm
                color: Core.NexaColors.text
                Layout.alignment: Qt.AlignLeft
            }

            Item { Layout.fillWidth: true }

            Text {
                visible: root.showValueLabel
                text: (root.prefix !== "" ? root.prefix : root.valuePrefix) + root.value.toFixed(root.decimals > 0 ? root.decimals : root.valueDecimals) + (root.suffix !== "" ? root.suffix : root.valueSuffix)
                font.family: Core.NexaTypography.familyMono
                font.pixelSize: Core.NexaTypography.sizeXs
                color: Core.NexaColors.primary
                Layout.alignment: Qt.AlignRight
            }
        }

        // 2. Track & Capsule Fill Container
        Item {
            id: trackContainer
            Layout.fillWidth: true
            Layout.fillHeight: true

            Rectangle {
                id: trackBg
                anchors.fill: parent
                radius: root.effectiveRadius
                color: root.trackColor
                clip: true

                border.width: Core.NexaTokens.borderThin
                border.color: mouseArea.containsMouse ? Core.NexaColors.primary : Core.NexaColors.border

                scale: (mouseArea.pressed && root.interactive) ? 0.985 : (mouseArea.containsMouse ? 1.005 : 1.0)
                Behavior on scale {
                    enabled: Core.NexaMotion.enabled
                    SpringAnimation {
                        spring: Core.NexaMotion.springStiffness
                        damping: Core.NexaMotion.springDamping
                        mass: Core.NexaMotion.springMass
                        epsilon: 0.002
                    }
                }

                Behavior on color {
                    ColorAnimation { duration: Core.NexaMotion.durationNormal }
                }
                Behavior on border.color {
                    ColorAnimation { duration: Core.NexaMotion.durationInstant }
                }

                // Top Specular Highlight (Layer 2 specular beam)
                Rectangle {
                    anchors.top: parent.top
                    anchors.topMargin: 1
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: trackBg.radius > 0 ? Math.max(0, parent.width - trackBg.radius * 1.6) : parent.width
                    height: 1
                    visible: Core.NexaOptics.specularHighlight && Core.NexaOptics.specularIntensity > 0.01
                    opacity: Math.min(1.0, Core.NexaOptics.specularIntensity / 0.28)
                    z: 2
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.35) }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                }

                // Progress Fill
                Rectangle {
                    id: progressFill
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: Math.max(0, Math.min(parent.width, parent.width * root.normalizedValue))
                    radius: trackBg.radius
                    color: root.accentColor

                    Behavior on width {
                        enabled: Core.NexaMotion.enabled && !mouseArea.pressed
                        SpringAnimation {
                            spring: Core.NexaMotion.useSpring("sliders") ? Core.NexaMotion.springStiffness : 8.0
                            damping: Core.NexaMotion.useSpring("sliders") ? Core.NexaMotion.springDamping : 1.0
                            mass: Core.NexaMotion.springMass
                            epsilon: 0.5
                        }
                    }

                    // Micro-gradient
                    Rectangle {
                        anchors.fill: parent
                        radius: progressFill.radius
                        visible: Core.NexaOptics.surface3DGradient && Core.NexaOptics.gradientIntensity > 0.01
                        opacity: Core.NexaOptics.gradientIntensity * 0.75
                        gradient: Gradient {
                            GradientStop { position: 0.00; color: Qt.rgba(1, 1, 1, 0.15) }
                            GradientStop { position: 0.45; color: Qt.rgba(1, 1, 1, 0.03) }
                            GradientStop { position: 0.70; color: Qt.rgba(0, 0, 0, 0.00) }
                            GradientStop { position: 1.00; color: Qt.rgba(0, 0, 0, 0.15) }
                        }
                    }

                    Behavior on color {
                        ColorAnimation { duration: Core.NexaMotion.durationNormal }
                    }
                }

                // Live mic dynamic audio reactivity glow
                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    visible: root.livePulse > 0.02
                    width: Math.min(progressFill.width, progressFill.width * (0.85 + root.livePulse * 0.25))
                    radius: trackBg.radius
                    color: Qt.lighter(root.accentColor, 1.25)
                    opacity: root.livePulse * 0.7

                    Behavior on color {
                        ColorAnimation { duration: Core.NexaMotion.durationNormal }
                    }
                }

                // Leading Icon (Left - Mist Control Center Style)
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
                        font.family: Core.NexaTypography.familyIcon
                        font.pixelSize: root.iconSize
                        color: (progressFill.width > 28) ? Core.NexaColors.onPrimary : Core.NexaColors.text
                        opacity: 0.95

                        Behavior on color {
                            ColorAnimation { duration: Core.NexaMotion.durationInstant }
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

                // Trailing Icon (Right)
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
                        font.family: Core.NexaTypography.familyIcon
                        font.pixelSize: root.iconSize
                        color: root.normalizedValue > 0.88 ? Core.NexaColors.onPrimary : Core.NexaColors.text
                        opacity: 0.95

                        Behavior on color {
                            ColorAnimation { duration: Core.NexaMotion.durationInstant }
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

                // Value Readout inside track (when showValue is true)
                Text {
                    id: inTrackValueText
                    anchors.right: parent.right
                    anchors.rightMargin: (root.icon !== "" && root.iconPosition === "right") ? 42 : 14
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.showValue
                    z: 3

                    text: root.valuePrefix + (root.valueDecimals > 0 ? root.value.toFixed(root.valueDecimals) : Math.round(root.value)) + root.valueSuffix
                    color: (progressFill.width > (parent.width - 60)) ? Core.NexaColors.onPrimary : Core.NexaColors.text
                    font.family: Core.NexaTypography.familyMono
                    font.pixelSize: Core.NexaTypography.sizeXs
                    font.weight: Font.DemiBold

                    Behavior on color {
                        ColorAnimation { duration: Core.NexaMotion.durationInstant }
                    }
                }
            }

            // Interactive MouseArea
            MouseArea {
                id: mouseArea
                anchors.fill: parent
                anchors.leftMargin: (root.iconInteractive && root.iconPosition === "left") ? 40 : 0
                anchors.rightMargin: (root.iconInteractive && root.iconPosition === "right") ? 40 : 0
                enabled: root.interactive
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                preventStealing: true

                onPressed: function(event) {
                    root.value = root.valueFromPosition(event.x + anchors.leftMargin, trackContainer.width);
                    root.moved(root.value);
                }

                onPositionChanged: function(event) {
                    if (!pressed) return;
                    root.value = root.valueFromPosition(event.x + anchors.leftMargin, trackContainer.width);
                    root.moved(root.value);
                }

                onReleased: function() {
                    root.released(root.value);
                }
            }
        }
    }
}
