import QtQuick
import QtQuick.Shapes
import "../../../NewNexaUI" as NexaUI

// Chamfered HUD background for shell pieces under the HUD desktop theme: a
// fill and hairline with the top-left and bottom-right corners cut, and an
// accent tick along the top-left chamfer. Drawn directly (no layer), so it
// suits items whose own colour is internal; for items whose colour is set by
// their users, mask them with HudMask instead.
Shape {
    id: frame

    property real cut: 8
    property color fill: NexaUI.NexaColors.surfaceContainer
    property color stroke: NexaUI.NexaColors.withAlpha(NexaUI.NexaColors.onSurface, 0.12)
    property real strokeWidth: 1
    property bool tick: true
    property color tickColor: NexaUI.NexaColors.primary

    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
        fillColor: frame.fill
        strokeColor: frame.stroke
        strokeWidth: frame.strokeWidth
        joinStyle: ShapePath.MiterJoin
        startX: frame.cut
        startY: 0.5
        PathLine { x: frame.width - 0.5; y: 0.5 }
        PathLine { x: frame.width - 0.5; y: frame.height - frame.cut }
        PathLine { x: frame.width - frame.cut; y: frame.height - 0.5 }
        PathLine { x: 0.5; y: frame.height - 0.5 }
        PathLine { x: 0.5; y: frame.cut }
        PathLine { x: frame.cut; y: 0.5 }
    }

    ShapePath {
        fillColor: "transparent"
        strokeColor: frame.tick ? frame.tickColor : "transparent"
        strokeWidth: 1.5
        capStyle: ShapePath.FlatCap
        joinStyle: ShapePath.MiterJoin
        startX: 0.75
        startY: frame.cut + 7
        PathLine { x: 0.75; y: frame.cut }
        PathLine { x: frame.cut; y: 0.75 }
        PathLine { x: frame.cut + 12; y: 0.75 }
    }
}
