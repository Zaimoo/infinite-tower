"""
Corrupted Grove Floor 31 (Blighted Verge) sculpted assets, generated in headless Blender.

The Hollin grove-wardens' things on the edge of the grove: their thatched water mill and its wheel on the
blight-brook, a fieldstone weir, banded autumn trees, graft-knot posts, the wardens' lean-to and sawn stumps,
the woven stile arch at the arrival, wattle fences, the Warding Shrine cairn, the felled Blight Line log hung
with Pale Bands, wicker lanterns, the split Heartrot Spring trunk, and autumn-grass and rot-bloom ground cover.

Reuses the mesh helpers and role conventions of `tools/blender/generate_tower_biome_kit.py`
(1 Blender unit = 1 stud, standing on z = 0, front facing -Y in Blender / +Z in Roblox,
one mesh object per colour role named "<Template>__<ROLE>"). Roles used here: STONE (fieldstone),
WOOD (bark and timber), TRIM (pale cut wood and carved rings), ALT (thatch and straw), FOLIAGE (leaves and
grass), MOSS, SILK (the linen Pale Bands), GLOW (rot light, lantern glass), CANDLE (flames), STEM and CAP
(rot-bloom stalks and petals). Floor 31 tints every role itself (TowerSetPieces/CorruptedGrove).

Run:
    /Applications/Blender.app/Contents/MacOS/Blender --background --python tools/blender/generate_corrupted_f31_kit.py

Outputs (assets-source/tower/corrupted_f31_kit/):
    CorruptedF31Kit.blend    the generated scene
    CorruptedF31Kit.fbx      FBX for File > Import 3D in Studio
    manifest.json            per template: roles, reference size, triangle counts
    previews/                contact-sheet renders
"""
import bpy, bmesh, math, os, json, runpy
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT_DIR = os.path.join(ROOT, "assets-source", "tower", "corrupted_f31_kit")

kit_mod = runpy.run_path(os.path.join(HERE, "generate_tower_biome_kit.py"), init_globals={"RUN_KIT": False})

Template = kit_mod["Template"]
M = kit_mod["M"]
box = kit_mod["box"]
cone = kit_mod["cone"]
uvsphere = kit_mod["uvsphere"]
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
    vmap = [bm.verts.new(v.co) for v in tmp.verts]
    for f in tmp.faces:
        bm.faces.new([vmap[v.index] for v in f.verts])
    tmp.free()


def band(bm, centre, radius, height, segs=12, tilt=(0, 0, 0)):
    """A linen Pale Band: a short open cylinder hugging a trunk (radius just over the bark)."""
    cone(bm, radius, radius * 0.98, height, segs, M(centre, rot=tilt))


def trailing_tail(bm, start, length, sway, seed):
    """A loose band end hanging from a knot: a thin twisted strip."""
    pts = [Vector(start)]
    for k in range(1, 5):
        f = k / 4
        pts.append(Vector(start) + Vector((math.sin(seed + f * 2.4) * sway * f, -0.4 * f, -length * f)))
    tube(bm, pts, [0.32, 0.30, 0.26, 0.20, 0.12], 4)


DEFAULT_BUDGET = 3500
F31_TEMPLATES = {}


def template(name, **budget):
    def deco(fn):
        F31_TEMPLATES[name] = (fn, budget)
        return fn
    return deco


@template("HollinWaterMill", STONE=1400, WOOD=2400, ALT=1600, GLOW=200, MOSS=600, TRIM=500)
def hollin_water_mill(t):
    """Thatched wattle-and-timber mill house on a fieldstone footing (~24 x 18 x 27). Wheel axle on +X."""
    stone, wood, alt, glow, moss, trim = (t.bm("STONE"), t.bm("WOOD"), t.bm("ALT"), t.bm("GLOW"),
                                          t.bm("MOSS"), t.bm("TRIM"))
    rng = t.rng
    # Fieldstone footing: a battered plinth of big rounded stones.
    box(stone, (22.0, 16.0, 5.2), M((0, 0, 2.6)), bevel=0.6)
    for k in range(14):
        a = k / 14 * 2 * math.pi
        x, y = math.cos(a) * 11.2, math.sin(a) * 8.2
        rock_clean(stone, (rng.uniform(3.2, 4.6), rng.uniform(2.6, 3.6), rng.uniform(2.6, 4.2)), M((x, y, 0)), 300 + k, subdiv=1)
    # Wattle walls between timber frame posts.
    box(trim, (19.0, 13.0, 10.0), M((0, 0, 10.2)), bevel=0.15)
    for x in (-9.4, -3.1, 3.1, 9.4):
        for y in (-6.4, 6.4):
            box(wood, (1.1, 1.1, 11.0), M((x, y, 10.6)), bevel=0.1)
    for y in (-6.4, 6.4):
        box(wood, (20.0, 1.1, 1.0), M((0, y, 15.4)), bevel=0.1)
        box(wood, (20.0, 1.1, 1.0), M((0, y, 5.8)), bevel=0.1)
        # Diagonal braces.
        for x0, s in ((-6.3, 1), (6.3, -1)):
            box(wood, (0.8, 0.8, 7.6), M((x0, y, 10.6), rot=(0, s * 0.62, 0)), bevel=0.06)
    # Door and two warm windows on the front (-Y).
    box(wood, (3.6, 0.6, 6.4), M((-4.6, -6.75, 8.6)), bevel=0.08)
    for x in (2.2, 6.6):
        box(glow, (2.2, 0.3, 2.0), M((x, -6.65, 11.2)))
        box(wood, (2.8, 0.5, 0.4), M((x, -6.8, 12.3)))
    # Thatch roof: two thick slopes, a ridge roll, overhanging eaves.
    for s in (-1, 1):
        box(alt, (24.0, 10.6, 1.9), M((0, s * 4.4, 19.2), rot=(s * -0.72, 0, 0)), bevel=0.7)
    tube(alt, [(-12.6, 0, 23.0), (0, 0, 23.4), (12.6, 0, 23.0)], [1.4, 1.5, 1.4], 8)
    # Gable ends in wattle.
    for x in (-9.6, 9.6):
        for k in range(3):
            w = 10.0 - k * 3.2
            box(trim, (0.6, w, 2.4), M((x, 0, 16.6 + k * 2.3)), bevel=0.08)
    # Moss on the thatch, an axle boss on the wheel side (+X).
    for k, (x, y) in enumerate(((-6, 3.5), (2, -4.0), (8, 4.2), (-9, -3.6))):
        rock_clean(moss, (3.4, 2.6, 1.0), M((x, y, 19.6 + abs(y) * -0.35)), 330 + k, subdiv=1)
    tube(wood, [(9.6, 0, 6.5), (13.6, 0, 6.5)], [1.1, 1.1], 8)


@template("MillWheel", WOOD=2400, TRIM=500)
def mill_wheel(t):
    """Undershot water wheel, 18 across, axle along X, standing on its rim at z = 0."""
    wood, trim = t.bm("WOOD"), t.bm("TRIM")
    r = 9.0
    for x in (-1.6, 1.6):
        ring_mesh(wood, r, 0.55, 28, M((x, 0, r), rot=(0, math.pi / 2, 0)), tube_segs=5)
        ring_mesh(wood, r * 0.42, 0.4, 16, M((x, 0, r), rot=(0, math.pi / 2, 0)), tube_segs=4)
    tube(trim, [(-2.8, 0, r), (2.8, 0, r)], [1.0, 1.0], 10)
    for k in range(8):
        a = k * math.pi / 4
        for x in (-1.6, 1.6):
            p0 = Vector((x, math.cos(a) * 0.8, r + math.sin(a) * 0.8))
            p1 = Vector((x, math.cos(a) * (r - 0.4), r + math.sin(a) * (r - 0.4)))
            tube(wood, [p0, p1], [0.32, 0.32], 5)
    for k in range(18):
        a = k * 2 * math.pi / 18
        box(wood, (3.8, 0.35, 2.2), M((0, math.cos(a) * (r - 0.6), r + math.sin(a) * (r - 0.6)), rot=(a, 0, 0)), bevel=0.05)


@template("FieldstoneWeir", STONE=2200, MOSS=600)
def fieldstone_weir(t):
    """A stepped fieldstone weir across a brook (40 long along X, its spill face toward -Y), ~6 high."""
    stone, moss = t.bm("STONE"), t.bm("MOSS")
    rng = t.rng
    for step, (y, h, depth) in enumerate(((2.0, 6.0, 5.0), (-2.4, 4.0, 4.0), (-5.6, 2.0, 3.6))):
        n = 10
        for k in range(n):
            x = -19.0 + (k + 0.5) * 38.0 / n
            rock_clean(stone, (4.4 + rng.uniform(-0.4, 0.4), depth, h + rng.uniform(-0.3, 0.5)), M((x, y, 0)), 400 + step * 20 + k, roughness=0.14, subdiv=1)
    for k in range(5):
        rock_clean(moss, (5.0, 3.2, 0.8), M((-16 + k * 8, 2.4, 5.8)), 460 + k, subdiv=1)


@template("PaleBandTree", WOOD=2600, FOLIAGE=2600, SILK=300, MOSS=300, TRIM=300)
def pale_band_tree(t):
    """An autumn beech the wardens saved: grey trunk, a white linen Pale Band, a golden crown (~36 tall)."""
    wood, leaf, silk, moss, trim = t.bm("WOOD"), t.bm("FOLIAGE"), t.bm("SILK"), t.bm("MOSS"), t.bm("TRIM")
    rng = t.rng
    trunk = [Vector((rng.uniform(-0.4, 0.4) * k * 0.3, rng.uniform(-0.4, 0.4) * k * 0.3, k * 4.2 - 0.6)) for k in range(7)]
    radii = [2.1, 1.75, 1.55, 1.4, 1.25, 1.05, 0.8]
    tube(wood, trunk, radii, 10)
    for k in range(4):
        a = k * math.pi / 2 + 0.4
        tube(wood, [(math.cos(a) * 1.2, math.sin(a) * 1.2, 2.4), (math.cos(a) * 3.8, math.sin(a) * 3.8, 0.6), (math.cos(a) * 5.4, math.sin(a) * 5.4, -0.4)], [1.1, 0.7, 0.3], 6)
    band(silk, (trunk[1].x, trunk[1].y, 3.6), radii[1] + 0.18, 1.5)
    trailing_tail(silk, (trunk[1].x + radii[1] + 0.1, trunk[1].y - 0.4, 4.1), 3.4, 0.6, 1.3)
    trailing_tail(silk, (trunk[1].x + radii[1] - 0.2, trunk[1].y - 0.8, 4.0), 2.6, 0.9, 2.1)
    ends = []
    for k in range(5):
        a = k * 2 * math.pi / 5 + rng.uniform(-0.2, 0.2)
        path = branch_path(trunk[4], (math.cos(a), math.sin(a), 0.7), 12, 3, 0.2, rng)
        tube(wood, path, [0.8, 0.6, 0.4, 0.2], 6)
        ends.append(path[-1])
    for k, e in enumerate(ends):
        canopy_blob(leaf, e + Vector((0, 0, 2.5)), (11, 10, 7), 500 + k, subdiv=1)
    canopy_blob(leaf, trunk[-1] + Vector((0, 0, 4)), (17, 16, 11), 520)
    rock_clean(moss, (5.0, 5.0, 1.0), M((0, 0, 0)), 530, subdiv=1)
    # A pale wax-sealed cut where a rotten limb was taken off.
    uvsphere(trim, 0.7, M((radii[2] + 0.2, 0, 9.0), scale=(0.35, 1.0, 1.0)), u=8, v=6)


@template("GraftKnotPost", WOOD=900, TRIM=500, SILK=250, MOSS=200)
def graft_knot_post(t):
    """A carved Hollin marker post topped by the graft-knot: two crossed branches bound by a ring (~10 tall)."""
    wood, trim, silk, moss = t.bm("WOOD"), t.bm("TRIM"), t.bm("SILK"), t.bm("MOSS")
    box(wood, (1.6, 1.6, 7.0), M((0, 0, 3.5)), bevel=0.2)
    for s in (-1, 1):
        tube(wood, [(-2.0 * s, 0, 6.6), (0, 0, 8.4), (2.0 * s, 0, 10.2)], [0.45, 0.5, 0.35], 6)
    ring_mesh(trim, 1.25, 0.28, 16, M((0, 0, 8.4), rot=(math.pi / 2, 0, 0)), tube_segs=5)
    band(silk, (0, 0, 4.6), 1.0, 1.0, segs=4, tilt=(0, 0, math.pi / 4))
    trailing_tail(silk, (0.9, -0.6, 4.6), 2.6, 0.5, 0.7)
    rock_clean(moss, (3.4, 3.4, 0.9), M((0, 0, 0)), 540, subdiv=1)


@template("WardensLeanTo", WOOD=1600, ALT=900, SILK=400, STONE=500, GLOW=120)
def wardens_lean_to(t):
    """The wardens' open lean-to: a thatched slope on poles over a cot and a fire ring (~16 x 11 x 9)."""
    wood, alt, silk, stone, glow = t.bm("WOOD"), t.bm("ALT"), t.bm("SILK"), t.bm("STONE"), t.bm("GLOW")
    for x in (-7.0, 7.0):
        tube(wood, [(x, -4.0, 0), (x, -4.0, 8.6)], [0.45, 0.4], 6)
        tube(wood, [(x, 4.0, 0), (x, 4.0, 4.0)], [0.45, 0.4], 6)
    tube(wood, [(-7.6, -4.0, 8.4), (7.6, -4.0, 8.4)], [0.4, 0.4], 6)
    box(alt, (16.4, 10.4, 1.0), M((0, 0.2, 6.4), rot=(0.42, 0, 0)), bevel=0.35)
    # Cot with a rolled blanket.
    box(wood, (7.0, 3.2, 1.2), M((-2.4, 2.0, 1.4)), bevel=0.1)
    tube(silk, [(-5.6, 1.4, 2.4), (0.8, 1.4, 2.4)], [0.8, 0.8], 8)
    # Fire ring of stones in front, embers still warm.
    for k in range(8):
        a = k * math.pi / 4
        rock_clean(stone, (1.4, 1.4, 1.0), M((3.6 + math.cos(a) * 2.2, -6.6 + math.sin(a) * 2.2, 0)), 550 + k, subdiv=1)
    uvsphere(glow, 1.1, M((3.6, -6.6, 0.3), scale=(1, 1, 0.35)), u=8, v=5)
    for k in range(3):
        a = k * 2.1
        tube(wood, [(3.6 + math.cos(a) * 1.6, -6.6 + math.sin(a) * 1.6, 0.2), (3.6, -6.6, 1.7)], [0.2, 0.15], 4)


@template("SawnStumpCluster", WOOD=1600, TRIM=600, MOSS=300)
def sawn_stump_cluster(t):
    """Fresh-sawn stumps and a few split logs where the wardens cut away the first rot (~12 x 10)."""
    wood, trim, moss = t.bm("WOOD"), t.bm("TRIM"), t.bm("MOSS")
    rng = t.rng
    for k, (x, y, r, h) in enumerate(((0, 0, 2.6, 2.4), (5.2, 2.6, 1.9, 1.6), (-4.6, 3.2, 1.6, 1.3), (2.6, -4.4, 1.4, 1.0))):
        cone(wood, r + 0.4, r, h, 12, M((x, y, 0)))
        cone(trim, r - 0.15, r - 0.15, 0.2, 12, M((x, y, h)))
        for j in range(3):
            a = j * 2.1 + k
            tube(wood, [(x + math.cos(a) * r * 0.8, y + math.sin(a) * r * 0.8, 0.8), (x + math.cos(a) * (r + 1.8), y + math.sin(a) * (r + 1.8), -0.2)], [0.6, 0.2], 5)
    for k in range(3):
        y = -1.2 + k * 1.3
        tube(wood, [(-6.5, y - 5.0, 0.7 + (k == 1) * 1.2), (-1.0, y - 5.4, 0.7 + (k == 1) * 1.2)], [0.7, 0.7], 8)
    rock_clean(moss, (3.6, 3.0, 0.7), M((-3.0, -1.0, 0)), 560, subdiv=1)


@template("HeartrotSpringTrunk", WOOD=5200, GLOW=1100, MOSS=900, STONE=900)
def heartrot_spring_trunk(t):
    """The Heartrot Spring: a colossal elder split open to a glowing rot-heart, its roots in the spring
    (~110 tall, ~70 across). The split faces -Y."""
    wood, glow, moss, stone = t.bm("WOOD"), t.bm("GLOW"), t.bm("MOSS"), t.bm("STONE")
    rng = t.rng
    # Two leaning halves of one trunk, parted at the front.
    for s in (-1, 1):
        pts, radii = [], []
        for k in range(10):
            f = k / 9
            lean = s * (3.5 + 9.0 * f * f)
            pts.append(Vector((lean + math.sin(f * 5 + s) * 1.5, 2.0 + 4.0 * f, f * 82 - 1)))
            radii.append(9.5 - 5.5 * f)
        tube(wood, pts, radii, 12)
        # Gnarled crown limbs.
        for j in range(4):
            a = (j * 0.9 + 0.3) * s + (0 if s > 0 else math.pi)
            path = branch_path(pts[6 + j % 3], (math.cos(a) * 0.9, math.sin(a) * 0.6, 0.55), 26, 5, 0.35, rng)
            tube(wood, path, [2.6, 2.1, 1.6, 1.1, 0.6, 0.25], 7)
            twig = branch_path(path[3], (math.cos(a + 0.8), math.sin(a + 0.8), 0.8), 10, 3, 0.4, rng)
            tube(wood, twig, [0.7, 0.5, 0.3, 0.1], 5)
    # The rot-heart: a glowing seam filling the split, brightest low down.
    seam = [Vector((math.sin(k * 0.9) * 0.8, -1.5 - k * 0.15, 2 + k * 6.5)) for k in range(9)]
    tube(glow, seam, [3.2, 3.0, 2.6, 2.2, 1.8, 1.4, 1.0, 0.7, 0.4], 8)
    uvsphere(glow, 4.2, M((0, -2.4, 9), scale=(1.0, 0.55, 1.6)), u=10, v=8)
    # Root buttresses gripping the spring's rocks.
    for k in range(9):
        a = k * 2 * math.pi / 9 + rng.uniform(-0.15, 0.15)
        reach = rng.uniform(22, 34)
        tube(wood, [(math.cos(a) * 6, math.sin(a) * 6, 10), (math.cos(a) * reach * 0.5, math.sin(a) * reach * 0.5, 4.5), (math.cos(a) * reach, math.sin(a) * reach, -0.8)], [4.2, 3.0, 1.2], 8)
        rock_clean(stone, (rng.uniform(5, 9), rng.uniform(4, 7), rng.uniform(3, 6)), M((math.cos(a + 0.35) * reach * 0.8, math.sin(a + 0.35) * reach * 0.8, 0)), 600 + k, subdiv=1)
    for k in range(7):
        a = k * 2 * math.pi / 7 + 0.5
        rock_clean(moss, (7.0, 6.0, 1.6), M((math.cos(a) * 10, math.sin(a) * 10, 8 + (k % 3) * 9)), 620 + k, subdiv=1)


@template("HollinStileArch", WOOD=2600, SILK=500, TRIM=600, MOSS=300)
def hollin_stile_arch(t):
    """The woven wattle arch over the arrival path (inner span 40, crown ~24), the graft-knot at its crown."""
    wood, silk, trim, moss = t.bm("WOOD"), t.bm("SILK"), t.bm("TRIM"), t.bm("MOSS")
    half = 21.5
    for s in (-1, 1):
        tube(wood, [(s * half, 0, -0.5), (s * half, 0, 17.0)], [1.4, 1.1], 8)
        tube(wood, [(s * (half + 1.6), 0.8, -0.5), (s * (half + 0.6), 0.3, 12.0)], [0.8, 0.5], 6)
        band(silk, (s * half, 0, 7.5), 1.55, 1.4)
        trailing_tail(silk, (s * half, -1.5, 7.6), 4.0, 0.8, s)
        rock_clean(moss, (5.0, 4.0, 1.4), M((s * half, 0, 0)), 650 + s, subdiv=1)
    # Three braided withies sweeping over the span.
    for j, (dy, r) in enumerate(((-0.8, 0.85), (0.0, 1.0), (0.8, 0.85))):
        pts, radii = [], []
        for k in range(13):
            u = -1 + 2 * k / 12
            pts.append(Vector((u * half, dy + math.sin(u * 9 + j * 2.1) * 0.6, 16.0 + 8.0 * (1 - u * u) + math.cos(u * 9 + j) * 0.5)))
            radii.append(r)
        tube(wood, pts, radii, 6)
    # The graft-knot at the crown: two crossed branches bound by a carved ring.
    for s in (-1, 1):
        tube(wood, [(-3.2 * s, -1.2, 21.4), (0, -1.2, 24.4), (3.2 * s, -1.2, 27.4)], [0.55, 0.6, 0.4], 6)
    ring_mesh(trim, 1.9, 0.38, 18, M((0, -1.2, 24.4), rot=(math.pi / 2, 0, 0)), tube_segs=5)


@template("WattleFence", WOOD=1400)
def wattle_fence(t):
    """A woven wattle fence segment, 14 long along X, ~4.5 high."""
    wood = t.bm("WOOD")
    for k in range(6):
        x = -7 + k * 2.8
        tube(wood, [(x, 0, -0.5), (x, 0, 4.6)], [0.3, 0.26], 5)
    for row in range(4):
        z = 1.0 + row * 0.95
        pts = [Vector((-7.2 + i * 1.4, math.sin(i * math.pi / 2 + row) * 0.32, z)) for i in range(11)]
        tube(wood, pts, [0.2] * len(pts), 4)


@template("FieldstoneCairn", STONE=2000, MOSS=400, WOOD=500, SILK=300)
def fieldstone_cairn(t):
    """The Warding Shrine: a stacked fieldstone cairn on a ring of stones, banded stakes behind (~13 tall)."""
    stone, moss, wood, silk = t.bm("STONE"), t.bm("MOSS"), t.bm("WOOD"), t.bm("SILK")
    rng = t.rng
    z = 0.0
    for k, w in enumerate((7.0, 6.0, 5.2, 4.2, 3.4, 2.6, 1.8)):
        h = 1.6 + rng.uniform(-0.2, 0.3)
        rock_clean(stone, (w + rng.uniform(-0.3, 0.3), w * 0.9, h), M((rng.uniform(-0.3, 0.3), rng.uniform(-0.3, 0.3), z)), 700 + k, roughness=0.14, subdiv=1)
        z += h * 0.88
    for k in range(9):
        a = k * 2 * math.pi / 9
        rock_clean(stone, (1.8, 1.6, 1.2), M((math.cos(a) * 6.2, math.sin(a) * 6.2, 0)), 720 + k, subdiv=1)
    for k in range(5):
        a = math.pi * 0.2 + k * math.pi * 0.15
        x, y = math.cos(a) * 8.5, math.sin(a) * 8.5
        tube(wood, [(x, y, -0.4), (x, y, 5.5 + (k % 2) * 1.2)], [0.3, 0.22], 5)
        band(silk, (x, y, 4.0), 0.42, 0.6, segs=8)
        trailing_tail(silk, (x + 0.3, y - 0.2, 4.0), 2.2, 0.4, k)
    rock_clean(moss, (5.0, 4.5, 0.9), M((0, 0, 1.4)), 740, subdiv=1)


@template("FelledBandLog", WOOD=3000, SILK=700, MOSS=500, TRIM=300)
def felled_band_log(t):
    """The Blight Line: a great felled trunk laid as a barrier (60 long along X), Pale Bands torn and hanging."""
    wood, silk, moss, trim = t.bm("WOOD"), t.bm("SILK"), t.bm("MOSS"), t.bm("TRIM")
    rng = t.rng
    pts = [Vector((-30 + k * 7.5, math.sin(k * 0.8) * 1.2, 3.4 - k * 0.12)) for k in range(9)]
    tube(wood, pts, [3.6 - k * 0.15 for k in range(9)], 12)
    cone(trim, 3.4, 3.4, 0.3, 12, M((-30.1, 0, 3.4), rot=(0, -math.pi / 2, 0)))
    # Broken limb stubs and a root plate at the east end.
    for k in range(4):
        p = pts[2 + k * 2 - (k == 3)]
        tube(wood, [p, p + Vector((rng.uniform(-2, 2), rng.uniform(-3, 3), 6 + k))], [1.0, 0.4], 6)
    for k in range(7):
        a = k * 2 * math.pi / 7
        tube(wood, [(30, 0, 3.4), (31.5, math.cos(a) * 6.5, 3.4 + math.sin(a) * 6.0)], [1.2, 0.35], 5)
    # Bands: wrapped round the log, torn ends hanging.
    for k, idx in enumerate((1, 2, 3, 5, 6)):
        p = pts[idx]
        band(silk, (p.x, p.y, p.z), 3.75 - k * 0.1, 1.0, segs=12, tilt=(0, math.pi / 2, 0))
        trailing_tail(silk, (p.x + 0.3, p.y - 3.4, p.z), 3.2 + k * 0.4, 0.6, k)
    for k in range(5):
        rock_clean(moss, (6.0, 4.6, 1.2), M((-24 + k * 12, 0, 6.4 - k * 0.2)), 760 + k, subdiv=1)


@template("HangingLantern", WOOD=500, GLOW=150, CANDLE=80, TRIM=200)
def hanging_lantern(t):
    """A wicker lantern on a short cord. Its origin is the lantern's foot (it stands on it, like every template);
    the cord rises to the hook 5.2 above, which is where Floor 31 hangs it from."""
    wood, glow, candle, trim = t.bm("WOOD"), t.bm("GLOW"), t.bm("CANDLE"), t.bm("TRIM")
    h = 5.2
    tube(trim, [(0, 0, h), (0, 0, h - 1.6)], [0.08, 0.08], 4)
    cone(wood, 0.3, 1.1, 0.8, 8, M((0, 0, h - 2.4)))
    for k in range(6):
        a = k * math.pi / 3
        tube(wood, [(math.cos(a) * 1.0, math.sin(a) * 1.0, h - 2.4), (math.cos(a) * 1.2, math.sin(a) * 1.2, h - 4.0), (math.cos(a) * 0.9, math.sin(a) * 0.9, h - 5.0)], [0.12, 0.12, 0.12], 4)
    uvsphere(glow, 1.0, M((0, 0, h - 3.8), scale=(1, 1, 1.2)), u=8, v=6)
    cone(candle, 0.25, 0.02, 0.8, 6, M((0, 0, h - 3.9)))
    cone(wood, 1.0, 0.7, 0.4, 8, M((0, 0, h - 5.2)))


@template("AutumnGrassTuft", FOLIAGE=900)
def autumn_grass_tuft(t):
    """A clump of dry golden grass blades (~5 across, ~2.6 tall)."""
    leaf = t.bm("FOLIAGE")
    rng = t.rng
    for k in range(16):
        a = rng.uniform(0, 2 * math.pi)
        r = rng.uniform(0, 1.6)
        x, y = math.cos(a) * r, math.sin(a) * r
        h = rng.uniform(1.6, 2.8)
        lean = rng.uniform(0.3, 1.1)
        tube(leaf, [(x, y, 0), (x + math.cos(a) * lean * 0.5, y + math.sin(a) * lean * 0.5, h * 0.6), (x + math.cos(a) * lean, y + math.sin(a) * lean, h)], [0.16, 0.1, 0.02], 3, cap=False)


@template("RotBloomCluster", STEM=500, CAP=900, GLOW=300)
def rot_bloom_cluster(t):
    """Magenta rot-blooms: drooping five-petal flowers on dark stalks, glowing hearts (~4 across, ~3 tall)."""
    stem, cap, glow = t.bm("STEM"), t.bm("CAP"), t.bm("GLOW")
    rng = t.rng
    for k in range(5):
        a = k * 2 * math.pi / 5 + rng.uniform(-0.3, 0.3)
        r = rng.uniform(0.4, 1.6)
        base = Vector((math.cos(a) * r, math.sin(a) * r, 0))
        top = base + Vector((math.cos(a) * 0.6, math.sin(a) * 0.6, rng.uniform(1.8, 3.0)))
        tube(stem, [base, (base + top) / 2 + Vector((0, 0, 0.3)), top], [0.12, 0.1, 0.08], 4)
        for p in range(5):
            pa = p * 2 * math.pi / 5
            box(cap, (0.9, 0.5, 0.12), M((top.x + math.cos(pa) * 0.5, top.y + math.sin(pa) * 0.5, top.z - 0.15), rot=(0.5, 0, pa)), bevel=0.04)
        uvsphere(glow, 0.22, M((top.x, top.y, top.z)), u=6, v=4)


def build_kit():
    reset_scene()
    kit = bpy.data.collections.new("CorruptedF31Kit")
    bpy.context.scene.collection.children.link(kit)
    manifest = {}
    for name, (fn, budget) in F31_TEMPLATES.items():
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
        filepath=os.path.join(OUT_DIR, "CorruptedF31Kit.fbx"),
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
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT_DIR, "CorruptedF31Kit.blend"))


if __name__ == "__main__":
    kit, manifest = build_kit()
    export_kit(kit, manifest)
    preview_dir = os.path.join(OUT_DIR, "previews")
    render_previews(kit, preview_dir, list(F31_TEMPLATES.keys()), tile=520, cols=5)
    print(json.dumps(manifest, indent=2))
