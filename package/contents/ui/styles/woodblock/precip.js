.pragma library

// Woodblock rain and snow as static geometry. Each depth layer is one sheet of shapes that
// Precipitation.qml slides down on the shared clock. A sheet is a little taller than the screen
// and k whole periods pass per 20 min clock cycle, so the wrap is seamless. Coordinates are
// screen pixels: x from the screen's left edge, y from the sheet top (0..period).

function clamp(x, a, b) { return Math.max(a, Math.min(b, x)) }

// mulberry32: deterministic, so the picture is the same on every rebuild
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

function poly(pts) {
    var s = "M" + P(pts[0][0], pts[0][1])
    for (var i = 1; i < pts.length; i++) s += " L" + P(pts[i][0], pts[i][1])
    return s + " Z "
}
function circle(cx, cy, r) {
    var a = q(r) + " " + q(r) + " 0 1 1 "
    return "M" + P(cx - r, cy) + " A" + a + P(cx + r, cy) + " A" + a + P(cx - r, cy) + " Z "
}

// Screen area against 1920x1080, clamped: the density scale of the old particle emitters.
function areaScale(w, h) { return clamp(w * h / (1920 * 1080), 0.5, 1.5) }

// One of three rain sheets: thin straight lines along (slant, 1), slant = dx/dy. At full rain the
// three sheets together hold about 212 lines per screen at 1080p (350 at most).
function rainSheet(w, h, i, slant) {
    var pad = 0.1 * h, period = h + 2 * pad, lw = Math.max(1, Math.min(w, h) * 0.0009)
    var total = Math.min(350, 212 * areaScale(w, h))
    var rho = total / (w * h) / 3                                  // per px2 for one sheet
    var drift = Math.abs(slant) * period
    var x0 = -pad - drift, x1 = w + pad + drift
    var count = Math.round(rho * (x1 - x0) * period)
    var r = rng(9001 + i * 131 + Math.round(slant * 100)), dl = Math.sqrt(slant * slant + 1)
    var dx = slant / dl, dy = 1 / dl, nx = -dy * lw / 2, ny = dx * lw / 2, d = ""
    for (var s = 0; s < count; s++) {
        var len = h * (0.08 + 0.06 * r())
        var cx = x0 + r() * (x1 - x0), cy = r() * period
        d += poly([[cx - dx * len / 2 + nx, cy - dy * len / 2 + ny], [cx + dx * len / 2 + nx, cy + dy * len / 2 + ny],
                   [cx + dx * len / 2 - nx, cy + dy * len / 2 - ny], [cx - dx * len / 2 - nx, cy - dy * len / 2 - ny]])
    }
    return { d: d, top: -pad, period: period, k: Math.max(1, Math.round(1200 * 1.3 * h / period)) }
}

// One of three snow sheets: cream dots. The flakes also sway sideways, m whole cycles per clock
// cycle, amp wide, phase ph. At full snow the sheets hold about 380 flakes per screen at 1080p.
function snowSheet(w, h, i, slant) {
    var px = Math.max(0.4, Math.min(w, h) / 1080), amp = 25 * px
    var pad = 0.05 * h, period = h + 2 * pad
    var total = Math.min(400, 380 * areaScale(w, h))
    var rho = total / (w * h) / 3
    var drift = Math.abs(slant) * period, padX = pad + amp
    var x0 = -padX - drift, x1 = w + padX + drift
    var count = Math.round(rho * (x1 - x0) * period)
    var r = rng(7001 + i * 97 + Math.round(slant * 100)), d = ""
    for (var s = 0; s < count; s++) {
        var rad = Math.min(w, h) * (0.004 + 0.007 * r()) / 2
        d += circle(x0 + r() * (x1 - x0), r() * period, rad)
    }
    return { d: d, top: -pad, period: period, k: Math.max(1, Math.round(1200 * 0.11 * h / period)),
             amp: amp, m: [173, 211, 151][i], ph: i * 0.37 }
}
