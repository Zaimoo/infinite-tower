"""Generates Vane's face decal (assets/faces/hero_vane_face.png).

A transparent 512x512 PNG in the Roblox face-decal layout: a cold, calculating archmage.
Half-lidded eyes with crimson irises behind rectangular black-framed glasses, dark violet
brows (following his violet hair) with the viewer's right brow raised a little higher, a
short nose stroke and a closed one-sided smirk rising to the viewer's right. Derived from
make_velkist_face.py (the cocky base). Drawn at 4x and downsampled for clean edges.

    python -I assets/faces/make_vane_face.py
"""

from pathlib import Path

from PIL import Image, ImageChops, ImageDraw

SIZE = 512
S = 4
W = SIZE * S

OUT = Path(__file__).with_name("hero_vane_face.png")
PREVIEW = Path(__file__).with_name("hero_vane_face_preview.png")

INK = (22, 14, 26, 255)
BROW = (52, 22, 84, 255)
IRIS_TOP = (96, 12, 22)
IRIS_BOTTOM = (226, 72, 60)
PUPIL = (26, 6, 10, 255)
SCLERA = (252, 250, 250, 255)
LID = (70, 40, 50, 200)
NOSE = (150, 92, 70, 150)
MOUTH = (60, 26, 28, 255)
FRAME = (16, 12, 18, 255)
GLINT = (255, 255, 255, 70)


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
    m = mirror if flip else (lambda p: p)
    outer, inner = (104, 256), (210, 270)
    # Flat, heavy lid: half-lidded and unimpressed.
    top = bezier(outer, (154, 248), inner)
    bottom = bezier(inner, (160, 296), outer)

    mask = Image.new("L", (W, W), 0)
    ImageDraw.Draw(mask).polygon(sc(m(top + bottom)), fill=255)
    img.paste(Image.new("RGBA", (W, W), SCLERA), (0, 0), mask)

    # Irises look straight ahead, a little toward the viewer's right.
    cx = (SIZE - 162 + 4) if flip else (162 + 4)
    cy = 272
    iris = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    d = ImageDraw.Draw(iris)
    rx, ry = 25, 29
    for row in range(-ry, ry + 1):
        t = (row + ry) / (2 * ry)
        col = tuple(round(IRIS_TOP[i] + (IRIS_BOTTOM[i] - IRIS_TOP[i]) * t) for i in range(3)) + (255,)
        half = rx * (1 - (row / ry) ** 2) ** 0.5
        d.rectangle([(cx - half) * S, (cy + row) * S, (cx + half) * S, (cy + row + 1) * S], fill=col)
    d.ellipse([(cx - rx) * S, (cy - ry) * S, (cx + rx) * S, (cy + ry) * S], outline=(46, 8, 14, 255), width=3 * S)
    d.ellipse([(cx - 10) * S, (cy - 12) * S, (cx + 10) * S, (cy + 12) * S], fill=PUPIL)
    d.ellipse([(cx - 14) * S, (cy - 14) * S, (cx - 3) * S, (cy - 3) * S], fill=(255, 255, 255, 255))
    d.ellipse([(cx + 7) * S, (cy + 8) * S, (cx + 11) * S, (cy + 12) * S], fill=(255, 255, 255, 210))
    iris.putalpha(ImageChops.multiply(iris.getchannel("A"), mask))
    img.alpha_composite(iris)

    thick = []
    for i, (x, y) in enumerate(top):
        t = i / (len(top) - 1)
        thick.append((x, y - (14 - 9 * t)))
    lash = top + list(reversed(thick)) + [(92, 250), (98, 264)]
    ImageDraw.Draw(img).polygon(sc(m(lash)), fill=INK)

    lower = bezier(outer, (134, 286), (178, 288), 12)
    ImageDraw.Draw(img).line(sc(m(lower)), fill=LID, width=3 * S, joint="curve")


def brow(img, flip):
    m = mirror if flip else (lambda p: p)
    # Low and nearly straight, angled slightly toward the nose; the viewer's right brow
    # (flip) sits higher: a sceptical, raised brow.
    lift = -10 if flip else 0
    shape = [(96, 212), (150, 200), (232, 222), (229, 234), (150, 214), (100, 224)]
    ImageDraw.Draw(img).polygon(sc(m([(x, y + lift) for x, y in shape])), fill=BROW)


def glasses(img, flip):
    m = mirror if flip else (lambda p: p)
    d = ImageDraw.Draw(img)
    # Rectangular lens: a thicker top bar, thinner sides and bottom.
    left, right, top, bottom = 84, 232, 236, 306
    d.polygon(sc(m([(left, top - 2), (right, top - 2), (right, top + 7), (left, top + 7)])), fill=FRAME)
    d.line(sc(m([(right, top), (right, bottom), (left + 4, bottom), (left, top)])), fill=FRAME, width=5 * S, joint="curve")
    # Temple arm toward the edge of the face.
    d.line(sc(m([(left, top + 4), (52, top + 10)])), fill=FRAME, width=5 * S)
    # Faint diagonal glint across the lens.
    glint = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    ImageDraw.Draw(glint).line(sc(m([(222, 244), (208, 268)])), fill=GLINT, width=6 * S)
    img.alpha_composite(glint)


def main():
    img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    for flip in (False, True):
        eye(img, flip)
        glasses(img, flip)
        brow(img, flip)
    d = ImageDraw.Draw(img)
    # Bridge between the lenses, sitting on the nose.
    d.line(sc([(232, 252), (256, 246), (280, 252)]), fill=FRAME, width=5 * S, joint="curve")
    # Nose.
    d.line(sc([(264, 304), (270, 334), (256, 342)]), fill=NOSE, width=4 * S, joint="curve")

    # Closed smirk: a thin mouth line flat on the viewer's left, curling up on the right,
    # with a small dimple tick at the raised corner.
    smirk = bezier((222, 392), (270, 398), (306, 374), 20)
    d.line(sc(smirk), fill=MOUTH, width=5 * S, joint="curve")
    d.line(sc([(306, 374), (314, 368)]), fill=MOUTH, width=4 * S)
    d.line(sc([(312, 382), (316, 372)]), fill=(120, 70, 56, 140), width=3 * S)

    face = img.resize((SIZE, SIZE), Image.LANCZOS)
    face.save(OUT)
    preview = Image.new("RGBA", (SIZE, SIZE), (226, 178, 138, 255))
    preview.alpha_composite(face)
    preview.save(PREVIEW)
    print(OUT)


if __name__ == "__main__":
    main()
