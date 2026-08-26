import QtQuick
QtObject {
    // Primary
    readonly property color primary: "#edc182"
    readonly property color on_primary: "#372306"
    readonly property color primaryContainer: "#543d1c"
    readonly property color on_primary_container: "#f6d7ac"

    // Secondary
    readonly property color secondary: "#e6b089"
    readonly property color on_secondary: "#361b08"
    readonly property color secondaryContainer: "#51341f"
    readonly property color on_secondary_container: "#f4cbaf"

    // Tertiary
    readonly property color tertiary: "#89e6e6"
    readonly property color on_tertiary: "#083636"
    readonly property color tertiaryContainer: "#1f5151"
    readonly property color on_tertiary_container: "#aff4f4"

    // Background
    readonly property color background: "#201d18"
    readonly property color on_background: "#e7e1da"

    // Surface hierarchy
    readonly property color surface: "#201d18"
    readonly property color surfaceDim: "#181510"
    readonly property color surfaceBright: "#493f31"
    readonly property color surfaceContainerLowest: "#15120e"
    readonly property color surfaceContainerLow: "#27221c"
    readonly property color surfaceContainer: "#302a22"
    readonly property color surfaceContainerHigh: "#3c352a"
    readonly property color surfaceContainerHighest: "#4c4234"

    // Surface content
    readonly property color on_surface: "#e7e1da"
    readonly property color on_surface_variant: "#c2b9ad"
    readonly property color inverseSurface: "#e5e1dc"
    readonly property color inverse_on_surface: "#252018"
    readonly property color inversePrimary: "#bd7f28"

    // Outline and overlays
    readonly property color outline: "#847662"
    readonly property color outlineVariant: "#423a2e"
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
