import QtQuick
QtObject {
    // Primary
    readonly property color primary: "#829ded"
    readonly property color on_primary: "#061237"
    readonly property color primaryContainer: "#1c2a54"
    readonly property color on_primary_container: "#acbff6"

    // Secondary
    readonly property color secondary: "#9189e6"
    readonly property color on_secondary: "#0b0836"
    readonly property color secondaryContainer: "#231f51"
    readonly property color on_secondary_container: "#b4aff4"

    // Tertiary
    readonly property color tertiary: "#89cfe6"
    readonly property color on_tertiary: "#082a36"
    readonly property color tertiaryContainer: "#1f4551"
    readonly property color on_tertiary_container: "#afe2f4"

    // Background
    readonly property color background: "#181a20"
    readonly property color on_background: "#dadde7"

    // Surface hierarchy
    readonly property color surface: "#181a20"
    readonly property color surfaceDim: "#101218"
    readonly property color surfaceBright: "#313749"
    readonly property color surfaceContainerLowest: "#0e1015"
    readonly property color surfaceContainerLow: "#1c1e27"
    readonly property color surfaceContainer: "#222530"
    readonly property color surfaceContainerHigh: "#2a2e3c"
    readonly property color surfaceContainerHighest: "#343a4c"

    // Surface content
    readonly property color on_surface: "#dadde7"
    readonly property color on_surface_variant: "#adb2c2"
    readonly property color inverseSurface: "#dcdee5"
    readonly property color inverse_on_surface: "#181c25"
    readonly property color inversePrimary: "#284dbd"

    // Outline and overlays
    readonly property color outline: "#626a84"
    readonly property color outlineVariant: "#2e3342"
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
