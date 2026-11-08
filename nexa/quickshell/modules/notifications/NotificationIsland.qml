import QtQuick
import QtQuick.Layouts

import Quickshell

import "../../NewNexaUI" as NexaUI
import "../appLauncher" as AppLauncher


Item {
    id: root

    // ============================================================
    // INPUT
    // ============================================================

    property var notification: null

    signal activated()

    readonly property string rawAppName:
        root.notification ? String(root.notification.appName || "") : ""

    readonly property string rawIcon:
        root.notification ? String(root.notification.appIcon || "") : ""

    readonly property bool isScreenshot: {
        const name = rawAppName.toLowerCase()
        if (name === "screenshot" || name === "snipping") return true
        if (rawIcon.toLowerCase().includes("screenshot") || rawIcon.toLowerCase().includes("snip")) return true
        return false
    }

    readonly property string screenshotPath: {
        if (!isScreenshot) return ""
        let s = rawIcon
        if (s.startsWith("file://")) s = s.slice(7)
        return s
    }

    readonly property string resolvedIconSource: {
        if (!rawIcon || rawIcon.length === 0) return ""
        if (rawIcon.startsWith("file://")) return rawIcon
        if (rawIcon.startsWith("/")) return "file://" + rawIcon
        return AppLauncher.AppRegistry.resolveAppIcon(rawIcon) || rawIcon
    }


    // ============================================================
    // CONTENT
    // ============================================================

    RowLayout {
        anchors {
            fill: parent
            leftMargin: NexaUI.NexaTokens.spacingLg
            rightMargin: NexaUI.NexaTokens.spacingLg
            topMargin: NexaUI.NexaTokens.spacingSm
            bottomMargin: NexaUI.NexaTokens.spacingSm
        }

        spacing: NexaUI.NexaTokens.spacingMd


        // ========================================================
        // APP ICON / SCREENSHOT THUMBNAIL SQUIRCLE
        // ========================================================

        Rectangle {
            Layout.preferredWidth: root.isScreenshot ? 64 : 36
            Layout.preferredHeight: root.isScreenshot ? 44 : 36
            Layout.alignment: Qt.AlignVCenter

            radius: NexaUI.NexaTokens.radiusSm
            color: NexaUI.NexaColors.surfaceContainerHigh
            border.width: NexaUI.NexaTokens.borderThin
            border.color: NexaUI.NexaColors.borderSubtle
            clip: true

            Image {
                id: notificationIcon

                anchors {
                    fill: parent
                    margins: root.isScreenshot ? 0 : NexaUI.NexaTokens.spacingXs
                }

                source: root.resolvedIconSource

                visible: status === Image.Ready

                fillMode: root.isScreenshot ? Image.PreserveAspectCrop : Image.PreserveAspectFit

                asynchronous: true

                smooth: true
            }

            Text {
                anchors.centerIn: parent

                visible: !notificationIcon.visible

                text: root.isScreenshot ? "󰄄" : "󰂚"

                color: NexaUI.NexaColors.primary

                font {
                    family: NexaUI.NexaTypography.familyIcon
                    pixelSize: NexaUI.NexaTypography.sizeLg
                }
            }
        }


        // ========================================================
        // TEXT
        // ========================================================

        ColumnLayout {
            Layout.fillWidth:
                true

            Layout.alignment:
                Qt.AlignVCenter

            spacing:
                NexaUI.NexaTokens.spacing2Xs


            RowLayout {
                Layout.fillWidth:
                    true

                spacing:
                    NexaUI.NexaTokens.spacingSm

                Text {
                    Layout.fillWidth:
                        true

                    text:
                        root.notification
                            ? (root.notification.appName || "Notification")
                            : ""

                    color:
                        NexaUI.NexaColors.mutedText

                    elide:
                        Text.ElideRight

                    font {
                        family:
                            NexaUI.NexaTypography.familyBody

                        pixelSize:
                            NexaUI.NexaTypography.sizeXs

                        weight:
                            NexaUI.NexaTypography.weightMedium
                    }
                }

                Text {
                    text:
                        "now"

                    color:
                        NexaUI.NexaColors.mutedText

                    font {
                        family:
                            NexaUI.NexaTypography.familyBody

                        pixelSize:
                            NexaUI.NexaTypography.size2Xs
                    }
                }
            }


            Text {
                Layout.fillWidth:
                    true

                textFormat: Text.PlainText

                text:
                    root.notification
                        ? (root.notification.summary || "")
                        : ""

                color:
                    NexaUI.NexaColors.text

                elide:
                    Text.ElideRight

                maximumLineCount:
                    1

                font {
                    family:
                        NexaUI.NexaTypography.familyBody

                    pixelSize:
                        NexaUI.NexaTypography.sizeSm

                    weight:
                        NexaUI.NexaTypography.weightSemiBold
                }
            }


            Text {
                Layout.fillWidth:
                    true

                textFormat: Text.PlainText

                visible:
                    text.length > 0

                text:
                    root.notification
                        ? (root.notification.body || "")
                        : ""

                color:
                    NexaUI.NexaColors.mutedText

                elide:
                    Text.ElideRight

                maximumLineCount:
                    1

                font {
                    family:
                        NexaUI.NexaTypography.familyBody

                    pixelSize:
                        NexaUI.NexaTypography.sizeXs
                }
            }
        }
    }


    // ============================================================
    // WHOLE PREVIEW IS CLICKABLE
    // ============================================================

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onClicked: (mouse) => {
            if (root.isScreenshot && root.screenshotPath.length > 0) {
                if (mouse.button === Qt.RightButton) {
                    const slashIndex = root.screenshotPath.lastIndexOf("/")
                    const dir = slashIndex > 0 ? root.screenshotPath.substring(0, slashIndex) : root.screenshotPath
                    Quickshell.execDetached(["xdg-open", dir])
                } else {
                    Quickshell.execDetached(["xdg-open", root.screenshotPath])
                }
            }
            root.activated()
        }
    }
}
