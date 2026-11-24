"""
Thunder Highlands Floor 30 (Roc's Eyrie) sculpted assets, generated in headless Blender.

Inspired by the Roc's Eyrie reference art (reference/Thunder Highlands 30.jpg): the summit caldera at the roof
of the Thunder Highlands. Behind the elevated wet-slate Eyrie boss dais rises the colossal twin-peak
ShatteredSkySpire framed by a broken radial ring of copper-clad LightningCrownArch ribs crackling with storm
lightning; woven giant storm-blasted pine logs and braided lashing ropes (EyrieNestRimSegment) ring the Eyrie's
perimeter. In the foreground, a circular stone-and-copper EyePulpitBalustrade juts out over the swirling Cloud
Eye with catenary HangingAbyssChain banners draped across the abyss, flanked on the left by ThresholdRuinArch,
giant impaled ColossalRocFeather plumes, cliffside GaleLanternTower and conical AerieThresholdTotem, and on the
right by ObservatoryHall, terraced fortifications and roaring waterfalls, plus FeatherHeartShrine,
ShatteredCrownFragment and CalderaRibBones.

1 Blender unit = 1 stud, standing on z = 0, front facing -Y in Blender / +Z in Roblox, one mesh object per colour
role named "<Template>__<ROLE>". Every piece stands on its origin.

Roles (TowerSetPieces passes the Kairnfolk override): STONE granite and slate, MOSS turf, METAL hammered copper,
ACCENT verdigris, WOOD weathered timber, TRIM dark slate and bone/iron, ALT banner cloth / feather vanes / rope,
GLOW violet storm light, CRYSTAL storm glass, GOLD storm-heart gold.

Outputs (assets-source/tower/thunder_f30_kit/): ThunderF30Kit.blend, ThunderF30Kit.fbx, manifest.json,
previews/kit_sheet_1.png.

Run:
    blender.exe --background --factory-startup --python tools/blender/generate_thunder_f30_kit.py
"""
import bpy, bmesh, math, os, json, runpy, random
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT_DIR = os.path.join(ROOT, "assets-source", "tower", "thunder_f30_kit")

f26 = runpy.run_path(os.path.join(HERE, "generate_thunder_f26_kit.py"))
f28 = runpy.run_path(os.path.join(HERE, "generate_thunder_f28_kit.py"))
f29 = runpy.run_path(os.path.join(HERE, "generate_thunder_f29_kit.py"))
box, cone, uvsphere, tube, ring_mesh = f26["box"], f26["cone"], f26["uvsphere"], f26["tube"], f26["ring_mesh"]
cyl_x, cyl_y, cyl_z, strut = f26["cyl_x"], f26["cyl_y"], f26["cyl_z"], f26["strut"]
ground_rock, centred_rock, slab_stone, bolt = f26["ground_rock"], f26["centred_rock"], f26["slab_stone"], f26["bolt"]
build_kit, export_kit, render_previews = f26["build_kit"], f26["export_kit"], f26["render_previews"]
coursed_block, cone_along, hanging_rope = f28["coursed_block"], f28["cone_along"], f28["hanging_rope"]
drum, round_crenels, copper_rings, banner = f29["drum"], f29["round_crenels"], f29["copper_rings"], f29["banner"]
T = Matrix.Translation
R = Matrix.Rotation

DEFAULT_BUDGET = 3500
F30_TEMPLATES = {}


def template(name, **budget):
    def deco(fn):
        F30_TEMPLATES[name] = (fn, budget)
        return fn
    return deco


# -----------------------------------------------------------------------------------------------------------
# 1. ShatteredSkySpire: colossal twin jagged peaks split down the middle (~125 studs tall; scaled 1.65x = 206).
# -----------------------------------------------------------------------------------------------------------
@template("ShatteredSkySpire", STONE=11000, TRIM=4000, METAL=2800, ACCENT=1200, GLOW=1200)
def shattered_sky_spire(t):
    stone, trim, metal, accent, glow = (t.bm(r) for r in ("STONE", "TRIM", "METAL", "ACCENT", "GLOW"))
    # Broad craggy mountain shoulder base grounding both peaks cleanly.
    for k, (x, y, sx, sy, sz) in enumerate([
        (-28, 2, 26, 20, 28), (28, 3, 27, 21, 30), (-14, -4, 18, 16, 22), (14, -3, 18, 16, 22),
        (-42, 6, 18, 16, 18), (42, 5, 19, 16, 19), (0, 12, 24, 14, 16),
    ]):
        ground_rock(stone if k % 2 == 0 else trim, (sx, sy, sz), (x, y, -1.0), seed=3001 + k * 7, roughness=0.28, subdiv=2)

    # Twin soaring jagged peaks split cleanly down X = 0 by a dramatic vertical storm chasm.
    peaks = [
        # (side, base_x, top_x, height, base_r, seed)
        (-1, -18.5, -11.5, 125.0, 16.5, 3011),
        (1, 19.5, 12.5, 118.0, 16.0, 3023),
    ]
    for side, bx, tx, h, br, seed in peaks:
        rng = random.Random(seed)
        segs = 11
        pts = []
        rads = []
        for i in range(segs):
            f = i / (segs - 1)
            px = bx + (tx - bx) * (f ** 0.85) + side * math.sin(f * math.pi * 1.4) * 2.4
            py = math.sin(f * math.pi * 2.1 + side) * 2.2
            pz = f * h
            r = br * ((1 - f) ** 0.72) + (1.6 if f < 0.92 else 0.35)
            pts.append((px, py, pz))
            rads.append(r)
        # Main peak shaft with faceted craggy ribs.
        for i in range(segs - 1):
            p0, p1 = Vector(pts[i]), Vector(pts[i + 1])
            cone_along(stone, rads[i], rads[i + 1], p0, p1, 7)
        # Flanking buttress needles hugging the outer face of each peak.
        for k in range(3):
            fk = 0.22 + k * 0.22
            ox = bx + side * (9.5 - k * 2.2)
            oy = (-5.5 if k % 2 == 0 else 6.0)
            oh = h * (0.48 + k * 0.16)
            cone_along(trim, 8.2 - k * 1.4, 0.5, Vector((ox, oy, 0)), Vector((ox - side * 2.5, oy * 0.5, oh)), 6)
        # Jagged copper lightning-conductor straps & clamping rings bolted up the inner fissure wall.
        for k in range(4):
            fz = 0.22 + k * 0.19
            z = fz * h
            ix = (bx + (tx - bx) * fz) - side * (rads[min(segs - 1, int(fz * segs))] * 0.65)
            box(metal, (2.2, 4.2, 8.5), T((ix, -1.5, z)) @ R(side * 0.12, 4, "Y"))
            box(accent, (2.6, 4.6, 1.2), T((ix, -1.5, z + 3.2)))
            if k < 3:
                nz = (fz + 0.19) * h
                nix = (bx + (tx - bx) * (fz + 0.19)) - side * (rads[min(segs - 1, int((fz + 0.19) * segs))] * 0.65)
                strut(metal, (ix, -1.5, z), (nix, -1.5, nz), 0.75)

    # Electric white-violet lightning bolts crackling across the vertical chasm between the twin peaks!
    for k, z in enumerate([34, 54, 74, 94, 110]):
        rng = random.Random(3050 + k * 19)
        lx0, lx1 = -9.5 + k * 0.5, 10.5 - k * 0.5
        steps = 5
        prev = Vector((lx0, -2.5, z))
        for s in range(1, steps + 1):
            f = s / steps
            nx = lx0 + (lx1 - lx0) * f
            ny = -2.5 + (0 if s == steps else rng.uniform(-3.0, 3.0))
            nz = z + (0 if s == steps else rng.uniform(-4.5, 4.5))
            nxt = Vector((nx, ny, nz))
            strut(glow, prev, nxt, 0.55 if k % 2 == 0 else 0.42)
            prev = nxt


# -----------------------------------------------------------------------------------------------------------
# 2. LightningCrownArch: colossal curved copper-clad stone arch rib (~80 studs tall) with broken tip.
# -----------------------------------------------------------------------------------------------------------
@template("LightningCrownArch", STONE=4500, METAL=3600, ACCENT=1400, TRIM=1200, GLOW=600)
def lightning_crown_arch(t):
    stone, metal, accent, trim, glow = (t.bm(r) for r in ("STONE", "METAL", "ACCENT", "TRIM", "GLOW"))
    # Stepped granite plinth base (stands at origin; curves inward toward +X as it climbs in +Z).
    coursed_block(stone, 12.0, 12.0, 0.0, 14.0, 3071, course=2.4)
    box(trim, (13.4, 13.4, 2.0), T((0, 0, 14.2)))
    box(metal, (13.8, 13.8, 1.4), T((0, 0, 16.0)))
    # Sweeping curved stone-and-copper rib arching inward over +X up to Z ~78.
    segs = 14
    pts = []
    for i in range(segs):
        f = i / (segs - 1)
        ang = f * math.radians(68)
        cx = (1 - math.cos(ang)) * 42.0
        cz = 14.0 + math.sin(ang) * 68.0
        pts.append(Vector((cx, 0.0, cz)))
    for i in range(segs - 1):
        p0, p1 = pts[i], pts[i + 1]
        d = p1 - p0
        mid = (p0 + p1) * 0.5
        f = i / (segs - 1)
        w = 6.2 * (1 - f * 0.36)
        th = 5.4 * (1 - f * 0.32)
        m = T(mid) @ d.normalized().to_track_quat("Z", "Y").to_matrix().to_4x4()
        # Stone core + riveted hammered copper outer cladding + verdigris collar bands.
        box(stone, (w, th, d.length + 0.6), m)
        box(metal, (w + 1.1, th * 0.72, d.length * 0.78), m)
        if i % 2 == 1:
            box(accent, (w + 1.6, th + 1.0, 1.1), m @ T((0, 0, d.length * 0.35)))
    # Fractured jagged tip + glowing static lightning fork bursting from the broken rib end.
    tip = pts[-1]
    dir_end = (pts[-1] - pts[-2]).normalized()
    m_tip = T(tip) @ dir_end.to_track_quat("Z", "Y").to_matrix().to_4x4()
    cone_along(metal, 2.2, 0.3, tip, tip + dir_end * 5.2, 6)
    cone_along(trim, 1.4, 0.2, tip + Vector((0, 1.8, -1.2)), tip + dir_end * 4.0 + Vector((0, 2.4, -0.6)), 5)
    bolt(glow, Vector((0, 0, 0)), 9.5, 2.4, 0.36, T(tip + dir_end * 3.2) @ dir_end.to_track_quat("Z", "Y").to_matrix().to_4x4(), segs=4)


# -----------------------------------------------------------------------------------------------------------
# 3. EyrieNestRimSegment: giant tangled lightning-blasted pine logs lashed with braided rope/copper (~26x13x12).
# -----------------------------------------------------------------------------------------------------------
@template("EyrieNestRimSegment", WOOD=4200, ALT=1800, METAL=1000, STONE=2400, TRIM=900)
def eyrie_nest_rim_segment(t):
    wood, alt, metal, stone, trim = (t.bm(r) for r in ("WOOD", "ALT", "METAL", "STONE", "TRIM"))
    rng = random.Random(3091)
    # Stone parapet ledge cradling the woven nest logs.
    coursed_block(stone, 26.0, 7.2, 0.0, 4.6, 3092, course=1.5)
    # Giant horizontal & cross-woven storm-blasted timber trunks bristling outward (front = -Y).
    logs = [
        ((-13.6, -1.2, 4.6), (13.6, 0.6, 6.2), 1.9, 1.5),
        ((-13.2, 1.6, 6.4), (13.4, -0.8, 5.2), 1.6, 1.8),
        ((-12.8, -2.4, 7.6), (12.8, -0.4, 8.8), 1.5, 1.3),
        ((-11.8, 0.8, 8.6), (13.2, -2.2, 7.2), 1.4, 1.2),
        ((-12.2, -0.8, 10.2), (12.0, 1.0, 9.6), 1.25, 1.1),
    ]
    for p0, p1, r0, r1 in logs:
        cone_along(wood, r0, r1, Vector(p0), Vector(p1), 7)
    # Jagged cantilevered branch tips jutting outward toward the abyss (-Y) like a colossal bird's nest!
    for k in range(6):
        x = -10.5 + k * 4.2 + rng.uniform(-0.6, 0.6)
        z = rng.uniform(5.2, 9.8)
        yaw = rng.uniform(-0.45, 0.45)
        p0 = Vector((x, 1.8, z))
        p1 = Vector((x + math.sin(yaw) * 6.5, -5.8 - rng.uniform(0.4, 2.2), z + rng.uniform(0.5, 3.2)))
        cone_along(wood if k % 2 == 0 else trim, 1.15, 0.25, p0, p1, 6)
    # Thick diagonal braided hemp ropes & hammered copper straps lashing the nest rim together.
    for x in (-8.5, 0.0, 8.5):
        for k in range(3):
            ox = x + (k - 1) * 1.1
            ring_mesh(alt, 3.8, 0.52, 16, T((ox, -0.4, 7.4)) @ R(math.pi / 2, 4, "Y") @ R(0.28, 4, "Z"), tube_segs=5)
        ring_mesh(metal, 4.1, 0.34, 16, T((x, -0.4, 7.4)) @ R(math.pi / 2, 4, "Y"), tube_segs=5)


# -----------------------------------------------------------------------------------------------------------
# 4. EyePulpitBalustrade: circular stone-and-copper viewing pulpit parapet with south entry opening (~28 diam).
# -----------------------------------------------------------------------------------------------------------
@template("EyePulpitBalustrade", STONE=3800, METAL=3200, ACCENT=1200, TRIM=1200, GLOW=400)
def eye_pulpit_balustrade(t):
    stone, metal, accent, trim, glow = (t.bm(r) for r in ("STONE", "METAL", "ACCENT", "TRIM", "GLOW"))
    # Open at -Y (south entry from Crossing_EyePulpit causeway: angle around -pi/2 skipped by +/- 36 deg).
    R_OUT = 15.2
    segs = 28
    # Flat carved storm-compass inlay flush on the floor (z = 0.08).
    ring_mesh(metal, 8.2, 0.14, 24, T((0, 0, 0.1)), tube_segs=4)
    ring_mesh(accent, 4.2, 0.12, 20, T((0, 0, 0.1)), tube_segs=4)
    for k in range(8):
        a = k * math.pi / 4
        strut(metal if k % 2 == 0 else trim, (math.cos(a) * 1.4, math.sin(a) * 1.4, 0.12),
              (math.cos(a) * 11.2, math.sin(a) * 11.2, 0.12), 0.22)
    uvsphere(glow, 0.65, T((0, 0, 0.15)), 8, 6)
    # Circular stone drum collar + low parapet curb + hammered copper balustrade & vertical balusters.
    for k in range(segs):
        a0 = 2 * math.pi * k / segs
        a1 = 2 * math.pi * (k + 1) / segs
        am = (a0 + a1) * 0.5
        # Skip the south causeway opening (-Y = 3*pi/2 = -pi/2).
        da = abs(((am + math.pi / 2 + math.pi) % (2 * math.pi)) - math.pi)
        if da < math.radians(34):
            continue
        p0 = Vector((math.cos(a0) * R_OUT, math.sin(a0) * R_OUT, 0))
        p1 = Vector((math.cos(a1) * R_OUT, math.sin(a1) * R_OUT, 0))
        mid = (p0 + p1) * 0.5
        d = (p1 - p0).length
        rot = R(am + math.pi / 2, 4, "Z")
        # Stone base curb
        box(stone, (d + 0.35, 1.8, 1.6), T((mid.x, mid.y, 0.8)) @ rot)
        # Upper hammered copper top rail & mid rail
        strut(metal, p0 + Vector((0, 0, 4.4)), p1 + Vector((0, 0, 4.4)), 0.42)
        strut(accent, p0 + Vector((0, 0, 2.8)), p1 + Vector((0, 0, 2.8)), 0.22)
        # Vertical copper balusters (two per segment)
        for f in (0.25, 0.75):
            bp = p0.lerp(p1, f)
            cyl_z(metal if k % 2 == 0 else trim, 0.22, 2.8, (bp.x, bp.y, 1.6), segs=6)
    # Twin copper-capped stone entrance bollards flanking the south causeway gap.
    for side in (-1, 1):
        ea = -math.pi / 2 + side * math.radians(34)
        ex, ey = math.cos(ea) * R_OUT, math.sin(ea) * R_OUT
        cyl_z(stone, 1.35, 5.2, (ex, ey, 0), segs=10)
        ring_mesh(metal, 1.45, 0.28, 12, T((ex, ey, 3.6)), tube_segs=5)
        cone(accent, 1.4, 0.3, 1.1, 10, T((ex, ey, 5.2)))


# -----------------------------------------------------------------------------------------------------------
# 5. ColossalRocFeather: giant 32-stud metallic storm-bird primary feather impaled in cracked slate rock.
# -----------------------------------------------------------------------------------------------------------
@template("ColossalRocFeather", ALT=2600, METAL=1800, TRIM=1200, STONE=1400, GLOW=600)
def colossal_roc_feather(t):
    alt, metal, trim, stone, glow = (t.bm(r) for r in ("ALT", "METAL", "TRIM", "STONE", "GLOW"))
    # Cracked slate impact collar around the embedded quill base.
    for k in range(6):
        a = 2 * math.pi * k / 6
        ground_rock(stone, (3.2, 2.4, 2.2), (math.cos(a) * 2.1, math.sin(a) * 2.1, -0.3), seed=3121 + k, roughness=0.25, subdiv=1)
    # Slightly curved towering feather shaft (leaned slightly in +X for wind drama).
    segs = 12
    pts = []
    for i in range(segs):
        f = i / (segs - 1)
        pts.append(Vector((math.sin(f * math.pi * 0.7) * 3.2, math.sin(f * math.pi) * 0.9, f * 32.0)))
    for i in range(segs - 1):
        f = i / (segs - 1)
        cone_along(trim, 0.65 * (1 - f * 0.72), 0.65 * (1 - (f + 1 / segs) * 0.72), pts[i], pts[i + 1], 7)
    # Wide asymmetrical flight vanes with sleek overlapping feather barbs & copper leading edges.
    for i in range(2, segs - 1):
        f = (i + 0.5) / (segs - 1)
        taper = math.sin(min(1.0, (f - 0.14) / 0.86) * math.pi) ** 0.72
        w_l = 4.8 * taper
        w_r = 3.2 * taper
        notch = 0.72 if i in (5, 8) else 1.0
        p0, p1 = pts[i], pts[i + 1]
        seg_len = (p1 - p0).length
        mid = (p0 + p1) * 0.5
        d = (p1 - p0).normalized()
        m = T(mid) @ d.to_track_quat("Z", "Y").to_matrix().to_4x4()
        box(alt, (w_l * notch, 0.34, seg_len * 1.12), m @ T((-w_l * notch * 0.5, 0, 0)))
        box(alt, (w_r * notch, 0.34, seg_len * 1.12), m @ T((w_r * notch * 0.5, 0, 0)))
        # Burnished copper edge trim & subtle static glow vein along the quill.
        box(metal, (0.36, 0.42, seg_len * 1.08), m @ T((-w_l * notch, 0, 0)))
        box(metal, (0.30, 0.40, seg_len * 1.08), m @ T((w_r * notch, 0, 0)))
        if i % 2 == 0:
            strut(glow, p0 + Vector((-0.4, -0.22, 0)), p1 + Vector((-w_l * 0.55, -0.22, 0)), 0.14)
    # Tapered pointed feather tip crown.
    cone_along(alt, 1.4, 0.08, pts[-2], pts[-1] + Vector((0.3, 0, 2.2)), 6)


# -----------------------------------------------------------------------------------------------------------
# 6. GaleLanternTower: highland cliff watchtower (~34 studs tall) with pitched slate roof & glowing belfry.
# -----------------------------------------------------------------------------------------------------------
@template("GaleLanternTower", STONE=4200, TRIM=1800, METAL=1400, ACCENT=700, WOOD=800, GLOW=600)
def gale_lantern_tower(t):
    stone, trim, metal, accent, wood, glow = (t.bm(r) for r in ("STONE", "TRIM", "METAL", "ACCENT", "WOOD", "GLOW"))
    # Battered dry-stone square lower and mid shaft.
    coursed_block(stone, 12.4, 12.4, 0.0, 12.0, 3141, course=2.0)
    coursed_block(stone, 10.6, 10.6, 12.0, 11.0, 3142, course=1.9)
    # Copper corner quoins & stringcourse bands.
    box(metal, (11.6, 11.6, 0.8), T((0, 0, 12.0)))
    box(metal, (11.2, 11.2, 0.8), T((0, 0, 23.0)))
    # Open arched lantern belfry (four corner stone piers + glowing storm-lantern core).
    for sx in (-1, 1):
        for sy in (-1, 1):
            box(trim, (2.2, 2.2, 6.2), T((sx * 4.2, sy * 4.2, 26.1)))
    box(wood, (8.6, 8.6, 0.7), T((0, 0, 23.4)))
    uvsphere(glow, 2.2, T((0, 0, 26.4)), 10, 8)
    ring_mesh(metal, 2.9, 0.25, 16, T((0, 0, 26.4)), tube_segs=5)
    # Steep pitched pyramidal slate roof with copper ridge hips & lightning finial.
    cone(trim, 8.2, 0.5, 6.8, 4, T((0, 0, 29.2)) @ R(math.pi / 4, 4, "Z"))
    for k in range(4):
        a = k * math.pi / 2 + math.pi / 4
        strut(metal, (math.cos(a) * 8.2, math.sin(a) * 8.2, 29.2), (0, 0, 36.0), 0.32)
    cone(metal, 0.45, 0.04, 4.2, 6, T((0, 0, 35.8)))
    ring_mesh(accent, 1.3, 0.18, 12, T((0, 0, 37.6)), tube_segs=4)


# -----------------------------------------------------------------------------------------------------------
# 7. ObservatoryHall: Kairnfolk gabled stone highland hall/observatory (~24x16x18) beside the cliff tower.
# -----------------------------------------------------------------------------------------------------------
@template("ObservatoryHall", STONE=4200, TRIM=2200, METAL=1200, WOOD=1200, GLOW=600, MOSS=600)
def observatory_hall(t):
    stone, trim, metal, wood, glow, moss = (t.bm(r) for r in ("STONE", "TRIM", "METAL", "WOOD", "GLOW", "MOSS"))
    # Thick dry-stone rectangular hall with stepped side buttresses.
    coursed_block(stone, 22.0, 14.0, 0.0, 10.5, 3161, course=1.8)
    for sx in (-1, 1):
        for x in (-7.2, 0.0, 7.2):
            box(trim, (1.8, 1.8, 9.6), T((x, sx * 7.6, 4.8)))
    # Recessed glowing arched windows along front & back walls.
    for sy in (-1, 1):
        for x in (-4.8, 4.8):
            box(glow, (2.2, 0.4, 3.6), T((x, sy * 7.05, 5.4)))
            box(wood, (2.8, 0.6, 0.5), T((x, sy * 7.2, 3.4)))
    # Arched stone doorway on the west gable end (-X).
    box(trim, (1.2, 4.8, 6.2), T((-11.1, 0, 3.1)))
    box(wood, (0.6, 3.6, 5.4), T((-10.9, 0, 2.7)))
    # Gabled slate roof (two pitched roof slabs + stone gable triangles + copper ridge & storm-vane).
    for sy in (-1, 1):
        box(trim, (24.4, 10.2, 0.8), T((0, sy * 4.4, 13.6)) @ R(-sy * 0.64, 4, "X"))
    for sx in (-1, 1):
        for k in range(4):
            w = 13.2 - k * 3.1
            box(stone, (1.4, w, 1.65), T((sx * 10.4, 0, 11.2 + k * 1.6)))
    strut(metal, (-12.4, 0, 16.9), (12.4, 0, 16.9), 0.55)
    cone(metal, 0.35, 0.04, 4.0, 6, T((0, 0, 16.9)))
    box(metal, (3.2, 0.16, 1.2), T((1.2, 0, 19.6)))
    # Moss patches creeping up the foundation.
    for k, (x, y) in enumerate([(-9, -7.2), (8, -7.2), (-6, 7.2), (9, 7.2)]):
        ground_rock(moss, (3.6, 2.2, 1.4), (x, y, -0.2), seed=3166 + k, roughness=0.3, subdiv=1)


# -----------------------------------------------------------------------------------------------------------
# 8. ThresholdRuinArch: weathered foreground ruined stone archway & crumbled walls (~36x24x10).
# -----------------------------------------------------------------------------------------------------------
@template("ThresholdRuinArch", STONE=4800, TRIM=1800, METAL=700, MOSS=1000)
def threshold_ruin_arch(t):
    stone, trim, metal, moss = (t.bm(r) for r in ("STONE", "TRIM", "METAL", "MOSS"))
    # Twin battered arch piers with stepped broken side walls.
    for sx in (-1, 1):
        coursed_block(stone, 6.2, 7.2, 0.0, 14.0, 3181 + sx, course=1.8, cx=sx * 9.2)
        box(trim, (7.0, 7.8, 1.4), T((sx * 9.2, 0, 14.0)))
        # Crumbled flanking masonry wings stepping down outward.
        h_outer = 11.0 if sx < 0 else 8.4
        coursed_block(stone, 8.0, 4.2, 0.0, h_outer, 3184 + sx, course=1.8, cx=sx * 15.8, cy=0.8)
        ground_rock(moss, (4.8, 3.2, 1.6), (sx * 14.5, -2.0, -0.2), seed=3187 + sx, roughness=0.28, subdiv=1)
    # Semicircular stone voussoir arch (with one jagged weathered notch near the crown).
    segs = 11
    for k in range(segs):
        a = math.pi * (k + 0.5) / segs
        x = math.cos(a) * 9.2
        z = 14.0 + math.sin(a) * 8.6
        size_z = 2.6 if k != 5 else 3.2
        box(trim if k % 2 == 0 else stone, (3.2, 6.2, size_z), T((x, 0, z)) @ R(a - math.pi / 2, 4, "Y"))
    # Ruined upper parapet courses broken across the arch crown + copper tie-bars.
    for x, h in [(-10.2, 3.8), (-6.0, 2.2), (6.5, 2.8), (10.0, 4.0)]:
        box(stone, (4.2, 4.6, h), T((x, 0, 21.8 + h * 0.5 - (0.8 if abs(x) < 7 else 0))))
    strut(metal, (-9.0, 0, 14.5), (9.0, 0, 14.5), 0.3)


# -----------------------------------------------------------------------------------------------------------
# 9. AerieThresholdTotem: pointed conical stone-and-copper cliff beacon spire (~26 studs tall).
# -----------------------------------------------------------------------------------------------------------
@template("AerieThresholdTotem", STONE=2600, METAL=2000, ACCENT=800, TRIM=800, GLOW=400)
def aerie_threshold_totem(t):
    stone, metal, accent, trim, glow = (t.bm(r) for r in ("STONE", "METAL", "ACCENT", "TRIM", "GLOW"))
    # Stepped octagonal cairn plinth tapering cleanly into a tall copper-capped cliff beacon needle.
    cone(stone, 5.2, 4.4, 4.5, 8, T((0, 0, 0)))
    cone(trim, 4.5, 3.8, 1.0, 8, T((0, 0, 4.5)))
    cone(stone, 3.7, 2.1, 11.5, 8, T((0, 0, 5.5)))
    # Copper cladding rings & pointed finial needle.
    copper_rings(metal, accent, [(3.4, 8.5, 0.32), (2.9, 12.2, 0.3), (2.4, 15.8, 0.28)])
    cone(metal, 2.1, 0.14, 8.4, 8, T((0, 0, 17.0)))
    ring_mesh(accent, 1.5, 0.2, 14, T((0, 0, 21.2)), tube_segs=5)
    uvsphere(glow, 0.7, T((0, 0, 25.6)), 8, 6)


# -----------------------------------------------------------------------------------------------------------
# 10. FeatherHeartShrine: ceremonial shrine cradling a golden-violet feathered thunderheart (~15 studs tall).
# -----------------------------------------------------------------------------------------------------------
@template("FeatherHeartShrine", STONE=2400, METAL=1800, GOLD=1200, GLOW=600, CRYSTAL=500, ACCENT=600)
def feather_heart_shrine(t):
    stone, metal, gold, glow, crystal, accent = (t.bm(r) for r in ("STONE", "METAL", "GOLD", "GLOW", "CRYSTAL", "ACCENT"))
    # Stepped circular rune-carved slate plinth.
    cone(stone, 6.4, 5.8, 1.4, 14, T((0, 0, 0)))
    cone(stone, 4.6, 4.1, 1.6, 12, T((0, 0, 1.4)))
    ring_mesh(accent, 4.6, 0.24, 18, T((0, 0, 3.0)), tube_segs=5)
    # Three sweeping curved copper wing-ribs cradling the central thunderheart orb.
    for k in range(3):
        a = k * 2 * math.pi / 3
        rot = R(a, 4, "Z")
        pts = [rot @ Vector((3.2 + math.sin(f * math.pi) * 1.8, 0, 3.0 + f * 10.2)) for f in [0.0, 0.35, 0.7, 1.0]]
        for i in range(len(pts) - 1):
            cone_along(metal, 0.75 - i * 0.18, 0.58 - i * 0.16, pts[i], pts[i + 1], 6)
        # Feathered gold vane flaring from each wing-rib.
        box(gold, (1.8, 0.22, 4.2), rot @ T((4.8, 0, 8.8)) @ R(-0.25, 4, "Y"))
    # Glowing golden-violet thunderheart suspended in the cradle.
    uvsphere(crystal, 2.2, T((0, 0, 8.6)), 12, 10)
    uvsphere(glow, 1.3, T((0, 0, 8.6)), 10, 8)
    ring_mesh(gold, 2.8, 0.22, 18, T((0, 0, 8.6)) @ R(0.6, 4, "X"), tube_segs=5)
    ring_mesh(gold, 2.8, 0.22, 18, T((0, 0, 8.6)) @ R(-0.6, 4, "Y"), tube_segs=5)


# -----------------------------------------------------------------------------------------------------------
# 11. ShatteredCrownFragment: fallen broken chunk of a copper-clad crown arch buried in rock (~22x18x14).
# -----------------------------------------------------------------------------------------------------------
@template("ShatteredCrownFragment", STONE=3000, METAL=2200, ACCENT=900, TRIM=900, GLOW=500)
def shattered_crown_fragment(t):
    stone, metal, accent, trim, glow = (t.bm(r) for r in ("STONE", "METAL", "ACCENT", "TRIM", "GLOW"))
    # Cratered slate talus mound holding the crashed arch fragment.
    for k, (x, y, s) in enumerate([(-4, -2, 7.5), (5, 2, 7.0), (0, -5, 6.2), (-6, 4, 5.5)]):
        ground_rock(stone if k % 2 == 0 else trim, (s, s * 0.85, s * 0.65), (x, y, -0.4), seed=3211 + k, roughness=0.28, subdiv=1)
    # Leaning curved broken stone-and-copper arch rib thrusting up at 42 degrees.
    segs = 7
    pts = [Vector((-6.5 + f * 15.0, -1.0 + math.sin(f * math.pi) * 2.0, 2.0 + math.sin(f * math.pi * 0.65) * 14.5)) for f in [i / (segs - 1) for i in range(segs)]]
    for i in range(segs - 1):
        p0, p1 = pts[i], pts[i + 1]
        d = p1 - p0
        m = T((p0 + p1) * 0.5) @ d.normalized().to_track_quat("Z", "Y").to_matrix().to_4x4()
        box(stone, (4.8, 4.2, d.length + 0.4), m)
        box(metal, (5.5, 3.2, d.length * 0.75), m)
        if i % 2 == 1:
            box(accent, (5.8, 4.8, 0.9), m)
    bolt(glow, Vector((0, 0, 0)), 6.0, 2.0, 0.28, T(pts[-1]), segs=3)


# -----------------------------------------------------------------------------------------------------------
# 12. CalderaRibBones: colossal bleached mountain-beast ribcage & shattered spine (~24x14x16).
# -----------------------------------------------------------------------------------------------------------
@template("CalderaRibBones", TRIM=3600, STONE=2000, ALT=1200)
def caldera_rib_bones(t):
    trim, stone, alt = (t.bm(r) for r in ("TRIM", "STONE", "ALT"))
    # Slate scree bed.
    for k, (x, y) in enumerate([(-6, 0), (0, 2), (6, -1), (0, -3)]):
        ground_rock(stone, (6.5, 5.5, 2.8), (x, y, -0.3), seed=3231 + k, roughness=0.26, subdiv=1)
    # Curved vertebrae spine resting along X.
    for k in range(6):
        x = -9.0 + k * 3.6
        box(alt, (2.2, 2.6, 2.4), T((x, 0, 1.8)) @ R(0.1 * (k - 2.5), 4, "Z"))
    # Five pairs of huge curved bleached ribs arching skyward (some snapped short).
    for k in range(5):
        x = -7.6 + k * 3.8
        for sy in (-1, 1):
            segs = 6 if (k + (1 if sy > 0 else 0)) % 3 != 0 else 4
            prev = Vector((x, sy * 1.1, 1.8))
            for s in range(1, segs + 1):
                f = s / 6.0
                ang = f * math.radians(108)
                ny = sy * (1.2 + math.sin(ang) * 7.6)
                nz = 1.8 + (1 - math.cos(ang)) * 7.4
                nxt = Vector((x + math.sin(f * 2.0) * 0.4, ny, nz))
                cone_along(alt if s % 2 == 0 else trim, 0.85 * (1 - f * 0.55), 0.72 * (1 - f * 0.6), prev, nxt, 6)
                prev = nxt


# -----------------------------------------------------------------------------------------------------------
# 13. HangingAbyssChain: sweeping 42-stud catenary iron-and-copper chain span with tattered banners.
# -----------------------------------------------------------------------------------------------------------
@template("HangingAbyssChain", TRIM=2600, METAL=1600, ALT=1400, ACCENT=700)
def hanging_abyss_chain(t):
    trim, metal, alt, accent = (t.bm(r) for r in ("TRIM", "METAL", "ALT", "ACCENT"))
    # Chain runs along X from -21 to +21, anchored at Z = 18 at both ends and sagging down to Z = 8.4 at X = 0
    # so the lowest hanging banner tip stands cleanly above z = 0 (kit origin rule).
    span = 42.0
    segs = 20
    pts = []
    for i in range(segs + 1):
        f = i / segs
        x = (f - 0.5) * span
        sag = 4 * f * (1 - f)
        z = 18.0 - sag * 9.6
        pts.append(Vector((x, 0.0, z)))
    for i in range(segs):
        p0, p1 = pts[i], pts[i + 1]
        d = p1 - p0
        m = T((p0 + p1) * 0.5) @ d.normalized().to_track_quat("Z", "Y").to_matrix().to_4x4()
        # Alternating horizontal/vertical heavy forged chain links with occasional copper shackles.
        role = metal if i % 4 == 0 else trim
        ring_mesh(role, 0.95, 0.24, 10, m @ R(math.pi / 2 if i % 2 == 0 else 0, 4, "Z"), tube_segs=4)
    # Three weathered tattered Kairnfolk storm banners hung along the sagging chain!
    for idx, f in enumerate((0.26, 0.50, 0.74)):
        k = int(f * segs)
        p = pts[k]
        banner(alt, accent, trim, (p.x, 0.0, p.z - 0.6), 3.4, 7.8 if idx == 1 else 6.2, 3260 + idx * 13)


if __name__ == "__main__":
    kit, manifest = build_kit("ThunderF30Kit", F30_TEMPLATES, DEFAULT_BUDGET)
    export_kit(kit, manifest, OUT_DIR, "ThunderF30Kit")
    render_previews(kit, F30_TEMPLATES, OUT_DIR)
    print(json.dumps(manifest, indent=2))
