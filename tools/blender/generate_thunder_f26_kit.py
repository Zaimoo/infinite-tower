"""
Thunder Highlands Floor 26 (Stormgrass Rise) sculpted assets, generated in headless Blender.

Inspired by the Stormgrass Rise reference art (reference/Thunder Highlands 26.jpg): a stormy highland moor of
dry-stone walls, a dolmen bell-gate on the entry trail flanked by cairns with copper forked-bolt capstones, a
shepherd's croft and a sheepfold with timber hurdles and sheep, a ruined post windmill on a knoll, rune standing
stones, wind-bent pines, prayer-flag lines, twin waterfalls down the headwall, a crater of violet storm crystals
and a great split granite tor crowned by a copper forked-bolt lightning totem.

1 Blender unit = 1 stud, standing on z = 0, front facing -Y in Blender / +Z in Roblox, one mesh object per colour
role named "<Template>__<ROLE>".

Roles (TowerSetPieces passes a Kairnfolk override for each):
    STONE  highland slate and granite      MOSS    turf, lichen and moss
    METAL  hammered copper                 ACCENT  verdigris, prayer flags (second dye)
    WOOD   weathered timber                TRIM    dark slate roofing, rope, iron
    ALT    wool, sailcloth, foam, flags    GLOW    electric violet storm light
    FOLIAGE pine needles, stormgrass       CRYSTAL storm crystal glass, falling water
    GOLD   prayer flags (third dye), bell bronze

Outputs (assets-source/tower/thunder_f26_kit/): ThunderF26Kit.blend, ThunderF26Kit.fbx, manifest.json,
previews/kit_sheet_1.png.

Run:
    blender.exe --background --factory-startup --python tools/blender/generate_thunder_f26_kit.py
"""
import bpy, bmesh, math, os, json, runpy, random
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT_DIR = os.path.join(ROOT, "assets-source", "tower", "thunder_f26_kit")

# Shared primitives and the kit pipeline (build_kit, export_kit, render_previews) from the Floor 21 generator.
f21 = runpy.run_path(os.path.join(HERE, "generate_infernal_f21_kit.py"))
Template = f21["Template"]
box, cone, uvsphere, tube, ring_mesh = f21["box"], f21["cone"], f21["uvsphere"], f21["tube"], f21["ring_mesh"]
reset_scene, finalize = f21["reset_scene"], f21["finalize"]
rock_clean, cyl_x, cyl_y, cyl_z = f21["rock_clean"], f21["cyl_x"], f21["cyl_y"], f21["cyl_z"]
strut = f21["strut"]
build_kit, export_kit, render_previews = f21["build_kit"], f21["export_kit"], f21["render_previews"]
T = Matrix.Translation
R = Matrix.Rotation

DEFAULT_BUDGET = 3500
F26_TEMPLATES = {}

# The storm blows from the north-west; down-wind is +X (east) and -Y (south, the front) in Blender. Pines and
# grass lean down-wind along +X: TowerSetPieces turns every leaning piece the same way.
WIND = Vector((1.0, 0.0, 0.0))


def template(name, **budget):
    def deco(fn):
        F26_TEMPLATES[name] = (fn, budget)
        return fn
    return deco


# Note: rock() (generate_tower_biome_kit.py) already lifts every rock by 0.3 x its height, so a flat-bottomed
# rock's base sits on its matrix's origin. A rock meant to be centred on a point is lowered by that much again.
def ground_rock(bm, size, at, seed, roughness=0.26, subdiv=2):
    """A rock of the given full size whose flattened base sits on at.z."""
    rock_clean(bm, size, T(at), seed=seed, roughness=roughness, subdiv=subdiv)


def centred_rock(bm, size, mat, seed, roughness=0.12, subdiv=2):
    """A rounded rock (no flattened base) centred on mat's origin."""
    rock_clean(bm, size, mat @ T((0, 0, -size[2] * 0.3)), seed=seed, roughness=roughness, subdiv=subdiv, flat_bottom=False)


def slab_stone(bm, size, at, rot_z=0.0, tilt=0.0, seed=0, roughness=0.12):
    """A flat-ish dressed stone (a squashed rock) centred at at, turned rot_z and tipped tilt."""
    centred_rock(bm, size, T(at) @ R(rot_z, 4, "Z") @ R(tilt, 4, "X"), seed=seed, roughness=roughness, subdiv=1)


def prism(bm, w, d, h, mat):
    """A gable roof volume: a w by d rectangle (X by Y) at z = 0 rising to a ridge along X at height h."""
    hx, hy = w / 2, d / 2
    v = [bm.verts.new(mat @ Vector(p)) for p in ((-hx, -hy, 0), (hx, -hy, 0), (hx, hy, 0), (-hx, hy, 0), (-hx, 0, h), (hx, 0, h))]
    for f in ((v[0], v[1], v[5], v[4]), (v[2], v[3], v[4], v[5]), (v[0], v[4], v[3]), (v[1], v[2], v[5]), (v[0], v[3], v[2], v[1])):
        bm.faces.new(f)


def bolt(bm, base, height, width, thick, mat=Matrix.Identity(4), segs=4, flip=1):
    """A forked lightning glyph: a zig-zag of flat tapering struts climbing height from base, in the XZ plane."""
    pts = [Vector(base)]
    for k in range(1, segs + 1):
        x = (width if (k % 2 == 1) else -width * 0.35) * flip
        pts.append(Vector(base) + Vector((x, 0, height * k / segs)))
    for k in range(len(pts) - 1):
        a, b = pts[k], pts[k + 1]
        d = b - a
        q = d.normalized().to_track_quat("Z", "Y").to_matrix().to_4x4()
        w = thick * (1.0 - 0.18 * k)
        box(bm, (w * 2.2, w, d.length + w), mat @ T((a + b) / 2) @ q)
    return pts[-1]


@template("ForkedBoltTotem", STONE=2400, METAL=2200, ACCENT=900, GLOW=600, MOSS=600)
def forked_bolt_totem(t):
    """The Kairnfolk forked-bolt lightning totem: a battered stepped cairn plinth, a tall tapering granite shaft
    bound by three hammered-copper grounding rings, and a copper head of twin crescent storm-blades round a
    central lightning spike, forked bolts glowing violet along the blades."""
    stone, metal, accent, glow, moss = (t.bm(r) for r in ("STONE", "METAL", "ACCENT", "GLOW", "MOSS"))
    # Stepped cairn plinth of rough stones.
    rng = random.Random(2601)
    for layer, (rad, n, h) in enumerate(((6.0, 9, 2.2), (4.6, 7, 2.0), (3.2, 5, 1.8))):
        z = sum(x[2] for x in ((6.0, 9, 2.2), (4.6, 7, 2.0), (3.2, 5, 1.8))[:layer])
        for k in range(n):
            a = 2 * math.pi * k / n + layer * 0.4
            slab_stone(stone, (rad * 0.9, rad * 0.75, h * 1.1), (math.cos(a) * rad * 0.55, math.sin(a) * rad * 0.55, z + h * 0.5), rot_z=a, seed=2602 + layer * 20 + k)
    for k in range(6):
        a = rng.uniform(0, 2 * math.pi)
        ground_rock(moss, (2.6, 2.2, 0.8), (math.cos(a) * 5.4, math.sin(a) * 5.4, 0), seed=2640 + k, roughness=0.3, subdiv=1)
    base = 6.0
    shaft_h = 24.0
    cone(stone, 2.3, 1.5, shaft_h, 4, T((0, 0, base)) @ R(math.pi / 4, 4, "Z"))
    for k, z in enumerate((base + 5.0, base + 11.0, base + 17.0)):
        rr = 2.3 - 0.8 * (z - base) / shaft_h
        ring_mesh(metal, rr * 1.48, 0.42, 20, T((0, 0, z)), tube_segs=6)
        ring_mesh(accent, rr * 1.48, 0.2, 20, T((0, 0, z + 0.6)), tube_segs=4)
    top = base + shaft_h
    # Copper collar and the head.
    cone(metal, 2.0, 1.3, 2.2, 12, T((0, 0, top - 0.6)))
    cone(metal, 0.9, 0.05, 11.0, 8, T((0, 0, top + 1.4)))
    for sx in (-1, 1):
        # A crescent storm-blade: a dense fan of flat vanes from the collar, merging into one broad blade whose
        # outer edge curves from low and wide to a high point, like a double axe.
        for k in range(11):
            ang = math.radians(-20 + k * 10.5)
            length = 9.5 - abs(k - 5) * 0.55
            p0 = Vector((sx * 0.8, 0, top + 2.4))
            p1 = p0 + Vector((sx * math.cos(ang) * length, 0, math.sin(ang) * length))
            box(metal if k % 3 else accent, (length, 0.7, 1.55), T((p0 + p1) / 2) @ R(-sx * ang, 4, "Y") @ R(0 if sx > 0 else math.pi, 4, "Z"))
        # A verdigris rim along the blade edge and a glowing forked bolt across its face.
        rim = []
        for k in range(12):
            ang = math.radians(-20 + k * 10.0)
            length = 9.6 - abs(k - 5.5) * 0.5
            rim.append((sx * (0.8 + math.cos(ang) * length), 0, top + 2.4 + math.sin(ang) * length))
        tube(accent, rim, [0.4] * len(rim), 5, cap=True)
        bolt(glow, (sx * 2.4, -0.55, top - 1.4), 9.0, 1.4 * sx, 0.3, flip=1)
    cyl_z(glow, 0.32, 3.0, (0, 0, top + 9.6), segs=8)
    # A glowing seam spiralling up the shaft under the rings (the circuit).
    pts = []
    for k in range(25):
        z = base + 1.0 + k * (shaft_h - 3.0) / 24
        a = k * 0.55
        rr = (2.3 - 0.8 * (z - base) / shaft_h) * 1.02
        pts.append((math.cos(a) * rr, math.sin(a) * rr, z))
    tube(glow, pts, [0.16] * len(pts), 5, cap=False)


@template("SplitGraniteTor", STONE=5200, MOSS=1600, ALT=800)
def split_granite_tor(t):
    """A great split granite tor: two towering weathered pillars of jointed granite standing side by side over a
    cleft, on a heap of fallen blocks, moss and lichen on the ledges. Its crown is flat, to carry a totem."""
    stone, moss, alt = (t.bm(r) for r in ("STONE", "MOSS", "ALT"))
    rng = random.Random(2611)
    # Twin pillars built from stacked jointed blocks, narrowing upward, leaning slightly apart.
    for sx, h, lean in ((-1, 78.0, -0.035), (1, 84.0, 0.03)):
        z = 0.0
        k = 0
        while z < h:
            bh = rng.uniform(7.0, 11.0)
            frac = z / h
            w = 26.0 - frac * 9.0 + rng.uniform(-1.2, 1.2)
            dpt = 30.0 - frac * 10.0 + rng.uniform(-1.2, 1.2)
            cx = sx * (13.5 - frac * 2.0) + math.sin(z * 0.11) * 0.8 + lean * z * sx * 0
            mat = T((cx, rng.uniform(-0.8, 0.8), z + bh * 0.5)) @ R(rng.uniform(-0.07, 0.07), 4, "Z") @ R(lean * frac + rng.uniform(-0.03, 0.03), 4, "Y")
            # Granite weathers into rounded rectangular blocks along its joints.
            box(stone, (w, dpt, bh + 0.6), mat, bevel=min(2.2, bh * 0.22), segs=2)
            if k % 2 == 1:
                ground_rock(moss, (w * 0.7, dpt * 0.5, 1.2), (cx + rng.uniform(-3, 3), rng.uniform(-6, 6), z + bh - 0.3), seed=2690 + k + sx, roughness=0.3, subdiv=1)
            z += bh
            k += 1
        # The flat crown slab.
        box(stone, (17.0, 20.0, 3.0), T((sx * 11.8, 0, h + 1.2)), bevel=1.0, segs=2)
    # A chockstone wedged in the cleft near the top, and fallen blocks round the foot.
    centred_rock(stone, (8.0, 10.0, 7.0), T((0, 0, 62.0)) @ R(0.3, 4, "Y"), seed=2710, roughness=0.12, subdiv=2)
    for k in range(10):
        a = rng.uniform(0, 2 * math.pi)
        d = rng.uniform(22, 30)
        s = rng.uniform(5, 10)
        ground_rock(stone if k % 3 else alt, (s * 1.2, s, s * 0.7), (math.cos(a) * d, math.sin(a) * d * 0.9, -0.5), seed=2720 + k, roughness=0.18)
    for k in range(8):
        a = rng.uniform(0, 2 * math.pi)
        d = rng.uniform(18, 30)
        ground_rock(moss, (7, 6, 1.4), (math.cos(a) * d, math.sin(a) * d, 0), seed=2740 + k, roughness=0.32, subdiv=1)


@template("HighlandWindmill", STONE=2000, WOOD=3600, TRIM=1400, ALT=1200, METAL=500)
def highland_windmill(t):
    """A weathered post windmill on a dry-stone roundhouse base: a boarded timber body with a pitched slate roof,
    a tail pole and steps down the back, four lattice sails with tattered sailcloth (one sail broken)."""
    stone, wood, trim, alt, metal = (t.bm(r) for r in ("STONE", "WOOD", "TRIM", "ALT", "METAL"))
    # Stone roundhouse base.
    cone(stone, 9.0, 8.4, 9.0, 20, T((0, 0, 0)))
    for k in range(4):
        ring_mesh(stone, 8.9 - k * 0.15, 0.35, 24, T((0, 0, 1.6 + k * 2.1)), tube_segs=4)
    cone(trim, 9.4, 9.4, 0.8, 20, T((0, 0, 9.0)))
    box(wood, (2.6, 0.6, 4.2), T((0, -8.6, 2.1)))
    # The post and crown tree carrying the body.
    cyl_z(wood, 1.3, 6.0, (0, 0, 9.6), segs=8)
    body_z, bw, bd, bh = 14.0, 12.0, 14.0, 17.0
    box(wood, (bw, bd, bh), T((0, 0, body_z + bh / 2)))
    for k in range(9):
        box(trim, (bw + 0.3, 0.3, 0.35), T((0, -bd / 2 - 0.1, body_z + 1.0 + k * 1.9)))
    box(alt, (2.6, 0.3, 3.2), T((3.0, -bd / 2 - 0.2, body_z + 9.0)))
    # Pitched roof (two slabs) with a ridge.
    for sx in (-1, 1):
        box(trim, (bw * 0.62, bd + 2.4, 0.6), T((sx * bw * 0.26, 0, body_z + bh + 2.6)) @ R(sx * math.radians(-38), 4, "Y"))
    box(trim, (0.8, bd + 2.8, 0.8), T((0, 0, body_z + bh + 4.6)))
    # Tail pole and ladder steps down the back.
    strut(wood, (0, bd / 2, body_z + 3.0), (0, bd / 2 + 16, 0.4), 1.1)
    for k in range(7):
        z = body_z + 2.0 - k * 2.2
        y = bd / 2 + 1.5 + k * 1.9
        box(wood, (4.4, 1.2, 0.3), T((0, y, z)))
    strut(wood, (-2.0, bd / 2, body_z + 3.0), (-2.0, bd / 2 + 14.5, 0.2), 0.5)
    strut(wood, (2.0, bd / 2, body_z + 3.0), (2.0, bd / 2 + 14.5, 0.2), 0.5)
    # Windshaft and the four sails (lattice stocks with cloth), in the XZ plane at the front.
    hub = Vector((0, -bd / 2 - 1.8, body_z + bh - 3.0))
    cyl_y(metal, 1.1, 3.6, hub + Vector((0, 1.2, 0)), segs=10)
    for k in range(4):
        a = math.radians(28 + k * 90)
        d = Vector((math.cos(a), 0, math.sin(a)))
        side = Vector((-math.sin(a), 0, math.cos(a)))
        broken = k == 2
        length = 10.0 if broken else 21.0
        strut(wood, hub, hub + d * length, 0.9)
        rungs = int(length / 2.2)
        for r in range(1, rungs + 1):
            p = hub + d * (r * 2.2)
            strut(wood, p, p + side * 4.2, 0.3)
        for r in (0, 1):
            off = side * (1.4 + r * 2.8)
            strut(wood, hub + d * 3.0 + off, hub + d * length + off, 0.25)
        if not broken:
            # Tattered cloth on the inner part of the sail.
            cloth_len = length * (0.55 if k % 2 else 0.8)
            box(alt, (cloth_len, 0.12, 3.6), T(hub + d * (3.0 + cloth_len / 2) + side * 2.2 + Vector((0, -0.3, 0))) @ R(-a, 4, "Y"))
        else:
            # The snapped stock dangling, its cloth torn.
            strut(wood, hub + d * length, hub + d * length + Vector((0.6, -0.4, -6.0)), 0.7)
            box(alt, (4.5, 0.12, 2.6), T(hub + d * 6.0 + side * 2.0 + Vector((0, -0.3, 0))) @ R(-a - 0.3, 4, "Y"))


@template("RuneStandingStone", STONE=1400, MOSS=500, GLOW=400)
def rune_standing_stone(t):
    """A weathered rune standing stone: a tall round-shouldered slab carved with a forked-bolt rune that glows
    faint violet, lichen at its foot, two copper-scored grooves where the grounding chains were fixed."""
    stone, moss, glow = (t.bm(r) for r in ("STONE", "MOSS", "GLOW"))
    # A flat-bottomed rock keeps 0.8 of its height: the slab reaches 12, its rounded crown sits into it.
    rock_clean(stone, (4.6, 2.4, 15.6), T((0, 0, -0.5)), seed=2621, roughness=0.08, subdiv=2)
    centred_rock(stone, (4.0, 2.2, 3.0), T((0, 0, 11.4)), seed=2622, roughness=0.1, subdiv=2)
    bolt(glow, (-0.6, -1.25, 4.2), 6.0, 1.1, 0.22)
    box(glow, (1.6, 0.18, 0.22), T((0, -1.25, 3.6)))
    for k in range(3):
        a = k * 2.1
        ground_rock(moss, (2.6, 2.2, 0.7), (math.cos(a) * 2.6, math.sin(a) * 1.8, 0), seed=2625 + k, roughness=0.3, subdiv=1)


@template("ShepherdCroft", STONE=3200, MOSS=1800, WOOD=900, TRIM=600, GLOW=100)
def shepherd_croft(t):
    """A Kairnfolk shepherd's croft: low dry-stone walls with big quoins, a heavy turf roof, a gable chimney, a
    plank door and a deep-set window with a warm light."""
    stone, moss, wood, trim, glow = (t.bm(r) for r in ("STONE", "MOSS", "WOOD", "TRIM", "GLOW"))
    w, d, h = 20.0, 12.0, 7.5
    # Coursed walls: rows of stones round a core.
    box(stone, (w - 1.0, d - 1.0, h), T((0, 0, h / 2)))
    rng = random.Random(2631)
    for row in range(4):
        z = 0.9 + row * 1.8
        for side in (-1, 1):
            x = -w / 2 + 1.2
            while x < w / 2 - 1.2:
                sl = rng.uniform(2.0, 3.4)
                slab_stone(stone, (sl, 1.2, 1.7), (x + sl / 2, side * (d / 2 - 0.5), z), seed=2632 + row * 40 + int(x * 3) + side, roughness=0.14)
                x += sl * 0.92
    for sx in (-1, 1):
        for sy in (-1, 1):
            for row in range(4):
                box(stone, (1.8, 1.8, 1.7), T((sx * (w / 2 - 0.6), sy * (d / 2 - 0.6), 0.9 + row * 1.8)))
    # Gable walls and the pitched roof: a slate prism with turf grown over it.
    prism(stone, w - 1.0, d - 1.0, 4.2, T((0, 0, h)))
    prism(trim, w + 1.6, d + 1.6, 4.9, T((0, 0, h - 0.2)))
    for k in range(7):
        sy = 1 if k % 2 == 0 else -1
        centred_rock(moss, (rng.uniform(4, 7), 2.6, 0.9), T((rng.uniform(-w / 2 + 2, w / 2 - 2), sy * 2.4, h + 2.6)) @ R(sy * math.radians(-40), 4, "X"), seed=2670 + k, roughness=0.25, subdiv=1)
    # Chimney on the east gable.
    box(stone, (2.4, 2.4, 5.0), T((w / 2 - 1.6, 0, h + 3.5)))
    box(trim, (2.8, 2.8, 0.5), T((w / 2 - 1.6, 0, h + 6.2)))
    # Door and window on the front (-Y).
    box(wood, (2.6, 0.4, 4.6), T((-3.0, -d / 2 - 0.05, 2.3)))
    box(trim, (3.4, 0.6, 0.6), T((-3.0, -d / 2 - 0.1, 4.9)))
    box(glow, (1.8, 0.2, 1.5), T((4.0, -d / 2 - 0.05, 3.6)))
    box(wood, (2.4, 0.4, 0.4), T((4.0, -d / 2 - 0.15, 2.7)))
    # Lichen and turf at the wall foot.
    for k in range(6):
        ground_rock(moss, (3.0, 1.8, 0.6), (rng.uniform(-w / 2, w / 2), rng.choice((-1, 1)) * (d / 2 + 0.8), 0), seed=2660 + k, roughness=0.3, subdiv=1)


@template("DryStoneWall", STONE=2600, MOSS=700)
def dry_stone_wall(t):
    """A 24-stud run of dry-stone walling: two faces of rough stones battered inward, through-stones and an
    upright coping of slabs set on edge, moss in the joints."""
    stone, moss = t.bm("STONE"), t.bm("MOSS")
    rng = random.Random(2651)
    length, height = 24.0, 3.6
    box(stone, (length, 1.4, height - 0.6), T((0, 0, (height - 0.6) / 2)))
    for row in range(3):
        z = 0.5 + row * 1.0
        for side in (-1, 1):
            x = -length / 2
            while x < length / 2:
                sl = rng.uniform(1.2, 2.4)
                slab_stone(stone, (sl, 0.9, 1.0), (x + sl / 2, side * (0.85 - row * 0.12), z), rot_z=rng.uniform(-0.1, 0.1), seed=2652 + row * 100 + int((x + 20) * 7) + side, roughness=0.16)
                x += sl * 0.95
    # Coping: slabs on edge along the top.
    x = -length / 2 + 0.3
    k = 0
    while x < length / 2 - 0.3:
        sl = rng.uniform(1.0, 1.6)
        slab_stone(stone, (sl, 1.7, 0.9), (x + sl / 2, 0, height - 0.3), rot_z=rng.uniform(-0.15, 0.15), tilt=0, seed=2900 + k, roughness=0.14)
        x += sl * 1.02
        k += 1
    for k in range(5):
        ground_rock(moss, (rng.uniform(2, 3.4), 1.0, 0.6), (rng.uniform(-11, 11), rng.choice((-1, 1)) * 1.0, rng.uniform(0.2, 2.2)), seed=2950 + k, roughness=0.3, subdiv=1)


@template("RamHurdleFence", WOOD=1600)
def ram_hurdle_fence(t):
    """A 12-stud run of timber sheep hurdles: split rails mortised into posts, braced, one hurdle sagging."""
    wood = t.bm("WOOD")
    rng = random.Random(2661)
    for x in (-6.0, -2.0, 2.0, 6.0):
        box(wood, (0.6, 0.6, 4.6), T((x, 0, 2.3)) @ R(rng.uniform(-0.05, 0.05), 4, "Y"))
    for k, z in enumerate((1.0, 2.0, 3.0, 4.0)):
        sag = -0.25 if k == 2 else 0.0
        strut(wood, (-6.0, 0.05, z), (6.0, 0.05, z + sag), 0.32)
    for x0 in (-6.0, -2.0, 2.0):
        strut(wood, (x0, -0.05, 0.6), (x0 + 4.0, -0.05, 4.0), 0.26)


@template("TrailCairnTall", STONE=1500, METAL=700, GLOW=200, MOSS=300)
def trail_cairn_tall(t):
    """A tall trail cairn of stacked flat stones with a hammered-copper forked-bolt capstone, its points tipped
    with violet static."""
    stone, metal, glow, moss = (t.bm(r) for r in ("STONE", "METAL", "GLOW", "MOSS"))
    z = 0.0
    for k in range(7):
        w = 4.4 - k * 0.42
        h = 1.15
        slab_stone(stone, (w, w * 0.85, h * 1.15), (math.sin(k * 1.7) * 0.25, math.cos(k * 1.3) * 0.2, z + h * 0.5), rot_z=k * 0.7, seed=2671 + k, roughness=0.12)
        z += h * 0.92
    ground_rock(moss, (4.8, 4.0, 0.6), (0, 0, 0), seed=2680, roughness=0.3, subdiv=1)
    cyl_z(metal, 0.32, 2.4, (0, 0, z - 0.2), segs=8)
    tip = bolt(metal, (0, 0, z + 1.8), 3.4, 0.9, 0.45, segs=3)
    for sx in (-1, 1):
        strut(metal, (0, 0, z + 2.2), (sx * 1.8, 0, z + 4.4), 0.32)
        uvsphere(glow, 0.22, T((sx * 1.8, 0, z + 4.5)), 6, 4)
    uvsphere(glow, 0.26, T(tip + Vector((0, 0, 0.3))), 6, 4)


@template("WindBentPine", WOOD=1800, FOLIAGE=3200)
def wind_bent_pine(t):
    """A highland pine bent by the gale: a curving trunk leaning down-wind (+X) with its branches combed the same
    way, flattened tiers of needles streaming off the lee side and a bare windward flank."""
    wood, foliage = t.bm("WOOD"), t.bm("FOLIAGE")
    rng = random.Random(2681)
    pts, radii = [], []
    for k in range(9):
        f = k / 8
        pts.append((15.0 * f ** 1.5, 0, f * 30.0 - 2.0 * f * f))
        radii.append(1.3 - f * 0.95)
    tube(wood, pts, radii, 8)
    # Roots flaring at the foot.
    for k in range(5):
        a = 2 * math.pi * k / 5 + 0.3
        strut(wood, (0, 0, 0.6), (math.cos(a) * 3.2, math.sin(a) * 3.2, -0.3), 0.55)
    # Needle tiers: flattened cones shifted down-wind, shrinking upward.
    for k in range(5):
        f = 0.5 + k * 0.12
        cx, cz = 15.0 * f ** 1.5, f * 30.0 - 2.0 * f * f
        r = 7.5 - k * 0.9 + rng.uniform(-0.6, 0.6)
        # Flat, ragged pads of needles combed down-wind off the lee side of the trunk.
        for j in range(3):
            pad = T((cx + r * (0.45 + j * 0.35), rng.uniform(-1.5, 1.5), cz - 0.8 + j * 0.4)) @ Matrix.Diagonal((1.5, 1.0, 0.42, 1.0))
            centred_rock(foliage, (r * (1.1 - j * 0.25), r * (0.95 - j * 0.2), 4.0), pad, seed=2682 + k * 5 + j, roughness=0.3, subdiv=1)
        strut(wood, (cx, 0, cz - 0.6), (cx + r * 1.4, rng.uniform(-1, 1), cz + 0.2), 0.32)


@template("StormgrassTuft", FOLIAGE=900, MOSS=300)
def stormgrass_tuft(t):
    """Ground cover: a clump of tough stormgrass and heather, every blade combed down-wind (+X)."""
    foliage, moss = t.bm("FOLIAGE"), t.bm("MOSS")
    rng = random.Random(2691)
    ground_rock(moss, (3.2, 2.6, 0.5), (0, 0, -0.1), seed=2692, roughness=0.3, subdiv=1)
    for k in range(22):
        a = rng.uniform(0, 2 * math.pi)
        d = rng.uniform(0, 1.4)
        base = Vector((math.cos(a) * d, math.sin(a) * d, 0))
        h = rng.uniform(1.6, 2.8)
        tip = base + Vector((h * 0.55, rng.uniform(-0.3, 0.3), h))
        mid = base + (tip - base) * 0.5 + Vector((-0.1, 0, 0.15))
        tube(foliage, [base, mid, tip], [0.09, 0.07, 0.02], 3, cap=False)


@template("DolmenBellGate", STONE=3000, MOSS=900, GOLD=1200, TRIM=500)
def dolmen_bell_gate(t):
    """The bell-gate: a dolmen of two great weathered uprights and a slab capstone spanning the trail, three
    bronze storm-bells hung on short chains under it. The uprights stand 36 studs apart (centre to centre) and
    carry the capstone, whose underside clears 19 studs; the lowest bell clapper hangs at 14.8."""
    stone, moss, gold, trim = (t.bm(r) for r in ("STONE", "MOSS", "GOLD", "TRIM"))
    for sx in (-1, 1):
        # A flat-bottomed rock keeps 0.8 of its height: these reach 20 studs, up into the capstone.
        rock_clean(stone, (6.4, 5.2, 25.8), T((sx * 18.0, 0, -0.6)) @ R(sx * 0.03, 4, "Y"), seed=2701 + sx, roughness=0.08, subdiv=2, flat_bottom=True)
        for k in range(3):
            ground_rock(moss, (3.2, 2.6, 0.9), (sx * 18.0 + math.cos(k * 2.1) * 3.6, math.sin(k * 2.1) * 3.0, 0), seed=2705 + k + sx * 10, roughness=0.3, subdiv=1)
    centred_rock(stone, (44.0, 7.6, 4.6), T((0, 0, 21.4)), seed=2710, roughness=0.07, subdiv=2)
    ground_rock(moss, (16.0, 5.0, 0.8), (-4, 0, 23.4), seed=2711, roughness=0.3, subdiv=1)
    for k, x in enumerate((-8.0, 0.0, 8.0)):
        top = 19.4
        strut(trim, (x, 0, top), (x, 0, top - 1.6), 0.22)
        bell_h = 2.6 if k == 1 else 2.0
        cone(gold, 0.6, 1.6 if k == 1 else 1.3, bell_h, 14, T((x, 0, top - 1.6)) @ R(math.pi, 4, "X"))
        ring_mesh(gold, 1.65 if k == 1 else 1.35, 0.14, 16, T((x, 0, top - 1.6 - bell_h)), tube_segs=4)
        uvsphere(trim, 0.35, T((x, 0, top - 1.6 - bell_h - 0.4)), 6, 4)


@template("HighlandSheep", ALT=900, TRIM=500)
def highland_sheep(t):
    """A shaggy highland sheep grazing: a heavy woollen fleece, a dark face and legs, curled horn stubs."""
    alt, trim = t.bm("ALT"), t.bm("TRIM")
    centred_rock(alt, (2.6, 4.4, 2.4), T((0, 0, 2.0)), seed=2721, roughness=0.18, subdiv=2)
    for sx in (-1, 1):
        for sy in (-1, 1):
            cyl_z(trim, 0.22, 1.3, (sx * 0.7, sy * 1.4, 0), segs=6)
    # Head lowered to graze, toward -Y.
    centred_rock(trim, (1.0, 1.6, 1.0), T((0, -2.6, 1.3)) @ R(math.radians(-30), 4, "X"), seed=2722, roughness=0.08, subdiv=1)
    for sx in (-1, 1):
        ring_mesh(trim, 0.35, 0.12, 8, T((sx * 0.55, -2.2, 1.9)) @ R(math.pi / 2, 4, "Y"), tube_segs=4)


@template("WaterfallRibbon", CRYSTAL=1200, ALT=1400)
def waterfall_ribbon(t):
    """A highland fall, 60 studs high, its origin at the foot: a sheet of water curving off a lip and widening as
    it drops (CRYSTAL), streaks of white water down it and a foam skirt boiling up at the foot (ALT)."""
    crystal, alt = t.bm("CRYSTAL"), t.bm("ALT")
    h = 60.0
    rows = 14
    rng = random.Random(2731)
    # The sheet: a quad strip in the XZ plane bowing forward (-Y) at the lip and settling back near the foot.
    verts = []
    for r in range(rows + 1):
        f = r / rows
        z = h * (1 - f)
        w = 4.0 + f * 5.0
        y = -2.4 * math.sin(f * math.pi * 0.5) * (1 - f * 0.6)
        row = []
        for c in range(5):
            u = c / 4 - 0.5
            row.append(crystal.verts.new((u * 2 * w, y + math.sin(c * 1.3 + r) * 0.15, z)))
        verts.append(row)
    for r in range(rows):
        for c in range(4):
            crystal.faces.new((verts[r][c], verts[r][c + 1], verts[r + 1][c + 1], verts[r + 1][c]))
    # White-water streaks down the face.
    for k in range(9):
        x = rng.uniform(-0.45, 0.45)
        z0 = rng.uniform(h * 0.4, h * 0.95)
        z1 = rng.uniform(1.0, z0 - 10)
        f0, f1 = 1 - z0 / h, 1 - z1 / h
        y0 = -2.4 * math.sin(f0 * math.pi * 0.5) * (1 - f0 * 0.6) - 0.15
        y1 = -2.4 * math.sin(f1 * math.pi * 0.5) * (1 - f1 * 0.6) - 0.15
        tube(alt, [(x * 2 * (4 + f0 * 5), y0, z0), (x * 2 * (4 + f1 * 5), y1, z1)], [0.35, 0.6], 4, cap=False)
    # Foam skirt at the foot.
    for k in range(9):
        a = rng.uniform(0, 2 * math.pi)
        d = rng.uniform(0, 7)
        centred_rock(alt, (rng.uniform(3, 6), rng.uniform(2.5, 4.5), rng.uniform(1.6, 3.2)), T((math.cos(a) * d, math.sin(a) * d * 0.5 - 1.5, 0.6)), seed=2740 + k, roughness=0.3, subdiv=1)


@template("PrayerFlagLine", WOOD=500, TRIM=500, ALT=600, ACCENT=600, GOLD=600)
def prayer_flag_line(t):
    """A Kairnfolk prayer-flag line: two leaning poles 30 studs apart (at x = -15 and 15), a sagging rope between
    their tops and fifteen square pennants in three dyes snapping down-wind."""
    wood, trim, alt, accent, gold = (t.bm(r) for r in ("WOOD", "TRIM", "ALT", "ACCENT", "GOLD"))
    for sx in (-1, 1):
        strut(wood, (sx * 15.0, 0, 0), (sx * 15.4, 0, 11.0), 0.45)
        strut(trim, (sx * 15.4, 0, 11.0), (sx * 18.0, 0, 0), 0.12)
    n = 15
    prev = None
    for k in range(n + 1):
        f = k / n
        x = -15.4 + f * 30.8
        z = 11.0 - 3.2 * math.sin(f * math.pi)
        p = Vector((x, 0, z))
        if prev is not None:
            strut(trim, prev, p, 0.12)
        prev = p
        if 0 < k < n:
            dye = (alt, accent, gold)[k % 3]
            box(dye, (1.5, 0.08, 1.7), T((x + 0.2, 0, z - 1.0)) @ R(0.12 * ((k % 2) * 2 - 1), 4, "Y"))


@template("StormCrystalSpikes", CRYSTAL=1600, GLOW=500, STONE=900)
def storm_crystal_spikes(t):
    """Storm-glass: a burst of violet crystal blades erupting from a fused, scorched rock bed where lightning
    struck, the tallest 16 studs, glowing cores in the biggest blades."""
    crystal, glow, stone = (t.bm(r) for r in ("CRYSTAL", "GLOW", "STONE"))
    rng = random.Random(2751)
    ground_rock(stone, (12.0, 10.0, 1.6), (0, 0, -0.3), seed=2752, roughness=0.28, subdiv=2)
    for k in range(11):
        a = rng.uniform(0, 2 * math.pi)
        d = rng.uniform(0, 4.2)
        h = rng.uniform(5.0, 16.0) * (1.1 - d / 8)
        r = rng.uniform(0.8, 1.6)
        tilt = d * 0.09 + rng.uniform(0, 0.15)
        mat = T((math.cos(a) * d, math.sin(a) * d, 0.2)) @ R(a, 4, "Z") @ R(tilt, 4, "Y")
        cone(crystal, r, 0.05, h, 6, mat)
        if h > 11:
            cone(glow, r * 0.38, 0.05, h * 0.8, 4, mat @ T((0, 0, 0.5)))


if __name__ == "__main__":
    kit, manifest = build_kit("ThunderF26Kit", F26_TEMPLATES, DEFAULT_BUDGET)
    export_kit(kit, manifest, OUT_DIR, "ThunderF26Kit")
    render_previews(kit, F26_TEMPLATES, OUT_DIR)
    print(json.dumps(manifest, indent=2))
