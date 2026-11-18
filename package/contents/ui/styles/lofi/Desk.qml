pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import "geometry.js" as Geo
import "palette.js" as Pal

// The desk and what stands on it. The lamp throws a cone and a warm pool onto the notebook,
// steam rises from the mug in a few soft puffs, music notes drift up from the radio, whose
// light pulses to the beat, and a jar of fairy lights glows at the right end. Puffs and
// notes follow the shared clock; the still parts are cached in one layer.
Item {
    id: root

    property var lay: Geo.layout(1920, 1080)
    property var c: Pal.room(0.3, 0)
    property real lamp: 0            // desk lamp, 0 off .. 1 on
    property real lights: 0          // fairy lights, 0 day .. 1 night
    property real clock: 0
    property bool running: true

    readonly property var d: Geo.desk(lay)
    readonly property var lt: d.light
    readonly property real u: lay.u

    // static (changes only on palette steps), drawn once and cached
    Item {
        anchors.fill: parent
        layer.enabled: true

        Paint {
            anchors.fill: parent
            c: root.c
            ops: root.d.surface
        }

        Shape {   // pool of lamp light: a radial gradient squashed onto the desk
            anchors.fill: parent
            opacity: root.lamp
            visible: opacity > 0.01
            transform: Scale {
                origin.y: root.lt.py
                yScale: root.lt.ry / root.lt.rx
            }
            ShapePath {
                strokeColor: "transparent"
                fillGradient: RadialGradient {
                    centerX: root.lt.px
                    centerY: root.lt.py
                    centerRadius: root.lt.rx
                    focalX: root.lt.px
                    focalY: root.lt.py
                    GradientStop { position: 0; color: Qt.alpha("#ffc27a", 0.55) }
                    GradientStop { position: 0.5; color: Qt.alpha("#ffb066", 0.2) }
                    GradientStop { position: 1; color: Qt.alpha("#ffb066", 0) }
                }
                PathSvg { path: Geo.circle(root.lt.px, root.lt.py, root.lt.rx) }
            }
        }

        Paint {
            anchors.fill: parent
            c: root.c
            ops: root.d.items
        }

        // ---- jar of fairy lights ----
        Shape {
            anchors.fill: parent
            opacity: root.lights
            visible: root.d.jar.r > 0 && opacity > 0.01
            ShapePath {
                strokeColor: "transparent"
                fillGradient: RadialGradient {
                    centerX: root.d.jar.x
                    centerY: root.d.jar.y
                    centerRadius: root.d.jar.r
                    focalX: root.d.jar.x
                    focalY: root.d.jar.y
                    GradientStop { position: 0; color: Qt.alpha("#ffc47e", 0.35) }
                    GradientStop { position: 1; color: Qt.alpha("#ffc47e", 0) }
                }
                PathSvg { path: Geo.circle(root.d.jar.x, root.d.jar.y, root.d.jar.r) }
            }
        }

        // ---- the lamp's light: lit shade and bulb, a soft cone, a glow round the shade ----
        Item {
            anchors.fill: parent
            opacity: root.lamp
            visible: opacity > 0.01

            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath { strokeColor: "transparent"; fillColor: "#ffe9bf"; PathSvg { path: root.d.mouth } }
                ShapePath { strokeColor: "transparent"; fillColor: "#fffaf0"; PathSvg { path: root.d.bulb } }
            }
            Shape {
                anchors.fill: parent
                opacity: 0.8
                ShapePath {
                    strokeColor: "transparent"
                    fillGradient: LinearGradient {
                        x1: root.lt.mx
                        y1: root.lt.my
                        x2: root.lt.px
                        y2: root.lt.py
                        GradientStop { position: 0; color: Qt.alpha("#ffd9a0", 0.35) }
                        GradientStop { position: 1; color: Qt.alpha("#ffd9a0", 0) }
                    }
                    PathSvg { path: root.d.cone }
                }
            }
            Shape {
                anchors.fill: parent
                ShapePath {
                    strokeColor: "transparent"
                    fillGradient: RadialGradient {
                        centerX: root.lt.mx
                        centerY: root.lt.my
                        centerRadius: root.lt.glow
                        focalX: root.lt.mx
                        focalY: root.lt.my
                        GradientStop { position: 0; color: Qt.alpha("#ffc47e", 0.4) }
                        GradientStop { position: 0.35; color: Qt.alpha("#ffb070", 0.12) }
                        GradientStop { position: 1; color: Qt.alpha("#ffb070", 0) }
                    }
                    PathSvg { path: Geo.circle(root.lt.mx, root.lt.my, root.lt.glow) }
                }
            }
        }
    }

    Fairy {
        anchors.fill: parent
        bulbs: root.d.jar.bulbs
        size: root.d.jar.size
        lights: root.lights
        clock: root.clock
    }

    // ---- the radio's light, pulsing to an 80 bpm beat (1600 beats per 20 min) ----
    Item {
        x: root.d.led.x
        y: root.d.led.y
        opacity: 0.55 + 0.45 * Math.pow(0.5 + 0.5 * Math.cos(2 * Math.PI * root.clock * 1600), 4)

        Rectangle {
            readonly property real r: root.d.led.r * 3.5
            x: -r
            y: -r
            width: 2 * r
            height: width
            radius: r
            color: Qt.alpha("#ff8a5a", 0.12 + 0.18 * root.lights)
        }
        Rectangle {
            readonly property real r: root.d.led.r
            x: -r
            y: -r
            width: 2 * r
            height: width
            radius: r
            color: "#ff8a5a"
            antialiasing: true
        }
    }

    // ---- steam from the mug: seven puffs, a new one every 0.4 s, 2.8 s life each ----
    Repeater {
        model: 7
        Shape {
            id: puff
            required property int index
            readonly property real t: (root.clock * 429 + index / 7) % 1
            readonly property real r: root.u * 1.8
            width: 2 * r
            height: width
            x: root.d.steam.x - r + Math.sin(2 * Math.PI * (t * 0.9 + index * 0.37)) * root.u * 0.9 * t
            y: root.d.steam.y - r - root.u * 0.3 - t * root.u * 6.2
            scale: 0.4 + 0.6 * t
            opacity: Math.sin(Math.PI * t)
            ShapePath {
                strokeColor: "transparent"
                fillGradient: RadialGradient {
                    centerX: puff.r
                    centerY: puff.r
                    centerRadius: puff.r
                    focalX: puff.r
                    focalY: puff.r
                    GradientStop { position: 0; color: Qt.alpha(root.c.steam, 0.32) }
                    GradientStop { position: 0.5; color: Qt.alpha(root.c.steam, 0.12) }
                    GradientStop { position: 1; color: Qt.alpha(root.c.steam, 0) }
                }
                PathSvg { path: Geo.circle(puff.r, puff.r, puff.r) }
            }
        }
    }

    // ---- notes from the radio: two, each drifting up for 6 s of a 9 s cycle ----
    Repeater {
        model: 2
        Text {
            id: note
            required property int index
            readonly property real t: (root.clock * 133 + index / 2) % 1
            readonly property real life: t / 0.665
            visible: life < 1
            text: index ? "♫" : "♪"
            color: root.c.note
            font.pixelSize: root.u * 2.6
            x: root.d.notes.x - width / 2 + life * root.u * 3.4 + Math.sin(2 * Math.PI * (life * 1.3 + index * 0.5)) * root.u * 0.8
            y: root.d.notes.y - height / 2 - life * root.u * 12.5
            rotation: -8 + Math.sin(2 * Math.PI * (life + index * 0.3)) * 12
            opacity: 0.8 * Math.sin(Math.PI * Math.min(1, life))
        }
    }
}
