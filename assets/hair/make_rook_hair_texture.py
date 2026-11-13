"""Generates Rook's hair texture (assets/hair/rook_hair_texture.png).

His reference art's wild rust-copper mane has deep mahogany roots, rich rust-red midtones,
warmer copper-orange tips, and crisp dark strand grooves for cel-shaded UGC hair. Our own
texture, drawn with PIL.

    python -I assets/hair/make_rook_hair_texture.py
"""

import math
import random
from pathlib import Path

from PIL import Image

W, H = 256, 1024
OUT = Path(__file__).with_name("rook_hair_texture.png")

ROOT = (76, 26, 16)
MID = (154, 58, 32)
TIP = (198, 86, 46)
SHINE = (224, 124, 68)


def lerp(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def smooth(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)


def main():
    rng = random.Random(9011)
    streak = [0.0] * W
    for _ in range(85):
        x = rng.randrange(W)
        amount = rng.uniform(-0.22, 0.24)
        for dx in range(-1, 2):
            streak[(x + dx) % W] += amount * (1 - abs(dx) * 0.5)
    for _ in range(11):
        x = rng.randrange(W)
        for dx in range(-6, 7):
            streak[(x + dx) % W] -= 0.2 * math.cos(dx / 6 * math.pi / 2)
    img = Image.new("RGB", (W, H))
    px = img.load()
    for row in range(H):
        v = 1 - row / (H - 1)
        base = lerp(ROOT, MID, smooth((0.95 - v) / 0.3))
        base = lerp(base, TIP, smooth((0.45 - v) / 0.42))
        shine = math.exp(-((v - 0.72) / 0.08) ** 2) * 0.45
        for col in range(W):
            c = lerp(base, SHINE, shine)
            k = 1 + streak[col]
            px[col, row] = tuple(max(0, min(255, round(ch * k))) for ch in c)
    img.save(OUT)
    print(OUT)


if __name__ == "__main__":
    main()
