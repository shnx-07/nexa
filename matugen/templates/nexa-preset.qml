pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    // Primary
    property color primary: "{{colors.primary}}"
    property color on_primary: "{{colors.on_primary}}"
    property color primaryContainer: "{{colors.primary_container}}"
    property color on_primary_container: "{{colors.on_primary_container}}"

    // Secondary
    property color secondary: "{{colors.secondary}}"
    property color on_secondary: "{{colors.on_secondary}}"
    property color secondaryContainer: "{{colors.secondary_container}}"
    property color on_secondary_container: "{{colors.on_secondary_container}}"

    // Tertiary
    property color tertiary: "{{colors.tertiary}}"
    property color on_tertiary: "{{colors.on_tertiary}}"
    property color tertiaryContainer: "{{colors.tertiary_container}}"
    property color on_tertiary_container: "{{colors.on_tertiary_container}}"

    // Background
    property color background: "{{colors.background}}"
    property color on_background: "{{colors.on_background}}"

    // Surface hierarchy
    property color surface: "{{colors.surface}}"
    property color surfaceDim: "{{colors.surface_dim}}"
    property color surfaceBright: "{{colors.surface_bright}}"

    property color surfaceContainerLowest: "{{colors.surface_container_lowest}}"
    property color surfaceContainerLow: "{{colors.surface_container_low}}"
    property color surfaceContainer: "{{colors.surface_container}}"
    property color surfaceContainerHigh: "{{colors.surface_container_high}}"
    property color surfaceContainerHighest: "{{colors.surface_container_highest}}"

    // Surface content
    property color on_surface: "{{colors.on_surface}}"
    property color on_surface_variant: "{{colors.on_surface_variant}}"

    property color inverseSurface: "{{colors.inverse_surface}}"
    property color inverse_on_surface: "{{colors.inverse_on_surface}}"
    property color inversePrimary: "{{colors.inverse_primary}}"

    // Outline
    property color outline: "{{colors.outline}}"
    property color outlineVariant: "{{colors.outline_variant}}"
    property color shadow: "{{colors.shadow}}"
    property color scrim: "{{colors.scrim}}"

    // Error
    property color error: "{{colors.error}}"
    property color on_error: "{{colors.on_error}}"
    property color errorContainer: "{{colors.error_container}}"
    property color on_error_container: "{{colors.on_error_container}}"

    // Success
    property color success: "{{colors.success}}"
    property color on_success: "{{colors.on_success}}"
    property color successContainer: "{{colors.success_container}}"
    property color on_success_container: "{{colors.on_success_container}}"

    // Warning
    property color warning: "{{colors.warning}}"
    property color on_warning: "{{colors.on_warning}}"
    property color warningContainer: "{{colors.warning_container}}"
    property color on_warning_container: "{{colors.on_warning_container}}"

    // Info
    property color info: "{{colors.info}}"
    property color on_info: "{{colors.on_info}}"
    property color infoContainer: "{{colors.info_container}}"
    property color on_info_container: "{{colors.on_info_container}}"

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
