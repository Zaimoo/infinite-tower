"""
Biome 6: Thunder Highlands (floors 26-30). docs/tower-mob-remodel-plan.md §5.6.
Storm-scoured crags. Motif: copper totems and jagged lightning glyphs. Glow: electric violet-white.

Blender coordinates: 1 unit = 1 stud, Z up, ground z = 0, enemies face +Y, their right hand is +X.
Birds (AVIAN / GIANT_AVIAN) use the biped joint names: Arm = inner wing, Forearm = outer wing (the clips flap
them about the forward axis), Leg/Knee = the legs. The ram (QUADRUPED) has front legs on Arm/Forearm and hind
legs on Leg/Knee. The Storm Roc is the raptor frame scaled up with scaled().
"""
import math, random
from mathutils import Vector
import raid_kit as K
import mob_kit as M

V = Vector
K.GLOW["storm"] = (190, 150, 255)
K.GLOW["spark"] = (238, 234, 255)
STORM = "glow:storm"
SPARK = "glow:spark"

ATLAS = M.Atlas("thunder_highlands", {
    "slate": (92, 100, 116), "slate_dark": (56, 62, 76), "slate_light": (146, 154, 170), "feather_pale": (206, 208, 214),
    "copper": (196, 118, 64), "copper_dark": (128, 72, 40), "verdigris": (84, 156, 136), "beak": (214, 188, 120),
    "talon": (34, 32, 36), "wool": (196, 190, 176), "wool_dark": (140, 132, 120), "hide": (104, 86, 72),
    "horn": (170, 150, 120), "hoof": (44, 38, 36), "cloth": (60, 66, 112), "cloth_dark": (36, 40, 74),
    "leather": (96, 68, 46), "skin": (150, 128, 108), "stone": (120, 116, 110), "gold": (232, 188, 86), "black": (18, 18, 22),
})
ATLAS_ALPHA = M.Atlas("thunder_highlands_alpha", dict(ATLAS.colours, **{
    "copper": (236, 190, 92), "copper_dark": (176, 130, 56), "wool": (220, 214, 198),
}))


def scaled(A, s):
    """Scale an authored asset about the ground origin (UVs were set at paint time and do not change)."""
    for seg in A.segments:
        for v in seg.bm.verts:
            v.co *= s
        seg.pivot = V(seg.pivot) * s
    return A


def feather(seg, root, length, width, colour, yaw=0.0, droop=0.0, tip=None, depth=0.06):
    """A flat feather lying horizontal, growing back (-Y) from root; yaw swings the tip toward +X,
    droop tips it down. tip: a second colour on the last quarter (copper-tipped primaries)."""
    m = K.M(root, (90 + droop, 0, yaw))
    w, L = width, length
    if tip:
        cut = L * 0.74
        seg.prism([(-w / 2, 0), (w / 2, 0), (w * 0.45, cut), (-w * 0.45, cut)], depth, colour, mat=m)
        seg.prism([(-w * 0.45, cut), (w * 0.45, cut), (w * 0.3, L * 0.9), (0, L), (-w * 0.3, L * 0.9)], depth * 1.1, tip, mat=m)
    else:
        seg.prism([(-w / 2, 0), (w / 2, 0), (w * 0.35, L * 0.85), (0, L), (-w * 0.35, L * 0.85)], depth, colour, mat=m)


def lightning(seg, a, b, kinks, amp, r, colour=SPARK, seed=0):
    """A jagged bolt from a to b."""
    a, b = V(a), V(b)
    rnd = random.Random(seed)
    d = b - a
    side = d.cross(V((0, 0, 1)))
    if side.length < 1e-4:
        side = V((1, 0, 0))
    side.normalize()
    up = side.cross(d).normalized()
    pts = [a]
    for k in range(1, kinks):
        t = k / kinks
        off = side * rnd.uniform(-amp, amp) + up * rnd.uniform(-amp, amp) * 0.6
        pts.append(a + d * t + off)
    pts.append(b)
    for p, q in zip(pts, pts[1:]):
        seg.rod(p, q, r, colour, segs=4)


# ============================================================================ the raptor frame (AVIAN)
def raptor(A, herald=False, roc=False):
    """Storm Talon / Squall Herald / Storm Roc share this frame (unit height ~5.6)."""
    body = A.segment("Body", (0, 0, 3.0))
    head = A.segment("Head", (0, 0.8, 4.2), body)
    # body leaning forward, a pale breast, slate back
    body.sphere(1.0, "slate", loc=(0, -0.15, 3.2), rot=(-22, 0, 0), scale=(0.8, 1.2, 0.85), segs=14, rings=8)
    body.sphere(1.0, "feather_pale", loc=(0, 0.45, 3.1), rot=(-15, 0, 0), scale=(0.62, 0.55, 0.75), segs=12, rings=7)
    # tail: a fan of slate feathers (the Herald's stands upright like a display fan); ExtraTailFan, keyed later
    fan = A.segment("ExtraTailFan", (0, -1.15, 3.2), body)
    if herald:
        for k in range(9):
            a = math.radians(-70 + k * 17.5)
            m = K.M((0, -1.15, 3.35), (0, a * 180 / math.pi, 0))
            root = V((0, -1.15, 3.35))
            tipp = root + V((math.sin(a) * 2.2, -0.35, math.cos(a) * 2.2))
            fan.prism([(-0.22, 0), (0.22, 0), (0.18, 1.85), (0, 2.2), (-0.18, 1.85)], 0.05, "slate" if k % 2 else "slate_dark",
                      mat=K.M(root, (8, a * 180 / math.pi, 0)))
            fan.sphere(0.11, STORM, loc=root + V((math.sin(a) * 1.85, -0.3, math.cos(a) * 1.85)), segs=6, rings=4)
    else:
        for k in range(5):
            yaw = (k - 2) * 14
            feather(fan, (0, -1.15, 3.0 - abs(k - 2) * 0.03), 1.7, 0.36, "slate_dark" if k % 2 else "slate", yaw=yaw, droop=18,
                    tip="copper" if not roc else "slate_light")
    # neck and head with a hooked beak (the Herald's beak flares into a speaking horn)
    head.tube([V((0, 0.55, 3.65)), V((0, 0.8, 4.25)), V((0, 0.92, 4.6))], [0.38, 0.32, 0.3], "slate", sides=10)
    head.sphere(0.4, "slate", loc=(0, 1.05, 4.75), scale=(0.9, 1.15, 0.9), segs=12, rings=7)
    head.box((0.7, 0.3, 0.1), "slate_dark", loc=(0, 1.3, 4.98), rot=(-10, 0, 0), bevel=0.03)
    for s in (1, -1):
        head.sphere(0.07, STORM, loc=(s * 0.27, 1.32, 4.86), segs=6, rings=4)
    beak = A.segment("ExtraBeak", (0, 1.4, 4.75), head)  # opens to cry or strike (keyed later)
    if herald:
        beak.rod((0, 1.4, 4.72), (0, 2.05, 4.68), 0.12, "copper", segs=10, r2=0.17)
        beak.cyl(0.36, 0.17, 0.32, "copper", loc=(0, 2.2, 4.68), rot=(-90, 0, 0), segs=12)
        for k, rr in enumerate((0.42, 0.62, 0.84)):
            beak.torus(rr, 0.035, STORM if k % 2 == 0 else SPARK, loc=(0, 2.55 + k * 0.38, 4.68), rot=(90, 0, 0), major=16, minor=4)
    else:
        beak.tube([V((0, 1.4, 4.78)), V((0, 1.75, 4.7)), V((0, 1.92, 4.52)), V((0, 1.86, 4.36))],
                  [(0.14, 0.16), (0.1, 0.12), (0.06, 0.07), (0.0, 0.0)], "beak", sides=8)
    # crest: slate plumes with crackling violet tips (the Roc's is a row of copper spines)
    crest = A.segment("ExtraCrest", (0, 0.95, 5.05), head)  # Cloth spring
    for k in range(5 if herald else 4):
        b = V((0, 0.95 - k * 0.12, 5.05 - k * 0.05))
        t = b + V((0, -0.55 - k * 0.15, 0.55 + (0.35 if herald else 0) - k * 0.05))
        if roc:
            body_c = "copper" if k % 2 == 0 else "copper_dark"
            crest.spike(b, t + V((0, -0.2, 0.2)), 0.1, body_c, segs=5)
        else:
            crest.spike(b, t, 0.08, "slate_dark", segs=5)
            crest.spike(t - (t - b) * 0.3, t + (t - b) * 0.25, 0.04, STORM, segs=4)
    # wings: inner (Arm) with coverts, outer (Forearm) with copper-tipped primaries
    span = 1.05 if roc else (0.8 if herald else 1.0)
    for s, side in ((-1, "L"), (1, "R")):
        sh = V((s * 0.7, 0.1, 3.65))
        wr = V((s * (0.7 + 1.5 * span), 0.0, 3.75))
        tipp = V((s * (0.7 + 2.8 * span), -0.15, 3.65))
        arm = A.segment(f"Arm{side}", sh, body)
        fore = A.segment(f"Forearm{side}", wr, arm)
        arm.tube([sh, sh.lerp(wr, 0.5) + V((0, 0.05, 0.1)), wr], [0.24, 0.2, 0.15], "slate_dark", sides=7)
        for k in range(4):
            t = (k + 0.5) / 4
            feather(arm, sh.lerp(wr, t) + V((0, 0.05, 0.02)), (0.9 + t * 0.5) * span, 0.42 * span, "slate" if k % 2 else "slate_light",
                    yaw=s * 6, droop=8)
        fore.tube([wr, tipp], [0.14, 0.08], "slate_dark", sides=6)
        for k in range(5):
            t = (k + 0.3) / 5
            feather(fore, wr.lerp(tipp, t), (1.35 + t * 0.6) * span, 0.36 * span, "slate_dark" if k % 2 else "slate",
                    yaw=s * (8 + t * 30), droop=6, tip="copper")
        if roc:
            # lightning running along the trailing edge of both wing halves
            lightning(arm, sh + V((0, -1.1 * span, -0.05)), wr + V((0, -1.4 * span, -0.05)), 4, 0.15, 0.05, SPARK, seed=3 + (s > 0))
            lightning(fore, wr + V((0, -1.5 * span, -0.05)), tipp + V((s * 0.6, -1.6 * span, -0.15)), 5, 0.18, 0.05, STORM, seed=7 + (s > 0))
    # legs: feathered thighs, scaled shins bending back, three forward talons and a hind one
    for s, side in ((-1, "L"), (1, "R")):
        leg = A.segment(f"Leg{side}", (s * 0.45, 0, 2.6), body)
        knee = A.segment(f"Knee{side}", (s * 0.5, 0.2, 1.7), leg)
        leg.tube([V((s * 0.45, 0, 2.75)), V((s * 0.5, 0.15, 2.1)), V((s * 0.5, 0.2, 1.7))], [0.36, 0.3, 0.18], "slate", sides=8)
        knee.tube([V((s * 0.5, 0.2, 1.7)), V((s * 0.5, -0.15, 0.85)), V((s * 0.5, 0.1, 0.18))], [0.11, 0.09, 0.09], "beak", sides=6)
        if roc:
            for z in (1.2, 0.6):
                knee.torus(0.13, 0.035, "copper", loc=(s * 0.5, 0.0 if z > 1 else -0.05, z), major=10, minor=4)
        foot = V((s * 0.5, 0.12, 0.12))
        for a in (-28, 0, 28):
            d = V((math.sin(math.radians(a)) * s, math.cos(math.radians(a)), 0))
            knee.tube([foot, foot + d * 0.45 + V((0, 0, -0.04)), foot + d * 0.62 + V((0, 0, -0.1))], [0.07, 0.05, 0.0], "talon", sides=5)
        knee.tube([foot, foot + V((0, -0.35, -0.04)), foot + V((0, -0.48, -0.1))], [0.06, 0.04, 0.0], "talon", sides=5)
    return body, head


def storm_talon():
    A = M.MobAsset("mob_storm_talon", "AVIAN", ATLAS, "REGULAR")
    raptor(A)
    return A


def squall_herald():
    A = M.MobAsset("mob_squall_herald", "AVIAN", ATLAS, "SUPPORT")
    raptor(A, herald=True)
    return scaled(A, 0.9)


def storm_roc():
    A = M.MobAsset("boss_storm_roc", "GIANT_AVIAN", ATLAS, "BOSS")
    body, head = raptor(A, roc=True)
    # copper totem bands on the breast and a storm glyph on the back
    for k in range(3):
        body.torus(0.55 - k * 0.06, 0.04, "copper", mat=K.M((0, 0.45 + k * 0.02, 3.5 - k * 0.3), (75, 0, 0)) @ K.M(scale=(1.1, 0.7, 1)), major=14, minor=4)
    lightning(body, (0, -0.35, 4.05), (0, -1.0, 3.75), 4, 0.12, 0.05, STORM, seed=11)
    return scaled(A, 2.6)


# ============================================================================ Crag Channeler (Regular, CASTER_BIPED)
def crag_channeler():
    A = M.MobAsset("mob_crag_channeler", "CASTER_BIPED", ATLAS, "REGULAR")
    body = A.segment("Body", (0, 0, 2.6))
    head = A.segment("Head", (0, 0.05, 4.35), body)
    # hide tunic under a rune cloak whose glyphs glow, a copper torc, a belt of charms
    body.tube([V((0, 0, 1.2)), V((0, 0, 2.2)), V((0, 0.03, 3.3)), V((0, 0, 4.3))], [(0.7, 0.55), (0.62, 0.5), (0.6, 0.46), (0.46, 0.38)], "hide", sides=10)
    body.tube([V((0, -0.05, 4.3)), V((0, -0.12, 2.6)), V((0, -0.16, 0.4))], [(0.62, 0.5), (0.85, 0.55), (1.0, 0.6)], "cloth", sides=10)
    for k in range(3):
        z = 3.5 - k * 1.0
        lightning(body, (-0.25, -0.73 - k * 0.04, z + 0.25), (0.25, -0.73 - k * 0.04, z - 0.25), 3, 0.06, 0.035, STORM, seed=k)
    body.torus(0.5, 0.07, "copper", mat=K.M((0, 0.02, 4.25)) @ K.M(scale=(1, 0.85, 1)), major=14, minor=4)
    body.torus(0.66, 0.07, "leather", mat=K.M((0, 0, 2.3)) @ K.M(scale=(1, 0.8, 1)), major=14, minor=4)
    for k, x in enumerate((-0.35, -0.1, 0.2, 0.42)):
        body.box((0.1, 0.06, 0.22), "copper_dark" if k % 2 else "stone", loc=(x, 0.52, 2.1))
    body.tube([V((0, 0, 1.2)), V((0, 0.02, 0.5))], [(0.72, 0.56), (0.78, 0.6)], "hide", sides=10)
    # head: a weathered face with violet eyes, curling ram-like horns, a feathered braid
    head.sphere(0.4, "skin", loc=(0, 0.1, 4.75), segs=10, rings=7)
    for s in (1, -1):
        head.box((0.12, 0.05, 0.05), STORM, loc=(s * 0.14, 0.47, 4.8))
        horn = [V((s * 0.3, 0.0, 5.05)), V((s * 0.65, -0.15, 5.35)), V((s * 0.85, 0.05, 5.15)), V((s * 0.8, 0.3, 4.9))]
        head.tube(horn, [0.13, 0.11, 0.08, 0.03], "horn", sides=6)
    head.box((0.5, 0.42, 0.1), "slate_dark", loc=(0, 0.15, 5.12), bevel=0.04)
    head.tube([V((0, -0.3, 4.9)), V((0, -0.45, 4.4)), V((0, -0.45, 3.9))], [0.08, 0.07, 0.05], "cloth_dark", sides=5)
    feather(head, (0, -0.45, 3.95), 0.6, 0.18, "slate_light", droop=75)
    # arms; the right hand holds a copper lightning-rod staff with a coil and a crackling tip
    for s, side in ((-1, "L"), (1, "R")):
        arm = A.segment(f"Arm{side}", (s * 0.55, 0, 4.05), body)
        fore = A.segment(f"Forearm{side}", (s * 0.78, 0.15, 3.35), arm)
        arm.tube([V((s * 0.5, 0, 4.1)), V((s * 0.72, 0.1, 3.6)), V((s * 0.78, 0.15, 3.35))], [0.17, 0.18, 0.18], "cloth", sides=8)
        fore.tube([V((s * 0.78, 0.15, 3.35)), V((s * 0.82, 0.35, 2.85))], [0.16, 0.14], "skin", sides=8)
        fore.torus(0.16, 0.04, "copper", loc=(s * 0.8, 0.25, 3.1), major=10, minor=4)
        fore.sphere(0.12, "skin", loc=(s * 0.82, 0.4, 2.75), segs=8, rings=5)
        if s == 1:
            fore.rod((0.82, 0.42, 0.6), (0.82, 0.42, 5.2), 0.06, "copper_dark", segs=6)
            for k in range(6):
                fore.torus(0.11, 0.025, "copper", loc=(0.82, 0.42, 4.3 + k * 0.13), major=8, minor=3)
            fore.spike((0.82, 0.42, 5.2), (0.82, 0.42, 5.9), 0.07, "copper", segs=6)
            lightning(fore, (0.82, 0.42, 5.75), (1.05, 0.5, 6.3), 3, 0.08, 0.03, SPARK, seed=5)
            lightning(fore, (0.82, 0.42, 5.75), (0.55, 0.3, 6.2), 3, 0.08, 0.03, STORM, seed=6)
            fore.sphere(0.1, SPARK, loc=(0.82, 0.42, 5.8), segs=6, rings=4)
    for s, side in ((-1, "L"), (1, "R")):
        leg = A.segment(f"Leg{side}", (s * 0.28, 0, 2.3), body)
        knee = A.segment(f"Knee{side}", (s * 0.3, 0.05, 1.2), leg)
        leg.tube([V((s * 0.28, 0, 2.35)), V((s * 0.3, 0.05, 1.2))], [0.18, 0.15], "hide", sides=7)
        knee.tube([V((s * 0.3, 0.05, 1.2)), V((s * 0.32, 0.1, 0.25))], [0.15, 0.13], "wool_dark", sides=7)
        knee.box((0.34, 0.56, 0.18), "leather", loc=(s * 0.32, 0.25, 0.09), bevel=0.05)
    return A


# ============================================================================ Thunder Ram Elite / Alpha (QUADRUPED)
def thunder_ram(alpha=False):
    A = M.MobAsset("alpha_thunder_ram" if alpha else "elite_thunder_ram", "QUADRUPED", ATLAS_ALPHA if alpha else ATLAS, "ALPHA" if alpha else "ELITE")
    body = A.segment("Body", (0, 0, 2.6))
    head = A.segment("Head", (0, 2.1, 3.0), body)
    rnd = random.Random(31)
    # a barrel of shaggy wool in clumps over a hide belly
    body.sphere(1.0, "wool_dark", loc=(0, 0.1, 2.75), scale=(1.05, 1.9, 0.95), segs=14, rings=8)
    for k in range(16):
        a = rnd.uniform(0, 2 * math.pi)
        y = rnd.uniform(-1.5, 1.6)
        c = V((math.cos(a) * 0.85, y, 2.85 + abs(math.sin(a)) * 0.75))
        if c.z < 2.5 or (alpha and abs(y + 0.1) < 0.95 and c.z > 3.0):  # keep the saddle's footprint clear
            continue
        body.ico(rnd.uniform(0.38, 0.55), "wool" if k % 3 else "wool_dark", loc=c, subdiv=1, jitter=0.08, seed=k)
    tail = A.segment("ExtraTail1", (0, -1.8, 3.0), body)  # a short flick (keyed later)
    tail.tube([V((0, -1.8, 3.0)), V((0, -2.15, 2.8))], [0.25, 0.12], "wool", sides=6)
    # head: a long hide face with violet eyes; spiral copper-banded horns that arc lightning between their tips
    head.sphere(0.55, "hide", loc=(0, 2.4, 3.15), scale=(0.85, 1.0, 0.9), segs=12, rings=7)
    head.tube([V((0, 2.65, 3.1)), V((0, 3.05, 2.85)), V((0, 3.3, 2.6))], [(0.36, 0.34), (0.3, 0.3), (0.22, 0.22)], "hide", sides=8)
    head.sphere(0.12, "black", loc=(0, 3.4, 2.62), segs=6, rings=4)
    head.ico(0.42, "wool", loc=(0, 2.25, 3.62), subdiv=1, jitter=0.07, seed=40)
    tips = []
    for s in (1, -1):
        head.sphere(0.08, STORM, loc=(s * 0.38, 2.75, 3.25), segs=6, rings=4)
        head.spike((s * 0.45, 2.25, 3.2), (s * 0.8, 2.0, 3.0), 0.12, "hide", segs=4)
        c = V((s * 0.62, 2.05, 3.15))
        pts = []
        steps = 12
        for i in range(steps + 1):
            th = math.radians(330 * i / steps)
            r = 0.58 - 0.3 * i / steps
            pts.append(c + V((s * 0.5 * i / steps, -r * math.sin(th), r * math.cos(th))))
        pts[0] = V((s * 0.3, 2.15, 3.55))
        radii = [0.24 - 0.17 * i / steps for i in range(steps + 1)]
        head.tube(pts, radii, "horn", sides=8)
        for i in (3, 6, 9):
            head.torus(radii[i] + 0.02, 0.035, "copper", mat=K.look_matrix(pts[i], pts[i + 1]), major=10, minor=4)
        tip = pts[-1]
        if alpha:
            head.spike(tip - (pts[-2] - tip).normalized() * -0.05, tip + (tip - pts[-2]).normalized() * 0.3, 0.09, "gold", segs=6)
        tips.append(tip)
    lightning(head, tips[0] + V((0, 0.05, 0.05)), tips[1] + V((0, 0.05, 0.05)), 6, 0.18, 0.035, SPARK, seed=9)
    lightning(head, tips[0], tips[1] + V((0, 0, 0.3)), 5, 0.22, 0.03, STORM, seed=10)
    # legs: thick wool upper legs, dark cloven hooves
    for s, side in ((-1, "L"), (1, "R")):
        arm = A.segment(f"Arm{side}", (s * 0.65, 1.3, 2.3), body)
        fore = A.segment(f"Forearm{side}", (s * 0.68, 1.35, 1.1), arm)
        arm.tube([V((s * 0.65, 1.3, 2.4)), V((s * 0.68, 1.35, 1.1))], [0.42, 0.25], "wool_dark", sides=8)
        fore.tube([V((s * 0.68, 1.35, 1.1)), V((s * 0.68, 1.4, 0.25))], [0.2, 0.17], "hide", sides=7)
        leg = A.segment(f"Leg{side}", (s * 0.65, -1.3, 2.3), body)
        knee = A.segment(f"Knee{side}", (s * 0.68, -1.55, 1.15), leg)
        leg.tube([V((s * 0.65, -1.2, 2.45)), V((s * 0.7, -1.4, 1.7)), V((s * 0.68, -1.55, 1.15))], [0.48, 0.38, 0.22], "wool_dark", sides=8)
        knee.tube([V((s * 0.68, -1.55, 1.15)), V((s * 0.68, -1.4, 0.25))], [0.2, 0.17], "hide", sides=7)
        for seg, y in ((fore, 1.45), (knee, -1.35)):
            for dx in (-0.09, 0.09):
                seg.box((0.16, 0.36, 0.26), "hoof", loc=(s * 0.68 + dx, y, 0.13), bevel=0.04)
    if alpha:
        saddle = A.segment("Trophy_StormSaddle", (0, -0.1, 3.75), body)
        saddle.box((1.9, 1.5, 0.12), "cloth", loc=(0, -0.1, 3.72), rot=(0, 0, 0), bevel=0.04)
        for s in (1, -1):
            saddle.box((0.12, 1.5, 0.9), "cloth", loc=(s * 0.98, -0.1, 3.3), bevel=0.03)
            saddle.box((0.14, 1.56, 0.1), "gold", loc=(s * 1.0, -0.1, 2.85))
            lightning(saddle, (s * 1.06, -0.55, 3.6), (s * 1.06, 0.35, 3.0), 3, 0.08, 0.04, STORM, seed=20 + (s > 0))
        saddle.box((1.96, 0.1, 0.1), "gold", loc=(0, 0.66, 3.8))
        saddle.box((1.96, 0.1, 0.1), "gold", loc=(0, -0.86, 3.8))
        saddle.cyl(0.25, 0.25, 0.08, "gold", loc=(0, -0.1, 3.82), segs=8)
        saddle.cyl(0.13, 0.13, 0.1, SPARK, loc=(0, -0.1, 3.84), segs=8)
    return scaled(A, 1.25)


BUILDERS = {
    "mob_storm_talon": storm_talon,
    "mob_crag_channeler": crag_channeler,
    "mob_squall_herald": squall_herald,
    "elite_thunder_ram": lambda: thunder_ram(False),
    "alpha_thunder_ram": lambda: thunder_ram(True),
    "boss_storm_roc": storm_roc,
}
