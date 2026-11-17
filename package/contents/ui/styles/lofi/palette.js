.pragma library

// Lofi Window palette. Pure JS returning "#rrggbb" strings (QML converts them), so the art
// can also be previewed outside QML. Everything is keyed by sun elevation (-1 .. 1).

function clamp(x, a, b) { return Math.max(a, Math.min(b, x)) }
function smooth(a, b, x) { var t = clamp((x - a) / (b - a), 0, 1); return t * t * (3 - 2 * t) }

function rgb(h) { var n = parseInt(h.slice(1), 16); return [(n >> 16) & 255, (n >> 8) & 255, n & 255] }
function mix(a, b, t) {
    var x = rgb(a), y = rgb(b), s = "#"
    for (var i = 0; i < 3; i++) s += ("0" + Math.round(x[i] + (y[i] - x[i]) * t).toString(16)).slice(-2)
    return s
}
function mixAll(a, b, t) { var o = {}; for (var k in a) o[k] = mix(a[k], typeof b === "string" ? b : b[k], t); return o }

// [[elevation, colours], ...] sorted by elevation; always returns a fresh object
function frames(list, e) {
    var i = 1
    while (i < list.length - 1 && e > list[i][0]) i++
    var a = list[i - 1], b = list[i]
    return mixAll(a[1], b[1], clamp((e - a[0]) / (b[0] - a[0]), 0, 1))
}

var LIT = ["#ffc874", "#ffae5c", "#ffe7b4", "#a8d4ff"]    // city windows
var BULBS = ["#ffd27a", "#ff9f6e", "#fff1cc"]             // fairy lights

// ---- outside ---------------------------------------------------------------

function S(top, mid, low, sun, halo, cloudTop, cloudBottom, far, near, farGlass, nearGlass, haze, rain, snow) {
    return { top: top, mid: mid, low: low, sun: sun, halo: halo, cloudTop: cloudTop, cloudBottom: cloudBottom,
             far: far, near: near, farGlass: farGlass, nearGlass: nearGlass, haze: haze, rain: rain, snow: snow }
}

var CLEAR = [
    [-0.3, S("#0e0f2b", "#1d1b45", "#3b2a5a", "#ff9a5a", "#ff8a50", "#1f1d40", "#3d2e58",
             "#262449", "#15142e", "#1e1c3e", "#100f26", "#34295a", "#7f86b0", "#8d8fb8")],
    [-0.1, S("#1a2257", "#3c3a7a", "#8e5584", "#ff8f5a", "#ff7a4a", "#33336a", "#7a4c78",
             "#3a3768", "#211f45", "#312f5c", "#1a1838", "#6a4c80", "#8f8fb8", "#b4b0d4")],
    [0.0,  S("#2f4180", "#8e6aa0", "#f59a6e", "#ffb27a", "#ff9860", "#a57fa8", "#f2a08a",
             "#5b4f80", "#2d2852", "#6e5f8e", "#3a3360", "#c98a95", "#c0a8c0", "#ecc9d2")],
    [0.1,  S("#4d7cbf", "#b6a2c6", "#f6c8a2", "#ffe0b0", "#ffd29a", "#fff0e4", "#d6a8b8",
             "#8d8db0", "#535277", "#a2a6c4", "#6a6a90", "#e6c2c0", "#d0d0e0", "#f6eef2")],
    [0.3,  S("#5f9fdb", "#a3cbec", "#eadfd6", "#fff7e6", "#fff0d2", "#ffffff", "#d3dbeb",
             "#a9b7d0", "#7686a6", "#c6d3e5", "#95a7c4", "#dde4ee", "#dfe6f0", "#f6f8ff")],
    [1.0,  S("#4f92d6", "#98c4ea", "#e2e3e0", "#fff9ec", "#fff0d2", "#ffffff", "#d3dbeb",
             "#a9b7d0", "#7686a6", "#c6d3e5", "#95a7c4", "#dde4ee", "#dfe6f0", "#f6f8ff")]
]

var GREY = [
    [-0.15, S("#17162a", "#201e34", "#3d3142", "#ffb27a", "#ff9a60", "#25233a", "#3a3044",
              "#29273f", "#18172a", "#222035", "#121122", "#352e40", "#6f7290", "#8a8ba6")],
    [0.0,   S("#3e3d5a", "#6b5f78", "#a98284", "#ffb27a", "#ff9a60", "#5f5670", "#8a6a78",
              "#4f4a66", "#2c2942", "#5a5470", "#34304a", "#8a7280", "#a49cb0", "#d6ccd8")],
    [0.2,   S("#8b96a8", "#a6aebb", "#c5c5c7", "#fbf6ec", "#efe9e0", "#c8ccd4", "#979dad",
              "#99a0b0", "#6c7385", "#a9b0bf", "#7d8596", "#c3c6cc", "#c9ced8", "#eef0f5")]
]

function sky(e, overcast) { return mixAll(frames(CLEAR, e), frames(GREY, e), smooth(0.2, 1, overcast) * 0.85) }

// city windows: off by day, on at dusk; dark overcast days switch a few on
function lights(e, overcast) { return Math.max(1 - smooth(-0.06, 0.12, e), clamp(overcast, 0, 1) * 0.3) }
// the reading lamp in the room
function lamp(e, overcast) { return Math.max(1 - smooth(-0.1, 0.22, e), clamp(overcast, 0, 1) * 0.35) }

var LEAVES = [["#8cc06e", "#a8d47e", "#6fa65c"],      // spring, with blossoms
              ["#4c8a58", "#67a465", "#3b7349"],      // summer
              ["#e8913c", "#d0592e", "#f2bb4c"],      // autumn
              ["#000000", "#000000", "#000000"]]      // winter: bare

function branch(season, e, overcast) {
    var k = clamp((1 - smooth(-0.15, 0.2, e)) * 0.8 + clamp(overcast, 0, 1) * 0.15, 0, 1), n = "#191730"
    var lv = LEAVES[season]
    return { wood: mix("#4a3a40", n, k), leaf: [mix(lv[0], n, k), mix(lv[1], n, k), mix(lv[2], n, k)],
             petal: mix("#f8cad8", n, k * 0.85), center: mix("#e5859f", n, k) }
}

// ---- room ------------------------------------------------------------------

function mul(a, b) {
    var x = rgb(a), y = rgb(b), s = "#"
    for (var i = 0; i < 3; i++) s += ("0" + Math.round(x[i] * y[i] / 255).toString(16)).slice(-2)
    return s
}
// one colour from [[elevation, "#rrggbb"], ...]
function track(list, e) {
    var i = 1
    while (i < list.length - 1 && e > list[i][0]) i++
    var a = list[i - 1], b = list[i]
    return mix(a[1], b[1], clamp((e - a[0]) / (b[0] - a[0]), 0, 1))
}

// Light falling on the room: white by day, warm at sunset, dim violet at night. Every room
// colour is its daytime colour multiplied by it, so the whole room shifts together.
var AMBIENT = [[-0.25, "#3a3456"], [-0.08, "#55456a"], [0.0, "#a8818f"], [0.08, "#ecc6b6"], [0.25, "#ffffff"]]
var AMBIENT_GREY = [[-0.25, "#35334a"], [0.0, "#6c6478"], [0.25, "#d2d0d8"]]
var LAMP_LIGHT = "#ffd9a8"

function ambient(e, overcast) { return mix(track(AMBIENT, e), track(AMBIENT_GREY, e), smooth(0.2, 1, overcast) * 0.85) }

// key: [daytime colour, lift, lamp]. lift keeps a key brighter at night (lit by the window,
// candle or fairy lights; 1 = unaffected); lamp warms it when the desk lamp is on.
var BASE = {
    wallTop: ["#b49a9e"], wall: ["#cdb3b0"],
    casing: ["#eee3d6", 0.1], frame: ["#f6efe5", 0.12], edge: ["#c9b8a6", 0.1],
    sillTop: ["#f1e6d8", 0.2], sillFront: ["#d6c4ae", 0.15], sillLip: ["#fbf6ee", 0.2], wire: ["#5a4a48", 0.2],
    curtain: ["#c9806a", 0.06], curtainShade: ["#a9634f", 0.06], curtainLight: ["#e1a184", 0.08],
    tie: ["#e8c27e", 0.15], rod: ["#4f3a33", 0.1],
    pot: ["#c9785b", 0.22], potRim: ["#d98b6b", 0.22], soil: ["#4a3426", 0.2],
    leafA: ["#5a9a68", 0.2], leafB: ["#82ba7c", 0.2], stem: ["#4a7a54", 0.2],
    cactus: ["#6fa070", 0.2, 0.3], cactusDark: ["#4f7f55", 0.2, 0.3], flower: ["#f08aa0", 0.25, 0.3], flowerCenter: ["#f6d06a", 0.25, 0.3],
    hangPot: ["#ebe3d6", 0.1], cord: ["#efe2cc", 0.12],
    bookA: ["#c56a5a", 0.1], bookB: ["#e2be80", 0.1], bookC: ["#5a7ea8", 0.1], bookD: ["#7e9f7e", 0.1],
    bookE: ["#9a6c94", 0.1], bookF: ["#eadcc2", 0.1], bookG: ["#3f5a72", 0.1],
    band: ["#f4eadb", 0.12], label: ["#f8f0e0", 0.12],
    wood: ["#c08b5c", 0.08], woodDark: ["#8f6141", 0.08], jarFill: ["#c98a5a", 0.1],
    clockRim: ["#5a4034", 0.08], clockFace: ["#fbf4e6", 0.12], clockTick: ["#5a4a44", 0.1], clockHand: ["#2f2622", 0.1],
    polaroid: ["#fbf8f1", 0.1], twine: ["#a8865f", 0.08], clip: ["#c9a46e", 0.1],
    photoSky0: ["#f2b8a0", 0.1], photoSun: ["#fde3a7", 0.15], photoSea: ["#7a9cc0", 0.1],
    photoSky1: ["#a8cce6", 0.1], photoHill: ["#6a8aa8", 0.1],
    photoSky2: ["#f4e6b8", 0.1], photoGreen: ["#88b07a", 0.1], photoTree: ["#4f7f55", 0.1],
    deskTop: ["#b98457", 0.1], deskGrain: ["#a37049", 0.1], deskFront: ["#875a3c", 0.05], deskEdge: ["#d6a070", 0.12],
    lamp: ["#4f7c78", 0.12, 0.25], lampDark: ["#3a5c59", 0.1, 0.2], lampLight: ["#8fb8b0", 0.12, 0.25], lampInner: ["#2c3b3b", 0.05],
    cover: ["#b5574b", 0.1, 0.5], paper: ["#fbf5e8", 0.1, 0.9], paperShade: ["#ddd0bb", 0.1, 0.85], ink: ["#4a4a68", 0.1, 0.6],
    ribbon: ["#c44a4a", 0.1, 0.6], pencil: ["#f2c14e", 0.1, 0.8], pencilWood: ["#ecd0a8", 0.1, 0.8],
    ferrule: ["#c8c0b8", 0.1, 0.8], eraser: ["#ec9a9a", 0.1, 0.8],
    mug: ["#f4eee6", 0.15, 0.6], stripe: ["#da8468", 0.15, 0.6], coffee: ["#4a2e22", 0.1, 0.4],
    radio: ["#e6c9a0", 0.12, 0.15], radioDark: ["#7a5440", 0.1, 0.1], grille: ["#9a7a62", 0.1, 0.1], grilleDot: ["#5c4436", 0.1, 0.1],
    dial: ["#f8ecd0", 0.15, 0.1], dialTick: ["#7a6a5a", 0.1, 0.1], needle: ["#d4553f", 0.15, 0.1],
    knob: ["#5c4436", 0.1, 0.1], antenna: ["#bcb4ac", 0.1, 0.1],
    phones: ["#ece3d8", 0.12, 0.15], phonesDark: ["#5c4642", 0.1, 0.1],
    snake: ["#4f8a5e", 0.12], snakeDark: ["#3c7050", 0.12], snakeEdge: ["#d8c66a", 0.12],
    pot2: ["#ece6dc", 0.1], pot2Band: ["#c98a6a", 0.1],
    radiator: ["#efe7dc", 0.12], radiatorShade: ["#d2c6b8", 0.1], valve: ["#c49a5a", 0.12],
    fur: ["#3a323f", 0.45]
}

// light from the window and room: the cat's rim light, steam, shadows, condensation, glints, music notes
function F(rim, steam, shadow, mist, glint, note) {
    return { rim: rim, steam: steam, shadow: shadow, mist: mist, glint: glint, note: note }
}
var LIGHT = [
    [-0.2, F("#6b5f96", "#a89aa6", "#120c16", "#5a4a68", "#ffcf9a", "#ffd9a8")],
    [0.0,  F("#ffb07e", "#e8d8d8", "#2a1a24", "#c8a8b0", "#ffe2c8", "#ffe0c0")],
    [0.25, F("#f6e6d0", "#ffffff", "#6e5a66", "#f2f4f8", "#ffffff", "#8a6a86")]
]

function room(e, overcast) {
    var amb = ambient(e, overcast), warm = lamp(e, overcast), o = {}
    for (var k in BASE) {
        var b = BASE[k], light = mix(amb, "#ffffff", b[1] || 0)
        if (b[2]) light = mix(light, LAMP_LIGHT, b[2] * warm)
        o[k] = mul(b[0], light)
    }
    var f = mixAll(frames(LIGHT, e), "#5d5768", clamp(overcast, 0, 1) * 0.25 * smooth(-0.1, 0.25, e))
    for (var j in f) o[j] = f[j]
    return o
}

