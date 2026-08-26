import QtQuick
QtObject {
    // Primary
    readonly property color primary: "#c982ed"
    readonly property color on_primary: "#270637"
    readonly property color primaryContainer: "#411c54"
    readonly property color on_primary_container: "#ddacf6"

    // Secondary
    readonly property color secondary: "#89c7e6"
    readonly property color on_secondary: "#082636"
    readonly property color secondaryContainer: "#1f4151"
    readonly property color on_secondary_container: "#afddf4"

    // Tertiary
    readonly property color tertiary: "#e689c7"
    readonly property color on_tertiary: "#360826"
    readonly property color tertiaryContainer: "#511f41"
    readonly property color on_tertiary_container: "#f4afdd"

    // Background
    readonly property color background: "#1d1820"
    readonly property color on_background: "#e2dae7"

    // Surface hierarchy
    readonly property color surface: "#1d1820"
    readonly property color surfaceDim: "#161018"
    readonly property color surfaceBright: "#413149"
    readonly property color surfaceContainerLowest: "#130e15"
    readonly property color surfaceContainerLow: "#231c27"
    readonly property color surfaceContainer: "#2b2230"
    readonly property color surfaceContainerHigh: "#362a3c"
    readonly property color surfaceContainerHighest: "#44344c"

    // Surface content
    readonly property color on_surface: "#e2dae7"
    readonly property color on_surface_variant: "#bbadc2"
    readonly property color inverseSurface: "#e2dce5"
    readonly property color inverse_on_surface: "#211825"
    readonly property color inversePrimary: "#8c28bd"

    // Outline and overlays
    readonly property color outline: "#786284"
    readonly property color outlineVariant: "#3b2e42"
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
