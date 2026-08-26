import QtQuick
import QtQuick.Layouts

import Quickshell
import Quickshell.Io

import "../../theme" as Nexa


Item {
    id: root


    // ============================================================
    // NEXA NOTIFICATIONS
    //
    // Rust owns:
    // - D-Bus notification server
    // - history/state
    // - dismiss / clear
    // - notification IDs
    //
    // QML owns presentation only.
    // ============================================================


    property var notificationData: ({
        "notifications": [],
        "unreadCount": 0
    })


    // ============================================================
    // STATE FILE
    // ============================================================

    FileView {
        id: notificationState

        path: Quickshell.env("HOME")
            + "/.cache/nexa/notifications.json"

        watchChanges: true


        onFileChanged: {
            reload()
        }


        onLoaded: {
            root.loadState()
        }
    }


    function loadState() {
        try {
            const text = notificationState.text()

            if (!text || text.length === 0)
                return

            root.notificationData = JSON.parse(text)

        } catch (error) {
            console.warn(
                "NEXA notifications:",
                error
            )
        }
    }


    // ============================================================
    // PRESENTATION HELPERS
    // ============================================================

    function formatTimestamp(timestamp) {
        if (!timestamp)
            return ""

        const now = Math.floor(Date.now() / 1000)
        const diff = Math.max(0, now - timestamp)

        if (diff < 60)
            return "now"

        if (diff < 3600)
            return Math.floor(diff / 60) + "m"

        if (diff < 86400)
            return Math.floor(diff / 3600) + "h"

        if (diff < 172800)
            return "Yesterday"

        const date = new Date(timestamp * 1000)

        return Qt.formatDate(
            date,
            "dd MMM"
        )
    }


    function iconSource(icon) {
        if (!icon || icon.length === 0)
            return ""

        // Absolute/file URI support.
        if (icon.startsWith("/")
                || icon.startsWith("file://"))
            return icon

        // Theme icon names are not guaranteed to resolve through
        // Image directly, so leave fallback handling to the card.
        return ""
    }


    // ============================================================
    // MAIN LAYOUT
    // ============================================================

    ColumnLayout {
        anchors {
            fill: parent
            margins: Nexa.Theme.spacingLg
        }

        spacing:
            Nexa.Theme.spacingMd


        // ========================================================
        // HEADER
        // ========================================================

        Rectangle {
            Layout.fillWidth: true

            Layout.preferredHeight:
                headerContent.implicitHeight
                + Nexa.Theme.spacingLg * 2

            radius:
                Nexa.Theme.radiusLg

            color:
                Nexa.Theme.panelBackgroundElevated

            border {
                width:
                    Nexa.Theme.borderThin

                color:
                    Nexa.Theme.divider
            }


            RowLayout {
                id: headerContent

                anchors {
                    left: parent.left
                    right: parent.right
                    verticalCenter: parent.verticalCenter

                    leftMargin:
                        Nexa.Theme.spacingLg

                    rightMargin:
                        Nexa.Theme.spacingLg
                }

                spacing:
                    Nexa.Theme.spacingMd


                ColumnLayout {
                    Layout.fillWidth: true

                    spacing:
                        Nexa.Theme.spacing2Xs


                    Text {
                        text:
                            "Notifications"

                        color:
                            Nexa.Theme.text

                        font {
                            family:
                                Nexa.Theme.fontFamily

                            pixelSize:
                                Nexa.Theme.fontSizeXl

                            weight:
                                Nexa.Theme.fontWeightDemiBold
                        }
                    }


                    Text {
                      text: {
                          const total =
                              root.notificationData.notifications
                              ? root.notificationData.notifications.length
                              : 0

                          const unread =
                              root.notificationData.unreadCount || 0

                          if (total === 0)
                              return "You're all caught up"

                          if (unread === 0)
                              return "No unread notifications"

                          return unread === 1
                              ? "1 unread notification"
                              : unread + " unread notifications"
                      }

                      color:
                          Nexa.Theme.mutedText

                      font {
                          family:
                              Nexa.Theme.fontFamily

                          pixelSize:
                              Nexa.Theme.fontSizeSm
                      }
                  }
                  
                
                }


                // ------------------------------------------------
                // CLEAR ALL
                // ------------------------------------------------

                Rectangle {
                    visible:
                        root.notificationData.notifications.length > 0

                    implicitWidth:
                        clearRow.implicitWidth
                        + Nexa.Theme.spacingLg

                    implicitHeight:
                        Nexa.Theme.controlHeightSm

                    radius:
                        Nexa.Theme.radiusPill

                    color: clearMouse.containsMouse
                        ? Qt.rgba(
                            Nexa.Theme.error.r,
                            Nexa.Theme.error.g,
                            Nexa.Theme.error.b,
                            0.16
                        )
                        : Qt.rgba(
                            Nexa.Theme.error.r,
                            Nexa.Theme.error.g,
                            Nexa.Theme.error.b,
                            0.10
                        )

                    border {
                        width:
                            Nexa.Theme.borderThin

                        color:
                            Qt.rgba(
                                Nexa.Theme.error.r,
                                Nexa.Theme.error.g,
                                Nexa.Theme.error.b,
                                0.45
                            )
                    }


                    scale: clearMouse.pressed
                        ? Nexa.Theme.pressScale
                        : Nexa.Theme.normalScale


                    Behavior on color {
                        ColorAnimation {
                            duration:
                                Nexa.Theme.animationFast
                        }
                    }


                    Behavior on scale {
                        NumberAnimation {
                            duration:
                                Nexa.Theme.animationFast

                            easing.type:
                                Nexa.Theme.easingStandard
                        }
                    }


                    Row {
                        id: clearRow

                        anchors.centerIn:
                            parent

                        spacing:
                            Nexa.Theme.spacingXs


                        Text {
                            text:
                                "󰆴"

                            color:
                                Nexa.Theme.error

                            font {
                                family:
                                    Nexa.Theme.iconFontFamily

                                pixelSize:
                                    Nexa.Theme.iconXs
                            }
                        }


                        Text {
                            text:
                                "Clear"

                            color:
                                Nexa.Theme.error

                            font {
                                family:
                                    Nexa.Theme.fontFamily

                                pixelSize:
                                    Nexa.Theme.fontSizeSm

                                weight:
                                    Nexa.Theme.fontWeightMedium
                            }
                        }
                    }


                    MouseArea {
                        id: clearMouse

                        anchors.fill:
                            parent

                        hoverEnabled:
                            true

                        cursorShape:
                            Qt.PointingHandCursor


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
        // EMPTY STATE
        // ========================================================

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            visible:
                root.notificationData.notifications.length === 0


            Column {
                anchors.centerIn:
                    parent

                spacing:
                    Nexa.Theme.spacingSm


                Text {
                    anchors.horizontalCenter:
                        parent.horizontalCenter

                    text:
                        "󰂛"

                    color:
                        Nexa.Theme.mutedText

                    font {
                        family:
                            Nexa.Theme.iconFontFamily

                        pixelSize:
                            Nexa.Theme.icon2Xl
                    }
                }


                Text {
                    anchors.horizontalCenter:
                        parent.horizontalCenter

                    text:
                        "No notifications"

                    color:
                        Nexa.Theme.text

                    font {
                        family:
                            Nexa.Theme.fontFamily

                        pixelSize:
                            Nexa.Theme.fontSizeMd

                        weight:
                            Nexa.Theme.fontWeightMedium
                    }
                }


                Text {
                    anchors.horizontalCenter:
                        parent.horizontalCenter

                    text:
                        "New notifications will appear here"

                    color:
                        Nexa.Theme.mutedText

                    font {
                        family:
                            Nexa.Theme.fontFamily

                        pixelSize:
                            Nexa.Theme.fontSizeSm
                    }
                }
            }
        }


        // ========================================================
        // NOTIFICATION LIST
        // ========================================================

        ListView {
            id: notificationList

            Layout.fillWidth: true
            Layout.fillHeight: true

            visible:
                root.notificationData.notifications.length > 0

            clip:
                true

            spacing:
                Nexa.Theme.spacingSm

            model:
                root.notificationData.notifications

            boundsBehavior:
                Flickable.StopAtBounds

            flickDeceleration:
                Nexa.Theme.flickDeceleration

            maximumFlickVelocity:
                Nexa.Theme.flickVelocityMax


            delegate: Rectangle {
                id: card

                required property var modelData


                width:
                    notificationList.width

                implicitHeight:
                    cardContent.implicitHeight
                    + Nexa.Theme.spacingLg * 2

                radius:
                    Nexa.Theme.radiusLg


                color: cardMouse.containsMouse
                    ? Nexa.Theme.cardBackgroundElevated
                    : Nexa.Theme.cardBackground


                border {
                    width:
                        Nexa.Theme.borderThin

                    color: card.modelData.read
                        ? Nexa.Theme.divider
                        : Qt.rgba(
                            Nexa.Theme.primary.r,
                            Nexa.Theme.primary.g,
                            Nexa.Theme.primary.b,
                            0.45
                        )
                }


                Behavior on color {
                    ColorAnimation {
                        duration:
                            Nexa.Theme.animationFast
                    }
                }


                // ------------------------------------------------
                // UNREAD ACCENT
                // ------------------------------------------------

                Rectangle {
                    visible:
                        !card.modelData.read

                    width:
                        Nexa.Theme.borderStrongWidth

                    radius:
                        Nexa.Theme.radiusPill

                    color:
                        Nexa.Theme.primary

                    anchors {
                        top: parent.top
                        bottom: parent.bottom
                        left: parent.left

                        topMargin:
                            Nexa.Theme.spacingSm

                        bottomMargin:
                            Nexa.Theme.spacingSm
                    }
                }


                // =================================================
                // CARD CONTENT
                // =================================================

                ColumnLayout {
                    id: cardContent

                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top

                        leftMargin:
                            Nexa.Theme.spacingLg

                        rightMargin:
                            Nexa.Theme.spacingLg

                        topMargin:
                            Nexa.Theme.spacingLg
                    }

                    spacing:
                        Nexa.Theme.spacingSm


                    // =============================================
                    // APP ROW
                    // =============================================

                    RowLayout {
                        Layout.fillWidth: true

                        spacing:
                            Nexa.Theme.spacingSm


                        // -----------------------------------------
                        // APP ICON
                        // -----------------------------------------

                        Rectangle {
                            implicitWidth:
                                Nexa.Theme.controlHeightMd

                            implicitHeight:
                                Nexa.Theme.controlHeightMd

                            radius:
                                Nexa.Theme.radiusMd

                            color:
                                Nexa.Theme.surfaceContainerHighest


                            Image {
                                id: appImage

                                anchors {
                                    fill: parent
                                    margins:
                                        Nexa.Theme.spacingXs
                                }

                                visible:
                                    source.toString().length > 0

                                source:
                                    root.iconSource(
                                        card.modelData.appIcon || ""
                                    )

                                fillMode:
                                    Image.PreserveAspectFit

                                asynchronous:
                                    true

                                smooth:
                                    true
                            }


                            // -------------------------------------
                            // FALLBACK ICON
                            // -------------------------------------

                            Text {
                                anchors.centerIn:
                                    parent

                                visible:
                                    !appImage.visible

                                text:
                                    "󰣆"

                                color:
                                    Nexa.Theme.primary

                                font {
                                    family:
                                        Nexa.Theme.iconFontFamily

                                    pixelSize:
                                        Nexa.Theme.iconSm
                                }
                            }
                        }


                        // -----------------------------------------
                        // APP NAME
                        // -----------------------------------------

                        Text {
                            Layout.fillWidth: true

                            text:
                                card.modelData.appName
                                || "Application"

                            elide:
                                Text.ElideRight

                            color:
                                Nexa.Theme.mutedText

                            font {
                                family:
                                    Nexa.Theme.fontFamily

                                pixelSize:
                                    Nexa.Theme.fontSizeXs

                                weight:
                                    Nexa.Theme.fontWeightMedium
                            }
                        }


                        // -----------------------------------------
                        // TIMESTAMP
                        // -----------------------------------------

                        Text {
                            text:
                                root.formatTimestamp(
                                    card.modelData.timestamp
                                )

                            color:
                                Nexa.Theme.mutedText

                            font {
                                family:
                                    Nexa.Theme.fontFamily

                                pixelSize:
                                    Nexa.Theme.fontSizeXs
                            }
                        }


                        // -----------------------------------------
                        // DISMISS
                        // -----------------------------------------

                        Rectangle {
                            implicitWidth:
                                Nexa.Theme.controlHeightXs

                            implicitHeight:
                                Nexa.Theme.controlHeightXs

                            radius:
                                Nexa.Theme.radiusPill

                            color: closeMouse.containsMouse
                                ? Qt.rgba(
                                    Nexa.Theme.error.r,
                                    Nexa.Theme.error.g,
                                    Nexa.Theme.error.b,
                                    0.12
                                )
                                : "transparent"


                            scale: closeMouse.pressed
                                ? Nexa.Theme.pressScale
                                : Nexa.Theme.normalScale


                            Behavior on color {
                                ColorAnimation {
                                    duration:
                                        Nexa.Theme.animationFast
                                }
                            }


                            Behavior on scale {
                                NumberAnimation {
                                    duration:
                                        Nexa.Theme.animationFast

                                    easing.type:
                                        Nexa.Theme.easingStandard
                                }
                            }


                            Text {
                                anchors.centerIn:
                                    parent

                                text:
                                    "󰅖"

                                color: closeMouse.containsMouse
                                    ? Nexa.Theme.error
                                    : Nexa.Theme.mutedText

                                font {
                                    family:
                                        Nexa.Theme.iconFontFamily

                                    pixelSize:
                                        Nexa.Theme.iconXs
                                }


                                Behavior on color {
                                    ColorAnimation {
                                        duration:
                                            Nexa.Theme.animationFast
                                    }
                                }
                            }


                            MouseArea {
                                id: closeMouse

                                anchors.fill:
                                    parent

                                hoverEnabled:
                                    true

                                cursorShape:
                                    Qt.PointingHandCursor


                                onClicked: {
                                    Quickshell.execDetached([
                                        "sh",
                                        "-c",
                                        "\"$HOME/.config/nexa/rust/target/release/nexad\" notifications dismiss "
                                            + card.modelData.id
                                    ])
                                }
                            }
                        }
                    }


                    // =============================================
                    // TITLE
                    // =============================================

                    Text {
                        Layout.fillWidth: true

                        text:
                            card.modelData.summary || ""

                        visible:
                            text.length > 0

                        wrapMode:
                            Text.Wrap

                        color:
                            Nexa.Theme.text

                        font {
                            family:
                                Nexa.Theme.fontFamily

                            pixelSize:
                                Nexa.Theme.fontSizeMd

                            weight:
                                Nexa.Theme.fontWeightDemiBold
                        }
                    }


                    // =============================================
                    // BODY
                    // =============================================

                    Text {
                        Layout.fillWidth: true

                        text:
                            card.modelData.body || ""

                        visible:
                            text.length > 0

                        wrapMode:
                            Text.Wrap

                        color:
                            Nexa.Theme.mutedText

                        font {
                            family:
                                Nexa.Theme.fontFamily

                            pixelSize:
                                Nexa.Theme.fontSizeSm
                        }
                    }


                    // =============================================
                    // ACTIONS
                    //
                    // Backend already stores them.
                    // Rendering only for now.
                    // Invocation wiring can come next.
                    // =============================================

                    RowLayout {
                        Layout.fillWidth: true

                        visible:
                            card.modelData.actions
                            && card.modelData.actions.length > 0

                        spacing:
                            Nexa.Theme.spacingSm


                        Repeater {
                            model:
                                card.modelData.actions || []


                            delegate: Rectangle {
                                id: actionButton

                                required property var modelData

                                implicitWidth:
                                    actionText.implicitWidth
                                    + Nexa.Theme.spacingLg

                                implicitHeight:
                                    Nexa.Theme.controlHeightSm

                                radius:
                                    Nexa.Theme.radiusPill

                                color: actionMouse.containsMouse
                                    ? Nexa.Theme.buttonBackgroundHover
                                    : Nexa.Theme.buttonBackground

                                border {
                                    width:
                                        Nexa.Theme.borderThin

                                    color:
                                        Nexa.Theme.divider
                                }

                                scale: actionMouse.pressed
                                    ? Nexa.Theme.pressScale
                                    : Nexa.Theme.normalScale


                                Behavior on color {
                                    ColorAnimation {
                                        duration:
                                            Nexa.Theme.animationFast
                                    }
                                }


                                Behavior on scale {
                                    NumberAnimation {
                                        duration:
                                            Nexa.Theme.animationFast

                                        easing.type:
                                            Nexa.Theme.easingStandard
                                    }
                                }


                                Text {
                                    id: actionText

                                    anchors.centerIn:
                                        parent

                                    text:
                                        actionButton.modelData.label || ""

                                    color:
                                        Nexa.Theme.text

                                    font {
                                        family:
                                            Nexa.Theme.fontFamily

                                        pixelSize:
                                            Nexa.Theme.fontSizeXs

                                        weight:
                                            Nexa.Theme.fontWeightMedium
                                    }
                                }


                                MouseArea {
                                    id: actionMouse

                                    anchors.fill:
                                        parent

                                    hoverEnabled:
                                        true

                                    cursorShape:
                                        Qt.PointingHandCursor

                                    onClicked: {
                                        Quickshell.execDetached([
                                            "sh",
                                            "-c",
                                            "\"$HOME/.config/nexa/rust/target/release/nexad\" notifications action "
                                                + card.modelData.id
                                                + " "
                                                + "\"" + actionButton.modelData.key + "\""
                                        ])
                                    }
                                }
                            } 
                        }


                        Item {
                            Layout.fillWidth:
                                true
                        }
                    }
                }


                // Hover tracking only.
                MouseArea {
                    id: cardMouse

                    anchors.fill:
                        parent

                    hoverEnabled:
                        true

                    acceptedButtons:
                        Qt.NoButton
                }
            }
        }
    }


    // ============================================================
    // TIMESTAMP REFRESH
    //
    // Keeps "2m", "3m", "1h" labels fresh without touching Rust.
    // ============================================================

    Timer {
        interval:
            60000

        repeat:
            true

        running:
            true

        onTriggered: {
            notificationList.forceLayout()
        }
    }
}
