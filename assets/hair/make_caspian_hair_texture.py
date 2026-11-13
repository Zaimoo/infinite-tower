"""Generates Caspian's hair texture (assets/hair/caspian_hair_texture.png).

His reference art's auburn hair is darker at the roots, catches a warm shine near the crown and
turns a lighter orange-auburn toward the spiky tips, with clear strand lines. The hair mesh
(tools/make_caspian_hair_ugc.py) maps V to height on the head: V = 1 at the crown, 0.5 at the
brows, 0 at the nape. This texture runs from the crown at the top to the tips at the bottom; U
runs across the head, and vertical strand streaks and darker clump grooves give the locks
detail. Our own texture, drawn with PIL.

    python -I assets/hair/make_caspian_hair_texture.py
"""

import math
import random
from pathlib import Path

from PIL import Image

W, H = 256, 1024
OUT = Path(__file__).with_name("caspian_hair_texture.png")

ROOT = (96, 40, 20)
MID = (158, 74, 38)
TIP = (204, 110, 56)
SHINE = (232, 150, 92)


def lerp(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def smooth(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)


def main():
    rng = random.Random(4242)
    # Per-column strand streaks (fine lines) and wider clump grooves (darker valleys).
    streak = [0.0] * W
    for _ in range(70):
        x = rng.randrange(W)
        amount = rng.uniform(-0.2, 0.25)
        for dx in range(-1, 2):
            streak[(x + dx) % W] += amount * (1 - abs(dx) * 0.5)
    for _ in range(9):
        x = rng.randrange(W)
        for dx in range(-6, 7):
            streak[(x + dx) % W] -= 0.18 * math.cos(dx / 6 * math.pi / 2)
    img = Image.new("RGB", (W, H))
    px = img.load()
    for row in range(H):
        v = 1 - row / (H - 1)  # 1 at the top (crown), 0 at the bottom (tips)
        # Roots darker, a mid auburn through the bangs, lighter toward the tips.
        base = lerp(ROOT, MID, smooth((0.95 - v) / 0.3))
        base = lerp(base, TIP, smooth((0.45 - v) / 0.4))
        shine = math.exp(-((v - 0.74) / 0.07) ** 2) * 0.55
        for col in range(W):
            c = lerp(base, SHINE, shine)
            k = 1 + streak[col]
            px[col, row] = tuple(max(0, min(255, round(ch * k))) for ch in c)
    img.save(OUT)
    print(OUT)


if __name__ == "__main__":
    main()
