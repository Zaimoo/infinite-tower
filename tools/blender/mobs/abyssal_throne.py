"""
Biome 10: Abyssal Throne (floors 46-50). docs/tower-mob-remodel-plan.md §5.10.
The tower's apex. Motif: blackened iron, crimson silk and void light. Glow: crimson with void purple, the same
glow colours as the raid bosses (raid_kit.GLOW "crimson" / "violet") so the endgame reads as one family.

Blender coordinates: 1 unit = 1 stud, Z up, ground z = 0, enemies face +Y, their right hand is +X.
Every enemy uses the biped joints. The Executioner and the Overlord are authored on a 6.6-stud biped frame and
scaled with scaled().
"""
import math, random
from mathutils import Vector
import raid_kit as K
import mob_kit as M

V = Vector
CRIMSON = "glow:crimson"
VOID = "glow:violet"

ATLAS = M.Atlas("abyssal_throne", {
    "iron": (64, 62, 72), "iron_dark": (32, 30, 38), "iron_light": (118, 116, 130), "crimson": (140, 22, 34),
    "crimson_dark": (80, 12, 22), "silk": (168, 30, 44), "void": (60, 34, 96), "void_dark": (32, 18, 52),
    "leather": (66, 42, 32), "bone": (226, 216, 196), "skin": (120, 108, 120), "chain": (82, 80, 90),
    "gold": (226, 180, 80), "gold_dark": (150, 110, 46), "black": (10, 10, 12),
})
ATLAS_ALPHA = M.Atlas("abyssal_throne_alpha", dict(ATLAS.colours, **{
    "iron_light": (214, 170, 84), "crimson_dark": (120, 18, 30),
}))


def scaled(A, s):
    """Scale an authored asset about the ground origin (UVs were set at paint time and do not change)."""
    for seg in A.segments:
        for v in seg.bm.verts:
            v.co *= s
        seg.pivot = V(seg.pivot) * s
    return A


def chain_links(seg, pts, link, colours):
    """Interlocking oval links along a polyline; consecutive links turn 90 degrees."""
    pts = [V(p) for p in pts]
    k = 0
    for a, b in zip(pts, pts[1:]):
        n = max(1, int((b - a).length / (link * 1.5)))
        for j in range(n):
            c = a.lerp(b, (j + 0.5) / n)
            m = K.look_matrix(c, c + (b - a)) @ K.M(rot=(90, 0, 90 * (k % 2))) @ K.M(scale=(0.62, 1.0, 1.0))
            seg.torus(link, link * 0.22, colours[k % len(colours)], mat=m, major=8, minor=4)
            k += 1


def crackle(seg, a, b, kinks, amp, r, colour, seed=0):
    """A jagged void arc from a to b."""
    a, b = V(a), V(b)
    rnd = random.Random(seed)
    pts = [a] + [a.lerp(b, k / kinks) + V((rnd.uniform(-amp, amp), rnd.uniform(-amp, amp), rnd.uniform(-amp, amp))) for k in range(1, kinks)] + [b]
    for p, q in zip(pts, pts[1:]):
        seg.rod(p, q, r, colour, segs=4)


def tattered(seg, top_w, length, colour, mat, teeth=5, seed=0):
    """A hanging cloth panel with a ragged hem (local XZ, hanging down -Z)."""
    rnd = random.Random(seed)
    poly = [(-top_w / 2, 0), (top_w / 2, 0)]
    for k in range(teeth * 2 + 1):
        x = top_w / 2 * 1.1 - k * (top_w * 1.1) / (teeth * 2)
        poly.append((x, -length * (1.0 if k % 2 == 0 else rnd.uniform(0.72, 0.85))))
    seg.prism(poly, 0.05, colour, mat=mat)


def biped_body(A, torso, plate, trim):
    """Shared plate-armoured torso, helmless head pivot, arms and legs (unit biped frame)."""
    body = A.segment("Body", (0, 0, 3.15))
    head = A.segment("Head", (0, 0.05, 5.35), body)
    body.tube([V((0, 0, 3.0)), V((0, 0.05, 3.95)), V((0, 0.06, 4.85)), V((0, 0, 5.35))], [(0.8, 0.55), (0.86, 0.6), (0.96, 0.62), (0.58, 0.45)], torso, sides=12)
    body.tube([V((0, 0.24, 4.15)), V((0, 0.3, 4.6)), V((0, 0.28, 5.0))], [(0.8, 0.36), (0.86, 0.38), (0.72, 0.34)], plate, sides=10)
    body.torus(0.82, 0.07, trim, mat=K.M((0, 0, 3.2)) @ K.M(scale=(1, 0.7, 1)), major=18, minor=4)
    arms, legs = {}, {}
    for s, side in ((-1, "L"), (1, "R")):
        arm = A.segment(f"Arm{side}", (s * 0.95, 0, 4.95), body)
        fore = A.segment(f"Forearm{side}", (s * 1.1, 0.05, 3.85), arm)
        arm.sphere(0.42, plate, loc=(s * 1.02, 0, 5.05), scale=(1, 1, 0.72), segs=12, rings=6)
        arm.spike((s * 1.1, -0.05, 5.3), (s * 1.5, -0.25, 5.8), 0.12, plate, segs=5)
        arm.tube([V((s * 0.98, 0, 4.9)), V((s * 1.1, 0.05, 3.9))], [0.24, 0.21], torso, sides=8)
        fore.tube([V((s * 1.1, 0.05, 3.85)), V((s * 1.15, 0.15, 2.95))], [0.24, 0.22], plate, sides=8)
        fore.sphere(0.19, torso, loc=(s * 1.15, 0.2, 2.8), segs=8, rings=5)
        arms[side] = (arm, fore)
    for s, side in ((-1, "L"), (1, "R")):
        leg = A.segment(f"Leg{side}", (s * 0.42, 0, 2.95), body)
        knee = A.segment(f"Knee{side}", (s * 0.46, 0.05, 1.55), leg)
        leg.tube([V((s * 0.42, 0, 3.0)), V((s * 0.46, 0.05, 2.2)), V((s * 0.46, 0.05, 1.6))], [0.32, 0.34, 0.26], torso, sides=8)
        knee.sphere(0.24, plate, loc=(s * 0.47, 0.22, 1.55), segs=8, rings=5)
        knee.spike((s * 0.47, 0.4, 1.55), (s * 0.47, 0.75, 1.65), 0.1, plate, segs=4)
        knee.tube([V((s * 0.46, 0.05, 1.5)), V((s * 0.48, 0.05, 0.8)), V((s * 0.48, 0.05, 0.3))], [0.26, 0.28, 0.22], plate, sides=8)
        knee.box((0.44, 0.9, 0.26), torso, loc=(s * 0.48, 0.2, 0.13), bevel=0.08)
        legs[side] = (leg, knee)
    return body, head, arms, legs


# ============================================================================ Abyss Reaver (Regular, WEAPON_BIPED)
def abyss_reaver():
    A = M.MobAsset("mob_abyss_reaver", "WEAPON_BIPED", ATLAS, "REGULAR")
    body, head, arms, legs = biped_body(A, "iron_dark", "iron", "crimson")
    # a tattered crimson half-cape off the left shoulder, a crimson sash
    cape = A.segment("ExtraCape", (-0.45, -0.55, 5.2), body)  # the half-cape (Cloth spring)
    tattered(cape, 1.0, 3.0, "silk", K.M((-0.45, -0.55, 5.2), (6, 0, 8)), teeth=4, seed=1)
    body.tube([V((-0.8, 0.55, 4.9)), V((0, 0.62, 4.1)), V((0.8, 0.58, 3.35))], [0.09] * 3, "crimson_dark", sides=5)
    body.box((0.25, 0.12, 0.25), CRIMSON, loc=(0, 0.66, 4.45), rot=(0, 45, 0))
    # head: a narrow visored helm with crimson eye slits and swept horns
    head.sphere(0.45, "iron_dark", loc=(0, 0.05, 5.85), scale=(0.95, 1.1, 1.15), segs=12, rings=8)
    head.box((0.5, 0.12, 0.3), "iron", loc=(0, 0.48, 5.75), bevel=0.04)
    for s in (1, -1):
        head.box((0.16, 0.05, 0.04), CRIMSON, loc=(s * 0.14, 0.55, 5.85), rot=(0, s * 12, 0))
        head.tube([V((s * 0.32, -0.05, 6.15)), V((s * 0.55, -0.35, 6.45)), V((s * 0.6, -0.75, 6.5))], [0.09, 0.06, 0.0], "iron_light", sides=5)
    # hooked twin blades
    for side in ("L", "R"):
        s = -1 if side == "L" else 1
        fore = arms[side][1]
        hilt = V((s * 1.15, 0.22, 2.8))
        fore.rod(hilt + V((0, 0, 0.22)), hilt - V((0, 0, 0.22)), 0.06, "leather", segs=6)
        fore.box((0.1, 0.36, 0.08), "crimson", loc=hilt + V((0, 0, 0.26)))
        blade = [(0.05, 0), (0.12, 0.6), (0.1, 1.3), (-0.05, 1.7), (-0.35, 1.85), (-0.5, 1.65), (-0.25, 1.55), (-0.08, 1.25), (-0.06, 0.6)]
        fore.prism(blade, 0.06, "iron_light", mat=K.M(hilt + V((0, 0.05, 0.25)), (-60, 0, 0)) @ K.M(rot=(0, 0, 90)))
        fore.prism([(0.0, 0.3), (0.05, 0.3), (0.05, 1.25), (0.0, 1.25)], 0.08, CRIMSON, mat=K.M(hilt + V((0, 0.05, 0.25)), (-60, 0, 0)) @ K.M(rot=(0, 0, 90)))
    return A


# ============================================================================ casters (CASTER_BIPED)
def caster_frame(A, robe, robe_dark, trim):
    body = A.segment("Body", (0, 0, 2.6))
    head = A.segment("Head", (0, 0.05, 4.35), body)
    body.tube([V((0, 0, 0.2)), V((0, 0, 1.6)), V((0, 0.03, 3.1)), V((0, 0, 4.3))], [(0.95, 0.85), (0.78, 0.68), (0.62, 0.5), (0.48, 0.4)], robe, sides=12)
    body.tube([V((0, 0, 0.2)), V((0, 0, 0.38))], [(0.97, 0.87), (0.95, 0.85)], trim, sides=12)
    body.torus(0.62, 0.07, trim, mat=K.M((0, 0.02, 3.1)) @ K.M(scale=(1, 0.82, 1)), major=16, minor=4)
    for s, side in ((-1, "L"), (1, "R")):
        arm = A.segment(f"Arm{side}", (s * 0.55, 0, 4.05), body)
        fore = A.segment(f"Forearm{side}", (s * 0.78, 0.15, 3.35), arm)
        arm.tube([V((s * 0.5, 0, 4.1)), V((s * 0.72, 0.1, 3.6)), V((s * 0.78, 0.15, 3.35))], [0.17, 0.19, 0.21], robe, sides=8)
        fore.tube([V((s * 0.78, 0.15, 3.35)), V((s * 0.82, 0.35, 2.85))], [0.22, 0.3], robe_dark, sides=8)
        fore.sphere(0.12, "skin", loc=(s * 0.82, 0.4, 2.75), segs=8, rings=5)
    for s, side in ((-1, "L"), (1, "R")):
        leg = A.segment(f"Leg{side}", (s * 0.25, 0, 2.4), body)
        knee = A.segment(f"Knee{side}", (s * 0.28, 0.05, 1.2), leg)
        leg.tube([V((s * 0.25, 0, 2.45)), V((s * 0.28, 0.05, 1.2))], [0.16, 0.14], robe_dark, sides=7)
        knee.tube([V((s * 0.28, 0.05, 1.2)), V((s * 0.3, 0.1, 0.25))], [0.14, 0.12], robe_dark, sides=7)
        knee.box((0.32, 0.55, 0.16), "iron_dark", loc=(s * 0.3, 0.28, 0.08), bevel=0.04)
    return body, head


def void_invoker():
    A = M.MobAsset("mob_void_invoker", "CASTER_BIPED", ATLAS, "REGULAR")
    body, head = caster_frame(A, "void_dark", "black", "crimson")
    # crimson-lined robes split at the front, a deep hood, a crackling void orb held up in both hands
    body.prism([(-0.25, 0), (0.25, 0), (0.42, -3.6), (-0.42, -3.6)], 0.05, "crimson_dark", loc=(0, 0.47, 4.0), rot=(-9, 0, 0))
    for k in range(4):
        body.box((0.3, 0.06, 0.04), "gold_dark", loc=(0, 0.56 + k * 0.12, 3.4 - k * 0.7), rot=(-9, 0, 0))
    head.tube([V((0, -0.05, 4.3)), V((0, -0.08, 4.85)), V((0, -0.12, 5.25)), V((0, -0.4, 5.55))], [(0.55, 0.52), (0.58, 0.56), (0.48, 0.48), (0.0, 0.0)], "void_dark", sides=10)
    head.sphere(0.38, "black", loc=(0, 0.12, 4.75), segs=10, rings=6)
    for s in (1, -1):
        head.box((0.12, 0.05, 0.05), VOID, loc=(s * 0.14, 0.5, 4.8))
    fore = A.seg("ForearmR")
    c = V((0.45, 0.85, 3.25))
    fore.sphere(0.32, VOID, loc=c, segs=12, rings=8)
    fore.torus(0.48, 0.03, CRIMSON, loc=c, rot=(70, 20, 0), major=18, minor=3)
    for k in range(5):
        a = 2 * math.pi * k / 5
        crackle(fore, c, c + V((math.cos(a) * 0.75, math.sin(a) * 0.3, math.sin(a) * 0.6)), 3, 0.1, 0.025, VOID if k % 2 else CRIMSON, seed=k)
    left = A.seg("ForearmL")
    crackle(left, (-0.82, 0.45, 2.8), c + V((-0.2, 0, 0)), 4, 0.12, 0.025, VOID, seed=9)
    return A


def void_hierophant():
    A = M.MobAsset("mob_void_hierophant", "CASTER_BIPED", ATLAS, "SUPPORT")
    body, head = caster_frame(A, "crimson_dark", "black", "gold")
    # layered vestments, a void stole, a bone mask under a tall crown-mitre, a swinging void censer
    body.tube([V((0, 0, 2.6)), V((0, 0.02, 3.6)), V((0, 0, 4.25))], [(0.75, 0.62), (0.7, 0.58), (0.52, 0.44)], "crimson", sides=12)
    for x in (-0.22, 0.22):
        body.prism([(-0.11, 0), (0.11, 0), (0.13, -3.6), (-0.13, -3.6)], 0.05, "void", loc=(x, 0.49, 4.15), rot=(-8, 0, 0))
    body.torus(0.52, 0.14, "gold_dark", mat=K.M((0, 0, 4.2)) @ K.M(scale=(1, 0.85, 1)), major=16, minor=5)
    head.sphere(0.4, "black", loc=(0, 0.1, 4.72), segs=10, rings=7)
    head.sphere(0.36, "bone", loc=(0, 0.22, 4.72), scale=(0.95, 0.6, 1.1), segs=12, rings=7)
    for s in (1, -1):
        head.box((0.13, 0.05, 0.05), VOID, loc=(s * 0.14, 0.45, 4.82))
    head.box((0.06, 0.04, 0.3), "crimson", loc=(0, 0.45, 4.55))
    mitre = [(-0.42, 0), (0.42, 0), (0.36, 0.7), (0.2, 1.3), (0, 1.55), (-0.2, 1.3), (-0.36, 0.7)]
    head.prism(mitre, 0.62, "iron_dark", loc=(0, 0.05, 5.0))
    head.prism([(-0.12, 0.15), (0.12, 0.15), (0.08, 1.1), (0, 1.25), (-0.08, 1.1)], 0.66, "crimson", loc=(0, 0.05, 5.0))
    for k in range(5):
        a = math.radians(-60 + k * 30)
        b = V((math.sin(a) * 0.42, 0.05, 5.05))
        head.spike(b, b + V((math.sin(a) * 0.25, 0, 0.45 - abs(k - 2) * 0.1)), 0.05, "gold", segs=4)
    head.sphere(0.07, CRIMSON, loc=(0, 0.38, 6.25), segs=6, rings=4)
    c = V((-0.82, 0.55, 1.85))
    left = A.segment("ExtraCenser", (-0.82, 0.42, 2.65), A.seg("ForearmL"))  # swings on its chain (Hanging spring)
    chain_links(left, [(-0.82, 0.42, 2.65), c + V((0, 0, 0.35))], 0.06, ("gold_dark",))
    left.sphere(0.25, "iron_dark", loc=c, scale=(1, 1, 0.85), segs=10, rings=6)
    left.torus(0.25, 0.04, "gold", loc=c, major=12, minor=4)
    left.spike(c + V((0, 0, 0.2)), c + V((0, 0, 0.45)), 0.1, "gold_dark", segs=6)
    left.sphere(0.13, VOID, loc=c, segs=8, rings=5)
    for k in range(3):
        left.sphere(0.06 + 0.02 * k, VOID, loc=c + V((0.05 * k, -0.05 * k, 0.55 + k * 0.25)), segs=6, rings=4)
    right = A.seg("ForearmR")
    right.rod((0.82, 0.42, 0.9), (0.82, 0.42, 5.0), 0.05, "iron_dark", segs=6)
    right.torus(0.2, 0.04, "gold", loc=(0.82, 0.42, 5.15), rot=(90, 0, 0), major=12, minor=4)
    right.sphere(0.1, CRIMSON, loc=(0.82, 0.42, 5.15), segs=6, rings=4)
    return A


# ============================================================================ Throne Executioner Elite / Alpha (HEAVY_BIPED)
def throne_executioner(alpha=False):
    A = M.MobAsset("alpha_throne_executioner" if alpha else "elite_throne_executioner", "HEAVY_BIPED", ATLAS_ALPHA if alpha else ATLAS, "ALPHA" if alpha else "ELITE")
    body = A.segment("Body", (0, 0, 3.15))
    head = A.segment("Head", (0, 0.25, 5.3), body)
    # a hulking bare-armed brute in a blackened iron cuirass and a crimson-stained leather apron
    body.sphere(1.0, "iron_dark", loc=(0, 0.1, 4.3), scale=(1.25, 0.85, 1.1), segs=14, rings=8)
    body.sphere(1.0, "leather", loc=(0, 0, 3.2), scale=(1.0, 0.75, 0.7), segs=12, rings=7)
    body.prism([(-0.8, 0), (0.8, 0), (0.9, -2.7), (-0.9, -2.7)], 0.08, "leather", loc=(0, 0.82, 4.4), rot=(-4, 0, 0))
    body.prism([(-0.5, -1.4), (0.3, -1.6), (0.6, -2.6), (-0.7, -2.6)], 0.09, "crimson_dark", loc=(0, 0.83, 4.4), rot=(-4, 0, 0))
    body.box((1.85, 0.1, 0.15), "black", loc=(0, 0.78, 3.3))
    for k in range(6):
        a = 2 * math.pi * k / 6
        body.spike((math.cos(a) * 1.0, 0.1 + math.sin(a) * 0.7, 5.0), (math.cos(a) * 1.3, 0.1 + math.sin(a) * 0.9, 5.25), 0.1, "iron", segs=4)
    if alpha:
        tattered(body, 1.3, 4.2, "silk", K.M((0, -0.72, 5.6), (4, 0, 0)), teeth=5, seed=3)
        body.rod((-0.8, -0.75, 5.65), (0.8, -0.75, 5.65), 0.05, "gold", segs=6)
        body.sphere(0.12, CRIMSON, loc=(0, -0.8, 4.6), segs=6, rings=4)
    # head: a tall pointed executioner's hood with crimson eye holes
    head.tube([V((0, 0.4, 5.2)), V((0, 0.45, 5.8)), V((0, 0.35, 6.3)), V((0, 0.1, 6.7))], [(0.5, 0.48), (0.5, 0.5), (0.38, 0.38), (0.0, 0.0)], "black", sides=10)
    for s in (1, -1):
        head.box((0.14, 0.06, 0.08), CRIMSON, loc=(s * 0.17, 0.92, 5.85))
    # arms: bare scarred arms with iron bracers; an oversized axe in the right hand
    for s, side in ((-1, "L"), (1, "R")):
        arm = A.segment(f"Arm{side}", (s * 1.35, 0, 4.85), body)
        fore = A.segment(f"Forearm{side}", (s * 1.6, 0.15, 3.6), arm)
        arm.sphere(0.55, "skin", loc=(s * 1.38, 0, 4.95), segs=10, rings=6)
        arm.tube([V((s * 1.35, 0, 4.8)), V((s * 1.6, 0.15, 3.6))], [0.45, 0.4], "skin", sides=8)
        fore.tube([V((s * 1.6, 0.15, 3.6)), V((s * 1.7, 0.35, 2.55))], [0.42, 0.36], "skin", sides=8)
        fore.cyl(0.46, 0.46, 0.55, "iron_dark", loc=(s * 1.68, 0.3, 2.85), segs=10)
        for k in range(3):
            fore.spike((s * 1.68, 0.3 + math.cos(k * 2.1) * 0.46, 2.85 + math.sin(k * 2.1) * 0.2), (s * 1.68, 0.3 + math.cos(k * 2.1) * 0.75, 2.85 + math.sin(k * 2.1) * 0.3), 0.07, "iron", segs=4)
        fore.sphere(0.36, "skin", loc=(s * 1.72, 0.4, 2.35), segs=10, rings=6)
        if s == 1:
            g = V((1.72, 0.45, 2.3))
            fore.rod(g - V((0, 0, 1.6)), g + V((0, 0, 2.6)), 0.08, "leather", segs=6)
            for z in (-1.0, 0.0, 1.0):
                fore.torus(0.1, 0.03, "iron", loc=g + V((0, 0, z)), major=8, minor=3)
            head_c = g + V((0, 0, 2.3))
            fore.prism([(0, 0.55), (0.25, 0.55), (1.6, 1.15), (2.0, 0.2), (1.75, -0.9), (0.25, -0.35), (0, -0.35)], 0.14, "iron", loc=head_c, rot=(0, 0, 90))
            fore.prism([(1.55, 1.05), (1.9, 0.2), (1.65, -0.8), (1.45, -0.6), (1.65, 0.2), (1.35, 0.9)], 0.16, "iron_light", loc=head_c, rot=(0, 0, 90))
            fore.prism([(0.4, 0.3), (1.2, 0.6), (1.4, 0.0), (0.4, -0.15)], 0.17, CRIMSON, loc=head_c, rot=(0, 0, 90))
            fore.spike(head_c + V((0, -0.05, 0.1)), head_c + V((0, -0.7, 0.1)), 0.12, "iron", segs=5)
    for s, side in ((-1, "L"), (1, "R")):
        leg = A.segment(f"Leg{side}", (s * 0.6, 0, 2.85), body)
        knee = A.segment(f"Knee{side}", (s * 0.65, 0.05, 1.5), leg)
        leg.tube([V((s * 0.6, 0, 2.9)), V((s * 0.66, 0.05, 2.1)), V((s * 0.65, 0.05, 1.55))], [0.48, 0.5, 0.38], "leather", sides=8)
        knee.sphere(0.32, "iron", loc=(s * 0.66, 0.3, 1.5), segs=8, rings=5)
        knee.tube([V((s * 0.65, 0.05, 1.5)), V((s * 0.68, 0.05, 0.8)), V((s * 0.68, 0.05, 0.3))], [0.36, 0.38, 0.32], "iron_dark", sides=8)
        knee.box((0.7, 1.05, 0.32), "iron_dark", loc=(s * 0.68, 0.2, 0.16), bevel=0.1)
    if alpha:
        pauldron = A.segment("Trophy_SkullPauldron", (-1.4, 0, 5.3), A.seg("ArmL"))
        pauldron.sphere(0.62, "iron_light", loc=(-1.42, 0, 5.15), scale=(1.05, 1.05, 0.65), segs=12, rings=6)
        pauldron.sphere(0.36, "bone", loc=(-1.5, 0.35, 5.5), scale=(0.9, 0.9, 1.0), segs=10, rings=7)
        pauldron.box((0.4, 0.2, 0.18), "bone", loc=(-1.5, 0.55, 5.27), bevel=0.04)
        for s in (1, -1):
            pauldron.sphere(0.08, CRIMSON, loc=(-1.5 + s * 0.13, 0.65, 5.55), segs=6, rings=4)
        for k in range(3):
            pauldron.spike((-1.42 - 0.2 * k, -0.2, 5.45), (-1.7 - 0.25 * k, -0.4, 6.0 - 0.1 * k), 0.08, "gold_dark", segs=4)
    return scaled(A, 1.3)


# ============================================================================ Crimson Overlord (Biome Boss, ROYAL_COLOSSUS)
def crimson_overlord():
    A = M.MobAsset("boss_crimson_overlord", "ROYAL_COLOSSUS", ATLAS, "BOSS")
    body, head, arms, legs = biped_body(A, "iron_dark", "iron", "gold_dark")
    rnd = random.Random(50)
    # a crimson silk tabard, a void sigil, and an articulated mantle of hanging chains
    body.prism([(-0.5, 0), (0.5, 0), (0.55, -2.55), (0, -2.8), (-0.55, -2.55)], 0.06, "crimson", loc=(0, 0.67, 4.75))
    body.prism([(-0.58, 0.05), (0.58, 0.05), (0.63, -2.6), (0, -2.9), (-0.63, -2.6)], 0.04, "gold_dark", loc=(0, 0.65, 4.75))
    body.cyl(0.28, 0.28, 0.06, "black", loc=(0, 0.72, 4.1), rot=(90, 0, 0), segs=8)
    body.cyl(0.18, 0.18, 0.08, VOID, loc=(0, 0.74, 4.1), rot=(90, 0, 0), segs=8)
    body.torus(0.7, 0.18, "crimson_dark", mat=K.M((0, -0.04, 5.2)) @ K.M(scale=(1.1, 0.85, 1)), major=18, minor=6)
    # the chain mantle in three hanging groups: the two left chains, the centre one, the two right (Cloth springs)
    mantles = [A.segment(name, (gx, -0.65, 5.15), body) for name, gx in (("ExtraMantleL", -0.75), ("ExtraMantle", 0.0), ("ExtraMantleR", 0.75))]
    for k in range(5):
        x = -1.0 + k * (2.0 / 4)
        top = V((x, -0.6 - abs(x) * 0.1, 5.15))
        bottom = top + V((x * 0.15, -0.5 - rnd.uniform(0, 0.2), -4.4 + abs(x) * 0.6))
        group = mantles[(0, 0, 1, 2, 2)[k]]
        chain_links(group, [top, top.lerp(bottom, 0.5) + V((0, -0.15, 0)), bottom], 0.17, ("chain", "iron_dark"))
        group.spike(bottom, bottom + V((0, -0.05, -0.35)), 0.09, "iron_light", segs=4)
    for k in range(4):
        body.sphere(0.06, CRIMSON, loc=(-0.85 + k * 0.57, -0.7, 4.95), segs=6, rings=4)
    # head: a closed black helm with a crimson visor, under a tall crown of iron spikes
    head.sphere(0.5, "iron_dark", loc=(0, 0.05, 5.85), scale=(1.0, 1.05, 1.1), segs=12, rings=8)
    head.box((0.66, 0.1, 0.1), CRIMSON, loc=(0, 0.55, 5.9))
    head.box((0.1, 0.1, 0.4), CRIMSON, loc=(0, 0.55, 5.72))
    head.box((0.78, 0.14, 0.12), "iron", loc=(0, 0.53, 6.05), bevel=0.03)
    head.torus(0.5, 0.08, "gold", loc=(0, 0.05, 6.3), major=18, minor=5)
    for k in range(9):
        a = 2 * math.pi * k / 9 + math.pi / 2
        b = V((math.cos(a) * 0.5, 0.05 + math.sin(a) * 0.5, 6.32))
        h = 1.1 if k == 0 else (0.75 if k % 2 else 0.5)
        head.spike(b, b + V((math.cos(a) * 0.12, math.sin(a) * 0.12, h)), 0.1, "iron_dark", segs=4)
        if k % 3 == 0:
            head.sphere(0.07, CRIMSON, loc=b + V((0, 0, 0.12)), segs=6, rings=4)
    # the sword of crimson light, raised in the right hand
    fore = arms["R"][1]
    hand = V((1.15, 0.3, 2.8))
    fore.rod(hand - V((0, 0, 0.4)), hand + V((0, 0, 0.35)), 0.07, "black", segs=6)
    fore.sphere(0.12, "gold", loc=hand - V((0, 0, 0.46)), segs=8, rings=5)
    fore.prism([(-0.55, 0), (0.55, 0), (0.45, 0.18), (-0.45, 0.18)], 0.16, "iron_dark", loc=hand + V((0, 0, 0.38)))
    for s in (1, -1):
        fore.spike(hand + V((s * 0.5, 0, 0.45)), hand + V((s * 0.7, 0.1, 0.75)), 0.06, "gold_dark", segs=4)
    base = hand + V((0, 0, 0.56))
    fore.prism([(-0.24, 0), (0.24, 0), (0.26, 3.7), (0, 4.3), (-0.26, 3.7)], 0.1, CRIMSON, loc=base)
    fore.prism([(-0.08, 0.1), (0.08, 0.1), (0.08, 3.6), (0, 3.9), (-0.08, 3.6)], 0.14, VOID, loc=base)
    left = arms["L"][1]
    left.box((0.5, 0.42, 0.3), "iron", loc=(-1.15, 0.3, 2.65), bevel=0.05)
    for k in range(3):
        left.spike((-1.15 + (k - 1) * 0.14, 0.45, 2.55), (-1.17 + (k - 1) * 0.16, 0.75, 2.3), 0.04, "iron_dark", segs=4)
    return scaled(A, 2.5)


BUILDERS = {
    "mob_abyss_reaver": abyss_reaver,
    "mob_void_invoker": void_invoker,
    "mob_void_hierophant": void_hierophant,
    "elite_throne_executioner": lambda: throne_executioner(False),
    "alpha_throne_executioner": lambda: throne_executioner(True),
    "boss_crimson_overlord": crimson_overlord,
}
