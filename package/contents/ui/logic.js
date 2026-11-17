.pragma library

// Pure scene logic: weather mapping, sun/moon arcs, palettes. No QML types.

var HORIZON_Y = 0.62
var DAY_MS = 864e5

function clamp(x, a, b) { return Math.max(a, Math.min(b, x)) }
function ok(d) { return !!d && !isNaN(+d) }
function smooth(a, b, x) { var t = clamp((x - a) / (b - a), 0, 1); return t * t * (3 - 2 * t) }

// colors are [r,g,b] arrays internally, "#rrggbb" at the API edge
function rgb(h) { var n = parseInt(h.slice(1), 16); return [(n >> 16) & 255, (n >> 8) & 255, n & 255] }
function hex(c) {
    return "#" + c.map(function (v) {
        v = Math.round(clamp(v, 0, 255))
        return (v < 16 ? "0" : "") + v.toString(16)
    }).join("")
}
function mix(a, b, t) { return a.map(function (v, i) { return v + (b[i] - v) * t }) }

// ---- weather -------------------------------------------------------------

// WMO code: [clouds floor, rain, snow, fog, storm]
var WMO = {
    0: [0, 0, 0, 0, 0], 1: [0.15, 0, 0, 0, 0], 2: [0.5, 0, 0, 0, 0], 3: [0.85, 0, 0, 0, 0],
    45: [0.6, 0, 0, 0.8, 0], 48: [0.6, 0, 0, 0.9, 0],
    51: [0.6, 0.2, 0, 0, 0], 53: [0.7, 0.3, 0, 0, 0], 55: [0.8, 0.4, 0, 0, 0],
    56: [0.7, 0.25, 0, 0, 0], 57: [0.8, 0.4, 0, 0, 0],
    61: [0.75, 0.35, 0, 0, 0], 63: [0.85, 0.6, 0, 0, 0], 65: [0.95, 0.9, 0, 0, 0],
    66: [0.8, 0.5, 0, 0, 0], 67: [0.95, 0.85, 0, 0, 0],
    71: [0.75, 0, 0.35, 0, 0], 73: [0.85, 0, 0.6, 0, 0], 75: [0.95, 0, 0.9, 0, 0],
    77: [0.7, 0, 0.4, 0, 0],
    80: [0.6, 0.45, 0, 0, 0], 81: [0.75, 0.7, 0, 0, 0], 82: [0.9, 1, 0, 0, 0],
    85: [0.7, 0, 0.5, 0, 0], 86: [0.9, 0, 0.9, 0, 0],
    95: [0.9, 0.7, 0, 0, 0.8], 96: [0.95, 0.8, 0, 0, 1], 99: [0.95, 0.9, 0, 0, 1]
}

function weatherState(code, cloudCover, precip, visibility) {
    var w = WMO[code] || WMO[0]
    var p = clamp((+precip || 0) / 4, 0, 1)   // ~4 mm/h is heavy
    var s = {
        clouds: clamp(Math.max(w[0], (+cloudCover || 0) / 100), 0, 1),
        rain: w[1] ? clamp(Math.max(w[1], p), 0, 1) : 0,
        snow: w[2] ? clamp(Math.max(w[2], p), 0, 1) : 0,
        fog: w[3],
        storm: w[4]
    }
    if (visibility > 0 && visibility < 2000)
        s.fog = Math.max(s.fog, 1 - visibility / 2000)
    return s
}

// PreviewWeather 1..6: Clear, Cloudy, Rain, Snow, Storm, Fog
function presetWeather(index) {
    switch (index) {
    case 1: return weatherState(0, 0, 0, 20000)
    case 2: return weatherState(3, 90, 0, 20000)
    case 3: return weatherState(63, 90, 2, 20000)
    case 4: return weatherState(73, 90, 2, 20000)
    case 5: return weatherState(96, 100, 6, 20000)
    case 6: return weatherState(45, 80, 0, 300)
    }
    return weatherState(0, 0, 0, 20000)
}

// ---- sun / moon ----------------------------------------------------------

// Day: elevation = sin(pi * fractionOfDay). Night: -sin(pi * fractionOfNight).
// Both are 0 at sunrise/sunset, so elevation is continuous everywhere.
function celestial(now, sunrise, sunset) {
    var t = ok(now) ? +now : Date.now()
    var sr = ok(sunrise) ? +sunrise : NaN
    var ss = ok(sunset) ? +sunset : NaN
    if (!(ss > sr && ss - sr < DAY_MS)) {
        var d = new Date(t)
        sr = d.setHours(6, 0, 0, 0)
        ss = d.setHours(18, 0, 0, 0)
    }
    var k = Math.floor((t - sr) / DAY_MS)   // shift by whole days so sr <= t < sr + 24h
    sr += k * DAY_MS
    ss += k * DAY_MS

    var day = t < ss
    var f = day ? (t - sr) / (ss - sr) : (t - ss) / (sr + DAY_MS - ss)
    var el = (day ? 1 : -1) * Math.sin(Math.PI * f)
    var sunF = day ? f : (f < 0.5 ? 1 : 0)   // after dusk the sun waits at the right edge, before dawn at the left
    var rise = HORIZON_Y - 0.12

    return {
        elevation: el,
        sunX: 0.04 + 0.92 * sunF,
        sunY: HORIZON_Y - rise * el,
        moonX: 0.04 + 0.92 * (day ? 0 : f),
        moonY: day ? HORIZON_Y : HORIZON_Y + rise * el,
        sunVisible: el > -0.1,
        moonVisible: !day,
        starOpacity: clamp((-el - 0.05) / 0.25, 0, 1)
    }
}

// ---- colors --------------------------------------------------------------

// [elevation, top, bottom, band, horizon, horizonAlpha]: woodblock sky.
// Night indigo, vermilion/sakura dawn glow, Prussian day fading to paper cream at the horizon.
var SKY = [
    [-1.0,  "#141a3c", "#1c2450", "#141a3c", "#2a2f66", 0],
    [-0.3,  "#141a3c", "#222a5c", "#141a3c", "#3a3470", 0.05],
    [-0.12, "#231f58", "#4a2f78", "#1a1d4a", "#8a3f7a", 0.5],
    [-0.04, "#3a2f7a", "#b04a80", "#1f3a80", "#e2462f", 0.85],
    [0.0,   "#4a4a9a", "#f08a8a", "#1f4e9c", "#e2462f", 0.9],
    [0.08,  "#3d6cc0", "#f4c4a0", "#1f4e9c", "#f08a8a", 0.65],
    [0.25,  "#3d7cc9", "#f3e7c4", "#1f4e9c", "#f6e9a8", 0.4],
    [1.0,   "#3d7cc9", "#f3e7c4", "#1f4e9c", "#f7ecb0", 0.35]
]

function skyColors(elevation, overcast) {
    var e = clamp(+elevation || 0, -1, 1), i = 1
    while (i < SKY.length - 1 && e > SKY[i][0]) i++
    var a = SKY[i - 1], b = SKY[i]
    var t = (e - a[0]) / (b[0] - a[0])
    var oc = clamp(+overcast || 0, 0, 1) * 0.7   // < 1 keeps some colour: rain scenes are grey-blue, not dead grey

    function col(n) {
        var c = mix(rgb(a[n]), rgb(b[n]), t)
        var L = 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]
        L += 20 * L / 255                     // slight lift keeps grey sky airy, not muddy
        return hex(mix(c, [L * 0.93, L * 0.99, L * 1.1], oc))
    }
    return {
        top: col(1), bottom: col(2), band: col(3), horizon: col(4),
        horizonAlpha: (a[5] + (b[5] - a[5]) * t) * (1 - 0.6 * oc)
    }
}

function sceneLight(elevation, overcast) {
    var base = 0.15 + 0.85 * smooth(-0.12, 0.25, +elevation || 0)
    return 0.15 + (base - 0.15) * (1 - 0.35 * clamp(+overcast || 0, 0, 1))
}

// 0 new, 0.5 full
function moonPhase(date) {
    if (!ok(date)) return 0
    var ref = Date.UTC(2000, 0, 6, 18, 14)
    var p = ((+date - ref) / (29.530588853 * DAY_MS)) % 1
    return p < 0 ? p + 1 : p
}

// Hill colors far to near: far is paler and bluer (atmospheric), near is richer.
var SEASONS = [
    ["#d6e4f5", "#e9eef8", "#f7f4ec", "#b4bde2"],   // winter, snow white with indigo shadows
    ["#e2d3dc", "#9fd6b4", "#6dbd8a", "#4fa36b"],   // spring, jade with a sakura hint far away
    ["#a9d3c8", "#5fb98a", "#3d9a63", "#2f8a4e"],   // summer, emerald
    ["#ecd6a8", "#d9a23b", "#d9722f", "#c8432b"]    // autumn, ochre to maple red
]

var INK = "#1d1a2e"

function dayOfYear(d, latitude) {
    var doy = (Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()) - Date.UTC(d.getFullYear(), 0, 0)) / DAY_MS
    return latitude < 0 ? doy + 182.6 : doy
}

function season(date, latitude) {
    var d = ok(date) ? new Date(+date) : new Date()
    var doy = dayOfYear(d, latitude)
    // season anchors sit at mid-season (winter = Jan 15), blended smoothly between
    var p = (((doy - 15) / 365.25 * 4) % 4 + 4) % 4
    var i = Math.floor(p)
    var t = smooth(0, 1, p - i)
    var a = SEASONS[i], b = SEASONS[(i + 1) % 4]
    return a.map(function (c, n) { return hex(mix(rgb(c), rgb(b[n]), t)) })
}

// Fraction of the volcano covered in snow: 0.55 around Feb 15 (doy 46), 0.15 around Aug 15.
function snowCap(date, latitude) {
    var d = ok(date) ? new Date(+date) : new Date()
    return 0.35 + 0.2 * Math.cos(2 * Math.PI * (dayOfYear(d, latitude) - 46) / 365.25)
}

// Meteorological direction = wind FROM; 270 (west) blows toward +x.
function windX(speedKmh, dirDeg) {
    var x = clamp((+speedKmh || 0) / 40, 0, 1) * -Math.sin((+dirDeg || 0) * Math.PI / 180)
    return x === 0 ? 0 : x   // avoid -0
}
