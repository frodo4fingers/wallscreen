.pragma library

// Pixel Loft: everything seen through the window, drawn pixel by pixel into a 2D canvas context.
// Only fillRect with whole-pixel coordinates is used, so the result stays crisp when the
// scene is scaled up with nearest-neighbour sampling. Pure JS, so tools can preview it
// outside QML with a stand-in context.
//
// Coordinates are local to the window glass (GW x GH). Colours come from the lofi palette
// (styles/lofi/palette.js), passed in as `pal`.

var GW = 320, GH = 178
var HORIZON = 140                 // local y where logic.js HORIZON_Y (0.62) lands

function rng(seed) {
    var s = seed | 0
    return function () {
        s = s + 0x6D2B79F5 | 0
        var t = Math.imul(s ^ s >>> 15, 1 | s)
        t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t
        return ((t ^ t >>> 14) >>> 0) / 4294967296
    }
}

function hash(a, b) {
    var h = Math.imul(a | 0, 0x9E3779B1) ^ Math.imul(b | 0, 0x85EBCA77)
    h = Math.imul(h ^ h >>> 15, 0x2C1B3C6D)
    return ((h ^ h >>> 13) >>> 0) / 4294967296
}

function rgb(h) { var n = parseInt(h.slice(1), 16); return [(n >> 16) & 255, (n >> 8) & 255, n & 255] }
function mix(a, b, t) {
    var x = rgb(a), y = rgb(b), s = "#"
    for (var i = 0; i < 3; i++) s += ("0" + Math.round(x[i] + (y[i] - x[i]) * t).toString(16)).slice(-2)
    return s
}

// ---- the city, built once --------------------------------------------------------------

var CITY = (function () {
    var r = rng(52), far = [], near = [], lights = [], x
    for (x = -2; x < GW + 2;) {
        var w = 5 + Math.floor(r() * 12), top = 78 + Math.floor(r() * 50)
        if (r() < 0.12) top -= 26 + Math.floor(r() * 16)                 // an occasional tower
        far.push([x, top, w, GH - top])
        if (r() < 0.2) far.push([x + (w >> 1), top - 6, 1, 6])            // antenna
        for (var fy = top + 3; fy < HORIZON + 10; fy += 3)
            for (var fx = x + 1; fx < x + w - 1; fx += 2)
                if (r() < 0.22) lights.push([fx, fy, 1, 0])
        x += w + (r() < 0.3 ? 1 : 0)
    }
    for (x = -4; x < GW + 4;) {
        var nw = 12 + Math.floor(r() * 20), ntop = 106 + Math.floor(r() * 36)
        near.push([x, ntop, nw, GH - ntop])
        if (r() < 0.35) near.push([x + 2, ntop - 3, nw - 4, 3])           // setback roof
        for (var ny = ntop + 3; ny < GH - 16; ny += 4)
            for (var nx = x + 2; nx < x + nw - 2; nx += 3)
                if (r() < 0.34) lights.push([nx, ny, 2, 1])
        x += nw
    }
    return { far: far, near: near, lights: lights }
})()

// the TV-style tower: shaft, a ball, an antenna, and its warning light on top
var SPIRE = { x: 236, ball: 62, top: 16 }

// cranes over a construction site in the near row: [mast x, mast top]
var CRANES = [[70, 96], [158, 100]]

var STARS = (function () {
    var r = rng(7), s = []
    for (var i = 0; i < 70; i++) s.push([Math.floor(r() * GW), Math.floor(r() * 110), r()])
    return s
})()

// clouds: blobs [dx, dy, radius]; a flat base at dy = 0
var CLOUD_SHAPES = [
    [[0, -3, 6], [8, -6, 8], [17, -4, 7], [25, -2, 5]],
    [[0, -2, 5], [7, -5, 6], [14, -3, 5]],
    [[0, -3, 7], [10, -8, 10], [22, -6, 9], [33, -3, 6], [40, -2, 4]],
    [[0, -2, 4], [6, -4, 5], [12, -2, 4]],
    [[0, -4, 8], [12, -7, 9], [24, -5, 7], [32, -2, 5]],
    [[0, -2, 5], [8, -4, 6], [16, -5, 7], [25, -3, 5]],
    [[0, -3, 6], [9, -6, 8], [19, -3, 6]]
]
// [shape, start x, base y, px per step (in tenths)]
var CLOUDS = [[2, 10, 38, 3], [0, 120, 26, 4], [4, 210, 50, 3], [1, 60, 64, 5],
              [5, 270, 18, 4], [3, 170, 74, 6], [6, 300, 44, 3]]

var DROPS = (function () {
    var r = rng(91), d = []
    for (var i = 0; i < 120; i++) d.push([r() * GW, r() * GH, 3 + r() * 2.5, 2 + Math.floor(r() * 3)])
    return d
})()
var FLAKES = (function () {
    var r = rng(33), f = []
    for (var i = 0; i < 150; i++) f.push([r() * GW, r() * GH, 0.2 + r() * 0.45, r() * 6.28, r() < 0.15 ? 2 : 1])
    return f
})()

// ---- primitives ---------------------------------------------------------------------------

function disc(ctx, cx, cy, radius, maxY) {
    for (var dy = -radius; dy <= radius; dy++) {
        if (maxY !== undefined && cy + dy > maxY) break
        var half = Math.floor(Math.sqrt(radius * radius - dy * dy) + 0.35)
        ctx.fillRect(cx - half, cy + dy, 2 * half + 1, 1)
    }
}

// ---- layers ---------------------------------------------------------------------------------

// Sky: flat bands from the palette's top, mid and low colours, with one checkerboard row
// between neighbours, then stars, sun and moon. `w` is the scene's world-like object.
function drawSky(ctx, pal, w) {
    var n = 12, bandH = Math.ceil(GH / n), i, x
    var cols = []
    for (i = 0; i < n; i++) {
        var t = i / (n - 1)
        cols.push(t < 0.5 ? mix(pal.top, pal.mid, t * 2) : mix(pal.mid, pal.low, (t - 0.5) * 2))
    }
    ctx.globalAlpha = 1
    for (i = 0; i < n; i++) {
        ctx.fillStyle = cols[i]
        ctx.fillRect(0, i * bandH, GW, bandH)
        if (i + 1 < n) {
            ctx.fillStyle = cols[i + 1]
            for (x = i & 1; x < GW; x += 2) ctx.fillRect(x, (i + 1) * bandH - 1, 1, 1)
        }
    }

    if (w.starOpacity > 0.01) {
        ctx.fillStyle = "#f3ecff"
        for (i = 0; i < STARS.length; i++) {
            var s = STARS[i]
            // a few stars dim and brighten in slow steps
            var dimmed = s[2] < 0.25 && hash(i, w.starStep) < 0.5
            ctx.globalAlpha = w.starOpacity * (dimmed ? 0.35 : 0.5 + 0.5 * s[2])
            ctx.fillRect(s[0], s[1], 1, 1)
        }
        ctx.globalAlpha = 1
    }

    if (w.sunVisible) {
        var sx = Math.round(w.sunX * GW), sy = Math.round(w.sunY / 0.62 * HORIZON)
        ctx.fillStyle = pal.halo
        ctx.globalAlpha = 0.35
        disc(ctx, sx, sy, 11)
        ctx.globalAlpha = 0.6
        disc(ctx, sx, sy, 8)
        ctx.globalAlpha = 1
        ctx.fillStyle = pal.sun
        disc(ctx, sx, sy, 6)
    }

    if (w.moonVisible) {
        var mx = Math.round(w.moonX * GW), my = Math.round(w.moonY / 0.62 * HORIZON), mr = 5
        var k = Math.cos(2 * Math.PI * w.moonPhase), waxing = w.moonPhase < 0.5
        ctx.fillStyle = "#f2ead2"
        for (var dy = -mr; dy <= mr; dy++) {
            var half = Math.sqrt(mr * mr - dy * dy) + 0.35
            var a = waxing ? half * k : -half, b = waxing ? half : -half * k
            var x0 = Math.round(mx + a), x1 = Math.round(mx + b)
            if (x1 > x0) ctx.fillRect(x0, my + dy, x1 - x0, 1)
        }
    }
}

// Clouds drift right one step at a time; `amount` (0..1) decides how many are out.
function drawClouds(ctx, pal, amount, step) {
    var count = Math.ceil(amount * CLOUDS.length - 0.05)
    for (var i = 0; i < count; i++) {
        var c = CLOUDS[i], shape = CLOUD_SHAPES[c[0]], span = GW + 70
        var x = Math.floor(((c[1] + step * c[3] / 10) % span + span) % span) - 50, y = c[2]
        for (var pass = 0; pass < 2; pass++) {
            ctx.fillStyle = pass ? pal.cloudTop : pal.cloudBottom
            for (var j = 0; j < shape.length; j++) {
                var b = shape[j]
                disc(ctx, x + b[0], y + b[1] + (pass ? -1 : 1), b[2], y + (pass ? -1 : 0))
            }
        }
    }
}

// The skyline: far row, haze, near row with cranes and the tower, lit windows, fog.
// `lit` (0..1) is how many windows are on; `slot` changes every few minutes and flips a few.
function drawCity(ctx, pal, lit, slot, fog) {
    var i, b
    ctx.globalAlpha = 1
    ctx.fillStyle = pal.far
    for (i = 0; i < CITY.far.length; i++) { b = CITY.far[i]; ctx.fillRect(b[0], b[1], b[2], b[3]) }
    // the tower stands in the far row
    ctx.fillRect(SPIRE.x, SPIRE.ball, 3, GH - SPIRE.ball)
    disc(ctx, SPIRE.x + 1, SPIRE.ball, 4)
    ctx.fillRect(SPIRE.x, SPIRE.ball - 8, 3, 4)
    ctx.fillRect(SPIRE.x + 1, SPIRE.top, 1, SPIRE.ball - 8 - SPIRE.top)

    ctx.fillStyle = pal.haze
    ctx.globalAlpha = 0.28
    ctx.fillRect(0, 96, GW, GH - 96)
    ctx.globalAlpha = 1

    ctx.fillStyle = pal.near
    for (i = 0; i < CITY.near.length; i++) { b = CITY.near[i]; ctx.fillRect(b[0], b[1], b[2], b[3]) }
    for (i = 0; i < CRANES.length; i++) {
        var cx = CRANES[i][0], ct = CRANES[i][1]
        ctx.fillRect(cx, ct, 1, GH - ct)
        ctx.fillRect(cx - 8, ct, 34, 1)
        ctx.fillRect(cx - 8, ct + 1, 3, 2)
    }

    if (lit > 0.01) {
        var cols = ["#ffc874", "#ffae5c", "#ffe7b4", "#a8d4ff"]
        for (i = 0; i < CITY.lights.length; i++) {
            var L = CITY.lights[i]
            var on = hash(i, 1) < 0.25 + 0.75 * lit
            if (hash(i, slot + 2) < 0.04) on = !on                       // a few switch over time
            if (!on) continue
            ctx.fillStyle = cols[Math.floor(hash(i, 3) * 4)]
            ctx.globalAlpha = Math.min(1, lit * 1.4) * (L[3] ? 1 : 0.7)
            ctx.fillRect(L[0], L[1], 1, L[2])
        }
        ctx.globalAlpha = 1
    }

    if (fog > 0.01) {
        ctx.fillStyle = pal.haze
        for (var y = 60; y < GH; y += 8) {
            ctx.globalAlpha = Math.min(0.85, fog * 0.75 * (y - 50) / (GH - 50))
            ctx.fillRect(0, y, GW, 8)
        }
        ctx.globalAlpha = 1
    }
}

// Rain streaks or snowflakes; `tick` advances them.
function drawPrecip(ctx, pal, rain, snow, wind, tick) {
    var i, n, span = GH + 8
    if (rain > 0.01) {
        n = Math.round(rain * DROPS.length)
        ctx.fillStyle = pal.rain
        ctx.globalAlpha = 0.75
        var slant = wind * 0.6
        for (i = 0; i < n; i++) {
            var d = DROPS[i]
            var y = Math.floor((d[1] + tick * d[2]) % span) - 4
            var x = Math.floor(((d[0] + y * slant) % GW + GW) % GW)
            for (var k = 0; k < d[3]; k++) ctx.fillRect(Math.round(x + k * slant), y + k, 1, 1)
        }
    }
    if (snow > 0.01) {
        n = Math.round(snow * FLAKES.length)
        ctx.fillStyle = pal.snow
        ctx.globalAlpha = 0.9
        for (i = 0; i < n; i++) {
            var f = FLAKES[i]
            var fy = Math.floor((f[1] + tick * f[2]) % span) - 4
            var fx = Math.floor(((f[0] + 2 * Math.sin(tick * 0.04 + f[3]) + wind * tick * 0.3) % GW + GW) % GW)
            ctx.fillRect(fx, fy, f[4], f[4])
        }
    }
    ctx.globalAlpha = 1
}

// ---- the cat on the window bench -------------------------------------------------------
// It sleeps most of the time. Once per CAT_CYCLE ticks (10 min at 12.5 Hz) it gets up, walks
// along the bench, sits and looks out for a while, walks on, turns, and comes back to sleep.
// Room coordinates: x is the left edge of a 30 px walk frame, frames stand on the cushion.

var CAT_CYCLE = 7500
var CAT_HOME = 178
// [kind, ticks, from x, to x, facing left]
var CAT_PLAN = [
    ["stand", 30, 178, 178, false],
    ["walk", 150, 178, 268, false],
    ["sit", 300, 268, 268, false],
    ["walk", 140, 268, 352, false],
    ["stand", 20, 352, 352, false],
    ["stand", 25, 352, 352, true],
    ["walk", 290, 352, 178, true],
    ["stand", 25, 178, 178, true]
]

// {sleep, x, frame (0-3 walk, 4 sit), left}
function catPose(tick) {
    var t = ((tick % CAT_CYCLE) + CAT_CYCLE) % CAT_CYCLE
    for (var i = 0; i < CAT_PLAN.length; i++) {
        var s = CAT_PLAN[i]
        if (t < s[1]) {
            var x = Math.round(s[2] + (s[3] - s[2]) * t / s[1])
            var frame = s[0] === "sit" ? 4 : s[0] === "walk" ? Math.floor(Math.abs(x - s[2]) / 3) % 4 : 0
            return { sleep: false, x: x, frame: frame, left: s[4] }
        }
        t -= s[1]
    }
    return { sleep: true, x: CAT_HOME, frame: 0, left: true }
}
