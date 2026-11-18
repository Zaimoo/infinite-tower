"""
Verdant Ruins Floor 4 (Vinebound Bastion) sculpted assets, generated in headless Blender.

Reuses the mesh helpers and role conventions of `tools/blender/generate_tower_biome_kit.py`
(1 Blender unit = 1 stud, standing on z = 0, front facing -Y in Blender / +Z in Roblox,
one mesh object per colour role named "<Template>__<ROLE>").

Outputs (assets-source/tower/verdant_f4_kit/):
    VerdantF4Kit.blend    the generated scene
    VerdantF4Kit.fbx      FBX for File > Import 3D in Studio
    manifest.json         per template: roles, reference size, triangle counts
    previews/             contact-sheet render of the 5 Floor 4 templates
"""
import bpy, bmesh, math, os, json, random, runpy
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT_DIR = os.path.join(ROOT, "assets-source", "tower", "verdant_f4_kit")

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
F4_TEMPLATES = {}


def template(name, **budget):
    def deco(fn):
        F4_TEMPLATES[name] = (fn, budget)
        return fn
    return deco


@template("GatehouseArch", TRIM=1600, ACCENT=500, GOLD=500, WOOD=900, MOSS=600)
def gatehouse_arch(t):
    """Breached Solmere fortress gatehouse arch with sun-disc piers and a strangler fig choking one pier."""
    trim, accent, gold, wood, moss = t.bm("TRIM"), t.bm("ACCENT"), t.bm("GOLD"), t.bm("WOOD"), t.bm("MOSS")

    # Twin heavy fortress piers flanking a 34-stud clear opening (walkable centre X in [-17..+17])
    for side in (-1, 1):
        px = side * 23.0
        box(trim, (12.0, 12.0, 26.0), M((px, 0.0, 13.0)), bevel=0.20)
        # Stepped outer shoulder wing connecting toward curtain wall
        box(trim, (10.0, 8.0, 18.0), M((side * 33.5, 0.0, 9.0)), bevel=0.16)
        # Crenellated battlements atop each gate pier
        for mx in (-4.0, 0.0, 4.0):
            for my in (-4.2, 4.2):
                box(trim, (2.6, 2.2, 2.8), M((px + mx, my, 27.2)), bevel=0.08)
        # Verdigris frieze & carved sun-disc medallion facing -Y (+Z in Roblox)
        box(accent, (12.4, 1.4, 2.2), M((px, -5.8, 19.5)), bevel=0.08)
        ring_mesh(gold, 2.6, 0.42, 14, M((px, -6.2, 14.5), rot=(math.pi / 2, 0, 0)), tube_segs=4)
        uvsphere(accent, 1.15, M((px, -6.3, 14.5), scale=(1.0, 0.35, 1.0)), u=8, v=5)
        rock_clean(moss, (9.0, 8.0, 1.8), M((px, 0.0, 26.4)), 10 + side, roughness=0.25, subdiv=2)

    # Tall arched lintel bridge across top (clear bottom height = 22.0 studs above ground!)
    box(trim, (42.0, 10.5, 5.2), M((0.0, 0.0, 24.6)), bevel=0.18)
    box(accent, (38.0, 11.2, 1.8), M((0.0, 0.0, 22.4)), bevel=0.08)
    for mx in range(-16, 17, 6):
        box(trim, (3.2, 2.2, 2.6), M((float(mx), -4.2, 28.4)), bevel=0.08)
        box(trim, (3.2, 2.2, 2.6), M((float(mx), 4.2, 28.4)), bevel=0.08)

    # Strangler fig bursting around the east (+X) pier and across the lintel, keeping centre doorway open
    tube(
        wood,
        [(20.0, -5.2, 0.0), (17.5, -6.2, 9.0), (16.2, -5.8, 19.5), (12.0, -5.5, 25.5), (3.0, -5.2, 27.6)],
        [2.2, 1.9, 1.6, 1.35, 0.9],
        8,
    )
    tube(
        wood,
        [(26.5, -5.5, 0.0), (22.0, -6.5, 11.0), (19.5, -4.5, 22.0), (24.5, -2.0, 29.0)],
        [1.7, 1.5, 1.25, 0.85],
        7,
    )
    rock_clean(moss, (12.0, 6.5, 2.2), M((6.0, -1.0, 27.6)), 14, roughness=0.28, subdiv=2)


@template("VineboundTower", TRIM=1500, ACCENT=300, WOOD=1100, MOSS=650)
def vinebound_tower(t):
    """Weathered circular Solmere fortress watchtower strangled by coiling Heartroot vines."""
    trim, accent, wood, moss = t.bm("TRIM"), t.bm("ACCENT"), t.bm("WOOD"), t.bm("MOSS")

    # Stepped octagonal/round stone drum (12 sides, radius 11.5 -> 9.2, height 48)
    cone(trim, 12.2, 11.2, 10.0, 12, M((0, 0, 0.0)))
    cone(trim, 10.8, 9.8, 28.0, 12, M((0, 0, 9.5)))
    # Upper overhanging parapet belt & verdigris trim collar
    cone(accent, 10.4, 10.8, 2.4, 12, M((0, 0, 36.8)))
    cone(trim, 10.8, 10.6, 8.5, 12, M((0, 0, 38.8)))

    # 8 weathered crenellated merlons around the top rim (with one broken gap)
    for k in range(8):
        if k == 2:
            continue
        ang = k * (math.pi * 2 / 8)
        mx = math.cos(ang) * 9.3
        my = math.sin(ang) * 9.3
        h = 3.2 if k != 5 else 1.8
        box(trim, (3.2, 2.6, h), M((mx, my, 47.3 + h * 0.5), rot=(0, 0, ang)), bevel=0.10)

    # Coiling Heartroot vines spiralling twice up the tower exterior
    for s_off, r_mod in ((0.0, 1.35), (2.2, 1.05)):
        pts, rads = [], []
        for k in range(13):
            u = k / 12.0
            ang = s_off + u * math.pi * 2.6
            rad = 11.8 - u * 1.6
            pts.append((math.cos(ang) * rad, math.sin(ang) * rad, 0.2 + u * 45.0))
            rads.append(r_mod * (1.15 - u * 0.45))
        tube(wood, pts, rads, 7)

    # Thick moss pads hugging the tower ledges and broken parapet
    for px, py, pz, sd in (
        (-6.0, -6.5, 47.5, 21), (6.5, -5.0, 38.0, 22), (-7.0, 5.5, 24.0, 23), (5.0, 6.8, 10.2, 24)
    ):
        rock_clean(moss, (6.8, 5.8, 2.2), M((px, py, pz)), sd, roughness=0.28, subdiv=2)


@template("VineboundKeep", TRIM=1800, ACCENT=450, GOLD=350, WOOD=950, MOSS=650)
def vinebound_keep(t):
    """Roofless twin-bastion Inner Keep citadel draped in overhead Heartroot vine cables."""
    trim, accent, gold, wood, moss = t.bm("TRIM"), t.bm("ACCENT"), t.bm("GOLD"), t.bm("WOOD"), t.bm("MOSS")

    # Flanking square keep towers connected by a stepped sanctuary facade & open portal bay
    for side in (-1, 1):
        tx = side * 16.5
        box(trim, (12.0, 14.0, 44.0), M((tx, 0.0, 22.0)), bevel=0.22)
        box(accent, (12.6, 14.6, 2.0), M((tx, 0.0, 34.0)), bevel=0.08)
        for sx in (-4.2, 4.2):
            for sy in (-5.0, 5.0):
                box(trim, (3.0, 3.0, 4.0), M((tx + sx, sy, 45.5)), bevel=0.10)
        rock_clean(moss, (10.5, 11.0, 2.4), M((tx, 0.0, 44.4)), 30 + side, roughness=0.26, subdiv=2)

    # Central stepped keep hall & recessed doorway arch facing -Y
    box(trim, (24.0, 12.0, 28.0), M((0.0, 2.0, 14.0)), bevel=0.20)
    box(trim, (26.0, 10.0, 6.0), M((0.0, -1.0, 31.0)), bevel=0.18)
    ring_mesh(gold, 3.8, 0.55, 16, M((0.0, -4.4, 24.5), rot=(math.pi / 2, 0, 0)), tube_segs=4)
    box(accent, (18.0, 1.8, 1.8), M((0.0, -4.4, 18.0)), bevel=0.08)

    # Draping vine canopy slung between the twin keep towers (roofless sky ceiling)
    for k, z_sag in enumerate(((44.0, 38.0, 44.0), (41.0, 35.5, 42.5))):
        y_off = -3.0 + k * 5.0
        tube(
            wood,
            [(-15.0, y_off, z_sag[0]), (-6.0, y_off - 1.2, z_sag[1] + 1.5), (0.0, y_off, z_sag[1]), (6.0, y_off + 1.0, z_sag[1] + 1.2), (15.0, y_off, z_sag[2])],
            [1.2, 0.95, 0.85, 0.95, 1.2],
            6,
        )
    # Climbing roots rising around left keep shoulder
    tube(wood, [(-21.5, -6.5, 0.0), (-20.0, -7.2, 16.0), (-17.5, -5.5, 32.0), (-15.0, -2.0, 43.0)], [2.0, 1.7, 1.3, 0.9], 7)


@template("CurtainWallRuins", TRIM=1000, ACCENT=250, MOSS=500, WOOD=550)
def curtain_wall_ruins(t):
    """Weathered crenellated Solmere fortress curtain wall segment with a ragged breach and vines."""
    trim, accent, moss, wood = t.bm("TRIM"), t.bm("ACCENT"), t.bm("MOSS"), t.bm("WOOD")

    # Stepped battered base & broken crenellated parapet running X (-16..+16)
    box(trim, (32.0, 6.2, 6.0), M((0.0, 0.0, 3.0)), bevel=0.16)
    box(trim, (14.0, 5.2, 10.5), M((-9.0, 0.0, 10.5)), bevel=0.16)
    box(trim, (11.0, 5.2, 8.2), M((9.5, 0.0, 9.5)), bevel=0.16)
    box(accent, (14.2, 5.6, 1.2), M((-9.0, 0.0, 12.2)), bevel=0.06)
    for mx in (-13.5, -8.5, -3.8, 7.5, 12.5):
        h = 2.6 if mx < 0 else 2.0
        z_top = 15.8 if mx < 0 else 13.6
        box(trim, (2.8, 2.0, h), M((mx, -1.6, z_top + h * 0.5)), bevel=0.08)

    tube(wood, [(1.5, -3.2, 0.0), (-1.5, -2.5, 7.5), (-5.0, -1.8, 15.0), (-11.0, 0.0, 17.5)], [1.3, 1.1, 0.85, 0.55], 6)
    for px, pz, sd in ((-9.0, 16.0, 41), (9.5, 13.8, 42), (0.0, 6.2, 43)):
        rock_clean(moss, (6.5, 4.6, 1.6), M((px, 0.0, pz)), sd, roughness=0.28, subdiv=2)


@template("VineboundGuardian", TRIM=1000, ACCENT=250, GLOW=180, WOOD=600, MOSS=450)
def vinebound_guardian(t):
    """Half-swallowed kneeling Solmere stone colossus overgrown with Heartroot vines at the gatehouse."""
    trim, accent, glow, wood, moss = t.bm("TRIM"), t.bm("ACCENT"), t.bm("GLOW"), t.bm("WOOD"), t.bm("MOSS")

    # Plinth & kneeling lower stone legs
    box(trim, (9.0, 9.0, 1.8), M((0.0, 0.0, 0.9)), bevel=0.14)
    box(trim, (7.0, 6.2, 4.2), M((0.0, 0.5, 3.6)), bevel=0.18)
    # Hunched broad armored stone torso & tilted head facing -Y
    box(trim, (7.4, 5.0, 6.2), M((0.0, 0.2, 8.2), rot=(0.14, 0, 0)), bevel=0.22)
    box(accent, (4.2, 1.2, 4.0), M((0.0, -2.3, 8.2), rot=(0.14, 0, 0)), bevel=0.08)
    uvsphere(glow, 0.85, M((0.0, -2.8, 8.6), scale=(1.0, 0.5, 1.0)), u=8, v=5)
    box(trim, (3.2, 3.4, 3.6), M((0.0, -0.8, 12.6), rot=(0.22, -0.18, 0.10)), bevel=0.18)
    # Stone arms resting forward on knees
    for side in (-1, 1):
        box(trim, (2.2, 4.6, 2.4), M((side * 3.8, -1.5, 6.8), rot=(0.45, 0, side * 0.12)), bevel=0.14)

    # Coiling strangler vines binding shoulder & torso down to plinth
    tube(wood, [(4.2, -2.8, 0.4), (3.8, -2.6, 5.5), (1.8, -2.4, 9.8), (-2.2, -1.0, 12.2)], [0.95, 0.80, 0.65, 0.45], 6)
    rock_clean(moss, (5.2, 4.0, 1.8), M((0.0, 0.2, 11.4)), 51, roughness=0.26, subdiv=2)


def build_f4():
    reset_scene()
    kit = bpy.data.collections.new("VerdantF4Kit")
    bpy.context.scene.collection.children.link(kit)
    manifest = {}
    for name, (fn, budget) in F4_TEMPLATES.items():
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


def export_f4(kit, manifest):
    os.makedirs(OUT_DIR, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    objs = [o for o in kit.all_objects if o.type == "MESH"]
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.fbx(
        filepath=os.path.join(OUT_DIR, "VerdantF4Kit.fbx"),
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
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT_DIR, "VerdantF4Kit.blend"))


if __name__ == "__main__":
    kit, manifest = build_f4()
    export_f4(kit, manifest)
    preview_dir = os.path.join(OUT_DIR, "previews")
    render_previews(kit, preview_dir, list(F4_TEMPLATES.keys()), tile=520, cols=5)
    print(json.dumps(manifest, indent=2))
