"""Generates Caspian's face decal (assets/faces/hero_caspian_face.png).

A transparent 512x512 PNG in the Roblox face-decal layout: a confident young knight. Derived
from make_han_face.py: warm amber irises, auburn brows (matching his hair) set a little lower
toward the nose but calmer than Han's, and a small, confident half-smile lifting at his left
corner (the viewer's right). Drawn at 4x and downsampled for clean edges.

    python -I assets/faces/make_caspian_face.py
"""

from pathlib import Path

from PIL import Image, ImageChops, ImageDraw

SIZE = 512
S = 4  # supersampling factor
W = SIZE * S

OUT = Path(__file__).with_name("hero_caspian_face.png")
PREVIEW = Path(__file__).with_name("hero_caspian_face_preview.png")

INK = (22, 16, 16, 255)
IRIS_TOP = (96, 44, 10)
IRIS_BOTTOM = (226, 140, 50)
BROW = (112, 52, 26, 255)
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
    top = bezier(outer, (150, 236), inner)
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
    # Thick and a little lower toward the nose: confident and focused, not angry.
    shape = [(92, 202), (152, 194), (234, 216), (232, 230), (152, 210), (98, 214)]
    ImageDraw.Draw(img).polygon(sc(m(shape)), fill=BROW)


def main():
    img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    for flip in (False, True):
        brow(img, flip)
        eye(img, flip)

    d = ImageDraw.Draw(img)
    # Nose: a short shaded stroke on one side with a small hook at the base.
    d.line(sc([(266, 298), (270, 330), (258, 338)]), fill=NOSE, width=4 * S, joint="curve")
    # Mouth: a small confident half-smile, lifting at his left corner (the viewer's right).
    d.line(sc(bezier((232, 388), (258, 392), (286, 378), 12)), fill=MOUTH, width=5 * S, joint="curve")
    d.line(sc([(248, 400), (268, 400)]), fill=(120, 70, 56, 90), width=3 * S)

    face = img.resize((SIZE, SIZE), Image.LANCZOS)
    face.save(OUT)

    # Preview on Caspian's skin tone (not used in game).
    preview = Image.new("RGBA", (SIZE, SIZE), (204, 152, 114, 255))
    preview.alpha_composite(face)
    preview.save(PREVIEW)
    print(OUT, PREVIEW)


if __name__ == "__main__":
    main()
