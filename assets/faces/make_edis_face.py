"""Generates Edis Callen's face decal (assets/faces/hero_edis_face.png).

Derived from make_astrea_face.py. A transparent 512x512 PNG in the Roblox face-decal layout: a
cool, aloof rogue. Half-lidded amber eyes under heavy black lashes, low nearly straight black
brows, no blush, and a small flat mouth.

    python assets/faces/make_edis_face.py
"""

from pathlib import Path
from PIL import Image, ImageDraw

SIZE = 512
S = 4  # supersampling factor
W = SIZE * S

OUT = Path(__file__).with_name("hero_edis_face.png")
PREVIEW = Path(__file__).with_name("hero_edis_face_preview.png")

# Amber eyes and black hair, from her card art and render
INK = (22, 16, 16, 255)            # Near-black ink
IRIS_TOP = (64, 34, 16)            # Dark bronze under the lid
IRIS_MID = (150, 88, 38)           # Amber
IRIS_BOTTOM = (226, 168, 92)       # Warm honey
IRIS_RIM = (46, 24, 12, 255)       # Outer limbal ring
PUPIL = (28, 14, 12, 255)          # Deep warm chocolate
SCLERA = (252, 250, 248, 255)      # Warm white
LID = (20, 16, 18, 245)            # Heavy black lash line
LID_CREASE = (110, 70, 60, 120)    # Eyelid fold
NOSE = (160, 95, 75, 140)          # Soft warm nose shadow
MOUTH_LIP = (58, 26, 22, 255)      # Smirk outline
MOUTH_CAVITY = (68, 24, 28, 255)   # Inside mouth shadow
TEETH = (255, 252, 248, 255)       # Clean upper teeth slit
BROW = (26, 22, 26, 255)           # Black hair match
BLUSH = (235, 140, 110, 30)         # Soft cheerful anime blush


def sc(points):
    return [(x * S, y * S) for x, y in points]


def bezier(p0, p1, p2, steps=28):
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
    # Positions calibrated for 1.2-stud head viewed under curtain bangs
    outer, inner = (102, 248), (218, 266)

    # Almond shape anime eye with slight upward tilt at outer corner
    top = bezier(outer, (156, 240), inner)
    bottom = bezier(inner, (162, 298), outer)

    # Sclera mask
    mask = Image.new("L", (W, W), 0)
    ImageDraw.Draw(mask).polygon(sc(m(top + bottom)), fill=255)
    img.paste(Image.new("RGBA", (W, W), SCLERA), (0, 0), mask)

    # Iris with 3-stop warm golden gradient, pupil, rim, and highlights
    cx, cy = (SIZE - 162, 262) if flip else (162, 262)
    iris = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    d = ImageDraw.Draw(iris)
    rx, ry = 28, 33

    for row in range(-ry, ry + 1):
        t = (row + ry) / (2 * ry)
        if t < 0.45:
            # Upper: top to mid
            t_sub = t / 0.45
            col = tuple(round(IRIS_TOP[i] + (IRIS_MID[i] - IRIS_TOP[i]) * t_sub) for i in range(3)) + (255,)
        else:
            # Lower: mid to bright yellow-gold
            t_sub = (t - 0.45) / 0.55
            col = tuple(round(IRIS_MID[i] + (IRIS_BOTTOM[i] - IRIS_MID[i]) * t_sub) for i in range(3)) + (255,)

        half = rx * (1 - (row / ry) ** 2) ** 0.5
        d.line(
            [((cx - half) * S, (cy + row) * S), ((cx + half) * S, (cy + row) * S)],
            fill=col,
            width=S,
        )

    # Limbal ring
    d.ellipse(
        [((cx - rx) * S, (cy - ry) * S), ((cx + rx) * S, (cy + ry) * S)],
        outline=IRIS_RIM,
        width=int(2.2 * S),
    )

    # Pupil (warm dark chocolate oval)
    prx, pry = 10, 15
    d.ellipse(
        [((cx - prx) * S, (cy - pry + 1) * S), ((cx + prx) * S, (cy + pry + 1) * S)],
        fill=PUPIL,
    )

    # Secondary lower iris caustic / glow arc
    glow_y = cy + 12
    d.arc(
        [((cx - 20) * S, (glow_y - 10) * S), ((cx + 20) * S, (glow_y + 10) * S)],
        start=20,
        end=160,
        fill=(255, 205, 130, 190),
        width=int(2.5 * S),
    )

    # Primary white sparkle catchlight (upper left of pupil)
    hl_x, hl_y = (cx + 8, cy - 8) if flip else (cx - 8, cy - 8)
    d.ellipse(
        [((hl_x - 6.5) * S, (hl_y - 8.5) * S), ((hl_x + 6.5) * S, (hl_y + 8.5) * S)],
        fill=(255, 255, 255, 245),
    )

    # Small secondary glimmer (lower right of iris)
    s2_x, s2_y = (cx - 10, cy + 9) if flip else (cx + 10, cy + 9)
    d.ellipse(
        [((s2_x - 3) * S, (s2_y - 3) * S), ((s2_x + 3) * S, (s2_y + 3) * S)],
        fill=(255, 255, 255, 180),
    )

    img.paste(iris, (0, 0), mask)

    # Upper lash line & delicate wing
    d_main = ImageDraw.Draw(img)
    d_main.line(sc(m(top)), fill=LID, width=int(5.4 * S), joint="curve")

    # Outer corner eyelash flick
    flick_end = (outer[0] - 12, outer[1] - 5)
    d_main.line(sc(m([outer, flick_end])), fill=LID, width=int(3.2 * S))

    # Inner eye corner dot
    inner_flick = (inner[0] + 3, inner[1] + 3)
    d_main.line(sc(m([inner, inner_flick])), fill=LID, width=int(2.2 * S))

    # Lower lash line (subtle, delicate)
    bot_pts = bezier(inner, (162, 298), outer)
    # take lower mid portion
    d_main.line(sc(m(bot_pts[6:22])), fill=LID, width=int(1.8 * S))

    # Eyelid crease above eye
    crease = bezier((outer[0] + 8, outer[1] - 10), (158, 226), (inner[0] - 6, inner[1] - 8))
    d_main.line(sc(m(crease)), fill=LID_CREASE, width=int(1.8 * S))


def brow(img, flip):
    """Draws a low, nearly straight black brow, slightly lowered at the inner end."""
    m = mirror if flip else (lambda p: p)
    # Confident arch, slightly lowered at inner corner
    p0 = (94, 214)    # Outer tail
    p1 = (150, 204)   # Gentle peak
    p2 = (214, 224)   # Inner head
    pts = bezier(p0, p1, p2, 24)
    d = ImageDraw.Draw(img)

    # Tapered brow: thicker in center, tapering to outer tail
    for i in range(len(pts) - 1):
        t = i / (len(pts) - 1)
        w = (1.8 + 2.4 * (1.0 - (t - 0.6) ** 2)) * S
        d.line(sc(m([pts[i], pts[i + 1]])), fill=BROW, width=int(w))


def blush(img):
    """Soft peachy cheeks."""
    d = ImageDraw.Draw(img)
    # Left cheek
    d.ellipse(sc([(112, 302), (176, 326)]), fill=BLUSH)
    # Right cheek
    d.ellipse(sc([(SIZE - 176, 302), (SIZE - 112, 326)]), fill=BLUSH)


def freckles(img):
    """Subtle, cute anime freckles across nose bridge and upper cheeks (Patreon ref)."""
    d = ImageDraw.Draw(img)
    FRECKLE_COL = (165, 95, 75, 140)
    FRECKLE_LIGHT = (185, 115, 95, 100)

    dots = [
        # Nose bridge
        (251, 312, 1.8), (258, 310, 1.6), (246, 318, 1.7), (262, 317, 1.9),
        # Right under-eye / upper cheek (viewer's left)
        (192, 308, 1.8), (178, 312, 2.0), (205, 315, 1.6), (168, 318, 1.7),
        (185, 322, 1.9), (198, 325, 1.5), (175, 328, 1.6), (212, 320, 1.4),
        # Left under-eye / upper cheek (viewer's right)
        (316, 306, 1.8), (330, 310, 2.0), (305, 314, 1.6), (342, 316, 1.7),
        (324, 320, 1.9), (312, 324, 1.5), (335, 326, 1.6), (298, 318, 1.4),
    ]

    for x, y, r in dots:
        col = FRECKLE_COL if r >= 1.7 else FRECKLE_LIGHT
        d.ellipse(
            [((x - r) * S, (y - r) * S), ((x + r) * S, (y + r) * S)],
            fill=col,
        )


GLYPH = (120, 190, 255, 255)
CHAIN = (190, 200, 220, 220)


def mouth_and_nose(img):
    """Small flat mouth with a faint lower lip, a short nose stroke."""
    d = ImageDraw.Draw(img)
    d.line(sc([(258, 306), (255, 326)]), fill=NOSE, width=int(2.2 * S))
    d.line(sc(bezier((240, 374), (256, 376), (272, 373))), fill=MOUTH_LIP, width=int(2.6 * S), joint="curve")
    d.line(sc(bezier((248, 388), (256, 390), (264, 388))), fill=(150, 85, 72, 80), width=int(2.0 * S))


def sun_runes(img):
    """Forehead jewel: a four-point star on a fine circlet chain."""
    d = ImageDraw.Draw(img)
    d.line(sc(bezier((150, 150), (256, 182), (362, 150))), fill=CHAIN, width=int(1.6 * S), joint="curve")
    cx, cy = 256, 168
    d.polygon(sc([(cx, cy - 22), (cx + 5, cy - 5), (cx + 18, cy), (cx + 5, cy + 5), (cx, cy + 20), (cx - 5, cy + 5), (cx - 18, cy), (cx - 5, cy - 5)]), fill=GLYPH)
    d.ellipse(sc([(cx - 3, cy - 3), (cx + 3, cy + 3)]), fill=(240, 250, 255, 255))


def main():
    hi = Image.new("RGBA", (W, W), (0, 0, 0, 0))

    eye(hi, flip=False)
    eye(hi, flip=True)
    brow(hi, flip=False)
    brow(hi, flip=True)
    mouth_and_nose(hi)

    # Downsample supersampled drawing
    final = hi.resize((SIZE, SIZE), Image.Resampling.LANCZOS)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    final.save(OUT)
    print(f"Saved: {OUT}")

    # Generate a preview against warm peach skin background
    bg = Image.new("RGBA", (SIZE, SIZE), (232, 196, 160, 255))
    preview = Image.alpha_composite(bg, final)
    preview.save(PREVIEW)
    print(f"Saved: {PREVIEW}")


if __name__ == "__main__":
    main()
