"""
Abyssal Throne Floor 46 (Abyssal Descent) sculpted assets, generated in headless Blender.

Inspired by the Abyssal Descent reference art (reference/Abyssal Throne 46.jpg) and the Vahl / Undertow
ecosystem (docs/prompts/abyssal-throne-floor-layouts-prompt.md):
where the dark first catches what falls from the Archive above. A colossal violet Upfall column pouring upward
into the black vault behind the Apex; forged iron-grate ChainFordSpans and ChainPostIron bollards with the
Chained Crown sigil; three sizes of sculpted dark basalt EyotSlabs; ReavingRack of hooked blades and torn
wine half-cape; VahlGibbetCage gallows and ExecutionBlock with notched Dreadguard cleaver; WeirOfHooks
spanning the channel to comb Archive debris; FallenStackWreck shattered ebony bookcases half-buried in ash;
ObsidianGeodeSplit exposing dark blood-red Trench Geode crystal; WardlightCage black-iron posts holding
pale bone-white flames; ChainedCrownKeystone carved with the Chained Crown and one broken link; and sculpted
UndertowRibbon void-river bed ribbons.

1 Blender unit = 1 stud, standing on z = 0, front facing -Y in Blender / +Z in Roblox, one mesh object
per colour role named "<Template>__<ROLE>". Every piece stands on its origin.

Roles (AbyssalFloor46 passes the Vahl override; no new colour roles):
    STONE    dark obsidian / basalt          ALT      bone-white marble & pages
    METAL    blackened iron                  TRIM     dark chain-iron
    SILK     deep wine crimson silk          ACCENT   old gold (Chained Crown rim)
    GLOW     pale bone-white Wardlight       CRYSTAL  blood-red geode / void Undertow
    MOSS     grey-black ash                  WOOD     dark charred ebony shelving

Outputs (assets-source/tower/abyssal_f46_kit/):
    AbyssalF46Kit.blend, AbyssalF46Kit.fbx, manifest.json, previews/kit_sheet_1.png, previews/tiles/*.png.

Run:
    blender.exe --background --factory-startup --python tools/blender/generate_abyssal_f46_kit.py
"""
import bpy, bmesh, math, os, json, runpy, random
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT_DIR = os.path.join(ROOT, "assets-source", "tower", "abyssal_f46_kit")

# Shared primitives and kit pipeline from Floor 21, Floor 26, and Floor 41 generators.
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
ground_rock, centred_rock, slab_stone = f26["ground_rock"], f26["centred_rock"], f26["slab_stone"]
chain_run = f41["chain_run"]
build_kit, export_kit, render_previews = f21["build_kit"], f21["export_kit"], f21["render_previews"]

T = Matrix.Translation
R = Matrix.Rotation

DEFAULT_BUDGET = 3500
F46_TEMPLATES = {}

# Vahl Abyssal Workbench preview colours (Studio strips materials and tints per role via TowerKitProps).
VAHL_PREVIEW_COLORS = {
    "STONE": (0.09, 0.08, 0.12, 1.0),    # dark obsidian / basalt
    "ALT": (0.88, 0.85, 0.78, 1.0),      # bone-white marble & pages
    "METAL": (0.14, 0.13, 0.16, 1.0),    # blackened iron
    "TRIM": (0.24, 0.23, 0.27, 1.0),     # dark chain-iron
    "SILK": (0.46, 0.08, 0.14, 1.0),     # deep wine crimson silk
    "ACCENT": (0.72, 0.56, 0.24, 1.0),   # aged gold
    "GLOW": (0.96, 0.93, 0.86, 1.0),     # bone-white Wardlight
    "CRYSTAL": (0.55, 0.08, 0.12, 1.0),  # blood-red geode crystal
    "MOSS": (0.24, 0.22, 0.26, 1.0),     # grey-black ash
    "WOOD": (0.15, 0.10, 0.08, 1.0),     # charred ebony shelving
}


def template(name, **budget):
    def deco(fn):
        F46_TEMPLATES[name] = (fn, budget)
        return fn
    return deco


# -----------------------------------------------------------------------------------------------------------
# Shared Vahl motifs: Chained Crown sigil, hooked blades, hanging Wardlight cage head, draped silk banners
# -----------------------------------------------------------------------------------------------------------
def chained_crown_sigil(trim, accent, mat, scale=1.0):
    """The Vahl sigil: a three-spiked crown inside a ring of iron chain links with one broken link at the bottom."""
    s = scale
    # Chain ring of 12 alternating links, leaving gap at bottom (-Z) for the broken link.
    n_links = 12
    ring_r = 1.85 * s
    for k in range(n_links):
        ang = -math.pi / 2 + 2 * math.pi * k / n_links
        cx = math.cos(ang) * ring_r
        cz = math.sin(ang) * ring_r
        if k == 0:
            # The broken link at the bottom: aged gold, snapped open.
            for sx in (-1, 1):
                box(accent, (0.34 * s, 0.24 * s, 0.28 * s), mat @ T((sx * 0.26 * s, 0, -ring_r)) @ R(sx * 0.35, 4, "Y"))
            continue
        m = mat @ T((cx, 0, cz)) @ R(-ang + math.pi / 2, 4, "Y") @ R(math.pi / 2 if k % 2 else 0, 4, "Z")
        ring_mesh(trim, 0.34 * s, 0.10 * s, 8, m @ R(math.pi / 2, 4, "X"), tube_segs=4)

    # Crown inside the ring: band + 3 sharp iron/gold spikes.
    box(accent, (1.85 * s, 0.28 * s, 0.38 * s), mat @ T((0, 0, -0.45 * s)))
    for sx, h_sp in ((-0.72, 1.15), (0.0, 1.55), (0.72, 1.15)):
        cone(accent, 0.24 * s, 0.03 * s, h_sp * s, 4, mat @ T((sx * s, 0, -0.28 * s)) @ R(math.pi / 4, 4, "Z"))
        uvsphere(accent, 0.14 * s, mat @ T((sx * s, 0, (-0.28 + h_sp) * s)), 6, 4)


def hooked_reaver_blade(metal, trim, alt, mat, length=4.8, scale=1.0):
    """Hooked Abyss Reaver blade with dark tang, spine rib, and pale honed edge."""
    s = scale
    L = length * s
    # Tang & pommel ring.
    cyl_z(metal, 0.12 * s, 0.9 * s, (0, 0, 0), segs=6) if mat == Matrix.Identity(4) else None
    box(metal, (0.20 * s, 0.20 * s, 1.0 * s), mat @ T((0, 0, 0.5 * s)))
    ring_mesh(trim, 0.22 * s, 0.06 * s, 8, mat @ R(math.pi / 2, 4, "X"), tube_segs=4)
    # Crossguard.
    box(trim, (1.15 * s, 0.28 * s, 0.24 * s), mat @ T((0, 0, 1.05 * s)))
    # Straight spine & honed edge.
    box(metal, (0.36 * s, 0.14 * s, L * 0.72), mat @ T((0, 0, 1.15 * s + L * 0.36)))
    box(alt, (0.14 * s, 0.10 * s, L * 0.72), mat @ T((0.22 * s, 0, 1.15 * s + L * 0.36)))
    # Curved reaving hook tip.
    hook_z = 1.15 * s + L * 0.72
    box(metal, (0.48 * s, 0.14 * s, L * 0.24), mat @ T((0.16 * s, 0, hook_z + L * 0.10)) @ R(0.42, 4, "Y"))
    cone(alt, 0.22 * s, 0.02 * s, 0.75 * s, 4, mat @ T((0.46 * s, 0, hook_z + L * 0.16)) @ R(1.15, 4, "Y"))


def wardlight_head(metal, trim, glow, mat, scale=1.0):
    """Hanging black-iron Wardlight lantern cage with a faceted pale bone-white flame core."""
    s = scale
    # Suspension ring & peaked iron hood.
    ring_mesh(trim, 0.30 * s, 0.07 * s, 10, mat @ T((0, 0, 1.05 * s)) @ R(math.pi / 2, 4, "X"), tube_segs=4)
    cone(metal, 0.92 * s, 0.14 * s, 0.85 * s, 6, mat @ T((0, 0, 0.15 * s)))
    # Lower spiked base cup.
    cone(metal, 0.12 * s, 0.74 * s, 0.75 * s, 6, mat @ T((0, 0, -1.75 * s)))
    # 6 vertical iron cage bars.
    for k in range(6):
        a = 2 * math.pi * k / 6
        strut(trim, mat @ Vector((math.cos(a) * 0.68 * s, math.sin(a) * 0.68 * s, -1.05 * s)),
              mat @ Vector((math.cos(a) * 0.82 * s, math.sin(a) * 0.82 * s, 0.18 * s)), 0.09 * s)
    ring_mesh(trim, 0.78 * s, 0.07 * s, 12, mat @ T((0, 0, -0.45 * s)), tube_segs=4)
    # Pale bone-white flame core inside cage.
    cone(glow, 0.36 * s, 0.04 * s, 1.15 * s, 5, mat @ T((0, 0, -0.92 * s)))
    uvsphere(glow, 0.34 * s, mat @ T((0, 0, -0.78 * s)), 8, 6)


def hanging_cage_body(metal, trim, mat, rad=1.85, height=5.8):
    """Empty barred octagonal iron gibbet cage suspended at mat."""
    # Top conical cap & suspension loop.
    ring_mesh(trim, 0.42, 0.10, 10, mat @ T((0, 0, height * 0.5 + 0.85)) @ R(math.pi / 2, 4, "X"), tube_segs=4)
    cone(metal, rad * 1.02, 0.25, 1.1, 8, mat @ T((0, 0, height * 0.5 - 0.1)))
    # Top, middle, bottom iron hoop bands.
    for z_ring, r_ring in ((height * 0.5 - 0.15, rad), (0.0, rad * 1.05), (-height * 0.5 + 0.15, rad * 0.92)):
        ring_mesh(trim, r_ring, 0.14, 16, mat @ T((0, 0, z_ring)), tube_segs=5)
    # Bottom floor plate & tapered spike.
    cone(metal, rad * 0.90, rad * 0.90, 0.28, 8, mat @ T((0, 0, -height * 0.5)))
    cone(metal, 0.45, 0.04, 1.35, 6, mat @ T((0, 0, -height * 0.5)) @ R(math.pi, 4, "X"))
    # 8 vertical cage bars.
    for k in range(8):
        a = 2 * math.pi * k / 8
        strut(metal, mat @ Vector((math.cos(a) * rad * 0.92, math.sin(a) * rad * 0.92, -height * 0.5 + 0.15)),
              mat @ Vector((math.cos(a) * rad, math.sin(a) * rad, height * 0.5 - 0.15)), 0.11)


# -----------------------------------------------------------------------------------------------------------
# 1. UpfallColumn — Colossal swirling violet/void upward column (>= 155 studs tall, standing on z = 0)
# -----------------------------------------------------------------------------------------------------------
@template("UpfallColumn", STONE=3800, TRIM=1600, METAL=1400, CRYSTAL=3600, GLOW=2600)
def upfall_column(t):
    """The Upfall: a 166-stud soaring column of violet void pouring straight upward into the black vault,
    anchored on z = 0 by jagged dark basalt spire collars bound in iron chain-bands, with spiraling crystal
    void streams, rising obsidian shard ribs, and upper swirling void glow above z = 78."""
    stone, trim, metal, crystal, glow = (t.bm(r) for r in ("STONE", "TRIM", "METAL", "CRYSTAL", "GLOW"))
    rng = random.Random(4601)

    # Grounded dark basalt basin collar & spire teeth at z = 0..28 (standing firmly on z = 0).
    cone(stone, 22.0, 16.5, 6.0, 14, T((0, 0, 0.0)))
    cone(stone, 16.5, 11.5, 10.0, 12, T((0, 0, 5.5)))
    for k in range(10):
        a = 2 * math.pi * k / 10 + 0.15
        r_base = 17.5 + rng.uniform(-1.5, 2.2)
        spire_h = 20.0 + (k % 3) * 7.5
        tilt = 0.16 + (k % 2) * 0.08
        m = T((math.cos(a) * r_base, math.sin(a) * r_base, 0.0)) @ R(a, 4, "Z") @ R(-tilt, 4, "Y")
        cone(stone, 4.4, 0.35, spire_h, 5, m)
        if k % 2 == 0:
            cone(trim, 2.2, 0.25, spire_h * 0.65, 4, m @ T((-1.2, 0, 2.0)))

    # Heavy iron binding rings & chain straps clasping the basal spire collar.
    for z_band, r_band in ((7.5, 16.8), (15.5, 13.6)):
        ring_mesh(metal, r_band, 0.68, 20, T((0, 0, z_band)), tube_segs=6)
        ring_mesh(trim, r_band + 0.45, 0.32, 20, T((0, 0, z_band + 1.1)), tube_segs=4)

    # Central void river column pouring UPWARD from z = 2 to z = 166 (flaring softly near the top).
    # Lower/mid body uses CRYSTAL (translucent violet glass, NOT Neon, keeping < 78 studs telegraph-safe!).
    profile = [
        (8.5, 2.0), (10.2, 16.0), (8.6, 36.0), (7.8, 62.0),
        (8.8, 92.0), (11.6, 126.0), (16.4, 156.0), (20.0, 166.0),
    ]
    lathe(crystal, profile, 18, Matrix.Identity(4), cap_bottom=True, cap_top=False)

    # 5 helical void-river ribbons spiraling upward from z = 6 to z = 165.
    for s_idx in range(5):
        a0 = 2 * math.pi * s_idx / 5
        pts = []
        rads = []
        for step in range(28):
            frac = step / 27.0
            z = 6.0 + frac * 159.0
            r_env = 10.6 - 2.2 * math.sin(frac * math.pi * 0.65) + frac * frac * 10.5
            ang = a0 + frac * 4.4
            pts.append((math.cos(ang) * r_env, math.sin(ang) * r_env, z))
            rads.append(1.15 - 0.35 * math.sin(frac * math.pi) + frac * 0.45)
        tube(crystal, pts, rads, 6, cap=True)

    # Upper luminous GLOW core & spiraling sky ribbons ONLY above z = 78 (>= 30 studs above Apex!).
    upper_profile = [(3.4, 78.0), (4.6, 102.0), (6.5, 130.0), (9.8, 156.0), (13.0, 166.0)]
    lathe(glow, upper_profile, 14, Matrix.Identity(4), cap_bottom=True, cap_top=False)
    for g_idx in range(4):
        a0 = 2 * math.pi * g_idx / 4 + 0.4
        pts = []
        rads = []
        for step in range(16):
            frac = step / 15.0
            z = 78.0 + frac * 88.0
            r_env = 8.4 + frac * 10.2
            ang = a0 + frac * 2.8
            pts.append((math.cos(ang) * r_env, math.sin(ang) * r_env, z))
            rads.append(0.65 + frac * 0.45)
        tube(glow, pts, rads, 5, cap=True)

    # Rising fractured obsidian shard ribs floating/caught in the upward current (z = 26..152).
    for k in range(18):
        frac = (k + 0.5) / 18.0
        z = 24.0 + frac * 126.0
        ang = k * 1.38
        rad = 11.2 + frac * 7.8 + rng.uniform(-1.0, 1.2)
        h_shard = 6.5 + (k % 3) * 3.8
        w_shard = 1.6 + (k % 2) * 0.8
        m = T((math.cos(ang) * rad, math.sin(ang) * rad, z)) @ R(ang, 4, "Z") @ R(0.18, 4, "Y")
        cone(stone if k % 3 else trim, w_shard, 0.18, h_shard, 5, m)


# -----------------------------------------------------------------------------------------------------------
# 2. ChainFordSpan — Forged iron-grate ford span with side chain rails
# -----------------------------------------------------------------------------------------------------------
@template("ChainFordSpan", METAL=1800, TRIM=1600, STONE=900, ALT=600)
def chain_ford_span(t):
    """A firm black-iron chain-ford bridge deck: twin I-beam side girders, transverse iron grate slats,
    bone-white marble curb trim, and sagging iron side chain rails between corner stanchions. 14x24x6.5."""
    metal, trim, stone, alt = (t.bm(r) for r in ("METAL", "TRIM", "STONE", "ALT"))
    w, length = 14.0, 24.0
    # Side iron box girders & bone-white marble edge curbs.
    for sx in (-1, 1):
        box(metal, (1.1, length, 1.4), T((sx * (w * 0.5 - 0.6), 0, 0.7)))
        box(alt, (0.55, length - 0.6, 0.35), T((sx * (w * 0.5 - 1.35), 0, 1.32)))
        # Under-deck cross-brackets.
        for sy in (-8.5, 0.0, 8.5):
            box(stone, (1.4, 1.6, 1.0), T((sx * (w * 0.5 - 0.7), sy, 0.5)))

    # Transverse iron grate bars & central longitudinal spine (firm walk deck at z = 1.15).
    box(metal, (1.2, length, 0.65), T((0, 0, 0.75)))
    for k in range(13):
        y = -length * 0.48 + k * (length * 0.96 / 12)
        box(trim, (w - 2.2, 0.85, 0.42), T((0, y, 0.95)))
    for sx in (-3.2, 3.2):
        box(metal, (0.55, length, 0.35), T((sx, 0, 0.92)))

    # Corner & mid stanchion posts with sagging side chain rails.
    for sx in (-1, 1):
        px = sx * (w * 0.5 - 0.55)
        for py in (-length * 0.44, 0.0, length * 0.44):
            box(metal, (0.85, 0.85, 5.4), T((px, py, 3.4)))
            cone(trim, 0.58, 0.12, 0.9, 4, T((px, py, 6.1)) @ R(math.pi / 4, 4, "Z"))
        for y0, y1 in ((-length * 0.44, 0.0), (0.0, length * 0.44)):
            pts = []
            for step in range(9):
                f = step / 8.0
                yy = y0 + (y1 - y0) * f
                sag = 1.05 * 4 * f * (1 - f)
                pts.append((px, yy, 5.1 - sag))
            tube(trim, pts, [0.18] * len(pts), 5, cap=True)


# -----------------------------------------------------------------------------------------------------------
# 3. ChainPostIron — Heavy forged iron bollard post with Chained Crown ring & Wardlight bracket
# -----------------------------------------------------------------------------------------------------------
@template("ChainPostIron", METAL=1200, TRIM=1200, ACCENT=700, GLOW=400)
def chain_post_iron(t):
    """Heavy forged iron bollard post (~4.4x4.4x11.5): stepped octagonal plinth, fluted iron bollard shaft,
    raised Chained Crown sigil medallion on front, and a side Wardlight lantern bracket."""
    metal, trim, accent, glow = (t.bm(r) for r in ("METAL", "TRIM", "ACCENT", "GLOW"))
    # Stepped iron plinth standing on z = 0.
    cone(metal, 2.2, 1.9, 1.4, 8, T((0, 0, 0)) @ R(math.pi / 8, 4, "Z"))
    cone(trim, 1.65, 1.45, 1.2, 8, T((0, 0, 1.4)) @ R(math.pi / 8, 4, "Z"))
    # Bollard shaft & mushroom cap.
    lathe(metal, [(1.15, 2.6), (0.98, 5.5), (1.28, 7.2), (1.05, 8.6), (1.42, 9.2), (0.65, 10.2), (0.15, 11.2)], 10, Matrix.Identity(4))
    ring_mesh(trim, 1.32, 0.22, 14, T((0, 0, 7.2)), tube_segs=5)
    # Chained Crown sigil medallion mounted on the front (-Y).
    chained_crown_sigil(trim, accent, T((0, -1.25, 5.2)), scale=0.45)
    # Overhanging side bracket arm & small Wardlight lantern head.
    strut(metal, (0.8, 0, 7.8), (2.2, 0, 9.4), 0.24)
    strut(trim, (0.8, 0, 6.2), (2.0, 0, 9.0), 0.16)
    wardlight_head(metal, trim, glow, T((2.2, 0, 8.0)), scale=0.65)


# -----------------------------------------------------------------------------------------------------------
# 4, 5, 6. EyotSlabS / M / L — Three sizes of dark sculpted basalt eyot rock slab skirts
# -----------------------------------------------------------------------------------------------------------
def _build_eyot_slab(t, width, depth, height, seed):
    """Dark sculpted basalt rock slab skirt standing cleanly on z = 0, flat-topped with stepped sheer
    obsidian facets, bone-white marble edge trim blocks, and grey-black ash crust."""
    stone, alt, moss = (t.bm(r) for r in ("STONE", "ALT", "MOSS"))
    rng = random.Random(seed)
    rx, ry = width * 0.5, depth * 0.5

    # Central stepped basalt mesa body (lens-shaped elongation along Y).
    lathe(stone, [(0.82, 0.0), (0.94, height * 0.35), (1.00, height * 0.78), (0.96, height)],
          14, Matrix.Diagonal((rx, ry, 1.0, 1.0)))

    # Craggy basalt apron buttresses ringing the skirt (all grounded at z = 0).
    n_crags = 12
    for k in range(n_crags):
        a = 2 * math.pi * k / n_crags + rng.uniform(-0.1, 0.1)
        px = math.cos(a) * rx * rng.uniform(0.76, 0.94)
        py = math.sin(a) * ry * rng.uniform(0.76, 0.94)
        ch = height * rng.uniform(0.55, 0.92)
        cw = width * rng.uniform(0.16, 0.24)
        cd = depth * rng.uniform(0.14, 0.22)
        ground_rock(stone, (cw, cd, ch), (px, py, 0.0), seed=seed + k * 7, roughness=0.22, subdiv=1)

    # Bone-white marble flagstone trim fragments along the upper rim + ash crust mounds.
    for k in range(6):
        a = 2 * math.pi * k / 6 + 0.35
        px = math.cos(a) * rx * 0.76
        py = math.sin(a) * ry * 0.76
        slab_stone(alt, (width * 0.16, depth * 0.11, 1.1), (px, py, height - 0.3), rot_z=a, seed=seed + 100 + k)
        ground_rock(moss, (width * 0.18, depth * 0.14, 1.2), (px * 0.92, py * 0.92, height - 0.5), seed=seed + 200 + k, roughness=0.28, subdiv=1)


@template("EyotSlabS", STONE=1800, ALT=600, MOSS=500)
def eyot_slab_s(t):
    """Small dark sculpted basalt eyot rock slab skirt (~28x32x14)."""
    _build_eyot_slab(t, 28.0, 32.0, 14.0, seed=4611)


@template("EyotSlabM", STONE=2200, ALT=700, MOSS=600)
def eyot_slab_m(t):
    """Medium dark sculpted basalt eyot rock slab skirt (~44x50x16)."""
    _build_eyot_slab(t, 44.0, 50.0, 16.0, seed=4622)


@template("EyotSlabL", STONE=2600, ALT=800, MOSS=700)
def eyot_slab_l(t):
    """Large dark sculpted basalt eyot rock slab skirt (~62x70x18)."""
    _build_eyot_slab(t, 62.0, 70.0, 18.0, seed=4633)


# -----------------------------------------------------------------------------------------------------------
# 7. ReavingRack — Iron weapon rack of hooked blades, whetstone & torn wine half-cape
# -----------------------------------------------------------------------------------------------------------
@template("ReavingRack", METAL=1400, TRIM=1200, SILK=700, STONE=700, ALT=500)
def reaving_rack(t):
    """Abyss Reaver weapon rack (~11x5x10.5): forged iron A-frame holding 4 hooked reaver blades,
    a stone whetstone trough at one flank, and a tattered deep-wine silk half-cape draped over the rail."""
    metal, trim, silk, stone, alt = (t.bm(r) for r in ("METAL", "TRIM", "SILK", "STONE", "ALT"))
    # Basalt footing blocks.
    for sx in (-4.2, 4.2):
        box(stone, (2.2, 3.6, 0.8), T((sx, 0, 0.4)), bevel=0.08)
        # Iron A-frame uprights.
        strut(metal, (sx, -1.2, 0.8), (sx, 0.0, 8.8), 0.36)
        strut(metal, (sx, 1.2, 0.8), (sx, 0.0, 8.8), 0.36)
    # Crossbars & spiked finials.
    cyl_x(trim, 0.24, 9.6, (0, 0, 8.5), segs=10)
    cyl_x(metal, 0.20, 8.8, (0, 0, 3.4), segs=8)
    for sx in (-4.8, 4.8):
        cone(trim, 0.38, 0.04, 1.4, 4, T((sx, 0, 8.6)))

    # 4 hooked reaver twin-blades racked along the beam.
    for k in range(4):
        bx = -2.7 + k * 1.8
        m = T((bx, -0.35, 1.6)) @ R(math.radians(-10 if k % 2 == 0 else 8), 4, "X") @ R(0.08 * (k - 1.5), 4, "Z")
        hooked_reaver_blade(metal, trim, alt, m, length=5.6, scale=1.0)

    # Stone whetstone trough beside the left post.
    box(stone, (2.4, 2.2, 1.6), T((-5.8, -0.6, 0.8)), bevel=0.1)
    cyl_y(alt, 0.85, 0.75, (-5.8, -0.6, 2.2), segs=14)
    cyl_x(trim, 0.14, 1.6, (-5.8, -0.6, 2.2), segs=6)

    # Tattered deep-wine silk half-cape draped over the right end of the rack.
    box(silk, (2.2, 0.22, 4.4), T((4.8, -0.8, 6.2)) @ R(0.18, 4, "X") @ R(0.12, 4, "Z"))
    box(silk, (1.8, 0.22, 3.6), T((5.1, 0.6, 6.6)) @ R(-0.15, 4, "X"))


# -----------------------------------------------------------------------------------------------------------
# 8. VahlGibbetCage — Tall iron gallows post with suspended empty iron gibbet cage
# -----------------------------------------------------------------------------------------------------------
@template("VahlGibbetCage", METAL=1800, TRIM=1200, STONE=700, ALT=400, SILK=500)
def vahl_gibbet_cage(t):
    """Tall black-iron gallows post (~7x11x22) with heavy stone socket base, angled jib arm,
    iron chain suspending an empty barred iron gibbet cage clear above the ground, and tattered wine pennant."""
    metal, trim, stone, alt, silk = (t.bm(r) for r in ("METAL", "TRIM", "STONE", "ALT", "SILK"))
    # Stone footing plinth & iron collar standing on z = 0.
    cone(stone, 2.8, 2.3, 1.8, 6, T((0, 2.6, 0.0)))
    box(metal, (1.8, 1.8, 1.2), T((0, 2.6, 2.2)))
    # Tall iron upright post & top spike.
    box(metal, (1.15, 1.15, 19.2), T((0, 2.6, 11.4)))
    cone(trim, 0.72, 0.05, 2.0, 4, T((0, 2.6, 20.8)) @ R(math.pi / 4, 4, "Z"))
    # Forward jib arm (-Y) & diagonal knee brace.
    box(metal, (0.95, 7.6, 0.95), T((0, -0.8, 19.6)))
    strut(trim, (0, 2.4, 14.8), (0, -2.4, 19.5), 0.55)
    # Chain & empty iron gibbet cage hung at y = -3.8, z = 11.8 (bottom spike clears z = 7.4).
    chain_run(trim, metal, (0, -3.8, 19.3), (0, -3.8, 15.6), link_h=1.1, link_w=0.7, thick=0.14)
    hanging_cage_body(metal, trim, T((0, -3.8, 11.8)), rad=1.85, height=5.8)
    # Bone skull trophy & tattered wine pennant on the post.
    uvsphere(alt, 0.45, T((0, 1.75, 15.2)), 8, 6)
    box(silk, (0.18, 2.4, 4.6), T((0.65, 2.6, 16.5)) @ R(0.12, 4, "Y"))


# -----------------------------------------------------------------------------------------------------------
# 9. ExecutionBlock — Heavy obsidian & iron execution block with notched cleaver & chain
# -----------------------------------------------------------------------------------------------------------
@template("ExecutionBlock", STONE=1500, METAL=1400, TRIM=900, ALT=400, SILK=400)
def execution_block(t):
    """Dreadguard execution block (~9x8x8.5): stepped obsidian dais, iron-strapped dark chopping block,
    heavy notched Dreadguard executioner's cleaver-axe wedged in the top, wrist shackles, and wine cloth."""
    stone, metal, trim, alt, silk = (t.bm(r) for r in ("STONE", "METAL", "TRIM", "ALT", "SILK"))
    # Stepped obsidian dais on z = 0.
    box(stone, (8.6, 7.6, 1.0), T((0, 0, 0.5)), bevel=0.12)
    box(stone, (6.4, 5.8, 1.0), T((0, 0.2, 1.5)), bevel=0.10)
    # Sloped iron-banded chopping block.
    cone(stone, 2.4, 1.95, 2.6, 8, T((0, 0.3, 2.0)) @ R(math.pi / 8, 4, "Z"))
    ring_mesh(metal, 2.25, 0.24, 16, T((0, 0.3, 2.7)), tube_segs=5)
    ring_mesh(metal, 2.02, 0.22, 16, T((0, 0.3, 4.1)), tube_segs=5)
    # Heavy Dreadguard cleaver-axe wedged upright into the block.
    axe_m = T((0.4, 0.1, 4.4)) @ R(math.radians(16), 4, "Y") @ R(math.radians(-12), 4, "X")
    box(metal, (0.35, 3.4, 2.6), axe_m @ T((0, 0, 1.1)))
    box(alt, (0.16, 3.6, 0.85), axe_m @ T((0, 0, -0.05)))
    strut(trim, axe_m @ Vector((0, 0.5, 0.8)), axe_m @ Vector((0, 0.5, 4.6)), 0.30)
    # Iron wrist shackles & short chain bolted to the dais front.
    for sx in (-2.4, 2.4):
        ring_mesh(trim, 0.48, 0.12, 10, T((sx, -2.6, 1.25)), tube_segs=4)
        chain_run(trim, metal, (sx, -2.6, 1.25), (sx * 0.75, -1.2, 2.2), link_h=0.8, link_w=0.5, thick=0.10)
    # Tattered wine-silk cloth scrap draped off one edge.
    box(silk, (2.2, 1.8, 0.22), T((-2.6, -1.8, 1.12)) @ R(0.25, 4, "Z"))


# -----------------------------------------------------------------------------------------------------------
# 10. WeirOfHooks — Forged iron weir arch hung with great dredge-hooks and caught Archive debris
# -----------------------------------------------------------------------------------------------------------
@template("WeirOfHooks", METAL=1800, TRIM=1600, STONE=900, SILK=600, ALT=700)
def weir_of_hooks(t):
    """Forged iron Weir of Hooks (~22x7x15): twin obsidian & iron piers bridged by a heavy spiked iron beam
    hung with 5 colossal curved dredge-hooks on chains, snagging Archive timbers, pages, and wine cloth."""
    metal, trim, stone, silk, alt = (t.bm(r) for r in ("METAL", "TRIM", "STONE", "SILK", "ALT"))
    # Twin stepped stone & iron buttress piers.
    for sx in (-1, 1):
        px = sx * 9.5
        box(stone, (3.6, 5.2, 3.0), T((px, 0, 1.5)), bevel=0.12)
        box(metal, (2.6, 3.8, 9.5), T((px, 0, 7.6)))
        cone(trim, 1.6, 0.25, 2.4, 4, T((px, 0, 12.4)) @ R(math.pi / 4, 4, "Z"))
    # Heavy horizontal iron weir beam & upper truss brace.
    box(metal, (21.6, 2.2, 1.6), T((0, 0, 11.4)))
    box(trim, (20.4, 2.6, 0.45), T((0, 0, 12.4)))
    for k in range(7):
        cone(trim, 0.28, 0.03, 1.4, 4, T((-7.5 + k * 2.5, 0, 12.6)))

    # 5 great iron dredge-hooks hanging down on chains across the span.
    for k in range(5):
        hx = -6.4 + k * 3.2
        hz = 5.4 + (k % 2) * 1.4
        chain_run(trim, metal, (hx, 0, 10.6), (hx, 0, hz + 1.8), link_h=1.0, link_w=0.65, thick=0.13)
        # Curved hook shank & barb.
        hook_pts = [
            (hx, 0, hz + 1.8), (hx, 0, hz + 0.4), (hx + 0.45, -0.35, hz - 0.5),
            (hx + 1.2, -0.5, hz - 0.1), (hx + 1.1, -0.35, hz + 0.8),
        ]
        tube(metal, hook_pts, [0.28, 0.26, 0.24, 0.18, 0.08], 6, cap=True)

    # Caught Archive debris snagged on the middle hooks (fallen timbers, pages, wine cloth).
    box(stone, (5.2, 1.8, 0.65), T((-1.2, -0.4, 5.8)) @ R(0.22, 4, "Y") @ R(0.18, 4, "Z"))
    for k in range(4):
        box(alt, (1.5, 1.1, 0.12), T((-2.4 + k * 1.6, -0.7, 5.2 + (k % 2) * 0.8)) @ R(0.35 * k, 4, "X") @ R(0.4 * k, 4, "Z"))
    box(silk, (2.6, 0.22, 3.8), T((3.2, -0.5, 6.4)) @ R(-0.22, 4, "Y"))


# -----------------------------------------------------------------------------------------------------------
# 11. FallenStackWreck — Shattered Halcyr ebony bookcase & spilled books/pages half-buried in ash
# -----------------------------------------------------------------------------------------------------------
@template("FallenStackWreck", WOOD=1800, ALT=1200, ACCENT=700, STONE=800, MOSS=900)
def fallen_stack_wreck(t):
    """Shattered Halcyr ebony bookcase & spilled books/pages half-buried in ash (~14x11x6.5): broken
    shelf carcass lying tilted in grey-black ash drift, brass corner mounts, spilled tomes & scattered pages."""
    wood, alt, accent, stone, moss = (t.bm(r) for r in ("WOOD", "ALT", "ACCENT", "STONE", "MOSS"))
    rng = random.Random(4615)

    # Ash drift & basalt scree bed grounded at z = 0.
    ground_rock(moss, (13.6, 10.4, 2.2), (0, 0, 0.0), seed=4616, roughness=0.28, subdiv=2)
    ground_rock(stone, (6.5, 5.4, 2.4), (-3.2, 1.5, 0.0), seed=4617, roughness=0.22, subdiv=1)

    # Tilted shattered ebony bookcase frame half-sunk in the ash (open shelves facing upward/forward).
    cm = T((-0.6, 0.4, 3.25)) @ R(math.radians(-68), 4, "X") @ R(math.radians(-16), 4, "Z")
    box(wood, (10.2, 0.65, 6.2), cm @ T((0, 1.1, 0)))
    for sx in (-4.8, 4.8):
        box(wood, (0.65, 2.4, 6.2), cm @ T((sx, 0, 0)))
    for sz in (-2.4, 0.0, 2.4):
        box(wood, (9.4, 2.1, 0.45), cm @ T((0, 0, sz)))
    box(accent, (10.6, 2.6, 0.55), cm @ T((0, 0, 3.1)))

    # Broken shelf plank snapped off forward.
    box(wood, (6.8, 1.8, 0.45), T((3.4, -2.6, 1.1)) @ R(0.32, 4, "Z") @ R(-0.18, 4, "X"))

    # Spilled Halcyr tomes & drifts of pale vellum pages (ALT).
    for k in range(7):
        bx = -3.8 + k * 1.25 + rng.uniform(-0.3, 0.3)
        by = -2.4 + (k % 3) * 1.1
        bz = 1.1 + (k % 2) * 0.45
        m_book = T((bx, by, bz)) @ R(rng.uniform(-0.6, 0.6), 4, "Z") @ R(rng.uniform(-0.2, 0.2), 4, "X")
        box(wood if k % 2 == 0 else accent, (1.5, 1.1, 0.42), m_book)
        box(alt, (1.35, 0.95, 0.28), m_book @ T((0.05, 0, 0)))
    for k in range(14):
        px = rng.uniform(-5.4, 5.4)
        py = rng.uniform(-4.6, 3.6)
        pz = 0.75 + rng.uniform(0.0, 0.55)
        box(alt, (1.25, 0.92, 0.08), T((px, py, pz)) @ R(rng.uniform(0, math.pi), 4, "Z") @ R(rng.uniform(-0.14, 0.14), 4, "X"))


# -----------------------------------------------------------------------------------------------------------
# 12. ObsidianGeodeSplit — Cracked black obsidian boulder revealing dark blood-red crystal core
# -----------------------------------------------------------------------------------------------------------
@template("ObsidianGeodeSplit", STONE=1800, CRYSTAL=1600, TRIM=700, MOSS=600)
def obsidian_geode_split(t):
    """Abyssal Trench Geode (~9.5x8.5x7.5): cracked dark obsidian boulder split open in a V-cleft to
    expose a faceted blood-red crystal core inside, ringed with grey-black ash crust."""
    stone, crystal, trim, moss = (t.bm(r) for r in ("STONE", "CRYSTAL", "TRIM", "MOSS"))
    rng = random.Random(4619)

    # Ash & obsidian cradle on z = 0.
    ground_rock(moss, (9.2, 8.2, 1.5), (0, 0, 0.0), seed=4620, roughness=0.25, subdiv=1)

    # Two split jagged obsidian boulder halves angled outward around the open geode cavity.
    for sx in (-1, 1):
        m_half = T((sx * 2.25, 0.3, 0.2)) @ R(sx * 0.28, 4, "Y") @ R(-0.12, 4, "X")
        rock_m = m_half @ T((0, 0, 0))
        centred_rock(stone, (4.8, 6.4, 6.2), rock_m @ T((0, 0, 3.1)), seed=4621 + sx, roughness=0.24, subdiv=2)
        box(trim, (1.2, 4.8, 5.2), m_half @ T((-sx * 1.55, -0.4, 2.8)))

    # Exposed cluster of sharp blood-red crystal shards growing inside the cleft.
    for k in range(11):
        ang = rng.uniform(-math.pi * 0.85, math.pi * 0.85)
        r_off = rng.uniform(0.0, 1.45)
        px = math.sin(ang) * r_off * 0.9
        py = math.cos(ang) * r_off * 1.1 - 0.3
        h_cry = rng.uniform(2.2, 4.8) if k > 0 else 5.2
        rad = rng.uniform(0.45, 0.82)
        tilt_x = rng.uniform(-0.35, 0.15)
        tilt_y = px * 0.22
        m_c = T((px, py, 1.4)) @ R(tilt_x, 4, "X") @ R(tilt_y, 4, "Y") @ R(ang, 4, "Z")
        cone(crystal, rad, rad * 0.72, h_cry * 0.55, 6, m_c)
        cone(crystal, rad * 0.72, 0.03, h_cry * 0.45, 6, m_c @ T((0, 0, h_cry * 0.55)))


# -----------------------------------------------------------------------------------------------------------
# 13. WardlightCage — Black-iron post & swinging iron cage housing a pale bone-white flame
# -----------------------------------------------------------------------------------------------------------
@template("WardlightCage", METAL=1300, TRIM=1000, STONE=600, GLOW=500)
def wardlight_cage(t):
    """Vahl Wardlight post (~4.2x5.5x13.5): dark obsidian socket plinth, curved leaning wrought-iron post,
    iron chain suspending a barred hexagonal iron cage with a pale bone-white flame core."""
    metal, trim, stone, glow = (t.bm(r) for r in ("METAL", "TRIM", "STONE", "GLOW"))
    # Obsidian socket plinth on z = 0.
    cone(stone, 1.9, 1.4, 1.4, 6, T((0, 0.6, 0.0)))
    box(metal, (1.4, 1.4, 1.0), T((0, 0.6, 1.8)))
    # Curved leaning wrought-iron standard rising to z = 13.2.
    pts = [(0, 0.6, 2.2), (0, 0.5, 6.2), (0, -0.2, 9.8), (0, -1.6, 12.4), (0, -2.6, 13.1)]
    tube(metal, pts, [0.42, 0.36, 0.30, 0.26, 0.22], 8, cap=True)
    # Decorative iron scroll brace under the crook.
    strut(trim, (0, 0.2, 8.2), (0, -1.7, 12.2), 0.22)
    ring_mesh(trim, 0.55, 0.09, 10, T((0, -0.8, 10.6)) @ R(math.pi / 2, 4, "Y"), tube_segs=4)
    # Chain & hanging Wardlight lantern head at y = -2.6, z = 9.4.
    chain_run(trim, metal, (0, -2.6, 13.0), (0, -2.6, 10.8), link_h=0.9, link_w=0.55, thick=0.10)
    wardlight_head(metal, trim, glow, T((0, -2.6, 9.4)), scale=1.0)


# -----------------------------------------------------------------------------------------------------------
# 14. ChainedCrownKeystone — Monolithic obsidian keystone carved with the Chained Crown + broken link
# -----------------------------------------------------------------------------------------------------------
@template("ChainedCrownKeystone", STONE=1800, ALT=900, METAL=1200, TRIM=1200, ACCENT=900, SILK=600)
def chained_crown_keystone(t):
    """Monolithic obsidian Chained Crown keystone (~12x7x17): bone-white marble plinth, tapered dark
    obsidian keystone stele bound by heavy iron side chains, raised aged-gold Chained Crown with one broken
    link on its front face, and wine-silk oath ribbons at the flanks."""
    stone, alt, metal, trim, accent, silk = (t.bm(r) for r in ("STONE", "ALT", "METAL", "TRIM", "ACCENT", "SILK"))
    # Bone-white marble plinth standing on z = 0.
    box(alt, (11.6, 6.8, 1.4), T((0, 0, 0.7)), bevel=0.14)
    box(stone, (10.2, 5.8, 1.2), T((0, 0, 2.0)), bevel=0.12)
    # Tapered obsidian keystone monolith (z = 2.6..16.8).
    cone(stone, 4.6, 5.4, 14.2, 4, T((0, 0, 2.6)) @ R(math.pi / 4, 4, "Z") @ Matrix.Diagonal((1.05, 0.58, 1.0, 1.0)))
    # Top iron keystone cap & finial.
    box(metal, (8.4, 4.8, 1.1), T((0, 0, 16.4)), bevel=0.12)
    cone(trim, 1.1, 0.06, 2.0, 4, T((0, 0, 16.95)) @ R(math.pi / 4, 4, "Z"))
    # Flanking iron chain anchors & taut iron chains binding the monolith.
    for sx in (-1, 1):
        box(metal, (1.4, 3.6, 2.2), T((sx * 4.9, 0, 3.6)))
        chain_run(trim, metal, (sx * 4.8, 0, 4.6), (sx * 4.3, 0, 15.8), link_h=1.2, link_w=0.8, thick=0.15)
        # Wine-silk oath ribbon tied at flank.
        box(silk, (0.28, 1.3, 4.8), T((sx * 4.95, -0.8, 9.6)) @ R(sx * 0.08, 4, "Y"))
    # Carved Chained Crown sigil relief on the front face (-Y).
    chained_crown_sigil(trim, accent, T((0, -2.35, 10.6)), scale=1.25)


# -----------------------------------------------------------------------------------------------------------
# 15. UndertowRibbon — Sculpted undulating void-river bed ribbon mesh with raised side ripples
# -----------------------------------------------------------------------------------------------------------
@template("UndertowRibbon", CRYSTAL=1600, GLOW=1200, STONE=900)
def undertow_ribbon(t):
    """Sculpted undulating void-river Undertow ribbon mesh (~18x42x2.2, z = 0..2.2): dark basalt bed edge
    curbs, undulating sinusoidal void-current surface, and braided raised side ripple ridges."""
    crystal, glow, stone = (t.bm(r) for r in ("CRYSTAL", "GLOW", "STONE"))
    w, length = 16.0, 42.0
    nx, ny = 8, 22

    # Undulating braided ribbon surface grid (CRYSTAL).
    grid = []
    for iy in range(ny + 1):
        fy = iy / ny
        y = -length * 0.5 + fy * length
        row = []
        for ix in range(nx + 1):
            fx = ix / nx - 0.5
            x = fx * w + math.sin(fy * math.pi * 2.0) * 1.1
            z = 0.45 + 0.35 * math.sin(fy * math.pi * 4.0 + fx * 3.0) + (abs(fx) * 0.4)
            row.append(crystal.verts.new((x, y, z)))
        grid.append(row)
    for iy in range(ny):
        for ix in range(nx):
            crystal.faces.new((grid[iy][ix], grid[iy][ix + 1], grid[iy + 1][ix + 1], grid[iy + 1][ix]))

    # Braided raised side ripple ridges & central luminous current thread (GLOW).
    for sx, phase in ((-0.36, 0.0), (0.0, 1.4), (0.36, 2.8)):
        pts = []
        rads = []
        for iy in range(21):
            fy = iy / 20.0
            y = -length * 0.5 + fy * length
            x = sx * w + math.sin(fy * math.pi * 2.0 + phase) * 1.35
            z = 0.85 + 0.45 * math.sin(fy * math.pi * 4.0 + phase)
            pts.append((x, y, z))
            rads.append(0.32 if sx == 0 else 0.42)
        tube(glow, pts, rads, 5, cap=True)

    # Low dark basalt bank-edge stones grounding the ribbon at z = 0..1.4.
    for sx in (-1, 1):
        for k in range(5):
            y = -16.0 + k * 8.0
            x = sx * (w * 0.5 + 0.6) + math.sin(k * 1.1) * 0.6
            ground_rock(stone, (3.2, 6.2, 1.3), (x, y, 0.0), seed=4650 + k + sx, roughness=0.24, subdiv=1)


def apply_vahl_preview_materials(kit):
    """Tint Blender Workbench materials to the Vahl Abyssal palette so preview PNGs read clearly."""
    for obj in kit.all_objects:
        if obj.type != "MESH" or "__" not in obj.name:
            continue
        role = obj.name.rsplit("__", 1)[-1]
        rgba = VAHL_PREVIEW_COLORS.get(role)
        if not rgba:
            continue
        mat_name = f"VahlPreview_{role}"
        mat = bpy.data.materials.get(mat_name)
        if mat is None:
            mat = bpy.data.materials.new(mat_name)
            mat.diffuse_color = rgba
        obj.data.materials.clear()
        obj.data.materials.append(mat)


if __name__ == "__main__":
    kit, manifest = build_kit("AbyssalF46Kit", F46_TEMPLATES, DEFAULT_BUDGET)
    apply_vahl_preview_materials(kit)
    export_kit(kit, manifest, OUT_DIR, "AbyssalF46Kit")
    render_previews(kit, F46_TEMPLATES, OUT_DIR)
    print(json.dumps(manifest, indent=2))
