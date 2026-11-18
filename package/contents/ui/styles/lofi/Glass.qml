pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import "geometry.js" as Geo

// Everything on the window glass: snow on the outer ledge, faint glints, condensation,
// frost, and raindrops that bead, slide down and leave wet trails. The drops are static geometry
// that the shared clock fades, shrinks and moves, not particles. Whatever falls outside the
// panes is hidden by the frame drawn on top.
Item {
    id: root

    property var lay: Geo.layout(1920, 1080)
    property real rain: 0
    property real snow: 0
    property real fog: 0
    property color mist: "#f2f4f8"
    property color glint: "white"
    property color snowColor: "#f6f8ff"
    property real lights: 0
    property real clock: 0

    readonly property real sh: lay.o                          // outside scale, see layout
    readonly property real gb: lay.glass.y + lay.glass.h      // bottom edge of the glass
    readonly property real area: lay.glass.w * lay.glass.h / (sh * sh)

    Shape {   // drifts on the outer ledge grow with snowfall
        anchors.fill: parent
        visible: root.snow > 0.02
        preferredRendererType: Shape.CurveRenderer
        transform: Scale {
            origin.y: root.gb
            yScale: Math.min(1, root.snow * 1.4)
        }
        ShapePath {
            strokeColor: "transparent"
            fillColor: root.snowColor
            PathSvg { path: Geo.ledge(root.lay) }
        }
    }

    Shape {   // slanted glints, fainter at night
        anchors.fill: parent
        opacity: 0.05 - 0.02 * root.lights
        ShapePath {
            strokeColor: "transparent"
            fillColor: root.glint
            PathSvg { path: Geo.reflections(root.lay) }
        }
    }

    Rectangle {   // condensation, heavier towards the bottom
        x: root.lay.glass.x
        y: root.lay.glass.y
        width: root.lay.glass.w
        height: root.lay.glass.h
        opacity: Math.min(0.55, root.fog * 0.3 + root.rain * 0.14 + root.snow * 0.1)
        visible: opacity > 0.01
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.alpha(root.mist, 0.4) }
            GradientStop { position: 1; color: root.mist }
        }
    }

    Item {   // frost: crystals from the edges and a frosted band along the bottom
        anchors.fill: parent
        opacity: Math.min(1, root.snow * 1.5)
        visible: opacity > 0.01

        Rectangle {
            x: root.lay.glass.x
            y: root.gb - root.sh * 0.09
            width: root.lay.glass.w
            height: root.sh * 0.09
            gradient: Gradient {
                GradientStop { position: 0; color: "#00e8f2ff" }
                GradientStop { position: 1; color: "#59e8f2ff" }
            }
        }
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: "#b3e8f2ff"
                strokeWidth: Math.max(1, root.sh * 0.0009)
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathSvg { path: Geo.frost(root.lay) }
            }
        }
    }

    // ---- raindrops ----
    // Beads land in 12 staggered groups on 24 s cycles and evaporate: they shrink and fade, then
    // the group is drawn again from a new seed. The rain level is latched when a cycle begins, so
    // the glass dries group by group within about 24 s after the rain. Heavy drops run down the
    // lower panes in 10 slots per pane column on 16 s cycles, leaving a dotted trail that a
    // growing clip reveals and that fades once the drop is gone. Cycle counts divide the 20 min
    // clock evenly (50 and 75), so every group and slot wraps without a jump.
    readonly property int perGroup: Math.ceil(18 * area * 24 / 12)   // beads per group at full rain
    readonly property int slots: 10 * lay.n

    Repeater {
        model: 12
        Item {
            id: grp
            required property int index
            readonly property real phase: root.clock * 50 + index / 12      // 24 s cycles, 50 per 20 min
            readonly property int cycle: Math.floor(phase) % 50
            readonly property real age: phase - Math.floor(phase)          // 0..1 through the cycle
            property real level: 0                                          // rain when the cycle began
            onCycleChanged: level = root.rain > 0.02 ? root.rain : 0
            Component.onCompleted: level = root.rain > 0.02 ? root.rain : 0
            readonly property var pts: Geo.beads(root.lay, index * 9973 + cycle * 7919 + 1, root.perGroup)
            readonly property int count: Math.round(root.perGroup * level)
            readonly property real shrink: Math.round((1 - 0.65 * age) * 20) / 20   // evaporating; steps keep updates rare
            anchors.fill: parent
            opacity: Math.max(0, Math.min(1, age / 0.02, (1 - age) / 0.15))
            visible: count > 0 && opacity > 0.01

            Repeater {
                model: root.perGroup
                Image {
                    required property int index
                    readonly property var p: grp.pts[index]
                    visible: index < grp.count
                    source: "drop.png"
                    x: p.x - p.s / 2
                    y: p.y - p.s / 2
                    width: p.s
                    height: p.s
                    scale: grp.shrink
                    opacity: 0.85
                    mipmap: true
                }
            }
        }
    }

    Repeater {
        model: root.slots
        Item {
            id: slot
            required property int index
            readonly property real phase: root.clock * 75 + index / root.slots   // 16 s cycles, 75 per 20 min
            readonly property int cycle: Math.floor(phase) % 75
            readonly property real age: (phase - Math.floor(phase)) * 16        // seconds into the cycle
            property bool live: false                                           // latched when the cycle begins
            onCycleChanged: live = root.rain > 0.15 && Geo.rng(index * 7907 + cycle * 3571 + 5)() < root.rain
            readonly property var tr: Geo.trail(root.lay, index * 104729 + cycle * 1299709 + 3)
            readonly property real run: Math.min(age, tr.d)
            anchors.fill: parent
            opacity: age < tr.d ? 1 : Math.max(0, 1 - (age - tr.d) / (16 - tr.d))
            visible: live && opacity > 0.01

            Item {   // reveals the trail down to the drop
                x: slot.tr.left
                y: slot.tr.top
                width: slot.tr.right - slot.tr.left
                height: slot.tr.y0 - slot.tr.top + slot.run * slot.tr.v + slot.tr.size / 2
                clip: true

                Shape {
                    x: -slot.tr.left
                    y: -slot.tr.top
                    width: root.width
                    height: root.height
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        strokeColor: "transparent"
                        fillColor: Qt.alpha("#e4e8f0", 0.5)
                        PathSvg { path: slot.tr.dots }
                    }
                }
            }

            Image {
                source: "slide.png"
                visible: slot.age < slot.tr.d
                width: slot.tr.size
                height: width
                x: Geo.trailX(slot.tr, slot.run) - width / 2
                y: slot.tr.y0 + slot.run * slot.tr.v - height / 2
                opacity: 0.95 * Math.max(0, Math.min(1, slot.age / 0.3, (slot.tr.d - slot.age) / 0.8))
                mipmap: true
            }
        }
    }
}
