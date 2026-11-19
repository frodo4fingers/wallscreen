pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes

// Ambient life, woodblock style: seasonal drifting petals/leaves, night fireflies (summer),
// and an occasional flock of ink birds by day. Flat fills, ink outlines, relative sizes.
// Everything moves as a pure function of the scene's 25 Hz clock: a running Animation or
// ParticleSystem would make Qt Quick render every vsync. Only the short fades are animated.
Item {
    id: root

    property int month: 0        // 0-11, hemisphere-adjusted by the caller
    property real light: 1       // 0-1 daylight
    property real windX: 0       // -1..1
    property real precip: 0      // 0-1, max(rain, snow)
    property bool running: true
    // 0..1 over 20 min, and the integer tick behind it (see Scene.qml)
    property real clock: 0
    property int ticks: 0

    readonly property string ink: "#1d1a2e"
    readonly property string inkSoft: "#661d1a2e" // ink at ~0.4 alpha
    readonly property real m: Math.min(width, height)
    readonly property real px: Math.max(0.4, m / 1080)
    readonly property real stroke: Math.max(1.5, m * 0.0018)

    readonly property bool spring: month >= 2 && month <= 4
    readonly property bool autumn: month >= 8 && month <= 10
    readonly property bool calm: precip <= 0.3

    readonly property real tau: 2 * Math.PI
    // Stable pseudo-random 0..1 from two numbers, so every pick is the same on each evaluation.
    function rnd(a, b) {
        var v = Math.sin(a * 12.9898 + b * 78.233 + 1.7) * 43758.5453;
        return v - Math.floor(v);
    }
    // Whole cycles per 20 min clock cycle for a period in seconds, so the wrap never jumps.
    function cycles(seconds) { return Math.max(1, Math.round(1200 / seconds)); }

    // ---- Petals / leaves ----
    // Fall 0.06 h/s (+-0.02), crossing ~1.4 h => ~23 s per fall, 25 in the pool.
    readonly property real petalVy: Math.max(1, height * 0.06)
    readonly property real petalLife: 1.4 * height / petalVy // seconds
    readonly property real driftDir: windX < 0 ? -1 : 1
    // Always a gentle sideways drift (0.025 h/s), more with wind.
    readonly property real petalVx: driftDir * Math.max(0.025, Math.abs(windX) * 0.1) * height
    // Upwind margin so petals starting off-side still cross the screen; capped at one width.
    readonly property real petalMargin: Math.min(width, Math.abs(petalVx) * petalLife * 0.6)

    property real petalRate: (spring || autumn) && calm ? 1.1 : 0
    Behavior on petalRate { NumberAnimation { duration: 8000 } }

    readonly property bool flyOn: month >= 5 && month <= 7 && light < 0.35 && calm
    property real flyRate: flyOn ? 1.0 : 0
    Behavior on flyRate { NumberAnimation { duration: 6000 } }

    // Momiji (maple) outline in a unit box, clockwise from the base. Uneven lobes: long top,
    // medium side lobes angled up ~30 deg, small bottom lobes angled down; serrated, pointed.
    readonly property var leafPts: [
        0.50, 0.72,
        0.58, 0.69, 0.66, 0.74, 0.74, 0.84, 0.73, 0.72, 0.66, 0.62,   // bottom-right lobe
        0.80, 0.62, 0.76, 0.55, 0.93, 0.40, 0.82, 0.38, 0.80, 0.31,   // right lobe
        0.64, 0.34, 0.66, 0.24, 0.60, 0.20, 0.60, 0.10, 0.50, 0.00,   // top lobe, right side
        0.42, 0.11, 0.41, 0.21, 0.35, 0.23, 0.37, 0.34,               // top lobe, left side
        0.20, 0.31, 0.22, 0.38, 0.07, 0.43, 0.20, 0.47, 0.19, 0.54,   // left lobe
        0.33, 0.58, 0.22, 0.66, 0.29, 0.68, 0.26, 0.80, 0.36, 0.74,   // bottom-left lobe
        0.34, 0.69, 0.43, 0.70
    ]
    // Built once per leaf.
    function leafSvg(s) {
        var p = leafPts, d = "M " + p[0] * s + " " + p[1] * s;
        for (var i = 2; i < p.length; i += 2)
            d += " L " + p[i] * s + " " + p[i + 1] * s;
        return d + " Z";
    }
    function stemSvg(s) { return "M " + 0.5 * s + " " + 0.70 * s + " Q " + 0.55 * s + " " + 0.88 * s + " " + 0.46 * s + " " + s; }
    function veinSvg(s) { return "M " + 0.5 * s + " " + 0.72 * s + " L " + 0.5 * s + " " + 0.06 * s; }
    // Notched teardrop petal: wide notched end on top, pointed tip at the bottom.
    function petalSvg(s) {
        return "M " + 0.5 * s + " " + s
            + " Q " + (-0.05 * s) + " " + 0.55 * s + " " + 0.38 * s + " " + 0.02 * s
            + " L " + 0.5 * s + " " + 0.14 * s + " L " + 0.62 * s + " " + 0.02 * s
            + " Q " + 1.05 * s + " " + 0.55 * s + " " + 0.5 * s + " " + s + " Z";
    }

    // The pool fades with petalRate; while it is hidden the clock is gated to 0, so none of the
    // per-item bindings re-evaluate out of season or in bad weather.
    Item {
        id: petals
        opacity: root.petalRate / 1.1
        visible: opacity > 0.02
        readonly property real c: visible ? root.clock : 0

        Repeater {
            model: 25
            delegate: Item {
                id: fl
                required property int index
                // Fall: m whole falls per clock cycle; n picks where this fall starts.
                readonly property real fallS: root.petalLife / (0.67 + 0.66 * root.rnd(index, 1))
                readonly property int falls: root.cycles(fallS)
                readonly property real u: petals.c * falls + root.rnd(index, 2)
                readonly property real t: u - Math.floor(u)
                readonly property int n: Math.floor(u) % falls
                readonly property real vx: root.petalVx * (1 + 0.4 * (2 * root.rnd(index, 3) - 1))
                readonly property real emitLeft: root.petalVx > 0 ? -root.petalMargin : 0
                readonly property real start: emitLeft + root.rnd(index, 1000 + n) * (root.width + root.petalMargin)
                // slow sideways and vertical wobble, the old Wander
                readonly property real wx: 45 * root.px * Math.sin(root.tau * (petals.c * root.cycles(6 + 6 * root.rnd(index, 14)) + root.rnd(index, 15)))
                readonly property real wy: 20 * root.px * Math.sin(root.tau * (petals.c * root.cycles(6 + 6 * root.rnd(index, 16)) + root.rnd(index, 17)))
                readonly property real cx: start + vx * t * (1200 / falls) + wx
                readonly property real cy: -0.04 * root.height + t * 1.4 * root.height + wy

                readonly property real s: root.spring
                    ? root.m * (0.018 + 0.010 * root.rnd(index, 6))
                    : root.m * (0.031 + 0.017 * root.rnd(index, 6))
                readonly property bool sway: !root.spring && root.rnd(index, 7) < 0.5 // half the leaves sway, half spin
                readonly property real turns: (root.rnd(index, 9) < 0.5 ? -1 : 1) * 360
                    * root.cycles(root.spring ? 4 + 6 * root.rnd(index, 8) : 8 + 8 * root.rnd(index, 8))
                readonly property real r0: root.rnd(index, 10) * 360

                width: s; height: s
                x: cx - s / 2
                y: cy - s / 2
                visible: cy < root.height + s
                rotation: sway
                    ? 25 * Math.sin(root.tau * (petals.c * root.cycles(2.4 + 2.4 * root.rnd(index, 11)) + root.rnd(index, 18)))
                    : r0 + turns * petals.c
                // flip: the edge-on moment sells the shape, 1.5-3 s per cycle
                transform: Scale {
                    origin.x: fl.s / 2; origin.y: fl.s / 2
                    xScale: Math.cos(root.tau * (petals.c * root.cycles(1.5 + 1.5 * root.rnd(fl.index, 12)) + root.rnd(fl.index, 13)))
                }

                Loader {
                    sourceComponent: root.spring ? petalShape : leafShape
                }

                Component {
                    id: petalShape
                    Shape {
                        width: fl.s; height: fl.s
                        preferredRendererType: Shape.CurveRenderer
                        ShapePath {
                            fillColor: root.rnd(fl.index, 4) < 0.55 ? "#f6a5b5" : "#fcd3dc"
                            strokeColor: root.inkSoft
                            strokeWidth: Math.max(1, root.stroke * 0.7)
                            joinStyle: ShapePath.RoundJoin
                            PathSvg { path: root.petalSvg(fl.s) }
                        }
                    }
                }

                Component {
                    id: leafShape
                    Shape {
                        id: leaf
                        readonly property real pick: root.rnd(fl.index, 5)
                        readonly property color fill: pick < 0.35 ? "#e2462f" : pick < 0.6 ? "#c8432b" : pick < 0.88 ? "#d9a23b" : "#e8743a"
                        width: fl.s; height: fl.s
                        preferredRendererType: Shape.CurveRenderer
                        ShapePath { // blade
                            fillColor: leaf.fill
                            strokeColor: "#801d1a2e" // ink at ~0.5 alpha
                            strokeWidth: Math.max(1, root.stroke * 0.8)
                            joinStyle: ShapePath.RoundJoin
                            PathSvg { path: root.leafSvg(fl.s) }
                        }
                        ShapePath { // midrib
                            fillColor: "transparent"
                            strokeColor: Qt.darker(leaf.fill, 1.6)
                            strokeWidth: Math.max(1, root.stroke * 0.7)
                            capStyle: ShapePath.RoundCap
                            PathSvg { path: root.veinSvg(fl.s) }
                        }
                        ShapePath { // stem
                            fillColor: "transparent"
                            strokeColor: root.ink
                            strokeWidth: Math.max(1.2, root.stroke * 1.1)
                            capStyle: ShapePath.RoundCap
                            PathSvg { path: root.stemSvg(fl.s) }
                        }
                    }
                }
            }
        }
    }

    // ---- Fireflies (summer nights), the only glow: tiny warm dots with a faint flat halo ----
    Item {
        id: flies
        opacity: root.flyRate
        visible: opacity > 0.02
        readonly property real c: visible ? root.clock : 0

        Repeater {
            model: 24
            delegate: Item {
                id: fly
                required property int index
                readonly property real d: Math.max(2, root.m * (0.004 + 0.003 * root.rnd(index, 20)))
                readonly property real amp: 0.04 * root.height
                // a slow Lissajous around a seeded home point
                x: root.rnd(index, 21) * root.width
                    + amp * Math.sin(root.tau * (flies.c * root.cycles(10 + 20 * root.rnd(index, 23)) + root.rnd(index, 25)))
                y: (0.45 + 0.45 * root.rnd(index, 22)) * root.height
                    + amp * Math.sin(root.tau * (flies.c * root.cycles(10 + 20 * root.rnd(index, 24)) + root.rnd(index, 26)))
                width: 1; height: 1
                // pulse between 0.12 and 1, half-beat 1.2-3 s
                opacity: 0.56 + 0.44 * Math.sin(root.tau * (flies.c * root.cycles(2 * (1.2 + 1.8 * root.rnd(index, 27))) + root.rnd(index, 28)))
                Rectangle { // halo
                    width: fly.d * 2.8; height: width; radius: width / 2
                    x: -width / 2; y: -width / 2
                    color: "#2effe27a"
                }
                Rectangle {
                    width: fly.d; height: width; radius: width / 2
                    x: -width / 2; y: -width / 2
                    color: "#ffe27a"
                }
            }
        }
    }

    // ---- Birds: one flock Item, bird count/position/direction re-rolled per crossing ----
    Item {
        id: flock
        property bool flying: false
        property int count: 5
        property int dir: 1
        property bool vee: true
        property real size: 10
        property real x0: 0
        property real x1: 0
        property int launches: 0
        property int startTick: 0
        property int durTicks: 1
        // ticks since launch; the flight is far shorter than the 30000-tick wrap
        readonly property int elapsed: flying ? (root.ticks - startTick + 30000) % 30000 : 0
        readonly property real progress: elapsed / durTicks
        x: flying ? x0 + (x1 - x0) * Math.min(1, progress) : -100000
        visible: flying
        // Fade out if the weather turns or night falls mid-crossing.
        opacity: root.light > 0.3 && root.precip < 0.5 ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 3000 } }

        // Ticks only change while the scene runs, so a paused flock stays where it is.
        Connections {
            target: root
            enabled: flock.flying
            function onTicksChanged() {
                if (flock.progress >= 1) {
                    flock.flying = false;
                    flock.schedule();
                }
            }
        }

        function schedule() {
            gapTimer.interval = launches === 0 ? 8000 + Math.random() * 20000 : 40000 + Math.random() * 80000;
            gapTimer.restart();
        }

        function launch() {
            launches++;
            var ok = root.running && root.light > 0.4 && root.precip < 0.3 && root.width > 0;
            dir = root.windX > 0.05 ? 1 : root.windX < -0.05 ? -1 : (Math.random() < 0.5 ? 1 : -1);
            count = 3 + Math.floor(Math.random() * 5);
            vee = Math.random() < 0.7;
            size = root.m * (0.012 + 0.006 * Math.random());
            y = root.height * (0.12 + 0.23 * Math.random());
            var margin = 0.2 * root.m;
            x0 = dir > 0 ? -margin : root.width + margin;
            x1 = dir > 0 ? root.width + margin : -margin;
            durTicks = Math.round((25000 + Math.random() * 15000) / 40);
            startTick = root.ticks;
            flying = ok;
        }

        Repeater {
            model: flock.count
            delegate: Item {
                id: bird
                required property int index
                readonly property real s: flock.size
                readonly property int rank: Math.ceil(index / 2)
                // seeded per launch: the values re-roll each crossing and never in a frame
                readonly property real jx: (root.rnd(index, flock.launches * 7 + 1) - 0.5) * s
                readonly property real jy: (root.rnd(index, flock.launches * 7 + 2) - 0.5) * s
                readonly property real beat: 350 + root.rnd(index, flock.launches * 7 + 3) * 250
                readonly property real phase: root.rnd(index, flock.launches * 7 + 4) * 400
                readonly property int glideEvery: 8 + Math.floor(root.rnd(index, flock.launches * 7 + 5) * 10)
                readonly property real glideMs: 1000 + root.rnd(index, flock.launches * 7 + 6) * 1000
                // wing tip y offset, up is negative: glideEvery flaps, then a level-wing glide
                readonly property real tip: flock.flying ? flap(flock.elapsed * 40 - phase) : 0
                x: -flock.dir * (flock.vee ? rank * s * 3.2 : index * s * 2.8) + jx
                y: (flock.vee ? (index % 2 ? 1 : -1) * rank * s * 1.6 : 0) + jy

                function ease(f) { return 0.5 - 0.5 * Math.cos(Math.PI * f); }
                function flap(ms) {
                    if (ms < 0) return 0; // the opening pause that offsets the birds
                    var pos = ms % (glideEvery * beat + glideMs);
                    if (pos >= glideEvery * beat) return 0;
                    var f = (pos % beat) / beat;
                    if (f < 0.3) return -0.45 * s * ease(f / 0.3);
                    if (f < 0.7) return s * (-0.45 + 0.8 * ease((f - 0.3) / 0.4));
                    return 0.35 * s * (1 - ease((f - 0.7) / 0.3));
                }

                Shape {
                    x: -bird.s; y: -bird.s
                    width: 2 * bird.s; height: 2 * bird.s
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        fillColor: "transparent"
                        strokeColor: root.ink
                        strokeWidth: Math.max(1.2, root.m * 0.0025)
                        capStyle: ShapePath.RoundCap
                        joinStyle: ShapePath.RoundJoin
                        startX: 0
                        startY: bird.s + bird.tip
                        PathQuad {
                            x: bird.s; y: bird.s
                            controlX: 0.5 * bird.s; controlY: 0.7 * bird.s + 0.5 * bird.tip
                        }
                        PathQuad {
                            x: 2 * bird.s; y: bird.s + bird.tip
                            controlX: 1.5 * bird.s; controlY: 0.7 * bird.s + 0.5 * bird.tip
                        }
                    }
                }
            }
        }
    }

    // First flock after 8-28 s (so it feels alive), then every 40-120 s. A plain Timer does
    // not force frames; the crossing itself runs off the clock.
    Timer {
        id: gapTimer
        repeat: false
        onTriggered: {
            flock.launch();
            if (!flock.flying) flock.schedule();
        }
    }
    Component.onCompleted: flock.schedule()
}
