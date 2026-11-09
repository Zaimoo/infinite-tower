"""
Biome 1: Verdant Ruins (floors 1-5). docs/tower-mob-remodel-plan.md §5.1.
Overgrown temple stone and living moss. Motif: carved sun-disc glyphs half swallowed by vines. Glow: spring green.

Blender coordinates: 1 unit = 1 stud, Z up, ground z = 0, enemies face +Y, their right hand is +X.
Joint names and parents follow TowerEnemyClips (mob_kit.BIPED / mob_kit.CRAWLER).
"""
import math, random
from mathutils import Vector
import raid_kit as K
import mob_kit as M

V = Vector
K.GLOW["spring"] = (153, 240, 125)
GLOW = "glow:spring"
SUN = "glow:gold"

ATLAS = M.Atlas("verdant_ruins", {
    "stone": (146, 150, 136), "stone_dark": (98, 102, 94), "stone_warm": (170, 156, 126), "stone_deep": (62, 66, 60),
    "moss": (86, 136, 58), "moss_dark": (50, 92, 42), "moss_light": (138, 178, 76), "lichen": (178, 184, 126),
    "bark": (98, 70, 46), "bark_dark": (60, 42, 30), "root": (118, 88, 60),
    "vine": (70, 122, 50), "vine_dark": (46, 84, 38), "leaf": (82, 150, 62), "leaf_dark": (46, 104, 48),
    "petal": (236, 168, 196), "petal_white": (244, 238, 222), "pollen": (250, 214, 92),
    "gold": (214, 174, 80), "gold_dark": (150, 112, 50), "iron": (104, 120, 110), "iron_dark": (66, 78, 72),
    "chitin": (66, 82, 60), "chitin_dark": (38, 48, 38), "mandible": (196, 180, 140), "eye": (22, 26, 22),
})
# The Alpha's gilded set: same names, trims and armour turned to gold, stone warmed.
ATLAS_ALPHA = M.Atlas("verdant_ruins_alpha", dict(ATLAS.colours, **{
    "iron": (196, 158, 70), "iron_dark": (150, 112, 48), "bark": (170, 128, 62), "bark_dark": (122, 88, 40),
    "gold": (246, 210, 110), "gold_dark": (196, 150, 66), "stone_dark": (120, 104, 76),
}))


# ============================================================================ Moss Crawler (Regular, CRAWLER)
def moss_crawler():
    A = M.MobAsset("mob_moss_crawler", "SIX_LEGGED_CRAWLER", ATLAS, "REGULAR")
    body = A.segment("Body", (0, 0, 1.6))
    head = A.segment("Head", (0, 1.9, 1.5), body)
    # abdomen and thorax under a shell of three overlapping temple tiles
    body.sphere(1.0, "chitin_dark", loc=(0, -0.5, 1.55), scale=(1.55, 2.2, 0.72), segs=16, rings=10)
    body.sphere(1.0, "chitin", loc=(0, 1.25, 1.6), scale=(1.05, 0.8, 0.62), segs=14, rings=8)
    for i, (y, w, tilt) in enumerate(((1.0, 2.5, -10), (-0.3, 2.9, 0), (-1.6, 2.6, 10))):
        body.box((w, 1.45, 0.34), "stone" if i != 1 else "stone_warm", loc=(0, y, 2.18 - abs(y + 0.3) * 0.08), rot=(tilt, 0, 0), bevel=0.1)
        body.box((w + 0.08, 0.16, 0.38), "stone_dark", loc=(0, y - 0.66, 2.16 - abs(y + 0.3) * 0.08), rot=(tilt, 0, 0))
    M.sun_glyph(body, (0, -0.3, 2.37), (0, 0, 1), 0.42, "gold_dark", GLOW, rays=6, ring_thick=0.07)
    M.moss(body, (-0.7, 0.9, 2.35), 0.42, 3, "moss", seed=1, flat=0.6)
    M.moss(body, (0.8, -1.5, 2.3), 0.46, 4, "moss_light", seed=2, flat=0.6)
    M.moss(body, (0.65, 0.45, 2.38), 0.3, 2, "moss_dark", seed=3, flat=0.6)
    for k, (dx, dy) in enumerate(((-0.15, -1.9), (0.1, -1.95), (0.3, -1.85))):  # a fern sprouting from the rear tile
        b = V((-0.6 + dx, dy, 2.35))
        M.leaf(body, b, b + V((dx * 3 - 0.3, -0.5 - k * 0.15, 0.9 + k * 0.2)), 0.32, "leaf")
    # head: rounded, stone brow plate, glowing eyes, curling antennae
    head.sphere(0.72, "chitin", loc=(0, 2.25, 1.45), scale=(1.15, 1.0, 0.8), segs=14, rings=8)
    head.box((1.4, 0.7, 0.24), "stone", loc=(0, 2.25, 1.98), rot=(-14, 0, 0), bevel=0.08)
    for s in (1, -1):
        head.sphere(0.17, GLOW, loc=(s * 0.42, 2.82, 1.62), segs=8, rings=6)
        head.tube([V((s * 0.3, 2.5, 1.9)), V((s * 0.6, 2.9, 2.5)), V((s * 0.95, 3.0, 2.8)), V((s * 1.15, 2.8, 2.75))],
                  [0.06, 0.05, 0.04, 0.0], "vine", sides=5)
    # mandibles
    for s, side in ((-1, "L"), (1, "R")):
        jaw = A.segment(f"Jaw{side}", (s * 0.45, 2.85, 1.3), head)
        jaw.tube([V((s * 0.45, 2.75, 1.3)), V((s * 0.6, 3.2, 1.25)), V((s * 0.4, 3.6, 1.2)), V((s * 0.1, 3.75, 1.15))],
                 [0.16, 0.14, 0.1, 0.0], "mandible", sides=6)
    # six root-like legs: hip (Leg) out and up to the knee, then the shin (Knee) down to the ground
    for s in (-1, 1):
        for i in (1, 2, 3):
            y = (2 - i) * 1.3
            hip = V((s * 0.95, y, 1.45))
            knee = V((s * 2.05, y * 1.12, 2.0))
            foot = V((s * 2.75, y * 1.25, 0.0))
            leg = A.segment(f"Leg{s}_{i}", hip, body)
            shin = A.segment(f"Knee{s}_{i}", knee, leg)
            leg.sphere(0.2, "chitin_dark", loc=hip, segs=8, rings=6)
            leg.tube([hip, hip.lerp(knee, 0.5) + V((0, 0, 0.18)), knee], [0.17, 0.15, 0.13], "root", sides=7)
            shin.sphere(0.15, "root", loc=knee, segs=8, rings=5)
            mid = knee.lerp(foot, 0.5) + V((s * 0.15, 0, 0.1))
            shin.tube([knee, mid, foot + V((0, 0, 0.12))], [0.13, 0.1, 0.06], "bark", sides=6)
            for t in (-0.5, 0.5):  # root toes
                f = foot + V((0, 0, 0.06))
                shin.tube([f, f + V((s * 0.25, t * 0.35, -0.05))], [0.05, 0.0], "bark_dark", sides=4)
    return A


# ============================================================================ Ruin Guardian (Regular, ARMORED_BIPED)
def ruin_guardian():
    A = M.MobAsset("mob_ruin_guardian", "ARMORED_BIPED", ATLAS, "REGULAR")
    body = A.segment("Body", (0, 0, 3.0))
    head = A.segment("Head", (0, 0.1, 5.75), body)
    # pelvis, column-drum waist, carved chest block
    body.box((2.3, 1.5, 0.9), "stone_dark", loc=(0, 0, 3.05), bevel=0.14)
    M.column(body, (0, 0, 3.4), (0, 0, 4.35), 0.95, "stone", flutes=9)
    body.box((2.9, 1.8, 1.45), "stone_warm", loc=(0, 0.05, 5.0), bevel=0.2)
    body.box((3.2, 1.6, 0.45), "stone", loc=(0, 0, 5.55), bevel=0.12)  # shoulder lintel
    M.sun_glyph(body, (0, 0.98, 5.0), (0, 1, 0), 0.42, "gold_dark", GLOW, rays=8)
    for x, z, w in ((-0.9, 4.6, 0.9), (0.7, 5.3, 0.6)):  # weathering cracks
        body.box((w, 0.06, 0.08), "stone_deep", loc=(x, 0.97, z), rot=(0, 25, 0))
    M.vine_spiral(body, (0, 0), 1.02, 3.3, 5.6, 1.3, "vine", thick=0.1, leaves=7, leaf_colour="leaf", seed=4, rx=1.5)
    M.moss(body, (-1.05, 0.1, 5.85), 0.36, 3, "moss", seed=5)
    M.moss(body, (1.0, -0.3, 5.82), 0.3, 2, "moss_light", seed=6)
    M.column(body, (0.5, -0.9, 5.0), (0.55, -1.05, 6.2), 0.28, "stone_dark", flutes=6, broken=True, seed=7)  # broken pillar on the back
    # head: weathered slab with one glyph eye, mossy cap, a sprig
    head.box((1.25, 1.15, 1.25), "stone", loc=(0, 0.1, 6.35), bevel=0.15)
    head.box((1.4, 0.5, 0.32), "stone_dark", loc=(0, 0.5, 6.78), bevel=0.08)  # brow
    head.box((0.5, 0.2, 0.24), GLOW, loc=(0, 0.7, 6.45))
    head.box((0.36, 0.3, 0.3), "stone_deep", loc=(0.48, 0.55, 6.0), rot=(0, 0, 20))  # chipped cheek
    M.moss(head, (0, 0.0, 7.0), 0.36, 3, "moss", seed=8, flat=0.35)
    M.leaf(head, V((0.3, -0.1, 7.05)), V((0.55, -0.2, 7.6)), 0.22, "leaf")
    M.leaf(head, V((0.3, -0.1, 7.05)), V((0.05, -0.35, 7.55)), 0.18, "leaf_dark")
    # arms: boulder pauldrons, vine-bound stone gauntlets; the right fist is a heavy hammer-block
    for s, side in ((-1, "L"), (1, "R")):
        arm = A.segment(f"Arm{side}", (s * 1.75, 0, 5.4), body)
        fore = A.segment(f"Forearm{side}", (s * 1.95, 0.05, 4.05), arm)
        arm.ico(0.7, "stone", loc=(s * 1.85, 0, 5.6), scale=(1.1, 1.0, 0.85), subdiv=1, jitter=0.12, seed=10 + s)
        arm.rod((s * 1.8, 0, 5.3), (s * 1.95, 0.05, 4.15), 0.42, "stone_dark", segs=10, r2=0.38)
        M.moss(arm, (s * 1.95, -0.1, 6.15), 0.24, 2, "moss_light", seed=12 + s)
        fore.sphere(0.4, "stone", loc=(s * 1.95, 0.05, 4.05), segs=10, rings=7)
        fore.rod((s * 1.95, 0.05, 4.0), (s * 2.0, 0.15, 2.95), 0.5, "stone", segs=10, r2=0.56)
        M.vine_spiral(fore, (s * 1.97, 0.1), 0.55, 3.1, 3.9, 1.4, "vine_dark", thick=0.08, leaves=3, leaf_colour="leaf", seed=14 + s)
        fist = 0.95 if s == 1 else 0.75
        fore.box((fist, fist * 0.95, fist * 0.9), "stone_warm", loc=(s * 2.02, 0.2, 2.55), bevel=0.12)
        if s == 1:
            fore.box((1.1, 0.25, 0.2), "gold_dark", loc=(2.02, 0.2, 2.9), bevel=0.04)
    # legs: thick stone thighs, shins and plinth feet
    for s, side in ((-1, "L"), (1, "R")):
        leg = A.segment(f"Leg{side}", (s * 0.65, 0, 2.75), body)
        knee = A.segment(f"Knee{side}", (s * 0.7, 0.05, 1.45), leg)
        leg.rod((s * 0.65, 0, 2.8), (s * 0.7, 0.05, 1.5), 0.5, "stone_dark", segs=10, r2=0.45)
        knee.sphere(0.42, "stone", loc=(s * 0.7, 0.12, 1.45), segs=10, rings=7)
        knee.rod((s * 0.7, 0.05, 1.4), (s * 0.72, 0.05, 0.45), 0.42, "stone", segs=10, r2=0.48)
        knee.box((0.95, 1.45, 0.45), "stone_dark", loc=(s * 0.72, 0.22, 0.22), bevel=0.1)
        M.moss(knee, (s * 0.75, 0.6, 0.45), 0.2, 2, "moss", seed=20 + s)
    return A


# ============================================================================ Bloom Tender (Support, ROOTED_BIPED)
def bloom_tender():
    A = M.MobAsset("mob_bloom_tender", "ROOTED_BIPED", ATLAS, "SUPPORT")
    body = A.segment("Body", (0, 0, 2.4))
    head = A.segment("Head", (0, 0.05, 4.15), body)
    # slender sprout body: green stem torso wrapped in leaves, a skirt of hanging petal-leaves
    body.tube([V((0, 0, 2.2)), V((0, 0.05, 3.0)), V((0, 0.08, 3.7)), V((0, 0.05, 4.15))], [0.42, 0.36, 0.42, 0.24], "leaf", sides=10)
    for k in range(9):
        a = 2 * math.pi * k / 9
        b = V((math.cos(a) * 0.4, math.sin(a) * 0.4, 2.55))
        tip = V((math.cos(a) * 0.95, math.sin(a) * 0.95, 1.35))
        M.leaf(body, b, tip, 0.5, "leaf_dark" if k % 2 else "leaf", up=(math.cos(a), math.sin(a), 0))
    for k in range(5):
        a = 2 * math.pi * k / 5 + 0.3
        b = V((math.cos(a) * 0.35, math.sin(a) * 0.35, 3.0))
        M.leaf(body, b, b + V((math.cos(a) * 0.15, math.sin(a) * 0.15, 1.0)), 0.36, "leaf", up=(math.cos(a), math.sin(a), 0))
    body.sphere(0.2, GLOW, loc=(0, 0.33, 3.45), segs=10, rings=6)  # heart bud
    # head: a soft bud face under a lily-pad hood, crowned by a blossom with a glowing pollen heart
    head.sphere(0.48, "leaf", loc=(0, 0.05, 4.62), scale=(0.95, 0.9, 1.05), segs=14, rings=10)
    head.cyl(0.95, 0.9, 0.08, "leaf_dark", loc=(0, -0.25, 4.85), rot=(-62, 0, 0), segs=16)  # lily-pad hood
    for s in (1, -1):
        head.sphere(0.09, GLOW, loc=(s * 0.18, 0.47, 4.66), segs=8, rings=5)
    for k in range(6):
        a = 2 * math.pi * k / 6
        b = V((math.cos(a) * 0.12, 0.05 + math.sin(a) * 0.12, 5.05))
        M.leaf(head, b, b + V((math.cos(a) * 0.55, math.sin(a) * 0.55, 0.42)), 0.38, "petal" if k % 2 else "petal_white", up=(0, 0, 1))
    head.sphere(0.17, SUN, loc=(0, 0.05, 5.12), segs=10, rings=6)
    # vine arms; the right hand carries a budding staff
    for s, side in ((-1, "L"), (1, "R")):
        arm = A.segment(f"Arm{side}", (s * 0.4, 0, 3.95), body)
        fore = A.segment(f"Forearm{side}", (s * 0.62, 0.1, 3.2), arm)
        arm.tube([V((s * 0.35, 0, 3.95)), V((s * 0.55, 0.05, 3.55)), V((s * 0.62, 0.1, 3.2))], [0.11, 0.1, 0.09], "vine", sides=6)
        fore.tube([V((s * 0.62, 0.1, 3.2)), V((s * 0.66, 0.25, 2.8)), V((s * 0.65, 0.35, 2.5))], [0.09, 0.08, 0.07], "vine", sides=6)
        for f in (-1, 0, 1):
            M.leaf(fore, V((s * 0.65, 0.35, 2.5)), V((s * 0.65 + f * 0.12, 0.5, 2.22)), 0.12, "leaf")
        if s == 1:
            fore.tube([V((0.66, 0.38, 1.6)), V((0.68, 0.4, 2.6)), V((0.72, 0.4, 3.7)), V((0.66, 0.42, 4.2))], [0.06, 0.07, 0.06, 0.05], "bark", sides=6)
            for k in range(5):
                a = 2 * math.pi * k / 5
                b = V((0.66, 0.42, 4.3))
                M.leaf(fore, b, b + V((math.cos(a) * 0.3, math.sin(a) * 0.3, 0.25)), 0.22, "petal")
            fore.sphere(0.12, GLOW, loc=(0.66, 0.42, 4.33), segs=8, rings=5)
    # root legs
    for s, side in ((-1, "L"), (1, "R")):
        leg = A.segment(f"Leg{side}", (s * 0.22, 0, 2.3), body)
        knee = A.segment(f"Knee{side}", (s * 0.28, 0.05, 1.2), leg)
        leg.tube([V((s * 0.22, 0, 2.35)), V((s * 0.26, 0.03, 1.75)), V((s * 0.28, 0.05, 1.2))], [0.15, 0.13, 0.12], "root", sides=7)
        knee.tube([V((s * 0.28, 0.05, 1.2)), V((s * 0.3, 0.08, 0.6)), V((s * 0.32, 0.1, 0.08))], [0.12, 0.11, 0.1], "root", sides=7)
        for t in (-0.6, 0, 0.6):
            f = V((s * 0.32, 0.1, 0.08))
            knee.tube([f, f + V((s * 0.18 + t * 0.2, 0.35 * (1 - abs(t)), -0.06))], [0.06, 0.0], "bark", sides=4)
    return A


# ============================================================================ Vinebound Elite / Alpha (ROOTED_BIPED)
def vinebound(alpha=False):
    A = M.MobAsset("alpha_vinebound" if alpha else "elite_vinebound", "ROOTED_BIPED", ATLAS_ALPHA if alpha else ATLAS, "ALPHA" if alpha else "ELITE")
    body = A.segment("Body", (0, 0, 3.4))
    head = A.segment("Head", (0, 0.05, 6.2), body)
    # armoured torso swallowed by vines
    body.box((2.5, 1.6, 0.8), "iron_dark", loc=(0, 0, 3.45), bevel=0.15)
    body.tube([V((0, 0, 3.6)), V((0, 0.05, 4.6)), V((0, 0.05, 5.5)), V((0, 0, 6.1))], [(1.15, 0.75), (1.4, 0.85), (1.6, 0.9), (1.05, 0.7)], "iron", sides=12)
    body.box((0.3, 0.3, 2.0), "gold_dark", loc=(0, 0.92, 4.9), bevel=0.06)
    M.sun_glyph(body, (0, 0.98, 5.15), (0, 1, 0), 0.5, "gold", GLOW, rays=8)
    for k, x in enumerate((-0.8, -0.27, 0.27, 0.8)):  # tassets
        body.box((0.5, 0.2, 1.1), "iron", loc=(x, 0.78, 2.75), rot=(-8, 0, 0), bevel=0.06)
    M.vine_spiral(body, (0, 0), 1.25, 3.3, 6.0, 1.6, "vine_dark", thick=0.13, leaves=10, leaf_colour="leaf", seed=30, rx=1.55)
    M.vine_spiral(body, (0, 0), 1.2, 3.2, 5.6, 1.1, "vine", thick=0.1, leaves=6, leaf_colour="leaf_dark", seed=31, phase=2.0, rx=1.5)
    M.moss(body, (-1.1, -0.2, 6.05), 0.38, 3, "moss", seed=32)
    M.moss(body, (0.9, -0.5, 5.9), 0.3, 3, "moss_light", seed=33)
    for k in range(4):  # thorns on the back
        body.spike((0.3 * (k % 2 * 2 - 1), -0.8, 4.0 + k * 0.5), (0.45 * (k % 2 * 2 - 1), -1.35, 4.3 + k * 0.5), 0.12, "bark_dark", segs=5)
    # great helm with a glowing visor, antler branches and leaves
    head.tube([V((0, 0.05, 6.15)), V((0, 0.1, 6.7)), V((0, 0.1, 7.3)), V((0, 0.05, 7.55))], [(0.62, 0.66), (0.7, 0.74), (0.66, 0.7), (0.4, 0.45)], "iron", sides=12)
    head.box((1.05, 0.25, 0.14), GLOW, loc=(0, 0.78, 7.0))
    head.box((0.16, 0.3, 0.7), "gold_dark", loc=(0, 0.78, 6.75))
    for s in (1, -1):
        pts = [V((s * 0.45, 0, 7.3)), V((s * 0.8, -0.1, 7.8)), V((s * 1.0, -0.2, 8.25)), V((s * 0.85, -0.3, 8.6))]
        head.tube(pts, [0.1, 0.08, 0.06, 0.0], "bark", sides=6)
        head.tube([pts[1], pts[1] + V((s * 0.45, 0.1, 0.25))], [0.06, 0.0], "bark", sides=5)
        M.leaf(head, pts[2], pts[2] + V((s * 0.35, 0.1, 0.25)), 0.22, "leaf")
    M.moss(head, (0.2, -0.1, 7.55), 0.22, 2, "moss", seed=34)
    for s, side in ((-1, "L"), (1, "R")):
        arm = A.segment(f"Arm{side}", (s * 1.55, 0, 5.75), body)
        fore = A.segment(f"Forearm{side}", (s * 1.8, 0.05, 4.4), arm)
        arm.sphere(0.72, "iron", loc=(s * 1.7, 0, 5.85), scale=(1.1, 1.0, 0.8), segs=14, rings=8)
        arm.torus(0.7, 0.08, "gold_dark", loc=(s * 1.72, 0, 5.6), major=16, minor=5)
        arm.rod((s * 1.62, 0, 5.6), (s * 1.8, 0.05, 4.5), 0.34, "iron_dark", segs=10)
        M.vine_spiral(arm, (s * 1.7, 0.02), 0.4, 4.6, 5.5, 1.2, "vine", thick=0.07, leaves=2, leaf_colour="leaf", seed=35 + s)
        fore.sphere(0.34, "iron", loc=(s * 1.8, 0.05, 4.4), segs=10, rings=6)
        fore.rod((s * 1.8, 0.05, 4.35), (s * 1.85, 0.2, 3.35), 0.36, "iron", segs=10, r2=0.42)
        fore.box((0.6, 0.62, 0.55), "iron_dark", loc=(s * 1.86, 0.25, 3.05), bevel=0.1)
        if s == -1:
            # living-wood kite shield: bark planks, gold rim, glowing glyph
            sh = [(0.0, 1.05), (0.75, 0.75), (0.7, -0.4), (0.0, -1.35), (-0.7, -0.4), (-0.75, 0.75)]
            from mathutils import Matrix
            m = Matrix(((0, -1, 0, -2.3), (1, 0, 0, 0.35), (0, 0, 1, 3.55), (0, 0, 0, 1)))  # local X = +Y, local Y = -X, local Z = up
            fore.prism(sh, 0.22, "bark", mat=m)
            for k, x in enumerate((-0.35, 0.0, 0.35)):
                fore.box((0.06, 0.3, 2.0 - abs(x) * 1.2), "bark_dark", mat=m @ K.M((x, -0.05, -0.15)))
            fore.tube([m @ V((p[0] * 1.02, -0.02, p[1] * 1.02)) for p in sh + [sh[0]]], [0.07] * 7, "gold", sides=5)
            M.sun_glyph(fore, m @ V((0, -0.14, 0.05)), (-1, 0, 0), 0.28, "gold_dark", GLOW, rays=6)
            M.moss(fore, m @ V((0.4, -0.1, 0.7)), 0.16, 2, "moss", seed=40)
        else:
            # thorn whip: a thick barbed vine hanging from the gauntlet, coiling at the end
            pts = [V((1.86, 0.4, 2.95)), V((1.95, 0.9, 2.2)), V((2.1, 1.3, 1.3)), V((2.0, 1.6, 0.6)), V((1.6, 1.8, 0.35)), V((1.4, 1.55, 0.6))]
            fore.tube(pts, [0.14, 0.13, 0.12, 0.1, 0.08, 0.05], "vine_dark", sides=7)
            for k in range(1, len(pts) - 1):
                d = (pts[k + 1] - pts[k - 1]).normalized()
                side_v = d.cross(V((0, 0, 1))).normalized() if abs(d.z) < 0.9 else V((1, 0, 0))
                for sg in (1, -1):
                    fore.spike(pts[k] + side_v * sg * 0.1, pts[k] + side_v * sg * 0.38 + d * 0.12, 0.06, "bark_dark", segs=4)
            fore.sphere(0.12, GLOW, loc=pts[-1], segs=8, rings=5)
    for s, side in ((-1, "L"), (1, "R")):
        leg = A.segment(f"Leg{side}", (s * 0.7, 0, 3.05), body)
        knee = A.segment(f"Knee{side}", (s * 0.75, 0.05, 1.6), leg)
        leg.rod((s * 0.7, 0, 3.1), (s * 0.75, 0.05, 1.65), 0.42, "iron_dark", segs=10)
        leg.box((0.75, 0.25, 1.1), "iron", loc=(s * 0.72, 0.42, 2.4), bevel=0.08)
        knee.sphere(0.38, "iron", loc=(s * 0.75, 0.12, 1.6), segs=10, rings=6)
        knee.rod((s * 0.75, 0.05, 1.55), (s * 0.78, 0.05, 0.4), 0.38, "iron", segs=10, r2=0.34)
        knee.box((0.8, 1.25, 0.4), "iron_dark", loc=(s * 0.78, 0.25, 0.2), bevel=0.1)
        for t in (-0.5, 0.0, 0.5):  # roots growing from the greaves into the ground
            b = V((s * (0.78 + t * 0.3), -0.2, 0.55))
            knee.tube([b, b + V((s * 0.2 + t * 0.2, -0.3, -0.3)), b + V((s * 0.35 + t * 0.35, -0.45, -0.55))], [0.09, 0.07, 0.0], "root", sides=5)
    if alpha:
        # trophy: a gilded sun-disc halo behind the helm
        halo = A.segment("Trophy_Halo", (0, -0.6, 7.2), head)
        M.sun_glyph(halo, (0, -0.65, 7.25), (0, 1, 0), 1.0, "gold", SUN, rays=12, ring_thick=0.12)
        halo.torus(1.25, 0.05, "gold_dark", mat=K.look_matrix(V((0, -0.7, 7.25)), V((0, 0.3, 7.25))), major=28, minor=5)
    return A


# ============================================================================ Mossbound Guardian (Biome Boss, STONE_COLOSSUS)
def mossbound_guardian():
    A = M.MobAsset("boss_mossbound_guardian", "STONE_COLOSSUS", ATLAS, "BOSS")
    body = A.segment("Body", (0, 0, 7.4))
    head = A.segment("Head", (0, 1.0, 12.4), body)
    rnd = random.Random(50)
    # hunched temple-statue torso: pelvis plinth, stacked carved blocks, frieze band, sun-disc chest core
    body.box((5.0, 3.6, 1.9), "stone_dark", loc=(0, 0, 7.3), bevel=0.3)
    body.box((5.6, 3.9, 2.3), "stone", loc=(0, 0.25, 9.2), rot=(8, 0, 0), bevel=0.35)
    body.box((7.2, 4.4, 2.3), "stone_warm", loc=(0, 0.55, 11.1), rot=(12, 0, 0), bevel=0.4)
    body.box((7.4, 0.5, 0.45), "gold_dark", loc=(0, 2.85, 10.25), rot=(12, 0, 0), bevel=0.08)  # frieze band
    for k in range(7):
        body.box((0.35, 0.25, 0.35), "gold", loc=(-3.0 + k, 3.05, 10.25), rot=(12, 0, 45), bevel=0.04)
    M.sun_glyph(body, (0, 2.85, 11.2), (0, 1, -0.2), 1.05, "gold", GLOW, rays=10, ring_thick=0.18)
    # moss carpet over the shoulders and back, hanging vines
    for k in range(14):
        x = rnd.uniform(-3.4, 3.4)
        y = rnd.uniform(-2.2, 0.8)
        M.moss(body, (x, y, 12.2 - abs(x) * 0.1), rnd.uniform(0.7, 1.05), 3, rnd.choice(("moss", "moss_dark", "moss_light")), seed=60 + k, flat=0.55)
    for k in range(6):
        x = -3.2 + k * 1.3
        top = V((x, 2.4 + (k % 2) * 0.3, 11.9))
        body.tube([top, top + V((0.1, 0.35, -1.2)), top + V((-0.1, 0.4, -2.6)), top + V((0.05, 0.3, -3.4 - (k % 3) * 0.5))], [0.13, 0.12, 0.1, 0.0], "vine", sides=6)
        M.leaf(body, top + V((0.1, 0.38, -1.5)), top + V((0.45, 0.6, -1.9)), 0.3, "leaf")
    # a broken pediment on the back and a tree growing from the left shoulder
    body.prism([(-3.2, 0), (3.2, 0), (0, 1.8)], 0.9, "stone", loc=(0, -2.3, 12.0))
    body.box((6.6, 0.95, 0.4), "stone_dark", loc=(0, -2.3, 11.95), bevel=0.1)
    trunk = [V((-3.4, -0.6, 12.4)), V((-3.9, -0.8, 13.8)), V((-4.1, -1.0, 15.2)), V((-4.0, -0.9, 16.2))]
    body.tube(trunk, [0.65, 0.52, 0.4, 0.28], "bark", sides=9)
    for k, d in enumerate((V((0.9, 0.2, 0.6)), V((-0.8, 0.3, 0.4)), V((0.1, -0.7, 0.7)))):
        body.tube([trunk[2], trunk[2] + d], [0.2, 0.08], "bark_dark", sides=6)
    for k, (dx, dy, dz, r) in enumerate(((0, 0, 0.7, 1.8), (1.2, 0.3, 0.2, 1.3), (-1.3, 0.2, 0.3, 1.35), (0.2, -1.1, 0.3, 1.2), (0.3, 1.0, -0.1, 1.1), (-0.6, -0.4, 1.4, 1.0))):
        body.ico(r, "leaf" if k % 2 else "leaf_dark", loc=trunk[3] + V((dx, dy, dz)), scale=(1, 1, 0.8), subdiv=2, jitter=0.12, seed=70 + k)
    # head: a statue face sunk between the shoulders, broken tiara, glyph eyes, moss beard
    head.box((2.0, 1.8, 2.0), "stone", loc=(0, 1.55, 13.2), bevel=0.3)
    head.box((2.3, 0.6, 0.5), "stone_dark", loc=(0, 2.35, 13.75), bevel=0.12)
    for s in (1, -1):
        head.box((0.45, 0.2, 0.22), GLOW, loc=(s * 0.45, 2.48, 13.35))
    head.box((0.35, 0.4, 0.7), "stone_warm", loc=(0, 2.5, 13.0), bevel=0.08)  # nose
    for k in range(5):
        a = (k - 2) * 0.32
        head.box((0.35, 0.3, 0.9 - abs(k - 2) * 0.2), "gold_dark", loc=((k - 2) * 0.45, 1.6, 14.45 + (0.45 - abs(k - 2) * 0.1) * 0.5), rot=(0, math.degrees(a) * 0.4, 0), bevel=0.04)
    M.moss(head, (0, 2.35, 12.45), 0.35, 4, "moss_dark", seed=80, flat=0.6, spread=0.5)
    # arms: boulder shoulders, column-drum upper arms, forearms that are fallen pillars ending in capital fists
    for s, side in ((-1, "L"), (1, "R")):
        arm = A.segment(f"Arm{side}", (s * 4.0, 0.4, 11.4), body)
        fore = A.segment(f"Forearm{side}", (s * 4.6, 1.0, 8.4), arm)
        arm.ico(1.6, "stone", loc=(s * 4.2, 0.4, 11.8), scale=(1.1, 1.0, 0.9), subdiv=2, jitter=0.1, seed=90 + s)
        M.moss(arm, (s * 4.2, 0.0, 13.0), 0.5, 3, "moss", seed=92 + s, flat=0.4)
        M.column(arm, (s * 4.1, 0.5, 10.8), (s * 4.55, 0.95, 8.6), 0.95, "stone_dark", flutes=10)
        fore.sphere(0.95, "stone", loc=(s * 4.6, 1.0, 8.4), segs=12, rings=8)
        M.column(fore, (s * 4.65, 1.1, 8.2), (s * 4.85, 1.7, 4.6), 1.05, "stone", flutes=12, capital="stone_warm")
        fore.box((2.6, 2.6, 1.9), "stone_warm", loc=(s * 4.9, 1.85, 3.5), bevel=0.3)  # capital fist
        fore.box((2.8, 2.8, 0.35), "gold_dark", loc=(s * 4.9, 1.85, 4.35), bevel=0.06)
        M.vine_spiral(fore, (s * 4.75, 1.4), 1.15, 4.8, 7.6, 1.2, "vine_dark", thick=0.12, leaves=4, leaf_colour="leaf", seed=95 + s)
    # legs: column-drum thighs, shins on plinth feet
    for s, side in ((-1, "L"), (1, "R")):
        leg = A.segment(f"Leg{side}", (s * 1.9, 0, 6.4), body)
        knee = A.segment(f"Knee{side}", (s * 2.0, 0.2, 3.4), leg)
        M.column(leg, (s * 1.9, 0, 6.5), (s * 2.0, 0.2, 3.6), 1.05, "stone_dark", flutes=10)
        knee.sphere(1.0, "stone", loc=(s * 2.0, 0.35, 3.4), segs=12, rings=8)
        M.column(knee, (s * 2.0, 0.2, 3.3), (s * 2.05, 0.25, 1.1), 1.0, "stone", flutes=10)
        knee.box((2.6, 3.2, 1.1), "stone_dark", loc=(s * 2.05, 0.6, 0.55), bevel=0.2)
        M.moss(knee, (s * 2.1, 1.6, 1.15), 0.4, 3, "moss", seed=98 + s)
    return A


BUILDERS = {
    "mob_moss_crawler": moss_crawler,
    "mob_ruin_guardian": ruin_guardian,
    "mob_bloom_tender": bloom_tender,
    "elite_vinebound": lambda: vinebound(False),
    "alpha_vinebound": lambda: vinebound(True),
    "boss_mossbound_guardian": mossbound_guardian,
}
