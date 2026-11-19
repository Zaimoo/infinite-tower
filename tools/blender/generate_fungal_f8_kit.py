"""
Fungal Hollow Floor 8 (Blooming Chasm) sculpted assets: the Lampkeepers' camp kit, generated in Blender.

The Lampkeepers were the last Velmari who refused the Veinweb, fleeing up through the cavern. Everything
they built was made on the run: rope, planks, cut cap, scavenged slate. Same conventions as
generate_fungal_f6_kit.py (1 unit = 1 stud, standing on z = 0, front -Y in Blender / +Z in Roblox, one
mesh per colour role named "<Template>__<ROLE>"); it reuses that script's helpers.

    CapShelter     a lean-to roofed with a cut section of cap on two poles, a bedroll inside
    CampSupplies   bedrolls, sacks, a crate and a rope coil
    CrystalBrazier a scavenged slate ring holding crystals and a warm flame (CANDLE)
    Barricade      planks and slate slabs lashed together with cable (~14 studs wide)
    ChalkSign      the Lampkeepers' sign on a rock: a gill-wheel with one long ray pointing the way up

Outputs (assets-source/tower/fungal_f8_kit/): FungalF8Kit.blend, FungalF8Kit.fbx, manifest.json, previews/.

Run headless:  blender --background --python tools/blender/generate_fungal_f8_kit.py
"""
import bpy, bmesh, math, os, json, random, runpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT_DIR = os.path.join(ROOT, "assets-source", "tower", "fungal_f8_kit")

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
ROLE_PREVIEW = f6["ROLE_PREVIEW"]
ROLE_PREVIEW.update({"WOOD": (0.40, 0.30, 0.22), "FOLIAGE": (0.62, 0.52, 0.38), "ALT": (0.92, 0.92, 0.96)})

DEFAULT_BUDGET = 3500
F8_TEMPLATES = {}


def rock_clean(bm, size, mat, seed, roughness=0.22, subdiv=2, flat_bottom=True):
    """A displaced boulder built in a fresh bmesh and copied in, so earlier bevels in `bm` can't corrupt the
    vertex tracking `rock` relies on (they stretch the rock otherwise)."""
    tmp = bmesh.new()
    rock(tmp, size, mat, seed, roughness=roughness, subdiv=subdiv, flat_bottom=flat_bottom)
    vmap = [bm.verts.new(v.co) for v in tmp.verts]
    for f in tmp.faces:
        bm.faces.new([vmap[v.index] for v in f.verts])
    tmp.free()


def template(name, **budget):
    def deco(fn):
        F8_TEMPLATES[name] = (fn, budget)
        return fn
    return deco


def _bedroll(t, at, yaw, length=4.2):
    """A rolled bedroll (FOLIAGE: cloth) tied with two bands (WOOD: cord)."""
    cloth, cord = t.bm("FOLIAGE"), t.bm("WOOD")
    m = M(at, rot=(0, math.pi / 2, yaw))
    cone(cloth, 0.55, 0.55, length, 10, m @ M((0, 0, -length / 2)))
    for u in (-0.3, 0.3):
        cone(cord, 0.6, 0.6, 0.15, 10, m @ M((0, 0, u * length - 0.075)))


@template("CapShelter", CAP=900, STEM=700, WOOD=900, FOLIAGE=500, MOSS=300, GLOW=300)
def cap_shelter(t):
    """A lean-to: a cut, curved section of mushroom cap laid over a ridge pole on two forked poles (~12 x 9)."""
    rng = t.rng
    cap, stem, wood, moss, glow = t.bm("CAP"), t.bm("STEM"), t.bm("WOOD"), t.bm("MOSS"), t.bm("GLOW")
    w, d, h = 11.0, 8.0, 6.4
    # Two forked poles at the front, the ridge pole across them, the back edge resting on the ground.
    for sx in (-1, 1):
        base = Vector((sx * w / 2 * 0.86, -d / 2 + 0.6, 0))
        tube(wood, [base, base + Vector((0, 0, h))], [0.28, 0.22], 6)
        for fork in (-1, 1):
            tube(wood, [base + Vector((0, 0, h - 0.3)), base + Vector((fork * 0.5, 0, h + 0.7))], [0.18, 0.12], 5, cap=False)
    tube(wood, [Vector((-w / 2, -d / 2 + 0.6, h + 0.2)), Vector((w / 2, -d / 2 + 0.6, h + 0.2))], [0.24, 0.24], 6, cap=False)
    # The cap section: a curved shell sloping from the ridge to the ground at the back.
    cols, rows = 10, 6
    verts = []
    for r in range(rows + 1):
        v = r / rows
        y = -d / 2 + 0.4 + (d - 0.2) * v
        z = (h + 0.6) * (1 - v) ** 1.15 + 0.1
        row = []
        for c in range(cols + 1):
            u = c / cols
            x = -w / 2 - 0.6 + (w + 1.2) * u
            bulge = 0.7 * math.sin(math.pi * u) * math.sin(math.pi * v)
            row.append(cap.verts.new((x, y - bulge * 0.4, z + bulge)))
        verts.append(row)
    for r in range(rows):
        for c in range(cols):
            cap.faces.new((verts[r][c], verts[r][c + 1], verts[r + 1][c + 1], verts[r + 1][c]))
    # The cut edge's gills along the front (a dim GLOW strip) and spots on the shell.
    tube(glow, [Vector((-w / 2 - 0.4, -d / 2 + 0.3, h + 0.45)), Vector((w / 2 + 0.4, -d / 2 + 0.3, h + 0.45))], [0.12, 0.12], 4, cap=False)
    for k in range(6):
        u, v = rng.uniform(0.15, 0.85), rng.uniform(0.2, 0.75)
        x = -w / 2 + w * u
        y = -d / 2 + d * v
        z = (h + 0.6) * (1 - v) ** 1.15 + 0.7 * math.sin(math.pi * u) * math.sin(math.pi * v) + 0.15
        ico(stem, 0.45, M((x, y, z), scale=(1.0, 1.0, 0.35)), 1)
    # A bedroll under it, and moss banked against the back.
    _bedroll(t, Vector((0.6, 0.6, 0.55)), 0.0)
    rock(moss, (w * 0.9, 2.6, 0.9), M((0, d / 2 - 0.8, -0.2)), 31, roughness=0.3, subdiv=2)


@template("CampSupplies", FOLIAGE=900, WOOD=900, TRIM=300, MOSS=200)
def camp_supplies(t):
    """A small cache: two bedrolls, three sacks, a lashed crate and a coil of rope (~7 x 5)."""
    rng = t.rng
    cloth, wood, trim, moss = t.bm("FOLIAGE"), t.bm("WOOD"), t.bm("TRIM"), t.bm("MOSS")
    _bedroll(t, Vector((-1.8, -1.0, 0.55)), 0.2)
    _bedroll(t, Vector((-1.6, 0.2, 1.6)), -0.15, 3.8)
    for k, (x, y, s) in enumerate(((1.2, -1.2, 1.0), (2.4, -0.2, 0.85), (1.0, 0.9, 0.75))):
        v = uvsphere(cloth, 1.0, M((x, y, s * 0.8), scale=(s * 0.8, s * 0.7, s)), u=10, v=7)
        displace(cloth, v, 0.06, 1.3, k)
        cone(cloth, 0.22 * s, 0.12 * s, 0.5 * s, 6, M((x, y, s * 1.7)))
    # Crate: planks with two straps, a slate slab on top as a lid weight.
    box(wood, (2.2, 1.8, 1.6), M((-0.2, 1.9, 0.8)), bevel=0.06)
    for u in (-0.6, 0.6):
        box(trim, (2.3, 1.9, 0.18), M((-0.2, 1.9, 0.8 + u)), bevel=0.02)
    box(trim, (1.4, 1.1, 0.25), M((-0.1, 1.9, 1.75), rot=(0, 0, 0.25)), bevel=0.05)
    # Rope coil.
    for k in range(4):
        ring_mesh(wood, 0.7 - k * 0.05, 0.12, 14, M((2.6, 1.6, 0.14 + k * 0.22)), tube_segs=4)
    rock(moss, (6.8, 5.2, 0.5), M((0.3, 0.3, -0.25)), 37, roughness=0.3, subdiv=2)


@template("CrystalBrazier", TRIM=900, CRYSTAL=600, CANDLE=500, MOSS=200)
def crystal_brazier(t):
    """A ring of scavenged slate slabs holding a crystal clutch and a warm flame (~5 across)."""
    rng = t.rng
    trim, crystal, flame, moss = t.bm("TRIM"), t.bm("CRYSTAL"), t.bm("CANDLE"), t.bm("MOSS")
    for k in range(9):
        a = k * 2 * math.pi / 9
        box(trim, (1.4, 0.6, 1.1 + rng.uniform(0, 0.4)), M((math.cos(a) * 2.0, math.sin(a) * 2.0, 0.55), rot=(rng.uniform(-0.12, 0.12), 0, a + math.pi / 2)), bevel=0.08)
    rock_clean(trim, (3.2, 3.2, 0.5), M((0, 0, 0.0)), 41, roughness=0.15, subdiv=1)
    for k in range(5):
        a = k * 2 * math.pi / 5 + 0.3
        h = rng.uniform(1.0, 1.8)
        cone(crystal, 0.32, 0.02, h, 5, M((math.cos(a) * 0.9, math.sin(a) * 0.9, 0.45), rot=(math.sin(a) * 0.4, -math.cos(a) * 0.4, a)))
    # The flame: three teardrops.
    for (x, y, s) in ((0, 0, 1.0), (0.3, 0.2, 0.7), (-0.3, -0.1, 0.65)):
        uvsphere(flame, 0.45 * s, M((x, y, 0.9 + 0.5 * s), scale=(1.0, 1.0, 2.0)), u=8, v=6)
    rock(moss, (5.4, 5.0, 0.4), M((0, 0, -0.22)), 43, roughness=0.3, subdiv=2)


@template("Barricade", WOOD=1200, TRIM=900, STEM=400, MOSS=200)
def barricade(t):
    """Planks and slate slabs lashed with cable between leaning posts (~14 wide, 5 tall)."""
    rng = t.rng
    wood, trim, cable, moss = t.bm("WOOD"), t.bm("TRIM"), t.bm("STEM"), t.bm("MOSS")
    posts = [-6.4, -2.1, 2.2, 6.3]
    for k, x in enumerate(posts):
        lean = rng.uniform(-0.12, 0.12)
        tube(wood, [Vector((x, 0.2, -0.3)), Vector((x + lean * 4, -0.1, 5.2 + rng.uniform(-0.4, 0.5)))], [0.3, 0.22], 6)
    for k in range(5):
        z = 0.8 + k * 0.95
        box(wood, (13.6 + rng.uniform(-1.2, 0.4), 0.3, 0.75), M((rng.uniform(-0.4, 0.4), -0.25, z), rot=(0, rng.uniform(-0.06, 0.06), 0)), bevel=0.04)
    # Slate slabs propped against the front, and a cable lashing along the top.
    for x in (-4.6, 0.4, 4.4):
        box(trim, (2.6, 0.5, 3.0 + rng.uniform(-0.5, 0.5)), M((x, -0.9, 1.4), rot=(0.25, 0, rng.uniform(-0.15, 0.15))), bevel=0.1)
    pts = [Vector((x, -0.45, 4.3 + 0.25 * math.sin(i))) for i, x in enumerate((-6.6, -4.2, -2.1, 0, 2.2, 4.3, 6.5))]
    tube(cable, pts, [0.12] * len(pts), 4, cap=False)
    rock(moss, (12.0, 2.2, 0.6), M((0, 0.6, -0.25)), 47, roughness=0.3, subdiv=2)


@template("ChalkSign", STONE=500, ALT=400)
def chalk_sign(t):
    """The Lampkeepers' sign chalked on a rock: a gill-wheel with one long ray, pointing up (~3 across)."""
    stone, chalk = t.bm("STONE"), t.bm("ALT")
    # A squat rock with a flattened front face, the sign chalked flat on that face (one plane, -Y).
    rock(stone, (3.0, 1.8, 2.8), M((0, 0.3, -0.1)), 53, roughness=0.12, subdiv=2)
    face = Vector((0, -0.62, 1.3))
    ring_mesh(chalk, 0.42, 0.045, 14, M(face, rot=(math.pi / 2, 0, 0)), tube_segs=3)
    for k in range(8):
        a = k * math.pi / 4
        ln = 0.75 if k == 2 else 0.28
        p0 = face + Vector((math.cos(a) * 0.48, 0, math.sin(a) * 0.48))
        p1 = face + Vector((math.cos(a) * (0.48 + ln), 0, math.sin(a) * (0.48 + ln)))
        tube(chalk, [p0, p1], [0.045, 0.045], 3, cap=False)


def build_f8():
    reset_scene()
    kit = bpy.data.collections.new("FungalF8Kit")
    bpy.context.scene.collection.children.link(kit)
    manifest = {}
    for name, (fn, budget) in F8_TEMPLATES.items():
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


def export_f8(kit, manifest):
    os.makedirs(OUT_DIR, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    objs = [o for o in kit.all_objects if o.type == "MESH"]
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.fbx(
        filepath=os.path.join(OUT_DIR, "FungalF8Kit.fbx"),
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
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT_DIR, "FungalF8Kit.blend"))


if __name__ == "__main__" or globals().get("RUN_F8", False):
    kit, manifest = build_f8()
    export_f8(kit, manifest)
    if globals().get("PREVIEWS", True):
        render_previews(kit, os.path.join(OUT_DIR, "previews"), list(F8_TEMPLATES.keys()), tile=520, cols=5)
    result = {"templates": len(manifest), "manifest": manifest}
    print(json.dumps(manifest, indent=2))
