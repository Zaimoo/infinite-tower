"""Generates Diran's face decal (assets/faces/hero_diran_face.png).

A transparent 512x512 PNG in the Roblox face-decal layout: calm, composed veteran
healer expression with cool slate-silver angled brows (matching his silver-white hair),
focused slate-grey eyes with crisp dark lash lines, a short shaded nose stroke and a
calm, resolute neutral mouth. Drawn at 4x and downsampled for clean edges.

    python -I assets/faces/make_diran_face.py
"""

from pathlib import Path

from PIL import Image, ImageChops, ImageDraw

SIZE = 512
S = 4  # supersampling factor
W = SIZE * S

OUT = Path(__file__).with_name("hero_diran_face.png")
PREVIEW = Path(__file__).with_name("hero_diran_face_preview.png")

INK = (22, 24, 30, 255)
BROW = (108, 118, 134, 255)
BROW_OUTLINE = (54, 60, 72, 255)
IRIS_TOP = (38, 44, 56)
IRIS_BOTTOM = (108, 120, 136)
PUPIL = (14, 16, 22, 255)
SCLERA = (252, 251, 249, 255)
LID = (72, 62, 58, 190)
NOSE = (148, 94, 72, 150)
MOUTH = (58, 36, 32, 255)


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
    outer, inner = (98, 252), (214, 268)
    # Composed, slightly narrowed upper lid for a calm veteran paladin-healer gaze.
    top = bezier(outer, (152, 238), inner)
    bottom = bezier(inner, (162, 296), outer)

    # Sclera mask (almond shape).
    mask = Image.new("L", (W, W), 0)
    ImageDraw.Draw(mask).polygon(sc(m(top + bottom)), fill=255)
    img.paste(Image.new("RGBA", (W, W), SCLERA), (0, 0), mask)

    # Iris with a vertical gradient, pupil and highlights, clipped to the sclera.
    cx, cy = (SIZE - 160, 264) if flip else (160, 264)
    iris = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    d = ImageDraw.Draw(iris)
    rx, ry = 27, 29
    for row in range(-ry, ry + 1):
        t = (row + ry) / (2 * ry)
        col = tuple(round(IRIS_TOP[i] + (IRIS_BOTTOM[i] - IRIS_TOP[i]) * t) for i in range(3)) + (255,)
        half = rx * (1 - (row / ry) ** 2) ** 0.5
        d.rectangle([(cx - half) * S, (cy + row) * S, (cx + half) * S, (cy + row + 1) * S], fill=col)
    d.ellipse([(cx - rx) * S, (cy - ry) * S, (cx + rx) * S, (cy + ry) * S], outline=(24, 28, 36, 255), width=3 * S)
    d.ellipse([(cx - 12) * S, (cy - 13) * S, (cx + 12) * S, (cy + 13) * S], fill=PUPIL)
    hx = cx - 9 if not flip else cx + 9
    d.ellipse([(hx - 7) * S, (cy - 17) * S, (hx + 7) * S, (cy - 3) * S], fill=(255, 255, 255, 255))
    lx = cx + 10 if not flip else cx - 10
    d.ellipse([(lx - 3) * S, (cy + 10) * S, (lx + 3) * S, (cy + 16) * S], fill=(255, 255, 255, 220))
    iris_alpha = ImageChops.multiply(iris.getchannel("A"), mask)
    iris.putalpha(iris_alpha)
    img.alpha_composite(iris)

    # Upper lash line: thick, heavier at the outer corner, with a short flick past it.
    thick = []
    for i, (x, y) in enumerate(top):
        t = i / (len(top) - 1)  # 0 outer -> 1 inner
        thick.append((x, y - (14 - 8 * t)))
    lash = top + list(reversed(thick)) + [(86, 248), (92, 263)]
    ImageDraw.Draw(img).polygon(sc(m(lash)), fill=INK)

    # Lower lid: thin line along the outer two thirds.
    lower = bezier(outer, (130, 286), (178, 288), 12)
    ImageDraw.Draw(img).line(sc(m(lower)), fill=LID, width=3 * S, joint="curve")

    # Lid crease just above the lash line.
    crease = bezier((112, 232), (156, 218), (200, 238), 12)
    ImageDraw.Draw(img).line(sc(m(crease)), fill=(72, 62, 58, 145), width=3 * S, joint="curve")


def brow(img, flip):
    m = mirror if flip else (lambda p: p)
    # Cool slate-silver brow angled gently down toward the bridge of the nose.
    shape = [(92, 206), (152, 200), (234, 224), (230, 238), (152, 214), (98, 218)]
    d = ImageDraw.Draw(img)
    d.polygon(sc(m(shape)), fill=BROW, outline=BROW_OUTLINE, width=2 * S)


def main():
    img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    for flip in (False, True):
        brow(img, flip)
        eye(img, flip)

    d = ImageDraw.Draw(img)
    # Nose: a short shaded stroke on one side with a small hook at the base.
    d.line(sc([(264, 298), (268, 328), (256, 336)]), fill=NOSE, width=4 * S, joint="curve")
    # Mouth: calm, resolute horizontal line with a subtle lower-lip shadow.
    d.line(sc(bezier((228, 384), (256, 381), (284, 384), 12)), fill=MOUTH, width=5 * S, joint="curve")
    d.line(sc([(246, 396), (266, 396)]), fill=(120, 70, 56, 90), width=3 * S)

    face = img.resize((SIZE, SIZE), Image.LANCZOS)
    face.save(OUT)

    # Preview on Diran's skin tone (not used in game).
    preview = Image.new("RGBA", (SIZE, SIZE), (236, 196, 158, 255))
    preview.alpha_composite(face)
    preview.save(PREVIEW)
    print(OUT, PREVIEW)


if __name__ == "__main__":
    main()
