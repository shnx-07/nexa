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
        interval: 380
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
        contentHeight: contentCol.implicitHeight + 20
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
                        text: "󰏢"
                        font.family: Nexa.Theme.iconFontFamily
                        font.pixelSize: 22
                        color: Nexa.Theme.primary
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

                    // Revert All to Classic Nexa Default
                    Rectangle {
                        width: defTxt.implicitWidth + 28
                        height: 32
                        radius: root.rad(16)
                        color: !Nexa.Theme.springEnabled ? Nexa.Theme.secondaryContainer : (defHov.containsMouse ? Nexa.Theme.surfaceContainerHighest : Nexa.Theme.surfaceContainerHigh)
                        border.width: Nexa.Theme.borderThin
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
                                text: "Classic Easing (All)"
                                font.family: Nexa.Theme.fontFamily
                                font.pixelSize: 11
                                font.weight: !Nexa.Theme.springEnabled ? Font.Bold : Font.Normal
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
                        width: springAllTxt.implicitWidth + 28
                        height: 32
                        radius: root.rad(16)
                        color: Nexa.Theme.springEnabled ? Nexa.Theme.primaryContainer : (spHov.containsMouse ? Nexa.Theme.surfaceContainerHighest : Nexa.Theme.surfaceContainerHigh)
                        border.width: Nexa.Theme.borderThin
                        border.color: Nexa.Theme.springEnabled ? Nexa.Theme.primary : Nexa.Theme.border

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                text: "󱐋"
                                font.family: Nexa.Theme.iconFontFamily
                                font.pixelSize: 13
                                color: Nexa.Theme.springEnabled ? Nexa.Theme.primary : Nexa.Theme.text
                            }
                            Text {
                                id: springAllTxt
                                text: "Spring Physics (All)"
                                font.family: Nexa.Theme.fontFamily
                                font.pixelSize: 11
                                font.weight: Nexa.Theme.springEnabled ? Font.Bold : Font.Normal
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
                                Nexa.Theme.saveMotionConfig(3.8, 0.28, 1.0, "fluid", true, allSections);
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
                height: 230
                radius: root.rad(14)
                color: Nexa.Theme.surfaceContainer
                border.width: Nexa.Theme.borderThin
                border.color: Nexa.Theme.border

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 10

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

                        // Modern Unified Segmented Capsule Bar
                        Rectangle {
                            implicitWidth: segRow.implicitWidth + 8
                            implicitHeight: 32
                            radius: root.rad(16)
                            color: Nexa.Theme.surfaceContainerHigh
                            border.width: Nexa.Theme.borderThin
                            border.color: Nexa.Theme.border

                            Row {
                                id: segRow
                                anchors.centerIn: parent
                                spacing: 3

                                Repeater {
                                    model: [
                                        { id: "pill", label: "Pill", w: 220, h: 48, r: 24 },
                                        { id: "osd", label: "OSD", w: 280, h: 56, r: 28 },
                                        { id: "player", label: "Player", w: 380, h: 120, r: 24 },
                                        { id: "notif", label: "Card", w: 440, h: 160, r: 28 }
                                    ]

                                    Rectangle {
                                        width: pLbl.implicitWidth + 22
                                        height: 26
                                        radius: root.rad(13)
                                        readonly property bool isSelected: root.activePreset === modelData.id && !stressTimer.running
                                        color: isSelected ? Nexa.Theme.primary : (pHov.containsMouse ? Nexa.Theme.surfaceContainerHighest : "transparent")

                                        Text {
                                            id: pLbl
                                            anchors.centerIn: parent
                                            text: modelData.label
                                            font.family: Nexa.Theme.fontFamily
                                            font.pixelSize: 11
                                            font.weight: isSelected ? Font.Bold : Font.Normal
                                            color: isSelected ? Nexa.Theme.onPrimary : Nexa.Theme.text
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

                                // Subtle separator
                                Rectangle {
                                    width: 1
                                    height: 16
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: Nexa.Theme.border
                                }

                                // Auto Cycle / Stress Test Button
                                Rectangle {
                                    width: stressLbl.implicitWidth + 22
                                    height: 26
                                    radius: root.rad(13)
                                    color: stressTimer.running ? Nexa.Theme.primary : (stressHov.containsMouse ? Nexa.Theme.surfaceContainerHighest : "transparent")

                                    RowLayout {
                                        id: stressLbl
                                        anchors.centerIn: parent
                                        spacing: 5
                                        Text {
                                            text: stressTimer.running ? "󰅖" : "󱐋"
                                            font.family: Nexa.Theme.iconFontFamily
                                            font.pixelSize: 12
                                            color: stressTimer.running ? Nexa.Theme.onPrimary : Nexa.Theme.text
                                        }
                                        Text {
                                            text: stressTimer.running ? "Stop Test" : "Auto Cycle"
                                            font.family: Nexa.Theme.fontFamily
                                            font.pixelSize: 11
                                            font.weight: stressTimer.running ? Font.Bold : Font.Normal
                                            color: stressTimer.running ? Nexa.Theme.onPrimary : Nexa.Theme.text
                                        }
                                    }

                                    MouseArea {
                                        id: stressHov
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: stressTimer.running = !stressTimer.running
                                    }
                                }
                            }
                        }
                    }

                    // Morphing Stage (Deep glass stage canvas)
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: root.rad(10)
                        color: Nexa.Theme.glassMode ? Qt.rgba(0, 0, 0, 0.45) : Qt.rgba(0, 0, 0, 0.32)
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
                    anchors.margins: 14
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "Physical Presets"
                            font.family: Nexa.Theme.fontFamily
                            font.pixelSize: 13
                            font.bold: true
                            color: Nexa.Theme.text
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: "Curated harmonic parameters"
                            font.family: Nexa.Theme.fontFamily
                            font.pixelSize: 11
                            color: Nexa.Theme.mutedText
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Repeater {
                            model: [
                                { id: "classic", name: "Classic Linear", sub: "220ms · 0 Bounce", s: 4.0, d: 1.0, m: 1.0, icon: "󰅖", classic: true },
                                { id: "fluid", name: "Apple Fluid", sub: "k: 3.8 · c: 0.28", s: 3.8, d: 0.28, m: 1.0, icon: "󰀵", classic: false },
                                { id: "snappy", name: "Crisp Snappy", sub: "k: 5.5 · c: 0.35", s: 5.5, d: 0.35, m: 1.0, icon: "󰅒", classic: false },
                                { id: "gentle", name: "Smooth Gentle", sub: "k: 2.8 · c: 0.30", s: 2.8, d: 0.30, m: 1.0, icon: "󰖲", classic: false },
                                { id: "bouncy", name: "Bouncy & Elastic", sub: "k: 7.8 · c: 0.16", s: 7.8, d: 0.16, m: 1.0, icon: "󰑮", classic: false }
                            ]

                            Rectangle {
                                Layout.fillWidth: true
                                height: 68
                                radius: root.rad(10)
                                readonly property bool isSelected: (!Nexa.Theme.springEnabled && modelData.id === "classic") || (Nexa.Theme.springEnabled && Nexa.Theme.springPreset === modelData.id)
                                color: isSelected ? Nexa.Theme.primaryContainer : (cHover.containsMouse ? Nexa.Theme.surfaceContainerHighest : Nexa.Theme.surfaceContainerHigh)
                                border.width: isSelected ? 1.5 : Nexa.Theme.borderThin
                                border.color: isSelected ? Nexa.Theme.primary : Nexa.Theme.border

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 4

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 8

                                        Text {
                                            text: modelData.icon
                                            font.family: Nexa.Theme.iconFontFamily
                                            font.pixelSize: 18
                                            color: isSelected ? Nexa.Theme.primary : Nexa.Theme.text
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.name
                                            font.family: Nexa.Theme.fontFamily
                                            font.pixelSize: 12
                                            font.bold: true
                                            elide: Text.ElideRight
                                            color: isSelected ? Nexa.Theme.onPrimaryContainer : Nexa.Theme.text
                                        }
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.sub
                                        font.family: Nexa.Theme.fontFamily
                                        font.pixelSize: 11
                                        font.features: Nexa.Theme.fontFeaturesTnum
                                        elide: Text.ElideRight
                                        color: isSelected ? Nexa.Theme.primary : Nexa.Theme.mutedText
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
            // 4. MOTION ROUTING & FINE-TUNE PARAMETERS (Side-by-Side Symmetrical)
            // ────────────────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 14

                // 4A. Section Motion Routing (Left Column ~56% width)
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 550
                    Layout.fillHeight: true
                    implicitHeight: secCol.implicitHeight + 28
                    radius: root.rad(14)
                    color: Nexa.Theme.surfaceContainer
                    border.width: Nexa.Theme.borderThin
                    border.color: Nexa.Theme.border

                    ColumnLayout {
                        id: secCol
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 9

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
                                text: "Toggle per module"
                                font.family: Nexa.Theme.fontFamily
                                font.pixelSize: 11
                                color: Nexa.Theme.mutedText
                            }
                        }

                        Repeater {
                            model: [
                                { id: "island", name: "Dynamic Island", desc: "Fluid expansion & radius morphing", icon: "󰈺" },
                                { id: "popups", name: "System Popups", desc: "Battery, WiFi, Bluetooth entrance scale", icon: "󰂯" },
                                { id: "clipboard", name: "Clipboard Manager", desc: "Modal scale pop-in & item transitions", icon: "󰅌" },
                                { id: "settings", name: "Settings Window & Modals", desc: "Dialog zoom & tab indicator slides", icon: "󰒓" },
                                { id: "wallpaper", name: "Wallpaper Picker", desc: "Grid thumbnail & preview capsule", icon: "󰸉" },
                                { id: "workspace", name: "Workspace Switcher", desc: "Active indicator pill & overview zoom", icon: "󰍹" },
                                { id: "sliders", name: "Sliders & Toggle Switches", desc: "Smooth track fill & tactile flick", icon: "󱐋" }
                            ]

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10

                                Rectangle {
                                    width: 30
                                    height: 30
                                    radius: root.rad(7)
                                    color: Nexa.Theme.useSpring(modelData.id) ? Nexa.Theme.primaryContainer : Nexa.Theme.surfaceContainerHigh
                                    border.width: 1
                                    border.color: Nexa.Theme.border

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.icon
                                        font.family: Nexa.Theme.iconFontFamily
                                        font.pixelSize: 15
                                        color: Nexa.Theme.useSpring(modelData.id) ? Nexa.Theme.primary : Nexa.Theme.mutedText
                                    }
                                }

                                ColumnLayout {
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
                                        font.pixelSize: 10
                                        color: Nexa.Theme.mutedText
                                    }
                                }

                                Item { Layout.fillWidth: true }

                                NexaUI.NexaToggle {
                                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
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

                // 4B. Fine-Tune Physics Parameters (Right Column ~44% width - 3 vertically stacked sliders)
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 420
                    Layout.fillHeight: true
                    implicitHeight: slidersCol.implicitHeight + 28
                    radius: root.rad(14)
                    color: Nexa.Theme.surfaceContainer
                    border.width: Nexa.Theme.borderThin
                    border.color: Nexa.Theme.border

                    ColumnLayout {
                        id: slidersCol
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 12

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "Fine-Tune Physics Parameters"
                                font.family: Nexa.Theme.fontFamily
                                font.pixelSize: 13
                                font.bold: true
                                color: Nexa.Theme.text
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: "Real-time tuning"
                                font.family: Nexa.Theme.fontFamily
                                font.pixelSize: 11
                                color: Nexa.Theme.mutedText
                            }
                        }

                        // 1. Stiffness (k)
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: "Spring Stiffness (k)"
                                    font.family: Nexa.Theme.fontFamily
                                    font.pixelSize: 12
                                    font.weight: Nexa.Theme.fontWeightDemiBold
                                    color: Nexa.Theme.text
                                }
                                Item { Layout.fillWidth: true }
                                Text {
                                    text: Nexa.Theme.springStiffness.toFixed(1)
                                    font.family: Nexa.Theme.fontFamily
                                    font.pixelSize: 12
                                    font.weight: Nexa.Theme.fontWeightDemiBold
                                    font.features: Nexa.Theme.fontFeaturesTnum
                                    color: Nexa.Theme.primary
                                }
                            }

                            NexaUI.NexaSlider {
                                Layout.fillWidth: true
                                sliderHeight: 28
                                from: 1.0
                                to: 12.0
                                stepSize: 0.1
                                value: Nexa.Theme.springStiffness
                                icon: "󱐋"
                                iconPosition: "left"
                                onMoved: (val) => {
                                    Nexa.Theme.saveMotionConfig(val, Nexa.Theme.springDamping, Nexa.Theme.springMass, "custom", true, Nexa.Theme.motionSections);
                                }
                            }
                        }

                        // 2. Damping (c)
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: "Damping Friction (c)"
                                    font.family: Nexa.Theme.fontFamily
                                    font.pixelSize: 12
                                    font.weight: Nexa.Theme.fontWeightDemiBold
                                    color: Nexa.Theme.text
                                }
                                Item { Layout.fillWidth: true }
                                Text {
                                    text: Nexa.Theme.springDamping.toFixed(2)
                                    font.family: Nexa.Theme.fontFamily
                                    font.pixelSize: 12
                                    font.weight: Nexa.Theme.fontWeightDemiBold
                                    font.features: Nexa.Theme.fontFeaturesTnum
                                    color: Nexa.Theme.primary
                                }
                            }

                            NexaUI.NexaSlider {
                                Layout.fillWidth: true
                                sliderHeight: 28
                                from: 0.05
                                to: 0.80
                                stepSize: 0.01
                                value: Nexa.Theme.springDamping
                                icon: "󰑮"
                                iconPosition: "left"
                                onMoved: (val) => {
                                    Nexa.Theme.saveMotionConfig(Nexa.Theme.springStiffness, val, Nexa.Theme.springMass, "custom", true, Nexa.Theme.motionSections);
                                }
                            }
                        }

                        // 3. Inertial Mass (m)
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: "Inertial Mass (m)"
                                    font.family: Nexa.Theme.fontFamily
                                    font.pixelSize: 12
                                    font.weight: Nexa.Theme.fontWeightDemiBold
                                    color: Nexa.Theme.text
                                }
                                Item { Layout.fillWidth: true }
                                Text {
                                    text: Nexa.Theme.springMass.toFixed(1)
                                    font.family: Nexa.Theme.fontFamily
                                    font.pixelSize: 12
                                    font.weight: Nexa.Theme.fontWeightDemiBold
                                    font.features: Nexa.Theme.fontFeaturesTnum
                                    color: Nexa.Theme.primary
                                }
                            }

                            NexaUI.NexaSlider {
                                Layout.fillWidth: true
                                sliderHeight: 28
                                from: 0.5
                                to: 3.0
                                stepSize: 0.1
                                value: Nexa.Theme.springMass
                                icon: "󰓡"
                                iconPosition: "left"
                                onMoved: (val) => {
                                    Nexa.Theme.saveMotionConfig(Nexa.Theme.springStiffness, Nexa.Theme.springDamping, val, "custom", true, Nexa.Theme.motionSections);
                                }
                            }
                        }

                        Item { Layout.fillHeight: true }

                        // Info pill at the bottom of the sliders card
                        Rectangle {
                            Layout.fillWidth: true
                            height: 36
                            radius: root.rad(8)
                            color: Nexa.Theme.surfaceContainerHigh
                            border.width: 1
                            border.color: Nexa.Theme.border

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 8
                                Text {
                                    text: "󰏢"
                                    font.family: Nexa.Theme.iconFontFamily
                                    font.pixelSize: 14
                                    color: Nexa.Theme.primary
                                }
                                Text {
                                    text: "Active Preset: " + Nexa.Theme.springPreset.toUpperCase()
                                    font.family: Nexa.Theme.fontFamily
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                    color: Nexa.Theme.mutedText
                                }
                            }
                        }
                    }
                }
            }

            // ────────────────────────────────────────────────────────────
            // 5. HYPRLAND COMPOSITOR TRANSITIONS & ANIMATION PROFILES
            // ────────────────────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: hyprAnimCol.implicitHeight + 24
                radius: root.rad(14)
                color: Nexa.Theme.surfaceContainer
                border.width: Nexa.Theme.borderThin
                border.color: Nexa.Theme.border

                ColumnLayout {
                    id: hyprAnimCol
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 12

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "Hyprland Compositor Animation Profiles"
                            font.family: Nexa.Theme.fontFamily
                            font.pixelSize: 13
                            font.bold: true
                            color: Nexa.Theme.text
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: "Instant live cubic beziers & workspace transitions"
                            font.family: Nexa.Theme.fontFamily
                            font.pixelSize: 11
                            color: Nexa.Theme.mutedText
                        }
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 4
                        columnSpacing: 10
                        rowSpacing: 10

                        Repeater {
                            model: [
                                { id: "fluid", name: "Apple Fluid", sub: "Natural damping · Smooth", icon: "󰀵" },
                                { id: "bouncy", name: "Elastic Bouncy", sub: "Spring recoil · Overshoot", icon: "󰑮" },
                                { id: "slidefade", name: "Slide & Fade", sub: "Modern Wayland crossfade", icon: "󰖲" },
                                { id: "snappy", name: "Crisp Snappy", sub: "120ms ultra-fast speed", icon: "󰅒" },
                                { id: "cinematic", name: "Cinematic Gentle", sub: "Velvety smooth 400ms curves", icon: "󰏢" },
                                { id: "pop", name: "Arcade Pop", sub: "Center 50% pop-in scale", icon: "󱐋" },
                                { id: "minimal", name: "Minimal Fade", sub: "Zero motion · Opacity only", icon: "󰅖" },
                                { id: "game", name: "Game Mode", sub: "Instant 0ms cut · 0 latency", icon: "󰊴" }
                            ]

                            Rectangle {
                                Layout.fillWidth: true
                                height: 60
                                radius: root.rad(10)
                                readonly property bool isSelected: Nexa.Theme.hyprAnimationProfile === modelData.id
                                color: isSelected ? Nexa.Theme.primaryContainer : (animHover.containsMouse ? Nexa.Theme.surfaceContainerHighest : Nexa.Theme.surfaceContainerHigh)
                                border.width: isSelected ? 1.5 : Nexa.Theme.borderThin
                                border.color: isSelected ? Nexa.Theme.primary : Nexa.Theme.border

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 3

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 8

                                        Text {
                                            text: modelData.icon
                                            font.family: Nexa.Theme.iconFontFamily
                                            font.pixelSize: 16
                                            color: isSelected ? Nexa.Theme.primary : Nexa.Theme.text
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.name
                                            font.family: Nexa.Theme.fontFamily
                                            font.pixelSize: 12
                                            font.bold: true
                                            elide: Text.ElideRight
                                            color: isSelected ? Nexa.Theme.onPrimaryContainer : Nexa.Theme.text
                                        }
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.sub
                                        font.family: Nexa.Theme.fontFamily
                                        font.pixelSize: 10
                                        elide: Text.ElideRight
                                        color: isSelected ? Nexa.Theme.primary : Nexa.Theme.mutedText
                                    }
                                }

                                MouseArea {
                                    id: animHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        Nexa.Theme.saveHyprAnimationProfile(modelData.id);
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
