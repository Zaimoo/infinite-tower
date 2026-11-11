"""Generates Astrea's face decal (assets/faces/hero_astrea_face.png).

Uses the feminine eye() from make_jenna_face.py (tall rounded eyes, winged lash line, large
iris). A transparent 512x512 PNG in the Roblox face-decal layout: a gentle star-gazer. Blue-grey irises, soft silver brows, a teal crystal on the forehead in a
silver circlet, and a soft closed smile.

    python assets/faces/make_astrea_face.py
"""

from pathlib import Path
from PIL import Image, ImageDraw

SIZE = 512
S = 4  # supersampling factor
W = SIZE * S

OUT = Path(__file__).with_name("hero_astrea_face.png")
PREVIEW = Path(__file__).with_name("hero_astrea_face_preview.png")

INK = (42, 22, 18, 255)            # Deep warm chestnut ink
IRIS_TOP = (44, 62, 112)           # Deep night blue under the lid
IRIS_MID = (104, 140, 204)          # Star blue
IRIS_BOTTOM = (196, 224, 255)       # Pale starlight
IRIS_RIM = (34, 44, 84, 255)       # Outer limbal ring
PUPIL = (18, 20, 40, 255)          # Navy pupil
SCLERA = (252, 250, 248, 255)      # Warm white
LID = (44, 38, 62, 240)            # Cool plum-navy liner (silver hair)
LID_CREASE = (118, 96, 120, 100)    # Soft eyelid fold
NOSE = (160, 95, 75, 140)          # Soft warm nose shadow
MOUTH_LIP = (58, 26, 22, 255)      # Smirk outline
MOUTH_CAVITY = (68, 24, 28, 255)   # Inside mouth shadow
TEETH = (255, 252, 248, 255)       # Clean upper teeth slit
BROW = (132, 140, 172, 255)          # Silver-blue hair, a shade darker so it reads on skin
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


# Eye shape, in 512 space for the viewer's left eye (mirrored for the other). A feminine anime
# eye: tall and rounded, a thick upper lash line that thickens into a wing at the outer corner,
# a large iris the lid overlaps a little, and a big catchlight. Tune the look with these numbers
# rather than redrawing: OUTER/INNER set the tilt, TOP_PEAK how open the eye is.
EYE_OUTER = (100, 254)
EYE_INNER = (222, 270)
EYE_TOP_PEAK = (150, 204)      # a touch lower than Jenna's: serene, not wide-eyed
EYE_BOTTOM_PEAK = (166, 316)
IRIS_CENTRE = (163, 265)
IRIS_RADII = (31, 38)
LASH_THICK = (3.5, 10.5)       # upper lash thickness at the inner corner and at the outer corner
BROW_POINTS = ((96, 202), (150, 182), (214, 206))


def eye(img, flip):
    """Draws one eye; coordinates are for the viewer's left eye, mirrored when flip."""
    m = mirror if flip else (lambda p: p)
    outer, inner = EYE_OUTER, EYE_INNER
    top = bezier(outer, EYE_TOP_PEAK, inner, 40)
    bottom = bezier(inner, EYE_BOTTOM_PEAK, outer, 40)

    mask = Image.new("L", (W, W), 0)
    ImageDraw.Draw(mask).polygon(sc(m(top + bottom)), fill=255)
    img.paste(Image.new("RGBA", (W, W), SCLERA), (0, 0), mask)

    cx, cy = IRIS_CENTRE
    if flip:
        cx = SIZE - cx
    rx, ry = IRIS_RADII
    iris = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    d = ImageDraw.Draw(iris)
    for row in range(-ry * S, ry * S + 1):
        t = (row / S + ry) / (2 * ry)
        if t < 0.5:
            u = t / 0.5
            col = tuple(round(IRIS_TOP[i] + (IRIS_MID[i] - IRIS_TOP[i]) * u) for i in range(3)) + (255,)
        else:
            u = (t - 0.5) / 0.5
            col = tuple(round(IRIS_MID[i] + (IRIS_BOTTOM[i] - IRIS_MID[i]) * u) for i in range(3)) + (255,)
        half = rx * (1 - (row / S / ry) ** 2) ** 0.5
        d.line([((cx - half) * S, cy * S + row), ((cx + half) * S, cy * S + row)], fill=col, width=1)
    d.ellipse([((cx - rx) * S, (cy - ry) * S), ((cx + rx) * S, (cy + ry) * S)], outline=IRIS_RIM, width=int(3.0 * S))
    # Pupil, then a bright crescent in the lower iris so the eye glows from below
    prx, pry = rx * 0.36, ry * 0.42
    d.ellipse([((cx - prx) * S, (cy - pry) * S), ((cx + prx) * S, (cy + pry) * S)], fill=PUPIL)
    d.arc([((cx - rx * 0.66) * S, (cy - ry * 0.1) * S), ((cx + rx * 0.66) * S, (cy + ry * 0.78) * S)],
          start=25, end=155, fill=tuple(IRIS_BOTTOM) + (235,), width=int(3.2 * S))
    # Shadow the lid casts on the top of the iris and the white
    shade = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shade)
    lid_shadow = [(x, y + 13) for x, y in top]
    sd.polygon(sc(m(top + list(reversed(lid_shadow)))), fill=(60, 30, 40, 46))
    iris = Image.alpha_composite(iris, Image.composite(shade, Image.new("RGBA", (W, W), (0, 0, 0, 0)), mask))
    d = ImageDraw.Draw(iris)
    # Catchlights: a large one toward the light (upper, viewer's left) and a small one opposite
    hx, hy = cx - rx * 0.36, cy - ry * 0.40
    d.ellipse([((hx - rx * 0.30) * S, (hy - ry * 0.27) * S), ((hx + rx * 0.30) * S, (hy + ry * 0.27) * S)], fill=(255, 255, 255, 250))
    sx, sy = cx + rx * 0.40, cy + ry * 0.36
    d.ellipse([((sx - rx * 0.13) * S, (sy - rx * 0.13) * S), ((sx + rx * 0.13) * S, (sy + rx * 0.13) * S)], fill=(255, 255, 255, 215))
    img.paste(iris, (0, 0), Image.composite(mask, Image.new("L", (W, W), 0), iris.split()[3]))
    img.alpha_composite(Image.composite(shade, Image.new("RGBA", (W, W), (0, 0, 0, 0)), mask))

    d_main = ImageDraw.Draw(img)
    # Upper lash line: a filled band that thickens toward the outer corner, then a two-point wing
    n = len(top)
    upper = []
    for i, (x, y) in enumerate(top):
        t = 1 - i / (n - 1)  # 1 at the outer corner
        upper.append((x - 1.5 * t, y - (LASH_THICK[0] + (LASH_THICK[1] - LASH_THICK[0]) * t ** 1.4)))
    d_main.polygon(sc(m(top + list(reversed(upper)))), fill=LID)
    ox, oy = outer
    wing = bezier((ox + 12, oy - LASH_THICK[1] - 1), (ox - 4, oy - LASH_THICK[1] - 3), (ox - 15, oy - LASH_THICK[1] - 9), 10)
    d_main.polygon(sc(m(wing + bezier((ox - 15, oy - LASH_THICK[1] - 9), (ox - 6, oy - 3), (ox + 6, oy + 1), 10))), fill=LID)
    # Lower lid: only the outer third, so the eye stays soft
    d_main.line(sc(m(bottom[24:38])), fill=LID, width=int(2.0 * S), joint="curve")
    # Eyelid crease, following the lid
    crease = bezier((outer[0] + 14, outer[1] - LASH_THICK[1] - 12), (EYE_TOP_PEAK[0], EYE_TOP_PEAK[1] - 9), (inner[0] - 16, inner[1] - 16))
    d_main.line(sc(m(crease)), fill=LID_CREASE, width=int(1.8 * S), joint="curve")


def brow(img, flip):
    """A slim, softly arched brow that tapers at both ends."""
    m = mirror if flip else (lambda p: p)
    pts = bezier(*BROW_POINTS, 30)
    d = ImageDraw.Draw(img)
    for i in range(len(pts) - 1):
        t = i / (len(pts) - 1)  # 0 at the outer tail, 1 at the inner head
        w = (1.4 + 3.4 * (1 - abs(t - 0.68) / 0.68) ** 0.8) * S
        d.line(sc(m([pts[i], pts[i + 1]])), fill=BROW, width=max(1, int(w)))


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


GLYPH = (80, 232, 214, 255)        # Teal crystal (matches the tiara crystals)
GLYPH_DEEP = (30, 150, 150, 255)
CHAIN = (196, 204, 222, 230)       # Silver circlet


def mouth_and_nose(img):
    """Serene closed mouth, small nose dot."""
    d = ImageDraw.Draw(img)
    d.ellipse(sc([(253, 316), (259, 322)]), fill=NOSE)
    d.line(sc(bezier((236, 370), (256, 382), (276, 370))), fill=MOUTH_LIP, width=int(2.6 * S), joint="curve")
    d.line(sc(bezier((246, 388), (256, 390), (266, 388))), fill=(150, 85, 72, 90), width=int(2.0 * S))


def sun_runes(img):
    """Forehead jewel from her reference art: a silver circlet with a filigree setting and a
    teal crystal diamond in the middle."""
    d = ImageDraw.Draw(img)
    d.line(sc(bezier((140, 152), (256, 186), (372, 152))), fill=CHAIN, width=int(2.0 * S), joint="curve")
    cx, cy = 256, 168
    # Silver filigree curls either side of the setting
    for side in (-1, 1):
        d.line(sc(bezier((cx + side * 14, cy - 2), (cx + side * 30, cy - 14), (cx + side * 38, cy + 2))), fill=CHAIN, width=int(2.2 * S), joint="curve")
    # Silver setting, teal crystal, a darker lower facet and a catchlight
    d.polygon(sc([(cx, cy - 22), (cx + 15, cy), (cx, cy + 24), (cx - 15, cy)]), fill=CHAIN)
    d.polygon(sc([(cx, cy - 17), (cx + 11, cy), (cx, cy + 19), (cx - 11, cy)]), fill=GLYPH)
    d.polygon(sc([(cx - 11, cy), (cx + 11, cy), (cx, cy + 19)]), fill=GLYPH_DEEP)
    d.polygon(sc([(cx - 3, cy - 11), (cx + 1, cy - 13), (cx - 5, cy - 3)]), fill=(240, 255, 252, 255))


def main():
    hi = Image.new("RGBA", (W, W), (0, 0, 0, 0))

    blush(hi)
    eye(hi, flip=False)
    eye(hi, flip=True)
    brow(hi, flip=False)
    brow(hi, flip=True)
    mouth_and_nose(hi)
    sun_runes(hi)

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
