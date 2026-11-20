#!/usr/bin/env python3
"""Generate the images for the "Misty Forest" style.

The style animates a static watercolour painting of spruces in thick fog. This script derives
everything from that painting and from procedural noise:

  forest.jpg   the painting itself (only written when a source image is given)
  front.png    the painting again, with an alpha mask that keeps only the dark front trees; fog
               layers drift between forest.jpg and front.png so mist passes behind these trees
  mist1.png    two tileable fog textures (white, alpha from fractal noise in a horizontal band)
  mist2.png    that wrap left to right so they can scroll forever
  glow.png     a soft radial blob used for the pale light in the sky

Usage: python3 tools/misty_forest.py [source.png]
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

OUT = Path(__file__).resolve().parent.parent / "package/contents/ui/styles/forest"

# The front cut-out: pixels darker than L_OPAQUE are fully kept, brighter than L_CLEAR are
# dropped. Only the lower part of the picture counts, so dark sky or distant trees stay out.
L_CLEAR, L_OPAQUE = 0.42, 0.28
Y_START, Y_FULL = 0.35, 0.50       # vertical ramp (fraction of the height): 0 above, 1 below
FEATHER = 2                        # Gaussian radius in pixels for the alpha edge

MIST_SIZE = (1200, 500)
MIST_FOG = (236, 240, 238)


def smoothstep(a, b, x):
    """0 at x == a, 1 at x == b, smooth in between (works for a > b too)."""
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def make_front(painting):
    rgb = np.asarray(painting, np.float32) / 255
    lum = rgb @ np.array([0.2126, 0.7152, 0.0722], np.float32)
    h = lum.shape[0]
    ramp = smoothstep(Y_START * h, Y_FULL * h, np.arange(h, dtype=np.float32))[:, None]
    alpha = Image.fromarray((smoothstep(L_CLEAR, L_OPAQUE, lum) * ramp * 255).round().astype(np.uint8))
    alpha = alpha.filter(ImageFilter.GaussianBlur(FEATHER))
    img = painting.convert("RGBA")
    img.putalpha(alpha)
    # Transparent pixels keep no colour, which helps the PNG compress.
    a = np.asarray(img).copy()
    a[a[..., 3] == 0, :3] = 0
    return Image.fromarray(a)


def value_noise(w, h, cells_x, cells_y, rng):
    """Cosine-interpolated lattice noise in 0..1 that wraps horizontally."""
    lattice = rng.random((cells_y + 1, cells_x))
    u = np.arange(w) / w * cells_x
    v = np.arange(h) / h * cells_y
    x0, y0 = u.astype(int), v.astype(int)
    fx = ((1 - np.cos((u - x0) * np.pi)) / 2)[None, :]
    fy = ((1 - np.cos((v - y0) * np.pi)) / 2)[:, None]
    x1 = (x0 + 1) % cells_x
    top = lattice[y0][:, x0] * (1 - fx) + lattice[y0][:, x1] * fx
    bot = lattice[y0 + 1][:, x0] * (1 - fx) + lattice[y0 + 1][:, x1] * fx
    return top * (1 - fy) + bot * fy


def blur_wrap(a, sigma):
    """Gaussian blur that treats the columns as a loop, so the left and right edges still match."""
    r = int(sigma * 3)
    k = np.exp(-0.5 * (np.arange(-r, r + 1) / sigma) ** 2)
    k /= k.sum()
    padded = np.pad(a, ((r, r), (r, r)), mode="wrap")          # wrap both ways, rows are cropped
    tmp = sum(k[i] * padded[:, i:i + a.shape[1]] for i in range(2 * r + 1))
    return sum(k[i] * tmp[i:i + a.shape[0]] for i in range(2 * r + 1))


def make_mist(seed, band, max_alpha=0.95):
    """Fog texture: fractal noise shaped into soft billows inside a vertical band.

    The billows are large and separated by clear gaps, because a diffuse haze drifting over the
    pale painting does not read as movement.

    band = (fade-in start, dense start, dense end, fade-out end) as fractions of the height.
    """
    w, h = MIST_SIZE
    rng = np.random.default_rng(seed)
    n = sum(value_noise(w, h, 5 * 2 ** o, 2 * 2 ** o, rng) / 2 ** o for o in range(4))
    n = blur_wrap(n / (2 - 2 ** -3), 3)
    n = (n - n.min()) / (n.max() - n.min())        # use the whole 0..1 range whatever the seed
    y = np.arange(h) / h
    profile = smoothstep(band[0], band[1], y) * (1 - smoothstep(band[2], band[3], y))
    alpha = profile[:, None] * np.clip((n - 0.4) / 0.3, 0, 1) * max_alpha
    out = np.empty((h, w, 4), np.uint8)
    out[..., :3] = MIST_FOG
    out[..., 3] = (alpha * 255).round()
    return Image.fromarray(out)


def make_glow(size=256):
    c = (np.arange(size) + 0.5) / size * 2 - 1
    r = np.hypot(c[None, :], c[:, None])
    alpha = (1 - np.clip(r, 0, 1)) ** 2
    out = np.full((size, size, 4), 255, np.uint8)
    out[..., 3] = (alpha * 255).round()
    return Image.fromarray(out)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    if len(sys.argv) > 1:
        Image.open(sys.argv[1]).convert("RGB").save(OUT / "forest.jpg", quality=90)
    painting = Image.open(OUT / "forest.jpg").convert("RGB")
    make_front(painting).save(OUT / "front.png", optimize=True)
    make_mist(11, (0.15, 0.45, 0.75, 1.0)).save(OUT / "mist1.png", optimize=True)
    make_mist(23, (0.0, 0.30, 0.55, 0.85)).save(OUT / "mist2.png", optimize=True)
    make_glow().save(OUT / "glow.png", optimize=True)
    for f in sorted(OUT.iterdir()):
        print(f"{f.name}: {f.stat().st_size / 1e3:.0f} kB")


if __name__ == "__main__":
    main()
