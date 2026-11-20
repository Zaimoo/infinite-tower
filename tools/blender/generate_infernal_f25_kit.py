"""
Infernal Foundry Floor 25 (Titan's Crucible) sculpted assets, generated in headless Blender.

Inspired by the Titan's Crucible boss-arena concept art: the colossal Great Crucible on twin geared trunnion
towers behind the dark-iron dais, the glowing Titan Heart Grate inside its mouth, twin towering Great Bellows
frames feeding curved Duct Manifolds, the Pour Spout funnel catching the molten overflow above the Pour Gate,
giant moulds for a Titan's fist and helm, a gear-driven Pattern Lathe in the Pattern Shop, stacked steel beams
and Ingot Pallets in the Ingot Store, Hanging Chain Runs and Chain Gallery Rails along the high catwalks, and
cathedral-scale Vault Rib Arches framing the black cavern vault.

1 Blender unit = 1 stud, standing on z = 0, front facing -Y in Blender / +Z in Roblox, one mesh object per colour
role named "<Template>__<ROLE>".

Roles (TowerSetPieces passes a Sootwright override): METAL iron, TRIM dark iron, STONE basalt brickwork,
GOLD brass fittings & sigil, WOOD timber/patterns, ACCENT rust/copper, GLOW molten gold & heart fire.

Outputs (assets-source/tower/infernal_f25_kit/): InfernalF25Kit.blend, InfernalF25Kit.fbx, manifest.json,
previews/kit_sheet_1.png.

Run:
    blender.exe --background --factory-startup --python tools/blender/generate_infernal_f25_kit.py
"""
import bpy, bmesh, math, os, json, runpy, random
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT_DIR = os.path.join(ROOT, "assets-source", "tower", "infernal_f25_kit")

f24 = runpy.run_path(os.path.join(HERE, "generate_infernal_f24_kit.py"))
box, cone, uvsphere, tube, ring_mesh = f24["box"], f24["cone"], f24["uvsphere"], f24["tube"], f24["ring_mesh"]
cyl_x, cyl_y, cyl_z = f24["cyl_x"], f24["cyl_y"], f24["cyl_z"]
strut, wheel_x, gear_ring, railing, chain = f24["strut"], f24["wheel_x"], f24["gear_ring"], f24["railing"], f24["chain"]
arch_ring = f24["arch_ring"]
build_kit, export_kit, render_previews = f24["build_kit"], f24["export_kit"], f24["render_previews"]
T = Matrix.Translation
R = Matrix.Rotation

DEFAULT_BUDGET = 3500
F25_TEMPLATES = {}


def template(name, **budget):
    def deco(fn):
        F25_TEMPLATES[name] = (fn, budget)
        return fn
    return deco


@template("GreatCrucible", METAL=2800, TRIM=2600, STONE=2000, GOLD=1400, GLOW=1200)
def great_crucible(t):
    """The colossal Great Crucible on twin geared trunnion towers: massive circular furnace cauldron with riveted
    iron hoops, toothed tilting sector gears on both flanks, barred glowing furnace throat, and molten pouring
    lip facing forward (-Y)."""
    metal, trim, stone, gold, glow = (t.bm(r) for r in ("METAL", "TRIM", "STONE", "GOLD", "GLOW"))
    # Broad stepped basalt foundation piers under twin trunnion towers.
    box(stone, (74.0, 32.0, 10.0), T((0, 0, 5.0)))
    for sx in (-1, 1):
        tx = sx * 30.0
        box(stone, (14.0, 26.0, 52.0), T((tx, 2.0, 36.0)))
        for z in (20.0, 36.0, 52.0, 62.0):
            box(trim, (15.2, 27.2, 1.8), T((tx, 2.0, z)))
        # Upper trunnion bearing block and giant toothed sector gear wheel.
        box(trim, (11.0, 14.0, 14.0), T((tx, 0.0, 66.0)))
        gear_ring(gold, 13.5, 18, 2.4, T((sx * 23.0, 0.0, 64.0)) @ R(math.pi / 2, 4, "Y"))
        # Massive iron trunnion axle pin.
        cyl_x(metal, 3.6, 14.0, (sx * 24.5, 0.0, 64.0), segs=14)
    # The colossal cauldron vessel suspended horizontally/tilted forward between the trunnions.
    # Outer riveted drum & conical furnace belly.
    cyl_y(metal, 21.5, 26.0, (0, 2.0, 64.0), segs=24)
    ring_mesh(trim, 22.4, 2.2, 26, T((0, -10.5, 64.0)) @ R(math.pi / 2, 4, "X"), tube_segs=8)
    ring_mesh(trim, 22.2, 1.6, 26, T((0, 0.0, 64.0)) @ R(math.pi / 2, 4, "X"), tube_segs=6)
    ring_mesh(trim, 22.2, 1.6, 26, T((0, 10.5, 64.0)) @ R(math.pi / 2, 4, "X"), tube_segs=6)
    # Recessed blazing crucible mouth with heavy vertical grate bars and radiant molten pool!
    cyl_y(glow, 17.8, 1.8, (0, -9.8, 64.0), segs=22)
    for k in range(9):
        bx = -13.6 + k * 3.4
        bh = 2.0 * math.sqrt(max(1.0, 17.2 ** 2 - bx ** 2))
        box(trim, (1.1, 1.4, bh), T((bx, -11.4, 64.0)))
    box(trim, (34.0, 1.8, 1.8), T((0, -11.4, 64.0)))
    # Heavy pouring spout lip jutting from the bottom of the cauldron mouth (-Y).
    box(metal, (14.0, 10.0, 4.0), T((0, -14.0, 45.0)) @ R(math.radians(18), 4, "X"))
    for sx in (-6.4, 6.4):
        box(trim, (1.8, 11.0, 6.5), T((sx, -14.0, 47.5)) @ R(math.radians(18), 4, "X"))
    box(glow, (10.4, 10.5, 1.6), T((0, -14.2, 47.0)) @ R(math.radians(18), 4, "X"))
    # Towering crown exhaust flue & ribs rising above the cauldron (total height ~98 at scale 1).
    box(stone, (24.0, 18.0, 14.0), T((0, 5.0, 88.0)))
    ring_mesh(gold, 10.5, 1.2, 18, T((0, 5.0, 96.0)), tube_segs=6)
    # Lower receiving spillway arch underneath the cauldron between the piers.
    arch_ring(stone, (0, -6.0, 26.0), 17.5, 4.0, 12.0, segs=16)


@template("TitanHeartGrate", TRIM=2200, METAL=1400, GOLD=1200, GLOW=1000)
def titan_heart_grate(t):
    """The Titan's Heart furnace grate: massive circular toothed gear-ring frame set with heavy forged iron bars
    caging an anvil-shaped blazing molten heart core."""
    trim, metal, gold, glow = (t.bm(r) for r in ("TRIM", "METAL", "GOLD", "GLOW"))
    cx, cy, cz = 0.0, 0.0, 14.0
    box(trim, (26.0, 4.0, 2.6), T((0, 0, 1.3)))
    face = T((cx, cy, cz)) @ R(math.pi / 2, 4, "X")
    gear_ring(gold, 12.2, 16, 2.0, face)
    ring_mesh(trim, 10.2, 1.1, 24, face, tube_segs=6)
    cyl_y(metal, 10.4, 2.2, (cx, 1.4, cz), segs=22)
    # Blazing anvil-forged heart core behind the bars.
    cyl_y(glow, 8.8, 0.8, (cx, 0.1, cz), segs=20)
    box(glow, (6.5, 1.6, 8.2), T((cx, -0.4, cz)))
    # Heavy forged grate bars crossing the front.
    for k in range(7):
        bx = -7.5 + k * 2.5
        bh = 2.0 * math.sqrt(max(1.0, 9.5 ** 2 - bx ** 2))
        box(trim, (0.75, 1.0, bh), T((bx, -1.2, cz)))
    for bz in (cz - 4.0, cz + 4.0):
        box(metal, (18.2, 1.1, 0.85), T((0, -1.2, bz)))


@template("GreatBellows", STONE=2200, METAL=2000, TRIM=2200, WOOD=1200, ACCENT=600)
def great_bellows(t):
    """A colossal Sootwright Bellows Tower (the Foundry's lungs): heavy basalt masonry plinth, towering braced
    iron lattice frame, stacked pleated bellows chambers, top rocker beam, and side blast-pipe outlet."""
    stone, metal, trim, wood, accent = (t.bm(r) for r in ("STONE", "METAL", "TRIM", "WOOD", "ACCENT"))
    # Heavy basalt plinth with iron hoops.
    box(stone, (24.0, 22.0, 14.0), T((0, 0, 7.0)))
    for z in (4.0, 13.4):
        box(trim, (25.0, 23.0, 1.2), T((0, 0, z)))
    # Four heavy raking corner legs of the lattice bellows tower rising from z=14 to z=56.
    h0, h1 = 14.0, 56.0
    for sx in (-1, 1):
        for sy in (-1, 1):
            strut(trim, (sx * 9.6, sy * 8.6, h0), (sx * 6.8, sy * 6.2, h1), 1.5)
    # Cross-bracing tiers.
    for k in range(4):
        z0 = h0 + k * (h1 - h0) / 4
        z1 = z0 + (h1 - h0) / 4
        r0 = 9.6 - k * 0.7
        r1 = 9.6 - (k + 1) * 0.7
        for sy in (-1, 1):
            strut(metal, (-r0, sy * (r0 * 0.9), z0), (r1, sy * (r1 * 0.9), z1), 0.55)
            strut(metal, (r0, sy * (r0 * 0.9), z0), (-r1, sy * (r1 * 0.9), z1), 0.55)
        box(trim, (r1 * 2.1, r1 * 1.9, 0.9), T((0, 0, z1)))
    # Pleated accordion bellows chambers stacked inside the frame.
    for k in range(6):
        z = 18.0 + k * 5.2
        w_pleat = 13.6 - (k % 2) * 2.2
        d_pleat = 12.2 - (k % 2) * 2.0
        box(wood if k % 2 == 0 else accent, (w_pleat, d_pleat, 2.4), T((0, 0, z)))
        box(metal, (14.2, 12.8, 0.55), T((0, 0, z + 1.4)))
    # Heavy top crown cap and piston rocker beam.
    box(trim, (17.0, 15.5, 3.2), T((0, 0, h1 + 1.6)))
    box(metal, (19.0, 5.0, 2.6), T((0, 0, h1 + 5.2)) @ R(math.radians(8), 4, "Y"))
    cyl_z(accent, 1.8, 12.0, (0, 0, h1 - 6.0), segs=12)
    # Large flanged blast-air outlet nozzle jutting from the plinth (-Y).
    cyl_y(metal, 4.2, 7.0, (0, -13.0, 8.5), segs=16)
    ring_mesh(trim, 4.6, 0.55, 18, T((0, -16.2, 8.5)) @ R(math.pi / 2, 4, "X"), tube_segs=6)


@template("TitanMouldFist", STONE=1600, METAL=2200, TRIM=1600, GLOW=700)
def titan_mould_fist(t):
    """A colossal cast-iron foundry mould for the Ember Titan's articulated gauntlet/fist: heavy riveted sand
    flask with clamping lugs, four sculpted armoured finger cavities, and glowing molten runner sprues."""
    stone, metal, trim, glow = (t.bm(r) for r in ("STONE", "METAL", "TRIM", "GLOW"))
    # Massive lower iron flask box & sand bed.
    box(trim, (20.0, 16.0, 4.2), T((0, 0, 2.1)))
    box(stone, (18.2, 14.2, 3.8), T((0, 0, 2.5)))
    for sx in (-1, 1):
        for sy in (-1, 1):
            box(metal, (2.2, 2.2, 5.0), T((sx * 10.4, sy * 6.0, 2.5)))
    # Sculpted colossal Titan gauntlet resting half-cast in the mould.
    box(metal, (11.0, 7.6, 4.6), T((0, 1.6, 5.4)), bevel=0.4)
    box(trim, (11.6, 2.2, 5.0), T((0, 5.2, 5.6)))
    # Four articulated armoured fingers & thumb gripping upward.
    for k in range(4):
        fx = -4.2 + k * 2.8
        box(metal, (2.2, 4.2, 3.4), T((fx, -3.6, 5.2)) @ R(math.radians(18), 4, "X"), bevel=0.25)
        box(trim, (2.0, 2.6, 2.8), T((fx, -5.8, 7.4)) @ R(math.radians(48), 4, "X"))
    box(metal, (2.8, 4.6, 3.0), T((-6.8, -1.6, 5.6)) @ R(math.radians(-30), 4, "Z"))
    # Glowing molten feed channels around the casting.
    box(glow, (14.5, 0.8, 0.35), T((0, -6.2, 4.45)))
    box(glow, (12.2, 0.7, 0.35), T((0, 5.8, 4.45)))
    for sx in (-5.6, 5.6):
        box(glow, (0.7, 11.4, 0.35), T((sx, 0, 4.45)))


@template("TitanMouldHelm", STONE=1600, METAL=2200, TRIM=1600, GLOW=700)
def titan_mould_helm(t):
    """A colossal foundry mould cradle holding the Ember Titan's horned furnace greathelm: riveted iron flask,
    heavy ribbed dome, glowing furnace visor grille, and twin sweeping iron horns."""
    stone, metal, trim, glow = (t.bm(r) for r in ("STONE", "METAL", "TRIM", "GLOW"))
    box(trim, (18.0, 18.0, 4.0), T((0, 0, 2.0)))
    box(stone, (16.0, 16.0, 3.6), T((0, 0, 2.4)))
    # Giant greathelm crown & face plate rising out of the flask.
    cyl_z(metal, 6.2, 9.5, (0, 0, 4.0), segs=14)
    uvsphere(metal, 6.2, T((0, 0, 13.5)) @ Matrix.Diagonal((1.0, 1.0, 0.7, 1)), 14, 8)
    box(trim, (1.4, 13.0, 12.0), T((0, 0, 11.8)))
    # Glowing furnace visor grille on front (-Y).
    box(glow, (7.6, 0.8, 3.4), T((0, -6.1, 9.6)))
    for k in range(5):
        box(trim, (0.55, 1.2, 3.8), T((-3.2 + k * 1.6, -6.4, 9.6)))
    # Twin curved forged crown horns.
    for sx in (-1, 1):
        pts = [(sx * 5.6, 0, 12.2), (sx * 9.5, -1.0, 14.5), (sx * 11.2, -3.2, 18.5)]
        tube(trim, pts, [1.5, 1.05, 0.35], 10, cap=True)
    ring_mesh(glow, 6.6, 0.35, 18, T((0, 0, 4.3)), tube_segs=5)


@template("HangingChainRun", TRIM=2200, METAL=1600, GOLD=600)
def hanging_chain_run(t):
    """A massive overhead foundry chain run with trolley pulley carriage, twin forged iron chains, heavy shackle
    block, and colossal brass-rimmed crane hook (stands on its hook tip at z = 0 so callers hang it cleanly)."""
    trim, metal, gold = (t.bm(r) for r in ("TRIM", "METAL", "GOLD"))
    h = 34.0
    # Hook tip at z = 0 curving up to the heavy sheave block at z = 4..8.
    hook_pts = [(1.8, 0, 2.6), (1.4, 0, 0.7), (0.0, 0, 0.3), (-1.4, 0, 1.1), (-1.2, 0, 3.0), (0.0, 0, 4.2)]
    tube(gold, hook_pts, [0.42, 0.55, 0.62, 0.55, 0.48, 0.52], 10, cap=True)
    box(trim, (4.2, 2.8, 4.4), T((0, 0, 6.4)))
    cyl_y(metal, 1.4, 3.2, (0, 0, 6.8), segs=12)
    # Twin forged heavy chains climbing up to the overhead trolley carriage at z = h.
    for sx in (-1.2, 1.2):
        chain(trim, (sx, 0, 8.6), (sx, 0, h - 2.6), link=1.2)
    # Overhead girder pulley carriage box.
    box(metal, (7.4, 5.2, 3.4), T((0, 0, h - 1.7)))
    for sx in (-2.6, 2.6):
        wheel_x(trim, gold, 1.4, 0.5, (sx, 0, h - 0.6), spokes=4, bm_spoke=trim)


@template("PourSpoutChute", STONE=1800, METAL=2200, TRIM=1800, GLOW=900, ACCENT=500)
def pour_spout_chute(t):
    """The iconic Pour Spout funnel (from the centre of the concept art): battered basalt pedestal supporting a
    flared iron receiving funnel, riveted side overflow spout, valves, and blazing molten pool inside."""
    stone, metal, trim, glow, accent = (t.bm(r) for r in ("STONE", "METAL", "TRIM", "GLOW", "ACCENT"))
    # Battered stone pedestal & iron collar.
    box(stone, (16.0, 16.0, 6.0), T((0, 0, 3.0)))
    cone(stone, 7.6, 6.2, 8.0, 8, T((0, 0, 6.0)))
    ring_mesh(trim, 6.6, 0.6, 18, T((0, 0, 13.8)), tube_segs=6)
    # Wide flared iron smelting funnel basin.
    cone(metal, 5.8, 10.6, 7.5, 18, T((0, 0, 14.0)))
    ring_mesh(trim, 10.9, 0.75, 22, T((0, 0, 21.5)), tube_segs=6)
    for k in range(8):
        a = k * math.pi / 4
        m = R(a, 4, "Z")
        box(trim, (0.9, 1.4, 7.8), m @ T((8.2, 0, 17.6)) @ R(math.radians(-30), 4, "Y"))
    # Blazing molten metal brimming inside the funnel.
    cyl_z(glow, 9.4, 0.4, (0, 0, 20.6), segs=18)
    # Forward overflow pouring lip (-Y) & side pressure valve wheel.
    box(metal, (5.2, 6.4, 3.2), T((0, -11.4, 19.6)))
    box(glow, (3.4, 6.6, 0.8), T((0, -11.6, 20.9)))
    wheel_x(accent, trim, 2.2, 0.4, (8.6, 0, 12.0), spokes=6, bm_spoke=trim)


@template("DuctManifold", METAL=2400, TRIM=1800, ACCENT=600, GOLD=500)
def duct_manifold(t):
    """A colossal curved blast-air duct manifold (straight from West Duct & East Duct in the concept art):
    sweeping giant riveted iron pipe curving 90 degrees from horizontal into a flanged vertical standpipe, with
    heavy bolted flange rings, saddle cradles, and brass pressure gauges."""
    metal, trim, accent, gold = (t.bm(r) for r in ("METAL", "TRIM", "ACCENT", "GOLD"))
    r = 4.4
    # Horizontal entry run -> curved elbow -> vertical drop into a flanged shoe at z=0.
    pts = [
        (0, 16.0, 18.0),
        (0, 6.0, 18.0),
        (0, 1.5, 16.8),
        (0, -1.8, 13.8),
        (0, -3.0, 9.5),
        (0, -3.0, 1.0),
    ]
    tube(metal, pts, [r] * len(pts), 18, cap=True)
    # Heavy flanged collar rings along horizontal and vertical runs.
    for y in (14.5, 8.5):
        ring_mesh(trim, r + 0.45, 0.55, 22, T((0, y, 18.0)) @ R(math.pi / 2, 4, "X"), tube_segs=6)
    for z in (8.5, 3.5):
        ring_mesh(trim, r + 0.45, 0.55, 22, T((0, -3.0, z)), tube_segs=6)
    # Flanged floor shoe and twin steel cradle legs under the horizontal run.
    box(trim, (12.0, 12.0, 2.0), T((0, -3.0, 1.0)))
    for y in (8.5, 14.5):
        box(trim, (10.5, 2.0, 14.2), T((0, y, 7.1)))
        box(accent, (11.5, 3.2, 1.4), T((0, y, 0.7)))
    # Side brass pressure gauge and damper wheel.
    cyl_x(gold, 1.4, 0.8, (r + 0.7, 11.5, 18.0), segs=12)
    wheel_x(accent, trim, 2.0, 0.35, (r + 1.0, -3.0, 6.2), spokes=6, bm_spoke=trim)


@template("IngotPallet", WOOD=1200, METAL=2000, TRIM=1400, GLOW=500)
def ingot_pallet(t):
    """A heavy foundry pallet stacked high with long forged dark-steel girders and glowing fresh-poured ingot
    bars lashed with iron straps (straight from Ingot Store in the concept art)."""
    wood, metal, trim, glow = (t.bm(r) for r in ("WOOD", "METAL", "TRIM", "GLOW"))
    # Heavy timber sleeper base.
    box(wood, (14.0, 8.6, 0.7), T((0, 0, 0.35)))
    for x in (-5.6, 0.0, 5.6):
        box(trim, (0.9, 8.8, 0.6), T((x, 0, 0.9)))
    # Lower two tiers of long forged dark-steel beams.
    for row in range(2):
        z = 1.85 + row * 1.35
        for k in range(5):
            y = -3.2 + k * 1.6
            box(metal if (k + row) % 2 == 0 else trim, (13.4, 1.25, 1.1), T((0, y, z)))
    # Upper tier of fresh-cast trapezoidal ingots, several still glowing warm orange!
    for k in range(4):
        y = -2.4 + k * 1.6
        for ix in (-3.6, 0.0, 3.6):
            bm = glow if (k == 1 and ix == 0.0) or (k == 2 and ix == 3.6) else metal
            box(bm, (3.0, 1.15, 0.95), T((ix, y, 4.35)))
    # Iron strapping bands holding the stack.
    for x in (-4.4, 4.4):
        box(trim, (0.45, 8.4, 3.8), T((x, 0, 2.6)))


@template("PatternLathe", METAL=2400, TRIM=2200, WOOD=1400, GOLD=800, ACCENT=600)
def pattern_lathe(t):
    """A colossal gear-driven industrial foundry pattern lathe (from Pattern Shop on the left of the concept art):
    heavy cast-iron bed, stepped headstock with meshed brass-and-iron cogwheels, tailstock, and a massive turned
    wooden pattern drum mounted on the spindle."""
    metal, trim, wood, gold, accent = (t.bm(r) for r in ("METAL", "TRIM", "WOOD", "GOLD", "ACCENT"))
    # Heavy cast-iron machine bed & legs.
    box(trim, (22.0, 7.2, 2.4), T((0, 0, 3.2)))
    for x in (-9.4, 0.0, 9.4):
        box(trim, (2.6, 7.6, 3.2), T((x, 0, 1.6)))
    # Headstock gear housing on the left (-X) with meshed cogwheels.
    box(metal, (6.0, 6.8, 7.6), T((-8.0, 0, 8.2)))
    gear_ring(gold, 3.6, 14, 1.0, T((-8.0, -3.9, 8.8)) @ R(math.pi / 2, 4, "X"))
    gear_ring(accent, 2.4, 10, 0.9, T((-4.2, -3.9, 6.4)) @ R(math.pi / 2, 4, "X"))
    wheel_x(trim, gold, 2.2, 0.45, (-11.5, 0, 8.8), spokes=6, bm_spoke=trim)
    # Tailstock on the right (+X) and tool carriage in the middle.
    box(metal, (3.6, 5.6, 6.4), T((9.2, 0, 7.6)))
    wheel_x(trim, metal, 1.6, 0.35, (11.5, 0, 8.8), spokes=4, bm_spoke=trim)
    box(accent, (3.4, 7.8, 2.8), T((1.0, -0.6, 5.2)))
    # Massive turned wooden/iron Titan limb pattern mounted between chuck and tailstock.
    cyl_x(trim, 0.85, 16.0, (0.6, 0, 8.8), segs=12)
    cyl_x(wood, 2.6, 10.5, (0.8, 0, 8.8), segs=16)
    for x in (-3.2, 0.8, 4.8):
        ring_mesh(gold, 2.8, 0.28, 16, T((x, 0, 8.8)) @ R(math.pi / 2, 4, "Y"), tube_segs=5)


@template("VaultRibArch", STONE=2400, METAL=1200, TRIM=1200)
def vault_rib_arch(t):
    """A monumental cathedral-scale basalt vault pier and springing rib arch: massive octagonal basalt column
    bound in riveted iron hoops, flaring capital, and sweeping ribbed arch springing inward."""
    stone, metal, trim = (t.bm(r) for r in ("STONE", "METAL", "TRIM"))
    # Broad stepped basalt base & tall column shaft.
    box(stone, (14.0, 14.0, 5.0), T((0, 0, 2.5)))
    cone(stone, 5.8, 5.0, 62.0, 8, T((0, 0, 5.0)))
    for z in (18.0, 34.0, 50.0, 64.0):
        ring_mesh(trim, 5.7, 0.65, 16, T((0, 0, z)), tube_segs=6)
    # Flared Gothic-industrial capital block.
    box(stone, (13.6, 13.6, 5.5), T((0, 0, 69.5)))
    box(metal, (14.4, 14.4, 1.2), T((0, 0, 72.4)))
    # Sweeping ribbed vault half-arch springing toward +X up to z=118.
    segs = 10
    r_arch = 44.0
    for k in range(segs):
        a0 = (math.pi / 2) * (k / segs)
        a1 = (math.pi / 2) * ((k + 1) / segs)
        am = (a0 + a1) / 2
        cx = r_arch - math.cos(am) * r_arch
        cz = 72.0 + math.sin(am) * r_arch
        seg_len = (math.pi / 2) * r_arch / segs * 1.1
        m = T((cx, 0, cz)) @ R(-am, 4, "Y")
        box(stone, (5.2, 6.4, seg_len), m)
        box(trim, (5.8, 2.2, seg_len * 0.96), m @ T((0, -2.8, 0)))
        box(metal, (5.8, 2.2, seg_len * 0.96), m @ T((0, 2.8, 0)))


@template("ChainGalleryRail", TRIM=1800, METAL=1400, GOLD=500)
def chain_gallery_rail(t):
    """A heavy riveted iron chain-gallery balustrade: flanged I-beam stanchions, top and mid rails, brass newel
    bosses, and a sagging forged iron chain draped across the outer face."""
    trim, metal, gold = (t.bm(r) for r in ("TRIM", "METAL", "GOLD"))
    w, h = 22.0, 5.0
    # Kickplate kerb & top/mid handrails.
    box(trim, (w, 1.2, 0.9), T((0, 0, 0.45)))
    box(trim, (w + 0.4, 0.75, 0.65), T((0, 0, h)))
    box(metal, (w, 0.45, 0.45), T((0, 0, h * 0.56)))
    # Four flanged stanchion posts with brass finial bosses.
    for k in range(4):
        x = -w / 2 + 0.6 + k * (w - 1.2) / 3
        box(trim, (0.9, 0.9, h), T((x, 0, h / 2)))
        uvsphere(gold, 0.58, T((x, 0, h + 0.55)), 8, 6)
    # Sagging draped chain festoon across the front (-Y).
    for span in range(3):
        x0 = -w / 2 + 0.6 + span * (w - 1.2) / 3
        x1 = x0 + (w - 1.2) / 3
        xm = (x0 + x1) / 2
        chain(metal, (x0, -0.7, h - 0.6), (xm, -0.7, h - 2.3), link=0.75)
        chain(metal, (xm, -0.7, h - 2.3), (x1, -0.7, h - 0.6), link=0.75)


if __name__ == "__main__":
    kit, manifest = build_kit("InfernalF25Kit", F25_TEMPLATES, DEFAULT_BUDGET)
    export_kit(kit, manifest, OUT_DIR, "InfernalF25Kit")
    render_previews(kit, F25_TEMPLATES, OUT_DIR)
    print(json.dumps(manifest, indent=2))
