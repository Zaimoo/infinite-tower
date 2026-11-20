"""
Infernal Foundry Floor 22 (Molten Assembly) sculpted assets, generated in headless Blender.

Inspired by the assembly-hall reference art: a gantry crane over a hall of half-built Forge Constructs in
scaffolds, chain hoists and a crane trolley, steaming quench tanks, brick furnaces venting steam, a glazed
control cab, wooden foundry patterns, wall-mounted gears, roller conveyors, parts racks and the failed
hydraulic jack under the girder's east end.

1 Blender unit = 1 stud, standing on z = 0, front facing -Y in Blender / +Z in Roblox, one mesh object per colour
role named "<Template>__<ROLE>". Hanging pieces (ChainHoist) stand on their hook's tip, so they still sit on
their origin; TowerSetPieces hangs them from the overhead crane.

Roles (TowerSetPieces passes a Sootwright override): METAL iron, TRIM dark iron, STONE soot brick, GOLD brass,
WOOD timber and patterns, ACCENT rust, GLOW furnace light, CRYSTAL glass or quench water.

Outputs (assets-source/tower/infernal_f22_kit/): InfernalF22Kit.blend, InfernalF22Kit.fbx, manifest.json,
previews/kit_sheet_1.png.

Run:
    blender.exe --background --factory-startup --python tools/blender/generate_infernal_f22_kit.py
"""
import bpy, bmesh, math, os, json, runpy, random
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT_DIR = os.path.join(ROOT, "assets-source", "tower", "infernal_f22_kit")

# Shared primitives and the Floor 21 helpers (cylinders, struts, wheels, railings, the hammer-ring).
f21 = runpy.run_path(os.path.join(HERE, "generate_infernal_f21_kit.py"))
Template = f21["Template"]
box, cone, uvsphere, tube, ring_mesh = f21["box"], f21["cone"], f21["uvsphere"], f21["tube"], f21["ring_mesh"]
reset_scene, finalize = f21["reset_scene"], f21["finalize"]
rock_clean, cyl_x, cyl_y, cyl_z = f21["rock_clean"], f21["cyl_x"], f21["cyl_y"], f21["cyl_z"]
strut, wheel_x, gear_ring, railing = f21["strut"], f21["wheel_x"], f21["gear_ring"], f21["railing"]
build_kit, export_kit, render_previews = f21["build_kit"], f21["export_kit"], f21["render_previews"]
T = Matrix.Translation
R = Matrix.Rotation

DEFAULT_BUDGET = 3500
F22_TEMPLATES = {}


def template(name, **budget):
    def deco(fn):
        F22_TEMPLATES[name] = (fn, budget)
        return fn
    return deco


def chain(bm, p0, p1, link=0.9):
    """A hanging chain of alternating flat links from p0 to p1."""
    a, b = Vector(p0), Vector(p1)
    n = max(2, int((b - a).length / link))
    d = (b - a).normalized()
    q = d.to_track_quat("Z", "Y").to_matrix().to_4x4()
    for k in range(n):
        at = a + (b - a) * ((k + 0.5) / n)
        box(bm, (0.5 if k % 2 == 0 else 0.18, 0.18 if k % 2 == 0 else 0.5, link * 1.05), T(at) @ q)


@template("ConstructShell", METAL=3200, TRIM=2600, GOLD=500, GLOW=300, ACCENT=800)
def construct_shell(t):
    """A half-built Forge Construct standing at attention: a barrel chest with a furnace core showing through
    open plating, pauldrons, a riveted helm with a visor slit, a hammer arm and a bare-frame left arm, plated legs
    on broad feet. Some plates are missing, showing the iron skeleton beneath."""
    metal, trim, gold, glow, accent = (t.bm(r) for r in ("METAL", "TRIM", "GOLD", "GLOW", "ACCENT"))
    # Feet and legs.
    for sx in (-1, 1):
        box(metal, (2.6, 3.8, 1.2), T((sx * 1.8, -0.4, 0.6)), bevel=0.2)
        cyl_z(trim, 0.7, 6.4, (sx * 1.8, 0, 1.2), segs=10)
        box(metal, (2.0, 2.2, 3.6), T((sx * 1.8, -0.2, 3.6)), bevel=0.2)
        uvsphere(trim, 1.0, T((sx * 1.8, 0, 7.6)), 10, 6)
        box(metal if sx < 0 else accent, (2.2, 2.4, 4.0), T((sx * 1.8, 0, 9.8)), bevel=0.2)
    # Pelvis and spine.
    box(metal, (5.0, 3.0, 1.8), T((0, 0, 12.4)), bevel=0.3)
    cyl_z(trim, 0.8, 2.6, (0, 0, 13.2), segs=10)
    # Barrel chest: a riveted drum with the furnace core behind a grate.
    cyl_z(metal, 3.4, 6.2, (0, 0.2, 15.4), segs=16)
    box(trim, (4.6, 0.6, 3.4), T((0, -3.3, 18.2)))
    box(glow, (3.6, 0.3, 2.6), T((0, -3.15, 18.2)))
    for k in range(4):
        box(trim, (0.3, 0.7, 2.8), T((-1.4 + k * 0.95, -3.55, 18.2)))
    for k in range(8):
        a = 2 * math.pi * k / 8
        uvsphere(gold, 0.25, T((math.cos(a) * 3.45, 0.2 + math.sin(a) * 3.45, 20.9)), 6, 4)
    # Pauldrons, helm.
    for sx in (-1, 1):
        uvsphere(metal, 2.0, T((sx * 4.2, 0, 21.0)) @ Matrix.Diagonal((1, 1.1, 0.8, 1)), 12, 8)
    box(metal, (2.8, 3.0, 3.0), T((0, 0, 23.4)), bevel=0.5, segs=2)
    box(glow, (2.0, 0.2, 0.4), T((0, -1.6, 23.8)))
    box(gold, (0.4, 3.2, 0.5), T((0, 0, 25.0)))
    # Right arm: the hammer arm, held down at its side.
    cyl_z(trim, 0.6, 5.0, (5.0, 0, 15.2), segs=8)
    box(metal, (2.2, 2.4, 4.0), T((5.2, 0, 13.0)), bevel=0.2)
    box(metal, (4.6, 3.6, 3.0), T((5.4, -0.2, 9.6)), bevel=0.3)
    box(accent, (1.2, 1.2, 3.0), T((5.4, -0.2, 11.6)))
    # Left arm: bare frame, no plates yet.
    strut(trim, (-4.6, 0, 20.0), (-5.6, 0, 14.6), 0.8)
    strut(trim, (-5.6, 0, 14.6), (-5.4, -1.0, 10.4), 0.7)
    uvsphere(trim, 0.8, T((-5.6, 0, 14.6)), 8, 5)
    for k in range(3):
        box(trim, (1.8, 0.3, 0.3), T((-5.4, -0.9, 10.2 - k * 0.5)))
    # A missing plate on the right flank shows the ribs.
    for k in range(3):
        box(trim, (0.3, 3.0, 0.4), T((3.3, 0.2, 14.4 + k * 1.2)))


@template("AssemblyScaffold", TRIM=3200, WOOD=1600, METAL=600)
def assembly_scaffold(t):
    """A scaffold tower round an open bay (a construct stands inside): iron poles, ledgers at four lifts, diagonal
    braces on the back and sides, plank decks along the sides and back at two lifts, and a ladder."""
    trim, wood, metal = t.bm("TRIM"), t.bm("WOOD"), t.bm("METAL")
    w, d, h = 18.0, 14.0, 30.0
    xs, ys = (-w / 2, -w / 6, w / 6, w / 2), (-d / 2, d / 2)
    for x in (-w / 2, w / 2):
        for y in (-d / 2, 0, d / 2):
            strut(trim, (x, y, 0), (x, y, h), 0.45)
            box(metal, (1.2, 1.2, 0.3), T((x, y, 0.15)))
    for x in xs[1:3]:
        strut(trim, (x, d / 2, 0), (x, d / 2, h), 0.45)
    for k in range(1, 5):
        z = k * h / 4.4
        for y in ys:
            strut(trim, (-w / 2, y, z), (w / 2, y, z), 0.35)
        for x in (-w / 2, w / 2):
            strut(trim, (x, -d / 2, z), (x, d / 2, z), 0.35)
    for k in range(4):
        z0, z1 = k * h / 4.4 + 0.5, (k + 1) * h / 4.4
        strut(trim, (-w / 2, d / 2, z0), (-w / 6, d / 2, z1), 0.25)
        strut(trim, (w / 2, d / 2, z0), (w / 6, d / 2, z1), 0.25)
        for x in (-w / 2, w / 2):
            strut(trim, (x, -d / 2, z0), (x, d / 2, z1), 0.25)
    for z in (h / 4.4 * 2, h / 4.4 * 4):
        box(wood, (w, 2.6, 0.3), T((0, d / 2 - 1.3, z + 0.2)))
        for x in (-w / 2, w / 2):
            box(wood, (2.6, d - 2.6, 0.3), T((x - math.copysign(1.3, x), 0, z + 0.2)))
        railing(trim, -w / 2, w / 2, d / 2 + 0.2, z + 0.35, 4)
    for sy in (-0.5, 0.5):
        strut(trim, (w / 2 + 0.6, -d / 2 + 2 + sy, 0), (w / 2 + 0.6, -d / 2 + 2 + sy, h / 4.4 * 4), 0.2)
    for k in range(26):
        z = 0.8 + k * 1.0
        strut(trim, (w / 2 + 0.6, -d / 2 + 1.5, z), (w / 2 + 0.6, -d / 2 + 2.5, z), 0.15)


@template("ChainHoist", METAL=1200, TRIM=1600, GOLD=300)
def chain_hoist(t):
    """A chain hoist: a forged hook (its tip is the origin), the bottom block with its sheave, twin load chains
    running up 20 studs to the top block, and a slack hand chain looping down beside them."""
    metal, trim, gold = t.bm("METAL"), t.bm("TRIM"), t.bm("GOLD")
    # The hook: a tube curling up from the tip.
    tube(gold, [(1.0, 0, 1.4), (0.9, 0, 0.6), (0, 0, 0.4), (-0.9, 0, 0.8), (-0.9, 0, 1.9), (-0.3, 0, 2.9), (0, 0, 3.7)],
         [0.2, 0.3, 0.36, 0.36, 0.34, 0.3, 0.3], 8, cap=True)
    # Bottom block with sheave.
    box(metal, (1.6, 1.4, 2.4), T((0, 0, 4.6)), bevel=0.25)
    cyl_x(trim, 1.3, 0.6, (0, 0, 5.0), segs=14)
    # Load chains up to the top block.
    for sx in (-0.45, 0.45):
        chain(trim, (sx, 0, 5.8), (sx, 0, 19.0))
    box(metal, (2.6, 2.2, 2.6), T((0, 0, 20.4)), bevel=0.3)
    cyl_y(trim, 1.6, 0.5, (0, -1.3, 20.4), segs=16)
    # Hand chain loop.
    chain(trim, (0, -1.6, 19.4), (0.3, -1.6, 9.0), link=0.6)
    chain(trim, (0.6, -1.6, 9.0), (0.6, -1.6, 19.4), link=0.6)
    box(gold, (0.8, 0.8, 0.6), T((0, 0, 22.0)))


@template("CraneTrolley", METAL=2600, TRIM=2200, GOLD=500, ACCENT=500, GLOW=150)
def crane_trolley(t):
    """The crane trolley's winch house: a riveted carriage on four flanged wheels, twin rope drums, a gearbox and
    motor, a small operator's shelter with a lit gauge, and a railing round its roof."""
    metal, trim, gold, accent, glow = (t.bm(r) for r in ("METAL", "TRIM", "GOLD", "ACCENT", "GLOW"))
    box(trim, (16, 11, 1.4), T((0, 0, 1.6)))
    for sx in (-1, 1):
        for sy in (-1, 1):
            cyl_x(metal, 1.1, 0.8, (sx * 6.5, sy * 4.6, 1.1), segs=12)
    for sx in (-1, 1):
        cyl_x(metal, 2.6, 5.4, (sx * 3.6, 0, 5.4), segs=18)
        for k in range(6):
            ring_mesh(gold, 2.65, 0.1, 22, T((sx * 3.6 - 2.4 + k * 0.95, 0, 5.4)) @ R(math.pi / 2, 4, "Y"), tube_segs=4)
        box(trim, (0.8, 6.4, 6.0), T((sx * 6.8, 0, 5.0)))
    box(metal, (4, 4, 4), T((0, 3.4, 4.4)))
    box(accent, (4.4, 2.6, 3.0), T((0, -3.8, 3.8)))
    # Operator's shelter.
    box(metal, (5.6, 4.4, 6.0), T((-4.8, -3.8, 5.3)))
    box(trim, (6.4, 5.2, 0.4), T((-4.8, -3.8, 8.5)))
    box(glow, (1.2, 0.2, 1.2), T((-4.8, -6.05, 6.0)))
    railing(trim, -8, 8, 5.4, 8.5, 4)


@template("QuenchTank", METAL=1800, TRIM=1600, CRYSTAL=200, STONE=600)
def quench_tank(t):
    """A quench tank sunk in the floor: a riveted iron rim round dark oil-black water, a brick kerb, handrails on
    three sides, an inlet pipe curling over the edge, and a dunking cradle on the near side."""
    metal, trim, crystal, stone = (t.bm(r) for r in ("METAL", "TRIM", "CRYSTAL", "STONE"))
    w, d = 24.0, 16.0
    box(stone, (w + 3, d + 3, 1.0), T((0, 0, 0.3)))
    for sy in (-1, 1):
        box(metal, (w, 1.0, 1.8), T((0, sy * (d / 2 - 0.5), 1.0)))
    for sx in (-1, 1):
        box(metal, (1.0, d - 2, 1.8), T((sx * (w / 2 - 0.5), 0, 1.0)))
    box(crystal, (w - 2, d - 2, 0.2), T((0, 0, 1.2)))
    railing(trim, -w / 2, w / 2, d / 2 + 0.6, 1.8, 6)
    for sx in (-1, 1):
        strut(trim, (sx * (w / 2 + 0.6), -d / 2, 5.0), (sx * (w / 2 + 0.6), d / 2, 5.0), 0.28)
        for k in range(4):
            y = -d / 2 + k * d / 3
            strut(trim, (sx * (w / 2 + 0.6), y, 1.8), (sx * (w / 2 + 0.6), y, 5.1), 0.26)
    tube(metal, [(w / 2 + 2.0, -3, 0.2), (w / 2 + 2.0, -3, 5.0), (w / 2 + 0.4, -3, 6.4), (w / 2 - 2.0, -3, 5.6), (w / 2 - 2.0, -3, 3.0)],
         [0.7] * 5, 10, cap=False)
    # Dunking cradle on the open side.
    for sx in (-1, 1):
        strut(trim, (sx * 3, -d / 2 - 1.0, 0.8), (sx * 2, -d / 2 + 1.5, 7.0), 0.4)
    strut(trim, (-2, -d / 2 + 1.5, 7.0), (2, -d / 2 + 1.5, 7.0), 0.4)
    chain_pts = [(0, -d / 2 + 1.5, 6.8), (0, -d / 2 + 1.5, 2.4)]
    strut(trim, chain_pts[0], chain_pts[1], 0.15)
    box(metal, (2.4, 1.2, 0.6), T((0, -d / 2 + 1.5, 2.2)))


@template("PatternRack", WOOD=2400, TRIM=900, ACCENT=500)
def pattern_rack(t):
    """A timber rack of wooden foundry patterns: a gear pattern, a gauntlet pattern, a hammer-head pattern and
    flat core boxes leaned against it, with a pattern-maker's bench at its foot."""
    wood, trim, accent = t.bm("WOOD"), t.bm("TRIM"), t.bm("ACCENT")
    for sx in (-1, 1):
        box(wood, (0.6, 1.8, 11), T((sx * 6, 0.8, 5.5)))
    for z in (2.4, 6.0, 9.6):
        box(wood, (12.6, 2.0, 0.4), T((0, 0.8, z)))
    box(wood, (12.6, 0.3, 10.6), T((0, 1.8, 5.5)))
    # Gear pattern (a ring of teeth, carved in wood) leaned on the rack.
    g = T((-3.0, -0.4, 5.0)) @ R(math.radians(80), 4, "X")
    gear_ring(wood, 2.4, 12, 0.7, g)
    # Gauntlet and hammer-head patterns on the shelves.
    box(wood, (2.4, 1.4, 3.0), T((2.6, 0.4, 7.5)), bevel=0.3)
    for k in range(4):
        box(wood, (0.5, 0.6, 1.2), T((1.8 + k * 0.55, 0.0, 9.2)))
    box(wood, (3.6, 1.6, 1.6), T((3.0, 0.4, 3.4)), bevel=0.3)
    box(accent, (1.0, 1.2, 1.0), T((-1.0, 0.4, 3.4)))
    # Core boxes leaned at the front.
    for k in range(3):
        box(wood, (2.6, 0.4, 3.4), T((-4.4 + k * 3.4, -1.6, 1.6)) @ R(math.radians(-14), 4, "X"))
    # Bench.
    box(wood, (8, 3.0, 0.5), T((1.0, -3.8, 3.2)))
    for sx in (-1, 1):
        for sy in (-1, 1):
            box(trim, (0.4, 0.4, 3.0), T((1.0 + sx * 3.6, -3.8 + sy * 1.2, 1.5)))
    box(trim, (1.6, 0.8, 0.8), T((3.4, -3.8, 3.8)))


@template("ControlCabin", METAL=2200, TRIM=2000, CRYSTAL=600, GOLD=600, GLOW=200, WOOD=300)
def control_cabin(t):
    """The crane's control cab: an iron-framed glazed booth with a hipped roof, a door and step, banks of brass
    levers and round gauges behind the glass, and a lamp over the door."""
    metal, trim, crystal, gold, glow, wood = (t.bm(r) for r in ("METAL", "TRIM", "CRYSTAL", "GOLD", "GLOW", "WOOD"))
    w, d, h = 14.0, 11.0, 9.0
    box(metal, (w + 1, d + 1, 1.0), T((0, 0, 0.5)))
    box(metal, (w, d, 3.0), T((0, 0, 2.5)))
    # Glazed walls: mullions and panes.
    for k in range(8):
        x = -w / 2 + k * w / 7
        for sy in (-1, 1):
            box(trim, (0.35, 0.35, h - 4), T((x, sy * d / 2, 4.0 + (h - 4) / 2)))
    for k in range(6):
        y = -d / 2 + k * d / 5
        for sx in (-1, 1):
            box(trim, (0.35, 0.35, h - 4), T((sx * w / 2, y, 4.0 + (h - 4) / 2)))
    for sy in (-1, 1):
        box(crystal, (w - 0.4, 0.1, h - 4.2), T((0, sy * (d / 2 - 0.05), 4.0 + (h - 4) / 2)))
        box(trim, (w, 0.4, 0.4), T((0, sy * d / 2, 6.6)))
    for sx in (-1, 1):
        box(crystal, (0.1, d - 0.4, h - 4.2), T((sx * (w / 2 - 0.05), 0, 4.0 + (h - 4) / 2)))
    box(trim, (w + 0.4, d + 0.4, 0.6), T((0, 0, h + 0.3)))
    cone(metal, w * 0.78, 0.8, 3.2, 4, T((0, 0, h + 0.6)) @ R(math.pi / 4, 4, "Z") @ Matrix.Diagonal((1, d / w, 1, 1)))
    # Lever banks and gauges inside.
    box(wood, (w - 3, 2.4, 1.0), T((0, -d / 2 + 2.2, 4.4)))
    for k in range(9):
        strut(gold, (-5 + k * 1.25, -d / 2 + 2.2, 4.9), (-5 + k * 1.25 + 0.3, -d / 2 + 2.6, 7.2), 0.2)
    for k in range(3):
        cyl_y(gold, 0.6, 0.3, (-3 + k * 3, d / 2 - 1.0, 6.6), segs=12)
    box(glow, (1.0, 0.6, 0.6), T((w / 2 - 1.6, -d / 2 - 0.4, h - 0.6)))
    box(wood, (2.6, 1.4, 0.4), T((w / 2 - 2.4, -d / 2 - 0.8, 0.2)))


@template("FurnaceBox", STONE=2600, METAL=1800, TRIM=1400, GLOW=500)
def furnace_box(t):
    """A brick reverberatory furnace: a tall stepped brick body with an arched glowing mouth behind an iron door
    frame, iron tie-rods and bands, a charging platform, and two iron chimneys venting steam."""
    stone, metal, trim, glow = (t.bm(r) for r in ("STONE", "METAL", "TRIM", "GLOW"))
    w, d = 22.0, 16.0
    box(stone, (w, d, 14), T((0, 0, 7)))
    box(stone, (w - 4, d - 2, 6), T((0, 1, 17)))
    box(trim, (w + 0.6, d + 0.6, 0.8), T((0, 0, 14.2)))
    # Arched mouth.
    box(glow, (8, 0.4, 6), T((0, -d / 2 - 0.05, 4.4)))
    cyl_y(glow, 4.0, 0.4, (0, -d / 2 - 0.05, 7.4), segs=18)
    box(trim, (10, 1.0, 1.0), T((0, -d / 2 - 0.4, 0.6)))
    for sx in (-1, 1):
        box(trim, (1.0, 1.0, 11.6), T((sx * 5.0, -d / 2 - 0.4, 5.8)))
    ring_mesh(trim, 4.5, 0.5, 20, T((0, -d / 2 - 0.4, 7.4)) @ R(math.pi / 2, 4, "X"), tube_segs=6)
    # Tie rods and buckstays.
    for sx in (-1, 0.33, -0.33, 1):
        box(metal, (0.8, 0.8, 19), T((sx * (w / 2 + 0.3), -d / 2 - 0.3, 9.5)))
    for z in (3, 11):
        box(metal, (w + 1.4, 0.5, 0.5), T((0, -d / 2 - 0.6, z)))
    # Chimneys.
    for sx in (-1, 1):
        cyl_z(metal, 1.6, 14, (sx * 5.5, 3, 20), segs=14)
        ring_mesh(trim, 1.7, 0.25, 18, T((sx * 5.5, 3, 34)), tube_segs=5)
    # Charging platform with a ladder.
    box(metal, (w, 4, 0.6), T((0, d / 2 + 2, 12)))
    railing(trim, -w / 2, w / 2, d / 2 + 4, 12.3, 5)
    for k in range(10):
        strut(trim, (w / 2 + 0.5, d / 2 + 1, 1 + k * 1.1), (w / 2 + 0.5, d / 2 + 3, 1 + k * 1.1), 0.15)


@template("WallGear", METAL=2600, TRIM=1400, ACCENT=800)
def wall_gear(t):
    """A great gear wheel standing on its rim in an iron cradle: spoked hub, a toothed rim, a pinion meshing at
    its side, and the cradle's braced frame."""
    metal, trim, accent = t.bm("METAL"), t.bm("TRIM"), t.bm("ACCENT")
    r = 12.0
    c = Vector((0, 0, r + 1.5))
    m = T(c) @ R(math.pi / 2, 4, "X")
    gear_ring(metal, r, 36, 1.6, m)
    ring_mesh(metal, r - 1.4, 0.7, 36, m, tube_segs=6)
    for k in range(8):
        a = 2 * math.pi * k / 8
        strut(trim, c, c + Vector((math.cos(a) * (r - 1.2), 0, math.sin(a) * (r - 1.2))), 1.0)
    cyl_y(accent, 2.2, 2.4, c, segs=16)
    # Pinion.
    pc = Vector((r + 4.0, 0, 6.0))
    gear_ring(accent, 3.0, 12, 1.0, T(pc) @ R(math.pi / 2, 4, "X"))
    cyl_y(trim, 1.2, 2.0, pc, segs=12)
    # Cradle.
    box(trim, (2 * r + 6, 5, 1.6), T((2, 0, 0.8)))
    for sx in (-1, 1):
        strut(trim, (sx * 6, -2, 1.5), (0, -2, c.z), 0.9)
        strut(trim, (sx * 6, 2, 1.5), (0, 2, c.z), 0.9)


@template("ConveyorRollers", METAL=1600, TRIM=1400, ACCENT=600)
def conveyor_rollers(t):
    """A roller conveyor on trestle legs carrying cast construct parts: a run of rollers between side rails, the
    drive drum and its motor at one end."""
    metal, trim, accent = t.bm("METAL"), t.bm("TRIM"), t.bm("ACCENT")
    length, h = 22.0, 3.2
    for sx in (-1, 1):
        box(trim, (0.5, length, 0.8), T((sx * 2.6, 0, h)))
    for k in range(18):
        y = -length / 2 + 0.8 + k * (length - 1.6) / 17
        cyl_x(metal, 0.4, 5.0, (0, y, h + 0.1), segs=8)
    for y in (-length / 2 + 1.5, 0, length / 2 - 1.5):
        for sx in (-1, 1):
            box(trim, (0.5, 0.5, h), T((sx * 2.4, y, h / 2)))
        box(trim, (5.2, 0.4, 0.4), T((0, y, 1.0)))
    cyl_x(accent, 0.9, 5.0, (0, length / 2, h + 0.1), segs=12)
    box(metal, (2.6, 2.4, 2.2), T((3.8, length / 2 - 1, h - 0.6)))
    # Cast parts riding the rollers.
    box(accent, (2.4, 3.0, 1.6), T((0, -5, h + 1.3)), bevel=0.4)
    uvsphere(metal, 1.4, T((0, 2.5, h + 1.6)) @ Matrix.Diagonal((1, 1.1, 0.8, 1)), 10, 6)


@template("PartsRack", TRIM=1600, METAL=1800, GOLD=400)
def parts_rack(t):
    """An iron shelving rack of construct parts: helms, gauntlets, hammer heads and coils of rivets on three
    shelves."""
    trim, metal, gold = t.bm("TRIM"), t.bm("METAL"), t.bm("GOLD")
    w, d, h = 12.0, 3.4, 9.0
    for sx in (-1, 1):
        for sy in (-1, 1):
            box(trim, (0.4, 0.4, h), T((sx * w / 2, sy * d / 2, h / 2)))
    for z in (0.6, 3.4, 6.2, 8.8):
        box(trim, (w, d, 0.25), T((0, 0, z)))
    strut(trim, (-w / 2, d / 2, 0.6), (w / 2, d / 2, 8.8), 0.25)
    rng = random.Random(2201)
    for z in (0.75, 3.55, 6.35):
        x = -w / 2 + 1.4
        while x < w / 2 - 1.4:
            kind = rng.randint(0, 3)
            if kind == 0:
                box(metal, (1.8, 1.8, 1.8), T((x, 0, z + 0.9)), bevel=0.4)
            elif kind == 1:
                box(metal, (1.4, 2.4, 1.0), T((x, 0, z + 0.5)), bevel=0.2)
                for k in range(3):
                    box(metal, (0.3, 0.6, 0.8), T((x - 0.4 + k * 0.4, -1.0, z + 1.2)))
            elif kind == 2:
                box(metal, (2.2, 1.2, 1.2), T((x, 0, z + 0.6)), bevel=0.2)
            else:
                cyl_z(gold, 0.8, 0.8, (x, 0, z), segs=10)
            x += 2.6


@template("HydraulicJack", METAL=1800, TRIM=1200, GOLD=500, ACCENT=700)
def hydraulic_jack(t):
    """The failed jack: a squat iron cylinder on a riveted base with its ram half-extended and cocked, a split
    seam weeping rust, a hand pump and a coil of hose."""
    metal, trim, gold, accent = (t.bm(r) for r in ("METAL", "TRIM", "GOLD", "ACCENT"))
    box(trim, (8, 8, 1.2), T((0, 0, 0.6)), bevel=0.2)
    cyl_z(metal, 2.6, 7.0, (0, 0, 1.2), segs=18)
    ring_mesh(gold, 2.7, 0.25, 22, T((0, 0, 3.0)), tube_segs=5)
    ring_mesh(gold, 2.7, 0.25, 22, T((0, 0, 7.0)), tube_segs=5)
    cone(trim, 1.7, 1.7, 6.0, 14, T((0, 0, 8.2)) @ R(math.radians(9), 4, "Y"))
    box(metal, (4.6, 4.6, 1.0), T((0.9, 0, 14.4)) @ R(math.radians(9), 4, "Y"))
    box(accent, (0.4, 0.6, 5.6), T((2.6, -0.4, 4.4)))
    box(metal, (1.6, 1.6, 2.4), T((-3.6, -2.6, 2.4)))
    strut(trim, (-3.6, -2.6, 3.6), (-4.8, -3.6, 6.4), 0.25)
    tube(trim, [(-3.6, -1.8, 1.6), (-2.0, -2.8, 1.4), (0, -3.2, 1.6), (1.8, -2.6, 2.0)], [0.25] * 4, 8, cap=False)


if __name__ == "__main__":
    kit, manifest = build_kit("InfernalF22Kit", F22_TEMPLATES, DEFAULT_BUDGET)
    export_kit(kit, manifest, OUT_DIR, "InfernalF22Kit")
    render_previews(kit, F22_TEMPLATES, OUT_DIR)
    print(json.dumps(manifest, indent=2))
