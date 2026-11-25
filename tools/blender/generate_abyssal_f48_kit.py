"""
Abyssal Throne Floor 48 (Voidspan Crossing) sculpted assets, generated in headless Blender.

Inspired by the Voidspan Crossing reference art (Abyssal Throne 48.jpg) and the Vahl / Warden-King
ecosystem (docs/prompts/abyssal-throne-floor-layouts-prompt.md):
the court's crossing of the great void. Four towering iron-collared obsidian Anchor Spires with giant
capstans and suspended counterweights carry four colossal forged iron chains in a dipping saltire over
the central hung iron Keystone cage-platform (brightest bone-white Wardlight at the lowest point), with
four hung iron Bead platforms suspended along the arms, wall-bolted iron Gibbet Ledges along the sheer
void walls, the Chainwright's Yard half-forged colossal link, the Hookward pulley gantries, the Ashgrate
grated ash pits, and the obsidian Far Gatehouse crowned with the gold-rimmed Chained Crown sigil over
the churning violet Undertow pool below.

1 Blender unit = 1 stud, standing on z = 0, front facing -Y in Blender / +Z in Roblox, one mesh object
per colour role named "<Template>__<ROLE>". Every piece stands on its origin (min.y in (-1.0, 0.5]).

Roles (AbyssalFloor48 passes full Abyssal / Throneward tint tables; no new colour roles):
    STONE    obsidian & dark basalt          ALT      bone-white marble & weathered bone
    METAL    blackened forged iron           TRIM     dark iron bands & chain collars
    SILK     matte wine-crimson silk         ACCENT   old gold (Chained Crown rim, sparingly)
    GLOW     pale bone-white Wardlight       CRYSTAL  caged void shard / dark violet energy
    MOSS     ash drifts & cinder rubble      WOOD     charred ironwood (capstan bars, trestles)

Outputs (assets-source/tower/abyssal_f48_kit/):
    AbyssalF48Kit.blend, AbyssalF48Kit.fbx, manifest.json, previews/kit_sheet_1.png, previews/tiles/*.png.

Run:
    blender.exe --background --factory-startup --python tools/blender/generate_abyssal_f48_kit.py
"""
import bpy, bmesh, math, os, json, runpy, random
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT_DIR = os.path.join(ROOT, "assets-source", "tower", "abyssal_f48_kit")

# Import ONLY from generate_infernal_f21_kit.py, generate_thunder_f26_kit.py, generate_astral_f41_kit.py.
f21 = runpy.run_path(os.path.join(HERE, "generate_infernal_f21_kit.py"))
f26 = runpy.run_path(os.path.join(HERE, "generate_thunder_f26_kit.py"))
f41 = runpy.run_path(os.path.join(HERE, "generate_astral_f41_kit.py"))

kit_mod = f21["kit_mod"]
box = f21["box"]
cone = f21["cone"]
uvsphere = f21["uvsphere"]
tube = f21["tube"]
ring_mesh = f21["ring_mesh"]
lathe = kit_mod["lathe"]
cyl_x, cyl_y, cyl_z, strut = f21["cyl_x"], f21["cyl_y"], f21["cyl_z"], f21["strut"]
build_kit, export_kit, render_previews = f21["build_kit"], f21["export_kit"], f21["render_previews"]
ground_rock, centred_rock, slab_stone = f26["ground_rock"], f26["centred_rock"], f26["slab_stone"]
chain_run = f41["chain_run"]

T = Matrix.Translation
R = Matrix.Rotation

DEFAULT_BUDGET = 3500
F48_TEMPLATES = {}

# Abyssal Workbench preview colours (Studio strips materials and tints per role via TowerKitProps).
ABYSSAL_PREVIEW_COLORS = {
    "STONE": (0.10, 0.09, 0.13, 1.0),   # dark obsidian
    "ALT": (0.84, 0.81, 0.75, 1.0),     # bone-white marble
    "METAL": (0.20, 0.21, 0.25, 1.0),   # blackened forged iron
    "TRIM": (0.28, 0.29, 0.34, 1.0),    # dark iron bands & collars
    "SILK": (0.46, 0.09, 0.14, 1.0),    # matte wine-crimson silk
    "ACCENT": (0.78, 0.64, 0.26, 1.0),  # old gold (Chained Crown rim)
    "GLOW": (0.96, 0.93, 0.87, 1.0),    # pale bone-white Wardlight
    "CRYSTAL": (0.42, 0.16, 0.58, 1.0), # caged void / violet energy
    "MOSS": (0.30, 0.28, 0.32, 1.0),    # ash drifts
    "WOOD": (0.22, 0.16, 0.13, 1.0),    # charred ironwood
}


def template(name, **budget):
    def deco(fn):
        F48_TEMPLATES[name] = (fn, budget)
        return fn
    return deco


# -----------------------------------------------------------------------------------------------------------
# Shared Abyssal / Vahl motifs: oval forged chain links, Wardlight iron cage, Chained Crown sigil
# -----------------------------------------------------------------------------------------------------------
def oval_link(bm, mat, link_len=3.2, link_w=1.8, thick=0.45, segs=12):
    """A single chunky forged oval chain link lying in local XZ plane (major axis along X)."""
    m = mat @ Matrix.Diagonal((link_len * 0.5, 1.0, link_w * 0.5, 1.0))
    ring_mesh(bm, 1.0, thick / max(link_len * 0.5, 0.5), segs, m @ R(math.pi / 2, 4, "X"), tube_segs=5)


def great_chain_curve(metal, trim, pts, link_len=4.2, link_w=2.4, thick=0.62, segs=12):
    """Lay alternating 90-degree heavy forged iron links along a polyline of 3D points."""
    total_pts = [Vector(p) for p in pts]
    if len(total_pts) < 2:
        return
    # Compute arc-length parameterisation
    cum = [0.0]
    for k in range(1, len(total_pts)):
        cum.append(cum[-1] + (total_pts[k] - total_pts[k - 1]).length)
    total_len = cum[-1]
    if total_len < 0.2:
        return
    step = link_len * 0.68
    n = max(2, int(total_len / step))
    for i in range(n):
        target = (i + 0.5) / n * total_len
        # Find segment
        seg_idx = 0
        while seg_idx < len(cum) - 2 and cum[seg_idx + 1] < target:
            seg_idx += 1
        d_seg = max(1e-5, cum[seg_idx + 1] - cum[seg_idx])
        frac = (target - cum[seg_idx]) / d_seg
        pos = total_pts[seg_idx].lerp(total_pts[seg_idx + 1], frac)
        tangent = (total_pts[seg_idx + 1] - total_pts[seg_idx]).normalized()
        q = tangent.to_track_quat("X", "Z").to_matrix().to_4x4()
        twist = (math.pi / 2) if (i % 2 == 1) else 0.0
        m = T(pos) @ q @ R(twist, 4, "X")
        bm = metal if (i % 3 != 1) else trim
        oval_link(bm, m, link_len=link_len, link_w=link_w, thick=thick, segs=segs)


def wardlight_cage(metal, trim, glow, mat, scale=1.0):
    """Blackened-iron hanging cage lantern with a pale bone-white Wardlight core (no orange)."""
    s = scale
    # Top suspension ring & peaked iron hood
    ring_mesh(trim, 0.52 * s, 0.12 * s, 10, mat @ T((0, 0, 2.05 * s)) @ R(math.pi / 2, 4, "X"), tube_segs=4)
    cone(metal, 1.45 * s, 0.25 * s, 0.95 * s, 6, mat @ T((0, 0, 0.95 * s)))
    # Bottom flared ash pan
    cone(metal, 0.22 * s, 1.25 * s, 0.70 * s, 6, mat @ T((0, 0, -1.75 * s)))
    # Glowing bone-white Wardlight flame core
    uvsphere(glow, 0.72 * s, mat @ T((0, 0, -0.15 * s)) @ Matrix.Diagonal((0.85, 0.85, 1.35, 1.0)), 10, 7)
    # 6 vertical iron cage bars & central band
    ring_mesh(trim, 1.22 * s, 0.11 * s, 12, mat @ T((0, 0, -0.15 * s)), tube_segs=4)
    for k in range(6):
        a = 2 * math.pi * k / 6
        rx, ry = math.cos(a) * 1.18 * s, math.sin(a) * 1.18 * s
        strut(trim, mat @ Vector((rx, ry, -1.10 * s)), mat @ Vector((rx, ry, 0.98 * s)), 0.13 * s)


def chained_crown_sigil(metal, trim, accent, mat, scale=1.0):
    """The Vahl sigil: a five-pointed iron-and-gold crown inside a ring of chain with ONE broken link at top."""
    s = scale
    R_ring = 3.2 * s
    links = 14
    for k in range(links):
        # Leave link k == 3 (topmost link, angle = pi/2) missing / broken open!
        a = 2 * math.pi * k / links
        if k == 3:
            # Parted broken-link halves splayed outward — Vharos's broken oath
            for side in (-1, 1):
                pa = a + side * 0.18
                pm = mat @ T((math.cos(pa) * (R_ring + 0.35 * s), 0, math.sin(pa) * (R_ring + 0.35 * s))) @ R(-pa + side * 0.55, 4, "Y")
                box(accent, (0.55 * s, 0.34 * s, 0.28 * s), pm)
            continue
        lm = mat @ T((math.cos(a) * R_ring, 0, math.sin(a) * R_ring)) @ R(-a + math.pi / 2, 4, "Y") @ R((math.pi / 2) if k % 2 else 0.0, 4, "X")
        oval_link(accent if k % 4 == 0 else trim, lm, link_len=1.25 * s, link_w=0.72 * s, thick=0.18 * s, segs=8)

    # Inner five-pointed crown in old gold & blackened iron
    box(metal, (3.2 * s, 0.50 * s, 0.65 * s), mat @ T((0, 0, -1.0 * s)))
    box(accent, (3.4 * s, 0.58 * s, 0.24 * s), mat @ T((0, 0, -1.25 * s)))
    box(accent, (3.3 * s, 0.58 * s, 0.22 * s), mat @ T((0, 0, -0.72 * s)))
    for i, (px, h_sp, tilt) in enumerate(((-1.35, 1.55, -0.22), (-0.70, 1.85, -0.10), (0.0, 2.35, 0.0), (0.70, 1.85, 0.10), (1.35, 1.55, 0.22))):
        pm = mat @ T((px * s, 0, -0.65 * s)) @ R(tilt, 4, "Y")
        cone(metal if i % 2 else accent, 0.34 * s, 0.05 * s, h_sp * s, 4, pm)
        uvsphere(accent, 0.18 * s, pm @ T((0, 0, h_sp * s)), 6, 4)


# -----------------------------------------------------------------------------------------------------------
# 1. AnchorSpire — Towering >=205-stud iron-collared obsidian spire with giant capstan & chain brackets
# -----------------------------------------------------------------------------------------------------------
@template("AnchorSpire", STONE=3600, METAL=3400, TRIM=2600, ACCENT=600, GLOW=600)
def anchor_spire(t):
    """Towering 214-stud tapered obsidian Anchor Spire (matches Abyssal Throne 48.jpg): stepped octagonal
    obsidian footing with heavy iron buttress claws, four massive studded blackened-iron collar bands,
    forged chain-anchor shackle brackets & backstay tension struts, cantilevered Wardlight lantern arm,
    and a crowned iron capstan-head rising to Z = 214."""
    stone, metal, trim, accent, glow = (t.bm(r) for r in ("STONE", "METAL", "TRIM", "ACCENT", "GLOW"))

    # Stepped octagonal obsidian footing (footprint ~24x24, z = 0..18)
    cone(stone, 12.2, 11.0, 5.5, 8, T((0, 0, 0.0)) @ R(math.pi / 8, 4, "Z"))
    cone(metal, 11.4, 10.6, 2.4, 8, T((0, 0, 5.5)) @ R(math.pi / 8, 4, "Z"))
    cone(stone, 9.8, 8.6, 10.5, 8, T((0, 0, 7.9)) @ R(math.pi / 8, 4, "Z"))

    # 4 heavy iron corner anchor claws gripping the plinth (z = 0..22)
    for k in range(4):
        a = k * math.pi / 2 + math.pi / 4
        m = R(a, 4, "Z")
        box(metal, (3.2, 4.0, 12.0), m @ T((9.2, 0, 6.0)), bevel=0.18)
        strut(trim, m @ Vector((10.4, 0, 1.5)), m @ Vector((7.2, 0, 22.0)), 1.65)
        # Anchor ring lug on outer plinth
        ring_mesh(trim, 1.35, 0.34, 10, m @ T((11.0, 0, 8.5)) @ R(math.pi / 2, 4, "X"), tube_segs=4)

    # Main soaring tapered octagonal obsidian spire shaft (z = 18..184)
    cone(stone, 8.2, 5.4, 62.0, 8, T((0, 0, 18.0)) @ R(math.pi / 8, 4, "Z"))
    cone(stone, 5.4, 3.2, 66.0, 8, T((0, 0, 80.0)) @ R(math.pi / 8, 4, "Z"))
    cone(stone, 3.2, 1.6, 42.0, 8, T((0, 0, 146.0)) @ R(math.pi / 8, 4, "Z"))

    # 8 vertical iron edge strakes running up the spire facets
    for k in range(8):
        a = k * math.pi / 4
        strut(metal, (math.cos(a) * 8.1, math.sin(a) * 8.1, 18.0), (math.cos(a) * 1.9, math.sin(a) * 1.9, 186.0), 0.75)

    # 5 heavy blackened-iron stepped collar rings with riveted gussets & massive chain-anchor shackles
    collar_specs = (
        (36.0, 7.8, 3.8),
        (68.0, 6.5, 4.2),
        (104.0, 5.2, 3.8),
        (140.0, 4.1, 4.4),
        (174.0, 2.9, 3.4),
    )
    for z_c, r_c, h_c in collar_specs:
        cone(metal, r_c + 1.15, r_c + 0.95, h_c, 8, T((0, 0, z_c)) @ R(math.pi / 8, 4, "Z"))
        ring_mesh(trim, r_c + 1.28, 0.55, 16, T((0, 0, z_c + 0.3)), tube_segs=5)
        ring_mesh(trim, r_c + 1.18, 0.50, 16, T((0, 0, z_c + h_c - 0.3)), tube_segs=5)
        # Rivet/bolt bosses around collar
        for k in range(8):
            a = k * math.pi / 4 + math.pi / 8
            box(trim, (0.9, 0.9, h_c * 0.72), T((math.cos(a) * (r_c + 1.18), math.sin(a) * (r_c + 1.18), z_c + h_c * 0.5)) @ R(a, 4, "Z"))

    # Massive chain-anchor brackets on front (-Y) and sides at Z = 68 & Z = 140 (where great chains attach!)
    for z_sh, r_sh in ((70.0, 7.8), (142.0, 5.4)):
        for ang in (-math.pi / 2, -math.pi / 4, -3 * math.pi / 4):
            m = R(ang, 4, "Z")
            box(metal, (3.2, 2.4, 3.6), m @ T((r_sh + 1.0, 0, z_sh)))
            ring_mesh(trim, 2.1, 0.52, 12, m @ T((r_sh + 2.8, 0, z_sh)) @ R(math.pi / 2, 4, "X"), tube_segs=5)

    # Diagonal backstay iron struts & heavy anchor chain down the +Y rear flank (matches guide image!)
    for sx in (-1, 1):
        strut(metal, (sx * 4.2, 8.8, 12.0), (sx * 2.4, 5.6, 70.0), 1.05)
        chain_run(trim, metal, (sx * 3.8, 9.4, 12.0), (sx * 2.2, 6.2, 68.0), link_h=2.4, link_w=1.45, thick=0.34)

    # Cantilevered iron Wardlight bracket arm projecting off the void side (-Y) at Z = 44 (well above deck)
    strut(metal, (0, -7.2, 44.0), (0, -13.2, 45.8), 0.72)
    strut(trim, (0, -7.2, 38.5), (0, -11.8, 45.2), 0.55)
    chain_run(trim, metal, (0, -13.0, 45.6), (0, -13.0, 39.2), link_h=1.4, link_w=0.85, thick=0.18)
    wardlight_cage(metal, trim, glow, T((0, -13.0, 37.2)), scale=1.35)

    # Top capstan-drum crown & towering iron needle finial (z = 178..214)
    cone(metal, 3.4, 4.2, 5.0, 8, T((0, 0, 178.0)) @ R(math.pi / 8, 4, "Z"))
    cyl_z(trim, 2.6, 7.5, (0, 0, 183.0), segs=12)
    ring_mesh(accent, 3.8, 0.45, 16, T((0, 0, 186.5)), tube_segs=5)
    for k in range(4):
        a = k * math.pi / 2
        strut(metal, (math.cos(a) * -5.8, math.sin(a) * -5.8, 186.5), (math.cos(a) * 5.8, math.sin(a) * 5.8, 186.5), 0.72)
    cone(metal, 2.8, 0.15, 24.0, 8, T((0, 0, 190.0)) @ R(math.pi / 8, 4, "Z"))


# -----------------------------------------------------------------------------------------------------------
# 2. GreatChainSegment — Straight colossal forged iron chain run (~32 studs long)
# -----------------------------------------------------------------------------------------------------------
@template("GreatChainSegment", METAL=2400, TRIM=1600)
def great_chain_segment(t):
    """A 32-stud-long colossal forged blackened-iron chain run along X with heavy studded coupler collars.
    Lowest point sits cleanly on z = 0."""
    metal, trim = (t.bm(r) for r in ("METAL", "TRIM"))
    pts = [(-16.0 + 32.0 * k / 8, 0.0, 1.55) for k in range(9)]
    great_chain_curve(metal, trim, pts, link_len=4.4, link_w=2.55, thick=0.68, segs=12)
    # Heavy clamped iron coupler collars at -8, 0, +8
    for cx in (-8.5, 8.5):
        cyl_x(trim, 1.75, 1.4, (cx, 0, 1.55), segs=10)
        ring_mesh(metal, 1.85, 0.28, 12, T((cx, 0, 1.55)) @ R(math.pi / 2, 4, "Y"), tube_segs=4)


# -----------------------------------------------------------------------------------------------------------
# 3. GreatChainCatenary — Sweeping catenary chain arc span (~55 studs long)
# -----------------------------------------------------------------------------------------------------------
@template("GreatChainCatenary", METAL=3200, TRIM=2200)
def great_chain_catenary(t):
    """A sweeping 55-stud-long catenary iron chain span along X: ends rise to Z = 15.5 while the middle
    dips cleanly down to z = 0.0 (so placing at Y_sag automatically puts the ends 15.5 studs higher!)."""
    metal, trim = (t.bm(r) for r in ("METAL", "TRIM"))
    span = 55.0
    sag = 14.0
    pts = []
    for k in range(17):
        f = k / 16.0 - 0.5  # -0.5..+0.5
        x = f * span
        # Parabolic catenary approximation; lowest outer surface reaches z = 0.0
        z = 1.55 + sag * ((2.0 * f) ** 2)
        pts.append((x, 0.0, z))
    great_chain_curve(metal, trim, pts, link_len=4.6, link_w=2.65, thick=0.70, segs=12)
    # Centre clevis shackle ring for hanging a Wardlight or coupling
    ring_mesh(trim, 1.75, 0.36, 12, T((0, 0, 1.65)) @ R(math.pi / 2, 4, "X"), tube_segs=4)


# -----------------------------------------------------------------------------------------------------------
# 4. KeystoneCage — Octagonal open-frame iron cage canopy & cradle for the Keystone deck (high clearance)
# -----------------------------------------------------------------------------------------------------------
@template("KeystoneCage", METAL=4200, TRIM=2800, STONE=1400, ACCENT=800, GLOW=900)
def keystone_cage(t):
    """The Keystone cage-platform canopy & cradle: four heavy cardinal iron buttress piers at (+-25, 0) and
    (0, +-21) leave all four diagonal bridge entries 100% open up to Z = 22, sweeping into a high octagonal
    barred iron cage crown (Z = 22..40) with massive diagonal chain-anchor brackets where the four colossal
    saltire chains converge, and the floor's brightest bone-white Wardlight hanging inside the upper cage."""
    metal, trim, stone, accent, glow = (t.bm(r) for r in ("METAL", "TRIM", "STONE", "ACCENT", "GLOW"))

    # Four cardinal heavy iron anchor piers (keeps all 4 diagonal bridge entries wide open!)
    cardinal = ((25.0, 0.0, 0.0), (-25.0, 0.0, math.pi), (0.0, 21.0, math.pi / 2), (0.0, -21.0, -math.pi / 2))
    for px, py, ang in cardinal:
        m = T((px, py, 0.0)) @ R(ang, 4, "Z")
        box(stone, (5.2, 7.6, 2.2), m @ T((0, 0, 1.1)), bevel=0.18)
        box(metal, (4.2, 6.2, 18.0), m @ T((0, 0, 11.2)), bevel=0.12)
        # Iron cage bars along the outer flank of each pier
        for by in (-2.0, 0.0, 2.0):
            strut(trim, m @ Vector((-2.15, by, 2.2)), m @ Vector((-2.15, by, 21.5)), 0.32)
        # Sweeping arch rib rising from pier top (Z=20) up to central octagonal crown ring (R=10, Z=33)
        rib_pts = [
            m @ Vector((0, 0, 19.5)),
            m @ Vector((-5.5, 0, 26.5)),
            m @ Vector((-12.5, 0, 31.2)),
            m @ Vector((-16.5, 0, 33.0)),
        ]
        tube(metal, rib_pts, [1.5, 1.35, 1.15, 0.95], 8, cap=True)
        # Curved iron cage slats flanking each rib
        for sy in (-1.8, 1.8):
            strut(trim, m @ Vector((-1.5, sy, 20.5)), m @ Vector((-14.5, sy * 0.7, 32.0)), 0.42)

    # Diagonal corner chain-anchor horns high overhead (Z = 24..28) so diagonal chains attach cleanly without
    # blocking the walk deck below!
    for sx in (-1, 1):
        for sy in (-1, 1):
            cx, cy = sx * 21.5, sy * 17.5
            strut(metal, (sx * 12.0, sy * 9.5, 29.5), (cx, cy, 24.5), 1.35)
            ring_mesh(trim, 2.0, 0.48, 12, T((cx, cy, 24.5)) @ R(math.atan2(sy, sx), 4, "Z") @ R(math.pi / 2, 4, "X"), tube_segs=5)

    # Octagonal upper iron cage crown & barred lantern turret (Z = 22..40)
    ring_mesh(metal, 11.5, 0.95, 16, T((0, 0, 32.5)), tube_segs=6)
    ring_mesh(trim, 8.2, 0.65, 16, T((0, 0, 36.2)), tube_segs=5)
    # Barred iron lantern cage suspended beneath the crown at Z = 23..32
    ring_mesh(trim, 5.2, 0.45, 12, T((0, 0, 23.2)), tube_segs=5)
    ring_mesh(trim, 5.2, 0.45, 12, T((0, 0, 31.6)), tube_segs=5)
    for k in range(12):
        a = 2 * math.pi * k / 12
        strut(metal, (math.cos(a) * 5.1, math.sin(a) * 5.1, 23.2), (math.cos(a) * 5.1, math.sin(a) * 5.1, 31.6), 0.30)
    # Brightest bone-white Wardlight burning inside the Keystone cage (Z = 25..29.5, clear above 22 studs!)
    wardlight_cage(metal, trim, glow, T((0, 0, 27.0)), scale=2.1)
    # Chained Crown finial crest atop the cage (Z = 36..41)
    cone(metal, 4.2, 0.45, 4.8, 8, T((0, 0, 36.2)))
    chained_crown_sigil(metal, trim, accent, T((0, 0, 41.2)), scale=0.95)


# -----------------------------------------------------------------------------------------------------------
# 5. HungBeadPlatform — Iron collar cradle & twin side suspension yokes for the four Bead decks
# -----------------------------------------------------------------------------------------------------------
@template("HungBeadPlatform", METAL=3200, TRIM=2400, STONE=1200, GLOW=500)
def hung_bead_platform(t):
    """Hung iron Bead cradle & overhead chain suspension frame (48x36 footprint, 29 studs tall): low dark
    iron curb brackets & side anchor shoes at X = +-22, Y = +-11 (leaving the NNW-SSE diagonal bridge route
    completely open!), rising via four heavy chain-stayed corner hangers to an overhead iron yoke beam at
    Z = 23..29 with a hanging bone-white Wardlight."""
    metal, trim, stone, glow = (t.bm(r) for r in ("METAL", "TRIM", "STONE", "GLOW"))

    # East & West heavy iron anchor shoes & vertical lattice piers at X = +-22 (clear of N-S diagonal bridges!)
    for sx in (-1, 1):
        px = sx * 22.0
        box(stone, (3.8, 18.0, 1.4), T((px, 0, 0.7)), bevel=0.14)
        box(metal, (2.6, 16.0, 2.2), T((px, 0, 2.0)), bevel=0.10)
        for sy in (-1, 1):
            py = sy * 6.8
            # Heavy corner shackle & vertical suspension chain rising to Z = 24
            ring_mesh(trim, 1.15, 0.28, 10, T((px, py, 3.2)) @ R(math.pi / 2, 4, "Y"), tube_segs=4)
            chain_run(metal, trim, (px, py, 3.6), (px * 0.88, py * 0.75, 24.5), link_h=2.2, link_w=1.35, thick=0.30)
            strut(metal, (px, py, 2.0), (px * 0.88, py * 0.75, 24.5), 0.55)
        # Side truss bracing bar between front and rear hanger
        box(trim, (1.6, 12.6, 1.1), T((px * 0.90, 0, 23.6)))

    # Overhead iron spreader arch spanning East-West at Z = 24..28 (clear >= 23 studs over deck!)
    arch_pts = [
        (-19.5, 0.0, 24.2),
        (-10.0, 0.0, 26.8),
        (0.0, 0.0, 27.8),
        (10.0, 0.0, 26.8),
        (19.5, 0.0, 24.2),
    ]
    tube(metal, arch_pts, [1.05, 1.15, 1.25, 1.15, 1.05], 8, cap=True)
    ring_mesh(trim, 1.65, 0.38, 12, T((0, 0, 28.4)) @ R(math.pi / 2, 4, "X"), tube_segs=4)
    # Hanging bone-white Wardlight at centre (Z = 22.8..25.5)
    chain_run(trim, metal, (0, 0, 27.2), (0, 0, 24.8), link_h=1.1, link_w=0.65, thick=0.14)
    wardlight_cage(metal, trim, glow, T((0, 0, 22.8)), scale=1.05)


# -----------------------------------------------------------------------------------------------------------
# 6. CatenarySpanDeck — Iron truss & chain-stayed underside span frame for catenary bridges
# -----------------------------------------------------------------------------------------------------------
@template("CatenarySpanDeck", METAL=2600, TRIM=2000, STONE=1200)
def catenary_span_deck(t):
    """A 26-stud-long, 15-stud-wide iron truss & chain-stayed underside span frame: dark basalt/iron deck
    cheek plates, inverted-arch iron keel trusses, transverse cross-girders, and side shackle lugs."""
    metal, trim, stone = (t.bm(r) for r in ("METAL", "TRIM", "STONE"))
    L, W, deck_z = 26.0, 15.0, 3.6

    # Inverted parabolic iron underside keel trusses on both sides (z = 0..deck_z)
    for sx in (-1, 1):
        rx = sx * (W * 0.44)
        keel_pts = []
        for k in range(9):
            f = k / 8.0 - 0.5
            y = f * L
            z = 0.35 + ((2.0 * f) ** 2) * (deck_z - 0.8)
            keel_pts.append((rx, y, z))
        tube(metal, keel_pts, [0.42] * len(keel_pts), 6, cap=True)
        # Top longitudinal edge girder
        box(metal, (1.1, L, 0.85), T((rx, 0, deck_z - 0.4)))
        box(trim, (0.55, L, 0.45), T((rx + sx * 0.45, 0, deck_z + 0.18)))
        # Vertical truss webs & diagonal struts
        for y in (-10.0, -5.0, 0.0, 5.0, 10.0):
            f = y / L
            kz = 0.35 + ((2.0 * f) ** 2) * (deck_z - 0.8)
            strut(trim, (rx, y, kz), (rx, y, deck_z - 0.4), 0.38)
        # Side chain-hanger shackle rings
        for sy in (-8.5, 8.5):
            ring_mesh(trim, 0.85, 0.22, 10, T((rx + sx * 0.65, sy, deck_z + 0.3)) @ R(math.pi / 2, 4, "Y"), tube_segs=4)

    # Transverse iron cross-girders & recessed dark grate under-deck
    for y in (-11.5, -5.8, 0.0, 5.8, 11.5):
        box(metal, (W * 0.90, 0.75, 0.70), T((0, y, deck_z - 0.55)))
    box(stone, (W - 2.0, L - 0.6, 0.42), T((0, 0, deck_z - 0.12)))


# -----------------------------------------------------------------------------------------------------------
# 7. ChainCapstanGreat — Massive seized iron windlass capstan drum with coiled chain & capstan bars
# -----------------------------------------------------------------------------------------------------------
@template("ChainCapstanGreat", METAL=3200, TRIM=2600, WOOD=1400, STONE=1200)
def chain_capstan_great(t):
    """Colossal seized iron windlass capstan drum (~18x16x13 studs, seen on the left cliff in Abyssal Throne
    48.jpg): heavy stone-and-iron A-frame cheek mounts, horizontal ribbed drum wrapped in thick chain coils,
    toothed ratchet wheel, and heavy ironwood-and-iron capstan lever bars."""
    metal, trim, wood, stone = (t.bm(r) for r in ("METAL", "TRIM", "WOOD", "STONE"))

    # Heavy bolted stone & iron sill bed (z = 0..1.6)
    box(stone, (17.5, 14.5, 1.4), T((0, 0, 0.7)), bevel=0.16)
    box(metal, (15.8, 12.8, 0.6), T((0, 0, 1.6)))

    # Twin heavy A-frame iron cheek standards at X = +-6.8
    for sx in (-1, 1):
        cx = sx * 6.8
        box(metal, (1.8, 9.6, 1.4), T((cx, 0, 2.5)))
        strut(metal, (cx, -4.0, 2.5), (cx, 0.0, 8.6), 1.45)
        strut(metal, (cx, 4.0, 2.5), (cx, 0.0, 8.6), 1.45)
        cyl_x(trim, 2.2, 2.4, (cx, 0.0, 8.4), segs=12)

    # Massive central horizontal iron axle & ribbed windlass drum (z = 8.4)
    cyl_x(metal, 1.25, 16.5, (0, 0, 8.4), segs=12)
    cyl_x(metal, 3.6, 11.4, (0, 0, 8.4), segs=18)
    for sx in (-1, 1):
        ring_mesh(trim, 4.6, 0.55, 18, T((sx * 5.2, 0, 8.4)) @ R(math.pi / 2, 4, "Y"), tube_segs=5)
        # Toothed iron ratchet gear wheel on each drum cheek
        for k in range(12):
            a = 2 * math.pi * k / 12
            box(trim, (0.7, 0.9, 1.1), T((sx * 5.5, math.cos(a) * 4.8, 8.4 + math.sin(a) * 4.8)) @ R(-a, 4, "X"))

    # Thick coiled forged iron chain wrapped 4 turns around the drum + trailing anchor chain to z = 0
    coil_pts = []
    for k in range(49):
        f = k / 48.0
        a = f * 4.0 * 2.0 * math.pi
        x = -3.8 + f * 7.6
        r = 4.25
        coil_pts.append((x, math.cos(a) * r, 8.4 + math.sin(a) * r))
    great_chain_curve(trim, metal, coil_pts, link_len=2.1, link_w=1.25, thick=0.34, segs=8)
    # Trailing chain anchored down to front-left sill
    chain_run(trim, metal, (-3.8, -4.2, 8.4), (-3.8, -6.5, 1.4), link_h=1.8, link_w=1.05, thick=0.26)

    # Heavy ironwood-and-iron capstan lever bars jutting through the drum hub
    for k in range(4):
        a = k * math.pi / 2 + 0.35
        for sx in (-3.2, 3.2):
            p0 = (sx, math.cos(a) * 2.0, 8.4 + math.sin(a) * 2.0)
            p1 = (sx, math.cos(a) * 6.4, 8.4 + math.sin(a) * 6.4)
            strut(wood, p0, p1, 0.52)
            box(metal, (0.68, 0.68, 0.68), T(p1))


# -----------------------------------------------------------------------------------------------------------
# 8. Counterweight — Colossal suspended blackened-iron counterweight cylinder & anchor hook
# -----------------------------------------------------------------------------------------------------------
@template("Counterweight", METAL=2400, TRIM=1800, STONE=900)
def counterweight(t):
    """Colossal suspended blackened-iron counterweight (~10x10x28 studs): forged iron bottom anchor hook
    resting on z = 0, massive banded cast-iron & obsidian weight drum, upper forged shackle bail and heavy
    suspension chain rising to Z = 28."""
    metal, trim, stone = (t.bm(r) for r in ("METAL", "TRIM", "STONE"))

    # Massive curved iron anchor hook at bottom (tip touches z = 0.0)
    hook_pts = [
        (0.0, 0.0, 5.2),
        (0.0, 0.0, 2.8),
        (0.8, 0.0, 1.0),
        (2.4, 0.0, 0.7),
        (3.5, 0.0, 2.0),
        (3.2, 0.0, 3.6),
    ]
    tube(trim, hook_pts, [0.95, 0.90, 0.82, 0.72, 0.55, 0.32], 8, cap=True)

    # Heavy cast-iron & obsidian counterweight cylinder (z = 4.8..19.2)
    cone(metal, 4.4, 4.8, 2.4, 12, T((0, 0, 4.8)))
    cone(stone, 4.6, 4.6, 9.6, 12, T((0, 0, 7.2)))
    cone(metal, 4.8, 3.4, 2.4, 12, T((0, 0, 16.8)))
    # Heavy iron hoop bands & vertical iron straps
    for z_b in (7.4, 11.8, 16.4):
        ring_mesh(trim, 4.85, 0.45, 16, T((0, 0, z_b)), tube_segs=5)
    for k in range(4):
        a = k * math.pi / 2
        box(metal, (1.1, 1.1, 11.8), T((math.cos(a) * 4.5, math.sin(a) * 4.5, 12.0)) @ R(a, 4, "Z"))

    # Top forged shackle bail & heavy vertical chain rising to Z = 28
    ring_mesh(trim, 1.65, 0.42, 12, T((0, 0, 20.6)) @ R(math.pi / 2, 4, "X"), tube_segs=5)
    chain_run(metal, trim, (0, 0, 21.8), (0, 0, 28.0), link_h=2.4, link_w=1.45, thick=0.34)


# -----------------------------------------------------------------------------------------------------------
# 9. GibbetLedgeCage — Wall-bolted iron cantilever bracket with dangling barred cage & Wardlight
# -----------------------------------------------------------------------------------------------------------
@template("GibbetLedgeCage", METAL=2400, TRIM=1800, STONE=900, GLOW=450)
def gibbet_ledge_cage(t):
    """Wall-bolted iron cantilever gibbet crane & dangling iron cage (seen along the void walls in Abyssal
    Throne 48.jpg): heavy stone-and-iron wall mounting plate at +Y, projecting triangular iron truss arm,
    suspended cylindrical barred iron gibbet cage (bottom resting cleanly at z = 0), and a hanging bone-white
    Wardlight lantern."""
    metal, trim, stone, glow = (t.bm(r) for r in ("METAL", "TRIM", "STONE", "GLOW"))

    # Heavy iron wall-anchor plate & gusset bracket on the back (+Y = +5.2)
    box(stone, (6.2, 2.2, 10.0), T((0, 5.2, 19.0)), bevel=0.15)
    box(metal, (5.0, 1.4, 9.0), T((0, 4.4, 19.0)))
    # Cantilever horizontal crane beam & angled knee brace
    box(metal, (1.6, 10.6, 1.8), T((0, 0.0, 23.2)))
    strut(trim, (0, 4.2, 15.2), (0, -3.6, 23.0), 1.05)
    # End shackle & dangling gibbet chain
    ring_mesh(trim, 0.85, 0.22, 10, T((0, -4.4, 21.8)) @ R(math.pi / 2, 4, "Y"), tube_segs=4)
    chain_run(trim, metal, (0, -4.4, 21.2), (0, -4.4, 12.0), link_h=1.8, link_w=1.05, thick=0.22)

    # Dangling cylindrical barred iron gibbet cage (z = 0..12.0, centred at (0, -4.4))
    cx, cy = 0.0, -4.4
    cone(metal, 0.25, 2.8, 1.6, 10, T((cx, cy, 0.0)))   # pointed bottom cap touching z = 0
    ring_mesh(trim, 2.85, 0.28, 14, T((cx, cy, 1.6)), tube_segs=4)
    ring_mesh(trim, 2.85, 0.28, 14, T((cx, cy, 6.0)), tube_segs=4)
    ring_mesh(trim, 2.85, 0.28, 14, T((cx, cy, 10.4)), tube_segs=4)
    cone(metal, 2.9, 0.45, 1.6, 10, T((cx, cy, 10.4)))
    for k in range(8):
        a = 2 * math.pi * k / 8
        strut(metal, (cx + math.cos(a) * 2.8, cy + math.sin(a) * 2.8, 1.6), (cx + math.cos(a) * 2.8, cy + math.sin(a) * 2.8, 10.4), 0.24)

    # Hanging pale bone-white Wardlight suspended off mid-arm
    chain_run(trim, metal, (0, -1.0, 22.4), (0, -1.0, 17.5), link_h=1.2, link_w=0.72, thick=0.16)
    wardlight_cage(metal, trim, glow, T((0, -1.0, 15.6)), scale=0.95)


# -----------------------------------------------------------------------------------------------------------
# 10. FarGatehouse — Monumental obsidian gatehouse with gold-rimmed Chained Crown sigil over the arch
# -----------------------------------------------------------------------------------------------------------
@template("FarGatehouse", STONE=4200, METAL=3200, TRIM=2400, SILK=1200, ACCENT=1200, GLOW=900)
def far_gatehouse(t):
    """Monumental obsidian Far Gatehouse (top-right of Abyssal Throne 48.jpg, adapted with bone-white
    Wardlights instead of orange flames): twin crenellated obsidian buttress towers flanking a 28-stud-wide
    arched portal with raised iron portcullis teeth, wine-crimson tattered flanking banners, twin rooftop
    Wardlight braziers, and the gold-rimmed Chained Crown sigil set proudly in the entablature over the arch."""
    stone, metal, trim, silk, accent, glow = (t.bm(r) for r in ("STONE", "METAL", "TRIM", "SILK", "ACCENT", "GLOW"))

    # Twin stepped obsidian flanking piers & crenellated buttress towers (clear central opening X = -14..+14)
    for sx in (-1, 1):
        px = sx * 21.0
        box(stone, (15.0, 15.0, 4.0), T((px, 0, 2.0)), bevel=0.25)
        box(stone, (13.2, 13.2, 42.0), T((px, 0, 25.0)), bevel=0.22)
        box(metal, (13.8, 13.8, 1.8), T((px, 0, 22.0)))
        box(metal, (13.8, 13.8, 2.2), T((px, 0, 45.5)))
        # Corner iron pilaster strips
        for cx in (-1, 1):
            for cy in (-1, 1):
                box(metal, (1.4, 1.4, 44.0), T((px + cx * 6.3, cy * 6.3, 24.0)))
        # Rooftop parapet merlons + bone-white Wardlight brazier (adapted from jpg's orange flames!)
        for mx in (-4.8, 0.0, 4.8):
            for my in (-5.6, 5.6):
                box(stone, (2.6, 2.2, 4.4), T((px + mx, my, 48.8)), bevel=0.12)
        cone(metal, 2.4, 3.4, 2.4, 8, T((px, 0, 46.8)))
        uvsphere(glow, 1.85, T((px, 0, 50.2)), 10, 8)
        # Flanking hanging Wardlights on front (-Y) tower face at Z = 18
        strut(metal, (px - sx * 5.8, -6.5, 18.0), (px - sx * 5.8, -10.2, 18.4), 0.45)
        wardlight_cage(metal, trim, glow, T((px - sx * 5.8, -10.0, 15.8)), scale=1.05)

        # Matte wine-crimson tattered Vahl banner hanging on outer flank (-Y face)
        bx = px + sx * 0.5
        box(metal, (6.2, 0.5, 0.5), T((bx, -7.2, 34.0)))
        box(silk, (5.2, 0.25, 16.0), T((bx, -7.3, 25.5)))
        for tip_x in (-1.6, 0.0, 1.6):
            cone(silk, 0.95, 0.05, 4.2, 4, T((bx + tip_x, -7.3, 17.5)) @ R(math.pi, 4, "X"))

    # High arched obsidian & iron portal span (clear height ~29 studs inside arch!)
    cz, R_arch = 16.5, 14.5
    segs = 18
    for k in range(segs):
        a = math.radians(10 + 160 * (k + 0.5) / segs)
        x = math.cos(a) * R_arch
        z = cz + math.sin(a) * R_arch
        seg_l = (math.pi * R_arch * 160 / 180) / segs + 0.4
        m = T((x, 0, z)) @ R(-a, 4, "Y")
        box(stone, (4.4, 11.2, seg_l), m)
        box(trim, (1.1, 11.8, seg_l * 0.98), m @ T((-2.1, 0, 0)))

    # Raised blackened-iron portcullis spikes tucked high inside the arch (Z = 25..31)
    box(metal, (24.0, 1.0, 1.4), T((0, 0, 27.5)))
    for kx in range(-10, 11, 2):
        strut(trim, (kx, 0, 24.8), (kx, 0, 31.0), 0.36)
        cone(trim, 0.32, 0.04, 1.2, 4, T((kx, 0, 24.8)) @ R(math.pi, 4, "X"))

    # Upper obsidian entablature gable & gold-rimmed Chained Crown crest (Z = 33..56)
    box(stone, (32.0, 12.0, 14.0), T((0, 0, 40.0)), bevel=0.25)
    box(metal, (33.5, 12.6, 2.0), T((0, 0, 47.2)))
    box(stone, (20.0, 10.0, 6.5), T((0, 0, 51.0)), bevel=0.2)
    chained_crown_sigil(metal, trim, accent, T((0, -6.4, 41.2)), scale=1.95)
    chained_crown_sigil(metal, trim, accent, T((0, 6.4, 41.2)), scale=1.95)


# -----------------------------------------------------------------------------------------------------------
# 11. HalfForgedLink — Colossal house-sized half-forged chain link on giant iron trestles (Crossing)
# -----------------------------------------------------------------------------------------------------------
@template("HalfForgedLink", METAL=3400, TRIM=2400, STONE=1400, WOOD=1200, GLOW=450)
def half_forged_link(t):
    """A colossal house-sized forged iron chain link (~24x14x17 studs) resting half-forged on giant iron-and-
    timber trestles in the Chainwright's Yard: one half closed and riveted, the other half split open for the
    hammer, flanked by giant smithing tongs, anvil block and a pale bone-white forge-lantern (zero orange)."""
    metal, trim, stone, wood, glow = (t.bm(r) for r in ("METAL", "TRIM", "STONE", "WOOD", "GLOW"))

    # Heavy timber & stone trestle cribs supporting the colossal link (z = 0..4.5)
    for sx in (-6.5, 6.5):
        box(stone, (4.2, 11.0, 1.6), T((sx, 0, 0.8)), bevel=0.14)
        box(wood, (3.2, 9.8, 2.4), T((sx, 0, 2.8)), bevel=0.10)
        box(metal, (3.4, 10.2, 0.7), T((sx, 0, 4.2)))

    # Colossal half-forged link tilted at 22 deg, resting on the trestles (lowest side at z = 4.2)
    lm = T((0, 0, 8.8)) @ R(math.radians(22), 4, "X")
    # Build two C-shaped halves leaving an open forge-weld gap on the front-right!
    pts_a = []
    for k in range(15):
        a = math.radians(25 + 245 * k / 14)
        pts_a.append(lm @ Vector((math.cos(a) * 10.2, math.sin(a) * 5.6, 0.0)))
    tube(metal, pts_a, [1.65] * len(pts_a), 10, cap=True)
    # Split open jaw ends with iron clamp collar
    for end_pt in (pts_a[0], pts_a[-1]):
        ring_mesh(trim, 1.85, 0.35, 10, T(end_pt) @ R(math.pi / 2, 4, "Y"), tube_segs=4)

    # Heavy smithing anvil block & colossal iron sledge resting at the foot (z = 0..5.2)
    box(stone, (5.2, 4.0, 2.0), T((0, -5.8, 1.0)), bevel=0.12)
    box(metal, (4.4, 3.2, 2.4), T((0, -5.8, 3.2)), bevel=0.12)
    # Colossal smithing hammer leaning against the anvil
    strut(wood, (2.6, -7.2, 0.2), (1.4, -4.4, 6.2), 0.55)
    box(metal, (3.2, 1.8, 1.8), T((1.3, -4.2, 6.4)) @ R(0.4, 4, "X"))
    # Hanging pale bone-white work-lamp on a trestle post
    strut(metal, (-8.0, -4.2, 3.2), (-8.0, -4.2, 11.2), 0.35)
    strut(metal, (-8.0, -4.2, 11.2), (-6.2, -5.5, 11.2), 0.28)
    wardlight_cage(metal, trim, glow, T((-6.2, -5.5, 9.2)), scale=0.88)


# -----------------------------------------------------------------------------------------------------------
# 12. AshGrateFloor — Heavy iron-bar grate frame over a recessed dark ash pit (The Ashgrate)
# -----------------------------------------------------------------------------------------------------------
@template("AshGrateFloor", METAL=2200, TRIM=1600, STONE=1200, MOSS=1400)
def ash_grate_floor(t):
    """Heavy octagonal/square iron-bar grate frame (~16x16x3.4 studs) over a recessed dark ash pit with
    mounded pale-grey ash drifts banked along the outer iron curb (for The Ashgrate)."""
    metal, trim, stone, moss = (t.bm(r) for r in ("METAL", "TRIM", "STONE", "MOSS"))

    # Recessed dark basalt pit pan & low outer iron curb
    box(stone, (15.6, 15.6, 0.8), T((0, 0, 0.4)))
    for sy in (-1, 1):
        box(metal, (16.4, 1.8, 2.0), T((0, sy * 7.3, 1.0)), bevel=0.12)
    for sx in (-1, 1):
        box(metal, (1.8, 12.8, 2.0), T((sx * 7.3, 0, 1.0)), bevel=0.12)
    # Corner bolted iron gusset plates
    for sx in (-1, 1):
        for sy in (-1, 1):
            box(trim, (2.6, 2.6, 2.3), T((sx * 7.2, sy * 7.2, 1.15)), bevel=0.1)

    # Heavy iron grate bars spanning across the pit
    for gx in range(-5, 6, 2):
        box(trim, (0.55, 13.0, 0.65), T((gx * 1.1, 0, 1.45)))
    for gy in (-4.2, 0.0, 4.2):
        box(metal, (13.0, 0.75, 0.85), T((0, gy, 1.15)))

    # Ash drifts pooled inside the pit and around the outer corners
    for k, (ax, ay, sx, sy, sz) in enumerate((
        (-2.2, 1.5, 4.8, 4.2, 1.1), (3.0, -2.0, 4.4, 3.8, 1.0),
        (-7.6, -6.2, 4.0, 3.6, 1.5), (7.6, 6.0, 4.2, 3.4, 1.4),
    )):
        ground_rock(moss, (sx, sy, sz), (ax, ay, 0.15), seed=4810 + k, roughness=0.28, subdiv=1)


# -----------------------------------------------------------------------------------------------------------
# 13. ChainBollard — Squat iron mooring bollard wrapped in heavy chain (Rim Walk & Quay)
# -----------------------------------------------------------------------------------------------------------
@template("ChainBollard", METAL=1600, TRIM=1400, STONE=900)
def chain_bollard(t):
    """Squat heavy iron mooring bollard (~5.8x5.8x7.6 studs) bolted to an octagonal obsidian plinth and
    wrapped in three tight turns of heavy forged iron chain."""
    metal, trim, stone = (t.bm(r) for r in ("METAL", "TRIM", "STONE"))

    cone(stone, 2.8, 2.5, 1.0, 8, T((0, 0, 0.0)) @ R(math.pi / 8, 4, "Z"))
    box(metal, (4.2, 4.2, 0.55), T((0, 0, 1.25)), bevel=0.08)
    lathe(metal, [(1.55, 1.5), (1.25, 2.6), (1.20, 5.2), (1.65, 6.2), (1.45, 7.2), (0.6, 7.6)], 12, Matrix.Identity(4))
    # Cross mooring horn pin
    cyl_x(trim, 0.45, 4.2, (0, 0, 5.8), segs=10)
    # 3 wraps of heavy chain coiled around the bollard waist
    coil_pts = []
    for k in range(31):
        f = k / 30.0
        a = f * 3.0 * 2.0 * math.pi
        coil_pts.append((math.cos(a) * 1.65, math.sin(a) * 1.65, 2.0 + f * 2.8))
    great_chain_curve(trim, metal, coil_pts, link_len=1.45, link_w=0.88, thick=0.24, segs=8)


# -----------------------------------------------------------------------------------------------------------
# 14. HookPulleyRack — Iron gantry frame with chain hoists, double pulleys & hanging reaver hooks
# -----------------------------------------------------------------------------------------------------------
@template("HookPulleyRack", METAL=2400, TRIM=1800, STONE=800, GLOW=350)
def hook_pulley_rack(t):
    """Iron gantry rack for The Hookward (~14x7x14 studs): bolted stone-and-iron A-frame gantry holding an
    overhead pulley beam with twin iron sheaves, hanging chain hoists, three oversized barbed iron reaver hooks,
    and a pale bone-white Wardlight."""
    metal, trim, stone, glow = (t.bm(r) for r in ("METAL", "TRIM", "STONE", "GLOW"))

    # Twin A-frame iron gantry uprights at X = +-6.0
    for sx in (-1, 1):
        gx = sx * 6.0
        box(stone, (2.2, 5.8, 0.9), T((gx, 0, 0.45)), bevel=0.1)
        strut(metal, (gx, -2.2, 0.8), (gx, 0.0, 12.6), 0.72)
        strut(metal, (gx, 2.2, 0.8), (gx, 0.0, 12.6), 0.72)
        strut(trim, (gx, -1.3, 5.5), (gx, 1.3, 5.5), 0.45)

    # Overhead cross-beam & pulley rail (z = 12.6)
    box(metal, (14.4, 1.4, 1.2), T((0, 0, 12.6)), bevel=0.08)
    box(trim, (14.8, 1.6, 0.4), T((0, 0, 13.4)))

    # 3 chain hoists with spoked pulley wheels & heavy hanging curved hooks (lowest hook touches z = 1.8)
    for idx, hx in enumerate((-3.4, 0.0, 3.4)):
        drop_z = 3.2 if idx == 1 else 4.6
        # Pulley housing & wheel
        box(trim, (1.2, 1.8, 1.8), T((hx, 0, 11.4)))
        cyl_y(metal, 0.75, 0.45, (hx, 0, 11.3), segs=12)
        chain_run(trim, metal, (hx, 0, 10.6), (hx, 0, drop_z + 1.8), link_h=1.35, link_w=0.82, thick=0.18)
        # Heavy curved reaver hook
        h_pts = [
            (hx, 0.0, drop_z + 1.8),
            (hx, 0.0, drop_z + 0.5),
            (hx + 0.7, 0.0, drop_z - 0.5),
            (hx + 1.4, 0.0, drop_z - 0.1),
            (hx + 1.3, 0.0, drop_z + 0.9),
        ]
        tube(metal, h_pts, [0.28, 0.28, 0.25, 0.20, 0.08], 6, cap=True)

    # Pale bone-white Wardlight hung off the left gantry shoulder
    strut(metal, (-6.2, -0.4, 12.2), (-7.6, -1.6, 12.2), 0.25)
    wardlight_cage(metal, trim, glow, T((-7.6, -1.6, 10.4)), scale=0.78)


# -----------------------------------------------------------------------------------------------------------
# 15. VoidPoolMesh — Sculpted undulating abyssal void energy disc with concentric violet vortex ripples
# -----------------------------------------------------------------------------------------------------------
@template("VoidPoolMesh", STONE=1200, ALT=1800, CRYSTAL=1800, GLOW=1200)
def void_pool_mesh(t):
    """Sculpted undulating abyssal void Undertow energy disc (~72x72x4.5 studs, placed deep on the void
    floor at Y = -9.5, 17-31+ studs below every walk surface): dark basalt-void outer rim, sculpted concentric
    swirling vortex wave ridges in deep violet, and glowing Undertow energy ribs."""
    stone, alt, crystal, glow = (t.bm(r) for r in ("STONE", "ALT", "CRYSTAL", "GLOW"))

    # Base abyssal dark sheet standing on z = 0.0
    cone(stone, 36.0, 34.5, 0.65, 32, T((0, 0, 0.0)))
    cone(alt, 31.0, 29.8, 0.95, 28, T((0, 0, 0.45)))

    # Concentric undulating violet vortex ripple rings & spiral arms rising smoothly to z = 4.2
    for r_ring, z_ring, th, bm in (
        (26.5, 1.3, 0.85, crystal),
        (19.5, 1.8, 0.75, alt),
        (13.0, 2.3, 0.65, crystal),
        (7.2, 2.8, 0.55, glow),
    ):
        pts = []
        for k in range(29):
            a = 2 * math.pi * k / 28
            wave = math.sin(a * 4.0) * 0.45
            pts.append((math.cos(a) * r_ring, math.sin(a) * r_ring, z_ring + wave))
        tube(bm, pts, [th] * len(pts), 6, cap=False)

    # 3 sweeping spiral Undertow energy currents flowing across the vortex
    for arm in range(3):
        pts = []
        for k in range(18):
            f = k / 17.0
            a = arm * (2 * math.pi / 3) + f * 3.4
            rr = 2.5 + f * 29.5
            zz = 3.6 - f * 2.2 + math.sin(f * 6.0) * 0.35
            pts.append((math.cos(a) * rr, math.sin(a) * rr, zz))
        tube(glow if arm == 0 else crystal, pts, [0.55 * (1.0 - 0.35 * (k / 17.0)) for k in range(18)], 5, cap=True)
    uvsphere(glow, 2.4, T((0, 0, 2.4)) @ Matrix.Diagonal((1.0, 1.0, 0.45, 1.0)), 12, 6)


def apply_abyssal_preview_materials(kit):
    """Tint Blender Workbench materials to the Abyssal Throne palette so preview PNGs read clearly."""
    for obj in kit.all_objects:
        if obj.type != "MESH" or "__" not in obj.name:
            continue
        role = obj.name.rsplit("__", 1)[-1]
        rgba = ABYSSAL_PREVIEW_COLORS.get(role)
        if not rgba:
            continue
        mat_name = f"AbyssalPreview_{role}"
        mat = bpy.data.materials.get(mat_name)
        if mat is None:
            mat = bpy.data.materials.new(mat_name)
            mat.diffuse_color = rgba
        obj.data.materials.clear()
        obj.data.materials.append(mat)


if __name__ == "__main__":
    kit, manifest = build_kit("AbyssalF48Kit", F48_TEMPLATES, DEFAULT_BUDGET)
    apply_abyssal_preview_materials(kit)
    export_kit(kit, manifest, OUT_DIR, "AbyssalF48Kit")
    render_previews(kit, F48_TEMPLATES, OUT_DIR)
    print(json.dumps(manifest, indent=2))
