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

    property real breath: 0
    property real swing: -1
    property real flick: 0
    property real tilt: 0
    property real earL: 0
    property real earR: 0

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

    SequentialAnimation on breath {
        loops: Animation.Infinite
        running: true
        paused: running && !root.running
        NumberAnimation { to: 1; duration: 1700; easing.type: Easing.InOutSine }
        NumberAnimation { to: 0; duration: 2100; easing.type: Easing.InOutSine }
    }
    SequentialAnimation on swing {
        loops: Animation.Infinite
        running: true
        paused: running && !root.running
        NumberAnimation { to: 1; duration: 2600; easing.type: Easing.InOutSine }
        NumberAnimation { to: -1; duration: 2600; easing.type: Easing.InOutSine }
    }

    SequentialAnimation {
        id: twitchL
        paused: running && !root.running
        NumberAnimation { target: root; property: "earL"; to: 16; duration: 70 }
        NumberAnimation { target: root; property: "earL"; to: 0; duration: 200; easing.type: Easing.OutBack }
    }
    SequentialAnimation {
        id: twitchR
        paused: running && !root.running
        NumberAnimation { target: root; property: "earR"; to: 16; duration: 70 }
        NumberAnimation { target: root; property: "earR"; to: 0; duration: 200; easing.type: Easing.OutBack }
    }
    SequentialAnimation {
        id: flickAnim
        paused: running && !root.running
        NumberAnimation { target: root; property: "flick"; to: 1; duration: 160; easing.type: Easing.OutQuad }
        NumberAnimation { target: root; property: "flick"; to: 0; duration: 520; easing.type: Easing.InOutSine }
    }
    NumberAnimation {
        id: tiltAnim
        target: root
        property: "tilt"
        duration: 900
        easing.type: Easing.InOutQuad
        paused: running && !root.running
    }

    // random gaps, set from the handlers, never from inside an animation
    Timer {
        repeat: false
        running: root.running
        interval: 5000
        onTriggered: {
            const p = Math.random();
            (p < 0.35 ? twitchL : p < 0.7 ? twitchR : flickAnim).restart();
            interval = 3000 + Math.random() * 9000;
            restart();
        }
    }
    Timer {
        repeat: false
        running: root.running
        interval: 11000
        onTriggered: {
            tiltAnim.to = Math.random() < 0.35 ? 0 : (Math.random() * 2 - 1) * 9;
            tiltAnim.restart();
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
