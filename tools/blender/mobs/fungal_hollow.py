"""
Biome 2: Fungal Hollow (floors 6-10). docs/tower-mob-remodel-plan.md §5.2.
Bioluminescent caves. Motif: gill fans and spore-glow freckles. Glow: cyan-teal, with violet accents.

Blender coordinates: 1 unit = 1 stud, Z up, ground z = 0, enemies face +Y, their right hand is +X.
Joint names and parents follow TowerEnemyClips (mob_kit.BIPED / mob_kit.CRAWLER).
"""
import math, random
from mathutils import Vector
import raid_kit as K
import mob_kit as M

V = Vector
K.GLOW["spore"] = (110, 255, 220)
GLOW = "glow:spore"
VIO = "glow:violet"
AMBER = "glow:gold"

ATLAS = M.Atlas("fungal_hollow", {
    "cap_violet": (128, 78, 160), "cap_dark": (76, 44, 104), "cap_light": (178, 128, 206), "cap_teal": (62, 146, 138),
    "stalk": (220, 210, 188), "stalk_dark": (156, 142, 122), "gill": (204, 166, 186), "gill_dark": (136, 100, 126),
    "flesh": (188, 156, 176), "mycelium": (236, 230, 218), "shelf": (182, 124, 72), "shelf_dark": (116, 76, 44),
    "rock": (74, 76, 92), "rock_dark": (46, 48, 62), "moss_blue": (62, 100, 108),
    "robe": (70, 56, 92), "robe_dark": (42, 34, 60), "rope": (156, 124, 92), "brass": (200, 156, 86), "brass_dark": (134, 98, 50),
    "chitin_dark": (40, 32, 50), "eye": (14, 14, 20), "bone": (214, 204, 184),
})
ATLAS_ALPHA = M.Atlas("fungal_hollow_alpha", dict(ATLAS.colours, **{
    "cap_teal": (226, 156, 60), "cap_violet": (214, 146, 64), "cap_dark": (150, 96, 40),
    "shelf": (240, 196, 98), "shelf_dark": (178, 132, 54), "gill": (236, 206, 150), "gill_dark": (182, 142, 86),
}))


# ---------------------------------------------------------------------------- motif helpers
def cap(seg, centre, radius, height, colour, gill="gill", gill_dark="gill_dark", spots=0, spot=GLOW, stalk_r=None, seed=0, gills=14):
    """A mushroom cap: a dome, a gilled underside (cone + radial ridges) and optional glowing freckles."""
    c = V(centre)
    seg.sphere(radius, colour, loc=c, scale=(1, 1, height / radius), segs=14, rings=8)
    sr = stalk_r or radius * 0.22
    seg.cyl(radius * 0.97, sr, height * 0.55, gill, loc=c - V((0, 0, height * 0.3)), segs=14)
    for k in range(gills):
        a = 2 * math.pi * k / gills
        d = V((math.cos(a), math.sin(a), 0))
        seg.box((radius * 0.72, 0.05 * radius + 0.02, height * 0.18), gill_dark,
                loc=c + d * (radius * 0.6) - V((0, 0, height * 0.42)), rot=(0, 0, math.degrees(a)))
    rnd = random.Random(seed)
    for k in range(spots):
        a = rnd.uniform(0, 2 * math.pi)
        e = rnd.uniform(0.25, 1.05)
        n = V((math.cos(a) * math.cos(e), math.sin(a) * math.cos(e), math.sin(e)))
        p = c + V((n.x * radius, n.y * radius, n.z * height))
        seg.sphere(rnd.uniform(0.06, 0.11) * radius + 0.03, spot, loc=p, scale=(1, 1, 0.5), segs=6, rings=4)


def bracket(seg, at, out, width, colour, rim, tiers=3, seed=0):
    """Shelf (bracket) fungi stacked on a surface: half-discs sticking out along `out`."""
    rnd = random.Random(seed)
    at, out = V(at), V(out).normalized()
    side = out.cross(V((0, 0, 1))).normalized()
    for k in range(tiers):
        w = width * (1 - k * 0.22) * rnd.uniform(0.9, 1.1)
        base = at + V((0, 0, k * width * 0.32))
        pts = [(math.cos(t) * w, math.sin(t) * w * 0.75) for t in [math.pi * i / 6 for i in range(7)]]
        from mathutils import Matrix
        # frame: local X = along the surface, local Y = out of it, local Z = up
        frame = Matrix(((side.x, out.x, 0, base.x), (side.y, out.y, 0, base.y), (side.z, out.z, 1, base.z), (0, 0, 0, 1)))
        # prism profiles are (x, z) extruded along local Y; Rx(-90) lays the half-disc flat, bulging out
        seg.prism([(x, y) for x, y in pts], width * 0.12, colour, mat=frame @ K.M(rot=(-90, 0, 0)))
        seg.tube([frame @ V((math.cos(t) * w, math.sin(t) * w * 0.75, 0)) for t in [math.pi * i / 6 for i in range(7)]],
                 [width * 0.035] * 7, rim, sides=4)


def lantern(seg, centre, radius, height, cage, core, top, ribs=6):
    """A caged lantern: glowing core inside vertical ribs, a cap on top and a ring at the base."""
    c = V(centre)
    seg.sphere(radius * 0.72, core, loc=c, scale=(1, 1, height / radius * 0.75), segs=14, rings=8)
    for k in range(ribs):
        a = 2 * math.pi * k / ribs
        d = V((math.cos(a), math.sin(a), 0))
        pts = [c + d * radius * f + V((0, 0, z * height)) for f, z in ((0.55, -0.95), (1.0, -0.4), (1.05, 0.2), (0.6, 0.95))]
        seg.tube(pts, [radius * 0.09] * 4, cage, sides=5)
    seg.torus(radius * 0.6, radius * 0.1, cage, loc=c - V((0, 0, height * 0.95)), major=14, minor=5)
    seg.sphere(radius * 0.75, top, loc=c + V((0, 0, height * 0.98)), scale=(1, 1, 0.55), segs=14, rings=7)


def morel(seg, centre, radius, height, colour, pit, seed=0):
    """A pitted morel cap: an elongated lumpy cone with dark honeycomb pits."""
    c = V(centre)
    seg.ico(radius, colour, loc=c, scale=(1, 1, height / radius), subdiv=2, jitter=0.1, seed=seed)
    rnd = random.Random(seed + 7)
    for k in range(int(10 + radius * 6)):
        a = rnd.uniform(0, 2 * math.pi)
        z = rnd.uniform(-0.75, 0.85)
        r = radius * math.sqrt(max(0.05, 1 - z * z)) * 0.98
        p = c + V((math.cos(a) * r, math.sin(a) * r, z * height))
        seg.sphere(radius * rnd.uniform(0.11, 0.17), pit, loc=p, scale=(1, 1, 1.3), segs=8, rings=5)


# ============================================================================ Spore Skitter (Regular, CRAWLER)
def spore_skitter():
    A = M.MobAsset("mob_spore_skitter", "CRAWLER", ATLAS, "REGULAR")
    body = A.segment("Body", (0, 0, 1.6))
    head = A.segment("Head", (0, 1.3, 1.5), body)
    rnd = random.Random(1)
    # puffball body with a gilled skirt and glowing freckles, little mushrooms sprouting from its back
    body.sphere(1.0, "stalk", loc=(0, -0.25, 1.95), scale=(1.15, 1.35, 0.95), segs=14, rings=9)
    body.cyl(1.15, 0.6, 0.5, "gill", loc=(0, -0.25, 1.15), segs=18)
    for k in range(10):
        a = 2 * math.pi * k / 10
        body.box((0.55, 0.06, 0.3), "gill_dark", loc=(math.cos(a) * 0.95, -0.25 + math.sin(a) * 1.1, 1.05), rot=(0, 0, math.degrees(a)))
    for k in range(10):
        a = rnd.uniform(0, 2 * math.pi)
        e = rnd.uniform(0.15, 1.2)
        n = V((math.cos(a) * math.cos(e), math.sin(a) * math.cos(e), math.sin(e)))
        body.sphere(rnd.uniform(0.07, 0.12), GLOW, loc=V((n.x * 1.15, -0.25 + n.y * 1.35, 1.95 + n.z * 0.95)), segs=6, rings=4)
    for k, (x, y, h, r) in enumerate(((-0.4, -0.6, 0.55, 0.34), (0.35, -0.9, 0.42, 0.27))):
        b = V((x, y, 2.75 - abs(y + 0.25) * 0.25))
        body.rod(b, b + V((0, 0, h)), 0.06, "stalk_dark", segs=6)
        cap(body, b + V((0, 0, h)), r, r * 0.6, "cap_violet" if k != 1 else "cap_teal", spots=3, seed=10 + k, gills=0)
    # small dark head, glowing eyes, feelers
    head.sphere(0.48, "chitin_dark", loc=(0, 1.55, 1.5), scale=(1.1, 1.0, 0.85), segs=14, rings=8)
    for s in (1, -1):
        head.sphere(0.13, GLOW, loc=(s * 0.25, 1.95, 1.62), segs=8, rings=5)
        feeler = A.segment("ExtraAntennaR" if s == 1 else "ExtraAntennaL", (s * 0.2, 1.8, 1.8), head)  # springs (mob_extras)
        feeler.tube([V((s * 0.2, 1.8, 1.8)), V((s * 0.45, 2.2, 2.25)), V((s * 0.6, 2.35, 2.35))], [0.04, 0.03, 0.0], "gill_dark", sides=5)
    for s, side in ((-1, "L"), (1, "R")):
        jaw = A.segment(f"Jaw{side}", (s * 0.28, 1.95, 1.35), head)
        jaw.tube([V((s * 0.28, 1.9, 1.35)), V((s * 0.35, 2.25, 1.3)), V((s * 0.12, 2.45, 1.25))], [0.09, 0.07, 0.0], "bone", sides=5)
    # six spindly legs, the joints picked out in gill pink
    for s in (-1, 1):
        for i in (1, 2, 3):
            y = (2 - i) * 1.05 - 0.2
            hip = V((s * 0.85, y, 1.45))
            knee = V((s * 1.95, y * 1.15, 2.35))
            foot = V((s * 2.55, y * 1.3, 0.0))
            leg = A.segment(f"Leg{s}_{i}", hip, body)
            shin = A.segment(f"Knee{s}_{i}", knee, leg)
            leg.tube([hip, hip.lerp(knee, 0.5) + V((0, 0, 0.15)), knee], [0.11, 0.09, 0.08], "chitin_dark", sides=6)
            shin.sphere(0.12, "gill", loc=knee, segs=8, rings=5)
            shin.tube([knee, knee.lerp(foot, 0.5) + V((s * 0.15, 0, 0.05)), foot + V((0, 0, 0.05))], [0.08, 0.06, 0.02], "chitin_dark", sides=6)
    return A


# ============================================================================ Lantern Spore (Regular, FUNGAL_BIPED)
def lantern_spore():
    A = M.MobAsset("mob_lantern_spore", "FUNGAL_BIPED", ATLAS, "REGULAR")
    body = A.segment("Body", (0, 0, 2.4))
    head = A.segment("Head", (0, 0, 4.3), body)
    # a pale stalk with a frilled ring (annulus) and mycelium threads
    body.tube([V((0, 0, 2.2)), V((0, 0.05, 3.1)), V((0, 0.05, 3.8)), V((0, 0, 4.35))], [0.5, 0.42, 0.36, 0.3], "stalk", sides=12)
    body.cyl(0.8, 0.38, 0.35, "gill", loc=(0, 0, 3.75), segs=16)
    for k in range(12):
        a = 2 * math.pi * k / 12
        body.box((0.08, 0.32, 0.4), "gill_dark", loc=(math.cos(a) * 0.62, math.sin(a) * 0.62, 3.62), rot=(0, 0, math.degrees(a)))
    M.vine_spiral(body, (0, 0.02), 0.47, 2.3, 3.5, 1.2, "mycelium", thick=0.04, seed=2)
    body.sphere(0.55, "stalk_dark", loc=(0, 0, 2.25), scale=(1, 0.9, 0.6), segs=12, rings=7)
    # head: a caged lantern with a glowing spore core, capped by a small violet mushroom
    lantern(head, (0, 0, 4.95), 0.62, 0.62, "cap_dark", GLOW, "cap_violet")
    cap(head, (0, 0, 5.75), 0.55, 0.32, "cap_violet", spots=5, seed=3, gills=10)
    head.spike((0, 0, 6.0), (0, 0, 6.4), 0.07, "cap_light", segs=5)
    # drooping tendril arms with glowing tips (it casts from them)
    for s, side in ((-1, "L"), (1, "R")):
        arm = A.segment(f"Arm{side}", (s * 0.42, 0, 4.0), body)
        fore = A.segment(f"Forearm{side}", (s * 0.85, 0.1, 3.25), arm)
        arm.tube([V((s * 0.35, 0, 4.05)), V((s * 0.7, 0.05, 3.7)), V((s * 0.85, 0.1, 3.25))], [0.12, 0.1, 0.09], "flesh", sides=7)
        pts = [V((s * 0.85, 0.1, 3.25)), V((s * 0.95, 0.3, 2.7)), V((s * 0.85, 0.5, 2.25)), V((s * 0.65, 0.55, 2.05))]
        fore.tube(pts, [0.09, 0.08, 0.06, 0.03], "flesh", sides=6)
        fore.sphere(0.11, GLOW, loc=pts[-1], segs=8, rings=5)
        for k in (1, 2):
            fore.sphere(0.05, VIO, loc=pts[k] + V((s * 0.07, 0.05, 0)), segs=6, rings=4)
    # stubby root feet spreading into mycelium
    for s, side in ((-1, "L"), (1, "R")):
        leg = A.segment(f"Leg{side}", (s * 0.28, 0, 2.2), body)
        knee = A.segment(f"Knee{side}", (s * 0.33, 0.05, 1.15), leg)
        leg.tube([V((s * 0.28, 0, 2.25)), V((s * 0.31, 0.03, 1.7)), V((s * 0.33, 0.05, 1.15))], [0.2, 0.18, 0.16], "stalk_dark", sides=8)
        knee.tube([V((s * 0.33, 0.05, 1.15)), V((s * 0.36, 0.08, 0.55)), V((s * 0.4, 0.1, 0.1))], [0.16, 0.18, 0.24], "stalk_dark", sides=8)
        for t in (-0.7, -0.2, 0.3, 0.8):
            f = V((s * 0.4, 0.1, 0.08))
            knee.tube([f, f + V((s * 0.25 + t * 0.15, 0.4 * math.cos(t), -0.06))], [0.06, 0.0], "mycelium", sides=4)
    return A


# ============================================================================ Sporecap Chanter (Support, FUNGAL_BIPED)
def sporecap_chanter():
    A = M.MobAsset("mob_sporecap_chanter", "FUNGAL_BIPED", ATLAS, "SUPPORT")
    body = A.segment("Body", (0, 0, 2.2))
    head = A.segment("Head", (0, 0.35, 3.7), body)
    # hunched monk: a wide hooded robe, rope belt, hanging prayer tags
    body.tube([V((0, -0.05, 0.25)), V((0, 0, 1.3)), V((0, 0.1, 2.5)), V((0, 0.3, 3.55))], [(0.95, 0.85), (0.8, 0.7), (0.62, 0.55), (0.5, 0.45)], "robe", sides=12)
    body.tube([V((0, -0.05, 0.25)), V((0, -0.04, 0.45))], [(0.98, 0.88), (0.95, 0.85)], "robe_dark", sides=12)
    body.torus(0.68, 0.07, "rope", loc=(0, 0.05, 2.0), major=16, minor=5)
    for k, x in enumerate((-0.3, 0.05, 0.35)):
        body.tube([V((x, 0.66, 1.95)), V((x + 0.03, 0.72, 1.4))], [0.035, 0.03], "rope", sides=4)
        body.box((0.16, 0.04, 0.22), "brass", loc=(x + 0.03, 0.73, 1.3))
    body.tube([V((0, -0.3, 3.4)), V((0, -0.45, 3.85)), V((0, -0.2, 4.1))], [0.48, 0.42, 0.2], "robe_dark", sides=10)  # hood folds
    # head: a shadowed face under a wide spotted brim cap, a beard of mycelium threads
    head.sphere(0.36, "flesh", loc=(0, 0.5, 3.85), segs=12, rings=8)
    for s in (1, -1):
        head.sphere(0.07, GLOW, loc=(s * 0.13, 0.82, 3.9), segs=6, rings=4)
    for k in range(7):
        x = (k - 3) * 0.08
        head.tube([V((x, 0.72, 3.7)), V((x * 1.2, 0.8, 3.4)), V((x * 1.4, 0.75, 3.15))], [0.03, 0.025, 0.0], "mycelium", sides=4)
    cap(head, (0, 0.45, 4.35), 1.2, 0.5, "cap_violet", spots=9, seed=5, stalk_r=0.3, gills=18)
    # arms in wide sleeves; the right hand swings a brass censer of glowing spores, the left is raised
    for s, side in ((-1, "L"), (1, "R")):
        arm = A.segment(f"Arm{side}", (s * 0.48, 0.25, 3.3), body)
        fore = A.segment(f"Forearm{side}", (s * 0.75, 0.45, 2.65), arm)
        arm.tube([V((s * 0.45, 0.25, 3.35)), V((s * 0.65, 0.35, 2.95)), V((s * 0.75, 0.45, 2.65))], [0.2, 0.22, 0.24], "robe", sides=8)
        fore.tube([V((s * 0.75, 0.45, 2.65)), V((s * 0.8, 0.7, 2.35)), V((s * 0.82, 0.85, 2.2))], [0.26, 0.3, 0.33], "robe_dark", sides=8)
        fore.sphere(0.13, "flesh", loc=(s * 0.82, 0.92, 2.12), segs=8, rings=5)
        if s == 1:
            top = V((0.82, 0.95, 2.05))
            bot = V((0.85, 1.05, 1.25))
            censer = A.segment("ExtraCenser", top, fore)  # swings on its chain (Hanging spring)
            censer.tube([top, top.lerp(bot, 0.5) + V((0.02, 0, 0)), bot], [0.025] * 3, "brass_dark", sides=4)
            censer.sphere(0.24, "brass", loc=bot - V((0, 0, 0.18)), segs=12, rings=8)
            censer.torus(0.24, 0.04, "brass_dark", loc=bot - V((0, 0, 0.12)), major=12, minor=4)
            censer.sphere(0.12, GLOW, loc=bot - V((0, 0, 0.0)), segs=8, rings=5)
            for k in range(3):
                censer.sphere(0.07 + k * 0.025, GLOW, loc=bot + V((0.05 * k, 0.05, 0.22 + k * 0.2)), segs=6, rings=4)
    # short legs and sandaled feet under the robe hem
    for s, side in ((-1, "L"), (1, "R")):
        leg = A.segment(f"Leg{side}", (s * 0.25, 0, 2.05), body)
        knee = A.segment(f"Knee{side}", (s * 0.28, 0.05, 1.05), leg)
        leg.tube([V((s * 0.25, 0, 2.1)), V((s * 0.28, 0.05, 1.05))], [0.16, 0.14], "robe_dark", sides=7)
        knee.tube([V((s * 0.28, 0.05, 1.05)), V((s * 0.3, 0.1, 0.25))], [0.13, 0.12], "flesh", sides=7)
        knee.box((0.3, 0.55, 0.14), "rope", loc=(s * 0.3, 0.25, 0.07), bevel=0.04)
    return A


# ============================================================================ Mycelial Brute Elite / Alpha (HEAVY_BIPED)
def mycelial_brute(alpha=False):
    A = M.MobAsset("alpha_mycelial_brute" if alpha else "elite_mycelial_brute", "HEAVY_BIPED", ATLAS_ALPHA if alpha else ATLAS, "ALPHA" if alpha else "ELITE")
    body = A.segment("Body", (0, 0, 3.6))
    head = A.segment("Head", (0, 0.75, 6.5), body)
    # hulking fungal torso: a pale barrel with a glowing mycelium web, shelf fungi on shoulders and back
    body.sphere(1.0, "flesh", loc=(0, 0, 3.7), scale=(1.4, 1.1, 0.75), segs=16, rings=10)
    body.tube([V((0, 0, 3.6)), V((0, 0.15, 4.6)), V((0, 0.35, 5.6)), V((0, 0.5, 6.4))], [(1.5, 1.15), (1.85, 1.35), (2.05, 1.4), (1.5, 1.05)], "stalk", sides=14)
    for k in range(7):  # the web: glowing veins over the chest and belly
        a = math.radians(-60 + k * 20)
        pts = [V((math.sin(a) * r * 1.9, 1.15 + 0.35 * (z - 3.6) / 2.8 + math.cos(a) * 0.15, z)) for r, z in ((0.25, 3.9), (0.55, 4.6), (0.85, 5.3), (0.7, 6.1))]
        body.tube(pts, [0.05, 0.06, 0.06, 0.04], GLOW, sides=4)
    for z in (4.4, 5.2):
        body.torus(1.0, 0.035, "mycelium", mat=K.M((0, 1.05 + (z - 3.6) * 0.12, z), (90, 0, 0)) @ K.M(scale=(1.6, 0.5, 1)), major=18, minor=4)
    for k, (x, y, z, ox, oy) in enumerate(((-1.5, -0.6, 5.9, -1, -0.3), (1.6, -0.5, 6.0, 1, -0.3), (0.0, -1.2, 5.0, 0, -1), (-0.8, -1.1, 4.2, -0.4, -1))):
        bracket(body, (x, y, z), (ox, oy, 0), 0.9 if k < 2 else 1.1, "shelf", "shelf_dark", tiers=3, seed=20 + k)
    for k, (x, y) in enumerate(((0.6, -0.9), (-0.3, -1.0), (1.2, 0.2))):
        b = V((x, y, 6.25))
        body.rod(b, b + V((0, 0, 0.4 + k * 0.1)), 0.07, "stalk_dark", segs=6)
        cap(body, b + V((0, 0, 0.45 + k * 0.1)), 0.32, 0.2, "cap_teal", spots=2, seed=30 + k, gills=0)
    # head: a small skull-like stalk head under a broad teal cap, glowing eyes in the shadow of the brim
    head.sphere(0.6, "stalk_dark", loc=(0, 1.0, 6.75), scale=(1.0, 0.95, 0.9), segs=14, rings=8)
    head.box((0.8, 0.4, 0.3), "bone", loc=(0, 1.45, 6.4), bevel=0.08)
    for s in (1, -1):
        head.sphere(0.11, GLOW, loc=(s * 0.24, 1.5, 6.9), segs=8, rings=5)
    cap(head, (0, 0.9, 7.35), 1.25, 0.55, "cap_teal", spots=8, seed=31, stalk_r=0.35, gills=16)
    # massive arms; the forearms are clubs of stacked bracket fungi
    for s, side in ((-1, "L"), (1, "R")):
        arm = A.segment(f"Arm{side}", (s * 2.0, 0.2, 6.0), body)
        fore = A.segment(f"Forearm{side}", (s * 2.5, 0.5, 4.3), arm)
        arm.sphere(0.85, "stalk", loc=(s * 2.0, 0.2, 6.05), segs=14, rings=8)
        arm.tube([V((s * 2.1, 0.25, 5.8)), V((s * 2.35, 0.4, 5.0)), V((s * 2.5, 0.5, 4.3))], [0.62, 0.55, 0.5], "flesh", sides=10)
        fore.sphere(0.5, "stalk_dark", loc=(s * 2.5, 0.5, 4.3), segs=12, rings=7)
        fore.tube([V((s * 2.5, 0.55, 4.2)), V((s * 2.6, 0.75, 3.1)), V((s * 2.65, 0.9, 1.95))], [0.62, 0.85, 0.95], "shelf_dark", sides=10)
        for k, z in enumerate((3.4, 2.5)):
            for a in (20, 140, 260):
                ang = math.radians(a + k * 40)
                bracket(fore, (s * 2.62 + math.cos(ang) * 0.75, 0.82 + math.sin(ang) * 0.75, z), (math.cos(ang), math.sin(ang), 0), 0.55, "shelf", "shelf_dark", tiers=1, seed=40 + k * 3 + a)
        fore.sphere(0.95, "shelf_dark", loc=(s * 2.65, 0.95, 1.8), scale=(1, 1, 0.8), segs=12, rings=8)
        M.moss(fore, (s * 2.65, 0.95, 1.4), 0.25, 3, "mycelium", seed=50 + s, flat=0.4, spread=0.55)
    for s, side in ((-1, "L"), (1, "R")):
        leg = A.segment(f"Leg{side}", (s * 0.95, 0, 3.15), body)
        knee = A.segment(f"Knee{side}", (s * 1.05, 0.1, 1.7), leg)
        leg.tube([V((s * 0.95, 0, 3.2)), V((s * 1.05, 0.1, 1.7))], [0.62, 0.55], "stalk", sides=10)
        knee.sphere(0.5, "stalk_dark", loc=(s * 1.05, 0.15, 1.7), segs=10, rings=6)
        knee.tube([V((s * 1.05, 0.1, 1.6)), V((s * 1.1, 0.15, 0.35))], [0.5, 0.62], "stalk", sides=10)
        knee.sphere(0.75, "stalk_dark", loc=(s * 1.1, 0.35, 0.25), scale=(1.0, 1.25, 0.4), segs=12, rings=7)
        for t in (-0.6, 0.0, 0.6):
            f = V((s * 1.1, 0.35, 0.1))
            knee.tube([f, f + V((s * 0.35 + t * 0.4, 0.6 * math.cos(t), -0.08))], [0.08, 0.0], "mycelium", sides=4)
    if alpha:
        # trophies: a crown of amber caps, and gilded gill fans rising from the shoulders
        crown = A.segment("Trophy_Crown", (0, 0.9, 7.9), head)
        for k in range(5):
            a = 2 * math.pi * k / 5 + math.pi / 2
            b = V((math.cos(a) * 0.9, 0.9 + math.sin(a) * 0.9, 7.75))
            crown.rod(b, b + V((0, 0, 0.45)), 0.07, "stalk", segs=5)
            cap(crown, b + V((0, 0, 0.5)), 0.26, 0.17, "cap_violet", spots=1, spot=AMBER, seed=60 + k, gills=0)
        crown.torus(0.9, 0.08, "shelf", loc=(0, 0.9, 7.78), major=20, minor=5)
        fans = A.segment("Trophy_Fans", (0, -0.4, 6.2), body)
        for s in (1, -1):
            for k in range(5):
                a = math.radians(-20 + k * 18)
                b = V((s * 1.3, -0.6, 6.2))
                tip = b + V((s * math.cos(a) * 1.6, -0.3, math.sin(a) * 1.4 + 0.9))
                M.leaf(fans, b, tip, 0.45, "gill", up=(0, 1, 0))
            fans.sphere(0.18, AMBER, loc=(s * 1.3, -0.6, 6.25), segs=8, rings=5)
    return A


# ============================================================================ Spore Matriarch (Biome Boss, FUNGAL_COLOSSUS)
def spore_matriarch():
    A = M.MobAsset("boss_spore_matriarch", "FUNGAL_COLOSSUS", ATLAS, "BOSS")
    body = A.segment("Body", (0, 0, 6.6))
    head = A.segment("Head", (0, 0.3, 11.5), body)
    rnd = random.Random(70)
    # a skirt of heavy tendrils from the waist, a tall stem body widening to the shoulders
    skirt = A.segment("ExtraSkirt", (0, 0, 6.4), body)  # the tendril skirt (Cloth spring)
    for k in range(14):
        a = 2 * math.pi * k / 14 + rnd.uniform(-0.1, 0.1)
        d = V((math.cos(a), math.sin(a), 0))
        top = V((0, 0, 6.4)) + d * 1.6
        pts = [top, top + d * 1.2 + V((0, 0, -1.6)), top + d * 2.6 + V((0, 0, -3.6)), top + d * 3.2 + V((0, 0, -5.4)), top + d * 3.9 + V((0, 0, -6.2))]
        skirt.tube(pts, [0.55, 0.5, 0.42, 0.3, 0.12], "cap_dark" if k % 2 else "robe", sides=8)
        skirt.sphere(0.12, GLOW, loc=pts[2] + d * 0.42, segs=6, rings=4)
    body.cyl(2.4, 1.7, 1.2, "gill", loc=(0, 0, 6.6), segs=20)
    body.tube([V((0, 0, 6.6)), V((0, 0.2, 8.2)), V((0, 0.35, 9.8)), V((0, 0.3, 11.2))], [(1.7, 1.4), (1.6, 1.3), (2.3, 1.6), (1.6, 1.2)], "stalk", sides=16)
    for k in range(9):  # glowing mycelium veins up the stem
        a = math.radians(-80 + k * 20)
        pts = [V((math.sin(a) * w, 0.2 + math.cos(a) * w * 0.8, z)) for w, z in ((1.75, 6.8), (1.65, 8.2), (2.1, 9.6), (1.7, 11.0))]
        body.tube(pts, [0.06, 0.07, 0.07, 0.05], GLOW if k % 2 == 0 else VIO, sides=4)
    body.torus(2.35, 0.12, "mycelium", loc=(0, 0.3, 9.8), major=24, minor=5)
    # spore-sac lanterns hanging from the shoulders and back
    for k, (x, y) in enumerate(((-2.2, -0.6), (2.2, -0.6), (-1.0, -1.6), (1.1, -1.6))):
        top = V((x, y, 10.9))
        low = top + V((x * 0.15, y * 0.2, -1.4))
        sac = A.segment(f"ExtraSacs{k + 1}", top, body)  # each sac swings on its stalk (Hanging spring)
        sac.tube([top, top.lerp(low, 0.5) + V((0, 0, 0.1)), low], [0.08, 0.07, 0.06], "stalk_dark", sides=5)
        lantern(sac, low - V((0, 0, 0.55)), 0.42, 0.45, "cap_dark", GLOW, "cap_violet", ribs=5)
    # head: a face of gills under three tiers of pitted morel crown, rising to a point
    head.sphere(1.05, "flesh", loc=(0, 0.75, 12.1), scale=(1.0, 0.9, 1.0), segs=16, rings=10)
    for s in (1, -1):
        head.sphere(0.18, GLOW, loc=(s * 0.38, 1.62, 12.3), segs=8, rings=5)
    for k in range(9):
        x = (k - 4) * 0.2
        head.tube([V((x, 1.5, 11.75)), V((x * 1.1, 1.65, 11.2)), V((x * 1.2, 1.55, 10.7))], [0.05, 0.04, 0.0], "gill", sides=4)
    cap(head, (0, 0.4, 13.0), 2.6, 0.9, "cap_violet", spots=12, seed=80, stalk_r=0.9, gills=22)
    crown = A.segment("ExtraCrown", (0, 0.3, 13.6), head)  # the morel tiers: keyed to rise for Signatures later
    morel(crown, (0, 0.3, 14.3), 1.7, 1.2, "cap_dark", "robe_dark", seed=81)
    morel(crown, (0, 0.25, 15.6), 1.0, 1.0, "cap_violet", "cap_dark", seed=82)
    crown.spike((0, 0.25, 16.4), (0, 0.2, 17.2), 0.25, "cap_light", segs=6)
    # long tendril arms ending in gill-fan hands with glowing tips
    for s, side in ((-1, "L"), (1, "R")):
        arm = A.segment(f"Arm{side}", (s * 2.3, 0.3, 10.7), body)
        fore = A.segment(f"Forearm{side}", (s * 3.5, 0.8, 8.2), arm)
        arm.sphere(0.85, "stalk_dark", loc=(s * 2.3, 0.3, 10.7), segs=12, rings=7)
        arm.tube([V((s * 2.4, 0.35, 10.5)), V((s * 3.1, 0.55, 9.4)), V((s * 3.5, 0.8, 8.2))], [0.62, 0.55, 0.5], "flesh", sides=10)
        bracket(arm, (s * 2.7, -0.2, 10.3), (s, -0.4, 0), 0.8, "shelf", "shelf_dark", tiers=2, seed=90 + s)
        pts = [V((s * 3.5, 0.8, 8.2)), V((s * 3.8, 1.2, 7.0)), V((s * 3.85, 1.5, 6.0))]
        fore.tube(pts, [0.5, 0.45, 0.4], "flesh", sides=10)
        palm = pts[-1]
        for k in range(5):
            a = math.radians(-50 + k * 25)
            tip = palm + V((s * math.sin(a) * 0.4, 0.6 + math.cos(a) * 0.3, -1.6 + abs(k - 2) * 0.2))
            M.leaf(fore, palm, tip, 0.6, "gill", up=(0, 1, 0))
            fore.sphere(0.1, GLOW, loc=tip, segs=6, rings=4)
    # thick stalk legs inside the skirt, splayed root feet
    for s, side in ((-1, "L"), (1, "R")):
        leg = A.segment(f"Leg{side}", (s * 1.3, 0, 6.3), body)
        knee = A.segment(f"Knee{side}", (s * 1.6, 0.3, 3.4), leg)
        leg.tube([V((s * 1.3, 0, 6.4)), V((s * 1.6, 0.3, 3.4))], [0.95, 0.85], "stalk_dark", sides=10)
        knee.sphere(0.85, "stalk", loc=(s * 1.6, 0.35, 3.4), segs=12, rings=7)
        knee.tube([V((s * 1.6, 0.3, 3.3)), V((s * 1.7, 0.4, 0.6))], [0.8, 1.0], "stalk_dark", sides=10)
        knee.sphere(1.2, "stalk", loc=(s * 1.7, 0.6, 0.45), scale=(1.0, 1.3, 0.4), segs=14, rings=7)
        for t in (-0.7, -0.2, 0.3, 0.8):
            f = V((s * 1.7, 0.6, 0.2))
            knee.tube([f, f + V((s * 0.6 + t * 0.6, 1.1 * math.cos(t), -0.15))], [0.14, 0.0], "mycelium", sides=5)
    return A


BUILDERS = {
    "mob_spore_skitter": spore_skitter,
    "mob_lantern_spore": lantern_spore,
    "mob_sporecap_chanter": sporecap_chanter,
    "elite_mycelial_brute": lambda: mycelial_brute(False),
    "alpha_mycelial_brute": lambda: mycelial_brute(True),
    "boss_spore_matriarch": spore_matriarch,
}
