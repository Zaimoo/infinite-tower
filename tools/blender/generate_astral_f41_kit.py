"""
Astral Archives Floor 41 (Starlit Vestibule) sculpted assets, generated in headless Blender.

Inspired by the Starlit Vestibule reference art (reference/Astral Archives 41.jpg) and the Halcyr
star-archivist ecosystem (docs/prompts/astral-archives-floor-layouts-prompt.md):
the readers' entrance floating over the Nebula Floor. The brass-and-lapis Index Gate ring over the
arrival stair; the soaring Lectern of First Light spire on the Nib Star with an open glowing tome
and orbiting floating tomes; faceted slate-and-starglass floating isle undersides in three sizes;
star-glass bridge bays inlaid with gold constellation lines; the Halcyr star-quill Index Lamps and
Lamplighters' Isle lamp racks; Catalogue Isle's multi-drawer ebony card-catalogue cabinets with the
framed Nereth slate tide-chart ("received wet"); The Inkwell's swirling star-well basin and copyists'
desks; The Blotter's cracked vellum slab hung from four towering brass chains with an indigo ink blot;
curved ebony bookcases and star-moss planters for the Three Barbs' reading gardens; the Calamus
central armillary pedestal; the Vane Root Runeguard turnstile and glaive rack; and slender floating
Far Archive Towers for the Starfield skyline.

1 Blender unit = 1 stud, standing on z = 0, front facing -Y in Blender / +Z in Roblox, one mesh object
per colour role named "<Template>__<ROLE>". Every piece stands on its origin.

Roles (AstralFloor41 passes the Halcyr override; no new colour roles):
    STONE    pale vellum-white stone         ALT      deep lapis-indigo marble / dark slate
    TRIM     worn gold leaf & inlay          METAL    warm aged brass
    WOOD     ebony shelving & cabinets       SILK     vellum pages & index cards
    GLOW     pale starlight gold             CRYSTAL  star-glass (deck, crystal tips, wells)
    MOSS     star-moss in reading planters

Outputs (assets-source/tower/astral_f41_kit/):
    AstralF41Kit.blend, AstralF41Kit.fbx, manifest.json, previews/kit_sheet_1.png, previews/tiles/*.png.

Run:
    blender.exe --background --factory-startup --python tools/blender/generate_astral_f41_kit.py
"""
import bpy, bmesh, math, os, json, runpy, random
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT_DIR = os.path.join(ROOT, "assets-source", "tower", "astral_f41_kit")

# Shared primitives and kit pipeline from Floor 21 & Floor 26 generators.
f21 = runpy.run_path(os.path.join(HERE, "generate_infernal_f21_kit.py"))
f26 = runpy.run_path(os.path.join(HERE, "generate_thunder_f26_kit.py"))

kit_mod = f21["kit_mod"]
box = f21["box"]
cone = f21["cone"]
uvsphere = f21["uvsphere"]
tube = f21["tube"]
ring_mesh = f21["ring_mesh"]
lathe = kit_mod["lathe"]
cyl_x, cyl_y, cyl_z, strut = f21["cyl_x"], f21["cyl_y"], f21["cyl_z"], f21["strut"]
ground_rock, centred_rock, slab_stone = f26["ground_rock"], f26["centred_rock"], f26["slab_stone"]
build_kit, export_kit, render_previews = f21["build_kit"], f21["export_kit"], f21["render_previews"]

T = Matrix.Translation
R = Matrix.Rotation

DEFAULT_BUDGET = 3500
F41_TEMPLATES = {}

# Halcyr Workbench preview colours (Studio strips materials and tints per role via TowerKitProps).
HALCYR_PREVIEW_COLORS = {
    "STONE": (0.88, 0.85, 0.78, 1.0),    # pale vellum-white stone
    "ALT": (0.16, 0.21, 0.42, 1.0),      # lapis-indigo marble / slate
    "TRIM": (0.86, 0.72, 0.36, 1.0),     # worn gold leaf
    "METAL": (0.64, 0.50, 0.26, 1.0),    # warm aged brass
    "WOOD": (0.20, 0.14, 0.12, 1.0),     # dark ebony shelving
    "SILK": (0.95, 0.91, 0.80, 1.0),     # vellum pages
    "GLOW": (1.00, 0.92, 0.66, 1.0),     # pale starlight gold
    "CRYSTAL": (0.45, 0.76, 0.96, 1.0),  # star-glass
    "MOSS": (0.36, 0.58, 0.48, 1.0),     # star-moss
}


def template(name, **budget):
    def deco(fn):
        F41_TEMPLATES[name] = (fn, budget)
        return fn
    return deco


# -----------------------------------------------------------------------------------------------------------
# Shared Halcyr motifs: star-quill sigil, linked brass chains, open tomes, index lantern heads, crystal tips
# -----------------------------------------------------------------------------------------------------------
def star_quill_sigil(trim, metal, silk, mat, scale=1.0):
    """The Halcyr sigil: a four-pointed star pierced diagonally by a quill inside a brass ring (in local XZ)."""
    s = scale
    ring_mesh(metal, 1.8 * s, 0.16 * s, 20, mat @ R(math.pi / 2, 4, "X"), tube_segs=6)
    # Four-pointed star (vertical & horizontal slender bicones + centre boss).
    for ang, length in ((0.0, 2.0), (math.pi, 2.0), (math.pi / 2, 1.55), (-math.pi / 2, 1.55)):
        cone(trim, 0.34 * s, 0.03 * s, length * s, 4, mat @ R(ang, 4, "Y"))
    uvsphere(trim, 0.38 * s, mat, 8, 6)
    # Piercing quill angled at 40 degrees.
    q = mat @ R(math.radians(-40), 4, "Y")
    strut(metal, q @ Vector((0, 0, -2.3 * s)), q @ Vector((0, 0, 2.1 * s)), 0.14 * s)
    # Quill vane (two stepped feather blades on the upper shaft).
    box(silk, (0.65 * s, 0.12 * s, 1.65 * s), q @ T((0.28 * s, 0, 1.15 * s)) @ R(0.12, 4, "Y"))
    box(silk, (0.42 * s, 0.10 * s, 1.25 * s), q @ T((-0.18 * s, 0, 1.25 * s)) @ R(-0.1, 4, "Y"))
    cone(trim, 0.14 * s, 0.02 * s, 0.65 * s, 4, q @ T((0, 0, -2.3 * s)) @ R(math.pi, 4, "X"))


def chain_run(metal, trim, p0, p1, link_h=1.5, link_w=0.95, thick=0.18):
    """Alternating 90-degree oval brass chain links from p0 to p1."""
    a, b = Vector(p0), Vector(p1)
    d = b - a
    length = d.length
    if length < 0.2:
        return
    q = d.normalized().to_track_quat("Z", "Y").to_matrix().to_4x4()
    step = link_h * 0.72
    n = max(1, int(length / step))
    for k in range(n):
        t = (k + 0.5) / n
        c = a.lerp(b, t)
        rot_z = (math.pi / 2) if (k % 2 == 1) else 0.0
        m = T(c) @ q @ R(rot_z, 4, "Z") @ R(math.pi / 2, 4, "X") @ Matrix.Diagonal((link_w * 0.5, link_h * 0.5, 1.0, 1.0))
        ring_mesh(metal if k % 3 else trim, 1.0, thick, 10, m, tube_segs=4)


def open_tome(cover_bm, silk, trim, mat, w=3.2, d=2.2, page_h=0.55, spread=0.32):
    """An open tome centred on mat, spine along local Y, pages curving up to either side."""
    hw = w * 0.5
    # Spine bar.
    box(trim, (0.35, d + 0.14, 0.22), mat @ T((0, 0, 0.08)))
    for sx in (-1, 1):
        tilt = R(-sx * spread, 4, "Y")
        # Outer hard cover.
        box(cover_bm, (hw, d + 0.16, 0.14), mat @ T((sx * hw * 0.52, 0, 0.12)) @ tilt)
        # Gold corner trim strips.
        box(trim, (hw * 0.94, 0.14, 0.18), mat @ T((sx * hw * 0.52, d * 0.52, 0.14)) @ tilt)
        box(trim, (hw * 0.94, 0.14, 0.18), mat @ T((sx * hw * 0.52, -d * 0.52, 0.14)) @ tilt)
        # Arched vellum page block (two angled slabs forming a gentle page bow).
        box(silk, (hw * 0.52, d * 0.92, page_h), mat @ T((sx * hw * 0.28, 0, 0.22 + page_h * 0.42)) @ R(-sx * (spread + 0.16), 4, "Y"))
        box(silk, (hw * 0.48, d * 0.90, page_h * 0.85), mat @ T((sx * hw * 0.72, 0, 0.26 + page_h * 0.58)) @ R(-sx * (spread - 0.10), 4, "Y"))


def index_lantern_head(metal, trim, crystal, glow, mat, scale=1.0):
    """The hanging Halcyr Index Lamp head: circular brass ring, star-quill finial on top, glowing hexagonal lantern inside."""
    s = scale
    # Outer circular brass ring in local XZ plane.
    ring_mesh(metal, 1.35 * s, 0.12 * s, 18, mat @ R(math.pi / 2, 4, "X"), tube_segs=5)
    # Four-pointed star crown on top of ring.
    cone(trim, 0.22 * s, 0.02 * s, 0.95 * s, 4, mat @ T((0, 0, 1.35 * s)))
    cone(trim, 0.18 * s, 0.02 * s, 0.55 * s, 4, mat @ T((0, 0, 1.35 * s)) @ R(math.pi / 2, 4, "Y"))
    cone(trim, 0.18 * s, 0.02 * s, 0.55 * s, 4, mat @ T((0, 0, 1.35 * s)) @ R(-math.pi / 2, 4, "Y"))
    # Lantern cap, base cup, hexagonal star-glass cage and pale-gold core.
    cone(trim, 0.72 * s, 0.16 * s, 0.58 * s, 6, mat @ T((0, 0, 0.52 * s)))
    cone(metal, 0.16 * s, 0.65 * s, 0.48 * s, 6, mat @ T((0, 0, -1.02 * s)))
    cone(crystal, 0.58 * s, 0.66 * s, 1.06 * s, 6, mat @ T((0, 0, -0.54 * s)))
    cone(glow, 0.40 * s, 0.46 * s, 0.88 * s, 6, mat @ T((0, 0, -0.45 * s)))
    for k in range(6):
        a = 2 * math.pi * k / 6
        strut(trim, mat @ Vector((math.cos(a) * 0.64 * s, math.sin(a) * 0.64 * s, -0.54 * s)),
              mat @ Vector((math.cos(a) * 0.70 * s, math.sin(a) * 0.70 * s, 0.54 * s)), 0.08 * s)


def crystal_spike_cluster(crystal, glow, base_z, spread_r, height, count, seed, pointing_down=True):
    """Cluster of sharp, slender faceted hexagonal star-glass crystal shards with inner glowing cores."""
    rng = random.Random(seed)
    sign = -1.0 if pointing_down else 1.0
    for k in range(count):
        if k == 0:
            r_off, ang = 0.0, 0.0
            h = height
            rad = spread_r * 0.24
            tilt_x, tilt_y = 0.0, 0.0
        else:
            ang = 2 * math.pi * (k - 1) / max(1, count - 1) + rng.uniform(-0.22, 0.22)
            r_off = spread_r * rng.uniform(0.26, 0.78)
            h = height * rng.uniform(0.52, 0.86)
            rad = spread_r * rng.uniform(0.11, 0.19)
            tilt_x = math.sin(ang) * rng.uniform(0.08, 0.26) * (-sign)
            tilt_y = -math.cos(ang) * rng.uniform(0.08, 0.26) * (-sign)
        cx, cy = math.cos(ang) * r_off, math.sin(ang) * r_off
        flip = R(math.pi, 4, "X") if pointing_down else Matrix.Identity(4)
        m = T((cx, cy, base_z)) @ R(tilt_x, 4, "X") @ R(tilt_y, 4, "Y") @ R(ang, 4, "Z") @ flip
        # Slender faceted shard tapering sharply to a crystalline icicle point.
        cone(crystal, rad * 0.95, rad * 0.82, h * 0.36, 6, m)
        cone(crystal, rad * 0.82, 0.03, h * 0.64, 6, m @ T((0, 0, h * 0.36)))
        # Inner glow spire.
        cone(glow, rad * 0.40, 0.02, h * 0.82, 5, m @ T((0, 0, h * 0.06)))


def armillary_sphere(metal, trim, crystal, glow, centre, radius, segs=28):
    """Nested brass armillary rings tilted around a glowing star-core."""
    c = Vector(centre)
    ring_specs = (
        (radius, 0.22, (0.0, 0.0, 0.0), metal),
        (radius * 0.98, 0.18, (math.pi / 2, 0.0, 0.0), metal),
        (radius * 0.98, 0.18, (math.pi / 2, 0.0, math.pi / 2), trim),
        (radius * 0.84, 0.16, (math.radians(23.5), math.radians(18), 0.4), trim),
        (radius * 0.66, 0.14, (math.radians(-32), math.radians(48), 1.1), metal),
    )
    for r, th, rot, bm in ring_specs:
        m = T(c) @ R(rot[2], 4, "Z") @ R(rot[1], 4, "Y") @ R(rot[0], 4, "X")
        ring_mesh(bm, r, th, segs, m, tube_segs=6)
    # Polar axis rod with star pointers.
    axis_m = T(c) @ R(math.radians(23.5), 4, "X")
    strut(trim, axis_m @ Vector((0, 0, -radius * 1.18)), axis_m @ Vector((0, 0, radius * 1.18)), 0.18)
    cone(trim, 0.42, 0.03, 1.4, 4, axis_m @ T((0, 0, radius * 1.18)))
    # Central glowing star orb.
    uvsphere(glow, radius * 0.24, T(c), 12, 8)
    uvsphere(crystal, radius * 0.32, T(c), 12, 8)


def balustrade_post(stone, trim, x, y, z, h=3.2):
    """Classical Halcyr turned stone baluster post with gold cap."""
    box(stone, (0.95, 0.95, 0.45), T((x, y, z + 0.225)))
    lathe(stone, [(0.36, 0.45), (0.24, 0.85), (0.38, 1.55), (0.24, 2.35), (0.36, h - 0.35)], 8, T((x, y, z)))
    box(trim, (1.0, 1.0, 0.35), T((x, y, z + h - 0.175)))


# -----------------------------------------------------------------------------------------------------------
# 1. IndexGateRing — The arrival ring-gate over the Sanctuary stair (guide image foreground landmark)
# -----------------------------------------------------------------------------------------------------------
@template("IndexGateRing", STONE=3600, ALT=3200, TRIM=3600, METAL=3200, SILK=600, CRYSTAL=900, GLOW=900)
def index_gate_ring(t):
    """The Halcyr Index Gate: a grand 38-stud-wide circular brass-and-lapis ring-gate standing over the
    Sanctuary arrival stair. Wide clear central passage (28 studs wide, 26 studs tall) framed by stepped
    vellum-stone pedestals topped with celestial globes, lapis-indigo arch ring inlaid with 12 gold star-glyphs,
    nested inner brass armillary rims, and the Halcyr Star-Quill sigil crowning the apex. About 42 studs tall."""
    stone, alt, trim, metal, silk, crystal, glow = (t.bm(r) for r in ("STONE", "ALT", "TRIM", "METAL", "SILK", "CRYSTAL", "GLOW"))

    # Flanking stepped vellum-stone & lapis pedestals (clear opening between X = -14.5 and +14.5).
    for sx in (-1, 1):
        px = sx * 17.6
        box(stone, (7.6, 8.6, 2.2), T((px, 0, 1.1)), bevel=0.18)
        box(stone, (6.4, 7.2, 7.4), T((px, 0, 5.9)), bevel=0.14)
        box(alt, (4.4, 7.5, 4.8), T((px, 0, 5.8)))
        box(trim, (6.8, 7.6, 0.65), T((px, 0, 9.7)))
        box(stone, (6.8, 7.6, 0.9), T((px, 0, 10.4)))
        # Flanking celestial globe on outer pedestal shoulder.
        gx = sx * 19.6
        lathe(metal, [(1.1, 0), (0.45, 0.6), (0.32, 1.8), (0.75, 2.5)], 10, T((gx, -1.6, 10.85)))
        uvsphere(crystal, 1.35, T((gx, -1.6, 14.3)), 12, 8)
        uvsphere(glow, 0.72, T((gx, -1.6, 14.3)), 8, 6)
        ring_mesh(trim, 1.65, 0.12, 18, T((gx, -1.6, 14.3)) @ R(0.45, 4, "X"), tube_segs=4)
        ring_mesh(metal, 1.65, 0.12, 18, T((gx, -1.6, 14.3)) @ R(math.pi / 2, 4, "Y"), tube_segs=4)

    # Grand circular ring arch (centre at Z = 17.5, radius 16.2; bottom chords seat cleanly into pedestals).
    cz, R_main = 17.5, 16.2
    segs = 36
    # Lapis-indigo arch body with crisp inner & outer gold-leaf rims so the deep lapis face & star-glyphs pop!
    for k in range(segs):
        a = -math.radians(32) + (math.radians(244)) * (k + 0.5) / segs
        x = math.cos(a) * R_main
        z = cz + math.sin(a) * R_main
        if z < 3.0:
            continue
        seg_len = (2 * math.pi * R_main * 244 / 360) / segs + 0.35
        m = T((x, 0, z)) @ R(-a, 4, "Y")
        # Bold lapis-indigo arch face (exposed clearly on front & back).
        box(alt, (2.8, 3.4, seg_len), m)
        # Slim gold-leaf outer & inner bevel moulding rails (leaving the middle 2.1 studs of lapis visible!).
        for sr in (-1, 1):
            box(trim, (0.48, 3.72, seg_len * 0.99), m @ T((sr * 1.48, 0, 0)))
        # Every 3rd voussoir carries a crisp raised gold/glow star-glyph inlaid on the lapis face.
        if k % 3 == 1:
            for sy in (-1, 1):
                box(glow, (0.34, 0.24, 1.35), m @ T((0, sy * 1.75, 0)))
                box(trim, (1.25, 0.24, 0.34), m @ T((0, sy * 1.74, 0)))
                box(glow, (0.75, 0.22, 0.75), m @ T((0, sy * 1.73, 0)) @ R(math.pi / 4, 4, "Y"))

    # Continuous outer and inner brass structural rings hugging the arch.
    for r_ring, th, bm in ((R_main + 1.85, 0.36, metal), (R_main - 1.80, 0.32, trim)):
        pts = []
        for k in range(33):
            a = -math.radians(28) + math.radians(236) * k / 32
            pts.append((math.cos(a) * r_ring, 0.0, cz + math.sin(a) * r_ring))
        tube(bm, pts, [th] * len(pts), 6, cap=True)

    # Nested tilted inner brass armillary ribs framing the upper archway (keeps lower passage wide open!).
    for tilt_y, tilt_x, r_in in ((0.22, 0.16, 13.8), (-0.22, -0.14, 13.0)):
        pts = []
        for k in range(25):
            a = math.radians(15) + math.radians(150) * k / 24
            p = R(tilt_y, 4, "Y") @ R(tilt_x, 4, "X") @ Vector((math.cos(a) * r_in, 0.0, math.sin(a) * r_in))
            pts.append((p.x, p.y, cz + p.z))
        tube(metal, pts, [0.26] * len(pts), 6, cap=True)

    # Radiant zenith star-orb hung under the crown at Z = 29.8 (well above 18-stud clearance).
    strut(trim, (0, 0, cz + R_main - 1.4), (0, 0, 29.8), 0.24)
    ring_mesh(metal, 2.3, 0.15, 20, T((0, 0, 29.8)) @ R(math.pi / 2, 4, "X"), tube_segs=5)
    ring_mesh(trim, 1.8, 0.13, 18, T((0, 0, 29.8)) @ R(0.6, 4, "X") @ R(0.4, 4, "Y"), tube_segs=4)
    uvsphere(glow, 0.9, T((0, 0, 29.8)), 10, 8)
    uvsphere(crystal, 1.2, T((0, 0, 29.8)), 10, 8)

    # Crown keystone medallion with lapis inlay & the Halcyr Star-Quill sigil atop the gate (Z = 34..42).
    box(stone, (5.2, 4.0, 4.4), T((0, 0, cz + R_main + 1.0)), bevel=0.25)
    box(alt, (3.8, 4.25, 3.0), T((0, 0, cz + R_main + 1.0)))
    box(trim, (4.2, 4.18, 3.4), T((0, 0, cz + R_main + 1.0)))
    star_quill_sigil(trim, metal, silk, T((0, 0, cz + R_main + 4.8)), scale=1.65)


# -----------------------------------------------------------------------------------------------------------
# 2. LecternSpire — The Lectern of First Light (Floor 41's 130+ stud Apex centrepiece landmark)
# -----------------------------------------------------------------------------------------------------------
@template("LecternSpire", STONE=5600, ALT=2400, TRIM=4200, METAL=2400, SILK=1600, GLOW=1400, MOSS=1000)
def lectern_spire(t):
    """The Lectern of First Light: a soaring 132-stud vellum-stone spire with a compact 20x20 octagonal base
    so it clears the Nib Star Apex arena. Stepped lapis-inlaid plinth with star-moss around its foot, four-sided
    lancet-arch shaft rising 96 studs, flared Gothic gold-leaf filigree crown, ornate brass lectern cradle, and
    a colossal glowing open golden book held aloft in starlight."""
    stone, alt, trim, metal, silk, glow, moss = (t.bm(r) for r in ("STONE", "ALT", "TRIM", "METAL", "SILK", "GLOW", "MOSS"))

    # Stepped octagonal vellum-stone plinth & lapis accent ring (footprint ~24x24).
    cone(stone, 12.0, 11.2, 2.2, 8, T((0, 0, 0)) @ R(math.pi / 8, 4, "Z"))
    cone(alt, 10.6, 10.1, 1.8, 8, T((0, 0, 2.2)) @ R(math.pi / 8, 4, "Z"))
    cone(stone, 9.6, 8.8, 3.2, 8, T((0, 0, 4.0)) @ R(math.pi / 8, 4, "Z"))
    ring_mesh(trim, 9.4, 0.34, 16, T((0, 0, 7.2)), tube_segs=5)

    # Natural star-moss cushions tucked around the base steps (like the guide image).
    for k in range(8):
        a = 2 * math.pi * k / 8 + 0.2
        r = 10.2 if k % 2 == 0 else 10.9
        ground_rock(moss, (3.8, 2.9, 1.7), (math.cos(a) * r, math.sin(a) * r, 0.0), seed=4101 + k, roughness=0.30, subdiv=1)

    # Lower shrine base (Z = 7.2..32) with recessed arched doorway, flying buttress fins & tall lancets.
    cone(stone, 8.0, 6.8, 25.0, 8, T((0, 0, 7.2)) @ R(math.pi / 8, 4, "Z"))
    for k in range(4):
        a = k * math.pi / 2
        m = R(a, 4, "Z") @ T((0, -7.2, 7.2))
        box(alt, (4.2, 1.1, 17.5), m @ T((0, 0.3, 8.8)))
        # Pointed Gothic lancet trim framing each cardinal bay.
        strut(trim, m @ Vector((-2.3, -0.35, 0)), m @ Vector((-2.3, -0.35, 14.5)), 0.5)
        strut(trim, m @ Vector((2.3, -0.35, 0)), m @ Vector((2.3, -0.35, 14.5)), 0.5)
        strut(trim, m @ Vector((-2.3, -0.35, 14.5)), m @ Vector((0, -0.35, 19.2)), 0.52)
        strut(trim, m @ Vector((2.3, -0.35, 14.5)), m @ Vector((0, -0.35, 19.2)), 0.52)
        if k == 0:
            box(glow, (0.75, 0.35, 13.5), m @ T((0, -0.25, 8.5)))
        # Diagonal corner buttress fins sweeping from the plinth up into the shaft.
        ba = a + math.pi / 4
        strut(stone, (math.cos(ba) * 10.2, math.sin(ba) * 10.2, 7.2), (math.cos(ba) * 6.5, math.sin(ba) * 6.5, 36.0), 1.4)
        strut(trim, (math.cos(ba) * 10.6, math.sin(ba) * 10.6, 7.6), (math.cos(ba) * 6.9, math.sin(ba) * 6.9, 36.4), 0.35)

    # Mid slender fluted spire shaft (Z = 32..88), tapering gracefully with recessed lapis panels & 3 gold collars.
    cone(stone, 6.6, 4.8, 56.0, 8, T((0, 0, 32.0)) @ R(math.pi / 8, 4, "Z"))
    for z_band, r_band in ((32.0, 7.2), (52.0, 6.3), (70.0, 5.7), (88.0, 5.2)):
        cone(stone, r_band + 0.65, r_band + 0.25, 2.2, 8, T((0, 0, z_band - 0.6)) @ R(math.pi / 8, 4, "Z"))
        ring_mesh(trim, r_band + 0.7, 0.38, 16, T((0, 0, z_band + 0.5)), tube_segs=5)
    # 8 corner stone buttress ribs & glowing star-glyph channels up the shaft.
    for k in range(8):
        a = 2 * math.pi * k / 8
        p0 = (math.cos(a) * 6.8, math.sin(a) * 6.8, 32.0)
        p1 = (math.cos(a) * 5.0, math.sin(a) * 5.0, 88.0)
        strut(stone if k % 2 == 0 else trim, p0, p1, 0.85 if k % 2 == 0 else 0.42)
        if k % 2 == 1:
            g0 = (math.cos(a) * 6.3, math.sin(a) * 6.3, 36.0)
            g1 = (math.cos(a) * 4.85, math.sin(a) * 4.85, 84.0)
            strut(glow, g0, g1, 0.30)

    # Grand flared astral capital & soaring gold-leaf Gothic filigree crown (Z = 88..134).
    lathe(stone, [(5.0, 0.0), (6.0, 3.5), (8.4, 9.5), (10.2, 14.5), (9.8, 16.5)], 8, T((0, 0, 88.0)) @ R(math.pi / 8, 4, "Z"))
    ring_mesh(trim, 10.2, 0.55, 16, T((0, 0, 103.5)), tube_segs=6)
    # 8 soaring crown pinnacles & cathedral-arch gables framing the colossal book (matching the guide image's golden crown!).
    for k in range(8):
        a = 2 * math.pi * k / 8
        bx, by = math.cos(a) * 9.8, math.sin(a) * 9.8
        if k == 2:  # Back (+Y) cathedral spire peak rising behind the book to Z = 134!
            pin_h = 28.0
        elif k in (1, 3):
            pin_h = 20.0
        elif k in (0, 4):
            pin_h = 15.0
        else:
            pin_h = 10.5
        cone(trim, 0.95, 0.08, pin_h, 4, T((bx, by, 104.0)) @ R(a, 4, "Z"))
        a2 = 2 * math.pi * (k + 1) / 8
        nx, ny = math.cos(a2) * 9.8, math.sin(a2) * 9.8
        mx, my = (bx + nx) * 0.5, (by + ny) * 0.5
        strut(trim, (bx, by, 108.5), (mx, my, 114.0), 0.48)
        strut(trim, (nx, ny, 108.5), (mx, my, 114.0), 0.48)
    # Grand Gothic pointed arch halo directly behind the open book (+Y side).
    strut(trim, (-7.0, 6.8, 106.0), (0.0, 7.6, 131.5), 0.65)
    strut(trim, (7.0, 6.8, 106.0), (0.0, 7.6, 131.5), 0.65)
    cone(glow, 0.72, 0.05, 5.2, 4, T((0, 7.6, 130.0)))

    # Ornate brass lectern pedestal & the Colossal Open Book of First Light (bold, readable from arrival!).
    lathe(metal, [(4.4, 0), (2.2, 2.8), (1.9, 7.5), (5.2, 11.0)], 12, T((0, -0.8, 104.5)))
    book_m = T((0, -1.6, 117.5)) @ R(math.radians(-26), 4, "X")
    open_tome(alt, silk, trim, book_m, w=18.5, d=12.6, page_h=2.8, spread=0.28)
    # Radiant starlight aura halo & rays hovering softly over the open pages.
    ring_mesh(glow, 7.0, 0.32, 24, book_m @ T((0, 0, 3.4)), tube_segs=5)
    uvsphere(glow, 2.1, book_m @ T((0, 0, 2.8)), 10, 8)


# -----------------------------------------------------------------------------------------------------------
# 3, 4, 5. StarIsleUndersideS / M / L — Three sizes of floating slate-and-crystal isle undersides
# -----------------------------------------------------------------------------------------------------------
def _build_isle_underside(t, top_r, height, seed, lamp_count, crystal_count):
    """Tapering faceted slate rock cone topped by a vellum/brass rim collar and hanging Index Lamps,
    with glowing star-glass crystal spikes jutting from the bottom apex (standing cleanly on z = 0)."""
    alt, stone, metal, trim, crystal, glow = (t.bm(r) for r in ("ALT", "STONE", "METAL", "TRIM", "CRYSTAL", "GLOW"))
    rng = random.Random(seed)
    crys_h = height * 0.36
    rock_z0 = crys_h * 0.62
    rock_h = height - rock_z0 - 1.6

    # Central tapering faceted crag cone (dark indigo-slate ALT).
    cone(alt, top_r * 0.16, top_r * 0.94, rock_h, 12, T((0, 0, rock_z0)))
    # Ring of staggered angular rock ribs wrapping the cone so it reads as sculpted floating stone, not a smooth funnel.
    ribs = max(8, int(top_r * 0.45))
    for k in range(ribs):
        a = 2 * math.pi * k / ribs + rng.uniform(-0.08, 0.08)
        sub_h = rock_h * rng.uniform(0.58, 0.96)
        z_bot = rock_z0 + rock_h - sub_h
        r_mid = top_r * rng.uniform(0.52, 0.84)
        rad = top_r * rng.uniform(0.16, 0.26)
        cone(alt, rad * 0.22, rad, sub_h, 5, T((math.cos(a) * r_mid * 0.72, math.sin(a) * r_mid * 0.72, z_bot)) @ R(a, 4, "Z"))

    # Upper vellum-stone & brass rim collar crowning the underside.
    collar_z = height - 1.8
    cone(stone, top_r * 0.94, top_r, 1.8, 24, T((0, 0, collar_z)))
    ring_mesh(metal, top_r * 0.99, 0.42, 28, T((0, 0, collar_z + 0.9)), tube_segs=6)
    ring_mesh(trim, top_r * 0.96, 0.22, 28, T((0, 0, collar_z + 1.65)), tube_segs=4)

    # Downward-pointing star-glass crystal cluster reaching precisely to z = 0.
    crystal_spike_cluster(crystal, glow, base_z=crys_h, spread_r=top_r * 0.46, height=crys_h, count=crystal_count, seed=seed + 77, pointing_down=True)

    # Hanging brass chains with small Index Lanterns dangling beneath the rim (just like the guide image).
    for k in range(lamp_count):
        a = 2 * math.pi * k / lamp_count + 0.25
        rx, ry = math.cos(a) * top_r * 0.92, math.sin(a) * top_r * 0.92
        drop = rng.uniform(height * 0.26, height * 0.42)
        lz = max(3.0, collar_z - drop)
        # Ornate brass rim bracket.
        strut(metal, (rx * 0.86, ry * 0.86, collar_z - 1.4), (rx, ry, collar_z + 0.5), 0.35)
        chain_run(metal, trim, (rx, ry, collar_z), (rx, ry, lz + 1.2), link_h=1.2, link_w=0.65, thick=0.12)
        index_lantern_head(metal, trim, crystal, glow, T((rx, ry, lz)) @ R(a, 4, "Z"), scale=0.82)


@template("StarIsleUndersideS", ALT=2600, STONE=900, METAL=1400, TRIM=900, CRYSTAL=1400, GLOW=700)
def star_isle_underside_s(t):
    """Small floating star-isle underside (32 diameter, 28 tall) for Barbs, Lamplighters' Isle and Nib Landing."""
    _build_isle_underside(t, top_r=16.0, height=28.0, seed=4111, lamp_count=4, crystal_count=6)


@template("StarIsleUndersideM", ALT=3400, STONE=1100, METAL=1800, TRIM=1100, CRYSTAL=1800, GLOW=900)
def star_isle_underside_m(t):
    """Medium floating star-isle underside (48 diameter, 34 tall) for Vane Root, The Inkwell and The Calamus."""
    _build_isle_underside(t, top_r=24.0, height=34.0, seed=4121, lamp_count=6, crystal_count=8)


@template("StarIsleUndersideL", ALT=4200, STONE=1400, METAL=2200, TRIM=1400, CRYSTAL=2200, GLOW=1100)
def star_isle_underside_l(t):
    """Large floating star-isle underside (68 diameter, 42 tall) for The Nib Star Apex."""
    _build_isle_underside(t, top_r=34.0, height=42.0, seed=4131, lamp_count=8, crystal_count=11)


# -----------------------------------------------------------------------------------------------------------
# 6. StarglassBridgeSpan — Translucent star-glass bridge bay with gold constellation inlay & brass ribs
# -----------------------------------------------------------------------------------------------------------
@template("StarglassBridgeSpan", CRYSTAL=1200, METAL=2400, TRIM=2200, STONE=1600, GLOW=900)
def starglass_bridge_span(t):
    """A 24-stud-long, 14-stud-wide star-glass bridge bay: translucent Glacier-like star-glass deck over
    arched brass underside trusses, gold constellation lines & star-nodes inlaid along the glass, and low
    vellum-and-gold curb balustrades with corner newel lanterns outside the 11-stud clear lane."""
    crystal, metal, trim, stone, glow = (t.bm(r) for r in ("CRYSTAL", "METAL", "TRIM", "STONE", "GLOW"))
    L, W, deck_z = 24.0, 14.0, 2.2

    # Arched brass underside keel & transverse ribs (rising from z = 0 at ends to deck_z).
    for sx in (-1, 1):
        arch_pts = []
        for k in range(9):
            f = k / 8.0 - 0.5
            y = f * L
            z = 0.25 + (1.0 - (2 * f) ** 2) * (deck_z - 0.55)
            arch_pts.append((sx * (W * 0.44), y, z))
        tube(metal, arch_pts, [0.34] * len(arch_pts), 6, cap=True)
        # Top longitudinal edge girder.
        box(metal, (0.75, L, 0.55), T((sx * (W * 0.44), 0, deck_z - 0.22)))
    for y in (-11.2, -5.6, 0.0, 5.6, 11.2):
        box(metal, (W * 0.92, 0.55, 0.45), T((0, y, deck_z - 0.35)))

    # Translucent star-glass bridge deck slab.
    box(crystal, (W - 1.6, L, 0.36), T((0, 0, deck_z + 0.12)))

    # Inlaid glowing gold constellation lines & star-nodes zig-zagging down the centre of the glass.
    stars = [(0.0, -10.0), (-2.1, -5.0), (1.8, 0.0), (-1.6, 5.2), (0.0, 10.0)]
    for k, (sx, sy) in enumerate(stars):
        uvsphere(glow, 0.34, T((sx, sy, deck_z + 0.22)), 8, 6)
        ring_mesh(trim, 0.58, 0.07, 12, T((sx, sy, deck_z + 0.28)), tube_segs=4)
        if k < len(stars) - 1:
            nx, ny = stars[k + 1]
            strut(glow, (sx, sy, deck_z + 0.24), (nx, ny, deck_z + 0.24), 0.14)

    # Outer curb rails, vellum-stone balusters and gold-capped corner newels (outside clear walk width).
    for sx in (-1, 1):
        rx = sx * (W * 0.46)
        box(stone, (1.1, L, 0.65), T((rx, 0, deck_z + 0.42)))
        box(trim, (1.2, L, 0.18), T((rx, 0, deck_z + 0.78)))
        # Top handrail along both sides.
        box(trim, (0.42, L - 1.0, 0.26), T((rx, 0, deck_z + 3.45)))
        for y in (-8.0, -4.0, 0.0, 4.0, 8.0):
            balustrade_post(stone, trim, rx, y, deck_z + 0.75, h=2.6)
        # End newel piers topped with star-glow finials.
        for sy in (-1, 1):
            ny = sy * (L * 0.48)
            box(stone, (1.45, 1.45, 3.3), T((rx, ny, deck_z + 2.15)), bevel=0.1)
            box(trim, (1.65, 1.65, 0.32), T((rx, ny, deck_z + 3.92)))
            uvsphere(glow, 0.42, T((rx, ny, deck_z + 4.45)), 8, 6)


# -----------------------------------------------------------------------------------------------------------
# 7. IndexLamp — The Halcyr star-quill Index Lamp on a slender brass standard
# -----------------------------------------------------------------------------------------------------------
@template("IndexLamp", STONE=700, METAL=1400, TRIM=1200, CRYSTAL=500, GLOW=500)
def index_lamp(t):
    """The Halcyr Index Lamp: a stepped vellum-stone pedestal and slender fluted brass lamp-post with a
    scrolled top arm suspending a glowing star-quill lantern inside a circular brass ring. About 13 studs tall."""
    stone, metal, trim, crystal, glow = (t.bm(r) for r in ("STONE", "METAL", "TRIM", "CRYSTAL", "GLOW"))
    # Stepped octagonal vellum-stone base.
    cone(stone, 1.65, 1.45, 0.65, 8, T((0, 0, 0)) @ R(math.pi / 8, 4, "Z"))
    cone(stone, 1.25, 0.95, 1.15, 8, T((0, 0, 0.65)) @ R(math.pi / 8, 4, "Z"))
    ring_mesh(trim, 1.02, 0.14, 14, T((0, 0, 1.8)), tube_segs=5)
    # Slender turned brass standard.
    lathe(metal, [(0.55, 1.8), (0.32, 2.8), (0.26, 6.2), (0.42, 6.6), (0.24, 7.0), (0.20, 10.6)], 10, Matrix.Identity(4))
    # Graceful curved brass crook arm arcing forward (-Y).
    arm_pts = [
        (0.0, 0.0, 10.4),
        (0.0, -0.35, 11.6),
        (0.0, -1.25, 12.4),
        (0.0, -2.15, 12.1),
        (0.0, -2.35, 11.4),
    ]
    tube(metal, arm_pts, [0.18, 0.16, 0.15, 0.14, 0.12], 6, cap=True)
    # Small gold scroll under the arm.
    ring_mesh(trim, 0.45, 0.08, 12, T((0, -0.65, 10.8)) @ R(math.pi / 2, 4, "Y"), tube_segs=4)
    # Suspended Halcyr Index Lantern head (ring + star-quill finial + glowing core).
    index_lantern_head(metal, trim, crystal, glow, T((0, -2.35, 9.75)), scale=0.95)


# -----------------------------------------------------------------------------------------------------------
# 8. CatalogueCabinet — Ebony card-catalogue cabinet + framed Nereth slate tide-chart ("received wet")
# -----------------------------------------------------------------------------------------------------------
@template("CatalogueCabinet", WOOD=2800, TRIM=1800, METAL=1400, SILK=900, ALT=600, CRYSTAL=400, GLOW=400)
def catalogue_cabinet(t):
    """Catalogue Isle's double-sided ebony card-catalogue cabinet with rows of miniature drawers (several
    pulled half-open revealing neat ivory index cards), brass label-pulls, gold cornice moulding, and an
    attached brass frame holding the water-stained Nereth slate tide-chart ('received wet'). About 11 studs tall."""
    wood, trim, metal, silk, alt, crystal, glow = (t.bm(r) for r in ("WOOD", "TRIM", "METAL", "SILK", "ALT", "CRYSTAL", "GLOW"))
    # Main ebony cabinet carcass & stepped plinth + crown cornice.
    box(wood, (11.2, 4.6, 0.8), T((0, 0, 0.4)), bevel=0.08)
    box(wood, (10.4, 4.0, 8.8), T((0, 0, 5.2)), bevel=0.06)
    box(trim, (11.0, 4.5, 0.45), T((0, 0, 9.8)))
    box(wood, (11.4, 4.8, 0.65), T((0, 0, 10.3)), bevel=0.1)
    # Brass corner pilasters.
    for sx in (-1, 1):
        for sy in (-1, 1):
            box(metal, (0.38, 0.38, 9.2), T((sx * 5.25, sy * 2.05, 5.2)))

    # 6 columns x 5 rows of card-catalogue drawers on both front (-Y) and back (+Y), some pulled open!
    open_drawers = {(1, 3): 1.2, (4, 2): 1.5, (2, 1): 0.9, (5, 4): 1.1}
    for sy in (-1, 1):
        for col in range(6):
            cx = -4.0 + col * 1.6
            for row in range(5):
                cz = 1.75 + row * 1.65
                pull = open_drawers.get((col, row), 0.0) if sy == -1 else (0.9 if (col == 3 and row == 2) else 0.0)
                face_y = sy * (2.05 + pull)
                # Drawer front & brass pull handle.
                box(wood, (1.38, 0.24 + pull, 1.38), T((cx, sy * (2.0 + pull * 0.5), cz)))
                box(trim, (0.58, 0.14, 0.24), T((cx, face_y + sy * 0.16, cz)))
                # If pulled open, pack it with ivory vellum index cards!
                if pull > 0.2:
                    for c_i in range(4):
                        cy = sy * (2.05 + pull * (0.2 + 0.2 * c_i))
                        box(silk, (1.12, 0.08, 1.05), T((cx, cy, cz + 0.18)))

    # Attached brass easel-frame on the east (+X) end holding the Nereth slate tide-chart ("received wet").
    ex = 6.9
    strut(metal, (ex - 0.9, -1.1, 0), (ex - 0.7, 0.2, 7.6), 0.22)
    strut(metal, (ex + 0.9, -1.1, 0), (ex + 0.7, 0.2, 7.6), 0.22)
    strut(metal, (ex, 1.4, 0), (ex, 0.2, 7.2), 0.22)
    frame_m = T((ex, -0.3, 5.0)) @ R(math.radians(-14), 4, "X")
    # Brass frame + dark slate tablet + damp star-glass sheen + carved tide rings.
    box(trim, (2.8, 0.28, 3.6), frame_m)
    box(alt, (2.3, 0.34, 3.1), frame_m)
    box(crystal, (2.1, 0.08, 1.1), frame_m @ T((0, -0.18, -0.85)))
    ring_mesh(glow, 0.65, 0.05, 14, frame_m @ T((0, -0.20, 0.35)) @ R(math.pi / 2, 4, "X"), tube_segs=4)
    ring_mesh(trim, 0.95, 0.04, 14, frame_m @ T((0, -0.20, 0.35)) @ R(math.pi / 2, 4, "X"), tube_segs=4)


# -----------------------------------------------------------------------------------------------------------
# 9. CopyistDesk — Ebony sloped writing desk with open tome, inkpot, quill, desk-lamp and bench
# -----------------------------------------------------------------------------------------------------------
@template("CopyistDesk", WOOD=1800, METAL=900, TRIM=900, SILK=900, ALT=500, GLOW=300)
def copyist_desk(t):
    """An Astral Scribe's ebony copyist desk: turned legs with brass stretchers, sloped writing top with
    gold inlay rim, open vellum tome, brass ink-pot and tall quill, stacked manuscripts, hooded desk-lamp,
    and a low ebony reading bench tucked in front."""
    wood, metal, trim, silk, alt, glow = (t.bm(r) for r in ("WOOD", "METAL", "TRIM", "SILK", "ALT", "GLOW"))
    # Desk legs & stretcher bars.
    for sx in (-1, 1):
        for sy in (-1, 1):
            box(wood, (0.55, 0.55, 3.4), T((sx * 3.4, sy * 1.5, 1.7)))
            box(metal, (0.68, 0.68, 0.45), T((sx * 3.4, sy * 1.5, 0.22)))
        strut(metal, (sx * 3.4, -1.5, 1.0), (sx * 3.4, 1.5, 1.0), 0.22)
    strut(metal, (-3.4, 0.8, 1.0), (3.4, 0.8, 1.0), 0.24)
    # Desk body & gently sloped top facing -Y.
    box(wood, (7.8, 3.8, 0.65), T((0, 0, 3.55)), bevel=0.06)
    top_m = T((0, 0, 4.05)) @ R(math.radians(-10), 4, "X")
    box(wood, (8.2, 4.2, 0.35), top_m, bevel=0.05)
    box(trim, (8.35, 4.35, 0.14), top_m @ T((0, 0, 0.14)))
    # Open tome in the centre of the desk.
    open_tome(alt, silk, trim, top_m @ T((-0.6, 0.1, 0.22)), w=3.1, d=2.1, page_h=0.45, spread=0.25)
    # Ink-pot & tall feather quill on the right.
    cyl_z(metal, 0.34, 0.55, (2.3, -0.5, 4.15), segs=10)
    strut(trim, (2.3, -0.5, 4.55), (2.95, -0.1, 6.2), 0.08)
    box(silk, (0.48, 0.08, 1.35), T((2.75, -0.22, 5.65)) @ R(-0.35, 4, "Y"))
    # Stack of spare tomes on the far left.
    for k in range(3):
        m = T((-2.9, 0.6, 4.35 + k * 0.34)) @ R(0.18 * (k - 1), 4, "Z")
        box(alt if k % 2 == 0 else wood, (1.5, 1.9, 0.28), m)
        box(silk, (1.36, 1.76, 0.20), m @ T((0.06, 0, 0)))
    # Small hooded brass desk-lamp on back-right corner.
    strut(metal, (3.2, 1.4, 4.25), (3.2, 1.4, 6.1), 0.16)
    strut(metal, (3.2, 1.4, 6.1), (2.4, 0.8, 6.1), 0.14)
    cone(trim, 0.65, 0.18, 0.55, 8, T((2.4, 0.8, 5.55)))
    uvsphere(glow, 0.28, T((2.4, 0.8, 5.45)), 8, 6)
    # Reading bench tucked in front (-Y).
    box(wood, (5.2, 1.5, 0.36), T((0, -3.2, 1.95)), bevel=0.05)
    box(trim, (5.3, 1.6, 0.1), T((0, -3.2, 2.15)))
    for sx in (-1, 1):
        box(wood, (0.42, 1.3, 1.9), T((sx * 2.1, -3.2, 0.95)))


# -----------------------------------------------------------------------------------------------------------
# 10. BookcaseCurved — Curved three-bay ebony bookcase with tomes & rolling ladder (The Three Barbs)
# -----------------------------------------------------------------------------------------------------------
@template("BookcaseCurved", WOOD=3600, STONE=900, TRIM=2200, METAL=1200, ALT=1400, SILK=1400)
def bookcase_curved(t):
    """A sweeping curved three-bay ebony library bookcase (matching the Three Barbs' reading gardens):
    vellum-stone plinth, curved arched bays packed with varied tomes, gold pilasters and star-quill cresting,
    and a brass rolling-ladder rail with a leaning library ladder. About 21 wide, 14.5 tall."""
    wood, stone, trim, metal, alt, silk = (t.bm(r) for r in ("WOOD", "STONE", "TRIM", "METAL", "ALT", "SILK"))
    rng = random.Random(4141)
    arc_r = 22.0
    bay_angles = (-math.radians(17), 0.0, math.radians(17))
    bay_w, bay_d, bay_h = 6.2, 2.8, 12.4

    for b_idx, ang in enumerate(bay_angles):
        # Curve hugs a circle centred at (0, -arc_r, 0), concave facing -Y (front).
        cx = math.sin(ang) * arc_r
        cy = (math.cos(ang) - 1.0) * arc_r
        bm_mat = T((cx, cy, 0.0)) @ R(-ang, 4, "Z")

        # Vellum-stone base plinth & ebony carcass back/top.
        box(stone, (bay_w + 0.3, bay_d + 0.4, 1.0), bm_mat @ T((0, 0, 0.5)), bevel=0.06)
        box(wood, (bay_w, 0.45, bay_h), bm_mat @ T((0, bay_d * 0.42, 1.0 + bay_h * 0.5)))
        box(wood, (bay_w + 0.4, bay_d + 0.5, 0.8), bm_mat @ T((0, 0, bay_h + 1.1)), bevel=0.08)
        box(trim, (bay_w + 0.55, bay_d + 0.6, 0.25), bm_mat @ T((0, 0, bay_h + 1.55)))
        # Side pilasters with gold capitals.
        for sx in (-1, 1):
            box(wood, (0.65, bay_d + 0.15, bay_h), bm_mat @ T((sx * (bay_w * 0.48), 0, 1.0 + bay_h * 0.5)))
            box(trim, (0.8, bay_d + 0.3, 0.55), bm_mat @ T((sx * (bay_w * 0.48), 0, bay_h + 0.55)))

        # Four shelves packed with varied upright & leaning tomes.
        for s_i in range(4):
            sz = 1.3 + s_i * 2.85
            box(wood, (bay_w - 0.6, bay_d - 0.2, 0.3), bm_mat @ T((0, -0.1, sz)))
            # Grouped book blocks with distinct heights, spine tilts and alternating roles.
            x_cur = -bay_w * 0.41
            while x_cur < bay_w * 0.36:
                bw = rng.uniform(0.55, 1.05)
                bh = rng.uniform(1.55, 2.25)
                bd = rng.uniform(1.45, 1.95)
                tilt = rng.uniform(-0.14, 0.14) if rng.random() < 0.25 else 0.0
                role_bm = (alt, trim, silk, wood)[(b_idx + s_i + int((x_cur + 5) * 3)) % 4]
                box(role_bm, (bw, bd, bh), bm_mat @ T((x_cur + bw * 0.5, -0.15, sz + 0.15 + bh * 0.5)) @ R(tilt, 4, "Y"))
                x_cur += bw + 0.12

        # Centre bay carries an arched gold pediment crest.
        if b_idx == 1:
            box(trim, (4.0, 0.6, 0.7), bm_mat @ T((0, -bay_d * 0.35, bay_h + 1.95)))
            cone(trim, 1.4, 0.08, 1.9, 4, bm_mat @ T((0, -bay_d * 0.35, bay_h + 2.2)) @ R(math.pi / 4, 4, "Z"))

    # Brass rolling-ladder rail sweeping along the front face + leaning brass ladder on the right bay.
    rail_pts = []
    for k in range(13):
        a = -math.radians(24) + math.radians(48) * k / 12
        rail_pts.append((math.sin(a) * (arc_r - 1.85), (math.cos(a) - 1.0) * (arc_r - 1.85) - 1.85, 11.4))
    tube(metal, rail_pts, [0.16] * len(rail_pts), 6, cap=True)
    # Leaning brass ladder at bay 2.
    la = math.radians(12)
    lm = T((math.sin(la) * (arc_r - 2.2), (math.cos(la) - 1.0) * (arc_r - 2.2) - 2.2, 0.0)) @ R(-la, 4, "Z")
    for sx in (-0.75, 0.75):
        strut(metal, lm @ Vector((sx, -2.0, 0.0)), lm @ Vector((sx, 0.25, 11.5)), 0.18)
    for r_i in range(9):
        f = (r_i + 0.6) / 9.5
        ry = -2.0 + 2.25 * f
        rz = 11.5 * f
        strut(trim, lm @ Vector((-0.75, ry, rz)), lm @ Vector((0.75, ry, rz)), 0.12)


# -----------------------------------------------------------------------------------------------------------
# 11. InkwellBasin — Round star-well pool basin with compass rim and ink-pots (The Inkwell isle)
# -----------------------------------------------------------------------------------------------------------
@template("InkwellBasin", STONE=2200, METAL=1800, TRIM=1400, ALT=1400, CRYSTAL=1400, GLOW=900, SILK=500)
def inkwell_basin(t):
    """The Inkwell's centrepiece star-well: a 22-stud-diameter stepped vellum-stone circular curb ringed by
    brass compass-ticks, enclosing a deep swirling lapis-and-starglass ink pool with glowing starlight ripples,
    flanked by four oversized ink-pots with tall quills around the rim."""
    stone, metal, trim, alt, crystal, glow, silk = (t.bm(r) for r in ("STONE", "METAL", "TRIM", "ALT", "CRYSTAL", "GLOW", "SILK"))
    R_out, R_in = 10.8, 8.2

    # Stepped circular vellum-stone well curb (hollow ring built from 24 segments).
    segs = 24
    for k in range(segs):
        a = 2 * math.pi * (k + 0.5) / segs
        w = 2 * math.pi * ((R_out + R_in) * 0.5) / segs + 0.3
        m = R(a, 4, "Z") @ T(((R_out + R_in) * 0.5, 0, 0))
        box(stone, (R_out - R_in, w, 1.8), m @ T((0, 0, 0.9)))
        box(stone, (R_out - R_in + 0.8, w * 1.04, 0.65), m @ T((0.2, 0, 0.32)))

    # Brass rim collar & 8 gold compass pointer ticks.
    ring_mesh(metal, R_in + 0.35, 0.35, 32, T((0, 0, 1.9)), tube_segs=6)
    ring_mesh(trim, R_out - 0.2, 0.24, 32, T((0, 0, 1.85)), tube_segs=5)
    for k in range(8):
        a = 2 * math.pi * k / 8
        box(trim, (1.6, 0.35, 0.28), R(a, 4, "Z") @ T((R_in + 1.2, 0, 1.98)))

    # Recessed dark lapis well bed & swirling star-glass surface with spiral starlight ribbons.
    cyl_z(alt, R_in + 0.1, 0.45, (0, 0, 0.05), segs=24)
    cyl_z(crystal, R_in + 0.05, 0.35, (0, 0, 0.85), segs=24)
    # Two spiral starlight ripples inside the ink pool.
    for arm in range(2):
        pts = []
        for k in range(18):
            f = k / 17.0
            a = arm * math.pi + f * 3.8
            rr = 0.7 + f * (R_in - 1.4)
            pts.append((math.cos(a) * rr, math.sin(a) * rr, 1.24))
        tube(glow, pts, [0.20 * (1.0 - 0.5 * (k / 17.0)) for k in range(18)], 5, cap=True)
    uvsphere(glow, 1.0, T((0, 0, 1.05)), 10, 6)

    # Four ornate archive ink-pots & tall quills at intercardinal rim spots.
    for k in range(4):
        a = math.pi / 4 + k * math.pi / 2
        ix, iy = math.cos(a) * (R_out - 0.7), math.sin(a) * (R_out - 0.7)
        lathe(metal, [(0.85, 0), (0.95, 0.6), (0.55, 1.3), (0.68, 1.6)], 10, T((ix, iy, 1.8)))
        ring_mesh(trim, 0.62, 0.09, 12, T((ix, iy, 3.35)), tube_segs=4)
        # Tall tilted quill rising from each ink-pot.
        qm = T((ix, iy, 3.2)) @ R(a, 4, "Z") @ R(0.32, 4, "Y")
        strut(trim, qm @ Vector((0, 0, 0)), qm @ Vector((0, 0, 3.6)), 0.10)
        box(silk, (0.75, 0.12, 2.1), qm @ T((0.25, 0, 2.35)))


# -----------------------------------------------------------------------------------------------------------
# 12. ChainedSlab — The Blotter: cracked vellum slab hung on four towering brass chains with ink blot
# -----------------------------------------------------------------------------------------------------------
@template("ChainedSlab", STONE=2600, METAL=3400, TRIM=1600, ALT=1400, CRYSTAL=800, GLOW=400)
def chained_slab(t):
    """The Blotter: a massive 26x22 fractured vellum-stone manuscript slab suspended from four towering
    vertical brass anchor chains (rising 48 studs) with heavy corner shackles, gold page-ruling inlay,
    and a sculpted glossy indigo star-ink splatter pooled across its top."""
    stone, metal, trim, alt, crystal, glow = (t.bm(r) for r in ("STONE", "METAL", "TRIM", "ALT", "CRYSTAL", "GLOW"))
    W, D, H = 26.0, 22.0, 4.2

    # Thick fractured vellum-stone slab built from dressed blocks with chipped underside crags.
    box(stone, (W, D, H * 0.72), T((0, 0, H * 0.64)), bevel=0.35)
    for k in range(10):
        a = 2 * math.pi * k / 10
        rx, ry = math.cos(a) * W * 0.36, math.sin(a) * D * 0.36
        slab_stone(stone, (7.5, 6.2, 2.4), (rx, ry, 1.2), rot_z=a, seed=4151 + k, roughness=0.22)
    # Subtle gold manuscript border lines inlaid on the top surface.
    for sy in (-1, 1):
        box(trim, (W - 3.0, 0.25, 0.12), T((0, sy * (D * 0.5 - 1.5), H + 0.04)))
    for sx in (-1, 1):
        box(trim, (0.25, D - 3.0, 0.12), T((sx * (W * 0.5 - 1.5), 0, H + 0.04)))

    # Sculpted irregular star-ink blot pool splashed across the slab top (deep indigo ALT ink over star-glass rim).
    blot_lobes = [
        (0.0, 0.0, 5.4), (3.9, 1.7, 3.2), (-3.8, 2.3, 3.0), (-2.9, -3.3, 3.3),
        (3.3, -2.9, 2.7), (6.7, -0.5, 1.5), (-6.4, 0.4, 1.4), (1.3, 5.5, 1.6),
    ]
    for bx, by, br in blot_lobes:
        cyl_z(crystal, br * 1.05, 0.14, (bx, by, H - 0.02), segs=14)
        cyl_z(alt, br * 0.92, 0.20, (bx, by, H + 0.04), segs=14)
    # Tiny glowing star-specks suspended in the deep indigo star-ink.
    rng = random.Random(4159)
    for k in range(11):
        uvsphere(glow, 0.22, T((rng.uniform(-5.0, 5.0), rng.uniform(-4.2, 4.2), H + 0.28)), 6, 5)

    # Four massive corner brass anchor shackles & towering vertical chains rising to Z = 48.
    for sx in (-1, 1):
        for sy in (-1, 1):
            cx, cy = sx * (W * 0.5 - 2.1), sy * (D * 0.5 - 2.1)
            box(metal, (2.6, 2.6, 0.75), T((cx, cy, H + 0.35)))
            ring_mesh(trim, 1.05, 0.28, 14, T((cx, cy, H + 1.35)) @ R(math.pi / 2, 4, "X"), tube_segs=5)
            chain_run(metal, trim, (cx, cy, H + 2.0), (cx, cy, 48.0), link_h=2.4, link_w=1.45, thick=0.28)


# -----------------------------------------------------------------------------------------------------------
# 13. StarMossPlanter — Vellum-stone planter trough filled with star-moss & starlight buds (Three Barbs)
# -----------------------------------------------------------------------------------------------------------
@template("StarMossPlanter", STONE=1200, ALT=400, TRIM=700, MOSS=1800, GLOW=400)
def star_moss_planter(t):
    """A Halcyr reading-garden planter box: panelled vellum-stone trough with lapis insets, gold corner
    finials, brimming with sculpted star-moss cushions and pale-gold starlight blossoms. About 10x4.5x4.5."""
    stone, alt, trim, moss, glow = (t.bm(r) for r in ("STONE", "ALT", "TRIM", "MOSS", "GLOW"))
    # Stone trough & stepped feet.
    box(stone, (10.2, 4.6, 0.55), T((0, 0, 0.275)), bevel=0.06)
    box(stone, (9.4, 4.0, 2.2), T((0, 0, 1.65)), bevel=0.08)
    box(alt, (7.6, 4.18, 1.25), T((0, 0, 1.65)))
    box(stone, (10.4, 4.8, 0.45), T((0, 0, 2.95)), bevel=0.06)
    box(trim, (10.55, 4.95, 0.16), T((0, 0, 3.22)))
    for sx in (-1, 1):
        for sy in (-1, 1):
            uvsphere(trim, 0.34, T((sx * 4.9, sy * 2.1, 3.55)), 8, 6)
    # Pillowy star-moss mounds brimming over the rim.
    rng = random.Random(4161)
    for k in range(7):
        mx = -3.8 + k * 1.26
        my = rng.uniform(-0.7, 0.7)
        ground_rock(moss, (rng.uniform(2.4, 3.4), rng.uniform(2.4, 3.2), rng.uniform(1.3, 2.1)), (mx, my, 2.75), seed=4162 + k, roughness=0.32, subdiv=2)
    # Pale starlight buds peeking out of the moss.
    for k in range(6):
        bx = -3.5 + k * 1.4
        by = rng.uniform(-0.8, 0.8)
        bz = rng.uniform(3.9, 4.55)
        uvsphere(glow, 0.24, T((bx, by, bz)), 6, 5)


# -----------------------------------------------------------------------------------------------------------
# 14. FloatingTomeCluster — Orbiting ring of 7 open tomes on a golden starlight ribbon
# -----------------------------------------------------------------------------------------------------------
@template("FloatingTomeCluster", ALT=1400, WOOD=900, SILK=2200, TRIM=1600, GLOW=1200)
def floating_tome_cluster(t):
    """An orbital halo of 7 open floating tomes circling a pale-gold starlight ribbon (for orbiting the
    Lectern of First Light and spire landmarks). Stands on z = 0, radius ~11, height ~13."""
    alt, wood, silk, trim, glow = (t.bm(r) for r in ("ALT", "WOOD", "SILK", "TRIM", "GLOW"))
    # Subtle golden helical starlight ribbon (starts near z = 1.0, spirals gracefully up to z = 11.5).
    rib_pts = []
    for k in range(37):
        a = 2 * math.pi * k / 36
        rr = 10.2 + math.sin(a * 2) * 0.9
        zz = 5.5 + math.sin(a) * 3.8
        rib_pts.append((math.cos(a) * rr, math.sin(a) * rr, zz))
    tube(glow, rib_pts, [0.15] * len(rib_pts), 5, cap=False)

    # 7 open tomes riding the orbital halo, facing outward & pitched gently along the flight curve.
    n = 7
    for k in range(n):
        a = 2 * math.pi * k / n
        rr = 10.2 + math.sin(a * 2) * 0.9
        zz = 5.5 + math.sin(a) * 3.8 + (0.6 if k % 2 == 0 else -0.6)
        # Keep lowest tome resting cleanly near z = 0.4 so template Min.Y passes origin check.
        if k == 5:
            zz = 0.65
        tm = T((math.cos(a) * rr, math.sin(a) * rr, zz)) @ R(a + math.pi / 2, 4, "Z") @ R(math.radians(-18), 4, "X")
        cover = alt if k % 2 == 0 else wood
        open_tome(cover, silk, trim, tm, w=3.8, d=2.6, page_h=0.65, spread=0.34)
        # Small glowing star-mote hovering above each open tome.
        uvsphere(glow, 0.28, tm @ T((0, 0, 1.35)), 6, 5)


# -----------------------------------------------------------------------------------------------------------
# 15. CalamusArmillary — Central isle brass armillary sphere on a lapis-and-vellum plinth (The Calamus)
# -----------------------------------------------------------------------------------------------------------
@template("CalamusArmillary", STONE=2200, ALT=1400, METAL=3200, TRIM=2200, CRYSTAL=900, GLOW=900)
def calamus_armillary(t):
    """The Calamus's signature central armillary sphere (from the guide image's middle isle): stepped round
    lapis-and-vellum stone pedestal with gold inlaid cardinal lines, turned brass cradle column, and a grand
    multi-ring brass armillary sphere enclosing a glowing pale-gold star-core. About 16 wide, 25 tall."""
    stone, alt, metal, trim, crystal, glow = (t.bm(r) for r in ("STONE", "ALT", "METAL", "TRIM", "CRYSTAL", "GLOW"))
    # Stepped circular lapis & vellum-stone pedestal.
    cone(stone, 8.2, 7.8, 1.2, 24, T((0, 0, 0)))
    cone(alt, 7.0, 6.7, 1.0, 24, T((0, 0, 1.2)))
    ring_mesh(trim, 7.1, 0.22, 28, T((0, 0, 2.2)), tube_segs=5)
    cone(stone, 5.4, 4.6, 2.4, 16, T((0, 0, 2.2)))
    ring_mesh(trim, 4.7, 0.24, 20, T((0, 0, 4.6)), tube_segs=5)
    # Four curved brass scroll buttresses supporting the pedestal column.
    for k in range(4):
        a = k * math.pi / 2
        m = R(a, 4, "Z")
        strut(metal, m @ Vector((5.8, 0, 2.2)), m @ Vector((2.2, 0, 7.5)), 0.45)
        box(trim, (1.1, 0.45, 0.25), m @ T((6.8, 0, 1.35)))
    # Turned brass pedestal column & cradle fork.
    lathe(metal, [(2.8, 4.6), (1.4, 6.2), (1.1, 9.2), (1.8, 10.6), (1.2, 11.4)], 14, Matrix.Identity(4))
    # Semicircular brass meridian cradle holding the great armillary sphere (centred at Z = 17.8, R = 6.2).
    cz, R_arm = 17.8, 6.2
    cradle_pts = []
    for k in range(17):
        a = math.radians(-165) + math.radians(150) * k / 16
        cradle_pts.append((math.cos(a) * (R_arm + 0.9), 0.0, cz + math.sin(a) * (R_arm + 0.9)))
    tube(metal, cradle_pts, [0.38] * len(cradle_pts), 6, cap=True)
    # Grand nested armillary sphere.
    armillary_sphere(metal, trim, crystal, glow, (0, 0, cz), R_arm, segs=30)


# -----------------------------------------------------------------------------------------------------------
# 16. RuneguardGatePost — Vane Root doorkeeper post: brass turnstile gate, glaive rack & register lectern
# -----------------------------------------------------------------------------------------------------------
@template("RuneguardGatePost", STONE=1600, METAL=2800, TRIM=1600, WOOD=1400, SILK=500, GLOW=600)
def runeguard_gate_post(t):
    """Vane Root's Runeguard doorkeeper checkpoint (from the guide image's front-left isle): an ornate
    brass-barred checkpoint fence & turnstile between vellum-stone piers, flanked by an ebony glaive rack
    holding 5 segmented Runeguard glaives and a brass register lectern with an open ledger."""
    stone, metal, trim, wood, silk, glow = (t.bm(r) for r in ("STONE", "METAL", "TRIM", "WOOD", "SILK", "GLOW"))
    # Two vellum-stone flanking checkpoint piers + ornate brass barred barrier between them.
    for sx in (-1, 1):
        box(stone, (2.2, 2.2, 6.8), T((sx * 6.2, 0, 3.4)), bevel=0.1)
        box(trim, (2.5, 2.5, 0.45), T((sx * 6.2, 0, 7.0)))
        cone(trim, 0.75, 0.05, 1.5, 4, T((sx * 6.2, 0, 7.25)) @ R(math.pi / 4, 4, "Z"))
    # Brass checkpoint gate rails & vertical spears.
    box(metal, (10.8, 0.35, 0.35), T((0, 0, 1.2)))
    box(metal, (10.8, 0.35, 0.38), T((0, 0, 5.2)))
    for k in range(11):
        gx = -5.0 + k * 1.0
        if abs(gx) < 1.2:
            continue  # Leave narrow centre turnstile spindle slot.
        strut(metal, (gx, 0, 0.4), (gx, 0, 5.6), 0.16)
        cone(trim, 0.18, 0.02, 0.65, 4, T((gx, 0, 5.6)))
    # Centre brass rotating turnstile spindle with 4 crossed arms.
    cyl_z(metal, 0.32, 4.6, (0, 0, 0.0), segs=10)
    uvsphere(trim, 0.5, T((0, 0, 4.7)), 8, 6)
    for k in range(4):
        a = k * math.pi / 2 + math.pi / 4
        strut(trim, (0, 0, 3.0), (math.cos(a) * 2.4, math.sin(a) * 2.4, 3.0), 0.18)

    # Ebony & brass Runeguard Glaive Rack on the left (-X, offset slightly forward).
    rx, ry = -8.6, 1.8
    box(wood, (5.8, 1.8, 0.5), T((rx, ry, 0.25)))
    for sx in (-2.6, 2.6):
        box(wood, (0.45, 0.9, 6.2), T((rx + sx, ry, 3.3)))
    box(wood, (5.8, 0.5, 0.45), T((rx, ry, 5.6)))
    # 5 tall segmented Runeguard glaives standing in the rack.
    for k in range(5):
        gx = rx - 2.0 + k * 1.0
        cyl_z(metal, 0.12, 8.2, (gx, ry, 0.5), segs=8)
        # Segmented crescent glaive blade + glowing starlight edge.
        box(trim, (0.22, 0.65, 2.2), T((gx, ry - 0.12, 9.2)) @ R(-0.1, 4, "X"))
        box(glow, (0.14, 0.24, 1.8), T((gx, ry - 0.42, 9.2)) @ R(-0.1, 4, "X"))

    # Brass Register Lectern on the right (+X) with an open visitors' ledger.
    lx, ly = 8.8, -1.6
    cone(stone, 1.3, 1.0, 0.6, 8, T((lx, ly, 0)))
    lathe(metal, [(0.45, 0.6), (0.26, 2.4), (0.38, 3.8), (0.24, 4.6)], 10, T((lx, ly, 0)))
    lm = T((lx, ly, 4.85)) @ R(math.radians(-24), 4, "X")
    box(trim, (2.6, 1.9, 0.22), lm)
    open_tome(wood, silk, trim, lm @ T((0, 0, 0.18)), w=2.2, d=1.55, page_h=0.32, spread=0.22)


# -----------------------------------------------------------------------------------------------------------
# 17. LamplighterRack — Spare Index Lamp storage rack & hooked lighting pole (Lamplighters' Isle)
# -----------------------------------------------------------------------------------------------------------
@template("LamplighterRack", WOOD=1800, METAL=1600, TRIM=1600, STONE=700, CRYSTAL=900, GLOW=900)
def lamplighter_rack(t):
    """Lamplighters' Isle's lamp-store rack (from the guide image's mid-left isle): an ebony-and-brass
    twin-bay frame on stone footing blocks hung with 6 spare glowing Index Lamps in two tiers, plus a long
    brass hooked lamp-lighting pole leaning against the side."""
    wood, metal, trim, stone, crystal, glow = (t.bm(r) for r in ("WOOD", "METAL", "TRIM", "STONE", "CRYSTAL", "GLOW"))
    # Stone footing blocks & ebony timber frame.
    for x in (-6.2, 0.0, 6.2):
        box(stone, (1.5, 2.2, 0.7), T((x, 0, 0.35)), bevel=0.06)
        box(wood, (0.72, 0.72, 9.4), T((x, 0, 5.2)))
        box(trim, (0.92, 0.92, 0.35), T((x, 0, 9.95)))
    # Top cornice beam & two horizontal brass hanging rods.
    box(wood, (13.6, 1.4, 0.75), T((0, 0, 9.7)), bevel=0.06)
    box(trim, (13.9, 1.6, 0.22), T((0, 0, 10.15)))
    for z_rod in (4.8, 8.8):
        cyl_x(metal, 0.18, 12.6, (0, 0, z_rod), segs=10)
    # 6 spare Index Lamps hung in two neat rows (3 upper, 3 lower).
    for row_z, xs in ((7.2, (-4.2, -1.8, 3.1)), (3.2, (-3.1, 1.8, 4.2))):
        for lx in xs:
            strut(metal, (lx, 0, row_z + 1.55), (lx, 0, row_z + 0.9), 0.1)
            index_lantern_head(metal, trim, crystal, glow, T((lx, 0, row_z)), scale=0.68)
    # Long brass hooked lamp-lighting pole leaning diagonally against the east post.
    strut(metal, (7.6, -2.4, 0.0), (5.8, 0.35, 11.4), 0.16)
    hook_pts = [(5.8, 0.35, 11.4), (5.6, 0.65, 12.1), (5.2, 0.95, 12.25), (4.9, 1.05, 11.7)]
    tube(trim, hook_pts, [0.12] * len(hook_pts), 5, cap=True)


# -----------------------------------------------------------------------------------------------------------
# 18. FarArchiveTower — Floating background library tower for the Starfield skyline (guide image backdrop)
# -----------------------------------------------------------------------------------------------------------
@template("FarArchiveTower", ALT=2800, STONE=3400, TRIM=2200, METAL=1200, CRYSTAL=1200, GLOW=1200, WOOD=600, SILK=600)
def far_archive_tower(t):
    """A slender floating Halcyr archive tower for the far Starfield skyline (seen floating in the void in
    the guide image): tapering slate rock & star-glass underside, 3-story round vellum-stone stack tower with
    arched glowing library windows, ribbed lapis-indigo dome, gold spire finial, and a small stack of giant
    floating tomes hovering beside its flank. About 58 studs tall."""
    alt, stone, trim, metal, crystal, glow, wood, silk = (t.bm(r) for r in ("ALT", "STONE", "TRIM", "METAL", "CRYSTAL", "GLOW", "WOOD", "SILK"))

    # Floating slate rock base & downward crystal tip standing on z = 0.
    crystal_spike_cluster(crystal, glow, base_z=6.2, spread_r=4.2, height=6.2, count=5, seed=4181, pointing_down=True)
    cone(alt, 2.2, 8.4, 10.5, 10, T((0, 0, 3.8)))
    cone(stone, 8.4, 8.8, 1.5, 16, T((0, 0, 14.3)))
    ring_mesh(trim, 8.8, 0.28, 20, T((0, 0, 15.8)), tube_segs=5)

    # Three-story cylindrical vellum-stone library tower (Z = 15.8..42.8).
    cone(stone, 6.8, 6.2, 27.0, 16, T((0, 0, 15.8)))
    for story in range(3):
        sz = 16.5 + story * 8.6
        r_s = 6.75 - story * 0.2
        ring_mesh(trim, r_s + 0.35, 0.25, 20, T((0, 0, sz + 8.0)), tube_segs=5)
        # 8 recessed arched stack windows per story.
        for k in range(8):
            a = 2 * math.pi * k / 8
            wm = R(a, 4, "Z") @ T((r_s - 0.1, 0, sz + 3.8))
            box(alt, (0.65, 1.85, 5.0), wm)
            box(glow, (0.45, 1.15, 4.1), wm @ T((0.2, 0, 0)))
            box(trim, (0.45, 2.15, 0.35), wm @ T((0.22, 0, -2.55)))
            box(trim, (0.45, 2.15, 0.35), wm @ T((0.22, 0, 2.55)))

    # Cornice parapet & ribbed lapis-indigo dome + gold star-quill spire (Z = 42.8..58.0).
    cone(stone, 6.4, 7.2, 1.6, 16, T((0, 0, 42.8)))
    lathe(alt, [(6.1, 0.0), (6.0, 1.8), (5.2, 4.2), (3.4, 6.8), (1.2, 8.4), (0.2, 9.0)], 16, T((0, 0, 44.4)))
    for k in range(8):
        a = 2 * math.pi * k / 8
        pts = [
            (math.cos(a) * 6.2, math.sin(a) * 6.2, 44.4),
            (math.cos(a) * 5.4, math.sin(a) * 5.4, 48.6),
            (math.cos(a) * 3.5, math.sin(a) * 3.5, 51.2),
            (math.cos(a) * 0.6, math.sin(a) * 0.6, 53.3),
        ]
        tube(trim, pts, [0.22, 0.20, 0.18, 0.14], 5, cap=True)
    cone(metal, 0.55, 0.05, 5.2, 8, T((0, 0, 53.2)))
    uvsphere(glow, 0.65, T((0, 0, 56.4)), 8, 6)

    # Small hovering stack of 4 oversized books floating off the tower's flank (seen in the guide image!).
    for k in range(4):
        bm_rot = R(0.28 * k, 4, "Z")
        bz = 20.0 + k * 1.45
        box(wood if k % 2 == 0 else alt, (4.2, 3.2, 1.1), T((10.6, -1.5, bz)) @ bm_rot)
        box(silk, (3.85, 2.85, 0.8), T((10.75, -1.5, bz)) @ bm_rot)
        box(trim, (4.3, 0.25, 1.15), T((10.6, -1.5, bz)) @ bm_rot @ T((0, -1.55, 0)))


def apply_halcyr_preview_materials(kit):
    """Tint Blender Workbench materials to the Halcyr palette so preview PNGs read clearly."""
    for obj in kit.all_objects:
        if obj.type != "MESH" or "__" not in obj.name:
            continue
        role = obj.name.rsplit("__", 1)[-1]
        rgba = HALCYR_PREVIEW_COLORS.get(role)
        if not rgba:
            continue
        mat_name = f"HalcyrPreview_{role}"
        mat = bpy.data.materials.get(mat_name)
        if mat is None:
            mat = bpy.data.materials.new(mat_name)
            mat.diffuse_color = rgba
        obj.data.materials.clear()
        obj.data.materials.append(mat)


if __name__ == "__main__":
    kit, manifest = build_kit("AstralF41Kit", F41_TEMPLATES, DEFAULT_BUDGET)
    apply_halcyr_preview_materials(kit)
    export_kit(kit, manifest, OUT_DIR, "AstralF41Kit")
    render_previews(kit, F41_TEMPLATES, OUT_DIR)
    print(json.dumps(manifest, indent=2))
