"""
Corrupted Grove Floor 34 (Heartrot Stronghold) sculpted assets, generated in headless Blender.

Follows docs/prompts/corrupted-grove-floor-layouts-prompt.md (Floor 34):
the Hollin wardens' last refuge built into five colossal elder trunks rising from a deeply corrupted
violet-black rot bog, climbing tree-to-tree on bracket decks and branch bridges to the Heartrot Crown
in the fork of the Great Rotwood at the back-west.

Templates (14):
  GreatRotwoodCavity    colossal split elder trunk (~74 x 150 x 70; 1.25x -> 187.5 studs) with blazing magenta cavity & Pale Band
  ElderTrunkRootFlare   gnarled buttress root-plate base emerging from the bog with glowing magenta sap fissures
  ElderTrunkBoleA       split, rot-veined elder trunk column wrapped in Pale Bands and iron climbing pegs
  ElderTrunkBoleB       hollowed elder trunk column crusted with purple-magenta shelf fungi and glowing cracks
  ElderTrunkFork        wide twisted elder canopy crown fork with gnarled boughs and hanging moss curtains
  TreehouseKeep         Hollin wardens' timber-and-shingle treehouse keep with torn roof, arrow slits and banners
  ShelfFungusBracket    massive layered glowing-gilled shelf fungus bracket jutting from a trunk (used at 2 scales)
  SapTapCistern         wooden sap-tap spout pouring glowing magenta sap into a cooperage cistern tub and buckets
  SeedJarStack          hollow limb cradle stacked with glowing sealed seed jars, one central jar caged in black thorns
  StakePalisadeSegment  sharpened timber bog-palisade wall lashed with vines, Pale Bands and magenta briars
  StiltHut              Mender's Ward rickety stilt hut with woven roof, warm lantern and stilts into the bog
  WeepingGallowsTree    sombre gnarled dead gallows tree hung with Pale-Band-wrapped ropes over the bog
  SunkenWardenBoat      half-sunk weathered Hollin skiff tilted in the bog with oar and glowing rot-lilies
  BranchBridgeHanger    carved timber crane-arm hanger with hanging moss curtain and warm sap-lantern

Reuses `tools/blender/generate_tower_biome_kit.py` helpers and existing colour roles only:
WOOD, TRIM, ALT, FOLIAGE, MOSS, SILK, STONE, GLOW, CANDLE, CAP, CORAL, ACCENT, METAL, STEM.

Run:
    /Applications/Blender.app/Contents/MacOS/Blender --background --python tools/blender/generate_corrupted_f34_kit.py

Outputs (assets-source/tower/corrupted_f34_kit/):
    CorruptedF34Kit.blend    the generated scene
    CorruptedF34Kit.fbx      FBX for File > Import 3D in Studio
    manifest.json            per template: roles, reference size, triangle counts
    previews/                contact-sheet renders
"""
import bpy, bmesh, math, os, json, runpy
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT_DIR = os.path.join(ROOT, "assets-source", "tower", "corrupted_f34_kit")

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
branch_path = kit_mod["branch_path"]
canopy_blob = kit_mod["_canopy_blob"]
reset_scene = kit_mod["reset_scene"]
finalize = kit_mod["finalize"]
render_previews = kit_mod["render_previews"]


def rock_clean(bm, size, mat, seed, roughness=0.22, subdiv=2, flat_bottom=True):
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


def pale_band_wrap(bm, radius, z, height=1.8, segs=12, tail=True, tail_ang=-math.pi / 2):
    """Woven linen Pale Band wrapped around a trunk or post with a hanging knot tail."""
    ring_mesh(bm, radius, height * 0.45, segs, M((0, 0, z)), tube_segs=5)
    ring_mesh(bm, radius * 1.02, height * 0.36, segs, M((0, 0, z + height * 0.4)), tube_segs=5)
    if tail:
        ca, sa = math.cos(tail_ang), math.sin(tail_ang)
        pts = [
            (ca * (radius + 0.3), sa * (radius + 0.3), z),
            (ca * (radius + 0.8), sa * (radius + 0.8), z - height * 1.2),
            (ca * (radius + 1.1), sa * (radius + 1.1), z - height * 2.5),
        ]
        tube(bm, pts, [height * 0.32, height * 0.28, height * 0.14], 4)


def shelf_cap(bm_cap, bm_glow, center, rx, ry, thickness, yaw=0.0):
    """A sculpted semi-circular shelf fungus bracket with glowing underside gills."""
    mat = M(center, rot=(0, 0, yaw))
    # Layered stepped fan cap.
    for layer in range(3):
        f = 1.0 - layer * 0.16
        z_off = layer * thickness * 0.38
        uvsphere(bm_cap, 1.0, mat @ M((0, -ry * 0.32 * f, z_off), scale=(rx * f, ry * f, thickness * 0.42)), u=10, v=6)
    # Glowing gill cushion beneath the main shelf.
    uvsphere(bm_glow, 1.0, mat @ M((0, -ry * 0.30, -thickness * 0.22), scale=(rx * 0.86, ry * 0.82, thickness * 0.24)), u=8, v=5)


def moss_drape(bm, start, length=8.0, width=1.4, sway=0.8, seed=0):
    pts = []
    for i in range(5):
        f = i / 4.0
        pts.append(Vector(start) + Vector((math.sin(seed + f * 3.1) * sway * f, math.cos(seed + f * 2.2) * sway * 0.5 * f, -length * f)))
    tube(bm, pts, [width * 0.55, width * 0.48, width * 0.38, width * 0.24, width * 0.08], 4)


F34_TEMPLATES = {}


def template(name, **budget):
    def deco(fn):
        F34_TEMPLATES[name] = (fn, budget)
        return fn
    return deco


@template("GreatRotwoodCavity", WOOD=4400, GLOW=1200, SILK=600, CAP=700, MOSS=600)
def great_rotwood_cavity(t):
    """The Great Rotwood (~74 x 70 x 150; placed at 1.25x -> 187.5 studs): the colossal split elder
    behind Heartrot Crown with a blazing magenta cavity facing -Y, cradling upper limbs and a giant
    rot-soaked Pale Band wound around its lower bole."""
    wood, glow, silk, cap, moss = t.bm("WOOD"), t.bm("GLOW"), t.bm("SILK"), t.bm("CAP"), t.bm("MOSS")

    # Twin split colossal trunk halves rising from Z 0..146, parted wide at Z 26..86 to expose the heartrot cavity.
    for s in (-1, 1):
        pts, radii = [], []
        for k in range(12):
            f = k / 11.0
            part = s * (6.5 + 6.5 * math.sin(f * math.pi) + 7.0 * (f ** 1.7))
            pts.append(Vector((part + math.sin(f * 5.0 + s) * 1.4, 3.0 + 4.0 * f, f * 144.0)))
            radii.append(12.5 - 7.8 * f)
        tube(wood, pts, radii, 10)

    # Massive buttress root flares anchoring the base (keeping Z >= -1.2!).
    for k in range(8):
        a = k * 2 * math.pi / 8 + 0.15
        ca, sa = math.cos(a), math.sin(a)
        r_out = 26.0 + (k % 2) * 6.0
        pts = [
            Vector((ca * 9.0, sa * 9.0, 26.0)),
            Vector((ca * (r_out * 0.62), sa * (r_out * 0.62), 10.5)),
            Vector((ca * r_out, sa * r_out, 0.2)),
        ]
        tube(wood, pts, [5.8, 3.8, 1.8], 7)

    # Blazing heartrot cavity core & glowing sap veins inside the split (facing -Y).
    uvsphere(glow, 9.8, M((0, -2.0, 56.0), scale=(0.88, 0.55, 2.4)), u=12, v=9)
    for k in range(6):
        a = -math.pi / 2 + (k - 2.5) * 0.36
        tube(
            glow,
            [
                (math.cos(a) * 5.0, math.sin(a) * 4.0 - 1.5, 42.0 + (k % 3) * 10.0),
                (math.cos(a) * 13.0, math.sin(a) * 10.0 - 2.5, 58.0 + (k - 2.5) * 6.0),
                (math.cos(a) * 18.0, math.sin(a) * 12.0 - 3.0, 28.0 + k * 4.0),
            ],
            [1.15, 0.72, 0.32],
            5,
        )

    # Sweeping dead crown limbs arching outward at Z 95..150 (never overhanging the front arena!).
    for idx in range(7):
        a = math.radians(-165 + idx * 52)
        if abs(a + math.pi / 2) < 0.45:
            a += 0.65
        ca, sa = math.cos(a), math.sin(a)
        start_z = 92.0 + (idx % 3) * 16.0
        reach = 26.0 + (idx % 2) * 8.0
        pts = [
            Vector((ca * 7.0, sa * 7.0, start_z)),
            Vector((ca * (reach * 0.58), sa * (reach * 0.58), start_z + 18.0)),
            Vector((ca * reach, sa * reach, start_z + 28.0 + (idx % 2) * 8.0)),
        ]
        tube(wood, pts, [4.6, 2.8, 0.9], 6)
        # Hanging moss curtain off each high limb.
        moss_drape(moss, pts[1] + Vector((0, 0, -1.5)), length=18.0, width=2.4, sway=1.5, seed=idx * 3)

    # Giant rot-soaked Pale Band wound around the lower bole below the cavity.
    pale_band_wrap(silk, 14.5, 24.0, height=4.2, segs=14, tail=True, tail_ang=-math.pi / 2 + 0.3)

    # Giant shelf fungi clustered up the flanks.
    for sx, sy, sz, yaw in [(-15.0, -3.0, 36.0, -0.5), (15.5, -2.0, 48.0, 0.6), (-14.0, 4.0, 74.0, -1.1), (13.0, 5.0, 82.0, 1.0)]:
        shelf_cap(cap, glow, (sx, sy, sz), 6.5, 4.8, 2.2, yaw=yaw)


@template("ElderTrunkRootFlare", WOOD=2200, GLOW=450, MOSS=450, STONE=400)
def elder_trunk_root_flare(t):
    """Gnarled buttress root-plate base (~28 x 28 x 44) emerging from the corrupted rot bog."""
    wood, glow, moss, stone = t.bm("WOOD"), t.bm("GLOW"), t.bm("MOSS"), t.bm("STONE")
    # Flared central base trunk Z 0..44.
    pts = [Vector((0, 0, 0)), Vector((0.6, -0.4, 15.0)), Vector((-0.5, 0.5, 30.0)), Vector((0, 0, 44.0))]
    tube(wood, pts, [9.2, 7.6, 6.8, 6.4], 10)
    # 7 heavy buttress roots plunging into the bog (Z >= -1.0).
    for k in range(7):
        a = k * 2 * math.pi / 7 + 0.2
        ca, sa = math.cos(a), math.sin(a)
        r_out = 12.5 + (k % 2) * 2.2
        rpts = [
            Vector((ca * 5.8, sa * 5.8, 19.0 + (k % 3) * 3.0)),
            Vector((ca * (r_out * 0.68), sa * (r_out * 0.68), 7.2)),
            Vector((ca * r_out, sa * r_out, -0.4)),
        ]
        tube(wood, rpts, [3.4, 2.3, 1.1], 6)
        if k % 2 == 0:
            tube(glow, [rpts[0] + Vector((0, 0, 0.8)), rpts[1] + Vector((0, 0, 0.8)), rpts[2] + Vector((0, 0, 1.0))], [0.55, 0.42, 0.24], 4)
    # Mossy bog-stones wedged between roots.
    for k in range(4):
        a = k * math.pi / 2 + 0.45
        rock_clean(stone, (3.4, 2.8, 2.2), M((math.cos(a) * 9.5, math.sin(a) * 9.5, 0.6), rot=(0, 0, a)), 41 + k)
        canopy_blob(moss, (math.cos(a) * 8.2, math.sin(a) * 8.2, 2.2), (3.0, 2.4, 1.4), 51 + k)


@template("ElderTrunkBoleA", WOOD=2000, SILK=500, GLOW=450, METAL=450)
def elder_trunk_bole_a(t):
    """Split, rot-veined elder trunk column (~20 x 20 x 62) wrapped in Pale Bands and iron climbing pegs."""
    wood, silk, glow, metal = t.bm("WOOD"), t.bm("SILK"), t.bm("GLOW"), t.bm("METAL")
    # Main slightly-twisted elder bole Z 0..62.
    pts = [Vector((0, 0, 0)), Vector((0.8, -0.6, 20.0)), Vector((-0.7, 0.7, 42.0)), Vector((0, 0, 62.0))]
    tube(wood, pts, [6.6, 6.2, 5.9, 5.6], 10)
    # Bark ribs running vertically.
    for k in range(5):
        a = k * 2 * math.pi / 5
        ca, sa = math.cos(a), math.sin(a)
        rpts = [Vector((ca * 6.4, sa * 6.4, 1.0)), Vector((ca * 6.8, sa * 6.8, 30.0)), Vector((ca * 5.8, sa * 5.8, 60.0))]
        tube(wood, rpts, [1.5, 1.4, 1.1], 5)
    # Glowing vertical heartrot fissure along -Y face.
    tube(glow, [(0, -6.4, 8.0), (0.9, -6.5, 31.0), (-0.4, -6.0, 54.0)], [0.65, 1.05, 0.55], 5)
    # Two Pale Bands wound tightly around the trunk.
    pale_band_wrap(silk, 6.9, 18.0, height=2.2, segs=12, tail=True, tail_ang=-1.2)
    pale_band_wrap(silk, 6.4, 44.0, height=2.0, segs=12, tail=True, tail_ang=2.1)
    # Forged iron climbing pegs & bracket cleats spiralling up the bark.
    for i in range(10):
        z = 5.0 + i * 5.4
        a = i * 0.52
        box(metal, (3.0, 0.55, 0.45), M((math.cos(a) * 6.7, math.sin(a) * 6.7, z), rot=(0, 0, a)))


@template("ElderTrunkBoleB", WOOD=1800, CAP=900, GLOW=500, MOSS=450)
def elder_trunk_bole_b(t):
    """Hollowed elder trunk column (~24 x 24 x 62) crusted with purple-magenta shelf fungi and glowing cracks."""
    wood, cap, glow, moss = t.bm("WOOD"), t.bm("CAP"), t.bm("GLOW"), t.bm("MOSS")
    pts = [Vector((0, 0, 0)), Vector((-0.9, 0.5, 22.0)), Vector((0.8, -0.6, 44.0)), Vector((0, 0, 62.0))]
    tube(wood, pts, [6.8, 6.3, 6.0, 5.6], 10)
    # Glowing hollow knot eye facing -Y.
    uvsphere(glow, 3.2, M((0, -5.8, 30.0), scale=(0.85, 0.45, 1.9)), u=9, v=7)
    # 5 stepped shelf-fungus brackets erupting around the bole.
    for idx, (ang, z, rx) in enumerate([(-0.4, 14.0, 5.4), (1.3, 24.0, 4.8), (-2.1, 35.0, 5.6), (0.6, 46.0, 4.5), (-1.1, 54.0, 4.2)]):
        ca, sa = math.cos(ang), math.sin(ang)
        shelf_cap(cap, glow, (ca * 6.4, sa * 6.4, z), rx, rx * 0.72, 1.8, yaw=ang + math.pi / 2)
    # Hanging moss clumps.
    for k in range(4):
        a = k * math.pi / 2 + 0.5
        moss_drape(moss, (math.cos(a) * 6.6, math.sin(a) * 6.6, 48.0 - k * 6.0), length=10.0, width=1.4, seed=k * 5)


@template("ElderTrunkFork", WOOD=2400, FOLIAGE=900, MOSS=800, GLOW=400)
def elder_trunk_fork(t):
    """Wide twisted elder canopy crown fork (~48 x 42 x 46) with gnarled boughs and hanging moss curtains."""
    wood, foliage, moss, glow = t.bm("WOOD"), t.bm("FOLIAGE"), t.bm("MOSS"), t.bm("GLOW")
    # Short crown stem Z 0..14 splitting into 5 sweeping boughs.
    tube(wood, [(0, 0, 0), (0, 0, 14.0)], [6.0, 5.4], 9)
    for k in range(5):
        a = k * 2 * math.pi / 5 + 0.3
        ca, sa = math.cos(a), math.sin(a)
        reach = 19.0 + (k % 2) * 4.5
        top_z = 34.0 + (k % 3) * 5.5
        pts = [
            Vector((ca * 3.0, sa * 3.0, 11.0)),
            Vector((ca * (reach * 0.55), sa * (reach * 0.55), 24.0 + (k % 2) * 3.0)),
            Vector((ca * reach, sa * reach, top_z)),
        ]
        tube(wood, pts, [3.6, 2.3, 0.8], 6)
        # Blighted dark-violet canopy tufts at outer boughs.
        canopy_blob(foliage, pts[2] + Vector((0, 0, 1.8)), (7.2, 6.2, 4.0), 71 + k)
        moss_drape(moss, pts[1] + Vector((0, 0, -1.0)), length=14.0, width=1.8, sway=1.2, seed=k * 4)
        if k % 2 == 0:
            tube(glow, [pts[0] + Vector((0, 0, 0.5)), pts[1] + Vector((0, 0, 0.4))], [0.55, 0.32], 4)


@template("TreehouseKeep", WOOD=2100, ALT=900, TRIM=650, SILK=450, CANDLE=300, GLOW=250)
def treehouse_keep(t):
    """Hollin wardens' timber-and-shingle treehouse keep (~26 x 20 x 25) with torn roof, arrow slits,
    warm lantern window and rot-soaked Pale Band banners."""
    wood, alt, trim, silk, candle, glow = t.bm("WOOD"), t.bm("ALT"), t.bm("TRIM"), t.bm("SILK"), t.bm("CANDLE"), t.bm("GLOW")
    # Heavy bracket foundation & timber floor deck.
    box(wood, (24.0, 18.0, 1.6), M((0, 0, 0.8)))
    for sx in (-9.5, 0, 9.5):
        for sy in (-7.2, 7.2):
            box(wood, (1.4, 1.4, 14.5), M((sx, sy, 8.2)))
    # Slatted timber keep walls with narrow arrow-slit cutouts.
    box(trim, (22.0, 15.6, 12.6), M((0, 0, 7.9)))
    # Dark framed arrow slits & doorway arch on -Y front.
    box(wood, (4.8, 0.8, 7.6), M((0, -7.9, 5.4)))
    for sx in (-6.5, 6.5):
        box(wood, (1.4, 0.8, 3.8), M((sx, -7.9, 9.2)))
        box(candle, (0.9, 0.9, 3.0), M((sx, -7.85, 9.2)))
    # Pitched shingle roof — torn half away on the east side to show battle damage!
    box(alt, (14.5, 11.8, 1.1), M((-4.5, -5.2, 18.2), rot=(0.56, 0, 0)))
    box(alt, (14.5, 11.8, 1.1), M((-4.5, 5.2, 18.2), rot=(-0.56, 0, 0)))
    # Exposed broken rafters on the torn eastern roof half.
    for rx in (3.5, 6.8, 10.0):
        tube(wood, [(rx, -8.8, 14.8), (rx, 0, 21.8), (rx, 8.8, 14.8)], [0.55, 0.55, 0.55], 5)
    # Ridge beam & Pale Band pennants hanging from the eaves.
    box(wood, (24.8, 1.2, 1.2), M((0, 0, 22.0)))
    for sx in (-9.5, 9.5):
        pale_band_wrap(silk, 1.15, 10.5, height=1.2, segs=8, tail=True, tail_ang=-math.pi / 2)
        box(silk, (1.6, 0.3, 5.6), M((sx, -8.4, 11.8)))
    # Creeping magenta briar seam up the western corner.
    tube(glow, [(-11.2, -7.8, 0.5), (-11.6, -4.0, 8.2), (-10.5, -2.0, 15.6)], [0.45, 0.35, 0.22], 4)


@template("ShelfFungusBracket", CAP=1800, GLOW=700, WOOD=500, MOSS=350)
def shelf_fungus_bracket(t):
    """Massive layered glowing-gilled shelf fungus bracket (~26 x 20 x 13) jutting from an elder trunk."""
    cap, glow, wood, moss = t.bm("CAP"), t.bm("GLOW"), t.bm("WOOD"), t.bm("MOSS")
    # Bark attachment spine along +Y edge.
    tube(wood, [(-8.0, 8.2, 2.0), (0, 8.8, 7.5), (8.0, 8.2, 2.0)], [2.2, 2.8, 2.2], 6)
    # Giant primary shelf fan + 3 stepped sub-shelves below it.
    shelf_cap(cap, glow, (0, 6.8, 8.8), 12.6, 13.5, 3.2, yaw=0.0)
    shelf_cap(cap, glow, (-7.2, 6.2, 5.0), 6.8, 7.4, 2.0, yaw=-0.35)
    shelf_cap(cap, glow, (7.4, 6.2, 4.4), 6.4, 7.0, 2.0, yaw=0.35)
    shelf_cap(cap, glow, (0, 6.4, 1.8), 5.8, 6.2, 1.8, yaw=0.05)
    canopy_blob(moss, (-3.0, 4.5, 10.4), (4.2, 3.2, 1.2), 83)


@template("SapTapCistern", WOOD=1200, METAL=500, GLOW=750, TRIM=350)
def sap_tap_cistern(t):
    """Wooden sap-tap spout pouring glowing magenta sap into a hooped cooperage cistern tub and buckets."""
    wood, metal, glow, trim = t.bm("WOOD"), t.bm("METAL"), t.bm("GLOW"), t.bm("TRIM")
    # Big wooden cooperage cistern tub (lathe cylinder) + iron hoops.
    lathe(wood, [(4.4, 0.0), (4.8, 3.2), (4.6, 6.4), (4.1, 6.4), (4.1, 1.0), (0.0, 1.0)], 14, M((0, 0, 0)))
    for hz in (1.4, 3.4, 5.4):
        ring_mesh(metal, 4.88, 0.28, 14, M((0, 0, hz)), tube_segs=5)
    # Glowing magenta sap filling the tub.
    uvsphere(glow, 1.0, M((0, 0, 5.6), scale=(4.2, 4.2, 0.65)), u=12, v=6)
    # Timber tap post & carved wooden spout pouring a glowing sap stream into the tub!
    box(wood, (2.2, 2.2, 13.5), M((0, 5.8, 6.75)))
    box(trim, (1.4, 5.4, 1.1), M((0, 3.2, 10.6), rot=(0.24, 0, 0)))
    tube(glow, [(0, 0.8, 9.8), (0, 0.4, 7.8), (0, 0.0, 5.6)], [0.55, 0.48, 0.72], 6)
    # Two smaller overflow buckets beside the tub.
    for sx, sy in [(-5.8, -1.8), (5.6, -2.2)]:
        lathe(wood, [(1.35, 0.0), (1.55, 2.6), (1.3, 2.6), (1.3, 0.4), (0.0, 0.4)], segs=10, mat=M((sx, sy, 0)))
        uvsphere(glow, 1.0, M((sx, sy, 2.2), scale=(1.25, 1.25, 0.25)), u=8, v=4)


@template("SeedJarStack", WOOD=1200, CANDLE=700, GLOW=450, METAL=350, SILK=250)
def seed_jar_stack(t):
    """Hollow limb cradle stacked with glowing sealed Hollin seed jars, with one central jar caged in black thorns."""
    wood, candle, glow, metal, silk = t.bm("WOOD"), t.bm("CANDLE"), t.bm("GLOW"), t.bm("METAL"), t.bm("SILK")
    # Curved hollow elder limb cradle resting on timber chocks.
    for sx in (-4.4, 4.4):
        box(wood, (1.4, 5.2, 1.8), M((sx, 0, 0.9)))
    tube(wood, [(-5.8, 0, 2.4), (0, 0.6, 2.8), (5.8, 0, 2.4)], [3.2, 3.8, 3.2], 8)
    # Back curving hollow hood over the shelf.
    tube(wood, [(-5.4, 2.4, 2.8), (-4.2, 3.0, 8.8), (0, 3.2, 10.6), (4.2, 3.0, 8.8), (5.4, 2.4, 2.8)], [1.6, 1.8, 2.0, 1.8, 1.6], 7)
    # Row of 5 glowing amber-green clean seed jars on the shelf.
    for sx, sz in [(-3.6, 4.0), (-1.9, 4.2), (1.9, 4.2), (3.6, 4.0)]:
        lathe(candle, [(0.0, 0.0), (0.9, 0.0), (1.05, 1.4), (0.7, 2.4), (0.85, 2.7), (0.0, 2.7)], segs=8, mat=M((sx, -0.4, sz)))
        box(metal, (1.4, 1.4, 0.4), M((sx, -0.4, sz + 2.8)))
    # Central Heartrot-Core jar caged in black thorns & glowing magenta!
    lathe(glow, [(0.0, 0.0), (1.2, 0.0), (1.45, 1.8), (1.0, 3.2), (1.15, 3.6), (0.0, 3.6)], segs=10, mat=M((0, -0.6, 4.3)))
    for k in range(6):
        a = k * math.pi / 3
        tube(wood, [(math.cos(a) * 1.8, -0.6 + math.sin(a) * 1.8, 4.2), (math.cos(a + 0.5) * 2.0, -0.6 + math.sin(a + 0.5) * 2.0, 6.2), (math.cos(a + 1.0) * 1.4, -0.6 + math.sin(a + 1.0) * 1.4, 8.4)], [0.24, 0.2, 0.14], 4)
    pale_band_wrap(silk, 1.6, 3.4, height=0.9, segs=8, tail=False)


@template("StakePalisadeSegment", WOOD=1200, SILK=300, GLOW=300, TRIM=250)
def stake_palisade_segment(t):
    """Sharpened timber bog-palisade wall (~22 x 5 x 12) lashed with vines, Pale Bands and magenta briars."""
    wood, silk, glow, trim = t.bm("WOOD"), t.bm("SILK"), t.bm("GLOW"), t.bm("TRIM")
    # 11 sharpened stakes of varied height & slight lean.
    for i in range(11):
        x = -10.0 + i * 2.0
        h = 9.4 + ((i * 7) % 4) * 0.85
        lean = ((i % 3) - 1) * 0.06
        cone(wood, 0.85, 0.16, h, segs=7, mat=M((x, 0, h / 2), rot=(lean, 0, 0)))
    # Twin lashed horizontal rails & cross-braces.
    for rz in (2.8, 6.8):
        box(trim, (21.6, 0.9, 0.9), M((0, 0.85, rz)))
    # Pale Band tied to the centre stake & glowing briar vine snaking along the front.
    pale_band_wrap(silk, 1.15, 6.0, height=1.2, segs=8, tail=True, tail_ang=-math.pi / 2)
    tube(glow, [(-9.5, -0.9, 1.8), (-3.2, -1.0, 4.6), (3.4, -0.9, 3.4), (9.4, -1.0, 6.2)], [0.32, 0.38, 0.32, 0.24], 5)


@template("StiltHut", WOOD=1800, ALT=900, TRIM=550, CANDLE=300, SILK=250, MOSS=300)
def stilt_hut(t):
    """Mender's Ward rickety stilt hut (~22 x 18 x 22) with woven thatch roof, warm sap-lantern and bog stilts."""
    wood, alt, trim, candle, silk, moss = t.bm("WOOD"), t.bm("ALT"), t.bm("TRIM"), t.bm("CANDLE"), t.bm("SILK"), t.bm("MOSS")
    # 6 uneven timber stilts rising from Z 0..6.2 to hold the floor above bog muck.
    for sx in (-7.8, 0, 7.8):
        for sy in (-5.6, 5.6):
            tube(wood, [(sx, sy, 0.0), (sx * 0.96, sy * 0.96, 6.4)], [0.78, 0.68], 6)
    # Cross-bracing under deck & plank floor.
    tube(wood, [(-7.6, -5.4, 1.2), (7.6, -5.4, 5.6)], [0.35, 0.35], 4)
    tube(wood, [(-7.6, 5.4, 5.6), (7.6, 5.4, 1.2)], [0.35, 0.35], 4)
    box(wood, (19.6, 14.8, 1.1), M((0, 0, 6.5)))
    # Wattle-and-daub cabin walls + doorway + glowing warm window.
    box(trim, (15.6, 11.4, 8.0), M((0, 0.6, 10.9)))
    box(wood, (3.4, 0.6, 5.8), M((-2.4, -5.1, 9.8)))
    box(candle, (2.6, 0.6, 2.4), M((3.8, -5.1, 11.2)))
    # Steep woven roof with mossy patch.
    box(alt, (19.2, 9.2, 1.2), M((0, -3.4, 17.6), rot=(0.64, 0, 0)))
    box(alt, (19.2, 9.2, 1.2), M((0, 4.6, 17.6), rot=(-0.64, 0, 0)))
    canopy_blob(moss, (-4.5, -2.8, 19.2), (3.8, 2.6, 1.2), 91)
    # Hanging sap-lantern hook on front porch & Pale Band.
    tube(wood, [(7.2, -5.4, 7.0), (7.2, -6.8, 12.6), (7.2, -8.2, 12.0)], [0.4, 0.36, 0.26], 5)
    uvsphere(candle, 0.85, M((7.2, -8.2, 10.6)), u=7, v=5)
    pale_band_wrap(silk, 0.72, 9.5, height=0.9, segs=8, tail=True, tail_ang=-1.5)


@template("WeepingGallowsTree", WOOD=1800, SILK=650, TRIM=400, MOSS=350)
def weeping_gallows_tree(t):
    """Sombre gnarled dead gallows tree (~26 x 20 x 38) hung with Pale-Band-wrapped ropes swaying over the bog."""
    wood, silk, trim, moss = t.bm("WOOD"), t.bm("SILK"), t.bm("TRIM"), t.bm("MOSS")
    # Leaning dead gnarled trunk Z 0..34.
    pts = [Vector((0, 0, 0)), Vector((-1.4, 0.5, 12.0)), Vector((0.8, -0.6, 24.0)), Vector((2.2, -1.2, 34.0))]
    tube(wood, pts, [3.4, 2.6, 2.0, 1.4], 8)
    for k in range(5):
        a = k * 2 * math.pi / 5
        tube(wood, [(math.cos(a) * 1.8, math.sin(a) * 1.8, 4.5), (math.cos(a) * 6.4, math.sin(a) * 6.4, -0.2)], [1.4, 0.6], 5)
    # Two long horizontal weeping boughs at Z 26 & 31, each hung with sombre Pale-Band-wrapped ropes.
    boughs = [
        [Vector((0.8, -0.6, 25.0)), Vector((-6.5, -1.2, 27.2)), Vector((-12.5, -1.8, 26.0))],
        [Vector((2.0, -1.1, 31.0)), Vector((8.0, -1.6, 33.4)), Vector((12.8, -1.8, 32.0))],
    ]
    for b_idx, bpts in enumerate(boughs):
        tube(wood, bpts, [1.8, 1.2, 0.6], 6)
        for p in bpts[1:]:
            # Hanging weathered rope end + fluttering Pale Band knot (sombre, never gory).
            r_end = p + Vector((0, 0, -10.5))
            tube(trim, [p, p + Vector((0.3, 0, -5.5)), r_end], [0.22, 0.18, 0.26], 5)
            ring_mesh(silk, 0.55, 0.25, 8, M((p.x + 0.3, p.y, p.z - 5.5)), tube_segs=4)
            tube(silk, [p + Vector((0.3, -0.4, -5.5)), p + Vector((0.9, -0.6, -8.5))], [0.28, 0.14], 4)
        moss_drape(moss, bpts[1] + Vector((0, 0.6, -0.5)), length=7.5, width=1.1, seed=b_idx * 9)
    pale_band_wrap(silk, 2.8, 10.5, height=1.6, segs=10, tail=True, tail_ang=-1.5)


@template("SunkenWardenBoat", WOOD=1100, CAP=450, GLOW=300, MOSS=300)
def sunken_warden_boat(t):
    """Half-sunk weathered Hollin skiff (~18 x 8 x 6) tilted in the bog muck with oar and glowing rot-lilies."""
    wood, cap, glow, moss = t.bm("WOOD"), t.bm("CAP"), t.bm("GLOW"), t.bm("MOSS")
    tilt = M((0, 0, 1.4), rot=(0.18, -0.22, 0.12))
    # Pointed hull ribs & gunwales.
    for side in (-1, 1):
        pts = [
            tilt @ Vector((-8.2, 0.0, 1.4)),
            tilt @ Vector((-4.2, side * 3.1, 1.0)),
            tilt @ Vector((0.0, side * 3.5, 0.8)),
            tilt @ Vector((4.2, side * 3.0, 1.1)),
            tilt @ Vector((8.2, 0.0, 1.6)),
        ]
        tube(wood, pts, [0.45, 0.62, 0.65, 0.60, 0.45], 6)
    box(wood, (11.5, 5.2, 0.5), tilt @ M((0, 0, -0.3)))
    for tx in (-3.2, 0.2, 3.2):
        box(wood, (1.1, 5.8, 0.4), tilt @ M((tx, 0, 0.7)))
    # Slipped wooden oar across the thwart.
    tube(wood, [tilt @ Vector((-5.5, -2.5, 1.4)), tilt @ Vector((5.0, 3.8, 2.2))], [0.24, 0.22], 5)
    box(wood, (3.2, 1.2, 0.25), tilt @ M((5.8, 4.2, 2.3), rot=(0, 0, 0.55)))
    # Glowing rot-lilies growing out of the flooded bow.
    for lx, ly in [(-2.4, -1.2), (1.8, 0.8), (-0.4, 1.6)]:
        canopy_blob(moss, (lx, ly, 1.6), (1.5, 1.4, 0.35), int(abs(lx * 10) + 7))
        uvsphere(cap, 0.9, M((lx, ly, 2.1), scale=(1.1, 1.1, 0.5)), u=7, v=5)
        uvsphere(glow, 0.42, M((lx, ly, 2.35)), u=6, v=4)


@template("BranchBridgeHanger", WOOD=1200, MOSS=600, CANDLE=300, SILK=300)
def branch_bridge_hanger(t):
    """Carved timber crane-arm hanger (~14 x 10 x 20) with hanging moss curtain and warm sap-lantern."""
    wood, moss, candle, silk = t.bm("WOOD"), t.bm("MOSS"), t.bm("CANDLE"), t.bm("SILK")
    # Heavy gnarled timber upright post Z 0..19.5 + cantilevered hanger arm over the bridge approach.
    tube(wood, [(0, 0, 0), (0.3, -0.2, 10.0), (0, 0, 19.5)], [1.45, 1.25, 1.05], 7)
    tube(wood, [(0, 0, 16.5), (4.2, -0.4, 18.8), (8.6, -0.6, 17.8)], [1.1, 0.88, 0.55], 6)
    tube(wood, [(0, 0, 11.8), (4.6, -0.4, 18.2)], [0.65, 0.55], 5)
    # Warm sap-lantern hanging from the arm tip & moss curtains.
    tube(wood, [(7.8, -0.6, 17.8), (7.8, -0.6, 14.8)], [0.16, 0.16], 4)
    uvsphere(candle, 1.15, M((7.8, -0.6, 13.8), scale=(0.9, 0.9, 1.25)), u=8, v=6)
    moss_drape(moss, (3.2, -0.4, 17.8), length=7.5, width=1.4, seed=3)
    moss_drape(moss, (5.8, -0.5, 18.0), length=6.0, width=1.2, seed=7)
    pale_band_wrap(silk, 1.48, 8.2, height=1.3, segs=8, tail=True, tail_ang=-math.pi / 2)


DEFAULT_BUDGET = 1200


def build_kit():
    reset_scene()
    kit = bpy.data.collections.new("CorruptedF34Kit")
    bpy.context.scene.collection.children.link(kit)
    manifest = {}
    for name, (fn, budget) in F34_TEMPLATES.items():
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
        filepath=os.path.join(OUT_DIR, "CorruptedF34Kit.fbx"),
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
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT_DIR, "CorruptedF34Kit.blend"))


if __name__ == "__main__":
    kit, manifest = build_kit()
    export_kit(kit, manifest)
    preview_dir = os.path.join(OUT_DIR, "previews")
    render_previews(kit, preview_dir, list(F34_TEMPLATES.keys()), tile=520, cols=4)
    print(json.dumps(manifest, indent=2))
