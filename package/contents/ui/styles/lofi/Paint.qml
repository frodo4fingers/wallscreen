pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes

// Draws a geometry.js draw list in order. Each op is { d: SVG path, c: palette key, a: alpha,
// w: stroke width, 0 = fill }; colours come from the palette object c.
Item {
    id: root

    property var ops: []
    property var c: ({})

    Repeater {
        model: root.ops
        Shape {
            id: s
            required property var modelData
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                readonly property color col: Qt.alpha(root.c[s.modelData.c] ?? "transparent", s.modelData.a)
                fillColor: s.modelData.w > 0 ? "transparent" : col
                strokeColor: s.modelData.w > 0 ? col : "transparent"
                strokeWidth: Math.max(1, s.modelData.w)
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                fillRule: ShapePath.WindingFill
                PathSvg { path: s.modelData.d }
            }
        }
    }
}
