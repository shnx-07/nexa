// pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../../NewNexaUI" as NexaUI

RowLayout {
    id: root

    spacing: 14

    required property var presets
    required property var categories
    property string selectedCategory: "All"
    property string searchQuery: ""

    property string stagedPreset: ""
    property string stagedStyle: "preset"
    property string stagedMode: "dark"
    property string selectedPreset: ""
    property string selectedStyle: ""
    property string selectedMode: "dark"

    property bool applying: false
    property bool isCurrentThemeActive: false

    property color stagedPrimary: NexaUI.NexaColors.primary
    property color stagedSecondary: NexaUI.NexaColors.secondary
    property color stagedTertiary: NexaUI.NexaColors.tertiary
    property string stagedPresetName: ""
    property string stagedPresetCategory: ""

    signal stagePresetRequested(string presetId, string mode)
    signal stageModeRequested(string mode)
    signal applyRequested()

    // Favorites Management
    property var favoritePresets: []
    readonly property string favoritesConfigPath: Quickshell.env("HOME") + "/.config/nexa/config/favorite_presets.json"

    FileView {
        id: favoritesFile
        path: root.favoritesConfigPath
        watchChanges: true
        printErrors: false

        onFileChanged: reload()
        onLoaded: {
            try {
                const list = JSON.parse(text());
                if (Array.isArray(list)) {
                    root.favoritePresets = list;
                }
            } catch (_) {}
        }
    }

    function isFavorite(presetId) {
        if (!root.favoritePresets || !presetId) return false;
        return root.favoritePresets.indexOf(presetId) >= 0;
    }

    function toggleFavorite(presetId) {
        if (!presetId) return;
        let arr = Array.isArray(root.favoritePresets) ? root.favoritePresets.slice() : [];
        const idx = arr.indexOf(presetId);
        if (idx >= 0) {
            arr.splice(idx, 1);
        } else {
            arr.push(presetId);
        }
        root.favoritePresets = arr;
        try {
            favoritesFile.setText(JSON.stringify(arr, null, 2));
        } catch (e) {
            console.warn("PresetsTab: failed to save favorites:", e);
        }
    }

    // Friendly Category Titles
    function formatCategoryTitle(cat) {
        if (!cat) return "";
        switch (cat) {
            case "Favorites": return "Starred Favorites";
            case "CuratedVault": return "Curated Vault";
            case "extras": return "Community Classics";
            case "LinuxHyprland": return "Hyprland & Linux";
            case "ColdArctic": return "Cold & Arctic";
            case "CyberTech": return "CyberTech & Neon";
            case "Nature": return "Nature & Earth";
            case "WarmCozy": return "Warm & Cozy";
            case "Cosmic": return "Cosmic & Space";
            case "SkyTime": return "Sky & Twilight";
            case "MinimalMonochrome": return "Minimal Monochrome";
            case "SoftCalm": return "Soft & Pastel";
            case "Mystic": return "Mystic & Violet";
            default: return cat;
        }
    }

    function categoryIcon(cat) {
        switch (cat) {
            case "Favorites": return "";
            case "CuratedVault": return "󰆼";
            case "extras": return "󰓹";
            case "LinuxHyprland": return "󰌽";
            case "ColdArctic": return "󰜗";
            case "CyberTech": return "󰒋";
            case "Nature": return "󰌪";
            case "WarmCozy": return "󰈸";
            case "Cosmic": return "󰛡";
            case "SkyTime": return "󰖔";
            case "MinimalMonochrome": return "󰝤";
            case "SoftCalm": return "󰄛";
            case "Mystic": return "󰚥";
            default: return "󰏘";
        }
    }

    function categoryCount(cat) {
        if (!root.presets) return 0;
        if (cat === "All") return root.presets.length;
        if (cat === "Favorites") return root.favoritePresets ? root.favoritePresets.length : 0;
        let count = 0;
        for (let i = 0; i < root.presets.length; ++i) {
            if (root.presets[i].category === cat) count++;
        }
        return count;
    }

    // Computed Decks (Grouped by Category)
    readonly property var groupedDecks: {
        if (!root.presets || root.presets.length === 0) return [];
        const q = root.searchQuery.trim().toLowerCase();
        const catFilter = root.selectedCategory;

        if (catFilter === "Favorites") {
            const favItems = [];
            for (let i = 0; i < root.presets.length; ++i) {
                const p = root.presets[i];
                if (!root.isFavorite(p.id)) continue;
                if (q.length > 0) {
                    const matchName = p.name && p.name.toLowerCase().indexOf(q) >= 0;
                    const matchCat = p.category && p.category.toLowerCase().indexOf(q) >= 0;
                    const matchId = p.id && p.id.toLowerCase().indexOf(q) >= 0;
                    if (!matchName && !matchCat && !matchId) continue;
                }
                favItems.push(p);
            }
            if (favItems.length === 0) return [];
            return [{
                category: "Favorites",
                title: "Starred Favorites",
                icon: "",
                items: favItems
            }];
        }

        const order = [
            "CuratedVault", "extras", "LinuxHyprland", "CyberTech", "ColdArctic",
            "Nature", "WarmCozy", "Cosmic", "SkyTime",
            "MinimalMonochrome", "SoftCalm", "Mystic"
        ];

        const groupsMap = {};
        for (let i = 0; i < root.presets.length; ++i) {
            const p = root.presets[i];
            const cat = p.category || "Other";
            if (!groupsMap[cat]) groupsMap[cat] = [];
            groupsMap[cat].push(p);
        }

        const decks = [];
        const seen = {};
        const allCats = order.concat(Object.keys(groupsMap));

        for (let c = 0; c < allCats.length; ++c) {
            const catKey = allCats[c];
            if (seen[catKey] || !groupsMap[catKey]) continue;
            seen[catKey] = true;

            if (catFilter !== "All" && catKey !== catFilter) continue;

            let items = groupsMap[catKey];
            const matched = [];
            for (let k = 0; k < items.length; ++k) {
                const p = items[k];

                if (q.length > 0) {
                    const matchName = p.name && p.name.toLowerCase().indexOf(q) >= 0;
                    const matchCat = p.category && p.category.toLowerCase().indexOf(q) >= 0;
                    const matchId = p.id && p.id.toLowerCase().indexOf(q) >= 0;
                    if (!matchName && !matchCat && !matchId) continue;
                }
                matched.push(p);
            }
            items = matched;

            if (items.length > 0) {
                decks.push({
                    category: catKey,
                    title: root.formatCategoryTitle(catKey),
                    icon: root.categoryIcon(catKey),
                    items: items
                });
            }
        }
        return decks;
    }

    readonly property int totalFilteredCount: {
        let total = 0;
        const d = root.groupedDecks || [];
        for (let i = 0; i < d.length; ++i) {
            total += d[i].items.length;
        }
        return total;
    }

    // ── LEFT: PRESETS EXPLORER ────────────────────────────────────────────────
    Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        radius: NexaUI.NexaTokens.radiusMd
        color: NexaUI.NexaColors.surfaceContainer
        border.width: NexaUI.NexaTokens.borderThin
        border.color: NexaUI.NexaColors.border
        clip: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 12

            // Top Search Bar
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 38
                radius: NexaUI.NexaTokens.radiusSm
                color: NexaUI.NexaColors.surfaceContainer
                border.width: NexaUI.NexaTokens.borderThin
                border.color: searchInput.activeFocus ? NexaUI.NexaColors.primary : NexaUI.NexaColors.border

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 8

                    Text {
                        text: "󰍉"
                        font.family: NexaUI.NexaTypography.familyIcon
                        font.pixelSize: 15
                        color: NexaUI.NexaColors.mutedText
                    }

                    TextInput {
                        id: searchInput
                        Layout.fillWidth: true
                        font.family: NexaUI.NexaTypography.familyBody
                        font.pixelSize: 12
                        color: NexaUI.NexaColors.text
                        clip: true
                        text: root.searchQuery
                        onTextChanged: root.searchQuery = text

                        Text {
                            anchors.fill: parent
                            visible: !searchInput.text && !searchInput.activeFocus
                            text: "Search " + root.presets.length + " presets..."
                            font.family: NexaUI.NexaTypography.familyBody
                            font.pixelSize: 12
                            color: NexaUI.NexaColors.mutedText
                        }
                    }

                    Text {
                        text: root.totalFilteredCount + "/" + root.presets.length
                        font.family: NexaUI.NexaTypography.familyBody
                        font.pixelSize: 11
                        color: NexaUI.NexaColors.mutedText
                    }
                }
            }

            // Main Explorer Area: Vertical Category Sub-Sidebar on Left + Cards Deck on Right
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 12

                // ── 1. Vertical Category Filter Sidebar (Left) ────────────────
                Rectangle {
                    Layout.preferredWidth: 185
                    Layout.fillHeight: true
                    radius: NexaUI.NexaTokens.radiusSm
                    color: NexaUI.NexaColors.surfaceContainer
                    border.width: NexaUI.NexaTokens.borderThin
                    border.color: NexaUI.NexaColors.border
                    clip: true

                    Flickable {
                        anchors.fill: parent
                        anchors.margins: 6
                        contentWidth: width
                        contentHeight: catColumn.implicitHeight
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        Column {
                            id: catColumn
                            width: parent.width
                            spacing: 3

                            // Top item: All Presets
                            Rectangle {
                                id: allItem
                                width: catColumn.width
                                height: 36
                                radius: NexaUI.NexaTokens.radiusXs

                                readonly property bool isSelected: root.selectedCategory === "All"

                                color: isSelected
                                    ? NexaUI.NexaColors.primaryContainer
                                    : (allMouse.containsMouse ? NexaUI.NexaColors.surfaceContainerHigh : "transparent")
                                border.width: isSelected ? 1 : 0
                                border.color: isSelected ? NexaUI.NexaColors.primary : "transparent"

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 6
                                    spacing: 6

                                    Text {
                                        text: "󰏘"
                                        font.family: NexaUI.NexaTypography.familyIcon
                                        font.pixelSize: 13
                                        color: allItem.isSelected ? NexaUI.NexaColors.onPrimaryContainer : NexaUI.NexaColors.mutedText
                                    }

                                    Text {
                                        text: "All Presets"
                                        font.family: NexaUI.NexaTypography.familyBody
                                        font.pixelSize: 11
                                        font.weight: allItem.isSelected ? NexaUI.NexaTypography.weightSemiBold : NexaUI.NexaTypography.weightRegular
                                        color: allItem.isSelected ? NexaUI.NexaColors.onPrimaryContainer : NexaUI.NexaColors.text
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }

                                    // Count Badge
                                    Rectangle {
                                        height: 18
                                        width: allCountText.implicitWidth + 8
                                        radius: 9
                                        color: allItem.isSelected ? Qt.rgba(NexaUI.NexaColors.primary.r, NexaUI.NexaColors.primary.g, NexaUI.NexaColors.primary.b, 0.25) : NexaUI.NexaColors.surfaceContainerHighest

                                        Text {
                                            id: allCountText
                                            anchors.centerIn: parent
                                            text: root.presets ? root.presets.length : 0
                                            font.family: NexaUI.NexaTypography.familyBody
                                            font.pixelSize: 9
                                            font.weight: NexaUI.NexaTypography.weightSemiBold
                                            color: allItem.isSelected ? NexaUI.NexaColors.onPrimaryContainer : NexaUI.NexaColors.mutedText
                                        }
                                    }
                                }

                                MouseArea {
                                    id: allMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.selectedCategory = "All"
                                }
                            }

                            // Favorites Filter Item
                            Rectangle {
                                id: favCategoryItem
                                width: catColumn.width
                                height: 36
                                radius: NexaUI.NexaTokens.radiusXs

                                readonly property bool isSelected: root.selectedCategory === "Favorites"
                                readonly property int count: root.favoritePresets ? root.favoritePresets.length : 0

                                color: isSelected
                                    ? NexaUI.NexaColors.primaryContainer
                                    : (favMouse.containsMouse ? NexaUI.NexaColors.surfaceContainerHigh : "transparent")
                                border.width: isSelected ? 1 : 0
                                border.color: isSelected ? NexaUI.NexaColors.primary : "transparent"

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 6
                                    spacing: 6

                                    Text {
                                        text: ""
                                        font.family: NexaUI.NexaTypography.familyIcon
                                        font.pixelSize: 13
                                        color: favCategoryItem.isSelected ? NexaUI.NexaColors.onPrimaryContainer : "#f59e0b"
                                    }

                                    Text {
                                        text: "Favorites"
                                        font.family: NexaUI.NexaTypography.familyBody
                                        font.pixelSize: 11
                                        font.weight: favCategoryItem.isSelected ? NexaUI.NexaTypography.weightSemiBold : NexaUI.NexaTypography.weightRegular
                                        color: favCategoryItem.isSelected ? NexaUI.NexaColors.onPrimaryContainer : NexaUI.NexaColors.text
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }

                                    // Count Badge
                                    Rectangle {
                                        height: 18
                                        width: favCountText.implicitWidth + 8
                                        radius: 9
                                        color: favCategoryItem.isSelected
                                            ? Qt.rgba(NexaUI.NexaColors.primary.r, NexaUI.NexaColors.primary.g, NexaUI.NexaColors.primary.b, 0.25)
                                            : (favCategoryItem.count > 0 ? Qt.rgba(0.96, 0.62, 0.04, 0.18) : NexaUI.NexaColors.surfaceContainerHighest)

                                        Text {
                                            id: favCountText
                                            anchors.centerIn: parent
                                            text: favCategoryItem.count
                                            font.family: NexaUI.NexaTypography.familyBody
                                            font.pixelSize: 9
                                            font.weight: NexaUI.NexaTypography.weightSemiBold
                                            color: favCategoryItem.isSelected
                                                ? NexaUI.NexaColors.onPrimaryContainer
                                                : (favCategoryItem.count > 0 ? "#f59e0b" : NexaUI.NexaColors.mutedText)
                                        }
                                    }
                                }

                                MouseArea {
                                    id: favMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.selectedCategory = "Favorites"
                                }
                            }

                            // Subtle Divider
                            Rectangle {
                                width: catColumn.width - 12
                                height: 1
                                x: 6
                                color: NexaUI.NexaColors.border
                                opacity: 0.6
                            }

                            // Category Collections
                            Repeater {
                                model: {
                                    const cats = [];
                                    for (let i = 0; i < root.categories.length; ++i) {
                                        const c = root.categories[i];
                                        if (c !== "All") cats.push(c);
                                    }
                                    return cats;
                                }

                                Rectangle {
                                    id: catItem
                                    required property var modelData
                                    width: catColumn.width
                                    height: 36
                                    radius: NexaUI.NexaTokens.radiusXs

                                    readonly property bool isSelected: root.selectedCategory === modelData
                                    readonly property int count: root.categoryCount(modelData)

                                    color: isSelected
                                        ? NexaUI.NexaColors.primaryContainer
                                        : (catItemMouse.containsMouse ? NexaUI.NexaColors.surfaceContainerHigh : "transparent")
                                    border.width: isSelected ? 1 : 0
                                    border.color: isSelected ? NexaUI.NexaColors.primary : "transparent"

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 8
                                        anchors.rightMargin: 6
                                        spacing: 6

                                        Text {
                                            text: root.categoryIcon(catItem.modelData)
                                            font.family: NexaUI.NexaTypography.familyIcon
                                            font.pixelSize: 13
                                            color: catItem.isSelected ? NexaUI.NexaColors.onPrimaryContainer : NexaUI.NexaColors.mutedText
                                        }

                                        Text {
                                            text: root.formatCategoryTitle(catItem.modelData)
                                            font.family: NexaUI.NexaTypography.familyBody
                                            font.pixelSize: 11
                                            font.weight: catItem.isSelected ? NexaUI.NexaTypography.weightSemiBold : NexaUI.NexaTypography.weightRegular
                                            color: catItem.isSelected ? NexaUI.NexaColors.onPrimaryContainer : NexaUI.NexaColors.text
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }

                                        // Count Badge
                                        Rectangle {
                                            height: 18
                                            width: catCountText.implicitWidth + 8
                                            radius: 9
                                            color: catItem.isSelected ? Qt.rgba(NexaUI.NexaColors.primary.r, NexaUI.NexaColors.primary.g, NexaUI.NexaColors.primary.b, 0.25) : NexaUI.NexaColors.surfaceContainerHighest

                                            Text {
                                                id: catCountText
                                                anchors.centerIn: parent
                                                text: catItem.count
                                                font.family: NexaUI.NexaTypography.familyBody
                                                font.pixelSize: 9
                                                font.weight: NexaUI.NexaTypography.weightSemiBold
                                                color: catItem.isSelected ? NexaUI.NexaColors.onPrimaryContainer : NexaUI.NexaColors.mutedText
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: catItemMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.selectedCategory = catItem.modelData
                                    }
                                }
                            }
                        }
                    }
                }

                // ── 2. Cards Deck / Stack (Right) ─────────────────────────────
                Flickable {
                    id: decksFlickable
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    contentWidth: width
                    contentHeight: decksColumn.implicitHeight + 20
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    Column {
                        id: decksColumn
                        width: decksFlickable.width
                        spacing: 16

                        Repeater {
                            model: root.groupedDecks

                            Column {
                                id: deckSection
                                required property var modelData
                                width: decksColumn.width
                                spacing: 8

                                // Deck Header
                                RowLayout {
                                    width: parent.width
                                    spacing: 8

                                    Row {
                                        spacing: 6
                                        Layout.alignment: Qt.AlignVCenter

                                        Text {
                                            text: deckSection.modelData.icon
                                            font.family: NexaUI.NexaTypography.familyIcon
                                            font.pixelSize: 14
                                            color: NexaUI.NexaColors.primary
                                        }

                                        Text {
                                            text: deckSection.modelData.title
                                            font.family: NexaUI.NexaTypography.familyBody
                                            font.pixelSize: 12
                                            font.weight: NexaUI.NexaTypography.weightBold
                                            color: NexaUI.NexaColors.text
                                        }
                                    }

                                    Rectangle {
                                        height: 16
                                        width: countText.implicitWidth + 8
                                        radius: 8
                                        color: NexaUI.NexaColors.surfaceContainerHighest

                                        Text {
                                            id: countText
                                            anchors.centerIn: parent
                                            text: deckSection.modelData.items.length
                                            font.family: NexaUI.NexaTypography.familyBody
                                            font.pixelSize: 9
                                            font.weight: NexaUI.NexaTypography.weightSemiBold
                                            color: NexaUI.NexaColors.mutedText
                                        }
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: 1
                                        color: NexaUI.NexaColors.border
                                        opacity: 0.5
                                    }
                                }

                                // Cards Stack
                                Grid {
                                    width: parent.width
                                    columns: width > 460 ? 2 : 1
                                    spacing: 8

                                    readonly property real itemWidth: columns === 2 ? ((width - spacing) / 2) : width

                                    Repeater {
                                        model: deckSection.modelData.items

                                        PresetCard {
                                            required property var modelData
                                            width: parent.itemWidth
                                            presetData: modelData
                                            stagedPresetId: root.stagedPreset
                                            activePresetId: root.selectedPreset
                                            activeStyle: root.selectedStyle
                                            currentMode: root.stagedMode
                                            isFavorited: root.isFavorite(modelData.id)
                                            onCardSelected: (id, mode) => root.stagePresetRequested(id, mode)
                                            onToggleFavoriteRequested: (id) => root.toggleFavorite(id)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Empty State for Favorites or Search
                    ColumnLayout {
                        anchors.centerIn: parent
                        visible: root.groupedDecks.length === 0
                        spacing: 10

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: root.selectedCategory === "Favorites" ? "" : "󰍉"
                            font.family: NexaUI.NexaTypography.familyIcon
                            font.pixelSize: 36
                            color: root.selectedCategory === "Favorites" ? "#f59e0b" : NexaUI.NexaColors.mutedText
                            opacity: 0.7
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: root.selectedCategory === "Favorites"
                                ? "No Favorite Presets Yet"
                                : "No Presets Found"
                            font.family: NexaUI.NexaTypography.familyBody
                            font.pixelSize: 14
                            font.weight: NexaUI.NexaTypography.weightSemiBold
                            color: NexaUI.NexaColors.text
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: root.selectedCategory === "Favorites"
                                ? "Click the star icon on any preset card to pin your favorites here"
                                : "Try searching with a different keyword"
                            font.family: NexaUI.NexaTypography.familyBody
                            font.pixelSize: 11
                            color: NexaUI.NexaColors.mutedText
                        }
                    }
                }
            }
        }
    }

    // ── RIGHT: LIVE PREVIEW HUB ───────────────────────────────────────────────
    Rectangle {
        Layout.preferredWidth: 320
        Layout.fillHeight: true
        radius: NexaUI.NexaTokens.radiusMd
        color: NexaUI.NexaColors.surfaceContainer
        border.width: NexaUI.NexaTokens.borderThin
        border.color: NexaUI.NexaColors.border

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "Live Preview"
                    font.family: NexaUI.NexaTypography.familyBody
                    font.pixelSize: 15
                    font.weight: NexaUI.NexaTypography.weightBold
                    color: NexaUI.NexaColors.text
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: root.stagedPresetCategory || "Preset"
                    font.family: NexaUI.NexaTypography.familyBody
                    font.pixelSize: 11
                    color: NexaUI.NexaColors.mutedText
                }
            }

            // Mini Mockup Preview Card
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 140
                radius: NexaUI.NexaTokens.radiusSm
                color: root.stagedMode === "dark" ? "#1e1e2e" : "#f5f5f7"
                border.width: 1
                border.color: NexaUI.NexaColors.border
                clip: true

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    // Mini Window Titlebar
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Rectangle { width: 8; height: 8; radius: 4; color: "#ff5555" }
                        Rectangle { width: 8; height: 8; radius: 4; color: "#ffb86c" }
                        Rectangle { width: 8; height: 8; radius: 4; color: "#50fa7b" }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: root.stagedPresetName
                            font.family: NexaUI.NexaTypography.familyBody
                            font.pixelSize: 11
                            font.weight: NexaUI.NexaTypography.weightSemiBold
                            color: root.stagedMode === "dark" ? "#cdd6f4" : "#1e1e2e"
                            elide: Text.ElideRight
                        }
                    }

                    // Mini Window Content Mockup
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: NexaUI.NexaTokens.radiusXs
                        color: root.stagedMode === "dark" ? "#181825" : "#e6e6ec"

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 8

                            Rectangle {
                                Layout.preferredWidth: 28
                                Layout.fillHeight: true
                                radius: 3
                                color: root.stagedMode === "dark" ? "#11111b" : "#d0d0d8"
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 14
                                    radius: 3
                                    color: root.stagedPrimary
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 4

                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 12
                                        radius: 3
                                        color: root.stagedSecondary
                                    }
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 12
                                        radius: 3
                                        color: root.stagedTertiary
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Mode Selector (Dark / Light)
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Rectangle {
                    id: darkPill
                    Layout.fillWidth: true
                    height: 32
                    radius: NexaUI.NexaTokens.radiusSm
                    readonly property bool isDark: root.stagedMode === "dark"
                    color: isDark ? NexaUI.NexaColors.primaryContainer : (darkMouse.containsMouse ? NexaUI.NexaColors.surfaceContainerHigh : NexaUI.NexaColors.surfaceContainer)
                    border.width: isDark ? 1 : 0
                    border.color: isDark ? NexaUI.NexaColors.primary : "transparent"

                    Row {
                        anchors.centerIn: parent
                        spacing: 6
                        Text {
                            text: "󰖔"
                            font.family: NexaUI.NexaTypography.familyIcon
                            font.pixelSize: 13
                            color: darkPill.isDark ? NexaUI.NexaColors.onPrimaryContainer : NexaUI.NexaColors.mutedText
                        }
                        Text {
                            text: "Dark"
                            font.family: NexaUI.NexaTypography.familyBody
                            font.pixelSize: 12
                            font.weight: darkPill.isDark ? NexaUI.NexaTypography.weightSemiBold : NexaUI.NexaTypography.weightRegular
                            color: darkPill.isDark ? NexaUI.NexaColors.onPrimaryContainer : NexaUI.NexaColors.text
                        }
                    }

                    MouseArea {
                        id: darkMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.stageModeRequested("dark")
                    }
                }

                Rectangle {
                    id: lightPill
                    Layout.fillWidth: true
                    height: 32
                    radius: NexaUI.NexaTokens.radiusSm
                    readonly property bool isLight: root.stagedMode === "light"
                    color: isLight ? NexaUI.NexaColors.primaryContainer : (lightMouse.containsMouse ? NexaUI.NexaColors.surfaceContainerHigh : NexaUI.NexaColors.surfaceContainer)
                    border.width: isLight ? 1 : 0
                    border.color: isLight ? NexaUI.NexaColors.primary : "transparent"

                    Row {
                        anchors.centerIn: parent
                        spacing: 6
                        Text {
                            text: "󰖙"
                            font.family: NexaUI.NexaTypography.familyIcon
                            font.pixelSize: 13
                            color: lightPill.isLight ? NexaUI.NexaColors.onPrimaryContainer : NexaUI.NexaColors.mutedText
                        }
                        Text {
                            text: "Light"
                            font.family: NexaUI.NexaTypography.familyBody
                            font.pixelSize: 12
                            font.weight: lightPill.isLight ? NexaUI.NexaTypography.weightSemiBold : NexaUI.NexaTypography.weightRegular
                            color: lightPill.isLight ? NexaUI.NexaColors.onPrimaryContainer : NexaUI.NexaColors.text
                        }
                    }

                    MouseArea {
                        id: lightMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.stageModeRequested("light")
                    }
                }
            }

            // Swatches List with Hex Labels
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                    model: [
                        { name: "Primary Accent", color: root.stagedPrimary },
                        { name: "Secondary", color: root.stagedSecondary },
                        { name: "Tertiary", color: root.stagedTertiary }
                    ]

                    Rectangle {
                        id: swatchRow
                        required property var modelData
                        Layout.fillWidth: true
                        height: 34
                        radius: NexaUI.NexaTokens.radiusSm
                        color: NexaUI.NexaColors.surfaceContainer

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 8

                            Rectangle {
                                width: 16; height: 16; radius: 8
                                color: swatchRow.modelData.color
                                border.width: 1
                                border.color: NexaUI.NexaColors.border
                            }

                            Text {
                                text: swatchRow.modelData.name
                                font.family: NexaUI.NexaTypography.familyBody
                                font.pixelSize: 12
                                color: NexaUI.NexaColors.text
                                Layout.fillWidth: true
                            }

                            Text {
                                text: String(swatchRow.modelData.color).toUpperCase()
                                font.family: NexaUI.NexaTypography.familyBody
                                font.pixelSize: 11
                                font.weight: NexaUI.NexaTypography.weightSemiBold
                                color: NexaUI.NexaColors.mutedText
                            }
                        }
                    }
                }
            }

            Item { Layout.fillHeight: true }

            // Preset Summary & Apply Button
            Text {
                text: root.stagedPresetName
                font.family: NexaUI.NexaTypography.familyBody
                font.pixelSize: 14
                font.weight: NexaUI.NexaTypography.weightBold
                color: NexaUI.NexaColors.text
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Text {
                text: root.stagedPresetCategory ? (root.stagedPresetCategory + " Collection") : "Preset Collection"
                font.family: NexaUI.NexaTypography.familyBody
                font.pixelSize: 11
                color: NexaUI.NexaColors.mutedText
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            // Apply Button
            Rectangle {
                id: applyPresetBtn
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                radius: NexaUI.NexaTokens.radiusSm

                readonly property bool isCurrent: root.isCurrentThemeActive

                color: isCurrent
                    ? Qt.rgba(NexaUI.NexaColors.primary.r, NexaUI.NexaColors.primary.g, NexaUI.NexaColors.primary.b, 0.1)
                    : (applyMouse.containsMouse ? Qt.lighter(NexaUI.NexaColors.primary, 1.08) : NexaUI.NexaColors.primary)
                border.width: isCurrent ? 1 : 0
                border.color: isCurrent ? NexaUI.NexaColors.primary : "transparent"

                Row {
                    anchors.centerIn: parent
                    spacing: 8

                    Text {
                        text: applyPresetBtn.isCurrent ? "✓" : "󰸉"
                        font.family: applyPresetBtn.isCurrent ? NexaUI.NexaTypography.familyBody : NexaUI.NexaTypography.familyIcon
                        font.pixelSize: 14
                        color: applyPresetBtn.isCurrent ? NexaUI.NexaColors.primary : NexaUI.NexaColors.onPrimary
                    }

                    Text {
                        text: root.applying ? "Applying..." : (applyPresetBtn.isCurrent ? "Active Theme" : "Apply Preset")
                        font.family: NexaUI.NexaTypography.familyBody
                        font.pixelSize: 13
                        font.weight: NexaUI.NexaTypography.weightSemiBold
                        color: applyPresetBtn.isCurrent ? NexaUI.NexaColors.primary : NexaUI.NexaColors.onPrimary
                    }
                }

                MouseArea {
                    id: applyMouse
                    anchors.fill: parent
                    enabled: !root.isCurrentThemeActive && !root.applying
                    hoverEnabled: true
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: root.applyRequested()
                }
            }
        }
    }
}
