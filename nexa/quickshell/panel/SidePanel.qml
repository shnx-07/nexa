import QtQuick

import Quickshell
import Quickshell.Io

import "../theme" as Nexa


Scope {
    id: root

    property bool panelOpen: false

    property real panelHeightRatio: 0.78

    property int edgeGap: Nexa.Theme.spacingLg
    property int panelWidth: Nexa.Theme.panelWidthMd


    // ============================================================
    // OUTSIDE CLICK AREA
    //
    // Starts BELOW the Top Bar.
    // Therefore the Top Bar remains fully clickable.
    // ============================================================

    PanelWindow {
        id: outsideWindow

        visible: root.panelOpen

        anchors {
            left: true
            right: true
            bottom: true
        }

        // Do NOT cover the Top Bar.
        implicitHeight:
            screen.height - Nexa.Theme.barHeight

        color: "transparent"

        exclusionMode: ExclusionMode.Ignore
        aboveWindows: true


        // Only catch clicks outside the Side Panel.
        mask: Region {
            x: 0
            y: 0

            width:
                outsideWindow.width
                - root.panelWidth
                - root.edgeGap

            height:
                outsideWindow.height
        }


        MouseArea {
            anchors.fill: parent

            onClicked: {
                root.panelOpen = false
            }
        }
    }


    // ============================================================
    // ACTUAL SIDE PANEL
    // ============================================================

    PanelWindow {
        id: panelWindow

        anchors {
            top: true
            right: true
            bottom: true
        }

        implicitWidth:
            root.panelWidth
            + root.edgeGap

        color: "transparent"

        exclusionMode: ExclusionMode.Ignore
        visible: true
        aboveWindows: true
        focusable: root.panelOpen

        mask: Region {
            item: root.panelOpen
                ? panelContainer
                : null
        }


        Item {
            id: panelContainer

            width: root.panelWidth

            height:
                panelWindow.height
                * root.panelHeightRatio

            anchors.verticalCenter:
                parent.verticalCenter


            x: root.panelOpen
                ? 0
                : panelWindow.width


            opacity: root.panelOpen
                ? Nexa.Theme.opacityFull
                : Nexa.Theme.opacityHidden


            Behavior on x {
                NumberAnimation {
                    duration: root.panelOpen
                        ? Nexa.Theme.animationNormal
                        : Nexa.Theme.animationFast

                    easing.type: root.panelOpen
                        ? Nexa.Theme.easingEnter
                        : Nexa.Theme.easingExit
                }
            }


            Behavior on opacity {
                NumberAnimation {
                    duration: root.panelOpen
                        ? Nexa.Theme.animationNormal
                        : Nexa.Theme.animationFast

                    easing.type: root.panelOpen
                        ? Nexa.Theme.easingEnter
                        : Nexa.Theme.easingExit
                }
            }


            Rectangle {
                anchors.fill: parent

                color:
                    Nexa.Theme.panelBackground

                radius:
                    Nexa.Theme.radiusXl


                border {
                    width:
                        Nexa.Theme.borderThin

                    color:
                        Nexa.Theme.border
                }


                PanelContent {
                    anchors.fill: parent
                }
            }
        }
    }


    // ============================================================
    // ESC
    // ============================================================

    Shortcut {
        enabled:
            root.panelOpen

        sequence:
            "Escape"

        context:
            Qt.ApplicationShortcut

        onActivated: {
            root.panelOpen = false
        }
    }


    // ============================================================
    // IPC
    // ============================================================

    IpcHandler {
        target: "sidePanel"

        function toggle(): void {
            root.panelOpen = !root.panelOpen
        }

        function open(): void {
            root.panelOpen = true
        }

        function close(): void {
            root.panelOpen = false
        }

        function openNotifications(): void {
            console.log("NEXA: openNotifications called")

            // Open the panel first.
            root.panelOpen = true

            // Then switch to Notifications.
            Qt.callLater(function() {
                panelContent.currentPage = 0
            })

            Quickshell.execDetached([
                Quickshell.env("HOME")
                    + "/.config/nexa/rust/target/release/nexad",
                "notifications",
                "read-all"
            ])
        }
    }


}
