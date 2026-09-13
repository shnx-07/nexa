import QtQuick
import QtQuick.Controls
import ".." as Nexa

ComboBox {
    id: root
    implicitWidth: 170
    implicitHeight: Nexa.Theme.controlHeightMd

    leftPadding: Nexa.Theme.spacingMd
    rightPadding: Nexa.Theme.spacingLg + Nexa.Theme.iconSm

    contentItem: Text {
        text: root.displayText
        color: Nexa.Theme.text
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        font.family: Nexa.Theme.fontFamily
        font.pixelSize: Nexa.Theme.fontSizeSm
    }

    indicator: Text {
        anchors.right: parent.right
        anchors.rightMargin: Nexa.Theme.spacingMd
        anchors.verticalCenter: parent.verticalCenter
        text: "󰅀"
        color: root.popup.visible ? Nexa.Theme.primary : Nexa.Theme.mutedText
        font.family: Nexa.Theme.iconFontFamily
        font.pixelSize: Nexa.Theme.iconSm
        rotation: root.popup.visible ? 180 : 0
        // Symmetric fluid rotation — no overshoot, this is a small
        // glyph, a spring bounce on it would look noisy.
        Behavior on rotation {
            enabled: !Nexa.Theme.reducedMotion
            NumberAnimation {
                duration: Nexa.Theme.motionSelection
                easing.type: Nexa.Theme.easingFluidInOut
                easing.bezierCurve: Nexa.Theme.easingFluidInOutCurve
            }
        }
        Behavior on color {
            ColorAnimation {
                duration: Nexa.Theme.animationFast
                easing.type: Nexa.Theme.easingStandard
                easing.bezierCurve: Nexa.Theme.easingFluidCurve
            }
        }
    }

    background: Rectangle {
        radius: Nexa.Theme.radiusMd
        antialiasing: true
        color: root.down ? Nexa.Theme.buttonBackgroundPressed
                         : root.hovered ? Nexa.Theme.buttonBackgroundHover
                         : Nexa.Theme.buttonBackground
        border.width: Nexa.Theme.borderThin
        border.color: root.popup.visible ? Nexa.Theme.selectedBorder : Nexa.Theme.border

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
    }

    delegate: ItemDelegate {
        width: ListView.view ? ListView.view.width : root.width
        height: Nexa.Theme.controlHeightMd
        highlighted: root.highlightedIndex === index

        contentItem: Text {
            text: root.textRole !== "" && model ? model[root.textRole] : modelData
            color: root.currentIndex === index ? Nexa.Theme.primary : Nexa.Theme.text
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
            font.family: Nexa.Theme.fontFamily
            font.pixelSize: Nexa.Theme.fontSizeSm

            Behavior on color {
                ColorAnimation {
                    duration: Nexa.Theme.animationFast
                    easing.type: Nexa.Theme.easingStandard
                    easing.bezierCurve: Nexa.Theme.easingFluidCurve
                }
            }
        }

        background: Rectangle {
            radius: Nexa.Theme.radiusSm
            antialiasing: true
            color: root.currentIndex === index ? Nexa.Theme.selectedSurface
                                               : highlighted ? Nexa.Theme.hoverStrong
                                               : "transparent"

            Behavior on color {
                ColorAnimation {
                    duration: Nexa.Theme.animationFast
                    easing.type: Nexa.Theme.easingStandard
                    easing.bezierCurve: Nexa.Theme.easingFluidCurve
                }
            }
        }
    }

    popup: Popup {
        y: root.height + Nexa.Theme.spacingXs
        width: root.width
        padding: Nexa.Theme.spacingXs

        contentItem: ListView {
            clip: true
            implicitHeight: Math.min(contentHeight, 250)
            model: root.popup.visible ? root.delegateModel : null
            currentIndex: root.highlightedIndex
            boundsBehavior: Flickable.StopAtBounds
            flickDeceleration: Nexa.Theme.flickDeceleration
            maximumFlickVelocity: Nexa.Theme.flickVelocityMax
            ScrollIndicator.vertical: ScrollIndicator {}
        }

        background: Rectangle {
            radius: Nexa.Theme.radiusMd
            color: Nexa.Theme.popupBackground
            border.width: Nexa.Theme.borderThin
            border.color: Nexa.Theme.borderStrong

            NexaShadow {
                elevation: 1
                cornerRadius: Nexa.Theme.radiusMd
            }
        }

        enter: Transition {
            ParallelAnimation {
                NumberAnimation {
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: Nexa.Theme.popEnterDuration
                    easing.type: Nexa.Theme.easingStandard
                    easing.bezierCurve: Nexa.Theme.easingFluidCurve
                }
                NumberAnimation {
                    property: "scale"
                    from: 0.95
                    to: 1
                    duration: Nexa.Theme.popEnterDuration
                    easing.type: Nexa.Theme.easingEnter
                    easing.bezierCurve: Nexa.Theme.easingSpringCurve
                }
                NumberAnimation {
                    property: "y"
                    from: root.height
                    to: root.height + Nexa.Theme.spacingXs
                    duration: Nexa.Theme.popEnterDuration
                    easing.type: Nexa.Theme.easingStandard
                    easing.bezierCurve: Nexa.Theme.easingFluidCurve
                }
            }
        }

        exit: Transition {
            ParallelAnimation {
                NumberAnimation {
                    property: "opacity"
                    from: 1
                    to: 0
                    duration: Nexa.Theme.popExitDuration
                    easing.type: Easing.InCubic
                }
                NumberAnimation {
                    property: "scale"
                    from: 1
                    to: 0.95
                    duration: Nexa.Theme.popExitDuration
                    easing.type: Nexa.Theme.easingExit
                }
            }
        }
    }
}
