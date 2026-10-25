pragma Singleton
// pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Io
import QtQuick

// Lock screen themes: the registry of available designs and which ones are
// active. Lock.qml asks pick() for the theme of each lock; the picker panel
// (modules/lockthemes) edits the selection. With shuffle off the first active
// theme is always used; with it on, each lock draws a random one from the
// active set (never the same twice in a row when there's a choice).
//
// Timings are the theme's choreography lengths, which LockContext uses to run
// the intro, the reward hold and the exit.
Singleton {
    id: root

    readonly property string defaultTheme: "xianxia"

    readonly property var themes: [
        {
            id: "nexa",
            name: "Nexa Default",
            tagline: "Nexa Glass",
            description: "Nexa's native lock screen with dynamic music player, battery status, user avatar, and smooth password unlock.",
            source: Qt.resolvedUrl("../modules/lockthemes/themes/nexa/NexaSurface.qml"),
            introMs: 600, outroMs: 400, rewardBaseMs: 300, rewardLevelUpMs: 0, rewardAchievementMs: 0,
            ambient: false
        },
        {
            id: "xianxia",
            name: "Sealed Cave Abode",
            tagline: "Xianxia · 洞府封印",
            description: "Your wallpaper as a moonlit ink painting, sealed by a golden formation. Incense sticks are lives; unlocking is a breakthrough.",
            source: Qt.resolvedUrl("../modules/lockthemes/themes/xianxia/XianxiaSurface.qml"),
            introMs: 1700, outroMs: 1150, rewardBaseMs: 1400, rewardLevelUpMs: 1000, rewardAchievementMs: 450,
            ambient: true
        },
        {
            id: "cosmos",
            name: "Astral",
            tagline: "Deep space",
            description: "The desktop spirals into a singularity; your passcode charts a constellation across a living starfield.",
            source: Qt.resolvedUrl("../modules/lockthemes/themes/cosmos/CosmosSurface.qml"),
            introMs: 1600, outroMs: 1100, rewardBaseMs: 1300, rewardLevelUpMs: 900, rewardAchievementMs: 450,
            ambient: true
        },
        {
            id: "cyberpunk",
            name: "Black ICE",
            tagline: "Cyberpunk · 攻性防壁",
            description: "Your deck behind black ICE in a rain-slick neon city. The desktop glitches out, your passcode is a breach, wrong ones raise the trace, and getting in pays street cred.",
            source: Qt.resolvedUrl("../modules/lockthemes/themes/cyberpunk/CyberpunkSurface.qml"),
            introMs: 1250, outroMs: 950, rewardBaseMs: 1350, rewardLevelUpMs: 900, rewardAchievementMs: 450,
            ambient: true
        },
        {
            id: "zen",
            name: "Still",
            tagline: "Minimal glass",
            description: "Just the time, a soft focus pull and a glass field. The quickest unlock of the set.",
            source: Qt.resolvedUrl("../modules/lockthemes/themes/zen/ZenSurface.qml"),
            introMs: 900, outroMs: 520, rewardBaseMs: 280, rewardLevelUpMs: 0, rewardAchievementMs: 0,
            ambient: false
        },
        {
            id: "arcade",
            name: "Pause Menu",
            tagline: "Arcade HUD",
            description: "Sci-fi game HUD with XP, ranks, combos, lives and trophies. Tiles fly away on lock; an XP read-out on unlock.",
            source: Qt.resolvedUrl("../modules/lockthemes/themes/arcade/ArcadeSurface.qml"),
            introMs: 1250, outroMs: 900, rewardBaseMs: 1150, rewardLevelUpMs: 900, rewardAchievementMs: 450,
            ambient: false
        },
        {
            id: "wabisabi",
            name: "Ensō",
            tagline: "Wabi-sabi · 円相",
            description: "The desktop yellows into old washi paper. Each keystroke moves the brush around an ensō; mistakes crack it, and coming home mends the cracks with gold.",
            source: Qt.resolvedUrl("../modules/lockthemes/themes/wabisabi/WabisabiSurface.qml"),
            introMs: 1500, outroMs: 1100, rewardBaseMs: 1350, rewardLevelUpMs: 850, rewardAchievementMs: 400,
            ambient: true
        },
        {
            id: "newspaper",
            name: "Extra! Extra!",
            tagline: "Broadsheet · Stop the press",
            description: "Your desktop becomes the front-page photograph of your own paper. The passcode fills today's crossword, wrong ones print corrections, too many halt the presses, and getting in spins an EXTRA edition onto the screen.",
            source: Qt.resolvedUrl("../modules/lockthemes/themes/newspaper/NewspaperSurface.qml"),
            introMs: 1300, outroMs: 1150, rewardBaseMs: 1600, rewardLevelUpMs: 800, rewardAchievementMs: 400,
            ambient: false
        }
    ]

    readonly property alias active: adapter.active
    readonly property alias shuffle: adapter.shuffle
    readonly property alias last: adapter.last
    property bool ready: false

    // The active ids that still exist, in order; never empty.
    readonly property var activeIds: {
        const out = [];
        const ids = adapter.active;
        for (let i = 0; i < ids.length; i++)
            if (has(ids[i]) && !out.includes(ids[i]))
                out.push(ids[i]);
        return out.length > 0 ? out : [defaultTheme];
    }

    // The theme used when shuffle is off.
    readonly property string current: activeIds[0]

    function has(id) {
        return themes.some(t => t.id === id);
    }

    function theme(id) {
        return themes.find(t => t.id === id) ?? themes.find(t => t.id === defaultTheme);
    }

    function isActive(id) {
        return adapter.shuffle ? activeIds.includes(id) : current === id;
    }

    // Single mode: make `id` the theme. Shuffle mode: add it to / remove it
    // from the rotation (which always keeps at least one theme).
    function select(id) {
        if (!has(id))
            return;
        if (!adapter.shuffle) {
            adapter.active = [id];
            return;
        }
        const next = activeIds.slice();
        const i = next.indexOf(id);
        if (i < 0)
            next.push(id);
        else if (next.length > 1)
            next.splice(i, 1);
        adapter.active = next;
    }

    function setShuffle(on) {
        adapter.shuffle = on;
    }

    function pick() {
        const ids = activeIds;
        if (!adapter.shuffle || ids.length === 1)
            return ids[0];
        const fresh = ids.filter(id => id !== adapter.last);
        const pool = fresh.length > 0 ? fresh : ids;
        return pool[Math.floor(Math.random() * pool.length)];
    }

    // Lock.qml records what it showed, so shuffle can avoid repeats.
    function remember(id) {
        if (adapter.shuffle && adapter.last !== id)
            adapter.last = id;
    }

    Timer {
        id: writeTimer
        interval: 100
        repeat: false
        onTriggered: settingsFile.writeAdapter()
    }

    Timer {
        id: reloadTimer
        interval: 100
        repeat: false
        onTriggered: settingsFile.reload()
    }

    FileView {
        id: settingsFile
        path: Quickshell.env("HOME") + "/.config/nexa/config/lockscreen.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reloadTimer.restart()
        onAdapterUpdated: writeTimer.restart()
        onLoaded: root.ready = true
        onLoadFailed: error => {
            if (error == FileViewError.FileNotFound)
                root.ready = true;
        }

        adapter: JsonAdapter {
            id: adapter
            property var active: ["arcade"]
            property bool shuffle: false
            property string last: ""
        }
    }

    // ============================================================
    // LOCK SCREEN WALLPAPER (Nexa native integration)
    // ============================================================

    readonly property string wallpaperPath: _wallpaperPath
    readonly property string wallpaperProxy: _wallpaperProxy
    readonly property string wallpaperType: _wallpaperType
    readonly property string wallpaperThumb: _wallpaperThumb
    readonly property string wallpaperPreview: _wallpaperPreview
    readonly property string wallpaperSource: {
        if (_wallpaperType === "video" && _wallpaperProxy !== "") {
            return "file://" + encodeURI(_wallpaperProxy);
        }
        return _wallpaperPath !== "" ? ("file://" + encodeURI(_wallpaperPath)) : "";
    }
    readonly property bool wallpaperLoaded: _wallpaperLoaded

    property string _wallpaperPath: ""
    property string _wallpaperProxy: ""
    property string _wallpaperType: "image"
    property string _wallpaperThumb: "file://" + Quickshell.env("HOME") + "/.cache/current_wallpaper"
    property string _wallpaperPreview: "file://" + Quickshell.env("HOME") + "/.cache/current_wallpaper"
    property bool _wallpaperLoaded: false

    function refreshWallpaper() {
        lockInfoProc.running = false;
        lockInfoProc.command = [
            Quickshell.env("HOME") + "/.config/nexa/rust/target/release/nexad",
            "wallpaper",
            "lock-info"
        ];
        lockInfoProc.running = true;
    }

    Process {
        id: lockInfoProc
        stdout: StdioCollector {
            onStreamFinished: {
                const text = String(this.text).trim();
                const parts = text.split("|");
                if (parts.length < 2) return;
                const type = parts[0];
                const path = parts[1];
                const proxy = parts.length > 2 ? parts[2] : "";

                root._wallpaperProxy = proxy;
                root._wallpaperPath = path;
                root._wallpaperType = type;

                const filename = path.substring(path.lastIndexOf("/") + 1);
                const thumb = Quickshell.env("HOME") + "/.cache/nexa/wallpapers/thumbs/" + filename + ".jpg";
                root._wallpaperThumb = "file://" + encodeURI(thumb);

                if (type === "video") {
                    root._wallpaperPreview = "file://" + encodeURI(thumb);
                } else {
                    root._wallpaperPreview = "file://" + encodeURI(path);
                }
                root._wallpaperLoaded = true;
            }
        }
    }

    FileView {
        id: lockConfWatch
        path: Quickshell.env("HOME") + "/.config/nexa/config/lockscreen.conf"
        watchChanges: true
        printErrors: false
        onFileChanged: root.refreshWallpaper()
        onLoaded: root.refreshWallpaper()
    }

    Component.onCompleted: {
        root.refreshWallpaper();
    }
}

