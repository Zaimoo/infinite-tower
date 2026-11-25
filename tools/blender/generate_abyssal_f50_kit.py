"""
Abyssal Throne Floor 50 (Overlord's Throne) sculpted assets, generated in headless Blender.

Inspired by the Overlord's Throne reference art (Abyssal Throne 50.jpg) and the Vahl / Crimson Overlord
ecosystem (docs/prompts/abyssal-throne-floor-layouts-prompt.md):
the colossal tiered obsidian Throne rising as the landform itself out of the flagged Supplicants' Floor.
A sheer carved obsidian backrest soaring past 324 studs with gothic iron ribs, tiered shoulder piers,
full-height matte wine-silk banners, and the monumental Chained Crown (one broken link) framed against
the Crimson Eclipse in the black vault; walled armrest battlements; two colossal open iron Gauntlet Hands
cradling the last two bone-white Wardlights; towering armored Greave towers and Sabaton feet; shattered
Broken Grand Stair snapping off into the void; sweeping colossal Mantle Chains and caged chain climbs;
kneeling stone Supplicants; chained Oath Register walls; the ornate Footstool dais trim; iron Relic Cages;
and the jagged Throne Heart Crack showing the Overlord's deep matte red-black heartbeat in the base.

1 Blender unit = 1 stud, standing on z = 0, front facing -Y in Blender / +Z in Roblox, one mesh object
per colour role named "<Template>__<ROLE>". Every piece stands on its origin (Min.Y in (-1.0, 0.5]).

Roles (AbyssalFloor50 passes the Vahl / Crimson Overlord override; no new colour roles):
    STONE    carved obsidian & dark basalt       ALT      bone-white Vahl marble & cold ivory
    METAL    blackened iron plate & bars         TRIM     dark iron strapwork & forged chain
    SILK     matte wine-crimson silk & banners   ACCENT   sparing old gold (Chained Crown & relics)
    GLOW     bone-white Wardlight (or sky halo)  CRYSTAL  deep blood-red / void shard (matte/low-em)
    MOSS     pale grey-violet ash drifts

Outputs (assets-source/tower/abyssal_f50_kit/):
    AbyssalF50Kit.blend, AbyssalF50Kit.fbx, manifest.json, previews/kit_sheet_1.png, previews/tiles/*.png.

Run:
    blender.exe --background --factory-startup --python tools/blender/generate_abyssal_f50_kit.py
"""
import bpy, bmesh, math, os, json, runpy, random
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT_DIR = os.path.join(ROOT, "assets-source", "tower", "abyssal_f50_kit")

# Import ONLY from Floor 21, Floor 26, and Floor 41 generators.
f21 = runpy.run_path(os.path.join(HERE, "generate_infernal_f21_kit.py"))
f26 = runpy.run_path(os.path.join(HERE, "generate_thunder_f26_kit.py"))
f41 = runpy.run_path(os.path.join(HERE, "generate_astral_f41_kit.py"))

box = f21["box"]
cone = f21["cone"]
uvsphere = f21["uvsphere"]
tube = f21["tube"]
ring_mesh = f21["ring_mesh"]
cyl_x, cyl_y, cyl_z, strut = f21["cyl_x"], f21["cyl_y"], f21["cyl_z"], f21["strut"]
build_kit, export_kit, render_previews = f21["build_kit"], f21["export_kit"], f21["render_previews"]
prism = f26["prism"]
ground_rock, centred_rock, slab_stone = f26["ground_rock"], f26["centred_rock"], f26["slab_stone"]
lathe = f41["lathe"]

T = Matrix.Translation
R = Matrix.Rotation

DEFAULT_BUDGET = 3500
F50_TEMPLATES = {}

ABYSSAL_PREVIEW_COLORS = {
    "STONE": (0.09, 0.08, 0.12, 1.0),    # carved obsidian
    "ALT": (0.86, 0.83, 0.76, 1.0),      # bone-white marble
    "METAL": (0.16, 0.15, 0.19, 1.0),    # blackened iron
    "TRIM": (0.24, 0.22, 0.28, 1.0),     # dark iron & chain
    "SILK": (0.46, 0.09, 0.14, 1.0),     # matte wine crimson silk
    "ACCENT": (0.72, 0.56, 0.24, 1.0),   # sparing old gold
    "GLOW": (0.96, 0.93, 0.86, 1.0),     # bone-white Wardlight
    "CRYSTAL": (0.34, 0.06, 0.10, 1.0),  # deep blood-red crystal / heart fissure
    "MOSS": (0.32, 0.30, 0.36, 1.0),     # ash drifts
}


def template(name, **budget):
    def deco(fn):
        F50_TEMPLATES[name] = (fn, budget)
        return fn
    return deco


# -----------------------------------------------------------------------------------------------------------
# Shared Vahl / Overlord motifs: heavy forged chain links, gothic spires, Chained Crown sigil, Wardlight
# -----------------------------------------------------------------------------------------------------------
def oval_link(bm, rx, ry, thick, mat, segs=14, tube_segs=5):
    """Uniform-thickness oval chain link in local XY plane."""
    pts = [(math.cos(2 * math.pi * i / segs) * rx, math.sin(2 * math.pi * i / segs) * ry, 0.0) for i in range(segs + 1)]
    return tube(bm, pts, [thick] * len(pts), tube_segs, mat, cap=False)


def heavy_chain_run(metal, trim, p0, p1, link_h=3.6, link_w=2.2, thick=0.45, segs=12, sag=0.0):
    """Alternating 90-degree forged oval iron chain links from p0 to p1, with optional catenary sag."""
    a, b = Vector(p0), Vector(p1)
    d = b - a
    length = d.length
    if length < 0.2:
        return
    step = link_h * 0.72
    n = max(1, int(length / step))
    for k in range(n):
        t = (k + 0.5) / n
        c = a.lerp(b, t)
        c.z -= sag * 4.0 * t * (1.0 - t)
        t_next = min(1.0, t + 0.05)
        t_prev = max(0.0, t - 0.05)
        c_n = a.lerp(b, t_next)
        c_n.z -= sag * 4.0 * t_next * (1.0 - t_next)
        c_p = a.lerp(b, t_prev)
        c_p.z -= sag * 4.0 * t_prev * (1.0 - t_prev)
        tangent = (c_n - c_p)
        if tangent.length < 1e-4:
            tangent = d
        q = tangent.normalized().to_track_quat("Z", "Y").to_matrix().to_4x4()
        rot_z = (math.pi / 2) if (k % 2 == 1) else 0.0
        m = T(c) @ q @ R(rot_z, 4, "Z") @ R(math.pi / 2, 4, "X")
        oval_link(metal if k % 2 == 0 else trim, link_w * 0.5, link_h * 0.5, thick, m, segs=segs, tube_segs=5)


def gothic_pinnacle(stone, metal, trim, pos, base_w, height):
    """Tiered gothic obsidian & iron pinnacle spire standing on pos."""
    x, y, z = pos
    box(stone, (base_w, base_w, height * 0.34), T((x, y, z + height * 0.17)), bevel=0.18)
    box(trim, (base_w * 1.08, base_w * 1.08, height * 0.05), T((x, y, z + height * 0.34)))
    cone(stone, base_w * 0.58, base_w * 0.36, height * 0.28, 4, T((x, y, z + height * 0.34)) @ R(math.pi / 4, 4, "Z"))
    cone(metal, base_w * 0.40, 0.18, height * 0.38, 4, T((x, y, z + height * 0.62)) @ R(math.pi / 4, 4, "Z"))
    # Four iron rib fins along spire edges.
    for a in (0.0, math.pi / 2, math.pi, -math.pi / 2):
        strut(trim, (x + math.cos(a) * base_w * 0.45, y + math.sin(a) * base_w * 0.45, z + height * 0.34),
              (x, y, z + height * 0.96), max(0.28, base_w * 0.08))


def chained_crown_emblem(metal, trim, accent, mat, scale=1.0, broken_link=True):
    """The Vahl sigil: 5-pointed iron crown inside a great chain ring with ONE broken link at bottom-right."""
    s = scale
    # Crown base band + old gold rim.
    box(metal, (14.0 * s, 2.2 * s, 2.4 * s), mat @ T((0, 0, -2.5 * s)), bevel=0.18 * s)
    box(accent, (14.4 * s, 2.4 * s, 0.55 * s), mat @ T((0, 0, -3.5 * s)))
    box(accent, (14.4 * s, 2.4 * s, 0.55 * s), mat @ T((0, 0, -1.4 * s)))
    # Five jagged gothic crown spires (tallest at centre).
    crown_specs = (
        (-5.6, 5.8, -0.18),
        (-2.8, 7.6, -0.09),
        (0.0, 9.8, 0.0),
        (2.8, 7.6, 0.09),
        (5.6, 5.8, 0.18),
    )
    for cx, ch, tilt in crown_specs:
        cm = mat @ T((cx * s, 0, -1.5 * s)) @ R(tilt, 4, "Y")
        cone(metal, 1.55 * s, 0.22 * s, ch * s, 4, cm @ R(math.pi / 4, 4, "Z"))
        box(accent, (0.55 * s, 2.1 * s, ch * 0.55 * s), cm @ T((0, 0, ch * 0.35 * s)))
        uvsphere(accent, 0.62 * s, cm @ T((0, 0, ch * s)), 8, 6)

    # Great outer chain ring around the crown (radius 13.5 * s) with ONE broken link gap at bottom-right!
    r_ring = 13.5 * s
    n_links = 24
    # Gap at link index 20 (angle ~ -60 deg -> bottom-right when facing -Y).
    gap_idx = 20 if broken_link else -1
    for k in range(n_links):
        if k == gap_idx:
            continue
        ang = 2.0 * math.pi * k / n_links
        lx = math.cos(ang) * r_ring
        lz = math.sin(ang) * r_ring
        tangent_ang = ang + math.pi / 2.0
        twist = (math.pi / 2.0) if (k % 2 == 1) else 0.0
        lm = mat @ T((lx, 0, lz)) @ R(-tangent_ang, 4, "Y") @ R(twist, 4, "Z") @ R(math.pi / 2, 4, "X")
        oval_link(trim if k % 2 == 0 else metal, 1.35 * s, 2.2 * s, 0.45 * s, lm, segs=12, tube_segs=5)
    if broken_link:
        # Snapped dangling half-link at bottom-right edge of the gap.
        ang_b = 2.0 * math.pi * (gap_idx - 0.8) / n_links
        bx = math.cos(ang_b) * r_ring
        bz = math.sin(ang_b) * r_ring
        strut(accent, mat @ Vector((bx, 0, bz)), mat @ Vector((bx + 2.1 * s, -0.6 * s, bz - 3.6 * s)), 0.55 * s)
        # Cardinal iron cross-spokes at N, W, E (south left open beside broken link).
        for ang_c in (math.pi / 2, 0.0, math.pi):
            cm = mat @ T((math.cos(ang_c) * r_ring, 0, math.sin(ang_c) * r_ring)) @ R(-ang_c, 4, "Y")
            cone(accent, 0.9 * s, 0.12 * s, 3.6 * s, 4, cm @ R(math.pi / 2, 4, "Y"))


def wardlight_brazier_head(metal, trim, alt, glow, mat, scale=1.0):
    """Iron-caged Wardlight lantern/brazier cradling a bone-white flame."""
    s = scale
    cone(metal, 1.4 * s, 2.2 * s, 1.4 * s, 8, mat)
    ring_mesh(trim, 2.2 * s, 0.22 * s, 12, mat @ T((0, 0, 1.4 * s)), tube_segs=4)
    cone(alt, 1.5 * s, 1.2 * s, 0.4 * s, 8, mat @ T((0, 0, 1.3 * s)))
    # Bone-white faceted flame core.
    cone(glow, 1.05 * s, 0.15 * s, 2.6 * s, 6, mat @ T((0, 0, 1.6 * s)))
    uvsphere(glow, 0.95 * s, mat @ T((0, 0, 2.1 * s)), 8, 6)
    # 6 curved iron cage ribs.
    for k in range(6):
        a = 2.0 * math.pi * k / 6.0
        p0 = mat @ Vector((math.cos(a) * 2.1 * s, math.sin(a) * 2.1 * s, 1.4 * s))
        p1 = mat @ Vector((math.cos(a) * 1.4 * s, math.sin(a) * 1.4 * s, 4.4 * s))
        strut(trim, p0, p1, 0.18 * s)


# -----------------------------------------------------------------------------------------------------------
# 1. ThroneBackrest — Colossal >=324-stud sheer carved obsidian backrest with gothic ribs & spires
# -----------------------------------------------------------------------------------------------------------
@template("ThroneBackrest", STONE=7500, METAL=5500, TRIM=5000, ALT=1200, MOSS=900)
def throne_backrest(t):
    """Colossal sheer carved obsidian backrest wall (136 wide, 46 deep, 334 studs tall) rising behind the
    Crimson Overlord's Seat: stepped lower dais plinth, twin massive tiered gothic shoulder buttress piers
    with pointed pinnacle spires reaching Z=315, sheer fluted central lancet wall rising to Z=334, heavy
    blackened-iron gothic rib arcades, chain-anchor brackets on the shoulders, and banked ash drifts."""
    stone, metal, trim, alt, moss = (t.bm(r) for r in ("STONE", "METAL", "TRIM", "ALT", "MOSS"))

    # Massive stepped obsidian base plinth (Z = 0..64, Y = -20..+20).
    box(stone, (134.0, 40.0, 26.0), T((0, 0, 13.0)), bevel=0.5)
    box(stone, (124.0, 34.0, 22.0), T((0, 2.0, 37.0)), bevel=0.45)
    box(trim, (128.0, 36.0, 2.4), T((0, 1.5, 48.0)))
    box(alt, (118.0, 2.4, 2.2), T((0, -15.5, 36.0)))  # Subtle bone-marble frieze band above Seat horizon.

    # Sheer central obsidian backrest wall (X = -46..+46, Z = 48..296, Y = -6..+16).
    box(stone, (92.0, 22.0, 248.0), T((0, 5.0, 172.0)), bevel=0.4)
    # Recessed gothic lancet panels & iron vertical ribs across the front face (-Y).
    for x_rib in (-38.0, -24.0, -10.0, 10.0, 24.0, 38.0):
        rib_h = 264.0 if abs(x_rib) < 30 else 248.0
        box(metal, (3.2, 5.2, rib_h), T((x_rib, -5.5, 48.0 + rib_h * 0.5)), bevel=0.15)
        cone(trim, 2.4, 0.2, 22.0, 4, T((x_rib, -5.5, 48.0 + rib_h)) @ R(math.pi / 4, 4, "Z"))
    # Horizontal iron girdle bands with rivets.
    for z_band in (96.0, 152.0, 208.0, 264.0):
        box(trim, (96.0, 25.0, 3.4), T((0, 4.5, z_band)))
    # Gothic pointed central crown gable & soaring apex spire (Z = 290..334!).
    prism(stone, 72.0, 20.0, 32.0, T((0, 5.0, 296.0)))
    gothic_pinnacle(stone, metal, trim, (0, 2.0, 296.0), 14.0, 38.0)  # Top = 334.0 >= 324!
    for sx in (-1, 1):
        gothic_pinnacle(stone, metal, trim, (sx * 24.0, 2.0, 292.0), 9.5, 28.0)

    # Twin colossal outer shoulder piers & pinnacle towers (X = ±54, Z = 0..314).
    for sx in (-1, 1):
        px = sx * 53.0
        box(stone, (26.0, 36.0, 210.0), T((px, 1.0, 148.0)), bevel=0.45)
        box(metal, (28.0, 38.0, 4.0), T((px, 1.0, 108.0)))
        box(metal, (28.0, 38.0, 4.0), T((px, 1.0, 184.0)))
        box(metal, (28.0, 38.0, 4.5), T((px, 1.0, 252.0)))
        # Upper belfry shoulder tower & soaring pinnacle spire (reaches Z = 314).
        gothic_pinnacle(stone, metal, trim, (px, 0.0, 254.0), 18.0, 60.0)
        # Stepped outer flying buttress spurs.
        box(stone, (14.0, 26.0, 128.0), T((px + sx * 10.0, 3.0, 64.0)), bevel=0.3)
        # Heavy iron mantle-chain anchor ring brackets on the forward shoulder piers (Z = 192 & 236).
        for z_anc in (192.0, 236.0):
            box(metal, (6.0, 7.0, 6.0), T((px - sx * 6.0, -17.5, z_anc)))
            ring_mesh(trim, 3.8, 0.85, 16, T((px - sx * 6.0, -21.0, z_anc)) @ R(math.pi / 2, 4, "Y"), tube_segs=5)

    # Pointed gothic iron blind arches along the lower wall (Z = 52..108).
    for ax in (-31.0, -17.0, 0.0, 17.0, 31.0):
        for sx in (-1, 1):
            strut(trim, (ax + sx * 5.2, -7.2, 52.0), (ax + sx * 5.2, -7.2, 86.0), 1.4)
            strut(trim, (ax + sx * 5.2, -7.2, 86.0), (ax, -7.2, 102.0), 1.3)

    # Banked ash drifts around the plinth foot (Z = 0..4).
    for k, ax in enumerate((-56, -34, -14, 14, 34, 56)):
        ground_rock(moss, (16.0, 10.0, 3.8), (ax, -18.5, 0.0), seed=5001 + k, roughness=0.25, subdiv=1)


# -----------------------------------------------------------------------------------------------------------
# 2. ChainedCrownColossal — Monumental black-iron crown in a chain ring with ONE broken link
# -----------------------------------------------------------------------------------------------------------
@template("ChainedCrownColossal", METAL=3200, TRIM=3000, ACCENT=1800)
def chained_crown_colossal(t):
    """Monumental black-iron Chained Crown emblem (~72 wide, 84 tall, 14 deep) framed by an iron chain ring
    with ONE broken link at the bottom-right and sparing old-gold crown rims and cardinal points."""
    metal, trim, accent = (t.bm(r) for r in ("METAL", "TRIM", "ACCENT"))
    # Grounded iron mounting saddle at z = 0..10 so Min.Y = 0.0 (ring bottom sits at z >= 5).
    box(metal, (16.0, 9.0, 3.2), T((0, 0, 1.6)), bevel=0.2)
    strut(trim, (-5.5, 0, 3.0), (-9.0, 0, 12.0), 1.4)
    strut(trim, (5.5, 0, 3.0), (9.0, 0, 12.0), 1.4)
    chained_crown_emblem(metal, trim, accent, T((0, 0, 41.5)), scale=2.45, broken_link=True)


# -----------------------------------------------------------------------------------------------------------
# 3. CrimsonEclipseDisc — Colossal black sun ringed by a thin dark-crimson corona (sky/far layer only)
# -----------------------------------------------------------------------------------------------------------
@template("CrimsonEclipseDisc", STONE=1800, TRIM=1400, GLOW=2400, CRYSTAL=1800)
def crimson_eclipse_disc(t):
    """Colossal black sun disc ringed by a thin dark-crimson corona halo (~152 wide, 154 tall, 7 deep).
    Placed high in the black sky vault behind the Throne's crown; never used near walk surfaces."""
    stone, trim, glow, crystal = (t.bm(r) for r in ("STONE", "TRIM", "GLOW", "CRYSTAL"))
    cz = 77.0
    # Outer flaring crimson corona ring & jagged eclipse rays (bottom ray tip >= z = 0.2).
    ring_mesh(glow, 61.0, 2.4, 48, T((0, 0, cz)) @ R(math.pi / 2, 4, "X"), tube_segs=6)
    ring_mesh(crystal, 64.0, 1.7, 48, T((0, 1.0, cz)) @ R(math.pi / 2, 4, "X"), tube_segs=5)
    for k in range(28):
        ang = 2.0 * math.pi * k / 28.0
        ray_len = 8.5 + (k % 3) * 3.4
        rm = T((math.cos(ang) * 61.2, 0.8, cz + math.sin(ang) * 61.2)) @ R(-ang + math.pi / 2, 4, "Y")
        cone(glow if k % 2 == 0 else crystal, 2.1, 0.15, ray_len, 4, rm)
    # Pitch-black eclipse core disc (solid obsidian-black front face blocking sky behind it) + pedestal pin at z = 0.
    cyl_y(stone, 58.5, 5.2, (0, 0, cz), segs=40)
    cyl_y(trim, 56.5, 6.2, (0, -0.3, cz), segs=36)
    box(stone, (6.0, 4.0, 18.0), T((0, 0, 9.0)))


# -----------------------------------------------------------------------------------------------------------
# 4. ThroneArmrestWall — Carved obsidian & iron-banded outer armrest battlement wall
# -----------------------------------------------------------------------------------------------------------
@template("ThroneArmrestWall", STONE=2400, ALT=900, METAL=1800, TRIM=1400, SILK=700)
def throne_armrest_wall(t):
    """Carved obsidian & iron-banded outer armrest battlement wall (9 wide, 22 tall, 36 long along Y)."""
    stone, alt, metal, trim, silk = (t.bm(r) for r in ("STONE", "ALT", "METAL", "TRIM", "SILK"))
    box(stone, (8.4, 36.0, 4.0), T((0, 0, 2.0)), bevel=0.25)
    box(stone, (6.8, 34.8, 12.0), T((0, 0, 10.0)), bevel=0.2)
    box(alt, (7.6, 35.4, 1.2), T((0, 0, 16.4)))
    # Five crenellated merlons with iron spear finials.
    for y in (-13.0, -6.5, 0.0, 6.5, 13.0):
        box(stone, (6.4, 4.4, 3.6), T((0, y, 18.6)), bevel=0.12)
        box(metal, (6.8, 4.8, 0.8), T((0, y, 20.6)))
        cone(trim, 0.55, 0.05, 1.8, 4, T((0, y, 21.0)))
    # Iron vertical ribs & recessed matte wine cloth banners between ribs.
    for y in (-15.5, -8.5, 0.0, 8.5, 15.5):
        box(metal, (7.8, 1.6, 15.6), T((0, y, 8.8)), bevel=0.1)
    for y in (-12.0, -4.2, 4.2, 12.0):
        box(silk, (7.3, 4.8, 9.2), T((0, y, 9.6)))


# -----------------------------------------------------------------------------------------------------------
# 5. GauntletHandOpen — Colossal iron armored gauntlet palm-up cradling a Wardlight
# -----------------------------------------------------------------------------------------------------------
@template("GauntletHandOpen", METAL=3200, TRIM=2600, STONE=1400, ALT=900, ACCENT=700, GLOW=900)
def gauntlet_hand_open(t):
    """Colossal blackened-iron armored gauntlet resting palm-up (~26 wide, 28 tall, 26 deep) with 5 curved
    articulated iron fingers cradling a bone-white marble & gold Wardlight brazier in its palm."""
    metal, trim, stone, alt, accent, glow = (t.bm(r) for r in ("METAL", "TRIM", "STONE", "ALT", "ACCENT", "GLOW"))
    # Heavy obsidian & iron forearm cuff pedestal (Z = 0..10).
    cone(stone, 11.5, 9.4, 6.0, 12, T((0, 0, 0)))
    box(metal, (18.0, 16.0, 6.4), T((0, 1.5, 8.5)), bevel=0.35)
    ring_mesh(trim, 9.8, 1.1, 16, T((0, 1.5, 6.2)), tube_segs=5)
    # Open armored palm plate (Z = 11.5..15.5).
    box(metal, (17.5, 16.5, 3.8), T((0, -1.0, 13.4)), bevel=0.3)
    box(alt, (10.5, 10.5, 1.0), T((0, -1.0, 15.6)))
    # Four curved articulated iron fingers along the back/sides (-Y/+Y cupping inward) + opposing thumb.
    finger_specs = (
        (-7.6, 4.8, -0.35, 11.2),
        (-2.6, 6.6, -0.10, 13.0),
        (2.6, 6.6, 0.10, 13.0),
        (7.6, 4.8, 0.35, 11.0),
    )
    for fx, fy, yaw, flen in finger_specs:
        fm = T((fx, fy, 14.5)) @ R(yaw, 4, "Z")
        # Three phalanges curving upward and forward over the palm.
        p0 = fm @ Vector((0, 0, 0))
        p1 = fm @ Vector((0, -0.8, flen * 0.42))
        p2 = fm @ Vector((0, -3.2, flen * 0.78))
        p3 = fm @ Vector((0, -5.8, flen * 0.96))
        tube(metal, [p0, p1, p2, p3], [1.9, 1.65, 1.4, 1.05], 8, cap=True)
        for jp in (p1, p2):
            uvsphere(trim, 1.85, T(jp), 8, 6)
        cone(trim, 1.0, 0.12, 2.6, 4, T(p3) @ R(math.radians(-62), 4, "X"))
    # Opposing armored thumb on the +X / -Y side.
    thumb_pts = [(8.8, -2.5, 13.2), (10.8, -5.2, 16.8), (9.2, -7.8, 20.4), (6.4, -8.2, 22.2)]
    tube(metal, thumb_pts, [2.1, 1.8, 1.5, 1.1], 8, cap=True)
    cone(trim, 1.05, 0.12, 2.4, 4, T(thumb_pts[-1]) @ R(math.radians(55), 4, "Y"))
    # Wardlight brazier in the palm.
    wardlight_brazier_head(metal, trim, alt, glow, T((0, -1.2, 16.0)), scale=1.75)
    ring_mesh(accent, 4.2, 0.38, 18, T((0, -1.2, 18.2)), tube_segs=4)


# -----------------------------------------------------------------------------------------------------------
# 6. GreaveTower — Towering faceted obsidian & iron-strapped armored shin column
# -----------------------------------------------------------------------------------------------------------
@template("GreaveTower", STONE=2600, METAL=2600, TRIM=1800, ACCENT=600, SILK=700)
def greave_tower(t):
    """Towering faceted obsidian & blackened-iron armored shin column (~22 wide, 48 tall, 24 deep)
    with overlapping gothic knee-cop plates, iron strapwork, and a wine-crimson pennant strip."""
    stone, metal, trim, accent, silk = (t.bm(r) for r in ("STONE", "METAL", "TRIM", "ACCENT", "SILK"))
    # Heavy stepped obsidian plinth base.
    box(stone, (21.0, 22.0, 5.0), T((0, 0, 2.5)), bevel=0.3)
    # Tapered faceted shin core leaning slightly backward (+Y).
    lean = R(math.radians(8), 4, "X")
    cone(stone, 9.6, 6.8, 34.0, 6, T((0, 0, 5.0)) @ lean)
    # Four overlapping armored greave plates proudly proud on the front (-Y) face.
    for k in range(4):
        pz = 8.0 + k * 7.8
        pm = T((0, -5.8 + k * 1.1, pz)) @ lean @ R(math.radians(-6), 4, "X")
        box(metal, (14.4 - k * 1.1, 5.4, 8.6), pm, bevel=0.22)
        box(trim, (15.2 - k * 1.1, 6.0, 1.2), pm @ T((0, -0.3, -3.2)))
    # Gothic pointed poleyn / knee-cop crest at the crown (Z = 38..48).
    cone(metal, 7.6, 0.35, 12.0, 4, T((0, -1.6, 37.5)) @ R(math.pi / 4, 4, "Z"))
    box(accent, (1.4, 9.8, 8.5), T((0, -2.6, 41.0)))
    # Hanging wine silk tabard down the front spine.
    box(silk, (5.2, 0.9, 22.0), T((0, -9.2, 17.0)) @ R(math.radians(-5), 4, "X"))


# -----------------------------------------------------------------------------------------------------------
# 7. SabatonFoot — Colossal armored obsidian-and-iron sabaton toe & heel spur
# -----------------------------------------------------------------------------------------------------------
@template("SabatonFoot", STONE=2200, METAL=2800, TRIM=1800, MOSS=600)
def sabaton_foot(t):
    """Colossal armored obsidian-and-iron sabaton foot (~26 wide, 22 tall, 38 deep) with articulated
    overlapping lamellar toe plates tapering forward (-Y), ankle flanges, and iron heel spur."""
    stone, metal, trim, moss = (t.bm(r) for r in ("STONE", "METAL", "TRIM", "MOSS"))
    # Grounded obsidian sole plinth.
    box(stone, (24.0, 36.0, 3.6), T((0, 0, 1.8)), bevel=0.28)
    # Rear ankle cuff & iron spur (+Y).
    box(stone, (19.0, 14.0, 14.0), T((0, 10.0, 10.2)), bevel=0.3)
    box(metal, (21.0, 15.0, 3.2), T((0, 10.0, 17.5)), bevel=0.18)
    cone(trim, 2.6, 0.25, 8.5, 6, T((0, 17.0, 7.0)) @ R(math.radians(-78), 4, "X"))
    # Five articulated curved sabaton lamellar armor plates tapering toward the toe (-Y).
    for k in range(5):
        fy = 4.0 - k * 4.8
        w = 18.6 - k * 2.4
        h = 11.5 - k * 1.6
        box(metal, (w, 6.2, h), T((0, fy, 3.6 + h * 0.45)) @ R(math.radians(-10 - k * 4), 4, "X"), bevel=0.22)
        box(trim, (w + 0.8, 1.2, h + 0.6), T((0, fy - 2.6, 3.6 + h * 0.45)) @ R(math.radians(-10 - k * 4), 4, "X"))
    # Pointed iron toe-cap spike (-Y).
    cone(metal, 4.2, 0.35, 8.0, 4, T((0, -15.5, 4.2)) @ R(math.radians(82), 4, "X") @ R(math.pi / 4, 4, "Z"))
    ground_rock(moss, (10.0, 8.0, 2.2), (-9.0, -10.0, 0.0), seed=5007, roughness=0.25, subdiv=1)


# -----------------------------------------------------------------------------------------------------------
# 8. BrokenGrandStair — Shattered obsidian stair flight & torn wine runner snapping off into the void
# -----------------------------------------------------------------------------------------------------------
@template("BrokenGrandStair", STONE=2400, ALT=1200, METAL=1400, TRIM=1200, SILK=900)
def broken_grand_stair(t):
    """Shattered obsidian stair flight (~24 wide, 18 tall, 28 deep) ascending toward -Y and ending in a
    jagged fractured void lip with torn wine-crimson silk runner strips and snapped iron railings."""
    stone, alt, metal, trim, silk = (t.bm(r) for r in ("STONE", "ALT", "METAL", "TRIM", "SILK"))
    # 7 stepped obsidian risers climbing from +Y (south) toward -Y (north).
    for k in range(7):
        sy = 11.0 - k * 3.4
        sz = (k + 1) * 2.1
        w = 22.0 - (k // 5) * 3.0
        box(stone, (w, 4.2, sz), T((0, sy, sz * 0.5)), bevel=0.14)
        box(alt, (w * 0.92, 3.8, 0.45), T((0, sy, sz + 0.15)))
    # Jagged fractured north cliff face (-Y) emphasizing the impassable void drop.
    for k, (jx, jy, jh) in enumerate(((-7.0, -11.5, 11.0), (-2.0, -12.6, 13.5), (3.5, -12.2, 12.2), (8.2, -10.8, 9.5))):
        cone(stone, 3.8, 1.2, jh, 5, T((jx, jy, 0.0)) @ R(math.radians(12 - k * 4), 4, "X"))
    # Torn matte wine-silk stair runner draping up the steps and hanging raggedly over the broken lip.
    for k in range(7):
        sy = 11.0 - k * 3.4
        sz = (k + 1) * 2.1 + 0.48
        box(silk, (8.6, 4.0, 0.25), T((0, sy, sz)))
    for tx, len_d in ((-2.4, 6.2), (0.6, 8.4), (3.0, 5.2)):
        box(silk, (2.2, 0.4, len_d), T((tx, -12.2, 14.8 - len_d * 0.5)) @ R(math.radians(14), 4, "X"))
    # Snapped iron balustrades along both sides.
    for sx in (-1, 1):
        px = sx * 10.6
        for k in range(4):
            box(metal, (1.4, 1.4, 4.5 + k * 4.2), T((px, 10.0 - k * 6.5, (4.5 + k * 4.2) * 0.5)))
        strut(trim, (px, 10.0, 4.5), (px, -6.0, 15.5), 0.45)
        strut(trim, (px, -6.0, 15.5), (px, -11.5, 17.8), 0.40)


# -----------------------------------------------------------------------------------------------------------
# 9. MantleChainColossal — Sweeping colossal forged chain run hanging from the Throne's shoulders
# -----------------------------------------------------------------------------------------------------------
@template("MantleChainColossal", METAL=3400, TRIM=2800, STONE=900)
def mantle_chain_colossal(t):
    """Sweeping colossal forged chain run (~64 wide, 28 tall, 9 deep) built as a single optimised multi-link
    catenary span between two heavy obsidian-and-iron anchor shackles, with its lowest sag resting at z = 0."""
    metal, trim, stone = (t.bm(r) for r in ("METAL", "TRIM", "STONE"))
    # Left & right iron anchor brackets (lowest point on z = 0 so Min.Y = 0).
    for sx in (-1, 1):
        box(stone, (7.0, 7.0, 2.4), T((sx * 28.0, 0, 1.2)), bevel=0.2)
        box(metal, (4.8, 4.8, 22.0), T((sx * 28.0, 0, 12.2)), bevel=0.18)
        ring_mesh(trim, 2.8, 0.7, 14, T((sx * 25.5, 0, 22.0)) @ R(math.pi / 2, 4, "X"), tube_segs=5)
    heavy_chain_run(metal, trim, (-25.5, 0, 22.0), (25.5, 0, 22.0), link_h=4.6, link_w=2.8, thick=0.65, segs=12, sag=18.5)


# -----------------------------------------------------------------------------------------------------------
# 10. ChainClimbCage — Iron-barred climb frame flanking a chain ramp
# -----------------------------------------------------------------------------------------------------------
@template("ChainClimbCage", METAL=2800, TRIM=2400, STONE=1100, ALT=600, GLOW=700)
def chain_climb_cage(t):
    """Blackened-iron climb frame (~16 wide, 19 tall, 24 deep) with arched iron ribs, chain-strung side
    rails, and an overhead bone-white Wardlight beacon post."""
    metal, trim, stone, alt, glow = (t.bm(r) for r in ("METAL", "TRIM", "STONE", "ALT", "GLOW"))
    for sy in (-9.5, 0.0, 9.5):
        for sx in (-1, 1):
            px = sx * 6.8
            box(stone, (2.6, 2.6, 1.6), T((px, sy, 0.8)), bevel=0.1)
            box(metal, (1.4, 1.4, 12.5), T((px, sy, 7.8)))
        # Overhead gothic iron arch rib linking both sides (high clearance: Z = 14..18.5).
        strut(metal, (-6.8, sy, 14.0), (-3.2, sy, 17.5), 1.0)
        strut(metal, (6.8, sy, 14.0), (3.2, sy, 17.5), 1.0)
        strut(trim, (-3.2, sy, 17.5), (0.0, sy, 18.8), 0.9)
        strut(trim, (3.2, sy, 17.5), (0.0, sy, 18.8), 0.9)
    # Horizontal side guard rails & chain strands.
    for sx in (-1, 1):
        px = sx * 6.8
        strut(metal, (px, -10.5, 3.6), (px, 10.5, 3.6), 0.55)
        heavy_chain_run(metal, trim, (px, -10.0, 7.8), (px, 10.0, 7.8), link_h=2.2, link_w=1.3, thick=0.28, segs=10)
    # Central overhead Wardlight lantern hanging from the middle arch.
    wardlight_brazier_head(metal, trim, alt, glow, T((0, 0, 14.2)), scale=0.8)


# -----------------------------------------------------------------------------------------------------------
# 11. KneelingSupplicant — Hooded stone supplicant statue kneeling with bowed head
# -----------------------------------------------------------------------------------------------------------
@template("KneelingSupplicant", STONE=2200, ALT=700, METAL=900, TRIM=700, MOSS=500)
def kneeling_supplicant(t):
    """Hooded obsidian-stone supplicant statue kneeling with bowed head (~6.5 wide, 11.2 tall, 7.5 deep),
    clad in heavy pleated robes and resting clasped hands on a planted iron prayer-sword."""
    stone, alt, metal, trim, moss = (t.bm(r) for r in ("STONE", "ALT", "METAL", "TRIM", "MOSS"))
    # Grounded marble & obsidian prayer plinth.
    box(stone, (6.2, 7.2, 0.8), T((0, 0, 0.4)), bevel=0.1)
    box(alt, (5.4, 6.4, 0.3), T((0, 0, 0.95)))
    # Kneeling lower robe mass & draped knee folds (-Y forward).
    cone(stone, 2.9, 2.2, 3.6, 8, T((0, 0.4, 1.1)))
    # Bowed torso & sloped cloak shoulders.
    cone(stone, 2.3, 1.6, 4.6, 8, T((0, 0.3, 4.2)) @ R(math.radians(18), 4, "X"))
    # Deeply bowed peaked cowl / hooded head facing -Y.
    cone(stone, 1.5, 0.25, 2.6, 6, T((0, -0.7, 9.0)) @ R(math.radians(-62), 4, "X"))
    uvsphere(alt, 0.85, T((0, -1.25, 8.4)), 8, 6)
    # Clasped gauntleted arms & planted vertical iron sword in front (-Y).
    strut(metal, (-1.7, -0.3, 7.2), (0.0, -2.5, 5.8), 0.72)
    strut(metal, (1.7, -0.3, 7.2), (0.0, -2.5, 5.8), 0.72)
    box(trim, (0.45, 0.25, 4.8), T((0, -2.6, 3.5)))
    box(metal, (2.3, 0.42, 0.42), T((0, -2.6, 5.9)))
    ground_rock(moss, (3.2, 2.4, 0.8), (0, 2.6, 0.0), seed=5011, roughness=0.25, subdiv=1)


# -----------------------------------------------------------------------------------------------------------
# 12. OathRegisterWall — Tall obsidian archive wall hung with chained bronze/iron oath tablets
# -----------------------------------------------------------------------------------------------------------
@template("OathRegisterWall", STONE=2400, METAL=1600, TRIM=1400, ALT=1200, ACCENT=700, SILK=600)
def oath_register_wall(t):
    """Tall gothic obsidian archive wall (~18 wide, 24 tall, 5.5 deep) hung with chained bone-marble and
    old-gold oath tablets and matte wine-silk seal ribbons."""
    stone, metal, trim, alt, accent, silk = (t.bm(r) for r in ("STONE", "METAL", "TRIM", "ALT", "ACCENT", "SILK"))
    box(stone, (17.6, 5.2, 2.2), T((0, 0, 1.1)), bevel=0.18)
    box(stone, (15.8, 3.8, 17.5), T((0, 0.4, 10.8)), bevel=0.2)
    prism(stone, 16.4, 4.2, 4.6, T((0, 0.4, 19.4)))
    for sx in (-1, 1):
        box(metal, (2.0, 4.8, 21.0), T((sx * 7.6, 0.2, 11.5)))
        cone(trim, 1.2, 0.1, 3.2, 4, T((sx * 7.6, 0.2, 22.0)))
    # Two rows of 3 hanging chained oath tablets on the front (-Y) face.
    for row_z in (7.4, 14.6):
        for tx in (-4.4, 0.0, 4.4):
            box(alt, (3.2, 0.65, 4.8), T((tx, -1.8, row_z)), bevel=0.06)
            box(accent, (3.5, 0.75, 0.55), T((tx, -1.8, row_z + 2.3)))
            strut(trim, (tx - 1.1, -1.8, row_z + 2.5), (tx - 1.1, -1.6, row_z + 3.8), 0.16)
            strut(trim, (tx + 1.1, -1.8, row_z + 2.5), (tx + 1.1, -1.6, row_z + 3.8), 0.16)
            box(silk, (0.9, 0.25, 2.2), T((tx, -2.2, row_z - 1.4)))


# -----------------------------------------------------------------------------------------------------------
# 13. FootstoolGreat — Ornate carved obsidian & bone-marble footstool dais trim with iron corner censers
# -----------------------------------------------------------------------------------------------------------
@template("FootstoolGreat", STONE=2400, ALT=1400, METAL=1800, TRIM=1400, GLOW=700, ACCENT=500)
def footstool_great(t):
    """Ornate carved obsidian & bone-marble footstool dais trim (~32 wide, 12 tall, 18 deep) with gothic
    blind arcading and twin blackened-iron corner censers burning pale bone-white Wardlights."""
    stone, alt, metal, trim, glow, accent = (t.bm(r) for r in ("STONE", "ALT", "METAL", "TRIM", "GLOW", "ACCENT"))
    box(stone, (31.0, 16.0, 2.4), T((0, 0, 1.2)), bevel=0.2)
    box(stone, (28.0, 13.6, 4.8), T((0, 0, 4.8)), bevel=0.18)
    box(stone, (29.2, 14.4, 0.8), T((0, 0, 7.2)))
    # Subtle worn bone-marble trim inlay strips along the outer edge.
    for sy in (-6.6, 6.6):
        box(alt, (28.4, 0.8, 0.35), T((0, sy, 7.6)))
    for sx in (-13.8, 13.8):
        box(alt, (0.8, 13.2, 0.35), T((sx, 0, 7.6)))
    # Gothic arcade ribs along the front (-Y) face.
    for x in (-10.0, -5.0, 0.0, 5.0, 10.0):
        box(metal, (1.1, 1.2, 5.4), T((x, -7.0, 4.2)))
    # Twin blackened-iron corner censers on the outer ends.
    for sx in (-1, 1):
        cx = sx * 13.2
        box(stone, (3.8, 3.8, 7.2), T((cx, -5.6, 3.6)), bevel=0.12)
        wardlight_brazier_head(metal, trim, alt, glow, T((cx, -5.6, 7.2)), scale=1.05)
        ring_mesh(accent, 2.4, 0.2, 14, T((cx, -5.6, 8.6)), tube_segs=4)


# -----------------------------------------------------------------------------------------------------------
# 14. RelicCageIron — Iron-barred reliquary shrine cage housing a glowing/caged relic vessel
# -----------------------------------------------------------------------------------------------------------
@template("RelicCageIron", STONE=1200, METAL=2200, TRIM=1800, ACCENT=900, CRYSTAL=900, GLOW=600)
def relic_cage_iron(t):
    """Iron-barred reliquary shrine cage (~9 wide, 16 tall, 9 deep) on an obsidian plinth, enclosing a
    chained old-gold & blood-crystal relic vessel."""
    stone, metal, trim, accent, crystal, glow = (t.bm(r) for r in ("STONE", "METAL", "TRIM", "ACCENT", "CRYSTAL", "GLOW"))
    box(stone, (8.6, 8.6, 2.2), T((0, 0, 1.1)), bevel=0.16)
    box(metal, (7.4, 7.4, 1.0), T((0, 0, 2.7)))
    # 8 vertical gothic iron cage bars + dome crown.
    for k in range(8):
        a = 2.0 * math.pi * k / 8.0
        px, py = math.cos(a) * 3.1, math.sin(a) * 3.1
        strut(metal, (px, py, 3.2), (px, py, 10.8), 0.35)
        strut(trim, (px, py, 10.8), (0, 0, 14.2), 0.32)
    ring_mesh(trim, 3.2, 0.35, 16, T((0, 0, 10.8)), tube_segs=4)
    cone(metal, 0.85, 0.1, 2.2, 6, T((0, 0, 13.8)))
    # Caged relic urn & blood-red crystal core inside.
    lathe(accent, [(0.9, 3.4), (1.6, 5.2), (1.4, 7.2), (0.7, 8.2)], 12, Matrix.Identity(4))
    cone(crystal, 0.85, 0.15, 2.8, 6, T((0, 0, 7.8)))
    uvsphere(glow, 0.55, T((0, 0, 8.6)), 8, 6)


# -----------------------------------------------------------------------------------------------------------
# 15. ThroneHeartCrack — Jagged dark obsidian rift crack revealing deep matte red-black heartbeat fissures
# -----------------------------------------------------------------------------------------------------------
@template("ThroneHeartCrack", STONE=2600, METAL=1200, CRYSTAL=1400, SILK=900)
def throne_heart_crack(t):
    """Jagged dark obsidian rift crack (~28 wide, 22 tall, 10 deep) for the Throne's front base wall,
    revealing deep matte red-black heartbeat fissures inside the split rock (never bright Neon)."""
    stone, metal, crystal, silk = (t.bm(r) for r in ("STONE", "METAL", "CRYSTAL", "SILK"))
    # Grounded fractured obsidian base collar.
    box(stone, (26.0, 9.0, 2.4), T((0, 0, 1.2)), bevel=0.25)
    # Left & right jagged obsidian rock flanks framing an irregular vertical Y-shaped heart cleft.
    for sx in (-1, 1):
        for k, (ox, oz, w, h) in enumerate(((5.8, 6.0, 9.0, 11.0), (7.6, 12.5, 8.5, 9.5), (5.2, 17.5, 7.2, 6.5))):
            ground_rock(stone, (w, 8.0, h), (sx * ox, 0.5, oz - h * 0.45), seed=5015 + sx * 10 + k, roughness=0.28, subdiv=1)
        # Iron reinforcement staple clamps trying to hold the Throne's cracked heart shut.
        box(metal, (4.2, 1.4, 1.4), T((sx * 3.4, -3.2, 8.5)) @ R(sx * 0.25, 4, "Y"))
        box(metal, (4.0, 1.4, 1.4), T((sx * 2.8, -3.2, 14.5)) @ R(-sx * 0.2, 4, "Y"))
    # Deep red-black matte heartbeat fissure core & branching veins inside the cleft.
    fissure_pts = [(0.0, -1.6, 2.2), (-0.8, -1.9, 6.8), (0.9, -2.1, 11.4), (-0.4, -1.8, 16.2), (0.3, -1.5, 19.8)]
    tube(crystal, fissure_pts, [1.5, 2.2, 2.4, 1.8, 0.8], 6, cap=True)
    tube(silk, [(0.9, -2.1, 11.4), (3.6, -2.3, 14.6), (5.2, -2.0, 16.5)], [1.1, 0.7, 0.3], 5, cap=True)
    tube(silk, [(-0.8, -1.9, 6.8), (-3.8, -2.2, 9.4), (-5.4, -1.8, 11.2)], [1.0, 0.65, 0.3], 5, cap=True)


# -----------------------------------------------------------------------------------------------------------
# 16. BackrestBannerWine — Towering full-height matte wine-crimson silk banner with Chained Crown sigil
# -----------------------------------------------------------------------------------------------------------
@template("BackrestBannerWine", SILK=2600, METAL=1100, TRIM=900, ACCENT=1600)
def backrest_banner_wine(t):
    """Towering full-height matte wine-crimson silk banner (~18 wide, 96 tall, 4 deep) hung from a heavy
    blackened-iron crossbar and embossed with the Chained Crown sigil in muted old gold."""
    silk, metal, trim, accent = (t.bm(r) for r in ("SILK", "METAL", "TRIM", "ACCENT"))
    # Grounded lower swallowtail banner tips at z = 0..16.
    for sx in (-1, 1):
        cone(silk, 4.2, 0.35, 16.0, 4, T((sx * 4.2, 0, 16.0)) @ R(math.pi, 4, "X") @ R(math.pi / 4, 4, "Z"))
    # Main tall pleated wine-silk banner shaft (Z = 14..92).
    for k, bx in enumerate((-5.0, -2.5, 0.0, 2.5, 5.0)):
        by = 0.25 if (k % 2 == 0) else -0.25
        box(silk, (3.4, 1.2, 78.0), T((bx, by, 53.0)))
    # Gold border hem strips.
    for sx in (-1, 1):
        box(accent, (0.65, 1.4, 78.0), T((sx * 6.9, 0, 53.0)))
    # Top iron crossbar, chains & finial spears (Z = 91..96).
    cyl_x(metal, 0.85, 18.0, (0, 0, 92.5), segs=12)
    for sx in (-1, 1):
        cone(trim, 1.1, 0.1, 3.2, 4, T((sx * 9.0, 0, 92.5)) @ R(-sx * math.pi / 2, 4, "Y"))
        box(trim, (1.6, 2.2, 2.8), T((sx * 5.2, 0, 93.8)))
    # Embossed Chained Crown sigil on front (-Y) banner face.
    chained_crown_emblem(trim, metal, accent, T((0, -0.9, 58.0)), scale=0.42, broken_link=True)


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
    kit, manifest = build_kit("AbyssalF50Kit", F50_TEMPLATES, DEFAULT_BUDGET)
    apply_abyssal_preview_materials(kit)
    export_kit(kit, manifest, OUT_DIR, "AbyssalF50Kit")
    render_previews(kit, F50_TEMPLATES, OUT_DIR)
    print(json.dumps(manifest, indent=2))
