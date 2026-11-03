"""Generates Morrigan's face decal (assets/faces/hero_morrigan_face.png).

Derived from make_han_face.py.

A transparent 512x512 PNG in the Roblox face-decal layout: a grim veteran knight. Thick
scowling brows, heavy lids over steel-grey irises, a furrow between the brows, cheek lines,
a firm downturned mouth and a goatee. Drawn at 4x and downsampled.

    python -I assets/faces/make_morrigan_face.py
"""

from pathlib import Path

from PIL import Image, ImageChops, ImageDraw

SIZE = 512
S = 4  # supersampling factor
W = SIZE * S

OUT = Path(__file__).with_name("hero_morrigan_face.png")
PREVIEW = Path(__file__).with_name("hero_morrigan_face_preview.png")

INK = (22, 16, 16, 255)
IRIS_TOP = (40, 42, 50)
IRIS_BOTTOM = (130, 134, 146)
PUPIL = (16, 8, 6, 255)
SCLERA = (252, 250, 247, 255)
LID = (70, 40, 34, 200)
NOSE = (150, 92, 70, 150)
MOUTH = (58, 34, 30, 255)
BEARD = (20, 18, 20, 255)
LINES = (130, 90, 70, 150)


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
    top = bezier(outer, (150, 244), inner)
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
    d.ellipse([(cx - rx) * S, (cy - ry) * S, (cx + rx) * S, (cy + ry) * S], outline=(30, 12, 10, 255), width=3 * S)
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

    # Lower lid: thin line along the outer two thirds.
    lower = bezier(outer, (130, 288), (176, 290), 12)
    ImageDraw.Draw(img).line(sc(m(lower)), fill=LID, width=3 * S, joint="curve")

    # Lid crease just above the lash line.
    crease = bezier((112, 230), (156, 214), (200, 238), 12)
    ImageDraw.Draw(img).line(sc(m(crease)), fill=(70, 40, 34, 150), width=3 * S, joint="curve")


def brow(img, flip):
    m = mirror if flip else (lambda p: p)
    # Inner end lower than the outer end: a determined, slightly angry set.
    shape = [(86, 198), (150, 196), (240, 232), (236, 252), (150, 216), (94, 214)]
    ImageDraw.Draw(img).polygon(sc(m(shape)), fill=INK)


def main():
    img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    for flip in (False, True):
        brow(img, flip)
        eye(img, flip)

    d = ImageDraw.Draw(img)
    # Nose: a short shaded stroke on one side with a small hook at the base.
    d.line(sc([(266, 298), (270, 330), (258, 338)]), fill=NOSE, width=4 * S, joint="curve")
    # Mouth: short, flat and slightly turned down at the ends, with a faint lip shadow.
    d.line(sc(bezier((228, 392), (256, 382), (284, 392), 12)), fill=MOUTH, width=5 * S, joint="curve")
    d.line(sc([(246, 398), (268, 398)]), fill=(120, 70, 56, 90), width=3 * S)

    # Scowl furrow between the brows.
    d.line(sc([(248, 228), (252, 252)]), fill=LINES, width=3 * S)
    d.line(sc([(266, 228), (262, 252)]), fill=LINES, width=3 * S)
    # Weathered cheek lines.
    for flip in (False, True):
        pts = [(150, 318), (162, 352)]
        if flip:
            pts = mirror(pts)
        d.line(sc(pts), fill=LINES, width=3 * S)
    # Goatee: a patch under the lip down to the chin, with thin lines along the jaw.
    d.polygon(sc([(242, 404), (270, 404), (276, 436), (256, 452), (236, 436)]), fill=BEARD)
    d.line(sc(bezier((228, 396), (228, 424), (240, 446), 10)), fill=BEARD, width=4 * S, joint="curve")
    d.line(sc(bezier((284, 396), (284, 424), (272, 446), 10)), fill=BEARD, width=4 * S, joint="curve")

    face = img.resize((SIZE, SIZE), Image.LANCZOS)
    face.save(OUT)

    # Preview on Morrigan's skin tone (not used in game).
    preview = Image.new("RGBA", (SIZE, SIZE), (226, 186, 150, 255))
    preview.alpha_composite(face)
    preview.save(PREVIEW)
    print(OUT, PREVIEW)


if __name__ == "__main__":
    main()
