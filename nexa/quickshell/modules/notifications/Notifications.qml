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
        anchors.margins: 12
        spacing: 8

        // ========================================================
        // SUBHEADER (Count, Unread badge, Clear All)
        // ========================================================
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 28
            spacing: 8

            // Count / Status
            RowLayout {
                spacing: 6

                Text {
                    text: root.totalCount > 0
                        ? (root.totalCount + (root.totalCount === 1 ? " Notification" : " Notifications"))
                        : ""
                    color: Nexa.Theme.text
                    font.family: Nexa.Theme.fontFamily
                    font.pixelSize: 13
                    font.weight: Nexa.Theme.fontWeightDemiBold
                }

                // Unread Badge Pill
                Rectangle {
                    visible: root.unreadCount > 0
                    implicitHeight: 20
                    implicitWidth: unreadBadgeText.implicitWidth + 12
                    radius: 10
                    color: Qt.rgba(Nexa.Theme.primary.r, Nexa.Theme.primary.g, Nexa.Theme.primary.b, 0.15)
                    border.width: 1
                    border.color: Qt.rgba(Nexa.Theme.primary.r, Nexa.Theme.primary.g, Nexa.Theme.primary.b, 0.3)

                    Text {
                        id: unreadBadgeText
                        anchors.centerIn: parent
                        text: root.unreadCount + " new"
                        color: Nexa.Theme.primary
                        font.family: Nexa.Theme.fontFamily
                        font.pixelSize: 10
                        font.weight: Nexa.Theme.fontWeightBold
                    }
                }
            }

            Item { Layout.fillWidth: true }

            // Clear All Button (Sleek Glass Capsule)
            Rectangle {
                id: clearBtn
                visible: root.totalCount > 0
                implicitHeight: 26
                implicitWidth: clearRow.implicitWidth + 16
                radius: 13
                color: clearMouse.pressed
                       ? Nexa.Theme.hoverStrong
                       : (clearMouse.containsMouse ? Nexa.Theme.hover : Nexa.Theme.cardBackgroundElevated)
                border.width: Nexa.Theme.borderThin
                border.color: clearMouse.containsMouse ? Nexa.Theme.outline : Nexa.Theme.border

                Row {
                    id: clearRow
                    anchors.centerIn: parent
                    spacing: 5

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "󰆴"
                        color: clearMouse.containsMouse ? Nexa.Theme.error : Nexa.Theme.mutedText
                        font.family: Nexa.Theme.iconFontFamily
                        font.pixelSize: 12
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Clear All"
                        color: clearMouse.containsMouse ? Nexa.Theme.text : Nexa.Theme.mutedText
                        font.family: Nexa.Theme.fontFamily
                        font.pixelSize: 11
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

        // ========================================================
        // EMPTY STATE (Apple Minimalist Aesthetic)
        // ========================================================
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.totalCount === 0

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 10

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: 56
                    implicitHeight: 56
                    radius: 28
                    color: Qt.rgba(Nexa.Theme.primary.r, Nexa.Theme.primary.g, Nexa.Theme.primary.b, 0.08)
                    border.width: 1
                    border.color: Qt.rgba(Nexa.Theme.primary.r, Nexa.Theme.primary.g, Nexa.Theme.primary.b, 0.2)

                    Text {
                        anchors.centerIn: parent
                        text: "󰂚"
                        color: Nexa.Theme.primary
                        font.family: Nexa.Theme.iconFontFamily
                        font.pixelSize: 26
                    }
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "No Notifications"
                    color: Nexa.Theme.text
                    font.family: Nexa.Theme.fontFamily
                    font.pixelSize: 15
                    font.weight: Nexa.Theme.fontWeightDemiBold
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "You're completely caught up"
                    color: Nexa.Theme.mutedText
                    font.family: Nexa.Theme.fontFamily
                    font.pixelSize: 12
                }
            }
        }

        // ========================================================
        // 2-COLUMN NOTIFICATION GRID (Widescreen Island Layout)
        // ========================================================
        Flickable {
            id: notificationFlickable
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.totalCount > 0
            clip: true
            contentWidth: width
            contentHeight: cardsGrid.implicitHeight + 8
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

            Grid {
                id: cardsGrid
                width: notificationFlickable.width
                columns: 2
                columnSpacing: 10
                rowSpacing: 10

                Repeater {
                    model: root.notificationListModel

                    delegate: Rectangle {
                        id: cardRoot
                        required property var modelData

                        width: (cardsGrid.width - cardsGrid.columnSpacing) / 2
                        implicitHeight: Math.max(76, cardCol.implicitHeight + 20)
                        radius: Nexa.Theme.radiusMd
                        color: cardMouse.containsMouse
                               ? Nexa.Theme.cardBackgroundElevated
                               : Nexa.Theme.cardBackground
                        border.width: Nexa.Theme.borderThin
                        border.color: !cardRoot.modelData.read
                                      ? Qt.rgba(Nexa.Theme.primary.r, Nexa.Theme.primary.g, Nexa.Theme.primary.b, 0.45)
                                      : (cardMouse.containsMouse ? Nexa.Theme.outline : Nexa.Theme.border)
                        scale: cardMouse.pressed ? 0.985 : (cardMouse.containsMouse ? 1.008 : 1.0)

                        Behavior on color { ColorAnimation { duration: 120 } }
                        Behavior on border.color { ColorAnimation { duration: 120 } }
                        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }

                        // Left Accent Pill for Unread
                        Rectangle {
                            visible: !cardRoot.modelData.read
                            width: 3
                            height: 24
                            radius: 1.5
                            color: Nexa.Theme.primary
                            anchors {
                                left: parent.left
                                leftMargin: 4
                                verticalCenter: parent.verticalCenter
                            }
                        }

                        ColumnLayout {
                            id: cardCol
                            anchors {
                                left: parent.left
                                right: parent.right
                                top: parent.top
                                leftMargin: cardRoot.modelData.read ? 12 : 14
                                rightMargin: 10
                                topMargin: 10
                            }
                            spacing: 4

                            // Top Metadata Row: Icon + App Name + Time + Dismiss Button
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                // App Icon Squircle
                                Rectangle {
                                    implicitWidth: 18
                                    implicitHeight: 18
                                    radius: 5
                                    color: Nexa.Theme.surfaceContainerHighest
                                    clip: true
                                    Layout.alignment: Qt.AlignVCenter

                                    Image {
                                        id: appImage
                                        anchors.fill: parent
                                        anchors.margins: 1
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
                                        font.pixelSize: 10
                                    }
                                }

                                // App Name
                                Text {
                                    text: (cardRoot.modelData.appName || "Notification").toUpperCase()
                                    color: Nexa.Theme.mutedText
                                    font.family: Nexa.Theme.fontFamily
                                    font.pixelSize: 9
                                    font.weight: Nexa.Theme.fontWeightBold
                                    font.letterSpacing: 0.5
                                    elide: Text.ElideRight
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                // Dot
                                Text {
                                    text: "•"
                                    color: Nexa.Theme.mutedText
                                    font.pixelSize: 9
                                    opacity: 0.5
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                // Timestamp
                                Text {
                                    text: root.formatTimestamp(cardRoot.modelData.timestamp)
                                    color: Nexa.Theme.mutedText
                                    font.family: Nexa.Theme.fontFamily
                                    font.pixelSize: 10
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                Item { Layout.fillWidth: true }

                                // Dismiss Button (Micro Glass Circle)
                                Rectangle {
                                    id: dismissBtn
                                    implicitWidth: 18
                                    implicitHeight: 18
                                    radius: 9
                                    color: dismissMouse.pressed
                                           ? Nexa.Theme.hoverStrong
                                           : (dismissMouse.containsMouse ? Nexa.Theme.hover : "transparent")
                                    border.width: dismissMouse.containsMouse ? 1 : 0
                                    border.color: Nexa.Theme.border

                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰅖"
                                        color: dismissMouse.containsMouse ? Nexa.Theme.error : Nexa.Theme.mutedText
                                        font.family: Nexa.Theme.iconFontFamily
                                        font.pixelSize: 10
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

                            // Summary / Title
                            Text {
                                Layout.fillWidth: true
                                visible: text.length > 0
                                text: cardRoot.modelData.summary || ""
                                color: Nexa.Theme.text
                                wrapMode: Text.Wrap
                                maximumLineCount: 1
                                elide: Text.ElideRight
                                font.family: Nexa.Theme.fontFamily
                                font.pixelSize: 13
                                font.weight: Nexa.Theme.fontWeightDemiBold
                            }

                            // Body Text
                            Text {
                                Layout.fillWidth: true
                                visible: text.length > 0
                                text: cardRoot.modelData.body || ""
                                color: Nexa.Theme.mutedText
                                wrapMode: Text.Wrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                                font.family: Nexa.Theme.fontFamily
                                font.pixelSize: 11
                                lineHeight: 1.15
                            }

                            // Action Buttons (if any)
                            RowLayout {
                                Layout.fillWidth: true
                                Layout.topMargin: 2
                                visible: cardRoot.modelData.actions && cardRoot.modelData.actions.length > 0
                                spacing: 6

                                Repeater {
                                    model: cardRoot.modelData.actions || []

                                    delegate: Rectangle {
                                        id: actionPill
                                        required property var modelData

                                        implicitHeight: 22
                                        implicitWidth: actionLabel.implicitWidth + 14
                                        radius: 6
                                        color: actionMouse.pressed
                                               ? Nexa.Theme.hoverStrong
                                               : (actionMouse.containsMouse ? Nexa.Theme.hover : Nexa.Theme.surfaceContainerLow)
                                        border.width: Nexa.Theme.borderThin
                                        border.color: Nexa.Theme.border

                                        Text {
                                            id: actionLabel
                                            anchors.centerIn: parent
                                            text: actionPill.modelData.label || ""
                                            color: Nexa.Theme.text
                                            font.family: Nexa.Theme.fontFamily
                                            font.pixelSize: 11
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
                                                        + " \"" + actionPill.modelData.key + "\""
                                                ])
                                            }
                                        }
                                    }
                                }

                                Item { Layout.fillWidth: true }
                            }
                        }

                        // Interactive Card MouseArea
                        MouseArea {
                            id: cardMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            z: -1
                        }
                    }
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
        onTriggered: root.loadState()
    }
}
