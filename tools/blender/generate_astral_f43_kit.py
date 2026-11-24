"""
Astral Archives Floor 43 (Fractured Index) sculpted assets, generated in headless Blender.

Inspired by the Fractured Index reference art (reference/Astral Archives 43.jpg) and the Halcyr
fracture ecosystem (docs/prompts/astral-archives-floor-layouts-prompt.md):
the Index Floor cracked into tilted fault plates split by three violet-lit rifts. At the back-east stands
the colossal broken Index Engine — split cleanly into three modular templates for clearance
(IndexEngineCore, IndexEngineGearBank, IndexEngineShelfTower) — a 178-stud brass card-drawer colossus
ripped straight down the middle with towering interlocking ring-gears behind it and drawers spilling pages
into rift C. At the back-west sits the Lifted Index's grand curved two-tier reading-hall apse. Sheer
fractured scarps expose fossilised book-strata in dark slate; three sizes of jagged floating ShardSlabs
hang in the chasms with snapped chains and crooked burning Index Lamps; sculpted 3D PageFallRibbons
cascade over the cliff lips; toppled bookcases, spilled card-drawers, tilted sliding reading desks, a
Bindery screw press with twin gold-thread spools, an Errata correction press, tall leaning ledger stacks,
a cracked bleeding indigo ink-vat, a Colophon monument wall, and snapped orrery rings dress every plate.

1 Blender unit = 1 stud, standing on z = 0, front facing -Y in Blender / +Z in Roblox, one mesh object
per colour role named "<Template>__<ROLE>". Every piece stands on its origin.

Roles (AstralFloor43 passes the Riftward Halcyr override; no new colour roles):
    STONE    vellum-white / pale grey flagstone   ALT      dark slate rock & lapis-indigo ink
    TRIM     worn gold leaf & gilded trim         METAL    aged brass gears, chains & presses
    WOOD     ebony & dark walnut shelving         SILK     ivory vellum pages, cards & thread
    GLOW     pale starlight gold & fracture glow  CRYSTAL  star-glass & glossy ink sheen

Outputs (assets-source/tower/astral_f43_kit/):
    AstralF43Kit.blend, AstralF43Kit.fbx, manifest.json, previews/kit_sheet_1.png, previews/tiles/*.png.

Run:
    blender.exe --background --factory-startup --python tools/blender/generate_astral_f43_kit.py
"""
import bpy, bmesh, math, os, json, runpy, random
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT_DIR = os.path.join(ROOT, "assets-source", "tower", "astral_f43_kit")

# Reuse shared primitives, Halcyr motifs, gears, and kit pipeline from Floors 41 & 42.
f41 = runpy.run_path(os.path.join(HERE, "generate_astral_f41_kit.py"))
f42 = runpy.run_path(os.path.join(HERE, "generate_astral_f42_kit.py"))

box = f41["box"]
cone = f41["cone"]
uvsphere = f41["uvsphere"]
tube = f41["tube"]
ring_mesh = f41["ring_mesh"]
lathe = f41["lathe"]
cyl_x, cyl_y, cyl_z, strut = f41["cyl_x"], f41["cyl_y"], f41["cyl_z"], f41["strut"]
ground_rock, slab_stone = f41["ground_rock"], f41["slab_stone"]
build_kit, export_kit, render_previews = f41["build_kit"], f41["export_kit"], f41["render_previews"]
open_tome, chain_run, index_lantern_head = f41["open_tome"], f41["chain_run"], f41["index_lantern_head"]
balustrade_post, apply_halcyr_preview_materials = f41["balustrade_post"], f41["apply_halcyr_preview_materials"]
spoked_gear = f42["spoked_gear"]

T = Matrix.Translation
R = Matrix.Rotation

DEFAULT_BUDGET = 3500
F43_TEMPLATES = {}


def template(name, **budget):
    def deco(fn):
        F43_TEMPLATES[name] = (fn, budget)
        return fn
    return deco


# -----------------------------------------------------------------------------------------------------------
# 1. IndexEngineCore — Colossal 178-stud split brass card-drawer tower (Floor 43's ≥175 stud landmark)
# -----------------------------------------------------------------------------------------------------------
@template("IndexEngineCore", METAL=6400, TRIM=4800, WOOD=3800, ALT=2400, SILK=2400, GLOW=1600, STONE=1400)
def index_engine_core(t):
    """The fractured central core of the Index Engine (178 studs tall at scale 1, clearing Floor 43's 175-stud
    ladder target; compact ~46x26 footprint so it stands cleanly behind the Engine footing without overhanging
    lanes): two towering brass-armoured card-drawer banks ripped apart down a jagged vertical rift seam, leaning
    outward +/-4 degrees, with giant drawers burst open spilling cascades of ivory index cards and glowing
    fracture light bleeding from the split."""
    metal, trim, wood, alt, silk, glow, stone = (t.bm(r) for r in ("METAL", "TRIM", "WOOD", "ALT", "SILK", "GLOW", "STONE"))
    rng = random.Random(4301)

    # Fractured dark slate & flagstone base plinth split down X = 0.
    for sx in (-1, 1):
        box(stone, (20.0, 22.0, 4.5), T((sx * 11.8, 0, 2.25)) @ R(sx * -0.05, 4, "Y"), bevel=0.35)
        for k in range(4):
            ground_rock(alt, (8.0, 7.0, 4.2), (sx * (7.0 + k * 4.0), rng.uniform(-9.5, 9.5), 0.0), seed=4302 + k + (10 if sx > 0 else 0), roughness=0.28, subdiv=1)

    # Twin towering split brass card-drawer monolith halves leaning AWAY from the central fracture seam!
    for sx in (-1, 1):
        half_m = T((sx * 12.4, 0.0, 4.0)) @ R(sx * math.radians(4.8), 4, "Y")
        half_w, half_d, half_h = 17.5, 16.5, 152.0

        # Heavy armoured brass casing with dark walnut/ebony drawer faces & stepped cornice crown.
        box(metal, (half_w, half_d, half_h), half_m @ T((0, 0, half_h * 0.5)), bevel=0.25)
        box(wood, (half_w - 2.0, half_d + 0.35, half_h - 6.0), half_m @ T((0, 0, half_h * 0.5)))
        # Stepped crown hood & tall brass telemetry spire fin rising to Z ~ 178!
        box(trim, (half_w + 1.8, half_d + 1.8, 2.8), half_m @ T((0, 0, half_h + 1.4)))
        box(metal, (half_w * 0.86, half_d * 0.84, 9.5), half_m @ T((0, 0, half_h + 7.2)))
        box(trim, (half_w * 0.92, half_d * 0.90, 1.8), half_m @ T((0, 0, half_h + 12.6)))
        cone(trim, 2.2, 0.25, 10.5 if sx > 0 else 7.5, 6, half_m @ T((sx * 2.5, 0, half_h + 13.5)))

        # Horizontal brass structural tie-bands every 24 studs.
        for zb in range(20, 148, 24):
            box(trim, (half_w + 1.2, half_d + 1.2, 1.6), half_m @ T((0, 0, zb)))

        # Grid of giant catalogue drawers up the front (-Y) face (3 cols x 14 rows), many yanked out & bursting!
        for row in range(14):
            rz = 9.0 + row * 10.2
            for col in range(3):
                cx = -5.2 + col * 5.2
                # Drawers closest to the fracture crack pop farthest out!
                near_crack = (sx < 0 and col == 2) or (sx > 0 and col == 0)
                pull = rng.uniform(2.5, 6.8) if (near_crack and rng.random() < 0.72) else (rng.uniform(1.0, 3.2) if rng.random() < 0.28 else 0.0)
                dw, dh = 4.4, 8.2
                # Drawer front & brass pull bar.
                box(metal if (row + col) % 2 == 0 else wood, (dw, 0.9 + pull, dh), half_m @ T((cx, -half_d * 0.5 - pull * 0.5, rz)))
                box(trim, (2.2, 0.45, 0.85), half_m @ T((cx, -half_d * 0.5 - pull - 0.55, rz)))
                # Spilling ivory index cards in pulled drawers!
                if pull > 1.8:
                    for c_i in range(3):
                        box(silk, (dw * 0.82, 0.35, dh * 0.78),
                            half_m @ T((cx, -half_d * 0.5 - pull * (0.28 + 0.24 * c_i), rz + 1.0)) @ R(rng.uniform(-0.2, 0.2), 4, "X"))

        # Jagged broken inner brass teeth along the split fracture face facing X = 0.
        for k in range(12):
            fz = 12.0 + k * 12.2
            fy = rng.uniform(-5.5, 5.5)
            box(alt, (2.2, rng.uniform(3.0, 6.0), rng.uniform(5.0, 9.0)), half_m @ T((-sx * (half_w * 0.5 + 0.6), fy, fz)) @ R(rng.uniform(-0.25, 0.25), 4, "Y"))

    # Glowing vertical fracture core zig-zagging right up the split seam between the two leaning halves!
    seam_pts = [(rng.uniform(-1.6, 1.6), -2.5 + rng.uniform(-1.2, 1.2), 6.0 + k * 13.0) for k in range(12)]
    tube(glow, seam_pts, [0.95 - 0.04 * k for k in range(12)], 6, cap=True)

    # Avalanche of loose white vellum pages & broken drawers heaped at the foot of the split.
    for k in range(16):
        px = rng.uniform(-12.0, 12.0)
        py = rng.uniform(-13.5, -7.5)
        pz = rng.uniform(0.3, 3.8)
        box(silk, (rng.uniform(2.2, 3.8), rng.uniform(1.6, 2.8), 0.22),
            T((px, py, pz)) @ R(rng.uniform(0, math.pi), 4, "Z") @ R(rng.uniform(-0.4, 0.4), 4, "X"))


# -----------------------------------------------------------------------------------------------------------
# 2. IndexEngineGearBank — Split backdrop cluster of 3 colossal interlocking brass ring-gears
# -----------------------------------------------------------------------------------------------------------
@template("IndexEngineGearBank", METAL=4800, TRIM=3600, ALT=1400, STONE=1200)
def index_engine_gear_bank(t):
    """Modular gear-wheel backdrop for the Index Engine (split from IndexEngineCore for clean clearance):
    three monumental interlocking toothed brass ring-gears rising out of a fractured slate-and-stone anchor
    housing (seen towering behind the split Index Engine in the guide image). About 74 wide, 88 tall."""
    metal, trim, alt, stone = (t.bm(r) for r in ("METAL", "TRIM", "ALT", "STONE"))
    # Grounded fractured stone & brass drive-housing plinth.
    box(stone, (52.0, 12.0, 6.0), T((0, 0, 3.0)), bevel=0.3)
    for sx in (-20, 0, 20):
        ground_rock(alt, (14.0, 10.0, 7.5), (sx, 0, 0.0), seed=4310 + sx, roughness=0.28, subdiv=1)

    # Central colossal crown gear (R = 26, centred at Z = 58 -> top at Z = 88!).
    spoked_gear(metal, trim, 26.0, 3.2, 24, T((0, 0, 58.0)) @ R(math.pi / 2, 4, "X"), spokes=8)
    # West lower-side interlocking gear (R = 19, centred at (-24, 2.5, 30)).
    spoked_gear(metal, trim, 19.0, 2.8, 20, T((-24.0, 2.5, 30.0)) @ R(math.pi / 2, 4, "X") @ R(0.18, 4, "Y"), spokes=6)
    # East mid-high interlocking gear (R = 21, centred at (24, -2.0, 44)).
    spoked_gear(metal, trim, 21.0, 2.8, 20, T((24.0, -2.0, 44.0)) @ R(math.pi / 2, 4, "X") @ R(-0.14, 4, "Y"), spokes=6)
    # Heavy diagonal brass A-frame stanchions anchoring the gear axles to the plinth.
    for ax, az in ((0, 58.0), (-24.0, 30.0), (24.0, 44.0)):
        strut(metal, (ax - 8.0, 0, 4.0), (ax, 0, az), 1.8)
        strut(metal, (ax + 8.0, 0, 4.0), (ax, 0, az), 1.8)


# -----------------------------------------------------------------------------------------------------------
# 3. IndexEngineShelfTower — Modular leaning flanking shelf-tower of the fractured Index Engine
# -----------------------------------------------------------------------------------------------------------
@template("IndexEngineShelfTower", WOOD=3400, METAL=2800, TRIM=2200, ALT=1400, SILK=1400, STONE=900)
def index_engine_shelf_tower(t):
    """Modular flanking archive shelf-tower for the Index Engine (seen leaning inward on the left and right
    of the split central core in the guide image): a 90-stud-tall tilted ebony-and-brass bookcase monolith
    with 8 colossal shelf bays packed with oversized archive folios and buckled brass strapping."""
    wood, metal, trim, alt, silk, stone = (t.bm(r) for r in ("WOOD", "METAL", "TRIM", "ALT", "SILK", "STONE"))
    rng = random.Random(4320)

    # Cracked stone footing pad.
    box(stone, (24.0, 15.0, 3.2), T((0, 0, 1.6)), bevel=0.25)
    tilt_m = T((0, 0, 2.6)) @ R(math.radians(8.5), 4, "Y")
    W, D, H = 20.0, 11.5, 86.0

    # Tall brass-bound bookcase carcass.
    box(wood, (W, 1.6, H), tilt_m @ T((0, D * 0.42, H * 0.5)))
    for sx in (-1, 1):
        box(metal, (1.8, D, H), tilt_m @ T((sx * (W * 0.5 - 0.9), 0, H * 0.5)))
        box(trim, (2.1, D + 0.5, 1.4), tilt_m @ T((sx * (W * 0.5 - 0.9), 0, H - 2.0)))
    box(metal, (W + 2.2, D + 2.0, 3.2), tilt_m @ T((0, 0, H + 1.4)), bevel=0.2)
    box(trim, (W + 2.6, D + 2.4, 0.9), tilt_m @ T((0, 0, H + 3.2)))

    # 8 stacked shelf bays packed with giant slanted & upright tomes.
    for row in range(8):
        sz = 4.0 + row * 10.0
        box(wood, (W - 2.4, D - 0.8, 1.0), tilt_m @ T((0, -0.2, sz)))
        box(trim, (W - 2.0, 0.5, 0.45), tilt_m @ T((0, -D * 0.48, sz)))
        x_cur = -W * 0.41
        while x_cur < W * 0.36:
            bw = rng.uniform(1.5, 2.8)
            bh = rng.uniform(5.6, 8.2)
            bd = rng.uniform(6.2, 8.5)
            book_tilt = rng.uniform(-0.18, 0.22)
            role_bm = (alt, trim, silk, wood)[(row + int(x_cur + 12)) % 4]
            box(role_bm, (bw, bd, bh), tilt_m @ T((x_cur + bw * 0.5, -0.3, sz + 0.5 + bh * 0.5)) @ R(book_tilt, 4, "Y"))
            x_cur += bw + 0.35


# -----------------------------------------------------------------------------------------------------------
# 4. LiftedIndexGallery — Grand curved two-tier reading-hall apse (Floor 43 Apex landmark from guide image)
# -----------------------------------------------------------------------------------------------------------
@template("LiftedIndexGallery", WOOD=4400, STONE=3600, TRIM=2600, METAL=1600, ALT=1800, SILK=1600, GLOW=800)
def lifted_index_gallery(t):
    """The Lifted Index's signature back-wall reading-hall apse (directly from the back-left Apex of the guide
    image): a sweeping 68-stud-wide semicircular two-story ebony library gallery with twin curved side stairs,
    upper stone-balustrade balcony, central arched vault portal, packed curved bookcases, and a grand curved
    librarian's catalogue counter in front (leaves the Apex combat arena completely clear in front of it)."""
    wood, stone, trim, metal, alt, silk, glow = (t.bm(r) for r in ("WOOD", "STONE", "TRIM", "METAL", "ALT", "SILK", "GLOW"))
    rng = random.Random(4330)

    # Semicircular tiered base deck & upper balcony floor (concave facing -Y, centre at (0, -28, 0)).
    arc_r = 34.0
    balc_z = 13.5
    segs = 14
    for k in range(segs):
        a = math.radians(-58 + 116 * (k + 0.5) / segs)
        cx = math.sin(a) * arc_r
        cy = (math.cos(a) - 1.0) * arc_r
        seg_w = (2 * math.pi * arc_r * 116 / 360) / segs + 0.6
        m = T((cx, cy, 0.0)) @ R(-a, 4, "Z")

        # Lower backing wall & stone plinth.
        box(stone, (seg_w, 6.2, 1.4), m @ T((0, 0, 0.7)))
        box(wood, (seg_w, 1.2, balc_z * 2.05), m @ T((0, 2.8, balc_z * 1.02)))
        # Upper balcony cantilevered deck & classical balustrade rail.
        box(stone, (seg_w + 0.3, 8.2, 1.2), m @ T((0, -1.6, balc_z)))
        box(trim, (seg_w + 0.4, 8.4, 0.28), m @ T((0, -1.6, balc_z + 0.68)))
        balustrade_post(stone, trim, (m @ Vector((0, -5.2, balc_z + 0.6))).x,
                        (m @ Vector((0, -5.2, balc_z + 0.6))).y, balc_z + 0.6, h=2.8)
        box(trim, (seg_w + 0.2, 0.45, 0.26), m @ T((0, -5.2, balc_z + 3.55)))

        # Skip bookcases in the very centre 2 bays (reserved for the grand arched portal!).
        if k in (6, 7):
            continue
        # Lower & upper tier ebony bookcase shelves packed with books!
        for tier_z in (1.4, balc_z + 0.8):
            box(wood, (seg_w - 0.4, 2.4, 0.4), m @ T((0, 1.6, tier_z + 3.2)))
            box(wood, (seg_w - 0.4, 2.4, 0.4), m @ T((0, 1.6, tier_z + 6.4)))
            box(wood, (seg_w - 0.4, 2.4, 0.4), m @ T((0, 1.6, tier_z + 9.6)))
            for s_z in (tier_z + 0.4, tier_z + 3.6, tier_z + 6.8):
                for b_i in range(3):
                    bx = (-0.3 + b_i * 0.3) * seg_w
                    bh = rng.uniform(1.8, 2.6)
                    role_bm = (alt, trim, silk, wood)[(k + b_i + int(tier_z)) % 4]
                    box(role_bm, (seg_w * 0.24, 1.7, bh), m @ T((bx, 1.3, s_z + bh * 0.5)))

    # Central arched grand archive portal at the centre back (X = 0, Y = 1.0, Z = balc_z..32).
    box(stone, (10.5, 3.6, 17.5), T((0, 2.0, balc_z + 8.8)), bevel=0.2)
    box(alt, (6.8, 3.9, 13.0), T((0, 1.9, balc_z + 7.2)))
    ring_mesh(trim, 3.8, 0.45, 18, T((0, 0.0, balc_z + 13.8)) @ R(math.pi / 2, 4, "X"), tube_segs=5)
    box(glow, (0.65, 0.3, 10.5), T((0, -0.1, balc_z + 7.2)))

    # Twin curved access stairs rising from ground up to the balcony at both wings (+/- 38 deg).
    for sx in (-1, 1):
        for step in range(9):
            f = step / 8.0
            ang = sx * math.radians(46 - f * 18)
            rr = arc_r - 7.8
            px = math.sin(ang) * rr
            py = (math.cos(ang) - 1.0) * rr
            sz = 0.75 + f * (balc_z - 1.2)
            box(stone, (4.8, 2.2, 1.4), T((px, py, sz)) @ R(-ang, 4, "Z"))
            box(trim, (5.0, 2.3, 0.18), T((px, py, sz + 0.75)) @ R(-ang, 4, "Z"))

    # Grand curved librarian's catalogue desk standing in the lower central alcove.
    for k in range(5):
        a = math.radians(-28 + 56 * k / 4)
        dr = 18.5
        dx = math.sin(a) * dr
        dy = (math.cos(a) - 1.0) * dr - 7.5
        dm = T((dx, dy, 0.0)) @ R(-a, 4, "Z")
        box(wood, (4.4, 2.4, 3.8), dm @ T((0, 0, 1.9)), bevel=0.06)
        box(trim, (4.6, 2.6, 0.25), dm @ T((0, 0, 3.9)))
        if k == 2:
            open_tome(alt, silk, trim, dm @ T((0, 0, 4.15)), w=3.2, d=2.2, page_h=0.45, spread=0.26)


# -----------------------------------------------------------------------------------------------------------
# 5. ScarpShelfStrata — Up-thrown fractured cliff scarp banded with fossilised book-shelves
# -----------------------------------------------------------------------------------------------------------
@template("ScarpShelfStrata", ALT=3400, STONE=1600, WOOD=1800, TRIM=1200, SILK=1200)
def scarp_shelf_strata(t):
    """Sheer up-thrown fractured rock scarp (34 wide, 18 tall) banded with fossilised archive shelves and
    rows of ancient books embedded straight into the dark slate cliff face (seen under the raised fault plates
    in the guide image)."""
    alt, stone, wood, trim, silk = (t.bm(r) for r in ("ALT", "STONE", "WOOD", "TRIM", "SILK"))
    rng = random.Random(4340)

    # Stacked fractured slate cliff crags tilted slightly upward to the west (+X -> -X).
    for k in range(9):
        rx = -14.0 + k * 3.5
        rh = 13.5 + (4 - abs(k - 4)) * 1.1 + rng.uniform(-1.5, 1.5)
        box(alt, (rng.uniform(4.2, 6.2), rng.uniform(6.0, 8.8), rh),
            T((rx, rng.uniform(-0.8, 0.8), rh * 0.5)) @ R(rng.uniform(-0.08, 0.08), 4, "Z"), bevel=0.35)

    # Top broken flagstone lip overhanging the scarp edge.
    for k in range(7):
        fx = -13.5 + k * 4.5
        box(stone, (4.6, 8.6, 1.4), T((fx, -0.5, 16.8 + rng.uniform(-0.3, 0.3))) @ R(rng.uniform(-0.04, 0.04), 4, "Y"), bevel=0.14)

    # Two horizontal fossilised ebony bookshelf strata embedded straight into the front (-Y) rock face!
    for stratum_z in (5.2, 11.4):
        box(wood, (28.0, 2.2, 0.55), T((0, -3.9, stratum_z)))
        box(wood, (28.0, 2.2, 0.55), T((0, -3.9, stratum_z + 3.2)))
        for p_x in range(-12, 13, 6):
            box(wood, (0.65, 2.2, 3.2), T((p_x, -3.9, stratum_z + 1.6)))
        # Fossilised tomes wedged between the rock & wood shelves.
        x_cur = -12.6
        while x_cur < 12.2:
            if rng.random() < 0.16:
                x_cur += 1.4
                continue  # Broken rock gap in the fossilised stratum.
            bw = rng.uniform(0.7, 1.35)
            bh = rng.uniform(1.9, 2.75)
            role_bm = (trim, silk, wood, alt)[int((x_cur + 20) * 3) % 4]
            box(role_bm, (bw, 1.85, bh), T((x_cur + bw * 0.5, -4.1, stratum_z + 0.3 + bh * 0.5)) @ R(rng.uniform(-0.14, 0.14), 4, "Y"))
            x_cur += bw + 0.16


# -----------------------------------------------------------------------------------------------------------
# 6, 7, 8. ShardSlabS / M / L — Three sizes of fractured floating floor-slab shards with broken chains & lamp
# -----------------------------------------------------------------------------------------------------------
def _build_shard_slab(t, width, depth, height, seed, with_lamp=False, chains=2):
    """Jagged fractured floating floor-slab shard (standing cleanly on z = 0): broken flagged stone top with
    gold inlay cracks, craggy tapering slate underside, dangling snapped brass chains, and optional crooked lamp."""
    alt, stone, trim, metal, crystal, glow = (t.bm(r) for r in ("ALT", "STONE", "TRIM", "METAL", "CRYSTAL", "GLOW"))
    rng = random.Random(seed)
    top_z = height - 1.4

    # Tapering jagged dark slate rock underside rising from z = 0 up to top_z.
    cone(alt, width * 0.08, width * 0.46, top_z, 7, T((0, 0, 0.0)) @ Matrix.Diagonal((1.0, depth / width, 1.0, 1.0)))
    for k in range(6):
        a = 2 * math.pi * k / 6 + rng.uniform(-0.18, 0.18)
        sub_h = top_z * rng.uniform(0.45, 0.85)
        cone(alt, width * 0.05, width * 0.22, sub_h, 5,
             T((math.cos(a) * width * 0.24, math.sin(a) * depth * 0.24, top_z - sub_h)) @ R(a, 4, "Z"))

    # Broken mosaic of cracked pale-grey flagstones forming the walkable shard top!
    nx, ny = max(2, int(width / 7.5)), max(2, int(depth / 7.5))
    for i in range(nx):
        for j in range(ny):
            fx = ((i + 0.5) / nx - 0.5) * (width * 0.84)
            fy = ((j + 0.5) / ny - 0.5) * (depth * 0.84)
            # Clip corners slightly so silhouette reads jagged/polygonal, not boxy.
            if abs(fx) / (width * 0.5) + abs(fy) / (depth * 0.5) > 1.32:
                continue
            fw = (width * 0.84 / nx) * rng.uniform(0.84, 0.96)
            fd = (depth * 0.84 / ny) * rng.uniform(0.84, 0.96)
            box(stone, (fw, fd, 1.4), T((fx, fy, top_z + 0.7)) @ R(rng.uniform(-0.04, 0.04), 4, "Z"), bevel=0.1)
    # Fractured gold star-map inlay strips across the shard surface.
    box(trim, (width * 0.62, 0.32, 0.12), T((0, 0, top_z + 1.42)) @ R(0.35, 4, "Z"))
    box(trim, (depth * 0.55, 0.28, 0.12), T((0, 0, top_z + 1.42)) @ R(-0.65, 4, "Z"))

    # Dangling snapped brass chains hanging off the broken shard perimeter.
    for k in range(chains):
        a = 2 * math.pi * k / chains + 0.65
        rx, ry = math.cos(a) * width * 0.42, math.sin(a) * depth * 0.42
        drop = min(top_z - 1.5, rng.uniform(6.0, 12.0))
        chain_run(metal, trim, (rx, ry, top_z + 0.4), (rx * 1.06, ry * 1.06, max(1.0, top_z - drop)), link_h=1.25, link_w=0.72, thick=0.14)

    # Optional crooked glowing Index Lamp perched near the shard's outer corner (from the guide image!).
    if with_lamp:
        lm = T((width * 0.34, -depth * 0.28, top_z + 1.35)) @ R(math.radians(11), 4, "Y") @ R(math.radians(-7), 4, "X")
        cone(stone, 0.9, 0.7, 0.8, 8, lm)
        strut(metal, lm @ Vector((0, 0, 0.8)), lm @ Vector((0, 0, 8.6)), 0.28)
        strut(metal, lm @ Vector((0, 0, 8.6)), lm @ Vector((-1.6, 0, 8.9)), 0.20)
        index_lantern_head(metal, trim, crystal, glow, lm @ T((-1.6, 0, 7.5)), scale=0.78)


@template("ShardSlabS", ALT=1400, STONE=900, TRIM=600, METAL=900, CRYSTAL=200, GLOW=200)
def shard_slab_s(t):
    """Small fractured floating shard (16x14, 14 tall) for chasm dressing and stepping clusters."""
    _build_shard_slab(t, width=16.0, depth=14.0, height=14.0, seed=4351, with_lamp=False, chains=2)


@template("ShardSlabM", ALT=2000, STONE=1400, TRIM=900, METAL=1400, CRYSTAL=400, GLOW=400)
def shard_slab_m(t):
    """Medium fractured floating shard (28x24, 20 tall) with snapped chains and a crooked lit Index Lamp."""
    _build_shard_slab(t, width=28.0, depth=24.0, height=20.0, seed=4352, with_lamp=True, chains=3)


@template("ShardSlabL", ALT=2600, STONE=1800, TRIM=1200, METAL=1800, CRYSTAL=500, GLOW=500)
def shard_slab_l(t):
    """Large fractured floating shard (42x34, 26 tall) for The Index Shard junction with chains & crooked lamp."""
    _build_shard_slab(t, width=42.0, depth=34.0, height=26.0, seed=4353, with_lamp=True, chains=4)


# -----------------------------------------------------------------------------------------------------------
# 9. ToppledShelfRange — Fallen ebony bookcase lying on its side with books avalanching outward
# -----------------------------------------------------------------------------------------------------------
@template("ToppledShelfRange", WOOD=2200, TRIM=1400, ALT=1200, SILK=1600, STONE=700, METAL=600)
def toppled_shelf_range(t):
    """A toppled ebony archive bookcase lying broken on its side across cracked flagstones, its shelves
    splintered and an avalanche of bound tomes & loose vellum pages spilling downhill toward -Y."""
    wood, trim, alt, silk, stone, metal = (t.bm(r) for r in ("WOOD", "TRIM", "ALT", "SILK", "STONE", "METAL"))
    rng = random.Random(4360)

    # Cracked stone rubble pad beneath the fallen case.
    for k in range(4):
        slab_stone(stone, (4.2, 3.6, 0.9), (-5.0 + k * 3.4, 0.8, 0.35), rot_z=k * 0.5, seed=4361 + k, roughness=0.2)

    # Fallen bookcase carcass lying tipped forward/open toward -Y so its empty splintered shelves read clearly!
    fm = T((0, 1.8, 2.35)) @ R(math.radians(-74), 4, "X") @ R(math.radians(8), 4, "Z")
    W, D, H = 13.5, 3.2, 10.2
    box(wood, (W, 0.45, H), fm @ T((0, D * 0.44, 0)))
    for sx in (-1, 1):
        box(wood, (0.55, D, H), fm @ T((sx * (W * 0.5), 0, 0)))
        box(metal, (0.7, D + 0.2, 0.55), fm @ T((sx * (W * 0.5), 0, H * 0.48)))
    for sz in (-4.8, -1.6, 1.6, 4.8):
        box(wood, (W, D - 0.2, 0.35), fm @ T((0, 0, sz)))
        box(trim, (W + 0.2, 0.22, 0.42), fm @ T((0, -D * 0.48, sz)))

    # Avalanche of tumbled closed & open books spilling forward (-Y) onto the floor.
    for k in range(18):
        bx = rng.uniform(-7.2, 7.2)
        by = rng.uniform(-5.6, 1.2)
        bz = rng.uniform(0.25, 1.6) if by > -2.0 else rng.uniform(0.2, 0.65)
        bm = T((bx, by, bz)) @ R(rng.uniform(0, math.pi), 4, "Z") @ R(rng.uniform(-0.35, 0.35), 4, "X")
        role_bm = (alt, wood, trim)[k % 3]
        box(role_bm, (rng.uniform(1.1, 1.7), rng.uniform(0.85, 1.3), rng.uniform(0.32, 0.52)), bm)
        box(silk, (1.0, 0.8, 0.22), bm @ T((0.06, 0, 0)))
    # Scattered loose vellum pages fanning past the fallen books.
    for k in range(10):
        box(silk, (rng.uniform(0.9, 1.4), rng.uniform(0.7, 1.1), 0.08),
            T((rng.uniform(-7.8, 7.8), rng.uniform(-6.8, -2.0), 0.08)) @ R(rng.uniform(0, math.pi), 4, "Z"))


# -----------------------------------------------------------------------------------------------------------
# 10. CardDrawerSpill — Smashed brass-trimmed card drawers spilling fans of ivory index cards
# -----------------------------------------------------------------------------------------------------------
@template("CardDrawerSpill", WOOD=1200, TRIM=900, METAL=600, SILK=1400)
def card_drawer_spill(t):
    """A cluster of three knocked-loose ebony-and-brass card-catalogue drawers tumbled onto the floor,
    spilling cascading fans of ivory vellum index cards & torn markers."""
    wood, trim, metal, silk = (t.bm(r) for r in ("WOOD", "TRIM", "METAL", "SILK"))
    rng = random.Random(4370)

    drawers = ((-2.2, 0.6, 0.55, 0.35, 0.0), (1.8, 1.2, 0.9, -0.55, 0.32), (-0.3, -1.6, 0.55, 1.25, -0.15))
    for dx, dy, dz, yaw, pitch in drawers:
        dm = T((dx, dy, dz)) @ R(yaw, 4, "Z") @ R(pitch, 4, "X")
        # Open-top wooden drawer box.
        box(wood, (2.2, 3.6, 0.18), dm @ T((0, 0, -0.42)))
        for sx in (-1, 1):
            box(wood, (0.18, 3.6, 1.05), dm @ T((sx * 1.02, 0, 0.05)))
        for sy in (-1, 1):
            box(wood, (2.2, 0.2, 1.05), dm @ T((0, sy * 1.72, 0.05)))
        box(trim, (0.95, 0.18, 0.32), dm @ T((0, -1.88, 0.1)))
        box(metal, (2.28, 3.68, 0.14), dm @ T((0, 0, -0.35)))
        # Tilted ivory index cards jammed inside the drawer.
        for c_i in range(5):
            box(silk, (1.8, 0.12, 0.95), dm @ T((0, -1.1 + c_i * 0.55, 0.25)) @ R(rng.uniform(-0.35, 0.35), 4, "X"))

    # Fanned cascade of loose index cards strewn on z = 0.06 around the drawers.
    for k in range(22):
        box(silk, (rng.uniform(0.55, 0.95), rng.uniform(0.75, 1.15), 0.06),
            T((rng.uniform(-5.2, 5.2), rng.uniform(-4.4, 3.6), 0.05 + (k % 3) * 0.03)) @ R(rng.uniform(0, math.pi), 4, "Z"))


# -----------------------------------------------------------------------------------------------------------
# 11. CatalogueDeskTilted — Sliding reading desk with tipped chair, spilled ink & books (Reading Plate)
# -----------------------------------------------------------------------------------------------------------
@template("CatalogueDeskTilted", WOOD=1800, METAL=900, TRIM=900, SILK=1200, ALT=700, CRYSTAL=400)
def catalogue_desk_tilted(t):
    """Reading Plate's disrupted writing vignette: an ebony catalogue desk canted askew with a tipped-over
    chair beside it, spilled indigo ink pool, open manuscript sliding toward the edge, and scattered quills."""
    wood, metal, trim, silk, alt, crystal = (t.bm(r) for r in ("WOOD", "METAL", "TRIM", "SILK", "ALT", "CRYSTAL"))
    dm = T((-0.6, 0.8, 0.0)) @ R(math.radians(14), 4, "Z")

    # Ebony desk frame with one slightly buckled leg (still grounded at z = 0!).
    for sx in (-1, 1):
        for sy in (-1, 1):
            box(wood, (0.55, 0.55, 3.4), dm @ T((sx * 3.5, sy * 1.6, 1.7)))
            box(metal, (0.68, 0.68, 0.42), dm @ T((sx * 3.5, sy * 1.6, 0.21)))
    box(wood, (8.2, 4.2, 0.55), dm @ T((0, 0, 3.65)), bevel=0.06)
    box(trim, (8.35, 4.35, 0.14), dm @ T((0, 0, 3.96)))

    # Open tome sliding off the front-right corner of the desk!
    open_tome(alt, silk, trim, dm @ T((2.4, -1.65, 4.05)) @ R(math.radians(-18), 4, "X") @ R(0.35, 4, "Z"),
              w=2.9, d=2.0, page_h=0.45, spread=0.28)
    # Knocked-over brass ink-pot & dark ink puddle spreading over the desk top.
    cyl_x(metal, 0.32, 0.55, (dm @ Vector((-1.4, -0.4, 4.25))), segs=10)
    cyl_z(alt, 1.35, 0.08, (dm @ Vector((-0.6, -0.8, 3.96))), segs=12)
    cyl_z(crystal, 1.05, 0.05, (dm @ Vector((-0.6, -0.8, 4.02))), segs=10)

    # Tipped-over wooden scholar's chair lying on its side in front (-Y) of the desk.
    cm = T((1.8, -3.4, 1.05)) @ R(math.radians(-78), 4, "X") @ R(math.radians(32), 4, "Z")
    box(wood, (2.2, 2.2, 0.3), cm)
    box(wood, (2.2, 0.28, 2.6), cm @ T((0, 1.0, 1.35)))
    for sx in (-0.9, 0.9):
        for sy in (-0.9, 0.9):
            box(wood, (0.28, 0.28, 2.1), cm @ T((sx, sy, -1.05)))
    # Scattered pages on the floor around the tipped chair.
    for k in range(5):
        box(silk, (1.1, 0.85, 0.06), T((-2.4 + k * 1.4, -3.6 + (k % 2) * 1.1, 0.05)) @ R(k * 0.7, 4, "Z"))


# -----------------------------------------------------------------------------------------------------------
# 12. BinderyPress — Bookbinder's standing screw press & twin giant spools of gold thread (Bindery Plate)
# -----------------------------------------------------------------------------------------------------------
@template("BinderyPress", WOOD=2400, METAL=2200, TRIM=2400, SILK=1200, ALT=900, STONE=700)
def bindery_press(t):
    """Bindery Plate's signature craft vignette (seen clearly on the mid-left plate of the guide image!):
    a heavy timber-and-brass bookbinder's standing screw press clamping a stack of folios, flanked by two
    oversized turned wooden bobbins wound thickly with gleaming gold binding thread and a sewing frame."""
    wood, metal, trim, silk, alt, stone = (t.bm(r) for r in ("WOOD", "METAL", "TRIM", "SILK", "ALT", "STONE"))

    # Standing bookbinder's screw press (centred at X = -1.5).
    px = -1.5
    box(stone, (7.6, 5.2, 0.7), T((px, 0, 0.35)), bevel=0.08)
    box(wood, (6.8, 4.4, 2.2), T((px, 0, 1.8)), bevel=0.06)
    # Twin vertical timber guide posts + massive crosshead beam.
    for sx in (-2.7, 2.7):
        box(wood, (0.95, 1.1, 8.8), T((px + sx, 0, 6.2)))
        box(metal, (1.1, 1.25, 0.5), T((px + sx, 0, 10.4)))
    box(wood, (7.4, 1.6, 1.4), T((px, 0, 9.8)), bevel=0.08)
    box(metal, (7.6, 1.75, 0.35), T((px, 0, 10.55)))
    # Vertical threaded brass press screw + spinning crossbar wheel lever on top!
    cyl_z(metal, 0.58, 7.6, (px, 0, 4.6), segs=12)
    for k in range(10):
        ring_mesh(trim, 0.68, 0.09, 12, T((px, 0, 5.4 + k * 0.65)), tube_segs=4)
    # Crossbar handle with brass counterweight balls at ends.
    cyl_x(metal, 0.28, 6.4, (px, 0, 11.8), segs=10)
    for sx in (-3.2, 3.2):
        uvsphere(trim, 0.55, T((px + sx, 0, 11.8)), 8, 6)
    # Heavy brass platen clamping a thick stack of freshly bound folios on the press bed!
    box(metal, (4.4, 3.4, 0.55), T((px, 0, 5.2)))
    for k in range(3):
        box(alt if k % 2 == 0 else wood, (3.8, 2.8, 0.62), T((px, 0, 3.25 + k * 0.64)))
        box(silk, (3.55, 2.55, 0.42), T((px + 0.08, 0, 3.25 + k * 0.64)))

    # Two oversized wooden spools wound with thick coils of gleaming gold thread (seen right beside the press in the guide art!).
    # Spool 1: standing upright on the east (+X).
    sx1, sy1 = 5.4, -0.6
    cyl_z(wood, 2.0, 0.55, (sx1, sy1, 0.0), segs=16)
    cyl_z(wood, 2.0, 0.55, (sx1, sy1, 4.45), segs=16)
    cyl_z(trim, 1.55, 3.95, (sx1, sy1, 0.55), segs=16)
    for k in range(7):
        ring_mesh(trim, 1.62, 0.16, 16, T((sx1, sy1, 0.95 + k * 0.52)), tube_segs=4)
    # Spool 2: lying on its side in front-left (-X).
    sx2, sy2 = -6.8, -1.8
    m2 = T((sx2, sy2, 1.7)) @ R(0.45, 4, "Z") @ R(math.pi / 2, 4, "Y")
    cone(wood, 1.7, 1.7, 0.45, 14, m2 @ T((0, 0, -1.8)))
    cone(wood, 1.7, 1.7, 0.45, 14, m2 @ T((0, 0, 1.35)))
    cone(trim, 1.32, 1.32, 2.75, 14, m2 @ T((0, 0, -1.35)))


# -----------------------------------------------------------------------------------------------------------
# 13. ErrataPress — Correction printing press with brass roller & drying rack of proof sheets
# -----------------------------------------------------------------------------------------------------------
@template("ErrataPress", METAL=2200, WOOD=1800, TRIM=1400, SILK=1400, ALT=800, GLOW=400)
def errata_press(t):
    """Errata Plate's correction press: a heavy brass-and-ebony roller printing press with an inked type-bed
    and crank wheel, paired with a tall timber drying rack hung with struck-through vellum proof sheets."""
    metal, wood, trim, silk, alt, glow = (t.bm(r) for r in ("METAL", "WOOD", "TRIM", "SILK", "ALT", "GLOW"))

    # Printing press bed & frame on the left (-X).
    px = -2.2
    box(wood, (7.4, 4.6, 3.2), T((px, 0, 1.6)), bevel=0.08)
    box(metal, (7.8, 4.8, 0.45), T((px, 0, 3.4)))
    # Inked metal type-plate & half-printed proof sheet.
    box(alt, (4.8, 3.2, 0.25), T((px - 0.5, 0, 3.72)))
    box(silk, (2.6, 2.9, 0.08), T((px + 1.8, 0, 3.75)))
    # Overhead brass roller carriage & spoked crank flywheel.
    for sy in (-2.2, 2.2):
        box(metal, (1.4, 0.55, 3.4), T((px, sy, 5.1)))
    cyl_y(trim, 0.85, 4.6, (px, 0, 5.2), segs=14)
    spoked_gear(metal, trim, 1.9, 0.35, 12, T((px, -2.75, 5.2)) @ R(math.pi / 2, 4, "X"), spokes=5)

    # Tall drying rack on the right (+X) hung with 6 struck-through vellum proof sheets.
    rx = 5.4
    for sy in (-2.4, 2.4):
        box(wood, (0.55, 0.55, 9.6), T((rx, sy, 4.8)))
        box(wood, (2.4, 0.65, 0.45), T((rx, sy, 0.22)))
    for rz in (5.2, 8.8):
        cyl_y(metal, 0.16, 5.0, (rx, 0, rz), segs=8)
        for k in range(3):
            sy = -1.4 + k * 1.4
            box(silk, (0.1, 1.05, 2.4), T((rx + (0.15 if k % 2 else -0.1), sy, rz - 1.3)) @ R(0.08 * (k - 1), 4, "Y"))
            # Struck-through crimson/indigo errata slash across each hanging proof sheet!
            box(alt, (0.14, 0.85, 0.16), T((rx + (0.15 if k % 2 else -0.1), sy, rz - 1.2)) @ R(0.45, 4, "X"))
    uvsphere(glow, 0.35, T((px - 3.2, 1.8, 4.2)), 8, 6)


# -----------------------------------------------------------------------------------------------------------
# 14. LedgerStackTall — Precarious 14-stud tower of brass-clasped archive ledgers & fallen folio
# -----------------------------------------------------------------------------------------------------------
@template("LedgerStackTall", ALT=1600, WOOD=1400, SILK=1800, TRIM=1600, METAL=800, STONE=600)
def ledger_stack_tall(t):
    """Ledger Plate's towering precarious stack of oversized brass-clasped archive ledgers (14.5 studs tall),
    canting dramatically with a companion half-stack and a heavy ledger splayed open at its foot."""
    alt, wood, silk, trim, metal, stone = (t.bm(r) for r in ("ALT", "WOOD", "SILK", "TRIM", "METAL", "STONE"))
    rng = random.Random(4380)

    box(stone, (9.6, 8.2, 0.45), T((0, 0, 0.225)), bevel=0.06)
    # Main towering stack of 13 heavy folios leaning smoothly as it rises!
    z_cur = 0.45
    for k in range(13):
        bw = 4.6 - k * 0.14 + rng.uniform(-0.2, 0.2)
        bd = 3.4 - k * 0.08 + rng.uniform(-0.15, 0.15)
        bh = rng.uniform(0.85, 1.18)
        ox = -0.8 + k * 0.12 + rng.uniform(-0.22, 0.22)
        oy = 0.6 + rng.uniform(-0.22, 0.22)
        bm = T((ox, oy, z_cur + bh * 0.5)) @ R(rng.uniform(-0.38, 0.38), 4, "Z") @ R(0.04, 4, "Y")
        cover = (alt, wood, metal)[k % 3]
        box(cover, (bw, bd, bh), bm)
        box(silk, (bw * 0.9, bd * 0.88, bh * 0.68), bm @ T((bw * 0.04, 0, 0)))
        box(trim, (0.24, bd * 0.98, bh * 1.02), bm @ T((-bw * 0.48, 0, 0)))
        # Brass corner clasps on every 2nd ledger.
        if k % 2 == 0:
            box(trim, (0.35, 0.35, bh * 1.04), bm @ T((bw * 0.46, bd * 0.46, 0)))
        z_cur += bh

    # Shorter leaning companion stack on the right (+X).
    z2 = 0.45
    for k in range(6):
        bh = rng.uniform(0.75, 1.05)
        bm = T((3.1, -0.4, z2 + bh * 0.5)) @ R(rng.uniform(-0.4, 0.4), 4, "Z")
        box(wood if k % 2 else alt, (3.1, 2.4, bh), bm)
        box(silk, (2.85, 2.15, bh * 0.68), bm @ T((0.1, 0, 0)))
        z2 += bh

    # Fallen giant ledger splayed open in front (-Y).
    open_tome(alt, silk, trim, T((-0.8, -2.9, 0.55)) @ R(0.35, 4, "Z"), w=4.4, d=3.1, page_h=0.65, spread=0.22)


# -----------------------------------------------------------------------------------------------------------
# 15. InkVatCracked — Cracked brass-banded ink vat bleeding a glossy indigo puddle (Ink-Cellar Plate)
# -----------------------------------------------------------------------------------------------------------
@template("InkVatCracked", STONE=1400, METAL=1600, TRIM=900, ALT=1400, CRYSTAL=1200, GLOW=400)
def ink_vat_cracked(t):
    """Ink-Cellar Plate's fractured archive ink-vat (seen bleeding indigo across the mid-left ledge of the
    guide image): a heavy brass-banded stone-and-iron vat split wide down its front face, spilling a glossy
    dark indigo star-ink pool across the flagstones."""
    stone, metal, trim, alt, crystal, glow = (t.bm(r) for r in ("STONE", "METAL", "TRIM", "ALT", "CRYSTAL", "GLOW"))
    R_v, H_v = 3.2, 5.2

    # Cylindrical vat built from 10 stone staves, leaving a jagged split gap at the front (-Y)!
    for k in range(10):
        a = 2 * math.pi * k / 10
        if k == 7 or k == 8:
            # Cracked staves tilted slightly outward around the breach.
            tilt = 0.22 if k == 7 else -0.18
            m = R(a, 4, "Z") @ T((R_v + 0.2, 0, H_v * 0.45)) @ R(tilt, 4, "Y")
            box(stone, (0.7, 1.9, H_v * 0.85), m)
            continue
        m = R(a, 4, "Z") @ T((R_v, 0, H_v * 0.5))
        box(stone, (0.75, 2.1, H_v), m)

    # Snapped brass reinforcing hoops ringing the vat.
    for hz in (1.1, 2.8, 4.5):
        pts = [(math.cos(math.radians(-55 + 290 * k / 20)) * (R_v + 0.42),
                math.sin(math.radians(-55 + 290 * k / 20)) * (R_v + 0.42), hz) for k in range(21)]
        tube(metal, pts, [0.22] * len(pts), 6, cap=True)
    ring_mesh(trim, R_v + 0.1, 0.22, 22, T((0, 0, H_v + 0.1)), tube_segs=5)

    # Interior dark indigo ink level + pouring ink stream + multi-lobe floor puddle spreading toward -Y!
    cyl_z(alt, R_v - 0.3, 2.4, (0, 0, 0.2), segs=16)
    cyl_z(crystal, R_v - 0.35, 0.18, (0, 0, 2.55), segs=16)
    # Pouring tongue of ink spilling out the crack down onto the floor.
    box(alt, (1.6, 1.8, 2.6), T((0.2, -R_v - 0.4, 1.3)) @ R(math.radians(28), 4, "X"))
    # Organic multi-lobe spilled ink puddle across the ground (z = 0.04..0.24).
    for px, py, pr in ((0.4, -4.8, 3.6), (-2.1, -6.2, 2.4), (2.6, -5.8, 2.2), (0.8, -8.2, 1.8), (-1.4, -3.5, 2.0)):
        cyl_z(alt, pr, 0.16, (px, py, 0.02), segs=14)
        cyl_z(crystal, pr * 0.85, 0.08, (px, py, 0.14), segs=12)
    for k in range(5):
        uvsphere(glow, 0.16, T((-1.5 + k * 0.9, -5.0 - (k % 2) * 1.4, 0.24)), 6, 5)


# -----------------------------------------------------------------------------------------------------------
# 16. ColophonWall — Monument wall mosaic bound with framed gold-illuminated colophon pages
# -----------------------------------------------------------------------------------------------------------
@template("ColophonWall", STONE=2200, WOOD=1800, TRIM=2200, SILK=1600, ALT=1200, GLOW=900)
def colophon_wall(t):
    """Colophon Plate's monument wall: a 24-stud-wide stepped vellum-and-ebony archive wall mosaic inlaid
    with 15 brass-framed final manuscript pages (colophons) stamped with gold star-quill seals."""
    stone, wood, trim, silk, alt, glow = (t.bm(r) for r in ("STONE", "WOOD", "TRIM", "SILK", "ALT", "GLOW"))
    W, H = 24.0, 14.0

    # Stepped vellum-stone plinth, dark ebony backing wall & fractured gold pediment cornice.
    box(stone, (W + 1.6, 3.6, 1.4), T((0, 0, 0.7)), bevel=0.1)
    box(wood, (W, 2.2, H - 2.0), T((0, 0, 1.4 + (H - 2.0) * 0.5)))
    box(stone, (W + 1.2, 3.0, 1.1), T((0, 0, H - 0.1)), bevel=0.1)
    box(trim, (W + 1.5, 3.2, 0.35), T((0, 0, H + 0.55)))
    # Flanking fluted pilasters.
    for sx in (-1, 1):
        box(stone, (2.2, 3.2, H), T((sx * (W * 0.5 + 0.3), 0, H * 0.5)), bevel=0.08)
        cone(trim, 0.85, 0.06, 2.2, 4, T((sx * (W * 0.5 + 0.3), 0, H + 0.6)) @ R(math.pi / 4, 4, "Z"))

    # 5 columns x 3 rows of brass-framed illuminated colophon last-pages mounted on the front face (-Y)!
    for col in range(5):
        cx = -8.4 + col * 4.2
        for row in range(3):
            cz = 3.2 + row * 3.5
            # Brass frame + vellum page + indigo colophon block + glowing gold seal stamp.
            box(trim, (3.2, 0.35, 2.7), T((cx, -1.2, cz)))
            box(silk, (2.6, 0.42, 2.15), T((cx, -1.24, cz)))
            box(alt, (1.8, 0.46, 0.85), T((cx, -1.26, cz + 0.35)))
            uvsphere(glow if (col + row) % 2 == 0 else trim, 0.32, T((cx, -1.48, cz - 0.45)), 8, 6)


# -----------------------------------------------------------------------------------------------------------
# 17. BrokenOrreryRing — Snapped brass armillary ring & broken fluted column drum (Ruled Court debris)
# -----------------------------------------------------------------------------------------------------------
@template("BrokenOrreryRing", METAL=2200, TRIM=1600, STONE=1800, ALT=700, GLOW=400)
def broken_orrery_ring(t):
    """Debris hurled from the Index Engine across the Ruled Court (seen right on the foreground court in the
    guide image): a snapped, bent brass armillary ring half-embedded in flagstones beside a fallen fluted
    vellum-stone column drum and a loose brass spur gear."""
    metal, trim, stone, alt, glow = (t.bm(r) for r in ("METAL", "TRIM", "STONE", "ALT", "GLOW"))

    # Cracked stone debris pad.
    slab_stone(alt, (7.0, 6.2, 0.8), (0, 0, 0.35), seed=4390, roughness=0.2)

    # Snapped bent brass armillary/orrery ring tilted at 34 degrees, one quadrant ripped away.
    rm = T((-1.2, 0.4, 3.8)) @ R(math.radians(24), 4, "Z") @ R(math.radians(32), 4, "X")
    pts1 = [(math.cos(math.radians(-40 + 255 * k / 20)) * 5.2, math.sin(math.radians(-40 + 255 * k / 20)) * 5.2, 0) for k in range(21)]
    tube(metal, pts1, [0.42] * len(pts1), 6, mat=rm, cap=True)
    pts2 = [(math.cos(math.radians(20 + 190 * k / 16)) * 4.1, 0, math.sin(math.radians(20 + 190 * k / 16)) * 4.1) for k in range(17)]
    tube(trim, pts2, [0.28] * len(pts2), 6, mat=rm, cap=True)
    uvsphere(glow, 0.65, rm @ T((0, 0, 0)), 8, 6)

    # Fallen broken fluted vellum-stone column drum lying beside the ring (+X).
    cm = T((4.8, -1.6, 1.55)) @ R(math.radians(-22), 4, "Z") @ R(math.pi / 2, 4, "Y")
    cone(stone, 1.55, 1.55, 5.4, 14, cm @ T((0, 0, -2.7)))
    ring_mesh(trim, 1.62, 0.16, 16, cm @ T((0, 0, -2.5)), tube_segs=5)

    # Loose brass gear wheel lying flat on the flagstones in front (-Y).
    spoked_gear(metal, trim, 2.2, 0.45, 12, T((-3.6, -3.2, 0.32)), spokes=5)


# -----------------------------------------------------------------------------------------------------------
# 18. PageFallRibbon — Sculpted 3D waterfall cascade of tumbling vellum pages over a rift cliff!
# -----------------------------------------------------------------------------------------------------------
@template("PageFallRibbon", SILK=3200, TRIM=1200, ALT=600, GLOW=400)
def page_fall_ribbon(t):
    """Floor 43's iconic sculpted Page Fall (seen cascading like white waterfalls down every fractured cliff
    in the guide image!): 64 individually angled & curved 3D vellum manuscript pages tumbling over an upper
    lip (Z = 22) and cascading 22 studs down into the rift to Z = 0, catching pale starlight glints. Pure
    sculpted mesh — zero flat semi-transparent boxes."""
    silk, trim, alt, glow = (t.bm(r) for r in ("SILK", "TRIM", "ALT", "GLOW"))
    rng = random.Random(4395)

    # Parabolic waterfall trajectory: starts flat on the ledge at (Y = +4.5, Z = 21.5), crests at Y = 0, falls to (Y = -7.5, Z = 0.2).
    n_pages = 64
    for k in range(n_pages):
        f = k / (n_pages - 1)  # 0 at top ledge, 1 at bottom of waterfall
        spread_w = 5.5 + f * 5.2
        px = rng.uniform(-spread_w * 0.5, spread_w * 0.5)
        if f < 0.22:
            # Pooling and spilling across the upper ledge.
            u = f / 0.22
            py = 4.6 - u * 4.6
            pz = 21.6 - (u ** 2) * 1.4 + rng.uniform(-0.25, 0.25)
            pitch = math.radians(-12 - u * 42)
        else:
            # Tumbling waterfall arc plunging down into the chasm!
            u = (f - 0.22) / 0.78
            py = -u * 6.8 + math.sin(u * math.pi) * 1.1 + rng.uniform(-0.7, 0.7)
            pz = max(0.15, 20.2 * (1.0 - u ** 1.45) + rng.uniform(-0.5, 0.5))
            pitch = math.radians(-62 + rng.uniform(-35, 35))

        yaw = rng.uniform(-0.65, 0.65)
        roll = rng.uniform(-0.45, 0.45)
        pw = rng.uniform(1.35, 2.25)
        pd = rng.uniform(1.05, 1.75)
        pm = T((px, py, pz)) @ R(yaw, 4, "Z") @ R(pitch, 4, "X") @ R(roll, 4, "Y")
        # Gently folded 2-panel fluttering page silhouette!
        box(silk, (pw * 0.55, pd, 0.08), pm @ T((-pw * 0.25, 0, 0)) @ R(0.22, 4, "Y"))
        box(silk, (pw * 0.55, pd, 0.08), pm @ T((pw * 0.25, 0, 0)) @ R(-0.22, 4, "Y"))
        if k % 5 == 0:
            box(trim, (pw * 0.35, pd * 0.22, 0.11), pm @ T((0, 0, 0.04)))
        elif k % 11 == 0:
            box(alt, (pw * 0.42, pd * 0.32, 0.11), pm @ T((0, 0, 0.04)))
    # Subtle starlight motes tumbling within the page fall.
    for k in range(6):
        u = (k + 0.5) / 6.0
        uvsphere(glow, 0.26, T((rng.uniform(-2.5, 2.5), -u * 5.2, 18.0 * (1.0 - u))), 6, 5)


# -----------------------------------------------------------------------------------------------------------
# 19. CrookedIndexLamp — Bent fractured Index Lamp post with snapped chain & glowing lantern
# -----------------------------------------------------------------------------------------------------------
@template("CrookedIndexLamp", STONE=700, METAL=1400, TRIM=1200, CRYSTAL=500, GLOW=500)
def crooked_index_lamp(t):
    """Floor 43's crooked Index Lamp (seen tilting on the floating shards in the guide image): a cracked
    vellum-stone plinth, a bent brass standard tilted 13 degrees with a snapped chain trailing off its arm,
    and its glowing pale-gold star-quill lantern hanging plumb despite the tilt."""
    stone, metal, trim, crystal, glow = (t.bm(r) for r in ("STONE", "METAL", "TRIM", "CRYSTAL", "GLOW"))
    # Cracked octagonal base standing level on z = 0.
    cone(stone, 1.65, 1.4, 0.65, 8, T((0, 0, 0)) @ R(math.pi / 8, 4, "Z"))
    cone(stone, 1.2, 0.9, 1.1, 8, T((0, 0, 0.65)) @ R(math.pi / 8, 4, "Z"))
    # Tilted brass pole (bent 13 degrees to +X and 6 degrees forward!).
    tm = T((0, 0, 1.5)) @ R(math.radians(13), 4, "Y") @ R(math.radians(-6), 4, "X")
    lathe(metal, [(0.52, 0.0), (0.30, 1.2), (0.24, 5.2), (0.38, 5.6), (0.22, 9.4)], 10, tm)
    arm_pts = [tm @ Vector(p) for p in ((0, 0, 9.2), (0, -0.4, 10.4), (0, -1.35, 11.1), (0, -2.2, 10.7), (0, -2.35, 10.0))]
    tube(metal, arm_pts, [0.18, 0.16, 0.15, 0.14, 0.12], 6, cap=True)
    # Lantern hangs vertically plumb from the bent arm's tip!
    tip = arm_pts[-1]
    index_lantern_head(metal, trim, crystal, glow, T((tip.x, tip.y, tip.z - 1.55)), scale=0.92)
    # Snapped secondary brass chain dangling loose from the mid-shaft collar.
    mid = tm @ Vector((0, 0, 5.6))
    chain_run(metal, trim, mid, (mid.x + 0.8, mid.y + 0.4, 2.2), link_h=1.0, link_w=0.55, thick=0.1)


if __name__ == "__main__":
    kit, manifest = build_kit("AstralF43Kit", F43_TEMPLATES, DEFAULT_BUDGET)
    apply_halcyr_preview_materials(kit)
    export_kit(kit, manifest, OUT_DIR, "AstralF43Kit")
    render_previews(kit, F43_TEMPLATES, OUT_DIR)
    print(json.dumps(manifest, indent=2))
