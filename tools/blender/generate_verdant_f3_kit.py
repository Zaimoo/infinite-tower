"""
Verdant Ruins Floor 3 (Rootway Crossing) sculpted assets, generated in headless Blender.

Reuses the mesh helpers and role conventions of `tools/blender/generate_tower_biome_kit.py`
(1 Blender unit = 1 stud, standing on z = 0, front facing -Y in Blender / +Z in Roblox,
one mesh object per colour role named "<Template>__<ROLE>").

Outputs (assets-source/tower/verdant_f3_kit/):
    VerdantF3Kit.blend    the generated scene
    VerdantF3Kit.fbx      FBX for File > Import 3D in Studio
    manifest.json         per template: roles, reference size, triangle counts
    previews/             contact-sheet render of the 5 Floor 3 templates
"""
import bpy, bmesh, math, os, json, random, runpy
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT_DIR = os.path.join(ROOT, "assets-source", "tower", "verdant_f3_kit")

kit_mod = runpy.run_path(os.path.join(HERE, "generate_tower_biome_kit.py"), init_globals={"RUN_KIT": False})

Template = kit_mod["Template"]
M = kit_mod["M"]
box = kit_mod["box"]
cone = kit_mod["cone"]
uvsphere = kit_mod["uvsphere"]
tube = kit_mod["tube"]
rock = kit_mod["rock"]
ring_mesh = kit_mod["ring_mesh"]
reset_scene = kit_mod["reset_scene"]
finalize = kit_mod["finalize"]
render_previews = kit_mod["render_previews"]


def rock_clean(bm, size, mat, seed, roughness=0.22, subdiv=2, flat_bottom=True):
    tmp = bmesh.new()
    rock(tmp, size, mat, seed, roughness=roughness, subdiv=subdiv, flat_bottom=flat_bottom)
    vmap = [bm.verts.new(v.co) for v in tmp.verts]
    for f in tmp.faces:
        bm.faces.new([vmap[v.index] for v in f.verts])
    tmp.free()


DEFAULT_BUDGET = 3500
F3_TEMPLATES = {}


def template(name, **budget):
    def deco(fn):
        F3_TEMPLATES[name] = (fn, budget)
        return fn
    return deco


@template("RootThrone", WOOD=2200, TRIM=1200, GOLD=600, ACCENT=500, GLOW=400, MOSS=600)
def root_throne(t):
    """Solmere carved sun-disc throne recessed into colossal flared Heartroot tree buttresses."""
    wood, trim, gold, accent, glow, moss = (
        t.bm("WOOD"), t.bm("TRIM"), t.bm("GOLD"), t.bm("ACCENT"), t.bm("GLOW"), t.bm("MOSS")
    )

    # Colossal Heartroot backing trunk rising behind the throne (centred around y=+6, z=0..34)
    cone(wood, 12.5, 9.2, 34.0, 14, M((0, 7.5, 0)))
    # Flared root buttresses sweeping forward (-Y) around the throne flanking stairs
    for side in (-1, 1):
        tube(
            wood,
            [
                (side * 6.5, 4.5, 28.0),
                (side * 9.5, 1.5, 16.0),
                (side * 12.0, -3.5, 6.5),
                (side * 14.5, -8.0, 0.2),
            ],
            [2.6, 2.9, 2.4, 1.3],
            8,
        )
        tube(
            wood,
            [
                (side * 4.0, 2.0, 22.0),
                (side * 7.2, -2.5, 11.0),
                (side * 9.2, -7.2, 3.0),
                (side * 11.2, -11.0, 0.0),
            ],
            [1.6, 1.8, 1.4, 0.8],
            7,
        )
        # Sap veins glowing along inner flanking roots
        tube(
            glow,
            [
                (side * 7.8, -0.5, 13.0),
                (side * 9.6, -4.5, 5.5),
                (side * 11.4, -7.8, 1.2),
            ],
            [0.32, 0.28, 0.18],
            5,
        )

    # Stepped Solmere stone dais & altar stairs facing -Y
    for step in range(4):
        w = 15.0 - step * 1.4
        d = 9.0 - step * 1.5
        box(trim, (w, d, 1.15), M((0, -5.2 - step * 0.1, 0.58 + step * 1.1)), bevel=0.12)

    # Tall arched Solmere stela / throne backrest framed by carvings
    box(trim, (11.2, 3.2, 16.5), M((0, -1.6, 12.5)), bevel=0.22)
    box(trim, (9.4, 3.6, 3.2), M((0, -1.5, 21.5)), bevel=0.20)
    # Recessed seat plinth & stone armrests
    box(trim, (6.2, 4.2, 3.4), M((0, -3.5, 6.2)), bevel=0.14)
    for side in (-1, 1):
        box(trim, (1.6, 4.6, 5.2), M((side * 3.6, -3.5, 7.1)), bevel=0.12)
        box(accent, (1.8, 3.0, 12.5), M((side * 4.8, -2.6, 12.2)), bevel=0.08)

    # Giant carved Gold & Verdigris Sun Disc above the throne crest (facing -Y)
    disc_pos = M((0, -3.3, 17.8), rot=(math.pi / 2, 0, 0))
    ring_mesh(gold, 3.6, 0.58, 18, disc_pos, tube_segs=5)
    ring_mesh(accent, 2.2, 0.32, 14, M((0, -3.4, 17.8), rot=(math.pi / 2, 0, 0)), tube_segs=4)
    uvsphere(glow, 1.15, M((0, -3.5, 17.8), scale=(1.0, 0.35, 1.0)), u=10, v=6)
    for k in range(10):
        a = k * math.pi / 5
        rx = math.cos(a) * 4.55
        rz = 17.8 + math.sin(a) * 4.55
        box(gold, (1.6, 0.45, 0.52), M((rx, -3.3, rz), rot=(0, -a, 0)), bevel=0.06)

    # Moss cushions along root crests and dais edges
    for pos, sz, sd in (
        ((-9.2, -3.2, 7.0), (4.6, 3.2, 1.4), 11),
        ((9.2, -3.2, 7.0), (4.6, 3.2, 1.4), 12),
        ((0, -1.6, 23.4), (7.8, 3.4, 1.5), 13),
    ):
        rock_clean(moss, sz, M(pos), sd, roughness=0.25, subdiv=2)


@template("HollowStumpRim", WOOD=2600, MOSS=700, FOLIAGE=500)
def hollow_stump_rim(t):
    """Continuous jagged crescent bark wall & flared buttresses framing a hollow felled giant tree."""
    wood, moss, foliage = t.bm("WOOD"), t.bm("MOSS"), t.bm("FOLIAGE")
    rng = t.rng

    # Overlapping wide tapered bark staves + jagged splinter peaks along a horseshoe crescent opening toward -Y
    r_inner, r_outer = 23.0, 31.0
    segs = 21
    for i in range(segs):
        frac = i / (segs - 1)
        ang = math.radians(-22 + frac * 224)
        crest = 8.0 + 13.0 * math.sin(math.pi * frac) ** 0.85
        jag = rng.uniform(-2.0, 3.2) + (2.5 if i % 3 == 0 else -1.0)
        h = max(4.5, crest + jag)
        cx = math.cos(ang) * (r_inner + r_outer) * 0.5
        cy = math.sin(ang) * (r_inner + r_outer) * 0.5
        # Tangential slab wider than the angular step so adjacent bark staves fuse cleanly with zero gaps
        box(wood, (6.5, 5.8, h), M((cx, cy, h * 0.5), rot=(0.04, 0.0, ang)), bevel=0.25)
        # Tapered jagged splinter spike at crest of alternating staves
        if i % 2 == 1:
            sx = math.cos(ang) * (r_inner + 2.6)
            sy = math.sin(ang) * (r_inner + 2.6)
            cone(wood, 2.6, 0.35, 3.8 + rng.uniform(0.0, 2.4), 5, M((sx, sy, h - 0.5), rot=(0.08, -0.06, ang)))
        # Flared buttress roots gripping the ground
        if i % 3 == 0:
            rx = math.cos(ang) * (r_outer + 5.5)
            ry = math.sin(ang) * (r_outer + 5.5)
            tube(
                wood,
                [(cx, cy, h * 0.52), (rx * 0.94, ry * 0.94, 4.6), (rx * 1.18, ry * 1.18, 0.0)],
                [2.1, 2.3, 1.2],
                7,
            )
        if i % 4 == 1:
            rock_clean(moss, (6.2, 5.0, 2.2), M((cx, cy, h + 0.4)), 20 + i, roughness=0.26, subdiv=2)
        if i % 5 == 2:
            rock_clean(foliage, (5.5, 4.8, 2.8), M((cx * 0.96, cy * 0.96, h * 0.45)), 40 + i, roughness=0.30, subdiv=1)


@template("RootBridgeArch", WOOD=2600, TRIM=800, MOSS=600, GLOW=450)
def root_bridge_arch(t):
    """Sweeping smooth curved Heartroot arch span with twisted tendrils, mossy stone fragments & sap veins."""
    wood, trim, moss, glow = t.bm("WOOD"), t.bm("TRIM"), t.bm("MOSS"), t.bm("GLOW")

    # 9-point smooth parabolic Heartroot arch spanning X (-25..+25) rising from z=+2.8 to Z = +19.3
    arch_pts = []
    arch_r = []
    for k in range(9):
        u = -1.0 + 2.0 * (k / 8.0)
        x = u * 25.0
        z = 2.8 + 16.5 * (1.0 - u * u)
        y = 0.6 * math.sin(u * math.pi)
        arch_pts.append((x, y, z))
        arch_r.append(2.35 + 0.95 * (u * u))
    tube(wood, arch_pts, arch_r, 10)

    # Coiling secondary root tendril hugging the main arch
    coil_pts, coil_r = [], []
    for k in range(11):
        u = -1.0 + 2.0 * (k / 10.0)
        theta = u * math.pi * 1.65
        x = u * 24.0
        z = 2.8 + 16.5 * (1.0 - u * u) + math.sin(theta) * 2.2
        y = math.cos(theta) * 2.6
        coil_pts.append((x, y, z))
        coil_r.append(1.15 + 0.45 * (u * u))
    tube(wood, coil_pts, coil_r, 7)

    # Glowing emerald-gold underside sap vein
    vein_pts = []
    vein_r = []
    for k in range(7):
        u = -0.75 + 1.5 * (k / 6.0)
        vein_pts.append((u * 24.0, -0.35, 2.8 + 16.5 * (1.0 - u * u) - 2.1))
        vein_r.append(0.45 - 0.12 * (u * u))
    tube(glow, vein_pts, vein_r, 5)

    # Ruined Solmere stone crest fragments & moss perched atop the arch
    for px, pz, sz, rotz in (
        (-5.5, 19.6, (2.6, 2.4, 3.8), 0.08),
        (-1.0, 20.6, (3.2, 2.8, 4.6), -0.05),
        (4.5, 19.8, (2.4, 2.2, 3.4), 0.12),
    ):
        box(trim, sz, M((px, 0.0, pz), rot=(0, rotz, 0)), bevel=0.14)
    for px, pz, sd in ((-12.0, 16.6, 61), (0.5, 21.4, 62), (11.5, 16.8, 63)):
        rock_clean(moss, (5.5, 3.6, 1.5), M((px, 0.0, pz)), sd, roughness=0.25, subdiv=2)


@template("RootKnotLantern", TRIM=900, GOLD=300, WOOD=700, GLOW=250, MOSS=350)
def root_knot_lantern(t):
    """Weathered Solmere stone trail lantern wrapped by Heartroot tendrils (for bridge & stair junctions)."""
    trim, gold, wood, glow, moss = t.bm("TRIM"), t.bm("GOLD"), t.bm("WOOD"), t.bm("GLOW"), t.bm("MOSS")

    # Stepped stone plinth & tapered shaft
    box(trim, (3.2, 3.2, 1.0), M((0, 0, 0.5)), bevel=0.12)
    box(trim, (1.8, 1.8, 4.2), M((0, 0, 3.1)), bevel=0.12)
    box(trim, (2.6, 2.6, 0.7), M((0, 0, 5.5)), bevel=0.10)
    # Glowing lantern chamber & gold corner posts
    uvsphere(glow, 0.82, M((0, 0, 6.65)), u=8, v=6)
    for sx in (-0.85, 0.85):
        for sy in (-0.85, 0.85):
            box(gold, (0.28, 0.28, 1.8), M((sx, sy, 6.65)), bevel=0.04)
    # Pagoda-inspired Solmere cap stone & finial
    cone(trim, 2.0, 0.65, 1.35, 4, M((0, 0, 7.6), rot=(0, 0, math.pi / 4)))
    uvsphere(gold, 0.36, M((0, 0, 8.95)), u=8, v=5)
    # Twisting Heartroot tendril gripping the pedestal
    tube(
        wood,
        [(1.7, -1.2, 0.1), (1.1, 0.6, 2.2), (-0.95, 0.9, 4.2), (-1.1, -0.7, 5.7)],
        [0.45, 0.38, 0.30, 0.20],
        6,
    )
    rock_clean(moss, (2.6, 2.6, 0.9), M((0, 0, 8.35)), 77, roughness=0.25, subdiv=1)


@template("FernCluster", FOLIAGE=1800, MOSS=350, WOOD=300)
def fern_cluster(t):
    """Broad-frond lush jungle fern rosette with continuous arched leaf ribbons."""
    foliage, moss, wood = t.bm("FOLIAGE"), t.bm("MOSS"), t.bm("WOOD")
    rng = t.rng

    cone(wood, 0.85, 0.50, 1.1, 7, M((0, 0, 0.0)))
    rock_clean(moss, (2.2, 2.2, 0.85), M((0, 0, 0.15)), 88, roughness=0.25, subdiv=1)

    # Build continuous curved multi-quad fronds fanning out cleanly
    for ring_idx, (count, length, arch_h, tip_drop, z0) in enumerate(((7, 4.9, 2.1, 0.7, 0.75), (5, 3.3, 2.3, 1.4, 0.95))):
        for k in range(count):
            ang = k * (2 * math.pi / count) + ring_idx * 0.42 + rng.uniform(-0.1, 0.1)
            rm = M((0, 0, 0), rot=(0, 0, ang))
            steps = 5
            rings = []
            for s in range(steps + 1):
                u = s / steps
                r = 0.35 + u * length
                z = z0 + math.sin(u * math.pi * 0.72) * arch_h + u * (tip_drop - arch_h * 0.35)
                hw = max(0.06, 0.88 * math.sin(math.pi * (0.15 + 0.82 * u)) * (1.0 - 0.18 * ring_idx))
                v_l = foliage.verts.new(rm @ Vector((r, -hw, z - 0.04)))
                v_m = foliage.verts.new(rm @ Vector((r, 0.0, z + 0.08)))
                v_r = foliage.verts.new(rm @ Vector((r, hw, z - 0.04)))
                v_b = foliage.verts.new(rm @ Vector((r, 0.0, z - 0.12)))
                rings.append((v_l, v_m, v_r, v_b))
            for s in range(steps):
                a, b = rings[s], rings[s + 1]
                foliage.faces.new((a[0], b[0], b[1], a[1]))
                foliage.faces.new((a[1], b[1], b[2], a[2]))
                foliage.faces.new((a[2], b[2], b[3], a[3]))
                foliage.faces.new((a[3], b[3], b[0], a[0]))
            foliage.faces.new((rings[0][0], rings[0][1], rings[0][2], rings[0][3]))
            foliage.faces.new((rings[-1][3], rings[-1][2], rings[-1][1], rings[-1][0]))


def build_f3():
    reset_scene()
    kit = bpy.data.collections.new("VerdantF3Kit")
    bpy.context.scene.collection.children.link(kit)
    manifest = {}
    for name, (fn, budget) in F3_TEMPLATES.items():
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


def export_f3(kit, manifest):
    os.makedirs(OUT_DIR, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    objs = [o for o in kit.all_objects if o.type == "MESH"]
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.fbx(
        filepath=os.path.join(OUT_DIR, "VerdantF3Kit.fbx"),
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
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT_DIR, "VerdantF3Kit.blend"))


if __name__ == "__main__":
    kit, manifest = build_f3()
    export_f3(kit, manifest)
    preview_dir = os.path.join(OUT_DIR, "previews")
    render_previews(kit, preview_dir, list(F3_TEMPLATES.keys()), tile=520, cols=5)
    print(json.dumps(manifest, indent=2))
