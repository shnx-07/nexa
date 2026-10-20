// pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../theme" as Nexa
import "../../theme/components" as NexaUI
import "../../services" as Services
import "./profile" as ProfileModule
import "./display" as DisplayModule

Item {
    id: root

    anchors.fill: parent
    visible: false
    focus: true
    Keys.forwardTo: [keys]
    Keys.onEscapePressed: root.close()

    property string tab: "lock"
    readonly property var tabs: ["profile", "display", "bars", "lock", "system"]

    function rad(n) {
        if (Nexa.Theme.windowRounding === 0) return 0
        return Math.max(0, Math.round(n * (Nexa.Theme.windowRounding / 10.0)))
    }

    readonly property bool shuffle: Services.LockScreen.shuffle

    function lockNow() {
        root.close()
        Quickshell.execDetached(["qs", "-p", Quickshell.env("HOME") + "/.config/nexa/quickshell", "ipc", "call", "lockScreen", "lock"])
    }

    function open() {
        visible = true
        root.forceActiveFocus()
        openAnim.restart()
    }

    function close() {
        closeAnim.restart()
    }

    function toggle() {
        if (visible) close()
        else open()
    }

    function openTab(which) {
        if (which === "system" || which === "profile" || which === "display" || which === "bars" || which === "lock") {
            tab = which
        } else {
            tab = "lock"
        }
        open()
    }



    Rectangle {
        id: scrim
        anchors.fill: parent
        color: Nexa.Theme.scrim
        opacity: 0
        enabled: opacity > 0.01

        MouseArea {
            anchors.fill: parent
            enabled: parent.enabled
            onClicked: root.close()
        }
    }

    ParallelAnimation {
        id: openAnim
        NumberAnimation { target: scrim; property: "opacity"; to: 0.65; duration: 220; easing.type: Easing.OutCubic }
        NumberAnimation { target: panel; property: "opacity"; to: 1; duration: 240; easing.type: Easing.OutCubic }
        NumberAnimation { target: panel; property: "scale"; to: 1; duration: 320; easing.type: Easing.OutBack }
    }

    ParallelAnimation {
        id: closeAnim
        NumberAnimation { target: scrim; property: "opacity"; to: 0; duration: 180; easing.type: Easing.InCubic }
        NumberAnimation { target: panel; property: "opacity"; to: 0; duration: 200; easing.type: Easing.InCubic }
        NumberAnimation { target: panel; property: "scale"; to: 0.94; duration: 200; easing.type: Easing.InCubic }
        onFinished: root.visible = false
    }

    Rectangle {
        id: panel
        anchors.centerIn: parent
        width: Math.min(1240, (root.width > 0 ? root.width : 1920) * 0.88)
        height: Math.min(900, (root.height > 0 ? root.height : 1080) * 0.9)
        radius: Nexa.Theme.windowRounding === 0 ? 0 : root.rad(Nexa.Theme.radiusLg + 6)
        color: Nexa.Theme.panelBackground
        border.width: Nexa.Theme.borderThin
        border.color: Nexa.Theme.border
        clip: true
        opacity: 0
        scale: 0.94

        Item {
            id: keys
            focus: true
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    root.close()
                    event.accepted = true
                } else if (event.key === Qt.Key_Tab) {
                    const idx = root.tabs.indexOf(root.tab)
                    root.tab = root.tabs[(idx + 1) % root.tabs.length]
                    event.accepted = true
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(Nexa.Theme.primary.r, Nexa.Theme.primary.g, Nexa.Theme.primary.b, 0.08) }
                GradientStop { position: 0.35; color: "transparent" }
            }
        }

        Row {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 24

            // Left Sidebar Navigation
            Item {
                width: 230
                height: parent.height

                Column {
                    anchors.fill: parent
                    spacing: 8

                    Row {
                        spacing: 12
                        height: 44
                        anchors.left: parent.left
                        anchors.leftMargin: 6

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 36
                            height: 36
                            radius: root.rad(10)
                            color: Nexa.Theme.primaryContainer
                            Text {
                                anchors.centerIn: parent
                                text: "󰒓"
                                font { family: Nexa.Theme.iconFontFamily; pixelSize: 18 }
                                color: Nexa.Theme.onPrimaryContainer
                            }
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 1
                            Text {
                                text: "NEXA Control"
                                font { family: Nexa.Theme.fontFamily; pixelSize: 15; weight: Font.Bold }
                                color: Nexa.Theme.text
                            }
                            Text {
                                text: "Desktop Settings"
                                font { family: Nexa.Theme.fontFamily; pixelSize: 11 }
                                color: Nexa.Theme.mutedText
                            }
                        }
                    }

                    Item { width: 1; height: 10 }

                    Text {
                        text: "SYSTEM PREFERENCES"
                        font { family: Nexa.Theme.fontFamily; pixelSize: 11; weight: Font.DemiBold; letterSpacing: 1.0 }
                        color: Nexa.Theme.mutedText
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                    }

                    Repeater {
                        model: [
                            { id: "profile", icon: "", label: "Profile" },
                            { id: "display", icon: "󰍹", label: "Display" },
                            { id: "bars", icon: "󰈺", label: "Bars" }
                        ]

                        NexaUI.NexaCard {
                            required property var modelData
                            anchors.left: parent.left
                            anchors.leftMargin: 6
                            width: 204
                            implicitHeight: 42
                            padding: 8
                            interactive: true
                            selected: root.tab === modelData.id
                            radius: root.rad(10)
                            onClicked: root.tab = modelData.id

                            Row {
                                anchors.left: parent.left
                                anchors.leftMargin: 4
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 12

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.icon
                                    font { family: Nexa.Theme.iconFontFamily; pixelSize: 18 }
                                    color: root.tab === modelData.id ? Nexa.Theme.primary : Nexa.Theme.text
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.label
                                    font { family: Nexa.Theme.fontFamily; pixelSize: 14; weight: root.tab === modelData.id ? Font.Bold : Font.Medium }
                                    color: root.tab === modelData.id ? Nexa.Theme.primary : Nexa.Theme.text
                                }
                            }
                        }
                    }

                    Item { width: 1; height: 10 }

                    Text {
                        text: "CUSTOMIZATION"
                        font { family: Nexa.Theme.fontFamily; pixelSize: 11; weight: Font.DemiBold; letterSpacing: 1.0 }
                        color: Nexa.Theme.mutedText
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                    }

                    Repeater {
                        model: [
                            { id: "lock", icon: "󰌾", label: "Lock Screen" },
                            { id: "system", icon: "󰔎", label: "Theme & Styles" }
                        ]

                        NexaUI.NexaCard {
                            required property var modelData
                            anchors.left: parent.left
                            anchors.leftMargin: 6
                            width: 204
                            implicitHeight: 42
                            padding: 8
                            interactive: true
                            selected: root.tab === modelData.id
                            radius: root.rad(10)
                            onClicked: root.tab = modelData.id

                            Row {
                                anchors.left: parent.left
                                anchors.leftMargin: 4
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 12

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.icon
                                    font { family: Nexa.Theme.iconFontFamily; pixelSize: 18 }
                                    color: root.tab === modelData.id ? Nexa.Theme.primary : Nexa.Theme.text
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.label
                                    font { family: Nexa.Theme.fontFamily; pixelSize: 14; weight: root.tab === modelData.id ? Font.Bold : Font.Medium }
                                    color: root.tab === modelData.id ? Nexa.Theme.primary : Nexa.Theme.text
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                width: 1
                height: parent.height
                color: Nexa.Theme.divider
            }

            // Right Main Workspace
            Column {
                width: parent.width - 230 - 24 - 1
                height: parent.height
                spacing: 16

                RowLayout {
                    width: parent.width
                    height: 48

                    ColumnLayout {
                        spacing: 2
                        Text {
                            text: {
                                if (root.tab === "profile") return "Profile"
                                if (root.tab === "display") return "Display Settings"
                                if (root.tab === "bars") return "Bars & Panels"
                                if (root.tab === "system") return "System Themes"
                                return "Lock Screen Themes"
                            }
                            font { family: Nexa.Theme.fontFamily; pixelSize: 20; weight: Font.Bold }
                            color: Nexa.Theme.text
                        }
                        Text {
                            text: {
                                if (root.tab === "profile") return "User account & system identity"
                                if (root.tab === "display") return "Display layout, resolution & scaling"
                                if (root.tab === "bars") return "Status bar layout, components & appearance"
                                if (root.tab === "system") return "Desktop customization and appearance"
                                return (root.shuffle ? "Shuffle: each lock picks one of the selected themes" : "Pick the design used when you lock")
                            }
                            font { family: Nexa.Theme.fontFamily; pixelSize: 12 }
                            color: Nexa.Theme.mutedText
                        }
                    }

                    Item { Layout.fillWidth: true }

                    RowLayout {
                        spacing: 10

                        // Shuffle Toggle (Lock Screen only)
                        RowLayout {
                            visible: root.tab === "lock"
                            spacing: 8
                            Text {
                                text: "Shuffle"
                                font { family: Nexa.Theme.fontFamily; pixelSize: 13; weight: Font.Medium }
                                color: Nexa.Theme.text
                            }
                            NexaUI.NexaToggle {
                                checked: root.shuffle
                                onToggled: isChecked => Services.LockScreen.setShuffle(isChecked)
                            }
                        }

                        // Lock Now Button (Lock Screen only)
                        NexaUI.NexaButton {
                            visible: root.tab === "lock"
                            text: "Lock now"
                            icon: "󰌾"
                            onClicked: root.lockNow()
                        }

                        // Close Button
                        NexaUI.NexaIconButton {
                            icon: "󰅖"
                            onClicked: root.close()
                        }
                    }
                }

                Item {
                    width: parent.width
                    height: parent.height - 48 - parent.spacing

                    Loader {
                        id: contentLoader
                        anchors.fill: parent
                        sourceComponent: {
                            if (root.tab === "profile") return profileTabComponent
                            if (root.tab === "display") return displayTabComponent
                            if (root.tab === "bars") return barsTabComponent
                            if (root.tab === "system") return systemTabComponent
                            return lockTabComponent
                        }
                    }
                }
            }
        }
    }

    Component {
        id: profileTabComponent
        ProfileModule.ProfileSettings {
            onRequestClose: root.close()
            onOpenWallpaper: {
                root.close()
                Quickshell.execDetached(["qs", "-p", Quickshell.env("HOME") + "/.config/nexa/quickshell", "ipc", "call", "wallpaper", "open"])
            }
            onOpenLockTab: { root.tab = "lock" }
        }
    }

    Component {
        id: displayTabComponent
        DisplayModule.DisplaySettings { onRequestClose: root.close() }
    }

    Component {
        id: barsTabComponent
        BarsSettings { onRequestClose: root.close() }
    }

    Component {
        id: lockTabComponent
        LockScreenSettings { onRequestClose: root.close() }
    }

    Component {
        id: systemTabComponent
        SystemThemeSettings { onRequestClose: root.close() }
    }
}
