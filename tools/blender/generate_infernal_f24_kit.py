"""
Infernal Foundry Floor 24 (Ironflame Bulwark) sculpted assets, generated in headless Blender.

Inspired by the Ironflame Bulwark fortress reference art: dark iron-bound crenellated bulwark walls along two
lava channels, twin sluice towers with vertical chain winches and portcullis gates barring the lava canals,
heavy slag cannons on the west gun deck, powder kegs in the loft, a roaring signal fire brazier atop the west
bastion, a blazing flame-jet portcullis gatehouse, colossal industrial drop-hammers in the east hammer hall,
siege ballistas on the battlements, garrison armour racks, and the monumental Ironflame Citadel keep with its
embossed hammer-ring doors.

1 Blender unit = 1 stud, standing on z = 0, front facing -Y in Blender / +Z in Roblox, one mesh object per colour
role named "<Template>__<ROLE>".

Roles (TowerSetPieces passes a Sootwright override): METAL iron, TRIM dark iron, STONE basalt brickwork,
GOLD brass fittings & sigil, WOOD siege timber, ACCENT rust/copper, GLOW magma & flames.

Outputs (assets-source/tower/infernal_f24_kit/): InfernalF24Kit.blend, InfernalF24Kit.fbx, manifest.json,
previews/kit_sheet_1.png.

Run:
    blender.exe --background --factory-startup --python tools/blender/generate_infernal_f24_kit.py
"""
import bpy, bmesh, math, os, json, runpy, random
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT_DIR = os.path.join(ROOT, "assets-source", "tower", "infernal_f24_kit")

f23 = runpy.run_path(os.path.join(HERE, "generate_infernal_f23_kit.py"))
box, cone, uvsphere, tube, ring_mesh = f23["box"], f23["cone"], f23["uvsphere"], f23["tube"], f23["ring_mesh"]
cyl_x, cyl_y, cyl_z = f23["cyl_x"], f23["cyl_y"], f23["cyl_z"]
strut, wheel_x, gear_ring, railing, chain = f23["strut"], f23["wheel_x"], f23["gear_ring"], f23["railing"], f23["chain"]
arch_ring = f23["arch_ring"]
build_kit, export_kit, render_previews = f23["build_kit"], f23["export_kit"], f23["render_previews"]
T = Matrix.Translation
R = Matrix.Rotation

DEFAULT_BUDGET = 3500
F24_TEMPLATES = {}


def template(name, **budget):
    def deco(fn):
        F24_TEMPLATES[name] = (fn, budget)
        return fn
    return deco


def crenels(bm, x0, x1, y, z_base, merlon_w, merlon_d, merlon_h, count):
    """Row of crenellated fortress merlons along X from x0 to x1."""
    if count <= 1:
        box(bm, (merlon_w, merlon_d, merlon_h), T(((x0 + x1) / 2, y, z_base + merlon_h / 2)))
        return
    for k in range(count):
        x = x0 + (x1 - x0) * k / (count - 1)
        box(bm, (merlon_w, merlon_d, merlon_h), T((x, y, z_base + merlon_h / 2)))


def flame_plume(bm, centre, radius, height, tongues=7, seed=2401):
    """Sculpted cluster of roaring flame tongues for braziers and flame-jet gates."""
    rng = random.Random(seed)
    cx, cy, cz = centre
    cone(bm, radius * 0.82, 0.08, height, 8, T((cx, cy, cz)))
    for k in range(tongues):
        a = 2 * math.pi * k / tongues + rng.uniform(-0.2, 0.2)
        r = radius * rng.uniform(0.32, 0.72)
        h = height * rng.uniform(0.58, 0.92)
        tilt = rng.uniform(0.06, 0.22)
        tx = cx + math.cos(a) * r
        ty = cy + math.sin(a) * r
        m = T((tx, ty, cz)) @ R(a, 4, "Z") @ R(tilt, 4, "Y")
        cone(bm, radius * rng.uniform(0.26, 0.42), 0.06, h, 6, m)


@template("BulwarkWall", STONE=2000, METAL=1400, TRIM=1200, GOLD=500)
def bulwark_wall(t):
    """A fortified basalt-and-iron parapet bulwark segment: battered stone base, riveted iron banding, buttress
    pilasters, crenellated battlements with iron caps, and brass rivet studs."""
    stone, metal, trim, gold = (t.bm(r) for r in ("STONE", "METAL", "TRIM", "GOLD"))
    w, d, h = 24.0, 4.2, 9.5
    box(stone, (w, d + 1.2, 2.2), T((0, 0, 1.1)))
    box(stone, (w, d, h - 2.2), T((0, 0, 2.2 + (h - 2.2) / 2)))
    # Horizontal riveted iron bands across the face.
    for z in (2.4, 6.2, h - 0.4):
        box(trim, (w + 0.4, d + 0.5, 0.65), T((0, 0, z)))
    # Buttress pilasters at ends and centre.
    for x in (-w / 2 + 1.4, 0.0, w / 2 - 1.4):
        box(stone, (2.6, d + 1.8, h), T((x, 0, h / 2)))
        box(metal, (2.9, d + 2.1, 0.7), T((x, 0, h + 0.1)))
        for z in (3.2, 7.2):
            box(trim, (2.8, d + 2.0, 0.5), T((x, 0, z)))
    # Crenellated merlons along the top with iron coping plates.
    for x in (-9.0, -3.0, 3.0, 9.0):
        box(stone, (3.8, d * 0.86, 3.0), T((x, -0.2, h + 1.5)))
        box(metal, (4.2, d * 0.94, 0.45), T((x, -0.2, h + 3.15)))
    # Brass rivets along the top iron band.
    for k in range(9):
        rx = -10.0 + k * 2.5
        for sy in (-1, 1):
            uvsphere(gold, 0.22, T((rx, sy * (d / 2 + 0.3), h - 0.4)), 6, 4)


@template("SluiceTower", STONE=2600, METAL=1600, TRIM=1600, ACCENT=500, GLOW=400)
def sluice_tower(t):
    """A tall narrow crenellated sluice tower standing in a lava channel: battered basalt plinth, riveted iron
    corner straps, vertical winch recess on the front face, glowing furnace slit windows, overhanging corbelled
    battlements, and top capstan housing."""
    stone, metal, trim, accent, glow = (t.bm(r) for r in ("STONE", "METAL", "TRIM", "ACCENT", "GLOW"))
    w, d, h = 15.0, 15.0, 44.0
    # Heavy battered base rising out of the lava.
    box(stone, (w + 3.4, d + 3.4, 6.0), T((0, 0, 3.0)))
    box(trim, (w + 3.8, d + 3.8, 0.8), T((0, 0, 6.2)))
    # Main tower shaft with vertical iron corner straps and horizontal hoops.
    box(stone, (w, d, h - 6.0), T((0, 0, 6.0 + (h - 6.0) / 2)))
    for sx in (-1, 1):
        for sy in (-1, 1):
            box(trim, (1.8, 1.8, h - 4.0), T((sx * (w / 2 - 0.2), sy * (d / 2 - 0.2), 4.0 + (h - 4.0) / 2)))
    for z in (14.0, 24.0, 34.0, 42.5):
        box(metal, (w + 0.8, d + 0.8, 0.9), T((0, 0, z)))
    # Recessed vertical chain chase on the front (-Y) face with hanging chain runs.
    for sx in (-1, 1):
        box(trim, (1.1, 1.8, 30.0), T((sx * 3.2, -d / 2 - 0.6, 23.0)))
        chain(metal, (sx * 1.6, -d / 2 - 0.7, 38.0), (sx * 1.6, -d / 2 - 0.7, 8.0), link=1.1)
    # Glowing furnace slit embrasures on front and sides.
    for z in (19.0, 29.0):
        box(glow, (1.4, 0.3, 4.2), T((0, -d / 2 - 0.1, z)))
        box(trim, (2.2, 0.6, 4.8), T((0, -d / 2 - 0.2, z)))
        for sx in (-1, 1):
            box(glow, (0.3, 1.4, 3.6), T((sx * (w / 2 + 0.1), 0, z)))
    # Corbelled overhanging parapet and battlements.
    box(stone, (w + 2.6, d + 2.6, 3.2), T((0, 0, h + 1.2)))
    box(trim, (w + 3.0, d + 3.0, 0.7), T((0, 0, h - 0.2)))
    for k in range(3):
        off = -5.6 + k * 5.6
        for sy in (-1, 1):
            box(stone, (3.2, 1.8, 3.6), T((off, sy * (d / 2 + 0.4), h + 4.4)))
            box(metal, (3.5, 2.0, 0.45), T((off, sy * (d / 2 + 0.4), h + 6.35)))
        for sx in (-1, 1):
            box(stone, (1.8, 3.2, 3.6), T((sx * (w / 2 + 0.4), off, h + 4.4)))
            box(metal, (2.0, 3.5, 0.45), T((sx * (w / 2 + 0.4), off, h + 6.35)))
    # Top twin chain sheaves / hoist reels.
    for sx in (-3.0, 3.0):
        cyl_x(accent, 2.2, 2.8, (sx, -1.5, h + 4.6), segs=12)
        box(trim, (3.4, 1.2, 4.0), T((sx, -1.5, h + 3.6)))


@template("SluiceGateChain", TRIM=2200, METAL=1600, ACCENT=600)
def sluice_gate_chain(t):
    """A massive iron portcullis gate barring a lava channel: heavy spiked vertical iron bars, riveted cross
    girders, flanking channel guide posts, top hoist beam, and twin vertical lifting chains."""
    trim, metal, accent = (t.bm(r) for r in ("TRIM", "METAL", "ACCENT"))
    w, h = 28.0, 18.0
    # Guide posts anchored into the lava bed.
    for sx in (-1, 1):
        box(trim, (2.4, 2.6, h + 4.0), T((sx * (w / 2 + 1.0), 0, (h + 4.0) / 2)))
        box(metal, (3.2, 3.4, 1.4), T((sx * (w / 2 + 1.0), 0, 0.7)))
    # Top hoist beam and lower gate girders.
    box(trim, (w + 4.4, 2.4, 2.2), T((0, 0, h + 2.8)))
    for z in (3.2, 9.2, 15.2):
        box(metal, (w + 0.4, 1.2, 1.1), T((0, 0, z)))
    # Heavy vertical portcullis bars with forged spikes at the bottom.
    bars = 11
    for k in range(bars):
        x = -w / 2 + 1.4 + k * (w - 2.8) / (bars - 1)
        box(trim, (0.72, 0.72, h - 1.0), T((x, 0, h / 2 + 1.0)))
        cone(metal, 0.55, 0.05, 2.0, 4, T((x, 0, 2.0)) @ R(math.pi, 4, "X"))
    # Twin lifting chains and rusted counterweights.
    for sx in (-1, 1):
        chain(metal, (sx * (w * 0.34), 0, h + 2.0), (sx * (w * 0.34), 0, 15.2), link=0.9)
        cyl_x(accent, 1.3, 2.2, (sx * (w * 0.34), 0, h + 3.8), segs=10)


@template("SlagCannon", METAL=2400, TRIM=1600, WOOD=1400, GOLD=600, GLOW=300)
def slag_cannon(t):
    """A heavy Sootwright siege slag cannon on a stepped iron-bound timber naval carriage: thick tapered iron
    barrel with reinforcing rings, brass cascabel and trunnions, spoked iron wheels, and molten glowing bore."""
    metal, trim, wood, gold, glow = (t.bm(r) for r in ("METAL", "TRIM", "WOOD", "GOLD", "GLOW"))
    # Stepped naval gun carriage cheeks and bed.
    box(wood, (4.8, 10.6, 1.0), T((0, 0.6, 2.0)))
    for sx in (-1, 1):
        box(wood, (0.95, 10.4, 2.6), T((sx * 2.15, 0.6, 3.4)))
        box(wood, (0.95, 7.2, 1.4), T((sx * 2.15, -0.6, 5.1)))
        box(trim, (1.15, 10.6, 0.35), T((sx * 2.15, 0.6, 2.2)))
        # Iron carriage straps & axle trees.
        for y in (-2.8, 3.6):
            wheel_x(trim, metal, 1.75, 0.65, (sx * 3.05, y, 2.0), spokes=6, bm_spoke=trim)
    for y in (-2.8, 3.6):
        cyl_x(trim, 0.48, 6.8, (0, y, 2.0), segs=10)
    # Heavy tapered cannon barrel pointing toward -Y (+Z in Roblox), elevated 9 degrees upward toward the muzzle.
    elev = T((0, -0.4, 6.2)) @ R(math.radians(-9), 4, "X") @ R(math.pi / 2, 4, "X")
    cone(metal, 1.85, 1.25, 13.8, 18, elev @ T((0, 0, -5.0)))
    # Cascabel knob at breech (+Y) & reinforcing bands along barrel.
    uvsphere(gold, 1.05, elev @ T((0, 0, -5.6)), 10, 8)
    for along, rr in ((-4.2, 1.94), (-1.2, 1.78), (2.2, 1.62), (5.6, 1.48), (8.4, 1.56)):
        ring_mesh(trim if along < 7 else gold, rr, 0.28, 18, elev @ T((0, 0, along)), tube_segs=6)
    # Trunnion pins and molten slag glow inside the muzzle (-Y).
    cyl_x(gold, 0.65, 5.4, (0, -0.4, 6.2), segs=10)
    cyl_z(glow, 0.92, 0.35, (0, 0, 0), segs=14)
    # Place glow disc cleanly inside the elevated muzzle bore:
    bmesh.ops.translate(glow, vec=Vector((0, 0, 8.7)), verts=glow.verts[:])
    bmesh.ops.transform(glow, matrix=elev, verts=glow.verts[:])
    # Stack of iron slag shot beside the breech.
    for sx, sy, sz in ((-3.8, 3.4, 0.65), (-2.6, 3.4, 0.65), (-3.2, 4.4, 0.65), (-3.2, 3.7, 1.65)):
        uvsphere(trim, 0.65, T((sx, sy, sz)), 8, 6)


@template("SignalBrazier", STONE=1600, METAL=1600, TRIM=1400, GLOW=1200, GOLD=400)
def signal_brazier(t):
    """A towering iron-bound fortress signal brazier: octagonal basalt pedestal, clawed iron struts supporting a
    massive ribbed fire bowl heaped with embers and roaring sculpted flame tongues."""
    stone, metal, trim, glow, gold = (t.bm(r) for r in ("STONE", "METAL", "TRIM", "GLOW", "GOLD"))
    # Stepped octagonal basalt plinth.
    cone(stone, 7.8, 6.8, 3.0, 8, T((0, 0, 0)))
    cone(stone, 6.2, 5.0, 7.5, 8, T((0, 0, 3.0)))
    ring_mesh(trim, 5.6, 0.45, 16, T((0, 0, 10.4)), tube_segs=6)
    # Four iron support brackets curving out to the fire bowl.
    for k in range(4):
        a = k * math.pi / 2 + math.pi / 4
        m = R(a, 4, "Z")
        strut(trim, m @ Vector((4.2, 0, 6.0)), m @ Vector((6.8, 0, 13.5)), 0.95)
        box(gold, (1.4, 1.4, 1.0), m @ T((6.6, 0, 13.6)))
    # Wide ribbed iron cauldron bowl.
    cone(metal, 4.2, 7.6, 4.6, 16, T((0, 0, 10.6)))
    ring_mesh(trim, 7.8, 0.55, 20, T((0, 0, 15.2)), tube_segs=6)
    for k in range(8):
        a = k * math.pi / 4
        m = R(a, 4, "Z")
        box(trim, (0.7, 1.2, 4.8), m @ T((6.2, 0, 13.0)) @ R(math.radians(-30), 4, "Y"))
    # Ember bed and roaring sculpted flames.
    uvsphere(glow, 6.2, T((0, 0, 14.8)) @ Matrix.Diagonal((1.0, 1.0, 0.35, 1)), 14, 8)
    flame_plume(glow, (0, 0, 15.2), 5.6, 14.5, tongues=8, seed=2405)


@template("DropHammer", METAL=2800, TRIM=2400, STONE=1400, ACCENT=600, GLOW=400)
def drop_hammer(t):
    """A colossal Sootwright steam drop-hammer: twin riveted A-frame iron standards on a stone foundation, overhead
    steam cylinder and flywheel, hanging chains, suspended hammer tup, and a glowing forged billet on the die."""
    metal, trim, stone, accent, glow = (t.bm(r) for r in ("METAL", "TRIM", "STONE", "ACCENT", "GLOW"))
    # Heavy stone anvil foundation and iron die block.
    box(stone, (16.0, 12.0, 3.0), T((0, 0, 1.5)))
    box(trim, (7.6, 6.2, 3.6), T((0, 0, 4.8)))
    box(metal, (6.0, 5.0, 1.2), T((0, 0, 7.2)))
    # Glowing hot steel billet on the anvil die.
    box(glow, (4.4, 2.2, 1.0), T((0, 0, 8.3)))
    # Twin A-frame columns rising to overhead beam.
    for sx in (-1, 1):
        strut(metal, (sx * 7.0, -4.4, 3.0), (sx * 4.4, -1.6, 30.0), 1.6)
        strut(metal, (sx * 7.0, 4.4, 3.0), (sx * 4.4, 1.6, 30.0), 1.6)
        box(trim, (1.4, 4.2, 26.0), T((sx * 4.2, 0, 16.5)))
        for z in (10.0, 18.0, 26.0):
            box(trim, (2.2, 9.0 - (z - 10.0) * 0.22, 0.9), T((sx * (6.2 - (z - 10.0) * 0.09), 0, z)))
    # Heavy crown girder and vertical steam cylinder.
    box(metal, (14.5, 6.4, 4.2), T((0, 0, 31.5)))
    cyl_z(accent, 3.0, 10.5, (0, 0, 33.6), segs=16)
    ring_mesh(trim, 3.25, 0.4, 18, T((0, 0, 38.8)), tube_segs=5)
    ring_mesh(trim, 3.25, 0.4, 18, T((0, 0, 43.8)), tube_segs=5)
    # Piston rod, suspended massive hammer tup, and side guide chains.
    cyl_z(metal, 0.9, 13.5, (0, 0, 20.0), segs=12)
    box(trim, (6.8, 5.2, 6.4), T((0, 0, 17.6)), bevel=0.3)
    box(metal, (6.0, 4.6, 1.4), T((0, 0, 14.0)))
    for sx in (-1, 1):
        chain(metal, (sx * 3.2, -2.6, 30.0), (sx * 3.2, -2.6, 17.8), link=1.0)
    # Side steam pipe and governor flywheel.
    wheel_x(trim, accent, 3.2, 0.7, (7.6, 0, 24.0), spokes=6, bm_spoke=trim)


@template("PowderKegStack", WOOD=2200, TRIM=1600, ACCENT=600)
def powder_keg_stack(t):
    """A munitions pallet stacked with iron-hooped black-powder kegs and an iron-strapped powder chest."""
    wood, trim, accent = (t.bm(r) for r in ("WOOD", "TRIM", "ACCENT"))
    # Timber pallet base.
    box(wood, (8.6, 6.4, 0.5), T((0, 0, 0.25)))
    for y in (-2.4, 0.0, 2.4):
        box(trim, (8.6, 0.45, 0.25), T((0, y, 0.55)))
    # Standing kegs on the left and stacked horizontal kegs on the right.
    for x, y in ((-2.6, -1.5), (-0.4, -1.5), (-1.5, 1.2)):
        cyl_z(wood, 1.05, 3.4, (x, y, 0.5), segs=12)
        for z in (1.1, 2.2, 3.4):
            ring_mesh(trim, 1.08, 0.14, 14, T((x, y, z)), tube_segs=4)
    # Upper keg perched on top of the standing trio.
    cyl_z(wood, 1.0, 3.2, (-1.5, -0.5, 3.9), segs=12)
    for z in (4.5, 6.5):
        ring_mesh(accent, 1.03, 0.14, 14, T((-1.5, -0.5, z)), tube_segs=4)
    # Horizontal barrel resting in a timber cradle and an iron-bound ammo crate.
    cyl_x(wood, 1.05, 3.4, (2.2, -1.4, 1.65), segs=12)
    for x in (1.0, 3.4):
        ring_mesh(trim, 1.08, 0.14, 14, T((x, -1.4, 1.65)) @ R(math.pi / 2, 4, "Y"), tube_segs=4)
    box(wood, (3.4, 2.4, 2.2), T((2.1, 1.4, 1.6)))
    for x in (0.7, 2.1, 3.5):
        box(trim, (0.3, 2.55, 2.35), T((x, 1.4, 1.6)))
    box(accent, (1.2, 0.3, 0.9), T((2.1, 0.15, 1.7)))


@template("FlameJetPortcullis", STONE=2600, METAL=1600, TRIM=1600, GLOW=1600, GOLD=500)
def flame_jet_portcullis(t):
    """The Ironflame Gatehouse & flame-jet portcullis: a fortified dark-brick crenellated gatehouse with three
    glowing upper furnace windows, heavy iron portcullis bars, nozzle headers, and roaring sheets of molten fire
    blazing across the archway."""
    stone, metal, trim, glow, gold = (t.bm(r) for r in ("STONE", "METAL", "TRIM", "GLOW", "GOLD"))
    w, h, d = 38.0, 28.0, 10.0
    # Left and right gatehouse piers with iron bands and plinths.
    for sx in (-1, 1):
        box(stone, (10.5, d, h), T((sx * 13.75, 0, h / 2)))
        box(stone, (12.0, d + 2.0, 3.0), T((sx * 13.75, 0, 1.5)))
        for z in (7.0, 16.0, 25.0):
            box(trim, (11.1, d + 0.6, 0.8), T((sx * 13.75, 0, z)))
    # Upper gatehouse bridge lintel over the 17-stud archway.
    box(stone, (17.5, d, 12.0), T((0, 0, 22.0)))
    box(trim, (w + 1.4, d + 1.0, 1.2), T((0, 0, 16.4)))
    box(trim, (w + 1.8, d + 1.4, 1.2), T((0, 0, h - 0.6)))
    # Three glowing upper furnace windows above the gate (straight from the reference image!).
    for x in (-5.6, 0.0, 5.6):
        box(glow, (2.6, 0.4, 3.8), T((x, -d / 2 - 0.1, 21.8)))
        box(trim, (3.4, 0.8, 4.4), T((x, -d / 2 - 0.2, 21.8)))
    # Crenellated battlements crowning the gatehouse.
    crenels(stone, -16.5, 16.5, -d / 2 + 1.0, h, 3.6, 2.2, 3.4, 7)
    crenels(metal, -16.5, 16.5, -d / 2 + 1.0, h + 3.4, 3.9, 2.4, 0.45, 7)
    # Iron portcullis bars and flame nozzle manifold inside the archway.
    for k in range(7):
        x = -7.2 + k * 2.4
        box(trim, (0.55, 0.55, 15.8), T((x, -1.2, 8.2)))
    for z in (4.5, 9.5, 14.5):
        box(metal, (17.2, 0.8, 0.7), T((0, -1.2, z)))
    box(gold, (16.8, 1.2, 0.9), T((0, -1.8, 0.6)))
    # Roaring wall of sculpted flames inside the portcullis arch!
    box(glow, (16.2, 0.7, 13.5), T((0, 0.4, 7.0)))
    for k, x in enumerate((-6.2, -3.1, 0.0, 3.1, 6.2)):
        flame_plume(glow, (x, -0.8, 0.6), 2.1, 13.8 if k % 2 == 0 else 11.4, tongues=4, seed=2410 + k)


@template("ChainWinch", TRIM=2200, METAL=1600, WOOD=900, GOLD=400)
def chain_winch(t):
    """A heavy angled fortress chain windlass: raking iron-and-timber A-frame, ribbed chain drum wrapped in links,
    geared handwheel, ratchet pawl, and twin tension chains running upward."""
    trim, metal, wood, gold = (t.bm(r) for r in ("TRIM", "METAL", "WOOD", "GOLD"))
    # Heavy anchored base skids.
    for sx in (-1, 1):
        box(wood, (1.4, 9.2, 1.0), T((sx * 3.4, 0, 0.5)))
        strut(trim, (sx * 3.4, -3.8, 1.0), (sx * 3.4, 1.2, 8.8), 0.95)
        strut(trim, (sx * 3.4, 4.0, 1.0), (sx * 3.4, 1.2, 8.8), 0.95)
        box(metal, (1.2, 2.2, 2.4), T((sx * 3.4, 1.2, 4.4)))
    box(trim, (8.2, 1.6, 0.8), T((0, -3.6, 0.9)))
    box(trim, (8.2, 1.6, 0.8), T((0, 3.8, 0.9)))
    # Main chain drum and coiled iron rings.
    cyl_x(metal, 1.65, 6.6, (0, 1.2, 4.4), segs=16)
    for k in range(7):
        x = -2.4 + k * 0.8
        ring_mesh(trim, 1.82, 0.22, 16, T((x, 1.2, 4.4)) @ R(math.pi / 2, 4, "Y"), tube_segs=5)
    # Geared flywheel and brass ratchet cog on the sides.
    wheel_x(trim, metal, 2.8, 0.45, (4.5, 1.2, 4.4), spokes=6, bm_spoke=trim)
    gear_ring(gold, 2.0, 12, 0.5, T((-4.3, 1.2, 4.4)) @ R(math.pi / 2, 4, "Y"))
    # Upper sheave axle and vertical chains rising toward a tower wall.
    cyl_x(gold, 0.55, 7.6, (0, 1.2, 8.8), segs=10)
    for sx in (-1.6, 1.6):
        chain(metal, (sx, 1.2, 8.8), (sx, 1.2, 16.5), link=0.9)


@template("SiegeBallista", WOOD=2000, METAL=1600, TRIM=1400, GOLD=500)
def siege_ballista(t):
    """A fortress torsion siege ballista on a swiveling iron-bound turret pedestal: raking stock rail, twin boxed
    torsion spring drums, heavy iron-shod bow arms, taut bowstring, and a massive barbed siege bolt."""
    wood, metal, trim, gold = (t.bm(r) for r in ("WOOD", "METAL", "TRIM", "GOLD"))
    # Turret base ring and timber pedestal.
    cyl_z(trim, 3.8, 1.2, (0, 0, 0), segs=16)
    box(wood, (3.2, 4.2, 3.4), T((0, 0.4, 2.8)))
    for sx in (-1, 1):
        strut(trim, (sx * 2.8, -1.8, 1.1), (sx * 1.4, 0.4, 4.4), 0.55)
        strut(trim, (sx * 2.8, 2.2, 1.1), (sx * 1.4, 0.4, 4.4), 0.55)
    # Tilted stock aiming toward -Y (+Z in Roblox), elevated 8 degrees upward.
    aim = T((0, 0, 5.2)) @ R(math.radians(-8), 4, "X")
    box(wood, (1.8, 14.2, 1.2), aim @ T((0, 0, 0)))
    box(trim, (2.1, 14.4, 0.35), aim @ T((0, 0, -0.55)))
    # Twin torsion spring frames at the front.
    box(trim, (8.6, 2.6, 2.8), aim @ T((0, -4.6, 0.5)))
    for sx in (-1, 1):
        # Torsion coil drum inside the front frame.
        coil_pos = aim @ Vector((sx * 3.6, -4.6, -1.0))
        cyl_z(gold, 0.85, 3.0, coil_pos, segs=10)
        box(metal, (1.8, 2.8, 3.4), aim @ T((sx * 3.6, -4.6, 0.5)))
        # Heavy bowed torsion arms sweeping back.
        arm_tip = aim @ Vector((sx * 9.2, -1.0, 0.6))
        arm_root = aim @ Vector((sx * 3.8, -4.6, 0.6))
        strut(wood, arm_root, arm_tip, 0.95)
        box(trim, (0.9, 1.1, 1.1), T(arm_tip))
        # Bowstring drawn back to trigger catch.
        strut(metal, arm_tip, aim @ Vector((0, 4.6, 0.7)), 0.16)
    # Rear ratchet windlass and massive barbed iron siege bolt on the rail.
    wheel_x(trim, gold, 1.5, 0.35, (1.8, 6.2, 4.2), spokes=4, bm_spoke=trim)
    strut(wood, aim @ Vector((0, 4.5, 0.85)), aim @ Vector((0, -8.8, 0.85)), 0.36)
    cone(metal, 0.72, 0.04, 2.6, 4, aim @ T((0, -8.8, 0.85)) @ R(math.pi / 2, 4, "X"))


@template("ArmourRack", WOOD=1200, METAL=1800, TRIM=1200, GOLD=600)
def armour_rack(t):
    """A Sootwright garrison armour rack: heavy iron-shod timber stand holding a riveted dark-iron cuirass,
    spiked pauldrons, a brass-trimmed tower shield, and a pair of forged halberds."""
    wood, metal, trim, gold = (t.bm(r) for r in ("WOOD", "METAL", "TRIM", "GOLD"))
    # Stand base and frame.
    box(wood, (7.6, 3.2, 0.6), T((0, 0, 0.3)))
    for sx in (-1, 1):
        box(wood, (0.6, 0.6, 7.6), T((sx * 3.4, 0.4, 4.2)))
    box(wood, (7.8, 0.6, 0.6), T((0, 0.4, 8.0)))
    # Centre armour mannequin T-post with cuirass, helm and pauldrons.
    box(wood, (0.5, 0.5, 6.4), T((-1.2, 0.2, 3.6)))
    box(wood, (3.2, 0.45, 0.45), T((-1.2, 0.2, 5.6)))
    box(metal, (2.2, 1.4, 2.8), T((-1.2, 0.2, 4.8)), bevel=0.25)
    box(gold, (2.3, 1.5, 0.3), T((-1.2, 0.2, 4.8)))
    for sx in (-1, 1):
        uvsphere(trim, 0.75, T((-1.2 + sx * 1.4, 0.2, 5.8)), 8, 6)
    box(metal, (1.3, 1.4, 1.5), T((-1.2, 0.2, 6.9)), bevel=0.3)
    # Brass-rimmed tower shield leaning on the right side.
    shield_cf = T((1.6, -0.3, 2.9)) @ R(math.radians(-12), 4, "X")
    box(trim, (2.4, 0.35, 4.8), shield_cf)
    box(gold, (2.6, 0.42, 0.35), shield_cf @ T((0, 0, 2.2)))
    box(gold, (2.6, 0.42, 0.35), shield_cf @ T((0, 0, -2.2)))
    uvsphere(gold, 0.45, shield_cf @ T((0, -0.2, 0)), 8, 6)
    # Pair of halberds racked on the outer posts.
    for sx in (-2.9, 2.9):
        box(wood, (0.24, 0.24, 8.4), T((sx, -0.2, 4.6)))
        box(metal, (1.2, 0.16, 1.8), T((sx + (0.45 if sx > 0 else -0.45), -0.2, 7.6)))


@template("CitadelDoors", STONE=3200, METAL=2600, TRIM=2400, GOLD=1600, GLOW=900)
def citadel_doors(t):
    """The monumental Ironflame Citadel keep facade (straight from the reference art): towering twin-turret dark
    basalt and iron fortress keep, crenellated upper crown, massive double riveted iron doors emblazoned with the
    giant embossed Sootwright Hammer-Ring sigil, glowing furnace slit seam, and flanking brazier pedestals."""
    stone, metal, trim, gold, glow = (t.bm(r) for r in ("STONE", "METAL", "TRIM", "GOLD", "GLOW"))
    w, h, d = 58.0, 68.0, 16.0
    # Broad stepped fortress plinth.
    box(stone, (w + 6.0, d + 4.0, 4.0), T((0, 0, 2.0)))
    # Twin flanking fortress buttress towers (left and right).
    for sx in (-1, 1):
        tx = sx * 24.5
        box(stone, (15.0, d + 2.0, h + 12.0), T((tx, 0, (h + 12.0) / 2)))
        for z in (12.0, 26.0, 42.0, 58.0, 74.0):
            box(trim, (15.8, d + 2.8, 1.2), T((tx, 0, z)))
        # Corner iron straps.
        for cx in (-1, 1):
            for cy in (-1, 1):
                box(trim, (1.6, 1.6, h + 10.0), T((tx + cx * 7.1, cy * (d / 2 + 0.6), (h + 10.0) / 2)))
        # Turret battlements and glowing brazier bowl on each crown.
        crenels(stone, tx - 6.0, tx + 6.0, -d / 2 - 0.6, h + 12.0, 2.8, 2.0, 3.6, 4)
        crenels(metal, tx - 6.0, tx + 6.0, -d / 2 - 0.6, h + 15.6, 3.1, 2.2, 0.5, 4)
        cone(trim, 2.4, 4.2, 2.8, 12, T((tx, 0, h + 12.2)))
        flame_plume(glow, (tx, 0, h + 15.0), 3.0, 8.5, tongues=5, seed=2420 + (1 if sx > 0 else 0))
    # Central recessed keep wall and upper crenellated crown.
    box(stone, (36.0, d, h), T((0, 0.5, h / 2)))
    box(trim, (38.0, d + 1.2, 2.4), T((0, 0, h - 1.2)))
    crenels(stone, -15.0, 15.0, -d / 2 + 0.4, h, 3.6, 2.4, 4.2, 6)
    crenels(metal, -15.0, 15.0, -d / 2 + 0.4, h + 4.2, 3.9, 2.6, 0.5, 6)
    # Massive stepped iron portal surround framing the monumental doors.
    for sx in (-1, 1):
        box(trim, (4.2, 4.0, 48.0), T((sx * 15.6, -d / 2 - 0.4, 24.0)))
    box(trim, (35.4, 4.4, 5.0), T((0, -d / 2 - 0.5, 49.5)))
    # Double riveted iron citadel doors with glowing centre seam.
    for sx in (-1, 1):
        box(metal, (13.2, 2.4, 46.0), T((sx * 6.9, -d / 2 + 0.4, 23.0)))
        for z in (10.0, 22.0, 34.0, 44.0):
            box(trim, (13.6, 2.8, 1.1), T((sx * 6.9, -d / 2 + 0.3, z)))
        # Vertical panel ribs.
        box(trim, (1.2, 2.7, 45.0), T((sx * 12.0, -d / 2 + 0.3, 23.0)))
    box(glow, (0.9, 1.0, 44.5), T((0, -d / 2 - 0.6, 23.0)))
    # Giant embossed Sootwright Hammer-Ring sigil across the centre of the doors!
    sig = T((0, -d / 2 - 1.4, 26.0)) @ R(math.pi / 2, 4, "X")
    gear_ring(gold, 9.6, 16, 1.8, sig)
    ring_mesh(trim, 7.6, 0.55, 24, sig, tube_segs=6)
    box(gold, (2.2, 11.2, 1.5), sig @ T((0, -1.8, 0)))
    box(gold, (8.6, 3.8, 1.8), sig @ T((0, 4.0, 0)))
    # Flanking threshold brazier pedestals (straight from the reference image!).
    for sx in (-1, 1):
        bx = sx * 16.5
        box(stone, (4.6, 4.6, 7.0), T((bx, -d / 2 - 3.6, 3.5)))
        cone(trim, 1.8, 3.2, 2.2, 12, T((bx, -d / 2 - 3.6, 7.0)))
        flame_plume(glow, (bx, -d / 2 - 3.6, 9.2), 2.2, 6.0, tongues=5, seed=2430 + (1 if sx > 0 else 0))


if __name__ == "__main__":
    kit, manifest = build_kit("InfernalF24Kit", F24_TEMPLATES, DEFAULT_BUDGET)
    export_kit(kit, manifest, OUT_DIR, "InfernalF24Kit")
    render_previews(kit, F24_TEMPLATES, OUT_DIR)
    print(json.dumps(manifest, indent=2))
