import QtQuick
import QtQuick.Layouts
import Quickshell

import "../../theme" as Nexa


PopupWindow {
    id: root

    property Item anchorItem
    property string title: ""
    property var rows: []

    implicitWidth: Math.max(220, content.implicitWidth + Nexa.Theme.spacingXl)
    implicitHeight: content.implicitHeight + Nexa.Theme.spacingMd * 2

    color: "transparent"


    // ============================================================
    // POSITION
    //
    // Anchor to the bottom-center of the icon.
    // Popup expands downward and stays visually connected.
    // The extra +2 px on rect.y prevents the tooltip from
    // overlapping the bar icon when it first appears.
    // ============================================================

    anchor {
        item: root.anchorItem

        rect.x:
            root.anchorItem
            ? root.anchorItem.width / 2
            : 0

        rect.y:
            root.anchorItem
            ? root.anchorItem.height + 2
            : 0

        rect.width: 1
        rect.height: 1

        edges: Edges.Top
        gravity: Edges.Bottom
    }


    // ============================================================
    // SURFACE
    // ============================================================

    Rectangle {
        id: card

        anchors.fill: parent

        radius: Nexa.Theme.radiusMd
        color: Nexa.Theme.popupBackground

        border {
            width: Nexa.Theme.borderThin
            color: Nexa.Theme.border
        }


        // --------------------------------------------------------
        // FADE + SLIDE  (FIXED DIRECTION)
        //
        // When appearing: slide DOWN from -slideSmall → 0
        // Previously this was reversed (sliding toward the bar).
        // --------------------------------------------------------

        opacity:
            root.visible
            ? Nexa.Theme.opacityFull
            : Nexa.Theme.opacityHidden

        scale:
            root.visible
            ? 1.0
            : 0.95

        // Slide y from -spacingXs upward when hidden → 0 when visible
        // (translates DOWN on appear since origin is top of popup)
        transform: Translate {
            id: slideTranslate
            y: root.visible ? 0 : -Nexa.Theme.spacingXs
        }


        Behavior on opacity {
            NumberAnimation {
                duration: Nexa.Theme.animationFast
                easing.type: Nexa.Theme.easingEnter
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: Nexa.Theme.animationFast
                easing.type: Nexa.Theme.easingEmphasized
            }
        }


        ColumnLayout {
            id: content

            anchors {
                fill: parent
                margins: Nexa.Theme.spacingMd
            }

            spacing: Nexa.Theme.spacingSm


            // ----------------------------------------------------
            // TITLE
            // ----------------------------------------------------

            Text {
                Layout.fillWidth: true

                text: root.title
                color: Nexa.Theme.text

                font {
                    family: Nexa.Theme.fontFamily
                    pixelSize: Nexa.Theme.fontSizeSm
                    weight: Nexa.Theme.fontWeightDemiBold
                }
            }


            // ----------------------------------------------------
            // INFO ROWS
            // ----------------------------------------------------

            Repeater {
                model: root.rows


                delegate: RowLayout {
                    required property var modelData

                    Layout.fillWidth: true


                    Text {
                        text: modelData[0]
                        color: Nexa.Theme.mutedText

                        font {
                            family: Nexa.Theme.fontFamily
                            pixelSize: Nexa.Theme.fontSizeXs
                        }
                    }


                    Item {
                        Layout.fillWidth: true
                    }


                    Text {
                        text: modelData[1]
                        color: Nexa.Theme.text

                        font {
                            family: Nexa.Theme.fontFamily
                            pixelSize: Nexa.Theme.fontSizeXs
                            weight: Nexa.Theme.fontWeightMedium
                        }
                    }
                }
            }
        }
    }
}
