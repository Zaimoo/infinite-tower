"""
Infernal Foundry Floor 23 (Furnace Causeway) sculpted assets, generated in headless Blender.

Inspired by the furnace-line reference art: a rail causeway on stone piers over a lava lake, a tilting crucible
pouring into casting moulds, slag ladles tipping into the lava, furnace towers with glowing mouths, a giant
arched furnace door at the head of a stair, jib cranes with chains, bellows ducts, steam vents and crust floes.

1 Blender unit = 1 stud, standing on z = 0, front facing -Y in Blender / +Z in Roblox, one mesh object per colour
role named "<Template>__<ROLE>". Pour streams are part of their template (GLOW), so they always reach the mould.

Roles (TowerSetPieces passes a Sootwright override): METAL iron, TRIM dark iron, STONE soot brick, GOLD brass,
WOOD timber, ACCENT rust, GLOW molten metal, ALT basalt crust.

Outputs (assets-source/tower/infernal_f23_kit/): InfernalF23Kit.blend, InfernalF23Kit.fbx, manifest.json,
previews/kit_sheet_1.png.

Run:
    blender.exe --background --factory-startup --python tools/blender/generate_infernal_f23_kit.py
"""
import bpy, bmesh, math, os, json, runpy, random
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT_DIR = os.path.join(ROOT, "assets-source", "tower", "infernal_f23_kit")

f22 = runpy.run_path(os.path.join(HERE, "generate_infernal_f22_kit.py"))
box, cone, uvsphere, tube, ring_mesh = f22["box"], f22["cone"], f22["uvsphere"], f22["tube"], f22["ring_mesh"]
rock_clean, cyl_x, cyl_y, cyl_z = f22["rock_clean"], f22["cyl_x"], f22["cyl_y"], f22["cyl_z"]
strut, wheel_x, gear_ring, railing, chain = f22["strut"], f22["wheel_x"], f22["gear_ring"], f22["railing"], f22["chain"]
build_kit, export_kit, render_previews = f22["build_kit"], f22["export_kit"], f22["render_previews"]
T = Matrix.Translation
R = Matrix.Rotation

DEFAULT_BUDGET = 3500
F23_TEMPLATES = {}


def template(name, **budget):
    def deco(fn):
        F23_TEMPLATES[name] = (fn, budget)
        return fn
    return deco


def arch_ring(bm, centre, r, thick, depth, segs=16):
    """A semicircular arch of blocks in the XZ plane (opening toward -Y) centred at centre."""
    c = Vector(centre)
    for k in range(segs):
        a0, a1 = math.pi * k / segs, math.pi * (k + 1) / segs
        am = (a0 + a1) / 2
        at = c + Vector((math.cos(am) * r, 0, math.sin(am) * r))
        size = (thick, depth, 2 * math.pi * r / (2 * segs) * 1.08)
        box(bm, size, T(at) @ R(-am, 4, "Y"))


def stream(bm, p0, p1, p2, r0, r1):
    """A molten pour: a tapering tube curving from p0 through p1 to p2."""
    pts = []
    for k in range(9):
        t = k / 8
        a = Vector(p0).lerp(Vector(p1), t)
        b = Vector(p1).lerp(Vector(p2), t)
        pts.append(a.lerp(b, t))
    tube(bm, pts, [r0 + (r1 - r0) * k / 8 for k in range(9)], 10, cap=True)


@template("FurnaceTower", STONE=2400, METAL=1400, TRIM=1200, GLOW=500, ACCENT=400)
def furnace_tower(t):
    """A furnace tower: a tapering soot-brick shaft on a stepped base, an arched mouth glowing at its foot behind an
    iron door frame, a charging door half-way up with a gangway, iron hoops, and a flue stack on its crown."""
    stone, metal, trim, glow, accent = (t.bm(r) for r in ("STONE", "METAL", "TRIM", "GLOW", "ACCENT"))
    box(stone, (20, 18, 4), T((0, 0, 2)))
    cone(stone, 9.0, 7.0, 34, 4, T((0, 0, 4)) @ R(math.pi / 4, 4, "Z") @ Matrix.Diagonal((1.0, 0.9, 1, 1)))
    for k in range(5):
        z = 8 + k * 6.5
        rr = 9.0 - 2.0 * (z - 4) / 34
        cone(trim, rr * 1.03, rr * 1.03, 0.8, 4, T((0, 0, z)) @ R(math.pi / 4, 4, "Z") @ Matrix.Diagonal((1.0, 0.9, 1, 1)))
    # The mouth: a glowing arch in a door frame.
    box(glow, (7, 0.4, 6), T((0, -6.35, 7)))
    cyl_y(glow, 3.5, 0.4, (0, -6.35, 10), segs=16)
    arch_ring(trim, (0, -6.7, 10), 4.4, 1.2, 1.4)
    for sx in (-1, 1):
        box(trim, (1.2, 1.4, 6.0), T((sx * 4.4, -6.7, 7.0)))
    box(trim, (10, 2.0, 1.0), T((0, -7.0, 4.5)))
    # Charging door and gangway.
    box(metal, (4, 0.6, 4), T((0, -5.7, 24)))
    box(glow, (2.4, 0.3, 0.6), T((0, -6.05, 22.6)))
    box(trim, (10, 3.0, 0.5), T((0, -7.2, 21.6)))
    railing(trim, -5, 5, -8.6, 21.8, 3)
    # Crown and stack.
    box(stone, (13, 12, 3), T((0, 0, 39.5)))
    cyl_z(metal, 2.6, 18, (0, 1.5, 41), segs=16)
    ring_mesh(accent, 2.7, 0.35, 20, T((0, 1.5, 58.6)), tube_segs=5)
    cyl_z(glow, 2.0, 0.3, (0, 1.5, 59.0), segs=14)


@template("TiltingCrucible", METAL=2600, TRIM=1600, GLOW=900, GOLD=400, ACCENT=500)
def tilting_crucible(t):
    """A tilting crucible on a trunnion frame, tipped forward, a white-hot stream pouring from its lip down to the
    ground in front of it, with the tilting wheel and gearing at its side."""
    metal, trim, glow, gold, accent = (t.bm(r) for r in ("METAL", "TRIM", "GLOW", "GOLD", "ACCENT"))
    for sx in (-1, 1):
        box(trim, (1.4, 3.0, 9.0), T((sx * 6.2, 2.0, 4.5)))
        strut(trim, (sx * 6.2, 5.0, 0.2), (sx * 6.2, 2.0, 8.5), 0.9)
        strut(trim, (sx * 6.2, -1.0, 0.2), (sx * 6.2, 2.0, 8.5), 0.9)
        box(metal, (3.0, 7.0, 0.8), T((sx * 6.2, 2.0, 0.4)))
    cyl_x(gold, 0.8, 13.6, (0, 2.0, 8.5), segs=12)
    tilt = T((0, 2.0, 8.5)) @ R(math.radians(-55), 4, "X")
    # The pot: a lathe-like cone open at the top, tilted forward (-Y).
    cone(metal, 3.6, 5.0, 8.0, 18, tilt @ T((0, 0, -3.5)))
    ring_mesh(accent, 5.0, 0.45, 22, tilt @ T((0, 0, 4.5)), tube_segs=6)
    box(glow, (6.4, 6.4, 0.3), tilt @ T((0, 0, 4.3)))
    # Spout and stream down to the ground in front.
    lip = tilt @ Vector((0, -4.6, 4.6))
    box(metal, (2.0, 2.4, 1.0), tilt @ T((0, -5.2, 4.2)))
    stream(glow, lip, lip + Vector((0, -3.0, -1.5)), (0, -9.5, 0.2), 0.55, 0.9)
    # Splash pool.
    cyl_z(glow, 2.4, 0.3, (0, -9.5, 0.0), segs=14)
    # Tilting wheel.
    wheel_x(trim, metal, 2.8, 0.5, (8.0, 2.0, 8.5), spokes=6, bm_spoke=trim)


@template("MouldBed", STONE=1600, METAL=1000, GLOW=900, TRIM=600)
def mould_bed(t):
    """A casting mould bed: a low iron-framed bed of rammed sand with sword, axe-head and ingot cavities, some
    still glowing with fresh metal, and a runner channel along its length."""
    stone, metal, glow, trim = (t.bm(r) for r in ("STONE", "METAL", "GLOW", "TRIM"))
    w, d = 16.0, 10.0
    box(stone, (w, d, 1.4), T((0, 0, 0.7)))
    for sy in (-1, 1):
        box(metal, (w + 0.6, 0.5, 1.8), T((0, sy * (d / 2 + 0.2), 0.9)))
    for sx in (-1, 1):
        box(metal, (0.5, d, 1.8), T((sx * (w / 2 + 0.2), 0, 0.9)))
    box(glow, (w - 1.0, 0.6, 0.12), T((0, -d / 2 + 1.0, 1.42)))
    rng = random.Random(2301)
    x = -w / 2 + 1.6
    k = 0
    while x < w / 2 - 1.6:
        hot = k % 3 != 2
        bm = glow if hot else trim
        kind = k % 3
        if kind == 0:  # a sword cavity
            box(bm, (0.7, 6.2, 0.12), T((x, 0.6, 1.42)))
            box(bm, (2.2, 0.5, 0.12), T((x, -2.4, 1.42)))
        elif kind == 1:  # an axe head
            box(bm, (2.4, 2.6, 0.12), T((x, 1.0, 1.42)))
            box(bm, (0.5, 3.6, 0.12), T((x, -1.6, 1.42)))
        else:  # ingots
            for j in range(3):
                box(bm, (1.6, 1.2, 0.12), T((x, -2 + j * 2.0, 1.42)))
        strut(glow if hot else trim, (x, -d / 2 + 1.0, 1.45), (x, -2.6, 1.45), 0.25)
        x += 3.0
        k += 1


@template("CoolingRack", TRIM=2000, METAL=800, GLOW=1000, STONE=400)
def cooling_rack(t):
    """A cooling rack: an iron frame hung with rows of fresh-forged blades, the newest still glowing orange at the
    tips, over a trough of quenching sand."""
    trim, metal, glow, stone = (t.bm(r) for r in ("TRIM", "METAL", "GLOW", "STONE"))
    w, h = 12.0, 9.0
    for sx in (-1, 1):
        for sy in (-1, 1):
            box(trim, (0.5, 0.5, h), T((sx * w / 2, sy * 1.6, h / 2)))
    for z in (h - 0.3, h * 0.5):
        for sy in (-1, 1):
            box(trim, (w + 0.4, 0.4, 0.4), T((0, sy * 1.6, z)))
    box(stone, (w - 0.4, 3.0, 1.0), T((0, 0, 0.5)))
    for row, (z, sy) in enumerate(((h - 0.6, -1.6), (h - 0.6, 1.6), (h * 0.5 - 0.3, -1.6))):
        for k in range(8):
            x = -w / 2 + 0.9 + k * (w - 1.8) / 7
            hot = (k + row) % 3 == 0
            box(metal, (0.5, 0.12, 3.4), T((x, sy, z - 1.9)))
            box(glow if hot else metal, (0.4, 0.13, 1.0), T((x, sy, z - 3.9)))
            box(trim, (1.2, 0.3, 0.3), T((x, sy, z - 0.2)))


@template("BladeDisplay", WOOD=1000, METAL=1600, GOLD=600, TRIM=600)
def blade_display(t):
    """A display stand of finished weapons: a timber frame with a greatsword, two longswords, a war axe and a
    hammer racked upright, brass fittings on the guards."""
    wood, metal, gold, trim = (t.bm(r) for r in ("WOOD", "METAL", "GOLD", "TRIM"))
    box(wood, (8, 2.6, 0.6), T((0, 0, 0.3)))
    for sx in (-1, 1):
        box(wood, (0.6, 0.6, 8.5), T((sx * 3.8, 0.8, 4.5)))
    box(wood, (8.2, 0.6, 0.6), T((0, 0.8, 8.6)))
    box(wood, (8.2, 0.6, 0.6), T((0, 0.8, 4.4)))
    for k, x in enumerate((-2.8, -1.2, 0.4, 2.0)):
        tall = 7.6 if k == 0 else 6.2
        box(metal, (0.5 if k else 0.8, 0.12, tall), T((x, 0.4, 0.7 + tall / 2)))
        box(gold, (1.6, 0.4, 0.3), T((x, 0.4, 0.9 + tall * 0.2)))
    # War axe and hammer.
    box(wood, (0.3, 0.3, 6.8), T((3.2, 0.2, 4.0)))
    box(metal, (1.6, 0.2, 1.6), T((3.6, 0.2, 6.8)))
    box(trim, (0.4, 0.4, 2.4), T((2.6, -0.6, 1.8)))


@template("FurnaceDoorGiant", STONE=2800, METAL=1600, TRIM=1600, GLOW=900, GOLD=800)
def furnace_door_giant(t):
    """The Furnace Mouth: a towering brick portal with a stepped round arch, the great furnace beyond it white-hot
    through a raised iron portcullis, buttresses, the hammer-ring over the keystone, and iron bands across."""
    stone, metal, trim, glow, gold = (t.bm(r) for r in ("STONE", "METAL", "TRIM", "GLOW", "GOLD"))
    w, h, d = 46.0, 54.0, 10.0
    for sx in (-1, 1):
        box(stone, (13, d, h), T((sx * (w / 2 - 6.5), 0, h / 2)))
        box(stone, (15, d + 3, 4), T((sx * (w / 2 - 6.5), 0, 2)))
        box(stone, (6, d + 4, h * 0.7), T((sx * (w / 2 + 2), 0.5, h * 0.35)))
    box(stone, (w - 26, d, 16), T((0, 0, h - 8)))
    # Stepped arch over the opening.
    for k, (r, th) in enumerate(((10.4, 1.6), (11.8, 1.4), (13.0, 1.2))):
        arch_ring(trim if k == 1 else stone, (0, -d / 2 - 0.2 - k * 0.6, 26), r, th, 1.6 + k * 0.4)
    # The fire beyond: glow panels deep in the opening.
    box(glow, (19, 0.5, 26), T((0, d / 2 - 1.5, 13)))
    cyl_y(glow, 9.5, 0.5, (0, d / 2 - 1.5, 26), segs=20)
    # Raised portcullis bars at the top of the opening.
    for k in range(7):
        x = -7.5 + k * 2.5
        box(metal, (0.6, 0.6, 8), T((x, -d / 2 + 2, 30)))
    box(metal, (19, 0.8, 0.8), T((0, -d / 2 + 2, 26.6)))
    # Bands, keystone and sigil.
    for z in (8, 18, 44):
        box(trim, (w + 1, d + 0.6, 0.8), T((0, 0, z)))
    box(stone, (5, d + 1.2, 6), T((0, -0.6, 39)))
    sig = T((0, -d / 2 - 1.4, 46)) @ R(math.pi / 2, 4, "X")
    gear_ring(gold, 3.6, 12, 0.9, sig)
    box(gold, (0.8, 4.2, 0.6), sig @ T((0, -0.8, 0)))
    box(gold, (3.6, 1.6, 0.8), sig @ T((0, 1.8, 0)))
    # Threshold step.
    box(trim, (22, 4, 1.2), T((0, -d / 2 - 1.6, 0.6)))


@template("SlagLadleCart", METAL=2400, TRIM=1600, GLOW=800, ACCENT=500)
def slag_ladle_cart(t):
    """A slag-ladle cart on a rail bogie: the bell-shaped ladle tipped out over the front on its trunnions, a
    glowing stream falling off its lip, the tipping gear and a coupler."""
    metal, trim, glow, accent = (t.bm(r) for r in ("METAL", "TRIM", "GLOW", "ACCENT"))
    box(trim, (5.6, 11, 1.2), T((0, 1.0, 2.0)))
    for y in (-2.4, 4.4):
        for sx in (-1, 1):
            cyl_x(metal, 1.3, 0.6, (sx * 2.6, y, 1.3), segs=12)
    for sx in (-1, 1):
        box(trim, (0.9, 2.0, 6.0), T((sx * 4.4, 1.0, 5.0)))
    cyl_x(accent, 0.7, 9.6, (0, 1.0, 7.4), segs=10)
    tilt = T((0, 1.0, 7.4)) @ R(math.radians(-70), 4, "X")
    cone(metal, 2.6, 4.4, 7.0, 18, tilt @ T((0, 0, -3.0)))
    box(glow, (5.6, 5.6, 0.3), tilt @ T((0, 0, 3.8)))
    lip = tilt @ Vector((0, -4.2, 4.0))
    stream(glow, lip, lip + Vector((0, -2.5, -1.0)), (0, -9.0, -1.8), 0.5, 0.8)
    wheel_x(trim, metal, 2.2, 0.4, (5.2, 1.0, 7.4), spokes=6, bm_spoke=trim)
    box(trim, (1.2, 1.2, 0.8), T((0, 6.8, 2.0)))


@template("JibCrane", TRIM=2400, METAL=1400, GOLD=300, ACCENT=500)
def jib_crane(t):
    """A foundry jib crane: a braced lattice mast on a riveted base, a raking boom reaching out over the front,
    its pulley, a hanging chain and hook, and the winch box on the mast."""
    trim, metal, gold, accent = (t.bm(r) for r in ("TRIM", "METAL", "GOLD", "ACCENT"))
    box(metal, (6, 6, 1.6), T((0, 0, 0.8)))
    h = 26.0
    for sx in (-1, 1):
        for sy in (-1, 1):
            strut(trim, (sx * 1.6, sy * 1.6, 1.6), (sx * 1.2, sy * 1.2, h), 0.5)
    for k in range(8):
        z0 = 1.6 + k * (h - 1.6) / 8
        z1 = z0 + (h - 1.6) / 8
        strut(trim, (-1.5, -1.5, z0), (1.5, -1.5, z1), 0.25)
        strut(trim, (1.5, 1.5, z0), (-1.5, 1.5, z1), 0.25)
    box(metal, (3.6, 3.6, 1.2), T((0, 0, h + 0.6)))
    # Boom raking out toward the front (-Y).
    tip = Vector((0, -18, h + 6))
    strut(trim, (0, -0.5, h - 6), tip, 1.0)
    strut(trim, (0, 0, h + 1), tip, 0.6)
    for k in range(5):
        a = Vector((0, -0.5, h - 6)).lerp(tip, (k + 0.5) / 5)
        b = Vector((0, 0, h + 1)).lerp(tip, (k + 1) / 5)
        strut(trim, a, b, 0.25)
    cyl_x(gold, 0.9, 0.6, tip + Vector((0, 0, -0.8)), segs=12)
    chain(trim, tip + Vector((0, 0, -1.6)), (0, -18, h - 14))
    box(metal, (1.4, 1.2, 1.8), T((0, -18, h - 15)))
    tube(gold, [(0.6, -18, h - 17.4), (0.5, -18, h - 18.2), (0, -18, h - 18.4), (-0.5, -18, h - 17.9), (-0.4, -18, h - 16.2)], [0.18, 0.22, 0.24, 0.22, 0.2], 8, cap=True)
    box(accent, (2.4, 2.0, 2.4), T((0, 2.4, 10)))
    cyl_x(metal, 0.8, 2.6, (0, 2.4, 11.6), segs=10)


@template("BellowsDuctRun", METAL=2200, TRIM=1400, ACCENT=500)
def bellows_duct_run(t):
    """A great bellows duct: an iron pipe rising from a flanged floor shoe, bending through a riveted elbow and
    running level overhead toward the front, its joints flanged and a damper wheel on the riser."""
    metal, trim, accent = t.bm("METAL"), t.bm("TRIM"), t.bm("ACCENT")
    r = 2.6
    box(trim, (8, 8, 1.6), T((0, 4, 0.8)))
    pts = [(0, 4, 1.0), (0, 4, 18.0), (0, 3.2, 21.5), (0, 0.5, 24.0), (0, -3, 24.6), (0, -18, 24.6)]
    tube(metal, pts, [r] * len(pts), 18, cap=True)
    for z in (6.0, 12.0, 17.5):
        ring_mesh(trim, r + 0.25, 0.35, 22, T((0, 4, z)), tube_segs=5)
    for y in (-8.0, -14.0):
        ring_mesh(trim, r + 0.25, 0.35, 22, T((0, y, 24.6)) @ R(math.pi / 2, 4, "X"), tube_segs=5)
    wheel_x(accent, trim, 1.6, 0.3, (r + 0.8, 4, 10.0), spokes=4, bm_spoke=trim)
    for y in (-11.0, -17.0):
        strut(trim, (0, y, 0.0), (0, y, 22.0), 0.7)
        box(trim, (3, 3, 0.8), T((0, y, 0.4)))


@template("CrustIsland", ALT=1400, GLOW=800, STONE=400)
def crust_island(t):
    """A floe of cooled crust adrift on the lava: a broad flat basalt raft, plate-cracked, with molten light
    welling up through its seams and a few rafted-up slabs."""
    alt, glow, stone = t.bm("ALT"), t.bm("GLOW"), t.bm("STONE")
    rock_clean(alt, (16, 12, 1.6), T((0, 0, -0.2)), seed=2331, roughness=0.18, subdiv=2)
    rng = random.Random(2332)
    for k in range(5):
        x, y = rng.uniform(-5, 5), rng.uniform(-3.5, 3.5)
        box(stone, (rng.uniform(2.5, 4.5), rng.uniform(2, 3.5), 0.8), T((x, y, 1.0)) @ R(rng.uniform(-0.4, 0.4), 4, "X") @ R(rng.uniform(0, 3), 4, "Z"))
    for k in range(6):
        a = rng.uniform(0, math.pi)
        x, y = rng.uniform(-4, 4), rng.uniform(-3, 3)
        box(glow, (rng.uniform(4, 8), 0.35, 0.2), T((x, y, 0.95)) @ R(a, 4, "Z"))


@template("SteamVent", METAL=900, TRIM=700, ACCENT=300)
def steam_vent(t):
    """A steam relief vent: an iron stack on a flanged base with a mushroom cowl, a valve wheel and a gauge."""
    metal, trim, accent = t.bm("METAL"), t.bm("TRIM"), t.bm("ACCENT")
    box(trim, (4, 4, 0.8), T((0, 0, 0.4)))
    cyl_z(metal, 1.1, 8.0, (0, 0, 0.8), segs=12)
    ring_mesh(trim, 1.25, 0.25, 16, T((0, 0, 4.0)), tube_segs=5)
    cone(metal, 2.4, 0.6, 1.4, 14, T((0, 0, 9.4)))
    cyl_z(metal, 0.4, 0.8, (0, 0, 8.8), segs=8)
    wheel_x(accent, trim, 0.8, 0.2, (1.6, 0, 3.0), spokes=4, bm_spoke=trim)
    cyl_y(accent, 0.5, 0.2, (0, -1.25, 5.6), segs=10)


if __name__ == "__main__":
    kit, manifest = build_kit("InfernalF23Kit", F23_TEMPLATES, DEFAULT_BUDGET)
    export_kit(kit, manifest, OUT_DIR, "InfernalF23Kit")
    render_previews(kit, F23_TEMPLATES, OUT_DIR)
    print(json.dumps(manifest, indent=2))
