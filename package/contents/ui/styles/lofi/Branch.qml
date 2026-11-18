import QtQuick
import QtQuick.Shapes
import "geometry.js" as Geo
import "palette.js" as Pal

// A tree branch reaching into view from the top right: blossom in spring, leaves in
// summer and autumn, snow in winter. Sways about its base, more in wind.
Item {
    id: root

    property var lay: Geo.layout(1920, 1080)
    property int month: 5
    property real elevation: 0.3
    property real overcast: 0
    property color snowColor: "#f6f8ff"
    property real windX: 0
    property bool running: true

    readonly property var g: Geo.branch(lay, month)
    readonly property var c: Pal.branch(g.season, elevation, overcast)

    property real clock: 0
    // 167 cycles per 20 min: a 7.2 s sway
    readonly property real swing: Math.sin(2 * Math.PI * root.clock * 167)

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        transform: Rotation {
            origin.x: root.g.ax
            origin.y: root.g.ay
            angle: root.swing * (0.5 + 1.8 * Math.abs(root.windX))
        }

        ShapePath {
            strokeColor: "transparent"
            fillColor: root.c.wood
            fillRule: ShapePath.WindingFill
            PathSvg { path: root.g.wood }
        }
        ShapePath {
            strokeColor: "transparent"
            fillColor: root.c.leaf[0]
            fillRule: ShapePath.WindingFill
            PathSvg { path: root.g.leaf[0] }
        }
        ShapePath {
            strokeColor: "transparent"
            fillColor: root.c.leaf[1]
            fillRule: ShapePath.WindingFill
            PathSvg { path: root.g.leaf[1] }
        }
        ShapePath {
            strokeColor: "transparent"
            fillColor: root.c.leaf[2]
            fillRule: ShapePath.WindingFill
            PathSvg { path: root.g.leaf[2] }
        }
        ShapePath {
            strokeColor: "transparent"
            fillColor: root.c.petal
            fillRule: ShapePath.WindingFill
            PathSvg { path: root.g.petals }
        }
        ShapePath {
            strokeColor: "transparent"
            fillColor: root.c.center
            fillRule: ShapePath.WindingFill
            PathSvg { path: root.g.centers }
        }
        ShapePath {
            strokeColor: root.snowColor
            strokeWidth: root.lay.o * 0.006
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: root.g.snow }
        }
    }
}
