import QtQuick
QtObject {
    // Primary
    readonly property color primary: "#af82ed"
    readonly property color on_primary: "#1b0637"
    readonly property color primaryContainer: "#331c54"
    readonly property color on_primary_container: "#cbacf6"

    // Secondary
    readonly property color secondary: "#89a8e6"
    readonly property color on_secondary: "#081736"
    readonly property color secondaryContainer: "#1f3051"
    readonly property color on_secondary_container: "#afc6f4"

    // Tertiary
    readonly property color tertiary: "#e689c7"
    readonly property color on_tertiary: "#360826"
    readonly property color tertiaryContainer: "#511f41"
    readonly property color on_tertiary_container: "#f4afdd"

    // Background
    readonly property color background: "#1b1820"
    readonly property color on_background: "#dfdae7"

    // Surface hierarchy
    readonly property color surface: "#1b1820"
    readonly property color surfaceDim: "#141018"
    readonly property color surfaceBright: "#3b3149"
    readonly property color surfaceContainerLowest: "#110e15"
    readonly property color surfaceContainerLow: "#201c27"
    readonly property color surfaceContainer: "#282230"
    readonly property color surfaceContainerHigh: "#312a3c"
    readonly property color surfaceContainerHighest: "#3e344c"

    // Surface content
    readonly property color on_surface: "#dfdae7"
    readonly property color on_surface_variant: "#b6adc2"
    readonly property color inverseSurface: "#e0dce5"
    readonly property color inverse_on_surface: "#1e1825"
    readonly property color inversePrimary: "#6628bd"

    // Outline and overlays
    readonly property color outline: "#706284"
    readonly property color outlineVariant: "#362e42"
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
