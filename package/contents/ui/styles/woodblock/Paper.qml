import QtQuick

// Static washi paper overlay: grain specks, short fibers, warm edge vignette.
// Painted once per size change with a seeded PRNG, so it never flickers or changes.
Item {
    id: root

    property real strength: 0.5

    enabled: false
    opacity: Math.max(0, Math.min(1, strength))

    Canvas {
        anchors.fill: parent
        renderStrategy: Canvas.Cooperative
        renderTarget: Canvas.Image

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Component.onCompleted: requestPaint()

        onPaint: {
            var w = width, h = height
            if (w < 2 || h < 2) return
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, w, h)

            // mulberry32, fixed seed
            var s = 0x9e3779b9
            function rnd() {
                s = (s + 0x6D2B79F5) | 0
                var t = Math.imul(s ^ (s >>> 15), 1 | s)
                t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t
                return ((t ^ (t >>> 14)) >>> 0) / 4294967296
            }

            var px = Math.max(1, Math.min(w, h) / 1080)
            var n = Math.round(w * h / 1200) // specks per batch (~1700 at 1080p)

            // One path + one fill per colour/alpha batch.
            var batches = [
                ["rgba(58,47,32,0.04)", 1], ["rgba(58,47,32,0.08)", 1],
                ["rgba(255,250,240,0.05)", 1], ["rgba(255,250,240,0.10)", 1]
            ]
            for (var b = 0; b < batches.length; b++) {
                ctx.fillStyle = batches[b][0]
                ctx.beginPath()
                for (var i = 0; i < n; i++)
                    ctx.rect(rnd() * w, rnd() * h, px, px)
                ctx.fill()
            }

            // Fibers: short curved strokes, light cream, one path.
            var nf = Math.round(w * h / 6000)
            ctx.strokeStyle = "rgba(255,244,214,0.14)"
            ctx.lineWidth = px
            ctx.beginPath()
            for (var f = 0; f < nf; f++) {
                var x = rnd() * w, y = rnd() * h
                var len = (4 + rnd() * 16) * px
                var a = rnd() * Math.PI * 2
                var bend = (rnd() - 0.5) * len * 0.8
                var ex = x + Math.cos(a) * len, ey = y + Math.sin(a) * len
                ctx.moveTo(x, y)
                ctx.quadraticCurveTo((x + ex) / 2 - Math.sin(a) * bend,
                                     (y + ey) / 2 + Math.cos(a) * bend, ex, ey)
            }
            ctx.stroke()

            // Warm vignette: clear centre, #6b4a2a at 0.12 in the corners.
            var r = Math.sqrt(w * w + h * h) / 2
            var g = ctx.createRadialGradient(w / 2, h / 2, r * 0.45, w / 2, h / 2, r)
            g.addColorStop(0, "rgba(107,74,42,0)")
            g.addColorStop(1, "rgba(107,74,42,0.12)")
            ctx.fillStyle = g
            ctx.fillRect(0, 0, w, h)
        }
    }
}
