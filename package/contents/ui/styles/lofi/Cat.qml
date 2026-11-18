import QtQuick
import QtQuick.Shapes
import "geometry.js" as Geo

// A cat seen from behind, watching the city. It breathes, swishes the tail hanging over
// the sill, twitches an ear now and then and tilts its head at things outside.
Item {
    id: root

    property var lay: Geo.layout(1920, 1080)
    property color fur: "#3a323f"
    property color rim: "#f6e6d0"      // light from the window around the silhouette
    property color shadow: "#6e5a66"
    property bool running: true

    readonly property var g: Geo.cat(lay)

    property real clock: 0             // 0..1 every 20 min, shared with the scene
    // 316 and 231 cycles per 20 min: a 3.8 s breath and a 5.2 s tail swing
    readonly property real breath: 0.5 - 0.5 * Math.cos(2 * Math.PI * root.clock * 316)
    readonly property real swing: Math.sin(2 * Math.PI * root.clock * 231)

    // Event motions run on the shared clock too: each keeps the clock value it started at
    // (-1 = not yet), and its value follows from the seconds since then, sampled at 25 Hz.
    property real twitchLAt: -1
    property real twitchRAt: -1
    property real flickAt: -1
    property real tiltAt: -1
    property real tiltFrom: 0
    property real tiltTo: 0
    readonly property real earL: root.twitch(root.since(root.twitchLAt))
    readonly property real earR: root.twitch(root.since(root.twitchRAt))
    readonly property real flick: root.flickCurve(root.since(root.flickAt))
    readonly property real tilt: {
        const t = root.since(root.tiltAt);
        if (t < 0) return root.tiltTo;
        const x = Math.min(1, t / 0.9);                                    // 900 ms, InOutQuad
        const e = x < 0.5 ? 2 * x * x : 1 - Math.pow(-2 * x + 2, 2) / 2;
        return root.tiltFrom + (root.tiltTo - root.tiltFrom) * e;
    }

    // seconds since a start mark, -1 if it never started; the clock wraps every 20 min
    function since(at) { return at < 0 ? -1 : ((root.clock - at + 1) % 1) * 1200 }
    // ear twitch: up to 16 degrees in 70 ms, back in 200 ms with OutBack
    function twitch(t) {
        if (t < 0 || t >= 0.27) return 0;
        if (t < 0.07) return 16 * t / 0.07;
        const x = (t - 0.07) / 0.2 - 1;
        return 16 * (1 - (1 + 2.70158 * x * x * x + 1.70158 * x * x));
    }
    // tail flick: out in 160 ms (OutQuad), back in 520 ms (InOutSine)
    function flickCurve(t) {
        if (t < 0 || t >= 0.68) return 0;
        if (t < 0.16) { const x = t / 0.16; return 1 - (1 - x) * (1 - x); }
        return 1 - (1 - Math.cos(Math.PI * (t - 0.16) / 0.52)) / 2;
    }

    // a body part rotating about a pivot (ears and tail)
    component Part: Shape {
        id: part
        property string path
        property color fill
        property var pivot: [0, 0]
        property real angle: 0
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        transform: Rotation {
            origin.x: part.pivot[0]
            origin.y: part.pivot[1]
            angle: part.angle
        }
        ShapePath {
            strokeColor: "transparent"
            fillColor: part.fill
            PathSvg { path: part.path }
        }
    }

    // random gaps; the handlers only set start marks, the motion itself follows the clock
    Timer {
        repeat: false
        running: root.running
        interval: 5000
        onTriggered: {
            const p = Math.random();
            if (p < 0.35) root.twitchLAt = root.clock;
            else if (p < 0.7) root.twitchRAt = root.clock;
            else root.flickAt = root.clock;
            interval = 3000 + Math.random() * 9000;
            restart();
        }
    }
    Timer {
        repeat: false
        running: root.running
        interval: 11000
        onTriggered: {
            root.tiltFrom = root.tilt;
            root.tiltTo = Math.random() < 0.35 ? 0 : (Math.random() * 2 - 1) * 9;
            root.tiltAt = root.clock;
            interval = 6000 + Math.random() * 16000;
            restart();
        }
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: "transparent"
            fillColor: Qt.alpha(root.shadow, 0.3)
            PathSvg { path: root.g.shadow }
        }
    }

    Item {   // breathing lifts everything above the haunches
        anchors.fill: parent
        transform: Scale {
            origin.x: root.g.cx
            origin.y: root.g.b
            xScale: 1 + 0.006 * root.breath
            yScale: 1 + 0.014 * root.breath
        }

        Part { path: root.g.bodyRim; fill: root.rim }
        Part { path: root.g.body; fill: root.fur }

        Item {
            anchors.fill: parent
            transform: Rotation {
                origin.x: root.g.headPivot[0]
                origin.y: root.g.headPivot[1]
                angle: root.tilt
            }
            // rims first, so light shows only around the outline of head and ears
            Part { path: root.g.earLRim; fill: root.rim; pivot: root.g.earLPivot; angle: -root.earL }
            Part { path: root.g.earRRim; fill: root.rim; pivot: root.g.earRPivot; angle: root.earR }
            Part { path: root.g.headRim; fill: root.rim }
            Part { path: root.g.earL; fill: root.fur; pivot: root.g.earLPivot; angle: -root.earL }
            Part { path: root.g.earR; fill: root.fur; pivot: root.g.earRPivot; angle: root.earR }
            Part { path: root.g.head; fill: root.fur }
        }
    }

    // tail: from the base of the spine along the sill, then hanging over its edge
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: root.fur
            strokeWidth: root.g.tailW
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathSvg { path: root.g.tailLie }
        }
    }
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        transform: Rotation {
            origin.x: root.g.tailPivot[0]
            origin.y: root.g.tailPivot[1]
            angle: root.swing * 9 + root.flick * 16
        }
        ShapePath {
            strokeColor: root.fur
            strokeWidth: root.g.tailW
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathSvg { path: root.g.tailHang }
        }
    }
}
