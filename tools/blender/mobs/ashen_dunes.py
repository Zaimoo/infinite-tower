"""
Biome 3: Ashen Dunes (floors 11-15). docs/tower-mob-remodel-plan.md §5.3.
Sun-bleached sandstone, glassed sand and ember. Motif: wind-worn banded stone and black volcanic glass.
Glow: ember orange (molten gold on the glass).

Blender coordinates: 1 unit = 1 stud, Z up, ground z = 0, enemies face +Y, their right hand is +X.
Joint names and parents follow TowerEnemyClips (mob_kit.BIPED / mob_kit.CRAWLER).
"""
import math, random
from mathutils import Vector
import raid_kit as K
import mob_kit as M

V = Vector
K.GLOW["ember"] = (255, 140, 52)
K.GLOW["magma"] = (255, 92, 30)
EMBER = "glow:ember"
MAGMA = "glow:magma"
SUNGLOW = "glow:gold"

ATLAS = M.Atlas("ashen_dunes", {
    "sand": (218, 190, 136), "sand_dark": (170, 138, 90), "sandstone": (200, 154, 100), "band": (160, 112, 68), "band_dark": (112, 74, 46),
    "obsidian": (36, 32, 40), "obsidian_mid": (70, 62, 70), "glass_amber": (226, 150, 58), "glass_dark": (150, 86, 34),
    "bronze": (182, 124, 62), "bronze_dark": (116, 76, 38), "bronze_iri": (88, 118, 100), "bronze_teal": (60, 104, 98),
    "cloth": (206, 182, 146), "cloth_dark": (146, 116, 86), "sash": (160, 56, 42), "sash_dark": (102, 34, 30),
    "leather": (100, 68, 44), "steel": (168, 168, 164), "gold": (224, 180, 84), "gold_dark": (154, 112, 50),
    "skin": (124, 86, 62), "bone": (228, 214, 184), "black": (18, 16, 18), "lapis": (54, 80, 150),
})
ATLAS_ALPHA = M.Atlas("ashen_dunes_alpha", dict(ATLAS.colours, **{
    "bronze_dark": (236, 192, 92), "obsidian_mid": (120, 94, 60), "glass_dark": (240, 186, 80), "glass_amber": (252, 206, 104),
}))


def banded_block(seg, size, loc, colours, bands=3, rot=(0, 0, 0), bevel=0.15):
    """A wind-worn sandstone block in horizontal bands of alternating colour, each band slightly inset."""
    w, d, h = size
    for k in range(bands):
        inset = 0.06 * (k % 2)
        z = loc[2] - h / 2 + h * (k + 0.5) / bands
        seg.box((w - inset * 2, d - inset * 2, h / bands + 0.01), colours[k % len(colours)], mat=K.M((loc[0], loc[1], z), rot) if rot != (0, 0, 0) else None,
                loc=(loc[0], loc[1], z), bevel=bevel)


# ============================================================================ Dune Scarab (Regular, INSECT)
def dune_scarab():
    A = M.MobAsset("mob_dune_scarab", "INSECT", ATLAS, "REGULAR")
    body = A.segment("Body", (0, 0, 1.5))
    head = A.segment("Head", (0, 1.55, 1.45), body)
    # iridescent split wing-cases over a bronze body, a pronotum shield, sand streaming off the back
    body.sphere(1.0, "bronze_dark", loc=(0, -0.3, 1.45), scale=(1.25, 1.65, 0.7), segs=14, rings=8)
    for s in (1, -1):  # each wing-case hinges at its front edge (ExtraElytraL/R, keyed later; springs until then)
        case = A.segment("ExtraElytraR" if s == 1 else "ExtraElytraL", (s * 0.4, 0.9, 2.05), body)
        case.sphere(1.0, "bronze_iri", loc=(s * 0.62, -0.45, 1.85), scale=(0.68, 1.55, 0.62), segs=12, rings=8)
    body.box((0.08, 3.0, 0.1), "gold", loc=(0, -0.45, 2.45))
    body.sphere(1.0, "bronze", loc=(0, 0.95, 1.8), scale=(1.05, 0.6, 0.55), segs=12, rings=7)
    body.box((1.6, 0.12, 0.12), "gold_dark", loc=(0, 1.42, 1.95))
    for k, (x, z) in enumerate(((-0.4, 2.0), (0.3, 1.9), (0.0, 1.7))):  # sand trickling off the back
        b = V((x, -1.9, z))
        body.spike(b, b + V((x * 0.3, -0.5, -1.0 - k * 0.2)), 0.18, "sand", segs=5)
    # head with a curved horn and amber eyes
    head.sphere(0.55, "bronze_dark", loc=(0, 1.8, 1.45), scale=(1.1, 0.9, 0.75), segs=12, rings=7)
    head.tube([V((0, 2.1, 1.65)), V((0, 2.5, 2.1)), V((0, 2.55, 2.6)), V((0, 2.3, 2.9))], [0.17, 0.13, 0.08, 0.0], "bronze", sides=6)
    for s in (1, -1):
        head.sphere(0.11, EMBER, loc=(s * 0.35, 2.2, 1.6), segs=6, rings=4)
    for s, side in ((-1, "L"), (1, "R")):
        jaw = A.segment(f"Jaw{side}", (s * 0.3, 2.25, 1.3), head)
        jaw.tube([V((s * 0.3, 2.2, 1.3)), V((s * 0.38, 2.55, 1.25)), V((s * 0.12, 2.75, 1.2))], [0.09, 0.07, 0.0], "bronze_dark", sides=5)
    # six toothed legs
    for s in (-1, 1):
        for i in (1, 2, 3):
            y = (2 - i) * 1.1
            hip = V((s * 0.95, y, 1.3))
            knee = V((s * 1.85, y * 1.1, 1.9))
            foot = V((s * 2.45, y * 1.25, 0.0))
            leg = A.segment(f"Leg{s}_{i}", hip, body)
            shin = A.segment(f"Knee{s}_{i}", knee, leg)
            leg.tube([hip, hip.lerp(knee, 0.5) + V((0, 0, 0.12)), knee], [0.15, 0.13, 0.11], "bronze_dark", sides=6)
            shin.tube([knee, knee.lerp(foot, 0.5) + V((s * 0.12, 0, 0.05)), foot + V((0, 0, 0.05))], [0.1, 0.08, 0.03], "bronze_dark", sides=6)
            mid = knee.lerp(foot, 0.4)
            shin.spike(mid, mid + V((s * 0.05, 0.2, 0.25)), 0.05, "gold_dark", segs=4)
    return A


# ============================================================================ Ash Raider (Regular, WEAPON_BIPED)
def ash_raider():
    A = M.MobAsset("mob_ash_raider", "WEAPON_BIPED", ATLAS, "REGULAR")
    body = A.segment("Body", (0, 0, 3.15))
    head = A.segment("Head", (0, 0.05, 5.35), body)
    # wrapped torso: layered cloth, a crossing red sash, belt and loose cloth tails
    body.tube([V((0, 0, 3.0)), V((0, 0.05, 4.0)), V((0, 0.05, 4.9)), V((0, 0, 5.35))], [(0.82, 0.55), (0.9, 0.6), (1.0, 0.62), (0.6, 0.45)], "cloth", sides=10)
    body.tube([V((-0.85, 0.58, 4.95)), V((0, 0.66, 4.2)), V((0.85, 0.6, 3.45))], [0.1, 0.1, 0.1], "sash", sides=5)
    body.tube([V((-0.85, -0.58, 4.95)), V((0, -0.66, 4.2)), V((0.85, -0.6, 3.45))], [0.1, 0.1, 0.1], "sash", sides=5)
    body.torus(0.82, 0.1, "leather", mat=K.M((0, 0, 3.3)) @ K.M(scale=(1, 0.7, 1)), major=16, minor=5)
    body.box((0.32, 0.12, 0.3), "gold", loc=(0, 0.6, 3.3))
    for k, x in enumerate((-0.35, 0.3)):
        body.prism([(-0.22, 0), (0.22, 0), (0.12, -1.3), (-0.18, -1.15)], 0.06, "sash_dark" if k else "sash", loc=(x, 0.6, 3.2))
    body.prism([(-0.5, 0), (0.5, 0), (0.3, -1.4), (-0.35, -1.2)], 0.06, "cloth_dark", loc=(0, -0.55, 3.2))
    # head: wrapped hood, a bronze half-mask with ember eye slits, a headwrap tail streaming back
    head.sphere(0.55, "cloth", loc=(0, 0.05, 5.85), scale=(1.0, 1.05, 1.1), segs=12, rings=8)
    head.box((0.82, 0.25, 0.42), "bronze", loc=(0, 0.52, 5.7), bevel=0.08)
    for s in (1, -1):
        head.box((0.22, 0.06, 0.07), EMBER, loc=(s * 0.18, 0.66, 5.78))
    head.torus(0.5, 0.1, "sash", loc=(0, 0.05, 6.1), rot=(8, 0, 0), major=14, minor=5)
    wrap = A.segment("ExtraWrapTail", (0.1, -0.45, 6.05), head)  # streams behind (Cloth spring)
    wrap.tube([V((0.1, -0.45, 6.05)), V((0.25, -0.9, 5.7)), V((0.2, -1.3, 5.2)), V((0.35, -1.6, 4.9))], [(0.18, 0.05)] * 3 + [(0.12, 0.04)], "sash", rect=True, up=(0, 0, 1))
    # wrapped arms; a curved khopesh in the right hand, a bronze bracer on the left
    for s, side in ((-1, "L"), (1, "R")):
        arm = A.segment(f"Arm{side}", (s * 0.95, 0, 4.95), body)
        fore = A.segment(f"Forearm{side}", (s * 1.1, 0.05, 3.85), arm)
        arm.sphere(0.36, "cloth_dark", loc=(s * 0.98, 0, 5.0), segs=10, rings=6)
        arm.tube([V((s * 0.98, 0, 4.9)), V((s * 1.1, 0.05, 3.9))], [0.26, 0.22], "cloth", sides=8)
        fore.tube([V((s * 1.1, 0.05, 3.85)), V((s * 1.15, 0.15, 2.95))], [0.22, 0.2], "cloth_dark", sides=8)
        fore.sphere(0.18, "skin", loc=(s * 1.15, 0.2, 2.8), segs=8, rings=5)
        if s == 1:
            hilt = V((1.15, 0.22, 2.8))
            fore.rod(hilt + V((0, 0, 0.25)), hilt - V((0, 0, 0.25)), 0.07, "leather", segs=6)
            fore.box((0.12, 0.42, 0.1), "gold", loc=hilt - V((0, 0, 0.28)))
            blade = [(0.05, 0), (0.16, 0.4), (0.18, 0.95), (0.05, 1.4), (-0.25, 1.85), (-0.62, 2.0), (-0.75, 1.85), (-0.45, 1.65), (-0.2, 1.35), (-0.12, 0.9), (-0.06, 0.4)]
            # blade hangs from the hilt, curving forward: profile (x = forward, z = down)
            from mathutils import Matrix
            m = Matrix(((0, 1, 0, 1.15), (-1, 0, 0, 0.22), (0, 0, -1, 2.5), (0, 0, 0, 1)))  # local X -> -Y (hook ahead), Y -> +X, Z -> down
            fore.prism(blade, 0.08, "steel", mat=m)
            fore.prism([(x * 0.6 - 0.02, z * 0.55 + 0.75) for x, z in blade[3:9]], 0.1, "gold_dark", mat=m)
        else:
            fore.cyl(0.25, 0.25, 0.5, "bronze", loc=(-1.12, 0.1, 3.3), segs=10)
    # baggy trousers and wrapped boots
    for s, side in ((-1, "L"), (1, "R")):
        leg = A.segment(f"Leg{side}", (s * 0.42, 0, 2.95), body)
        knee = A.segment(f"Knee{side}", (s * 0.46, 0.05, 1.55), leg)
        leg.tube([V((s * 0.42, 0, 3.0)), V((s * 0.48, 0.05, 2.2)), V((s * 0.46, 0.05, 1.6))], [0.36, 0.4, 0.3], "cloth_dark", sides=8)
        knee.tube([V((s * 0.46, 0.05, 1.55)), V((s * 0.48, 0.05, 0.8)), V((s * 0.48, 0.05, 0.25))], [0.3, 0.32, 0.22], "cloth_dark", sides=8)
        knee.tube([V((s * 0.48, 0.05, 0.85)), V((s * 0.48, 0.05, 0.3))], [0.25, 0.25], "leather", sides=8)
        knee.box((0.4, 0.8, 0.26), "leather", loc=(s * 0.48, 0.2, 0.13), bevel=0.08)
    return A


# ============================================================================ Ember Oracle (Support, CASTER_BIPED)
def ember_oracle():
    A = M.MobAsset("mob_ember_oracle", "CASTER_BIPED", ATLAS, "SUPPORT")
    body = A.segment("Body", (0, 0, 2.6))
    head = A.segment("Head", (0, 0.05, 4.35), body)
    rnd = random.Random(3)
    # long two-tone robe with a gold-trimmed hem, and a ring of floating glass shards (its ward)
    body.tube([V((0, 0, 0.2)), V((0, 0, 1.6)), V((0, 0.03, 3.1)), V((0, 0, 4.3))], [(0.95, 0.85), (0.78, 0.68), (0.62, 0.5), (0.48, 0.4)], "cloth", sides=12)
    body.tube([V((0, 0, 0.2)), V((0, 0, 0.38))], [(0.97, 0.87), (0.95, 0.85)], "gold", sides=12)
    body.prism([(-0.35, 0), (0.35, 0), (0.28, -2.3), (-0.28, -2.3)], 0.05, "sash", loc=(0, 0.56, 3.9))
    body.torus(0.62, 0.07, "gold_dark", mat=K.M((0, 0.02, 3.1)) @ K.M(scale=(1, 0.82, 1)), major=16, minor=4)
    ring = A.segment("ExtraRing", (0, 0, 3.35), body)  # the floating ward shards orbit (Spin)
    for k in range(6):
        a = 2 * math.pi * k / 6 + 0.3
        c = V((math.cos(a) * 1.45, math.sin(a) * 1.45, 3.35 + math.sin(a * 3) * 0.2))
        d = V((rnd.uniform(-0.3, 0.3), rnd.uniform(-0.3, 0.3), 1)).normalized()
        ring.crystal(c - d * 0.35, c + d * 0.35, 0.13, SUNGLOW, sides=5, shaft=0.5)
        ring.spike(c - d * 0.35, c - d * 0.6, 0.12, SUNGLOW, segs=5)
    # head: a deep veiled hood, the veil hung with gold coins, ember eyes behind it
    head.sphere(0.42, "skin", loc=(0, 0.1, 4.75), segs=10, rings=7)
    head.tube([V((0, -0.05, 4.3)), V((0, -0.08, 4.85)), V((0, -0.1, 5.25)), V((0, -0.25, 5.45))], [(0.55, 0.52), (0.58, 0.56), (0.48, 0.48), (0.0, 0.0)], "cloth_dark", sides=10)
    head.prism([(-0.36, 0), (0.36, 0), (0.3, -0.62), (0, -0.75), (-0.3, -0.62)], 0.04, "sash_dark", loc=(0, 0.52, 4.92))
    for k in range(5):
        x = (k - 2) * 0.13
        head.cyl(0.05, 0.05, 0.02, "gold", loc=(x, 0.55, 4.22 - abs(k - 2) * 0.04), rot=(90, 0, 0), segs=8)
    for s in (1, -1):
        head.box((0.12, 0.05, 0.05), EMBER, loc=(s * 0.14, 0.55, 4.88))
    # arms; the right hand holds a tall staff with a gold crescent and an ember orb
    for s, side in ((-1, "L"), (1, "R")):
        arm = A.segment(f"Arm{side}", (s * 0.55, 0, 4.05), body)
        fore = A.segment(f"Forearm{side}", (s * 0.78, 0.15, 3.35), arm)
        arm.tube([V((s * 0.5, 0, 4.1)), V((s * 0.72, 0.1, 3.6)), V((s * 0.78, 0.15, 3.35))], [0.17, 0.19, 0.21], "cloth", sides=8)
        fore.tube([V((s * 0.78, 0.15, 3.35)), V((s * 0.82, 0.35, 2.85))], [0.22, 0.27], "cloth_dark", sides=8)
        fore.sphere(0.12, "skin", loc=(s * 0.82, 0.4, 2.75), segs=8, rings=5)
        if s == 1:
            fore.rod((0.82, 0.42, 1.0), (0.82, 0.42, 5.2), 0.06, "leather", segs=6)
            fore.torus(0.32, 0.05, "gold", loc=(0.82, 0.42, 5.45), rot=(90, 0, 0), major=12, minor=4)
            fore.sphere(0.18, EMBER, loc=(0.82, 0.42, 5.45), segs=10, rings=6)
    for s, side in ((-1, "L"), (1, "R")):
        leg = A.segment(f"Leg{side}", (s * 0.25, 0, 2.4), body)
        knee = A.segment(f"Knee{side}", (s * 0.28, 0.05, 1.2), leg)
        leg.tube([V((s * 0.25, 0, 2.45)), V((s * 0.28, 0.05, 1.2))], [0.16, 0.14], "cloth_dark", sides=7)
        knee.tube([V((s * 0.28, 0.05, 1.2)), V((s * 0.3, 0.1, 0.25))], [0.14, 0.12], "cloth_dark", sides=7)
        knee.box((0.32, 0.55, 0.16), "leather", loc=(s * 0.3, 0.28, 0.08), bevel=0.04)
    return A


# ============================================================================ Glass Scorpion Elite / Alpha (SCORPION)
def glass_scorpion(alpha=False):
    A = M.MobAsset("alpha_glass_scorpion" if alpha else "elite_glass_scorpion", "SCORPION", ATLAS_ALPHA if alpha else ATLAS, "ALPHA" if alpha else "ELITE")
    body = A.segment("Body", (0, 0, 2.0))
    head = A.segment("Head", (0, 2.4, 1.9), body)
    # obsidian plated body with amber glass seams, and a segmented tail arching over the back
    body.sphere(1.0, "obsidian", loc=(0, 0.6, 1.95), scale=(1.4, 1.8, 0.75), segs=14, rings=8)
    for k in range(5):
        y = 0.9 - k * 0.85
        w = 1.35 - k * 0.12
        body.box((w * 2, 0.8, 0.5), "obsidian_mid", loc=(0, y, 2.35 - k * 0.05), rot=(-6, 0, 0), bevel=0.15)
        body.box((w * 2 - 0.2, 0.1, 0.3), "glass_amber", loc=(0, y - 0.43, 2.3 - k * 0.05))
    # the tail: four links ExtraTail1-4 then ExtraSting, each pivoting at its base (keyed later; springs until then)
    tail = [V((0, -2.9, 2.4)), V((0, -3.9, 3.2)), V((0, -4.3, 4.4)), V((0, -3.9, 5.5)), V((0, -3.0, 6.1)), V((0, -2.0, 6.0))]
    prev = body
    for k in range(len(tail) - 1):
        r = 0.6 - k * 0.07
        link = A.segment("ExtraSting" if k == len(tail) - 2 else f"ExtraTail{k + 1}", tail[k], prev)
        link.rod(tail[k], tail[k + 1], r, "obsidian", segs=10, r2=r * 0.9)
        link.sphere(r * 0.92, "glass_amber", loc=tail[k + 1], segs=10, rings=6)
        prev = link
    sting = prev
    sting_base = tail[-1]
    sting.sphere(0.5, "glass_dark", loc=sting_base + V((0, 0.25, -0.15)), segs=10, rings=7)
    sting.tube([sting_base + V((0, 0.4, -0.2)), sting_base + V((0, 0.9, -0.6)), sting_base + V((0, 1.0, -1.1))], [0.2, 0.12, 0.0], MAGMA, sides=6)
    # head: a flat obsidian plate with amber eyes
    head.sphere(1.0, "obsidian", loc=(0, 2.75, 1.85), scale=(1.0, 0.7, 0.5), segs=12, rings=7)
    head.box((1.4, 0.7, 0.18), "obsidian_mid", loc=(0, 2.75, 2.25), bevel=0.08)
    for s in (1, -1):
        for k, (x, y) in enumerate(((0.3, 3.3), (0.55, 3.1))):
            head.sphere(0.1 - k * 0.02, EMBER, loc=(s * x, y, 2.15), segs=6, rings=4)
    # pincers (the clip set's jaws): long arms ending in glassy claws with gold-banded joints
    for s, side in ((-1, "L"), (1, "R")):
        jaw = A.segment(f"Jaw{side}", (s * 0.9, 3.1, 1.8), head)
        arm = [V((s * 0.9, 3.1, 1.8)), V((s * 1.7, 3.8, 1.95)), V((s * 1.8, 4.7, 2.0)), V((s * 1.5, 5.4, 2.0))]
        jaw.tube(arm, [0.3, 0.32, 0.36, 0.42], "obsidian", sides=8)
        for k in (1, 2):
            jaw.torus(0.35, 0.07, "bronze_dark", mat=K.look_matrix(arm[k], arm[k + 1]), major=12, minor=4)
        claw = arm[-1]
        jaw.sphere(0.55, "obsidian_mid", loc=claw, scale=(0.9, 1.2, 0.8), segs=10, rings=7)
        for k, off in enumerate((0.25, -0.25)):
            jaw.tube([claw + V((s * off, 0.3, 0)), claw + V((s * off * 1.4, 1.0, 0.05)), claw + V((s * off * 0.6, 1.6, 0.0))],
                     [0.22, 0.16, 0.0], "glass_amber" if k == 0 else "obsidian_mid", sides=6)
    # six spiky glass-black legs
    for s in (-1, 1):
        for i in (1, 2, 3):
            y = (2 - i) * 1.05 + 0.2
            hip = V((s * 1.2, y, 1.8))
            knee = V((s * 2.5, y * 1.15, 2.8))
            foot = V((s * 3.4, y * 1.3, 0.0))
            leg = A.segment(f"Leg{s}_{i}", hip, body)
            shin = A.segment(f"Knee{s}_{i}", knee, leg)
            leg.tube([hip, hip.lerp(knee, 0.5) + V((0, 0, 0.2)), knee], [0.2, 0.18, 0.16], "obsidian", sides=6)
            shin.sphere(0.18, "glass_amber", loc=knee, segs=8, rings=5)
            shin.tube([knee, knee.lerp(foot, 0.5) + V((s * 0.15, 0, 0.1)), foot + V((0, 0, 0.05))], [0.15, 0.11, 0.03], "obsidian_mid", sides=6)
            mid = knee.lerp(foot, 0.35)
            shin.spike(mid, mid + V((s * 0.1, 0, 0.35)), 0.07, "glass_dark", segs=4)
    if alpha:
        # trophy: a gold sun crest mounted under the stinger
        crest = A.segment("Trophy_SunCrest", (0, -2.6, 6.2), sting)  # rides the stinger
        M.sun_glyph(crest, (0, -2.4, 6.75), (0, 1, 0.2), 0.55, "gold", SUNGLOW, rays=10, ring_thick=0.09)
    return A


# ============================================================================ Sandstone Colossus (Biome Boss, STONE_COLOSSUS)
def sandstone_colossus():
    A = M.MobAsset("boss_sandstone_colossus", "STONE_COLOSSUS", ATLAS, "BOSS")
    body = A.segment("Body", (0, 0, 8.2))
    head = A.segment("Head", (0, 0.9, 14.9), body)
    rnd = random.Random(40)
    bands = ("sandstone", "band", "sand", "band_dark")
    # banded pelvis and torso blocks, a broad collar, a magma seam down the spine
    banded_block(body, (5.4, 3.6, 2.2), (0, 0, 8.0), bands, bands=2, bevel=0.3)
    banded_block(body, (6.6, 4.1, 2.6), (0, 0.2, 10.3), ("sandstone", "band"), bands=2, bevel=0.3)
    banded_block(body, (8.6, 4.6, 2.8), (0, 0.4, 12.85), ("sand", "sandstone"), bands=2, bevel=0.35)
    body.box((7.0, 0.5, 0.9), "gold", loc=(0, 2.75, 13.7), bevel=0.12)
    for k in range(9):
        body.box((0.5, 0.35, 0.7), "lapis" if k % 2 else "gold_dark", loc=(-3.2 + k * 0.8, 2.95, 13.65), bevel=0.05)
    seam = [V((0, -2.1 + 0.05 * math.sin(k), 7.4 + k * 0.85)) + V((rnd.uniform(-0.2, 0.2), 0, 0)) for k in range(8)]
    body.tube(seam, [0.16] * len(seam), MAGMA, sides=5)
    for k in range(4):  # cracks branching from the seam
        p = seam[1 + k * 2]
        sgn = 1 if k % 2 else -1
        body.tube([p, p + V((sgn * 0.8, -0.05, 0.4)), p + V((sgn * 1.4, 0.0, 0.3))], [0.1, 0.07, 0.03], MAGMA, sides=4)
    for k, (x, y, z, tx, ty, tz, r) in enumerate(((-3.6, -1.0, 13.9, -4.4, -2.0, 15.6, 0.55), (3.6, -1.0, 13.9, 4.6, -1.8, 15.4, 0.55),
                                                   (-1.5, -1.9, 13.8, -1.9, -3.0, 15.0, 0.4), (1.6, -1.9, 13.6, 2.2, -3.1, 14.8, 0.4))):
        body.crystal((x, y, z), (tx, ty, tz), r, "glass_amber", sides=6)
    # head: a guardian's face under a striped nemes headdress, ember eyes, a braided beard (built 1.3x about its base)
    hb = V((0, 1.2, 14.2))
    def H(x, y, z):
        return tuple(hb + (V((x, y, z)) - hb) * 1.3)
    def HS(*s):
        return tuple(v * 1.3 for v in s)
    head.box(HS(2.4, 2.2, 2.4), "sandstone", loc=H(0, 1.3, 15.8), bevel=0.35)
    for s in (1, -1):
        for k in range(3):
            head.box(HS(0.9, 0.42, 2.6 - k * 0.2), "gold" if k % 2 == 0 else "lapis", loc=H(s * 1.55, 1.2 - k * 0.42, 15.35 - k * 0.05), rot=(0, s * 8, 0), bevel=0.08)
    head.box(HS(2.8, 2.5, 0.6), "gold", loc=H(0, 1.1, 17.15), bevel=0.18)
    head.box(HS(2.2, 2.0, 0.5), "lapis", loc=H(0, 1.1, 17.6), bevel=0.14)
    head.prism([(-1.3 * 1.3, 0), (1.3 * 1.3, 0), (0, 1.3)], 2.3, "gold_dark", loc=H(0, 1.0, 17.85))
    head.sphere(0.45, MAGMA, loc=H(0, 2.55, 17.25), segs=8, rings=5)
    for s in (1, -1):
        head.box(HS(0.55, 0.15, 0.22), EMBER, loc=H(s * 0.55, 2.45, 16.1))
    head.box(HS(0.5, 0.5, 0.8), "sand", loc=H(0, 2.4, 15.55), bevel=0.1)
    head.box(HS(0.8, 0.7, 1.4), "band_dark", loc=H(0, 2.2, 14.3), bevel=0.18)
    for z in (14.0, 14.5):
        head.box(HS(0.85, 0.75, 0.1), "gold", loc=H(0, 2.2, z))
    # arms: shoulder blocks with glass shards, banded upper arms, slab forearms, glass-veined fists
    for s, side in ((-1, "L"), (1, "R")):
        arm = A.segment(f"Arm{side}", (s * 4.6, 0.4, 13.0), body)
        fore = A.segment(f"Forearm{side}", (s * 5.4, 0.8, 9.6), arm)
        banded_block(arm, (2.8, 3.0, 2.4), (s * 5.0, 0.4, 13.4), ("sandstone", "band", "sand"), bands=3)
        arm.crystal((s * 5.3, -0.5, 14.6), (s * 6.2, -1.4, 16.3), 0.5, "glass_amber", sides=6)
        for k in range(2):
            z = 11.7 - k * 1.15
            arm.cyl(1.1 - k * 0.05, 1.05 - k * 0.05, 1.1, ("band", "sandstone")[k], loc=(s * (5.0 + k * 0.18), 0.4 + k * 0.18, z), segs=12)
        fore.box((2.1, 2.1, 0.6), "gold_dark", loc=(s * 5.4, 0.8, 9.6), bevel=0.1)
        banded_block(fore, (2.3, 2.4, 3.2), (s * 5.55, 1.0, 7.6), ("band", "sandstone", "band_dark"), bands=3)
        fore.box((3.0, 3.0, 2.4), "sandstone", loc=(s * 5.7, 1.3, 4.8), bevel=0.35)
        for k in range(3):  # obsidian glass veins with ember light in the fist
            a = math.radians(30 + k * 60)
            p = V((s * 5.7, 1.3, 4.8)) + V((math.cos(a) * 1.2 * s, 1.55, math.sin(a) * 0.9 - 0.3))
            fore.tube([p, p + V((s * 0.3, 0, -0.6)), p + V((s * 0.1, 0, -1.2))], [0.12, 0.1, 0.05], "obsidian", sides=5)
            fore.sphere(0.12, EMBER, loc=p + V((s * 0.3, 0.05, -0.6)), segs=6, rings=4)
    # legs: banded pillars on plinth feet
    for s, side in ((-1, "L"), (1, "R")):
        leg = A.segment(f"Leg{side}", (s * 2.0, 0, 7.0), body)
        knee = A.segment(f"Knee{side}", (s * 2.1, 0.2, 3.6), leg)
        for k in range(2):
            leg.cyl(1.25, 1.2, 1.7, ("sandstone", "band")[k], loc=(s * (2.0 + k * 0.05), 0.08 * k, 6.15 - k * 1.7), segs=12)
        knee.sphere(1.05, "sand", loc=(s * 2.1, 0.35, 3.6), segs=12, rings=7)
        for k in range(2):
            knee.cyl(1.15, 1.25, 1.35, ("band", "sandstone")[k], loc=(s * 2.12, 0.25, 2.7 - k * 1.3), segs=12)
        knee.box((3.0, 3.6, 1.0), "band_dark", loc=(s * 2.15, 0.7, 0.5), bevel=0.2)
        knee.box((3.2, 3.8, 0.2), "gold_dark", loc=(s * 2.15, 0.7, 1.05))
    return A


BUILDERS = {
    "mob_dune_scarab": dune_scarab,
    "mob_ash_raider": ash_raider,
    "mob_ember_oracle": ember_oracle,
    "elite_glass_scorpion": lambda: glass_scorpion(False),
    "alpha_glass_scorpion": lambda: glass_scorpion(True),
    "boss_sandstone_colossus": sandstone_colossus,
}
