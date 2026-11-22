"""
Corrupted Grove Floor 35 (Sovereign's Grove — Biome Boss: Blight Sovereign) sculpted assets,
generated in headless Blender.

Follows docs/prompts/corrupted-grove-floor-layouts-prompt.md (Floor 35):
the Mother Graft's colossal root crown over an abyssal sap mire (Bottom = -8, Surface = "BLIGHT"),
where three colossal roots climb to the 184 x 136 Sovereign's Dais beneath the >= 230-stud dead
colossus trunk of the Mother Graft.

Templates (14):
  MotherGraftTrunk      colossal dead Mother Graft colossus (~86 x 205 x 68; 1.22x Y -> 250 studs) with blazing cavity & Giant Pale Band
  MotherGraftLimbOak    gnarled dead grafted oak limb with heartrot seams
  MotherGraftLimbPine   twisted grafted pine bough with blighted needles
  MotherGraftLimbFruit  crooked grafted orchard bough hung with bloated glowing rot-fruit
  RootRidgeSegment      colossal curved root-bark ridge casing with bark plates & glowing heartrot fissures
  RootKneeJunction      fused cracked root-burl knot bursting with glowing blight pods
  LastWardenGraft       sombre Hollin warden half-grafted into a root, knife in hand, ringed in remnant green moss & ferns
  RotbloomGiant         colossal shield-sized magenta rot-bloom cluster (Rotbloom Nursery)
  FallenCrownBranch     broken circlet of fallen Mother Graft crown branches
  SapfallRibbon         sculpted curving viscous magenta sap waterfall pouring off a root into a splash pool
  HeartrotGeode         split dark-basalt root geode glowing violet-magenta inside (Blightroot Geode echo)
  ThornCagedSeed        luminous clean golden seed pod imprisoned inside black thorns (Heartrot Core echo)
  MossMantle            sweeping tattered hanging moss & dead-vine curtain for high canopy rims
  WardenRootShrine      carved Hollin root-crest shrine of crossed timber & fieldstone wrapped in a Pale Band

Reuses `tools/blender/generate_tower_biome_kit.py` helpers and existing colour roles only:
WOOD, TRIM, ALT, FOLIAGE, MOSS, SILK, STONE, GLOW, CANDLE, CAP, CORAL, ACCENT, METAL, STEM.

Run:
    /Applications/Blender.app/Contents/MacOS/Blender --background --python tools/blender/generate_corrupted_f35_kit.py
"""
import bpy, bmesh, math, os, json, runpy
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT_DIR = os.path.join(ROOT, "assets-source", "tower", "corrupted_f35_kit")

kit_mod = runpy.run_path(os.path.join(HERE, "generate_tower_biome_kit.py"), init_globals={"RUN_KIT": False})

Template = kit_mod["Template"]
M = kit_mod["M"]
box = kit_mod["box"]
cone = kit_mod["cone"]
uvsphere = kit_mod["uvsphere"]
lathe = kit_mod["lathe"]
tube = kit_mod["tube"]
rock = kit_mod["rock"]
ring_mesh = kit_mod["ring_mesh"]
canopy_blob = kit_mod["_canopy_blob"]
reset_scene = kit_mod["reset_scene"]
finalize = kit_mod["finalize"]
render_previews = kit_mod["render_previews"]


def rock_clean(bm, size, mat, seed, roughness=0.24, subdiv=2, flat_bottom=True):
    tmp = bmesh.new()
    rock(tmp, size, mat, seed, roughness=roughness, subdiv=subdiv, flat_bottom=flat_bottom)
    vert_map = {}
    for v in tmp.verts:
        vert_map[v] = bm.verts.new(v.co)
    for f in tmp.faces:
        try:
            bm.faces.new([vert_map[v] for v in f.verts])
        except ValueError:
            pass
    tmp.free()


def pale_band_wrap(bm, radius, z, height=2.2, segs=14, tail=True, tail_ang=-math.pi / 2):
    ring_mesh(bm, radius, height * 0.45, segs, M((0, 0, z)), tube_segs=5)
    ring_mesh(bm, radius * 1.03, height * 0.36, segs, M((0, 0, z + height * 0.42)), tube_segs=5)
    if tail:
        ca, sa = math.cos(tail_ang), math.sin(tail_ang)
        pts = [
            (ca * (radius + 0.4), sa * (radius + 0.4), z),
            (ca * (radius + 1.4), sa * (radius + 1.4), z - height * 1.5),
            (ca * (radius + 2.2), sa * (radius + 2.2), z - height * 3.1),
        ]
        tube(bm, pts, [height * 0.36, height * 0.28, height * 0.14], 4)


def giant_bloom(bm_cap, bm_glow, center, radius=3.6, tilt=(0, 0, 0)):
    mat = M(center, rot=tilt)
    for k in range(7):
        a = k * 2 * math.pi / 7
        p_mat = mat @ M((math.cos(a) * radius * 0.56, math.sin(a) * radius * 0.56, radius * 0.14), rot=(0.42, 0, a + math.pi / 2))
        uvsphere(bm_cap, 1.0, p_mat @ M((0, 0, 0), scale=(radius * 0.44, radius * 0.56, radius * 0.20)), u=7, v=5)
    for k in range(5):
        a = k * 2 * math.pi / 5 + 0.3
        p_mat = mat @ M((math.cos(a) * radius * 0.30, math.sin(a) * radius * 0.30, radius * 0.34), rot=(0.68, 0, a + math.pi / 2))
        uvsphere(bm_cap, 1.0, p_mat @ M((0, 0, 0), scale=(radius * 0.30, radius * 0.38, radius * 0.16)), u=6, v=4)
    uvsphere(bm_glow, radius * 0.34, mat @ M((0, 0, radius * 0.36)), u=7, v=5)


F35_TEMPLATES = {}


def template(name, **budget):
    def deco(fn):
        F35_TEMPLATES[name] = (fn, budget)
        return fn
    return deco


@template("MotherGraftTrunk", WOOD=4800, GLOW=1400, SILK=700, CAP=700, MOSS=500)
def mother_graft_trunk(t):
    """The Mother Graft (~86 x 64 x 205; placed at Y scale 1.22 -> 250 studs): the dead colossus
    trunk behind the Sovereign's Dais, parted around a blazing magenta heart-cavity at Z ~105,
    bound below by the colossal rotten Pale Band, with dead grafted limbs fanning wide to the
    sides and back (never protruding far in -Y over the boss arena)."""
    wood, glow, silk, cap, moss = t.bm("WOOD"), t.bm("GLOW"), t.bm("SILK"), t.bm("CAP"), t.bm("MOSS")

    # Twin monumental split trunk halves rising Z 0..195, curving apart around the cavity at Z 65..135.
    for s in (-1, 1):
        pts, radii = [], []
        for k in range(13):
            f = k / 12.0
            part = s * (8.0 + 9.5 * math.sin(f * math.pi) + 7.5 * (f ** 1.8))
            pts.append(Vector((part + math.sin(f * 5.0 + s) * 1.5, 4.0 + 6.0 * f, f * 192.0)))
            radii.append(16.0 - 10.0 * f)
        tube(wood, pts, radii, 10)

    # Massive root buttresses flaring out sideways and backward (keeping -Y trim so arena stays clear!).
    for k in range(8):
        a = k * 2 * math.pi / 8 + 0.2
        ca, sa = math.cos(a), math.sin(a)
        r_out = 28.0 if sa < -0.35 else 38.0
        pts = [
            Vector((ca * 12.0, sa * 10.0, 38.0)),
            Vector((ca * (r_out * 0.65), sa * (r_out * 0.65), 14.0)),
            Vector((ca * r_out, sa * r_out, 0.2)),
        ]
        tube(wood, pts, [7.2, 4.8, 2.2], 7)

    # Blazing colossal heartrot cavity nested inside the split at Z 78..132 (facing -Y toward the dais!).
    uvsphere(glow, 12.5, M((0, -2.5, 104.0), scale=(0.95, 0.52, 2.35)), u=12, v=9)
    for k in range(8):
        a = -math.pi / 2 + (k - 3.5) * 0.34
        tube(
            glow,
            [
                (math.cos(a) * 6.0, math.sin(a) * 4.5 - 1.5, 88.0 + (k % 3) * 12.0),
                (math.cos(a) * 18.0, math.sin(a) * 9.0 - 2.0, 104.0 + (k - 3.5) * 7.0),
                (math.cos(a) * 26.0, math.sin(a) * 11.0, 62.0 + k * 5.0),
            ],
            [1.45, 0.92, 0.40],
            5,
        )

    # Enormous rotting Pale Band tied round the colossus trunk below the heart cavity (Z 56).
    pale_band_wrap(silk, 19.5, 56.0, height=5.8, segs=16, tail=True, tail_ang=-math.pi / 2 + 0.25)

    # Crown of 10 dead grafted limbs fanning sideways & upward to Z 205 (never overhanging -Y arena!).
    for idx in range(10):
        # Fan across east, north, and west (-15° to +195°), avoiding straight south (-90°).
        a = math.radians(-10 + idx * 22.2)
        ca, sa = math.cos(a), math.sin(a)
        start_z = 128.0 + (idx % 4) * 16.0
        reach = 36.0 + (idx % 3) * 7.5
        peak_z = start_z + 28.0 + (idx % 3) * 12.0
        pts = [
            Vector((ca * 9.0, sa * 8.0, start_z)),
            Vector((ca * (reach * 0.56), sa * (reach * 0.56), start_z + 18.0)),
            Vector((ca * reach, sa * reach, peak_z)),
        ]
        tube(wood, pts, [5.4, 3.2, 0.9], 6)
        # Secondary dead twigs for the "hundred species" silhouette.
        mid = pts[1]
        twig_end = mid + Vector((ca * 10.0 - sa * 8.0, sa * 10.0 + ca * 8.0, 18.0))
        tube(wood, [mid, twig_end], [2.0, 0.5], 5)
        if idx % 2 == 0:
            canopy_blob(moss, mid + Vector((0, 0, -4.0)), (4.5, 4.0, 8.5), 11 + idx)

    # Giant bloated rot-blooms erupting around the lower root collars.
    for sx, sy, sz in [(-22.0, -5.0, 26.0), (22.0, -4.0, 32.0), (-18.0, 8.0, 68.0), (19.0, 6.0, 74.0)]:
        giant_bloom(cap, glow, (sx, sy, sz), radius=5.2, tilt=(0.5, 0, 0))


@template("MotherGraftLimbOak", WOOD=1600, GLOW=450, MOSS=500)
def mother_graft_limb_oak(t):
    """Gnarled dead grafted oak limb (~46 x 22 x 30) with twisting sub-branches and glowing rot veins."""
    wood, glow, moss = t.bm("WOOD"), t.bm("GLOW"), t.bm("MOSS")
    pts = [Vector((-20.0, 0, 2.0)), Vector((-6.0, -2.5, 11.0)), Vector((8.0, 2.0, 18.5)), Vector((22.0, -1.0, 26.0))]
    tube(wood, pts, [4.6, 3.4, 2.2, 0.8], 7)
    tube(wood, [pts[1], Vector((-2.0, -9.0, 23.0)), Vector((4.0, -12.0, 29.0))], [2.2, 1.3, 0.5], 6)
    tube(wood, [pts[2], Vector((14.0, 9.5, 25.0))], [1.8, 0.55], 5)
    tube(glow, [pts[0] + Vector((0, -2.5, 1.0)), pts[1] + Vector((0, -2.0, 0.6)), pts[2] + Vector((0, -1.2, 0.4))], [0.6, 0.45, 0.25], 4)
    canopy_blob(moss, pts[1] + Vector((0, 0, -2.5)), (5.0, 4.2, 3.2), 21)


@template("MotherGraftLimbPine", WOOD=1500, FOLIAGE=700, GLOW=350)
def mother_graft_limb_pine(t):
    """Twisted grafted pine bough (~44 x 20 x 28) with jagged needle tufts and glowing sap seams."""
    wood, foliage, glow = t.bm("WOOD"), t.bm("FOLIAGE"), t.bm("GLOW")
    pts = [Vector((-19.0, 0, 1.5)), Vector((-4.0, 1.5, 9.5)), Vector((10.0, -1.5, 18.0)), Vector((21.0, 0.5, 24.0))]
    tube(wood, pts, [4.0, 2.9, 1.8, 0.65], 7)
    for idx, p in enumerate(pts[1:]):
        for s in (-1, 1):
            tip = p + Vector((4.0, s * 7.5, 3.5))
            tube(wood, [p, tip], [1.2, 0.35], 5)
            cone(foliage, 3.2, 0.2, 6.2, segs=6, mat=M(tip, rot=(s * 0.4, 0.3, idx)))
    tube(glow, [pts[0] + Vector((0, -2.0, 0.8)), pts[2] + Vector((0, -1.0, 0.4))], [0.5, 0.24], 4)


@template("MotherGraftLimbFruit", WOOD=1500, CAP=700, GLOW=450)
def mother_graft_limb_fruit(t):
    """Crooked grafted orchard bough (~42 x 20 x 26) hung with bloated glowing magenta rot-fruit."""
    wood, cap, glow = t.bm("WOOD"), t.bm("CAP"), t.bm("GLOW")
    pts = [Vector((-18.0, 0, 2.0)), Vector((-4.0, -2.0, 12.0)), Vector((9.0, 1.8, 19.0)), Vector((20.0, 0, 22.0))]
    tube(wood, pts, [3.8, 2.8, 1.7, 0.65], 7)
    for idx, (fx, fy, fz) in enumerate([(-6.0, -3.0, 7.5), (2.0, -1.0, 11.5), (10.0, 2.5, 14.0), (16.0, -1.0, 16.5)]):
        tube(wood, [(fx, fy, fz + 3.2), (fx, fy, fz + 0.8)], [0.24, 0.18], 4)
        uvsphere(cap, 2.2 + (idx % 2) * 0.5, M((fx, fy, fz), scale=(0.95, 0.95, 1.15)), u=8, v=6)
        uvsphere(glow, 1.1, M((fx, fy - 1.2, fz - 0.5)), u=6, v=4)


@template("RootRidgeSegment", WOOD=2000, GLOW=500, MOSS=450, CAP=400)
def root_ridge_segment(t):
    """Colossal curved root-bark ridge casing (~32 x 18 x 12) with side-roots and pulsing heartrot seams."""
    wood, glow, moss, cap = t.bm("WOOD"), t.bm("GLOW"), t.bm("MOSS"), t.bm("CAP")
    # Heavy ribbed arch-root body running along X (-15..+15).
    pts = [Vector((-15.5, 0, 2.0)), Vector((-6.0, 1.2, 6.2)), Vector((6.0, -1.0, 6.8)), Vector((15.5, 0, 2.2))]
    tube(wood, pts, [4.6, 5.4, 5.2, 4.4], 9)
    # Four gripping side-roots clutching down into the mire.
    for sx in (-10.0, -3.0, 4.0, 11.0):
        for sy in (-1, 1):
            tube(wood, [(sx, sy * 3.5, 5.0), (sx + sy * 1.5, sy * 8.2, 0.2)], [2.1, 0.9], 5)
    # Glowing heartrot fissure running down the root flank.
    tube(glow, [(-13.0, -4.2, 2.8), (-4.0, -5.0, 5.8), (5.0, -5.2, 6.0), (13.0, -4.0, 3.0)], [0.55, 0.72, 0.68, 0.48], 5)
    canopy_blob(moss, (-5.0, 2.8, 7.2), (4.6, 3.2, 1.4), 31)
    giant_bloom(cap, glow, (6.5, -4.2, 5.6), radius=2.2, tilt=(0.6, 0, 0))


@template("RootKneeJunction", WOOD=2200, GLOW=600, CAP=650, MOSS=400)
def root_knee_junction(t):
    """Fused cracked bark burl (~26 x 24 x 14) where great roots knit together, bursting with blight pods."""
    wood, glow, cap, moss = t.bm("WOOD"), t.bm("GLOW"), t.bm("CAP"), t.bm("MOSS")
    # Interlaced X-shaped root burl arms.
    for ang in (0.4, -0.4, 1.9, -1.9):
        ca, sa = math.cos(ang), math.sin(ang)
        tube(wood, [(0, 0, 7.5), (ca * 7.5, sa * 7.5, 5.2), (ca * 12.5, sa * 12.5, 0.2)], [4.6, 3.4, 1.8], 7)
    uvsphere(wood, 6.8, M((0, 0, 6.5), scale=(1.15, 1.05, 0.95)), u=10, v=7)
    # Cracked glowing seams & bursting blight pods across the crown.
    for k in range(5):
        a = k * 2 * math.pi / 5
        tube(glow, [(0, 0, 8.2), (math.cos(a) * 8.0, math.sin(a) * 8.0, 4.6)], [0.62, 0.28], 4)
        uvsphere(cap, 2.0, M((math.cos(a) * 5.8, math.sin(a) * 5.8, 7.8 + (k % 2) * 1.4)), u=7, v=5)
        uvsphere(glow, 0.9, M((math.cos(a) * 5.8, math.sin(a) * 5.8, 9.2 + (k % 2) * 1.4)), u=6, v=4)
    canopy_blob(moss, (0, 0, 11.4), (4.5, 4.2, 1.6), 37)


@template("LastWardenGraft", WOOD=1600, TRIM=700, SILK=500, MOSS=700, FOLIAGE=650, METAL=300)
def last_warden_graft(t):
    """Sombre Hollin warden (~14 x 14 x 16) half-grafted into a gnarled root, grafting knife in hand,
    surrounded by a ring of lush remnant green moss and ferns — the only green on Floor 35."""
    wood, trim, silk, moss, foliage, metal = t.bm("WOOD"), t.bm("TRIM"), t.bm("SILK"), t.bm("MOSS"), t.bm("FOLIAGE"), t.bm("METAL")
    # Gnarled root column rising behind & enveloping the warden's legs and left shoulder.
    tube(wood, [(0, 1.6, 0), (0.4, 1.4, 7.5), (-0.8, 2.2, 15.0)], [3.6, 2.6, 1.4], 8)
    for k in range(5):
        a = k * 2 * math.pi / 5
        tube(wood, [(0, 1.2, 3.8), (math.cos(a) * 5.8, math.sin(a) * 5.8, 0.0)], [1.4, 0.65], 5)
    # Sombre hooded Hollin warden torso, bowed head, and right arm extending a curved grafting knife.
    lathe(trim, [(2.0, 2.0), (1.7, 6.2), (1.9, 9.5), (1.1, 10.6), (0, 10.6)], 10, M((0, -0.8, 0)))
    uvsphere(trim, 1.35, M((0, -1.2, 11.4), rot=(0.25, 0, 0), scale=(0.95, 1.1, 1.15)), u=8, v=6)
    # Right arm & gleaming curved Hollin grafting knife held forward.
    tube(trim, [(1.6, -0.8, 8.8), (3.4, -2.4, 7.2), (4.2, -4.0, 7.6)], [0.55, 0.45, 0.36], 5)
    box(metal, (0.3, 3.6, 0.75), M((4.5, -5.5, 8.2), rot=(0.35, 0, -0.25)))
    # Pale Band sash across the warden's chest & coiled around the root.
    pale_band_wrap(silk, 2.3, 7.8, height=1.2, segs=10, tail=True, tail_ang=-1.8)
    # Ring of lush remnant green moss & living fern fronds circling the warden's feet!
    for k in range(8):
        a = k * 2 * math.pi / 8
        canopy_blob(moss, (math.cos(a) * 5.2, math.sin(a) * 5.2, 0.9), (2.4, 2.2, 0.9), 41 + k)
        box(foliage, (1.2, 3.8, 0.25), M((math.cos(a) * 5.8, math.sin(a) * 5.8, 1.6), rot=(0.48, 0, a - math.pi / 2)))


@template("RotbloomGiant", CAP=1800, GLOW=700, WOOD=500, MOSS=350)
def rotbloom_giant(t):
    """Colossal shield-sized pulsing magenta rot-bloom cluster (~18 x 18 x 14) for the Rotbloom Nursery."""
    cap, glow, wood, moss = t.bm("CAP"), t.bm("GLOW"), t.bm("WOOD"), t.bm("MOSS")
    # Tangled dark root urn-base echoing the Rotbloom Urn relic.
    lathe(wood, [(4.2, 0.0), (5.2, 2.8), (4.4, 5.4), (3.6, 5.4), (3.6, 0.8), (0.0, 0.8)], 12, M((0, 0, 0)))
    for k in range(5):
        a = k * 2 * math.pi / 5
        tube(wood, [(math.cos(a) * 4.5, math.sin(a) * 4.5, 4.5), (math.cos(a) * 7.8, math.sin(a) * 7.8, 0.0)], [1.1, 0.5], 5)
    # Central colossal shield-sized bloom + 3 flanking blooms!
    giant_bloom(cap, glow, (0, 0, 8.8), radius=5.6, tilt=(0.15, 0, 0))
    giant_bloom(cap, glow, (-5.4, -3.6, 5.2), radius=3.4, tilt=(0.55, -0.3, 0.4))
    giant_bloom(cap, glow, (5.6, -2.8, 5.6), radius=3.2, tilt=(0.50, 0.35, -0.4))
    giant_bloom(cap, glow, (0.4, 5.4, 6.4), radius=3.5, tilt=(-0.45, 0, 0.2))
    canopy_blob(moss, (0, -4.8, 1.6), (3.8, 2.8, 1.2), 53)


@template("FallenCrownBranch", WOOD=1900, GLOW=450, MOSS=450, SILK=350)
def fallen_crown_branch(t):
    """Broken circular crown of ancient Mother Graft branches (~26 x 24 x 15) lying like a fallen circlet."""
    wood, glow, moss, silk = t.bm("WOOD"), t.bm("GLOW"), t.bm("MOSS"), t.bm("SILK")
    # Two sweeping broken arc halves forming an open circlet with upward crown tines.
    for half in (0, 1):
        pts, radii = [], []
        start_a = half * math.pi + 0.22
        for i in range(8):
            a = start_a + i * (math.pi - 0.55) / 7.0
            r = 10.5 + math.sin(i * 1.1) * 1.1
            z = 2.2 + math.sin(i * math.pi / 7.0) * 3.0
            pts.append(Vector((math.cos(a) * r, math.sin(a) * r, z)))
            radii.append(2.2 - 0.8 * abs(i - 3.5) / 3.5)
        tube(wood, pts, radii, 7)
        for i in (1, 3, 5):
            p = pts[i]
            tip = p + Vector((p.x * 0.18, p.y * 0.18, 9.5 + (i % 2) * 3.0))
            tube(wood, [p, tip], [1.4, 0.32], 5)
            if i == 3:
                tube(glow, [p + Vector((0, 0, 0.6)), tip], [0.38, 0.16], 4)
        canopy_blob(moss, pts[2], (3.4, 3.0, 1.6), 61 + half)
    pale_band_wrap(silk, 2.1, 4.5, height=1.2, segs=8, tail=True, tail_ang=-1.2)


@template("SapfallRibbon", GLOW=1200, WOOD=900, CAP=450)
def sapfall_ribbon(t):
    """Sculpted curving viscous magenta sap waterfall (~14 x 16 x 32) pouring off a root-burl spout into a splash pool."""
    glow, wood, cap = t.bm("GLOW"), t.bm("WOOD"), t.bm("CAP")
    # Overhanging gnarly root spout at Z 26..31.
    tube(wood, [(0, 6.5, 29.5), (0, 1.8, 28.2), (0, -2.5, 26.2)], [4.2, 3.4, 2.4], 7)
    # Three thick sculpted twisting strands of pouring magenta sap descending Z 26 -> 0.
    for idx, (sx, rad) in enumerate([(-1.4, 1.45), (0.0, 2.05), (1.5, 1.35)]):
        pts, radii = [], []
        for k in range(10):
            f = k / 9.0
            pts.append(Vector((sx + math.sin(f * 5.0 + idx) * 0.7, -2.2 - 3.2 * (f ** 0.7), 26.2 * (1.0 - f))))
            radii.append(rad * (1.0 - 0.25 * math.sin(f * math.pi)) + (0.9 if k == 9 else 0.0))
        tube(glow, pts, radii, 7)
    # Bubbling glowing sap splash pool & foam blisters at the base (Z 0..2.2).
    uvsphere(glow, 1.0, M((0, -5.2, 0.6), scale=(6.2, 5.2, 0.75)), u=12, v=6)
    for k in range(5):
        a = k * 2 * math.pi / 5
        uvsphere(cap, 1.15, M((math.cos(a) * 3.8, -5.2 + math.sin(a) * 3.2, 1.4)), u=7, v=5)


@template("HeartrotGeode", STONE=1200, GLOW=900, CAP=500, WOOD=500)
def heartrot_geode(t):
    """Split dark-basalt root geode (~16 x 14 x 14) glowing violet-magenta inside (Blightroot Geode echo)."""
    stone, glow, cap, wood = t.bm("STONE"), t.bm("GLOW"), t.bm("CAP"), t.bm("WOOD")
    # Two cracked basalt shell halves opening toward -Y.
    for s in (-1, 1):
        rock_clean(stone, (7.6, 9.5, 12.2), M((s * 3.8, 0.8, 5.4), rot=(0, s * 0.22, s * 0.35)), 71 + s)
    # Radiant cluster of glowing violet-magenta crystal prisms erupting from the split interior.
    for k in range(7):
        a = (k - 3) * 0.35
        h = 6.5 + (3 - abs(k - 3)) * 2.2
        cone(glow, 1.45, 0.25, h, segs=6, mat=M((math.sin(a) * 2.4, -1.6, 3.2 + h * 0.38), rot=(-0.45, a, 0)))
    # Grasping black roots cradling the geode base.
    for k in range(4):
        a = k * math.pi / 2 + 0.4
        tube(wood, [(math.cos(a) * 3.0, math.sin(a) * 3.0, 5.0), (math.cos(a) * 7.8, math.sin(a) * 7.8, 0.0)], [1.2, 0.5], 5)
    giant_bloom(cap, glow, (0, 3.8, 11.4), radius=2.4, tilt=(-0.3, 0, 0))


@template("ThornCagedSeed", WOOD=1400, CANDLE=700, GLOW=450, STONE=400, SILK=300)
def thorn_caged_seed(t):
    """Luminous clean golden seed pod imprisoned inside a lattice of twisted black thorns (Heartrot Core echo)."""
    wood, candle, glow, stone, silk = t.bm("WOOD"), t.bm("CANDLE"), t.bm("GLOW"), t.bm("STONE"), t.bm("SILK")
    rock_clean(stone, (9.5, 9.5, 3.2), M((0, 0, 1.2)), 83)
    # Glowing clean amber-gold seed pod suspended inside the cage (Z 4..11).
    uvsphere(candle, 1.0, M((0, 0, 7.6), scale=(2.8, 2.8, 4.0)), u=10, v=8)
    # 8 spiralling barbed black thorn bars caging the seed!
    for k in range(8):
        a = k * 2 * math.pi / 8
        pts = []
        for i in range(6):
            f = i / 5.0
            tw = a + f * 0.9
            r = 4.6 * math.sin(f * math.pi * 0.85) + 1.4
            pts.append(Vector((math.cos(tw) * r, math.sin(tw) * r, 1.8 + f * 12.8)))
        tube(wood, pts, [0.75, 0.65, 0.55, 0.45, 0.35, 0.2], 5)
    # Magenta corruption tendrils trying to pierce the base.
    for k in range(4):
        a = k * math.pi / 2
        tube(glow, [(math.cos(a) * 5.2, math.sin(a) * 5.2, 1.8), (math.cos(a) * 3.2, math.sin(a) * 3.2, 5.2)], [0.35, 0.18], 4)
    pale_band_wrap(silk, 4.4, 3.2, height=1.1, segs=10, tail=True, tail_ang=-1.4)


@template("MossMantle", MOSS=1200, WOOD=600, GLOW=250)
def moss_mantle(t):
    """Sweeping tattered hanging moss & dead-vine curtain (~28 x 10 x 26) for high Mother Graft rims."""
    moss, wood, glow = t.bm("MOSS"), t.bm("WOOD"), t.bm("GLOW")
    # Overhead support bough at Z 22..25.
    tube(wood, [(-13.5, 0, 23.0), (0, 0.8, 25.0), (13.5, 0, 22.8)], [1.8, 2.2, 1.6], 6)
    # 7 long swaying moss curtains hanging down to Z 0.5..9.
    for i in range(7):
        x = -11.0 + i * 3.65
        drop = 15.0 + ((i * 5) % 4) * 2.8
        pts = [Vector((x, 0, 23.8)), Vector((x + math.sin(i) * 0.9, -0.6, 23.8 - drop * 0.5)), Vector((x - math.cos(i) * 0.8, 0.4, 23.8 - drop))]
        tube(moss, pts, [1.5, 1.25, 0.42], 5)
        if i % 3 == 1:
            tube(glow, [pts[0], pts[1]], [0.28, 0.16], 4)


@template("WardenRootShrine", WOOD=1100, STONE=700, SILK=450, CANDLE=300)
def warden_root_shrine(t):
    """Carved Hollin root-crest shrine (~14 x 10 x 16) of crossed graft-knot timber, stacked stones & Pale Band."""
    wood, stone, silk, candle = t.bm("WOOD"), t.bm("STONE"), t.bm("SILK"), t.bm("CANDLE")
    # Stacked fieldstone cairn base.
    rock_clean(stone, (8.2, 6.8, 2.6), M((0, 0, 1.1)), 91)
    rock_clean(stone, (6.0, 5.2, 2.2), M((0, 0, 3.0)), 93)
    # Crossed Hollin graft-knot timber posts rising to Z 15.5 + ring halo.
    tube(wood, [(-3.6, 0, 2.2), (3.4, 0, 15.2)], [0.95, 0.65], 6)
    tube(wood, [(3.6, 0, 2.2), (-3.4, 0, 15.2)], [0.95, 0.65], 6)
    ring_mesh(wood, 3.2, 0.55, 14, M((0, 0, 9.6), rot=(math.pi / 2, 0, 0)), tube_segs=5)
    # Pale Band wound around the crossing & glowing warden offering lantern at the foot.
    pale_band_wrap(silk, 1.9, 8.8, height=1.2, segs=10, tail=True, tail_ang=-1.5)
    uvsphere(candle, 1.05, M((0, -2.4, 4.6), scale=(0.9, 0.9, 1.2)), u=8, v=6)


DEFAULT_BUDGET = 1200


def build_kit():
    reset_scene()
    kit = bpy.data.collections.new("CorruptedF35Kit")
    bpy.context.scene.collection.children.link(kit)
    manifest = {}
    for name, (fn, budget) in F35_TEMPLATES.items():
        coll = bpy.data.collections.new(name)
        kit.children.link(coll)
        t = Template(name)
        fn(t)
        roles = {}
        lo = Vector((1e9, 1e9, 1e9))
        hi = Vector((-1e9, -1e9, -1e9))
        for role, bm in t.meshes.items():
            if len(bm.verts) == 0:
                bm.free()
                continue
            obj, tris = finalize(name, role, bm, budget.get(role, DEFAULT_BUDGET), coll)
            for v in obj.data.vertices:
                lo = Vector((min(lo.x, v.co.x), min(lo.y, v.co.y), min(lo.z, v.co.z)))
                hi = Vector((max(hi.x, v.co.x), max(hi.y, v.co.y), max(hi.z, v.co.z)))
            roles[role] = tris
        manifest[name] = {
            "Roles": roles,
            "Triangles": sum(roles.values()),
            "Size": [round(hi.x - lo.x, 3), round(hi.z - lo.z, 3), round(hi.y - lo.y, 3)],
            "Min": [round(lo.x, 3), round(lo.z, 3), round(-hi.y, 3)],
        }
    return kit, manifest


def export_kit(kit, manifest):
    os.makedirs(OUT_DIR, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    objs = [o for o in kit.all_objects if o.type == "MESH"]
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.fbx(
        filepath=os.path.join(OUT_DIR, "CorruptedF35Kit.fbx"),
        use_selection=True,
        apply_scale_options="FBX_SCALE_ALL",
        axis_forward="-Z",
        axis_up="Y",
        mesh_smooth_type="FACE",
        add_leaf_bones=False,
        bake_anim=False,
        use_mesh_modifiers=True,
        bake_space_transform=True,
        object_types={"MESH"},
    )
    with open(os.path.join(OUT_DIR, "manifest.json"), "w") as f:
        json.dump({"Templates": manifest, "Unit": "studs", "Front": "-Y in Blender, +Z in Roblox"}, f, indent=2, sort_keys=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT_DIR, "CorruptedF35Kit.blend"))


if __name__ == "__main__":
    kit, manifest = build_kit()
    export_kit(kit, manifest)
    preview_dir = os.path.join(OUT_DIR, "previews")
    render_previews(kit, preview_dir, list(F35_TEMPLATES.keys()), tile=520, cols=4)
    print(json.dumps(manifest, indent=2))
