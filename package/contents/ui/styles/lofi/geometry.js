.pragma library

// Lofi Window style: pure geometry. Every function returns absolute pixel coordinates
// for a W x H screen as SVG path strings (QML PathSvg). QML rebuilds them only on
// resize / month change. Plain JS on purpose, so the art can be previewed as SVG outside QML.
//
// Room furniture comes back as draw lists: [{ d: path, c: palette key, a: alpha, w: stroke
// width (0 fills) }], drawn in order by Paint.qml and by the SVG preview.
//
// Fill-rule note: union paths (city, clouds, frame, branch) keep every subpath in
// the same winding direction and are drawn with ShapePath.WindingFill.

function clamp(x, a, b) { return Math.max(a, Math.min(b, x)) }

// mulberry32: deterministic, so the scene looks the same on every rebuild
function rng(seed) {
    var s = seed >>> 0
    return function () {
        s = (s + 0x6D2B79F5) | 0
        var t = Math.imul(s ^ (s >>> 15), 1 | s)
        t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t
        return ((t ^ (t >>> 14)) >>> 0) / 4294967296
    }
}

function q(v) { return Math.round(v * 10) / 10 }
function P(x, y) { return q(x) + " " + q(y) }

// clockwise on screen
function rect(x, y, w, h) {
    return "M" + P(x, y) + " L" + P(x + w, y) + " L" + P(x + w, y + h) + " L" + P(x, y + h) + " Z "
}
function rrect(x, y, w, h, r) {
    r = Math.min(r, w / 2, h / 2)
    var a = q(r) + " " + q(r) + " 0 0 1 "
    return "M" + P(x + r, y) + " L" + P(x + w - r, y) + " A" + a + P(x + w, y + r)
         + " L" + P(x + w, y + h - r) + " A" + a + P(x + w - r, y + h)
         + " L" + P(x + r, y + h) + " A" + a + P(x, y + h - r)
         + " L" + P(x, y + r) + " A" + a + P(x + r, y) + " Z "
}
function ellipse(cx, cy, rx, ry) {
    var a = q(rx) + " " + q(ry) + " 0 1 1 "
    return "M" + P(cx - rx, cy) + " A" + a + P(cx + rx, cy) + " A" + a + P(cx - rx, cy) + " Z "
}
function circle(cx, cy, r) { return ellipse(cx, cy, r, r) }
function capsule(x, y, w, h) {
    var r = h / 2, a = q(r) + " " + q(r) + " 0 0 1 "
    return "M" + P(x + r, y) + " L" + P(x + w - r, y) + " A" + a + P(x + w - r, y + h)
         + " L" + P(x + r, y + h) + " A" + a + P(x + r, y) + " Z "
}
function poly(pts) {
    var s = "M" + P(pts[0][0], pts[0][1])
    for (var i = 1; i < pts.length; i++) s += " L" + P(pts[i][0], pts[i][1])
    return s + " Z "
}

// append a draw op; empty paths are skipped
function op(list, d, c, a, w) {
    if (d) list.push({ d: d, c: c, a: a === undefined ? 1 : a, w: w || 0 })
}

// transform for local shapes: translate (ox, oy), scale s, rotate a (radians)
function T(ox, oy, s, a) {
    var c = Math.cos(a || 0) * s, n = Math.sin(a || 0) * s
    return function (x, y) { return [ox + x * c - y * n, oy + x * n + y * c] }
}
// segs: [["M", x, y], ["C", x1, y1, x2, y2, x, y], ["Q", ...], ["L", x, y], ["Z"]]
function pathT(segs, tf) {
    var s = ""
    for (var i = 0; i < segs.length; i++) {
        var g = segs[i]
        s += g[0]
        for (var k = 1; k < g.length; k += 2) {
            var p = tf(g[k], g[k + 1])
            s += " " + P(p[0], p[1])
        }
        s += " "
    }
    return s
}
function rectSegs(x, y, w, h) { return [["M", x, y], ["L", x + w, y], ["L", x + w, y + h], ["L", x, y + h], ["Z"]] }
// ellipse as cubics, so pathT can rotate it; clockwise
function ellipseSegs(cx, cy, rx, ry) {
    var k = 0.5523
    return [["M", cx + rx, cy],
            ["C", cx + rx, cy + ry * k, cx + rx * k, cy + ry, cx, cy + ry],
            ["C", cx - rx * k, cy + ry, cx - rx, cy + ry * k, cx - rx, cy],
            ["C", cx - rx, cy - ry * k, cx - rx * k, cy - ry, cx, cy - ry],
            ["C", cx + rx * k, cy - ry, cx + rx, cy - ry * k, cx + rx, cy], ["Z"]]
}

function bez(a, b, c, d, t) {
    var u = 1 - t
    return [u * u * u * a[0] + 3 * u * u * t * b[0] + 3 * u * t * t * c[0] + t * t * t * d[0],
            u * u * u * a[1] + 3 * u * u * t * b[1] + 3 * u * t * t * c[1] + t * t * t * d[1]]
}
function bezAngle(a, b, c, d, t) {
    var u = 1 - t
    var dx = 3 * u * u * (b[0] - a[0]) + 6 * u * t * (c[0] - b[0]) + 3 * t * t * (d[0] - c[0])
    var dy = 3 * u * u * (b[1] - a[1]) + 6 * u * t * (c[1] - b[1]) + 3 * t * t * (d[1] - c[1])
    return Math.atan2(dy, dx)
}
function cubicStr(a, b, c, d) { return "M" + P(a[0], a[1]) + " C" + P(b[0], b[1]) + " " + P(c[0], c[1]) + " " + P(d[0], d[1]) + " " }

// ---- room layout ---------------------------------------------------------

function layout(W, H) {
    var L = { W: W, H: H }
    var D = Math.min(H, W * 1.25)                    // room scale; below H only on tall portrait screens
    L.D = D
    L.u = Math.min(H, W * 0.9) * 0.01                // object unit
    L.f = Math.max(5, D * 0.016)                     // frame thickness
    L.m = L.f * 0.62                                 // mullion thickness
    // bottom up: the desk, a strip of wall, the window, centred with wall on both sides
    L.deskFront = H - D * 0.05                       // front edge of the desk top
    L.deskY = L.deskFront - D * 0.14                 // back edge, against the wall
    L.sillY = L.deskY - D * 0.17
    var ww = Math.min(W * clamp(0.54 + (1.6 - W / H) * 0.15, 0.54, 0.8), D * 1.45), wy = H * 0.1
    L.win = { x: (W - ww) / 2, y: wy, w: ww, h: L.sillY - wy }
    L.n = clamp(Math.round(L.win.w / (0.9 * L.win.h)), 1, 4)
    var gx = L.win.x + L.f, gy = L.win.y + L.f
    var gw = L.win.w - 2 * L.f, gb = L.sillY - L.f * 1.25
    L.glass = { x: gx, y: gy, w: gw, h: gb - gy }
    L.transomY = gy + (gb - gy) * 0.27
    L.colW = (gw - (L.n - 1) * L.m) / L.n
    L.panes = []
    for (var i = 0; i < L.n; i++) {
        var px = gx + i * (L.colW + L.m)
        L.panes.push({ x: px, y: gy, w: L.colW, h: L.transomY - gy, upper: true })
        L.panes.push({ x: px, y: L.transomY + L.m, w: L.colW, h: gb - L.transomY - L.m, upper: false })
    }
    L.casing = L.f * 1.1
    L.sill = { x: L.win.x - L.f * 1.9, w: L.win.w + L.f * 3.8, y: L.sillY, depth: D * 0.024, front: D * 0.02 }
    L.frontY = L.sillY + L.sill.depth                // front edge of the sill top
    L.baseY = L.sillY + L.sill.depth * 0.6           // where objects stand
    // the outside was first drawn for a window 0.74 screen heights tall; o is that screen height now
    L.o = Math.min(L.win.h / 0.74, L.win.w / 0.9)
    L.horizon = L.sillY - L.o * 0.18
    // curtains hang from a rod above the window and reach cw past the casing onto the wall
    L.rodY = L.win.y - L.casing - D * 0.022
    L.cw = Math.min(D * 0.1, (L.win.x - L.casing) * 0.42)
    // free wall between the curtains and the screen edges, for shelves and pictures
    var x0 = D * 0.03, x1 = L.win.x - L.casing - L.cw - D * 0.035
    L.wallL = { x: x0, w: Math.max(0, x1 - x0) }
    L.wallR = { x: W - x1, w: Math.max(0, x1 - x0) }
    return L
}

// sun and moon come in screen fractions (horizon at 0.62, highest at 0.12); map them into the window
function skyPoint(L, x, y) {
    return [L.win.x + x * L.win.w, L.horizon - (0.62 - y) * 1.7 * (L.horizon - L.win.y)]
}

function room(L) {
    var w = L.win, W = L.W, H = L.H, c = L.casing, s = L.sill
    var gb = L.glass.y + L.glass.h
    var frameP = rect(w.x, w.y, w.w, L.f) + rect(w.x, gb, w.w, L.sillY - gb)
               + rect(w.x, w.y, L.f, w.h) + rect(w.x + w.w - L.f, w.y, L.f, w.h)
               + rect(L.glass.x, L.transomY, L.glass.w, L.m)
    for (var i = 1; i < L.n; i++)
        frameP += rect(L.glass.x + i * (L.colW + L.m) - L.m, L.glass.y, L.m, L.glass.h)
    var edges = ""
    for (var k = 0; k < L.panes.length; k++) {
        var p = L.panes[k]
        edges += rect(p.x, p.y, p.w, p.h)
    }
    var d = s.depth * 0.7
    return {
        wall: rect(0, 0, W, H) + rect(w.x, w.y, w.w, w.h),                       // OddEven: hole
        casing: rect(w.x - c, w.y - c, w.w + 2 * c, L.sillY - w.y + c) + rect(w.x, w.y, w.w, w.h),
        frame: frameP,
        edges: edges,
        // highlight on the top face of the bottom rail and transom (light from the room)
        sheen: rect(w.x + L.f, gb, w.w - 2 * L.f, Math.max(1, L.f * 0.18))
             + rect(L.glass.x, L.transomY + L.m - Math.max(1, L.m * 0.2), L.glass.w, Math.max(1, L.m * 0.2)),
        sillTop: "M" + P(s.x + d, L.sillY) + " L" + P(s.x + s.w - d, L.sillY) + " L" + P(s.x + s.w, L.frontY)
               + " L" + P(s.x, L.frontY) + " Z",
        sillFront: rect(s.x, L.frontY, s.w, s.front),
        sillLip: rect(s.x, L.frontY, s.w, Math.max(1, s.front * 0.14))
    }
}

// ---- outside (sizes in L.o, the screen height the outside was designed for) --

var LIT_WEIGHTS = [0.42, 0.30, 0.20, 0.08]

function city(L, near) {
    var H = L.o, r = rng(near ? 7331 : 4242)
    // roof heights were designed for a sill at 0.8 H; keep them relative to the sill
    function Y(f) { return L.sillY - H * (0.8 - f) }
    var x = L.win.x - H * 0.06, end = L.win.x + L.win.w + H * 0.06
    var base = L.sillY + 1
    var o = { body: "", lit: ["", "", "", ""], glass: "", beacon: ["", ""], halo: ["", ""], flick: [] }
    var cw = H * (near ? 0.0135 : 0.0095), ch = H * (near ? 0.02 : 0.0142)
    var ww = H * (near ? 0.0066 : 0.0042), wh = H * (near ? 0.0098 : 0.0066)
    var aw = Math.max(1.2, H * 0.0014)
    var seen = 0

    function antenna(ax, ay) {
        var ah = H * (0.025 + r() * 0.04), g = r() < 0.5 ? 0 : 1, br = H * (near ? 0.0026 : 0.0018)
        o.body += rect(ax - aw / 2, ay - ah, aw, ah)
        o.beacon[g] += circle(ax, ay - ah, br)
        o.halo[g] += circle(ax, ay - ah, br * 3.2)
    }
    function pickColor() {
        var v = r(), acc = 0
        for (var i = 0; i < 4; i++) { acc += LIT_WEIGHTS[i]; if (v < acc) return i }
        return 0
    }
    function lit(wx, wy, w, h) {
        var c = pickColor()
        o.glass += rect(wx, wy, w, h)              // every window is glass by day
        o.lit[c] += rect(wx, wy, w, h)
        // reservoir sample of visible lit windows for the slow on/off life
        if (near && wx > L.win.x && wx + w < L.win.x + L.win.w && wy + h < L.sillY - H * 0.01) {
            seen++
            var item = { x: wx, y: wy, w: w, h: h, c: c }
            if (o.flick.length < 18) o.flick.push(item)
            else if (r() < 18 / seen) o.flick[Math.floor(r() * 18)] = item
        }
    }

    while (x < end) {
        var bw = H * (near ? 0.07 + r() * 0.1 : 0.045 + r() * 0.075)
        var top = Y(near ? 0.6 + r() * 0.12 : 0.47 + r() * 0.15)
        if (near && r() < 0.12) top = Y(0.52 + r() * 0.05)
        o.body += rect(x, top, bw, base - top)

        var k = r()
        if (k < 0.16) {                                    // setback crown
            var sw = bw * (0.45 + r() * 0.25), sh = H * (0.015 + r() * 0.03), sx = x + (bw - sw) * r()
            o.body += rect(sx, top - sh, sw, sh)
            if (r() < 0.5) antenna(sx + sw * 0.5, top - sh)
        } else if (k < 0.28 && near) {                    // water tower
            var tw = H * 0.021, th = H * 0.024, leg = H * 0.012, tx = x + bw * (0.2 + 0.5 * r())
            o.body += rect(tx + tw * 0.12, top - leg, aw * 1.4, leg) + rect(tx + tw * 0.82, top - leg, aw * 1.4, leg)
            o.body += rect(tx, top - leg - th, tw, th)
            o.body += "M" + P(tx - tw * 0.08, top - leg - th) + " L" + P(tx + tw / 2, top - leg - th - tw * 0.45)
                    + " L" + P(tx + tw * 1.08, top - leg - th) + " Z "
        } else if (k < 0.42) {                            // flat roof with antenna
            antenna(x + bw * (0.2 + 0.6 * r()), top)
        } else if (k < 0.48) {                            // gable
            o.body += "M" + P(x, top) + " L" + P(x + bw / 2, top - bw * 0.28) + " L" + P(x + bw, top) + " Z "
        } else if (!near && k < 0.53) {                   // spire
            o.body += "M" + P(x + bw * 0.3, top) + " L" + P(x + bw / 2, top - H * 0.07) + " L" + P(x + bw * 0.7, top) + " Z "
        }
        if (r() < 0.3) o.body += rect(x + bw * (0.1 + 0.6 * r()), top - H * 0.008, H * 0.014, H * 0.008)   // roof box

        var style = r(), litP = 0.06 + r() * 0.42
        if (style >= 0.1) {
            var pad = H * 0.006
            var cols = Math.max(1, Math.floor((bw - 2 * pad) / cw))
            var x0 = x + (bw - cols * cw) / 2 + (cw - ww) / 2
            for (var wy = top + H * 0.012; wy + wh < base; wy += ch) {
                if (style < 0.18) {                      // ribbon windows
                    var rw = bw - 2 * pad - (cw - ww)
                    if (r() < litP * 0.6) lit(x0, wy, rw, wh * 0.9)
                    else o.glass += rect(x0, wy, rw, wh * 0.9)
                } else {
                    for (var i = 0; i < cols; i++) {
                        var wx = x0 + i * cw
                        if (r() < litP) lit(wx, wy, ww, wh)
                        else o.glass += rect(wx, wy, ww, wh)
                    }
                }
            }
        }
        x += bw + (r() < 0.3 ? H * 0.006 * r() : -H * 0.004)
    }
    return o
}

// three twinkle groups of star dots in the upper half of the window
function starPaths(L) {
    var r = rng(99), o = ["", "", ""]
    var n = Math.round(clamp(L.win.w * L.win.h / 1e6 * 32, 24, 180))
    for (var i = 0; i < n; i++)
        o[i % 3] += circle(L.win.x + r() * L.win.w, L.win.y + r() * L.win.h * 0.5, L.o * (0.0011 + r() * r() * 0.0026))
    return o
}

// cumulus: union of puffs on a flat capsule base; light = same puffs nudged up-left
function cloud(seed, w) {
    var r = rng(seed), n = 5 + Math.floor(r() * 4), sh = "", li = "", top = 0
    for (var i = 0; i < n; i++) {
        var t = i / (n - 1)
        var cx = w * (0.14 + 0.72 * t + (r() - 0.5) * 0.06)
        var rad = w * (0.085 + 0.12 * (1 - Math.abs(t - 0.5) * 1.6) + r() * 0.05)
        var cy = -rad * (0.95 + r() * 0.35)
        sh += circle(cx, cy, rad)
        li += circle(cx - rad * 0.07, cy - rad * 0.13, rad * 0.83)
        top = Math.min(top, cy - rad)
    }
    sh += capsule(w * 0.05, -w * 0.09, w * 0.9, w * 0.09)
    return { shadow: sh, light: li, h: -top }
}

// drifting clouds: x = win.x - w + frac(phase + k * clock) * (win.w + w), k whole passes per clock cycle
function clouds(L) {
    var r = rng(808), a = [], sky = L.horizon - L.win.y
    for (var i = 0; i < 7; i++) {
        var w = L.o * (0.16 + 0.2 * r())
        var c = cloud(101 + i * 37, w)
        c.w = w
        c.y = L.win.y + sky * (0.18 + 0.46 * r())
        c.phase = r()
        c.k = 2 + Math.floor(r() * 4)
        a.push(c)
    }
    return a
}

function season(month) {
    return [3, 3, 0, 0, 0, 1, 1, 1, 2, 2, 2, 3][((month % 12) + 12) % 12]   // 0 spring .. 3 winter (month 0 = January)
}

// tapered limb polygon along a cubic; returns polygon + sampled spine
function limb(a, b, c, d, w0, w1, N) {
    var left = [], right = [], spine = []
    for (var i = 0; i <= N; i++) {
        var t = i / N, p = bez(a, b, c, d, t), an = bezAngle(a, b, c, d, t)
        var w = (w0 + (w1 - w0) * t) / 2, nx = -Math.sin(an), ny = Math.cos(an)
        left.push([p[0] - nx * w, p[1] - ny * w])
        right.push([p[0] + nx * w, p[1] + ny * w])
        spine.push({ x: p[0], y: p[1], a: an, t: t, w: w * 2 })
    }
    var s = "M" + P(left[0][0], left[0][1])
    for (var j = 1; j < left.length; j++) s += " L" + P(left[j][0], left[j][1])
    for (var k = right.length - 1; k >= 0; k--) s += " L" + P(right[k][0], right[k][1])
    return { path: s + " Z ", spine: spine, left: left, right: right }
}

var LEAF = [["M", 0, 0], ["C", 0.25, -0.34, 0.7, -0.3, 1, 0], ["C", 0.7, 0.3, 0.25, 0.34, 0, 0], ["Z"]]

// outside branch reaching in from the top-right; leaves/blossoms/snow by season
function branch(L, month) {
    var H = L.o, r = rng(2024), se = season(month)
    var ax = L.win.x + L.win.w + H * 0.01, ay = L.win.y - H * 0.01
    var len = Math.min(H * 0.5, L.win.w * 0.62), drop = len * 0.36
    var A = [ax, ay], B = [ax - len * 0.35, ay + drop * 0.05], C = [ax - len * 0.72, ay + drop * 0.8], D = [ax - len, ay + drop]
    var o = { wood: "", leaf: ["", "", ""], petals: "", centers: "", snow: "", ax: ax, ay: ay, season: se }
    var main = limb(A, B, C, D, H * 0.03, H * 0.004, 30)
    o.wood += main.path
    var spines = [{ s: main.spine, from: 0.32 }]
    var tops = [main.left]

    var nT = 9
    for (var k = 0; k < nT; k++) {
        var t = 0.14 + 0.78 * (k + 0.2 + r() * 0.6) / nT
        var p = bez(A, B, C, D, t), an = bezAngle(A, B, C, D, t)
        var side = k % 2 ? 1 : -1
        var a = an + side * (0.5 + r() * 0.45)
        var tl = H * (0.06 + r() * 0.08) * (1 - 0.35 * t) * (len / (H * 0.5))
        var e = [p[0] + Math.cos(a) * tl, p[1] + Math.sin(a) * tl + tl * 0.18]
        var c1 = [p[0] + Math.cos(a) * tl * 0.35, p[1] + Math.sin(a) * tl * 0.35]
        var c2 = [e[0] - Math.cos(a + side * 0.3) * tl * 0.3, e[1] - Math.sin(a + side * 0.3) * tl * 0.3]
        var w0 = (H * 0.03 + (H * 0.004 - H * 0.03) * t) * 0.55
        var tw = limb(p, c1, c2, e, Math.max(w0, H * 0.003), H * 0.0013, 12)
        o.wood += tw.path
        spines.push({ s: tw.spine, from: 0.18 })
        tops.push(side < 0 ? tw.left : tw.right)
    }

    if (se === 3) {                                   // winter: snow on the upper edges
        for (var m = 0; m < tops.length; m++) {
            var pts = tops[m], seg = ""
            for (var j = 0; j < pts.length - 2; j++) {
                seg += (j === 0 ? "M" : " L") + P(pts[j][0], pts[j][1] - H * 0.0012)
            }
            o.snow += seg + " "
        }
        return o
    }

    var density = [0.75, 1, 0.85][se]
    var step = H * (se === 1 ? 0.014 : 0.018)
    for (var n = 0; n < spines.length; n++) {
        var sp = spines[n].s, acc = 0, flip = 1
        for (var i = 1; i < sp.length; i++) {
            acc += Math.hypot(sp[i].x - sp[i - 1].x, sp[i].y - sp[i - 1].y)
            if (sp[i].t < spines[n].from || acc < step) continue
            acc = 0
            flip = -flip
            if (r() > density) continue
            var sz = H * (0.02 + r() * 0.012) * (se === 0 ? 0.75 : 1)
            var ang = sp[i].a + flip * (0.7 + r() * 0.5)
            ang = ang + (Math.PI / 2 - ang) * 0.22                         // droop
            o.leaf[Math.floor(r() * 3)] += pathT(LEAF, T(sp[i].x, sp[i].y, sz, ang))
        }
        if (se === 0) {                                                   // blossoms near tips
            for (var b = 0; b < 4; b++) {
                var pnt = sp[Math.floor(sp.length * (0.45 + 0.55 * r())) - 1] || sp[sp.length - 1]
                if (r() < 0.25) continue
                var pr = H * (0.0055 + r() * 0.003), bx = pnt.x + (r() - 0.5) * pr * 2, by = pnt.y + (r() - 0.5) * pr * 2
                for (var pi = 0; pi < 5; pi++) {
                    var pa = pi * Math.PI * 2 / 5 + r() * 0.3
                    o.petals += circle(bx + Math.cos(pa) * pr * 0.95, by + Math.sin(pa) * pr * 0.95, pr * 0.78)
                }
                o.centers += circle(bx, by, pr * 0.42)
            }
        }
    }
    return o
}

// ---- glass ---------------------------------------------------------------

function frost(L) {
    var r = rng(1717), H = L.o, s = ""
    function crystal(x, y, a, len, depth) {
        var ex = x + Math.cos(a) * len, ey = y + Math.sin(a) * len
        s += "M" + P(x, y) + " L" + P(ex, ey) + " "
        if (depth <= 0) return
        var nb = 2 + Math.floor(r() * 2)
        for (var i = 0; i < nb; i++) {
            var t = 0.25 + 0.65 * r()
            crystal(x + (ex - x) * t, y + (ey - y) * t, a + (r() < 0.5 ? -1 : 1) * (1.05 + (r() - 0.5) * 0.3),
                    len * (0.3 + 0.25 * r()), depth - 1)
        }
    }
    for (var k = 0; k < L.panes.length; k++) {
        var p = L.panes[k], seeds = Math.round(p.w / (H * (p.upper ? 0.05 : 0.022)))
        var reach = p.upper ? 0.35 : 1
        for (var i = 0; i < seeds; i++) {
            var fromLeft = r() < 0.5, dd = r() * r() * p.w * 0.5
            var x = fromLeft ? p.x + dd : p.x + p.w - dd
            var edgeY = p.upper ? p.y : p.y + p.h
            var dir = p.upper ? Math.PI / 2 : -Math.PI / 2
            var len = H * (0.008 + r() * 0.028) * (1 - dd / (p.w * 0.5) * 0.6) * reach
            crystal(x, edgeY, dir + (r() - 0.5) * 1.1, len, 2)
        }
        if (p.upper) continue
        for (var j = 0; j < seeds * 0.5; j++) {
            var left = r() < 0.5, yy = p.y + p.h - r() * r() * p.h * 0.5
            crystal(left ? p.x : p.x + p.w, yy, (left ? 0 : Math.PI) + (r() - 0.5) * 1.1,
                    H * (0.006 + r() * 0.02), 2)
        }
    }
    return s
}

// two slanted glints per pane; overflow hides under the frame
function reflections(L) {
    var s = ""
    for (var k = 0; k < L.panes.length; k++) {
        var p = L.panes[k], sl = p.h * 0.5, b = [[0.16, 0.08], [0.3, 0.025]]
        for (var i = 0; i < 2; i++) {
            var x0 = p.x + p.w * b[i][0], bw = p.w * b[i][1]
            s += "M" + P(x0 + sl, p.y) + " L" + P(x0 + sl + bw, p.y) + " L" + P(x0 + bw, p.y + p.h) + " L" + P(x0, p.y + p.h) + " Z "
        }
    }
    return s
}

// snow drifts on the outer ledge, deepest in the corners; QML scales the height with snowfall
function ledge(L) {
    var r = rng(555), s = "", gb = L.glass.y + L.glass.h, hg = L.o * 0.024
    for (var k = 1; k < L.panes.length; k += 2) {
        var p = L.panes[k], n = Math.max(3, Math.round(p.w / (L.o * 0.08)))
        s += "M" + P(p.x - 2, gb + 2) + " L" + P(p.x - 2, gb - hg)
        for (var i = 1; i <= n; i++) {
            var y1 = i === n ? gb - hg : gb - hg * (0.4 + 0.25 * r())
            s += " Q" + P(p.x + p.w * (i - 0.5) / n, gb - hg * (0.55 + 0.3 * r())) + " " + P(p.x + p.w * i / n, y1)
        }
        s += " L" + P(p.x + p.w + 2, gb + 2) + " Z "
    }
    return s
}

// ---- sill ----------------------------------------------------------------

var HEART = [["M", 0.12, 0], ["C", -0.05, -0.38, 0.5, -0.6, 1, 0], ["C", 0.5, 0.6, -0.05, 0.38, 0.12, 0], ["Z"]]

// pothos in a terracotta pot, some stems trailing over the sill
function plant(L) {
    var u = L.u, b = L.baseY, cx = L.win.x + Math.max(L.win.w * 0.3, 18 * u)
    var top = b - 5.2 * u, tw = 3.1 * u, bw = 2.35 * u, fe = L.frontY
    var stemsP = "", leaf = ["", ""], ops = []
    var stems = [
        [[cx - 0.8 * u, top - 1 * u], [cx - 2.6 * u, top - 5 * u], [cx - 4.8 * u, top - 8 * u], [cx - 3.6 * u, top - 11.5 * u]],
        [[cx + 0.3 * u, top - 1 * u], [cx + 0.6 * u, top - 5.5 * u], [cx + 2.8 * u, top - 9 * u], [cx + 1.4 * u, top - 13.5 * u]],
        [[cx + 1.2 * u, top - 1 * u], [cx + 3.6 * u, top - 4 * u], [cx + 6.2 * u, top - 6 * u], [cx + 7.8 * u, top - 8.8 * u]],
        [[cx + 2.6 * u, top - 1.1 * u], [cx + 5.8 * u, top - 1.6 * u], [cx + 7 * u, fe - 0.6 * u], [cx + 7.2 * u, b + 7.5 * u]],
        [[cx - 2.6 * u, top - 1.1 * u], [cx - 5.4 * u, top - 0.6 * u], [cx - 6.2 * u, fe], [cx - 5.8 * u, b + 4.8 * u]]
    ]
    var r = rng(31)
    for (var k = 0; k < stems.length; k++) {
        var s = stems[k]
        stemsP += cubicStr(s[0], s[1], s[2], s[3])
        var nL = 6 + Math.floor(r() * 3), flip = k % 2 ? 1 : -1
        for (var i = 0; i < nL; i++) {
            var t = 0.2 + 0.8 * (i + 0.5) / nL
            var p = bez(s[0], s[1], s[2], s[3], t), an = bezAngle(s[0], s[1], s[2], s[3], t)
            flip = -flip
            var ang = an + flip * (0.9 + r() * 0.35)
            if (p[1] > fe) ang = Math.PI / 2 + flip * (0.35 + r() * 0.3)       // hanging leaves point down
            var sz = u * (2.7 - 0.9 * t) * (0.85 + r() * 0.3)
            leaf[(i + k) % 2] += pathT(HEART, T(p[0], p[1], sz, ang))
        }
        var tip = s[3], ta = bezAngle(s[0], s[1], s[2], s[3], 1)
        leaf[k % 2] += pathT(HEART, T(tip[0], tip[1], u * 1.5, ta))
    }
    op(ops, ellipse(cx + 0.4 * u, b + 0.15 * u, tw * 1.25, 0.5 * u), "shadow", 0.35)
    op(ops, "M" + P(cx - tw, top) + " L" + P(cx + tw, top) + " L" + P(cx + bw, b) + " L" + P(cx - bw, b) + " Z ", "pot")
    op(ops, "M" + P(cx + tw * 0.3, top) + " L" + P(cx + tw, top) + " L" + P(cx + bw, b) + " L" + P(cx + bw * 0.3, b) + " Z ", "shadow", 0.25)
    op(ops, rect(cx - tw * 1.1, top - 1.15 * u, tw * 2.2, 1.25 * u), "potRim")
    op(ops, rect(cx - tw * 1.1, top - 0.25 * u, tw * 2.2, 0.35 * u), "shadow", 0.25)
    op(ops, ellipse(cx, top - 1.12 * u, tw, 0.32 * u), "soil")
    op(ops, stemsP, "stem", 1, Math.max(1.2, u * 0.3))
    op(ops, leaf[0], "leafA")
    op(ops, leaf[1], "leafB")
    return { cx: cx, ops: ops }
}

// round cactus with a flower in a small pot; (x, y) bottom centre, s = size unit
function cactus(ops, x, y, s) {
    var tw = 1.7 * s, bw = 1.3 * s, top = y - 2.6 * s, cy = top - 2.4 * s, fy = cy - 2.0 * s
    op(ops, ellipse(x + 0.3 * s, y + 0.1 * s, tw * 1.25, 0.35 * s), "shadow", 0.3)
    op(ops, ellipse(x - 1.5 * s, cy + 0.4 * s, 0.6 * s, 0.95 * s) + ellipse(x, cy, 1.5 * s, 2.05 * s), "cactus")
    op(ops, "M" + P(x - 0.55 * s, cy - 1.7 * s) + " Q" + P(x - 0.9 * s, cy) + " " + P(x - 0.55 * s, cy + 1.7 * s)
          + " M" + P(x + 0.55 * s, cy - 1.7 * s) + " Q" + P(x + 0.9 * s, cy) + " " + P(x + 0.55 * s, cy + 1.7 * s) + " ",
       "cactusDark", 0.8, Math.max(1, 0.16 * s))
    var fl = ""
    for (var i = 0; i < 5; i++) {
        var a = i * Math.PI * 2 / 5 - Math.PI / 2
        fl += circle(x + Math.cos(a) * 0.45 * s, fy + Math.sin(a) * 0.45 * s, 0.4 * s)
    }
    op(ops, fl, "flower")
    op(ops, circle(x, fy, 0.26 * s), "flowerCenter")
    op(ops, "M" + P(x - tw, top) + " L" + P(x + tw, top) + " L" + P(x + bw, y) + " L" + P(x - bw, y) + " Z ", "pot")
    op(ops, rect(x - tw * 1.08, top - 0.6 * s, tw * 2.16, 0.75 * s), "potRim")
}

// three books on the sill with a cactus on top, at the left end
function stack(L) {
    var u = L.u, b = L.baseY, ops = [], cx = L.win.x + Math.max(L.win.w * 0.09, 7 * u)
    var books = [[-5.0, 10, 1.5], [-4.3, 9, 1.25], [-4.7, 9.6, 1.6]], keys = ["bookA", "bookB", "bookC"]
    op(ops, ellipse(cx, b + 0.15 * u, 5.6 * u, 0.5 * u), "shadow", 0.35)
    var y = b, bands = ""
    for (var i = 0; i < 3; i++) {
        var bx = cx + books[i][0] * u, bwid = books[i][1] * u, bh = books[i][2] * u
        y -= bh
        op(ops, rect(bx, y, bwid, bh), keys[i])
        bands += rect(bx + 0.9 * u, y + bh * 0.18, 0.22 * u, bh * 0.64) + rect(bx + bwid - 1.2 * u, y + bh * 0.18, 0.22 * u, bh * 0.64)
    }
    op(ops, bands, "band")
    cactus(ops, cx + 0.4 * u, y, u * 0.75)
    return ops
}

// cat seen from behind, sitting, looking out. Local units: C = height, origin = base centre.
var CAT_BODY = [["M", -0.31, 0], ["C", -0.37, -0.05, -0.37, -0.17, -0.33, -0.26], ["C", -0.29, -0.36, -0.24, -0.45, -0.2, -0.53],
                ["C", -0.17, -0.59, -0.15, -0.63, -0.13, -0.66], ["L", 0.13, -0.66], ["C", 0.15, -0.63, 0.17, -0.59, 0.2, -0.53],
                ["C", 0.24, -0.45, 0.29, -0.36, 0.33, -0.26], ["C", 0.37, -0.17, 0.37, -0.05, 0.31, 0], ["Z"]]
var CAT_HEAD = [["M", -0.17, -0.64], ["C", -0.25, -0.67, -0.27, -0.75, -0.24, -0.81], ["C", -0.2, -0.89, -0.1, -0.91, 0, -0.91],
                ["C", 0.1, -0.91, 0.2, -0.89, 0.24, -0.81], ["C", 0.27, -0.75, 0.25, -0.67, 0.17, -0.64],
                ["C", 0.09, -0.61, -0.09, -0.61, -0.17, -0.64], ["Z"]]
var CAT_EAR_L = [["M", -0.235, -0.78], ["L", -0.215, -0.985], ["Q", -0.205, -1.005, -0.19, -0.995], ["L", -0.06, -0.9], ["Z"]]
var CAT_EAR_R = [["M", 0.06, -0.9], ["L", 0.19, -0.995], ["Q", 0.205, -1.005, 0.215, -0.985], ["L", 0.235, -0.78], ["Z"]]

function cat(L) {
    var u = L.u, C = 15 * u, b = L.baseY
    var pane = L.panes[2 * Math.floor(L.n / 2) + 1]          // lower pane at / right of the centre
    var cx = L.n === 1 ? L.win.x + L.win.w * 0.72 : pane.x + pane.w * 0.5
    var tf = T(cx, b, C, 0)
    // rim light: the part scaled up about an anchor near its base, drawn behind the fur
    function about(ax, ay, k) { return function (x, y) { return tf(ax + (x - ax) * k, ay + (y - ay) * k) } }
    var fe = (L.frontY - b) / C                      // sill front edge in cat units
    function pp(x, y) { var p = tf(x, y); return P(p[0], p[1]) }
    var o = { C: C, cx: cx, b: b }
    o.body = pathT(CAT_BODY, tf)
    o.head = pathT(CAT_HEAD, tf)
    o.earL = pathT(CAT_EAR_L, tf)
    o.earR = pathT(CAT_EAR_R, tf)
    o.bodyRim = pathT(CAT_BODY, about(0, -0.02, 1.03))
    o.headRim = pathT(CAT_HEAD, about(0, -0.66, 1.07))
    o.earLRim = pathT(CAT_EAR_L, about(-0.15, -0.84, 1.1))
    o.earRRim = pathT(CAT_EAR_R, about(0.15, -0.84, 1.1))
    o.headPivot = tf(0, -0.65)
    o.earLPivot = tf(-0.15, -0.84)
    o.earRPivot = tf(0.15, -0.84)
    // tail: from the base of the spine (towards us) along the sill, then over its front edge
    o.tailLie = "M" + pp(0.02, -0.08) + " Q" + pp(0.3, -0.03) + " " + pp(0.42, fe) + " "
    o.tailPivot = tf(0.42, fe)
    o.tailHang = "M" + pp(0.42, fe) + " C" + pp(0.45, fe + 0.12) + " " + pp(0.39, fe + 0.24) + " " + pp(0.45, fe + 0.37) + " "
    o.tailW = 0.08 * C
    o.shadow = ellipse(cx + 0.03 * C, b + 0.01 * C, 0.4 * C, 0.035 * C)
    return o
}

var FLAME = [["M", 0, 0], ["C", -0.42, -0.02, -0.38, -0.45, 0, -1], ["C", 0.38, -0.45, 0.42, -0.02, 0, 0], ["Z"]]

// jar candle at the right end of the sill; QML flickers the flame about (cx, flameY)
function candle(L) {
    var u = L.u, b = L.baseY, cx = L.win.x + L.win.w * 0.9
    var w = 3.6 * u, h = 4.4 * u, x0 = cx - w / 2, top = b - h, rr = 0.7 * u, wax = top + 1.4 * u
    return {
        cx: cx, flameY: wax - 0.15 * u, glowR: 12 * u,
        shadow: ellipse(cx + 0.3 * u, b + 0.15 * u, w * 0.75, 0.45 * u),
        jar: "M" + P(x0, top) + " L" + P(x0 + w, top) + " L" + P(x0 + w, b - rr) + " Q" + P(x0 + w, b) + " " + P(x0 + w - rr, b)
           + " L" + P(x0 + rr, b) + " Q" + P(x0, b) + " " + P(x0, b - rr) + " Z ",
        wax: rect(x0 + 0.35 * u, wax, w - 0.7 * u, b - wax - 0.35 * u),
        waxTop: ellipse(cx, wax, w / 2 - 0.35 * u, 0.3 * u),
        lip: ellipse(cx, top, w / 2, 0.32 * u),
        wick: rect(cx - 0.06 * u, wax - 0.45 * u, 0.12 * u, 0.45 * u),
        flame: pathT(FLAME, T(cx, wax - 0.15 * u, 1.5 * u, 0)),
        core: pathT(FLAME, T(cx, wax - 0.15 * u, 0.7 * u, 0))
    }
}

// ---- curtains ------------------------------------------------------------

// fold strips from the outer edge inwards: 0 base, 1 shade (valley), 2 light (ridge)
var FOLD_TONES = [1, 0, 2, 0, 1, 0, 2, 0, 1, 0, 2]
var FOLD_WEIGHT = [1.25, 1.0, 0.6]
var CURTAIN_KEYS = ["curtain", "curtainShade", "curtainLight"]
var TASSEL = [["M", -0.35, 1.3], ["L", 0.35, 1.3], ["L", 0.85, 5.0], ["Q", 0, 5.7, -0.85, 5.0], ["Z"]]

// Curtains tied back on both sides of the window, hanging from a rod on rings. Each is a fan of
// fold strips between its outer edge and its curved inner edge: the folds pinch together at the
// tie-back and flare out below it, down behind the desk.
function curtains(L) {
    var D = L.D, w = L.win, r = rng(77), ops = []
    var reach = L.cw, over = Math.min(w.w * 0.07, D * 0.06)
    var top = L.rodY + D * 0.004, bottom = L.deskY + D * 0.02, tieY = w.y + w.h * 0.62
    var wTop = reach + L.casing + over, wTie = reach * 0.42, wBot = reach * 0.95, pinch = reach * 0.07
    var K = 64, N = FOLD_TONES.length
    // inner edge as d(y), d measured from the outer edge towards the window
    var inner = []
    function sample(a, b, c, d) { for (var i = 0; i <= 60; i++) inner.push(bez(a, b, c, d, i / 60)) }
    sample([wTop, top], [wTop, top + 0.5 * (tieY - top)], [wTie + 0.4 * (wTop - wTie), tieY - 0.06 * (tieY - top)], [wTie, tieY])
    sample([wTie, tieY], [wTie + 0.12 * reach, tieY + 0.25 * (bottom - tieY)], [wBot, tieY + 0.45 * (bottom - tieY)], [wBot, bottom])
    function dIn(y) {
        for (var i = 1; i < inner.length; i++) {
            var a = inner[i - 1], b = inner[i]
            if (b[1] >= y) return b[1] > a[1] ? a[0] + (b[0] - a[0]) * (y - a[1]) / (b[1] - a[1]) : b[0]
        }
        return inner[inner.length - 1][0]
    }
    function dOut(y) {
        if (y <= tieY) { var s = (y - top) / (tieY - top); return pinch * s * s }
        var v = (y - tieY) / (bottom - tieY)
        return pinch * (1 - v) * (1 - v) - reach * 0.05 * v
    }
    var rows = []
    for (var k = 0; k <= K; k++) {
        var y = top + (bottom - top) * k / K
        rows.push([y, dOut(y), dIn(y)])
    }
    var strips = ["", "", ""], shadow = "", tie = "", tassel = "", rings = ""
    for (var side = -1; side <= 1; side += 2) {
        var edge = side < 0 ? w.x - L.casing - reach : w.x + w.w + L.casing + reach
        var X = function (d) { return edge - side * d }
        // fold lines across the width, 0 outer .. 1 inner, a little uneven
        var ts = [0], acc = 0
        for (var i = 0; i < N; i++) { acc += FOLD_WEIGHT[FOLD_TONES[i]] * (0.75 + 0.5 * r()); ts.push(acc) }
        for (var j = 0; j <= N; j++) ts[j] /= acc
        for (var f = 0; f < N; f++) {
            var pts = []
            for (var k1 = 0; k1 <= K; k1++) pts.push([X(rows[k1][1] + ts[f] * (rows[k1][2] - rows[k1][1])), rows[k1][0]])
            for (var k2 = K; k2 >= 0; k2--) pts.push([X(rows[k2][1] + ts[f + 1] * (rows[k2][2] - rows[k2][1])), rows[k2][0]])
            strips[FOLD_TONES[f]] += poly(pts)
        }
        // shadow on the wall, cast away from the window
        var sh = [], dx = side * D * 0.012, dy = D * 0.008
        for (var k3 = 0; k3 <= K; k3++) sh.push([X(rows[k3][1]) + dx, rows[k3][0] + dy])
        for (var k4 = K; k4 >= 0; k4--) sh.push([X(rows[k4][2]) + dx, rows[k4][0] + dy])
        shadow += poly(sh)
        // tie-back band with a tassel at its outer end
        var a0 = X(dOut(tieY) - D * 0.006), a1 = X(dIn(tieY) + D * 0.006), th = D * 0.016
        tie += capsule(Math.min(a0, a1), tieY - th / 2, Math.abs(a1 - a0), th)
        var tx = X(dOut(tieY) + D * 0.01)
        tassel += circle(tx, tieY + D * 0.009, D * 0.0065) + pathT(TASSEL, T(tx, tieY, D * 0.01, 0))
        for (var j2 = 0; j2 <= N; j2 += 2) rings += circle(X(ts[j2] * wTop), L.rodY + D * 0.002, D * 0.007)
    }
    var x0 = w.x - L.casing - reach - D * 0.035, x1 = w.x + w.w + L.casing + reach + D * 0.035, rt = D * 0.008
    op(ops, shadow, "shadow", 0.22)
    for (var c = 0; c < 3; c++) op(ops, strips[c], CURTAIN_KEYS[c])
    op(ops, tie, "tie")
    op(ops, tassel, "tie")
    op(ops, capsule(x0, L.rodY - rt / 2, x1 - x0, rt), "rod")
    op(ops, rings, "rod", 1, Math.max(1, D * 0.002))
    op(ops, circle(x0, L.rodY, D * 0.013) + circle(x1, L.rodY, D * 0.013), "rod")
    return ops
}

// fairy lights draped along the curtain rod: over each curtain and between the mullions
function garland(L) {
    var D = L.D, w = L.win, y = L.rodY + D * 0.004
    var hooks = [w.x - L.casing - L.cw - D * 0.02, w.x - L.casing * 0.5]
    for (var i = 1; i < L.n; i++) hooks.push(L.glass.x + i * (L.colW + L.m) - L.m / 2)
    hooks.push(w.x + w.w + L.casing * 0.5, w.x + w.w + L.casing + L.cw + D * 0.02)
    var wire = "M" + P(hooks[0], y), bulbs = []
    for (var k = 0; k < hooks.length - 1; k++) {
        var x0 = hooks[k], x1 = hooks[k + 1], span = x1 - x0, sag = Math.min(D * 0.05, span * 0.09)
        var cx = (x0 + x1) / 2, cy = y + 2 * sag
        wire += " Q" + P(cx, cy) + " " + P(x1, y)
        var nb = Math.max(2, Math.round(span / (D * 0.055)))
        for (var j = 0; j < nb; j++) {
            var t = (j + 0.5) / nb, u = 1 - t
            bulbs.push({ x: u * u * x0 + 2 * u * t * cx + t * t * x1,
                         y: u * u * y + 2 * u * t * cy + t * t * y + D * 0.005,
                         c: (j + k) % 3, p: ((j * 7 + k * 3) % 11) / 11 })
        }
    }
    var ops = []
    op(ops, wire + " ", "wire", 1, Math.max(1, D * 0.0012))
    return { ops: ops, bulbs: bulbs, size: D * 0.0058 }
}

// ---- wall ----------------------------------------------------------------

var BOOK_KEYS = ["bookA", "bookB", "bookC", "bookD", "bookE", "bookF", "bookG"]

// two floating shelves on the left wall: books standing, leaning and stacked, a cookie jar, and a
// pothos trailing over the edge of the top shelf
function shelves(L) {
    var z = L.wallL, D = L.D, ops = []
    if (z.w < D * 0.15) return ops
    var r = rng(4711), sw = Math.min(z.w, D * 0.4), x0 = z.x + (z.w - sw) / 2, t = D * 0.013
    var books = ["", "", "", "", "", "", ""], bands = "", labels = "", boards = "", under = "", shade1 = "", shade2 = ""
    var jars = "", fill = "", lids = "", pots = "", potShade = "", rims = "", stems = "", leaf = ["", ""]
    var last = -1, prevH = 0
    function pick() { var c; do c = Math.floor(r() * 7); while (c === last); last = c; return c }
    function upright(x, y, bw, bh, ang) {
        var tf = T(x, y, 1, ang || 0)
        books[pick()] += pathT(rectSegs(0, -bh, bw, bh), tf)
        if (r() < 0.65) bands += pathT(rectSegs(0, -bh * 0.87, bw, bh * 0.045), tf) + pathT(rectSegs(0, -bh * 0.17, bw, bh * 0.04), tf)
        if (r() < 0.35) labels += pathT(rectSegs(bw * 0.22, -bh * 0.64, bw * 0.56, bh * 0.16), tf)
    }
    function vine(sx, sy, ex, ey, bend) {
        var A = [sx, sy], B = [sx + bend, sy - D * 0.012], C = [ex - bend * 0.8, sy + (ey - sy) * 0.55], E = [ex, ey]
        stems += cubicStr(A, B, C, E)
        var n = 8 + Math.floor(r() * 3), flip = 1
        for (var i = 0; i < n; i++) {
            var tt = 0.15 + 0.85 * (i + 0.5) / n, p = bez(A, B, C, E, tt)
            flip = -flip
            var ang = p[1] > sy + D * 0.01 ? Math.PI / 2 + flip * (0.4 + r() * 0.35) : bezAngle(A, B, C, E, tt) + flip
            leaf[i % 2] += pathT(HEART, T(p[0], p[1], D * (0.012 + 0.004 * r()) * (1.1 - 0.4 * tt), ang))
        }
    }
    var ys = [L.win.y + L.win.h * 0.36, L.win.y + L.win.h * 0.74]
    for (var s = 0; s < 2; s++) {
        var y = ys[s], x = x0 + D * 0.014, end = x0 + sw - D * 0.014
        boards += rect(x0, y, sw, t)
        under += rect(x0, y + t * 0.62, sw, t * 0.38)
        for (var b = 0; b < 2; b++) {                    // brackets
            var bx = x0 + sw * (b ? 0.84 : 0.16)
            under += "M" + P(bx - D * 0.003, y + t) + " L" + P(bx + D * 0.003, y + t) + " L" + P(bx + D * 0.003, y + t + D * 0.028) + " Z "
        }
        shade1 += rect(x0 + D * 0.002, y + t, sw - D * 0.004, D * 0.007)
        shade2 += rect(x0 + D * 0.006, y + t, sw - D * 0.012, D * 0.02)
        var plan = s === 0 ? ["books", "plant", "books"] : ["stack", "books", "jar"]
        for (var p = 0; p < plan.length; p++) {
            if (plan[p] === "books") {
                var n = 3 + Math.floor(r() * 4)
                prevH = 0
                for (var i = 0; i < n; i++) {
                    var bw = D * (0.014 + 0.011 * r()), bh = D * (0.06 + 0.035 * r())
                    if (x + bw > end) break
                    upright(x, y, bw, bh)
                    x += bw + D * 0.0012
                    prevH = bh
                }
                // the next one leans on the row, touching the top of the last book
                var a = 0.22 + 0.12 * r(), lw = D * (0.015 + 0.008 * r())
                var lh = Math.max(D * (0.065 + 0.02 * r()), prevH / Math.cos(a) * 1.05)
                var xb = x + prevH * Math.tan(a)
                if (prevH > 0 && r() < 0.6 && xb + lw * Math.cos(a) < end) {
                    upright(xb, y, lw, lh, -a)
                    x = xb + lw * Math.cos(a)
                }
                x += D * (0.012 + 0.01 * r())
            } else if (plan[p] === "stack") {
                var m = 2 + Math.floor(r() * 2), yy = y, maxL = 0
                for (var j = 0; j < m; j++) {
                    var bl = D * (0.05 + 0.02 * r()), bt = D * (0.011 + 0.006 * r()), off = D * 0.006 * (r() - 0.5)
                    if (x + bl + off > end) break
                    books[pick()] += rect(x + off, yy - bt, bl, bt)
                    bands += rect(x + off + bl * 0.1, yy - bt, bl * 0.035, bt)
                    yy -= bt
                    maxL = Math.max(maxL, bl + off)
                }
                x += maxL + D * 0.016
            } else if (plan[p] === "plant") {
                var pw = D * 0.02, pb = D * 0.015, ph = D * 0.032, cx = x + pw * 1.1
                if (cx + pw * 1.1 > end) continue
                var pt = y - ph, rimY = pt - D * 0.007
                pots += "M" + P(cx - pw, pt) + " L" + P(cx + pw, pt) + " L" + P(cx + pb, y) + " L" + P(cx - pb, y) + " Z "
                potShade += "M" + P(cx + pw * 0.3, pt) + " L" + P(cx + pw, pt) + " L" + P(cx + pb, y) + " L" + P(cx + pb * 0.3, y) + " Z "
                rims += rect(cx - pw * 1.1, rimY, pw * 2.2, D * 0.008)
                vine(cx - pw * 0.8, rimY, cx - pw * 1.8, y + D * 0.14, -D * 0.024)
                vine(cx + pw * 0.2, rimY, cx + pw * 0.4, y + D * 0.19, D * 0.016)
                vine(cx + pw * 0.9, rimY, cx + pw * 2.4, y + D * 0.1, D * 0.026)
                for (var l = 0; l < 5; l++) {                    // a tuft on top
                    var la = -Math.PI / 2 + (l - 2) * 0.55 + (r() - 0.5) * 0.2
                    leaf[l % 2] += pathT(HEART, T(cx + (l - 2) * pw * 0.3, rimY, D * (0.014 + 0.004 * r()), la))
                }
                x = cx + pw * 1.1 + D * 0.014
            } else {                                             // cookie jar
                var jw = D * 0.026, jh = D * 0.038
                if (x + jw > end) continue
                jars += rrect(x, y - jh, jw, jh, jw * 0.22)
                fill += rrect(x + jw * 0.12, y - jh * 0.62, jw * 0.76, jh * 0.55, jw * 0.14)
                lids += rrect(x - jw * 0.05, y - jh - D * 0.008, jw * 1.1, D * 0.009, D * 0.002)
                x += jw + D * 0.012
            }
        }
    }
    op(ops, shade2, "shadow", 0.1)
    op(ops, shade1, "shadow", 0.16)
    op(ops, boards, "wood")
    op(ops, under, "woodDark")
    for (var c = 0; c < 7; c++) op(ops, books[c], BOOK_KEYS[c])
    op(ops, bands, "band", 0.55)
    op(ops, labels, "label", 0.85)
    op(ops, fill, "jarFill")
    op(ops, jars, "glint", 0.3)
    op(ops, lids, "woodDark")
    op(ops, pots, "pot")
    op(ops, potShade, "shadow", 0.25)
    op(ops, rims, "potRim")
    op(ops, stems, "stem", 1, Math.max(1, D * 0.0018))
    op(ops, leaf[0], "leafA")
    op(ops, leaf[1], "leafB")
    return ops
}

// wall clock on the right wall; QML turns the hands. show is false when there is no room.
function clock(L) {
    var z = L.wallR, D = L.D, ops = []
    if (z.w < D * 0.15) return { show: false, cx: 0, cy: 0, r: 1, ops: ops }
    var R = Math.min(D * 0.052, z.w * 0.32), cx = z.x + z.w / 2, cy = L.win.y + L.win.h * 0.2
    op(ops, circle(cx + D * 0.004, cy + D * 0.006, R), "shadow", 0.22)
    op(ops, circle(cx, cy, R), "clockRim")
    op(ops, circle(cx, cy, R * 0.86), "clockFace")
    var ticks = ""
    for (var i = 0; i < 12; i++) {
        var a = i * Math.PI / 6, l = R * (i % 3 ? 0.08 : 0.15), tw = R * (i % 3 ? 0.025 : 0.05)
        ticks += pathT(rectSegs(-tw / 2, 0, tw, l), T(cx + Math.sin(a) * R * 0.76, cy - Math.cos(a) * R * 0.76, 1, a))
    }
    op(ops, ticks, "clockTick")
    return { show: true, cx: cx, cy: cy, r: R, ops: ops }
}

// polaroids clipped to a string on the right wall, under the clock
function photos(L) {
    var z = L.wallR, D = L.D, ops = [], bulbs = []
    if (z.w < D * 0.15) return { ops: ops, bulbs: bulbs, size: 1 }
    var r = rng(2468), sw = Math.min(z.w, D * 0.36), x0 = z.x + (z.w - sw) / 2, x1 = x0 + sw, mx = (x0 + x1) / 2
    var y = L.win.y + L.win.h * 0.5, sag = D * 0.025
    var n = clamp(Math.floor(sw / (D * 0.085)), 1, 4), pw = D * 0.058, ph = pw * 1.2, ins = pw * 0.08, s = pw - 2 * ins
    var acc = {}
    function add(k, d) { acc[k] = (acc[k] || "") + d }
    for (var i = 0; i < n; i++) {
        var t = (i + 0.5) / n, v = 1 - t
        var px = v * v * x0 + 2 * v * t * mx + t * t * x1, py = v * v * y + 2 * v * t * (y + 2 * sag) + t * t * y
        var tf = T(px, py, 1, (r() - 0.5) * 0.28)
        var X0 = -pw / 2 + ins, Y0 = D * 0.003 + ins                       // photo square, s x s
        add("pshadow", pathT(rectSegs(-pw / 2 + D * 0.003, D * 0.007, pw, ph), tf))
        add("polaroid", pathT(rectSegs(-pw / 2, D * 0.003, pw, ph), tf))
        var kind = i % 3
        if (kind === 0) {                                                 // sunset over the sea
            add("photoSky0", pathT(rectSegs(X0, Y0, s, s), tf))
            add("photoSun", pathT(ellipseSegs(X0 + s * 0.5, Y0 + s * 0.58, s * 0.17, s * 0.17), tf))
            add("photoSea", pathT(rectSegs(X0, Y0 + s * 0.62, s, s * 0.38), tf))
        } else if (kind === 1) {                                          // mountains
            add("photoSky1", pathT(rectSegs(X0, Y0, s, s), tf))
            add("photoHill", pathT([["M", X0, Y0 + s], ["L", X0, Y0 + s * 0.72], ["L", X0 + s * 0.32, Y0 + s * 0.36],
                                    ["L", X0 + s * 0.52, Y0 + s * 0.6], ["L", X0 + s * 0.72, Y0 + s * 0.42],
                                    ["L", X0 + s, Y0 + s * 0.7], ["L", X0 + s, Y0 + s], ["Z"]], tf))
        } else {                                                          // a tree on a hill
            add("photoSky2", pathT(rectSegs(X0, Y0, s, s), tf))
            add("photoGreen", pathT([["M", X0, Y0 + s * 0.74], ["Q", X0 + s * 0.5, Y0 + s * 0.5, X0 + s, Y0 + s * 0.72],
                                     ["L", X0 + s, Y0 + s], ["L", X0, Y0 + s], ["Z"]], tf))
            add("photoTree", pathT(rectSegs(X0 + s * 0.6, Y0 + s * 0.42, s * 0.05, s * 0.2), tf)
                           + pathT(ellipseSegs(X0 + s * 0.625, Y0 + s * 0.38, s * 0.14, s * 0.13), tf))
        }
        add("clip", pathT(rectSegs(-D * 0.0035, -D * 0.006, D * 0.007, D * 0.016), tf))
    }
    for (var b = 0; b <= n; b++) {                      // between and beside the photos
        var tb = clamp(b / n, 0.03, 0.97), vb = 1 - tb
        bulbs.push({ x: vb * vb * x0 + 2 * vb * tb * mx + tb * tb * x1, y: vb * vb * y + 2 * vb * tb * (y + 2 * sag) + tb * tb * y + D * 0.004,
                     c: b % 3, p: ((b * 5) % 7) / 7 })
    }
    op(ops, "M" + P(x0, y) + " Q" + P(mx, y + 2 * sag) + " " + P(x1, y) + " ", "twine", 1, Math.max(1, D * 0.0015))
    op(ops, circle(x0, y, D * 0.0035) + circle(x1, y, D * 0.0035), "clockHand")
    op(ops, acc.pshadow, "shadow", 0.2)
    var order = ["polaroid", "photoSky0", "photoSun", "photoSea", "photoSky1", "photoHill", "photoSky2", "photoGreen", "photoTree", "clip"]
    for (var k = 0; k < order.length; k++) op(ops, acc[order[k]], order[k])
    return { ops: ops, bulbs: bulbs, size: D * 0.0045 }
}

// a column radiator on the wall under the window, its feet behind the desk
function radiator(L) {
    var D = L.D, w = L.win, ops = []
    var rw = Math.min(w.w * 0.46, D * 0.6), x0 = w.x + (w.w - rw) / 2
    var top = L.frontY + L.sill.front + D * 0.035, bot = L.deskY + D * 0.01
    var n = Math.max(6, Math.round(rw / (D * 0.026))), cw = rw / n, cols = "", shade = "", hi = ""
    for (var i = 0; i < n; i++) {
        var cx = x0 + i * cw + cw * 0.1, w1 = cw * 0.8
        cols += rrect(cx, top, w1, bot - top, w1 * 0.45)
        shade += rect(cx + w1 * 0.62, top + w1 * 0.4, w1 * 0.38, bot - top - w1 * 0.4)
        hi += rect(cx + w1 * 0.15, top + w1 * 0.5, w1 * 0.14, bot - top - w1 * 0.5)
    }
    var vx = x0 - D * 0.014
    op(ops, rect(x0 + D * 0.008, top + D * 0.01, rw, bot - top), "shadow", 0.16)
    op(ops, rect(x0, top + D * 0.014, rw, D * 0.01) + rect(x0, bot - D * 0.03, rw, D * 0.01), "radiatorShade")
    op(ops, rect(vx - D * 0.004, top + D * 0.03, D * 0.008, bot - top), "radiatorShade")
    op(ops, cols, "radiator")
    op(ops, shade, "radiatorShade")
    op(ops, hi, "glint", 0.3)
    op(ops, circle(vx, top + D * 0.03, D * 0.009), "valve")
    return ops
}

// macrame planter hanging in the window from a hook under the top frame; QML sways it about (hx, hy)
function hanger(L) {
    var D = L.D, w = L.win, r = rng(909), ops = []
    var hx = w.x + w.w * (L.n === 1 ? 0.22 : 0.16), hy = L.glass.y - L.f * 0.2
    var ky = hy + D * 0.035, py = hy + D * 0.15, pw = D * 0.034, ph = D * 0.04
    var cords = "M" + P(hx, hy) + " L" + P(hx, ky)
              + " M" + P(hx, ky) + " L" + P(hx - pw * 0.92, py) + " M" + P(hx, ky) + " L" + P(hx + pw * 0.92, py)
              + " M" + P(hx - pw * 0.92, py) + " L" + P(hx + pw * 0.12, py + ph * 0.8)
              + " M" + P(hx + pw * 0.92, py) + " L" + P(hx - pw * 0.12, py + ph * 0.8)
              + " M" + P(hx, py + ph * 0.72) + " L" + P(hx, py + ph * 1.2) + " "
    for (var i = -2; i <= 2; i++)
        cords += "M" + P(hx, py + ph * 1.2) + " L" + P(hx + i * D * 0.003, py + ph * 1.2 + D * (0.03 - Math.abs(i) * 0.004)) + " "
    var pot = "M" + P(hx - pw, py) + " L" + P(hx + pw, py) + " C" + P(hx + pw, py + ph * 0.9) + " " + P(hx + pw * 0.45, py + ph) + " " + P(hx, py + ph)
            + " C" + P(hx - pw * 0.45, py + ph) + " " + P(hx - pw, py + ph * 0.9) + " " + P(hx - pw, py) + " Z "
    var stems = "", leaf = ["", ""]
    var vines = [[-0.85, 0.2, -1], [-0.35, 0.28, -1], [0.3, 0.24, 1], [0.8, 0.16, 1]]
    for (var v = 0; v < vines.length; v++) {
        var sx = hx + vines[v][0] * pw, len = D * vines[v][1], dir = vines[v][2]
        var A = [sx, py], B = [sx + dir * D * 0.02, py + D * 0.005], C = [sx + dir * D * 0.012, py + len * 0.5], E = [sx + dir * D * 0.006, py + len]
        stems += cubicStr(A, B, C, E)
        var n = 6 + Math.floor(r() * 3), flip = 1
        for (var j = 0; j < n; j++) {
            var t = 0.12 + 0.88 * (j + 0.5) / n, p = bez(A, B, C, E, t)
            flip = -flip
            leaf[(j + v) % 2] += pathT(HEART, T(p[0], p[1], D * (0.013 + 0.004 * r()) * (1.1 - 0.4 * t), Math.PI / 2 + flip * (0.45 + 0.35 * r())))
        }
    }
    for (var k = 0; k < 6; k++) {                        // tuft over the rim
        var a = -Math.PI / 2 + (k - 2.5) * 0.5 + (r() - 0.5) * 0.2
        leaf[k % 2] += pathT(HEART, T(hx + (k - 2.5) * pw * 0.3, py, D * (0.016 + 0.005 * r()), a))
    }
    op(ops, circle(hx, hy + D * 0.004, D * 0.0045), "rod", 1, Math.max(1, D * 0.0018))
    op(ops, stems, "stem", 1, Math.max(1, D * 0.0018))
    op(ops, leaf[0], "leafA")
    op(ops, leaf[1], "leafB")
    op(ops, pot, "hangPot")
    op(ops, cords, "cord", 1, Math.max(1, D * 0.0022))
    return { hx: hx, hy: hy, ops: ops }
}

// ---- desk ----------------------------------------------------------------

var LAMP_BASE = [["M", -4.6, 0], ["C", -4.6, -1.5, -2.8, -2.1, 0, -2.1], ["C", 2.8, -2.1, 4.6, -1.5, 4.6, 0], ["Z"]]
var SHADE = [["M", 0.3, -1.75], ["C", -1.7, -1.75, -1.7, 1.75, 0.3, 1.75], ["L", 6.2, 4.1], ["L", 6.2, -4.1], ["Z"]]
var SHADE_DARK = [["M", 0.3, 0.5], ["L", 0.3, 1.75], ["L", 6.2, 4.1], ["L", 6.2, 2.1], ["Z"]]
var SHADE_LIGHT = [["M", 0.5, -1.45], ["L", 6.0, -3.7], ["L", 6.0, -3.0], ["L", 0.5, -1.0], ["Z"]]

// The desk across the bottom and what stands on it: a lamp (left), a radio and a cactus (right),
// an open notebook with a pencil and a mug of coffee. The lamp's light is drawn in QML from
// mouth, bulb, cone and light; steam rises at steam, notes at notes, the radio light is led.
function desk(L) {
    var W = L.W, H = L.H, D = L.D, u = L.u, w = L.win, r = rng(1234)
    var y0 = L.deskY, y1 = L.deskFront, dep = y1 - y0
    var o = { surface: [], items: [] }, s = o.surface, it = o.items

    // ---- surface ----
    op(s, rect(0, y0 - D * 0.006, W, D * 0.006), "shadow", 0.25)           // contact shadow on the wall
    op(s, rect(0, y0, W, dep), "deskTop")
    var grain = ""
    for (var g = 0; g < 9; g++)
        grain += capsule(W * r() * 0.85, y0 + dep * (0.08 + 0.84 * r()), W * (0.12 + 0.35 * r()), Math.max(1, D * 0.0016))
    op(s, grain, "deskGrain", 0.7)
    op(s, rect(0, y0, W, dep * 0.12), "shadow", 0.14)                       // darker towards the wall
    op(s, rect(0, y0 + dep * 0.12, W, dep * 0.2), "shadow", 0.06)
    op(s, rect(0, y1, W, H - y1 + 1), "deskFront")
    op(s, rect(0, y1, W, Math.max(1.5, D * 0.004)), "deskEdge")

    // ---- lamp ----
    var bx = w.x + Math.max(w.w * 0.035, 4 * u), by = y0 + dep * 0.36, tf = T(bx, by, u, 0)
    function pp(x, y) { var p = tf(x, y); return P(p[0], p[1]) }
    var J0 = [0.3, -2.0], J1 = [-2.4, -14.8], J2 = [8.4, -18.6], th = 1.08
    var j0 = tf(J0[0], J0[1]), j1 = tf(J1[0], J1[1]), j2 = tf(J2[0], J2[1]), stf = T(j2[0], j2[1], u, th)
    op(it, ellipse(bx + 0.8 * u, by + 0.1 * u, 5.4 * u, 0.55 * u), "shadow", 0.35)
    op(it, "M" + pp(J0[0], J0[1]) + " L" + pp(J1[0], J1[1]) + " L" + pp(J2[0], J2[1]) + " ", "lampDark", 1, 0.62 * u)
    op(it, "M" + pp(J0[0] + 0.75, J0[1]) + " L" + pp(J1[0] + 0.65, J1[1] + 0.45) + " L" + pp(J2[0] - 0.25, J2[1] + 0.75) + " ", "lamp", 1, 0.3 * u)
    op(it, pathT(LAMP_BASE, tf), "lamp")
    op(it, pathT(rectSegs(-4.6, -0.45, 9.2, 0.45), tf), "lampDark")
    op(it, circle(j0[0], j0[1], 0.75 * u) + circle(j1[0], j1[1], 0.85 * u), "lamp")
    op(it, pathT(SHADE, stf), "lamp")
    op(it, pathT(SHADE_DARK, stf), "lampDark")
    op(it, pathT(SHADE_LIGHT, stf), "lampLight", 0.7)
    o.mouth = pathT(ellipseSegs(6.2, 0, 0.9, 4.1), stf)
    o.bulb = pathT(ellipseSegs(6.0, 0, 0.55, 2.4), stf)
    op(it, o.mouth, "lampInner")
    op(it, circle(j2[0], j2[1], 0.62 * u), "lampDark")
    var m = stf(6.2, 0), e1 = stf(6.6, -4.1), e2 = stf(6.6, 4.1)
    var py = y0 + dep * 0.6, px = m[0] + (py - m[1]) / Math.tan(th), rx = 15 * u
    o.light = { mx: m[0], my: m[1], px: px, py: py, rx: rx, ry: dep * 0.32, glow: D * 0.3 }
    o.cone = poly([e1, [px + rx * 0.8, py], [px - rx * 0.8, py], e2])

    // ---- radio, back right ----
    var rx0 = w.x + w.w * 0.78, ry0 = y0 + dep * 0.4, rtf = T(rx0, ry0, u, 0)
    function pr(x, y) { var p = rtf(x, y); return P(p[0], p[1]) }
    function R(x, y, ww, hh) { var p = rtf(x, y); return rect(p[0], p[1], ww * u, hh * u) }
    op(it, ellipse(rx0 + 0.6 * u, ry0 + 0.1 * u, 8.4 * u, 0.6 * u), "shadow", 0.35)
    op(it, "M" + pr(6, -8.4) + " L" + pr(10.6, -17.5) + " ", "antenna", 1, 0.26 * u)
    op(it, circle(rtf(10.6, -17.5)[0], rtf(10.6, -17.5)[1], 0.36 * u), "antenna")
    op(it, "M" + pr(-5, -8.6) + " L" + pr(-5, -10.2) + " Q" + pr(-5, -11) + " " + pr(-4.2, -11) + " L" + pr(4.2, -11)
         + " Q" + pr(5, -11) + " " + pr(5, -10.2) + " L" + pr(5, -8.6) + " ", "radioDark", 1, 0.55 * u)
    op(it, R(-6.2, -0.7, 1.4, 0.7) + R(4.8, -0.7, 1.4, 0.7), "radioDark")
    var rb = rtf(-7.5, -9)
    op(it, rrect(rb[0], rb[1], 15 * u, 8.4 * u, 1.5 * u), "radio")
    op(it, R(-7.3, -2.4, 14.6, 0.45), "radioDark")
    var gc = rtf(-3.5, -5.1), dots = ""
    op(it, circle(gc[0], gc[1], 2.9 * u), "grille")
    for (var gx = -2; gx <= 2; gx++)
        for (var gy = -2; gy <= 2; gy++)
            if (Math.hypot(gx, gy) <= 2.3) dots += circle(gc[0] + gx * 0.95 * u, gc[1] + gy * 0.95 * u, 0.24 * u)
    op(it, dots, "grilleDot")
    var dl = rtf(0.7, -7.7), ticks = ""
    op(it, rrect(dl[0], dl[1], 5.6 * u, 2.5 * u, 0.5 * u), "dial")
    for (var ti = 0; ti < 9; ti++) ticks += R(1.25 + ti * 0.57, ti % 2 ? -6.9 : -7.2, 0.12, ti % 2 ? 0.5 : 0.8)
    op(it, ticks, "dialTick")
    op(it, R(3.5, -7.5, 0.2, 2.1), "needle")
    var k1 = rtf(1.9, -3.9), k2 = rtf(5.0, -3.9)
    op(it, circle(k1[0], k1[1], 1.05 * u) + circle(k2[0], k2[1], 1.05 * u), "knob")
    op(it, R(1.8, -4.8, 0.2, 0.7) + R(4.9, -4.8, 0.2, 0.7), "dial")
    var ld = rtf(3.45, -3.9)
    o.led = { x: ld[0], y: ld[1], r: 0.36 * u }
    o.notes = { x: gc[0], y: gc[1] - 3.6 * u }
    if (rx0 + 14 * u < W) cactus(it, rx0 + 11.5 * u, y0 + dep * 0.55, u * 1.1)

    // ---- notebook and pencil, under the lamp ----
    var nx = px + 1.5 * u, ny = y0 + dep * 0.6, hb = 9.5 * u, hf = 10.5 * u, yb = ny - 2.6 * u, yf = ny + 2.6 * u
    op(it, ellipse(nx + u, yf + 0.6 * u, hf * 1.05, 0.9 * u), "shadow", 0.25)
    op(it, poly([[nx - hb - 0.5 * u, yb - 0.25 * u], [nx + hb + 0.5 * u, yb - 0.25 * u], [nx + hf + 0.7 * u, yf + 0.7 * u], [nx - hf - 0.7 * u, yf + 0.7 * u]]), "cover")
    op(it, rect(nx - hf, yf - 0.05 * u, 2 * hf, 0.4 * u), "paperShade")
    op(it, "M" + P(nx - hb, yb) + " Q" + P(nx - hb * 0.5, yb - 0.55 * u) + " " + P(nx, yb + 0.3 * u) + " L" + P(nx, yf + 0.25 * u)
         + " Q" + P(nx - hf * 0.5, yf - 0.3 * u) + " " + P(nx - hf, yf) + " Z "
         + "M" + P(nx, yb + 0.3 * u) + " Q" + P(nx + hb * 0.5, yb - 0.55 * u) + " " + P(nx + hb, yb) + " L" + P(nx + hf, yf)
         + " Q" + P(nx + hf * 0.5, yf - 0.3 * u) + " " + P(nx, yf + 0.25 * u) + " Z ", "paper")
    op(it, rect(nx - 0.12 * u, yb + 0.3 * u, 0.24 * u, yf - yb - 0.1 * u), "paperShade", 0.8)
    var ink = ""
    for (var row = 1; row <= 6; row++) {                 // handwriting: rows of dashes
        var tt = row / 7.2, yy = yb + (yf - yb) * tt + 0.1 * u, half = hb + (hf - hb) * tt
        for (var sd = -1; sd <= 1; sd += 2) {
            if (sd > 0 && row > 4) continue               // the right page is half written
            var xx = nx + sd * u, xe = nx + sd * half * 0.86
            while (sd < 0 ? xx > xe : xx < xe) {
                var len = Math.min(u * (0.8 + 2.2 * r()), Math.abs(xe - xx))
                ink += rect(sd < 0 ? xx - len : xx, yy, len, Math.max(1, 0.16 * u))
                xx += sd * (len + 0.5 * u)
            }
        }
    }
    op(it, ink, "ink", 0.55)
    op(it, poly([[nx + 0.2 * u, yf + 0.2 * u], [nx + 0.75 * u, yf + 0.2 * u], [nx + 1.1 * u, yf + 2.4 * u], [nx + 0.45 * u, yf + 2.1 * u]]), "ribbon")
    var ptf = T(nx + hb * 0.55, ny + 0.4 * u, u, -0.32)
    op(it, pathT(rectSegs(-4.6, 0.1, 9.1, 0.6), ptf), "shadow", 0.18)
    op(it, pathT([["M", -3.6, -0.3], ["L", -3.6, 0.3], ["L", -4.9, 0], ["Z"]], ptf), "pencilWood")
    op(it, pathT([["M", -4.45, -0.1], ["L", -4.45, 0.1], ["L", -4.9, 0], ["Z"]], ptf), "ink")
    op(it, pathT(rectSegs(-3.6, -0.3, 6.6, 0.6), ptf), "pencil")
    op(it, pathT(rectSegs(3.0, -0.3, 0.6, 0.6), ptf), "ferrule")
    op(it, pathT(rectSegs(3.6, -0.3, 0.9, 0.6), ptf), "eraser")

    // ---- mug, right of the notebook ----
    var mx = nx + hf + 7 * u, mb = y0 + dep * 0.62, mw = 5 * u, mh = 5.4 * u, mt = mb - mh, rr = 0.9 * u
    var xa = mx - mw / 2, xz = mx + mw / 2
    op(it, ellipse(mx + 0.5 * u, mb + 0.1 * u, mw * 0.75, 0.55 * u), "shadow", 0.35)
    op(it, "M" + P(xz - 0.1 * u, mt + 0.9 * u) + " C" + P(xz + 1.8 * u, mt + 0.6 * u) + " " + P(xz + 1.9 * u, mt + 3.2 * u)
         + " " + P(xz - 0.1 * u, mb - 1.0 * u) + " ", "mug", 1, 0.5 * u)
    op(it, "M" + P(xa, mt) + " L" + P(xz, mt) + " L" + P(xz, mb - rr) + " Q" + P(xz, mb) + " " + P(xz - rr, mb)
         + " L" + P(xa + rr, mb) + " Q" + P(xa, mb) + " " + P(xa, mb - rr) + " Z ", "mug")
    op(it, rect(xa, mt + mh * 0.42, mw, mh * 0.16), "stripe")
    op(it, "M" + P(mx + mw * 0.18, mt) + " L" + P(xz, mt) + " L" + P(xz, mb - rr) + " Q" + P(xz, mb) + " " + P(xz - rr, mb)
         + " L" + P(mx + mw * 0.18, mb) + " Z ", "shadow", 0.2)
    op(it, ellipse(mx, mt, mw / 2, 0.45 * u), "mug")
    op(it, ellipse(mx, mt + 0.05 * u, mw / 2 - 0.3 * u, 0.3 * u), "coffee")
    o.steam = { x: mx, y: mt - 0.2 * u }

    // ---- headphones between the mug and the radio ----
    var hx = (mx + mw + rx0 - 8 * u) / 2
    if (hx - 6 * u > mx + mw && hx + 14 * u < rx0 - 8 * u) headphones(it, hx, y0 + dep * 0.55, u)

    // ---- a snake plant on the left end, a jar of fairy lights on books on the right end ----
    if (L.wallL.w > 0) snakePlant(it, L.wallL.x + L.wallL.w * 0.5, y0 + dep * 0.5, u)
    o.jar = { bulbs: [], size: 1, x: 0, y: 0, r: 0 }
    if (L.wallR.w > 0) o.jar = lightJar(it, L.wallR.x + L.wallR.w * 0.5, y0 + dep * 0.5, u)
    return o
}

// over-ear headphones lying on the desk, band up; (x, y) bottom centre
function headphones(ops, x, y, u) {
    var tf = T(x, y, u, 0)
    op(ops, ellipse(x + 0.5 * u, y + 0.15 * u, 6.4 * u, 0.6 * u), "shadow", 0.3)
    op(ops, pathT([["M", 5.2, -0.4], ["C", 7.5, 0.8, 8.0, -1.2, 9.5, -0.2], ["C", 11, 0.8, 11.5, -0.6, 13.5, 0.3]], tf), "phonesDark", 1, 0.24 * u)
    op(ops, pathT([["M", -4.3, -2.8], ["C", -4.7, -10.6, 4.7, -10.6, 4.3, -2.8]], tf), "phones", 1, 1.05 * u)
    op(ops, pathT([["M", -2.6, -8.1], ["C", -1.2, -9.1, 1.2, -9.1, 2.6, -8.1]], tf), "phonesDark", 1, 0.55 * u)
    op(ops, pathT(ellipseSegs(-4.4, -2.2, 1.75, 2.35), tf) + pathT(ellipseSegs(4.4, -2.2, 1.75, 2.35), tf), "phones")
    op(ops, pathT(ellipseSegs(-3.3, -2.2, 0.75, 2.05), tf) + pathT(ellipseSegs(3.3, -2.2, 0.75, 2.05), tf), "phonesDark")
}

// sansevieria: tall pointed leaves with yellow edges in a ceramic pot; (x, y) bottom centre
var SNAKE = [[-1.7, 15, 1.7, -0.16], [-0.6, 21, 2.0, -0.05], [0.6, 18, 1.9, 0.07], [1.6, 12.5, 1.6, 0.2],
             [-2.4, 10, 1.4, -0.34], [2.5, 9, 1.3, 0.36], [0.1, 13.5, 1.6, 0.0]]
function snakePlant(ops, x, y, u) {
    var pw = 3.3 * u, ph = 5.2 * u, edge = "", leaf = ["", ""]
    for (var i = 0; i < SNAKE.length; i++) {
        var g = SNAKE[i], tf = T(x + g[0] * u, y - ph * 0.85, u, g[3]), w = g[2], h = g[1]
        var shape = function (k) { return pathT([["M", -w * k / 2, 0], ["Q", -w * k * 0.62, -h * 0.55, 0, -h], ["Q", w * k * 0.62, -h * 0.55, w * k / 2, 0], ["Z"]], tf) }
        edge += shape(1.25)
        leaf[i % 2] += shape(0.95)
    }
    op(ops, ellipse(x + 0.6 * u, y + 0.15 * u, pw * 1.3, 0.6 * u), "shadow", 0.35)
    op(ops, edge, "snakeEdge")
    op(ops, leaf[0], "snake")
    op(ops, leaf[1], "snakeDark")
    op(ops, rrect(x - pw, y - ph, pw * 2, ph, 0.9 * u), "pot2")
    op(ops, rect(x - pw, y - ph * 0.62, pw * 2, 0.5 * u), "pot2Band")
}

// two books with a jar of fairy lights on top; returns the bulbs (QML makes them glow)
function lightJar(ops, x, y, u) {
    var r = rng(66), yb = y - 3.0 * u, jw = 5 * u, jh = 6.4 * u, bulbs = [], wire = ""
    op(ops, ellipse(x + 0.6 * u, y + 0.15 * u, 6.6 * u, 0.6 * u), "shadow", 0.35)
    op(ops, rect(x - 6 * u, y - 1.6 * u, 12 * u, 1.6 * u), "bookE")
    op(ops, rect(x - 5.2 * u, yb, 10.6 * u, 1.4 * u), "bookB")
    op(ops, rect(x - 5.2 * u, yb + 0.25 * u, 0.3 * u, 0.9 * u) + rect(x + 4.6 * u, y - 1.35 * u, 0.3 * u, 1.1 * u), "band", 0.7)
    for (var i = 0; i < 8; i++) {
        var bx = x + (r() - 0.5) * jw * 0.66, by = yb - jh * (0.12 + 0.72 * (i + r()) / 8)
        wire += (i ? " L" : "M") + P(bx, by)
        bulbs.push({ x: bx, y: by, c: i % 3, p: r() })
    }
    op(ops, rrect(x - jw / 2, yb - jh, jw, jh, 0.9 * u), "glint", 0.22)
    op(ops, wire + " ", "wire", 0.8, Math.max(1, 0.12 * u))
    op(ops, rrect(x - jw / 2 + 0.5 * u, yb - jh + 1.2 * u, 0.5 * u, jh - 2 * u, 0.25 * u), "glint", 0.35)
    op(ops, rrect(x - jw * 0.55, yb - jh - 0.9 * u, jw * 1.1, 1.1 * u, 0.3 * u), "woodDark")
    return { bulbs: bulbs, size: 0.32 * u, x: x, y: yb - jh * 0.5, r: 7 * u }
}
