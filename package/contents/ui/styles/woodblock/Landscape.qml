import QtQuick
import QtQuick.Shapes

// Ukiyo-e landscape: snow-capped volcano, four hill layers (far to near) with
// bokashi crests, umbrella pines on the two near layers, one small pagoda.
// All geometry is normalized; path strings are bindings that depend only on
// width/height/snowCap, so they are rebuilt on resize or snowCap change, never per frame.
Item {
    id: root

    property var colors: ["#6f86a8", "#4f6a86", "#34506a", "#1f3447"]
    property real light: 1.0
    property real snowCap: 0.3           // fraction of volcano height under snow
    property color ink: "#1d1a2e"
    property real windX: 0               // -1..1, leans pines and scales sway
    property bool running: true          // false pauses the sway

    // Contract HORIZON_Y: highest crest of the far layer.
    readonly property real horizonY: 0.62

    readonly property real ow: Math.max(1.5, Math.min(width, height) * 0.0018)      // outline width
    readonly property real trunkW: Math.max(2, Math.min(width, height) * 0.0026)

    readonly property color nightColor: "#0b1026"
    readonly property color hazeColor: Qt.rgba(0.66, 0.74, 0.86, 1)

    // Joints [x, y] per layer; segments are smoothstep S-curves (horizontal
    // tangents at each joint, control x at 1/3, so y(x) is analytic for trees/pagoda).
    // trees: [x, size (fraction of min(w,h)), lean, pad count 2-4]. pagoda: x or 0.
    readonly property var layers: [
        { haze: 0.40, trees: [], pagoda: 0.22,
          pts: [[0, 0.70], [0.18, 0.62], [0.40, 0.72], [0.62, 0.64], [0.82, 0.73], [1, 0.66]] },
        { haze: 0.22, trees: [], pagoda: 0,
          pts: [[0, 0.77], [0.12, 0.72], [0.34, 0.81], [0.56, 0.73], [0.78, 0.83], [1, 0.75]] },
        { haze: 0.08, pagoda: 0,
          trees: [[0.12, 0.010, -0.5, 3], [0.60, 0.011, 0.4, 2]],
          pts: [[0, 0.86], [0.20, 0.81], [0.45, 0.90], [0.70, 0.82], [0.90, 0.89], [1, 0.86]] },
        { haze: 0.0, pagoda: 0,
          trees: [[0.05, 0.017, 0.5, 4], [0.14, 0.013, -0.4, 3], [0.92, 0.015, -0.5, 3]],
          pts: [[0, 0.92], [0.25, 0.96], [0.50, 0.89], [0.78, 0.97], [1, 0.92]] }
    ]

    // Foliage pad layout relative to the trunk top: [dx, bottom dy, half width] in units of u.
    readonly property var pads: [[0.4, -0.3, 3.0], [-2.5, 1.9, 2.5], [2.6, 2.7, 2.2], [-0.8, 4.1, 2.1]]

    // ---- colour helper: haze toward the sky, then toward night by (1 - light) ----
    function lit(base, haze) {
        var c = Qt.tint(Qt.color(base), Qt.rgba(hazeColor.r, hazeColor.g, hazeColor.b, haze))
        return Qt.tint(c, Qt.rgba(nightColor.r, nightColor.g, nightColor.b,
                                  1 - Math.max(0, Math.min(1, light))))
    }

    // ---- hills ----
    function pointsY(pts, x) {
        for (var i = 1; i < pts.length; i++) {
            if (x <= pts[i][0]) {
                var t = (x - pts[i - 1][0]) / (pts[i][0] - pts[i - 1][0])
                return pts[i - 1][1] + (pts[i][1] - pts[i - 1][1]) * t * t * (3 - 2 * t)
            }
        }
        return pts[pts.length - 1][1]
    }

    // Crest curve segments (no leading M), optionally shifted down by dy and/or reversed.
    function crestSegs(pts, w, h, dy, rev) {
        var s = ""
        var i
        if (!rev) {
            for (i = 1; i < pts.length; i++) {
                var x0 = pts[i - 1][0], y0 = pts[i - 1][1] * h + dy, x1 = pts[i][0], y1 = pts[i][1] * h + dy
                var dx = (x1 - x0) / 3
                s += " C " + (x0 + dx) * w + " " + y0 + " " + (x1 - dx) * w + " " + y1 + " " + x1 * w + " " + y1
            }
        } else {
            for (i = pts.length - 1; i >= 1; i--) {
                var a0 = pts[i - 1][0], b0 = pts[i - 1][1] * h + dy, a1 = pts[i][0], b1 = pts[i][1] * h + dy
                var d = (a1 - a0) / 3
                s += " C " + (a1 - d) * w + " " + b1 + " " + (a0 + d) * w + " " + b0 + " " + a0 * w + " " + b0
            }
        }
        return s
    }

    function crestPath(pts, w, h) {
        return "M 0 " + pts[0][1] * h + crestSegs(pts, w, h, 0, false)
    }

    function hillPath(pts, w, h) {
        return crestPath(pts, w, h) + " L " + w + " " + (h + 2) + " L 0 " + (h + 2) + " Z"
    }

    // Band between the crest and the crest shifted down by dy (bokashi step).
    function bandPath(pts, w, h, dy) {
        return crestPath(pts, w, h) + " L " + w + " " + (pts[pts.length - 1][1] * h + dy)
             + crestSegs(pts, w, h, dy, true) + " Z"
    }

    // ---- umbrella pines ----
    function padPath(cx, cy, a) {
        var b = 0.3 * a
        return " M " + (cx - a) + " " + cy
             + " C " + (cx - 1.02 * a) + " " + (cy - 0.9 * b) + " " + (cx - 0.62 * a) + " " + (cy - 1.05 * b)
                     + " " + (cx - 0.35 * a) + " " + (cy - 0.85 * b)
             + " C " + (cx - 0.30 * a) + " " + (cy - 1.35 * b) + " " + (cx + 0.10 * a) + " " + (cy - 1.45 * b)
                     + " " + (cx + 0.25 * a) + " " + (cy - 1.10 * b)
             + " C " + (cx + 0.50 * a) + " " + (cy - 1.20 * b) + " " + (cx + 1.05 * a) + " " + (cy - 0.80 * b)
                     + " " + (cx + a) + " " + cy + " Z"
    }

    // One tree, in coordinates relative to its trunk base. Returns {bx, by (base in item space),
    // tx, ty (trunk top, relative), trunk, pads}: trunk (+branches) is stroke-only, pads are filled + outlined.
    function treeParts(pts, tr, w, h) {
        var u = tr[1] * Math.min(w, h), lean = tr[2]
        var tx = lean * u, ty = -6 * u
        var trunk = "M 0 0 C " + (-0.4 * lean * u) + " " + (-2 * u) + " " + (1.2 * lean * u) + " " + (-4 * u)
                  + " " + tx + " " + ty
        var pads = ""
        for (var k = 0; k < tr[3]; k++) {
            var pd = root.pads[k]
            var cx = tx + pd[0] * u, cy = ty + pd[1] * u
            if (k > 0) {
                var sy = cy + 0.8 * u, sx = tx - lean * (sy - ty) / 6
                trunk += " M " + sx + " " + sy + " Q " + (sx + cx) / 2 + " " + (cy + 0.4 * u) + " " + cx + " " + cy
            }
            pads += padPath(cx, cy, pd[2] * u)
        }
        return { bx: tr[0] * w, by: pointsY(pts, tr[0]) * h + 0.4 * u,   // base buried in the hill
                 tx: tx, ty: ty, trunk: trunk, pads: pads }
    }

    // ---- pagoda: 3 tiers, upturned eaves ----
    function roofPath(cx, e, wd, r, p) {
        return " M " + (cx - wd) + " " + (e - 0.05 * p)
             + " Q " + (cx - 0.72 * wd) + " " + (e + 0.03 * p) + " " + (cx - 0.42 * wd) + " " + (e + 0.02 * p)
             + " L " + (cx + 0.42 * wd) + " " + (e + 0.02 * p)
             + " Q " + (cx + 0.72 * wd) + " " + (e + 0.03 * p) + " " + (cx + wd) + " " + (e - 0.05 * p)
             + " Q " + (cx + 0.5 * wd) + " " + (e - 0.25 * r) + " " + (cx + 0.14 * wd) + " " + (e - r)
             + " L " + (cx - 0.14 * wd) + " " + (e - r)
             + " Q " + (cx - 0.5 * wd) + " " + (e - 0.25 * r) + " " + (cx - wd) + " " + (e - 0.05 * p) + " Z"
    }

    // Returns {body, roof, fin}. Total height 0.06 * h, sitting on the crest at x = fx.
    function pagodaParts(pts, fx, w, h) {
        if (!(fx > 0))
            return { body: "M 0 0", roof: "M 0 0", fin: "M 0 0" }
        var p = 0.06 * h / 0.88, cx = fx * w, yB = pointsY(pts, fx) * h + 0.04 * p
        var bw = [0.16, 0.13, 0.10], rw = [0.34, 0.27, 0.21]
        var lo = [0, -0.24, -0.46], hi = [-0.15, -0.37, -0.58]
        var body = "", roof = ""
        for (var i = 0; i < 3; i++) {
            var y0 = yB + lo[i] * p, y1 = yB + hi[i] * p, b = bw[i] * p
            body += " M " + (cx - b) + " " + y0 + " L " + (cx + b) + " " + y0
                  + " L " + (cx + b) + " " + y1 + " L " + (cx - b) + " " + y1 + " Z"
            roof += roofPath(cx, y1, rw[i] * p, 0.12 * p, p)
        }
        var fin = " M " + cx + " " + (yB - 0.70 * p) + " L " + cx + " " + (yB - 0.90 * p)
                + " M " + (cx - 0.05 * p) + " " + (yB - 0.78 * p) + " L " + (cx + 0.05 * p) + " " + (yB - 0.78 * p)
                + " M " + (cx - 0.04 * p) + " " + (yB - 0.84 * p) + " L " + (cx + 0.04 * p) + " " + (yB - 0.84 * p)
        return { body: body, roof: roof, fin: fin }
    }

    // ---- volcano ----
    function bz(a, b, c, d, t) {
        var u = 1 - t
        return u * u * u * a + 3 * u * u * t * b + 3 * u * t * t * c + t * t * t * d
    }
    function lp(a, b, t) { return [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t] }
    function pt(p) { return " " + p[0] + " " + p[1] }
    // Right part [t,1] of a cubic (de Casteljau).
    function bezTail(P, t) {
        var a = lp(P[0], P[1], t), b = lp(P[1], P[2], t), c = lp(P[2], P[3], t)
        var d = lp(a, b, t), e = lp(b, c, t)
        return [lp(d, e, t), e, c, P[3]]
    }

    // Returns {body, cap, gy1, gy2}: cone outline, snow cap polygon, bokashi gradient span.
    function buildVolcano(w, h, cap) {
        if (w <= 0 || h <= 0)
            return { body: "M 0 0", cap: "M 0 0", gy1: 0, gy2: 1 }
        var asp = w / h, t = Math.max(0, Math.min(1, (asp - 0.5625) / 0.4375))
        var px = (0.6 + 0.08 * t) * w, py = 0.30 * h, by = 0.74 * h   // base hidden behind far hills
        var hw = Math.min(0.40 * w, 0.9 * h), sw = 0.05 * hw           // base / summit half widths
        var Hb = by - py, Hv = 0.36 * h, dx = hw - sw, notch = 0.03 * Hb
        var c = Math.max(0.05, Math.min(0.9, cap))

        // Concave left flank, base to rim; right flank is its mirror.
        var L = [[px - hw, by], [px - hw + 0.30 * dx, by - 0.12 * Hb],
                 [px - sw - 0.08 * dx, py + 0.40 * Hb], [px - sw, py]]
        var R = []
        for (var i = 0; i < 4; i++) R.push([2 * px - L[i][0], L[i][1]])

        var body = "M" + pt(L[0]) + " C" + pt(L[1]) + pt(L[2]) + pt(L[3])
                 + " L " + px + " " + (py + notch) + " L" + pt(R[3])
                 + " C" + pt(R[2]) + pt(R[1]) + pt(R[0]) + " Z"

        // Parameter where the flank reaches the cap line (y decreases with t).
        var yc = py + c * Hv, lo = 0, hi = 1
        for (var k = 0; k < 28; k++) {
            var mid = (lo + hi) / 2
            if (bz(L[0][1], L[1][1], L[2][1], L[3][1], mid) > yc) lo = mid; else hi = mid
        }
        var ql = bezTail(L, lo), qr = bezTail(R, lo)
        var xl = ql[0][0], xr = qr[0][0]

        // Jagged lower edge: 5-8 downward drips, count grows with the cap.
        var n = Math.max(5, Math.min(8, Math.round(5 + (c - 0.15) / 0.40 * 3)))
        var lens = [0.10, 0.05, 0.14, 0.07, 0.12, 0.04, 0.11, 0.06]
        var pos = [0.50, 0.40, 0.60, 0.45, 0.55, 0.40, 0.60, 0.50]
        var s = (xr - xl) / n
        var capD = "M " + xl + " " + yc
        for (var j = 0; j < n; j++) {
            var tx = xl + j * s + s * pos[j]
            capD += " L " + (tx - 0.22 * s) + " " + yc + " L " + tx + " " + (yc + lens[j] * Hv)
                  + " L " + (tx + 0.22 * s) + " " + yc
                  + " L " + (xl + (j + 1) * s) + " " + (j === n - 1 ? yc : yc - 0.015 * Hv)
        }
        capD += " C" + pt(qr[1]) + pt(qr[2]) + pt(qr[3])
              + " L " + px + " " + (py + notch) + " L" + pt(ql[3])
              + " C" + pt(ql[2]) + pt(ql[1]) + pt(ql[0]) + " Z"

        return { body: body, cap: capD, gy1: yc, gy2: yc + 0.30 * Hv }
    }

    readonly property var volc: buildVolcano(width, height, snowCap)

    // Volcano colours: darker bokashi at the top of the rock, lit blue-indigo below.
    property color volcTop: lit("#26407c", 0.18)
    property color volcRock: lit("#3a5a9a", 0.18)
    property color snowFill: lit("#f7f4ec", 0.08)
    Behavior on volcTop { ColorAnimation { duration: 20000 } }
    Behavior on volcRock { ColorAnimation { duration: 20000 } }
    Behavior on snowFill { ColorAnimation { duration: 20000 } }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: root.ink
            strokeWidth: root.ow
            joinStyle: ShapePath.RoundJoin
            fillGradient: LinearGradient {
                x1: 0; y1: root.volc.gy1
                x2: 0; y2: root.volc.gy2
                GradientStop { position: 0; color: root.volcTop }
                GradientStop { position: 1; color: root.volcRock }
            }
            PathSvg { path: root.volc.body }
        }
        ShapePath {
            strokeColor: root.ink
            strokeWidth: root.ow
            joinStyle: ShapePath.RoundJoin
            fillColor: root.snowFill
            PathSvg { path: root.volc.cap }
        }
    }

    Repeater {
        model: root.layers.length

        Shape {
            id: hill
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            readonly property var def: root.layers[index]
            readonly property var pg: root.pagodaParts(def.pts, def.pagoda, root.width, root.height)

            // Haze lifts far layers toward the sky, then everything sinks toward night.
            readonly property color shade: root.lit(root.colors && root.colors[index] ? root.colors[index] : "#445566", def.haze)
            property color fill: shade
            property color treeFill: root.lit("#1d5a3a", def.haze)
            property color vermFill: root.lit("#c8432b", def.haze * 0.5)
            property color roofFill: root.lit("#2a2236", def.haze * 0.5)
            Behavior on fill { ColorAnimation { duration: 20000 } }
            Behavior on treeFill { ColorAnimation { duration: 20000 } }
            Behavior on vermFill { ColorAnimation { duration: 20000 } }
            Behavior on roofFill { ColorAnimation { duration: 20000 } }

            // Hill body.
            ShapePath {
                strokeColor: "transparent"
                strokeWidth: -1
                fillColor: hill.fill
                PathSvg { path: root.hillPath(hill.def.pts, root.width, root.height) }
            }
            // Bokashi crest: three stepped darker washes (~6% of height) fading down.
            ShapePath {
                strokeColor: "transparent"
                strokeWidth: -1
                fillColor: Qt.darker(hill.fill, 1.10)
                PathSvg { path: root.bandPath(hill.def.pts, root.width, root.height, 0.06 * root.height) }
            }
            ShapePath {
                strokeColor: "transparent"
                strokeWidth: -1
                fillColor: Qt.darker(hill.fill, 1.22)
                PathSvg { path: root.bandPath(hill.def.pts, root.width, root.height, 0.036 * root.height) }
            }
            ShapePath {
                strokeColor: "transparent"
                strokeWidth: -1
                fillColor: Qt.darker(hill.fill, 1.36)
                PathSvg { path: root.bandPath(hill.def.pts, root.width, root.height, 0.016 * root.height) }
            }
            // Ink line on the crest only.
            ShapePath {
                strokeColor: root.ink
                strokeWidth: root.ow
                fillColor: "transparent"
                joinStyle: ShapePath.RoundJoin
                capStyle: ShapePath.RoundCap
                PathSvg { path: root.crestPath(hill.def.pts, root.width, root.height) }
            }
            // Swaying pines: one Item per tree at its trunk base, drawn right after this hill
            // (child items paint above the Shape's own paths, below the next layer).
            Repeater {
                model: hill.def.trees

                Item {
                    id: tree
                    readonly property var tp: root.treeParts(hill.def.pts, modelData, root.width, root.height)
                    readonly property real amp: 0.6 + 1.6 * Math.abs(root.windX)
                    property real unit: Math.random() * 2 - 1      // -1..1, random start = random phase
                    readonly property int halfMs: (3500 + Math.random() * 2500) / 2

                    x: tp.bx
                    y: tp.by
                    transform: Rotation { angle: root.windX * 2.5 + tree.unit * tree.amp }

                    SequentialAnimation on unit {
                        loops: Animation.Infinite
                        running: true
                        paused: running && !root.running
                        NumberAnimation { to: 1; duration: tree.halfMs; easing.type: Easing.InOutSine }
                        NumberAnimation { to: -1; duration: tree.halfMs; easing.type: Easing.InOutSine }
                    }

                    // Trunk and branches.
                    Shape {
                        preferredRendererType: Shape.CurveRenderer
                        ShapePath {
                            strokeColor: root.ink
                            strokeWidth: root.trunkW
                            fillColor: "transparent"
                            joinStyle: ShapePath.RoundJoin
                            capStyle: ShapePath.RoundCap
                            PathSvg { path: tree.tp.trunk }
                        }
                    }
                    // Foliage pads: extra half-again sway about the trunk top.
                    Shape {
                        preferredRendererType: Shape.CurveRenderer
                        transform: Rotation {
                            origin.x: tree.tp.tx
                            origin.y: tree.tp.ty
                            angle: tree.unit * tree.amp * 0.5
                        }
                        ShapePath {
                            strokeColor: root.ink
                            strokeWidth: root.ow
                            fillColor: hill.treeFill
                            fillRule: ShapePath.WindingFill
                            joinStyle: ShapePath.RoundJoin
                            PathSvg { path: tree.tp.pads }
                        }
                    }
                }
            }
            // Pagoda: vermilion bodies, dark roofs, finial.
            ShapePath {
                strokeColor: root.ink
                strokeWidth: root.ow
                fillColor: hill.vermFill
                joinStyle: ShapePath.RoundJoin
                PathSvg { path: hill.pg.body }
            }
            ShapePath {
                strokeColor: root.ink
                strokeWidth: root.ow
                fillColor: hill.roofFill
                joinStyle: ShapePath.RoundJoin
                PathSvg { path: hill.pg.roof }
            }
            ShapePath {
                strokeColor: root.ink
                strokeWidth: root.ow
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathSvg { path: hill.pg.fin }
            }
        }
    }
}
