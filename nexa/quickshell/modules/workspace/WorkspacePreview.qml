import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland

import "../../theme" as Nexa
import "../../theme/components" as NexaUI

PopupWindow {
    id: root

    property Item anchorItem: null
    property var workspace: null
    property bool activeWorkspace: false
    property bool previewVisible: false

    readonly property int workspaceId:
        workspace ? workspace.id : -1

    readonly property var windowList: {
        if (workspaceId < 0 || typeof Hyprland === "undefined" || !Hyprland.toplevels)
            return []

        const result = []
        const toplevels = Hyprland.toplevels.values

        for (let i = 0; i < toplevels.length; ++i) {
            const tl = toplevels[i]
            if (tl && tl.workspace && tl.workspace.id === workspaceId) {
                result.push(tl)
            }
        }

        return result
    }

    readonly property var activeWindow: {
        return windowList.length > 0 ? windowList[0] : null
    }

    readonly property real monitorWidth: {
        if (typeof Hyprland !== "undefined" && Hyprland.focusedMonitor && Hyprland.focusedMonitor.width > 0)
            return Hyprland.focusedMonitor.width
        return 1920
    }

    readonly property real monitorHeight: {
        if (typeof Hyprland !== "undefined" && Hyprland.focusedMonitor && Hyprland.focusedMonitor.height > 0)
            return Hyprland.focusedMonitor.height
        return 1080
    }

    implicitWidth: 320
    implicitHeight: card.implicitHeight

    color: "transparent"

    visible: previewVisible && anchorItem !== null && !activeWorkspace

    anchor {
        item: root.anchorItem

        rect.x: root.anchorItem ? root.anchorItem.width / 2 : 0
        rect.y: root.anchorItem ? root.anchorItem.height + 6 : 0
        rect.width: 1
        rect.height: 1

        edges: Edges.Top
        gravity: Edges.Bottom
    }

    Rectangle {
        id: card

        width: 320
        implicitHeight: mainColumn.implicitHeight

        radius: Nexa.Theme.radiusLg

        color: Qt.rgba(24/255, 25/255, 28/255, 0.98)

        border.width: Nexa.Theme.borderThin
        border.color: Qt.rgba(255/255, 255/255, 255/255, 0.15)

        clip: true

        opacity: root.previewVisible ? 1.0 : 0.0
        scale: root.previewVisible ? 1.0 : 0.92

        Behavior on opacity {
            NumberAnimation {
                duration: Nexa.Theme.animationNormal
                easing.type: Easing.OutQuint
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: Nexa.Theme.animationNormal
                easing.type: Easing.OutQuint
            }
        }

        ColumnLayout {
            id: mainColumn

            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
            }

            spacing: 0

            // ------------------------------------------------------------
            // CHROME-STYLE TOP HEADER BAR WITH CLOSE BUTTON (X)
            // ------------------------------------------------------------

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 38

                color: Qt.rgba(36/255, 38/255, 42/255, 0.95)

                RowLayout {
                    anchors {
                        fill: parent
                        leftMargin: 12
                        rightMargin: 10
                    }
                    spacing: 8

                    Image {
                        Layout.preferredWidth: 20
                        Layout.preferredHeight: 20
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true

                        source: {
                            const appId = root.activeWindow ? (root.activeWindow.appId || "") : ""
                            const iconPath = Quickshell.iconPath(appId.toLowerCase(), "application-x-executable")
                            return iconPath !== "" ? iconPath : Quickshell.iconPath("application-x-executable")
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Text {
                            Layout.fillWidth: true
                            text: {
                                if (root.activeWindow) {
                                    const title = root.activeWindow.title || root.activeWindow.appId || ("Workspace " + root.workspaceId)
                                    return title
                                }
                                return "Workspace " + root.workspaceId
                            }
                            color: Nexa.Theme.text
                            elide: Text.ElideRight

                            font {
                                family: Nexa.Theme.fontFamily
                                pixelSize: Nexa.Theme.fontSizeXs
                                weight: Nexa.Theme.fontWeightDemiBold
                            }
                        }
                    }

                    // Close Button (X)
                    Rectangle {
                        Layout.preferredWidth: 22
                        Layout.preferredHeight: 22
                        radius: height / 2

                        color: closeMouse.containsMouse
                            ? Qt.rgba(255/255, 255/255, 255/255, 0.15)
                            : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: "✕"
                            color: closeMouse.containsMouse ? Nexa.Theme.text : Nexa.Theme.mutedText
                            font.pixelSize: 12
                        }

                        MouseArea {
                            id: closeMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            onClicked: {
                                root.previewVisible = false
                                if (root.activeWindow && typeof root.activeWindow.close === "function") {
                                    root.activeWindow.close()
                                }
                            }
                        }
                    }
                }
            }

            // ------------------------------------------------------------
            // VISUAL WORKSPACE SCREEN MIRROR CANVAS
            // ------------------------------------------------------------

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 190

                Rectangle {
                    id: miniDesktopCanvas

                    anchors {
                        fill: parent
                        margins: 8
                    }

                    radius: Nexa.Theme.radiusSm
                    color: Qt.rgba(14/255, 16/255, 20/255, 0.95)
                    border.width: Nexa.Theme.borderThin
                    border.color: Qt.rgba(255/255, 255/255, 255/255, 0.12)
                    clip: true

                    // Desktop Grid Background Pattern
                    Item {
                        anchors.fill: parent

                        Repeater {
                            model: 6
                            delegate: Rectangle {
                                x: (index % 3) * (miniDesktopCanvas.width / 3)
                                y: Math.floor(index / 3) * (miniDesktopCanvas.height / 2)
                                width: miniDesktopCanvas.width / 3
                                height: miniDesktopCanvas.height / 2
                                color: "transparent"
                                border.width: 1
                                border.color: Qt.rgba(255/255, 255/255, 255/255, 0.03)
                            }
                        }
                    }

                    // Render Window Cards for THAT Target Workspace
                    Repeater {
                        model: root.windowList

                        delegate: NexaUI.NexaCard {
                            id: targetWinFrame

                            required property var modelData
                            required property int index

                            readonly property real scaleX: miniDesktopCanvas.width / root.monitorWidth
                            readonly property real scaleY: miniDesktopCanvas.height / root.monitorHeight

                            x: Math.max(4, Math.min(miniDesktopCanvas.width - width - 4, (modelData && modelData.at ? modelData.at.x : 0) * scaleX))
                            y: Math.max(4, Math.min(miniDesktopCanvas.height - height - 4, (modelData && modelData.at ? modelData.at.y : 0) * scaleY))

                            implicitWidth: Math.max(70, Math.min(miniDesktopCanvas.width - 8, (modelData && modelData.size ? modelData.size.width : 400) * scaleX))
                            implicitHeight: Math.max(48, Math.min(miniDesktopCanvas.height - 8, (modelData && modelData.size ? modelData.size.height : 300) * scaleY))

                            radius: Nexa.Theme.radiusSm
                            padding: 0
                            interactive: true

                            onClicked: {
                                if (root.workspace) {
                                    root.workspace.activate()
                                }
                                if (targetWinFrame.modelData && typeof targetWinFrame.modelData.focus === "function") {
                                    targetWinFrame.modelData.focus()
                                }
                            }

                            // Window Control Dots Accent
                            Row {
                                anchors {
                                    top: parent.top
                                    left: parent.left
                                    margins: 5
                                }
                                spacing: 3

                                Rectangle { width: 5; height: 5; radius: 2.5; color: "#ff5f56" }
                                Rectangle { width: 5; height: 5; radius: 2.5; color: "#ffbd2e" }
                                Rectangle { width: 5; height: 5; radius: 2.5; color: "#27c93f" }
                            }

                            // App Icon & Title
                            ColumnLayout {
                                anchors {
                                    centerIn: parent
                                    margins: 2
                                }
                                spacing: 2

                                Image {
                                    Layout.alignment: Qt.AlignHCenter
                                    Layout.preferredWidth: Math.min(24, targetWinFrame.height * 0.45)
                                    Layout.preferredHeight: Math.min(24, targetWinFrame.height * 0.45)
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true

                                    source: {
                                        const appId = targetWinFrame.modelData ? (targetWinFrame.modelData.appId || "") : ""
                                        const iconPath = Quickshell.iconPath(appId.toLowerCase(), "application-x-executable")
                                        return iconPath !== "" ? iconPath : Quickshell.iconPath("application-x-executable")
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    Layout.maximumWidth: targetWinFrame.width - 10
                                    horizontalAlignment: Text.AlignHCenter
                                    text: targetWinFrame.modelData ? (targetWinFrame.modelData.title || targetWinFrame.modelData.appId || "") : ""
                                    color: Nexa.Theme.text
                                    elide: Text.ElideRight

                                    font {
                                        family: Nexa.Theme.fontFamily
                                        pixelSize: 10
                                        weight: Nexa.Theme.fontWeightMedium
                                    }
                                }
                            }
                        }
                    }

                    // Empty Workspace State
                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 4
                        visible: root.windowList.length === 0

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "🖥️"
                            font.pixelSize: 24
                            opacity: 0.6
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "Workspace " + root.workspaceId + " is Empty"
                            color: Nexa.Theme.mutedText

                            font {
                                family: Nexa.Theme.fontFamily
                                pixelSize: Nexa.Theme.fontSizeXs
                                weight: Nexa.Theme.fontWeightMedium
                            }
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "Click to switch to this workspace"
                            color: Nexa.Theme.mutedText

                            font {
                                family: Nexa.Theme.fontFamily
                                pixelSize: 10
                            }
                        }
                    }

                    // Click backdrop to switch to target workspace
                    MouseArea {
                        anchors.fill: parent
                        z: -1
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        onClicked: {
                            if (root.workspace) {
                                root.workspace.activate()
                            }
                        }
                    }
                }
            }
        }
    }
}
