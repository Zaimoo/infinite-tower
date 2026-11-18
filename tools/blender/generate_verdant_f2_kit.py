"""
Verdant Ruins Floor 2 (Broken Aqueduct) sculpted assets, generated in headless Blender.

Reuses the mesh helpers and role conventions of `tools/blender/generate_tower_biome_kit.py`
(1 Blender unit = 1 stud, standing on z = 0, front facing -Y in Blender / +Z in Roblox,
one mesh object per colour role named "<Template>__<ROLE>").

Outputs (assets-source/tower/verdant_f2_kit/):
    VerdantF2Kit.blend    the generated scene
    VerdantF2Kit.fbx      FBX for File > Import 3D in Studio
    manifest.json         per template: roles, reference size, triangle counts
    previews/             contact-sheet render of the 5 Floor 2 templates
"""
import bpy, bmesh, math, os, json, random, runpy
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT_DIR = os.path.join(ROOT, "assets-source", "tower", "verdant_f2_kit")

# Load helper primitives from generate_tower_biome_kit without running its main build.
kit_mod = runpy.run_path(os.path.join(HERE, "generate_tower_biome_kit.py"), init_globals={"RUN_KIT": False})

Template = kit_mod["Template"]
M = kit_mod["M"]
box = kit_mod["box"]
cone = kit_mod["cone"]
ico = kit_mod["ico"]
uvsphere = kit_mod["uvsphere"]
lathe = kit_mod["lathe"]
tube = kit_mod["tube"]
branch_path = kit_mod["branch_path"]
subdivide = kit_mod["subdivide"]
displace = kit_mod["displace"]
rock = kit_mod["rock"]
ring_mesh = kit_mod["ring_mesh"]
_canopy_blob = kit_mod["_canopy_blob"]
reset_scene = kit_mod["reset_scene"]
finalize = kit_mod["finalize"]
render_previews = kit_mod["render_previews"]


def rock_clean(bm, size, mat, seed, roughness=0.22, subdiv=2, flat_bottom=True):
    """Build a displaced boulder in a fresh bmesh so prior bevel ops cannot corrupt vertex tracking."""
    tmp = bmesh.new()
    rock(tmp, size, mat, seed, roughness=roughness, subdiv=subdiv, flat_bottom=flat_bottom)
    vmap = [bm.verts.new(v.co) for v in tmp.verts]
    for f in tmp.faces:
        bm.faces.new([vmap[v.index] for v in f.verts])
    tmp.free()


DEFAULT_BUDGET = 3500
F2_TEMPLATES = {}


def template(name, **budget):
    def deco(fn):
        F2_TEMPLATES[name] = (fn, budget)
        return fn
    return deco


@template("Waterwheel", WOOD=1800, TRIM=1000, METAL=500, MOSS=600, FOLIAGE=500)
def waterwheel(t):
    """Weathered wooden & iron-rimmed Solmere waterwheel in a ruined masonry cradle, choked by Heartroot roots."""
    rng = t.rng
    wood, trim, metal, moss, foliage = t.bm("WOOD"), t.bm("TRIM"), t.bm("METAL"), t.bm("MOSS"), t.bm("FOLIAGE")

    # Ruined stone mill cradle & sluice wall behind the wheel (+Y side)
    box(trim, (19.0, 4.4, 2.2), M((0, 3.6, 1.1)), bevel=0.18)
    box(trim, (15.5, 3.8, 12.0), M((1.2, 3.6, 8.2)), bevel=0.20)
    # Stepped ruined wall crest & sluice abutment on +X
    box(trim, (7.5, 4.0, 5.5), M((5.2, 3.6, 16.5)), bevel=0.18)
    box(trim, (5.0, 4.4, 1.2), M((5.8, 3.2, 19.6)), bevel=0.12)
    # Stone sluice trough overhanging the top-right of the wheel
    box(trim, (6.5, 4.8, 1.4), M((5.8, -0.6, 19.2), rot=(0, -0.14, 0)), bevel=0.12)
    # Low stone axle pier in front-left
    box(trim, (3.4, 3.4, 14.2), M((0, -4.8, 7.1)), bevel=0.18)

    # Moss cushions along wall ledges and pier top
    for pos, sz, sd in (
        ((5.5, 3.2, 20.3), (5.2, 4.0, 1.4), 1),
        ((-3.5, 3.5, 14.3), (6.5, 3.6, 1.4), 2),
        ((0, -4.8, 14.3), (3.8, 3.6, 1.3), 3),
        ((-7.5, 3.5, 2.3), (4.5, 4.0, 1.2), 4),
    ):
        rock(moss, sz, M(pos), sd, roughness=0.25, subdiv=2)

    # Wheel geometry in X-Z plane centered at (0, -1.4, 13.5), axle along Y
    cx, cy, cz = 0.0, -1.4, 13.5
    r_outer, r_inner = 11.8, 9.2
    wheel_rot = M((cx, cy, cz), rot=(math.pi / 2, 0, 0))

    # Heavy timber axle & hub
    cone(wood, 1.35, 1.35, 9.2, 10, M((cx, cy - 4.2, cz), rot=(-math.pi / 2, 0, 0)))
    cone(wood, 2.5, 2.5, 3.6, 12, M((cx, cy - 1.8, cz), rot=(-math.pi / 2, 0, 0)))
    ring_mesh(metal, 2.55, 0.35, 14, M((cx, cy - 1.4, cz), rot=(math.pi / 2, 0, 0)), tube_segs=5)
    ring_mesh(metal, 2.55, 0.35, 14, M((cx, cy + 1.4, cz), rot=(math.pi / 2, 0, 0)), tube_segs=5)

    # Double wooden rims & outer iron straps
    for y_off in (-1.35, 1.35):
        rm = M((cx, cy + y_off, cz), rot=(math.pi / 2, 0, 0))
        ring_mesh(wood, r_outer, 0.58, 20, rm, tube_segs=4)
        ring_mesh(wood, r_inner, 0.45, 20, rm, tube_segs=4)
        ring_mesh(metal, r_outer + 0.52, 0.18, 20, rm, tube_segs=4)

    # 8 radial spokes & 16 angled wooden paddles
    for k in range(8):
        a = k * math.pi / 4 + 0.18
        for y_off in (-1.35, 1.35):
            sx = cx + math.cos(a) * (r_outer * 0.5)
            sz = cz + math.sin(a) * (r_outer * 0.5)
            box(wood, (r_outer * 0.96, 0.65, 0.72), M((sx, cy + y_off, sz), rot=(0, -a, 0)), bevel=0.06)

    for k in range(16):
        a = k * math.pi / 8 + 0.08
        rm_r = (r_outer + r_inner) * 0.5
        px = cx + math.cos(a) * rm_r
        pz = cz + math.sin(a) * rm_r
        box(wood, (2.6, 3.1, 0.42), M((px, cy, pz), rot=(0, -(a + 0.35), 0)), bevel=0.05)

    # Moss draped over the top arc of the wheel
    for k in (3, 4, 5):
        a = k * math.pi / 8 + 0.08
        mx = cx + math.cos(a) * (r_outer + 0.3)
        mz = cz + math.sin(a) * (r_outer + 0.3)
        rock(moss, (2.6, 3.6, 1.2), M((mx, cy, mz), rot=(0, -a + math.pi / 2, 0)), 10 + k, roughness=0.28, subdiv=2)

    # Heartroot feeder roots coiling from the ground up through the spokes & around the masonry
    root_paths = [
        [(-8.5, -2.5, 0.0), (-6.2, -2.8, 4.5), (-3.8, -3.1, 9.2), (-2.0, -3.2, 14.0), (-4.5, -2.8, 19.5)],
        [(7.5, -2.2, 0.0), (5.4, -2.9, 5.2), (3.5, -3.2, 10.5), (5.8, -2.2, 15.8), (8.2, 1.2, 18.6)],
        [(-10.5, 1.5, 0.0), (-9.0, 2.2, 6.0), (-6.8, 1.6, 11.5), (-3.2, 1.2, 15.0)],
        [(9.2, 2.2, 0.0), (8.6, 1.8, 8.0), (6.5, 1.2, 14.5), (3.0, 1.8, 18.2)],
        [(-3.2, -3.4, 0.0), (-2.2, -3.5, 5.5), (0.6, -3.4, 10.5), (3.8, -3.1, 13.8)],
    ]
    for pts in root_paths:
        radii = [1.05, 0.86, 0.68, 0.48, 0.28][:len(pts)]
        tube(wood, pts, radii, 6)
        # Hanging vine leaf tufts near upper root bends
        _canopy_blob(foliage, pts[-1], (2.8, 2.4, 2.2), rng.randint(1, 99), subdiv=1)


@template("AqueductBrokenSpan", TRIM=1600, ACCENT=400, MOSS=600, WOOD=700)
def aqueduct_broken_span(t):
    """Jagged snapped stone end of the Solmere aqueduct with verdigris cornice, water trough & feeder roots."""
    trim, accent, moss, wood = t.bm("TRIM"), t.bm("ACCENT"), t.bm("MOSS"), t.bm("WOOD")

    # Twin back piers standing at y = +3.5 (deck top at z = 14.0)
    for sx in (-1, 1):
        box(trim, (4.8, 5.2, 1.8), M((sx * 8.2, 3.8, 0.9)), bevel=0.16)
        box(trim, (3.8, 4.2, 11.4), M((sx * 8.2, 3.8, 7.2)), bevel=0.14)
        box(trim, (4.6, 5.0, 1.4), M((sx * 8.2, 3.8, 12.6)), bevel=0.12)

    # Intact rear arch crown & deck slab spanning between the piers and cantilevering forward (-Y)
    box(trim, (20.4, 10.5, 1.8), M((0, 1.8, 13.1)), bevel=0.14)
    # Fractured staggered deck extension overhanging toward -Y (snapped unevenly!)
    box(trim, (11.5, 6.2, 1.7), M((-3.8, -4.6, 13.05), rot=(0.04, 0, 0.06)), bevel=0.15)
    box(trim, (7.8, 4.5, 1.5), M((4.6, -3.4, 13.0), rot=(0.06, 0, -0.05)), bevel=0.15)

    # Half-arch springing forward from each pier into the gap
    for sx in (-1, 1):
        for step, (dy, dz, pitch) in enumerate(((-1.2, 10.4, 0.35), (-3.4, 11.7, 0.72), (-5.8, 12.3, 1.1))):
            if sx > 0 and step == 2:
                continue  # asymmetric break!
            box(trim, (3.4, 2.8, 2.2), M((sx * 8.2, 2.5 + dy, dz), rot=(pitch, 0, 0)), bevel=0.12)

    # Twin channel parapet walls (z = 14.0 .. 17.4) with uneven broken tips
    for sx, front_len in ((-1, 14.5), (1, 11.5)):
        y_ctr = 7.0 - front_len * 0.5
        box(trim, (2.2, front_len, 3.4), M((sx * 9.0, y_ctr, 15.7)), bevel=0.12)
        # Signature verdigris teal-green cornice frieze along outer wall face
        box(accent, (2.6, front_len + 0.2, 1.15), M((sx * 9.0, y_ctr, 13.7)), bevel=0.08)
        # Coping cap stones
        box(trim, (2.7, front_len * 0.75, 0.75), M((sx * 9.0, y_ctr + front_len * 0.12, 17.6)), bevel=0.08)

    # Jagged masonry rubble blocks & fallen stones along the broken edge and pier foot
    for pos, sz, rot, sd in (
        ((-7.6, -7.2, 14.8), (2.4, 2.6, 2.2), (0.2, 0.3, -0.2), 1),
        ((-2.2, -7.8, 12.6), (3.2, 2.4, 1.8), (0.35, -0.1, 0.15), 2),
        ((6.8, -5.2, 14.4), (2.2, 2.2, 2.0), (-0.15, 0.2, 0.3), 3),
        ((-6.2, -1.5, 0.8), (4.2, 3.8, 2.2), (0.0, 0.0, 0.4), 4),
        ((7.2, -0.5, 0.9), (3.8, 3.4, 2.0), (0.0, 0.0, -0.3), 5),
    ):
        rock_clean(trim, sz, M(pos, rot=rot), sd, roughness=0.22, subdiv=2)

    # Thick moss cushions on the broken deck, parapet tops & base
    for pos, sz, sd in (
        ((-9.0, -2.0, 17.9), (2.8, 6.0, 1.0), 11),
        ((9.0, 1.5, 17.9), (2.8, 5.5, 1.0), 12),
        ((-3.5, -5.0, 14.0), (7.5, 4.5, 0.9), 13),
        ((8.2, 3.6, 1.9), (5.5, 5.2, 1.2), 14),
    ):
        rock(moss, sz, M(pos), sd, roughness=0.26, subdiv=2)

    # Heartroot feeder roots wrapping the west pier and spilling over the broken edge
    for pts, r_start in (
        (((-9.8, 5.2, 0.0), (-10.3, 3.8, 5.5), (-10.4, 1.8, 11.0), (-9.6, -1.5, 16.5), (-7.2, -5.2, 14.2), (-6.2, -7.5, 9.0)), 1.15),
        (((-6.8, 1.8, 0.0), (-6.4, 2.6, 6.2), (-7.4, 2.0, 12.0), (-5.2, -2.5, 13.6)), 0.85),
        (((9.8, 5.5, 0.0), (10.2, 3.5, 6.5), (9.8, 1.2, 12.8), (8.4, -2.0, 15.2)), 0.9),
    ):
        n = len(pts)
        radii = [r_start * (1.0 - 0.65 * i / max(1, n - 1)) for i in range(n)]
        tube(wood, pts, radii, 6)


@template("SunDiscShrine", TRIM=900, GOLD=1100, ACCENT=400, GLOW=300, MOSS=400)
def sun_disc_shrine(t):
    """Monumental carved Solmere Sun Disc shrine atop a stepped limestone spring plinth."""
    trim, gold, accent, glow, moss = t.bm("TRIM"), t.bm("GOLD"), t.bm("ACCENT"), t.bm("GLOW"), t.bm("MOSS")

    # Stepped limestone plinth & spring spout lip
    box(trim, (16.0, 8.2, 2.0), M((0, 0, 1.0)), bevel=0.16)
    box(trim, (12.4, 6.6, 2.2), M((0, 0.2, 3.1)), bevel=0.14)
    box(accent, (12.8, 6.9, 0.65), M((0, 0.2, 4.35)), bevel=0.06)
    # Front water-spout basin lip (-Y)
    box(trim, (6.2, 3.2, 1.4), M((0, -3.6, 1.8)), bevel=0.12)

    # Flanking carved pilasters cradling the sun disc
    for sx in (-1, 1):
        box(trim, (2.2, 3.4, 9.4), M((sx * 5.6, 0.4, 9.1)), bevel=0.12)
        box(trim, (2.8, 4.0, 1.1), M((sx * 5.6, 0.4, 14.0)), bevel=0.10)

    # Carved golden Sun Disc centered at (0, 0.2, 15.6) facing -Y
    cz = 15.6
    disc_mat = M((0, 0.2, cz), rot=(math.pi / 2, 0, 0))
    ring_mesh(gold, 4.5, 0.72, 24, disc_mat, tube_segs=6)
    ring_mesh(accent, 3.3, 0.38, 20, disc_mat, tube_segs=5)

    # 12 alternating long/short tapered sun rays
    for k in range(12):
        a = k * math.pi / 6
        r_len = 3.2 if k % 2 == 0 else 2.1
        r_w = 0.62 if k % 2 == 0 else 0.44
        dist = 4.9 + r_len * 0.48
        rx = math.cos(a) * dist
        rz = cz + math.sin(a) * dist
        cone(gold, r_w, 0.08, r_len, 4, M((rx, 0.2, rz), rot=(0, a - math.pi / 2, 0)) @ Matrix.Rotation(math.pi / 2, 4, "X"))
        # Wait: cone builds along local +Z; rotating around Y by (math.pi/2 - a) points +Z radially outward in X-Z!
    # Re-clear and place rays properly oriented in X-Z plane:
    # Let's place clean radial rays using box/cone oriented by exact angle in X-Z!
    # Actually the cone line above added 12 cones; let's verify orientation:
    # In Blender, Matrix.Rotation(theta, 4, 'Y') maps local (0,0,1) -> (sin(theta), 0, cos(theta)).
    # We want (sin(theta), 0, cos(theta)) == (cos(a), 0, sin(a)), so theta = pi/2 - a!
    # Let's clear `gold` and rebuild ring + properly oriented rays cleanly!
    gold.clear()
    ring_mesh(gold, 4.5, 0.72, 24, disc_mat, tube_segs=6)
    for k in range(12):
        a = k * math.pi / 6
        r_len = 3.2 if k % 2 == 0 else 2.1
        r_w = 0.62 if k % 2 == 0 else 0.44
        base_r = 4.95
        bx = math.cos(a) * base_r
        bz = cz + math.sin(a) * base_r
        cone(gold, r_w, 0.08, r_len, 4, M((bx, 0.2, bz), rot=(0, math.pi / 2 - a, 0)))

    # Glowing emerald-gold sunsap core in the center
    cone(glow, 2.35, 2.35, 1.1, 18, M((0, 0.75, cz), rot=(math.pi / 2, 0, 0)))
    uvsphere(glow, 1.5, M((0, 0.2, cz), scale=(1.0, 0.55, 1.0)), u=14, v=8)

    # Moss cushions on plinth corners
    for sx in (-1, 1):
        rock_clean(moss, (3.6, 3.2, 1.1), M((sx * 6.4, -2.5, 2.1)), 7 + sx, roughness=0.25, subdiv=2)


@template("SolmereBalustrade", TRIM=900, ACCENT=200, MOSS=300)
def solmere_balustrade(t):
    """Carved mossy Solmere stone balustrade section with turned balusters and newel posts."""
    trim, accent, moss = t.bm("TRIM"), t.bm("ACCENT"), t.bm("MOSS")

    # Plinth curb & heavy bevelled handrail
    box(trim, (16.0, 2.6, 0.9), M((0, 0, 0.45)), bevel=0.10)
    box(trim, (15.6, 2.2, 0.8), M((0, 0, 4.15)), bevel=0.10)

    # 4 turned stone balusters via lathe
    profile = [(0.62, 0.9), (0.62, 1.25), (0.36, 1.55), (0.52, 2.3), (0.34, 3.1), (0.58, 3.45), (0.58, 3.8)]
    for bx in (-4.5, -1.5, 1.5, 4.5):
        lathe(trim, profile, 10, M((bx, 0, 0)))

    # End newel posts with verdigris collar & pyramidal cap
    for sx in (-1, 1):
        px = sx * 7.1
        box(trim, (2.2, 2.8, 4.6), M((px, 0, 2.3)), bevel=0.10)
        box(accent, (2.4, 3.0, 0.55), M((px, 0, 4.1)), bevel=0.06)
        cone(trim, 1.55, 0.15, 0.95, 4, M((px, 0, 4.6), rot=(0, 0, math.pi / 4)))

    # Moss cushions on rail & base
    rock(moss, (3.4, 2.2, 0.8), M((-3.0, 0, 4.55)), 21, roughness=0.25, subdiv=2)
    rock(moss, (3.0, 2.4, 0.9), M((4.2, -0.3, 0.95)), 22, roughness=0.25, subdiv=2)


@template("ReedPondCluster", FOLIAGE=900, WOOD=400, GLOW=300)
def reed_pond_cluster(t):
    """Cattail reeds and notched water-lily pads with glowing emerald-gold blossoms."""
    rng = t.rng
    foliage, wood, glow = t.bm("FOLIAGE"), t.bm("WOOD"), t.bm("GLOW")

    # 12 fanning reed blades in 2 clumps
    for cx, cy in ((-1.4, -0.6), (1.8, 0.9)):
        for k in range(6):
            a = k * math.pi / 3 + rng.uniform(-0.2, 0.2)
            tilt = rng.uniform(0.14, 0.36)
            h = rng.uniform(3.8, 6.2)
            bx = cx + math.cos(a) * 0.45
            by = cy + math.sin(a) * 0.45
            cone(foliage, 0.26, 0.03, h, 4, M((bx, by, 0.0), rot=(math.sin(a) * tilt, -math.cos(a) * tilt, a)))

        # 3 cattail stalks with seed heads per clump
        for k in range(3):
            a = k * 2.1 + 0.5
            tilt = rng.uniform(0.06, 0.18)
            h = rng.uniform(4.8, 6.4)
            sx = cx + math.cos(a) * 0.25
            sy = cy + math.sin(a) * 0.25
            rot = (math.sin(a) * tilt, -math.cos(a) * tilt, 0)
            cone(wood, 0.08, 0.06, h, 5, M((sx, sy, 0.0), rot=rot))
            # Plump cattail head near top
            top_mat = M((sx, sy, 0.0), rot=rot) @ M((0, 0, h * 0.72))
            cone(wood, 0.24, 0.22, 1.35, 7, top_mat)

    # 3 notched water-lily pads (circular disc sector with a V-notch!)
    for px, py, rad, notch_ang, has_bloom in (
        (-1.6, 2.4, 1.9, 0.4, True),
        (2.4, -2.0, 1.6, 2.2, True),
        (0.4, 0.6, 1.4, 4.1, False),
    ):
        segs = 12
        verts = [foliage.verts.new((px, py, 0.24))]
        for i in range(segs + 1):
            a = notch_ang + 0.25 + (2 * math.pi - 0.5) * i / segs
            verts.append(foliage.verts.new((px + math.cos(a) * rad, py + math.sin(a) * rad, 0.26)))
        for i in range(1, len(verts) - 1):
            foliage.faces.new((verts[0], verts[i], verts[i + 1]))
        if has_bloom:
            uvsphere(glow, 0.48, M((px, py, 0.52), scale=(1.0, 1.0, 0.75)), u=10, v=6)


def build_f2():
    reset_scene()
    kit = bpy.data.collections.new("VerdantF2Kit")
    bpy.context.scene.collection.children.link(kit)
    manifest = {}
    for name, (fn, budget) in F2_TEMPLATES.items():
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


def export_f2(kit, manifest):
    os.makedirs(OUT_DIR, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    objs = [o for o in kit.all_objects if o.type == "MESH"]
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.fbx(
        filepath=os.path.join(OUT_DIR, "VerdantF2Kit.fbx"),
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
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT_DIR, "VerdantF2Kit.blend"))


if __name__ == "__main__":
    kit, manifest = build_f2()
    export_f2(kit, manifest)
    preview_dir = os.path.join(OUT_DIR, "previews")
    render_previews(kit, preview_dir, list(F2_TEMPLATES.keys()), tile=520, cols=5)
    print(json.dumps(manifest, indent=2))
