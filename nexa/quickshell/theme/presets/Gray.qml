import QtQuick

QtObject {
    // Primary
    readonly property color primary: "#c7c7d1"
    readonly property color on_primary: "#2f3038"
    readonly property color primaryContainer: "#464750"
    readonly property color on_primary_container: "#e3e2ec"

    // Secondary
    readonly property color secondary: "#c6c6cc"
    readonly property color on_secondary: "#303036"
    readonly property color secondaryContainer: "#47474d"
    readonly property color on_secondary_container: "#e2e1e7"

    // Tertiary
    readonly property color tertiary: "#c8c5ca"
    readonly property color on_tertiary: "#313033"
    readonly property color tertiaryContainer: "#484649"
    readonly property color on_tertiary_container: "#e5e1e6"

    // Background
    readonly property color background: "#171719"
    readonly property color on_background: "#e5e1e6"

    // Surface hierarchy
    readonly property color surface: "#171719"
    readonly property color surfaceDim: "#171719"
    readonly property color surfaceBright: "#3d3b3e"

    readonly property color surfaceContainerLowest: "#111113"
    readonly property color surfaceContainerLow: "#1f1f21"
    readonly property color surfaceContainer: "#242426"
    readonly property color surfaceContainerHigh: "#2e2e30"
    readonly property color surfaceContainerHighest: "#39383b"

    // Surface content
    readonly property color on_surface: "#e5e1e6"
    readonly property color on_surface_variant: "#c9c5ca"

    readonly property color inverseSurface: "#e5e1e6"
    readonly property color inverse_on_surface: "#323033"
    readonly property color inversePrimary: "#5e5f68"

    // Outline and overlays
    readonly property color outline: "#939095"
    readonly property color outlineVariant: "#49474b"
    readonly property color shadow: "#000000"
    readonly property color scrim: "#000000"

    // Error
    readonly property color error: "#f2b8b5"
    readonly property color on_error: "#601410"
    readonly property color errorContainer: "#8c1d18"
    readonly property color on_error_container: "#f9dedc"

    // Success
    readonly property color success: "#9bc7a6"
    readonly property color on_success: "#123820"
    readonly property color successContainer: "#294f36"
    readonly property color on_success_container: "#b7e4c1"

    // Warning
    readonly property color warning: "#d8bf7a"
    readonly property color on_warning: "#3c3005"
    readonly property color warningContainer: "#554718"
    readonly property color on_warning_container: "#f5dc94"

    // Information
    readonly property color info: "#a8bedc"
    readonly property color on_info: "#19324e"
    readonly property color infoContainer: "#304963"
    readonly property color on_info_container: "#c7ddfb"
}
