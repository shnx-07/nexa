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

    // Dimensions matching reference screenshot (sleek, non-bulky)
    property int sliderHeight: 34
    property int sliderRadius: 10
    property alias pillHeight: root.sliderHeight
    property alias pillRadius: root.sliderRadius
    property color trackColor: Nexa.Theme.cardBackgroundElevated
    property color accentColor: Nexa.Theme.primary

    // Embedded trailing icon (e.g. sun, speaker, mic)
    property string icon: ""
    property int iconSize: 15
    property bool iconInteractive: false

    // Live audio pulse reactivity (for mic slider)
    property real livePulse: 0.0

    signal moved(real value)
    signal released(real value)
    signal iconClicked()

    implicitWidth: 220
    implicitHeight: sliderHeight

    readonly property real normalizedValue:
        to <= from ? 0 : Math.max(0, Math.min(1, (value - from) / (to - from)))

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

        // Main Track
        Rectangle {
            id: track
            anchors.fill: parent
            radius: root.sliderRadius
            color: root.trackColor
            clip: true

            border.width: Nexa.Theme.borderThin
            border.color: mouse.containsMouse ? Nexa.Theme.borderStrong : Nexa.Theme.border

            Behavior on border.color {
                ColorAnimation { duration: Nexa.Theme.animationFast }
            }

            // 1. Progress Fill
            Rectangle {
                id: progressFill
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: Math.max(0, Math.min(parent.width, parent.width * root.normalizedValue))
                radius: track.radius
                color: root.accentColor

                Behavior on width {
                    enabled: !mouse.pressed
                    NumberAnimation {
                        duration: 80
                        easing.type: Easing.OutCubic
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
            }

            // 2. Trailing Icon (sun / speaker / mic)
            Item {
                id: iconArea
                width: 40
                height: parent.height
                anchors.right: parent.right
                anchors.rightMargin: 8
                visible: root.icon !== ""

                Text {
                    anchors.centerIn: parent
                    text: root.icon
                    font.family: Nexa.Theme.iconFontFamily
                    font.pixelSize: root.iconSize
                    color: root.normalizedValue > 0.88 ? Nexa.Theme.primaryContainerText : Nexa.Theme.text
                    opacity: 0.95

                    Behavior on color {
                        ColorAnimation { duration: Nexa.Theme.animationFast }
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
        }

        // 3. Vertical Divider Line (Matches reference screenshot: slightly taller than track)
        Rectangle {
            id: dividerLine
            width: 2.5
            height: track.height + 4
            radius: 1.25
            anchors.verticalCenter: track.verticalCenter
            x: Math.max(0, Math.min(track.width - width, track.width * root.normalizedValue - width / 2))
            visible: root.normalizedValue > 0.005 && root.normalizedValue < 0.995
            color: "#ffffff"
            opacity: mouse.pressed ? 1.0 : (mouse.containsMouse ? 0.95 : 0.9)

            Behavior on x {
                enabled: !mouse.pressed
                NumberAnimation {
                    duration: 80
                    easing.type: Easing.OutCubic
                }
            }
        }

        // 4. Interaction Mouse Area (NO WHEEL EVENT - PREVENTS SCROLL ACCIDENTS)
        MouseArea {
            id: mouse
            anchors.fill: parent
            anchors.rightMargin: root.iconInteractive ? 44 : 0
            enabled: root.interactive
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            preventStealing: true

            onPressed: event => {
                root.value = root.valueFromPosition(event.x)
                root.moved(root.value)
            }

            onPositionChanged: event => {
                if (!pressed) return
                root.value = root.valueFromPosition(event.x)
                root.moved(root.value)
            }

            onReleased: root.released(root.value)
        }
    }
}
