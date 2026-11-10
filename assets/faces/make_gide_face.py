"""Generates Gide's face decal (assets/faces/hero_gide_face.png).

A transparent 512x512 PNG in the Roblox face-decal layout: stern, battle-hardened veteran
miner look with thick dark-brown angled brows, focused half-lidded brown eyes, a small
under-eye scar on his right cheek and a vertical scar on his left cheek, a shaded nose
stroke and a firm downturned mouth. Drawn at 4x and downsampled for clean edges.

    python -I assets/faces/make_gide_face.py
"""

from pathlib import Path

from PIL import Image, ImageChops, ImageDraw

SIZE = 512
S = 4  # supersampling factor
W = SIZE * S

OUT = Path(__file__).with_name("hero_gide_face.png")
PREVIEW = Path(__file__).with_name("hero_gide_face_preview.png")

INK = (24, 16, 14, 255)
BROW = (42, 30, 24, 255)
IRIS_TOP = (44, 26, 18)
IRIS_BOTTOM = (128, 82, 54)
PUPIL = (16, 10, 8, 255)
SCLERA = (252, 250, 247, 255)
LID = (72, 44, 36, 205)
NOSE = (148, 92, 68, 155)
MOUTH = (58, 34, 28, 255)
SCAR = (142, 86, 64, 185)
SCAR_HI = (248, 214, 180, 110)


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
    outer, inner = (96, 250), (214, 270)
    # A flat, heavy upper lid that cuts off the top of the iris (focused, veteran glare).
    top = bezier(outer, (150, 236), inner)
    bottom = bezier(inner, (160, 298), outer)

    # Sclera mask (sharp almond shape).
    mask = Image.new("L", (W, W), 0)
    ImageDraw.Draw(mask).polygon(sc(m(top + bottom)), fill=255)
    img.paste(Image.new("RGBA", (W, W), SCLERA), (0, 0), mask)

    # Iris with a vertical gradient, pupil and highlights, clipped to the sclera.
    cx, cy = (SIZE - 162, 264) if flip else (162, 264)
    iris = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    d = ImageDraw.Draw(iris)
    rx, ry = 27, 30
    for row in range(-ry, ry + 1):
        t = (row + ry) / (2 * ry)
        col = tuple(round(IRIS_TOP[i] + (IRIS_BOTTOM[i] - IRIS_TOP[i]) * t) for i in range(3)) + (255,)
        half = rx * (1 - (row / ry) ** 2) ** 0.5
        d.rectangle([(cx - half) * S, (cy + row) * S, (cx + half) * S, (cy + row + 1) * S], fill=col)
    d.ellipse([(cx - rx) * S, (cy - ry) * S, (cx + rx) * S, (cy + ry) * S], outline=(28, 14, 10, 255), width=3 * S)
    d.ellipse([(cx - 12) * S, (cy - 13) * S, (cx + 12) * S, (cy + 13) * S], fill=PUPIL)
    hx = cx - 9 if not flip else cx + 9
    d.ellipse([(hx - 7) * S, (cy - 18) * S, (hx + 7) * S, (cy - 4) * S], fill=(255, 255, 255, 255))
    lx = cx + 10 if not flip else cx - 10
    d.ellipse([(lx - 3) * S, (cy + 10) * S, (lx + 3) * S, (cy + 16) * S], fill=(255, 255, 255, 220))
    iris_alpha = ImageChops.multiply(iris.getchannel("A"), mask)
    iris.putalpha(iris_alpha)
    img.alpha_composite(iris)

    # Upper lash line: thick, heavier at the outer corner, with a sharp outer wing.
    thick = []
    for i, (x, y) in enumerate(top):
        t = i / (len(top) - 1)  # 0 outer -> 1 inner
        thick.append((x, y - (15 - 9 * t)))
    lash = top + list(reversed(thick)) + [(85, 245), (91, 261)]
    ImageDraw.Draw(img).polygon(sc(m(lash)), fill=INK)

    # Lower lid: crisp line along the outer two thirds.
    lower = bezier(outer, (132, 287), (182, 289), 12)
    ImageDraw.Draw(img).line(sc(m(lower)), fill=LID, width=3 * S, joint="curve")

    # Lid crease just above the lash line.
    crease = bezier((110, 230), (156, 215), (200, 238), 12)
    ImageDraw.Draw(img).line(sc(m(crease)), fill=(72, 44, 36, 150), width=3 * S, joint="curve")


def brow(img, flip):
    m = mirror if flip else (lambda p: p)
    # Thick dark-brown brow angled sharply down toward the bridge of the nose.
    shape = [(88, 198), (150, 196), (238, 228), (233, 246), (148, 214), (95, 213)]
    ImageDraw.Draw(img).polygon(sc(m(shape)), fill=BROW)


def scars(d):
    # Right under-eye scar (viewer's left): a short horizontal/diagonal mark below the outer lower lid.
    d.line(sc([(110, 297), (138, 293)]), fill=SCAR, width=3 * S, joint="curve")
    d.line(sc([(123, 289), (121, 301)]), fill=SCAR, width=2 * S)
    # Left cheek scar (viewer's right): vertical battle scar down the cheekbone, as in the reference art.
    d.line(sc(bezier((368, 316), (373, 342), (371, 370), 12)), fill=SCAR, width=4 * S, joint="curve")
    d.line(sc(bezier((371, 317), (376, 342), (374, 369), 12)), fill=SCAR_HI, width=2 * S, joint="curve")


def main():
    img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    for flip in (False, True):
        brow(img, flip)
        eye(img, flip)

    d = ImageDraw.Draw(img)
    scars(d)
    # Nose: a short shaded stroke on one side with a small hook at the base.
    d.line(sc([(265, 298), (269, 330), (257, 338)]), fill=NOSE, width=4 * S, joint="curve")
    # Mouth: firm, slightly downturned veteran frown with a faint lower-lip shadow.
    d.line(sc(bezier((222, 389), (256, 381), (290, 389), 12)), fill=MOUTH, width=5 * S, joint="curve")
    d.line(sc([(244, 399), (270, 399)]), fill=(120, 70, 56, 95), width=3 * S)

    face = img.resize((SIZE, SIZE), Image.LANCZOS)
    face.save(OUT)

    # Preview on Gide's skin tone (not used in game).
    preview = Image.new("RGBA", (SIZE, SIZE), (236, 196, 158, 255))
    preview.alpha_composite(face)
    preview.save(PREVIEW)
    print(OUT, PREVIEW)


if __name__ == "__main__":
    main()
