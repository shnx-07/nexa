pragma Singleton
import QtQuick
import Quickshell
import "../../NewNexaUI" as NexaUI

// Palette and type for the lock screen HUD. The HUD always sits on a darkened
// backdrop, so on a light matugen scheme the ink/base roles flip to their
// inverse and the accents use the *_fixed_dim tones, which are the same in
// light and dark schemes.
Singleton {
    id: root

    readonly property string display: "Orbitron"
    readonly property string mono: "JetBrainsMono Nerd Font"
    readonly property string icons: "Material Symbols Rounded"

    readonly property bool dark: Qt.color(NexaUI.NexaColors.background).hslLightness < 0.5

    readonly property color base: dark ? NexaUI.NexaColors.background : NexaUI.NexaColors.inverseSurface
    readonly property color ink: dark ? NexaUI.NexaColors.onSurface : NexaUI.NexaColors.inverseOnSurface
    readonly property color inkDim: NexaUI.NexaColors.withAlpha(ink, 0.62)
    readonly property color inkFaint: NexaUI.NexaColors.withAlpha(ink, 0.32)
    readonly property color accent: NexaUI.NexaColors.primary
    readonly property color accentSoft: NexaUI.NexaColors.withAlpha(accent, 0.18)
    readonly property color gold: NexaUI.NexaColors.tertiary
    readonly property color danger: dark ? NexaUI.NexaColors.error : "#ffb4ab"
    readonly property color panel: NexaUI.NexaColors.withAlpha(base, 0.58)
    readonly property color panelHi: NexaUI.NexaColors.withAlpha(base, 0.78)
    readonly property color line: NexaUI.NexaColors.withAlpha(ink, 0.14)

    function alpha(c, a) {
        return NexaUI.NexaColors.withAlpha(c, a);
    }

    // Eased 0..1 slice of a 0..1 timeline: how far an element whose entrance
    // runs from `from` to `to` has got when the whole choreography is at `p`.
    function seg(p, from, to) {
        const x = Math.max(0, Math.min(1, (p - from) / (to - from)));
        return 1 - Math.pow(1 - x, 3);
    }
}
