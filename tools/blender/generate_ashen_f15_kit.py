"""
Ashen Dunes Floor 15 (Colossus Dais) sculpted assets, generated in headless Blender
against the Caldera / Fallen Elder Colossus reference composition.

1 Blender unit = 1 stud, standing on z = 0, front facing -Y in Blender / +Z in Roblox,
one mesh object per colour role named "<Template>__<ROLE>".

Outputs (assets-source/tower/ashen_f15_kit/):
    AshenF15Kit.blend     the generated scene
    AshenF15Kit.fbx       FBX for File > Import 3D in Studio
    manifest.json         per template: roles, reference size, triangle counts
    previews/             Workbench contact-sheet render of the Floor 15 templates
"""
import bpy, bmesh, math, os, json, runpy
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT_DIR = os.path.join(ROOT, "assets-source", "tower", "ashen_f15_kit")

kit_mod = runpy.run_path(os.path.join(HERE, "generate_tower_biome_kit.py"), init_globals={"RUN_KIT": False})

Template = kit_mod["Template"]
M = kit_mod["M"]
box = kit_mod["box"]
cone = kit_mod["cone"]
lathe = kit_mod["lathe"]
uvsphere = kit_mod["uvsphere"]
tube = kit_mod["tube"]
rock = kit_mod["rock"]
reset_scene = kit_mod["reset_scene"]
finalize = kit_mod["finalize"]


def rock_clean(bm, size, mat, seed, roughness=0.22, subdiv=2, flat_bottom=True):
    tmp = bmesh.new()
    rock(tmp, size, mat, seed, roughness=roughness, subdiv=subdiv, flat_bottom=flat_bottom)
    vmap = [bm.verts.new(v.co) for v in tmp.verts]
    for f in tmp.faces:
        bm.faces.new([vmap[v.index] for v in f.verts])
    tmp.free()


def tapered_limb(bm, p0, p1, r0, r1, segs=7):
    """Add an octagonal tapered stone limb segment between p0 and p1."""
    d = Vector(p1) - Vector(p0)
    length = d.length
    if length < 1e-4:
        return
    q = d.normalized().to_track_quat("Z", "Y")
    mat = Matrix.Translation(p0) @ q.to_matrix().to_4x4()
    cone(bm, r0, r1, length, segs, mat)


def round_disc_sector(bm, radius, thick, a0, a1, steps, mat):
    """Build a thick chamfered pie-sector slab in local XY centered vertically on z=0."""
    top_center = bm.verts.new(mat @ Vector((0, 0, thick * 0.52)))
    bot_center = bm.verts.new(mat @ Vector((0, 0, -thick * 0.52)))
    top_ring, bot_ring = [], []
    for i in range(steps + 1):
        a = a0 + (a1 - a0) * (i / steps)
        x, y = math.cos(a) * radius, math.sin(a) * radius
        top_ring.append(bm.verts.new(mat @ Vector((x * 0.96, y * 0.96, thick * 0.5))))
        bot_ring.append(bm.verts.new(mat @ Vector((x, y, -thick * 0.5))))
    for i in range(steps):
        bm.faces.new([top_center, top_ring[i], top_ring[i + 1]])
        bm.faces.new([bot_center, bot_ring[i + 1], bot_ring[i]])
        bm.faces.new([top_ring[i], bot_ring[i], bot_ring[i + 1], top_ring[i + 1]])
    # Radial cut faces
    bm.faces.new([top_center, bot_center, bot_ring[0], top_ring[0]])
    bm.faces.new([top_center, top_ring[-1], bot_ring[-1], bot_center])


DEFAULT_BUDGET = 3500
F15_TEMPLATES = {}


def template(name, **budget):
    def deco(fn):
        F15_TEMPLATES[name] = (fn, budget)
        return fn
    return deco


@template("ElderHandFingers", STONE=1200, TRIM=2200, ALT=400, METAL=300, GLOW=250)
def elder_hand_fingers(t):
    """Giant weathered open stone hand with 5 curved articulated fingers fanning around the palm."""
    stone, trim, alt, metal, glow = t.bm("STONE"), t.bm("TRIM"), t.bm("ALT"), t.bm("METAL"), t.bm("GLOW")

    # Basalt crag & carved stone palm heel anchoring the fingers cleanly into terrain
    rock_clean(stone, (28.0, 15.0, 5.2), M((0.0, 3.0, 2.0)), seed=161, roughness=0.20, subdiv=2)
    box(trim, (42.0, 18.0, 4.0), M((0.0, 1.5, 2.2), rot=(0.06, 0.0, 0.0)), bevel=0.45)

    # 4 main fingers fanned along a curved palm knuckle arc + 1 heavy angled thumb on the right (+X)
    # Each finger curves upward & slightly inward (+Y) through 3 tapered octagonal phalanges
    fingers = [
        # (base_x, base_y, fan_yaw, scale_r, len1, len2, len3, tilt1, tilt2, tilt3)
        (-18.5, 3.5, -0.34, 3.4, 8.2, 6.8, 5.4, 0.30, 0.62, 0.96),   # Pinky
        (-7.2,  -1.0, -0.14, 3.9, 10.4, 8.4, 6.4, 0.24, 0.56, 0.92),  # Ring
        (5.2,   -2.2,  0.08, 4.1, 11.2, 8.8, 6.6, 0.22, 0.52, 0.88),  # Middle
        (16.8,   1.5,  0.28, 3.8, 9.8, 7.6, 5.8, 0.26, 0.58, 0.92),   # Index
    ]
    for idx, (bx, by, yaw, r, l1, l2, l3, a1, a2, a3) in enumerate(fingers):
        dx, dy = math.sin(yaw), math.cos(yaw)  # direction finger curls in XY (curving inward toward +Y / fan)
        # Base knuckle mound
        uvsphere(trim, r * 1.15, M((bx, by, 3.4)), u=8, v=5)
        p0 = Vector((bx, by, 3.2))
        p1 = p0 + Vector((dx * l1 * math.sin(a1), dy * l1 * math.sin(a1), l1 * math.cos(a1)))
        p2 = p1 + Vector((dx * l2 * math.sin(a2), dy * l2 * math.sin(a2), l2 * math.cos(a2)))
        p3 = p2 + Vector((dx * l3 * math.sin(a3), dy * l3 * math.sin(a3), l3 * math.cos(a3)))

        tapered_limb(trim, p0, p1, r * 1.05, r * 0.90, segs=8)
        tapered_limb(trim, p1, p2, r * 0.88, r * 0.74, segs=8)
        tapered_limb(trim, p2, p3, r * 0.72, r * 0.44, segs=7)
        # Dark stone nail plate & weathered bronze knuckle ring
        uvsphere(stone, r * 0.46, M(tuple(p3)), u=7, v=5)
        tapered_limb(metal, p1 - Vector((0, 0, 0.6)), p1 + Vector((0, 0, 0.8)), r * 0.96, r * 0.92, segs=8)
        if idx in (1, 2):
            box(glow, (1.1, 4.8, 1.4), M((bx, by + 2.2, 3.2), rot=(0, 0, yaw)), bevel=0.06)

    # Massive angled opposable thumb rising from the inner edge (+X, -Y)
    tb = Vector((24.5, -7.5, 3.0))
    tp1 = tb + Vector((4.8, 3.5, 8.2))
    tp2 = tp1 + Vector((1.2, 4.4, 7.0))
    uvsphere(trim, 4.8, M(tuple(tb)), u=8, v=5)
    tapered_limb(trim, tb, tp1, 4.4, 3.6, segs=8)
    tapered_limb(trim, tp1, tp2, 3.5, 2.3, segs=7)
    uvsphere(stone, 2.4, M(tuple(tp2)), u=7, v=5)
    box(alt, (7.6, 5.8, 1.8), M((24.8, -7.0, 4.8), rot=(0.2, 0.3, -0.5)), bevel=0.14)


@template("ElderShieldRim", STONE=1200, TRIM=1600, ALT=500, METAL=500, GLOW=300)
def elder_shield_rim(t):
    """Colossal ROUND cracked sandstone & basalt tower shield, split in two and tilted into the lava shore."""
    stone, trim, alt, metal, glow = t.bm("STONE"), t.bm("TRIM"), t.bm("ALT"), t.bm("METAL"), t.bm("GLOW")

    # Basalt caldera rock cradle grounding the tilted shield rim at z=0
    rock_clean(stone, (28.0, 14.0, 6.0), M((0.0, 0.0, 0.2)), seed=162, roughness=0.22, subdiv=2)

    # Tilted round shield split into two slightly shifted semicircular halves (~radius 23)
    tilt_x = 0.58   # leaning back ~33 deg
    base_center = Vector((0.0, 0.5, 19.2))

    # Right cracked half & Left cracked half (angled slightly apart along the center fissure)
    halves = [
        (-1, math.pi * 0.54, math.pi * 1.46, Vector((-1.4, -0.4, 0.3)), (tilt_x, -0.07, 0.06)),
        ( 1, -math.pi * 0.46, math.pi * 0.46, Vector((1.4, 0.4, -0.3)), (tilt_x,  0.07, -0.05)),
    ]
    for side, a0, a1, off, rot in halves:
        m = M(tuple(base_center + off), rot=rot) @ Matrix.Rotation(math.pi * 0.5, 4, "X")
        round_disc_sector(trim, 22.0, 3.4, a0, a1, 10, m)
        # Raised outer dark basalt armored rim collar on each half
        for k in range(5):
            ang = a0 + (a1 - a0) * ((k + 0.5) / 5.0)
            local_rim = Vector((math.cos(ang) * 21.4, math.sin(ang) * 21.4, -1.6))
            rm = m @ Matrix.Translation(local_rim) @ Matrix.Rotation(ang, 4, "Z")
            box(stone, (3.2, 8.8, 3.0), rm, bevel=0.22)
        # Radial terracotta rib bands across the shield face
        mid_a = (a0 + a1) * 0.5
        rib_m = m @ Matrix.Translation(Vector((math.cos(mid_a) * 12.5, math.sin(mid_a) * 12.5, -1.5))) @ Matrix.Rotation(mid_a, 4, "Z")
        box(alt, (13.0, 2.6, 2.2), rib_m, bevel=0.14)

    # Split hexagonal bronze central boss & molten fracture fissure running down the crack
    boss_m = M(tuple(base_center + Vector((0, -2.2, 0.4))), rot=(tilt_x - math.pi * 0.5, 0, 0))
    cone(metal, 6.8, 4.2, 3.2, 6, boss_m)
    cone(glow, 2.6, 0.8, 4.0, 6, boss_m)
    box(glow, (1.8, 3.8, 34.0), M(tuple(base_center + Vector((0, -0.2, 0.0))), rot=(tilt_x, 0.04, 0.12)), bevel=0.06)


@template("ElderColossusHead", STONE=1100, TRIM=1800, ALT=500, METAL=300, GLOW=250)
def elder_colossus_head(t):
    """Weathered carved stone Elder Colossus head resting on its cheek with brow, eyes, nose & beard ridges."""
    stone, trim, alt, metal, glow = t.bm("STONE"), t.bm("TRIM"), t.bm("ALT"), t.bm("METAL"), t.bm("GLOW")

    rock_clean(stone, (20.0, 20.0, 6.2), M((0.0, 0.0, 0.0)), seed=163, roughness=0.22, subdiv=2)

    # Tilted head lying semi-upright / rolled onto its cheek, facing -Y / +X toward the caldera
    rot = (-0.48, 0.58, -0.32)
    c = Vector((0.0, 0.0, 15.2))

    def hp(bm, fn_kind, *args, local_off=Vector((0, 0, 0)), local_rot=(0, 0, 0)):
        m = M(tuple(c), rot=rot) @ Matrix.Translation(local_off) @ Matrix.Rotation(local_rot[2], 4, "Z") @ Matrix.Rotation(local_rot[1], 4, "Y") @ Matrix.Rotation(local_rot[0], 4, "X")
        if fn_kind == "box":
            box(bm, args[0], m, bevel=args[1] if len(args) > 1 else 0.25)
        elif fn_kind == "cone":
            cone(bm, args[0], args[1], args[2], args[3], m)

    # Sculpted octagonal cranium + tapered lower jaw/chin
    hp(trim, "cone", 10.6, 8.8, 17.0, 8, local_off=Vector((0, 0, 0.5)))
    hp(trim, "cone", 8.8, 6.2, 9.0, 8, local_off=Vector((0, -0.8, -11.0)))
    # Heavy overhanging carved brow plate + cheekbone ledges
    hp(alt, "box", (18.4, 5.4, 4.4), 0.22, local_off=Vector((0, -7.2, 6.5)))
    hp(trim, "box", (4.0, 4.6, 8.5), 0.25, local_off=Vector((0, -9.2, 1.4)), local_rot=(-0.18, 0, 0))
    for side in (-1, 1):
        hp(stone, "box", (4.2, 9.2, 12.0), 0.22, local_off=Vector((side * 8.6, -2.0, 1.0)))
        hp(trim, "box", (5.8, 4.2, 3.6), 0.20, local_off=Vector((side * 4.8, -7.4, -0.8)))
        # Deep recessed dying-ember eye sockets under the brow
        hp(glow, "box", (3.6, 2.2, 1.5), 0.05, local_off=Vector((side * 4.5, -7.8, 3.6)))
    # Stepped carved stone beard ribs + bronze chin band
    hp(metal, "box", (11.6, 4.6, 5.2), 0.18, local_off=Vector((0, -7.2, -7.8)))
    hp(stone, "cone", 10.0, 9.2, 4.2, 8, local_off=Vector((0, 0.5, 11.5)))


@template("ElderCrownRing", STONE=1000, TRIM=1800, ALT=600, METAL=400, GLOW=250)
def elder_crown_ring(t):
    """Toppled sweeping semicircular sandstone crown of sharp radiating spikes."""
    stone, trim, alt, metal, glow = t.bm("STONE"), t.bm("TRIM"), t.bm("ALT"), t.bm("METAL"), t.bm("GLOW")

    rock_clean(stone, (28.0, 14.0, 5.2), M((0.0, 0.0, 2.4)), seed=164, roughness=0.22, subdiv=2)

    # Sweeping curved stone circlet ring with 9 tall splayed crown spikes
    n_pts = 9
    radius = 25.0
    tilt_x = 0.28
    for i in range(n_pts):
        ang = -math.pi * 0.46 + (i / (n_pts - 1)) * (math.pi * 0.92)
        px = math.sin(ang) * radius
        py = -math.cos(ang) * radius * 0.42 + 4.0
        h_spike = 15.0 + (4.2 if i % 2 == 0 else 0.0) + (3.0 if i == 4 else 0.0)
        m_base = M((px, py, 3.2), rot=(tilt_x, 0, -ang))
        box(stone, (7.6, 5.4, 5.2), m_base, bevel=0.20)
        # Tall hexagonal sandstone crown spire flaring outward radially
        m_spire = M((px, py, 5.2), rot=(tilt_x + 0.16, math.sin(ang) * 0.22, -ang))
        cone(trim, 3.5, 0.85, h_spike, 6, m_spire)
        cone(alt, 2.9, 2.5, 2.0, 6, M((px, py, 5.2 + h_spike * 0.34), rot=(tilt_x + 0.16, math.sin(ang) * 0.22, -ang)))
        if i % 2 == 0:
            box(metal, (2.2, 3.8, 3.4), M((px, py, 5.2 + h_spike * 0.62), rot=(tilt_x + 0.16, math.sin(ang) * 0.22, -ang)), bevel=0.08)
            box(glow, (1.0, 4.1, 2.2), M((px, py, 5.2 + h_spike * 0.48), rot=(tilt_x + 0.16, math.sin(ang) * 0.22, -ang)), bevel=0.04)


@template("ElderShoulderPauldron", STONE=1200, TRIM=1400, ALT=400, METAL=300, GLOW=200)
def elder_shoulder_pauldron(t):
    """Curved domed stone Shoulder Pauldron flanked by stepped hexagonal basalt columns."""
    stone, trim, alt, metal, glow = t.bm("STONE"), t.bm("TRIM"), t.bm("ALT"), t.bm("METAL"), t.bm("GLOW")

    # Stepped hexagonal basalt column organ-pipes rising behind the pauldron edge
    col_specs = [
        (-18.0,  6.0, 34.0, 3.4),
        (-13.5,  8.5, 44.0, 3.8),
        (-8.0,  10.0, 52.0, 4.0),
        (-2.5,  11.0, 46.0, 3.6),
        (-15.5,  1.5, 26.0, 3.2),
        (-10.0,  3.5, 32.0, 3.4),
        (16.0,   6.0, 28.0, 3.4),
    ]
    for cx, cy, ch, cr in col_specs:
        cone(stone, cr, cr * 0.94, ch, 6, M((cx, cy, -0.1)))

    # Domed layered sandstone Shoulder Pauldron shell curving down toward the caldera
    rock_clean(stone, (22.0, 15.0, 5.5), M((4.0, -2.0, 2.4)), seed=165, roughness=0.20, subdiv=2)
    for tier, (rad, thick, z_off, y_off, rot_x) in enumerate((
        (18.5, 4.6, 10.5, -2.0, 0.34),
        (14.8, 4.2, 16.0,  0.5, 0.22),
        (10.5, 3.6, 20.5,  2.5, 0.12),
    )):
        m = M((4.5, y_off, z_off), rot=(rot_x, -0.25, 0.15)) @ Matrix.Rotation(math.pi * 0.5, 4, "X")
        round_disc_sector(trim if tier != 1 else alt, rad, thick, -math.pi * 0.15, math.pi * 1.15, 10, m)
    # Bronze pauldron ridge strap & ember fissure seam
    box(metal, (24.0, 3.2, 2.8), M((4.5, -4.5, 15.5), rot=(0.28, -0.25, 0.15)), bevel=0.14)
    box(glow, (14.0, 1.4, 2.0), M((4.5, -5.5, 12.2), rot=(0.30, -0.25, 0.15)), bevel=0.04)


@template("CinderholdVent", STONE=1600, TRIM=1000, ALT=500, METAL=300, GLOW=450)
def cinderhold_vent(t):
    """Conical volcanic caldera throat flanked by basalt spire ridges, ruined colonnades, and glowing magma column."""
    stone, trim, alt, metal, glow = t.bm("STONE"), t.bm("TRIM"), t.bm("ALT"), t.bm("METAL"), t.bm("GLOW")

    # Wide jagged caldera cone base & flanking hexagonal basalt cliffs
    cone(stone, 42.0, 19.0, 44.0, 10, M((0.0, 8.0, -0.2)))
    rock_clean(stone, (38.0, 20.0, 10.0), M((0.0, 2.0, 4.8)), seed=166, roughness=0.22, subdiv=2)

    # Ring of dark jagged caldera peaks behind the blazing vent mouth
    for sx, sy, sh, rad, lean in (
        (-36.0, -2.0, 56.0, 9.5,  0.14),
        (-22.0,  9.0, 74.0, 11.0, 0.08),
        (-8.0,  14.0, 88.0, 11.5, 0.02),
        (10.0,  13.0, 84.0, 11.0,-0.04),
        (24.0,   8.0, 70.0, 10.5,-0.10),
        (37.0,  -3.0, 52.0, 9.0, -0.15),
    ):
        cone(stone, rad, rad * 0.34, sh, 6, M((sx, sy, 0.0), rot=(-0.08, lean, 0.0)))
        cone(alt, rad * 0.78, rad * 0.52, sh * 0.38, 6, M((sx * 0.94, sy - 2.0, 0.0), rot=(-0.06, lean, 0.0)))

    # Ruined sandstone & bronze colonnade temple wings framing left & right flanks of the vent (like the reference dais)
    for side in (-1, 1):
        base_x = side * 32.0
        box(stone, (18.0, 9.0, 6.0), M((base_x, -9.0, 3.0)), bevel=0.16)
        for c_idx in range(3):
            cx = base_x + (c_idx - 1) * 6.0
            ch = 24.0 if c_idx != 1 else 26.5
            cone(trim, 1.8, 1.5, ch, 8, M((cx, -9.0, 5.8)))
        box(trim, (17.5, 4.2, 2.6), M((base_x, -9.0, 30.8)), bevel=0.12)
        box(alt, (18.2, 4.6, 1.4), M((base_x, -9.0, 32.8)), bevel=0.08)

    # Blazing magma eruption column & caldera lava fissures
    cone(glow, 13.0, 7.2, 92.0, 8, M((0.0, 6.0, 8.0)))
    for ang in (-0.48, 0.0, 0.48):
        box(glow, (2.2, 3.4, 52.0), M((math.sin(ang) * 16.0, -4.0, 26.0), rot=(0.24, ang * 0.3, 0.0)), bevel=0.05)
    for side in (-1, 1):
        box(metal, (9.0, 4.8, 10.0), M((side * 15.0, -9.5, 6.0), rot=(0.15, side * 0.2, 0)), bevel=0.12)


@template("CalderaDragonCorpse", STONE=1000, TRIM=2400, GLOW=350)
def caldera_dragon_corpse(t):
    """Colossal half-submerged Ash-Dragon skeleton lying in the molten caldera lake."""
    stone, trim, glow = t.bm("STONE"), t.bm("TRIM"), t.bm("GLOW")

    # Charred basalt magma crust island under the ribcage & skull
    rock_clean(stone, (30.0, 46.0, 4.2), M((0.0, 0.0, -0.1)), seed=167, roughness=0.24, subdiv=2)
    box(glow, (11.0, 22.0, 1.4), M((0.0, -2.0, 1.2)), bevel=0.1)

    # Horned Dragon Skull at front (-Y) resting tilted on the basalt crust
    skull_c = Vector((-2.0, -24.0, 5.2))
    s_rot = (-0.18, 0.14, 0.22)
    sm = M(tuple(skull_c), rot=s_rot)
    cone(trim, 6.2, 2.4, 15.5, 6, sm @ Matrix.Rotation(math.pi * 0.5, 4, "X"))  # snout pointing -Y
    box(trim, (11.5, 8.5, 6.4), sm @ Matrix.Translation(Vector((0, 4.0, 0.8))), bevel=0.25)  # cranium
    box(trim, (6.5, 11.0, 2.4), sm @ Matrix.Translation(Vector((0.6, -2.5, -3.4))) @ Matrix.Rotation(0.24, 4, "X"), bevel=0.16)  # lower jaw
    for side in (-1, 1):
        # Sweeping obsidian-tipped dragon horns curving backward (+Y) and upward
        h0 = sm @ Vector((side * 4.4, 5.5, 2.8))
        h1 = sm @ Vector((side * 7.8, 12.0, 7.6))
        h2 = sm @ Vector((side * 9.5, 19.5, 11.2))
        tapered_limb(trim, h0, h1, 2.1, 1.4, segs=6)
        tapered_limb(stone, h1, h2, 1.4, 0.35, segs=6)
        box(glow, (1.8, 2.2, 1.5), sm @ Matrix.Translation(Vector((side * 3.8, 0.5, 1.4))), bevel=0.05)

    # Sinuous arched vertebrae spine + dorsal ridges curving through the lava lake (y=-18..+28)
    spine_pts = []
    for k in range(11):
        u = k / 10.0
        sy = -17.0 + u * 45.0
        sx = math.sin(u * math.pi * 1.45) * 7.5
        sz = 2.6 + math.sin(u * math.pi * 0.92) * 6.2
        spine_pts.append(Vector((sx, sy, sz)))
    for k in range(len(spine_pts) - 1):
        p0, p1 = spine_pts[k], spine_pts[k + 1]
        r = 2.6 - (k / len(spine_pts)) * 1.4
        tapered_limb(trim, p0, p1, r, r * 0.9, segs=6)
        # Jagged obsidian dorsal fin spikes along the spine
        cone(stone, 1.2, 0.3, 4.2 - k * 0.2, 5, M(tuple((p0 + p1) * 0.5 + Vector((0, 0, r * 0.6))), rot=(-0.25, 0, 0)))

    # 6 pairs of massive arched rib bones curving out of the glowing magma heart pool
    for r_idx in range(6):
        sp = spine_pts[r_idx + 1]
        span = 11.5 + math.sin((r_idx / 5.0) * math.pi) * 6.5
        h_arc = 10.5 + math.sin((r_idx / 5.0) * math.pi) * 4.5
        for side in (-1, 1):
            rp0 = sp
            rp1 = Vector((sp.x + side * span * 0.72, sp.y - 1.0, sp.z + h_arc * 0.45))
            rp2 = Vector((sp.x + side * span, sp.y - 2.2, 1.2))
            tapered_limb(trim, rp0, rp1, 1.65, 1.25, segs=6)
            tapered_limb(trim, rp1, rp2, 1.25, 0.65, segs=6)

    # Two asymmetric skeletal dragon wing spars rising from the shoulder region
    wing_specs = [
        (-1, Vector((-5.0, -8.0, 7.2)), Vector((-19.0, -2.0, 21.0)), Vector((-30.0, 9.0, 14.0)), -1.0),
        ( 1, Vector(( 5.0, -6.0, 7.2)), Vector(( 16.0,  2.0, 15.5)), Vector(( 25.0, 12.0, 2.5)),  1.0),
    ]
    for _, w0, w1, w2, side in wing_specs:
        tapered_limb(trim, w0, w1, 2.0, 1.3, segs=6)
        tapered_limb(trim, w1, w2, 1.3, 0.7, segs=6)
        for f in range(3):
            tip = w1 + Vector((side * (9.0 + f * 3.5), 6.0 + f * 5.0, -4.0 - f * 3.5))
            tapered_limb(stone, w1, tip, 0.85, 0.28, segs=5)


def build_f15():
    reset_scene()
    kit = bpy.data.collections.new("AshenF15Kit")
    bpy.context.scene.collection.children.link(kit)
    manifest = {}
    for name, (fn, budget) in F15_TEMPLATES.items():
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
            obj, tris = finalize(name, role, bm, budget.get(role, DEFAULT_BUDGET), coll)
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


def export_f15(kit, manifest):
    os.makedirs(OUT_DIR, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    objs = [o for o in kit.all_objects if o.type == "MESH"]
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.fbx(
        filepath=os.path.join(OUT_DIR, "AshenF15Kit.fbx"),
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
    with open(os.path.join(OUT_DIR, "manifest.json"), "w") as f:
        json.dump({"Templates": manifest, "Unit": "studs", "Front": "-Y in Blender, +Z in Roblox"}, f, indent=2, sort_keys=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT_DIR, "AshenF15Kit.blend"))


if __name__ == "__main__":
    kit, manifest = build_f15()
    export_f15(kit, manifest)
    preview_dir = os.path.join(OUT_DIR, "previews")
    tiles = os.path.join(preview_dir, "tiles")
    os.makedirs(tiles, exist_ok=True)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.color_type = "MATERIAL"
    lc = next(c for c in bpy.context.view_layer.layer_collection.children if c.collection == kit)
    lc.exclude = True
    stage = bpy.data.collections.new("PreviewStage")
    scene.collection.children.link(stage)
    cam = bpy.data.objects.new("PreviewCam", bpy.data.cameras.new("PreviewCam"))
    stage.objects.link(cam)
    scene.camera = cam
    scene.render.resolution_x = scene.render.resolution_y = 520
    tile_imgs = []
    for n in F15_TEMPLATES:
        c = bpy.data.collections[n]
        lo = Vector((1e9,) * 3)
        hi = Vector((-1e9,) * 3)
        for o in c.objects:
            for v in o.data.vertices:
                lo = Vector(map(min, lo, v.co))
                hi = Vector(map(max, hi, v.co))
        e = bpy.data.objects.new("PreviewInstance", None)
        e.instance_type = "COLLECTION"
        e.instance_collection = c
        stage.objects.link(e)
        size = max(hi - lo)
        ctr = (lo + hi) / 2
        cam.location = ctr + Vector((0.55, -1.0, 0.42)).normalized() * size * 1.9
        cam.rotation_euler = (ctr - cam.location).to_track_quat("-Z", "Y").to_euler()
        p_path = os.path.join(tiles, n + ".png")
        scene.render.filepath = p_path
        bpy.ops.render.render(write_still=True)
        bpy.data.objects.remove(e, do_unlink=True)
        tile_imgs.append(bpy.data.images.load(p_path))
    import numpy as np
    n_templates = len(F15_TEMPLATES)
    sheet = bpy.data.images.new("PreviewSheet", width=520 * n_templates, height=520, alpha=True)
    buf = np.zeros((520, 520 * n_templates, 4), dtype=np.float32)
    for idx, img in enumerate(tile_imgs):
        arr = np.asarray(img.pixels[:], dtype=np.float32).reshape(520, 520, 4)
        buf[:, idx * 520:(idx + 1) * 520, :] = arr
        bpy.data.images.remove(img)
    sheet.pixels.foreach_set(buf.ravel())
    sheet.filepath_raw = os.path.join(preview_dir, "kit_sheet_1.png")
    sheet.file_format = "PNG"
    sheet.save()
    bpy.data.images.remove(sheet)
    print(json.dumps(manifest, indent=2))
