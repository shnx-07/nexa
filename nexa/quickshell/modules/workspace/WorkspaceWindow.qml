import QtQuick
import QtQuick.Controls

import Quickshell
import Quickshell.Wayland

import "../../theme" as Nexa


Item {
    id: root

    // ============================================================
    // NEXA WORKSPACE WINDOW
    //
    // Visual / live-preview component.
    // Coordinates and drag are managed in WorkspaceManager.
    // ============================================================

    // ============================================================
    // INPUT
    // ============================================================

    property var windowData: null
    property var toplevel: null
    property var monitorData: null

    // ============================================================
    // WORKSPACE GEOMETRY
    // ============================================================

    property real workspaceX: 0
    property real workspaceY: 0

    property real workspaceWidth: 1
    property real workspaceHeight: 1

    // Scale from real monitor coordinates to workspace preview
    property real previewScaleX: 1
    property real previewScaleY: 1

    // ============================================================
    // WINDOW STATE
    // ============================================================

    property bool hovered: false
    property bool pressed: false
    property bool dragInProgress: false

    // ============================================================
    // WINDOW INFORMATION
    // ============================================================

    readonly property string address:
        windowData ? String(windowData.address || "") : ""

    readonly property string appClass:
        windowData ? String(windowData.class || "") : ""

    readonly property string title:
        windowData ? String(windowData.title || "") : ""

    readonly property bool focused:
        windowData ? windowData.focused === true : false

    // ============================================================
    // INITIAL POSITION
    // Fit cleanly within workspace with zero outer bleed
    // ============================================================

    readonly property real initX: {
        if (!windowData || !monitorData)
            return workspaceX

        const monitorX = Number(monitorData.x || 0)
        const windowX = Number(windowData.x || 0)

        return workspaceX + Math.max(0, windowX - monitorX) * previewScaleX
    }

    readonly property real initY: {
        if (!windowData || !monitorData)
            return workspaceY

        const monitorY = Number(monitorData.y || 0)
        const windowY = Number(windowData.y || 0)

        return workspaceY + Math.max(0, windowY - monitorY) * previewScaleY
    }

    readonly property real targetWidth: {
        if (!windowData)
            return 100

        return Math.max(32, Number(windowData.width || 100) * previewScaleX)
    }

    readonly property real targetHeight: {
        if (!windowData)
            return 70

        return Math.max(24, Number(windowData.height || 70) * previewScaleY)
    }

    // ============================================================
    // DIMENSIONS & POSITION
    // ============================================================

    x: initX
    y: initY

    // Fit strictly inside workspace bounds
    width: Math.min(targetWidth, Math.max(20, workspaceWidth - (initX - workspaceX)))
    height: Math.min(targetHeight, Math.max(16, workspaceHeight - (initY - workspaceY)))

    z: dragInProgress ? 1000 : (focused ? 20 : 10)

    scale: dragInProgress ? 1.04 : (hovered ? 1.015 : 1.0)

    Behavior on scale {
        NumberAnimation {
            duration: Nexa.Theme.motionInteraction
            easing.type: Nexa.Theme.easingStandard
        }
    }

    opacity: pressed ? 0.92 : 1.0

    // ============================================================
    // MOVEMENT ANIMATION
    // ============================================================

    Behavior on x {
        enabled: !root.dragInProgress
        NumberAnimation {
            duration: Nexa.Theme.motionLayout
            easing.type: Nexa.Theme.easingStandard
        }
    }

    Behavior on y {
        enabled: !root.dragInProgress
        NumberAnimation {
            duration: Nexa.Theme.motionLayout
            easing.type: Nexa.Theme.easingStandard
        }
    }

    // ============================================================
    // WINDOW PREVIEW / CONTENT
    // ============================================================

    Rectangle {
        id: windowSurface
        anchors.fill: parent
        radius: Nexa.Theme.radiusSm
        color: Nexa.Theme.surfaceContainerLow
        clip: true

        // Live Wayland Screencopy
        ScreencopyView {
            id: preview
            anchors.fill: parent
            captureSource: root.toplevel
            live: root.toplevel !== null
            paintCursor: false
        }

        // Fallback when Screencopy is idle or unmapped
        Column {
            anchors.centerIn: parent
            spacing: 4
            visible: !preview.hasContent

            Image {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.max(20, Math.min(36, root.width * 0.3, root.height * 0.3))
                height: width
                source: Quickshell.iconPath(
                    root.appClass !== "" ? root.appClass : "application-x-executable",
                    "application-x-executable"
                )
                fillMode: Image.PreserveAspectFit
                smooth: true
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.appClass || root.title
                color: Nexa.Theme.mutedText
                font.family: Nexa.Theme.fontFamily
                font.pixelSize: Nexa.Theme.fontSize2Xs
                elide: Text.ElideRight
                maximumLineCount: 1
                width: Math.min(implicitWidth, root.width - 8)
                visible: root.height >= 42
            }
        }
    }

    // ============================================================
    // BORDER & FOCUS OVERLAY
    // ============================================================

    Rectangle {
        anchors.fill: parent
        radius: Nexa.Theme.radiusSm
        color: root.pressed
            ? Nexa.Theme.pressed
            : (root.hovered ? Nexa.Theme.hover : "transparent")

        border.width: root.focused ? Nexa.Theme.borderNormal : Nexa.Theme.borderThin
        border.color: root.focused
            ? Nexa.Theme.primary
            : (root.hovered ? Nexa.Theme.primary : Nexa.Theme.border)

        Behavior on color {
            ColorAnimation { duration: Nexa.Theme.animationFast }
        }

        Behavior on border.color {
            ColorAnimation { duration: Nexa.Theme.animationFast }
        }
    }

    // ============================================================
    // TITLE TOOLTIP ON HOVER
    // ============================================================

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: titleText.implicitHeight + 6
        visible: root.hovered && root.title !== ""
        color: Nexa.Theme.scrimHeavy
        radius: Nexa.Theme.radiusSm

        Text {
            id: titleText
            anchors.fill: parent
            anchors.margins: 4
            verticalAlignment: Text.AlignVCenter
            text: root.title
            color: Nexa.Theme.text
            font.family: Nexa.Theme.fontFamily
            font.pixelSize: Nexa.Theme.fontSize2Xs
            elide: Text.ElideRight
            maximumLineCount: 1
        }
    }
}
