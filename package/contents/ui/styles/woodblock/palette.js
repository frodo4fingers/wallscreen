.pragma library

// Woodblock style palettes: sky, hills, snow cap. No QML types.

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
