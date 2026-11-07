import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

import "../../NewNexaUI" as NexaUI
import "../appLauncher" as AppLauncher

NexaUI.NexaCard {
    id: root

    // ------------------------------------------------------------
    // ACTIVE APPLICATION & TITLE
    // Dual fallback: ToplevelManager (Wayland) + Hyprland.focusedWindow
    // Ensures floating terminal, file manager & scratchpads never disappear
    // ------------------------------------------------------------

    readonly property var app: (typeof ToplevelManager !== "undefined") ? ToplevelManager.activeToplevel : null
    readonly property var hyprWindow: (typeof Hyprland !== "undefined" && Hyprland.focusedWindow) ? Hyprland.focusedWindow : null

    readonly property string appId: {
        if (app && app.appId && app.appId !== "") return app.appId;
        if (hyprWindow && hyprWindow.class && hyprWindow.class !== "") return hyprWindow.class;
        return "";
    }

    readonly property bool hasApp: appId !== ""

    readonly property string appName: {
        if (!hasApp) return ""
        return AppLauncher.AppRegistry.cleanAppName(appId)
    }

    readonly property string windowTitle: {
        if (app && app.title && app.title !== "") return app.title;
        if (hyprWindow && hyprWindow.title && hyprWindow.title !== "") return hyprWindow.title;
        return "";
    }

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

    implicitHeight: NexaUI.NexaTokens.controlHeightSm
    customHeight: NexaUI.NexaTokens.controlHeightSm

    implicitWidth: hasApp
        ? fixedPillWidth
        : NexaUI.NexaTokens.controlHeightSm

    radius: NexaUI.NexaTokens.radiusLg === 0 ? 0 : Math.min(height / 2, NexaUI.NexaTokens.radiusLg)
    customRadius: NexaUI.NexaTokens.radiusLg === 0 ? 0 : Math.min(height / 2, NexaUI.NexaTokens.radiusLg)

    // ------------------------------------------------------------
    // SURFACE
    // ------------------------------------------------------------

    interactive: true
    padding: 0

    Behavior on implicitWidth {
        NumberAnimation {
            duration: NexaUI.NexaMotion.durationNormal
            easing.type: NexaUI.NexaMotion.standardEasing
        }
    }

    function appIconSource(id) {
        return AppLauncher.AppRegistry.resolveAppIcon(id)
    }

    // ------------------------------------------------------------
    // CONTENT ROW: ( ICON | TICKER TEXT )
    // ------------------------------------------------------------

    RowLayout {
        id: contentRow

        anchors {
            fill: parent
            leftMargin: NexaUI.NexaTokens.spacingSm
            rightMargin: NexaUI.NexaTokens.spacingSm
        }

        spacing: NexaUI.NexaTokens.spacingXs

        // Application Icon
        Image {
            id: appIcon

            Layout.preferredWidth: NexaUI.NexaTokens.iconSm
            Layout.preferredHeight: NexaUI.NexaTokens.iconSm
            Layout.alignment: Qt.AlignVCenter

            source: root.hasApp ? root.appIconSource(root.appId) : ""

            visible: root.hasApp

            fillMode: Image.PreserveAspectFit
            smooth: true
            mipmap: true

            Behavior on opacity {
                NumberAnimation {
                    duration: NexaUI.NexaMotion.durationFast
                    easing.type: NexaUI.NexaMotion.standardEasing
                }
            }
        }

        // Animated Marquee Ticker for App Title
        Item {
            id: tickerContainer

            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            visible: root.hasApp

            readonly property bool needsScroll:
                tickerText.implicitWidth > tickerContainer.width

            readonly property real scrollDistance:
                Math.max(0, tickerText.implicitWidth - tickerContainer.width)

            Text {
                id: tickerText

                anchors.verticalCenter: parent.verticalCenter
                x: tickerContainer.needsScroll ? -tickerAnim.scrollX : 0

                text: root.displayText
                color: NexaUI.NexaColors.text
                font.family: NexaUI.NexaTypography.familyBody
                font.pixelSize: NexaUI.NexaTypography.sizeSm
                font.weight: NexaUI.NexaTypography.weightMedium

                elide: tickerContainer.needsScroll ? Text.ElideNone : Text.ElideRight

                Behavior on color {
                    ColorAnimation {
                        duration: NexaUI.NexaMotion.durationFast
                        easing.type: NexaUI.NexaMotion.standardEasing
                    }
                }
            }

            SequentialAnimation {
                id: tickerAnim

                property real scrollX: 0

                running: tickerContainer.needsScroll && !root.hovered
                loops: Animation.Infinite

                PauseAnimation { duration: 2500 }

                NumberAnimation {
                    target: tickerAnim
                    property: "scrollX"
                    from: 0
                    to: tickerContainer.scrollDistance
                    duration: Math.max(1200, tickerContainer.scrollDistance * 28)
                    easing.type: Easing.Linear
                }

                PauseAnimation { duration: 1800 }

                NumberAnimation {
                    target: tickerAnim
                    property: "scrollX"
                    from: tickerContainer.scrollDistance
                    to: 0
                    duration: Math.max(800, tickerContainer.scrollDistance * 16)
                    easing.type: NexaUI.NexaMotion.standardEasing
                }
            }

            Connections {
                target: root
                function onDisplayTextChanged() {
                    tickerAnim.scrollX = 0
                    tickerAnim.restart()
                }
            }
        }

        // Empty state dot when no active window
        Rectangle {
            Layout.alignment: Qt.AlignCenter
            visible: !root.hasApp
            width: 6
            height: 6
            radius: 3
            color: NexaUI.NexaColors.mutedText
            opacity: 0.5
        }
    }
}
