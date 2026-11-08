pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    // Primary
    property color primary: "#afc6ff"
    property color on_primary: "#002d6d"
    property color primaryContainer: "#004299"
    property color on_primary_container: "#d9e2ff"

    // Secondary
    property color secondary: "#c2c3eb"
    property color on_secondary: "#2c2e4d"
    property color secondaryContainer: "#424465"
    property color on_secondary_container: "#e0e0ff"

    // Tertiary
    property color tertiary: "#cdbef7"
    property color on_tertiary: "#342957"
    property color tertiaryContainer: "#4b3f6f"
    property color on_tertiary_container: "#e8ddff"

    // Background
    property color background: "#10131c"
    property color on_background: "#e0e2ef"

    // Surface hierarchy
    property color surface: "#10131c"
    property color surfaceDim: "#10131c"
    property color surfaceBright: "#363943"

    property color surfaceContainerLowest: "#0a0e17"
    property color surfaceContainerLow: "#181b25"
    property color surfaceContainer: "#1c1f29"
    property color surfaceContainerHigh: "#262a34"
    property color surfaceContainerHighest: "#31353f"

    // Surface content
    property color on_surface: "#e0e2ef"
    property color on_surface_variant: "#c3c6d3"

    property color inverseSurface: "#e0e2ef"
    property color inverse_on_surface: "#2d303a"
    property color inversePrimary: "#0059c8"

    // Outline
    property color outline: "#8d909c"
    property color outlineVariant: "#434751"
    property color shadow: "#000000"
    property color scrim: "#000000"

    // Error
    property color error: "#f0757f"
    property color on_error: "#37060a"
    property color errorContainer: "#541c21"
    property color on_error_container: "#f8aab1"

    // Success
    property color success: "#78e29c"
    property color on_success: "#083617"
    property color successContainer: "#1c4a2b"
    property color on_success_container: "#a6f2bf"

    // Warning
    property color warning: "#efc36c"
    property color on_warning: "#372706"
    property color warningContainer: "#4d3c19"
    property color on_warning_container: "#f7daa1"

    // Info
    property color info: "#79cfec"
    property color on_info: "#062b37"
    property color infoContainer: "#1c3e4a"
    property color on_info_container: "#a3e0f5"

    // Compatibility aliases
    readonly property color text: on_background
    readonly property color mutedText: on_surface_variant

    // Keep current NEXA compatibility (map to proper surface container, not text)
    readonly property color surfaceVariant: surfaceContainerHigh

    property FileView _paletteWatcher: FileView {
        path: Quickshell.env("HOME") + "/.cache/nexa/theme/palette"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const lines = text().split("\n");
                for (let i = 0; i < lines.length; ++i) {
                    const line = lines[i].trim();
                    if (!line || line.startsWith("#")) continue;
                    const eq = line.indexOf("=");
                    if (eq < 0) continue;
                    const key = line.substring(0, eq).trim();
                    const val = line.substring(eq + 1).trim().replace(/^["']|["']$/g, '');
                    if (!val) continue;

                    switch (key) {
                        case "PRIMARY": root.primary = val; break;
                        case "PRIMARY_TEXT": root.on_primary = val; break;
                        case "PRIMARY_CONTAINER": root.primaryContainer = val; break;
                        case "PRIMARY_CONTAINER_TEXT": root.on_primary_container = val; break;

                        case "SECONDARY": root.secondary = val; break;
                        case "SECONDARY_TEXT": root.on_secondary = val; break;
                        case "SECONDARY_CONTAINER": root.secondaryContainer = val; break;
                        case "SECONDARY_CONTAINER_TEXT": root.on_secondary_container = val; break;

                        case "TERTIARY": root.tertiary = val; break;
                        case "TERTIARY_TEXT": root.on_tertiary = val; break;
                        case "TERTIARY_CONTAINER": root.tertiaryContainer = val; break;
                        case "TERTIARY_CONTAINER_TEXT": root.on_tertiary_container = val; break;

                        case "BACKGROUND": root.background = val; break;
                        case "BACKGROUND_TEXT": root.on_background = val; break;

                        case "SURFACE": root.surface = val; break;
                        case "SURFACE_DIM": root.surfaceDim = val; break;
                        case "SURFACE_BRIGHT": root.surfaceBright = val; break;

                        case "SURFACE_CONTAINER_LOWEST": root.surfaceContainerLowest = val; break;
                        case "SURFACE_CONTAINER_LOW": root.surfaceContainerLow = val; break;
                        case "SURFACE_CONTAINER": root.surfaceContainer = val; break;
                        case "SURFACE_CONTAINER_HIGH": root.surfaceContainerHigh = val; break;
                        case "SURFACE_CONTAINER_HIGHEST": root.surfaceContainerHighest = val; break;

                        case "TEXT": root.on_surface = val; break;
                        case "MUTED_TEXT": root.on_surface_variant = val; break;

                        case "INVERSE_SURFACE": root.inverseSurface = val; break;
                        case "INVERSE_ON_SURFACE": root.inverse_on_surface = val; break;
                        case "INVERSE_PRIMARY": root.inversePrimary = val; break;

                        case "OUTLINE": root.outline = val; break;
                        case "OUTLINE_VARIANT": root.outlineVariant = val; break;
                        case "SHADOW": root.shadow = val; break;
                        case "SCRIM": root.scrim = val; break;

                        case "ERROR": root.error = val; break;
                        case "ERROR_TEXT": root.on_error = val; break;
                        case "ERROR_CONTAINER": root.errorContainer = val; break;

                        case "SUCCESS": root.success = val; break;
                        case "SUCCESS_TEXT": root.on_success = val; break;
                        case "SUCCESS_CONTAINER": root.successContainer = val; break;

                        case "WARNING": root.warning = val; break;
                        case "WARNING_TEXT": root.on_warning = val; break;
                        case "WARNING_CONTAINER": root.warningContainer = val; break;

                        case "INFO": root.info = val; break;
                        case "INFO_TEXT": root.on_info = val; break;
                        case "INFO_CONTAINER": root.infoContainer = val; break;
                    }
                }
            } catch (e) {}
        }
    }
}
