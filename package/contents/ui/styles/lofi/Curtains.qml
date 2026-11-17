import QtQuick
import "geometry.js" as Geo
import "palette.js" as Pal

// Curtains tied back on both sides of the window, the rod, and fairy lights draped along it.
Item {
    id: root

    property var lay: Geo.layout(1920, 1080)
    property var c: Pal.room(0.3, 0)
    property real lights: 0
    property real clock: 0

    readonly property var garland: Geo.garland(lay)

    Paint {
        anchors.fill: parent
        c: root.c
        ops: Geo.curtains(root.lay)
    }
    Paint {
        anchors.fill: parent
        c: root.c
        ops: root.garland.ops
    }
    Fairy {
        anchors.fill: parent
        bulbs: root.garland.bulbs
        size: root.garland.size
        lights: root.lights
        clock: root.clock
    }
}
