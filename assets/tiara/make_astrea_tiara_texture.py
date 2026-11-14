"""Generate a luminous faceted astral-cyan crystal texture for Astrea's tiara crystals."""

import math
import os
from PIL import Image, ImageDraw

OUT_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "astrea_tiara_crystals_texture.png")
W, H = 512, 512

img = Image.new("RGB", (W, H), (36, 210, 212))
px = img.load()

# 6 vertical facet bands across U with alternating cool/bright astral cyan tones
# + vertical root-to-tip crystal luminosity gradient (deep teal root -> radiant aqua -> ice-white apex)
FACET_SHADE = [1.06, 0.86, 0.98, 1.12, 0.88, 0.96]

for y in range(H):
    # v = 1 at top (crystal tip), 0 at bottom (prong root)
    v = 1.0 - (y / (H - 1))
    # Root darkening near base, bright luminous shoulder, crisp ice-cyan highlight toward tip
    if v < 0.22:
        t = v / 0.22
        base_r = 14 + 34 * t
        base_g = 112 + 96 * t
        base_b = 132 + 88 * t
    elif v < 0.72:
        t = (v - 0.22) / 0.50
        base_r = 48 + 72 * t
        base_g = 208 + 40 * t
        base_b = 220 + 30 * t
    else:
        t = (v - 0.72) / 0.28
        base_r = 120 + 115 * (t ** 1.15)
        base_g = 248 + 7 * t
        base_b = 250 + 5 * t

    for x in range(W):
        u = x / W
        f_float = u * 6.0
        f_idx = int(f_float) % 6
        local_u = f_float - int(f_float)

        # Bright crisp edge specular ridge along facet boundaries
        edge_dist = min(local_u, 1.0 - local_u)
        edge_boost = max(0.0, 1.0 - edge_dist / 0.085) ** 2.2

        # Diagonal internal crystal refraction glint
        shimmer = 0.06 * math.sin((u * 3.0 + v * 2.2) * math.pi)
        shade = FACET_SHADE[f_idx] + shimmer

        r = base_r * shade + 85 * edge_boost
        g = base_g * shade + 55 * edge_boost
        b = base_b * shade + 45 * edge_boost

        px[x, y] = (
            max(0, min(255, int(r))),
            max(0, min(255, int(g))),
            max(0, min(255, int(b))),
        )

# Add subtle internal star sparkle glints around mid-upper crystal body
draw = ImageDraw.Draw(img, "RGBA")
for cx_f, cy_f, rad in [(0.18, 0.30, 18), (0.52, 0.24, 22), (0.84, 0.34, 16)]:
    cx, cy = int(cx_f * W), int(cy_f * H)
    draw.ellipse((cx - rad, cy - rad, cx + rad, cy + rad), fill=(235, 255, 255, 55))

img.save(OUT_PATH)
print("Saved crystal texture:", OUT_PATH)
