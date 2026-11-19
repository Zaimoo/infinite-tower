"""
Fungal Hollow Floor 7 (Mycelium Galleries) sculpted assets, generated in Blender.

Same conventions as generate_fungal_f6_kit.py (1 unit = 1 stud, standing on z = 0, front -Y in Blender /
+Z in Roblox, one mesh per colour role named "<Template>__<ROLE>"); it reuses that script's helpers.

    MyceliumNet   a Veinweb net strung between two mycelium stalks (the galleries' nets)
    LampNiche     a Velmari lamp niche cut for a cliff face: pilasters, arch, shelf, gill-wheel, hanging bulb

Outputs (assets-source/tower/fungal_f7_kit/): FungalF7Kit.blend, FungalF7Kit.fbx, manifest.json, previews/.

Run headless:  blender --background --python tools/blender/generate_fungal_f7_kit.py
"""
import bpy, math, os, json, random, runpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT_DIR = os.path.join(ROOT, "assets-source", "tower", "fungal_f7_kit")

f6 = runpy.run_path(os.path.join(HERE, "generate_fungal_f6_kit.py"), init_globals={"RUN_F6": False})
Template = f6["Template"]
M = f6["M"]
box = f6["box"]
cone = f6["cone"]
ico = f6["ico"]
uvsphere = f6["uvsphere"]
lathe = f6["lathe"]
tube = f6["tube"]
displace = f6["displace"]
rock = f6["rock"]
ring_mesh = f6["ring_mesh"]
reset_scene = f6["reset_scene"]
finalize = f6["finalize"]
render_previews = f6["render_previews"]
_gill_wheel = f6["_gill_wheel"]

DEFAULT_BUDGET = 3500
F7_TEMPLATES = {}


def template(name, **budget):
    def deco(fn):
        F7_TEMPLATES[name] = (fn, budget)
        return fn
    return deco


@template("MyceliumNet", STEM=1800, GLOW=1400, BULB=500, MOSS=300)
def mycelium_net(t):
    """Two mycelium stalks 24 studs apart with a sagging glowing net between them (~26 x 15 studs)."""
    rng = t.rng
    stem, glow, bulb, moss = t.bm("STEM"), t.bm("GLOW"), t.bm("BULB"), t.bm("MOSS")
    half, top = 12.0, 14.0
    posts = []
    for sx in (-1, 1):
        base = Vector((sx * half, 0, 0))
        pts = [base + Vector((0, 0, -0.4)), base + Vector((sx * 0.4, 0.3, top * 0.45)), base + Vector((sx * 0.2, -0.2, top * 0.8)),
               base + Vector((0, 0, top))]
        v = tube(stem, pts, [1.3, 0.95, 0.8, 0.55], 8)
        displace(stem, v, 0.12, 0.6, int(sx + 5))
        rock(moss, (3.4, 3.0, 1.0), M(base + Vector((0, 0, -0.3))), int(sx + 9), roughness=0.3, subdiv=2)
        posts.append(base)
    # Horizontal strands (catenaries), sagging more toward the bottom.
    rows = 6
    grid = []
    for r in range(rows):
        z = 4.5 + r * (top - 5.5) / (rows - 1)
        sag = 1.0 + (rows - 1 - r) * 0.3
        row = []
        for k in range(9):
            u = k / 8
            x = -half + 2 * half * u
            row.append(Vector((x, -0.15 * math.sin(math.pi * u), z - sag * math.sin(math.pi * u))))
        grid.append(row)
        thick = r in (0, rows - 1)
        tube(stem if thick else glow, row, [0.22 if thick else 0.08] * len(row), 4 if thick else 3, cap=False)
    # Vertical threads and bulb nodes where they cross.
    for k in range(1, 8):
        col = [grid[r][k] for r in range(rows)]
        tube(glow, col, [0.07] * len(col), 3, cap=False)
        for r in range(rows):
            if (k + r) % 2 == 0:
                ico(bulb, 0.22 + rng.uniform(0, 0.08), M(grid[r][k]), 1)
    # A few torn strands hanging from the bottom row.
    for k in (2, 5, 7):
        p0 = grid[0][k]
        ln = rng.uniform(0.8, 1.6)
        tube(glow, [p0, p0 + Vector((0.1, 0, -ln * 0.5)), p0 + Vector((0.2, 0.1, -ln))], [0.07, 0.06, 0.04], 3, cap=False)


@template("LampNiche", TRIM=1500, ACCENT=700, GLOW=500, BULB=300, MOSS=500, STEM=300)
def lamp_niche(t):
    """A Velmari lamp niche for a cliff face: a slab with pilasters, an arched head, a shelf and a hanging bulb."""
    rng = t.rng
    trim, accent, moss, stem = t.bm("TRIM"), t.bm("ACCENT"), t.bm("MOSS"), t.bm("STEM")
    w, h, d = 12.0, 14.0, 3.0
    # The back slab (set into the cliff) and the recess's back wall.
    box(trim, (w, d, h), M((0, d / 2 + 0.6, h / 2)), bevel=0.2)
    # Pilasters either side, stepped plinth, and a lintel course.
    for sx in (-1, 1):
        box(trim, (1.8, 1.6, h - 1.0), M((sx * (w / 2 - 0.9), -0.2, (h - 1.0) / 2)), bevel=0.15)
        box(trim, (2.4, 2.0, 1.2), M((sx * (w / 2 - 0.9), -0.3, 0.6)), bevel=0.1)
    box(trim, (w + 0.8, 2.2, 1.2), M((0, 0.1, h - 0.6)), bevel=0.15)
    # The arch over the recess (half ring) and its keystone.
    arc_r = (w - 3.6) / 2
    pts = [Vector((math.cos(a) * arc_r, -0.6, h - 4.6 + math.sin(a) * arc_r * 0.7)) for a in [math.pi * i / 10 for i in range(11)]]
    tube(accent, pts, [0.55] * len(pts), 5, cap=False)
    box(accent, (1.2, 1.0, 1.6), M((0, -0.7, h - 4.6 + arc_r * 0.7 + 0.3)), bevel=0.1)
    # The shelf, the gill-wheel set into the recess and its lamp hanging from the arch.
    box(trim, (w - 3.6, 2.4, 0.6), M((0, -0.4, 3.2)), bevel=0.1)
    _gill_wheel(t, Vector((0, 0.4, 7.0)), 2.2, (0, 0, 0))
    hang = Vector((0, -1.0, h - 4.6 + arc_r * 0.7 - 0.6))
    tube(stem, [hang, hang + Vector((0, 0, -2.2))], [0.08, 0.08], 3, cap=False)
    uvsphere(t.bm("BULB"), 0.7, M(hang + Vector((0, 0, -2.9)), scale=(1.0, 1.0, 1.3)), u=10, v=8)
    # Spore-moss creeping over the plinths and shelf, a few wax stubs on the shelf.
    for (x, y, z, s) in ((-w / 2 + 1, -0.8, 1.2, 1.6), (w / 2 - 1.2, -0.8, 1.2, 1.3), (-2.0, -0.6, 3.5, 1.0), (0, 0.8, h - 0.1, 2.4)):
        rock(moss, (s * 1.8, s * 1.2, s * 0.5), M((x, y, z)), int(s * 17 + x * 3 + 40), roughness=0.3, subdiv=2)
    for k in range(4):
        x = -2.6 + k * 1.6 + rng.uniform(-0.3, 0.3)
        cone(stem, 0.2, 0.18, rng.uniform(0.5, 1.1), 6, M((x, -0.9, 3.5)))


def build_f7():
    reset_scene()
    kit = bpy.data.collections.new("FungalF7Kit")
    bpy.context.scene.collection.children.link(kit)
    manifest = {}
    for name, (fn, budget) in F7_TEMPLATES.items():
        coll = bpy.data.collections.new(name)
        kit.children.link(coll)
        t = Template(name)
        t.rng = random.Random(sum(map(ord, name)))
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


def export_f7(kit, manifest):
    os.makedirs(OUT_DIR, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    objs = [o for o in kit.all_objects if o.type == "MESH"]
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.fbx(
        filepath=os.path.join(OUT_DIR, "FungalF7Kit.fbx"),
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
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT_DIR, "FungalF7Kit.blend"))


if __name__ == "__main__" or globals().get("RUN_F7", False):
    kit, manifest = build_f7()
    export_f7(kit, manifest)
    if globals().get("PREVIEWS", True):
        render_previews(kit, os.path.join(OUT_DIR, "previews"), list(F7_TEMPLATES.keys()), tile=520, cols=2)
    result = {"templates": len(manifest), "manifest": manifest}
    print(json.dumps(manifest, indent=2))
