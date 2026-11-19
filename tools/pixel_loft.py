#!/usr/bin/env python3
"""Generate the pixel art for the "Pixel Loft" style.

Everything is drawn at the native art size (576x240) with hard-edged shapes. The room is
drawn once in flat "albedo" colours and then lit twice: a day version lit by the window,
and a night version lit by the lamps. Light is quantized with an ordered (Bayer) dither so
it falls off in a few clean pixel bands instead of smooth gradients.

Usage: python3 tools/pixel_loft.py [output_dir]
"""
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

W, H = 576, 240
GLASS = (150, 12, 470, 190)          # x0, y0, x1, y1 of the window glass (exclusive x1, y1)
FLOOR_Y = 200

BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]], np.float32) / 16


def bands(v, n, xx, yy, width=0.3):
    """Quantize v (0..1) to n steps; dither only a narrow band around each step edge."""
    t = BAYER[yy.astype(int) % 4, xx.astype(int) % 4]
    return np.floor(v * n + 0.5 + (t - 0.5) * width) / n


def hexc(h, a=255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


def dark(c, f=0.62):
    return tuple(int(v * f) for v in c[:3]) + (255,)


P = {k: hexc(v) for k, v in {
    "ceiling": "#6f6787", "wall": "#8a81a2", "wallTrim": "#6a6284", "skirting": "#5a5272",
    "floor": "#9a6b4f", "floorLine": "#82573f", "floorShade": "#7a5039",
    "rug": "#c07a62", "rugEdge": "#e3b48c", "rugDark": "#9a5a4a",
    "frame": "#2b2838", "frameHi": "#4a4560",
    "bench": "#b98c66", "benchTop": "#d4a77d", "cushion": "#e2d3b6", "cushionShade": "#c5b292",
    "pillow": "#d97757", "pillowShade": "#b35e48",
    "cat": "#e3995a", "catStripe": "#b8723d", "catLight": "#f4c189",
    "desk": "#c89c72", "deskTop": "#dcb38a", "deskLeg": "#2b2838",
    "bezel": "#1f1c29", "screen": "#3a3f74",
    "keys": "#e8e2d8", "keysShade": "#bcb4a8",
    "mug": "#d97757", "mugShade": "#a8553f",
    "shelf": "#b98c66", "shelfShade": "#8e6748",
    "book1": "#5c7a67", "book2": "#d97757", "book3": "#4a5f8a", "book4": "#e8c37a", "book5": "#8a5a7a",
    "player": "#3a3346", "vinyl": "#1a1622", "label": "#e8c37a",
    "chair": "#5c7a67", "chairShade": "#46604f", "chairLight": "#7a9a83",
    "blanket": "#e8c37a", "blanketStripe": "#c9894a",
    "metal": "#2b2838", "lampShade": "#ece0c8", "lampShadeDark": "#c8b896",
    "leaf": "#4f8a5b", "leafDark": "#35644a", "leafLight": "#7ab27a",
    "pot": "#e8e2d8", "potShade": "#bdb5a8",
    "poster": "#2D284B", "posterArt": "#D97757", "posterSun": "#FFB347", "posterHill": "#5C7A67",
    "wire": "#2b2838", "bulb": "#ffd27f",
}.items()}


def draw_room():
    img = Image.new("RGBA", (W, H), P["wall"])
    emit = Image.new("RGB", (W, H), (0, 0, 0))      # what glows at night, added after lighting
    d, e = ImageDraw.Draw(img), ImageDraw.Draw(emit)

    # ceiling, floor, skirting
    d.rectangle((0, 0, W - 1, 9), fill=P["ceiling"])
    d.line((0, 10, W - 1, 10), fill=P["wallTrim"])
    d.rectangle((0, FLOOR_Y, W - 1, H - 1), fill=P["floor"])
    for y in (206, 214, 224, 236):
        d.line((0, y, W - 1, y), fill=P["floorLine"])
    for i, y in enumerate((200, 206, 214, 224)):
        for x in range((i * 37) % 60, W, 60 + i * 9):
            d.line((x, y + 1, x, y + (6, 7, 9, 11)[i]), fill=P["floorLine"])
    d.rectangle((0, FLOOR_Y - 4, W - 1, FLOOR_Y - 1), fill=P["skirting"])

    # window: thin black steel frame, two mullions and a transom
    x0, y0, x1, y1 = GLASS
    d.rectangle((x0 - 3, y0 - 3, x1 + 2, y1 + 1), fill=P["frame"])
    d.rectangle((x0, y0, x1 - 1, y1 - 1), fill=(0, 0, 0, 0))
    for mx in (256, 363):
        d.rectangle((mx, y0, mx + 1, y1 - 1), fill=P["frame"])
    d.rectangle((x0, 54, x1 - 1, 55), fill=P["frame"])
    d.line((x0 - 3, y0 - 3, x1 + 2, y0 - 3), fill=P["frameHi"])

    # string lights across the top of the window
    pts = []
    for x in range(x0 - 2, x1 + 2):
        u = ((x - x0) / 53.3) % 1
        pts.append((x, int(y0 + 2 + 5 * math.sin(math.pi * u))))
    d.line(pts, fill=P["wire"])
    bulbs = []
    for i, (x, y) in enumerate(pts[6::13]):
        d.rectangle((x, y + 1, x + 1, y + 2), fill=P["bulb"])
        e.rectangle((x, y + 1, x + 1, y + 2), fill=(255, 205, 120))
        bulbs.append((x, y + 2))

    # window bench with a long cushion, a pillow, and the cat's spot
    d.rectangle((x0 - 6, 178, x1 + 5, 199), fill=P["bench"])
    d.rectangle((x0 - 6, 178, x1 + 5, 180), fill=P["benchTop"])
    d.line((x0 - 6, 199, x1 + 5, 199), fill=dark(P["bench"]))
    for x in range(x0 + 20, x1, 64):
        d.line((x, 183, x, 196), fill=dark(P["bench"], .8))
    d.rounded_rectangle((x0 - 2, 170, x1 + 1, 179), 3, fill=P["cushion"], outline=dark(P["cushion"], .7))
    d.line((x0, 177, x1 - 1, 177), fill=P["cushionShade"])
    d.rounded_rectangle((x0 + 2, 156, x0 + 26, 172), 4, fill=P["pillow"], outline=dark(P["pillow"], .65))
    d.line((x0 + 5, 168, x0 + 23, 168), fill=P["pillowShade"])

    # bookshelf against the left wall, with a record player on top
    d.rectangle((10, 146, 138, 199), fill=P["shelf"], outline=dark(P["shelf"], .6))
    for y in (163, 181):
        d.line((11, y, 137, y), fill=P["shelfShade"])
    colors = [P["book1"], P["book2"], P["book3"], P["book4"], P["book5"]]
    rx = 14
    for shelf_y in (148, 165, 183):
        x, k = rx, (shelf_y // 7) % 5
        while x < 132:
            w, h = 3 + (k * 7) % 4, 12 + (k * 5) % 4
            if (k * 13) % 9 == 0:
                x += 5
            else:
                d.rectangle((x, shelf_y + 14 - h, x + w - 1, shelf_y + 13), fill=colors[k % 5], outline=dark(colors[k % 5], .7))
            x += w
            k += 1
    d.rectangle((26, 134, 74, 145), fill=P["player"], outline=dark(P["player"], .6))
    d.ellipse((30, 133, 58, 141), fill=P["vinyl"])
    d.point((44, 137), fill=P["label"])
    d.rectangle((42, 136, 46, 138), fill=P["label"])
    d.line((66, 134, 54, 139), fill=P["keysShade"])
    d.rectangle((96, 126, 112, 145), fill=P["pot"], outline=dark(P["pot"], .7))   # small plant on the shelf
    for (lx, ly) in ((98, 118), (104, 112), (110, 119), (101, 122), (108, 123)):
        d.ellipse((lx - 4, ly - 3, lx + 4, ly + 3), fill=P["leaf"], outline=P["leafDark"])

    # poster above the shelf
    d.rectangle((30, 50, 96, 118), fill=P["frame"])
    d.rectangle((33, 53, 93, 115), fill=P["poster"])
    d.ellipse((50, 62, 76, 88), fill=P["posterSun"])
    d.polygon([(33, 115), (33, 98), (50, 84), (64, 96), (78, 80), (93, 96), (93, 115)], fill=P["posterHill"])
    d.rectangle((33, 104, 93, 115), fill=P["posterArt"])

    # arc floor lamp reaching over the armchair
    def bez(p0, p1, p2, p3, n=40):
        return [tuple((1 - t) ** 3 * a + 3 * (1 - t) ** 2 * t * b + 3 * (1 - t) * t * t * c + t ** 3 * e_
                      for a, b, c, e_ in zip(p0, p1, p2, p3)) for t in [i / n for i in range(n + 1)]]
    arc = [(18, 232), (18, 70)] + bez((18, 70), (18, 26), (80, 18), (110, 44))
    d.line([(int(x), int(y)) for x, y in arc], fill=P["metal"], width=2)
    d.rectangle((10, 231, 28, 234), fill=P["metal"])
    sx, sy = int(arc[-1][0]), int(arc[-1][1])
    d.polygon([(sx - 9, sy + 10), (sx - 5, sy), (sx + 5, sy), (sx + 9, sy + 10)], fill=P["lampShade"], outline=P["lampShadeDark"])
    d.line((sx - 7, sy + 10, sx + 7, sy + 10), fill=P["lampShadeDark"])
    e.rectangle((sx - 6, sy + 10, sx + 6, sy + 11), fill=(255, 214, 150))
    lamp = (sx, sy + 12)

    # armchair with a mustard blanket
    d.rounded_rectangle((34, 176, 130, 224), 6, fill=P["chair"], outline=dark(P["chair"], .6))      # back
    d.rounded_rectangle((26, 196, 52, 232), 5, fill=P["chairLight"], outline=dark(P["chair"], .6))  # arms
    d.rounded_rectangle((112, 196, 138, 232), 5, fill=P["chair"], outline=dark(P["chair"], .6))
    d.rectangle((48, 206, 116, 222), fill=P["chairShade"])
    d.rectangle((40, 232, 44, 237), fill=P["deskLeg"])
    d.rectangle((122, 232, 126, 237), fill=P["deskLeg"])
    d.polygon([(92, 178), (116, 178), (122, 194), (140, 198), (140, 226), (112, 230), (108, 206), (90, 204)],
              fill=P["blanket"], outline=dark(P["blanket"], .7))
    for y in (186, 200, 214):
        d.line((96, y, 138, y + 4), fill=P["blanketStripe"])

    # rug
    d.polygon([(176, 214), (404, 214), (430, 236), (150, 236)], fill=P["rug"], outline=P["rugDark"])
    d.polygon([(184, 217), (396, 217), (416, 233), (164, 233)], outline=P["rugEdge"])
    for x in range(200, 390, 24):
        d.polygon([(x, 222), (x + 6, 225), (x, 228), (x - 6, 225)], fill=P["rugEdge"])

    # plant shelf in front of the right pane: three wooden boards on a thin black frame
    for bx in (388, 536):
        d.rectangle((bx, 146, bx + 1, 233), fill=P["metal"])
    boards = (148, 180, 210)
    for by in boards:
        d.rectangle((386, by, 540, by + 3), fill=P["benchTop"], outline=dark(P["bench"], .6))
        d.line((387, by + 3, 539, by + 3), fill=P["shelfShade"])

    def pot(x0, x1, bottom, h, color=None, rim=True):
        c = color or P["pot"]
        d.polygon([(x0, bottom - h), (x1, bottom - h), (x1 - 1, bottom), (x0 + 1, bottom)], fill=c, outline=dark(c, .68))
        if rim:
            d.line((x0, bottom - h + 1, x1, bottom - h + 1), fill=dark(c, .85))

    def leaf_at(x, y, light=False):
        d.polygon([(x - 2, y), (x, y + 1), (x + 2, y), (x + 2, y + 2), (x, y + 4), (x - 2, y + 2)],
                  fill=P["leafLight"] if light else P["leaf"], outline=P["leafDark"])

    def trail(x, top, length, seed):
        for k in range(0, length, 5):
            vx = x + int(2 * math.sin(k / 8 + seed))
            d.point((vx, top + k), fill=P["leafDark"])
            leaf_at(vx + (-3 if (k // 5) % 2 else 3), top + k, k % 15 == 0)

    def snake(x, bottom, height):
        for i, (dx, h) in enumerate(((-4, .75), (-1, 1.0), (2, .9), (5, .65), (0, .55))):
            top = bottom - int(height * h)
            c = P["leaf"] if i % 2 else hexc("#5f8f55")
            d.polygon([(x + dx - 1, bottom), (x + dx + 2, bottom), (x + dx + 1, top)], fill=c, outline=P["leafDark"])
            d.point((x + dx, bottom - int(height * h * .5)), fill=hexc("#c9c27a"))

    def fern(cx, base, w, h):
        for side in (-1, 1):
            for j in range(4):
                tipx, tipy = cx + side * (w - j * 3), base - h + j * 4
                d.line((cx, base, tipx, tipy), fill=P["leafDark"])
                for t in (.35, .6, .85):
                    px, py = cx + (tipx - cx) * t, base + (tipy - base) * t
                    d.point((int(px), int(py) - 1), fill=P["leafLight"] if j == 0 else P["leaf"])
                    d.point((int(px), int(py) + 1), fill=P["leaf"])

    def rosette(cx, cy, r, c):
        d.ellipse((cx - r, cy - r + 1, cx + r, cy + r - 1), fill=c, outline=dark(c, .6))
        d.ellipse((cx - r + 2, cy - r + 2, cx + r - 2, cy + r - 3), fill=dark(c, 1.2) if False else hexc("#9cc59a"))
        d.point((cx, cy - 1), fill=dark(c, .6))

    # top board: snake plant, mushroom lamp, trailing pothos, the mug, a cactus, succulents, a tall leafy plant
    t = boards[0]
    snake(399, t - 10, 40)
    pot(392, 407, t - 1, 10, hexc("#e8dccb"))
    d.rectangle((424, t - 8, 427, t - 1), fill=hexc("#d9c7a8"), outline=dark(hexc("#d9c7a8"), .7))   # mushroom lamp
    d.pieslice((416, t - 18, 436, t - 2), 180, 360, fill=hexc("#f0b27a"), outline=dark(hexc("#f0b27a"), .7))
    e.pieslice((417, t - 17, 435, t - 3), 180, 360, fill=(255, 196, 128))
    pot(444, 458, t - 1, 9, P["pillow"])
    for (lx, ly) in ((446, t - 12), (452, t - 14), (457, t - 11), (449, t - 10)):
        leaf_at(lx, ly)
    trail(447, t + 4, 26, 1)
    trail(455, t + 4, 40, 3)
    d.rectangle((466, t - 8, 474, t - 1), fill=P["mug"], outline=dark(P["mug"], .6))
    d.line((467, t - 7, 473, t - 7), fill=P["mugShade"])
    for yy in (t - 6, t - 5, t - 4):
        d.point((475, yy), fill=dark(P["mug"], .6))
    pot(481, 492, t - 1, 7, hexc("#c07a62"))
    d.rounded_rectangle((484, t - 22, 489, t - 7), 2, fill=hexc("#6f9a5e"), outline=P["leafDark"])
    d.rounded_rectangle((480, t - 17, 483, t - 12), 1, fill=hexc("#6f9a5e"), outline=P["leafDark"])
    for yy in range(t - 20, t - 8, 3):
        d.point((486, yy), fill=hexc("#e8e2d8"))
    d.rectangle((498, t - 5, 516, t - 1), fill=hexc("#5a5272"), outline=dark(hexc("#5a5272"), .7))  # succulent bowl
    rosette(503, t - 7, 4, hexc("#6fa07a"))
    rosette(511, t - 6, 3, hexc("#8ab07a"))
    pot(521, 535, t - 1, 12, hexc("#e8e2d8"))
    d.line((528, t - 12, 528, t - 40), fill=P["leafDark"])
    for i, (lx, ly) in enumerate(((523, t - 38), (533, t - 34), (522, t - 28), (534, t - 22), (525, t - 18), (531, t - 44))):
        d.ellipse((lx - 4, ly - 3, lx + 4, ly + 3), fill=P["leafLight"] if i == 5 else P["leaf"], outline=P["leafDark"])

    # middle board: a fern, two little pots, books, a watering can, a round leafy plant
    m = boards[1]
    fern(401, m - 10, 12, 18)
    pot(394, 409, m - 1, 10, hexc("#e8dccb"))
    for x0, c in ((418, hexc("#c07a62")), (432, hexc("#5C7A67"))):
        pot(x0, x0 + 9, m - 1, 7, c)
        rosette(x0 + 4, m - 9, 3, hexc("#7fae86"))
    for i, (h, c) in enumerate(((5, P["book3"]), (4, P["book4"]), (5, P["book2"]))):
        y1 = m - 1 - sum((5, 4, 5)[:i])
        d.rectangle((446 + i, y1 - h + 1, 472 - i, y1), fill=c, outline=dark(c, .7))
    d.polygon([(482, m - 1), (481, m - 11), (496, m - 11), (495, m - 1)], fill=hexc("#7d8fb0"), outline=dark(hexc("#7d8fb0"), .65))
    d.line((496, m - 9, 503, m - 15), fill=dark(hexc("#7d8fb0"), .65))      # spout
    d.arc((482, m - 17, 494, m - 7), 180, 360, fill=dark(hexc("#7d8fb0"), .65))
    pot(510, 530, m - 1, 10, hexc("#e8dccb"))
    for (lx, ly) in ((513, m - 16), (520, m - 20), (527, m - 15), (516, m - 12), (525, m - 11), (520, m - 13)):
        d.ellipse((lx - 4, ly - 3, lx + 4, ly + 3), fill=P["leaf"], outline=P["leafDark"])

    # bottom board: a big leafy pot, a woven basket, small pots stacked
    b = boards[2]
    pot(395, 419, b - 1, 14, P["pillow"])
    for (lx, ly) in ((398, b - 22), (407, b - 27), (416, b - 21), (402, b - 16), (412, b - 15)):
        d.ellipse((lx - 5, ly - 4, lx + 5, ly + 4), fill=P["leaf"], outline=P["leafDark"])
        d.point((lx - 2, ly - 2), fill=P["leafLight"])
    d.rectangle((428, b - 12, 468, b - 1), fill=hexc("#c9a06a"), outline=dark(hexc("#c9a06a"), .65))
    for yy in range(b - 10, b - 1, 3):
        d.line((429, yy, 467, yy), fill=dark(hexc("#c9a06a"), .8))
    for (lx, ly) in ((434, b - 15), (442, b - 17), (450, b - 15), (458, b - 16), (464, b - 14)):
        leaf_at(lx, ly)
    pot(478, 496, b - 1, 9, hexc("#e8e2d8"))
    pot(480, 494, b - 10, 6, hexc("#c07a62"))
    snake(487, b - 16, 16)
    pot(504, 528, b - 1, 11, hexc("#5a5272"))
    fern(516, b - 12, 11, 14)
    desk_lamp = (426, t - 8)
    mug = (469, t - 9)

    # big monstera in the corner: heart-shaped leaves with the typical splits
    d.polygon([(540, 236), (544, 206), (572, 206), (575, 236)], fill=P["pot"], outline=dark(P["pot"], .7))
    d.line((542, 214, 574, 214), fill=P["potShade"])
    for (cx, cy, r, tilt) in ((556, 104, 15, -.5), (548, 150, 19, -.9), (570, 128, 18, .3), (542, 184, 15, -1.3), (571, 170, 18, .8)):
        d.line((558, 206, cx, cy), fill=P["leafDark"], width=2 if cy > 150 else 1)
        ca, sa = math.cos(tilt), math.sin(tilt)
        def at(u, v):
            return (cx + (u * ca - v * sa) * r, cy + (u * sa + v * ca) * r * .8)
        heart = [at(1.2 * math.sin(a) ** 3, -(1.0 * math.cos(a) - .4 * math.cos(2 * a) - .15 * math.cos(3 * a))) for a in
                 [2 * math.pi * i / 32 for i in range(32)]]
        d.polygon(heart, fill=P["leaf"], outline=P["leafDark"])
        d.line([at(0, -.6), at(0, .9)], fill=P["leafDark"])
        for v in (-.35, .05, .45):
            for side in (-1, 1):
                d.line([at(side * .55, v), at(side * 1.25, v + .18)], fill=P["wall"], width=1)
        d.point(at(-.35, -.2), fill=P["leafLight"])
        d.point(at(-.45, -.1), fill=P["leafLight"])

    # hanging pothos at the left edge of the window
    d.line((142, 10, 142, 38), fill=P["metal"])
    d.rectangle((134, 38, 150, 48), fill=P["pot"], outline=dark(P["pot"], .7))
    for vx, length in ((136, 70), (142, 92), (148, 60), (153, 44)):
        for k in range(0, length, 6):
            x = vx + int(2 * math.sin(k / 9 + vx))
            y = 48 + k
            d.point((x, y), fill=P["leafDark"])
            side = -3 if (k // 6) % 2 else 3
            lx = x + side
            d.polygon([(lx - 2, y), (lx, y + 1), (lx + 2, y), (lx + 2, y + 2), (lx, y + 4), (lx - 2, y + 2)],
                      fill=P["leafLight"] if k % 18 == 0 else P["leaf"], outline=P["leafDark"])

    return img, emit, {"lamp": lamp, "desk": desk_lamp, "mug": mug, "bulbs": bulbs}


CAT_BOX = (174, 154, 214, 173)     # x0, y0, x1, y1 of the cat sprite on the window bench


def draw_cat(img, frame):
    """A ginger cat asleep on the bench cushion, curled up with its head on the left.
    Frame 1 is the breath in: the back rises by one pixel."""
    d = ImageDraw.Draw(img)
    up = frame
    d.ellipse((184, 162 - up, 208, 175), fill=P["cat"], outline=dark(P["cat"], .55))          # body
    d.rectangle((183, 170, 209, 172), fill=P["cushion"])                                       # cut the body flat on the cushion
    d.line((185, 169, 208, 169), fill=dark(P["cat"], .55))
    for x in (194, 199, 204):
        d.line((x, 163 - up + (1 if x == 204 else 0), x - 1, 166 - up), fill=P["catStripe"])
    d.line((190, 164 - up, 200, 163 - up), fill=P["catLight"])
    d.line((206, 168, 186, 169), fill=P["catStripe"])                                         # tail wrapped in front
    d.point((185, 168), fill=P["catStripe"])
    d.ellipse((177, 161, 189, 170), fill=P["cat"], outline=dark(P["cat"], .55))                # head
    d.polygon([(178, 163), (179, 158), (182, 162)], fill=P["cat"], outline=dark(P["cat"], .55))  # ears
    d.polygon([(184, 162), (187, 158), (188, 163)], fill=P["cat"], outline=dark(P["cat"], .55))
    d.point((180, 161), fill=P["catLight"])
    d.line((180, 166, 182, 166), fill=dark(P["cat"], .4))                                      # closed eyes
    d.line((184, 166, 186, 166), fill=dark(P["cat"], .4))
    d.point((183, 168), fill=hexc("#b8604a"))                                                   # nose
    d.line((178, 169, 188, 169), fill=dark(P["cat"], .55))


WALK_W, WALK_H = 30, 20             # one frame of the walking cat; feet on the bottom row


class Shifted:
    """An ImageDraw stand-in that moves everything down by dy pixels."""
    def __init__(self, d, dy):
        self.d, self.dy = d, dy

    def _shift(self, xy):
        if isinstance(xy, list):
            return [(x, y + self.dy) for x, y in xy]
        if len(xy) == 2:
            return (xy[0], xy[1] + self.dy)
        return (xy[0], xy[1] + self.dy, xy[2], xy[3] + self.dy)

    def __getattr__(self, name):
        f = getattr(self.d, name)
        return lambda xy, *a, **k: f(self._shift(xy), *a, **k)


def draw_walk(d, frame):
    """The cat side-on, facing right, into a WALK_W x WALK_H frame.
    Frames 0-3 are the walk cycle (0 doubles as standing), frame 4 is sitting."""
    o = dark(P["cat"], .55)
    if frame == 4:
        d.polygon([(4, 17), (2, 15), (3, 13), (8, 14)], fill=P["catStripe"])               # tail curled round the feet
        d.ellipse((7, 5, 20, 18), fill=P["cat"], outline=o)                                  # upright body
        d.line((9, 9, 9, 15), fill=P["catStripe"])
        d.line((12, 8, 12, 16), fill=P["catStripe"])
        d.rectangle((15, 15, 18, 17), fill=P["catLight"])                                    # front paws
        d.ellipse((13, 0, 23, 9), fill=P["cat"], outline=o)                                  # head
        d.polygon([(14, 2), (15, -2), (17, 1)], fill=P["cat"], outline=o)
        d.polygon([(19, 1), (21, -2), (22, 3)], fill=P["cat"], outline=o)
        d.point((20, 4), fill=dark(P["cat"], .3))
        d.point((23, 6), fill=hexc("#b8604a"))
        return
    # legs: [x, lift] for back-far, back-near, front-far, front-near; the cycle swings them
    swing = [(0, 1, 0, 1), (1, 0, 1, 0), (0, -1, 0, -1), (-1, 0, -1, 0)][frame]
    lifted = [(0, 0, 1, 0), (0, 0, 0, 0), (1, 0, 0, 0), (0, 0, 0, 0)][frame]
    for i, (bx, near) in enumerate(((8, False), (10, True), (19, False), (21, True))):
        x = bx + swing[i]
        c = P["catStripe"] if not near else P["cat"]
        d.rectangle((x, 12, x + 1, 17 - lifted[i]), fill=c, outline=None)
        d.point((x, 17 - lifted[i]), fill=o)
        d.point((x + 1, 17 - lifted[i]), fill=o)
    d.ellipse((5, 5, 24, 14), fill=P["cat"], outline=o)                                      # body
    for x in (10, 14, 18):
        d.line((x, 6, x - 1, 9), fill=P["catStripe"])
    d.line((9, 6, 19, 6), fill=P["catLight"])
    tip = (3, 1) if frame % 2 == 0 else (2, 2)                                                # the tail tip sways a pixel
    d.line([(5, 8), (3, 7), (2, 5), (2, 3), tip], fill=P["catStripe"], width=2)
    d.ellipse((20, 2, 29, 11), fill=P["cat"], outline=o)                                     # head
    d.polygon([(21, 4), (22, 0), (24, 3)], fill=P["cat"], outline=o)
    d.polygon([(25, 3), (27, 0), (28, 5)], fill=P["cat"], outline=o)
    d.point((26, 6), fill=dark(P["cat"], .3))                                                 # open eye
    d.point((29, 8), fill=hexc("#b8604a"))


def light_maps(alpha, lights):
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    x0, y0, x1, y1 = GLASS

    # day: soft ambient plus light from the window falling into the room
    dx = np.maximum(0, np.maximum(x0 - xx, xx - x1))
    dy = np.maximum(0, yy - y1) * 0.6
    near_window = np.exp(-(np.hypot(dx, dy) / 150) ** 2)
    day_level = 0.66 + bands(near_window, 3, xx, yy) * 0.36
    day = np.dstack([day_level * 1.02, day_level * 1.0, day_level * 0.96])

    # night: a dim blue ambient from the city, warm pools from the lamps, cool light from the monitor
    def pool(cx, cy, radius, color, strength, squash=1.0):
        r = np.hypot(xx - cx, (yy - cy) / squash) / radius
        level = bands(np.clip(1 - r, 0, 1) ** 1.2, 4, xx, yy) * strength
        return np.dstack([level * c for c in color])

    night = np.dstack([np.full((H, W), v) for v in (0.20, 0.22, 0.36)])
    night = night + 0.12 * np.dstack([bands(near_window, 2, xx, yy) * c for c in (0.7, 0.75, 1.0)])
    night += pool(lights["lamp"][0], lights["lamp"][1] + 70, 125, (1.0, 0.72, 0.45), 1.0, 1.25)
    night += pool(lights["lamp"][0], lights["lamp"][1] + 4, 34, (1.0, 0.8, 0.55), 0.6)
    night += pool(*lights["desk"], 92, (1.0, 0.76, 0.5), 0.75, 1.1)
    for bx, by in lights["bulbs"]:
        night += pool(bx, by, 14, (1.0, 0.75, 0.45), 0.35)
    return day, night


def lit(albedo, light, emit=None):
    a = np.asarray(albedo).astype(np.float32) / 255
    rgb = a[..., :3] * light
    if emit is not None:
        rgb = np.maximum(rgb, np.asarray(emit).astype(np.float32) / 255)
    out = np.dstack([np.clip(rgb, 0, 1), a[..., 3:]])
    return Image.fromarray((out * 255 + 0.5).astype(np.uint8), "RGBA")


def main():
    out = Path(sys.argv[1] if len(sys.argv) > 1 else "package/contents/ui/styles/pixel")
    out.mkdir(parents=True, exist_ok=True)
    albedo, emit, lights = draw_room()
    day, night = light_maps(np.asarray(albedo)[..., 3], lights)
    lit(albedo, day).save(out / "room_day.png", optimize=True)
    lit(albedo, night, emit).save(out / "room_night.png", optimize=True)
    # the cat: two breathing frames side by side, lit like the room around it
    for name, light, glow in (("cat_day.png", day, None), ("cat_night.png", night, emit)):
        x0, y0, x1, y1 = CAT_BOX
        strip = Image.new("RGBA", (2 * (x1 - x0), y1 - y0))
        for frame in (0, 1):
            layer = albedo.copy()
            draw_cat(layer, frame)
            sprite = lit(layer, light, glow).crop(CAT_BOX)
            strip.paste(sprite, (frame * (x1 - x0), 0))
        strip.save(out / name, optimize=True)

    # the walking cat: 5 frames, lit with the light found on the bench
    for name, light, at in (("cat_walk_day.png", day, (280, 165)), ("cat_walk_night.png", night, (176, 160))):
        sheet = Image.new("RGBA", (5 * WALK_W, WALK_H), (0, 0, 0, 0))
        for frame in range(5):
            f = Image.new("RGBA", (WALK_W, WALK_H), (0, 0, 0, 0))
            draw_walk(Shifted(ImageDraw.Draw(f), 2), frame)
            sheet.paste(f, (frame * WALK_W, 0))
        level = light[at[1], at[0]]
        sheet = lit(sheet, np.broadcast_to(level, (WALK_H, 5 * WALK_W, 3)))
        sheet.save(out / name, optimize=True)
    x0, y0, x1, y1 = GLASS
    (out / "art.js").write_text(
        ".pragma library\n\n"
        "// Generated by tools/pixel_loft.py together with the PNGs here; do not edit by hand.\n\n"
        f"// x, y, width, height of the window glass\nvar GLASS = [{x0}, {y0}, {x1 - x0}, {y1 - y0}]\n"
        f"// where the sleeping cat sprite goes, and its size\nvar CAT_BOX = {list(CAT_BOX[:2])}\n"
        f"var CAT_SIZE = [{CAT_BOX[2] - CAT_BOX[0]}, {CAT_BOX[3] - CAT_BOX[1]}]\n"
        f"// one walking frame, and the y that puts its feet on the cushion\nvar WALK_SIZE = [{WALK_W}, {WALK_H}]\n"
        f"var WALK_Y = {170 - WALK_H}\n"
        f"// top of the mug, where the steam starts\nvar MUG = {list(lights['mug'])}\n"
        f"var BULBS = {[list(b) for b in lights['bulbs']]}\n")
    print("wrote", out)


if __name__ == "__main__":
    main()
