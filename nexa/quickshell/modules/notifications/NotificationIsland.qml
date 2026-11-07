import QtQuick
import QtQuick.Layouts

import Quickshell

import "../../NewNexaUI" as NexaUI


Item {
    id: root

    // ============================================================
    // INPUT
    // ============================================================

    property var notification: null

    signal activated()


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
        // APP ICON SQUIRCLE
        // ========================================================

        Rectangle {
            Layout.preferredWidth: 36
            Layout.preferredHeight: 36
            Layout.alignment: Qt.AlignVCenter

            radius: NexaUI.NexaTokens.radiusSm
            color: NexaUI.NexaColors.surfaceContainerHigh
            border.width: NexaUI.NexaTokens.borderThin
            border.color: NexaUI.NexaColors.borderSubtle

            Image {
                id: notificationIcon

                anchors {
                    fill: parent
                    margins: NexaUI.NexaTokens.spacingXs
                }

                source:
                    root.notification
                        ? (root.notification.appIcon || "")
                        : ""

                visible:
                    source.toString().length > 0

                fillMode:
                    Image.PreserveAspectFit

                asynchronous:
                    true

                smooth:
                    true
            }

            Text {
                anchors.centerIn:
                    parent

                visible:
                    !notificationIcon.visible

                text:
                    "󰂚"

                color:
                    NexaUI.NexaColors.primary

                font {
                    family:
                        NexaUI.NexaTypography.familyIcon

                    pixelSize:
                        NexaUI.NexaTypography.sizeLg
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
        anchors.fill:
            parent

        cursorShape:
            Qt.PointingHandCursor

        onClicked:
            root.activated()
    }
}
