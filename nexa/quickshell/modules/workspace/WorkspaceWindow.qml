import QtQuick

import Quickshell
import Quickshell.Wayland

import "../../theme" as Nexa


Item {
    id: root


    // ============================================================
    // NEXA WORKSPACE WINDOW
    //
    // Visual/live-preview component only.
    //
    // IMPORTANT:
    // Dragging is NOT implemented here.
    // WorkspaceManager.qml will own:
    //
    //   MouseArea
    //   drag.target
    //   Drag.active
    //   Drag.source
    //   destination workspace handling
    //
    // This matches the architecture of the working overview.
    // ============================================================


    // ============================================================
    // INPUT
    // ============================================================

    // Rust window object from:
    //
    // nexad workspace info
    //
    // {
    //   address,
    //   class,
    //   title,
    //   x,
    //   y,
    //   width,
    //   height,
    //   floating,
    //   ...
    // }
    property var windowData: null


    // Quickshell Hyprland toplevel wrapper.
    //
    // Expected shape:
    //
    // {
    //     wayland: ...
    // }
    //
    property var toplevel: null


    // Monitor returned by Rust.
    property var monitorData: null


    // ============================================================
    // WORKSPACE GEOMETRY
    // ============================================================

    property real workspaceX: 0
    property real workspaceY: 0

    property real workspaceWidth: 1
    property real workspaceHeight: 1


    // Scale from real monitor coordinates to workspace preview.
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
        windowData
        ? String(windowData.address || "")
        : ""


    readonly property string appClass:
        windowData
        ? String(windowData.class || "")
        : ""


    readonly property string title:
        windowData
        ? String(windowData.title || "")
        : ""


    readonly property bool focused:
        windowData
        ? windowData.focused === true
        : false


    // ============================================================
    // INITIAL POSITION
    //
    // Same important idea as the working overview:
    //
    // x/y are real movable properties.
    //
    // initX/initY tell the manager where the window belongs when
    // it is NOT being dragged.
    // ============================================================

    readonly property real initX: {

        if (!windowData || !monitorData)
            return workspaceX


        const monitorX =
            Number(monitorData.x || 0)

        const windowX =
            Number(windowData.x || 0)


        return workspaceX
            + Math.max(
                0,
                windowX - monitorX
            )
            * previewScaleX
    }


    readonly property real initY: {

        if (!windowData || !monitorData)
            return workspaceY


        const monitorY =
            Number(monitorData.y || 0)

        const windowY =
            Number(windowData.y || 0)


        return workspaceY
            + Math.max(
                0,
                windowY - monitorY
            )
            * previewScaleY
    }


    // ============================================================
    // SIZE
    // ============================================================

    readonly property real targetWidth: {

        if (!windowData)
            return 100


        return Math.max(
            32,
            Number(windowData.width || 100)
            * previewScaleX
        )
    }


    readonly property real targetHeight: {

        if (!windowData)
            return 70


        return Math.max(
            24,
            Number(windowData.height || 70)
            * previewScaleY
        )
    }


    // ============================================================
    // IMPORTANT
    //
    // We bind x/y directly like the working overview.
    //
    // MouseArea.drag.target will temporarily break/change these
    // while the actual item is being dragged.
    //
    // When a drop is rejected, WorkspaceManager simply assigns:
    //
    //     window.x = window.initX
    //     window.y = window.initY
    //
    // ============================================================

    x:
        initX

    y:
        initY


    width:
        Math.min(
            targetWidth,
            workspaceWidth
        )

    height:
        Math.min(
            targetHeight,
            workspaceHeight
        )


    // ============================================================
    // STACKING & SCALE ELEVATION
    // ============================================================

    z:
        dragInProgress
        ? 1000
        : focused
          ? 20
          : 10


    scale:
        dragInProgress
        ? 1.04
        : hovered
          ? 1.015
          : 1.0


    Behavior on scale {

        NumberAnimation {
            duration:
                Nexa.Theme.motionInteraction

            easing.type:
                Nexa.Theme.easingStandard
        }
    }


    // ============================================================
    // APPEARANCE
    // ============================================================

    opacity:
        pressed
        ? 0.92
        : 1.0


    // The preview itself needs clipping, but WorkspaceManager's
    // shared window layer will NOT be clipped.
    clip:
        true


    // ============================================================
    // MOVEMENT ANIMATION
    //
    // Never animate while dragging.
    // ============================================================

    Behavior on x {

        enabled:
            !root.dragInProgress

        NumberAnimation {
            duration:
                Nexa.Theme.motionLayout

            easing.type:
                Nexa.Theme.easingStandard
        }
    }


    Behavior on y {

        enabled:
            !root.dragInProgress

        NumberAnimation {
            duration:
                Nexa.Theme.motionLayout

            easing.type:
                Nexa.Theme.easingStandard
        }
    }


    // ============================================================
    // WINDOW BACKGROUND
    // ============================================================

    Rectangle {
        anchors.fill:
            parent

        radius:
            Nexa.Theme.radiusMd

        color:
            Nexa.Theme.cardBackgroundElevated
    }


    // ============================================================
    // LIVE WINDOW PREVIEW
    // ============================================================

    ScreencopyView {
        id: preview

        anchors.fill:
            parent

        captureSource:
            root.toplevel

        live:
            root.toplevel !== null

        paintCursor:
            false
    }

    // ============================================================
    // FALLBACK
    // ============================================================

    Rectangle {
        anchors.fill:
            parent

        visible:
            !preview.hasContent

        radius:
            Nexa.Theme.radiusMd

        color:
            Nexa.Theme.cardBackgroundElevated

        /*
        Image {
            anchors.centerIn:
                parent

            width:
                Math.max(
                    18,
                    Math.min(
                        40,
                        parent.width * 0.28,
                        parent.height * 0.28
                    )
                )

            height:
                width


            source:
                Quickshell.iconPath(
                    root.appClass !== ""
                    ? root.appClass
                    : "application-x-executable",
                    "application-x-executable"
                )


            fillMode:
                Image.PreserveAspectFit

            smooth:
                true
        }

        */
    }


    // ============================================================
    // HOVER / PRESS OVERLAY
    // ============================================================

    Rectangle {
        anchors.fill:
            parent

        radius:
            Nexa.Theme.radiusMd


        color:
            root.pressed
            ? Nexa.Theme.pressed
            : root.hovered
              ? Nexa.Theme.hover
              : "transparent"


        border.width:
            root.focused
            ? Nexa.Theme.borderStrongWidth
            : 1


        border.color:
            root.focused
            ? Nexa.Theme.selectedBorder
            : root.hovered
              ? Nexa.Theme.primary
              : Nexa.Theme.border


        Behavior on color {

            ColorAnimation {
                duration:
                    Nexa.Theme.motionInteraction
            }
        }


        Behavior on border.color {

            ColorAnimation {
                duration:
                    Nexa.Theme.motionInteraction
            }
        }
    }


    // ============================================================
    // TITLE
    // ============================================================

    Rectangle {
        anchors {
            left:
                parent.left

            right:
                parent.right

            bottom:
                parent.bottom
        }


        height:
            titleText.implicitHeight
            + Nexa.Theme.spacingSm * 2


        visible:
            root.hovered
            && root.title !== ""


        color:
            Nexa.Theme.scrimHeavy


        Text {
            id: titleText

            anchors {
                left:
                    parent.left

                right:
                    parent.right

                verticalCenter:
                    parent.verticalCenter

                leftMargin:
                    Nexa.Theme.spacingSm

                rightMargin:
                    Nexa.Theme.spacingSm
            }


            text:
                root.title


            color:
                Nexa.Theme.text


            font {
                family:
                    Nexa.Theme.fontFamily

                pixelSize:
                    Nexa.Theme.fontSizeXs
            }


            elide:
                Text.ElideRight

            maximumLineCount:
                1
        }
    }
}

