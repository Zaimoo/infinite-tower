"""Generates Rhyman's face decal (assets/faces/hero_rhyman_face.png).

A transparent 512x512 PNG in the Roblox face-decal layout: a scarred berserker enjoying
himself. Heavy dark-gold brows pinched down over narrowed grey-brown eyes, two slashes
across his left brow, a long scar down his right cheek and two short ones on his left, a
crooked grin showing the upper teeth, and a dirty-blond chin beard. Drawn at 4x and
downsampled for clean edges.

    python -I assets/faces/make_rhyman_face.py
"""

from pathlib import Path

from PIL import Image, ImageChops, ImageDraw

SIZE = 512
S = 4  # supersampling factor
W = SIZE * S

OUT = Path(__file__).with_name("hero_rhyman_face.png")
PREVIEW = Path(__file__).with_name("hero_rhyman_face_preview.png")

INK = (24, 16, 14, 255)
BROW = (122, 92, 44, 255)
BEARD = (176, 138, 72, 255)
BEARD_DARK = (128, 96, 48, 255)
TEETH = (250, 247, 240, 255)
IRIS_TOP = (52, 46, 40)
IRIS_BOTTOM = (150, 132, 108)
PUPIL = (16, 10, 8, 255)
SCLERA = (252, 250, 247, 255)
LID = (72, 44, 36, 205)
NOSE = (148, 92, 68, 155)
MOUTH = (58, 34, 28, 255)
SCAR = (158, 78, 66, 215)
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
    top = bezier(outer, (152, 242), inner)
    bottom = bezier(inner, (160, 294), outer)

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
    shape = [(84, 194), (150, 190), (242, 226), (236, 250), (148, 213), (90, 214)]
    ImageDraw.Draw(img).polygon(sc(m(shape)), fill=BROW)


def scars(d):
    def scar(points, width=4):
        d.line(sc(points), fill=SCAR, width=width * S, joint="curve")
        d.line(sc([(x + 3, y + 1) for x, y in points]), fill=SCAR_HI, width=2 * S, joint="curve")

    # Two slashes across his left brow (viewer's right), running down past the eye.
    scar(bezier((372, 170), (366, 206), (356, 238), 12))
    scar(bezier((398, 176), (392, 208), (384, 236), 12), 3)
    # A long scar down his right cheek (viewer's left), from under the eye to the jaw.
    scar(bezier((128, 300), (140, 344), (132, 392), 14))
    # Two short cuts on his left cheek (viewer's right).
    scar(bezier((372, 312), (382, 334), (378, 358), 10), 3)
    scar(bezier((394, 318), (402, 336), (399, 354), 10), 3)


def beard(d):
    # Chin beard: a soft patch under the mouth with stubble strokes fanning down from it.
    d.pieslice([222 * S, 404 * S, 290 * S, 492 * S], 0, 180, fill=BEARD)
    for x0, x1 in ((234, 232), (245, 244), (256, 256), (267, 268), (278, 280)):
        d.line(sc([(x0, 452), (x1, 484 - abs(x0 - 256) * 0.55)]), fill=BEARD_DARK, width=2 * S)
    # Soul patch joining the lip to the beard.
    d.polygon(sc([(246, 414), (266, 414), (262, 432), (250, 432)]), fill=BEARD)


def grin(d):
    # Crooked grin, higher on the viewer's right: lip line, teeth, lower lip.
    upper = bezier((204, 384), (258, 392), (318, 362), 20)
    lower = bezier((318, 362), (270, 422), (212, 390), 20)
    d.polygon(sc(upper + lower), fill=TEETH)
    d.line(sc(upper), fill=MOUTH, width=5 * S, joint="curve")
    d.line(sc(lower), fill=MOUTH, width=4 * S, joint="curve")
    # The bite line and three tooth gaps.
    d.line(sc(bezier((214, 388), (262, 404), (312, 368), 16)), fill=(150, 120, 110, 200), width=2 * S, joint="curve")
    for x, y0, y1 in ((240, 389, 403), (264, 389, 407), (288, 383, 399)):
        d.line(sc([(x, y0), (x + 1, y1)]), fill=(150, 120, 110, 200), width=2 * S)
    # The corner of the mouth, pulled up into the cheek.
    d.line(sc(bezier((318, 362), (328, 356), (331, 346), 8)), fill=MOUTH, width=4 * S, joint="curve")


def main():
    img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    for flip in (False, True):
        brow(img, flip)
        eye(img, flip)

    d = ImageDraw.Draw(img)
    scars(d)
    # Nose: a short shaded stroke on one side with a small hook at the base.
    d.line(sc([(265, 298), (269, 330), (257, 338)]), fill=NOSE, width=4 * S, joint="curve")
    beard(d)
    grin(d)

    face = img.resize((SIZE, SIZE), Image.LANCZOS)
    face.save(OUT)

    # Preview on Rhyman's skin tone (not used in game).
    preview = Image.new("RGBA", (SIZE, SIZE), (236, 192, 152, 255))
    preview.alpha_composite(face)
    preview.save(PREVIEW)
    print(OUT, PREVIEW)


if __name__ == "__main__":
    main()
