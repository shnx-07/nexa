import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import Quickshell
import Quickshell.Io

import "../../theme" as Nexa
import "../../theme/components" as NexaUI

Item {
    id: root

    // ============================================================
    // NEXA NOTIFICATIONS (Apple-Inspired Modern UI)
    //
    // Rust backend owns:
    // - D-Bus notification daemon
    // - State & history file (~/.cache/nexa/notifications.json)
    // - Dismiss / clear / action dispatch
    // ============================================================

    property var notificationData: ({
        "notifications": [],
        "unreadCount": 0
    })

    readonly property var notificationListModel:
        notificationData.notifications || []

    readonly property int totalCount:
        notificationListModel.length

    readonly property int unreadCount:
        notificationData.unreadCount || 0

    // ============================================================
    // STATE FILE WATCHER
    // ============================================================

    FileView {
        id: notificationState

        path: Quickshell.env("HOME") + "/.cache/nexa/notifications.json"
        watchChanges: true

        onFileChanged: reload()
        onLoaded: root.loadState()
    }

    function loadState() {
        try {
            const text = notificationState.text()
            if (!text || text.length === 0) return
            root.notificationData = JSON.parse(text)
        } catch (error) {
            console.warn("NEXA notifications state error:", error)
        }
    }

    // ============================================================
    // PRESENTATION HELPERS
    // ============================================================

    function formatTimestamp(timestamp) {
        if (!timestamp) return ""
        const now = Math.floor(Date.now() / 1000)
        const diff = Math.max(0, now - timestamp)

        if (diff < 60) return "now"
        if (diff < 3600) return Math.floor(diff / 60) + "m ago"
        if (diff < 86400) return Math.floor(diff / 3600) + "h ago"
        if (diff < 172800) return "Yesterday"

        const date = new Date(timestamp * 1000)
        return Qt.formatDate(date, "dd MMM")
    }

    function iconSource(icon) {
        if (!icon || icon.length === 0) return ""
        if (icon.startsWith("/") || icon.startsWith("file://"))
            return icon
        return ""
    }

    // ============================================================
    // MAIN LAYOUT
    // ============================================================

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Nexa.Theme.spacingMd
        spacing: Nexa.Theme.spacingMd

        // ========================================================
        // APPLE-STYLE HEADER
        // ========================================================

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 52
            radius: 16
            color: Nexa.Theme.surfaceContainer
            border.width: Nexa.Theme.borderThin
            border.color: Nexa.Theme.border

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Nexa.Theme.spacingLg
                anchors.rightMargin: Nexa.Theme.spacingLg
                spacing: Nexa.Theme.spacingSm

                // Section Title
                Text {
                    text: "Notifications"
                    color: Nexa.Theme.text
                    font.family: Nexa.Theme.fontFamily
                    font.pixelSize: Nexa.Theme.fontSizeLg
                    font.weight: Nexa.Theme.fontWeightDemiBold
                    Layout.alignment: Qt.AlignVCenter
                }

                // Unread Badge Capsule
                Rectangle {
                    visible: root.unreadCount > 0
                    implicitHeight: 22
                    implicitWidth: unreadBadgeText.implicitWidth + 14
                    radius: 11
                    color: Qt.rgba(Nexa.Theme.primary.r, Nexa.Theme.primary.g, Nexa.Theme.primary.b, 0.16)
                    border.width: 1
                    border.color: Qt.rgba(Nexa.Theme.primary.r, Nexa.Theme.primary.g, Nexa.Theme.primary.b, 0.35)
                    Layout.alignment: Qt.AlignVCenter

                    Text {
                        id: unreadBadgeText
                        anchors.centerIn: parent
                        text: root.unreadCount + " new"
                        color: Nexa.Theme.primary
                        font.family: Nexa.Theme.fontFamily
                        font.pixelSize: 11
                        font.weight: Nexa.Theme.fontWeightBold
                    }
                }

                Item { Layout.fillWidth: true }

                // Clear All Button (Apple-Style Glass Capsule)
                Rectangle {
                    id: clearBtn
                    visible: root.totalCount > 0
                    implicitHeight: 28
                    implicitWidth: clearRow.implicitWidth + 16
                    radius: 14
                    color: clearMouse.pressed
                           ? Nexa.Theme.surfaceContainerHighest
                           : (clearMouse.containsMouse ? Nexa.Theme.surfaceContainerHigh : Nexa.Theme.surfaceContainerLow)
                    border.width: Nexa.Theme.borderThin
                    border.color: clearMouse.containsMouse ? Nexa.Theme.outline : Nexa.Theme.border
                    scale: clearMouse.pressed ? 0.96 : (clearMouse.containsMouse ? 1.02 : 1.0)
                    Layout.alignment: Qt.AlignVCenter

                    Behavior on color { ColorAnimation { duration: 120 } }
                    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }

                    Row {
                        id: clearRow
                        anchors.centerIn: parent
                        spacing: 5

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "󰆴"
                            color: clearMouse.containsMouse ? Nexa.Theme.error : Nexa.Theme.mutedText
                            font.family: Nexa.Theme.iconFontFamily
                            font.pixelSize: 13
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Clear All"
                            color: clearMouse.containsMouse ? Nexa.Theme.text : Nexa.Theme.mutedText
                            font.family: Nexa.Theme.fontFamily
                            font.pixelSize: 12
                            font.weight: Nexa.Theme.fontWeightMedium
                        }
                    }

                    MouseArea {
                        id: clearMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Quickshell.execDetached([
                                "sh",
                                "-c",
                                "\"$HOME/.config/nexa/rust/target/release/nexad\" notifications clear"
                            ])
                        }
                    }
                }
            }
        }

        // ========================================================
        // EMPTY STATE (Apple Minimalist Aesthetic)
        // ========================================================

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.totalCount === 0

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 12

                // Ambient glowing bell icon container
                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: 68
                    implicitHeight: 68
                    radius: 34
                    color: Qt.rgba(Nexa.Theme.primary.r, Nexa.Theme.primary.g, Nexa.Theme.primary.b, 0.08)
                    border.width: 1
                    border.color: Qt.rgba(Nexa.Theme.primary.r, Nexa.Theme.primary.g, Nexa.Theme.primary.b, 0.2)

                    Text {
                        anchors.centerIn: parent
                        text: "󰂚"
                        color: Nexa.Theme.primary
                        font.family: Nexa.Theme.iconFontFamily
                        font.pixelSize: 30
                    }
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "No Notifications"
                    color: Nexa.Theme.text
                    font.family: Nexa.Theme.fontFamily
                    font.pixelSize: 16
                    font.weight: Nexa.Theme.fontWeightDemiBold
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "You're completely caught up"
                    color: Nexa.Theme.mutedText
                    font.family: Nexa.Theme.fontFamily
                    font.pixelSize: 13
                }
            }
        }

        // ========================================================
        // NOTIFICATION LIST (Apple Frosted Glass Cards)
        // ========================================================

        ListView {
            id: notificationList

            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.totalCount > 0
            clip: true
            spacing: 10
            model: root.notificationListModel

            boundsBehavior: Flickable.StopAtBounds
            flickDeceleration: Nexa.Theme.flickDeceleration
            maximumFlickVelocity: Nexa.Theme.flickVelocityMax

            delegate: Rectangle {
                id: cardRoot
                required property var modelData

                width: notificationList.width
                implicitHeight: cardCol.implicitHeight + 28
                radius: 16
                color: cardMouse.containsMouse
                       ? Nexa.Theme.surfaceContainerHigh
                       : Nexa.Theme.surfaceContainer
                border.width: Nexa.Theme.borderThin
                border.color: !cardRoot.modelData.read
                              ? Qt.rgba(Nexa.Theme.primary.r, Nexa.Theme.primary.g, Nexa.Theme.primary.b, 0.4)
                              : (cardMouse.containsMouse ? Nexa.Theme.outline : Nexa.Theme.border)
                scale: cardMouse.pressed ? 0.985 : (cardMouse.containsMouse ? 1.008 : 1.0)

                Behavior on color { ColorAnimation { duration: 140 } }
                Behavior on border.color { ColorAnimation { duration: 140 } }
                Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutQuad } }

                // ------------------------------------------------
                // UNREAD ACCENT PILL (Apple-Style Left Indicator)
                // ------------------------------------------------
                Rectangle {
                    visible: !cardRoot.modelData.read
                    width: 4
                    height: 28
                    radius: 2
                    color: Nexa.Theme.primary
                    anchors {
                        left: parent.left
                        leftMargin: 5
                        verticalCenter: parent.verticalCenter
                    }
                }

                // ------------------------------------------------
                // CARD CONTENT
                // ------------------------------------------------
                ColumnLayout {
                    id: cardCol
                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                        leftMargin: cardRoot.modelData.read ? 16 : 18
                        rightMargin: 14
                        topMargin: 14
                    }
                    spacing: 6

                    // =============================================
                    // TOP METADATA ROW: Icon + App + Time + Dismiss
                    // =============================================
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        // App Icon Squircle
                        Rectangle {
                            implicitWidth: 22
                            implicitHeight: 22
                            radius: 6
                            color: Nexa.Theme.surfaceContainerHighest
                            clip: true
                            Layout.alignment: Qt.AlignVCenter

                            Image {
                                id: appImage
                                anchors.fill: parent
                                anchors.margins: 2
                                visible: source.toString().length > 0
                                source: root.iconSource(cardRoot.modelData.appIcon || "")
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                                smooth: true
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: !appImage.visible
                                text: "󰂚"
                                color: Nexa.Theme.primary
                                font.family: Nexa.Theme.iconFontFamily
                                font.pixelSize: 11
                            }
                        }

                        // App Name
                        Text {
                            text: (cardRoot.modelData.appName || "Notification").toUpperCase()
                            color: Nexa.Theme.mutedText
                            font.family: Nexa.Theme.fontFamily
                            font.pixelSize: 10
                            font.weight: Nexa.Theme.fontWeightBold
                            font.letterSpacing: 0.5
                            elide: Text.ElideRight
                            Layout.alignment: Qt.AlignVCenter
                        }

                        // Middle Dot
                        Text {
                            text: "•"
                            color: Nexa.Theme.mutedText
                            font.pixelSize: 10
                            opacity: 0.6
                            Layout.alignment: Qt.AlignVCenter
                        }

                        // Timestamp
                        Text {
                            text: root.formatTimestamp(cardRoot.modelData.timestamp)
                            color: Nexa.Theme.mutedText
                            font.family: Nexa.Theme.fontFamily
                            font.pixelSize: 11
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Item { Layout.fillWidth: true }

                        // Apple-Style Circular Micro Dismiss Button
                        Rectangle {
                            id: dismissBtn
                            implicitWidth: 22
                            implicitHeight: 22
                            radius: 11
                            color: dismissMouse.pressed
                                   ? Nexa.Theme.surfaceContainerHighest
                                   : (dismissMouse.containsMouse ? Nexa.Theme.surfaceContainerHighest : "transparent")
                            border.width: dismissMouse.containsMouse ? 1 : 0
                            border.color: Nexa.Theme.border
                            scale: dismissMouse.pressed ? 0.9 : 1.0

                            Behavior on color { ColorAnimation { duration: 100 } }
                            Behavior on scale { NumberAnimation { duration: 100 } }

                            Text {
                                anchors.centerIn: parent
                                text: "󰅖"
                                color: dismissMouse.containsMouse ? Nexa.Theme.error : Nexa.Theme.mutedText
                                font.family: Nexa.Theme.iconFontFamily
                                font.pixelSize: 11
                            }

                            MouseArea {
                                id: dismissMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    Quickshell.execDetached([
                                        "sh",
                                        "-c",
                                        "\"$HOME/.config/nexa/rust/target/release/nexad\" notifications dismiss "
                                            + cardRoot.modelData.id
                                    ])
                                }
                            }
                        }
                    }

                    // =============================================
                    // SUMMARY / TITLE
                    // =============================================
                    Text {
                        Layout.fillWidth: true
                        visible: text.length > 0
                        text: cardRoot.modelData.summary || ""
                        color: Nexa.Theme.text
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        font.family: Nexa.Theme.fontFamily
                        font.pixelSize: 14
                        font.weight: Nexa.Theme.fontWeightDemiBold
                    }

                    // =============================================
                    // BODY
                    // =============================================
                    Text {
                        Layout.fillWidth: true
                        visible: text.length > 0
                        text: cardRoot.modelData.body || ""
                        color: Nexa.Theme.mutedText
                        wrapMode: Text.Wrap
                        maximumLineCount: 3
                        elide: Text.ElideRight
                        font.family: Nexa.Theme.fontFamily
                        font.pixelSize: 12
                        lineHeight: 1.15
                    }

                    // =============================================
                    // ACTION BUTTONS (Apple Pill Buttons)
                    // =============================================
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 4
                        visible: cardRoot.modelData.actions && cardRoot.modelData.actions.length > 0
                        spacing: 8

                        Repeater {
                            model: cardRoot.modelData.actions || []

                            delegate: Rectangle {
                                id: actionPill
                                required property var modelData

                                implicitHeight: 28
                                implicitWidth: actionLabel.implicitWidth + 20
                                radius: 8
                                color: actionMouse.pressed
                                       ? Nexa.Theme.surfaceContainerHighest
                                       : (actionMouse.containsMouse ? Nexa.Theme.surfaceContainerHigh : Nexa.Theme.surfaceContainerLow)
                                border.width: Nexa.Theme.borderThin
                                border.color: Nexa.Theme.border
                                scale: actionMouse.pressed ? 0.96 : (actionMouse.containsMouse ? 1.02 : 1.0)

                                Behavior on color { ColorAnimation { duration: 100 } }
                                Behavior on scale { NumberAnimation { duration: 100 } }

                                Text {
                                    id: actionLabel
                                    anchors.centerIn: parent
                                    text: actionPill.modelData.label || ""
                                    color: Nexa.Theme.text
                                    font.family: Nexa.Theme.fontFamily
                                    font.pixelSize: 12
                                    font.weight: Nexa.Theme.fontWeightMedium
                                }

                                MouseArea {
                                    id: actionMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        Quickshell.execDetached([
                                            "sh",
                                            "-c",
                                            "\"$HOME/.config/nexa/rust/target/release/nexad\" notifications action "
                                                + cardRoot.modelData.id
                                                + " "
                                                + "\"" + actionPill.modelData.key + "\""
                                        ])
                                    }
                                }
                            }
                        }

                        Item { Layout.fillWidth: true }
                    }
                }

                // Interactive Card MouseArea for hover lift
                MouseArea {
                    id: cardMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    z: -1 // Behind buttons
                }
            }
        }
    }

    // ============================================================
    // TIMESTAMP AUTO-REFRESH (Every minute)
    // ============================================================
    Timer {
        interval: 60000
        repeat: true
        running: true
        onTriggered: notificationList.forceLayout()
    }
}
