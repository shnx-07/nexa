import QtQuick

Item {
    id: root

    property alias text: label.glyphName
    property alias color: label.color
    property alias font: label.font
    property alias horizontalAlignment: label.horizontalAlignment
    property alias verticalAlignment: label.verticalAlignment
    property bool filled: false
    property int weight: 500

    implicitWidth: label.implicitWidth
    implicitHeight: label.implicitHeight
    width: implicitWidth
    height: implicitHeight

    Text {
        id: label
        property string glyphName: ""

        anchors.centerIn: parent
        font.family: "Symbols Nerd Font Mono"
        color: (typeof LockTheme !== "undefined" && LockTheme.ink) ? LockTheme.ink : "white"
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter

        readonly property var _glyphMap: ({
            "lock": "\uf023",
            "lock_open": "\uf09c",
            "check": "\uf00c",
            "close": "\uf00d",
            "shuffle": "\uf074",
            "play_arrow": "\uf04b",
            "pause": "\uf04c",
            "skip_next": "\uf051",
            "skip_previous": "\uf048",
            "military_tech": "\uf0a3",
            "bolt": "\uf0e7",
            "local_fire_department": "\uf06d",
            "emoji_events": "\uf091",
            "desktop_windows": "\uf108",
            "widgets": "\uf009",
            "favorite": "\uf004",
            "favorite_border": "\uf08a",
            "heart_broken": "\uf7a9",
            "volume_up": "\uf028",
            "volume_off": "\uf026",
            "volume_mute": "\uf026",
            "music_note": "\uf001",
            "sports_esports": "\uf11b",
            "battery_full": "\uf240",
            "battery_charging_full": "\uf0e7",
            "visibility": "\uf06e",
            "visibility_off": "\uf070",
            "keyboard_capslock": "\uf102",
            "refresh": "\uf021",
            "settings": "\uf013",
            "star": "\uf005",
            "star_border": "\uf006",
            "shield": "\uf132",
            "key": "\uf084",
            "crop_square": "\uf096",
            "view_agenda": "\uf009",
            "grid_4x4": "\uf00a"
        })

        text: _glyphMap[glyphName] !== undefined ? _glyphMap[glyphName] : glyphName
    }
}
