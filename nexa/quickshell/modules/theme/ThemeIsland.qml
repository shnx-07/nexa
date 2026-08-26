import QtQuick
import QtQuick.Layouts

import Quickshell
import Quickshell.Io

import "../../theme" as Nexa


Item {
    id: root


    // ============================================================
    // STATE
    // ============================================================

    property string selectedStyle: "preset"
    property string selectedPreset: ""
    property string selectedMode: "dark"

    property bool warmthEnabled: false

    property bool applying: false
    property bool presetsLoaded: false

    property var presets: []

    // Dynamic Matugen browser state.
    property var folderOptions: []
    property var subfolderOptions: []
    property var presetOptions: []

    property string selectedFolder: ""
    property string selectedSubfolder: ""
    property string browserPreset: ""

    // True when any dropdown popup is open.
    // Forwarded to Island.qml to keep the Island alive
    // while the user browses presets.
    readonly property bool themePopupOpen:
        modeDropdown.opened
        || styleDropdown.opened
        || warmthDropdown.opened
        || folderDropdown.opened
        || subfolderDropdown.opened
        || presetDropdown.opened


    readonly property string themeScript:
        "$HOME/.config/nexa/scripts/theme.sh"

    readonly property string nexad:
        "$HOME/.config/nexa/rust/target/release/nexad"


    // ============================================================
    // DROPDOWN DATA
    // ============================================================

    readonly property var appearanceModes: [
        {
            id: "dark",
            label: "Dark"
        },
        {
            id: "light",
            label: "Light"
        }
    ]


    readonly property var styles: [
        {
            id: "preset",
            label: "Preset"
        },
        {
            id: "wallpaperAccents",
            label: "Accents"
        },
        {
            id: "wallpaperFull",
            label: "Full"
        }
    ]


    readonly property var warmthModes: [
        {
            id: "off",
            label: "Off"
        },
        {
            id: "on",
            label: "On"
        }
    ]


    // ============================================================
    // PRESETS
    // ============================================================
    //
    // Presets are discovered dynamically from the Matugen-backed
    // theme engine. NEXA does not own a preset registry anymore.
    //
    // theme.sh presets-json is the only preset catalog API used here.
    // Adding/removing presets under Matugen therefore needs no QML
    // changes.
    // ============================================================


    // ============================================================
    // HELPERS
    // ============================================================

    function presetById(id) {
        for (let i = 0; i < root.presets.length; ++i) {
            if (root.presets[i].id === id)
                return root.presets[i]
        }

        return null
    }


    function colorForPreset(id, slot) {
        const preset =
            root.presetById(id)

        if (preset && preset.previews) {
            let colors =
                preset.previews[root.selectedMode]

            if (!colors || colors.length < 3)
                colors = preset.previews["default"]

            if (!colors || colors.length < 3) {
                const keys = Object.keys(preset.previews)

                if (keys.length > 0)
                    colors = preset.previews[keys[0]]
            }

            if (colors && colors.length > slot)
                return colors[slot]
        }

        return slot === 0
            ? Nexa.Theme.primary
            : slot === 1
                ? Nexa.Theme.secondary
                : Nexa.Theme.tertiary
    }


    function labelFor(list, id) {
        for (let i = 0; i < list.length; ++i) {
            if (list[i].id === id)
                return list[i].label
        }

        return id
    }


    function titleCase(value) {
        if (!value || value.length === 0)
            return ""

        return value.charAt(0).toUpperCase()
            + value.slice(1)
    }


    function categoryHasSubfolders(category) {
        let count = 0

        for (let i = 0; i < root.presets.length; ++i) {
            const preset = root.presets[i]

            if (preset.category !== category)
                continue

            ++count

            // Categorized Matugen themes expose paired variants.
            // Direct leaf folders such as extras expose standalone
            // JSON presets instead.
            if (
                preset.variants
                && preset.variants.indexOf("dark") >= 0
                && preset.variants.indexOf("light") >= 0
            )
                return true
        }

        return false
    }


    function rebuildFolderOptions() {
        const seen = {}
        const result = []

        for (let i = 0; i < root.presets.length; ++i) {
            const category = root.presets[i].category

            if (!category || seen[category])
                continue

            seen[category] = true

            result.push({
                id: category,
                label: category
            })
        }

        root.folderOptions = result
    }


    function rebuildSubfolderOptions() {
        const result = []

        if (
            !root.selectedFolder
            || !root.categoryHasSubfolders(root.selectedFolder)
        ) {
            root.subfolderOptions = []
            root.selectedSubfolder = ""
            rebuildPresetOptions()
            return
        }

        for (let i = 0; i < root.presets.length; ++i) {
            const preset = root.presets[i]

            if (preset.category !== root.selectedFolder)
                continue

            result.push({
                id: preset.name,
                label: preset.name
            })
        }

        root.subfolderOptions = result

        let valid = false

        for (let i = 0; i < result.length; ++i) {
            if (result[i].id === root.selectedSubfolder) {
                valid = true
                break
            }
        }

        if (!valid)
            root.selectedSubfolder =
                result.length > 0 ? result[0].id : ""

        rebuildPresetOptions()
    }


    function rebuildPresetOptions() {
        const result = []

        if (!root.selectedFolder) {
            root.presetOptions = []
            return
        }

        if (root.categoryHasSubfolders(root.selectedFolder)) {
            // The global Theme Mode dropdown already chooses Dark/Light.
            // Therefore the final dropdown represents the resolved leaf
            // of the selected folder/subfolder for the current mode.
            for (let i = 0; i < root.presets.length; ++i) {
                const preset = root.presets[i]

                if (
                    preset.category === root.selectedFolder
                    && preset.name === root.selectedSubfolder
                ) {
                    result.push({
                        id: preset.id,
                        label:
                            root.titleCase(root.selectedMode)
                            + " · "
                            + preset.name
                    })
                    break
                }
            }
        } else {
            // Direct-leaf categories (currently extras) have no
            // subfolder. Every JSON file is itself a selectable preset.
            for (let i = 0; i < root.presets.length; ++i) {
                const preset = root.presets[i]

                if (preset.category !== root.selectedFolder)
                    continue

                result.push({
                    id: preset.id,
                    label: preset.name
                })
            }
        }

        root.presetOptions = result

        let validBrowserPreset = false

        for (let i = 0; i < result.length; ++i) {
            if (result[i].id === root.browserPreset) {
                validBrowserPreset = true
                break
            }
        }

        if (!validBrowserPreset)
            root.browserPreset =
                result.length > 0 ? result[0].id : ""
    }


    function syncBrowserFromPreset() {
        // Always rebuild the folder list first so folderOptions
        // is populated before any index/validation logic runs.
        rebuildFolderOptions()

        const preset =
            root.presetById(root.selectedPreset)

        if (preset) {
            root.selectedFolder =
                preset.category

            root.selectedSubfolder =
                root.categoryHasSubfolders(preset.category)
                ? preset.name
                : ""

            root.browserPreset =
                preset.id
        } else if (root.folderOptions.length > 0) {
            root.selectedFolder =
                root.folderOptions[0].id

            root.selectedSubfolder = ""
        }

        rebuildSubfolderOptions()
        rebuildPresetOptions()
    }


    function selectFolder(folder) {
        if (
            root.applying
            || !root.presetsLoaded
            || root.selectedFolder === folder
        )
            return

        root.selectedFolder = folder
        root.selectedSubfolder = ""

        rebuildSubfolderOptions()
    }


    function selectSubfolder(subfolder) {
        if (
            root.applying
            || !root.presetsLoaded
            || !root.categoryHasSubfolders(root.selectedFolder)
            || root.selectedSubfolder === subfolder
        )
            return

        root.selectedSubfolder = subfolder

        rebuildPresetOptions()
    }



    // ============================================================
    // PRESET
    // ============================================================

    function selectPreset(presetId) {
        if (
            root.applying
            || !root.presetsLoaded
            || !presetId
        )
            return

        if (root.selectedPreset === presetId)
            return

        root.browserPreset =
            presetId

        root.selectedPreset =
            presetId


        applyProcess.command = [
            "sh",
            "-c",
            root.themeScript
            + " preset "
            + "'" + presetId + "'"
            + " && "
            + root.themeScript
            + " apply"
        ]

        applyProcess.running = true
    }



    // ============================================================
    // STYLE
    // ============================================================

    function selectStyle(style) {
        if (root.selectedStyle === style)
            return

        if (root.applying)
            return


        // Update frontend immediately.
        root.selectedStyle =
            style


        applyProcess.command = [
            "sh",
            "-c",
            root.themeScript
            + " style "
            + style
            + " && "
            + root.themeScript
            + " apply"
        ]

        applyProcess.running = true
    }


    // ============================================================
    // APPEARANCE
    // ============================================================

    function selectMode(mode) {
        if (root.selectedMode === mode)
            return

        if (root.applying)
            return


        // Update frontend immediately.
        root.selectedMode =
            mode

        // Refresh the final Matugen leaf shown by the preset browser.
        rebuildPresetOptions()


        applyProcess.command = [
            "sh",
            "-c",
            root.themeScript
            + " mode "
            + mode
            + " && "
            + root.themeScript
            + " apply"
        ]

        applyProcess.running = true
    }


    // ============================================================
    // WALLPAPER WARMTH
    // ============================================================

    function setWarmth(enabled) {
        if (root.warmthEnabled === enabled)
            return

        if (root.applying)
            return


        // Update frontend immediately.
        root.warmthEnabled =
            enabled


        if (enabled) {
            warmthProcess.command = [
                "sh",
                "-c",
                root.nexad
                + " screenTemp mode wallpaper"
                + " && "
                + root.nexad
                + " screenTemp enable"
            ]
        } else {
            warmthProcess.command = [
                "sh",
                "-c",
                root.nexad
                + " screenTemp disable"
            ]
        }


        warmthProcess.running = true
    }


    // ============================================================
    // THEME BACKEND STATUS
    // ============================================================

    Process {
        id: statusProcess

        command: [
            "sh",
            "-c",
            root.themeScript + " status"
        ]


        stdout: StdioCollector {
            onStreamFinished: {
                const lines =
                    text.split("\n")


                for (let i = 0; i < lines.length; ++i) {
                    const line =
                        lines[i].trim()


                    if (line.startsWith("Style")) {
                        const separator =
                            line.indexOf(":")

                        if (separator >= 0) {
                            root.selectedStyle =
                                line
                                .substring(separator + 1)
                                .trim()
                        }
                    }


                    if (line.startsWith("Preset")) {
                        const separator =
                            line.indexOf(":")

                        if (separator >= 0) {
                            root.selectedPreset =
                                line
                                .substring(separator + 1)
                                .trim()
                        }
                    }


                    if (line.startsWith("Mode")) {
                        const separator =
                            line.indexOf(":")

                        if (separator >= 0) {
                            root.selectedMode =
                                line
                                .substring(separator + 1)
                                .trim()
                        }
                    }
                }


                Qt.callLater(
                    root.syncBrowserFromPreset
                )
            }
        }
    }


    // ============================================================
    // SCREEN TEMPERATURE STATUS
    // ============================================================

    Process {
        id: warmthStatusProcess

        command: [
            "sh",
            "-c",
            root.nexad + " screenTemp info"
        ]


        stdout: StdioCollector {
            onStreamFinished: {
                const output =
                    text.trim()

                if (output.length === 0)
                    return


                try {
                    const state =
                        JSON.parse(output)

                    root.warmthEnabled =
                        state.enabled === true
                        && state.mode === "wallpaper"

                } catch (error) {
                    console.warn(
                        "ThemeIsland: failed to parse screenTemp status:",
                        error
                    )
                }
            }
        }
    }


    // ============================================================
    // MATUGEN PRESET CATALOG
    // ============================================================

    Process {
        id: presetCatalogProcess

        command: [
            "sh",
            "-c",
            root.themeScript + " presets-json"
        ]


        stdout: StdioCollector {
            onStreamFinished: {
                const output =
                    text.trim()

                if (output.length === 0) {
                    console.warn(
                        "ThemeIsland: empty preset catalog"
                    )

                    root.presets = []
                    root.presetsLoaded = true
                    statusProcess.running = true
                    return
                }


                try {
                    const catalog =
                        JSON.parse(output)

                    root.presets =
                        Array.isArray(catalog)
                        ? catalog
                        : []

                    root.presetsLoaded = true

                } catch (error) {
                    console.warn(
                        "ThemeIsland: failed to parse Matugen preset catalog:",
                        error
                    )

                    root.presets = []
                    root.presetsLoaded = true
                }


                // Load persisted theme state only after the dynamic
                // catalog exists so selectedIndex can resolve safely.
                statusProcess.running = true
            }
        }
    }


    // ============================================================
    // APPLY PROCESS
    // ============================================================

    Process {
        id: applyProcess

        property bool wasRunning: false


        onRunningChanged: {
            if (running) {
                root.applying = true
                wasRunning = true
                return
            }


            if (wasRunning) {
                root.applying = false
                wasRunning = false

                statusProcess.running = true
            }
        }
    }


    // ============================================================
    // WARMTH PROCESS
    // ============================================================

    Process {
        id: warmthProcess

        property bool wasRunning: false


        onRunningChanged: {
            if (running) {
                root.applying = true
                wasRunning = true
                return
            }


            if (wasRunning) {
                root.applying = false
                wasRunning = false

                warmthStatusProcess.running = true
            }
        }
    }


    // ============================================================
    // INITIAL LOAD
    // ============================================================

    Component.onCompleted: {
        presetCatalogProcess.running = true
        warmthStatusProcess.running = true
    }


    // ============================================================
    // REUSABLE DROPDOWN
    // ============================================================

    component NexaDropdown: Item {
        id: dropdown

        property var model: []
        property string currentValue: ""

        property bool enabled: true
        property bool opened: false

        property string disabledText: ""

        // "below" | "left" | "right"
        // Controls which side the floating popup opens on.
        property string popupSide: "below"

        signal selected(string value)


        readonly property string currentLabel:
            !dropdown.enabled
            && dropdown.disabledText.length > 0
            ? dropdown.disabledText
            : root.labelFor(
                dropdown.model,
                dropdown.currentValue
            )


        Rectangle {
            id: button

            anchors.fill:
                parent

            radius:
                Nexa.Theme.radiusSm

            color: {
                if (!dropdown.enabled)
                    return Nexa.Theme.cardBackground

                if (buttonMouse.pressed)
                    return Nexa.Theme.pressed

                if (buttonMouse.containsMouse)
                    return Nexa.Theme.hover

                return Nexa.Theme.cardBackground
            }

            border.width:
                Nexa.Theme.borderThin

            border.color:
                dropdown.opened
                ? Nexa.Theme.primary
                : buttonMouse.containsMouse
                    && dropdown.enabled
                    ? Nexa.Theme.borderStrong
                    : Nexa.Theme.border

            opacity:
                dropdown.enabled
                ? 1.0
                : Nexa.Theme.opacityDisabled

            Behavior on color {
                ColorAnimation {
                    duration:
                        Nexa.Theme.animationFast
                }
            }

            Row {
                anchors {
                    fill: parent
                    leftMargin:
                        Nexa.Theme.spacingSm
                    rightMargin:
                        Nexa.Theme.spacingSm
                }

                spacing:
                    Nexa.Theme.spacingXs

                Text {
                    anchors.verticalCenter:
                        parent.verticalCenter

                    width:
                        parent.width
                        - arrowText.width
                        - parent.spacing

                    text:
                        dropdown.currentLabel

                    elide:
                        Text.ElideRight

                    horizontalAlignment:
                        Text.AlignHCenter

                    color:
                        Nexa.Theme.text

                    font {
                        family:
                            Nexa.Theme.fontFamily
                        pixelSize:
                            Nexa.Theme.fontSizeSm
                        weight:
                            Nexa.Theme.fontWeightMedium
                    }
                }

                Text {
                    id: arrowText

                    anchors.verticalCenter:
                        parent.verticalCenter

                    text:
                        dropdown.opened
                        ? "⌃"
                        : "⌄"

                    color:
                        Nexa.Theme.mutedText

                    font {
                        family:
                            Nexa.Theme.fontFamily
                        pixelSize:
                            Nexa.Theme.fontSizeXs
                        weight:
                            Nexa.Theme.fontWeightDemiBold
                    }
                }
            }

            MouseArea {
                id: buttonMouse

                anchors.fill:
                    parent

                enabled:
                    dropdown.enabled

                hoverEnabled:
                    true

                cursorShape:
                    dropdown.enabled
                    ? Qt.PointingHandCursor
                    : Qt.ArrowCursor

                onClicked: {
                    dropdown.opened =
                        !dropdown.opened

                    if (dropdown.opened)
                        dropdownPopup.anchor.updateAnchor()
                }
            }
        }


        // A real Quickshell popup surface instead of an Item child.
        // This lets the menu extend outside the Dynamic Island bounds.
        PopupWindow {
            id: dropdownPopup

            anchor.item:
                button

            anchor.rect.x: {
                if (dropdown.popupSide === "left")
                    return -(Math.max(dropdown.width, 150) + 4)

                if (dropdown.popupSide === "right")
                    return dropdown.width + 4

                return 0
            }

            anchor.rect.y: {
                if (dropdown.popupSide === "left"
                    || dropdown.popupSide === "right")
                    return 0

                return button.height + 4
            }

            implicitWidth:
                Math.max(dropdown.width, 150)

            implicitHeight:
                Math.min(
                    dropdown.model.length * 30
                    + Nexa.Theme.spacingXs * 2,
                    260
                )

            visible:
                dropdown.opened
                && dropdown.enabled
                && dropdown.model.length > 0

            grabFocus:
                true

            color:
                "transparent"

            onVisibleChanged: {
                if (!visible && dropdown.opened)
                    dropdown.opened = false
            }

            Rectangle {
                anchors.fill:
                    parent

                radius:
                    Nexa.Theme.radiusSm

                color:
                    Nexa.Theme.popupBackground

                border.width:
                    Nexa.Theme.borderThin

                border.color:
                    Nexa.Theme.borderStrong

                clip:
                    true

                ListView {
                    id: popupList

                    anchors {
                        fill: parent
                        margins:
                            Nexa.Theme.spacingXs
                    }

                    model:
                        dropdown.model

                    spacing: 0

                    clip:
                        true

                    boundsBehavior:
                        Flickable.StopAtBounds

                    delegate: Rectangle {
                        id: option

                        required property var modelData

                        width:
                            popupList.width

                        height: 30

                        radius:
                            Nexa.Theme.radiusXs

                        readonly property bool selectedOption:
                            dropdown.currentValue
                            === modelData.id

                        color:
                            selectedOption
                            ? Nexa.Theme.hoverStrong
                            : optionMouse.containsMouse
                                ? Nexa.Theme.hover
                                : "transparent"

                        Text {
                            anchors.centerIn:
                                parent

                            width:
                                parent.width
                                - Nexa.Theme.spacingSm * 2

                            text:
                                option.modelData.label

                            elide:
                                Text.ElideRight

                            horizontalAlignment:
                                Text.AlignHCenter

                            color:
                                option.selectedOption
                                ? Nexa.Theme.primary
                                : Nexa.Theme.text

                            font {
                                family:
                                    Nexa.Theme.fontFamily
                                pixelSize:
                                    Nexa.Theme.fontSizeXs
                                weight:
                                    option.selectedOption
                                    ? Nexa.Theme.fontWeightDemiBold
                                    : Nexa.Theme.fontWeightMedium
                            }
                        }

                        MouseArea {
                            id: optionMouse

                            anchors.fill:
                                parent

                            hoverEnabled:
                                true

                            cursorShape:
                                Qt.PointingHandCursor

                            onClicked: {
                                dropdown.opened = false
                                dropdown.selected(
                                    option.modelData.id
                                )
                            }
                        }
                    }
                }
            }
        }
    }


    // ============================================================
    // PAGE
    // ============================================================

    ColumnLayout {
        anchors.fill:
            parent

        spacing:
            Nexa.Theme.spacingSm


        // ========================================================
        // LIVE THEME PREVIEW
        // ========================================================

        Rectangle {
            id: preview

            Layout.fillWidth:
                true

            Layout.preferredHeight:
                118

            Layout.maximumHeight:
                118

            radius:
                Nexa.Theme.radiusMd

            color:
                Nexa.Theme.background

            border.width:
                Nexa.Theme.borderThin

            border.color:
                Nexa.Theme.border

            clip:
                true


            Rectangle {
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                }

                height: 30

                color:
                    Nexa.Theme.surfaceContainer


                Row {
                    anchors {
                        left: parent.left
                        verticalCenter:
                            parent.verticalCenter

                        leftMargin:
                            Nexa.Theme.spacingMd
                    }

                    spacing:
                        Nexa.Theme.spacingXs


                    Repeater {
                        model: [
                            Nexa.Theme.error,
                            Nexa.Theme.warning,
                            Nexa.Theme.success
                        ]


                        Rectangle {
                            required property var modelData

                            width: 7
                            height: 7

                            radius:
                                width / 2

                            color:
                                modelData
                        }
                    }
                }


                Text {
                    anchors.centerIn:
                        parent

                    text:
                        String(root.selectedPreset)
                            .replace(/-/g, " ")

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
            }


            Rectangle {
                anchors {
                    left: parent.left
                    top: parent.top
                    bottom: parent.bottom

                    leftMargin:
                        Nexa.Theme.spacingMd

                    topMargin: 42

                    bottomMargin:
                        Nexa.Theme.spacingMd
                }

                width:
                    parent.width * 0.30

                radius:
                    Nexa.Theme.radiusSm

                color:
                    Nexa.Theme.surfaceContainerHigh


                Column {
                    anchors {
                        fill: parent

                        margins:
                            Nexa.Theme.spacingSm
                    }

                    spacing: 6


                    Rectangle {
                        width:
                            parent.width * 0.76

                        height: 6

                        radius:
                            Nexa.Theme.radiusPill

                        color:
                            Nexa.Theme.primary
                    }


                    Rectangle {
                        width:
                            parent.width

                        height: 4

                        radius:
                            Nexa.Theme.radiusPill

                        color:
                            Nexa.Theme.outlineVariant
                    }


                    Rectangle {
                        width:
                            parent.width * 0.72

                        height: 4

                        radius:
                            Nexa.Theme.radiusPill

                        color:
                            Nexa.Theme.outlineVariant
                    }


                    Item {
                        width: 1
                        height: 1
                    }


                    Row {
                        spacing:
                            Nexa.Theme.spacingXs


                        Repeater {
                            model: [
                                Nexa.Theme.primary,
                                Nexa.Theme.secondary,
                                Nexa.Theme.tertiary
                            ]


                            Rectangle {
                                required property var modelData

                                width: 18
                                height: 18

                                radius:
                                    Nexa.Theme.radiusXs

                                color:
                                    modelData
                            }
                        }
                    }
                }
            }


            Rectangle {
                anchors {
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom

                    leftMargin:
                        parent.width * 0.34

                    rightMargin:
                        Nexa.Theme.spacingMd

                    bottomMargin:
                        Nexa.Theme.spacingMd
                }

                height: 64

                radius:
                    Nexa.Theme.radiusSm

                color:
                    Nexa.Theme.surfaceContainerHigh


                Rectangle {
                    anchors {
                        left: parent.left
                        top: parent.top
                        bottom: parent.bottom
                    }

                    width: 5

                    radius:
                        Nexa.Theme.radiusPill

                    color:
                        Nexa.Theme.primary
                }


                Column {
                    anchors {
                        left: parent.left
                        verticalCenter:
                            parent.verticalCenter

                        leftMargin:
                            Nexa.Theme.spacingLg
                    }

                    spacing:
                        Nexa.Theme.spacingXs


                    Text {
                        text:
                            "NEXA"

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


                    Text {
                        text: {
                            if (root.selectedStyle === "preset")
                                return "Preset theme"

                            if (root.selectedStyle === "wallpaperAccents")
                                return "Wallpaper accents"

                            return "Full wallpaper · "
                                + root.labelFor(
                                    root.appearanceModes,
                                    root.selectedMode
                                )
                        }

                        color:
                            Nexa.Theme.mutedText

                        font {
                            family:
                                Nexa.Theme.fontFamily

                            pixelSize:
                                Nexa.Theme.fontSizeXs
                        }
                    }
                }


                Row {
                    anchors {
                        right: parent.right
                        verticalCenter:
                            parent.verticalCenter

                        rightMargin:
                            Nexa.Theme.spacingMd
                    }

                    spacing:
                        Nexa.Theme.spacingXs


                    Repeater {
                        model: [
                            Nexa.Theme.primary,
                            Nexa.Theme.secondary,
                            Nexa.Theme.tertiary
                        ]


                        Rectangle {
                            required property var modelData

                            width: 22
                            height: 22

                            radius:
                                Nexa.Theme.radiusXs

                            color:
                                modelData
                        }
                    }
                }
            }
        }


        // ========================================================
        // MODE / SOURCE / WARMTH
        // ========================================================

        RowLayout {
            id: controlRow

            Layout.fillWidth:
                true

            Layout.preferredHeight:
                34

            spacing:
                Nexa.Theme.spacingSm

            z: 1000


            // ----------------------------------------------------
            // APPEARANCE
            // ----------------------------------------------------

            NexaDropdown {
                id: modeDropdown

                Layout.fillWidth:
                    true

                Layout.fillHeight:
                    true

                model:
                    root.appearanceModes

                currentValue:
                    root.selectedMode

                enabled:
                    !root.applying
                    && root.presetsLoaded


                onSelected: value => {
                    root.selectMode(value)
                }
            }


            // ----------------------------------------------------
            // THEME SOURCE
            // ----------------------------------------------------

            NexaDropdown {
                id: styleDropdown

                Layout.fillWidth:
                    true

                Layout.fillHeight:
                    true

                model:
                    root.styles

                currentValue:
                    root.selectedStyle

                enabled:
                    !root.applying


                onSelected: value => {
                    root.selectStyle(value)
                }
            }


            // ----------------------------------------------------
            // WALLPAPER WARMTH
            // ----------------------------------------------------

            NexaDropdown {
                id: warmthDropdown

                Layout.fillWidth:
                    true

                Layout.fillHeight:
                    true

                model:
                    root.warmthModes

                currentValue:
                    root.warmthEnabled
                    ? "on"
                    : "off"

                enabled:
                    !root.applying


                onSelected: value => {
                    root.setWarmth(
                        value === "on"
                    )
                }
            }
        }


        // ========================================================
        // MATUGEN PRESET BROWSER
        // ========================================================

        Rectangle {
            id: selector

            Layout.fillWidth:
                true

            Layout.fillHeight:
                true

            Layout.minimumHeight:
                105

            radius:
                Nexa.Theme.radiusMd

            color:
                Nexa.Theme.cardBackground

            border.width:
                Nexa.Theme.borderThin

            border.color:
                Nexa.Theme.border

            clip:
                false

            opacity:
                root.selectedStyle !== "wallpaperFull"
                ? 1.0
                : Nexa.Theme.opacityDisabled


            Behavior on opacity {
                NumberAnimation {
                    duration:
                        Nexa.Theme.animationFast
                }
            }


            ColumnLayout {
                anchors {
                    fill: parent

                    margins:
                        Nexa.Theme.spacingMd
                }

                spacing:
                    Nexa.Theme.spacingSm


                RowLayout {
                    Layout.fillWidth:
                        true

                    spacing:
                        Nexa.Theme.spacingSm


                    // ------------------------------------------------
                    // FOLDER / CATEGORY
                    // ------------------------------------------------

                    ColumnLayout {
                        Layout.fillWidth:
                            true

                        spacing: 4


                        Text {
                            Layout.fillWidth:
                                true

                            text:
                                "Folder"

                            color:
                                Nexa.Theme.mutedText

                            font {
                                family:
                                    Nexa.Theme.fontFamily

                                pixelSize:
                                    Nexa.Theme.fontSize2Xs

                                weight:
                                    Nexa.Theme.fontWeightMedium
                            }
                        }


                        NexaDropdown {
                            id: folderDropdown

                            Layout.fillWidth:
                                true

                            Layout.preferredHeight:
                                34

                            model:
                                root.folderOptions

                            currentValue:
                                root.selectedFolder

                            popupSide: "left"

                            enabled:
                                root.selectedStyle !== "wallpaperFull"
                                && root.presetsLoaded
                                && !root.applying


                            onSelected: value => {
                                root.selectFolder(value)
                            }
                        }
                    }


                    // ------------------------------------------------
                    // SUBFOLDER / FAMILY
                    // ------------------------------------------------

                    ColumnLayout {
                        Layout.fillWidth:
                            true

                        spacing: 4


                        Text {
                            Layout.fillWidth:
                                true

                            text:
                                "Subfolder"

                            color:
                                Nexa.Theme.mutedText

                            font {
                                family:
                                    Nexa.Theme.fontFamily

                                pixelSize:
                                    Nexa.Theme.fontSize2Xs

                                weight:
                                    Nexa.Theme.fontWeightMedium
                            }
                        }


                        NexaDropdown {
                            id: subfolderDropdown

                            Layout.fillWidth:
                                true

                            Layout.preferredHeight:
                                34

                            model:
                                root.subfolderOptions

                            currentValue:
                                root.selectedSubfolder

                            disabledText:
                                "Direct presets"

                            popupSide: "left"

                            enabled:
                                root.selectedStyle !== "wallpaperFull"
                                && root.presetsLoaded
                                && !root.applying
                                && root.categoryHasSubfolders(
                                    root.selectedFolder
                                )
                                && root.subfolderOptions.length > 0


                            onSelected: value => {
                                root.selectSubfolder(value)
                            }
                        }
                    }


                    // ------------------------------------------------
                    // FINAL PRESET
                    // ------------------------------------------------

                    ColumnLayout {
                        Layout.fillWidth:
                            true

                        spacing: 4


                        Text {
                            Layout.fillWidth:
                                true

                            text:
                                "Preset"

                            color:
                                Nexa.Theme.mutedText

                            font {
                                family:
                                    Nexa.Theme.fontFamily

                                pixelSize:
                                    Nexa.Theme.fontSize2Xs

                                weight:
                                    Nexa.Theme.fontWeightMedium
                            }
                        }


                        NexaDropdown {
                            id: presetDropdown

                            Layout.fillWidth:
                                true

                            Layout.preferredHeight:
                                34

                            model:
                                root.presetOptions

                            currentValue:
                                root.browserPreset

                            popupSide: "right"

                            enabled:
                                root.selectedStyle !== "wallpaperFull"
                                && root.presetsLoaded
                                && !root.applying
                                && root.presetOptions.length > 0


                            onSelected: value => {
                                root.browserPreset = value
                                root.selectPreset(value)
                            }
                        }
                    }
                }


                RowLayout {
                    Layout.fillWidth:
                        true

                    spacing:
                        Nexa.Theme.spacingSm


                    Text {
                        Layout.fillWidth:
                            true

                        text: {
                            if (!root.presetsLoaded)
                                return "Loading Matugen presets…"

                            if (!root.selectedFolder)
                                return "No Matugen presets found"

                            if (
                                root.categoryHasSubfolders(
                                    root.selectedFolder
                                )
                            ) {
                                return root.selectedFolder
                                    + " / "
                                    + root.selectedSubfolder
                                    + " / "
                                    + root.titleCase(
                                        root.selectedMode
                                    )
                            }

                            const preset =
                                root.presetById(
                                    root.browserPreset
                                )

                            return root.selectedFolder
                                + " / "
                                + (
                                    preset
                                    ? preset.name
                                    : "Select preset"
                                )
                        }

                        color:
                            Nexa.Theme.mutedText

                        elide:
                            Text.ElideRight

                        font {
                            family:
                                Nexa.Theme.fontFamily

                            pixelSize:
                                Nexa.Theme.fontSize2Xs
                        }
                    }


                    Row {
                        spacing: 5

                        visible:
                            root.browserPreset.length > 0


                        Repeater {
                            model: 3


                            Rectangle {
                                required property int index

                                width: 18
                                height: 18

                                radius:
                                    Nexa.Theme.radiusXs

                                color:
                                    root.colorForPreset(
                                        root.browserPreset,
                                        index
                                    )

                                border.width:
                                    Nexa.Theme.borderThin

                                border.color:
                                    Nexa.Theme.border
                            }
                        }
                    }


                    Text {
                        text:
                            root.applying
                            ? "Applying…"
                            : ""

                        color:
                            Nexa.Theme.primary

                        font {
                            family:
                                Nexa.Theme.fontFamily

                            pixelSize:
                                Nexa.Theme.fontSize2Xs

                            weight:
                                Nexa.Theme.fontWeightMedium
                        }
                    }
                }
            }
        }
    }
}
