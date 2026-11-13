"""Generates Nyx's hair texture (assets/hair/nyx_hair_texture.png).

Her reference art has black hair that fades to bright teal toward the ends. The hair mesh
(tools/make_nyx_hair_ugc.py) maps V to height on the head (1 at the crown, 0.5 at the cheeks, 0
at the chin and nape), so every lock turns teal at the same height, and U across each lock, so
the strand lines run along the locks.

Black hair needs its detail drawn in, not multiplied: a brightness multiplier on near-black does
nothing. So the black carries its own strand lines in a cool grey-blue (added, not scaled), darker
grooves between clumps, and a wide blue-black sheen near the crown, the way anime black hair is
drawn; the teal part keeps lighter and darker strands of its own. Our own texture, drawn with PIL.

    python -I assets/hair/make_nyx_hair_texture.py
"""

import math
import random
from pathlib import Path

from PIL import Image

W, H = 256, 1024
OUT = Path(__file__).with_name("nyx_hair_texture.png")

BLACK = (20, 20, 26)
STRAND = (92, 102, 132)  # cool grey-blue strand lines on the black
SHEEN = (96, 108, 140)  # the blue-black sheen band
TEAL = (36, 214, 188)
DEEP_TEAL = (18, 120, 116)


def lerp(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def smooth(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)


def main():
    rng = random.Random(77)
    # Strand lines (0..1 strength per column) and clump grooves (0..1 darkening).
    lines = [0.0] * W
    for _ in range(46):
        x = rng.randrange(W)
        strength = rng.uniform(0.35, 1.0)
        for dx in range(-1, 2):
            lines[(x + dx) % W] = max(lines[(x + dx) % W], strength * (1 - abs(dx) * 0.55))
    grooves = [0.0] * W
    for _ in range(8):
        x = rng.randrange(W)
        for dx in range(-7, 8):
            grooves[(x + dx) % W] = max(grooves[(x + dx) % W], math.cos(dx / 7 * math.pi / 2))
    img = Image.new("RGB", (W, H))
    px = img.load()
    for row in range(H):
        v = 1 - row / (H - 1)  # 1 at the top (crown), 0 at the bottom (ends)
        teal = smooth((0.55 - v) / 0.45)  # black above v 0.55, full teal at v 0.1
        tealColour = lerp(DEEP_TEAL, TEAL, smooth((0.4 - v) / 0.3))
        sheen = math.exp(-((v - 0.78) / 0.09) ** 2)  # a wide band near the crown
        for col in range(W):
            # The black: strand lines added in grey-blue, stronger in the sheen band.
            black = lerp(BLACK, STRAND, lines[col] * (0.5 + 0.5 * sheen))
            black = lerp(black, SHEEN, sheen * 0.45 * (0.5 + 0.5 * lines[col]))
            black = lerp(black, (8, 8, 12), grooves[col] * 0.6)
            # The teal: lighter and darker strands of its own.
            t = lerp(tealColour, (190, 255, 240), lines[col] * 0.25)
            t = lerp(t, (10, 70, 70), grooves[col] * 0.35)
            c = lerp(black, t, teal)
            px[col, row] = tuple(max(0, min(255, round(ch))) for ch in c)
    img.save(OUT)
    print(OUT)


if __name__ == "__main__":
    main()
