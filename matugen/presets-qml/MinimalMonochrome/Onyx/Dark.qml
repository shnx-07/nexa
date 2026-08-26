import QtQuick
QtObject {
    // Primary
    readonly property color primary: "#ed8282"
    readonly property color on_primary: "#370606"
    readonly property color primaryContainer: "#541c1c"
    readonly property color on_primary_container: "#f6acac"

    // Secondary
    readonly property color secondary: "#89a8e6"
    readonly property color on_secondary: "#081736"
    readonly property color secondaryContainer: "#1f3051"
    readonly property color on_secondary_container: "#afc6f4"

    // Tertiary
    readonly property color tertiary: "#89e689"
    readonly property color on_tertiary: "#083608"
    readonly property color tertiaryContainer: "#1f511f"
    readonly property color on_tertiary_container: "#aff4af"

    // Background
    readonly property color background: "#201818"
    readonly property color on_background: "#e7dada"

    // Surface hierarchy
    readonly property color surface: "#201818"
    readonly property color surfaceDim: "#181010"
    readonly property color surfaceBright: "#493131"
    readonly property color surfaceContainerLowest: "#150e0e"
    readonly property color surfaceContainerLow: "#271c1c"
    readonly property color surfaceContainer: "#302222"
    readonly property color surfaceContainerHigh: "#3c2a2a"
    readonly property color surfaceContainerHighest: "#4c3434"

    // Surface content
    readonly property color on_surface: "#e7dada"
    readonly property color on_surface_variant: "#c2adad"
    readonly property color inverseSurface: "#e5dcdc"
    readonly property color inverse_on_surface: "#251818"
    readonly property color inversePrimary: "#bd2828"

    // Outline and overlays
    readonly property color outline: "#846262"
    readonly property color outlineVariant: "#422e2e"
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
