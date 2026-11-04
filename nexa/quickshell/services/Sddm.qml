pragma Singleton
// pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property var themes: []
    property string activeSddmTheme: "material-you-dark"
    property string activeDesktopSddmTheme: ""
    property bool syncWallpaper: true
    property bool applying: false
    property string lastAppliedStatus: ""

    // ── SDDM Themes Catalog ──────────────────────────────────────────
    FileView {
        id: themesFile
        path: Quickshell.env("HOME") + "/.config/nexa/sddm/themes.json"
        watchChanges: true
        printErrors: false
        onLoaded: {
            try {
                const parsed = JSON.parse(text());
                if (Array.isArray(parsed)) {
                    root.themes = parsed;
                }
            } catch (e) {
                console.warn("[SddmService] Failed to parse themes.json:", e);
            }
        }
    }

    // ── Active SDDM Theme Tracking ───────────────────────────────────
    FileView {
        id: sddmThemeWatcher
        path: Quickshell.env("HOME") + "/.config/nexa/config/sddm_theme"
        watchChanges: true
        printErrors: false
        onLoaded: {
            const t = text().trim();
            if (t.length > 0) root.activeSddmTheme = t;
        }
        onFileChanged: {
            const t = text().trim();
            if (t.length > 0) root.activeSddmTheme = t;
        }
    }

    // ── Active Desktop SDDM Theme Tracking ───────────────────────────
    FileView {
        id: desktopLockWatcher
        path: Quickshell.env("HOME") + "/.config/nexa/config/desktop_sddm_theme"
        watchChanges: true
        printErrors: false
        onLoaded: {
            root.activeDesktopSddmTheme = text().trim();
        }
        onFileChanged: {
            root.activeDesktopSddmTheme = text().trim();
        }
    }

    // ── Wallpaper Path Helper ────────────────────────────────────────
    readonly property string currentWallpaper: {
        return Quickshell.env("HOME") + "/.cache/current_wallpaper";
    }

    // ── Apply to SDDM via Polkit ─────────────────────────────────────
    function applyToSddm(themeId) {
        if (!themeId || themeId.trim() === "") return;
        root.applying = true;
        root.lastAppliedStatus = "Authenticating with Polkit...";

        let wpArg = "";
        if (root.syncWallpaper) {
            // Read active wallpaper from wallpaper.conf
            wpArg = "sync";
        }

        applyProc.running = false;
        applyProc.command = [
            "pkexec",
            Quickshell.env("HOME") + "/.config/nexa/scripts/sddm-apply.sh",
            themeId,
            wpArg
        ];
        applyProc.running = true;
    }

    Process {
        id: applyProc
        stdout: StdioCollector {
            onStreamFinished: {
                console.log("[SddmService] pkexec stdout:", this.text);
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (this.text.trim().length > 0) {
                    console.warn("[SddmService] pkexec stderr:", this.text);
                }
            }
        }
        onExited: (code, status) => {
            root.applying = false;
            if (code === 0) {
                root.lastAppliedStatus = "Successfully applied to SDDM!";
                sddmThemeWatcher.reload();
            } else {
                root.lastAppliedStatus = "Failed or canceled by user (exit code " + code + ")";
            }
        }
    }

    // ── Desktop Lock Management ─────────────────────────────────────
    function setDesktopLockTheme(themeId) {
        if (!themeId || themeId.trim() === "") return;
        const cleanId = themeId.trim();
        root.activeDesktopSddmTheme = cleanId;
        desktopLockWatcher.setText(cleanId);
    }

    function clearDesktopLockTheme() {
        root.activeDesktopSddmTheme = "";
        desktopLockWatcher.setText("");
        Quickshell.execDetached([
            "rm", "-f",
            Quickshell.env("HOME") + "/.config/nexa/config/desktop_sddm_theme"
        ]);
    }

    function toggleDesktopLockTheme(themeId) {
        if (!themeId || themeId.trim() === "") return;
        if (root.activeDesktopSddmTheme === themeId) {
            clearDesktopLockTheme();
        } else {
            setDesktopLockTheme(themeId);
        }
    }

    // ── Apply to Both (SDDM + Nexa Desktop Lock) ─────────────────────
    function applyToBoth(themeId) {
        if (!themeId || themeId.trim() === "") return;
        setDesktopLockTheme(themeId);
        applyToSddm(themeId);
    }

    // ── Preview SDDM Theme ───────────────────────────────────────────
    function previewTheme(themeId) {
        if (!themeId || themeId.trim() === "") return;
        const cleanId = themeId.trim();
        Quickshell.execDetached([
            "env",
            "QS_THEME=" + cleanId,
            "QS_TESTING=1",
            "quickshell",
            "-p",
            Quickshell.env("HOME") + "/.config/nexa/sddm/lock_shell.qml"
        ]);
    }

    Component.onCompleted: {
        themesFile.reload();
        sddmThemeWatcher.reload();
        desktopLockWatcher.reload();
    }
}
