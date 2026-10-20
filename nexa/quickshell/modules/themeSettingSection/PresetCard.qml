// pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../theme" as Nexa

Rectangle {
    id: root

    required property var presetData
    property string stagedPresetId: ""
    property string activePresetId: ""
    property string activeStyle: ""
    property string currentMode: "dark"

    signal cardSelected(string presetId, string mode)

    readonly property bool isStaged: root.stagedPresetId === root.presetData.id
    readonly property bool isSystemActive: root.activeStyle === "preset" && root.activePresetId === root.presetData.id

    readonly property string displayName: {
        const p = root.presetData;
        if (!p) return "";
        if (p.id === "extras/Dark" || (p.name === "extras" && p.id && p.id.indexOf("Dark") >= 0)) {
            return "Material 3 Dark";
        }
        if (p.id === "extras/Light" || (p.name === "extras" && p.id && p.id.indexOf("Light") >= 0)) {
            return "Material 3 Light";
        }
        if (!p.name) return p.id || "";
        return p.name.replace(/([a-z])([A-Z])/g, '$1 $2');
    }

    readonly property bool isDualPreset: {
        const p = root.presetData;
        return p && p.variants && p.variants.length > 1;
    }

    readonly property bool isLightPreset: {
        const p = root.presetData;
        if (!p) return false;
        if (root.isDualPreset) return false;
        if (p.id === "extras/Light") return true;
        const nameLower = ((p.name || "") + " " + (p.id || "")).toLowerCase();
        return nameLower.indexOf("light") >= 0 || nameLower.indexOf("dawn") >= 0 || nameLower.indexOf("latte") >= 0;
    }

    readonly property color col0: {
        const prev = root.presetData && root.presetData.previews;
        if (prev) {
            let arr = prev[root.currentMode];
            if (!arr || arr.length === 0)
                arr = prev["default"] || prev["dark"] || prev["light"];
            if (arr && arr.length > 0) return arr[0];
        }
        return Nexa.Theme.primary;
    }

    readonly property color col1: {
        const prev = root.presetData && root.presetData.previews;
        if (prev) {
            let arr = prev[root.currentMode];
            if (!arr || arr.length === 0)
                arr = prev["default"] || prev["dark"] || prev["light"];
            if (arr && arr.length > 1) return arr[1];
        }
        return Nexa.Theme.secondary;
    }

    readonly property color col2: {
        const prev = root.presetData && root.presetData.previews;
        if (prev) {
            let arr = prev[root.currentMode];
            if (!arr || arr.length === 0)
                arr = prev["default"] || prev["dark"] || prev["light"];
            if (arr && arr.length > 2) return arr[2];
        }
        return Nexa.Theme.tertiary;
    }

    height: 66
    radius: Nexa.Theme.radiusSm

    color: isStaged
        ? Qt.rgba(Nexa.Theme.primary.r, Nexa.Theme.primary.g, Nexa.Theme.primary.b, 0.08)
        : (cardMouse.containsMouse ? Nexa.Theme.hover : Nexa.Theme.surfaceContainer)

    border.width: isStaged ? 1.5 : (isSystemActive ? 1.0 : 1.0)
    border.color: isStaged ? Nexa.Theme.primary : (isSystemActive ? Nexa.Theme.primary : Nexa.Theme.border)

    Behavior on color { ColorAnimation { duration: Nexa.Theme.animationFast } }
    Behavior on border.color { ColorAnimation { duration: Nexa.Theme.animationFast } }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        anchors.topMargin: 8
        anchors.bottomMargin: 8
        spacing: 10

        // Left: Preset Title & Status Pills
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            Text {
                text: root.displayName
                font.family: Nexa.Theme.fontFamily
                font.pixelSize: 13
                font.weight: root.isStaged ? Nexa.Theme.fontWeightBold : Nexa.Theme.fontWeightDemiBold
                color: root.isStaged ? Nexa.Theme.primary : Nexa.Theme.text
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Row {
                spacing: 6

                // For Dual-Mode Presets: Interactive [ 󰖔 Dark ] and [ 󰖙 Light ] pills
                Row {
                    visible: root.isDualPreset
                    spacing: 4

                    // Dark Mode Pill
                    Rectangle {
                        height: 18
                        width: darkPillRow.implicitWidth + 8
                        radius: 9
                        readonly property bool isActive: (root.isStaged || root.isSystemActive) ? (root.currentMode === "dark") : false
                        color: isActive ? Nexa.Theme.primary : (darkPillHov.containsMouse ? Nexa.Theme.hover : Nexa.Theme.surfaceContainerHighest)
                        border.width: isActive ? 1 : 0
                        border.color: Nexa.Theme.primary

                        Row {
                            id: darkPillRow
                            anchors.centerIn: parent
                            spacing: 3
                            Text {
                                text: "󰖔"
                                font.family: Nexa.Theme.iconFontFamily
                                font.pixelSize: 10
                                color: parent.parent.isActive ? Nexa.Theme.onPrimary : Nexa.Theme.mutedText
                            }
                            Text {
                                text: "Dark"
                                font.family: Nexa.Theme.fontFamily
                                font.pixelSize: 9
                                font.weight: parent.parent.isActive ? Nexa.Theme.fontWeightBold : Nexa.Theme.fontWeightRegular
                                color: parent.parent.isActive ? Nexa.Theme.onPrimary : Nexa.Theme.mutedText
                            }
                        }

                        MouseArea {
                            id: darkPillHov
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.cardSelected(root.presetData.id, "dark")
                        }
                    }

                    // Light Mode Pill
                    Rectangle {
                        height: 18
                        width: lightPillRow.implicitWidth + 8
                        radius: 9
                        readonly property bool isActive: (root.isStaged || root.isSystemActive) ? (root.currentMode === "light") : false
                        color: isActive ? "#e5a50a" : (lightPillHov.containsMouse ? Nexa.Theme.hover : Nexa.Theme.surfaceContainerHighest)
                        border.width: isActive ? 1 : 0
                        border.color: isActive ? "#e5a50a" : "transparent"

                        Row {
                            id: lightPillRow
                            anchors.centerIn: parent
                            spacing: 3
                            Text {
                                text: "󰖙"
                                font.family: Nexa.Theme.iconFontFamily
                                font.pixelSize: 10
                                color: parent.parent.isActive ? "#1a1a24" : "#e5a50a"
                            }
                            Text {
                                text: "Light"
                                font.family: Nexa.Theme.fontFamily
                                font.pixelSize: 9
                                font.weight: parent.parent.isActive ? Nexa.Theme.fontWeightBold : Nexa.Theme.fontWeightRegular
                                color: parent.parent.isActive ? "#1a1a24" : Nexa.Theme.mutedText
                            }
                        }

                        MouseArea {
                            id: lightPillHov
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.cardSelected(root.presetData.id, "light")
                        }
                    }
                }

                // For Standalone Presets: Single Badge
                Rectangle {
                    visible: !root.isDualPreset
                    height: 18
                    width: singlePillRow.implicitWidth + 8
                    radius: 9
                    color: root.isLightPreset ? Qt.rgba(0.9, 0.65, 0.05, 0.15) : Nexa.Theme.surfaceContainerHighest

                    Row {
                        id: singlePillRow
                        anchors.centerIn: parent
                        spacing: 3
                        Text {
                            text: root.isLightPreset ? "󰖙" : "󰖔"
                            font.family: Nexa.Theme.iconFontFamily
                            font.pixelSize: 10
                            color: root.isLightPreset ? "#e5a50a" : Nexa.Theme.mutedText
                        }
                        Text {
                            text: root.isLightPreset ? "Light" : "Dark"
                            font.family: Nexa.Theme.fontFamily
                            font.pixelSize: 9
                            font.weight: Nexa.Theme.fontWeightMedium
                            color: root.isLightPreset ? "#e5a50a" : Nexa.Theme.mutedText
                        }
                    }
                }

                // Active Badge
                Rectangle {
                    visible: root.isSystemActive
                    height: 18
                    width: activeText.implicitWidth + 10
                    radius: 9
                    color: Qt.rgba(Nexa.Theme.primary.r, Nexa.Theme.primary.g, Nexa.Theme.primary.b, 0.15)

                    Text {
                        id: activeText
                        anchors.centerIn: parent
                        text: "Active"
                        font.family: Nexa.Theme.fontFamily
                        font.pixelSize: 9
                        font.weight: Nexa.Theme.fontWeightDemiBold
                        color: Nexa.Theme.primary
                    }
                }

                // Staged indicator (if not active)
                Rectangle {
                    visible: root.isStaged && !root.isSystemActive
                    height: 18
                    width: stagedText.implicitWidth + 10
                    radius: 9
                    color: Qt.rgba(Nexa.Theme.primary.r, Nexa.Theme.primary.g, Nexa.Theme.primary.b, 0.15)

                    Text {
                        id: stagedText
                        anchors.centerIn: parent
                        text: "Selected"
                        font.family: Nexa.Theme.fontFamily
                        font.pixelSize: 9
                        font.weight: Nexa.Theme.fontWeightDemiBold
                        color: Nexa.Theme.primary
                    }
                }
            }
        }

        // Right: Connected 3-Tone Capsule Swatch Ribbon
        Rectangle {
            Layout.preferredWidth: 66
            Layout.preferredHeight: 22
            radius: 11
            clip: true
            border.width: 1
            border.color: Nexa.Theme.border

            Row {
                anchors.fill: parent

                Rectangle {
                    width: 22
                    height: parent.height
                    color: root.col0
                }

                Rectangle {
                    width: 22
                    height: parent.height
                    color: root.col1
                }

                Rectangle {
                    width: 22
                    height: parent.height
                    color: root.col2
                }
            }
        }
    }

    MouseArea {
        id: cardMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (root.isDualPreset) {
                root.cardSelected(root.presetData.id, root.currentMode);
            } else if (root.isLightPreset) {
                root.cardSelected(root.presetData.id, "light");
            } else {
                root.cardSelected(root.presetData.id, "dark");
            }
        }
    }
}
