import QtQuick
import "geometry.js" as Geo
import "palette.js" as Pal

// A pothos in a macrame hanger in the window, swaying a little in the warm air from the radiator.
Item {
    id: root

    property var lay: Geo.layout(1920, 1080)
    property var c: Pal.room(0.3, 0)
    property real clock: 0

    readonly property var g: Geo.hanger(lay)

    Paint {
        anchors.fill: parent
        c: root.c
        ops: root.g.ops
        // 150 swings per 20 min: one every 8 s
        transform: Rotation {
            origin.x: root.g.hx
            origin.y: root.g.hy
            angle: 1.2 * Math.sin(2 * Math.PI * root.clock * 150)
        }
    }
}
