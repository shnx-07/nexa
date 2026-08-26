import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

import "../../theme" as Nexa

Rectangle {
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
    // SIZE & GEOMETRY
    // ------------------------------------------------------------

    height: Nexa.Theme.controlHeightSm

    width: hasApp
        ? Math.min(260, contentRow.implicitWidth + (Nexa.Theme.spacingSm * 2))
        : Nexa.Theme.controlHeightSm

    radius: height / 2

    // ------------------------------------------------------------
    // SURFACE
    // ------------------------------------------------------------

    color: mouse.pressed
        ? Nexa.Theme.pressed
        : mouse.containsMouse
            ? Nexa.Theme.hoverStrong
            : Nexa.Theme.surfaceContainerLow

    border.width: Nexa.Theme.borderThin

    border.color: mouse.containsMouse
        ? Nexa.Theme.border
        : Nexa.Theme.divider

    // ------------------------------------------------------------
    // MOTION
    // ------------------------------------------------------------

    scale: mouse.pressed
        ? Nexa.Theme.pressScale
        : mouse.containsMouse
            ? Nexa.Theme.hoverScale
            : Nexa.Theme.normalScale

    Behavior on width {
        NumberAnimation {
            duration: Nexa.Theme.motionSelection
            easing.type: Nexa.Theme.easingStandard
        }
    }

    Behavior on color {
        ColorAnimation {
            duration: Nexa.Theme.animationFast
        }
    }

    Behavior on border.color {
        ColorAnimation {
            duration: Nexa.Theme.animationFast
        }
    }

    Behavior on scale {
        NumberAnimation {
            duration: Nexa.Theme.animationFast
            easing.type: Nexa.Theme.easingStandard
        }
    }

    // ------------------------------------------------------------
    // CONTENT ROW: (( ICON ) | APP NAME + WORK TITLE)
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

            scale: mouse.containsMouse ? 1.08 : 1.0

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

        // App Name and Active Window Title
        Text {
            id: titleText

            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter

            text: root.displayText

            color: mouse.containsMouse
                ? Nexa.Theme.text
                : Nexa.Theme.mutedText

            font {
                family: Nexa.Theme.fontFamily
                pixelSize: Nexa.Theme.fontSizeXs
                weight: Nexa.Theme.fontWeightMedium
            }

            elide: Text.ElideRight

            visible: root.hasApp

            Behavior on color {
                ColorAnimation {
                    duration: Nexa.Theme.animationFast
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

    // ------------------------------------------------------------
    // INTERACTION
    // ------------------------------------------------------------

    MouseArea {
        id: mouse

        anchors.fill: parent

        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
    }
}
