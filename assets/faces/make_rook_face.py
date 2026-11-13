"""Generates Rook's face decal (assets/faces/hero_rook_face.png).

A transparent 512x512 PNG in the Roblox face-decal layout: a fierce, battle-scarred warrior
with heavy angled rust-brown brows, furrowed brow creases, sharp steel-grey eyes, a stern
jawline mouth, and cheek/chin battle scars from his reference art. Drawn at 4x and
downsampled for clean edges.

    python -I assets/faces/make_rook_face.py
"""

from pathlib import Path

from PIL import Image, ImageChops, ImageDraw

SIZE = 512
S = 4  # supersampling factor
W = SIZE * S

OUT = Path(__file__).with_name("hero_rook_face.png")
PREVIEW = Path(__file__).with_name("hero_rook_face_preview.png")

INK = (20, 14, 14, 255)
IRIS_TOP = (76, 84, 98)
IRIS_BOTTOM = (188, 198, 214)
BROW = (132, 46, 28, 255)
BROW_OUTLINE = (28, 16, 14, 255)
PUPIL = (14, 10, 10, 255)
SCLERA = (248, 246, 242, 255)
LID = (72, 42, 32, 215)
NOSE = (118, 68, 48, 175)
MOUTH = (48, 26, 22, 255)
SCAR = (108, 56, 42, 210)
SCAR_HIGHLIGHT = (212, 164, 134, 130)


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
    """Draws one fierce narrow eye; coordinates are viewer's left eye, mirrored when flip."""
    m = mirror if flip else (lambda p: p)
    outer, inner = (96, 246), (218, 272)
    top = bezier(outer, (154, 232), inner)
    bottom = bezier(inner, (162, 294), outer)

    # Sclera mask.
    mask = Image.new("L", (W, W), 0)
    ImageDraw.Draw(mask).polygon(sc(m(top + bottom)), fill=255)
    img.paste(Image.new("RGBA", (W, W), SCLERA), (0, 0), mask)

    # Intense steel-grey iris clipped to sclera.
    cx, cy = (SIZE - 160, 260) if flip else (160, 260)
    iris = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    d = ImageDraw.Draw(iris)
    rx, ry = 25, 29
    for row in range(-ry, ry + 1):
        t = (row + ry) / (2 * ry)
        col = tuple(round(IRIS_TOP[i] + (IRIS_BOTTOM[i] - IRIS_TOP[i]) * t) for i in range(3)) + (255,)
        half = rx * (1 - (row / ry) ** 2) ** 0.5
        d.rectangle([(cx - half) * S, (cy + row) * S, (cx + half) * S, (cy + row + 1) * S], fill=col)
    d.ellipse([(cx - rx) * S, (cy - ry) * S, (cx + rx) * S, (cy + ry) * S], outline=(24, 22, 26, 255), width=3 * S)
    d.ellipse([(cx - 10) * S, (cy - 12) * S, (cx + 10) * S, (cy + 12) * S], fill=PUPIL)
    hx = cx - 8 if not flip else cx + 8
    d.ellipse([(hx - 6) * S, (cy - 16) * S, (hx + 6) * S, (cy - 4) * S], fill=(255, 255, 255, 255))
    iris_alpha = ImageChops.multiply(iris.getchannel("A"), mask)
    iris.putalpha(iris_alpha)
    img.alpha_composite(iris)

    # Heavy upper lash line tapering to an intense outer wing.
    thick = []
    for i, (x, y) in enumerate(top):
        t = i / (len(top) - 1)
        thick.append((x, y - (14 - 8 * t)))
    lash = top + list(reversed(thick)) + [(84, 242), (90, 256)]
    ImageDraw.Draw(img).polygon(sc(m(lash)), fill=INK)

    # Lower lid and under-eye shadow.
    lower = bezier(outer, (136, 286), (190, 286), 14)
    ImageDraw.Draw(img).line(sc(m(lower)), fill=LID, width=3 * S, joint="curve")
    crease = bezier((114, 224), (156, 212), (200, 236), 12)
    ImageDraw.Draw(img).line(sc(m(crease)), fill=(82, 46, 34, 150), width=3 * S, joint="curve")


def brow(img, flip):
    m = mirror if flip else (lambda p: p)
    # Sharply angled, heavy rust-brown brows with dark comic-style edge.
    shape = [(84, 198), (146, 196), (234, 236), (228, 254), (146, 216), (94, 214)]
    pts = sc(m(shape))
    d = ImageDraw.Draw(img)
    d.polygon(pts, fill=BROW)
    d.line(pts + [pts[0]], fill=BROW_OUTLINE, width=3 * S, joint="curve")


def draw_scar(d, p0, p1, ticks=()):
    d.line(sc([(p0[0] + 2, p0[1] + 2), (p1[0] + 2, p1[1] + 2)]), fill=SCAR_HIGHLIGHT, width=3 * S, joint="curve")
    d.line(sc([p0, p1]), fill=SCAR, width=4 * S, joint="curve")
    for tx, ty, dx, dy in ticks:
        d.line(sc([(tx - dx, ty - dy), (tx + dx, ty + dy)]), fill=SCAR, width=3 * S)


def main():
    img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    for flip in (False, True):
        brow(img, flip)
        eye(img, flip)

    d = ImageDraw.Draw(img)
    # Furrow creases between the brows.
    d.line(sc([(244, 230), (242, 256)]), fill=INK, width=3 * S)
    d.line(sc([(268, 230), (270, 256)]), fill=INK, width=3 * S)

    # Strong nose bridge and tip shadow.
    d.line(sc([(244, 286), (240, 326)]), fill=(118, 68, 48, 100), width=3 * S)
    d.line(sc([(268, 284), (272, 328), (258, 340), (244, 336)]), fill=NOSE, width=4 * S, joint="curve")

    # Stern flat-to-frowning warrior mouth and under-lip crease.
    d.line(sc(bezier((216, 388), (256, 378), (296, 388), 16)), fill=MOUTH, width=5 * S, joint="curve")
    d.line(sc([(216, 388), (212, 394)]), fill=MOUTH, width=4 * S)
    d.line(sc([(296, 388), (300, 394)]), fill=MOUTH, width=4 * S)
    d.line(sc([(242, 402), (270, 402)]), fill=(96, 52, 38, 120), width=3 * S)

    # Cheek, eyebrow, and chin scars matching reference art.
    draw_scar(d, (124, 322), (166, 346), ticks=((142, 332, -3, 6),))
    draw_scar(d, (356, 294), (392, 344), ticks=((368, 311, 7, -4), (380, 328, 6, -4)))
    draw_scar(d, (292, 418), (314, 438))

    face = img.resize((SIZE, SIZE), Image.LANCZOS)
    face.save(OUT)

    preview = Image.new("RGBA", (SIZE, SIZE), (176, 120, 88, 255))
    preview.alpha_composite(face)
    preview.save(PREVIEW)
    print(OUT, PREVIEW)


if __name__ == "__main__":
    main()
