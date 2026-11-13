"""Generates Isabelle's face decal (assets/faces/hero_isabelle_face.png).

A transparent 512x512 PNG in the Roblox face-decal layout: a stern, cool-headed huntress.
Derived from make_aeli_face.py: amber-gold irises under a flat, heavy lid, straight brows in
dark ash angled slightly toward the nose, and a firm, level mouth with no smile or blush. Her
gold-rimmed monocle sits over her left eye (the viewer's right), drawn into the decal so it
always lines up with the eye: a pale lens tint with a glint, a gold rim, and a fine gold chain
running down past the jaw. Drawn at 4x and downsampled for clean edges.

    python -I assets/faces/make_isabelle_face.py
"""

from pathlib import Path

from PIL import Image, ImageChops, ImageDraw

SIZE = 512
S = 4  # supersampling factor
W = SIZE * S

OUT = Path(__file__).with_name("hero_isabelle_face.png")
PREVIEW = Path(__file__).with_name("hero_isabelle_face_preview.png")

INK = (22, 16, 16, 255)
IRIS_TOP = (92, 56, 14)
IRIS_BOTTOM = (226, 170, 72)
BROW = (118, 104, 86, 255)
GOLD = (214, 172, 84, 255)
GOLD_DARK = (150, 110, 46, 255)
PUPIL = (16, 8, 6, 255)
SCLERA = (252, 250, 247, 255)
LID = (70, 40, 34, 200)
NOSE = (150, 92, 70, 150)
MOUTH = (58, 34, 30, 255)


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
    outer, inner = (98, 250), (214, 270)
    # A flat, heavy upper lid that cuts off the top of the iris (half-lidded, focused).
    top = bezier(outer, (150, 234), inner)
    bottom = bezier(inner, (162, 300), outer)

    # Sclera mask (almond shape).
    mask = Image.new("L", (W, W), 0)
    ImageDraw.Draw(mask).polygon(sc(m(top + bottom)), fill=255)
    img.paste(Image.new("RGBA", (W, W), SCLERA), (0, 0), mask)

    # Iris with a vertical gradient, pupil and highlights, clipped to the sclera.
    cx, cy = (SIZE - 162, 264) if flip else (162, 264)
    iris = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    d = ImageDraw.Draw(iris)
    rx, ry = 27, 31
    for row in range(-ry, ry + 1):
        t = (row + ry) / (2 * ry)
        col = tuple(round(IRIS_TOP[i] + (IRIS_BOTTOM[i] - IRIS_TOP[i]) * t) for i in range(3)) + (255,)
        half = rx * (1 - (row / ry) ** 2) ** 0.5
        d.rectangle([(cx - half) * S, (cy + row) * S, (cx + half) * S, (cy + row + 1) * S], fill=col)
    d.ellipse([(cx - rx) * S, (cy - ry) * S, (cx + rx) * S, (cy + ry) * S], outline=(60, 34, 8, 255), width=3 * S)
    d.ellipse([(cx - 12) * S, (cy - 14) * S, (cx + 12) * S, (cy + 14) * S], fill=PUPIL)
    hx = cx - 9 if not flip else cx + 9
    d.ellipse([(hx - 7) * S, (cy - 19) * S, (hx + 7) * S, (cy - 5) * S], fill=(255, 255, 255, 255))
    lx = cx + 10 if not flip else cx - 10
    d.ellipse([(lx - 3) * S, (cy + 10) * S, (lx + 3) * S, (cy + 16) * S], fill=(255, 255, 255, 220))
    iris_alpha = ImageChops.multiply(iris.getchannel("A"), mask)
    iris.putalpha(iris_alpha)
    img.alpha_composite(iris)

    # Upper lash line: thick, heavier at the outer corner, with a short flick past it.
    thick = []
    for i, (x, y) in enumerate(top):
        t = i / (len(top) - 1)  # 0 outer -> 1 inner
        thick.append((x, y - (15 - 9 * t)))
    lash = top + list(reversed(thick)) + [(86, 246), (92, 262)]
    ImageDraw.Draw(img).polygon(sc(m(lash)), fill=INK)
    # Outer-corner lash flicks.
    ImageDraw.Draw(img).line(sc(m([(92, 246), (74, 232)])), fill=INK, width=4 * S)
    ImageDraw.Draw(img).line(sc(m([(104, 238), (90, 222)])), fill=INK, width=3 * S)

    # Lower lid: thin line along the outer two thirds.
    lower = bezier(outer, (130, 288), (176, 290), 12)
    ImageDraw.Draw(img).line(sc(m(lower)), fill=LID, width=3 * S, joint="curve")

    # Lid crease just above the lash line.
    crease = bezier((112, 230), (156, 214), (200, 238), 12)
    ImageDraw.Draw(img).line(sc(m(crease)), fill=(70, 40, 34, 150), width=3 * S, joint="curve")


def brow(img, flip):
    m = mirror if flip else (lambda p: p)
    # Nearly straight and low, dipping toward the nose: stern, not angry.
    shape = [(100, 206), (160, 200), (226, 216), (224, 225), (160, 209), (104, 214)]
    ImageDraw.Draw(img).polygon(sc(m(shape)), fill=BROW)


def monocle(img):
    """Gold-rimmed monocle over her left eye (viewer's right) and its chain down past the jaw."""
    cx, cy, r = SIZE - 158, 266, 57
    lens = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    ld = ImageDraw.Draw(lens)
    ld.ellipse(sc([(cx - r, cy - r), (cx + r, cy + r)]), fill=(200, 226, 255, 40))
    # Glint: a short bright arc in the upper left of the lens.
    ld.arc(sc([(cx - r + 10, cy - r + 10), (cx + r - 10, cy + r - 10)]), 200, 245, fill=(255, 255, 255, 200), width=4 * S)
    img.alpha_composite(lens)
    d = ImageDraw.Draw(img)
    d.ellipse(sc([(cx - r - 3, cy - r - 3), (cx + r + 3, cy + r + 3)]), outline=GOLD_DARK, width=9 * S)
    d.ellipse(sc([(cx - r - 1, cy - r - 1), (cx + r + 1, cy + r + 1)]), outline=GOLD, width=5 * S)
    # Chain: small links from the rim's lower outer edge, curving down past the jaw.
    chain = bezier((cx + 40, cy + 42), (cx + 56, cy + 110), (cx + 48, cy + 206), 18)
    for i, (x, y) in enumerate(chain):
        rad = 3.2 if i % 2 == 0 else 2.4
        d.ellipse(sc([(x - rad, y - rad), (x + rad, y + rad)]), fill=GOLD if i % 2 == 0 else GOLD_DARK)


def main():
    img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    for flip in (False, True):
        brow(img, flip)
        eye(img, flip)

    d = ImageDraw.Draw(img)
    # Nose: a short shaded stroke on one side with a small hook at the base.
    d.line(sc([(266, 298), (270, 330), (258, 338)]), fill=NOSE, width=4 * S, joint="curve")
    # Mouth: a firm, level line with the corners pressed down a touch, and a small lower lip.
    d.line(sc(bezier((238, 386), (259, 382), (280, 387), 14)), fill=(110, 52, 50, 255), width=4 * S, joint="curve")
    d.line(sc([(250, 398), (268, 398)]), fill=(190, 110, 100, 100), width=3 * S)

    monocle(img)

    face = img.resize((SIZE, SIZE), Image.LANCZOS)
    face.save(OUT)

    # Preview on Isabelle's skin tone (not used in game).
    preview = Image.new("RGBA", (SIZE, SIZE), (232, 192, 158, 255))
    preview.alpha_composite(face)
    preview.save(PREVIEW)
    print(OUT, PREVIEW)


if __name__ == "__main__":
    main()
