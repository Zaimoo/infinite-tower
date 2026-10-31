"""Generates Jenna's face decal (assets/faces/hero_jenna_face.png).

A transparent 512x512 PNG in the Roblox face-decal layout:
Spirited, confident, warm anime eyes with dual-tone golden amber irises,
determined crimson eyebrows angled down, delicate nose accent,
and a playful confident smirk parted slightly showing white upper teeth.
Drawn at 4x and downsampled with high-quality antialiasing.

    python assets/faces/make_jenna_face.py
"""

from pathlib import Path
from PIL import Image, ImageDraw

SIZE = 512
S = 4  # supersampling factor
W = SIZE * S

OUT = Path(__file__).with_name("hero_jenna_face.png")
PREVIEW = Path(__file__).with_name("hero_jenna_face_preview.png")

# Palette matching reference image media_1793189724366_18ee5575.jpg
INK = (42, 22, 18, 255)            # Deep warm chestnut ink
IRIS_TOP = (150, 72, 18)           # Rich warm bronze amber
IRIS_MID = (242, 172, 42)          # Vibrant golden amber
IRIS_BOTTOM = (255, 224, 95)       # Radiant pale yellow-gold
IRIS_RIM = (85, 36, 18, 255)       # Outer limbal ring
PUPIL = (28, 14, 12, 255)          # Deep warm chocolate
SCLERA = (252, 250, 248, 255)      # Warm white
LID = (55, 28, 22, 235)            # Eyeliner tone
LID_CREASE = (120, 70, 55, 110)    # Soft eyelid fold
NOSE = (160, 95, 75, 140)          # Soft warm nose shadow
MOUTH_LIP = (58, 26, 22, 255)      # Smirk outline
MOUTH_CAVITY = (68, 24, 28, 255)   # Inside mouth shadow
TEETH = (255, 252, 248, 255)       # Clean upper teeth slit
BROW = (175, 48, 32, 255)          # Crimson hair match
BLUSH = (235, 110, 95, 48)         # Soft cheerful anime blush


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
    top = bezier(outer, (156, 228), inner)
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
        fill=(255, 245, 180, 200),
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
    d_main.line(sc(m(top)), fill=LID, width=int(4.2 * S), joint="curve")

    # Outer corner eyelash flick
    flick_end = (outer[0] - 8, outer[1] - 7)
    d_main.line(sc(m([outer, flick_end])), fill=LID, width=int(3.2 * S))

    # Inner eye corner dot
    inner_flick = (inner[0] + 3, inner[1] + 3)
    d_main.line(sc(m([inner, inner_flick])), fill=LID, width=int(2.2 * S))

    # Lower lash line (subtle, delicate)
    bot_pts = bezier(inner, (162, 298), outer)
    # take lower mid portion
    d_main.line(sc(m(bot_pts[6:22])), fill=LID, width=int(1.8 * S))

    # Eyelid crease above eye
    crease = bezier((outer[0] + 6, outer[1] - 14), (158, 218), (inner[0] - 6, inner[1] - 12))
    d_main.line(sc(m(crease)), fill=LID_CREASE, width=int(1.8 * S))


def brow(img, flip):
    """Draws Jenna's energetic, confident crimson eyebrow."""
    m = mirror if flip else (lambda p: p)
    # Confident arch, slightly lowered at inner corner
    p0 = (92, 212)    # Outer tail
    p1 = (148, 194)   # High arch peak
    p2 = (212, 218)   # Inner head
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


def mouth_and_nose(img):
    """Jenna's signature confident smirk with visible white teeth."""
    d = ImageDraw.Draw(img)

    # Subtle nose shadow dot
    d.ellipse(sc([(253, 316), (259, 322)]), fill=NOSE)

    # Playful, confident smile: slightly asymmetrical smirk, higher on viewer's right
    corner_l = (212, 366)
    corner_r = (298, 356)  # higher on right (viewer right = character left)
    mid_bottom = (252, 382)
    mid_top = (254, 364)

    # Fill inside mouth cavity
    mouth_poly = bezier(corner_l, mid_top, corner_r) + bezier(corner_r, mid_bottom, corner_l)
    d.polygon(sc(mouth_poly), fill=MOUTH_CAVITY)

    # White upper teeth bar across top of smile
    teeth_bottom = bezier((220, 367), (254, 372), (290, 361))
    teeth_poly = bezier(corner_l, mid_top, corner_r) + list(reversed(teeth_bottom))
    d.polygon(sc(teeth_poly), fill=TEETH)

    # Dark mouth outline
    d.line(sc(bezier(corner_l, mid_bottom, corner_r)), fill=MOUTH_LIP, width=int(2.6 * S))
    d.line(sc(bezier(corner_l, mid_top, corner_r)), fill=MOUTH_LIP, width=int(2.2 * S))

    # Corner smirk crease accents
    d.line(sc([(corner_r[0] + 1, corner_r[1] + 2), (corner_r[0] + 5, corner_r[1] - 4)]), fill=MOUTH_LIP, width=int(2.0 * S))
    d.line(sc([(corner_l[0] - 1, corner_l[1] + 2), (corner_l[0] - 4, corner_l[1] - 2)]), fill=MOUTH_LIP, width=int(1.8 * S))

    # Subtle lower lip shadow accent
    d.line(sc(bezier((242, 394), (254, 396), (266, 394))), fill=(130, 75, 65, 120), width=int(2.0 * S))


def main():
    hi = Image.new("RGBA", (W, W), (0, 0, 0, 0))

    blush(hi)
    freckles(hi)
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
    bg = Image.new("RGBA", (SIZE, SIZE), (246, 218, 196, 255))
    preview = Image.alpha_composite(bg, final)
    preview.save(PREVIEW)
    print(f"Saved: {PREVIEW}")


if __name__ == "__main__":
    main()
