import QtQuick
import QtQuick.Particles
import QtQuick.Shapes

// Ambient life, woodblock style: seasonal drifting petals/leaves, night fireflies (summer),
// and an occasional flock of ink birds by day. Flat fills, ink outlines, relative sizes.
// No per-frame JS: rates/geometry are bindings, motion is Animation / ParticleSystem only.
Item {
    id: root

    property int month: 0        // 0-11, hemisphere-adjusted by the caller
    property real light: 1       // 0-1 daylight
    property real windX: 0       // -1..1
    property real precip: 0      // 0-1, max(rain, snow)
    property bool running: true

    readonly property string ink: "#1d1a2e"
    readonly property string inkSoft: "#661d1a2e" // ink at ~0.4 alpha
    readonly property real m: Math.min(width, height)
    readonly property real px: Math.max(0.4, m / 1080)
    readonly property real stroke: Math.max(1.5, m * 0.0018)

    readonly property bool spring: month >= 2 && month <= 4
    readonly property bool autumn: month >= 8 && month <= 10
    readonly property bool calm: precip <= 0.3

    // ---- Petals / leaves ----
    // Fall 0.06 h/s (+-0.02), crossing ~1.4 h => ~23 s life, ~25 alive at 1.1/s (cap 40).
    readonly property real petalVy: Math.max(1, height * 0.06)
    readonly property real petalLife: 1.4 * height / petalVy // seconds
    readonly property real driftDir: windX < 0 ? -1 : 1
    // Always a gentle sideways drift (0.025 h/s), more with wind.
    readonly property real petalVx: driftDir * Math.max(0.025, Math.abs(windX) * 0.1) * height
    // Upwind margin so particles starting off-side still cross the screen; capped at one width.
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

    ParticleSystem {
        id: sys
        paused: !root.running
    }

    ItemParticle {
        system: sys
        groups: ["sakura"]
        fade: false
        delegate: Item {
            width: 1; height: 1
            Shape {
                id: petal
                readonly property real s: root.m * (0.018 + 0.010 * Math.random())
                readonly property real r0: Math.random() * 360
                readonly property real turn: Math.random() < 0.5 ? -360 : 360
                readonly property real flipMs: 750 + Math.random() * 750 // half cycle: 1.5-3 s per flip cycle
                width: s; height: s
                x: -s / 2; y: -s / 2
                preferredRendererType: Shape.CurveRenderer
                transform: Scale { id: petalFlip; origin.x: petal.s / 2; origin.y: petal.s / 2; xScale: 1 }
                ShapePath {
                    fillColor: Math.random() < 0.55 ? "#f6a5b5" : "#fcd3dc"
                    strokeColor: root.inkSoft
                    strokeWidth: Math.max(1, root.stroke * 0.7)
                    joinStyle: ShapePath.RoundJoin
                    PathSvg { path: root.petalSvg(petal.s) }
                }
                NumberAnimation on rotation {
                    from: petal.r0; to: petal.r0 + petal.turn
                    duration: 4000 + Math.random() * 6000
                    loops: Animation.Infinite
                    running: true
                    paused: running && !root.running
                }
                SequentialAnimation {
                    loops: Animation.Infinite
                    running: true
                    paused: running && !root.running
                    NumberAnimation { target: petalFlip; property: "xScale"; to: -1; duration: petal.flipMs; easing.type: Easing.InOutSine }
                    NumberAnimation { target: petalFlip; property: "xScale"; to: 1; duration: petal.flipMs; easing.type: Easing.InOutSine }
                }
            }
        }
    }

    ItemParticle {
        system: sys
        groups: ["maple"]
        fade: false
        delegate: Item {
            width: 1; height: 1
            Shape {
                id: leaf
                readonly property real s: root.m * (0.031 + 0.017 * Math.random())
                readonly property real pick: Math.random()
                readonly property color fill: pick < 0.35 ? "#e2462f" : pick < 0.6 ? "#c8432b" : pick < 0.88 ? "#d9a23b" : "#e8743a"
                readonly property bool sway: Math.random() < 0.5 // half sway like a pendulum, half spin slowly
                readonly property real r0: Math.random() * 360
                readonly property real turn: Math.random() < 0.5 ? -360 : 360
                readonly property real flipMs: 750 + Math.random() * 750
                width: s; height: s
                x: -s / 2; y: -s / 2
                preferredRendererType: Shape.CurveRenderer
                transform: Scale { id: leafFlip; origin.x: leaf.s / 2; origin.y: leaf.s / 2; xScale: 1 }
                ShapePath { // blade
                    fillColor: leaf.fill
                    strokeColor: "#801d1a2e" // ink at ~0.5 alpha
                    strokeWidth: Math.max(1, root.stroke * 0.8)
                    joinStyle: ShapePath.RoundJoin
                    PathSvg { path: root.leafSvg(leaf.s) }
                }
                ShapePath { // midrib
                    fillColor: "transparent"
                    strokeColor: Qt.darker(leaf.fill, 1.6)
                    strokeWidth: Math.max(1, root.stroke * 0.7)
                    capStyle: ShapePath.RoundCap
                    PathSvg { path: root.veinSvg(leaf.s) }
                }
                ShapePath { // stem
                    fillColor: "transparent"
                    strokeColor: root.ink
                    strokeWidth: Math.max(1.2, root.stroke * 1.1)
                    capStyle: ShapePath.RoundCap
                    PathSvg { path: root.stemSvg(leaf.s) }
                }
                NumberAnimation { // slow full turn, 8-16 s
                    target: leaf; property: "rotation"
                    from: leaf.r0; to: leaf.r0 + leaf.turn
                    duration: 8000 + Math.random() * 8000
                    loops: Animation.Infinite
                    running: !leaf.sway
                    paused: running && !root.running
                }
                SequentialAnimation { // pendulum sway +-25 deg
                    loops: Animation.Infinite
                    running: leaf.sway
                    paused: running && !root.running
                    NumberAnimation { target: leaf; property: "rotation"; from: -25; to: 25; duration: 1200 + Math.random() * 1200; easing.type: Easing.InOutSine }
                    NumberAnimation { target: leaf; property: "rotation"; to: -25; duration: 1200 + Math.random() * 1200; easing.type: Easing.InOutSine }
                }
                SequentialAnimation { // flip: edge-on moment sells the leaf
                    loops: Animation.Infinite
                    running: true
                    paused: running && !root.running
                    NumberAnimation { target: leafFlip; property: "xScale"; to: -1; duration: leaf.flipMs; easing.type: Easing.InOutSine }
                    NumberAnimation { target: leafFlip; property: "xScale"; to: 1; duration: leaf.flipMs; easing.type: Easing.InOutSine }
                }
            }
        }
    }

    // One emitter for both seasons; the group follows the season.
    Emitter {
        system: sys
        group: root.spring ? "sakura" : "maple"
        enabled: root.petalRate > 0.05
        emitRate: root.petalRate
        lifeSpan: 1000 * root.petalLife
        maximumEmitted: 40
        // Top edge plus an upwind margin.
        x: root.petalVx > 0 ? -root.petalMargin : 0
        y: -0.04 * root.height
        width: root.width + root.petalMargin
        height: 1
        velocity: PointDirection {
            x: root.petalVx
            xVariation: 0.4 * Math.abs(root.petalVx)
            y: root.petalVy
            yVariation: 0.33 * root.petalVy // 0.04-0.08 h/s
        }
    }
    Wander {
        system: sys
        groups: ["sakura", "maple"]
        xVariance: 45 * root.px
        yVariance: 20 * root.px
        pace: 100
    }

    // ---- Fireflies (summer nights), the only glow: tiny warm dots with a faint flat halo ----
    ItemParticle {
        system: sys
        groups: ["fly"]
        delegate: Item {
            id: fly
            width: 1; height: 1
            readonly property real d: Math.max(2, root.m * (0.004 + 0.003 * Math.random()))
            readonly property real beat: 1200 + Math.random() * 1800
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
            SequentialAnimation on opacity {
                loops: Animation.Infinite
                running: true
                paused: running && !root.running
                NumberAnimation { to: 1.0; duration: fly.beat; easing.type: Easing.InOutSine }
                NumberAnimation { to: 0.12; duration: fly.beat; easing.type: Easing.InOutSine }
            }
        }
    }
    Emitter {
        system: sys
        group: "fly"
        enabled: root.flyRate > 0.05
        emitRate: root.flyRate
        lifeSpan: 14000
        maximumEmitted: 24
        x: 0; y: 0.45 * root.height
        width: root.width; height: 0.45 * root.height
        velocity: AngleDirection {
            angleVariation: 360
            magnitude: 0.012 * root.height
            magnitudeVariation: 0.008 * root.height
        }
    }
    Wander {
        system: sys
        groups: ["fly"]
        xVariance: 20 * root.px
        yVariance: 20 * root.px
        pace: 50
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
        x: -100000
        visible: flying
        // Fade out if the weather turns or night falls mid-crossing.
        opacity: root.light > 0.3 && root.precip < 0.5 ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 3000 } }

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
            flyAnim.from = x0;
            flyAnim.to = x1;
            flyAnim.duration = 25000 + Math.random() * 15000;
            x = x0;
            flying = ok;
            if (ok) flyAnim.restart();
        }

        Repeater {
            model: flock.count
            delegate: Item {
                id: bird
                readonly property real s: flock.size
                readonly property int rank: Math.ceil(index / 2)
                readonly property real jx: (Math.random() - 0.5) * s
                readonly property real jy: (Math.random() - 0.5) * s
                readonly property real beat: 350 + Math.random() * 250
                readonly property real phase: Math.random() * 400
                readonly property int glideEvery: 8 + Math.floor(Math.random() * 10)
                readonly property real glideMs: 1000 + Math.random() * 1000
                property real tip: 0 // wing tip y offset, up is negative
                x: -flock.dir * (flock.vee ? rank * s * 3.2 : index * s * 2.8) + jx
                y: (flock.vee ? (index % 2 ? 1 : -1) * rank * s * 1.6 : 0) + jy

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

                SequentialAnimation {
                    running: flock.flying
                    paused: running && !root.running
                    PauseAnimation { duration: bird.phase }
                    SequentialAnimation {
                        loops: Animation.Infinite
                        // glideEvery flaps, then a level-wing glide.
                        SequentialAnimation {
                            loops: bird.glideEvery
                            NumberAnimation { target: bird; property: "tip"; to: -0.45 * bird.s; duration: bird.beat * 0.3; easing.type: Easing.InOutSine }
                            NumberAnimation { target: bird; property: "tip"; to: 0.35 * bird.s; duration: bird.beat * 0.4; easing.type: Easing.InOutSine }
                            NumberAnimation { target: bird; property: "tip"; to: 0; duration: bird.beat * 0.3; easing.type: Easing.InOutSine }
                        }
                        PauseAnimation { duration: bird.glideMs }
                    }
                }
            }
        }
    }

    // First flock after 8-28 s (so it feels alive), then every 40-120 s.
    // Plain Timer + standalone animation: nothing mutates an animation inside its own group.
    Timer {
        id: gapTimer
        repeat: false
        onTriggered: {
            flock.launch();
            if (!flock.flying) flock.schedule();
        }
    }
    NumberAnimation {
        id: flyAnim
        target: flock
        property: "x"
        paused: running && !root.running
        onFinished: {
            flock.flying = false;
            flock.schedule();
        }
    }
    Component.onCompleted: flock.schedule()
}
