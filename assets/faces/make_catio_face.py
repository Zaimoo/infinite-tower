"""Generates Catio's face decal (assets/faces/hero_catio_face.png).

A transparent 512x512 PNG in the Roblox face-decal layout:
Stoic, calm, slightly half-lidded anime eyes with slate/navy-to-steel-blue irises,
straight low dark indigo eyebrows, small delicate nose shadow, and a calm, firm mouth.
Drawn at 4x and downsampled with high-quality antialiasing.

    python assets/faces/make_catio_face.py
"""

from pathlib import Path
from PIL import Image, ImageDraw

SIZE = 512
S = 4  # supersampling factor
W = SIZE * S

OUT = Path(__file__).with_name("hero_catio_face.png")
PREVIEW = Path(__file__).with_name("hero_catio_face_preview.png")

INK = (24, 26, 38, 255)
IRIS_TOP = (28, 38, 64)
IRIS_BOTTOM = (105, 138, 182)
IRIS_RIM = (42, 58, 92, 255)
PUPIL = (14, 16, 26, 255)
SCLERA = (250, 252, 255, 255)
LID = (50, 52, 68, 210)
LID_CREASE = (80, 75, 85, 120)
NOSE = (120, 100, 110, 140)
MOUTH = (50, 42, 48, 255)
BROW = (42, 48, 70, 255)  # dark indigo/navy to match hair


def sc(points):
    return [(x * S, y * S) for x, y in points]


def bezier(p0, p1, p2, steps=24):
    out = []
    for i in range(steps + 1):
        t = i / steps
        a, b, c = (1 - t) ** 2, 2 * (1 - t) * t, t * t
        out.append((a * p0[0] + b * p1[0] + c * p2[0], a * p0[1] + b * p1[1] + c * p2[1]))
    return out


def mirror(points):
    return [(SIZE - x, y) for x, y in points]


def eye(img, flip):
    """Draws one eye; coordinates are for the viewer's left eye, mirrored when flip."""
    m = mirror if flip else (lambda p: p)
    # Positions calibrated for the 1.4-stud head viewed under Catio's low bangs
    outer, inner = (106, 254), (218, 272)
    
    # Flat, heavy upper lid cutting off top of iris (stoic, calm anime look)
    top = bezier(outer, (158, 240), inner)
    bottom = bezier(inner, (166, 302), outer)

    # Sclera mask (almond shape)
    mask = Image.new("L", (W, W), 0)
    ImageDraw.Draw(mask).polygon(sc(m(top + bottom)), fill=255)
    img.paste(Image.new("RGBA", (W, W), SCLERA), (0, 0), mask)

    # Iris with gradient, pupil, rim, and highlight
    cx, cy = (SIZE - 164, 268) if flip else (164, 268)
    iris = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    d = ImageDraw.Draw(iris)
    rx, ry = 26, 30
    for row in range(-ry, ry + 1):
        t = (row + ry) / (2 * ry)
        col = tuple(round(IRIS_TOP[i] + (IRIS_BOTTOM[i] - IRIS_TOP[i]) * t) for i in range(3)) + (255,)
        half = rx * (1 - (row / ry) ** 2) ** 0.5
        d.line(
            [( (cx - half) * S, (cy + row) * S ), ( (cx + half) * S, (cy + row) * S )],
            fill=col,
            width=S,
        )

    # Pupil: vertical oval, deep midnight
    d.ellipse(
        [((cx - 8) * S, (cy - 12) * S), ((cx + 8) * S, (cy + 12) * S)],
        fill=PUPIL,
    )

    # Specular glint (upper-right glint)
    gx, gy = (cx + 8, cy - 8) if not flip else (cx - 8, cy - 8)
    d.ellipse(
        [((gx - 4) * S, (gy - 5) * S), ((gx + 4) * S, (gy + 5) * S)],
        fill=(255, 255, 255, 230),
    )
    # Secondary tiny glint
    gx2, gy2 = (cx - 6, cy + 6) if not flip else (cx + 6, cy + 6)
    d.ellipse(
        [((gx2 - 2) * S, (gy2 - 2) * S), ((gx2 + 2) * S, (gy2 + 2) * S)],
        fill=(210, 230, 255, 160),
    )

    # Clip iris to sclera
    img.paste(iris, (0, 0), mask)

    # Upper eyelid lash line: thick, tapered, dark
    draw = ImageDraw.Draw(img)
    top_scaled = sc(m(top))
    for i in range(len(top_scaled) - 1):
        t_frac = i / (len(top_scaled) - 1)
        # Thickest in the center-outer lash
        thick = int(round(S * (3.8 + 2.0 * math.sin(t_frac * math.pi))))
        draw.line([top_scaled[i], top_scaled[i + 1]], fill=INK, width=thick)

    # Subtle lower lash line
    bot_scaled = sc(m(bottom))
    for i in range(len(bot_scaled) - 1):
        draw.line([bot_scaled[i], bot_scaled[i + 1]], fill=LID, width=int(round(S * 1.5)))

    # Upper eyelid crease line
    crease = bezier((outer[0] + 6, outer[1] - 12), (outer[0] + 50, outer[1] - 22), (inner[0] - 10, inner[1] - 12))
    crease_scaled = sc(m(crease))
    for i in range(len(crease_scaled) - 1):
        draw.line([crease_scaled[i], crease_scaled[i + 1]], fill=LID_CREASE, width=int(round(S * 1.6)))


def brow(draw, flip):
    """Low, straight, slightly angled anime brow matching the dark indigo hair."""
    m = mirror if flip else (lambda p: p)
    # Start inner slightly higher, straight outward, dipping slightly at outer edge
    p0 = (212, 226)  # inner brow
    p1 = (160, 218)  # mid arch
    p2 = (108, 222)  # outer tail
    pts = sc(m(bezier(p0, p1, p2, 18)))
    for i in range(len(pts) - 1):
        t_frac = i / (len(pts) - 1)
        # Thicker at inner/mid, tapering at outer tip
        w = int(round(S * (3.2 * (1.0 - 0.5 * t_frac))))
        draw.line([pts[i], pts[i + 1]], fill=BROW, width=w)


def nose_and_mouth(draw):
    # Nose: tiny subtle shadow line just below eyes
    draw.line(sc([(256, 318), (256, 326)]), fill=NOSE, width=int(round(S * 1.8)))

    # Mouth: calm, firm, neutral/slightly downturned slit
    m0, m1, m2 = (230, 368), (256, 365), (282, 368)
    mouth_pts = sc(bezier(m0, m1, m2, 16))
    for i in range(len(mouth_pts) - 1):
        draw.line([mouth_pts[i], mouth_pts[i + 1]], fill=MOUTH, width=int(round(S * 2.2)))
    # Subtle lower lip shadow dot
    draw.ellipse(sc([(253, 376), (259, 379)]), fill=NOSE)


def main():
    import math
    img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    eye(img, flip=False)
    eye(img, flip=True)

    draw = ImageDraw.Draw(img)
    brow(draw, flip=False)
    brow(draw, flip=True)
    nose_and_mouth(draw)

    # Downsample with Lanczos for smooth subpixel rendering
    final = img.resize((SIZE, SIZE), Image.Resampling.LANCZOS)
    final.save(OUT)
    print(f"Saved {OUT}")

    # Preview on skin tone (#FCE6D4)
    skin_bg = Image.new("RGBA", (SIZE, SIZE), (252, 230, 212, 255))
    skin_bg.alpha_composite(final)
    skin_bg.save(PREVIEW)
    print(f"Saved preview {PREVIEW}")


if __name__ == "__main__":
    import math
    main()
