import QtQuick
import QtQuick.Shapes
import "geometry.js" as Geo
import "palette.js" as Pal

// One skyline layer: silhouettes, dark glass, lit windows in four colours, blinking
// antenna beacons and, on the near layer, a handful of windows switching on and off.
Item {
    id: root

    property var lay: Geo.layout(1920, 1080)
    property bool near: false
    property color body: "#5b4f80"
    property color glass: "#3a3360"
    property real lights: 0        // 0 day .. 1 night
    property real clock: 0
    property bool running: true

    readonly property var g: Geo.city(lay, near)

    // thousands of axis-aligned rects: the default renderer is fast and needs no smoothing
    Shape {
        anchors.fill: parent
        ShapePath {
            strokeColor: "transparent"
            fillColor: root.body
            fillRule: ShapePath.WindingFill
            PathSvg { path: root.g.body }
        }
        ShapePath {
            strokeColor: "transparent"
            fillColor: root.glass
            PathSvg { path: root.g.glass }
        }
    }

    Shape {
        anchors.fill: parent
        opacity: root.lights * (root.near ? 1 : 0.8)
        visible: opacity > 0.01
        ShapePath { strokeColor: "transparent"; fillColor: Pal.LIT[0]; PathSvg { path: root.g.lit[0] } }
        ShapePath { strokeColor: "transparent"; fillColor: Pal.LIT[1]; PathSvg { path: root.g.lit[1] } }
        ShapePath { strokeColor: "transparent"; fillColor: Pal.LIT[2]; PathSvg { path: root.g.lit[2] } }
        ShapePath { strokeColor: "transparent"; fillColor: Pal.LIT[3]; PathSvg { path: root.g.lit[3] } }
    }

    // windows that change state now and then; each covers a lit window of the static layer. They
    // switch on and off at once, as real lights do; a fade would redraw the wallpaper at display rate.
    Repeater {
        id: flick
        model: root.near ? root.g.flick : []
        Rectangle {
            id: win
            required property var modelData
            property bool lit: Math.random() < 0.6

            x: modelData.x
            y: modelData.y
            width: modelData.w
            height: modelData.h
            color: root.glass
            visible: root.lights > 0.01

            Rectangle {
                anchors.fill: parent
                color: Pal.LIT[win.modelData.c]
                opacity: win.lit ? root.lights : 0
            }
        }
    }

    Timer {
        repeat: false
        running: root.near && root.running && root.lights > 0.2
        interval: 4000
        onTriggered: {
            const w = flick.itemAt(Math.floor(Math.random() * flick.count));
            if (w)
                w.lit = !w.lit;
            interval = 2500 + Math.random() * 7000;
            restart();
        }
    }

    // aviation beacons: two groups blinking out of step, always on but faint by day
    Repeater {
        model: 2
        Shape {
            id: beacons
            required property int index
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            // 900 cycles per 20 min: one blink every 1.3 s
            opacity: (0.15 + 0.85 * root.lights) * (((root.clock * 900 + index * 0.5) % 1) < 0.35 ? 1 : 0.12)
            ShapePath {
                strokeColor: "transparent"
                fillColor: "#40ff4d4d"
                fillRule: ShapePath.WindingFill
                PathSvg { path: root.g.halo[beacons.index] }
            }
            ShapePath {
                strokeColor: "transparent"
                fillColor: "#ff4d4d"
                fillRule: ShapePath.WindingFill
                PathSvg { path: root.g.beacon[beacons.index] }
            }
        }
    }
}
