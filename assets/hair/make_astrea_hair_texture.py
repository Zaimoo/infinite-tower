"""Generates Astrea's hair texture atlas (assets/hair/astrea_hair_texture.png).

Our own procedural strand texture, drawn with PIL, so the hair meshes read as hair instead of
flat plastic: fine strand lines with darker clump grooves, darker roots fading to bright tips,
a soft shine band near the root, and cylindrical shading across each lock.

The atlas is 1024 x 1024, four columns of 256 px. Each column is one lock: across the column is
across the lock's width (UV u), down the column is along its length, root at the top and tip at
the bottom (UV v = 1 at the root). Columns 0 and 1 are two variants for the outer layers, 2 and 3
darker, cooler variants for the inner layers and the scalp, so the layers separate visually.
tools/make_astrea_hair_ugc.py assigns each lock a column.

Silver hair: a textured Roblox mesh ignores the part colour, so the colour is painted here.

    python -I assets/hair/make_astrea_hair_texture.py
"""

import math
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

SIZE = 1024
COL = 256
S = 2  # supersampling
OUT = Path(__file__).with_name("astrea_hair_texture.png")

# Silver with cool lavender-blue shadows (her art), root -> mid -> tip
ROOT = (112, 114, 140)
MID = (208, 212, 230)
TIP = (240, 242, 250)
INNER_SHADE = (0.74, 0.75, 0.8)  # multiply for the inner variants (cooler and darker)


def lerp(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def base_colour(t):
    """Colour along the lock: t = 0 at the root, 1 at the tip."""
    if t < 0.3:
        return lerp(ROOT, MID, (t / 0.3) ** 0.6)
    return lerp(MID, TIP, (t - 0.3) / 0.7)


def column(seed, inner):
    rng = random.Random(seed)
    w, h = COL * S, SIZE * S
    img = Image.new("RGB", (w, h))
    px = img.load()
    # Base: length gradient x cylindrical shading across the lock, plus a shine band
    for y in range(h):
        t = y / (h - 1)
        c = base_colour(t)
        shine = 34 * math.exp(-((t - 0.22) / 0.09) ** 2)
        for x in range(w):
            u = x / (w - 1)
            across = 0.8 + 0.2 * math.sin(math.pi * u)
            r, g, b = (min(255, c[i] * across + shine) for i in range(3))
            if inner:
                r, g, b = r * INNER_SHADE[0], g * INNER_SHADE[1], b * INNER_SHADE[2]
            px[x, y] = (int(r), int(g), int(b))
    d = ImageDraw.Draw(img, "RGBA")
    # Fine strands: thin lines along the length with a slight wobble, lighter or darker
    for _ in range(320):
        x0 = rng.uniform(0, w)
        amp, ph, freq = rng.uniform(0.3, 1.5) * S, rng.uniform(0, 6.28), rng.uniform(0.6, 2.2)
        delta = rng.choice((-1, 1)) * rng.uniform(8, 30)
        col = (255, 255, 255, int(abs(delta) * 2.4)) if delta > 0 else (40, 40, 70, int(abs(delta) * 2.4))
        y_start = rng.uniform(0, 0.05) * h
        y_end = h - rng.uniform(0, 0.08) * h
        pts = [(x0 + amp * math.sin(freq * 6.28 * (y / h) + ph), y) for y in range(int(y_start), int(y_end), 8)]
        d.line(pts, fill=col, width=rng.choice((1, 1, 2, 3)))
    # Clump grooves: a few deeper dark lines that split the lock into strand clumps
    for _ in range(5):
        x0 = rng.uniform(0.12, 0.88) * w
        amp, ph = rng.uniform(0.5, 1.5) * S, rng.uniform(0, 6.28)
        pts = [(x0 + amp * math.sin(1.3 * 6.28 * (y / h) + ph), y) for y in range(int(h * rng.uniform(0, 0.15)), h, 8)]
        d.line(pts, fill=(60, 58, 90, 55), width=2 * S)
    # Tips: the last stretch separates into wisps (dark gaps between bright strands)
    for _ in range(26):
        x0 = rng.uniform(0, w)
        d.line([(x0, h * rng.uniform(0.8, 0.9)), (x0 + rng.uniform(-6, 6), h)], fill=(50, 50, 80, 110), width=2 * S)
    img = img.filter(ImageFilter.GaussianBlur(0.9 * S))
    return img.resize((COL, SIZE), Image.Resampling.LANCZOS)


def main():
    atlas = Image.new("RGB", (SIZE, SIZE))
    for i, (seed, inner) in enumerate(((11, False), (23, False), (37, True), (53, True))):
        atlas.paste(column(seed, inner), (i * COL, 0))
    atlas.save(OUT)
    print(f"Saved: {OUT}")


if __name__ == "__main__":
    main()
