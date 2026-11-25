"""
Abyssal Throne Floor 47 (Crimson Procession) sculpted assets, generated in headless Blender.

Inspired by the Crimson Procession reference art (Abyssal Throne 47.jpg) and the Vahl oath-procession
ecosystem (docs/prompts/abyssal-throne-floor-layouts-prompt.md):
the road the oaths were carried down. Two columns -- the Sworn in hoods and the Bound in chains --
crossing at the Crossing of Oaths before the Crimson Bier and the colossal Warden-King Effigy carried
on stone bearers above the Vigil Walk, backed by bone-white Ossuary urn niches and matte wine-silk
processional stairs.

1 Blender unit = 1 stud, standing on z = 0, front facing -Y in Blender / +Z in Roblox, one mesh object
per colour role named "<Template>__<ROLE>". Every piece stands cleanly on z = 0.

Roles (AbyssalFloor47 passes the full Vahl tint override):
    STONE    obsidian & dark basalt bedrock
    ALT      bone-white Vahl marble
    METAL    blackened iron
    TRIM     dark iron & chain links
    SILK     matte deep-wine crimson silk (never Neon)
    ACCENT   old tarnished gold (Chained Crown rim & seals)
    GLOW     Wardlight bone-white / cold-silver
    CRYSTAL  blood-red geode / caged void (matte or low-emission)
    MOSS     pale ash drifts

Outputs (assets-source/tower/abyssal_f47_kit/):
    AbyssalF47Kit.blend, AbyssalF47Kit.fbx, manifest.json, previews/kit_sheet_1.png, previews/tiles/*.png.

Run:
    blender.exe --background --factory-startup --python tools/blender/generate_abyssal_f47_kit.py
"""
import bpy, bmesh, math, os, json, runpy, random
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT_DIR = os.path.join(ROOT, "assets-source", "tower", "abyssal_f47_kit")

# Shared primitives and kit pipeline ONLY from Floors 21, 26, and 41 generators.
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
chain_run, open_tome = f41["chain_run"], f41["open_tome"]
build_kit, export_kit, render_previews = f21["build_kit"], f21["export_kit"], f21["render_previews"]

T = Matrix.Translation
R = Matrix.Rotation

DEFAULT_BUDGET = 3500
F47_TEMPLATES = {}

ABYSSAL_PREVIEW_COLORS = {
    "STONE": (0.09, 0.08, 0.11, 1.0),   # obsidian / dark basalt
    "ALT": (0.86, 0.83, 0.77, 1.0),     # bone-white Vahl marble
    "METAL": (0.16, 0.16, 0.19, 1.0),   # blackened iron
    "TRIM": (0.24, 0.24, 0.28, 1.0),    # dark iron & chain
    "SILK": (0.46, 0.09, 0.14, 1.0),    # matte deep-wine crimson silk
    "ACCENT": (0.68, 0.56, 0.30, 1.0),  # old tarnished gold
    "GLOW": (0.96, 0.94, 0.88, 1.0),    # Wardlight bone-white
    "CRYSTAL": (0.44, 0.12, 0.24, 1.0), # blood-red / void shard
    "MOSS": (0.36, 0.34, 0.38, 1.0),    # pale ash
}


def template(name, **budget):
    def deco(fn):
        F47_TEMPLATES[name] = (fn, budget)
        return fn
    return deco


# -----------------------------------------------------------------------------------------------------------
# Shared Vahl architectural motifs: Chained Crown sigil, Wardlight cage, Sovereign's Urn, gothic rib arch
# -----------------------------------------------------------------------------------------------------------
def chained_crown_sigil(accent, trim, metal, mat, scale=1.0):
    """The Vahl sigil: a jagged iron-and-gold crown inside a chain ring with one broken link at the bottom."""
    s = scale
    # Outer ring of 10 chain links with the bottom link missing (Vharos's broken oath).
    for k in range(11):
        if k == 8:  # Broken link gap near bottom-right!
            continue
        ang = 2 * math.pi * k / 11 + math.pi / 2
        cx = math.cos(ang) * 1.9 * s
        cz = math.sin(ang) * 1.9 * s
        rot_y = (math.pi / 2) if (k % 2 == 1) else 0.0
        m = mat @ T((cx, 0, cz)) @ R(-ang, 4, "Y") @ R(rot_y, 4, "Z") @ R(math.pi / 2, 4, "X")
        ring_mesh(trim if k % 2 == 0 else metal, 0.38 * s, 0.10 * s, 8, m, tube_segs=4)
    # Inner crown circlet & 5 tall royal spikes.
    ring_mesh(accent, 1.10 * s, 0.13 * s, 14, mat @ T((0, 0, -0.35 * s)) @ R(math.pi / 2, 4, "X"), tube_segs=5)
    box(metal, (1.85 * s, 0.24 * s, 0.36 * s), mat @ T((0, 0, -0.35 * s)))
    for sp_x, sp_h in ((-0.75, 0.95), (-0.38, 1.15), (0.0, 1.45), (0.38, 1.15), (0.75, 0.95)):
        cone(accent, 0.16 * s, 0.02 * s, sp_h * s, 4, mat @ T((sp_x * s, 0, -0.18 * s)))


def wardlight_cage(metal, trim, glow, mat, scale=1.0):
    """Black-iron caged Wardlight lantern glowing bone-white inside."""
    s = scale
    cone(metal, 0.92 * s, 0.18 * s, 0.72 * s, 6, mat @ T((0, 0, 0.62 * s)))
    cone(metal, 0.18 * s, 0.80 * s, 0.56 * s, 6, mat @ T((0, 0, -1.25 * s)))
    ring_mesh(trim, 0.86 * s, 0.09 * s, 10, mat @ T((0, 0, 0.58 * s)), tube_segs=4)
    ring_mesh(trim, 0.78 * s, 0.09 * s, 10, mat @ T((0, 0, -0.68 * s)), tube_segs=4)
    for k in range(6):
        a = 2 * math.pi * k / 6
        p0 = mat @ Vector((math.cos(a) * 0.76 * s, math.sin(a) * 0.76 * s, -0.68 * s))
        p1 = mat @ Vector((math.cos(a) * 0.84 * s, math.sin(a) * 0.84 * s, 0.58 * s))
        strut(trim, p0, p1, 0.09 * s)
    # Bone-white Wardlight flame core inside the cage.
    cone(glow, 0.44 * s, 0.06 * s, 0.95 * s, 6, mat @ T((0, 0, -0.45 * s)))
    uvsphere(glow, 0.34 * s, mat @ T((0, 0, -0.25 * s)), 8, 6)


def sovereign_urn(metal, trim, silk, accent, mat, scale=1.0):
    """The Sovereign's Cursed Urn: blackened-iron amphora bound in iron chains with a wine-silk seal."""
    s = scale
    prof = [(0.55 * s, 0.0), (0.35 * s, 0.3 * s), (0.85 * s, 1.1 * s), (0.95 * s, 1.9 * s), (0.45 * s, 2.5 * s), (0.62 * s, 2.9 * s)]
    lathe(metal, prof, 10, mat)
    cone(accent, 0.58 * s, 0.10 * s, 0.65 * s, 8, mat @ T((0, 0, 2.9 * s)))
    ring_mesh(trim, 0.96 * s, 0.09 * s, 12, mat @ T((0, 0, 1.75 * s)), tube_segs=4)
    ring_mesh(trim, 0.80 * s, 0.08 * s, 12, mat @ T((0, 0, 1.05 * s)), tube_segs=4)
    # Wine-crimson wax/silk seal band.
    box(silk, (0.32 * s, 0.36 * s, 0.95 * s), mat @ T((0, -0.82 * s, 1.55 * s)))


def pointed_gothic_arch(stone, metal, p0, p1, arch_h, thick=1.2, rib_segs=8):
    """Pointed Gothic arch spanning between p0 and p1 in XY, peaking at +arch_h above endpoints."""
    a, b = Vector(p0), Vector(p1)
    mid = (a + b) * 0.5
    peak = mid + Vector((0, 0, arch_h))
    span = (b - a).length
    up = Vector((0, 0, 1))
    for side_pt in (a, b):
        pts = []
        for k in range(rib_segs + 1):
            t = k / rib_segs
            # Quadratic curve curving outward then sharply into pointed apex.
            p = side_pt.lerp(peak, t)
            bulge = math.sin(t * math.pi) * (arch_h * 0.24)
            pts.append((p.x, p.y, p.z + bulge))
        tube(stone, pts, [thick] * len(pts), 6, cap=True)
        pts_in = [(px, py, pz - thick * 0.45) for (px, py, pz) in pts]
        tube(metal, pts_in, [thick * 0.38] * len(pts_in), 5, cap=True)
    # Keystone drop at peak.
    box(metal, (thick * 1.3, thick * 1.3, thick * 1.6), T((peak.x, peak.y, peak.z)))


def humanoid_torso_and_head(bm_body, bm_trim, mat, h_scale=1.0, hooded=True, bowed=0.0):
    """Sculpted stone statue upper body: draped robe/torso, broad shoulders, head with hood or bowed brow."""
    s = h_scale
    # Draped lower skirt/robe column.
    cone(bm_body, 1.55 * s, 1.15 * s, 7.2 * s, 10, mat)
    # Torso & shoulders (pitched slightly if bowed).
    t_mat = mat @ T((0, 0, 7.0 * s)) @ R(bowed, 4, "X")
    cone(bm_body, 1.15 * s, 1.38 * s, 4.4 * s, 8, t_mat)
    box(bm_trim, (3.1 * s, 1.45 * s, 1.2 * s), t_mat @ T((0, 0, 4.0 * s)), bevel=0.18 * s)
    # Head & hood.
    h_mat = t_mat @ T((0, -0.15 * s, 5.4 * s)) @ R(bowed * 0.6, 4, "X")
    uvsphere(bm_body, 0.86 * s, h_mat, 10, 8)
    if hooded:
        cone(bm_body, 1.22 * s, 0.25 * s, 2.3 * s, 8, h_mat @ T((0, 0.25 * s, -0.35 * s)) @ R(math.radians(-18), 4, "X"))
        box(bm_trim, (1.8 * s, 0.4 * s, 1.4 * s), h_mat @ T((0, -0.68 * s, -0.05 * s)))


# -----------------------------------------------------------------------------------------------------------
# 1. EffigyOnBearers — Colossal >= 175-stud Warden-King Effigy on Vaulted Stone Bearers (straddles Vigil Walk)
# -----------------------------------------------------------------------------------------------------------
@template("EffigyOnBearers", STONE=5600, ALT=3200, METAL=4800, TRIM=2800, SILK=1400, ACCENT=1200, GLOW=900)
def effigy_on_bearers(t):
    """Colossal 186-stud centerpiece behind the Crimson Bier:
    - Vaulted stone bearer arch (29 studs wide open along X, 27.5 studs tall clear underneath for Vigil Walk!)
      supported by 4 sculpted stone bearers on the south face and 4 piers/bearers on the north face.
    - Atop the bearer slab (Z=35): monumental recumbent-rising black-iron Warden-King Effigy lying across
      from east (+X feet) to west (-X rising torso, folded gauntlets over greatsword, horned helm with
      the Chained Crown, wrapped in wine-crimson funeral silk).
    - Soaring iron-ribbed Gothic canopy/halo with tall bone-white Wardlight lancets and hanging chains
      rising to Z = 186."""
    stone, alt, metal, trim, silk, accent, glow = (
        t.bm(r) for r in ("STONE", "ALT", "METAL", "TRIM", "SILK", "ACCENT", "GLOW")
    )

    # Clear tunnel runs East-West along X between Y = -14.8 and +14.8 (29.6 studs wide!), Z = 0..27.5.
    pier_ys = (-17.5, 17.5)
    bearer_xs = (-18.0, -6.4, 6.4, 18.0)

    # 1) Foundation plinths, corner piers & 8 sculpted stone bearers (4 south, 4 north) outside Y in [-14.8, 14.8].
    for sy_idx, py in enumerate(pier_ys):
        face_sign = -1.0 if py < 0 else 1.0  # -1 faces -Y (front/Bier), +1 faces +Y (Ossuary)
        # Continuous stepped obsidian footing outside the walk lane.
        box(stone, (50.0, 5.4, 2.2), T((0, py, 1.1)), bevel=0.2)
        box(alt, (48.0, 4.4, 0.7), T((0, py, 2.55)))
        # Heavy end buttress towers at X = +-23.5.
        for sx in (-1, 1):
            box(stone, (5.2, 5.0, 29.0), T((sx * 23.5, py, 16.5)), bevel=0.18)
            box(metal, (5.6, 5.4, 1.1), T((sx * 23.5, py, 29.5)))
        # 4 sculpted stone bearer statues per side holding up the catafalque slab.
        for bx in bearer_xs:
            # Stepped bone-white plinth & dark basalt pedestal.
            box(alt, (4.4, 4.2, 2.0), T((bx, py, 3.8)))
            box(stone, (3.8, 3.6, 4.2), T((bx, py, 6.9)))
            # Bearer caryatid figure (legs/robe, broad torso, raised arms bracing the lintel).
            b_yaw = 0.0 if face_sign < 0 else math.pi
            b_mat = T((bx, py, 9.0)) @ R(b_yaw, 4, "Z")
            humanoid_torso_and_head(alt, stone, b_mat, h_scale=1.22, hooded=True, bowed=math.radians(-12))
            # Two raised stone arms holding up the massive lintel corbel at Z = 27.5.
            for arm_sx in (-1, 1):
                strut(alt, b_mat @ Vector((arm_sx * 1.65, 0.0, 12.2)), b_mat @ Vector((arm_sx * 1.45, -0.5, 18.6)), 0.78)
            box(stone, (4.2, 4.4, 2.2), T((bx, py, 27.4)))

    # 2) Vaulted overhead bearer arch & monumental Catafalque Slab (Z = 27.5..35.2).
    # Clear underside is Z >= 27.5 across the entire Y in [-14.8, +14.8] Vigil Walk!
    for x_rib in (-22.0, -14.0, -6.4, 0.0, 6.4, 14.0, 22.0):
        box(stone, (2.4, 39.2, 2.4), T((x_rib, 0, 28.8)))
        box(metal, (1.1, 39.6, 1.2), T((x_rib, 0, 28.2)))
    # Main monumental black-obsidian bearer deck slab.
    box(stone, (52.0, 40.0, 4.2), T((0, 0, 32.1)), bevel=0.35)
    box(alt, (53.2, 41.2, 1.0), T((0, 0, 34.4)))
    box(metal, (52.6, 40.6, 1.1), T((0, 0, 30.2)))
    # Iron chain garlands draped along the south & north slab edges (staying above Z = 26.5, clear of walk!).
    for py in (-19.6, 19.6):
        for k in range(3):
            x0, x1 = bearer_xs[k], bearer_xs[k + 1]
            pts = []
            for s_i in range(9):
                f = s_i / 8.0
                pts.append((x0 + (x1 - x0) * f, py, 30.2 - math.sin(f * math.pi) * 2.4))
            tube(trim, pts, [0.28] * len(pts), 5, cap=True)

    # 3) Colossal Recumbent-Rising Warden-King Effigy (Z = 35..98).
    # Bier cradle on top of the bearer slab.
    box(stone, (42.0, 18.0, 3.6), T((0, -2.0, 36.8)), bevel=0.25)
    box(silk, (40.5, 18.8, 1.8), T((0, -2.0, 38.6)))  # Wine-crimson funeral pall under the King.

    # Lower armoured legs & draped funeral cloak stretched toward +X (east).
    for sy in (-2.6, 2.6):
        # Black-iron greaves & sabatons.
        cyl_x(metal, 2.4, 16.5, (10.5, -2.0 + sy, 41.5), segs=10, r2=1.9)
        box(metal, (4.2, 3.4, 6.2), T((19.5, -2.0 + sy, 42.6)), bevel=0.2)  # Upright armoured sabatons.
        box(trim, (2.6, 3.7, 1.2), T((16.5, -2.0 + sy, 41.5)))
    # Heavy matte wine-silk burial drapery sweeping from knees (+X) up under the rising torso (-X).
    box(silk, (22.0, 12.0, 4.6), T((6.5, -2.0, 42.0)) @ R(math.radians(-8), 4, "Y"), bevel=0.35)

    # Rising colossal torso, broad Dreadguard pauldrons, gauntlets, greatsword & Chained Crown helm (-X).
    torso_m = T((-4.5, -2.0, 50.0)) @ R(math.radians(36), 4, "Y")
    box(metal, (15.5, 11.5, 8.2), torso_m, bevel=0.45)  # Breastplate rising westward.
    box(trim, (14.0, 12.1, 1.6), torso_m @ T((0, 0, 1.8)))  # Chest harness band.
    box(accent, (3.2, 12.2, 3.2), torso_m @ T((-2.0, 0, 2.5)) @ R(math.pi / 4, 4, "Y"))
    # Broad spiked Dreadguard pauldrons.
    for sy in (-1, 1):
        p_m = torso_m @ T((-5.0, sy * 7.2, 2.6)) @ R(sy * 0.35, 4, "X")
        uvsphere(metal, 4.2, p_m, 10, 8)
        cone(trim, 1.1, 0.08, 4.2, 4, p_m @ T((0, sy * 2.2, 2.8)) @ R(-sy * 0.5, 4, "X"))
    # Crowned Head & Horned Black-Iron Helm rising above the shoulders (around X = -12, Z = 65..78).
    head_m = T((-11.8, -2.0, 66.5)) @ R(math.radians(24), 4, "Y")
    uvsphere(metal, 3.6, head_m, 12, 10)
    box(trim, (2.2, 5.2, 4.8), head_m @ T((-1.8, 0, -0.4)))  # Visor plate.
    box(glow, (0.4, 3.2, 0.55), head_m @ T((-3.1, 0, 0.6)))   # Faint pale bone-white eye slit!
    # The Chained Crown on the King's helm.
    ring_mesh(accent, 3.5, 0.55, 16, head_m @ T((0, 0, 2.8)), tube_segs=5)
    for k in range(8):
        a = 2 * math.pi * k / 8
        cone(accent if k % 2 == 0 else metal, 0.55, 0.05, 3.8 if k % 2 == 0 else 2.6, 4,
             head_m @ T((math.cos(a) * 3.3, math.sin(a) * 3.3, 3.0)))
    # Gauntleted hands folded over colossal upright greatsword (rising beside chest to Z = 90).
    for sy in (-1, 1):
        strut(metal, torso_m @ Vector((-3.5, sy * 6.4, 0.5)), (-2.5, -2.0 + sy * 2.4, 58.0), 1.9)
    # Colossal Warden-King Greatsword planted vertically through the bier/hands.
    box(trim, (1.6, 2.6, 44.0), T((-2.0, -2.0, 60.0)))
    box(metal, (2.2, 11.5, 1.6), T((-2.0, -2.0, 74.0)))  # Broad crossguard.
    cyl_z(accent, 1.1, 6.2, (-2.0, -2.0, 74.8), segs=8)   # Hilt grip.
    uvsphere(accent, 1.65, T((-2.0, -2.0, 82.0)), 8, 6)    # Crown pommel.

    # 4) Soaring Iron-Ribbed Gothic Canopy & Halo behind the Effigy (Z = 35..186)!
    # Positioned on the north side of the slab (Y = +10..+16) + outer flanking cathedral buttresses (X = +-23.5)
    # so it frames the Effigy like a monumental gothic reliquary halo against the black vault!
    for sx in (-1, 1):
        # Outer colossal twin spire buttresses rising from Z = 35 to Z = 154.
        bx = sx * 22.5
        for by in (-9.0, 12.5):
            cone(stone, 2.8, 1.4, 115.0, 6, T((bx, by, 35.0)))
            cone(metal, 1.6, 0.08, 22.0, 6, T((bx, by, 150.0)))
            ring_mesh(trim, 2.2, 0.32, 10, T((bx, by, 95.0)), tube_segs=4)
            ring_mesh(trim, 1.8, 0.28, 10, T((bx, by, 128.0)), tube_segs=4)
        # Inner main Gothic canopy piers on the north rim (Y = +13.5, X = +-13.5).
        ix = sx * 13.5
        cone(stone, 3.2, 1.8, 120.0, 8, T((ix, 13.5, 35.0)))
        box(metal, (3.8, 3.8, 2.0), T((ix, 13.5, 155.0)))
        cone(trim, 1.5, 0.08, 18.0, 4, T((ix, 13.5, 156.5)))

    # Great pointed Gothic cathedral arch & rising spire crown (Z = 115..186).
    pointed_gothic_arch(stone, metal, (-22.5, 12.5, 105.0), (22.5, 12.5, 105.0), arch_h=56.0, thick=2.0, rib_segs=10)
    pointed_gothic_arch(metal, trim, (-13.5, 13.5, 118.0), (13.5, 13.5, 118.0), arch_h=48.0, thick=1.5, rib_segs=8)
    # Central soaring crown-spire pinnacle reaching Z = 186.0 (>= 175 studs!).
    cone(stone, 3.6, 1.4, 24.0, 8, T((0, 13.0, 154.0)))
    cone(metal, 1.8, 0.06, 16.0, 6, T((0, 13.0, 170.0)))
    # Colossal Chained Crown halo centred inside the upper gothic arch (Z = 136).
    chained_crown_sigil(accent, trim, metal, T((0, 11.0, 136.0)), scale=4.2)

    # Tall bone-white Wardlight lancet ribs & draped canopy chains high inside the canopy (Z >= 72!).
    for sx in (-1, 0, 1):
        lx = sx * 6.5
        lh = 76.0 if sx == 0 else 58.0
        box(glow, (0.75, 0.55, lh), T((lx, 12.2, 72.0 + lh * 0.5)))
        box(trim, (1.35, 0.9, lh + 1.2), T((lx, 12.7, 72.0 + lh * 0.5)))
    # Hanging iron chains from the upper gothic ribs down to the Effigy's flanks.
    for sx in (-1, 1):
        chain_run(trim, metal, (sx * 18.0, 10.0, 132.0), (sx * 14.0, 2.0, 68.0), link_h=3.6, link_w=2.1, thick=0.38)
        chain_run(trim, metal, (sx * 10.5, 11.5, 146.0), (sx * 7.5, 1.0, 82.0), link_h=3.2, link_w=1.8, thick=0.34)


# -----------------------------------------------------------------------------------------------------------
# 2. CrimsonBierCatafalque — Raised black-marble catafalque draped in matte wine silk
# -----------------------------------------------------------------------------------------------------------
@template("CrimsonBierCatafalque", STONE=2200, ALT=1200, SILK=2400, METAL=1800, TRIM=1000, ACCENT=700, GLOW=400)
def crimson_bier_catafalque(t):
    """Raised black-marble catafalque draped in matte deep-wine crimson silk under a four-post iron
    baldachin canopy with Chained Crown finials and corner Wardlight sconces. About 14 wide, 22 tall, 10 deep."""
    stone, alt, silk, metal, trim, accent, glow = (
        t.bm(r) for r in ("STONE", "ALT", "SILK", "METAL", "TRIM", "ACCENT", "GLOW")
    )
    # Stepped black-obsidian & bone-white plinth.
    box(stone, (14.0, 10.0, 1.2), T((0, 0, 0.6)), bevel=0.12)
    box(alt, (12.4, 8.6, 0.65), T((0, 0, 1.5)), bevel=0.06)
    box(stone, (10.8, 7.0, 2.8), T((0, 0, 3.2)), bevel=0.14)
    # Matte wine-silk pall draped across the catafalque slab.
    box(silk, (11.2, 7.4, 0.8), T((0, 0, 4.9)), bevel=0.12)
    box(silk, (9.8, 8.2, 2.4), T((0, 0, 3.8)), bevel=0.15)
    # Shrouded ceremonial sword-form resting atop the bier.
    box(silk, (6.4, 2.2, 0.95), T((0, 0, 5.5)), bevel=0.18)
    box(metal, (7.6, 0.55, 0.35), T((0, 0, 6.0)))
    box(metal, (0.55, 2.4, 0.45), T((-2.4, 0, 6.1)))

    # Four blackened-iron baldachin posts rising to Z = 15.5.
    for sx in (-1, 1):
        for sy in (-1, 1):
            px, py = sx * 5.6, sy * 3.6
            box(stone, (1.5, 1.5, 1.8), T((px, py, 0.9)))
            cyl_z(metal, 0.38, 13.8, (px, py, 1.8), segs=10)
            ring_mesh(accent, 0.52, 0.12, 10, T((px, py, 15.6)), tube_segs=4)
            cone(metal, 0.48, 0.04, 2.2, 6, T((px, py, 15.8)))
            # Small Wardlight sconce mounted high on the front posts (Z = 12.2).
            if sy == -1:
                wardlight_cage(metal, trim, glow, T((px, py - 0.8, 12.2)), scale=0.58)

    # Peaked matte wine-silk baldachin canopy & Chained Crown crest (Z = 15.2..22.0).
    box(metal, (12.2, 8.2, 0.7), T((0, 0, 15.3)))
    box(silk, (11.8, 7.8, 1.4), T((0, 0, 14.5)))
    # Hanging wine-silk corner valances.
    for sy in (-1, 1):
        box(silk, (11.4, 0.35, 3.6), T((0, sy * 3.7, 13.2)))
    for sx in (-1, 1):
        box(silk, (0.35, 7.4, 3.6), T((sx * 5.7, 0, 13.2)))
    # Sloped canopy roof.
    cone(silk, 6.2, 1.2, 4.0, 4, T((0, 0, 15.6)) @ R(math.pi / 4, 4, "Z") @ Matrix.Diagonal((1.4, 0.95, 1.0, 1.0)))
    chained_crown_sigil(accent, trim, metal, T((0, 0, 20.4)), scale=0.85)


# -----------------------------------------------------------------------------------------------------------
# 3. ProcessionerSworn — Hooded pale-stone processioner statue with cold censer
# -----------------------------------------------------------------------------------------------------------
@template("ProcessionerSworn", STONE=1100, ALT=2200, METAL=900, TRIM=600, GLOW=300)
def processioner_sworn(t):
    """Solemn hooded stone processioner statue of the Sworn column: bone-white carved robe & cowl
    over an obsidian octagonal plinth, holding an iron oath-scroll & swinging a cold Wardlight censer."""
    stone, alt, metal, trim, glow = (t.bm(r) for r in ("STONE", "ALT", "METAL", "TRIM", "GLOW"))
    # Stepped octagonal obsidian & bone-white plinth.
    cone(stone, 2.8, 2.5, 1.0, 8, T((0, 0, 0)) @ R(math.pi / 8, 4, "Z"))
    cone(alt, 2.3, 2.1, 0.8, 8, T((0, 0, 1.0)) @ R(math.pi / 8, 4, "Z"))
    cone(stone, 2.0, 1.8, 2.4, 8, T((0, 0, 1.8)) @ R(math.pi / 8, 4, "Z"))
    # Standing hooded figure (Z = 4.2..19.0).
    humanoid_torso_and_head(alt, stone, T((0, 0, 4.2)), h_scale=1.08, hooded=True, bowed=math.radians(6))
    # Folded stone arms & suspended iron censer in front (-Y).
    for sx in (-1, 1):
        strut(alt, (sx * 1.45, 0.0, 14.5), (sx * 0.45, -1.35, 12.2), 0.48)
    # Oath scroll held in left hand, censer chain from right hand.
    cyl_x(alt, 0.28, 2.1, (-0.35, -1.45, 12.2), segs=8)
    box(metal, (0.35, 0.72, 0.72), T((0.55, -1.45, 12.2)))
    chain_run(trim, metal, (0.65, -1.45, 12.0), (0.65, -1.85, 8.8), link_h=0.95, link_w=0.55, thick=0.10)
    wardlight_cage(metal, trim, glow, T((0.65, -1.85, 7.8)), scale=0.65)


# -----------------------------------------------------------------------------------------------------------
# 4. ProcessionerBound — Chained dark-basalt processioner statue
# -----------------------------------------------------------------------------------------------------------
@template("ProcessionerBound", STONE=2200, ALT=900, METAL=1400, TRIM=1600)
def processioner_bound(t):
    """Bowed dark-basalt processioner statue of the Bound column: iron neck-yoke, wrist shackles, and
    heavy iron chains binding torso and plinth. About 18.8 studs tall."""
    stone, alt, metal, trim = (t.bm(r) for r in ("STONE", "ALT", "METAL", "TRIM"))
    # Stepped octagonal basalt & bone-white plinth.
    cone(stone, 2.8, 2.5, 1.0, 8, T((0, 0, 0)) @ R(math.pi / 8, 4, "Z"))
    cone(alt, 2.3, 2.1, 0.7, 8, T((0, 0, 1.0)) @ R(math.pi / 8, 4, "Z"))
    cone(stone, 2.0, 1.8, 2.5, 8, T((0, 0, 1.7)) @ R(math.pi / 8, 4, "Z"))
    # Bowed unhooded figure in dark basalt stone.
    humanoid_torso_and_head(stone, metal, T((0, 0, 4.2)), h_scale=1.06, hooded=False, bowed=math.radians(16))
    # Iron neck-yoke & bound arms pulled forward.
    box(metal, (3.6, 1.1, 0.65), T((0, -0.5, 15.6)), bevel=0.08)
    for sx in (-1, 1):
        strut(stone, (sx * 1.4, 0.0, 14.4), (sx * 0.55, -1.55, 11.4), 0.45)
        ring_mesh(metal, 0.48, 0.14, 8, T((sx * 0.55, -1.55, 11.4)), tube_segs=4)
    # Helical iron chains wrapping the torso & dropping to the plinth shackles.
    chain_run(trim, metal, (-1.4, -0.9, 15.4), (1.3, -1.1, 11.4), link_h=1.0, link_w=0.6, thick=0.12)
    chain_run(trim, metal, (1.4, -0.9, 15.4), (-1.3, -1.1, 11.4), link_h=1.0, link_w=0.6, thick=0.12)
    chain_run(trim, metal, (-0.55, -1.55, 11.2), (-1.65, -1.65, 4.2), link_h=1.1, link_w=0.65, thick=0.12)
    chain_run(trim, metal, (0.55, -1.55, 11.2), (1.65, -1.65, 4.2), link_h=1.1, link_w=0.65, thick=0.12)


# -----------------------------------------------------------------------------------------------------------
# 5. KneelingStatue — Kneeling stone vigil figure for stairs & galleries
# -----------------------------------------------------------------------------------------------------------
@template("KneelingStatue", STONE=1000, ALT=1800, METAL=700, SILK=600)
def kneeling_statue(t):
    """Kneeling stone vigil figure flanking the Processional Stairs: bone-white robe kneeling on an
    obsidian plinth, wine-crimson shoulder stole, and hands resting on an upright iron oath-sword."""
    stone, alt, metal, silk = (t.bm(r) for r in ("STONE", "ALT", "METAL", "SILK"))
    # Low obsidian & bone-white plinth.
    box(stone, (4.4, 5.4, 0.9), T((0, 0, 0.45)), bevel=0.1)
    box(alt, (3.8, 4.8, 0.5), T((0, 0, 1.15)), bevel=0.06)
    # Kneeling lower legs & trailing cloak extending back (+Y).
    box(alt, (2.6, 3.6, 2.2), T((0, 0.5, 2.4)), bevel=0.28)
    # Upright/bowed torso, wine stole & hooded head (Z = 3.2..9.5).
    k_mat = T((0, -0.35, 3.3)) @ R(math.radians(14), 4, "X")
    cone(alt, 1.35, 1.10, 3.6, 8, k_mat)
    box(silk, (1.25, 1.55, 2.75), k_mat @ T((0, -0.45, 2.05)))
    uvsphere(alt, 0.72, k_mat @ T((0, -0.25, 4.4)), 8, 6)
    cone(alt, 0.98, 0.22, 1.7, 8, k_mat @ T((0, 0.1, 4.2)) @ R(math.radians(-16), 4, "X"))
    # Arms resting forward on an upright iron oath-sword planted at (0, -1.75, 1.4).
    for sx in (-1, 1):
        strut(alt, k_mat @ Vector((sx * 1.15, 0.0, 2.8)), (0.0, -1.75, 5.4), 0.36)
    box(metal, (0.28, 0.55, 4.4), T((0, -1.75, 3.6)))
    box(metal, (1.65, 0.36, 0.32), T((0, -1.75, 5.8)))
    cyl_z(metal, 0.18, 1.1, (0, -1.75, 5.95), segs=6)


# -----------------------------------------------------------------------------------------------------------
# 6. ProcessionalStairRunner — Ornate iron-and-wine-silk banner pylon / stair flanker
# -----------------------------------------------------------------------------------------------------------
@template("ProcessionalStairRunner", STONE=1200, ALT=900, METAL=1400, TRIM=800, SILK=1200, ACCENT=400, GLOW=400)
def processional_stair_runner(t):
    """Ornate iron-and-wine-silk stair flanker pylon: stepped obsidian & bone-white marble newel pier,
    arched blackened-iron gothic arm supporting a matte wine-crimson silk runner banner with Chained Crown
    bar, and a caged bone-white Wardlight hanging above the stair edge. About 5.5 wide, 18.5 tall."""
    stone, alt, metal, trim, silk, accent, glow = (
        t.bm(r) for r in ("STONE", "ALT", "METAL", "TRIM", "SILK", "ACCENT", "GLOW")
    )
    # Stepped obsidian & bone-white newel pier.
    box(stone, (3.8, 3.8, 1.2), T((0, 0, 0.6)), bevel=0.1)
    box(alt, (3.1, 3.1, 0.8), T((0, 0, 1.6)), bevel=0.08)
    box(stone, (2.6, 2.6, 5.2), T((0, 0, 4.6)), bevel=0.1)
    box(alt, (3.0, 3.0, 0.7), T((0, 0, 7.55)))
    # Fluted iron mast & gothic spear finial.
    cyl_z(metal, 0.42, 9.6, (0, 0, 7.9), segs=10)
    cone(accent, 0.56, 0.04, 1.8, 4, T((0, 0, 17.5)))
    # Cantilevered iron banner cross-arm & hanging matte wine-silk banner (-X side toward stair).
    strut(metal, (0, 0, 15.6), (-3.8, 0, 15.6), 0.24)
    strut(trim, (0, 0, 13.0), (-3.2, 0, 15.6), 0.16)
    box(accent, (2.6, 0.35, 0.35), T((-1.8, 0, 15.2)))
    box(silk, (2.1, 0.22, 8.2), T((-1.8, 0, 10.9)))
    cone(silk, 1.2, 0.05, 1.6, 4, T((-1.8, 0, 6.8)) @ R(math.pi, 4, "X") @ R(math.pi / 4, 4, "Z"))
    # Suspended Wardlight cage on forward iron bracket (-Y).
    strut(metal, (0, 0, 13.8), (0, -2.2, 13.8), 0.20)
    wardlight_cage(metal, trim, glow, T((0, -2.2, 12.3)), scale=0.72)


# -----------------------------------------------------------------------------------------------------------
# 7. OathLectern — Iron-and-obsidian lectern holding an open chained oath register
# -----------------------------------------------------------------------------------------------------------
@template("OathLectern", STONE=900, ALT=900, METAL=1400, TRIM=900, SILK=900, ACCENT=500, GLOW=300)
def oath_lectern(t):
    """Iron-and-obsidian oath lectern on a stepped bone-white marble plinth: Chained Crown relief on the
    pedestal, sloped lectern cradle holding an open chained oath register, and a small reading Wardlight."""
    stone, alt, metal, trim, silk, accent, glow = (
        t.bm(r) for r in ("STONE", "ALT", "METAL", "TRIM", "SILK", "ACCENT", "GLOW")
    )
    box(stone, (4.2, 3.8, 0.7), T((0, 0, 0.35)), bevel=0.08)
    box(alt, (3.4, 3.0, 0.5), T((0, 0, 0.95)), bevel=0.06)
    lathe(metal, [(1.1, 1.2), (0.65, 2.2), (0.55, 4.6), (0.95, 5.6)], 10, Matrix.Identity(4))
    chained_crown_sigil(accent, trim, metal, T((0, -0.78, 3.6)), scale=0.48)
    # Sloped iron desk facing -Y.
    desk_m = T((0, -0.1, 5.8)) @ R(math.radians(-24), 4, "X")
    box(stone, (3.8, 2.8, 0.35), desk_m, bevel=0.06)
    box(metal, (4.0, 3.0, 0.22), desk_m @ T((0, 0, -0.15)))
    open_tome(silk, alt, accent, desk_m @ T((0, 0, 0.28)), w=3.0, d=2.1, page_h=0.45, spread=0.25)
    # Iron chain fastening the tome down to the base.
    chain_run(trim, metal, (1.5, -0.5, 5.5), (1.3, -0.9, 1.2), link_h=0.85, link_w=0.48, thick=0.09)
    # Small reading Wardlight lantern perched on top-left corner.
    strut(metal, (-1.6, 0.9, 6.2), (-1.6, 0.9, 7.6), 0.12)
    wardlight_cage(metal, trim, glow, T((-1.6, 0.4, 7.3)), scale=0.45)


# -----------------------------------------------------------------------------------------------------------
# 8. OathTabletChained — Stone oath stele wrapped in iron chains
# -----------------------------------------------------------------------------------------------------------
@template("OathTabletChained", STONE=1200, ALT=1400, METAL=1400, TRIM=1600, SILK=500, ACCENT=500)
def oath_tablet_chained(t):
    """Weathered bone-white marble & obsidian oath stele mounted in a riveted blackened-iron frame,
    bound diagonally in heavy iron chains and sealed with a Chained Crown and wine-silk ribbon."""
    stone, alt, metal, trim, silk, accent = (
        t.bm(r) for r in ("STONE", "ALT", "METAL", "TRIM", "SILK", "ACCENT")
    )
    # Stepped plinth & iron frame piers.
    box(stone, (6.8, 3.6, 1.0), T((0, 0, 0.5)), bevel=0.1)
    box(alt, (5.8, 2.8, 0.6), T((0, 0, 1.3)), bevel=0.06)
    for sx in (-1, 1):
        box(metal, (0.75, 1.8, 11.4), T((sx * 2.75, 0, 7.3)))
        cone(metal, 0.48, 0.04, 1.4, 4, T((sx * 2.75, 0, 13.0)))
    # Tall bone-white carved oath slab + iron header.
    box(alt, (4.8, 1.2, 10.6), T((0, 0, 6.9)), bevel=0.08)
    box(stone, (3.8, 1.35, 8.6), T((0, 0, 6.8)))
    for rz in (3.6, 5.6, 7.6, 9.6):
        box(alt, (3.4, 1.45, 0.36), T((0, 0, rz)))
    box(metal, (6.4, 2.0, 0.9), T((0, 0, 12.5)))
    # Crisscrossing iron chains binding the tablet.
    chain_run(trim, metal, (-2.6, -0.95, 11.6), (2.6, -0.95, 2.4), link_h=1.1, link_w=0.65, thick=0.13)
    chain_run(trim, metal, (2.6, -0.95, 11.6), (-2.6, -0.95, 2.4), link_h=1.1, link_w=0.65, thick=0.13)
    # Chained Crown seal & wine-silk ribbon hanging from top center.
    chained_crown_sigil(accent, trim, metal, T((0, -1.1, 10.8)), scale=0.62)
    box(silk, (1.1, 0.18, 4.4), T((0, -1.05, 8.2)))


# -----------------------------------------------------------------------------------------------------------
# 9. MournerVeiled — Veiled stone mourner statue in matte wine shroud
# -----------------------------------------------------------------------------------------------------------
@template("MournerVeiled", STONE=1000, ALT=900, SILK=2000, METAL=800, TRIM=400, GLOW=300)
def mourner_veiled(t):
    """Bowed veiled stone mourner statue draped head-to-foot in a matte deep-wine crimson shroud over
    a bone-white marble plinth, clutching a cold iron votive lantern. About 15.2 studs tall."""
    stone, alt, silk, metal, trim, glow = (t.bm(r) for r in ("STONE", "ALT", "SILK", "METAL", "TRIM", "GLOW"))
    cone(stone, 2.6, 2.3, 0.9, 8, T((0, 0, 0)) @ R(math.pi / 8, 4, "Z"))
    cone(alt, 2.1, 1.9, 0.7, 8, T((0, 0, 0.9)) @ R(math.pi / 8, 4, "Z"))
    # Shrouded column & draped wine-silk veil.
    cone(stone, 1.55, 1.05, 8.4, 10, T((0, 0, 1.6)))
    cone(silk, 1.72, 1.18, 8.8, 10, T((0, 0.15, 1.6)) @ R(math.radians(5), 4, "X"))
    # Bowed shrouded head & drooping veil.
    hm = T((0, -0.35, 11.6)) @ R(math.radians(22), 4, "X")
    uvsphere(silk, 1.05, hm, 10, 8)
    cone(silk, 1.25, 0.28, 2.6, 8, hm @ T((0, 0.25, -0.45)) @ R(math.radians(-18), 4, "X"))
    box(metal, (0.65, 0.4, 0.95), hm @ T((0, -0.82, -0.75)))
    # Arms clutching a small cold Wardlight lantern before the chest.
    for sx in (-1, 1):
        strut(silk, (sx * 1.15, 0.0, 9.8), (0.0, -1.45, 8.2), 0.42)
    wardlight_cage(metal, trim, glow, T((0, -1.65, 7.2)), scale=0.55)


# -----------------------------------------------------------------------------------------------------------
# 10. SilkLoomShrine — Tall obsidian & iron loom strung with matte crimson silk banners
# -----------------------------------------------------------------------------------------------------------
@template("SilkLoomShrine", STONE=1800, ALT=1200, METAL=1800, TRIM=1200, SILK=2400, ACCENT=600, GLOW=400)
def silk_loom_shrine(t):
    """Shrine of Silk centerpiece: stepped obsidian & bone-white altar dais supporting a towering
    blackened-iron vertical loom strung with taut warp threads and cascading bolts of matte deep-wine
    crimson silk, crowned with Chained Crown finials and bone-white Wardlights."""
    stone, alt, metal, trim, silk, accent, glow = (
        t.bm(r) for r in ("STONE", "ALT", "METAL", "TRIM", "SILK", "ACCENT", "GLOW")
    )
    # Stepped altar dais.
    box(stone, (15.6, 7.4, 1.2), T((0, 0, 0.6)), bevel=0.12)
    box(alt, (14.2, 6.2, 0.8), T((0, 0, 1.6)), bevel=0.08)
    box(stone, (12.0, 4.6, 1.6), T((0, 0, 2.8)), bevel=0.1)
    # Twin tall obsidian & blackened-iron loom uprights.
    for sx in (-1, 1):
        px = sx * 5.6
        box(stone, (2.2, 2.4, 15.2), T((px, 0, 11.0)), bevel=0.12)
        box(metal, (2.5, 2.7, 0.9), T((px, 0, 18.8)))
        cone(metal, 0.95, 0.06, 3.2, 4, T((px, 0, 19.3)) @ R(math.pi / 4, 4, "Z"))
        wardlight_cage(metal, trim, glow, T((px, -2.0, 16.5)), scale=0.72)
    # Upper & lower loom roller beams.
    cyl_x(metal, 0.65, 11.4, (0, 0, 17.6), segs=12)
    cyl_x(metal, 0.55, 11.4, (0, 0, 5.2), segs=12)
    box(stone, (13.4, 2.0, 1.4), T((0, 0, 19.2)))
    chained_crown_sigil(accent, trim, metal, T((0, -1.1, 20.6)), scale=0.95)
    # Taut vertical iron warp threads & cascading wine-silk panels.
    for k in range(11):
        wx = -4.2 + k * 0.84
        strut(trim, (wx, 0.35, 5.2), (wx, 0.35, 17.6), 0.08)
    for px, pw, drop in ((-3.0, 2.6, 12.2), (0.0, 3.2, 13.4), (3.0, 2.6, 12.0)):
        box(silk, (pw, 0.32, drop), T((px, -0.35, 17.6 - drop * 0.5)))
    # Pooled folded bolts of wine silk resting on the altar shelf.
    box(silk, (4.8, 2.4, 1.2), T((-2.4, -1.4, 4.1)), bevel=0.2)
    box(silk, (4.0, 2.2, 1.0), T((2.6, -1.4, 4.0)), bevel=0.2)


# -----------------------------------------------------------------------------------------------------------
# 11. IronForgeShrine — Cold iron oath-anvil shrine with chained tongs & quenched blades (zero orange!)
# -----------------------------------------------------------------------------------------------------------
@template("IronForgeShrine", STONE=2000, ALT=1000, METAL=2800, TRIM=1600, SILK=900, GLOW=400)
def iron_forge_shrine(t):
    """Shrine of Iron centerpiece: cold blackened-iron oath-anvil before a dark obsidian hearth hood
    (cold and quenched -- zero fire/orange!), racks of quenched hooked oath-blades, chained tongs,
    a matte wine banner, and a bone-white Wardlight lantern on a jib arm."""
    stone, alt, metal, trim, silk, glow = (
        t.bm(r) for r in ("STONE", "ALT", "METAL", "TRIM", "SILK", "GLOW")
    )
    # Stepped dark basalt & bone-white floor plinth.
    box(stone, (13.6, 9.2, 1.2), T((0, 0, 0.6)), bevel=0.12)
    box(alt, (12.2, 7.8, 0.6), T((0, 0, 1.5)), bevel=0.08)
    # Back cold obsidian hearth hood & chimney flue (+Y).
    box(stone, (9.4, 3.6, 6.2), T((0, 2.4, 4.8)), bevel=0.15)
    cone(stone, 5.4, 2.2, 6.4, 4, T((0, 2.4, 7.9)) @ R(math.pi / 4, 4, "Z"))
    box(stone, (3.2, 3.2, 4.0), T((0, 2.4, 14.5)))
    box(metal, (3.6, 3.6, 0.7), T((0, 2.4, 16.5)))
    # Recessed cold dark-iron hearth chamber (no ember/orange).
    box(trim, (5.6, 1.2, 3.6), T((0, 0.9, 4.2)))
    # Hanging wine banner & iron chains from the hood.
    box(silk, (2.8, 0.25, 5.2), T((0, 0.4, 11.0)))
    chain_run(trim, metal, (-3.6, 0.8, 8.2), (-3.6, -0.4, 4.2), link_h=0.9, link_w=0.5, thick=0.10)
    # Monumental blackened-iron Oath-Anvil in front (-Y).
    box(stone, (3.4, 2.8, 1.8), T((0, -1.8, 2.6)))
    box(metal, (5.8, 2.2, 1.8), T((0, -1.8, 4.4)), bevel=0.12)
    cone(metal, 1.1, 0.22, 2.4, 8, T((-2.8, -1.8, 4.5)) @ R(-math.pi / 2, 4, "Y"))
    # Quenched hooked oath-blade rack on east flank (+X).
    box(metal, (3.4, 1.6, 0.45), T((4.8, -1.4, 1.9)))
    for k in range(4):
        bx = 3.6 + k * 0.8
        cyl_z(trim, 0.11, 5.4, (bx, -1.4, 2.1), segs=6)
        box(metal, (0.20, 0.75, 1.6), T((bx, -1.5, 6.6)))
    # Cold Wardlight lantern hanging from a forged jib arm on west flank (-X).
    strut(metal, (-4.6, 1.4, 1.8), (-4.6, 1.4, 11.4), 0.28)
    strut(metal, (-4.6, 1.4, 11.4), (-4.2, -1.6, 11.4), 0.22)
    wardlight_cage(metal, trim, glow, T((-4.2, -1.6, 10.0)), scale=0.72)


# -----------------------------------------------------------------------------------------------------------
# 12. ChainVotiveRack — Iron gallows frame hung with votive chains & bone oath-tags
# -----------------------------------------------------------------------------------------------------------
@template("ChainVotiveRack", STONE=1000, ALT=1200, METAL=1800, TRIM=2200, SILK=600, GLOW=400)
def chain_votive_rack(t):
    """Blackened-iron votive rack for the Chapel of Chains: twin stepped stone footings, iron crossbeams
    hung with dozens of small iron votive chains, bone-white oath-tags, wine ribbons, and high Wardlights."""
    stone, alt, metal, trim, silk, glow = (t.bm(r) for r in ("STONE", "ALT", "METAL", "TRIM", "SILK", "GLOW"))
    # Twin stepped basalt & bone-white footings and vertical iron posts.
    for sx in (-1, 1):
        px = sx * 6.0
        box(stone, (2.8, 3.2, 1.0), T((px, 0, 0.5)), bevel=0.1)
        box(alt, (2.2, 2.6, 0.6), T((px, 0, 1.3)))
        box(metal, (0.95, 0.95, 12.6), T((px, 0, 7.9)))
        cone(metal, 0.65, 0.05, 2.2, 4, T((px, 0, 14.2)) @ R(math.pi / 4, 4, "Z"))
        wardlight_cage(metal, trim, glow, T((px, -1.5, 13.4)), scale=0.65)
    # Upper & middle horizontal iron gallows beams.
    box(metal, (13.6, 1.1, 0.9), T((0, 0, 13.4)))
    box(metal, (12.8, 0.7, 0.55), T((0, 0, 8.2)))
    # Rows of hanging iron votive chains, bone oath-tags, and wine-silk strips.
    rng = random.Random(4712)
    for k in range(11):
        cx = -4.8 + k * 0.96
        drop = rng.uniform(3.6, 7.2)
        chain_run(trim, metal, (cx, 0, 13.0), (cx, 0, 13.0 - drop), link_h=0.85, link_w=0.48, thick=0.09)
        if k % 2 == 0:
            box(alt, (0.52, 0.16, 1.05), T((cx, 0, 12.4 - drop)))
        elif k % 3 == 1:
            box(silk, (0.45, 0.14, 1.8), T((cx, 0, 12.1 - drop)))
    for k in range(7):
        cx = -3.9 + k * 1.3
        drop = rng.uniform(2.8, 5.2)
        chain_run(trim, metal, (cx, -0.2, 8.0), (cx, -0.2, 8.0 - drop), link_h=0.8, link_w=0.45, thick=0.08)
        box(alt, (0.46, 0.15, 0.92), T((cx, -0.2, 7.5 - drop)))


# -----------------------------------------------------------------------------------------------------------
# 13. OssuaryNicheWall — Bone-white marble columbarium wall stacked with Sovereign's Cursed Urns
# -----------------------------------------------------------------------------------------------------------
@template("OssuaryNicheWall", STONE=2200, ALT=3200, METAL=1800, TRIM=1400, SILK=900, ACCENT=700, GLOW=600)
def ossuary_niche_wall(t):
    """Curved-profile bone-white marble & obsidian columbarium wall (24 wide, 24 tall, 7 deep) housing
    2 tiers x 4 gothic-arched niches, each holding a chained Sovereign's Cursed Urn with wine-silk seal,
    crowned by obsidian ribs and high Wardlight sconces."""
    stone, alt, metal, trim, silk, accent, glow = (
        t.bm(r) for r in ("STONE", "ALT", "METAL", "TRIM", "SILK", "ACCENT", "GLOW")
    )
    # Stepped obsidian plinth & bone-white marble wall mass.
    box(stone, (24.0, 6.8, 1.8), T((0, 0, 0.9)), bevel=0.14)
    box(alt, (23.0, 5.8, 1.2), T((0, 0, 2.4)), bevel=0.1)
    # Main wall backing (+Y side) and bone-white marble niche piers.
    box(stone, (22.6, 2.2, 18.8), T((0, 1.6, 12.2)))
    box(alt, (22.2, 1.6, 17.6), T((0, 0.6, 12.0)))
    # Top gothic cornice & Chained Crown keystone crest.
    box(stone, (23.8, 6.4, 1.8), T((0, 0.2, 21.8)), bevel=0.14)
    box(alt, (22.8, 5.6, 1.0), T((0, 0.2, 20.6)))
    chained_crown_sigil(accent, trim, metal, T((0, -2.5, 22.8)), scale=1.05)

    # 5 vertical pilasters dividing 4 arched niche bays across X = -8.1, -2.7, +2.7, +8.1.
    for px in (-10.8, -5.4, 0.0, 5.4, 10.8):
        box(alt, (1.45, 3.6, 17.8), T((px, -0.4, 12.0)), bevel=0.08)
        box(stone, (0.75, 4.0, 18.2), T((px, -0.5, 12.0)))
        if abs(px) > 1.0:
            wardlight_cage(metal, trim, glow, T((px, -2.8, 18.8)), scale=0.62)

    # 2 tiers (Z = 4.2 and Z = 12.2) x 4 bays of arched niches with Sovereign's Cursed Urns.
    for tier_z in (4.2, 12.2):
        box(alt, (22.0, 4.2, 0.95), T((0, -0.4, tier_z - 0.3)))
        for bx in (-8.1, -2.7, 2.7, 8.1):
            # Dark recessed niche backing + iron arch lintel.
            box(stone, (3.6, 1.2, 6.2), T((bx, -0.1, tier_z + 3.2)))
            box(metal, (3.8, 2.0, 0.65), T((bx, -0.6, tier_z + 6.1)))
            sovereign_urn(metal, trim, silk, accent, T((bx, -1.1, tier_z + 0.15)), scale=1.22)


# -----------------------------------------------------------------------------------------------------------
# 14. BannerPoleWine — Tall blackened-iron banner pole flying matte wine silk with Chained Crown
# -----------------------------------------------------------------------------------------------------------
@template("BannerPoleWine", STONE=700, ALT=500, METAL=1200, TRIM=700, SILK=1400, ACCENT=500, GLOW=300)
def banner_pole_wine(t):
    """Tall blackened-iron processional banner pole (22 studs tall) on a stepped obsidian & bone-white
    plinth, flying a long tapered matte wine-crimson silk banner emblazoned with the Chained Crown and
    a high bone-white Wardlight cage."""
    stone, alt, metal, trim, silk, accent, glow = (
        t.bm(r) for r in ("STONE", "ALT", "METAL", "TRIM", "SILK", "ACCENT", "GLOW")
    )
    cone(stone, 2.0, 1.7, 0.9, 8, T((0, 0, 0)) @ R(math.pi / 8, 4, "Z"))
    cone(alt, 1.5, 1.3, 0.7, 8, T((0, 0, 0.9)) @ R(math.pi / 8, 4, "Z"))
    cyl_z(metal, 0.34, 18.8, (0, 0, 1.6), segs=10)
    cone(accent, 0.48, 0.04, 1.8, 4, T((0, 0, 20.4)))
    # Horizontal cross-yard & hanging banner forward (-Y).
    box(metal, (4.4, 0.36, 0.36), T((0, -0.8, 18.6)))
    box(silk, (3.6, 0.22, 10.4), T((0, -0.9, 13.3)))
    cone(silk, 1.9, 0.06, 2.4, 4, T((0, -0.9, 8.1)) @ R(math.pi, 4, "X") @ R(math.pi / 4, 4, "Z"))
    chained_crown_sigil(accent, trim, metal, T((0, -1.1, 14.8)), scale=0.65)
    # High Wardlight cage on short iron arm (+Y or -Y above head height).
    wardlight_cage(metal, trim, glow, T((0, -1.65, 19.2)), scale=0.60)


# -----------------------------------------------------------------------------------------------------------
# 15. CenserStand — Tall iron tripod censer stand with pale bone-white ember
# -----------------------------------------------------------------------------------------------------------
@template("CenserStand", STONE=700, ALT=700, METAL=1400, TRIM=900, ACCENT=500, GLOW=300)
def censer_stand(t):
    """Tall blackened-iron tripod censer stand on an octagonal bone-white marble plinth, suspending a
    perforated iron censer bowl with pale bone-white/cold-silver core. About 12 studs tall."""
    stone, alt, metal, trim, accent, glow = (t.bm(r) for r in ("STONE", "ALT", "METAL", "TRIM", "ACCENT", "GLOW"))
    cone(stone, 2.1, 1.8, 0.8, 8, T((0, 0, 0)) @ R(math.pi / 8, 4, "Z"))
    cone(alt, 1.6, 1.4, 0.6, 8, T((0, 0, 0.8)) @ R(math.pi / 8, 4, "Z"))
    # Three curved iron tripod legs converging to a crown ring at Z = 10.6.
    for k in range(3):
        a = 2 * math.pi * k / 3 + math.pi / 6
        pts = [
            (math.cos(a) * 1.45, math.sin(a) * 1.45, 1.4),
            (math.cos(a) * 1.15, math.sin(a) * 1.15, 6.2),
            (math.cos(a) * 0.72, math.sin(a) * 0.72, 10.6),
            (math.cos(a) * 1.15, math.sin(a) * 1.15, 11.8),
        ]
        tube(metal, pts, [0.22, 0.18, 0.16, 0.14], 6, cap=True)
    ring_mesh(accent, 0.85, 0.14, 14, T((0, 0, 10.6)), tube_segs=5)
    # Suspended censer bowl at Z = 7.4 on 3 chains.
    for k in range(3):
        a = 2 * math.pi * k / 3 + math.pi / 6
        chain_run(trim, metal, (math.cos(a) * 0.72, math.sin(a) * 0.72, 10.5),
                  (math.cos(a) * 0.55, math.sin(a) * 0.55, 8.0), link_h=0.65, link_w=0.38, thick=0.07)
    wardlight_cage(metal, trim, glow, T((0, 0, 7.2)), scale=0.82)


def apply_abyssal_preview_materials(kit):
    """Tint Blender Workbench materials to the Vahl palette so preview PNGs read clearly."""
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
    kit, manifest = build_kit("AbyssalF47Kit", F47_TEMPLATES, DEFAULT_BUDGET)
    apply_abyssal_preview_materials(kit)
    export_kit(kit, manifest, OUT_DIR, "AbyssalF47Kit")
    render_previews(kit, F47_TEMPLATES, OUT_DIR)
    print(json.dumps(manifest, indent=2))
