"""
Biome 9: Astral Archives (floors 41-45). docs/tower-mob-remodel-plan.md §5.9.
Cosmic library. Motif: floating pages, brass orreries and star-glyphs. Glow: starlight gold with indigo.

Blender coordinates: 1 unit = 1 stud, Z up, ground z = 0, enemies face +Y, their right hand is +X.
The Rune Mite uses the crawler joints; everyone else the biped joints. The Executor and the Rift Warden are
authored on a 6.6-stud biped frame and scaled with scaled().
"""
import math, random
from mathutils import Vector
import raid_kit as K
import mob_kit as M

V = Vector
K.GLOW["star"] = (255, 214, 120)
K.GLOW["indigo"] = (128, 116, 255)
STAR = "glow:star"
INDIGO = "glow:indigo"

ATLAS = M.Atlas("astral_archives", {
    "brass": (196, 156, 78), "brass_dark": (130, 98, 46), "midnight": (40, 44, 78), "midnight_dark": (24, 26, 48),
    "indigo": (66, 58, 140), "indigo_dark": (40, 34, 92), "parchment": (226, 212, 174), "parchment_dark": (176, 158, 118),
    "leather": (110, 64, 44), "wood": (112, 74, 46), "wood_dark": (70, 44, 28), "book_red": (150, 46, 46),
    "book_green": (52, 104, 70), "book_blue": (48, 72, 140), "silver": (196, 202, 216), "skin": (200, 176, 156),
    "stone": (128, 126, 140), "gold": (234, 192, 92), "black": (14, 14, 22),
})
ATLAS_ALPHA = M.Atlas("astral_archives_alpha", dict(ATLAS.colours, **{
    "silver": (238, 204, 112), "midnight": (52, 50, 96),
}))
BOOKS = ("book_red", "book_green", "book_blue", "leather", "indigo")


def scaled(A, s):
    """Scale an authored asset about the ground origin (UVs were set at paint time and do not change)."""
    for seg in A.segments:
        for v in seg.bm.verts:
            v.co *= s
        seg.pivot = V(seg.pivot) * s
    return A


def glyph_plate(seg, centre, size, colour, glow, rot=(0, 0, 0), seed=0):
    """A square rune plate with a few glowing strokes on its face (+Z face before rot)."""
    m = K.M(centre, rot)
    seg.box((size, size, 0.08), colour, mat=m @ K.M(scale=(1, 1, 1)), bevel=0.02)
    rnd = random.Random(seed)
    for k in range(3):
        a = rnd.uniform(0, 180)
        seg.box((size * rnd.uniform(0.35, 0.7), 0.05, 0.03), glow, mat=m @ K.M((rnd.uniform(-0.15, 0.15) * size, rnd.uniform(-0.15, 0.15) * size, 0.05), (0, 0, a)))


def book(seg, centre, size, colour, rot=(0, 0, 0), open_=False):
    """A closed book (cover + page block), or an open one lying flat."""
    w, d, h = size
    m = K.M(centre, rot)
    if open_:
        for s in (1, -1):
            seg.box((w / 2, d, h * 0.3), colour, mat=m @ K.M((s * w / 4, 0, 0), (0, s * -8, 0)))
            seg.box((w / 2 * 0.92, d * 0.92, h * 0.25), "parchment", mat=m @ K.M((s * w / 4 * 0.98, 0, h * 0.22), (0, s * -8, 0)))
    else:
        seg.box((w, d, h), colour, mat=m, bevel=0.02)
        seg.box((w * 0.9, d * 1.02, h * 0.82), "parchment", mat=m @ K.M((0.03 * w, 0, 0)))


def shelf_row(seg, x0, x1, y, z, h, depth, rnd):
    """A row of book spines facing +Y."""
    x = x0
    while x < x1 - 0.12:
        w = rnd.uniform(0.12, 0.22)
        bh = h * rnd.uniform(0.7, 0.98)
        seg.box((w, depth, bh), rnd.choice(BOOKS), loc=(x + w / 2, y, z + bh / 2))
        x += w + 0.015


# ============================================================================ Rune Mite (Regular, CRAWLER)
def rune_mite():
    A = M.MobAsset("mob_rune_mite", "CRAWLER", ATLAS, "REGULAR")
    body = A.segment("Body", (0, 0, 1.0))
    head = A.segment("Head", (0, 1.1, 0.95), body)
    # a brass clockwork body with a winding key, and a rune-plate shell floating above it
    body.sphere(1.0, "brass", loc=(0, -0.1, 1.0), scale=(0.95, 1.2, 0.55), segs=14, rings=8)
    body.torus(0.95, 0.06, "brass_dark", mat=K.M((0, -0.1, 1.0)) @ K.M(scale=(1, 1.25, 1)), major=18, minor=4)
    for k in range(5):
        a = 2 * math.pi * k / 5
        body.cyl(0.08, 0.08, 0.06, "silver", loc=(math.cos(a) * 0.5, -0.1 + math.sin(a) * 0.6, 1.53), segs=6)
    body.rod((0, -1.2, 1.1), (0, -1.55, 1.3), 0.05, "brass_dark", segs=5)
    body.torus(0.2, 0.05, "brass", loc=(0, -1.62, 1.35), rot=(0, 90, 0), major=10, minor=4)
    glyph_plate(body, (0, -0.1, 1.95), 1.5, "stone", STAR, rot=(4, 0, 45), seed=1)
    glyph_plate(body, (0, -0.1, 2.15), 0.85, "midnight", INDIGO, rot=(-6, 0, 10), seed=2)
    body.sphere(0.12, STAR, loc=(0, -0.1, 2.35), segs=6, rings=4)
    # head: a riveted brass dome with one lens eye
    head.sphere(0.45, "brass_dark", loc=(0, 1.2, 1.0), scale=(1.0, 0.9, 0.75), segs=12, rings=7)
    head.cyl(0.16, 0.16, 0.12, "silver", loc=(0, 1.58, 1.08), rot=(90, 0, 0), segs=10)
    head.cyl(0.1, 0.1, 0.14, STAR, loc=(0, 1.6, 1.08), rot=(90, 0, 0), segs=10)
    for s, side in ((-1, "L"), (1, "R")):
        jaw = A.segment(f"Jaw{side}", (s * 0.22, 1.5, 0.85), head)
        jaw.tube([V((s * 0.22, 1.5, 0.85)), V((s * 0.3, 1.8, 0.8)), V((s * 0.08, 1.98, 0.76))], [0.06, 0.05, 0.0], "silver", sides=5)
    for s in (-1, 1):
        for i in (1, 2, 3):
            y = (2 - i) * 0.7 - 0.1
            hip = V((s * 0.8, y, 0.95))
            knee = V((s * 1.55, y * 1.15, 1.45))
            foot = V((s * 2.0, y * 1.3, 0.0))
            leg = A.segment(f"Leg{s}_{i}", hip, body)
            shin = A.segment(f"Knee{s}_{i}", knee, leg)
            leg.tube([hip, knee], [0.08, 0.07], "brass_dark", sides=6)
            shin.sphere(0.09, "brass", loc=knee, segs=6, rings=4)
            shin.tube([knee, knee.lerp(foot, 0.5) + V((s * 0.08, 0, 0.05)), foot + V((0, 0, 0.04))], [0.06, 0.05, 0.02], "brass", sides=6)
    return A


# ============================================================================ casters (CASTER_BIPED)
def caster_frame(A, robe, robe_dark, trim, hood=True):
    body = A.segment("Body", (0, 0, 2.6))
    head = A.segment("Head", (0, 0.05, 4.35), body)
    body.tube([V((0, 0, 0.2)), V((0, 0, 1.6)), V((0, 0.03, 3.1)), V((0, 0, 4.3))], [(0.92, 0.82), (0.76, 0.66), (0.6, 0.5), (0.46, 0.4)], robe, sides=12)
    body.tube([V((0, 0, 0.2)), V((0, 0, 0.38))], [(0.94, 0.84), (0.92, 0.82)], trim, sides=12)
    body.torus(0.6, 0.07, trim, mat=K.M((0, 0.02, 3.1)) @ K.M(scale=(1, 0.82, 1)), major=16, minor=4)
    if hood:
        head.tube([V((0, -0.05, 4.3)), V((0, -0.08, 4.85)), V((0, -0.12, 5.25)), V((0, -0.35, 5.5))], [(0.55, 0.52), (0.58, 0.56), (0.48, 0.48), (0.0, 0.0)], robe_dark, sides=10)
        head.sphere(0.38, "black", loc=(0, 0.12, 4.75), segs=10, rings=6)
    for s, side in ((-1, "L"), (1, "R")):
        arm = A.segment(f"Arm{side}", (s * 0.55, 0, 4.05), body)
        fore = A.segment(f"Forearm{side}", (s * 0.78, 0.15, 3.35), arm)
        arm.tube([V((s * 0.5, 0, 4.1)), V((s * 0.72, 0.1, 3.6)), V((s * 0.78, 0.15, 3.35))], [0.17, 0.19, 0.21], robe, sides=8)
        fore.tube([V((s * 0.78, 0.15, 3.35)), V((s * 0.82, 0.35, 2.85))], [0.22, 0.29], robe_dark, sides=8)
        fore.torus(0.27, 0.04, trim, loc=(s * 0.82, 0.35, 2.87), rot=(-20, 0, 0), major=12, minor=4)
        fore.sphere(0.12, "skin", loc=(s * 0.82, 0.4, 2.75), segs=8, rings=5)
    for s, side in ((-1, "L"), (1, "R")):
        leg = A.segment(f"Leg{side}", (s * 0.25, 0, 2.4), body)
        knee = A.segment(f"Knee{side}", (s * 0.28, 0.05, 1.2), leg)
        leg.tube([V((s * 0.25, 0, 2.45)), V((s * 0.28, 0.05, 1.2))], [0.16, 0.14], robe_dark, sides=7)
        knee.tube([V((s * 0.28, 0.05, 1.2)), V((s * 0.3, 0.1, 0.25))], [0.14, 0.12], robe_dark, sides=7)
        knee.box((0.32, 0.55, 0.16), "leather", loc=(s * 0.3, 0.28, 0.08), bevel=0.04)
    return body, head


def astral_scribe():
    A = M.MobAsset("mob_astral_scribe", "CASTER_BIPED", ATLAS, "REGULAR")
    body, head = caster_frame(A, "indigo", "indigo_dark", "brass")
    # star-stitched robe, gold eyes in the hood, a quill-staff, an open floating tome trailing pages
    rnd = random.Random(41)
    for k in range(7):
        a = rnd.uniform(-1.2, 1.2)
        z = rnd.uniform(0.6, 3.0)
        r = 0.92 - (z - 0.2) / 4.1 * 0.46
        body.sphere(0.04, STAR, loc=(math.sin(a) * r, math.cos(a) * r * 0.9, z), segs=4, rings=3)
    for s in (1, -1):
        head.box((0.12, 0.05, 0.05), STAR, loc=(s * 0.14, 0.5, 4.82))
    fore = A.seg("ForearmR")
    fore.rod((0.82, 0.42, 0.9), (0.82, 0.42, 5.3), 0.05, "wood_dark", segs=6)
    fore.cyl(0.08, 0.06, 0.25, "brass", loc=(0.82, 0.42, 5.4), segs=6)
    fore.prism([(-0.05, 0), (0.05, 0), (0.22, 0.6), (0.18, 1.1), (0.0, 1.35), (-0.12, 0.8)], 0.03, "parchment", loc=(0.82, 0.42, 5.5), rot=(0, 0, 90))
    fore.spike((0.82, 0.42, 0.9), (0.82, 0.42, 0.55), 0.05, STAR, segs=5)
    left = A.seg("ForearmL")
    c = V((-0.9, 0.95, 3.25))
    book(left, c, (1.0, 0.7, 0.12), "book_blue", rot=(-35, 0, 0), open_=True)
    left.sphere(0.08, STAR, loc=c + V((0, 0.1, 0.25)), segs=6, rings=4)
    for k in range(4):
        p = c + V((-0.3 - 0.25 * k, -0.6 - 0.35 * k, 0.3 + 0.18 * k))
        left.box((0.28, 0.02, 0.36), "parchment", loc=p, rot=(rnd.uniform(-30, 30), rnd.uniform(-30, 30), rnd.uniform(0, 90)))
    return A


def glyph_warden():
    A = M.MobAsset("mob_glyph_warden", "CASTER_BIPED", ATLAS, "SUPPORT")
    body, head = caster_frame(A, "parchment", "parchment_dark", "brass", hood=False)
    # an archivist in parchment robes with a brass collar and lenses; three glyph rings orbit it
    body.prism([(-0.28, 0), (0.28, 0), (0.22, -2.9), (-0.22, -2.9)], 0.05, "indigo", loc=(0, 0.53, 4.05))
    for k in range(4):
        body.box((0.16, 0.06, 0.16), STAR, loc=(0, 0.57, 3.6 - k * 0.6), rot=(0, 45, 0))
    head.sphere(0.4, "skin", loc=(0, 0.1, 4.72), segs=10, rings=7)
    head.tube([V((0, 0.0, 4.95)), V((0, -0.05, 5.25))], [(0.42, 0.4), (0.3, 0.3)], "indigo_dark", sides=10)
    head.cyl(0.3, 0.3, 0.06, "brass", loc=(0, -0.05, 5.3), segs=10)
    for s in (1, -1):
        head.torus(0.12, 0.025, "brass", loc=(s * 0.15, 0.45, 4.8), rot=(90, 0, 0), major=10, minor=3)
        head.cyl(0.1, 0.1, 0.02, STAR, loc=(s * 0.15, 0.46, 4.8), rot=(90, 0, 0), segs=8)
    head.tube([V((0, 0.4, 4.55)), V((0, 0.42, 4.25)), V((0, 0.36, 4.05))], [(0.18, 0.08), (0.14, 0.07), (0.0, 0.0)], "silver", sides=6)
    body.torus(0.5, 0.12, "brass", mat=K.M((0, 0, 4.25)) @ K.M(scale=(1, 0.85, 1)), major=16, minor=5)
    for k, (r, tilt, z, col) in enumerate(((1.35, (20, 0, 0), 3.2, STAR), (1.2, (-15, 25, 0), 2.6, INDIGO), (1.5, (5, -20, 0), 1.9, STAR))):
        body.torus(r, 0.035, col, loc=(0, 0, z), rot=tilt, major=28, minor=3)
        m = K.M((0, 0, z), tilt)
        for j in range(4):
            a = 2 * math.pi * j / 4 + k
            body.box((0.16, 0.16, 0.04), "brass", mat=m @ K.M((math.cos(a) * r, math.sin(a) * r, 0), (0, 0, math.degrees(a))))
    return A


# ============================================================================ Archive Executor Elite / Alpha (ARMORED_BIPED)
def archive_executor(alpha=False):
    A = M.MobAsset("alpha_archive_executor" if alpha else "elite_archive_executor", "ARMORED_BIPED", ATLAS_ALPHA if alpha else ATLAS, "ALPHA" if alpha else "ELITE")
    body = A.segment("Body", (0, 0, 3.15))
    head = A.segment("Head", (0, 0.05, 5.35), body)
    rnd = random.Random(44)
    # midnight plate with silver edges and a star-chart tabard
    body.tube([V((0, 0, 3.0)), V((0, 0.05, 3.9)), V((0, 0.06, 4.85)), V((0, 0, 5.4))], [(0.82, 0.56), (0.88, 0.62), (1.0, 0.66), (0.6, 0.46)], "midnight", sides=12)
    body.tube([V((0, 0.24, 4.2)), V((0, 0.3, 4.6)), V((0, 0.3, 5.0))], [(0.82, 0.38), (0.9, 0.4), (0.76, 0.36)], "midnight_dark", sides=10)
    body.torus(0.82, 0.06, "silver", mat=K.M((0, 0, 3.15)) @ K.M(scale=(1, 0.7, 1)), major=18, minor=4)
    tab = K.M((0, 0.66, 4.3))
    body.prism([(-0.45, 0), (0.45, 0), (0.48, -3.1), (0, -3.4), (-0.48, -3.1)], 0.05, "indigo_dark", mat=tab)
    stars = [V((rnd.uniform(-0.35, 0.35), 0.7, rnd.uniform(1.3, 4.1))) for _ in range(8)]
    for p in stars:
        body.sphere(0.045, STAR, loc=p, segs=4, rings=3)
    for a, b in zip(stars, stars[1:5]):
        body.rod(a, b, 0.012, "silver", segs=3)
    for k in range(2):
        body.tube([V((0, 0, 3.0 - k * 0.32)), V((0, 0, 2.7 - k * 0.32))], [(0.9 + k * 0.05, 0.64), (0.94 + k * 0.05, 0.68)], "midnight_dark", sides=12)
    body.prism([(-0.75, 0), (0.75, 0), (0.85, -2.9), (-0.85, -2.9)], 0.07, "indigo", loc=(0, -0.66, 5.15), rot=(5, 0, 0))
    # head: a tall faceless helm with a star slit and a brass crest fin
    head.cyl(0.42, 0.38, 1.0, "midnight", loc=(0, 0.05, 5.9), segs=10)
    head.sphere(0.38, "midnight", loc=(0, 0.05, 6.4), scale=(1, 1, 0.6), segs=10, rings=6)
    head.box((0.08, 0.1, 0.6), STAR, loc=(0, 0.46, 5.9))
    head.box((0.45, 0.1, 0.06), STAR, loc=(0, 0.46, 6.05))
    head.prism([(0, 0), (0.0, 0.7), (-0.9, 0.35), (-1.1, -0.1)], 0.06, "brass", loc=(0, 0.15, 6.55), rot=(0, 0, 90))
    head.torus(0.42, 0.04, "silver", loc=(0, 0.05, 5.42), major=14, minor=4)
    # arms: banded pauldrons; a segmented glaive in the right hand
    for s, side in ((-1, "L"), (1, "R")):
        arm = A.segment(f"Arm{side}", (s * 1.0, 0, 4.95), body)
        fore = A.segment(f"Forearm{side}", (s * 1.15, 0.05, 3.85), arm)
        for j in range(3):
            arm.sphere(0.48 - j * 0.06, "midnight" if j % 2 == 0 else "midnight_dark", loc=(s * (1.05 + j * 0.08), 0, 5.1 - j * 0.22), scale=(1, 1, 0.5), segs=12, rings=6)
        arm.torus(0.46, 0.04, "silver", loc=(s * 1.05, 0, 5.08), major=14, minor=4)
        arm.tube([V((s * 1.05, 0, 4.9)), V((s * 1.15, 0.05, 3.9))], [0.25, 0.22], "midnight_dark", sides=8)
        fore.tube([V((s * 1.15, 0.05, 3.85)), V((s * 1.2, 0.15, 2.95))], [0.25, 0.23], "midnight", sides=8)
        fore.sphere(0.2, "silver", loc=(s * 1.2, 0.2, 2.8), segs=8, rings=5)
        if s == 1:
            x, y = 1.2, 0.3
            for j in range(5):
                z0 = 0.4 + j * 1.25
                fore.rod((x, y, z0), (x, y, z0 + 1.15), 0.055, "midnight_dark", segs=6)
                fore.torus(0.08, 0.03, "brass", loc=(x, y, z0 + 1.2), major=8, minor=3)
            fore.prism([(0, 0), (0.12, 0.3), (0.55, 1.3), (0.2, 2.0), (0.0, 2.2), (-0.15, 1.1)], 0.08, "silver", loc=(x, y, 6.6))
            fore.prism([(0.05, 0.4), (0.15, 0.5), (0.35, 1.2), (0.12, 1.7), (0.0, 1.2)], 0.1, STAR, loc=(x, y, 6.6))
            fore.spike((x, y, 0.4), (x, y, 0.0), 0.07, "brass", segs=5)
        else:
            book(fore, (-1.4, 0.35, 3.0), (0.6, 0.18, 0.8), "book_red", rot=(0, 0, 90))
            fore.rod((-1.25, 0.3, 3.3), (-1.4, 0.35, 3.4), 0.02, "brass", segs=3)
    for s, side in ((-1, "L"), (1, "R")):
        leg = A.segment(f"Leg{side}", (s * 0.42, 0, 2.95), body)
        knee = A.segment(f"Knee{side}", (s * 0.46, 0.05, 1.55), leg)
        leg.tube([V((s * 0.42, 0, 3.0)), V((s * 0.46, 0.05, 2.2)), V((s * 0.46, 0.05, 1.6))], [0.32, 0.34, 0.26], "midnight_dark", sides=8)
        knee.sphere(0.24, "silver", loc=(s * 0.47, 0.22, 1.55), segs=8, rings=5)
        knee.tube([V((s * 0.46, 0.05, 1.5)), V((s * 0.48, 0.05, 0.8)), V((s * 0.48, 0.05, 0.3))], [0.26, 0.28, 0.22], "midnight", sides=8)
        knee.box((0.44, 0.9, 0.26), "midnight_dark", loc=(s * 0.48, 0.2, 0.13), bevel=0.08)
    if alpha:
        crown = A.segment("Trophy_OrreryCrown", (0, 0.05, 6.65), head)
        c = V((0, 0.05, 7.2))
        crown.rod((0, 0.05, 6.6), c, 0.05, "brass", segs=6)
        crown.sphere(0.18, STAR, loc=c, segs=10, rings=6)
        for k, (r, tilt) in enumerate(((0.55, (75, 0, 0)), (0.8, (70, 25, 0)), (1.05, (80, -20, 0)))):
            crown.torus(r, 0.03, "silver", loc=c, rot=tilt, major=24, minor=3)
            p = K.M(c, tilt) @ V((math.cos(k * 2.1) * r, math.sin(k * 2.1) * r, 0))
            crown.sphere(0.09 + 0.02 * k, ("book_blue", "book_red", "brass")[k], loc=tuple(p), segs=8, rings=5)
    return scaled(A, 1.35)


# ============================================================================ Rift Warden (Biome Boss, ARCANE_COLOSSUS)
def rift_warden():
    A = M.MobAsset("boss_archive_rift_warden", "ARCANE_COLOSSUS", ATLAS, "BOSS")
    body = A.segment("Body", (0, 0, 3.0))
    head = A.segment("Head", (0, 0.1, 5.75), body)
    rnd = random.Random(45)
    # the torso is a bookcase: a wooden frame with shelves of books around a rift-eye core, bound by brass rings
    body.box((2.4, 1.3, 2.9), "wood_dark", loc=(0, 0, 4.25), bevel=0.08)
    for z in (3.0, 4.25, 5.5):
        body.box((2.5, 1.38, 0.12), "wood", loc=(0, 0, z), bevel=0.02)
    for k, z in enumerate((3.08, 4.33)):
        shelf_row(body, -1.1, -0.45, 0.4, z, 1.05, 0.5, rnd)
        shelf_row(body, 0.45, 1.1, 0.4, z, 1.05, 0.5, rnd)
        shelf_row(body, -1.1, 1.1, -0.4, z, 1.05, 0.5, rnd)
    body.cyl(0.55, 0.55, 0.3, "black", loc=(0, 0.6, 4.25), rot=(90, 0, 0), scale=(0.75, 1.0, 1), segs=14)
    body.torus(0.58, 0.08, "brass", mat=K.M((0, 0.72, 4.25), (90, 0, 0)) @ K.M(scale=(0.75, 1.0, 1)), major=18, minor=4)
    body.sphere(0.28, INDIGO, loc=(0, 0.66, 4.25), scale=(0.75, 0.5, 1.0), segs=10, rings=6)
    body.sphere(0.12, STAR, loc=(0, 0.78, 4.25), segs=8, rings=5)
    for k, (r, tilt) in enumerate(((1.75, (0, 0, 0)), (1.6, (12, 0, 0)))):
        body.torus(r, 0.06, "brass", loc=(0, 0, 3.6 + k * 1.3), rot=tilt, major=28, minor=4)
    for k in range(6):
        a = 2 * math.pi * k / 6
        body.box((0.14, 0.14, 0.06), STAR, loc=(math.cos(a) * 1.75, math.sin(a) * 1.75, 3.6), rot=(0, 0, math.degrees(a) + 45))
    body.box((2.2, 1.2, 0.5), "wood_dark", loc=(0, 0, 2.6), bevel=0.06)
    # head: a brass orrery dome with a single great eye
    head.sphere(0.75, "brass_dark", loc=(0, 0.15, 6.25), scale=(1, 1, 0.85), segs=14, rings=8)
    head.cyl(0.32, 0.32, 0.16, "silver", loc=(0, 0.85, 6.3), rot=(90, 0, 0), segs=12)
    head.cyl(0.22, 0.22, 0.2, STAR, loc=(0, 0.87, 6.3), rot=(90, 0, 0), segs=12)
    head.torus(0.95, 0.04, "silver", loc=(0, 0.15, 6.3), rot=(70, 0, 0), major=24, minor=3)
    head.torus(1.05, 0.04, "silver", loc=(0, 0.15, 6.3), rot=(70, 0, 60), major=24, minor=3)
    for k in range(3):
        a = 2 * math.pi * k / 3
        p = K.M((0, 0.15, 6.3), (70, 0, 60 * (k % 2))) @ V((math.cos(a) * (0.95 + 0.1 * (k % 2)), math.sin(a) * (0.95 + 0.1 * (k % 2)), 0))
        head.sphere(0.11, ("book_blue", "book_red", "gold")[k], loc=tuple(p), segs=8, rings=5)
    head.spike((0, 0.15, 6.85), (0, 0.15, 7.55), 0.12, "brass", segs=6)
    head.sphere(0.1, STAR, loc=(0, 0.15, 7.6), segs=6, rings=4)
    # arms: shelf-block shoulders, brass-ringed arms, each guarded by a floating tome shield
    for s, side in ((-1, "L"), (1, "R")):
        arm = A.segment(f"Arm{side}", (s * 1.45, 0, 5.1), body)
        fore = A.segment(f"Forearm{side}", (s * 1.75, 0.15, 3.7), arm)
        arm.box((1.0, 1.2, 1.0), "wood_dark", loc=(s * 1.6, 0, 5.25), bevel=0.06)
        shelf_row(arm, s * 1.6 - 0.4, s * 1.6 + 0.4, 0.45, 4.9, 0.75, 0.35, rnd)
        arm.tube([V((s * 1.55, 0, 4.85)), V((s * 1.75, 0.15, 3.75))], [0.32, 0.28], "brass_dark", sides=8)
        fore.tube([V((s * 1.75, 0.15, 3.7)), V((s * 1.8, 0.3, 2.75))], [0.3, 0.28], "wood", sides=8)
        for z in (3.45, 3.0):
            fore.torus(0.32, 0.05, "brass", loc=(s * 1.78, 0.22, z), major=12, minor=4)
        fore.sphere(0.32, "brass_dark", loc=(s * 1.82, 0.35, 2.55), segs=10, rings=6)
        book(fore, (s * 2.55, 0.55, 3.3), (0.32, 1.3, 1.7), "book_red" if s > 0 else "book_blue", rot=(0, 0, s * 12))
        fore.cyl(0.3, 0.3, 0.06, "brass", loc=(s * 2.75, 0.55, 3.3), rot=(0, 90, 0), segs=8)
        fore.cyl(0.18, 0.18, 0.08, STAR, loc=(s * 2.77, 0.55, 3.3), rot=(0, 90, 0), segs=6)
    # legs: stacked tomes on brass feet
    for s, side in ((-1, "L"), (1, "R")):
        leg = A.segment(f"Leg{side}", (s * 0.65, 0, 2.5), body)
        knee = A.segment(f"Knee{side}", (s * 0.7, 0.05, 1.4), leg)
        for j in range(3):
            book(leg, (s * 0.67, 0.02, 2.25 - j * 0.32), (0.95, 0.85, 0.3), BOOKS[(j + (s > 0)) % 5], rot=(0, 0, rnd.uniform(-10, 10)))
        knee.sphere(0.36, "brass", loc=(s * 0.7, 0.08, 1.4), segs=10, rings=6)
        for j in range(3):
            book(knee, (s * 0.72, 0.05, 1.0 - j * 0.3), (1.0, 0.9, 0.28), BOOKS[(j + 2 + (s > 0)) % 5], rot=(0, 0, rnd.uniform(-10, 10)))
        knee.box((1.15, 1.35, 0.22), "brass_dark", loc=(s * 0.72, 0.2, 0.11), bevel=0.05)
    return scaled(A, 2.3)


BUILDERS = {
    "mob_rune_mite": rune_mite,
    "mob_astral_scribe": astral_scribe,
    "mob_glyph_warden": glyph_warden,
    "elite_archive_executor": lambda: archive_executor(False),
    "alpha_archive_executor": lambda: archive_executor(True),
    "boss_archive_rift_warden": rift_warden,
}
