// pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import "../../NewNexaUI" as NexaUI

Item {
    id: root

    anchors.fill: parent

    signal requestClose()

    function rad(n) {
        if (NexaUI.NexaTokens.nexaRounding === 0) return 0;
        return Math.max(0, Math.round(n * (NexaUI.NexaTokens.nexaRounding / 10.0)));
    }

    // Local sandbox preview state
    property int targetW: 220
    property int targetH: 48
    property int targetR: 24
    property string activePreset: "pill"
    property real squashVal: 0

    Behavior on squashVal {
        NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
    }

    readonly property bool isPhysicsActive: wAnim.running || hAnim.running || rAnim.running || stressTimer.running

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
                    color: NexaUI.NexaColors.primaryContainer
                    border.width: NexaUI.NexaTokens.borderThin
                    border.color: NexaUI.NexaColors.border

                    Text {
                        anchors.centerIn: parent
                        text: "󰏢"
                        font.family: NexaUI.NexaTypography.familyIcon
                        font.pixelSize: 22
                        color: NexaUI.NexaColors.primary
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        text: "Motion & Spring Physics"
                        font.family: NexaUI.NexaTypography.familyBody
                        font.pixelSize: 16
                        font.weight: Font.Bold
                        color: NexaUI.NexaColors.text
                    }

                    Text {
                        text: "Granularly choose between modern harmonic springs and classic Nexa default easing per section"
                        font.family: NexaUI.NexaTypography.familyBody
                        font.pixelSize: 12
                        color: NexaUI.NexaColors.mutedText
                    }
                }

                // Global Quick Action Buttons (Mutually Exclusive Engine Select)
                RowLayout {
                    spacing: 8

                    // Revert All to Classic Nexa Default
                    Rectangle {
                        width: defTxt.implicitWidth + 28
                        height: 32
                        radius: root.rad(16)
                        readonly property bool isSelected: NexaUI.NexaMotion.physicsEngine === "classic"
                        color: isSelected ? NexaUI.NexaColors.secondaryContainer : (defHov.containsMouse ? NexaUI.NexaColors.surfaceContainerHighest : NexaUI.NexaColors.surfaceContainerHigh)
                        border.width: NexaUI.NexaTokens.borderThin
                        border.color: isSelected ? NexaUI.NexaColors.secondary : NexaUI.NexaColors.border

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                text: "󰅖"
                                font.family: NexaUI.NexaTypography.familyIcon
                                font.pixelSize: 13
                                color: isSelected ? NexaUI.NexaColors.onSecondaryContainer : NexaUI.NexaColors.text
                            }
                            Text {
                                id: defTxt
                                text: "Classic Easing (All)"
                                font.family: NexaUI.NexaTypography.familyBody
                                font.pixelSize: 11
                                font.weight: isSelected ? Font.Bold : Font.Normal
                                color: isSelected ? NexaUI.NexaColors.onSecondaryContainer : NexaUI.NexaColors.text
                            }
                        }

                        MouseArea {
                            id: defHov
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                NexaUI.NexaMotion.savePhysicsEngine("classic", 0.44, 1.0, "classic");
                            }
                        }
                    }

                    // Apply Spring to All
                    Rectangle {
                        width: springAllTxt.implicitWidth + 28
                        height: 32
                        radius: root.rad(16)
                        readonly property bool isSelected: NexaUI.NexaMotion.physicsEngine === "fluid"
                        color: isSelected ? NexaUI.NexaColors.primaryContainer : (spHov.containsMouse ? NexaUI.NexaColors.surfaceContainerHighest : NexaUI.NexaColors.surfaceContainerHigh)
                        border.width: NexaUI.NexaTokens.borderThin
                        border.color: isSelected ? NexaUI.NexaColors.primary : NexaUI.NexaColors.border

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                text: "󰀵"
                                font.family: NexaUI.NexaTypography.familyIcon
                                font.pixelSize: 13
                                color: isSelected ? NexaUI.NexaColors.primary : NexaUI.NexaColors.text
                            }
                            Text {
                                id: springAllTxt
                                text: "Apple Fluid Physics (All)"
                                font.family: NexaUI.NexaTypography.familyBody
                                font.pixelSize: 11
                                font.weight: isSelected ? Font.Bold : Font.Normal
                                color: isSelected ? NexaUI.NexaColors.onPrimaryContainer : NexaUI.NexaColors.text
                            }
                        }

                        MouseArea {
                            id: spHov
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                NexaUI.NexaMotion.savePhysicsEngine("fluid", 0.44, 0.86, "fluid");
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
                color: NexaUI.NexaColors.surfaceContainer
                border.width: NexaUI.NexaTokens.borderThin
                border.color: NexaUI.NexaColors.border

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Text {
                            text: "Interactive Live Preview"
                            font.family: NexaUI.NexaTypography.familyBody
                            font.pixelSize: 13
                            font.bold: true
                            color: NexaUI.NexaColors.text
                        }

                        // Real-Time Zero-Strain Activity Monitor Badge
                        Rectangle {
                            Layout.preferredHeight: 22
                            Layout.preferredWidth: statusText.contentWidth + 16
                            radius: 11
                            color: root.isPhysicsActive ? Qt.rgba(0.9, 0.7, 0.1, 0.20) : Qt.rgba(0.1, 0.8, 0.3, 0.18)
                            border.width: 1
                            border.color: root.isPhysicsActive ? "#eab308" : "#22c55e"

                            Text {
                                id: statusText
                                anchors.centerIn: parent
                                text: root.isPhysicsActive ? "⚡ SPRING MOVING (Vsync)" : "● PHYSICS SLEEPING (0.0% CPU)"
                                font.family: NexaUI.NexaTypography.familyBody
                                font.pixelSize: 10
                                font.weight: Font.Bold
                                color: root.isPhysicsActive ? "#fef08a" : "#86efac"
                            }
                        }

                        Item { Layout.fillWidth: true }

                        // Modern Unified Segmented Capsule Bar
                        Rectangle {
                            implicitWidth: segRow.implicitWidth + 8
                            implicitHeight: 32
                            radius: root.rad(16)
                            color: NexaUI.NexaColors.surfaceContainerHigh
                            border.width: NexaUI.NexaTokens.borderThin
                            border.color: NexaUI.NexaColors.border

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
                                        color: isSelected ? NexaUI.NexaColors.primary : (pHov.containsMouse ? NexaUI.NexaColors.surfaceContainerHighest : "transparent")

                                        Text {
                                            id: pLbl
                                            anchors.centerIn: parent
                                            text: modelData.label
                                            font.family: NexaUI.NexaTypography.familyBody
                                            font.pixelSize: 11
                                            font.weight: isSelected ? Font.Bold : Font.Normal
                                            color: isSelected ? NexaUI.NexaColors.onPrimary : NexaUI.NexaColors.text
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
                                    color: NexaUI.NexaColors.border
                                }

                                // Auto Cycle / Stress Test Button
                                Rectangle {
                                    width: stressLbl.implicitWidth + 22
                                    height: 26
                                    radius: root.rad(13)
                                    color: stressTimer.running ? NexaUI.NexaColors.primary : (stressHov.containsMouse ? NexaUI.NexaColors.surfaceContainerHighest : "transparent")

                                    RowLayout {
                                        id: stressLbl
                                        anchors.centerIn: parent
                                        spacing: 5
                                        Text {
                                            text: stressTimer.running ? "󰅖" : "󱐋"
                                            font.family: NexaUI.NexaTypography.familyIcon
                                            font.pixelSize: 12
                                            color: stressTimer.running ? NexaUI.NexaColors.onPrimary : NexaUI.NexaColors.text
                                        }
                                        Text {
                                            text: stressTimer.running ? "Stop Test" : "Auto Cycle"
                                            font.family: NexaUI.NexaTypography.familyBody
                                            font.pixelSize: 11
                                            font.weight: stressTimer.running ? Font.Bold : Font.Normal
                                            color: stressTimer.running ? NexaUI.NexaColors.onPrimary : NexaUI.NexaColors.text
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
                        color: NexaUI.NexaOptics.glassMode ? Qt.rgba(0, 0, 0, 0.45) : Qt.rgba(0, 0, 0, 0.32)
                        border.width: 1
                        border.color: NexaUI.NexaColors.border
                        clip: true

                        // Tight Contact Shadow
                        Rectangle {
                            anchors.fill: previewBox
                            anchors.topMargin: 2
                            anchors.bottomMargin: -2
                            radius: previewBox.radius
                            color: Qt.rgba(0, 0, 0, 0.45 * NexaUI.NexaOptics.shadowBlurFactor)
                            visible: NexaUI.NexaOptics.contactShadow
                            antialiasing: previewBox.radius > 0
                        }

                        Rectangle {
                            id: previewBox
                            anchors.centerIn: parent
                            width: root.targetW * (1 + 0.05 * root.squashVal)
                            height: Math.min(root.targetH, parent.height - 20) * (1 - 0.07 * root.squashVal)
                            radius: root.targetR
                            color: NexaUI.NexaColors.primaryContainer
                            border.width: 1.5
                            border.color: NexaUI.NexaColors.primary

                            Behavior on width {
                                id: wAnim
                                SpringAnimation {
                                    spring: NexaUI.NexaMotion.islandSpringStiffness
                                    damping: NexaUI.NexaMotion.islandSpringDamping
                                    epsilon: 0.25
                                    mass: NexaUI.NexaMotion.islandSpringMass
                                }
                            }
                            Behavior on height {
                                id: hAnim
                                SpringAnimation {
                                    spring: NexaUI.NexaMotion.islandSpringStiffness
                                    damping: NexaUI.NexaMotion.islandSpringDamping
                                    epsilon: 0.25
                                    mass: NexaUI.NexaMotion.islandSpringMass
                                }
                            }
                            Behavior on radius {
                                id: rAnim
                                SpringAnimation {
                                    spring: NexaUI.NexaMotion.islandSpringStiffness
                                    damping: NexaUI.NexaMotion.islandSpringDamping
                                    epsilon: 0.25
                                    mass: NexaUI.NexaMotion.islandSpringMass
                                }
                            }

                            // Apple Tactile 4-stop OLED Depth Micro-Gradient
                            Rectangle {
                                anchors.fill: parent
                                radius: parent.radius
                                antialiasing: parent.radius > 0
                                visible: NexaUI.NexaOptics.surface3DGradient && NexaUI.NexaOptics.gradientIntensity > 0.01
                                opacity: NexaUI.NexaOptics.gradientIntensity
                                gradient: Gradient {
                                    GradientStop { position: 0.00; color: Qt.rgba(1, 1, 1, 0.070) }
                                    GradientStop { position: 0.40; color: Qt.rgba(1, 1, 1, 0.016) }
                                    GradientStop { position: 0.72; color: Qt.rgba(0, 0, 0, 0.000) }
                                    GradientStop { position: 1.00; color: Qt.rgba(0, 0, 0, 0.160) }
                                }
                            }

                            // Apple 1px Top Chamfer Specular Highlight
                            Rectangle {
                                anchors.top: parent.top
                                anchors.topMargin: 1
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: parent.radius > 0 ? Math.max(0, parent.width - parent.radius * 1.5) : parent.width
                                height: 1
                                visible: NexaUI.NexaOptics.specularHighlight && NexaUI.NexaOptics.specularIntensity > 0.01
                                opacity: Math.min(1.0, NexaUI.NexaOptics.specularIntensity / 0.28)
                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop { position: 0.0; color: "transparent" }
                                    GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.40) }
                                    GradientStop { position: 1.0; color: "transparent" }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onPressed: root.squashVal = 1.0
                                onReleased: root.squashVal = 0.0
                                onCanceled: root.squashVal = 0.0
                            }

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 8

                                Rectangle {
                                    width: 8
                                    height: 8
                                    radius: 4
                                    color: NexaUI.NexaColors.primary
                                }

                                Text {
                                    text: root.activePreset.toUpperCase()
                                    font.family: NexaUI.NexaTypography.familyBody
                                    font.pixelSize: 12
                                    font.bold: true
                                    color: NexaUI.NexaColors.onPrimaryContainer
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
                color: NexaUI.NexaColors.surfaceContainer
                border.width: NexaUI.NexaTokens.borderThin
                border.color: NexaUI.NexaColors.border

                ColumnLayout {
                    id: presetCol
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "Physical Presets"
                            font.family: NexaUI.NexaTypography.familyBody
                            font.pixelSize: 13
                            font.bold: true
                            color: NexaUI.NexaColors.text
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: "Curated harmonic parameters"
                            font.family: NexaUI.NexaTypography.familyBody
                            font.pixelSize: 11
                            color: NexaUI.NexaColors.mutedText
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Repeater {
                            model: [
                                { id: "classic", name: "Classic Linear", sub: "220ms · 0 Bounce", engine: "classic", resp: 0.44, damp: 1.0, icon: "󰅖" },
                                { id: "fluid", name: "Apple Fluid", sub: "Resp: 0.44s · Damp: 0.86", engine: "fluid", resp: 0.44, damp: 0.86, icon: "󰀵" },
                                { id: "snappy", name: "Crisp Snappy", sub: "Resp: 0.30s · Damp: 0.90", engine: "fluid", resp: 0.30, damp: 0.90, icon: "󰅒" },
                                { id: "gentle", name: "Smooth Gentle", sub: "Resp: 0.60s · Damp: 0.95", engine: "fluid", resp: 0.60, damp: 0.95, icon: "󰖲" },
                                { id: "bouncy", name: "Bouncy & Elastic", sub: "Resp: 0.42s · Damp: 0.65", engine: "fluid", resp: 0.42, damp: 0.65, icon: "󰑮" }
                            ]

                            Rectangle {
                                Layout.fillWidth: true
                                height: 68
                                radius: root.rad(10)
                                readonly property bool isSelected: (NexaUI.NexaMotion.physicsEngine === "classic" && modelData.id === "classic")
                                    || (NexaUI.NexaMotion.physicsEngine === "fluid" && NexaUI.NexaMotion.preset === modelData.id)
                                color: isSelected ? NexaUI.NexaColors.primaryContainer : (cHover.containsMouse ? NexaUI.NexaColors.surfaceContainerHighest : NexaUI.NexaColors.surfaceContainerHigh)
                                border.width: isSelected ? 1.5 : NexaUI.NexaTokens.borderThin
                                border.color: isSelected ? NexaUI.NexaColors.primary : NexaUI.NexaColors.border

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 4

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 8

                                        Text {
                                            text: modelData.icon
                                            font.family: NexaUI.NexaTypography.familyIcon
                                            font.pixelSize: 18
                                            color: isSelected ? NexaUI.NexaColors.primary : NexaUI.NexaColors.text
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.name
                                            font.family: NexaUI.NexaTypography.familyBody
                                            font.pixelSize: 12
                                            font.bold: true
                                            elide: Text.ElideRight
                                            color: isSelected ? NexaUI.NexaColors.onPrimaryContainer : NexaUI.NexaColors.text
                                        }
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.sub
                                        font.family: NexaUI.NexaTypography.familyBody
                                        font.pixelSize: 11
                                        font.features: NexaUI.NexaTypography.fontFeaturesTnum
                                        elide: Text.ElideRight
                                        color: isSelected ? NexaUI.NexaColors.primary : NexaUI.NexaColors.mutedText
                                    }
                                }

                                MouseArea {
                                    id: cHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        NexaUI.NexaMotion.savePhysicsEngine(modelData.engine, modelData.resp, modelData.damp, modelData.id);
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
                    color: NexaUI.NexaColors.surfaceContainer
                    border.width: NexaUI.NexaTokens.borderThin
                    border.color: NexaUI.NexaColors.border

                    ColumnLayout {
                        id: secCol
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 9

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "Section Motion Routing"
                                font.family: NexaUI.NexaTypography.familyBody
                                font.pixelSize: 13
                                font.bold: true
                                color: NexaUI.NexaColors.text
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: "Toggle per module"
                                font.family: NexaUI.NexaTypography.familyBody
                                font.pixelSize: 11
                                color: NexaUI.NexaColors.mutedText
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
                                    color: NexaUI.NexaMotion.useSpring(modelData.id) ? NexaUI.NexaColors.primaryContainer : NexaUI.NexaColors.surfaceContainerHigh
                                    border.width: 1
                                    border.color: NexaUI.NexaColors.border

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.icon
                                        font.family: NexaUI.NexaTypography.familyIcon
                                        font.pixelSize: 15
                                        color: NexaUI.NexaMotion.useSpring(modelData.id) ? NexaUI.NexaColors.primary : NexaUI.NexaColors.mutedText
                                    }
                                }

                                ColumnLayout {
                                    spacing: 1
                                    Text {
                                        text: modelData.name
                                        font.family: NexaUI.NexaTypography.familyBody
                                        font.pixelSize: 12
                                        font.bold: true
                                        color: NexaUI.NexaColors.text
                                    }
                                    Text {
                                        text: modelData.desc
                                        font.family: NexaUI.NexaTypography.familyBody
                                        font.pixelSize: 10
                                        color: NexaUI.NexaColors.mutedText
                                    }
                                }

                                Item { Layout.fillWidth: true }

                                NexaUI.NexaToggle {
                                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                                    checked: NexaUI.NexaMotion.useSpring(modelData.id)
                                    onToggled: (val) => {
                                        let s = Object.assign({}, NexaUI.NexaMotion.sections);
                                        s[modelData.id] = val;
                                        NexaUI.NexaMotion.saveMotionConfig(NexaUI.NexaMotion.springStiffness, NexaUI.NexaMotion.springDamping, NexaUI.NexaMotion.springMass, NexaUI.NexaMotion.preset, NexaUI.NexaMotion.enabled, s);
                                    }
                                }
                            }
                        }
                    }
                }

                // 4B. Fine-Tune Physics Parameters (Right Column ~44% width - Response & Damping Sliders)
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 420
                    Layout.fillHeight: true
                    implicitHeight: slidersCol.implicitHeight + 28
                    radius: root.rad(14)
                    color: NexaUI.NexaColors.surfaceContainer
                    border.width: NexaUI.NexaTokens.borderThin
                    border.color: NexaUI.NexaColors.border

                    ColumnLayout {
                        id: slidersCol
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 12

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            ColumnLayout {
                                spacing: 1
                                Text {
                                    text: "Fine-Tune Physics Parameters"
                                    font.family: NexaUI.NexaTypography.familyBody
                                    font.pixelSize: 13
                                    font.bold: true
                                    color: NexaUI.NexaColors.text
                                }
                                Text {
                                    text: NexaUI.NexaMotion.physicsEngine === "fluid" ? "󰀦 Apple Fluid Physics Active" : "󰅖 Disabled · Nexa Classic Active"
                                    font.family: NexaUI.NexaTypography.familyBody
                                    font.pixelSize: 10
                                    color: NexaUI.NexaMotion.physicsEngine === "fluid" ? NexaUI.NexaColors.primary : NexaUI.NexaColors.mutedText
                                }
                            }

                            Item { Layout.fillWidth: true }

                            NexaUI.NexaToggle {
                                checked: NexaUI.NexaMotion.physicsEngine === "fluid"
                                onToggled: (val) => {
                                    if (val) {
                                        NexaUI.NexaMotion.savePhysicsEngine("fluid", NexaUI.NexaMotion.physicsResponse || 0.30, NexaUI.NexaMotion.physicsDamping || 0.81, "snappy");
                                    } else {
                                        NexaUI.NexaMotion.savePhysicsEngine("classic", 0.44, 1.0, "classic");
                                    }
                                }
                            }
                        }

                        // 1. Response (Stiffness)
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            opacity: NexaUI.NexaMotion.physicsEngine === "fluid" ? 1.0 : 0.5
                            enabled: NexaUI.NexaMotion.physicsEngine === "fluid"

                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: "Response (Stiffness)"
                                    font.family: NexaUI.NexaTypography.familyBody
                                    font.pixelSize: 12
                                    font.weight: NexaUI.NexaTypography.weightSemiBold
                                    color: NexaUI.NexaColors.text
                                }
                                Item { Layout.fillWidth: true }
                                Text {
                                    text: NexaUI.NexaMotion.physicsResponse.toFixed(2) + "s"
                                    font.family: NexaUI.NexaTypography.familyBody
                                    font.pixelSize: 12
                                    font.weight: NexaUI.NexaTypography.weightSemiBold
                                    font.features: NexaUI.NexaTypography.fontFeaturesTnum
                                    color: NexaUI.NexaColors.primary
                                }
                            }

                            NexaUI.NexaSlider {
                                Layout.fillWidth: true
                                sliderHeight: 28
                                from: 0.20
                                to: 0.80
                                stepSize: 0.01
                                value: NexaUI.NexaMotion.physicsResponse
                                icon: "󱐋"
                                iconPosition: "left"
                                onMoved: (val) => {
                                    NexaUI.NexaMotion.savePhysicsEngine("fluid", val, NexaUI.NexaMotion.physicsDamping, NexaUI.NexaMotion.preset);
                                }
                            }
                        }

                        // 2. Damping (Friction)
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            opacity: NexaUI.NexaMotion.physicsEngine === "fluid" ? 1.0 : 0.5
                            enabled: NexaUI.NexaMotion.physicsEngine === "fluid"

                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: "Damping (Friction)"
                                    font.family: NexaUI.NexaTypography.familyBody
                                    font.pixelSize: 12
                                    font.weight: NexaUI.NexaTypography.weightSemiBold
                                    color: NexaUI.NexaColors.text
                                }
                                Item { Layout.fillWidth: true }
                                Text {
                                    text: NexaUI.NexaMotion.physicsDamping.toFixed(2)
                                    font.family: NexaUI.NexaTypography.familyBody
                                    font.pixelSize: 12
                                    font.weight: NexaUI.NexaTypography.weightSemiBold
                                    font.features: NexaUI.NexaTypography.fontFeaturesTnum
                                    color: NexaUI.NexaColors.primary
                                }
                            }

                            NexaUI.NexaSlider {
                                Layout.fillWidth: true
                                sliderHeight: 28
                                from: 0.50
                                to: 1.10
                                stepSize: 0.01
                                value: NexaUI.NexaMotion.physicsDamping
                                icon: "󰑮"
                                iconPosition: "left"
                                onMoved: (val) => {
                                    NexaUI.NexaMotion.savePhysicsEngine("fluid", NexaUI.NexaMotion.physicsResponse, val, NexaUI.NexaMotion.preset);
                                }
                            }
                        }

                        // 3. Global Animation Speed Factor
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: "Animation Speed (Pace)"
                                    font.family: NexaUI.NexaTypography.familyBody
                                    font.pixelSize: 12
                                    font.weight: NexaUI.NexaTypography.weightSemiBold
                                    color: NexaUI.NexaColors.text
                                }
                                Item { Layout.fillWidth: true }
                                Text {
                                    text: NexaUI.NexaMotion.animationSpeed.toFixed(1) + "x"
                                    font.family: NexaUI.NexaTypography.familyBody
                                    font.pixelSize: 12
                                    font.weight: NexaUI.NexaTypography.weightSemiBold
                                    font.features: NexaUI.NexaTypography.fontFeaturesTnum
                                    color: NexaUI.NexaColors.primary
                                }
                            }

                            NexaUI.NexaSlider {
                                Layout.fillWidth: true
                                sliderHeight: 28
                                from: 0.50
                                to: 2.50
                                stepSize: 0.10
                                value: NexaUI.NexaMotion.animationSpeed
                                icon: "󰓅"
                                iconPosition: "left"
                                onMoved: (val) => {
                                    NexaUI.NexaMotion.setAnimationSpeed(val);
                                }
                            }
                        }

                        Item { Layout.fillHeight: true }

                        // Interactive Engine Switcher button at the bottom of the card
                        Rectangle {
                            id: enginePill
                            Layout.fillWidth: true
                            height: 38
                            radius: root.rad(8)
                            color: engineHover.containsMouse ? NexaUI.NexaColors.surfaceContainerHighest : NexaUI.NexaColors.surfaceContainerHigh
                            border.width: 1
                            border.color: NexaUI.NexaMotion.physicsEngine === "fluid" ? NexaUI.NexaColors.primary : NexaUI.NexaColors.border

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 8
                                Text {
                                    text: NexaUI.NexaMotion.physicsEngine === "fluid" ? "󰀵" : "󰅖"
                                    font.family: NexaUI.NexaTypography.familyIcon
                                    font.pixelSize: 15
                                    color: NexaUI.NexaMotion.physicsEngine === "fluid" ? NexaUI.NexaColors.primary : NexaUI.NexaColors.mutedText
                                }
                                Text {
                                    text: NexaUI.NexaMotion.physicsEngine === "fluid"
                                        ? ("Active Engine: APPLE FLUID (" + NexaUI.NexaMotion.preset.toUpperCase() + ") · Click to Disable")
                                        : "Active Engine: NEXA CLASSIC EASING · Click to Enable Fluid"
                                    font.family: NexaUI.NexaTypography.familyBody
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                    color: NexaUI.NexaMotion.physicsEngine === "fluid" ? NexaUI.NexaColors.onSurface : NexaUI.NexaColors.mutedText
                                }
                            }

                            MouseArea {
                                id: engineHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (NexaUI.NexaMotion.physicsEngine === "fluid") {
                                        NexaUI.NexaMotion.savePhysicsEngine("classic", 0.44, 1.0, "classic");
                                    } else {
                                        NexaUI.NexaMotion.savePhysicsEngine("fluid", NexaUI.NexaMotion.physicsResponse || 0.30, NexaUI.NexaMotion.physicsDamping || 0.81, "snappy");
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ────────────────────────────────────────────────────────────
            // 5. 3D OPTICAL LIGHTING & PHYSICAL SHADOW CONTROLS
            // ────────────────────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: opticsCol.implicitHeight + 28
                radius: root.rad(14)
                color: NexaUI.NexaColors.surfaceContainer
                border.width: NexaUI.NexaTokens.borderThin
                border.color: NexaUI.NexaColors.border

                ColumnLayout {
                    id: opticsCol
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 14

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        ColumnLayout {
                            spacing: 1
                            Text {
                                text: "3D Optical Lighting & Physical Shadows"
                                font.family: NexaUI.NexaTypography.familyBody
                                font.pixelSize: 13
                                font.bold: true
                                color: NexaUI.NexaColors.text
                            }
                            Text {
                                readonly property bool is3D: NexaUI.NexaOptics.specularHighlight || NexaUI.NexaOptics.surface3DGradient || NexaUI.NexaOptics.contactShadow
                                text: is3D ? "󱐋 Tactile 3D Glass Active (Convex Depth & GPU Shadows)" : "󰅖 3D Effects Disabled (Flat 2D UI)"
                                font.family: NexaUI.NexaTypography.familyBody
                                font.pixelSize: 10
                                color: is3D ? NexaUI.NexaColors.primary : NexaUI.NexaColors.mutedText
                            }
                        }

                        Item { Layout.fillWidth: true }

                        NexaUI.NexaToggle {
                            readonly property bool is3D: NexaUI.NexaOptics.specularHighlight || NexaUI.NexaOptics.surface3DGradient || NexaUI.NexaOptics.contactShadow
                            checked: is3D
                            onToggled: (val) => {
                                if (val) {
                                    NexaUI.NexaOptics.saveOpticsConfig(true, 0.28, true, 1.0, true, 0.75);
                                } else {
                                    NexaUI.NexaOptics.saveOpticsConfig(false, 0.0, false, 0.0, false, 0.0);
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 14
                        opacity: (NexaUI.NexaOptics.specularHighlight || NexaUI.NexaOptics.surface3DGradient || NexaUI.NexaOptics.contactShadow) ? 1.0 : 0.45
                        enabled: (NexaUI.NexaOptics.specularHighlight || NexaUI.NexaOptics.surface3DGradient || NexaUI.NexaOptics.contactShadow)

                        // 1. Top Specular Light Highlight
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: specCol.implicitHeight + 20
                            radius: root.rad(10)
                            color: NexaUI.NexaColors.surfaceContainerHigh
                            border.width: 1
                            border.color: NexaUI.NexaColors.border

                            ColumnLayout {
                                id: specCol
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 8

                                RowLayout {
                                    Layout.fillWidth: true
                                    ColumnLayout {
                                        spacing: 1
                                        Text {
                                            text: "Top Specular Highlight"
                                            font.family: NexaUI.NexaTypography.familyBody
                                            font.pixelSize: 12
                                            font.bold: true
                                            color: NexaUI.NexaColors.text
                                        }
                                        Text {
                                            text: "1px overhead light reflection"
                                            font.family: NexaUI.NexaTypography.familyBody
                                            font.pixelSize: 10
                                            color: NexaUI.NexaColors.mutedText
                                        }
                                    }
                                    Item { Layout.fillWidth: true }
                                    NexaUI.NexaToggle {
                                        checked: NexaUI.NexaOptics.specularHighlight
                                        onToggled: (val) => {
                                            NexaUI.NexaOptics.saveOpticsConfig(val, NexaUI.NexaOptics.specularIntensity, NexaUI.NexaOptics.surface3DGradient, NexaUI.NexaOptics.gradientIntensity, NexaUI.NexaOptics.contactShadow, NexaUI.NexaOptics.shadowBlurFactor);
                                        }
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    Text {
                                        text: "Intensity"
                                        font.family: NexaUI.NexaTypography.familyBody
                                        font.pixelSize: 11
                                        color: NexaUI.NexaColors.mutedText
                                    }
                                    Item { Layout.fillWidth: true }
                                    Text {
                                        text: Math.round(NexaUI.NexaOptics.specularIntensity * 100) + "%"
                                        font.family: NexaUI.NexaTypography.familyBody
                                        font.pixelSize: 11
                                        font.bold: true
                                        color: NexaUI.NexaColors.primary
                                    }
                                }

                                NexaUI.NexaSlider {
                                    Layout.fillWidth: true
                                    sliderHeight: 24
                                    from: 0.05
                                    to: 0.60
                                    stepSize: 0.01
                                    value: NexaUI.NexaOptics.specularIntensity
                                    enabled: NexaUI.NexaOptics.specularHighlight
                                    onMoved: (val) => {
                                        NexaUI.NexaOptics.saveOpticsConfig(NexaUI.NexaOptics.specularHighlight, val, NexaUI.NexaOptics.surface3DGradient, NexaUI.NexaOptics.gradientIntensity, NexaUI.NexaOptics.contactShadow, NexaUI.NexaOptics.shadowBlurFactor);
                                    }
                                }
                            }
                        }

                        // 2. 3D Surface Depth Gradient
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: gradCol.implicitHeight + 20
                            radius: root.rad(10)
                            color: NexaUI.NexaColors.surfaceContainerHigh
                            border.width: 1
                            border.color: NexaUI.NexaColors.border

                            ColumnLayout {
                                id: gradCol
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 8

                                RowLayout {
                                    Layout.fillWidth: true
                                    ColumnLayout {
                                        spacing: 1
                                        Text {
                                            text: "3D Surface Depth Gradient"
                                            font.family: NexaUI.NexaTypography.familyBody
                                            font.pixelSize: 12
                                            font.bold: true
                                            color: NexaUI.NexaColors.text
                                        }
                                        Text {
                                            text: "Convex tactile depth vs flat color"
                                            font.family: NexaUI.NexaTypography.familyBody
                                            font.pixelSize: 10
                                            color: NexaUI.NexaColors.mutedText
                                        }
                                    }
                                    Item { Layout.fillWidth: true }
                                    NexaUI.NexaToggle {
                                        checked: NexaUI.NexaOptics.surface3DGradient
                                        onToggled: (val) => {
                                            NexaUI.NexaOptics.saveOpticsConfig(NexaUI.NexaOptics.specularHighlight, NexaUI.NexaOptics.specularIntensity, val, NexaUI.NexaOptics.gradientIntensity, NexaUI.NexaOptics.contactShadow, NexaUI.NexaOptics.shadowBlurFactor);
                                        }
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    Text {
                                        text: "Depth Amount"
                                        font.family: NexaUI.NexaTypography.familyBody
                                        font.pixelSize: 11
                                        color: NexaUI.NexaColors.mutedText
                                    }
                                    Item { Layout.fillWidth: true }
                                    Text {
                                        text: Math.round(NexaUI.NexaOptics.gradientIntensity * 100) + "%"
                                        font.family: NexaUI.NexaTypography.familyBody
                                        font.pixelSize: 11
                                        font.bold: true
                                        color: NexaUI.NexaColors.primary
                                    }
                                }

                                NexaUI.NexaSlider {
                                    Layout.fillWidth: true
                                    sliderHeight: 24
                                    from: 0.10
                                    to: 1.00
                                    stepSize: 0.05
                                    value: NexaUI.NexaOptics.gradientIntensity
                                    enabled: NexaUI.NexaOptics.surface3DGradient
                                    onMoved: (val) => {
                                        NexaUI.NexaOptics.saveOpticsConfig(NexaUI.NexaOptics.specularHighlight, NexaUI.NexaOptics.specularIntensity, NexaUI.NexaOptics.surface3DGradient, val, NexaUI.NexaOptics.contactShadow, NexaUI.NexaOptics.shadowBlurFactor);
                                    }
                                }
                            }
                        }

                        // 3. Bottom Contact & Ambient Drop Shadow
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: shadCol.implicitHeight + 20
                            radius: root.rad(10)
                            color: NexaUI.NexaColors.surfaceContainerHigh
                            border.width: 1
                            border.color: NexaUI.NexaColors.border

                            ColumnLayout {
                                id: shadCol
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 8

                                RowLayout {
                                    Layout.fillWidth: true
                                    ColumnLayout {
                                        spacing: 1
                                        Text {
                                            text: "Bottom Contact & Drop Shadow"
                                            font.family: NexaUI.NexaTypography.familyBody
                                            font.pixelSize: 12
                                            font.bold: true
                                            color: NexaUI.NexaColors.text
                                        }
                                        Text {
                                            text: "Physical grounding floating in 3D"
                                            font.family: NexaUI.NexaTypography.familyBody
                                            font.pixelSize: 10
                                            color: NexaUI.NexaColors.mutedText
                                        }
                                    }
                                    Item { Layout.fillWidth: true }
                                    NexaUI.NexaToggle {
                                        checked: NexaUI.NexaOptics.contactShadow
                                        onToggled: (val) => {
                                            NexaUI.NexaOptics.saveOpticsConfig(NexaUI.NexaOptics.specularHighlight, NexaUI.NexaOptics.specularIntensity, NexaUI.NexaOptics.surface3DGradient, NexaUI.NexaOptics.gradientIntensity, val, NexaUI.NexaOptics.shadowBlurFactor);
                                        }
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    Text {
                                        text: "Shadow Blur"
                                        font.family: NexaUI.NexaTypography.familyBody
                                        font.pixelSize: 11
                                        color: NexaUI.NexaColors.mutedText
                                    }
                                    Item { Layout.fillWidth: true }
                                    Text {
                                        text: Math.round(NexaUI.NexaOptics.shadowBlurFactor * 100) + "%"
                                        font.family: NexaUI.NexaTypography.familyBody
                                        font.pixelSize: 11
                                        font.bold: true
                                        color: NexaUI.NexaColors.primary
                                    }
                                }

                                NexaUI.NexaSlider {
                                    Layout.fillWidth: true
                                    sliderHeight: 24
                                    from: 0.10
                                    to: 1.00
                                    stepSize: 0.05
                                    value: NexaUI.NexaOptics.shadowBlurFactor
                                    enabled: NexaUI.NexaOptics.contactShadow
                                    onMoved: (val) => {
                                        NexaUI.NexaOptics.saveOpticsConfig(NexaUI.NexaOptics.specularHighlight, NexaUI.NexaOptics.specularIntensity, NexaUI.NexaOptics.surface3DGradient, NexaUI.NexaOptics.gradientIntensity, NexaUI.NexaOptics.contactShadow, val);
                                    }
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
                color: NexaUI.NexaColors.surfaceContainer
                border.width: NexaUI.NexaTokens.borderThin
                border.color: NexaUI.NexaColors.border

                ColumnLayout {
                    id: hyprAnimCol
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 12

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "Hyprland Compositor Animation Profiles"
                            font.family: NexaUI.NexaTypography.familyBody
                            font.pixelSize: 13
                            font.bold: true
                            color: NexaUI.NexaColors.text
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: "Instant live cubic beziers & workspace transitions"
                            font.family: NexaUI.NexaTypography.familyBody
                            font.pixelSize: 11
                            color: NexaUI.NexaColors.mutedText
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
                                readonly property bool isSelected: NexaUI.NexaMotion.hyprAnimationProfile === modelData.id
                                color: isSelected ? NexaUI.NexaColors.primaryContainer : (animHover.containsMouse ? NexaUI.NexaColors.surfaceContainerHighest : NexaUI.NexaColors.surfaceContainerHigh)
                                border.width: isSelected ? 1.5 : NexaUI.NexaTokens.borderThin
                                border.color: isSelected ? NexaUI.NexaColors.primary : NexaUI.NexaColors.border

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 3

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 8

                                        Text {
                                            text: modelData.icon
                                            font.family: NexaUI.NexaTypography.familyIcon
                                            font.pixelSize: 16
                                            color: isSelected ? NexaUI.NexaColors.primary : NexaUI.NexaColors.text
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.name
                                            font.family: NexaUI.NexaTypography.familyBody
                                            font.pixelSize: 12
                                            font.bold: true
                                            elide: Text.ElideRight
                                            color: isSelected ? NexaUI.NexaColors.onPrimaryContainer : NexaUI.NexaColors.text
                                        }
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.sub
                                        font.family: NexaUI.NexaTypography.familyBody
                                        font.pixelSize: 10
                                        elide: Text.ElideRight
                                        color: isSelected ? NexaUI.NexaColors.primary : NexaUI.NexaColors.mutedText
                                    }
                                }

                                MouseArea {
                                    id: animHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        NexaUI.NexaMotion.saveHyprAnimationProfile(modelData.id);
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
