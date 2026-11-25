"""
Abyssal Throne Floor 49 (Dreadguard Citadel) sculpted assets, generated in headless Blender.

Inspired by the Dreadguard Citadel reference art (Abyssal Throne 49.jpg) and the Vahl/Dreadguard
fortress ecosystem (docs/prompts/abyssal-throne-floor-layouts-prompt.md):
a bastioned obsidian-and-iron star fort rising around a central moated Dreadguard Keep. Towering
over the pointed Ravelin and the covered way's iron-stake palisades rises the 244-stud square
DreadguardKeepTower (with battered corner buttresses, the Chained Crown sigil, the Overlord's empty
sword-niche, and iron spire); twin iron-banded drawbridge gatehouses and chained gate towers carrying
the floor's only lit bone-white Wardlights; arrow-head StarBastionSalients with sentry bartizans;
crenellated CurtainWallCrenels with caged void shards and ShutteredWardlights (dark iron, unlit);
a blind RavelinPortcullis leading nowhere; Bastion of Hooks' SiegeHookCrane; Bastion of Axes'
ExecutionYardSet; Dread Bastions' hanging PenitentCages; North Bastion's GreatIronBell;
Countermine's MineWindingGear; Inner Ward ArmourStandPlates; and hulking DreadguardSentry statues.

1 Blender unit = 1 stud, standing on z = 0, front facing -Y in Blender / +Z in Roblox, one mesh object
per colour role named "<Template>__<ROLE>". Every piece stands on its origin.

Roles (AbyssalFloor49 passes a Dreadguard iron-night override; no new colour roles):
    STONE    obsidian / dark basalt masonry    ALT      bone-white marble trim & coping
    METAL    blackened iron                    TRIM     dark iron strapping, chains & bars
    SILK     matte wine-crimson silk           ACCENT   old gold (Chained Crown rim, clasps)
    GLOW     bone-white Wardlight flame        CRYSTAL  caged void shard (low-emission violet)
    WOOD     weathered dark siege timber       MOSS     pale grey ash

Outputs (assets-source/tower/abyssal_f49_kit/):
    AbyssalF49Kit.blend, AbyssalF49Kit.fbx, manifest.json, previews/kit_sheet_1.png, previews/tiles/*.png.

Run:
    blender.exe --background --factory-startup --python tools/blender/generate_abyssal_f49_kit.py
"""
import bpy, bmesh, math, os, json, runpy, random
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT_DIR = os.path.join(ROOT, "assets-source", "tower", "abyssal_f49_kit")

# Shared primitives and kit pipeline from Floors 21, 26 & 41 only.
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
F49_TEMPLATES = {}

ABYSSAL_PREVIEW_COLORS = {
    "STONE": (0.14, 0.15, 0.20, 1.0),    # obsidian masonry
    "ALT": (0.82, 0.80, 0.76, 1.0),      # bone-white marble trim
    "METAL": (0.20, 0.22, 0.27, 1.0),    # blackened iron
    "TRIM": (0.11, 0.12, 0.16, 1.0),     # dark iron & chain
    "SILK": (0.46, 0.09, 0.14, 1.0),     # matte wine crimson silk
    "ACCENT": (0.68, 0.56, 0.30, 1.0),   # old gold (sparingly)
    "GLOW": (0.96, 0.93, 0.87, 1.0),     # bone-white Wardlight
    "CRYSTAL": (0.48, 0.30, 0.68, 1.0),  # caged void shard
    "WOOD": (0.18, 0.14, 0.13, 1.0),     # dark siege timber
    "MOSS": (0.38, 0.40, 0.46, 1.0),     # pale grey ash
}


def template(name, **budget):
    def deco(fn):
        F49_TEMPLATES[name] = (fn, budget)
        return fn
    return deco


# -----------------------------------------------------------------------------------------------------------
# Shared Vahl & Dreadguard motifs: Chained Crown sigil, crenellations, Wardlights, banners, spikes
# -----------------------------------------------------------------------------------------------------------
def chained_crown_sigil(metal, trim, accent, mat, scale=1.0):
    """The Vahl sigil: a three-spiked iron-and-gold crown inside a ring of chain with one broken link at bottom."""
    s = scale
    # Chain ring with a deliberate gap at the bottom (-Z) for the broken link.
    n_links = 12
    for k in range(n_links):
        a = -math.pi * 0.5 + (2 * math.pi) * k / n_links
        if k == 0:
            continue  # broken oath link at bottom
        lx = math.cos(a) * 2.1 * s
        lz = math.sin(a) * 2.1 * s
        rot_y = -a + (math.pi / 2 if k % 2 == 1 else 0.0)
        m = mat @ T((lx, 0, lz)) @ R(rot_y, 4, "Y") @ Matrix.Diagonal((0.42 * s, 0.25 * s, 0.65 * s, 1.0))
        ring_mesh(trim if k % 2 == 0 else metal, 1.0, 0.16, 10, m, tube_segs=4)
    # Broken link ends flanking the bottom gap.
    for sx in (-1, 1):
        box(accent, (0.36 * s, 0.28 * s, 0.55 * s), mat @ T((sx * 0.52 * s, 0, -2.05 * s)) @ R(sx * 0.45, 4, "Y"))
    # Central iron & old-gold crown inside the ring.
    box(metal, (2.2 * s, 0.38 * s, 0.65 * s), mat @ T((0, 0, -0.55 * s)))
    box(accent, (2.35 * s, 0.44 * s, 0.22 * s), mat @ T((0, 0, -0.82 * s)))
    for sx, h_sp in ((-0.82, 1.25), (0.0, 1.65), (0.82, 1.25)):
        cone(metal, 0.32 * s, 0.04 * s, h_sp * s, 4, mat @ T((sx * s, 0, -0.25 * s)) @ R(math.pi / 4, 4, "Z"))
        uvsphere(accent, 0.16 * s, mat @ T((sx * s, 0, (-0.25 + h_sp) * s)), 6, 4)


def banner_hang(metal, silk, trim, mat, w=2.2, h=7.5):
    """Iron crossbar with spiked finial and long tapered matte wine-crimson banner facing -Y."""
    cone(metal, 0.14, 0.14, w + 0.9, 8, mat @ T((-(w + 0.9) * 0.5, 0, 0)) @ R(math.pi / 2, 4, "Y"))
    for sx in (-1, 1):
        cone(trim, 0.22, 0.03, 0.55, 4, mat @ T((sx * (w * 0.5 + 0.55), 0, 0)) @ R(-sx * math.pi / 2, 4, "Y"))
    # Upper body + lower split swallowtail points.
    box(silk, (w, 0.16, h * 0.68), mat @ T((0, -0.08, -h * 0.34)))
    for sx in (-1, 1):
        box(silk, (w * 0.42, 0.15, h * 0.32), mat @ T((sx * w * 0.26, -0.08, -h * 0.80)) @ R(sx * 0.08, 4, "Y"))
    box(trim, (w + 0.08, 0.20, 0.24), mat @ T((0, -0.08, -0.22)))


def wardlight_cage(metal, trim, glow, mat, scale=1.0, lit=True):
    """Blackened-iron Wardlight lantern cage. When lit=True, holds a bone-white flame; when lit=False, shuttered dark."""
    s = scale
    # Top suspension ring & peaked hood.
    ring_mesh(trim, 0.34 * s, 0.08 * s, 10, mat @ T((0, 0, 1.45 * s)) @ R(math.pi / 2, 4, "X"), tube_segs=4)
    cone(metal, 0.88 * s, 0.14 * s, 0.65 * s, 4, mat @ T((0, 0, 0.72 * s)) @ R(math.pi / 4, 4, "Z"))
    cone(metal, 0.18 * s, 0.76 * s, 0.50 * s, 4, mat @ T((0, 0, -1.25 * s)) @ R(math.pi / 4, 4, "Z"))
    for k in range(4):
        a = k * math.pi / 2 + math.pi / 4
        cx, cy = math.cos(a) * 0.66 * s, math.sin(a) * 0.66 * s
        strut(trim, (mat @ Vector((cx, cy, -0.78 * s))), (mat @ Vector((cx, cy, 0.74 * s))), 0.11 * s)
    if lit and glow is not None:
        cone(glow, 0.38 * s, 0.05 * s, 1.05 * s, 6, mat @ T((0, 0, -0.45 * s)))
        uvsphere(glow, 0.34 * s, mat @ T((0, 0, -0.35 * s)), 8, 6)
    else:
        # Solid shuttered iron plates closing every face.
        for k in range(4):
            a = k * math.pi / 2
            box(trim, (0.95 * s, 0.14 * s, 1.32 * s), mat @ R(a, 4, "Z") @ T((0, -0.52 * s, -0.02 * s)))
        box(metal, (1.12 * s, 1.12 * s, 0.24 * s), mat @ T((0, 0, -0.05 * s)))


def crenel_row(stone, alt, x0, x1, y, z, width=2.4, depth=1.6, height=2.4, step=4.4):
    """Row of crenellated obsidian merlons with bone-white marble coping caps along X."""
    span = x1 - x0
    n = max(1, int(span / step))
    for k in range(n + 1):
        x = x0 + span * k / n
        box(stone, (width, depth, height), T((x, y, z + height * 0.5)), bevel=0.08)
        box(alt, (width + 0.22, depth + 0.22, 0.34), T((x, y, z + height + 0.16)))


# -----------------------------------------------------------------------------------------------------------
# 1. DreadguardKeepTower — Colossal 244-stud square obsidian citadel rising behind the Apex
# -----------------------------------------------------------------------------------------------------------
@template("DreadguardKeepTower", STONE=6200, ALT=1800, METAL=4200, TRIM=3600, SILK=1200, ACCENT=1100, MOSS=800)
def dreadguard_keep_tower(t):
    """The Dreadguard Keep Tower (244 studs tall, 38x30 base footprint): a colossal battered obsidian square
    keep rising behind the Apex mound, visible from arrival over the Ravelin. Features stepped obsidian
    plinths with ash drifts, battered corner buttresses, the Overlord's empty sword-niche on the lower south
    face (-Y), a massive Chained Crown relief high on the facade, deep lancet embrasures, overhanging
    machicolated battlements, four spiked iron corner watch-turrets, giant anchor chains, wine crimson
    banners, and a towering central blackened-iron spire rising to 244 studs."""
    stone, alt, metal, trim, silk, accent, moss = (t.bm(r) for r in ("STONE", "ALT", "METAL", "TRIM", "SILK", "ACCENT", "MOSS"))

    # Stepped obsidian base plinth & ash drifts (Z = 0..16, footprint 38 x 30).
    box(stone, (38.0, 30.0, 6.0), T((0, 0, 3.0)), bevel=0.4)
    box(stone, (34.0, 26.8, 10.0), T((0, 0, 11.0)), bevel=0.35)
    box(alt, (34.6, 27.4, 0.9), T((0, 0, 16.2)))
    for k, (ax, ay) in enumerate(((-15.5, -13.0), (15.5, -13.0), (-16.0, 12.5), (16.0, 12.5))):
        ground_rock(moss, (7.0, 5.5, 2.2), (ax, ay, 0.0), seed=4901 + k, roughness=0.30, subdiv=1)

    # Lower keep bastion body (Z = 16..68, 30 x 24) with heavy battered corner buttresses.
    box(stone, (30.0, 24.0, 52.0), T((0, 0, 42.0)), bevel=0.3)
    for sx in (-1, 1):
        for sy in (-1, 1):
            # Battered corner buttress piers climbing from plinth to upper tier.
            strut(stone, (sx * 16.2, sy * 13.0, 4.0), (sx * 13.8, sy * 10.8, 72.0), 4.8)
            box(metal, (5.4, 5.4, 1.4), T((sx * 14.4, sy * 11.4, 44.0)))
            box(metal, (5.0, 5.0, 1.4), T((sx * 13.8, sy * 10.8, 68.0)))

    # Overlord's empty sword-niche on the south (-Y) facade (Z = 24..54, visible above Apex!).
    box(trim, (11.6, 2.8, 24.0), T((0, -12.4, 38.0)))
    box(metal, (8.4, 1.8, 20.5), T((0, -12.0, 38.0)))
    # Pointed arch hood over the niche.
    strut(stone, (-5.8, -13.2, 46.0), (0, -13.2, 54.0), 1.6)
    strut(stone, (5.8, -13.2, 46.0), (0, -13.2, 54.0), 1.6)
    # Empty gilded sword-rack & iron brackets inside the dark niche (waiting for Vharos's blade).
    box(alt, (5.2, 2.2, 2.4), T((0, -12.8, 28.5)))
    box(silk, (4.4, 2.4, 0.7), T((0, -12.8, 29.8)))
    for sz_hook in (34.0, 42.0):
        box(accent, (3.2, 1.0, 0.45), T((0, -12.8, sz_hook)))
        for sx in (-1.2, 1.2):
            box(accent, (0.35, 1.6, 0.6), T((sx, -13.3, sz_hook + 0.25)))

    # First string-course gallery & Chained Crown colossal relief (Z = 68..88).
    box(stone, (32.4, 26.4, 3.2), T((0, 0, 69.6)), bevel=0.25)
    box(alt, (33.0, 27.0, 0.8), T((0, 0, 71.4)))
    box(metal, (32.6, 26.6, 1.2), T((0, 0, 67.6)))

    # Mid citadel tower shaft (Z = 71..152, 24 x 20) with recessed vertical lancet bays & iron strapping.
    box(stone, (24.0, 20.0, 81.0), T((0, 0, 111.5)), bevel=0.25)
    for sx in (-1, 1):
        for sy in (-1, 1):
            strut(stone, (sx * 12.2, sy * 10.2, 70.0), (sx * 10.8, sy * 9.0, 154.0), 3.6)
    # Colossal Chained Crown relief centred on the south (-Y) wall at Z = 90.
    chained_crown_sigil(metal, trim, accent, T((0, -10.5, 92.0)), scale=3.1)
    # Recessed dark iron lancet arrow-slit windows on all 4 faces.
    for f_ang, dist in ((0.0, 10.2), (math.pi, 10.2), (math.pi / 2, 12.2), (-math.pi / 2, 12.2)):
        fm = R(f_ang, 4, "Z") @ T((0, -dist, 0))
        for sx in (-4.4, 4.4):
            box(trim, (1.6, 0.9, 34.0), fm @ T((sx, 0, 124.0)))
        box(trim, (1.8, 0.9, 26.0), fm @ T((0, 0, 130.0)))
    # Iron tie-bands wrapping the mid tower.
    for zb in (82.0, 108.0, 134.0, 150.0):
        box(metal, (25.2, 21.2, 1.4), T((0, 0, zb)))

    # Upper machicolated war-gallery & crenellated parapet (Z = 152..182).
    box(stone, (28.0, 24.0, 5.5), T((0, 0, 154.7)), bevel=0.3)
    for k in range(5):
        ox = -10.0 + k * 5.0
        for sy in (-1, 1):
            box(stone, (1.8, 2.2, 4.0), T((ox, sy * 11.4, 150.8)))
    box(stone, (22.0, 18.0, 24.0), T((0, 0, 169.5)), bevel=0.2)
    box(alt, (28.6, 24.6, 0.9), T((0, 0, 157.8)))
    for sy in (-1, 1):
        crenel_row(stone, alt, -12.0, 12.0, sy * 12.4, 158.0, width=2.6, depth=1.6, height=4.2, step=4.8)
    # Wine crimson war-banners hanging from upper war-gallery (-Y front & flanks).
    for sx in (-8.5, 8.5):
        banner_hang(metal, silk, trim, T((sx, -13.4, 154.0)), w=3.4, h=22.0)

    # Four overhanging corner watch-turrets (Z = 156..198) + heavy iron brace chains!
    for sx in (-1, 1):
        for sy in (-1, 1):
            tx, ty = sx * 12.8, sy * 10.8
            box(stone, (6.2, 6.2, 28.0), T((tx, ty, 170.0)), bevel=0.18)
            box(metal, (6.6, 6.6, 1.2), T((tx, ty, 184.2)))
            cone(metal, 4.4, 0.15, 14.0, 4, T((tx, ty, 184.8)) @ R(math.pi / 4, 4, "Z"))
            # Heavy iron anchor chain sweeping from turret waist down to lower corner buttress.
            chain_run(metal, trim, (tx, ty, 160.0), (sx * 15.0, sy * 12.2, 70.0), link_h=2.8, link_w=1.7, thick=0.35)

    # Top belfry lantern & towering blackened-iron citadel spire reaching Z = 244.0!
    box(stone, (16.0, 14.0, 18.0), T((0, 0, 190.5)), bevel=0.2)
    for sx in (-1, 1):
        for sy in (-1, 1):
            box(metal, (3.2, 3.2, 22.0), T((sx * 6.8, sy * 5.8, 192.0)))
    box(metal, (17.2, 15.2, 1.8), T((0, 0, 200.0)))
    # Steep octagonal/pyramidal iron spire roof + tall finial spike to Z = 244.0.
    cone(stone, 10.2, 3.8, 18.0, 4, T((0, 0, 200.9)) @ R(math.pi / 4, 4, "Z"))
    cone(metal, 4.2, 0.12, 25.1, 4, T((0, 0, 218.9)) @ R(math.pi / 4, 4, "Z"))
    ring_mesh(accent, 1.6, 0.28, 12, T((0, 0, 232.0)) @ R(math.pi / 2, 4, "X"), tube_segs=5)


# -----------------------------------------------------------------------------------------------------------
# 2. DreadguardKeepGatehouse — Inner drawbridge gate-arch with chain-winch turrets & Wardlights
# -----------------------------------------------------------------------------------------------------------
@template("DreadguardKeepGatehouse", STONE=4200, ALT=1200, METAL=2800, TRIM=2400, SILK=900, ACCENT=600, GLOW=600)
def dreadguard_keep_gatehouse(t):
    """Inner drawbridge gate-arch (28 wide, 14 deep, 38 tall) with a wide 18-stud clear passage and 20-stud
    arch clearance so drawbridges walk cleanly through. Flanked by dual chain-winch turrets, Chained Crown
    keystone over the pointed arch, wine crimson banners, and the keep's lit bone-white Wardlight lamps."""
    stone, alt, metal, trim, silk, accent, glow = (t.bm(r) for r in ("STONE", "ALT", "METAL", "TRIM", "SILK", "ACCENT", "GLOW"))

    # Twin flanking gate-piers (inner faces at X = +-9.2 -> 18.4-stud wide clear opening).
    for sx in (-1, 1):
        px = sx * 11.8
        box(stone, (5.2, 11.2, 4.0), T((px, 0, 2.0)), bevel=0.2)
        box(stone, (4.6, 10.2, 22.0), T((px, 0, 15.0)), bevel=0.18)
        box(metal, (4.9, 10.5, 1.0), T((px, 0, 14.0)))
        box(alt, (5.0, 10.6, 0.65), T((px, 0, 26.2)))
        # Upper chain-winch turret rising to Z = 36.
        box(stone, (4.2, 8.8, 9.0), T((px, 0, 31.0)), bevel=0.15)
        cone(metal, 3.0, 0.12, 6.2, 4, T((px, 0, 35.5)) @ R(math.pi / 4, 4, "Z"))
        # Lit bone-white Wardlight hanging from forward bracket at Z = 18.5.
        strut(metal, (px, -5.1, 20.5), (px, -7.2, 20.5), 0.32)
        strut(trim, (px, -5.1, 18.6), (px, -6.8, 20.5), 0.22)
        wardlight_cage(metal, trim, glow, T((px, -7.2, 18.4)), scale=1.18, lit=True)
        # Heavy drawbridge winch wheel & angled chains anchored to arch cheek.
        ring_mesh(metal, 1.8, 0.25, 14, T((px - sx * 2.4, -4.6, 22.0)) @ R(math.pi / 2, 4, "Y"), tube_segs=5)
        chain_run(metal, trim, (px - sx * 1.4, -4.6, 22.0), (px - sx * 1.4, -6.5, 8.0), link_h=1.3, link_w=0.8, thick=0.16)

    # High pointed obsidian arch bridge spanning between piers (clear height >= 20.5 studs!).
    box(stone, (20.4, 9.4, 5.4), T((0, 0, 25.8)), bevel=0.2)
    for sx in (-1, 1):
        # Haunch corbels keeping Z <= 20 completely open across X = -9.0..+9.0.
        strut(stone, (sx * 9.5, 0, 19.2), (sx * 4.5, 0, 24.4), 2.8)
    crenel_row(stone, alt, -9.2, 9.2, -4.0, 28.5, width=2.2, depth=1.4, height=2.6, step=4.4)
    crenel_row(stone, alt, -9.2, 9.2, 4.0, 28.5, width=2.2, depth=1.4, height=2.6, step=4.4)
    # Chained Crown keystone & flanking wine banners on front (-Y) face.
    chained_crown_sigil(metal, trim, accent, T((0, -5.1, 26.2)), scale=1.25)
    for sx in (-1, 1):
        banner_hang(metal, silk, trim, T((sx * 6.4, -5.2, 26.8)), w=1.9, h=6.4)


# -----------------------------------------------------------------------------------------------------------
# 3. StarBastionSalient — Angular arrow-head obsidian star-fort bastion prow with sentry box
# -----------------------------------------------------------------------------------------------------------
@template("StarBastionSalient", STONE=3800, ALT=900, METAL=2400, TRIM=1600, SILK=900)
def star_bastion_salient(t):
    """Arrow-head obsidian star-fort bastion prow (26 wide, 22 deep, 28 tall): V-shaped battered masonry walls
    converging to a sharp iron-capped prow facing -Y, topped by bone-white coping, crenellated parapet,
    overhanging octagonal sentry box (bartizan) at the tip, and a wine crimson banner."""
    stone, alt, metal, trim, silk = (t.bm(r) for r in ("STONE", "ALT", "METAL", "TRIM", "SILK"))

    # Stepped battered arrow-head prow body built from angled left/right cheek walls + solid core.
    prow_y, back_y, wing_x = -11.0, 9.5, 12.2
    for sx in (-1, 1):
        a = Vector((sx * wing_x, back_y, 0))
        b = Vector((0.0, prow_y, 0))
        d = b - a
        yaw = math.atan2(d.y, d.x)
        m = T((a + b) * 0.5) @ R(yaw, 4, "Z")
        length = d.length + 1.5
        box(stone, (length, 4.4, 4.0), m @ T((0, 0, 2.0)), bevel=0.18)
        box(stone, (length - 0.8, 3.6, 13.0), m @ T((0, 0, 10.5)), bevel=0.14)
        box(alt, (length - 0.4, 4.0, 0.55), m @ T((0, 0, 17.2)))
        # Crenellated merlons along each cheek.
        for k in range(5):
            f = (k + 0.5) / 5.0
            p = a.lerp(b, f)
            box(stone, (2.4, 1.5, 2.4), T((p.x, p.y, 18.6)) @ R(yaw, 4, "Z"))
            box(alt, (2.6, 1.7, 0.32), T((p.x, p.y, 19.95)) @ R(yaw, 4, "Z"))
    # Rear bastion fill deck & iron prow cutwater nose at (0, prow_y).
    box(stone, (18.0, 10.0, 17.0), T((0, 4.5, 8.5)), bevel=0.2)
    box(metal, (2.2, 2.6, 17.5), T((0, prow_y, 8.75)) @ R(math.pi / 4, 4, "Z"))

    # Overhanging sentry box (bartizan) perched at the bastion's salient tip (Z = 15.5..28).
    cone(stone, 1.0, 2.8, 3.5, 6, T((0, prow_y + 0.6, 14.2)))
    cone(stone, 2.7, 2.6, 6.2, 6, T((0, prow_y + 0.6, 17.7)))
    box(trim, (1.2, 1.2, 3.8), T((0, prow_y - 1.9, 20.8)))
    cone(metal, 3.1, 0.1, 5.0, 6, T((0, prow_y + 0.6, 23.9)))
    # Wine crimson banner pole behind the sentry box.
    cyl_z(metal, 0.20, 10.0, (0, -2.5, 17.0), segs=8)
    banner_hang(metal, silk, trim, T((0, -2.8, 25.8)), w=2.2, h=6.5)


# -----------------------------------------------------------------------------------------------------------
# 4. CurtainWallCrenel — Battered obsidian crenellated curtain-wall parapet with arrow-slits & caged void shard
# -----------------------------------------------------------------------------------------------------------
@template("CurtainWallCrenel", STONE=2400, ALT=700, METAL=1400, TRIM=1200, CRYSTAL=600)
def curtain_wall_crenel(t):
    """Battered obsidian crenellated curtain-wall parapet segment (24 wide, 6 deep, 15 tall) with stepped
    footing, iron tie-bolts, arrow-slit embrasures, bone-white coping, and a caged void shard set in the
    central merlon (echoing the Void Titan Core relic)."""
    stone, alt, metal, trim, crystal = (t.bm(r) for r in ("STONE", "ALT", "METAL", "TRIM", "CRYSTAL"))
    box(stone, (24.0, 5.6, 2.2), T((0, 0, 1.1)), bevel=0.14)
    box(stone, (23.6, 4.6, 7.6), T((0, 0, 6.0)), bevel=0.12)
    box(metal, (24.0, 4.9, 0.65), T((0, 0, 5.4)))
    box(alt, (24.0, 5.0, 0.48), T((0, 0, 10.0)))
    # Buttress pilasters at ends & centre.
    for x in (-10.6, 0.0, 10.6):
        box(stone, (2.2, 5.4, 9.8), T((x, 0, 4.9)), bevel=0.08)
        box(metal, (2.5, 5.6, 0.55), T((x, 0, 8.2)))
    # Crenellated merlons with narrow arrow-slits.
    for x in (-9.6, -4.8, 4.8, 9.6):
        box(stone, (3.1, 2.2, 3.2), T((x, -1.2, 11.8)), bevel=0.06)
        box(alt, (3.3, 2.4, 0.36), T((x, -1.2, 13.55)))
        box(trim, (0.45, 2.35, 1.8), T((x, -1.2, 11.6)))
    # Central iron-caged void shard perched on the middle merlon.
    box(stone, (3.4, 2.6, 3.8), T((0, -1.0, 12.1)), bevel=0.08)
    cone(crystal, 0.72, 0.08, 2.4, 6, T((0, -1.0, 13.8)))
    for k in range(4):
        a = k * math.pi / 2 + math.pi / 4
        strut(trim, (math.cos(a) * 0.9, -1.0 + math.sin(a) * 0.9, 13.8),
              (math.cos(a) * 0.45, -1.0 + math.sin(a) * 0.45, 16.4), 0.14)
    ring_mesh(metal, 0.95, 0.14, 10, T((0, -1.0, 14.8)), tube_segs=4)


# -----------------------------------------------------------------------------------------------------------
# 5. DrawbridgeStair — Iron-banded drawbridge gate frame with angled chain anchor stays
# -----------------------------------------------------------------------------------------------------------
@template("DrawbridgeStair", STONE=2200, METAL=2800, TRIM=2200, WOOD=1800, ALT=600)
def drawbridge_stair(t):
    """Iron-banded drawbridge gate frame (24 wide, 12 deep, 26 tall) with wide 17-stud clear passage, heavy
    obsidian & timber portal piers, iron strapping bands, overhead beam, and twin angled iron anchor chains."""
    stone, metal, trim, wood, alt = (t.bm(r) for r in ("STONE", "METAL", "TRIM", "WOOD", "ALT"))

    # Twin flanking portal piers (inner clear width X = -8.6..+8.6 = 17.2 studs).
    for sx in (-1, 1):
        px = sx * 10.4
        box(stone, (3.6, 8.8, 3.2), T((px, 0, 1.6)), bevel=0.14)
        box(wood, (2.8, 7.2, 19.0), T((px, 0, 12.7)))
        for zb in (5.0, 10.5, 16.0, 21.5):
            box(metal, (3.1, 7.6, 0.75), T((px, 0, zb)))
        box(alt, (3.4, 8.0, 0.55), T((px, 0, 22.4)))
        # Iron anchor bollard & angled drawbridge suspension chains running forward (-Y).
        box(metal, (2.2, 2.2, 2.4), T((px, -4.8, 1.2)))
        chain_run(metal, trim, (px - sx * 0.8, -1.0, 21.2), (px - sx * 0.8, -5.6, 3.2), link_h=1.4, link_w=0.85, thick=0.18)
        # Overhead iron pulley bracket.
        box(metal, (1.6, 3.2, 2.2), T((px, -3.4, 22.8)))
        ring_mesh(trim, 1.15, 0.20, 12, T((px, -4.5, 22.8)) @ R(math.pi / 2, 4, "Y"), tube_segs=4)

    # Overhead iron-banded lintel beam (clear height >= 20.6 studs!).
    box(wood, (21.6, 4.4, 2.8), T((0, 0, 23.8)))
    for bx in (-7.0, 0.0, 7.0):
        box(metal, (1.2, 4.8, 3.1), T((bx, 0, 23.8)))
    box(trim, (22.4, 4.8, 0.55), T((0, 0, 25.4)))


# -----------------------------------------------------------------------------------------------------------
# 6. GateTowerChained — Tall iron-strapped gate tower carrying drawbridge chain pulleys & lit Wardlight
# -----------------------------------------------------------------------------------------------------------
@template("GateTowerChained", STONE=3600, ALT=900, METAL=2800, TRIM=2400, SILK=900, GLOW=600)
def gate_tower_chained(t):
    """Tall iron-strapped square gate tower (14x14x54) carrying drawbridge chain pulley wheels, iron strapping
    bands, overhanging hoarding gallery, pyramidal iron roof with spike finial, wine banner, and a lit
    bone-white Wardlight lantern hanging from a forward iron jib."""
    stone, alt, metal, trim, silk, glow = (t.bm(r) for r in ("STONE", "ALT", "METAL", "TRIM", "SILK", "GLOW"))

    # Battered plinth & main square tower shaft (Z = 0..38).
    box(stone, (14.0, 14.0, 4.5), T((0, 0, 2.25)), bevel=0.2)
    box(stone, (11.4, 11.4, 32.0), T((0, 0, 20.5)), bevel=0.18)
    for zb in (11.0, 21.0, 31.0):
        box(metal, (12.0, 12.0, 1.1), T((0, 0, zb)))
    box(alt, (12.2, 12.2, 0.6), T((0, 0, 36.8)))

    # Overhanging upper machicolated watch-story (Z = 37..44) & pyramidal iron roof (Z = 44..54).
    box(stone, (13.4, 13.4, 6.2), T((0, 0, 40.2)), bevel=0.15)
    box(metal, (13.8, 13.8, 0.8), T((0, 0, 43.6)))
    cone(metal, 9.6, 0.14, 10.4, 4, T((0, 0, 44.0)) @ R(math.pi / 4, 4, "Z"))
    # Drawbridge chain pulley wheel on front cheek + vertical chain drop.
    ring_mesh(metal, 2.2, 0.28, 14, T((0, -6.2, 26.0)) @ R(math.pi / 2, 4, "Y"), tube_segs=5)
    chain_run(metal, trim, (0, -6.4, 26.0), (0, -6.4, 5.0), link_h=1.4, link_w=0.85, thick=0.18)
    # Lit bone-white Wardlight hanging off forward iron jib at Z = 16.
    strut(metal, (0, -5.6, 18.8), (0, -8.4, 18.8), 0.34)
    strut(trim, (0, -5.6, 16.5), (0, -8.0, 18.8), 0.22)
    wardlight_cage(metal, trim, glow, T((0, -8.4, 16.6)), scale=1.25, lit=True)
    # Wine crimson banner on upper story.
    banner_hang(metal, silk, trim, T((0, -7.1, 41.2)), w=2.4, h=8.0)


# -----------------------------------------------------------------------------------------------------------
# 7. RavelinPortcullis — Blind iron portcullis set into a pointed obsidian ravelin wall (leads nowhere)
# -----------------------------------------------------------------------------------------------------------
@template("RavelinPortcullis", STONE=3600, ALT=900, METAL=2800, TRIM=2400, SILK=900, ACCENT=500)
def ravelin_portcullis(t):
    """Pointed obsidian ravelin wall (26 wide, 11 deep, 24 tall) housing a blind spiked iron portcullis sealed
    solid against an iron-studded wall (the fort has no front gate), crowned with Chained Crown & banners."""
    stone, alt, metal, trim, silk, accent = (t.bm(r) for r in ("STONE", "ALT", "METAL", "TRIM", "SILK", "ACCENT"))

    # Pointed ravelin cheek walls flanking the central blind gateway.
    box(stone, (24.0, 8.2, 2.6), T((0, 0, 1.3)), bevel=0.18)
    for sx in (-1, 1):
        box(stone, (7.6, 7.6, 15.5), T((sx * 8.4, 0.6, 10.0)) @ R(sx * 0.22, 4, "Z"), bevel=0.15)
        box(alt, (7.9, 7.9, 0.5), T((sx * 8.4, 0.6, 18.0)) @ R(sx * 0.22, 4, "Z"))
        crenel_row(stone, alt, sx * 5.2 - 2.6, sx * 5.2 + 2.6, -2.5, 18.2, width=2.2, depth=1.5, height=2.6, step=4.0)
        banner_hang(metal, silk, trim, T((sx * 7.8, -3.6, 16.5)), w=2.0, h=6.5)

    # Central arch lintel & solid blind backing wall (leads nowhere!).
    box(stone, (12.4, 6.8, 17.0), T((0, 1.2, 11.1)), bevel=0.16)
    box(stone, (11.2, 7.4, 5.2), T((0, -0.4, 17.4)), bevel=0.14)
    box(alt, (11.6, 7.8, 0.5), T((0, -0.4, 20.2)))
    chained_crown_sigil(metal, trim, accent, T((0, -4.4, 17.6)), scale=1.15)
    # Blind studded iron seal door & lowered spiked iron portcullis grille in front of it.
    box(trim, (8.6, 1.2, 14.2), T((0, -0.8, 8.2)))
    for kx in range(-3, 4):
        strut(metal, (kx * 1.15, -2.4, 1.2), (kx * 1.15, -2.4, 15.0), 0.34)
        cone(trim, 0.24, 0.02, 1.1, 4, T((kx * 1.15, -2.4, 1.2)) @ R(math.pi, 4, "X"))
    for kz in (3.2, 6.6, 10.0, 13.4):
        box(metal, (8.6, 0.42, 0.42), T((0, -2.4, kz)))


# -----------------------------------------------------------------------------------------------------------
# 8. IronStakePalisade — Row of angled blackened-iron cheval-de-frise stakes along the covered way
# -----------------------------------------------------------------------------------------------------------
@template("IronStakePalisade", METAL=2200, TRIM=1800, STONE=900, MOSS=600)
def iron_stake_palisade(t):
    """Row of 9 angled blackened-iron cheval-de-frise stakes (20 wide, 6 deep, 9 tall) anchored in an obsidian
    kerb beam with ash drifts, canted forward toward the Glacis (-Y)."""
    metal, trim, stone, moss = (t.bm(r) for r in ("METAL", "TRIM", "STONE", "MOSS"))
    box(stone, (20.0, 3.6, 1.4), T((0, 0.4, 0.7)), bevel=0.1)
    ground_rock(moss, (5.5, 3.2, 1.1), (-5.5, -0.6, 0.0), seed=4908, roughness=0.3, subdiv=1)
    ground_rock(moss, (5.5, 3.2, 1.1), (5.5, -0.6, 0.0), seed=4909, roughness=0.3, subdiv=1)
    # Horizontal iron stringer rail binding the stakes.
    box(trim, (19.6, 0.55, 0.55), T((0, -0.4, 3.4)))
    for k in range(9):
        x = -8.8 + k * 2.2
        pitch = math.radians(-30 + (k % 3 - 1) * 5)
        m = T((x, 0.4, 1.1)) @ R(pitch, 4, "X")
        cone(metal, 0.38, 0.24, 6.8, 6, m)
        cone(trim, 0.26, 0.02, 2.2, 4, m @ T((0, 0, 6.8)))
        if k % 2 == 1:
            # Back brace stake leaning +Y.
            mb = T((x, 0.6, 1.1)) @ R(math.radians(24), 4, "X")
            cone(trim, 0.30, 0.04, 5.2, 5, mb)


# -----------------------------------------------------------------------------------------------------------
# 9. SiegeHookCrane — Tall iron bastion crane with chains & colossal siege grapnel hook
# -----------------------------------------------------------------------------------------------------------
@template("SiegeHookCrane", METAL=2800, TRIM=2400, WOOD=1600, STONE=1200)
def siege_hook_crane(t):
    """Tall iron siege crane for the Bastion of Hooks (12 wide, 22 deep, 36 tall): stepped obsidian slewing
    base, iron-banded timber A-frame mast, sweeping jib boom extending over the parapet (-Y), spiked iron
    counterweight box, toothed winch wheel, and a colossal 4-prong siege grapnel dangling on iron chain."""
    metal, trim, wood, stone = (t.bm(r) for r in ("METAL", "TRIM", "WOOD", "STONE"))

    # Stepped slewing plinth (Z = 0..3.6).
    cone(stone, 5.4, 4.8, 2.2, 8, T((0, 1.0, 0)))
    cone(metal, 4.2, 3.6, 1.4, 8, T((0, 1.0, 2.2)))
    # Vertical iron-bound crane mast & diagonal stay struts (Z = 3.6..28).
    box(wood, (2.4, 2.4, 24.5), T((0, 1.0, 15.8)))
    for zb in (7.0, 13.0, 19.0, 25.0):
        box(metal, (2.7, 2.7, 0.7), T((0, 1.0, zb)))
    strut(metal, (-2.6, 4.4, 3.4), (-0.8, 1.4, 20.0), 0.75)
    strut(metal, (2.6, 4.4, 3.4), (0.8, 1.4, 20.0), 0.75)
    # Counterweight box behind mast (+Y) + winding gear drum.
    box(trim, (4.4, 4.4, 4.8), T((0, 6.2, 23.0)))
    cyl_x(metal, 1.5, 4.2, (0, 2.4, 9.0), segs=12)
    ring_mesh(trim, 2.4, 0.25, 16, T((2.4, 2.4, 9.0)) @ R(math.pi / 2, 4, "Y"), tube_segs=5)
    # Long angled jib boom extending forward (-Y) up to Z = 35.5!
    strut(wood, (0, 1.2, 14.0), (0, -10.4, 34.8), 1.45)
    strut(metal, (0, 1.2, 27.6), (0, -10.4, 34.8), 0.55)
    # Tip sheave pulley + chain dropping down to colossal 4-prong siege grapnel hook!
    ring_mesh(metal, 1.3, 0.22, 12, T((0, -10.4, 34.8)) @ R(math.pi / 2, 4, "Y"), tube_segs=4)
    chain_run(metal, trim, (0, -10.4, 34.2), (0, -10.4, 15.0), link_h=1.5, link_w=0.95, thick=0.20)
    # Colossal 4-prong iron siege grapnel hook (Z = 9.5..15.0).
    cyl_z(metal, 0.55, 4.5, (0, -10.4, 10.5), segs=8)
    for k in range(4):
        a = k * math.pi / 2
        m = T((0, -10.4, 10.8)) @ R(a, 4, "Z")
        strut(trim, m @ Vector((0, 0, 0)), m @ Vector((2.6, 0, 1.4)), 0.45)
        cone(metal, 0.35, 0.03, 2.2, 4, m @ T((2.6, 0, 1.4)) @ R(math.radians(-30), 4, "Y"))


# -----------------------------------------------------------------------------------------------------------
# 10. ExecutionYardSet — Executioner's dais block, whetstone wheel & two-handed axe rack
# -----------------------------------------------------------------------------------------------------------
@template("ExecutionYardSet", STONE=1600, WOOD=1800, METAL=2200, TRIM=1400, SILK=400)
def execution_yard_set(t):
    """Bastion of Axes executioners' yard vignette (14 wide, 12 deep, 9 tall): stepped obsidian dais with
    iron-banded chopping block and planted great-axe, treadle whetstone grindstone on an A-frame, and an
    iron-bound rack holding three oversized Dreadguard executioner axes."""
    stone, wood, metal, trim, silk = (t.bm(r) for r in ("STONE", "WOOD", "METAL", "TRIM", "SILK"))

    # Stepped obsidian dais + iron-banded timber chopping block (left-front).
    box(stone, (7.6, 6.8, 1.2), T((-2.6, -1.8, 0.6)), bevel=0.1)
    cyl_z(wood, 1.85, 2.8, (-2.6, -1.8, 1.2), segs=12)
    ring_mesh(metal, 1.92, 0.16, 16, T((-2.6, -1.8, 2.0)), tube_segs=4)
    ring_mesh(metal, 1.92, 0.16, 16, T((-2.6, -1.8, 3.6)), tube_segs=4)
    # Embedded great-axe biting into the block.
    box(metal, (0.28, 2.4, 2.2), T((-2.6, -1.8, 4.9)) @ R(0.18, 4, "Y"))
    strut(wood, (-2.6, -1.8, 4.6), (-1.4, -2.1, 8.8), 0.24)

    # Treadle whetstone grindstone wheel on the right-front (+X).
    for sy in (-1.2, 1.2):
        strut(wood, (3.6, sy - 0.8, 0.0), (3.6, sy, 3.6), 0.35)
        strut(wood, (5.4, sy + 0.6, 0.0), (3.6, sy, 3.6), 0.35)
    cyl_y(stone, 1.85, 0.9, (3.6, 0.0, 2.8), segs=18)
    cyl_y(metal, 0.26, 3.2, (3.6, 0.0, 2.8), segs=8)

    # Heavy iron-bound great-axe rack along the back (+Y).
    box(wood, (10.8, 1.8, 0.55), T((0, 3.8, 0.275)))
    for sx in (-4.8, 4.8):
        box(wood, (0.55, 1.0, 7.2), T((sx, 3.8, 3.9)))
    box(metal, (10.8, 0.6, 0.55), T((0, 3.8, 6.2)))
    for k in range(3):
        ax = -3.0 + k * 3.0
        cyl_z(wood, 0.16, 7.6, (ax, 3.5, 0.55), segs=8)
        box(metal, (2.2, 0.24, 2.4), T((ax, 3.3, 6.8)))
        box(trim, (2.4, 0.28, 0.35), T((ax, 3.3, 5.8)))
    box(silk, (1.6, 0.15, 2.8), T((-4.8, 3.2, 4.8)))


# -----------------------------------------------------------------------------------------------------------
# 11. PenitentCage — Hanging iron penitent cage suspended from a spiked iron gibbet bracket
# -----------------------------------------------------------------------------------------------------------
@template("PenitentCage", STONE=900, METAL=2400, TRIM=2000, SILK=500)
def penitent_cage(t):
    """Spiked iron gibbet bracket on an obsidian plinth (8x8x22) suspending a barred cylindrical iron
    penitent cage on a heavy chain at Z = 6.5..14.5 with tattered wine cloth inside."""
    stone, metal, trim, silk = (t.bm(r) for r in ("STONE", "METAL", "TRIM", "SILK"))

    # Grounded obsidian plinth & upright iron gibbet post (at +Y side).
    cone(stone, 3.2, 2.6, 1.6, 6, T((0, 2.0, 0)))
    box(metal, (1.1, 1.1, 19.6), T((0, 2.0, 11.4)))
    strut(metal, (0, 2.0, 21.0), (0, -2.4, 21.0), 0.9)
    strut(trim, (0, 2.0, 15.8), (0, -1.6, 21.0), 0.55)
    cone(trim, 0.45, 0.03, 1.6, 4, T((0, 2.0, 21.2)))
    # Hanging chain & barred iron penitent cage centred at (0, -2.4, 6.8..14.4).
    chain_run(metal, trim, (0, -2.4, 20.6), (0, -2.4, 14.8), link_h=1.2, link_w=0.75, thick=0.16)
    cx, cy = 0.0, -2.4
    for z_ring, r_ring in ((7.0, 1.8), (10.4, 2.15), (14.0, 1.75)):
        ring_mesh(metal, r_ring, 0.18, 12, T((cx, cy, z_ring)), tube_segs=5)
    cyl_z(trim, 1.85, 0.28, (cx, cy, 6.7), segs=12)
    for k in range(8):
        a = 2 * math.pi * k / 8
        strut(trim, (cx + math.cos(a) * 1.8, cy + math.sin(a) * 1.8, 7.0),
              (cx + math.cos(a) * 1.75, cy + math.sin(a) * 1.75, 14.0), 0.16)
        strut(metal, (cx + math.cos(a) * 1.75, cy + math.sin(a) * 1.75, 14.0),
              (cx, cy, 15.1), 0.14)
    box(silk, (1.4, 0.2, 3.6), T((cx, cy, 8.6)) @ R(0.18, 4, "X"))


# -----------------------------------------------------------------------------------------------------------
# 12. GreatIronBell — Colossal cracked iron alarm bell hung in a heavy belfry frame (North Bastion)
# -----------------------------------------------------------------------------------------------------------
@template("GreatIronBell", STONE=2400, METAL=3200, TRIM=2200, WOOD=1400, ACCENT=600)
def great_iron_bell(t):
    """The fort's great iron alarm bell (18 wide, 14 deep, 30 tall): heavy battered obsidian belfry piers,
    iron-banded timber headstock beam, spoked ringing wheel, and a colossal cracked blackened-iron bell
    with old-gold rim band and heavy iron clapper."""
    stone, metal, trim, wood, accent = (t.bm(r) for r in ("STONE", "METAL", "TRIM", "WOOD", "ACCENT"))

    # Twin battered obsidian belfry piers (Z = 0..24) + pointed gable crown (Z = 24..30).
    for sx in (-1, 1):
        px = sx * 6.8
        box(stone, (4.2, 9.6, 3.0), T((px, 0, 1.5)), bevel=0.16)
        strut(stone, (px + sx * 0.4, 0, 3.0), (px - sx * 0.4, 0, 24.0), 3.2)
        box(metal, (3.8, 5.2, 0.9), T((px, 0, 14.0)))
    # Top belfry transom & gable ridge.
    box(stone, (16.2, 5.8, 3.2), T((0, 0, 24.4)), bevel=0.15)
    strut(metal, (-7.8, 0, 25.8), (0, 0, 30.2), 1.4)
    strut(metal, (7.8, 0, 25.8), (0, 0, 30.2), 1.4)
    cone(trim, 0.85, 0.06, 3.2, 4, T((0, 0, 29.8)))

    # Heavy timber & iron headstock beam at Z = 20.6 + spoked ringing wheel on east (+X) cheek.
    box(wood, (11.8, 2.2, 2.2), T((0, 0, 20.8)))
    cyl_x(metal, 0.55, 14.2, (0, 0, 20.8), segs=10)
    ring_mesh(metal, 3.6, 0.24, 18, T((5.2, 0, 20.8)) @ R(math.pi / 2, 4, "Y"), tube_segs=5)
    for k in range(6):
        a = 2 * math.pi * k / 6
        strut(wood, (5.2, 0, 20.8), (5.2, math.cos(a) * 3.5, 20.8 + math.sin(a) * 3.5), 0.24)

    # Colossal cracked blackened-iron bell suspended from Z = 20 down to Z = 7.5!
    bell_profile = [
        (4.8, 7.6),
        (4.3, 8.8),
        (3.4, 11.4),
        (3.0, 15.2),
        (2.4, 18.2),
        (1.0, 19.6),
    ]
    lathe(metal, bell_profile, 20, Matrix.Identity(4))
    ring_mesh(accent, 4.7, 0.22, 20, T((0, 0, 8.0)), tube_segs=5)
    # Jagged vertical crack scar down the front (-Y) skirt of the bell.
    for kz, kx in ((8.4, -0.35), (10.2, 0.22), (12.0, -0.18), (13.8, 0.15)):
        box(trim, (0.45, 0.85, 2.1), T((kx, -3.55, kz)) @ R(kx * 0.9, 4, "Y"))
    # Heavy iron clapper hanging inside & slightly visible below rim.
    cyl_z(trim, 0.28, 10.5, (0, 0, 6.2), segs=8)
    uvsphere(trim, 1.05, T((0, 0, 6.2)), 8, 6)


# -----------------------------------------------------------------------------------------------------------
# 13. MineWindingGear — Iron mine-head hoist frame, winding drum & void-pit shaft collar (Countermine)
# -----------------------------------------------------------------------------------------------------------
@template("MineWindingGear", STONE=1800, METAL=3200, TRIM=2200, WOOD=1600, CRYSTAL=600)
def mine_winding_gear(t):
    """Countermine void-pit hoist (18x18x26): octagonal obsidian shaft collar with faint violet void pit well,
    A-frame blackened-iron headframe, overhead sheave wheel, spoked timber-and-iron winding drum wound with
    iron hoist chains, and brake lever."""
    stone, metal, trim, wood, crystal = (t.bm(r) for r in ("STONE", "METAL", "TRIM", "WOOD", "CRYSTAL"))

    # Octagonal obsidian void-pit shaft collar (Z = 0..3.2, inner radius 4.4).
    for k in range(8):
        a = 2 * math.pi * (k + 0.5) / 8
        m = R(a, 4, "Z") @ T((5.2, 0, 1.6))
        box(stone, (2.2, 4.6, 3.2), m, bevel=0.12)
        box(metal, (2.4, 4.8, 0.45), m @ T((0, 0, 1.75)))
    # Dark pit void floor & subtle void-crystal seam at bottom of collar.
    cyl_z(trim, 4.5, 0.4, (0, 0, 0.05), segs=16)
    cyl_z(crystal, 3.8, 0.2, (0, 0, 0.48), segs=16)

    # Towering A-frame iron headframe rising over the pit to Z = 26!
    for sx in (-1, 1):
        strut(metal, (sx * 5.8, -4.4, 2.8), (sx * 1.4, 0.0, 24.5), 0.9)
        strut(metal, (sx * 5.8, 4.4, 2.8), (sx * 1.4, 0.0, 24.5), 0.9)
        strut(trim, (sx * 4.2, -3.0, 10.0), (sx * 4.2, 3.0, 10.0), 0.55)
    box(metal, (4.4, 3.2, 2.0), T((0, 0, 24.8)))
    # Overhead sheave pulley wheel at Z = 25.5.
    ring_mesh(metal, 2.6, 0.34, 18, T((0, 0, 25.5)) @ R(math.pi / 2, 4, "Y"), tube_segs=5)
    cyl_x(trim, 0.45, 4.8, (0, 0, 25.5), segs=10)

    # Winding drum assembly behind the pit (+Y = 6.8) with wound iron hoist chains.
    for sx in (-3.6, 3.6):
        box(metal, (1.2, 3.6, 5.4), T((sx, 6.8, 2.7)))
    cyl_x(wood, 2.2, 6.4, (0, 6.8, 4.4), segs=16)
    for x_wrap in (-2.2, -1.1, 0.0, 1.1, 2.2):
        ring_mesh(trim, 2.32, 0.22, 16, T((x_wrap, 6.8, 4.4)) @ R(math.pi / 2, 4, "Y"), tube_segs=4)
    # Hoist chain running from drum up to sheave and down into the void shaft!
    chain_run(metal, trim, (0, 5.2, 5.8), (0, 1.6, 25.5), link_h=1.4, link_w=0.85, thick=0.16)
    chain_run(metal, trim, (0, -0.4, 24.2), (0, -0.4, 1.2), link_h=1.4, link_w=0.85, thick=0.18)


# -----------------------------------------------------------------------------------------------------------
# 14. ArmourStandPlate — Blackened-iron Dreadguard plate armor mounted on an iron stand
# -----------------------------------------------------------------------------------------------------------
@template("ArmourStandPlate", STONE=700, METAL=2400, TRIM=1400, SILK=900, ACCENT=400)
def armour_stand_plate(t):
    """Blackened-iron Dreadguard plate armor on an iron stand (6x5x10): stepped obsidian plinth, cruciform
    stand pole, fluted black-iron cuirass, layered spiked pauldrons, cowled iron helm, and wine surcoat."""
    stone, metal, trim, silk, accent = (t.bm(r) for r in ("STONE", "METAL", "TRIM", "SILK", "ACCENT"))

    cone(stone, 2.4, 2.0, 1.0, 6, T((0, 0, 0)))
    cyl_z(trim, 0.24, 7.6, (0, 0, 1.0), segs=8)
    cyl_x(trim, 0.20, 4.2, (0, 0, 6.8), segs=8)
    # Tattered wine crimson surcoat skirt & chest tabard.
    cone(silk, 1.45, 0.95, 3.2, 8, T((0, 0, 2.0)))
    box(silk, (1.1, 1.4, 2.6), T((0, -0.1, 5.2)))
    # Fluted blackened-iron cuirass & tassets.
    box(metal, (2.2, 1.5, 2.8), T((0, 0, 5.6)), bevel=0.16)
    box(accent, (1.6, 1.6, 0.25), T((0, 0, 4.4)))
    # Layered spiked Dreadguard pauldrons.
    for sx in (-1, 1):
        uvsphere(metal, 0.95, T((sx * 1.65, 0, 6.9)), 8, 6)
        cone(trim, 0.24, 0.02, 1.1, 4, T((sx * 2.05, 0, 7.6)) @ R(-sx * 0.45, 4, "Y"))
        box(metal, (0.65, 0.75, 1.9), T((sx * 1.85, 0, 5.2)))
    # Cowled/horned blackened-iron Dreadguard helm.
    uvsphere(metal, 0.85, T((0, 0, 8.3)), 10, 8)
    box(trim, (0.95, 0.4, 1.1), T((0, -0.68, 8.15)))
    for sx in (-1, 1):
        cone(trim, 0.22, 0.02, 1.1, 4, T((sx * 0.55, 0, 8.9)) @ R(-sx * 0.35, 4, "Y"))


# -----------------------------------------------------------------------------------------------------------
# 15. ShutteredWardlight — Iron lamp post with closed dark iron cage (NO glow on outer walls!)
# -----------------------------------------------------------------------------------------------------------
@template("ShutteredWardlight", STONE=700, METAL=1400, TRIM=1400)
def shuttered_wardlight(t):
    """Shuttered Wardlight lamp post for the outer bastions & curtains (4x5x14): stepped obsidian plinth,
    blackened-iron standard with crooked arm, suspending a completely closed, shuttered dark-iron lantern
    cage (ZERO GLOW role so outer fortress walls stay in iron night)."""
    stone, metal, trim = (t.bm(r) for r in ("STONE", "METAL", "TRIM"))

    cone(stone, 1.7, 1.4, 0.7, 8, T((0, 0, 0)) @ R(math.pi / 8, 4, "Z"))
    cone(stone, 1.25, 0.95, 1.1, 8, T((0, 0, 0.7)) @ R(math.pi / 8, 4, "Z"))
    cyl_z(metal, 0.32, 9.6, (0, 0, 1.8), segs=10)
    ring_mesh(trim, 0.48, 0.10, 10, T((0, 0, 6.4)), tube_segs=4)
    # Crooked iron jib arm arcing forward (-Y).
    arm_pts = [(0, 0, 11.2), (0, -0.45, 12.6), (0, -1.5, 13.4), (0, -2.5, 13.0), (0, -2.7, 12.1)]
    tube(metal, arm_pts, [0.22, 0.20, 0.18, 0.16, 0.14], 6, cap=True)
    strut(trim, (0, -0.2, 10.2), (0, -1.5, 13.2), 0.14)
    # Shuttered dark iron lantern (lit=False -> zero GLOW mesh!).
    wardlight_cage(metal, trim, None, T((0, -2.7, 10.3)), scale=1.0, lit=False)


# -----------------------------------------------------------------------------------------------------------
# 16. DreadguardSentry — Hulking hooded Dreadguard statue holding a great executioner's axe
# -----------------------------------------------------------------------------------------------------------
@template("DreadguardSentry", STONE=2400, METAL=2200, TRIM=1600, ACCENT=400)
def dreadguard_sentry(t):
    """Hulking hooded Dreadguard sentry statue (9x9x20) on an octagonal obsidian plinth for star-bastion
    salients: heavy cloaked silhouette in dark stone & blackened iron, deep cowled hood, Chained Crown
    breastplate relief, and both gauntleted hands gripping a colossal planted executioner's greataxe."""
    stone, metal, trim, accent = (t.bm(r) for r in ("STONE", "METAL", "TRIM", "ACCENT"))

    # Battered octagonal obsidian plinth (Z = 0..3.2).
    cone(stone, 4.4, 3.8, 2.2, 8, T((0, 0, 0)) @ R(math.pi / 8, 4, "Z"))
    cone(metal, 3.9, 3.5, 1.0, 8, T((0, 0, 2.2)) @ R(math.pi / 8, 4, "Z"))

    # Heavy armored cloak & lower greaves (Z = 3.2..11.2).
    cone(stone, 3.0, 2.2, 8.2, 10, T((0, 0, 3.2)))
    for sx in (-1, 1):
        box(metal, (1.2, 1.6, 5.2), T((sx * 1.15, -0.6, 5.8)), bevel=0.1)
    # Broad armored torso, spiked shoulder pauldrons & Chained Crown chest emblem (Z = 11..15.8).
    box(metal, (4.6, 2.8, 4.8), T((0, 0.1, 13.2)), bevel=0.22)
    box(stone, (5.2, 2.4, 4.6), T((0, 0.9, 13.0)), bevel=0.2)
    box(accent, (1.4, 0.4, 1.4), T((0, -1.35, 13.8)) @ R(math.pi / 4, 4, "Y"))
    for sx in (-1, 1):
        uvsphere(metal, 1.35, T((sx * 2.6, 0.0, 14.8)), 8, 6)
        cone(trim, 0.32, 0.03, 1.5, 4, T((sx * 3.1, 0.0, 15.8)) @ R(-sx * 0.45, 4, "Y"))
        # Forearms reaching forward to clasp the greataxe haft.
        strut(metal, (sx * 2.5, 0.0, 14.0), (sx * 0.4, -2.5, 11.4), 0.72)

    # Deep cowled hood & shadowed helm visor (Z = 15.6..19.8).
    cone(stone, 1.65, 0.75, 3.6, 8, T((0, 0.1, 15.6)))
    box(trim, (1.5, 1.2, 2.2), T((0, -0.55, 16.9)), bevel=0.12)
    cone(stone, 0.95, 0.15, 1.6, 6, T((0, 0.3, 18.4)) @ R(0.25, 4, "X"))

    # Colossal vertical executioner's greataxe planted in front (-Y = -2.6, Z = 3.2..16.5).
    cyl_z(trim, 0.24, 13.2, (0, -2.6, 3.2), segs=8)
    box(metal, (3.2, 0.42, 4.4), T((0, -2.6, 5.8)), bevel=0.06)
    box(trim, (3.4, 0.50, 0.55), T((0, -2.6, 8.0)))


def apply_abyssal_preview_materials(kit):
    """Tint Blender Workbench materials to the Abyssal Dreadguard Citadel palette."""
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
    kit, manifest = build_kit("AbyssalF49Kit", F49_TEMPLATES, DEFAULT_BUDGET)
    apply_abyssal_preview_materials(kit)
    export_kit(kit, manifest, OUT_DIR, "AbyssalF49Kit")
    render_previews(kit, F49_TEMPLATES, OUT_DIR)
    print(json.dumps(manifest, indent=2))
