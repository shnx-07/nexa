import QtQuick
QtObject {
    // Primary
    readonly property color primary: "#8bed82"
    readonly property color on_primary: "#0a3706"
    readonly property color primaryContainer: "#21541c"
    readonly property color on_primary_container: "#b2f6ac"

    // Secondary
    readonly property color secondary: "#bfe689"
    readonly property color on_secondary: "#223608"
    readonly property color secondaryContainer: "#3c511f"
    readonly property color on_secondary_container: "#d7f4af"

    // Tertiary
    readonly property color tertiary: "#e6cf89"
    readonly property color on_tertiary: "#362a08"
    readonly property color tertiaryContainer: "#51451f"
    readonly property color on_tertiary_container: "#f4e2af"

    // Background
    readonly property color background: "#192018"
    readonly property color on_background: "#dbe7da"

    // Surface hierarchy
    readonly property color surface: "#192018"
    readonly property color surfaceDim: "#111810"
    readonly property color surfaceBright: "#334931"
    readonly property color surfaceContainerLowest: "#0f150e"
    readonly property color surfaceContainerLow: "#1c271c"
    readonly property color surfaceContainer: "#233022"
    readonly property color surfaceContainerHigh: "#2b3c2a"
    readonly property color surfaceContainerHighest: "#364c34"

    // Surface content
    readonly property color on_surface: "#dbe7da"
    readonly property color on_surface_variant: "#afc2ad"
    readonly property color inverseSurface: "#dde5dc"
    readonly property color inverse_on_surface: "#1a2518"
    readonly property color inversePrimary: "#35bd28"

    // Outline and overlays
    readonly property color outline: "#648462"
    readonly property color outlineVariant: "#30422e"
    readonly property color shadow: "#000000"
    readonly property color scrim: "#000000"

    // Error
    readonly property color error: "#f0757f"
    readonly property color on_error: "#37060a"
    readonly property color errorContainer: "#541c21"
    readonly property color on_error_container: "#f8aab1"

    // Success
    readonly property color success: "#78e29c"
    readonly property color on_success: "#083617"
    readonly property color successContainer: "#1c4a2b"
    readonly property color on_success_container: "#a6f2bf"

    // Warning
    readonly property color warning: "#efc36c"
    readonly property color on_warning: "#372706"
    readonly property color warningContainer: "#4d3c19"
    readonly property color on_warning_container: "#f7daa1"

    // Information
    readonly property color info: "#79cfec"
    readonly property color on_info: "#062b37"
    readonly property color infoContainer: "#1c3e4a"
    readonly property color on_info_container: "#a3e0f5"
}
