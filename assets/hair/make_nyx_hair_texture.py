"""Generates Nyx's hair texture (assets/hair/nyx_hair_texture.png).

Her reference art has black hair that fades to bright teal toward the ends. The hair mesh
(tools/make_nyx_hair_ugc.py) maps V to height on the head: V = 1 at the crown, 0.5 at the
cheeks and 0 at the chin and nape. This texture is black over its upper half and fades to teal
over the lower half, so every lock turns teal at the same height, like the art. U wraps around
the head; faint vertical strand streaks and a soft shine band keep it from reading as plastic.
Our own texture, drawn with PIL.

    python -I assets/hair/make_nyx_hair_texture.py
"""

import math
import random
from pathlib import Path

from PIL import Image

W, H = 256, 1024
OUT = Path(__file__).with_name("nyx_hair_texture.png")

BLACK = (24, 24, 30)
SHEEN = (58, 62, 76)
TEAL = (36, 214, 188)
DEEP_TEAL = (18, 120, 116)


def lerp(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def smooth(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)


def main():
    rng = random.Random(77)
    # Per-column strand streaks: a few lighter and darker lines.
    streak = [0.0] * W
    for _ in range(40):
        x = rng.randrange(W)
        amount = rng.uniform(-0.18, 0.22)
        for dx in range(-1, 2):
            streak[(x + dx) % W] += amount * (1 - abs(dx) * 0.5)
    img = Image.new("RGB", (W, H))
    px = img.load()
    for row in range(H):
        v = 1 - row / (H - 1)  # 1 at the top (crown), 0 at the bottom (ends)
        teal = smooth((0.55 - v) / 0.45)  # black above v 0.55, full teal at v 0.1
        base = lerp(BLACK, lerp(DEEP_TEAL, TEAL, smooth((0.4 - v) / 0.3)), teal)
        shine = math.exp(-((v - 0.78) / 0.06) ** 2) * 0.6  # a soft band near the crown
        for col in range(W):
            c = lerp(base, SHEEN, shine)
            k = 1 + streak[col]
            px[col, row] = tuple(max(0, min(255, round(ch * k))) for ch in c)
    img.save(OUT)
    print(OUT)


if __name__ == "__main__":
    main()
