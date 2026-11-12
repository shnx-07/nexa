import QtQuick
import QtQuick.Layouts

import Quickshell

import "../../NewNexaUI" as NexaUI
import "../../services" as Services
import "../workspace" as WorkspaceModule
import "../battery" as BatteryModule
import "../network" as NetworkModule
import "../power" as PowerModule
import "../../decorations/ConstellationRail" as ConstellationRailModule

PanelWindow {
    id: root

    // ============================================================
    // NEXA BAR (Supports Top, Bottom, Left, Right & Autohide)
    // ============================================================

    readonly property string barPosition: Services.BarConfig.position || "top"
    readonly property bool isVertical: barPosition === "left" || barPosition === "right"
    readonly property bool isAutohide: Services.BarConfig.autohide || false
    readonly property int effectiveSize: Services.BarConfig.height || NexaUI.NexaTokens.barHeight

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

    implicitHeight: isVertical ? 1 : Math.max(1, effectiveSize)
    implicitWidth: isVertical ? Math.max(1, effectiveSize) : 1

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
                    leftMargin: NexaUI.NexaTokens.spacingMd
                    verticalCenter: parent.verticalCenter
                }
                spacing: NexaUI.NexaTokens.spacingSm
                visible: Services.BarConfig.showWorkspaces

                WorkspaceModule.Workspace {
                    id: workspaceSection
                }
            }

            // CENTER DECORATION: Constellation Rail
            ConstellationRailModule.ConstellationRail {
                id: constellationRail
                anchors.fill: parent
                leftMargin: leftSection.width + NexaUI.NexaTokens.spacingLg
                rightMargin: Math.max(150, rightSection.width + NexaUI.NexaTokens.spacingLg)
            }

            // RIGHT SECTION: Music, Battery, Network, Power
            RowLayout {
                id: rightSection
                anchors {
                    right: parent.right
                    rightMargin: NexaUI.NexaTokens.spacingMd
                    verticalCenter: parent.verticalCenter
                }
                spacing: NexaUI.NexaTokens.spacingXs

                component BarPill: Item {
                    id: pillRoot
                    default property alias content: pillRow.data
                    property int contentSpacing: 0
                    property int extraWidth: NexaUI.NexaTokens.spacingMd

                    implicitHeight: NexaUI.NexaTokens.controlHeightSm
                    implicitWidth: pillRow.implicitWidth + extraWidth

                    // GPU-Accelerated Nexa Drop Shadow for Top Bar Pills
                    NexaUI.NexaShadow {
                        id: pillShadow
                        targetItem: pillBody
                        elevation: 0
                    }

                    Rectangle {
                        id: pillBody
                        anchors.fill: parent
                        radius: NexaUI.NexaTokens.radiusLg === 0 ? 0 : Math.min(height / 2, NexaUI.NexaTokens.radiusLg)
                        color: NexaUI.NexaColors.surfaceContainer
                        border.width: NexaUI.NexaTokens.borderThin
                        border.color: NexaUI.NexaColors.border

                        Behavior on color {
                            ColorAnimation { duration: NexaUI.NexaMotion.durationFast }
                        }

                        // Apple Tactile 4-stop Depth Micro-Gradient
                        Rectangle {
                            anchors.fill: parent
                            radius: pillBody.radius
                            antialiasing: true
                            visible: NexaUI.NexaOptics.surface3DGradient && NexaUI.NexaOptics.gradientIntensity > 0.01
                            opacity: NexaUI.NexaOptics.gradientIntensity
                            gradient: Gradient {
                                GradientStop { position: 0.00; color: Qt.rgba(1, 1, 1, 0.045) }
                                GradientStop { position: 0.40; color: Qt.rgba(1, 1, 1, 0.010) }
                                GradientStop { position: 0.70; color: Qt.rgba(0, 0, 0, 0.000) }
                                GradientStop { position: 1.00; color: Qt.rgba(0, 0, 0, 0.120) }
                            }
                        }

                        // Apple Top Chamfer Specular Highlight
                        Rectangle {
                            anchors.top: parent.top
                            anchors.topMargin: 1
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: pillBody.radius > 0 ? Math.max(0, parent.width - pillBody.radius * 1.6) : parent.width
                            height: 1
                            visible: NexaUI.NexaOptics.specularHighlight && NexaUI.NexaOptics.specularIntensity > 0.01
                            opacity: Math.min(1.0, NexaUI.NexaOptics.specularIntensity / 0.28)
                            z: 1
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0.0; color: "transparent" }
                                GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.30) }
                                GradientStop { position: 1.0; color: "transparent" }
                            }
                        }

                        // Apple Bottom Chamfer Ambient Shadow Line
                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 1
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: pillBody.radius > 0 ? Math.max(0, parent.width - pillBody.radius * 1.6) : parent.width
                            height: 1
                            visible: NexaUI.NexaOptics.contactShadow && NexaUI.NexaOptics.shadowBlurFactor > 0.01
                            opacity: Math.min(1.0, NexaUI.NexaOptics.shadowBlurFactor)
                            z: 1
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0.0; color: "transparent" }
                                GradientStop { position: 0.5; color: Qt.rgba(0, 0, 0, 0.45) }
                                GradientStop { position: 1.0; color: "transparent" }
                            }
                        }

                        Row {
                            id: pillRow
                            anchors.centerIn: parent
                            spacing: contentSpacing
                            z: 2
                        }
                    }
                }

                BarPill {
                    id: batteryPill
                    visible: Services.BarConfig.showBattery
                    BatteryModule.Battery {}
                }

                BarPill {
                    id: wifiPill
                    visible: Services.BarConfig.showNetwork
                    extraWidth: 0
                    NetworkModule.Wifi {}
                }

                BarPill {
                    id: bluetoothPill
                    visible: Services.BarConfig.showNetwork
                    extraWidth: 0
                    NetworkModule.Bluetooth {}
                }

                BarPill {
                    id: settingsPill
                    visible: Services.BarConfig.showSettings
                    extraWidth: 0
                    implicitWidth: NexaUI.NexaTokens.controlHeightSm

                    Item {
                        implicitWidth: NexaUI.NexaTokens.controlHeightSm
                        implicitHeight: NexaUI.NexaTokens.controlHeightSm

                        NexaUI.NexaButton {
                            anchors.fill: parent
                            variant: "icon"
                            icon: "󰒓"
                            iconColor: NexaUI.NexaColors.text
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
                    implicitWidth: NexaUI.NexaTokens.controlHeightSm
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
                    topMargin: NexaUI.NexaTokens.spacingMd
                    horizontalCenter: parent.horizontalCenter
                }
                spacing: NexaUI.NexaTokens.spacingSm
                visible: Services.BarConfig.showWorkspaces

                WorkspaceModule.Workspace {
                    id: verticalWorkspaceSection
                }
            }

            ColumnLayout {
                anchors {
                    bottom: parent.bottom
                    bottomMargin: NexaUI.NexaTokens.spacingMd
                    horizontalCenter: parent.horizontalCenter
                }
                spacing: NexaUI.NexaTokens.spacingXs

                component VerticalBarPill: Rectangle {
                    width: NexaUI.NexaTokens.controlHeightSm
                    height: NexaUI.NexaTokens.controlHeightSm
                    radius: NexaUI.NexaTokens.radiusLg === 0 ? 0 : Math.min(width / 2, NexaUI.NexaTokens.radiusLg)
                    color: NexaUI.NexaColors.surfaceContainer
                    border.width: NexaUI.NexaTokens.borderThin
                    border.color: NexaUI.NexaColors.border
                }

                VerticalBarPill {
                    visible: Services.BarConfig.showBattery

                    BatteryModule.Battery {
                        anchors.centerIn: parent
                    }
                }

                VerticalBarPill {
                    visible: Services.BarConfig.showNetwork

                    NetworkModule.Wifi {
                        anchors.centerIn: parent
                    }
                }

                VerticalBarPill {
                    visible: Services.BarConfig.showNetwork

                    NetworkModule.Bluetooth {
                        anchors.centerIn: parent
                    }
                }

                VerticalBarPill {
                    visible: Services.BarConfig.showSettings

                    NexaUI.NexaButton {
                        anchors.fill: parent
                        variant: "icon"
                        icon: "󰒓"
                        iconColor: NexaUI.NexaColors.text
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

                VerticalBarPill {
                    visible: Services.BarConfig.showPower

                    PowerModule.Power {
                        anchors.centerIn: parent
                    }
                }
            }
        }
    }
    }
}
