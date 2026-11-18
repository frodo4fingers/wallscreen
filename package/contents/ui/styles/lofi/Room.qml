pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import "geometry.js" as Geo
import "palette.js" as Pal

// The room side: the wall with shelves, a clock showing the real time, polaroids on a string
// of lights and a radiator under the window; the window casing, frame and sill, and on the
// sill a pothos, a stack of books with a cactus and a jar candle.
Item {
    id: root

    property var lay: Geo.layout(1920, 1080)
    property var c: Pal.room(0.3, 0)
    property real lights: 0          // fairy lights, 0 day .. 1 night
    property real lamp: 0            // candle glow
    property real clock: 0
    property date now: new Date()

    readonly property real sh: lay.H
    readonly property var r: Geo.room(lay)
    readonly property var candleGeo: Geo.candle(lay)
    readonly property var photos: Geo.photos(lay)
    readonly property var ck: Geo.clock(lay)

    // static, so drawn once and cached; re-rendered on palette steps and when the minute hand moves
    Item {
        anchors.fill: parent
        layer.enabled: true

        // ---- wall and what hangs on it ----
        Shape {
            anchors.fill: parent
            ShapePath {   // wall with the window hole, darker towards the ceiling
                strokeColor: "transparent"
                fillRule: ShapePath.OddEvenFill
                fillGradient: LinearGradient {
                    x1: 0
                    y1: 0
                    x2: 0
                    y2: root.sh
                    GradientStop { position: 0; color: root.c.wallTop }
                    GradientStop { position: 0.7; color: root.c.wall }
                }
                PathSvg { path: root.r.wall }
            }
        }

        Paint {
            anchors.fill: parent
            c: root.c
            ops: Geo.radiator(root.lay)
        }
        Paint {
            anchors.fill: parent
            c: root.c
            ops: Geo.shelves(root.lay)
        }
        Paint {
            anchors.fill: parent
            c: root.c
            ops: root.photos.ops
        }

        Item {   // wall clock; world.now moves the hands once a minute
            id: wallClock
            anchors.fill: parent
            visible: root.ck.show

            readonly property real hours: root.now.getHours() % 12 + root.now.getMinutes() / 60

            Paint {
                anchors.fill: parent
                c: root.c
                ops: root.ck.ops
            }
            Repeater {   // hour hand, minute hand: [length, width, angle]
                model: [[0.48, 0.08, wallClock.hours * 30], [0.7, 0.055, root.now.getMinutes() * 6]]
                Rectangle {
                    id: hand
                    required property var modelData
                    readonly property real len: root.ck.r * modelData[0]
                    x: root.ck.cx - width / 2
                    y: root.ck.cy - len
                    width: root.ck.r * modelData[1]
                    height: len + width / 2
                    radius: width / 2
                    color: root.c.clockHand
                    antialiasing: true
                    transform: Rotation {
                        origin.x: hand.width / 2
                        origin.y: hand.len
                        angle: hand.modelData[2]
                    }
                }
            }
            Rectangle {
                readonly property real k: root.ck.r * 0.07
                x: root.ck.cx - k
                y: root.ck.cy - k
                width: 2 * k
                height: width
                radius: k
                color: root.c.clockHand
            }
        }

        Rectangle {   // shadow the sill casts on the wall
            x: root.lay.sill.x
            y: root.lay.frontY + root.lay.sill.front
            width: root.lay.sill.w
            height: root.lay.D * 0.035
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.alpha(root.c.shadow, 0.45) }
                GradientStop { position: 1; color: Qt.alpha(root.c.shadow, 0) }
            }
        }

        Shape {   // casing, frame, sill: straight edges, default renderer
            anchors.fill: parent
            ShapePath {
                strokeColor: "transparent"
                fillColor: root.c.casing
                fillRule: ShapePath.OddEvenFill
                PathSvg { path: root.r.casing }
            }
            ShapePath {
                strokeColor: "transparent"
                fillColor: root.c.frame
                fillRule: ShapePath.WindingFill
                PathSvg { path: root.r.frame }
            }
            ShapePath {   // glazing line around each pane
                strokeColor: root.c.edge
                strokeWidth: Math.max(1, root.lay.f * 0.09)
                fillColor: "transparent"
                PathSvg { path: root.r.edges }
            }
            ShapePath {
                strokeColor: "transparent"
                fillColor: Qt.alpha(root.c.sillLip, 0.6)
                fillRule: ShapePath.WindingFill
                PathSvg { path: root.r.sheen }
            }
            ShapePath { strokeColor: "transparent"; fillColor: root.c.sillTop; PathSvg { path: root.r.sillTop } }
            ShapePath { strokeColor: "transparent"; fillColor: root.c.sillFront; PathSvg { path: root.r.sillFront } }
            ShapePath { strokeColor: "transparent"; fillColor: root.c.sillLip; PathSvg { path: root.r.sillLip } }
        }

        // ---- on the sill ----
        Paint {
            anchors.fill: parent
            c: root.c
            ops: Geo.plant(root.lay).ops
        }
        Paint {
            anchors.fill: parent
            c: root.c
            ops: Geo.stack(root.lay)
        }
    }

    Fairy {
        anchors.fill: parent
        bulbs: root.photos.bulbs
        size: root.photos.size
        lights: root.lights
        clock: root.clock
    }

    // ---- jar candle; the flame flickers on the shared clock ----
    Item {
        id: candle
        anchors.fill: parent

        readonly property var k: root.candleGeo
        readonly property real cy: k.flameY - root.lay.u
        // 1500, 2470, 4130 cycles per 20 min: an uneven 1-3 Hz flutter
        readonly property real f: {
            const t = 2 * Math.PI * root.clock;
            return 0.9 + 0.06 * Math.sin(t * 1500) + 0.04 * Math.sin(t * 2470 + 1.3) + 0.03 * Math.sin(t * 4130 + 0.4);
        }

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath { strokeColor: "transparent"; fillColor: Qt.alpha(root.c.shadow, 0.3); PathSvg { path: candle.k.shadow } }
        }
        Shape {
            anchors.fill: parent
            opacity: (0.35 + 0.65 * root.lamp) * candle.f
            ShapePath {
                strokeColor: "transparent"
                fillGradient: RadialGradient {
                    centerX: candle.k.cx
                    centerY: candle.cy
                    centerRadius: candle.k.glowR
                    focalX: candle.k.cx
                    focalY: candle.cy
                    GradientStop { position: 0; color: "#73ffb066" }
                    GradientStop { position: 0.35; color: "#26ff9a55" }
                    GradientStop { position: 1; color: "#00ff9a55" }
                }
                PathSvg { path: Geo.circle(candle.k.cx, candle.cy, candle.k.glowR) }
            }
        }
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath { strokeColor: "transparent"; fillColor: "#f3e3cc"; PathSvg { path: candle.k.wax } }
            ShapePath { strokeColor: "transparent"; fillColor: "#fff3df"; PathSvg { path: candle.k.waxTop } }
            ShapePath { strokeColor: "transparent"; fillColor: "#3a2a20"; PathSvg { path: candle.k.wick } }
        }
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            transform: Scale {
                origin.x: candle.k.cx
                origin.y: candle.k.flameY
                xScale: 1 / Math.sqrt(candle.f)
                yScale: candle.f
            }
            ShapePath { strokeColor: "transparent"; fillColor: "#ffb347"; PathSvg { path: candle.k.flame } }
            ShapePath { strokeColor: "transparent"; fillColor: "#fff4c8"; PathSvg { path: candle.k.core } }
        }
        Shape {   // the glass jar in front of the candle
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath { strokeColor: "transparent"; fillColor: Qt.alpha(root.c.glint, 0.22); PathSvg { path: candle.k.jar } }
            ShapePath { strokeColor: "transparent"; fillColor: Qt.alpha(root.c.glint, 0.35); PathSvg { path: candle.k.lip } }
        }
    }
}
