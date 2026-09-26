import QtQuick
import QtQuick.Layouts

import Quickshell

import "../theme" as Nexa
import "../theme/components" as NexaUI
import "../modules/workspace" as WorkspaceModule
import "../modules/battery" as BatteryModule
import "../modules/network" as NetworkModule
import "../modules/power" as PowerModule
PanelWindow {
    id: root

    required property var modelData
    screen: modelData

    // ============================================================
    // NEXA TOP BAR
    //
    // Purpose:
    // - Own the permanent Top Bar window and layout.
    // - Compose feature modules.
    //
    // Important:
    // - Feature logic does NOT belong here.
    // - Dynamic Island is a separate window/entity.
    // - Side Panel is not implemented in this phase.
    // ============================================================


    // ------------------------------------------------------------
    // Window
    // ------------------------------------------------------------

    anchors {
        top: true
        left: true
        right: true
    }

    implicitHeight: Nexa.Theme.barHeight

    color: "transparent"

    exclusionMode: ExclusionMode.Auto


    // ============================================================
    // BAR SURFACE
    // ============================================================

    Rectangle {
        anchors.fill: parent

        color: "transparent"


        // ========================================================
        // LEFT SECTION
        //
        // Final:
        // [ Workspaces ] [ Current App ]
        // ========================================================

        RowLayout {
            id: leftSection

            anchors {
                left: parent.left
                leftMargin: Nexa.Theme.spacingMd
                verticalCenter: parent.verticalCenter
            }

            spacing: Nexa.Theme.spacingSm


            // ------------------------------------------------------------
            // WORKSPACE SECTION
            //
            // Owns:
            // - workspace buttons
            // - active workspace state
            // - current application section
            //
            // All workspace/current-app logic stays inside the module.
            // ------------------------------------------------------------

            WorkspaceModule.Workspace {
                id: workspaceSection
            }
        }


        // ========================================================
        // CENTER
        //
        // Intentionally empty.
        //
        // Dynamic Island is a separate PanelWindow and must remain
        // independent from TopBar.qml.
        // ========================================================


        // ========================================================
        // RIGHT SECTION
        //
        // Final:
        // [ Battery ] [ Wi-Fi | BT ] [ Panel ] [ Power ]
        // ========================================================

        RowLayout {
            id: rightSection

            anchors {
                right: parent.right
                rightMargin: Nexa.Theme.spacingMd
                verticalCenter: parent.verticalCenter
            }

            spacing: Nexa.Theme.spacingXs


            // ----------------------------------------------------
            // PILL 0 — MUSIC WAVEFORM
            // ----------------------------------------------------

            WaveformPill {
                id: musicWaveformPill
            }


            // ----------------------------------------------------
            // PILL 1 — BATTERY
            // ----------------------------------------------------

            component BarPill: Rectangle {
                default property alias content: pillRow.data
                property int contentSpacing: 0
                property int extraWidth: Nexa.Theme.spacingMd

                implicitHeight: Nexa.Theme.controlHeightSm
                implicitWidth: pillRow.implicitWidth + extraWidth
                radius: height / 2
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
                BatteryModule.Battery {}
            }

            BarPill {
                id: networkPill
                NetworkModule.Network {}
            }

            BarPill {
                id: powerPill
                extraWidth: 0
                implicitWidth: Nexa.Theme.controlHeightSm
                PowerModule.Power {}
            }
        }
    }
}
