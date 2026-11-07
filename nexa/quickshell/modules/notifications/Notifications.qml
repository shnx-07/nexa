import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import Quickshell
import Quickshell.Io

import "../../NewNexaUI" as NexaUI

Item {
    id: root

    // ============================================================
    // NEXA NOTIFICATIONS (Apple-Inspired Modern UI)
    //
    // Dynamic tokens sourced from NewNexaUI (NexaColors, NexaTokens,
    // NexaMotion, NexaOptics, NexaTypography).
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
        anchors.margins: NexaUI.NexaTokens.spacingMd
        spacing: NexaUI.NexaTokens.spacingSm

        // ========================================================
        // SUBHEADER (Count, Unread badge, Clear All)
        // ========================================================
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 28
            spacing: NexaUI.NexaTokens.spacingSm

            // Count / Status
            RowLayout {
                spacing: NexaUI.NexaTokens.spacingSm

                Text {
                    text: root.totalCount > 0
                        ? (root.totalCount + (root.totalCount === 1 ? " Notification" : " Notifications"))
                        : ""
                    color: NexaUI.NexaColors.text
                    font.family: NexaUI.NexaTypography.familyDisplay
                    font.pixelSize: NexaUI.NexaTypography.sizeSm
                    font.weight: NexaUI.NexaTypography.weightSemiBold
                }

                // Unread Badge Pill
                Rectangle {
                    visible: root.unreadCount > 0
                    implicitHeight: 20
                    implicitWidth: unreadBadgeText.implicitWidth + NexaUI.NexaTokens.spacingMd
                    radius: NexaUI.NexaTokens.radiusPill
                    color: NexaUI.NexaColors.alpha(NexaUI.NexaColors.primary, 0.15)
                    border.width: NexaUI.NexaTokens.borderThin
                    border.color: NexaUI.NexaColors.alpha(NexaUI.NexaColors.primary, 0.35)

                    Text {
                        id: unreadBadgeText
                        anchors.centerIn: parent
                        text: root.unreadCount + " new"
                        color: NexaUI.NexaColors.primary
                        font.family: NexaUI.NexaTypography.familyBody
                        font.pixelSize: NexaUI.NexaTypography.sizeXs
                        font.weight: NexaUI.NexaTypography.weightBold
                    }
                }
            }

            Item { Layout.fillWidth: true }

            // Clear All Button (Sleek Glass Capsule)
            Rectangle {
                id: clearBtn
                visible: root.totalCount > 0
                implicitHeight: 26
                implicitWidth: clearRow.implicitWidth + NexaUI.NexaTokens.spacingLg
                radius: NexaUI.NexaTokens.radiusPill
                color: clearMouse.pressed
                       ? NexaUI.NexaColors.surfaceContainerHighest
                       : (clearMouse.containsMouse ? NexaUI.NexaColors.surfaceContainerHigh : NexaUI.NexaColors.surfaceContainer)
                border.width: NexaUI.NexaTokens.borderThin
                border.color: clearMouse.containsMouse ? NexaUI.NexaColors.borderStrong : NexaUI.NexaColors.border

                Behavior on color { ColorAnimation { duration: NexaUI.NexaMotion.durationFast } }
                Behavior on border.color { ColorAnimation { duration: NexaUI.NexaMotion.durationFast } }

                Row {
                    id: clearRow
                    anchors.centerIn: parent
                    spacing: NexaUI.NexaTokens.spacingXs

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "󰆴"
                        color: clearMouse.containsMouse ? NexaUI.NexaColors.error : NexaUI.NexaColors.mutedText
                        font.family: NexaUI.NexaTypography.familyIcon
                        font.pixelSize: NexaUI.NexaTypography.sizeSm
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Clear All"
                        color: clearMouse.containsMouse ? NexaUI.NexaColors.text : NexaUI.NexaColors.mutedText
                        font.family: NexaUI.NexaTypography.familyBody
                        font.pixelSize: NexaUI.NexaTypography.sizeXs
                        font.weight: NexaUI.NexaTypography.weightMedium
                    }
                }

                MouseArea {
                    id: clearMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Quickshell.execDetached([
                            Quickshell.env("HOME") + "/.config/nexa/rust/target/release/nexad",
                            "notifications",
                            "clear"
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
                spacing: NexaUI.NexaTokens.spacingMd

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: 56
                    implicitHeight: 56
                    radius: 28
                    color: NexaUI.NexaColors.alpha(NexaUI.NexaColors.primary, 0.08)
                    border.width: NexaUI.NexaTokens.borderThin
                    border.color: NexaUI.NexaColors.alpha(NexaUI.NexaColors.primary, 0.22)

                    Text {
                        anchors.centerIn: parent
                        text: "󰂚"
                        color: NexaUI.NexaColors.primary
                        font.family: NexaUI.NexaTypography.familyIcon
                        font.pixelSize: 26
                    }
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "No Notifications"
                    color: NexaUI.NexaColors.text
                    font.family: NexaUI.NexaTypography.familyDisplay
                    font.pixelSize: NexaUI.NexaTypography.sizeLg
                    font.weight: NexaUI.NexaTypography.weightSemiBold
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "You're completely caught up"
                    color: NexaUI.NexaColors.mutedText
                    font.family: NexaUI.NexaTypography.familyBody
                    font.pixelSize: NexaUI.NexaTypography.sizeSm
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
            contentHeight: cardsGrid.implicitHeight + NexaUI.NexaTokens.spacingSm
            boundsBehavior: Flickable.StopAtBounds

            ScrollBar.vertical: ScrollBar {
                id: notifScrollBar
                policy: ScrollBar.AsNeeded
                width: 4
                anchors.right: parent.right
                anchors.rightMargin: 1
                visible: size < 1.0

                contentItem: Rectangle {
                    implicitWidth: 3
                    radius: NexaUI.NexaTokens.radiusPill
                    color: notifScrollBar.hovered ? NexaUI.NexaColors.primary : NexaUI.NexaColors.mutedText
                    opacity: (notifScrollBar.active || notifScrollBar.hovered) ? 0.6 : 0.0

                    Behavior on opacity {
                        NumberAnimation { duration: NexaUI.NexaMotion.durationNormal }
                    }
                    Behavior on color {
                        ColorAnimation { duration: NexaUI.NexaMotion.durationFast }
                    }
                }

                background: null
            }

            Grid {
                id: cardsGrid
                width: notificationFlickable.width - (notificationFlickable.contentHeight > notificationFlickable.height ? (NexaUI.NexaTokens.spacingSm + 4) : 0)
                columns: 2
                columnSpacing: NexaUI.NexaTokens.spacingSm + 2
                rowSpacing: NexaUI.NexaTokens.spacingSm + 2

                Behavior on width {
                    NumberAnimation { duration: NexaUI.NexaMotion.durationFast }
                }

                Repeater {
                    model: root.notificationListModel

                    delegate: Rectangle {
                        id: cardRoot
                        required property var modelData

                        width: (cardsGrid.width - cardsGrid.columnSpacing) / 2
                        implicitHeight: Math.max(76, cardCol.implicitHeight + NexaUI.NexaTokens.spacingLg)
                        radius: NexaUI.NexaTokens.radiusMd
                        color: cardMouse.containsMouse
                               ? NexaUI.NexaColors.surfaceContainerHigh
                               : NexaUI.NexaColors.surfaceContainer
                        border.width: NexaUI.NexaTokens.borderThin
                        border.color: !cardRoot.modelData.read
                                      ? NexaUI.NexaColors.alpha(NexaUI.NexaColors.primary, 0.45)
                                      : (cardMouse.containsMouse ? NexaUI.NexaColors.borderStrong : NexaUI.NexaColors.border)
                        scale: cardMouse.pressed ? 0.985 : (cardMouse.containsMouse ? 1.008 : 1.0)

                        Behavior on color { ColorAnimation { duration: NexaUI.NexaMotion.durationFast } }
                        Behavior on border.color { ColorAnimation { duration: NexaUI.NexaMotion.durationFast } }
                        Behavior on scale { NumberAnimation { duration: NexaUI.NexaMotion.durationFast; easing.type: Easing.OutQuad } }

                        // Specular Highlight Line
                        Rectangle {
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 1
                            radius: parent.radius
                            color: Qt.rgba(1, 1, 1, (cardMouse.containsMouse ? 0.18 : 0.08) * NexaUI.NexaOptics.specularIntensity)
                            visible: NexaUI.NexaOptics.specularHighlight
                        }

                        // Left Accent Pill for Unread
                        Rectangle {
                            visible: !cardRoot.modelData.read
                            width: 3
                            height: 24
                            radius: 1.5
                            color: NexaUI.NexaColors.primary
                            anchors {
                                left: parent.left
                                leftMargin: NexaUI.NexaTokens.spacingXs
                                verticalCenter: parent.verticalCenter
                            }
                        }

                        ColumnLayout {
                            id: cardCol
                            anchors {
                                left: parent.left
                                right: parent.right
                                top: parent.top
                                leftMargin: cardRoot.modelData.read ? NexaUI.NexaTokens.spacingMd : (NexaUI.NexaTokens.spacingMd + 2)
                                rightMargin: NexaUI.NexaTokens.spacingSm + 2
                                topMargin: NexaUI.NexaTokens.spacingSm + 2
                            }
                            spacing: NexaUI.NexaTokens.spacingXs

                            // Top Metadata Row: Icon + App Name + Time + Dismiss Button
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: NexaUI.NexaTokens.spacingSm

                                // App Icon Squircle
                                Rectangle {
                                    implicitWidth: 20
                                    implicitHeight: 20
                                    radius: NexaUI.NexaTokens.radiusXs
                                    color: NexaUI.NexaColors.surfaceContainerHighest
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
                                        color: NexaUI.NexaColors.primary
                                        font.family: NexaUI.NexaTypography.familyIcon
                                        font.pixelSize: NexaUI.NexaTypography.sizeXs
                                    }
                                }

                                // App Name
                                Text {
                                    text: (cardRoot.modelData.appName || "Notification").toUpperCase()
                                    color: NexaUI.NexaColors.mutedText
                                    font.family: NexaUI.NexaTypography.familyBody
                                    font.pixelSize: NexaUI.NexaTypography.size2Xs
                                    font.weight: NexaUI.NexaTypography.weightBold
                                    font.letterSpacing: 0.5
                                    elide: Text.ElideRight
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                // Dot
                                Text {
                                    text: "•"
                                    color: NexaUI.NexaColors.mutedText
                                    font.pixelSize: NexaUI.NexaTypography.size2Xs
                                    opacity: 0.5
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                // Timestamp
                                Text {
                                    text: root.formatTimestamp(cardRoot.modelData.timestamp)
                                    color: NexaUI.NexaColors.mutedText
                                    font.family: NexaUI.NexaTypography.familyBody
                                    font.pixelSize: NexaUI.NexaTypography.sizeXs
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                Item { Layout.fillWidth: true }

                                // Dismiss Button (Micro Glass Circle)
                                Rectangle {
                                    id: dismissBtn
                                    implicitWidth: 20
                                    implicitHeight: 20
                                    radius: NexaUI.NexaTokens.radiusPill
                                    color: dismissMouse.pressed
                                           ? NexaUI.NexaColors.alpha(NexaUI.NexaColors.error, 0.20)
                                           : (dismissMouse.containsMouse ? NexaUI.NexaColors.alpha(NexaUI.NexaColors.error, 0.12) : "transparent")
                                    border.width: dismissMouse.containsMouse ? NexaUI.NexaTokens.borderThin : 0
                                    border.color: NexaUI.NexaColors.alpha(NexaUI.NexaColors.error, 0.30)

                                    Behavior on color { ColorAnimation { duration: NexaUI.NexaMotion.durationInstant } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰅖"
                                        color: dismissMouse.containsMouse ? NexaUI.NexaColors.error : NexaUI.NexaColors.mutedText
                                        font.family: NexaUI.NexaTypography.familyIcon
                                        font.pixelSize: NexaUI.NexaTypography.sizeXs
                                    }

                                    MouseArea {
                                        id: dismissMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            Quickshell.execDetached([
                                                Quickshell.env("HOME") + "/.config/nexa/rust/target/release/nexad",
                                                "notifications",
                                                "dismiss",
                                                String(cardRoot.modelData.id)
                                            ])
                                        }
                                    }
                                }
                            }

                            // Summary / Title
                            Text {
                                Layout.fillWidth: true
                                textFormat: Text.PlainText
                                visible: text.length > 0
                                text: cardRoot.modelData.summary || ""
                                color: NexaUI.NexaColors.text
                                wrapMode: Text.Wrap
                                maximumLineCount: 1
                                elide: Text.ElideRight
                                font.family: NexaUI.NexaTypography.familyBody
                                font.pixelSize: NexaUI.NexaTypography.sizeSm
                                font.weight: NexaUI.NexaTypography.weightSemiBold
                            }

                            // Body Text
                            Text {
                                Layout.fillWidth: true
                                textFormat: Text.PlainText
                                visible: text.length > 0
                                text: cardRoot.modelData.body || ""
                                color: NexaUI.NexaColors.mutedText
                                wrapMode: Text.Wrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                                font.family: NexaUI.NexaTypography.familyBody
                                font.pixelSize: NexaUI.NexaTypography.sizeXs
                                lineHeight: 1.15
                            }

                            // Action Buttons (if any)
                            RowLayout {
                                Layout.fillWidth: true
                                Layout.topMargin: NexaUI.NexaTokens.spacing2Xs
                                visible: cardRoot.modelData.actions && cardRoot.modelData.actions.length > 0
                                spacing: NexaUI.NexaTokens.spacingSm

                                Repeater {
                                    model: cardRoot.modelData.actions || []

                                    delegate: Rectangle {
                                        id: actionPill
                                        required property var modelData

                                        implicitHeight: 22
                                        implicitWidth: actionLabel.implicitWidth + NexaUI.NexaTokens.spacingMd
                                        radius: NexaUI.NexaTokens.radiusPill
                                        color: actionMouse.pressed
                                               ? NexaUI.NexaColors.surfaceContainerHighest
                                               : (actionMouse.containsMouse ? NexaUI.NexaColors.surfaceContainerHigh : NexaUI.NexaColors.surfaceContainerLow)
                                        border.width: NexaUI.NexaTokens.borderThin
                                        border.color: actionMouse.containsMouse ? NexaUI.NexaColors.borderStrong : NexaUI.NexaColors.border

                                        Behavior on color { ColorAnimation { duration: NexaUI.NexaMotion.durationInstant } }

                                        Text {
                                            id: actionLabel
                                            anchors.centerIn: parent
                                            text: actionPill.modelData.label || ""
                                            color: NexaUI.NexaColors.text
                                            font.family: NexaUI.NexaTypography.familyBody
                                            font.pixelSize: NexaUI.NexaTypography.sizeXs
                                            font.weight: NexaUI.NexaTypography.weightMedium
                                        }

                                        MouseArea {
                                            id: actionMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                Quickshell.execDetached([
                                                    Quickshell.env("HOME") + "/.config/nexa/rust/target/release/nexad",
                                                    "notifications",
                                                    "action",
                                                    String(cardRoot.modelData.id),
                                                    String(actionPill.modelData.key || "")
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
        running: root.visible
        onTriggered: root.loadState()
    }

    onVisibleChanged: {
        if (root.visible)
            root.loadState()
    }
}
