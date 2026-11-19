"""
Fungal Hollow Floor 9 (Rotcap Keep) sculpted assets, generated in Blender.

The Velmari citadel devoured from the inside by rotcaps, and the scene of the Lampkeepers' last stand
against the Mycelial Brutes and Sporecap Chanters. Every asset mixes bruised violet stone/caps with
sickly yellow-green glowing rot veins, gills and spore pustules. Same conventions as generate_fungal_f6_kit.py
(1 unit = 1 stud, standing on z = 0, front -Y in Blender / +Z in Roblox, one mesh per colour role
named "<Template>__<ROLE>"); it reuses that script's helpers.

    BrokenBarricade  a smashed Lampkeeper barricade overgrown with violet shelf-rotcaps and yellow-green veins
    RotVat           a slate brewing vat brimming with bubbling yellow-green rot and clinging violet shelf-caps
    OssuaryBones     giant curved rib-arches and a weathered skull choked with yellow-green rot veins and violet caps
    RotcapTower      a ruined Velmari keep tower split by bursting violet rotcaps and cascading yellow-green webs
    VelmariBanner    a tattered Velmari standard on a stone plinth crept over by violet caps and yellow-green rot
    RotcapCluster    a multi-tiered cluster of warped violet rotcaps with blazing yellow-green gills and hanging pustules
    RotMyceliumWeb   a thick creeping patch of yellow-green glowing mycelium veins, rot-bulbs and violet shelf-caps

Outputs (assets-source/tower/fungal_f9_kit/): FungalF9Kit.blend, FungalF9Kit.fbx, manifest.json, previews/.

Run headless:  blender --background --python tools/blender/generate_fungal_f9_kit.py
"""
import bpy, bmesh, math, os, json, random, runpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT_DIR = os.path.join(ROOT, "assets-source", "tower", "fungal_f9_kit")

f6 = runpy.run_path(os.path.join(HERE, "generate_fungal_f6_kit.py"), init_globals={"RUN_F6": False})
Template = f6["Template"]
M = f6["M"]
box = f6["box"]
cone = f6["cone"]
ico = f6["ico"]
uvsphere = f6["uvsphere"]
lathe = f6["lathe"]
tube = f6["tube"]
displace = f6["displace"]
rock = f6["rock"]
ring_mesh = f6["ring_mesh"]
reset_scene = f6["reset_scene"]
finalize = f6["finalize"]
render_previews = f6["render_previews"]
_cap = f6["_cap"]
_gill_wheel = f6["_gill_wheel"]
ROLE_PREVIEW = f6["ROLE_PREVIEW"]
ROLE_PREVIEW.update({
    "WOOD": (0.36, 0.27, 0.21),
    "FOLIAGE": (0.44, 0.15, 0.27),
    "ALT": (0.82, 0.85, 0.72),
    "GLOW": (0.71, 0.96, 0.29),
    "BULB": (0.83, 1.00, 0.38),
    "CAP": (0.38, 0.19, 0.67),
    "MOSS": (0.30, 0.24, 0.46),
})

DEFAULT_BUDGET = 3500
F9_TEMPLATES = {}


def rock_clean(bm, size, mat, seed, roughness=0.22, subdiv=2, flat_bottom=True):
    """A displaced boulder built in a fresh bmesh and copied in, so earlier geometry in `bm` stays untouched."""
    tmp = bmesh.new()
    rock(tmp, size, mat, seed, roughness=roughness, subdiv=subdiv, flat_bottom=flat_bottom)
    vmap = [bm.verts.new(v.co) for v in tmp.verts]
    for f in tmp.faces:
        bm.faces.new([vmap[v.index] for v in f.verts])
    tmp.free()


def box_clean(bm, size, mat, bevel=0.0, segs=1):
    """A beveled box built in a fresh bmesh and copied in, avoiding bmesh bevel vertex-index drift."""
    tmp = bmesh.new()
    box(tmp, size, mat, bevel=bevel, segs=segs)
    vmap = [bm.verts.new(v.co) for v in tmp.verts]
    for f in tmp.faces:
        bm.faces.new([vmap[v.index] for v in f.verts])
    tmp.free()


def template(name, **budget):
    def deco(fn):
        F9_TEMPLATES[name] = (fn, budget)
        return fn
    return deco


@template("BrokenBarricade", WOOD=1200, TRIM=900, STEM=400, MOSS=300, CAP=500, GLOW=400, BULB=300)
def broken_barricade(t):
    """A breached barricade (~15 wide, 5.5 tall) overgrown with violet rotcaps and yellow-green veins."""
    rng = t.rng
    wood, trim, cable, moss, glow, bulb = (
        t.bm("WOOD"), t.bm("TRIM"), t.bm("STEM"), t.bm("MOSS"), t.bm("GLOW"), t.bm("BULB")
    )
    for x, top_z, lean_x, lean_y in (
        (-6.6, 5.2, -0.8, 0.4),
        (-3.2, 2.3, -0.5, -0.6),
        (3.1, 2.6, 0.4, -0.5),
        (6.5, 5.0, 0.9, 0.3),
    ):
        tube(wood, [Vector((x, 0.1, -0.2)), Vector((x + lean_x, lean_y, top_z))], [0.32, 0.22], 6)

    for sx in (-1, 1):
        for k in range(3):
            z = 1.1 + k * 1.15
            ln = rng.uniform(4.2, 5.4)
            pitch = sx * rng.uniform(0.18, 0.42)
            yaw = rng.uniform(-0.15, 0.15)
            cx = sx * (4.8 + rng.uniform(-0.3, 0.3))
            box_clean(wood, (ln, 0.32, 0.72), M((cx, -0.2, z), rot=(0.0, pitch, yaw)), bevel=0.04)
        box_clean(wood, (4.8, 0.34, 0.76), M((sx * 1.9, -1.6 + sx * 0.2, 0.38), rot=(0.12, 0.08 * sx, 0.45 * sx)), bevel=0.04)

    # Broken wooden wagon wheel half-buried in front of the right wing.
    wheel_cf = M((2.8, -2.0, 1.35), rot=(0.95, 0.25, -0.35))
    ring_mesh(wood, 1.45, 0.16, 12, wheel_cf, tube_segs=4)
    for k in range(6):
        a = k * math.pi / 3
        p0 = wheel_cf @ Vector((0, 0, 0))
        p1 = wheel_cf @ Vector((math.cos(a) * 1.4, math.sin(a) * 1.4, 0))
        tube(wood, [p0, p1], [0.09, 0.07], 4, cap=False)

    # Toppled slate slabs knocked loose from the keep wall.
    for x, y, z, rz in ((-5.4, -0.9, 1.3, 0.28), (-1.4, 0.8, 1.15, -0.45), (5.0, -0.8, 1.4, -0.32)):
        box_clean(trim, (2.6, 0.55, 2.6), M((x, y, z), rot=(0.45, 0.18, rz)), bevel=0.1)

    # Snapped mycelium lashing cables dangling from the outer posts + glowing yellow-green rot veins.
    for sx in (-1, 1):
        p0 = Vector((sx * 6.9, 0.2, 4.4))
        pts = [p0, Vector((sx * 5.0, -0.5, 3.3)), Vector((sx * 3.8, -0.9, 1.4)), Vector((sx * 3.2, -1.2, 0.15))]
        tube(cable, pts, [0.13, 0.12, 0.10, 0.08], 4, cap=False)
        vein_pts = [
            Vector((sx * 6.4, -0.4, 3.2)),
            Vector((sx * 5.2, -0.7, 2.1)),
            Vector((sx * 3.6, -1.1, 0.8)),
            Vector((sx * 1.8, -1.4, 0.25)),
        ]
        tube(glow, vein_pts, [0.14, 0.11, 0.09, 0.06], 4, cap=False)

    # Violet shelf-rotcaps and glowing yellow-green pustules overgrowing the breached timber and slate.
    for (cx, cy, cz, r, h, s) in (
        (-5.6, -1.0, 2.5, 1.35, 0.72, 301),
        (-3.6, 0.2, 1.6, 1.05, 0.55, 303),
        (5.4, -0.9, 2.3, 1.25, 0.68, 307),
    ):
        _cap(t, Vector((cx, cy, cz)), r, h, s, gill_role="GLOW", spot_role="BULB", spots=3, lip=r * 0.15, segs=10, displace_amp=r * 0.04)

    for (bx, by, bz, br) in ((-4.8, -0.8, 0.55, 0.28), (-1.2, -0.9, 0.45, 0.24), (4.2, -0.8, 0.55, 0.3)):
        uvsphere(bulb, br, M((bx, by, bz)), u=7, v=5)

    rock_clean(moss, (13.4, 3.6, 0.65), M((0, 0.2, -0.2)), 91, roughness=0.32, subdiv=2)


@template("RotVat", TRIM=900, GLOW=500, BULB=400, MOSS=400, WOOD=300, CAP=500)
def rot_vat(t):
    """A Velmari stone brewing vat brimming with bubbling yellow-green rot and violet shelf-caps (~6.8 wide)."""
    rng = t.rng
    trim, glow, bulb, moss, wood = t.bm("TRIM"), t.bm("GLOW"), t.bm("BULB"), t.bm("MOSS"), t.bm("WOOD")
    cone(trim, 2.8, 2.9, 0.7, 12, M((0, 0, 0)))
    n_staves = 12
    for k in range(n_staves):
        a = k * 2 * math.pi / n_staves
        r = 2.65
        box_clean(trim, (1.35, 0.55, 3.8), M((math.cos(a) * r, math.sin(a) * r, 2.2), rot=(0, 0, a + math.pi / 2)), bevel=0.08)
    for z in (1.1, 3.3):
        ring_mesh(trim, 2.95, 0.22, 16, M((0, 0, z)), tube_segs=5)

    cone(glow, 2.45, 2.45, 0.25, 14, M((0, 0, 3.45)))
    for k in range(8):
        a = rng.uniform(0, 2 * math.pi)
        d = rng.uniform(0.2, 1.85)
        s = rng.uniform(0.24, 0.52)
        uvsphere(bulb, s, M((math.cos(a) * d, math.sin(a) * d, 3.65 + s * 0.4), scale=(1.0, 1.0, 0.85)), u=8, v=6)

    # Spilling yellow-green slime streams and violet shelf-rotcaps clinging to the vat staves.
    for (sx, sy) in ((0.6, -2.4), (-1.9, -1.8)):
        tube(glow, [Vector((sx, sy, 3.6)), Vector((sx * 1.15, sy * 1.22, 2.1)), Vector((sx * 1.2, sy * 1.28, 0.25))], [0.22, 0.16, 0.12], 4, cap=False)
    for (cx, cy, cz, r, h, s) in (
        (-2.85, -1.1, 1.9, 1.05, 0.55, 311),
        (2.85, -0.6, 2.5, 0.9, 0.48, 313),
        (1.6, 2.4, 1.4, 1.1, 0.58, 317),
    ):
        _cap(t, Vector((cx, cy, cz)), r, h, s, gill_role="GLOW", spot_role="BULB", spots=3, lip=r * 0.14, segs=10, displace_amp=r * 0.04)

    paddle_cf = M((-1.1, -0.4, 3.3), rot=(0.45, -0.35, 0.2))
    tube(wood, [paddle_cf @ Vector((0, 0, -2.2)), paddle_cf @ Vector((0, 0, 2.3))], [0.16, 0.13], 5)
    box_clean(wood, (0.7, 0.18, 1.3), paddle_cf @ M((0, 0, -1.6)), bevel=0.03)

    rock_clean(moss, (6.8, 6.4, 0.7), M((0, 0, -0.25)), 93, roughness=0.3, subdiv=2)


@template("OssuaryBones", ALT=1400, CAP=700, STEM=500, GLOW=500, BULB=300, MOSS=400)
def ossuary_bones(t):
    """Giant beast ribs and a weathered skull choked with yellow-green rot veins and violet caps (~12 wide)."""
    rng = t.rng
    bones, stem, glow, bulb, moss = t.bm("ALT"), t.bm("STEM"), t.bm("GLOW"), t.bm("BULB"), t.bm("MOSS")
    rock_clean(moss, (12.4, 9.6, 1.1), M((0, 0.4, -0.35)), 95, roughness=0.35, subdiv=2)

    for row in range(4):
        y_off = -0.2 + row * 1.85
        span_r = 4.6 - row * 0.38
        arch_h = 7.4 - row * 0.55
        for sx in (-1, 1):
            pts = []
            radii = []
            for s in range(6):
                u = s / 5
                ang = u * math.pi * 0.48
                x = sx * (span_r * math.cos(ang) + 0.35)
                z = 0.2 + arch_h * math.sin(ang)
                y = y_off + math.sin(u * math.pi) * 0.45
                pts.append(Vector((x, y, z)))
                radii.append(0.46 - 0.18 * u)
            tube(bones, pts, radii, 6)
            # Yellow-green mycelium tendrils creeping up the outer rib arches.
            if row in (0, 2):
                tube(glow, pts[:4], [0.12, 0.10, 0.08, 0.06], 4, cap=False)

    for k in range(5):
        box_clean(bones, (1.4, 1.3, 1.1), M((0, -0.5 + k * 1.55, 0.55), rot=(0.1, 0, rng.uniform(-0.15, 0.15))), bevel=0.14)

    skull_at = Vector((-0.6, -2.5, 2.0))
    uvsphere(bones, 2.1, M(skull_at + Vector((0, 0.4, 0.5)), scale=(1.05, 1.18, 0.92)), u=12, v=8)
    box_clean(bones, (2.2, 1.8, 1.35), M(skull_at + Vector((0, -1.35, -0.45)), rot=(0.18, 0, -0.1)), bevel=0.18)
    for sx in (-1, 1):
        cone(bones, 0.65, 0.18, 1.6, 6, M(skull_at + Vector((sx * 1.35, -0.6, 0.2)), rot=(0.8, 0, sx * 0.4)))
        # Sickly yellow-green eye-socket rot pools inside the skull.
        uvsphere(bulb, 0.42, M(skull_at + Vector((sx * 0.72, -1.45, 0.45))), u=8, v=6)

    # Violet rotcaps with yellow-green gills & spots bursting through the ribs and skull.
    for (x, y, z, r, h, lean_x) in (
        (-2.0, -2.0, 4.6, 2.3, 1.25, -0.3),
        (2.4, 1.2, 4.2, 2.0, 1.1, 0.4),
        (0.5, 3.0, 3.6, 1.7, 0.95, 0.1),
        (-3.2, 0.4, 2.8, 1.45, 0.85, -0.5),
    ):
        base = Vector((x, y, 0.3))
        top = Vector((x + lean_x, y - 0.2, z))
        tube(stem, [base, (base + top) / 2 + Vector((lean_x * 0.4, 0, 0)), top], [r * 0.28, r * 0.22, r * 0.24], 7, cap=False)
        _cap(t, top, r, h, int(abs(x) * 19 + z * 7), gill_role="GLOW", spot_role="BULB", spots=4, lip=r * 0.18, segs=12, displace_amp=r * 0.04)


@template("RotcapTower", TRIM=1600, ACCENT=600, CAP=900, GLOW=700, STEM=500, MOSS=400, BULB=300)
def rotcap_tower(t):
    """A ruined Velmari watchtower split by bursting violet rotcaps and cascading yellow-green webs (~17 wide, 24 tall)."""
    rng = t.rng
    trim, accent, glow, stem, moss, bulb = (
        t.bm("TRIM"), t.bm("ACCENT"), t.bm("GLOW"), t.bm("STEM"), t.bm("MOSS"), t.bm("BULB")
    )
    box_clean(trim, (11.2, 11.2, 2.2), M((0, 0, 1.1)), bevel=0.25)
    box_clean(trim, (9.4, 9.4, 1.8), M((0, 0, 3.1)), bevel=0.2)
    box_clean(trim, (8.0, 8.0, 9.5), M((0, 0, 8.6)), bevel=0.22)
    box_clean(trim, (7.6, 7.6, 7.6), M((0.35, -0.25, 16.8), rot=(0.06, 0.08, -0.05)), bevel=0.22)

    box_clean(accent, (8.4, 8.4, 0.8), M((0, 0, 13.0)), bevel=0.1)
    box_clean(accent, (3.2, 0.8, 4.6), M((0, -3.9, 8.6)), bevel=0.1)
    _gill_wheel(t, Vector((0, -4.15, 16.2)), 1.6, (0, 0, 0))
    for bx, by, bh in (
        (-3.1, -3.1, 2.4), (3.1, -3.1, 2.0), (-3.1, 3.1, 2.5), (3.1, 3.1, 1.3), (0.0, 3.1, 2.1),
    ):
        box_clean(trim, (2.0, 1.8, bh), M((bx + 0.4, by - 0.3, 20.6 + bh / 2), rot=(0.05, 0.06, -0.04)), bevel=0.1)

    for (cx, cy, cz, r, h, s) in (
        (-3.8, -3.6, 13.4, 4.6, 2.3, 101),
        (4.1, -2.4, 10.6, 3.7, 1.8, 107),
        (1.0, -2.0, 20.8, 4.4, 2.2, 113),
    ):
        top = Vector((cx, cy, cz))
        _cap(t, top, r, h, s, gill_role="GLOW", spot_role="BULB", spots=5, lip=r * 0.16, segs=14, displace_amp=r * 0.04)

    # Thick mycelium cables AND glowing yellow-green rot veins streaming down the tower fissure.
    for k in range(5):
        sx = -3.4 + k * 1.7
        pts = [
            Vector((sx, -4.8, -0.2)),
            Vector((sx * 0.9 + rng.uniform(-0.4, 0.4), -4.1, 5.5)),
            Vector((sx * 0.85, -4.0, 12.0)),
            Vector((sx * 0.7 + 0.3, -3.9, 18.8)),
        ]
        tube(stem, pts, [0.48, 0.38, 0.30, 0.22], 6, cap=False)
        if k in (1, 2, 3):
            glow_pts = [p + Vector((0.18, -0.32, 0)) for p in pts]
            tube(glow, glow_pts, [0.16, 0.14, 0.12, 0.08], 4, cap=False)
            uvsphere(bulb, 0.34, M(glow_pts[2]), u=7, v=5)

    rock_clean(moss, (13.0, 12.6, 1.3), M((0, 0, -0.35)), 97, roughness=0.35, subdiv=2)


@template("VelmariBanner", WOOD=500, TRIM=400, FOLIAGE=900, ALT=500, GLOW=300, CAP=400)
def velmari_banner(t):
    """A tattered Velmari keep standard (~5.5 wide, 15 tall) crept over by violet caps and yellow-green rot."""
    wood, trim, cloth, emblem, glow = t.bm("WOOD"), t.bm("TRIM"), t.bm("FOLIAGE"), t.bm("ALT"), t.bm("GLOW")
    box_clean(trim, (2.6, 2.6, 1.0), M((0, 0, 0.5)), bevel=0.15)
    cone(wood, 0.32, 0.22, 13.4, 7, M((0, 0, 0.9)))
    cone(trim, 0.38, 0.06, 1.1, 6, M((0, 0, 13.9)))
    tube(wood, [Vector((-2.7, -0.25, 12.1)), Vector((2.7, -0.25, 12.1))], [0.22, 0.22], 6)

    cols, rows = 8, 9
    verts = []
    w, top_z, bot_z = 4.6, 12.0, 3.6
    for r in range(rows + 1):
        v = r / rows
        row = []
        for c in range(cols + 1):
            u = c / cols
            x = -w / 2 + w * u
            tear = 1.4 * math.sin(u * math.pi) * (v ** 2) + 0.55 * math.sin(u * 5 * math.pi) * (v ** 3)
            z = top_z - (top_z - bot_z) * v + tear
            y = -0.35 - 0.55 * math.sin(v * math.pi) * (0.7 + 0.3 * math.cos(u * math.pi))
            row.append(cloth.verts.new((x, y, z)))
        verts.append(row)
    for r in range(rows):
        for c in range(cols):
            cloth.faces.new((verts[r][c], verts[r][c + 1], verts[r + 1][c + 1], verts[r + 1][c]))

    crest_y = -0.92
    ring_mesh(emblem, 0.85, 0.08, 14, M((0, crest_y, 8.2), rot=(math.pi / 2, 0, 0)), tube_segs=4)
    tube(emblem, [Vector((0, crest_y, 6.2)), Vector((0, crest_y, 10.1))], [0.10, 0.07], 4, cap=False)
    for sx in (-1, 1):
        tube(emblem, [Vector((0, crest_y, 7.6)), Vector((sx * 1.15, crest_y, 9.2))], [0.08, 0.05], 4, cap=False)
        tube(emblem, [Vector((0, crest_y, 8.6)), Vector((sx * 0.9, crest_y, 10.0))], [0.07, 0.04], 4, cap=False)
    uvsphere(glow, 0.26, M((0, crest_y, 8.2)), u=8, v=6)

    # Violet shelf-rotcaps and creeping yellow-green rot vein on the plinth and lower pike.
    tube(glow, [Vector((-0.9, -1.25, 0.2)), Vector((-0.35, -0.65, 1.4)), Vector((0.25, -0.32, 3.1))], [0.11, 0.09, 0.07], 4, cap=False)
    _cap(t, Vector((0.85, -0.8, 1.35)), 0.95, 0.5, 331, gill_role="GLOW", spot_role=None, lip=0.12, segs=10, displace_amp=0.04)


@template("RotcapCluster", CAP=1100, GLOW=800, BULB=500, STEM=600, MOSS=400)
def rotcap_cluster(t):
    """A multi-tiered cluster of warped violet rotcaps with blazing yellow-green gills and hanging pustules (~10 wide, 8.5 tall)."""
    rng = t.rng
    stem, glow, bulb, moss = t.bm("STEM"), t.bm("GLOW"), t.bm("BULB"), t.bm("MOSS")
    rock_clean(moss, (9.6, 8.8, 1.2), M((0, 0, -0.3)), 341, roughness=0.35, subdiv=2)

    caps = (
        (0.0, 0.2, 7.2, 3.6, 1.7, 0.3, -0.2, 343),
        (-2.8, -1.4, 4.9, 2.4, 1.2, -0.8, -0.4, 347),
        (2.7, -1.2, 5.4, 2.6, 1.3, 0.9, -0.3, 349),
        (-1.4, 2.3, 4.1, 2.0, 1.0, -0.4, 0.7, 353),
        (1.8, 2.1, 3.4, 1.7, 0.85, 0.6, 0.5, 359),
    )
    for (x, y, z, r, h, lx, ly, seed) in caps:
        base = Vector((x * 0.45, y * 0.45, 0.2))
        top = Vector((x + lx, y + ly, z))
        mid = (base + top) / 2 + Vector((lx * 0.4, ly * 0.4, 0))
        tube(stem, [base, mid, top], [r * 0.34, r * 0.24, r * 0.26], 8, cap=False)
        _cap(t, top, r, h, seed, gill_role="GLOW", spot_role="BULB", spots=5, lip=r * 0.18, segs=14, displace_amp=r * 0.05)

    # Hanging yellow-green spore-tendrils and glowing pustules beneath the main canopy.
    for k in range(6):
        a = k * math.pi / 3 + 0.25
        p0 = Vector((math.cos(a) * 2.5, math.sin(a) * 2.3, 6.7))
        ln = rng.uniform(1.8, 3.2)
        p1 = p0 + Vector((math.cos(a) * 0.3, math.sin(a) * 0.3, -ln))
        tube(glow, [p0, p1], [0.11, 0.07], 4, cap=False)
        uvsphere(bulb, 0.28, M(p1), u=7, v=5)


@template("RotMyceliumWeb", GLOW=1000, BULB=500, CAP=600, STEM=500, MOSS=400)
def rot_mycelium_web(t):
    """A creeping web of yellow-green glowing mycelium veins, chartreuse bulbs and violet shelf-caps (~14 wide, 6 tall)."""
    rng = t.rng
    glow, bulb, stem, moss = t.bm("GLOW"), t.bm("BULB"), t.bm("STEM"), t.bm("MOSS")
    rock_clean(moss, (13.6, 11.4, 1.1), M((0, 0, -0.3)), 367, roughness=0.35, subdiv=2)

    # Central bruised-moss mound & arching yellow-green mycelium tendrils radiating across it.
    rock_clean(stem, (5.2, 4.6, 2.8), M((0, 0.2, 0.6)), 373, roughness=0.32, subdiv=2)
    for k in range(8):
        a = k * math.pi / 4 + rng.uniform(-0.15, 0.15)
        d = Vector((math.cos(a), math.sin(a), 0))
        pts = [
            Vector((0, 0, 2.2)) + d * 0.6,
            d * 2.6 + Vector((0, 0, 2.5 + rng.uniform(-0.3, 0.4))),
            d * 4.8 + Vector((0, 0, 1.1 + rng.uniform(-0.2, 0.3))),
            d * 6.4 + Vector((0, 0, 0.2)),
        ]
        tube(glow, pts, [0.24, 0.19, 0.14, 0.08], 5, cap=False)
        uvsphere(bulb, rng.uniform(0.32, 0.48), M(pts[1] + Vector((0, 0, 0.2))), u=7, v=5)
        uvsphere(bulb, rng.uniform(0.24, 0.38), M(pts[2] + Vector((0, 0, 0.15))), u=7, v=5)

    for (cx, cy, cz, r, h, s) in (
        (-1.6, -1.8, 3.8, 2.0, 1.0, 379),
        (2.1, -1.0, 3.3, 1.65, 0.85, 383),
        (0.2, 2.1, 3.5, 1.8, 0.9, 389),
    ):
        _cap(t, Vector((cx, cy, cz)), r, h, s, gill_role="GLOW", spot_role="BULB", spots=4, lip=r * 0.16, segs=12, displace_amp=r * 0.04)


def build_f9():
    reset_scene()
    kit = bpy.data.collections.new("FungalF9Kit")
    bpy.context.scene.collection.children.link(kit)
    manifest = {}
    for name, (fn, budget) in F9_TEMPLATES.items():
        coll = bpy.data.collections.new(name)
        kit.children.link(coll)
        t = Template(name)
        t.rng = random.Random(sum(map(ord, name)))
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


def export_f9(kit, manifest):
    os.makedirs(OUT_DIR, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    objs = [o for o in kit.all_objects if o.type == "MESH"]
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.fbx(
        filepath=os.path.join(OUT_DIR, "FungalF9Kit.fbx"),
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
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT_DIR, "FungalF9Kit.blend"))


if __name__ == "__main__" or globals().get("RUN_F9", False):
    kit, manifest = build_f9()
    export_f9(kit, manifest)
    if globals().get("PREVIEWS", True):
        render_previews(kit, os.path.join(OUT_DIR, "previews"), list(F9_TEMPLATES.keys()), tile=520, cols=4)
    result = {"templates": len(manifest), "manifest": manifest}
    print(json.dumps(manifest, indent=2))
