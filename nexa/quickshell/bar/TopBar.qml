import QtQuick
import QtQuick.Layouts

import Quickshell

import "../theme" as Nexa
import "../theme/components" as NexaUI
import "../services" as Services
import "../modules/workspace" as WorkspaceModule
import "../modules/battery" as BatteryModule
import "../modules/network" as NetworkModule
import "../modules/power" as PowerModule

PanelWindow {
    id: root

    // ============================================================
    // NEXA BAR (Supports Top, Bottom, Left, Right & Autohide)
    // ============================================================

    readonly property string barPosition: Services.BarConfig.position || "top"
    readonly property bool isVertical: barPosition === "left" || barPosition === "right"
    readonly property bool isAutohide: Services.BarConfig.autohide || false
    readonly property int effectiveSize: Services.BarConfig.height || Nexa.Theme.barHeight

    property bool isHovered: false
    property bool isRevealed: !isAutohide || isHovered

    Timer {
        id: hideTimer
        interval: 350
        repeat: false
        onTriggered: {
            if (!root.isHovered && root.isAutohide) {
                root.isRevealed = false;
            }
        }
    }

    // ------------------------------------------------------------
    // Dynamic Window Anchors & Sizing
    // ------------------------------------------------------------
    anchors {
        top: barPosition !== "bottom"
        bottom: barPosition !== "top"
        left: barPosition !== "right"
        right: barPosition !== "left"
    }

    implicitHeight: isVertical ? 0 : effectiveSize
    implicitWidth: isVertical ? effectiveSize : 0

    color: "transparent"

    // When autohide is enabled, ignore exclusion so Hyprland windows use full screen
    exclusionMode: isAutohide ? ExclusionMode.Ignore : ExclusionMode.Auto

    // ============================================================
    // BAR SURFACE WITH SLIDE ANIMATION
    // ============================================================
    Rectangle {
        id: surfaceContainer
        anchors.fill: parent
        color: "transparent"

        // Offset transitions for autohide
        y: {
            if (!root.isAutohide) return 0;
            if (root.barPosition === "top") return root.isRevealed ? 0 : -(root.implicitHeight - 2);
            if (root.barPosition === "bottom") return root.isRevealed ? 0 : (root.implicitHeight - 2);
            return 0;
        }

        x: {
            if (!root.isAutohide) return 0;
            if (root.barPosition === "left") return root.isRevealed ? 0 : -(root.implicitWidth - 2);
            if (root.barPosition === "right") return root.isRevealed ? 0 : (root.implicitWidth - 2);
            return 0;
        }

        Behavior on y {
            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
        }

        Behavior on x {
            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
        }

        // Mouse hover tracking
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            propagateComposedEvents: true
            onEntered: {
                hideTimer.stop();
                root.isHovered = true;
                root.isRevealed = true;
            }
            onExited: {
                root.isHovered = false;
                if (root.isAutohide) hideTimer.restart();
            }
        }

        // ========================================================
        // ON-DEMAND BAR LAYOUT (Only active layout is instantiated)
        // ========================================================
        Loader {
            anchors.fill: parent
            active: !root.isVertical
            visible: active
            sourceComponent: horizontalLayoutComponent
        }

        Loader {
            anchors.fill: parent
            active: root.isVertical
            visible: active
            sourceComponent: verticalLayoutComponent
        }

        Component {
            id: horizontalLayoutComponent

            Item {
                anchors.fill: parent

            // LEFT SECTION: Workspaces & Current App
            RowLayout {
                id: leftSection
                anchors {
                    left: parent.left
                    leftMargin: Nexa.Theme.spacingMd
                    verticalCenter: parent.verticalCenter
                }
                spacing: Nexa.Theme.spacingSm
                visible: Services.BarConfig.showWorkspaces

                WorkspaceModule.Workspace {
                    id: workspaceSection
                }
            }

            // RIGHT SECTION: Music, Battery, Network, Power
            RowLayout {
                id: rightSection
                anchors {
                    right: parent.right
                    rightMargin: Nexa.Theme.spacingMd
                    verticalCenter: parent.verticalCenter
                }
                spacing: Nexa.Theme.spacingXs

                WaveformPill {
                    id: musicWaveformPill
                    visible: Services.BarConfig.showMusic
                }

                component BarPill: Rectangle {
                    default property alias content: pillRow.data
                    property int contentSpacing: 0
                    property int extraWidth: Nexa.Theme.spacingMd

                    implicitHeight: Nexa.Theme.controlHeightSm
                    implicitWidth: pillRow.implicitWidth + extraWidth
                    radius: Nexa.Theme.nexaRounding === 0 ? 0 : Math.min(height / 2, Nexa.Theme.nexaRounding)
                    color: Nexa.Theme.surfaceContainer
                    border.width: Nexa.Theme.borderThin
                    border.color: Nexa.Theme.border

                    Behavior on color {
                        ColorAnimation { duration: Nexa.Theme.animationFast }
                    }

                    Row {
                        id: pillRow
                        anchors.centerIn: parent
                        spacing: contentSpacing
                    }
                }

                BarPill {
                    id: batteryPill
                    visible: Services.BarConfig.showBattery
                    BatteryModule.Battery {}
                }

                BarPill {
                    id: networkPill
                    visible: Services.BarConfig.showNetwork
                    NetworkModule.Network {}
                }

                BarPill {
                    id: settingsPill
                    visible: Services.BarConfig.showSettings
                    extraWidth: 0
                    implicitWidth: Nexa.Theme.controlHeightSm

                    Item {
                        implicitWidth: Nexa.Theme.controlHeightSm
                        implicitHeight: Nexa.Theme.controlHeightSm

                        NexaUI.NexaIconButton {
                            anchors.fill: parent
                            radius: height / 2
                            icon: "󰒓"
                            iconColor: Nexa.Theme.text
                            onClicked: {
                                Quickshell.execDetached([
                                    "qs",
                                    "-p",
                                    Quickshell.env("HOME") + "/.config/nexa/quickshell",
                                    "ipc",
                                    "call",
                                    "settings",
                                    "toggle"
                                ])
                            }
                        }
                    }
                }

                BarPill {
                    id: powerPill
                    visible: Services.BarConfig.showPower
                    extraWidth: 0
                    implicitWidth: Nexa.Theme.controlHeightSm
                    PowerModule.Power {}
                }
            }
        }

        }

        Component {
            id: verticalLayoutComponent

            Item {
                anchors.fill: parent

            ColumnLayout {
                anchors {
                    top: parent.top
                    topMargin: Nexa.Theme.spacingMd
                    horizontalCenter: parent.horizontalCenter
                }
                spacing: Nexa.Theme.spacingSm
                visible: Services.BarConfig.showWorkspaces

                WorkspaceModule.Workspace {
                    id: verticalWorkspaceSection
                }
            }

            ColumnLayout {
                anchors {
                    bottom: parent.bottom
                    bottomMargin: Nexa.Theme.spacingMd
                    horizontalCenter: parent.horizontalCenter
                }
                spacing: Nexa.Theme.spacingXs

                Rectangle {
                    visible: Services.BarConfig.showBattery
                    width: Nexa.Theme.controlHeightSm
                    height: Nexa.Theme.controlHeightSm
                    radius: Nexa.Theme.nexaRounding === 0 ? 0 : Math.min(width / 2, Nexa.Theme.nexaRounding)
                    color: Nexa.Theme.surfaceContainer
                    border.width: Nexa.Theme.borderThin
                    border.color: Nexa.Theme.border

                    BatteryModule.Battery {
                        anchors.centerIn: parent
                    }
                }

                Rectangle {
                    visible: Services.BarConfig.showNetwork
                    width: Nexa.Theme.controlHeightSm
                    height: Nexa.Theme.controlHeightSm
                    radius: Nexa.Theme.nexaRounding === 0 ? 0 : Math.min(width / 2, Nexa.Theme.nexaRounding)
                    color: Nexa.Theme.surfaceContainer
                    border.width: Nexa.Theme.borderThin
                    border.color: Nexa.Theme.border

                    NetworkModule.Network {
                        anchors.centerIn: parent
                    }
                }

                Rectangle {
                    visible: Services.BarConfig.showSettings
                    width: Nexa.Theme.controlHeightSm
                    height: Nexa.Theme.controlHeightSm
                    radius: Nexa.Theme.nexaRounding === 0 ? 0 : Math.min(width / 2, Nexa.Theme.nexaRounding)
                    color: Nexa.Theme.surfaceContainer
                    border.width: Nexa.Theme.borderThin
                    border.color: Nexa.Theme.border

                    NexaUI.NexaIconButton {
                        anchors.fill: parent
                        radius: height / 2
                        icon: "󰒓"
                        iconColor: Nexa.Theme.text
                        onClicked: {
                            Quickshell.execDetached([
                                "qs",
                                "-p",
                                Quickshell.env("HOME") + "/.config/nexa/quickshell",
                                "ipc",
                                "call",
                                "settings",
                                "toggle"
                            ])
                        }
                    }
                }

                Rectangle {
                    visible: Services.BarConfig.showPower
                    width: Nexa.Theme.controlHeightSm
                    height: Nexa.Theme.controlHeightSm
                    radius: Nexa.Theme.nexaRounding === 0 ? 0 : Math.min(width / 2, Nexa.Theme.nexaRounding)
                    color: Nexa.Theme.surfaceContainer
                    border.width: Nexa.Theme.borderThin
                    border.color: Nexa.Theme.border

                    PowerModule.Power {
                        anchors.centerIn: parent
                    }
                }
            }
        }
    }
    }
}
