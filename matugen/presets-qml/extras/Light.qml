import QtQuick

QtObject {
    // Primary
    readonly property color primary: "#6750a4"
    readonly property color on_primary: "#ffffff"
    readonly property color primaryContainer: "#eaddff"
    readonly property color on_primary_container: "#21005d"

    // Secondary
    readonly property color secondary: "#625b71"
    readonly property color on_secondary: "#ffffff"
    readonly property color secondaryContainer: "#e8def8"
    readonly property color on_secondary_container: "#1d192b"

    // Tertiary
    readonly property color tertiary: "#7d5260"
    readonly property color on_tertiary: "#ffffff"
    readonly property color tertiaryContainer: "#ffd8e4"
    readonly property color on_tertiary_container: "#31111d"

    // Background
    readonly property color background: "#fffbfe"
    readonly property color on_background: "#1d1b20"

    // Surface hierarchy
    readonly property color surface: "#fffbfe"
    readonly property color surfaceDim: "#ded8e1"
    readonly property color surfaceBright: "#fffbfe"

    readonly property color surfaceContainerLowest: "#ffffff"
    readonly property color surfaceContainerLow: "#f7f2fa"
    readonly property color surfaceContainer: "#f3edf7"
    readonly property color surfaceContainerHigh: "#ece6f0"
    readonly property color surfaceContainerHighest: "#e6e0e9"

    // Surface content
    readonly property color on_surface: "#1d1b20"
    readonly property color on_surface_variant: "#49454f"

    readonly property color inverseSurface: "#322f35"
    readonly property color inverse_on_surface: "#f5eff7"
    readonly property color inversePrimary: "#d0bcff"

    // Outline and overlays
    readonly property color outline: "#79747e"
    readonly property color outlineVariant: "#cac4d0"
    readonly property color shadow: "#000000"
    readonly property color scrim: "#000000"

    // Error
    readonly property color error: "#b3261e"
    readonly property color on_error: "#ffffff"
    readonly property color errorContainer: "#f9dedc"
    readonly property color on_error_container: "#410e0b"

    // Success
    readonly property color success: "#2e7d32"
    readonly property color on_success: "#ffffff"
    readonly property color successContainer: "#c8e6c9"
    readonly property color on_success_container: "#0d3b12"

    // Warning
    readonly property color warning: "#9a6700"
    readonly property color on_warning: "#ffffff"
    readonly property color warningContainer: "#ffe08a"
    readonly property color on_warning_container: "#2f2000"

    // Information
    readonly property color info: "#1967d2"
    readonly property color on_info: "#ffffff"
    readonly property color infoContainer: "#d4e3ff"
    readonly property color on_info_container: "#001b3f"
}
