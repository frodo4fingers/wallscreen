// Render what the Pixel Loft window shows, with the real draw.js and palette, to raw RGBA.
// Usage: node tools/pixel_preview.js <elevation> <clouds> <rain> <snow> <fog> <wind> <tick> > out.rgba
// Output: GW x GH pixels (320x178), 4 bytes each.
const fs = require("fs"), vm = require("vm"), path = require("path")
const root = path.join(__dirname, "..", "package", "contents", "ui")
function load(f) {
    const ctx = { Math }
    vm.createContext(ctx)
    vm.runInContext(fs.readFileSync(path.join(root, f), "utf8").replace(".pragma library", ""), ctx)
    return ctx
}
const Draw = load("styles/pixel/draw.js"), Pal = load("styles/lofi/palette.js")
const [e, clouds, rain, snow, fog, wind, tick] = process.argv.slice(2).map(Number)

// a stand-in for a 2D canvas context: fillRect with alpha blending into a byte buffer
const W = Draw.GW, H = Draw.GH, buf = Buffer.alloc(W * H * 4)
const ctx = {
    fillStyle: "#000000", globalAlpha: 1,
    fillRect(x, y, w, h) {
        const c = Draw.rgb(this.fillStyle), a = this.globalAlpha
        for (let j = Math.max(0, y); j < Math.min(H, y + h); j++)
            for (let i = Math.max(0, x); i < Math.min(W, x + w); i++) {
                const o = (j * W + i) * 4
                for (let k = 0; k < 3; k++) buf[o + k] = Math.round(buf[o + k] * (1 - a) + c[k] * a)
                buf[o + 3] = 255
            }
    }
}

const overcast = Math.round(clouds * 50) / 50
const pal = Pal.sky(e, overcast)
// sun and moon as logic.js would place them: elevation e on a 6:00-18:00 day
const day = e >= 0, f = Math.asin(Math.min(1, Math.abs(e))) / Math.PI
const world = {
    sunVisible: e > -0.1, moonVisible: !day, moonPhase: 0.3, starOpacity: Math.min(1, Math.max(0, (-e - 0.05) / 0.25)),
    sunX: 0.04 + 0.92 * (day ? 1 - f : 1), sunY: 0.62 - 0.5 * e, moonX: 0.04 + 0.92 * 0.6, moonY: 0.62 - 0.5 * Math.abs(e),
    starStep: 0
}
Draw.drawSky(ctx, pal, world)
Draw.drawClouds(ctx, pal, clouds, Math.floor(tick / 16))
Draw.drawCity(ctx, pal, Pal.lights(e, overcast), 0, fog)
Draw.drawPrecip(ctx, pal, rain, snow, wind, tick)
process.stdout.write(buf)
// the room crossfade the scene uses, for the caller
process.stderr.write(JSON.stringify({ lamp: Pal.lamp(e, overcast) }) + "\n")
