"""Generates Velkist's face decal (assets/faces/hero_velkist_face.png).

A transparent 512x512 PNG in the Roblox face-decal layout: a sly, cocky rogue. Sharp
brows pinched toward the nose, half-lidded eyes with violet irises, a short nose stroke
and a crooked grin showing the upper teeth, higher on the viewer's right. Drawn at 4x and
downsampled for clean edges.

    python -I assets/faces/make_velkist_face.py
"""

from pathlib import Path

from PIL import Image, ImageChops, ImageDraw

SIZE = 512
S = 4
W = SIZE * S

OUT = Path(__file__).with_name("hero_velkist_face.png")
PREVIEW = Path(__file__).with_name("hero_velkist_face_preview.png")

INK = (24, 16, 22, 255)
IRIS_TOP = (48, 26, 92)
IRIS_BOTTOM = (150, 120, 220)
PUPIL = (18, 10, 28, 255)
SCLERA = (252, 250, 250, 255)
LID = (70, 40, 50, 200)
NOSE = (150, 92, 70, 150)
MOUTH = (48, 22, 24, 255)
TEETH = (250, 248, 244, 255)


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
    outer, inner = (100, 252), (212, 270)
    # Very flat, heavy lid: a sly half-lidded look.
    top = bezier(outer, (152, 242), inner)
    bottom = bezier(inner, (160, 298), outer)

    mask = Image.new("L", (W, W), 0)
    ImageDraw.Draw(mask).polygon(sc(m(top + bottom)), fill=255)
    img.paste(Image.new("RGBA", (W, W), SCLERA), (0, 0), mask)

    # Irises glance slightly toward the viewer's right.
    cx = (SIZE - 168 + 6) if flip else (168 + 6)
    cy = 270
    iris = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    d = ImageDraw.Draw(iris)
    rx, ry = 26, 30
    for row in range(-ry, ry + 1):
        t = (row + ry) / (2 * ry)
        col = tuple(round(IRIS_TOP[i] + (IRIS_BOTTOM[i] - IRIS_TOP[i]) * t) for i in range(3)) + (255,)
        half = rx * (1 - (row / ry) ** 2) ** 0.5
        d.rectangle([(cx - half) * S, (cy + row) * S, (cx + half) * S, (cy + row + 1) * S], fill=col)
    d.ellipse([(cx - rx) * S, (cy - ry) * S, (cx + rx) * S, (cy + ry) * S], outline=(30, 14, 40, 255), width=3 * S)
    d.ellipse([(cx - 11) * S, (cy - 13) * S, (cx + 11) * S, (cy + 13) * S], fill=PUPIL)
    d.ellipse([(cx - 15) * S, (cy - 15) * S, (cx - 3) * S, (cy - 3) * S], fill=(255, 255, 255, 255))
    d.ellipse([(cx + 7) * S, (cy + 8) * S, (cx + 12) * S, (cy + 13) * S], fill=(255, 255, 255, 220))
    iris.putalpha(ImageChops.multiply(iris.getchannel("A"), mask))
    img.alpha_composite(iris)

    thick = []
    for i, (x, y) in enumerate(top):
        t = i / (len(top) - 1)
        thick.append((x, y - (16 - 10 * t)))
    lash = top + list(reversed(thick)) + [(86, 246), (94, 262)]
    ImageDraw.Draw(img).polygon(sc(m(lash)), fill=INK)

    lower = bezier(outer, (132, 286), (178, 288), 12)
    ImageDraw.Draw(img).line(sc(m(lower)), fill=LID, width=3 * S, joint="curve")
    crease = bezier((114, 236), (158, 224), (200, 244), 12)
    ImageDraw.Draw(img).line(sc(m(crease)), fill=(70, 40, 50, 140), width=3 * S, joint="curve")


def brow(img, flip):
    m = mirror if flip else (lambda p: p)
    # Pinched toward the nose and kinked: cocky rather than angry.
    shape = [(92, 210), (140, 198), (238, 226), (234, 240), (140, 214), (98, 222)]
    ImageDraw.Draw(img).polygon(sc(m(shape)), fill=INK)


def main():
    img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    for flip in (False, True):
        brow(img, flip)
        eye(img, flip)
    d = ImageDraw.Draw(img)
    # Furrow between the brows.
    d.line(sc([(246, 232), (250, 250)]), fill=(120, 70, 56, 120), width=3 * S)
    d.line(sc([(266, 232), (262, 250)]), fill=(120, 70, 56, 120), width=3 * S)
    # Nose.
    d.line(sc([(266, 300), (272, 332), (258, 340)]), fill=NOSE, width=4 * S, joint="curve")

    # Crooked grin: upper lip line rising to the viewer's right, teeth below it, a lower
    # lip curve, and a smirk tick at the high corner.
    upper = bezier((214, 378), (262, 384), (310, 360), 20)
    lower = bezier((310, 360), (270, 436), (214, 378), 20)
    d.polygon(sc(upper + lower), fill=MOUTH)
    teeth_low = bezier((310, 362), (266, 418), (216, 380), 20)
    d.polygon(sc(upper + teeth_low), fill=TEETH)
    d.line(sc(upper), fill=MOUTH, width=5 * S, joint="curve")
    d.line(sc([(310, 360), (320, 350)]), fill=MOUTH, width=4 * S)
    d.line(sc([(262, 384), (264, 404)]), fill=(200, 196, 192, 255), width=2 * S)

    face = img.resize((SIZE, SIZE), Image.LANCZOS)
    face.save(OUT)
    preview = Image.new("RGBA", (SIZE, SIZE), (240, 200, 160, 255))
    preview.alpha_composite(face)
    preview.save(PREVIEW)
    print(OUT)


if __name__ == "__main__":
    main()
