pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    // ============================================================
    // DYNAMIC APPLICATION REGISTRY
    //
    // Backed by nexad XDG desktop index ($XDG_RUNTIME_DIR/nexa/desktop_apps.json).
    // Automatically indexes all system, user, and flatpak .desktop files.
    // Resolves Wayland app_id / StartupWMClass to real names and icons dynamically.
    // Zero hardcoded app tables.
    // ============================================================

    property var desktopApps: ({})

    property FileView _desktopAppsWatcher: FileView {
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/nexa/desktop_apps.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const raw = text()
                if (raw && raw.length > 2) {
                    root.desktopApps = JSON.parse(raw)
                }
            } catch (e) {
                console.warn("[AppRegistry] Failed to parse desktop_apps.json:", e)
            }
        }
    }

    function resolveAppIcon(id) {
        if (!id || id.length === 0) return ""

        const raw = String(id).trim()
        const lower = raw.toLowerCase()
        const rawLast = raw.split('.').pop()
        const last = lower.split('.').pop()

        // 1. Dynamic lookup in XDG desktop registry
        if (root.desktopApps) {
            const keys = [raw, lower, rawLast, last]
            for (let i = 0; i < keys.length; i++) {
                const k = keys[i]
                if (k && root.desktopApps[k] && root.desktopApps[k].icon) {
                    const iconVal = root.desktopApps[k].icon
                    if (iconVal.startsWith("file://") || iconVal.startsWith("/")) {
                        return iconVal.startsWith("file://") ? iconVal : ("file://" + iconVal)
                    }
                    if (Quickshell.hasThemeIcon(iconVal)) {
                        return Quickshell.iconPath(iconVal)
                    }
                }
            }
        }

        // 2. Direct system icon theme candidates
        const candidates = [
            raw,
            lower,
            rawLast,
            last,
            "org.kde." + last,
            "org.gnome." + last,
            "com." + last
        ]

        for (let i = 0; i < candidates.length; i++) {
            const c = candidates[i]
            if (c && Quickshell.hasThemeIcon(c)) {
                return Quickshell.iconPath(c)
            }
        }

        // 3. Fallback generic categories
        if (lower.includes("terminal") || lower.includes("term")) {
            if (Quickshell.hasThemeIcon("utilities-terminal")) return Quickshell.iconPath("utilities-terminal")
        }
        if (lower.includes("browser") || lower.includes("web")) {
            if (Quickshell.hasThemeIcon("web-browser")) return Quickshell.iconPath("web-browser")
        }
        if (lower.includes("file") || lower.includes("fm")) {
            if (Quickshell.hasThemeIcon("system-file-manager")) return Quickshell.iconPath("system-file-manager")
        }

        // 4. Generic executable fallback
        if (Quickshell.hasThemeIcon("application-x-executable")) {
            return Quickshell.iconPath("application-x-executable")
        }

        return "file:///usr/share/icons/breeze/mimetypes/64/application-x-executable.svg"
    }

    function cleanAppName(id) {
        if (!id || id.length === 0) return ""
        const raw = String(id).trim()
        const lower = raw.toLowerCase()
        const rawLast = raw.split('.').pop()
        const last = lower.split('.').pop()

        // 1. Dynamic lookup in XDG desktop registry
        if (root.desktopApps) {
            const keys = [raw, lower, rawLast, last]
            for (let i = 0; i < keys.length; i++) {
                const k = keys[i]
                if (k && root.desktopApps[k] && root.desktopApps[k].name) {
                    return root.desktopApps[k].name
                }
            }
        }

        // 2. Fallback: Format the last component cleanly
        const display = rawLast || raw
        return display.charAt(0).toUpperCase() + display.slice(1)
    }
}

