pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    // Primary
    property color primary: "#ffffff"
    property color on_primary: "#000000"
    property color primaryContainer: "#242424"
    property color on_primary_container: "#ffffff"

    // Secondary
    property color secondary: "#d6d6d6"
    property color on_secondary: "#111111"
    property color secondaryContainer: "#1f1f1f"
    property color on_secondary_container: "#e0e0e0"

    // Tertiary
    property color tertiary: "#8a8a8a"
    property color on_tertiary: "#000000"
    property color tertiaryContainer: "#181818"
    property color on_tertiary_container: "#cccccc"

    // Background
    property color background: "#0a0a0a"
    property color on_background: "#f0f0f0"

    // Surface hierarchy
    property color surface: "#0a0a0a"
    property color surfaceDim: "#050505"
    property color surfaceBright: "#222222"

    property color surfaceContainerLowest: "#000000"
    property color surfaceContainerLow: "#0d0d0d"
    property color surfaceContainer: "#141414"
    property color surfaceContainerHigh: "#1c1c1c"
    property color surfaceContainerHighest: "#282828"

    // Surface content
    property color on_surface: "#f0f0f0"
    property color on_surface_variant: "#a6a6a6"

    property color inverseSurface: "#f0f0f0"
    property color inverse_on_surface: "#0a0a0a"
    property color inversePrimary: "#555555"

    // Outline
    property color outline: "#484848"
    property color outlineVariant: "#222222"
    property color shadow: "#000000"
    property color scrim: "#000000"

    // Error
    property color error: "#ff5555"
    property color on_error: "#220000"
    property color errorContainer: "#441111"
    property color on_error_container: "#ff9999"

    // Success
    property color success: "#55ff99"
    property color on_success: "#002211"
    property color successContainer: "#114422"
    property color on_success_container: "#99ffbb"

    // Warning
    property color warning: "#ffbb33"
    property color on_warning: "#332200"
    property color warningContainer: "#443311"
    property color on_warning_container: "#ffdd88"

    // Info
    property color info: "#77bbff"
    property color on_info: "#002244"
    property color infoContainer: "#113355"
    property color on_info_container: "#aaddff"

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
