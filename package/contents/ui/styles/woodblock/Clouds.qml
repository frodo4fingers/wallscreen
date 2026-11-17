import QtQuick
import QtQuick.Shapes

// Clouds (ukiyo-e kasumi): flat mist bands, ink outline, two depth layers.
// Drift via NumberAnimation only. Drift is always toward +x; |windX| only sets speed.
Item {
    id: root

    property real cover: 0          // 0..1
    property real darkness: 0       // 0..1
    property real windX: 0.1        // -1..1 (magnitude = speed only)
    property color tint: "#ffffff"
    property bool running: true

    readonly property real u: Math.min(width, height)
    readonly property real lineW: Math.max(1.5, u * 0.0018)
    readonly property color ink: "#1d1a2e"
    readonly property real windAbs: Math.abs(windX)
    // near layer, fraction of screen width per second: ~68 s crossing at low wind, ~33 s at full wind
    readonly property real speed: 0.013 + 0.017 * Math.min(1, windAbs)

    // mixed toward dark grey by darkness
    property color baseColor: Qt.rgba(
        tint.r * (1 - darkness) + 0.27 * darkness,
        tint.g * (1 - darkness) + 0.29 * darkness,
        tint.b * (1 - darkness) + 0.33 * darkness, 1)
    Behavior on baseColor { ColorAnimation { duration: 10000 } }

    // deterministic pseudo-random in [0,1)
    function rnd(seed, k) {
        var s = Math.sin(seed * 127.1 + k * 311.7) * 43758.5453
        return s - Math.floor(s)
    }

    // SVG path of one band (w x h box): flat bottom, rounded ends, n scallops on top.
    // Traversed counter-clockwise on screen (sweep 0). Scallop tops reach y = 0.
    function bandPath(w, h, n, seed) {
        var yT = 0.4 * h, r = 0.3 * h, x0 = r, x1 = w - r, span = x1 - x0
        var ws = [], tot = 0, i
        for (i = 0; i < n; i++) { ws.push(0.6 + rnd(seed, 50 + i)); tot += ws[i] }
        var p = "M " + x0 + " " + h + " L " + x1 + " " + h
              + " A " + r + " " + r + " 0 0 0 " + x1 + " " + yT
        var x = x1
        for (i = 0; i < n; i++) {
            var seg = span * ws[i] / tot
            x = (i === n - 1) ? x0 : x - seg
            p += " A " + (seg / 2) + " " + (h * (0.25 + 0.15 * rnd(seed, 70 + i))) + " 0 0 0 " + x + " " + yT
        }
        return p + " A " + r + " " + r + " 0 0 0 " + x0 + " " + h
    }

    // overcast sheet, opacity = cover^2: flat bokashi, solid at top, fading down
    Rectangle {
        width: root.width
        height: root.height * 0.66
        opacity: root.cover * root.cover * 0.85
        Behavior on opacity { NumberAnimation { duration: 10000 } }
        gradient: Gradient {
            GradientStop { position: 0.0; color: root.baseColor }
            GradientStop { position: 0.3; color: root.baseColor }
            GradientStop { position: 1.0; color: Qt.rgba(root.baseColor.r, root.baseColor.g, root.baseColor.b, 0) }
        }
    }

    // layer 0 = far (lighter, low near the horizon, smaller), layer 1 = near (higher, bigger)
    Repeater {
        model: 2
        delegate: Item {
            id: lyr
            required property int index
            readonly property bool near: index === 1
            readonly property int count: near ? 6 : 5          // pool of 11
            readonly property real speedScale: near ? 1.0 : 0.45
            readonly property real yTop: near ? 0.05 : 0.36     // fractions of root.height
            readonly property real yRange: near ? 0.30 : 0.18
            readonly property color fill: near ? root.baseColor : Qt.lighter(root.baseColor, 1.12)

            width: root.width
            height: root.height

            Repeater {
                model: lyr.count
                delegate: Shape {
                    id: band
                    required property int index
                    readonly property int seed: index + (lyr.near ? 100 : 0) + 1
                    readonly property int n: 2 + Math.floor(root.rnd(seed, 1) * 3)     // 2..4 scallops
                    readonly property real cw: root.width * (lyr.near ? 0.40 + 0.20 * root.rnd(seed, 2)
                                                                      : 0.25 + 0.20 * root.rnd(seed, 2))
                    readonly property real ch: root.height * (lyr.near ? 0.035 + 0.015 * root.rnd(seed, 6)
                                                                       : 0.025 + 0.010 * root.rnd(seed, 6))
                    readonly property real x0: root.rnd(seed, 3) * (lyr.width + cw) - cw
                    // low-discrepancy threshold: cover decides how many bands exist
                    readonly property real th: (index * 0.618034 + (lyr.near ? 0.3 : 0.0)) % 1.0
                    readonly property real vis: Math.max(0, Math.min(1, (root.cover * 1.15 - th) / 0.15))
                    readonly property real v: root.speed * lyr.width * lyr.speedScale
                                              * (0.8 + 0.4 * root.rnd(seed, 4))     // px/s
                    readonly property int dur: Math.round((lyr.width + cw) / v * 1000)
                    property int curDur: 1          // dur latched at each loop start: new speed, no jump
                    property real bob: -1           // -1..1 (starts at the animation start value), vertical breathing
                    readonly property int bobPeriod: 8000 + Math.round(6000 * root.rnd(seed, 8))

                    width: cw
                    height: ch
                    x: x0
                    // stratified vertical slot per band, so bands do not pile up
                    y: root.height * (lyr.yTop + lyr.yRange * (index + 0.15 + 0.7 * root.rnd(seed, 5)) / lyr.count
                                      + 0.004 * bob)
                    opacity: vis
                    visible: opacity > 0.005
                    Behavior on opacity { NumberAnimation { duration: 8000 } }
                    preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        strokeColor: root.ink
                        strokeWidth: root.lineW
                        joinStyle: ShapePath.RoundJoin
                        fillColor: lyr.fill
                        PathSvg { path: root.bandPath(band.cw, band.ch, band.n, band.seed) }
                    }

                    // paused only while running, so setPaused() never hits a stopped animation
                    SequentialAnimation {
                        running: true
                        paused: running && !root.running
                        ScriptAction { script: band.curDur = band.dur }
                        NumberAnimation {   // first pass from the spread-out start position
                            target: band; property: "x"
                            from: band.x0; to: lyr.width
                            duration: Math.max(1, Math.round(band.curDur * (lyr.width - band.x0) / (lyr.width + band.cw)))
                        }
                        SequentialAnimation {
                            loops: Animation.Infinite
                            ScriptAction { script: band.curDur = band.dur }
                            NumberAnimation {
                                target: band; property: "x"
                                from: -band.cw; to: lyr.width
                                duration: band.curDur
                            }
                        }
                    }

                    // vertical bob: random start delay = random phase, SineCurve is one full cycle
                    SequentialAnimation {
                        running: true
                        paused: running && !root.running
                        PauseAnimation { duration: Math.round(band.bobPeriod * root.rnd(band.seed, 9)) }
                        SequentialAnimation {
                            loops: Animation.Infinite
                            NumberAnimation {
                                target: band; property: "bob"
                                from: -1; to: 1
                                duration: band.bobPeriod
                                easing.type: Easing.SineCurve
                            }
                        }
                    }
                }
            }
        }
    }
}
