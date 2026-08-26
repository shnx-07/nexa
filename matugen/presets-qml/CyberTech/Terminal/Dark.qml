import QtQuick
QtObject {
    // Primary
    readonly property color primary: "#82ed8b"
    readonly property color on_primary: "#06370a"
    readonly property color primaryContainer: "#1c5421"
    readonly property color on_primary_container: "#acf6b2"

    // Secondary
    readonly property color secondary: "#89cfe6"
    readonly property color on_secondary: "#082a36"
    readonly property color secondaryContainer: "#1f4551"
    readonly property color on_secondary_container: "#afe2f4"

    // Tertiary
    readonly property color tertiary: "#bfe689"
    readonly property color on_tertiary: "#223608"
    readonly property color tertiaryContainer: "#3c511f"
    readonly property color on_tertiary_container: "#d7f4af"

    // Background
    readonly property color background: "#182019"
    readonly property color on_background: "#dae7db"

    // Surface hierarchy
    readonly property color surface: "#182019"
    readonly property color surfaceDim: "#101811"
    readonly property color surfaceBright: "#314933"
    readonly property color surfaceContainerLowest: "#0e150f"
    readonly property color surfaceContainerLow: "#1c271c"
    readonly property color surfaceContainer: "#223023"
    readonly property color surfaceContainerHigh: "#2a3c2b"
    readonly property color surfaceContainerHighest: "#344c36"

    // Surface content
    readonly property color on_surface: "#dae7db"
    readonly property color on_surface_variant: "#adc2af"
    readonly property color inverseSurface: "#dce5dd"
    readonly property color inverse_on_surface: "#18251a"
    readonly property color inversePrimary: "#28bd35"

    // Outline and overlays
    readonly property color outline: "#628464"
    readonly property color outlineVariant: "#2e4230"
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
