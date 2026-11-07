pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    // Primary
    property color primary: "#ffb4a2"
    property color on_primary: "#611200"
    property color primaryContainer: "#891d00"
    property color on_primary_container: "#ffdad2"

    // Secondary
    property color secondary: "#f2bb9a"
    property color on_secondary: "#4a2811"
    property color secondaryContainer: "#643e25"
    property color on_secondary_container: "#ffdbc8"

    // Tertiary
    property color tertiary: "#f5bc7d"
    property color on_tertiary: "#482900"
    property color tertiaryContainer: "#653e09"
    property color on_tertiary_container: "#ffddbb"

    // Background
    property color background: "#1e100c"
    property color on_background: "#f9dcd6"

    // Surface hierarchy
    property color surface: "#1e100c"
    property color surfaceDim: "#1e100c"
    property color surfaceBright: "#473531"

    property color surfaceContainerLowest: "#180b08"
    property color surfaceContainerLow: "#271814"
    property color surfaceContainer: "#2b1c18"
    property color surfaceContainerHigh: "#372622"
    property color surfaceContainerHighest: "#42312c"

    // Surface content
    property color on_surface: "#f9dcd6"
    property color on_surface_variant: "#dcc1ba"

    property color inverseSurface: "#f9dcd6"
    property color inverse_on_surface: "#3d2c28"
    property color inversePrimary: "#b42900"

    // Outline
    property color outline: "#a48b86"
    property color outlineVariant: "#55423e"
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
