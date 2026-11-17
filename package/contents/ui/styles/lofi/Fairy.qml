pragma ComponentBehavior: Bound
import QtQuick
import "palette.js" as Pal

// Fairy lights: warm bulbs with a soft glow, faint by day and bright at night, each one
// shimmering at its own phase on the shared clock.
Item {
    id: root

    property var bulbs: []
    property real size: 6
    property real lights: 0
    property real clock: 0

    Repeater {
        model: root.bulbs
        Item {
            id: bulb
            required property var modelData
            readonly property real s: root.size
            readonly property color tint: Pal.BULBS[modelData.c]

            x: modelData.x
            y: modelData.y
            // 260 cycles per 20 min: a slow 4.6 s shimmer
            opacity: (0.35 + 0.65 * root.lights) * (0.6 + 0.4 * Math.sin(2 * Math.PI * (root.clock * 260 + modelData.p)))

            Rectangle {
                width: bulb.s * 4.8
                height: width
                radius: width / 2
                x: -width / 2
                y: -height / 2
                color: Qt.alpha(bulb.tint, 0.12 * root.lights)
            }
            Rectangle {
                width: bulb.s * 2.6
                height: width
                radius: width / 2
                x: -width / 2
                y: -height / 2
                color: Qt.alpha(bulb.tint, 0.25 * root.lights)
            }
            Rectangle {
                width: bulb.s
                height: bulb.s * 1.3
                radius: width / 2
                x: -width / 2
                y: -height / 2
                color: bulb.tint
                antialiasing: true
            }
        }
    }
}
