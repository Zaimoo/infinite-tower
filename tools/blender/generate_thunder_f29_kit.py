"""
Thunder Highlands Floor 29 (Tempest Redoubt) sculpted assets, generated in headless Blender.

Inspired by the Tempest Redoubt reference art (reference/Thunder Highlands 29.jpg): the Kairnfolk's two-tier
mountain acropolis on a cliff fault. A crenellated barbican with twin drum towers and a raised portcullis on the
lower ward, huge copper signal horns on its outer walls, timber ram stables and folds in the yards; above the
cliff the Storm-Bell Gate with its giant verdigris bell hung in the arch, round Stormkeep towers, crenellated
curtain walls, the citadel keep crowned by a copper-ringed storm spire, and on the west the capacitor spire:
nested copper coils round a caged lightning nexus. Lightning-spear ballistae, nexus braziers, tattered war
banners, a half-toppled watchtower and the retaining buttresses under the cliff switchbacks.

1 Blender unit = 1 stud, standing on z = 0, front facing -Y in Blender / +Z in Roblox, one mesh object per colour
role named "<Template>__<ROLE>". Every piece stands on its origin.

Roles (TowerSetPieces passes the Kairnfolk override): STONE granite and slate, MOSS turf, METAL hammered copper,
ACCENT verdigris, WOOD weathered timber, TRIM dark slate and iron, ALT banner cloth and hay, GLOW violet storm
light, CRYSTAL storm glass.

Outputs (assets-source/tower/thunder_f29_kit/): ThunderF29Kit.blend, ThunderF29Kit.fbx, manifest.json,
previews/kit_sheet_1.png.

Run:
    blender.exe --background --factory-startup --python tools/blender/generate_thunder_f29_kit.py
"""
import bpy, bmesh, math, os, json, runpy, random
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT_DIR = os.path.join(ROOT, "assets-source", "tower", "thunder_f29_kit")

# Shared primitives and helpers from the Floor 26 and 28 generators (which take the pipeline from Floor 21's).
f26 = runpy.run_path(os.path.join(HERE, "generate_thunder_f26_kit.py"))
f28 = runpy.run_path(os.path.join(HERE, "generate_thunder_f28_kit.py"))
box, cone, uvsphere, tube, ring_mesh = f26["box"], f26["cone"], f26["uvsphere"], f26["tube"], f26["ring_mesh"]
cyl_x, cyl_y, cyl_z, strut = f26["cyl_x"], f26["cyl_y"], f26["cyl_z"], f26["strut"]
ground_rock, centred_rock, slab_stone, bolt = f26["ground_rock"], f26["centred_rock"], f26["slab_stone"], f26["bolt"]
build_kit, export_kit, render_previews = f26["build_kit"], f26["export_kit"], f26["render_previews"]
coursed_block, cone_along, hanging_rope = f28["coursed_block"], f28["cone_along"], f28["hanging_rope"]
T = Matrix.Translation
R = Matrix.Rotation

DEFAULT_BUDGET = 3500
F29_TEMPLATES = {}


def template(name, **budget):
    def deco(fn):
        F29_TEMPLATES[name] = (fn, budget)
        return fn
    return deco


def track(d):
    return Vector(d).normalized().to_track_quat("Z", "Y").to_matrix().to_4x4()


def drum(stone, r, z0, h, seed, segs=16, course=1.8):
    """A round dry-stone drum of radius r from z0 up h: a core with courses of dressed stones round it."""
    cone(stone, r - 0.35, r - 0.35, h, segs, T((0, 0, z0)))
    rng = random.Random(seed)
    rows = max(2, int(h / course))
    for row in range(rows):
        z = z0 + (row + 0.5) * h / rows
        n = max(6, int(2 * math.pi * r / 2.8))
        for k in range(n):
            a = 2 * math.pi * (k + (row % 2) * 0.5) / n
            slab_stone(stone, (2 * math.pi * r / n + 0.25, 0.8, h / rows * 0.9), (math.cos(a) * r, math.sin(a) * r, z),
                       rot_z=a + math.pi / 2 + rng.uniform(-0.04, 0.04), seed=seed + row * 41 + k, roughness=0.1)


def round_crenels(stone, r, z, n, size=(1.8, 1.4, 2.2)):
    """Merlons round a drum's top at radius r (every other slot open)."""
    for k in range(n):
        if k % 2 == 1:
            continue
        a = 2 * math.pi * k / n
        box(stone, size, T((math.cos(a) * r, math.sin(a) * r, z + size[2] / 2)) @ R(a + math.pi / 2, 4, "Z"))


def square_crenels(stone, w, d, z, merlon=1.8, h=2.2):
    """Merlons round a w by d rectangular wall-walk at height z."""
    for side in range(4):
        along = w if side % 2 == 0 else d
        across = d if side % 2 == 0 else w
        n = max(2, int(along / (merlon * 2)))
        for k in range(n):
            f = (k + 0.5) / n - 0.5
            pos = f * (along - merlon)
            at = (pos, -across / 2, z) if side == 0 else (across / 2, pos, z) if side == 1 else (-pos, across / 2, z) if side == 2 else (-across / 2, -pos, z)
            box(stone, (merlon if side % 2 == 0 else 1.3, 1.3 if side % 2 == 0 else merlon, h), T((at[0], at[1], at[2] + h / 2)))


def copper_rings(metal, accent, rings, z_axis=True):
    """Nested copper storm rings: (radius, z, tube) each, with a verdigris inner lip."""
    for r, z, th in rings:
        ring_mesh(metal, r, th, 28, T((0, 0, z)), tube_segs=6)
        ring_mesh(accent, r - th * 0.9, th * 0.35, 28, T((0, 0, z)), tube_segs=4)


def banner(alt, accent, trim, at, w, h, tatter_seed, facing=-1):
    """A hanging war banner w by h from a crossbar at `at` (its top centre), a forked bolt sigil on its face, the
    bottom cut into tattered tongues."""
    x, y, z = at
    strut(trim, (x - w / 2 - 0.6, y, z), (x + w / 2 + 0.6, y, z), 0.35)
    rng = random.Random(tatter_seed)
    tongues = 5
    for k in range(tongues):
        f0 = k / tongues
        length = h * rng.uniform(0.78, 1.0)
        cx = x - w / 2 + (f0 + 0.5 / tongues) * w
        box(alt, (w / tongues + 0.02, 0.12, length), T((cx, y + facing * 0.1, z - length / 2 - 0.2)) @ R(rng.uniform(-0.05, 0.05), 4, "Y"))
    bolt(accent, Vector((x, y + facing * 0.2, z - h * 0.75)), h * 0.5, w * 0.35, 0.12, Matrix.Identity(4), segs=4)


# -----------------------------------------------------------------------------------------------------------
# The citadel keep: the floor's 160+ stud landmark behind the Tempest Redoubt.
# -----------------------------------------------------------------------------------------------------------
@template("RedoubtCitadelKeep", STONE=12000, METAL=4200, ACCENT=1500, TRIM=1400, GLOW=600, MOSS=700, ALT=600)
def redoubt_citadel_keep(t):
    """The Tempest Redoubt's citadel keep (40 wide, 28 deep): a battered dry-stone hall with round corner turrets
    and crenellations, a square tower rising from its middle, an octagonal drum and over it the great storm
    spire: a tapering copper needle girdled by four nested copper rings, a lightning rod and a violet glow at its
    tip. About 128 studs tall at scale 1."""
    stone, metal, accent, trim, glow, moss, alt = (t.bm(r) for r in ("STONE", "METAL", "ACCENT", "TRIM", "GLOW", "MOSS", "ALT"))
    # Rubble footing.
    for k in range(14):
        a = 2 * math.pi * k / 14
        ground_rock(stone, (6.0, 4.6, 3.0), (math.cos(a) * 17, math.sin(a) * 11, -0.6), seed=2901 + k, roughness=0.25, subdiv=1)
    # The hall: two battered stages.
    coursed_block(stone, 36, 24, 0, 18, 2911)
    coursed_block(stone, 33, 22, 18, 12, 2913)
    square_crenels(stone, 33, 22, 30)
    box(metal, (36.6, 24.6, 1.2), T((0, 0, 14)))
    # Corner turrets.
    for sx in (-1, 1):
        for sy in (-1, 1):
            cx, cy = sx * 17.5, sy * 11.5
            for k in range(2):
                cone(stone, 4.2 - k * 0.3, 4.2 - k * 0.3, 18, 14, T((cx, cy, k * 18)))
            cone(stone, 4.8, 4.8, 1.2, 14, T((cx, cy, 36)))
            ring_mesh(metal, 4.5, 0.3, 18, T((cx, cy, 28)), tube_segs=4)
            for j in range(6):
                a = 2 * math.pi * j / 6
                box(stone, (1.4, 1.4, 2.0), T((cx + math.cos(a) * 4.2, cy + math.sin(a) * 4.2, 38.2)))
            cone(trim, 3.6, 0.4, 7, 12, T((cx, cy, 37.2)))
    # The gate on the front and arrow slits.
    box(trim, (6, 0.8, 9), T((0, -12.3, 4.5)))
    cone(trim, 3.0, 3.0, 0.8, 12, T((0, -12.3, 9)) @ R(-math.pi / 2, 4, "X"))
    for x in (-11, -5, 5, 11):
        box(trim, (0.8, 0.6, 3.2), T((x, -12.2, 22)))
    # The middle tower.
    coursed_block(stone, 18, 16, 30, 26, 2917)
    square_crenels(stone, 18, 16, 56)
    box(metal, (18.6, 16.6, 1.0), T((0, 0, 50)))
    for x in (-4, 4):
        box(trim, (1.0, 0.6, 4.0), T((x, -8.2, 44)))
    # Octagonal drum and copper cap.
    cone(stone, 7.6, 7.0, 12, 8, T((0, 0, 56)))
    cone(metal, 8.2, 8.2, 1.4, 8, T((0, 0, 68)))
    for k in range(8):
        a = 2 * math.pi * (k + 0.5) / 8
        box(trim, (0.8, 0.6, 3.5), T((math.cos(a) * 7.3, math.sin(a) * 7.3, 62)) @ R(a + math.pi / 2, 4, "Z"))
    # The storm spire: a tapering copper needle with four nested rings and stays down to the drum.
    cone(metal, 5.0, 0.6, 52, 16, T((0, 0, 69.4)))
    copper_rings(metal, accent, ((10.0, 78, 0.9), (8.0, 89, 0.8), (6.0, 99, 0.7), (4.2, 108, 0.6)))
    for k in range(4):
        a = 2 * math.pi * k / 4 + math.pi / 4
        for r, z in ((10.0, 78), (8.0, 89), (6.0, 99), (4.2, 108)):
            strut(metal, (math.cos(a) * r * 0.95, math.sin(a) * r * 0.95, z), (math.cos(a) * 1.0, math.sin(a) * 1.0, z + 4), 0.35)
        strut(accent, (math.cos(a) * 7.6, math.sin(a) * 7.6, 69.4), (math.cos(a) * 10.0, math.sin(a) * 10.0, 78), 0.4)
    cone(accent, 0.35, 0.15, 8, 6, T((0, 0, 120.5)))
    uvsphere(glow, 1.6, T((0, 0, 121.5)), 10, 8)
    bolt(glow, Vector((0, 0, 122)), 6.5, 2.0, 0.25, Matrix.Identity(4), segs=4)
    # Ivy and turf, and a banner on the gate.
    for k in range(6):
        ground_rock(moss, (5.0, 1.2, 2.0), (-15 + k * 6, -12.5, 0.3 + (k % 2) * 0.8), seed=2921 + k, roughness=0.3, subdiv=1)
    banner(alt, accent, trim, (0, -12.9, 26), 6, 9, 2923)


# -----------------------------------------------------------------------------------------------------------
# The Capacitor Spire.
# -----------------------------------------------------------------------------------------------------------
@template("CapacitorCoilSpire", STONE=6000, METAL=5200, ACCENT=1600, TRIM=1200, GLOW=700, CRYSTAL=500)
def capacitor_coil_spire(t):
    """The grand capacitor spire (14 wide): a square dry-stone tower with copper conduits running up its corners,
    a copper drum on top, and a copper mast girdled by three nested coil rings, crowned by a spherical wire cage
    holding a violet storm-glass nexus. About 64 studs tall."""
    stone, metal, accent, trim, glow, crystal = (t.bm(r) for r in ("STONE", "METAL", "ACCENT", "TRIM", "GLOW", "CRYSTAL"))
    for k in range(8):
        a = 2 * math.pi * k / 8
        ground_rock(stone, (3.6, 3.0, 2.0), (math.cos(a) * 6.8, math.sin(a) * 6.8, -0.4), seed=2931 + k, roughness=0.25, subdiv=1)
    coursed_block(stone, 12, 12, 0, 16, 2933)
    coursed_block(stone, 10, 10, 16, 10, 2935)
    square_crenels(stone, 10, 10, 26, merlon=1.6, h=1.8)
    for z in (8, 15.5, 24):
        box(metal, (12.6 if z < 16 else 10.6, 12.6 if z < 16 else 10.6, 0.9), T((0, 0, z)))
    # Conduits up the four corners, bent in over the parapet to the drum.
    for sx in (-1, 1):
        for sy in (-1, 1):
            p0 = (sx * 6.4, sy * 6.4, 0.4)
            p1 = (sx * 6.4, sy * 6.4, 15.6)
            p2 = (sx * 5.4, sy * 5.4, 16.4)
            p3 = (sx * 5.4, sy * 5.4, 27.5)
            p4 = (sx * 3.2, sy * 3.2, 29.6)
            for a, b in ((p0, p1), (p1, p2), (p2, p3), (p3, p4)):
                strut(metal, a, b, 0.7)
            for z in (4, 10, 20):
                box(accent, (1.2, 1.2, 0.5), T((sx * (6.4 if z < 16 else 5.4), sy * (6.4 if z < 16 else 5.4), z)))
    # The copper drum and the mast with its coils.
    cone(metal, 4.4, 4.0, 4.0, 18, T((0, 0, 27.4)))
    ring_mesh(accent, 4.3, 0.3, 18, T((0, 0, 29.6)), tube_segs=4)
    cone(metal, 1.6, 0.9, 26, 12, T((0, 0, 31.4)))
    copper_rings(metal, accent, ((6.2, 36, 0.75), (5.0, 42, 0.65), (3.9, 47.5, 0.55)))
    for k in range(3):
        a = 2 * math.pi * k / 3
        for r, z in ((6.2, 36), (5.0, 42), (3.9, 47.5)):
            strut(trim, (math.cos(a) * r, math.sin(a) * r, z), (math.cos(a) * 1.3, math.sin(a) * 1.3, z + 1.5), 0.3)
    # The nexus cage: meridian and latitude rings round a storm-glass core.
    cage_z = 53.5
    for k in range(4):
        ring_mesh(metal, 4.6, 0.22, 24, T((0, 0, cage_z)) @ R(math.pi * k / 4, 4, "Z") @ R(math.pi / 2, 4, "X"), tube_segs=4)
    for z, r in ((-2.6, 3.8), (0, 4.6), (2.6, 3.8)):
        ring_mesh(metal, r, 0.22, 24, T((0, 0, cage_z + z)), tube_segs=4)
    uvsphere(crystal, 3.4, T((0, 0, cage_z)), 14, 10)
    uvsphere(glow, 2.0, T((0, 0, cage_z)), 10, 8)
    cone(metal, 0.5, 0.12, 7, 6, T((0, 0, cage_z + 4.4)))
    for sx in (-1, 1):
        bolt(glow, Vector((sx * 2.6, 0, cage_z + 1)), 5.0, 1.6, 0.2, Matrix.Identity(4), segs=4, flip=sx)


# -----------------------------------------------------------------------------------------------------------
# The Storm-Bell Gate.
# -----------------------------------------------------------------------------------------------------------
GATE_HALF = 23.0  # half the passage under the arch


@template("StormBellGatehouse", STONE=9000, METAL=3200, ACCENT=2600, TRIM=1200, ALT=600, GLOW=300)
def storm_bell_gatehouse(t):
    """The Storm-Bell Gate (66 wide, 10 deep): two crenellated dry-stone pylons either side of a 46-stud
    passage, a stone lintel course over it on a pointed arch, and hung in the arch from a copper yoke the giant
    verdigris storm-bell, its lip 23 studs over the walk. Copper conduits climb both pylons; forked-bolt
    banners hang on their faces. About 46 studs tall."""
    stone, metal, accent, trim, alt, glow = (t.bm(r) for r in ("STONE", "METAL", "ACCENT", "TRIM", "ALT", "GLOW"))
    pw = 10.0
    for sx in (-1, 1):
        cx = sx * (GATE_HALF + pw / 2)
        coursed_block(stone, pw, 10, 0, 40, 2941 + (sx > 0), cx=cx)
        square_crenels_at(stone, cx, 0, pw + 0.4, 10.4, 40)
        box(metal, (pw + 0.6, 10.6, 1.0), T((cx, 0, 12)))
        box(metal, (pw + 0.6, 10.6, 1.0), T((cx, 0, 30)))
        for dy in (-1, 1):
            strut(metal, (cx - sx * (pw / 2 + 0.3), dy * 3.4, 0.4), (cx - sx * (pw / 2 + 0.3), dy * 3.4, 33), 0.6)
        banner(alt, accent, trim, (cx, -5.4, 27), 5.2, 10, 2943 + (sx > 0))
    # The lintel course and the pointed arch under it.
    box(stone, (2 * GATE_HALF + 2, 10, 6.4), T((0, 0, 37.0)))
    square_crenels_at(stone, 0, 0, 2 * GATE_HALF, 10.4, 40.2)
    n = 14
    for k in range(n + 1):
        f = k / n
        a = math.pi * f
        x = -math.cos(a) * GATE_HALF
        z = 30 + math.sin(a) * 4.0 + (1 - abs(f - 0.5) * 2) * 1.5
        box(stone, (2 * GATE_HALF / n + 0.5, 9.6, 2.0), T((x, 0, z)) @ R(-(f - 0.5) * 0.4, 4, "Y"))
    # The yoke and the bell.
    box(metal, (14, 2.0, 1.6), T((0, 0, 33.6)))
    for sx in (-1, 1):
        strut(metal, (sx * 6.5, 0, 33.6), (sx * 1.2, 0, 31.6), 0.6)
    cyl_z(trim, 0.6, 1.6, (0, 0, 30.4), segs=8)
    # The bell: a flared shell (stacked frusta), a lip ring, a clapper.
    profile = ((1.6, 30.6), (3.4, 30.0), (4.0, 28.6), (4.4, 26.6), (5.0, 24.8), (6.2, 23.4))
    for (r0, z0), (r1, z1) in zip(profile, profile[1:]):
        cone(accent, r1, r0, z0 - z1, 24, T((0, 0, z1)))
    ring_mesh(accent, 6.1, 0.45, 28, T((0, 0, 23.4)), tube_segs=6)
    ring_mesh(metal, 4.3, 0.25, 24, T((0, 0, 27.2)), tube_segs=4)
    strut(trim, (0, 0, 29.8), (0, 0, 24.4), 0.35)
    uvsphere(trim, 0.9, T((0, 0, 24.0)), 10, 8)
    uvsphere(glow, 0.4, T((0, -1.3, 34.6)), 6, 5)


def square_crenels_at(stone, cx, cy, w, d, z, merlon=1.8, h=2.2):
    """square_crenels about (cx, cy)."""
    for side in range(4):
        along = w if side % 2 == 0 else d
        across = d if side % 2 == 0 else w
        n = max(2, int(along / (merlon * 2)))
        for k in range(n):
            f = (k + 0.5) / n - 0.5
            pos = f * (along - merlon)
            at = (pos, -across / 2) if side == 0 else (across / 2, pos) if side == 1 else (-pos, across / 2) if side == 2 else (-across / 2, -pos)
            box(stone, (merlon if side % 2 == 0 else 1.3, 1.3 if side % 2 == 0 else merlon, h), T((cx + at[0], cy + at[1], z + h / 2)))


# -----------------------------------------------------------------------------------------------------------
# Towers and walls.
# -----------------------------------------------------------------------------------------------------------
@template("StormkeepRoundTower", STONE=8000, METAL=1500, ACCENT=500, TRIM=800, ALT=500, MOSS=500)
def stormkeep_round_tower(t):
    """A Stormkeep round tower: a coursed drum 18 across and 34 tall with a corbelled, crenellated wall-walk,
    arrow slits, a copper band, a flagpole with a tattered pennant, and turf at its foot."""
    stone, metal, accent, trim, alt, moss = (t.bm(r) for r in ("STONE", "METAL", "ACCENT", "TRIM", "ALT", "MOSS"))
    for k in range(10):
        a = 2 * math.pi * k / 10
        ground_rock(stone, (3.4, 2.8, 2.0), (math.cos(a) * 8.6, math.sin(a) * 8.6, -0.4), seed=2951 + k, roughness=0.25, subdiv=1)
    drum(stone, 9.0, 0, 30, 2953, segs=20)
    cone(stone, 9.0, 10.0, 1.6, 20, T((0, 0, 30)))
    cone(stone, 10.0, 10.0, 0.8, 20, T((0, 0, 31.6)))
    round_crenels(stone, 9.6, 32.4, 16)
    ring_mesh(metal, 9.1, 0.4, 24, T((0, 0, 22)), tube_segs=4)
    ring_mesh(accent, 9.15, 0.2, 24, T((0, 0, 23)), tube_segs=4)
    for k, z in ((0, 9), (1, 18), (2, 26)):
        a = -math.pi / 2 + (k - 1) * 0.7
        box(trim, (0.9, 0.7, 3.2), T((math.cos(a) * 8.9, math.sin(a) * 8.9, z)) @ R(a + math.pi / 2, 4, "Z"))
    cyl_z(trim, 0.3, 12, (3.0, 3.0, 32.4), segs=6)
    for k in range(3):
        box(alt, (2.0, 0.1, 2.4), T((4.2 + k * 1.9, 3.0, 42.6 - k * 0.3)) @ R(0.05 * k, 4, "Y"))
    for k in range(5):
        a = 2 * math.pi * k / 5 + 0.4
        ground_rock(moss, (3.0, 2.4, 0.8), (math.cos(a) * 9.4, math.sin(a) * 9.4, 0.1), seed=2957 + k, roughness=0.3, subdiv=1)


@template("BarbicanGatehouse", STONE=10000, METAL=2200, ACCENT=900, TRIM=2200, ALT=900, GLOW=200)
def barbican_gatehouse(t):
    """The Lower Barbican's gatehouse (72 wide, 14 deep): twin crenellated drum towers either side of a 44-stud
    passage under a crenellated gate block on a round arch, its iron portcullis raised in the arch head, and a
    forked-bolt war banner on each tower's face. About 34 studs tall."""
    stone, metal, accent, trim, alt, glow = (t.bm(r) for r in ("STONE", "METAL", "ACCENT", "TRIM", "ALT", "GLOW"))
    half = 22.0
    for sx in (-1, 1):
        cx = sx * (half + 7)
        cone(stone, 7.4, 7.0, 28, 18, T((cx, 0, 0)))
        drum_courses(stone, cx, 7.0, 0, 28, 2961 + (sx > 0))
        cone(stone, 7.0, 7.9, 1.4, 18, T((cx, 0, 28)))
        for k in range(14):
            if k % 2:
                continue
            a = 2 * math.pi * k / 14
            box(stone, (2.0, 1.3, 2.4), T((cx + math.cos(a) * 7.4, math.sin(a) * 7.4, 30.6)) @ R(a + math.pi / 2, 4, "Z"))
        ring_mesh(metal, 7.25, 0.35, 22, T((cx, 0, 20)), tube_segs=4)
        box(trim, (0.9, 0.7, 3.2), T((cx, -7.2, 14)))
        banner(alt, accent, trim, (cx, -7.6, 26), 5.0, 9, 2963 + (sx > 0))
    # The gate block over the passage, on a round arch.
    box(stone, (2 * half + 2, 12, 8), T((0, 0, 22.0)))
    square_crenels_at(stone, 0, 0, 2 * half, 12.4, 26.0)
    n = 16
    for k in range(n + 1):
        f = k / n
        a = math.pi * f
        box(stone, (2 * half / n + 0.4, 11.6, 1.6), T((-math.cos(a) * half, 0, 14.0 + math.sin(a) * 4.0)) @ R(-(f - 0.5) * 0.45, 4, "Y"))
    # The raised portcullis: a grid of iron bars in the arch head with spiked feet.
    for k in range(11):
        x = -half + 2 + k * (2 * half - 4) / 10
        box(trim, (0.5, 0.5, 6.0), T((x, -3.0, 18.4)))
        cone(trim, 0.3, 0.02, 0.9, 4, T((x, -3.0, 14.5)))
    for z in (16.0, 18.4, 20.8):
        box(trim, (2 * half - 3, 0.5, 0.45), T((0, -3.0, z)))
    for sx in (-1, 1):
        strut(metal, (sx * (half - 1), -5.9, 0.4), (sx * (half - 1), -5.9, 21.5), 0.5)
    uvsphere(glow, 0.5, T((0, -6.3, 24.6)), 6, 5)


def drum_courses(stone, cx, r, z0, h, seed, course=1.8):
    rng = random.Random(seed)
    rows = max(2, int(h / course))
    for row in range(rows):
        z = z0 + (row + 0.5) * h / rows
        n = max(6, int(2 * math.pi * r / 2.8))
        for k in range(n):
            a = 2 * math.pi * (k + (row % 2) * 0.5) / n
            slab_stone(stone, (2 * math.pi * r / n + 0.25, 0.8, h / rows * 0.9), (cx + math.cos(a) * r, math.sin(a) * r, z),
                       rot_z=a + math.pi / 2 + rng.uniform(-0.04, 0.04), seed=seed + row * 41 + k, roughness=0.1)


@template("CurtainWallSegment", STONE=2600, METAL=300, ACCENT=200, MOSS=300)
def curtain_wall_segment(t):
    """A 16-stud run of crenellated curtain wall, 2.6 thick and 10 tall (it is set 4 studs down, so its
    wall-walk parapet stands 4 over the terrace and its merlons 6), with a copper string-course and turf
    creeping along its foot. Placed end to end round the citadel terraces."""
    stone, metal, accent, moss = (t.bm(r) for r in ("STONE", "METAL", "ACCENT", "MOSS"))
    rng = random.Random(2971)
    box(stone, (15.8, 2.2, 8), T((0, 0, 4)))
    for row in range(4):
        n = 6
        for k in range(n):
            f = (k + 0.5 + (row % 2) * 0.4) / n - 0.5
            if abs(f) > 0.5:
                continue
            for sy in (-1, 1):
                slab_stone(stone, (16 / n + 0.2, 0.6, 1.9), (f * 16, sy * 1.15, 1.0 + row * 2.0), rot_z=rng.uniform(-0.03, 0.03), seed=2973 + row * 7 + k + (sy > 0) * 50, roughness=0.1)
    box(stone, (16.0, 2.8, 0.6), T((0, 0, 8.3)))
    for k in range(4):
        x = -6 + k * 4
        box(stone, (2.2, 2.4, 1.8), T((x, 0, 9.5)))
    box(metal, (16.0, 2.5, 0.5), T((0, 0, 6.0)))
    box(accent, (16.0, 2.55, 0.18), T((0, 0, 6.4)))
    for k in range(3):
        ground_rock(moss, (4.0, 1.0, 0.9), (-5 + k * 5, -1.5, 0.2), seed=2975 + k, roughness=0.3, subdiv=1)


@template("ShatteredWatchtower", STONE=7000, TRIM=600, MOSS=700, WOOD=500)
def shattered_watchtower(t):
    """A half-toppled cliff watchtower: the stump of a round drum (about 26 tall at its high side), its top
    broken away on a slant, fallen courses and beams heaped at its foot, turf on the rubble."""
    stone, trim, moss, wood = (t.bm(r) for r in ("STONE", "TRIM", "MOSS", "WOOD"))
    rng = random.Random(2981)
    r = 7.0
    rows = 14
    for row in range(rows):
        z = 0.9 + row * 1.85
        n = 16
        for k in range(n):
            a = 2 * math.pi * (k + (row % 2) * 0.5) / n
            # The break: high on the -X side, falling to the +X side.
            top = 26 - 18 * (0.5 + 0.5 * math.cos(a)) + rng.uniform(-2, 2)
            if z > top:
                continue
            slab_stone(stone, (2 * math.pi * r / n + 0.2, 1.4, 1.75), (math.cos(a) * r, math.sin(a) * r, z), rot_z=a + math.pi / 2, seed=2983 + row * 31 + k, roughness=0.14)
    cone(trim, r - 1.2, r - 1.2, 3.0, 16, T((0, 0, 0)))
    for k in range(9):
        a = rng.uniform(-0.9, 0.9)
        d = rng.uniform(9, 15)
        slab_stone(stone, (2.6, 1.6, 1.6), (math.cos(a) * d, math.sin(a) * d, 0.7 + (k % 3) * 0.9), rot_z=rng.uniform(0, 3), tilt=rng.uniform(-0.3, 0.3), seed=2985 + k, roughness=0.18)
    for k in range(2):
        strut(wood, (8 + k * 2, -3 + k * 5, 0.5), (14 + k, 1 + k * 3, 3.2 - k), 0.7)
    for k in range(4):
        ground_rock(moss, (4.0, 3.0, 0.9), (10 + rng.uniform(-2, 3), rng.uniform(-5, 5), 0.3), seed=2987 + k, roughness=0.3, subdiv=1)


@template("FaultRetainingButtress", STONE=3600, METAL=500, ACCENT=200, MOSS=300)
def fault_retaining_buttress(t):
    """A retaining buttress propping a fault switchback against the cliff: a stepped, battered dry-stone pier
    (8 wide, 16 deep at its foot), its face sloping back to the top (30 tall), with two copper tie bands."""
    stone, metal, accent, moss = (t.bm(r) for r in ("STONE", "METAL", "ACCENT", "MOSS"))
    steps = ((16.0, 0, 8), (12.5, 8, 8), (9.0, 16, 8), (5.6, 24, 6))
    for i, (depth, z0, h) in enumerate(steps):
        coursed_block(stone, 8.0 - i * 0.6, depth, z0, h, 2991 + i * 13, cy=(16 - depth) / 2)
        # A sloped weathering cap on each step's front.
        box(stone, (8.2 - i * 0.6, 3.0, 0.8), T((0, -depth / 2 + (16 - depth) / 2 + 1.0, z0 + h)) @ R(-0.45, 4, "X"))
    for z in (10, 22):
        d = 16 - (z / 30) * 10.4
        box(metal, (8.6 - (z / 30) * 2, d + 0.4, 0.8), T((0, (16 - d) / 2, z)))
    ground_rock(moss, (6.0, 4.0, 1.0), (0, 2, 30.2), seed=2997, roughness=0.3, subdiv=1)


# -----------------------------------------------------------------------------------------------------------
# Yard and wall dressing.
# -----------------------------------------------------------------------------------------------------------
@template("SignalHornCannon", METAL=4200, ACCENT=1200, STONE=2200, TRIM=800, WOOD=600)
def signal_horn_cannon(t):
    """A great copper signal horn on its mount: a stone plinth with a timber cradle and an iron trunnion, the
    horn's long copper throat flaring to a 12-stud mouth aimed out over the drop (toward -Y), girdled with
    verdigris bands. About 16 studs tall, 28 long."""
    metal, accent, stone, trim, wood = (t.bm(r) for r in ("METAL", "ACCENT", "STONE", "TRIM", "WOOD"))
    coursed_block(stone, 8, 8, 0, 5, 3001)
    for sx in (-1, 1):
        strut(wood, (sx * 3.2, -2.5, 5), (sx * 3.2, 0, 9.4), 1.0)
        strut(wood, (sx * 3.2, 2.5, 5), (sx * 3.2, 0, 9.4), 1.0)
    cyl_x(trim, 0.9, 8.4, (0, 0, 9.4), segs=10)
    # The throat runs from behind the trunnion out to the mouth (-Y), rising gently.
    tail = Vector((0, 9.0, 9.0))
    neck = Vector((0, -2.0, 10.0))
    mouth = Vector((0, -18.0, 11.6))
    cone_along(metal, 1.0, 1.6, tail, neck, 16)
    bell = [(1.6, 0.0), (2.2, 0.35), (3.2, 0.62), (4.6, 0.82), (6.0, 1.0)]
    for (r0, f0), (r1, f1) in zip(bell, bell[1:]):
        cone_along(metal, r0, r1, neck.lerp(mouth, f0), neck.lerp(mouth, f1), 24)
    q = track(mouth - neck)
    ring_mesh(accent, 6.0, 0.45, 28, T(mouth) @ q, tube_segs=6)
    for f in (0.2, 0.5):
        p = neck.lerp(mouth, f)
        ring_mesh(accent, 1.8 + f * 2.4, 0.28, 20, T(p) @ q, tube_segs=4)
    ring_mesh(accent, 1.25, 0.25, 16, T(tail.lerp(neck, 0.5)) @ track(neck - tail), tube_segs=4)
    cone_along(trim, 1.1, 0.6, tail, tail + Vector((0, 1.6, 0.2)), 12)


@template("ThunderRamStable", WOOD=6000, STONE=2400, TRIM=1200, ALT=1200, METAL=500)
def thunder_ram_stable(t):
    """A Kairnfolk thunder-ram stable (20 wide, 11 deep): a dry-stone back wall, timber frame and stall
    partitions open to the front, a slate lean-to roof, hay heaped in the stalls and a copper weathervane."""
    wood, stone, trim, alt, metal = (t.bm(r) for r in ("WOOD", "STONE", "TRIM", "ALT", "METAL"))
    coursed_block(stone, 20, 2.0, 0, 10.0, 3011, cy=4.5)
    for sx in (-1, 1):
        coursed_block(stone, 1.6, 10, 0, 6.0, 3013 + (sx > 0), cx=sx * 9.2)
    for k in range(5):
        x = -9 + k * 4.5
        strut(wood, (x, -5.0, 0), (x, -5.0, 7.2), 0.7)
        strut(wood, (x, -4.6, 3.0), (x, 4.0, 3.0), 0.4)
        box(wood, (0.3, 8.6, 3.0), T((x, -0.4, 1.6)))
        # A rafter from the back wall's head down over the front beam.
        strut(wood, (x, 5.4, 10.2), (x, -6.0, 7.3), 0.45)
    strut(wood, (-9.6, -5.0, 7.0), (9.6, -5.0, 7.0), 0.6)
    # A lean-to slate roof falling to the front, laid in overlapping courses.
    a, b = Vector((0, 6.0, 10.9)), Vector((0, -6.6, 7.6))
    d = b - a
    q = d.normalized().to_track_quat("Y", "Z").to_matrix().to_4x4()
    box(trim, (21.6, d.length, 0.4), T((a + b) / 2) @ q)
    for k in range(6):
        f = (k + 0.5) / 6
        box(trim, (21.8, d.length / 6 + 0.3, 0.25), T(a.lerp(b, f) + Vector((0, 0, 0.28))) @ q)
    for k in range(4):
        x = -6.75 + k * 4.5
        ground_rock(alt, (3.4, 6.0, 1.6), (x, 0.4, 0.1), seed=3015 + k, roughness=0.35, subdiv=1)
    cyl_z(metal, 0.12, 3.0, (6, 3.8, 10.0), segs=6)
    box(metal, (2.2, 0.08, 0.7), T((6.6, 3.8, 12.6)))
    bolt(metal, Vector((5.9, 3.8, 11.4)), 1.6, 0.8, 0.1, Matrix.Identity(4), segs=3)


@template("LightningSpearBallista", WOOD=3600, METAL=2200, STONE=1800, TRIM=900, CRYSTAL=400, GLOW=300)
def lightning_spear_ballista(t):
    """A storm-glass ballista on its stone emplacement: a turning timber stock on a copper pivot, twin bow arms
    with a drawn cable, a copper-shod lightning spear laid in the groove pointing out (toward -Y), and a
    storm-glass coil on the stock. About 9 studs tall, 14 long."""
    wood, metal, stone, trim, crystal, glow = (t.bm(r) for r in ("WOOD", "METAL", "STONE", "TRIM", "CRYSTAL", "GLOW"))
    cone(stone, 5.0, 4.6, 2.4, 10, T((0, 0, 0)))
    cyl_z(metal, 1.2, 2.4, (0, 0, 2.4), segs=10)
    tilt = R(-0.12, 4, "X")
    base = T((0, 0, 5.4)) @ tilt
    box(wood, (2.2, 13.0, 1.4), base @ T((0, 0, 0)))
    for sx in (-1, 1):
        strut(wood, (base @ Vector((sx * 0.8, -4.5, 0.2))), (base @ Vector((sx * 6.6, -2.6, 0.6))), 0.6)
        strut(trim, (base @ Vector((sx * 6.6, -2.6, 0.6))), (base @ Vector((0, 3.4, 0.9))), 0.12)
    strut(metal, base @ Vector((0, 5.5, 1.0)), base @ Vector((0, -8.0, 1.0)), 0.35)
    cone_along(metal, 0.45, 0.02, base @ Vector((0, -8.0, 1.0)), base @ Vector((0, -10.0, 1.0)), 8)
    for k in range(3):
        ring_mesh(metal, 0.9, 0.18, 12, base @ T((0, 2.0 + k * 0.9, 0.2)) @ R(math.pi / 2, 4, "X"), tube_segs=4)
    uvsphere(crystal, 0.85, base @ T((0, 3.2, 1.6)), 10, 8)
    uvsphere(glow, 0.45, base @ T((0, 3.2, 1.6)), 6, 5)
    strut(wood, base @ Vector((0, 4.5, -0.4)), base @ Vector((0, 4.5, -2.6)), 0.6)


@template("NexusBrazierPedestal", STONE=2400, METAL=1800, ACCENT=500, GLOW=400, CRYSTAL=300)
def nexus_brazier_pedestal(t):
    """A copper-caged lightning nexus brazier: a dressed stone pedestal with a copper bowl, crossed copper
    hoops caging a violet storm-glass core. About 9 studs tall."""
    stone, metal, accent, glow, crystal = (t.bm(r) for r in ("STONE", "METAL", "ACCENT", "GLOW", "CRYSTAL"))
    cone(stone, 2.2, 2.0, 1.0, 8, T((0, 0, 0)) @ R(math.pi / 8, 4, "Z"))
    cone(stone, 1.3, 1.1, 4.0, 8, T((0, 0, 1.0)) @ R(math.pi / 8, 4, "Z"))
    cone(stone, 1.6, 1.8, 0.6, 8, T((0, 0, 5.0)) @ R(math.pi / 8, 4, "Z"))
    cone(metal, 1.1, 2.0, 1.0, 14, T((0, 0, 5.6)))
    ring_mesh(accent, 2.0, 0.16, 16, T((0, 0, 6.6)), tube_segs=4)
    for k in range(3):
        ring_mesh(metal, 1.6, 0.12, 18, T((0, 0, 7.9)) @ R(math.pi * k / 3, 4, "Z") @ R(math.pi / 2, 4, "X"), tube_segs=4)
    uvsphere(crystal, 1.1, T((0, 0, 7.9)), 10, 8)
    uvsphere(glow, 0.65, T((0, 0, 7.9)), 8, 6)
    cone(metal, 0.2, 0.05, 1.4, 5, T((0, 0, 9.5)))


@template("WarBannerPole", WOOD=900, ALT=900, ACCENT=500, TRIM=400, METAL=300, STONE=600)
def war_banner_pole(t):
    """A Kairnfolk war banner: a tall pole in a cairn, a crossbar and a long tattered banner with the forked
    bolt, a copper finial. About 18 studs tall."""
    wood, alt, accent, trim, metal, stone = (t.bm(r) for r in ("WOOD", "ALT", "ACCENT", "TRIM", "METAL", "STONE"))
    for k in range(5):
        a = 2 * math.pi * k / 5
        ground_rock(stone, (1.8, 1.5, 1.4), (math.cos(a) * 1.3, math.sin(a) * 1.3, -0.2), seed=3031 + k, roughness=0.25, subdiv=1)
    cone(wood, 0.35, 0.25, 17, 8, T((0, 0, 0)))
    cone(metal, 0.4, 0.02, 1.4, 6, T((0, 0, 17)))
    banner(alt, accent, trim, (0, -0.4, 15.2), 4.0, 10, 3033)


if __name__ == "__main__":
    kit, manifest = build_kit("ThunderF29Kit", F29_TEMPLATES, DEFAULT_BUDGET)
    export_kit(kit, manifest, OUT_DIR, "ThunderF29Kit")
    render_previews(kit, F29_TEMPLATES, OUT_DIR)
    print(json.dumps(manifest, indent=2))
