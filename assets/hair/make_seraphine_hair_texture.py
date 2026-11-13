"""Generates Seraphine's hair texture (assets/hair/seraphine_hair_texture.png).

Her reference art's silver-white hair: cool lavender-grey in the shadowed roots, near-white silver
along the length with a soft bright sheen high on each lock, and fine strand lines and darker
lavender clump grooves so the pale hair keeps its shape. The hair mesh
(tools/make_seraphine_hair_ugc.py) maps every lock and bun coil along its own length (V from 1 at
the root to 0 at the tip, U across), so the strands follow the hair. Our own texture, drawn with
PIL.

    python -I assets/hair/make_seraphine_hair_texture.py
"""

import math
import random
from pathlib import Path

from PIL import Image

W, H = 256, 1024
OUT = Path(__file__).with_name("seraphine_hair_texture.png")

ROOT = (170, 168, 196)
MID = (222, 224, 238)
TIP = (240, 241, 250)
SHINE = (255, 255, 255)
GROOVE = (128, 122, 170)


def lerp(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def smooth(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)


def main():
    rng = random.Random(2312)
    streak = [0.0] * W
    for _ in range(80):
        x = rng.randrange(W)
        amount = rng.uniform(-0.09, 0.06)
        for dx in range(-1, 2):
            streak[(x + dx) % W] += amount * (1 - abs(dx) * 0.5)
    grooves = [0.0] * W
    for _ in range(9):
        x = rng.randrange(W)
        for dx in range(-6, 7):
            grooves[(x + dx) % W] = max(grooves[(x + dx) % W], math.cos(dx / 6 * math.pi / 2))
    img = Image.new("RGB", (W, H))
    px = img.load()
    for row in range(H):
        v = 1 - row / (H - 1)  # 1 at the top (root), 0 at the bottom (tip)
        base = lerp(ROOT, MID, smooth((0.98 - v) / 0.28))
        base = lerp(base, TIP, smooth((0.45 - v) / 0.4))
        shine = math.exp(-((v - 0.76) / 0.08) ** 2) * 0.65
        for col in range(W):
            c = lerp(base, GROOVE, grooves[col] * 0.32 * (1 - 0.6 * shine))
            c = lerp(c, SHINE, shine * (1 - 0.5 * grooves[col]))
            k = 1 + streak[col]
            px[col, row] = tuple(max(0, min(255, round(ch * k))) for ch in c)
    img.save(OUT)
    print(OUT)


if __name__ == "__main__":
    main()
