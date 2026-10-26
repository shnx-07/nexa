// pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import "../../theme" as Nexa
import "../../theme/components" as NexaUI

Item {
    id: root

    anchors.fill: parent

    signal requestClose()

    function rad(n) {
        if (Nexa.Theme.nexaRounding === 0) return 0;
        return Math.max(0, Math.round(n * (Nexa.Theme.nexaRounding / 10.0)));
    }

    // Local sandbox preview state
    property int targetW: 220
    property int targetH: 48
    property int targetR: 24
    property string activePreset: "pill"

    function setPreviewPreset(name, w, h, r) {
        activePreset = name;
        targetW = w;
        targetH = h;
        targetR = r;
    }

    Timer {
        id: stressTimer
        interval: 360
        repeat: true
        running: false
        property int step: 0
        onTriggered: {
            step = (step + 1) % 4;
            if (step === 0) setPreviewPreset("pill", 220, 48, 24);
            else if (step === 1) setPreviewPreset("osd", 280, 56, 28);
            else if (step === 2) setPreviewPreset("player", 380, 130, 24);
            else setPreviewPreset("notif", 440, 200, 28);
        }
    }

    Flickable {
        anchors.fill: parent
        anchors.margins: 18
        contentWidth: width
        contentHeight: contentCol.implicitHeight + 40
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        NexaUI.NexaSmoothScroll {}

        ColumnLayout {
            id: contentCol
            width: parent.width
            spacing: 16

            // ────────────────────────────────────────────────────────────
            // 1. HEADER
            // ────────────────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Rectangle {
                    width: 44
                    height: 44
                    radius: root.rad(22)
                    color: Nexa.Theme.primaryContainer
                    border.width: Nexa.Theme.borderThin
                    border.color: Nexa.Theme.border

                    Text {
                        anchors.centerIn: parent
                        text: "󰚌"
                        font.family: Nexa.Theme.iconFontFamily
                        font.pixelSize: 22
                        color: Nexa.Theme.onPrimaryContainer
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        text: "Motion & Spring Physics"
                        font.family: Nexa.Theme.fontFamily
                        font.pixelSize: 16
                        font.weight: Font.Bold
                        color: Nexa.Theme.text
                    }

                    Text {
                        text: "Granularly choose between modern harmonic springs and classic Nexa default easing per section"
                        font.family: Nexa.Theme.fontFamily
                        font.pixelSize: 12
                        color: Nexa.Theme.mutedText
                    }
                }

                // Global Quick Action Buttons
                RowLayout {
                    spacing: 8

                    // Revert All to Nexa Default
                    Rectangle {
                        width: defTxt.implicitWidth + 24
                        height: 32
                        radius: root.rad(6)
                        color: !Nexa.Theme.springEnabled ? Nexa.Theme.secondaryContainer : (defHov.containsMouse ? Nexa.Theme.surfaceContainerHighest : Nexa.Theme.surfaceContainerHigh)
                        border.width: !Nexa.Theme.springEnabled ? 1.5 : Nexa.Theme.borderThin
                        border.color: !Nexa.Theme.springEnabled ? Nexa.Theme.secondary : Nexa.Theme.border

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                text: "󰅖"
                                font.family: Nexa.Theme.iconFontFamily
                                font.pixelSize: 13
                                color: !Nexa.Theme.springEnabled ? Nexa.Theme.onSecondaryContainer : Nexa.Theme.text
                            }
                            Text {
                                id: defTxt
                                text: "Nexa Default (All)"
                                font.family: Nexa.Theme.fontFamily
                                font.pixelSize: 11
                                font.weight: !Nexa.Theme.springEnabled ? Font.Bold : Font.Medium
                                color: !Nexa.Theme.springEnabled ? Nexa.Theme.onSecondaryContainer : Nexa.Theme.text
                            }
                        }

                        MouseArea {
                            id: defHov
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                const classicSections = {
                                    "island": false,
                                    "popups": false,
                                    "clipboard": false,
                                    "settings": false,
                                    "wallpaper": false,
                                    "workspace": false,
                                    "sliders": false
                                };
                                Nexa.Theme.saveMotionConfig(4.0, 1.0, 1.0, "classic", false, classicSections);
                            }
                        }
                    }

                    // Apply Spring to All
                    Rectangle {
                        width: springAllTxt.implicitWidth + 24
                        height: 32
                        radius: root.rad(6)
                        color: Nexa.Theme.springEnabled ? Nexa.Theme.primaryContainer : (spHov.containsMouse ? Nexa.Theme.surfaceContainerHighest : Nexa.Theme.surfaceContainerHigh)
                        border.width: Nexa.Theme.springEnabled ? 1.5 : Nexa.Theme.borderThin
                        border.color: Nexa.Theme.springEnabled ? Nexa.Theme.primary : Nexa.Theme.border

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                text: "⚡"
                                font.pixelSize: 11
                                color: Nexa.Theme.springEnabled ? Nexa.Theme.primary : Nexa.Theme.text
                            }
                            Text {
                                id: springAllTxt
                                text: "Spring Physics (All)"
                                font.family: Nexa.Theme.fontFamily
                                font.pixelSize: 11
                                font.weight: Nexa.Theme.springEnabled ? Font.Bold : Font.Medium
                                color: Nexa.Theme.springEnabled ? Nexa.Theme.onPrimaryContainer : Nexa.Theme.text
                            }
                        }

                        MouseArea {
                            id: spHov
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                const allSections = {
                                    "island": true,
                                    "popups": true,
                                    "clipboard": true,
                                    "settings": true,
                                    "wallpaper": true,
                                    "workspace": true,
                                    "sliders": true
                                };
                                Nexa.Theme.saveMotionConfig(7.8, 0.16, 1.0, "bouncy", true, allSections);
                            }
                        }
                    }
                }
            }

            // ────────────────────────────────────────────────────────────
            // 2. INTERACTIVE SANDBOX PREVIEW
            // ────────────────────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                height: 250
                radius: root.rad(14)
                color: Nexa.Theme.surfaceContainer
                border.width: Nexa.Theme.borderThin
                border.color: Nexa.Theme.border

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12

                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            text: "Interactive Live Preview"
                            font.family: Nexa.Theme.fontFamily
                            font.pixelSize: 13
                            font.bold: true
                            color: Nexa.Theme.text
                        }

                        Item { Layout.fillWidth: true }

                        // Preset preview pills
                        RowLayout {
                            spacing: 6

                            Repeater {
                                model: [
                                    { id: "pill", label: "Pill", w: 220, h: 48, r: 24 },
                                    { id: "osd", label: "OSD", w: 280, h: 56, r: 28 },
                                    { id: "player", label: "Player", w: 380, h: 130, r: 24 },
                                    { id: "notif", label: "Card", w: 440, h: 200, r: 28 }
                                ]

                                Rectangle {
                                    width: pLbl.implicitWidth + 16
                                    height: 26
                                    radius: root.rad(13)
                                    color: root.activePreset === modelData.id ? Nexa.Theme.primary : (pHov.containsMouse ? Nexa.Theme.surfaceContainerHighest : Nexa.Theme.surfaceContainerHigh)
                                    border.width: 1
                                    border.color: root.activePreset === modelData.id ? Nexa.Theme.primary : Nexa.Theme.border

                                    Text {
                                        id: pLbl
                                        anchors.centerIn: parent
                                        text: modelData.label
                                        font.family: Nexa.Theme.fontFamily
                                        font.pixelSize: 11
                                        font.weight: root.activePreset === modelData.id ? Font.Bold : Font.Normal
                                        color: root.activePreset === modelData.id ? Nexa.Theme.onPrimary : Nexa.Theme.text
                                    }

                                    MouseArea {
                                        id: pHov
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            stressTimer.running = false;
                                            root.setPreviewPreset(modelData.id, modelData.w, modelData.h, modelData.r);
                                        }
                                    }
                                }
                            }

                            // Stress test toggle
                            Rectangle {
                                width: stressLbl.implicitWidth + 18
                                height: 26
                                radius: root.rad(13)
                                color: stressTimer.running ? "#f59e0b" : Nexa.Theme.surfaceContainerHigh
                                border.width: 1
                                border.color: stressTimer.running ? "#fbbf24" : Nexa.Theme.border

                                RowLayout {
                                    id: stressLbl
                                    anchors.centerIn: parent
                                    spacing: 4
                                    Text {
                                        text: stressTimer.running ? "⏹" : "⚡"
                                        font.pixelSize: 11
                                        color: stressTimer.running ? "#000000" : "#fbbf24"
                                    }
                                    Text {
                                        text: stressTimer.running ? "Stop Test" : "Stress Test"
                                        font.family: Nexa.Theme.fontFamily
                                        font.pixelSize: 11
                                        font.bold: true
                                        color: stressTimer.running ? "#000000" : "#fbbf24"
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: stressTimer.running = !stressTimer.running
                                }
                            }
                        }
                    }

                    // Morphing Stage
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: root.rad(10)
                        color: Nexa.Theme.surfaceContainerLowest
                        border.width: 1
                        border.color: Nexa.Theme.border
                        clip: true

                        Rectangle {
                            id: previewBox
                            anchors.centerIn: parent
                            width: root.targetW
                            height: Math.min(root.targetH, parent.height - 20)
                            radius: root.targetR
                            color: Nexa.Theme.primaryContainer
                            border.width: 1.5
                            border.color: Nexa.Theme.primary

                            Behavior on width {
                                NexaUI.NexaSpring { section: "island" }
                            }
                            Behavior on height {
                                NexaUI.NexaSpring { section: "island" }
                            }
                            Behavior on radius {
                                NexaUI.NexaSpring { section: "island" }
                            }

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 8

                                Rectangle {
                                    width: 8
                                    height: 8
                                    radius: 4
                                    color: Nexa.Theme.primary
                                }

                                Text {
                                    text: root.activePreset.toUpperCase()
                                    font.family: Nexa.Theme.fontFamily
                                    font.pixelSize: 12
                                    font.bold: true
                                    color: Nexa.Theme.onPrimaryContainer
                                }
                            }
                        }
                    }
                }
            }

            // ────────────────────────────────────────────────────────────
            // 3. PHYSICAL PRESETS
            // ────────────────────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: presetCol.implicitHeight + 24
                radius: root.rad(14)
                color: Nexa.Theme.surfaceContainer
                border.width: Nexa.Theme.borderThin
                border.color: Nexa.Theme.border

                ColumnLayout {
                    id: presetCol
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12

                    Text {
                        text: "Physical Presets"
                        font.family: Nexa.Theme.fontFamily
                        font.pixelSize: 13
                        font.bold: true
                        color: Nexa.Theme.text
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Repeater {
                            model: [
                                { id: "classic", name: "Nexa Default", sub: "Original 220ms (Zero Bounce)", s: 4.0, d: 1.0, m: 1.0, icon: "󰅖", classic: true },
                                { id: "bouncy", name: "Bouncy & Elastic", sub: "Stiffness 7.8, Damping 0.16", s: 7.8, d: 0.16, m: 1.0, icon: "󰑮", classic: false },
                                { id: "fluid", name: "Apple Fluid", sub: "Stiffness 3.8, Damping 0.28", s: 3.8, d: 0.28, m: 1.0, icon: "󰚌", classic: false },
                                { id: "snappy", name: "Crisp Snappy", sub: "Stiffness 5.5, Damping 0.35", s: 5.5, d: 0.35, m: 1.0, icon: "󰅒", classic: false },
                                { id: "gentle", name: "Smooth Gentle", sub: "Stiffness 2.8, Damping 0.30", s: 2.8, d: 0.30, m: 1.0, icon: "󰖲", classic: false }
                            ]

                            Rectangle {
                                Layout.fillWidth: true
                                height: 68
                                radius: root.rad(10)
                                readonly property bool isSelected: (!Nexa.Theme.springEnabled && modelData.id === "classic") || (Nexa.Theme.springEnabled && Nexa.Theme.springPreset === modelData.id)
                                color: isSelected ? Nexa.Theme.primaryContainer : (cHover.containsMouse ? Nexa.Theme.surfaceContainerHighest : Nexa.Theme.surfaceContainerHigh)
                                border.width: isSelected ? 1.5 : Nexa.Theme.borderThin
                                border.color: isSelected ? Nexa.Theme.primary : Nexa.Theme.border

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 10

                                    Text {
                                        text: modelData.icon
                                        font.family: Nexa.Theme.iconFontFamily
                                        font.pixelSize: 20
                                        color: isSelected ? Nexa.Theme.primary : Nexa.Theme.text
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2
                                        Text {
                                            text: modelData.name
                                            font.family: Nexa.Theme.fontFamily
                                            font.pixelSize: 12
                                            font.bold: true
                                            color: isSelected ? Nexa.Theme.onPrimaryContainer : Nexa.Theme.text
                                        }
                                        Text {
                                            text: modelData.sub
                                            font.family: Nexa.Theme.fontFamily
                                            font.pixelSize: 10
                                            color: Nexa.Theme.mutedText
                                        }
                                    }
                                }

                                MouseArea {
                                    id: cHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        const enableSpring = !modelData.classic;
                                        Nexa.Theme.saveMotionConfig(modelData.s, modelData.d, modelData.m, modelData.id, enableSpring, Nexa.Theme.motionSections);
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ────────────────────────────────────────────────────────────
            // 4. GRANULAR SECTION SELECTORS
            // ────────────────────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: secCol.implicitHeight + 24
                radius: root.rad(14)
                color: Nexa.Theme.surfaceContainer
                border.width: Nexa.Theme.borderThin
                border.color: Nexa.Theme.border

                ColumnLayout {
                    id: secCol
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 14

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "Section Motion Routing"
                            font.family: Nexa.Theme.fontFamily
                            font.pixelSize: 13
                            font.bold: true
                            color: Nexa.Theme.text
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: "Choose Spring Physics or Nexa Default per module"
                            font.family: Nexa.Theme.fontFamily
                            font.pixelSize: 11
                            color: Nexa.Theme.mutedText
                        }
                    }

                    Repeater {
                        model: [
                            { id: "island", name: "Dynamic Island", desc: "Fluid expansion of width, height, and corner radius", icon: "󰈺" },
                            { id: "popups", name: "System Popups (Battery, WiFi, Bluetooth)", desc: "Entrance scale, opacity, and progress meter transitions", icon: "󰂯" },
                            { id: "clipboard", name: "Clipboard Manager", desc: "Modal scale pop-in and item selection animations", icon: "󰅌" },
                            { id: "settings", name: "Settings Window & Modals", desc: "Dialog zoom, sidebar transitions, and tab indicator slides", icon: "󰒓" },
                            { id: "wallpaper", name: "Wallpaper Picker & Slideshow", desc: "Grid thumbnail expansion, card selection & preview capsule", icon: "󰸉" },
                            { id: "workspace", name: "Workspace Switcher & Manager", desc: "Workspace bar active indicator pill and overview window scaling", icon: "󰍹" },
                            { id: "sliders", name: "Sliders & Toggle Switches", desc: "Smooth track progress fill and tactile switch thumb flick", icon: "󱐋" }
                        ]

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            Rectangle {
                                width: 34
                                height: 34
                                radius: root.rad(8)
                                color: Nexa.Theme.useSpring(modelData.id) ? Nexa.Theme.primaryContainer : Nexa.Theme.surfaceContainerHigh
                                border.width: 1
                                border.color: Nexa.Theme.border

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.icon
                                    font.family: Nexa.Theme.iconFontFamily
                                    font.pixelSize: 16
                                    color: Nexa.Theme.useSpring(modelData.id) ? Nexa.Theme.primary : Nexa.Theme.mutedText
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1
                                Text {
                                    text: modelData.name
                                    font.family: Nexa.Theme.fontFamily
                                    font.pixelSize: 12
                                    font.bold: true
                                    color: Nexa.Theme.text
                                }
                                Text {
                                    text: modelData.desc
                                    font.family: Nexa.Theme.fontFamily
                                    font.pixelSize: 11
                                    color: Nexa.Theme.mutedText
                                }
                            }

                            // Badge indicating state
                            Rectangle {
                                width: modeBadgeTxt.implicitWidth + 14
                                height: 24
                                radius: root.rad(12)
                                color: Nexa.Theme.useSpring(modelData.id) ? Qt.rgba(Nexa.Theme.primary.r, Nexa.Theme.primary.g, Nexa.Theme.primary.b, 0.16) : Nexa.Theme.surfaceContainerHigh
                                border.width: 1
                                border.color: Nexa.Theme.useSpring(modelData.id) ? Nexa.Theme.primary : Nexa.Theme.border

                                Text {
                                    id: modeBadgeTxt
                                    anchors.centerIn: parent
                                    text: Nexa.Theme.useSpring(modelData.id) ? "⚡ Spring" : "↺ Default"
                                    font.family: Nexa.Theme.fontFamily
                                    font.pixelSize: 10
                                    font.bold: true
                                    color: Nexa.Theme.useSpring(modelData.id) ? Nexa.Theme.primary : Nexa.Theme.mutedText
                                }
                            }

                            NexaUI.NexaToggle {
                                checked: Nexa.Theme.useSpring(modelData.id)
                                onToggled: {
                                    let s = Object.assign({}, Nexa.Theme.motionSections);
                                    s[modelData.id] = checked;
                                    Nexa.Theme.saveMotionConfig(Nexa.Theme.springStiffness, Nexa.Theme.springDamping, Nexa.Theme.springMass, Nexa.Theme.springPreset, Nexa.Theme.springEnabled, s);
                                }
                            }
                        }
                    }
                }
            }

            // ────────────────────────────────────────────────────────────
            // 5. FINE-TUNE PARAMETERS
            // ────────────────────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: slidersCol.implicitHeight + 24
                radius: root.rad(14)
                color: Nexa.Theme.surfaceContainer
                border.width: Nexa.Theme.borderThin
                border.color: Nexa.Theme.border

                ColumnLayout {
                    id: slidersCol
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 16

                    Text {
                        text: "Fine-Tune Physics Parameters"
                        font.family: Nexa.Theme.fontFamily
                        font.pixelSize: 13
                        font.bold: true
                        color: Nexa.Theme.text
                    }

                    // Stiffness
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "Spring Stiffness (k)"
                                font.family: Nexa.Theme.fontFamily
                                font.pixelSize: 12
                                color: Nexa.Theme.text
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: Nexa.Theme.springStiffness.toFixed(1)
                                font.family: Nexa.Theme.fontFamily
                                font.pixelSize: 12
                                font.bold: true
                                color: Nexa.Theme.primary
                            }
                        }

                        Slider {
                            Layout.fillWidth: true
                            from: 1.0
                            to: 12.0
                            stepSize: 0.1
                            value: Nexa.Theme.springStiffness
                            onMoved: {
                                Nexa.Theme.saveMotionConfig(value, Nexa.Theme.springDamping, Nexa.Theme.springMass, "custom", true, Nexa.Theme.motionSections);
                            }
                        }
                    }

                    // Damping
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "Damping Friction (c)"
                                font.family: Nexa.Theme.fontFamily
                                font.pixelSize: 12
                                color: Nexa.Theme.text
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: Nexa.Theme.springDamping.toFixed(2)
                                font.family: Nexa.Theme.fontFamily
                                font.pixelSize: 12
                                font.bold: true
                                color: Nexa.Theme.primary
                            }
                        }

                        Slider {
                            Layout.fillWidth: true
                            from: 0.05
                            to: 0.80
                            stepSize: 0.01
                            value: Nexa.Theme.springDamping
                            onMoved: {
                                Nexa.Theme.saveMotionConfig(Nexa.Theme.springStiffness, value, Nexa.Theme.springMass, "custom", true, Nexa.Theme.motionSections);
                            }
                        }
                    }

                    // Mass
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "Inertial Mass (m)"
                                font.family: Nexa.Theme.fontFamily
                                font.pixelSize: 12
                                color: Nexa.Theme.text
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: Nexa.Theme.springMass.toFixed(1)
                                font.family: Nexa.Theme.fontFamily
                                font.pixelSize: 12
                                font.bold: true
                                color: Nexa.Theme.primary
                            }
                        }

                        Slider {
                            Layout.fillWidth: true
                            from: 0.5
                            to: 3.0
                            stepSize: 0.1
                            value: Nexa.Theme.springMass
                            onMoved: {
                                Nexa.Theme.saveMotionConfig(Nexa.Theme.springStiffness, Nexa.Theme.springDamping, value, "custom", true, Nexa.Theme.motionSections);
                            }
                        }
                    }
                }
            }
        }
    }
}
