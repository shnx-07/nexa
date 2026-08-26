import QtQuick
import QtQuick.Layouts

import Quickshell

import "../../theme" as Nexa


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

            leftMargin:
                Nexa.Theme.spacingLg

            rightMargin:
                Nexa.Theme.spacingLg

            topMargin:
                Nexa.Theme.spacingMd

            bottomMargin:
                Nexa.Theme.spacingMd
        }

        spacing:
            Nexa.Theme.spacingMd


        // ========================================================
        // APP ICON
        // ========================================================

        Rectangle {
            Layout.preferredWidth:
                Nexa.Theme.controlHeightLg

            Layout.preferredHeight:
                Nexa.Theme.controlHeightLg

            Layout.alignment:
                Qt.AlignVCenter

            radius:
                Nexa.Theme.radiusMd

            color:
                Nexa.Theme.surfaceContainerHighest


            Image {
                id: notificationIcon

                anchors {
                    fill: parent
                    margins:
                        Nexa.Theme.spacingXs
                }

                source:
                    root.notification
                        ? root.notification.appIcon || ""
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
                    Nexa.Theme.primary

                font {
                    family:
                        Nexa.Theme.iconFontFamily

                    pixelSize:
                        Nexa.Theme.iconMd
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
                Nexa.Theme.spacing2Xs


            RowLayout {
                Layout.fillWidth:
                    true

                spacing:
                    Nexa.Theme.spacingSm


                Text {
                    Layout.fillWidth:
                        true

                    text:
                        root.notification
                            ? root.notification.appName || "Application"
                            : ""

                    color:
                        Nexa.Theme.mutedText

                    elide:
                        Text.ElideRight

                    font {
                        family:
                            Nexa.Theme.fontFamily

                        pixelSize:
                            Nexa.Theme.fontSizeXs

                        weight:
                            Nexa.Theme.fontWeightMedium
                    }
                }


                Text {
                    text:
                        "now"

                    color:
                        Nexa.Theme.mutedText

                    font {
                        family:
                            Nexa.Theme.fontFamily

                        pixelSize:
                            Nexa.Theme.fontSize2Xs
                    }
                }
            }


            Text {
                Layout.fillWidth:
                    true

                text:
                    root.notification
                        ? root.notification.summary || ""
                        : ""

                color:
                    Nexa.Theme.text

                elide:
                    Text.ElideRight

                maximumLineCount:
                    1

                font {
                    family:
                        Nexa.Theme.fontFamily

                    pixelSize:
                        Nexa.Theme.fontSizeSm

                    weight:
                        Nexa.Theme.fontWeightDemiBold
                }
            }


            Text {
                Layout.fillWidth:
                    true

                visible:
                    text.length > 0

                text:
                    root.notification
                        ? root.notification.body || ""
                        : ""

                color:
                    Nexa.Theme.mutedText

                elide:
                    Text.ElideRight

                maximumLineCount:
                    1

                font {
                    family:
                        Nexa.Theme.fontFamily

                    pixelSize:
                        Nexa.Theme.fontSizeXs
                }
            }
        }
    }


    // ============================================================
    // WHOLE PREVIEW IS CLICKABLE
    //
    // No actions here.
    // Actions belong to Side Panel notifications.
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
