"""
Biome 5: Infernal Foundry (floors 21-25). docs/tower-mob-remodel-plan.md §5.5.
A working forge. Motif: rivets, pistons, cooling slag and glowing seams. Glow: molten orange-gold.

Blender coordinates: 1 unit = 1 stud, Z up, ground z = 0, enemies face +Y, their right hand is +X.
Every enemy here is a biped (mob_kit.BIPED joints). Each is authored on a ~6.6-stud biped frame and scaled
with scaled() before building: the imps shrink, the Taskmaster and the Ember Titan grow.
"""
import math, random
from mathutils import Vector
import raid_kit as K
import mob_kit as M

V = Vector
K.GLOW["molten"] = (255, 156, 44)
K.GLOW["ember"] = (255, 96, 30)
MOLTEN = "glow:molten"
EMBER = "glow:ember"

ATLAS = M.Atlas("infernal_foundry", {
    "iron": (88, 84, 82), "iron_dark": (48, 44, 44), "iron_light": (140, 134, 128),
    "brass": (196, 146, 70), "brass_dark": (128, 90, 44), "soot": (30, 26, 26), "soot_mid": (62, 52, 50),
    "slag": (92, 62, 52), "slag_dark": (56, 36, 32), "leather": (112, 70, 44), "leather_dark": (70, 44, 30),
    "apron": (124, 92, 66), "chain": (76, 72, 72), "brick": (128, 64, 48), "brick_dark": (84, 40, 32),
    "smoke": (70, 66, 66), "wood": (118, 80, 50), "gold": (230, 184, 82), "gold_dark": (156, 116, 50),
    "horn": (60, 50, 46), "black": (16, 14, 14),
})
# the Alpha's chain is brass-banded and its plate trimmed in gold
ATLAS_ALPHA = M.Atlas("infernal_foundry_alpha", dict(ATLAS.colours, **{
    "iron_light": (214, 170, 84), "brass_dark": (232, 184, 86),
}))


def scaled(A, s):
    """Scale an authored asset about the ground origin (UVs were set at paint time and do not change)."""
    for seg in A.segments:
        for v in seg.bm.verts:
            v.co *= s
        seg.pivot = V(seg.pivot) * s
    return A


def rivets(seg, pts, r, colour="brass"):
    for p in pts:
        seg.sphere(r, colour, loc=p, segs=6, rings=4)


def seam(seg, pts, r, colour=EMBER):
    """A glowing crack: a thin tapering tube."""
    seg.tube([V(p) for p in pts], [r] + [r * 0.8] * (len(pts) - 2) + [r * 0.3], colour, sides=4)


def chain_links(seg, pts, link, colours):
    """Interlocking oval links along a polyline; consecutive links turn 90 degrees."""
    pts = [V(p) for p in pts]
    k = 0
    for i in range(len(pts) - 1):
        a, b = pts[i], pts[i + 1]
        n = max(1, int((b - a).length / (link * 1.5)))
        for j in range(n):
            c = a.lerp(b, (j + 0.5) / n)
            m = K.look_matrix(c, c + (b - a)) @ K.M(rot=(90, 0, 90 * (k % 2))) @ K.M(scale=(0.62, 1.0, 1.0))
            seg.torus(link, link * 0.22, colours[k % len(colours)], mat=m, major=8, minor=4)
            k += 1


# ============================================================================ imps (Regular / Support, SMALL_BIPED)
def imp_base(A, skin, skin_dark):
    """Soot-black imp on the unit frame: a big horned head, ember cracks, a barbed tail, digitigrade legs."""
    body = A.segment("Body", (0, 0, 3.0))
    head = A.segment("Head", (0, 0.1, 4.6), body)
    body.sphere(1.0, skin, loc=(0, 0, 3.6), scale=(0.95, 0.75, 1.05), segs=12, rings=8)
    body.sphere(0.75, skin_dark, loc=(0, 0.05, 2.95), scale=(1.0, 0.85, 0.75), segs=10, rings=6)
    seam(body, [(0.3, 0.72, 4.2), (0.12, 0.76, 3.75), (0.28, 0.74, 3.3), (0.1, 0.66, 2.9)], 0.06)
    seam(body, [(-0.45, 0.62, 4.0), (-0.35, 0.7, 3.6), (-0.5, 0.6, 3.2)], 0.05)
    body.tube([V((0, -0.55, 2.9)), V((0, -1.2, 2.6)), V((0, -1.7, 2.9)), V((0, -1.9, 3.5))], [0.16, 0.13, 0.1, 0.07], skin_dark, sides=6)
    body.prism([(-0.22, 0), (0.22, 0), (0, 0.45)], 0.06, skin_dark, loc=(0, -1.9, 3.5), rot=(0, 0, 90))
    # head: wide grinning skull, ember eyes and mouth, spark-tipped horns, pointed ears
    head.sphere(0.85, skin, loc=(0, 0.15, 5.2), scale=(1.05, 0.95, 0.9), segs=12, rings=8)
    head.box((0.85, 0.12, 0.12), EMBER, loc=(0, 0.92, 4.95), rot=(0, 0, 0))
    for s in (1, -1):
        head.sphere(0.13, MOLTEN, loc=(s * 0.33, 0.85, 5.35), segs=6, rings=4)
        head.box((0.3, 0.08, 0.1), skin_dark, loc=(s * 0.33, 0.88, 5.55), rot=(0, s * -18, 0))
        horn = [V((s * 0.45, 0.0, 5.85)), V((s * 0.75, -0.1, 6.35)), V((s * 0.7, -0.35, 6.85))]
        head.tube(horn, [0.17, 0.12, 0.05], "horn", sides=6)
        head.sphere(0.08, MOLTEN, loc=horn[-1], segs=6, rings=4)
        head.spike((s * 0.8, 0.05, 5.25), (s * 1.45, -0.2, 5.5), 0.17, skin_dark, segs=4)
    for s, side in ((-1, "L"), (1, "R")):
        arm = A.segment(f"Arm{side}", (s * 0.85, 0, 4.15), body)
        fore = A.segment(f"Forearm{side}", (s * 1.05, 0.1, 3.3), arm)
        arm.tube([V((s * 0.85, 0, 4.15)), V((s * 1.05, 0.1, 3.3))], [0.22, 0.17], skin, sides=7)
        fore.tube([V((s * 1.05, 0.1, 3.3)), V((s * 1.1, 0.3, 2.55))], [0.17, 0.15], skin_dark, sides=7)
        fore.sphere(0.2, skin, loc=(s * 1.1, 0.35, 2.45), segs=8, rings=5)
        for c in (-0.1, 0.0, 0.1):
            fore.spike((s * 1.1 + c, 0.45, 2.4), (s * 1.12 + c * 1.4, 0.7, 2.2), 0.05, "horn", segs=4)
    for s, side in ((-1, "L"), (1, "R")):
        leg = A.segment(f"Leg{side}", (s * 0.4, 0, 2.7), body)
        knee = A.segment(f"Knee{side}", (s * 0.45, 0.35, 1.55), leg)
        leg.tube([V((s * 0.4, 0, 2.75)), V((s * 0.46, 0.3, 2.1)), V((s * 0.45, 0.35, 1.55))], [0.28, 0.24, 0.17], skin, sides=7)
        knee.tube([V((s * 0.45, 0.35, 1.55)), V((s * 0.47, -0.15, 0.85)), V((s * 0.47, 0.0, 0.2))], [0.16, 0.13, 0.12], skin_dark, sides=7)
        knee.box((0.36, 0.6, 0.18), "horn", loc=(s * 0.47, 0.18, 0.09), bevel=0.05)
    return body, head


def cinder_imp():
    A = M.MobAsset("mob_cinder_imp", "SMALL_BIPED", ATLAS, "REGULAR")
    body, head = imp_base(A, "soot", "soot_mid")
    # a tiny tong-claw in the right hand, still glowing at the jaws
    fore = A.seg("ForearmR")
    hand = V((1.1, 0.35, 2.45))
    for s in (1, -1):
        fore.tube([hand, hand + V((s * 0.12, 0.6, -0.05)), hand + V((s * 0.04, 1.2, 0.0))], [0.05, 0.05, 0.05], "iron", sides=5)
        fore.box((0.08, 0.25, 0.14), MOLTEN, loc=hand + V((s * 0.05, 1.3, 0)))
    fore.sphere(0.08, "iron_light", loc=hand + V((0, 0.6, -0.05)), segs=6, rings=4)
    body.torus(0.82, 0.08, "leather_dark", mat=K.M((0, 0.02, 3.05)) @ K.M(scale=(1, 0.82, 1)), major=14, minor=4)
    return scaled(A, 0.58)


def bellows_imp():
    A = M.MobAsset("mob_bellows_imp", "SMALL_BIPED", ATLAS, "SUPPORT")
    body, head = imp_base(A, "slag_dark", "soot")
    # a leather bellows pack strapped to its back, nozzle up, puffing sparks
    for s in (1, -1):
        body.tube([V((s * 0.55, 0.62, 4.3)), V((s * 0.45, 0.5, 3.4)), V((s * 0.5, -0.6, 3.0))], [0.06] * 3, "leather_dark", sides=4)
    pack = A.segment("ExtraBellows", (0, -0.9, 3.0), body)  # the pack pumps on ROUSE (keyed later; spring until then)
    pack.prism([(-0.8, 0), (0.8, 0), (0.55, 1.5), (-0.55, 1.5)], 0.12, "wood", loc=(0, -0.9, 3.0), rot=(-8, 0, 0))
    pack.prism([(-0.8, 0), (0.8, 0), (0.55, 1.5), (-0.55, 1.5)], 0.12, "wood", loc=(0, -1.6, 3.0), rot=(8, 0, 0))
    for k in range(4):
        y = -1.0 - k * 0.17
        pack.box((1.4 - k * 0.0, 0.14, 1.1), "leather" if k % 2 else "leather_dark", loc=(0, y, 3.65), bevel=0.04)
    for z in (3.2, 4.3):
        pack.box((1.3, 0.85, 0.08), "brass_dark", loc=(0, -1.25, z))
    pack.rod((0, -1.25, 4.5), (0, -1.1, 5.4), 0.14, "brass", segs=8, r2=0.08)
    rnd = random.Random(25)
    for k in range(5):
        c = V((rnd.uniform(-0.3, 0.3), -1.1 + rnd.uniform(-0.2, 0.2), 5.6 + k * 0.28))
        pack.sphere(0.07 + 0.03 * (k % 2), MOLTEN if k % 2 else EMBER, loc=c, segs=6, rings=4)
    body.rod((0.5, -0.9, 3.0), (0.9, -0.6, 2.4), 0.07, "wood", segs=5)
    return scaled(A, 0.6)


# ============================================================================ Forge Construct (Regular, ARMORED_BIPED)
def forge_construct():
    A = M.MobAsset("mob_forge_construct", "ARMORED_BIPED", ATLAS, "REGULAR")
    body = A.segment("Body", (0, 0, 3.15))
    head = A.segment("Head", (0, 0.05, 5.35), body)
    # a riveted iron boiler torso with a furnace-grill chest and a stack venting from the back
    body.box((1.9, 1.3, 2.2), "iron", loc=(0, 0, 4.2), bevel=0.2)
    body.box((1.5, 1.1, 0.7), "iron_dark", loc=(0, 0, 2.95), bevel=0.12)
    body.box((1.0, 0.1, 0.85), MOLTEN, loc=(0, 0.6, 4.3))
    for k in range(5):
        body.box((0.07, 0.1, 0.95), "iron_dark", loc=(-0.4 + k * 0.2, 0.67, 4.3))
    body.box((1.2, 0.12, 0.12), "brass_dark", loc=(0, 0.67, 4.8))
    body.box((1.2, 0.12, 0.12), "brass_dark", loc=(0, 0.67, 3.8))
    rivets(body, [(sx * 0.85, 0.66, z) for sx in (-1, 1) for z in (3.4, 4.0, 4.6, 5.1)], 0.06)
    body.cyl(0.22, 0.25, 1.0, "iron_dark", loc=(0.45, -0.7, 5.3), segs=8)
    body.cyl(0.27, 0.27, 0.12, "brass_dark", loc=(0.45, -0.7, 5.8), segs=8)
    body.sphere(0.2, "smoke", loc=(0.45, -0.75, 6.1), segs=6, rings=4)
    # head: a squat riveted helm with one furnace eye slit
    head.box((0.9, 0.85, 0.75), "iron_light", loc=(0, 0.1, 5.75), bevel=0.12)
    head.box((0.65, 0.1, 0.12), MOLTEN, loc=(0, 0.53, 5.8))
    head.box((0.95, 0.9, 0.12), "brass_dark", loc=(0, 0.1, 6.15))
    rivets(head, [(sx * 0.4, 0.55, z) for sx in (-1, 1) for z in (5.55, 6.0)], 0.05)
    # arms: a pincer left, a piston-driven hammer right
    for s, side in ((-1, "L"), (1, "R")):
        arm = A.segment(f"Arm{side}", (s * 1.15, 0, 4.95), body)
        fore = A.segment(f"Forearm{side}", (s * 1.3, 0.05, 3.85), arm)
        arm.sphere(0.45, "iron_dark", loc=(s * 1.15, 0, 5.0), segs=10, rings=6)
        arm.torus(0.42, 0.06, "brass", loc=(s * 1.15, 0, 4.8), major=12, minor=4)
        arm.cyl(0.2, 0.2, 1.0, "iron", loc=(s * 1.25, 0.03, 4.35), segs=8)
        fore.sphere(0.25, "brass_dark", loc=(s * 1.3, 0.05, 3.85), segs=8, rings=5)
        if s == 1:
            fore.cyl(0.26, 0.26, 0.8, "iron", loc=(1.3, 0.1, 3.4), segs=10)
            piston = A.segment("ExtraPiston", (1.3, 0.1, 3.05), fore)  # fires as the hammer lands (keyed later)
            piston.cyl(0.14, 0.14, 0.6, "iron_light", loc=(1.3, 0.1, 2.75), segs=8)
            piston.box((1.2, 0.75, 0.75), "iron_dark", loc=(1.3, 0.15, 2.15), bevel=0.1)
            for sx in (1, -1):
                piston.box((0.12, 0.8, 0.8), "brass_dark", loc=(1.3 + sx * 0.5, 0.15, 2.15))
            piston.box((0.9, 0.08, 0.5), EMBER, loc=(1.3, 0.55, 2.15))
        else:
            fore.cyl(0.24, 0.2, 0.9, "iron", loc=(-1.3, 0.1, 3.35), segs=8)
            for sx in (1, -1):
                fore.tube([V((-1.3 + sx * 0.12, 0.15, 2.9)), V((-1.3 + sx * 0.28, 0.35, 2.5)), V((-1.3 + sx * 0.12, 0.5, 2.2))], [0.09, 0.08, 0.03], "iron_dark", sides=5)
    for s, side in ((-1, "L"), (1, "R")):
        leg = A.segment(f"Leg{side}", (s * 0.5, 0, 2.9), body)
        knee = A.segment(f"Knee{side}", (s * 0.52, 0.05, 1.55), leg)
        leg.cyl(0.3, 0.26, 1.3, "iron", loc=(s * 0.5, 0, 2.25), segs=8)
        knee.sphere(0.27, "brass_dark", loc=(s * 0.52, 0.08, 1.55), segs=8, rings=5)
        knee.cyl(0.26, 0.3, 1.2, "iron_dark", loc=(s * 0.52, 0.05, 0.85), segs=8)
        knee.box((0.6, 0.95, 0.3), "iron", loc=(s * 0.52, 0.2, 0.15), bevel=0.08)
    return A


# ============================================================================ Molten Taskmaster Elite / Alpha (HEAVY_BIPED)
def molten_taskmaster(alpha=False):
    A = M.MobAsset("alpha_molten_taskmaster" if alpha else "elite_molten_taskmaster", "HEAVY_BIPED", ATLAS_ALPHA if alpha else ATLAS, "ALPHA" if alpha else "ELITE")
    body = A.segment("Body", (0, 0, 3.15))
    head = A.segment("Head", (0, 0.25, 5.25), body)
    # a hulking slag-skinned torso hunched forward, a foundry apron, riveted plate over the shoulders
    body.sphere(1.0, "slag", loc=(0, 0.1, 4.3), scale=(1.25, 0.85, 1.1), segs=14, rings=8)
    body.sphere(1.0, "slag_dark", loc=(0, 0, 3.2), scale=(1.0, 0.75, 0.7), segs=12, rings=7)
    body.prism([(-0.8, 0), (0.8, 0), (0.9, -2.7), (-0.9, -2.7)], 0.08, "apron", loc=(0, 0.82, 4.4), rot=(-4, 0, 0))
    body.box((1.85, 0.1, 0.15), "leather_dark", loc=(0, 0.78, 3.3))
    body.box((0.35, 0.12, 0.3), "iron_light", loc=(0, 0.84, 3.3))
    for s in (1, -1):
        seam(body, [(s * 0.5, -0.75, 4.8), (s * 0.7, -0.78, 4.2), (s * 0.45, -0.72, 3.7)], 0.07)
    body.box((2.2, 1.2, 0.3), "iron", loc=(0, 0.05, 5.15), bevel=0.1)
    rivets(body, [(x, 0.66, 5.15) for x in (-0.9, -0.45, 0.45, 0.9)], 0.06, "iron_light")
    # head: small and sunk between the shoulders, an iron mask with a molten grille
    head.sphere(0.5, "slag_dark", loc=(0, 0.45, 5.6), segs=10, rings=7)
    head.box((0.75, 0.2, 0.7), "iron_dark", loc=(0, 0.85, 5.6), bevel=0.08)
    for k in range(3):
        head.box((0.5, 0.06, 0.06), MOLTEN, loc=(0, 0.96, 5.75 - k * 0.15))
    rivets(head, [(sx * 0.3, 0.96, z) for sx in (-1, 1) for z in (5.35, 5.85)], 0.05, "iron_light")
    for s, side in ((-1, "L"), (1, "R")):
        arm = A.segment(f"Arm{side}", (s * 1.35, 0, 4.85), body)
        fore = A.segment(f"Forearm{side}", (s * 1.6, 0.15, 3.6), arm)
        arm.sphere(0.7, "iron", loc=(s * 1.4, 0, 5.05), scale=(1.0, 1.0, 0.7), segs=12, rings=6)
        arm.torus(0.62, 0.06, "iron_light", loc=(s * 1.4, 0, 4.85), major=14, minor=4)
        arm.tube([V((s * 1.35, 0, 4.8)), V((s * 1.6, 0.15, 3.6))], [0.45, 0.4], "slag", sides=8)
        fore.tube([V((s * 1.6, 0.15, 3.6)), V((s * 1.7, 0.35, 2.55))], [0.42, 0.36], "slag", sides=8)
        fore.cyl(0.46, 0.46, 0.5, "leather_dark", loc=(s * 1.68, 0.3, 2.85), segs=10)
        fore.sphere(0.36, "slag_dark", loc=(s * 1.72, 0.4, 2.35), segs=10, rings=6)
        seam(fore, [(s * 1.95, 0.3, 3.5), (s * 2.0, 0.35, 3.1), (s * 1.95, 0.4, 2.9)], 0.05)
    # the chain: from the right fist down to the floor and trailing behind, its last links still glowing
    # three links ExtraChain1-3, pivoting at the fist, the knee of the drop and where it meets the floor
    fist = V((1.72, 0.45, 2.3))
    pts = [fist, fist + V((0.15, 0.1, -1.2)), fist + V((0.25, -0.4, -2.2)), V((2.0, -1.5, 0.1)), V((1.8, -3.0, 0.1))]
    colours = ("brass_dark", "chain", "chain") if alpha else ("chain",)
    links, prev = [], A.seg("ForearmR")
    for n, (a, b) in enumerate(((0, 2), (2, 3), (3, 4))):
        link = A.segment(f"ExtraChain{n + 1}", pts[a], prev)
        chain_links(link, pts[a:b + 1], 0.19, colours)
        links.append(link)
        prev = link
    links[2].sphere(0.32, MOLTEN, loc=(1.75, -3.25, 0.25), segs=8, rings=5)
    links[2].box((0.35, 0.35, 0.35), "iron_dark", loc=(1.75, -3.25, 0.25), rot=(30, 20, 0))
    for s, side in ((-1, "L"), (1, "R")):
        leg = A.segment(f"Leg{side}", (s * 0.6, 0, 2.85), body)
        knee = A.segment(f"Knee{side}", (s * 0.65, 0.05, 1.5), leg)
        leg.tube([V((s * 0.6, 0, 2.9)), V((s * 0.66, 0.05, 2.1)), V((s * 0.65, 0.05, 1.55))], [0.48, 0.5, 0.38], "leather", sides=8)
        knee.sphere(0.32, "iron", loc=(s * 0.66, 0.3, 1.5), segs=8, rings=5)
        knee.tube([V((s * 0.65, 0.05, 1.5)), V((s * 0.68, 0.05, 0.8)), V((s * 0.68, 0.05, 0.3))], [0.36, 0.38, 0.32], "leather_dark", sides=8)
        knee.box((0.7, 1.05, 0.32), "iron_dark", loc=(s * 0.68, 0.2, 0.16), bevel=0.1)
    if alpha:
        crown = A.segment("Trophy_SlagCrown", (0, 0.45, 6.05), head)
        crown.cyl(0.5, 0.46, 0.22, "gold", loc=(0, 0.45, 6.05), segs=10)
        rnd = random.Random(7)
        for k in range(7):
            a = 2 * math.pi * k / 7 + math.pi / 2
            b = V((math.cos(a) * 0.45, 0.45 + math.sin(a) * 0.45, 6.12))
            crown.spike(b, b + V((0, 0, rnd.uniform(0.3, 0.55))), 0.1, "gold_dark", segs=5)
            if k % 2 == 0:
                crown.tube([b + V((0, 0, -0.08)), b + V((math.cos(a) * 0.05, math.sin(a) * 0.05, -0.3))], [0.06, 0.02], MOLTEN, sides=4)
    return scaled(A, 1.3)


# ============================================================================ Ember Titan (Biome Boss, FORGE_COLOSSUS)
def ember_titan():
    A = M.MobAsset("boss_ember_titan", "FORGE_COLOSSUS", ATLAS, "BOSS")
    body = A.segment("Body", (0, 0, 3.0))
    head = A.segment("Head", (0, 0.2, 5.6), body)
    # the furnace body: a brick barrel bound in iron hoops, a molten core window behind a grate, rivets
    body.cyl(1.35, 1.15, 2.6, "brick", loc=(0, 0, 4.3), segs=14)
    body.cyl(1.1, 1.2, 0.7, "brick_dark", loc=(0, 0, 2.75), segs=14)
    for z in (3.15, 4.3, 5.45):
        body.torus(1.3 - (z - 3.15) * 0.03 + 0.05, 0.08, "iron", loc=(0, 0, z), major=20, minor=4)
    body.cyl(0.62, 0.62, 0.3, MOLTEN, loc=(0, 1.15, 4.25), rot=(90, 0, 0), segs=12)
    body.torus(0.66, 0.1, "iron_dark", loc=(0, 1.3, 4.25), rot=(90, 0, 0), major=16, minor=5)
    for k in range(4):
        body.box((0.07, 0.12, 1.2), "iron_dark", loc=(-0.36 + k * 0.24, 1.38, 4.25))
    rivets(body, [(math.cos(a) * 0.78, 1.32, 4.25 + math.sin(a) * 0.78) for a in [k * math.pi / 4 for k in range(8)]], 0.05)
    for s in (1, -1):
        seam(body, [(s * 0.9, 0.8, 3.0), (s * 1.05, 0.6, 3.6), (s * 1.0, 0.7, 4.1)], 0.05, MOLTEN)
    body.cyl(1.0, 1.3, 0.4, "iron_dark", loc=(0, 0, 5.75), segs=14)
    # head: a domed furnace hood with a glowing visor slit, set low between the chimneys
    head.sphere(0.75, "iron", loc=(0, 0.3, 6.1), scale=(1, 1, 0.8), segs=12, rings=7)
    head.box((0.95, 0.1, 0.14), MOLTEN, loc=(0, 1.0, 6.1))
    head.box((1.1, 0.25, 0.1), "iron_dark", loc=(0, 0.95, 6.3))
    rivets(head, [(math.cos(a) * 0.7, 0.3 + math.sin(a) * 0.7, 6.15) for a in [k * math.pi / 3 for k in range(6)]], 0.05)
    head.spike((0, 0.1, 6.65), (0, 0.0, 7.15), 0.12, "iron_dark", segs=6)
    # arms: chimney stacks on the shoulders, venting smoke; riveted arms ending in anvil-head fists
    rnd = random.Random(21)
    for s, side in ((-1, "L"), (1, "R")):
        arm = A.segment(f"Arm{side}", (s * 1.55, 0, 5.2), body)
        fore = A.segment(f"Forearm{side}", (s * 1.8, 0.15, 3.85), arm)
        arm.box((1.0, 1.1, 0.9), "iron", loc=(s * 1.6, 0, 5.3), bevel=0.12)
        arm.cyl(0.26, 0.3, 1.5, "brick_dark", loc=(s * 1.7, -0.3, 6.35), segs=8)
        arm.cyl(0.34, 0.34, 0.14, "iron_dark", loc=(s * 1.7, -0.3, 7.1), segs=8)
        arm.cyl(0.2, 0.2, 0.05, EMBER, loc=(s * 1.7, -0.3, 7.15), segs=8)
        for k in range(3):
            arm.ico(0.3 + k * 0.08, "smoke", loc=(s * (1.7 + k * 0.08), -0.35 - k * 0.15, 7.45 + k * 0.45), subdiv=1, jitter=0.06, seed=k + (s > 0) * 5)
        arm.tube([V((s * 1.6, 0, 5.0)), V((s * 1.8, 0.15, 3.85))], [0.42, 0.38], "iron_dark", sides=8)
        fore.sphere(0.4, "brass_dark", loc=(s * 1.8, 0.15, 3.85), segs=10, rings=6)
        fore.tube([V((s * 1.8, 0.15, 3.85)), V((s * 1.85, 0.3, 2.9))], [0.4, 0.42], "iron", sides=8)
        fore.torus(0.43, 0.05, "brass", loc=(s * 1.83, 0.22, 3.35), major=12, minor=4)
        # anvil fist: horn forward, flat face, waisted base
        c = V((s * 1.88, 0.35, 2.3))
        fore.box((0.65, 0.9, 0.45), "iron_dark", loc=c + V((0, 0, 0.15)), bevel=0.05)
        fore.box((0.85, 1.25, 0.32), "iron_light", loc=c + V((0, -0.05, -0.2)), bevel=0.04)
        fore.spike(c + V((0, 0.55, -0.2)), c + V((0, 1.2, -0.25)), 0.16, "iron_light", segs=6)
        fore.box((0.95, 1.3, 0.3), "iron_dark", loc=c + V((0, -0.05, -0.5)), bevel=0.05)
        seam(fore, [c + V((s * 0.43, -0.3, 0.3)), c + V((s * 0.44, 0.0, 0.0)), c + V((s * 0.43, 0.3, 0.2))], 0.04, MOLTEN)
    # legs: riveted pillars on cast-iron feet
    for s, side in ((-1, "L"), (1, "R")):
        leg = A.segment(f"Leg{side}", (s * 0.7, 0, 2.6), body)
        knee = A.segment(f"Knee{side}", (s * 0.75, 0.08, 1.45), leg)
        leg.cyl(0.48, 0.44, 1.2, "iron", loc=(s * 0.7, 0, 2.0), segs=10)
        leg.torus(0.48, 0.05, "brass", loc=(s * 0.7, 0, 2.3), major=12, minor=4)
        knee.sphere(0.42, "brass_dark", loc=(s * 0.75, 0.1, 1.45), segs=10, rings=6)
        knee.cyl(0.42, 0.5, 1.05, "brick_dark", loc=(s * 0.75, 0.08, 0.8), segs=10)
        knee.box((1.05, 1.4, 0.32), "iron_dark", loc=(s * 0.75, 0.25, 0.16), bevel=0.08)
        rivets(knee, [(s * 0.75 + dx, 0.95, 0.2) for dx in (-0.3, 0.0, 0.3)], 0.05)
    return scaled(A, 2.3)


BUILDERS = {
    "mob_cinder_imp": cinder_imp,
    "mob_bellows_imp": bellows_imp,
    "mob_forge_construct": forge_construct,
    "elite_molten_taskmaster": lambda: molten_taskmaster(False),
    "alpha_molten_taskmaster": lambda: molten_taskmaster(True),
    "boss_ember_titan": ember_titan,
}
