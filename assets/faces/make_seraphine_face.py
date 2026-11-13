"""Generates Seraphine's face decal (assets/faces/hero_seraphine_face.png).

A transparent 512x512 PNG in the Roblox face-decal layout: a serene, regal scholar, from her
reference art. Derived from make_isabelle_face.py: violet-blue irises under soft, lowered lids
(calm, not stern), thin arched silver-lilac brows, lilac lid shadow, a small gentle smile with a
touch of rose, and a soft blush. The gilt circlet's centre point and its small glowing gem sit on
the forehead in the decal, so they always line up with the face. Drawn at 4x and downsampled.

    python -I assets/faces/make_seraphine_face.py
"""

from pathlib import Path

from PIL import Image, ImageChops, ImageDraw

SIZE = 512
S = 4  # supersampling factor
W = SIZE * S

OUT = Path(__file__).with_name("hero_seraphine_face.png")
PREVIEW = Path(__file__).with_name("hero_seraphine_face_preview.png")

INK = (34, 26, 52, 255)
IRIS_TOP = (46, 40, 120)
IRIS_BOTTOM = (150, 150, 240)
BROW = (170, 164, 196, 255)
GOLD = (214, 172, 84, 255)
GOLD_DARK = (150, 110, 46, 255)
PUPIL = (22, 16, 44, 255)
SCLERA = (252, 250, 247, 255)
LID = (90, 70, 110, 190)
NOSE = (170, 120, 110, 130)
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
    # A soft, lowered upper lid that rests on the top of the iris (calm, half-lidded).
    top = bezier(outer, (152, 228), inner)
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
    d.ellipse([(cx - rx) * S, (cy - ry) * S, (cx + rx) * S, (cy + ry) * S], outline=(30, 24, 80, 255), width=3 * S)
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
    crease = bezier((112, 226), (156, 208), (200, 234), 12)
    ImageDraw.Draw(img).line(sc(m(crease)), fill=(90, 70, 120, 150), width=3 * S, joint="curve")
    # Lilac lid shadow between the crease and the lashes.
    shadow = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).polygon(sc(m(bezier((100, 238), (156, 206), (212, 252), 16) + list(reversed(bezier((100, 246), (152, 222), (212, 262), 16))))), fill=(150, 120, 200, 90))
    img.alpha_composite(shadow)


def brow(img, flip):
    m = mirror if flip else (lambda p: p)
    # Thin, high and gently arched: serene.
    upper = bezier((104, 200), (150, 172), (222, 194), 16)
    lower = bezier((222, 198), (150, 182), (106, 205), 16)
    shape = upper + lower
    ImageDraw.Draw(img).polygon(sc(m(shape)), fill=BROW)


def circlet(img):
    """The circlet's centre point on the forehead: a gilt chevron with a small glowing gem."""
    d = ImageDraw.Draw(img)
    cx = SIZE / 2
    d.polygon(sc([(cx - 34, 104), (cx, 150), (cx + 34, 104), (cx + 24, 104), (cx, 134), (cx - 24, 104)]), fill=GOLD_DARK)
    d.polygon(sc([(cx - 30, 104), (cx, 144), (cx + 30, 104), (cx + 26, 104), (cx, 138), (cx - 26, 104)]), fill=GOLD)
    glow = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse(sc([(cx - 16, 112), (cx + 16, 144)]), fill=(150, 170, 255, 70))
    img.alpha_composite(glow)
    d.polygon(sc([(cx, 116), (cx + 8, 127), (cx, 140), (cx - 8, 127)]), fill=(120, 150, 255, 255))
    d.polygon(sc([(cx, 119), (cx + 4, 126), (cx, 131), (cx - 3, 126)]), fill=(225, 235, 255, 255))


def blush(img):
    layer = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    ld = ImageDraw.Draw(layer)
    for x in (150, SIZE - 150):
        ld.ellipse(sc([(x - 34, 318), (x + 34, 340)]), fill=(240, 150, 170, 55))
    img.alpha_composite(layer)


def main():
    img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    for flip in (False, True):
        brow(img, flip)
        eye(img, flip)

    d = ImageDraw.Draw(img)
    # Nose: a short shaded stroke on one side with a small hook at the base.
    d.line(sc([(266, 298), (270, 330), (258, 338)]), fill=NOSE, width=4 * S, joint="curve")
    # Mouth: a small, gentle smile with the corners lifted, and a touch of rose below.
    d.line(sc(bezier((236, 382), (258, 394), (282, 381), 14)), fill=(140, 70, 90, 255), width=4 * S, joint="curve")
    d.line(sc([(250, 400), (268, 400)]), fill=(220, 130, 150, 110), width=4 * S)

    blush(img)
    circlet(img)

    face = img.resize((SIZE, SIZE), Image.LANCZOS)
    face.save(OUT)

    # Preview on Seraphine's skin tone (not used in game).
    preview = Image.new("RGBA", (SIZE, SIZE), (240, 214, 196, 255))
    preview.alpha_composite(face)
    preview.save(PREVIEW)
    print(OUT, PREVIEW)


if __name__ == "__main__":
    main()
