"""
Sunken Sanctuary Floor 37 (Coral Cloister) sculpted assets, generated in headless Blender.

The Nereth cantors' flooded double cloister (guide image: reference/Sunken Sanctuary 37.jpg):
coral-grown cloister arcade bays (straight and corner) with verdigris tiled roofs and hanging bells,
the tall square limestone Campanile Bell Tower with paired belfry bells and verdigris spire,
modular open ribbed-vault Chapter House bays for Chapter Isle, the domed Lavabo fountain house
with its giant scalloped shell basin and bronze fish-head spouts, curved cantors' stalls, conch
racks, the Frater's set refectory table, Scriptorium tide-chart desks, Sacristy vestment presses
with coiled bell-rope bins, robed Cantor niche statues, drowned garth sundials, brain-coral
mounds, and Dorter stone cots.

Reuses the mesh helpers and role conventions of `tools/blender/generate_tower_biome_kit.py`
(1 Blender unit = 1 stud, standing on z = 0, front facing -Y in Blender / +Z in Roblox,
one mesh object per colour role named "<Template>__<ROLE>"). Roles used here: STONE (pale
limestone), TRIM (white marble), METAL (bronze), ACCENT (verdigris), GOLD (gilding), GLOW (aqua
rune light), CANDLE (warm lamp flame), WOOD (drowned timber), SILK (robes and drapes), FOLIAGE
(kelp and seagrass), MOSS (waterline weed), CORAL (pink-violet / cream / aqua / ochre coral,
never red or orange), ALT (shell and nacre) and CRYSTAL (still water and pearl).
Floor 37 tints every role itself (TowerSetPieces/SunkenFloor37).

Run:
    PYTHONHASHSEED=0 /Applications/Blender.app/Contents/MacOS/Blender --background --python tools/blender/generate_sunken_f37_kit.py

Outputs (assets-source/tower/sunken_f37_kit/):
    SunkenF37Kit.blend    the generated scene
    SunkenF37Kit.fbx      FBX for File > Import 3D in Studio
    manifest.json         per template: roles, reference size, triangle counts
    previews/             contact-sheet renders
"""
import bpy, bmesh, math, os, json, runpy
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT_DIR = os.path.join(ROOT, "assets-source", "tower", "sunken_f37_kit")

kit_mod = runpy.run_path(os.path.join(HERE, "generate_tower_biome_kit.py"), init_globals={"RUN_KIT": False})

Template = kit_mod["Template"]
M = kit_mod["M"]
box = kit_mod["box"]
cone = kit_mod["cone"]
uvsphere = kit_mod["uvsphere"]
tube = kit_mod["tube"]
lathe = kit_mod["lathe"]
rock = kit_mod["rock"]
ring_mesh = kit_mod["ring_mesh"]
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


def round_arch(bm, half_span, rise, thick, depth, mat, segs=10):
    """A semicircular/segmental cloister arch over x in [-half_span, half_span], springing at z = 0."""
    pts = []
    for k in range(segs + 1):
        a = math.pi * k / segs
        pts.append(Vector((math.cos(a) * half_span, 0.0, math.sin(a) * rise)))
    for k in range(segs):
        p0, p1 = pts[k], pts[k + 1]
        mid = (p0 + p1) / 2
        d = p1 - p0
        ang = math.atan2(d.z, d.x)
        box(bm, (d.length + thick * 0.35, depth, thick), mat @ M((mid.x, 0, mid.z), rot=(0, -ang, 0)))


def pointed_arch(bm, half_span, rise, thick, depth, mat, segs=8):
    """A two-centred pointed arch springing at z = 0."""
    for s in (-1, 1):
        pts = []
        for k in range(segs + 1):
            a = k / segs * (math.pi / 3)
            x = s * half_span - s * 2 * half_span * (1 - math.cos(a))
            z = 2 * half_span * math.sin(a) * (rise / (2 * half_span * math.sin(math.pi / 3)))
            pts.append(Vector((x, 0, z)))
        for k in range(segs):
            p0, p1 = pts[k], pts[k + 1]
            mid = (p0 + p1) / 2
            d = p1 - p0
            ang = math.atan2(d.z, d.x)
            box(bm, (d.length + thick * 0.35, depth, thick), mat @ M((mid.x, 0, mid.z), rot=(0, -ang, 0)))


def mini_bell(bm_body, bm_trim, bm_wood, mat, scale=1.0):
    """A verdigris cloister bell with yoke and rotted rope stub, lip at z = 0 of mat."""
    prof = [(1.8 * scale, 0.0), (1.9 * scale, 0.25 * scale), (1.6 * scale, 0.7 * scale),
            (1.25 * scale, 1.5 * scale), (1.1 * scale, 2.5 * scale), (0.85 * scale, 3.2 * scale),
            (0.0, 3.45 * scale)]
    lathe(bm_body, prof, 12, mat)
    ring_mesh(bm_trim, 1.82 * scale, 0.16 * scale, 12, mat @ M((0, 0, 0.18 * scale)), tube_segs=5)
    uvsphere(bm_trim, 0.42 * scale, mat @ M((0, 0, 0.1 * scale)), u=6, v=4)
    box(bm_wood, (3.4 * scale, 0.65 * scale, 0.7 * scale), mat @ M((0, 0, 3.7 * scale)))
    tube(bm_wood, [(0, 0, -0.1 * scale), (0.15 * scale, 0.08 * scale, -1.6 * scale)], [0.11 * scale, 0.06 * scale], 5, mat=mat)


def coral_burst(bm, origin_pt, rng, count=6, reach=2.6, base_r=0.35, mat=Matrix.Identity(4)):
    """Organic branching reef coral cluster sprouting from origin_pt."""
    o = Vector(origin_pt)
    for k in range(count):
        az = k * 2 * math.pi / count + rng.uniform(-0.35, 0.35)
        el = rng.uniform(0.35, 1.15)
        dir_v = Vector((math.cos(az) * math.cos(el), math.sin(az) * math.cos(el), math.sin(el)))
        p1 = o + dir_v * (reach * 0.55)
        p2 = p1 + (dir_v + Vector((rng.uniform(-0.3, 0.3), rng.uniform(-0.3, 0.3), 0.35))).normalized() * (reach * 0.55)
        tube(bm, [o, p1, p2], [base_r, base_r * 0.68, base_r * 0.28], 5, mat=mat)
        uvsphere(bm, base_r * 0.42, mat @ M(tuple(p2)), u=5, v=4)
        # Secondary fork
        fork_dir = (dir_v + Vector((math.cos(az + 1.2) * 0.6, math.sin(az + 1.2) * 0.6, 0.45))).normalized()
        p3 = p1 + fork_dir * (reach * 0.42)
        tube(bm, [p1, p3], [base_r * 0.55, base_r * 0.22], 5, mat=mat)


def tide_spiral(bm, centre, radius, turns, width, mat):
    """Carved Nereth nautilus spiral lying in XZ plane (front -Y)."""
    steps = int(14 * turns)
    for k in range(steps):
        f = k / steps
        a = f * turns * 2 * math.pi
        r = radius * (0.18 + 0.82 * f)
        x, z = math.cos(a) * r, math.sin(a) * r
        size = width * (0.5 + 0.5 * f)
        box(bm, (size, size * 0.6, size), mat @ M((centre[0] + x, centre[1], centre[2] + z), rot=(0, -a, 0)))


def scalloped_shell(bm, radius, depth_h, ribs, mat):
    """A fluted giant scallop shell bowl opening upward from z = 0."""
    # Central lower cradle + radiating fluted ribs
    for k in range(ribs):
        u = (k / (ribs - 1)) * 2 - 1  # -1..1
        ang = u * 1.12
        r_len = radius * (1.0 - 0.16 * abs(u))
        pts = [
            Vector((0.0, -radius * 0.15, depth_h * 0.18)),
            Vector((math.sin(ang) * r_len * 0.5, math.cos(ang) * r_len * 0.45, depth_h * 0.42)),
            Vector((math.sin(ang) * r_len, math.cos(ang) * r_len * 0.92, depth_h * (0.95 - 0.12 * abs(u)))),
        ]
        tube(bm, pts, [radius * 0.16, radius * 0.19, radius * 0.14], 6, mat=mat)
    # Hinge heel
    box(bm, (radius * 0.55, radius * 0.28, depth_h * 0.35), mat @ M((0, -radius * 0.22, depth_h * 0.2)))


DEFAULT_BUDGET = 3600
F37_TEMPLATES = {}


def template(name, **budget):
    def deco(fn):
        F37_TEMPLATES[name] = (fn, budget)
        return fn
    return deco


# -------------------------------------------------------------------------------------------------
# 1. CoralArcadeBay: straight cloister arcade bay with verdigris tiled roof, hanging bell and coral
# -------------------------------------------------------------------------------------------------
@template("CoralArcadeBay", STONE=2400, TRIM=900, ACCENT=1600, METAL=900, CORAL=2400, MOSS=600, WOOD=400, GOLD=400)
def coral_arcade_bay(t):
    stone, trim, verd, metal, coral, moss, wood, gold = (
        t.bm("STONE"), t.bm("TRIM"), t.bm("ACCENT"), t.bm("METAL"),
        t.bm("CORAL"), t.bm("MOSS"), t.bm("WOOD"), t.bm("GOLD"),
    )
    rng = t.rng
    span = 9.2
    col_h = 16.5
    # Two columns with moulded plinths and capitals
    for sx in (-1, 1):
        x = sx * span
        box(trim, (3.8, 3.8, 1.4), M((x, 0, 0.7)), bevel=0.12)
        box(stone, (3.2, 3.2, 1.2), M((x, 0, 2.0)), bevel=0.1)
        cone(stone, 1.25, 1.12, col_h - 3.2, 10, M((x, 0, 2.6)))
        box(trim, (3.4, 3.4, 1.3), M((x, 0, col_h + 0.15)), bevel=0.15)
        box(stone, (2.8, 2.8, 0.9), M((x, 0, col_h - 0.85)), bevel=0.08)
        # Waterline weed collar
        rock_clean(moss, (3.8, 3.8, 1.4), M((x, 0, 0.0)), 10 + sx, subdiv=1)

    # Round cloister arch + carved spandrel wall + cornice
    round_arch(stone, span, 6.2, 2.0, 3.0, M((0, 0, col_h + 0.6)), segs=10)
    box(trim, (2.2, 3.4, 2.8), M((0, 0, col_h + 7.1)), bevel=0.12)
    tide_spiral(gold, (0, -1.75, col_h + 7.1), 0.72, 1.4, 0.18, Matrix.Identity(4))
    # Spandrel fill left/right above haunches
    for sx in (-1, 1):
        box(stone, (4.8, 2.4, 4.2), M((sx * (span - 1.6), 0, col_h + 4.4)), bevel=0.08)
    box(stone, (span * 2 + 4.0, 3.6, 1.4), M((0, 0, col_h + 8.3)), bevel=0.1)

    # Pitched verdigris tiled roof eaves crowning the arcade
    for sy in (-1, 1):
        box(verd, (span * 2 + 4.6, 4.4, 0.9), M((0, sy * 1.85, col_h + 10.1), rot=(sy * -0.42, 0, 0)), bevel=0.06)
        for k in range(-4, 5):
            box(verd, (1.6, 4.6, 0.35), M((k * 2.4, sy * 1.9, col_h + 10.45), rot=(sy * -0.42, 0, 0)))
    box(trim, (span * 2 + 4.8, 1.1, 1.0), M((0, 0, col_h + 11.4)), bevel=0.08)

    # Hanging verdigris bronze cloister bell inside the arch
    mini_bell(verd, gold, wood, M((0, 0, col_h + 1.4)), scale=1.05)

    # Lush coral reef overgrowth along roof ridge, eaves and column capitals
    for pt in [(-8.2, -1.6, col_h + 9.2), (-2.4, -1.2, col_h + 10.8), (4.6, -1.5, col_h + 10.0),
               (8.8, 1.4, col_h + 9.0), (-5.8, 1.4, col_h + 10.2), (0.8, 1.6, col_h + 11.1)]:
        coral_burst(coral, pt, rng, count=5, reach=2.7, base_r=0.34)


# -------------------------------------------------------------------------------------------------
# 2. CoralArcadeCorner: 90-degree cloister corner pier & twin arches
# -------------------------------------------------------------------------------------------------
@template("CoralArcadeCorner", STONE=2200, TRIM=800, ACCENT=1400, CORAL=2000, MOSS=500, WOOD=300, GOLD=300)
def coral_arcade_corner(t):
    stone, trim, verd, coral, moss, wood, gold = (
        t.bm("STONE"), t.bm("TRIM"), t.bm("ACCENT"), t.bm("CORAL"),
        t.bm("MOSS"), t.bm("WOOD"), t.bm("GOLD"),
    )
    rng = t.rng
    col_h = 16.5
    # Heavy corner pier at origin
    box(trim, (4.8, 4.8, 1.6), M((0, 0, 0.8)), bevel=0.14)
    box(stone, (3.8, 3.8, col_h - 1.4), M((0, 0, 1.6 + (col_h - 1.4) / 2)), bevel=0.12)
    box(trim, (4.6, 4.6, 1.5), M((0, 0, col_h + 0.2)), bevel=0.14)
    rock_clean(moss, (5.2, 5.2, 1.5), M((0, 0, 0)), 22, subdiv=1)

    # Two orthogonal stub bays (+X and +Y)
    for rot_z in (0.0, math.pi / 2):
        rm = M((0, 0, 0), rot=(0, 0, rot_z))
        box(trim, (3.4, 3.4, 1.4), rm @ M((11.5, 0, 0.7)), bevel=0.1)
        cone(stone, 1.15, 1.05, col_h - 1.6, 10, rm @ M((11.5, 0, 1.4)))
        box(trim, (3.2, 3.2, 1.3), rm @ M((11.5, 0, col_h + 0.15)), bevel=0.12)
        round_arch(stone, 5.75, 5.4, 1.9, 2.8, rm @ M((5.75, 0, col_h + 0.6)), segs=8)
        box(stone, (12.8, 3.2, 1.4), rm @ M((5.8, 0, col_h + 7.2)), bevel=0.1)
        box(verd, (13.4, 4.6, 1.1), rm @ M((5.8, 0, col_h + 9.2)), bevel=0.12)
        mini_bell(verd, gold, wood, rm @ M((5.75, 0, col_h + 1.0)), scale=0.88)

    # Pyramidal verdigris corner roof cap & finial
    cone(verd, 4.4, 0.4, 5.8, 4, M((0, 0, col_h + 8.0), rot=(0, 0, math.pi / 4)))
    uvsphere(gold, 0.75, M((0, 0, col_h + 14.1)), u=8, v=6)

    for pt in [(0.0, -2.0, col_h + 9.8), (5.5, -1.6, col_h + 9.4), (-1.8, 5.5, col_h + 9.4), (2.2, 2.2, col_h + 10.6)]:
        coral_burst(coral, pt, rng, count=5, reach=2.6, base_r=0.34)


# -------------------------------------------------------------------------------------------------
# 3. CampanileTower: tall square limestone Bell Tower (148 studs) behind Chapter Isle
# -------------------------------------------------------------------------------------------------
@template("CampanileTower", STONE=3600, TRIM=1400, ACCENT=2200, METAL=1400, GOLD=800, GLOW=600, CORAL=2000, WOOD=400)
def campanile_tower(t):
    stone, trim, verd, metal, gold, glow, coral, wood = (
        t.bm("STONE"), t.bm("TRIM"), t.bm("ACCENT"), t.bm("METAL"),
        t.bm("GOLD"), t.bm("GLOW"), t.bm("CORAL"), t.bm("WOOD"),
    )
    rng = t.rng
    # Stepped foundation plinth (z = 0..14)
    box(stone, (28.0, 28.0, 5.0), M((0, 0, 2.5)), bevel=0.3)
    box(trim, (25.5, 25.5, 2.4), M((0, 0, 6.2)), bevel=0.2)
    box(stone, (23.0, 23.0, 7.0), M((0, 0, 10.9)), bevel=0.25)

    # Lower & mid tower shaft (z = 14..78) with corner buttresses and stringcourses
    box(stone, (20.2, 20.2, 64.0), M((0, 0, 46.0)), bevel=0.2)
    for sx in (-1, 1):
        for sy in (-1, 1):
            box(trim, (3.6, 3.6, 72.0), M((sx * 10.2, sy * 10.2, 42.0)), bevel=0.18)
            box(stone, (4.8, 4.8, 22.0), M((sx * 10.6, sy * 10.6, 17.0)), bevel=0.18)
    for z_band in (30.0, 52.0, 76.0):
        box(trim, (23.2, 23.2, 2.0), M((0, 0, z_band)), bevel=0.15)

    # Arched statue niche on south (-Y) face around z = 32..50 + glowing tide-spiral medallion
    pointed_arch(trim, 4.4, 5.8, 1.4, 2.2, M((0, -10.5, 43.0)), segs=6)
    for sx in (-1, 1):
        box(trim, (1.5, 2.0, 11.5), M((sx * 4.4, -10.5, 37.2)), bevel=0.1)
    # Robed figure silhouette inside niche
    cone(trim, 2.4, 1.2, 8.2, 10, M((0, -10.0, 32.0)))
    uvsphere(trim, 1.15, M((0, -10.0, 41.2)), u=8, v=6)
    tide_spiral(glow, (0, -10.4, 62.0), 3.2, 1.6, 0.55, Matrix.Identity(4))

    # Tall lancet slit windows on E/W/N faces
    for rot_z in (math.pi / 2, math.pi, -math.pi / 2):
        rm = M((0, 0, 0), rot=(0, 0, rot_z))
        for z_w in (36.0, 58.0):
            box(glow, (2.2, 0.8, 11.0), rm @ M((0, -10.2, z_w)))
            pointed_arch(trim, 1.8, 2.6, 0.8, 1.2, rm @ M((0, -10.4, z_w + 5.2)), segs=5)

    # Open Belfry Chamber (z = 78..106): 4 heavy corner piers, paired lancet arches on each face, TWO bells
    for sx in (-1, 1):
        for sy in (-1, 1):
            box(stone, (4.6, 4.6, 28.0), M((sx * 8.2, sy * 8.2, 92.0)), bevel=0.16)
    for rot_z in (0, math.pi / 2, math.pi, -math.pi / 2):
        rm = M((0, 0, 0), rot=(0, 0, rot_z))
        # Central mullion dividing paired belfry lancets
        cone(trim, 0.95, 0.85, 19.0, 8, rm @ M((0, -9.2, 78.0)))
        for sx in (-1, 1):
            pointed_arch(stone, 3.0, 5.2, 1.3, 2.4, rm @ M((sx * 3.2, -9.2, 96.5)), segs=6)
        box(stone, (20.8, 2.8, 4.0), rm @ M((0, -9.2, 104.0)), bevel=0.12)

    # Belfry cornice & parapet (z = 106..110)
    box(trim, (24.4, 24.4, 2.8), M((0, 0, 107.4)), bevel=0.2)
    for sx in (-1, 1):
        for sy in (-1, 1):
            cone(trim, 1.9, 0.3, 6.5, 4, M((sx * 10.6, sy * 10.6, 108.8), rot=(0, 0, math.pi / 4)))

    # Two silent verdigris-bronze bells inside the belfry (visible through paired arches!)
    box(wood, (15.0, 2.0, 2.0), M((0, 0, 96.5)))
    mini_bell(metal, gold, wood, M((-3.8, 0, 84.0)), scale=2.3)
    mini_bell(verd, gold, wood, M((3.8, 0, 84.0)), scale=2.3)

    # Steep verdigris-bronze pyramidal spire (z = 108..146) + golden finial (to 150)
    cone(verd, 13.8, 0.45, 37.0, 4, M((0, 0, 108.6), rot=(0, 0, math.pi / 4)))
    # Gold hip ribs along the four spire edges
    for k in range(4):
        a = k * math.pi / 2 + math.pi / 4
        tube(gold, [(math.cos(a) * 13.6, math.sin(a) * 13.6, 108.6), (0, 0, 145.6)], [0.42, 0.16], 5)
    cone(gold, 0.6, 0.12, 4.6, 8, M((0, 0, 145.4)))
    uvsphere(gold, 1.05, M((0, 0, 146.5)), u=8, v=6)

    # Coral creeping up the tower base and mid-shaft quoins
    for pt in [(-11.0, -9.5, 16.0), (11.2, -9.0, 24.0), (-10.6, -10.2, 54.0), (10.4, 9.8, 38.0), (0, -10.8, 77.5)]:
        coral_burst(coral, pt, rng, count=6, reach=3.8, base_r=0.48)


# -------------------------------------------------------------------------------------------------
# 4. ChapterHouseRib: modular octagonal gothic rib bay for Chapter Isle (open to sky)
# -------------------------------------------------------------------------------------------------
@template("ChapterHouseRib", STONE=2400, TRIM=1000, ACCENT=1200, CORAL=1800, GOLD=400, GLOW=400)
def chapter_house_rib(t):
    stone, trim, verd, coral, gold, glow = (
        t.bm("STONE"), t.bm("TRIM"), t.bm("ACCENT"), t.bm("CORAL"), t.bm("GOLD"), t.bm("GLOW"),
    )
    rng = t.rng
    span = 8.4
    col_h = 20.5
    # Two outer buttressed stone piers + low stone parapet wall between them
    for sx in (-1, 1):
        x = sx * span
        box(trim, (4.0, 4.4, 1.8), M((x, 0, 0.9)), bevel=0.14)
        box(stone, (3.2, 3.6, col_h - 1.6), M((x, 0, 1.8 + (col_h - 1.6) / 2)), bevel=0.12)
        box(trim, (3.8, 4.2, 1.5), M((x, 0, col_h + 0.4)), bevel=0.14)
        # Outer gothic flying-buttress spur (+Y is outer side, -Y faces inward toward Chapter Isle centre)
        box(stone, (2.2, 4.2, 11.0), M((x, 3.2, 5.5)), bevel=0.12)
        cone(trim, 1.4, 0.25, 5.2, 4, M((x, 0, col_h + 1.2), rot=(0, 0, math.pi / 4)))

    # Low stone balustrade bench rail on outer rim
    box(stone, (span * 2 - 2.4, 2.0, 3.2), M((0, 0.6, 1.6)), bevel=0.1)
    box(trim, (span * 2 - 2.0, 2.4, 0.6), M((0, 0.6, 3.4)), bevel=0.06)

    # Pointed gothic arch spanning between piers + trefoil tracery ring
    pointed_arch(stone, span, 9.2, 2.0, 2.8, M((0, 0, col_h + 0.6)), segs=8)
    ring_mesh(trim, 2.2, 0.38, 12, M((0, 0, col_h + 5.6), rot=(math.pi / 2, 0, 0)), tube_segs=5)
    uvsphere(glow, 0.85, M((0, 0, col_h + 5.6)), u=8, v=6)

    # Sweeping broken vault ribs curving inward (-Y) and upward to form the half-fallen open dome
    for sx in (-1, 1):
        x0 = sx * span
        pts = []
        for k in range(8):
            f = k / 7.0
            rx = x0 * (1.0 - f * 0.42)
            ry = -f * 13.5
            rz = col_h + 0.8 + math.sin(f * math.pi * 0.52) * 19.5
            pts.append(Vector((rx, ry, rz)))
        tube(stone, pts, [1.15 - 0.05 * k for k in range(8)], 6)
        tube(gold, [p + Vector((0, 0, -0.7)) for p in pts], [0.24] * 8, 5)

    # Verdigris eave cornice + coral bursting over the arch crown
    box(verd, (span * 2 + 3.2, 3.4, 1.2), M((0, 0.8, col_h + 10.0)), bevel=0.1)
    for pt in [(-6.2, 0.5, col_h + 10.6), (0.0, 0.6, col_h + 10.8), (6.4, 0.5, col_h + 10.4), (-8.5, 2.2, 12.0)]:
        coral_burst(coral, pt, rng, count=5, reach=2.8, base_r=0.35)


# -------------------------------------------------------------------------------------------------
# 5. LavaboFountain: domed round fountain house with giant shell basin and bronze fish-head spouts
# -------------------------------------------------------------------------------------------------
@template("LavaboFountain", STONE=2600, TRIM=1200, ACCENT=2200, METAL=1400, ALT=1800, GOLD=900, GLOW=800, CRYSTAL=900, CORAL=1600)
def lavabo_fountain(t):
    stone, trim, verd, metal, shell, gold, glow, water, coral = (
        t.bm("STONE"), t.bm("TRIM"), t.bm("ACCENT"), t.bm("METAL"),
        t.bm("ALT"), t.bm("GOLD"), t.bm("GLOW"), t.bm("CRYSTAL"), t.bm("CORAL"),
    )
    rng = t.rng
    # Circular stepped marble basin plinth (z = 0..3.0)
    cone(stone, 12.6, 12.2, 1.4, 20, M((0, 0, 0)))
    cone(trim, 11.4, 11.2, 1.5, 20, M((0, 0, 1.4)))
    ring_mesh(trim, 10.2, 0.75, 20, M((0, 0, 2.9)), tube_segs=6)
    # Shimmering basin pool surface
    cone(water, 9.6, 9.6, 0.4, 20, M((0, 0, 2.5)))

    # Central carved pedestal carrying the giant scalloped shell basin (z = 2.6..9.6)
    cone(stone, 3.2, 2.2, 3.2, 12, M((0, 0, 2.6)))
    scalloped_shell(shell, 5.4, 3.6, 11, M((0, 0, 5.4)))
    # Warm glowing shell heart + crystal water pool inside shell
    cone(glow, 3.6, 3.8, 0.35, 14, M((0, 0.6, 7.2)))

    # Four bronze fish-head spouts arcing crystal water streams into the shell
    for k in range(4):
        a = k * math.pi / 2 + math.pi / 4
        ca, sa = math.cos(a), math.sin(a)
        rm = M((0, 0, 0), rot=(0, 0, a))
        # Bronze dolphin/fish spout perched on rim pedestal
        box(stone, (2.0, 2.0, 4.2), rm @ M((7.8, 0, 4.2)), bevel=0.1)
        tube(metal, [(7.8, 0, 6.2), (6.6, 0, 7.6), (5.4, 0, 7.3)], [0.95, 0.72, 0.45], 8, mat=rm)
        uvsphere(gold, 0.55, rm @ M((6.5, 0, 7.8)), u=6, v=5)
        # Water arc into the shell
        tube(water, [(5.3, 0, 7.2), (3.6, 0, 8.2), (2.0, 0, 7.4)], [0.28, 0.24, 0.34], 6, mat=rm)

    # 6 slender pavilion columns supporting round arches + ribbed verdigris cupola dome
    n_cols = 6
    ring_r = 10.4
    col_h = 13.5
    for k in range(n_cols):
        a = k * 2 * math.pi / n_cols
        cx, cy = math.cos(a) * ring_r, math.sin(a) * ring_r
        box(trim, (2.2, 2.2, 1.0), M((cx, cy, 3.2)), bevel=0.08)
        cone(stone, 0.85, 0.76, col_h - 1.0, 10, M((cx, cy, 3.7)))
        box(trim, (2.2, 2.2, 0.9), M((cx, cy, 3.7 + col_h - 0.8)), bevel=0.1)
        # Round arch to next column
        a2 = (k + 1) * 2 * math.pi / n_cols
        mid_a = (a + a2) / 2
        mx, my = math.cos(mid_a) * ring_r, math.sin(mid_a) * ring_r
        span_half = ring_r * math.sin(math.pi / n_cols)
        round_arch(stone, span_half, 3.4, 1.3, 1.8, M((mx, my, 16.4), rot=(0, 0, mid_a + math.pi / 2)), segs=8)

    # Drum cornice + ribbed verdigris dome (z = 19.6..26.5) + gold finial
    ring_mesh(trim, ring_r + 0.2, 0.9, 24, M((0, 0, 20.0)), tube_segs=6)
    dome_prof = [(10.8, 0.0), (10.3, 1.6), (8.9, 3.4), (6.5, 5.1), (3.4, 6.2), (0.0, 6.6)]
    lathe(verd, dome_prof, 18, M((0, 0, 20.2)))
    for k in range(12):
        a = k * 2 * math.pi / 12
        pts = [Vector((math.cos(a) * r, math.sin(a) * r, 20.2 + z)) for (r, z) in dome_prof]
        tube(gold, pts, [0.22] * len(pts), 4)
    cone(gold, 0.75, 0.14, 3.4, 8, M((0, 0, 26.7)))
    uvsphere(gold, 0.7, M((0, 0, 27.2)), u=8, v=6)

    # Coral tufts around cornice
    for k in range(6):
        a = k * 2 * math.pi / 6 + 0.35
        coral_burst(coral, (math.cos(a) * 10.6, math.sin(a) * 10.6, 20.6), rng, count=4, reach=2.2, base_r=0.3)


# -------------------------------------------------------------------------------------------------
# 6. CantorStall: carved limestone choir stall with scalloped back canopy
# -------------------------------------------------------------------------------------------------
@template("CantorStall", STONE=1400, TRIM=700, ALT=600, WOOD=500, GLOW=200)
def cantor_stall(t):
    stone, trim, shell, wood, glow = t.bm("STONE"), t.bm("TRIM"), t.bm("ALT"), t.bm("WOOD"), t.bm("GLOW")
    # Stepped dais + bench seat + armrests + scalloped back canopy
    box(stone, (10.6, 4.8, 0.9), M((0, 0, 0.45)), bevel=0.08)
    box(wood, (9.6, 2.2, 0.45), M((0, -0.4, 2.4)), bevel=0.05)
    for sx in (-1, 0, 1):
        box(stone, (0.9, 2.6, 2.5), M((sx * 4.4, -0.3, 1.9)), bevel=0.06)
        box(trim, (1.1, 3.0, 0.5), M((sx * 4.4, -0.3, 3.3)), bevel=0.06)
    # High carved backrest with three shell arches
    box(stone, (10.2, 0.9, 6.2), M((0, 1.5, 4.0)), bevel=0.08)
    box(trim, (10.6, 1.4, 0.7), M((0, 1.5, 7.3)), bevel=0.08)
    for sx in (-3.0, 0.0, 3.0):
        round_arch(trim, 1.3, 1.3, 0.42, 0.9, M((sx, 1.1, 5.4)), segs=6)
        uvsphere(shell, 0.75, M((sx, 1.15, 5.4)), u=7, v=5)
    tide_spiral(glow, (0, 0.98, 4.0), 0.75, 1.3, 0.14, Matrix.Identity(4))


# -------------------------------------------------------------------------------------------------
# 7. ConchRack: stone & verdigris rack holding spiralled singing conches
# -------------------------------------------------------------------------------------------------
@template("ConchRack", STONE=800, ACCENT=600, ALT=1200, GOLD=500, GLOW=300)
def conch_rack(t):
    stone, verd, shell, gold, glow = t.bm("STONE"), t.bm("ACCENT"), t.bm("ALT"), t.bm("GOLD"), t.bm("GLOW")
    box(stone, (6.8, 2.8, 0.8), M((0, 0, 0.4)), bevel=0.08)
    for sx in (-2.7, 2.7):
        box(stone, (0.9, 1.6, 5.0), M((sx, 0, 3.2)), bevel=0.08)
    for z_bar in (2.5, 4.6):
        box(verd, (6.0, 0.45, 0.45), M((0, 0, z_bar)), bevel=0.05)
    # 4 spiralled singing conch shells resting on the two tiers
    for z_c in (3.0, 5.1):
        for sx in (-1.35, 1.35):
            # Conch body: tapered curved tube + flared bell mouth
            pts = [Vector((sx - 0.85, 0.1, z_c)), Vector((sx - 0.1, -0.2, z_c + 0.25)), Vector((sx + 0.75, -0.45, z_c + 0.1))]
            tube(shell, pts, [0.18, 0.58, 0.76], 8)
            ring_mesh(gold, 0.72, 0.11, 10, M((sx + 0.75, -0.45, z_c + 0.1), rot=(0, math.pi / 2, 0)), tube_segs=4)
            uvsphere(glow, 0.35, M((sx + 0.65, -0.42, z_c + 0.1)), u=6, v=4)


# -------------------------------------------------------------------------------------------------
# 8. RefectoryTable: long set Frater dining table with goblets, platters, candelabrum & benches
# -------------------------------------------------------------------------------------------------
@template("RefectoryTable", WOOD=1200, STONE=900, METAL=900, ALT=800, GOLD=500, CANDLE=300)
def refectory_table(t):
    wood, stone, metal, shell, gold, candle = (
        t.bm("WOOD"), t.bm("STONE"), t.bm("METAL"), t.bm("ALT"), t.bm("GOLD"), t.bm("CANDLE"),
    )
    # Heavy stone trestles + long drowned-timber tabletop
    for sx in (-6.5, 0.0, 6.5):
        box(stone, (1.4, 4.2, 3.0), M((sx, 0, 1.5)), bevel=0.1)
    box(wood, (17.6, 4.8, 0.6), M((0, 0, 3.3)), bevel=0.06)
    # Two long side benches
    for sy in (-3.6, 3.6):
        box(wood, (16.4, 1.4, 0.4), M((0, sy, 1.85)), bevel=0.05)
        for sx in (-6.0, 6.0):
            box(stone, (0.9, 1.2, 1.65), M((sx, sy, 0.82)), bevel=0.06)
    # Tableware: shell platters, bronze goblets & central candelabrum
    for sx in (-5.8, -2.0, 2.0, 5.8):
        for sy in (-1.2, 1.2):
            cone(shell, 0.82, 0.55, 0.22, 10, M((sx, sy, 3.6)))
            cone(metal, 0.22, 0.34, 0.78, 8, M((sx + 0.85, sy * 0.75, 3.6)))
    # Central 3-branch bronze candelabrum with glowing warm tapers
    cone(gold, 0.55, 0.22, 1.8, 8, M((0, 0, 3.6)))
    box(gold, (2.2, 0.22, 0.22), M((0, 0, 5.2)))
    for sx in (-0.95, 0.0, 0.95):
        cone(candle, 0.14, 0.12, 0.9, 6, M((sx, 0, 5.3)))


# -------------------------------------------------------------------------------------------------
# 9. ScriptoriumDesk: carved stone scribe desk + slate tide-chart frame (guide image upper right)
# -------------------------------------------------------------------------------------------------
@template("ScriptoriumDesk", STONE=1400, TRIM=700, WOOD=600, ACCENT=700, GOLD=600, GLOW=700, SILK=500)
def scriptorium_desk(t):
    stone, trim, wood, verd, gold, glow, silk = (
        t.bm("STONE"), t.bm("TRIM"), t.bm("WOOD"), t.bm("ACCENT"), t.bm("GOLD"), t.bm("GLOW"), t.bm("SILK"),
    )
    # Scribe's stone desk + bench
    box(stone, (8.6, 3.8, 3.2), M((0, -0.8, 1.6)), bevel=0.1)
    box(trim, (9.0, 4.4, 0.45), M((0, -0.8, 3.55), rot=(-0.22, 0, 0)), bevel=0.06)
    box(wood, (6.4, 1.5, 0.4), M((0, -4.0, 1.9)), bevel=0.05)
    for sx in (-2.4, 2.4):
        box(stone, (0.8, 1.3, 1.7), M((sx, -4.0, 0.85)), bevel=0.05)
    # Rolled scroll + clay scroll jar beside desk
    cone(silk, 0.28, 0.28, 2.4, 8, M((-1.6, -0.9, 3.95), rot=(0, math.pi / 2, 0.2)))
    cone(stone, 0.9, 0.65, 2.2, 10, M((5.2, -0.4, 0.0)))
    for k in range(3):
        cone(silk, 0.18, 0.18, 1.4, 6, M((5.0 + k * 0.2, -0.4, 1.8), rot=(0.15 * (k - 1), 0.12, 0)))

    # Tall carved slate star/tide-chart tablet framed behind the desk (guide image upper-right charts!)
    box(stone, (9.6, 1.1, 9.6), M((0, 2.0, 8.4)), bevel=0.14)
    box(verd, (8.2, 1.25, 8.0), M((0, 1.95, 8.4)))
    # Celestial / tide rings & radiating compass spokes in gold & aqua glow
    ring_mesh(gold, 3.2, 0.16, 16, M((0, 1.25, 8.4), rot=(math.pi / 2, 0, 0)), tube_segs=4)
    ring_mesh(glow, 1.9, 0.12, 14, M((0, 1.22, 8.4), rot=(math.pi / 2, 0, 0)), tube_segs=4)
    for k in range(4):
        a = k * math.pi / 4
        box(gold, (6.4, 0.16, 0.14), M((0, 1.24, 8.4), rot=(0, a, 0)))
    tide_spiral(glow, (0, 1.22, 8.4), 1.35, 1.4, 0.16, Matrix.Identity(4))


# -------------------------------------------------------------------------------------------------
# 10. SacristyPress: arched vestment press with hanging cantor robes & coiled bell-rope bronze bin
# -------------------------------------------------------------------------------------------------
@template("SacristyPress", STONE=1400, WOOD=900, SILK=1200, ACCENT=900, METAL=700, GOLD=400)
def sacristy_press(t):
    stone, wood, silk, verd, metal, gold = (
        t.bm("STONE"), t.bm("WOOD"), t.bm("SILK"), t.bm("ACCENT"), t.bm("METAL"), t.bm("GOLD"),
    )
    # Arched recessed limestone cabinet (x in [-4.5, 2.0])
    box(stone, (7.6, 3.8, 1.0), M((-1.2, 0, 0.5)), bevel=0.1)
    for sx in (-4.5, 2.1):
        box(stone, (1.2, 3.6, 10.5), M((sx, 0, 6.0)), bevel=0.1)
    box(stone, (7.8, 1.0, 11.2), M((-1.2, 1.4, 6.2)), bevel=0.1)
    round_arch(stone, 3.3, 2.6, 1.2, 3.6, M((-1.2, 0, 10.8)), segs=8)
    # Bronze hanging rod + 2 pale silk cantor vestments hanging inside
    box(metal, (5.6, 0.35, 0.35), M((-1.2, -0.2, 9.8)))
    for rx in (-2.5, 0.1):
        cone(silk, 1.35, 0.65, 6.4, 10, M((rx, -0.2, 2.8)))
        box(gold, (0.35, 0.8, 5.8), M((rx, -0.75, 5.8)))
        box(wood, (2.2, 0.3, 0.25), M((rx, -0.2, 9.3)))
    # Bronze bin beside press holding coiled bell-ropes
    cone(verd, 1.8, 2.1, 3.4, 12, M((4.6, -0.2, 0.0)))
    ring_mesh(gold, 2.1, 0.18, 12, M((4.6, -0.2, 3.3)), tube_segs=4)
    for k in range(4):
        ring_mesh(wood, 1.35 - k * 0.12, 0.24, 12, M((4.6, -0.2, 3.45 + k * 0.34)), tube_segs=5)


# -------------------------------------------------------------------------------------------------
# 11. CantorNicheStatue: arched shell-hooded stone niche with robed cantor holding a conch
# -------------------------------------------------------------------------------------------------
@template("CantorNicheStatue", STONE=1800, TRIM=1600, ALT=900, ACCENT=600, GOLD=500, GLOW=300)
def cantor_niche_statue(t):
    stone, trim, shell, verd, gold, glow = (
        t.bm("STONE"), t.bm("TRIM"), t.bm("ALT"), t.bm("ACCENT"), t.bm("GOLD"), t.bm("GLOW"),
    )
    # Stepped pedestal + framed arched niche backing
    box(stone, (7.6, 5.0, 2.4), M((0, 0, 1.2)), bevel=0.14)
    box(trim, (6.4, 4.2, 1.4), M((0, 0, 3.1)), bevel=0.1)
    for sx in (-3.1, 3.1):
        box(stone, (1.4, 3.2, 11.2), M((sx, 0.4, 9.2)), bevel=0.1)
    box(stone, (7.4, 1.2, 13.8), M((0, 1.6, 10.5)), bevel=0.1)
    round_arch(stone, 3.1, 3.2, 1.3, 3.2, M((0, 0.4, 14.8)), segs=10)
    # Scalloped shell hood behind head
    scalloped_shell(shell, 2.6, 1.8, 7, M((0, 1.0, 13.5), rot=(math.pi / 2, 0, 0)))

    # Robed Nereth Cantor figure standing at z = 3.8..15.2
    cone(trim, 2.15, 1.15, 8.8, 12, M((0, -0.2, 3.8)))
    uvsphere(trim, 1.35, M((0, -0.2, 12.6)), u=8, v=6)  # hooded shoulders
    uvsphere(trim, 0.92, M((0, -0.35, 14.3)), u=8, v=6)  # head
    # Raised arms cradling a glowing conch shell + bronze staff
    tube(trim, [(-1.2, -0.2, 12.2), (-1.1, -1.2, 10.9), (-0.3, -1.5, 11.2)], [0.42, 0.34, 0.28], 6)
    tube(trim, [(1.2, -0.2, 12.2), (1.3, -1.0, 11.0), (1.8, -1.2, 11.8)], [0.42, 0.34, 0.28], 6)
    uvsphere(shell, 0.72, M((-0.15, -1.65, 11.3)), u=7, v=5)
    uvsphere(glow, 0.32, M((-0.15, -1.95, 11.3)), u=6, v=4)
    # Verdigris & gold staff in right hand
    tube(verd, [(1.9, -1.2, 3.8), (1.9, -1.2, 16.0)], [0.22, 0.18], 6)
    ring_mesh(gold, 0.65, 0.14, 10, M((1.9, -1.2, 16.4), rot=(math.pi / 2, 0, 0)), tube_segs=4)


# -------------------------------------------------------------------------------------------------
# 12. DrownedSundial: large circular submerged garth sundial with bronze gnomon (guide image!)
# -------------------------------------------------------------------------------------------------
@template("DrownedSundial", STONE=1600, TRIM=1000, ACCENT=900, GOLD=600, MOSS=500)
def drowned_sundial(t):
    stone, trim, verd, gold, moss = t.bm("STONE"), t.bm("TRIM"), t.bm("ACCENT"), t.bm("GOLD"), t.bm("MOSS")
    # Wide flat carved circular plinth resting on garth seabed
    cone(stone, 11.2, 10.8, 0.9, 24, M((0, 0, 0.0)))
    cone(trim, 9.6, 9.6, 0.35, 24, M((0, 0, 0.9)))
    ring_mesh(stone, 10.2, 0.55, 24, M((0, 0, 1.15)), tube_segs=5)
    ring_mesh(gold, 7.6, 0.18, 24, M((0, 0, 1.32)), tube_segs=4)
    ring_mesh(gold, 4.2, 0.16, 20, M((0, 0, 1.32)), tube_segs=4)
    # 12 radial hour spokes
    for k in range(12):
        a = k * math.pi / 6
        box(trim, (5.2, 0.42, 0.24), M((math.cos(a) * 6.8, math.sin(a) * 6.8, 1.32), rot=(0, 0, a)))
    # Sculpted triangular verdigris-bronze gnomon blade rising at center
    tube(verd, [(0, -2.4, 1.25), (0, 3.6, 1.25), (0, 2.2, 4.4), (0, -2.4, 1.25)], [0.42, 0.42, 0.28, 0.42], 5)
    box(verd, (0.45, 5.2, 2.4), M((0, 0.6, 2.4), rot=(0.45, 0, 0)), bevel=0.05)
    uvsphere(gold, 0.65, M((0, 0, 1.55)), u=8, v=6)
    # Seaweed tufts clinging to rim
    for k in range(4):
        a = k * math.pi / 2 + 0.5
        rock_clean(moss, (2.6, 2.2, 0.9), M((math.cos(a) * 9.8, math.sin(a) * 9.8, 0.4)), 40 + k, subdiv=1)


# -------------------------------------------------------------------------------------------------
# 13. BrainCoralMound: organic ridged reef coral dome with glowing polyps
# -------------------------------------------------------------------------------------------------
@template("BrainCoralMound", STONE=600, CORAL=2400, ALT=800, GLOW=400)
def brain_coral_mound(t):
    stone, coral, shell, glow = t.bm("STONE"), t.bm("CORAL"), t.bm("ALT"), t.bm("GLOW")
    rng = t.rng
    rock_clean(stone, (9.8, 8.8, 2.0), M((0, 0, 0.0)), 61, subdiv=2)
    # Clustered sculpted brain-coral domes
    domes = [(0.0, 0.0, 1.2, 3.2), (-2.6, 1.3, 0.9, 2.2), (2.8, -1.1, 0.9, 2.4), (1.1, 2.4, 0.8, 1.8)]
    for idx, (dx, dy, dz, r) in enumerate(domes):
        rock_clean(coral, (r * 2.1, r * 1.95, r * 1.45), M((dx, dy, dz)), 70 + idx, roughness=0.16, subdiv=2, flat_bottom=False)
        # Ridged coral rings around each lobe
        ring_mesh(shell, r * 0.72, 0.22, 12, M((dx, dy, dz + r * 0.55), rot=(0.2 * idx, 0.15, idx)), tube_segs=4)
    # Branching shoots + glowing aqua polyp buds
    coral_burst(coral, (0.0, 0.0, 3.6), rng, count=6, reach=2.8, base_r=0.34)
    for k in range(6):
        a = k * math.pi / 3
        uvsphere(glow, 0.28, M((math.cos(a) * 3.1, math.sin(a) * 2.8, 2.2 + (k % 2) * 0.7)), u=6, v=4)


# -------------------------------------------------------------------------------------------------
# 14. DorterCot: monastic stone bed with draped canopy frame and warm shell bedside lamp
# -------------------------------------------------------------------------------------------------
@template("DorterCot", STONE=1000, SILK=1200, WOOD=700, FOLIAGE=500, ALT=500, CANDLE=300)
def dorter_cot(t):
    stone, silk, wood, kelp, shell, candle = (
        t.bm("STONE"), t.bm("SILK"), t.bm("WOOD"), t.bm("FOLIAGE"), t.bm("ALT"), t.bm("CANDLE"),
    )
    # Carved limestone bed plinth + pale linen mattress & pillow
    box(stone, (7.8, 4.4, 1.5), M((0, 0, 0.75)), bevel=0.1)
    box(silk, (7.2, 3.8, 0.75), M((0, 0, 1.85)), bevel=0.14)
    box(silk, (1.5, 3.0, 0.55), M((-2.5, 0, 2.45)), bevel=0.16)
    # Four timber canopy posts + top frame + draped kelp/silk side curtain
    for sx in (-3.6, 3.6):
        for sy in (-1.9, 1.9):
            box(wood, (0.45, 0.45, 8.2), M((sx, sy, 4.2)), bevel=0.04)
    box(wood, (7.6, 0.4, 0.4), M((0, -1.9, 8.3)))
    box(wood, (7.6, 0.4, 0.4), M((0, 1.9, 8.3)))
    box(wood, (0.4, 4.2, 0.4), M((-3.6, 0, 8.3)))
    box(wood, (0.4, 4.2, 0.4), M((3.6, 0, 8.3)))
    # Hanging kelp/silk curtain at head & back
    box(silk, (7.0, 0.25, 5.8), M((0, 1.82, 5.2)))
    for k in range(-2, 3):
        tube(kelp, [(k * 1.4, 1.7, 8.1), (k * 1.4 + 0.2, 1.5, 4.2)], [0.16, 0.08], 4)
    # Bedside stone stand with glowing shell lamp
    box(stone, (1.6, 1.6, 2.4), M((-4.9, 0.4, 1.2)), bevel=0.08)
    scalloped_shell(shell, 0.85, 0.65, 5, M((-4.9, 0.4, 2.4)))
    uvsphere(candle, 0.34, M((-4.9, 0.4, 2.85)), u=6, v=4)


def build_kit():
    reset_scene()
    kit = bpy.data.collections.new("SunkenF37Kit")
    bpy.context.scene.collection.children.link(kit)
    manifest = {}
    for name, (fn, budget) in F37_TEMPLATES.items():
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
        filepath=os.path.join(OUT_DIR, "SunkenF37Kit.fbx"),
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
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT_DIR, "SunkenF37Kit.blend"))


if __name__ == "__main__":
    kit, manifest = build_kit()
    export_kit(kit, manifest)
    preview_dir = os.path.join(OUT_DIR, "previews")
    render_previews(kit, preview_dir, list(F37_TEMPLATES.keys()), tile=520, cols=5)
    print(json.dumps(manifest, indent=2))
