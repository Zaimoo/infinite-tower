"""Generates Isabelle's hair texture (assets/hair/isabelle_hair_texture.png).

Her reference art's platinum hair: a slightly deeper ash-gold at the roots, a soft bright shine
near the root, and pale, near-white platinum toward the tips, with fine strand lines and darker
clump grooves. The hair mesh (tools/make_isabelle_hair_ugc.py) maps every lock and every braid
plait along its own length (V from 1 at the root to 0 at the tip, U across), so the strands
follow the hair. Our own texture, drawn with PIL.

    python -I assets/hair/make_isabelle_hair_texture.py
"""

import math
import random
from pathlib import Path

from PIL import Image

W, H = 256, 1024
OUT = Path(__file__).with_name("isabelle_hair_texture.png")

ROOT = (176, 166, 146)
MID = (226, 220, 204)
TIP = (246, 243, 234)
SHINE = (255, 255, 250)


def lerp(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def smooth(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)


def main():
    rng = random.Random(1717)
    streak = [0.0] * W
    for _ in range(70):
        x = rng.randrange(W)
        amount = rng.uniform(-0.1, 0.08)
        for dx in range(-1, 2):
            streak[(x + dx) % W] += amount * (1 - abs(dx) * 0.5)
    for _ in range(9):
        x = rng.randrange(W)
        for dx in range(-6, 7):
            streak[(x + dx) % W] -= 0.1 * math.cos(dx / 6 * math.pi / 2)
    img = Image.new("RGB", (W, H))
    px = img.load()
    for row in range(H):
        v = 1 - row / (H - 1)  # 1 at the top (root), 0 at the bottom (tip)
        base = lerp(ROOT, MID, smooth((0.98 - v) / 0.3))
        base = lerp(base, TIP, smooth((0.5 - v) / 0.45))
        shine = math.exp(-((v - 0.78) / 0.07) ** 2) * 0.6
        for col in range(W):
            c = lerp(base, SHINE, shine)
            k = 1 + streak[col]
            px[col, row] = tuple(max(0, min(255, round(ch * k))) for ch in c)
    img.save(OUT)
    print(OUT)


if __name__ == "__main__":
    main()
