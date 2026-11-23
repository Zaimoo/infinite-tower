"""
Thunder Highlands Floor 27 (Thunderhead Outpost) sculpted assets, generated in headless Blender.

Inspired by the Thunderhead Outpost reference art (reference/Thunder Highlands 27.jpg): a concentric dry-stone
ringfort on a storm-swept hilltop, its rampart walls banded with verdigris copper; a stepped broch keep with a
turf crown, a copper cage lantern and twin forked spires; curved timber-and-copper wind-harps on the ridge;
palisades of copper-tipped stakes at the gates with watch-bell gallows; a beacon hearth; a copper-smith's forge
with a copper hood and wire reels; ram pens with timber chutes; capacitor casks; longhouse ruins; inner gate
arches; and masts carrying the braided copper cables between them.

1 Blender unit = 1 stud, standing on z = 0, front facing -Y in Blender / +Z in Roblox, one mesh object per colour
role named "<Template>__<ROLE>". Every piece stands on its origin (rock() lifts its rocks onto their base; see the
note in generate_thunder_f26_kit.py).

Roles (TowerSetPieces passes the Kairnfolk override): STONE slate and granite, MOSS turf, METAL hammered copper,
ACCENT verdigris, WOOD weathered timber, TRIM dark slate and iron, ALT sailcloth and pennants, GLOW violet storm
light, GOLD bell bronze and firelight, CRYSTAL lantern glass.

Outputs (assets-source/tower/thunder_f27_kit/): ThunderF27Kit.blend, ThunderF27Kit.fbx, manifest.json,
previews/kit_sheet_1.png.

Run:
    blender.exe --background --factory-startup --python tools/blender/generate_thunder_f27_kit.py
"""
import bpy, bmesh, math, os, json, runpy, random
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT_DIR = os.path.join(ROOT, "assets-source", "tower", "thunder_f27_kit")

# Shared primitives and helpers from the Floor 26 generator (which takes the pipeline from Floor 21's).
f26 = runpy.run_path(os.path.join(HERE, "generate_thunder_f26_kit.py"))
box, cone, uvsphere, tube, ring_mesh = f26["box"], f26["cone"], f26["uvsphere"], f26["tube"], f26["ring_mesh"]
cyl_x, cyl_y, cyl_z, strut = f26["cyl_x"], f26["cyl_y"], f26["cyl_z"], f26["strut"]
ground_rock, centred_rock, slab_stone, bolt = f26["ground_rock"], f26["centred_rock"], f26["slab_stone"], f26["bolt"]
prism = f26["prism"]
build_kit, export_kit, render_previews = f26["build_kit"], f26["export_kit"], f26["render_previews"]
T = Matrix.Translation
R = Matrix.Rotation

DEFAULT_BUDGET = 3500
F27_TEMPLATES = {}


def template(name, **budget):
    def deco(fn):
        F27_TEMPLATES[name] = (fn, budget)
        return fn
    return deco


def coursed_drum(stone, accent, r0, r1, z0, h, seed, band_at=None):
    """A dry-stone drum (a slightly battered cylinder) laid in rough courses of stones, with a verdigris band."""
    cone(stone, r0 - 0.3, r1 - 0.3, h, 20, T((0, 0, z0)))
    rng = random.Random(seed)
    rows = max(2, int(h / 1.5))
    for row in range(rows):
        z = z0 + 0.75 + row * (h - 0.6) / rows
        f = (z - z0) / h
        rr = r0 + (r1 - r0) * f
        n = max(8, int(2 * math.pi * rr / 2.4))
        for k in range(n):
            a = 2 * math.pi * (k + (row % 2) * 0.5) / n + rng.uniform(-0.04, 0.04)
            slab_stone(stone, (2.6, 1.0, 1.25), (math.cos(a) * rr, math.sin(a) * rr, z), rot_z=a + math.pi / 2, seed=seed + row * 97 + k, roughness=0.15)
    if band_at is not None and accent is not None:
        zb = z0 + h * band_at
        rr = r0 + (r1 - r0) * band_at
        ring_mesh(accent, rr + 0.25, 0.35, 28, T((0, 0, zb)), tube_segs=5)


@template("BrochKeepTower", STONE=6000, MOSS=1200, METAL=1600, ACCENT=900, TRIM=600, GLOW=300, CRYSTAL=300)
def broch_keep_tower(t):
    """The Thunderhead keep: three stepped dry-stone broch drums (each banded in verdigris), dark doorways and
    window slits, a turf crown, and on top a copper cage lantern with a violet heart between two forked spires."""
    stone, moss, metal, accent, trim, glow, crystal = (t.bm(r) for r in ("STONE", "MOSS", "METAL", "ACCENT", "TRIM", "GLOW", "CRYSTAL"))
    tiers = ((10.6, 9.8, 0.0, 16.0), (8.0, 7.4, 16.0, 14.0), (5.8, 5.3, 30.0, 11.0))
    for i, (r0, r1, z0, h) in enumerate(tiers):
        coursed_drum(stone, accent, r0, r1, z0, h, 2711 + i * 31, band_at=0.62)
        # The step ledge capping each tier, turfed.
        cone(stone, r1 + 0.4, r1 - 0.6, 0.9, 20, T((0, 0, z0 + h - 0.2)))
        ring_mesh(moss, r1 - 0.9, 0.55, 24, T((0, 0, z0 + h + 0.55)), tube_segs=5)
        # A dark doorway and window slits facing the front, one more slit round the back.
        box(trim, (2.4, 1.2, 3.8 if i == 0 else 2.6), T((0, -(r0 + r1) / 2 + 0.1, z0 + (2.0 if i == 0 else h * 0.45))))
        for a in (math.radians(140), math.radians(40)):
            rr = (r0 + r1) / 2 - 0.1
            box(trim, (0.8, 1.0, 2.0), T((math.cos(a) * rr, math.sin(a) * rr, z0 + h * 0.55)) @ R(a + math.pi / 2, 4, "Z"))
    top = 41.0
    cone(moss, 5.6, 3.4, 2.6, 20, T((0, 0, top)))
    # The cage lantern: copper posts round a violet heart, a domed cap and a finial.
    lz = top + 2.4
    cyl_z(metal, 2.6, 0.6, (0, 0, lz), segs=12)
    for k in range(8):
        a = 2 * math.pi * k / 8
        strut(metal, (math.cos(a) * 2.2, math.sin(a) * 2.2, lz + 0.5), (math.cos(a) * 2.2, math.sin(a) * 2.2, lz + 5.5), 0.28)
    cyl_z(crystal, 1.9, 4.6, (0, 0, lz + 0.7), segs=12)
    uvsphere(glow, 1.2, T((0, 0, lz + 3.0)), 10, 8)
    ring_mesh(metal, 2.3, 0.22, 16, T((0, 0, lz + 3.0)), tube_segs=4)
    cone(metal, 2.9, 0.4, 2.6, 12, T((0, 0, lz + 5.4)))
    cyl_z(metal, 0.18, 2.4, (0, 0, lz + 7.8), segs=6)
    uvsphere(accent, 0.45, T((0, 0, lz + 10.4)), 8, 6)
    # Twin forked spires on the crown, either side of the lantern.
    for sx in (-1, 1):
        x = sx * 4.2
        cyl_z(metal, 0.32, 9.0, (x, 0, top + 1.5), segs=8, r2=0.18)
        for side in (-1, 1):
            strut(metal, (x, 0, top + 7.0), (x + side * 1.3, 0, top + 11.5), 0.22)
        bolt(glow, (x - 0.2, -0.3, top + 3.0), 6.0, 0.6, 0.12)


@template("WindHarpTower", WOOD=3200, METAL=1600, ACCENT=600, STONE=1400, GLOW=500, ALT=500)
def wind_harp_tower(t):
    """A Kairnfolk wind-harp: a tall sweeping timber arc and its upright post on a dry-stone footing, strung
    with copper resonance cables that glow violet in the squall, a sailcloth baffle and a copper sounding drum."""
    wood, metal, accent, stone, glow, alt = (t.bm(r) for r in ("WOOD", "METAL", "ACCENT", "STONE", "GLOW", "ALT"))
    # Footing of rough stones.
    for k in range(9):
        a = 2 * math.pi * k / 9
        ground_rock(stone, (3.2, 2.6, 2.4), (math.cos(a) * 3.6, math.sin(a) * 2.6, -0.3), seed=2751 + k, roughness=0.2, subdiv=1)
    box(stone, (8.4, 6.0, 2.4), T((0, 0, 1.2)))
    # The arc: a curving laminated beam sweeping up and over in the XZ plane, thinning to its head.
    pts, radii = [], []
    for k in range(14):
        f = k / 13
        a = math.radians(-8 + f * 104)
        pts.append((-3.0 + 15.0 * (1 - math.cos(a)) * 0.55, 0, 2.4 + 40.0 * math.sin(math.radians(f * 80))))
        radii.append(1.25 - 0.6 * f)
    tube(wood, pts, radii, 8)
    # The upright post, braced to the footing.
    strut(wood, (4.6, 0, 2.4), (4.6, 0, 30.0), 1.3)
    strut(wood, (4.6, 0, 9.0), (-1.8, 0, 2.6), 0.6)
    for z in (6.0, 18.0, 28.0):
        ring_mesh(metal, 1.0, 0.25, 12, T((4.6, 0, z)), tube_segs=4)
    # Copper strings from the post to the arc (with glowing cores), and a crossbar at the post's head.
    for k in range(9):
        f = 0.15 + k * 0.085
        idx = min(13, int(f * 13))
        top = Vector(pts[idx])
        z0 = 3.2 + k * 3.0
        strut(metal, (4.6, 0, z0), (top.x, 0, top.z), 0.16)
        if k % 2 == 0:
            strut(glow, (4.6, -0.12, z0), (top.x, -0.12, top.z), 0.07)
    strut(wood, (4.6, 0, 30.0), Vector(pts[13]) + Vector((0, 0, -0.5)), 0.7)
    # Sailcloth baffle on the lower strings and a copper sounding drum at the foot of the post.
    box(alt, (5.0, 0.12, 6.0), T((1.6, 0.4, 8.5)) @ R(math.radians(8), 4, "Y"))
    cyl_y(metal, 1.8, 2.4, (4.6, 0, 4.2), segs=14)
    ring_mesh(accent, 1.85, 0.2, 16, T((4.6, 1.2, 4.2)) @ R(math.pi / 2, 4, "X"), tube_segs=4)
    ring_mesh(accent, 1.85, 0.2, 16, T((4.6, -1.2, 4.2)) @ R(math.pi / 2, 4, "X"), tube_segs=4)


@template("RampartWallSegment", STONE=2600, ACCENT=300, MOSS=500)
def rampart_wall_segment(t):
    """A 16-stud run of the ringfort's rampart: battered dry-stone faces of rough coursed stones, a verdigris
    copper band let into the courses two thirds up, flat coping slabs and turf along the top."""
    stone, accent, moss = t.bm("STONE"), t.bm("ACCENT"), t.bm("MOSS")
    length, height = 16.0, 8.0
    # The core: a battered square-section block (a 4-sided cone turned square), stretched along the run.
    cone(stone, 2.3, 1.7, height - 0.6, 4, Matrix.Diagonal((length / 3.2, 1.0, 1.0, 1.0)) @ R(math.pi / 4, 4, "Z"))
    rng = random.Random(2761)
    rows = 6
    for row in range(rows):
        z = 0.7 + row * 1.2
        half = 1.6 - 0.45 * (z / height)
        for side in (-1, 1):
            x = -length / 2
            while x < length / 2:
                sl = rng.uniform(1.4, 2.6)
                slab_stone(stone, (sl, 0.9, 1.15), (x + sl / 2, side * half, z), rot_z=rng.uniform(-0.08, 0.08), seed=2762 + row * 131 + int((x + 10) * 11) + side, roughness=0.16)
                x += sl * 0.95
    for side in (-1, 1):
        box(accent, (length, 0.3, 0.55), T((0, side * (1.6 - 0.45 * 0.66) - side * 0.05, height * 0.62)))
    x = -length / 2 + 0.4
    k = 0
    while x < length / 2 - 0.4:
        sl = rng.uniform(1.4, 2.2)
        slab_stone(stone, (sl, 2.6, 0.7), (x + sl / 2, 0, height - 0.35), rot_z=rng.uniform(-0.1, 0.1), seed=2900 + k, roughness=0.1)
        x += sl * 1.0
        k += 1
    for k in range(4):
        centred_rock(moss, (rng.uniform(2.5, 4), 1.6, 0.6), T((rng.uniform(-6.5, 6.5), rng.uniform(-0.4, 0.4), height + 0.1)), seed=2950 + k, roughness=0.3, subdiv=1)


@template("PalisadeWallSpan", WOOD=2400, METAL=700, TRIM=400, STONE=500)
def palisade_wall_span(t):
    """A 14-stud span of the stockade: sharpened timber stakes of uneven height, copper-sheathed points, two
    lashed rails behind, raking props, and a few stones packed round their feet."""
    wood, metal, trim, stone = (t.bm(r) for r in ("WOOD", "METAL", "TRIM", "STONE"))
    rng = random.Random(2771)
    x = -7.0
    while x < 7.0:
        h = rng.uniform(8.6, 10.6)
        r = rng.uniform(0.42, 0.58)
        lean = rng.uniform(-0.04, 0.04)
        base = T((x, rng.uniform(-0.15, 0.15), -0.4)) @ R(lean, 4, "Y")
        cone(wood, r, r * 0.9, h, 7, base)
        cone(metal, r * 0.95, 0.05, 1.6, 7, base @ T((0, 0, h)))
        x += r * 2.0 + 0.05
    for z in (3.0, 7.0):
        box(trim, (14.4, 0.35, 0.5), T((0, 0.75, z)))
    for x in (-5.0, 0.0, 5.0):
        strut(wood, (x, 0.8, 6.0), (x, 4.2, -0.2), 0.4)
    for k in range(6):
        ground_rock(stone, (rng.uniform(1.4, 2.2), 1.2, 0.8), (rng.uniform(-6.5, 6.5), rng.choice((-1, 1)) * 0.9, -0.2), seed=2780 + k, roughness=0.3, subdiv=1)


@template("WatchBellGallows", WOOD=1200, GOLD=700, METAL=300, ALT=300)
def watch_bell_gallows(t):
    """A watch-bell gallows at a stockade gate: two posts and a crossbeam braced at the corners, a bronze storm
    bell hung from the beam, and a torn pennant on a pole beside it."""
    wood, gold, metal, alt = (t.bm(r) for r in ("WOOD", "GOLD", "METAL", "ALT"))
    for sx in (-1, 1):
        box(wood, (0.8, 0.8, 10.0), T((sx * 3.2, 0, 5.0)))
        strut(wood, (sx * 3.2, 0, 7.6), (sx * 1.6, 0, 9.6), 0.4)
    box(wood, (8.4, 0.9, 0.9), T((0, 0, 10.1)))
    strut(metal, (0, 0, 9.6), (0, 0, 8.4), 0.15)
    cone(gold, 0.5, 1.4, 2.4, 14, T((0, 0, 8.4)) @ R(math.pi, 4, "X"))
    ring_mesh(gold, 1.45, 0.13, 16, T((0, 0, 6.0)), tube_segs=4)
    uvsphere(metal, 0.3, T((0, 0, 5.6)), 6, 4)
    strut(wood, (4.6, 0.6, 0), (4.8, 0.6, 12.5), 0.25)
    box(alt, (2.6, 0.08, 1.6), T((6.1, 0.6, 11.6)) @ R(math.radians(-6), 4, "Y"))


@template("BeaconBrazier", STONE=1800, METAL=900, GLOW=300, ACCENT=300)
def beacon_brazier(t):
    """A signal beacon: a squat coursed stone plinth carrying a hammered-copper fire basket heaped with glowing
    coals, verdigris straps round the basket."""
    stone, metal, glow, accent = (t.bm(r) for r in ("STONE", "METAL", "GLOW", "ACCENT"))
    rng = random.Random(2791)
    cone(stone, 3.0, 2.6, 5.0, 12, T((0, 0, 0)))
    for row in range(3):
        for k in range(8):
            a = 2 * math.pi * (k + row * 0.5) / 8
            rr = 3.0 - row * 0.15
            slab_stone(stone, (2.1, 0.9, 1.4), (math.cos(a) * rr, math.sin(a) * rr, 0.8 + row * 1.6), rot_z=a + math.pi / 2, seed=2792 + row * 20 + k)
    cone(metal, 1.2, 2.3, 2.2, 14, T((0, 0, 5.0)))
    for k in range(4):
        a = 2 * math.pi * k / 4 + 0.4
        strut(accent, (math.cos(a) * 1.3, math.sin(a) * 1.3, 5.1), (math.cos(a) * 2.3, math.sin(a) * 2.3, 7.2), 0.16)
    ring_mesh(accent, 2.3, 0.18, 18, T((0, 0, 7.2)), tube_segs=4)
    for k in range(6):
        centred_rock(glow, (1.2, 1.0, 0.8), T((rng.uniform(-1.0, 1.0), rng.uniform(-1.0, 1.0), 6.9 + rng.uniform(0, 0.4))), seed=2800 + k, roughness=0.3, subdiv=1)


@template("CopperWireReel", WOOD=1200, METAL=1600, ACCENT=400)
def copper_wire_reel(t):
    """A great cable reel on a timber cradle: two spoked flanges, the drum wound thick with braided copper, a
    loose end trailing to the ground."""
    wood, metal, accent = t.bm("WOOD"), t.bm("METAL"), t.bm("ACCENT")
    for sx in (-1, 1):
        strut(wood, (sx * 2.6, -2.2, 0), (sx * 2.6, 0, 4.4), 0.5)
        strut(wood, (sx * 2.6, 2.2, 0), (sx * 2.6, 0, 4.4), 0.5)
        cyl_x(wood, 4.0, 0.5, (sx * 2.0, 0, 4.4), segs=16)
        for k in range(6):
            a = 2 * math.pi * k / 6
            strut(accent, (sx * 2.3, 0, 4.4), (sx * 2.3, math.cos(a) * 3.8, 4.4 + math.sin(a) * 3.8), 0.22)
    cyl_x(wood, 0.5, 6.2, (0, 0, 4.4), segs=8)
    for k in range(5):
        cyl_x(metal, 2.4 + k * 0.22, 3.4, (0, 0, 4.4), segs=18)
    tube(metal, [(0.6, -2.6, 3.2), (0.8, -4.0, 1.0), (1.4, -6.0, 0.2), (2.6, -8.0, 0.2)], [0.25] * 4, 6, cap=True)


@template("CopperForgeHearth", STONE=2400, METAL=1800, TRIM=900, GLOW=300, WOOD=400)
def copper_forge_hearth(t):
    """The copper-smith's open-air forge: a stone hearth with a glowing firebed under a hammered-copper hood and
    flue, an anvil on its block, a quench trough and a rack of tongs."""
    stone, metal, trim, glow, wood = (t.bm(r) for r in ("STONE", "METAL", "TRIM", "GLOW", "WOOD"))
    box(stone, (7.0, 5.6, 3.6), T((0, 0, 1.8)), bevel=0.3)
    box(glow, (4.6, 3.2, 0.4), T((0, -0.2, 3.7)))
    cone(metal, 4.2, 1.1, 4.6, 4, T((0, 0, 7.2)) @ R(math.pi / 4, 4, "Z"))
    for sx in (-1, 1):
        for sy in (-1, 1):
            strut(trim, (sx * 2.8, sy * 2.2, 3.6), (sx * 2.6, sy * 2.0, 7.3), 0.3)
    cyl_z(metal, 0.9, 7.0, (0, 0.4, 11.6), segs=10)
    cone(metal, 1.6, 0.9, 1.0, 10, T((0, 0.4, 18.4)))
    # Anvil on a block in front, quench trough beside.
    cyl_z(wood, 1.2, 2.2, (0, -6.0, 0), segs=10)
    box(trim, (3.2, 1.2, 1.4), T((0, -6.0, 2.9)))
    cone(trim, 0.6, 0.05, 1.8, 6, T((1.6, -6.0, 3.0)) @ R(math.pi / 2, 4, "Y"))
    box(wood, (2.4, 5.0, 1.6), T((5.4, -2.0, 0.8)))
    box(trim, (2.0, 4.6, 0.2), T((5.4, -2.0, 1.55)))
    # A tong rack.
    box(wood, (0.4, 4.0, 3.6), T((-4.6, -2.4, 1.8)))
    for k in range(4):
        strut(trim, (-4.4, -3.8 + k * 0.9, 3.4), (-4.4, -3.6 + k * 0.9, 0.6), 0.14)


@template("RamPenChute", WOOD=2200, STONE=900)
def ram_pen_chute(t):
    """A ram pen of dry-stone footings and timber hurdles, a gate, and a slatted timber chute ramping up its side
    for loading the rams."""
    wood, stone = t.bm("WOOD"), t.bm("STONE")
    w, d = 12.0, 9.0
    rng = random.Random(2811)
    for (x0, y0, x1, y1) in ((-w / 2, -d / 2, w / 2, -d / 2), (-w / 2, d / 2, w / 2, d / 2), (w / 2, -d / 2, w / 2, d / 2)):
        length = math.hypot(x1 - x0, y1 - y0)
        n = max(2, int(length / 3))
        for k in range(n + 1):
            f = k / n
            box(wood, (0.5, 0.5, 4.2), T((x0 + (x1 - x0) * f, y0 + (y1 - y0) * f, 2.1)))
        for z in (1.2, 2.4, 3.6):
            strut(wood, (x0, y0, z), (x1, y1, z), 0.24)
        for k in range(n):
            f = (k + 0.5) / n
            ground_rock(stone, (2.6, 1.2, 0.8), (x0 + (x1 - x0) * f, y0 + (y1 - y0) * f, -0.2), seed=2812 + k + int(x0 * 3 + y0), roughness=0.3, subdiv=1)
    # The gate on the west side, half open.
    strut(wood, (-w / 2, -d / 2, 0.2), (-w / 2, -d / 2, 4.2), 0.5)
    strut(wood, (-w / 2, d / 2, 0.2), (-w / 2, d / 2, 4.2), 0.5)
    for z in (1.4, 2.8):
        strut(wood, (-w / 2, -d / 2, z), (-w / 2 - 3.0, -d / 2 + 2.6, z), 0.24)
    # The chute: two side rails ramping up from the ground to a deck on the east side, slats between.
    for side in (-1.2, 1.2):
        strut(wood, (w / 2 + 7.0, side, 0.2), (w / 2 + 0.5, side, 3.4), 0.35)
        strut(wood, (w / 2 + 7.0, side, 1.6), (w / 2 + 0.5, side, 4.8), 0.24)
    for k in range(6):
        f = k / 5
        box(wood, (0.6, 2.6, 0.18), T((w / 2 + 7.0 - f * 6.5, 0, 0.3 + f * 3.1)))
    for side in (-1.2, 1.2):
        box(wood, (0.4, 0.4, 3.4), T((w / 2 + 0.6, side, 1.7)))


@template("CapacitorCask", WOOD=900, METAL=900, ACCENT=300, GLOW=200)
def capacitor_cask(t):
    """A storm-charged capacitor cask: a stout iron-hooped barrel bound in copper coil, a copper terminal post on
    its lid tipped with violet static."""
    wood, metal, accent, glow = (t.bm(r) for r in ("WOOD", "METAL", "ACCENT", "GLOW"))
    cone(wood, 1.6, 1.9, 2.2, 14, T((0, 0, 0)))
    cone(wood, 1.9, 1.6, 2.2, 14, T((0, 0, 2.2)))
    for z in (0.4, 2.2, 4.0):
        ring_mesh(accent, 1.65 + (0.25 if z == 2.2 else 0.0), 0.12, 16, T((0, 0, z)), tube_segs=4)
    pts = []
    for k in range(40):
        a = k * 0.55
        pts.append((math.cos(a) * 1.95, math.sin(a) * 1.95, 0.9 + k * 0.07))
    tube(metal, pts, [0.11] * len(pts), 4, cap=False)
    cyl_z(metal, 0.22, 2.2, (0, 0, 4.4), segs=6)
    ring_mesh(metal, 0.45, 0.1, 10, T((0, 0, 5.6)), tube_segs=4)
    uvsphere(glow, 0.38, T((0, 0, 6.8)), 8, 6)


@template("LonghouseRuin", STONE=3600, MOSS=1400, WOOD=900)
def longhouse_ruin(t):
    """A ruined Kairnfolk longhouse: long, low dry-stone walls with rounded ends, one end tumbled, a doorway with
    a lintel stone, a couple of charred roof timbers still leaning across, turf creeping over everything."""
    stone, moss, wood = t.bm("STONE"), t.bm("MOSS"), t.bm("WOOD")
    rng = random.Random(2821)
    L, W = 26.0, 10.0
    # The walls as an elongated ring of stones, highest along the sides, broken at the west end.
    n = 46
    for k in range(n):
        a = 2 * math.pi * k / n
        x, y = math.cos(a) * L / 2, math.sin(a) * W / 2
        if x < -L * 0.3 and abs(y) < W * 0.35:
            continue  # the tumbled end
        h = 3.6 if abs(math.sin(a)) > 0.5 else 2.6
        if 0.15 < a < 0.45:
            continue  # the doorway on the south-east
        for row in range(int(h / 1.1)):
            slab_stone(stone, (2.0, 1.4, 1.2), (x, y, 0.6 + row * 1.05), rot_z=a + math.pi / 2, seed=2822 + k * 7 + row, roughness=0.18)
    box(stone, (4.0, 1.6, 0.9), T((math.cos(0.3) * L / 2, math.sin(0.3) * W / 2, 3.4)) @ R(0.3 + math.pi / 2, 4, "Z"))
    for k in range(6):
        ground_rock(stone, (rng.uniform(1.6, 2.8),) * 2 + (1.2,), (-L / 2 - rng.uniform(0, 4), rng.uniform(-3, 3), -0.2), seed=2860 + k, roughness=0.3, subdiv=1)
    for x in (-4.0, 3.0):
        strut(wood, (x, -W / 2 + 0.5, 3.6), (x + 1.5, W / 2 - 1.5, 0.3), 0.35)
    for k in range(10):
        ground_rock(moss, (rng.uniform(2.5, 5), rng.uniform(2, 3.5), 0.7), (rng.uniform(-L / 2, L / 2), rng.uniform(-W / 2 - 1, W / 2 + 1), rng.uniform(0, 2.6)), seed=2870 + k, roughness=0.3, subdiv=1)


@template("InnerGateArch", STONE=4200, ACCENT=500, MOSS=700, METAL=400, GLOW=200)
def inner_gate_arch(t):
    """An inner rampart gate-arch spanning a path: two massive coursed dry-stone piers 50 studs apart (centre to
    centre) carrying a voussoir arch whose underside clears 20 studs, a verdigris band and a copper forked-bolt
    keystone."""
    stone, accent, moss, metal, glow = (t.bm(r) for r in ("STONE", "ACCENT", "MOSS", "METAL", "GLOW"))
    span, pier = 50.0, 6.0
    for sx in (-1, 1):
        x = sx * span / 2
        box(stone, (pier, pier, 21.0), T((x, 0, 10.5)), bevel=0.4)
        rng = random.Random(2881 + sx)
        for row in range(16):
            z = 0.6 + row * 1.3
            for side in (-1, 1):
                slab_stone(stone, (pier * 0.55, 0.8, 1.2), (x + rng.uniform(-1.2, 1.2), side * pier / 2, z), seed=2882 + row * 11 + sx * 3 + side, roughness=0.15)
        box(accent, (pier + 0.5, pier + 0.5, 0.5), T((x, 0, 14.0)))
        for k in range(3):
            centred_rock(moss, (2.6, 2.0, 0.6), T((x + (k - 1) * 1.6, 0, 21.2)), seed=2890 + k + sx * 5, roughness=0.3, subdiv=1)
    # The arch: wedge voussoirs round a half-ellipse from pier head to pier head.
    n = 17
    for k in range(n):
        a0, a1 = math.pi * k / n, math.pi * (k + 1) / n
        am = (a0 + a1) / 2
        rx, rz = span / 2, 9.0
        x, z = -math.cos(am) * rx, 20.5 + math.sin(am) * rz
        # Each voussoir lies along the arch's curve (tangent (rx sin a, rz cos a) in the XZ plane).
        tangent = math.atan2(rz * math.cos(am), rx * math.sin(am))
        box(stone, (4.2, pier - 0.6, 2.8), T((x, 0, z + 1.2)) @ R(-tangent, 4, "Y"))
    # Keystone with a copper forked bolt.
    box(stone, (3.6, pier, 4.2), T((0, 0, 31.0)))
    bolt(metal, (-0.4, -pier / 2 - 0.2, 29.4), 3.6, 0.9, 0.35, segs=3)
    bolt(glow, (-0.4, -pier / 2 - 0.35, 29.6), 3.2, 0.8, 0.12, segs=3)


@template("CopperCableMast", WOOD=1400, METAL=900, ACCENT=300, STONE=700)
def copper_cable_mast(t):
    """A cable mast: a tall timber pole on a cairn footing, braced, with a copper crossarm and two insulator
    knobs that carry the braided grounding cables 30 studs up."""
    wood, metal, accent, stone = (t.bm(r) for r in ("WOOD", "METAL", "ACCENT", "STONE"))
    for k in range(7):
        a = 2 * math.pi * k / 7
        ground_rock(stone, (2.0, 1.8, 1.6), (math.cos(a) * 1.8, math.sin(a) * 1.8, -0.2), seed=2901 + k, roughness=0.25, subdiv=1)
    cone(wood, 0.7, 0.5, 31.0, 8, T((0, 0, 0)))
    for k in range(3):
        a = 2 * math.pi * k / 3
        strut(wood, (0, 0, 10.0), (math.cos(a) * 4.0, math.sin(a) * 4.0, 0), 0.3)
    box(metal, (7.0, 0.45, 0.45), T((0, 0, 29.5)))
    for sx in (-1, 1):
        cyl_z(accent, 0.45, 0.9, (sx * 3.0, 0, 29.7), segs=8)
        uvsphere(metal, 0.35, T((sx * 3.0, 0, 30.9)), 6, 4)


if __name__ == "__main__":
    kit, manifest = build_kit("ThunderF27Kit", F27_TEMPLATES, DEFAULT_BUDGET)
    export_kit(kit, manifest, OUT_DIR, "ThunderF27Kit")
    render_previews(kit, F27_TEMPLATES, OUT_DIR)
    print(json.dumps(manifest, indent=2))
