import QtQuick
import QtQuick.Shapes
import QtQuick.Particles
import "geometry.js" as Geo
import "palette.js" as Pal

// The desk and what stands on it. The lamp throws a cone and a warm pool onto the notebook,
// steam rises from the mug, music notes drift up from the radio, whose light pulses to the
// beat, and a jar of fairy lights glows at the right end.
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
    Fairy {
        anchors.fill: parent
        bulbs: root.d.jar.bulbs
        size: root.d.jar.size
        lights: root.lights
        clock: root.clock
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

    // ---- steam from the mug, notes from the radio ----
    ParticleSystem {
        id: sys
        paused: !root.running
    }

    ImageParticle {
        system: sys
        groups: ["steam"]
        source: "glow.png"
        color: root.c.steam
        alpha: 0.16
        entryEffect: ImageParticle.Fade
    }
    Emitter {
        system: sys
        group: "steam"
        x: root.d.steam.x - root.u
        y: root.d.steam.y - root.u * 0.3
        width: root.u * 2
        height: root.u * 0.4
        emitRate: 5
        lifeSpan: 2800
        lifeSpanVariation: 600
        size: root.u * 1.4
        sizeVariation: root.u * 0.4
        endSize: root.u * 3.6
        velocity: AngleDirection {
            angle: 270
            angleVariation: 10
            magnitude: root.u * 2.2
            magnitudeVariation: root.u * 0.8
        }
    }
    Wander {
        system: sys
        groups: ["steam"]
        xVariance: root.u * 1.2
        pace: root.u * 2
    }

    ImageParticle {
        system: sys
        groups: ["note"]
        source: "note.png"
        color: root.c.note
        alpha: 0.8
        rotation: -8
        rotationVariation: 15
        entryEffect: ImageParticle.Fade
    }
    Emitter {   // one note every three seconds or so, drifting up and to the right
        system: sys
        group: "note"
        x: root.d.notes.x - root.u
        y: root.d.notes.y - root.u
        width: root.u * 2
        height: root.u
        emitRate: 0.35
        lifeSpan: 6000
        lifeSpanVariation: 1000
        size: root.u * 2.4
        sizeVariation: root.u * 0.6
        velocity: AngleDirection {
            angle: 285
            angleVariation: 20
            magnitude: root.u * 2.2
            magnitudeVariation: root.u * 0.6
        }
    }
    Wander {
        system: sys
        groups: ["note"]
        xVariance: root.u * 2
        pace: root.u * 1.5
    }
}
