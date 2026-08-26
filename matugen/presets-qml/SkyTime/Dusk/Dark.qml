import QtQuick
QtObject {
    // Primary
    readonly property color primary: "#b882ed"
    readonly property color on_primary: "#1f0637"
    readonly property color primaryContainer: "#381c54"
    readonly property color on_primary_container: "#d1acf6"

    // Secondary
    readonly property color secondary: "#e689c7"
    readonly property color on_secondary: "#360826"
    readonly property color secondaryContainer: "#511f41"
    readonly property color on_secondary_container: "#f4afdd"

    // Tertiary
    readonly property color tertiary: "#e6bf89"
    readonly property color on_tertiary: "#362208"
    readonly property color tertiaryContainer: "#513c1f"
    readonly property color on_tertiary_container: "#f4d7af"

    // Background
    readonly property color background: "#1c1820"
    readonly property color on_background: "#e0dae7"

    // Surface hierarchy
    readonly property color surface: "#1c1820"
    readonly property color surfaceDim: "#141018"
    readonly property color surfaceBright: "#3d3149"
    readonly property color surfaceContainerLowest: "#120e15"
    readonly property color surfaceContainerLow: "#211c27"
    readonly property color surfaceContainer: "#292230"
    readonly property color surfaceContainerHigh: "#332a3c"
    readonly property color surfaceContainerHighest: "#40344c"

    // Surface content
    readonly property color on_surface: "#e0dae7"
    readonly property color on_surface_variant: "#b8adc2"
    readonly property color inverseSurface: "#e0dce5"
    readonly property color inverse_on_surface: "#1f1825"
    readonly property color inversePrimary: "#7328bd"

    // Outline and overlays
    readonly property color outline: "#736284"
    readonly property color outlineVariant: "#382e42"
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
