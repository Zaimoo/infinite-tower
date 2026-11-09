"""
Biome 8: Sunken Sanctuary (floors 36-40). docs/tower-mob-remodel-plan.md §5.8.
Drowned temple. Motif: verdigris bronze, coral growth and shell spirals. Glow: aqua.

Blender coordinates: 1 unit = 1 stud, Z up, ground z = 0, enemies face +Y, their right hand is +X.
The crab uses the crawler joints (Jaw = pincers). The Leviathan (SERPENT) uses the biped joint names like the
old part rig: Body = the reared neck, Arm/Forearm = the side fins, and the body's ground coil runs
Body -> LegR -> KneeR, then LegL -> KneeL out to the tail fin (the slither clip yaws these).
"""
import math, random
from mathutils import Vector
import raid_kit as K
import mob_kit as M

V = Vector
K.GLOW["aqua"] = (70, 240, 222)
K.GLOW["pearl"] = (226, 250, 255)
AQUA = "glow:aqua"
PEARL = "glow:pearl"

ATLAS = M.Atlas("sunken_sanctuary", {
    "verdigris": (76, 150, 128), "verdigris_dark": (44, 96, 84), "bronze": (156, 112, 62), "bronze_dark": (100, 70, 40),
    "coral": (230, 112, 92), "coral_dark": (160, 64, 60), "coral_pink": (236, 156, 164), "shell": (232, 214, 190), "shell_dark": (176, 150, 124),
    "nacre": (212, 222, 232), "kelp": (62, 104, 64), "kelp_dark": (36, 66, 44), "skin": (88, 132, 132), "belly": (172, 194, 176),
    "robe": (58, 78, 104), "robe_dark": (34, 46, 68), "crab": (186, 82, 58), "crab_dark": (120, 48, 40), "barnacle": (204, 198, 182),
    "stone": (120, 132, 132), "gold": (232, 190, 88), "gold_dark": (160, 122, 56), "black": (14, 18, 22),
})
ATLAS_ALPHA = M.Atlas("sunken_sanctuary_alpha", dict(ATLAS.colours, **{
    "verdigris_dark": (150, 128, 70), "bronze": (226, 182, 92), "verdigris": (110, 170, 120),
}))


def scaled(A, s):
    """Scale an authored asset about the ground origin (UVs were set at paint time and do not change)."""
    for seg in A.segments:
        for v in seg.bm.verts:
            v.co *= s
        seg.pivot = V(seg.pivot) * s
    return A


def coral(seg, base, direction, length, colour, seed=0, r=0.09):
    """A branching coral sprig."""
    rnd = random.Random(seed)
    base, d = V(base), V(direction).normalized()
    tip = base + d * length
    seg.tube([base, base.lerp(tip, 0.5) + V((rnd.uniform(-0.05, 0.05), 0, 0)), tip], [r, r * 0.8, r * 0.35], colour, sides=5)
    for k in range(2):
        p = base.lerp(tip, 0.4 + 0.25 * k)
        side = d.cross(V((0, 0, 1)))
        if side.length < 1e-3:
            side = V((1, 0, 0))
        side.normalize()
        t = p + (d * 0.6 + side * (1 if k % 2 else -1) * 0.7).normalized() * length * 0.45
        seg.spike(p, t, r * 0.6, colour, segs=4)


def nautilus(seg, mat, r, colour="shell", stripe="shell_dark", glow=None):
    """A flat nautilus disc in the local XZ plane (facing local +Y) with a spiral ridge."""
    seg.cyl(r, r, 0.22, colour, mat=mat @ K.M(rot=(90, 0, 0)), segs=14)
    pts = []
    for i in range(22):
        th = i / 21 * 2.2 * math.pi
        rr = r * (0.95 - 0.8 * i / 21)
        pts.append(mat @ V((math.cos(th) * rr, 0.13, math.sin(th) * rr)))
    seg.tube(pts, [r * 0.09 * (1 - 0.7 * i / 21) for i in range(22)], stripe, sides=4)
    if glow:
        seg.sphere(r * 0.16, glow, loc=mat @ V((0, 0.14, 0)), segs=6, rings=4)


# ============================================================================ Tide Claw (Regular, CRUSTACEAN)
def tide_claw():
    A = M.MobAsset("mob_tide_claw", "CRUSTACEAN", ATLAS, "REGULAR")
    body = A.segment("Body", (0, 0, 1.4))
    head = A.segment("Head", (0, 1.3, 1.45), body)
    rnd = random.Random(36)
    # a wide shell crusted with coral and barnacles
    body.sphere(1.0, "crab", loc=(0, 0, 1.5), scale=(1.55, 1.2, 0.6), segs=14, rings=8)
    body.sphere(1.0, "crab_dark", loc=(0, -0.1, 1.25), scale=(1.4, 1.05, 0.35), segs=12, rings=6)
    for s in (1, -1):
        body.spike((s * 1.4, 0.4, 1.6), (s * 1.85, 0.6, 1.7), 0.15, "crab_dark", segs=4)
    for k in range(7):
        a = rnd.uniform(0, 2 * math.pi)
        c = V((math.cos(a) * rnd.uniform(0.3, 1.1), math.sin(a) * rnd.uniform(0.2, 0.8) - 0.1, 2.0))
        body.cyl(0.12, 0.08, 0.14, "barnacle", loc=c, segs=6)
    coral(body, (-0.5, -0.3, 1.95), (-0.3, -0.2, 1), 0.8, "coral", seed=1)
    coral(body, (0.4, -0.5, 1.95), (0.25, -0.3, 1), 0.65, "coral_pink", seed=2)
    coral(body, (0.0, 0.1, 2.05), (0.0, 0.2, 1), 0.5, "coral", seed=3)
    # head: eyestalks with aqua eyes, little mouthparts
    head.box((0.9, 0.35, 0.3), "crab_dark", loc=(0, 1.3, 1.45), bevel=0.06)
    for s in (1, -1):  # eyestalks (ExtraEyeL/R, Rigid springs)
        eye = A.segment("ExtraEyeR" if s == 1 else "ExtraEyeL", (s * 0.25, 1.35, 1.55), head)
        eye.rod((s * 0.25, 1.35, 1.55), (s * 0.32, 1.45, 2.05), 0.05, "crab", segs=5)
        eye.sphere(0.1, AQUA, loc=(s * 0.32, 1.45, 2.1), segs=6, rings=4)
    # pincers (Jaw): the right one is much bigger
    for s, side in ((-1, "L"), (1, "R")):
        big = s == 1
        jaw = A.segment(f"Jaw{side}", (s * 0.9, 1.0, 1.4), head)
        k = 1.35 if big else 0.85
        arm = [V((s * 0.9, 1.0, 1.4)), V((s * 1.5, 1.6, 1.55)), V((s * 1.55, 2.3, 1.55))]
        jaw.tube(arm, [0.16 * k, 0.15 * k, 0.17 * k], "crab", sides=7)
        claw = arm[-1] + V((0, 0.3 * k, 0))
        jaw.sphere(0.38 * k, "crab", loc=claw, scale=(0.8, 1.2, 0.75), segs=10, rings=6)
        jaw.tube([claw + V((s * 0.12 * k, 0.3 * k, 0.08)), claw + V((s * 0.1 * k, 0.8 * k, 0.1)), claw + V((-s * 0.05, 1.05 * k, 0.05))], [0.16 * k, 0.12 * k, 0.0], "crab_dark", sides=5)
        jaw.tube([claw + V((-s * 0.12 * k, 0.3 * k, -0.08)), claw + V((-s * 0.08 * k, 0.7 * k, -0.1)), claw + V((s * 0.02, 0.9 * k, -0.05))], [0.12 * k, 0.09 * k, 0.0], "crab_dark", sides=5)
        if big:
            jaw.cyl(0.1, 0.07, 0.12, "barnacle", loc=claw + V((0, 0, 0.3)), segs=6)
    # six jointed legs
    for s in (-1, 1):
        for i in (1, 2, 3):
            y = (2 - i) * 0.6 - 0.1
            hip = V((s * 1.2, y, 1.3))
            knee = V((s * 2.0, y * 1.2, 1.7))
            foot = V((s * 2.5, y * 1.4, 0.0))
            leg = A.segment(f"Leg{s}_{i}", hip, body)
            shin = A.segment(f"Knee{s}_{i}", knee, leg)
            leg.tube([hip, hip.lerp(knee, 0.5) + V((0, 0, 0.12)), knee], [0.13, 0.12, 0.1], "crab", sides=6)
            shin.tube([knee, knee.lerp(foot, 0.5) + V((s * 0.1, 0, 0.05)), foot + V((0, 0, 0.05))], [0.1, 0.07, 0.02], "crab_dark", sides=6)
    return A


# ============================================================================ casters (CASTER_BIPED)
def caster_frame(A, robe, robe_dark, trim):
    body = A.segment("Body", (0, 0, 2.6))
    head = A.segment("Head", (0, 0.05, 4.35), body)
    body.tube([V((0, 0, 0.2)), V((0, 0, 1.6)), V((0, 0.03, 3.1)), V((0, 0, 4.3))], [(0.92, 0.82), (0.76, 0.66), (0.6, 0.5), (0.46, 0.4)], robe, sides=12)
    body.tube([V((0, 0, 0.2)), V((0, 0, 0.38))], [(0.94, 0.84), (0.92, 0.82)], trim, sides=12)
    body.torus(0.6, 0.07, trim, mat=K.M((0, 0.02, 3.1)) @ K.M(scale=(1, 0.82, 1)), major=16, minor=4)
    for s, side in ((-1, "L"), (1, "R")):
        arm = A.segment(f"Arm{side}", (s * 0.55, 0, 4.05), body)
        fore = A.segment(f"Forearm{side}", (s * 0.78, 0.15, 3.35), arm)
        arm.tube([V((s * 0.5, 0, 4.1)), V((s * 0.72, 0.1, 3.6)), V((s * 0.78, 0.15, 3.35))], [0.17, 0.19, 0.21], robe, sides=8)
        fore.tube([V((s * 0.78, 0.15, 3.35)), V((s * 0.82, 0.35, 2.85))], [0.22, 0.27], robe_dark, sides=8)
        fore.sphere(0.12, "skin", loc=(s * 0.82, 0.4, 2.75), segs=8, rings=5)
        for k in range(2):
            fore.spike((s * (0.82 + 0.05 * k), 0.45, 2.7), (s * (0.85 + 0.08 * k), 0.62, 2.6), 0.03, "skin", segs=4)
    for s, side in ((-1, "L"), (1, "R")):
        leg = A.segment(f"Leg{side}", (s * 0.25, 0, 2.4), body)
        knee = A.segment(f"Knee{side}", (s * 0.28, 0.05, 1.2), leg)
        leg.tube([V((s * 0.25, 0, 2.45)), V((s * 0.28, 0.05, 1.2))], [0.16, 0.14], robe_dark, sides=7)
        knee.tube([V((s * 0.28, 0.05, 1.2)), V((s * 0.3, 0.1, 0.25))], [0.14, 0.12], "skin", sides=7)
        knee.prism([(-0.2, 0), (0.2, 0), (0.28, 0.55), (0, 0.45), (-0.28, 0.55)], 0.06, "skin", loc=(s * 0.3, 0.05, 0.05), rot=(90, 0, 0))
    return body, head


def fish_head(head, hood_colour):
    """A round amphibious head with wide-set aqua eyes, a lipless mouth and gill frills."""
    head.sphere(0.45, "skin", loc=(0, 0.1, 4.75), scale=(1.05, 1.0, 0.95), segs=12, rings=7)
    head.sphere(0.3, "belly", loc=(0, 0.3, 4.55), scale=(1.1, 0.8, 0.6), segs=10, rings=6)
    head.box((0.42, 0.06, 0.04), "black", loc=(0, 0.53, 4.55))
    for s in (1, -1):
        head.sphere(0.11, AQUA, loc=(s * 0.27, 0.42, 4.85), segs=6, rings=4)
        for k in range(3):
            head.prism([(0, 0), (0.12, 0.25), (0, 0.4 - k * 0.05)], 0.03, "coral_pink", loc=(s * 0.42, 0.0 - k * 0.12, 4.6 + k * 0.05), rot=(0, 0, s * 70))


def drowned_acolyte():
    A = M.MobAsset("mob_drowned_acolyte", "CASTER_BIPED", ATLAS, "REGULAR")
    body, head = caster_frame(A, "robe", "robe_dark", "verdigris")
    # kelp wrapped round the robe, a verdigris fin hood, a shell staff with an aqua pearl
    M.vine_spiral(body, (0, 0.0, 0), 0.75, 0.6, 3.6, 2.0, "kelp", thick=0.07, leaves=10, leaf_colour="kelp_dark", seed=8, rx=None)
    fish_head(head, "verdigris")
    head.tube([V((0, -0.1, 4.4)), V((0, -0.05, 5.0)), V((0, -0.2, 5.4))], [(0.52, 0.5), (0.5, 0.5), (0.0, 0.0)], "verdigris_dark", sides=10)
    head.prism([(0, 0), (0.0, 0.85), (-0.7, 0.4), (-0.9, -0.2)], 0.05, "verdigris", loc=(0, -0.15, 5.0), rot=(0, 0, 90))
    fore = A.seg("ForearmR")
    fore.rod((0.82, 0.42, 0.8), (0.82, 0.42, 5.0), 0.05, "bronze_dark", segs=6)
    nautilus(fore, K.M((0.82, 0.42, 5.4), (0, 0, 0)), 0.42, glow=AQUA)
    coral(fore, (0.82, 0.42, 4.2), (0.4, 0.1, 0.6), 0.5, "coral", seed=4, r=0.06)
    return A


def tide_cantor():
    A = M.MobAsset("mob_tide_cantor", "CASTER_BIPED", ATLAS, "SUPPORT")
    body, head = caster_frame(A, "nacre", "robe", "gold")
    # pale nacre robes with a scalloped shell collar, a conch held up, a ring of water over the head
    for k in range(9):
        a = 2 * math.pi * k / 9
        body.prism([(-0.17, 0), (0.17, 0), (0, 0.3)], 0.04, "shell" if k % 2 else "shell_dark",
                   loc=(math.cos(a) * 0.5, math.sin(a) * 0.43, 4.15), rot=(0, 0, math.degrees(a) - 90))
    body.prism([(-0.3, 0), (0.3, 0), (0.2, -2.6), (-0.2, -2.6)], 0.05, "robe", loc=(0, 0.53, 3.95))
    fish_head(head, "nacre")
    for s in (1, -1):
        for k in range(4):
            head.spike((s * 0.38, -0.05 - k * 0.1, 4.95 - k * 0.08), (s * 0.85, -0.25 - k * 0.15, 5.3 - k * 0.2), 0.05, "coral_pink", segs=4)
    halo = A.segment("ExtraRing", (0, -0.05, 5.55), head)  # the water ring turns over the head (Spin)
    halo.torus(0.62, 0.05, AQUA, loc=(0, -0.05, 5.55), rot=(15, 0, 0), major=20, minor=4)
    halo.torus(0.48, 0.03, PEARL, loc=(0, -0.05, 5.6), rot=(15, 0, 0), major=16, minor=4)
    fore = A.seg("ForearmL")
    c = V((-0.85, 0.6, 3.15))
    pts = [c + V((0, -0.15 + 0.5 * i / 8, 0.1 * math.sin(i)) ) for i in range(9)]
    fore.tube([c + V((0, -0.25, 0)), c + V((0, 0.05, 0.05)), c + V((0, 0.35, 0.1)), c + V((0, 0.55, 0.08))], [0.06, 0.2, 0.26, 0.2], "shell", sides=8)
    for k in range(4):
        fore.spike(c + V((0, 0.1 * k, 0.15)), c + V((0, 0.1 * k, 0.38)), 0.05, "shell_dark", segs=4)
    fore.cyl(0.14, 0.14, 0.04, PEARL, loc=c + V((0, 0.6, 0.08)), rot=(90, 0, 0), segs=8)
    return A


# ============================================================================ Coral Warden Elite / Alpha (ARMORED_BIPED)
def coral_warden(alpha=False):
    A = M.MobAsset("alpha_coral_warden" if alpha else "elite_coral_warden", "ARMORED_BIPED", ATLAS_ALPHA if alpha else ATLAS, "ALPHA" if alpha else "ELITE")
    body = A.segment("Body", (0, 0, 3.15))
    head = A.segment("Head", (0, 0.05, 5.35), body)
    # verdigris plate overgrown with branching coral
    body.tube([V((0, 0, 3.0)), V((0, 0.05, 3.9)), V((0, 0.06, 4.85)), V((0, 0, 5.4))], [(0.88, 0.6), (0.96, 0.66), (1.06, 0.7), (0.64, 0.48)], "verdigris", sides=12)
    body.tube([V((0, 0.26, 3.3)), V((0, 0.38, 3.95)), V((0, 0.42, 4.4))], [(0.68, 0.34), (0.76, 0.34), (0.68, 0.3)], "verdigris_dark", sides=10)
    body.torus(0.9, 0.08, "bronze", mat=K.M((0, 0, 3.15)) @ K.M(scale=(1, 0.72, 1)), major=18, minor=4)
    for k in range(2):
        body.tube([V((0, 0, 3.0 - k * 0.32)), V((0, 0, 2.7 - k * 0.32))], [(0.96 + k * 0.05, 0.68), (1.0 + k * 0.05, 0.72)], "verdigris_dark", sides=12)
    for k, (x, y, z, dx, dz, col) in enumerate(((0.55, 0.62, 4.6, 0.5, 1, "coral"), (-0.6, 0.55, 3.8, -0.6, 0.6, "coral_pink"),
                                                  (0.3, -0.6, 4.9, 0.3, 1, "coral"), (-0.4, -0.62, 4.4, -0.4, 0.8, "coral_pink"))):
        coral(body, (x, y, z), (dx, 0.3 if y > 0 else -0.3, dz), 0.7, col, seed=k, r=0.08)
    rnd = random.Random(8)
    for k in range(6):
        body.cyl(0.1, 0.07, 0.1, "barnacle", loc=(rnd.uniform(-0.7, 0.7), -0.66, rnd.uniform(3.3, 5.0)), rot=(90, 0, 0), segs=6)
    body.cyl(0.18, 0.18, 0.1, AQUA, loc=(0, 0.8, 4.4), rot=(90, 0, 0), segs=8)
    # head: a domed helm with a fin crest and an aqua visor slit
    head.sphere(0.5, "verdigris", loc=(0, 0.05, 5.85), scale=(1, 1.05, 1.1), segs=12, rings=8)
    head.box((0.6, 0.12, 0.1), AQUA, loc=(0, 0.53, 5.85))
    head.box((0.7, 0.14, 0.4), "verdigris_dark", loc=(0, 0.5, 5.55), bevel=0.05)
    head.prism([(0, 0), (0.0, 0.8), (-0.6, 0.55), (-0.95, 0.05)], 0.06, "coral", loc=(0, 0.15, 6.2), rot=(0, 0, 90))
    head.torus(0.5, 0.05, "bronze", loc=(0, 0.05, 5.62), major=16, minor=4)
    # arms: a nautilus shield on the left, a hook-glaive in the right
    for s, side in ((-1, "L"), (1, "R")):
        arm = A.segment(f"Arm{side}", (s * 1.05, 0, 4.95), body)
        fore = A.segment(f"Forearm{side}", (s * 1.2, 0.05, 3.85), arm)
        arm.sphere(0.52, "verdigris", loc=(s * 1.12, 0, 5.08), scale=(1.0, 1.0, 0.7), segs=12, rings=6)
        coral(arm, (s * 1.3, -0.1, 5.35), (s * 0.4, -0.2, 1), 0.55, "coral", seed=20 + (s > 0), r=0.07)
        arm.tube([V((s * 1.08, 0, 4.9)), V((s * 1.2, 0.05, 3.9))], [0.27, 0.24], "verdigris_dark", sides=8)
        fore.tube([V((s * 1.2, 0.05, 3.85)), V((s * 1.25, 0.15, 2.95))], [0.27, 0.25], "verdigris", sides=8)
        fore.sphere(0.21, "bronze", loc=(s * 1.25, 0.2, 2.8), segs=8, rings=5)
        if s == -1:
            nautilus(fore, K.M((-1.55, 0.55, 3.3), (0, 0, -15)), 1.05, "shell", "shell_dark", glow=AQUA)
            fore.torus(1.05, 0.07, "bronze", mat=K.M((-1.55, 0.55, 3.3), (90, 0, -15)), major=20, minor=4)
        else:
            hand = V((1.25, 0.3, 2.8))
            fore.rod((1.25, 0.3, 0.6), (1.25, 0.3, 5.6), 0.06, "bronze_dark", segs=6)
            fore.tube([V((1.25, 0.3, 5.5)), V((1.25, 0.65, 6.0)), V((1.25, 0.95, 5.95)), V((1.25, 1.05, 5.6)), V((1.25, 0.9, 5.35))],
                      [(0.06, 0.2), (0.05, 0.24), (0.05, 0.2), (0.04, 0.12), (0.02, 0.02)], "verdigris", sides=6)
            fore.spike((1.25, 0.3, 5.55), (1.25, 0.2, 6.4), 0.09, "verdigris_dark", segs=5)
            fore.sphere(0.09, AQUA, loc=(1.25, 0.3, 5.55), segs=6, rings=4)
    for s, side in ((-1, "L"), (1, "R")):
        leg = A.segment(f"Leg{side}", (s * 0.45, 0, 2.95), body)
        knee = A.segment(f"Knee{side}", (s * 0.5, 0.05, 1.55), leg)
        leg.tube([V((s * 0.45, 0, 3.0)), V((s * 0.5, 0.05, 2.2)), V((s * 0.5, 0.05, 1.6))], [0.36, 0.38, 0.29], "verdigris_dark", sides=8)
        knee.sphere(0.26, "bronze", loc=(s * 0.51, 0.24, 1.55), segs=8, rings=5)
        knee.tube([V((s * 0.5, 0.05, 1.5)), V((s * 0.52, 0.05, 0.8)), V((s * 0.52, 0.05, 0.3))], [0.29, 0.31, 0.25], "verdigris", sides=8)
        knee.box((0.5, 0.95, 0.3), "verdigris_dark", loc=(s * 0.52, 0.22, 0.15), bevel=0.1)
    if alpha:
        crown = A.segment("Trophy_PearlCrown", (0, 0.05, 6.35), head)
        crown.torus(0.47, 0.07, "gold", loc=(0, 0.05, 6.3), major=18, minor=4)
        for k in range(8):
            a = 2 * math.pi * k / 8 + math.pi / 2
            b = V((math.cos(a) * 0.47, 0.05 + math.sin(a) * 0.47, 6.33))
            crown.spike(b, b + V((math.cos(a) * 0.06, math.sin(a) * 0.06, 0.4 if k % 2 else 0.6)), 0.07, "gold_dark", segs=4)
            if k % 2 == 0:
                crown.sphere(0.09, PEARL, loc=b + V((0, 0, 0.62)), segs=6, rings=4)
        crown.sphere(0.13, PEARL, loc=(0, 0.53, 6.4), segs=8, rings=5)
    return scaled(A, 1.3)


# ============================================================================ Tidal Leviathan (Biome Boss, SERPENT)
def tidal_leviathan():
    A = M.MobAsset("boss_tidal_leviathan", "SERPENT", ATLAS, "BOSS")
    body = A.segment("Body", (0, 0, 1.0))
    head = A.segment("Head", (0, 1.0, 5.6), body)
    rnd = random.Random(40)

    def eel(seg, pts, r0, r1, stripe=True, debris=0, seed=0):
        pts = [V(p) for p in pts]
        n = len(pts)
        radii = [(r0 + (r1 - r0) * i / (n - 1)) for i in range(n)]
        seg.tube(pts, [(r * 1.0, r * 0.9) for r in radii], "skin", sides=10)
        belly = [p + V((0, 0, -0.35 * radii[i])) + ((pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]).cross(V((0, 0, 1))).normalized() * 0.0) for i, p in enumerate(pts)]
        seg.tube(belly, [(r * 0.85, r * 0.6) for r in radii], "belly", sides=8)
        if stripe:
            seg.tube([p + V((0, 0, radii[i] * 0.88)) for i, p in enumerate(pts)], [r * 0.12 for r in radii], AQUA, sides=4)
        for i in range(1, n - 1, 2):
            d = (pts[i + 1] - pts[i - 1]).normalized()
            seg.prism([(0, 0), (radii[i] * 0.5, 0.6 * radii[i] + 0.15), (radii[i] * 1.3, 0)], 0.05, "coral_dark",
                      mat=K.look_matrix(pts[i] + V((0, 0, radii[i] * 0.95)), pts[i] + V((0, 0, radii[i] * 0.95)) + d) @ K.M(rot=(0, 90, 0)) @ K.M(rot=(0, 0, 0)))
        r2 = random.Random(seed)
        for _ in range(debris):
            i = r2.randrange(1, n - 1)
            p = pts[i] + V((r2.uniform(-0.2, 0.2), r2.uniform(-0.2, 0.2), radii[i] * 0.85))
            seg.box((r2.uniform(0.4, 0.7), r2.uniform(0.4, 0.7), r2.uniform(0.3, 0.6)), "bronze" if r2.random() < 0.5 else "verdigris_dark",
                    loc=p, rot=(r2.uniform(-15, 15), r2.uniform(-15, 15), r2.uniform(0, 90)), bevel=0.05)
            coral(seg, p + V((0, 0, 0.25)), (r2.uniform(-0.3, 0.3), r2.uniform(-0.3, 0.3), 1), 0.6, "coral", seed=r2.randrange(99), r=0.07)

    # reared neck rising from the ground coil, with a broken bronze column fused to its back
    neck = [(0, 0.0, 0.7), (0, -0.1, 1.8), (0, 0.1, 3.0), (0, 0.5, 4.2), (0, 0.9, 5.2)]
    eel(body, neck, 0.95, 0.68, debris=1, seed=1)
    M.column(body, V((0.15, -0.95, 2.0)), V((0.15, -0.95, 3.6)), 0.32, "bronze", flutes=8, broken=True, seed=2)
    # head: a long frilled eel-dragon skull with aqua eyes and a gaping jaw of shell teeth
    head.sphere(0.85, "skin", loc=(0, 1.35, 5.75), scale=(0.95, 1.35, 0.8), segs=14, rings=8)
    head.tube([V((0, 1.9, 5.85)), V((0, 2.55, 5.75)), V((0, 2.95, 5.6))], [(0.6, 0.45), (0.48, 0.36), (0.32, 0.25)], "skin", sides=10)
    jaw = A.segment("ExtraJaw", (0, 1.7, 5.3), head)  # gapes on the bite (keyed later)
    jaw.tube([V((0, 1.7, 5.3)), V((0, 2.4, 5.2)), V((0, 2.8, 5.25))], [(0.5, 0.25), (0.4, 0.2), (0.25, 0.14)], "belly", sides=8)
    for k in range(6):
        y = 2.0 + k * 0.15
        for s in (1, -1):
            head.spike((s * (0.38 - k * 0.03), y, 5.5), (s * (0.36 - k * 0.03), y + 0.05, 5.2), 0.05, "shell", segs=4)
    frill = A.segment("ExtraFrill", (0, 1.0, 5.85), head)  # the side frills flare on the windup (keyed later)
    for s in (1, -1):
        head.sphere(0.16, AQUA, loc=(s * 0.55, 1.95, 6.0), segs=8, rings=5)
        head.box((0.4, 0.15, 0.08), "skin", loc=(s * 0.52, 1.95, 6.18), rot=(0, s * -15, 0))
        for k in range(4):
            root = V((s * 0.7, 1.2 - k * 0.2, 5.9 - k * 0.05))
            frill.prism([(0, 0), (0.35, 0.9 - k * 0.12), (0.7, 0.1)], 0.04, "coral" if k % 2 else "coral_pink", loc=root, rot=(0, -s * 25, s * (60 + k * 8)))
            frill.spike(root, root + V((s * 0.7, -0.3, 0.6 - k * 0.1)), 0.04, "coral_dark", segs=4)
    head.prism([(0, 0), (-1.1, 0.7), (-1.8, 0.2), (-1.9, -0.3)], 0.05, "coral_dark", loc=(0, 1.2, 6.35), rot=(0, 0, 90))
    head.sphere(0.12, AQUA, loc=(0, 2.4, 6.15), segs=6, rings=4)
    # side fins (Arm/Forearm)
    for s, side in ((-1, "L"), (1, "R")):
        arm = A.segment(f"Arm{side}", (s * 0.7, 0.2, 3.2), body)
        fore = A.segment(f"Forearm{side}", (s * 1.6, 0.0, 2.6), arm)
        arm.prism([(0, 0), (0.95, 0.45), (1.1, -0.4), (0.3, -0.8)], 0.06, "coral_dark", loc=(s * 0.7, 0.2, 3.2), rot=(0, 0, 0) if s > 0 else (0, 0, 180))
        fore.prism([(0, 0), (0.9, 0.2), (1.25, -0.7), (0.2, -0.6)], 0.05, "coral", loc=(s * 1.6, 0.0, 2.6), rot=(0, 0, 0) if s > 0 else (0, 0, 180))
        fore.tube([V((s * 1.6, 0.0, 2.6)), V((s * 2.5, 0.0, 2.4)), V((s * 2.85, 0.0, 1.9))], [0.06, 0.05, 0.0], AQUA, sides=4)
    # the ground coil: LegR -> KneeR loop round the right and back, LegL -> KneeL out to the tail fin
    legr = A.segment("LegR", (0.4, -0.1, 0.65), body)
    kner = A.segment("KneeR", (1.9, -2.4, 0.6), legr)
    legl = A.segment("LegL", (0.2, -3.4, 0.55), body)
    knel = A.segment("KneeL", (-1.8, -5.3, 0.45), legl)
    eel(legr, [(0.4, -0.1, 0.7), (1.6, 0.2, 0.68), (2.4, -0.9, 0.65), (1.9, -2.4, 0.62)], 0.92, 0.85, debris=1, seed=3)
    eel(kner, [(1.9, -2.4, 0.62), (1.2, -3.3, 0.6), (0.2, -3.4, 0.58)], 0.85, 0.8, debris=1, seed=4)
    eel(legl, [(0.2, -3.4, 0.58), (-1.0, -3.6, 0.55), (-1.9, -4.4, 0.5), (-1.8, -5.3, 0.48)], 0.8, 0.66, debris=1, seed=5)
    tail1 = A.segment("ExtraTail1", (-1.2, -6.3, 0.42), knel)  # the tail carries the S-wave to the fin (keyed later)
    tail2 = A.segment("ExtraTail2", (0.0, -6.9, 0.38), tail1)
    eel(knel, [(-1.8, -5.3, 0.48), (-1.2, -6.3, 0.42)], 0.66, 0.54, debris=0)
    eel(tail1, [(-1.2, -6.3, 0.42), (0.0, -6.9, 0.38)], 0.54, 0.42, debris=0)
    eel(tail2, [(0.0, -6.9, 0.38), (1.0, -7.1, 0.35)], 0.42, 0.3, debris=0)
    tail1.sphere(0.54, "skin", loc=(-1.2, -6.3, 0.42), scale=(1, 1, 0.9), segs=10, rings=6)  # covers the bends
    tail2.sphere(0.42, "skin", loc=(0.0, -6.9, 0.38), scale=(1, 1, 0.9), segs=10, rings=6)
    tail2.prism([(0, 0), (1.2, 0.9), (1.5, 0.0), (1.2, -0.9)], 0.06, "coral", loc=(1.0, -7.1, 0.38), rot=(90, 0, 0))
    tail2.tube([V((1.05, -7.1, 0.4)), V((2.1, -7.1, 1.1)), V((2.4, -7.1, 0.4))], [0.05, 0.04, 0.0], AQUA, sides=4)
    return scaled(A, 2.05)


BUILDERS = {
    "mob_tide_claw": tide_claw,
    "mob_drowned_acolyte": drowned_acolyte,
    "mob_tide_cantor": tide_cantor,
    "elite_coral_warden": lambda: coral_warden(False),
    "alpha_coral_warden": lambda: coral_warden(True),
    "boss_tidal_leviathan": tidal_leviathan,
}
