"""
Biome 4: Frozen Citadel (floors 16-20). docs/tower-mob-remodel-plan.md §5.4.
Frost-locked fortress. Motif: hexagonal ice and blue steel with silver filigree. Glow: pale ice-blue.

Blender coordinates: 1 unit = 1 stud, Z up, ground z = 0, enemies face +Y, their right hand is +X.
Joint names and parents follow TowerEnemyClips (mob_kit.BIPED; the quadruped's front legs are Arm/Forearm,
its hind legs Leg/Knee). The Glacier Knight and the Frostbound King are authored on a 6.6-stud biped frame
and scaled up with scaled() before building.
"""
import math, random
from mathutils import Vector
import raid_kit as K
import mob_kit as M

V = Vector
K.GLOW["frost"] = (168, 226, 255)
K.GLOW["rime"] = (226, 246, 255)
FROST = "glow:frost"
RIME = "glow:rime"

ATLAS = M.Atlas("frozen_citadel", {
    "ice": (184, 226, 242), "ice_deep": (104, 166, 210), "ice_dark": (60, 106, 152),
    "steel": (92, 120, 160), "steel_dark": (50, 66, 98), "steel_light": (150, 176, 208),
    "silver": (210, 218, 230), "silver_dark": (136, 146, 166),
    "fur": (228, 230, 234), "fur_dark": (156, 160, 172), "fur_grey": (112, 120, 134),
    "robe": (222, 228, 238), "robe_dark": (126, 146, 182), "robe_blue": (54, 82, 142),
    "royal": (70, 48, 128), "royal_dark": (42, 28, 84), "ermine": (246, 246, 248),
    "leather": (72, 60, 56), "black": (20, 22, 28), "skin": (196, 210, 226), "gold": (226, 188, 94), "gold_dark": (152, 118, 56),
})
# the Alpha's filigree is gilded: every silver trim reads as gold
ATLAS_ALPHA = M.Atlas("frozen_citadel_alpha", dict(ATLAS.colours, **{
    "silver": (236, 198, 104), "silver_dark": (172, 130, 60), "steel_dark": (40, 52, 84),
}))


def scaled(A, s):
    """Scale an authored asset about the ground origin (UVs were set at paint time and do not change)."""
    for seg in A.segments:
        for v in seg.bm.verts:
            v.co *= s
        seg.pivot = V(seg.pivot) * s
    return A


def hex_plate(seg, centre, radius, colour, depth=0.08, rot=(90, 0, 0)):
    """A flat hexagonal plate (an ice tile), facing +Y by default."""
    seg.cyl(radius, radius, depth, colour, loc=centre, rot=rot, segs=6)


def snowflake(seg, c, r, colour, plane="XZ", thick=0.04):
    """Six-armed snowflake with a pair of branchlets on each arm, in the XZ plane (facing +Y)."""
    c = V(c)
    for k in range(6):
        a = math.pi / 2 + k * math.pi / 3
        d = V((math.cos(a), 0, math.sin(a)))
        seg.rod(c, c + d * r, thick, colour, segs=4)
        for sgn in (1, -1):
            b = c + d * r * 0.6
            a2 = a + sgn * math.radians(50)
            seg.rod(b, b + V((math.cos(a2), 0, math.sin(a2))) * r * 0.32, thick * 0.8, colour, segs=4)


# ============================================================================ Frost Hound (Regular, QUADRUPED)
def frost_hound():
    A = M.MobAsset("mob_frost_hound", "QUADRUPED", ATLAS, "REGULAR")
    body = A.segment("Body", (0, 0, 2.2))
    head = A.segment("Head", (0, 1.9, 2.9), body)
    # lean torso: a deep chest, tucked waist, pale chest ruff and a silver harness band
    body.sphere(1.0, "fur_grey", loc=(0, 1.0, 2.45), scale=(0.78, 0.95, 0.85), segs=12, rings=8)
    body.sphere(1.0, "fur_grey", loc=(0, -0.75, 2.4), scale=(0.6, 1.25, 0.6), segs=12, rings=8)
    body.sphere(1.0, "fur", loc=(0, 1.4, 2.1), scale=(0.55, 0.55, 0.6), segs=10, rings=6)
    body.torus(0.82, 0.07, "silver", mat=K.M((0, 0.45, 2.45), (90, 0, 0)) @ K.M(scale=(0.92, 1.0, 1)), major=16, minor=4)
    # crystalline icicle mane down the neck and spine, swept back
    for k in range(9):
        t = k / 8
        base = V((0, 1.75 - t * 2.4, 3.2 - t * 0.35 - (0.25 if k == 0 else 0)))
        length = 0.95 - t * 0.5
        body.crystal(base, base + V((0, -0.55 * length, length)), 0.15 - t * 0.05, "ice" if k % 3 else "ice_deep", sides=6)
    for s in (1, -1):
        for k in range(3):
            base = V((s * 0.38, 1.65 - k * 0.35, 2.95 - k * 0.05))
            body.crystal(base, base + V((s * 0.45, -0.45, 0.45)), 0.1, "ice", sides=5)
    # tail ending in an ice shard
    body.tube([V((0, -1.9, 2.55)), V((0, -2.6, 2.75)), V((0, -3.2, 2.6)), V((0, -3.55, 2.25))], [0.22, 0.2, 0.15, 0.1], "fur_grey", sides=7)
    body.crystal((0, -3.5, 2.3), (0, -4.1, 1.85), 0.13, "ice", sides=6)
    # head: a narrow skull, long snout with frosted breath vents, a silver brow plate, ice teeth
    head.sphere(0.5, "fur_grey", loc=(0, 2.25, 3.15), scale=(0.95, 1.1, 0.85), segs=12, rings=7)
    head.tube([V((0, 2.55, 3.05)), V((0, 3.0, 2.95)), V((0, 3.38, 2.85))], [(0.3, 0.25), (0.23, 0.19), (0.15, 0.13)], "fur_grey", sides=8)
    head.sphere(0.09, "black", loc=(0, 3.45, 2.9), segs=6, rings=4)
    head.tube([V((0, 2.5, 2.75)), V((0, 3.0, 2.68)), V((0, 3.28, 2.66))], [0.19, 0.13, 0.07], "fur_dark", sides=6)
    head.box((0.5, 0.36, 0.08), "silver", loc=(0, 2.45, 3.55), rot=(-15, 0, 0), bevel=0.03)
    head.crystal((0, 2.3, 3.55), (0, 1.95, 4.1), 0.1, "ice", sides=5)
    for s in (1, -1):
        head.spike((s * 0.28, 2.1, 3.45), (s * 0.4, 1.9, 4.05), 0.15, "fur_grey", segs=4)
        head.sphere(0.07, FROST, loc=(s * 0.25, 2.62, 3.25), segs=6, rings=4)
        head.box((0.04, 0.38, 0.06), FROST, loc=(s * 0.23, 3.0, 2.92))
        head.spike((s * 0.12, 3.2, 2.82), (s * 0.12, 3.22, 2.62), 0.04, "ice", segs=4)
    # front legs (Arm/Forearm) and hind legs (Leg/Knee) on silver-shod paws with ice claws
    for s, side in ((-1, "L"), (1, "R")):
        arm = A.segment(f"Arm{side}", (s * 0.5, 1.3, 2.3), body)
        fore = A.segment(f"Forearm{side}", (s * 0.55, 1.15, 1.15), arm)
        arm.tube([V((s * 0.5, 1.3, 2.5)), V((s * 0.56, 1.25, 1.8)), V((s * 0.55, 1.15, 1.15))], [0.3, 0.22, 0.16], "fur_grey", sides=7)
        fore.tube([V((s * 0.55, 1.15, 1.15)), V((s * 0.55, 1.3, 0.55)), V((s * 0.55, 1.4, 0.2))], [0.15, 0.12, 0.12], "fur_dark", sides=7)
        leg = A.segment(f"Leg{side}", (s * 0.5, -1.3, 2.3), body)
        knee = A.segment(f"Knee{side}", (s * 0.55, -1.75, 1.2), leg)
        leg.tube([V((s * 0.5, -1.2, 2.45)), V((s * 0.58, -1.45, 1.8)), V((s * 0.55, -1.75, 1.2))], [0.38, 0.3, 0.15], "fur_grey", sides=7)
        knee.tube([V((s * 0.55, -1.75, 1.2)), V((s * 0.55, -1.55, 0.55)), V((s * 0.55, -1.45, 0.2))], [0.14, 0.12, 0.12], "fur_dark", sides=7)
        for seg, y in ((fore, 1.52), (knee, -1.33)):
            seg.box((0.32, 0.46, 0.18), "silver", loc=(s * 0.55, y, 0.09), bevel=0.05)
            for c in (-0.1, 0.1):
                seg.spike((s * 0.55 + c, y + 0.2, 0.08), (s * 0.55 + c, y + 0.4, 0.02), 0.04, "ice", segs=4)
    return A


# ============================================================================ Rime Sentry (Regular, WEAPON_BIPED)
def rime_sentry():
    A = M.MobAsset("mob_rime_sentry", "WEAPON_BIPED", ATLAS, "REGULAR")
    body = A.segment("Body", (0, 0, 3.15))
    head = A.segment("Head", (0, 0.05, 5.35), body)
    # blue-steel cuirass with a silver ridge and a hex ice gem, a leather belt, steel tassets, a fur mantle and cape
    body.tube([V((0, 0, 3.0)), V((0, 0.05, 4.0)), V((0, 0.05, 4.9)), V((0, 0, 5.35))], [(0.8, 0.55), (0.88, 0.6), (0.98, 0.62), (0.58, 0.45)], "steel", sides=10)
    body.box((0.1, 0.1, 1.35), "silver", loc=(0, 0.64, 4.25))
    hex_plate(body, (0, 0.66, 4.6), 0.2, "ice", depth=0.1)
    hex_plate(body, (0, 0.7, 4.6), 0.1, FROST, depth=0.06)
    body.torus(0.82, 0.1, "leather", mat=K.M((0, 0, 3.3)) @ K.M(scale=(1, 0.7, 1)), major=16, minor=5)
    body.box((0.3, 0.12, 0.28), "silver", loc=(0, 0.6, 3.3))
    for x in (-0.42, 0.42):
        body.prism([(-0.3, 0), (0.3, 0), (0.26, -0.8), (-0.26, -0.8)], 0.08, "steel_dark", loc=(x, 0.55, 3.2), rot=(-8, 0, 0))
    body.torus(0.74, 0.26, "fur", mat=K.M((0, -0.04, 5.15)) @ K.M(scale=(1.08, 0.82, 1)), major=16, minor=6)
    body.prism([(-0.7, 0), (0.7, 0), (0.82, -2.4), (-0.82, -2.4)], 0.08, "robe_blue", loc=(0, -0.62, 5.05), rot=(6, 0, 0))
    body.prism([(-0.82, -2.25), (0.82, -2.25), (0.84, -2.45), (-0.84, -2.45)], 0.1, "fur", loc=(0, -0.64, 5.05), rot=(6, 0, 0))
    # head: a rounded helm with a nasal guard, frost eye slits, a silver rim and an ice crest
    head.sphere(0.5, "steel", loc=(0, 0.05, 5.85), scale=(1.0, 1.05, 1.1), segs=12, rings=8)
    head.box((0.62, 0.12, 0.22), "black", loc=(0, 0.5, 5.8))
    head.box((0.09, 0.14, 0.5), "silver", loc=(0, 0.57, 5.78))
    for s in (1, -1):
        head.box((0.15, 0.05, 0.05), FROST, loc=(s * 0.17, 0.57, 5.84))
        head.prism([(-0.14, 0), (0.14, 0), (0.1, -0.42), (-0.12, -0.36)], 0.06, "steel_dark", loc=(s * 0.4, 0.3, 5.75), rot=(0, 0, s * 35))
    head.torus(0.5, 0.06, "silver", loc=(0, 0.05, 5.62), major=16, minor=4)
    head.crystal((0, -0.05, 6.25), (0, -0.35, 7.0), 0.13, "ice", sides=6)
    for s in (1, -1):
        head.crystal((s * 0.15, -0.1, 6.2), (s * 0.3, -0.4, 6.7), 0.08, "ice_deep", sides=5)
    # arms with steel pauldrons; a long spear with an ice-crystal head in the right hand, a hex buckler on the left
    for s, side in ((-1, "L"), (1, "R")):
        arm = A.segment(f"Arm{side}", (s * 0.95, 0, 4.95), body)
        fore = A.segment(f"Forearm{side}", (s * 1.1, 0.05, 3.85), arm)
        arm.sphere(0.42, "steel_light", loc=(s * 1.02, 0, 5.05), scale=(1.0, 1.0, 0.75), segs=10, rings=6)
        arm.torus(0.36, 0.05, "silver", loc=(s * 1.02, 0, 4.88), major=12, minor=4)
        arm.tube([V((s * 0.98, 0, 4.9)), V((s * 1.1, 0.05, 3.9))], [0.25, 0.22], "steel_dark", sides=8)
        fore.tube([V((s * 1.1, 0.05, 3.85)), V((s * 1.15, 0.15, 2.95))], [0.24, 0.21], "steel", sides=8)
        fore.sphere(0.19, "silver", loc=(s * 1.15, 0.2, 2.8), segs=8, rings=5)
        if s == 1:
            fore.rod((1.15, 0.22, 0.5), (1.15, 0.22, 6.3), 0.06, "leather", segs=6)
            fore.cyl(0.1, 0.1, 0.22, "silver", loc=(1.15, 0.22, 6.3), segs=6)
            fore.crystal((1.15, 0.22, 6.38), (1.15, 0.22, 7.6), 0.17, "ice", sides=6, shaft=0.35)
            fore.spike((1.15, 0.22, 6.5), (1.15, 0.22, 7.1), 0.07, FROST, segs=5)
            fore.spike((1.15, 0.22, 0.5), (1.15, 0.22, 0.2), 0.07, "silver", segs=5)
        else:
            fore.cyl(0.55, 0.55, 0.1, "steel_light", loc=(-1.32, 0.12, 3.35), rot=(0, 90, 0), segs=6)
            fore.cyl(0.42, 0.42, 0.12, "steel_dark", loc=(-1.34, 0.12, 3.35), rot=(0, 90, 0), segs=6)
            fore.crystal((-1.36, 0.12, 3.35), (-1.6, 0.12, 3.35), 0.14, "ice", sides=6, shaft=0.4)
    # steel greaves over fur-topped boots
    for s, side in ((-1, "L"), (1, "R")):
        leg = A.segment(f"Leg{side}", (s * 0.42, 0, 2.95), body)
        knee = A.segment(f"Knee{side}", (s * 0.46, 0.05, 1.55), leg)
        leg.tube([V((s * 0.42, 0, 3.0)), V((s * 0.47, 0.05, 2.2)), V((s * 0.46, 0.05, 1.6))], [0.34, 0.36, 0.28], "robe_blue", sides=8)
        knee.sphere(0.24, "silver", loc=(s * 0.47, 0.22, 1.55), segs=8, rings=5)
        knee.tube([V((s * 0.46, 0.05, 1.5)), V((s * 0.48, 0.05, 0.8)), V((s * 0.48, 0.05, 0.3))], [0.27, 0.28, 0.22], "steel", sides=8)
        knee.torus(0.3, 0.12, "fur", loc=(s * 0.48, 0.05, 0.75), major=12, minor=5)
        knee.box((0.42, 0.82, 0.26), "steel_dark", loc=(s * 0.48, 0.2, 0.13), bevel=0.08)
    return A


# ============================================================================ Rime Chaplain (Support, CASTER_BIPED)
def rime_chaplain():
    A = M.MobAsset("mob_rime_chaplain", "CASTER_BIPED", ATLAS, "SUPPORT")
    body = A.segment("Body", (0, 0, 2.6))
    head = A.segment("Head", (0, 0.05, 4.35), body)
    # white vestments with a silver hem, a blue stole with silver crosses, and a ring of hex ice shards (its ward)
    body.tube([V((0, 0, 0.2)), V((0, 0, 1.6)), V((0, 0.03, 3.1)), V((0, 0, 4.3))], [(0.95, 0.85), (0.78, 0.68), (0.62, 0.5), (0.48, 0.4)], "robe", sides=12)
    body.tube([V((0, 0, 0.2)), V((0, 0, 0.38))], [(0.97, 0.87), (0.95, 0.85)], "silver", sides=12)
    for x in (-0.22, 0.22):
        m = K.M((x, 0.47, 4.2), (8, 0, 0))
        body.prism([(-0.12, 0), (0.12, 0), (0.14, -3.8), (-0.14, -3.8)], 0.05, "robe_blue", mat=m)
        for dz in (-0.9, -2.6):
            body.box((0.18, 0.06, 0.05), "silver", loc=tuple(m @ V((0, 0.04, dz))), rot=(8, 0, 0))
            body.box((0.05, 0.06, 0.2), "silver", loc=tuple(m @ V((0, 0.04, dz))), rot=(8, 0, 0))
    body.torus(0.55, 0.14, "robe_dark", mat=K.M((0, 0, 4.15)) @ K.M(scale=(1, 0.85, 1)), major=14, minor=5)
    for k in range(6):
        a = 2 * math.pi * k / 6 + 0.25
        c = V((math.cos(a) * 1.45, math.sin(a) * 1.45, 3.3 + math.sin(a * 3) * 0.2))
        body.crystal(c - V((0, 0, 0.32)), c + V((0, 0, 0.32)), 0.14, "ice", sides=6, shaft=0.6)
        body.spike(c - V((0, 0, 0.3)), c - V((0, 0, 0.6)), 0.14, "ice", segs=6)
        body.sphere(0.06, FROST, loc=c, segs=6, rings=4)
    # head: a pale face with frost eyes, a long white beard, and a tall mitre with silver crosses
    head.sphere(0.4, "skin", loc=(0, 0.1, 4.72), segs=10, rings=7)
    for s in (1, -1):
        head.box((0.12, 0.05, 0.05), FROST, loc=(s * 0.14, 0.47, 4.8))
    head.tube([V((0, 0.4, 4.62)), V((0, 0.48, 4.38)), V((0, 0.46, 4.08)), V((0, 0.4, 3.85))], [(0.26, 0.1), (0.24, 0.11), (0.14, 0.08), (0.0, 0.0)], "fur", sides=8)
    head.prism([(-0.4, 0), (0.4, 0), (0.33, 0.85), (0, 1.25), (-0.33, 0.85)], 0.6, "robe", loc=(0, 0.05, 4.95))
    head.torus(0.42, 0.06, "silver", mat=K.M((0, 0.05, 5.0)) @ K.M(scale=(1, 0.78, 1)), major=14, minor=4)
    head.box((0.1, 0.64, 0.95), "silver", loc=(0, 0.05, 5.5))
    head.box((0.1, 0.06, 0.6), "silver", loc=(0, 0.36, 5.45))
    head.box((0.36, 0.06, 0.1), "silver", loc=(0, 0.36, 5.55))
    for s in (1, -1):
        head.prism([(-0.06, 0), (0.06, 0), (0.06, -0.9), (-0.06, -0.9)], 0.03, "robe_blue", loc=(s * 0.2, -0.32, 5.0))
    # arms in wide sleeves; a silver crozier in the right hand, the snowflake reliquary over the left
    for s, side in ((-1, "L"), (1, "R")):
        arm = A.segment(f"Arm{side}", (s * 0.55, 0, 4.05), body)
        fore = A.segment(f"Forearm{side}", (s * 0.78, 0.15, 3.35), arm)
        arm.tube([V((s * 0.5, 0, 4.1)), V((s * 0.72, 0.1, 3.6)), V((s * 0.78, 0.15, 3.35))], [0.17, 0.19, 0.21], "robe", sides=8)
        fore.tube([V((s * 0.78, 0.15, 3.35)), V((s * 0.82, 0.35, 2.85))], [0.22, 0.3], "robe_dark", sides=8)
        fore.sphere(0.12, "skin", loc=(s * 0.82, 0.4, 2.75), segs=8, rings=5)
        if s == 1:
            fore.rod((0.82, 0.42, 0.9), (0.82, 0.42, 5.3), 0.05, "silver", segs=6)
            fore.tube([V((0.82, 0.42, 5.3)), V((0.82, 0.5, 5.7)), V((0.82, 0.8, 5.88)), V((0.82, 1.02, 5.7)), V((0.82, 0.98, 5.45))],
                      [0.06, 0.06, 0.055, 0.05, 0.03], "silver", sides=6)
            fore.crystal((0.82, 0.98, 5.42), (0.82, 0.98, 5.05), 0.07, "ice", sides=6)
        else:
            c = V((-0.85, 0.75, 3.35))
            fore.torus(0.5, 0.035, "silver", mat=K.M(c, (90, 0, 0)), major=6, minor=4)
            snowflake(fore, c, 0.45, FROST)
            hex_plate(fore, tuple(c), 0.13, "ice", depth=0.1)
    for s, side in ((-1, "L"), (1, "R")):
        leg = A.segment(f"Leg{side}", (s * 0.25, 0, 2.4), body)
        knee = A.segment(f"Knee{side}", (s * 0.28, 0.05, 1.2), leg)
        leg.tube([V((s * 0.25, 0, 2.45)), V((s * 0.28, 0.05, 1.2))], [0.16, 0.14], "robe_dark", sides=7)
        knee.tube([V((s * 0.28, 0.05, 1.2)), V((s * 0.3, 0.1, 0.25))], [0.14, 0.12], "robe_dark", sides=7)
        knee.box((0.32, 0.55, 0.16), "silver_dark", loc=(s * 0.3, 0.28, 0.08), bevel=0.04)
    return A


# ============================================================================ Glacier Knight Elite / Alpha (ARMORED_BIPED)
def glacier_knight(alpha=False):
    A = M.MobAsset("alpha_glacier_knight" if alpha else "elite_glacier_knight", "ARMORED_BIPED", ATLAS_ALPHA if alpha else ATLAS, "ALPHA" if alpha else "ELITE")
    body = A.segment("Body", (0, 0, 3.15))
    head = A.segment("Head", (0, 0.05, 5.35), body)
    # heavy plate: a broad cuirass with a plackart, silver filigree, a blue tabard and layered faulds
    body.tube([V((0, 0, 3.0)), V((0, 0.05, 3.9)), V((0, 0.06, 4.85)), V((0, 0, 5.4))], [(0.9, 0.62), (0.98, 0.68), (1.1, 0.72), (0.66, 0.5)], "steel", sides=12)
    body.tube([V((0, 0.28, 3.25)), V((0, 0.4, 3.9)), V((0, 0.44, 4.35))], [(0.7, 0.36), (0.78, 0.36), (0.7, 0.32)], "steel_light", sides=10)
    for s in (1, -1):
        body.tube([V((s * 0.15, 0.72, 4.95)), V((s * 0.45, 0.76, 4.6)), V((s * 0.4, 0.8, 4.2)), V((s * 0.6, 0.76, 3.9))], [0.04] * 4, "silver", sides=4)
    hex_plate(body, (0, 0.76, 4.62), 0.22, "ice", depth=0.1)
    hex_plate(body, (0, 0.8, 4.62), 0.12, FROST, depth=0.06)
    body.prism([(-0.42, 0), (0.42, 0), (0.38, -2.1), (0, -2.35), (-0.38, -2.1)], 0.06, "robe_blue", loc=(0, 0.72, 3.25))
    body.box((0.08, 0.07, 1.9), "silver", loc=(0, 0.76, 2.3))
    for k in range(2):
        body.tube([V((0, 0, 3.15 - k * 0.32)), V((0, 0, 2.85 - k * 0.32))], [(0.96 + k * 0.05, 0.68 + k * 0.04), (1.0 + k * 0.05, 0.72 + k * 0.04)], "steel_dark", sides=12)
    body.prism([(-0.75, 0), (0.75, 0), (0.85, -2.6), (-0.85, -2.6)], 0.08, "robe_blue", loc=(0, -0.7, 5.15), rot=(5, 0, 0))
    # head: a great helm with a frost visor, a silver cross band and short ice horns
    head.cyl(0.47, 0.47, 0.75, "steel", loc=(0, 0.05, 5.8), segs=12)
    head.sphere(0.47, "steel", loc=(0, 0.05, 6.15), scale=(1, 1, 0.55), segs=12, rings=6)
    head.box((0.7, 0.1, 0.08), FROST, loc=(0, 0.5, 5.9))
    head.box((0.1, 0.1, 0.75), "silver", loc=(0, 0.52, 5.85))
    head.torus(0.48, 0.05, "silver", loc=(0, 0.05, 5.45), major=16, minor=4)
    for k in range(4):
        head.box((0.08, 0.06, 0.06), "black", loc=(0.2 + k * 0.0, 0.5, 5.65 - k * 0.07))
    for s in (1, -1):
        head.crystal((s * 0.38, 0.0, 6.2), (s * 0.75, -0.15, 6.85), 0.11, "ice", sides=5)
    # arms: layered pauldrons; a tower shield of ice on the left, a broad glacier blade in the right
    for s, side in ((-1, "L"), (1, "R")):
        arm = A.segment(f"Arm{side}", (s * 1.05, 0, 4.95), body)
        fore = A.segment(f"Forearm{side}", (s * 1.2, 0.05, 3.85), arm)
        arm.sphere(0.55, "steel_light", loc=(s * 1.12, 0, 5.1), scale=(1.0, 1.0, 0.72), segs=12, rings=6)
        arm.sphere(0.5, "steel", loc=(s * 1.25, 0, 4.82), scale=(0.9, 0.95, 0.55), segs=12, rings=6)
        arm.torus(0.5, 0.045, "silver", loc=(s * 1.15, 0, 5.08), major=14, minor=4)
        arm.crystal((s * 1.2, -0.1, 5.4), (s * 1.45, -0.3, 5.95), 0.1, "ice", sides=5)
        arm.tube([V((s * 1.08, 0, 4.9)), V((s * 1.2, 0.05, 3.9))], [0.28, 0.25], "steel_dark", sides=8)
        fore.tube([V((s * 1.2, 0.05, 3.85)), V((s * 1.25, 0.15, 2.95))], [0.28, 0.26], "steel", sides=8)
        fore.sphere(0.22, "silver", loc=(s * 1.25, 0.2, 2.8), segs=8, rings=5)
        if s == -1:
            m = K.M((-1.5, 0.55, 3.35), (0, 0, -18))
            fore.prism([(-0.62, 1.15), (0, 1.5), (0.62, 1.15), (0.62, -1.15), (0, -1.6), (-0.62, -1.15)], 0.2, "ice", mat=m)
            fore.prism([(-0.7, 1.25), (0, 1.62), (0.7, 1.25), (0.7, -1.25), (0, -1.74), (-0.7, -1.25)], 0.12, "steel_dark", mat=m @ K.M((0, -0.14, 0)))
            fore.prism([(-0.06, 1.4), (0.06, 1.4), (0.06, -1.5), (-0.06, -1.5)], 0.24, "silver", mat=m)
            fore.cyl(0.3, 0.3, 0.26, "ice_deep", mat=m @ K.M((0, 0.04, 0.05), (90, 0, 0)), segs=6)
            fore.cyl(0.16, 0.16, 0.3, FROST, mat=m @ K.M((0, 0.06, 0.05), (90, 0, 0)), segs=6)
        else:
            hand = V((1.25, 0.3, 2.8))
            fore.rod(hand - V((0, 0, 0.3)), hand + V((0, 0, 0.3)), 0.08, "leather", segs=6)
            fore.sphere(0.12, "ice_deep", loc=hand - V((0, 0, 0.38)), segs=8, rings=5)
            fore.box((0.95, 0.2, 0.16), "silver", loc=hand + V((0, 0, 0.36)), bevel=0.05)
            blade = [(-0.32, 0), (0.32, 0), (0.36, 2.3), (0.12, 2.95), (-0.34, 2.5)]
            fore.prism(blade, 0.14, "ice", loc=hand + V((0, 0, 0.44)))
            fore.prism([(-0.07, 0.1), (0.07, 0.1), (0.07, 2.3), (-0.07, 2.3)], 0.18, "ice_deep", loc=hand + V((0, 0, 0.44)))
            fore.spike(hand + V((0, 0, 1.2)), hand + V((0, 0, 2.6)), 0.05, FROST, segs=4)
    # plate legs and broad sabatons
    for s, side in ((-1, "L"), (1, "R")):
        leg = A.segment(f"Leg{side}", (s * 0.45, 0, 2.95), body)
        knee = A.segment(f"Knee{side}", (s * 0.5, 0.05, 1.55), leg)
        leg.tube([V((s * 0.45, 0, 3.0)), V((s * 0.5, 0.05, 2.2)), V((s * 0.5, 0.05, 1.6))], [0.38, 0.4, 0.3], "steel_dark", sides=8)
        knee.sphere(0.27, "silver", loc=(s * 0.51, 0.25, 1.55), segs=8, rings=5)
        knee.tube([V((s * 0.5, 0.05, 1.5)), V((s * 0.52, 0.05, 0.8)), V((s * 0.52, 0.05, 0.3))], [0.3, 0.32, 0.26], "steel", sides=8)
        knee.box((0.5, 0.95, 0.3), "steel_dark", loc=(s * 0.52, 0.22, 0.15), bevel=0.1)
        knee.box((0.52, 0.12, 0.2), "silver", loc=(s * 0.52, 0.68, 0.2))
    if alpha:
        # trophy: a silver (gilded) crown of icicles riding the great helm, plus extra gold filigree on the cuirass
        crown = A.segment("Trophy_IceCrown", (0, 0.05, 6.35), head)
        crown.torus(0.46, 0.07, "silver", loc=(0, 0.05, 6.32), major=18, minor=4)
        for k in range(9):
            a = 2 * math.pi * k / 9 + math.pi / 2
            b = V((math.cos(a) * 0.46, 0.05 + math.sin(a) * 0.46, 6.35))
            h = 0.85 if k == 0 else (0.55 if k % 2 else 0.4)
            crown.crystal(b, b + V((math.cos(a) * 0.12, math.sin(a) * 0.12, h)), 0.08, "ice", sides=5)
        crown.sphere(0.09, RIME, loc=(0, 0.52, 6.4), segs=8, rings=5)
        for s in (1, -1):
            body.tube([V((s * 0.2, 0.5, 3.4)), V((s * 0.55, 0.62, 3.7)), V((s * 0.75, 0.56, 4.1))], [0.035] * 3, "gold", sides=4)
    return scaled(A, 1.3)


# ============================================================================ Frostbound King (Biome Boss, ROYAL_BIPED)
def frostbound_king():
    A = M.MobAsset("boss_frostbound_king", "ROYAL_BIPED", ATLAS, "BOSS")
    body = A.segment("Body", (0, 0, 3.15))
    head = A.segment("Head", (0, 0.05, 5.35), body)
    rnd = random.Random(20)
    # royal plate under a violet tabard, a snowflake sigil, and a thick ermine mantle with black tails
    body.tube([V((0, 0, 2.95)), V((0, 0.05, 3.9)), V((0, 0.06, 4.85)), V((0, 0, 5.4))], [(0.88, 0.6), (0.95, 0.66), (1.05, 0.68), (0.62, 0.48)], "steel_dark", sides=14)
    body.prism([(-0.5, 0), (0.5, 0), (0.55, -2.55), (0, -2.8), (-0.55, -2.55)], 0.06, "royal", loc=(0, 0.68, 4.75))
    body.prism([(-0.58, 0.05), (0.58, 0.05), (0.63, -2.6), (0, -2.9), (-0.63, -2.6)], 0.04, "silver", loc=(0, 0.66, 4.75))
    snowflake(body, (0, 0.74, 4.05), 0.32, FROST, thick=0.035)
    body.torus(0.86, 0.1, "silver", mat=K.M((0, 0, 3.15)) @ K.M(scale=(1, 0.72, 1)), major=18, minor=5)
    body.torus(0.78, 0.32, "ermine", mat=K.M((0, -0.04, 5.2)) @ K.M(scale=(1.1, 0.85, 1)), major=20, minor=7)
    for k in range(12):
        a = 2 * math.pi * k / 12
        body.spike((math.cos(a) * 0.86 * 1.1, -0.04 + math.sin(a) * 0.86 * 0.85, 5.12), (math.cos(a) * 0.95 * 1.1, -0.04 + math.sin(a) * 0.95 * 0.85, 4.8), 0.05, "black", segs=4)
    # the articulated cloak: five fanned violet panels lined with ermine, frost trailing off the hem
    for k in range(5):
        x = (k - 2) * 0.36
        yaw = (k - 2) * -9
        tilt = 7 + abs(k - 2) * 2
        m = K.M((x, -0.66 - abs(k - 2) * 0.04, 5.1), (tilt, 0, yaw))
        body.prism([(-0.22, 0), (0.22, 0), (0.27, -4.6), (-0.27, -4.6)], 0.07, "royal" if k % 2 == 0 else "royal_dark", mat=m)
        body.prism([(-0.27, -4.45), (0.27, -4.45), (0.28, -4.85), (-0.28, -4.85)], 0.12, "ermine", mat=m)
        for j in range(2):
            tip = m @ V(((j - 0.5) * 0.25, -0.3, -4.85))
            body.spike(m @ V(((j - 0.5) * 0.25, 0, -4.75)), tip + V((rnd.uniform(-0.1, 0.1), -0.55, -0.1)), 0.06, FROST, segs=4)
    # head: a frozen face, an icicle beard, frost eyes and a jagged ice crown on a silver circlet
    head.sphere(0.45, "skin", loc=(0, 0.08, 5.82), scale=(0.95, 1.0, 1.08), segs=12, rings=8)
    for s in (1, -1):
        head.box((0.14, 0.05, 0.05), FROST, loc=(s * 0.16, 0.5, 5.9))
        head.box((0.18, 0.05, 0.05), "ice_dark", loc=(s * 0.16, 0.5, 6.0), rot=(0, s * -12, 0))
    for k in range(7):
        x = (k - 3) * 0.1
        length = 0.75 - abs(k - 3) * 0.13
        head.crystal((x, 0.42 - abs(k - 3) * 0.04, 5.6), (x * 1.2, 0.5, 5.6 - length), 0.07, "ice", sides=5)
    head.torus(0.47, 0.07, "silver", loc=(0, 0.06, 6.18), major=18, minor=5)
    for k in range(11):
        a = 2 * math.pi * k / 11 + math.pi / 2
        b = V((math.cos(a) * 0.47, 0.06 + math.sin(a) * 0.47, 6.2))
        h = 1.15 if k == 0 else rnd.uniform(0.45, 0.8)
        head.crystal(b, b + V((math.cos(a) * 0.22 + rnd.uniform(-0.05, 0.05), math.sin(a) * 0.22, h)), 0.09, "ice" if k % 3 else "ice_deep", sides=5)
    head.cyl(0.08, 0.08, 0.06, FROST, loc=(0, 0.54, 6.25), rot=(90, 0, 0), segs=6)
    # arms: silver-edged pauldrons with ice spikes; a greatsword sheathed in ice, raised in the right hand
    for s, side in ((-1, "L"), (1, "R")):
        arm = A.segment(f"Arm{side}", (s * 1.0, 0, 4.95), body)
        fore = A.segment(f"Forearm{side}", (s * 1.15, 0.05, 3.85), arm)
        arm.sphere(0.5, "steel", loc=(s * 1.08, 0, 5.05), scale=(1.0, 1.0, 0.72), segs=12, rings=7)
        arm.torus(0.46, 0.05, "silver", loc=(s * 1.1, 0, 4.9), major=16, minor=4)
        for j in range(3):
            b = V((s * (1.05 + j * 0.15), -0.15 + j * 0.15, 5.3))
            arm.crystal(b, b + V((s * 0.35, -0.15, 0.55 - j * 0.1)), 0.09, "ice", sides=5)
        arm.tube([V((s * 1.05, 0, 4.9)), V((s * 1.15, 0.05, 3.9))], [0.26, 0.23], "steel_dark", sides=8)
        fore.tube([V((s * 1.15, 0.05, 3.85)), V((s * 1.2, 0.15, 2.95))], [0.26, 0.24], "steel", sides=8)
        fore.torus(0.27, 0.04, "silver", loc=(s * 1.18, 0.1, 3.3), major=12, minor=4)
        fore.sphere(0.21, "silver_dark", loc=(s * 1.2, 0.2, 2.8), segs=8, rings=5)
        if s == 1:
            hand = V((1.2, 0.3, 2.8))
            fore.rod(hand - V((0, 0, 0.4)), hand + V((0, 0, 0.35)), 0.07, "leather", segs=6)
            fore.sphere(0.13, "ice_deep", loc=hand - V((0, 0, 0.46)), segs=8, rings=5)
            fore.box((1.05, 0.2, 0.16), "silver", loc=hand + V((0, 0, 0.42)), bevel=0.05)
            for sg in (1, -1):
                fore.crystal(hand + V((sg * 0.5, 0, 0.42)), hand + V((sg * 0.68, 0, 0.75)), 0.07, "ice", sides=5)
            base = hand + V((0, 0, 0.5))
            fore.prism([(-0.2, 0), (0.2, 0), (0.22, 3.6), (0, 4.1), (-0.22, 3.6)], 0.12, "steel_light", loc=base)
            for j in range(7):  # the ice sheath: hex crystals crusting both edges
                z = 0.3 + j * 0.52
                for sg in (1, -1):
                    c = base + V((sg * 0.2, 0, z))
                    fore.crystal(c - V((sg * 0.05, 0, 0.18)), c + V((sg * (0.2 + 0.06 * (j % 2)), 0, 0.32)), 0.1, "ice" if (j + (sg > 0)) % 2 else "ice_deep", sides=6)
            fore.spike(base + V((0, 0.07, 0.3)), base + V((0, 0.07, 3.7)), 0.05, FROST, segs=4)
        else:
            fore.crystal((-1.22, 0.42, 2.7), (-1.3, 0.55, 2.2), 0.08, "ice", sides=5)
    # plate legs, silver poleyns and sabatons
    for s, side in ((-1, "L"), (1, "R")):
        leg = A.segment(f"Leg{side}", (s * 0.44, 0, 2.95), body)
        knee = A.segment(f"Knee{side}", (s * 0.48, 0.05, 1.55), leg)
        leg.tube([V((s * 0.44, 0, 3.0)), V((s * 0.49, 0.05, 2.2)), V((s * 0.48, 0.05, 1.6))], [0.36, 0.38, 0.29], "steel_dark", sides=8)
        knee.sphere(0.26, "silver", loc=(s * 0.49, 0.24, 1.55), segs=8, rings=5)
        knee.tube([V((s * 0.48, 0.05, 1.5)), V((s * 0.5, 0.05, 0.8)), V((s * 0.5, 0.05, 0.3))], [0.29, 0.31, 0.24], "steel", sides=8)
        knee.box((0.48, 0.92, 0.28), "steel_dark", loc=(s * 0.5, 0.22, 0.14), bevel=0.1)
        knee.box((0.5, 0.1, 0.18), "silver", loc=(s * 0.5, 0.66, 0.2))
    return scaled(A, 2.45)


BUILDERS = {
    "mob_frost_hound": frost_hound,
    "mob_rime_sentry": rime_sentry,
    "mob_rime_chaplain": rime_chaplain,
    "elite_glacier_knight": lambda: glacier_knight(False),
    "alpha_glacier_knight": lambda: glacier_knight(True),
    "boss_frostbound_king": frostbound_king,
}
