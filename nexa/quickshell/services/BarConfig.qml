pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property string position: "top" // "top", "bottom", "left", "right"
    property bool autohide: false
    property bool floating: true
    property int height: 38
    property bool showWorkspaces: true
    property bool showTitle: true
    property bool showIsland: true
    property bool showTray: true
    property bool showBattery: true
    property bool showNetwork: true
    property bool showSettings: true
    property bool showPower: true
    property bool showMusic: true

    readonly property string configPath: Quickshell.env("HOME") + "/.config/nexa/config/bar.json"

    Timer {
        id: saveTimer
        interval: 150
        repeat: false
        onTriggered: root._writeConfig()
    }

    FileView {
        id: configFile
        path: root.configPath
        watchChanges: true
        printErrors: false

        onFileChanged: reload()

        onLoaded: {
            try {
                const d = JSON.parse(text());
                if (!d) return;
                if (d.position !== undefined) root.position = d.position;
                if (d.autohide !== undefined) root.autohide = d.autohide;
                if (d.floating !== undefined) root.floating = d.floating;
                if (d.height !== undefined) root.height = d.height;
                if (d.show_workspaces !== undefined) root.showWorkspaces = d.show_workspaces;
                if (d.show_title !== undefined) root.showTitle = d.show_title;
                if (d.show_island !== undefined) root.showIsland = d.show_island;
                if (d.show_tray !== undefined) root.showTray = d.show_tray;
                if (d.show_battery !== undefined) root.showBattery = d.show_battery;
                if (d.show_network !== undefined) root.showNetwork = d.show_network;
                if (d.show_settings !== undefined) root.showSettings = d.show_settings;
                if (d.show_power !== undefined) root.showPower = d.show_power;
                if (d.show_music !== undefined) root.showMusic = d.show_music;
            } catch (_) {}
        }
    }

    function _writeConfig() {
        const obj = {
            position: root.position,
            autohide: root.autohide,
            floating: root.floating,
            height: root.height,
            show_workspaces: root.showWorkspaces,
            show_title: root.showTitle,
            show_island: root.showIsland,
            show_tray: root.showTray,
            show_battery: root.showBattery,
            show_network: root.showNetwork,
            show_settings: root.showSettings,
            show_power: root.showPower,
            show_music: root.showMusic
        };
        const jsonStr = JSON.stringify(obj, null, 2);
        configFile.setText(jsonStr);
    }

    function setPosition(pos) {
        if (!pos || root.position === pos) return;
        root.position = pos;
        saveTimer.restart();
    }

    function setAutohide(val) {
        if (root.autohide === val) return;
        root.autohide = val;
        saveTimer.restart();
    }

    function setFloating(val) {
        if (root.floating === val) return;
        root.floating = val;
        saveTimer.restart();
    }

    function setHeight(h) {
        if (root.height === h) return;
        root.height = h;
        saveTimer.restart();
    }

    function toggleComponent(name) {
        switch (name) {
            case "workspaces": root.showWorkspaces = !root.showWorkspaces; break;
            case "title": root.showTitle = !root.showTitle; break;
            case "island": root.showIsland = !root.showIsland; break;
            case "tray": root.showTray = !root.showTray; break;
            case "battery": root.showBattery = !root.showBattery; break;
            case "network": root.showNetwork = !root.showNetwork; break;
            case "settings": root.showSettings = !root.showSettings; break;
            case "power": root.showPower = !root.showPower; break;
            case "music": root.showMusic = !root.showMusic; break;
        }
        saveTimer.restart();
    }

    function resetDefaults() {
        root.position = "top";
        root.autohide = false;
        root.floating = true;
        root.height = 38;
        root.showWorkspaces = true;
        root.showTitle = true;
        root.showIsland = true;
        root.showTray = true;
        root.showBattery = true;
        root.showNetwork = true;
        root.showPower = true;
        root.showMusic = true;
        saveTimer.restart();
    }
}
