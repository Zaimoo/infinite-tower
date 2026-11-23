"""
Thunder Highlands Floor 28 (Skybridge Cliffs) sculpted assets, generated in headless Blender.

Inspired by the Skybridge Cliffs reference art (reference/Thunder Highlands 28.jpg): granite needles rising
sheer out of a sea of storm cloud, joined by the Kairnfolk's rope-and-copper suspension skybridges. On the
summit two copper-banded crown towers lean their heads together with lightning arcing in the gap between
them. Freestanding sea-stack spires, sculpted cloud banks, heavy cable capstans and an A-frame supply windlass
on the near ledge, copper grounding chains hanging down the needle faces, a snapped skybridge stub, fulgurite
spires fused by lightning strikes, an anemometer mast, the Storm Roc's talon nest and shed feathers,
skybridge waystones and squall-horn perches.

1 Blender unit = 1 stud, standing on z = 0, front facing -Y in Blender / +Z in Roblox, one mesh object per colour
role named "<Template>__<ROLE>". Every piece stands on its origin (rock() lifts its rocks onto their base; see the
note in generate_thunder_f26_kit.py), except CliffGroundingChain, which hangs DOWN from its origin (its anchor
plate is at z = 0).

Roles (TowerSetPieces passes the Kairnfolk override): STONE granite and slate, MOSS turf, METAL hammered copper,
ACCENT verdigris, WOOD weathered timber, TRIM dark slate, iron and rope, ALT cloud and feather vane, GLOW violet
storm light, FOLIAGE pine needles, CRYSTAL fulgurite and storm glass.

Outputs (assets-source/tower/thunder_f28_kit/): ThunderF28Kit.blend, ThunderF28Kit.fbx, manifest.json,
previews/kit_sheet_1.png.

Run:
    blender.exe --background --factory-startup --python tools/blender/generate_thunder_f28_kit.py
"""
import bpy, bmesh, math, os, json, runpy, random
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT_DIR = os.path.join(ROOT, "assets-source", "tower", "thunder_f28_kit")

# Shared primitives and helpers from the Floor 26 generator (which takes the pipeline from Floor 21's).
f26 = runpy.run_path(os.path.join(HERE, "generate_thunder_f26_kit.py"))
box, cone, uvsphere, tube, ring_mesh = f26["box"], f26["cone"], f26["uvsphere"], f26["tube"], f26["ring_mesh"]
cyl_x, cyl_y, cyl_z, strut = f26["cyl_x"], f26["cyl_y"], f26["cyl_z"], f26["strut"]
ground_rock, centred_rock, slab_stone, bolt = f26["ground_rock"], f26["centred_rock"], f26["slab_stone"], f26["bolt"]
build_kit, export_kit, render_previews = f26["build_kit"], f26["export_kit"], f26["render_previews"]
T = Matrix.Translation
R = Matrix.Rotation

DEFAULT_BUDGET = 3500
# The hanging pieces stand on their lowest point: the chain's anchor plate and the stub's deck are this high.
CHAIN_TOP = 42.3
STUB_DECK = 18.1
F28_TEMPLATES = {}


def template(name, **budget):
    def deco(fn):
        F28_TEMPLATES[name] = (fn, budget)
        return fn
    return deco


def coursed_block(stone, w, d, z0, h, seed, course=1.6, cx=0.0, cy=0.0):
    """A square dry-stone shaft w by d (centred on cx, cy) from z0 up h, laid in staggered courses of dressed
    stones on a core."""
    box(stone, (w - 0.5, d - 0.5, h), T((cx, cy, z0 + h / 2)))
    rng = random.Random(seed)
    rows = max(2, int(h / course))
    for row in range(rows):
        z = z0 + (row + 0.5) * h / rows
        for side in range(4):
            along = w if side % 2 == 0 else d
            across = d if side % 2 == 0 else w
            n = max(2, int(along / 2.6))
            for k in range(n):
                f = (k + 0.5 + (row % 2) * 0.35) / n - 0.5
                if abs(f) > 0.5:
                    continue
                pos = f * along
                at = (pos, -across / 2, z) if side == 0 else (across / 2, pos, z) if side == 1 else (-pos, across / 2, z) if side == 2 else (-across / 2, -pos, z)
                rot = (0, math.pi / 2, math.pi, -math.pi / 2)[side]
                at = (at[0] + cx, at[1] + cy, at[2])
                slab_stone(stone, (along / n + 0.3, 0.9, h / rows * 0.92), at, rot_z=rot + rng.uniform(-0.03, 0.03), seed=seed + row * 53 + side * 11 + k, roughness=0.12)


def cone_along(bm, r1, r2, base, tip, segs=12):
    """A truncated cone from base (radius r1) to tip (radius r2)."""
    a, b = Vector(base), Vector(tip)
    d = b - a
    q = d.normalized().to_track_quat("Z", "Y").to_matrix().to_4x4()
    cone(bm, r1, r2, d.length, segs, T(a) @ q)


def lift_all(t, dz):
    """Raises every role mesh of a template by dz (a hanging piece re-anchored on its lowest point)."""
    for bm in t.meshes.values():
        bmesh.ops.translate(bm, vec=Vector((0, 0, dz)), verts=list(bm.verts))


def hanging_rope(bm, a, b, sag, thick, segs=8):
    """A rope from a to b sagging sag studs at its middle."""
    a, b = Vector(a), Vector(b)
    prev = a
    for k in range(1, segs + 1):
        f = k / segs
        p = a.lerp(b, f) - Vector((0, 0, sag * 4 * f * (1 - f)))
        strut(bm, prev, p, thick)
        prev = p


@template("CrownAnchorTower", STONE=9000, METAL=2200, ACCENT=900, TRIM=900, GLOW=500, MOSS=600)
def crown_anchor_tower(t):
    """One of the twin crown towers on the summit: a tall tapering dry-stone shaft girt with broad copper bands,
    a corbelled crown of merlons, and a stone half-arch springing from its head toward +X (its twin, turned
    round, reaches back), ending in a copper cable saddle and a forked lightning horn. Placed in pairs."""
    stone, metal, accent, trim, glow, moss = (t.bm(r) for r in ("STONE", "METAL", "ACCENT", "TRIM", "GLOW", "MOSS"))
    # A rough rubble footing.
    for k in range(10):
        a = 2 * math.pi * k / 10
        ground_rock(stone, (4.0, 3.4, 2.4), (math.cos(a) * 5.6, math.sin(a) * 5.6, -0.4), seed=2801 + k, roughness=0.25, subdiv=1)
    # Three stepped shafts, each a little narrower.
    stages = ((11.0, 0.0, 22.0), (9.6, 22.0, 22.0), (8.4, 44.0, 16.0))
    for i, (w, z0, h) in enumerate(stages):
        coursed_block(stone, w, w, z0, h, 2811 + i * 37)
        # A broad copper band near the top of each stage, verdigris trim lines either side.
        zb = z0 + h * 0.72
        box(metal, (w + 0.5, w + 0.5, 1.6), T((0, 0, zb)))
        for dz in (-1.0, 1.0):
            box(accent, (w + 0.7, w + 0.7, 0.3), T((0, 0, zb + dz)))
        # Dark window slits on the front and back.
        for sy in (-1, 1):
            box(trim, (1.0, 0.6, 3.0), T((0, sy * w / 2, z0 + h * 0.4)))
    # The crown: a corbel course and merlons.
    top = 60.0
    box(stone, (10.2, 10.2, 1.4), T((0, 0, top + 0.7)))
    for k in range(4):
        for j in (-1, 0, 1):
            for sx, sy in (((j * 3.2), -4.6), ((j * 3.2), 4.6), (-4.6, (j * 3.2)), (4.6, (j * 3.2))):
                if (k == 0 and sy == -4.6) or (k == 1 and sy == 4.6) or (k == 2 and sx == -4.6) or (k == 3 and sx == 4.6):
                    box(stone, (1.8, 1.8, 2.4), T((sx, sy, top + 2.6)))
    ring_mesh(moss, 3.6, 0.6, 14, T((0, 0, top + 1.6)), tube_segs=4)
    # The half-arch: voussoirs springing from the crown's +X face, rising then reaching out toward the twin.
    reach, rise = 16.0, 9.0
    prev = None
    n = 9
    for k in range(n + 1):
        f = k / n
        x = 4.4 + reach * f
        z = top - 6.0 + rise * math.sin(f * math.pi * 0.62)
        p = Vector((x, 0, z))
        if prev is not None:
            d = p - prev
            q = d.normalized().to_track_quat("Z", "Y").to_matrix().to_4x4()
            box(stone, (3.6 - f * 1.0, 3.4 - f * 0.8, d.length + 0.6), T((prev + p) / 2) @ q)
        prev = p
    # Copper bands round the arch and the cable saddle at its tip, a forked horn and a violet arc node.
    tip = prev
    for f in (0.35, 0.7):
        x = 4.4 + reach * f
        z = top - 6.0 + rise * math.sin(f * math.pi * 0.62)
        ring_mesh(metal, 1.9, 0.3, 12, T((x, 0, z)) @ R(math.pi / 2, 4, "Y"), tube_segs=4)
    cyl_y(metal, 1.4, 3.0, (tip.x + 0.6, 0, tip.z + 0.4), segs=12)
    for side in (-1, 1):
        strut(metal, (tip.x + 0.6, 0, tip.z + 1.2), (tip.x + 2.6, side * 1.2, tip.z + 5.2), 0.3)
    uvsphere(glow, 1.0, T((tip.x + 2.2, 0, tip.z + 1.0)), 10, 8)
    bolt(glow, (tip.x + 1.6, 0, tip.z - 3.6), 4.0, 0.5, 0.12)
    # A copper lightning rod on the crown.
    cyl_z(metal, 0.35, 10.0, (-2.0, 0, top + 1.4), segs=8, r2=0.15)
    for side in (-1, 1):
        strut(metal, (-2.0, 0, top + 8.0), (-2.0 + side * 1.4, 0, top + 12.0), 0.2)


@template("SeaStackSpire", STONE=7000, MOSS=900, FOLIAGE=900, WOOD=300)
def sea_stack_spire(t):
    """A freestanding granite needle out of the cloud sea: a cluster of tall jointed basalt-like columns, square
    in section and leaning together, broken off at staggered heights, a tuft of turf and a wind-bent bonsai pine
    clinging to the tallest top (about 68 studs)."""
    stone, moss, foliage, wood = (t.bm(r) for r in ("STONE", "MOSS", "FOLIAGE", "WOOD"))
    rng = random.Random(2821)
    columns = ((0.0, 0.0, 66.0, 6.2), (4.6, 1.4, 50.0, 4.8), (-4.2, 1.8, 56.0, 5.0), (1.2, -4.4, 44.0, 4.6),
        (-2.0, 4.6, 38.0, 4.2), (5.0, -3.4, 30.0, 4.0), (-5.4, -2.6, 24.0, 3.8))
    tallest = None
    for c, (x, y, h, w) in enumerate(columns):
        z = -2.0
        k = 0
        lean = Vector((-x * 0.02, -y * 0.02, 0))
        while z < h - 1.0:
            seg = min(rng.uniform(9.0, 15.0), h - z)
            f = z / h
            ww = w * (1.0 - 0.35 * f)
            at = Vector((x, y, 0)) + lean * z + Vector((0, 0, z + seg / 2))
            box(stone, (ww, ww * 0.92, seg - 0.35), T(at) @ R(rng.uniform(-0.06, 0.06) + c * 0.4, 4, "Z") @ R(rng.uniform(-0.03, 0.03), 4, "X"))
            z += seg
            k += 1
        top = Vector((x, y, 0)) + lean * z + Vector((0, 0, z))
        # A broken, tilted capstone on each column.
        box(stone, (w * 0.62, w * 0.55, 1.4), T(top + Vector((0, 0, 0.3))) @ R(0.4 + c, 4, "Z") @ R(0.18, 4, "X"))
        if tallest is None:
            tallest = top
    # Fallen blocks round the foot.
    for k in range(6):
        a = 2 * math.pi * k / 6 + 0.3
        ground_rock(stone, (4.4, 3.6, 2.6), (math.cos(a) * 8.0, math.sin(a) * 8.0, -0.4), seed=2830 + k, roughness=0.2, subdiv=1)
    ground_rock(moss, (6.0, 5.0, 1.0), (tallest.x, tallest.y, tallest.z + 0.6), seed=2841, roughness=0.3, subdiv=1)
    base = tallest + Vector((1.0, 0, 1.0))
    tube(wood, [base, base + Vector((2.0, 0.3, 2.5)), base + Vector((5.5, 0.6, 3.6))], [0.6, 0.45, 0.25], 6)
    for j in range(3):
        at = base + Vector((3.0 + j * 1.6, 0.4, 3.4 + j * 0.3))
        centred_rock(foliage, (4.2 - j * 0.8, 3.2 - j * 0.5, 1.4), T(at), seed=2851 + j, roughness=0.3, subdiv=1)


@template("CloudBankLayer", ALT=5000)
def cloud_bank_layer(t):
    """A sculpted bank of storm cloud: a broad, low drift of overlapping billows, flat underneath and heaped
    into soft domes on top (about 64 by 40 studs, 13 high), for the cloud sea in the abyss."""
    alt = t.bm("ALT")
    rng = random.Random(2861)
    for k in range(26):
        x = rng.uniform(-26.0, 26.0)
        y = rng.uniform(-15.0, 15.0)
        edge = 1.0 - max(abs(x) / 30.0, abs(y) / 18.0)
        r = 5.0 + 6.0 * max(0.0, edge) + rng.uniform(-1.0, 1.5)
        z = r * 0.35 + rng.uniform(0.0, 2.0) * max(0.0, edge)
        uvsphere(alt, 1.0, T((x, y, z)) @ Matrix.Diagonal((r * 1.25, r, r * 0.62, 1.0)), 10, 6)
    # Its underside sinks a little under the origin (into the abyss floor), within the kit's 3 studs.
    lift_all(t, 0.6)


@template("CableWinchCapstan", METAL=2400, WOOD=1600, STONE=900, ACCENT=500, TRIM=600)
def cable_winch_capstan(t):
    """A heavy cable winch that tensions a skybridge: a copper-banded timber drum wound with braided copper cable
    on a stone-weighted timber frame, a pawl ratchet wheel, four capstan bars and anchor bolts."""
    metal, wood, stone, accent, trim = (t.bm(r) for r in ("METAL", "WOOD", "STONE", "ACCENT", "TRIM"))
    # The frame: two timber cheeks on sill beams weighted with stones.
    for sx in (-1, 1):
        box(wood, (1.2, 9.0, 1.0), T((sx * 4.4, 0, 0.5)))
        box(wood, (1.0, 1.4, 6.6), T((sx * 4.4, 0, 3.8)))
        strut(wood, (sx * 4.4, -3.8, 1.0), (sx * 4.4, 0, 6.2), 0.7)
        strut(wood, (sx * 4.4, 3.8, 1.0), (sx * 4.4, 0, 6.2), 0.7)
        for sy in (-1, 1):
            ground_rock(stone, (2.4, 2.0, 1.6), (sx * 4.4, sy * 4.2, 0.6), seed=2871 + (sx + 1) * 3 + sy, roughness=0.25, subdiv=1)
    # The drum with its wound cable.
    cyl_x(wood, 2.2, 7.4, (0, 0, 5.2), segs=18)
    for k in range(9):
        ring_mesh(metal, 2.35, 0.22, 18, T((-3.0 + k * 0.75, 0, 5.2)) @ R(math.pi / 2, 4, "Y"), tube_segs=4)
    for x in (-3.7, 3.7):
        ring_mesh(accent, 2.3, 0.3, 18, T((x, 0, 5.2)) @ R(math.pi / 2, 4, "Y"), tube_segs=4)
    # Ratchet wheel and pawl on the +X cheek, capstan bars through the -X end.
    cyl_x(trim, 2.9, 0.5, (5.3, 0, 5.2), segs=14)
    strut(trim, (5.4, -3.2, 2.0), (5.4, -1.8, 4.4), 0.35)
    for k in range(4):
        a = math.pi / 4 + k * math.pi / 2
        strut(wood, (-5.4, 0, 5.2), (-5.4, math.cos(a) * 4.4, 5.2 + math.sin(a) * 4.4), 0.35)
    # Cable paid out forward and an anchor bolt plate.
    strut(metal, (0, -2.0, 5.6), (0, -9.0, 4.6), 0.4)
    box(trim, (3.0, 1.6, 0.4), T((0, -9.4, 0.2)))
    cyl_z(metal, 0.5, 1.4, (0, -9.4, 0.2), segs=8)


@template("SupplyHoistWindlass", WOOD=2400, METAL=1200, TRIM=700, STONE=600, ALT=300)
def supply_hoist_windlass(t):
    """The supply hoist on the ledge: a timber A-frame jib leaning out over the drop (-Y), a pulley block at its
    head, rope down to a hanging crate, a cable drum with a crank between its legs, and stone ballast."""
    wood, metal, trim, stone, alt = (t.bm(r) for r in ("WOOD", "METAL", "TRIM", "STONE", "ALT"))
    head = Vector((0, -7.0, 16.0))
    for sx in (-1, 1):
        strut(wood, (sx * 4.6, 2.0, 0), head + Vector((sx * 0.6, 0, 0)), 0.75)
        strut(wood, (sx * 4.6, 2.0, 0), (sx * 4.2, 8.0, 0.4), 0.55)
    strut(wood, (0, 8.0, 0.4), head + Vector((0, 0.4, -0.4)), 0.55)
    strut(wood, (-4.0, 0.4, 5.0), (4.0, 0.4, 5.0), 0.45)
    # The pulley block and its sheave.
    cyl_x(metal, 1.1, 1.0, head + Vector((0, 0, -1.0)), segs=12)
    box(trim, (1.4, 0.6, 2.4), T(head + Vector((0, 0, -0.6))))
    # Rope down to a hanging crate.
    strut(trim, head + Vector((0, -1.0, -1.8)), (0, -8.0, 4.6), 0.14)
    box(wood, (3.2, 3.2, 3.0), T((0, -8.0, 3.0)))
    for z in (1.8, 4.2):
        box(trim, (3.4, 3.4, 0.25), T((0, -8.0, z)))
    box(alt, (2.8, 2.8, 0.3), T((0, -8.0, 4.6)))
    # The drum and crank, the rope running up to the block.
    cyl_x(wood, 1.4, 7.0, (0, 3.0, 3.0), segs=14)
    for x in (-2.0, 0.0, 2.0):
        ring_mesh(metal, 1.5, 0.18, 14, T((x, 3.0, 3.0)) @ R(math.pi / 2, 4, "Y"), tube_segs=4)
    strut(metal, (3.8, 3.0, 3.0), (4.6, 3.0, 4.8), 0.25)
    strut(metal, (4.6, 3.0, 4.8), (5.6, 3.0, 4.8), 0.2)
    strut(trim, (0, 3.0, 4.4), head + Vector((0, 0.6, -0.6)), 0.12)
    for k in range(4):
        ground_rock(stone, (2.0, 1.8, 1.4), (-3.0 + k * 2.0, 8.6, 0.2), seed=2881 + k, roughness=0.25, subdiv=1)


@template("ShedRocFeather", ALT=1600, TRIM=600, GLOW=300)
def shed_roc_feather(t):
    """A feather shed by the Storm Roc, lying on its side: a long tapering quill and a broad curved vane of
    barbs (slate-grey, its tip edged violet), about 16 studs long."""
    alt, trim, glow = (t.bm(r) for r in ("ALT", "TRIM", "GLOW"))
    pts = [(-8.0 + 16.0 * f, 0, 0.5 + 0.9 * math.sin(f * math.pi)) for f in (k / 8 for k in range(9))]
    tube(trim, pts, [0.32 - 0.03 * k for k in range(9)], 6)
    for k in range(14):
        f = (k + 1) / 15
        x = -6.0 + 13.5 * f
        z = 0.5 + 0.9 * math.sin((x + 8.0) / 16.0 * math.pi)
        width = 3.6 * math.sin(f * math.pi) ** 0.6 + 0.4
        for side in (-1, 1):
            box(alt, (1.1, width, 0.12), T((x + 0.25 * side, side * width / 2, z)) @ R(side * math.radians(10), 4, "X") @ R(side * math.radians(-14), 4, "Z"))
    box(glow, (1.6, 2.2, 0.1), T((7.2, 0, 1.5)) @ R(math.radians(10), 4, "Y"))


@template("TalonNestPlatform", WOOD=4200, ALT=900, STONE=900, TRIM=400)
def talon_nest_platform(t):
    """The Storm Roc's talon nest: a broad ring of woven pine logs and branches heaped on a rock ledge, shed
    feathers caught in it and a few cracked slate shards in the bowl (about 22 studs across)."""
    wood, alt, stone, trim = (t.bm(r) for r in ("WOOD", "ALT", "STONE", "TRIM"))
    rng = random.Random(2891)
    for k in range(7):
        a = 2 * math.pi * k / 7
        ground_rock(stone, (5.0, 4.0, 1.8), (math.cos(a) * 7.0, math.sin(a) * 7.0, -0.4), seed=2892 + k, roughness=0.25, subdiv=1)
    for layer in range(3):
        n = 16
        r = 9.5 - layer * 1.0
        for k in range(n):
            a0 = 2 * math.pi * k / n + layer * 0.3 + rng.uniform(-0.1, 0.1)
            a1 = a0 + 2 * math.pi / n * 1.8
            z = 1.0 + layer * 1.3
            strut(wood, (math.cos(a0) * r, math.sin(a0) * r, z + rng.uniform(-0.3, 0.3)), (math.cos(a1) * (r + 1.5), math.sin(a1) * (r + 1.5), z + rng.uniform(-0.3, 0.6)), 0.7 - layer * 0.12)
    for k in range(10):
        a = rng.uniform(0, 2 * math.pi)
        strut(trim, (math.cos(a) * 9.0, math.sin(a) * 9.0, 3.0), (math.cos(a) * 12.5, math.sin(a) * 12.5, 4.2 + rng.uniform(0, 1.4)), 0.2)
    for k in range(5):
        a = 2 * math.pi * k / 5 + 0.4
        box(alt, (5.0, 1.6, 0.12), T((math.cos(a) * 8.6, math.sin(a) * 8.6, 4.4)) @ R(a, 4, "Z") @ R(math.radians(30), 4, "X"))
    box(stone, (14.0, 14.0, 0.8), T((0, 0, 0.6)))


@template("FulguriteSpireTall", CRYSTAL=3000, GLOW=900, STONE=900, TRIM=500)
def fulgurite_spire_tall(t):
    """A tall fulgurite spire: lightning-fused glass bursting out of the rock in a branching cluster of twisted,
    hollow-looking tubes, the tallest about 40 studs, violet light in their cores."""
    crystal, glow, stone, trim = (t.bm(r) for r in ("CRYSTAL", "GLOW", "STONE", "TRIM"))
    rng = random.Random(2901)
    for k in range(6):
        a = 2 * math.pi * k / 6
        ground_rock(stone, (4.6, 3.8, 2.4), (math.cos(a) * 4.4, math.sin(a) * 4.4, -0.4), seed=2902 + k, roughness=0.3, subdiv=1)
    box(trim, (7.0, 7.0, 1.2), T((0, 0, 0.4)) @ R(0.3, 4, "Z"))
    shoots = ((0.0, 0.0, 40.0, 1.9), (3.0, 1.2, 26.0, 1.3), (-2.6, -1.0, 30.0, 1.4), (1.2, -2.8, 18.0, 1.0), (-1.8, 2.6, 21.0, 1.0))
    for i, (x, y, h, r) in enumerate(shoots):
        pts, radii = [], []
        for k in range(8):
            f = k / 7
            pts.append((x + math.sin(f * 4.0 + i) * 1.1 + x * f * 0.6, y + math.cos(f * 3.0 + i) * 0.9 + y * f * 0.6, 0.8 + h * f))
            radii.append(r * (1.0 - 0.85 * f) + 0.12)
        tube(crystal, pts, radii, 7)
        tube(glow, pts[1:-1], [rr * 0.42 for rr in radii[1:-1]], 5)
        # Short side branches forking off.
        for k in (3, 5):
            p = Vector(pts[k])
            d = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), 0.8)).normalized()
            strut(crystal, p, p + d * h * 0.18, radii[k] * 0.45)


@template("AnemometerMast", METAL=1600, WOOD=900, ACCENT=500, STONE=600, TRIM=300)
def anemometer_mast(t):
    """A Kairnfolk weather mast: a copper tripod mast on a cairn footing carrying a four-cup anemometer, a
    forked-tail wind vane and a small storm bell, about 24 studs tall."""
    metal, wood, accent, stone, trim = (t.bm(r) for r in ("METAL", "WOOD", "ACCENT", "STONE", "TRIM"))
    for k in range(6):
        a = 2 * math.pi * k / 6
        ground_rock(stone, (2.2, 1.8, 1.4), (math.cos(a) * 2.4, math.sin(a) * 2.4, -0.2), seed=2911 + k, roughness=0.25, subdiv=1)
    for k in range(3):
        a = 2 * math.pi * k / 3
        strut(metal, (math.cos(a) * 3.2, math.sin(a) * 3.2, 0), (0, 0, 16.0), 0.35)
    strut(metal, (0, 0, 14.0), (0, 0, 22.0), 0.3)
    for z in (5.0, 10.0):
        ring_mesh(wood, 3.2 - z * 0.18, 0.18, 12, T((0, 0, z)), tube_segs=4)
    # The anemometer: four arms and cups.
    for k in range(4):
        a = k * math.pi / 2
        end = Vector((math.cos(a) * 3.2, math.sin(a) * 3.2, 22.0))
        strut(metal, (0, 0, 22.0), end, 0.14)
        uvsphere(accent, 0.7, T(end + Vector((-math.sin(a) * 0.5, math.cos(a) * 0.5, 0))) @ Matrix.Diagonal((1.0, 1.0, 0.7, 1.0)), 8, 6)
    # The wind vane below it.
    strut(metal, (-3.6, 0, 19.0), (3.6, 0, 19.0), 0.16)
    box(metal, (0.12, 2.2, 1.6), T((3.6, 0, 19.0)))
    for side in (-1, 1):
        box(accent, (1.8, 0.1, 0.9), T((-3.6, 0, 19.0)) @ R(side * math.radians(20), 4, "Z"))
    cone(trim, 0.9, 0.5, 1.2, 10, T((0, 0, 12.4)))


@template("CliffGroundingChain", METAL=2200, TRIM=700, ACCENT=300)
def cliff_grounding_chain(t):
    """A copper grounding chain bolted to a needle's lip and hanging down its face: an anchor plate on top,
    about 40 studs of heavy links and a braided cable hanging below it, and a weight at the end. It stands on
    the weight's foot (the anchor plate is CHAIN_TOP studs up): placed with its top at the lip, hanging over
    the drop."""
    metal, trim, accent = (t.bm(r) for r in ("METAL", "TRIM", "ACCENT"))
    box(trim, (3.4, 0.6, 2.2), T((0, 0, 0.3)))
    for x in (-1.2, 1.2):
        cyl_z(accent, 0.35, 0.7, (x, 0, 0.5), segs=6)
    n = 30
    for k in range(n):
        z = -0.8 - k * 1.32
        ring_mesh(metal, 0.62, 0.16, 10, T((0.2 * math.sin(k * 0.3), 0, z)) @ R((k % 2) * math.pi / 2, 4, "Z") @ R(math.pi / 2, 4, "X") @ Matrix.Diagonal((1.0, 1.6, 1.0, 1.0)), tube_segs=4)
    pts = [(1.6 + 0.4 * math.sin(k * 0.7), 0.3, -0.6 - k * 4.4) for k in range(10)]
    tube(metal, pts, [0.3] * 10, 6)
    uvsphere(trim, 1.0, T((0.2, 0, -41.0)) @ Matrix.Diagonal((1.0, 1.0, 1.3, 1.0)), 8, 6)
    lift_all(t, CHAIN_TOP - 0.6)


@template("SnappedBridgeStub", WOOD=2400, STONE=2400, METAL=1200, TRIM=500, ACCENT=300)
def snapped_bridge_stub(t):
    """A skybridge's broken end: twin copper-banded pylons on a stone footing, a few planks jutting out toward
    -Y and ending in a jagged snapped edge, a sagging hand rope, and its snapped main cables and loose planks
    dangling down into the mist. It stands on the dangling cables' ends: its deck is STUB_DECK studs up."""
    wood, stone, metal, trim, accent = (t.bm(r) for r in ("WOOD", "STONE", "METAL", "TRIM", "ACCENT"))
    box(stone, (16.0, 8.0, 3.0), T((0, 3.0, -1.0)))
    for sx in (-1, 1):
        coursed_block(stone, 3.6, 3.6, 0.0, 16.0, 2921 + sx, cx=sx * 6.0)
        for z in (4.0, 11.0):
            box(metal, (4.0, 4.0, 0.5), T((sx * 6.0, 0, z)))
        box(accent, (4.2, 4.2, 0.8), T((sx * 6.0, 0, 16.4)))
    # The deck stub: stringers and planks, the last ones broken short at ragged lengths.
    for sx in (-1, 1):
        strut(wood, (sx * 3.6, 2.0, 0.0), (sx * 3.6, -12.0, -0.6), 0.6)
    rng = random.Random(2925)
    for k in range(10):
        y = 1.0 - k * 1.5
        length = 8.0 if k < 6 else rng.uniform(2.5, 6.0)
        x0 = -4.0 if k < 6 else rng.uniform(-4.0, 0.0)
        box(wood, (length, 1.2, 0.2), T((x0 + length / 2, y, 0.1 - k * 0.05)) @ R(rng.uniform(-0.05, 0.05), 4, "Z"))
    # A dangling plank and the snapped cables hanging into the drop.
    box(wood, (5.0, 1.2, 0.2), T((1.0, -12.6, -3.0)) @ R(math.radians(70), 4, "X"))
    for sx in (-1, 1):
        hanging_rope(trim, (sx * 4.0, 0.0, 3.4), (sx * 4.0, -9.0, 2.4), 0.6, 0.12, 5)
        pts = [(sx * 5.0, -1.0, 15.0), (sx * 4.6, -5.0, 9.0), (sx * 4.0, -9.0, 1.0), (sx * 3.8, -11.0, -8.0), (sx * 4.2, -11.6, -18.0)]
        tube(metal, pts, [0.35, 0.33, 0.3, 0.28, 0.2], 6)
    lift_all(t, STUB_DECK)


@template("SkybridgeWaystone", STONE=1600, METAL=500, CRYSTAL=300, GLOW=200, MOSS=300)
def skybridge_waystone(t):
    """A thunder-glass waystone at a skybridge's bridgehead: a squat dressed granite pillar with a copper-bound
    storm-glass lens set in its face, glowing violet, and a turf cap."""
    stone, metal, crystal, glow, moss = (t.bm(r) for r in ("STONE", "METAL", "CRYSTAL", "GLOW", "MOSS"))
    ground_rock(stone, (4.4, 3.6, 1.4), (0, 0, -0.3), seed=2931, roughness=0.25, subdiv=1)
    # A dressed, slightly tapering pillar with a pitched top.
    cone(stone, 1.75, 1.35, 7.4, 4, T((0, 0, 0.4)) @ R(math.pi / 4, 4, "Z"))
    cone(stone, 1.45, 0.3, 1.2, 4, T((0, 0, 7.8)) @ R(math.pi / 4, 4, "Z"))
    ring_mesh(metal, 0.95, 0.2, 14, T((0, -1.45, 5.0)) @ R(math.pi / 2, 4, "X"), tube_segs=4)
    cyl_y(crystal, 0.8, 0.5, (0, -1.4, 5.0), segs=12)
    uvsphere(glow, 0.42, T((0, -1.6, 5.0)), 8, 6)
    ground_rock(moss, (1.8, 1.6, 0.5), (0.4, 0.3, 7.4), seed=2933, roughness=0.3, subdiv=1)


@template("SquallHornPerch", WOOD=1200, METAL=1400, ACCENT=500, STONE=600, ALT=200)
def squall_horn_perch(t):
    """A squall-herald perch: a tall timber pole in a cairn with a crossed perch bar on top for the storm birds,
    and two flared copper sound-horns turned out to the gorge, about 20 studs tall."""
    wood, metal, accent, stone, alt = (t.bm(r) for r in ("WOOD", "METAL", "ACCENT", "STONE", "ALT"))
    for k in range(6):
        a = 2 * math.pi * k / 6
        ground_rock(stone, (2.2, 1.8, 1.6), (math.cos(a) * 1.8, math.sin(a) * 1.8, -0.2), seed=2941 + k, roughness=0.25, subdiv=1)
    cone(wood, 0.6, 0.4, 20.0, 8, T((0, 0, 0)))
    strut(wood, (-4.0, 0, 19.0), (4.0, 0, 19.0), 0.35)
    strut(wood, (0, -2.5, 18.2), (0, 2.5, 18.2), 0.3)
    for sx in (-1, 1):
        neck = Vector((sx * 0.5, -0.3, 15.0))
        mouth = Vector((sx * 3.2, -3.6, 13.0))
        cone_along(metal, 0.3, 1.7, neck, mouth, 14)
        d = (mouth - neck).normalized()
        ring_mesh(accent, 1.72, 0.16, 14, T(mouth) @ d.to_track_quat("Z", "Y").to_matrix().to_4x4(), tube_segs=4)
        strut(metal, (0, 0, 15.6), neck, 0.2)
    box(alt, (0.1, 1.2, 4.0), T((0.5, 0, 16.0)))


if __name__ == "__main__":
    kit, manifest = build_kit("ThunderF28Kit", F28_TEMPLATES, DEFAULT_BUDGET)
    export_kit(kit, manifest, OUT_DIR, "ThunderF28Kit")
    render_previews(kit, F28_TEMPLATES, OUT_DIR)
    print(json.dumps(manifest, indent=2))
