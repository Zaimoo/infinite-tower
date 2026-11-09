"""
Biome 7: Corrupted Grove (floors 31-35). docs/tower-mob-remodel-plan.md §5.7.
Blighted forest. Motif: bruised bark, weeping sap and purple rot blooms. Glow: sickly magenta.

Blender coordinates: 1 unit = 1 stud, Z up, ground z = 0, enemies face +Y, their right hand is +X.
Every enemy uses the biped joint names (the wolf's front legs are Arm/Forearm, hind legs Leg/Knee).
The Rotwood Keeper and the Blight Sovereign share one treant frame, scaled with scaled().
"""
import math, random
from mathutils import Vector
import raid_kit as K
import mob_kit as M

V = Vector
K.GLOW["blight"] = (236, 72, 206)
K.GLOW["bloom"] = (255, 140, 236)
BLIGHT = "glow:blight"
BLOOM = "glow:bloom"

ATLAS = M.Atlas("corrupted_grove", {
    "bark": (92, 70, 66), "bark_dark": (54, 40, 44), "bark_bruise": (96, 62, 92), "bark_light": (140, 114, 104),
    "rot": (134, 64, 140), "rot_dark": (78, 34, 86), "moss": (112, 128, 70), "moss_dark": (66, 80, 46),
    "sap": (196, 120, 172), "thorn": (40, 30, 36), "fur": (98, 88, 104), "fur_dark": (60, 52, 66),
    "bone": (210, 200, 180), "twine": (170, 146, 110), "iron": (70, 66, 70), "cloth": (98, 90, 78),
    "gold": (232, 186, 84), "gold_dark": (160, 120, 54), "black": (16, 12, 16),
})
ATLAS_ALPHA = M.Atlas("corrupted_grove_alpha", dict(ATLAS.colours, **{
    "bark_light": (196, 160, 96), "moss": (150, 140, 70),
}))


def scaled(A, s):
    """Scale an authored asset about the ground origin (UVs were set at paint time and do not change)."""
    for seg in A.segments:
        for v in seg.bm.verts:
            v.co *= s
        seg.pivot = V(seg.pivot) * s
    return A


def bloom(seg, c, normal, r, petals=5, colour="rot", core=BLOOM):
    """A rot bloom: a ring of petals around a glowing core, facing `normal`."""
    c, n = V(c), V(normal).normalized()
    u = n.cross(V((0, 0, 1)))
    if u.length < 1e-3:
        u = V((1, 0, 0))
    u.normalize()
    w = n.cross(u)
    for k in range(petals):
        a = 2 * math.pi * k / petals
        d = u * math.cos(a) + w * math.sin(a)
        seg.spike(c, c + d * r + n * r * 0.35, r * 0.32, colour, segs=4)
    seg.sphere(r * 0.38, core, loc=c + n * r * 0.1, segs=6, rings=4)


def branch(seg, a, b, r, colour="bark", twigs=2, seed=0, twig_len=0.5):
    """A tapering branch with a few twigs."""
    a, b = V(a), V(b)
    rnd = random.Random(seed)
    mid = a.lerp(b, 0.5) + V((rnd.uniform(-0.1, 0.1), rnd.uniform(-0.1, 0.1), rnd.uniform(-0.05, 0.1)))
    seg.tube([a, mid, b], [r, r * 0.7, r * 0.15], colour, sides=6)
    for k in range(twigs):
        p = a.lerp(b, 0.45 + 0.4 * k / max(twigs, 1))
        d = (b - a).normalized()
        side = d.cross(V((0, 0, 1)))
        if side.length < 1e-3:
            side = V((1, 0, 0))
        side.normalize()
        t = p + (d * 0.5 + side * (1 if k % 2 else -1) + V((0, 0, 0.4))).normalized() * twig_len * rnd.uniform(0.8, 1.2)
        seg.spike(p, t, r * 0.35, colour, segs=4)


# ============================================================================ Blight Wolf (Regular, QUADRUPED)
def blight_wolf():
    A = M.MobAsset("mob_blight_wolf", "QUADRUPED", ATLAS, "REGULAR")
    body = A.segment("Body", (0, 0, 2.2))
    head = A.segment("Head", (0, 1.9, 2.9), body)
    rnd = random.Random(31)
    # a gaunt ribbed torso with bark plates on the flanks and a thorned spine
    body.sphere(1.0, "fur", loc=(0, 1.0, 2.45), scale=(0.72, 0.95, 0.85), segs=12, rings=8)
    body.sphere(1.0, "fur_dark", loc=(0, -0.75, 2.45), scale=(0.52, 1.25, 0.55), segs=12, rings=8)
    for s in (1, -1):
        for k in range(3):
            body.box((0.12, 0.7, 0.55), "bark_dark" if k % 2 else "bark_bruise", loc=(s * 0.62, 0.9 - k * 0.65, 2.55 - k * 0.05), rot=(0, s * -12, rnd.uniform(-8, 8)), bevel=0.05)
        for k in range(3):
            body.box((0.06, 0.08, 0.5), "bone", loc=(s * 0.55, -0.4 - k * 0.35, 2.35), rot=(0, s * -15, 0))
    for k in range(9):
        t = k / 8
        b = V((0, 1.7 - t * 2.9, 3.25 - t * 0.35 - (0.2 if k == 0 else 0)))
        body.spike(b, b + V((0, -0.35, 0.6 - t * 0.25)), 0.1, "thorn", segs=5)
    bloom(body, (0.3, -0.2, 2.95), (0.4, 0, 1), 0.28, petals=5)
    body.tube([V((0, -1.9, 2.55)), V((0, -2.6, 2.6)), V((0, -3.1, 2.2)), V((0, -3.3, 1.8))], [0.2, 0.16, 0.1, 0.04], "fur_dark", sides=6)
    for k in range(3):
        p = V((0, -2.3 - k * 0.35, 2.65 - k * 0.15))
        body.spike(p, p + V((0, -0.15, 0.35)), 0.06, "thorn", segs=4)
    # head: a lean skull, bark brow, thorn ears, bloom eyes, bared bone teeth
    head.sphere(0.5, "fur", loc=(0, 2.25, 3.15), scale=(0.92, 1.1, 0.85), segs=12, rings=7)
    head.tube([V((0, 2.55, 3.05)), V((0, 3.0, 2.95)), V((0, 3.38, 2.85))], [(0.28, 0.24), (0.22, 0.18), (0.14, 0.12)], "fur_dark", sides=8)
    head.sphere(0.09, "black", loc=(0, 3.45, 2.9), segs=6, rings=4)
    head.tube([V((0, 2.5, 2.75)), V((0, 3.0, 2.66)), V((0, 3.26, 2.64))], [0.18, 0.12, 0.07], "fur_dark", sides=6)
    head.box((0.55, 0.4, 0.1), "bark_bruise", loc=(0, 2.4, 3.55), rot=(-15, 0, 0), bevel=0.03)
    for s in (1, -1):
        head.spike((s * 0.28, 2.1, 3.45), (s * 0.45, 1.9, 4.0), 0.14, "thorn", segs=4)
        bloom(head, (s * 0.26, 2.62, 3.25), (s * 0.5, 1, 0.1), 0.12, petals=4)
        for k in range(2):
            head.spike((s * (0.08 + k * 0.08), 3.1 - k * 0.15, 2.8), (s * (0.08 + k * 0.08), 3.12 - k * 0.15, 2.62), 0.035, "bone", segs=4)
    for s, side in ((-1, "L"), (1, "R")):
        arm = A.segment(f"Arm{side}", (s * 0.5, 1.3, 2.3), body)
        fore = A.segment(f"Forearm{side}", (s * 0.55, 1.15, 1.15), arm)
        arm.tube([V((s * 0.5, 1.3, 2.5)), V((s * 0.55, 1.25, 1.8)), V((s * 0.55, 1.15, 1.15))], [0.26, 0.2, 0.14], "fur", sides=7)
        fore.tube([V((s * 0.55, 1.15, 1.15)), V((s * 0.55, 1.3, 0.55)), V((s * 0.55, 1.4, 0.2))], [0.13, 0.11, 0.11], "fur_dark", sides=7)
        leg = A.segment(f"Leg{side}", (s * 0.5, -1.3, 2.3), body)
        knee = A.segment(f"Knee{side}", (s * 0.55, -1.75, 1.2), leg)
        leg.tube([V((s * 0.48, -1.2, 2.45)), V((s * 0.55, -1.45, 1.8)), V((s * 0.55, -1.75, 1.2))], [0.34, 0.26, 0.13], "fur", sides=7)
        knee.tube([V((s * 0.55, -1.75, 1.2)), V((s * 0.55, -1.55, 0.55)), V((s * 0.55, -1.45, 0.2))], [0.12, 0.11, 0.11], "fur_dark", sides=7)
        for seg, y in ((fore, 1.5), (knee, -1.35)):
            seg.box((0.28, 0.42, 0.16), "fur_dark", loc=(s * 0.55, y, 0.08), bevel=0.05)
            for c in (-0.08, 0.08):
                seg.spike((s * 0.55 + c, y + 0.18, 0.08), (s * 0.55 + c, y + 0.38, 0.02), 0.035, "thorn", segs=4)
    return A


# ============================================================================ rooted casters (ROOTED_BIPED)
def rooted_legs(A, body, spread=0.3, colour="bark"):
    for s, side in ((-1, "L"), (1, "R")):
        leg = A.segment(f"Leg{side}", (s * spread, 0, 2.4), body)
        knee = A.segment(f"Knee{side}", (s * (spread + 0.05), 0.1, 1.25), leg)
        leg.tube([V((s * spread, 0, 2.45)), V((s * (spread + 0.04), 0.06, 1.8)), V((s * (spread + 0.05), 0.1, 1.25))], [0.2, 0.17, 0.14], colour, sides=6)
        knee.tube([V((s * (spread + 0.05), 0.1, 1.25)), V((s * (spread + 0.06), 0.05, 0.6)), V((s * (spread + 0.06), 0.05, 0.15))], [0.14, 0.13, 0.17], colour, sides=6)
        foot = V((s * (spread + 0.06), 0.05, 0.1))
        for a in (-40, 0, 40, 180):
            d = V((math.sin(math.radians(a)) * s, math.cos(math.radians(a)), 0))
            knee.tube([foot, foot + d * 0.35 + V((0, 0, -0.04)), foot + d * 0.6 + V((0, 0, -0.08))], [0.08, 0.05, 0.0], colour, sides=4)


def thorn_weaver():
    A = M.MobAsset("mob_thorn_weaver", "ROOTED_BIPED", ATLAS, "REGULAR")
    body = A.segment("Body", (0, 0, 2.6))
    head = A.segment("Head", (0, 0.05, 4.7), body)
    # a spindly twisted briar trunk wound with thorned vines
    body.tube([V((0, 0, 2.3)), V((0.08, 0.05, 3.2)), V((-0.06, 0.02, 4.1)), V((0, 0, 4.65))], [0.32, 0.28, 0.34, 0.24], "bark", sides=8)
    M.vine_spiral(body, (0, 0.02, 0), 0.32, 2.4, 4.5, 2.2, "thorn", thick=0.05, seed=4)
    for k in range(8):
        a = k * 2.4
        z = 2.5 + k * 0.25
        b = V((math.cos(a) * 0.32, math.sin(a) * 0.32, z))
        body.spike(b, b + V((math.cos(a) * 0.3, math.sin(a) * 0.3, 0.05)), 0.04, "thorn", segs=4)
    bloom(body, (0.2, 0.3, 3.7), (0.4, 1, 0.2), 0.22, petals=5)
    body.torus(0.38, 0.12, "bark_dark", loc=(0, 0, 4.35), major=12, minor=5)
    # head: a gnarled knot with hollow glowing eyes and a crown of thorns
    head.ico(0.45, "bark_bruise", loc=(0, 0.05, 5.05), subdiv=1, jitter=0.06, seed=2)
    for s in (1, -1):
        head.sphere(0.09, BLIGHT, loc=(s * 0.16, 0.42, 5.1), segs=6, rings=4)
    head.box((0.25, 0.08, 0.06), "black", loc=(0, 0.44, 4.85))
    for k in range(7):
        a = 2 * math.pi * k / 7
        b = V((math.cos(a) * 0.35, 0.05 + math.sin(a) * 0.35, 5.35))
        head.spike(b, b + V((math.cos(a) * 0.2, math.sin(a) * 0.2, 0.45 + 0.15 * (k % 2))), 0.06, "thorn", segs=4)
    # long thin arms ending in finger-branches; glowing thorn bolts gathered over the right hand
    for s, side in ((-1, "L"), (1, "R")):
        arm = A.segment(f"Arm{side}", (s * 0.4, 0, 4.35), body)
        fore = A.segment(f"Forearm{side}", (s * 0.85, 0.15, 3.45), arm)
        arm.tube([V((s * 0.38, 0, 4.35)), V((s * 0.65, 0.08, 3.9)), V((s * 0.85, 0.15, 3.45))], [0.12, 0.1, 0.09], "bark", sides=6)
        fore.tube([V((s * 0.85, 0.15, 3.45)), V((s * 0.95, 0.4, 2.85))], [0.09, 0.08], "bark", sides=6)
        hand = V((s * 0.95, 0.42, 2.8))
        for k, a in enumerate((-35, -10, 15, 40)):
            d = V((math.sin(math.radians(a)) * s * 0.6, 0.8, -0.3)).normalized()
            fore.tube([hand, hand + d * 0.35 + V((0, 0, 0.05)), hand + d * 0.65], [0.05, 0.035, 0.0], "bark_dark", sides=4)
        if s == 1:
            for k in range(3):
                c = hand + V((0.05 * k - 0.05, 0.5 + 0.1 * k, 0.45 + 0.25 * k))
                fore.spike(c - V((0, 0.25, 0)), c + V((0, 0.35, 0)), 0.06, BLIGHT, segs=4)
    rooted_legs(A, body, 0.22)
    return A


def rot_mender():
    A = M.MobAsset("mob_rot_mender", "ROOTED_BIPED", ATLAS, "SUPPORT")
    body = A.segment("Body", (0, 0, 2.5))
    head = A.segment("Head", (0, 0.55, 4.1), body)
    # a hunched grafter: a bent trunk with stitched bark patches and a mossy hood-cowl
    body.tube([V((0, -0.05, 2.2)), V((0, 0.0, 3.0)), V((0, 0.25, 3.7)), V((0, 0.5, 4.05))], [(0.55, 0.45), (0.6, 0.5), (0.55, 0.48), (0.38, 0.34)], "bark", sides=10)
    body.tube([V((0, -0.3, 3.4)), V((0, -0.1, 4.0)), V((0, 0.3, 4.35))], [(0.62, 0.42), (0.55, 0.42), (0.35, 0.3)], "moss_dark", sides=8)
    for k, (x, y, z) in enumerate(((0.35, 0.45, 3.0), (-0.3, 0.45, 2.6), (0.0, -0.45, 2.9))):
        body.box((0.36, 0.08, 0.32), "bark_light" if k % 2 else "bark_bruise", loc=(x, y, z), bevel=0.02)
        for j in range(3):
            body.box((0.32, 0.1, 0.03), "twine", loc=(x, y + (0.02 if y > 0 else -0.02), z - 0.1 + j * 0.1))
    for k in range(5):
        a = math.radians(-60 + k * 30)
        b = V((math.sin(a) * 0.5, -0.3 + math.cos(a) * -0.05, 4.0))
        body.spike(b, b + V((math.sin(a) * 0.1, -0.1, -0.7 - 0.2 * (k % 2))), 0.08, "moss", segs=4)
    body.tube([V((0, 0, 2.2)), V((0, 0, 1.7))], [(0.55, 0.45), (0.5, 0.42)], "cloth", sides=10)
    bloom(body, (-0.35, 0.35, 3.55), (-0.4, 1, 0.3), 0.18, petals=5)
    # head: a mossy cowl around a bark face, one magenta eye larger than the other
    head.sphere(0.36, "bark_bruise", loc=(0, 0.75, 4.25), segs=10, rings=7)
    head.sphere(0.45, "moss_dark", loc=(0, 0.6, 4.4), scale=(1.05, 1.0, 1.0), segs=10, rings=7)
    head.sphere(0.08, BLIGHT, loc=(0.13, 1.08, 4.3), segs=6, rings=4)
    head.sphere(0.05, BLIGHT, loc=(-0.13, 1.08, 4.32), segs=6, rings=4)
    head.box((0.22, 0.06, 0.04), "twine", loc=(0, 1.1, 4.12))
    # arms: a gnarled cane in the right hand, a hanging sap-lantern in the left (its MEND light)
    for s, side in ((-1, "L"), (1, "R")):
        arm = A.segment(f"Arm{side}", (s * 0.55, 0.3, 3.75), body)
        fore = A.segment(f"Forearm{side}", (s * 0.75, 0.45, 3.05), arm)
        arm.tube([V((s * 0.52, 0.3, 3.8)), V((s * 0.75, 0.45, 3.05))], [0.16, 0.13], "bark", sides=6)
        fore.tube([V((s * 0.75, 0.45, 3.05)), V((s * 0.8, 0.7, 2.6))], [0.13, 0.11], "bark_dark", sides=6)
        fore.sphere(0.12, "bark_light", loc=(s * 0.8, 0.75, 2.55), segs=8, rings=5)
        if s == 1:
            fore.tube([V((0.8, 0.8, 0.1)), V((0.85, 0.8, 1.5)), V((0.8, 0.78, 2.7)), V((0.95, 0.75, 2.95))], [0.06, 0.06, 0.06, 0.04], "bark_dark", sides=5)
        else:
            c = V((-0.8, 0.85, 1.85))
            fore.rod((-0.8, 0.78, 2.5), c + V((0, 0, 0.32)), 0.025, "iron", segs=4)
            fore.cyl(0.18, 0.2, 0.08, "iron", loc=c + V((0, 0, 0.3)), segs=6)
            fore.cyl(0.2, 0.18, 0.08, "iron", loc=c - V((0, 0, 0.3)), segs=6)
            for k in range(4):
                a = k * math.pi / 2 + math.pi / 4
                fore.rod(c + V((math.cos(a) * 0.17, math.sin(a) * 0.17, -0.28)), c + V((math.cos(a) * 0.17, math.sin(a) * 0.17, 0.28)), 0.025, "iron", segs=4)
            fore.sphere(0.15, BLOOM, loc=c, scale=(1, 1, 1.3), segs=8, rings=5)
            fore.spike(c - V((0, 0, 0.34)), c - V((0, 0, 0.6)), 0.05, "sap", segs=5)
    rooted_legs(A, body, 0.26)
    return A


# ============================================================================ the treant frame (TREANT / GROVE_COLOSSUS)
def treant(A, boss=False, alpha=False):
    rnd = random.Random(70 + boss)
    body = A.segment("Body", (0, 0, 3.0))
    head = A.segment("Head", (0, 0.05, 5.4), body)
    # a hollow trunk: bruised bark ridges around a cavity holding the glowing rot heart
    body.cyl(1.05, 0.85, 3.0, "bark", loc=(0, 0, 4.0), segs=10)
    for k in range(8):
        a = 2 * math.pi * k / 8 + 0.2
        if abs(math.sin(a) - 1) < 0.35:
            continue
        p = V((math.cos(a) * 0.98, math.sin(a) * 0.98, 4.0))
        body.box((0.24, 0.24, 2.9), "bark_dark" if k % 2 else "bark_bruise", loc=p, rot=(0, 0, math.degrees(a)), bevel=0.06)
    body.cyl(0.55, 0.55, 0.3, "black", loc=(0, 0.88, 4.1), rot=(90, 0, 0), scale=(1, 1.45, 1), segs=10)
    body.torus(0.55, 0.14, "bark_dark", mat=K.M((0, 0.98, 4.1), (90, 0, 0)) @ K.M(scale=(1, 1.45, 1)), major=12, minor=5)
    body.ico(0.36, BLIGHT, loc=(0, 0.8, 4.05), subdiv=1, jitter=0.05, seed=3)
    for k in range(4):
        a = math.radians(-50 + k * 33)
        body.tube([V((math.sin(a) * 0.35, 0.95, 3.6)), V((math.sin(a) * 0.4, 1.0, 3.2)), V((math.sin(a) * 0.36, 0.98, 2.9))], [0.05, 0.04, 0.0], "sap", sides=4)
    body.cyl(0.9, 1.0, 0.6, "bark_dark", loc=(0, 0, 2.6), segs=10)
    # a mantle of hanging moss over the shoulders
    for k in range(14 if boss else 9):
        a = math.pi * 0.15 + (math.pi * 1.7) * k / ((14 if boss else 9) - 1) + math.pi / 2
        b = V((math.cos(a) * 1.0, math.sin(a) * 0.95, 5.35))
        L = rnd.uniform(0.8, 1.4) * (1.5 if boss else 1.0)
        body.spike(b, b + V((math.cos(a) * 0.15, math.sin(a) * 0.15, -L)), 0.16, "moss" if k % 2 else "moss_dark", segs=4)
    for k in range(3):
        bloom(body, (rnd.uniform(-0.8, 0.8), rnd.uniform(-1.0, -0.5), rnd.uniform(3.0, 5.0)), (0, -1, 0.3), 0.25, petals=5)
    # head: the trunk's crown, a face of knots with glowing eyes, branches above
    head.cyl(0.85, 0.75, 0.8, "bark", loc=(0, 0.05, 5.8), segs=10)
    head.box((1.0, 0.25, 0.18), "bark_dark", loc=(0, 0.82, 6.15), bevel=0.05)
    for s in (1, -1):
        head.sphere(0.13, BLIGHT, loc=(s * 0.32, 0.8, 5.9), segs=6, rings=4)
    head.box((0.5, 0.1, 0.1), "black", loc=(0, 0.8, 5.5))
    for k in range(6 if boss else 4):
        a = 2 * math.pi * k / (6 if boss else 4) + 0.4
        b = V((math.cos(a) * 0.55, 0.05 + math.sin(a) * 0.5, 6.15))
        t = b + V((math.cos(a) * 0.7, math.sin(a) * 0.5, rnd.uniform(1.0, 1.6) * (1.25 if boss else 1)))
        branch(head, b, t, 0.16, "bark_dark", twigs=2, seed=k)
    if boss:
        # a jagged crown of dead wood bound with a gold band
        head.torus(0.82, 0.08, "gold", loc=(0, 0.05, 6.22), major=16, minor=4)
        for k in range(9):
            a = 2 * math.pi * k / 9 + math.pi / 2
            b = V((math.cos(a) * 0.82, 0.05 + math.sin(a) * 0.82, 6.25))
            head.spike(b, b + V((math.cos(a) * 0.1, math.sin(a) * 0.1, 0.55 if k % 2 else 0.85)), 0.11, "bark_light", segs=4)
        head.sphere(0.12, BLOOM, loc=(0, 0.88, 6.35), segs=6, rings=4)
    # branch arms ending in grasping twig hands
    for s, side in ((-1, "L"), (1, "R")):
        arm = A.segment(f"Arm{side}", (s * 1.05, 0, 5.0), body)
        fore = A.segment(f"Forearm{side}", (s * 1.5, 0.2, 3.6), arm)
        arm.tube([V((s * 0.9, 0, 5.05)), V((s * 1.35, 0.05, 4.4)), V((s * 1.5, 0.2, 3.6))], [0.36, 0.3, 0.26], "bark", sides=7)
        branch(arm, (s * 1.3, 0.0, 4.6), (s * 1.9, -0.3, 5.4), 0.1, "bark_dark", twigs=1, seed=10 + (s > 0))
        fore.tube([V((s * 1.5, 0.2, 3.6)), V((s * 1.6, 0.4, 2.8)), V((s * 1.6, 0.55, 2.35))], [0.26, 0.22, 0.2], "bark_dark", sides=7)
        hand = V((s * 1.6, 0.6, 2.25))
        for k, a in enumerate((-50, -20, 10, 40)):
            d = V((math.sin(math.radians(a)) * s * 0.7, 0.6, -0.6)).normalized()
            fore.tube([hand, hand + d * 0.5, hand + d * 0.85 + V((0, 0.15, 0.1))], [0.08, 0.06, 0.0], "bark", sides=5)
        fore.tube([hand, hand + V((-s * 0.3, 0.35, 0.2)), hand + V((-s * 0.4, 0.6, 0.35))], [0.08, 0.06, 0.0], "bark", sides=5)
    # root legs splaying into root toes
    for s, side in ((-1, "L"), (1, "R")):
        leg = A.segment(f"Leg{side}", (s * 0.55, 0, 2.5), body)
        knee = A.segment(f"Knee{side}", (s * 0.62, 0.1, 1.35), leg)
        leg.tube([V((s * 0.55, 0, 2.6)), V((s * 0.62, 0.05, 1.9)), V((s * 0.62, 0.1, 1.35))], [0.42, 0.38, 0.32], "bark", sides=7)
        knee.tube([V((s * 0.62, 0.1, 1.35)), V((s * 0.65, 0.1, 0.7)), V((s * 0.65, 0.1, 0.25))], [0.32, 0.34, 0.4], "bark_dark", sides=7)
        foot = V((s * 0.65, 0.1, 0.2))
        for a in (-55, -15, 25, 70, 160):
            d = V((math.sin(math.radians(a)) * s, math.cos(math.radians(a)), 0))
            knee.tube([foot, foot + d * 0.5 + V((0, 0, -0.1)), foot + d * 0.95 + V((0, 0, -0.18))], [0.14, 0.09, 0.0], "bark", sides=5)
    if alpha:
        crown = A.segment("Trophy_AntlerCrown", (0, 0.05, 6.3), head)
        for s in (1, -1):
            base = V((s * 0.45, 0.05, 6.25))
            tip = base + V((s * 0.9, -0.2, 1.3))
            crown.tube([base, base.lerp(tip, 0.5) + V((s * 0.15, 0, 0)), tip], [0.11, 0.08, 0.03], "gold", sides=6)
            for k, t in enumerate((0.35, 0.6, 0.85)):
                p = base.lerp(tip, t)
                crown.spike(p, p + V((s * 0.15, 0.35 if k % 2 else -0.15, 0.45)), 0.05, "gold_dark" if k % 2 else "gold", segs=4)
        crown.torus(0.6, 0.06, "gold", loc=(0, 0.05, 6.22), major=14, minor=4)
        crown.sphere(0.1, BLOOM, loc=(0, 0.7, 6.25), segs=6, rings=4)
    return A


def rotwood_keeper(alpha=False):
    A = M.MobAsset("alpha_rotwood_keeper" if alpha else "elite_rotwood_keeper", "TREANT", ATLAS_ALPHA if alpha else ATLAS, "ALPHA" if alpha else "ELITE")
    treant(A, alpha=alpha)
    return scaled(A, 1.25)


def blight_sovereign():
    A = M.MobAsset("boss_blight_sovereign", "GROVE_COLOSSUS", ATLAS, "BOSS")
    treant(A, boss=True)
    return scaled(A, 2.2)


BUILDERS = {
    "mob_blight_wolf": blight_wolf,
    "mob_thorn_weaver": thorn_weaver,
    "mob_rot_mender": rot_mender,
    "elite_rotwood_keeper": lambda: rotwood_keeper(False),
    "alpha_rotwood_keeper": lambda: rotwood_keeper(True),
    "boss_blight_sovereign": blight_sovereign,
}
