import QtQuick
import QtQuick.Layouts
import ".." as Nexa

Rectangle {
    id: root

    // ============================================================
    // PROPERTIES & API
    // ============================================================
    property alias text: input.text
    property alias placeholderText: placeholder.text
    property alias echoMode: input.echoMode
    property alias readOnly: input.readOnly
    property alias inputFocus: input.focus
    property alias font: input.font
    property alias validator: input.validator
    property alias cursorPosition: input.cursorPosition

    property string icon: ""
    property bool showClearButton: true
    property bool clearable: showClearButton && input.text.length > 0 && !input.readOnly

    signal accepted()
    signal textEdited()
    signal cleared()

    function forceActiveFocus() {
        input.forceActiveFocus()
    }

    function clear() {
        input.text = ""
        root.cleared()
    }

    // Sizing & Appearance
    implicitWidth: 260
    implicitHeight: Nexa.Theme.controlHeightMd
    radius: Nexa.Theme.radiusMd
    antialiasing: true

    color: input.activeFocus ? Nexa.Theme.surfaceContainerHighest : Nexa.Theme.surfaceContainer
    border.width: input.activeFocus ? Nexa.Theme.borderThick : Nexa.Theme.borderThin
    border.color: input.activeFocus ? Nexa.Theme.primary : Nexa.Theme.border

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

    // Static subtle glass highlight on top edge
    Rectangle {
        anchors.fill: parent
        anchors.margins: root.border.width
        radius: Math.max(0, root.radius - root.border.width)
        gradient: Gradient {
            GradientStop { position: 0.0; color: Nexa.Theme.edgeHighlight }
            GradientStop { position: 0.6; color: "transparent" }
        }
    }

    // ============================================================
    // CONTENT LAYOUT
    // ============================================================
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Nexa.Theme.spacingMd
        anchors.rightMargin: Nexa.Theme.spacingSm
        spacing: Nexa.Theme.spacingSm

        // Left Icon (optional)
        Text {
            visible: root.icon.length > 0
            text: root.icon
            font.family: Nexa.Theme.iconFont
            font.pixelSize: Nexa.Theme.iconSizeSm
            color: input.activeFocus ? Nexa.Theme.primary : Nexa.Theme.mutedText
            Layout.alignment: Qt.AlignVCenter

            Behavior on color {
                ColorAnimation { duration: Nexa.Theme.motionInteraction }
            }
        }

        // Main Input Area & Placeholder
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Text {
                id: placeholder
                anchors.fill: parent
                verticalAlignment: Text.AlignVCenter
                text: "Type here..."
                color: Nexa.Theme.mutedText
                font.family: Nexa.Theme.fontFamily
                font.pixelSize: Nexa.Theme.fontSizeSm
                opacity: input.text.length === 0 ? 0.6 : 0.0
                visible: opacity > 0

                Behavior on opacity {
                    NumberAnimation { duration: Nexa.Theme.motionInteraction }
                }
            }

            TextInput {
                id: input
                anchors.fill: parent
                verticalAlignment: TextInput.AlignVCenter
                color: Nexa.Theme.text
                font.family: Nexa.Theme.fontFamily
                font.pixelSize: Nexa.Theme.fontSizeSm
                clip: true
                selectByMouse: true
                selectionColor: Nexa.Theme.primary
                selectedTextColor: Nexa.Theme.on_primary

                onAccepted: root.accepted()
                onTextEdited: root.textEdited()
            }
        }

        // Clear Button (×)
        Rectangle {
            id: clearBtn
            visible: root.clearable
            Layout.preferredWidth: 20
            Layout.preferredHeight: 20
            radius: height / 2
            color: clearMouse.containsMouse ? Nexa.Theme.surfaceBright : "transparent"
            Layout.alignment: Qt.AlignVCenter

            Text {
                anchors.centerIn: parent
                text: "✕"
                font.pixelSize: 11
                color: clearMouse.containsMouse ? Nexa.Theme.text : Nexa.Theme.mutedText
            }

            MouseArea {
                id: clearMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.clear()
                    input.forceActiveFocus()
                }
            }
        }
    }

    // Clicking anywhere in the rectangle gives focus to the TextInput
    MouseArea {
        anchors.fill: parent
        z: -1
        cursorShape: Qt.IBeamCursor
        onClicked: input.forceActiveFocus()
    }
}
