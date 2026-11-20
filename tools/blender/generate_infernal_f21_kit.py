"""
Infernal Foundry Floor 21 (Slagworks Entry) sculpted assets, generated in headless Blender.

Inspired by the Slagworks reference art: a rail yard round a great turntable, an ore crusher with twin
flywheels on its gantry, coal hoppers on trestles, a small tank locomotive and ore carts, a signal cabin,
the hammer-ring Furnace Gate, a water tower on iron legs, buffer stops, soot-brick flue stacks, scrap
heaps and coal heaps.

1 Blender unit = 1 stud, standing on z = 0, front facing -Y in Blender / +Z in Roblox,
one mesh object per colour role named "<Template>__<ROLE>".

Roles used (TowerBiomeAssets passes a Sootwright override for each):
    METAL  blackened iron          TRIM   dark iron trim, rails, railings
    STONE  soot brick / basalt     GOLD   brass fittings, the hammer-ring sigil
    WOOD   rail timber, planking   ALT    coal and ore
    ACCENT rust                    GLOW   furnace glow, lamps

Outputs (assets-source/tower/infernal_f21_kit/):
    InfernalF21Kit.blend    the generated scene
    InfernalF21Kit.fbx      FBX for File > Import 3D in Studio
    manifest.json           per template: roles, reference size, triangle counts
    previews/               Workbench contact-sheet render of the Floor 21 templates

Run:
    blender.exe --background --factory-startup --python tools/blender/generate_infernal_f21_kit.py
"""
import bpy, bmesh, math, os, json, runpy, random
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT_DIR = os.path.join(ROOT, "assets-source", "tower", "infernal_f21_kit")

kit_mod = runpy.run_path(os.path.join(HERE, "generate_tower_biome_kit.py"), init_globals={"RUN_KIT": False})

Template = kit_mod["Template"]
box = kit_mod["box"]
cone = kit_mod["cone"]
uvsphere = kit_mod["uvsphere"]
rock = kit_mod["rock"]
tube = kit_mod["tube"]
ring_mesh = kit_mod["ring_mesh"]
reset_scene = kit_mod["reset_scene"]
finalize = kit_mod["finalize"]

T = Matrix.Translation
R = Matrix.Rotation


def rock_clean(bm, size, mat, seed, roughness=0.22, subdiv=2, flat_bottom=True):
    tmp = bmesh.new()
    rock(tmp, size, mat, seed, roughness=roughness, subdiv=subdiv, flat_bottom=flat_bottom)
    vmap = [bm.verts.new(v.co) for v in tmp.verts]
    for f in tmp.faces:
        bm.faces.new([vmap[v.index] for v in f.verts])
    tmp.free()


def cyl_x(bm, r, length, centre, segs=16, r2=None):
    """A cylinder along X centred on centre."""
    c = Vector(centre)
    cone(bm, r, r if r2 is None else r2, length, segs, T((c.x - length / 2, c.y, c.z)) @ R(math.pi / 2, 4, "Y"))


def cyl_y(bm, r, length, centre, segs=16, r2=None):
    """A cylinder along Y centred on centre."""
    c = Vector(centre)
    cone(bm, r, r if r2 is None else r2, length, segs, T((c.x, c.y - length / 2, c.z)) @ R(-math.pi / 2, 4, "X"))


def cyl_z(bm, r, height, base, segs=16, r2=None):
    """A cylinder along Z standing on base."""
    cone(bm, r, r if r2 is None else r2, height, segs, T(base))


def strut(bm, p0, p1, thick):
    """A square beam from p0 to p1."""
    a, b = Vector(p0), Vector(p1)
    d = b - a
    length = d.length
    if length < 1e-4:
        return
    q = d.normalized().to_track_quat("Z", "Y")
    box(bm, (thick, thick, length), T((a + b) / 2) @ q.to_matrix().to_4x4())


def wheel_x(bm_disc, bm_rim, r, width, centre, spokes=0, bm_spoke=None):
    """A wheel turning about X: a thin disc with a rim ring and optional spokes."""
    c = Vector(centre)
    cyl_x(bm_disc, r * 0.92, width * 0.55, c, segs=20)
    rim = T(c) @ R(math.pi / 2, 4, "Y")
    ring_mesh(bm_rim, r, max(0.12, width * 0.35), 24, rim, tube_segs=6)
    cyl_x(bm_rim, r * 0.22, width * 1.2, c, segs=10)
    if spokes and bm_spoke is not None:
        for k in range(spokes):
            a = 2 * math.pi * k / spokes
            tip = c + Vector((0, math.cos(a) * r * 0.9, math.sin(a) * r * 0.9))
            strut(bm_spoke, c, tip, max(0.25, r * 0.09))


def gear_ring(bm, r, teeth, thick, mat):
    """A flat ring of gear teeth in the local XY plane (for the hammer-ring sigil)."""
    ring_mesh(bm, r, thick * 0.5, 32, mat, tube_segs=6)
    for k in range(teeth):
        a = 2 * math.pi * k / teeth
        box(bm, (thick * 1.2, thick * 1.6, thick * 0.9), mat @ T((math.cos(a) * (r + thick * 0.9), math.sin(a) * (r + thick * 0.9), 0)) @ R(a, 4, "Z"))


def railing(bm, x0, x1, y, z, posts):
    """A straight handrail along X with posts."""
    strut(bm, (x0, y, z + 3.2), (x1, y, z + 3.2), 0.28)
    strut(bm, (x0, y, z + 1.7), (x1, y, z + 1.7), 0.2)
    for k in range(posts + 1):
        x = x0 + (x1 - x0) * k / posts
        strut(bm, (x, y, z), (x, y, z + 3.3), 0.26)


DEFAULT_BUDGET = 3500
F21_TEMPLATES = {}


def template(name, **budget):
    def deco(fn):
        F21_TEMPLATES[name] = (fn, budget)
        return fn
    return deco


@template("OreCrusherJaw", METAL=3200, TRIM=2600, STONE=900, GOLD=600, ALT=1400, ACCENT=900, GLOW=200)
def ore_crusher_jaw(t):
    """The Ore Crusher: a riveted jaw-crusher housing between twin spoked flywheels, a feed hopper heaped with
    ore on top, a pitman arm and drive belt, a railed service walk and a discharge chute spilling ore."""
    metal, trim, stone, gold, alt, accent, glow = (t.bm(r) for r in ("METAL", "TRIM", "STONE", "GOLD", "ALT", "ACCENT", "GLOW"))
    # Bed frame and foundation plinth.
    box(stone, (26, 18, 2.4), T((0, 0, 0.8)))
    for sx in (-1, 1):
        box(metal, (2.2, 17, 3.0), T((sx * 11.5, 0, 3.4)))
    # Main housing: a tapered riveted box, deeper at the back.
    box(metal, (14, 13, 12), T((0, 1.0, 9.0)), bevel=0.35)
    box(accent, (14.4, 1.2, 9.5), T((0, -5.8, 8.6)))
    for row in range(3):
        for col in range(5):
            uvsphere(gold, 0.32, T((-5.6 + col * 2.8, -6.5, 5.4 + row * 3.2)), 6, 4)
    # Fixed jaw and the swing jaw plate showing in the front mouth.
    box(trim, (10, 1.4, 9), T((0, -7.2, 9.0)) @ R(math.radians(-14), 4, "X"))
    box(alt, (8.5, 2.2, 3.2), T((0, -8.4, 4.0)))
    # Twin flywheels with six spokes, axle through the housing.
    for sx in (-1, 1):
        wheel_x(metal, trim, 8.4, 1.6, (sx * 9.6, 2.0, 12.0), spokes=6, bm_spoke=trim)
        box(metal, (1.8, 3.4, 9.6), T((sx * 8.0, 2.0, 7.0)))
    cyl_x(trim, 0.9, 22.5, (0, 2.0, 12.0), segs=10)
    # Pitman arm and eccentric up the back.
    strut(trim, (0, 7.5, 6.5), (0, 3.5, 13.5), 1.6)
    cyl_x(gold, 1.6, 3.0, (0, 3.5, 13.5), segs=12)
    # Drive belt to a motor housing at the back.
    box(metal, (5, 5, 5), T((-8.5, 8.0, 4.8)))
    strut(stone, (-9.6, 2.0, 12.0), (-9.6, 8.0, 5.4), 0.5)
    # Feed hopper: an inverted pyramid frustum heaped with ore.
    cone(metal, 4.0, 9.0, 7.5, 4, T((0, 0.5, 15.0)) @ R(math.pi / 4, 4, "Z"))
    box(trim, (13.2, 13.2, 0.8), T((0, 0.5, 22.6)) @ R(0, 4, "Z"))
    rock_clean(alt, (10.0, 10.0, 4.5), T((0, 0.5, 21.0)), seed=211, roughness=0.32, subdiv=2)
    # Railed service walk round the hopper on three sides, with a ladder down the side.
    box(trim, (20, 2.2, 0.4), T((0, 7.8, 15.0)))
    railing(trim, -10, 10, 8.8, 15.2, 5)
    for sx in (-1, 1):
        box(trim, (2.2, 16, 0.4), T((sx * 10.6, 0.5, 15.0)))
        strut(trim, (sx * 11.6, -7.5, 18.4), (sx * 11.6, 8.8, 18.4), 0.28)
        for k in range(4):
            strut(trim, (sx * 11.6, -7.5 + k * 5.4, 15.2), (sx * 11.6, -7.5 + k * 5.4, 18.5), 0.26)
    for k in range(8):
        strut(trim, (-12.4, -2.5, 1.5 + k * 1.8), (-12.4, -0.5, 1.5 + k * 1.8), 0.2)
    for sy in (-2.5, -0.5):
        strut(trim, (-12.4, sy, 0.0), (-12.4, sy, 15.0), 0.26)
    # Discharge chute under the mouth spilling crushed ore forward.
    box(metal, (7, 7, 1.0), T((0, -10.0, 3.0)) @ R(math.radians(28), 4, "X"))
    rock_clean(alt, (9.0, 7.0, 2.6), T((0, -12.0, 0.0)), seed=212, roughness=0.35, subdiv=2)
    # A warm glow inside the motor housing grille.
    box(glow, (3.2, 0.3, 1.6), T((-8.5, 5.4, 5.6)))


@template("CoalHopper", METAL=2600, TRIM=2400, WOOD=900, ALT=1600, ACCENT=500)
def coal_hopper(t):
    """A row of three coal hoppers on a braced iron trestle: inverted-pyramid bins brimming with coal, discharge
    gates over the rails, a plank walkway along the top."""
    metal, trim, wood, alt, accent = (t.bm(r) for r in ("METAL", "TRIM", "WOOD", "ALT", "ACCENT"))
    width, depth, top = 36.0, 12.0, 18.0
    # Trestle legs and bracing.
    legs = [(-17, -5), (-17, 5), (-5.7, -5), (-5.7, 5), (5.7, -5), (5.7, 5), (17, -5), (17, 5)]
    for (x, y) in legs:
        box(trim, (1.4, 1.4, top), T((x, y, top / 2)))
        box(metal, (2.6, 2.6, 0.8), T((x, y, 0.4)))
    for y in (-5, 5):
        for k in range(3):
            x0, x1 = legs[k * 2][0], legs[k * 2 + 2][0]
            strut(trim, (x0, y, 1.5), (x1, y, top - 6.5), 0.6)
            strut(trim, (x1, y, 1.5), (x0, y, top - 6.5), 0.6)
        strut(trim, (-17, y, top - 6.0), (17, y, top - 6.0), 0.9)
    for x in (-17, -5.7, 5.7, 17):
        strut(trim, (x, -5, 2.0), (x, 5, top - 7.0), 0.5)
    # Three bins: inverted pyramid frusta with a vertical collar, heaped with coal.
    for k, x in enumerate((-11.4, 0.0, 11.4)):
        cone(metal, 2.0, 7.6, 7.0, 4, T((x, 0, top - 7.0)) @ R(math.pi / 4, 4, "Z"))
        box(metal, (10.8, 10.8, 3.6), T((x, 0, top + 1.8)))
        box(accent, (11.0, 11.0, 0.6), T((x, 0, top + 0.2)))
        rock_clean(alt, (9.6, 9.6, 3.4 + (k % 2) * 0.8), T((x, 0, top + 2.6)), seed=231 + k, roughness=0.36, subdiv=2)
        box(trim, (3.0, 3.0, 1.6), T((x, 0, top - 7.6)))
        box(metal, (3.4, 0.4, 2.4), T((x, -1.8, top - 8.4)) @ R(math.radians(30), 4, "X"))
    # Plank walkway along the back with a handrail.
    box(wood, (width, 2.4, 0.5), T((0, 6.8, top + 0.2)))
    railing(trim, -18, 18, 7.8, top + 0.4, 6)


@template("OreCart", METAL=1100, TRIM=900, ALT=900, ACCENT=300)
def ore_cart(t):
    """A riveted side-tipping ore tub on a four-wheeled bogie, heaped with ore; couplers at both ends."""
    metal, trim, alt, accent = (t.bm(r) for r in ("METAL", "TRIM", "ALT", "ACCENT"))
    # Bogie frame and wheels (axles along X, track gauge ~5).
    box(trim, (4.4, 8.4, 0.8), T((0, 0, 1.7)))
    for y in (-2.6, 2.6):
        for sx in (-1, 1):
            cyl_x(trim, 1.15, 0.5, (sx * 2.5, y, 1.15), segs=12)
        cyl_x(trim, 0.25, 5.4, (0, y, 1.15), segs=6)
    # The tub: a flared box.
    cone(metal, 3.4, 4.2, 3.0, 4, T((0, 0, 2.1)) @ R(math.pi / 4, 4, "Z") @ Matrix.Diagonal((0.72, 1.32, 1, 1)))
    for sx in (-1, 1):
        box(accent, (0.4, 9.2, 0.5), T((sx * 2.6, 0, 5.0)))
    for sy in (-1, 1):
        box(accent, (5.6, 0.4, 0.5), T((0, sy * 4.4, 5.0)))
    rock_clean(alt, (4.4, 8.0, 2.4), T((0, 0, 4.4)), seed=251, roughness=0.34, subdiv=2)
    for y in (-4.6, 4.6):
        box(trim, (1.2, 0.8, 0.6), T((0, y, 1.8)))


@template("TankLocomotive", METAL=3200, TRIM=2400, GOLD=500, WOOD=300, GLOW=200, ACCENT=500)
def tank_locomotive(t):
    """A squat 0-4-0 saddle-tank shunting locomotive: riveted boiler and saddle tank, tall chimney, steam dome,
    cab with spectacle windows and a coal bunker, cowcatcher, buffers and six spoked wheels."""
    metal, trim, gold, wood, glow, accent = (t.bm(r) for r in ("METAL", "TRIM", "GOLD", "WOOD", "GLOW", "ACCENT"))
    # Frame and wheels (track gauge ~5, length along Y; the smokebox faces -Y, the front).
    box(trim, (4.6, 17, 1.2), T((0, 0, 2.3)))
    for y in (-5.2, -0.6, 4.0):
        for sx in (-1, 1):
            wheel_x(trim, metal, 1.9, 0.6, (sx * 2.5, y, 1.9), spokes=8, bm_spoke=trim)
    strut(gold, (2.9, -5.2, 1.9), (2.9, 4.0, 1.9), 0.35)
    strut(gold, (-2.9, -5.2, 1.9), (-2.9, 4.0, 1.9), 0.35)
    # Boiler along Y with a saddle tank over it, smokebox at the front.
    cyl_y(metal, 2.3, 10.5, (0, -2.6, 5.4), segs=18)
    cyl_y(trim, 2.45, 1.6, (0, -7.6, 5.4), segs=18)
    cyl_y(trim, 1.6, 0.4, (0, -8.5, 5.4), segs=16)
    box(metal, (6.0, 8.4, 3.6), T((0, -1.8, 6.2)), bevel=0.6, segs=2)
    for y in (-5.4, -2.0, 1.6):
        box(gold, (6.2, 0.35, 0.35), T((0, y, 7.6)))
    # Chimney, steam dome and safety valves.
    cone(trim, 0.9, 1.3, 4.2, 12, T((0, -6.6, 7.4)))
    cyl_z(trim, 1.45, 0.6, (0, -6.6, 11.4), segs=12)
    uvsphere(gold, 1.1, T((0, -3.0, 8.6)), 10, 6)
    cyl_z(gold, 0.35, 1.4, (0.6, 0.6, 8.0), segs=6)
    # Cab with windows, roof, and the coal bunker behind.
    box(metal, (6.2, 4.6, 6.4), T((0, 4.4, 6.1)))
    for sx in (-1, 1):
        box(glow, (0.2, 1.6, 1.4), T((sx * 3.12, 4.4, 7.4)))
    for sx in (-1, 1):
        box(gold, (0.9, 0.2, 0.9), T((sx * 1.6, 2.06, 8.0)))
    box(trim, (7.0, 5.6, 0.5), T((0, 4.4, 9.55)), bevel=0.15)
    box(metal, (5.4, 2.6, 3.0), T((0, 7.6, 4.4)))
    rock_clean(wood, (4.6, 2.2, 1.4), T((0, 7.6, 5.8)), seed=271, roughness=0.3, subdiv=1)
    # Buffers and cowcatcher.
    for y in (-8.7, 8.7):
        box(accent, (5.6, 0.6, 1.2), T((0, y, 2.4)))
        for sx in (-1, 1):
            cyl_y(trim, 0.5, 1.2, (sx * 1.9, y - 0.6 * (1 if y < 0 else -1), 2.4), segs=8)
    for k in range(5):
        strut(trim, (-2.4 + k * 1.2, -9.1, 2.0), (-1.8 + k * 0.9, -10.6, 0.4), 0.25)


@template("SignalCabin", METAL=1400, WOOD=1100, TRIM=800, STONE=500, GLOW=200, ACCENT=300)
def signal_cabin(t):
    """A small corrugated-iron signal cabin on a brick footing: pitched roof, stovepipe, a lit window, a door and
    a lever frame showing through the window, with oil drums by the door."""
    metal, wood, trim, stone, glow, accent = (t.bm(r) for r in ("METAL", "WOOD", "TRIM", "STONE", "GLOW", "ACCENT"))
    box(stone, (9.4, 8.4, 1.2), T((0, 0, 0.3)))
    box(metal, (8.6, 7.6, 7.0), T((0, 0, 4.4)))
    # Corrugation ridges down the front and sides.
    for k in range(9):
        box(metal, (0.25, 0.2, 7.0), T((-4.0 + k * 1.0, -3.85, 4.4)))
    for sx in (-1, 1):
        box(trim, (0.4, 7.8, 0.5), T((sx * 4.4, 0, 7.8)))
    # Pitched roof.
    for side in (-1, 1):
        box(metal, (10.0, 5.0, 0.4), T((0, side * 2.0, 9.0)) @ R(-side * math.radians(24), 4, "X"))
    box(trim, (10.2, 0.5, 0.5), T((0, 0, 10.0)))
    cyl_z(trim, 0.35, 3.0, (2.6, 1.8, 9.2), segs=8)
    # Door, lit window and the lever frame behind it.
    box(wood, (2.4, 0.3, 5.2), T((-2.2, -3.95, 3.5)))
    box(glow, (3.0, 0.2, 2.0), T((1.8, -3.92, 5.4)))
    box(trim, (3.4, 0.3, 0.3), T((1.8, -4.0, 6.5)))
    box(trim, (3.4, 0.3, 0.3), T((1.8, -4.0, 4.3)))
    for k in range(4):
        strut(accent, (0.8 + k * 0.7, -3.4, 3.6), (0.9 + k * 0.7, -3.6, 5.6), 0.18)
    for k, (x, y) in enumerate(((-5.4, -2.4), (-5.6, -0.4), (-4.4, -4.6))):
        cyl_z(accent if k % 2 == 0 else metal, 0.95, 2.6, (x, y, 0), segs=10)


@template("FurnaceGateDoors", STONE=2600, METAL=2200, TRIM=1600, GOLD=1500, GLOW=600, ACCENT=500)
def furnace_gate_doors(t):
    """The Furnace Gate: towering riveted iron double doors under a stepped soot-brick arch, the Sootwright
    hammer-ring sigil (a hammer inside a ring of gear teeth) raised in brass across both leaves, flanking
    buttresses with brazier niches and a lintel of iron bands."""
    stone, metal, trim, gold, glow, accent = (t.bm(r) for r in ("STONE", "METAL", "TRIM", "GOLD", "GLOW", "ACCENT"))
    w, h, d = 46.0, 44.0, 8.0
    # Brick frame: two buttress towers and a stepped lintel block.
    for sx in (-1, 1):
        box(stone, (10, d + 2, h), T((sx * (w / 2 - 5), 0.6, h / 2)))
        box(stone, (12, d + 4, 3), T((sx * (w / 2 - 5), 0.6, 1.5)))
        box(stone, (11, d + 3, 2.4), T((sx * (w / 2 - 5), 0.6, h + 1.2)))
        # Brazier niche with a glow.
        box(trim, (5, 1.0, 6), T((sx * (w / 2 - 5), -d / 2 - 0.8, 10)))
        box(glow, (3.6, 0.6, 2.6), T((sx * (w / 2 - 5), -d / 2 - 1.1, 9.2)))
        for k in range(4):
            box(trim, (10.4, d + 2.4, 0.6), T((sx * (w / 2 - 5), 0.6, 6 + k * 10)))
    box(stone, (w - 20, d, 10), T((0, 0.6, h - 5)))
    box(stone, (w - 16, d + 1.5, 3), T((0, 0.6, h - 0.5)))
    for k in range(5):
        box(trim, (w - 19.6, d + 0.4, 0.5), T((0, 0.6, h - 9 + k * 2.0)))
    # The two door leaves, slightly ajar, with riveted straps.
    door_h = h - 10
    for sx in (-1, 1):
        cx = sx * 6.6
        box(metal, (13, 1.6, door_h), T((cx, -1.0, door_h / 2)) @ R(sx * math.radians(-2.5), 4, "Z"))
        for k in range(6):
            z = 3 + k * (door_h - 6) / 5
            box(trim, (13.4, 2.0, 0.9), T((cx, -1.2, z)))
            for j in range(5):
                uvsphere(gold, 0.3, T((cx - 5.2 + j * 2.6, -2.3, z)), 6, 4)
        box(accent, (0.8, 2.2, door_h), T((cx + sx * 6.2, -1.1, door_h / 2)))
    # Hammer-ring sigil across both leaves: a gear ring with a hammer inside.
    sig = T((0, -2.6, door_h * 0.55)) @ R(math.pi / 2, 4, "X")
    gear_ring(gold, 7.0, 16, 1.4, sig)
    box(gold, (1.6, 9.0, 1.0), sig @ T((0, -1.6, 0)))
    box(gold, (7.2, 3.2, 1.4), sig @ T((0, 3.6, 0)))
    # Threshold step and kick plate.
    box(trim, (w - 18, 3.0, 1.0), T((0, -3.0, 0.5)))


@template("WaterTower", METAL=2200, TRIM=2200, WOOD=1200, ACCENT=500)
def water_tower(t):
    """A locomotive water tower: a riveted iron tank with a conical roof on four braced iron legs, a ladder up
    one leg, and a swinging spout with its counterweight chain."""
    metal, trim, wood, accent = (t.bm(r) for r in ("METAL", "TRIM", "WOOD", "ACCENT"))
    leg_h, r = 20.0, 6.4
    corners = [(-5, -5), (-5, 5), (5, -5), (5, 5)]
    for (x, y) in corners:
        strut(trim, (x * 1.15, y * 1.15, 0), (x, y, leg_h), 1.2)
        box(metal, (2.6, 2.6, 0.8), T((x * 1.15, y * 1.15, 0.4)))
    for k in range(2):
        z0, z1 = 1.0 + k * (leg_h / 2), (k + 1) * (leg_h / 2) - 0.5
        for (a, b) in ((0, 2), (1, 3), (0, 1), (2, 3)):
            pa, pb = corners[a], corners[b]
            strut(trim, (pa[0], pa[1], z0), (pb[0], pb[1], z1), 0.45)
            strut(trim, (pb[0], pb[1], z0), (pa[0], pa[1], z1), 0.45)
    box(wood, (13, 13, 0.6), T((0, 0, leg_h + 0.3)))
    cyl_z(metal, r, 9.0, (0, 0, leg_h + 0.6), segs=22)
    for k in range(4):
        ring_mesh(accent, r + 0.08, 0.18, 26, T((0, 0, leg_h + 1.6 + k * 2.2)), tube_segs=5)
    cone(metal, r + 0.6, 0.6, 4.4, 22, T((0, 0, leg_h + 9.6)))
    # Spout and counterweight.
    strut(trim, (0, -r, leg_h + 2.0), (0, -r - 5.5, leg_h - 1.0), 1.0)
    strut(trim, (0, -r - 5.5, leg_h - 1.0), (0, -r - 5.5, leg_h - 4.0), 0.25)
    box(metal, (1.2, 1.2, 1.6), T((0, -r - 5.5, leg_h - 4.8)))
    # Ladder up the front-left leg.
    for sy in (-0.6, 0.6):
        strut(trim, (-6.4, -6.4 + sy, 0), (-5.4, -5.4 + sy, leg_h), 0.22)
    for k in range(12):
        z = 1.2 + k * 1.6
        f = z / leg_h
        x = -6.4 + f
        strut(trim, (x, x - 0.6, z), (x, x + 0.6, z), 0.18)


@template("RailBuffer", METAL=900, TRIM=700, WOOD=500, ACCENT=300)
def rail_buffer(t):
    """A buffer stop at a spur's end: an iron frame braced back to the rails, a timber beam faced with two
    sprung buffers, and a red lamp board."""
    metal, trim, wood, accent = (t.bm(r) for r in ("METAL", "TRIM", "WOOD", "ACCENT"))
    for sx in (-1, 1):
        strut(trim, (sx * 2.6, 2.5, 0.3), (sx * 2.6, -0.6, 3.2), 0.6)
        strut(trim, (sx * 2.6, 2.5, 0.3), (sx * 2.6, -1.2, 0.3), 0.5)
        strut(trim, (sx * 2.6, -0.8, 0.3), (sx * 2.6, -0.8, 3.4), 0.55)
    box(wood, (7.0, 1.2, 1.6), T((0, -1.2, 2.8)))
    for sx in (-1, 1):
        cyl_y(metal, 0.55, 1.4, (sx * 2.0, -2.4, 2.8), segs=10)
        cyl_y(metal, 0.85, 0.25, (sx * 2.0, -3.1, 2.8), segs=12)
    box(accent, (1.6, 0.25, 1.6), T((0, -1.9, 4.4)))
    strut(trim, (0, -1.4, 3.6), (0, -1.4, 5.4), 0.2)


@template("FlueStack", STONE=2200, METAL=1200, TRIM=900, GLOW=200)
def flue_stack(t):
    """A towering Sootwright flue stack: a tapering soot-brick chimney on a square plinth, banded with iron
    rings, a corbelled crown and an iron cap, a ladder of rungs up one face, the flue mouth glowing."""
    stone, metal, trim, glow = (t.bm(r) for r in ("STONE", "METAL", "TRIM", "GLOW"))
    h = 96.0
    box(stone, (14, 14, 10), T((0, 0, 5)))
    box(trim, (14.6, 14.6, 1.0), T((0, 0, 10.2)))
    cone(stone, 5.6, 3.6, h - 10, 18, T((0, 0, 10.4)))
    for k in range(7):
        z = 18 + k * 11.5
        rr = 5.6 - (5.6 - 3.6) * (z - 10.4) / (h - 10)
        ring_mesh(metal, rr + 0.12, 0.35, 24, T((0, 0, z)), tube_segs=5)
    cone(stone, 3.9, 4.7, 3.0, 18, T((0, 0, h)))
    cone(metal, 4.8, 4.2, 1.4, 18, T((0, 0, h + 3.0)))
    cyl_z(glow, 3.2, 0.4, (0, 0, h + 3.6), segs=14)
    # A ladder of iron rungs up the front face.
    for k in range(40):
        z = 12 + k * 2.1
        rr = 5.6 - (5.6 - 3.6) * (z - 10.4) / (h - 10)
        strut(trim, (-0.7, -rr - 0.35, z), (0.7, -rr - 0.35, z), 0.16)
    # Flue duct entering the plinth.
    box(metal, (5, 6, 5), T((0, -9.0, 3.2)))


@template("ScrapHeap", METAL=1600, TRIM=1400, ACCENT=1000, STONE=500)
def scrap_heap(t):
    """A heap of foundry scrap: bent plates, broken girders, a cracked gear wheel, pipe offcuts and rivet-pocked
    slabs piled on a bed of clinker."""
    metal, trim, accent, stone = (t.bm(r) for r in ("METAL", "TRIM", "ACCENT", "STONE"))
    rng = random.Random(281)
    rock_clean(stone, (15, 12, 2.8), T((0, 0, -0.6)), seed=281, roughness=0.3, subdiv=2)
    for k in range(14):
        x, y = rng.uniform(-5.5, 5.5), rng.uniform(-4.2, 4.2)
        z = 1.0 + rng.uniform(0, 2.4) * (1 - (abs(x) / 7 + abs(y) / 6) * 0.5)
        size = (rng.uniform(2.2, 4.6), rng.uniform(1.6, 3.4), 0.28)
        rot = R(rng.uniform(-0.7, 0.7), 4, "X") @ R(rng.uniform(-0.7, 0.7), 4, "Y") @ R(rng.uniform(0, math.pi), 4, "Z")
        box(metal if k % 3 else accent, size, T((x, y, z)) @ rot)
    for k in range(4):
        x, y = rng.uniform(-4, 4), rng.uniform(-3, 3)
        strut(trim, (x - 3, y, 0.6 + k * 0.5), (x + 3, y + rng.uniform(-2, 2), 1.4 + k * 0.6), 0.7)
    gear = T((2.2, -1.2, 2.4)) @ R(math.radians(62), 4, "X") @ R(0.3, 4, "Y")
    ring_mesh(accent, 2.4, 0.4, 20, gear, tube_segs=5)
    for k in range(10):
        a = 2 * math.pi * k / 10
        box(accent, (0.6, 0.9, 0.5), gear @ T((math.cos(a) * 2.9, math.sin(a) * 2.9, 0)) @ R(a, 4, "Z"))
    cyl_x(trim, 0.8, 5.0, (-3.0, 2.2, 1.2), segs=10)


@template("CoalHeap", ALT=1500, STONE=600)
def coal_heap(t):
    """Ground cover: a low heap of coal or ore lumps in two or three mounds with loose lumps at the foot."""
    alt, stone = t.bm("ALT"), t.bm("STONE")
    rock_clean(alt, (9.0, 7.0, 3.2), T((0, 0, 0)), seed=291, roughness=0.42, subdiv=2)
    rock_clean(alt, (5.2, 4.4, 2.2), T((3.8, 2.0, 0)), seed=292, roughness=0.42, subdiv=2)
    rock_clean(alt, (4.4, 3.8, 1.8), T((-3.6, -2.2, 0)), seed=293, roughness=0.42, subdiv=2)
    rng = random.Random(294)
    for k in range(9):
        a = rng.uniform(0, 2 * math.pi)
        d = rng.uniform(4.2, 5.6)
        rock_clean(stone if k % 3 == 0 else alt, (rng.uniform(0.7, 1.3),) * 3, T((math.cos(a) * d, math.sin(a) * d * 0.8, -0.1)), seed=295 + k, roughness=0.3, subdiv=1)


@template("SignalLamp", METAL=700, TRIM=600, GLOW=200, GOLD=200)
def signal_lamp(t):
    """A yard signal: an iron post on a cast base with a semaphore arm and a glowing lamp housing."""
    metal, trim, glow, gold = (t.bm(r) for r in ("METAL", "TRIM", "GLOW", "GOLD"))
    box(metal, (1.8, 1.8, 0.8), T((0, 0, 0.4)))
    cyl_z(trim, 0.28, 9.0, (0, 0, 0.8), segs=8)
    box(metal, (1.4, 1.2, 1.6), T((0, -0.4, 8.2)))
    box(glow, (0.9, 0.2, 0.9), T((0, -1.05, 8.2)))
    box(gold, (0.5, 0.5, 0.4), T((0, -0.4, 9.2)))
    box(trim, (3.6, 0.3, 0.6), T((1.6, -0.2, 7.0)) @ R(math.radians(-18), 4, "Y"))
    for k in range(5):
        strut(trim, (-0.35, 0.3, 1.0 + k * 1.4), (0.35, 0.3, 1.0 + k * 1.4), 0.12)


def build_kit(kit_name, templates, default_budget):
    """Builds every template into its own collection under kit_name; returns the kit and its manifest."""
    reset_scene()
    kit = bpy.data.collections.new(kit_name)
    bpy.context.scene.collection.children.link(kit)
    manifest = {}
    for name, (fn, budget) in templates.items():
        coll = bpy.data.collections.new(name)
        kit.children.link(coll)
        t = Template(name)
        fn(t)
        roles = {}
        lo = Vector((1e9, 1e9, 1e9))
        hi = Vector((-1e9, -1e9, -1e9))
        for role, bm in t.meshes.items():
            if len(bm.verts) == 0:
                bm.free()
                continue
            obj, tris = finalize(name, role, bm, budget.get(role, default_budget), coll)
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


def export_kit(kit, manifest, out_dir, base):
    """Writes <base>.fbx (for File > Import 3D), manifest.json and <base>.blend into out_dir."""
    os.makedirs(out_dir, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    objs = [o for o in kit.all_objects if o.type == "MESH"]
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.fbx(
        filepath=os.path.join(out_dir, base + ".fbx"),
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
    with open(os.path.join(out_dir, "manifest.json"), "w") as f:
        json.dump({"Templates": manifest, "Unit": "studs", "Front": "-Y in Blender, +Z in Roblox"}, f, indent=2, sort_keys=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out_dir, base + ".blend"))


def render_previews(kit, templates, out_dir):
    """Workbench renders of every template, tiled six to a row into previews/kit_sheet_1.png."""
    preview_dir = os.path.join(out_dir, "previews")
    tiles = os.path.join(preview_dir, "tiles")
    os.makedirs(tiles, exist_ok=True)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.color_type = "MATERIAL"
    stage = bpy.data.collections.new("PreviewStage")
    scene.collection.children.link(stage)
    cam = bpy.data.objects.new("PreviewCam", bpy.data.cameras.new("PreviewCam"))
    stage.objects.link(cam)
    scene.camera = cam
    scene.render.resolution_x = scene.render.resolution_y = 320
    for o in kit.all_objects:
        o.hide_render = True
    tile_imgs = []
    for n in templates:
        c = bpy.data.collections[n]
        lo = Vector((1e9,) * 3)
        hi = Vector((-1e9,) * 3)
        for o in c.objects:
            o.hide_render = False
            for v in o.data.vertices:
                lo = Vector(map(min, lo, v.co))
                hi = Vector(map(max, hi, v.co))
        size = max(hi - lo)
        ctr = (lo + hi) / 2
        cam.location = ctr + Vector((0.55, -1.0, 0.42)).normalized() * size * 1.9
        cam.rotation_euler = (ctr - cam.location).to_track_quat("-Z", "Y").to_euler()
        p_path = os.path.join(tiles, n + ".png")
        scene.render.filepath = p_path
        bpy.ops.render.render(write_still=True)
        for o in c.objects:
            o.hide_render = True
        tile_imgs.append(bpy.data.images.load(p_path))
    import numpy as np
    cols = 6
    rows = (len(tile_imgs) + cols - 1) // cols
    sheet = bpy.data.images.new("PreviewSheet", width=320 * cols, height=320 * rows, alpha=True)
    buf = np.zeros((320 * rows, 320 * cols, 4), dtype=np.float32)
    for idx, img in enumerate(tile_imgs):
        arr = np.asarray(img.pixels[:], dtype=np.float32).reshape(320, 320, 4)
        r, c = idx // cols, idx % cols
        y0 = (rows - 1 - r) * 320
        buf[y0:y0 + 320, c * 320:(c + 1) * 320, :] = arr
        bpy.data.images.remove(img)
    sheet.pixels.foreach_set(buf.ravel())
    sheet.filepath_raw = os.path.join(preview_dir, "kit_sheet_1.png")
    sheet.file_format = "PNG"
    sheet.save()
    bpy.data.images.remove(sheet)


if __name__ == "__main__":
    kit, manifest = build_kit("InfernalF21Kit", F21_TEMPLATES, DEFAULT_BUDGET)
    export_kit(kit, manifest, OUT_DIR, "InfernalF21Kit")
    render_previews(kit, F21_TEMPLATES, OUT_DIR)
    print(json.dumps(manifest, indent=2))
