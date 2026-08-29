import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

import "../../theme" as Nexa
import "../../theme/components" as NexaUI

NexaUI.NexaCard {
    id: root

    // ------------------------------------------------------------
    // ACTIVE APPLICATION & TITLE
    // ------------------------------------------------------------

    readonly property var app: ToplevelManager.activeToplevel

    readonly property string appId:
        app?.appId ?? ""

    readonly property bool hasApp:
        appId !== ""

    readonly property string appName: {
        if (!hasApp) return ""
        return appId.charAt(0).toUpperCase() + appId.slice(1)
    }

    readonly property string windowTitle:
        app?.title ?? ""

    readonly property string displayText: {
        if (!hasApp) return ""
        if (windowTitle && windowTitle.toLowerCase() !== appName.toLowerCase()) {
            return appName + "  •  " + windowTitle
        }
        return appName
    }

    // ------------------------------------------------------------
    // SIZE & GEOMETRY (Fixed Length Pill)
    // ------------------------------------------------------------

    readonly property int fixedPillWidth: 210

    implicitHeight: Nexa.Theme.controlHeightSm

    implicitWidth: hasApp
        ? fixedPillWidth
        : Nexa.Theme.controlHeightSm

    radius: height / 2

    // ------------------------------------------------------------
    // SURFACE
    // ------------------------------------------------------------

    interactive: true
    padding: 0

    Behavior on implicitWidth {
        NumberAnimation {
            duration: Nexa.Theme.motionSelection
            easing.type: Nexa.Theme.easingStandard
        }
    }

    // ------------------------------------------------------------
    // CONTENT ROW: ( ICON | TICKER TEXT )
    // ------------------------------------------------------------

    RowLayout {
        id: contentRow

        anchors {
            fill: parent
            leftMargin: Nexa.Theme.spacingSm
            rightMargin: Nexa.Theme.spacingSm
        }

        spacing: Nexa.Theme.spacingXs

        // Application Icon
        Image {
            id: appIcon

            Layout.preferredWidth: Nexa.Theme.iconSm
            Layout.preferredHeight: Nexa.Theme.iconSm
            Layout.alignment: Qt.AlignVCenter

            source: root.hasApp
                ? Quickshell.iconPath(
                    root.appId,
                    "application-x-executable"
                )
                : ""

            visible: root.hasApp

            fillMode: Image.PreserveAspectFit
            smooth: true
            mipmap: true

            scale: root.hovered ? 1.08 : 1.0

            Behavior on scale {
                NumberAnimation {
                    duration: Nexa.Theme.animationFast
                    easing.type: Nexa.Theme.easingStandard
                }
            }
        }

        // Separator Line (|)
        Rectangle {
            Layout.preferredWidth: 1
            Layout.preferredHeight: 14
            Layout.alignment: Qt.AlignVCenter

            color: Nexa.Theme.divider
            opacity: 0.6

            visible: root.hasApp
        }

        // Sliding Marquee Ticker Container
        Item {
            id: marqueeContainer

            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.alignment: Qt.AlignVCenter
            clip: true
            visible: root.hasApp

            readonly property bool needsScroll:
                marqueeText.implicitWidth > width

            readonly property real overflowDist:
                Math.max(0, marqueeText.implicitWidth - width)

            Text {
                id: marqueeText

                x: 0
                anchors.verticalCenter: parent.verticalCenter

                text: root.displayText

                color: root.hovered
                    ? Nexa.Theme.text
                    : Nexa.Theme.mutedText

                font {
                    family: Nexa.Theme.fontFamily
                    pixelSize: Nexa.Theme.fontSizeXs
                    weight: Nexa.Theme.fontWeightMedium
                }

                Behavior on color {
                    ColorAnimation {
                        duration: Nexa.Theme.animationFast
                    }
                }
            }

            SequentialAnimation {
                id: tickerAnimation
                running: marqueeContainer.needsScroll
                loops: Animation.Infinite

                PauseAnimation { duration: 1800 }

                NumberAnimation {
                    target: marqueeText
                    property: "x"
                    from: 0
                    to: -marqueeContainer.overflowDist - 16
                    duration: Math.max(1400, (marqueeContainer.overflowDist + 16) * 35)
                    easing.type: Easing.InOutQuad
                }

                PauseAnimation { duration: 1500 }

                NumberAnimation {
                    target: marqueeText
                    property: "x"
                    to: 0
                    duration: Math.max(1000, (marqueeContainer.overflowDist + 16) * 25)
                    easing.type: Easing.InOutQuad
                }
            }

            onWidthChanged: {
                marqueeText.x = 0
                if (needsScroll) tickerAnimation.restart()
                else tickerAnimation.stop()
            }

            Connections {
                target: root
                function onDisplayTextChanged() {
                    marqueeText.x = 0
                    if (marqueeContainer.needsScroll) tickerAnimation.restart()
                    else tickerAnimation.stop()
                }
                function onHasAppChanged() {
                    marqueeText.x = 0
                    if (marqueeContainer.needsScroll) tickerAnimation.restart()
                    else tickerAnimation.stop()
                }
            }
        }
    }

    // ------------------------------------------------------------
    // EMPTY STATE (WHEN NO ACTIVE WINDOW)
    // ------------------------------------------------------------

    Rectangle {
        anchors.centerIn: parent

        visible: !root.hasApp

        width: Nexa.Theme.spacingXs
        height: Nexa.Theme.spacingXs

        radius: Nexa.Theme.radiusPill

        color: Nexa.Theme.mutedText

        opacity: Nexa.Theme.opacitySecondary
    }
}
