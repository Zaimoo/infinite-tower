"""
Frozen Citadel Floor 20 (Frostbound Throne) sculpted assets, generated in headless Blender
inspired by media_1795022995025_d8a1e5e6.jpg (ruined gothic throne cathedral: rows of kneeling
knights frozen in ice, colossal iron-banded cathedral colonnade pillars with icicle capitals,
crystalline blue-fire braziers, the Frostbound King on the Throne of Icicles with glowing Stillheart,
the frozen avalanche wave bursting behind the apse, shattered stained-glass rose windows,
Glacial Urn shrines, and the caged Permafrost Core).

1 Blender unit = 1 stud, standing on z = 0 (with -0.5..-1.2 footing), front facing -Y in Blender / +Z in Roblox,
one mesh object per colour role named "<Template>__<ROLE>".

Outputs (assets-source/tower/frozen_f20_kit/):
    FrozenF20Kit.blend    the generated scene
    FrozenF20Kit.fbx      FBX for File > Import 3D in Studio
    manifest.json         per template: roles, reference size, triangle counts
    previews/             Workbench contact-sheet render of the Floor 20 templates
"""
import bpy, bmesh, math, os, json, runpy
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT_DIR = os.path.join(ROOT, "assets-source", "tower", "frozen_f20_kit")

kit_mod = runpy.run_path(os.path.join(HERE, "generate_tower_biome_kit.py"), init_globals={"RUN_KIT": False})

Template = kit_mod["Template"]
box = kit_mod["box"]
cone = kit_mod["cone"]
uvsphere = kit_mod["uvsphere"]
rock = kit_mod["rock"]
reset_scene = kit_mod["reset_scene"]
finalize = kit_mod["finalize"]


def rock_clean(bm, size, mat, seed, roughness=0.22, subdiv=2, flat_bottom=True):
    tmp = bmesh.new()
    rock(tmp, size, mat, seed, roughness=roughness, subdiv=subdiv, flat_bottom=flat_bottom)
    vmap = [bm.verts.new(v.co) for v in tmp.verts]
    for f in tmp.faces:
        bm.faces.new([vmap[v.index] for v in f.verts])
    tmp.free()


def tapered_limb(bm, p0, p1, r0, r1, segs=7):
    d = Vector(p1) - Vector(p0)
    length = d.length
    if length < 1e-4:
        return
    q = d.normalized().to_track_quat("Z", "Y")
    mat = Matrix.Translation(p0) @ q.to_matrix().to_4x4()
    cone(bm, r0, r1, length, segs, mat)


DEFAULT_BUDGET = 3500
F20_TEMPLATES = {}


def template(name, **budget):
    def deco(fn):
        F20_TEMPLATES[name] = (fn, budget)
        return fn
    return deco


@template("KneelingKnight", STONE=900, METAL=800, MOSS=450, CRYSTAL=850, GLOW=120)
def kneeling_knight(t):
    """Whiteguard knight kneeling in prayer over a greatsword, encased in jagged glacier ice and drifted snow."""
    stone, metal, moss, crystal, glow = t.bm("STONE"), t.bm("METAL"), t.bm("MOSS"), t.bm("CRYSTAL"), t.bm("GLOW")

    # Frosted carved stone kneeling flagstone plinth (footing -0.6)
    rock_clean(stone, (5.2, 6.2, 1.2), Matrix.Translation((0.0, 0.2, 0.0)), seed=201, roughness=0.14)
    rock_clean(moss, (5.6, 6.6, 0.7), Matrix.Translation((0.0, 0.2, 0.3)), seed=202, roughness=0.18)

    # Lower kneeling armored legs: right knee on floor (+0.9 X), left knee bent forward (-0.9 X)
    tapered_limb(metal, (0.9, 1.5, 0.3), (0.85, 0.2, 2.5), 0.72, 0.65, segs=7)
    tapered_limb(metal, (0.9, 1.4, 0.4), (1.0, 2.8, 0.6), 0.62, 0.50, segs=7)
    tapered_limb(metal, (-0.9, -0.8, 0.2), (-0.95, -0.7, 2.5), 0.68, 0.60, segs=7)
    tapered_limb(metal, (-0.95, -0.7, 2.5), (-0.85, 0.8, 2.7), 0.65, 0.60, segs=7)

    # Heavy fluted breastplate torso leaning slightly forward toward -Y & fur-trimmed armored cloak
    box(metal, (3.2, 2.2, 3.6), Matrix.Translation((0.0, 0.4, 4.3)) @ Matrix.Rotation(math.radians(-16), 4, "X"))
    tapered_limb(stone, (0.0, 1.5, 4.6), (0.0, 2.1, 0.5), 1.4, 2.2, segs=7)  # Frosted heavy cloak pooling to floor
    # Wide knight pauldrons & bowed helmeted head
    for sx in (-1.85, 1.85):
        uvsphere(metal, 1.1, Matrix.Translation((sx, 0.2, 5.7)) @ Matrix.Scale(1.1, 4, Vector((1.0, 0.9, 0.8))), u=8, v=6)
        rock_clean(moss, (2.2, 1.9, 0.8), Matrix.Translation((sx, 0.2, 6.5)), seed=210 + int(sx), roughness=0.15)
    uvsphere(metal, 1.05, Matrix.Translation((0.0, -0.35, 7.2)) @ Matrix.Rotation(math.radians(-22), 4, "X"), u=8, v=6)
    # Faint frosted eye slit / visor glint
    box(glow, (1.1, 0.35, 0.28), Matrix.Translation((0.0, -1.25, 7.05)))

    # Gauntleted arms gripping planted upright greatsword hilt at -Y front
    for sx in (-1.75, 1.75):
        tapered_limb(metal, (sx, 0.0, 5.4), (sx * 0.45, -1.65, 4.55), 0.55, 0.42, segs=6)
    box(metal, (0.34, 0.42, 4.8), Matrix.Translation((0.0, -1.85, 2.5)))  # Blade planted in stone
    box(metal, (2.4, 0.45, 0.36), Matrix.Translation((0.0, -1.85, 4.9)))  # Crossguard
    box(metal, (0.32, 0.32, 1.15), Matrix.Translation((0.0, -1.85, 5.6)))  # Grip & pommel

    # Translucent glacier-ice shroud & jagged ice spikes locking the knight in time
    cone(crystal, 2.8, 1.6, 5.8, 7, Matrix.Translation((0.0, 0.3, 0.4)))
    for sp0, sp1, r0 in (
        ((1.5, 1.0, 0.2), (2.7, 1.6, 6.4), 0.72),
        ((-1.6, 0.9, 0.2), (-2.6, 1.5, 5.6), 0.65),
        ((0.4, -1.9, 0.3), (0.7, -2.5, 3.8), 0.55),
    ):
        tapered_limb(crystal, sp0, sp1, r0, 0.08, segs=5)


@template("GothicPillarColonnade", STONE=1400, METAL=350, MOSS=550, CRYSTAL=650, GLOW=160)
def gothic_pillar_colonnade(t):
    """Monumental iron-banded granite cathedral column with icicle capital, snowdrifts, and hanging rimelight crystal."""
    stone, metal, moss, crystal, glow = t.bm("STONE"), t.bm("METAL"), t.bm("MOSS"), t.bm("CRYSTAL"), t.bm("GLOW")

    # Massive octagonal stepped plinth & snow drift apron (footing -1.0)
    box(stone, (9.6, 9.6, 4.2), Matrix.Translation((0.0, 0.0, 1.1)))
    cone(stone, 5.6, 4.4, 4.0, 8, Matrix.Translation((0.0, 0.0, 3.2)))
    rock_clean(moss, (10.6, 10.2, 2.2), Matrix.Translation((0.0, 0.6, 1.8)), seed=221, roughness=0.20)

    # Tall octagonal cathedral pier shaft & 4 bundled gothic colonnette ribs
    cone(stone, 3.8, 3.6, 30.0, 8, Matrix.Translation((0.0, 0.0, 7.0)))
    for ang in (0.0, math.pi * 0.5, math.pi, -math.pi * 0.5):
        cx, cy = math.cos(ang) * 3.55, math.sin(ang) * 3.55
        cone(stone, 0.85, 0.82, 30.0, 6, Matrix.Translation((cx, cy, 7.0)))

    # Three riveted wrought-iron binding bands wrapping the granite shaft
    for bz in (13.5, 22.5, 31.5):
        cone(metal, 4.35, 4.35, 1.15, 8, Matrix.Translation((0.0, 0.0, bz)))

    # Flared gothic capital, abacus block, broken vault springer ribs, and heavy snow cap
    cone(stone, 3.8, 5.8, 5.4, 8, Matrix.Translation((0.0, 0.0, 36.8)))
    box(stone, (10.8, 10.8, 2.6), Matrix.Translation((0.0, 0.0, 42.6)))
    box(stone, (12.0, 3.6, 4.5), Matrix.Translation((0.0, 0.0, 45.2)))
    rock_clean(moss, (11.4, 11.4, 2.0), Matrix.Translation((0.0, 0.0, 46.2)), seed=229, roughness=0.18)

    # Thick icicle beard dripping around the flared capital
    for i in range(12):
        ang = i * (math.pi / 6.0)
        ix, iy = math.cos(ang) * 5.2, math.sin(ang) * 5.2
        tapered_limb(crystal, (ix, iy, 41.8), (ix, iy, 34.5 - (i % 3) * 1.8), 0.45, 0.05, segs=5)

    # Iron sconce bracket & dangling glowing cyan rimelight shard
    tapered_limb(metal, (0.0, -3.5, 26.5), (0.0, -5.6, 26.5), 0.25, 0.16, segs=5)
    tapered_limb(glow, (0.0, -5.6, 26.2), (0.0, -5.6, 22.8), 0.65, 0.08, segs=5)
    tapered_limb(glow, (0.0, -5.6, 26.2), (0.0, -5.6, 27.6), 0.65, 0.08, segs=5)


@template("IceCrystalBrazier", METAL=650, STONE=400, MOSS=300, CRYSTAL=450, GLOW=450)
def ice_crystal_brazier(t):
    """Spiked wrought-iron cathedral floor brazier brimming with glowing blue rimelight crystal shards."""
    metal, stone, moss, crystal, glow = t.bm("METAL"), t.bm("STONE"), t.bm("MOSS"), t.bm("CRYSTAL"), t.bm("GLOW")

    # Stepped octagonal granite hearth ring (footing -0.4)
    cone(stone, 3.8, 3.3, 1.1, 8, Matrix.Translation((0.0, 0.0, -0.4)))
    rock_clean(moss, (7.2, 7.2, 0.9), Matrix.Translation((0.0, 0.2, 0.4)), seed=241, roughness=0.18)

    # 4 splayed iron dragon-leg supports & heavy riveted bowl
    for i in range(4):
        ang = i * (math.pi * 0.5) + math.pi * 0.25
        lx, ly = math.cos(ang), math.sin(ang)
        tapered_limb(metal, (lx * 3.1, ly * 3.1, 0.4), (lx * 1.9, ly * 1.9, 2.4), 0.35, 0.28, segs=6)
    cone(metal, 1.6, 3.4, 2.2, 10, Matrix.Translation((0.0, 0.0, 1.6)))
    cone(metal, 3.5, 3.2, 0.7, 10, Matrix.Translation((0.0, 0.0, 3.7)))
    # Gothic perimeter spikes cradling the crystal fire
    for i in range(8):
        ang = i * (math.pi / 4.0)
        sx, sy = math.cos(ang) * 3.15, math.sin(ang) * 3.15
        tapered_limb(metal, (sx, sy, 3.6), (sx * 1.12, sy * 1.12, 5.4), 0.22, 0.04, segs=4)

    # Radiating cyan Rimelight & pale glacier-ice crystal cluster rising like frozen flames
    for cx, cy, hgt, r0 in (
        (0.0, 0.0, 4.6, 0.75),
        (-0.85, -0.5, 3.5, 0.55),
        (0.9, 0.4, 3.8, 0.58),
        (-0.5, 0.95, 3.2, 0.50),
        (0.6, -0.95, 3.1, 0.48),
    ):
        tapered_limb(glow, (cx * 0.4, cy * 0.4, 3.5), (cx * 1.4, cy * 1.4, 3.5 + hgt), r0, 0.06, segs=5)
    for cx, cy, hgt in ((-1.5, 0.2, 2.6), (1.45, -0.35, 2.7), (0.15, 1.5, 2.5)):
        tapered_limb(crystal, (cx * 0.5, cy * 0.5, 3.6), (cx * 1.45, cy * 1.45, 3.6 + hgt), 0.42, 0.05, segs=5)


@template("ThroneOfIcicles", STONE=1600, METAL=500, MOSS=550, CRYSTAL=1100, GLOW=320)
def throne_of_icicles(t):
    """Colossal Frostbound King enthroned on a jagged gothic seat of stone and icicles, Stillheart blazing in his chest."""
    stone, metal, moss, crystal, glow = t.bm("STONE"), t.bm("METAL"), t.bm("MOSS"), t.bm("CRYSTAL"), t.bm("GLOW")

    # Grand tiered royal throne plinth (footing -1.0)
    box(stone, (22.0, 18.0, 3.6), Matrix.Translation((0.0, 0.0, 0.8)))
    box(stone, (16.5, 13.5, 2.8), Matrix.Translation((0.0, 0.5, 3.8)))
    rock_clean(moss, (23.0, 19.0, 2.0), Matrix.Translation((0.0, -0.6, 1.6)), seed=251, roughness=0.20)

    # Heavy granite throne seat, massive sculpted armrests, and soaring gothic spire seat-back
    box(stone, (12.0, 9.5, 4.8), Matrix.Translation((0.0, 0.8, 7.2)))
    for sx in (-6.0, 6.0):
        box(stone, (2.6, 10.5, 7.2), Matrix.Translation((sx, 0.8, 8.8)))
        box(stone, (3.2, 2.8, 32.0), Matrix.Translation((sx, 4.8, 20.0)))
        tapered_limb(crystal, (sx, 5.2, 35.5), (sx, 5.2, 42.5), 1.45, 0.14, segs=6)
    box(stone, (10.5, 3.2, 27.5), Matrix.Translation((0.0, 4.8, 18.5)))
    # Pointed central gable spire crest & jagged ice crown
    tapered_limb(stone, (0.0, 4.8, 32.0), (0.0, 4.8, 39.5), 4.5, 0.5, segs=4)
    for ix, hgt in ((-3.4, 37.5), (-1.7, 40.5), (0.0, 43.0), (1.7, 40.5), (3.4, 37.5)):
        tapered_limb(crystal, (ix, 5.0, 31.0), (ix, 4.4, hgt), 1.05, 0.10, segs=5)

    # Colossal Frostbound King seated: armored greaves, torso, royal helm/crown, greatsword & Stillheart glow
    for sx in (-2.4, 2.4):
        tapered_limb(metal, (sx, -0.4, 9.2), (sx * 1.08, -3.8, 5.6), 1.45, 1.15, segs=7)
    box(metal, (7.4, 5.2, 8.2), Matrix.Translation((0.0, 1.0, 13.5)))
    for sx in (-4.4, 4.4):
        uvsphere(metal, 2.35, Matrix.Translation((sx, 0.6, 16.5)) @ Matrix.Scale(1.1, 4, Vector((1.0, 0.9, 0.8))), u=8, v=6)
        rock_clean(moss, (4.2, 3.8, 1.2), Matrix.Translation((sx, 0.6, 18.2)), seed=260 + int(sx), roughness=0.18)
        tapered_limb(metal, (sx, 0.4, 15.8), (sx * 1.12, -2.5, 12.2), 1.05, 0.85, segs=6)
    uvsphere(metal, 2.15, Matrix.Translation((0.0, 0.4, 19.6)), u=8, v=6)
    cone(crystal, 2.3, 2.6, 2.2, 7, Matrix.Translation((0.0, 0.4, 21.0)))  # Ice crown
    # King's vertical greatsword between knees
    box(metal, (0.72, 0.85, 10.5), Matrix.Translation((0.0, -3.5, 10.5)))
    box(metal, (4.4, 0.9, 0.75), Matrix.Translation((0.0, -3.5, 15.0)))

    # Glowing faceted Stillheart pulsing cleanly inside chest cavity
    uvsphere(glow, 1.65, Matrix.Translation((0.0, -1.75, 14.2)) @ Matrix.Scale(0.75, 4, Vector((1.0, 0.6, 1.2))), u=6, v=4)
    # Ice pillars fusing throne into mountain snow
    for sx in (-8.4, 8.4):
        tapered_limb(crystal, (sx, 4.5, 1.0), (sx * 0.85, 4.0, 26.0), 2.4, 0.75, segs=6)


@template("FrozenAvalancheWave", MOSS=1400, CRYSTAL=1300, STONE=700)
def frozen_avalanche_wave(t):
    """Colossal frozen tidal cascade of crested glacier waves, snowbanks, and tumbled ruin boulders behind the throne."""
    moss, crystal, stone = t.bm("MOSS"), t.bm("CRYSTAL"), t.bm("STONE")

    # Stepped rocky cascade shelf anchored at z=-1.2
    box(stone, (58.0, 20.0, 3.2), Matrix.Translation((0.0, 3.5, 0.4)))
    for sx, wd, hgt in ((-20.0, 24.0, 16.0), (0.0, 32.0, 22.0), (20.0, 24.0, 15.0)):
        rock_clean(stone, (wd, 20.0, hgt), Matrix.Translation((sx, 4.0, hgt * 0.30 - 1.6)), seed=271 + int(sx), roughness=0.26)
        rock_clean(moss, (wd + 3.0, 22.0, hgt * 0.65), Matrix.Translation((sx, -1.0, hgt * 0.45)), seed=280 + int(sx), roughness=0.22)

    # Towering curling ice wave crest plunging forward (-Y) over the shelf without extending too far past front
    for idx, (cx, y_off, z_top, tilt, rad) in enumerate((
        (-22.0, -2.5, 36.0, 28, 5.2),
        (-11.0, -4.0, 44.0, 34, 6.2),
        (0.0, -5.0, 50.0, 38, 7.0),
        (11.0, -4.0, 43.0, 33, 6.0),
        (22.0, -2.5, 35.0, 27, 5.0),
    )):
        tapered_limb(crystal, (cx, 6.0, 2.0), (cx, y_off, z_top), rad, rad * 0.22, segs=7)
        rock_clean(moss, (14.5, 12.0, 8.5), Matrix.Translation((cx, y_off + 2.5, z_top * 0.76)) @ Matrix.Rotation(math.radians(tilt), 4, "X"), seed=290 + idx, roughness=0.24)
        # Curling ice wave spray prongs leaping down at -Y crest
        tapered_limb(crystal, (cx, y_off, z_top * 0.85), (cx + math.sin(idx) * 2.5, y_off - 7.5, z_top * 0.58), rad * 0.48, 0.25, segs=6)


@template("ShatteredRoseWindow", STONE=1100, MOSS=350, CRYSTAL=600, GLOW=220)
def shattered_rose_window(t):
    """Tall pointed gothic stone window arch with radial wheel-tracery mullions and shattered glacier-glass panes."""
    stone, moss, crystal, glow = t.bm("STONE"), t.bm("MOSS"), t.bm("CRYSTAL"), t.bm("GLOW")

    # Heavy window wall jambs & snow-crusted sill (footing -0.8)
    box(stone, (22.0, 6.0, 4.0), Matrix.Translation((0.0, 0.0, 1.2)))
    rock_clean(moss, (22.6, 7.0, 1.6), Matrix.Translation((0.0, -0.5, 3.4)), seed=301, roughness=0.18)
    for sx in (-8.5, 8.5):
        box(stone, (4.8, 5.8, 28.0), Matrix.Translation((sx, 0.0, 17.0)))
        tapered_limb(stone, (sx, 0.0, 30.0), (0.0, 0.0, 39.5), 2.5, 1.9, segs=6)
    rock_clean(moss, (18.0, 6.5, 2.2), Matrix.Translation((0.0, 0.0, 38.5)), seed=305, roughness=0.20)

    # Outer stone rose tracery ring + radial broken spokes
    for i in range(12):
        ang = i * (math.pi / 6.0)
        rx, rz = math.cos(ang) * 6.4, 21.5 + math.sin(ang) * 6.4
        box(stone, (1.4, 2.6, 3.6), Matrix.Translation((rx, 0.0, rz)) @ Matrix.Rotation(-ang, 4, "Y"))
        if i % 3 != 1:  # Leave 4 radial spokes jaggedly shattered
            tapered_limb(stone, (0.0, 0.0, 21.5), (rx * 0.92, 0.0, 21.5 + math.sin(ang) * 5.9), 0.35, 0.25, segs=4)

    # Jagged shards of ice-glazed stained glass & bright moonlit cyan glow core
    for i in range(8):
        ang = i * (math.pi / 4.0) + 0.2
        gx, gz = math.cos(ang) * 4.2, 21.5 + math.sin(ang) * 4.2
        tapered_limb(crystal, (gx, 0.0, gz), (gx * 0.25, 0.0, 21.5 + math.sin(ang) * 1.4), 1.65, 0.12, segs=4)
    uvsphere(glow, 1.6, Matrix.Translation((0.0, 0.0, 21.5)) @ Matrix.Scale(0.35, 4, Vector((1.0, 0.4, 1.0))), u=6, v=4)
    for ix in (-4.5, -1.5, 2.0, 5.0):
        tapered_limb(crystal, (ix, -1.2, 34.5), (ix, -1.2, 29.0 - (abs(int(ix)) % 3)), 0.38, 0.04, segs=5)


@template("GlacialUrnShrine", STONE=600, METAL=350, MOSS=300, CRYSTAL=350, GLOW=280)
def glacial_urn_shrine(t):
    """Carved granite pedestal holding a monumental Whiteguard Glacial Urn with runes frozen mid-glow."""
    stone, metal, moss, crystal, glow = t.bm("STONE"), t.bm("METAL"), t.bm("MOSS"), t.bm("CRYSTAL"), t.bm("GLOW")

    # Carved octagonal chapel pedestal (footing -0.5)
    cone(stone, 4.2, 3.6, 1.6, 8, Matrix.Translation((0.0, 0.0, -0.5)))
    cone(stone, 2.8, 2.6, 4.0, 8, Matrix.Translation((0.0, 0.0, 1.1)))
    cone(stone, 3.4, 3.8, 1.2, 8, Matrix.Translation((0.0, 0.0, 5.1)))
    rock_clean(moss, (6.4, 6.4, 1.0), Matrix.Translation((0.0, 0.0, 0.6)), seed=311, roughness=0.18)

    # Tall amphora urn body + iron binding collars + glowing cyan rune bands
    cone(stone, 1.9, 3.0, 3.4, 10, Matrix.Translation((0.0, 0.0, 6.2)))
    cone(stone, 3.0, 1.8, 2.8, 10, Matrix.Translation((0.0, 0.0, 9.6)))
    cone(metal, 3.15, 3.15, 0.7, 10, Matrix.Translation((0.0, 0.0, 9.2)))
    cone(glow, 2.65, 2.95, 0.9, 10, Matrix.Translation((0.0, 0.0, 8.0)))
    # Lid finial + frosted crystal halo
    cone(stone, 2.2, 0.6, 1.8, 10, Matrix.Translation((0.0, 0.0, 12.4)))
    for i in range(4):
        ang = i * (math.pi * 0.5)
        tapered_limb(crystal, (math.cos(ang) * 2.5, math.sin(ang) * 2.5, 6.2), (math.cos(ang) * 3.1, math.sin(ang) * 3.1, 10.2), 0.35, 0.05, segs=4)


@template("PermafrostCage", METAL=900, STONE=450, MOSS=300, CRYSTAL=550, GLOW=380)
def permafrost_cage(t):
    """Wrought-iron gothic reliquary cage suspending the glowing faceted Permafrost Core crystal."""
    metal, stone, moss, crystal, glow = t.bm("METAL"), t.bm("STONE"), t.bm("MOSS"), t.bm("CRYSTAL"), t.bm("GLOW")

    # Stepped octagonal chapel shrine plinth (footing -0.6)
    cone(stone, 5.4, 4.8, 1.8, 8, Matrix.Translation((0.0, 0.0, -0.6)))
    cone(stone, 4.2, 4.0, 2.2, 8, Matrix.Translation((0.0, 0.0, 1.2)))
    rock_clean(moss, (8.2, 8.2, 1.0), Matrix.Translation((0.0, 0.0, 3.3)), seed=321, roughness=0.20)

    # 8 upright wrought-iron cage bars rising to a pointed iron reliquary spire crown
    cone(metal, 3.6, 3.6, 0.75, 8, Matrix.Translation((0.0, 0.0, 3.4)))
    cone(metal, 3.6, 3.6, 0.75, 8, Matrix.Translation((0.0, 0.0, 13.8)))
    for i in range(8):
        ang = i * (math.pi / 4.0)
        bx, by = math.cos(ang) * 3.25, math.sin(ang) * 3.25
        tapered_limb(metal, (bx, by, 3.6), (bx, by, 14.0), 0.24, 0.24, segs=6)
        tapered_limb(metal, (bx, by, 14.2), (0.0, 0.0, 19.8), 0.22, 0.10, segs=5)
    tapered_limb(metal, (0.0, 0.0, 19.6), (0.0, 0.0, 22.8), 0.26, 0.05, segs=6)

    # Suspended faceted glowing Permafrost Core encased in translucent crystal spikes inside the iron bars
    tapered_limb(glow, (0.0, 0.0, 8.8), (0.0, 0.0, 13.0), 1.95, 0.22, segs=6)
    tapered_limb(glow, (0.0, 0.0, 8.8), (0.0, 0.0, 4.8), 1.95, 0.22, segs=6)
    for i in range(6):
        ang = i * (math.pi / 3.0)
        tapered_limb(crystal, (0.0, 0.0, 8.8), (math.cos(ang) * 2.5, math.sin(ang) * 2.5, 8.8 + ((i % 2) * 2 - 1) * 1.4), 0.55, 0.06, segs=5)


def build_f20():
    reset_scene()

    kit = bpy.data.collections.new("FrozenF20Kit")
    bpy.context.scene.collection.children.link(kit)
    manifest = {}
    for name, (fn, budget) in F20_TEMPLATES.items():
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


def export_f20(kit, manifest):
    os.makedirs(OUT_DIR, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    objs = [o for o in kit.all_objects if o.type == "MESH"]
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.fbx(
        filepath=os.path.join(OUT_DIR, "FrozenF20Kit.fbx"),
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
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT_DIR, "FrozenF20Kit.blend"))


if __name__ == "__main__":
    kit, manifest = build_f20()
    export_f20(kit, manifest)
    preview_dir = os.path.join(OUT_DIR, "previews")
    tiles = os.path.join(preview_dir, "tiles")
    os.makedirs(tiles, exist_ok=True)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.color_type = "MATERIAL"
    lc = next(c for c in bpy.context.view_layer.layer_collection.children if c.collection == kit)
    lc.exclude = False
    stage = bpy.data.collections.new("PreviewStage")
    scene.collection.children.link(stage)
    cam = bpy.data.objects.new("PreviewCam", bpy.data.cameras.new("PreviewCam"))
    stage.objects.link(cam)
    scene.camera = cam
    scene.render.resolution_x = scene.render.resolution_y = 320
    all_kit_objs = [o for o in kit.all_objects if o.type == "MESH"]
    for o in all_kit_objs:
        o.hide_render = True
    tile_imgs = []
    for n in F20_TEMPLATES:
        c = bpy.data.collections[n]
        lo = Vector((1e9,) * 3)
        hi = Vector((-1e9,) * 3)
        for o in c.objects:
            o.hide_render = False
            for v in o.data.vertices:
                lo = Vector(map(min, lo, v.co))
                hi = Vector(map(max, hi, v.co))
        size = max(hi - lo)
        ctr = (lo + hi) / 2
        cam.location = ctr + Vector((0.55, -1.0, 0.42)).normalized() * size * 1.9
        cam.rotation_euler = (ctr - cam.location).to_track_quat("-Z", "Y").to_euler()
        p_path = os.path.join(tiles, n + ".png")
        scene.render.filepath = p_path
        bpy.ops.render.render(write_still=True)
        for o in c.objects:
            o.hide_render = True
        tile_imgs.append(bpy.data.images.load(p_path))
    import numpy as np
    n_templates = len(F20_TEMPLATES)
    sheet = bpy.data.images.new("PreviewSheet", width=320 * n_templates, height=320, alpha=True)
    buf = np.zeros((320, 320 * n_templates, 4), dtype=np.float32)
    for idx, img in enumerate(tile_imgs):
        arr = np.asarray(img.pixels[:], dtype=np.float32).reshape(320, 320, 4)
        buf[:, idx * 320:(idx + 1) * 320, :] = arr
        bpy.data.images.remove(img)
    sheet.pixels.foreach_set(buf.ravel())
    sheet.filepath_raw = os.path.join(preview_dir, "kit_sheet_1.png")
    sheet.file_format = "PNG"
    sheet.save()
    bpy.data.images.remove(sheet)
    print(json.dumps(manifest, indent=2))
